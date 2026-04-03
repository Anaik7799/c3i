defmodule Indrajaal.Tps.FiveLevelRcaEngineTest do
  @moduledoc """
  Tests for Indrajaal.Tps.FiveLevelRcaEngine GenServer - 5-level RCA methodology.
  STAMP: SC-GDE-001, SC-TDG-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Tps.FiveLevelRcaEngine

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(FiveLevelRcaEngine)
    end

    test "start_link/1 is exported" do
      assert function_exported?(FiveLevelRcaEngine, :start_link, 1)
    end

    test "perform_complete_analysis/1 is exported" do
      assert function_exported?(FiveLevelRcaEngine, :perform_complete_analysis, 1)
    end

    test "analyze_batch_incidents/1 is exported" do
      assert function_exported?(FiveLevelRcaEngine, :analyze_batch_incidents, 1)
    end

    test "generate_actionable_recommendations/1 is exported" do
      assert function_exported?(FiveLevelRcaEngine, :generate_actionable_recommendations, 1)
    end

    test "create_rca_documentation/1 is exported" do
      assert function_exported?(FiveLevelRcaEngine, :create_rca_documentation, 1)
    end

    test "validate_stamp_constraints/1 is exported" do
      assert function_exported?(FiveLevelRcaEngine, :validate_stamp_constraints, 1)
    end

    test "validate_tps_config/1 is exported" do
      assert function_exported?(FiveLevelRcaEngine, :validate_tps_config, 1)
    end

    test "analyze_symptom/1 is exported" do
      assert function_exported?(FiveLevelRcaEngine, :analyze_symptom, 1)
    end
  end

  describe "perform_complete_analysis/1" do
    test "returns {:ok, analysis} for a valid incident" do
      incident = %{
        description: "Database connection lost",
        timestamp: DateTime.utc_now(),
        severity: :critical,
        affected_systems: ["database"],
        initial_symptoms: ["connection_refused"]
      }

      result = FiveLevelRcaEngine.perform_complete_analysis(incident)
      assert match?({:ok, _}, result)
    end

    test "analysis contains 5 levels" do
      incident = %{
        description: "Test incident",
        timestamp: DateTime.utc_now(),
        severity: :medium,
        affected_systems: ["api"],
        initial_symptoms: ["slow_response"]
      }

      {:ok, analysis} = FiveLevelRcaEngine.perform_complete_analysis(incident)
      assert Map.has_key?(analysis, :level_1_analysis)
      assert Map.has_key?(analysis, :level_2_analysis)
      assert Map.has_key?(analysis, :level_3_analysis)
      assert Map.has_key?(analysis, :level_4_analysis)
      assert Map.has_key?(analysis, :level_5_analysis)
    end

    test "analysis contains quality metrics" do
      incident = %{
        description: "Test",
        timestamp: DateTime.utc_now(),
        severity: :low,
        affected_systems: [],
        initial_symptoms: []
      }

      {:ok, analysis} = FiveLevelRcaEngine.perform_complete_analysis(incident)
      assert Map.has_key?(analysis, :quality_score)
      assert Map.has_key?(analysis, :completion_time)
    end
  end

  describe "validate_tps_config/1" do
    test "returns :ok for valid TPS config" do
      config = %{
        jidoka_enabled: true,
        continuous_improvement: true,
        respect_for_people: true,
        just_in_time: true,
        five_level_analysis: true
      }

      result = FiveLevelRcaEngine.validate_tps_config(config)
      assert result == :ok
    end

    test "returns {:error, :tps_configuration_invalid} for incomplete config" do
      config = %{jidoka_enabled: true}
      result = FiveLevelRcaEngine.validate_tps_config(config)
      assert result == {:error, :tps_configuration_invalid}
    end
  end

  describe "analyze_symptom/1" do
    test "returns {:ok, analysis} for valid symptom" do
      symptom = %{
        description: "High memory usage",
        timestamp: DateTime.utc_now(),
        severity: :high
      }

      result = FiveLevelRcaEngine.analyze_symptom(symptom)
      assert match?({:ok, _}, result)
    end

    test "returns {:error, :incomplete_symptom_data} for missing fields" do
      symptom = %{description: "partial"}
      result = FiveLevelRcaEngine.analyze_symptom(symptom)
      assert result == {:error, :incomplete_symptom_data}
    end
  end

  describe "validate_stamp_constraints/1" do
    test "returns {:ok, validation} for any safety context" do
      context = %{
        constraint_sc1: :validated,
        constraint_sc2: :validated,
        constraint_sc3: :validated
      }

      result = FiveLevelRcaEngine.validate_stamp_constraints(context)
      assert match?({:ok, _}, result)
    end

    test "validation identifies violations when constraints not validated" do
      context = %{constraint_sc1: :not_validated}
      {:ok, validation} = FiveLevelRcaEngine.validate_stamp_constraints(context)
      assert Map.has_key?(validation, :constraint_violations)
    end
  end

  describe "generate_actionable_recommendations/1" do
    test "returns {:ok, recommendations} for a complete analysis" do
      incident = %{
        description: "Test",
        timestamp: DateTime.utc_now(),
        severity: :low,
        affected_systems: [],
        initial_symptoms: []
      }

      {:ok, analysis} = FiveLevelRcaEngine.perform_complete_analysis(incident)
      result = FiveLevelRcaEngine.generate_actionable_recommendations(analysis)
      assert match?({:ok, _}, result)
    end

    test "recommendations include immediate_actions" do
      incident = %{
        description: "Test",
        timestamp: DateTime.utc_now(),
        severity: :low,
        affected_systems: [],
        initial_symptoms: []
      }

      {:ok, analysis} = FiveLevelRcaEngine.perform_complete_analysis(incident)
      {:ok, recs} = FiveLevelRcaEngine.generate_actionable_recommendations(analysis)
      assert Map.has_key?(recs, :immediate_actions)
    end
  end
end
