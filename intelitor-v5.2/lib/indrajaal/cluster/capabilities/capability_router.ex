defmodule Indrajaal.Cluster.Capabilities.CapabilityRouter do
  @moduledoc """
  Unified Capability Router for Multi-Backend Mesh Networking.

  WHAT: Routes compute requests to appropriate backends (Process, Container, K8s, Proxmox).
  WHY: SC-CLU-001 requires unified identity networking across all compute types.
  CONSTRAINTS: Must prioritize Tailscale naming; fallback chain when backends unavailable.

  ## Architecture

  This module provides:
  1. **Backend Discovery**: Detects available backends at runtime
  2. **Intelligent Routing**: Routes based on workload type and backend availability
  3. **Failover Chain**: Process -> Container -> K8s -> Proxmox (configurable)
  4. **Unified Naming**: All backends use consistent Tailscale/local naming

  ## STAMP Constraints
  - SC-CLU-001: Identity-based networking (unified across all backends)
  - SC-CLU-004: Graceful degradation (failover chain)
  - SC-FLAME-001: Stateless compute (all backends)
  - SC-FLAME-002: Secure RPC (capability tokens)

  ## Backend Priority (Default)
  1. Process - Fastest, lowest overhead, same node
  2. Container - Good isolation, fast startup
  3. K8s - Elastic scaling, cloud-native
  4. Proxmox - Maximum isolation, persistent VMs

  ## Usage

      # Get best available backend
      {:ok, backend} = CapabilityRouter.get_backend(:runner)

      # Route to specific capability
      {:ok, node} = CapabilityRouter.route_to(:container, :video, opts)

      # Get mesh status
      status = CapabilityRouter.mesh_status()
  """

  use GenServer
  require Logger

  alias Indrajaal.Cluster.ProcessCapability
  alias Indrajaal.Cluster.Capabilities.{ContainerCapability, K8sCapability, ProxmoxCapability}
  alias Indrajaal.Cluster.TailscaleDNS

  # ============================================================
  # TYPE DEFINITIONS
  # ============================================================

  @type capability_type :: :process | :container | :k8s | :proxmox
  @type workload_type ::
          :runner | :worker | :analytics | :video | :intelligence | :compute | :storage
  @type network_mode :: :tailscale | :local | :hybrid

  @type backend_status :: %{
          capability: capability_type(),
          available: boolean(),
          network_mode: network_mode(),
          node_count: non_neg_integer()
        }

  @type routing_strategy :: :priority | :round_robin | :least_loaded | :affinity

  @type state :: %{
          backends: %{capability_type() => pid() | nil},
          priority_chain: [capability_type()],
          routing_strategy: routing_strategy(),
          network_mode: network_mode(),
          tailscale_available: boolean(),
          workload_affinity: %{workload_type() => [capability_type()]},
          stats: %{capability_type() => map()}
        }

  # ============================================================
  # CONFIGURATION
  # ============================================================

  @default_priority_chain [:process, :container, :k8s, :proxmox]

  @default_workload_affinity %{
    runner: [:process, :container],
    worker: [:process, :container, :k8s],
    analytics: [:container, :k8s],
    video: [:container, :k8s, :proxmox],
    intelligence: [:k8s, :proxmox],
    compute: [:k8s, :proxmox],
    storage: [:proxmox]
  }

  @health_check_interval_ms 15_000

  # ============================================================
  # CLIENT API
  # ============================================================

  @doc """
  Start the CapabilityRouter GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get the best available backend for a workload type.
  """
  @spec get_backend(workload_type()) :: {:ok, capability_type()} | {:error, :no_backend_available}
  def get_backend(workload_type) do
    GenServer.call(__MODULE__, {:get_backend, workload_type})
  end

  @doc """
  Route a request to a specific capability and create a compute node.
  """
  @spec route_to(capability_type(), workload_type(), keyword()) ::
          {:ok, atom()} | {:error, term()}
  def route_to(capability, workload_type, opts \\ []) do
    GenServer.call(__MODULE__, {:route_to, capability, workload_type, opts})
  end

  @doc """
  Get status of all backends.
  """
  @spec mesh_status() :: %{capability_type() => backend_status()}
  def mesh_status do
    GenServer.call(__MODULE__, :mesh_status)
  end

  @doc """
  Get current network mode (tailscale/local/hybrid).
  """
  @spec network_mode() :: network_mode()
  def network_mode do
    GenServer.call(__MODULE__, :network_mode)
  end

  @doc """
  List all available backends.
  """
  @spec available_backends() :: [capability_type()]
  def available_backends do
    GenServer.call(__MODULE__, :available_backends)
  end

  @doc """
  Set the routing strategy.
  """
  @spec set_routing_strategy(routing_strategy()) :: :ok
  def set_routing_strategy(strategy) do
    GenServer.cast(__MODULE__, {:set_routing_strategy, strategy})
  end

  @doc """
  Get unified node name for current host.
  """
  @spec get_node_name() :: atom()
  def get_node_name do
    GenServer.call(__MODULE__, :get_node_name)
  end

  @doc """
  Resolve a hostname to node name using appropriate backend.
  """
  @spec resolve_node(String.t()) :: {:ok, atom()} | {:error, term()}
  def resolve_node(hostname) do
    GenServer.call(__MODULE__, {:resolve_node, hostname})
  end

  @doc """
  Check if Tailscale mesh is active.
  """
  @spec tailscale_active?() :: boolean()
  def tailscale_active? do
    GenServer.call(__MODULE__, :tailscale_active?)
  end

  # ============================================================
  # GENSERVER CALLBACKS
  # ============================================================

  @impl GenServer
  def init(opts) do
    # Discover available backends
    backends = discover_backends()
    tailscale_available = check_tailscale()

    network_mode =
      cond do
        tailscale_available -> :tailscale
        Enum.any?(backends, fn {_, available} -> available end) -> :local
        true -> :local
      end

    priority_chain = Keyword.get(opts, :priority_chain, @default_priority_chain)
    routing_strategy = Keyword.get(opts, :routing_strategy, :priority)

    initial_state = %{
      backends: backends,
      priority_chain: priority_chain,
      routing_strategy: routing_strategy,
      network_mode: network_mode,
      tailscale_available: tailscale_available,
      workload_affinity: @default_workload_affinity,
      stats: initialize_stats()
    }

    # Schedule health checks
    :timer.send_interval(@health_check_interval_ms, :health_check)

    Logger.info(
      "[CapabilityRouter] Initialized - Tailscale: #{tailscale_available}, Backends: #{inspect(Map.keys(backends))}"
    )

    {:ok, initial_state}
  end

  @impl GenServer
  def handle_call({:get_backend, workload_type}, _from, state) do
    result = find_best_backend(workload_type, state)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:route_to, capability, workload_type, opts}, _from, state) do
    result = do_route_to(capability, workload_type, opts, state)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call(:mesh_status, _from, state) do
    status =
      state.backends
      |> Enum.map(fn {capability, available} ->
        {capability,
         %{
           capability: capability,
           available: available,
           network_mode: state.network_mode,
           node_count: get_node_count(capability)
         }}
      end)
      |> Map.new()

    {:reply, status, state}
  end

  @impl GenServer
  def handle_call(:network_mode, _from, state) do
    {:reply, state.network_mode, state}
  end

  @impl GenServer
  def handle_call(:available_backends, _from, state) do
    available =
      state.backends
      |> Enum.filter(fn {_, available} -> available end)
      |> Enum.map(fn {type, _} -> type end)

    {:reply, available, state}
  end

  @impl GenServer
  def handle_call(:get_node_name, _from, state) do
    node_name = build_node_name(state)
    {:reply, node_name, state}
  end

  @impl GenServer
  def handle_call({:resolve_node, hostname}, _from, state) do
    result = resolve_hostname(hostname, state)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call(:tailscale_active?, _from, state) do
    {:reply, state.tailscale_available, state}
  end

  @impl GenServer
  def handle_cast({:set_routing_strategy, strategy}, state) do
    Logger.info("[CapabilityRouter] Routing strategy changed to: #{strategy}")
    {:noreply, %{state | routing_strategy: strategy}}
  end

  @impl GenServer
  def handle_info(:health_check, state) do
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

  defp discover_backends do
    %{
      process: check_process_capability(),
      container: check_container_capability(),
      k8s: check_k8s_capability(),
      proxmox: check_proxmox_capability()
    }
  end

  defp check_process_capability do
    if Code.ensure_loaded?(ProcessCapability) do
      case GenServer.whereis(ProcessCapability) do
        nil -> false
        _pid -> true
      end
    else
      # Process capability is always available as fallback
      true
    end
  end

  defp check_container_capability do
    if Code.ensure_loaded?(ContainerCapability) do
      case GenServer.whereis(ContainerCapability) do
        nil -> false
        _pid -> ContainerCapability.available?()
      end
    else
      false
    end
  rescue
    _ -> false
  end

  defp check_k8s_capability do
    if Code.ensure_loaded?(K8sCapability) do
      case GenServer.whereis(K8sCapability) do
        nil -> false
        _pid -> K8sCapability.available?()
      end
    else
      false
    end
  rescue
    _ -> false
  end

  defp check_proxmox_capability do
    if Code.ensure_loaded?(ProxmoxCapability) do
      case GenServer.whereis(ProxmoxCapability) do
        nil -> false
        _pid -> ProxmoxCapability.available?()
      end
    else
      false
    end
  rescue
    _ -> false
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

  defp initialize_stats do
    %{
      process: %{requests: 0, successes: 0, failures: 0},
      container: %{requests: 0, successes: 0, failures: 0},
      k8s: %{requests: 0, successes: 0, failures: 0},
      proxmox: %{requests: 0, successes: 0, failures: 0}
    }
  end

  defp find_best_backend(workload_type, state) do
    # Get affinity list for this workload
    affinity = Map.get(state.workload_affinity, workload_type, state.priority_chain)

    # Filter by availability and find first available
    case Enum.find(affinity, fn cap -> Map.get(state.backends, cap, false) end) do
      nil ->
        # Fallback to priority chain
        case Enum.find(state.priority_chain, fn cap -> Map.get(state.backends, cap, false) end) do
          nil -> {:error, :no_backend_available}
          cap -> {:ok, cap}
        end

      cap ->
        {:ok, cap}
    end
  end

  defp do_route_to(capability, workload_type, opts, state) do
    if Map.get(state.backends, capability, false) do
      case capability do
        :process ->
          route_to_process(workload_type, opts, state)

        :container ->
          route_to_container(workload_type, opts, state)

        :k8s ->
          route_to_k8s(workload_type, opts, state)

        :proxmox ->
          route_to_proxmox(workload_type, opts, state)

        _ ->
          {:error, {:unknown_capability, capability}}
      end
    else
      {:error, {:backend_unavailable, capability}}
    end
  end

  defp route_to_process(_workload_type, _opts, state) do
    node_name = build_node_name(state)
    {:ok, node_name}
  end

  defp route_to_container(workload_type, opts, _state) do
    type =
      case workload_type do
        :runner -> :runner
        :worker -> :worker
        :analytics -> :analytics
        :video -> :video
        _ -> :worker
      end

    case ContainerCapability.start_container(type, opts) do
      {:ok, container_id} ->
        ContainerCapability.get_container_node(container_id)

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e -> {:error, {:exception, e}}
  end

  defp route_to_k8s(workload_type, opts, _state) do
    type =
      case workload_type do
        :runner -> :runner
        :worker -> :worker
        :analytics -> :analytics
        :video -> :video
        :intelligence -> :intelligence
        _ -> :worker
      end

    case K8sCapability.create_pod(type, opts) do
      {:ok, pod_id} ->
        K8sCapability.get_pod_node(pod_id)

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e -> {:error, {:exception, e}}
  end

  defp route_to_proxmox(workload_type, opts, _state) do
    type =
      case workload_type do
        :video -> :video
        :intelligence -> :inference
        :compute -> :compute
        :analytics -> :analytics
        :storage -> :storage
        _ -> :compute
      end

    case ProxmoxCapability.create_vm(type, opts) do
      {:ok, vmid} ->
        case ProxmoxCapability.start_vm(vmid) do
          :ok -> ProxmoxCapability.get_vm_node(vmid)
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e -> {:error, {:exception, e}}
  end

  defp build_node_name(state) do
    hostname = get_local_hostname()

    case state.network_mode do
      :tailscale ->
        suffix = get_tailscale_suffix()
        :"indrajaal@#{hostname}.#{suffix}"

      _ ->
        :"indrajaal@#{hostname}.local.indrajaal"
    end
  end

  defp get_local_hostname do
    case :inet.gethostname() do
      {:ok, name} -> to_string(name)
      _ -> "localhost"
    end
  end

  defp get_tailscale_suffix do
    if Code.ensure_loaded?(TailscaleDNS) do
      TailscaleDNS.get_tailnet_suffix()
    else
      "local.indrajaal"
    end
  end

  defp resolve_hostname(hostname, state) do
    case state.network_mode do
      :tailscale ->
        suffix = get_tailscale_suffix()
        {:ok, :"indrajaal@#{hostname}.#{suffix}"}

      _ ->
        {:ok, :"indrajaal@#{hostname}.local.indrajaal"}
    end
  end

  defp get_node_count(capability) do
    case capability do
      :process -> 1
      :container -> get_container_count()
      :k8s -> get_pod_count()
      :proxmox -> get_vm_count()
    end
  end

  defp get_container_count do
    if Code.ensure_loaded?(ContainerCapability) do
      try do
        length(ContainerCapability.list_containers())
      rescue
        _ -> 0
      catch
        :exit, _ -> 0
        _, _ -> 0
      end
    else
      0
    end
  end

  defp get_pod_count do
    if Code.ensure_loaded?(K8sCapability) do
      try do
        length(K8sCapability.list_pods())
      rescue
        _ -> 0
      catch
        :exit, _ -> 0
        _, _ -> 0
      end
    else
      0
    end
  end

  defp get_vm_count do
    if Code.ensure_loaded?(ProxmoxCapability) do
      try do
        length(ProxmoxCapability.list_vms())
      rescue
        _ -> 0
      catch
        :exit, _ -> 0
        _, _ -> 0
      end
    else
      0
    end
  end

  defp perform_health_check(state) do
    new_backends = discover_backends()
    new_tailscale = check_tailscale()

    new_mode =
      cond do
        new_tailscale -> :tailscale
        Enum.any?(new_backends, fn {_, available} -> available end) -> :local
        true -> :local
      end

    if new_mode != state.network_mode do
      Logger.info(
        "[CapabilityRouter] Network mode changed: #{state.network_mode} -> #{new_mode} - SC-CLU-004"
      )
    end

    # Log backend availability changes
    Enum.each(new_backends, fn {cap, available} ->
      old_available = Map.get(state.backends, cap, false)

      if available != old_available do
        Logger.info(
          "[CapabilityRouter] Backend #{cap} availability: #{old_available} -> #{available}"
        )
      end
    end)

    %{
      state
      | backends: new_backends,
        network_mode: new_mode,
        tailscale_available: new_tailscale
    }
  end
end
