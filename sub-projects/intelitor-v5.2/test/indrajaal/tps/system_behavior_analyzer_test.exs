defmodule Indrajaal.TPS.SystemBehaviorAnalyzerTest do
  @moduledoc """
  Tests for Indrajaal.TPS.SystemBehaviorAnalyzer - TPS Level 3 RCA.
  STAMP: SC-GDE-001, SC-TDG-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.TPS.SystemBehaviorAnalyzer

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(SystemBehaviorAnalyzer)
    end

    test "analyze_system_behavior/2 is exported" do
      assert function_exported?(SystemBehaviorAnalyzer, :analyze_system_behavior, 2)
    end
  end

  describe "analyze_system_behavior/2" do
    test "returns a map" do
      level2_results = %{
        information_flow: %{flow_quality: :good},
        communication_channels: %{effectiveness: :high}
      }

      result = SystemBehaviorAnalyzer.analyze_system_behavior(level2_results)
      assert is_map(result)
    end

    test "result contains interaction_patterns key" do
      result = SystemBehaviorAnalyzer.analyze_system_behavior(%{})
      assert Map.has_key?(result, :interaction_patterns)
    end

    test "result contains feedback_loops key" do
      result = SystemBehaviorAnalyzer.analyze_system_behavior(%{})
      assert Map.has_key?(result, :feedback_loops)
    end

    test "result contains system_boundaries key" do
      result = SystemBehaviorAnalyzer.analyze_system_behavior(%{})
      assert Map.has_key?(result, :system_boundaries)
    end

    test "result contains control_mechanisms key" do
      result = SystemBehaviorAnalyzer.analyze_system_behavior(%{})
      assert Map.has_key?(result, :control_mechanisms)
    end

    test "result contains behavioral_patterns key" do
      result = SystemBehaviorAnalyzer.analyze_system_behavior(%{})
      assert Map.has_key?(result, :behavioral_patterns)
    end

    test "result contains systemic_vulnerabilities key" do
      result = SystemBehaviorAnalyzer.analyze_system_behavior(%{})
      assert Map.has_key?(result, :systemic_vulnerabilities)
    end

    test "accepts context as second argument" do
      level2 = %{surface_cause: "resource_exhaustion"}
      context = %{system: :indrajaal, environment: :production}
      result = SystemBehaviorAnalyzer.analyze_system_behavior(level2, context)
      assert is_map(result)
    end

    test "interaction_patterns contains component_interactions" do
      result = SystemBehaviorAnalyzer.analyze_system_behavior(%{})
      assert Map.has_key?(result.interaction_patterns, :component_interactions)
    end

    test "feedback_loops contains positive_feedback_loops" do
      result = SystemBehaviorAnalyzer.analyze_system_behavior(%{})
      assert Map.has_key?(result.feedback_loops, :positive_feedback_loops)
    end

    test "systemic_vulnerabilities contains architectural_vulnerabilities" do
      result = SystemBehaviorAnalyzer.analyze_system_behavior(%{})
      assert Map.has_key?(result.systemic_vulnerabilities, :architectural_vulnerabilities)
    end
  end
end
