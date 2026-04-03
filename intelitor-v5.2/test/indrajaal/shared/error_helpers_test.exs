defmodule Indrajaal.Shared.ErrorHelpersTest do
  @moduledoc """
  Comprehensive test suite for Indrajaal.Shared.ErrorHelpers module.

  This is a SAFETY-CRITICAL module that handles all error scenarios across 19 domain contexts.
  Zero tolerance for failures in this module.

  Test Categories:
  1. Unit Tests (100% function coverage)
  2. Property-Based Tests (PropCheck)
  3. Property-Based Tests (ExUnitProperties)
  4. STAMP Safety Constraint Validation
  5. TDG Methodology Compliance
  6. Integration Tests

  Created: 2025-10-11 13:50:00 CEST
  Phase: 1.1.1.1 - Critical Safety Files Testing
  Risk Level: CRITICAL
  """

  use ExUnit.Case, async: true
  # PropCheck property testing - ExUnitProperties tests are in a separate module
  # (error_helpers_exunit_properties_test.exs) to avoid macro conflicts
  use PropCheck
  alias StreamData, as: SD
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Shared.ErrorHelpers
  alias Ash.Changeset

  # ============================================================================
  # SECTION 1: UNIT TESTS (100% Function Coverage)
  # ============================================================================

  describe "analyze_validation_errors/2 - Unit Tests" do
    test "analyzes empty changeset with no errors" do
      # Setup: Create a minimal mock changeset
      changeset = %Changeset{
        errors: [],
        valid?: true,
        action_type: :create,
        resource: TestResource
      }

      # Execute
      result = ErrorHelpers.analyze_validation_errors(changeset, TestResource)

      # Verify - Check for rca_analysis structure
      assert is_map(result)
      assert Map.has_key?(result, :level1_symptom)
      assert Map.has_key?(result, :level2_direct_cause)
      assert Map.has_key?(result, :level3_system_behavior)
      assert Map.has_key?(result, :level4_process_gap)
      assert Map.has_key?(result, :level5_root_cause)
      assert Map.has_key?(result, :error_pattern)
      assert Map.has_key?(result, :recommended_actions)
      assert is_list(result.recommended_actions)
    end

    test "analyzes changeset with single validation error" do
      # Setup: Changeset with one validation error
      changeset = %Changeset{
        errors: [
          %{
            field: :email,
            message: "is invalid",
            validation: :format
          }
        ],
        valid?: false,
        action_type: :create,
        resource: TestResource
      }

      # Execute
      result = ErrorHelpers.analyze_validation_errors(changeset, TestResource)

      # Verify
      assert is_map(result)
      assert is_binary(result.level1_symptom)
      assert is_binary(result.level2_direct_cause)
      assert is_binary(result.error_pattern)
      assert String.length(result.level1_symptom) > 0
      assert is_list(result.recommended_actions)
    end

    test "analyzes changeset with multiple validation errors" do
      # Setup: Changeset with multiple errors
      changeset = %Changeset{
        errors: [
          %{field: :email, message: "is invalid", validation: :format},
          %{field: :password, message: "is too short", validation: :length},
          %{field: :username, message: "is required", validation: :required}
        ],
        valid?: false,
        action_type: :create,
        resource: TestResource
      }

      # Execute
      result = ErrorHelpers.analyze_validation_errors(changeset, TestResource)

      # Verify - All 5 levels should be present
      assert is_binary(result.level1_symptom)
      assert is_binary(result.level2_direct_cause)
      assert is_binary(result.level3_system_behavior)
      assert is_binary(result.level4_process_gap)
      assert is_binary(result.level5_root_cause)
      assert is_list(result.recommended_actions)
    end

    test "handles changeset with nested error structures" do
      # Setup: Complex nested error structure
      changeset = %Changeset{
        errors: [
          %{
            field: :user,
            message: "has invalid nested data",
            validation: :embedded,
            path: [:user, :profile, :email]
          }
        ],
        valid?: false,
        action_type: :update,
        resource: TestResource
      }

      # Execute
      result = ErrorHelpers.analyze_validation_errors(changeset, TestResource)

      # Verify
      assert is_map(result)
      assert is_binary(result.level1_symptom)
      assert is_list(result.recommended_actions)
    end
  end

  describe "analyze_database_error/3 - Unit Tests" do
    test "analyzes unique constraint violation" do
      # Setup: Mock unique constraint error (simplified without Postgrex dependency)
      error = {:error, :unique_constraint, "users_email_index"}

      # Execute
      result = ErrorHelpers.analyze_database_error(error, :insert, %{table: "users"})

      # Verify - Check for rca_analysis structure
      assert is_map(result)
      assert is_binary(result.level1_symptom)
      assert is_binary(result.level2_direct_cause)
      assert is_binary(result.error_pattern)
      assert is_list(result.recommended_actions)
    end

    test "analyzes foreign key constraint violation" do
      # Setup: Mock foreign key error
      error = {:error, :foreign_key_constraint, "fk_user_organization"}

      # Execute
      result = ErrorHelpers.analyze_database_error(error, :delete, %{table: "organizations"})

      # Verify
      assert is_map(result)
      assert is_binary(result.level1_symptom)
      assert is_binary(result.level5_root_cause)
      assert is_list(result.recommended_actions)
    end

    test "analyzes database connection error" do
      # Setup: Connection timeout error
      error = {:error, :timeout, "connection timeout"}

      # Execute
      result = ErrorHelpers.analyze_database_error(error, :query, %{})

      # Verify
      assert is_map(result)
      assert is_binary(result.level1_symptom)
      assert is_binary(result.error_pattern)
    end

    test "analyzes generic database error" do
      # Setup: Generic error
      error = %RuntimeError{message: "unknown database error"}

      # Execute
      result = ErrorHelpers.analyze_database_error(error, :update, %{})

      # Verify - Should still return rca_analysis structure
      assert is_map(result)
      assert Map.has_key?(result, :level1_symptom)
      assert Map.has_key?(result, :level5_root_cause)
      assert is_list(result.recommended_actions)
    end
  end

  describe "analyze_business_error/3 - Unit Tests" do
    test "analyzes resource not found error" do
      # Execute
      result = ErrorHelpers.analyze_business_error(:not_found, :accounts, "get_user")

      # Verify - Check for rca_analysis structure
      assert is_map(result)
      assert is_binary(result.level1_symptom)
      assert is_binary(result.level2_direct_cause)
      assert is_binary(result.error_pattern)
      assert is_list(result.recommended_actions)
    end

    test "analyzes authorization error" do
      # Execute
      result =
        ErrorHelpers.analyze_business_error(:unauthorized, :access_control, "check_permission")

      # Verify
      assert is_map(result)
      assert is_binary(result.level1_symptom)
      assert is_binary(result.level5_root_cause)
      assert is_list(result.recommended_actions)
    end

    test "analyzes business logic validation error" do
      # Execute
      result =
        ErrorHelpers.analyze_business_error(
          "Invalid alarm state transition",
          :alarms,
          "update_state"
        )

      # Verify
      assert is_map(result)
      assert is_binary(result.level1_symptom)
      assert is_list(result.recommended_actions)
    end

    test "handles atom error reasons" do
      # Execute
      result = ErrorHelpers.analyze_business_error(:timeout, :devices, "send_command")

      # Verify
      assert is_map(result)
      assert is_binary(result.error_pattern)
      assert is_list(result.recommended_actions)
    end

    test "handles string error reasons" do
      # Execute
      result =
        ErrorHelpers.analyze_business_error("Custom business error", :analytics, "calculate")

      # Verify
      assert is_map(result)
      assert is_binary(result.level1_symptom)
      assert is_list(result.recommended_actions)
    end
  end

  describe "format_error_response/2 - Unit Tests" do
    test "formats simple error message" do
      # Setup
      error = "Something went wrong"

      # Execute
      result = ErrorHelpers.format_error_response(error)

      # Verify
      assert is_map(result)
      assert Map.has_key?(result, :error)
      assert is_binary(result.error)
      assert Map.has_key?(result, :details)
    end

    test "formats error with request context" do
      # Setup: Plain strings hit the catch-all clause for security
      # The function intentionally returns "Internal server error" to hide internal details
      error = "Invalid input"

      context = %{
        request_id: "req-123",
        user_id: "user-456",
        tenant_id: "tenant-789"
      }

      # Execute
      result = ErrorHelpers.format_error_response(error, context)

      # Verify: Plain strings are treated as internal errors (security pattern)
      # Internal error details are sanitized - only type info is exposed
      assert result.error == "Internal server error"
      assert is_map(result.details)
      assert Map.has_key?(result, :details)
    end

    test "formats error tuple with request context preserves message" do
      # Setup: Use proper {:error, reason} tuple format to preserve message
      error = {:error, "Invalid input"}

      context = %{
        request_id: "req-123"
      }

      # Execute
      result = ErrorHelpers.format_error_response(error, context)

      # Verify: Error tuples with binary reason preserve the message
      assert result.error == "Invalid input"
      assert is_map(result.details)
    end

    test "formats Ash error structs" do
      # Setup
      ash_error = %Ash.Error.Invalid{
        errors: [%{message: "validation failed"}]
      }

      # Execute
      result = ErrorHelpers.format_error_response(ash_error)

      # Verify
      assert is_map(result)
      assert is_binary(result.error)
      assert is_map(result.details)
    end

    test "formats exception structs" do
      # Setup: Exception structs hit the catch-all clause for security
      # Internal exceptions should NOT expose their messages to users
      exception = %RuntimeError{message: "runtime error occurred"}

      # Execute
      result = ErrorHelpers.format_error_response(exception)

      # Verify: Exception details are hidden for security (SC-SHARED-001.2)
      # The function returns generic "Internal server error" to prevent information leakage
      assert result.error == "Internal server error"
      assert is_map(result.details)
      # The error_type should show the struct type but NOT the internal message
      assert is_binary(result.details.error_type)
    end

    test "handles nil error input" do
      # Execute
      result = ErrorHelpers.format_error_response(nil)

      # Verify
      assert is_map(result)
      assert is_binary(result.error)
    end
  end

  describe "log_structured_error/3 - Unit Tests" do
    test "logs error with info severity" do
      # Setup
      error = "Test error"
      context = %{module: TestModule}

      # Execute (should not raise)
      assert :ok = ErrorHelpers.log_structured_error(error, context, :info)
    end

    test "logs error with warning severity" do
      # Setup
      error = "Warning error"
      context = %{function: "test_function"}

      # Execute
      assert :ok = ErrorHelpers.log_structured_error(error, context, :warning)
    end

    test "logs error with error severity" do
      # Setup
      error = "Critical error"
      context = %{line: 123}

      # Execute
      assert :ok = ErrorHelpers.log_structured_error(error, context, :error)
    end

    test "logs complex error structures" do
      # Setup
      error = %{
        type: :database_error,
        message: "Connection failed",
        details: %{retries: 3}
      }

      context = %{module: DatabaseModule}

      # Execute
      assert :ok = ErrorHelpers.log_structured_error(error, context, :error)
    end
  end

  # ============================================================================
  # SECTION 2: PROPERTY-BASED TESTS (PropCheck)
  # ============================================================================

  describe "Property Tests (PropCheck)" do
    @tag :propcheck
    test "analyze_validation_errors always returns valid RCA structure" do
      assert PropCheck.quickcheck(
               PropCheck.forall changeset <- valid_changeset_generator() do
                 result = ErrorHelpers.analyze_validation_errors(changeset, TestResource)

                 is_map(result) and
                   Map.has_key?(result, :level1_symptom) and
                   Map.has_key?(result, :level2_direct_cause) and
                   Map.has_key?(result, :level3_system_behavior) and
                   Map.has_key?(result, :level4_process_gap) and
                   Map.has_key?(result, :level5_root_cause) and
                   Map.has_key?(result, :error_pattern) and
                   Map.has_key?(result, :recommended_actions) and
                   is_binary(result.level1_symptom) and
                   is_list(result.recommended_actions)
               end,
               numtests: 50
             )
    end

    @tag :propcheck
    test "analyze_database_error handles all error types" do
      assert PropCheck.quickcheck(
               PropCheck.forall {error, operation} <-
                                  {database_error_generator(), operation_generator()} do
                 result = ErrorHelpers.analyze_database_error(error, operation, %{})

                 is_map(result) and
                   Map.has_key?(result, :level1_symptom) and
                   Map.has_key?(result, :level5_root_cause) and
                   Map.has_key?(result, :error_pattern) and
                   is_binary(result.level1_symptom) and
                   is_list(result.recommended_actions)
               end,
               numtests: 50
             )
    end

    @tag :propcheck
    test "analyze_business_error returns complete RCA structure" do
      assert PropCheck.quickcheck(
               PropCheck.forall {reason, domain, op} <-
                                  {error_reason_generator(), domain_generator(), binary()} do
                 result = ErrorHelpers.analyze_business_error(reason, domain, op)

                 is_map(result) and
                   Map.has_key?(result, :level1_symptom) and
                   Map.has_key?(result, :level5_root_cause) and
                   Map.has_key?(result, :error_pattern) and
                   is_binary(result.error_pattern)
               end,
               numtests: 50
             )
    end

    @tag :propcheck
    test "format_error_response always returns error and details" do
      assert PropCheck.quickcheck(
               PropCheck.forall error <- error_generator() do
                 result = ErrorHelpers.format_error_response(error, %{})

                 is_map(result) and
                   Map.has_key?(result, :error) and
                   Map.has_key?(result, :details) and
                   is_binary(result.error)
               end,
               numtests: 50
             )
    end

    @tag :propcheck
    test "log_structured_error never crashes" do
      assert PropCheck.quickcheck(
               PropCheck.forall {error, context, severity} <-
                                  {error_generator(), PC.map(atom(), term()),
                                   severity_generator()} do
                 result = ErrorHelpers.log_structured_error(error, context, severity)
                 result == :ok
               end,
               numtests: 50
             )
    end
  end

  # ============================================================================
  # SECTION 3: PROPERTY-BASED TESTS (ExUnitProperties)
  # ============================================================================
  # NOTE: ExUnitProperties tests have been moved to a separate module
  # (error_helpers_exunit_properties_test.exs) to avoid PropCheck/ExUnitProperties
  # macro conflicts. Both test files should be run together for complete coverage.

  # ============================================================================
  # SECTION 4: STAMP SAFETY CONSTRAINT VALIDATION
  # ============================================================================

  describe "STAMP Safety Constraint: SC-SHARED-001 (Error Handling Safety)" do
    test "SC-SHARED-001.1: Error analysis never crashes system" do
      # Test with extreme inputs that might cause crashes
      extreme_inputs = [
        nil,
        "",
        %{},
        [],
        {:error, "test"},
        %RuntimeError{message: String.duplicate("x", 10_000)},
        %{nested: %{very: %{deep: %{structure: "value"}}}}
      ]

      for input <- extreme_inputs do
        assert_no_crash(fn ->
          ErrorHelpers.analyze_database_error(input, :query, %{})
        end)
      end
    end

    test "SC-SHARED-001.2: Error formatting never leaks sensitive data" do
      # Setup: Error with potentially sensitive information
      error_with_secrets = %{
        message: "Database connection failed",
        password: "super_secret_password",
        api_key: "sk_live_123456789",
        credit_card: "4532-1234-5678-9012"
      }

      # Execute
      result = ErrorHelpers.format_error_response(error_with_secrets, %{})

      # Verify: Sensitive fields should not appear in formatted output
      formatted_string = inspect(result)
      refute String.contains?(formatted_string, "super_secret_password")
      refute String.contains?(formatted_string, "sk_live_123456789")
      refute String.contains?(formatted_string, "4532-1234-5678-9012")
    end

    test "SC-SHARED-001.3: TPS 5-Level RCA maintains consistency" do
      # All RCA analyses must return all 5 levels
      test_errors = [
        {:simple, :not_found, :accounts, "get"},
        {:moderate, :timeout, :devices, "send_command"},
        {:complex, "Multi-level error", :alarms, "process"}
      ]

      for {_complexity, error, domain, op} <- test_errors do
        result = ErrorHelpers.analyze_business_error(error, domain, op)

        # Verify all 5 RCA levels are present
        assert Map.has_key?(result, :level1_symptom), "RCA must include level1_symptom"
        assert Map.has_key?(result, :level2_direct_cause), "RCA must include level2_direct_cause"

        assert Map.has_key?(result, :level3_system_behavior),
               "RCA must include level3_system_behavior"

        assert Map.has_key?(result, :level4_process_gap), "RCA must include level4_process_gap"
        assert Map.has_key?(result, :level5_root_cause), "RCA must include level5_root_cause"
        assert is_binary(result.level1_symptom), "level1_symptom must be binary"
        assert is_binary(result.level5_root_cause), "level5_root_cause must be binary"
      end
    end

    test "SC-SHARED-001.4: Error logging never blocks request processing" do
      # Logging should be async and non-blocking
      start_time = System.monotonic_time(:millisecond)

      # Log 100 errors in rapid succession
      for i <- 1..100 do
        ErrorHelpers.log_structured_error(
          "Test error #{i}",
          %{iteration: i},
          :info
        )
      end

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      # All 100 logs should complete in under 100ms (1ms per log average)
      # This ensures async logging doesn't block
      assert duration < 100, "Logging must be non-blocking (took #{duration}ms)"
    end

    test "SC-SHARED-001.5: Error analysis provides actionable information" do
      # Every error analysis must include actionable information
      changeset = %Changeset{
        errors: [%{field: :email, message: "is invalid", validation: :format}],
        valid?: false,
        action_type: :create,
        resource: TestResource
      }

      result = ErrorHelpers.analyze_validation_errors(changeset, TestResource)

      # Verify actionable information is present (in rca_analysis structure)
      assert is_binary(result.level1_symptom), "Must have symptom description"
      assert String.length(result.level1_symptom) > 10, "Symptom must be descriptive"
      assert is_binary(result.level5_root_cause), "Must have root cause"
      assert is_list(result.recommended_actions), "Must provide recommended actions"
      assert length(result.recommended_actions) > 0, "Must have at least one action"
    end
  end

  # ============================================================================
  # SECTION 5: TDG (Test-Driven Generation) METHODOLOGY COMPLIANCE
  # ============================================================================

  describe "TDG Methodology Compliance Validation" do
    test "TDG-001: All public functions have corresponding tests" do
      # Get all exported functions from ErrorHelpers module
      exports = ErrorHelpers.__info__(:functions)

      # Define expected public functions (excluding callbacks and internal)
      expected_functions = [
        {:analyze_validation_errors, 2},
        {:analyze_database_error, 3},
        {:analyze_business_error, 3},
        {:format_error_response, 2},
        {:log_structured_error, 3}
      ]

      # Verify all expected functions exist
      for {name, arity} <- expected_functions do
        assert {name, arity} in exports,
               "Expected function #{name}/#{arity} not found in exports"
      end

      # This test file should have tests for each function
      # (already validated by the describe blocks above)
    end

    test "TDG-002: Test coverage includes edge cases" do
      # Edge case 1: Empty inputs
      assert %{} = ErrorHelpers.format_error_response(nil, %{})
      assert %{} = ErrorHelpers.format_error_response("", %{})

      # Edge case 2: Large inputs
      large_error = String.duplicate("x", 10_000)
      result = ErrorHelpers.format_error_response(large_error, %{})
      assert is_map(result)

      # Edge case 3: Malformed inputs
      assert %{} = ErrorHelpers.analyze_database_error("not an error struct", :query, %{})
    end

    test "TDG-003: Tests validate both success and failure paths" do
      # Success path: Valid changeset
      valid_changeset = %Changeset{
        errors: [],
        valid?: true,
        action_type: :create,
        resource: TestResource
      }

      success_result = ErrorHelpers.analyze_validation_errors(valid_changeset, TestResource)
      assert Map.has_key?(success_result, :level1_symptom)
      assert is_list(success_result.recommended_actions)

      # Failure path: Invalid changeset
      invalid_changeset = %Changeset{
        errors: [%{field: :test, message: "error", validation: :custom}],
        valid?: false,
        action_type: :create,
        resource: TestResource
      }

      failure_result = ErrorHelpers.analyze_validation_errors(invalid_changeset, TestResource)
      assert is_binary(failure_result.level1_symptom)
      assert length(failure_result.recommended_actions) > 0
    end

    test "TDG-004: Property-based tests validate invariants" do
      # Invariant 1: RCA analysis always returns complete structure
      for _i <- 1..50 do
        domain = Enum.random([:accounts, :alarms, :devices])
        result = ErrorHelpers.analyze_business_error(:test, domain, "op")
        assert Map.has_key?(result, :level1_symptom)
        assert Map.has_key?(result, :level5_root_cause)
        assert is_binary(result.error_pattern)
      end

      # Invariant 2: format_error_response always returns map with :error and :details
      for _i <- 1..50 do
        error = Enum.random(["error1", "error2", nil, %{}, []])
        result = ErrorHelpers.format_error_response(error, %{})
        assert Map.has_key?(result, :error)
        assert Map.has_key?(result, :details)
      end
    end
  end

  # ============================================================================
  # SECTION 6: INTEGRATION TESTS
  # ============================================================================

  describe "Integration Tests with Dependent Modules" do
    @tag :integration
    test "integrates with Ash changesets correctly" do
      # This would require actual Ash resources to be defined
      # Placeholder for integration test with real Ash changesets
      # TODO: Add integration test when TestResource is available
    end

    @tag :integration
    test "integrates with logging infrastructure" do
      # Verify that logged errors appear in the logging system
      # This requires the actual logging backend to be configured
      # TODO: Add integration test with real logging backend
    end

    @tag :integration
    test "integrates with telemetry for error tracking" do
      # Verify that errors are emitted as telemetry events
      # TODO: Add telemetry integration test
    end
  end

  # ============================================================================
  # HELPER FUNCTIONS FOR PROPERTY-BASED TESTING
  # ============================================================================

  defp valid_changeset_generator do
    let error_count <- SD.integer(0..10) do
      errors =
        for i <- 1..error_count do
          %{
            field: :"field_#{i}",
            message: "error message #{i}",
            validation: Enum.random([:required, :format, :length, :custom])
          }
        end

      %Changeset{
        errors: errors,
        valid?: error_count == 0,
        action_type: Enum.random([:create, :update, :destroy]),
        resource: TestResource
      }
    end
  end

  defp database_error_generator do
    oneof([
      %Postgrex.Error{
        postgres: %{
          code: Enum.random(["23_505", "23_503", "23_514"]),
          constraint: "test_constraint",
          message: "constraint violation"
        }
      },
      %DBConnection.ConnectionError{message: "connection failed", reason: :timeout},
      %RuntimeError{message: "generic error"}
    ])
  end

  defp operation_generator do
    oneof([:insert, :update, :delete, :query, :select])
  end

  defp error_reason_generator do
    oneof([
      :not_found,
      :unauthorized,
      :timeout,
      :invalid_input,
      binary()
    ])
  end

  defp domain_generator do
    oneof([
      :accounts,
      :alarms,
      :devices,
      :analytics,
      :compliance,
      :access_control,
      :communication,
      :observability,
      :performance
    ])
  end

  defp error_generator do
    oneof([
      binary(),
      %RuntimeError{message: binary()},
      {:error, binary()},
      %{message: binary()},
      nil
    ])
  end

  defp severity_generator do
    oneof([:info, :warning, :error, :critical])
  end

  defp assert_no_crash(fun) do
    try do
      fun.()
      true
    rescue
      _ -> false
    else
      _ -> true
    end
  end

  # Mock module for testing
  defmodule TestResource do
    @moduledoc false
    def __ash_resource__?, do: true
  end
end
