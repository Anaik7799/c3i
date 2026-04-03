defmodule Indrajaal.Shared.ValidationUtilitiesTest do
  @moduledoc """
  TDG-compliant tests for Indrajaal.Shared.ValidationUtilities module.

  Tests comprehensive validation patterns for:
  - Occupancy limit validation (STAMP safety constraint)
  - Timezone validation (business rule enforcement)
  - Emergency exit validation (safety-critical)

  Created: 2025-11-27 12:55:00 CEST
  Phase: 2.2 - C1 Security-Critical Testing (Validation Modules)
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Shared.ValidationUtilities
  alias Ash.Changeset

  # Mock resource for testing
  defmodule TestResource do
    @moduledoc false
    defstruct [:current_occupancy, :max_occupancy, :timezone, :area_type, :emergency_exit?]
  end

  # ============================================================================
  # OCCUPANCY VALIDATION TESTS
  # ============================================================================

  describe "validate_occupancy_limits/2" do
    test "returns ok when current occupancy is below maximum" do
      changeset = create_changeset(%{current_occupancy: 50, max_occupancy: 100})

      assert {:ok, ^changeset} = ValidationUtilities.validate_occupancy_limits(changeset, %{})
    end

    test "returns ok when current occupancy equals maximum" do
      changeset = create_changeset(%{current_occupancy: 100, max_occupancy: 100})

      assert {:ok, ^changeset} = ValidationUtilities.validate_occupancy_limits(changeset, %{})
    end

    test "returns error when current occupancy exceeds maximum" do
      changeset = create_changeset(%{current_occupancy: 150, max_occupancy: 100})

      assert {:error, field: :current_occupancy, message: "cannot exceed maximum occupancy"} =
               ValidationUtilities.validate_occupancy_limits(changeset, %{})
    end

    test "returns ok when maximum occupancy is nil" do
      changeset = create_changeset(%{current_occupancy: 50, max_occupancy: nil})

      assert {:ok, ^changeset} = ValidationUtilities.validate_occupancy_limits(changeset, %{})
    end

    test "returns ok when current occupancy is nil" do
      changeset = create_changeset(%{current_occupancy: nil, max_occupancy: 100})

      assert {:ok, ^changeset} = ValidationUtilities.validate_occupancy_limits(changeset, %{})
    end

    test "returns ok when both occupancy values are nil" do
      changeset = create_changeset(%{current_occupancy: nil, max_occupancy: nil})

      assert {:ok, ^changeset} = ValidationUtilities.validate_occupancy_limits(changeset, %{})
    end

    test "returns ok when current occupancy is zero" do
      changeset = create_changeset(%{current_occupancy: 0, max_occupancy: 100})

      assert {:ok, ^changeset} = ValidationUtilities.validate_occupancy_limits(changeset, %{})
    end

    test "returns error when exceeding by small margin" do
      changeset = create_changeset(%{current_occupancy: 101, max_occupancy: 100})

      assert {:error, field: :current_occupancy, message: _} =
               ValidationUtilities.validate_occupancy_limits(changeset, %{})
    end
  end

  # ============================================================================
  # TIMEZONE VALIDATION TESTS
  # ============================================================================

  describe "validate_timezone/2" do
    test "returns ok for valid UTC timezone" do
      changeset = create_changeset(%{timezone: "UTC"})

      assert {:ok, ^changeset} = ValidationUtilities.validate_timezone(changeset, %{})
    end

    test "returns ok for valid US timezone" do
      changeset = create_changeset(%{timezone: "America / New_York"})

      assert {:ok, ^changeset} = ValidationUtilities.validate_timezone(changeset, %{})
    end

    test "returns ok for valid European timezone" do
      changeset = create_changeset(%{timezone: "Europe / London"})

      assert {:ok, ^changeset} = ValidationUtilities.validate_timezone(changeset, %{})
    end

    test "returns ok for valid Asian timezone" do
      changeset = create_changeset(%{timezone: "Asia / Tokyo"})

      assert {:ok, ^changeset} = ValidationUtilities.validate_timezone(changeset, %{})
    end

    test "returns ok for valid Australian timezone" do
      changeset = create_changeset(%{timezone: "Australia / Sydney"})

      assert {:ok, ^changeset} = ValidationUtilities.validate_timezone(changeset, %{})
    end

    test "returns error for invalid timezone" do
      changeset = create_changeset(%{timezone: "Invalid/Timezone"})

      assert {:error, field: :timezone, message: "must be a valid timezone"} =
               ValidationUtilities.validate_timezone(changeset, %{})
    end

    test "returns ok when timezone is nil" do
      changeset = create_changeset(%{timezone: nil})

      assert {:ok, ^changeset} = ValidationUtilities.validate_timezone(changeset, %{})
    end

    test "returns error for timezone with incorrect format" do
      # Missing space
      changeset = create_changeset(%{timezone: "America/New_York"})

      assert {:error, field: :timezone, message: _} =
               ValidationUtilities.validate_timezone(changeset, %{})
    end

    test "returns error for random string timezone" do
      changeset = create_changeset(%{timezone: "random_string"})

      assert {:error, field: :timezone, message: _} =
               ValidationUtilities.validate_timezone(changeset, %{})
    end
  end

  # ============================================================================
  # STAIRWELL EMERGENCY EXIT VALIDATION TESTS (SAFETY-CRITICAL)
  # ============================================================================

  describe "validate_stairwell_emergency_exit/2 (STAMP safety)" do
    test "returns ok when stairwell is marked as emergency exit" do
      changeset = create_changeset(%{area_type: :stairwell, emergency_exit?: true})

      assert {:ok, ^changeset} =
               ValidationUtilities.validate_stairwell_emergency_exit(changeset, %{})
    end

    test "returns error when stairwell is NOT marked as emergency exit" do
      changeset = create_changeset(%{area_type: :stairwell, emergency_exit?: false})

      assert {:error,
              field: :emergency_exit?, message: "stairwells must be marked as emergency exits"} =
               ValidationUtilities.validate_stairwell_emergency_exit(changeset, %{})
    end

    test "returns error when stairwell has nil emergency exit flag" do
      changeset = create_changeset(%{area_type: :stairwell, emergency_exit?: nil})

      assert {:error, field: :emergency_exit?, message: _} =
               ValidationUtilities.validate_stairwell_emergency_exit(changeset, %{})
    end

    test "returns ok for non-stairwell area without emergency exit" do
      changeset = create_changeset(%{area_type: :office, emergency_exit?: false})

      assert {:ok, ^changeset} =
               ValidationUtilities.validate_stairwell_emergency_exit(changeset, %{})
    end

    test "returns ok for non-stairwell area with emergency exit" do
      changeset = create_changeset(%{area_type: :hallway, emergency_exit?: true})

      assert {:ok, ^changeset} =
               ValidationUtilities.validate_stairwell_emergency_exit(changeset, %{})
    end

    test "returns ok when area_type is nil" do
      changeset = create_changeset(%{area_type: nil, emergency_exit?: false})

      assert {:ok, ^changeset} =
               ValidationUtilities.validate_stairwell_emergency_exit(changeset, %{})
    end
  end

  # ============================================================================
  # PROPERTY-BASED TESTS (PropCheck)
  # ============================================================================

  describe "Property Tests (PropCheck)" do
    property "occupancy validation always returns valid structure" do
      forall {current, maximum} <- {PC.non_neg_integer(), PC.non_neg_integer()} do
        changeset = create_changeset(%{current_occupancy: current, max_occupancy: maximum})
        result = ValidationUtilities.validate_occupancy_limits(changeset, %{})

        case result do
          {:ok, _cs} -> true
          {:error, field: :current_occupancy, message: msg} when is_binary(msg) -> true
          _ -> false
        end
      end
    end

    property "timezone validation handles any string input safely" do
      forall tz <- PC.binary() do
        changeset = create_changeset(%{timezone: tz})
        result = ValidationUtilities.validate_timezone(changeset, %{})

        case result do
          {:ok, _cs} -> true
          {:error, field: :timezone, message: msg} when is_binary(msg) -> true
          _ -> false
        end
      end
    end

    property "emergency exit validation handles all area types" do
      forall {area_type, emergency_exit} <- {area_type_gen(), PC.boolean()} do
        changeset = create_changeset(%{area_type: area_type, emergency_exit?: emergency_exit})
        result = ValidationUtilities.validate_stairwell_emergency_exit(changeset, %{})

        case result do
          {:ok, _cs} -> true
          {:error, field: :emergency_exit?, message: msg} when is_binary(msg) -> true
          _ -> false
        end
      end
    end
  end

  # ============================================================================
  # EDGE CASE TESTS
  # ============================================================================

  describe "Edge Cases" do
    test "handles very large occupancy numbers" do
      changeset =
        create_changeset(%{current_occupancy: 999_999_999, max_occupancy: 1_000_000_000})

      assert {:ok, _} = ValidationUtilities.validate_occupancy_limits(changeset, %{})
    end

    test "handles negative occupancy gracefully" do
      changeset = create_changeset(%{current_occupancy: -1, max_occupancy: 100})

      # Negative values should not exceed positive max
      assert {:ok, _} = ValidationUtilities.validate_occupancy_limits(changeset, %{})
    end

    test "context parameter is ignored" do
      changeset = create_changeset(%{current_occupancy: 50, max_occupancy: 100})

      # Any context should work
      assert {:ok, _} = ValidationUtilities.validate_occupancy_limits(changeset, nil)
      assert {:ok, _} = ValidationUtilities.validate_occupancy_limits(changeset, [])
      assert {:ok, _} = ValidationUtilities.validate_occupancy_limits(changeset, %{user: "test"})
    end
  end

  # ============================================================================
  # SECURITY TESTS
  # ============================================================================

  describe "Security Tests" do
    test "does not leak internal implementation details in error messages" do
      changeset = create_changeset(%{current_occupancy: 200, max_occupancy: 100})

      {:error, field: _field, message: message} =
        ValidationUtilities.validate_occupancy_limits(changeset, %{})

      # Message should be user-friendly, not contain implementation details
      refute String.contains?(message, "Changeset")
      refute String.contains?(message, "Ash")
      refute String.contains?(message, "module")
    end

    test "timezone validation does not execute injected code" do
      # Attempt code injection via timezone string
      dangerous_timezone = "<script>alert('xss')</script>"
      changeset = create_changeset(%{timezone: dangerous_timezone})

      result = ValidationUtilities.validate_timezone(changeset, %{})

      # Should safely return error without executing anything
      assert {:error, field: :timezone, message: _} = result
    end
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  # Creates a mock changeset with specified attributes
  defp create_changeset(attrs) do
    # Create a mock changeset structure that matches Ash.Changeset behavior
    %Changeset{
      attributes: attrs,
      valid?: true,
      action_type: :create,
      resource: TestResource
    }
  end

  # PropCheck generator for area types
  defp area_type_gen do
    oneof([:stairwell, :office, :hallway, :lobby, :restroom, :storage, :elevator, nil])
  end
end
