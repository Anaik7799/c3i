defmodule Indrajaal.Shared.TestSupportConsolidationAnalysisTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Shared.TestSupportConsolidationAnalysis

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(TestSupportConsolidationAnalysis)
    end
  end

  describe "analyze_duplication_patterns/0" do
    test "function is exported" do
      assert function_exported?(
               TestSupportConsolidationAnalysis,
               :analyze_duplication_patterns,
               0
             )
    end

    test "returns analysis map" do
      result = TestSupportConsolidationAnalysis.analyze_duplication_patterns()
      assert is_map(result)
    end

    test "analysis contains bulk_creation_functions key" do
      result = TestSupportConsolidationAnalysis.analyze_duplication_patterns()
      assert Map.has_key?(result, :bulk_creation_functions)
    end

    test "analysis contains factory_patterns key" do
      result = TestSupportConsolidationAnalysis.analyze_duplication_patterns()
      assert Map.has_key?(result, :factory_patterns)
    end

    test "analysis contains test_helpers key" do
      result = TestSupportConsolidationAnalysis.analyze_duplication_patterns()
      assert Map.has_key?(result, :test_helpers)
    end

    test "analysis contains property_testing key" do
      result = TestSupportConsolidationAnalysis.analyze_duplication_patterns()
      assert Map.has_key?(result, :property_testing)
    end

    test "analysis contains total_estimated_violations" do
      result = TestSupportConsolidationAnalysis.analyze_duplication_patterns()
      assert Map.has_key?(result, :total_estimated_violations)
      assert is_integer(result.total_estimated_violations)
      assert result.total_estimated_violations > 0
    end
  end

  describe "generate_consolidation_plan/0" do
    test "function is exported" do
      assert function_exported?(TestSupportConsolidationAnalysis, :generate_consolidation_plan, 0)
    end

    test "returns consolidation plan map" do
      result = TestSupportConsolidationAnalysis.generate_consolidation_plan()
      assert is_map(result)
    end

    test "plan contains phase_1" do
      result = TestSupportConsolidationAnalysis.generate_consolidation_plan()
      assert Map.has_key?(result, :phase_1)
    end

    test "plan contains phase_2" do
      result = TestSupportConsolidationAnalysis.generate_consolidation_plan()
      assert Map.has_key?(result, :phase_2)
    end

    test "plan contains phase_3" do
      result = TestSupportConsolidationAnalysis.generate_consolidation_plan()
      assert Map.has_key?(result, :phase_3)
    end

    test "plan contains phase_4" do
      result = TestSupportConsolidationAnalysis.generate_consolidation_plan()
      assert Map.has_key?(result, :phase_4)
    end

    test "each phase has a name" do
      result = TestSupportConsolidationAnalysis.generate_consolidation_plan()

      Enum.each([:phase_1, :phase_2, :phase_3, :phase_4], fn phase ->
        assert Map.has_key?(result[phase], :name)
        assert is_binary(result[phase].name)
      end)
    end
  end
end
