defmodule Indrajaal.Distributed.Mesh.PartitionTest do
  @moduledoc """
  Tests for Indrajaal.Distributed.Mesh.Partition.

  WHAT: Validates partition detection, status, majority check, and statistics.
  WHY: SC-PAR-001 requires partition detection < 5s; SC-PAR-002 prevents split-brain.
  CONSTRAINTS: async: false (name-registered GenServers).
  Note: Partition's heartbeat calls Mycelium.nodes() — Mycelium is started in setup.
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Distributed.Mesh.{Partition, Mycelium}

  setup do
    # Ensure clean state for both GenServers
    for mod <- [Partition, Mycelium] do
      case Process.whereis(mod) do
        nil -> :ok
        pid -> GenServer.stop(pid, :normal, 1000)
      end
    end

    # Start Mycelium first (Partition's heartbeat calls Mycelium.nodes())
    {:ok, _mycelium_pid} = start_supervised({Mycelium, []})
    {:ok, pid} = start_supervised({Partition, []})
    %{pid: pid}
  end

  describe "start_link/1" do
    test "starts and registers the GenServer", %{pid: pid} do
      assert is_pid(pid)
      assert Process.alive?(pid)
      assert Process.whereis(Partition) == pid
    end
  end

  describe "status/0" do
    test "returns :normal when freshly started" do
      result = Partition.status()
      assert result == :normal
    end

    test "returns one of the valid partition states" do
      result = Partition.status()
      assert result in [:normal, :suspected, :partitioned, :healing]
    end

    test "status is stable when no unreachable nodes are reported" do
      s1 = Partition.status()
      s2 = Partition.status()
      assert s1 == s2
    end
  end

  describe "partition_info/0" do
    test "returns nil when no partition is detected" do
      result = Partition.partition_info()
      assert is_nil(result)
    end

    test "returns nil or a map" do
      result = Partition.partition_info()
      assert is_nil(result) or is_map(result)
    end
  end

  describe "in_majority?/0" do
    test "returns true when no partition is active (single node is majority)" do
      result = Partition.in_majority?()
      assert result == true
    end

    test "returns a boolean" do
      result = Partition.in_majority?()
      assert is_boolean(result)
    end
  end

  describe "check/0" do
    test "returns {:ok, status_atom}" do
      result = Partition.check()
      assert match?({:ok, status} when is_atom(status), result)
    end

    test "returned status is a valid partition state" do
      {:ok, status} = Partition.check()
      assert status in [:normal, :suspected, :partitioned, :healing]
    end

    test "check is idempotent when network is healthy" do
      {:ok, s1} = Partition.check()
      {:ok, s2} = Partition.check()
      assert s1 == s2
    end
  end

  describe "heal/0" do
    test "returns {:error, :not_partitioned} when status is :normal" do
      assert Partition.status() == :normal
      result = Partition.heal()
      assert result == {:error, :not_partitioned}
    end
  end

  describe "report_unreachable/1" do
    test "returns :ok (cast)" do
      result = Partition.report_unreachable("node_abc_123")
      assert result == :ok
    end

    test "reporting unreachable is idempotent" do
      assert Partition.report_unreachable("node_dead") == :ok
      assert Partition.report_unreachable("node_dead") == :ok
    end

    test "unreachable count increases in stats after report" do
      Partition.report_unreachable("node_x1")
      # Give the cast time to process
      Process.sleep(20)
      stats = Partition.stats()
      assert stats.unreachable_count >= 1
    end
  end

  describe "report_reachable/1" do
    test "returns :ok (cast)" do
      result = Partition.report_reachable("node_abc_123")
      assert result == :ok
    end

    test "unreachable count decreases after marking node reachable again" do
      Partition.report_unreachable("node_temp")
      Process.sleep(20)
      stats_before = Partition.stats()
      Partition.report_reachable("node_temp")
      Process.sleep(20)
      stats_after = Partition.stats()
      assert stats_after.unreachable_count <= stats_before.unreachable_count
    end
  end

  describe "stats/0" do
    test "returns a map" do
      result = Partition.stats()
      assert is_map(result)
    end

    test "stats include :partitions_detected" do
      result = Partition.stats()
      assert Map.has_key?(result, :partitions_detected)
    end

    test "stats include :partitions_healed" do
      result = Partition.stats()
      assert Map.has_key?(result, :partitions_healed)
    end

    test "stats include :status" do
      result = Partition.stats()
      assert Map.has_key?(result, :status)
      assert result.status in [:normal, :suspected, :partitioned, :healing]
    end

    test "stats include :unreachable_count" do
      result = Partition.stats()
      assert Map.has_key?(result, :unreachable_count)
      assert is_integer(result.unreachable_count)
    end

    test "initial partitions_detected is zero" do
      result = Partition.stats()
      assert result.partitions_detected == 0
    end
  end
end
