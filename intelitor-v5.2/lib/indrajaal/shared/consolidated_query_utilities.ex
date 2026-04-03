defmodule Indrajaal.Shared.ConsolidatedQueryUtilities do
  @moduledoc """
  Consolidated Query Utilities - Eliminates duplicate timescale / query patterns

  Combines functionality from:
  - TimescaleQueryUtilities
  - Aggregation- Various duplicate query building patterns
  """

  @doc """
  Build performance trend query - consolidated from multiple duplicates.
  """
  @spec build_performance_trend_query(term()) :: term()
  def build_performance_trend_query(params) do
    base_query = """
    SELECT
      time_bucket('1 hour', created_at) as bucket,
      avg(response_time) as avg_response_time,
      count(*) as _request_count
    FROM __events
    WHERE tenant_id = $1
    """

    apply_time_filters(base_query, params)
  end

  @doc """
  Build __event count query - consolidated from duplicate patterns.
  """
  @spec build_event_count_query(term()) :: term()
  def build_event_count_query(params) do
    base_query = """
    SELECT
      __event_type,
      count(*) as __event_count,
      date_trunc('day', created_at) as __event_date
    FROM __events
    WHERE tenant_id = $1
    """

    apply_filters(base_query, params)
  end

  # Consolidated helper methods
  defp apply_time_filters(query, %{starttime: _start_time, end_time: _end_time}) do
    query <> " AND created_at BETWEEN $2 AND $3"
  end

  defp apply_time_filters(query, __params), do: query

  defp apply_filters(query, params) do
    query
    |> apply_time_filters(params)
    |> apply_event_type_filter(params)
  end

  defp apply_event_type_filter(query, %{__event_types: types}) when length(types) > 0 do
    type_list = Enum.map_join(types, ",", fn t -> "'#{t}'" end)
    query <> " AND __event_type IN (" <> type_list <> ")"
  end

  defp apply_event_type_filter(query, __params), do: query
end
