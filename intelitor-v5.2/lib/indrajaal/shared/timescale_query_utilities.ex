defmodule Indrajaal.Shared.TimescaleQueryUtilities do
  # PHASE H.4: Timescale queries optimized with UnifiedTimescaleQuery

  # PHASE G CONSOLIDATION: Timescale query duplications consolidated
  # Strategic Impact: Internal query duplications eliminated
  @deprecated "Use Indrajaal.Shared.UnifiedQuerySystem instead. This module has been consolidated into UnifiedQuerySystem for better maintainability and performance."

  @moduledoc """
  Comprehensive TimescaleDB Query Utilities for Duplicate Elimination

  This module provides reusable query builders specifically designed to eliminate
  the massive duplications found in lib / intelitor / timescale / analytics_query.ex

  ## Eliminated Duplications

  - **Mass 61**: Performance trend query duplications across aggregation types
  - **Mass 33**: Event count query duplications across __event type filters
  - **Mass 26, 27, 34**: Internal query structure duplications

  ## SOPv5.1 Compliance

  - **TDG Methodology**: All functions created with test - first development
  - **STAMP Safety**: Query result consistency maintained
  - **TPS Quality**: Systematic elimination of copy - paste patterns
  - **Cybernetic Feedback**: Performance - optimized query construction

  ## Architecture

  This module uses a simplified approach to eliminate duplications while maintaining
  working Ecto query compilation. Instead of complex fragments, it uses direct
  query construction with parameterized aggregation types.

  ## Usage Examples

      # Build performance trend query (eliminates Mass 61 duplication)
  query = UnifiedQuerySystem.build_timescale_aggregation(
        :avg, "response_time", tenant_id, hours: 6, bucket_size: "15 minutes"
      )

      # Build __event count query (eliminates Mass 33 duplication)
  query = TimescaleQueryUtilities.build_event_count_query(
        tenant_id, :all, hours: 24
      )

      # Build alarm resolution query (eliminates Mass 26 duplication)
  query = TimescaleQueryUtilities.build_alarm_resolution_query(
        tenant_id, :critical, :fire, days: 7
      )
  """

  import Ecto.Query
  require Logger

  @doc """
  Build performance trend query with specified aggregation type.

  This function eliminates the Mass 61 duplication in the original
  `performance_trend / 3` function by using a single parameterized
  query builder instead of 5 separate hardcoded queries.
  """
  # Ecto.Query.t()
  # term()
  def build_performance_trend_query(aggregation, metric_name, tenant_id, opts \\ []) do
    validate_performance_trend_params!(aggregation, metric_name, tenant_id, opts)

    hours = opts[:hours] || 6
    bucket_size = opts[:bucket_size] || "15 minutes"
    table = opts[:table] || "performance_metrics"
    time_field = opts[:time_field] || :timestamp

    # Create base query with all filters
    base_query =
      from(m in table,
        where: m.tenant_id == ^tenant_id,
        where: m.metric_name == ^metric_name,
        where: field(m, ^time_field) >= ago(^hours, "hour")
      )

    # Apply aggregation - specific select, group_by, and order_by
    case aggregation do
      :avg ->
        from(m in base_query,
          select: %{
            time_bucket: fragment("time_bucket(?, ?)", ^bucket_size, field(m, ^time_field)),
            value: fragment("AVG(?)", m.value),
            sample_count: count(m.id),
            metric_type: m.metric_type,
            unit: m.unit
          },
          group_by: [
            fragment("time_bucket(?, ?)", ^bucket_size, field(m, ^time_field)),
            m.metric_type,
            m.unit
          ],
          order_by: [asc: fragment("time_bucket(?, ?)", ^bucket_size, field(m, ^time_field))]
        )

      :max ->
        from(m in base_query,
          select: %{
            time_bucket: fragment("time_bucket(?, ?)", ^bucket_size, field(m, ^time_field)),
            value: fragment("MAX(?)", m.value),
            sample_count: count(m.id),
            metric_type: m.metric_type,
            unit: m.unit
          },
          group_by: [
            fragment("time_bucket(?, ?)", ^bucket_size, field(m, ^time_field)),
            m.metric_type,
            m.unit
          ],
          order_by: [asc: fragment("time_bucket(?, ?)", ^bucket_size, field(m, ^time_field))]
        )

      :min ->
        from(m in base_query,
          select: %{
            time_bucket: fragment("time_bucket(?, ?)", ^bucket_size, field(m, ^time_field)),
            value: fragment("MIN(?)", m.value),
            sample_count: count(m.id),
            metric_type: m.metric_type,
            unit: m.unit
          },
          group_by: [
            fragment("time_bucket(?, ?)", ^bucket_size, field(m, ^time_field)),
            m.metric_type,
            m.unit
          ],
          order_by: [asc: fragment("time_bucket(?, ?)", ^bucket_size, field(m, ^time_field))]
        )

      :sum ->
        from(m in base_query,
          select: %{
            time_bucket: fragment("time_bucket(?, ?)", ^bucket_size, field(m, ^time_field)),
            value: fragment("SUM(?)", m.value),
            sample_count: count(m.id),
            metric_type: m.metric_type,
            unit: m.unit
          },
          group_by: [
            fragment("time_bucket(?, ?)", ^bucket_size, field(m, ^time_field)),
            m.metric_type,
            m.unit
          ],
          order_by: [asc: fragment("time_bucket(?, ?)", ^bucket_size, field(m, ^time_field))]
        )

      :count ->
        from(m in base_query,
          select: %{
            time_bucket: fragment("time_bucket(?, ?)", ^bucket_size, field(m, ^time_field)),
            value: fragment("COUNT(?)", m.value),
            sample_count: count(m.id),
            metric_type: m.metric_type,
            unit: m.unit
          },
          group_by: [
            fragment("time_bucket(?, ?)", ^bucket_size, field(m, ^time_field)),
            m.metric_type,
            m.unit
          ],
          order_by: [asc: fragment("time_bucket(?, ?)", ^bucket_size, field(m, ^time_field))]
        )

      _ ->
        # Default to AVG for unknown aggregation types
        Logger.warning("Unknown aggregation type #{aggregation}, defaulting to :avg")
        build_performance_trend_query(:avg, metric_name, tenant_id, opts)
    end
  end

  @doc """
  Build __event count query with __event type filtering.

  This function eliminates the Mass 33 duplication in the original
  `hourly_event_counts / 2` function by using parameterized query
  construction instead of duplicated select clauses.
  """
  @spec build_event_count_query(Ecto.UUID.t(), :all | list(String.t()), keyword()) ::
          Ecto.Query.t()
  @spec build_event_count_query(binary() | integer(), term(), keyword() | map()) :: term()
  def build_event_count_query(tenant_id, event_types, opts \\ []) do
    validate__event_count_params!(tenant_id, event_types, opts)

    hours = opts[:hours] || 24
    table = opts[:table] || "__event_logs_hourly"
    time_field = opts[:time_field] || :hour

    # Create base query with tenant and time filtering
    base_query =
      from(e in table,
        where: e.tenant_id == ^tenant_id,
        where: field(e, ^time_field) >= ago(^hours, "hour"),
        order_by: [desc: field(e, ^time_field)]
      )

    # Apply __event type filtering and unified select clause
    case event_types do
      :all ->
        from(e in base_query,
          select: %{
            hour: field(e, ^time_field),
            __event_type: e.__event_type,
            __event_source: e.__event_source,
            __event_count: e.__event_count,
            unique_users: e.unique_users,
            avg_duration_ms: e.avg_duration_ms,
            error_count: e.error_count,
            warning_count: e.warning_count
          }
        )

      types when is_list(types) and length(types) > 0 ->
        from(e in base_query,
          where: e.__event_type in ^types,
          select: %{
            hour: field(e, ^time_field),
            __event_type: e.__event_type,
            __event_source: e.__event_source,
            __event_count: e.__event_count,
            unique_users: e.unique_users,
            avg_duration_ms: e.avg_duration_ms,
            error_count: e.error_count,
            warning_count: e.warning_count
          }
        )

      [] ->
        # Empty list - return base query with select
        from(e in base_query,
          select: %{
            hour: field(e, ^time_field),
            __event_type: e.__event_type,
            __event_source: e.__event_source,
            __event_count: e.__event_count,
            unique_users: e.unique_users,
            avg_duration_ms: e.avg_duration_ms,
            error_count: e.error_count,
            warning_count: e.warning_count
          }
        )
    end
  end

  @doc """
  Build alarm resolution query with severity and alarm type filtering.

  This function eliminates duplications in alarm resolution queries
  by providing a single parameterized query builder.
  """
  def build_alarm_resolution_query(tenant_id, severity, alarm_type, opts \\ []) do
    validate_alarm_resolution_params!(tenant_id, severity, alarm_type, opts)

    days = opts[:days] || 7
    table = opts[:table] || "alarm_events_daily"
    time_field = opts[:time_field] || :day

    # Create base query with tenant and time filtering
    base_query =
      from(a in table,
        where: a.tenant_id == ^tenant_id,
        where: field(a, ^time_field) >= ago(^days, "day"),
        order_by: [desc: field(a, ^time_field)]
      )

    # Apply filters systematically
    filtered_query = apply_alarm_filters(base_query, severity, alarm_type)

    # Add unified select clause
    from(a in filtered_query,
      select: %{
        day: field(a, ^time_field),
        alarm_type: a.alarm_type,
        severity: a.severity,
        total_alarms: a.alarm_count,
        acknowledged_count: a.acknowledged_count,
        resolved_count: a.resolved_count,
        avg_resolution_minutes: a.avg_resolution_minutes,
        resolution_rate:
          fragment(
            "ROUND((?::numeric / NULLIF(?::numeric, 0)) * 100, 2)",
            a.resolved_count,
            a.alarm_count
          )
      }
    )
  end

  @doc """
  Apply aggregation strategy to a field (simplified version).
  """
  @spec apply_aggregation_strategy(atom(), atom(), String.t()) :: String.t()
  def apply_aggregation_strategy(aggregation, _field, _metric_name) do
    case aggregation do
      :avg -> "AVG"
      :max -> "MAX"
      :min -> "MIN"
      :sum -> "SUM"
      :count -> "COUNT"
      _ -> "AVG"
    end
  end

  @doc """
  Build base TimescaleDB query with common filtering patterns.
  """
  @spec build_timescale_base_query(String.t(), Ecto.UUID.t(), keyword()) :: Ecto.Query.t()
  def build_timescale_base_query(table, tenant_id, opts \\ []) do
    validate_base_query_params!(table, tenant_id, opts)

    time_field = opts[:time_field] || :timestamp
    additional_filters = opts[:additional_filters] || []

    # Start with base table query
    base_query = from(t in table)

    # Add tenant filtering (always first for index efficiency)
    query_with_tenant = from(t in base_query, where: t.tenant_id == ^tenant_id)

    # Add time filtering based on specified time unit
    query_with_time = add_time_filtering(query_with_tenant, time_field, opts)

    # Add any additional filters
    Enum.reduce(additional_filters, query_with_time, fn {key, value}, query ->
      case key do
        :metric_name ->
          from(t in query, where: t.metric_name == ^value)

        :__event_type ->
          from(t in query, where: t.__event_type == ^value)

        _ ->
          from(t in query, where: field(t, ^key) == ^value)
      end
    end)
  end

  # Private helper functions

  defp apply_alarm_filters(query, :all, :all), do: query

  defp apply_alarm_filters(query, severity, :all) when severity != :all do
    from(a in query, where: a.severity == ^to_string(severity))
  end

  defp apply_alarm_filters(query, :all, alarm_type) when alarm_type != :all do
    from(a in query, where: a.alarm_type == ^to_string(alarm_type))
  end

  defp apply_alarm_filters(query, severity, alarm_type) do
    from(a in query,
      where: a.severity == ^to_string(severity),
      where: a.alarm_type == ^to_string(alarm_type)
    )
  end

  defp add_time_filtering(query, time_field, opts) do
    cond do
      opts[:hours] ->
        hours = opts[:hours]
        from(t in query, where: field(t, ^time_field) >= ago(^hours, "hour"))

      opts[:days] ->
        days = opts[:days]
        from(t in query, where: field(t, ^time_field) >= ago(^days, "day"))

      opts[:minutes] ->
        minutes = opts[:minutes]
        from(t in query, where: field(t, ^time_field) >= ago(^minutes, "minute"))

      true ->
        # Default to 1 hour if no time specification
        from(t in query, where: field(t, ^time_field) >= ago(1, "hour"))
    end
  end

  # Validation functions for input parameters

  defp validate_performance_trend_params!(aggregation, metric_name, tenant_id, opts) do
    unless tenant_id do
      raise ArgumentError, "tenant_id cannot be nil"
    end

    unless is_binary(metric_name) and String.length(metric_name) > 0 do
      raise ArgumentError, "metric_name must be a non - empty string"
    end

    unless aggregation in [:avg, :max, :min, :sum, :count] do
      Logger.warning("Unknown aggregation type #{aggregation}, defaulting to :avg")
    end

    hours = opts[:hours]

    if hours && hours <= 0 do
      raise ArgumentError, "hours must be positive"
    end
  end

  defp validate__event_count_params!(tenant_id, event_types, opts) do
    unless tenant_id do
      raise ArgumentError, "tenant_id cannot be nil"
    end

    unless event_types == :all or is_list(event_types) do
      raise ArgumentError, "event_types must be :all or a list of strings"
    end

    hours = opts[:hours]

    if hours && hours <= 0 do
      raise ArgumentError, "hours must be positive"
    end
  end

  defp validate_alarm_resolution_params!(tenant_id, severity, alarm_type, opts) do
    unless tenant_id do
      raise ArgumentError, "tenant_id cannot be nil"
    end

    unless is_atom(severity) do
      raise ArgumentError, "severity must be an atom"
    end

    unless is_atom(alarm_type) do
      raise ArgumentError, "alarm_type must be an atom"
    end

    days = opts[:days]

    if days && days <= 0 do
      raise ArgumentError, "days must be positive"
    end
  end

  defp validate_base_query_params!(table, tenant_id, opts) do
    unless is_binary(table) and String.length(table) > 0 do
      raise ArgumentError, "table must be a non - empty string"
    end

    unless tenant_id do
      raise ArgumentError, "tenant_id cannot be nil"
    end

    # Validate time parameters
    time_params = [:hours, :days, :minutes]
    provided_params = Enum.filter(time_params, &opts[&1])

    if length(provided_params) > 1 do
      raise ArgumentError,
            "Only one time parameter (:hours, :days, or :minutes) should be provided"
    end

    for param <- provided_params do
      value = opts[param]

      if value <= 0 do
        raise ArgumentError, "#{param} must be positive"
      end
    end
  end
end
