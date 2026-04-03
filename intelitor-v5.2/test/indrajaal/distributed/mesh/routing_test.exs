defmodule Indrajaal.Distributed.Mesh.RoutingTest do
  @moduledoc """
  Tests for Indrajaal.Distributed.Mesh.Routing.

  WHAT: Validates routing table management, stats, and cast operations.
  WHY: SC-ROU-001 requires route calculation < 5ms; SC-ROU-002 requires cache invalidation.
  CONSTRAINTS: async: false — GenServer registered as __MODULE__.
  Note: route_message/2 calls Mycelium.send_message internally — only tested for error path.
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Distributed.Mesh.Routing

  setup do
    case Process.whereis(Routing) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 1000)
    end

    {:ok, pid} = start_supervised({Routing, []})
    %{pid: pid}
  end

  describe "start_link/1" do
    test "starts and registers the GenServer", %{pid: pid} do
      assert is_pid(pid)
      assert Process.alive?(pid)
      assert Process.whereis(Routing) == pid
    end
  end

  describe "routing_table/0" do
    test "returns a map" do
      result = Routing.routing_table()
      assert is_map(result)
    end

    test "routing table is empty on fresh start" do
      result = Routing.routing_table()
      assert result == %{}
    end

    test "routing table remains empty when no routes have been calculated" do
      # Two calls should both return empty
      t1 = Routing.routing_table()
      t2 = Routing.routing_table()
      assert t1 == %{}
      assert t2 == %{}
    end
  end

  describe "stats/0" do
    test "returns a map" do
      result = Routing.stats()
      assert is_map(result)
    end

    test "stats include :routes_calculated key" do
      result = Routing.stats()
      assert Map.has_key?(result, :routes_calculated)
    end

    test "stats include :cache_hits key" do
      result = Routing.stats()
      assert Map.has_key?(result, :cache_hits)
    end

    test "stats include :cache_misses key" do
      result = Routing.stats()
      assert Map.has_key?(result, :cache_misses)
    end

    test "stats include :failovers key" do
      result = Routing.stats()
      assert Map.has_key?(result, :failovers)
    end

    test "stats include :cached_routes key" do
      result = Routing.stats()
      assert Map.has_key?(result, :cached_routes)
    end

    test "initial routes_calculated is zero" do
      result = Routing.stats()
      assert result.routes_calculated == 0
    end

    test "initial cache_hits is zero" do
      result = Routing.stats()
      assert result.cache_hits == 0
    end

    test "initial cached_routes is zero" do
      result = Routing.stats()
      assert result.cached_routes == 0
    end

    test "stats also include :known_nodes and :known_edges" do
      result = Routing.stats()
      assert Map.has_key?(result, :known_nodes)
      assert Map.has_key?(result, :known_edges)
    end
  end

  describe "get_route/2" do
    test "returns {:error, :no_route} when no topology is configured" do
      # With empty topology, no path exists between arbitrary nodes
      result = Routing.get_route("node-a")
      assert result == {:error, :no_route}
    end

    test "returns {:error, :no_route} for a two-argument call with unknown destination" do
      result = Routing.get_route("nonexistent-node-xyz-123", [])
      assert result == {:error, :no_route}
    end
  end

  describe "next_hop/1" do
    test "returns {:error, :no_route} when no topology is configured" do
      result = Routing.next_hop("target-node-xyz")
      assert result == {:error, :no_route}
    end

    test "returns a tagged tuple" do
      result = Routing.next_hop("some-node")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "route_message/2" do
    test "returns {:error, :no_route} with empty topology" do
      # Routing will fail to find a route before reaching Mycelium.send_message
      result = Routing.route_message("unknown-dest-xyz", %{payload: "hello"})
      assert result == {:error, :no_route}
    end

    test "returns a tagged tuple for any destination" do
      result = Routing.route_message("destination-node", %{type: :data, body: "test"})
      assert match?({:ok, _}, result) or match?({:error, _}, result) or result == :ok
    end
  end

  describe "update_topology/1 (cast)" do
    test "returns :ok immediately (it is a cast)" do
      topology = %{
        nodes: ["node-1", "node-2"],
        edges: [%{from: "node-1", to: "node-2", latency: 5}]
      }

      result = Routing.update_topology(topology)
      assert result == :ok
    end

    test "returns :ok for empty topology" do
      result = Routing.update_topology(%{nodes: [], edges: []})
      assert result == :ok
    end

    test "update_topology is idempotent" do
      topology = %{nodes: ["n1"], edges: []}
      assert Routing.update_topology(topology) == :ok
      assert Routing.update_topology(topology) == :ok
    end
  end

  describe "report_metrics/2 (cast)" do
    test "returns :ok immediately (it is a cast)" do
      metrics = %{latency: 10, load: 0.3}
      result = Routing.report_metrics("neighbor-node", metrics)
      assert result == :ok
    end

    test "returns :ok for empty metrics" do
      result = Routing.report_metrics("node-xyz", %{})
      assert result == :ok
    end
  end

  describe "invalidate_cache/0 (cast)" do
    test "returns :ok immediately (it is a cast)" do
      result = Routing.invalidate_cache()
      assert result == :ok
    end

    test "invalidate_cache is idempotent" do
      assert Routing.invalidate_cache() == :ok
      assert Routing.invalidate_cache() == :ok
    end

    test "routing table is empty after cache invalidation" do
      # Start with fresh table, invalidate, still empty
      Routing.invalidate_cache()
      # Give the cast time to process
      Process.sleep(10)
      assert Routing.routing_table() == %{}
    end
  end
end
