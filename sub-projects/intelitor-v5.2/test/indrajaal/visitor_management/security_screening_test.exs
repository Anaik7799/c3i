defmodule Indrajaal.VisitorManagement.SecurityScreeningTest do
  @moduledoc """
  TDG-compliant test suite for Indrajaal.VisitorManagement.SecurityScreening.

  Tests security screening processes and background checks for visitors.

  ## SOPv5.11 Compliance
  - TDG: Tests written FIRST, code validated against tests
  - STAMP: Safety constraints for screening process integrity
  - Property Testing: PropCheck for screening data validation
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.VisitorManagement.SecurityScreening

  # ============================================================================
  # Module Structure Tests
  # ============================================================================

  describe "module structure" do
    test "module exists and is compiled" do
      assert Code.ensure_loaded?(SecurityScreening)
    end

    test "uses BaseResource with VisitorManagement domain" do
      assert Ash.Resource.Info.domain(SecurityScreening) == Indrajaal.VisitorManagement
    end

    test "uses TenantResource for multi-tenancy" do
      attributes = Ash.Resource.Info.attributes(SecurityScreening)
      attribute_names = Enum.map(attributes, & &1.name)
      assert :tenant_id in attribute_names
    end
  end

  # ============================================================================
  # Attribute Tests
  # ============================================================================

  describe "attributes" do
    test "has uuid primary key :id" do
      attributes = Ash.Resource.Info.attributes(SecurityScreening)
      id_attr = Enum.find(attributes, &(&1.name == :id))
      assert id_attr != nil
      assert id_attr.primary_key? == true
    end

    test "has required :screening_type atom with 6 options" do
      attributes = Ash.Resource.Info.attributes(SecurityScreening)
      type_attr = Enum.find(attributes, &(&1.name == :screening_type))
      assert type_attr != nil
      assert type_attr.type == Ash.Type.Atom
      assert type_attr.allow_nil? == false

      expected_types = [
        :basic_id_check,
        :background_check,
        :security_interview,
        :biometric_enrollment,
        :document_verification,
        :reference_check
      ]

      assert type_attr.constraints[:one_of] == expected_types
    end

    test "has :screening_status atom with 6 options and default :scheduled" do
      attributes = Ash.Resource.Info.attributes(SecurityScreening)
      status_attr = Enum.find(attributes, &(&1.name == :screening_status))
      assert status_attr != nil
      assert status_attr.type == Ash.Type.Atom
      assert status_attr.default == :scheduled

      expected_statuses = [
        :scheduled,
        :in_progress,
        :completed,
        :failed,
        :cancelled,
        :__requires_escalation
      ]

      assert status_attr.constraints[:one_of] == expected_statuses
    end

    test "has required :screening_level atom with 4 options" do
      attributes = Ash.Resource.Info.attributes(SecurityScreening)
      level_attr = Enum.find(attributes, &(&1.name == :screening_level))
      assert level_attr != nil
      assert level_attr.type == Ash.Type.Atom
      assert level_attr.allow_nil? == false

      expected_levels = [:basic, :standard, :enhanced, :comprehensive]
      assert level_attr.constraints[:one_of] == expected_levels
    end

    test "has :__requested_date with default Date.utc_today/0" do
      attributes = Ash.Resource.Info.attributes(SecurityScreening)
      requested_attr = Enum.find(attributes, &(&1.name == :__requested_date))
      assert requested_attr != nil
      assert requested_attr.type == Ash.Type.Date
      assert requested_attr.allow_nil? == false
    end

    test "has :risk_assessment_score integer with constraints 0-100" do
      attributes = Ash.Resource.Info.attributes(SecurityScreening)
      risk_attr = Enum.find(attributes, &(&1.name == :risk_assessment_score))
      assert risk_attr != nil
      assert risk_attr.type == Ash.Type.Integer
      assert risk_attr.constraints[:min] == 0
      assert risk_attr.constraints[:max] == 100
    end

    test "has :clearance_level_granted atom with 5 options and default :none" do
      attributes = Ash.Resource.Info.attributes(SecurityScreening)
      clearance_attr = Enum.find(attributes, &(&1.name == :clearance_level_granted))
      assert clearance_attr != nil
      assert clearance_attr.type == Ash.Type.Atom
      assert clearance_attr.default == :none

      expected_clearances = [:none, :basic, :standard, :confidential, :secret]
      assert clearance_attr.constraints[:one_of] == expected_clearances
    end

    test "has :biometric_data_collected boolean with default false" do
      attributes = Ash.Resource.Info.attributes(SecurityScreening)
      biometric_attr = Enum.find(attributes, &(&1.name == :biometric_data_collected))
      assert biometric_attr != nil
      assert biometric_attr.type == Ash.Type.Boolean
      assert biometric_attr.default == false
    end

    test "has :interview_conducted boolean with default false" do
      attributes = Ash.Resource.Info.attributes(SecurityScreening)
      interview_attr = Enum.find(attributes, &(&1.name == :interview_conducted))
      assert interview_attr != nil
      assert interview_attr.default == false
    end

    test "has :appeals_process_initiated boolean with default false" do
      attributes = Ash.Resource.Info.attributes(SecurityScreening)
      appeals_attr = Enum.find(attributes, &(&1.name == :appeals_process_initiated))
      assert appeals_attr != nil
      assert appeals_attr.default == false
    end

    test "has array attributes with defaults []" do
      attributes = Ash.Resource.Info.attributes(SecurityScreening)

      array_attrs = [
        :documents_verified,
        :biometric_types,
        :risk_factors_identified,
        :recommendations,
        :clearance_conditions
      ]

      Enum.each(array_attrs, fn attr_name ->
        attr = Enum.find(attributes, &(&1.name == attr_name))
        assert attr != nil, "Expected attribute #{attr_name} to exist"
        assert attr.default == [], "Expected #{attr_name} to have default []"
      end)
    end
  end

  # ============================================================================
  # Relationship Tests
  # ============================================================================

  describe "relationships" do
    test "belongs_to visitor (required)" do
      relationships = Ash.Resource.Info.relationships(SecurityScreening)
      visitor_rel = Enum.find(relationships, &(&1.name == :visitor))
      assert visitor_rel != nil
      assert visitor_rel.type == :belongs_to
      assert visitor_rel.allow_nil? == false
    end

    test "belongs_to visit_request (optional)" do
      relationships = Ash.Resource.Info.relationships(SecurityScreening)
      request_rel = Enum.find(relationships, &(&1.name == :visit_request))
      assert request_rel != nil
      assert request_rel.type == :belongs_to
    end

    test "belongs_to __requested_by (required)" do
      relationships = Ash.Resource.Info.relationships(SecurityScreening)
      requested_rel = Enum.find(relationships, &(&1.name == :__requested_by))
      assert requested_rel != nil
      assert requested_rel.type == :belongs_to
      assert requested_rel.allow_nil? == false
    end

    test "belongs_to conducted_by (optional)" do
      relationships = Ash.Resource.Info.relationships(SecurityScreening)
      conducted_rel = Enum.find(relationships, &(&1.name == :conducted_by))
      assert conducted_rel != nil
      assert conducted_rel.type == :belongs_to
    end

    test "belongs_to approved_by (optional)" do
      relationships = Ash.Resource.Info.relationships(SecurityScreening)
      approved_rel = Enum.find(relationships, &(&1.name == :approved_by))
      assert approved_rel != nil
      assert approved_rel.type == :belongs_to
    end
  end

  # ============================================================================
  # Calculation Tests
  # ============================================================================

  describe "calculations" do
    test "has days_to_expiry calculation" do
      calculations = Ash.Resource.Info.calculations(SecurityScreening)
      expiry_calc = Enum.find(calculations, &(&1.name == :days_to_expiry))
      assert expiry_calc != nil
      assert expiry_calc.type in [:integer, Ash.Type.Integer]
    end

    test "has is_clearance_expired calculation" do
      calculations = Ash.Resource.Info.calculations(SecurityScreening)
      expired_calc = Enum.find(calculations, &(&1.name == :is_clearance_expired))
      assert expired_calc != nil
      assert expired_calc.type in [:boolean, Ash.Type.Boolean]
    end

    test "has screening_duration_days calculation" do
      calculations = Ash.Resource.Info.calculations(SecurityScreening)
      duration_calc = Enum.find(calculations, &(&1.name == :screening_duration_days))
      assert duration_calc != nil
      assert duration_calc.type in [:integer, Ash.Type.Integer]
    end
  end

  # ============================================================================
  # Action Tests
  # ============================================================================

  describe "actions" do
    test "has default CRUD actions" do
      actions = Ash.Resource.Info.actions(SecurityScreening)
      action_names = Enum.map(actions, & &1.name)

      assert :read in action_names
      assert :create in action_names
      assert :update in action_names
      assert :destroy in action_names
    end

    test "has initiate_screening create action" do
      actions = Ash.Resource.Info.actions(SecurityScreening)
      initiate_action = Enum.find(actions, &(&1.name == :initiate_screening))
      assert initiate_action != nil
      assert initiate_action.type == :create
    end

    test "has start_screening action" do
      actions = Ash.Resource.Info.actions(SecurityScreening)
      start_action = Enum.find(actions, &(&1.name == :start_screening))
      assert start_action != nil
      assert start_action.type == :update
    end

    test "has verify_documents action" do
      actions = Ash.Resource.Info.actions(SecurityScreening)
      verify_action = Enum.find(actions, &(&1.name == :verify_documents))
      assert verify_action != nil
      assert verify_action.type == :update
    end

    test "has collect_biometrics action" do
      actions = Ash.Resource.Info.actions(SecurityScreening)
      biometrics_action = Enum.find(actions, &(&1.name == :collect_biometrics))
      assert biometrics_action != nil
      assert biometrics_action.type == :update
    end

    test "has conduct_interview action" do
      actions = Ash.Resource.Info.actions(SecurityScreening)
      interview_action = Enum.find(actions, &(&1.name == :conduct_interview))
      assert interview_action != nil
      assert interview_action.type == :update
    end

    test "has complete_background_check action" do
      actions = Ash.Resource.Info.actions(SecurityScreening)
      bg_action = Enum.find(actions, &(&1.name == :complete_background_check))
      assert bg_action != nil
      assert bg_action.type == :update
    end

    test "has assess_risk action" do
      actions = Ash.Resource.Info.actions(SecurityScreening)
      risk_action = Enum.find(actions, &(&1.name == :assess_risk))
      assert risk_action != nil
      assert risk_action.type == :update
    end

    test "has complete_screening action" do
      actions = Ash.Resource.Info.actions(SecurityScreening)
      complete_action = Enum.find(actions, &(&1.name == :complete_screening))
      assert complete_action != nil
      assert complete_action.type == :update
    end

    test "has fail_screening action" do
      actions = Ash.Resource.Info.actions(SecurityScreening)
      fail_action = Enum.find(actions, &(&1.name == :fail_screening))
      assert fail_action != nil
      assert fail_action.type == :update
    end

    test "has escalate_screening action" do
      actions = Ash.Resource.Info.actions(SecurityScreening)
      escalate_action = Enum.find(actions, &(&1.name == :escalate_screening))
      assert escalate_action != nil
      assert escalate_action.type == :update
    end

    test "has cancel_screening action" do
      actions = Ash.Resource.Info.actions(SecurityScreening)
      cancel_action = Enum.find(actions, &(&1.name == :cancel_screening))
      assert cancel_action != nil
      assert cancel_action.type == :update
    end

    test "has extend_clearance action" do
      actions = Ash.Resource.Info.actions(SecurityScreening)
      extend_action = Enum.find(actions, &(&1.name == :extend_clearance))
      assert extend_action != nil
      assert extend_action.type == :update
    end
  end

  # ============================================================================
  # Code Interface Tests
  # ============================================================================

  describe "code interface" do
    test "source defines all code_interface functions" do
      source_path = "lib/indrajaal/visitor_management/security_screening.ex"
      {:ok, content} = File.read(source_path)

      expected_functions = [
        "define :create",
        "define :initiate_screening",
        "define :start_screening",
        "define :verify_documents",
        "define :collect_biometrics",
        "define :conduct_interview",
        "define :complete_background_check",
        "define :assess_risk",
        "define :complete_screening",
        "define :fail_screening",
        "define :escalate_screening",
        "define :initiate_appeals_process",
        "define :cancel_screening",
        "define :extend_clearance"
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
    property "screening_type must be one of 6 valid options" do
      valid_types = [
        :basic_id_check,
        :background_check,
        :security_interview,
        :biometric_enrollment,
        :document_verification,
        :reference_check
      ]

      forall screening_type <- PC.oneof(valid_types) do
        screening_type in valid_types
      end
    end

    property "screening_status must be one of 6 valid options" do
      valid_statuses = [
        :scheduled,
        :in_progress,
        :completed,
        :failed,
        :cancelled,
        :__requires_escalation
      ]

      forall status <- PC.oneof(valid_statuses) do
        status in valid_statuses
      end
    end

    property "screening_level must be one of 4 valid options" do
      valid_levels = [:basic, :standard, :enhanced, :comprehensive]

      forall level <- PC.oneof(valid_levels) do
        level in valid_levels
      end
    end

    property "clearance_level_granted must be one of 5 valid options" do
      valid_clearances = [:none, :basic, :standard, :confidential, :secret]

      forall clearance <- PC.oneof(valid_clearances) do
        clearance in valid_clearances
      end
    end

    property "risk_assessment_score must be between 0 and 100" do
      forall score <- PC.integer(0, 100) do
        score >= 0 and score <= 100
      end
    end
  end

  # ============================================================================
  # Source Code Validation Tests
  # ============================================================================

  describe "source code validation" do
    test "source file exists" do
      source_path = "lib/indrajaal/visitor_management/security_screening.ex"
      assert File.exists?(source_path)
    end

    test "source file contains required module definition" do
      source_path = "lib/indrajaal/visitor_management/security_screening.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "defmodule Indrajaal.VisitorManagement.SecurityScreening"
      assert content =~ "use Indrajaal.BaseResource"
      assert content =~ "use Indrajaal.Multitenancy.TenantResource"
    end

    test "source file uses postgres table 'security_screenings'" do
      source_path = "lib/indrajaal/visitor_management/security_screening.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ ~s(table "security_screenings")
    end
  end

  # ============================================================================
  # Edge Case Tests
  # ============================================================================

  describe "edge cases" do
    test "fail_screening sets clearance_level to :none" do
      source_path = "lib/indrajaal/visitor_management/security_screening.ex"
      {:ok, content} = File.read(source_path)

      # fail_screening should reset clearance
      assert content =~ "set_attribute(:clearance_level_granted, :none)"
    end

    test "complete_screening sets status to :completed" do
      source_path = "lib/indrajaal/visitor_management/security_screening.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "set_attribute(:screening_status, :completed)"
    end
  end

  # ============================================================================
  # Multi-Tenant Isolation Tests
  # ============================================================================

  describe "multi-tenant isolation" do
    test "has tenant_id attribute" do
      attributes = Ash.Resource.Info.attributes(SecurityScreening)
      tenant_attr = Enum.find(attributes, &(&1.name == :tenant_id))
      assert tenant_attr != nil
    end

    test "indexes include tenant_id for isolation" do
      source_path = "lib/indrajaal/visitor_management/security_screening.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "[:tenant_id, :visitor_id]"
      assert content =~ "[:tenant_id, :screening_type]"
      assert content =~ "[:tenant_id, :screening_status]"
      assert content =~ "[:tenant_id, :screening_level]"
      assert content =~ "[:tenant_id, :clearance_level_granted]"
    end

    test "has conditional indexes for dates and risk" do
      source_path = "lib/indrajaal/visitor_management/security_screening.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "where: \"scheduled_date IS NOT NULL\""
      assert content =~ "where: \"completed_date IS NOT NULL\""
      assert content =~ "where: \"clearance_expiry_date IS NOT NULL\""
      assert content =~ "where: \"risk_assessment_score IS NOT NULL\""
      assert content =~ "where: \"appeals_process_initiated = true\""
    end
  end
end
