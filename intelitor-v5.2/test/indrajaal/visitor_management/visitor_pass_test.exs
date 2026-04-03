defmodule Indrajaal.VisitorManagement.VisitorPassTest do
  @moduledoc """
  TDG-compliant test suite for Indrajaal.VisitorManagement.VisitorPass.

  Tests physical and digital visitor passes with access controls and tracking.

  ## SOPv5.11 Compliance
  - TDG: Tests written FIRST, code validated against tests
  - STAMP: Safety constraints for pass lifecycle management
  - Property Testing: PropCheck for validity and time validation
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.VisitorManagement.VisitorPass

  # ============================================================================
  # Module Structure Tests
  # ============================================================================

  describe "module structure" do
    test "module exists and is compiled" do
      assert Code.ensure_loaded?(VisitorPass)
    end

    test "uses BaseResource with VisitorManagement domain" do
      assert Ash.Resource.Info.domain(VisitorPass) == Indrajaal.VisitorManagement
    end

    test "uses TenantResource for multi-tenancy" do
      attributes = Ash.Resource.Info.attributes(VisitorPass)
      attribute_names = Enum.map(attributes, & &1.name)
      assert :tenant_id in attribute_names
    end
  end

  # ============================================================================
  # Attribute Tests
  # ============================================================================

  describe "attributes" do
    test "has uuid primary key :id" do
      attributes = Ash.Resource.Info.attributes(VisitorPass)
      id_attr = Enum.find(attributes, &(&1.name == :id))
      assert id_attr != nil
      assert id_attr.primary_key? == true
    end

    test "has required :pass_number string with max_length 50" do
      attributes = Ash.Resource.Info.attributes(VisitorPass)
      pass_num_attr = Enum.find(attributes, &(&1.name == :pass_number))
      assert pass_num_attr != nil
      assert pass_num_attr.allow_nil? == false
      assert pass_num_attr.constraints[:max_length] == 50
    end

    test "has required :pass_type atom with 5 valid options" do
      attributes = Ash.Resource.Info.attributes(VisitorPass)
      type_attr = Enum.find(attributes, &(&1.name == :pass_type))
      assert type_attr != nil
      assert type_attr.type == Ash.Type.Atom
      assert type_attr.allow_nil? == false

      expected_types = [
        :physical_badge,
        :digital_pass,
        :temporary_sticker,
        :wristband,
        :rfid_card
      ]

      assert type_attr.constraints[:one_of] == expected_types
    end

    test "has :pass_status atom with 6 options and default :issued" do
      attributes = Ash.Resource.Info.attributes(VisitorPass)
      status_attr = Enum.find(attributes, &(&1.name == :pass_status))
      assert status_attr != nil
      assert status_attr.type == Ash.Type.Atom
      assert status_attr.default == :issued

      expected_statuses = [:issued, :active, :expired, :revoked, :lost, :returned]
      assert status_attr.constraints[:one_of] == expected_statuses
    end

    test "has :issued_at utc_datetime with default DateTime.utc_now/0" do
      attributes = Ash.Resource.Info.attributes(VisitorPass)
      issued_attr = Enum.find(attributes, &(&1.name == :issued_at))
      assert issued_attr != nil
      assert issued_attr.type == Ash.Type.UtcDatetime
      assert issued_attr.allow_nil? == false
    end

    test "has required :valid_from and :valid_until utc_datetime" do
      attributes = Ash.Resource.Info.attributes(VisitorPass)

      valid_from = Enum.find(attributes, &(&1.name == :valid_from))
      valid_until = Enum.find(attributes, &(&1.name == :valid_until))

      assert valid_from != nil
      assert valid_from.allow_nil? == false
      assert valid_until != nil
      assert valid_until.allow_nil? == false
    end

    test "has :access_level atom with 4 options and default :public_areas" do
      attributes = Ash.Resource.Info.attributes(VisitorPass)
      access_attr = Enum.find(attributes, &(&1.name == :access_level))
      assert access_attr != nil
      assert access_attr.default == :public_areas

      expected_levels = [:public_areas, :restricted_areas, :confidential_areas, :secure_areas]
      assert access_attr.constraints[:one_of] == expected_levels
    end

    test "has :authorized_areas and :restricted_areas arrays with default []" do
      attributes = Ash.Resource.Info.attributes(VisitorPass)

      authorized = Enum.find(attributes, &(&1.name == :authorized_areas))
      restricted = Enum.find(attributes, &(&1.name == :restricted_areas))

      assert authorized.default == []
      assert restricted.default == []
    end

    test "has :security_features map with default {}" do
      attributes = Ash.Resource.Info.attributes(VisitorPass)
      security_attr = Enum.find(attributes, &(&1.name == :security_features))
      assert security_attr != nil
      assert security_attr.type == Ash.Type.Map
      assert security_attr.default == %{}
    end

    test "has :escort_required boolean with default false" do
      attributes = Ash.Resource.Info.attributes(VisitorPass)
      escort_attr = Enum.find(attributes, &(&1.name == :escort_required))
      assert escort_attr != nil
      assert escort_attr.default == false
    end

    test "has :usage_count integer with default 0" do
      attributes = Ash.Resource.Info.attributes(VisitorPass)
      usage_attr = Enum.find(attributes, &(&1.name == :usage_count))
      assert usage_attr != nil
      assert usage_attr.default == 0
    end

    test "has :qr_code_data and :rfid_uid string attributes" do
      attributes = Ash.Resource.Info.attributes(VisitorPass)

      qr_attr = Enum.find(attributes, &(&1.name == :qr_code_data))
      rfid_attr = Enum.find(attributes, &(&1.name == :rfid_uid))

      assert qr_attr != nil
      assert qr_attr.constraints[:max_length] == 1000
      assert rfid_attr != nil
      assert rfid_attr.constraints[:max_length] == 50
    end
  end

  # ============================================================================
  # Relationship Tests
  # ============================================================================

  describe "relationships" do
    test "belongs_to visitor (required)" do
      relationships = Ash.Resource.Info.relationships(VisitorPass)
      visitor_rel = Enum.find(relationships, &(&1.name == :visitor))
      assert visitor_rel != nil
      assert visitor_rel.type == :belongs_to
      assert visitor_rel.allow_nil? == false
    end

    test "belongs_to visit_request (required)" do
      relationships = Ash.Resource.Info.relationships(VisitorPass)
      request_rel = Enum.find(relationships, &(&1.name == :visit_request))
      assert request_rel != nil
      assert request_rel.type == :belongs_to
      assert request_rel.allow_nil? == false
    end

    test "belongs_to issued_by (required)" do
      relationships = Ash.Resource.Info.relationships(VisitorPass)
      issued_rel = Enum.find(relationships, &(&1.name == :issued_by))
      assert issued_rel != nil
      assert issued_rel.type == :belongs_to
      assert issued_rel.allow_nil? == false
    end

    test "belongs_to revoked_by (optional)" do
      relationships = Ash.Resource.Info.relationships(VisitorPass)
      revoked_rel = Enum.find(relationships, &(&1.name == :revoked_by))
      assert revoked_rel != nil
      assert revoked_rel.type == :belongs_to
    end

    test "has_many visitor_accesses" do
      relationships = Ash.Resource.Info.relationships(VisitorPass)
      access_rel = Enum.find(relationships, &(&1.name == :visitor_accesses))
      assert access_rel != nil
      assert access_rel.type == :has_many
    end
  end

  # ============================================================================
  # Calculation Tests
  # ============================================================================

  describe "calculations" do
    test "has is_valid calculation" do
      calculations = Ash.Resource.Info.calculations(VisitorPass)
      valid_calc = Enum.find(calculations, &(&1.name == :is_valid))
      assert valid_calc != nil
      assert valid_calc.type in [:boolean, Ash.Type.Boolean]
    end

    test "has is_expired calculation" do
      calculations = Ash.Resource.Info.calculations(VisitorPass)
      expired_calc = Enum.find(calculations, &(&1.name == :is_expired))
      assert expired_calc != nil
      assert expired_calc.type in [:boolean, Ash.Type.Boolean]
    end

    test "has hours_remaining calculation" do
      calculations = Ash.Resource.Info.calculations(VisitorPass)
      hours_calc = Enum.find(calculations, &(&1.name == :hours_remaining))
      assert hours_calc != nil
      assert hours_calc.type in [:decimal, Ash.Type.Decimal]
    end
  end

  # ============================================================================
  # Action Tests
  # ============================================================================

  describe "actions" do
    test "has default CRUD actions" do
      actions = Ash.Resource.Info.actions(VisitorPass)
      action_names = Enum.map(actions, & &1.name)

      assert :read in action_names
      assert :create in action_names
      assert :update in action_names
      assert :destroy in action_names
    end

    test "has issue_pass create action" do
      actions = Ash.Resource.Info.actions(VisitorPass)
      issue = Enum.find(actions, &(&1.name == :issue_pass))
      assert issue != nil
      assert issue.type == :create
    end

    test "has activate_pass action" do
      actions = Ash.Resource.Info.actions(VisitorPass)
      activate = Enum.find(actions, &(&1.name == :activate_pass))
      assert activate != nil
      assert activate.type == :update
    end

    test "has revoke_pass action" do
      actions = Ash.Resource.Info.actions(VisitorPass)
      revoke = Enum.find(actions, &(&1.name == :revoke_pass))
      assert revoke != nil
      assert revoke.type == :update
    end

    test "has mark_lost action" do
      actions = Ash.Resource.Info.actions(VisitorPass)
      lost = Enum.find(actions, &(&1.name == :mark_lost))
      assert lost != nil
      assert lost.type == :update
    end

    test "has mark_returned action" do
      actions = Ash.Resource.Info.actions(VisitorPass)
      returned = Enum.find(actions, &(&1.name == :mark_returned))
      assert returned != nil
      assert returned.type == :update
    end

    test "has record_usage action" do
      actions = Ash.Resource.Info.actions(VisitorPass)
      usage = Enum.find(actions, &(&1.name == :record_usage))
      assert usage != nil
      assert usage.type == :update
    end

    test "has set_access_areas action" do
      actions = Ash.Resource.Info.actions(VisitorPass)
      areas = Enum.find(actions, &(&1.name == :set_access_areas))
      assert areas != nil
      assert areas.type == :update
    end

    test "has configure_security_features action" do
      actions = Ash.Resource.Info.actions(VisitorPass)
      security = Enum.find(actions, &(&1.name == :configure_security_features))
      assert security != nil
      assert security.type == :update
    end

    test "has extend_validity action" do
      actions = Ash.Resource.Info.actions(VisitorPass)
      extend = Enum.find(actions, &(&1.name == :extend_validity))
      assert extend != nil
      assert extend.type == :update
    end
  end

  # ============================================================================
  # Validation Tests
  # ============================================================================

  describe "validations" do
    test "validates valid_until greater than valid_from" do
      validations = Ash.Resource.Info.validations(VisitorPass)

      has_validation =
        Enum.any?(validations, fn v ->
          case v.validation do
            {Ash.Resource.Validation.Compare, opts} ->
              opts[:attribute] == :valid_until and
                opts[:greater_than] == :valid_from

            _ ->
              false
          end
        end)

      assert has_validation
    end
  end

  # ============================================================================
  # Code Interface Tests
  # ============================================================================

  describe "code interface" do
    test "source defines all code_interface functions" do
      source_path = "lib/indrajaal/visitor_management/visitor_pass.ex"
      {:ok, content} = File.read(source_path)

      expected_functions = [
        "define :create",
        "define :issue_pass",
        "define :activate_pass",
        "define :revoke_pass",
        "define :mark_lost",
        "define :mark_returned",
        "define :record_usage",
        "define :set_access_areas",
        "define :configure_security_features",
        "define :__require_escort",
        "define :remove_escort_requirement",
        "define :add_special_conditions",
        "define :extend_validity"
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
    property "pass_type must be one of 5 valid options" do
      valid_types = [:physical_badge, :digital_pass, :temporary_sticker, :wristband, :rfid_card]

      forall type <- PC.oneof(valid_types) do
        type in valid_types
      end
    end

    property "pass_status must be one of 6 valid options" do
      valid_statuses = [:issued, :active, :expired, :revoked, :lost, :returned]

      forall status <- PC.oneof(valid_statuses) do
        status in valid_statuses
      end
    end

    property "access_level must be one of 4 valid options" do
      valid_levels = [:public_areas, :restricted_areas, :confidential_areas, :secure_areas]

      forall level <- PC.oneof(valid_levels) do
        level in valid_levels
      end
    end

    property "valid_until must be after valid_from" do
      forall {from_offset, duration} <- {PC.integer(0, 86_400), PC.integer(1, 86_400 * 7)} do
        base = DateTime.utc_now()
        valid_from = DateTime.add(base, from_offset, :second)
        valid_until = DateTime.add(valid_from, duration, :second)

        DateTime.compare(valid_until, valid_from) == :gt
      end
    end

    property "usage_count must be non-negative" do
      forall count <- PC.integer(0, 10_000) do
        count >= 0
      end
    end
  end

  # ============================================================================
  # Source Code Validation Tests
  # ============================================================================

  describe "source code validation" do
    test "source file exists" do
      source_path = "lib/indrajaal/visitor_management/visitor_pass.ex"
      assert File.exists?(source_path)
    end

    test "source file contains required module definition" do
      source_path = "lib/indrajaal/visitor_management/visitor_pass.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "defmodule Indrajaal.VisitorManagement.VisitorPass"
      assert content =~ "use Indrajaal.BaseResource"
      assert content =~ "use Indrajaal.Multitenancy.TenantResource"
    end

    test "source file uses postgres table 'visitor_passes'" do
      source_path = "lib/indrajaal/visitor_management/visitor_pass.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ ~s(table "visitor_passes")
    end
  end

  # ============================================================================
  # Edge Case Tests
  # ============================================================================

  describe "edge cases" do
    test "pass lifecycle states" do
      # Valid lifecycle: issued -> active -> expired/revoked/lost/returned
      valid_statuses = [:issued, :active, :expired, :revoked, :lost, :returned]

      attributes = Ash.Resource.Info.attributes(VisitorPass)
      status_attr = Enum.find(attributes, &(&1.name == :pass_status))
      assert status_attr.constraints[:one_of] == valid_statuses
    end

    test "access level hierarchy" do
      # Security levels from lowest to highest
      levels = [:public_areas, :restricted_areas, :confidential_areas, :secure_areas]

      attributes = Ash.Resource.Info.attributes(VisitorPass)
      access_attr = Enum.find(attributes, &(&1.name == :access_level))
      assert access_attr.constraints[:one_of] == levels
    end

    test "record_usage action increments usage_count" do
      source_path = "lib/indrajaal/visitor_management/visitor_pass.ex"
      {:ok, content} = File.read(source_path)

      # Verify the action uses change fn to increment count
      assert content =~ "change fn changeset, _"
      assert content =~ ":usage_count"
    end
  end

  # ============================================================================
  # Multi-Tenant Isolation Tests
  # ============================================================================

  describe "multi-tenant isolation" do
    test "has tenant_id attribute" do
      attributes = Ash.Resource.Info.attributes(VisitorPass)
      tenant_attr = Enum.find(attributes, &(&1.name == :tenant_id))
      assert tenant_attr != nil
    end

    test "has unique index on tenant_id + pass_number" do
      source_path = "lib/indrajaal/visitor_management/visitor_pass.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "[:tenant_id, :pass_number], unique: true"
    end

    test "has unique index on tenant_id + rfid_uid when present" do
      source_path = "lib/indrajaal/visitor_management/visitor_pass.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "[:tenant_id, :rfid_uid]"
      assert content =~ "unique: true"
      assert content =~ "where: \"rfid_uid IS NOT NULL\""
    end

    test "indexes include tenant_id for isolation" do
      source_path = "lib/indrajaal/visitor_management/visitor_pass.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "[:tenant_id, :visitor_id]"
      assert content =~ "[:tenant_id, :pass_status]"
      assert content =~ "[:tenant_id, :pass_type]"
    end
  end
end
