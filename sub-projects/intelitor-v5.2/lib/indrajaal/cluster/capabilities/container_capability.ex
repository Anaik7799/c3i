defmodule Indrajaal.Cluster.Capabilities.ContainerCapability do
  @moduledoc """
  Container Capability Backend for Podman/Docker Mesh Networking.

  WHAT: Manages container-based compute nodes in the mesh with Tailscale networking.
  WHY: SC-CNT-009 mandates NixOS/Podman; SC-CLU-001 requires identity-based networking.
  CONSTRAINTS: Rootless Podman only; Tailscale names primary, local fallback.

  ## Architecture

  This module provides:
  1. **Container Lifecycle**: Start/stop/health check for Podman containers
  2. **Tailscale Integration**: Containers join Tailscale mesh automatically
  3. **Local Fallback**: Bridge networking when Tailscale unavailable

  ## STAMP Constraints
  - SC-CNT-009: NixOS/Podman exclusively
  - SC-CNT-010: Localhost registry only
  - SC-CNT-012: Rootless mode mandatory
  - SC-CLU-001: Identity-based networking

  ## Container Naming Convention
  - Tailscale: `indrajaal-{type}-{id}@{hostname}.{tailnet}.ts.net`
  - Local: `indrajaal-{type}-{id}@{hostname}.local.indrajaal`
  """

  use GenServer
  require Logger

  alias Indrajaal.Cluster.TailscaleDNS
  alias Indrajaal.Cluster.Capabilities.NodeNameBuilder

  @behaviour Indrajaal.Cluster.Capabilities.Behaviour

  # ============================================================
  # TYPE DEFINITIONS
  # ============================================================

  @type container_type :: :app | :worker | :runner | :analytics | :video
  @type container_id :: String.t()
  @type container_state :: :pending | :starting | :running | :stopping | :stopped | :failed
  @type network_mode :: :tailscale | :local | :bridge

  @type container_spec :: %{
          id: container_id(),
          type: container_type(),
          image: String.t(),
          env: map(),
          ports: list(),
          volumes: list(),
          network_mode: network_mode(),
          tailscale_authkey: String.t() | nil,
          node_name: atom() | nil
        }

  @type state :: %{
          containers: %{container_id() => container_spec()},
          network_mode: network_mode(),
          tailscale_available: boolean(),
          registry: String.t(),
          podman_socket: String.t() | nil
        }

  # ============================================================
  # CONFIGURATION
  # ============================================================

  @default_registry "localhost/"
  @podman_socket_paths [
    "/run/user/#{System.get_env("UID") || "1000"}/podman/podman.sock",
    "/run/podman/podman.sock"
  ]
  @container_health_interval_ms 15_000
  @container_start_timeout_ms 60_000

  @container_images %{
    app: "indrajaal-app:latest",
    worker: "indrajaal-worker:latest",
    runner: "indrajaal-runner:latest",
    analytics: "indrajaal-analytics:latest",
    video: "indrajaal-video:latest"
  }

  # ============================================================
  # CLIENT API
  # ============================================================

  @doc """
  Start the ContainerCapability GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Start a new container in the mesh.
  """
  @spec start_container(container_type(), keyword()) :: {:ok, container_id()} | {:error, term()}
  def start_container(type, opts \\ []) do
    GenServer.call(__MODULE__, {:start_container, type, opts}, @container_start_timeout_ms)
  end

  @doc """
  Stop a container.
  """
  @spec stop_container(container_id()) :: :ok | {:error, term()}
  def stop_container(container_id) do
    GenServer.call(__MODULE__, {:stop_container, container_id})
  end

  @doc """
  Get container status.
  """
  @spec container_status(container_id()) :: {:ok, container_state()} | {:error, :not_found}
  def container_status(container_id) do
    GenServer.call(__MODULE__, {:container_status, container_id})
  end

  @doc """
  List all managed containers.
  """
  @spec list_containers() :: list(container_spec())
  def list_containers do
    GenServer.call(__MODULE__, :list_containers)
  end

  @doc """
  Get the node name for a container.
  """
  @spec get_container_node(container_id()) :: {:ok, atom()} | {:error, term()}
  def get_container_node(container_id) do
    GenServer.call(__MODULE__, {:get_container_node, container_id})
  end

  @doc """
  Check if Podman is available.
  """
  @spec podman_available?() :: boolean()
  def podman_available? do
    GenServer.call(__MODULE__, :podman_available?)
  end

  @doc """
  Get capability status.
  """
  @impl Indrajaal.Cluster.Capabilities.Behaviour
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc """
  Get capability type.
  """
  @impl Indrajaal.Cluster.Capabilities.Behaviour
  def capability_type, do: :container

  @doc """
  Check if capability is available.
  """
  @impl Indrajaal.Cluster.Capabilities.Behaviour
  def available? do
    GenServer.call(__MODULE__, :podman_available?)
  end

  # ============================================================
  # GENSERVER CALLBACKS
  # ============================================================

  @impl GenServer
  def init(_opts) do
    podman_socket = find_podman_socket()
    tailscale_available = check_tailscale()

    initial_state = %{
      containers: %{},
      network_mode: if(tailscale_available, do: :tailscale, else: :bridge),
      tailscale_available: tailscale_available,
      registry: @default_registry,
      podman_socket: podman_socket
    }

    # Schedule health checks
    :timer.send_interval(@container_health_interval_ms, :health_check_containers)

    Logger.info("[ContainerCapability] Initialized - SC-CNT-009 Podman/Rootless")
    Logger.info("[ContainerCapability] Network mode: #{initial_state.network_mode}")
    {:ok, initial_state}
  end

  @impl GenServer
  def handle_call({:start_container, type, opts}, _from, state) do
    case do_start_container(type, opts, state) do
      {:ok, container_id, new_state} ->
        {:reply, {:ok, container_id}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:stop_container, container_id}, _from, state) do
    case do_stop_container(container_id, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:container_status, container_id}, _from, state) do
    case Map.get(state.containers, container_id) do
      nil -> {:reply, {:error, :not_found}, state}
      spec -> {:reply, {:ok, get_container_runtime_status(spec)}, state}
    end
  end

  @impl GenServer
  def handle_call(:list_containers, _from, state) do
    containers = Map.values(state.containers)
    {:reply, containers, state}
  end

  @impl GenServer
  def handle_call({:get_container_node, container_id}, _from, state) do
    case Map.get(state.containers, container_id) do
      nil -> {:reply, {:error, :not_found}, state}
      spec -> {:reply, {:ok, spec.node_name}, state}
    end
  end

  @impl GenServer
  def handle_call(:podman_available?, _from, state) do
    available = state.podman_socket != nil
    {:reply, available, state}
  end

  @impl GenServer
  def handle_call(:status, _from, state) do
    status = %{
      capability: :container,
      available: state.podman_socket != nil,
      network_mode: state.network_mode,
      tailscale_available: state.tailscale_available,
      container_count: map_size(state.containers),
      registry: state.registry,
      podman_socket: state.podman_socket
    }

    {:reply, status, state}
  end

  @impl GenServer
  def handle_info(:health_check_containers, state) do
    new_state = check_container_health(state)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ============================================================
  # PRIVATE FUNCTIONS
  # ============================================================

  defp find_podman_socket do
    Enum.find(@podman_socket_paths, fn path ->
      File.exists?(path)
    end)
  end

  defp check_tailscale do
    if Code.ensure_loaded?(TailscaleDNS) do
      case TailscaleDNS.validate_tailscale_connectivity() do
        {:ok, _} -> true
        {:error, _} -> false
      end
    else
      false
    end
  end

  defp do_start_container(type, opts, state) do
    container_id = generate_container_id(type)
    image = get_image_name(type, state.registry)

    node_name = build_container_node_name(container_id, type, state)

    spec = %{
      id: container_id,
      type: type,
      image: image,
      env: build_container_env(node_name, opts, state),
      ports: Keyword.get(opts, :ports, []),
      volumes: Keyword.get(opts, :volumes, []),
      network_mode: state.network_mode,
      tailscale_authkey: Keyword.get(opts, :tailscale_authkey),
      node_name: node_name
    }

    case execute_podman_create(spec, state) do
      :ok ->
        case execute_podman_start(container_id) do
          :ok ->
            new_containers = Map.put(state.containers, container_id, spec)
            Logger.info("[ContainerCapability] Started container #{container_id} as #{node_name}")
            {:ok, container_id, %{state | containers: new_containers}}

          {:error, reason} ->
            {:error, {:start_failed, reason}}
        end

      {:error, reason} ->
        {:error, {:create_failed, reason}}
    end
  end

  defp do_stop_container(container_id, state) do
    case Map.get(state.containers, container_id) do
      nil ->
        {:error, :not_found}

      _spec ->
        case execute_podman_stop(container_id) do
          :ok ->
            execute_podman_rm(container_id)
            new_containers = Map.delete(state.containers, container_id)
            Logger.info("[ContainerCapability] Stopped container #{container_id}")
            {:ok, %{state | containers: new_containers}}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp generate_container_id(type) do
    random_bytes = :crypto.strong_rand_bytes(4)
    random_suffix = Base.encode16(random_bytes, case: :lower)
    "indrajaal-#{type}-#{random_suffix}"
  end

  defp get_image_name(type, registry) do
    base_image = Map.get(@container_images, type, "indrajaal-base:latest")
    "#{registry}#{base_image}"
  end

  defp build_container_node_name(container_id, type, state) do
    hostname = NodeNameBuilder.normalize_hostname(container_id)

    NodeNameBuilder.build_node_name(hostname, type, state.network_mode,
      local_suffix: "local.indrajaal"
    )
  end

  defp build_container_env(node_name, opts, state) do
    base_env = %{
      "RELEASE_NODE" => to_string(node_name),
      "RELEASE_COOKIE" => get_release_cookie(),
      "PHX_HOST" => get_phx_host(state),
      "MIX_ENV" => System.get_env("MIX_ENV", "prod")
    }

    # Add Tailscale auth key if available
    tailscale_env =
      case Keyword.get(opts, :tailscale_authkey) do
        nil -> %{}
        key -> %{"TS_AUTHKEY" => key}
      end

    # Add user-provided env
    user_env = Keyword.get(opts, :env, %{})

    base_env
    |> Map.merge(tailscale_env)
    |> Map.merge(user_env)
  end

  defp get_release_cookie do
    System.get_env("RELEASE_COOKIE", "indrajaal_secure_cookie")
  end

  defp get_phx_host(state) do
    case state.network_mode do
      :tailscale -> NodeNameBuilder.get_tailscale_suffix("localhost")
      _ -> "localhost"
    end
  end

  defp execute_podman_create(spec, _state) do
    args = build_podman_create_args(spec)

    case System.cmd("podman", ["create" | args], stderr_to_stdout: true) do
      {_output, 0} -> :ok
      {output, _code} -> {:error, output}
    end
  rescue
    e -> {:error, {:exception, e}}
  end

  defp build_podman_create_args(spec) do
    base_args = [
      "--name",
      spec.id,
      "--hostname",
      spec.id
    ]

    # Environment variables
    env_args =
      Enum.flat_map(spec.env, fn {k, v} ->
        ["--env", "#{k}=#{v}"]
      end)

    # Port mappings
    port_args =
      Enum.flat_map(spec.ports, fn {host, container} ->
        ["--publish", "#{host}:#{container}"]
      end)

    # Volume mounts
    volume_args =
      Enum.flat_map(spec.volumes, fn {host, container} ->
        ["--volume", "#{host}:#{container}"]
      end)

    # Network mode
    network_args =
      case spec.network_mode do
        :tailscale -> ["--network", "tailscale"]
        :bridge -> ["--network", "bridge"]
        _ -> []
      end

    # Security options (SC-CNT-012: Rootless)
    security_args = [
      "--security-opt",
      "no-new-privileges:true",
      "--read-only-tmpfs"
    ]

    base_args ++
      env_args ++ port_args ++ volume_args ++ network_args ++ security_args ++ [spec.image]
  end

  defp execute_podman_start(container_id) do
    case System.cmd("podman", ["start", container_id], stderr_to_stdout: true) do
      {_output, 0} -> :ok
      {output, _code} -> {:error, output}
    end
  rescue
    e -> {:error, {:exception, e}}
  end

  defp execute_podman_stop(container_id) do
    case System.cmd("podman", ["stop", "-t", "30", container_id], stderr_to_stdout: true) do
      {_output, 0} -> :ok
      {output, _code} -> {:error, output}
    end
  rescue
    e -> {:error, {:exception, e}}
  end

  defp execute_podman_rm(container_id) do
    System.cmd("podman", ["rm", "-f", container_id], stderr_to_stdout: true)
    :ok
  rescue
    _ -> :ok
  end

  defp get_container_runtime_status(spec) do
    case System.cmd("podman", ["inspect", "-f", "{{.State.Status}}", spec.id],
           stderr_to_stdout: true
         ) do
      {"running\n", 0} -> :running
      {"created\n", 0} -> :pending
      {"exited\n", 0} -> :stopped
      {"paused\n", 0} -> :stopping
      _ -> :failed
    end
  rescue
    _ -> :failed
  end

  defp check_container_health(state) do
    updated_containers =
      Map.new(state.containers, fn {id, spec} ->
        status = get_container_runtime_status(spec)

        if status == :failed do
          Logger.warning("[ContainerCapability] Container #{id} is in failed state")
        end

        {id, spec}
      end)

    # Also check if Tailscale availability changed
    tailscale_available = check_tailscale()
    new_mode = if tailscale_available, do: :tailscale, else: :bridge

    if new_mode != state.network_mode do
      Logger.info(
        "[ContainerCapability] Network mode changed: #{state.network_mode} -> #{new_mode}"
      )
    end

    %{
      state
      | containers: updated_containers,
        tailscale_available: tailscale_available,
        network_mode: new_mode
    }
  end
end
