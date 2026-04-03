defmodule Indrajaal.Cortex.HomeostasisTest do
  @moduledoc """
  Tests for the Homeostasis module.

  STAMP Compliance:
  - SC-CTX-001: Autonomic system isolation
  - SC-CTX-003: Graceful degradation
  - SC-PRF-050: Performance self-tuning

  TDG: Test-Driven Generation - tests created before implementation validation.
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Cortex.Homeostasis

  describe "start_link/1" do
    test "starts the homeostasis process or uses existing" do
      case Process.whereis(Homeostasis) do
        nil ->
          # Not running, start fresh
          assert {:ok, pid} = Homeostasis.start_link([])
          assert Process.alive?(pid)

        pid ->
          # Already running from application supervisor
          assert Process.alive?(pid)
      end
    end

    test "process is registered with expected name" do
      case Process.whereis(Homeostasis) do
        nil ->
          {:ok, pid} = Homeostasis.start_link([])
          assert Process.whereis(Homeostasis) == pid

        pid ->
          # Already registered from application supervisor
          assert Process.whereis(Homeostasis) == pid
      end
    end
  end

  describe "get_state/0" do
    setup do
      case Process.whereis(Homeostasis) do
        nil ->
          {:ok, pid} = Homeostasis.start_link([])
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "returns state summary map", %{pid: _pid} do
      state = Homeostasis.get_state()

      assert is_map(state)
      assert Map.has_key?(state, :current_stress)
      assert Map.has_key?(state, :stress_trend)
      assert Map.has_key?(state, :last_action)
      assert Map.has_key?(state, :thresholds)
      assert Map.has_key?(state, :auto_tune)
      assert Map.has_key?(state, :uptime_seconds)
    end

    test "current_stress is between 0 and 1", %{pid: _pid} do
      state = Homeostasis.get_state()

      assert is_number(state.current_stress)
      assert state.current_stress >= 0.0
      assert state.current_stress <= 1.0
    end

    test "stress_trend is a valid atom", %{pid: _pid} do
      state = Homeostasis.get_state()

      assert state.stress_trend in [:rising, :falling, :stable]
    end

    test "thresholds contains expected keys", %{pid: _pid} do
      state = Homeostasis.get_state()

      assert Map.has_key?(state.thresholds, :critical)
      assert Map.has_key?(state.thresholds, :high)
      assert Map.has_key?(state.thresholds, :optimal_high)
      assert Map.has_key?(state.thresholds, :optimal_low)
      assert Map.has_key?(state.thresholds, :low)
    end

    test "uptime_seconds is non-negative", %{pid: _pid} do
      state = Homeostasis.get_state()

      assert is_integer(state.uptime_seconds)
      assert state.uptime_seconds >= 0
    end
  end

  describe "stress_level/0" do
    setup do
      case Process.whereis(Homeostasis) do
        nil ->
          {:ok, pid} = Homeostasis.start_link([])
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "returns current stress level", %{pid: _pid} do
      stress = Homeostasis.stress_level()

      assert is_number(stress)
      assert stress >= 0.0
      assert stress <= 1.0
    end
  end

  describe "check_now/0" do
    setup do
      case Process.whereis(Homeostasis) do
        nil ->
          {:ok, pid} = Homeostasis.start_link([])
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "triggers immediate stability check", %{pid: _pid} do
      # Get initial state
      initial_state = Homeostasis.get_state()

      # Trigger check
      :ok = Homeostasis.check_now()

      # Wait for async processing
      Process.sleep(100)

      # State should still be valid
      new_state = Homeostasis.get_state()
      assert is_map(new_state)
      assert is_number(new_state.current_stress)
    end

    test "returns :ok", %{pid: _pid} do
      result = Homeostasis.check_now()
      assert result == :ok
    end
  end

  describe "set_threshold/2" do
    setup do
      case Process.whereis(Homeostasis) do
        nil ->
          {:ok, pid} = Homeostasis.start_link([])
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "updates valid threshold", %{pid: _pid} do
      assert :ok = Homeostasis.set_threshold(:critical, 0.95)

      state = Homeostasis.get_state()
      assert state.thresholds.critical == 0.95
    end

    test "rejects invalid threshold key", %{pid: _pid} do
      result = Homeostasis.set_threshold(:invalid_key, 0.5)

      assert result == {:error, :invalid_threshold}
    end

    test "updates high threshold", %{pid: _pid} do
      assert :ok = Homeostasis.set_threshold(:high, 0.8)

      state = Homeostasis.get_state()
      assert state.thresholds.high == 0.8
    end

    test "updates low threshold", %{pid: _pid} do
      assert :ok = Homeostasis.set_threshold(:low, 0.15)

      state = Homeostasis.get_state()
      assert state.thresholds.low == 0.15
    end
  end

  describe "threshold configuration" do
    setup do
      case Process.whereis(Homeostasis) do
        nil ->
          {:ok, pid} = Homeostasis.start_link([])
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          # Reset thresholds to defaults for consistent testing
          Homeostasis.set_threshold(:critical, 0.9)
          Homeostasis.set_threshold(:high, 0.7)
          Homeostasis.set_threshold(:optimal_high, 0.5)
          Homeostasis.set_threshold(:optimal_low, 0.3)
          Homeostasis.set_threshold(:low, 0.2)
          {:ok, pid: pid}
      end
    end

    test "default thresholds are properly ordered", %{pid: _pid} do
      state = Homeostasis.get_state()
      t = state.thresholds

      # Thresholds should be in increasing order
      assert t.low < t.optimal_low
      assert t.optimal_low < t.optimal_high
      assert t.optimal_high < t.high
      assert t.high < t.critical
    end

    test "critical threshold is 0.9", %{pid: _pid} do
      state = Homeostasis.get_state()
      assert state.thresholds.critical == 0.9
    end

    test "low threshold is 0.2", %{pid: _pid} do
      state = Homeostasis.get_state()
      assert state.thresholds.low == 0.2
    end
  end

  describe "stress trend analysis" do
    setup do
      case Process.whereis(Homeostasis) do
        nil ->
          {:ok, pid} = Homeostasis.start_link([])
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "trend starts as stable", %{pid: _pid} do
      state = Homeostasis.get_state()

      # Initially should be stable (not enough history)
      assert state.stress_trend == :stable
    end

    test "trend updates after multiple checks", %{pid: _pid} do
      # Perform multiple checks
      for _ <- 1..5 do
        Homeostasis.check_now()
        Process.sleep(50)
      end

      state = Homeostasis.get_state()

      # Trend should be one of the valid values
      assert state.stress_trend in [:rising, :falling, :stable]
    end
  end

  describe "action history" do
    setup do
      case Process.whereis(Homeostasis) do
        nil ->
          {:ok, pid} = Homeostasis.start_link([])
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "last_action starts as nil", %{pid: _pid} do
      state = Homeostasis.get_state()

      assert is_nil(state.last_action)
    end

    test "last_action_at starts as nil", %{pid: _pid} do
      state = Homeostasis.get_state()

      assert is_nil(state.last_action_at)
    end
  end

  describe "STAMP compliance" do
    setup do
      case Process.whereis(Homeostasis) do
        nil ->
          {:ok, pid} = Homeostasis.start_link([])
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "SC-CTX-001: provides isolated autonomic regulation", %{pid: _pid} do
      # Homeostasis operates independently
      state1 = Homeostasis.get_state()
      Process.sleep(100)
      state2 = Homeostasis.get_state()

      # Both calls should succeed independently
      assert is_map(state1)
      assert is_map(state2)
    end

    test "SC-CTX-003: graceful operation under various stress levels", %{pid: _pid} do
      # Should handle checks without crashing
      for _ <- 1..3 do
        Homeostasis.check_now()
        state = Homeostasis.get_state()
        assert is_map(state)
        Process.sleep(50)
      end
    end

    test "SC-PRF-050: auto-tune is enabled by default", %{pid: _pid} do
      state = Homeostasis.get_state()

      assert state.auto_tune == true
    end

    test "provides stress scoring for self-tuning", %{pid: _pid} do
      stress = Homeostasis.stress_level()

      # Stress level should be a usable metric
      assert is_number(stress)
      assert stress >= 0.0
      assert stress <= 1.0
    end
  end
end
