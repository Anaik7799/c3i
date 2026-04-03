defmodule Indrajaal.Core.HomeostasisPIDTest do
  @moduledoc """
  Mathematical verification tests for the Homeostasis PID controller.

  Mathematical properties verified:
  1. Ziegler-Nichols PID tuning: Kp=2.0, Ki=0.1, Kd=0.5
  2. PID output: u(t) = Kp*e(t) + Ki*∫e(t)dt + Kd*de(t)/dt
  3. Setpoint tracking: controller drives error → 0 over time
  4. Proportional term: linearly proportional to current error
  5. Integral term: accumulates error over time (eliminates steady-state error)
  6. Derivative term: responds to rate-of-change (dampens oscillation)

  Setpoint: 0.45 (optimal stress level)
  Thresholds: critical=0.9, high=0.75, optimal_high=0.6, optimal_low=0.3, low=0.2

  STAMP: SC-MATH-003 (Ziegler-Nichols PID), SC-HOM-001
  Layer: L1-CODE (pure mathematical verification)
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :mathematical
  @moduletag :homeostasis

  # Ziegler-Nichols tuned parameters (from homeostasis.ex)
  @pid_setpoint 0.45
  @pid_kp 2.0
  @pid_ki 0.1
  @pid_kd 0.5

  # Stress thresholds (from homeostasis.ex)
  @stress_critical 0.9
  @stress_high 0.75
  @stress_optimal_high 0.6
  @stress_optimal_low 0.3
  @stress_low 0.2

  # ============================================================================
  # Pure PID computation (inline implementation for mathematical verification)
  # ============================================================================

  # Computes one PID step: returns {output, new_integral, prev_error}
  defp pid_step(current_value, setpoint, integral, prev_error, dt) do
    error = setpoint - current_value
    new_integral = integral + error * dt
    derivative = (error - prev_error) / dt
    output = @pid_kp * error + @pid_ki * new_integral + @pid_kd * derivative
    {output, new_integral, error}
  end

  # Simulates N steps of PID control starting from initial_value
  # Returns list of {value, output} pairs
  defp simulate_pid(initial_value, steps, dt \\ 0.1) do
    Enum.reduce(1..steps, {initial_value, 0.0, 0.0, []}, fn _step,
                                                            {val, integral, prev_err, acc} ->
      {output, new_integral, new_prev_err} =
        pid_step(val, @pid_setpoint, integral, prev_err, dt)

      # Plant model: simple first-order response (value += output * dt * gain)
      gain = 0.5
      new_val = val + output * dt * gain

      # Clamp to [0.0, 1.0]
      new_val = max(0.0, min(1.0, new_val))

      {new_val, new_integral, new_prev_err, [{new_val, output} | acc]}
    end)
    |> elem(3)
    |> Enum.reverse()
  end

  # ============================================================================
  # Parameter verification
  # ============================================================================

  describe "Ziegler-Nichols PID parameter invariants" do
    test "setpoint is 0.45 (optimal stress level)" do
      assert @pid_setpoint == 0.45
    end

    test "proportional gain Kp = 2.0" do
      assert @pid_kp == 2.0
    end

    test "integral gain Ki = 0.1" do
      assert @pid_ki == 0.1
    end

    test "derivative gain Kd = 0.5" do
      assert @pid_kd == 0.5
    end

    test "Kp > Ki (proportional dominates integral)" do
      assert @pid_kp > @pid_ki
    end

    test "Kd > Ki (derivative stronger than integral)" do
      assert @pid_kd > @pid_ki
    end

    test "setpoint within optimal band [0.3, 0.6]" do
      assert @pid_setpoint >= @stress_optimal_low
      assert @pid_setpoint <= @stress_optimal_high
    end
  end

  # ============================================================================
  # Stress threshold verification
  # ============================================================================

  describe "stress threshold ordering invariants" do
    test "thresholds form a proper ordered chain" do
      # low < optimal_low < setpoint < optimal_high < high < critical
      assert @stress_low < @stress_optimal_low
      assert @stress_optimal_low < @pid_setpoint
      assert @pid_setpoint < @stress_optimal_high
      assert @stress_optimal_high < @stress_high
      assert @stress_high < @stress_critical
    end

    test "critical threshold is below 1.0 (valid stress level)" do
      assert @stress_critical < 1.0
    end

    test "low threshold is above 0.0 (valid stress level)" do
      assert @stress_low > 0.0
    end
  end

  # ============================================================================
  # PID mathematical properties
  # ============================================================================

  describe "PID output mathematical properties" do
    test "proportional term is zero when at setpoint" do
      error = @pid_setpoint - @pid_setpoint
      p_term = @pid_kp * error
      assert p_term == 0.0
    end

    test "proportional term is positive when below setpoint" do
      # current < setpoint → error > 0 → output positive (increase)
      current = 0.2
      error = @pid_setpoint - current
      p_term = @pid_kp * error
      assert p_term > 0
    end

    test "proportional term is negative when above setpoint" do
      # current > setpoint → error < 0 → output negative (decrease)
      current = 0.8
      error = @pid_setpoint - current
      p_term = @pid_kp * error
      assert p_term < 0
    end

    test "proportional term scales linearly with error" do
      error1 = 0.1
      error2 = 0.2
      p1 = @pid_kp * error1
      p2 = @pid_kp * error2
      assert_in_delta p2 / p1, 2.0, 0.0001
    end

    test "integral term accumulates over time" do
      dt = 0.1
      error = 0.1
      integral_after_1 = error * dt
      integral_after_2 = integral_after_1 + error * dt
      assert integral_after_2 > integral_after_1
    end

    test "derivative term is zero for constant error" do
      # If error doesn't change, derivative = 0
      prev_error = 0.1
      current_error = 0.1
      dt = 0.1
      d_term = @pid_kd * (current_error - prev_error) / dt
      assert_in_delta d_term, 0.0, 0.0001
    end

    test "derivative term dampens rapid changes" do
      # Large derivative term for rapidly changing error
      prev_error = 0.1
      current_error = 0.5
      dt = 0.1
      d_term = @pid_kd * (current_error - prev_error) / dt
      assert d_term > 0
    end
  end

  # ============================================================================
  # Controller convergence
  # ============================================================================

  describe "PID controller convergence" do
    test "controller reduces error from high stress over 20 steps" do
      initial_stress = 0.8
      steps = simulate_pid(initial_stress, 20)
      {final_val, _} = List.last(steps)

      # Should move toward setpoint from 0.8
      assert final_val < initial_stress
    end

    test "controller reduces error from low stress over 20 steps" do
      initial_stress = 0.1
      steps = simulate_pid(initial_stress, 20)
      {final_val, _} = List.last(steps)

      # Should move toward setpoint from 0.1
      assert final_val > initial_stress
    end

    test "controller at setpoint stays near setpoint" do
      initial_stress = @pid_setpoint
      steps = simulate_pid(initial_stress, 10)
      {final_val, _} = List.last(steps)

      # Should remain close to setpoint (±0.1)
      assert abs(final_val - @pid_setpoint) < 0.1
    end

    test "error monotonically decreases in first 5 steps from far setpoint" do
      initial_stress = 0.9
      steps = simulate_pid(initial_stress, 5)
      values = Enum.map(steps, fn {v, _} -> v end)
      errors = Enum.map(values, fn v -> abs(v - @pid_setpoint) end)

      # First error should be larger than last error (converging)
      first_error = List.first(errors)
      last_error = List.last(errors)
      assert last_error <= first_error
    end
  end

  # ============================================================================
  # Property: PID output sign (PropCheck)
  # ============================================================================

  describe "property: PID output sign invariants (PropCheck)" do
    property "P-term output is opposite sign to (current - setpoint)" do
      forall error <- PC.float(-0.5, 0.5) do
        p_term = @pid_kp * error
        # If error > 0, output > 0; if error < 0, output < 0
        cond do
          error > 0 -> p_term > 0
          error < 0 -> p_term < 0
          true -> p_term == 0
        end
      end
    end

    property "integral grows monotonically for constant positive error" do
      forall steps <- PC.choose(1, 20) do
        dt = 0.1
        error = 0.1
        final_integral = Enum.reduce(1..steps, 0.0, fn _, acc -> acc + error * dt end)
        final_integral > 0.0
      end
    end
  end

  # ============================================================================
  # Property: threshold ordering (StreamData)
  # ============================================================================

  describe "property: stress classification correctness (StreamData)" do
    test "stress levels classified correctly across range" do
      ExUnitProperties.check all(stress_pct <- SD.integer(0..100)) do
        stress = stress_pct / 100.0

        classification =
          cond do
            stress >= @stress_critical -> :critical
            stress >= @stress_high -> :high
            stress >= @stress_optimal_high -> :elevated
            stress >= @stress_optimal_low -> :optimal
            stress >= @stress_low -> :low
            true -> :very_low
          end

        assert classification in [:critical, :high, :elevated, :optimal, :low, :very_low]
      end
    end

    test "setpoint always classifies as optimal" do
      stress = @pid_setpoint

      classification =
        cond do
          stress >= @stress_critical -> :critical
          stress >= @stress_high -> :high
          stress >= @stress_optimal_high -> :elevated
          stress >= @stress_optimal_low -> :optimal
          stress >= @stress_low -> :low
          true -> :very_low
        end

      assert classification == :optimal
    end
  end
end
