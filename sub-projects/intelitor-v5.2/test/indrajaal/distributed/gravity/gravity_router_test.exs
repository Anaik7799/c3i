defmodule Indrajaal.Distributed.Gravity.GravityRouterTest do
  @moduledoc """
  TDG-Compliant tests for GravityRouter module.

  Tests affinity-based routing decisions using data gravity.

  STAMP Constraints:
  - SC-GRAV-003: Affinity calculation < 1ms
  - SC-GRAV-004: Route decision logged for audit
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Distributed.Gravity.{GravityRouter, LocalityRegistry}

  describe "GravityRouter.start_link/1" do
    test "starts with default options" do
      {:ok, reg} = LocalityRegistry.start_link(name: :test_gr_reg_1)
      assert {:ok, pid} = GravityRouter.start_link(name: :test_gr_1, registry: reg)
      assert Process.alive?(pid)
      GenServer.stop(pid)
      GenServer.stop(reg)
    end
  end

  describe "GravityRouter.route/3" do
    test "returns local node for local data" do
      {:ok, reg} = LocalityRegistry.start_link(name: :test_gr_reg_2)
      {:ok, router} = GravityRouter.start_link(name: :test_gr_2, registry: reg)

      local_node = to_string(node())
      LocalityRegistry.register(reg, "local/data", local_node, %{size_bytes: 1000})

      decision = GravityRouter.route(router, "local/data", local_node)

      assert decision.target_node == local_node
      assert decision.decision == :local
      GenServer.stop(router)
      GenServer.stop(reg)
    end

    test "returns remote node for high gravity remote data" do
      {:ok, reg} = LocalityRegistry.start_link(name: :test_gr_reg_3)
      {:ok, router} = GravityRouter.start_link(name: :test_gr_3, registry: reg)

      # Use high gravity data (large size, many accesses)
      LocalityRegistry.register(reg, "remote/data", "node-1@remote-host", %{
        size_bytes: 500_000_000,
        access_count: 5000
      })

      decision = GravityRouter.route(router, "remote/data", "node-local@local-host")

      assert decision.target_node == "node-1@remote-host"
      assert decision.decision == :route_to_data
      GenServer.stop(router)
      GenServer.stop(reg)
    end

    test "fetches low gravity remote data locally" do
      {:ok, reg} = LocalityRegistry.start_link(name: :test_gr_reg_3b)
      {:ok, router} = GravityRouter.start_link(name: :test_gr_3b, registry: reg)

      # Use low gravity data
      LocalityRegistry.register(reg, "remote/data", "node-1@remote-host", %{
        size_bytes: 1000,
        access_count: 1
      })

      decision = GravityRouter.route(router, "remote/data", "node-local@local-host")

      # Low gravity - fetch data to compute node
      assert decision.target_node == "node-local@local-host"
      assert decision.decision == :fetch_data
      GenServer.stop(router)
      GenServer.stop(reg)
    end

    test "prefers high gravity data stay in place" do
      {:ok, reg} = LocalityRegistry.start_link(name: :test_gr_reg_4)
      {:ok, router} = GravityRouter.start_link(name: :test_gr_4, registry: reg)

      # Register large, frequently accessed data (500MB, 10k accesses = gravity ~0.65)
      LocalityRegistry.register(reg, "heavy/data", "node-data@host", %{
        size_bytes: 500_000_000,
        access_count: 10_000
      })

      decision = GravityRouter.route(router, "heavy/data", "node-compute@host")

      # High gravity data should attract compute
      assert decision.decision == :route_to_data
      assert decision.gravity > 0.3
      GenServer.stop(router)
      GenServer.stop(reg)
    end
  end

  describe "GravityRouter.compute_affinity/4" do
    test "SC-GRAV-003: affinity calculation is fast" do
      {:ok, reg} = LocalityRegistry.start_link(name: :test_gr_reg_5)
      {:ok, router} = GravityRouter.start_link(name: :test_gr_5, registry: reg)

      LocalityRegistry.register(reg, "perf/key", "node-1", %{size_bytes: 1000})

      {time_us, _result} =
        :timer.tc(fn ->
          GravityRouter.compute_affinity(router, "perf/key", "node-1", "node-2")
        end)

      # Should complete in < 1ms
      assert time_us < 1000
      GenServer.stop(router)
      GenServer.stop(reg)
    end

    test "same location has high affinity" do
      {:ok, reg} = LocalityRegistry.start_link(name: :test_gr_reg_6)
      {:ok, router} = GravityRouter.start_link(name: :test_gr_6, registry: reg)

      LocalityRegistry.register(reg, "data/key", "node-1", %{size_bytes: 1000})

      affinity = GravityRouter.compute_affinity(router, "data/key", "node-1", "node-1")

      assert affinity == 1.0
      GenServer.stop(router)
      GenServer.stop(reg)
    end

    test "different location has lower affinity" do
      {:ok, reg} = LocalityRegistry.start_link(name: :test_gr_reg_7)
      {:ok, router} = GravityRouter.start_link(name: :test_gr_7, registry: reg)

      LocalityRegistry.register(reg, "data/key", "node-1@dc-west", %{size_bytes: 1000})

      affinity =
        GravityRouter.compute_affinity(router, "data/key", "node-1@dc-west", "node-2@dc-east")

      assert affinity < 1.0
      GenServer.stop(router)
      GenServer.stop(reg)
    end
  end

  describe "GravityRouter.should_move_compute/3" do
    test "returns true for high gravity data" do
      {:ok, reg} = LocalityRegistry.start_link(name: :test_gr_reg_8)
      {:ok, router} = GravityRouter.start_link(name: :test_gr_8, registry: reg)

      LocalityRegistry.register(reg, "heavy/data", "node-data", %{
        size_bytes: 500_000_000,
        access_count: 10_000
      })

      assert GravityRouter.should_move_compute?(router, "heavy/data", "node-compute")
      GenServer.stop(router)
      GenServer.stop(reg)
    end

    test "returns false for low gravity data" do
      {:ok, reg} = LocalityRegistry.start_link(name: :test_gr_reg_9)
      {:ok, router} = GravityRouter.start_link(name: :test_gr_9, registry: reg)

      LocalityRegistry.register(reg, "light/data", "node-data", %{
        size_bytes: 100,
        access_count: 1
      })

      refute GravityRouter.should_move_compute?(router, "light/data", "node-compute")
      GenServer.stop(router)
      GenServer.stop(reg)
    end
  end

  describe "GravityRouter.get_routing_decision_log/2" do
    test "SC-GRAV-004: logs routing decisions for audit" do
      {:ok, reg} = LocalityRegistry.start_link(name: :test_gr_reg_10)
      {:ok, router} = GravityRouter.start_link(name: :test_gr_10, registry: reg)

      LocalityRegistry.register(reg, "audit/key", "node-1", %{size_bytes: 1000})

      # Make a routing decision
      GravityRouter.route(router, "audit/key", "node-local")

      # Get decision log
      log = GravityRouter.get_routing_decision_log(router, "audit/key")

      assert length(log) >= 1
      [latest | _] = log
      assert latest.key == "audit/key"
      assert is_binary(latest.timestamp)
      GenServer.stop(router)
      GenServer.stop(reg)
    end
  end

  describe "GravityRouter.metrics/1" do
    test "returns routing metrics" do
      {:ok, reg} = LocalityRegistry.start_link(name: :test_gr_reg_11)
      {:ok, router} = GravityRouter.start_link(name: :test_gr_11, registry: reg)

      metrics = GravityRouter.metrics(router)

      assert is_map(metrics)
      assert Map.has_key?(metrics, :total_decisions)
      assert Map.has_key?(metrics, :local_decisions)
      assert Map.has_key?(metrics, :remote_decisions)
      GenServer.stop(router)
      GenServer.stop(reg)
    end
  end

  describe "GravityRouter.health/1" do
    test "returns health status" do
      {:ok, reg} = LocalityRegistry.start_link(name: :test_gr_reg_12)
      {:ok, router} = GravityRouter.start_link(name: :test_gr_12, registry: reg)

      health = GravityRouter.health(router)

      assert health.status == :healthy
      GenServer.stop(router)
      GenServer.stop(reg)
    end
  end
end
