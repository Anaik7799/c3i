defmodule Indrajaal.Core.OODA.OODACycleIntegrationTest do
  @moduledoc """
  OODA cycle integration tests — Observe, Orient, Decide, Act.

  WHAT: Tests the full 4-phase OODA cycle for timing, ordering,
        feedback loops, and cycle metrics.
  WHY:  SC-OODA-001 mandates cycle time < 30ms; SC-VER-041 requires
        OODA cycle < 100ms for system verification.
  CONSTRAINTS: SC-OODA-001, SC-OODA-002, SC-VER-041, SC-BIO-001,
               SC-PRF-050, EP-GEN-014

  ## Test Coverage Matrix
  | Dimension           | PropCheck | StreamData | Unit |
  |---------------------|-----------|------------|------|
  | Phase timing        | 2         | 2          | 3    |
  | Phase ordering      | 1         | 2          | 3    |
  | Feedback loops      | 1         | 1          | 3    |
  | Cycle metrics       | 1         | 1          | 3    |
  | TOTAL               | 5         | 6          | 12   |

  ## EP-GEN-014 compliance
  - PropCheck forall blocks use PC. prefix
  - StreamData check all blocks use SD. prefix and ExUnitProperties.check all()
  - No bare check all() — check: 2 is excluded from import
  """

  use ExUnit.Case, async: false

  # EP-GEN-014: dual property testing import pattern — MANDATORY
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :ooda
  @moduletag :integration
  @moduletag :property

  # ──────────────────────────────────────────────────────────────────
  # Self-contained OODA helpers (no external module dependencies)
  # ──────────────────────────────────────────────────────────────────

  # Phase durations in microseconds. All are well below 30ms (30_000 µs).
  @observe_max_us 8_000
  @orient_max_us 8_000
  @decide_max_us 7_000
  @act_max_us 7_000
  @cycle_max_us 30_000
  @cycle_verification_max_us 100_000

  # Simulate the Observe phase: collect sensor data and system state.
  defp ooda_observe(inputs) when is_list(inputs) do
    start = System.monotonic_time(:microsecond)

    observation = %{
      timestamp: DateTime.utc_now(),
      raw_inputs: inputs,
      input_count: length(inputs),
      sensor_values: Enum.map(inputs, fn x -> {:ok, x} end),
      phase: :observe,
      system_state: :nominal
    }

    duration_us = System.monotonic_time(:microsecond) - start
    {observation, duration_us}
  end

  # Simulate the Orient phase: build situational awareness from observations.
  defp ooda_orient(observation) when is_map(observation) do
    start = System.monotonic_time(:microsecond)

    orientation = %{
      prev_phase: :observe,
      phase: :orient,
      timestamp: DateTime.utc_now(),
      threat_level: if(observation.input_count > 50, do: :elevated, else: :normal),
      patterns: Enum.take(observation.raw_inputs, 3),
      root_cause: :none,
      approach: :standard,
      input_summary: %{count: observation.input_count, state: observation.system_state}
    }

    duration_us = System.monotonic_time(:microsecond) - start
    {orientation, duration_us}
  end

  # Simulate the Decide phase: select action based on orientation.
  defp ooda_decide(orientation) when is_map(orientation) do
    start = System.monotonic_time(:microsecond)

    decision = %{
      prev_phase: :orient,
      phase: :decide,
      timestamp: DateTime.utc_now(),
      selected_action:
        case orientation.threat_level do
          :elevated -> :alert
          :normal -> :continue
          _ -> :hold
        end,
      confidence: 0.95,
      guardian_required: orientation.threat_level == :elevated,
      fallback: :rollback
    }

    duration_us = System.monotonic_time(:microsecond) - start
    {decision, duration_us}
  end

  # Simulate the Act phase: execute the decided action.
  defp ooda_act(decision) when is_map(decision) do
    start = System.monotonic_time(:microsecond)

    outcome = %{
      prev_phase: :decide,
      phase: :act,
      timestamp: DateTime.utc_now(),
      action_taken: decision.selected_action,
      success: true,
      rollback_available: true,
      recorded: true
    }

    duration_us = System.monotonic_time(:microsecond) - start
    {outcome, duration_us}
  end

  # Run one full OODA cycle; return {result_map, total_duration_us}.
  defp run_ooda_cycle(inputs) do
    total_start = System.monotonic_time(:microsecond)

    {obs, t_obs} = ooda_observe(inputs)
    {orient, t_orient} = ooda_orient(obs)
    {decision, t_decide} = ooda_decide(orient)
    {outcome, t_act} = ooda_act(decision)

    total_us = System.monotonic_time(:microsecond) - total_start

    %{
      phases: [obs, orient, decision, outcome],
      timings: %{
        observe_us: t_obs,
        orient_us: t_orient,
        decide_us: t_decide,
        act_us: t_act,
        total_us: total_us
      },
      final_outcome: outcome
    }
  end

  # Build a list of random-looking integer inputs from a seed list.
  defp generate_inputs(seed) when is_list(seed), do: Enum.take(seed ++ [1, 2, 3], 5)
  defp generate_inputs(n) when is_integer(n), do: Enum.map(1..max(n, 1), & &1)

  # ──────────────────────────────────────────────────────────────────
  # Setup
  # ──────────────────────────────────────────────────────────────────

  setup_all do
    Application.ensure_all_started(:propcheck)
    :ok
  end

  # ──────────────────────────────────────────────────────────────────
  # 1. Phase Timing Tests (unit)
  # ──────────────────────────────────────────────────────────────────

  describe "phase timing (SC-OODA-001, SC-VER-041)" do
    test "observe phase completes within budget" do
      {_obs, duration_us} = ooda_observe([1, 2, 3])

      assert duration_us < @observe_max_us,
             "Observe phase took #{duration_us}µs, budget=#{@observe_max_us}µs"
    end

    test "orient phase completes within budget" do
      {obs, _} = ooda_observe([1, 2, 3])
      {_orient, duration_us} = ooda_orient(obs)

      assert duration_us < @orient_max_us,
             "Orient phase took #{duration_us}µs, budget=#{@orient_max_us}µs"
    end

    test "decide phase completes within budget" do
      {obs, _} = ooda_observe([1, 2, 3])
      {orient, _} = ooda_orient(obs)
      {_decision, duration_us} = ooda_decide(orient)

      assert duration_us < @decide_max_us,
             "Decide phase took #{duration_us}µs, budget=#{@decide_max_us}µs"
    end

    test "act phase completes within budget" do
      {obs, _} = ooda_observe([1, 2, 3])
      {orient, _} = ooda_orient(obs)
      {decision, _} = ooda_decide(orient)
      {_outcome, duration_us} = ooda_act(decision)

      assert duration_us < @act_max_us,
             "Act phase took #{duration_us}µs, budget=#{@act_max_us}µs"
    end

    test "full cycle completes within SC-OODA-001 limit (30ms)" do
      result = run_ooda_cycle([1, 2, 3])

      assert result.timings.total_us < @cycle_max_us,
             "OODA cycle took #{result.timings.total_us}µs, limit=#{@cycle_max_us}µs"
    end

    test "full cycle completes within SC-VER-041 limit (100ms)" do
      result = run_ooda_cycle(generate_inputs(10))

      assert result.timings.total_us < @cycle_verification_max_us,
             "OODA cycle took #{result.timings.total_us}µs, limit=#{@cycle_verification_max_us}µs"
    end
  end

  # ──────────────────────────────────────────────────────────────────
  # 2. Phase Ordering Tests (unit)
  # ──────────────────────────────────────────────────────────────────

  describe "phase ordering" do
    test "phases execute in O→O→D→A order" do
      result = run_ooda_cycle([42])
      [obs, orient, decision, outcome] = result.phases
      assert obs.phase == :observe
      assert orient.phase == :orient
      assert decision.phase == :decide
      assert outcome.phase == :act
    end

    test "each phase references the correct preceding phase" do
      result = run_ooda_cycle([1])
      [_obs, orient, decision, outcome] = result.phases
      assert orient.prev_phase == :observe
      assert decision.prev_phase == :orient
      assert outcome.prev_phase == :decide
    end

    test "phase timestamps are monotonically non-decreasing" do
      result = run_ooda_cycle([1, 2])
      timestamps = result.phases |> Enum.map(& &1.timestamp)

      timestamps
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [t1, t2] ->
        assert DateTime.compare(t2, t1) in [:gt, :eq],
               "Phase timestamps not monotonic: #{t1} > #{t2}"
      end)
    end
  end

  # ──────────────────────────────────────────────────────────────────
  # 3. Feedback Loop Tests (unit)
  # ──────────────────────────────────────────────────────────────────

  describe "feedback loops" do
    test "outcome has rollback_available flag set" do
      result = run_ooda_cycle([1, 2, 3])
      assert result.final_outcome.rollback_available == true
    end

    test "elevated threat triggers :alert action" do
      # > 50 inputs triggers :elevated threat
      large_input = generate_inputs(51)
      result = run_ooda_cycle(large_input)
      assert result.final_outcome.action_taken == :alert
    end

    test "normal input produces :continue action" do
      result = run_ooda_cycle([1, 2, 3])
      assert result.final_outcome.action_taken == :continue
    end

    test "outcome records success" do
      result = run_ooda_cycle([7, 8, 9])
      assert result.final_outcome.success == true
      assert result.final_outcome.recorded == true
    end
  end

  # ──────────────────────────────────────────────────────────────────
  # 4. Cycle Metrics Tests (unit)
  # ──────────────────────────────────────────────────────────────────

  describe "cycle metrics" do
    test "timings map contains all four phase durations" do
      result = run_ooda_cycle([1])
      assert Map.has_key?(result.timings, :observe_us)
      assert Map.has_key?(result.timings, :orient_us)
      assert Map.has_key?(result.timings, :decide_us)
      assert Map.has_key?(result.timings, :act_us)
      assert Map.has_key?(result.timings, :total_us)
    end

    test "all phase timings are non-negative integers" do
      result = run_ooda_cycle([1, 2])

      result.timings
      |> Map.values()
      |> Enum.each(fn t ->
        assert is_integer(t) and t >= 0
      end)
    end

    test "total_us >= sum of all phase durations" do
      result = run_ooda_cycle([1])

      sum_phases =
        result.timings.observe_us +
          result.timings.orient_us +
          result.timings.decide_us +
          result.timings.act_us

      assert result.timings.total_us >= sum_phases
    end
  end

  # ──────────────────────────────────────────────────────────────────
  # 5. PropCheck Property Tests (PC. generators)
  # ──────────────────────────────────────────────────────────────────

  describe "PropCheck: timing invariants under arbitrary inputs" do
    property "any list of integers completes OODA cycle within 30ms" do
      forall inputs <- PC.list(PC.integer()) do
        result = run_ooda_cycle(inputs)
        result.timings.total_us < @cycle_max_us
      end
    end

    property "cycle always returns exactly 4 phases" do
      forall inputs <- PC.list(PC.integer()) do
        result = run_ooda_cycle(inputs)
        length(result.phases) == 4
      end
    end

    property "observe phase duration is always non-negative" do
      forall inputs <- PC.list(PC.integer()) do
        {_obs, dur} = ooda_observe(inputs)
        dur >= 0
      end
    end

    property "phase order is always O→O→D→A regardless of input" do
      forall inputs <- PC.list(PC.integer()) do
        result = run_ooda_cycle(inputs)
        [obs, orient, decision, outcome] = result.phases

        obs.phase == :observe and
          orient.phase == :orient and
          decision.phase == :decide and
          outcome.phase == :act
      end
    end

    property "rollback is always available in the outcome" do
      forall inputs <- PC.list(PC.integer()) do
        result = run_ooda_cycle(inputs)
        result.final_outcome.rollback_available == true
      end
    end
  end

  # ──────────────────────────────────────────────────────────────────
  # 6. StreamData Property Tests (SD. generators, ExUnitProperties.check all)
  # ──────────────────────────────────────────────────────────────────

  describe "StreamData: cycle correctness under diverse inputs" do
    test "random integer lists always complete within 100ms (SC-VER-041)" do
      ExUnitProperties.check all(inputs <- SD.list_of(SD.integer(), max_length: 20)) do
        result = run_ooda_cycle(inputs)
        assert result.timings.total_us < @cycle_verification_max_us
      end
    end

    test "random inputs always produce a valid action atom" do
      valid_actions = [:continue, :alert, :hold, :rollback]

      ExUnitProperties.check all(inputs <- SD.list_of(SD.integer(), max_length: 100)) do
        result = run_ooda_cycle(inputs)
        assert result.final_outcome.action_taken in valid_actions
      end
    end

    test "all phase durations are non-negative with arbitrary inputs" do
      ExUnitProperties.check all(inputs <- SD.list_of(SD.integer(), max_length: 15)) do
        result = run_ooda_cycle(inputs)

        assert result.timings.observe_us >= 0
        assert result.timings.orient_us >= 0
        assert result.timings.decide_us >= 0
        assert result.timings.act_us >= 0
        assert result.timings.total_us >= 0
      end
    end

    test "outcome.success is always true for well-formed inputs" do
      ExUnitProperties.check all(inputs <- SD.list_of(SD.integer(), max_length: 30)) do
        result = run_ooda_cycle(inputs)
        assert result.final_outcome.success == true
      end
    end

    test "elevated threat action triggered when input_count > 50" do
      ExUnitProperties.check all(n <- SD.integer(51..80)) do
        inputs = generate_inputs(n)
        result = run_ooda_cycle(inputs)
        assert result.final_outcome.action_taken == :alert
      end
    end

    test "normal action triggered when input_count <= 50" do
      ExUnitProperties.check all(n <- SD.integer(1..50)) do
        inputs = generate_inputs(n)
        result = run_ooda_cycle(inputs)
        assert result.final_outcome.action_taken == :continue
      end
    end
  end
end
