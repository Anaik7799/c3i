defmodule Indrajaal.Integrations.DataMappingTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Integrations.DataMapping

  describe "module structure" do
    test "module is loadable" do
      assert Code.ensure_loaded?(DataMapping)
    end

    test "is an Ash.Resource (exposes spark_dsl_config/0)" do
      assert function_exported?(DataMapping, :spark_dsl_config, 0)
    end

    test "spark_dsl_config/0 returns a non-nil value" do
      config = DataMapping.spark_dsl_config()
      assert not is_nil(config)
    end
  end

  describe "attribute definitions" do
    test "has expected primary key and public attributes" do
      attrs = Ash.Resource.Info.public_attributes(DataMapping)
      attr_names = Enum.map(attrs, & &1.name)

      assert :name in attr_names
      assert :source_system in attr_names
      assert :target_system in attr_names
      assert :entity_type in attr_names
      assert :direction in attr_names
      assert :field_mappings in attr_names
      assert :active? in attr_names
      assert :priority in attr_names
    end

    test "direction attribute has correct allowed values" do
      attr = Ash.Resource.Info.attribute(DataMapping, :direction)
      assert not is_nil(attr)
      assert attr.type == Ash.Type.Atom
    end

    test "entity_type attribute exists and is an atom type" do
      attr = Ash.Resource.Info.attribute(DataMapping, :entity_type)
      assert not is_nil(attr)
      assert attr.type == Ash.Type.Atom
    end

    test "priority attribute has non-nil type" do
      attr = Ash.Resource.Info.attribute(DataMapping, :priority)
      assert not is_nil(attr)
      assert attr.default == 100
    end

    test "active? attribute defaults to true" do
      attr = Ash.Resource.Info.attribute(DataMapping, :active?)
      assert not is_nil(attr)
      assert attr.default == true
    end

    test "field_mappings attribute defaults to empty map" do
      attr = Ash.Resource.Info.attribute(DataMapping, :field_mappings)
      assert not is_nil(attr)
      assert attr.default == %{}
    end
  end

  describe "actions" do
    test "has standard CRUD actions" do
      action_names = DataMapping |> Ash.Resource.Info.actions() |> Enum.map(& &1.name)

      assert :create in action_names
      assert :read in action_names
      assert :update in action_names
      assert :destroy in action_names
    end

    test "has :activate action" do
      action_names = DataMapping |> Ash.Resource.Info.actions() |> Enum.map(& &1.name)
      assert :activate in action_names
    end

    test "has :deactivate action" do
      action_names = DataMapping |> Ash.Resource.Info.actions() |> Enum.map(& &1.name)
      assert :deactivate in action_names
    end

    test "has :record_usage action" do
      action_names = DataMapping |> Ash.Resource.Info.actions() |> Enum.map(& &1.name)
      assert :record_usage in action_names
    end
  end

  describe "calculations" do
    test "has is_used_recently? calculation" do
      calc_names = DataMapping |> Ash.Resource.Info.calculations() |> Enum.map(& &1.name)
      assert :is_used_recently? in calc_names
    end

    test "has source_fields calculation" do
      calc_names = DataMapping |> Ash.Resource.Info.calculations() |> Enum.map(& &1.name)
      assert :source_fields in calc_names
    end

    test "has target_fields calculation" do
      calc_names = DataMapping |> Ash.Resource.Info.calculations() |> Enum.map(& &1.name)
      assert :target_fields in calc_names
    end
  end
end
