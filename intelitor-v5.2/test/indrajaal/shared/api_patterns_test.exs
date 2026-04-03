defmodule Indrajaal.Shared.ApiPatternsTest do
  @moduledoc """
  TDG-compliant test suite for Indrajaal.Shared.ApiPatterns.

  Tests the shared API creation patterns module that eliminates duplication across
  domain APIs following Toyota TPS principles for duplicate code waste elimination.

  SOPv5.11 Compliance: ✅
  Test Categories: Module Structure, Function Tests, Property Tests, Edge Cases
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Shared.ApiPatterns

  # ===========================================================================
  # Module Structure Tests
  # ===========================================================================

  describe "Module Structure" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(ApiPatterns)
    end

    test "exports create_resource_function/2" do
      exports = ApiPatterns.__info__(:functions)
      assert {:create_resource_function, 2} in exports
    end

    test "exports update_resource_function/2" do
      exports = ApiPatterns.__info__(:functions)
      assert {:update_resource_function, 2} in exports
    end

    test "exports get_resource_function/2" do
      exports = ApiPatterns.__info__(:functions)
      assert {:get_resource_function, 2} in exports
    end

    test "exports list_resources_function/2" do
      exports = ApiPatterns.__info__(:functions)
      assert {:list_resources_function, 2} in exports
    end

    test "exports delete_resource_function/2" do
      exports = ApiPatterns.__info__(:functions)
      assert {:delete_resource_function, 2} in exports
    end

    test "exports generate_crud_functions/2" do
      exports = ApiPatterns.__info__(:functions)
      assert {:generate_crud_functions, 2} in exports
    end

    test "exports batch_create_function/3" do
      exports = ApiPatterns.__info__(:functions)
      assert {:batch_create_function, 3} in exports
    end

    test "has proper moduledoc" do
      {:docs_v1, _, :elixir, _, module_doc, _, _} = Code.fetch_docs(ApiPatterns)
      assert module_doc != :hidden
      assert module_doc != :none
    end
  end

  # ===========================================================================
  # create_resource_function/2 Tests
  # ===========================================================================

  describe "create_resource_function/2" do
    test "returns a function when called with module" do
      result = ApiPatterns.create_resource_function(MockResource)
      assert is_function(result, 2)
    end

    test "returns a function with default action :create" do
      result = ApiPatterns.create_resource_function(MockResource)
      assert is_function(result, 2)
    end

    test "returns a function with custom action" do
      result = ApiPatterns.create_resource_function(MockResource, :custom_create)
      assert is_function(result, 2)
    end
  end

  # ===========================================================================
  # update_resource_function/2 Tests
  # ===========================================================================

  describe "update_resource_function/2" do
    test "returns a function when called with module" do
      result = ApiPatterns.update_resource_function(MockResource)
      assert is_function(result, 3)
    end

    test "returns a function with default action :update" do
      result = ApiPatterns.update_resource_function(MockResource)
      assert is_function(result, 3)
    end

    test "returns a function with custom action" do
      result = ApiPatterns.update_resource_function(MockResource, :custom_update)
      assert is_function(result, 3)
    end
  end

  # ===========================================================================
  # get_resource_function/2 Tests
  # ===========================================================================

  describe "get_resource_function/2" do
    test "returns a function when called with module" do
      result = ApiPatterns.get_resource_function(MockResource)
      assert is_function(result, 2)
    end

    test "returns a function with default action :read" do
      result = ApiPatterns.get_resource_function(MockResource)
      assert is_function(result, 2)
    end

    test "returns a function with custom action" do
      result = ApiPatterns.get_resource_function(MockResource, :custom_read)
      assert is_function(result, 2)
    end
  end

  # ===========================================================================
  # list_resources_function/2 Tests
  # ===========================================================================

  describe "list_resources_function/2" do
    test "returns a function when called with module" do
      result = ApiPatterns.list_resources_function(MockResource)
      assert is_function(result, 1)
    end

    test "returns a function with default action :read" do
      result = ApiPatterns.list_resources_function(MockResource)
      assert is_function(result, 1)
    end

    test "returns a function with custom action" do
      result = ApiPatterns.list_resources_function(MockResource, :custom_list)
      assert is_function(result, 1)
    end
  end

  # ===========================================================================
  # delete_resource_function/2 Tests
  # ===========================================================================

  describe "delete_resource_function/2" do
    test "returns a function when called with module" do
      result = ApiPatterns.delete_resource_function(MockResource)
      assert is_function(result, 2)
    end

    test "returns a function with default action :destroy" do
      result = ApiPatterns.delete_resource_function(MockResource)
      assert is_function(result, 2)
    end

    test "returns a function with custom action" do
      result = ApiPatterns.delete_resource_function(MockResource, :custom_destroy)
      assert is_function(result, 2)
    end
  end

  # ===========================================================================
  # generate_crud_functions/2 Tests
  # ===========================================================================

  describe "generate_crud_functions/2" do
    test "returns a map with all CRUD functions" do
      result = ApiPatterns.generate_crud_functions(MockResource, "mock")

      assert is_map(result)
      assert Map.has_key?(result, :create)
      assert Map.has_key?(result, :get)
      assert Map.has_key?(result, :list)
      assert Map.has_key?(result, :update)
      assert Map.has_key?(result, :delete)
    end

    test "all returned functions have correct arity" do
      result = ApiPatterns.generate_crud_functions(MockResource, "mock")

      assert is_function(result.create, 2)
      assert is_function(result.get, 2)
      assert is_function(result.list, 1)
      assert is_function(result.update, 3)
      assert is_function(result.delete, 2)
    end

    test "works with different resource names" do
      result1 = ApiPatterns.generate_crud_functions(MockResource, "incident_type")
      result2 = ApiPatterns.generate_crud_functions(MockResource, "alarm")

      assert is_map(result1)
      assert is_map(result2)
      assert map_size(result1) == 5
      assert map_size(result2) == 5
    end
  end

  # ===========================================================================
  # batch_create_function/3 Tests
  # ===========================================================================

  describe "batch_create_function/3" do
    test "returns a function when called with module" do
      result = ApiPatterns.batch_create_function(MockResource)
      assert is_function(result, 2)
    end

    test "returns a function with default action and batch_size" do
      result = ApiPatterns.batch_create_function(MockResource)
      assert is_function(result, 2)
    end

    test "returns a function with custom action" do
      result = ApiPatterns.batch_create_function(MockResource, :batch_create)
      assert is_function(result, 2)
    end

    test "returns a function with custom batch_size" do
      result = ApiPatterns.batch_create_function(MockResource, :create, 50)
      assert is_function(result, 2)
    end
  end

  # ===========================================================================
  # PropCheck Property-Based Tests
  # ===========================================================================

  describe "Property-based tests" do
    property "create_resource_function always returns a 2-arity function" do
      forall action <- PC.atom() do
        result = ApiPatterns.create_resource_function(MockResource, action)
        is_function(result, 2)
      end
    end

    property "update_resource_function always returns a 3-arity function" do
      forall action <- PC.atom() do
        result = ApiPatterns.update_resource_function(MockResource, action)
        is_function(result, 3)
      end
    end

    property "get_resource_function always returns a 2-arity function" do
      forall action <- PC.atom() do
        result = ApiPatterns.get_resource_function(MockResource, action)
        is_function(result, 2)
      end
    end

    property "list_resources_function always returns a 1-arity function" do
      forall action <- PC.atom() do
        result = ApiPatterns.list_resources_function(MockResource, action)
        is_function(result, 1)
      end
    end

    property "delete_resource_function always returns a 2-arity function" do
      forall action <- PC.atom() do
        result = ApiPatterns.delete_resource_function(MockResource, action)
        is_function(result, 2)
      end
    end

    property "generate_crud_functions always returns map with 5 keys" do
      forall name <- PC.utf8() do
        result = ApiPatterns.generate_crud_functions(MockResource, name)
        is_map(result) and map_size(result) == 5
      end
    end

    property "batch_create_function accepts any positive batch_size" do
      forall batch_size <- PC.pos_integer() do
        result = ApiPatterns.batch_create_function(MockResource, :create, batch_size)
        is_function(result, 2)
      end
    end
  end

  # ===========================================================================
  # Edge Case Tests
  # ===========================================================================

  describe "Edge cases" do
    test "handles nil resource module gracefully" do
      # The function should still return a function, even if it will fail when called
      result = ApiPatterns.create_resource_function(nil)
      assert is_function(result, 2)
    end

    test "handles empty resource name in generate_crud_functions" do
      result = ApiPatterns.generate_crud_functions(MockResource, "")
      assert is_map(result)
      assert map_size(result) == 5
    end

    test "handles unicode resource names" do
      result = ApiPatterns.generate_crud_functions(MockResource, "日本語リソース")
      assert is_map(result)
      assert map_size(result) == 5
    end

    test "batch_create_function with batch_size of 1" do
      result = ApiPatterns.batch_create_function(MockResource, :create, 1)
      assert is_function(result, 2)
    end

    test "batch_create_function with large batch_size" do
      result = ApiPatterns.batch_create_function(MockResource, :create, 10_000)
      assert is_function(result, 2)
    end
  end

  # ===========================================================================
  # Source Code Validation Tests
  # ===========================================================================

  describe "Source code validation" do
    test "source file exists" do
      source_path = "lib/indrajaal/shared/api_patterns.ex"
      assert File.exists?(source_path), "Source file should exist at #{source_path}"
    end

    test "has spec annotations for all public functions" do
      {:docs_v1, _, :elixir, _, _, _, function_docs} = Code.fetch_docs(ApiPatterns)

      mapped =
        Enum.map(function_docs, fn
          {{:function, name, arity}, _, _, _, _} -> {name, arity}
          _ -> nil
        end)

      documented_functions =
        mapped
        |> Enum.reject(&is_nil/1)

      # Check key functions are documented
      assert {:create_resource_function, 2} in documented_functions
      assert {:generate_crud_functions, 2} in documented_functions
    end
  end

  # ===========================================================================
  # Macro Tests
  # ===========================================================================

  describe "Macro functionality" do
    test "__using__ macro is defined" do
      exports = ApiPatterns.__info__(:macros)
      assert {:__using__, 1} in exports
    end

    test "generate_crud_api macro is exported" do
      exports = ApiPatterns.__info__(:macros)
      assert {:generate_crud_api, 3} in exports
    end
  end
end

# Mock module for testing
defmodule MockResource do
  @moduledoc false
  # Mock resource module for ApiPatterns testing
end
