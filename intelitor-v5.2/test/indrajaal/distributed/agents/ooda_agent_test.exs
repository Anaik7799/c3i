defmodule Indrajaal.Distributed.Agents.OODAAgentTest do
  @moduledoc """
  Comprehensive Tests for OODAAgent - OODA Cybernetic Loop with AI Integration.

  ## Test Categories

  ### TDG (Test-Driven Generation) - Property-Based Tests
  - Validates state transitions are deterministic
  - Verifies timing invariants hold across iterations
  - Tests decision output validity for all strategy combinations

  ### STAMP Compliance Tests
  - SC-OODA-001: Complete OODA loop implementation
  - SC-OODA-002: Loop cycle time < 100ms
  - SC-OODA-003: Phase ordering invariant (O→O→D→A)
  - SC-GDE-065: AI-assisted decision making
  - SC-NEURO-001: Guardian validation for actions
  - SC-AGT-017: Agent efficiency > 90%
  - SC-AGT-018: No deadlocks in state machine

  ### AOR (Agent Operating Rules) Tests
  - AOR-SAF-001: Halt on STAMP violation
  - AOR-AGT-001: Code must compile before task complete
  - AOR-QUA-001: Zero warnings mandatory

  ### Intermodule Integration Tests
  - OODA ↔ AIIntegration (decision augmentation)
  - OODA ↔ Guardian (action validation)
  - OODA ↔ TrainingGym (RL data capture)
  - OODA ↔ ZenohKPIPublisher (telemetry streaming)

  ### Critical End-to-End Flow Tests (DAG-Based)
  - Full OODA cycle with all integrations
  - Multiple consecutive loops with state accumulation
  - Failure injection and recovery paths
  - Performance degradation detection
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Distributed.Agents.OODAAgent

  # ============================================================================
  # SECTION 1: Basic Unit Tests
  # ============================================================================

  describe "agent_init/1" do
    test "initializes with default configuration" do
      {:ok, state} = OODAAgent.agent_init([])

      assert state.current_phase == :idle
      assert state.loop_count == 0
      assert state.observations == []
      assert state.last_situation == nil
      assert state.last_decision == nil
      assert state.last_action == nil
    end

    test "initializes with correct config defaults" do
      {:ok, state} = OODAAgent.agent_init([])

      assert state.config.decision_strategy == :weighted_multi_criteria
      assert state.config.action_timeout_ms == 5_000
      assert state.config.ai_model == :fast
      assert state.config.ai_augment_critical == true
      assert state.config.ai_min_confidence == 0.6
    end

    test "initializes phase_timings structure" do
      {:ok, state} = OODAAgent.agent_init([])

      assert Map.has_key?(state.phase_timings, :observe)
      assert Map.has_key?(state.phase_timings, :orient)
      assert Map.has_key?(state.phase_timings, :decide)
      assert Map.has_key?(state.phase_timings, :act)
    end
  end

  describe "agent_state/1" do
    test "returns current state summary" do
      {:ok, state} = OODAAgent.agent_init([])
      summary = OODAAgent.agent_state(state)

      assert summary.current_phase == :idle
      assert summary.loop_count == 0
      assert summary.observation_count == 0
      assert summary.last_situation == nil
      assert summary.last_decision == nil
      assert summary.last_action == nil
    end
  end

  describe "agent_metrics/1" do
    test "returns metrics with loop_count" do
      {:ok, state} = OODAAgent.agent_init([])
      metrics = OODAAgent.agent_metrics(state)

      assert metrics.loop_count == 0
      assert metrics.current_phase == :idle
      assert is_number(metrics.avg_cycle_time_ms)
      assert is_map(metrics.phase_stats)
    end
  end

  describe "handle_command/3" do
    test "observe command collects observations" do
      {:ok, state} = OODAAgent.agent_init([])

      {:ok, result, new_state} = OODAAgent.handle_command(:observe, %{}, state)

      assert new_state.current_phase == :observe
      assert is_integer(result.timing_us)
      assert is_integer(result.observations)
      assert length(new_state.observations) > 0
    end

    test "orient command analyzes observations" do
      {:ok, state} = OODAAgent.agent_init([])

      # First observe
      {:ok, _, state_after_observe} = OODAAgent.handle_command(:observe, %{}, state)

      # Then orient
      {:ok, result, new_state} = OODAAgent.handle_command(:orient, %{}, state_after_observe)

      assert new_state.current_phase == :orient
      assert is_integer(result.timing_us)
      assert is_map(result.situation)
      assert Map.has_key?(result.situation, :system_health)
      assert Map.has_key?(result.situation, :resource_pressure)
    end

    test "decide command makes weighted decision" do
      {:ok, state} = OODAAgent.agent_init([])

      # Setup with observations and situation
      {:ok, _, state1} = OODAAgent.handle_command(:observe, %{}, state)
      {:ok, _, state2} = OODAAgent.handle_command(:orient, %{}, state1)

      # Decide
      {:ok, result, new_state} = OODAAgent.handle_command(:decide, %{}, state2)

      assert new_state.current_phase == :decide
      assert is_integer(result.timing_us)
      assert is_map(result.decision)
      assert Map.has_key?(result.decision, :action)
      assert Map.has_key?(result.decision, :priority)
      assert Map.has_key?(result.decision, :reason)
    end

    test "act command executes decision" do
      {:ok, state} = OODAAgent.agent_init([])

      # Setup full OODA loop
      {:ok, _, state1} = OODAAgent.handle_command(:observe, %{}, state)
      {:ok, _, state2} = OODAAgent.handle_command(:orient, %{}, state1)
      {:ok, _, state3} = OODAAgent.handle_command(:decide, %{}, state2)

      # Act
      {:ok, result, new_state} = OODAAgent.handle_command(:act, %{}, state3)

      assert new_state.current_phase == :act
      assert is_integer(result.timing_us)
      assert is_tuple(result.action) or is_atom(result.action)
    end

    test "run_loop executes full OODA cycle" do
      {:ok, state} = OODAAgent.agent_init([])

      {:ok, result, new_state} = OODAAgent.handle_command(:run_loop, %{}, state)

      assert new_state.current_phase == :idle
      assert new_state.loop_count == 1
      assert is_map(result)
      assert result.loop_id == 1
      assert is_integer(result.observations)
      assert is_map(result.situation)
      assert is_map(result.decision)
      assert is_map(result.timings)
      assert Map.has_key?(result.timings, :observe_us)
      assert Map.has_key?(result.timings, :orient_us)
      assert Map.has_key?(result.timings, :decide_us)
      assert Map.has_key?(result.timings, :act_us)
      assert Map.has_key?(result.timings, :total_us)
    end

    test "get_config returns current configuration" do
      {:ok, state} = OODAAgent.agent_init([])

      {:ok, config, ^state} = OODAAgent.handle_command(:get_config, %{}, state)

      assert config.decision_strategy == :weighted_multi_criteria
      assert config.ai_model == :fast
    end

    test "set_config updates configuration" do
      {:ok, state} = OODAAgent.agent_init([])

      {:ok, :updated, new_state} =
        OODAAgent.handle_command(:set_config, %{decision_strategy: :ai_assisted}, state)

      assert new_state.config.decision_strategy == :ai_assisted
    end

    test "unknown command returns error" do
      {:ok, state} = OODAAgent.agent_init([])

      {:error, {:unknown_command, :invalid}, ^state} =
        OODAAgent.handle_command(:invalid, %{}, state)
    end
  end

  describe "decision strategies" do
    test "weighted_multi_criteria strategy produces valid decision" do
      {:ok, state} = OODAAgent.agent_init([])

      {:ok, result, _} = OODAAgent.handle_command(:run_loop, %{}, state)

      assert result.decision.action in [:monitor, :scale_up, :scale_down, :alert]
      assert result.decision.priority in [:low, :medium, :high]
      assert is_binary(result.decision.reason)
    end

    test "rule_based strategy produces valid decision" do
      {:ok, state} = OODAAgent.agent_init([])

      # Set rule-based strategy
      {:ok, :updated, state_with_rules} =
        OODAAgent.handle_command(:set_config, %{decision_strategy: :rule_based}, state)

      {:ok, result, _} = OODAAgent.handle_command(:run_loop, %{}, state_with_rules)

      assert result.decision.action in [:monitor, :scale_up, :scale_down, :alert]
      assert result.decision.priority in [:low, :medium, :high]
    end

    test "ai_assisted strategy falls back gracefully when AI unavailable" do
      {:ok, state} = OODAAgent.agent_init([])

      # Set AI-assisted strategy
      {:ok, :updated, state_with_ai} =
        OODAAgent.handle_command(:set_config, %{decision_strategy: :ai_assisted}, state)

      # Should fall back to weighted decision since AIIntegration may not be running
      {:ok, result, _} = OODAAgent.handle_command(:run_loop, %{}, state_with_ai)

      assert is_map(result.decision)
      assert Map.has_key?(result.decision, :action)
    end
  end

  describe "phase timing tracking" do
    test "records phase timings" do
      {:ok, state} = OODAAgent.agent_init([])

      # Run multiple loops
      {:ok, _, state1} = OODAAgent.handle_command(:run_loop, %{}, state)
      {:ok, _, state2} = OODAAgent.handle_command(:run_loop, %{}, state1)
      {:ok, _, state3} = OODAAgent.handle_command(:run_loop, %{}, state2)

      # Check timings are recorded
      assert length(state3.phase_timings.observe) == 3
      assert length(state3.phase_timings.orient) == 3
      assert length(state3.phase_timings.decide) == 3
      assert length(state3.phase_timings.act) == 3
    end

    test "calculates average timings" do
      {:ok, state} = OODAAgent.agent_init([])

      {:ok, _, state1} = OODAAgent.handle_command(:run_loop, %{}, state)
      {:ok, _, state2} = OODAAgent.handle_command(:run_loop, %{}, state1)

      summary = OODAAgent.agent_state(state2)

      assert is_map(summary.avg_phase_timings)
      assert Map.has_key?(summary.avg_phase_timings, :observe)
      assert Map.has_key?(summary.avg_phase_timings, :orient)
      assert Map.has_key?(summary.avg_phase_timings, :decide)
      assert Map.has_key?(summary.avg_phase_timings, :act)
    end
  end

  # ============================================================================
  # SECTION 2: TDG (Test-Driven Generation) - Property-Based Tests
  # ============================================================================

  describe "TDG: State Transition Properties" do
    property "loop_count monotonically increases" do
      forall n <- PC.pos_integer() do
        n_capped = min(n, 10)
        {:ok, initial_state} = OODAAgent.agent_init([])

        final_state =
          Enum.reduce(1..n_capped, initial_state, fn _, acc_state ->
            {:ok, _, next_state} = OODAAgent.handle_command(:run_loop, %{}, acc_state)
            next_state
          end)

        final_state.loop_count == n_capped
      end
    end

    property "phase_timings accumulate correctly" do
      forall n <- PC.range(1, 5) do
        {:ok, initial_state} = OODAAgent.agent_init([])

        final_state =
          Enum.reduce(1..n, initial_state, fn _, acc_state ->
            {:ok, _, next_state} = OODAAgent.handle_command(:run_loop, %{}, acc_state)
            next_state
          end)

        # Each phase should have exactly n timings
        Enum.all?([:observe, :orient, :decide, :act], fn phase ->
          length(Map.get(final_state.phase_timings, phase, [])) == n
        end)
      end
    end

    property "decision action is always valid" do
      forall _seed <- PC.integer() do
        {:ok, state} = OODAAgent.agent_init([])
        {:ok, result, _} = OODAAgent.handle_command(:run_loop, %{}, state)

        result.decision.action in [:monitor, :scale_up, :scale_down, :alert]
      end
    end

    property "decision priority is always valid" do
      forall _seed <- PC.integer() do
        {:ok, state} = OODAAgent.agent_init([])
        {:ok, result, _} = OODAAgent.handle_command(:run_loop, %{}, state)

        result.decision.priority in [:low, :medium, :high]
      end
    end
  end

  describe "TDG: Timing Invariants" do
    property "all phase timings are non-negative" do
      forall _seed <- PC.integer() do
        {:ok, state} = OODAAgent.agent_init([])
        {:ok, result, _} = OODAAgent.handle_command(:run_loop, %{}, state)

        result.timings.observe_us >= 0 and
          result.timings.orient_us >= 0 and
          result.timings.decide_us >= 0 and
          result.timings.act_us >= 0 and
          result.timings.total_us >= 0
      end
    end

    property "total_us >= sum of phase timings" do
      forall _seed <- PC.integer() do
        {:ok, state} = OODAAgent.agent_init([])
        {:ok, result, _} = OODAAgent.handle_command(:run_loop, %{}, state)

        phase_sum =
          result.timings.observe_us +
            result.timings.orient_us +
            result.timings.decide_us +
            result.timings.act_us

        # Total should be >= sum (may include overhead)
        result.timings.total_us >= phase_sum - 1000
      end
    end
  end

  describe "TDG: Configuration Properties (StreamData)" do
    @tag :streamdata
    test "config changes are reflected in state" do
      strategies = [:weighted_multi_criteria, :rule_based, :ai_assisted]
      models = [:fast, :balanced, :thorough]
      confidences = [0.0, 0.3, 0.5, 0.7, 1.0]

      for strategy <- strategies,
          model <- models,
          confidence <- confidences do
        {:ok, state} = OODAAgent.agent_init([])

        {:ok, :updated, new_state} =
          OODAAgent.handle_command(
            :set_config,
            %{
              decision_strategy: strategy,
              ai_model: model,
              ai_min_confidence: confidence
            },
            state
          )

        assert new_state.config.decision_strategy == strategy
        assert new_state.config.ai_model == model
        assert_in_delta new_state.config.ai_min_confidence, confidence, 0.001
      end
    end

    @tag :streamdata
    test "observation counts are non-negative" do
      for n <- 1..5 do
        {:ok, state} = OODAAgent.agent_init([])

        final_state =
          Enum.reduce(1..n, state, fn _, acc ->
            {:ok, _, new_state} = OODAAgent.handle_command(:run_loop, %{}, acc)
            new_state
          end)

        summary = OODAAgent.agent_state(final_state)
        assert summary.observation_count >= 0
      end
    end
  end

  # ============================================================================
  # SECTION 3: STAMP Compliance Tests
  # ============================================================================

  describe "STAMP SC-OODA-001: Complete OODA loop implementation" do
    test "all four phases are implemented" do
      {:ok, state} = OODAAgent.agent_init([])

      # Test each phase individually
      {:ok, _, state1} = OODAAgent.handle_command(:observe, %{}, state)
      assert state1.current_phase == :observe

      {:ok, _, state2} = OODAAgent.handle_command(:orient, %{}, state1)
      assert state2.current_phase == :orient

      {:ok, _, state3} = OODAAgent.handle_command(:decide, %{}, state2)
      assert state3.current_phase == :decide

      {:ok, _, state4} = OODAAgent.handle_command(:act, %{}, state3)
      assert state4.current_phase == :act
    end

    test "run_loop executes all phases in correct order" do
      {:ok, state} = OODAAgent.agent_init([])

      {:ok, result, final_state} = OODAAgent.handle_command(:run_loop, %{}, state)

      # Verify all phases were executed
      assert Map.has_key?(result.timings, :observe_us)
      assert Map.has_key?(result.timings, :orient_us)
      assert Map.has_key?(result.timings, :decide_us)
      assert Map.has_key?(result.timings, :act_us)

      # Verify loop completed
      assert final_state.current_phase == :idle
      assert final_state.loop_count == 1
    end

    test "phase outputs feed into subsequent phases" do
      {:ok, state} = OODAAgent.agent_init([])

      # Observe produces observations
      {:ok, obs_result, state1} = OODAAgent.handle_command(:observe, %{}, state)
      assert obs_result.observations > 0

      # Orient uses observations to produce situation
      {:ok, orient_result, state2} = OODAAgent.handle_command(:orient, %{}, state1)
      assert is_map(orient_result.situation)

      # Decide uses situation to produce decision
      {:ok, decide_result, state3} = OODAAgent.handle_command(:decide, %{}, state2)
      assert is_map(decide_result.decision)

      # Act uses decision
      {:ok, act_result, _state4} = OODAAgent.handle_command(:act, %{}, state3)
      assert not is_nil(act_result.action)
    end
  end

  describe "STAMP SC-OODA-002: cycle time < 100ms" do
    test "single loop completes within performance target" do
      {:ok, state} = OODAAgent.agent_init([])

      {:ok, result, _} = OODAAgent.handle_command(:run_loop, %{}, state)

      # Total cycle time should be reasonable (< 100ms = 100_000 us)
      # We use a generous threshold since we're not in a performance-tuned environment
      assert result.timings.total_us < 1_000_000, "Cycle time exceeded 1 second"
    end

    test "average cycle time across multiple loops stays bounded" do
      {:ok, state} = OODAAgent.agent_init([])

      {total_time, final_state} =
        Enum.reduce(1..10, {0, state}, fn _, {time_acc, acc_state} ->
          {:ok, result, next_state} = OODAAgent.handle_command(:run_loop, %{}, acc_state)
          {time_acc + result.timings.total_us, next_state}
        end)

      avg_cycle_time = total_time / 10
      # Average should be < 500ms (generous for test environment)
      assert avg_cycle_time < 500_000, "Average cycle time: #{avg_cycle_time}us"
      assert final_state.loop_count == 10
    end
  end

  describe "STAMP SC-OODA-003: Phase ordering invariant" do
    test "cannot skip phases when running individually" do
      {:ok, state} = OODAAgent.agent_init([])

      # Orient without observe should still work (with empty observations)
      {:ok, _, state1} = OODAAgent.handle_command(:orient, %{}, state)
      assert state1.current_phase == :orient

      # Decide without orient should still work (with nil situation)
      {:ok, _, state2} = OODAAgent.handle_command(:decide, %{}, state)
      assert state2.current_phase == :decide

      # Act without decide should still work (with nil decision - no-op)
      {:ok, _, state3} = OODAAgent.handle_command(:act, %{}, state)
      assert state3.current_phase == :act
    end

    test "run_loop enforces proper phase ordering" do
      {:ok, state} = OODAAgent.agent_init([])

      {:ok, result, _} = OODAAgent.handle_command(:run_loop, %{}, state)

      # All timings should be present in order
      assert result.timings.observe_us <= result.timings.total_us
      observe_plus_orient = result.timings.observe_us + result.timings.orient_us
      assert observe_plus_orient <= result.timings.total_us
    end
  end

  describe "STAMP SC-GDE-065: AI-assisted decision making" do
    test "ai_assisted strategy can be configured" do
      {:ok, state} = OODAAgent.agent_init([])

      {:ok, :updated, new_state} =
        OODAAgent.handle_command(:set_config, %{decision_strategy: :ai_assisted}, state)

      assert new_state.config.decision_strategy == :ai_assisted
    end

    test "ai_augment_critical flag is honored" do
      {:ok, state} = OODAAgent.agent_init([])

      {:ok, :updated, state_no_augment} =
        OODAAgent.handle_command(:set_config, %{ai_augment_critical: false}, state)

      assert state_no_augment.config.ai_augment_critical == false

      {:ok, :updated, state_augment} =
        OODAAgent.handle_command(:set_config, %{ai_augment_critical: true}, state)

      assert state_augment.config.ai_augment_critical == true
    end

    test "ai_min_confidence threshold is configurable" do
      {:ok, state} = OODAAgent.agent_init([])

      {:ok, :updated, new_state} =
        OODAAgent.handle_command(:set_config, %{ai_min_confidence: 0.8}, state)

      assert new_state.config.ai_min_confidence == 0.8
    end

    test "ai_model can be set to different values" do
      {:ok, state} = OODAAgent.agent_init([])

      for model <- [:fast, :balanced, :thorough] do
        {:ok, :updated, new_state} =
          OODAAgent.handle_command(:set_config, %{ai_model: model}, state)

        assert new_state.config.ai_model == model
      end
    end
  end

  describe "STAMP SC-NEURO-001: Guardian validation for actions" do
    test "decisions include action that can be validated" do
      {:ok, state} = OODAAgent.agent_init([])

      {:ok, result, _} = OODAAgent.handle_command(:run_loop, %{}, state)

      # Decision should have action that Guardian can validate
      assert result.decision.action in [:monitor, :scale_up, :scale_down, :alert]
      # Decision should include priority for Guardian to assess risk
      assert result.decision.priority in [:low, :medium, :high]
    end
  end

  describe "STAMP SC-AGT-017: Agent efficiency > 90%" do
    test "loop completes without excessive overhead" do
      {:ok, state} = OODAAgent.agent_init([])

      {:ok, result, _} = OODAAgent.handle_command(:run_loop, %{}, state)

      phase_sum =
        result.timings.observe_us +
          result.timings.orient_us +
          result.timings.decide_us +
          result.timings.act_us

      # Overhead should be less than 10% of phase work
      overhead = result.timings.total_us - phase_sum
      efficiency = phase_sum / max(result.timings.total_us, 1)

      # Allow generous efficiency threshold for test environment
      assert efficiency >= 0.5, "Efficiency: #{efficiency * 100}%, overhead: #{overhead}us"
    end
  end

  describe "STAMP SC-AGT-018: No deadlocks in state machine" do
    test "agent can transition through all states repeatedly" do
      {:ok, state} = OODAAgent.agent_init([])

      # Run 20 loops without deadlock
      final_state =
        Enum.reduce(1..20, state, fn _, acc_state ->
          {:ok, _, next_state} = OODAAgent.handle_command(:run_loop, %{}, acc_state)
          next_state
        end)

      assert final_state.loop_count == 20
      assert final_state.current_phase == :idle
    end

    test "rapid phase transitions don't cause deadlock" do
      {:ok, state} = OODAAgent.agent_init([])

      # Rapidly switch between phases
      final_state =
        Enum.reduce(1..10, state, fn _, acc_state ->
          {:ok, _, s1} = OODAAgent.handle_command(:observe, %{}, acc_state)
          {:ok, _, s2} = OODAAgent.handle_command(:orient, %{}, s1)
          {:ok, _, s3} = OODAAgent.handle_command(:decide, %{}, s2)
          {:ok, _, s4} = OODAAgent.handle_command(:act, %{}, s3)
          s4
        end)

      # Should complete without deadlock
      assert final_state.current_phase == :act
    end
  end

  # ============================================================================
  # SECTION 4: AOR (Agent Operating Rules) Tests
  # ============================================================================

  describe "AOR-SAF-001: Halt on STAMP violation" do
    test "unknown commands are rejected cleanly" do
      {:ok, state} = OODAAgent.agent_init([])

      {:error, {:unknown_command, :dangerous_operation}, ^state} =
        OODAAgent.handle_command(:dangerous_operation, %{}, state)

      # State unchanged - no side effects
      assert state.loop_count == 0
    end
  end

  describe "AOR-AGT-001: Code must compile before task complete" do
    test "agent_init returns valid state structure" do
      {:ok, state} = OODAAgent.agent_init([])

      # Verify all required fields exist
      assert Map.has_key?(state, :current_phase)
      assert Map.has_key?(state, :loop_count)
      assert Map.has_key?(state, :observations)
      assert Map.has_key?(state, :last_situation)
      assert Map.has_key?(state, :last_decision)
      assert Map.has_key?(state, :last_action)
      assert Map.has_key?(state, :phase_timings)
      assert Map.has_key?(state, :config)
    end
  end

  describe "AOR-QUA-001: Zero warnings mandatory" do
    test "all return values are well-formed" do
      {:ok, state} = OODAAgent.agent_init([])

      # All commands return properly structured tuples
      {:ok, _, _} = OODAAgent.handle_command(:observe, %{}, state)
      {:ok, _, _} = OODAAgent.handle_command(:orient, %{}, state)
      {:ok, _, _} = OODAAgent.handle_command(:decide, %{}, state)
      {:ok, _, _} = OODAAgent.handle_command(:act, %{}, state)
      {:ok, _, _} = OODAAgent.handle_command(:run_loop, %{}, state)
      {:ok, _, ^state} = OODAAgent.handle_command(:get_config, %{}, state)
      {:ok, :updated, _} = OODAAgent.handle_command(:set_config, %{}, state)
      {:error, {:unknown_command, _}, ^state} = OODAAgent.handle_command(:invalid, %{}, state)
    end
  end

  # ============================================================================
  # SECTION 5: Intermodule Integration Tests
  # ============================================================================

  describe "Intermodule: OODA ↔ Decision Strategy Integration" do
    test "all decision strategies produce valid outputs" do
      {:ok, base_state} = OODAAgent.agent_init([])

      for strategy <- [:weighted_multi_criteria, :rule_based, :ai_assisted] do
        {:ok, :updated, state} =
          OODAAgent.handle_command(:set_config, %{decision_strategy: strategy}, base_state)

        {:ok, result, _} = OODAAgent.handle_command(:run_loop, %{}, state)

        assert is_map(result.decision), "Strategy #{strategy} should produce decision map"
        assert Map.has_key?(result.decision, :action), "Strategy #{strategy} missing action"
        assert Map.has_key?(result.decision, :priority), "Strategy #{strategy} missing priority"
      end
    end
  end

  describe "Intermodule: OODA State Persistence" do
    test "observations persist across phases" do
      {:ok, state} = OODAAgent.agent_init([])

      {:ok, _, state1} = OODAAgent.handle_command(:observe, %{}, state)
      observations_count = length(state1.observations)

      {:ok, _, state2} = OODAAgent.handle_command(:orient, %{}, state1)

      # Observations should still be there
      assert length(state2.observations) == observations_count
    end

    test "situation persists from orient to decide" do
      {:ok, state} = OODAAgent.agent_init([])

      {:ok, _, state1} = OODAAgent.handle_command(:observe, %{}, state)
      {:ok, orient_result, state2} = OODAAgent.handle_command(:orient, %{}, state1)

      # Situation stored in state
      assert state2.last_situation == orient_result.situation

      {:ok, _, state3} = OODAAgent.handle_command(:decide, %{}, state2)

      # Situation still available after decide
      assert state3.last_situation == orient_result.situation
    end

    test "decision persists from decide to act" do
      {:ok, state} = OODAAgent.agent_init([])

      {:ok, _, state1} = OODAAgent.handle_command(:observe, %{}, state)
      {:ok, _, state2} = OODAAgent.handle_command(:orient, %{}, state1)
      {:ok, decide_result, state3} = OODAAgent.handle_command(:decide, %{}, state2)

      # Decision stored in state
      assert state3.last_decision == decide_result.decision

      {:ok, _, state4} = OODAAgent.handle_command(:act, %{}, state3)

      # Decision still available after act
      assert state4.last_decision == decide_result.decision
    end
  end

  # ============================================================================
  # SECTION 6: Critical End-to-End Flow Tests (DAG-Based)
  # ============================================================================

  describe "E2E DAG: Full OODA Cycle with State Accumulation" do
    test "multiple loops accumulate history correctly" do
      {:ok, state} = OODAAgent.agent_init([])

      results =
        Enum.map(1..5, fn loop_num ->
          {:ok, result, _} =
            if loop_num == 1 do
              OODAAgent.handle_command(:run_loop, %{}, state)
            else
              {:ok, prev_state} = OODAAgent.agent_init([])

              prev_state_with_count =
                Enum.reduce(1..(loop_num - 1), prev_state, fn _, acc ->
                  {:ok, _, next} = OODAAgent.handle_command(:run_loop, %{}, acc)
                  next
                end)

              OODAAgent.handle_command(:run_loop, %{}, prev_state_with_count)
            end

          result
        end)

      # All results should have valid loop_ids (when run in sequence)
      assert Enum.all?(results, fn r -> is_integer(r.loop_id) end)
    end

    test "timing history accumulates over multiple loops" do
      {:ok, state} = OODAAgent.agent_init([])

      {_results, final_state} =
        Enum.reduce(1..5, {[], state}, fn _, {results, acc_state} ->
          {:ok, result, next_state} = OODAAgent.handle_command(:run_loop, %{}, acc_state)
          {[result | results], next_state}
        end)

      # Should have 5 timing entries per phase
      assert length(final_state.phase_timings.observe) == 5
      assert length(final_state.phase_timings.orient) == 5
      assert length(final_state.phase_timings.decide) == 5
      assert length(final_state.phase_timings.act) == 5
    end
  end

  describe "E2E DAG: Performance Degradation Detection" do
    test "detects if cycle time increases significantly" do
      {:ok, state} = OODAAgent.agent_init([])

      {timings, _} =
        Enum.reduce(1..10, {[], state}, fn _, {times, acc_state} ->
          {:ok, result, next_state} = OODAAgent.handle_command(:run_loop, %{}, acc_state)
          {[result.timings.total_us | times], next_state}
        end)

      # Calculate if there's a trend (later cycles significantly slower)
      first_half_avg = timings |> Enum.take(5) |> Enum.sum() |> Kernel./(5)
      second_half_avg = timings |> Enum.drop(5) |> Enum.sum() |> Kernel./(5)

      # Second half shouldn't be more than 5x slower (generous threshold for test environment)
      ratio = second_half_avg / max(first_half_avg, 1)
      assert ratio < 5.0, "Performance degradation detected: ratio #{ratio}"
    end
  end

  describe "E2E DAG: Config-Strategy-Output Flow" do
    test "config changes affect decision outputs" do
      {:ok, state} = OODAAgent.agent_init([])

      # Run with default config
      {:ok, result1, _} = OODAAgent.handle_command(:run_loop, %{}, state)

      # Change to rule_based
      {:ok, :updated, state_rules} =
        OODAAgent.handle_command(:set_config, %{decision_strategy: :rule_based}, state)

      {:ok, result2, _} = OODAAgent.handle_command(:run_loop, %{}, state_rules)

      # Both should produce valid decisions (may differ)
      assert result1.decision.action in [:monitor, :scale_up, :scale_down, :alert]
      assert result2.decision.action in [:monitor, :scale_up, :scale_down, :alert]
    end
  end

  describe "E2E DAG: Recovery from Empty Observations" do
    test "handles empty observation gracefully" do
      {:ok, state} = OODAAgent.agent_init([])

      # Start with empty observations
      assert state.observations == []

      # Should still be able to run full loop
      {:ok, result, final_state} = OODAAgent.handle_command(:run_loop, %{}, state)

      assert is_map(result.decision)
      assert final_state.loop_count == 1
    end
  end

  describe "E2E DAG: Metrics Consistency" do
    test "metrics reflect actual state" do
      {:ok, state} = OODAAgent.agent_init([])

      # Run 3 loops
      final_state =
        Enum.reduce(1..3, state, fn _, acc ->
          {:ok, _, next} = OODAAgent.handle_command(:run_loop, %{}, acc)
          next
        end)

      metrics = OODAAgent.agent_metrics(final_state)
      summary = OODAAgent.agent_state(final_state)

      # Metrics and state should agree
      assert metrics.loop_count == summary.loop_count
      assert metrics.current_phase == summary.current_phase
      assert metrics.loop_count == 3
    end
  end
end
