defmodule Indrajaal.Shared.PrimaryEntityManagementTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Shared.PrimaryEntityManagement

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(PrimaryEntityManagement)
    end
  end

  describe "createprimary_entity_change/3" do
    test "function is exported" do
      assert function_exported?(PrimaryEntityManagement, :createprimary_entity_change, 3)
    end

    test "returns a function" do
      result = PrimaryEntityManagement.createprimary_entity_change(SomeModule)
      assert is_function(result)
    end

    test "returns a function with custom primary field" do
      result = PrimaryEntityManagement.createprimary_entity_change(SomeModule, :is_primary)
      assert is_function(result)
    end

    test "returns a function with all custom opts" do
      result =
        PrimaryEntityManagement.createprimary_entity_change(
          SomeModule,
          :is_primary,
          :tenant_id
        )

      assert is_function(result)
    end
  end

  describe "updateprimary_entity_change/3" do
    test "function is exported" do
      assert function_exported?(PrimaryEntityManagement, :updateprimary_entity_change, 3)
    end

    test "returns a function" do
      result = PrimaryEntityManagement.updateprimary_entity_change(SomeModule)
      assert is_function(result)
    end
  end

  describe "setprimary_action/3" do
    test "function is exported" do
      assert function_exported?(PrimaryEntityManagement, :setprimary_action, 3)
    end

    test "returns action configuration map" do
      result = PrimaryEntityManagement.setprimary_action(SomeModule)
      assert is_map(result)
    end

    test "action config has :name key" do
      result = PrimaryEntityManagement.setprimary_action(SomeModule, :set_primary)
      assert Map.has_key?(result, :name)
      assert result.name == :set_primary
    end

    test "action config has :changes key" do
      result = PrimaryEntityManagement.setprimary_action(SomeModule)
      assert Map.has_key?(result, :changes)
      assert is_list(result.changes)
    end
  end

  describe "get_primary_entity/4" do
    test "function is exported" do
      assert function_exported?(PrimaryEntityManagement, :get_primary_entity, 4)
    end

    test "returns error tuple when called without valid Ash context" do
      result =
        try do
          PrimaryEntityManagement.get_primary_entity(SomeModule, "tenant-1", %{}, :is_primary)
        rescue
          _ -> {:error, :rescued}
        end

      assert match?({:error, _}, result)
    end
  end

  describe "validate_single_primary/3" do
    test "function is exported" do
      assert function_exported?(PrimaryEntityManagement, :validate_single_primary, 3)
    end

    test "returns error tuple without valid Ash module" do
      result =
        try do
          PrimaryEntityManagement.validate_single_primary(SomeModule, "tenant-1", %{})
        rescue
          _ -> {:error, :rescued}
        end

      assert match?({:error, _}, result)
    end
  end

  describe "ensure_primary_exists/4" do
    test "function is exported" do
      assert function_exported?(PrimaryEntityManagement, :ensure_primary_exists, 4)
    end
  end

  describe "list_primary_entities/4" do
    test "function is exported" do
      assert function_exported?(PrimaryEntityManagement, :list_primary_entities, 4)
    end
  end
end
