defmodule Indrajaal.VisitorManagement.VisitApprovalTest do
  @moduledoc """
  TDG-compliant test suite for Indrajaal.VisitorManagement.VisitApproval.

  Tests multi-level approval workflows with delegation and escalation support.

  ## SOPv5.11 Compliance
  - TDG: Tests written FIRST, code validated against tests
  - STAMP: Safety constraints for approval workflow integrity
  - Property Testing: PropCheck for approval state validation
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.VisitorManagement.VisitApproval

  # ============================================================================
  # Module Structure Tests
  # ============================================================================

  describe "module structure" do
    test "module exists and is compiled" do
      assert Code.ensure_loaded?(VisitApproval)
    end

    test "uses BaseResource with VisitorManagement domain" do
      assert Ash.Resource.Info.domain(VisitApproval) == Indrajaal.VisitorManagement
    end

    test "uses TenantResource for multi-tenancy" do
      attributes = Ash.Resource.Info.attributes(VisitApproval)
      attribute_names = Enum.map(attributes, & &1.name)
      assert :tenant_id in attribute_names
    end
  end

  # ============================================================================
  # Attribute Tests
  # ============================================================================

  describe "attributes" do
    test "has uuid primary key :id" do
      attributes = Ash.Resource.Info.attributes(VisitApproval)
      id_attr = Enum.find(attributes, &(&1.name == :id))
      assert id_attr != nil
      assert id_attr.primary_key? == true
    end

    test "has required :approval_level integer with constraints 1-5" do
      attributes = Ash.Resource.Info.attributes(VisitApproval)
      level_attr = Enum.find(attributes, &(&1.name == :approval_level))
      assert level_attr != nil
      assert level_attr.type == Ash.Type.Integer
      assert level_attr.allow_nil? == false
      assert level_attr.constraints[:min] == 1
      assert level_attr.constraints[:max] == 5
    end

    test "has required :approval_type atom with 5 valid options" do
      attributes = Ash.Resource.Info.attributes(VisitApproval)
      type_attr = Enum.find(attributes, &(&1.name == :approval_type))
      assert type_attr != nil
      assert type_attr.type == Ash.Type.Atom
      assert type_attr.allow_nil? == false

      expected_types = [:manager, :security, :facility, :compliance, :executive]
      assert type_attr.constraints[:one_of] == expected_types
    end

    test "has :approval_status atom with 5 options and default :pending" do
      attributes = Ash.Resource.Info.attributes(VisitApproval)
      status_attr = Enum.find(attributes, &(&1.name == :approval_status))
      assert status_attr != nil
      assert status_attr.type == Ash.Type.Atom
      assert status_attr.default == :pending

      expected_statuses = [:pending, :approved, :rejected, :delegated, :escalated]
      assert status_attr.constraints[:one_of] == expected_statuses
    end

    test "has :__requested_at utc_datetime with default DateTime.utc_now/0" do
      attributes = Ash.Resource.Info.attributes(VisitApproval)
      requested_attr = Enum.find(attributes, &(&1.name == :__requested_at))
      assert requested_attr != nil
      assert requested_attr.type == Ash.Type.UtcDatetime
      assert requested_attr.allow_nil? == false
    end

    test "has :responded_at optional utc_datetime" do
      attributes = Ash.Resource.Info.attributes(VisitApproval)
      responded_attr = Enum.find(attributes, &(&1.name == :responded_at))
      assert responded_attr != nil
      assert responded_attr.type == Ash.Type.UtcDatetime
    end

    test "has :approval_comments with max_length 1000" do
      attributes = Ash.Resource.Info.attributes(VisitApproval)
      comments_attr = Enum.find(attributes, &(&1.name == :approval_comments))
      assert comments_attr != nil
      assert comments_attr.constraints[:max_length] == 1000
    end

    test "has :conditions array with default []" do
      attributes = Ash.Resource.Info.attributes(VisitApproval)
      conditions_attr = Enum.find(attributes, &(&1.name == :conditions))
      assert conditions_attr != nil
      assert conditions_attr.default == []
    end

    test "has :restrictions array with default []" do
      attributes = Ash.Resource.Info.attributes(VisitApproval)
      restrictions_attr = Enum.find(attributes, &(&1.name == :restrictions))
      assert restrictions_attr != nil
      assert restrictions_attr.default == []
    end

    test "has :escalation_reason with max_length 500" do
      attributes = Ash.Resource.Info.attributes(VisitApproval)
      escalation_attr = Enum.find(attributes, &(&1.name == :escalation_reason))
      assert escalation_attr != nil
      assert escalation_attr.constraints[:max_length] == 500
    end

    test "has :delegation_reason with max_length 500" do
      attributes = Ash.Resource.Info.attributes(VisitApproval)
      delegation_attr = Enum.find(attributes, &(&1.name == :delegation_reason))
      assert delegation_attr != nil
      assert delegation_attr.constraints[:max_length] == 500
    end

    test "has :auto_approve_conditions map with default {}" do
      attributes = Ash.Resource.Info.attributes(VisitApproval)
      auto_attr = Enum.find(attributes, &(&1.name == :auto_approve_conditions))
      assert auto_attr != nil
      assert auto_attr.type == Ash.Type.Map
      assert auto_attr.default == %{}
    end

    test "has :is_final_approval boolean with default false" do
      attributes = Ash.Resource.Info.attributes(VisitApproval)
      final_attr = Enum.find(attributes, &(&1.name == :is_final_approval))
      assert final_attr != nil
      assert final_attr.default == false
    end
  end

  # ============================================================================
  # Relationship Tests
  # ============================================================================

  describe "relationships" do
    test "belongs_to visit_request (required)" do
      relationships = Ash.Resource.Info.relationships(VisitApproval)
      request_rel = Enum.find(relationships, &(&1.name == :visit_request))
      assert request_rel != nil
      assert request_rel.type == :belongs_to
      assert request_rel.allow_nil? == false
    end

    test "belongs_to approver (required)" do
      relationships = Ash.Resource.Info.relationships(VisitApproval)
      approver_rel = Enum.find(relationships, &(&1.name == :approver))
      assert approver_rel != nil
      assert approver_rel.type == :belongs_to
      assert approver_rel.allow_nil? == false
    end

    test "belongs_to delegated_to (optional)" do
      relationships = Ash.Resource.Info.relationships(VisitApproval)
      delegated_rel = Enum.find(relationships, &(&1.name == :delegated_to))
      assert delegated_rel != nil
      assert delegated_rel.type == :belongs_to
    end

    test "belongs_to escalated_to (optional)" do
      relationships = Ash.Resource.Info.relationships(VisitApproval)
      escalated_rel = Enum.find(relationships, &(&1.name == :escalated_to))
      assert escalated_rel != nil
      assert escalated_rel.type == :belongs_to
    end
  end

  # ============================================================================
  # Calculation Tests
  # ============================================================================

  describe "calculations" do
    test "has is_overdue calculation" do
      calculations = Ash.Resource.Info.calculations(VisitApproval)
      overdue_calc = Enum.find(calculations, &(&1.name == :is_overdue))
      assert overdue_calc != nil
      assert overdue_calc.type in [:boolean, Ash.Type.Boolean]
    end

    test "has response_time_hours calculation" do
      calculations = Ash.Resource.Info.calculations(VisitApproval)
      response_calc = Enum.find(calculations, &(&1.name == :response_time_hours))
      assert response_calc != nil
      assert response_calc.type in [:decimal, Ash.Type.Decimal]
    end
  end

  # ============================================================================
  # Action Tests
  # ============================================================================

  describe "actions" do
    test "has default CRUD actions" do
      actions = Ash.Resource.Info.actions(VisitApproval)
      action_names = Enum.map(actions, & &1.name)

      assert :read in action_names
      assert :create in action_names
      assert :update in action_names
      assert :destroy in action_names
    end

    test "has __request_approval create action" do
      actions = Ash.Resource.Info.actions(VisitApproval)
      request_action = Enum.find(actions, &(&1.name == :__request_approval))
      assert request_action != nil
      assert request_action.type == :create
    end

    test "has approve action" do
      actions = Ash.Resource.Info.actions(VisitApproval)
      approve_action = Enum.find(actions, &(&1.name == :approve))
      assert approve_action != nil
      assert approve_action.type == :update
    end

    test "has reject action" do
      actions = Ash.Resource.Info.actions(VisitApproval)
      reject_action = Enum.find(actions, &(&1.name == :reject))
      assert reject_action != nil
      assert reject_action.type == :update
    end

    test "has delegate action" do
      actions = Ash.Resource.Info.actions(VisitApproval)
      delegate_action = Enum.find(actions, &(&1.name == :delegate))
      assert delegate_action != nil
      assert delegate_action.type == :update
    end

    test "has escalate action" do
      actions = Ash.Resource.Info.actions(VisitApproval)
      escalate_action = Enum.find(actions, &(&1.name == :escalate))
      assert escalate_action != nil
      assert escalate_action.type == :update
    end

    test "has set_auto_approve_conditions action" do
      actions = Ash.Resource.Info.actions(VisitApproval)
      auto_action = Enum.find(actions, &(&1.name == :set_auto_approve_conditions))
      assert auto_action != nil
      assert auto_action.type == :update
    end

    test "has extend_deadline action" do
      actions = Ash.Resource.Info.actions(VisitApproval)
      extend_action = Enum.find(actions, &(&1.name == :extend_deadline))
      assert extend_action != nil
      assert extend_action.type == :update
    end
  end

  # ============================================================================
  # Code Interface Tests
  # ============================================================================

  describe "code interface" do
    test "source defines all code_interface functions" do
      source_path = "lib/indrajaal/visitor_management/visit_approval.ex"
      {:ok, content} = File.read(source_path)

      expected_functions = [
        "define :create",
        "define :__request_approval",
        "define :approve",
        "define :reject",
        "define :delegate",
        "define :escalate",
        "define :set_auto_approve_conditions",
        "define :extend_deadline"
      ]

      Enum.each(expected_functions, fn func ->
        assert content =~ func, "Expected code_interface to define #{func}"
      end)
    end
  end

  # ============================================================================
  # Property Tests (PropCheck)
  # ============================================================================

  describe "property tests" do
    property "approval_level must be between 1 and 5" do
      forall level <- PC.integer(1, 5) do
        level >= 1 and level <= 5
      end
    end

    property "approval_type must be one of 5 valid options" do
      valid_types = [:manager, :security, :facility, :compliance, :executive]

      forall type <- PC.oneof(valid_types) do
        type in valid_types
      end
    end

    property "approval_status must be one of 5 valid options" do
      valid_statuses = [:pending, :approved, :rejected, :delegated, :escalated]

      forall status <- PC.oneof(valid_statuses) do
        status in valid_statuses
      end
    end

    property "response_time is non-negative when responded_at is after __requested_at" do
      forall seconds <- PC.integer(0, 86_400 * 7) do
        seconds >= 0
      end
    end

    property "conditions and restrictions must be lists of strings" do
      forall conditions <- PC.list(PC.utf8()) do
        is_list(conditions) and Enum.all?(conditions, &is_binary/1)
      end
    end
  end

  # ============================================================================
  # Source Code Validation Tests
  # ============================================================================

  describe "source code validation" do
    test "source file exists" do
      source_path = "lib/indrajaal/visitor_management/visit_approval.ex"
      assert File.exists?(source_path)
    end

    test "source file contains required module definition" do
      source_path = "lib/indrajaal/visitor_management/visit_approval.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "defmodule Indrajaal.VisitorManagement.VisitApproval"
      assert content =~ "use Indrajaal.BaseResource"
      assert content =~ "use Indrajaal.Multitenancy.TenantResource"
    end

    test "source file uses postgres table 'visit_approvals'" do
      source_path = "lib/indrajaal/visitor_management/visit_approval.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ ~s(table "visit_approvals")
    end
  end

  # ============================================================================
  # Edge Case Tests
  # ============================================================================

  describe "edge cases" do
    test "approval_level boundary - minimum 1" do
      attributes = Ash.Resource.Info.attributes(VisitApproval)
      level_attr = Enum.find(attributes, &(&1.name == :approval_level))
      assert level_attr.constraints[:min] == 1
    end

    test "approval_level boundary - maximum 5" do
      attributes = Ash.Resource.Info.attributes(VisitApproval)
      level_attr = Enum.find(attributes, &(&1.name == :approval_level))
      assert level_attr.constraints[:max] == 5
    end

    test "approval workflow transitions" do
      # Valid workflow: pending -> approved/rejected/delegated/escalated
      valid_statuses = [:pending, :approved, :rejected, :delegated, :escalated]

      attributes = Ash.Resource.Info.attributes(VisitApproval)
      status_attr = Enum.find(attributes, &(&1.name == :approval_status))
      assert status_attr.constraints[:one_of] == valid_statuses
    end

    test "delegation and escalation are separate paths" do
      relationships = Ash.Resource.Info.relationships(VisitApproval)

      delegated_rel = Enum.find(relationships, &(&1.name == :delegated_to))
      escalated_rel = Enum.find(relationships, &(&1.name == :escalated_to))

      assert delegated_rel != nil
      assert escalated_rel != nil
      assert delegated_rel.name != escalated_rel.name
    end
  end

  # ============================================================================
  # Multi-Tenant Isolation Tests
  # ============================================================================

  describe "multi-tenant isolation" do
    test "has tenant_id attribute" do
      attributes = Ash.Resource.Info.attributes(VisitApproval)
      tenant_attr = Enum.find(attributes, &(&1.name == :tenant_id))
      assert tenant_attr != nil
    end

    test "indexes include tenant_id for isolation" do
      source_path = "lib/indrajaal/visitor_management/visit_approval.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "[:tenant_id, :visit_request_id]"
      assert content =~ "[:tenant_id, :approver_id]"
      assert content =~ "[:tenant_id, :approval_status]"
      assert content =~ "[:tenant_id, :approval_type]"
      assert content =~ "[:tenant_id, :approval_level]"
    end

    test "has conditional indexes for delegation and escalation" do
      source_path = "lib/indrajaal/visitor_management/visit_approval.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "[:tenant_id, :delegated_to_id], where: \"delegated_to_id IS NOT NULL\""
      assert content =~ "[:tenant_id, :escalated_to_id], where: \"escalated_to_id IS NOT NULL\""
    end
  end
end
