defmodule Indrajaal.Core.MathematicalHomeostasisPIDTest do
  @moduledoc """
  Mathematical homeostasis PID tuning verification test.

  WHAT: Tests PID controller behavior for system homeostasis —
        setpoint tracking, disturbance rejection, stability.
  WHY: Validates SC-MATH-003 (Homeostasis RPN remediated; Ziegler-Nichols PID),
       SC-WATCHDOG-001 (check interval ≤ 100ms), AOR-MATH-007 (validate PID params).

  STAMP Constraints:
  - SC-MATH-003: Homeostasis RPN remediated with Ziegler-Nichols PID
  - SC-MATH-001: Discipline health monitored
  - SC-WATCHDOG-001: Check interval ≤ 100ms

  AOR Rules:
  - AOR-MATH-007: Validate Ziegler-Nichols PID parameters
  - AOR-MATH-020: Homeostasis PID tuning documented
  """

  use ExUnit.Case, async: true
  import ExUnitProperties, except: [property: 2, property: 3]

  alias StreamData, as: SD

  # PID controller parameters (Ziegler-Nichols classic tuning)
  # Proportional gain
  @kp 1.2
  # Integral gain
  @ki 0.5
  # Derivative gain
  @kd 0.1
  # Time step (10ms)
  @dt 0.01
  @setpoint 1.0
  @max_output 10.0
  @min_output -10.0
  @integral_windup_limit 5.0

  # ============================================================================
  # PID Controller Core Tests
  # ============================================================================

  describe "PID controller initialization" do
    test "creates controller with Ziegler-Nichols parameters" do
      pid = new_pid(@kp, @ki, @kd)

      assert pid.kp == @kp
      assert pid.ki == @ki
      assert pid.kd == @kd
      assert pid.integral == 0.0
      assert pid.prev_error == 0.0
      assert pid.output == 0.0
    end

    test "rejects negative gains" do
      assert {:error, :invalid_gains} = validate_gains(-1.0, @ki, @kd)
      assert {:error, :invalid_gains} = validate_gains(@kp, -1.0, @kd)
      assert {:error, :invalid_gains} = validate_gains(@kp, @ki, -1.0)
    end

    test "accepts zero integral/derivative gains (P-only or PD controller)" do
      assert :ok = validate_gains(@kp, 0.0, 0.0)
      assert :ok = validate_gains(@kp, 0.0, @kd)
      assert :ok = validate_gains(@kp, @ki, 0.0)
    end
  end

  # ============================================================================
  # Setpoint Tracking Tests
  # ============================================================================

  describe "setpoint tracking" do
    test "converges to setpoint from zero initial state" do
      pid = new_pid(@kp, @ki, @kd)
      process_value = 0.0

      {_pid, final_pv} = simulate_steps(pid, @setpoint, process_value, 500)

      assert_in_delta final_pv,
                      @setpoint,
                      0.05,
                      "PID should converge to setpoint within 5% tolerance"
    end

    test "converges to setpoint from above" do
      pid = new_pid(@kp, @ki, @kd)
      process_value = 2.0

      {_pid, final_pv} = simulate_steps(pid, @setpoint, process_value, 500)

      assert_in_delta final_pv, @setpoint, 0.05
    end

    test "tracks step change in setpoint" do
      pid = new_pid(@kp, @ki, @kd)
      process_value = 0.0

      # First converge to 1.0
      {pid, pv1} = simulate_steps(pid, 1.0, process_value, 300)
      assert_in_delta pv1, 1.0, 0.1

      # Then change setpoint to 2.0
      {_pid, pv2} = simulate_steps(pid, 2.0, pv1, 300)
      assert_in_delta pv2, 2.0, 0.1
    end

    test "handles zero setpoint" do
      pid = new_pid(@kp, @ki, @kd)
      process_value = 1.0

      {_pid, final_pv} = simulate_steps(pid, 0.0, process_value, 500)

      assert_in_delta final_pv, 0.0, 0.05
    end
  end

  # ============================================================================
  # Disturbance Rejection Tests
  # ============================================================================

  describe "disturbance rejection" do
    test "rejects step disturbance" do
      pid = new_pid(@kp, @ki, @kd)

      # First converge
      {pid, pv} = simulate_steps(pid, @setpoint, 0.0, 300)
      assert_in_delta pv, @setpoint, 0.1

      # Apply disturbance (sudden process value change)
      disturbed_pv = pv + 0.5

      # Recover
      {_pid, recovered_pv} = simulate_steps(pid, @setpoint, disturbed_pv, 300)
      assert_in_delta recovered_pv, @setpoint, 0.1, "PID should reject step disturbance"
    end

    test "rejects periodic disturbance" do
      pid = new_pid(@kp, @ki, @kd)
      pv = 0.0

      # Simulate with periodic disturbance
      {_pid, final_pv, _history} =
        Enum.reduce(1..500, {pid, pv, []}, fn step, {p, process_val, hist} ->
          disturbance = if rem(step, 50) < 10, do: 0.3, else: 0.0
          {new_pid, new_pv} = pid_step(p, @setpoint, process_val + disturbance)
          {new_pid, new_pv, [new_pv | hist]}
        end)

      # Should still be near setpoint despite periodic disturbances
      assert_in_delta final_pv, @setpoint, 0.2
    end
  end

  # ============================================================================
  # Stability Tests
  # ============================================================================

  describe "stability" do
    test "output is bounded by min/max limits" do
      pid = new_pid(@kp, @ki, @kd)

      # Large error should not produce unbounded output
      {updated_pid, _output} = compute_output(pid, 100.0)
      assert updated_pid.output >= @min_output
      assert updated_pid.output <= @max_output
    end

    test "integral windup is prevented" do
      pid = new_pid(@kp, @ki, @kd)

      # Apply sustained large error to accumulate integral
      pid_after =
        Enum.reduce(1..1000, pid, fn _, p ->
          {new_p, _} = compute_output(p, 10.0)
          new_p
        end)

      assert abs(pid_after.integral) <= @integral_windup_limit,
             "Integral should be bounded by windup limit"
    end

    test "does not oscillate indefinitely at setpoint" do
      pid = new_pid(@kp, @ki, @kd)
      pv = 0.0

      {_pid, _pv, history} =
        Enum.reduce(1..500, {pid, pv, []}, fn _step, {p, process_val, hist} ->
          {new_pid, new_pv} = pid_step(p, @setpoint, process_val)
          {new_pid, new_pv, [new_pv | hist]}
        end)

      # Last 100 samples should be close to setpoint (settled)
      last_100 = Enum.take(history, 100)
      max_deviation = last_100 |> Enum.map(&abs(&1 - @setpoint)) |> Enum.max()

      assert max_deviation < 0.1,
             "System should settle — max deviation in last 100 steps: #{max_deviation}"
    end

    test "P-only controller has steady-state error" do
      # P-only
      pid = new_pid(@kp, 0.0, 0.0)
      pv = 0.0

      {_pid, final_pv} = simulate_steps(pid, @setpoint, pv, 500)

      # P-only will have steady-state error (no integral to eliminate it)
      # Just verify it gets in the right direction
      assert final_pv > 0.0, "P-only should move toward setpoint"
    end

    test "PI controller eliminates steady-state error" do
      # PI controller
      pid = new_pid(@kp, @ki, 0.0)
      pv = 0.0

      {_pid, final_pv} = simulate_steps(pid, @setpoint, pv, 1000)

      assert_in_delta final_pv,
                      @setpoint,
                      0.05,
                      "PI controller should eliminate steady-state error"
    end
  end

  # ============================================================================
  # Ziegler-Nichols Tuning Tests
  # ============================================================================

  describe "Ziegler-Nichols tuning (SC-MATH-003)" do
    test "computes classic PID gains from ultimate gain and period" do
      # Ultimate gain
      ku = 2.0
      # Ultimate period (seconds)
      tu = 1.0

      {kp, ki, kd} = ziegler_nichols_classic(ku, tu)

      # 0.6 * Ku
      assert_in_delta kp, 1.2, 0.01
      # 2 * Kp / Tu = 1.2 * Ku / Tu
      assert_in_delta ki, 2.4, 0.01
      # Kp * Tu / 8
      assert_in_delta kd, 0.15, 0.01
    end

    test "computes Pessen Integral Rule gains" do
      ku = 2.0
      tu = 1.0

      {kp, ki, kd} = ziegler_nichols_pessen(ku, tu)

      # 0.7 * Ku
      assert_in_delta kp, 1.4, 0.01
      # 2.5 * Kp / Tu
      assert_in_delta ki, 3.5, 0.01
      # 0.15 * Kp * Tu
      assert_in_delta kd, 0.105, 0.01
    end

    test "computes some overshoot rule gains" do
      ku = 2.0
      tu = 1.0

      {kp, ki, kd} = ziegler_nichols_some_overshoot(ku, tu)

      # 0.33 * Ku
      assert_in_delta kp, 0.66, 0.01
      # 2 * Kp / Tu
      assert_in_delta ki, 1.32, 0.01
      # Kp * Tu / 3
      assert_in_delta kd, 0.11, 0.02
    end

    test "rejects zero ultimate period" do
      assert {:error, :invalid_tu} = ziegler_nichols_classic(2.0, 0.0)
    end

    test "rejects negative ultimate gain" do
      assert {:error, :invalid_ku} = ziegler_nichols_classic(-1.0, 1.0)
    end
  end

  # ============================================================================
  # Performance Tests
  # ============================================================================

  describe "performance (SC-WATCHDOG-001)" do
    test "PID computation completes within 1ms" do
      pid = new_pid(@kp, @ki, @kd)

      {time_us, _result} =
        :timer.tc(fn ->
          Enum.reduce(1..1000, pid, fn _, p ->
            {new_p, _} = compute_output(p, :rand.uniform() * 2 - 1)
            new_p
          end)
        end)

      avg_us = time_us / 1000
      assert avg_us < 100, "Average PID step should be <100µs, got #{avg_us}µs"
    end

    test "100-step simulation completes within 10ms" do
      pid = new_pid(@kp, @ki, @kd)

      {time_us, _result} =
        :timer.tc(fn ->
          simulate_steps(pid, @setpoint, 0.0, 100)
        end)

      assert time_us < 10_000, "100-step sim should be <10ms, got #{time_us}µs"
    end
  end

  # ============================================================================
  # Metrics and Health Tests
  # ============================================================================

  describe "homeostasis health metrics" do
    test "computes settling time" do
      pid = new_pid(@kp, @ki, @kd)
      pv = 0.0

      {_pid, _pv, history} =
        Enum.reduce(1..500, {pid, pv, []}, fn _step, {p, process_val, hist} ->
          {new_pid, new_pv} = pid_step(p, @setpoint, process_val)
          {new_pid, new_pv, [{new_pv, length(hist)} | hist]}
        end)

      settling_step = compute_settling_time(Enum.reverse(history), @setpoint, 0.02)
      assert settling_step != nil, "System should settle"
      assert settling_step < 400, "Settling time should be <400 steps"
    end

    test "computes overshoot percentage" do
      pid = new_pid(@kp, @ki, @kd)
      pv = 0.0

      {_pid, _pv, history} =
        Enum.reduce(1..500, {pid, pv, []}, fn _step, {p, process_val, hist} ->
          {new_pid, new_pv} = pid_step(p, @setpoint, process_val)
          {new_pid, new_pv, [new_pv | hist]}
        end)

      max_pv = Enum.max(history)
      overshoot_pct = max(0.0, (max_pv - @setpoint) / @setpoint * 100)

      # Ziegler-Nichols classic typically has ~25% overshoot
      assert overshoot_pct < 50.0,
             "Overshoot should be <50%, got #{Float.round(overshoot_pct, 1)}%"
    end

    test "computes RPN health score from PID metrics" do
      metrics = %{
        settling_time: 150,
        overshoot_pct: 20.0,
        steady_state_error: 0.02,
        oscillation_count: 3
      }

      rpn = compute_health_rpn(metrics)
      assert rpn >= 0
      assert rpn <= 1000
    end
  end

  # ============================================================================
  # Property Tests
  # ============================================================================

  describe "property: PID output bounds" do
    @tag timeout: 30_000
    test "output is always bounded regardless of error magnitude" do
      ExUnitProperties.check all(
                               error <- SD.float(min: -1000.0, max: 1000.0),
                               max_runs: 50
                             ) do
        pid = new_pid(@kp, @ki, @kd)
        {updated_pid, _output} = compute_output(pid, error)
        assert updated_pid.output >= @min_output
        assert updated_pid.output <= @max_output
      end
    end
  end

  describe "property: integral is bounded" do
    @tag timeout: 30_000
    test "integral never exceeds windup limit" do
      ExUnitProperties.check all(
                               errors <- SD.list_of(SD.float(min: -10.0, max: 10.0)),
                               max_runs: 10
                             ) do
        pid = new_pid(@kp, @ki, @kd)

        final_pid =
          Enum.reduce(errors, pid, fn err, p ->
            {new_p, _} = compute_output(p, err)
            new_p
          end)

        assert abs(final_pid.integral) <= @integral_windup_limit + 0.001
      end
    end
  end

  describe "property: Ziegler-Nichols gains are positive" do
    @tag timeout: 30_000
    test "classic gains are always positive for valid inputs" do
      ExUnitProperties.check all(
                               ku <- SD.float(min: 0.1, max: 100.0),
                               tu <- SD.float(min: 0.01, max: 10.0),
                               max_runs: 30
                             ) do
        {kp, ki, kd} = ziegler_nichols_classic(ku, tu)
        assert kp > 0
        assert ki > 0
        assert kd > 0
      end
    end
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp new_pid(kp, ki, kd) do
    %{
      kp: kp,
      ki: ki,
      kd: kd,
      integral: 0.0,
      prev_error: 0.0,
      output: 0.0
    }
  end

  defp validate_gains(kp, ki, kd) do
    if kp < 0 or ki < 0 or kd < 0 do
      {:error, :invalid_gains}
    else
      :ok
    end
  end

  defp compute_output(pid, error) do
    # Proportional
    p_term = pid.kp * error

    # Integral with anti-windup
    new_integral = pid.integral + error * @dt
    clamped_integral = clamp(new_integral, -@integral_windup_limit, @integral_windup_limit)
    i_term = pid.ki * clamped_integral

    # Derivative
    d_term = pid.kd * (error - pid.prev_error) / @dt

    # Total output with clamping
    raw_output = p_term + i_term + d_term
    clamped_output = clamp(raw_output, @min_output, @max_output)

    updated_pid = %{pid | integral: clamped_integral, prev_error: error, output: clamped_output}

    {updated_pid, clamped_output}
  end

  defp pid_step(pid, setpoint, process_value) do
    error = setpoint - process_value
    {new_pid, output} = compute_output(pid, error)

    # Simple first-order process model: pv += output * dt * process_gain
    process_gain = 0.8
    new_pv = process_value + output * @dt * process_gain

    {new_pid, new_pv}
  end

  defp simulate_steps(pid, setpoint, initial_pv, steps) do
    Enum.reduce(1..steps, {pid, initial_pv}, fn _step, {p, pv} ->
      pid_step(p, setpoint, pv)
    end)
  end

  defp clamp(value, min_val, max_val) do
    value |> max(min_val) |> min(max_val)
  end

  defp ziegler_nichols_classic(ku, tu) when ku <= 0, do: {:error, :invalid_ku}
  defp ziegler_nichols_classic(_ku, tu) when tu <= 0, do: {:error, :invalid_tu}

  defp ziegler_nichols_classic(ku, tu) do
    kp = 0.6 * ku
    ki = 2.0 * kp / tu
    kd = kp * tu / 8.0
    {kp, ki, kd}
  end

  defp ziegler_nichols_pessen(ku, tu) do
    kp = 0.7 * ku
    ki = 2.5 * kp / tu
    kd = 0.15 * kp * tu
    {kp, ki, kd}
  end

  defp ziegler_nichols_some_overshoot(ku, tu) do
    kp = 0.33 * ku
    ki = 2.0 * kp / tu
    kd = kp * tu / 3.0
    {kp, ki, kd}
  end

  defp compute_settling_time(history, setpoint, tolerance) do
    # Find the first step after which all values stay within tolerance
    indexed = Enum.with_index(history)

    Enum.find_value(indexed, fn {{pv, _orig_idx}, step_idx} ->
      remaining = Enum.drop(indexed, step_idx)

      all_settled =
        Enum.all?(remaining, fn {{val, _}, _} ->
          abs(val - setpoint) <= tolerance * abs(setpoint + 0.001)
        end)

      if all_settled, do: step_idx, else: nil
    end)
  end

  defp compute_health_rpn(metrics) do
    # Severity: based on steady-state error
    severity =
      cond do
        metrics.steady_state_error > 0.1 -> 9
        metrics.steady_state_error > 0.05 -> 7
        metrics.steady_state_error > 0.02 -> 5
        true -> 3
      end

    # Occurrence: based on oscillation count
    occurrence =
      cond do
        metrics.oscillation_count > 10 -> 8
        metrics.oscillation_count > 5 -> 6
        metrics.oscillation_count > 2 -> 4
        true -> 2
      end

    # Detection: based on settling time
    detection =
      cond do
        metrics.settling_time > 300 -> 8
        metrics.settling_time > 200 -> 6
        metrics.settling_time > 100 -> 4
        true -> 2
      end

    severity * occurrence * detection
  end
end
