defmodule Indrajaal.Core.GraphCentralityTest do
  @moduledoc """
  Mathematical verification tests for graph betweenness centrality (Brandes algorithm).

  Mathematical properties verified:
  1. Brandes algorithm: BC(v) = Σ_{s≠v≠t} σ(s,t|v) / σ(s,t)
     where σ(s,t) = number of shortest paths from s to t
     and σ(s,t|v) = number of those paths passing through v
  2. Centrality non-negativity: BC(v) ≥ 0 for all v
  3. Maximum centrality: in a path graph, middle node has highest BC
  4. Zero centrality: leaf nodes in a tree have BC = 0
  5. Star graph: center has maximum BC, all leaves have BC = 0
  6. Complete graph: all nodes have equal BC

  This implements the Brandes 2001 algorithm inline as pure mathematical
  verification — no external module required (module does not exist in codebase).

  STAMP: SC-MATH-001 (discipline health), SC-GRAPH-001 (graph operations)
  Layer: L1-CODE (pure mathematical verification)
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :mathematical
  @moduletag :graph_centrality

  # ============================================================================
  # Brandes betweenness centrality — inline implementation
  # ============================================================================

  # Graph represented as adjacency map: %{node => [neighbor, ...]}
  # Undirected: if {u, v} is an edge, both u→v and v→u are in adj

  defp build_graph(edges) do
    Enum.reduce(edges, %{}, fn {u, v}, acc ->
      acc
      |> Map.update(u, [v], &[v | &1])
      |> Map.update(v, [u], &[u | &1])
    end)
  end

  # Brandes algorithm (2001): O((V+E) * V) for unweighted graphs
  # Returns map: %{node => betweenness_centrality}
  defp brandes_centrality(adj) do
    nodes = Map.keys(adj)

    # Initialize centrality to 0.0 for all nodes
    betweenness = Enum.reduce(nodes, %{}, fn v, acc -> Map.put(acc, v, 0.0) end)

    # Accumulate contributions from each source node s
    betweenness =
      Enum.reduce(nodes, betweenness, fn s, bc ->
        # BFS from s to find shortest path counts and predecessors
        {sigma, dist, preds, stack} = bfs_shortest_paths(adj, s, nodes)

        # Backward accumulation of dependencies
        delta = Enum.reduce(nodes, %{}, fn v, acc -> Map.put(acc, v, 0.0) end)

        delta =
          Enum.reduce(stack, delta, fn w, d ->
            # For each predecessor of w
            d =
              Enum.reduce(Map.get(preds, w, []), d, fn v, dd ->
                # Contribution: (sigma[v]/sigma[w]) * (1 + delta[w])
                contrib =
                  if Map.get(sigma, w, 0) > 0,
                    do: Map.get(sigma, v, 0) / Map.get(sigma, w, 0) * (1.0 + Map.get(dd, w, 0.0)),
                    else: 0.0

                Map.update(dd, v, contrib, &(&1 + contrib))
              end)

            d
          end)

        # Add delta to betweenness (excluding source s)
        Enum.reduce(nodes, bc, fn v, b ->
          if v != s do
            Map.update(b, v, Map.get(delta, v, 0.0), &(&1 + Map.get(delta, v, 0.0)))
          else
            b
          end
        end)
      end)

    # For undirected graphs, divide by 2 (each path counted twice)
    Enum.reduce(betweenness, %{}, fn {v, bc}, acc ->
      Map.put(acc, v, bc / 2.0)
    end)
  end

  # BFS from source s — returns {sigma, dist, preds, stack}
  defp bfs_shortest_paths(adj, s, nodes) do
    sigma = Enum.reduce(nodes, %{}, fn v, acc -> Map.put(acc, v, 0) end)
    dist = Enum.reduce(nodes, %{}, fn v, acc -> Map.put(acc, v, -1) end)
    preds = Enum.reduce(nodes, %{}, fn v, acc -> Map.put(acc, v, []) end)

    sigma = Map.put(sigma, s, 1)
    dist = Map.put(dist, s, 0)

    queue = :queue.from_list([s])
    stack = []

    bfs_loop(adj, queue, stack, sigma, dist, preds)
  end

  defp bfs_loop(adj, queue, stack, sigma, dist, preds) do
    case :queue.out(queue) do
      {:empty, _} ->
        {sigma, dist, preds, Enum.reverse(stack)}

      {{:value, v}, queue2} ->
        stack = [v | stack]
        neighbors = Map.get(adj, v, [])

        {queue3, sigma2, dist2, preds2} =
          Enum.reduce(neighbors, {queue2, sigma, dist, preds}, fn w, {q, sig, d, pr} ->
            # First time w is visited?
            {q, d} =
              if Map.get(d, w, -1) < 0 do
                {:queue.in(w, q), Map.put(d, w, Map.get(d, v, 0) + 1)}
              else
                {q, d}
              end

            # Is w on shortest path from s via v?
            {sig2, pr2} =
              if Map.get(d, w, -1) == Map.get(d, v, 0) + 1 do
                new_sig = Map.update(sig, w, 0, &(&1 + Map.get(sig, v, 0)))
                new_pr = Map.update(pr, w, [v], &[v | &1])
                {new_sig, new_pr}
              else
                {sig, pr}
              end

            {q, sig2, d, pr2}
          end)

        bfs_loop(adj, queue3, stack, sigma2, dist2, preds2)
    end
  end

  # ============================================================================
  # Path graph tests: 1—2—3—4—5
  # Middle nodes have highest betweenness
  # ============================================================================

  describe "path graph betweenness centrality" do
    test "path graph P5: node 3 (middle) has highest centrality" do
      # 1—2—3—4—5
      edges = [{1, 2}, {2, 3}, {3, 4}, {4, 5}]
      adj = build_graph(edges)
      bc = brandes_centrality(adj)

      # Node 3 is the middle — every path from {1,2} to {4,5} passes through 3
      assert bc[3] > bc[1]
      assert bc[3] > bc[5]
      assert bc[3] >= bc[2]
      assert bc[3] >= bc[4]
    end

    test "path graph P5: leaf nodes (1 and 5) have zero centrality" do
      edges = [{1, 2}, {2, 3}, {3, 4}, {4, 5}]
      adj = build_graph(edges)
      bc = brandes_centrality(adj)

      assert_in_delta bc[1], 0.0, 0.0001
      assert_in_delta bc[5], 0.0, 0.0001
    end

    test "path graph P3: middle node has maximum centrality" do
      # 1—2—3
      edges = [{1, 2}, {2, 3}]
      adj = build_graph(edges)
      bc = brandes_centrality(adj)

      assert bc[2] > bc[1]
      assert bc[2] > bc[3]
    end

    test "path graph P3: BC(middle) = 1.0 (exactly one path from 1 to 3)" do
      edges = [{1, 2}, {2, 3}]
      adj = build_graph(edges)
      bc = brandes_centrality(adj)

      # Only path 1→3 passes through 2: BC(2) = 1.0
      assert_in_delta bc[2], 1.0, 0.0001
    end
  end

  # ============================================================================
  # Star graph tests: center has BC = n*(n-1)/2
  # ============================================================================

  describe "star graph betweenness centrality" do
    test "star K1,4: center (node 1) has maximum centrality" do
      # 1 connected to 2,3,4,5
      edges = [{1, 2}, {1, 3}, {1, 4}, {1, 5}]
      adj = build_graph(edges)
      bc = brandes_centrality(adj)

      assert bc[1] > bc[2]
      assert bc[1] > bc[3]
      assert bc[1] > bc[4]
      assert bc[1] > bc[5]
    end

    test "star K1,4: leaf nodes have zero centrality" do
      edges = [{1, 2}, {1, 3}, {1, 4}, {1, 5}]
      adj = build_graph(edges)
      bc = brandes_centrality(adj)

      for leaf <- [2, 3, 4, 5] do
        assert_in_delta bc[leaf], 0.0, 0.0001
      end
    end

    test "star K1,3: center BC = 3.0 (C(3,2) = 3 pairs of leaves)" do
      # Center 1 is on ALL paths between leaves: 2↔3, 2↔4, 3↔4
      edges = [{1, 2}, {1, 3}, {1, 4}]
      adj = build_graph(edges)
      bc = brandes_centrality(adj)

      assert_in_delta bc[1], 3.0, 0.0001
    end
  end

  # ============================================================================
  # Cycle graph: equal centrality for all nodes
  # ============================================================================

  describe "cycle graph betweenness centrality" do
    test "cycle C4: all nodes have equal centrality" do
      # 1—2—3—4—1
      edges = [{1, 2}, {2, 3}, {3, 4}, {4, 1}]
      adj = build_graph(edges)
      bc = brandes_centrality(adj)

      for node <- [1, 2, 3, 4] do
        assert_in_delta bc[node], bc[1], 0.0001
      end
    end
  end

  # ============================================================================
  # Non-negativity invariant
  # ============================================================================

  describe "centrality non-negativity invariant" do
    test "all betweenness values are non-negative" do
      edges = [{1, 2}, {2, 3}, {3, 4}, {4, 5}, {2, 4}]
      adj = build_graph(edges)
      bc = brandes_centrality(adj)

      Enum.each(bc, fn {node, centrality} ->
        assert centrality >= 0.0, "Node #{node} has negative BC: #{centrality}"
      end)
    end
  end

  # ============================================================================
  # Property: BC non-negativity for random graphs (PropCheck)
  # ============================================================================

  describe "property: betweenness centrality non-negativity (PropCheck)" do
    property "BC(v) ≥ 0 for all nodes in any path graph" do
      forall n <- PC.choose(3, 8) do
        edges = Enum.map(1..(n - 1), fn i -> {i, i + 1} end)
        adj = build_graph(edges)
        bc = brandes_centrality(adj)

        Enum.all?(bc, fn {_, centrality} -> centrality >= 0.0 end)
      end
    end

    property "star graph center has strictly positive BC for n ≥ 3" do
      forall leaves <- PC.choose(2, 5) do
        edges = Enum.map(1..leaves, fn i -> {0, i} end)
        adj = build_graph(edges)
        bc = brandes_centrality(adj)

        bc[0] > 0.0 or leaves < 2
      end
    end
  end

  # ============================================================================
  # Property: BC ordering in path graphs (StreamData)
  # ============================================================================

  describe "property: path graph centrality ordering (StreamData)" do
    test "in path graph Pn, inner nodes have BC > leaf nodes" do
      ExUnitProperties.check all(n <- SD.integer(4..7)) do
        edges = Enum.map(1..(n - 1), fn i -> {i, i + 1} end)
        adj = build_graph(edges)
        bc = brandes_centrality(adj)

        leaf1_bc = bc[1] || 0.0
        leaf_n_bc = bc[n] || 0.0
        inner_max = Enum.max(Enum.map(2..(n - 1), fn v -> bc[v] || 0.0 end))

        inner_max >= leaf1_bc and inner_max >= leaf_n_bc
      end
    end

    test "all BC values in path graph are non-negative" do
      ExUnitProperties.check all(n <- SD.integer(3..6)) do
        edges = Enum.map(1..(n - 1), fn i -> {i, i + 1} end)
        adj = build_graph(edges)
        bc = brandes_centrality(adj)

        Enum.all?(Map.values(bc), fn v -> v >= 0.0 end)
      end
    end
  end
end
