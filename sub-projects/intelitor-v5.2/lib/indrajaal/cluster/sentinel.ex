defmodule Indrajaal.Cluster.Sentinel do
  @moduledoc """
  The Immune System of the Cluster.
  Monitors node membership and enforces Quorum to prevent Split-Brain (SC-CLU-005).

  STAMP Compliance:
  - SC-CLU-001: Identity-based networking via Tailscale DNS
  - SC-CLU-002: Minimum 3 nodes for HA
  - SC-CLU-005: Split-brain prevention with consistent naming

  All node names are validated against Tailscale DNS format to ensure
  identity-based networking per STAMP requirements.
  """
  use GenServer
  require Logger

  alias Indrajaal.Cluster.TailscaleDNS

  defstruct [
    # MapSet of connected nodes (Tailscale DNS names)
    :active_nodes,
    # Total nodes in topology (from config)
    :total_expected,
    # :healthy | :degraded | :partitioned
    :status,
    # Tailscale DNS suffix for validation
    :tailnet_suffix,
    # Expected quorum nodes from config
    :quorum_nodes
  ]

  # --- Client API ---

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Get current cluster status including Tailscale DNS information.
  Returns map with active_nodes, status, tailnet_suffix, and quorum info.
  """
  def get_status(pid \\ __MODULE__) do
    GenServer.call(pid, :get_status)
  end

  @doc """
  Get list of active nodes with Tailscale DNS validation status.
  """
  def get_active_nodes(pid \\ __MODULE__) do
    GenServer.call(pid, :get_active_nodes)
  end

  @doc """
  Check if a specific node is part of the quorum.
  """
  def quorum_member?(node, pid \\ __MODULE__) do
    GenServer.call(pid, {:is_quorum_member, node})
  end

  # --- Server Callbacks ---

  @doc """
  Check if quorum is lost for a given active count.
  """
  def is_quorum_lost(pid \\ __MODULE__, active_count) do
    total = GenServer.call(pid, :get_total_expected)
    threshold = div(total, 2) + 1
    active_count < threshold
  end

  @doc """
  Get the current members of the cluster (active nodes).
  """
  def get_members(pid \\ __MODULE__) do
    status = get_status(pid)
    Enum.map(status.active_nodes, & &1.node)
  end

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    Logger.info("🛡️ Sentinel: Activating Safety Kernel with Tailscale DNS validation...")
    :net_kernel.monitor_nodes(true)

    # Get expected topology size (default 3 for HA - SC-CLU-002)
    # Allow override from opts for testing
    total =
      Keyword.get(opts, :total_expected) || Application.get_env(:indrajaal, :cluster_size, 3)

    # Get Tailscale DNS configuration
    tailnet_suffix = TailscaleDNS.get_tailnet_suffix()
    quorum_nodes = TailscaleDNS.get_quorum_nodes()

    # Validate current node uses Tailscale DNS naming (SC-CLU-001)
    current_node = Node.self()

    if TailscaleDNS.valid_quorum_node?(current_node) do
      Logger.info("🛡️ Sentinel: Current node #{current_node} validated for Tailscale DNS")
    else
      Logger.warning(
        "🛡️ Sentinel: Current node #{current_node} does NOT use Tailscale DNS format. " <>
          "Expected suffix: #{tailnet_suffix}"
      )
    end

    state = %__MODULE__{
      active_nodes: MapSet.new([current_node]),
      total_expected: total,
      status: :healthy,
      tailnet_suffix: tailnet_suffix,
      quorum_nodes: MapSet.new(quorum_nodes)
    }

    {:ok, state}
  end

  @impl true
  def handle_info({:nodeup, node}, state) do
    # SC-CLU-001: Validate joining node uses Tailscale DNS
    if TailscaleDNS.valid_quorum_node?(node) do
      Logger.info("🛡️ Sentinel: Node Joined (Tailscale DNS validated) - #{node}")
    else
      Logger.warning(
        "🛡️ Sentinel: Node Joined but NOT using Tailscale DNS format - #{node}. " <>
          "Expected suffix containing: #{state.tailnet_suffix}"
      )
    end

    # Convert to Tailscale DNS name if needed for consistency (SC-CLU-005)
    normalized_node = TailscaleDNS.node_to_tailscale_name(node)
    new_nodes = MapSet.put(state.active_nodes, normalized_node)
    new_state = check_quorum(%{state | active_nodes: new_nodes})
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:nodedown, node}, state) do
    Logger.warning("🛡️ Sentinel: Node Lost - #{node}")

    # Normalize node name for consistent tracking (SC-CLU-005)
    normalized_node = TailscaleDNS.node_to_tailscale_name(node)
    new_nodes = MapSet.delete(state.active_nodes, normalized_node)
    # Also try removing the original in case it wasn't normalized
    new_nodes = MapSet.delete(new_nodes, node)

    # 5-second debounce would go here (implementing direct for now)
    new_state = check_quorum(%{state | active_nodes: new_nodes})
    {:noreply, new_state}
  end

  # Simulation handlers for testing
  @impl true
  def handle_info({:simulate_node_join, node}, state) do
    new_nodes = MapSet.put(state.active_nodes, node)
    {:noreply, %{state | active_nodes: new_nodes}}
  end

  @impl true
  def handle_info({:simulate_node_leave, node, caller}, state) do
    new_nodes = MapSet.delete(state.active_nodes, node)
    new_state = %{state | active_nodes: new_nodes}

    active_count = MapSet.size(new_nodes)
    quorum_threshold = div(state.total_expected, 2) + 1

    if active_count < quorum_threshold do
      # Only send notifications if we weren't already partitioned
      if state.status != :partitioned do
        send(caller, {:quorum_lost, self()})
        send(caller, {:intentional_leave, self()})
      end

      {:noreply, %{new_state | status: :partitioned}}
    else
      {:noreply, new_state}
    end
  end

  @impl true
  def handle_info({:simulate_initial_members, members}, state) do
    {:noreply, %{state | active_nodes: MapSet.new(members)}}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    active_count = MapSet.size(state.active_nodes)
    quorum_threshold = div(state.total_expected, 2) + 1

    # Validate all active nodes against Tailscale DNS
    validated_nodes =
      state.active_nodes
      |> MapSet.to_list()
      |> Enum.map(fn node ->
        %{
          node: node,
          tailscale_valid: TailscaleDNS.valid_quorum_node?(node)
        }
      end)

    status_map = %{
      status: state.status,
      active_count: active_count,
      total_expected: state.total_expected,
      quorum_threshold: quorum_threshold,
      has_quorum: active_count >= quorum_threshold,
      tailnet_suffix: state.tailnet_suffix,
      active_nodes: validated_nodes,
      expected_quorum_nodes: MapSet.to_list(state.quorum_nodes)
    }

    {:reply, status_map, state}
  end

  @impl true
  def handle_call(:get_total_expected, _from, state) do
    {:reply, state.total_expected, state}
  end

  @impl true
  def handle_call(:get_active_nodes, _from, state) do
    nodes =
      state.active_nodes
      |> MapSet.to_list()
      |> Enum.map(fn node ->
        %{
          node: node,
          tailscale_valid: TailscaleDNS.valid_quorum_node?(node),
          in_expected_quorum: MapSet.member?(state.quorum_nodes, node)
        }
      end)

    {:reply, nodes, state}
  end

  @impl true
  def handle_call({:is_quorum_member, node}, _from, state) do
    # Normalize node name for consistent checking
    normalized = TailscaleDNS.node_to_tailscale_name(node)

    is_member =
      MapSet.member?(state.active_nodes, normalized) or MapSet.member?(state.active_nodes, node)

    {:reply, is_member, state}
  end

  defp check_quorum(state) do
    active_count = MapSet.size(state.active_nodes)
    quorum_threshold = div(state.total_expected, 2) + 1

    # SC-CLU-001: Log Tailscale DNS validation status
    valid_tailscale_count =
      state.active_nodes
      |> MapSet.to_list()
      |> Enum.count(&TailscaleDNS.valid_quorum_node?/1)

    if active_count >= quorum_threshold do
      if state.status != :healthy do
        Logger.info(
          "🛡️ Sentinel: Quorum Restored (#{active_count}/#{state.total_expected}), " <>
            "Tailscale DNS validated: #{valid_tailscale_count}/#{active_count}"
        )
      end

      %{state | status: :healthy}
    else
      Logger.critical(
        "🚨 Sentinel: QUORUM LOST! (#{active_count}/#{state.total_expected}). " <>
          "Tailscale DNS validated: #{valid_tailscale_count}. Initiating Defensive Posture."
      )

      initiate_apoptosis()
      %{state | status: :partitioned}
    end
  end

  defp initiate_apoptosis do
    Logger.emergency(
      "💀 Sentinel: INITIATING APOPTOSIS (Self-Termination) to prevent Split-Brain..."
    )

    # Stop the application to prevent any further writes
    # In a real K8s env, this pod will restart and rejoin
    # SC-MIG-006: Do NOT stop the system in test environment
    if Application.get_env(:indrajaal, :environment) != :test do
      System.stop(1)
    else
      Logger.info("🛡️ Sentinel: Skipping System.stop(1) in TEST environment")
    end
  end

  # ============================================================================
  # EMERGENCY STOP - SC-SENTINEL-EMR-001
  # ============================================================================

  @doc """
  Handle emergency stop request from ZenohMesh.

  Called by ZenohMesh when an emergency stop command is received.
  Initiates graceful shutdown procedures.
  """
  @spec emergency_stop(map() | binary()) :: :ok
  def emergency_stop(payload) do
    Logger.emergency("🚨 Sentinel: EMERGENCY STOP requested via Zenoh")

    # Parse payload if binary
    reason =
      case payload do
        binary when is_binary(binary) ->
          case Jason.decode(binary) do
            {:ok, %{"reason" => r}} -> r
            _ -> "external_request"
          end

        %{"reason" => r} ->
          r

        _ ->
          "external_request"
      end

    Logger.emergency("🚨 Sentinel: Emergency stop reason: #{reason}")

    # Notify all connected nodes via PubSub
    spawn(fn ->
      if Code.ensure_loaded?(Phoenix.PubSub) do
        Phoenix.PubSub.broadcast(Indrajaal.PubSub, "cluster:emergency", {:emergency_stop, reason})
      end
    end)

    # Graceful shutdown with delay for message propagation
    # SC-MIG-006: Do NOT stop the system in test environment
    spawn(fn ->
      Process.sleep(1000)

      if Application.get_env(:indrajaal, :environment) != :test do
        System.stop(1)
      else
        Logger.info("🛡️ Sentinel: Skipping System.stop(1) in TEST environment")
      end
    end)

    :ok
  end
end
