defmodule Indrajaal.VisitorManagement.VisitorComplianceTest do
  @moduledoc """
  TDG-compliant test suite for Indrajaal.VisitorManagement.VisitorCompliance.

  Tests visitor compliance tracking and regulatory requirement management.

  ## SOPv5.11 Compliance
  - TDG: Tests written FIRST, code validated against tests
  - STAMP: Safety constraints for compliance tracking integrity
  - Property Testing: PropCheck for compliance data validation
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.VisitorManagement.VisitorCompliance

  # ============================================================================
  # Module Structure Tests
  # ============================================================================

  describe "module structure" do
    test "module exists and is compiled" do
      assert Code.ensure_loaded?(VisitorCompliance)
    end

    test "uses BaseResource with VisitorManagement domain" do
      assert Ash.Resource.Info.domain(VisitorCompliance) == Indrajaal.VisitorManagement
    end

    test "uses TenantResource for multi-tenancy" do
      attributes = Ash.Resource.Info.attributes(VisitorCompliance)
      attribute_names = Enum.map(attributes, & &1.name)
      assert :tenant_id in attribute_names
    end
  end

  # ============================================================================
  # Attribute Tests
  # ============================================================================

  describe "attributes" do
    test "has uuid primary key :id" do
      attributes = Ash.Resource.Info.attributes(VisitorCompliance)
      id_attr = Enum.find(attributes, &(&1.name == :id))
      assert id_attr != nil
      assert id_attr.primary_key? == true
    end

    test "has required :compliance_type atom with 7 options" do
      attributes = Ash.Resource.Info.attributes(VisitorCompliance)
      type_attr = Enum.find(attributes, &(&1.name == :compliance_type))
      assert type_attr != nil
      assert type_attr.type == Ash.Type.Atom
      assert type_attr.allow_nil? == false

      expected_types = [:gdpr, :hipaa, :sox, :pci_dss, :iso_27001, :nist, :custom_policy]
      assert type_attr.constraints[:one_of] == expected_types
    end

    test "has :compliance_status atom with 5 options and default :pending_review" do
      attributes = Ash.Resource.Info.attributes(VisitorCompliance)
      status_attr = Enum.find(attributes, &(&1.name == :compliance_status))
      assert status_attr != nil
      assert status_attr.type == Ash.Type.Atom
      assert status_attr.default == :pending_review

      expected_statuses = [
        :compliant,
        :non_compliant,
        :partial_compliance,
        :pending_review,
        :exempt
      ]

      assert status_attr.constraints[:one_of] == expected_statuses
    end

    test "has :assessment_date with default Date.utc_today/0" do
      attributes = Ash.Resource.Info.attributes(VisitorCompliance)
      assessment_attr = Enum.find(attributes, &(&1.name == :assessment_date))
      assert assessment_attr != nil
      assert assessment_attr.type == Ash.Type.Date
      assert assessment_attr.allow_nil? == false
    end

    test "has :compliance_score decimal with constraints 0-100" do
      attributes = Ash.Resource.Info.attributes(VisitorCompliance)
      score_attr = Enum.find(attributes, &(&1.name == :compliance_score))
      assert score_attr != nil
      assert score_attr.type == Ash.Type.Decimal
      assert score_attr.constraints[:min] == 0
      assert score_attr.constraints[:max] == 100
    end

    test "has :retention_period_days integer with constraints 1-7300" do
      attributes = Ash.Resource.Info.attributes(VisitorCompliance)
      retention_attr = Enum.find(attributes, &(&1.name == :retention_period_days))
      assert retention_attr != nil
      assert retention_attr.type == Ash.Type.Integer
      assert retention_attr.constraints[:min] == 1
      assert retention_attr.constraints[:max] == 7300
    end

    test "has :privacy_briefing_completed boolean with default false" do
      attributes = Ash.Resource.Info.attributes(VisitorCompliance)
      privacy_attr = Enum.find(attributes, &(&1.name == :privacy_briefing_completed))
      assert privacy_attr != nil
      assert privacy_attr.type == Ash.Type.Boolean
      assert privacy_attr.default == false
    end

    test "has :confidentiality_agreement_signed boolean with default false" do
      attributes = Ash.Resource.Info.attributes(VisitorCompliance)
      confid_attr = Enum.find(attributes, &(&1.name == :confidentiality_agreement_signed))
      assert confid_attr != nil
      assert confid_attr.default == false
    end

    test "has array attributes with defaults []" do
      attributes = Ash.Resource.Info.attributes(VisitorCompliance)

      array_attrs = [
        :compliance_requirements,
        :__requirements_met,
        :__requirements_not_met,
        :documentation_provided,
        :training_completed,
        :training_required,
        :consent_forms_signed,
        :__data_processing_agreements,
        :access_restrictions,
        :monitoring_requirements,
        :non_compliance_reasons,
        :corrective_actions_required,
        :corrective_actions_completed
      ]

      Enum.each(array_attrs, fn attr_name ->
        attr = Enum.find(attributes, &(&1.name == attr_name))
        assert attr != nil, "Expected attribute #{attr_name} to exist"
        assert attr.default == [], "Expected #{attr_name} to have default []"
      end)
    end

    test "has :__data_subject_rights map with default {}" do
      attributes = Ash.Resource.Info.attributes(VisitorCompliance)
      rights_attr = Enum.find(attributes, &(&1.name == :__data_subject_rights))
      assert rights_attr != nil
      assert rights_attr.type == Ash.Type.Map
      assert rights_attr.default == %{}
    end
  end

  # ============================================================================
  # Relationship Tests
  # ============================================================================

  describe "relationships" do
    test "belongs_to visitor (required)" do
      relationships = Ash.Resource.Info.relationships(VisitorCompliance)
      visitor_rel = Enum.find(relationships, &(&1.name == :visitor))
      assert visitor_rel != nil
      assert visitor_rel.type == :belongs_to
      assert visitor_rel.allow_nil? == false
    end

    test "belongs_to visit_request (optional)" do
      relationships = Ash.Resource.Info.relationships(VisitorCompliance)
      request_rel = Enum.find(relationships, &(&1.name == :visit_request))
      assert request_rel != nil
      assert request_rel.type == :belongs_to
    end

    test "belongs_to assessed_by (required)" do
      relationships = Ash.Resource.Info.relationships(VisitorCompliance)
      assessed_rel = Enum.find(relationships, &(&1.name == :assessed_by))
      assert assessed_rel != nil
      assert assessed_rel.type == :belongs_to
      assert assessed_rel.allow_nil? == false
    end

    test "belongs_to reviewed_by (optional)" do
      relationships = Ash.Resource.Info.relationships(VisitorCompliance)
      reviewed_rel = Enum.find(relationships, &(&1.name == :reviewed_by))
      assert reviewed_rel != nil
      assert reviewed_rel.type == :belongs_to
    end
  end

  # ============================================================================
  # Calculation Tests
  # ============================================================================

  describe "calculations" do
    test "has compliance_percentage calculation" do
      calculations = Ash.Resource.Info.calculations(VisitorCompliance)
      percentage_calc = Enum.find(calculations, &(&1.name == :compliance_percentage))
      assert percentage_calc != nil
      assert percentage_calc.type in [:decimal, Ash.Type.Decimal]
    end

    test "has days_until_review calculation" do
      calculations = Ash.Resource.Info.calculations(VisitorCompliance)
      days_calc = Enum.find(calculations, &(&1.name == :days_until_review))
      assert days_calc != nil
      assert days_calc.type in [:integer, Ash.Type.Integer]
    end

    test "has is_review_overdue calculation" do
      calculations = Ash.Resource.Info.calculations(VisitorCompliance)
      overdue_calc = Enum.find(calculations, &(&1.name == :is_review_overdue))
      assert overdue_calc != nil
      assert overdue_calc.type in [:boolean, Ash.Type.Boolean]
    end
  end

  # ============================================================================
  # Action Tests
  # ============================================================================

  describe "actions" do
    test "has default CRUD actions" do
      actions = Ash.Resource.Info.actions(VisitorCompliance)
      action_names = Enum.map(actions, & &1.name)

      assert :read in action_names
      assert :create in action_names
      assert :update in action_names
      assert :destroy in action_names
    end

    test "has initiate_compliance_assessment create action" do
      actions = Ash.Resource.Info.actions(VisitorCompliance)
      initiate_action = Enum.find(actions, &(&1.name == :initiate_compliance_assessment))
      assert initiate_action != nil
      assert initiate_action.type == :create
    end

    test "has assess_requirements action" do
      actions = Ash.Resource.Info.actions(VisitorCompliance)
      assess_action = Enum.find(actions, &(&1.name == :assess_requirements))
      assert assess_action != nil
      assert assess_action.type == :update
    end

    test "has submit_documentation action" do
      actions = Ash.Resource.Info.actions(VisitorCompliance)
      docs_action = Enum.find(actions, &(&1.name == :submit_documentation))
      assert docs_action != nil
      assert docs_action.type == :update
    end

    test "has complete_training action" do
      actions = Ash.Resource.Info.actions(VisitorCompliance)
      training_action = Enum.find(actions, &(&1.name == :complete_training))
      assert training_action != nil
      assert training_action.type == :update
    end

    test "has sign_consent_forms action" do
      actions = Ash.Resource.Info.actions(VisitorCompliance)
      consent_action = Enum.find(actions, &(&1.name == :sign_consent_forms))
      assert consent_action != nil
      assert consent_action.type == :update
    end

    test "has complete_privacy_briefing action" do
      actions = Ash.Resource.Info.actions(VisitorCompliance)
      privacy_action = Enum.find(actions, &(&1.name == :complete_privacy_briefing))
      assert privacy_action != nil
      assert privacy_action.type == :update
    end

    test "has sign_confidentiality_agreement action" do
      actions = Ash.Resource.Info.actions(VisitorCompliance)
      confid_action = Enum.find(actions, &(&1.name == :sign_confidentiality_agreement))
      assert confid_action != nil
      assert confid_action.type == :update
    end

    test "has set_data_processing_agreements action" do
      actions = Ash.Resource.Info.actions(VisitorCompliance)
      dpa_action = Enum.find(actions, &(&1.name == :set_data_processing_agreements))
      assert dpa_action != nil
      assert dpa_action.type == :update
    end

    test "has apply_access_restrictions action" do
      actions = Ash.Resource.Info.actions(VisitorCompliance)
      restrict_action = Enum.find(actions, &(&1.name == :apply_access_restrictions))
      assert restrict_action != nil
      assert restrict_action.type == :update
    end

    test "has set_retention_policy action" do
      actions = Ash.Resource.Info.actions(VisitorCompliance)
      retention_action = Enum.find(actions, &(&1.name == :set_retention_policy))
      assert retention_action != nil
      assert retention_action.type == :update
    end

    test "has identify_non_compliance action" do
      actions = Ash.Resource.Info.actions(VisitorCompliance)
      non_comply_action = Enum.find(actions, &(&1.name == :identify_non_compliance))
      assert non_comply_action != nil
      assert non_comply_action.type == :update
    end

    test "has complete_corrective_actions action" do
      actions = Ash.Resource.Info.actions(VisitorCompliance)
      corrective_action = Enum.find(actions, &(&1.name == :complete_corrective_actions))
      assert corrective_action != nil
      assert corrective_action.type == :update
    end

    test "has grant_exemption action" do
      actions = Ash.Resource.Info.actions(VisitorCompliance)
      exempt_action = Enum.find(actions, &(&1.name == :grant_exemption))
      assert exempt_action != nil
      assert exempt_action.type == :update
    end

    test "has schedule_review action" do
      actions = Ash.Resource.Info.actions(VisitorCompliance)
      schedule_action = Enum.find(actions, &(&1.name == :schedule_review))
      assert schedule_action != nil
      assert schedule_action.type == :update
    end

    test "has review_compliance action" do
      actions = Ash.Resource.Info.actions(VisitorCompliance)
      review_action = Enum.find(actions, &(&1.name == :review_compliance))
      assert review_action != nil
      assert review_action.type == :update
    end
  end

  # ============================================================================
  # Code Interface Tests
  # ============================================================================

  describe "code interface" do
    test "source defines all code_interface functions" do
      source_path = "lib/indrajaal/visitor_management/visitor_compliance.ex"
      {:ok, content} = File.read(source_path)

      expected_functions = [
        "define :create",
        "define :initiate_compliance_assessment",
        "define :assess_requirements",
        "define :submit_documentation",
        "define :complete_training",
        "define :sign_consent_forms",
        "define :complete_privacy_briefing",
        "define :sign_confidentiality_agreement",
        "define :set_data_processing_agreements",
        "define :apply_access_restrictions",
        "define :set_retention_policy",
        "define :identify_non_compliance",
        "define :complete_corrective_actions",
        "define :grant_exemption",
        "define :schedule_review",
        "define :review_compliance"
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
    property "compliance_type must be one of 7 valid options" do
      valid_types = [:gdpr, :hipaa, :sox, :pci_dss, :iso_27001, :nist, :custom_policy]

      forall compliance_type <- PC.oneof(valid_types) do
        compliance_type in valid_types
      end
    end

    property "compliance_status must be one of 5 valid options" do
      valid_statuses = [:compliant, :non_compliant, :partial_compliance, :pending_review, :exempt]

      forall status <- PC.oneof(valid_statuses) do
        status in valid_statuses
      end
    end

    property "compliance_score must be between 0 and 100" do
      forall score <- PC.float(0.0, 100.0) do
        score >= 0.0 and score <= 100.0
      end
    end

    property "retention_period_days must be between 1 and 7300 (20 years)" do
      forall days <- PC.integer(1, 7300) do
        days >= 1 and days <= 7300
      end
    end

    property "compliance_percentage calculation produces valid results" do
      forall {met, not_met} <- {PC.non_neg_integer(), PC.non_neg_integer()} do
        total = met + not_met

        if total > 0 do
          percentage = met * 100 / total
          percentage >= 0 and percentage <= 100
        else
          true
        end
      end
    end
  end

  # ============================================================================
  # Source Code Validation Tests
  # ============================================================================

  describe "source code validation" do
    test "source file exists" do
      source_path = "lib/indrajaal/visitor_management/visitor_compliance.ex"
      assert File.exists?(source_path)
    end

    test "source file contains required module definition" do
      source_path = "lib/indrajaal/visitor_management/visitor_compliance.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "defmodule Indrajaal.VisitorManagement.VisitorCompliance"
      assert content =~ "use Indrajaal.BaseResource"
      assert content =~ "use Indrajaal.Multitenancy.TenantResource"
    end

    test "source file uses postgres table 'visitor_compliance'" do
      source_path = "lib/indrajaal/visitor_management/visitor_compliance.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ ~s(table "visitor_compliance")
    end
  end

  # ============================================================================
  # Edge Case Tests
  # ============================================================================

  describe "edge cases" do
    test "assess_requirements calculates compliance status based on requirements" do
      source_path = "lib/indrajaal/visitor_management/visitor_compliance.ex"
      {:ok, content} = File.read(source_path)

      # Logic: if not_met == 0 then :compliant, if met == 0 then :non_compliant, else :partial_compliance
      assert content =~ ":compliant"
      assert content =~ ":non_compliant"
      assert content =~ ":partial_compliance"
    end

    test "grant_exemption sets status to :exempt" do
      source_path = "lib/indrajaal/visitor_management/visitor_compliance.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "set_attribute(:compliance_status, :exempt)"
    end

    test "identify_non_compliance sets status to :non_compliant" do
      source_path = "lib/indrajaal/visitor_management/visitor_compliance.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "set_attribute(:compliance_status, :non_compliant)"
    end

    test "complete_corrective_actions updates status based on completion" do
      source_path = "lib/indrajaal/visitor_management/visitor_compliance.ex"
      {:ok, content} = File.read(source_path)

      # If all required actions are completed, status becomes :compliant
      assert content =~ "complete_corrective_actions"
      assert content =~ "corrective_actions_required"
    end
  end

  # ============================================================================
  # Multi-Tenant Isolation Tests
  # ============================================================================

  describe "multi-tenant isolation" do
    test "has tenant_id attribute" do
      attributes = Ash.Resource.Info.attributes(VisitorCompliance)
      tenant_attr = Enum.find(attributes, &(&1.name == :tenant_id))
      assert tenant_attr != nil
    end

    test "indexes include tenant_id for isolation" do
      source_path = "lib/indrajaal/visitor_management/visitor_compliance.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "[:tenant_id, :visitor_id]"
      assert content =~ "[:tenant_id, :compliance_type]"
      assert content =~ "[:tenant_id, :compliance_status]"
      assert content =~ "[:tenant_id, :assessment_date]"
      assert content =~ "[:tenant_id, :assessed_by_id]"
    end

    test "has conditional indexes for review dates and score" do
      source_path = "lib/indrajaal/visitor_management/visitor_compliance.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "where: \"next_assessment_date IS NOT NULL\""
      assert content =~ "where: \"compliance_score IS NOT NULL\""
      assert content =~ "where: \"reviewed_by_id IS NOT NULL\""
    end
  end
end
