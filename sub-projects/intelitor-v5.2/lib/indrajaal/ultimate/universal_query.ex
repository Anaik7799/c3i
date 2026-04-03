defmodule Indrajaal.Ultimate.UniversalQuery do
  @moduledoc """
  Universal Query Framework - Phase S final consolidation

  Eliminates ALL query - related duplications across domains.
  """

  import Ecto.Query

  @doc """
  Universal query builder
  """
  @spec build_query(term(), term()) :: term()
  def build_query(base_query, criteria) do
    Enum.reduce(criteria, base_query, fn
      {:filter, filters}, query -> apply_filters(query, filters)
      {:sort, sort_opts}, query -> apply_sorting(query, sort_opts)
      {:preload, preloads}, query -> preload(query, ^preloads)
      {:limit, limit}, query -> limit(query, ^limit)
      {:offset, offset}, query -> offset(query, ^offset)
      {:group_by, fields}, query -> group_by(query, ^fields)
      {:having, conditions}, query -> having(query, ^conditions)
      _, query -> query
    end)
  end

  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn {field, value}, q ->
      where(q, [r], field(r, ^field) == ^value)
    end)
  end

  defp apply_sorting(query, sort_opts) do
    Enum.reduce(sort_opts, query, fn {field, direction}, q ->
      order_by(q, [r], [{^direction, field(r, ^field)}])
    end)
  end
end
