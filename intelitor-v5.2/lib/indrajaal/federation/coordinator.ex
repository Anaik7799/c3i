defmodule Indrajaal.Federation.Coordinator do
  @moduledoc """
  Federation Coordinator - Distributed Jain Network Management for v20.0.0

  Coordinates the Jain node federation:
  - Node registration and discovery
  - Health monitoring
  - Resource sharing coordination
  - Constitutional synchronization
  - Emergency response coordination

  ## Federation Model

  The federation is a loose coupling of Jain nodes that:
  1. Share a common constitution
  2. Cooperate on resource sharing
  3. Maintain mutual awareness
  4. Coordinate emergency responses

  ## Coordination Modes
  - **Passive**: Just observe and report
  - **Active**: Coordinate activities
  - **Emergency**: Take control for safety

  ## STAMP Constraints
  - SC-FED-001: Coordinator MUST NOT modify node constitutions
  - SC-FED-002: Coordinator MUST maintain node autonomy
  - SC-FED-003: Coordinator MUST detect constitution divergence
  - SC-FED-004: Emergency coordination MUST be time-bounded
  """

  use GenServer
  require Logger

  alias Indrajaal.Federation.Protocol

  @type coordinator_state :: %{
          mode: :passive | :active | :emergency,
          nodes: map(),
          health_status: map(),
          last_sync: DateTime.t() | nil,
          stats: map()
        }

  @type coordination_event :: %{
          type: atom(),
          source: String.t(),
          timestamp: DateTime.t(),
          payload: term()
        }

  # Health check interval (ms)
  @health_check_interval 30_000

  # Emergency timeout (ms) - SC-FED-004
  @emergency_timeout 300_000

  # --- Client API ---

  @doc """
  Starts the federation coordinator.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Registers a node with the federation.
  """
  @spec register_node(String.t(), map()) :: :ok | {:error, term()}
  def register_node(node_id, metadata) do
    GenServer.call(__MODULE__, {:register_node, node_id, metadata})
  end

  @doc """
  Unregisters a node from the federation.
  """
  @spec unregister_node(String.t()) :: :ok
  def unregister_node(node_id) do
    GenServer.call(__MODULE__, {:unregister_node, node_id})
  end

  @doc """
  Gets the current federation status.
  """
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc """
  Broadcasts a message to all federation nodes.
  """
  @spec broadcast(term()) :: :ok
  def broadcast(message) do
    GenServer.cast(__MODULE__, {:broadcast, message})
  end

  @doc """
  Initiates emergency coordination mode.
  """
  @spec enter_emergency(atom()) :: :ok | {:error, term()}
  def enter_emergency(reason) do
    GenServer.call(__MODULE__, {:enter_emergency, reason})
  end

  @doc """
  Exits emergency coordination mode.
  """
  @spec exit_emergency() :: :ok | {:error, term()}
  def exit_emergency do
    GenServer.call(__MODULE__, :exit_emergency)
  end

  @doc """
  Gets health status for all nodes.
  """
  @spec health_report() :: map()
  def health_report do
    GenServer.call(__MODULE__, :health_report)
  end

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    state = %{
      mode: Keyword.get(opts, :mode, :passive),
      nodes: %{},
      health_status: %{},
      last_sync: nil,
      stats: %{
        registrations: 0,
        broadcasts: 0,
        health_checks: 0,
        emergencies: 0
      }
    }

    Logger.info("🌐 Federation Coordinator starting in #{state.mode} mode")

    # Schedule health checks
    schedule_health_check()

    {:ok, state}
  end

  @impl true
  def handle_call({:register_node, node_id, metadata}, _from, state) do
    Logger.info("Registering node #{node_id} with federation")

    # Verify constitution hash matches federation
    case verify_constitution_hash(metadata) do
      :ok ->
        node_info = %{
          id: node_id,
          metadata: metadata,
          registered_at: DateTime.utc_now(),
          last_seen: DateTime.utc_now(),
          status: :healthy
        }

        new_nodes = Map.put(state.nodes, node_id, node_info)
        new_stats = Map.update!(state.stats, :registrations, &(&1 + 1))

        Logger.info("Node #{node_id} registered successfully")

        {:reply, :ok, %{state | nodes: new_nodes, stats: new_stats}}

      {:error, reason} = error ->
        Logger.warning("Node #{node_id} registration rejected: #{reason}")
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:unregister_node, node_id}, _from, state) do
    Logger.info("Unregistering node #{node_id} from federation")

    new_nodes = Map.delete(state.nodes, node_id)
    new_health = Map.delete(state.health_status, node_id)

    {:reply, :ok, %{state | nodes: new_nodes, health_status: new_health}}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      mode: state.mode,
      node_count: map_size(state.nodes),
      healthy_nodes: count_healthy_nodes(state),
      last_sync: state.last_sync,
      stats: state.stats
    }

    {:reply, status, state}
  end

  @impl true
  def handle_call({:enter_emergency, reason}, _from, state) do
    if state.mode == :emergency do
      {:reply, {:error, :already_in_emergency}, state}
    else
      Logger.warning("🚨 Entering EMERGENCY mode: #{reason}")

      new_state = %{
        state
        | mode: :emergency,
          stats: Map.update!(state.stats, :emergencies, &(&1 + 1))
      }

      # Broadcast emergency to all nodes
      broadcast_emergency(reason, new_state)

      # Schedule emergency timeout
      Process.send_after(self(), :emergency_timeout, @emergency_timeout)

      {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call(:exit_emergency, _from, state) do
    if state.mode != :emergency do
      {:reply, {:error, :not_in_emergency}, state}
    else
      Logger.info("✅ Exiting EMERGENCY mode")
      {:reply, :ok, %{state | mode: :active}}
    end
  end

  @impl true
  def handle_call(:health_report, _from, state) do
    report = %{
      timestamp: DateTime.utc_now(),
      nodes: state.health_status,
      summary: %{
        total: map_size(state.nodes),
        healthy: count_healthy_nodes(state),
        unhealthy: count_unhealthy_nodes(state)
      }
    }

    {:reply, report, state}
  end

  @impl true
  def handle_cast({:broadcast, message}, state) do
    Logger.debug("Broadcasting to #{map_size(state.nodes)} nodes")

    # Send to all registered nodes
    Enum.each(state.nodes, fn {node_id, _info} ->
      Protocol.send_message(node_id, message)
    end)

    new_stats = Map.update!(state.stats, :broadcasts, &(&1 + 1))

    {:noreply, %{state | stats: new_stats}}
  end

  @impl true
  def handle_info(:health_check, state) do
    Logger.debug("Running federation health check")

    new_health_status =
      Enum.reduce(state.nodes, %{}, fn {node_id, info}, acc ->
        health = check_node_health(node_id, info)
        Map.put(acc, node_id, health)
      end)

    # Update node statuses based on health
    new_nodes = update_node_statuses(state.nodes, new_health_status)
    new_stats = Map.update!(state.stats, :health_checks, &(&1 + 1))

    # Schedule next check
    schedule_health_check()

    {:noreply, %{state | health_status: new_health_status, nodes: new_nodes, stats: new_stats}}
  end

  @impl true
  def handle_info(:emergency_timeout, state) do
    if state.mode == :emergency do
      Logger.warning("⏰ Emergency timeout reached - auto-exiting emergency mode")
      {:noreply, %{state | mode: :active}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:node_event, event}, state) do
    Logger.debug("Received node event: #{event.type} from #{event.source}")

    case event.type do
      :heartbeat ->
        handle_heartbeat(event, state)

      :status_change ->
        handle_status_change(event, state)

      :constitution_alert ->
        handle_constitution_alert(event, state)

      _ ->
        {:noreply, state}
    end
  end

  # Private helpers

  defp schedule_health_check do
    Process.send_after(self(), :health_check, @health_check_interval)
  end

  defp verify_constitution_hash(metadata) do
    expected_hash = get_federation_constitution_hash()
    node_hash = Map.get(metadata, :constitution_hash)

    cond do
      is_nil(node_hash) ->
        {:error, :no_constitution_hash}

      node_hash != expected_hash ->
        {:error, :constitution_mismatch}

      true ->
        :ok
    end
  end

  defp get_federation_constitution_hash do
    # In production, would load from federation configuration
    "federation_constitution_hash"
  end

  defp count_healthy_nodes(state) do
    Enum.count(state.nodes, fn {_id, info} -> info.status == :healthy end)
  end

  defp count_unhealthy_nodes(state) do
    Enum.count(state.nodes, fn {_id, info} -> info.status != :healthy end)
  end

  defp check_node_health(node_id, info) do
    # Check if node has been seen recently
    time_since_seen = DateTime.diff(DateTime.utc_now(), info.last_seen, :second)

    %{
      node_id: node_id,
      healthy: time_since_seen < 60,
      last_seen: info.last_seen,
      time_since_seen: time_since_seen,
      checked_at: DateTime.utc_now()
    }
  end

  defp update_node_statuses(nodes, health_status) do
    Enum.reduce(health_status, nodes, fn {node_id, health}, acc ->
      if Map.has_key?(acc, node_id) do
        status = if health.healthy, do: :healthy, else: :unhealthy
        update_in(acc, [node_id, :status], fn _ -> status end)
      else
        acc
      end
    end)
  end

  defp broadcast_emergency(reason, state) do
    message = %{
      type: :emergency,
      reason: reason,
      timestamp: DateTime.utc_now(),
      coordinator: node()
    }

    Enum.each(state.nodes, fn {node_id, _info} ->
      Protocol.send_message(node_id, message)
    end)
  end

  defp handle_heartbeat(event, state) do
    node_id = event.source

    new_nodes =
      if Map.has_key?(state.nodes, node_id) do
        update_in(state.nodes, [node_id, :last_seen], fn _ -> DateTime.utc_now() end)
      else
        state.nodes
      end

    {:noreply, %{state | nodes: new_nodes}}
  end

  defp handle_status_change(event, state) do
    node_id = event.source
    new_status = event.payload[:status]

    new_nodes =
      if Map.has_key?(state.nodes, node_id) do
        update_in(state.nodes, [node_id, :status], fn _ -> new_status end)
      else
        state.nodes
      end

    {:noreply, %{state | nodes: new_nodes}}
  end

  defp handle_constitution_alert(event, state) do
    node_id = event.source

    Logger.warning("Constitution alert from #{node_id}: #{inspect(event.payload)}")

    # In emergency, might need to isolate the node
    if state.mode == :emergency do
      # Mark node as potentially corrupted
      new_nodes =
        if Map.has_key?(state.nodes, node_id) do
          update_in(state.nodes, [node_id, :status], fn _ -> :quarantined end)
        else
          state.nodes
        end

      {:noreply, %{state | nodes: new_nodes}}
    else
      {:noreply, state}
    end
  end
end
