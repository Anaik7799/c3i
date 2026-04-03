defmodule Indrajaal.Timescale.AnalyticsQuery do
  @moduledoc """
  🚀 Enterprise TimescaleDB Analytics Query Engine - SOPv5.1 Cybernetic Execution
  ==============================================================================
  Date: 2025 - 08 - 09 09:58:00 CEST
  Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Container - Only + Git - based
  Agent: Analytics Enhancement Worker - 2

  High - performance analytics queries for TimescaleDB hypertables with:
  - Time - series aggregations with bucket functions
  - Real - time dashboard data preparation
  - Multi - tenant query optimization
  - Continuous aggregate utilization
  - Performance metric analysis
  - Alarm trend analysis
  - Event correlation queries

  ## Query Categories

  ### Real - time Dashboards
  - Current system status
  - Live alarm counts
  - Performance metrics
  - User activity trends

  ### Historical Analysis
  - Time - series trends
  - Comparative analysis
  - Pattern detection
  - Anomaly identification

  ### Business Intelligence
  - KPI calculations
  - Usage analytics
  - Performance benchmarks
  - Cost optimization data

  ## Usage Examples

      # Get hourly event counts for the last 24 hours
      AnalyticsQuery.hourly_event_counts(tenant_id, hours: 24)

      # Get alarm resolution times
      AnalyticsQuery.alarm_resolution_times(tenant_id, days: 7)

      # Get performance metrics trend
      AnalyticsQuery.performance_trend("response_time", tenant_id, hours: 6)

      # Get user activity heatmap
      AnalyticsQuery.__user_activity_heatmap(tenant_id, days: 30)
  """

  import Ecto.Query
  alias Indrajaal.Repo
  alias Indrajaal.Shared.UnifiedQuerySystem
  alias Indrajaal.Aggregation
  require Logger

  @doc """
  Get hourly event counts for a tenant over a specified time period.
  Uses continuous aggregates for optimal performance.
  """
  @spec hourly_event_counts(Ecto.UUID.t(), keyword()) :: list(map())
  def hourly_event_counts(tenant_id, opts \\ []) do
    hours = opts[:hours] || 24
    event_types = opts[:event_types] || :all

    # Base query logic moved to TimescaleQueryUtilities.build_event_count_query / 3 for duplicate elimination

    # Use shared utility to eliminate Mass 33 duplication
    query =
      TimescaleQueryUtilities.build_event_count_query(
        tenant_id,
        event_types,
        hours: hours
      )

    Repo.all(query)
  rescue
    error ->
      Logger.error("Failed to get hourly event counts", error: error, tenant_id: tenant_id)
      []
  end

  @doc """
  Get alarm resolution metrics for a tenant over a specified time period.
  """
  @spec alarm_resolution_times(Ecto.UUID.t(), keyword()) :: list(map())
  def alarm_resolution_times(tenant_id, opts \\ []) do
    days = opts[:days] || 7
    severity = opts[:severity] || :all
    alarm_type = opts[:alarm_type] || :all

    # Use shared utility to eliminate Mass 26 duplication
    query =
      TimescaleQueryUtilities.build_alarm_resolution_query(
        tenant_id,
        severity,
        alarm_type,
        days: days
      )

    Repo.all(query)
  rescue
    error ->
      Logger.error("Failed to get alarm resolution times", error: error, tenant_id: tenant_id)
      []
  end

  @doc """
  Get performance metrics trend for a specific metric over time.
  """
  @spec performance_trend(String.t(), Ecto.UUID.t(), keyword()) :: list(map())
  def performance_trend(metric_name, tenant_id, opts \\ []) do
    hours = opts[:hours] || 6
    bucket_size = opts[:bucket_size] || "15 minutes"
    aggregation = opts[:aggregation] || :avg

    # Use shared utility to eliminate Mass 61 duplication
    query =
      UnifiedQuerySystem.build_timescale_aggregation(
        aggregation,
        metric_name,
        tenant_id,
        hours: hours,
        bucket_size: bucket_size
      )

    Repo.all(query)
  rescue
    error ->
      Logger.error("Failed to get performance trend",
        error: error,
        metric_name: metric_name,
        tenant_id: tenant_id
      )

      []
  end

  @doc """
  Get user activity heatmap data for a tenant.
  """
  @spec __user_activity_heatmap(Ecto.UUID.t(), keyword()) :: list(map())
  def __user_activity_heatmap(tenant_id, opts \\ []) do
    days = opts[:days] || 30

    query =
      from(e in "event_logs",
        where: e.tenant_id == ^tenant_id,
        where: e.timestamp >= ago(^days, "day"),
        where: not is_nil(e.user_id),
        select: %{
          date: fragment("DATE(?)", e.timestamp),
          hour: fragment("EXTRACT(hour FROM ?)", e.timestamp),
          activity_count: count(e.id),
          unique_users: fragment("COUNT(DISTINCT ?)", e.user_id)
        },
        group_by: [1, 2],
        order_by: [asc: 1, asc: 2]
      )

    Repo.all(query)
  rescue
    error ->
      Logger.error("Failed to get user activity heatmap", error: error, tenant_id: tenant_id)
      []
  end

  @doc """
  Get real - time system status for dashboard display.
  """
  @spec real_time_system_status(Ecto.UUID.t()) :: map()
  def real_time_system_status(tenant_id) do
    now = DateTime.utc_now()
    one_hour_ago = DateTime.add(now, -3600, :second)

    # Parallel queries for better performance
    tasks = [
      Task.async(fn -> get_recent_event_counts(tenant_id, one_hour_ago) end),
      Task.async(fn -> get_active_alarm_counts(tenant_id) end),
      Task.async(fn -> get_recent_performance_summary(tenant_id, one_hour_ago) end),
      Task.async(fn -> get_active_user_count(tenant_id, one_hour_ago) end)
    ]

    [event_counts, alarm_counts, performance_summary, active_users] =
      Task.await_many(tasks, 5_000)

    %{
      timestamp: now,
      tenant_id: tenant_id,
      events: event_counts || %{},
      alarms: alarm_counts || %{},
      performance: performance_summary || %{},
      active_users: active_users || 0,
      status: determine_system_health(alarm_counts, performance_summary)
    }
  rescue
    error ->
      Logger.error("Failed to get real - time system status", error: error, tenant_id: tenant_id)

      %{
        timestamp: DateTime.utc_now(),
        tenant_id: tenant_id,
        error: "Failed to retrieve system status",
        status: :error
      }
  end

  @doc """
  Get event correlation analysis for debugging and investigation.
  """
  @spec event_correlation_analysis(Ecto.UUID.t(), String.t(), keyword()) :: list(map())
  def event_correlation_analysis(tenant_id, correlation_id, opts \\ []) do
    _time_window = opts[:time_window] || "1 hour"

    # Get the primary event
    query =
      from(e in "event_logs",
        where: e.tenant_id == ^tenant_id,
        where: e.correlation_id == ^correlation_id,
        limit: 1
      )

    primary_event = Repo.one(query)

    return_empty = fn -> [] end

    case primary_event do
      nil ->
        return_empty.()

      event ->
        # Get related events within time window
        # 1 hour before
        time_start = DateTime.add(event.timestamp, -3600, :second)
        # 1 hour after
        time_end = DateTime.add(event.timestamp, 3600, :second)

        query =
          from(e in "event_logs",
            where: e.tenant_id == ^tenant_id,
            where: e.timestamp >= ^time_start,
            where: e.timestamp <= ^time_end,
            where:
              e.user_id == ^event.user_id or
                e.correlation_id == ^correlation_id or
                e.trace_id == ^event.trace_id,
            select: %{
              id: e.id,
              timestamp: e.timestamp,
              event_type: e.event_type,
              event_source: e.event_source,
              action: e.action,
              status: e.status,
              severity: e.severity,
              correlation_id: e.correlation_id,
              trace_id: e.trace_id,
              span_id: e.span_id,
              user_id: e.user_id,
              duration_ms: e.duration_ms,
              metadata: e.metadata,
              time_diff_ms:
                fragment("EXTRACT(EPOCH FROM (? - ?)) * 1000", e.timestamp, ^event.timestamp)
            },
            order_by: [asc: e.timestamp]
          )

        Repo.all(query)
    end
  rescue
    error ->
      Logger.error("Failed to get event correlation analysis",
        error: error,
        tenant_id: tenant_id,
        correlation_id: correlation_id
      )

      []
  end

  @doc """
  Get top performance metrics for optimization insights.
  """
  @spec top_performance_metrics(Ecto.UUID.t(), keyword()) :: list(map())
  def top_performance_metrics(tenant_id, opts \\ []) do
    hours = opts[:hours] || 24
    limit = opts[:limit] || 10
    order_by = opts[:order_by] || :avg_value

    base_query =
      from(m in "performance_metrics",
        where: m.tenant_id == ^tenant_id,
        where: m.timestamp >= ago(^hours, "hour")
      )

    order_clause =
      case order_by do
        :avg_value -> [desc: :avg_value]
        :max_value -> [desc: :max_value]
        :total_samples -> [desc: :total_samples]
        :latest -> [desc: :latest_timestamp]
        _ -> [desc: :avg_value]
      end

    query =
      from(m in base_query,
        select: %{
          metric_name: m.metric_name,
          metric_type: m.metric_type,
          avg_value: avg(m.value),
          max_value: max(m.value),
          min_value: min(m.value),
          total_samples: count(m.id),
          latest_value: fragment("(array_agg(? ORDER BY ? DESC))[1]", m.value, m.timestamp),
          latest_timestamp: max(m.timestamp),
          unit: fragment("(array_agg(DISTINCT ?))[1]", m.unit),
          source: fragment("(array_agg(DISTINCT ?))[1]", m.source)
        },
        group_by: [m.metric_name, m.metric_type],
        order_by: ^order_clause,
        limit: ^limit
      )

    Repo.all(query)
  rescue
    error ->
      Logger.error("Failed to get top performance metrics", error: error, tenant_id: tenant_id)
      []
  end

  ## Private Helper Functions

  # apply_alarm_filters functions moved to Indrajaal.Shared.Aggregation.apply_alarm_resolution_filters / 4 for duplicate elimination

  defp get_recent_event_counts(tenant_id, since) do
    # Use shared utility component to eliminate duplication
    components = Aggregation.create_system_status_components(tenant_id, since)

    Repo.one(components.event_counts)
  rescue
    _ -> %{total: 0, errors: 0, warnings: 0, by_type: %{}}
  end

  defp get_active_alarm_counts(tenant_id) do
    # Use shared utility component to eliminate duplication
    components =
      Aggregation.create_system_status_components(tenant_id, DateTime.utc_now())

    Repo.one(components.alarm_counts)
  rescue
    _ -> %{total: 0, critical: 0, warning: 0, info: 0, acknowledged: 0}
  end

  defp get_recent_performance_summary(tenant_id, since) do
    # Use shared utility component to eliminate duplication
    components = Aggregation.create_system_status_components(tenant_id, since)

    Repo.one(components.performance_summary)
  rescue
    _ -> %{total_metrics: 0, avg_response_time: nil, max_memory_usage: nil, avg_cpu_usage: nil}
  end

  defp get_active_user_count(tenant_id, since) do
    # Use shared utility component to eliminate duplication
    components = Aggregation.create_system_status_components(tenant_id, since)

    Repo.one(components.active_users) || 0
  rescue
    _ -> 0
  end

  defp determine_system_health(alarm_counts, performance_summary) do
    cond do
      alarm_counts[:critical] > 0 ->
        :critical

      alarm_counts[:warning] > 5 ->
        :warning

      performance_summary[:avg_response_time] && performance_summary[:avg_response_time] > 1000 ->
        :degraded

      true ->
        :healthy
    end
  rescue
    _ -> :unknown
  end
end
