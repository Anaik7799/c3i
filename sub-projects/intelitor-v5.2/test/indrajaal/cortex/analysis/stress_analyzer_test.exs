defmodule Indrajaal.Cortex.Analysis.StressAnalyzerTest do
  @moduledoc """
  TDG Sprint 54: Module coverage tests for Indrajaal.Cortex.Analysis.StressAnalyzer.
  Tests pure stress calculation functions. No DB or process state required.
  STAMP: SC-COG-001, SC-MATH-003 (Homeostasis)
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cortex.Analysis.StressAnalyzer

  @sample_metrics %{
    cpu_usage: 0.45,
    memory_usage: 0.60,
    message_queue_length: 10,
    gc_major_count: 2,
    process_count: 150,
    reduction_rate: 500_000
  }

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(StressAnalyzer)
    end

    test "module exports calculate_stress/1" do
      functions = StressAnalyzer.__info__(:functions)
      assert Keyword.has_key?(functions, :calculate_stress)
    end

    test "module exports calculate_stress_detailed/1" do
      functions = StressAnalyzer.__info__(:functions)
      assert Keyword.has_key?(functions, :calculate_stress_detailed)
    end
  end

  describe "calculate_stress/1" do
    test "returns a float between 0.0 and 1.0 for normal metrics" do
      score = StressAnalyzer.calculate_stress(@sample_metrics)
      assert is_float(score)
      assert score >= 0.0
      assert score <= 1.0
    end

    test "returns low stress for low-load metrics" do
      low_load = %{
        cpu_usage: 0.05,
        memory_usage: 0.10,
        message_queue_length: 0,
        gc_major_count: 0,
        process_count: 10,
        reduction_rate: 10_000
      }

      score = StressAnalyzer.calculate_stress(low_load)
      assert score < 0.5
    end

    test "returns high stress for high-load metrics" do
      high_load = %{
        cpu_usage: 0.95,
        memory_usage: 0.95,
        message_queue_length: 5000,
        gc_major_count: 50,
        process_count: 10_000,
        reduction_rate: 10_000_000
      }

      score = StressAnalyzer.calculate_stress(high_load)
      assert score > 0.5
    end

    test "handles empty metrics map" do
      score = StressAnalyzer.calculate_stress(%{})
      assert is_float(score)
      assert score >= 0.0
    end
  end

  describe "calculate_stress_detailed/1" do
    test "returns a map with stress breakdown" do
      result = StressAnalyzer.calculate_stress_detailed(@sample_metrics)
      assert is_map(result)
    end

    test "result contains overall stress score" do
      result = StressAnalyzer.calculate_stress_detailed(@sample_metrics)
      # Must have some form of overall/total key
      has_score =
        Map.has_key?(result, :overall) or
          Map.has_key?(result, :score) or
          Map.has_key?(result, :total) or
          Map.has_key?(result, :stress)

      assert has_score
    end
  end

  describe "weighted_stress/2 (doc false public function)" do
    test "is exported and callable" do
      functions = StressAnalyzer.__info__(:functions)
      assert Keyword.has_key?(functions, :weighted_stress)
    end

    test "returns a numeric value" do
      result = StressAnalyzer.weighted_stress(@sample_metrics, [])
      assert is_number(result)
    end

    test "accepts custom weights" do
      weights = [cpu_weight: 0.5, memory_weight: 0.5]
      result = StressAnalyzer.weighted_stress(@sample_metrics, weights)
      assert is_number(result)
      assert result >= 0.0
    end
  end
end
