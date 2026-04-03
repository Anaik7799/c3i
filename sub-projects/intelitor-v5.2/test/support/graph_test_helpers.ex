defmodule Indrajaal.GraphTestHelpers do
  @moduledoc """
  WHAT: Shared graph algorithms for test utilities.
  WHY: Eliminates duplicate cycle detection code across test files.
  CONSTRAINTS: Test-only module, not for production use.

  Provides DFS-based cycle detection for dependency graphs and wait graphs
  used in architecture tests and deadlock detection tests.
  """

  @doc """
  Detects cycles in a directed graph using DFS traversal.

  ## Parameters
    - graph: A map where keys are nodes and values are lists of neighbor nodes

  ## Returns
    - true if a cycle is detected
    - false if no cycle exists

  ## Examples

      iex> GraphTestHelpers.has_cycle?(%{a: [:b], b: [:c], c: []})
      false

      iex> GraphTestHelpers.has_cycle?(%{a: [:b], b: [:c], c: [:a]})
      true
  """
  @spec has_cycle?(map()) :: boolean()
  def has_cycle?(graph) when is_map(graph) do
    visited = MapSet.new()
    rec_stack = MapSet.new()

    Enum.any?(Map.keys(graph), fn node ->
      detect_cycle_dfs(node, graph, visited, rec_stack)
    end)
  end

  @doc """
  DFS helper for cycle detection.

  Uses a recursion stack to track the current DFS path.
  A cycle is detected when we encounter a node already in the recursion stack.
  """
  @spec detect_cycle_dfs(any(), map(), MapSet.t(), MapSet.t()) :: boolean()
  def detect_cycle_dfs(node, graph, visited, rec_stack) do
    if MapSet.member?(rec_stack, node) do
      true
    else
      if MapSet.member?(visited, node) do
        false
      else
        visited = MapSet.put(visited, node)
        rec_stack = MapSet.put(rec_stack, node)

        neighbors = Map.get(graph, node, [])

        Enum.any?(neighbors, fn neighbor ->
          detect_cycle_dfs(neighbor, graph, visited, rec_stack)
        end)
      end
    end
  end
end
