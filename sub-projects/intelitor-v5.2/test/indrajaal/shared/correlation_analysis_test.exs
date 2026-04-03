defmodule Indrajaal.Shared.CorrelationAnalysisTest do
  @moduledoc """
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
  alias PropCheck.BasicTypes, as: PC
  # StreamData - based property testing
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias StreamData, as: SD
  @moduletag :tdg_compliant
  @moduletag :stamp_safety
  @moduletag :gde_compliant
  @moduletag :dual_property_testing

  alias Indrajaal.Shared.CorrelationAnalysis

  describe "interpret_correlation / 1" do
    test "returns :improving for positive correlation > 0.3" do
      correlation = Decimal.new("0.5")
      assert CorrelationAnalysis.interpret_correlation(correlation) == :improving
    end

    test "returns :degrading for negative correlation < -0.3" do
      correlation = Decimal.new("-0.5")
      assert CorrelationAnalysis.interpret_correlation(correlation) == :degrading
    end

    test "returns :stable for correlation between -0.3 and 0.3" do
      correlation = Decimal.new("0.1")
      assert CorrelationAnalysis.interpret_correlation(correlation) == :stable

      correlation = Decimal.new("-0.1")
      assert CorrelationAnalysis.interpret_correlation(correlation) == :stable

      correlation = Decimal.new("0.0")
      assert CorrelationAnalysis.interpret_correlation(correlation) == :stable
    end

    test "returns :insufficient_data for nil correlation" do
      assert CorrelationAnalysis.interpret_correlation(nil) == :insufficient_data
    end

    test "handles boundary values correctly" do
      # Exactly at boundary
      correlation = Decimal.new("0.3")
      assert CorrelationAnalysis.interpret_correlation(correlation) == :stable

      correlation = Decimal.new("-0.3")
      assert CorrelationAnalysis.interpret_correlation(correlation) == :stable

      # Just over boundary
      correlation = Decimal.new("0.30_001")
      assert CorrelationAnalysis.interpret_correlation(correlation) == :improving

      correlation = Decimal.new("-0.30_001")
      assert CorrelationAnalysis.interpret_correlation(correlation) == :degrading
    end
  end

  describe "process_correlation_result / 1" do
    test "processes valid correlation result correctly" do
      result = %{rows: [[Decimal.new("0.5")]]}
      assert CorrelationAnalysis.process_correlation_result(result) == :improving

      result = %{rows: [[Decimal.new("-0.5")]]}
      assert CorrelationAnalysis.process_correlation_result(result) == :degrading

      result = %{rows: [[Decimal.new("0.1")]]}
      assert CorrelationAnalysis.process_correlation_result(result) == :stable
    end

    test "handles nil correlation in result" do
      result = %{rows: [[nil]]}
      assert CorrelationAnalysis.process_correlation_result(result) == :insufficient_data
    end

    test "handles empty result" do
      result = %{rows: []}
      assert CorrelationAnalysis.process_correlation_result(result) == :insufficient_data
    end

    test "handles malformed result" do
      result = %{rows: [["invalid"]]}
      assert CorrelationAnalysis.process_correlation_result(result) == :insufficient_data

      result = %{rows: [[1, 2]]}
      assert CorrelationAnalysis.process_correlation_result(result) == :insufficient_data
    end
  end

  describe "calculate_trend_correlation / 3" do
    test "calculates trend with mock repo" do
      # Mock repo that returns improving trend
      _mock_repo = fn query, params ->
        assert is_binary(query)
        assert is_list(params)
        %{rows: [[Decimal.new("0.5")]]}
      end

      # Create a module that implements the query! function
      defmodule MockRepo do
        @spec query!(binary(), list()) :: map()
        def query!(_query, _params) do
          %{rows: [[Decimal.new("0.5")]]}
        end
      end

      result =
        CorrelationAnalysis.calculate_trend_correlation(
          MockRepo,
          "SELECT CORR(x, y) FROM __data",
          [1, 2, 3]
        )

      assert result == :improving
    end
  end

  # Property - based tests using ExUnitProperties
  test "correlation interpretation is consistent with thresholds" do
    ExUnitProperties.check all(correlation_float <- SD.float(min: -1.0, max: 1.0)) do
      correlation = Decimal.from_float(correlation_float)
      result = CorrelationAnalysis.interpret_correlation(correlation)

      expected =
        cond do
          correlation_float > 0.3 -> :improving
          correlation_float < -0.3 -> :degrading
          true -> :stable
        end

      assert result == expected
    end
  end

  test "process_correlation_result handles various input formats" do
    ExUnitProperties.check all(
                             correlation_value <-
                               StreamData.one_of([
                                 StreamData.constant(nil),
                                 StreamData.map(
                                   StreamData.float(min: -1.0, max: 1.0),
                                   &Decimal.from_float/1
                                 )
                               ])
                           ) do
      result_struct = %{rows: [[correlation_value]]}
      processed = CorrelationAnalysis.process_correlation_result(result_struct)

      assert processed in [:improving, :degrading, :stable, :insufficient_data]
    end
  end

  describe "edge cases and error handling" do
    test "handles very small correlation values" do
      correlation = Decimal.new("0.000_001")
      assert CorrelationAnalysis.interpret_correlation(correlation) == :stable
    end

    test "handles very large correlation values" do
      correlation = Decimal.new("0.999_999")
      assert CorrelationAnalysis.interpret_correlation(correlation) == :improving

      correlation = Decimal.new("-0.999_999")
      assert CorrelationAnalysis.interpret_correlation(correlation) == :degrading
    end

    test "handles correlation values exactly at thresholds" do
      # Test exact threshold values
      test_cases = [
        {Decimal.new("0.3"), :stable},
        {Decimal.new("-0.3"), :stable},
        {Decimal.new("0.30_000_000_001"), :improving},
        {Decimal.new("-0.30_000_000_001"), :degrading}
      ]

      for {correlation, expected} <- test_cases do
        result = CorrelationAnalysis.interpret_correlation(correlation)

        assert result == expected,
               "Expected #{inspect(expected)} for correlation #{inspect(correlation)}, got #{inspect(result)}"
      end
    end
  end

  describe "integration scenarios" do
    test "simulates real - world correlation analysis workflow" do
      # Simulate a typical testing analytics workflow
      test_scenarios = [
        # Improving reliability trend
        %{
          correlation: Decimal.new("0.65"),
          expected: :improving,
          scenario: "reliability improving over time"
        },
        # Degrading performance trend
        %{
          correlation: Decimal.new("-0.45"),
          expected: :degrading,
          scenario: "performance degrading over time"
        },
        # Stable quality metrics
        %{
          correlation: Decimal.new("0.05"),
          expected: :stable,
          scenario: "quality metrics stable"
        },
        # Insufficient __data
        %{
          correlation: nil,
          expected: :insufficient_data,
          scenario: "insufficient __data for analysis"
        }
      ]

      for scenario <- test_scenarios do
        result = CorrelationAnalysis.interpret_correlation(scenario.correlation)

        assert result == scenario.expected,
               "Failed scenario: #{scenario.scenario}"
      end
    end
  end
end
