defmodule Indrajaal.Cockpit.Prajna.SmartMetrics do
  @moduledoc """
  PRAJNA C3I Mesh Cockpit - Smart Metrics Engine

  WHAT: Real-time metric collection, trend analysis, and anomaly detection
        implementing NUREG-0700 analog-over-digital principles.

  WHY: Smart Metrics provide situational awareness through:
       - Trend vectors (direction, not just value)
       - Staleness detection (frozen numbers decay)
       - Sparkline history (visual pattern recognition)
       - Alarm level computation (threshold-based)

  CONSTRAINTS:
    - SC-HMI-002: Trend vectors MUST be displayed
    - SC-HMI-003: Staleness detection (5-second watchdog)
    - SC-PRF-050: Metric updates < 50ms latency

  ## Architecture

  ```
  ┌─────────────────────────────────────────────────────────────┐
  │                  SMART METRICS ENGINE                        │
  ├─────────────────────────────────────────────────────────────┤
  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
  │  │  Collector  │→ │  Analyzer   │→ │  Publisher  │          │
  │  │  (Telemetry)│  │  (Trends)   │  │  (PubSub)   │          │
  │  └─────────────┘  └─────────────┘  └─────────────┘          │
  │         ↓                ↓                ↓                  │
  │  ┌─────────────────────────────────────────────────────┐    │
  │  │           METRIC STORE (ETS + History)               │    │
  │  │  - Current values with trends                        │    │
  │  │  - Sparkline buffers (last 20 samples)              │    │
  │  │  - Threshold configurations                          │    │
  │  └─────────────────────────────────────────────────────┘    │
  └─────────────────────────────────────────────────────────────┘
  ```

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-27 |
  | Author | Cybernetic Architect |
  | STAMP | SC-HMI-002, SC-HMI-003, SC-PRF-050 |
  """

  use GenServer
  require Logger

  alias Indrajaal.Cockpit.Prajna.Domain

  @table :prajna_metrics
  @history_table :prajna_metrics_history
  @staleness_threshold_ms 5_000
  @sparkline_length 20

  # ═══════════════════════════════════════════════════════════════════════════
  # CLIENT API
  # ═══════════════════════════════════════════════════════════════════════════

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Record a new metric value"
  @spec record(String.t(), String.t(), number(), keyword()) :: :ok
  def record(metric_id, label, value, opts \\ []) do
    GenServer.cast(__MODULE__, {:record, metric_id, label, value, opts})
  end

  @doc "Get current metric with trend and staleness info"
  @spec get(String.t()) :: Domain.smart_metric() | nil
  def get(metric_id) do
    case :ets.lookup(@table, metric_id) do
      [{^metric_id, metric}] -> metric
      [] -> nil
    end
  end

  @doc "Get all metrics"
  @spec all() :: list({String.t(), Domain.smart_metric()})
  def all do
    :ets.tab2list(@table)
  end

  @doc "Get metrics by pattern (e.g., 'cpu.*' or 'node.app-01.*')"
  @spec get_by_pattern(String.t()) :: list({String.t(), Domain.smart_metric()})
  def get_by_pattern(pattern) do
    regex_pattern = String.replace(pattern, "*", ".*")
    regex = Regex.compile!(regex_pattern)
    all_metrics = :ets.tab2list(@table)

    all_metrics
    |> Enum.filter(fn {id, _} -> Regex.match?(regex, id) end)
  end

  @doc "Get stale metrics (> 5 seconds old)"
  @spec stale_metrics() :: list({String.t(), Domain.smart_metric()})
  def stale_metrics do
    now = System.monotonic_time(:millisecond)
    all_metrics = :ets.tab2list(@table)

    all_metrics
    |> Enum.filter(fn {_, metric} ->
      staleness = now - metric_to_mono_time(metric)
      staleness > @staleness_threshold_ms
    end)
  end

  @doc "Get metrics in alarm state (above normal)"
  @spec alarmed_metrics() :: list({String.t(), Domain.smart_metric()})
  def alarmed_metrics do
    all_metrics = :ets.tab2list(@table)

    all_metrics
    |> Enum.filter(fn {_, metric} -> metric.level != :normal end)
    |> Enum.sort_by(fn {_, metric} -> alarm_priority(metric.level) end)
  end

  @doc "Get sparkline data for a metric"
  @spec sparkline(String.t()) :: list(float())
  def sparkline(metric_id) do
    case get(metric_id) do
      nil -> []
      metric -> metric.sparkline
    end
  end

  @doc "Configure thresholds for a metric"
  @spec configure_thresholds(String.t(), map()) :: :ok
  def configure_thresholds(metric_id, thresholds) do
    GenServer.cast(__MODULE__, {:configure_thresholds, metric_id, thresholds})
  end

  @doc "Delete a specific metric"
  @spec delete(String.t()) :: :ok
  def delete(metric_id) do
    :ets.delete(@table, metric_id)
    :ok
  end

  @doc "Clear all metrics"
  @spec clear() :: :ok
  def clear do
    :ets.delete_all_objects(@table)
    :ok
  end

  @doc "Get system-wide health summary"
  @spec health_summary() :: map()
  def health_summary do
    metrics = all()
    total = length(metrics)
    stale = length(stale_metrics())
    alarmed = length(alarmed_metrics())

    {normal, advisory, caution, warning, critical} =
      Enum.reduce(metrics, {0, 0, 0, 0, 0}, fn {_, m}, {n, a, c, w, cr} ->
        case m.level do
          :normal -> {n + 1, a, c, w, cr}
          :advisory -> {n, a + 1, c, w, cr}
          :caution -> {n, a, c + 1, w, cr}
          :warning -> {n, a, c, w + 1, cr}
          :critical -> {n, a, c, w, cr + 1}
        end
      end)

    health_score =
      if total > 0 do
        # Weight: normal=100, advisory=80, caution=50, warning=20, critical=0
        ((normal * 100 + advisory * 80 + caution * 50 + warning * 20) / total)
        |> round()
      else
        100
      end

    %{
      total_metrics: total,
      stale_count: stale,
      alarmed_count: alarmed,
      by_level: %{
        normal: normal,
        advisory: advisory,
        caution: caution,
        warning: warning,
        critical: critical
      },
      health_score: health_score,
      status: health_status(health_score, stale, critical)
    }
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # GENSERVER CALLBACKS
  # ═══════════════════════════════════════════════════════════════════════════

  @impl GenServer
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    :ets.new(@history_table, [:named_table, :public, :set])

    # Start staleness checker
    schedule_staleness_check()

    Logger.info(
      "[Prajna.SmartMetrics] Initialized with staleness threshold: #{@staleness_threshold_ms}ms"
    )

    {:ok,
     %{
       started_at: DateTime.utc_now(),
       metrics_recorded: 0,
       last_staleness_check: nil
     }}
  end

  @impl GenServer
  def handle_cast({:record, metric_id, label, value, opts}, state) do
    unit = Keyword.get(opts, :unit, "")
    thresholds = Keyword.get(opts, :thresholds)
    now = DateTime.utc_now()
    mono_now = System.monotonic_time(:millisecond)

    metric =
      case :ets.lookup(@table, metric_id) do
        [{^metric_id, existing}] ->
          update_metric(existing, value, now, mono_now)

        [] ->
          create_metric(label, unit, value, now, mono_now, thresholds)
      end

    # Apply thresholds if configured
    metric = apply_thresholds(metric)

    :ets.insert(@table, {metric_id, metric})

    # ZUIP: Publish alarmed metrics to Zenoh mesh (warning/critical only)
    if metric.level in [:warning, :critical] do
      safe_zenoh_publish(:publish_sentinel_threat, [
        :metric_alarm,
        metric_id,
        metric.level,
        %{value: metric.value, label: metric.label}
      ])
    end

    # Publish update via PubSub (if available)
    safe_broadcast("prajna:metrics", {:metric_updated, metric_id, metric})

    {:noreply, %{state | metrics_recorded: state.metrics_recorded + 1}}
  end

  @impl GenServer
  def handle_cast({:configure_thresholds, metric_id, thresholds}, state) do
    case :ets.lookup(@table, metric_id) do
      [{^metric_id, metric}] ->
        updated = %{metric | thresholds: thresholds}
        :ets.insert(@table, {metric_id, apply_thresholds(updated)})

      [] ->
        :ok
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:check_staleness, state) do
    stale = stale_metrics()

    if length(stale) > 0 do
      Logger.debug("[Prajna.SmartMetrics] #{length(stale)} stale metrics detected")

      Enum.each(stale, fn {id, _metric} ->
        safe_broadcast("prajna:metrics", {:metric_stale, id})
      end)
    end

    schedule_staleness_check()
    {:noreply, %{state | last_staleness_check: DateTime.utc_now()}}
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PRIVATE HELPERS
  # ═══════════════════════════════════════════════════════════════════════════

  defp create_metric(label, unit, value, now, mono_now, thresholds) do
    %{
      value: value,
      previous_value: nil,
      last_updated: now,
      mono_time: mono_now,
      trend: :stable,
      level: :normal,
      thresholds: thresholds,
      unit: unit,
      label: label,
      sparkline: [value]
    }
  end

  defp update_metric(existing, new_value, now, mono_now) do
    trend = compute_trend(existing.value, new_value, existing.trend)
    sparkline = [new_value | existing.sparkline] |> Enum.take(@sparkline_length)

    %{
      existing
      | value: new_value,
        previous_value: existing.value,
        last_updated: now,
        mono_time: mono_now,
        trend: trend,
        sparkline: sparkline
    }
  end

  defp compute_trend(old_value, new_value, previous_trend)
       when is_number(old_value) and is_number(new_value) do
    diff = new_value - old_value
    percent_change = if old_value != 0, do: abs(diff / old_value) * 100, else: abs(diff)

    cond do
      # Rising fast: >10% increase or already rising and continued increase
      diff > 0 and (percent_change > 10 or previous_trend == :rising) ->
        if percent_change > 10, do: :rising_fast, else: :rising

      diff > 0 ->
        :rising

      # Falling fast: >10% decrease or already falling and continued decrease
      diff < 0 and (percent_change > 10 or previous_trend == :falling) ->
        if percent_change > 10, do: :falling_fast, else: :falling

      diff < 0 ->
        :falling

      true ->
        :stable
    end
  end

  defp compute_trend(_, _, _), do: :stable

  defp apply_thresholds(%{thresholds: nil} = metric), do: metric

  defp apply_thresholds(%{thresholds: t, value: v} = metric) when is_map(t) do
    level =
      cond do
        t[:warning_high] && v >= t.warning_high -> :warning
        t[:warning_low] && v <= t.warning_low -> :warning
        t[:caution_high] && v >= t.caution_high -> :caution
        t[:caution_low] && v <= t.caution_low -> :caution
        t[:advisory_high] && v >= t.advisory_high -> :advisory
        t[:advisory_low] && v <= t.advisory_low -> :advisory
        true -> :normal
      end

    %{metric | level: level}
  end

  defp apply_thresholds(metric), do: metric

  defp metric_to_mono_time(%{mono_time: mono_time}), do: mono_time
  defp metric_to_mono_time(_), do: 0

  defp alarm_priority(:critical), do: 0
  defp alarm_priority(:warning), do: 1
  defp alarm_priority(:caution), do: 2
  defp alarm_priority(:advisory), do: 3
  defp alarm_priority(:normal), do: 4

  defp health_status(score, stale_count, critical_count) do
    cond do
      critical_count > 0 -> :critical
      score < 50 -> :warning
      stale_count > 5 or score < 70 -> :caution
      stale_count > 0 or score < 90 -> :advisory
      true -> :healthy
    end
  end

  defp schedule_staleness_check do
    Process.send_after(self(), :check_staleness, 1_000)
  end

  defp safe_broadcast(topic, message) do
    try do
      Phoenix.PubSub.broadcast(Indrajaal.PubSub, topic, message)
    rescue
      ArgumentError -> :ok
    catch
      _, _ -> :ok
    end
  end

  defp safe_zenoh_publish(function, args) do
    try do
      case Code.ensure_loaded(Indrajaal.Observability.ZenohSafetyPublisher) do
        {:module, mod} -> apply(mod, function, args)
        _ -> :ok
      end
    rescue
      _ -> :ok
    end
  end
end
