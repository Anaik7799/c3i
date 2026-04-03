# Enhancement to UnifiedErrorSystem for complete consolidation
defmodule Indrajaal.Shared.EnhancedErrorPatterns do
  @moduledoc """
  Enhanced error handling patterns to eliminate remaining duplicates.

  SOPv5.1 Compliance: ✅
  Agent: Helper - 2 (Duplicate Code Specialist)
  Pattern: EP - DUP - 004 (mass: 27 - 34)
  """

  @doc """
  Consolidated error formatting for all controllers and channels.
  """
  @spec format_changeset_errors(Ecto.Changeset.t()) :: term()
  def format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {k, v}, acc ->
        String.replace(acc, "%{#{k}}", to_string(v))
      end)
    end)
  end

  @doc """
  Standardized error response structure.
  """
  @spec error_response(term(), map()) :: term()
  def error_response(reason, details \\ %{}) do
    %{
      success: false,
      error: reason,
      details: details,
      timestamp: DateTime.utc_now()
    }
  end
end
