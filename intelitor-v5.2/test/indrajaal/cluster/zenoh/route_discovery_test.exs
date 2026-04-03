defmodule Indrajaal.Cluster.Zenoh.RouteDiscoveryTest do
  @moduledoc """
  TDG-Compliant tests for RouteDiscovery module.

  Tests automatic topology discovery via Zenoh liveliness tokens.

  STAMP Constraints:
  - SC-ZENOH-DISC-001: Discovery within 5s of node join
  - SC-ZENOH-DISC-002: Liveliness tokens for presence detection
  - SC-ZENOH-DISC-003: Topology events published to mesh
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Cluster.Zenoh.RouteDiscovery

  describe "RouteDiscovery.start_link/1" do
    test "starts with default options" do
      assert {:ok, pid} = RouteDiscovery.start_link(name: :test_discovery_1)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "accepts custom liveliness prefix" do
      opts = [name: :test_discovery_2, liveliness_prefix: "test/nodes"]
      assert {:ok, pid} = RouteDiscovery.start_link(opts)

      state = :sys.get_state(pid)
      assert state.liveliness_prefix == "test/nodes"
      GenServer.stop(pid)
    end
  end

  describe "RouteDiscovery.get_topology/0" do
    test "SC-ZENOH-DISC-001: returns current topology" do
      {:ok, pid} = RouteDiscovery.start_link(name: :test_discovery_3)

      topology = RouteDiscovery.get_topology(pid)

      assert is_map(topology)
      assert Map.has_key?(topology, :nodes)
      assert Map.has_key?(topology, :edges)
      assert Map.has_key?(topology, :last_updated)

      GenServer.stop(pid)
    end

    test "includes local node in topology" do
      {:ok, pid} = RouteDiscovery.start_link(name: :test_discovery_4)

      topology = RouteDiscovery.get_topology(pid)
      local_node = to_string(node())

      assert local_node in topology.nodes

      GenServer.stop(pid)
    end
  end

  describe "RouteDiscovery.register_node/2" do
    test "SC-ZENOH-DISC-002: adds node to topology" do
      {:ok, pid} = RouteDiscovery.start_link(name: :test_discovery_5)

      node_info = %{
        node_id: "test-node-1",
        capabilities: [:alarms, :video],
        address: "192.168.1.100"
      }

      :ok = RouteDiscovery.register_node(pid, node_info)

      topology = RouteDiscovery.get_topology(pid)
      assert "test-node-1" in topology.nodes

      GenServer.stop(pid)
    end

    test "updates existing node info" do
      {:ok, pid} = RouteDiscovery.start_link(name: :test_discovery_6)

      node_info_v1 = %{node_id: "test-node-2", capabilities: [:alarms]}
      node_info_v2 = %{node_id: "test-node-2", capabilities: [:alarms, :video]}

      :ok = RouteDiscovery.register_node(pid, node_info_v1)
      :ok = RouteDiscovery.register_node(pid, node_info_v2)

      info = RouteDiscovery.get_node_info(pid, "test-node-2")
      assert :video in info.capabilities

      GenServer.stop(pid)
    end
  end

  describe "RouteDiscovery.unregister_node/2" do
    test "removes node from topology" do
      {:ok, pid} = RouteDiscovery.start_link(name: :test_discovery_7)

      node_info = %{node_id: "ephemeral-node", capabilities: []}
      :ok = RouteDiscovery.register_node(pid, node_info)

      topology_before = RouteDiscovery.get_topology(pid)
      assert "ephemeral-node" in topology_before.nodes

      :ok = RouteDiscovery.unregister_node(pid, "ephemeral-node")

      topology_after = RouteDiscovery.get_topology(pid)
      refute "ephemeral-node" in topology_after.nodes

      GenServer.stop(pid)
    end
  end

  describe "RouteDiscovery.find_nodes_with_capability/2" do
    test "finds nodes matching capability" do
      {:ok, pid} = RouteDiscovery.start_link(name: :test_discovery_8)

      :ok = RouteDiscovery.register_node(pid, %{node_id: "alarm-node", capabilities: [:alarms]})
      :ok = RouteDiscovery.register_node(pid, %{node_id: "video-node", capabilities: [:video]})

      :ok =
        RouteDiscovery.register_node(pid, %{
          node_id: "combo-node",
          capabilities: [:alarms, :video]
        })

      alarm_nodes = RouteDiscovery.find_nodes_with_capability(pid, :alarms)

      assert "alarm-node" in alarm_nodes
      assert "combo-node" in alarm_nodes
      refute "video-node" in alarm_nodes

      GenServer.stop(pid)
    end

    test "returns empty list for unknown capability" do
      {:ok, pid} = RouteDiscovery.start_link(name: :test_discovery_9)

      nodes = RouteDiscovery.find_nodes_with_capability(pid, :nonexistent)

      assert nodes == []

      GenServer.stop(pid)
    end
  end

  describe "RouteDiscovery.subscribe_to_changes/2" do
    test "SC-ZENOH-DISC-003: notifies on topology changes" do
      {:ok, pid} = RouteDiscovery.start_link(name: :test_discovery_10)

      :ok = RouteDiscovery.subscribe_to_changes(pid, self())

      :ok = RouteDiscovery.register_node(pid, %{node_id: "new-node", capabilities: []})

      assert_receive {:topology_change, :node_added, "new-node"}, 1000

      GenServer.stop(pid)
    end

    test "notifies on node removal" do
      {:ok, pid} = RouteDiscovery.start_link(name: :test_discovery_11)

      :ok = RouteDiscovery.register_node(pid, %{node_id: "leaving-node", capabilities: []})
      :ok = RouteDiscovery.subscribe_to_changes(pid, self())
      :ok = RouteDiscovery.unregister_node(pid, "leaving-node")

      assert_receive {:topology_change, :node_removed, "leaving-node"}, 1000

      GenServer.stop(pid)
    end
  end

  describe "RouteDiscovery.generate_liveliness_token/1" do
    test "generates valid liveliness token" do
      token = RouteDiscovery.generate_liveliness_token("my-node")

      assert is_binary(token)
      assert String.contains?(token, "my-node")
      assert String.starts_with?(token, "indrajaal/liveliness/")
    end

    test "includes timestamp in token" do
      token = RouteDiscovery.generate_liveliness_token("node-1")

      # Token format: indrajaal/liveliness/{node_id}/{timestamp}
      parts = String.split(token, "/")
      assert length(parts) >= 4
    end
  end

  describe "RouteDiscovery.parse_liveliness_token/1" do
    test "extracts node_id from token" do
      token = "indrajaal/liveliness/test-node/1_234_567_890"

      {:ok, info} = RouteDiscovery.parse_liveliness_token(token)

      assert info.node_id == "test-node"
      assert is_integer(info.timestamp)
    end

    test "returns error for invalid token" do
      invalid_token = "invalid/token/format"

      assert {:error, :invalid_token} = RouteDiscovery.parse_liveliness_token(invalid_token)
    end
  end

  describe "RouteDiscovery health and metrics" do
    test "reports healthy when running" do
      {:ok, pid} = RouteDiscovery.start_link(name: :test_discovery_12)

      health = RouteDiscovery.health(pid)

      assert health.status == :healthy
      assert is_integer(health.node_count)

      GenServer.stop(pid)
    end

    test "tracks discovery metrics" do
      {:ok, pid} = RouteDiscovery.start_link(name: :test_discovery_13)

      :ok = RouteDiscovery.register_node(pid, %{node_id: "n1", capabilities: []})
      :ok = RouteDiscovery.register_node(pid, %{node_id: "n2", capabilities: []})

      metrics = RouteDiscovery.metrics(pid)

      assert metrics.total_discoveries >= 2
      assert metrics.active_nodes >= 2

      GenServer.stop(pid)
    end
  end

  # Property tests
  test "property: node registration is idempotent" do
    test_cases = ["node-a", "node-b", "test-123", "special_chars-node"]

    for {node_id, idx} <- Enum.with_index(test_cases) do
      name = String.to_atom("test_discovery_prop_#{idx}")
      {:ok, pid} = RouteDiscovery.start_link(name: name)

      node_info = %{node_id: node_id, capabilities: [:test]}

      # Register same node multiple times
      :ok = RouteDiscovery.register_node(pid, node_info)
      :ok = RouteDiscovery.register_node(pid, node_info)
      :ok = RouteDiscovery.register_node(pid, node_info)

      topology = RouteDiscovery.get_topology(pid)
      count = Enum.count(topology.nodes, &(&1 == node_id))

      GenServer.stop(pid)

      # Should only appear once
      assert count == 1
    end
  end
end
