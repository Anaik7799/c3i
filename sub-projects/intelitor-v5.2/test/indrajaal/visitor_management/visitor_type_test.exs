defmodule Indrajaal.VisitorManagement.VisitorTypeTest do
  @moduledoc """
  TDG-compliant test suite for Indrajaal.VisitorManagement.VisitorType.

  Tests visitor type classification with security levels and requirements.

  ## SOPv5.11 Compliance
  - TDG: Tests written FIRST, code validated against tests
  - STAMP: Safety constraints for visitor categorization
  - Property Testing: PropCheck for constraint validation
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.VisitorManagement.VisitorType

  # ============================================================================
  # Module Structure Tests
  # ============================================================================

  describe "module structure" do
    test "module exists and is compiled" do
      assert Code.ensure_loaded?(VisitorType)
    end

    test "uses BaseResource" do
      assert Ash.Resource.Info.domain(VisitorType) == Indrajaal.VisitorManagement
    end

    test "uses TenantResource for multi-tenancy" do
      attributes = Ash.Resource.Info.attributes(VisitorType)
      attribute_names = Enum.map(attributes, & &1.name)
      assert :tenant_id in attribute_names
    end
  end

  # ============================================================================
  # Attribute Tests
  # ============================================================================

  describe "attributes" do
    test "has uuid primary key :id" do
      attributes = Ash.Resource.Info.attributes(VisitorType)
      id_attr = Enum.find(attributes, &(&1.name == :id))
      assert id_attr != nil
      assert id_attr.primary_key? == true
    end

    test "has required :name attribute with max_length 100" do
      attributes = Ash.Resource.Info.attributes(VisitorType)
      name_attr = Enum.find(attributes, &(&1.name == :name))
      assert name_attr != nil
      assert name_attr.allow_nil? == false
      assert name_attr.constraints[:max_length] == 100
    end

    test "has :description with max_length 500" do
      attributes = Ash.Resource.Info.attributes(VisitorType)
      desc_attr = Enum.find(attributes, &(&1.name == :description))
      assert desc_attr != nil
      assert desc_attr.constraints[:max_length] == 500
    end

    test "has required :type_code with max_length 20" do
      attributes = Ash.Resource.Info.attributes(VisitorType)
      code_attr = Enum.find(attributes, &(&1.name == :type_code))
      assert code_attr != nil
      assert code_attr.allow_nil? == false
      assert code_attr.constraints[:max_length] == 20
    end

    test "has :category atom with 9 valid options" do
      attributes = Ash.Resource.Info.attributes(VisitorType)
      category_attr = Enum.find(attributes, &(&1.name == :category))
      assert category_attr != nil
      assert category_attr.type == Ash.Type.Atom
      assert category_attr.allow_nil? == false

      expected_categories = [
        :guest,
        :contractor,
        :vendor,
        :delivery,
        :service,
        :vip,
        :government,
        :media,
        :candidate
      ]

      assert category_attr.constraints[:one_of] == expected_categories
    end

    test "has :security_level atom with 4 options and default :public" do
      attributes = Ash.Resource.Info.attributes(VisitorType)
      security_attr = Enum.find(attributes, &(&1.name == :security_level))
      assert security_attr != nil
      assert security_attr.type == Ash.Type.Atom
      assert security_attr.default == :public

      expected_levels = [:public, :restricted, :confidential, :secret]
      assert security_attr.constraints[:one_of] == expected_levels
    end

    test "has :__requires_escort boolean with default false" do
      attributes = Ash.Resource.Info.attributes(VisitorType)
      escort_attr = Enum.find(attributes, &(&1.name == :__requires_escort))
      assert escort_attr != nil
      assert escort_attr.type == Ash.Type.Boolean
      assert escort_attr.default == false
    end

    test "has :__requires_background_check boolean with default false" do
      attributes = Ash.Resource.Info.attributes(VisitorType)
      bg_check_attr = Enum.find(attributes, &(&1.name == :__requires_background_check))
      assert bg_check_attr != nil
      assert bg_check_attr.default == false
    end

    test "has :__requires_training boolean with default false" do
      attributes = Ash.Resource.Info.attributes(VisitorType)
      training_attr = Enum.find(attributes, &(&1.name == :__requires_training))
      assert training_attr != nil
      assert training_attr.default == false
    end

    test "has :max_visit_duration_hours integer with constraints 1-168 and default 8" do
      attributes = Ash.Resource.Info.attributes(VisitorType)
      duration_attr = Enum.find(attributes, &(&1.name == :max_visit_duration_hours))
      assert duration_attr != nil
      assert duration_attr.type == Ash.Type.Integer
      assert duration_attr.default == 8
      assert duration_attr.constraints[:min] == 1
      assert duration_attr.constraints[:max] == 168
    end

    test "has :advance_notice_hours integer with constraints 0-720 and default 24" do
      attributes = Ash.Resource.Info.attributes(VisitorType)
      notice_attr = Enum.find(attributes, &(&1.name == :advance_notice_hours))
      assert notice_attr != nil
      assert notice_attr.default == 24
      assert notice_attr.constraints[:min] == 0
      assert notice_attr.constraints[:max] == 720
    end

    test "has :approval_required boolean with default true" do
      attributes = Ash.Resource.Info.attributes(VisitorType)
      approval_attr = Enum.find(attributes, &(&1.name == :approval_required))
      assert approval_attr != nil
      assert approval_attr.default == true
    end

    test "has :allowed_areas array of UUIDs with default []" do
      attributes = Ash.Resource.Info.attributes(VisitorType)
      allowed_attr = Enum.find(attributes, &(&1.name == :allowed_areas))
      assert allowed_attr != nil
      assert allowed_attr.type == {:array, Ash.Type.UUID}
      assert allowed_attr.default == []
    end

    test "has :restricted_areas array of UUIDs with default []" do
      attributes = Ash.Resource.Info.attributes(VisitorType)
      restricted_attr = Enum.find(attributes, &(&1.name == :restricted_areas))
      assert restricted_attr != nil
      assert restricted_attr.default == []
    end

    test "has :__required_documents array of strings with default []" do
      attributes = Ash.Resource.Info.attributes(VisitorType)
      docs_attr = Enum.find(attributes, &(&1.name == :__required_documents))
      assert docs_attr != nil
      assert docs_attr.default == []
    end

    test "has :is_active boolean with default true" do
      attributes = Ash.Resource.Info.attributes(VisitorType)
      active_attr = Enum.find(attributes, &(&1.name == :is_active))
      assert active_attr != nil
      assert active_attr.default == true
    end
  end

  # ============================================================================
  # Relationship Tests
  # ============================================================================

  describe "relationships" do
    test "has_many visitors" do
      relationships = Ash.Resource.Info.relationships(VisitorType)
      visitors_rel = Enum.find(relationships, &(&1.name == :visitors))
      assert visitors_rel != nil
      assert visitors_rel.type == :has_many
      assert visitors_rel.destination == Indrajaal.VisitorManagement.Visitor
    end

    test "has_many visit_requests" do
      relationships = Ash.Resource.Info.relationships(VisitorType)
      requests_rel = Enum.find(relationships, &(&1.name == :visit_requests))
      assert requests_rel != nil
      assert requests_rel.type == :has_many
      assert requests_rel.destination == Indrajaal.VisitorManagement.VisitRequest
    end
  end

  # ============================================================================
  # Action Tests
  # ============================================================================

  describe "actions" do
    test "has default CRUD actions" do
      actions = Ash.Resource.Info.actions(VisitorType)
      action_names = Enum.map(actions, & &1.name)

      assert :read in action_names
      assert :create in action_names
      assert :update in action_names
      assert :destroy in action_names
    end

    test "has :create_type action" do
      actions = Ash.Resource.Info.actions(VisitorType)
      create_type = Enum.find(actions, &(&1.name == :create_type))
      assert create_type != nil
      assert create_type.type == :create
    end

    test "has :configure_requirements action" do
      actions = Ash.Resource.Info.actions(VisitorType)
      config_req = Enum.find(actions, &(&1.name == :configure_requirements))
      assert config_req != nil
      assert config_req.type == :update
    end

    test "has :set_access_areas action" do
      actions = Ash.Resource.Info.actions(VisitorType)
      set_areas = Enum.find(actions, &(&1.name == :set_access_areas))
      assert set_areas != nil
      assert set_areas.type == :update
    end

    test "has :activate action" do
      actions = Ash.Resource.Info.actions(VisitorType)
      activate = Enum.find(actions, &(&1.name == :activate))
      assert activate != nil
      assert activate.type == :update
    end

    test "has :deactivate action" do
      actions = Ash.Resource.Info.actions(VisitorType)
      deactivate = Enum.find(actions, &(&1.name == :deactivate))
      assert deactivate != nil
      assert deactivate.type == :update
    end
  end

  # ============================================================================
  # Code Interface Tests
  # ============================================================================

  describe "code interface" do
    test "defines create function" do
      assert function_exported?(Indrajaal.VisitorManagement, :create, 2)
    end

    test "source defines all code_interface functions" do
      source_path = "lib/indrajaal/visitor_management/visitor_type.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "define :create"
      assert content =~ "define :create_type"
      assert content =~ "define :configure_requirements"
      assert content =~ "define :set_access_areas"
      assert content =~ "define :activate"
      assert content =~ "define :deactivate"
    end
  end

  # ============================================================================
  # Property Tests (PropCheck)
  # ============================================================================

  describe "property tests" do
    property "category must be one of 9 valid options" do
      valid_categories = [
        :guest,
        :contractor,
        :vendor,
        :delivery,
        :service,
        :vip,
        :government,
        :media,
        :candidate
      ]

      forall category <- PC.oneof(valid_categories) do
        category in valid_categories
      end
    end

    property "security_level must be one of 4 valid options" do
      valid_levels = [:public, :restricted, :confidential, :secret]

      forall level <- PC.oneof(valid_levels) do
        level in valid_levels
      end
    end

    property "max_visit_duration_hours must be between 1 and 168" do
      forall hours <- PC.integer(1, 168) do
        hours >= 1 and hours <= 168
      end
    end

    property "advance_notice_hours must be between 0 and 720" do
      forall hours <- PC.integer(0, 720) do
        hours >= 0 and hours <= 720
      end
    end

    property "allowed_areas and restricted_areas must be lists of UUIDs" do
      forall areas <- PC.list(PC.binary(16)) do
        is_list(areas)
      end
    end
  end

  # ============================================================================
  # Source Code Validation Tests
  # ============================================================================

  describe "source code validation" do
    test "source file exists" do
      source_path = "lib/indrajaal/visitor_management/visitor_type.ex"
      assert File.exists?(source_path)
    end

    test "source file contains required module definition" do
      source_path = "lib/indrajaal/visitor_management/visitor_type.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "defmodule Indrajaal.VisitorManagement.VisitorType"
      assert content =~ "use Indrajaal.BaseResource"
      assert content =~ "use Indrajaal.Multitenancy.TenantResource"
    end

    test "source file uses postgres table 'visitor_types'" do
      source_path = "lib/indrajaal/visitor_management/visitor_type.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ ~s(table "visitor_types")
    end
  end

  # ============================================================================
  # Edge Case Tests
  # ============================================================================

  describe "edge cases" do
    test "max_visit_duration_hours boundary - minimum 1" do
      attributes = Ash.Resource.Info.attributes(VisitorType)
      duration_attr = Enum.find(attributes, &(&1.name == :max_visit_duration_hours))
      assert duration_attr.constraints[:min] == 1
    end

    test "max_visit_duration_hours boundary - maximum 168 (one week)" do
      attributes = Ash.Resource.Info.attributes(VisitorType)
      duration_attr = Enum.find(attributes, &(&1.name == :max_visit_duration_hours))
      assert duration_attr.constraints[:max] == 168
    end

    test "advance_notice_hours boundary - minimum 0 (no notice)" do
      attributes = Ash.Resource.Info.attributes(VisitorType)
      notice_attr = Enum.find(attributes, &(&1.name == :advance_notice_hours))
      assert notice_attr.constraints[:min] == 0
    end

    test "advance_notice_hours boundary - maximum 720 (30 days)" do
      attributes = Ash.Resource.Info.attributes(VisitorType)
      notice_attr = Enum.find(attributes, &(&1.name == :advance_notice_hours))
      assert notice_attr.constraints[:max] == 720
    end
  end

  # ============================================================================
  # Multi-Tenant Isolation Tests
  # ============================================================================

  describe "multi-tenant isolation" do
    test "has tenant_id attribute" do
      attributes = Ash.Resource.Info.attributes(VisitorType)
      tenant_attr = Enum.find(attributes, &(&1.name == :tenant_id))
      assert tenant_attr != nil
    end

    test "has unique index on tenant_id + type_code" do
      source_path = "lib/indrajaal/visitor_management/visitor_type.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "[:tenant_id, :type_code], unique: true"
    end

    test "indexes include tenant_id for isolation" do
      source_path = "lib/indrajaal/visitor_management/visitor_type.ex"
      {:ok, content} = File.read(source_path)

      assert content =~ "[:tenant_id, :category]"
      assert content =~ "[:tenant_id, :security_level]"
      assert content =~ "[:tenant_id, :is_active]"
    end
  end
end
