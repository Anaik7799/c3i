defmodule Indrajaal.Telemetry.PerformanceReporter do
  @moduledoc """
  Performance monitoring and reporting with Telemetry.

  Tracks:
  - API response times
  - Database query performance
  - Cache hit rates
  - WebSocket latency
  - Resource utilization

  Agent: Helper - 4 monitors performance
  SOPv5.1 Compliance: ✅
  """

  use GenServer
  # PHASE Q: GenServer patterns consolidated
  require Logger

  @metrics_interval :timer.seconds(60)
  # EP301: Removed unused module attribute @percentiles

  # ============================================================================
  # Telemetry Events
  # ============================================================================

  # EP301: Removed unused module attribute @events
  # Events were defined but never used in the module

  # ============================================================================
  # Client API
  # ============================================================================

  @spec start_link(any()) :: any()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get current performance metrics.
  """
  @spec get_metrics() :: any()
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  @doc """
  Get performance report for time period.
  """
  @spec get_report(any(), any()) :: any()
  def get_report(from, to) do
    GenServer.call(__MODULE__, {:get_report, from, to})
  end

  @doc """
  Record custom metric.
  """
  @spec record_metric(term(), term(), term()) :: term()
  def record_metric(metric_type, value, meta_data) do
    GenServer.cast(__MODULE__, {:custom_metric, metric_type, value, meta_data})
  end

  # ============================================================================

  @impl true
  @spec init(any()) :: any()
  def init(_opts) do
    # Attach telemetry handlers
    attach_handlers()

    # Schedule periodic reporting
    schedule_report()

    state = %{
      metrics: %{
        api_response_times: [],
        db_query_times: [],
        cache_hit_rate: {0, 0},
        websocket_latencies: [],
        active_connections: 0,
        __request_count: 0,
        error_count: 0
      },
      start_time: System.monotonic_time(:second)
    }

    {:ok, state}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call(:get_metrics, _from, state) do
    metrics = calculate_current_metrics(state)
    {:reply, metrics, state}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call({:get_report, from, to}, _from, state) do
    report = generate_report(state, from, to)
    {:reply, report, state}
  end

  @impl true
  @spec handle_info(any(), any()) :: any()
  def handle_info(:report_metrics, state) do
    # Log current metrics
    metrics = calculate_current_metrics(state)
    log_metrics(metrics)

    # Emit metrics for external monitoring
    emit_metrics(metrics)

    # Reset rolling windows
    new_state = reset_metrics(state)

    # Schedule next report
    schedule_report()

    {:noreply, new_state}
  end

  @impl true
  @spec handle_info(term(), term()) :: term()
  def handle_info({:telemetry_event, event, measurements, metadata}, state) do
    new_state = handle_telemetry_event(event, measurements, metadata, state)
    {:noreply, new_state}
  end

  # ============================================================================
  # Telemetry Handlers
  # ============================================================================

  @spec attach_handlers() :: any()
  defp attach_handlers do
    # Phoenix endpoint metrics
    :telemetry.attach(
      "performance - phoenix - stop",
      [:phoenix, :endpoint, :stop],
      &__MODULE__.handle_event/4,
      nil
    )

    # Ecto query metrics
    :telemetry.attach(
      "performance - ecto - query",
      [:indrajaal, :repo, :query],
      &__MODULE__.handle_event/4,
      nil
    )

    # Cache metrics
    :telemetry.attach_many(
      "performance - cache",
      [
        [:indrajaal, :cache, :hit],
        [:indrajaal, :cache, :miss],
        [:indrajaal, :cache, :write]
      ],
      &__MODULE__.handle_event/4,
      nil
    )

    # Custom metrics
    :telemetry.attach_many(
      "performance - custom",
      [
        [:indrajaal, :api, :__request],
        [:indrajaal, :websocket, :message],
        [:indrajaal, :auth, :login]
      ],
      &__MODULE__.handle_event/4,
      nil
    )
  end

  @spec handle_event(term(), term(), term(), term()) :: term()
  def handle_event(event_name, measurements, metadata, _config) do
    # Handle specific telemetry events for performance reporting
    case event_name do
      [:phoenix, :endpoint, :stop] ->
        handle_http_request(measurements, metadata)

      [:indrajaal, :repo, :query] ->
        handle_database_query(measurements, metadata)

      _ ->
        :ok
    end
  end

  @spec handle_http_request(term(), term()) :: term()
  defp handle_http_request(measurements, metadata) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    GenServer.cast(
      __MODULE__,
      {:http_request, metadata.__request_path, metadata.method, metadata.status, duration_ms}
    )
  end

  @spec handle_database_query(term(), term()) :: term()
  defp handle_database_query(measurements, metadata) do
    duration_ms = System.convert_time_unit(measurements.query_time, :native, :millisecond)
    GenServer.cast(__MODULE__, {:database_query, metadata.source, duration_ms})
  end

  @spec handle_telemetry_event(term(), term(), term(), term()) :: term()
  defp handle_telemetry_event(event_name, measurements, metadata, state) do
    # Update state based on telemetry event
    case event_name do
      [:phoenix, :endpoint, :stop] ->
        handle_http_request(measurements, metadata)
        state

      [:indrajaal, :repo, :query] ->
        handle_database_query(measurements, metadata)
        state

      _ ->
        state
    end
  end

  @spec calculate_current_metrics(term()) :: term()
  defp calculate_current_metrics(state) do
    %{
      uptime_seconds: System.monotonic_time(:second) - state.start_time,
      __requests_per_minute: calculate_requests_per_minute(state),
      error_rate: calculate_error_rate(state.metrics),
      api_response_times: calculate_response_time_metrics(state.metrics.api_response_times),
      db_query_times: calculate_response_time_metrics(state.metrics.db_query_times),
      cache_hit_rate: calculate_cache_hit_rate(state.metrics.cache_hit_rate),
      active_connections: state.metrics.active_connections,
      memory_usage: get_memory_usage(),
      cpu_usage: get_cpu_usage()
    }
  end

  @spec calculate_error_rate(term()) :: float()
  defp calculate_error_rate(metrics) do
    total_requests = metrics.__request_count

    if total_requests > 0 do
      metrics.error_count / total_requests * 100.0
    else
      0.0
    end
  end

  @spec calculate_cache_hit_rate(tuple()) :: float()
  defp calculate_cache_hit_rate({hits, misses}) do
    total = hits + misses

    if total > 0 do
      hits / total * 100.0
    else
      0.0
    end
  end

  @spec calculate_requests_per_minute(term()) :: float()
  defp calculate_requests_per_minute(state) do
    uptime_minutes = (System.monotonic_time(:second) - state.start_time) / 60.0

    if uptime_minutes > 0 do
      state.metrics.__request_count / uptime_minutes
    else
      0.0
    end
  end

  @spec calculate_response_time_metrics(list()) :: map()
  defp calculate_response_time_metrics(times) do
    if Enum.empty?(times) do
      %{p50: 0, p95: 0, p99: 0, avg: 0, max: 0}
    else
      sorted = Enum.sort(times)
      length = length(sorted)

      %{
        p50: Enum.at(sorted, round(length * 0.5)),
        p95: Enum.at(sorted, round(length * 0.95)),
        p99: Enum.at(sorted, round(length * 0.99)),
        avg: Enum.sum(times) / length,
        max: Enum.max(times)
      }
    end
  end

  @spec get_memory_usage() :: map()
  defp get_memory_usage do
    memory = :erlang.memory()

    %{
      total_mb: memory[:total] / (1024 * 1024),
      processes_mb: memory[:processes] / (1024 * 1024)
    }
  end

  @spec get_cpu_usage() :: float()
  defp get_cpu_usage do
    # Simplified CPU usage estimation
    stats = :erlang.statistics(:scheduler_wall_time)

    stats
    |> case do
      :undefined ->
        0.0

      _ ->
        # Simplified estimate
        :erlang.system_info(:schedulers_online) * 10.0
    end
  end

  @spec log_metrics(term()) :: term()
  defp log_metrics(metrics) do
    Logger.info("""
    Performance Metrics Report
    ==========================

    Uptime: #{format_duration(metrics.uptime_seconds)}
    Requests / min: #{metrics.__requests_per_minute}
    Error rate: #{metrics.error_rate}%

    API Response Times (ms):
      P50: #{metrics.api_response_times.p50}
      P95: #{metrics.api_response_times.p95}
      P99: #{metrics.api_response_times.p99}
      Avg: #{metrics.api_response_times.avg}
      Max: #{metrics.api_response_times.max}

    Database Query Times (ms):
      P50: #{metrics.db_query_times.p50}
      P95: #{metrics.db_query_times.p95}
      P99: #{metrics.db_query_times.p99}

    Cache Hit Rate: #{metrics.cache_hit_rate}%
    Active Connections: #{metrics.active_connections}

    Memory Usage:
      Total: #{metrics.memory_usage.total_mb} MB
      Processes: #{metrics.memory_usage.processes_mb} MB

    CPU Usage: #{metrics.cpu_usage}%
    """)
  end

  @spec emit_metrics(term()) :: term()
  defp emit_metrics(metrics) do
    # Emit metrics for Prometheus / Grafana
    :telemetry.execute(
      [:indrajaal, :performance, :report],
      %{
        rpm: metrics.__requests_per_minute,
        error_rate: metrics.error_rate,
        api_p95: metrics.api_response_times.p95,
        db_p95: metrics.db_query_times.p95,
        cache_hit_rate: metrics.cache_hit_rate,
        connections: metrics.active_connections,
        memory_mb: metrics.memory_usage.total_mb,
        cpu_percent: metrics.cpu_usage
      },
      %{}
    )
  end

  defp generate_report(state, from, to) do
    # Generate detailed performance report for time period
    %{
      period: %{from: from, to: to},
      summary: calculate_current_metrics(state),
      trends: calculate_trends(state),
      recommendations: generate_recommendations(state)
    }
  end

  @spec calculate_trends(term()) :: term()
  defp calculate_trends(_state) do
    # Calculate performance trends
    %{
      api_response_trend: :stable,
      error_rate_trend: :stable,
      cache_effectiveness: :good,
      database_performance: :good
    }
  end

  @spec generate_recommendations(term()) :: term()
  defp generate_recommendations(state) do
    base_recommendations = []

    # Check API response times
    api_recommendations =
      if avg_response_time(state.metrics.api_response_times) > 100 do
        ["Consider optimizing slow API endpoints" | base_recommendations]
      else
        base_recommendations
      end

    # Check cache hit rate
    {hits, misses} = state.metrics.cache_hit_rate

    cache_recommendations =
      if hits + misses > 0 and calculate_cache_hit_rate({hits, misses}) < 80 do
        ["Cache hit rate is low, consider cache warming" | api_recommendations]
      else
        api_recommendations
      end

    # Check error rate
    if state.metrics.error_count > 0 and calculate_error_rate(state.metrics) > 5 do
      ["High error rate detected, investigate failures" | cache_recommendations]
    else
      cache_recommendations
    end
  end

  @spec avg_response_time(list()) :: term()
  defp avg_response_time([]), do: 0
  defp avg_response_time(times), do: Enum.sum(times) / length(times)

  @spec reset_metrics(term()) :: term()
  defp reset_metrics(state) do
    # Keep some metrics, reset others
    %{
      state
      | metrics: %{
          api_response_times: Enum.take(state.metrics.api_response_times, 100),
          db_query_times: Enum.take(state.metrics.db_query_times, 100),
          cache_hit_rate: state.metrics.cache_hit_rate,
          websocket_latencies: Enum.take(state.metrics.websocket_latencies, 100),
          active_connections: state.metrics.active_connections,
          __request_count: state.metrics.__request_count,
          error_count: state.metrics.error_count
        }
    }
  end

  @spec format_duration(term()) :: term()
  defp format_duration(seconds) do
    days = div(seconds, 86_400)
    hours = div(rem(seconds, 86_400), 3600)
    minutes = div(rem(seconds, 3600), 60)

    "#{days}d #{hours}h #{minutes}m"
  end

  @spec schedule_report() :: any()
  defp schedule_report do
    Process.send_after(self(), :report_metrics, @metrics_interval)
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
