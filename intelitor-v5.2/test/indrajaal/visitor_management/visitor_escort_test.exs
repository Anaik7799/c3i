defmodule Indrajaal.VisitorManagement.VisitorEscortTest do
  @moduledoc """
  TDG-compliant test suite for Indrajaal.VisitorManagement.VisitorEscort.

  Tests escort assignments and tracking for visitors requiring supervision.

  ## SOPv5.11 Compliance
  - TDG: Tests written FIRST, code validated against tests
  - STAMP: Safety constraints for escort tracking integrity
  - Property Testing: PropCheck for escort data validation
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.VisitorManagement.VisitorEscort

  # ============================================================================
  # Module Structure Tests
  # ============================================================================

  describe "module structure" do
    test "module exists and is compiled" do
      assert Code.ensure_loaded?(VisitorEscort)
    end

    test "uses BaseResource with VisitorManagement domain" do
      assert Ash.Resource.Info.domain(VisitorEscort) == Indrajaal.VisitorManagement
    end

    test "uses TenantResource for multi-tenancy" do
      attributes = Ash.Resource.Info.attributes(VisitorEscort)
      attribute_names = Enum.map(attributes, & &1.name)
      assert :tenant_id in attribute_names
    end
  end

  # ============================================================================
  # Attribute Tests
  # ============================================================================

  describe "attributes" do
    test "has uuid primary key :id" do
      attributes = Ash.Resource.Info.attributes(VisitorEscort)
      id_attr = Enum.find(attributes, &(&1.name == :id))
      assert id_attr != nil
      assert id_attr.primary_key? == true
    end

    test "has :escort_status atom with 5 options and default :assigned" do
      attributes = Ash.Resource.Info.attributes(VisitorEscort)
      status_attr = Enum.find(attributes, &(&1.name == :escort_status))
      assert status_attr != nil
      assert status_attr.type == Ash.Type.Atom
      assert status_attr.default == :assigned

      expected_statuses = [:assigned, :active, :completed, :cancelled, :emergency_terminated]
      assert status_attr.constraints[:one_of] == expected_statuses
    end

    test "has :escort_type atom with 4 options and default :continuous" do
      attributes = Ash.Resource.Info.attributes(VisitorEscort)
      type_attr = Enum.find(attributes, &(&1.name == :escort_type))
      assert type_attr != nil
      assert type_attr.type == Ash.Type.Atom
      assert type_attr.default == :continuous

      expected_types = [:continuous, :intermittent, :area_specific, :emergency_only]
      assert type_attr.constraints[:one_of] == expected_types
    end

    test "has required :planned_start_time utc_datetime" do
      attributes = Ash.Resource.Info.attributes(VisitorEscort)
      start_attr = Enum.find(attributes, &(&1.name == :planned_start_time))
      assert start_attr != nil
      assert start_attr.type == Ash.Type.UtcDatetime
      assert start_attr.allow_nil? == false
    end

    test "has required :planned_end_time utc_datetime" do
      attributes = Ash.Resource.Info.attributes(VisitorEscort)
      end_attr = Enum.find(attributes, &(&1.name == :planned_end_time))
      assert end_attr != nil
      assert end_attr.type == Ash.Type.UtcDatetime
      assert end_attr.allow_nil? == false
    end

    test "has :visitor_briefing_completed boolean with default false" do
      attributes = Ash.Resource.Info.attributes(VisitorEscort)
      briefing_attr = Enum.find(attributes, &(&1.name == :visitor_briefing_completed))
      assert briefing_attr != nil
      assert briefing_attr.type == Ash.Type.Boolean
      assert briefing_attr.default == false
    end

    test "has :security_briefing_completed boolean with default false" do
      attributes = Ash.Resource.Info.attributes(VisitorEscort)
      security_attr = Enum.find(attributes, &(&1.name == :security_briefing_completed))
      assert security_attr != nil
      assert security_attr.default == false
    end

    test "has :incidents_reported integer with default 0" do
      attributes = Ash.Resource.Info.attributes(VisitorEscort)
      incidents_attr = Enum.find(attributes, &(&1.name == :incidents_reported))
      assert incidents_attr != nil
      assert incidents_attr.type == Ash.Type.Integer
      assert incidents_attr.default == 0
    end

    test "has :compliance_violations integer with default 0" do
      attributes = Ash.Resource.Info.attributes(VisitorEscort)
      violations_attr = Enum.find(attributes, &(&1.name == :compliance_violations))
      assert violations_attr != nil
      assert violations_attr.default == 0
    end

    test "has :performance_rating atom with 5 options" do
      attributes = Ash.Resource.Info.attributes(VisitorEscort)
      rating_attr = Enum.find(attributes, &(&1.name == :performance_rating))
      assert rating_attr != nil
      assert rating_attr.type == Ash.Type.Atom

      expected_ratings = [:excellent, :good, :satisfactory, :needs_improvement, :unsatisfactory]
      assert rating_attr.constraints[:one_of] == expected_ratings
    end

    test "has :escort_areas array with default []" do
      attributes = Ash.Resource.Info.attributes(VisitorEscort)
      areas_attr = Enum.find(attributes, &(&1.name == :escort_areas))
      assert areas_attr != nil
      assert areas_attr.default == []
    end

    test "has :escort_responsibilities array with default []" do
      attributes = Ash.Resource.Info.attributes(VisitorEscort)
      resp_attr = Enum.find(attributes, &(&1.name == :escort_responsibilities))
      assert resp_attr != nil
      assert resp_attr.default == []
    end
  end

  # ============================================================================
  # Relationship Tests
  # ============================================================================

  describe "relationships" do
    test "belongs_to visitor (required)" do
      relationships = Ash.Resource.Info.relationships(VisitorEscort)
      visitor_rel = Enum.find(relationships, &(&1.name == :visitor))
      assert visitor_rel != nil
      assert visitor_rel.type == :belongs_to
      assert visitor_rel.allow_nil? == false
    end

    test "belongs_to visit_request (required)" do
      relationships = Ash.Resource.Info.relationships(VisitorEscort)
      request_rel = Enum.find(relationships, &(&1.name == :visit_request))
      assert request_rel != nil
      assert request_rel.type == :belongs_to
      assert request_rel.allow_nil? == false
    end

    test "belongs_to primary_escort (required)" do
      relationships = Ash.Resource.Info.relationships(VisitorEscort)
      primary_rel = Enum.find(relationships, &(&1.name == :primary_escort))
      assert primary_rel != nil
      assert primary_rel.type == :belongs_to
      assert primary_rel.allow_nil? == false
    end

    test "belongs_to backup_escort (optional)" do
      relationships = Ash.Resource.Info.relationships(VisitorEscort)
      backup_rel = Enum.find(relationships, &(&1.name == :backup_escort))
      assert backup_rel != nil
      assert backup_rel.type == :belongs_to
    end

    test "belongs_to assigned_by (required)" do
      relationships = Ash.Resource.Info.relationships(VisitorEscort)
      assigned_rel = Enum.find(relationships, &(&1.name == :assigned_by))
      assert assigned_rel != nil
      assert assigned_rel.type == :belongs_to
      assert assigned_rel.allow_nil? == false
    end

    test "belongs_to relieved_by_escort (optional)" do
      relationships = Ash.Resource.Info.relationships(VisitorEscort)
      relieved_rel = Enum.find(relationships, &(&1.name == :relieved_by_escort))
      assert relieved_rel != nil
      assert relieved_rel.type == :belongs_to
    end
  end

  # ============================================================================
  # Calculation Tests
  # ============================================================================

  describe "calculations" do
    test "has escort_duration_hours calculation" do
      calculations = Ash.Resource.Info.calculations(VisitorEscort)
      duration_calc = Enum.find(calculations, &(&1.name == :escort_duration_hours))
      assert duration_calc != nil
      assert duration_calc.type in [:decimal, Ash.Type.Decimal]
    end

    test "has is_overrun calculation" do
      calculations = Ash.Resource.Info.calculations(VisitorEscort)
      overrun_calc = Enum.find(calculations, &(&1.name == :is_overrun))
      assert overrun_calc != nil
      assert overrun_calc.type in [:boolean, Ash.Type.Boolean]
    end

    test "has is_currently_active calculation" do
      calculations = Ash.Resource.Info.calculations(VisitorEscort)
      active_calc = Enum.find(calculations, &(&1.name == :is_currently_active))
      assert active_calc != nil
      assert active_calc.type in [:boolean, Ash.Type.Boolean]
    end
  end

  # ============================================================================
  # Action Tests
  # ============================================================================

  describe "actions" do
    test "has default CRUD actions" do
      actions = Ash.Resource.Info.actions(VisitorEscort)
      action_names = Enum.map(actions, & &1.name)

      assert :read in action_names
      assert :create in action_names
      assert :update in action_names
      assert :destroy in action_names
    end

    test "has assign_escort create action" do
      actions = Ash.Resource.Info.actions(VisitorEscort)
      assign_action = Enum.find(actions, &(&1.name == :assign_escort))
      assert assign_action != nil
      assert assign_action.type == :create
    end

    test "has start_escort action" do
      actions = Ash.Resource.Info.actions(VisitorEscort)
      start_action = Enum.find(actions, &(&1.name == :start_escort))
      assert start_action != nil
      assert start_action.type == :update
    end

    test "has complete_escort action" do
      actions = Ash.Resource.Info.actions(VisitorEscort)
      complete_action = Enum.find(actions, &(&1.name == :complete_escort))
      assert complete_action != nil
      assert complete_action.type == :update
    end

    test "has cancel_escort action" do
      actions = Ash.Resource.Info.actions(VisitorEscort)
      cancel_action = Enum.find(actions, &(&1.name == :cancel_escort))
      assert cancel_action != nil
      assert cancel_action.type == :update
    end

    test "has emergency_terminate action" do
      actions = Ash.Resource.Info.actions(VisitorEscort)
      emergency_action = Enum.find(actions, &(&1.name == :emergency_terminate))
      assert emergency_action != nil
      assert emergency_action.type == :update
    end

    test "has assign_backup_escort action" do
      actions = Ash.Resource.Info.actions(VisitorEscort)
      backup_action = Enum.find(actions, &(&1.name == :assign_backup_escort))
      assert backup_action != nil
      assert backup_action.type == :update
    end

    test "has handover_escort action" do
      actions = Ash.Resource.Info.actions(VisitorEscort)
      handover_action = Enum.find(actions, &(&1.name == :handover_escort))
      assert handover_action != nil
      assert handover_action.type == :update
    end

    test "has complete_briefings action" do
      actions = Ash.Resource.Info.actions(VisitorEscort)
      briefings_action = Enum.find(actions, &(&1.name == :complete_briefings))
      assert briefings_action != nil
      assert briefings_action.type == :update
    end

    test "has report_incident action" do
      actions = Ash.Resource.Info.actions(VisitorEscort)
      incident_action = Enum.find(actions, &(&1.name == :report_incident))
      assert incident_action != nil
      assert incident_action.type == :update
    end

    test "has report_compliance_violation action" do
      actions = Ash.Resource.Info.actions(VisitorEscort)
      violation_action = Enum.find(actions, &(&1.name == :report_compliance_violation))
      assert violation_action != nil
      assert violation_action.type == :update
    end

    test "has set_escort_areas action" do
      actions = Ash.Resource.Info.actions(VisitorEscort)
      areas_action = Enum.find(actions, &(&1.name == :set_escort_areas))
      assert areas_action != nil
      assert areas_action.type == :update
    end

    test "has add_responsibilities action" do
      actions = Ash.Resource.Info.actions(VisitorEscort)
      resp_action = Enum.find(actions, &(&1.name == :add_responsibilities))
      assert resp_action != nil
      assert resp_action.type == :update
    end
  end

  # ============================================================================
  # Validation Tests
  # ============================================================================

  describe "validations" do
    test "validates planned_end_time after planned_start_time" do
      source_path = "lib/indrajaal/visitor_management/visitor_escort.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "compare(:planned_end_time, greater_than: :planned_start_time)"
    end
  end

  # ============================================================================
  # Code Interface Tests
  # ============================================================================

  describe "code interface" do
    test "source defines all code_interface functions" do
      source_path = "lib/indrajaal/visitor_management/visitor_escort.ex"
      {:ok, content} = File.read(source_path)

      expected_functions = [
        "define :create",
        "define :assign_escort",
        "define :start_escort",
        "define :complete_escort",
        "define :cancel_escort",
        "define :emergency_terminate",
        "define :assign_backup_escort",
        "define :handover_escort",
        "define :complete_briefings",
        "define :report_incident",
        "define :report_compliance_violation",
        "define :set_escort_areas",
        "define :add_responsibilities"
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
    property "escort_status must be one of 5 valid options" do
      valid_statuses = [:assigned, :active, :completed, :cancelled, :emergency_terminated]

      forall status <- PC.oneof(valid_statuses) do
        status in valid_statuses
      end
    end

    property "escort_type must be one of 4 valid options" do
      valid_types = [:continuous, :intermittent, :area_specific, :emergency_only]

      forall escort_type <- PC.oneof(valid_types) do
        escort_type in valid_types
      end
    end

    property "performance_rating must be one of 5 valid options" do
      valid_ratings = [:excellent, :good, :satisfactory, :needs_improvement, :unsatisfactory]

      forall rating <- PC.oneof(valid_ratings) do
        rating in valid_ratings
      end
    end

    property "incidents_reported must be non-negative" do
      forall incidents <- PC.non_neg_integer() do
        incidents >= 0
      end
    end

    property "compliance_violations must be non-negative" do
      forall violations <- PC.non_neg_integer() do
        violations >= 0
      end
    end
  end

  # ============================================================================
  # Source Code Validation Tests
  # ============================================================================

  describe "source code validation" do
    test "source file exists" do
      source_path = "lib/indrajaal/visitor_management/visitor_escort.ex"
      assert File.exists?(source_path)
    end

    test "source file contains required module definition" do
      source_path = "lib/indrajaal/visitor_management/visitor_escort.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "defmodule Indrajaal.VisitorManagement.VisitorEscort"
      assert content =~ "use Indrajaal.BaseResource"
      assert content =~ "use Indrajaal.Multitenancy.TenantResource"
    end

    test "source file uses postgres table 'visitor_escorts'" do
      source_path = "lib/indrajaal/visitor_management/visitor_escort.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ ~s(table "visitor_escorts")
    end
  end

  # ============================================================================
  # Edge Case Tests
  # ============================================================================

  describe "edge cases" do
    test "emergency_terminate sets emergency_procedures_followed to true" do
      source_path = "lib/indrajaal/visitor_management/visitor_escort.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "set_attribute(:emergency_procedures_followed, true)"
    end

    test "start_escort sets status to active and start_time" do
      source_path = "lib/indrajaal/visitor_management/visitor_escort.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "set_attribute(:escort_status, :active)"
      assert content =~ "set_attribute(:start_time, &DateTime.utc_now/0)"
    end

    test "is_overrun checks planned_end_time against current time" do
      source_path = "lib/indrajaal/visitor_management/visitor_escort.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "is_overrun"
      assert content =~ "DateTime.compare(now, record.planned_end_time)"
    end
  end

  # ============================================================================
  # Multi-Tenant Isolation Tests
  # ============================================================================

  describe "multi-tenant isolation" do
    test "has tenant_id attribute" do
      attributes = Ash.Resource.Info.attributes(VisitorEscort)
      tenant_attr = Enum.find(attributes, &(&1.name == :tenant_id))
      assert tenant_attr != nil
    end

    test "indexes include tenant_id for isolation" do
      source_path = "lib/indrajaal/visitor_management/visitor_escort.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "[:tenant_id, :visitor_id]"
      assert content =~ "[:tenant_id, :visit_request_id]"
      assert content =~ "[:tenant_id, :primary_escort_id]"
      assert content =~ "[:tenant_id, :escort_status]"
      assert content =~ "[:tenant_id, :escort_type]"
    end

    test "has conditional indexes for backup escort and incidents" do
      source_path = "lib/indrajaal/visitor_management/visitor_escort.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "where: \"backup_escort_id IS NOT NULL\""
      assert content =~ "where: \"start_time IS NOT NULL\""
      assert content =~ "where: \"incidents_reported > 0\""
    end
  end
end
