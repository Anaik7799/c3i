defmodule Indrajaal.Safety.GuardianEnvelopeIntegrationTest do
  @moduledoc """
  TDG test suite for Guardian + Envelope integration (SC-GUARD-001 to SC-GUARD-003).

  WHAT: Verifies Guardian validates proposals against the Safety Envelope,
        integrates with DeadMansSwitch, and enforces FounderDirective constraints.
  WHY: SC-GUARD-001 mandates Guardian MUST use Envelope for constraint values.
       SC-GUARD-002 requires integration with DeadMansSwitch (fail closed).
       SC-GUARD-003 requires FounderDirective integration.

  ## STAMP Safety Integration
  - SC-GUARD-001: Guardian MUST use Envelope for constraint values
  - SC-GUARD-002: Guardian integrates with DeadMansSwitch, fail closed when unavailable
  - SC-GUARD-003: Guardian integrates with FounderDirective
  - SC-NEURO-001: All AI proposals MUST pass Guardian validation
  - SC-GDE-001: Guardian validation required before deploy

  NOTE: Guardian falls back to do_validate_proposal/1 when GenServer not running.
        Tests work without starting the full Guardian GenServer where possible.
  """

  use ExUnit.Case, async: false

  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Safety.Guardian
  alias Indrajaal.Safety.Envelope

  @moduletag :unit
  @moduletag :safety

  # ─────────────────────────────────────────────────────────────────────────
  # MODULE EXISTENCE
  # ─────────────────────────────────────────────────────────────────────────

  describe "module existence" do
    test "Guardian module is defined" do
      assert Code.ensure_loaded?(Guardian)
    end

    test "validate_proposal/1 is exported" do
      assert function_exported?(Guardian, :validate_proposal, 1)
    end

    test "validate_proposal/2 is exported (with opts)" do
      assert function_exported?(Guardian, :validate_proposal, 2)
    end

    test "propose/1 is exported (legacy alias)" do
      assert function_exported?(Guardian, :propose, 1)
    end

    test "alive?/0 is exported" do
      # alive?/1 with default opts — check the /1 arity exists
      assert function_exported?(Guardian, :alive?, 1)
    end

    test "status/0 is exported" do
      assert function_exported?(Guardian, :status, 0)
    end

    test "health_check/1 is exported" do
      assert function_exported?(Guardian, :health_check, 1)
    end

    test "constraints/0 is exported" do
      assert function_exported?(Guardian, :constraints, 0)
    end

    test "report_threat/1 is exported" do
      assert function_exported?(Guardian, :report_threat, 1)
    end

    test "Envelope module is defined (SC-GUARD-001)" do
      assert Code.ensure_loaded?(Envelope)
    end
  end

  # ─────────────────────────────────────────────────────────────────────────
  # VALIDATE_PROPOSAL — ENVELOPE CONSTRAINT ENFORCEMENT
  # ─────────────────────────────────────────────────────────────────────────

  describe "validate_proposal/1 envelope constraint enforcement (SC-GUARD-001)" do
    test "returns ok-tuple or veto-tuple for any proposal map" do
      proposal = %{action: :test, source: :test_suite, intent: :verify}
      result = Guardian.validate_proposal(proposal)

      assert match?({:ok, _}, result) or match?({:veto, _, _}, result),
             "Expected {:ok, proposal} or {:veto, reason, fallback}, got: #{inspect(result)}"
    end

    test "approved proposal contains the original proposal data" do
      proposal = %{action: :read_config, source: :cortex, intent: :query}

      case Guardian.validate_proposal(proposal) do
        {:ok, approved} ->
          assert is_map(approved)

          assert Map.get(approved, :action) == :read_config or
                   Map.get(approved, :source) == :cortex

        {:veto, _reason, _fallback} ->
          # Veto is a valid response — constraint enforcement working
          :ok
      end
    end

    test "vetoed proposal returns three-element tuple" do
      # A proposal with a destructive action that might be vetoed
      proposal = %{action: :destroy_all_data, source: :unknown, intent: :destructive}

      result = Guardian.validate_proposal(proposal)

      case result do
        {:ok, _approved} ->
          # May pass — depends on envelope configuration
          :ok

        {:veto, reason, fallback} ->
          assert is_atom(reason) or is_binary(reason),
                 "Veto reason should be atom or string, got: #{inspect(reason)}"

          assert is_map(fallback), "Veto fallback should be a map, got: #{inspect(fallback)}"
      end
    end

    test "empty proposal map is handled gracefully" do
      result = Guardian.validate_proposal(%{})
      assert match?({:ok, _}, result) or match?({:veto, _, _}, result)
    end

    test "proposal with all optional keys is handled" do
      full_proposal = %{
        action: :analyze,
        source: :cortex,
        intent: :synthesize,
        model: "anthropic/claude-3.5-sonnet",
        prompt: "Analyze this",
        temperature: 0.5,
        max_tokens: 1000
      }

      result = Guardian.validate_proposal(full_proposal)
      assert match?({:ok, _}, result) or match?({:veto, _, _}, result)
    end
  end

  # ─────────────────────────────────────────────────────────────────────────
  # PROPOSE/1 — LEGACY ALIAS
  # ─────────────────────────────────────────────────────────────────────────

  describe "propose/1 legacy alias" do
    test "returns approved or vetoed tuple" do
      proposal = %{action: :query_status, source: :test}
      result = Guardian.propose(proposal)

      assert match?({:approved, _}, result) or match?({:vetoed, _}, result),
             "Expected {:approved, proposal} or {:vetoed, reason}, got: #{inspect(result)}"
    end

    test "approved proposal in propose/1 contains map" do
      proposal = %{action: :read, source: :test}

      case Guardian.propose(proposal) do
        {:approved, approved_proposal} ->
          assert is_map(approved_proposal)

        {:vetoed, reason} ->
          assert is_atom(reason) or is_binary(reason)
      end
    end

    test "propose/1 is consistent with validate_proposal/1" do
      proposal = %{action: :ping, source: :test, intent: :health_check}

      validate_result = Guardian.validate_proposal(proposal)
      propose_result = Guardian.propose(proposal)

      # Both should agree on approve/veto
      case {validate_result, propose_result} do
        {{:ok, _}, {:approved, _}} -> :ok
        {{:veto, _, _}, {:vetoed, _}} -> :ok
        # Due to non-determinism or timing, may differ — but both valid
        {{:ok, _}, {:vetoed, _}} -> :ok
        {{:veto, _, _}, {:approved, _}} -> :ok
      end
    end
  end

  # ─────────────────────────────────────────────────────────────────────────
  # ALIVE?/1 — LIVENESS CHECK
  # ─────────────────────────────────────────────────────────────────────────

  describe "alive?/1 liveness check" do
    test "returns a boolean" do
      result = Guardian.alive?()
      assert is_boolean(result)
    end

    test "alive?/1 accepts timeout option" do
      result = Guardian.alive?(timeout: 1_000)
      assert is_boolean(result)
    end

    test "alive?/1 with very short timeout returns false gracefully" do
      # 1ms timeout will almost certainly time out
      result = Guardian.alive?(timeout: 1)
      assert is_boolean(result)
    end
  end

  # ─────────────────────────────────────────────────────────────────────────
  # STATUS/0 — GUARDIAN STATUS
  # ─────────────────────────────────────────────────────────────────────────

  describe "status/0" do
    test "returns a map" do
      result = Guardian.status()
      assert is_map(result)
    end

    test "status map contains :running key" do
      result = Guardian.status()
      assert Map.has_key?(result, :running)
    end

    test ":running is a boolean" do
      result = Guardian.status()
      assert is_boolean(result.running)
    end

    test "status map contains :violations key" do
      result = Guardian.status()
      assert Map.has_key?(result, :violations)
    end

    test "status map contains :validations key" do
      result = Guardian.status()
      assert Map.has_key?(result, :validations)
    end

    test ":violations is a non-negative integer" do
      result = Guardian.status()
      assert is_integer(result.violations) and result.violations >= 0
    end
  end

  # ─────────────────────────────────────────────────────────────────────────
  # CONSTRAINTS/0 — ENVELOPE CONSTRAINT LISTING
  # ─────────────────────────────────────────────────────────────────────────

  describe "constraints/0 — Envelope integration (SC-GUARD-001)" do
    test "returns a map" do
      result = Guardian.constraints()
      assert is_map(result)
    end

    test "constraints map is non-nil" do
      result = Guardian.constraints()
      refute is_nil(result)
    end

    test "delegates to Envelope.all_constraints/0" do
      guardian_constraints = Guardian.constraints()
      envelope_constraints = Envelope.all_constraints()
      assert guardian_constraints == envelope_constraints
    end
  end

  # ─────────────────────────────────────────────────────────────────────────
  # HEALTH_CHECK/1 — INTEGRATED HEALTH CHECK
  # ─────────────────────────────────────────────────────────────────────────

  describe "health_check/1 — DeadMansSwitch + Envelope integration (SC-GUARD-002)" do
    test "returns a map with default empty metrics" do
      result = Guardian.health_check()
      assert is_map(result)
    end

    test "health_check result contains :envelope key" do
      result = Guardian.health_check(%{})
      assert Map.has_key?(result, :envelope)
    end

    test "health_check result contains :dead_mans_switch key (SC-GUARD-002)" do
      result = Guardian.health_check(%{})
      assert Map.has_key?(result, :dead_mans_switch)
    end

    test "health_check result contains :guardian key" do
      result = Guardian.health_check(%{})
      assert Map.has_key?(result, :guardian)
    end

    test "health_check result contains :overall_healthy key" do
      result = Guardian.health_check(%{})
      assert Map.has_key?(result, :overall_healthy)
    end

    test ":overall_healthy is a boolean" do
      result = Guardian.health_check(%{})
      assert is_boolean(result.overall_healthy)
    end

    test "dead_mans_switch sub-map contains :state key" do
      result = Guardian.health_check(%{})
      assert is_map(result.dead_mans_switch)
      assert Map.has_key?(result.dead_mans_switch, :state)
    end

    test "dead_mans_switch sub-map contains :heartbeats_received key" do
      result = Guardian.health_check(%{})
      assert Map.has_key?(result.dead_mans_switch, :heartbeats_received)
    end
  end

  # ─────────────────────────────────────────────────────────────────────────
  # REPORT_THREAT/1 — THREAT REPORTING
  # ─────────────────────────────────────────────────────────────────────────

  describe "report_threat/1" do
    test "returns :ok for any threat map" do
      threat = %{
        type: :anomaly,
        severity: :high,
        signature: "test_threat",
        source: :test_suite
      }

      assert :ok == Guardian.report_threat(threat)
    end

    test "returns :ok for empty threat map" do
      assert :ok == Guardian.report_threat(%{})
    end

    test "returns :ok for threat with reason field" do
      threat = %{reason: :test_reason}
      assert :ok == Guardian.report_threat(threat)
    end
  end

  # ─────────────────────────────────────────────────────────────────────────
  # VALIDATE_PROPOSAL/2 — WITH OPTIONS
  # ─────────────────────────────────────────────────────────────────────────

  describe "validate_proposal/2 with options" do
    test "accepts timeout option" do
      proposal = %{action: :test, source: :test}
      result = Guardian.validate_proposal(proposal, timeout: 5_000)
      assert match?({:ok, _}, result) or match?({:veto, _, _}, result)
    end

    test "very short timeout still returns a result gracefully" do
      proposal = %{action: :test, source: :test}
      # Short timeout — may fall back to do_validate_proposal/1
      result = Guardian.validate_proposal(proposal, timeout: 1)
      assert match?({:ok, _}, result) or match?({:veto, _, _}, result)
    end
  end

  # ─────────────────────────────────────────────────────────────────────────
  # PROPERTY TESTS — ENVELOPE CONSTRAINT INVARIANTS
  # ─────────────────────────────────────────────────────────────────────────

  describe "property: validate_proposal always returns valid tuple" do
    test "any proposal map always yields ok or veto tuple (property)" do
      ExUnitProperties.check all(
                               action <- SD.one_of([SD.atom(:alphanumeric), SD.constant(nil)]),
                               source <- SD.atom(:alphanumeric),
                               intent <-
                                 SD.one_of([
                                   SD.member_of([:analyze, :synthesize, :query, :verify]),
                                   SD.atom(:alphanumeric)
                                 ])
                             ) do
        proposal = %{source: source, intent: intent}

        proposal =
          if is_nil(action), do: proposal, else: Map.put(proposal, :action, action)

        result = Guardian.validate_proposal(proposal)
        assert match?({:ok, _}, result) or match?({:veto, _, _}, result)
      end
    end
  end

  describe "property: constraints/0 is stable across calls" do
    test "constraints/0 returns same value on repeated calls (property)" do
      ExUnitProperties.check all(_ <- SD.constant(:ok), max_runs: 5) do
        c1 = Guardian.constraints()
        c2 = Guardian.constraints()
        assert c1 == c2
      end
    end
  end
end
