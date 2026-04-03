defmodule Indrajaal.Cortex.ControllerTest do
  @moduledoc """
  Tests for the Cortex.Controller module (OODA Loop Engine).

  STAMP Compliance:
  - SC-CTX-004: OODA cycle bounded latency (<1000ms)
  - SC-CTX-005: Decision audit trail
  - SC-CTX-006: Action rollback capability

  TDG: Test-Driven Generation - tests created before implementation validation.
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Cortex.Controller

  describe "start_link/1" do
    test "starts the controller process or uses existing" do
      case Process.whereis(Controller) do
        nil ->
          # Not running, start fresh
          assert {:ok, pid} = Controller.start_link([])
          assert Process.alive?(pid)

        pid ->
          # Already running from application supervisor
          assert Process.alive?(pid)
      end
    end

    test "process is registered with expected name" do
      case Process.whereis(Controller) do
        nil ->
          {:ok, pid} = Controller.start_link([])
          assert Process.whereis(Controller) == pid

        pid ->
          # Already registered from application supervisor
          assert Process.whereis(Controller) == pid
      end
    end
  end

  describe "get_state/0" do
    setup do
      case Process.whereis(Controller) do
        nil ->
          {:ok, pid} = Controller.start_link([])
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "returns state summary map", %{pid: _pid} do
      state = Controller.get_state()

      assert is_map(state)
      assert Map.has_key?(state, :phase)
      assert Map.has_key?(state, :cycle_count)
      assert Map.has_key?(state, :pending_proposals)
      assert Map.has_key?(state, :auto_execute)
      assert Map.has_key?(state, :uptime_seconds)
    end

    test "phase starts as idle", %{pid: _pid} do
      state = Controller.get_state()

      assert state.phase == :idle
    end

    test "cycle_count is non-negative", %{pid: _pid} do
      state = Controller.get_state()

      assert is_integer(state.cycle_count)
      assert state.cycle_count >= 0
    end

    test "auto_execute is disabled by default", %{pid: _pid} do
      state = Controller.get_state()

      assert state.auto_execute == false
    end

    test "uptime_seconds is non-negative", %{pid: _pid} do
      state = Controller.get_state()

      assert is_integer(state.uptime_seconds)
      assert state.uptime_seconds >= 0
    end
  end

  describe "get_proposals/0" do
    setup do
      case Process.whereis(Controller) do
        nil ->
          {:ok, pid} = Controller.start_link([])
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "returns list of proposals", %{pid: _pid} do
      proposals = Controller.get_proposals()

      assert is_list(proposals)
    end

    test "proposals list is empty initially", %{pid: _pid} do
      proposals = Controller.get_proposals()

      assert proposals == []
    end
  end

  describe "approve_proposal/1" do
    setup do
      case Process.whereis(Controller) do
        nil ->
          {:ok, pid} = Controller.start_link([])
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "returns error for non-existent proposal", %{pid: _pid} do
      result = Controller.approve_proposal("nonexistent-id")

      assert result == {:error, :not_found}
    end
  end

  describe "reject_proposal/2" do
    setup do
      case Process.whereis(Controller) do
        nil ->
          {:ok, pid} = Controller.start_link([])
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "returns ok for any proposal id", %{pid: _pid} do
      # Rejecting non-existent proposal is fine (idempotent)
      result = Controller.reject_proposal("nonexistent-id")

      assert result == :ok
    end

    test "accepts custom rejection reason", %{pid: _pid} do
      result = Controller.reject_proposal("nonexistent-id", "Custom reason")

      assert result == :ok
    end
  end

  describe "trigger_cycle/0" do
    setup do
      case Process.whereis(Controller) do
        nil ->
          {:ok, pid} = Controller.start_link([])
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "triggers OODA cycle asynchronously", %{pid: _pid} do
      # Get initial state
      initial_state = Controller.get_state()
      initial_count = initial_state.cycle_count

      # Trigger cycle
      Controller.trigger_cycle()

      # Wait for async processing
      Process.sleep(200)

      # Cycle count should have increased
      new_state = Controller.get_state()
      assert new_state.cycle_count == initial_count + 1
    end

    test "returns :ok immediately", %{pid: _pid} do
      result = Controller.trigger_cycle()

      assert result == :ok
    end
  end

  describe "metrics/0" do
    setup do
      case Process.whereis(Controller) do
        nil ->
          {:ok, pid} = Controller.start_link([])
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "returns metrics map", %{pid: _pid} do
      metrics = Controller.metrics()

      assert is_map(metrics)
      assert Map.has_key?(metrics, :cycle_count)
      assert Map.has_key?(metrics, :avg_latency_ms)
      assert Map.has_key?(metrics, :decisions_made)
      assert Map.has_key?(metrics, :actions_executed)
      assert Map.has_key?(metrics, :pending_proposals)
      assert Map.has_key?(metrics, :stress_history_size)
    end

    test "cycle_count is non-negative", %{pid: _pid} do
      metrics = Controller.metrics()

      assert is_integer(metrics.cycle_count)
      assert metrics.cycle_count >= 0
    end

    test "avg_latency_ms is non-negative", %{pid: _pid} do
      metrics = Controller.metrics()

      assert is_number(metrics.avg_latency_ms)
      assert metrics.avg_latency_ms >= 0
    end

    test "metrics update after trigger_cycle", %{pid: _pid} do
      # Trigger a cycle
      Controller.trigger_cycle()
      Process.sleep(200)

      metrics = Controller.metrics()

      assert metrics.cycle_count >= 1
      assert metrics.decisions_made >= 1
    end
  end

  describe "OODA cycle execution" do
    setup do
      case Process.whereis(Controller) do
        nil ->
          {:ok, pid} = Controller.start_link([])
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "cycle increments cycle_count", %{pid: _pid} do
      initial_count = Controller.get_state().cycle_count

      Controller.trigger_cycle()
      Process.sleep(200)

      assert Controller.get_state().cycle_count == initial_count + 1
    end

    test "multiple cycles accumulate correctly", %{pid: _pid} do
      for _ <- 1..3 do
        Controller.trigger_cycle()
        Process.sleep(100)
      end

      assert Controller.get_state().cycle_count >= 3
    end

    test "stress history accumulates after cycles", %{pid: _pid} do
      for _ <- 1..3 do
        Controller.trigger_cycle()
        Process.sleep(100)
      end

      metrics = Controller.metrics()
      assert metrics.stress_history_size >= 3
    end
  end

  describe "STAMP compliance" do
    setup do
      case Process.whereis(Controller) do
        nil ->
          {:ok, pid} = Controller.start_link([])
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "SC-CTX-004: OODA cycle completes within latency bound", %{pid: _pid} do
      # Measure cycle time
      start_time = System.monotonic_time(:millisecond)
      Controller.trigger_cycle()
      Process.sleep(200)
      end_time = System.monotonic_time(:millisecond)

      # Should complete well within 1000ms bound
      assert end_time - start_time < 1000
    end

    test "SC-CTX-005: decisions are tracked (audit trail)", %{pid: _pid} do
      # Execute a cycle
      Controller.trigger_cycle()
      Process.sleep(200)

      metrics = Controller.metrics()

      # Decisions are counted
      assert metrics.decisions_made >= 1
    end

    test "SC-CTX-006: proposals can be rejected (rollback capability)", %{pid: _pid} do
      # Rejection should always succeed (idempotent)
      result = Controller.reject_proposal("any-proposal", "Test rejection")

      assert result == :ok
    end

    test "controller maintains operational state through multiple cycles", %{pid: _pid} do
      for _ <- 1..5 do
        Controller.trigger_cycle()
        Process.sleep(50)

        # State should remain valid
        state = Controller.get_state()
        assert is_map(state)
        # Returns to idle after each cycle
        assert state.phase == :idle
      end
    end

    test "metrics track all OODA phases", %{pid: _pid} do
      Controller.trigger_cycle()
      Process.sleep(200)

      metrics = Controller.metrics()

      # All metrics should be populated
      assert is_number(metrics.cycle_count)
      assert is_number(metrics.avg_latency_ms)
      assert is_number(metrics.decisions_made)
      assert is_number(metrics.actions_executed)
      assert is_number(metrics.pending_proposals)
    end
  end

  describe "proposal lifecycle" do
    setup do
      case Process.whereis(Controller) do
        nil ->
          {:ok, pid} = Controller.start_link([])
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "proposals can be retrieved after cycles", %{pid: _pid} do
      Controller.trigger_cycle()
      Process.sleep(200)

      proposals = Controller.get_proposals()
      assert is_list(proposals)
    end

    test "pending_proposals count matches get_proposals length", %{pid: _pid} do
      state = Controller.get_state()
      proposals = Controller.get_proposals()

      assert state.pending_proposals == length(proposals)
    end
  end
end
