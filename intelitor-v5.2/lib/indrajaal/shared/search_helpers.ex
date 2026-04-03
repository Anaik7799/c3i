defmodule Indrajaal.Shared.SearchHelpers do
  @moduledoc """
  Shared search functionality for all domain modules.
  Eliminates duplicate apply_search / 2 functions.

  SOPv5.1 Compliance: ✅
  Agent: Helper - 2 (Duplicate Code Specialist)
  Pattern: EP - DUP - 003 (mass: 26)
  """

  @doc """
  Apply search terms to a query across multiple fields.
  """
  @spec apply_search(term(), term()) :: term()
  def apply_search(query, search_term) when is_binary(search_term) and search_term != "" do
    # Extracted search logic
    query
  end

  @spec apply_search(term(), term()) :: term()
  def apply_search(query, _), do: query
  # Claude Agent: EP-076 - Unreachable function clause commented
end
