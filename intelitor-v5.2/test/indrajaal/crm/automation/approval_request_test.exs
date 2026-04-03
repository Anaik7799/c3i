defmodule Indrajaal.Crm.Automation.ApprovalRequestTest do
  @moduledoc """
  TDG comprehensive test suite for Indrajaal.Crm.ApprovalRequest.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation (Sprint 54)
  - FPPS Validation: 5-method consensus verification
  - Dual property testing: PropCheck (forall) + ExUnitProperties (check all)

  ## STAMP Safety Integration
  - SC-AUTO-004: Approval history is immutable — only appended, never overwritten
  - SC-DB-001: Uses BaseResource
  - SC-DB-005: UUID primary key

  ## Constitutional Verification
  - Ψ₀ Existence: Each approve/reject/escalate returns {:ok, _} or {:error, _}; system survives
  - Ψ₁ Regeneration: Approval records are stored in PostgreSQL via Ash; fully restorable
  - Ψ₃ Verification: History list grows monotonically — auditable chain

  ## Founder's Directive Alignment
  - Ω₀.3: Symbiotic binding — approval lifecycle tested end-to-end

  ## TPS 5-Level RCA Context
  - L1 Symptom: approve/reject/escalate return wrong status
  - L5 Root Cause: Ash update action not applied; guard clauses on status mis-match

  ## FMEA Analysis
  | Failure Mode            | S | O | D | RPN | Mitigation                  |
  |-------------------------|---|---|---|-----|-----------------------------|
  | Double-approve race     | 7 | 2 | 5 |  70 | Guard on status != :pending |
  | Escalate at final step  | 6 | 3 | 4 |  72 | Guard step >= total         |
  | Approvals list nil      | 5 | 2 | 3 |  30 | Default [] in attribute     |
  | Missing approver id     | 4 | 3 | 6 |  72 | approver map required       |
  """

  use Indrajaal.DataCase, async: false
  use PropCheck

  # EP-GEN-014: exclude PropCheck's check/2 so ExUnitProperties ExUnitProperties.check all() is unambiguous
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # MANDATORY: disambiguate generators (SC-PROP-023, EP-GEN-014)
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Crm.ApprovalRequest

  # SC-TEST-NIF-001: tag so test runner keeps SKIP_ZENOH_NIF=0
  @moduletag :zenoh_nif
  @moduletag :crm
  @moduletag :sprint_54

  # ---------------------------------------------------------------------------
  # Shared helpers
  # ---------------------------------------------------------------------------

  # Build a valid set of create attrs for a 2-step approval request.
  defp approval_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        process_id: "proc-#{System.unique_integer([:positive])}",
        record_id: Ash.UUID.generate(),
        record_type: :opportunity,
        current_step: 1,
        total_steps: 2,
        submitted_by: Ash.UUID.generate()
      },
      overrides
    )
  end

  # Persist a fresh pending request via the Ash code-interface create action.
  defp create_pending(overrides \\ %{}) do
    ApprovalRequest.create(approval_attrs(overrides))
  end

  # Build a minimal approver map with a stable id.
  defp approver(id \\ nil), do: %{id: id || Ash.UUID.generate()}

  # ---------------------------------------------------------------------------
  # approve/2,3
  # ---------------------------------------------------------------------------

  describe "approve/2,3" do
    test "advances step on intermediate approval (step < total_steps)" do
      {:ok, request} = create_pending(%{current_step: 1, total_steps: 3})
      approver = approver()

      assert {:ok, updated} = ApprovalRequest.approve(request, approver, "looks good")

      # Step advances, status remains :pending (more steps to go)
      assert updated.current_step == 2
      assert updated.status == :pending
    end

    test "marks status :approved when final step is approved" do
      # total_steps: 1 means step 1 IS the final step
      {:ok, request} = create_pending(%{current_step: 1, total_steps: 1})
      approver = approver()

      assert {:ok, approved} = ApprovalRequest.approve(request, approver, "all good")

      assert approved.status == :approved
      assert approved.completed_at != nil
    end

    test "appends an approval entry to the history" do
      {:ok, request} = create_pending(%{current_step: 1, total_steps: 2})
      approver = approver()

      {:ok, updated} = ApprovalRequest.approve(request, approver, "signed off")

      history = updated.approvals
      assert length(history) == 1
      [entry] = history
      assert entry.action == :approved
      assert entry.approver_id == approver.id
      assert entry.comments == "signed off"
      assert entry.step == 1
    end

    test "approve/2 defaults comments to empty string" do
      {:ok, request} = create_pending(%{current_step: 1, total_steps: 1})

      assert {:ok, approved} = ApprovalRequest.approve(request, approver())

      [entry] = approved.approvals
      assert entry.comments == ""
    end

    test "returns error when request is already :approved" do
      # Directly set status :approved on request struct to test guard clause.
      # We build a map rather than persisting a second time because the guard
      # operates on the first argument's :status field without a DB read.
      fake_approved = %{
        status: :approved,
        current_step: 1,
        total_steps: 1,
        approvals: []
      }

      assert {:error, msg} = ApprovalRequest.approve(fake_approved, approver())
      assert is_binary(msg)
      assert msg =~ "approved"
    end

    test "returns error when request is :rejected" do
      fake_rejected = %{
        status: :rejected,
        current_step: 1,
        total_steps: 1,
        approvals: []
      }

      assert {:error, msg} = ApprovalRequest.approve(fake_rejected, approver())
      assert msg =~ "rejected"
    end
  end

  # ---------------------------------------------------------------------------
  # reject/2,3
  # ---------------------------------------------------------------------------

  describe "reject/2,3" do
    test "sets status to :rejected and records history entry" do
      {:ok, request} = create_pending()
      approver = approver()

      assert {:ok, rejected} = ApprovalRequest.reject(request, approver, "not acceptable")

      assert rejected.status == :rejected
      assert rejected.completed_at != nil

      history = rejected.approvals
      assert length(history) == 1
      [entry] = history
      assert entry.action == :rejected
      assert entry.approver_id == approver.id
      assert entry.comments == "not acceptable"
    end

    test "reject/2 defaults comments to empty string" do
      {:ok, request} = create_pending()

      assert {:ok, rejected} = ApprovalRequest.reject(request, approver())

      [entry] = rejected.approvals
      assert entry.comments == ""
    end

    test "returns error when rejecting an already-approved request" do
      fake_approved = %{
        status: :approved,
        current_step: 1,
        total_steps: 1,
        approvals: []
      }

      assert {:error, msg} = ApprovalRequest.reject(fake_approved, approver())
      assert is_binary(msg)
      assert msg =~ "approved"
    end
  end

  # ---------------------------------------------------------------------------
  # escalate/2,3
  # ---------------------------------------------------------------------------

  describe "escalate/2,3" do
    test "advances step without changing status to :approved" do
      {:ok, request} = create_pending(%{current_step: 1, total_steps: 3})
      escalator = approver()

      assert {:ok, escalated} = ApprovalRequest.escalate(request, escalator, "timeout")

      assert escalated.current_step == 2
      assert escalated.status == :pending
    end

    test "appends an :escalated history entry" do
      {:ok, request} = create_pending(%{current_step: 1, total_steps: 2})
      escalator = approver()

      {:ok, escalated} = ApprovalRequest.escalate(request, escalator, "24h no response")

      [entry] = escalated.approvals
      assert entry.action == :escalated
      assert entry.approver_id == escalator.id
      assert entry.comments == "24h no response"
    end

    test "returns error when escalating at final step" do
      # current_step == total_steps means no further step to escalate to
      {:ok, request} = create_pending(%{current_step: 2, total_steps: 2})

      assert {:error, msg} = ApprovalRequest.escalate(request, approver(), "late")
      assert is_binary(msg)
      assert msg =~ "final step"
    end

    test "returns error when escalating a non-pending request" do
      fake_rejected = %{
        status: :rejected,
        current_step: 1,
        total_steps: 2,
        approvals: []
      }

      assert {:error, msg} = ApprovalRequest.escalate(fake_rejected, approver())
      assert msg =~ "rejected"
    end
  end

  # ---------------------------------------------------------------------------
  # Status transition sequence
  # ---------------------------------------------------------------------------

  describe "status transitions" do
    test "full two-step happy path: step 1 approve → step 2 approve → :approved" do
      {:ok, request} = create_pending(%{current_step: 1, total_steps: 2})
      approver_a = approver()
      approver_b = approver()

      # Step 1 approval — advances step, stays :pending
      {:ok, after_step1} = ApprovalRequest.approve(request, approver_a, "step 1 ok")
      assert after_step1.current_step == 2
      assert after_step1.status == :pending

      # Step 2 approval — final, transitions to :approved
      {:ok, final} = ApprovalRequest.approve(after_step1, approver_b, "step 2 ok")
      assert final.status == :approved
      assert length(final.approvals) == 2
    end

    test "escalate then approve completes the flow" do
      {:ok, request} = create_pending(%{current_step: 1, total_steps: 2})

      {:ok, escalated} = ApprovalRequest.escalate(request, approver(), "escalating")
      assert escalated.current_step == 2

      {:ok, final} = ApprovalRequest.approve(escalated, approver(), "final approval")
      assert final.status == :approved
    end
  end

  # ---------------------------------------------------------------------------
  # pending_for_user/2
  # ---------------------------------------------------------------------------

  describe "pending_for_user/2" do
    test "returns a list (possibly empty)" do
      user = %{id: Ash.UUID.generate()}
      result = ApprovalRequest.pending_for_user(user)
      assert is_list(result)
    end

    test "includes pending requests created by the query" do
      # Create a pending request; pending_for_user returns ALL pending
      {:ok, _} = create_pending()
      user = %{id: Ash.UUID.generate()}
      result = ApprovalRequest.pending_for_user(user)
      assert is_list(result)
      assert length(result) >= 1
    end
  end

  # ---------------------------------------------------------------------------
  # Property test (StreamData / ExUnitProperties — check all)
  # ---------------------------------------------------------------------------

  property "approve comment content is preserved exactly in history entry" do
    ExUnitProperties.check all(
                             comments <- SD.string(:printable, min_length: 0, max_length: 200),
                             total <- SD.integer(1..5)
                           ) do
      {:ok, request} = create_pending(%{current_step: 1, total_steps: total})
      {:ok, result} = ApprovalRequest.approve(request, approver(), comments)
      [entry | _] = result.approvals
      assert entry.comments == comments
    end
  end

  # ---------------------------------------------------------------------------
  # PropCheck property test (forall)
  # ---------------------------------------------------------------------------

  property "approve on any non-pending status always returns an error tuple" do
    # Start PropCheck GenServer (may already be started)
    _ = Application.ensure_all_started(:propcheck)

    forall status <- PC.oneof([:approved, :rejected, :recalled]) do
      fake_request = %{
        status: status,
        current_step: 1,
        total_steps: 2,
        approvals: []
      }

      match?({:error, _}, ApprovalRequest.approve(fake_request, %{id: "approver-1"}))
    end
  end
end
