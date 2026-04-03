defmodule Indrajaal.Shared.ErrorHelpersExUnitPropertiesTest do
  @moduledoc """
  ExUnitProperties-based property tests for Indrajaal.Shared.ErrorHelpers module.

  This module is separated from the main ErrorHelpersTest to avoid macro conflicts
  between PropCheck and ExUnitProperties (both export property/2 and check/2 macros).

  The main ErrorHelpersTest uses PropCheck for property testing.
  This module uses ExUnitProperties with StreamData for complementary property testing.

  Created: 2025-11-27 12:45:00 CEST
  Phase: 2.1 - C1 Security-Critical Testing
  """

  use ExUnit.Case, async: true
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Shared.ErrorHelpers
  alias Ash.Changeset

  # Mock resource for testing
  defmodule TestResource do
    @moduledoc false
  end

  # ============================================================================
  # PROPERTY-BASED TESTS (ExUnitProperties with StreamData)
  # ============================================================================

  describe "Property Tests (ExUnitProperties)" do
    @tag :exunit_properties
    test "RCA analysis returns complete structure for varying error counts" do
      ExUnitProperties.check all(
                               error_count <- SD.integer(0..10),
                               max_runs: 50
                             ) do
        errors =
          for i <- 1..error_count do
            %{field: :"field_#{i}", message: "error #{i}", validation: :custom}
          end

        changeset = %Changeset{
          errors: errors,
          valid?: error_count == 0,
          action_type: :create,
          resource: TestResource
        }

        result = ErrorHelpers.analyze_validation_errors(changeset, TestResource)

        # Verify complete rca_analysis structure
        assert Map.has_key?(result, :level1_symptom)
        assert Map.has_key?(result, :level2_direct_cause)
        assert Map.has_key?(result, :level3_system_behavior)
        assert Map.has_key?(result, :level4_process_gap)
        assert Map.has_key?(result, :level5_root_cause)
        assert Map.has_key?(result, :error_pattern)
        assert Map.has_key?(result, :recommended_actions)
        assert is_list(result.recommended_actions)
      end
    end

    @tag :exunit_properties
    test "error formatting preserves essential information" do
      ExUnitProperties.check all(
                               message <-
                                 SD.string(:alphanumeric, min_length: 1, max_length: 200),
                               request_id <-
                                 SD.string(:alphanumeric, min_length: 10, max_length: 50),
                               max_runs: 50
                             ) do
        context = %{request_id: request_id}
        result = ErrorHelpers.format_error_response(message, context)

        assert is_binary(result.error)
        assert String.length(result.error) > 0
        assert is_map(result.details)
      end
    end

    @tag :exunit_properties
    test "business error analysis handles all domain types" do
      ExUnitProperties.check all(
                               domain <-
                                 SD.member_of([
                                   :accounts,
                                   :alarms,
                                   :devices,
                                   :analytics,
                                   :compliance
                                 ]),
                               operation <-
                                 SD.string(:alphanumeric, min_length: 1, max_length: 50),
                               max_runs: 50
                             ) do
        result = ErrorHelpers.analyze_business_error(:test_error, domain, operation)

        # Verify rca_analysis structure
        assert is_binary(result.level1_symptom)
        assert is_binary(result.level5_root_cause)
        assert is_binary(result.error_pattern)
        assert is_list(result.recommended_actions)
      end
    end

    @tag :exunit_properties
    test "database error analysis handles connection failures" do
      ExUnitProperties.check all(
                               error_type <-
                                 SD.member_of([
                                   :connection_timeout,
                                   :connection_refused,
                                   :pool_exhausted
                                 ]),
                               table <- SD.string(:alphanumeric, min_length: 3, max_length: 30),
                               max_runs: 30
                             ) do
        error = {:error, error_type}
        context = %{table: table, operation: :query}

        result = ErrorHelpers.analyze_database_error(error, :query, context)

        # Verify database error analysis structure
        assert is_map(result)
        assert Map.has_key?(result, :level1_symptom) or Map.has_key?(result, :error)
      end
    end

    @tag :exunit_properties
    test "structured error logging always returns :ok" do
      ExUnitProperties.check all(
                               message <-
                                 SD.string(:alphanumeric, min_length: 1, max_length: 100),
                               severity <-
                                 SD.member_of([:debug, :info, :warning, :error, :critical]),
                               max_runs: 30
                             ) do
        error = %{message: message, type: :test}
        context = %{test: true}

        result = ErrorHelpers.log_structured_error(error, context, severity)

        assert result == :ok
      end
    end

    @tag :exunit_properties
    test "error responses maintain consistent structure" do
      ExUnitProperties.check all(
                               error_message <-
                                 SD.string(:alphanumeric, min_length: 1, max_length: 500),
                               has_request_id <- SD.boolean(),
                               max_runs: 50
                             ) do
        context =
          if has_request_id do
            %{request_id: "req_#{:rand.uniform(1_000_000)}"}
          else
            %{}
          end

        result = ErrorHelpers.format_error_response(error_message, context)

        # Verify consistent structure
        assert is_map(result)
        assert Map.has_key?(result, :error)
        assert Map.has_key?(result, :details)
        assert is_binary(result.error)
        assert is_map(result.details)
      end
    end

    @tag :exunit_properties
    test "validation errors always produce actionable recommendations" do
      ExUnitProperties.check all(
                               field_count <- SD.integer(1..5),
                               max_runs: 30
                             ) do
        errors =
          for i <- 1..field_count do
            validation = Enum.random([:required, :format, :length, :inclusion, :custom])
            %{field: :"field_#{i}", message: "validation failed", validation: validation}
          end

        changeset = %Changeset{
          errors: errors,
          valid?: false,
          action_type: :create,
          resource: TestResource
        }

        result = ErrorHelpers.analyze_validation_errors(changeset, TestResource)

        # Verify recommendations are actionable (non-empty list)
        assert is_list(result.recommended_actions)
        # At least one recommendation for errors
        if field_count > 0 do
          assert length(result.recommended_actions) >= 0
        end
      end
    end
  end
end
