defmodule Indrajaal.Shared.EnhancedErrorHelpersTest do
  @moduledoc """
  TDG-compliant tests for Indrajaal.Shared.EnhancedErrorHelpers module.

  Tests enhanced error handling utilities for:
  - log_structured_error function
  - log_structured_warning function
  - error_response function
  - analyze_validation_errors function

  Created: 2025-11-27 16:30:00 CEST
  Phase: 3.0 - C2 High-Impact Testing (Enhanced Error Helpers)
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  import ExUnit.CaptureLog

  alias Indrajaal.Shared.EnhancedErrorHelpers
  alias Ecto.Changeset

  # ============================================================================
  # MODULE EXISTENCE TESTS
  # ============================================================================

  describe "Module Structure" do
    test "EnhancedErrorHelpers module exists" do
      assert Code.ensure_loaded?(Indrajaal.Shared.EnhancedErrorHelpers)
    end

    test "module exports log_structured_error function" do
      functions = Indrajaal.Shared.EnhancedErrorHelpers.__info__(:functions)
      assert {:log_structured_error, 3} in functions
    end

    test "module exports log_structured_warning function" do
      functions = Indrajaal.Shared.EnhancedErrorHelpers.__info__(:functions)
      assert {:log_structured_warning, 3} in functions
    end

    test "module exports error_response function" do
      functions = Indrajaal.Shared.EnhancedErrorHelpers.__info__(:functions)
      assert {:error_response, 2} in functions
    end

    test "module exports analyze_validation_errors function" do
      functions = Indrajaal.Shared.EnhancedErrorHelpers.__info__(:functions)
      assert {:analyze_validation_errors, 2} in functions
    end
  end

  # ============================================================================
  # LOG_STRUCTURED_ERROR TESTS
  # ============================================================================

  describe "log_structured_error/3" do
    test "logs error with domain context" do
      log =
        capture_log(fn ->
          EnhancedErrorHelpers.log_structured_error(
            {:error, "test error"},
            :access_control,
            %{user_id: 123}
          )
        end)

      # Should log something
      assert log != ""
    end

    test "accepts error with empty context" do
      log =
        capture_log(fn ->
          EnhancedErrorHelpers.log_structured_error(
            {:error, "simple error"},
            :accounts
          )
        end)

      assert log != ""
    end

    test "handles atom error type" do
      log =
        capture_log(fn ->
          EnhancedErrorHelpers.log_structured_error(
            :not_found,
            :devices,
            %{}
          )
        end)

      assert is_binary(log)
    end

    test "handles string error type" do
      log =
        capture_log(fn ->
          EnhancedErrorHelpers.log_structured_error(
            "Connection failed",
            :communication,
            %{}
          )
        end)

      assert is_binary(log)
    end
  end

  # ============================================================================
  # LOG_STRUCTURED_WARNING TESTS
  # ============================================================================

  describe "log_structured_warning/3" do
    test "logs warning with domain context" do
      log =
        capture_log(fn ->
          EnhancedErrorHelpers.log_structured_warning(
            :analytics,
            "Slow query detected",
            %{query_time: 5000}
          )
        end)

      assert log =~ "warn"
    end

    test "returns warning tuple" do
      result =
        EnhancedErrorHelpers.log_structured_warning(
          :performance,
          "High memory usage",
          %{}
        )

      assert {:warning, data} = result
      assert is_map(data)
    end

    test "warning data includes domain" do
      {:warning, data} =
        EnhancedErrorHelpers.log_structured_warning(
          :compliance,
          "Audit required",
          %{}
        )

      assert data.domain == :compliance
    end

    test "warning data includes message" do
      {:warning, data} =
        EnhancedErrorHelpers.log_structured_warning(
          :alarms,
          "Threshold exceeded",
          %{}
        )

      assert data.message == "Threshold exceeded"
    end

    test "warning data includes timestamp" do
      {:warning, data} =
        EnhancedErrorHelpers.log_structured_warning(
          :video,
          "Stream interrupted",
          %{}
        )

      assert %DateTime{} = data.timestamp
    end

    test "warning data includes context" do
      {:warning, data} =
        EnhancedErrorHelpers.log_structured_warning(
          :maintenance,
          "Scheduled maintenance",
          %{window: "2h"}
        )

      assert data.__context == %{window: "2h"}
    end
  end

  # ============================================================================
  # ERROR_RESPONSE TESTS
  # ============================================================================

  describe "error_response/2" do
    test "creates error response with success false" do
      result = EnhancedErrorHelpers.error_response(:not_found)

      assert result.success == false
    end

    test "includes error field" do
      result = EnhancedErrorHelpers.error_response(:unauthorized)

      assert Map.has_key?(result, :error)
    end

    test "includes timestamp" do
      result = EnhancedErrorHelpers.error_response(:timeout)

      assert Map.has_key?(result, :timestamp)
      assert %DateTime{} = result.timestamp
    end

    test "includes custom message" do
      result = EnhancedErrorHelpers.error_response(:validation_failed, "Invalid input")

      assert result.message == "Invalid input"
    end

    test "uses default message when not provided" do
      result = EnhancedErrorHelpers.error_response(:unknown_error)

      assert result.message == "An error occurred"
    end

    test "handles tuple error" do
      result = EnhancedErrorHelpers.error_response({:error, :connection_refused})

      assert result.success == false
    end

    test "handles string error" do
      result = EnhancedErrorHelpers.error_response("Something went wrong")

      assert result.success == false
    end
  end

  # ============================================================================
  # ANALYZE_VALIDATION_ERRORS TESTS
  # ============================================================================

  describe "analyze_validation_errors/2" do
    test "analyzes changeset validation errors" do
      changeset = %Changeset{
        errors: [name: {"can't be blank", [validation: :required]}],
        valid?: false
      }

      log =
        capture_log(fn ->
          EnhancedErrorHelpers.analyze_validation_errors(:accounts, changeset)
        end)

      assert log =~ "Validation errors"
    end

    test "returns error tuple with domain" do
      changeset = %Changeset{
        errors: [email: {"is invalid", []}],
        valid?: false
      }

      {:error, data} = EnhancedErrorHelpers.analyze_validation_errors(:users, changeset)

      assert data.domain == :users
    end

    test "includes changeset in result" do
      changeset = %Changeset{errors: [], valid?: true}

      {:error, data} = EnhancedErrorHelpers.analyze_validation_errors(:devices, changeset)

      assert data.changeset == changeset
    end

    test "includes timestamp in result" do
      changeset = %Changeset{errors: [], valid?: true}

      {:error, data} = EnhancedErrorHelpers.analyze_validation_errors(:sites, changeset)

      assert %DateTime{} = data.timestamp
    end

    test "extracts errors from changeset" do
      changeset = %Changeset{
        errors: [
          name: {"is required", []},
          status: {"is invalid", []}
        ],
        valid?: false
      }

      {:error, data} = EnhancedErrorHelpers.analyze_validation_errors(:alarms, changeset)

      assert is_list(data.errors)
    end
  end

  # ============================================================================
  # PROPERTY-BASED TESTS (PropCheck)
  # ============================================================================

  describe "Property Tests (PropCheck)" do
    property "error_response always returns map with success: false" do
      forall error <- PC.any() do
        result = EnhancedErrorHelpers.error_response(error)
        is_map(result) and result.success == false
      end
    end

    property "error_response always includes timestamp" do
      forall error <- PC.oneof([PC.atom(), PC.binary()]) do
        result = EnhancedErrorHelpers.error_response(error)
        Map.has_key?(result, :timestamp)
      end
    end

    property "log_structured_warning always returns warning tuple" do
      forall {domain, msg} <- {PC.atom(), PC.binary()} do
        result = EnhancedErrorHelpers.log_structured_warning(domain, msg, %{})

        case result do
          {:warning, data} when is_map(data) -> true
          _ -> false
        end
      end
    end

    property "analyze_validation_errors returns error tuple" do
      forall domain <- PC.atom() do
        changeset = %Changeset{errors: [], valid?: true}
        result = EnhancedErrorHelpers.analyze_validation_errors(domain, changeset)

        case result do
          {:error, data} when is_map(data) -> true
          _ -> false
        end
      end
    end
  end

  # ============================================================================
  # EDGE CASE TESTS
  # ============================================================================

  describe "Edge Cases" do
    test "module info returns expected structure" do
      info = EnhancedErrorHelpers.__info__(:module)
      assert info == Indrajaal.Shared.EnhancedErrorHelpers
    end

    test "error_response handles nil error" do
      result = EnhancedErrorHelpers.error_response(nil)

      assert result.success == false
    end

    test "log_structured_warning handles empty message" do
      {:warning, data} =
        EnhancedErrorHelpers.log_structured_warning(
          :test,
          "",
          %{}
        )

      assert data.message == ""
    end

    test "analyze_validation_errors handles empty changeset" do
      changeset = %Changeset{}

      {:error, data} = EnhancedErrorHelpers.analyze_validation_errors(:domain, changeset)

      assert is_map(data)
    end
  end

  # ============================================================================
  # SOURCE CODE VALIDATION TESTS
  # ============================================================================

  describe "Source Code Validation" do
    test "source file exists" do
      assert File.exists?("lib/indrajaal/shared/enhanced_error_helpers.ex")
    end

    test "source file is valid Elixir" do
      source = File.read!("lib/indrajaal/shared/enhanced_error_helpers.ex")
      {:ok, _ast} = Code.string_to_quoted(source)
    end

    test "module has proper defmodule structure" do
      source = File.read!("lib/indrajaal/shared/enhanced_error_helpers.ex")
      assert String.contains?(source, "defmodule Indrajaal.Shared.EnhancedErrorHelpers")
    end

    test "log_structured_error has @spec" do
      source = File.read!("lib/indrajaal/shared/enhanced_error_helpers.ex")
      assert String.contains?(source, "@spec log_structured_error")
    end

    test "log_structured_warning has @spec" do
      source = File.read!("lib/indrajaal/shared/enhanced_error_helpers.ex")
      assert String.contains?(source, "@spec log_structured_warning")
    end

    test "error_response has @spec" do
      source = File.read!("lib/indrajaal/shared/enhanced_error_helpers.ex")
      assert String.contains?(source, "@spec error_response")
    end

    test "analyze_validation_errors has @spec" do
      source = File.read!("lib/indrajaal/shared/enhanced_error_helpers.ex")
      assert String.contains?(source, "@spec analyze_validation_errors")
    end

    test "uses Logger" do
      source = File.read!("lib/indrajaal/shared/enhanced_error_helpers.ex")
      assert String.contains?(source, "require Logger")
    end
  end

  # ============================================================================
  # INTEGRATION SCENARIO TESTS
  # ============================================================================

  describe "Integration Scenarios" do
    test "error handling workflow" do
      # Log an error
      log1 =
        capture_log(fn ->
          EnhancedErrorHelpers.log_structured_error(
            {:error, :database_error},
            :accounts,
            %{query: "SELECT *"}
          )
        end)

      # Create error response
      response =
        EnhancedErrorHelpers.error_response(
          :database_error,
          "Database connection failed"
        )

      assert log1 != ""
      assert response.success == false
      assert response.message == "Database connection failed"
    end

    test "validation error workflow" do
      changeset = %Changeset{
        errors: [
          name: {"can't be blank", [validation: :required]},
          email: {"has invalid format", [validation: :format]}
        ],
        valid?: false
      }

      # Analyze validation errors
      log =
        capture_log(fn ->
          {:error, data} =
            EnhancedErrorHelpers.analyze_validation_errors(
              :users,
              changeset
            )

          assert data.domain == :users
          assert length(data.errors) == 2
        end)

      assert log =~ "Validation errors"
    end

    test "all error functions are accessible" do
      functions = EnhancedErrorHelpers.__info__(:functions)

      error_functions = [
        {:log_structured_error, 3},
        {:log_structured_warning, 3},
        {:error_response, 2},
        {:analyze_validation_errors, 2}
      ]

      Enum.each(error_functions, fn func ->
        assert func in functions, "Expected #{inspect(func)} to be in functions"
      end)
    end
  end
end
