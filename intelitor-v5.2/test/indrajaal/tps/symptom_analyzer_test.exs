defmodule Indrajaal.TPS.SymptomAnalyzerTest do
  @moduledoc """
  Tests for Indrajaal.TPS.SymptomAnalyzer - TPS Level 1 RCA.
  STAMP: SC-GDE-001, SC-TDG-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.TPS.SymptomAnalyzer

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(SymptomAnalyzer)
    end

    test "analyze_symptoms/2 is exported" do
      assert function_exported?(SymptomAnalyzer, :analyze_symptoms, 2)
    end
  end

  describe "analyze_symptoms/2" do
    test "returns a map" do
      result = SymptomAnalyzer.analyze_symptoms("High CPU usage", %{})
      assert is_map(result)
    end

    test "result contains environment key" do
      result = SymptomAnalyzer.analyze_symptoms("Test problem", %{})
      assert Map.has_key?(result, :environment)
    end

    test "environment has mix_env field" do
      result = SymptomAnalyzer.analyze_symptoms("Test", %{})
      assert Map.has_key?(result.environment, :mix_env)
    end

    test "environment has config_files field" do
      result = SymptomAnalyzer.analyze_symptoms("Test", %{})
      assert Map.has_key?(result.environment, :config_files)
      assert is_list(result.environment.config_files)
    end

    test "accepts empty context" do
      result = SymptomAnalyzer.analyze_symptoms("Problem description")
      assert is_map(result)
    end

    test "accepts context map as second argument" do
      context = %{source: :sentinel, timestamp: DateTime.utc_now()}
      result = SymptomAnalyzer.analyze_symptoms("Memory pressure", context)
      assert is_map(result)
    end

    test "environment.mix_env is a valid Mix environment atom" do
      result = SymptomAnalyzer.analyze_symptoms("Test", %{})
      env = result.environment.mix_env
      assert env in [:dev, :test, :prod]
    end
  end
end
