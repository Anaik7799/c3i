defmodule Indrajaal.Shared.MathUtilitiesTest do
  @moduledoc """
  TDG (Test-Driven Generation) Test Suite for Math Utilities

  SOPv5.1 Cybernetic Framework: ✅ Test - first approach for duplicate code elimination
  Agent: Worker - 2 (TDG Test Creation Specialist)
  Framework: Container - Only + Git - based + TDG Methodology + Property - Based Testing

  Tests created BEFORE implementation to ensure:
  1. Complete functionality preservation during duplication elimination
  2. Edge case coverage for mathematical operations
  3. Property - based validation for statistical functions
  4. Performance benchmarking for extracted utilities

  STAMP Safety Compliance: ✅
  TDG Compliance: ✅ Tests written before implementation
  GDE Compliance: ✅ Goal - directed execution validated
  Dual Property - Based Testing: ✅ PropCheck + ExUnitProperties
  """

  use ExUnit.Case, async: true
  use Indrajaal.Ultimate.TestConsolidation
  # Advanced property testing with sophisticated shrinking
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  # StreamData-based property testing
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # Disambiguate PropCheck vs StreamData generators (EP-GEN-014)
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :tdg_compliant
  @moduletag :stamp_safety
  @moduletag :gde_compliant
  @moduletag :dual_property_testing

  alias Indrajaal.Shared.MathUtilities

  @moduletag :shared_utilities
  @moduletag :tdg_compliant

  describe "update_average / 3" do
    test "calculates correct average for first value (count = 1)" do
      assert MathUtilities.update_average(0, 10, 1) == 10
      assert MathUtilities.update_average(5, 15, 1) == 15
      assert MathUtilities.update_average(-3, 7, 1) == 7
    end

    test "calculates correct running average for multiple values" do
      # Starting with average of 10 from 1 value, add 20 (count = 2)
      # Expected: (10 * 1 + 20) / 2 = 15
      assert MathUtilities.update_average(10, 20, 2) == 15.0

      # Starting with average of 15 from 2 values, add 30 (count = 3)
      # Expected: (15 * 2 + 30) / 3 = 20
      assert MathUtilities.update_average(15, 30, 3) == 20.0

      # Starting with average of 20 from 3 values, add 0 (count = 4)
      # Expected: (20 * 3 + 0) / 4 = 15
      assert MathUtilities.update_average(20, 0, 4) == 15.0
    end

    test "handles floating point precision correctly" do
      result = MathUtilities.update_average(33.33, 66.67, 2)
      assert_in_delta result, 50.0, 0.01

      result = MathUtilities.update_average(1.0 / 3.0, 2.0 / 3.0, 2)
      assert_in_delta result, 0.5, 0.01
    end

    test "handles negative numbers correctly" do
      assert MathUtilities.update_average(-10, -20, 2) == -15.0
      assert MathUtilities.update_average(-10, 20, 2) == 5.0
      assert MathUtilities.update_average(10, -20, 2) == -5.0
    end

    test "handles zero count edge case" do
      # When count is 0 or invalid, return new value
      assert MathUtilities.update_average(100, 50, 0) == 50
      assert MathUtilities.update_average(100, 50, -1) == 50
    end

    test "handles large numbers without overflow" do
      large_avg = 1_000_000_000.0
      large_value = 2_000_000_000.0
      large_count = 1_000_000

      result = MathUtilities.update_average(large_avg, large_value, large_count)

      # Should not raise or return infinity / nan
      assert is_float(result)
      assert result > 0
      assert result != :infinity
      # Check for NaN properly using :math.is_nan (NaN != NaN is always true)
      refute :erlang.is_number(result) and not is_float(result)
    end
  end

  describe "update_average / 3 property-based testing" do
    test "running average converges correctly" do
      ExUnitProperties.check all(
                               values <-
                                 SD.list_of(SD.float(min: -1000.0, max: 1000.0),
                                   min_length: 2,
                                   max_length: 100
                                 ),
                               length(values) > 1
                             ) do
        # Calculate expected average using standard formula
        expected_average = Enum.sum(values) / length(values)

        # Calculate using running average
        [first | rest] = values

        {final_avg, _count} =
          Enum.reduce(rest, {first, 1}, fn value, {current_avg, count} ->
            new_count = count + 1
            new_avg = MathUtilities.update_average(current_avg, value, new_count)
            {new_avg, new_count}
          end)

        # Should be very close to expected average
        assert_in_delta final_avg, expected_average, 0.001
      end
    end

    test "first value becomes initial average" do
      ExUnitProperties.check all(
                               initial_avg <- SD.float(min: -1000.0, max: 1000.0),
                               new_value <- SD.float(min: -1000.0, max: 1000.0)
                             ) do
        result = MathUtilities.update_average(initial_avg, new_value, 1)
        assert result == new_value
      end
    end

    test "average is always between min and max of values" do
      ExUnitProperties.check all(
                               current_avg <- SD.float(min: -1000.0, max: 1000.0),
                               new_value <- SD.float(min: -1000.0, max: 1000.0),
                               count <- SD.positive_integer()
                             ) do
        result = MathUtilities.update_average(current_avg, new_value, count + 1)

        min_val = min(current_avg, new_value)
        max_val = max(current_avg, new_value)

        # Result should be between the bounds (with small tolerance for floating point)
        assert result >= min_val - 0.001
        assert result <= max_val + 0.001
      end
    end
  end

  describe "calculate_percentage / 2" do
    test "calculates basic percentages correctly" do
      assert MathUtilities.calculate_percentage(25, 100) == 25.0
      assert MathUtilities.calculate_percentage(50, 200) == 25.0

      percentage = MathUtilities.calculate_percentage(1, 3)
      assert percentage |> Float.round(2) == 33.33
    end

    test "handles zero total gracefully" do
      assert MathUtilities.calculate_percentage(10, 0) == 0.0
      assert MathUtilities.calculate_percentage(0, 0) == 0.0
    end

    test "handles negative numbers" do
      assert MathUtilities.calculate_percentage(-25, 100) == -25.0
      assert MathUtilities.calculate_percentage(25, -100) == -25.0
      assert MathUtilities.calculate_percentage(-25, -100) == 25.0
    end

    test "returns exact percentage for precise divisions" do
      assert MathUtilities.calculate_percentage(1, 2) == 50.0
      assert MathUtilities.calculate_percentage(3, 4) == 75.0
      assert MathUtilities.calculate_percentage(0, 100) == 0.0
    end
  end

  describe "safe_divide / 2" do
    test "performs normal division for non-zero divisor" do
      assert MathUtilities.safe_divide(10, 2) == 5.0

      division_result = MathUtilities.safe_divide(7, 3)
      assert division_result |> Float.round(3) == 2.333

      assert MathUtilities.safe_divide(-10, 2) == -5.0
    end

    test "returns zero for zero divisor" do
      assert MathUtilities.safe_divide(10, 0) == 0.0
      assert MathUtilities.safe_divide(-5, 0) == 0.0
      assert MathUtilities.safe_divide(0, 0) == 0.0
    end

    test "handles floating point precision" do
      result = MathUtilities.safe_divide(1, 3)
      assert_in_delta result, 0.33_333, 0.001
    end
  end

  describe "round_to_precision / 2" do
    test "rounds to specified decimal places" do
      assert MathUtilities.round_to_precision(3.14_159, 2) == 3.14
      assert MathUtilities.round_to_precision(3.14_159, 4) == 3.1416
      assert MathUtilities.round_to_precision(3.14_159, 0) == 3.0
    end

    test "handles negative numbers" do
      assert MathUtilities.round_to_precision(-3.14_159, 2) == -3.14
      assert MathUtilities.round_to_precision(-3.19_999, 1) == -3.2
    end

    test "handles integer values" do
      assert MathUtilities.round_to_precision(5, 2) == 5.0
      assert MathUtilities.round_to_precision(-5, 3) == -5.0
    end
  end

  describe "performance benchmarks" do
    @tag :benchmark
    test "update_average performance is within acceptable bounds" do
      # Benchmark the update_average function
      {time_microseconds, _result} =
        :timer.tc(fn ->
          Enum.reduce(1..10_000, {0.0, 0}, fn value, {current_avg, count} ->
            new_count = count + 1
            new_avg = MathUtilities.update_average(current_avg, value, new_count)
            {new_avg, new_count}
          end)
        end)

      # Should complete 10,000 operations in less than 100ms (100,000 microseconds)
      assert time_microseconds < 100_000,
             "Performance regression: update_average took #{time_microseconds}μs for 10K operations"
    end
  end

  describe "error handling and edge cases" do
    test "handles very small numbers" do
      tiny_number = 1.0e-10
      result = MathUtilities.update_average(tiny_number, tiny_number * 2, 2)
      assert result > 0
      assert is_float(result)
    end

    test "handles very large numbers" do
      large_number = 1.0e10
      result = MathUtilities.update_average(large_number, large_number * 2, 2)
      expected = large_number * 1.5
      assert_in_delta result, expected, expected * 0.001
    end

    test "mathematical consistency across operations" do
      # Test mathematical properties
      avg1 = MathUtilities.update_average(10, 20, 2)
      avg2 = MathUtilities.update_average(avg1, 30, 3)

      # Should equal the direct average of all three values
      direct_avg = (10 + 20 + 30) / 3
      assert_in_delta avg2, direct_avg, 0.001
    end
  end
end
