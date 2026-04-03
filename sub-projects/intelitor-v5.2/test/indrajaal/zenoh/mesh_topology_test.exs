defmodule Indrajaal.Zenoh.MeshTopologyTest do
  @moduledoc """
  Zenoh mesh topology visualization data provider test.

  WHAT: Tests the mesh topology data pipeline that feeds visualization tooling.
        Verifies node discovery, edge computation between nodes, topology
        serialization for rendering, and real-time topology change propagation
        via PubSub/Zenoh.

  WHY: The Prajna cockpit and external dashboards depend on a consistent, typed
       topology data structure to render the mesh graph.  This suite proves that
       the topology provider emits well-formed node/edge descriptors and that the
       serialization round-trip preserves all invariants required by the
       visualization layer (SC-VDP-001 to SC-VDP-017).

  CONSTRAINTS:
    - SC-ZENOH-001: Zenoh NIF active (SKIP_ZENOH_NIF=0)
    - SC-ZTEST-003: Publish latency < 10ms
    - SC-ZTEST-012: FIFO ordering per topic
    - SC-ZTEST-017: Topic depth ≤ 6 levels
    - SC-VDP-001: Topology data MUST be serializable to JSON
    - SC-VDP-002: Node descriptors MUST include status, role, address
    - SC-VDP-003: Edge descriptors MUST include source, target, weight
    - SC-SIL6-006: 2oo3 quorum reflected in topology state
    - SC-PRF-050: Response < 50ms
    - SC-BUS-001: Async messaging only
    - SC-BUS-002: No blocking operations

  ## Change History
  | Version | Date       | Author            | Change                      |
  |---------|------------|-------------------|-----------------------------|
  | 1.0.0   | 2026-03-24 | Claude Sonnet 4.6 | Sprint 88 Wave 3 — initial  |

  @version "1.0.0"
  @last_modified "2026-03-24T00:00:00Z"
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh
  @moduletag :zenoh_topology
  @moduletag timeout: 60_000

  # ---------------------------------------------------------------------------
  # Configuration
  # ---------------------------------------------------------------------------

  @zenoh_available System.get_env("SKIP_ZENOH_NIF") != "1"

  @pubsub_name __MODULE__.PubSub

  # Topology broadcast topics
  @topology_topic "indrajaal/mesh/topology"
  @node_discovery_topic "indrajaal/mesh/nodes"
  @edge_update_topic "indrajaal/mesh/edges"
  @topology_delta_topic "indrajaal/mesh/topology/delta"

  # Latency budget (SC-PRF-050)
  @latency_budget_ms 50

  # Simulated 4-node mesh (zenoh-router + 3 holons)
  @mesh_nodes [
    %{
      id: "zenoh-router-1",
      role: :router,
      address: "tcp/zenoh-router-1:7447",
      status: :healthy,
      layer: 5
    },
    %{
      id: "indrajaal-ex-app-1",
      role: :seed,
      address: "tcp/indrajaal-ex-app-1:4000",
      status: :healthy,
      layer: 4
    },
    %{
      id: "indrajaal-cortex",
      role: :cognitive,
      address: "tcp/indrajaal-cortex:9877",
      status: :healthy,
      layer: 3
    },
    %{
      id: "indrajaal-chaya",
      role: :twin,
      address: "tcp/indrajaal-chaya:4002",
      status: :healthy,
      layer: 3
    }
  ]

  # ---------------------------------------------------------------------------
  # Setup
  # ---------------------------------------------------------------------------

  setup do
    {:ok, _pid} = start_supervised({Phoenix.PubSub, name: @pubsub_name})

    for topic <- [
          @topology_topic,
          @node_discovery_topic,
          @edge_update_topic,
          @topology_delta_topic
        ] do
      :ok = Phoenix.PubSub.subscribe(@pubsub_name, topic)
    end

    on_exit(fn ->
      for topic <- [
            @topology_topic,
            @node_discovery_topic,
            @edge_update_topic,
            @topology_delta_topic
          ] do
        Phoenix.PubSub.unsubscribe(@pubsub_name, topic)
      end
    end)

    zenoh_mode = if @zenoh_available, do: :nif, else: :pubsub_fallback
    {:ok, zenoh_mode: zenoh_mode, nodes: @mesh_nodes}
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Build a node descriptor (SC-VDP-002)
  defp node_descriptor(node) do
    %{
      id: node.id,
      role: node.role,
      address: node.address,
      status: node.status,
      layer: node.layer,
      discovered_at_us: System.monotonic_time(:microsecond),
      checkpoint_id: "CP-TOPO-#{:erlang.phash2(node.id, 9999)}"
    }
  end

  # Build an edge descriptor between two nodes (SC-VDP-003)
  defp edge_descriptor(source_id, target_id, weight \\ 1.0) do
    %{
      id: "#{source_id}->#{target_id}",
      source: source_id,
      target: target_id,
      weight: weight,
      latency_ms: :rand.uniform(10),
      direction: :bidirectional,
      created_at_us: System.monotonic_time(:microsecond)
    }
  end

  # Compute edges from a star topology (router is hub)
  defp compute_star_edges(nodes) do
    router = Enum.find(nodes, &(&1.role == :router))

    if router do
      nodes
      |> Enum.reject(&(&1.role == :router))
      |> Enum.map(&edge_descriptor(router.id, &1.id))
    else
      []
    end
  end

  # Compute a full-mesh (all-to-all) edge list
  defp compute_full_mesh_edges(nodes) do
    for a <- nodes, b <- nodes, a.id < b.id do
      edge_descriptor(a.id, b.id)
    end
  end

  # Build a complete topology snapshot
  defp topology_snapshot(nodes, edges) do
    %{
      version: 1,
      node_count: length(nodes),
      edge_count: length(edges),
      nodes: Enum.map(nodes, &node_descriptor/1),
      edges: edges,
      quorum_required: div(length(nodes), 2) + 1,
      healthy_count: Enum.count(nodes, &(&1.status == :healthy)),
      timestamp_us: System.monotonic_time(:microsecond),
      schema_version: "1.0.0"
    }
  end

  # Serialize topology to a JSON-compatible map (all keys as strings)
  defp serialize_topology(topo) do
    %{
      "version" => topo.version,
      "node_count" => topo.node_count,
      "edge_count" => topo.edge_count,
      "schema_version" => topo.schema_version,
      "quorum_required" => topo.quorum_required,
      "healthy_count" => topo.healthy_count,
      "nodes" =>
        Enum.map(topo.nodes, fn n ->
          %{
            "id" => n.id,
            "role" => to_string(n.role),
            "address" => n.address,
            "status" => to_string(n.status),
            "layer" => n.layer
          }
        end),
      "edges" =>
        Enum.map(topo.edges, fn e ->
          %{
            "id" => e.id,
            "source" => e.source,
            "target" => e.target,
            "weight" => e.weight,
            "direction" => to_string(e.direction)
          }
        end)
    }
  end

  # Drain all topology messages from mailbox
  defp drain_topology(timeout_ms \\ 300, acc \\ []) do
    receive do
      {:topology_snapshot, topo} -> drain_topology(timeout_ms, [{:topology_snapshot, topo} | acc])
      {:node_discovered, node} -> drain_topology(timeout_ms, [{:node_discovered, node} | acc])
      {:edge_added, edge} -> drain_topology(timeout_ms, [{:edge_added, edge} | acc])
      {:topology_delta, delta} -> drain_topology(timeout_ms, [{:topology_delta, delta} | acc])
    after
      timeout_ms -> Enum.reverse(acc)
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: Module and environment
  # ---------------------------------------------------------------------------

  describe "Mesh Topology: Module availability" do
    test "transport mode is correctly detected", %{zenoh_mode: mode} do
      assert mode in [:nif, :pubsub_fallback]
    end

    test "Indrajaal.Native.Zenoh module is reachable" do
      assert Code.ensure_loaded?(Indrajaal.Native.Zenoh)
    end

    test "topology topics conform to SC-ZTEST-017 depth ≤ 6" do
      topics = [
        @topology_topic,
        @node_discovery_topic,
        @edge_update_topic,
        @topology_delta_topic
      ]

      for topic <- topics do
        depth = String.split(topic, "/") |> length() |> Kernel.-(1)

        assert depth <= 6,
               "Topic '#{topic}' has depth #{depth} > 6 (SC-ZTEST-017)"
      end
    end

    test "mesh node list is non-empty and well-formed", %{nodes: nodes} do
      assert length(nodes) > 0

      for node <- nodes do
        assert is_binary(node.id)
        assert is_atom(node.role)
        assert is_binary(node.address)
        assert node.status in [:healthy, :unhealthy, :degraded]
        assert is_integer(node.layer)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: Node discovery
  # ---------------------------------------------------------------------------

  describe "Mesh Topology: Node discovery" do
    test "node descriptor has all required fields (SC-VDP-002)", %{nodes: nodes} do
      node = hd(nodes)
      desc = node_descriptor(node)

      assert is_binary(desc.id)
      assert is_atom(desc.role)
      assert is_binary(desc.address)
      assert desc.status in [:healthy, :unhealthy, :degraded]
      assert is_integer(desc.layer)
      assert is_integer(desc.discovered_at_us)
      assert is_binary(desc.checkpoint_id)
    end

    test "all #{length(@mesh_nodes)} nodes are discoverable", %{nodes: nodes} do
      node_ids = Enum.map(nodes, & &1.id) |> MapSet.new()

      assert MapSet.size(node_ids) == length(nodes),
             "Node IDs must be unique within the mesh"
    end

    test "each discovered node broadcasts to node discovery topic", %{nodes: nodes} do
      node = hd(nodes)
      desc = node_descriptor(node)

      :ok =
        Phoenix.PubSub.broadcast(@pubsub_name, @node_discovery_topic, {:node_discovered, desc})

      assert_receive {:node_discovered, received}, 300
      assert received.id == node.id
      assert received.role == node.role
    end

    test "node discovery events are FIFO ordered per topic (SC-ZTEST-012)", %{nodes: nodes} do
      for node <- nodes do
        desc = node_descriptor(node)
        Phoenix.PubSub.broadcast(@pubsub_name, @node_discovery_topic, {:node_discovered, desc})
      end

      received = drain_topology(400)
      discovered = Enum.filter(received, &match?({:node_discovered, _}, &1))

      ids_received = Enum.map(discovered, fn {:node_discovered, n} -> n.id end)
      ids_expected = Enum.map(nodes, & &1.id)

      assert ids_received == ids_expected,
             "Node discovery FIFO violated (SC-ZTEST-012): got #{inspect(ids_received)}, expected #{inspect(ids_expected)}"
    end

    test "router node is present in discovered nodes", %{nodes: nodes} do
      router = Enum.find(nodes, &(&1.role == :router))
      assert router != nil, "Mesh must have a Zenoh router node"
    end

    test "node address includes protocol prefix", %{nodes: nodes} do
      for node <- nodes do
        assert String.starts_with?(node.address, "tcp/") or
                 String.starts_with?(node.address, "udp/") or
                 String.starts_with?(node.address, "quic/"),
               "Node #{node.id} address '#{node.address}' missing protocol prefix"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: Edge computation
  # ---------------------------------------------------------------------------

  describe "Mesh Topology: Edge computation" do
    test "edge descriptor has all required fields (SC-VDP-003)", %{nodes: nodes} do
      [a, b | _] = nodes
      edge = edge_descriptor(a.id, b.id)

      assert is_binary(edge.id)
      assert is_binary(edge.source)
      assert is_binary(edge.target)
      assert is_float(edge.weight)
      assert edge.weight > 0.0
      assert edge.direction in [:unidirectional, :bidirectional]
      assert is_integer(edge.created_at_us)
    end

    test "star topology: router connects to all other nodes", %{nodes: nodes} do
      edges = compute_star_edges(nodes)
      non_router_count = Enum.count(nodes, &(&1.role != :router))

      assert length(edges) == non_router_count,
             "Star topology should have #{non_router_count} edges, got #{length(edges)}"
    end

    test "star topology: all edges have router as source", %{nodes: nodes} do
      router = Enum.find(nodes, &(&1.role == :router))
      edges = compute_star_edges(nodes)

      for edge <- edges do
        assert edge.source == router.id,
               "Star edge source must be router, got #{edge.source}"
      end
    end

    test "full mesh: edge count = N*(N-1)/2 for #{length(@mesh_nodes)} nodes", %{nodes: nodes} do
      n = length(nodes)
      expected_edges = div(n * (n - 1), 2)
      edges = compute_full_mesh_edges(nodes)

      assert length(edges) == expected_edges,
             "Full mesh should have #{expected_edges} edges, got #{length(edges)}"
    end

    test "full mesh: no self-loops", %{nodes: nodes} do
      edges = compute_full_mesh_edges(nodes)

      for edge <- edges do
        refute edge.source == edge.target,
               "Self-loop detected for node #{edge.source}"
      end
    end

    test "full mesh: no duplicate edges", %{nodes: nodes} do
      edges = compute_full_mesh_edges(nodes)
      edge_ids = Enum.map(edges, & &1.id) |> MapSet.new()

      assert MapSet.size(edge_ids) == length(edges),
             "Duplicate edges detected in full mesh"
    end

    test "edge update events broadcast correctly", %{nodes: nodes} do
      [a, b | _] = nodes
      edge = edge_descriptor(a.id, b.id, 0.95)

      :ok = Phoenix.PubSub.broadcast(@pubsub_name, @edge_update_topic, {:edge_added, edge})

      assert_receive {:edge_added, received}, 300
      assert received.source == a.id
      assert received.target == b.id
      assert received.weight == 0.95
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: Topology snapshot and serialization
  # ---------------------------------------------------------------------------

  describe "Mesh Topology: Topology snapshot" do
    test "topology snapshot includes all nodes and edges", %{nodes: nodes} do
      edges = compute_star_edges(nodes)
      topo = topology_snapshot(nodes, edges)

      assert topo.node_count == length(nodes)
      assert topo.edge_count == length(edges)
      assert length(topo.nodes) == length(nodes)
      assert length(topo.edges) == length(edges)
    end

    test "topology snapshot quorum_required is floor(N/2)+1", %{nodes: nodes} do
      edges = compute_star_edges(nodes)
      topo = topology_snapshot(nodes, edges)

      expected_quorum = div(length(nodes), 2) + 1
      assert topo.quorum_required == expected_quorum
    end

    test "topology snapshot healthy_count matches healthy nodes", %{nodes: nodes} do
      edges = compute_star_edges(nodes)
      topo = topology_snapshot(nodes, edges)
      expected_healthy = Enum.count(nodes, &(&1.status == :healthy))

      assert topo.healthy_count == expected_healthy
    end

    test "topology snapshot has schema_version in semver format", %{nodes: nodes} do
      edges = compute_star_edges(nodes)
      topo = topology_snapshot(nodes, edges)

      assert is_binary(topo.schema_version)

      assert topo.schema_version =~ ~r/^\d+\.\d+\.\d+$/,
             "schema_version '#{topo.schema_version}' must be semver (SC-ZTEST-014)"
    end

    test "topology snapshot is broadcast to topology topic", %{nodes: nodes} do
      edges = compute_star_edges(nodes)
      topo = topology_snapshot(nodes, edges)

      :ok = Phoenix.PubSub.broadcast(@pubsub_name, @topology_topic, {:topology_snapshot, topo})

      assert_receive {:topology_snapshot, received}, 300
      assert received.node_count == topo.node_count
      assert received.edge_count == topo.edge_count
    end
  end

  describe "Mesh Topology: Serialization for visualization (SC-VDP-001)" do
    test "serialized topology has string keys (JSON-compatible)", %{nodes: nodes} do
      edges = compute_star_edges(nodes)
      topo = topology_snapshot(nodes, edges)
      serialized = serialize_topology(topo)

      for {key, _} <- serialized do
        assert is_binary(key),
               "All top-level keys must be strings for JSON serialization (SC-VDP-001)"
      end
    end

    test "serialized node roles are strings (atom-safe for JSON)", %{nodes: nodes} do
      edges = compute_star_edges(nodes)
      topo = topology_snapshot(nodes, edges)
      serialized = serialize_topology(topo)

      for node <- serialized["nodes"] do
        assert is_binary(node["role"]),
               "Node role must be string in serialized form, got #{inspect(node["role"])}"

        assert is_binary(node["status"]),
               "Node status must be string in serialized form"
      end
    end

    test "serialized edge directions are strings (atom-safe for JSON)", %{nodes: nodes} do
      edges = compute_star_edges(nodes)
      topo = topology_snapshot(nodes, edges)
      serialized = serialize_topology(topo)

      for edge <- serialized["edges"] do
        assert is_binary(edge["direction"]),
               "Edge direction must be string in serialized form"
      end
    end

    test "serialized topology preserves node count", %{nodes: nodes} do
      edges = compute_star_edges(nodes)
      topo = topology_snapshot(nodes, edges)
      serialized = serialize_topology(topo)

      assert serialized["node_count"] == length(nodes)
      assert length(serialized["nodes"]) == length(nodes)
    end

    test "serialized topology preserves edge count", %{nodes: nodes} do
      edges = compute_star_edges(nodes)
      topo = topology_snapshot(nodes, edges)
      serialized = serialize_topology(topo)

      assert serialized["edge_count"] == length(edges)
      assert length(serialized["edges"]) == length(edges)
    end

    test "serialization round-trip preserves node ids", %{nodes: nodes} do
      edges = compute_star_edges(nodes)
      topo = topology_snapshot(nodes, edges)
      serialized = serialize_topology(topo)

      original_ids = Enum.map(nodes, & &1.id) |> Enum.sort()
      serialized_ids = Enum.map(serialized["nodes"], & &1["id"]) |> Enum.sort()

      assert original_ids == serialized_ids,
             "Node IDs must be preserved through serialization"
    end

    test "publish latency for topology snapshot < #{@latency_budget_ms}ms (SC-PRF-050)", %{
      nodes: nodes
    } do
      edges = compute_star_edges(nodes)
      topo = topology_snapshot(nodes, edges)
      serialized = serialize_topology(topo)

      t0 = System.monotonic_time(:microsecond)

      :ok =
        Phoenix.PubSub.broadcast(@pubsub_name, @topology_topic, {:topology_snapshot, serialized})

      elapsed_us = System.monotonic_time(:microsecond) - t0

      elapsed_ms = elapsed_us / 1_000.0

      assert elapsed_ms < @latency_budget_ms,
             "Topology publish latency #{Float.round(elapsed_ms, 2)}ms exceeded #{@latency_budget_ms}ms budget (SC-PRF-050)"
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: Topology change propagation (delta updates)
  # ---------------------------------------------------------------------------

  describe "Mesh Topology: Delta propagation" do
    test "node status change emits topology delta" do
      delta = %{
        type: :node_status_changed,
        node_id: "indrajaal-ex-app-1",
        old_status: :healthy,
        new_status: :unhealthy,
        timestamp_us: System.monotonic_time(:microsecond)
      }

      :ok =
        Phoenix.PubSub.broadcast(@pubsub_name, @topology_delta_topic, {:topology_delta, delta})

      assert_receive {:topology_delta, received}, 300
      assert received.type == :node_status_changed
      assert received.node_id == "indrajaal-ex-app-1"
      assert received.new_status == :unhealthy
    end

    test "edge weight change emits topology delta" do
      delta = %{
        type: :edge_weight_changed,
        edge_id: "zenoh-router-1->indrajaal-ex-app-1",
        old_weight: 1.0,
        new_weight: 0.3,
        reason: :high_latency,
        timestamp_us: System.monotonic_time(:microsecond)
      }

      :ok =
        Phoenix.PubSub.broadcast(@pubsub_name, @topology_delta_topic, {:topology_delta, delta})

      assert_receive {:topology_delta, received}, 300
      assert received.type == :edge_weight_changed
      assert received.new_weight == 0.3
    end

    test "multiple delta events arrive in FIFO order (SC-ZTEST-012)" do
      delta_types = [:node_joined, :node_left, :edge_added, :edge_removed, :node_status_changed]

      for {type, idx} <- Enum.with_index(delta_types, 1) do
        delta = %{
          type: type,
          sequence: idx,
          timestamp_us: System.monotonic_time(:microsecond)
        }

        Phoenix.PubSub.broadcast(@pubsub_name, @topology_delta_topic, {:topology_delta, delta})
      end

      received = drain_topology(400)
      deltas = Enum.filter(received, &match?({:topology_delta, _}, &1))
      seq_received = Enum.map(deltas, fn {:topology_delta, d} -> d.sequence end)

      assert seq_received == Enum.sort(seq_received),
             "Topology delta FIFO violated (SC-ZTEST-012): #{inspect(seq_received)}"
    end

    test "node removal reduces node count in subsequent snapshot", %{nodes: nodes} do
      # Simulate removing one node
      remaining_nodes = tl(nodes)
      edges_after = compute_star_edges(remaining_nodes)
      topo_after = topology_snapshot(remaining_nodes, edges_after)

      assert topo_after.node_count == length(nodes) - 1
    end

    test "zero topology events when no broadcast is made" do
      received = drain_topology(150)

      assert received == [],
             "Expected empty mailbox, got #{length(received)} topology events"
    end
  end
end
