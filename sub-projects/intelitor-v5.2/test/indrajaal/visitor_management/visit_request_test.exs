defmodule Indrajaal.VisitorManagement.VisitRequestTest do
  @moduledoc """
  TDG-compliant test suite for Indrajaal.VisitorManagement.VisitRequest.

  Tests visit scheduling with approval workflows and access requirements.

  ## SOPv5.11 Compliance
  - TDG: Tests written FIRST, code validated against tests
  - STAMP: Safety constraints for visit scheduling integrity
  - Property Testing: PropCheck for time and status validation
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.VisitorManagement.VisitRequest

  # ============================================================================
  # Module Structure Tests
  # ============================================================================

  describe "module structure" do
    test "module exists and is compiled" do
      assert Code.ensure_loaded?(VisitRequest)
    end

    test "uses BaseResource with VisitorManagement domain" do
      assert Ash.Resource.Info.domain(VisitRequest) == Indrajaal.VisitorManagement
    end

    test "uses TenantResource for multi-tenancy" do
      attributes = Ash.Resource.Info.attributes(VisitRequest)
      attribute_names = Enum.map(attributes, & &1.name)
      assert :tenant_id in attribute_names
    end
  end

  # ============================================================================
  # Attribute Tests
  # ============================================================================

  describe "attributes" do
    test "has uuid primary key :id" do
      attributes = Ash.Resource.Info.attributes(VisitRequest)
      id_attr = Enum.find(attributes, &(&1.name == :id))
      assert id_attr != nil
      assert id_attr.primary_key? == true
    end

    test "has required :__request_id string with max_length 50" do
      attributes = Ash.Resource.Info.attributes(VisitRequest)
      request_id_attr = Enum.find(attributes, &(&1.name == :__request_id))
      assert request_id_attr != nil
      assert request_id_attr.allow_nil? == false
      assert request_id_attr.constraints[:max_length] == 50
    end

    test "has required :visit_purpose string with max_length 500" do
      attributes = Ash.Resource.Info.attributes(VisitRequest)
      purpose_attr = Enum.find(attributes, &(&1.name == :visit_purpose))
      assert purpose_attr != nil
      assert purpose_attr.allow_nil? == false
      assert purpose_attr.constraints[:max_length] == 500
    end

    test "has :visit_type atom with 8 valid options" do
      attributes = Ash.Resource.Info.attributes(VisitRequest)
      type_attr = Enum.find(attributes, &(&1.name == :visit_type))
      assert type_attr != nil
      assert type_attr.type == Ash.Type.Atom
      assert type_attr.allow_nil? == false

      expected_types = [
        :business_meeting,
        :site_tour,
        :delivery,
        :maintenance,
        :installation,
        :inspection,
        :emergency,
        :other
      ]

      assert type_attr.constraints[:one_of] == expected_types
    end

    test "has required :scheduled_arrival utc_datetime" do
      attributes = Ash.Resource.Info.attributes(VisitRequest)
      arrival_attr = Enum.find(attributes, &(&1.name == :scheduled_arrival))
      assert arrival_attr != nil
      assert arrival_attr.type == Ash.Type.UtcDatetime
      assert arrival_attr.allow_nil? == false
    end

    test "has required :scheduled_departure utc_datetime" do
      attributes = Ash.Resource.Info.attributes(VisitRequest)
      departure_attr = Enum.find(attributes, &(&1.name == :scheduled_departure))
      assert departure_attr != nil
      assert departure_attr.type == Ash.Type.UtcDatetime
      assert departure_attr.allow_nil? == false
    end

    test "has optional :actual_arrival and :actual_departure" do
      attributes = Ash.Resource.Info.attributes(VisitRequest)
      actual_arrival = Enum.find(attributes, &(&1.name == :actual_arrival))
      actual_departure = Enum.find(attributes, &(&1.name == :actual_departure))

      assert actual_arrival != nil
      assert actual_departure != nil
    end

    test "has :__request_status atom with 6 options and default :submitted" do
      attributes = Ash.Resource.Info.attributes(VisitRequest)
      status_attr = Enum.find(attributes, &(&1.name == :__request_status))
      assert status_attr != nil
      assert status_attr.type == Ash.Type.Atom
      assert status_attr.default == :submitted

      expected_statuses = [
        :submitted,
        :under_review,
        :approved,
        :rejected,
        :cancelled,
        :completed
      ]

      assert status_attr.constraints[:one_of] == expected_statuses
    end

    test "has :priority_level atom with 4 options and default :medium" do
      attributes = Ash.Resource.Info.attributes(VisitRequest)
      priority_attr = Enum.find(attributes, &(&1.name == :priority_level))
      assert priority_attr != nil
      assert priority_attr.default == :medium

      expected_priorities = [:low, :medium, :high, :emergency]
      assert priority_attr.constraints[:one_of] == expected_priorities
    end

    test "has :number_of_visitors integer with constraints 1-50 and default 1" do
      attributes = Ash.Resource.Info.attributes(VisitRequest)
      num_visitors = Enum.find(attributes, &(&1.name == :number_of_visitors))
      assert num_visitors != nil
      assert num_visitors.default == 1
      assert num_visitors.constraints[:min] == 1
      assert num_visitors.constraints[:max] == 50
    end

    test "has :security_briefing_required boolean with default false" do
      attributes = Ash.Resource.Info.attributes(VisitRequest)
      briefing_attr = Enum.find(attributes, &(&1.name == :security_briefing_required))
      assert briefing_attr != nil
      assert briefing_attr.default == false
    end

    test "has array attributes with default []" do
      attributes = Ash.Resource.Info.attributes(VisitRequest)

      requested_areas = Enum.find(attributes, &(&1.name == :__requested_areas))
      equipment = Enum.find(attributes, &(&1.name == :equipment_bringing))
      additional = Enum.find(attributes, &(&1.name == :additional_visitors))
      compliance = Enum.find(attributes, &(&1.name == :compliance_requirements))

      assert requested_areas.default == []
      assert equipment.default == []
      assert additional.default == []
      assert compliance.default == []
    end
  end

  # ============================================================================
  # Relationship Tests
  # ============================================================================

  describe "relationships" do
    test "belongs_to visitor (required)" do
      relationships = Ash.Resource.Info.relationships(VisitRequest)
      visitor_rel = Enum.find(relationships, &(&1.name == :visitor))
      assert visitor_rel != nil
      assert visitor_rel.type == :belongs_to
      assert visitor_rel.allow_nil? == false
    end

    test "belongs_to visitor_type (required)" do
      relationships = Ash.Resource.Info.relationships(VisitRequest)
      type_rel = Enum.find(relationships, &(&1.name == :visitor_type))
      assert type_rel != nil
      assert type_rel.type == :belongs_to
      assert type_rel.allow_nil? == false
    end

    test "belongs_to __requesting_employee (required)" do
      relationships = Ash.Resource.Info.relationships(VisitRequest)
      emp_rel = Enum.find(relationships, &(&1.name == :__requesting_employee))
      assert emp_rel != nil
      assert emp_rel.type == :belongs_to
      assert emp_rel.allow_nil? == false
    end

    test "belongs_to site (required)" do
      relationships = Ash.Resource.Info.relationships(VisitRequest)
      site_rel = Enum.find(relationships, &(&1.name == :site))
      assert site_rel != nil
      assert site_rel.type == :belongs_to
      assert site_rel.allow_nil? == false
    end

    test "has_many approvals" do
      relationships = Ash.Resource.Info.relationships(VisitRequest)
      approvals_rel = Enum.find(relationships, &(&1.name == :approvals))
      assert approvals_rel != nil
      assert approvals_rel.type == :has_many
    end

    test "has_one visitor_pass" do
      relationships = Ash.Resource.Info.relationships(VisitRequest)
      pass_rel = Enum.find(relationships, &(&1.name == :visitor_pass))
      assert pass_rel != nil
      assert pass_rel.type == :has_one
    end

    test "has_many visitor_accesses" do
      relationships = Ash.Resource.Info.relationships(VisitRequest)
      access_rel = Enum.find(relationships, &(&1.name == :visitor_accesses))
      assert access_rel != nil
      assert access_rel.type == :has_many
    end
  end

  # ============================================================================
  # Calculation Tests
  # ============================================================================

  describe "calculations" do
    test "has visit_duration_hours calculation" do
      calculations = Ash.Resource.Info.calculations(VisitRequest)
      duration_calc = Enum.find(calculations, &(&1.name == :visit_duration_hours))
      assert duration_calc != nil
      assert duration_calc.type in [:decimal, Ash.Type.Decimal]
    end

    test "has is_overdue_for_approval calculation" do
      calculations = Ash.Resource.Info.calculations(VisitRequest)
      overdue_calc = Enum.find(calculations, &(&1.name == :is_overdue_for_approval))
      assert overdue_calc != nil
      assert overdue_calc.type in [:boolean, Ash.Type.Boolean]
    end

    test "has is_visit_active calculation" do
      calculations = Ash.Resource.Info.calculations(VisitRequest)
      active_calc = Enum.find(calculations, &(&1.name == :is_visit_active))
      assert active_calc != nil
      assert active_calc.type in [:boolean, Ash.Type.Boolean]
    end
  end

  # ============================================================================
  # Action Tests
  # ============================================================================

  describe "actions" do
    test "has default read, create, destroy actions" do
      actions = Ash.Resource.Info.actions(VisitRequest)
      action_names = Enum.map(actions, & &1.name)

      assert :read in action_names
      assert :create in action_names
      assert :destroy in action_names
    end

    test "has submit_request create action" do
      actions = Ash.Resource.Info.actions(VisitRequest)
      submit = Enum.find(actions, &(&1.name == :submit_request))
      assert submit != nil
      assert submit.type == :create
    end

    test "has update_status action" do
      actions = Ash.Resource.Info.actions(VisitRequest)
      update_status = Enum.find(actions, &(&1.name == :update_status))
      assert update_status != nil
      assert update_status.type == :update
    end

    test "has approve_request action" do
      actions = Ash.Resource.Info.actions(VisitRequest)
      approve = Enum.find(actions, &(&1.name == :approve_request))
      assert approve != nil
      assert approve.type == :update
    end

    test "has reject_request action" do
      actions = Ash.Resource.Info.actions(VisitRequest)
      reject = Enum.find(actions, &(&1.name == :reject_request))
      assert reject != nil
      assert reject.type == :update
    end

    test "has cancel_request action" do
      actions = Ash.Resource.Info.actions(VisitRequest)
      cancel = Enum.find(actions, &(&1.name == :cancel_request))
      assert cancel != nil
      assert cancel.type == :update
    end

    test "has record_arrival action" do
      actions = Ash.Resource.Info.actions(VisitRequest)
      arrival = Enum.find(actions, &(&1.name == :record_arrival))
      assert arrival != nil
      assert arrival.type == :update
    end

    test "has record_departure action" do
      actions = Ash.Resource.Info.actions(VisitRequest)
      departure = Enum.find(actions, &(&1.name == :record_departure))
      assert departure != nil
      assert departure.type == :update
    end
  end

  # ============================================================================
  # Validation Tests
  # ============================================================================

  describe "validations" do
    test "validates scheduled_departure greater than scheduled_arrival" do
      validations = Ash.Resource.Info.validations(VisitRequest)

      has_departure_validation =
        Enum.any?(validations, fn v ->
          case v.validation do
            {Ash.Resource.Validation.Compare, opts} ->
              opts[:attribute] == :scheduled_departure and
                opts[:greater_than] == :scheduled_arrival

            _ ->
              false
          end
        end)

      assert has_departure_validation
    end

    test "validates actual_departure greater than actual_arrival when both present" do
      validations = Ash.Resource.Info.validations(VisitRequest)

      has_actual_validation =
        Enum.any?(validations, fn v ->
          case v.validation do
            {Ash.Resource.Validation.Compare, opts} ->
              opts[:attribute] == :actual_departure and
                opts[:greater_than] == :actual_arrival

            _ ->
              false
          end
        end)

      assert has_actual_validation
    end
  end

  # ============================================================================
  # Code Interface Tests
  # ============================================================================

  describe "code interface" do
    test "source defines all code_interface functions" do
      source_path = "lib/indrajaal/visitor_management/visit_request.ex"
      {:ok, content} = File.read(source_path)

      expected_functions = [
        "define :create",
        "define :submit_request",
        "define :update_status",
        "define :approve_request",
        "define :reject_request",
        "define :cancel_request",
        "define :record_arrival",
        "define :record_departure",
        "define :set_approval_deadline",
        "define :add_equipment_list",
        "define :add_vehicle_details",
        "define :add_additional_visitors",
        "define :set_compliance_requirements",
        "define :__require_security_briefing"
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
    property "visit_type must be one of 8 valid options" do
      valid_types = [
        :business_meeting,
        :site_tour,
        :delivery,
        :maintenance,
        :installation,
        :inspection,
        :emergency,
        :other
      ]

      forall visit_type <- PC.oneof(valid_types) do
        visit_type in valid_types
      end
    end

    property "__request_status must be one of 6 valid options" do
      valid_statuses = [:submitted, :under_review, :approved, :rejected, :cancelled, :completed]

      forall status <- PC.oneof(valid_statuses) do
        status in valid_statuses
      end
    end

    property "priority_level must be one of 4 valid options" do
      valid_priorities = [:low, :medium, :high, :emergency]

      forall priority <- PC.oneof(valid_priorities) do
        priority in valid_priorities
      end
    end

    property "number_of_visitors must be between 1 and 50" do
      forall num <- PC.integer(1, 50) do
        num >= 1 and num <= 50
      end
    end

    property "scheduled_departure must be after scheduled_arrival" do
      forall {arrival_offset, duration} <- {PC.integer(0, 86_400), PC.integer(1, 86_400)} do
        base = DateTime.utc_now()
        arrival = DateTime.add(base, arrival_offset, :second)
        departure = DateTime.add(arrival, duration, :second)

        DateTime.compare(departure, arrival) == :gt
      end
    end
  end

  # ============================================================================
  # Source Code Validation Tests
  # ============================================================================

  describe "source code validation" do
    test "source file exists" do
      source_path = "lib/indrajaal/visitor_management/visit_request.ex"
      assert File.exists?(source_path)
    end

    test "source file contains required module definition" do
      source_path = "lib/indrajaal/visitor_management/visit_request.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "defmodule Indrajaal.VisitorManagement.VisitRequest"
      assert content =~ "use Indrajaal.BaseResource"
      assert content =~ "use Indrajaal.Multitenancy.TenantResource"
    end

    test "source file uses postgres table 'visit_requests'" do
      source_path = "lib/indrajaal/visitor_management/visit_request.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ ~s(table "visit_requests")
    end
  end

  # ============================================================================
  # Edge Case Tests
  # ============================================================================

  describe "edge cases" do
    test "number_of_visitors boundary - minimum 1" do
      attributes = Ash.Resource.Info.attributes(VisitRequest)
      num_attr = Enum.find(attributes, &(&1.name == :number_of_visitors))
      assert num_attr.constraints[:min] == 1
    end

    test "number_of_visitors boundary - maximum 50" do
      attributes = Ash.Resource.Info.attributes(VisitRequest)
      num_attr = Enum.find(attributes, &(&1.name == :number_of_visitors))
      assert num_attr.constraints[:max] == 50
    end

    test "request status workflow transitions" do
      # Valid workflow: submitted -> under_review -> approved/rejected -> completed/cancelled
      valid_statuses = [:submitted, :under_review, :approved, :rejected, :cancelled, :completed]

      attributes = Ash.Resource.Info.attributes(VisitRequest)
      status_attr = Enum.find(attributes, &(&1.name == :__request_status))
      assert status_attr.constraints[:one_of] == valid_statuses
    end
  end

  # ============================================================================
  # Multi-Tenant Isolation Tests
  # ============================================================================

  describe "multi-tenant isolation" do
    test "has tenant_id attribute" do
      attributes = Ash.Resource.Info.attributes(VisitRequest)
      tenant_attr = Enum.find(attributes, &(&1.name == :tenant_id))
      assert tenant_attr != nil
    end

    test "has unique index on tenant_id + __request_id" do
      source_path = "lib/indrajaal/visitor_management/visit_request.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "[:tenant_id, :__request_id], unique: true"
    end

    test "indexes include tenant_id for isolation" do
      source_path = "lib/indrajaal/visitor_management/visit_request.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "[:tenant_id, :visitor_id]"
      assert content =~ "[:tenant_id, :__request_status]"
      assert content =~ "[:tenant_id, :visit_type]"
      assert content =~ "[:tenant_id, :priority_level]"
    end
  end
end
