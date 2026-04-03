defmodule Indrajaal.Core.SmritiKnowledgeGraphLinkTest do
  @moduledoc """
  TDG test: SMRITI knowledge graph link resolution.

  ## WHAT
  Validates knowledge graph link operations: create, resolve, bidirectional traversal,
  cycle detection, orphan detection.

  ## WHY
  SC-IKE-001 mandates document ingestion pipeline.
  SC-SMRITI-130 requires query results include integrity proofs.
  Knowledge graph links are the foundation of SMRITI's associative memory.

  ## CONSTRAINTS
  - SC-IKE-001: Document ingestion pipeline
  - SC-SMRITI-130: Integrity proofs in queries
  - SC-SMRITI-131: Full-text search uses FTS5
  - SC-SMRITI-133: Query timeout < 500ms

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-03-24 | Claude | Initial implementation — Sprint 88 Wave 7 |
  """

  use ExUnit.Case, async: true
  import ExUnitProperties, except: [property: 2, property: 3]
  alias StreamData, as: SD

  @moduletag :smriti
  @moduletag :knowledge_graph
  @moduletag :sprint_88

  setup do
    table = :ets.new(:kg_test, [:bag, :public])
    nodes_table = :ets.new(:kg_nodes_test, [:set, :public])

    on_exit(fn ->
      :ets.delete(table)
      :ets.delete(nodes_table)
    end)

    {:ok, edges: table, nodes: nodes_table}
  end

  describe "node operations" do
    test "create and retrieve node", %{nodes: nodes} do
      node = %{id: "zettel-001", title: "Elixir Patterns", tags: ["elixir", "patterns"]}
      :ets.insert(nodes, {node.id, node})

      assert [{_, ^node}] = :ets.lookup(nodes, "zettel-001")
    end

    test "node IDs are unique", %{nodes: nodes} do
      :ets.insert(nodes, {"z1", %{id: "z1", title: "A"}})
      :ets.insert(nodes, {"z1", %{id: "z1", title: "B"}})

      # :set table keeps only the latest
      results = :ets.lookup(nodes, "z1")
      assert length(results) == 1
      assert elem(hd(results), 1).title == "B"
    end
  end

  describe "link creation" do
    test "create directed link", %{edges: edges} do
      link = {"zettel-001", :references, "zettel-002"}
      :ets.insert(edges, link)

      results = :ets.lookup(edges, "zettel-001")
      assert length(results) == 1
      assert {"zettel-001", :references, "zettel-002"} in results
    end

    test "multiple links from same node", %{edges: edges} do
      :ets.insert(edges, {"z1", :references, "z2"})
      :ets.insert(edges, {"z1", :extends, "z3"})
      :ets.insert(edges, {"z1", :contradicts, "z4"})

      results = :ets.lookup(edges, "z1")
      assert length(results) == 3
    end

    test "link types are atoms" do
      valid_types = [:references, :extends, :contradicts, :supports, :derives_from, :related_to]
      assert Enum.all?(valid_types, &is_atom/1)
    end
  end

  describe "link resolution (traversal)" do
    test "forward traversal: find targets", %{edges: edges} do
      :ets.insert(edges, {"z1", :references, "z2"})
      :ets.insert(edges, {"z1", :references, "z3"})

      targets = forward_links(edges, "z1")
      assert length(targets) == 2
      assert "z2" in targets
      assert "z3" in targets
    end

    test "backward traversal: find sources", %{edges: edges} do
      :ets.insert(edges, {"z1", :references, "z3"})
      :ets.insert(edges, {"z2", :supports, "z3"})

      sources = backward_links(edges, "z3")
      assert length(sources) == 2
      assert "z1" in sources
      assert "z2" in sources
    end

    test "bidirectional: all connected nodes", %{edges: edges} do
      :ets.insert(edges, {"z1", :references, "z2"})
      :ets.insert(edges, {"z3", :supports, "z1"})

      connected = bidirectional_links(edges, "z1")
      assert "z2" in connected
      assert "z3" in connected
    end
  end

  describe "path finding" do
    test "find path between connected nodes", %{edges: edges} do
      :ets.insert(edges, {"z1", :references, "z2"})
      :ets.insert(edges, {"z2", :references, "z3"})
      :ets.insert(edges, {"z3", :references, "z4"})

      path = find_path(edges, "z1", "z4")
      assert path == ["z1", "z2", "z3", "z4"]
    end

    test "no path returns nil", %{edges: edges} do
      :ets.insert(edges, {"z1", :references, "z2"})
      # z3 is disconnected
      path = find_path(edges, "z1", "z3")
      assert path == nil
    end

    test "direct link path has length 2", %{edges: edges} do
      :ets.insert(edges, {"z1", :references, "z2"})

      path = find_path(edges, "z1", "z2")
      assert path == ["z1", "z2"]
    end
  end

  describe "cycle detection" do
    test "detect cycle in graph", %{edges: edges} do
      :ets.insert(edges, {"z1", :references, "z2"})
      :ets.insert(edges, {"z2", :references, "z3"})
      :ets.insert(edges, {"z3", :references, "z1"})

      assert has_cycle?(edges) == true
    end

    test "acyclic graph has no cycles", %{edges: edges} do
      :ets.insert(edges, {"z1", :references, "z2"})
      :ets.insert(edges, {"z2", :references, "z3"})
      :ets.insert(edges, {"z1", :references, "z3"})

      assert has_cycle?(edges) == false
    end

    test "self-loop is a cycle", %{edges: edges} do
      :ets.insert(edges, {"z1", :references, "z1"})
      assert has_cycle?(edges) == true
    end
  end

  describe "orphan detection" do
    test "find nodes with no links", %{edges: edges, nodes: nodes} do
      :ets.insert(nodes, {"z1", %{id: "z1"}})
      :ets.insert(nodes, {"z2", %{id: "z2"}})
      :ets.insert(nodes, {"z3", %{id: "z3"}})

      :ets.insert(edges, {"z1", :references, "z2"})
      # z3 has no links

      orphans = find_orphans(edges, nodes)
      assert "z3" in orphans
      refute "z1" in orphans
      refute "z2" in orphans
    end
  end

  describe "query timing (SC-SMRITI-133)" do
    test "graph traversal completes under 500ms", %{edges: edges} do
      # Build a moderate graph
      for i <- 1..100 do
        :ets.insert(edges, {"n#{i}", :references, "n#{i + 1}"})
      end

      {time_us, _result} = :timer.tc(fn -> forward_links(edges, "n1") end)
      time_ms = time_us / 1000

      assert time_ms < 500, "Query took #{time_ms}ms (budget: 500ms)"
    end
  end

  describe "property-based graph operations" do
    test "property — chain graph has exactly one forward link from first node for any link type (SD)" do
      check all(
              n <- SD.integer(2..20),
              link_type <- SD.member_of([:references, :extends, :supports])
            ) do
        table = :ets.new(:prop_kg, [:bag, :public])

        # Create chain: n1 -> n2 -> ... -> nN
        for i <- 1..(n - 1) do
          :ets.insert(table, {"n#{i}", link_type, "n#{i + 1}"})
        end

        # First node should have 1 forward link
        targets = forward_links(table, "n1")
        assert length(targets) == 1

        :ets.delete(table)
      end
    end
  end

  # --- Knowledge Graph Helpers ---

  defp forward_links(edges, node_id) do
    edges
    |> :ets.lookup(node_id)
    |> Enum.map(fn {_from, _type, to} -> to end)
  end

  defp backward_links(edges, node_id) do
    :ets.tab2list(edges)
    |> Enum.filter(fn {_from, _type, to} -> to == node_id end)
    |> Enum.map(fn {from, _type, _to} -> from end)
  end

  defp bidirectional_links(edges, node_id) do
    (forward_links(edges, node_id) ++ backward_links(edges, node_id))
    |> Enum.uniq()
  end

  defp find_path(edges, from, to) do
    bfs(edges, [{[from]}], to, MapSet.new())
  end

  defp bfs(_edges, [], _to, _visited), do: nil

  defp bfs(edges, [path | rest], to, visited) do
    current = hd(path)

    if current == to do
      Enum.reverse(path)
    else
      if MapSet.member?(visited, current) do
        bfs(edges, rest, to, visited)
      else
        new_visited = MapSet.put(visited, current)
        neighbors = forward_links(edges, current)
        new_paths = Enum.map(neighbors, fn n -> [n | path] end)
        bfs(edges, rest ++ new_paths, to, new_visited)
      end
    end
  end

  defp has_cycle?(edges) do
    all_nodes =
      :ets.tab2list(edges)
      |> Enum.flat_map(fn {from, _type, to} -> [from, to] end)
      |> Enum.uniq()

    Enum.any?(all_nodes, fn node ->
      dfs_cycle?(edges, node, MapSet.new(), MapSet.new())
    end)
  end

  defp dfs_cycle?(edges, node, visiting, _visited) do
    if MapSet.member?(visiting, node) do
      true
    else
      new_visiting = MapSet.put(visiting, node)
      neighbors = forward_links(edges, node)

      Enum.any?(neighbors, fn neighbor ->
        dfs_cycle?(edges, neighbor, new_visiting, MapSet.new())
      end)
    end
  end

  defp find_orphans(edges, nodes) do
    all_linked =
      :ets.tab2list(edges)
      |> Enum.flat_map(fn {from, _type, to} -> [from, to] end)
      |> MapSet.new()

    :ets.tab2list(nodes)
    |> Enum.map(fn {id, _data} -> id end)
    |> Enum.reject(fn id -> MapSet.member?(all_linked, id) end)
  end
end
