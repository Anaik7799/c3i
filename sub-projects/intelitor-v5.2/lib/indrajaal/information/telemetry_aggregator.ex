defmodule Indrajaal.Information.TelemetryAggregator do
  @moduledoc """
  Telemetry Aggregator — L2 Information Layer

  ## Design Intent
  GenServer that aggregates telemetry from multiple sources into a unified
  metric stream. Buffers raw metrics in ETS for sub-millisecond reads,
  then flushes aggregated snapshots at a configurable interval to PubSub
  and the :telemetry pipeline.

  Supports three metric types:
  - **Counter**: monotonically increasing integer (e.g. request count)
  - **Gauge**: current float reading (e.g. CPU percent)
  - **Histogram**: list of float samples (e.g. latency observations)

  On each flush cycle, counters produce a delta, gauges a last-value, and
  histograms produce {count, min, max, mean, p95, p99}.

  ## STAMP Constraints
  - SC-DEBUG-001: Telemetry bus must buffer and flush metrics reliably
  - SC-OBS-069: Dual log — Term logger + Zenoh telemetry pathway

  ## Change History
  | Version | Date       | Author            | Change                    |
  |---------|------------|-------------------|---------------------------|
  | 21.3.1  | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation    |
  """

  use GenServer

  require Logger

  @name __MODULE__
  @ets_table :telemetry_aggregator_metrics
  @pubsub_topic "telemetry:aggregated"
  @default_flush_interval_ms 5_000
  @telemetry_event [:indrajaal, :information, :telemetry_aggregated]

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type metric_type :: :counter | :gauge | :histogram
  @type metric_name :: String.t()

  @type counter_entry :: %{type: :counter, value: non_neg_integer()}
  @type gauge_entry :: %{type: :gauge, value: float()}
  @type histogram_entry :: %{type: :histogram, samples: [float()]}

  @type metric_entry :: counter_entry() | gauge_entry() | histogram_entry()

  @type aggregated_metric :: %{
          name: metric_name(),
          type: metric_type(),
          value: term(),
          timestamp: non_neg_integer()
        }

  @type state :: %{
          flush_interval_ms: pos_integer(),
          last_counters: %{metric_name() => non_neg_integer()}
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Starts the TelemetryAggregator GenServer.

  Options:
  - `:flush_interval_ms` — how often to flush aggregated metrics (default: 5000ms)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc "Increments a counter metric by `amount` (default: 1)."
  @spec increment(metric_name(), pos_integer()) :: :ok
  def increment(name, amount \\ 1) when is_binary(name) and is_integer(amount) and amount > 0 do
    GenServer.cast(@name, {:increment, name, amount})
  end

  @doc "Sets a gauge metric to `value`."
  @spec set_gauge(metric_name(), float()) :: :ok
  def set_gauge(name, value) when is_binary(name) and is_number(value) do
    GenServer.cast(@name, {:set_gauge, name, value / 1})
  end

  @doc "Records a histogram observation."
  @spec observe(metric_name(), float()) :: :ok
  def observe(name, value) when is_binary(name) and is_number(value) do
    GenServer.cast(@name, {:observe, name, value / 1})
  end

  @doc "Returns the current raw metric map from ETS (fast read, no GenServer call)."
  @spec get_metrics() :: %{metric_name() => metric_entry()}
  def get_metrics do
    case :ets.whereis(@ets_table) do
      :undefined ->
        %{}

      _ ->
        :ets.tab2list(@ets_table)
        |> Enum.into(%{}, fn {k, v} -> {k, v} end)
    end
  end

  @doc "Forces an immediate flush (useful for testing)."
  @spec flush() :: [aggregated_metric()]
  def flush do
    GenServer.call(@name, :flush)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    :ets.new(@ets_table, [:named_table, :public, read_concurrency: true])

    flush_interval_ms = Keyword.get(opts, :flush_interval_ms, @default_flush_interval_ms)
    schedule_flush(flush_interval_ms)

    Logger.info("[TelemetryAggregator] L2 started — flush_interval=#{flush_interval_ms}ms")

    state = %{
      flush_interval_ms: flush_interval_ms,
      last_counters: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:increment, name, amount}, state) do
    current =
      case :ets.lookup(@ets_table, name) do
        [{^name, %{type: :counter, value: v}}] -> v
        _ -> 0
      end

    :ets.insert(@ets_table, {name, %{type: :counter, value: current + amount}})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:set_gauge, name, value}, state) do
    :ets.insert(@ets_table, {name, %{type: :gauge, value: value}})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:observe, name, value}, state) do
    existing_samples =
      case :ets.lookup(@ets_table, name) do
        [{^name, %{type: :histogram, samples: s}}] -> s
        _ -> []
      end

    :ets.insert(@ets_table, {name, %{type: :histogram, samples: [value | existing_samples]}})
    {:noreply, state}
  end

  @impl true
  def handle_call(:flush, _from, state) do
    {aggregated, new_last_counters} = do_flush(state.last_counters)
    {:reply, aggregated, %{state | last_counters: new_last_counters}}
  end

  @impl true
  def handle_info(:flush, state) do
    {aggregated, new_last_counters} = do_flush(state.last_counters)

    if aggregated != [] do
      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        @pubsub_topic,
        {:telemetry_aggregated, aggregated}
      )

      :telemetry.execute(@telemetry_event, %{metric_count: length(aggregated)}, %{
        topic: @pubsub_topic
      })
    end

    schedule_flush(state.flush_interval_ms)
    {:noreply, %{state | last_counters: new_last_counters}}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec do_flush(%{metric_name() => non_neg_integer()}) ::
          {[aggregated_metric()], %{metric_name() => non_neg_integer()}}
  defp do_flush(last_counters) do
    now = System.monotonic_time(:millisecond)

    all_entries = :ets.tab2list(@ets_table)

    {aggregated, new_last_counters} =
      Enum.reduce(all_entries, {[], last_counters}, fn {name, entry}, {acc, lc} ->
        {agg, updated_lc} = aggregate_entry(name, entry, lc, now)
        {[agg | acc], updated_lc}
      end)

    # Reset histograms after flush (samples consumed)
    Enum.each(all_entries, fn
      {name, %{type: :histogram}} ->
        :ets.insert(@ets_table, {name, %{type: :histogram, samples: []}})

      _ ->
        :ok
    end)

    {Enum.reverse(aggregated), new_last_counters}
  end

  @spec aggregate_entry(metric_name(), metric_entry(), map(), non_neg_integer()) ::
          {aggregated_metric(), map()}
  defp aggregate_entry(name, %{type: :counter, value: v}, last_counters, now) do
    prev = Map.get(last_counters, name, 0)
    delta = v - prev

    agg = %{
      name: name,
      type: :counter,
      value: %{total: v, delta: delta},
      timestamp: now
    }

    {agg, Map.put(last_counters, name, v)}
  end

  defp aggregate_entry(name, %{type: :gauge, value: v}, last_counters, now) do
    agg = %{name: name, type: :gauge, value: v, timestamp: now}
    {agg, last_counters}
  end

  defp aggregate_entry(name, %{type: :histogram, samples: []}, last_counters, now) do
    agg = %{name: name, type: :histogram, value: %{count: 0}, timestamp: now}
    {agg, last_counters}
  end

  defp aggregate_entry(name, %{type: :histogram, samples: samples}, last_counters, now) do
    sorted = Enum.sort(samples)
    count = length(sorted)
    total = Enum.sum(sorted)
    mean = total / count
    min_val = List.first(sorted)
    max_val = List.last(sorted)
    p95 = percentile(sorted, count, 0.95)
    p99 = percentile(sorted, count, 0.99)

    agg = %{
      name: name,
      type: :histogram,
      value: %{
        count: count,
        min: min_val,
        max: max_val,
        mean: mean,
        p95: p95,
        p99: p99
      },
      timestamp: now
    }

    {agg, last_counters}
  end

  @spec percentile([float()], pos_integer(), float()) :: float()
  defp percentile(sorted, count, pct) do
    idx = round(pct * count) - 1
    clamped = max(0, min(idx, count - 1))
    Enum.at(sorted, clamped)
  end

  defp schedule_flush(interval_ms) do
    Process.send_after(self(), :flush, interval_ms)
  end
end
