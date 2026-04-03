defmodule Indrajaal.Distributed.Gravity.GravityRouter do
  @moduledoc """
  Affinity-based routing using data gravity.

  Makes routing decisions based on data locality to minimize data movement
  and network costs. High gravity data (large, frequently accessed) should
  attract compute rather than being moved.

  ## STAMP Constraints

  - SC-GRAV-003: Affinity calculation < 1ms
  - SC-GRAV-004: Route decision logged for audit

  ## Routing Strategy

  1. Calculate data gravity for the target key
  2. Compare network cost of moving compute vs data
  3. Choose the option with lower cost
  4. Log decision for audit trail

  ## Usage

      {:ok, router} = GravityRouter.start_link(registry: registry_pid)

      # Get routing decision
      decision = GravityRouter.route(router, "alarms/tenant-1", current_node)
      # => %{target_node: "node-data@host", decision: :route_to_data, gravity: 0.7}

      # Check if compute should move to data
      if GravityRouter.should_move_compute?(router, key, current_node) do
        execute_on_remote_node(data_node, operation)
      else
        fetch_data_locally()
      end

  """

  use GenServer
  require Logger

  alias Indrajaal.Distributed.Gravity.LocalityRegistry

  @type routing_decision :: %{
          target_node: String.t(),
          decision: :local | :route_to_data | :fetch_data,
          gravity: float(),
          affinity: float(),
          reason: String.t()
        }

  # Threshold for "high gravity" - above this, move compute to data
  @gravity_threshold 0.3
  # Max decision log entries per key
  @max_log_entries 100

  # ============================================================================
  # CLIENT API
  # ============================================================================

  @doc """
  Starts the gravity router.

  ## Options

  - `:name` - Process name (optional)
  - `:registry` - LocalityRegistry pid or name (required)

  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name)
    gen_opts = if name, do: [name: name], else: []
    GenServer.start_link(__MODULE__, opts, gen_opts)
  end

  @doc """
  Makes a routing decision for accessing data.

  Returns a decision struct indicating where to execute the operation.
  """
  @spec route(GenServer.server(), String.t(), String.t()) :: routing_decision()
  def route(server \\ __MODULE__, key, from_node) do
    GenServer.call(server, {:route, key, from_node})
  end

  @doc """
  Computes affinity between data location and a target node.

  Returns 1.0 if same node, lower values for more distant nodes.
  """
  @spec compute_affinity(GenServer.server(), String.t(), String.t(), String.t()) :: float()
  def compute_affinity(server \\ __MODULE__, key, data_node, compute_node) do
    GenServer.call(server, {:compute_affinity, key, data_node, compute_node})
  end

  @doc """
  Determines if compute should be moved to data (vs fetching data).
  """
  @spec should_move_compute?(GenServer.server(), String.t(), String.t()) :: boolean()
  def should_move_compute?(server \\ __MODULE__, key, from_node) do
    GenServer.call(server, {:should_move_compute?, key, from_node})
  end

  @doc """
  Gets the routing decision log for a key (for audit).
  """
  @spec get_routing_decision_log(GenServer.server(), String.t()) :: [map()]
  def get_routing_decision_log(server \\ __MODULE__, key) do
    GenServer.call(server, {:get_decision_log, key})
  end

  @doc """
  Returns routing metrics.
  """
  @spec metrics(GenServer.server()) :: map()
  def metrics(server \\ __MODULE__) do
    GenServer.call(server, :metrics)
  end

  @doc """
  Returns health status.
  """
  @spec health(GenServer.server()) :: map()
  def health(server \\ __MODULE__) do
    GenServer.call(server, :health)
  end

  # ============================================================================
  # GENSERVER CALLBACKS
  # ============================================================================

  @impl true
  def init(opts) do
    registry = Keyword.fetch!(opts, :registry)

    state = %{
      registry: registry,
      decision_log: %{},
      metrics: %{
        total_decisions: 0,
        local_decisions: 0,
        remote_decisions: 0
      },
      started_at: DateTime.utc_now()
    }

    Logger.info("[GravityRouter] Started with registry: #{inspect(registry)}")

    {:ok, state}
  end

  @impl true
  def handle_call({:route, key, from_node}, _from, state) do
    # Lookup data location
    locality_info = LocalityRegistry.lookup(state.registry, key)

    decision =
      if locality_info == nil do
        # Unknown data - default to local
        %{
          target_node: from_node,
          decision: :local,
          gravity: 0.0,
          affinity: 1.0,
          reason: "Data location unknown, defaulting to local"
        }
      else
        data_node = locality_info.primary_node
        gravity = LocalityRegistry.get_data_gravity(state.registry, key)

        if data_node == from_node do
          # Data is local
          %{
            target_node: from_node,
            decision: :local,
            gravity: gravity,
            affinity: 1.0,
            reason: "Data is local"
          }
        else
          # Data is remote - decide based on gravity
          affinity = calculate_node_affinity(data_node, from_node)

          if gravity >= @gravity_threshold do
            # High gravity - move compute to data
            %{
              target_node: data_node,
              decision: :route_to_data,
              gravity: gravity,
              affinity: affinity,
              reason: "High gravity (#{Float.round(gravity, 2)}) - routing compute to data"
            }
          else
            # Low gravity - fetch data to compute
            %{
              target_node: from_node,
              decision: :fetch_data,
              gravity: gravity,
              affinity: affinity,
              reason: "Low gravity (#{Float.round(gravity, 2)}) - fetching data"
            }
          end
        end
      end

    # Log decision for audit (SC-GRAV-004)
    log_entry = %{
      key: key,
      from_node: from_node,
      decision: decision,
      timestamp: DateTime.to_iso8601(DateTime.utc_now())
    }

    new_log = update_decision_log(state.decision_log, key, log_entry)

    # Update metrics
    new_metrics = update_metrics(state.metrics, decision.decision)

    new_state = %{state | decision_log: new_log, metrics: new_metrics}

    {:reply, decision, new_state}
  end

  @impl true
  def handle_call({:compute_affinity, _key, data_node, compute_node}, _from, state) do
    affinity = calculate_node_affinity(data_node, compute_node)
    {:reply, affinity, state}
  end

  @impl true
  def handle_call({:should_move_compute?, key, from_node}, _from, state) do
    locality_info = LocalityRegistry.lookup(state.registry, key)

    should_move =
      if locality_info == nil do
        false
      else
        data_node = locality_info.primary_node

        if data_node == from_node do
          false
        else
          gravity = LocalityRegistry.get_data_gravity(state.registry, key)
          gravity >= @gravity_threshold
        end
      end

    {:reply, should_move, state}
  end

  @impl true
  def handle_call({:get_decision_log, key}, _from, state) do
    log = Map.get(state.decision_log, key, [])
    {:reply, log, state}
  end

  @impl true
  def handle_call(:metrics, _from, state) do
    metrics = %{
      total_decisions: state.metrics.total_decisions,
      local_decisions: state.metrics.local_decisions,
      remote_decisions: state.metrics.remote_decisions,
      uptime_ms: DateTime.diff(DateTime.utc_now(), state.started_at, :millisecond)
    }

    {:reply, metrics, state}
  end

  @impl true
  def handle_call(:health, _from, state) do
    health = %{
      status: :healthy,
      registry_connected: Process.alive?(state.registry),
      decision_log_keys: map_size(state.decision_log)
    }

    {:reply, health, state}
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp calculate_node_affinity(node1, node2) do
    if node1 == node2 do
      1.0
    else
      # Compare datacenters
      dc1 = extract_datacenter(node1)
      dc2 = extract_datacenter(node2)

      if dc1 == dc2 do
        # Same datacenter
        0.8
      else
        # Different datacenter
        0.3
      end
    end
  end

  defp extract_datacenter(node_name) do
    case String.split(to_string(node_name), "@") do
      [_name, location] ->
        case String.split(location, "-") do
          [dc | _] -> dc
          _ -> location
        end

      _ ->
        node_name
    end
  end

  defp update_decision_log(log, key, entry) do
    existing = Map.get(log, key, [])
    # Keep only last N entries
    updated = [entry | Enum.take(existing, @max_log_entries - 1)]
    Map.put(log, key, updated)
  end

  defp update_metrics(metrics, decision) do
    case decision do
      :local ->
        %{
          metrics
          | total_decisions: metrics.total_decisions + 1,
            local_decisions: metrics.local_decisions + 1
        }

      _ ->
        %{
          metrics
          | total_decisions: metrics.total_decisions + 1,
            remote_decisions: metrics.remote_decisions + 1
        }
    end
  end
end
