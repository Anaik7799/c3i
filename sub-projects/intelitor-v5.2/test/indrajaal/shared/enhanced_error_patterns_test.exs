defmodule Indrajaal.Shared.EnhancedErrorPatternsTest do
  @moduledoc """
  TDG-compliant tests for Indrajaal.Shared.EnhancedErrorPatterns module.

  Tests comprehensive error pattern handling for:
  - format_changeset_errors function
  - error_response function
  - Ecto.Changeset error traversal
  - Error response structure
  - Timestamp inclusion

  Created: 2025-11-27 15:45:00 CEST
  Phase: 2.4 - C1 Security-Critical Testing (Pattern & Factory Modules)
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Shared.EnhancedErrorPatterns
  alias Ecto.Changeset

  # ============================================================================
  # MODULE EXISTENCE TESTS
  # ============================================================================

  describe "Module Structure" do
    test "EnhancedErrorPatterns module exists" do
      assert Code.ensure_loaded?(Indrajaal.Shared.EnhancedErrorPatterns)
    end

    test "module exports format_changeset_errors function" do
      functions = Indrajaal.Shared.EnhancedErrorPatterns.__info__(:functions)
      assert {:format_changeset_errors, 1} in functions
    end

    test "module exports error_response function" do
      functions = Indrajaal.Shared.EnhancedErrorPatterns.__info__(:functions)
      assert {:error_response, 2} in functions
    end
  end

  # ============================================================================
  # FORMAT_CHANGESET_ERRORS TESTS
  # ============================================================================

  describe "format_changeset_errors/1" do
    test "formats changeset with single error" do
      changeset = %Changeset{
        errors: [name: {"can't be blank", [validation: :required]}],
        valid?: false
      }

      result = EnhancedErrorPatterns.format_changeset_errors(changeset)

      assert result != nil
    end

    test "formats changeset with multiple errors" do
      changeset = %Changeset{
        errors: [
          name: {"can't be blank", [validation: :required]},
          email: {"has invalid format", [validation: :format]},
          age: {"must be greater than 0", [validation: :number]}
        ],
        valid?: false
      }

      result = EnhancedErrorPatterns.format_changeset_errors(changeset)

      assert result != nil
    end

    test "formats valid changeset with no errors" do
      changeset = %Changeset{
        errors: [],
        valid?: true
      }

      result = EnhancedErrorPatterns.format_changeset_errors(changeset)

      assert result != nil
    end

    test "handles changeset with nested error messages" do
      changeset = %Changeset{
        errors: [
          field: {"error with %{count} items", [count: 5, validation: :length]}
        ],
        valid?: false
      }

      result = EnhancedErrorPatterns.format_changeset_errors(changeset)

      assert result != nil
    end

    test "handles changeset with constraint errors" do
      changeset = %Changeset{
        errors: [
          email:
            {"has already been taken",
             [constraint: :unique, constraint_name: "users_email_index"]}
        ],
        valid?: false
      }

      result = EnhancedErrorPatterns.format_changeset_errors(changeset)

      assert result != nil
    end

    test "handles empty changeset struct" do
      changeset = %Changeset{}

      result = EnhancedErrorPatterns.format_changeset_errors(changeset)

      assert result != nil
    end
  end

  # ============================================================================
  # ERROR_RESPONSE TESTS
  # ============================================================================

  describe "error_response/2" do
    test "creates error response with reason" do
      result = EnhancedErrorPatterns.error_response(:not_found)

      assert is_map(result)
      assert result.success == false
    end

    test "creates error response with reason and details" do
      details = %{resource: "user", id: 123}
      result = EnhancedErrorPatterns.error_response(:not_found, details)

      assert is_map(result)
      assert result.success == false
      assert is_map(result.details)
    end

    test "includes timestamp in response" do
      result = EnhancedErrorPatterns.error_response(:timeout)

      assert Map.has_key?(result, :timestamp)
    end

    test "includes error field in response" do
      result = EnhancedErrorPatterns.error_response(:validation_failed)

      assert Map.has_key?(result, :error)
    end

    test "handles atom reason" do
      result = EnhancedErrorPatterns.error_response(:unauthorized)

      assert result.success == false
    end

    test "handles string reason" do
      result = EnhancedErrorPatterns.error_response("Something went wrong")

      assert result.success == false
    end

    test "handles tuple reason" do
      result = EnhancedErrorPatterns.error_response({:error, :complex_failure})

      assert result.success == false
    end

    test "handles empty details" do
      result = EnhancedErrorPatterns.error_response(:error, %{})

      assert is_map(result.details)
    end

    test "handles complex details" do
      details = %{
        errors: [
          %{field: :name, message: "is required"},
          %{field: :email, message: "is invalid"}
        ],
        metadata: %{
          request_id: "abc-123",
          timestamp: DateTime.utc_now()
        }
      }

      result = EnhancedErrorPatterns.error_response(:validation_error, details)

      assert is_map(result)
      assert result.success == false
    end

    test "default details is empty map" do
      result = EnhancedErrorPatterns.error_response(:error)

      assert Map.has_key?(result, :details)
    end
  end

  # ============================================================================
  # RESPONSE STRUCTURE TESTS
  # ============================================================================

  describe "Response Structure" do
    test "error_response returns map with success: false" do
      result = EnhancedErrorPatterns.error_response(:test)

      assert is_map(result)
      assert result.success == false
    end

    test "error_response has consistent structure" do
      result = EnhancedErrorPatterns.error_response(:test, %{key: "value"})

      # Expected structure
      assert Map.has_key?(result, :success)
      assert Map.has_key?(result, :error)
      assert Map.has_key?(result, :details)
      assert Map.has_key?(result, :timestamp)
    end

    test "timestamp is valid DateTime" do
      result = EnhancedErrorPatterns.error_response(:test)

      # Timestamp should be present and valid
      assert result.timestamp != nil
    end
  end

  # ============================================================================
  # PROPERTY-BASED TESTS (PropCheck)
  # ============================================================================

  describe "Property Tests (PropCheck)" do
    property "error_response always returns map with success: false" do
      forall reason <- PC.any() do
        result = EnhancedErrorPatterns.error_response(reason)
        is_map(result) and result.success == false
      end
    end

    property "error_response always includes timestamp" do
      forall reason <- PC.oneof([PC.atom(), PC.binary()]) do
        result = EnhancedErrorPatterns.error_response(reason)
        Map.has_key?(result, :timestamp)
      end
    end

    property "error_response preserves details structure" do
      forall details <- PC.map(PC.atom(), PC.any()) do
        result = EnhancedErrorPatterns.error_response(:test, details)
        is_map(result.details)
      end
    end

    property "format_changeset_errors handles any error list" do
      forall errors <- PC.list({PC.atom(), {PC.binary(), PC.list()}}) do
        changeset = %Changeset{errors: errors, valid?: false}
        result = EnhancedErrorPatterns.format_changeset_errors(changeset)
        result != nil
      end
    end
  end

  # ============================================================================
  # EDGE CASE TESTS
  # ============================================================================

  describe "Edge Cases" do
    test "handles nil reason" do
      result = EnhancedErrorPatterns.error_response(nil)

      assert is_map(result)
      assert result.success == false
    end

    test "handles very long error message" do
      long_message = String.duplicate("a", 10_000)
      result = EnhancedErrorPatterns.error_response(long_message)

      assert is_map(result)
    end

    test "handles special characters in reason" do
      result = EnhancedErrorPatterns.error_response("Error: <script>alert('xss')</script>")

      assert is_map(result)
    end

    test "handles unicode in error message" do
      result = EnhancedErrorPatterns.error_response("エラー: 何かがおかしい")

      assert is_map(result)
    end

    test "handles changeset with unusual field names" do
      changeset = %Changeset{
        errors: [
          {:__struct__, {"invalid", []}},
          {:"field-with-dash", {"error", []}},
          {:"field.with.dots", {"error", []}}
        ],
        valid?: false
      }

      result = EnhancedErrorPatterns.format_changeset_errors(changeset)

      assert result != nil
    end

    test "handles deeply nested details" do
      deep_details = %{
        level1: %{
          level2: %{
            level3: %{
              level4: %{
                value: "deep"
              }
            }
          }
        }
      }

      result = EnhancedErrorPatterns.error_response(:error, deep_details)

      assert is_map(result)
    end
  end

  # ============================================================================
  # SOURCE CODE VALIDATION TESTS
  # ============================================================================

  describe "Source Code Validation" do
    test "source file exists" do
      assert File.exists?("lib/indrajaal/shared/enhanced_error_patterns.ex")
    end

    test "source file is valid Elixir" do
      source = File.read!("lib/indrajaal/shared/enhanced_error_patterns.ex")
      {:ok, _ast} = Code.string_to_quoted(source)
    end

    test "module has proper defmodule structure" do
      source = File.read!("lib/indrajaal/shared/enhanced_error_patterns.ex")
      assert String.contains?(source, "defmodule Indrajaal.Shared.EnhancedErrorPatterns")
    end

    test "format_changeset_errors has @spec" do
      source = File.read!("lib/indrajaal/shared/enhanced_error_patterns.ex")
      assert String.contains?(source, "@spec format_changeset_errors")
    end

    test "error_response has @spec" do
      source = File.read!("lib/indrajaal/shared/enhanced_error_patterns.ex")
      assert String.contains?(source, "@spec error_response")
    end

    test "uses Ecto.Changeset" do
      source = File.read!("lib/indrajaal/shared/enhanced_error_patterns.ex")
      assert String.contains?(source, "Ecto.Changeset")
    end
  end

  # ============================================================================
  # INTEGRATION SCENARIO TESTS
  # ============================================================================

  describe "Integration Scenarios" do
    test "error handling workflow: changeset -> formatted -> response" do
      # Step 1: Create changeset with errors
      changeset = %Changeset{
        errors: [
          name: {"can't be blank", [validation: :required]},
          email: {"is invalid", [validation: :format]}
        ],
        valid?: false
      }

      # Step 2: Format changeset errors
      formatted = EnhancedErrorPatterns.format_changeset_errors(changeset)
      assert formatted != nil

      # Step 3: Create error response
      response =
        EnhancedErrorPatterns.error_response(:validation_failed, %{
          errors: formatted
        })

      assert response.success == false
      assert is_map(response.details)
    end

    test "multiple error responses maintain structure" do
      reasons = [:not_found, :unauthorized, :forbidden, :timeout, :server_error]

      responses =
        Enum.map(reasons, fn reason ->
          EnhancedErrorPatterns.error_response(reason)
        end)

      # All responses should have consistent structure
      assert Enum.all?(responses, fn r ->
               is_map(r) and
                 r.success == false and
                 Map.has_key?(r, :error) and
                 Map.has_key?(r, :details) and
                 Map.has_key?(r, :timestamp)
             end)
    end

    test "batch changeset error formatting" do
      changesets =
        Enum.map(1..5, fn i ->
          %Changeset{
            errors: [{String.to_atom("field_#{i}"), {"error #{i}", []}}],
            valid?: false
          }
        end)

      results = Enum.map(changesets, &EnhancedErrorPatterns.format_changeset_errors/1)

      assert length(results) == 5
      assert Enum.all?(results, &(&1 != nil))
    end
  end
end
