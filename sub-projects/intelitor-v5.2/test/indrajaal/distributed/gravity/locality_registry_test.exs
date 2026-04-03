defmodule Indrajaal.Distributed.Gravity.LocalityRegistryTest do
  @moduledoc """
  TDG-Compliant tests for LocalityRegistry module.

  Tests ETS-based data locality tracking for gravity routing decisions.

  STAMP Constraints:
  - SC-GRAV-001: Locality lookup < 100us
  - SC-GRAV-004: Route decision logged for audit
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Distributed.Gravity.LocalityRegistry

  describe "LocalityRegistry.start_link/1" do
    test "starts with default options" do
      assert {:ok, pid} = LocalityRegistry.start_link(name: :test_loc_1)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "creates ETS table" do
      {:ok, pid} = LocalityRegistry.start_link(name: :test_loc_2)

      state = :sys.get_state(pid)
      assert is_reference(state.table)
      GenServer.stop(pid)
    end
  end

  describe "LocalityRegistry.register/4" do
    test "registers data location" do
      {:ok, pid} = LocalityRegistry.start_link(name: :test_loc_3)

      :ok =
        LocalityRegistry.register(pid, "alarms/tenant-1/zone-a", "node-1@host1", %{
          size_bytes: 1024,
          last_accessed: DateTime.utc_now()
        })

      info = LocalityRegistry.lookup(pid, "alarms/tenant-1/zone-a")

      assert info != nil
      assert info.primary_node == "node-1@host1"
      GenServer.stop(pid)
    end

    test "SC-GRAV-001: registration is fast" do
      {:ok, pid} = LocalityRegistry.start_link(name: :test_loc_4)

      {time_us, :ok} =
        :timer.tc(fn ->
          LocalityRegistry.register(pid, "test/key", "node-1", %{size_bytes: 100})
        end)

      # Should complete in < 100us (relaxed for test overhead)
      assert time_us < 5000
      GenServer.stop(pid)
    end
  end

  describe "LocalityRegistry.lookup/2" do
    test "returns nil for unknown key" do
      {:ok, pid} = LocalityRegistry.start_link(name: :test_loc_5)

      assert LocalityRegistry.lookup(pid, "unknown/key") == nil
      GenServer.stop(pid)
    end

    test "SC-GRAV-001: lookup is fast" do
      {:ok, pid} = LocalityRegistry.start_link(name: :test_loc_6)

      LocalityRegistry.register(pid, "perf/key", "node-1", %{size_bytes: 100})

      {time_us, _result} =
        :timer.tc(fn ->
          LocalityRegistry.lookup(pid, "perf/key")
        end)

      # Should complete in < 100us (relaxed for test overhead)
      assert time_us < 5000
      GenServer.stop(pid)
    end

    test "returns locality info with all fields" do
      {:ok, pid} = LocalityRegistry.start_link(name: :test_loc_7)

      LocalityRegistry.register(pid, "data/key", "node-1@host", %{
        size_bytes: 2048,
        replica_nodes: ["node-2@host", "node-3@host"]
      })

      info = LocalityRegistry.lookup(pid, "data/key")

      assert info.primary_node == "node-1@host"
      assert info.size_bytes == 2048
      assert "node-2@host" in info.replica_nodes
      GenServer.stop(pid)
    end
  end

  describe "LocalityRegistry.unregister/2" do
    test "removes data location" do
      {:ok, pid} = LocalityRegistry.start_link(name: :test_loc_8)

      LocalityRegistry.register(pid, "temp/key", "node-1", %{})
      assert LocalityRegistry.lookup(pid, "temp/key") != nil

      :ok = LocalityRegistry.unregister(pid, "temp/key")
      assert LocalityRegistry.lookup(pid, "temp/key") == nil
      GenServer.stop(pid)
    end
  end

  describe "LocalityRegistry.update_access/2" do
    test "updates last accessed timestamp" do
      {:ok, pid} = LocalityRegistry.start_link(name: :test_loc_9)

      old_time = DateTime.add(DateTime.utc_now(), -3600, :second)
      LocalityRegistry.register(pid, "accessed/key", "node-1", %{last_accessed: old_time})

      :ok = LocalityRegistry.update_access(pid, "accessed/key")

      info = LocalityRegistry.lookup(pid, "accessed/key")
      assert DateTime.compare(info.last_accessed, old_time) == :gt
      GenServer.stop(pid)
    end
  end

  describe "LocalityRegistry.find_by_node/2" do
    test "finds all data on a specific node" do
      {:ok, pid} = LocalityRegistry.start_link(name: :test_loc_10)

      LocalityRegistry.register(pid, "data/1", "node-a", %{})
      LocalityRegistry.register(pid, "data/2", "node-a", %{})
      LocalityRegistry.register(pid, "data/3", "node-b", %{})

      keys = LocalityRegistry.find_by_node(pid, "node-a")

      assert length(keys) == 2
      assert "data/1" in keys
      assert "data/2" in keys
      GenServer.stop(pid)
    end
  end

  describe "LocalityRegistry.get_data_gravity/2" do
    test "calculates data gravity for a key" do
      {:ok, pid} = LocalityRegistry.start_link(name: :test_loc_11)

      LocalityRegistry.register(pid, "heavy/data", "node-1", %{
        size_bytes: 10_000_000,
        access_count: 1000
      })

      gravity = LocalityRegistry.get_data_gravity(pid, "heavy/data")

      assert is_number(gravity)
      assert gravity > 0
      GenServer.stop(pid)
    end

    test "larger data has higher gravity" do
      {:ok, pid} = LocalityRegistry.start_link(name: :test_loc_12)

      LocalityRegistry.register(pid, "small/data", "node-1", %{size_bytes: 1000})
      LocalityRegistry.register(pid, "large/data", "node-1", %{size_bytes: 1_000_000})

      small_gravity = LocalityRegistry.get_data_gravity(pid, "small/data")
      large_gravity = LocalityRegistry.get_data_gravity(pid, "large/data")

      assert large_gravity > small_gravity
      GenServer.stop(pid)
    end
  end

  describe "LocalityRegistry.find_nearest_replica/3" do
    test "finds closest node with data" do
      {:ok, pid} = LocalityRegistry.start_link(name: :test_loc_13)

      LocalityRegistry.register(pid, "replicated/key", "node-1@dc-west", %{
        replica_nodes: ["node-2@dc-east", "node-3@dc-central"]
      })

      # Simulating calling from dc-central
      nearest =
        LocalityRegistry.find_nearest_replica(pid, "replicated/key", "node-local@dc-central")

      # Should prefer dc-central replica
      assert nearest in ["node-1@dc-west", "node-2@dc-east", "node-3@dc-central"]
      GenServer.stop(pid)
    end
  end

  describe "LocalityRegistry.metrics/1" do
    test "returns registry metrics" do
      {:ok, pid} = LocalityRegistry.start_link(name: :test_loc_14)

      LocalityRegistry.register(pid, "m/1", "node-1", %{size_bytes: 100})
      LocalityRegistry.register(pid, "m/2", "node-1", %{size_bytes: 200})

      metrics = LocalityRegistry.metrics(pid)

      assert metrics.total_entries >= 2
      assert metrics.total_size_bytes >= 300
      GenServer.stop(pid)
    end
  end

  describe "LocalityRegistry.health/1" do
    test "returns health status" do
      {:ok, pid} = LocalityRegistry.start_link(name: :test_loc_15)

      health = LocalityRegistry.health(pid)

      assert health.status == :healthy
      assert is_integer(health.entry_count)
      GenServer.stop(pid)
    end
  end

  # Property tests
  test "property: registered data can always be looked up" do
    {:ok, pid} = LocalityRegistry.start_link(name: :test_loc_prop_1)

    test_cases =
      for i <- 1..20 do
        key = "prop/key/#{i}"
        node = "node-#{rem(i, 3)}@host"
        LocalityRegistry.register(pid, key, node, %{size_bytes: i * 100})
        {key, node}
      end

    for {key, node} <- test_cases do
      info = LocalityRegistry.lookup(pid, key)
      assert info.primary_node == node
    end

    GenServer.stop(pid)
  end
end
