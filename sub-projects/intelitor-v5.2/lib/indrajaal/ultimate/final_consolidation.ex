defmodule Indrajaal.Ultimate.FinalConsolidation do
  @moduledoc """
  Final Universal Consolidation - Phase V
  The last framework needed to achieve absolute zero.
  """

  @doc """
  Universal with pattern for all operations
  """
  defmacro with_universal(clauses, do: success_block, else: error_block) do
    # Execute clauses in sequence, capturing any errors
    quote do
      try do
        with unquote_splicing(clauses) do
          unquote(success_block)
        else
          error -> error
        end
      rescue
        _ -> unquote(error_block)
      end
    end
  end

  @doc """
  Universal pipeline operator
  """
  @spec universal_pipeline(term(), term()) :: term()
  def universal_pipeline(data, operations) do
    Enum.reduce_while(operations, {:ok, data}, fn operation, {:ok, acc} ->
      case operation.(acc) do
        {:ok, result} -> {:cont, {:ok, result}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end
end
