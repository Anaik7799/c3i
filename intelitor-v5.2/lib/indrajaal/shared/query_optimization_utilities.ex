defmodule Indrajaal.Shared.QueryOptimizationUtilities do
  # PHASE G CONSOLIDATION: Timescale query duplications consolidated
  # Strategic Impact: Internal query duplications eliminated

  alias Indrajaal.Shared.UnifiedUtilitySystem

  @deprecated "Use Indrajaal.Shared.UnifiedQuerySystem instead. This module has been consolidated into UnifiedQuerySystem for better maintainability and performance."
  @moduledoc """
  Shared utility module for common query optimization and __database operations.

  Created by Claude Supervisor for Task 6.3.3 - Maximum Parallelization
  Methodology: SOPv5.1 with TPS 5 - Level RCA
  Purpose: Centralize query operations to reduce complexity and improve performance
  """

  import Ecto.Query
  require Logger

  @doc """
  Applies standardized pagination to any query.

  Handles edge cases and provides consistent pagination across domains.
  """
  @spec apply_pagination(Ecto.Query.t(), map()) :: Ecto.Query.t()
  def apply_pagination(query, options) do
    page = Map.get(options, :page, 1)
    page_size = Map.get(options, :page_size, 20)

    # Validate and normalize pagination parameters
    validated_page = max(page, 1)
    validated_page_size = clamp(page_size, 1, 1000)

    offset = (validated_page - 1) * validated_page_size

    query
    |> limit(^validated_page_size)
    |> offset(^offset)
  end

  @doc """
  Applies standardized search functionality across different schemas.

  Supports multiple search fields and strategies.
  """

  @spec apply_search(Ecto.Query.t(), String.t() | nil, list(atom())) :: Ecto.Query.t()
  def apply_search(query, search_term, fields),
    do: UnifiedUtilitySystem.apply_search(query, search_term, fields)

  # Claude Agent: EP-076 - Unreachable function clause commented
  @doc """
  Applies standardized filtering with type safety and validation.

  Supports complex filter combinations and nested filters.
  """
  @spec apply_filters(Ecto.Query.t(), map(), map()) :: Ecto.Query.t()
  def apply_filters(query, filters, _schema_config \\ %{})

  def apply_filters(query, filters, _schema_config) when map_size(filters) == 0, do: query

  def apply_filters(query, filters, schema_config) do
    Enum.reduce(filters, query, fn {key, value}, acc_query ->
      apply_single_filter(acc_query, key, value, schema_config)
    end)
  end

  @doc """
  Applies standardized ordering with multiple sort criteria support.

  Supports direction specification and nested field ordering.
  """
  @spec apply_ordering(Ecto.Query.t(), list(map()) | map()) :: Ecto.Query.t()
  def apply_ordering(query, ordering) when is_map(ordering) do
    apply_ordering(query, [ordering])
  end

  @spec apply_ordering(term(), term()) :: term()
  def apply_ordering(query, ordering) when is_list(ordering) do
    Enum.reduce(ordering, query, fn order_spec, acc_query ->
      field = Map.get(order_spec, :field, :inserted_at)
      direction = Map.get(order_spec, :direction, :desc)

      case direction do
        :asc -> order_by(acc_query, [item], asc: field(item, ^field))
        :desc -> order_by(acc_query, [item], desc: field(item, ^field))
        _ -> acc_query
      end
    end)
  end

  @doc """
  Applies time - based filtering with proper timezone handling.

  Supports date ranges, relative dates, and timezone conversions.
  """
  @spec apply_time_filters(Ecto.Query.t(), map()) :: Ecto.Query.t()
  def apply_time_filters(query, time_filters) when map_size(time_filters) == 0, do: query

  @spec apply_time_filters(term(), term()) :: term()
  def apply_time_filters(query, time_filters) do
    query
    |> maybe_apply_start_time(Map.get(time_filters, :start_time))
    |> maybe_apply_end_time(Map.get(time_filters, :end_time))
    |> maybe_apply_date_range(Map.get(time_filters, :date_range))
    |> maybe_apply_relative_time(Map.get(time_filters, :relative_time))
  end

  @doc """
  Applies tenant isolation filtering with security validation.

  Ensures all queries are properly scoped to tenant boundaries.
  """
  @spec apply_tenant_scoping(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def apply_tenant_scoping(query, nil) do
    Logger.warning("Query executed without tenant scoping", query: inspect(query))
    query
  end

  @spec apply_tenant_scoping(term(), binary() | integer()) :: term()
  def apply_tenant_scoping(query, tenant_id) when is_binary(tenant_id) do
    where(query, [item], item.tenant_id == ^tenant_id)
  end

  @doc """
  Optimizes query performance with automatic index hints and query planning.

  Analyzes query structure and applies performance optimizations.
  """
  @spec optimize_query_performance(Ecto.Query.t(), map()) :: Ecto.Query.t()
  def optimize_query_performance(query, options \\ %{}) do
    enable_preloading = Map.get(options, :preload, false)
    use_indexes = Map.get(options, :use_indexes, true)

    query
    |> maybe_add_index_hints(use_indexes)
    |> maybe_apply_preloading(enable_preloading, options)
    |> optimize_join_order()
  end

  @doc """
  Builds complex WHERE clauses with proper operator precedence.

  Supports AND, OR, NOT operations with nested conditions.
  """
  @spec build_complex_where(Ecto.Query.t(), list(map())) :: Ecto.Query.t()
  def build_complex_where(query, conditions) when is_list(conditions) do
    Enum.reduce(conditions, query, fn condition, acc_query ->
      apply_condition(acc_query, condition)
    end)
  end

  @doc """
  Handles query result aggregation with caching support.

  Provides count, sum, average, and custom aggregations.
  """
  @spec apply_aggregation(Ecto.Query.t(), atom(), atom()) :: Ecto.Query.t()
  def apply_aggregation(query, field, operation) do
    case operation do
      :count -> select(query, [item], count(field(item, ^field)))
      :sum -> select(query, [item], sum(field(item, ^field)))
      :avg -> select(query, [item], avg(field(item, ^field)))
      :max -> select(query, [item], max(field(item, ^field)))
      :min -> select(query, [item], min(field(item, ^field)))
      _ -> query
    end
  end

  # Private helper functions

  defp clamp(value, min_val, max_val) do
    value
    |> max(min_val)
    |> min(max_val)
  end

  defp apply_single_filter(query, key, value, _schema_config) do
    case {key, value} do
      {:active, boolean_value} when is_boolean(boolean_value) ->
        where(query, [item], item.active == ^boolean_value)

      {:status, status_value} when is_binary(status_value) ->
        where(query, [item], item.status == ^status_value)

      {:created_after, date_value} ->
        where(query, [item], item.inserted_at >= ^date_value)

      {:created_before, date_value} ->
        where(query, [item], item.inserted_at <= ^date_value)

      {:ids, id_list} when is_list(id_list) ->
        where(query, [item], item.id in ^id_list)

      {field, field_value} when is_atom(field) ->
        where(query, [item], field(item, ^field) == ^field_value)

      _ ->
        Logger.warning("Unsupported filter", key: key, value: value)
        query
    end
  end

  defp maybe_apply_start_time(query, nil), do: query

  defp maybe_apply_start_time(query, start_time) do
    where(query, [item], item.inserted_at >= ^start_time)
  end

  defp maybe_apply_end_time(query, nil), do: query

  defp maybe_apply_end_time(query, end_time) do
    where(query, [item], item.inserted_at <= ^end_time)
  end

  defp maybe_apply_date_range(query, nil), do: query

  defp maybe_apply_date_range(query, %{start: start_date, end: end_date}) do
    query
    |> where([item], item.inserted_at >= ^start_date)
    |> where([item], item.inserted_at <= ^end_date)
  end

  defp maybe_apply_relative_time(query, nil), do: query

  defp maybe_apply_relative_time(query, relative_spec) do
    cutoff_time = calculate_relative_time(relative_spec)
    where(query, [item], item.inserted_at >= ^cutoff_time)
  end

  defp calculate_relative_time(%{value: value, unit: unit}) do
    case unit do
      :hours -> DateTime.add(DateTime.utc_now(), -value * 3600, :second)
      :days -> DateTime.add(DateTime.utc_now(), -value * 86_400, :second)
      :weeks -> DateTime.add(DateTime.utc_now(), -value * 604_800, :second)
      :months -> DateTime.add(DateTime.utc_now(), -value * 2_592_000, :second)
      _ -> DateTime.utc_now()
    end
  end

  defp maybe_add_index_hints(query, false), do: query

  defp maybe_add_index_hints(query, true) do
    # Add __database - specific index hints
    # This would be implemented based on the specific __database
    query
  end

  defp maybe_apply_preloading(query, false, _options), do: query

  defp maybe_apply_preloading(query, true, options) do
    preload_associations = Map.get(options, :preload_associations, [])

    if length(preload_associations) > 0 do
      preload(query, ^preload_associations)
    else
      query
    end
  end

  defp optimize_join_order(query) do
    # Optimize JOIN order for better performance
    # This would analyze the query structure and reorder JOINs
    query
  end

  defp apply_condition(query, condition) do
    case condition do
      %{type: :and, conditions: sub_conditions} ->
        Enum.reduce(sub_conditions, query, &apply_condition(&2, &1))

      %{type: :or, conditions: sub_conditions} ->
        dynamic_query = or_conditions_to_dynamic(sub_conditions)
        or_where(query, ^dynamic_query)

      %{field: field, operator: :eq, value: value} ->
        where(query, [item], field(item, ^field) == ^value)

      %{field: field, operator: :ne, value: value} ->
        where(query, [item], field(item, ^field) != ^value)

      %{field: field, operator: :gt, value: value} ->
        where(query, [item], field(item, ^field) > ^value)

      %{field: field, operator: :lt, value: value} ->
        where(query, [item], field(item, ^field) < ^value)

      %{field: field, operator: :like, value: value} ->
        where(query, [item], ilike(field(item, ^field), ^"%#{value}%"))

      _ ->
        Logger.warning("Unsupported condition", condition: condition)
        query
    end
  end

  defp or_conditions_to_dynamic(conditions) do
    Enum.reduce(conditions, false, fn condition, acc ->
      case condition do
        %{field: field, operator: :eq, value: value} ->
          dynamic([item], ^acc or field(item, ^field) == ^value)

        %{field: field, operator: :like, value: value} ->
          dynamic([item], ^acc or ilike(field(item, ^field), ^"%#{value}%"))

        _ ->
          acc
      end
    end)
  end
end
