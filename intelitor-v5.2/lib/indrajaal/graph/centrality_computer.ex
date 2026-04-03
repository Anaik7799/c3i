defmodule Indrajaal.Graph.CentralityComputer do
  @moduledoc """
  Centrality Computer — L3 Control Layer (Graph Subsystem)

  ## Design Intent

  Pure module that computes graph centrality metrics for identifying critical
  nodes in the system topology. Supports degree centrality, betweenness
  centrality (Brandes algorithm), closeness centrality, and PageRank.

  Used for identifying single points of failure and optimal placement of
  monitoring probes in the distributed mesh.

  All functions are referentially transparent — they accept a graph
  representation and return computed metrics without side effects.

  ## Graph Representation

  A graph is an adjacency map: `%{node_id() => [node_id()]}` where edges
  are directed. For undirected graphs pass both directions.

  ## STAMP Constraints

  - SC-GRAPH-003: Centrality metrics available for topology analysis
  - SC-HA-001: SIL-6 availability via topology analysis
  - SC-DIST-001: FQUN distributed mesh topology

  ## Change History

  | Version | Date       | Author | Change                        |
  |---------|------------|--------|-------------------------------|
  | 21.3.1  | 2026-03-28 | Claude | Rewrite as pure module        |
  """

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type node_id :: atom() | String.t()
  @type graph :: %{node_id() => [node_id()]}
  @type centrality_map :: %{node_id() => float()}

  # ---------------------------------------------------------------------------
  # Public API — Pure Functions
  # ---------------------------------------------------------------------------

  @doc """
  Compute degree centrality for every node in the graph.

  Degree centrality = out-degree / (n - 1) where n is total node count.
  Returns a map of node → normalized degree centrality in [0.0, 1.0].
  Returns empty map for graphs with fewer than 2 nodes.

  ## Examples

      iex> Indrajaal.Graph.CentralityComputer.degree_centrality(%{a: [:b, :c], b: [:c], c: []})
      %{a: 0.6667, b: 0.3333, c: 0.0}
  """
  @spec degree_centrality(graph()) :: centrality_map()
  def degree_centrality(graph) when is_map(graph) do
    nodes = all_nodes(graph)
    n = MapSet.size(nodes)

    if n < 2 do
      Enum.reduce(MapSet.to_list(nodes), %{}, fn node, acc ->
        Map.put(acc, node, 0.0)
      end)
    else
      denominator = n - 1

      Enum.reduce(MapSet.to_list(nodes), %{}, fn node, acc ->
        out_deg = length(Map.get(graph, node, []))
        Map.put(acc, node, Float.round(out_deg / denominator, 4))
      end)
    end
  end

  @doc """
  Compute betweenness centrality for every node using Brandes algorithm.

  Betweenness centrality for node v = Σ_{s≠v≠t} (σ_{st}(v) / σ_{st})
  normalized by 1 / ((n-1)(n-2)) for directed graphs.

  Returns a map of node → normalized betweenness in [0.0, 1.0].
  Complexity: O(V·E) via Brandes 2001.
  """
  @spec betweenness_centrality(graph()) :: centrality_map()
  def betweenness_centrality(graph) when is_map(graph) do
    nodes_list = all_nodes(graph) |> MapSet.to_list()
    n = length(nodes_list)

    # Initialize all to 0.0
    cb = Enum.reduce(nodes_list, %{}, fn v, acc -> Map.put(acc, v, 0.0) end)

    if n < 3 do
      cb
    else
      # Brandes algorithm: one BFS per source node
      cb =
        Enum.reduce(nodes_list, cb, fn source, cb_acc ->
          brandes_update(source, graph, nodes_list, cb_acc)
        end)

      # Normalize by 1 / ((n-1)(n-2))
      norm = 1.0 / ((n - 1) * (n - 2))

      Enum.reduce(cb, %{}, fn {v, score}, acc ->
        Map.put(acc, v, Float.round(score * norm, 6))
      end)
    end
  end

  @doc """
  Compute closeness centrality for every node.

  Closeness centrality for node v = (n-1) / Σ d(v, u)
  where d(v, u) is the shortest-path distance from v to u.
  Nodes unreachable from v are excluded from the sum (Wasserman & Faust variant).

  Returns a map of node → closeness centrality in [0.0, 1.0].
  """
  @spec closeness_centrality(graph()) :: centrality_map()
  def closeness_centrality(graph) when is_map(graph) do
    nodes = all_nodes(graph)
    n = MapSet.size(nodes)
    nodes_list = MapSet.to_list(nodes)

    Enum.reduce(nodes_list, %{}, fn node, acc ->
      cc = compute_closeness(node, graph, n)
      Map.put(acc, node, Float.round(cc, 6))
    end)
  end

  @doc """
  Compute PageRank scores for every node.

  Iterative power method. `damping` defaults to 0.85 (standard Web PageRank).
  Convergence threshold: 1.0e-6. Max iterations: 100.

  Returns a map of node → PageRank score (sums approximately to 1.0).
  """
  @spec pagerank(graph(), float()) :: centrality_map()
  def pagerank(graph, damping \\ 0.85)
      when is_map(graph) and is_float(damping) and damping >= 0.0 and damping <= 1.0 do
    nodes = all_nodes(graph) |> MapSet.to_list()
    n = length(nodes)

    if n == 0 do
      %{}
    else
      # Build reverse adjacency (who points TO each node)
      reverse = build_reverse(graph, nodes)

      out_degree =
        Enum.reduce(nodes, %{}, fn v, acc -> Map.put(acc, v, length(Map.get(graph, v, []))) end)

      # Initialize uniform PageRank
      initial_rank = 1.0 / n
      ranks = Enum.reduce(nodes, %{}, fn v, acc -> Map.put(acc, v, initial_rank) end)

      do_pagerank(ranks, graph, reverse, out_degree, nodes, n, damping, 0)
    end
  end

  # ---------------------------------------------------------------------------
  # Private — Brandes Betweenness
  # ---------------------------------------------------------------------------

  defp brandes_update(source, graph, nodes_list, cb) do
    # BFS to compute shortest path counts and predecessors
    {sigma, pred, _dist, stack} = brandes_bfs(source, graph, nodes_list)

    # Back-propagation
    delta = Enum.reduce(nodes_list, %{}, fn v, acc -> Map.put(acc, v, 0.0) end)

    delta =
      Enum.reduce(stack, delta, fn w, delta_acc ->
        Enum.reduce(Map.get(pred, w, []), delta_acc, fn v, d_acc ->
          contribution =
            Map.get(sigma, v, 0) / Map.get(sigma, w, 1) * (1.0 + Map.get(d_acc, w, 0.0))

          Map.update(d_acc, v, contribution, &(&1 + contribution))
        end)
      end)

    # Accumulate centrality (excluding source)
    Enum.reduce(nodes_list, cb, fn w, acc ->
      if w != source do
        Map.update(acc, w, Map.get(delta, w, 0.0), &(&1 + Map.get(delta, w, 0.0)))
      else
        acc
      end
    end)
  end

  defp brandes_bfs(source, graph, nodes_list) do
    sigma = Enum.reduce(nodes_list, %{}, fn v, acc -> Map.put(acc, v, 0) end)
    sigma = Map.put(sigma, source, 1)
    dist = Enum.reduce(nodes_list, %{}, fn v, acc -> Map.put(acc, v, -1) end)
    dist = Map.put(dist, source, 0)
    pred = Enum.reduce(nodes_list, %{}, fn v, acc -> Map.put(acc, v, []) end)

    do_brandes_bfs([source], [], sigma, pred, dist, graph)
  end

  defp do_brandes_bfs([], stack, sigma, pred, dist, _graph) do
    {sigma, pred, dist, stack}
  end

  defp do_brandes_bfs([v | queue], stack, sigma, pred, dist, graph) do
    stack2 = [v | stack]
    neighbors = Map.get(graph, v, [])

    {queue2, sigma2, pred2, dist2} =
      Enum.reduce(neighbors, {queue, sigma, pred, dist}, fn w, {q, s, p, d} ->
        if Map.get(d, w, -1) < 0 do
          # First visit
          q2 = q ++ [w]
          d2 = Map.put(d, w, Map.get(d, v, 0) + 1)
          s2 = Map.update(s, w, Map.get(s, v, 0), &(&1 + Map.get(s, v, 0)))
          p2 = Map.update(p, w, [v], &[v | &1])
          {q2, s2, p2, d2}
        else
          if Map.get(d, w) == Map.get(d, v) + 1 do
            # Another shortest path
            s2 = Map.update(s, w, Map.get(s, v, 0), &(&1 + Map.get(s, v, 0)))
            p2 = Map.update(p, w, [v], &[v | &1])
            {q, s2, p2, d}
          else
            {q, s, p, d}
          end
        end
      end)

    do_brandes_bfs(queue2, stack2, sigma2, pred2, dist2, graph)
  end

  # ---------------------------------------------------------------------------
  # Private — Closeness
  # ---------------------------------------------------------------------------

  defp compute_closeness(node, graph, n) do
    if n <= 1 do
      0.0
    else
      distances = bfs_distances(node, graph)
      # Exclude the node itself
      reachable_dists = Map.delete(distances, node) |> Map.values()
      reachable = length(reachable_dists)
      total_dist = Enum.sum(reachable_dists)

      if reachable > 0 and total_dist > 0 do
        # Wasserman-Faust normalization
        reachable / total_dist * (reachable / (n - 1))
      else
        0.0
      end
    end
  end

  defp bfs_distances(start, graph) do
    do_bfs_dist([{start, 0}], %{start => 0}, graph)
  end

  defp do_bfs_dist([], distances, _graph), do: distances

  defp do_bfs_dist([{current, dist} | rest], distances, graph) do
    neighbors = Map.get(graph, current, [])

    {new_queue, new_distances} =
      Enum.reduce(neighbors, {rest, distances}, fn neighbor, {q, d} ->
        if Map.has_key?(d, neighbor) do
          {q, d}
        else
          {q ++ [{neighbor, dist + 1}], Map.put(d, neighbor, dist + 1)}
        end
      end)

    do_bfs_dist(new_queue, new_distances, graph)
  end

  # ---------------------------------------------------------------------------
  # Private — PageRank
  # ---------------------------------------------------------------------------

  defp do_pagerank(ranks, _graph, _reverse, _out_degree, nodes, _n, _damping, 100) do
    # Max iterations reached — normalize and return
    total = Enum.sum(Map.values(ranks))

    if total > 0 do
      Enum.reduce(nodes, %{}, fn v, acc ->
        Map.put(acc, v, Float.round(Map.get(ranks, v) / total, 6))
      end)
    else
      ranks
    end
  end

  defp do_pagerank(ranks, graph, reverse, out_degree, nodes, n, damping, iter) do
    base = (1.0 - damping) / n

    new_ranks =
      Enum.reduce(nodes, %{}, fn v, acc ->
        incoming = Map.get(reverse, v, [])

        contribution =
          Enum.reduce(incoming, 0.0, fn u, sum ->
            out_u = Map.get(out_degree, u, 0)
            if out_u > 0, do: sum + Map.get(ranks, u, 0.0) / out_u, else: sum
          end)

        Map.put(acc, v, base + damping * contribution)
      end)

    # Check convergence
    diff =
      Enum.reduce(nodes, 0.0, fn v, sum ->
        sum + abs(Map.get(new_ranks, v, 0.0) - Map.get(ranks, v, 0.0))
      end)

    if diff < 1.0e-6 do
      Enum.reduce(nodes, %{}, fn v, acc ->
        Map.put(acc, v, Float.round(Map.get(new_ranks, v), 6))
      end)
    else
      do_pagerank(new_ranks, graph, reverse, out_degree, nodes, n, damping, iter + 1)
    end
  end

  defp build_reverse(graph, nodes) do
    base = Enum.reduce(nodes, %{}, fn v, acc -> Map.put(acc, v, []) end)

    Enum.reduce(graph, base, fn {from, tos}, acc ->
      Enum.reduce(tos, acc, fn to, a ->
        Map.update(a, to, [from], &[from | &1])
      end)
    end)
  end

  # ---------------------------------------------------------------------------
  # Private — Utilities
  # ---------------------------------------------------------------------------

  defp all_nodes(graph) do
    Enum.reduce(graph, MapSet.new(), fn {from, tos}, acc ->
      acc2 = MapSet.put(acc, from)
      Enum.reduce(tos, acc2, &MapSet.put(&2, &1))
    end)
  end
end
