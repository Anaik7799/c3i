defmodule Indrajaal.Shared.AggregationQueryBuilder do
  # PHASE G CONSOLIDATION: Timescale query duplications consolidated
  # Strategic Impact: Internal query duplications eliminated

  @deprecated "Use Indrajaal.Shared.UnifiedQuerySystem instead. This module has been consolidated into UnifiedQuerySystem for better maintainability and performance."
  @moduledoc """
  Aggregation Query Builder for TimescaleDB Operations

  This module provides the strategy pattern implementation for different
  aggregation types and query building patterns. It works in conjunction
  with TimescaleQueryUtilities to eliminate massive duplications.

  ## Architecture

  This module implements the Strategy Pattern for aggregation operations:
  - Each aggregation type (:avg, :max, :min, :sum, :count) has specific logic
  - Query building is parameterized to eliminate copy - paste duplication
  - Fragment generation is centralized for consistency

  ## Eliminated Duplications

  This module specifically addresses the internal structure duplications
  found in the original analytics_query.ex file by providing reusable
  query building components.

  ## SOPv5.1 Compliance

  - **TDG Methodology**: All functions tested before implementation
  - **Strategy Pattern**: Systematic approach to aggregation variants
  - **Performance Optimization**: Optimized query structure generation
  - **Type Safety**: Comprehensive type specifications and validation
  """

  import Ecto.Query
  require Logger

  @doc """
  Create aggregation select map for performance trend queries.

  This function generates the select clause for time - series aggregation
  queries, eliminating the duplication of select clause structure across
  different aggregation types.
  """
  @spec create_aggregation_select(atom(), atom()) :: map()
  def create_aggregation_select(aggregation, table_alias) do
    %{
      time_bucket: create_time_bucket_fragment("15 minutes", :timestamp),
      value: get_aggregation_fragment(aggregation, :value),
      sample_count: dynamic([{^table_alias, t}], count(t.id)),
      metric_type: dynamic([{^table_alias, t}], t.metric_type),
      unit: dynamic([{^table_alias, t}], t.unit)
    }
  end

  @doc """
  Get the appropriate aggregation fragment for a given aggregation type.

  This function implements the strategy pattern for aggregation operations,
  eliminating the need for separate query branches for each aggregation type.
  """
  @spec get_aggregation_fragment(atom(), atom()) :: String.t()
  def get_aggregation_fragment(aggregation, _field) do
    case aggregation do
      :avg ->
        "AVG"

      :max ->
        "MAX"

      :min ->
        "MIN"

      :sum ->
        "SUM"

      :count ->
        "COUNT"

      _ ->
        # Default to AVG for unknown aggregation types
        Logger.warning("Unknown aggregation type #{aggregation}, defaulting to AVG")
        "AVG"
    end
  end

  @doc """
  Create time bucket fragment for TimescaleDB time - series queries.

  This function generates the time_bucket function call for TimescaleDB,
  providing consistent time bucketing across all query types.
  """
  def create_time_bucket_fragment(bucket_size, time_field) do
    dynamic([t], fragment("time_bucket(?, ?)", ^bucket_size, field(t, ^time_field)))
  end

  @doc """
  Create base performance metrics query with standard filtering.

  This function provides the foundation for performance metrics queries,
  eliminating duplication in basic query structure.
  """
  @spec create_base_performance_query(Ecto.UUID.t(), String.t(), integer(), keyword()) ::
          Ecto.Query.t()
  def create_base_performance_query(tenant_id, metric_name, hours, opts \\ []) do
    validate_base_performance_params!(tenant_id, metric_name, hours)

    table = opts[:table] || "performance_metrics"
    time_field = opts[:time_field] || :timestamp

    from(m in table,
      where: m.tenant_id == ^tenant_id,
      where: m.metric_name == ^metric_name,
      where: field(m, ^time_field) >= ago(^hours, "hour")
    )
  end

  @doc """
  This function has been moved to TimescaleQueryUtilities for direct implementation.

  The original complex aggregation logic caused Ecto compilation issues,
  so we use direct query building in TimescaleQueryUtilities instead.
  """
  def applyaggregation_to_query(_base_query, _aggregation, _opts \\ []) do
    raise "This function has been replaced by TimescaleQueryUtilities.build_performance_trend_query / 4"
  end

  @doc """
  Create __event count select map for hourly __event queries.

  This function generates the select clause for __event count queries,
  eliminating duplication between :all and specific __event type queries.
  """
  @spec create_event_count_select(:all | list(String.t()), atom()) :: map()
  def create_event_count_select(_event_types, table_alias) do
    # Same select structure regardless of __event type filtering
    %{
      hour: dynamic([{^table_alias, e}], e.hour),
      __event_type: dynamic([{^table_alias, e}], e.__event_type),
      __event_source: dynamic([{^table_alias, e}], e.__event_source),
      __event_count: dynamic([{^table_alias, e}], e.__event_count),
      unique_users: dynamic([{^table_alias, e}], e.unique_users),
      avg_duration_ms: dynamic([{^table_alias, e}], e.avg_duration_ms),
      error_count: dynamic([{^table_alias, e}], e.error_count),
      warning_count: dynamic([{^table_alias, e}], e.warning_count)
    }
  end

  @doc """
  Apply alarm resolution filters to base query.

  This function applies severity and alarm type filters systematically,
  eliminating the duplication in the original apply_alarm_filters function.
  """
  # query, :all, :all, table_alias), do: query
  # Claude Agent: EP-076 - Unreachable function clause commented
  @spec apply_alarm_resolution_filters(term(), term(), term(), term()) :: term()
  def apply_alarm_resolution_filters(query, severity, :all, table_alias) when severity != :all do
    from([{^table_alias, a}] in query, where: a.severity == ^to_string(severity))
  end

  def apply_alarm_resolution_filters(query, :all, alarm_type, table_alias)
      when alarm_type != :all do
    from([{^table_alias, a}] in query, where: a.alarm_type == ^to_string(alarm_type))
  end

  def apply_alarm_resolution_filters(query, severity, alarm_type, table_alias) do
    from([{^table_alias, a}] in query,
      where: a.severity == ^to_string(severity),
      where: a.alarm_type == ^to_string(alarm_type)
    )
  end

  @doc """
  Create alarm resolution select map with resolution rate calculation.

  This function generates the select clause for alarm resolution queries,
  including the resolution rate calculation with proper division by zero handling.
  """
  @spec create_alarm_resolution_select(atom()) :: map()
  def create_alarm_resolution_select(table_alias) do
    %{
      day: dynamic([{^table_alias, a}], a.day),
      alarm_type: dynamic([{^table_alias, a}], a.alarm_type),
      severity: dynamic([{^table_alias, a}], a.severity),
      total_alarms: dynamic([{^table_alias, a}], a.alarm_count),
      acknowledged_count: dynamic([{^table_alias, a}], a.acknowledged_count),
      resolved_count: dynamic([{^table_alias, a}], a.resolved_count),
      avg_resolution_minutes: dynamic([{^table_alias, a}], a.avg_resolution_minutes),
      resolution_rate:
        dynamic(
          [{^table_alias, a}],
          fragment(
            "ROUND((?::numeric / NULLIF(?::numeric, 0)) * 100, 2)",
            a.resolved_count,
            a.alarm_count
          )
        )
    }
  end

  @doc """
  Create system status query components.

  This function provides reusable components for real - time system status
  queries, eliminating duplication in dashboard query construction.
  """
  @spec create_system_status_components(Ecto.UUID.t(), DateTime.t()) :: map()
  def create_system_status_components(tenant_id, since_time) do
    %{
      __event_counts: create_event_count_query_component(tenant_id, since_time),
      alarm_counts: create_alarm_count_query_component(tenant_id),
      performance_summary: create_performance_summary_component(tenant_id, since_time),
      active_users: create_active_user_count_component(tenant_id, since_time)
    }
  end

  # Private helper functions

  defp create_event_count_query_component(tenant_id, since_time) do
    from(e in "__event_logs",
      where: e.tenant_id == ^tenant_id,
      where: e.timestamp >= ^since_time,
      select: %{
        total: count(e.id),
        errors: filter(count(e.id), e.severity == "error"),
        warnings: filter(count(e.id), e.severity == "warn"),
        by_type: fragment("json_object_agg(?, ?)", e.__event_type, fragment("count(*)"))
      },
      group_by: []
    )
  end

  defp create_alarm_count_query_component(tenant_id) do
    from(a in "alarm_events",
      where: a.tenant_id == ^tenant_id,
      where: a.resolved == false,
      select: %{
        total: count(a.id),
        critical: filter(count(a.id), a.severity == "critical"),
        warning: filter(count(a.id), a.severity == "warning"),
        info: filter(count(a.id), a.severity == "info"),
        acknowledged: filter(count(a.id), a.acknowledged == true)
      },
      group_by: []
    )
  end

  defp create_performance_summary_component(tenant_id, since_time) do
    from(m in "performance_metrics",
      where: m.tenant_id == ^tenant_id,
      where: m.timestamp >= ^since_time,
      select: %{
        total_metrics: count(m.id),
        avg_response_time: filter(avg(m.value), m.metric_name == "response_time"),
        max_memory_usage: filter(max(m.value), m.metric_name == "memory_usage"),
        avg_cpu_usage: filter(avg(m.value), m.metric_name == "cpu_usage")
      },
      group_by: []
    )
  end

  defp create_active_user_count_component(tenant_id, since_time) do
    from(e in "__event_logs",
      where: e.tenant_id == ^tenant_id,
      where: e.timestamp >= ^since_time,
      where: not is_nil(e.user_id),
      select: fragment("COUNT(DISTINCT ?)", e.user_id)
    )
  end

  # Validation functions

  defp validate_base_performance_params!(tenant_id, metric_name, hours) do
    unless tenant_id do
      raise ArgumentError, "tenant_id cannot be nil"
    end

    unless is_binary(metric_name) and String.length(metric_name) > 0 do
      raise ArgumentError, "metric_name must be a non - empty string"
    end

    unless is_integer(hours) and hours > 0 do
      raise ArgumentError, "hours must be a positive integer"
    end
  end
end
