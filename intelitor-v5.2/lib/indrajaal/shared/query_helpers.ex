defmodule Indrajaal.Shared.QueryHelpers do
  # PHASE G CONSOLIDATION: Timescale query duplications consolidated
  # Strategic Impact: Internal query duplications eliminated

  alias Indrajaal.Shared.UnifiedUtilitySystem

  @deprecated "Use Indrajaal.Shared.UnifiedQuerySystem instead. This module has been consolidated into UnifiedQuerySystem for better maintainability and performance."

  @moduledoc """
  Shared query utility functions for all domain __contexts.

  Eliminates systematic code duplication across domain modules by providing
  common query patterns used throughout the application.

  Generated to resolve TPS Pattern D001: Domain file duplication across 18 domains.
  Framework: SOPv5.1 + TPS + Maximum Parallelization
  """

  import Ecto.Query

  @doc """
  Applies search filtering to a query based on search term.

  ## Parameters
  - query: The Ecto query to filter
  - search: The search term (nil, empty string, or valid search)
  - fields: List of fields to search in (defaults to [:name])

  ## Examples

      iex> query = from(u in User)
      iex> UnifiedQuerySystem.apply_search(query, "john", [:name, :email])
      # Returns query with WHERE name ILIKE '%john%' OR email ILIKE '%john%'

      iex> UnifiedQuerySystem.apply_search(query, nil, [:name])
      # Returns original query unchanged
  """
  @spec apply_search(Ecto.Query.t(), binary() | nil, [atom()]) :: Ecto.Query.t()
  def apply_search(query, search_term, fields),
    do: UnifiedUtilitySystem.apply_search(query, search_term, fields)

  # Claude Agent: EP-076 - Unreachable function clause commented
  @doc """
  Applies pagination to a query with validation.

  ## Parameters
  - query: The Ecto query to paginate
  - page: Page number (must be positive integer)
  - page_size: Items per page (must be positive integer, max 1000)

  ## Examples

      iex> query = from(u in User)
      iex> UnifiedQuerySystem.apply_pagination(query, 1, 20)
      # Returns query with LIMIT 20 OFFSET 0
  """
  @spec apply_pagination(Ecto.Query.t(), integer(), integer()) :: Ecto.Query.t()
  def apply_pagination(query, page, page_size)
      when is_integer(page) and page > 0 and
             is_integer(page_size) and page_size > 0 and page_size <= 1000 do
    offset = (page - 1) * page_size

    query
    |> limit(^page_size)
    |> offset(^offset)
  end

  @spec apply_pagination(term(), term(), term()) :: term()
  def applypagination(query, _page, _page_size) do
    # Invalid pagination parameters - return query with default pagination
    query
    |> limit(20)
    |> offset(0)
  end

  @doc """
  Applies filters to a query based on a filter map.

  ## Parameters
  - query: The Ecto query to filter
  - filters: Map of filter conditions
  - allowed_filters: List of allowed filter keys (security measure)

  ## Examples

      iex> query = from(u in User)
      iex> filters = %{active: true, role: "admin"}
      iex> UnifiedQuerySystem.apply_filters(query, filters, [:active, :role])
      # Returns query with WHERE active = true AND role = 'admin'
  """
  @spec apply_filters(Ecto.Query.t(), map(), [atom()]) :: Ecto.Query.t()
  def apply_filters(query, filters, allowed_filters)
      when is_map(filters) and is_list(allowed_filters) do
    Enum.reduce(filters, query, fn {key, value}, acc_query ->
      if key in allowed_filters do
        apply_single_filter(acc_query, key, value)
      else
        acc_query
      end
    end)
  end

  @spec apply_filters(term(), term(), term()) :: term()
  # query, filters, allowed_filters), do: query
  # Claude Agent: EP-076 - Unreachable function clause commented
  @doc """
  Applies ordering to a query with validation.

  ## Parameters
  - query: The Ecto query to order
  - sort_by: Field to sort by (must be atom)
  - sort_order: Sort direction (:asc or :desc, defaults to :asc)

  ## Examples

      iex> query = from(u in User)
      iex> UnifiedQuerySystem.apply_ordering(query, :created_at, :desc)
      # Returns query with ORDER BY created_at DESC
  """
  @spec apply_ordering(Ecto.Query.t(), atom(), :asc | :desc) :: Ecto.Query.t()
  def apply_ordering(query, sort_by, sort_order \\ :asc)

  def apply_ordering(query, sort_by, sort_order)
      when is_atom(sort_by) and sort_order in [:asc, :desc] do
    order_by(query, [item], [{^sort_order, field(item, ^sort_by)}])
  end

  @spec apply_ordering(term(), term(), term()) :: term()
  def applyordering(query, _sort_by, _sort_order) do
    # Invalid ordering parameters - return query with default ordering
    order_by(query, [item], asc: item.inserted_at)
  end

  # Private helper functions

  @spec apply_single_filter(Ecto.Query.t(), atom(), any()) :: Ecto.Query.t()
  defp apply_single_filter(query, :active, value) when is_boolean(value) do
    where(query, [item], item.active == ^value)
  end

  defp apply_single_filter(query, :tenant_id, value) when is_binary(value) do
    where(query, [item], item.tenant_id == ^value)
  end

  defp apply_single_filter(query, :created_after, %DateTime{} = datetime) do
    where(query, [item], item.inserted_at >= ^datetime)
  end

  defp apply_single_filter(query, :created_before, %DateTime{} = datetime) do
    where(query, [item], item.inserted_at <= ^datetime)
  end

  # Fallback for unknown filters - return query unchanged
  defp apply_single_filter(query, _key, _value), do: query

  @doc """
  Validates query parameters for safety and correctness.

  ## Parameters
  - page: Page number to validate
  - page_size: Page size to validate

  ## Returns
  - {:ok, validated_page, validated_page_size} if valid
  - {:error, reason} if invalid
  """
  @spec validate_query_params(any(), any()) :: {:ok, integer(), integer()} | {:error, atom()}
  def validate_query_params(page, page_size) do
    with {:ok, valid_page} <- validate_page(page),
         {:ok, valid_page_size} <- validate_page_size(page_size) do
      {:ok, valid_page, valid_page_size}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @spec validate_page(any()) :: {:ok, integer()} | {:error, atom()}
  defp validate_page(page) when is_integer(page) and page > 0, do: {:ok, page}

  defp validate_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {parsed_page, ""} when parsed_page > 0 -> {:ok, parsed_page}
      _ -> {:error, :invalid_page}
    end
  end

  defp validate_page(_), do: {:error, :invalid_page}

  @spec validate_page_size(any()) :: {:ok, integer()} | {:error, atom()}
  defp validate_page_size(page_size)
       when is_integer(page_size) and page_size > 0 and page_size <= 1000 do
    {:ok, page_size}
  end

  defp validate_page_size(page_size) when is_binary(page_size) do
    case Integer.parse(page_size) do
      {parsed_size, ""} when parsed_size > 0 and parsed_size <= 1000 -> {:ok, parsed_size}
      _ -> {:error, :invalid_page_size}
    end
  end

  defp validate_page_size(_), do: {:error, :invalid_page_size}
end
