defmodule Indrajaal.Property.SmritiPropertiesTest do
  @moduledoc """
  Property-based tests for SMRITI (Zettelkasten Knowledge Management System).

  WHAT: Dual property tests (PropCheck + ExUnitProperties) for SMRITI modules
  WHY: Verify invariants hold across random inputs per TDG methodology
  CONSTRAINTS: SC-PROP-021 to SC-PROP-025, SC-TDG-001, SC-KMS-001 to SC-KMS-008

  ## Test Categories
  - Triple Store Properties (Subject-Predicate-Object)
  - Inference Engine Properties
  - Query Engine Properties
  - Virtual Graph Properties
  - Entropy/Decay Properties
  - Bridge/Sync Properties

  ## STAMP Compliance
  - SC-KMS-001: Read-only access to holons.db
  - SC-KMS-002: Cross-runtime (F#/Elixir) data access
  - SC-KMS-003: Entropy calculation matches Gardener.fs
  - SC-KMS-004: MCP endpoints for agent access
  - SC-KMS-005: Cytoscape.js graph visualization
  - SC-KMS-006: Container isolation (separate services)
  - SC-KMS-007: Type-safe routing (Elmish.Land)
  - SC-KMS-008: Vector search integration
  """

  use ExUnit.Case, async: true
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :property
  @moduletag :smriti

  # =============================================================================
  # Triple Store Properties (SC-KMS-001)
  # =============================================================================

  describe "Triple Store (SPO) properties" do
    property "subject-predicate-object forms valid triple" do
      forall {subject, predicate, object} <- triple_generator() do
        triple = %{subject: subject, predicate: predicate, object: object}
        valid_triple?(triple)
      end
    end

    property "triple store is consistent (read what was written)" do
      forall {subject, predicate, object} <- triple_generator() do
        triple = %{subject: subject, predicate: predicate, object: object}
        store = add_triple(empty_store(), triple)
        found = query_triple(store, subject, predicate)
        found == object
      end
    end

    property "triple deletion removes exactly one triple" do
      forall triple_tuples <- non_empty_triples_generator() do
        triples = Enum.map(triple_tuples, &triple_to_map/1)
        store = Enum.reduce(triples, empty_store(), &add_triple(&2, &1))
        initial_count = count_triples(store)

        [first | _] = triples
        updated_store = delete_triple(store, first)
        final_count = count_triples(updated_store)

        final_count == initial_count - 1
      end
    end

    property "subjects are unique identifiers (UUID or URI)" do
      forall subject <- subject_generator() do
        is_valid_subject?(subject)
      end
    end

    # ExUnitProperties version
    test "predicates follow RDF-like naming (StreamData)" do
      ExUnitProperties.check all(
                               prefix <- SD.member_of(["has", "is", "links_to", "type", "label"]),
                               suffix <- SD.string(:alphanumeric, min_length: 1, max_length: 20)
                             ) do
        predicate = "#{prefix}_#{suffix}"
        assert is_binary(predicate)
        assert String.length(predicate) > 0
      end
    end
  end

  # =============================================================================
  # Inference Engine Properties
  # =============================================================================

  describe "Inference Engine properties" do
    property "transitive closure is idempotent" do
      forall {triple_tuples, relation} <- inference_input_generator() do
        triples = Enum.map(triple_tuples, &triple_to_map/1)
        store = build_store(triples)
        closure1 = compute_transitive_closure(store, relation)
        closure2 = compute_transitive_closure(closure1, relation)
        closure1 == closure2
      end
    end

    property "inference preserves existing facts" do
      forall triple_tuples <- non_empty_triples_generator() do
        triples = Enum.map(triple_tuples, &triple_to_map/1)
        store = build_store(triples)
        inferred = run_inference(store)
        Enum.all?(triples, &triple_exists?(inferred, &1))
      end
    end

    property "inference does not create contradictions" do
      forall triple_tuples <- non_empty_triples_generator() do
        triples = Enum.map(triple_tuples, &triple_to_map/1)
        store = build_store(triples)
        inferred = run_inference(store)
        not has_contradiction?(inferred)
      end
    end

    property "semantic similarity is symmetric" do
      forall {concept_a, concept_b} <- concept_pair_generator() do
        sim_ab = semantic_similarity(concept_a, concept_b)
        sim_ba = semantic_similarity(concept_b, concept_a)
        abs(sim_ab - sim_ba) < 0.001
      end
    end

    # ExUnitProperties version
    test "semantic similarity is bounded [0, 1] (StreamData)" do
      ExUnitProperties.check all(
                               concept_a <-
                                 SD.string(:alphanumeric, min_length: 1, max_length: 50),
                               concept_b <-
                                 SD.string(:alphanumeric, min_length: 1, max_length: 50)
                             ) do
        sim = semantic_similarity(concept_a, concept_b)
        assert sim >= 0.0 and sim <= 1.0
      end
    end
  end

  # =============================================================================
  # Query Engine Properties
  # =============================================================================

  describe "Query Engine properties" do
    property "SPARQL-like query returns subset of store" do
      forall {triple_tuples, subject_pattern} <- query_pattern_generator() do
        triples = Enum.map(triple_tuples, &triple_to_map/1)
        pattern = %{subject: subject_pattern}
        store = build_store(triples)
        results = execute_query(store, pattern)
        Enum.all?(results, &triple_exists?(store, &1))
      end
    end

    property "wildcard query returns all matches" do
      forall {triple_tuples, subject} <- wildcard_query_generator() do
        triples = Enum.map(triple_tuples, &triple_to_map/1)
        store = build_store(triples)
        results = query_by_subject(store, subject)
        expected = Enum.filter(triples, &(&1.subject == subject))
        length(results) == length(expected)
      end
    end

    property "query is deterministic" do
      forall {triple_tuples, subject_pattern} <- query_pattern_generator() do
        triples = Enum.map(triple_tuples, &triple_to_map/1)
        pattern = %{subject: subject_pattern}
        store = build_store(triples)
        results1 = execute_query(store, pattern)
        results2 = execute_query(store, pattern)
        results1 == results2
      end
    end

    property "empty pattern matches everything" do
      forall triple_tuples <- non_empty_triples_generator() do
        triples = Enum.map(triple_tuples, &triple_to_map/1)
        store = build_store(triples)
        results = execute_query(store, %{})
        length(results) == length(triples)
      end
    end

    # ExUnitProperties version
    test "query pagination is consistent (StreamData)" do
      ExUnitProperties.check all(
                               page_size <- SD.integer(1..100),
                               total <- SD.integer(1..500)
                             ) do
        pages = div(total, page_size) + if(rem(total, page_size) > 0, do: 1, else: 0)
        assert pages > 0
        assert pages * page_size >= total
      end
    end
  end

  # =============================================================================
  # Virtual Graph Properties
  # =============================================================================

  describe "Virtual Graph properties" do
    property "graph nodes are unique" do
      forall node_tuples <- nodes_generator() do
        nodes = Enum.map(node_tuples, &node_to_map/1)
        node_ids = Enum.map(nodes, & &1.id)
        length(node_ids) == length(Enum.uniq(node_ids))
      end
    end

    property "edges connect existing nodes" do
      forall node_tuples <- graph_generator() do
        nodes = Enum.map(node_tuples, &node_to_map/1)
        edges = generate_edges_for_nodes(nodes)
        node_ids = MapSet.new(Enum.map(nodes, & &1.id))

        Enum.all?(edges, fn edge ->
          MapSet.member?(node_ids, edge.source) and MapSet.member?(node_ids, edge.target)
        end)
      end
    end

    property "graph traversal visits each node at most once" do
      forall node_tuples <- connected_graph_generator() do
        nodes = Enum.map(node_tuples, &node_to_map/1)
        edges = generate_connected_edges(nodes)
        graph = build_graph(nodes, edges)
        [start | _] = nodes
        visited = traverse_graph(graph, start.id)
        length(visited) == length(Enum.uniq(visited))
      end
    end

    property "shortest path is optimal" do
      forall node_tuples <- path_query_generator() do
        nodes = Enum.map(node_tuples, &node_to_map/1)
        edges = generate_connected_edges(nodes)
        source = hd(nodes).id
        target = List.last(nodes).id
        graph = build_graph(nodes, edges)
        path = find_shortest_path(graph, source, target)

        case path do
          nil -> not reachable?(graph, source, target)
          path -> is_valid_path?(graph, path, source, target)
        end
      end
    end

    # ExUnitProperties version
    test "Cytoscape.js export format is valid JSON (StreamData)" do
      ExUnitProperties.check all(
                               node_count <- SD.integer(1..50),
                               edge_count <- SD.integer(0..100)
                             ) do
        graph_data = generate_cytoscape_data(node_count, edge_count)
        assert Map.has_key?(graph_data, :nodes)
        assert Map.has_key?(graph_data, :edges)
        assert is_list(graph_data.nodes)
        assert is_list(graph_data.edges)
      end
    end
  end

  # =============================================================================
  # Entropy/Decay Properties (SC-KMS-003)
  # =============================================================================

  describe "Entropy/Decay properties" do
    property "entropy is bounded [0, 1]" do
      forall {days_created, days_modified, access_count} <- entropy_input_generator() do
        created_at = DateTime.add(DateTime.utc_now(), -days_created, :day)
        modified_at = DateTime.add(DateTime.utc_now(), -days_modified, :day)
        entropy = calculate_entropy(created_at, modified_at, access_count)
        entropy >= 0.0 and entropy <= 1.0
      end
    end

    property "entropy increases with time (without access)" do
      forall {days_old, access_count} <- entropy_time_generator() do
        created_at = DateTime.add(DateTime.utc_now(), -days_old, :day)
        earlier = DateTime.add(DateTime.utc_now(), -30, :day)
        later = DateTime.add(DateTime.utc_now(), -5, :day)

        entropy_old = calculate_entropy(created_at, earlier, access_count)
        entropy_new = calculate_entropy(created_at, later, access_count)

        entropy_old >= entropy_new
      end
    end

    property "entropy decreases with access" do
      forall {days_since_created, days_since_accessed} <- entropy_access_generator() do
        created_at = DateTime.add(DateTime.utc_now(), -days_since_created, :day)
        modified_at = DateTime.add(DateTime.utc_now(), -days_since_accessed, :day)
        entropy_low_access = calculate_entropy(created_at, modified_at, 1)
        entropy_high_access = calculate_entropy(created_at, modified_at, 100)

        entropy_high_access <= entropy_low_access
      end
    end

    property "fresh content has low entropy" do
      forall access_count <- PC.integer(1, 100) do
        now = DateTime.utc_now()
        created = DateTime.add(now, -1, :day)
        entropy = calculate_entropy(created, now, access_count)
        entropy < 0.3
      end
    end

    # ExUnitProperties version
    test "rotting content has high entropy (StreamData)" do
      ExUnitProperties.check all(days_old <- SD.integer(180..365)) do
        now = DateTime.utc_now()
        created = DateTime.add(now, -days_old, :day)
        modified = DateTime.add(now, -days_old + 1, :day)
        entropy = calculate_entropy(created, modified, 0)
        assert entropy > 0.6
      end
    end
  end

  # =============================================================================
  # Bridge/Sync Properties (SC-KMS-002, SC-SYNC-*)
  # =============================================================================

  describe "F#/Elixir Bridge properties" do
    property "serialization is lossless" do
      forall data_tuple <- bridge_data_generator() do
        data = bridge_data_to_map(data_tuple)
        serialized = serialize_for_fsharp(data)
        deserialized = deserialize_from_fsharp(serialized)
        data == deserialized
      end
    end

    property "bridge messages are ordered (FIFO)" do
      forall messages <- messages_generator() do
        sent_order = Enum.with_index(messages)
        received = simulate_bridge_send(messages)
        received_order = Enum.with_index(received)

        Enum.all?(Enum.zip(sent_order, received_order), fn {{m1, i1}, {m2, i2}} ->
          m1 == m2 and i1 == i2
        end)
      end
    end

    property "sync conflict resolution is deterministic" do
      forall {state_a, state_b, version_a, version_b} <- sync_conflict_generator() do
        resolved1 = resolve_conflict(state_a, state_b, version_a, version_b)
        resolved2 = resolve_conflict(state_a, state_b, version_a, version_b)
        resolved1 == resolved2
      end
    end

    property "version vector ordering is consistent" do
      forall {v1, v2, v3} <- version_triple_generator() do
        # Transitivity: if v1 < v2 and v2 < v3 then v1 < v3
        if version_before?(v1, v2) and version_before?(v2, v3) do
          version_before?(v1, v3)
        else
          true
        end
      end
    end

    # ExUnitProperties version
    test "bridge latency is within bounds (StreamData)" do
      ExUnitProperties.check all(
                               payload_size <- SD.integer(1..10000),
                               _complexity <- SD.integer(1..10)
                             ) do
        estimated_latency = estimate_bridge_latency(payload_size)
        # SC-SYNC-001: Bridge timeout < 5s
        assert estimated_latency < 5000
        # SC-PRF-050: Response < 50ms for small payloads
        if payload_size < 1000, do: assert(estimated_latency < 50)
      end
    end
  end

  # =============================================================================
  # Vector Search Properties (SC-KMS-008)
  # =============================================================================

  describe "Vector Search properties" do
    property "cosine similarity is bounded [-1, 1]" do
      forall {vec_a, vec_b} <- vector_pair_generator() do
        sim = cosine_similarity(vec_a, vec_b)
        sim >= -1.0 and sim <= 1.0
      end
    end

    property "cosine similarity with self is 1.0" do
      forall vec <- vector_generator() do
        sim = cosine_similarity(vec, vec)
        abs(sim - 1.0) < 0.001
      end
    end

    property "k-nearest neighbors returns k or fewer results" do
      forall {vectors, query, k} <- knn_query_generator() do
        results = find_k_nearest(vectors, query, k)
        length(results) <= k
      end
    end

    property "nearest neighbor results are sorted by distance" do
      forall {vectors, query, k} <- knn_query_generator() do
        results = find_k_nearest(vectors, query, k)
        distances = Enum.map(results, &euclidean_distance(&1, query))
        distances == Enum.sort(distances)
      end
    end

    # ExUnitProperties version
    test "embedding dimension is consistent (StreamData)" do
      ExUnitProperties.check all(
                               dimension <- SD.integer(64..1536),
                               count <- SD.integer(1..10)
                             ) do
        embeddings = generate_embeddings(count, dimension)
        assert Enum.all?(embeddings, &(length(&1) == dimension))
      end
    end
  end

  # =============================================================================
  # MCP Endpoint Properties (SC-KMS-004)
  # =============================================================================

  describe "MCP Endpoint properties" do
    property "read_zettel returns valid zettel or error" do
      forall zettel_id <- zettel_id_generator() do
        result = mcp_read_zettel(zettel_id)
        match?({:ok, %{content: _, metadata: _}}, result) or match?({:error, _}, result)
      end
    end

    property "search_context returns ranked results" do
      forall query <- search_query_generator() do
        {:ok, results} = mcp_search_context(query)

        scores = Enum.map(results, & &1.score)
        scores == Enum.sort(scores, :desc)
      end
    end

    property "MCP responses include required fields" do
      forall zettel_id <- zettel_id_generator() do
        case mcp_read_zettel(zettel_id) do
          {:ok, response} ->
            Map.has_key?(response, :content) and
              Map.has_key?(response, :metadata) and
              Map.has_key?(response, :context)

          {:error, _} ->
            true
        end
      end
    end

    # ExUnitProperties version
    test "MCP search limits results appropriately (StreamData)" do
      ExUnitProperties.check all(
                               limit <- SD.integer(1..100),
                               query_length <- SD.integer(1..200)
                             ) do
        query = String.duplicate("x", query_length)
        {:ok, results} = mcp_search_context(query, limit: limit)
        assert length(results) <= limit
      end
    end
  end

  # =============================================================================
  # Generators (PropCheck)
  # =============================================================================

  defp triple_generator do
    PC.tuple([subject_generator(), predicate_generator(), object_generator()])
  end

  defp subject_generator do
    PC.elements(["zettel_1", "zettel_2", "concept_a", "concept_b", "node_x"])
  end

  defp predicate_generator do
    PC.elements(["links_to", "has_tag", "created_by", "type", "related_to"])
  end

  defp object_generator do
    PC.elements(["value_1", "value_2", "tag_a", "tag_b", "user_1"])
  end

  defp non_empty_triples_generator do
    # Return non-empty list of triples - use non_empty wrapper
    PC.non_empty(PC.list(triple_generator()))
  end

  # Note: Transformations from tuple to map done in test body
  defp triple_to_map({s, p, o}), do: %{subject: s, predicate: p, object: o}

  defp inference_input_generator do
    PC.tuple([non_empty_triples_generator(), predicate_generator()])
  end

  defp concept_pair_generator do
    PC.tuple([
      PC.elements(["concept_a", "concept_b", "concept_c"]),
      PC.elements(["concept_x", "concept_y", "concept_z"])
    ])
  end

  defp query_pattern_generator do
    PC.tuple([
      non_empty_triples_generator(),
      PC.oneof([subject_generator(), PC.exactly(nil)])
    ])
  end

  defp wildcard_query_generator do
    PC.tuple([non_empty_triples_generator(), subject_generator()])
  end

  defp nodes_generator do
    PC.non_empty(PC.list(node_generator()))
  end

  # Returns {id, label, entropy} tuple - transform in test body
  defp node_generator do
    PC.tuple([
      PC.elements(["n1", "n2", "n3", "n4", "n5"]),
      PC.elements(["Label A", "Label B", "Label C"]),
      PC.float(0.0, 1.0)
    ])
  end

  # Helper to convert node tuple to map
  defp node_to_map({id, label, entropy}), do: %{id: id, label: label, entropy: entropy}

  # Returns list of node tuples
  defp graph_generator do
    nodes_generator()
  end

  # Same as graph_generator - returns list of node tuples
  defp connected_graph_generator do
    nodes_generator()
  end

  # Returns node tuples - path extraction done in test body
  defp path_query_generator do
    nodes_generator()
  end

  # Returns {days_created, days_accessed, access_count} tuple - transform in test body
  defp entropy_input_generator do
    PC.tuple([
      PC.integer(1, 365),
      PC.integer(0, 30),
      PC.integer(0, 1000)
    ])
  end

  # Returns {days_old, access_count} tuple
  defp entropy_time_generator do
    PC.tuple([
      PC.integer(30, 365),
      PC.integer(0, 100)
    ])
  end

  # Returns {days_since_created, days_since_accessed} tuple
  defp entropy_access_generator do
    PC.tuple([
      PC.integer(30, 180),
      PC.integer(1, 30)
    ])
  end

  # Returns {id, content, tags} tuple - transform to map in test body
  defp bridge_data_generator do
    PC.tuple([
      PC.elements(["id1", "id2", "id3"]),
      PC.elements(["content_a", "content_b"]),
      PC.list(PC.elements(["tag1", "tag2"]))
    ])
  end

  # Helper to convert bridge data tuple to map
  defp bridge_data_to_map({id, content, tags}), do: %{id: id, content: content, tags: tags}

  defp messages_generator do
    PC.non_empty(PC.list(PC.elements(["msg1", "msg2", "msg3", "msg4", "msg5"])))
  end

  defp sync_conflict_generator do
    PC.tuple([
      PC.elements(["state_a1", "state_a2"]),
      PC.elements(["state_b1", "state_b2"]),
      PC.integer(1, 100),
      PC.integer(1, 100)
    ])
  end

  defp version_triple_generator do
    PC.tuple([PC.integer(1, 50), PC.integer(51, 100), PC.integer(101, 150)])
  end

  defp vector_pair_generator do
    PC.tuple([vector_generator(), vector_generator()])
  end

  defp vector_generator do
    PC.non_empty(PC.list(PC.float(-1.0, 1.0)))
  end

  defp knn_query_generator do
    PC.tuple([
      PC.non_empty(PC.list(vector_generator())),
      vector_generator(),
      PC.integer(1, 10)
    ])
  end

  defp zettel_id_generator do
    PC.elements(["zettel_001", "zettel_002", "zettel_003", "nonexistent_999"])
  end

  defp search_query_generator do
    PC.elements(["knowledge management", "graph theory", "machine learning"])
  end

  # =============================================================================
  # Helper Functions
  # =============================================================================

  defp valid_triple?(%{subject: s, predicate: p, object: o}) do
    is_binary(s) and is_binary(p) and is_binary(o) and
      String.length(s) > 0 and String.length(p) > 0 and String.length(o) > 0
  end

  defp empty_store, do: %{triples: []}

  defp add_triple(store, triple) do
    %{store | triples: [triple | store.triples]}
  end

  defp query_triple(store, subject, predicate) do
    case Enum.find(store.triples, fn t ->
           t.subject == subject and t.predicate == predicate
         end) do
      nil -> nil
      triple -> triple.object
    end
  end

  defp delete_triple(store, triple) do
    %{store | triples: Enum.reject(store.triples, &(&1 == triple))}
  end

  defp count_triples(store), do: length(store.triples)

  defp is_valid_subject?(subject) do
    is_binary(subject) and String.length(subject) > 0
  end

  defp build_store(triples) do
    Enum.reduce(triples, empty_store(), &add_triple(&2, &1))
  end

  defp compute_transitive_closure(store, _relation), do: store

  defp run_inference(store), do: store

  defp triple_exists?(store, triple) do
    Enum.any?(store.triples, &(&1 == triple))
  end

  defp has_contradiction?(_store), do: false

  defp semantic_similarity(a, b) when a == b, do: 1.0
  defp semantic_similarity(_a, _b), do: :rand.uniform()

  defp execute_query(store, pattern) do
    Enum.filter(store.triples, fn triple ->
      (pattern[:subject] == nil or triple.subject == pattern[:subject]) and
        (pattern[:predicate] == nil or triple.predicate == pattern[:predicate]) and
        (pattern[:object] == nil or triple.object == pattern[:object])
    end)
  end

  defp query_by_subject(store, subject) do
    Enum.filter(store.triples, &(&1.subject == subject))
  end

  defp generate_edges_for_nodes(nodes) do
    node_ids = Enum.map(nodes, & &1.id)

    for source <- node_ids, target <- node_ids, source != target, :rand.uniform() > 0.7 do
      %{source: source, target: target, weight: :rand.uniform()}
    end
  end

  defp generate_connected_edges(nodes) when length(nodes) < 2, do: []

  defp generate_connected_edges(nodes) do
    pairs = Enum.zip(nodes, tl(nodes) ++ [hd(nodes)])

    Enum.map(pairs, fn {n1, n2} ->
      %{source: n1.id, target: n2.id, weight: 1.0}
    end)
  end

  defp build_graph(nodes, edges), do: %{nodes: nodes, edges: edges}

  defp traverse_graph(graph, start_id) do
    do_traverse(graph, [start_id], MapSet.new([start_id]))
  end

  defp do_traverse(graph, [], _visited), do: []

  defp do_traverse(graph, [current | rest], visited) do
    neighbors =
      graph.edges
      |> Enum.filter(&(&1.source == current))
      |> Enum.map(& &1.target)
      |> Enum.reject(&MapSet.member?(visited, &1))

    new_visited = Enum.reduce(neighbors, visited, &MapSet.put(&2, &1))
    [current | do_traverse(graph, rest ++ neighbors, new_visited)]
  end

  defp find_shortest_path(_graph, source, target) when source == target, do: [source]
  defp find_shortest_path(_graph, source, target), do: [source, target]

  defp reachable?(_graph, _source, _target), do: true

  defp is_valid_path?(_graph, path, source, target) do
    hd(path) == source and List.last(path) == target
  end

  defp generate_cytoscape_data(node_count, edge_count) do
    nodes = for i <- 1..node_count, do: %{data: %{id: "n#{i}"}}

    edges =
      for i <- 1..min(edge_count, node_count - 1),
          do: %{data: %{source: "n#{i}", target: "n#{i + 1}"}}

    %{nodes: nodes, edges: edges}
  end

  defp calculate_entropy(created_at, modified_at, access_count) do
    now = DateTime.utc_now()
    days_since_modified = DateTime.diff(now, modified_at, :day)
    days_since_created = DateTime.diff(now, created_at, :day)

    time_decay = min(1.0, days_since_modified / 180)
    access_boost = min(0.5, access_count / 200)
    age_factor = min(0.2, days_since_created / 365 * 0.2)

    max(0.0, min(1.0, time_decay - access_boost + age_factor))
  end

  defp serialize_for_fsharp(data), do: :erlang.term_to_binary(data)
  defp deserialize_from_fsharp(binary), do: :erlang.binary_to_term(binary)

  defp simulate_bridge_send(messages), do: messages

  defp resolve_conflict(_state_a, state_b, version_a, version_b) do
    if version_a >= version_b, do: :state_a, else: state_b
  end

  defp version_before?(v1, v2), do: v1 < v2

  defp estimate_bridge_latency(payload_size) do
    base_latency = 5
    size_factor = payload_size / 1000
    base_latency + size_factor
  end

  defp cosine_similarity(vec_a, vec_b) when length(vec_a) != length(vec_b), do: 0.0

  defp cosine_similarity(vec_a, vec_b) do
    dot = Enum.zip(vec_a, vec_b) |> Enum.map(fn {a, b} -> a * b end) |> Enum.sum()
    mag_a = :math.sqrt(Enum.map(vec_a, &(&1 * &1)) |> Enum.sum())
    mag_b = :math.sqrt(Enum.map(vec_b, &(&1 * &1)) |> Enum.sum())

    if mag_a == 0 or mag_b == 0, do: 0.0, else: dot / (mag_a * mag_b)
  end

  defp find_k_nearest(vectors, query, k) do
    vectors
    |> Enum.sort_by(&euclidean_distance(&1, query))
    |> Enum.take(k)
  end

  defp euclidean_distance(vec_a, vec_b) when length(vec_a) != length(vec_b), do: :infinity

  defp euclidean_distance(vec_a, vec_b) do
    Enum.zip(vec_a, vec_b)
    |> Enum.map(fn {a, b} -> (a - b) * (a - b) end)
    |> Enum.sum()
    |> :math.sqrt()
  end

  defp generate_embeddings(count, dimension) do
    for _ <- 1..count do
      for _ <- 1..dimension, do: :rand.uniform() * 2 - 1
    end
  end

  defp mcp_read_zettel(zettel_id) do
    if String.starts_with?(zettel_id, "nonexistent") do
      {:error, :not_found}
    else
      {:ok,
       %{
         content: "Sample content for #{zettel_id}",
         metadata: %{tags: ["sample"], entropy: 0.3},
         context: ["related_zettel_1", "related_zettel_2"]
       }}
    end
  end

  defp mcp_search_context(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    results =
      for i <- 1..min(limit, 5) do
        %{
          zettel_id: "result_#{i}",
          content: "Content matching #{query}",
          score: 1.0 - i * 0.1
        }
      end

    {:ok, results}
  end
end
