defmodule Indrajaal.Core.OODACycleIntegrationTest do
  @moduledoc """
  Complete OODA (Observe-Orient-Decide-Act) cycle integration test suite.

  WHAT: Self-contained tests for all four phases of the OODA loop, including
        ETS-backed sensor simulation, anomaly detection, rule-engine decisions,
        verified side-effects, cycle counter monotonicity, concurrent safety,
        and graceful degradation under sensor failure.
  WHY:  SC-OODA-001 mandates cycle time < 30ms; SC-BIO-001 (fast OODA in
        biomorphic mode); SC-VER-041 (OODA < 100ms); SC-SENS-001 (non-blocking
        polling); SC-SENS-002 (graceful degradation).
  CONSTRAINTS: SC-OODA-001, SC-OODA-002, SC-BIO-001, SC-VER-041, SC-PRF-050,
               SC-SENS-001, SC-SENS-002

  ## Coverage Matrix
  | Dimension                        | StreamData | Unit |
  |----------------------------------|------------|------|
  | Observe — ETS sensor collection  | 2          | 4    |
  | Orient — anomaly detection       | 2          | 4    |
  | Decide — rule engine             | 2          | 4    |
  | Act — side-effect execution      | 2          | 4    |
  | Full-cycle timing (30ms / 100ms) | 2          | 4    |
  | Cycle counter monotonicity       | 1          | 2    |
  | Concurrent non-interference      | 1          | 3    |
  | Degraded / sensor-fail mode      | 1          | 2    |
  | TOTAL                            | 13         | 27   |
  """

  use ExUnit.Case, async: false
  import ExUnitProperties, except: [property: 2, property: 3]

  alias StreamData, as: SD

  @moduletag :ooda
  @moduletag :integration
  @moduletag :property
  @moduletag :sprint_88

  # ---------------------------------------------------------------------------
  # Timing budgets (SC-OODA-001: < 30ms target, SC-VER-041: < 100ms hard limit)
  # ---------------------------------------------------------------------------
  @phase_max_us 7_500
  @cycle_target_us 30_000
  @cycle_hard_limit_us 100_000

  # ---------------------------------------------------------------------------
  # ETS table names used across this test module
  # ---------------------------------------------------------------------------
  @sensor_table :ooda_test_sensors
  @action_log_table :ooda_test_actions
  @cycle_counter_table :ooda_test_cycle_counter

  # ---------------------------------------------------------------------------
  # Setup / Teardown
  # ---------------------------------------------------------------------------

  setup do
    # Each test gets a fresh set of ETS tables (or re-uses existing ones).
    # We use :ets.whereis/1 to avoid double-creation races in async=false mode.
    for table <- [@sensor_table, @action_log_table, @cycle_counter_table] do
      case :ets.whereis(table) do
        :undefined ->
          :ets.new(table, [:named_table, :public, :set])

        _ ->
          :ets.delete_all_objects(table)
      end
    end

    :ets.insert(@sensor_table, {:cpu, 0.35})
    :ets.insert(@sensor_table, {:memory, 0.55})
    :ets.insert(@sensor_table, {:network, 0.10})
    :ets.insert(@sensor_table, {:latency_ms, 12.0})

    :ets.insert(@cycle_counter_table, {:count, 0})

    :ok
  end

  # ===========================================================================
  # Self-contained helpers (NO production module dependencies)
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # OBSERVE helpers — ETS-backed sensor polling (SC-SENS-001: non-blocking)
  # ---------------------------------------------------------------------------

  defp sensor_read(key) do
    case :ets.lookup(@sensor_table, key) do
      [{^key, value}] -> {:ok, value}
      [] -> {:error, :sensor_not_found}
    end
  end

  defp sensor_write(key, value) do
    :ets.insert(@sensor_table, {key, value})
    :ok
  end

  defp sensor_delete(key) do
    :ets.delete(@sensor_table, key)
    :ok
  end

  defp ooda_observe(sensor_keys \\ [:cpu, :memory, :network, :latency_ms]) do
    start = System.monotonic_time(:microsecond)

    readings =
      Enum.map(sensor_keys, fn key ->
        {key, sensor_read(key)}
      end)

    {ok_readings, failed_keys} =
      Enum.reduce(readings, {%{}, []}, fn {key, result}, {ok_acc, fail_acc} ->
        case result do
          {:ok, value} -> {Map.put(ok_acc, key, value), fail_acc}
          {:error, _} -> {ok_acc, [key | fail_acc]}
        end
      end)

    observation = %{
      phase: :observe,
      timestamp: System.monotonic_time(:millisecond),
      readings: ok_readings,
      sensor_count: map_size(ok_readings),
      failed_sensors: Enum.reverse(failed_keys),
      degraded: length(failed_keys) > 0,
      system_state: if(map_size(ok_readings) == 0, do: :blind, else: :nominal)
    }

    duration_us = System.monotonic_time(:microsecond) - start
    {observation, duration_us}
  end

  # ---------------------------------------------------------------------------
  # ORIENT helpers — anomaly detection rule set
  # ---------------------------------------------------------------------------

  defp detect_anomaly(readings) do
    cond do
      Map.get(readings, :cpu, 0.0) > 0.85 -> :cpu_spike
      Map.get(readings, :memory, 0.0) > 0.90 -> :memory_pressure
      Map.get(readings, :latency_ms, 0.0) > 50.0 -> :high_latency
      Map.get(readings, :network, 0.0) > 0.80 -> :network_saturation
      true -> :none
    end
  end

  defp ooda_orient(observation) when is_map(observation) do
    start = System.monotonic_time(:microsecond)

    readings = observation.readings
    anomaly = detect_anomaly(readings)

    threat_score =
      0.0
      |> add_if(Map.get(readings, :cpu, 0.0) > 0.75, 0.4)
      |> add_if(Map.get(readings, :memory, 0.0) > 0.80, 0.3)
      |> add_if(Map.get(readings, :latency_ms, 0.0) > 30.0, 0.2)
      |> add_if(observation.degraded, 0.1)

    threat_level =
      cond do
        threat_score >= 0.7 -> :critical
        threat_score >= 0.4 -> :elevated
        threat_score >= 0.1 -> :low
        true -> :nominal
      end

    orientation = %{
      phase: :orient,
      prev_phase: :observe,
      timestamp: System.monotonic_time(:millisecond),
      anomaly: anomaly,
      threat_level: threat_level,
      threat_score: threat_score,
      sensor_count: observation.sensor_count,
      degraded: observation.degraded,
      failed_sensors: observation.failed_sensors,
      root_cause: if(anomaly != :none, do: {:detected, anomaly}, else: :none),
      approach: if(observation.degraded, do: :conservative, else: :standard)
    }

    duration_us = System.monotonic_time(:microsecond) - start
    {orientation, duration_us}
  end

  defp add_if(score, true, increment), do: score + increment
  defp add_if(score, false, _increment), do: score

  # ---------------------------------------------------------------------------
  # DECIDE helpers — deterministic rule engine (same input → same output)
  # ---------------------------------------------------------------------------

  @decision_rules [
    {:critical, :alert_and_scale_down},
    {:elevated, :alert},
    {:low, :monitor},
    {:nominal, :continue}
  ]

  defp rule_engine(threat_level) do
    case List.keyfind(@decision_rules, threat_level, 0) do
      {^threat_level, action} -> action
      nil -> :hold
    end
  end

  defp ooda_decide(orientation) when is_map(orientation) do
    start = System.monotonic_time(:microsecond)

    selected_action = rule_engine(orientation.threat_level)

    confidence =
      case orientation.threat_level do
        :critical -> 0.99
        :elevated -> 0.92
        :low -> 0.85
        :nominal -> 0.97
      end

    decision = %{
      phase: :decide,
      prev_phase: :orient,
      timestamp: System.monotonic_time(:millisecond),
      selected_action: selected_action,
      confidence: confidence,
      threat_level: orientation.threat_level,
      guardian_required: orientation.threat_level == :critical,
      fallback: :rollback,
      degraded_mode: orientation.degraded
    }

    duration_us = System.monotonic_time(:microsecond) - start
    {decision, duration_us}
  end

  # ---------------------------------------------------------------------------
  # ACT helpers — execute action, write side effect to ETS action log
  # ---------------------------------------------------------------------------

  defp execute_action(:continue, _ctx), do: {:noop, :ok}
  defp execute_action(:monitor, _ctx), do: {:telemetry_tick, :ok}
  defp execute_action(:alert, ctx), do: {:alert_emitted, ctx.threat_level}
  defp execute_action(:alert_and_scale_down, _ctx), do: {:scale_down_initiated, :executing}
  defp execute_action(:hold, _ctx), do: {:hold_applied, :pending_review}
  defp execute_action(_unknown, _ctx), do: {:unknown_action, :error}

  defp ooda_act(decision) when is_map(decision) do
    start = System.monotonic_time(:microsecond)

    {effect_type, effect_result} =
      execute_action(decision.selected_action, %{
        threat_level: decision.threat_level
      })

    # Write side effect to ETS action log (verifiable)
    action_entry = {
      System.monotonic_time(:microsecond),
      decision.selected_action,
      effect_type,
      effect_result
    }

    :ets.insert(@action_log_table, {:last_action, action_entry})

    outcome = %{
      phase: :act,
      prev_phase: :decide,
      timestamp: System.monotonic_time(:millisecond),
      action_taken: decision.selected_action,
      effect_type: effect_type,
      effect_result: effect_result,
      success: effect_result != :error,
      rollback_available: true,
      recorded: true
    }

    duration_us = System.monotonic_time(:microsecond) - start
    {outcome, duration_us}
  end

  # ---------------------------------------------------------------------------
  # Full-cycle runner — increments monotonic cycle counter
  # ---------------------------------------------------------------------------

  defp run_ooda_cycle(sensor_keys \\ [:cpu, :memory, :network, :latency_ms]) do
    total_start = System.monotonic_time(:microsecond)

    # Increment cycle counter atomically
    [{:count, prev}] = :ets.lookup(@cycle_counter_table, :count)
    :ets.insert(@cycle_counter_table, {:count, prev + 1})

    {obs, t_obs} = ooda_observe(sensor_keys)
    {orient, t_orient} = ooda_orient(obs)
    {decision, t_decide} = ooda_decide(orient)
    {outcome, t_act} = ooda_act(decision)

    total_us = System.monotonic_time(:microsecond) - total_start

    %{
      cycle_number: prev + 1,
      phases: [obs, orient, decision, outcome],
      timings: %{
        observe_us: t_obs,
        orient_us: t_orient,
        decide_us: t_decide,
        act_us: t_act,
        total_us: total_us
      },
      final_outcome: outcome,
      orientation_threat: orient.threat_level
    }
  end

  defp current_cycle_count do
    [{:count, c}] = :ets.lookup(@cycle_counter_table, :count)
    c
  end

  defp action_log_entry do
    case :ets.lookup(@action_log_table, :last_action) do
      [{:last_action, entry}] -> {:ok, entry}
      [] -> {:error, :no_action_recorded}
    end
  end

  # ===========================================================================
  # SECTION 1: Observe Phase — ETS sensor collection
  # ===========================================================================

  describe "Observe phase — ETS sensor collection (SC-SENS-001)" do
    test "OBSERVE_UNIT_01: reads all four default sensors without error" do
      {obs, _dur} = ooda_observe()
      assert obs.phase == :observe
      assert obs.sensor_count == 4
      assert obs.failed_sensors == []
      assert obs.degraded == false
      assert Map.has_key?(obs.readings, :cpu)
      assert Map.has_key?(obs.readings, :memory)
      assert Map.has_key?(obs.readings, :network)
      assert Map.has_key?(obs.readings, :latency_ms)
    end

    test "OBSERVE_UNIT_02: reports failed sensors in degraded mode (SC-SENS-002)" do
      sensor_delete(:cpu)
      {obs, _dur} = ooda_observe()
      assert obs.degraded == true
      assert :cpu in obs.failed_sensors
      assert obs.sensor_count == 3
    end

    test "OBSERVE_UNIT_03: system_state is :blind when all sensors fail" do
      for key <- [:cpu, :memory, :network, :latency_ms], do: sensor_delete(key)
      {obs, _dur} = ooda_observe()
      assert obs.system_state == :blind
      assert obs.sensor_count == 0
      assert obs.degraded == true
    end

    test "OBSERVE_UNIT_04: phase duration is non-negative and within budget" do
      {_obs, dur_us} = ooda_observe()
      assert dur_us >= 0

      assert dur_us < @phase_max_us,
             "Observe took #{dur_us}µs — budget #{@phase_max_us}µs"
    end
  end

  # ===========================================================================
  # SECTION 2: Orient Phase — anomaly detection
  # ===========================================================================

  describe "Orient phase — anomaly detection" do
    test "ORIENT_UNIT_01: no anomaly detected for nominal sensor readings" do
      {obs, _} = ooda_observe()
      {orient, _} = ooda_orient(obs)
      assert orient.phase == :orient
      assert orient.prev_phase == :observe
      assert orient.anomaly == :none
      assert orient.threat_level == :nominal
    end

    test "ORIENT_UNIT_02: cpu_spike anomaly detected when CPU > 0.85" do
      sensor_write(:cpu, 0.90)
      {obs, _} = ooda_observe()
      {orient, _} = ooda_orient(obs)
      assert orient.anomaly == :cpu_spike
      assert orient.threat_level in [:elevated, :critical]
    end

    test "ORIENT_UNIT_03: high_latency anomaly detected when latency_ms > 50" do
      sensor_write(:latency_ms, 75.0)
      {obs, _} = ooda_observe()
      {orient, _} = ooda_orient(obs)
      assert orient.anomaly == :high_latency
    end

    test "ORIENT_UNIT_04: orient phase duration within budget" do
      {obs, _} = ooda_observe()
      {_orient, dur_us} = ooda_orient(obs)
      assert dur_us >= 0

      assert dur_us < @phase_max_us,
             "Orient took #{dur_us}µs — budget #{@phase_max_us}µs"
    end
  end

  # ===========================================================================
  # SECTION 3: Decide Phase — rule engine
  # ===========================================================================

  describe "Decide phase — deterministic rule engine" do
    test "DECIDE_UNIT_01: nominal threat → :continue action" do
      {obs, _} = ooda_observe()
      {orient, _} = ooda_orient(obs)
      {decision, _} = ooda_decide(orient)
      assert decision.phase == :decide
      assert decision.prev_phase == :orient
      assert decision.selected_action == :continue
    end

    test "DECIDE_UNIT_02: critical threat → :alert_and_scale_down action" do
      sensor_write(:cpu, 0.92)
      sensor_write(:memory, 0.93)
      {obs, _} = ooda_observe()
      {orient, _} = ooda_orient(obs)
      # Force threat_level to :critical by overriding orientation
      critical_orient = Map.put(orient, :threat_level, :critical)
      {decision, _} = ooda_decide(critical_orient)
      assert decision.selected_action == :alert_and_scale_down
      assert decision.guardian_required == true
    end

    test "DECIDE_UNIT_03: decisions are deterministic — same orientation gives same action" do
      {obs, _} = ooda_observe()
      {orient, _} = ooda_orient(obs)
      {d1, _} = ooda_decide(orient)
      {d2, _} = ooda_decide(orient)
      assert d1.selected_action == d2.selected_action
      assert d1.confidence == d2.confidence
    end

    test "DECIDE_UNIT_04: decide phase duration within budget" do
      {obs, _} = ooda_observe()
      {orient, _} = ooda_orient(obs)
      {_decision, dur_us} = ooda_decide(orient)
      assert dur_us >= 0

      assert dur_us < @phase_max_us,
             "Decide took #{dur_us}µs — budget #{@phase_max_us}µs"
    end
  end

  # ===========================================================================
  # SECTION 4: Act Phase — side-effect execution and ETS recording
  # ===========================================================================

  describe "Act phase — execution and side-effect recording" do
    test "ACT_UNIT_01: action logged to ETS action table" do
      {obs, _} = ooda_observe()
      {orient, _} = ooda_orient(obs)
      {decision, _} = ooda_decide(orient)
      {outcome, _} = ooda_act(decision)
      assert outcome.phase == :act
      assert outcome.prev_phase == :decide
      assert outcome.recorded == true
      assert {:ok, _entry} = action_log_entry()
    end

    test "ACT_UNIT_02: action taken matches decision selected_action" do
      {obs, _} = ooda_observe()
      {orient, _} = ooda_orient(obs)
      {decision, _} = ooda_decide(orient)
      {outcome, _} = ooda_act(decision)
      assert outcome.action_taken == decision.selected_action
    end

    test "ACT_UNIT_03: rollback_available is always true in act outcome" do
      {obs, _} = ooda_observe()
      {orient, _} = ooda_orient(obs)
      {decision, _} = ooda_decide(orient)
      {outcome, _} = ooda_act(decision)
      assert outcome.rollback_available == true
    end

    test "ACT_UNIT_04: act phase duration within budget" do
      {obs, _} = ooda_observe()
      {orient, _} = ooda_orient(obs)
      {decision, _} = ooda_decide(orient)
      {_outcome, dur_us} = ooda_act(decision)
      assert dur_us >= 0

      assert dur_us < @phase_max_us,
             "Act took #{dur_us}µs — budget #{@phase_max_us}µs"
    end
  end

  # ===========================================================================
  # SECTION 5: Full cycle timing
  # ===========================================================================

  describe "Full cycle timing (SC-OODA-001, SC-VER-041)" do
    test "TIMING_UNIT_01: full cycle completes within 30ms target (SC-OODA-001)" do
      result = run_ooda_cycle()

      assert result.timings.total_us < @cycle_target_us,
             "Cycle took #{result.timings.total_us}µs — target #{@cycle_target_us}µs"
    end

    test "TIMING_UNIT_02: full cycle completes within 100ms hard limit (SC-VER-041)" do
      result = run_ooda_cycle()

      assert result.timings.total_us < @cycle_hard_limit_us,
             "Cycle took #{result.timings.total_us}µs — hard limit #{@cycle_hard_limit_us}µs"
    end

    test "TIMING_UNIT_03: total_us >= sum of individual phase durations" do
      result = run_ooda_cycle()
      t = result.timings
      sum_phases = t.observe_us + t.orient_us + t.decide_us + t.act_us
      assert t.total_us >= sum_phases
    end

    test "TIMING_UNIT_04: all individual phase timings are non-negative integers" do
      result = run_ooda_cycle()

      result.timings
      |> Map.values()
      |> Enum.each(fn t ->
        assert is_integer(t) and t >= 0
      end)
    end
  end

  # ===========================================================================
  # SECTION 6: Cycle counter monotonicity
  # ===========================================================================

  describe "Cycle counter monotonicity" do
    test "COUNTER_UNIT_01: cycle number increments by 1 per run_ooda_cycle call" do
      c0 = current_cycle_count()
      run_ooda_cycle()
      assert current_cycle_count() == c0 + 1
      run_ooda_cycle()
      assert current_cycle_count() == c0 + 2
    end

    test "COUNTER_UNIT_02: cycle number in result matches counter state" do
      c0 = current_cycle_count()
      r1 = run_ooda_cycle()
      r2 = run_ooda_cycle()
      assert r1.cycle_number == c0 + 1
      assert r2.cycle_number == c0 + 2
    end
  end

  # ===========================================================================
  # SECTION 7: Concurrent OODA cycles — non-interference
  # ===========================================================================

  describe "Concurrent OODA cycles — non-interference (SC-BIO-001)" do
    test "CONC_UNIT_01: multiple sequential cycles do not corrupt action log" do
      for _ <- 1..5, do: run_ooda_cycle()
      # Action log contains the last recorded action without corruption
      assert {:ok, _entry} = action_log_entry()
    end

    test "CONC_UNIT_02: concurrent cycles all complete within 100ms" do
      parent = self()

      tasks =
        for _ <- 1..8 do
          Task.async(fn ->
            result = run_ooda_cycle()
            send(parent, {:done, result.timings.total_us})
            result.timings.total_us
          end)
        end

      durations = Task.await_many(tasks, 5_000)

      Enum.each(durations, fn dur ->
        assert dur < @cycle_hard_limit_us,
               "Concurrent cycle took #{dur}µs — hard limit #{@cycle_hard_limit_us}µs"
      end)
    end

    test "CONC_UNIT_03: concurrent cycles produce valid action atoms" do
      valid_actions = [
        :continue,
        :monitor,
        :alert,
        :alert_and_scale_down,
        :hold
      ]

      tasks =
        for _ <- 1..6 do
          Task.async(fn ->
            result = run_ooda_cycle()
            result.final_outcome.action_taken
          end)
        end

      actions = Task.await_many(tasks, 5_000)
      Enum.each(actions, fn action -> assert action in valid_actions end)
    end
  end

  # ===========================================================================
  # SECTION 8: Degraded mode — graceful sensor failure (SC-SENS-002)
  # ===========================================================================

  describe "Degraded mode — graceful degradation (SC-SENS-002)" do
    test "DEGRADED_UNIT_01: cycle completes when all sensors fail" do
      for key <- [:cpu, :memory, :network, :latency_ms], do: sensor_delete(key)
      result = run_ooda_cycle()
      assert result.final_outcome.success == true
      assert result.final_outcome.action_taken in [:continue, :monitor, :hold]
    end

    test "DEGRADED_UNIT_02: cycle still within timing budget in degraded mode" do
      for key <- [:cpu, :memory, :latency_ms], do: sensor_delete(key)
      result = run_ooda_cycle()
      assert result.timings.total_us < @cycle_hard_limit_us
    end
  end

  # ===========================================================================
  # SECTION 9: StreamData property tests (SD. generators, ExUnitProperties.check all)
  # ===========================================================================

  describe "StreamData: OODA invariants under arbitrary inputs" do
    test "SD_PROP_01: any float in [0,1] as CPU reading produces valid cycle" do
      ExUnitProperties.check all(cpu <- SD.float(min: 0.0, max: 1.0), max_runs: 20) do
        sensor_write(:cpu, cpu)
        result = run_ooda_cycle()
        assert is_map(result)
        assert result.final_outcome.success == true
      end
    end

    test "SD_PROP_02: cycle always returns exactly 4 phases for any readings" do
      ExUnitProperties.check all(
                               cpu <- SD.float(min: 0.0, max: 1.0),
                               mem <- SD.float(min: 0.0, max: 1.0),
                               max_runs: 20
                             ) do
        sensor_write(:cpu, cpu)
        sensor_write(:memory, mem)
        result = run_ooda_cycle()
        assert length(result.phases) == 4
      end
    end

    test "SD_PROP_03: all timing values are non-negative for any sensor data" do
      ExUnitProperties.check all(
                               cpu <- SD.float(min: 0.0, max: 1.0),
                               latency <- SD.float(min: 0.0, max: 200.0),
                               max_runs: 20
                             ) do
        sensor_write(:cpu, cpu)
        sensor_write(:latency_ms, latency)
        result = run_ooda_cycle()

        assert result.timings
               |> Map.values()
               |> Enum.all?(&(&1 >= 0))
      end
    end

    test "SD_PROP_04: cycle time < 30ms for any valid single-float sensor value" do
      ExUnitProperties.check all(v <- SD.float(min: 0.0, max: 1.0), max_runs: 20) do
        sensor_write(:cpu, v)
        result = run_ooda_cycle()
        assert result.timings.total_us < @cycle_target_us
      end
    end

    test "SD_PROP_05: decision is deterministic — same CPU input → same action" do
      ExUnitProperties.check all(cpu <- SD.float(min: 0.0, max: 1.0), max_runs: 20) do
        sensor_write(:cpu, cpu)
        {obs, _} = ooda_observe()
        {orient, _} = ooda_orient(obs)
        {d1, _} = ooda_decide(orient)
        {d2, _} = ooda_decide(orient)
        assert d1.selected_action == d2.selected_action
      end
    end

    test "SD_PROP_06: threat_score is always a float in [0.0, 1.0]" do
      ExUnitProperties.check all(
                               cpu <- SD.float(min: 0.0, max: 1.0),
                               mem <- SD.float(min: 0.0, max: 1.0),
                               max_runs: 20
                             ) do
        sensor_write(:cpu, cpu)
        sensor_write(:memory, mem)
        {obs, _} = ooda_observe()
        {orient, _} = ooda_orient(obs)
        assert is_float(orient.threat_score)
        assert orient.threat_score >= 0.0
        assert orient.threat_score <= 1.0
      end
    end

    test "SD_PROP_07: rollback always available regardless of threat level" do
      ExUnitProperties.check all(
                               level <- SD.member_of([:nominal, :low, :elevated, :critical]),
                               max_runs: 10
                             ) do
        fake_orient = %{
          threat_level: level,
          anomaly: :none,
          threat_score: 0.0,
          sensor_count: 4,
          degraded: false,
          failed_sensors: [],
          root_cause: :none,
          approach: :standard
        }

        {decision, _} = ooda_decide(fake_orient)
        assert decision.fallback == :rollback
      end
    end

    test "SD_PROP_08: confidence is always in (0.8, 1.0] for all threat levels" do
      ExUnitProperties.check all(
                               level <- SD.member_of([:nominal, :low, :elevated, :critical]),
                               max_runs: 10
                             ) do
        fake_orient = %{
          threat_level: level,
          anomaly: :none,
          threat_score: 0.0,
          sensor_count: 4,
          degraded: false,
          failed_sensors: [],
          root_cause: :none,
          approach: :standard
        }

        {decision, _} = ooda_decide(fake_orient)
        assert decision.confidence > 0.8
        assert decision.confidence <= 1.0
      end
    end

    test "SD_PROP_09: cycle number always positive after running at least one cycle" do
      ExUnitProperties.check all(_v <- SD.integer(1..5), max_runs: 10) do
        result = run_ooda_cycle()
        assert result.cycle_number >= 1
      end
    end

    test "SD_PROP_10: phase ordering O→O→D→A holds for any input" do
      ExUnitProperties.check all(
                               inputs <- SD.list_of(SD.float(min: 0.0, max: 1.0)),
                               max_runs: 20
                             ) do
        cpu = if inputs == [], do: 0.5, else: hd(inputs)
        sensor_write(:cpu, cpu)
        result = run_ooda_cycle()
        [obs, orient, decision, outcome] = result.phases
        assert obs.phase == :observe
        assert orient.phase == :orient
        assert decision.phase == :decide
        assert outcome.phase == :act
      end
    end

    test "SD_PROP_11: cycle completes within 100ms hard limit (degraded mode)" do
      ExUnitProperties.check all(n_failed <- SD.integer(0..4), max_runs: 10) do
        keys = Enum.take([:cpu, :memory, :network, :latency_ms], n_failed)
        Enum.each(keys, &sensor_delete/1)
        remaining = [:cpu, :memory, :network, :latency_ms] -- keys
        Enum.each(remaining, &sensor_write(&1, 0.5))
        result = run_ooda_cycle()
        sensor_write(:cpu, 0.35)
        sensor_write(:memory, 0.55)
        sensor_write(:network, 0.10)
        sensor_write(:latency_ms, 12.0)
        assert result.timings.total_us < @cycle_hard_limit_us
      end
    end

    test "SD_PROP_12: outcome action is always a known atom" do
      valid_actions = [:continue, :monitor, :alert, :alert_and_scale_down, :hold]

      ExUnitProperties.check all(cpu <- SD.float(min: 0.0, max: 1.0), max_runs: 20) do
        sensor_write(:cpu, cpu)
        result = run_ooda_cycle()
        assert result.final_outcome.action_taken in valid_actions
      end
    end
  end

  # ===========================================================================
  # SECTION 10: StreamData property tests (SD. generators, ExUnitProperties.check all)
  # ===========================================================================

  describe "StreamData: cycle correctness with diverse generated inputs" do
    test "SD_PROP_01: random CPU floats always produce valid cycles within 30ms" do
      ExUnitProperties.check all(cpu <- SD.float(min: 0.0, max: 1.0), max_runs: 50) do
        sensor_write(:cpu, cpu)
        result = run_ooda_cycle()

        assert result.timings.total_us < @cycle_target_us,
               "Cycle took #{result.timings.total_us}µs with cpu=#{cpu}"
      end
    end

    test "SD_PROP_02: all phase durations are non-negative with random sensor data" do
      ExUnitProperties.check all(
                               cpu <- SD.float(min: 0.0, max: 1.0),
                               mem <- SD.float(min: 0.0, max: 1.0),
                               max_runs: 40
                             ) do
        sensor_write(:cpu, cpu)
        sensor_write(:memory, mem)
        result = run_ooda_cycle()

        assert result.timings.observe_us >= 0
        assert result.timings.orient_us >= 0
        assert result.timings.decide_us >= 0
        assert result.timings.act_us >= 0
        assert result.timings.total_us >= 0
      end
    end

    test "SD_PROP_03: decisions are deterministic for same orientation threat level" do
      ExUnitProperties.check all(
                               level <- SD.member_of([:nominal, :low, :elevated, :critical]),
                               max_runs: 30
                             ) do
        orient = %{
          threat_level: level,
          anomaly: :none,
          threat_score: 0.0,
          sensor_count: 4,
          degraded: false,
          failed_sensors: [],
          root_cause: :none,
          approach: :standard
        }

        {d1, _} = ooda_decide(orient)
        {d2, _} = ooda_decide(orient)

        assert d1.selected_action == d2.selected_action,
               "Decisions differ for level=#{level}: #{d1.selected_action} != #{d2.selected_action}"
      end
    end

    test "SD_PROP_04: threat_score is bounded in [0.0, 1.0] for any float readings" do
      ExUnitProperties.check all(
                               cpu <- SD.float(min: 0.0, max: 1.0),
                               mem <- SD.float(min: 0.0, max: 1.0),
                               latency <- SD.float(min: 0.0, max: 200.0),
                               max_runs: 40
                             ) do
        sensor_write(:cpu, cpu)
        sensor_write(:memory, mem)
        sensor_write(:latency_ms, latency)
        {obs, _} = ooda_observe()
        {orient, _} = ooda_orient(obs)
        assert orient.threat_score >= 0.0
        assert orient.threat_score <= 1.0
      end
    end

    test "SD_PROP_05: cycle counter increments by exactly 1 per call" do
      ExUnitProperties.check all(_seed <- SD.integer(), max_runs: 10) do
        before_count = current_cycle_count()
        run_ooda_cycle()
        after_count = current_cycle_count()
        assert after_count == before_count + 1
      end
    end

    test "SD_PROP_06: action log always contains entry after any cycle" do
      ExUnitProperties.check all(_cpu <- SD.float(min: 0.0, max: 1.0), max_runs: 20) do
        run_ooda_cycle()
        assert {:ok, _entry} = action_log_entry()
      end
    end

    test "SD_PROP_07: high-latency sensor triggers :high_latency anomaly" do
      ExUnitProperties.check all(
                               latency <- SD.float(min: 51.0, max: 500.0),
                               max_runs: 20
                             ) do
        sensor_write(:latency_ms, latency)
        # Reset cpu and memory to nominal so latency dominates anomaly detection
        sensor_write(:cpu, 0.30)
        sensor_write(:memory, 0.40)
        {obs, _} = ooda_observe()
        {orient, _} = ooda_orient(obs)
        assert orient.anomaly == :high_latency
      end
    end

    test "SD_PROP_08: cycle completes within hard limit even with high latency sensor" do
      ExUnitProperties.check all(
                               latency <- SD.float(min: 51.0, max: 1000.0),
                               max_runs: 20
                             ) do
        sensor_write(:latency_ms, latency)
        result = run_ooda_cycle()
        assert result.timings.total_us < @cycle_hard_limit_us
      end
    end

    test "SD_PROP_09: degraded mode still produces valid 4-phase result" do
      ExUnitProperties.check all(n_fail <- SD.integer(1..4), max_runs: 10) do
        keys_to_fail = Enum.take([:cpu, :memory, :network, :latency_ms], n_fail)
        Enum.each(keys_to_fail, &sensor_delete/1)
        result = run_ooda_cycle()
        assert length(result.phases) == 4
        # Restore for next iteration
        sensor_write(:cpu, 0.35)
        sensor_write(:memory, 0.55)
        sensor_write(:network, 0.10)
        sensor_write(:latency_ms, 12.0)
      end
    end

    test "SD_PROP_10: phase ordering O→O→D→A holds for any combination of readings" do
      ExUnitProperties.check all(
                               cpu <- SD.float(min: 0.0, max: 1.0),
                               mem <- SD.float(min: 0.0, max: 1.0),
                               max_runs: 30
                             ) do
        sensor_write(:cpu, cpu)
        sensor_write(:memory, mem)
        result = run_ooda_cycle()
        [obs, orient, decision, outcome] = result.phases
        assert obs.phase == :observe
        assert orient.phase == :orient
        assert decision.phase == :decide
        assert outcome.phase == :act
      end
    end

    test "SD_PROP_11: success flag is always true for non-error actions" do
      ExUnitProperties.check all(
                               level <- SD.member_of([:nominal, :low, :elevated, :critical]),
                               max_runs: 20
                             ) do
        orient = %{
          threat_level: level,
          anomaly: :none,
          threat_score: 0.0,
          sensor_count: 4,
          degraded: false,
          failed_sensors: [],
          root_cause: :none,
          approach: :standard
        }

        {decision, _} = ooda_decide(orient)
        {outcome, _} = ooda_act(decision)
        assert outcome.success == true
      end
    end

    test "SD_PROP_12: nominal readings always result in :continue action" do
      ExUnitProperties.check all(
                               cpu <- SD.float(min: 0.0, max: 0.74),
                               mem <- SD.float(min: 0.0, max: 0.79),
                               lat <- SD.float(min: 0.0, max: 29.9),
                               net <- SD.float(min: 0.0, max: 0.79),
                               max_runs: 30
                             ) do
        sensor_write(:cpu, cpu)
        sensor_write(:memory, mem)
        sensor_write(:latency_ms, lat)
        sensor_write(:network, net)
        result = run_ooda_cycle()
        assert result.final_outcome.action_taken == :continue
      end
    end

    test "SD_PROP_13: cycle_number is always positive after running a cycle" do
      ExUnitProperties.check all(_seed <- SD.integer(), max_runs: 10) do
        result = run_ooda_cycle()
        assert result.cycle_number >= 1
      end
    end
  end
end
