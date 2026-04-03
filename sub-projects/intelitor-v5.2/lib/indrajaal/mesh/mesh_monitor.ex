defmodule Indrajaal.Mesh.MeshMonitor do
  @moduledoc """
  Mesh Monitor - Real-time node health monitoring with Phoenix.PubSub + ETS

  WHAT: Monitors all mesh nodes in real-time, maintains health state in ETS,
        and broadcasts node health events via Phoenix.PubSub.
  WHY: Provides L5-layer (Node) observability across the Indrajaal SIL-6 mesh
       per SC-MON-003 (domain metrics per domain) and SC-SIL6-001 (mesh health).

  ## Architecture
  - ETS table `:mesh_node_health` holds current health for all known nodes
  - Phoenix.PubSub broadcasts `mesh:node_health` events on changes
  - GenServer polls node health every `:poll_interval_ms` (default 5_000ms)
  - Zenoh subscription (via `indrajaal/health/*`) receives push updates

  ## STAMP Constraints
  - SC-MON-001: Metrics refresh every 30s (or finer via push)
  - SC-MON-003: Domain metrics per domain
  - SC-MON-004: Safety metrics MANDATORY
  - SC-SIL6-001: Mesh boot MUST complete 5 stages
  - SC-AGENT-002: Agents MUST publish heartbeat every 5s
  - SC-AGENT-003: Agents MUST respond to ping within 100ms
  """

  use GenServer
  require Logger

  @pubsub Indrajaal.PubSub
  @topic_prefix "mesh:node_health"
  @ets_table :mesh_node_health
  @default_poll_interval_ms 5_000
  @node_timeout_ms 30_000

  # ============================================================================
  # Types
  # ============================================================================

  @type node_status :: :healthy | :degraded | :unreachable | :unknown
  @type node_health :: %{
          node_id: String.t(),
          status: node_status(),
          last_seen: DateTime.t(),
          latency_ms: non_neg_integer() | nil,
          container: String.t() | nil,
          layer: atom() | nil,
          zenoh_connected: boolean(),
          metadata: map()
        }

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Starts the MeshMonitor GenServer.

  ## Options
  - `:poll_interval_ms` - Health poll interval (default: #{@default_poll_interval_ms})
  - `:name` - GenServer name (default: __MODULE__)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Returns current health of all known mesh nodes.
  """
  @spec all_node_health() :: [node_health()]
  def all_node_health do
    ensure_ets_table()

    :ets.tab2list(@ets_table)
    |> Enum.map(fn {_node_id, health} -> health end)
    |> Enum.sort_by(& &1.node_id)
  end

  @doc """
  Returns health of a specific node by ID.
  """
  @spec node_health(String.t()) :: {:ok, node_health()} | {:error, :not_found}
  def node_health(node_id) do
    ensure_ets_table()

    case :ets.lookup(@ets_table, node_id) do
      [{^node_id, health}] -> {:ok, health}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Reports health for a node — called by nodes pushing their own health.
  Stores in ETS and broadcasts via PubSub.
  """
  @spec report_health(String.t(), node_status(), map()) :: :ok
  def report_health(node_id, status, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:report_health, node_id, status, metadata})
  end

  @doc """
  Returns aggregated mesh health score (0.0–1.0).
  0.0 = all nodes unhealthy, 1.0 = all nodes healthy.
  """
  @spec mesh_health_score() :: float()
  def mesh_health_score do
    nodes = all_node_health()

    case nodes do
      [] ->
        0.0

      _ ->
        healthy = Enum.count(nodes, &(&1.status == :healthy))
        Float.round(healthy / length(nodes), 3)
    end
  end

  @doc """
  Returns nodes that have not been seen within the timeout window.
  """
  @spec stale_nodes() :: [node_health()]
  def stale_nodes do
    now = DateTime.utc_now()

    all_node_health()
    |> Enum.filter(fn health ->
      DateTime.diff(now, health.last_seen, :millisecond) > @node_timeout_ms
    end)
  end

  @doc """
  Triggers an immediate health poll for all nodes.
  """
  @spec poll_now() :: :ok
  def poll_now do
    GenServer.cast(__MODULE__, :poll_now)
  end

  @doc """
  Returns monitor status and statistics.
  """
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(opts) do
    poll_interval = Keyword.get(opts, :poll_interval_ms, @default_poll_interval_ms)

    # Initialize ETS table for node health state (SC-SIL6-001)
    ensure_ets_table()

    # Seed known nodes from digital twin (if available)
    seed_from_digital_twin()

    # Schedule first poll
    schedule_poll(poll_interval)

    state = %{
      poll_interval_ms: poll_interval,
      started_at: DateTime.utc_now(),
      poll_count: 0,
      last_poll_at: nil,
      broadcast_count: 0
    }

    Logger.info("[MeshMonitor] Started — polling every #{poll_interval}ms")

    {:ok, state}
  end

  @impl true
  def handle_cast({:report_health, node_id, status, metadata}, state) do
    health = build_health_entry(node_id, status, metadata)

    # Upsert into ETS
    :ets.insert(@ets_table, {node_id, health})

    # Broadcast via PubSub (SC-BRIDGE-001: FIFO ordering)
    broadcast_health_event(node_id, health)

    new_state = %{state | broadcast_count: state.broadcast_count + 1}
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:poll_now, state) do
    perform_health_poll()
    new_state = %{state | poll_count: state.poll_count + 1, last_poll_at: DateTime.utc_now()}
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    node_count = :ets.info(@ets_table, :size)

    healthy_count =
      :ets.tab2list(@ets_table)
      |> Enum.count(fn {_id, h} -> h.status == :healthy end)

    status = %{
      poll_interval_ms: state.poll_interval_ms,
      started_at: state.started_at,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at),
      poll_count: state.poll_count,
      last_poll_at: state.last_poll_at,
      broadcast_count: state.broadcast_count,
      node_count: node_count,
      healthy_count: healthy_count,
      mesh_health_score: mesh_health_score()
    }

    {:reply, status, state}
  end

  @impl true
  def handle_info(:poll, state) do
    perform_health_poll()

    new_state = %{
      state
      | poll_count: state.poll_count + 1,
        last_poll_at: DateTime.utc_now()
    }

    schedule_poll(state.poll_interval_ms)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:zenoh_health_update, node_id, payload}, state) do
    # Handle Zenoh push updates from nodes publishing to indrajaal/health/*
    status = parse_zenoh_status(payload)
    metadata = Map.get(payload, :metadata, %{})
    health = build_health_entry(node_id, status, metadata)

    :ets.insert(@ets_table, {node_id, health})
    broadcast_health_event(node_id, health)

    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ============================================================================
  # Private helpers
  # ============================================================================

  defp ensure_ets_table do
    case :ets.whereis(@ets_table) do
      :undefined ->
        :ets.new(@ets_table, [:named_table, :public, :set, read_concurrency: true])

      _ref ->
        @ets_table
    end
  end

  defp seed_from_digital_twin do
    # Seed with known container nodes from SIL-6 topology (SC-SIL6-001)
    known_nodes = [
      %{id: "indrajaal-db-prod", container: "indrajaal-db-prod", layer: :l3},
      %{id: "indrajaal-obs-prod", container: "indrajaal-obs-prod", layer: :l3},
      %{id: "indrajaal-ex-app-1", container: "indrajaal-ex-app-1", layer: :l3},
      %{id: "zenoh-router-1", container: "zenoh-router", layer: :l4},
      %{id: "indrajaal-cortex", container: "indrajaal-cortex", layer: :l3},
      %{id: "cepaf-bridge", container: "cepaf-bridge", layer: :l4}
    ]

    Enum.each(known_nodes, fn node ->
      health =
        build_health_entry(node.id, :unknown, %{container: node.container, layer: node.layer})

      :ets.insert_new(@ets_table, {node.id, health})
    end)
  end

  defp perform_health_poll do
    # Check stale nodes and mark them as degraded/unreachable
    now = DateTime.utc_now()

    :ets.tab2list(@ets_table)
    |> Enum.each(fn {node_id, health} ->
      age_ms = DateTime.diff(now, health.last_seen, :millisecond)

      new_status =
        cond do
          age_ms <= @node_timeout_ms -> health.status
          age_ms <= @node_timeout_ms * 2 -> :degraded
          true -> :unreachable
        end

      if new_status != health.status do
        updated = %{health | status: new_status}
        :ets.insert(@ets_table, {node_id, updated})
        broadcast_health_event(node_id, updated)

        Logger.warning("[MeshMonitor] Node #{node_id} status: #{health.status} -> #{new_status}")
      end
    end)

    # Publish aggregate mesh health score
    score = mesh_health_score()

    :telemetry.execute(
      [:mesh, :monitor, :poll],
      %{health_score: score, node_count: :ets.info(@ets_table, :size)},
      %{}
    )
  end

  defp build_health_entry(node_id, status, metadata) do
    %{
      node_id: node_id,
      status: status,
      last_seen: DateTime.utc_now(),
      latency_ms: Map.get(metadata, :latency_ms),
      container: Map.get(metadata, :container),
      layer: Map.get(metadata, :layer),
      zenoh_connected: Map.get(metadata, :zenoh_connected, false),
      metadata: metadata
    }
  end

  defp broadcast_health_event(node_id, health) do
    topic = "#{@topic_prefix}:#{node_id}"
    message = {:mesh_node_health, node_id, health}

    Phoenix.PubSub.broadcast(@pubsub, topic, message)
    Phoenix.PubSub.broadcast(@pubsub, @topic_prefix, message)
  end

  defp parse_zenoh_status(%{status: status}) when is_atom(status), do: status
  defp parse_zenoh_status(%{"status" => "healthy"}), do: :healthy
  defp parse_zenoh_status(%{"status" => "degraded"}), do: :degraded
  defp parse_zenoh_status(%{"status" => "unreachable"}), do: :unreachable
  defp parse_zenoh_status(_), do: :unknown

  defp schedule_poll(interval_ms) do
    Process.send_after(self(), :poll, interval_ms)
  end
end
