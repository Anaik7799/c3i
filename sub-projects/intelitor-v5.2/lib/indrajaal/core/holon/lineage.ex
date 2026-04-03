defmodule Indrajaal.Core.Holon.Lineage do
  @moduledoc """
  Ancestral Lineage API - SC-SING-005.

  WHAT: Provides functions to trace the "Genetic Ancestry" of holons and code mutations.
  WHY: Enables self-reflection on evolutionary paths and impact analysis.
  """

  require Logger
  alias Indrajaal.Core.Holon.ImmutableRegister

  @doc """
  Gets the full lineage history for a specific substrate path.
  """
  def get_file_ancestry(path) do
    case ImmutableRegister.get_full_state() do
      {:ok, blocks} ->
        history =
          blocks
          |> Enum.filter(fn b -> get_in(b.content, [:data, :path]) == path end)
          |> Enum.map(fn b ->
            %{
              index: b.index,
              hash: b.hash,
              old_hash: b.content.data[:old_hash],
              new_hash: b.content.data[:new_hash],
              timestamp: b.timestamp
            }
          end)

        {:ok, history}

      error ->
        error
    end
  end

  @doc """
  Traces the parent of a specific mutation block.
  """
  def get_parent_mutation(block_hash) do
    case ImmutableRegister.get_full_state() do
      {:ok, blocks} ->
        block = Enum.find(blocks, fn b -> b.hash == block_hash end)

        case block do
          nil -> {:error, :not_found}
          %{prev_hash: "genesis"} -> {:ok, :genesis}
          %{prev_hash: prev} -> {:ok, prev}
        end

      error ->
        error
    end
  end
end
