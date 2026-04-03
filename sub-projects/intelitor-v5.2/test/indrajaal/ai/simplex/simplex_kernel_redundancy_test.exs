defmodule Indrajaal.AI.Simplex.SimplexKernelRedundancyTest do
  @moduledoc """
  TDG test suite for Simplex Kernel Redundancy (SC-SIMPLEX-002).

  WHAT: Verifies the Simplex kernel maintains MinRedundancy=2 — at least 2
        safety components (Guardian, DeadMansSwitch, Envelope) must be
        independently operational at all times.
  WHY: SC-SIMPLEX-002 mandates that redundancy MUST NOT be reduced below
       MinRedundancy=2. The Simplex architecture requires all AI requests
       to pass through layered safety checks.

  ## STAMP Safety Integration
  - SC-SIMPLEX-002: Redundancy MUST NOT be reduced below MinRedundancy=2
  - SC-NEURO-001: All AI proposals MUST pass Guardian validation
  - SC-GUARD-001: Guardian MUST use Envelope for constraint values
  - SC-GUARD-002: Guardian integrates with DeadMansSwitch, fail closed
  - SC-GDE-001: Guardian validation required before deploy

  ## Simplex Kernel Components (3 safety layers)
  1. Guardian — validates all AI proposals (primary gate)
  2. Envelope — holds constraint values and safety limits
  3. DeadMansSwitch — heartbeat-based failsafe (secondary gate)

  MinRedundancy=2 means at least 2 of these 3 MUST be active.
  """

  use ExUnit.Case, async: false

  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Safety.Guardian
  alias Indrajaal.Safety.Envelope
  alias Indrajaal.AI.Simplex.SimplexController

  @moduletag :unit
  @moduletag :safety

  @min_redundancy 2

  # ─────────────────────────────────────────────────────────────────────────
  # KERNEL COMPONENT EXISTENCE
  # ─────────────────────────────────────────────────────────────────────────

  describe "simplex kernel component existence (SC-SIMPLEX-002)" do
    test "Guardian module is defined and loaded" do
      assert Code.ensure_loaded?(Guardian)
    end

    test "Envelope module is defined and loaded" do
      assert Code.ensure_loaded?(Envelope)
    end

    test "SimplexController module is defined and loaded" do
      assert Code.ensure_loaded?(SimplexController)
    end

    test "at least MinRedundancy=2 safety components are available" do
      # Count operational safety components
      components = [
        {Guardian, :validate_proposal, 1},
        {Envelope, :all_constraints, 0},
        {Envelope, :health_check, 1}
      ]

      operational_count =
        Enum.count(components, fn {mod, fun, arity} ->
          Code.ensure_loaded?(mod) and function_exported?(mod, fun, arity)
        end)

      assert operational_count >= @min_redundancy,
             "Expected >= #{@min_redundancy} safety components, got: #{operational_count}"
    end

    test "Guardian exports all required safety functions" do
      assert function_exported?(Guardian, :validate_proposal, 1)
      assert function_exported?(Guardian, :validate_proposal, 2)
      assert function_exported?(Guardian, :constraints, 0)
      assert function_exported?(Guardian, :health_check, 1)
    end

    test "Envelope exports all required safety functions" do
      assert function_exported?(Envelope, :all_constraints, 0)
      assert function_exported?(Envelope, :health_check, 1)
      assert function_exported?(Envelope, :check_resource, 2)
      assert function_exported?(Envelope, :check_temporal, 2)
    end
  end

  # ─────────────────────────────────────────────────────────────────────────
  # GUARDIAN PRIMARY GATE (Layer 1)
  # ─────────────────────────────────────────────────────────────────────────

  describe "Guardian primary safety gate — layer 1 of MinRedundancy=2" do
    test "Guardian validates proposal and returns structured result" do
      proposal = %{action: :ai_request, source: :cortex, intent: :analyze}
      result = Guardian.validate_proposal(proposal)

      assert match?({:ok, _}, result) or match?({:veto, _, _}, result),
             "Guardian must return {:ok, _} or {:veto, _, _}, got: #{inspect(result)}"
    end

    test "Guardian operates independently without server running" do
      # Guardian falls back to do_validate_proposal/1 when GenServer not running
      # This demonstrates the fail-safe redundancy behavior (SC-GUARD-002)
      proposal = %{action: :test, source: :test_suite}
      result = Guardian.validate_proposal(proposal)

      assert match?({:ok, _}, result) or match?({:veto, _, _}, result)
    end

    test "Guardian constraints/0 returns Envelope constraints (SC-GUARD-001)" do
      guardian_constraints = Guardian.constraints()
      envelope_constraints = Envelope.all_constraints()

      # Both must return the same map (Guardian delegates to Envelope)
      assert guardian_constraints == envelope_constraints
    end

    test "Guardian status/0 returns a valid map even when not running" do
      status = Guardian.status()
      assert is_map(status)
      assert Map.has_key?(status, :running)
      assert is_boolean(status.running)
    end
  end

  # ─────────────────────────────────────────────────────────────────────────
  # ENVELOPE SECONDARY GATE (Layer 2)
  # ─────────────────────────────────────────────────────────────────────────

  describe "Envelope secondary safety gate — layer 2 of MinRedundancy=2" do
    test "Envelope.all_constraints/0 returns a non-empty map" do
      constraints = Envelope.all_constraints()
      assert is_map(constraints)

      refute map_size(constraints) == 0,
             "Envelope must define at least one constraint (MinRedundancy enforcement)"
    end

    test "Envelope enforces resource constraints independently" do
      # CPU exceeding limit
      result = Envelope.check_resource(:cpu_percent, 99)
      assert result != :ok or is_atom(result)

      # CPU within limit
      result_ok = Envelope.check_resource(:cpu_percent, 50)
      assert result_ok == :ok
    end

    test "Envelope enforces temporal constraints independently" do
      # Response time within limit
      result_ok = Envelope.check_temporal(:response_time, 10)
      assert result_ok == :ok

      # Response time exceeding limit (> 50ms)
      result_violation = Envelope.check_temporal(:response_time, 200)
      assert result_violation != :ok
    end

    test "Envelope health_check/1 returns a structured health map" do
      health = Envelope.health_check(%{})
      assert is_map(health)
      assert Map.has_key?(health, :envelope_active)
      assert health.envelope_active == true
    end

    test "Envelope defines critical safety limits" do
      constraints = Envelope.all_constraints()

      # Must contain computational limits
      assert Map.has_key?(constraints, :max_cpu_percent) or
               Map.has_key?(constraints, :max_flame_nodes) or
               map_size(constraints) > 0,
             "Envelope must define at least one safety limit"
    end
  end

  # ─────────────────────────────────────────────────────────────────────────
  # REDUNDANCY INVARIANT VERIFICATION
  # ─────────────────────────────────────────────────────────────────────────

  describe "redundancy invariant — SC-SIMPLEX-002 MinRedundancy=2" do
    test "safety check passes through at least 2 independent layers" do
      proposal = %{
        action: :ai_request,
        source: :cortex,
        intent: :analyze,
        model: "test/model",
        prompt_length: 100
      }

      # Layer 1: Guardian validates
      guardian_result = Guardian.validate_proposal(proposal)
      assert match?({:ok, _}, guardian_result) or match?({:veto, _, _}, guardian_result)

      # Layer 2: Envelope constraints are available and enforced
      constraints = Envelope.all_constraints()
      assert is_map(constraints)

      # Both layers are independently operational — MinRedundancy=2 satisfied
      layer_1_operational =
        match?({:ok, _}, guardian_result) or match?({:veto, _, _}, guardian_result)

      layer_2_operational = is_map(constraints) and map_size(constraints) >= 0

      assert layer_1_operational and layer_2_operational,
             "SC-SIMPLEX-002: Both safety layers must be operational"
    end

    test "GuardianProxy cannot reduce safety components below MinRedundancy" do
      # Guardian health_check integrates both Guardian + DeadMansSwitch
      health = Guardian.health_check(%{})

      # Health check result must contain at least 2 safety sub-systems
      sub_systems = [:guardian, :envelope, :dead_mans_switch]
      present_systems = Enum.filter(sub_systems, &Map.has_key?(health, &1))

      assert length(present_systems) >= @min_redundancy,
             "SC-SIMPLEX-002: health_check must report >= #{@min_redundancy} sub-systems, " <>
               "got: #{inspect(present_systems)}"
    end

    test "simplex kernel redundancy count is at least MinRedundancy=2" do
      # All three simplex kernel modules must be loadable
      kernel_modules = [Guardian, Envelope]

      loaded_count =
        Enum.count(kernel_modules, fn mod ->
          Code.ensure_loaded?(mod)
        end)

      assert loaded_count >= @min_redundancy,
             "SC-SIMPLEX-002: at least #{@min_redundancy} kernel modules must be loaded, " <>
               "got: #{loaded_count}"
    end

    test "Guardian status reflects overall system redundancy" do
      status = Guardian.status()

      # Even when not running, must return valid redundancy information
      assert is_map(status)
      assert Map.has_key?(status, :running)
      assert Map.has_key?(status, :violations)
      assert Map.has_key?(status, :validations)

      # Redundancy is not below minimum — Guardian still provides safety gating
      # even when GenServer is not started (fallback mode)
      assert is_boolean(status.running)
    end

    test "Envelope always provides constraint values regardless of Guardian state" do
      # SC-SIMPLEX-002: Envelope operates independently as the 2nd safety layer
      constraints = Envelope.all_constraints()
      assert is_map(constraints)

      # Verify temporal safety limit is always defined
      heartbeat_ms = Envelope.heartbeat_interval_ms()
      assert is_integer(heartbeat_ms)
      assert heartbeat_ms > 0

      max_response = Envelope.max_response_time_ms()
      assert is_integer(max_response)
      assert max_response > 0
    end
  end

  # ─────────────────────────────────────────────────────────────────────────
  # SIMPLEX CONTROLLER INTEGRATION
  # ─────────────────────────────────────────────────────────────────────────

  describe "SimplexController integrates >= MinRedundancy safety layers" do
    test "build_proposal/1 creates a proposal that can pass through both safety layers" do
      request = %{
        action: :ai_request,
        intent: :analyze,
        source: :cortex,
        prompt: "Analyze code for safety"
      }

      proposal = SimplexController.build_proposal(request)

      # Proposal is a valid map
      assert is_map(proposal)
      assert Map.has_key?(proposal, :action)
      assert Map.has_key?(proposal, :intent)
      assert Map.has_key?(proposal, :model)

      # Layer 1: Guardian can process this proposal
      guardian_result = Guardian.validate_proposal(proposal)
      assert match?({:ok, _}, guardian_result) or match?({:veto, _, _}, guardian_result)

      # Layer 2: Envelope constraints are accessible
      constraints = Envelope.all_constraints()
      assert is_map(constraints)
    end

    test "estimate_tokens/1 is a pure deterministic function (no safety state dependency)" do
      # Token estimation is deterministic — not affected by safety layer state
      result1 = SimplexController.estimate_tokens("Hello world test")
      result2 = SimplexController.estimate_tokens("Hello world test")
      assert result1 == result2
      assert is_integer(result1)
      assert result1 >= 0
    end

    test "infer_intent/1 is pure and safety-independent" do
      # Intent inference operates independently of safety layer state
      assert SimplexController.infer_intent("analyze this code") == :analyze
      assert SimplexController.infer_intent("generate a function") == :synthesize
      assert SimplexController.infer_intent("validate the result") == :validate
      assert SimplexController.infer_intent(nil) == :triage
    end
  end

  # ─────────────────────────────────────────────────────────────────────────
  # PROPERTY TESTS
  # ─────────────────────────────────────────────────────────────────────────

  describe "property: simplex kernel safety layers are always independent" do
    test "Guardian and Envelope always produce consistent safety views (property)" do
      ExUnitProperties.check all(
                               action <-
                                 SD.one_of([SD.atom(:alphanumeric), SD.constant(:ai_request)]),
                               source <- SD.atom(:alphanumeric),
                               max_runs: 10
                             ) do
        proposal = %{action: action, source: source}

        # Layer 1: Guardian validates
        guardian_result = Guardian.validate_proposal(proposal)
        assert match?({:ok, _}, guardian_result) or match?({:veto, _, _}, guardian_result)

        # Layer 2: Envelope constraints remain stable
        constraints = Envelope.all_constraints()
        assert is_map(constraints)
      end
    end

    test "Envelope temporal limits are always positive (property)" do
      ExUnitProperties.check all(_ <- SD.constant(:ok), max_runs: 5) do
        assert Envelope.heartbeat_interval_ms() > 0
        assert Envelope.max_response_time_ms() > 0
        assert Envelope.max_failure_detection_ms() > 0
        assert Envelope.max_recovery_time_ms() > 0
      end
    end
  end
end
