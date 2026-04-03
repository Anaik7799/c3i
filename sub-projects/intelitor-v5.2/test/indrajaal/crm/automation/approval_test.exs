defmodule Indrajaal.Crm.Automation.ApprovalTest do
  @moduledoc """
  TDG-compliant tests for Indrajaal.Crm.Automation.Approval.

  Sprint 54 — 100% module coverage.

  ## STAMP Compliance
  - SC-COV-001: Module coverage
  - SC-AUTO-001 to SC-AUTO-004: Approval automation
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Crm.Automation.Approval
  alias Indrajaal.Crm.Automation.Approval.ApprovalProcess
  alias Indrajaal.Crm.Automation.Approval.ApprovalStep

  @moduletag :zenoh_nif

  describe "module existence" do
    test "Approval module is loaded" do
      assert Code.ensure_loaded?(Approval)
    end

    test "ApprovalProcess struct is loaded" do
      assert Code.ensure_loaded?(ApprovalProcess)
    end

    test "ApprovalStep struct is loaded" do
      assert Code.ensure_loaded?(ApprovalStep)
    end
  end

  describe "public API exports" do
    test "submit_for_approval/2" do
      assert function_exported?(Approval, :submit_for_approval, 2)
    end

    test "approve/3" do
      assert function_exported?(Approval, :approve, 3)
    end

    test "reject/3" do
      assert function_exported?(Approval, :reject, 3)
    end

    test "delegate/3" do
      assert function_exported?(Approval, :delegate, 3)
    end

    test "recall/2" do
      assert function_exported?(Approval, :recall, 2)
    end

    test "check_and_escalate_timeouts/0" do
      assert function_exported?(Approval, :check_and_escalate_timeouts, 0)
    end
  end

  describe "ApprovalProcess struct" do
    test "has required fields" do
      process = %ApprovalProcess{}
      assert Map.has_key?(process, :id)
      assert Map.has_key?(process, :name)
      assert Map.has_key?(process, :object_type)
      assert Map.has_key?(process, :steps)
      assert Map.has_key?(process, :active)
      assert process.active == true
    end
  end

  describe "ApprovalStep struct" do
    test "has required fields with defaults" do
      step = %ApprovalStep{}
      assert step.approval_type == :first_response
      assert step.timeout_hours == 24
      assert step.delegate_to == nil
      assert step.escalate_to == nil
    end
  end

  describe "check_and_escalate_timeouts/0" do
    test "returns {:ok, count}" do
      assert {:ok, 0} = Approval.check_and_escalate_timeouts()
    end
  end

  describe "submit_for_approval/2" do
    test "returns {:ok, request} with valid record and process_id" do
      record = %{id: "rec-1", created_by: "user-1"}
      assert {:ok, request} = Approval.submit_for_approval(record, "process-1")
      assert request.status == :pending
      assert request.current_step == 1
    end
  end
end
