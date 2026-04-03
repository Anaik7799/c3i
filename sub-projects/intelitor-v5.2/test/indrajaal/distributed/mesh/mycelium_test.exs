defmodule Indrajaal.Distributed.Mesh.MyceliumTest do
  @moduledoc """
  Tests for Indrajaal.Distributed.Mesh.Mycelium.

  WHAT: Validates mycelium mesh networking lifecycle and node management.
  WHY: SC-MYC-001 requires mesh connectivity; nodes/0 is called by Gossip and Holography.
  CONSTRAINTS: GenServer registered as __MODULE__; async: false to prevent name conflicts.
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Distributed.Mesh.Mycelium

  setup do
    # Stop any existing Mycelium process to get a clean slate
    case Process.whereis(Mycelium) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 1000)
    end

    {:ok, pid} = start_supervised({Mycelium, []})
    %{pid: pid}
  end

  describe "start_link/1" do
    test "starts the GenServer and registers it under __MODULE__", %{pid: pid} do
      assert is_pid(pid)
      assert Process.alive?(pid)
      assert Process.whereis(Mycelium) == pid
    end
  end

  describe "nodes/0" do
    test "returns an empty list when no peers have joined" do
      result = Mycelium.nodes()
      assert is_list(result)
      assert result == []
    end

    test "returns a list even after calling nodes/0 multiple times" do
      assert is_list(Mycelium.nodes())
      assert is_list(Mycelium.nodes())
    end
  end

  describe "join/2" do
    test "returns :ok when joining a valid seed address and port" do
      result = Mycelium.join("127.0.0.1", 4369)
      assert result == :ok
    end

    test "adds the seed node to the known nodes list after join" do
      assert Mycelium.nodes() == []
      :ok = Mycelium.join("127.0.0.1", 5001)
      nodes = Mycelium.nodes()
      assert length(nodes) == 1
    end

    test "returns {:error, :invalid_seed_address} for invalid address" do
      result = Mycelium.join(nil, 4369)
      assert match?({:error, _}, result)
    end

    test "returns {:error, :invalid_seed_address} for port 0" do
      result = Mycelium.join("127.0.0.1", 0)
      assert match?({:error, _}, result)
    end

    test "can join multiple seeds" do
      :ok = Mycelium.join("192.168.1.1", 4370)
      :ok = Mycelium.join("192.168.1.2", 4371)
      nodes = Mycelium.nodes()
      assert length(nodes) == 2
    end
  end

  describe "leave/0" do
    test "returns :ok when leaving" do
      result = Mycelium.leave()
      assert result == :ok
    end

    test "clears all known nodes after leaving" do
      Mycelium.join("127.0.0.1", 4369)
      assert length(Mycelium.nodes()) == 1
      :ok = Mycelium.leave()
      assert Mycelium.nodes() == []
    end

    test "leave is idempotent when already disconnected" do
      assert Mycelium.leave() == :ok
      assert Mycelium.leave() == :ok
    end
  end

  describe "get_node/1" do
    test "returns {:error, :not_found} for an unknown node ID" do
      assert {:error, :not_found} = Mycelium.get_node("nonexistent_node_id")
    end

    test "returns {:ok, node_info} after joining the seed" do
      Mycelium.join("127.0.0.1", 5002)
      nodes = Mycelium.nodes()
      assert [node_info | _] = nodes
      assert {:ok, found} = Mycelium.get_node(node_info.id)
      assert found.id == node_info.id
    end
  end

  describe "topology/0" do
    test "returns a map with :self, :nodes, :connections keys" do
      result = Mycelium.topology()
      assert is_map(result)
      assert Map.has_key?(result, :self)
      assert Map.has_key?(result, :nodes)
      assert Map.has_key?(result, :connections)
    end

    test ":connections is initially an empty list" do
      result = Mycelium.topology()
      assert result.connections == []
    end

    test ":nodes is a list of node summaries" do
      Mycelium.join("127.0.0.1", 5003)
      result = Mycelium.topology()
      assert is_list(result.nodes)
      assert length(result.nodes) == 1
    end
  end

  describe "stats/0" do
    test "returns a map with required metric keys" do
      result = Mycelium.stats()
      assert is_map(result)
      assert Map.has_key?(result, :self_id)
      assert Map.has_key?(result, :num_nodes)
      assert Map.has_key?(result, :num_connections)
    end

    test "initial stats show zero nodes and connections" do
      result = Mycelium.stats()
      assert result.num_nodes == 0
      assert result.num_connections == 0
    end

    test "stats reflect joined nodes" do
      Mycelium.join("10.0.0.1", 5004)
      result = Mycelium.stats()
      assert result.num_nodes == 1
    end

    test "alive_nodes, suspected_nodes, dead_nodes are present" do
      result = Mycelium.stats()
      assert Map.has_key?(result, :alive_nodes)
      assert Map.has_key?(result, :suspected_nodes)
      assert Map.has_key?(result, :dead_nodes)
    end
  end

  describe "send_message/2" do
    test "returns {:error, :unknown_node} for an unknown target" do
      result = Mycelium.send_message("nonexistent_node", %{data: "hello"})
      assert result == {:error, :unknown_node}
    end
  end

  describe "broadcast/1" do
    test "returns :ok when broadcasting with no peers" do
      # broadcast is a cast, so GenServer.cast always returns :ok
      result = Mycelium.broadcast(%{type: :announcement, data: "test"})
      assert result == :ok
    end
  end

  describe "register_handler/2" do
    test "registers a handler without error" do
      handler = fn _from, _payload -> :ok end
      result = Mycelium.register_handler(:test_message, handler)
      assert result == :ok
    end

    test "multiple handlers for different types can be registered" do
      h1 = fn _from, _payload -> :handled end
      h2 = fn _from, _payload -> :handled_too end
      assert Mycelium.register_handler(:type_a, h1) == :ok
      assert Mycelium.register_handler(:type_b, h2) == :ok
    end
  end
end
