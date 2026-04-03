defmodule Indrajaal.Telemetry.PeriodicCollector do
  @moduledoc """
  L4-Intelligence: Periodic telemetry collection and aggregation.

  WHAT: GenServer that runs periodic telemetry collection tasks including
        metric snapshots, Zenoh health heartbeats, and ETS counter flushes.
  WHY: Continuous observability requires time-driven collection in addition
       to event-driven telemetry (SC-ZENOH-007, AOR-ZENOH-007).
  CONSTRAINTS: SC-ZENOH-007, SC-MON-001, AOR-ZENOH-007, AOR-MON-004.

  ## Collection Tasks
  - System metrics snapshot every 30s (SC-MON-001)
  - Zenoh health heartbeat every 10s (AOR-ZENOH-007)
  - ETS counter aggregation every 60s

  ## Change History
  | Version | Date       | Author             | Change                       |
  |---------|------------|--------------------|------------------------------|
  | 21.3.1  | 2026-03-28 | Claude Sonnet 4.6  | Initial real implementation  |
  """

  use GenServer
  require Logger

  @metrics_interval_ms 30_000
  @heartbeat_interval_ms 10_000
  @aggregation_interval_ms 60_000

  defstruct [
    :last_metrics_at,
    :last_heartbeat_at,
    :last_aggregation_at,
    :collection_count
  ]

  # ---- Client API ----

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns collection statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # ---- GenServer Callbacks ----

  @impl true
  def init(_opts) do
    schedule_metrics()
    schedule_heartbeat()
    schedule_aggregation()

    state = %__MODULE__{
      last_metrics_at: nil,
      last_heartbeat_at: nil,
      last_aggregation_at: nil,
      collection_count: 0
    }

    Logger.info("[PeriodicCollector] Started — periodic telemetry collection active",
      stamp: "SC-MON-001"
    )

    {:ok, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    {:reply,
     %{
       collection_count: state.collection_count,
       last_metrics_at: state.last_metrics_at,
       last_heartbeat_at: state.last_heartbeat_at,
       last_aggregation_at: state.last_aggregation_at
     }, state}
  end

  @impl true
  def handle_info(:collect_metrics, state) do
    collect_system_metrics()
    schedule_metrics()

    {:noreply,
     %{state | last_metrics_at: DateTime.utc_now(), collection_count: state.collection_count + 1}}
  end

  @impl true
  def handle_info(:health_heartbeat, state) do
    emit_health_heartbeat()
    schedule_heartbeat()
    {:noreply, %{state | last_heartbeat_at: DateTime.utc_now()}}
  end

  @impl true
  def handle_info(:aggregate_counters, state) do
    aggregate_ets_counters()
    schedule_aggregation()
    {:noreply, %{state | last_aggregation_at: DateTime.utc_now()}}
  end

  # ---- Private Helpers ----

  defp collect_system_metrics do
    uptime_ms = :erlang.monotonic_time(:millisecond) - :erlang.system_time(:millisecond) + 1
    {total_reductions, _} = :erlang.statistics(:reductions)
    {gc_count, gc_words, _} = :erlang.statistics(:garbage_collection)

    :telemetry.execute(
      [:indrajaal, :periodic_collector, :metrics_snapshot],
      %{
        uptime_ms: abs(uptime_ms),
        reductions: total_reductions,
        gc_count: gc_count,
        gc_words_reclaimed: gc_words,
        process_count: :erlang.system_info(:process_count)
      },
      %{node: node()}
    )
  rescue
    e ->
      Logger.debug("[PeriodicCollector] metrics collection error: #{Exception.message(e)}")
  end

  defp emit_health_heartbeat do
    # Emit Zenoh heartbeat via telemetry pipeline (SC-ZENOH-007)
    :telemetry.execute(
      [:indrajaal, :periodic_collector, :heartbeat],
      %{timestamp: System.system_time(:second)},
      %{node: node(), status: :alive}
    )
  end

  defp aggregate_ets_counters do
    # Scan known telemetry ETS tables and emit aggregated counts
    tables = [:prajna_analytics_reports, :prajna_alarms, :indrajaal_external_connectors]

    Enum.each(tables, fn table ->
      case :ets.whereis(table) do
        :undefined ->
          :skip

        _ref ->
          size = :ets.info(table, :size)

          :telemetry.execute(
            [:indrajaal, :periodic_collector, :ets_aggregate],
            %{size: size},
            %{table: table}
          )
      end
    end)
  end

  defp schedule_metrics do
    Process.send_after(self(), :collect_metrics, @metrics_interval_ms)
  end

  defp schedule_heartbeat do
    Process.send_after(self(), :health_heartbeat, @heartbeat_interval_ms)
  end

  defp schedule_aggregation do
    Process.send_after(self(), :aggregate_counters, @aggregation_interval_ms)
  end
end
