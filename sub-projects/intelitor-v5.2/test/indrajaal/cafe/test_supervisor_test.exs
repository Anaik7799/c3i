defmodule Indrajaal.CAFE.TestSupervisorTest do
  @moduledoc """
  TDG test suite for CAFE.TestSupervisor.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation verification
  - CAFE Framework: Cybernetic Architect Framework for Execution

  ## STAMP Safety Integration
  - SC-OODA-001: OODA cycle < 100ms
  - SC-BIO-002: Quality gate > 80%
  - SC-AGT-017: Agent efficiency > 90%

  ## TPS 5-Level RCA Context
  - L1 Symptom: TestSupervisor fails to initialize or returns incorrect progress maps
  - L5 Root Cause: GenServer state not properly initialized or phase execution corrupted
  """

  use ExUnit.Case, async: false

  alias Indrajaal.CAFE.TestSupervisor

  @moduletag :zenoh_nif

  setup do
    # Stop any existing named instance to avoid conflicts
    case Process.whereis(TestSupervisor) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 5000)
    end

    # Allow process to fully terminate
    Process.sleep(50)

    :ok
  end

  # ============================================================================
  # start_link/1
  # ============================================================================

  describe "start_link/1" do
    test "starts the GenServer successfully with no options" do
      assert {:ok, pid} = TestSupervisor.start_link([])
      assert is_pid(pid)
      assert Process.alive?(pid)

      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    end

    test "registers under module name" do
      {:ok, pid} = TestSupervisor.start_link([])
      assert Process.whereis(TestSupervisor) == pid

      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    end

    test "fails to start a second instance when one is already running" do
      {:ok, pid} = TestSupervisor.start_link([])

      assert {:error, {:already_started, ^pid}} = TestSupervisor.start_link([])

      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    end

    test "accepts custom config options" do
      {:ok, pid} = TestSupervisor.start_link(total_agents: 5)
      assert Process.alive?(pid)

      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    end
  end

  # ============================================================================
  # get_dashboard_state/0
  # ============================================================================

  describe "get_dashboard_state/0" do
    setup do
      {:ok, pid} = TestSupervisor.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    test "returns a map" do
      result = TestSupervisor.get_dashboard_state()
      assert is_map(result)
    end

    test "dashboard state has :progress key" do
      state = TestSupervisor.get_dashboard_state()
      assert Map.has_key?(state, :progress)
    end

    test "dashboard state has :agents key" do
      state = TestSupervisor.get_dashboard_state()
      assert Map.has_key?(state, :agents)
    end

    test "dashboard state has :ooda key" do
      state = TestSupervisor.get_dashboard_state()
      assert Map.has_key?(state, :ooda)
    end

    test "dashboard state has :health key" do
      state = TestSupervisor.get_dashboard_state()
      assert Map.has_key?(state, :health)
    end

    test "dashboard state has :last_update key" do
      state = TestSupervisor.get_dashboard_state()
      assert Map.has_key?(state, :last_update)
    end

    test "last_update is a DateTime" do
      state = TestSupervisor.get_dashboard_state()
      assert %DateTime{} = state.last_update
    end
  end

  # ============================================================================
  # get_execution_progress/0
  # ============================================================================

  describe "get_execution_progress/0" do
    setup do
      {:ok, pid} = TestSupervisor.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    test "returns a map" do
      result = TestSupervisor.get_execution_progress()
      assert is_map(result)
    end

    test "progress has :total_tests key" do
      progress = TestSupervisor.get_execution_progress()
      assert Map.has_key?(progress, :total_tests)
    end

    test "progress has :completed key" do
      progress = TestSupervisor.get_execution_progress()
      assert Map.has_key?(progress, :completed)
    end

    test "progress has :passed key" do
      progress = TestSupervisor.get_execution_progress()
      assert Map.has_key?(progress, :passed)
    end

    test "progress has :failed key" do
      progress = TestSupervisor.get_execution_progress()
      assert Map.has_key?(progress, :failed)
    end

    test "progress has :skipped key" do
      progress = TestSupervisor.get_execution_progress()
      assert Map.has_key?(progress, :skipped)
    end

    test "progress has :current_phase key" do
      progress = TestSupervisor.get_execution_progress()
      assert Map.has_key?(progress, :current_phase)
    end

    test "progress has :phases_completed key as list" do
      progress = TestSupervisor.get_execution_progress()
      assert Map.has_key?(progress, :phases_completed)
      assert is_list(progress.phases_completed)
    end

    test "initial total_tests is 0" do
      progress = TestSupervisor.get_execution_progress()
      assert progress.total_tests == 0
    end

    test "initial completed is 0" do
      progress = TestSupervisor.get_execution_progress()
      assert progress.completed == 0
    end

    test "initial passed is 0" do
      progress = TestSupervisor.get_execution_progress()
      assert progress.passed == 0
    end

    test "initial failed is 0" do
      progress = TestSupervisor.get_execution_progress()
      assert progress.failed == 0
    end

    test "initial phases_completed is empty list" do
      progress = TestSupervisor.get_execution_progress()
      assert progress.phases_completed == []
    end
  end

  # ============================================================================
  # execute_test_suite/1
  # ============================================================================

  describe "execute_test_suite/1" do
    setup do
      {:ok, pid} = TestSupervisor.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    test "returns {:ok, map} tuple" do
      result = TestSupervisor.execute_test_suite([])
      assert {:ok, progress} = result
      assert is_map(progress)
    end

    test "returned progress map has :phases_completed key" do
      {:ok, progress} = TestSupervisor.execute_test_suite([])
      assert Map.has_key?(progress, :phases_completed)
    end

    test "returned progress has phases_completed as list" do
      {:ok, progress} = TestSupervisor.execute_test_suite([])
      assert is_list(progress.phases_completed)
    end

    test "phases_completed list is non-empty after execution" do
      {:ok, progress} = TestSupervisor.execute_test_suite([])
      assert length(progress.phases_completed) > 0
    end

    test "all 6 phases are completed after execution" do
      {:ok, progress} = TestSupervisor.execute_test_suite([])
      # Phases: phase_1 through phase_6 complete markers
      assert length(progress.phases_completed) >= 6
    end

    test "execution returns same structure as get_execution_progress" do
      {:ok, exec_progress} = TestSupervisor.execute_test_suite([])
      current_progress = TestSupervisor.get_execution_progress()

      # Both should have same keys
      assert Map.keys(exec_progress) == Map.keys(current_progress)
    end
  end

  # ============================================================================
  # Default config values
  # ============================================================================

  describe "default configuration" do
    setup do
      {:ok, pid} = TestSupervisor.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    test "GenServer process is alive after init" do
      assert Process.alive?(Process.whereis(TestSupervisor))
    end

    test "multiple get_dashboard_state calls are consistent" do
      state1 = TestSupervisor.get_dashboard_state()
      state2 = TestSupervisor.get_dashboard_state()

      assert Map.keys(state1) == Map.keys(state2)
    end
  end
end
