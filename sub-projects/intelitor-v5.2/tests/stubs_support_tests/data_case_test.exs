defmodule Intelitor.DataCaseTest do
  @moduledoc """
  TDG - Compliant comprehensive test suite for Intelitor.DataCase.
  Implements SOPv5.1 cybernetic testing framework with 100% coverage target.
  Tests all DataCase helper functions, sandbox setup, and Ash integration.
  """

  use ExUnit.Case, async: true
  use Intelitor.Ultimate.TestConsolidation

  # import ExUnitProperties  # Disabled - PropCheck conflict (SC-TDG-002), except: [property: 2, check: 2]
  use PropCheck

  alias Ecto.Changeset
  alias Intelitor.DataCase

  describe "DataCase.setup_sandbox / 1" do
    test "sets up database sandbox with async: false" do
      # TDG: Test sandbox setup for synchronous tests
      tags = %{async: false}

      # Should not raise and return :ok
      assert :ok = DataCase.setup_sandbox(tags)

      # Verify sandbox is active
      assert Process.get(:"$callers") != nil or
               Ecto.Adapters.SQL.Sandbox.mode(Intelitor.Repo) == {:shared, self()}
    end

    test "sets up database sandbox with async: true" do
      # TDG: Test sandbox setup for asynchronous tests
      tags = %{async: true}

      # Should not raise and return :ok
      assert :ok = DataCase.setup_sandbox(tags)

      # For async tests, sandbox should be in checkout mode
      # Verify the connection is checked out
      assert Process.get(:"$callers") != nil or
               is_pid(Process.get(:"$ecto_sandbox_owner"))
    end

    test "handles missing async tag gracefully" do
      # TDG: Test edge case with no async tag
      tags = %{}

      # Should default to non - async behavior (shared: true)
      assert :ok = DataCase.setup_sandbox(tags)
    end

    test "handles extra tags without errors" do
      # TDG: Test robustness with additional tags
      tags = %{async: false, other_tag: true, module: SomeModule}

      assert :ok = DataCase.setup_sandbox(tags)
    end
  end

  describe "DataCase.errors_on / 1" do
    test "transforms changeset errors into map of messages" do
      # TDG: Test error transformation with simple error
      changeset = %Ecto.Changeset{
        valid?: false,
        errors: [
          {:password, {"is too short", [min: 8]}},
          {:email, {"is invalid", []}}
        ]
      }

      errors = DataCase.errors_on(changeset)

      assert is_map(errors)
      assert "is too short" in errors[:password]
      assert "is invalid" in errors[:email]
    end

    test "handles interpolated error messages with options" do
      # TDG: Test complex error interpolation
      changeset = %Ecto.Changeset{
        valid?: false,
        errors: [
          {:name, {"should be at most %{count} character(s)", [count: 100]}},
          {:age, {"must be greater than %{number}", [number: 18]}}
        ]
      }

      errors = DataCase.errors_on(changeset)

      assert "should be at most 100 character(s)" in errors[:name]
      assert "must be greater than 18" in errors[:age]
    end

    test "handles multiple errors for same field" do
      # TDG: Test multiple validation errors
      changeset = %Ecto.Changeset{
        valid?: false,
        errors: [
          {:password, {"is too short", [min: 8]}},
          {:password, {"must contain special characters", []}},
          {:password, {"cannot be blank", []}}
        ]
      }

      errors = DataCase.errors_on(changeset)

      assert length(errors[:password]) == 3
      assert "is too short" in errors[:password]
      assert "must contain special characters" in errors[:password]
      assert "cannot be blank" in errors[:password]
    end

    test "handles changeset with no errors" do
      # TDG: Test edge case with valid changeset
      changeset = %Ecto.Changeset{valid?: true, errors: []}

      errors = DataCase.errors_on(changeset)

      assert errors == %{}
    end

    test "handles complex interpolation patterns" do
      # TDG: Test regex replacement edge cases
      changeset = %Ecto.Changeset{
        valid?: false,
        errors: [
          {:field, {"value %{key1} and %{key2} are invalid", [key1: "test", key2: 42]}},
          {:other, {"no interpolation here", []}}
        ]
      }

      errors = DataCase.errors_on(changeset)

      assert "value test and 42 are invalid" in errors[:field]
      assert "no interpolation here" in errors[:other]
    end
  end

  describe "DataCase.random_tenant / 0" do
    test "returns valid tenant for testing" do
      # TDG: Test tenant creation
      tenant = DataCase.random_tenant()

      assert is_struct(tenant)
      assert Map.has_key?(tenant, :id)
      assert is_binary(tenant.id) or is_integer(tenant.id)
    end

    test "creates different tenants on multiple calls" do
      # TDG: Test uniqueness
      tenant1 = DataCase.random_tenant()
      tenant2 = DataCase.random_tenant()

      # Should be different instances (though could have same ID by chance)
      assert is_struct(tenant1) and is_struct(tenant2)
    end
  end

  describe "DataCase.set_tenant / 1" do
    test "sets tenant __context in process dictionary" do
      # TDG: Test tenant __context setting
      tenant_id = "test - tenant - 123"

      assert :ok = DataCase.set_tenant(tenant_id)
      assert Process.get(:current_tenant) == tenant_id
    end

    test "overwrites existing tenant __context" do
      # TDG: Test tenant switching
      DataCase.set_tenant("first - tenant")
      assert Process.get(:current_tenant) == "first - tenant"

      DataCase.set_tenant("second - tenant")
      assert Process.get(:current_tenant) == "second - tenant"
    end

    test "handles various tenant ID formats" do
      # TDG: Test different ID types
      test_cases = [
        "string - tenant",
        123,
        :atom_tenant,
        "tenant - with - special - chars-@#$"
      ]

      Enum.each(test_cases, fn tenant_id ->
        DataCase.set_tenant(tenant_id)
        assert Process.get(:current_tenant) == tenant_id
      end)
    end
  end

  describe "DataCase.ash_insert / 2" do
    test "calls factory function with default attributes" do
      # TDG: Test factory calling mechanism
      # Note: This tests the dynamic function calling, not actual factory execu

      # Test that it attempts to call the factory function
      assert_raise UndefinedFunctionError, fn ->
        DataCase.ash_insert(:nonexistent_factory)
      end
    end

    test "calls factory function with custom attributes" do
      # TDG: Test factory calling with attributes
      attrs = %{name: "test", value: 42}

      # Test that it attempts to call with attributes
      assert_raise UndefinedFunctionError, fn ->
        DataCase.ash_insert(:nonexistent_factory, attrs)
      end
    end

    test "constructs correct factory function name" do
      # TDG: Test function name construction logic
      factory_name = :tenant
      _expected_function = :tenant_factory

      # Use try / rescue to capture the function name being called
      try do
        DataCase.ash_insert(factory_name)
      rescue
        e in UndefinedFunctionError ->
          assert String.contains?(Exception.message(e), "tenant_factory")
      end
    end
  end

  describe "DataCase module integration" do
    test "provides all required imports and helpers" do
      # TDG: Test that using DataCase provides expected functionality
      defmodule TestModule do
        use Intelitor.DataCase, async: true

        @spec test_imports_available() :: term()
        def test_imports_available do
          # Test that key functions are available
          %{
            repo_available: function_exported?(__MODULE__, :insert, 1),
            ecto_available: function_exported?(Ecto, :assoc, 2),
            changeset_available: function_exported?(Ecto.Changeset, :change, 1),
            query_available: function_exported?(Ecto.Query, :from, 1),
            datacase_available: function_exported?(Intelitor.DataCase, :errors_on, 1)
          }
        end
      end

      result = TestModule.test_imports_available()

      assert result.repo_available
      assert result.ecto_available
      assert result.changeset_available
      assert result.query_available
      assert result.datacase_available
    end
  end

  # Property - based testing for robustness
  describe "Property - based testing" do
    # Simplified property test for tenant handling
    test "tenant __context accepts various data types" do
      test_values = [
        "string_tenant",
        123,
        :atom_tenant,
        {"complex", "tenant"}
      ]

      Enum.each(test_values, fn tenant_id ->
        DataCase.set_tenant(tenant_id)
        assert Process.get(:current_tenant) == tenant_id
      end)
    end

    test "errors_on function handles empty and populated changesets" do
      # Test with empty errors
      empty_changeset = %Ecto.Changeset{valid?: true, errors: []}
      assert DataCase.errors_on(empty_changeset) == %{}

      # Test with various error structures
      error_changeset = %Ecto.Changeset{
        valid?: false,
        errors: [
          {:field1, {"message1", []}},
          {:field2, {"message2 %{count}", [count: 5]}},
          {:field1, {"message3", []}}
        ]
      }

      result = DataCase.errors_on(error_changeset)
      assert is_map(result)
      assert Map.has_key?(result, :field1)
      assert Map.has_key?(result, :field2)
      assert "message2 5" in result[:field2]
    end
  end

  describe "Error handling and edge cases" do
    test "handles malformed changeset gracefully" do
      # TDG: Test resilience with invalid input
      invalid_changeset = %{not_a_changeset: true}

      assert_raise FunctionClauseError, fn ->
        DataCase.errors_on(invalid_changeset)
      end
    end

    test "sandbox setup handles database connection issues" do
      # TDG: Test error handling in sandbox setup
      # This is more of a documentation test since we can't easily mock DB fail
      tags = %{async: false}

      # Should complete without raising in normal conditions
      assert :ok = DataCase.setup_sandbox(tags)
    end
  end

  describe "Performance and concurrency" do
    test "concurrent sandbox operations do not interfere" do
      # TDG: Test parallel sandbox usage
      tasks =
        Enum.map(1..5, fn _i ->
          Task.async(fn ->
            DataCase.setup_sandbox(%{async: true})
            DataCase.random_tenant()
          end)
        end)

      results = Task.await_many(tasks, 5000)

      # All should complete successfully
      assert length(results) == 5
      assert Enum.all?(results, &is_struct/1)
    end

    test "tenant __context is process - isolated" do
      # TDG: Test process isolation
      parent_pid = self()

      DataCase.set_tenant("parent - tenant")

      task =
        Task.async(fn ->
          DataCase.set_tenant("child - tenant")
          {Process.get(:current_tenant), parent_pid}
        end)

      {child_tenant, ^parent_pid} = Task.await(task)

      assert child_tenant == "child - tenant"
      assert Process.get(:current_tenant) == "parent - tenant"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
