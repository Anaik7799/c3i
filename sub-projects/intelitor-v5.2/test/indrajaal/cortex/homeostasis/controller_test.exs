defmodule Indrajaal.Cortex.Homeostasis.ControllerTest do
  @moduledoc """
  TDG Sprint 54: Module coverage tests for Indrajaal.Cortex.Homeostasis.Controller.
  Covers GenServer init contract, PID-based regulation, adaptive gain tuning
  (GAP-P3-002), real actuator integration, and pure utility functions.

  STAMP: SC-MATH-003 (Homeostasis PID), SC-COG-001, SC-ZTEST-004
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cortex.Homeostasis.Controller

  @sample_metrics %{
    cpu_usage: 0.45,
    memory_usage: 0.60,
    message_queue_length: 10,
    process_count: 150
  }

  # 20 alternating errors — enough for adaptive tuning (needs >= 10)
  @oscillating_errors Enum.map(1..20, fn i ->
                        if rem(i, 2) == 0, do: 0.3, else: -0.3
                      end)

  # 20 same-sign errors — no oscillation
  @flat_errors Enum.map(1..20, fn _i -> 0.1 end)

  # ---------------------------------------------------------------------------
  # Module existence
  # ---------------------------------------------------------------------------

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Controller)
    end

    test "implements GenServer behaviour" do
      assert function_exported?(Controller, :start_link, 1)
      assert function_exported?(Controller, :init, 1)
    end
  end

  # ---------------------------------------------------------------------------
  # Public API surface
  # ---------------------------------------------------------------------------

  describe "public API surface" do
    test "exports regulate/1" do
      assert function_exported?(Controller, :regulate, 1)
    end

    test "exports update_metrics/1" do
      assert function_exported?(Controller, :update_metrics, 1)
    end

    test "exports get_state/0" do
      assert function_exported?(Controller, :get_state, 0)
    end

    test "exports set_gains/3" do
      assert function_exported?(Controller, :set_gains, 3)
    end

    test "exports set_setpoint/1" do
      assert function_exported?(Controller, :set_setpoint, 1)
    end

    test "exports weighted_stress/2 (doc false public)" do
      assert function_exported?(Controller, :weighted_stress, 2)
    end

    test "exports trigger_adapt_gains/0 (GAP-P3-002)" do
      assert function_exported?(Controller, :trigger_adapt_gains, 0)
    end

    test "exports get_error_history/0 (GAP-P3-002)" do
      assert function_exported?(Controller, :get_error_history, 0)
    end

    test "exports set_adaptive_tune/1 (GAP-P3-002)" do
      assert function_exported?(Controller, :set_adaptive_tune, 1)
    end

    test "exports apply_control_action/2 (GAP-P3-002)" do
      assert function_exported?(Controller, :apply_control_action, 2)
    end

    test "exports detect_oscillation_period/1 (GAP-P3-002)" do
      assert function_exported?(Controller, :detect_oscillation_period, 1)
    end

    test "exports compute_ultimate_gain/1 (GAP-P3-002)" do
      assert function_exported?(Controller, :compute_ultimate_gain, 1)
    end

    test "exports adapt_gains/2 (GAP-P3-002)" do
      assert function_exported?(Controller, :adapt_gains, 2)
    end
  end

  # ---------------------------------------------------------------------------
  # start_link / init
  # ---------------------------------------------------------------------------

  describe "start_link/1 contract" do
    test "starts process with empty opts" do
      {:ok, pid} = start_supervised({Controller, []})
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "initial state is a map" do
      {:ok, pid} = start_supervised({Controller, []})
      state = :sys.get_state(pid)
      assert is_map(state)
    end

    test "error_history starts empty" do
      {:ok, pid} = start_supervised({Controller, []})
      state = :sys.get_state(pid)
      assert state.error_history == []
    end

    test "tune_cycle_count starts at 0" do
      {:ok, pid} = start_supervised({Controller, []})
      state = :sys.get_state(pid)
      assert state.tune_cycle_count == 0
    end

    test "adaptive_tune_enabled defaults to true" do
      {:ok, pid} = start_supervised({Controller, []})
      state = :sys.get_state(pid)
      assert state.adaptive_tune_enabled == true
    end

    test "adaptive_tune_enabled can be disabled at init" do
      {:ok, pid} = start_supervised({Controller, [adaptive_tune: false]})
      state = :sys.get_state(pid)
      assert state.adaptive_tune_enabled == false
    end

    test "accepts custom kp/ki/kd at init" do
      {:ok, pid} = start_supervised({Controller, [kp: 0.5, ki: 0.05, kd: 0.01]})
      state = :sys.get_state(pid)
      assert state.kp == 0.5
      assert state.ki == 0.05
      assert state.kd == 0.01
    end
  end

  # ---------------------------------------------------------------------------
  # weighted_stress/2 pure function
  # ---------------------------------------------------------------------------

  describe "weighted_stress/2 pure function" do
    test "returns a float" do
      result = Controller.weighted_stress(@sample_metrics, [])
      assert is_number(result)
    end

    test "returns 0.0 or higher for valid metrics" do
      result = Controller.weighted_stress(@sample_metrics, [])
      assert result >= 0.0
    end

    test "accepts custom weight options as keyword list" do
      opts = [cpu_weight: 0.4, memory_weight: 0.4, queue_weight: 0.2]
      result = Controller.weighted_stress(@sample_metrics, opts)
      assert is_number(result)
    end

    test "accepts empty map metrics" do
      result = Controller.weighted_stress(%{}, %{})
      assert result == 0.0
    end

    test "clamps result to [0.0, 1.0]" do
      extreme = %{cpu: 999.0, memory: 999.0}
      result = Controller.weighted_stress(extreme, %{cpu: 0.5, memory: 0.5})
      assert result <= 1.0
    end
  end

  # ---------------------------------------------------------------------------
  # child_spec/1
  # ---------------------------------------------------------------------------

  describe "child_spec/1" do
    test "returns valid child spec" do
      spec = Controller.child_spec([])
      assert is_map(spec)
      assert Map.has_key?(spec, :id)
      assert Map.has_key?(spec, :start)
    end
  end

  # ---------------------------------------------------------------------------
  # detect_oscillation_period/1 — pure function
  # ---------------------------------------------------------------------------

  describe "detect_oscillation_period/1 (GAP-P3-002)" do
    test "returns 1.0 for empty list" do
      assert Controller.detect_oscillation_period([]) == 1.0
    end

    test "returns 1.0 for single element" do
      assert Controller.detect_oscillation_period([0.1]) == 1.0
    end

    test "returns a positive float for oscillating signal" do
      result = Controller.detect_oscillation_period(@oscillating_errors)
      assert is_float(result)
      assert result > 0.0
    end

    test "returns 1.0 (fallback) for non-oscillating signal" do
      result = Controller.detect_oscillation_period(@flat_errors)
      # No sign changes → fewer than 2 crossings → fallback 1.0
      assert result == 1.0
    end

    test "period is at least 1.0" do
      result = Controller.detect_oscillation_period(@oscillating_errors)
      assert result >= 1.0
    end
  end

  # ---------------------------------------------------------------------------
  # compute_ultimate_gain/1 — pure function
  # ---------------------------------------------------------------------------

  describe "compute_ultimate_gain/1 (GAP-P3-002)" do
    test "returns 1.0 for empty list" do
      assert Controller.compute_ultimate_gain([]) == 1.0
    end

    test "returns a positive float for non-empty history" do
      result = Controller.compute_ultimate_gain(@oscillating_errors)
      assert is_float(result)
      assert result > 0.0
    end

    test "result is clamped within [0.1, 4.0]" do
      result = Controller.compute_ultimate_gain(@oscillating_errors)
      assert result >= 0.1
      assert result <= 4.0
    end

    test "small errors produce smaller ultimate gain than large errors" do
      small_errors = Enum.map(1..20, fn _ -> 0.01 end)
      large_errors = Enum.map(1..20, fn _ -> 0.5 end)
      small_ku = Controller.compute_ultimate_gain(small_errors)
      large_ku = Controller.compute_ultimate_gain(large_errors)
      # Small mean absolute error → higher Ku (more gain needed)
      assert small_ku >= large_ku
    end
  end

  # ---------------------------------------------------------------------------
  # adapt_gains/2 — pure function (uses state struct)
  # ---------------------------------------------------------------------------

  describe "adapt_gains/2 (GAP-P3-002)" do
    setup do
      {:ok, pid} = start_supervised({Controller, [adaptive_tune: false]})
      state = :sys.get_state(pid)
      {:ok, state: state}
    end

    test "returns error with fewer than 10 samples", %{state: state} do
      assert {:error, :insufficient_history} = Controller.adapt_gains(state, [0.1, 0.2])
    end

    test "returns {:ok, new_state, gains} with sufficient history", %{state: state} do
      result = Controller.adapt_gains(state, @oscillating_errors)
      assert {:ok, new_state, gains} = result
      assert is_map(new_state)
      assert is_map(gains)
    end

    test "returned gains contain kp, ki, kd keys", %{state: state} do
      {:ok, _new_state, gains} = Controller.adapt_gains(state, @oscillating_errors)
      assert Map.has_key?(gains, :kp)
      assert Map.has_key?(gains, :ki)
      assert Map.has_key?(gains, :kd)
    end

    test "kp is within safe range [0.1, 2.0]", %{state: state} do
      {:ok, _new_state, gains} = Controller.adapt_gains(state, @oscillating_errors)
      assert gains.kp >= 0.1
      assert gains.kp <= 2.0
    end

    test "ki is within safe range [0.01, 1.0]", %{state: state} do
      {:ok, _new_state, gains} = Controller.adapt_gains(state, @oscillating_errors)
      assert gains.ki >= 0.01
      assert gains.ki <= 1.0
    end

    test "kd is within safe range [0.05, 0.5]", %{state: state} do
      {:ok, _new_state, gains} = Controller.adapt_gains(state, @oscillating_errors)
      assert gains.kd >= 0.05
      assert gains.kd <= 0.5
    end

    test "new_state has updated kp matching gains.kp", %{state: state} do
      {:ok, new_state, gains} = Controller.adapt_gains(state, @oscillating_errors)
      assert new_state.kp == gains.kp
    end

    test "flat (non-oscillating) errors also produce valid gains", %{state: state} do
      {:ok, _new_state, gains} = Controller.adapt_gains(state, @flat_errors)
      assert gains.kp >= 0.1
      assert gains.ki >= 0.01
      assert gains.kd >= 0.05
    end
  end

  # ---------------------------------------------------------------------------
  # trigger_adapt_gains/0 — GenServer call
  # ---------------------------------------------------------------------------

  describe "trigger_adapt_gains/0 (GAP-P3-002)" do
    test "returns error when error history is empty" do
      {:ok, pid} = start_supervised({Controller, [name: :ctrl_empty_hist, adaptive_tune: false]})
      result = GenServer.call(pid, :trigger_adapt_gains)
      assert result == {:error, :insufficient_history}
    end

    test "returns {:ok, gains} after sufficient regulate cycles" do
      {:ok, pid} =
        start_supervised(
          {Controller, [name: :ctrl_adapt_call, adaptive_tune: false, cooldown_ms: 0]}
        )

      # Drive 20 regulate cycles to populate error history
      for _ <- 1..20 do
        GenServer.call(pid, {:regulate_score, 0.6})
      end

      result = GenServer.call(pid, :trigger_adapt_gains)
      assert {:ok, gains} = result
      assert is_map(gains)
      assert Map.has_key?(gains, :kp)
    end
  end

  # ---------------------------------------------------------------------------
  # get_error_history/0 and set_adaptive_tune/1 — GenServer calls
  # ---------------------------------------------------------------------------

  describe "get_error_history/0 (GAP-P3-002)" do
    test "starts empty" do
      {:ok, pid} = start_supervised({Controller, []})
      history = GenServer.call(pid, :get_error_history)
      assert history == []
    end

    test "grows after regulate calls" do
      {:ok, pid} = start_supervised({Controller, [name: :ctrl_hist_grow]})

      for _ <- 1..5 do
        GenServer.call(pid, {:regulate_score, 0.5})
      end

      history = GenServer.call(pid, :get_error_history)
      assert length(history) == 5
    end

    test "capped at 100 entries" do
      {:ok, pid} = start_supervised({Controller, [name: :ctrl_hist_cap]})

      for _ <- 1..110 do
        GenServer.call(pid, {:regulate_score, 0.5})
      end

      history = GenServer.call(pid, :get_error_history)
      assert length(history) <= 100
    end

    test "each entry is a float" do
      {:ok, pid} = start_supervised({Controller, [name: :ctrl_hist_type]})
      GenServer.call(pid, {:regulate_score, 0.6})
      [entry | _] = GenServer.call(pid, :get_error_history)
      assert is_float(entry)
    end
  end

  describe "set_adaptive_tune/1 (GAP-P3-002)" do
    test "disables adaptive tuning" do
      {:ok, pid} = start_supervised({Controller, []})
      assert :ok == GenServer.call(pid, {:set_adaptive_tune, false})
      state = :sys.get_state(pid)
      assert state.adaptive_tune_enabled == false
    end

    test "re-enables adaptive tuning" do
      {:ok, pid} = start_supervised({Controller, [adaptive_tune: false]})
      assert :ok == GenServer.call(pid, {:set_adaptive_tune, true})
      state = :sys.get_state(pid)
      assert state.adaptive_tune_enabled == true
    end
  end

  # ---------------------------------------------------------------------------
  # apply_control_action/2 — real actuators (GAP-P3-002)
  # ---------------------------------------------------------------------------

  describe "apply_control_action/2 (GAP-P3-002)" do
    test ":agent_scaling rounds output to integer target" do
      assert {:ok, target} = Controller.apply_control_action(3.7, :agent_scaling)
      assert is_integer(target)
      assert target == 4
    end

    test ":agent_scaling returns {:ok, integer}" do
      assert {:ok, 2} = Controller.apply_control_action(2.0, :agent_scaling)
    end

    test ":rate_limiting clamps to [0.1, 1.0]" do
      assert {:ok, rate} = Controller.apply_control_action(0.5, :rate_limiting)
      assert is_float(rate)
      assert rate >= 0.1
      assert rate <= 1.0
    end

    test ":rate_limiting clamps oversized output to 1.0" do
      assert {:ok, rate} = Controller.apply_control_action(5.0, :rate_limiting)
      assert rate == 1.0
    end

    test ":rate_limiting clamps undersized output to 0.1" do
      assert {:ok, rate} = Controller.apply_control_action(0.0, :rate_limiting)
      assert rate == 0.1
    end

    test ":memory_pressure returns {:ok, control_output}" do
      assert {:ok, out} = Controller.apply_control_action(0.5, :memory_pressure)
      assert is_float(out)
      assert out == 0.5
    end

    test ":memory_pressure triggers GC when output > 0.8" do
      # Just verify no crash when GC path is taken
      assert {:ok, _} = Controller.apply_control_action(0.9, :memory_pressure)
    end

    test ":memory_pressure does not crash when output <= 0.8" do
      assert {:ok, _} = Controller.apply_control_action(0.5, :memory_pressure)
    end
  end

  # ---------------------------------------------------------------------------
  # Adaptive tuning integrates into regulate cycle
  # ---------------------------------------------------------------------------

  describe "adaptive tuning in regulate cycle (GAP-P3-002)" do
    test "tune_cycle_count increments on each regulate call" do
      {:ok, pid} = start_supervised({Controller, [name: :ctrl_cycle_count]})

      for _ <- 1..3 do
        GenServer.call(pid, {:regulate_score, 0.5})
      end

      state = :sys.get_state(pid)
      assert state.tune_cycle_count == 3
    end

    test "error_history is populated after regulate calls" do
      {:ok, pid} = start_supervised({Controller, [name: :ctrl_err_hist]})

      for _ <- 1..5 do
        GenServer.call(pid, {:regulate_score, 0.6})
      end

      state = :sys.get_state(pid)
      assert length(state.error_history) == 5
    end

    test "gains remain valid (in-range) after 20 adaptive cycles" do
      {:ok, pid} =
        start_supervised(
          {Controller, [name: :ctrl_adaptive_20, adaptive_tune: true, cooldown_ms: 0]}
        )

      # 20 calls → 2 adaptive events (every 10 cycles)
      for i <- 1..20 do
        stress = if rem(i, 2) == 0, do: 0.7, else: 0.3
        GenServer.call(pid, {:regulate_score, stress})
      end

      state = :sys.get_state(pid)
      assert state.kp >= 0.1 and state.kp <= 2.0
      assert state.ki >= 0.01 and state.ki <= 1.0
      assert state.kd >= 0.05 and state.kd <= 0.5
    end
  end
end
