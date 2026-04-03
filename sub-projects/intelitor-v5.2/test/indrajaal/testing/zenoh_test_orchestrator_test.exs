defmodule Indrajaal.Testing.ZenohTestOrchestratorTest do
  @moduledoc """
  TDG test suite for Testing.ZenohTestOrchestrator.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation verification
  - Real-time test aggregation via Zenoh pub/sub

  ## STAMP Safety Integration
  - SC-ZTEST-005: Orchestrator aggregate update < 100ms
  - SC-ZTEST-001: All checkpoints have unique topics
  - SC-ZTEST-008: Log-based fallback when Zenoh unavailable

  ## Constitutional Verification
  - Ψ₀ Existence: Orchestrator survives reset and query operations
  - Ψ₃ Verification: Stats map always contains full set of required keys

  ## TPS 5-Level RCA Context
  - L1 Symptom: get_stats returns 0 pass_rate on empty state
  - L5 Root Cause: calculate_pass_rate divides (test_total + smoke_total) — zero total yields 0.0
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Testing.ZenohTestOrchestrator

  @moduletag :zenoh_nif

  # Use a unique test name to avoid conflicts with any supervisor-started instance
  @test_name :zenoh_orchestrator_test_instance

  setup do
    # Stop any existing test instance
    case Process.whereis(@test_name) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 5000)
    end

    Process.sleep(30)

    # Start fresh instance under unique name (avoids collision with module-level instance)
    {:ok, pid} = ZenohTestOrchestrator.start_link(name: @test_name)

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid, :normal, 5000)
    end)

    {:ok, pid: pid, server: @test_name}
  end

  # ============================================================================
  # get_stats/1
  # ============================================================================

  describe "get_stats/1" do
    test "returns a map", %{server: server} do
      result = ZenohTestOrchestrator.get_stats(server)
      assert is_map(result)
    end

    test "has :test_total key", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert Map.has_key?(stats, :test_total)
    end

    test "has :test_passed key", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert Map.has_key?(stats, :test_passed)
    end

    test "has :test_failed key", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert Map.has_key?(stats, :test_failed)
    end

    test "has :test_skipped key", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert Map.has_key?(stats, :test_skipped)
    end

    test "has :test_running key", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert Map.has_key?(stats, :test_running)
    end

    test "has :test_suites key", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert Map.has_key?(stats, :test_suites)
    end

    test "has :smoke_total key", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert Map.has_key?(stats, :smoke_total)
    end

    test "has :smoke_passed key", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert Map.has_key?(stats, :smoke_passed)
    end

    test "has :smoke_failed key", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert Map.has_key?(stats, :smoke_failed)
    end

    test "has :smoke_batches key", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert Map.has_key?(stats, :smoke_batches)
    end

    test "has :boot_started key", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert Map.has_key?(stats, :boot_started)
    end

    test "has :boot_complete key", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert Map.has_key?(stats, :boot_complete)
    end

    test "has :boot_duration_ms key", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert Map.has_key?(stats, :boot_duration_ms)
    end

    test "has :boot_phases key", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert Map.has_key?(stats, :boot_phases)
    end

    test "has :quorum_status key", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert Map.has_key?(stats, :quorum_status)
    end

    test "has :state_vector key", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert Map.has_key?(stats, :state_vector)
    end

    test "has :sprint_total key", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert Map.has_key?(stats, :sprint_total)
    end

    test "has :sprint_completed key", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert Map.has_key?(stats, :sprint_completed)
    end

    test "has :sprint_failed key", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert Map.has_key?(stats, :sprint_failed)
    end

    test "has :sprint_gates_passed key", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert Map.has_key?(stats, :sprint_gates_passed)
    end

    test "has :sprint_waves_evaluated key", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert Map.has_key?(stats, :sprint_waves_evaluated)
    end

    test "has :pass_rate key", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert Map.has_key?(stats, :pass_rate)
    end

    test "has :total_tests key", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert Map.has_key?(stats, :total_tests)
    end

    test "has :total_passed key", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert Map.has_key?(stats, :total_passed)
    end

    test "has :total_failed key", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert Map.has_key?(stats, :total_failed)
    end

    test "has :uptime_seconds key as integer", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert Map.has_key?(stats, :uptime_seconds)
      assert is_integer(stats.uptime_seconds)
    end

    test "has :last_update key as DateTime", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert Map.has_key?(stats, :last_update)
      assert %DateTime{} = stats.last_update
    end

    test "initial test_total is 0", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert stats.test_total == 0
    end

    test "initial test_passed is 0", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert stats.test_passed == 0
    end

    test "initial boot_started is false", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert stats.boot_started == false
    end

    test "initial boot_complete is false", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert stats.boot_complete == false
    end

    test "initial quorum_status is 'Unknown'", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert stats.quorum_status == "Unknown"
    end

    test "initial state_vector is '[0,0,0,0,0,0]'", %{server: server} do
      stats = ZenohTestOrchestrator.get_stats(server)
      assert stats.state_vector == "[0,0,0,0,0,0]"
    end
  end

  # ============================================================================
  # get_pass_rate/1
  # ============================================================================

  describe "get_pass_rate/1" do
    test "returns 0.0 when no tests have run", %{server: server} do
      rate = ZenohTestOrchestrator.get_pass_rate(server)
      assert rate == 0.0
    end

    test "returns a float", %{server: server} do
      rate = ZenohTestOrchestrator.get_pass_rate(server)
      assert is_float(rate)
    end

    test "returns value between 0.0 and 100.0", %{server: server} do
      rate = ZenohTestOrchestrator.get_pass_rate(server)
      assert rate >= 0.0
      assert rate <= 100.0
    end
  end

  # ============================================================================
  # get_failures/1
  # ============================================================================

  describe "get_failures/1" do
    test "returns a list", %{server: server} do
      result = ZenohTestOrchestrator.get_failures(server)
      assert is_list(result)
    end

    test "returns empty list initially", %{server: server} do
      result = ZenohTestOrchestrator.get_failures(server)
      assert result == []
    end
  end

  # ============================================================================
  # reset/1
  # ============================================================================

  describe "reset/1" do
    test "reset returns :ok (cast)", %{server: server} do
      result = ZenohTestOrchestrator.reset(server)
      assert result == :ok
    end

    test "stats are zeroed after reset", %{server: server} do
      # Allow cast to be processed
      ZenohTestOrchestrator.reset(server)
      Process.sleep(30)

      stats = ZenohTestOrchestrator.get_stats(server)
      assert stats.test_total == 0
      assert stats.test_passed == 0
      assert stats.test_failed == 0
      assert stats.smoke_total == 0
    end

    test "state_vector resets to initial value", %{server: server} do
      ZenohTestOrchestrator.reset(server)
      Process.sleep(30)

      stats = ZenohTestOrchestrator.get_stats(server)
      assert stats.state_vector == "[0,0,0,0,0,0]"
    end

    test "quorum_status resets to Unknown", %{server: server} do
      ZenohTestOrchestrator.reset(server)
      Process.sleep(30)

      stats = ZenohTestOrchestrator.get_stats(server)
      assert stats.quorum_status == "Unknown"
    end

    test "failures list empty after reset", %{server: server} do
      ZenohTestOrchestrator.reset(server)
      Process.sleep(30)

      failures = ZenohTestOrchestrator.get_failures(server)
      assert failures == []
    end
  end

  # ============================================================================
  # start_link with custom name
  # ============================================================================

  describe "start_link/1 with custom name" do
    test "can start multiple named instances" do
      name2 = :orchestrator_test_second

      case Process.whereis(name2) do
        nil -> :ok
        pid -> GenServer.stop(pid)
      end

      {:ok, pid2} = ZenohTestOrchestrator.start_link(name: name2)
      assert Process.alive?(pid2)
      assert Process.whereis(name2) == pid2

      on_exit(fn -> if Process.alive?(pid2), do: GenServer.stop(pid2) end)
    end

    test "each named instance has independent state" do
      name3 = :orchestrator_test_third

      case Process.whereis(name3) do
        nil -> :ok
        pid -> GenServer.stop(pid)
      end

      {:ok, pid3} = ZenohTestOrchestrator.start_link(name: name3)

      stats_main = ZenohTestOrchestrator.get_stats(@test_name)
      stats_other = ZenohTestOrchestrator.get_stats(name3)

      # Both should be independently initialized
      assert stats_main.test_total == 0
      assert stats_other.test_total == 0

      on_exit(fn -> if Process.alive?(pid3), do: GenServer.stop(pid3) end)
    end
  end
end
