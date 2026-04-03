defmodule Indrajaal.Semantic.Telemetry do
  @moduledoc """
  Prajna Integration for Semantic Layer Telemetry

  WHAT: Publishes semantic layer metrics to Zenoh for Prajna Cockpit dashboard
        and triggers alerts on bridge failures.

  WHY: Provides real-time visibility into semantic operations and enables
       proactive monitoring of F# bridge health.

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.2.1 | 2026-01-11 | Claude | Initial implementation |

  ## STAMP Compliance
  - SC-BRIDGE-005: PubSub topics for semantic metrics
  - SC-PRAJNA-004: SmartMetrics sync every 30s
  - SC-PRF-050: Response latency < 50ms

  ## Telemetry Events

  This module attaches to the following telemetry events:

  - `[:semantic, :bridge, :start]` - Bridge startup
  - `[:semantic, :bridge, :call]` - RPC call with duration
  - `[:semantic, :bridge, :failure]` - Bridge failure
  - `[:semantic, :triple, :add]` - Triple addition
  - `[:semantic, :query, :sparql]` - SPARQL query
  - `[:semantic, :vector, :similar]` - Vector search
  - `[:semantic, :zettel, :process]` - Zettel processing

  ## Zenoh Topics

  - `indrajaal/semantic/kpi` - KPI metrics
  - `indrajaal/semantic/health` - Health status
  - `indrajaal/semantic/alerts` - Alert notifications
  """

  require Logger

  # Metric update interval (30s per SC-PRAJNA-004)
  @metric_interval 30_000

  # Alert thresholds
  @latency_warning_ms 100
  @latency_critical_ms 500
  @failure_rate_warning 0.1
  @failure_rate_critical 0.25

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Attach telemetry handlers for semantic layer monitoring.

  Should be called during application startup in init/1.
  """
  @spec attach_handlers() :: :ok
  def attach_handlers do
    events = [
      [:semantic, :bridge, :start],
      [:semantic, :bridge, :call],
      [:semantic, :bridge, :failure],
      [:semantic, :triple, :add],
      [:semantic, :triple, :add_batch],
      [:semantic, :triple, :remove],
      [:semantic, :query, :sparql],
      [:semantic, :vector, :similar],
      [:semantic, :zettel, :process]
    ]

    :telemetry.attach_many(
      "semantic-telemetry-handler",
      events,
      &handle_event/4,
      nil
    )

    Logger.info("Semantic telemetry handlers attached",
      events: length(events),
      interval_ms: @metric_interval
    )

    # Start periodic metric publisher
    start_metric_publisher()

    :ok
  end

  @doc """
  Detach telemetry handlers (for testing).
  """
  @spec detach_handlers() :: :ok | {:error, :not_found}
  def detach_handlers do
    :telemetry.detach("semantic-telemetry-handler")
  end

  @doc """
  Get current semantic layer metrics.
  """
  @spec get_metrics() :: map()
  def get_metrics do
    state = get_state()

    %{
      bridge: %{
        uptime_seconds: uptime_seconds(state.bridge_start_time),
        total_calls: state.total_calls,
        total_failures: state.total_failures,
        failure_rate: calculate_failure_rate(state),
        circuit_breaker_state: state.circuit_breaker_state
      },
      operations: %{
        triple_adds: state.triple_adds,
        triple_removes: state.triple_removes,
        queries: state.queries,
        vector_searches: state.vector_searches,
        zettel_processes: state.zettel_processes
      },
      performance: %{
        avg_latency_ms: calculate_avg_latency(state),
        p50_latency_ms: calculate_percentile(state, 50),
        p95_latency_ms: calculate_percentile(state, 95),
        p99_latency_ms: calculate_percentile(state, 99)
      },
      health: %{
        status: determine_health_status(state),
        last_failure: state.last_failure,
        consecutive_failures: state.consecutive_failures
      }
    }
  end

  @doc """
  Publish metrics to Zenoh.
  """
  @spec publish_metrics() :: :ok
  def publish_metrics do
    metrics = get_metrics()

    # Publish to Zenoh KPI topic (SC-BRIDGE-005)
    publish_to_zenoh("indrajaal/semantic/kpi", metrics)

    :ok
  end

  @doc """
  Get dashboard data for Prajna Cockpit.
  """
  @spec dashboard_data() :: map()
  def dashboard_data do
    metrics = get_metrics()

    %{
      title: "Semantic Layer",
      status: metrics.health.status,
      kpis: [
        %{
          name: "Total Operations",
          value: metrics.bridge.total_calls,
          unit: "calls",
          trend: :stable
        },
        %{
          name: "Failure Rate",
          value: Float.round(metrics.bridge.failure_rate * 100, 2),
          unit: "%",
          trend:
            if(metrics.bridge.failure_rate > @failure_rate_warning, do: :rising, else: :stable),
          alarm_level:
            cond do
              metrics.bridge.failure_rate >= @failure_rate_critical -> :critical
              metrics.bridge.failure_rate >= @failure_rate_warning -> :warning
              true -> :normal
            end
        },
        %{
          name: "Avg Latency",
          value: metrics.performance.avg_latency_ms,
          unit: "ms",
          trend: :stable,
          alarm_level:
            cond do
              metrics.performance.avg_latency_ms >= @latency_critical_ms -> :critical
              metrics.performance.avg_latency_ms >= @latency_warning_ms -> :warning
              true -> :normal
            end
        },
        %{
          name: "Uptime",
          value: metrics.bridge.uptime_seconds,
          unit: "s",
          trend: :rising
        }
      ],
      operations: [
        %{name: "Triples Added", count: metrics.operations.triple_adds},
        %{name: "SPARQL Queries", count: metrics.operations.queries},
        %{name: "Vector Searches", count: metrics.operations.vector_searches},
        %{name: "Zettels Processed", count: metrics.operations.zettel_processes}
      ],
      circuit_breaker: %{
        state: metrics.bridge.circuit_breaker_state,
        consecutive_failures: metrics.health.consecutive_failures,
        last_failure: metrics.health.last_failure
      }
    }
  end

  # ============================================================================
  # Telemetry Event Handlers
  # ============================================================================

  @spec handle_event(list(atom()), map(), map(), term()) :: :ok
  def handle_event([:semantic, :bridge, :start], _measurements, metadata, _config) do
    Logger.info("Semantic bridge started", metadata)

    update_state(fn state ->
      %{state | bridge_start_time: DateTime.utc_now(), circuit_breaker_state: :closed}
    end)

    publish_to_zenoh("indrajaal/semantic/health", %{
      event: "bridge_start",
      timestamp: DateTime.utc_now()
    })

    :ok
  end

  def handle_event([:semantic, :bridge, :call], %{duration_ms: duration}, metadata, _config) do
    update_state(fn state ->
      latencies = [duration | Enum.take(state.latencies, 999)]

      %{
        state
        | total_calls: state.total_calls + 1,
          latencies: latencies,
          consecutive_failures: 0
      }
    end)

    # Alert on high latency
    if duration >= @latency_critical_ms do
      alert(:critical, "Semantic bridge latency critical", %{
        duration_ms: duration,
        method: metadata[:method]
      })
    end

    :ok
  end

  def handle_event([:semantic, :bridge, :failure], %{count: count}, _metadata, _config) do
    update_state(fn state ->
      %{
        state
        | total_failures: state.total_failures + 1,
          last_failure: DateTime.utc_now(),
          consecutive_failures: count,
          circuit_breaker_state: if(count >= 3, do: :open, else: :closed)
      }
    end)

    # Alert on circuit breaker open
    if count >= 3 do
      alert(:critical, "Semantic bridge circuit breaker OPEN", %{
        consecutive_failures: count
      })
    end

    :ok
  end

  def handle_event([:semantic, :triple, :add], _measurements, _metadata, _config) do
    update_state(fn state ->
      %{state | triple_adds: state.triple_adds + 1}
    end)

    :ok
  end

  def handle_event([:semantic, :triple, :add_batch], %{count: count}, _metadata, _config) do
    update_state(fn state ->
      %{state | triple_adds: state.triple_adds + count}
    end)

    :ok
  end

  def handle_event([:semantic, :triple, :remove], _measurements, _metadata, _config) do
    update_state(fn state ->
      %{state | triple_removes: state.triple_removes + 1}
    end)

    :ok
  end

  def handle_event([:semantic, :query, :sparql], _measurements, _metadata, _config) do
    update_state(fn state ->
      %{state | queries: state.queries + 1}
    end)

    :ok
  end

  def handle_event([:semantic, :vector, :similar], _measurements, _metadata, _config) do
    update_state(fn state ->
      %{state | vector_searches: state.vector_searches + 1}
    end)

    :ok
  end

  def handle_event([:semantic, :zettel, :process], _measurements, _metadata, _config) do
    update_state(fn state ->
      %{state | zettel_processes: state.zettel_processes + 1}
    end)

    :ok
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp start_metric_publisher do
    # Start periodic task to publish metrics every 30s
    Task.start(fn ->
      Process.sleep(@metric_interval)
      publish_loop()
    end)
  end

  defp publish_loop do
    publish_metrics()
    Process.sleep(@metric_interval)
    publish_loop()
  end

  # State management using process dictionary (simple in-memory)
  defp get_state do
    Process.get(:semantic_telemetry_state, initial_state())
  end

  defp update_state(fun) do
    state = get_state()
    new_state = fun.(state)
    Process.put(:semantic_telemetry_state, new_state)
    new_state
  end

  defp initial_state do
    %{
      bridge_start_time: nil,
      total_calls: 0,
      total_failures: 0,
      triple_adds: 0,
      triple_removes: 0,
      queries: 0,
      vector_searches: 0,
      zettel_processes: 0,
      latencies: [],
      last_failure: nil,
      consecutive_failures: 0,
      circuit_breaker_state: :closed
    }
  end

  defp uptime_seconds(nil), do: 0

  defp uptime_seconds(start_time) do
    DateTime.diff(DateTime.utc_now(), start_time, :second)
  end

  defp calculate_failure_rate(%{total_calls: 0}), do: 0.0

  defp calculate_failure_rate(state) do
    state.total_failures / state.total_calls
  end

  defp calculate_avg_latency(%{latencies: []}), do: 0.0

  defp calculate_avg_latency(state) do
    Enum.sum(state.latencies) / length(state.latencies)
  end

  defp calculate_percentile(%{latencies: []}, _percentile), do: 0.0

  defp calculate_percentile(state, percentile) do
    sorted = Enum.sort(state.latencies)
    index = trunc(length(sorted) * percentile / 100)
    Enum.at(sorted, index, 0.0)
  end

  defp determine_health_status(state) do
    cond do
      state.circuit_breaker_state == :open -> :critical
      state.consecutive_failures >= 2 -> :degraded
      calculate_failure_rate(state) >= @failure_rate_critical -> :critical
      calculate_failure_rate(state) >= @failure_rate_warning -> :warning
      calculate_avg_latency(state) >= @latency_critical_ms -> :degraded
      calculate_avg_latency(state) >= @latency_warning_ms -> :warning
      true -> :healthy
    end
  end

  defp publish_to_zenoh(topic, data) do
    # Use Zenoh NIF if available (SKIP_ZENOH_NIF=0)
    if Application.get_env(:indrajaal, :zenoh_enabled, false) do
      try do
        Indrajaal.Observability.ZenohPublisher.publish(topic, data)
      rescue
        e ->
          Logger.debug("Zenoh publish failed (non-critical)", topic: topic, error: inspect(e))
          :ok
      end
    else
      # Fallback: log for development
      Logger.debug("Zenoh disabled - would publish to #{topic}", data: data)
      :ok
    end
  end

  defp alert(level, message, metadata) do
    # Publish alert to Zenoh
    alert_data = %{
      level: level,
      message: message,
      metadata: metadata,
      timestamp: DateTime.utc_now(),
      source: "semantic_telemetry"
    }

    publish_to_zenoh("indrajaal/semantic/alerts", alert_data)

    # Also log locally
    case level do
      :critical -> Logger.error(message, metadata)
      :warning -> Logger.warning(message, metadata)
      _ -> Logger.info(message, metadata)
    end
  end
end
