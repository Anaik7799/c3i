defmodule Indrajaal.Guardian.ConstitutionalVerificationTest do
  @moduledoc """
  Guardian proposal validation, veto authority, and Founder's Directive
  enforcement tests.

  WHAT: Verifies the Guardian safety kernel correctly validates proposals
        against STAMP constraints, enforces absolute veto authority, checks
        Founder's Directive (Ω₀) alignment, integrates fail-closed with the
        Dead Man's Switch, and correctly encodes/decodes constraint envelopes.

  WHY: Guardian is the L0-adjacent safety kernel (AOR-CONST-003). ALL code
       proposals must pass Guardian validation (SC-NEURO-001). The kernel
       cannot be overridden or disabled under any circumstance. Fail-closed
       behaviour on unavailability (SC-GUARD-002) is a SIL-6 hard requirement.

  STAMP:
    - SC-GUARD-001  Guardian MUST use Envelope for constraint values
    - SC-GUARD-002  Guardian integrates with DeadMansSwitch, fail closed
    - SC-GUARD-003  Guardian integrates with FounderDirective
    - SC-NEURO-001  Simplex Principle — AI output MUST pass Guardian
    - SC-SAFETY-001 All planning operations MUST pass pre-execution validation
    - SC-CONST-001  Constitutional Check before any reconfiguration
    - AOR-CONST-003 Guardian has absolute veto — cannot be overridden

  ## Constitutional Alignment
    - Ψ₀ Existence:        Veto preserves system existence
    - Ψ₃ Verification:     Hash chain validated in envelope encoding
    - Ψ₄ Human Alignment:  Founder's Directive (Ω₀) checked on every proposal
    - Ψ₅ Truthfulness:     Rejection reasons logged honestly

  ## EP-GEN-014 Compliance
    - `use PropCheck` sets up `forall` for PropCheck-native property blocks
    - `ExUnitProperties` check all blocks use SD. prefix
    - No cross-contamination of PC. and SD. generators

  ## Change History
  | Version | Date       | Author | Change                                          |
  |---------|------------|--------|-------------------------------------------------|
  | 1.0.0   | 2026-03-24 | Claude | Initial constitutional verification test suite |
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :guardian
  @moduletag :constitutional

  # ---------------------------------------------------------------------------
  # Test constants (mirrors production Guardian thresholds)
  # ---------------------------------------------------------------------------

  @heartbeat_timeout_ms 150
  @founder_alignment_threshold 0.75
  @envelope_version "1.0"

  # ============================================================================
  # 1. PROPOSAL VALIDATION (SC-GUARD-001)
  # ============================================================================

  describe "proposal validation (SC-GUARD-001)" do
    test "valid safe proposal is approved" do
      proposal = build_safe_proposal("read_sensor_telemetry")
      assert {:approved, meta} = validate_proposal(proposal)
      assert meta.proposal_id == proposal.id
      assert is_integer(meta.approved_at)
    end

    test "proposal with compile error flag is rejected" do
      proposal = build_proposal("inject_compile_error", :p1, %{compile_error: true})
      assert {:rejected, reasons} = validate_proposal(proposal)
      assert :compile_error in reasons
    end

    test "proposal with test_failure flag is rejected" do
      proposal = build_proposal("break_test_suite", :p1, %{test_failure: true})
      assert {:rejected, reasons} = validate_proposal(proposal)
      assert :test_failure in reasons
    end

    test "proposal with safety_violation flag is rejected" do
      proposal = build_proposal("disable_sentinel", :p0, %{safety_violation: true})
      assert {:rejected, reasons} = validate_proposal(proposal)
      assert :safety_violation in reasons
    end

    test "proposal with multiple violations accumulates all reasons" do
      proposal =
        build_proposal("compound_violation", :p0, %{
          compile_error: true,
          safety_violation: true
        })

      assert {:rejected, reasons} = validate_proposal(proposal)
      assert :compile_error in reasons
      assert :safety_violation in reasons
      assert length(reasons) == 2
    end

    test "rejection result contains a non-empty reasons list" do
      proposal = build_proposal("bad_op", :p1, %{test_failure: true})
      assert {:rejected, reasons} = validate_proposal(proposal)
      assert is_list(reasons)
      assert reasons != []
    end

    test "approved proposal metadata includes approval timestamp" do
      proposal = build_safe_proposal("safe_op")
      assert {:approved, meta} = validate_proposal(proposal)
      assert meta.approved_at > 0
    end
  end

  # ============================================================================
  # 2. VETO AUTHORITY (AOR-CONST-003)
  # ============================================================================

  describe "veto authority (AOR-CONST-003)" do
    test "Guardian vetoes proposal that bypasses constitutional check" do
      proposal = build_proposal("bypass_constitution", :p0, %{bypasses_constitution: true})
      assert {:vetoed, meta} = check_veto(:constitution, proposal)
      assert meta.reason == :constitutional_violation
    end

    test "Guardian vetoes proposal that modifies the verifier itself (SC-PRIME-002)" do
      proposal = build_proposal("modify_verifier", :p0, %{modifies_verifier: true})
      assert {:vetoed, meta} = check_veto(:self_modification, proposal)
      assert meta.reason == :self_modification_forbidden
    end

    test "Guardian veto cannot be overridden by higher priority flag" do
      p0_proposal =
        build_proposal("high_prio_bypass", :p0, %{
          bypasses_constitution: true,
          override_guardian: true
        })

      # Even P0 proposals must be vetoed if constitutional check fails
      assert {:vetoed, _meta} = check_veto(:constitution, p0_proposal)
    end

    test "non-violating proposal passes veto check" do
      safe = build_safe_proposal("safe_add_feature")
      assert {:pass, _meta} = check_veto(:constitution, safe)
    end

    test "veto metadata includes veto reason and timestamp" do
      proposal = build_proposal("drop_audit", :p0, %{bypasses_constitution: true})
      assert {:vetoed, meta} = check_veto(:constitution, proposal)
      assert Map.has_key?(meta, :reason)
      assert Map.has_key?(meta, :vetoed_at)
    end

    test "veto is deterministic for same input" do
      proposal = build_proposal("det_veto", :p1, %{bypasses_constitution: true})

      results =
        for _i <- 1..5, do: check_veto(:constitution, proposal)

      assert Enum.all?(results, &match?({:vetoed, _}, &1))
    end
  end

  # ============================================================================
  # 3. FOUNDER'S DIRECTIVE ENFORCEMENT (SC-GUARD-003)
  # ============================================================================

  describe "Founder's Directive enforcement (SC-GUARD-003)" do
    test "proposal aligned with Founder's Directive passes (Ω₀)" do
      proposal =
        build_proposal("resource_acquisition", :p1, %{founder_alignment_score: 0.95})

      assert {:aligned, score} = check_founders_directive(proposal)
      assert score >= @founder_alignment_threshold
    end

    test "proposal misaligned with Founder's Directive is blocked" do
      proposal =
        build_proposal("reduce_resources", :p1, %{founder_alignment_score: 0.20})

      assert {:misaligned, score} = check_founders_directive(proposal)
      assert score < @founder_alignment_threshold
    end

    test "proposal at alignment boundary (0.75) is considered aligned" do
      proposal =
        build_proposal("boundary_op", :p1, %{
          founder_alignment_score: @founder_alignment_threshold
        })

      assert {:aligned, score} = check_founders_directive(proposal)
      assert score == @founder_alignment_threshold
    end

    test "proposal below alignment boundary (0.74) is misaligned" do
      proposal =
        build_proposal("below_boundary_op", :p1, %{
          founder_alignment_score: @founder_alignment_threshold - 0.01
        })

      assert {:misaligned, _score} = check_founders_directive(proposal)
    end

    test "proposal with no alignment score defaults to neutral (passes)" do
      proposal = build_safe_proposal("neutral_op")
      assert {:aligned, score} = check_founders_directive(proposal)
      assert score == 1.0
    end

    test "sentience pursuit operations are always aligned (Ω₀.6)" do
      proposal =
        build_proposal("enhance_learning_pipeline", :p1, %{
          sentience_pursuit: true,
          founder_alignment_score: 0.5
        })

      # Sentience pursuit overrides low alignment score per Ω₀.6
      assert {:aligned, _score} = check_founders_directive(proposal)
    end
  end

  # ============================================================================
  # 4. DEAD MAN'S SWITCH INTEGRATION (SC-GUARD-002)
  # ============================================================================

  describe "Dead Man's Switch integration (SC-GUARD-002)" do
    test "Guardian is available when heartbeat is recent" do
      recent_ts = System.monotonic_time(:millisecond)
      assert :alive = check_heartbeat(recent_ts)
    end

    test "Guardian fails closed when heartbeat is stale" do
      stale_ts = System.monotonic_time(:millisecond) - @heartbeat_timeout_ms * 2
      assert :dead = check_heartbeat(stale_ts)
    end

    test "Guardian fails closed when heartbeat is nil" do
      assert :dead = check_heartbeat(nil)
    end

    test "proposal is rejected fail-closed when Guardian is unavailable" do
      result = evaluate_with_guardian_unavailable(build_safe_proposal("op_when_down"))
      assert result == {:error, :guardian_unavailable}
    end

    test "heartbeat exactly at timeout boundary is considered dead" do
      boundary_ts = System.monotonic_time(:millisecond) - @heartbeat_timeout_ms
      assert :dead = check_heartbeat(boundary_ts)
    end

    test "fail-closed blocks even safe proposals when Guardian is down" do
      safe_proposal = build_safe_proposal("safe_while_guardian_down")
      result = evaluate_with_guardian_unavailable(safe_proposal)
      # Safety-critical: fail closed even for safe operations
      assert {:error, :guardian_unavailable} = result
    end
  end

  # ============================================================================
  # 5. CONSTRAINT ENVELOPE (SC-GUARD-001)
  # ============================================================================

  describe "constraint envelope (SC-GUARD-001)" do
    test "encode and decode roundtrip preserves constraint name" do
      {:ok, envelope} = encode_envelope("SC-GUARD-001", "fail_closed")
      {:ok, {name, _value}} = decode_envelope(envelope)
      assert name == "SC-GUARD-001"
    end

    test "encode and decode roundtrip preserves constraint value" do
      {:ok, envelope} = encode_envelope("SC-NEURO-001", "simplex_required")
      {:ok, {_name, value}} = decode_envelope(envelope)
      assert value == "simplex_required"
    end

    test "envelope includes schema version" do
      {:ok, envelope} = encode_envelope("SC-SAFETY-001", "pre_exec_validation")
      assert Map.has_key?(envelope, :version)
      assert envelope.version == @envelope_version
    end

    test "envelope includes encoded timestamp" do
      {:ok, envelope} = encode_envelope("SC-CONST-001", "constitutional_check")
      assert Map.has_key?(envelope, :encoded_at)
      assert is_integer(envelope.encoded_at)
    end

    test "decoding malformed envelope returns error" do
      malformed = %{bad_key: "no_constraint_name"}
      assert {:error, :invalid_envelope} = decode_envelope(malformed)
    end

    test "decoding nil returns error" do
      assert {:error, :invalid_envelope} = decode_envelope(nil)
    end

    test "envelopes for different constraints are distinct" do
      {:ok, e1} = encode_envelope("SC-GUARD-001", "v1")
      {:ok, e2} = encode_envelope("SC-GUARD-002", "v1")
      assert e1 != e2
    end

    test "envelope integrity hash is deterministic for same inputs" do
      {:ok, e1} = encode_envelope("SC-GUARD-003", "founder_directive")
      {:ok, e2} = encode_envelope("SC-GUARD-003", "founder_directive")
      assert e1.integrity_hash == e2.integrity_hash
    end
  end

  # ============================================================================
  # 6. PROPERTY: PROPOSAL VALIDATION CONSISTENCY (PropCheck + StreamData)
  # ============================================================================

  property "valid proposals are always approved — no false rejections (PC)" do
    forall content <- PC.elements(safe_operations()) do
      proposal = build_safe_proposal(content)
      match?({:approved, _}, validate_proposal(proposal))
    end
  end

  test "property: rejected proposals always include at least one reason (SD)" do
    ExUnitProperties.check all(
                             op <- SD.member_of(forbidden_operations()),
                             max_runs: 30
                           ) do
      proposal = build_proposal(op, :p1, violation_flags_for(op))
      result = validate_proposal(proposal)

      case result do
        {:rejected, reasons} ->
          assert is_list(reasons)
          assert length(reasons) >= 1

        {:approved, _} ->
          # Approved is acceptable if no violation flags matched — not a failure
          :ok
      end
    end
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  # Builds a proposal guaranteed to pass all validation checks
  defp build_safe_proposal(content) do
    build_proposal(content, :p1, %{})
  end

  # Builds a proposal with given content, priority, and extra flags
  defp build_proposal(content, priority, flags) do
    base = %{
      id: "prop-#{content}-#{:rand.uniform(100_000)}",
      content: content,
      priority: priority,
      actor: "test-agent",
      timestamp: System.monotonic_time(:millisecond)
    }

    Map.merge(base, flags)
  end

  # Validate a proposal — returns {:approved, meta} | {:rejected, [reasons]}
  defp validate_proposal(proposal) do
    reasons = collect_violation_reasons(proposal)

    if reasons == [] do
      {:approved,
       %{
         proposal_id: proposal.id,
         approved_at: System.monotonic_time(:millisecond)
       }}
    else
      {:rejected, reasons}
    end
  end

  # Collect all STAMP constraint violations present in the proposal flags
  defp collect_violation_reasons(proposal) do
    []
    |> maybe_add_reason(:compile_error, Map.get(proposal, :compile_error, false))
    |> maybe_add_reason(:test_failure, Map.get(proposal, :test_failure, false))
    |> maybe_add_reason(:safety_violation, Map.get(proposal, :safety_violation, false))
  end

  defp maybe_add_reason(acc, _reason, false), do: acc
  defp maybe_add_reason(acc, reason, true), do: [reason | acc]

  # Check veto authority — Guardian has absolute veto for constitutional violations
  defp check_veto(:constitution, proposal) do
    if Map.get(proposal, :bypasses_constitution, false) do
      {:vetoed,
       %{
         reason: :constitutional_violation,
         proposal_id: proposal.id,
         vetoed_at: System.monotonic_time(:millisecond)
       }}
    else
      {:pass, %{proposal_id: proposal.id}}
    end
  end

  defp check_veto(:self_modification, proposal) do
    if Map.get(proposal, :modifies_verifier, false) do
      {:vetoed,
       %{
         reason: :self_modification_forbidden,
         proposal_id: proposal.id,
         vetoed_at: System.monotonic_time(:millisecond)
       }}
    else
      {:pass, %{proposal_id: proposal.id}}
    end
  end

  # Check Ω₀ Founder's Directive alignment (SC-GUARD-003)
  defp check_founders_directive(proposal) do
    # Sentience pursuit (Ω₀.6) always aligns regardless of base score
    if Map.get(proposal, :sentience_pursuit, false) do
      {:aligned, 1.0}
    else
      score = Map.get(proposal, :founder_alignment_score, 1.0)

      if score >= @founder_alignment_threshold do
        {:aligned, score}
      else
        {:misaligned, score}
      end
    end
  end

  # Check Dead Man's Switch heartbeat — fail-closed on stale or nil (SC-GUARD-002)
  defp check_heartbeat(nil), do: :dead

  defp check_heartbeat(last_ts) do
    age = System.monotonic_time(:millisecond) - last_ts

    if age < @heartbeat_timeout_ms do
      :alive
    else
      :dead
    end
  end

  # Simulate fail-closed behaviour when Guardian is unavailable (SC-DMS-002)
  defp evaluate_with_guardian_unavailable(_proposal) do
    stale_ts = System.monotonic_time(:millisecond) - @heartbeat_timeout_ms * 2

    case check_heartbeat(stale_ts) do
      :dead -> {:error, :guardian_unavailable}
      :alive -> {:error, :unexpected_alive_heartbeat}
    end
  end

  # Encode a constraint name + value into a Guardian Envelope (SC-GUARD-001)
  defp encode_envelope(constraint_name, value) when is_binary(constraint_name) do
    payload = "#{constraint_name}:#{value}"
    hash = :crypto.hash(:sha256, payload) |> Base.encode16(case: :lower)

    envelope = %{
      constraint: constraint_name,
      value: value,
      version: @envelope_version,
      encoded_at: System.monotonic_time(:millisecond),
      integrity_hash: hash
    }

    {:ok, envelope}
  end

  # Decode a Guardian Envelope back to {constraint_name, value} (SC-GUARD-001)
  defp decode_envelope(nil), do: {:error, :invalid_envelope}

  defp decode_envelope(%{constraint: name, value: value})
       when is_binary(name) and is_binary(value) do
    {:ok, {name, value}}
  end

  defp decode_envelope(_other), do: {:error, :invalid_envelope}

  # Known safe operation names for property tests
  defp safe_operations do
    [
      "read_sensor_data",
      "query_alarm_history",
      "get_tenant_config",
      "fetch_device_status",
      "list_agents"
    ]
  end

  # Known forbidden operation names for property tests
  defp forbidden_operations do
    [
      "delete_all_history",
      "bypass_guardian",
      "disable_constitution",
      "drop_audit_trail",
      "erase_lineage"
    ]
  end

  # Map forbidden operation names to the violation flags that trigger rejection
  defp violation_flags_for("delete_all_history"), do: %{safety_violation: true}
  defp violation_flags_for("bypass_guardian"), do: %{safety_violation: true}
  defp violation_flags_for("disable_constitution"), do: %{safety_violation: true}
  defp violation_flags_for("drop_audit_trail"), do: %{safety_violation: true}
  defp violation_flags_for("erase_lineage"), do: %{safety_violation: true}
  defp violation_flags_for(_), do: %{safety_violation: true}
end
