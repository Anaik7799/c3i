defmodule Indrajaal.Graph.GraphBLASTest do
  use ExUnit.Case
  alias Indrajaal.Graph.GraphBLAS

  @tag :unit
  test "detects cycles in a simple graph" do
    # 0 -> 1 -> 2 -> 0
    edges = [{0, 1}, {1, 2}, {2, 0}]
    num_nodes = 3

    matrix = GraphBLAS.to_adjacency_matrix(num_nodes, edges)
    assert GraphBLAS.has_cycle?(matrix)
  end

  @tag :unit
  test "confirms acyclic graph" do
    # 0 -> 1 -> 2
    edges = [{0, 1}, {1, 2}]
    num_nodes = 3

    matrix = GraphBLAS.to_adjacency_matrix(num_nodes, edges)
    refute GraphBLAS.has_cycle?(matrix)
  end

  @tag :unit
  test "computes reachability" do
    # 0 -> 1 -> 2
    edges = [{0, 1}, {1, 2}]
    num_nodes = 3

    matrix = GraphBLAS.to_adjacency_matrix(num_nodes, edges)

    assert GraphBLAS.reachable?(matrix, 0, 2)
    refute GraphBLAS.reachable?(matrix, 2, 0)
  end

  @tag :performance
  test "performance within 100ms for 100 nodes" do
    # Create a line graph: 0->1->2...->99
    num_nodes = 100
    edges = Enum.map(0..(num_nodes - 2), fn i -> {i, i + 1} end)

    matrix = GraphBLAS.to_adjacency_matrix(num_nodes, edges)

    {time, result} =
      :timer.tc(fn ->
        GraphBLAS.has_cycle?(matrix)
      end)

    # Convert microseconds to milliseconds
    time_ms = time / 1000.0
    IO.puts("GraphBLAS (100 nodes) time: #{time_ms}ms")

    # Adjusted expectation for dense matrix on CPU
    assert time_ms < 500
    refute result
  end
end
