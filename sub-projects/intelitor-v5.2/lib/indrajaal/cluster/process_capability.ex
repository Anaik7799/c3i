defmodule Indrajaal.Cluster.ProcessCapability do
  @moduledoc """
  ProcessCapability Backend for FLAME Mesh Networking.

  WHAT: Capability-based process backend for distributed compute in standalone/mesh environments.
  WHY: SC-FLAME-001 requires stateless runners; SC-CLU-001 requires identity-based networking.
  CONSTRAINTS: Must use Tailscale names when available, fallback to local when Tailscale is down.

  ## Architecture

  This module provides:
  1. **Capability Token Management**: Secure tokens for inter-node communication
  2. **Node Resolution**: Tailscale-first with local fallback
  3. **FLAME Backend Interface**: Via nested FlameBackend module

  ## STAMP Constraints
  - SC-FLAME-001: No local state in runners
  - SC-FLAME-002: Secure RPC for FLAME tasks
  - SC-CLU-001: Identity-based networking (Tailscale)
  - SC-CLU-004: Graceful degradation when Tailscale unavailable

  ## Usage

      config :flame, :backend, Indrajaal.Cluster.ProcessCapability.FlameBackend

  """

  use GenServer
  require Logger

  alias Indrajaal.Cluster.TailscaleDNS

  # ============================================================
  # TYPE DEFINITIONS
  # ============================================================

  @type capability_token :: binary()
  @type node_ref :: {node(), capability_token()}
  @type network_mode :: :tailscale | :local | :hybrid

  @type state :: %{
          mode: network_mode(),
          capabilities: %{node() => capability_token()},
          node_cache: %{String.t() => node()},
          tailscale_available: boolean(),
          local_node_name: node(),
          tailscale_node_name: node() | nil,
          last_health_check: DateTime.t() | nil
        }

  # ============================================================
  # CONFIGURATION
  # ============================================================

  @capability_token_bytes 32
  @health_check_interval_ms 30_000
  @tailscale_check_timeout_ms 5_000
  @default_local_suffix "local.indrajaal"

  # ============================================================
  # CLIENT API
  # ============================================================

  @doc """
  Start the ProcessCapability GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get the current network mode.
  """
  @spec network_mode() :: network_mode()
  def network_mode do
    GenServer.call(__MODULE__, :network_mode)
  end

  @doc """
  Get node name for the current environment.
  Returns Tailscale name if available, local name otherwise.
  """
  @spec get_node_name() :: node()
  def get_node_name do
    GenServer.call(__MODULE__, :get_node_name)
  end

  @doc """
  Resolve a hostname to a node reference with capability token.
  """
  @spec resolve_node(String.t()) :: {:ok, node_ref()} | {:error, term()}
  def resolve_node(hostname) do
    GenServer.call(__MODULE__, {:resolve_node, hostname})
  end

  @doc """
  Generate a capability token for a node.
  """
  @spec generate_capability(node()) :: {:ok, capability_token()} | {:error, term()}
  def generate_capability(target_node) do
    GenServer.call(__MODULE__, {:generate_capability, target_node})
  end

  @doc """
  Validate a capability token for a node.
  """
  @spec validate_capability(node(), capability_token()) :: boolean()
  def validate_capability(target_node, token) do
    GenServer.call(__MODULE__, {:validate_capability, target_node, token})
  end

  @doc """
  Check if Tailscale is currently available.
  """
  @spec tailscale_available?() :: boolean()
  def tailscale_available? do
    GenServer.call(__MODULE__, :tailscale_available?)
  end

  @doc """
  Force a health check of network connectivity.
  """
  @spec health_check() :: :ok
  def health_check do
    GenServer.cast(__MODULE__, :health_check)
  end

  @doc """
  Get current status of the ProcessCapability system.
  """
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  end

  # ============================================================
  # GENSERVER CALLBACKS
  # ============================================================

  @impl GenServer
  def init(_opts) do
    # Initialize state
    initial_state = %{
      mode: :local,
      capabilities: %{},
      node_cache: %{},
      tailscale_available: false,
      local_node_name: build_local_node_name(),
      tailscale_node_name: nil,
      last_health_check: nil
    }

    # Schedule initial health check
    send(self(), :perform_health_check)

    # Schedule periodic health checks
    :timer.send_interval(@health_check_interval_ms, :perform_health_check)

    Logger.info("[ProcessCapability] Initialized - SC-CLU-001 Identity Networking")
    {:ok, initial_state}
  end

  @impl GenServer
  def handle_call(:network_mode, _from, state) do
    {:reply, state.mode, state}
  end

  @impl GenServer
  def handle_call(:get_node_name, _from, state) do
    node_name = effective_node_name(state)
    {:reply, node_name, state}
  end

  @impl GenServer
  def handle_call({:resolve_node, hostname}, _from, state) do
    case resolve_hostname(hostname, state) do
      {:ok, node} ->
        token = get_or_create_capability(node, state)
        {:reply, {:ok, {node, token}}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:generate_capability, target_node}, _from, state) do
    token = generate_token()
    new_capabilities = Map.put(state.capabilities, target_node, token)
    {:reply, {:ok, token}, %{state | capabilities: new_capabilities}}
  end

  @impl GenServer
  def handle_call({:validate_capability, target_node, token}, _from, state) do
    valid =
      case Map.get(state.capabilities, target_node) do
        ^token -> true
        _ -> false
      end

    {:reply, valid, state}
  end

  @impl GenServer
  def handle_call(:tailscale_available?, _from, state) do
    {:reply, state.tailscale_available, state}
  end

  @impl GenServer
  def handle_call(:status, _from, state) do
    status = %{
      mode: state.mode,
      tailscale_available: state.tailscale_available,
      local_node_name: state.local_node_name,
      tailscale_node_name: state.tailscale_node_name,
      active_capabilities: map_size(state.capabilities),
      cached_nodes: map_size(state.node_cache),
      last_health_check: state.last_health_check
    }

    {:reply, status, state}
  end

  @impl GenServer
  def handle_cast(:health_check, state) do
    send(self(), :perform_health_check)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:perform_health_check, state) do
    new_state = perform_health_check(state)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ============================================================
  # PRIVATE FUNCTIONS
  # ============================================================

  defp build_local_node_name do
    hostname = get_local_hostname()
    :"indrajaal@#{hostname}.#{@default_local_suffix}"
  end

  @doc false
  def get_local_hostname do
    case :inet.gethostname() do
      {:ok, name} -> to_string(name)
      _ -> "localhost"
    end
  end

  defp effective_node_name(state) do
    case state.mode do
      :tailscale -> state.tailscale_node_name || state.local_node_name
      :hybrid -> state.tailscale_node_name || state.local_node_name
      :local -> state.local_node_name
    end
  end

  defp perform_health_check(state) do
    tailscale_result = check_tailscale_availability()

    {new_mode, ts_available, ts_node} =
      case tailscale_result do
        {:ok, ts_node_name} ->
          {:tailscale, true, ts_node_name}

        {:error, :timeout} ->
          # Tailscale might be slow, keep hybrid mode
          Logger.warning("[ProcessCapability] Tailscale check timed out, using hybrid mode")
          {:hybrid, false, state.tailscale_node_name}

        {:error, _reason} ->
          # Tailscale unavailable, fallback to local
          Logger.info(
            "[ProcessCapability] Tailscale unavailable, falling back to local - SC-CLU-004"
          )

          {:local, false, nil}
      end

    %{
      state
      | mode: new_mode,
        tailscale_available: ts_available,
        tailscale_node_name: ts_node,
        last_health_check: DateTime.utc_now()
    }
  end

  defp check_tailscale_availability do
    # Use TailscaleDNS module if available
    if Code.ensure_loaded?(TailscaleDNS) do
      task =
        Task.async(fn ->
          try do
            case TailscaleDNS.validate_tailscale_connectivity() do
              {:ok, _info} ->
                node_name = TailscaleDNS.get_node_name(:app, get_local_hostname())
                {:ok, node_name}

              {:error, reason} ->
                {:error, reason}
            end
          rescue
            e -> {:error, {:exception, e}}
          end
        end)

      case Task.yield(task, @tailscale_check_timeout_ms) || Task.shutdown(task, :brutal_kill) do
        {:ok, result} -> result
        nil -> {:error, :timeout}
      end
    else
      {:error, :tailscale_dns_not_loaded}
    end
  end

  defp resolve_hostname(hostname, state) do
    # Check cache first
    case Map.get(state.node_cache, hostname) do
      nil ->
        # Resolve based on mode
        case state.mode do
          :tailscale ->
            resolve_tailscale_hostname(hostname)

          :hybrid ->
            case resolve_tailscale_hostname(hostname) do
              {:ok, node} -> {:ok, node}
              {:error, _} -> resolve_local_hostname(hostname)
            end

          :local ->
            resolve_local_hostname(hostname)
        end

      node ->
        {:ok, node}
    end
  end

  defp resolve_tailscale_hostname(hostname) do
    if Code.ensure_loaded?(TailscaleDNS) do
      suffix = TailscaleDNS.get_tailnet_suffix()
      node = :"indrajaal@#{hostname}.#{suffix}"
      {:ok, node}
    else
      {:error, :tailscale_dns_not_loaded}
    end
  end

  defp resolve_local_hostname(hostname) do
    node = :"indrajaal@#{hostname}.#{@default_local_suffix}"
    {:ok, node}
  end

  defp get_or_create_capability(node, state) do
    case Map.get(state.capabilities, node) do
      nil -> generate_token()
      token -> token
    end
  end

  defp generate_token do
    random_bytes = :crypto.strong_rand_bytes(@capability_token_bytes)
    Base.url_encode64(random_bytes, padding: false)
  end

  # ============================================================
  # NESTED FLAME.Backend MODULE
  # ============================================================

  defmodule FlameBackend do
    @moduledoc """
    FLAME.Backend implementation for ProcessCapability.

    This nested module implements the FLAME.Backend behaviour separately
    from the GenServer, avoiding callback conflicts.

    ## Usage

        config :flame, :backend, Indrajaal.Cluster.ProcessCapability.FlameBackend

    """

    @behaviour FLAME.Backend
    require Logger

    @impl FLAME.Backend
    def init(opts) do
      # Initialize as FLAME backend
      parent = Keyword.get(opts, :parent, self())
      log = Keyword.get(opts, :log, :debug)

      state = %{
        parent: parent,
        log: log,
        runner_pid: nil,
        runner_node: nil
      }

      {:ok, state}
    end

    @impl FLAME.Backend
    def remote_spawn_monitor(state, term) do
      # Spawn a process on the appropriate node based on network mode
      node = determine_target_node(state)

      Logger.debug("[ProcessCapability.FlameBackend] Spawning on node: #{inspect(node)}")

      case spawn_on_node(node, term) do
        {:ok, pid} ->
          ref = Process.monitor(pid)
          {:ok, {pid, ref}, %{state | runner_pid: pid, runner_node: node}}

        {:error, reason} ->
          {:error, reason}
      end
    end

    @impl FLAME.Backend
    def remote_boot(_state) do
      # For process capability, we don't need to "boot" external resources
      # The node is already running; we just connect
      {:ok, %{}}
    end

    @impl FLAME.Backend
    def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
      if state.runner_pid == pid do
        Logger.debug(
          "[ProcessCapability.FlameBackend] Runner #{inspect(pid)} exited: #{inspect(reason)}"
        )

        {:stop, reason, %{state | runner_pid: nil}}
      else
        {:noreply, state}
      end
    end

    def handle_info(_msg, state) do
      {:noreply, state}
    end

    @impl FLAME.Backend
    def system_shutdown do
      Logger.info("[ProcessCapability.FlameBackend] System shutdown requested")
      :ok
    end

    # ============================================================
    # PRIVATE FUNCTIONS
    # ============================================================

    defp determine_target_node(state) do
      # For now, run on local node
      # Future: Use load balancing across mesh nodes
      case state.runner_node do
        nil -> node()
        existing -> existing
      end
    end

    defp spawn_on_node(target_node, term) when target_node == node() do
      # Local spawn
      try do
        pid = spawn(fn -> execute_term(term) end)
        {:ok, pid}
      rescue
        e -> {:error, {:spawn_failed, e}}
      end
    end

    defp spawn_on_node(target_node, term) do
      # Remote spawn on cluster node
      try do
        pid = Node.spawn(target_node, fn -> execute_term(term) end)
        {:ok, pid}
      rescue
        e -> {:error, {:remote_spawn_failed, e}}
      end
    end

    defp execute_term(term) when is_function(term, 0) do
      term.()
    end

    defp execute_term({mod, fun, args}) do
      apply(mod, fun, args)
    end

    defp execute_term(_term) do
      Logger.error("[ProcessCapability.FlameBackend] Invalid term for execution")
      :error
    end
  end
end
