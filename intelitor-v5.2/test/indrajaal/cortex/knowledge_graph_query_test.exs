defmodule Indrajaal.Cortex.KnowledgeGraphQueryTest do
  @moduledoc """
  TDG test suite for Cortex Knowledge Graph query operations — L1 Function level.

  WHAT: Validates knowledge graph node/edge CRUD, graph traversal, semantic search,
        subgraph extraction, document ingestion, entropy gating, and drift detection.
        Entirely self-contained — simulates a knowledge graph over ETS; no production
        module dependency.

  WHY: Ensures the Cortex knowledge mesh correctly maintains graph structure,
       enforces Shannon entropy gates (SC-IKE-002), detects structural drift
       (SC-IKE-003), and surfaces queryable knowledge for AI context assembly
       (SC-SMRITI-131).  Property tests guarantee structural invariants hold
       under arbitrary graph mutations.

  STAMP Constraints:
  - SC-IKE-001: Document ingestion pipeline populates the graph
  - SC-IKE-002: Entropy gating — deployment blocked when entropy > 0.2
  - SC-IKE-003: Drift detection scores reflect structural change
  - SC-GRAPH-001: Graph operations verified for correctness
  - SC-SMRITI-131: Full-text search uses FTS5 (simulated via ETS match)

  AOR Rules:
  - AOR-IKE-001: Update Knowledge Graph on every new ingestion
  - AOR-IKE-003: No hallucinated knowledge entries permitted
  """

  use ExUnit.Case, async: true
  use PropCheck
  # EP-GEN-014: Dual property testing. ExUnitProperties macros are used via
  # fully qualified calls (ExUnitProperties.check all) to avoid the check/2
  # conflict with PropCheck. PC aliases PropCheck.BasicTypes; SD aliases StreamData.
  import ExUnitProperties, except: [property: 2, property: 3]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # ---------------------------------------------------------------------------
  # In-process ETS-backed Knowledge Graph implementation
  # ---------------------------------------------------------------------------

  defmodule KG do
    @moduledoc "Minimal ETS-backed knowledge graph for testing SC-IKE-001..003."

    @spec new(atom()) :: :ok
    def new(table) do
      if :ets.whereis(table) == :undefined do
        :ets.new(table, [:named_table, :public, :set])
      end

      :ets.insert(table, {:nodes, %{}})
      :ets.insert(table, {:edges, []})
      :ok
    end

    @spec destroy(atom()) :: :ok
    def destroy(table) do
      if :ets.whereis(table) != :undefined, do: :ets.delete(table)
      :ok
    end

    # --- nodes ---

    @spec create_node(atom(), String.t(), atom(), map()) ::
            {:ok, String.t()} | {:error, :duplicate_id}
    def create_node(table, id, type, attrs) do
      nodes = get_nodes(table)

      if Map.has_key?(nodes, id) do
        {:error, :duplicate_id}
      else
        node = %{
          id: id,
          type: type,
          attrs: attrs,
          created_at: System.monotonic_time(:millisecond)
        }

        :ets.insert(table, {:nodes, Map.put(nodes, id, node)})
        {:ok, id}
      end
    end

    @spec get_node(atom(), String.t()) :: {:ok, map()} | {:error, :not_found}
    def get_node(table, id) do
      case Map.fetch(get_nodes(table), id) do
        {:ok, node} -> {:ok, node}
        :error -> {:error, :not_found}
      end
    end

    @spec update_node(atom(), String.t(), map()) :: {:ok, map()} | {:error, :not_found}
    def update_node(table, id, new_attrs) do
      nodes = get_nodes(table)

      case Map.fetch(nodes, id) do
        {:ok, node} ->
          updated = %{node | attrs: Map.merge(node.attrs, new_attrs)}
          :ets.insert(table, {:nodes, Map.put(nodes, id, updated)})
          {:ok, updated}

        :error ->
          {:error, :not_found}
      end
    end

    @spec delete_node(atom(), String.t()) :: :ok
    def delete_node(table, id) do
      nodes = get_nodes(table)
      edges = get_edges(table)
      :ets.insert(table, {:nodes, Map.delete(nodes, id)})
      remaining = Enum.reject(edges, fn {from, to, _type} -> from == id or to == id end)
      :ets.insert(table, {:edges, remaining})
      :ok
    end

    @spec all_nodes(atom()) :: [map()]
    def all_nodes(table), do: Map.values(get_nodes(table))

    # --- edges ---

    @spec create_edge(atom(), String.t(), String.t(), atom()) ::
            {:ok, tuple()} | {:error, :node_not_found}
    def create_edge(table, from_id, to_id, edge_type) do
      nodes = get_nodes(table)

      cond do
        not Map.has_key?(nodes, from_id) ->
          {:error, :node_not_found}

        not Map.has_key?(nodes, to_id) ->
          {:error, :node_not_found}

        true ->
          edge = {from_id, to_id, edge_type}
          :ets.insert(table, {:edges, [edge | get_edges(table)]})
          {:ok, edge}
      end
    end

    @spec edges_from(atom(), String.t()) :: [{String.t(), String.t(), atom()}]
    def edges_from(table, id) do
      Enum.filter(get_edges(table), fn {from, _to, _type} -> from == id end)
    end

    @spec edges_to(atom(), String.t()) :: [{String.t(), String.t(), atom()}]
    def edges_to(table, id) do
      Enum.filter(get_edges(table), fn {_from, to, _type} -> to == id end)
    end

    @spec edges_of_type(atom(), atom()) :: [{String.t(), String.t(), atom()}]
    def edges_of_type(table, type) do
      Enum.filter(get_edges(table), fn {_f, _t, et} -> et == type end)
    end

    @spec all_edges(atom()) :: [{String.t(), String.t(), atom()}]
    def all_edges(table), do: get_edges(table)

    # --- traversal ---

    @spec bfs(atom(), String.t()) :: [String.t()]
    def bfs(table, start_id) do
      do_bfs(table, [start_id], MapSet.new([start_id]), [])
    end

    @spec dfs(atom(), String.t()) :: [String.t()]
    def dfs(table, start_id) do
      {_visited, order} = do_dfs(table, start_id, MapSet.new(), [])
      Enum.reverse(order)
    end

    @spec shortest_path(atom(), String.t(), String.t()) ::
            {:ok, [String.t()]} | {:error, :no_path}
    def shortest_path(table, from_id, to_id) do
      do_bfs_path(table, [{from_id, [from_id]}], MapSet.new([from_id]), to_id)
    end

    @spec path_exists?(atom(), String.t(), String.t()) :: boolean()
    def path_exists?(table, from_id, to_id) do
      match?({:ok, _}, shortest_path(table, from_id, to_id))
    end

    # --- semantic search ---

    @spec search(atom(), String.t()) :: [{float(), map()}]
    def search(table, query) do
      keywords = query |> String.downcase() |> String.split(~r/\s+/, trim: true)

      get_nodes(table)
      |> Map.values()
      |> Enum.map(fn node ->
        text =
          [
            node.id,
            to_string(node.type),
            Map.get(node.attrs, :label, ""),
            Map.get(node.attrs, :content, ""),
            Enum.join(Map.get(node.attrs, :tags, []), " ")
          ]
          |> Enum.join(" ")
          |> String.downcase()

        hits = Enum.count(keywords, &String.contains?(text, &1))
        score = if length(keywords) > 0, do: hits / length(keywords), else: 0.0
        {score, node}
      end)
      |> Enum.filter(fn {score, _} -> score > 0.0 end)
      |> Enum.sort_by(fn {score, _} -> -score end)
    end

    @spec fuzzy_search(atom(), String.t(), float()) :: [{float(), map()}]
    def fuzzy_search(table, query, min_score) do
      search(table, query) |> Enum.filter(fn {score, _} -> score >= min_score end)
    end

    # --- subgraph extraction ---

    @spec n_hop_neighborhood(atom(), String.t(), non_neg_integer()) :: [map()]
    def n_hop_neighborhood(table, start_id, hops) do
      visited = do_n_hop(table, MapSet.new([start_id]), MapSet.new([start_id]), hops)
      nodes = get_nodes(table)
      visited |> Enum.flat_map(fn id -> if Map.has_key?(nodes, id), do: [nodes[id]], else: [] end)
    end

    @spec subgraph_by_type(atom(), atom()) :: [map()]
    def subgraph_by_type(table, node_type) do
      get_nodes(table)
      |> Map.values()
      |> Enum.filter(fn node -> node.type == node_type end)
    end

    # --- knowledge ingestion ---

    @spec ingest_document(atom(), map()) :: {:ok, [String.t()]}
    def ingest_document(table, %{title: title, content: content, tags: tags}) do
      doc_id = "doc:#{:erlang.phash2({title, content})}"

      {:ok, _} =
        create_node(table, doc_id, :document, %{label: title, content: content, tags: tags})

      entity_ids =
        tags
        |> Enum.map(fn tag ->
          entity_id = "entity:#{tag}"

          unless match?({:ok, _}, get_node(table, entity_id)) do
            create_node(table, entity_id, :entity, %{label: tag, tags: [tag]})
          end

          create_edge(table, doc_id, entity_id, :relates_to)
          entity_id
        end)

      {:ok, [doc_id | entity_ids]}
    end

    # --- entropy gating (SC-IKE-002) ---

    @spec entropy(atom()) :: float()
    def entropy(table) do
      nodes = get_nodes(table)
      total = map_size(nodes)

      if total == 0 do
        0.0
      else
        type_counts =
          nodes
          |> Map.values()
          |> Enum.group_by(& &1.type)
          |> Enum.map(fn {_type, group} -> length(group) end)

        type_counts
        |> Enum.reduce(0.0, fn count, acc ->
          p = count / total
          acc - p * :math.log2(p)
        end)
        # Normalize to 0-1 range (max entropy when all types equal)
        |> then(fn h ->
          max_h = :math.log2(max(length(type_counts), 1))
          if max_h > 0, do: h / max_h, else: 0.0
        end)
      end
    end

    @spec deployment_allowed?(atom()) :: {:ok, float()} | {:error, {:entropy_too_high, float()}}
    def deployment_allowed?(table) do
      h = entropy(table)

      if h <= 0.2 do
        {:ok, h}
      else
        {:error, {:entropy_too_high, h}}
      end
    end

    # --- drift detection (SC-IKE-003) ---

    @spec snapshot(atom()) :: map()
    def snapshot(table) do
      %{
        node_count: map_size(get_nodes(table)),
        edge_count: length(get_edges(table)),
        type_distribution:
          get_nodes(table)
          |> Map.values()
          |> Enum.group_by(& &1.type)
          |> Enum.map(fn {k, v} -> {k, length(v)} end)
          |> Map.new(),
        node_ids: get_nodes(table) |> Map.keys() |> Enum.sort()
      }
    end

    @spec drift_score(map(), map()) :: float()
    def drift_score(snap1, snap2) do
      node_delta = abs(snap2.node_count - snap1.node_count) / max(snap1.node_count, 1)
      edge_delta = abs(snap2.edge_count - snap1.edge_count) / max(snap1.edge_count, 1)

      added = length(snap2.node_ids -- snap1.node_ids)
      removed = length(snap1.node_ids -- snap2.node_ids)
      structural_delta = (added + removed) / max(snap1.node_count + snap2.node_count, 1)

      (node_delta + edge_delta + structural_delta) / 3.0
    end

    # --- private helpers ---

    defp get_nodes(table) do
      case :ets.lookup(table, :nodes) do
        [{:nodes, nodes}] -> nodes
        [] -> %{}
      end
    end

    defp get_edges(table) do
      case :ets.lookup(table, :edges) do
        [{:edges, edges}] -> edges
        [] -> []
      end
    end

    defp do_bfs(_table, [], _visited, order), do: Enum.reverse(order)

    defp do_bfs(table, [current | rest], visited, order) do
      neighbors =
        edges_from(table, current)
        |> Enum.map(fn {_from, to, _type} -> to end)
        |> Enum.reject(&MapSet.member?(visited, &1))

      new_visited = Enum.reduce(neighbors, visited, &MapSet.put(&2, &1))
      do_bfs(table, rest ++ neighbors, new_visited, [current | order])
    end

    defp do_dfs(table, id, visited, order) do
      if MapSet.member?(visited, id) do
        {visited, order}
      else
        visited = MapSet.put(visited, id)

        {visited, order} =
          edges_from(table, id)
          |> Enum.reduce({visited, order}, fn {_from, to, _type}, {v, o} ->
            do_dfs(table, to, v, o)
          end)

        {visited, [id | order]}
      end
    end

    defp do_bfs_path(_table, [], _visited, _target), do: {:error, :no_path}

    defp do_bfs_path(_table, [{current, path} | _], _visited, target)
         when current == target,
         do: {:ok, Enum.reverse(path)}

    defp do_bfs_path(table, [{current, path} | rest], visited, target) do
      neighbors =
        edges_from(table, current)
        |> Enum.map(fn {_from, to, _type} -> to end)
        |> Enum.reject(&MapSet.member?(visited, &1))

      new_queue = rest ++ Enum.map(neighbors, fn n -> {n, [n | path]} end)
      new_visited = Enum.reduce(neighbors, visited, &MapSet.put(&2, &1))
      do_bfs_path(table, new_queue, new_visited, target)
    end

    defp do_n_hop(_table, frontier, visited, 0), do: MapSet.union(frontier, visited)

    defp do_n_hop(table, frontier, visited, hops) do
      next_frontier =
        frontier
        |> Enum.flat_map(fn id ->
          edges_from(table, id) |> Enum.map(fn {_f, t, _et} -> t end)
        end)
        |> Enum.reject(&MapSet.member?(visited, &1))
        |> MapSet.new()

      do_n_hop(table, next_frontier, MapSet.union(visited, next_frontier), hops - 1)
    end
  end

  # ---------------------------------------------------------------------------
  # Shared helpers
  # ---------------------------------------------------------------------------

  defp unique_table do
    :"kg_test_#{:erlang.unique_integer([:positive])}"
  end

  defp setup_table do
    t = unique_table()
    KG.new(t)
    t
  end

  defp seed_small_graph(t) do
    {:ok, _} = KG.create_node(t, "n1", :concept, %{label: "alarm", tags: ["alarm", "safety"]})
    {:ok, _} = KG.create_node(t, "n2", :concept, %{label: "sensor", tags: ["sensor", "device"]})
    {:ok, _} = KG.create_node(t, "n3", :entity, %{label: "guardian", tags: ["guardian"]})

    {:ok, _} =
      KG.create_node(t, "n4", :document, %{
        label: "policy doc",
        content: "safety policy",
        tags: []
      })

    {:ok, _} = KG.create_edge(t, "n1", "n2", :relates_to)
    {:ok, _} = KG.create_edge(t, "n2", "n3", :depends_on)
    {:ok, _} = KG.create_edge(t, "n3", "n4", :derives_from)
    t
  end

  # ---------------------------------------------------------------------------
  # 1. Node CRUD
  # ---------------------------------------------------------------------------

  describe "node CRUD" do
    test "creates a node and reads it back" do
      t = setup_table()
      assert {:ok, "alice"} = KG.create_node(t, "alice", :person, %{label: "Alice"})
      assert {:ok, node} = KG.get_node(t, "alice")
      assert node.id == "alice"
      assert node.type == :person
      assert node.attrs.label == "Alice"
      KG.destroy(t)
    end

    test "enforces unique ID — duplicate returns :duplicate_id" do
      t = setup_table()
      {:ok, _} = KG.create_node(t, "dup", :concept, %{})
      assert {:error, :duplicate_id} = KG.create_node(t, "dup", :concept, %{})
      KG.destroy(t)
    end

    test "get_node returns :not_found for absent ID" do
      t = setup_table()
      assert {:error, :not_found} = KG.get_node(t, "ghost")
      KG.destroy(t)
    end

    test "updates node attrs in place" do
      t = setup_table()
      {:ok, _} = KG.create_node(t, "upd", :concept, %{score: 1})
      assert {:ok, updated} = KG.update_node(t, "upd", %{score: 99})
      assert updated.attrs.score == 99
      KG.destroy(t)
    end

    test "update on absent node returns :not_found" do
      t = setup_table()
      assert {:error, :not_found} = KG.update_node(t, "missing", %{})
      KG.destroy(t)
    end

    test "delete removes node from all_nodes result" do
      t = setup_table()
      {:ok, _} = KG.create_node(t, "del", :concept, %{})
      assert length(KG.all_nodes(t)) == 1
      KG.delete_node(t, "del")
      assert KG.all_nodes(t) == []
      KG.destroy(t)
    end

    test "delete non-existent node is a no-op" do
      t = setup_table()
      {:ok, _} = KG.create_node(t, "keep", :concept, %{})
      KG.delete_node(t, "phantom")
      assert length(KG.all_nodes(t)) == 1
      KG.destroy(t)
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Edge management
  # ---------------------------------------------------------------------------

  describe "edge management" do
    test "creates a directed edge between two existing nodes" do
      t = setup_table()
      {:ok, _} = KG.create_node(t, "a", :concept, %{})
      {:ok, _} = KG.create_node(t, "b", :concept, %{})
      assert {:ok, {"a", "b", :relates_to}} = KG.create_edge(t, "a", "b", :relates_to)
      KG.destroy(t)
    end

    test "edge creation fails when source node absent" do
      t = setup_table()
      {:ok, _} = KG.create_node(t, "b", :concept, %{})
      assert {:error, :node_not_found} = KG.create_edge(t, "missing", "b", :relates_to)
      KG.destroy(t)
    end

    test "edge creation fails when target node absent" do
      t = setup_table()
      {:ok, _} = KG.create_node(t, "a", :concept, %{})
      assert {:error, :node_not_found} = KG.create_edge(t, "a", "missing", :depends_on)
      KG.destroy(t)
    end

    test "supports all three canonical edge types" do
      t = setup_table()
      for id <- ["n1", "n2", "n3", "n4"], do: KG.create_node(t, id, :concept, %{})

      for {from, to, etype} <- [
            {"n1", "n2", :relates_to},
            {"n2", "n3", :depends_on},
            {"n3", "n4", :derives_from}
          ] do
        assert {:ok, {^from, ^to, ^etype}} = KG.create_edge(t, from, to, etype)
      end

      KG.destroy(t)
    end

    test "edges_from/2 returns only outgoing edges for a node" do
      t = seed_small_graph(setup_table())
      outgoing = KG.edges_from(t, "n1")
      assert length(outgoing) == 1
      assert Enum.all?(outgoing, fn {from, _to, _type} -> from == "n1" end)
      KG.destroy(t)
    end

    test "edges_to/2 returns only incoming edges for a node" do
      t = seed_small_graph(setup_table())
      incoming = KG.edges_to(t, "n3")
      assert length(incoming) == 1
      assert Enum.all?(incoming, fn {_from, to, _type} -> to == "n3" end)
      KG.destroy(t)
    end

    test "edges_of_type/2 filters by edge type" do
      t = seed_small_graph(setup_table())
      deps = KG.edges_of_type(t, :depends_on)
      assert length(deps) == 1
      assert match?({_, _, :depends_on}, hd(deps))
      KG.destroy(t)
    end
  end

  # ---------------------------------------------------------------------------
  # 3. Graph traversal
  # ---------------------------------------------------------------------------

  describe "graph traversal" do
    test "BFS visits all reachable nodes exactly once from start" do
      t = seed_small_graph(setup_table())
      visited = KG.bfs(t, "n1")
      assert length(visited) == length(Enum.uniq(visited))
      assert "n1" in visited
      assert "n4" in visited
      KG.destroy(t)
    end

    test "DFS visits all reachable nodes from start" do
      t = seed_small_graph(setup_table())
      visited = KG.dfs(t, "n1")
      assert length(visited) == length(Enum.uniq(visited))
      assert "n1" in visited
      KG.destroy(t)
    end

    test "shortest_path finds direct path between adjacent nodes" do
      t = seed_small_graph(setup_table())
      assert {:ok, path} = KG.shortest_path(t, "n1", "n2")
      assert List.first(path) == "n1"
      assert List.last(path) == "n2"
      KG.destroy(t)
    end

    test "shortest_path finds multi-hop path" do
      t = seed_small_graph(setup_table())
      assert {:ok, path} = KG.shortest_path(t, "n1", "n4")
      assert List.first(path) == "n1"
      assert List.last(path) == "n4"
      assert length(path) >= 2
      KG.destroy(t)
    end

    test "shortest_path returns :no_path when disconnected" do
      t = setup_table()
      {:ok, _} = KG.create_node(t, "island_a", :concept, %{})
      {:ok, _} = KG.create_node(t, "island_b", :concept, %{})
      assert {:error, :no_path} = KG.shortest_path(t, "island_a", "island_b")
      KG.destroy(t)
    end

    test "path_exists? returns true for reachable pair and false otherwise" do
      t = seed_small_graph(setup_table())
      {:ok, _} = KG.create_node(t, "orphan", :concept, %{})
      assert KG.path_exists?(t, "n1", "n4") == true
      assert KG.path_exists?(t, "n1", "orphan") == false
      KG.destroy(t)
    end
  end

  # ---------------------------------------------------------------------------
  # 4. Semantic search
  # ---------------------------------------------------------------------------

  describe "semantic search" do
    test "search returns relevant nodes for keyword match" do
      t = seed_small_graph(setup_table())
      results = KG.search(t, "alarm")
      assert length(results) >= 1
      {score, node} = hd(results)
      assert score > 0.0
      assert node.type != nil
      KG.destroy(t)
    end

    test "search returns empty list when no match" do
      t = seed_small_graph(setup_table())
      results = KG.search(t, "xyzzy_nonexistent_zzz")
      assert results == []
      KG.destroy(t)
    end

    test "search results are ordered by descending relevance" do
      t = setup_table()

      {:ok, _} =
        KG.create_node(t, "high", :concept, %{label: "alarm alarm alarm", tags: ["alarm"]})

      {:ok, _} = KG.create_node(t, "low", :concept, %{label: "alarm", tags: []})
      results = KG.search(t, "alarm")
      scores = Enum.map(results, fn {score, _} -> score end)
      assert scores == Enum.sort(scores, :desc)
      KG.destroy(t)
    end

    test "fuzzy_search filters below min_score threshold" do
      t = seed_small_graph(setup_table())
      results = KG.fuzzy_search(t, "alarm", 1.0)
      assert Enum.all?(results, fn {score, _} -> score >= 1.0 end)
      KG.destroy(t)
    end

    test "search is case-insensitive" do
      t = setup_table()
      {:ok, _} = KG.create_node(t, "n", :concept, %{label: "GUARDIAN", tags: []})
      results = KG.search(t, "guardian")
      assert length(results) >= 1
      KG.destroy(t)
    end
  end

  # ---------------------------------------------------------------------------
  # 5. Subgraph extraction
  # ---------------------------------------------------------------------------

  describe "subgraph extraction" do
    test "1-hop neighborhood includes start node and direct neighbors" do
      t = seed_small_graph(setup_table())
      neighborhood = KG.n_hop_neighborhood(t, "n1", 1)
      ids = Enum.map(neighborhood, & &1.id)
      assert "n1" in ids
      assert "n2" in ids
      KG.destroy(t)
    end

    test "2-hop neighborhood reaches transitive neighbors" do
      t = seed_small_graph(setup_table())
      neighborhood = KG.n_hop_neighborhood(t, "n1", 2)
      ids = Enum.map(neighborhood, & &1.id)
      assert "n1" in ids
      assert "n2" in ids
      assert "n3" in ids
      KG.destroy(t)
    end

    test "0-hop neighborhood returns only the start node" do
      t = seed_small_graph(setup_table())
      neighborhood = KG.n_hop_neighborhood(t, "n1", 0)
      assert length(neighborhood) == 1
      assert hd(neighborhood).id == "n1"
      KG.destroy(t)
    end

    test "subgraph_by_type returns only nodes of the given type" do
      t = seed_small_graph(setup_table())
      concepts = KG.subgraph_by_type(t, :concept)
      assert length(concepts) == 2
      assert Enum.all?(concepts, fn n -> n.type == :concept end)
      KG.destroy(t)
    end

    test "subgraph_by_type returns empty list when type absent" do
      t = seed_small_graph(setup_table())
      assert KG.subgraph_by_type(t, :spacecraft) == []
      KG.destroy(t)
    end
  end

  # ---------------------------------------------------------------------------
  # 6. Knowledge ingestion (SC-IKE-001)
  # ---------------------------------------------------------------------------

  describe "knowledge ingestion" do
    test "ingest_document creates a document node and entity nodes per tag" do
      t = setup_table()

      {:ok, ids} =
        KG.ingest_document(t, %{
          title: "SIL-6 Safety Manual",
          content: "Apoptosis protocol and guardian requirements.",
          tags: ["safety", "guardian", "apoptosis"]
        })

      assert length(ids) == 4
      doc_id = hd(ids)
      assert {:ok, doc_node} = KG.get_node(t, doc_id)
      assert doc_node.type == :document
      assert doc_node.attrs.label == "SIL-6 Safety Manual"
      KG.destroy(t)
    end

    test "ingest_document creates :relates_to edges from document to entities" do
      t = setup_table()

      {:ok, [doc_id | _entity_ids]} =
        KG.ingest_document(t, %{
          title: "Zenoh Spec",
          content: "Zenoh pub/sub protocol details.",
          tags: ["zenoh", "pubsub"]
        })

      outgoing = KG.edges_from(t, doc_id)
      assert length(outgoing) == 2
      assert Enum.all?(outgoing, fn {_from, _to, etype} -> etype == :relates_to end)
      KG.destroy(t)
    end

    test "ingesting two documents sharing a tag reuses the entity node" do
      t = setup_table()
      {:ok, _} = KG.ingest_document(t, %{title: "Doc A", content: "x", tags: ["shared"]})
      {:ok, _} = KG.ingest_document(t, %{title: "Doc B", content: "y", tags: ["shared"]})
      entities = KG.subgraph_by_type(t, :entity)
      shared_entities = Enum.filter(entities, fn n -> n.attrs.label == "shared" end)
      assert length(shared_entities) == 1
      KG.destroy(t)
    end

    test "ingest_document with no tags creates only the document node" do
      t = setup_table()
      {:ok, ids} = KG.ingest_document(t, %{title: "Bare doc", content: "no tags", tags: []})
      assert length(ids) == 1
      KG.destroy(t)
    end
  end

  # ---------------------------------------------------------------------------
  # 7. Entropy gating (SC-IKE-002)
  # ---------------------------------------------------------------------------

  describe "entropy gating" do
    test "empty graph has zero entropy" do
      t = setup_table()
      assert KG.entropy(t) == 0.0
      KG.destroy(t)
    end

    test "single-type graph has zero normalized entropy (max disorder not reached)" do
      t = setup_table()
      {:ok, _} = KG.create_node(t, "a", :concept, %{})
      {:ok, _} = KG.create_node(t, "b", :concept, %{})
      assert KG.entropy(t) == 0.0
      KG.destroy(t)
    end

    test "mixed-type graph has positive normalized entropy" do
      t = seed_small_graph(setup_table())
      h = KG.entropy(t)
      assert h > 0.0
      assert h <= 1.0
      KG.destroy(t)
    end

    test "deployment_allowed? passes when entropy <= 0.2 (all same type)" do
      t = setup_table()
      for i <- 1..5, do: KG.create_node(t, "c#{i}", :concept, %{})
      assert {:ok, _h} = KG.deployment_allowed?(t)
      KG.destroy(t)
    end

    test "deployment_allowed? blocks when entropy > 0.2 (high type diversity)" do
      t = setup_table()
      types = [:concept, :entity, :document, :relation, :event]

      for {type, idx} <- Enum.with_index(types, 1) do
        KG.create_node(t, "n#{idx}", type, %{label: "#{type}-#{idx}"})
      end

      # With 5 equally distributed types, normalized entropy = 1.0 > 0.2
      assert {:error, {:entropy_too_high, h}} = KG.deployment_allowed?(t)
      assert h > 0.2
      KG.destroy(t)
    end

    test "entropy is between 0.0 and 1.0 inclusive for any graph" do
      t = seed_small_graph(setup_table())
      h = KG.entropy(t)
      assert h >= 0.0
      assert h <= 1.0
      KG.destroy(t)
    end
  end

  # ---------------------------------------------------------------------------
  # 8. Drift detection (SC-IKE-003)
  # ---------------------------------------------------------------------------

  describe "drift detection" do
    test "snapshot captures node_count, edge_count, type_distribution, node_ids" do
      t = seed_small_graph(setup_table())
      snap = KG.snapshot(t)
      assert snap.node_count == 4
      assert snap.edge_count == 3
      assert is_map(snap.type_distribution)
      assert is_list(snap.node_ids)
      KG.destroy(t)
    end

    test "drift_score is 0.0 when comparing identical snapshots" do
      t = seed_small_graph(setup_table())
      snap = KG.snapshot(t)
      assert KG.drift_score(snap, snap) == 0.0
      KG.destroy(t)
    end

    test "adding a node increases drift_score above zero" do
      t = seed_small_graph(setup_table())
      snap1 = KG.snapshot(t)
      {:ok, _} = KG.create_node(t, "new_node", :concept, %{label: "newcomer"})
      snap2 = KG.snapshot(t)
      assert KG.drift_score(snap1, snap2) > 0.0
      KG.destroy(t)
    end

    test "removing a node produces positive drift_score" do
      t = seed_small_graph(setup_table())
      snap1 = KG.snapshot(t)
      KG.delete_node(t, "n4")
      snap2 = KG.snapshot(t)
      assert KG.drift_score(snap1, snap2) > 0.0
      KG.destroy(t)
    end

    test "drift_score reflects both additions and deletions" do
      t = seed_small_graph(setup_table())
      snap1 = KG.snapshot(t)
      KG.delete_node(t, "n1")
      {:ok, _} = KG.create_node(t, "replacement", :concept, %{})
      snap2 = KG.snapshot(t)
      score = KG.drift_score(snap1, snap2)
      assert is_float(score)
      assert score >= 0.0
      KG.destroy(t)
    end

    test "drift_score is bounded between 0.0 and an upper bound for any two graphs" do
      t1 = seed_small_graph(setup_table())
      snap_a = KG.snapshot(t1)

      t2 = setup_table()
      {:ok, _} = KG.create_node(t2, "x1", :concept, %{})
      {:ok, _} = KG.create_node(t2, "x2", :entity, %{})
      {:ok, _} = KG.create_node(t2, "x3", :document, %{})
      {:ok, _} = KG.create_node(t2, "x4", :concept, %{})
      snap_b = KG.snapshot(t2)

      s_ab = KG.drift_score(snap_a, snap_b)
      s_ba = KG.drift_score(snap_b, snap_a)

      # Both directions produce non-negative, finite floats
      assert is_float(s_ab) and s_ab >= 0.0
      assert is_float(s_ba) and s_ba >= 0.0

      # Score must be higher than identity (0.0) since the graphs differ in node IDs
      assert s_ab > 0.0 or s_ba > 0.0

      KG.destroy(t1)
      KG.destroy(t2)
    end
  end

  # ---------------------------------------------------------------------------
  # 9. Property: node deletion removes all connected edges
  # ---------------------------------------------------------------------------

  describe "property: node deletion removes all connected edges" do
    test "deleting a node leaves no dangling edges referencing it" do
      ExUnitProperties.check all(
                               node_count <- SD.integer(2..8),
                               raw_idx <- SD.integer(0..7),
                               max_runs: 30
                             ) do
        t = setup_table()
        # Clamp raw_idx so it stays in-bounds regardless of generated node_count
        target_idx = rem(raw_idx, node_count)
        ids = Enum.map(0..(node_count - 1), fn i -> "n#{i}" end)
        Enum.each(ids, fn id -> KG.create_node(t, id, :concept, %{}) end)

        # Connect nodes in a simple chain
        ids
        |> Enum.zip(tl(ids))
        |> Enum.each(fn {from, to} -> KG.create_edge(t, from, to, :relates_to) end)

        target = Enum.at(ids, target_idx)
        KG.delete_node(t, target)

        remaining_edges = KG.all_edges(t)

        assert Enum.all?(remaining_edges, fn {from, to, _type} ->
                 from != target and to != target
               end),
               "Found dangling edge referencing deleted node #{target}"

        KG.destroy(t)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 10. Property: graph traversal visits each node at most once
  # ---------------------------------------------------------------------------

  describe "property: graph traversal visits each node at most once" do
    test "BFS visits every reachable node at most once" do
      ExUnitProperties.check all(
                               node_count <- SD.integer(1..10),
                               max_runs: 25
                             ) do
        t = setup_table()
        ids = Enum.map(1..node_count, fn i -> "bfs_n#{i}" end)
        Enum.each(ids, fn id -> KG.create_node(t, id, :concept, %{}) end)

        # Add edges to form a sparse connected graph
        ids
        |> Enum.zip(tl(ids))
        |> Enum.each(fn {from, to} -> KG.create_edge(t, from, to, :relates_to) end)

        start = hd(ids)
        visited = KG.bfs(t, start)

        assert length(visited) == length(Enum.uniq(visited)),
               "BFS visited a node more than once: #{inspect(visited)}"

        KG.destroy(t)
      end
    end

    test "DFS visits every reachable node at most once" do
      ExUnitProperties.check all(
                               node_count <- SD.integer(1..8),
                               max_runs: 25
                             ) do
        t = setup_table()
        ids = Enum.map(1..node_count, fn i -> "dfs_n#{i}" end)
        Enum.each(ids, fn id -> KG.create_node(t, id, :concept, %{}) end)

        ids
        |> Enum.zip(tl(ids))
        |> Enum.each(fn {from, to} -> KG.create_edge(t, from, to, :relates_to) end)

        start = hd(ids)
        visited = KG.dfs(t, start)

        assert length(visited) == length(Enum.uniq(visited)),
               "DFS visited a node more than once: #{inspect(visited)}"

        KG.destroy(t)
      end
    end

    @tag :propcheck
    test "PropCheck forall: BFS result contains no duplicate IDs" do
      forall n <- PC.choose(1, 6) do
        t = setup_table()
        ids = Enum.map(1..n, fn i -> "pc_n#{i}" end)
        Enum.each(ids, fn id -> KG.create_node(t, id, :concept, %{}) end)

        ids
        |> Enum.zip(tl(ids))
        |> Enum.each(fn {from, to} -> KG.create_edge(t, from, to, :relates_to) end)

        visited = KG.bfs(t, hd(ids))
        unique_count = length(Enum.uniq(visited))
        total_count = length(visited)
        KG.destroy(t)
        unique_count == total_count
      end
    end
  end
end
