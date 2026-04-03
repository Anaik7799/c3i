defmodule Indrajaal.Graph.GraphBLAS do
  @moduledoc """
  High-Performance Graph Verification Engine using Matrix Algebra.

  ## WHAT
  Implements graph algorithms (Reachability, Cycle Detection) using
  Sparse Matrix operations (GraphBLAS style) via Nx.

  ## WHY
  - SC-GVF-005: Verification must complete in < 100ms for 1000 nodes.
  - Matrix operations are highly parallelizable (SIMD).

  ## STAMP Constraints
  - SC-GVF-003: Supervision graph must be acyclic.
  - SC-GVF-004: Container network must satisfy isolation.
  """

  # We use Nx for tensor operations. 
  # In a real GraphBLAS setup, we'd use a sparse backend, but Nx.Tensor is dense by default.
  # For 1000 nodes, dense is fine (1M elements).

  @doc """
  Converts an edge list to an adjacency matrix.
  """
  def to_adjacency_matrix(num_nodes, edges) do
    # edges is a list of {source, target}
    indices = Enum.map(edges, fn {s, t} -> [s, t] end)

    # Create a tensor of 1s at the indices
    updates = Nx.broadcast(1, {length(edges)})

    # Scatter into a zero matrix
    Nx.indexed_add(Nx.broadcast(0, {num_nodes, num_nodes}), Nx.tensor(indices), updates)
  end

  @doc """
  Computes the Transitive Closure using matrix squaring (Floyd-Warshall / Kleene).
  R = A | A^2 | ... | A^n
  """
  def transitive_closure(adjacency_matrix) do
    start_time = System.monotonic_time()

    n = Nx.axis_size(adjacency_matrix, 0)
    steps = :math.ceil(:math.log2(n)) |> round()

    result = do_transitive_closure(adjacency_matrix, steps)

    duration = System.monotonic_time() - start_time
    :telemetry.execute([:indrajaal, :graph, :closure], %{duration: duration}, %{nodes: n})

    result
  end

  defp do_transitive_closure(matrix, 0), do: matrix

  defp do_transitive_closure(matrix, step) do
    # R_next = R + R.R
    # We use min(1, ...) to keep it boolean-ish (0 or 1)
    squared = Nx.dot(matrix, matrix)
    next = Nx.add(matrix, squared)
    # Clip to 1
    next = Nx.min(next, 1)

    do_transitive_closure(next, step - 1)
  end

  @doc """
  Detects if the graph has any cycles.
  Cycle exists if Transitive Closure has 1s on the diagonal (self-loops introduced by path).
  Wait, strict transitive closure A+A^2... checks paths of length >= 1.
  If A[i,i] becomes 1, there is a path from i to i.
  """
  def has_cycle?(adjacency_matrix) do
    closure = transitive_closure(adjacency_matrix)
    diagonal = Nx.take_diagonal(closure)
    Nx.sum(diagonal) |> Nx.to_number() > 0
  end

  @doc """
  Checks reachability from source to target.
  """
  def reachable?(adjacency_matrix, source, target) do
    closure = transitive_closure(adjacency_matrix)
    Nx.to_number(closure[source][target]) > 0
  end
end
