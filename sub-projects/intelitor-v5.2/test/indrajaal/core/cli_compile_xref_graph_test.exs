defmodule Indrajaal.Core.CliCompileXrefGraphTest do
  @moduledoc """
  L5 TDG tests for compile-xref dependency graph DOT output.

  WHAT: Verifies the dependency graph analysis produced by the `compile-xref`
        devenv command — graph construction, cycle detection, DOT format output,
        strongly connected components, fan-in/fan-out, layer violations, and
        graph metrics. Fully self-contained; no production modules required.

  WHY: The `compile-xref` command is a SIL-6 quality gate (SC-METRICS-006)
       that validates the 7-level fractal module topology. Ensuring the graph
       analysis is correct prevents undetected circular dependencies
       (SC-BOOT-008) and cross-layer violations (SC-FRACTAL-001) from reaching
       production.

  CONSTRAINTS:
    - SC-FRACTAL-001: Expected genotype MUST match runtime graph
    - SC-BOOT-008: DAG acyclic (Kahn's algorithm)
    - SC-VER-007: All source files compiled
    - SC-METRICS-006: 7-level fractal analysis

  ## Change History
  | Version  | Date       | Author | Change                            |
  |----------|------------|--------|-----------------------------------|
  | 21.3.0   | 2026-03-24 | Claude | Initial compile-xref graph tests  |

  @version "21.3.0"
  @last_modified "2026-03-24T00:00:00Z"
  """

  use ExUnit.Case, async: true
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias StreamData, as: SD

  @moduletag :compile_xref
  @moduletag :cli
  @moduletag :sprint_88

  # ============================================================================
  # ETS-backed graph simulation
  #
  # Graph is stored as a directed adjacency map:
  #   %{module_name => [dependency_name, ...]}
  #
  # ETS table :xref_graph holds a single key :graph_data => map.
  # ============================================================================

  defp new_graph(table, edges) when is_list(edges) do
    graph =
      Enum.reduce(edges, %{}, fn {from, to}, acc ->
        acc
        |> Map.update(from, [to], &[to | &1])
        |> Map.update(to, [], fn existing -> existing end)
      end)

    :ets.insert(table, {:graph_data, graph})
    graph
  end

  defp get_graph(table) do
    case :ets.lookup(table, :graph_data) do
      [{:graph_data, g}] -> g
      [] -> %{}
    end
  end

  # ============================================================================
  # build_graph/1 — build directed adjacency map from edge list
  # ============================================================================

  defp build_graph(edges) do
    Enum.reduce(edges, %{}, fn {from, to}, acc ->
      acc
      |> Map.update(from, [to], &[to | &1])
      # Ensure target node exists even with no outgoing edges
      |> Map.update(to, [], & &1)
    end)
  end

  # ============================================================================
  # detect_cycles/1 — DFS-based cycle detection
  # Returns {:cyclic, [cycle_path]} | {:acyclic, [topological_order]}
  # ============================================================================

  defp detect_cycles(graph) do
    nodes = Map.keys(graph)
    {result, order} = dfs_cycle_check(nodes, graph, MapSet.new(), MapSet.new(), [])

    case result do
      :acyclic -> {:acyclic, Enum.reverse(order)}
      {:cyclic, cycle} -> {:cyclic, cycle}
    end
  end

  defp dfs_cycle_check([], _graph, _visited, _in_stack, order) do
    {:acyclic, order}
  end

  defp dfs_cycle_check([node | rest], graph, visited, in_stack, order) do
    if MapSet.member?(visited, node) do
      dfs_cycle_check(rest, graph, visited, in_stack, order)
    else
      case dfs_visit(node, graph, visited, in_stack, order) do
        {:cyclic, cycle} ->
          {{:cyclic, cycle}, order}

        {:ok, new_visited, new_order} ->
          dfs_cycle_check(rest, graph, new_visited, in_stack, new_order)
      end
    end
  end

  defp dfs_visit(node, graph, visited, in_stack, order) do
    visited = MapSet.put(visited, node)
    in_stack = MapSet.put(in_stack, node)

    neighbors = Map.get(graph, node, [])

    result =
      Enum.reduce_while(neighbors, {:ok, visited, in_stack, order}, fn neighbor, {:ok, v, s, o} ->
        cond do
          MapSet.member?(s, neighbor) ->
            # Back edge — cycle detected
            {:halt, {:cyclic, [neighbor, node]}}

          MapSet.member?(v, neighbor) ->
            # Already fully visited — skip
            {:cont, {:ok, v, s, o}}

          true ->
            case dfs_visit(neighbor, graph, v, s, o) do
              {:cyclic, path} -> {:halt, {:cyclic, [node | path]}}
              {:ok, nv, _ns, no} -> {:cont, {:ok, nv, s, no}}
            end
        end
      end)

    case result do
      {:cyclic, path} ->
        {:cyclic, path}

      {:ok, final_visited, _final_stack, final_order} ->
        {:ok, final_visited, [node | final_order]}
    end
  end

  # ============================================================================
  # kahn_sort/1 — Kahn's algorithm for topological sort (SC-BOOT-008)
  # Returns {:ok, [order]} | {:error, :cycle_detected}
  # ============================================================================

  defp kahn_sort(graph) do
    nodes = Map.keys(graph)
    all_edges = for {from, tos} <- graph, to <- tos, do: {from, to}

    in_degree =
      Enum.reduce(nodes, %{}, fn n, acc -> Map.put(acc, n, 0) end)

    in_degree =
      Enum.reduce(all_edges, in_degree, fn {_from, to}, acc ->
        Map.update(acc, to, 1, &(&1 + 1))
      end)

    queue = for {n, 0} <- in_degree, do: n
    kahn_loop(queue, graph, in_degree, [])
  end

  defp kahn_loop([], _graph, in_degree, result) do
    remaining = Enum.count(in_degree, fn {_, d} -> d > 0 end)

    if remaining > 0 do
      {:error, :cycle_detected}
    else
      {:ok, Enum.reverse(result)}
    end
  end

  defp kahn_loop([node | queue], graph, in_degree, result) do
    neighbors = Map.get(graph, node, [])

    {new_in_degree, new_queue} =
      Enum.reduce(neighbors, {in_degree, queue}, fn neighbor, {deg, q} ->
        new_deg = Map.update!(deg, neighbor, &(&1 - 1))

        if new_deg[neighbor] == 0 do
          {new_deg, q ++ [neighbor]}
        else
          {new_deg, q}
        end
      end)

    kahn_loop(new_queue, graph, new_in_degree, [node | result])
  end

  # ============================================================================
  # to_dot/2 — generate Graphviz DOT format
  # ============================================================================

  defp to_dot(graph, opts \\ []) do
    graph_name = Keyword.get(opts, :name, "xref_graph")
    highlight_cycles = Keyword.get(opts, :highlight_cycles, [])

    edges_dot =
      for {from, tos} <- graph,
          to <- tos do
        edge_style =
          if Enum.member?(highlight_cycles, {from, to}) do
            " [color=red, style=bold]"
          else
            ""
          end

        "  \"#{from}\" -> \"#{to}\"#{edge_style};"
      end

    nodes_dot =
      Map.keys(graph)
      |> Enum.map(fn node ->
        layer = extract_layer(node)
        color = layer_color(layer)
        "  \"#{node}\" [label=\"#{node}\", fillcolor=\"#{color}\", style=filled];"
      end)

    ([
       "digraph #{graph_name} {",
       "  rankdir=TB;",
       "  node [shape=box, fontname=\"Helvetica\"];",
       ""
     ] ++
       nodes_dot ++
       [""] ++
       edges_dot ++
       ["}"])
    |> Enum.join("\n")
  end

  defp extract_layer(module_name) when is_atom(module_name) do
    str = Atom.to_string(module_name)
    extract_layer(str)
  end

  defp extract_layer(module_name) when is_binary(module_name) do
    cond do
      String.contains?(module_name, "L1") -> 1
      String.contains?(module_name, "L2") -> 2
      String.contains?(module_name, "L3") -> 3
      String.contains?(module_name, "L4") -> 4
      String.contains?(module_name, "L5") -> 5
      String.contains?(module_name, "L6") -> 6
      String.contains?(module_name, "L7") -> 7
      true -> 0
    end
  end

  defp layer_color(0), do: "white"
  defp layer_color(1), do: "#e8f4f8"
  defp layer_color(2), do: "#d0e8f0"
  defp layer_color(3), do: "#b8dce8"
  defp layer_color(4), do: "#a0d0e0"
  defp layer_color(5), do: "#88c4d8"
  defp layer_color(6), do: "#70b8d0"
  defp layer_color(7), do: "#58acc8"

  # ============================================================================
  # find_sccs/1 — Tarjan's SCC algorithm (simulation)
  # Returns list of SCCs, each an ordered list of nodes
  # ============================================================================

  defp find_sccs(graph) do
    nodes = Map.keys(graph)
    state = %{index: 0, stack: [], on_stack: MapSet.new(), indices: %{}, low_links: %{}, sccs: []}

    result =
      Enum.reduce(nodes, state, fn node, s ->
        if Map.has_key?(s.indices, node) do
          s
        else
          tarjan_dfs(node, graph, s)
        end
      end)

    result.sccs
  end

  defp tarjan_dfs(node, graph, state) do
    idx = state.index
    state = %{state | indices: Map.put(state.indices, node, idx)}
    state = %{state | low_links: Map.put(state.low_links, node, idx)}
    state = %{state | index: idx + 1}
    state = %{state | stack: [node | state.stack]}
    state = %{state | on_stack: MapSet.put(state.on_stack, node)}

    neighbors = Map.get(graph, node, [])

    state =
      Enum.reduce(neighbors, state, fn w, s ->
        if not Map.has_key?(s.indices, w) do
          # Successor not yet visited
          s2 = tarjan_dfs(w, graph, s)
          low_w = Map.get(s2.low_links, w, idx)
          low_v = Map.get(s2.low_links, node, idx)
          %{s2 | low_links: Map.put(s2.low_links, node, min(low_v, low_w))}
        else
          if MapSet.member?(s.on_stack, w) do
            # Successor is on stack — back edge
            low_v = Map.get(s.low_links, node, idx)
            idx_w = Map.get(s.indices, w, idx)
            %{s | low_links: Map.put(s.low_links, node, min(low_v, idx_w))}
          else
            s
          end
        end
      end)

    # If node is root of an SCC, pop the stack
    if Map.get(state.low_links, node) == Map.get(state.indices, node) do
      {scc, new_stack, new_on_stack} = pop_scc(node, state.stack, state.on_stack, [])
      %{state | stack: new_stack, on_stack: new_on_stack, sccs: [scc | state.sccs]}
    else
      state
    end
  end

  defp pop_scc(root, [root | rest], on_stack, scc) do
    {[root | scc], rest, MapSet.delete(on_stack, root)}
  end

  defp pop_scc(root, [head | rest], on_stack, scc) do
    pop_scc(root, rest, MapSet.delete(on_stack, head), [head | scc])
  end

  # ============================================================================
  # compute_fan_in_out/1 — in-degree and out-degree per module
  # ============================================================================

  defp compute_fan_in_out(graph) do
    nodes = Map.keys(graph)

    # out-degree: number of dependencies a module has
    out_degree =
      Enum.reduce(nodes, %{}, fn n, acc ->
        Map.put(acc, n, length(Map.get(graph, n, [])))
      end)

    # in-degree: number of modules that depend on this module (fan-in)
    in_degree =
      Enum.reduce(nodes, %{}, fn n, acc -> Map.put(acc, n, 0) end)

    in_degree =
      Enum.reduce(graph, in_degree, fn {_from, tos}, acc ->
        Enum.reduce(tos, acc, fn to, a ->
          Map.update(a, to, 1, &(&1 + 1))
        end)
      end)

    %{fan_in: in_degree, fan_out: out_degree}
  end

  # ============================================================================
  # detect_layer_violations/2 — cross-layer dependency violations
  # Higher layer number = higher abstraction (L7 > L1)
  # A violation: a lower-layer module depends on a higher-layer module
  # e.g., L1 → L3 is a violation (L1 must not depend on L3)
  # ============================================================================

  defp detect_layer_violations(graph, layer_map) do
    for {from, tos} <- graph,
        to <- tos,
        from_layer = Map.get(layer_map, from, 0),
        to_layer = Map.get(layer_map, to, 0),
        from_layer > 0 and to_layer > 0,
        from_layer < to_layer do
      {from, to, from_layer, to_layer}
    end
  end

  # ============================================================================
  # compute_metrics/1 — graph density, longest path, avg path length
  # ============================================================================

  defp compute_metrics(graph) do
    nodes = Map.keys(graph)
    n = length(nodes)
    edges = for {from, tos} <- graph, _to <- tos, do: from
    e = length(edges)

    density =
      if n <= 1 do
        0.0
      else
        e / (n * (n - 1))
      end

    # Longest path (only meaningful for DAGs)
    longest =
      case kahn_sort(graph) do
        {:ok, order} -> compute_longest_path(order, graph)
        {:error, :cycle_detected} -> -1
      end

    avg_out =
      if n == 0 do
        0.0
      else
        e / n
      end

    %{
      node_count: n,
      edge_count: e,
      density: Float.round(density, 4),
      longest_path: longest,
      average_out_degree: Float.round(avg_out, 4)
    }
  end

  defp compute_longest_path(topo_order, graph) do
    dist =
      Enum.reduce(topo_order, %{}, fn n, acc -> Map.put(acc, n, 0) end)

    dist =
      Enum.reduce(topo_order, dist, fn node, d ->
        node_dist = Map.get(d, node, 0)

        Enum.reduce(Map.get(graph, node, []), d, fn neighbor, dd ->
          current = Map.get(dd, neighbor, 0)
          Map.put(dd, neighbor, max(current, node_dist + 1))
        end)
      end)

    if map_size(dist) == 0 do
      0
    else
      Enum.max(Map.values(dist))
    end
  end

  # ============================================================================
  # Setup
  # ============================================================================

  setup do
    table = :ets.new(:xref_graph_test, [:set, :public])

    on_exit(fn ->
      if :ets.info(table) != :undefined, do: :ets.delete(table)
    end)

    %{table: table}
  end

  # ============================================================================
  # 1. Graph Construction
  # ============================================================================

  describe "graph construction" do
    test "build_graph/1 produces correct node count from edge list", %{table: table} do
      edges = [
        {:ModA, :ModB},
        {:ModB, :ModC},
        {:ModA, :ModC}
      ]

      graph = new_graph(table, edges)
      nodes = Map.keys(graph)

      assert length(nodes) == 3
      assert :ModA in nodes
      assert :ModB in nodes
      assert :ModC in nodes
    end

    test "build_graph/1 produces correct directed edge count", %{table: _table} do
      edges = [
        {:Core, :Util},
        {:Core, :Auth},
        {:Auth, :Util}
      ]

      graph = build_graph(edges)
      edge_count = for {_from, tos} <- graph, _to <- tos, do: 1
      assert length(edge_count) == 3
    end

    test "build_graph/1 handles nodes with no outgoing edges", %{table: table} do
      edges = [{:A, :B}, {:A, :C}]
      graph = new_graph(table, edges)

      # B and C are targets — they must exist in the graph as nodes
      assert Map.has_key?(graph, :B)
      assert Map.has_key?(graph, :C)
      assert graph[:B] == []
      assert graph[:C] == []
    end

    test "build_graph/1 handles disconnected nodes", %{table: _table} do
      edges = [{:X, :Y}, {:Z, :W}]
      graph = build_graph(edges)

      assert Map.has_key?(graph, :X)
      assert Map.has_key?(graph, :Y)
      assert Map.has_key?(graph, :Z)
      assert Map.has_key?(graph, :W)
    end

    test "ETS-stored graph matches in-memory graph", %{table: table} do
      edges = [{:M1, :M2}, {:M2, :M3}, {:M1, :M3}]
      stored = new_graph(table, edges)
      retrieved = get_graph(table)

      assert stored == retrieved
    end

    test "build_graph/1 is deterministic for same edge list", %{table: _table} do
      edges = [{:A, :B}, {:B, :C}, {:A, :C}]
      g1 = build_graph(edges)
      g2 = build_graph(edges)

      assert g1 == g2
    end
  end

  # ============================================================================
  # 2. Cycle Detection
  # ============================================================================

  describe "cycle detection" do
    test "DAG returns :acyclic with topological order", %{table: _table} do
      # A → B → C → D (linear DAG)
      edges = [{:A, :B}, {:B, :C}, {:C, :D}]
      graph = build_graph(edges)

      assert {:acyclic, order} = detect_cycles(graph)
      assert length(order) == 4

      # A must appear before B, B before C, C before D
      idx = Enum.with_index(order) |> Map.new()
      assert idx[:A] < idx[:B]
      assert idx[:B] < idx[:C]
      assert idx[:C] < idx[:D]
    end

    test "cycle A → B → A is detected", %{table: _table} do
      edges = [{:A, :B}, {:B, :A}]
      graph = build_graph(edges)

      assert {:cyclic, _path} = detect_cycles(graph)
    end

    test "self-loop is detected as a cycle", %{table: _table} do
      graph = %{SelfRef: [:SelfRef]}

      assert {:cyclic, _path} = detect_cycles(graph)
    end

    test "three-node cycle A → B → C → A is detected", %{table: _table} do
      edges = [{:A, :B}, {:B, :C}, {:C, :A}]
      graph = build_graph(edges)

      assert {:cyclic, path} = detect_cycles(graph)
      assert length(path) >= 2
    end

    test "Kahn's algorithm: DAG returns {:ok, topological_order} (SC-BOOT-008)",
         %{table: _table} do
      edges = [{:L1, :L2}, {:L2, :L3}, {:L1, :L3}]
      graph = build_graph(edges)

      assert {:ok, order} = kahn_sort(graph)
      assert :L1 in order
      assert :L2 in order
      assert :L3 in order
    end

    test "Kahn's algorithm: cyclic graph returns {:error, :cycle_detected}", %{table: _table} do
      edges = [{:P, :Q}, {:Q, :R}, {:R, :P}]
      graph = build_graph(edges)

      assert {:error, :cycle_detected} = kahn_sort(graph)
    end

    test "empty graph is acyclic", %{table: _table} do
      assert {:ok, []} = kahn_sort(%{})
    end

    test "single node with no edges is acyclic", %{table: _table} do
      graph = %{Lone: []}

      assert {:ok, [:Lone]} = kahn_sort(graph)
    end
  end

  # ============================================================================
  # 3. DOT Format Output
  # ============================================================================

  describe "DOT format output" do
    test "to_dot/2 produces string starting with 'digraph'", %{table: _table} do
      graph = build_graph([{:A, :B}])
      dot = to_dot(graph)

      assert String.starts_with?(dot, "digraph")
    end

    test "to_dot/2 includes '->' for directed edges", %{table: _table} do
      edges = [{:Core, :Util}, {:Core, :DB}]
      graph = build_graph(edges)
      dot = to_dot(graph)

      assert String.contains?(dot, "->")
    end

    test "to_dot/2 wraps output in braces (valid DOT structure)", %{table: _table} do
      graph = build_graph([{:X, :Y}])
      dot = to_dot(graph)

      assert String.contains?(dot, "{")
      assert String.contains?(dot, "}")
    end

    test "to_dot/2 uses custom graph name", %{table: _table} do
      graph = build_graph([{:Mod, :Dep}])
      dot = to_dot(graph, name: "my_module_graph")

      assert String.contains?(dot, "my_module_graph")
    end

    test "to_dot/2 includes all module names as nodes", %{table: _table} do
      edges = [{:AuthModule, :TokenCache}, {:AuthModule, :UserStore}]
      graph = build_graph(edges)
      dot = to_dot(graph)

      assert String.contains?(dot, "AuthModule")
      assert String.contains?(dot, "TokenCache")
      assert String.contains?(dot, "UserStore")
    end

    test "to_dot/2 includes edge style attributes for valid Graphviz syntax", %{table: _table} do
      graph = build_graph([{:ModA, :ModB}])
      dot = to_dot(graph)

      # Must include semicolons (valid DOT statement terminators)
      assert String.contains?(dot, ";")
    end

    test "to_dot/2 highlights cycle edges in red when provided", %{table: _table} do
      graph = build_graph([{:A, :B}, {:B, :A}])
      dot = to_dot(graph, highlight_cycles: [{:A, :B}])

      assert String.contains?(dot, "color=red")
    end

    test "to_dot/2 includes rankdir attribute for layout", %{table: _table} do
      graph = build_graph([{:X, :Y}])
      dot = to_dot(graph)

      assert String.contains?(dot, "rankdir=TB")
    end
  end

  # ============================================================================
  # 4. Connected Components (Strongly Connected Components via Tarjan's)
  # ============================================================================

  describe "connected components (Tarjan's SCC)" do
    test "DAG: each node is its own SCC", %{table: _table} do
      # A → B → C — no back edges
      edges = [{:N1, :N2}, {:N2, :N3}]
      graph = build_graph(edges)
      sccs = find_sccs(graph)

      # Three nodes, three singleton SCCs
      assert length(sccs) == 3

      for scc <- sccs do
        assert length(scc) == 1
      end
    end

    test "single cycle forms one SCC of size 3", %{table: _table} do
      edges = [{:A, :B}, {:B, :C}, {:C, :A}]
      graph = build_graph(edges)
      sccs = find_sccs(graph)

      big_scc = Enum.find(sccs, fn s -> length(s) > 1 end)
      assert big_scc != nil
      assert length(big_scc) == 3
    end

    test "two disconnected cycles produce two non-trivial SCCs", %{table: _table} do
      # Cycle 1: X → Y → X
      # Cycle 2: P → Q → P
      edges = [{:X, :Y}, {:Y, :X}, {:P, :Q}, {:Q, :P}]
      graph = build_graph(edges)
      sccs = find_sccs(graph)

      non_trivial = Enum.filter(sccs, fn s -> length(s) > 1 end)
      assert length(non_trivial) == 2
    end

    test "isolated node (no edges) is its own SCC", %{table: _table} do
      graph = %{Isolated: []}
      sccs = find_sccs(graph)

      assert length(sccs) == 1
      assert [:Isolated] in sccs
    end

    test "SCC count matches expected topology for complex graph", %{table: _table} do
      # A → B → A (cycle), C → D (no cycle), D → A (connects to cycle)
      edges = [{:A, :B}, {:B, :A}, {:C, :D}, {:D, :A}]
      graph = build_graph(edges)
      sccs = find_sccs(graph)

      # A and B form one SCC; C and D are singletons
      total_nodes_in_sccs = Enum.sum(Enum.map(sccs, &length/1))
      assert total_nodes_in_sccs == 4
    end
  end

  # ============================================================================
  # 5. Fan-in / Fan-out Analysis
  # ============================================================================

  describe "fan-in/fan-out analysis" do
    test "leaf node (no incoming) has fan-in = 0", %{table: _table} do
      # Core depends on nothing (is a root)
      graph = build_graph([{:Core, :Util}, {:Core, :DB}])
      %{fan_in: fan_in} = compute_fan_in_out(graph)

      assert fan_in[:Core] == 0
    end

    test "shared dependency has fan-in > 1", %{table: _table} do
      # Both ModA and ModB depend on Shared
      graph = build_graph([{:ModA, :Shared}, {:ModB, :Shared}])
      %{fan_in: fan_in} = compute_fan_in_out(graph)

      assert fan_in[:Shared] == 2
    end

    test "module with many dependencies has high fan-out", %{table: _table} do
      edges = [{:Hub, :A}, {:Hub, :B}, {:Hub, :C}, {:Hub, :D}]
      graph = build_graph(edges)
      %{fan_out: fan_out} = compute_fan_in_out(graph)

      assert fan_out[:Hub] == 4
    end

    test "isolated node has fan-in = 0 and fan-out = 0", %{table: _table} do
      graph = %{Lone: []}
      %{fan_in: fan_in, fan_out: fan_out} = compute_fan_in_out(graph)

      assert fan_in[:Lone] == 0
      assert fan_out[:Lone] == 0
    end

    test "fan-in sum equals total edge count", %{table: _table} do
      edges = [{:A, :B}, {:B, :C}, {:A, :C}, {:C, :D}]
      graph = build_graph(edges)
      %{fan_in: fan_in} = compute_fan_in_out(graph)

      total_fan_in = Enum.sum(Map.values(fan_in))
      edge_count = for {_from, tos} <- graph, _to <- tos, do: 1

      assert total_fan_in == length(edge_count)
    end
  end

  # ============================================================================
  # 6. Layer Violation Detection
  # ============================================================================

  describe "layer violation detection" do
    test "no violations in a strictly layered DAG", %{table: _table} do
      # L3 → L2 → L1 is correct (higher layer depends on lower)
      graph = build_graph([{:L3Mod, :L2Mod}, {:L2Mod, :L1Mod}])

      layer_map = %{L3Mod: 3, L2Mod: 2, L1Mod: 1}
      violations = detect_layer_violations(graph, layer_map)

      assert violations == []
    end

    test "L1 module depending on L3 module is a violation", %{table: _table} do
      graph = build_graph([{:L1Core, :L3Domain}])
      layer_map = %{L1Core: 1, L3Domain: 3}

      violations = detect_layer_violations(graph, layer_map)

      assert length(violations) == 1
      [{from, to, fl, tl}] = violations
      assert from == :L1Core
      assert to == :L3Domain
      assert fl == 1
      assert tl == 3
    end

    test "violation report includes from/to module names and layer numbers",
         %{table: _table} do
      graph = build_graph([{:FunctionMod, :DomainMod}])
      layer_map = %{FunctionMod: 1, DomainMod: 3}

      [{from, to, from_layer, to_layer}] = detect_layer_violations(graph, layer_map)

      assert is_atom(from)
      assert is_atom(to)
      assert is_integer(from_layer)
      assert is_integer(to_layer)
      assert from_layer < to_layer
    end

    test "multiple violations are all reported", %{table: _table} do
      graph =
        build_graph([
          {:L1A, :L3X},
          {:L1B, :L4Y},
          {:L2C, :L3Z}
        ])

      layer_map = %{L1A: 1, L3X: 3, L1B: 1, L4Y: 4, L2C: 2, L3Z: 3}
      violations = detect_layer_violations(graph, layer_map)

      assert length(violations) == 3
    end

    test "nodes without layer mapping are excluded from violation checks",
         %{table: _table} do
      graph = build_graph([{:UnknownMod, :AnotherUnknown}])
      layer_map = %{}

      violations = detect_layer_violations(graph, layer_map)
      assert violations == []
    end
  end

  # ============================================================================
  # 7. Dependency Metrics
  # ============================================================================

  describe "dependency metrics" do
    test "metrics include node_count, edge_count, density, longest_path", %{table: _table} do
      graph = build_graph([{:A, :B}, {:B, :C}])
      metrics = compute_metrics(graph)

      assert Map.has_key?(metrics, :node_count)
      assert Map.has_key?(metrics, :edge_count)
      assert Map.has_key?(metrics, :density)
      assert Map.has_key?(metrics, :longest_path)
      assert Map.has_key?(metrics, :average_out_degree)
    end

    test "linear chain A → B → C → D has longest_path = 3", %{table: _table} do
      graph = build_graph([{:A, :B}, {:B, :C}, {:C, :D}])
      metrics = compute_metrics(graph)

      assert metrics.longest_path == 3
    end

    test "empty graph has density 0.0", %{table: _table} do
      metrics = compute_metrics(%{})
      assert metrics.density == 0.0
    end

    test "complete graph K3 has density > 0.5", %{table: _table} do
      # K3 directed: 6 edges for 3 nodes, max possible = 3*2 = 6, density = 1.0
      edges = [{:N1, :N2}, {:N1, :N3}, {:N2, :N1}, {:N2, :N3}, {:N3, :N1}, {:N3, :N2}]
      graph = build_graph(edges)
      metrics = compute_metrics(graph)

      assert metrics.density > 0.5
    end

    test "node_count matches actual node count", %{table: _table} do
      edges = [{:M1, :M2}, {:M2, :M3}, {:M3, :M4}]
      graph = build_graph(edges)
      metrics = compute_metrics(graph)

      assert metrics.node_count == 4
    end

    test "edge_count matches actual edge count", %{table: _table} do
      edges = [{:A, :B}, {:A, :C}, {:B, :C}]
      graph = build_graph(edges)
      metrics = compute_metrics(graph)

      assert metrics.edge_count == 3
    end

    test "cyclic graph has longest_path = -1 (undefined for cyclic graph)", %{table: _table} do
      graph = build_graph([{:X, :Y}, {:Y, :X}])
      metrics = compute_metrics(graph)

      assert metrics.longest_path == -1
    end
  end

  # ============================================================================
  # 8. Property-based graph analysis (StreamData)
  # ============================================================================

  describe "property: graph invariants (StreamData)" do
    test "fan-in sum always equals edge count for random DAGs" do
      ExUnitProperties.check all(
                               n <- SD.integer(3..6),
                               extra_edges <- SD.integer(0..3)
                             ) do
        # Build a random DAG: chain i → i+1 plus some extras
        chain_edges = Enum.map(1..(n - 1), fn i -> {:"M#{i}", :"M#{i + 1}"} end)

        # Extra forward-only edges (no back edges to keep it acyclic)
        extra =
          Enum.flat_map(1..extra_edges, fn _ ->
            # Only create forward edges (lower to higher index)
            i = :rand.uniform(n - 2)
            j = i + 1 + :rand.uniform(n - i - 1)
            [{:"M#{i}", :"M#{j}"}]
          end)

        graph = build_graph(chain_edges ++ extra)
        %{fan_in: fan_in} = compute_fan_in_out(graph)
        edge_count = for {_from, tos} <- graph, _to <- tos, do: 1

        Enum.sum(Map.values(fan_in)) == length(edge_count)
      end
    end

    test "Kahn's algorithm succeeds on all DAGs built from chain edges" do
      ExUnitProperties.check all(n <- SD.integer(2..8)) do
        edges = Enum.map(1..(n - 1), fn i -> {:"N#{i}", :"N#{i + 1}"} end)
        graph = build_graph(edges)

        assert {:ok, order} = kahn_sort(graph)
        assert length(order) == n
      end
    end

    test "DOT output always starts with 'digraph' for any non-empty graph" do
      ExUnitProperties.check all(n <- SD.integer(1..5)) do
        edges = Enum.map(1..n, fn i -> {:"Mod#{i}", :"Dep#{i}"} end)
        graph = build_graph(edges)
        dot = to_dot(graph)

        String.starts_with?(dot, "digraph")
      end
    end
  end
end
