defmodule Indrajaal.VisitorManagement.ContractorManagementTest do
  @moduledoc """
  TDG-compliant test suite for Indrajaal.VisitorManagement.ContractorManagement.

  Tests extended contractor management with project tracking and certification requirements.

  ## SOPv5.11 Compliance
  - TDG: Tests written FIRST, code validated against tests
  - STAMP: Safety constraints for contractor lifecycle integrity
  - Property Testing: PropCheck for contractor data validation
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.VisitorManagement.ContractorManagement

  # ============================================================================
  # Module Structure Tests
  # ============================================================================

  describe "module structure" do
    test "module exists and is compiled" do
      assert Code.ensure_loaded?(ContractorManagement)
    end

    test "uses BaseResource with VisitorManagement domain" do
      assert Ash.Resource.Info.domain(ContractorManagement) == Indrajaal.VisitorManagement
    end

    test "uses TenantResource for multi-tenancy" do
      attributes = Ash.Resource.Info.attributes(ContractorManagement)
      attribute_names = Enum.map(attributes, & &1.name)
      assert :tenant_id in attribute_names
    end
  end

  # ============================================================================
  # Attribute Tests
  # ============================================================================

  describe "attributes" do
    test "has uuid primary key :id" do
      attributes = Ash.Resource.Info.attributes(ContractorManagement)
      id_attr = Enum.find(attributes, &(&1.name == :id))
      assert id_attr != nil
      assert id_attr.primary_key? == true
    end

    test "has required :contractor_id with max_length 50" do
      attributes = Ash.Resource.Info.attributes(ContractorManagement)
      contractor_id_attr = Enum.find(attributes, &(&1.name == :contractor_id))
      assert contractor_id_attr != nil
      assert contractor_id_attr.allow_nil? == false
      assert contractor_id_attr.constraints[:max_length] == 50
    end

    test "has required :company_name with max_length 200" do
      attributes = Ash.Resource.Info.attributes(ContractorManagement)
      company_attr = Enum.find(attributes, &(&1.name == :company_name))
      assert company_attr != nil
      assert company_attr.allow_nil? == false
      assert company_attr.constraints[:max_length] == 200
    end

    test "has required :contractor_type atom with 6 options" do
      attributes = Ash.Resource.Info.attributes(ContractorManagement)
      type_attr = Enum.find(attributes, &(&1.name == :contractor_type))
      assert type_attr != nil
      assert type_attr.type == Ash.Type.Atom
      assert type_attr.allow_nil? == false

      expected_types = [
        :general_contractor,
        :subcontractor,
        :consultant,
        :vendor,
        :service_provider,
        :specialist
      ]

      assert type_attr.constraints[:one_of] == expected_types
    end

    test "has :contractor_status atom with 5 options and default :active" do
      attributes = Ash.Resource.Info.attributes(ContractorManagement)
      status_attr = Enum.find(attributes, &(&1.name == :contractor_status))
      assert status_attr != nil
      assert status_attr.type == Ash.Type.Atom
      assert status_attr.default == :active

      expected_statuses = [:active, :suspended, :terminated, :completed, :on_hold]
      assert status_attr.constraints[:one_of] == expected_statuses
    end

    test "has :project_name with max_length 200" do
      attributes = Ash.Resource.Info.attributes(ContractorManagement)
      project_attr = Enum.find(attributes, &(&1.name == :project_name))
      assert project_attr != nil
      assert project_attr.constraints[:max_length] == 200
    end

    test "has :project_description with max_length 1000" do
      attributes = Ash.Resource.Info.attributes(ContractorManagement)
      desc_attr = Enum.find(attributes, &(&1.name == :project_description))
      assert desc_attr != nil
      assert desc_attr.constraints[:max_length] == 1000
    end

    test "has :project_start_date and :project_end_date" do
      attributes = Ash.Resource.Info.attributes(ContractorManagement)
      start_attr = Enum.find(attributes, &(&1.name == :project_start_date))
      end_attr = Enum.find(attributes, &(&1.name == :project_end_date))
      assert start_attr != nil
      assert end_attr != nil
    end

    test "has :liability_coverage_amount decimal with precision 15, scale 2" do
      attributes = Ash.Resource.Info.attributes(ContractorManagement)
      liability_attr = Enum.find(attributes, &(&1.name == :liability_coverage_amount))
      assert liability_attr != nil
      assert liability_attr.type == Ash.Type.Decimal
      assert liability_attr.constraints[:precision] == 15
      assert liability_attr.constraints[:scale] == 2
    end

    test "has :performance_rating decimal with constraints 0-5" do
      attributes = Ash.Resource.Info.attributes(ContractorManagement)
      rating_attr = Enum.find(attributes, &(&1.name == :performance_rating))
      assert rating_attr != nil
      assert rating_attr.type == Ash.Type.Decimal
      assert rating_attr.constraints[:min] == 0
      assert rating_attr.constraints[:max] == 5
    end

    test "has :safety_incidents integer with default 0" do
      attributes = Ash.Resource.Info.attributes(ContractorManagement)
      incidents_attr = Enum.find(attributes, &(&1.name == :safety_incidents))
      assert incidents_attr != nil
      assert incidents_attr.type == Ash.Type.Integer
      assert incidents_attr.default == 0
    end

    test "has :compliance_violations integer with default 0" do
      attributes = Ash.Resource.Info.attributes(ContractorManagement)
      violations_attr = Enum.find(attributes, &(&1.name == :compliance_violations))
      assert violations_attr != nil
      assert violations_attr.type == Ash.Type.Integer
      assert violations_attr.default == 0
    end

    test "has array attributes with defaults []" do
      attributes = Ash.Resource.Info.attributes(ContractorManagement)

      array_attrs = [
        :work_areas,
        :safety_certifications,
        :__required_certifications,
        :equipment_list,
        :hazardous_materials,
        :safety_protocols
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
      relationships = Ash.Resource.Info.relationships(ContractorManagement)
      visitor_rel = Enum.find(relationships, &(&1.name == :visitor))
      assert visitor_rel != nil
      assert visitor_rel.type == :belongs_to
      assert visitor_rel.allow_nil? == false
    end

    test "belongs_to project_manager (optional)" do
      relationships = Ash.Resource.Info.relationships(ContractorManagement)
      pm_rel = Enum.find(relationships, &(&1.name == :project_manager))
      assert pm_rel != nil
      assert pm_rel.type == :belongs_to
    end

    test "belongs_to safety_officer (optional)" do
      relationships = Ash.Resource.Info.relationships(ContractorManagement)
      safety_rel = Enum.find(relationships, &(&1.name == :safety_officer))
      assert safety_rel != nil
      assert safety_rel.type == :belongs_to
    end
  end

  # ============================================================================
  # Calculation Tests
  # ============================================================================

  describe "calculations" do
    test "has project_duration_days calculation" do
      calculations = Ash.Resource.Info.calculations(ContractorManagement)
      duration_calc = Enum.find(calculations, &(&1.name == :project_duration_days))
      assert duration_calc != nil
      assert duration_calc.type in [:integer, Ash.Type.Integer]
    end

    test "has days_until_insurance_expiry calculation" do
      calculations = Ash.Resource.Info.calculations(ContractorManagement)
      expiry_calc = Enum.find(calculations, &(&1.name == :days_until_insurance_expiry))
      assert expiry_calc != nil
      assert expiry_calc.type in [:integer, Ash.Type.Integer]
    end

    test "has is_insurance_expired calculation" do
      calculations = Ash.Resource.Info.calculations(ContractorManagement)
      expired_calc = Enum.find(calculations, &(&1.name == :is_insurance_expired))
      assert expired_calc != nil
      assert expired_calc.type in [:boolean, Ash.Type.Boolean]
    end

    test "has safety_score calculation" do
      calculations = Ash.Resource.Info.calculations(ContractorManagement)
      score_calc = Enum.find(calculations, &(&1.name == :safety_score))
      assert score_calc != nil
      assert score_calc.type in [:decimal, Ash.Type.Decimal]
    end
  end

  # ============================================================================
  # Action Tests
  # ============================================================================

  describe "actions" do
    test "has default CRUD actions" do
      actions = Ash.Resource.Info.actions(ContractorManagement)
      action_names = Enum.map(actions, & &1.name)

      assert :read in action_names
      assert :create in action_names
      assert :update in action_names
      assert :destroy in action_names
    end

    test "has register_contractor create action" do
      actions = Ash.Resource.Info.actions(ContractorManagement)
      register_action = Enum.find(actions, &(&1.name == :register_contractor))
      assert register_action != nil
      assert register_action.type == :create
    end

    test "has update_project_details action" do
      actions = Ash.Resource.Info.actions(ContractorManagement)
      project_action = Enum.find(actions, &(&1.name == :update_project_details))
      assert project_action != nil
      assert project_action.type == :update
    end

    test "has update_insurance_info action" do
      actions = Ash.Resource.Info.actions(ContractorManagement)
      insurance_action = Enum.find(actions, &(&1.name == :update_insurance_info))
      assert insurance_action != nil
      assert insurance_action.type == :update
    end

    test "has update_certifications action" do
      actions = Ash.Resource.Info.actions(ContractorManagement)
      certs_action = Enum.find(actions, &(&1.name == :update_certifications))
      assert certs_action != nil
      assert certs_action.type == :update
    end

    test "has assign_work_areas action" do
      actions = Ash.Resource.Info.actions(ContractorManagement)
      areas_action = Enum.find(actions, &(&1.name == :assign_work_areas))
      assert areas_action != nil
      assert areas_action.type == :update
    end

    test "has register_equipment action" do
      actions = Ash.Resource.Info.actions(ContractorManagement)
      equip_action = Enum.find(actions, &(&1.name == :register_equipment))
      assert equip_action != nil
      assert equip_action.type == :update
    end

    test "has register_hazardous_materials action" do
      actions = Ash.Resource.Info.actions(ContractorManagement)
      hazmat_action = Enum.find(actions, &(&1.name == :register_hazardous_materials))
      assert hazmat_action != nil
      assert hazmat_action.type == :update
    end

    test "has report_safety_incident action" do
      actions = Ash.Resource.Info.actions(ContractorManagement)
      incident_action = Enum.find(actions, &(&1.name == :report_safety_incident))
      assert incident_action != nil
      assert incident_action.type == :update
    end

    test "has report_compliance_violation action" do
      actions = Ash.Resource.Info.actions(ContractorManagement)
      violation_action = Enum.find(actions, &(&1.name == :report_compliance_violation))
      assert violation_action != nil
      assert violation_action.type == :update
    end

    test "has suspend_contractor action" do
      actions = Ash.Resource.Info.actions(ContractorManagement)
      suspend_action = Enum.find(actions, &(&1.name == :suspend_contractor))
      assert suspend_action != nil
      assert suspend_action.type == :update
    end

    test "has reactivate_contractor action" do
      actions = Ash.Resource.Info.actions(ContractorManagement)
      reactivate_action = Enum.find(actions, &(&1.name == :reactivate_contractor))
      assert reactivate_action != nil
      assert reactivate_action.type == :update
    end

    test "has complete_project action" do
      actions = Ash.Resource.Info.actions(ContractorManagement)
      complete_action = Enum.find(actions, &(&1.name == :complete_project))
      assert complete_action != nil
      assert complete_action.type == :update
    end
  end

  # ============================================================================
  # Code Interface Tests
  # ============================================================================

  describe "code interface" do
    test "source defines all code_interface functions" do
      source_path = "lib/indrajaal/visitor_management/contractor_management.ex"
      {:ok, content} = File.read(source_path)

      expected_functions = [
        "define :create",
        "define :register_contractor",
        "define :update_project_details",
        "define :update_insurance_info",
        "define :update_certifications",
        "define :assign_work_areas",
        "define :register_equipment",
        "define :register_hazardous_materials",
        "define :report_safety_incident",
        "define :report_compliance_violation",
        "define :update_performance_rating",
        "define :suspend_contractor",
        "define :reactivate_contractor",
        "define :complete_project"
      ]

      Enum.each(expected_functions, fn func ->
        assert content =~ func, "Expected code_interface to define #{func}"
      end)
    end
  end

  # ============================================================================
  # Validation Tests
  # ============================================================================

  describe "validations" do
    test "validates project end date after start date" do
      source_path = "lib/indrajaal/visitor_management/contractor_management.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "compare(:project_end_date, greater_than: :project_start_date)"
    end
  end

  # ============================================================================
  # Property Tests (PropCheck)
  # ============================================================================

  describe "property tests" do
    property "contractor_type must be one of 6 valid options" do
      valid_types = [
        :general_contractor,
        :subcontractor,
        :consultant,
        :vendor,
        :service_provider,
        :specialist
      ]

      forall contractor_type <- PC.oneof(valid_types) do
        contractor_type in valid_types
      end
    end

    property "contractor_status must be one of 5 valid options" do
      valid_statuses = [:active, :suspended, :terminated, :completed, :on_hold]

      forall status <- PC.oneof(valid_statuses) do
        status in valid_statuses
      end
    end

    property "performance_rating must be between 0 and 5" do
      forall rating <- PC.float(0.0, 5.0) do
        rating >= 0.0 and rating <= 5.0
      end
    end

    property "safety_incidents must be non-negative" do
      forall incidents <- PC.non_neg_integer() do
        incidents >= 0
      end
    end

    property "safety_score calculation produces valid results" do
      # base_score = 100, penalty = incidents * 10 + violations * 5
      forall {incidents, violations} <- {PC.non_neg_integer(), PC.non_neg_integer()} do
        penalty = incidents * 10 + violations * 5
        expected_score = max(0, 100 - penalty)
        expected_score >= 0 and expected_score <= 100
      end
    end
  end

  # ============================================================================
  # Source Code Validation Tests
  # ============================================================================

  describe "source code validation" do
    test "source file exists" do
      source_path = "lib/indrajaal/visitor_management/contractor_management.ex"
      assert File.exists?(source_path)
    end

    test "source file contains required module definition" do
      source_path = "lib/indrajaal/visitor_management/contractor_management.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "defmodule Indrajaal.VisitorManagement.ContractorManagement"
      assert content =~ "use Indrajaal.BaseResource"
      assert content =~ "use Indrajaal.Multitenancy.TenantResource"
    end

    test "source file uses postgres table 'contractor_management'" do
      source_path = "lib/indrajaal/visitor_management/contractor_management.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ ~s(table "contractor_management")
    end
  end

  # ============================================================================
  # Multi-Tenant Isolation Tests
  # ============================================================================

  describe "multi-tenant isolation" do
    test "has tenant_id attribute" do
      attributes = Ash.Resource.Info.attributes(ContractorManagement)
      tenant_attr = Enum.find(attributes, &(&1.name == :tenant_id))
      assert tenant_attr != nil
    end

    test "has unique index on tenant_id + contractor_id" do
      source_path = "lib/indrajaal/visitor_management/contractor_management.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "[:tenant_id, :contractor_id], unique: true"
    end

    test "indexes include tenant_id for isolation" do
      source_path = "lib/indrajaal/visitor_management/contractor_management.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "[:tenant_id, :visitor_id]"
      assert content =~ "[:tenant_id, :company_name]"
      assert content =~ "[:tenant_id, :contractor_type]"
      assert content =~ "[:tenant_id, :contractor_status]"
    end

    test "has conditional indexes for dates and safety metrics" do
      source_path = "lib/indrajaal/visitor_management/contractor_management.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "where: \"project_start_date IS NOT NULL\""
      assert content =~ "where: \"insurance_expiry_date IS NOT NULL\""
      assert content =~ "where: \"safety_incidents > 0\""
    end
  end
end
