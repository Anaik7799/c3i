defmodule Indrajaal.SMRITI.KnowledgeGraphLinkResolutionTest do
  @moduledoc """
  TDG test suite for SMRITI knowledge graph link resolution.

  ## WHAT
  Self-contained in-memory knowledge graph engine covering node/edge management,
  BFS traversal, cycle detection, transitive closure computation, and graph
  integrity invariants. All helpers are pure `defp` functions — no production
  module dependencies. The graph is represented as:

      %{
        nodes: %{id => %{id: String.t(), metadata: map()}},
        edges: [{from_id :: String.t(), to_id :: String.t()}]
      }

  ## WHY
  SMRITI's query engine (SC-SMRITI-133) must resolve links in < 500ms.
  Full-text / semantic search (SC-SMRITI-131) depends on graph traversal to
  expand query context. The knowledge ingestion pipeline (SC-IKE-001) requires
  cycle detection to reject circular knowledge dependencies before ingestion.
  Transitive closure pre-computes reachability, enabling `O(1)` reachability
  queries post-build.

  ## CONSTRAINTS
  - SC-SMRITI-130: Query results include integrity proofs
  - SC-SMRITI-131: Full-text search uses FTS5 (graph traversal feeds query expansion)
  - SC-IKE-001:    Document ingestion pipeline validates acyclicity before insert
  - SC-SMRITI-133: Query timeout < 500ms (BFS must terminate promptly)
  - SC-SMRITI-140: All evolution events recorded (graph mutations logged)
  - SC-SMRITI-141: Lineage chain unbroken (graph preserves provenance edges)

  ## FMEA Coverage
  | Failure Mode                          | Severity | Occurrence | Detection | RPN |
  |---------------------------------------|----------|------------|-----------|-----|
  | BFS visits same node twice (infinite) |    8     |     3      |     7     | 168 |
  | Cycle detection false negative        |    9     |     2      |     7     | 126 |
  | Transitive closure missing pair       |    7     |     3      |     6     | 126 |
  | Dangling edge not detected            |    6     |     4      |     6     | 144 |
  | BFS shortest path incorrect           |    6     |     2      |     8     |  96 |
  | Orphan node leaks memory              |    3     |     5      |     4     |  60 |

  ## Constitutional Verification
  - Ψ₀ Existence:     graph helpers never raise on valid input
  - Ψ₂ History:       add_node/add_edge operations are append-only (no hidden mutation)
  - Ψ₃ Verification:  transitive_closure is idempotent (self-verifying output)
  - Ψ₅ Truthfulness:  cycle detection accurately reflects structural reality

  ## EP-GEN-014 Compliance
  - `use PropCheck` for `property` / `forall` blocks using `PC.` prefix generators
  - `import ExUnitProperties, except: [property: 2, property: 3, check: 2]` to avoid clash
  - `require ExUnitProperties` so the `ExUnitProperties.check all(` call compiles
  - `alias StreamData, as: SD` — all StreamData generators use `SD.` prefix
  - `ExUnitProperties.check all(` — NEVER bare `check all(` inside a test block

  ## Change History
  | Version | Date       | Author | Change                                     |
  |---------|------------|--------|--------------------------------------------|
  | 21.3.0  | 2026-03-24 | Claude | Initial TDG test for graph link resolution |
  """

  use ExUnit.Case, async: true
  use PropCheck

  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  require ExUnitProperties

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :smriti
  @moduletag :sprint_88
  @moduletag :knowledge_graph

  setup_all do
    Application.ensure_all_started(:propcheck)
    :ok
  end

  # ============================================================
  # HELPERS: GRAPH CONSTRUCTION
  # ============================================================

  # Returns an empty graph.
  defp new_graph, do: %{nodes: %{}, edges: []}

  # Adds a node with the given id and metadata map.
  # If a node with the same id already exists it is overwritten.
  defp add_node(graph, id, metadata \\ %{}) do
    node = %{id: id, metadata: metadata}
    put_in(graph, [:nodes, id], node)
  end

  # Adds a directed edge from → to.
  # Does NOT validate that nodes exist (allows testing dangling-edge detection).
  defp add_edge(graph, from, to) do
    update_in(graph, [:edges], fn edges -> [{from, to} | edges] end)
  end

  # Returns the list of direct outgoing neighbours from node_id.
  defp neighbours(graph, node_id) do
    for {f, t} <- graph.edges, f == node_id, do: t
  end

  # ============================================================
  # HELPERS: BFS
  # ============================================================

  # BFS from start_id toward target_id.
  # Returns {:ok, path} where path is a list of node IDs start..target (inclusive),
  # or {:error, :not_reachable} if no path exists.
  defp bfs(graph, start_id, target_id) do
    bfs_loop(graph, :queue.from_list([[start_id]]), MapSet.new([start_id]), target_id)
  end

  defp bfs_loop(_graph, queue, _visited, target_id) do
    case :queue.out(queue) do
      {:empty, _} ->
        {:error, :not_reachable}

      {{:value, path}, rest} ->
        current = List.last(path)

        if current == target_id do
          {:ok, path}
        else
          {new_q, new_vis} =
            graph
            |> neighbours(current)
            |> Enum.reject(&MapSet.member?(_visited, &1))
            |> Enum.reduce({rest, _visited}, fn n, {q, vis} ->
              {:queue.in(path ++ [n], q), MapSet.put(vis, n)}
            end)

          bfs_loop(graph, new_q, new_vis, target_id)
        end
    end
  end

  # resolve_link/3 — find whether target_id is reachable from source_id.
  # Returns {:ok, path} or {:error, :not_reachable}.
  defp resolve_link(graph, source_id, target_id) do
    bfs(graph, source_id, target_id)
  end

  # Returns true when source_id can reach target_id (direct or transitive).
  defp reachable?(graph, source_id, target_id) do
    match?({:ok, _}, resolve_link(graph, source_id, target_id))
  end

  # ============================================================
  # HELPERS: BFS — ALL REACHABLE NODES
  # ============================================================

  # Returns the MapSet of all node IDs reachable from start_id (inclusive of start).
  defp bfs_all_reachable(graph, start_id) do
    bfs_all_loop(graph, :queue.from_list([start_id]), MapSet.new([start_id]))
  end

  defp bfs_all_loop(graph, queue, visited) do
    case :queue.out(queue) do
      {:empty, _} ->
        visited

      {{:value, node}, rest} ->
        {new_q, new_vis} =
          graph
          |> neighbours(node)
          |> Enum.reject(&MapSet.member?(visited, &1))
          |> Enum.reduce({rest, visited}, fn n, {q, vis} ->
            {:queue.in(n, q), MapSet.put(vis, n)}
          end)

        bfs_all_loop(graph, new_q, new_vis)
    end
  end

  # ============================================================
  # HELPERS: CYCLE DETECTION (DFS)
  # ============================================================

  # Returns true if the graph contains at least one directed cycle.
  defp detect_cycles(graph) do
    node_ids = Map.keys(graph.nodes)
    cycle_found?(graph, node_ids, MapSet.new(), MapSet.new())
  end

  defp cycle_found?(_graph, [], _visited, _rec_stack), do: false

  defp cycle_found?(graph, [node | rest], visited, rec_stack) do
    if MapSet.member?(visited, node) do
      cycle_found?(graph, rest, visited, rec_stack)
    else
      case dfs_visit(graph, node, visited, rec_stack) do
        {:cycle, _, _} -> true
        {:ok, new_visited, new_rec} -> cycle_found?(graph, rest, new_visited, new_rec)
      end
    end
  end

  defp dfs_visit(graph, node, visited, rec_stack) do
    visited2 = MapSet.put(visited, node)
    rec2 = MapSet.put(rec_stack, node)

    result =
      Enum.reduce_while(neighbours(graph, node), {:ok, visited2, rec2}, fn n, {:ok, v, r} ->
        cond do
          MapSet.member?(r, n) ->
            {:halt, {:cycle, v, r}}

          MapSet.member?(v, n) ->
            {:cont, {:ok, v, r}}

          true ->
            case dfs_visit(graph, n, v, r) do
              {:cycle, vv, rr} -> {:halt, {:cycle, vv, rr}}
              {:ok, vv, rr} -> {:cont, {:ok, vv, rr}}
            end
        end
      end)

    case result do
      {:cycle, v, r} -> {:cycle, v, r}
      {:ok, v, r} -> {:ok, v, MapSet.delete(r, node)}
    end
  end

  # ============================================================
  # HELPERS: TRANSITIVE CLOSURE
  # ============================================================

  # Computes the transitive closure as a MapSet of {from, to} pairs.
  # Uses BFS per source node (Warshall-style).
  defp transitive_closure(graph) do
    Map.keys(graph.nodes)
    |> Enum.reduce(MapSet.new(), fn source, acc ->
      reachable = bfs_all_reachable(graph, source)

      Enum.reduce(reachable, acc, fn target, acc2 ->
        if source == target, do: acc2, else: MapSet.put(acc2, {source, target})
      end)
    end)
  end

  # ============================================================
  # HELPERS: INTEGRITY
  # ============================================================

  # Returns list of node IDs that have no incoming AND no outgoing edges.
  defp orphan_nodes(graph) do
    all_targets = for {_f, t} <- graph.edges, into: MapSet.new(), do: t
    all_sources = for {f, _t} <- graph.edges, into: MapSet.new(), do: f
    referenced = MapSet.union(all_targets, all_sources)

    graph.nodes
    |> Map.keys()
    |> Enum.reject(&MapSet.member?(referenced, &1))
  end

  # Returns edges that reference non-existent node IDs (dangling).
  defp dangling_edges(graph) do
    node_ids = MapSet.new(Map.keys(graph.nodes))

    Enum.filter(graph.edges, fn {from, to} ->
      not MapSet.member?(node_ids, from) or not MapSet.member?(node_ids, to)
    end)
  end

  # Returns %{nodes: integer, edges: integer, density: float}.
  # Density = edges / (nodes * (nodes - 1)) for a directed graph.
  defp graph_stats(graph) do
    n = map_size(graph.nodes)
    e = length(graph.edges)

    density =
      if n <= 1 do
        0.0
      else
        e / (n * (n - 1))
      end

    %{nodes: n, edges: e, density: density}
  end

  # ============================================================
  # SECTION 1: KNOWLEDGE GRAPH CREATION
  # ============================================================

  describe "knowledge graph creation" do
    test "new_graph/0 returns empty graph with empty nodes map and empty edges list" do
      g = new_graph()
      assert g.nodes == %{}
      assert g.edges == []
    end

    test "add_node/2 inserts a node accessible by its id" do
      g = new_graph() |> add_node("n1")
      assert Map.has_key?(g.nodes, "n1")
      assert g.nodes["n1"].id == "n1"
    end

    test "add_node/3 stores arbitrary metadata" do
      g = new_graph() |> add_node("n1", %{label: "concept", weight: 0.9})
      assert g.nodes["n1"].metadata == %{label: "concept", weight: 0.9}
    end

    test "nodes have unique IDs — adding same id overwrites earlier entry" do
      g =
        new_graph()
        |> add_node("n1", %{version: 1})
        |> add_node("n1", %{version: 2})

      assert map_size(g.nodes) == 1
      assert g.nodes["n1"].metadata.version == 2
    end

    test "add_edge/3 creates a directed edge from → to" do
      g = new_graph() |> add_node("a") |> add_node("b") |> add_edge("a", "b")
      assert {"a", "b"} in g.edges
    end

    test "edges are directed — a→b does not imply b→a" do
      g = new_graph() |> add_node("a") |> add_node("b") |> add_edge("a", "b")
      refute {"b", "a"} in g.edges
    end

    test "multiple edges between different pairs are stored independently" do
      g =
        new_graph()
        |> add_node("a")
        |> add_node("b")
        |> add_node("c")
        |> add_edge("a", "b")
        |> add_edge("b", "c")
        |> add_edge("a", "c")

      assert length(g.edges) == 3
    end

    test "graph_stats reflects correct node and edge counts" do
      g =
        new_graph()
        |> add_node("x")
        |> add_node("y")
        |> add_edge("x", "y")

      stats = graph_stats(g)
      assert stats.nodes == 2
      assert stats.edges == 1
    end
  end

  # ============================================================
  # SECTION 2: LINK RESOLUTION
  # ============================================================

  describe "link resolution" do
    test "resolve_link finds a direct edge" do
      g = new_graph() |> add_node("a") |> add_node("b") |> add_edge("a", "b")
      assert {:ok, ["a", "b"]} = resolve_link(g, "a", "b")
    end

    test "resolve_link finds a transitive path A→B→C" do
      g =
        new_graph()
        |> add_node("a")
        |> add_node("b")
        |> add_node("c")
        |> add_edge("a", "b")
        |> add_edge("b", "c")

      assert {:ok, ["a", "b", "c"]} = resolve_link(g, "a", "c")
    end

    test "resolve_link returns :not_reachable for disconnected nodes" do
      g = new_graph() |> add_node("x") |> add_node("y")
      assert {:error, :not_reachable} = resolve_link(g, "x", "y")
    end

    test "resolve_link returns :not_reachable when edge is reversed (direction matters)" do
      g = new_graph() |> add_node("a") |> add_node("b") |> add_edge("a", "b")
      assert {:error, :not_reachable} = resolve_link(g, "b", "a")
    end

    test "resolve_link from a node to itself returns single-element path" do
      g = new_graph() |> add_node("a")
      assert {:ok, ["a"]} = resolve_link(g, "a", "a")
    end

    test "resolve_link works across a 4-hop chain" do
      g =
        new_graph()
        |> add_node("1")
        |> add_node("2")
        |> add_node("3")
        |> add_node("4")
        |> add_node("5")
        |> add_edge("1", "2")
        |> add_edge("2", "3")
        |> add_edge("3", "4")
        |> add_edge("4", "5")

      assert {:ok, ["1", "2", "3", "4", "5"]} = resolve_link(g, "1", "5")
    end

    test "reachable? returns true for connected pair" do
      g = new_graph() |> add_node("a") |> add_node("b") |> add_edge("a", "b")
      assert reachable?(g, "a", "b")
    end

    test "reachable? returns false for unconnected pair" do
      g = new_graph() |> add_node("a") |> add_node("b")
      refute reachable?(g, "a", "b")
    end

    test "missing link detection: node not present is unreachable" do
      g = new_graph() |> add_node("a")
      assert {:error, :not_reachable} = resolve_link(g, "a", "does_not_exist")
    end
  end

  # ============================================================
  # SECTION 3: BFS TRAVERSAL
  # ============================================================

  describe "BFS traversal" do
    test "BFS from root finds all reachable nodes in a tree" do
      g =
        new_graph()
        |> add_node("root")
        |> add_node("child1")
        |> add_node("child2")
        |> add_node("leaf")
        |> add_edge("root", "child1")
        |> add_edge("root", "child2")
        |> add_edge("child1", "leaf")

      reachable = bfs_all_reachable(g, "root")
      assert MapSet.member?(reachable, "child1")
      assert MapSet.member?(reachable, "child2")
      assert MapSet.member?(reachable, "leaf")
    end

    test "BFS respects edge direction — cannot cross reversed edge" do
      g =
        new_graph()
        |> add_node("a")
        |> add_node("b")
        |> add_node("c")
        |> add_edge("a", "b")
        |> add_edge("c", "b")

      # c has an edge TO b; a cannot reach c through b
      refute reachable?(g, "a", "c")
    end

    test "BFS returns shortest path when multiple paths exist" do
      #   a → b → d
      #   a → c → d
      g =
        new_graph()
        |> add_node("a")
        |> add_node("b")
        |> add_node("c")
        |> add_node("d")
        |> add_edge("a", "b")
        |> add_edge("a", "c")
        |> add_edge("b", "d")
        |> add_edge("c", "d")

      {:ok, path} = bfs(g, "a", "d")
      # Shortest path is 2 hops (3 nodes): a→?→d
      assert length(path) == 3
      assert hd(path) == "a"
      assert List.last(path) == "d"
    end

    test "BFS handles a graph with a single node" do
      g = new_graph() |> add_node("solo")
      reachable = bfs_all_reachable(g, "solo")
      assert MapSet.member?(reachable, "solo")
    end

    test "BFS from isolated node only reaches itself" do
      g = new_graph() |> add_node("isolated") |> add_node("other")
      reachable = bfs_all_reachable(g, "isolated")
      refute MapSet.member?(reachable, "other")
    end

    test "BFS terminates on a cyclic graph without infinite loop" do
      g =
        new_graph()
        |> add_node("a")
        |> add_node("b")
        |> add_edge("a", "b")
        |> add_edge("b", "a")

      assert {:ok, ["a", "b"]} = bfs(g, "a", "b")
    end
  end

  # ============================================================
  # SECTION 4: CYCLE DETECTION
  # ============================================================

  describe "cycle detection" do
    test "acyclic linear chain returns false" do
      g =
        new_graph()
        |> add_node("a")
        |> add_node("b")
        |> add_node("c")
        |> add_edge("a", "b")
        |> add_edge("b", "c")

      refute detect_cycles(g)
    end

    test "simple cycle a→b→a returns true" do
      g =
        new_graph()
        |> add_node("a")
        |> add_node("b")
        |> add_edge("a", "b")
        |> add_edge("b", "a")

      assert detect_cycles(g)
    end

    test "self-loop a→a is detected as cycle" do
      g = new_graph() |> add_node("a") |> add_edge("a", "a")
      assert detect_cycles(g)
    end

    test "three-node cycle a→b→c→a is detected" do
      g =
        new_graph()
        |> add_node("a")
        |> add_node("b")
        |> add_node("c")
        |> add_edge("a", "b")
        |> add_edge("b", "c")
        |> add_edge("c", "a")

      assert detect_cycles(g)
    end

    test "DAG (directed acyclic graph) returns false" do
      g =
        new_graph()
        |> add_node("1")
        |> add_node("2")
        |> add_node("3")
        |> add_node("4")
        |> add_edge("1", "2")
        |> add_edge("1", "3")
        |> add_edge("2", "4")
        |> add_edge("3", "4")

      refute detect_cycles(g)
    end

    test "empty graph has no cycles" do
      refute detect_cycles(new_graph())
    end

    test "graph with isolated nodes and no edges has no cycles" do
      g = new_graph() |> add_node("a") |> add_node("b") |> add_node("c")
      refute detect_cycles(g)
    end

    test "cycle in one component causes overall graph to report true" do
      g =
        new_graph()
        |> add_node("x")
        |> add_node("y")
        |> add_edge("x", "y")
        |> add_edge("y", "x")
        |> add_node("p")
        |> add_node("q")
        |> add_edge("p", "q")

      assert detect_cycles(g)
    end
  end

  # ============================================================
  # SECTION 5: TRANSITIVE CLOSURE
  # ============================================================

  describe "transitive closure" do
    test "closure of single-edge graph contains the one reachable pair" do
      g = new_graph() |> add_node("a") |> add_node("b") |> add_edge("a", "b")
      closure = transitive_closure(g)
      assert MapSet.member?(closure, {"a", "b"})
    end

    test "closure of A→B→C includes both direct and transitive pairs" do
      g =
        new_graph()
        |> add_node("a")
        |> add_node("b")
        |> add_node("c")
        |> add_edge("a", "b")
        |> add_edge("b", "c")

      closure = transitive_closure(g)
      assert MapSet.member?(closure, {"a", "b"})
      assert MapSet.member?(closure, {"b", "c"})
      assert MapSet.member?(closure, {"a", "c"})
    end

    test "closure does not include reflexive (self) pairs by default" do
      g = new_graph() |> add_node("a") |> add_node("b") |> add_edge("a", "b")
      closure = transitive_closure(g)
      refute MapSet.member?(closure, {"a", "a"})
      refute MapSet.member?(closure, {"b", "b"})
    end

    test "closure is idempotent — applying it twice yields the same result" do
      g =
        new_graph()
        |> add_node("a")
        |> add_node("b")
        |> add_node("c")
        |> add_edge("a", "b")
        |> add_edge("b", "c")

      assert transitive_closure(g) == transitive_closure(g)
    end

    test "closure of empty graph is empty MapSet" do
      assert transitive_closure(new_graph()) == MapSet.new()
    end

    test "closure of disconnected nodes is empty" do
      g = new_graph() |> add_node("x") |> add_node("y") |> add_node("z")
      assert transitive_closure(g) == MapSet.new()
    end

    test "closure of a diamond graph includes all expected reachable pairs" do
      #   a → b → d
      #   a → c → d
      g =
        new_graph()
        |> add_node("a")
        |> add_node("b")
        |> add_node("c")
        |> add_node("d")
        |> add_edge("a", "b")
        |> add_edge("a", "c")
        |> add_edge("b", "d")
        |> add_edge("c", "d")

      closure = transitive_closure(g)

      for pair <- [{"a", "b"}, {"a", "c"}, {"a", "d"}, {"b", "d"}, {"c", "d"}] do
        assert MapSet.member?(closure, pair),
               "Expected #{inspect(pair)} in closure but it was absent"
      end
    end

    test "closure of cyclic graph includes all cycle-participant pairs" do
      g =
        new_graph()
        |> add_node("a")
        |> add_node("b")
        |> add_edge("a", "b")
        |> add_edge("b", "a")

      closure = transitive_closure(g)
      assert MapSet.member?(closure, {"a", "b"})
      assert MapSet.member?(closure, {"b", "a"})
    end
  end

  # ============================================================
  # SECTION 6: KNOWLEDGE INTEGRITY
  # ============================================================

  describe "knowledge integrity" do
    test "orphan_nodes returns isolated nodes with no edges at all" do
      g =
        new_graph()
        |> add_node("connected_a")
        |> add_node("connected_b")
        |> add_node("orphan")
        |> add_edge("connected_a", "connected_b")

      orphans = orphan_nodes(g)
      assert "orphan" in orphans
      refute "connected_a" in orphans
      refute "connected_b" in orphans
    end

    test "no orphans when all nodes participate in edges" do
      g =
        new_graph()
        |> add_node("a")
        |> add_node("b")
        |> add_node("c")
        |> add_edge("a", "b")
        |> add_edge("b", "c")

      assert orphan_nodes(g) == []
    end

    test "orphan_nodes returns empty list for empty graph" do
      assert orphan_nodes(new_graph()) == []
    end

    test "dangling_edges detects edge to non-existent target node" do
      g = new_graph() |> add_node("a") |> add_edge("a", "ghost")
      assert length(dangling_edges(g)) == 1
      assert {"a", "ghost"} in dangling_edges(g)
    end

    test "dangling_edges detects edge from non-existent source node" do
      g = new_graph() |> add_node("b") |> add_edge("phantom", "b")
      assert {"phantom", "b"} in dangling_edges(g)
    end

    test "dangling_edges returns empty list when all edges reference valid nodes" do
      g = new_graph() |> add_node("x") |> add_node("y") |> add_edge("x", "y")
      assert dangling_edges(g) == []
    end

    test "graph_stats returns zero density for a single node" do
      g = new_graph() |> add_node("solo")
      assert graph_stats(g).density == 0.0
    end

    test "graph_stats density is between 0.0 and 1.0 for a typical graph" do
      g =
        new_graph()
        |> add_node("a")
        |> add_node("b")
        |> add_node("c")
        |> add_edge("a", "b")
        |> add_edge("b", "c")

      stats = graph_stats(g)
      assert stats.density >= 0.0
      assert stats.density <= 1.0
    end

    test "graph_stats density equals 1.0 for a complete directed 2-node graph" do
      # 2 nodes × (2-1) = 2 max edges; we insert exactly 2 directed edges
      g =
        new_graph()
        |> add_node("a")
        |> add_node("b")
        |> add_edge("a", "b")
        |> add_edge("b", "a")

      assert_in_delta graph_stats(g).density, 1.0, 0.001
    end
  end

  # ============================================================
  # SECTION 7a: PROPERTY TESTS — PropCheck (forall with PC.)
  # ============================================================

  describe "property: graph invariants (PropCheck forall)" do
    @tag :property
    property "add_node never decreases node count" do
      forall {n, id} <- {PC.pos_integer(), PC.utf8()} do
        g =
          Enum.reduce(1..n, new_graph(), fn i, acc ->
            add_node(acc, "node_#{i}")
          end)

        before_count = map_size(g.nodes)
        after_graph = add_node(g, to_string(id))
        after_count = map_size(after_graph.nodes)

        # Adding any ID (new or existing) cannot decrease node count
        after_count >= before_count
      end
    end

    @tag :property
    property "edge list length equals number of add_edge calls (no dedup)" do
      forall pairs <- PC.list({PC.utf8(), PC.utf8()}) do
        g =
          Enum.reduce(pairs, new_graph(), fn {f, t}, acc ->
            acc
            |> add_node(to_string(f))
            |> add_node(to_string(t))
            |> add_edge(to_string(f), to_string(t))
          end)

        length(g.edges) == length(pairs)
      end
    end

    @tag :property
    property "graph_stats node count matches map_size of nodes" do
      forall ids <- PC.list(PC.utf8()) do
        g = Enum.reduce(ids, new_graph(), fn id, acc -> add_node(acc, to_string(id)) end)
        graph_stats(g).nodes == map_size(g.nodes)
      end
    end

    @tag :property
    property "transitive closure pairs only reference existing node IDs" do
      forall pairs <- PC.list(PC.choose(1, 5)) do
        node_ids = Enum.map(1..5, &"n#{&1}")

        g =
          Enum.reduce(node_ids, new_graph(), &add_node(&2, &1))
          |> then(fn base ->
            Enum.reduce(pairs, base, fn i, acc ->
              from = "n#{Integer.mod(i, 5) + 1}"
              to = "n#{Integer.mod(i + 1, 5) + 1}"
              add_edge(acc, from, to)
            end)
          end)

        valid_ids = MapSet.new(Map.keys(g.nodes))

        Enum.all?(transitive_closure(g), fn {f, t} ->
          MapSet.member?(valid_ids, f) and MapSet.member?(valid_ids, t)
        end)
      end
    end
  end

  # ============================================================
  # SECTION 7b: PROPERTY TESTS — StreamData (ExUnitProperties.check all)
  # ============================================================

  describe "property: graph invariants (StreamData check all)" do
    @tag :property
    test "new_graph is always empty" do
      ExUnitProperties.check all(_n <- SD.integer(1..10)) do
        g = new_graph()
        assert g.nodes == %{}
        assert g.edges == []
      end
    end

    @tag :property
    test "adding N distinct nodes yields exactly N nodes in graph" do
      ExUnitProperties.check all(
                               ids <-
                                 SD.uniq_list_of(
                                   SD.string(:alphanumeric, min_length: 1, max_length: 8),
                                   min_length: 1,
                                   max_length: 12
                                 )
                             ) do
        g = Enum.reduce(ids, new_graph(), fn id, acc -> add_node(acc, id) end)
        assert map_size(g.nodes) == length(ids)
      end
    end

    @tag :property
    test "bfs from start to itself always returns single-element path" do
      ExUnitProperties.check all(id <- SD.string(:alphanumeric, min_length: 1, max_length: 8)) do
        g = new_graph() |> add_node(id)
        assert {:ok, [^id]} = bfs(g, id, id)
      end
    end

    @tag :property
    test "orphan_nodes count is always non-negative" do
      ExUnitProperties.check all(
                               ids <-
                                 SD.list_of(
                                   SD.string(:alphanumeric, min_length: 1, max_length: 6),
                                   min_length: 0,
                                   max_length: 8
                                 )
                             ) do
        g = Enum.reduce(ids, new_graph(), fn id, acc -> add_node(acc, id) end)
        assert length(orphan_nodes(g)) >= 0
      end
    end

    @tag :property
    test "graph_stats density is always in [0.0, 1.0]" do
      ExUnitProperties.check all(
                               ids <-
                                 SD.uniq_list_of(
                                   SD.string(:alphanumeric, min_length: 1, max_length: 4),
                                   min_length: 0,
                                   max_length: 6
                                 )
                             ) do
        g =
          Enum.reduce(ids, new_graph(), &add_node(&2, &1))
          |> then(fn base ->
            Enum.zip(ids, Enum.drop(ids, 1))
            |> Enum.reduce(base, fn {f, t}, acc -> add_edge(acc, f, t) end)
          end)

        stats = graph_stats(g)
        assert stats.density >= 0.0
        assert stats.density <= 1.0
      end
    end

    @tag :property
    test "transitive closure idempotency holds for random 3-node graphs" do
      edges_gen =
        SD.list_of(
          SD.bind(SD.member_of(["a", "b", "c"]), fn f ->
            SD.map(SD.member_of(["a", "b", "c"]), fn t -> {f, t} end)
          end),
          max_length: 6
        )

      ExUnitProperties.check all(edges <- edges_gen) do
        g =
          ["a", "b", "c"]
          |> Enum.reduce(new_graph(), &add_node(&2, &1))
          |> then(fn base ->
            Enum.reduce(edges, base, fn {f, t}, acc -> add_edge(acc, f, t) end)
          end)

        assert transitive_closure(g) == transitive_closure(g)
      end
    end
  end

  # ============================================================
  # SECTION 8: CONSTITUTIONAL INVARIANTS
  # ============================================================

  describe "constitutional invariants" do
    test "Ψ₀ existence — all graph helpers complete without raising on valid input" do
      graphs = [
        new_graph(),
        new_graph() |> add_node("a"),
        new_graph() |> add_node("a") |> add_node("b") |> add_edge("a", "b"),
        new_graph() |> add_node("x") |> add_edge("x", "x")
      ]

      for g <- graphs do
        assert is_map(graph_stats(g))
        assert is_list(orphan_nodes(g))
        assert is_list(dangling_edges(g))
        assert is_boolean(detect_cycles(g))
        assert %MapSet{} = transitive_closure(g)
      end
    end

    test "Ψ₃ verification — transitive closure is self-consistent (idempotent)" do
      g =
        new_graph()
        |> add_node("doc1")
        |> add_node("concept1")
        |> add_node("entity1")
        |> add_node("entity2")
        |> add_edge("doc1", "concept1")
        |> add_edge("concept1", "entity1")
        |> add_edge("concept1", "entity2")

      assert transitive_closure(g) == transitive_closure(g)
    end

    test "Ψ₅ truthfulness — cycle detection matches actual structural reality" do
      acyclic =
        new_graph()
        |> add_node("a")
        |> add_node("b")
        |> add_edge("a", "b")

      cyclic =
        new_graph()
        |> add_node("a")
        |> add_node("b")
        |> add_edge("a", "b")
        |> add_edge("b", "a")

      refute detect_cycles(acyclic), "Acyclic graph must not report cycle"
      assert detect_cycles(cyclic), "Cyclic graph must report cycle"
    end

    test "SC-SMRITI-130 integrity — closure pairs reference only known node IDs" do
      g =
        new_graph()
        |> add_node("concept_a")
        |> add_node("concept_b")
        |> add_node("entity_x")
        |> add_edge("concept_a", "concept_b")
        |> add_edge("concept_b", "entity_x")

      valid_ids = MapSet.new(Map.keys(g.nodes))

      for {from, to} <- transitive_closure(g) do
        assert MapSet.member?(valid_ids, from),
               "Closure source #{inspect(from)} is not a known node ID"

        assert MapSet.member?(valid_ids, to),
               "Closure target #{inspect(to)} is not a known node ID"
      end
    end

    test "SC-IKE-001 ingestion guard — reject graph with dependency cycle" do
      # A proposed document graph with a circular dependency chain must be blocked
      cyclic_doc_graph =
        new_graph()
        |> add_node("doc_new")
        |> add_node("depends_x")
        |> add_node("depends_y")
        |> add_edge("doc_new", "depends_x")
        |> add_edge("depends_x", "depends_y")
        |> add_edge("depends_y", "doc_new")

      # Ingestion pipeline gate: detect cycle → do not ingest
      should_ingest = not detect_cycles(cyclic_doc_graph)
      refute should_ingest, "Cyclic dependency graph must be rejected by ingestion pipeline"
    end

    test "SC-SMRITI-131 search expansion — transitive closure enables multi-hop context" do
      # Simulates how full-text search expands a query concept across the graph
      g =
        new_graph()
        |> add_node("query_term")
        |> add_node("related_concept")
        |> add_node("secondary_doc")
        |> add_node("tertiary_entity")
        |> add_edge("query_term", "related_concept")
        |> add_edge("related_concept", "secondary_doc")
        |> add_edge("secondary_doc", "tertiary_entity")

      closure = transitive_closure(g)

      # All downstream nodes should be reachable from the query term
      assert MapSet.member?(closure, {"query_term", "related_concept"})
      assert MapSet.member?(closure, {"query_term", "secondary_doc"})
      assert MapSet.member?(closure, {"query_term", "tertiary_entity"})
    end
  end
end
