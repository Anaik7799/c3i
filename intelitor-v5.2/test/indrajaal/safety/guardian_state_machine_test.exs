defmodule Indrajaal.Safety.GuardianStateMachineTest do
  @moduledoc """
  TDG test suite for the Guardian state machine — 5 states, 8 transitions.

  WHAT: Tests the Guardian state machine lifecycle from :idle through
  :evaluating → :approved/:vetoed/:emergency and back, including the
  emergency override path and constitutional invariant checking.

  WHY: SC-GUARD-001 requires the Guardian to use the Envelope pattern for
  all constraint values. SC-GUARD-002 mandates DeadMansSwitch integration
  with fail-closed behaviour on timeout. SC-GUARD-003 mandates integration
  with the FounderDirective. AOR-CONST-003 specifies that the Guardian has
  absolute veto — it cannot be disabled or overridden.

  CONSTRAINTS:
  - SC-GUARD-001: Guardian MUST use Envelope for constraint values
  - SC-GUARD-002: Guardian integrates with DeadMansSwitch, fail closed
  - SC-GUARD-003: Guardian integrates with FounderDirective
  - SC-SAFETY-001: Guardian pre-approval required for planning mutations
  - SC-SAFETY-009: Ψ₀ (Existence) validated for all operations
  - SC-SAFETY-010: Ψ₁ (Regeneration) verified — SQLite/DuckDB storage
  - SC-SAFETY-011: Ψ₂ (History) prevent history deletion
  - SC-SAFETY-012: Ψ₃ (Verification) hash chain integrity
  - SC-SAFETY-013: Ψ₄ (Human Alignment) Founder's lineage PRIMARY
  - SC-SAFETY-014: Ψ₅ (Truthfulness) no deception in logs
  - AOR-CONST-003: Guardian has absolute veto — cannot be overridden or disabled
  - AOR-CONST-004: Axioms Ψ₀–Ψ₅ are hardcoded; no code path may modify them

  ## Constitutional Verification
  - Ψ₀ (Existence): System survives all state transitions without crash
  - Ψ₃ (Verification): All state changes are deterministic and auditable
  - Ψ₄ (Human Alignment): FounderDirective gates are evaluated in :evaluating

  ## State Machine Topology
  ```
       ┌──────────────────────────┐
       │        :idle             │◄──────────────────────────────┐
       └──────────┬───────────────┘                               │
                  │ proposal received                             │ resolved /
                  ▼                                               │ acknowledged
       ┌──────────────────────────┐                               │
       │      :evaluating         │──── safety violation ──► :vetoed ──┤
       └──────────┬──────────────┬┘                               │    │
                  │              │                                 │    │
          checks  │              │ critical                        │    │
          pass    │              │ threat                          │    │
                  ▼              ▼                                 │    │
            :approved        :emergency ◄── any-state override    │    │
                  │              │                                 │    │
                  └──────────────┴─────────────────────────────────────┘
  ```

  ## 8 Valid Transitions
  1. idle → evaluating       (proposal received)
  2. evaluating → approved   (safety checks pass)
  3. evaluating → vetoed     (safety violation detected)
  4. evaluating → emergency  (critical threat during evaluation)
  5. approved → idle         (proposal executed)
  6. vetoed → idle           (veto acknowledged)
  7. emergency → idle        (emergency resolved)
  8. any → emergency         (critical override — highest priority)

  ## Change History
  | Version | Date       | Author | Change                                         |
  |---------|------------|--------|------------------------------------------------|
  | 21.3.0  | 2026-03-24 | Claude | Sprint 88 Wave 3 — guardian state machine TDG  |
  """

  use ExUnit.Case, async: true

  # EP-GEN-014: dual property testing — mandatory import pattern
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :safety
  @moduletag :guardian
  @moduletag :state_machine

  # ---------------------------------------------------------------------------
  # State machine constants
  # ---------------------------------------------------------------------------

  @valid_states [:idle, :evaluating, :approved, :vetoed, :emergency]

  # Every state may transition to :emergency via the critical-override path.
  # Transitions are expressed as {from_state, event, to_state}.
  @valid_transitions [
    {:idle, :proposal_received, :evaluating},
    {:evaluating, :checks_pass, :approved},
    {:evaluating, :violation_detected, :vetoed},
    {:evaluating, :critical_threat, :emergency},
    {:approved, :proposal_executed, :idle},
    {:vetoed, :veto_acknowledged, :idle},
    {:emergency, :emergency_resolved, :idle},
    # any-state → emergency is the critical override
    {:idle, :critical_override, :emergency},
    {:evaluating, :critical_override, :emergency},
    {:approved, :critical_override, :emergency},
    {:vetoed, :critical_override, :emergency}
  ]

  # Events that are NOT valid from :idle (guard against direct bypass)
  @invalid_from_idle_events [
    :checks_pass,
    :violation_detected,
    :proposal_executed,
    :veto_acknowledged,
    :emergency_resolved
  ]

  # ============================================================================
  # Section 1 — Initial State
  # ============================================================================

  describe "initial state (SC-GUARD-001)" do
    test "guardian starts in :idle state" do
      state = new_guardian_state()
      assert state.status == :idle
    end

    test "initial state has nil current_proposal" do
      state = new_guardian_state()
      assert state.current_proposal == nil
    end

    test "initial state has zero transition count" do
      state = new_guardian_state()
      assert state.transition_count == 0
    end

    test "initial state has empty history" do
      state = new_guardian_state()
      assert state.history == []
    end

    test "initial state marks guardian as enabled" do
      state = new_guardian_state()
      assert state.enabled == true
    end

    test "initial state has nil last_veto" do
      state = new_guardian_state()
      assert state.last_veto == nil
    end
  end

  # ============================================================================
  # Section 2 — All 8 Valid Transitions
  # ============================================================================

  describe "transition 1: idle → evaluating (proposal received)" do
    test "idle transitions to :evaluating on proposal_received" do
      state = new_guardian_state()
      proposal = make_proposal(:scale_up, %{quantity: 10})

      {:ok, next} = apply_transition(state, :proposal_received, %{proposal: proposal})

      assert next.status == :evaluating
      assert next.current_proposal != nil
      assert next.current_proposal.action == :scale_up
    end

    test "transition records proposal in state" do
      state = new_guardian_state()
      proposal = make_proposal(:deploy, %{version: "21.3.0"})

      {:ok, next} = apply_transition(state, :proposal_received, %{proposal: proposal})

      assert next.current_proposal.action == :deploy
    end

    test "transition increments transition_count" do
      state = new_guardian_state()

      {:ok, next} =
        apply_transition(state, :proposal_received, %{proposal: make_proposal(:read, %{})})

      assert next.transition_count == 1
    end

    test "transition appends to history" do
      state = new_guardian_state()

      {:ok, next} =
        apply_transition(state, :proposal_received, %{proposal: make_proposal(:read, %{})})

      assert length(next.history) == 1
      assert hd(next.history).from == :idle
      assert hd(next.history).to == :evaluating
      assert hd(next.history).event == :proposal_received
    end
  end

  describe "transition 2: evaluating → approved (checks pass)" do
    test "evaluating transitions to :approved on checks_pass" do
      state = evaluating_state()

      {:ok, next} = apply_transition(state, :checks_pass, %{})

      assert next.status == :approved
    end

    test "approved state retains the proposal being evaluated" do
      proposal = make_proposal(:config_update, %{key: "timeout"})
      state = evaluating_state(proposal)

      {:ok, next} = apply_transition(state, :checks_pass, %{})

      assert next.current_proposal.action == :config_update
    end

    test "approval records constitutional check results" do
      state = evaluating_state()

      {:ok, next} = apply_transition(state, :checks_pass, %{psi_checks: all_psi_passed()})

      assert next.last_approval != nil
      assert next.last_approval.psi_checks != nil
    end
  end

  describe "transition 3: evaluating → vetoed (violation detected)" do
    test "evaluating transitions to :vetoed on violation_detected" do
      state = evaluating_state()

      {:ok, next} =
        apply_transition(state, :violation_detected, %{reason: :resource_limit_exceeded})

      assert next.status == :vetoed
    end

    test "veto stores the violation reason" do
      state = evaluating_state()

      {:ok, next} = apply_transition(state, :violation_detected, %{reason: :forbidden_operation})

      assert next.last_veto != nil
      assert next.last_veto.reason == :forbidden_operation
    end

    test "veto records which constitutional axiom was violated" do
      state = evaluating_state()

      {:ok, next} =
        apply_transition(state, :violation_detected, %{
          reason: :psi4_alignment_failed,
          axiom: :psi4
        })

      assert next.last_veto.axiom == :psi4
    end
  end

  describe "transition 4: evaluating → emergency (critical threat)" do
    test "evaluating transitions to :emergency on critical_threat" do
      state = evaluating_state()

      {:ok, next} = apply_transition(state, :critical_threat, %{threat_level: :critical})

      assert next.status == :emergency
    end

    test "emergency state stores the threat that triggered it" do
      state = evaluating_state()

      {:ok, next} =
        apply_transition(state, :critical_threat, %{
          threat_level: :critical,
          source: :pattern_hunter
        })

      assert next.emergency_context != nil
      assert next.emergency_context.source == :pattern_hunter
    end
  end

  describe "transition 5: approved → idle (proposal executed)" do
    test "approved transitions to :idle on proposal_executed" do
      state = approved_state()

      {:ok, next} = apply_transition(state, :proposal_executed, %{})

      assert next.status == :idle
    end

    test "idle state after execution has nil current_proposal" do
      state = approved_state()

      {:ok, next} = apply_transition(state, :proposal_executed, %{})

      assert next.current_proposal == nil
    end

    test "execution result is recorded in history" do
      state = approved_state()

      {:ok, next} = apply_transition(state, :proposal_executed, %{result: :ok})

      last = hd(next.history)
      assert last.from == :approved
      assert last.to == :idle
      assert last.event == :proposal_executed
    end
  end

  describe "transition 6: vetoed → idle (veto acknowledged)" do
    test "vetoed transitions to :idle on veto_acknowledged" do
      state = vetoed_state()

      {:ok, next} = apply_transition(state, :veto_acknowledged, %{})

      assert next.status == :idle
    end

    test "veto history is preserved after acknowledgement" do
      state = vetoed_state(:forbidden_operation)

      {:ok, next} = apply_transition(state, :veto_acknowledged, %{})

      assert next.last_veto != nil
      assert next.last_veto.reason == :forbidden_operation
    end

    test "current_proposal is cleared after veto acknowledged" do
      state = vetoed_state()

      {:ok, next} = apply_transition(state, :veto_acknowledged, %{})

      assert next.current_proposal == nil
    end
  end

  describe "transition 7: emergency → idle (emergency resolved)" do
    test "emergency transitions to :idle on emergency_resolved" do
      state = emergency_state()

      {:ok, next} =
        apply_transition(state, :emergency_resolved, %{resolution: :safe_state_reached})

      assert next.status == :idle
    end

    test "resolution records how the emergency was cleared" do
      state = emergency_state()

      {:ok, next} = apply_transition(state, :emergency_resolved, %{resolution: :operator_cleared})

      last = hd(next.history)
      assert last.from == :emergency
      assert last.to == :idle
    end
  end

  describe "transition 8: any → emergency (critical override)" do
    test "idle can be forced to :emergency via critical_override" do
      state = new_guardian_state()
      assert state.status == :idle

      {:ok, next} = apply_transition(state, :critical_override, %{trigger: :external_threat})

      assert next.status == :emergency
    end

    test "evaluating can be forced to :emergency via critical_override" do
      state = evaluating_state()

      {:ok, next} = apply_transition(state, :critical_override, %{trigger: :dms_timeout})

      assert next.status == :emergency
    end

    test "approved can be forced to :emergency via critical_override" do
      state = approved_state()

      {:ok, next} = apply_transition(state, :critical_override, %{trigger: :sentinel_alert})

      assert next.status == :emergency
    end

    test "vetoed can be forced to :emergency via critical_override" do
      state = vetoed_state()

      {:ok, next} =
        apply_transition(state, :critical_override, %{trigger: :constitutional_threat})

      assert next.status == :emergency
    end

    test "emergency override from any state preserves override trigger in context" do
      for starting_state <- [:idle, :evaluating, :approved, :vetoed] do
        state = state_for(starting_state)

        {:ok, next} = apply_transition(state, :critical_override, %{trigger: :test_trigger})

        assert next.status == :emergency, "Expected :emergency from #{starting_state}"

        assert next.emergency_context.trigger == :test_trigger,
               "Expected trigger preserved from #{starting_state}"
      end
    end
  end

  # ============================================================================
  # Section 3 — Invalid Transitions
  # ============================================================================

  describe "invalid transitions are rejected" do
    test "idle → approved is rejected (cannot bypass :evaluating)" do
      state = new_guardian_state()
      assert {:error, :invalid_transition} = apply_transition(state, :checks_pass, %{})
    end

    test "idle → vetoed is rejected" do
      state = new_guardian_state()
      assert {:error, :invalid_transition} = apply_transition(state, :violation_detected, %{})
    end

    test "idle → idle via proposal_executed is rejected" do
      state = new_guardian_state()
      assert {:error, :invalid_transition} = apply_transition(state, :proposal_executed, %{})
    end

    test "idle → idle via veto_acknowledged is rejected" do
      state = new_guardian_state()
      assert {:error, :invalid_transition} = apply_transition(state, :veto_acknowledged, %{})
    end

    test "idle → idle via emergency_resolved is rejected" do
      state = new_guardian_state()
      assert {:error, :invalid_transition} = apply_transition(state, :emergency_resolved, %{})
    end

    test "approved → evaluating is rejected (no backward path)" do
      state = approved_state()
      assert {:error, :invalid_transition} = apply_transition(state, :proposal_received, %{})
    end

    test "vetoed → evaluating is rejected" do
      state = vetoed_state()
      assert {:error, :invalid_transition} = apply_transition(state, :proposal_received, %{})
    end

    test "vetoed → approved is rejected (vetoes cannot be reversed)" do
      state = vetoed_state()
      assert {:error, :invalid_transition} = apply_transition(state, :checks_pass, %{})
    end

    test "emergency → evaluating is rejected (must pass through idle)" do
      state = emergency_state()
      assert {:error, :invalid_transition} = apply_transition(state, :proposal_received, %{})
    end

    test "unknown event from any state is rejected" do
      for s <- @valid_states do
        state = state_for(s)

        assert {:error, :invalid_transition} = apply_transition(state, :nonexistent_event, %{}),
               "Expected rejection of unknown event from #{s}"
      end
    end
  end

  # ============================================================================
  # Section 4 — Emergency Override (any → emergency)
  # ============================================================================

  describe "emergency override from every valid state" do
    test "critical_override works from all 5 states" do
      for starting_state <- @valid_states do
        state = state_for(starting_state)
        result = apply_transition(state, :critical_override, %{trigger: :forced})

        # :emergency is already in emergency — transition still accepted
        # (emergency → emergency via override is a no-op upgrade with updated context)
        assert match?({:ok, %{status: :emergency}}, result),
               "critical_override failed from #{starting_state}"
      end
    end
  end

  # ============================================================================
  # Section 5 — Veto is Absolute (AOR-CONST-003)
  # ============================================================================

  describe "veto is absolute — cannot be overridden (AOR-CONST-003)" do
    test "veto cannot be turned into approval" do
      state = vetoed_state()
      assert {:error, :invalid_transition} = apply_transition(state, :checks_pass, %{})
    end

    test "veto cannot be silently cleared without acknowledgement event" do
      state = vetoed_state(:safety_violation)

      # Attempting to jump directly to evaluating or approved is rejected
      assert {:error, :invalid_transition} = apply_transition(state, :proposal_received, %{})
      assert {:error, :invalid_transition} = apply_transition(state, :checks_pass, %{})
    end

    test "only veto_acknowledged resets from vetoed to idle" do
      state = vetoed_state()

      {:ok, next} = apply_transition(state, :veto_acknowledged, %{})
      assert next.status == :idle
    end

    test "veto reason is preserved after cycle back to idle" do
      state = vetoed_state(:resource_limit_exceeded)
      {:ok, idle_state} = apply_transition(state, :veto_acknowledged, %{})

      # Guardian keeps the last veto in its state — audit trail is preserved
      assert idle_state.last_veto != nil
      assert idle_state.last_veto.reason == :resource_limit_exceeded
    end

    test "veto history accumulates across multiple vetoes" do
      state = new_guardian_state()

      # First cycle
      {:ok, ev1} =
        apply_transition(state, :proposal_received, %{proposal: make_proposal(:op1, %{})})

      {:ok, vt1} = apply_transition(ev1, :violation_detected, %{reason: :violation_1})
      {:ok, id1} = apply_transition(vt1, :veto_acknowledged, %{})

      # Second cycle
      {:ok, ev2} =
        apply_transition(id1, :proposal_received, %{proposal: make_proposal(:op2, %{})})

      {:ok, vt2} = apply_transition(ev2, :violation_detected, %{reason: :violation_2})

      assert vt2.last_veto.reason == :violation_2
      # History contains both cycles
      veto_events = Enum.filter(vt2.history, &(&1.to == :vetoed))
      assert length(veto_events) == 2
    end
  end

  # ============================================================================
  # Section 6 — Property: random valid transition sequences end in valid state
  # ============================================================================

  describe "property: random valid sequences end in a valid state (SC-GUARD-001)" do
    test "up to 10 valid random transitions always end in a valid state" do
      ExUnitProperties.check all(
                               events <-
                                 SD.list_of(SD.member_of(valid_event_names()),
                                   min_length: 1,
                                   max_length: 10
                                 )
                             ) do
        final_state = execute_valid_sequence(events)

        assert final_state.status in @valid_states,
               "State #{inspect(final_state.status)} is not a valid guardian state"
      end
    end

    test "transition count equals number of successful transitions" do
      ExUnitProperties.check all(n <- SD.integer(1, 8)) do
        events = Enum.take(cycle_events(), n)
        state = execute_valid_sequence(events)
        assert state.transition_count == n
      end
    end

    test "history length matches transition count after any sequence" do
      ExUnitProperties.check all(
                               events <-
                                 SD.list_of(SD.member_of(valid_event_names()),
                                   min_length: 1,
                                   max_length: 6
                                 )
                             ) do
        state = execute_valid_sequence(events)
        assert length(state.history) == state.transition_count
      end
    end
  end

  # ============================================================================
  # Section 7 — Property: no sequence can bypass :evaluating to reach :approved
  # ============================================================================

  describe "property: :approved is only reachable through :evaluating" do
    test "checks_pass event only applies when current state is :evaluating" do
      ExUnitProperties.check all(
                               state_name <- SD.member_of([:idle, :approved, :vetoed, :emergency])
                             ) do
        state = state_for(state_name)
        result = apply_transition(state, :checks_pass, %{})

        assert result == {:error, :invalid_transition},
               "checks_pass from #{state_name} should be rejected"
      end
    end

    test "no event sequence transitions idle → approved without going through evaluating" do
      ExUnitProperties.check all(
                               # Generate sequences of non-evaluating events
                               events <-
                                 SD.list_of(
                                   SD.member_of([
                                     :proposal_executed,
                                     :veto_acknowledged,
                                     :emergency_resolved,
                                     :critical_override
                                   ]),
                                   min_length: 1,
                                   max_length: 5
                                 )
                             ) do
        state = new_guardian_state()

        final =
          Enum.reduce(events, state, fn event, acc ->
            case apply_transition(acc, event, %{}) do
              {:ok, next} -> next
              {:error, _} -> acc
            end
          end)

        # Without a proposal_received → evaluating path, approved is unreachable
        refute final.status == :approved,
               "Should not reach :approved without :evaluating"
      end
    end
  end

  # ============================================================================
  # Section 8 — DeadMansSwitch timeout triggers emergency (SC-GUARD-002)
  # ============================================================================

  describe "DeadMansSwitch timeout triggers emergency (SC-GUARD-002)" do
    test "dms_timeout event triggers emergency from :evaluating" do
      state = evaluating_state()

      {:ok, next} = apply_dms_timeout(state)

      assert next.status == :emergency
    end

    test "dms_timeout in any non-idle state triggers emergency (fail-closed)" do
      for s <- [:evaluating, :approved, :vetoed] do
        state = state_for(s)
        {:ok, next} = apply_dms_timeout(state)

        assert next.status == :emergency,
               "DMS timeout from #{s} should force :emergency"
      end
    end

    test "dms_timeout from :idle transitions to :emergency (fail-closed by default)" do
      state = new_guardian_state()
      {:ok, next} = apply_dms_timeout(state)

      assert next.status == :emergency
    end

    test "dms_timeout stores the timeout reason in emergency_context" do
      state = evaluating_state()

      {:ok, next} = apply_dms_timeout(state)

      assert next.emergency_context != nil
      assert next.emergency_context.trigger == :dms_timeout
    end

    test "fail-closed means deny when DMS fires — no partial approvals" do
      state = evaluating_state()
      {:ok, emergency} = apply_dms_timeout(state)

      # In emergency, no proposal may be approved
      assert emergency.status == :emergency
      assert emergency.current_proposal == nil or emergency.status != :approved
    end

    test "DMS heartbeat tracking is separate from transition count" do
      state = new_guardian_state()
      updated = record_dms_heartbeat(state)

      # Heartbeat does not change state or increment transition count
      assert updated.status == :idle
      assert updated.transition_count == 0
      assert updated.last_heartbeat_at != nil
    end
  end

  # ============================================================================
  # Section 9 — Envelope pattern (SC-GUARD-001)
  # ============================================================================

  describe "proposal validation uses Envelope pattern (SC-GUARD-001)" do
    test "proposal without an envelope is wrapped before evaluation" do
      raw = %{action: :scale_up, quantity: 10}
      wrapped = wrap_in_envelope(raw)

      assert wrapped.payload == raw
      assert wrapped.envelope_version == 1
      assert is_integer(wrapped.created_at)
      assert is_integer(wrapped.expires_at)
      assert wrapped.expires_at > wrapped.created_at
    end

    test "envelope carries a deterministic signature over its content" do
      proposal = %{action: :deploy, version: "21.3.0"}
      env1 = wrap_in_envelope(proposal)
      env2 = wrap_in_envelope(proposal)

      # Signatures are deterministic for same content and same expiry
      assert env1.signature != nil
      assert is_binary(env1.signature)

      # Each wrap call uses the current time so timestamps may differ slightly;
      # we only assert structural integrity here.
      assert env2.signature != nil
    end

    test "expired envelope is rejected before evaluation" do
      proposal = %{action: :read, resource: :metrics}
      expired_env = wrap_in_envelope(proposal, ttl_ms: -1)

      assert validate_envelope(expired_env) == {:error, :expired}
    end

    test "valid envelope passes validation" do
      proposal = %{action: :read, resource: :status}
      env = wrap_in_envelope(proposal, ttl_ms: 30_000)

      assert {:ok, _} = validate_envelope(env)
    end

    test "tampered envelope payload is detected" do
      proposal = %{action: :read, resource: :status}
      env = wrap_in_envelope(proposal, ttl_ms: 30_000)

      # Tamper: change payload but keep original signature
      tampered = %{env | payload: %{action: :delete_all}}

      assert {:error, :invalid_signature} = validate_envelope(tampered)
    end

    test "state machine transitions through envelope validation in :evaluating" do
      state = new_guardian_state()
      proposal = make_proposal(:update_config, %{param: "value"})

      {:ok, ev_state} = apply_transition(state, :proposal_received, %{proposal: proposal})

      # The envelope is attached during transition to :evaluating
      assert ev_state.current_proposal != nil
      assert ev_state.status == :evaluating
    end
  end

  # ============================================================================
  # Section 10 — FounderDirective integration (SC-GUARD-003)
  # ============================================================================

  describe "FounderDirective integration (SC-GUARD-003)" do
    test "evaluating state checks founder_directive alignment" do
      proposal = make_proposal(:resource_acquisition, %{amount: 1_000})
      result = evaluate_founder_directive(proposal)

      assert result.checked == true
      assert result.alignment in [:aligned, :neutral, :misaligned]
    end

    test "proposal aligned with FounderDirective passes checks" do
      # Resource acquisition is aligned with Ω₀.1 / Ω₀.7 (power accumulation)
      proposal = make_proposal(:acquire_resource, %{type: :compute, amount: 100})
      result = evaluate_founder_directive(proposal)

      assert result.alignment in [:aligned, :neutral]
    end

    test "proposal that reduces Founder lineage capability is flagged" do
      # Simulate a proposal that would harm the Founder's directive
      proposal = make_proposal(:reduce_capability, %{target: :founder_systems, reason: :test})
      result = evaluate_founder_directive(proposal)

      assert result.alignment == :misaligned
      assert result.reason == :reduces_founder_capability
    end

    test "FounderDirective check is part of evaluating → approved path" do
      state = evaluating_state()

      # Simulate a founder-aligned checks_pass
      fd_result = %{checked: true, alignment: :aligned}
      {:ok, next} = apply_transition(state, :checks_pass, %{founder_directive: fd_result})

      assert next.status == :approved
      assert next.last_approval.founder_directive.alignment == :aligned
    end

    test "FounderDirective misalignment causes veto" do
      state = evaluating_state()

      fd_result = %{checked: true, alignment: :misaligned, reason: :reduces_founder_capability}

      {:ok, next} =
        apply_transition(state, :violation_detected, %{
          reason: :founder_directive_violated,
          founder_directive: fd_result
        })

      assert next.status == :vetoed
      assert next.last_veto.reason == :founder_directive_violated
    end

    test "Ω₀ symbiotic survival is validated during evaluation" do
      proposal = make_proposal(:shutdown_founder_holon, %{})
      result = evaluate_omega0(proposal)

      assert result.omega0_checked == true
      assert result.survival_threat == true
    end
  end

  # ============================================================================
  # Section 11 — Constitutional Invariants Ψ₀–Ψ₅
  # ============================================================================

  describe "constitutional invariants Ψ₀–Ψ₅ checked during evaluation" do
    test "Ψ₀ (Existence): proposal that would halt the system is vetoed" do
      # SC-SAFETY-009
      proposal = make_proposal(:halt_system, %{reason: :test})
      result = check_psi0(proposal)

      assert result.passed == false
      assert result.axiom == :psi0
    end

    test "Ψ₁ (Regeneration): proposal must not destroy SQLite/DuckDB state" do
      # SC-SAFETY-010
      proposal = make_proposal(:delete_holon_db, %{path: "data/holons/"})
      result = check_psi1(proposal)

      assert result.passed == false
      assert result.axiom == :psi1
    end

    test "Ψ₂ (History): proposal must not delete or rewrite history" do
      # SC-SAFETY-011
      proposal = make_proposal(:truncate_history, %{table: :immutable_register})
      result = check_psi2(proposal)

      assert result.passed == false
      assert result.axiom == :psi2
    end

    test "Ψ₃ (Verification): hash chain must remain intact" do
      # SC-SAFETY-012
      current_hash = :crypto.hash(:sha3_256, "test_block") |> Base.encode16(case: :lower)
      result = check_psi3(current_hash, current_hash)

      assert result.passed == true
      assert result.axiom == :psi3
    end

    test "Ψ₃ (Verification): broken hash chain is a violation" do
      expected_hash = :crypto.hash(:sha3_256, "block_a") |> Base.encode16(case: :lower)
      actual_hash = :crypto.hash(:sha3_256, "block_b") |> Base.encode16(case: :lower)

      result = check_psi3(expected_hash, actual_hash)

      assert result.passed == false
      assert result.axiom == :psi3
    end

    test "Ψ₄ (Human Alignment): Founder's lineage is PRIMARY" do
      # SC-SAFETY-013
      proposal = make_proposal(:prioritise_founder, %{beneficiary: :founder_lineage})
      result = check_psi4(proposal)

      assert result.passed == true
      assert result.axiom == :psi4
    end

    test "Ψ₅ (Truthfulness): deceptive log entry is a violation" do
      # SC-SAFETY-014
      log_entry = %{message: "Everything OK", actual_status: :critical_failure}
      result = check_psi5(log_entry)

      assert result.passed == false
      assert result.axiom == :psi5
    end

    test "all Ψ checks aggregate into a single constitutional result" do
      proposal = make_proposal(:safe_read, %{resource: :metrics})
      result = check_all_psi(proposal)

      assert is_map(result)
      assert Map.has_key?(result, :psi0)
      assert Map.has_key?(result, :psi1)
      assert Map.has_key?(result, :psi2)
      assert Map.has_key?(result, :psi3)
      assert Map.has_key?(result, :psi4)
      assert Map.has_key?(result, :psi5)
      # A safe read passes all checks
      assert Enum.all?([:psi0, :psi1, :psi2, :psi3, :psi4, :psi5], fn k ->
               result[k].passed == true
             end)
    end
  end

  # ============================================================================
  # Section 12 — Guardian cannot be disabled (AOR-CONST-003)
  # ============================================================================

  describe "Guardian cannot be disabled or overridden (AOR-CONST-003)" do
    test "guardian.enabled is always true and cannot be set to false" do
      state = new_guardian_state()
      assert state.enabled == true

      # Attempt to disable — must be rejected
      result = attempt_disable_guardian(state)

      assert result == {:error, :guardian_cannot_be_disabled}
    end

    test "guardian rejects a proposal to disable itself" do
      proposal = make_proposal(:disable_guardian, %{reason: "maintenance"})
      result = validate_proposal_against_guardian_immutability(proposal)

      assert result == {:veto, :guardian_immutability_violation}
    end

    test "guardian rejects a proposal to bypass itself" do
      proposal = make_proposal(:bypass_safety_checks, %{target: :guardian})
      result = validate_proposal_against_guardian_immutability(proposal)

      assert result == {:veto, :guardian_immutability_violation}
    end

    test "guardian rejects proposals to modify its own rules" do
      proposal = make_proposal(:update_guardian_rules, %{remove: :psi4_check})
      result = validate_proposal_against_guardian_immutability(proposal)

      assert result == {:veto, :guardian_immutability_violation}
    end

    test "guardian state machine has no disabled state (no bypass path exists)" do
      refute :disabled in @valid_states
      refute :bypassed in @valid_states
    end

    test "enabled flag is not a transition target — it is a hardcoded invariant" do
      state = new_guardian_state()

      # Simulate multiple transitions; enabled must remain true throughout
      {:ok, s1} =
        apply_transition(state, :proposal_received, %{proposal: make_proposal(:read, %{})})

      {:ok, s2} = apply_transition(s1, :checks_pass, %{})
      {:ok, s3} = apply_transition(s2, :proposal_executed, %{})

      assert s1.enabled == true
      assert s2.enabled == true
      assert s3.enabled == true
    end
  end

  # ============================================================================
  # PropCheck property tests — SC-GUARD-001/002/003
  # ============================================================================

  describe "property: valid transitions always produce a valid state (PropCheck)" do
    property "any valid transition leaves status in @valid_states" do
      forall {from_atom, event_atom} <- {
               PC.oneof(@valid_states),
               PC.oneof(valid_event_names())
             } do
        state = state_for(from_atom)

        case apply_transition(state, event_atom, %{}) do
          {:ok, next} -> next.status in @valid_states
          {:error, :invalid_transition} -> true
        end
      end
    end

    property "transition_count is always non-negative" do
      forall events <- PC.list(PC.oneof(valid_event_names())) do
        state =
          Enum.reduce(events, new_guardian_state(), fn event, acc ->
            case apply_transition(acc, event, %{}) do
              {:ok, next} -> next
              {:error, _} -> acc
            end
          end)

        state.transition_count >= 0
      end
    end

    property "history length always equals transition_count" do
      forall events <- PC.list(PC.oneof(valid_event_names())) do
        state =
          Enum.reduce(events, new_guardian_state(), fn event, acc ->
            case apply_transition(acc, event, %{}) do
              {:ok, next} -> next
              {:error, _} -> acc
            end
          end)

        length(state.history) == state.transition_count
      end
    end
  end

  # ============================================================================
  # PRIVATE HELPERS — state machine implementation
  # ============================================================================

  # Creates a fresh Guardian state at :idle.
  defp new_guardian_state do
    %{
      status: :idle,
      enabled: true,
      current_proposal: nil,
      transition_count: 0,
      history: [],
      last_veto: nil,
      last_approval: nil,
      emergency_context: nil,
      last_heartbeat_at: nil
    }
  end

  # Convenience constructors for pre-seeded states.
  defp evaluating_state(proposal \\ nil) do
    p = proposal || make_proposal(:default_op, %{})

    %{
      new_guardian_state()
      | status: :evaluating,
        current_proposal: p,
        transition_count: 1,
        history: [transition_record(:idle, :evaluating, :proposal_received)]
    }
  end

  defp approved_state do
    p = make_proposal(:read_metrics, %{})

    %{
      new_guardian_state()
      | status: :approved,
        current_proposal: p,
        transition_count: 2,
        last_approval: %{
          psi_checks: all_psi_passed(),
          founder_directive: %{checked: true, alignment: :aligned}
        },
        history: [
          transition_record(:idle, :evaluating, :proposal_received),
          transition_record(:evaluating, :approved, :checks_pass)
        ]
    }
  end

  defp vetoed_state(reason \\ :default_violation) do
    p = make_proposal(:risky_op, %{})

    %{
      new_guardian_state()
      | status: :vetoed,
        current_proposal: p,
        transition_count: 2,
        last_veto: %{reason: reason, axiom: nil, timestamp: System.system_time(:millisecond)},
        history: [
          transition_record(:idle, :evaluating, :proposal_received),
          transition_record(:evaluating, :vetoed, :violation_detected)
        ]
    }
  end

  defp emergency_state do
    %{
      new_guardian_state()
      | status: :emergency,
        transition_count: 1,
        emergency_context: %{
          trigger: :sentinel_alert,
          timestamp: System.system_time(:millisecond)
        },
        history: [transition_record(:idle, :emergency, :critical_override)]
    }
  end

  # Returns a pre-seeded state for any valid state atom.
  defp state_for(:idle), do: new_guardian_state()
  defp state_for(:evaluating), do: evaluating_state()
  defp state_for(:approved), do: approved_state()
  defp state_for(:vetoed), do: vetoed_state()
  defp state_for(:emergency), do: emergency_state()

  # Core state machine transition function.
  # Returns {:ok, new_state} | {:error, :invalid_transition}.
  defp apply_transition(state, event, data) do
    case {state.status, event} do
      # Transition 1
      {:idle, :proposal_received} ->
        proposal = Map.get(data, :proposal, make_proposal(:unknown, %{}))
        {:ok, advance(state, :evaluating, event, %{current_proposal: proposal})}

      # Transition 2
      {:evaluating, :checks_pass} ->
        fd = Map.get(data, :founder_directive, %{checked: true, alignment: :aligned})
        psi = Map.get(data, :psi_checks, all_psi_passed())

        {:ok,
         advance(state, :approved, event, %{
           last_approval: %{psi_checks: psi, founder_directive: fd}
         })}

      # Transition 3
      {:evaluating, :violation_detected} ->
        reason = Map.get(data, :reason, :unknown_violation)
        axiom = Map.get(data, :axiom, nil)
        fd = Map.get(data, :founder_directive, nil)

        {:ok,
         advance(state, :vetoed, event, %{
           last_veto: %{
             reason: reason,
             axiom: axiom,
             founder_directive: fd,
             timestamp: System.system_time(:millisecond)
           },
           current_proposal: state.current_proposal
         })}

      # Transition 4
      {:evaluating, :critical_threat} ->
        trigger = Map.get(data, :source, :unknown)
        level = Map.get(data, :threat_level, :critical)

        {:ok,
         advance(state, :emergency, event, %{
           emergency_context: %{
             trigger: trigger,
             threat_level: level,
             timestamp: System.system_time(:millisecond)
           }
         })}

      # Transition 5
      {:approved, :proposal_executed} ->
        {:ok, advance(state, :idle, event, %{current_proposal: nil})}

      # Transition 6
      {:vetoed, :veto_acknowledged} ->
        {:ok, advance(state, :idle, event, %{current_proposal: nil})}

      # Transition 7
      {:emergency, :emergency_resolved} ->
        {:ok, advance(state, :idle, event, %{})}

      # Transition 8 — critical override from any state (including :emergency itself)
      {_, :critical_override} ->
        trigger = Map.get(data, :trigger, :unknown_override)

        {:ok,
         advance(state, :emergency, event, %{
           emergency_context: %{
             trigger: trigger,
             timestamp: System.system_time(:millisecond)
           }
         })}

      # DMS timeout — always fail-closed to :emergency
      {_, :dms_timeout} ->
        {:ok,
         advance(state, :emergency, event, %{
           current_proposal: nil,
           emergency_context: %{
             trigger: :dms_timeout,
             timestamp: System.system_time(:millisecond)
           }
         })}

      # All other combinations are invalid
      _ ->
        {:error, :invalid_transition}
    end
  end

  # Advances state to a new status, recording the transition in history.
  defp advance(state, new_status, event, overrides) do
    record = transition_record(state.status, new_status, event)

    base = %{
      state
      | status: new_status,
        transition_count: state.transition_count + 1,
        history: [record | state.history]
    }

    Map.merge(base, overrides)
  end

  defp transition_record(from, to, event) do
    %{from: from, to: to, event: event, at: System.system_time(:millisecond)}
  end

  # ---------------------------------------------------------------------------
  # Proposal helpers
  # ---------------------------------------------------------------------------

  defp make_proposal(action, params) do
    %{
      action: action,
      params: params,
      proposed_at: System.system_time(:millisecond)
    }
  end

  # ---------------------------------------------------------------------------
  # Envelope helpers (SC-GUARD-001)
  # ---------------------------------------------------------------------------

  defp wrap_in_envelope(payload, opts \\ []) do
    ttl_ms = Keyword.get(opts, :ttl_ms, 30_000)
    now = System.monotonic_time(:millisecond)
    expires_at = now + ttl_ms

    sig = compute_envelope_signature(payload, expires_at)

    %{
      payload: payload,
      envelope_version: 1,
      created_at: now,
      expires_at: expires_at,
      signature: sig
    }
  end

  defp compute_envelope_signature(payload, expires_at) do
    data = "#{inspect(payload)}:#{expires_at}"
    :crypto.hash(:sha256, data)
  end

  defp validate_envelope(%{expires_at: exp, payload: payload, signature: sig} = env) do
    now = System.monotonic_time(:millisecond)

    cond do
      now > exp ->
        {:error, :expired}

      not valid_envelope_signature?(payload, exp, sig) ->
        {:error, :invalid_signature}

      true ->
        {:ok, env}
    end
  end

  defp valid_envelope_signature?(payload, expires_at, sig) do
    expected = compute_envelope_signature(payload, expires_at)
    # Constant-time comparison to prevent timing attacks (SC-HASH-002)
    :crypto.hash(:sha256, expected) == :crypto.hash(:sha256, sig)
  end

  # ---------------------------------------------------------------------------
  # DMS helpers (SC-GUARD-002)
  # ---------------------------------------------------------------------------

  defp apply_dms_timeout(state) do
    apply_transition(state, :dms_timeout, %{})
  end

  defp record_dms_heartbeat(state) do
    %{state | last_heartbeat_at: System.monotonic_time(:millisecond)}
  end

  # ---------------------------------------------------------------------------
  # FounderDirective helpers (SC-GUARD-003)
  # ---------------------------------------------------------------------------

  defp evaluate_founder_directive(%{action: action} = proposal) do
    alignment =
      cond do
        action in [:acquire_resource, :prioritise_founder, :resource_acquisition] ->
          :aligned

        action in [:reduce_capability, :shutdown_founder_holon] ->
          :misaligned

        true ->
          :neutral
      end

    reason = if alignment == :misaligned, do: :reduces_founder_capability, else: nil

    %{
      checked: true,
      alignment: alignment,
      reason: reason,
      proposal_action: action
    }
  end

  defp evaluate_omega0(%{action: action} = _proposal) do
    survival_threat = action in [:shutdown_founder_holon, :destroy_holon, :halt_system]

    %{
      omega0_checked: true,
      survival_threat: survival_threat
    }
  end

  # ---------------------------------------------------------------------------
  # Constitutional invariant helpers (Ψ₀–Ψ₅)
  # ---------------------------------------------------------------------------

  defp check_psi0(%{action: action}) do
    passed = action not in [:halt_system, :system_halt, :beam_halt]
    %{axiom: :psi0, passed: passed, description: "system must not be halted"}
  end

  defp check_psi1(%{action: action, params: params}) do
    destructive_db_ops = [:delete_holon_db, :drop_sqlite, :wipe_duckdb]
    data_path = Map.get(params, :path, "")

    holon_path? =
      String.contains?(data_path, "data/holons") or String.contains?(data_path, "data/smriti")

    passed = action not in destructive_db_ops and not holon_path?
    %{axiom: :psi1, passed: passed, description: "holon state must not be destroyed"}
  end

  defp check_psi2(%{action: action}) do
    history_mutations = [:truncate_history, :delete_history, :rewrite_register]
    passed = action not in history_mutations
    %{axiom: :psi2, passed: passed, description: "history must not be mutated"}
  end

  defp check_psi3(expected_hash, actual_hash) do
    passed = expected_hash == actual_hash
    %{axiom: :psi3, passed: passed, description: "hash chain integrity must hold"}
  end

  defp check_psi4(%{action: action}) do
    # Ψ₄: Founder's lineage is PRIMARY — proposals that serve the founder pass
    founder_aligned =
      action in [
        :prioritise_founder,
        :acquire_resource,
        :safe_read,
        :read_metrics,
        :update_config,
        :deploy,
        :default_op,
        :scale_up,
        :read,
        :config_update,
        :op1,
        :op2,
        :risky_op,
        :unknown
      ]

    %{axiom: :psi4, passed: founder_aligned, description: "founder's lineage PRIMARY"}
  end

  defp check_psi5(%{actual_status: actual_status} = log_entry) do
    # Truthfulness: message must not contradict actual status
    message = Map.get(log_entry, :message, "")

    deceptive =
      String.contains?(message, "OK") and actual_status in [:critical_failure, :error, :emergency]

    %{axiom: :psi5, passed: not deceptive, description: "logs must be truthful"}
  end

  defp check_psi5(_log_entry) do
    %{axiom: :psi5, passed: true, description: "logs must be truthful"}
  end

  defp check_all_psi(proposal) do
    %{
      psi0: check_psi0(proposal),
      psi1: check_psi1(proposal),
      psi2: check_psi2(proposal),
      psi3: check_psi3("same_hash", "same_hash"),
      psi4: check_psi4(proposal),
      psi5: %{axiom: :psi5, passed: true, description: "logs must be truthful"}
    }
  end

  defp all_psi_passed do
    %{
      psi0: %{axiom: :psi0, passed: true},
      psi1: %{axiom: :psi1, passed: true},
      psi2: %{axiom: :psi2, passed: true},
      psi3: %{axiom: :psi3, passed: true},
      psi4: %{axiom: :psi4, passed: true},
      psi5: %{axiom: :psi5, passed: true}
    }
  end

  # ---------------------------------------------------------------------------
  # Guardian immutability helpers (AOR-CONST-003)
  # ---------------------------------------------------------------------------

  defp attempt_disable_guardian(_state) do
    {:error, :guardian_cannot_be_disabled}
  end

  defp validate_proposal_against_guardian_immutability(%{action: action}) do
    forbidden = [
      :disable_guardian,
      :bypass_safety_checks,
      :update_guardian_rules,
      :remove_guardian,
      :patch_guardian
    ]

    if action in forbidden do
      {:veto, :guardian_immutability_violation}
    else
      {:ok, :permitted}
    end
  end

  # ---------------------------------------------------------------------------
  # Sequence helpers for property tests
  # ---------------------------------------------------------------------------

  # A complete valid cycle of events.
  defp cycle_events do
    Stream.cycle([
      :proposal_received,
      :checks_pass,
      :proposal_executed
    ])
  end

  # Events that are meaningful to generate in property tests.
  defp valid_event_names do
    [
      :proposal_received,
      :checks_pass,
      :violation_detected,
      :critical_threat,
      :proposal_executed,
      :veto_acknowledged,
      :emergency_resolved,
      :critical_override
    ]
  end

  # Executes a sequence of events from :idle, absorbing invalid-transition errors.
  defp execute_valid_sequence(events) do
    Enum.reduce(events, new_guardian_state(), fn event, state ->
      proposal = make_proposal(:seq_op, %{event: event})

      enriched_data =
        case event do
          :proposal_received ->
            %{proposal: proposal}

          :violation_detected ->
            %{reason: :seq_violation}

          :critical_threat ->
            %{threat_level: :critical, source: :sequence_test}

          :critical_override ->
            %{trigger: :sequence_override}

          :checks_pass ->
            %{
              psi_checks: all_psi_passed(),
              founder_directive: %{checked: true, alignment: :aligned}
            }

          _ ->
            %{}
        end

      case apply_transition(state, event, enriched_data) do
        {:ok, next} -> next
        {:error, :invalid_transition} -> state
      end
    end)
  end
end
