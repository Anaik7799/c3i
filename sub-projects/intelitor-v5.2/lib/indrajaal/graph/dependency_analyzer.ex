defmodule Indrajaal.Graph.DependencyAnalyzer do
  @moduledoc """
  Dependency Analyzer — L3 Control Layer (Graph Subsystem)

  ## Design Intent

  Pure module that analyzes module and service dependency graphs. Uses
  Kahn's topological sort algorithm (O(V+E)) to detect cycles, identify
  layering violations, compute coupling scores, and find critical paths.

  Supports both compile-time module dependencies and runtime service
  dependencies. All functions are referentially transparent.

  ## Graph Representation

  A dependency graph is a list of `{from, to}` edges where `from` depends
  on `to`. Alternatively, an adjacency map `%{node => [nodes]}` is
  accepted for bulk analysis.

  ## STAMP Constraints

  - SC-BOOT-008: DAG acyclic validation (Kahn's algorithm)
  - SC-GRAPH-001: Graph structural properties
  - SC-CPM-001: Critical path computation

  ## Change History

  | Version | Date       | Author | Change                        |
  |---------|------------|--------|-------------------------------|
  | 21.3.1  | 2026-03-28 | Claude | Rewrite as pure module        |
  """

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type node_id :: atom() | String.t()
  @type edge :: {node_id(), node_id()}
  @type graph :: %{node_id() => [node_id()]}

  @type analysis_result :: %{
          node_count: non_neg_integer(),
          edge_count: non_neg_integer(),
          acyclic: boolean(),
          topological_order: [node_id()],
          critical_path: [node_id()],
          max_depth: non_neg_integer(),
          cycles: [[node_id()]],
          layers: [[node_id()]],
          coupling_scores: %{node_id() => float()}
        }

  # ---------------------------------------------------------------------------
  # Public API — Pure Functions
  # ---------------------------------------------------------------------------

  @doc """
  Analyze a dependency graph fully.

  Accepts either a list of `{from, to}` edges or an adjacency map.
  Returns a comprehensive `analysis_result` including topological order,
  cycle detection, layering, critical path, and coupling scores.

  ## Examples

      iex> Indrajaal.Graph.DependencyAnalyzer.analyze([{:a, :b}, {:b, :c}])
      %{acyclic: true, topological_order: [:a, :b, :c], ...}
  """
  @spec analyze([edge()] | graph()) :: analysis_result()
  def analyze(edges) when is_list(edges) do
    graph = edges_to_graph(edges)
    analyze(graph)
  end

  def analyze(graph) when is_map(graph) do
    nodes = all_nodes(graph)
    edges_count = Enum.reduce(graph, 0, fn {_, tos}, acc -> acc + length(tos) end)

    {acyclic, topo_order, detected_cycles} = kahn_sort(graph, nodes)
    layer_groups = if acyclic, do: compute_layers(graph, topo_order), else: []
    cp = if acyclic, do: compute_critical_path(graph, topo_order), else: []
    coupling = compute_coupling_scores(graph, nodes)
    max_depth = compute_max_depth(graph, nodes)

    %{
      node_count: MapSet.size(nodes),
      edge_count: edges_count,
      acyclic: acyclic,
      topological_order: topo_order,
      critical_path: cp,
      max_depth: max_depth,
      cycles: detected_cycles,
      layers: layer_groups,
      coupling_scores: coupling
    }
  end

  @doc """
  Detect cycles in the dependency graph.

  Returns a list of cycle descriptions. Each cycle is a list of node IDs
  forming the cycle. Returns `[]` for acyclic graphs.

  Uses DFS with coloring (white=0, grey=1, black=2).
  """
  @spec cycles([edge()] | graph()) :: [[node_id()]]
  def cycles(edges) when is_list(edges) do
    edges_to_graph(edges) |> cycles()
  end

  def cycles(graph) when is_map(graph) do
    nodes = all_nodes(graph) |> MapSet.to_list()
    {_acyclic, _topo, detected_cycles} = kahn_sort(graph, MapSet.new(nodes))

    if detected_cycles == [] do
      []
    else
      # Find actual cycle paths via DFS
      find_cycle_paths(graph, nodes)
    end
  end

  @doc """
  Compute dependency layers (topological levels).

  Layer 0 contains nodes with no incoming edges (roots).
  Layer k contains nodes whose dependencies all live in layers < k.

  Returns a list of node-ID lists, one per layer.
  Returns `[]` if the graph has cycles.
  """
  @spec layers([edge()] | graph()) :: [[node_id()]]
  def layers(edges) when is_list(edges) do
    edges_to_graph(edges) |> layers()
  end

  def layers(graph) when is_map(graph) do
    nodes = all_nodes(graph)
    {acyclic, topo_order, _} = kahn_sort(graph, nodes)

    if acyclic do
      compute_layers(graph, topo_order)
    else
      []
    end
  end

  @doc """
  Compute a coupling score for each node.

  Coupling score = (in_degree + out_degree) / (2 * (n - 1))
  Nodes with high coupling scores are strong candidates for refactoring
  or extraction behind interfaces.

  Returns a map of node → coupling score in [0.0, 1.0].
  Returns `%{}` for graphs with fewer than 2 nodes.
  """
  @spec coupling_score([edge()] | graph()) :: %{node_id() => float()}
  def coupling_score(edges) when is_list(edges) do
    edges_to_graph(edges) |> coupling_score()
  end

  def coupling_score(graph) when is_map(graph) do
    nodes = all_nodes(graph)
    compute_coupling_scores(graph, nodes)
  end

  @doc """
  Find the critical path (longest dependency chain) in a DAG.

  The critical path is the sequence of nodes forming the longest path
  from any root to any leaf. For cyclic graphs returns `[]`.

  Returns a list of node IDs in dependency order (root first).
  """
  @spec critical_path([edge()] | graph()) :: [node_id()]
  def critical_path(edges) when is_list(edges) do
    edges_to_graph(edges) |> critical_path()
  end

  def critical_path(graph) when is_map(graph) do
    nodes = all_nodes(graph)
    {acyclic, topo_order, _} = kahn_sort(graph, nodes)

    if acyclic do
      compute_critical_path(graph, topo_order)
    else
      []
    end
  end

  # ---------------------------------------------------------------------------
  # Private — Kahn's Topological Sort
  # ---------------------------------------------------------------------------

  defp kahn_sort(graph, nodes) do
    # Compute in-degrees
    in_degree =
      Enum.reduce(MapSet.to_list(nodes), %{}, fn n, acc -> Map.put(acc, n, 0) end)

    in_degree =
      Enum.reduce(graph, in_degree, fn {_from, tos}, acc ->
        Enum.reduce(tos, acc, fn to, a -> Map.update(a, to, 1, &(&1 + 1)) end)
      end)

    queue = for {n, 0} <- in_degree, do: n
    n_total = MapSet.size(nodes)
    do_kahn(queue, in_degree, graph, [], n_total)
  end

  defp do_kahn([], _in_deg, _graph, sorted, total) do
    if length(sorted) == total do
      {true, Enum.reverse(sorted), []}
    else
      {false, Enum.reverse(sorted), [[:cycle_detected]]}
    end
  end

  defp do_kahn([node | rest], in_deg, graph, sorted, total) do
    neighbors = Map.get(graph, node, [])

    {new_queue_additions, new_in_deg} =
      Enum.reduce(neighbors, {[], in_deg}, fn n, {q, deg} ->
        new_d = Map.get(deg, n, 0) - 1
        deg2 = Map.put(deg, n, new_d)
        if new_d <= 0, do: {[n | q], deg2}, else: {q, deg2}
      end)

    do_kahn(rest ++ new_queue_additions, new_in_deg, graph, [node | sorted], total)
  end

  # ---------------------------------------------------------------------------
  # Private — Layers
  # ---------------------------------------------------------------------------

  defp compute_layers(graph, topo_order) do
    # Assign each node its layer number = max(predecessor layers) + 1
    layer_num =
      Enum.reduce(topo_order, %{}, fn node, acc ->
        predecessors =
          Enum.filter(topo_order, fn n ->
            node in Map.get(graph, n, [])
          end)

        layer =
          case predecessors do
            [] -> 0
            preds -> Enum.map(preds, &Map.get(acc, &1, 0)) |> Enum.max() |> Kernel.+(1)
          end

        Map.put(acc, node, layer)
      end)

    # Group by layer number
    layer_num
    |> Enum.group_by(fn {_, l} -> l end, fn {n, _} -> n end)
    |> Enum.sort_by(fn {l, _} -> l end)
    |> Enum.map(fn {_, nodes} -> nodes end)
  end

  # ---------------------------------------------------------------------------
  # Private — Critical Path (Longest Path in DAG)
  # ---------------------------------------------------------------------------

  defp compute_critical_path(_graph, []), do: []

  defp compute_critical_path(graph, topo_order) do
    # DP: dist[v] = length of longest path ending at v
    {dist, pred} =
      Enum.reduce(topo_order, {%{}, %{}}, fn node, {d, p} ->
        d2 = Map.put_new(d, node, 0)

        {d3, p3} =
          Enum.reduce(Map.get(graph, node, []), {d2, p}, fn neighbor, {da, pa} ->
            new_dist = Map.get(da, node, 0) + 1
            existing = Map.get(da, neighbor, 0)

            if new_dist > existing do
              {Map.put(da, neighbor, new_dist), Map.put(pa, neighbor, node)}
            else
              {da, pa}
            end
          end)

        {d3, p3}
      end)

    case Enum.max_by(dist, fn {_, d} -> d end, fn -> {nil, 0} end) do
      {nil, _} ->
        []

      {end_node, _} ->
        reconstruct_path(pred, end_node, [end_node])
    end
  end

  defp reconstruct_path(pred, node, path) do
    case Map.get(pred, node) do
      nil -> path
      parent -> reconstruct_path(pred, parent, [parent | path])
    end
  end

  # ---------------------------------------------------------------------------
  # Private — Coupling Scores
  # ---------------------------------------------------------------------------

  defp compute_coupling_scores(graph, nodes) do
    n = MapSet.size(nodes)

    if n < 2 do
      Enum.reduce(MapSet.to_list(nodes), %{}, fn node, acc -> Map.put(acc, node, 0.0) end)
    else
      # Build reverse adjacency for in-degree
      reverse = build_reverse_adj(graph, nodes)
      denominator = 2.0 * (n - 1)

      Enum.reduce(MapSet.to_list(nodes), %{}, fn node, acc ->
        out_deg = length(Map.get(graph, node, []))
        in_deg = length(Map.get(reverse, node, []))
        score = Float.round((out_deg + in_deg) / denominator, 4)
        Map.put(acc, node, score)
      end)
    end
  end

  defp build_reverse_adj(graph, nodes) do
    base = Enum.reduce(MapSet.to_list(nodes), %{}, fn v, acc -> Map.put(acc, v, []) end)

    Enum.reduce(graph, base, fn {from, tos}, acc ->
      Enum.reduce(tos, acc, fn to, a ->
        Map.update(a, to, [from], &[from | &1])
      end)
    end)
  end

  # ---------------------------------------------------------------------------
  # Private — Max Depth (longest reachable path from any node)
  # ---------------------------------------------------------------------------

  defp compute_max_depth(graph, nodes) do
    if MapSet.size(nodes) < 1 do
      0
    else
      nodes
      |> MapSet.to_list()
      |> Enum.map(fn n -> bfs_max_dist(n, graph) end)
      |> Enum.max(fn -> 0 end)
    end
  end

  defp bfs_max_dist(start, graph) do
    do_bfs([{start, 0}], MapSet.new([start]), 0, graph)
  end

  defp do_bfs([], _visited, max_dist, _graph), do: max_dist

  defp do_bfs([{current, dist} | rest], visited, max_dist, graph) do
    neighbors =
      Map.get(graph, current, [])
      |> Enum.reject(&MapSet.member?(visited, &1))

    new_entries = Enum.map(neighbors, &{&1, dist + 1})
    new_visited = Enum.reduce(neighbors, visited, &MapSet.put(&2, &1))
    new_max = max(max_dist, dist)
    do_bfs(rest ++ new_entries, new_visited, new_max, graph)
  end

  # ---------------------------------------------------------------------------
  # Private — DFS Cycle Path Detection
  # ---------------------------------------------------------------------------

  defp find_cycle_paths(graph, nodes) do
    {cycles, _} =
      Enum.reduce(nodes, {[], %{}}, fn node, {cycles_acc, colors} ->
        if Map.get(colors, node, :white) == :white do
          {found, colors2} = dfs_cycle(node, graph, colors, [])
          {cycles_acc ++ found, colors2}
        else
          {cycles_acc, colors}
        end
      end)

    cycles
  end

  defp dfs_cycle(node, graph, colors, path) do
    colors2 = Map.put(colors, node, :grey)
    path2 = path ++ [node]

    {cycles, colors3} =
      Enum.reduce(Map.get(graph, node, []), {[], colors2}, fn neighbor, {c_acc, col} ->
        case Map.get(col, neighbor, :white) do
          :grey ->
            # Found a back edge — extract the cycle
            cycle_start_idx = Enum.find_index(path2, &(&1 == neighbor))

            cycle =
              if cycle_start_idx do
                Enum.slice(path2, cycle_start_idx..-1//1)
              else
                [neighbor | Enum.reverse(path2) |> Enum.take_while(&(&1 != neighbor))]
              end

            {c_acc ++ [cycle], col}

          :white ->
            {sub_cycles, col2} = dfs_cycle(neighbor, graph, col, path2)
            {c_acc ++ sub_cycles, col2}

          :black ->
            {c_acc, col}
        end
      end)

    {cycles, Map.put(colors3, node, :black)}
  end

  # ---------------------------------------------------------------------------
  # Private — Graph Building
  # ---------------------------------------------------------------------------

  defp edges_to_graph(edges) do
    Enum.reduce(edges, %{}, fn {from, to}, acc ->
      Map.update(acc, from, [to], &[to | &1])
    end)
  end

  defp all_nodes(graph) do
    Enum.reduce(graph, MapSet.new(), fn {from, tos}, acc ->
      Enum.reduce(tos, MapSet.put(acc, from), &MapSet.put(&2, &1))
    end)
  end
end
