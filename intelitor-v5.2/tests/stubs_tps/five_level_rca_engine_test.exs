defmodule Intelitor.Tps.FiveLevelRcaEngineTest do
  @moduledoc """
  Comprehensive test suite for TPS 5 - Level Root Cause Analysis Engine.

  This test suite validates the complete Toyota Production System 5 - Level RCA
  methodology implementation with SOPv5.1 compliance and enterprise - grade
    quality.

  Created: 2025 - 08 - 05 11:21:00 CEST
  Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Container - Only
  TDG: ✅ Tests written BEFORE implementation (mandatory)
  GDE Enhanced: ✅ Goal - Directed Execution with adaptive strategy selection
  STAMP Safety: ✅ All safety constraints (SC1, SC2, SC3) validated
  """

  use ExUnit.Case, async: true
  use Intelitor.Ultimate.TestConsolidation
  use PropCheck

  # # use ExUnitProperties  # Disabled - PropCheck conflict (SC-TDG-002)  # Disabled - PropCheck property/2 conflict
  # # import ExUnitProperties  # Disabled - PropCheck conflict (SC-TDG-002)  # Disabled - PropCheck conflict

  alias Intelitor.Tps.FiveLevelRcaEngine

  describe "TPS 5 - Level RCA Engine initialization" do
    test "initializes RCA engine with SOPv5.1 compliance" do
      # Test that the RCA engine starts with proper SOPv5.1 configuration
      assert {:ok, engine} = FiveLevelRcaEngine.start_link([])
      assert is_pid(engine)

      # Validate SOPv5.1 compliance configuration
      __state = :sys.get_state(engine)
      assert state.sopv51_compliant == true
      assert state.tps_methodology_enabled == true
      assert state.claude_logging_enabled == true
    end

    test "validates required TPS configuration parameters" do
      # Test required TPS configuration validation
      config = %{
        jidoka_enabled: true,
        continuous_improvement: true,
        respect_for_people: true,
        just_in_time: true,
        five_level_analysis: true
      }

      assert :ok = FiveLevelRcaEngine.validate_tps_config(config)
    end

    test "rejects invalid TPS configuration" do
      # Test configuration validation with missing required parameters
      invalid_config = %{jidoka_enabled: false}

      assert {:error, :tps_configuration_invalid} =
               FiveLevelRcaEngine.validate_tps_config(invalid_config)
    end
  end

  describe "Level 1: Symptom Identification" do
    test "identifies and categorizes symptoms correctly" do
      # Test symptom identification and categorization
      symptom = %{
        description: "Container startup failure",
        timestamp: DateTime.utc_now(),
        severity: :critical,
        affected_systems: ["container_orchestration", "database"]
      }

      assert {:ok, analysis} = FiveLevelRcaEngine.analyze_symptom(symptom)
      assert analysis.level == 1

      assert analysis.symptom_category in [
               :system_failure,
               :performance_degradation,
               :data_integrity
             ]

      assert analysis.initial_impact_assessment != nil
    end

    test "validates symptom data completeness" do
      # Test symptom validation with incomplete data
      incomplete_symptom = %{description: "Partial symptom"}

      assert {:error, :incomplete_symptom_data} =
               FiveLevelRcaEngine.analyze_symptom(incomplete_symptom)
    end

    test "handles multiple concurrent symptoms" do
      # Test handling of multiple symptoms simultaneously
      symptoms = [
        %{description: "Symptom 1", timestamp: DateTime.utc_now(), severity: :high},
        %{description: "Symptom 2", timestamp: DateTime.utc_now(), severity: :medium},
        %{description: "Symptom 3", timestamp: DateTime.utc_now(), severity: :low}
      ]

      assert {:ok, analyses} = FiveLevelRcaEngine.analyze_multiple_symptoms(symptoms)
      assert length(analyses) == 3
      assert Enum.all?(analyses, fn analysis -> analysis.level == 1 end)
    end
  end

  describe "Level 2: Surface Cause Analysis" do
    test "identifies surface causes from symptoms" do
      # Test surface cause identification
      symptom_analysis = %{
        level: 1,
        symptom_category: :system_failure,
        description: "Container startup failure",
        affected_systems: ["container_orchestration"]
      }

      assert {:ok, surface_analysis} = FiveLevelRcaEngine.analyze_surface_cause(symptom_analysis)
      assert surface_analysis.level == 2
      assert surface_analysis.surface_cause != nil
      assert surface_analysis.contributing_factors != []
    end

    test "correlates multiple symptoms to common surface cause" do
      # Test correlation of multiple symptoms
      symptom_analyses = [
        %{level: 1, symptom_category: :system_failure, description: "Container A failed"},
        %{level: 1, symptom_category: :system_failure, description: "Container B failed"}
      ]

      assert {:ok, correlation} = FiveLevelRcaEngine.correlate_symptoms(symptom_analyses)
      assert correlation.common_surface_cause != nil
      assert correlation.correlation_strength >= 0.7
    end

    test "identifies environmental factors" do
      # Test environmental factor identification
      surface_analysis = %{
        level: 2,
        surface_cause: "Resource exhaustion",
        system_context: %{memory_pressure: true, cpu_utilization: 0.95}
      }

      assert {:ok, environmental_analysis} =
               FiveLevelRcaEngine.analyze_environmental_factors(surface_analysis)

      assert environmental_analysis.environmental_factors != []
      assert environmental_analysis.resource_constraints != nil
    end
  end

  describe "Level 3: System Behavior Analysis" do
    test "analyzes system behavior patterns" do
      # Test system behavior pattern analysis
      surface_analysis = %{
        level: 2,
        surface_cause: "Memory leak in application",
        affected_systems: ["application_server", "memory_management"]
      }

      assert {:ok, system_analysis} = FiveLevelRcaEngine.analyze_system_behavior(surface_analysis)
      assert system_analysis.level == 3
      assert system_analysis.system_behavior_patterns != []
      assert system_analysis.architectural_vulnerabilities != nil
    end

    test "identifies systemic weaknesses" do
      # Test systemic weakness identification
      system_context = %{
        resource_monitoring: :insufficient,
        error_handling: :partial,
        recovery_mechanisms: :missing
      }

      assert {:ok, weakness_analysis} =
               FiveLevelRcaEngine.identify_systemic_weaknesses(system_context)

      assert weakness_analysis.weakness_categories != []
      assert weakness_analysis.risk_assessment != nil
    end

    test "analyzes interaction between system components" do
      # Test component interaction analysis
      components = ["container_runtime", "orchestrator", "health_monitor"]

      assert {:ok, interaction_analysis} =
               FiveLevelRcaEngine.analyze_component_interactions(components)

      assert interaction_analysis.interaction_patterns != []
      assert interaction_analysis.coupling_strength != nil
    end
  end

  describe "Level 4: Configuration Gap Analysis" do
    test "identifies configuration gaps and misalignments" do
      # Test configuration gap identification
      system_analysis = %{
        level: 3,
        system_behavior_patterns: ["resource_contention", "cascade_failures"],
        current_configuration: %{timeout: 30, retries: 3, monitoring_interval: 60}
      }

      assert {:ok, config_analysis} =
               FiveLevelRcaEngine.analyze_configuration_gaps(system_analysis)

      assert config_analysis.level == 4
      assert config_analysis.configuration_gaps != []
      assert config_analysis.recommended_changes != []
    end

    test "compares current vs optimal configuration" do
      # Test configuration comparison
      current_config = %{memory_limit: "1GB", cpu_limit: "0.5", timeout: 30}
      optimal_config = %{memory_limit: "2GB", cpu_limit: "1.0", timeout: 60}

      assert {:ok, comparison} =
               FiveLevelRcaEngine.compare_configurations(
                 current_config,
                 optimal_config
               )

      assert comparison.configuration_delta != %{}
      assert comparison.impact_assessment != nil
    end

    test "validates configuration against best practices" do
      # Test best practices validation
      configuration = %{
        container_limits: %{memory: "512MB", cpu: "0.25"},
        monitoring: %{enabled: true, interval: 30},
        security: %{rootless: true, isolation: "strict"}
      }

      assert {:ok, validation} = FiveLevelRcaEngine.validate_against_best_practices(configuration)
      assert validation.compliance_score >= 0.8
      assert validation.recommendations != []
    end
  end

  describe "Level 5: Design Philosophy Analysis" do
    test "analyzes underlying design philosophy" do
      # Test design philosophy analysis
      config_analysis = %{
        level: 4,
        configuration_gaps: ["insufficient_resource_allocation", "missing_circuit_breakers"],
        system_architecture: "microservices"
      }

      assert {:ok, philosophy_analysis} =
               FiveLevelRcaEngine.analyze_design_philosophy(config_analysis)

      assert philosophy_analysis.level == 5
      assert philosophy_analysis.design_principles != []
      assert philosophy_analysis.architectural_decisions != []
    end

    test "identifies philosophical inconsistencies" do
      # Test philosophical inconsistency identification
      design_context = %{
        __stated_principles: ["resilience", "scalability", "maintainability"],
        actual_implementation: ["tightly_coupled", "single_point_failure", "manual_processes"]
      }

      assert {:ok, inconsistency_analysis} =
               FiveLevelRcaEngine.identify_philosophical_inconsistencies(design_context)

      assert inconsistency_analysis.inconsistencies != []
      assert inconsistency_analysis.alignment_score < 0.5
    end

    test "recommends philosophical realignment" do
      # Test philosophical realignment recommendations
      philosophy_analysis = %{
        level: 5,
        design_principles: ["reliability", "observability"],
        current_gaps: ["insufficient_monitoring", "manual_recovery"]
      }

      assert {:ok, realignment} =
               FiveLevelRcaEngine.recommend_philosophical_realignment(philosophy_analysis)

      assert realignment.realignment_strategy != nil
      assert realignment.implementation_roadmap != []
    end
  end

  describe "Complete 5 - Level RCA Analysis" do
    test "performs complete end - to - end 5 - level analysis" do
      # Test complete 5 - level RCA process
      incident = %{
        description: "Container orchestration system failure",
        timestamp: DateTime.utc_now(),
        severity: :critical,
        affected_systems: ["containers", "orchestration", "monitoring"],
        initial_symptoms: ["high_memory_usage", "container_restarts", "health_check_failures"]
      }

      assert {:ok, complete_analysis} = FiveLevelRcaEngine.perform_complete_analysis(incident)

      # Validate all 5 levels are completed
      assert complete_analysis.level_1_analysis != nil
      assert complete_analysis.level_2_analysis != nil
      assert complete_analysis.level_3_analysis != nil
      assert complete_analysis.level_4_analysis != nil
      assert complete_analysis.level_5_analysis != nil

      # Validate analysis chain consistency
      assert complete_analysis.analysis_chain_valid == true
      # 5 seconds max
      assert complete_analysis.completion_time <= 5000
    end

    test "generates actionable recommendations" do
      # Test actionable recommendation generation
      complete_analysis = %{
        level_1_analysis: %{symptom_category: :system_failure},
        level_2_analysis: %{surface_cause: "resource_exhaustion"},
        level_3_analysis: %{system_behavior_patterns: ["cascade_failure"]},
        level_4_analysis: %{configuration_gaps: ["insufficient_limits"]},
        level_5_analysis: %{design_principles: ["resilience_lacking"]}
      }

      assert {:ok, recommendations} =
               FiveLevelRcaEngine.generate_actionable_recommendations(complete_analysis)

      assert recommendations.immediate_actions != []
      assert recommendations.short_term_improvements != []
      assert recommendations.long_term_strategic_changes != []
      assert recommendations.priority_ranking != []
    end

    test "creates comprehensive documentation" do
      # Test RCA documentation generation
      analysis_data = %{
        incident_id: "INC - 001",
        complete_analysis: %{analysis_complete: true},
        recommendations: %{total_recommendations: 5}
      }

      assert {:ok, documentation} = FiveLevelRcaEngine.create_rca_documentation(analysis_data)
      assert documentation.executive_summary != nil
      assert documentation.detailed_analysis != nil
      assert documentation.action_plan != nil
      assert documentation.lessons_learned != []
    end
  end

  describe "SOPv5.1 integration and compliance" do
    test "integrates with 11 - agent architecture" do
      # Test 11 - agent architecture integration
      agent_config = %{
        supervisor: 1,
        helpers: 4,
        workers: 6,
        coordination_mode: :advanced
      }

      assert {:ok, integration} = FiveLevelRcaEngine.integrate_with_agents(agent_config)
      assert integration.agents_coordinated == 11
      assert integration.task_distribution != nil
    end

    test "maintains Claude logging compliance" do
      # Test Claude logging compliance
      rca_activity = %{
        analysis_type: "5_level_rca",
        incident_id: "INC - 002",
        completion_status: :success
      }

      assert :ok = FiveLevelRcaEngine.log_claude_activity(rca_activity)

      # Verify log file creation
      log_files = Path.wildcard("./data / tmp / claude_tps_rca_*.log")
      assert length(log_files) > 0
    end

    test "validates STAMP safety constraints" do
      # Test STAMP safety constraint validation
      safety_context = %{
        constraint_sc1: :validated,
        constraint_sc2: :validated,
        constraint_sc3: :validated
      }

      assert {:ok, safety_validation} =
               FiveLevelRcaEngine.validate_stamp_constraints(safety_context)

      assert safety_validation.all_constraints_valid == true
    end
  end

  describe "Performance and scalability" do
    test "handles high - volume incident analysis" do
      # Test high - volume performance
      incidents =
        Enum.map(1..100, fn i ->
          %{
            description: "Incident #{i}",
            timestamp: DateTime.utc_now(),
            severity: Enum.random([:low, :medium, :high, :critical])
          }
        end)

      start_time = System.monotonic_time()
      assert {:ok, analyses} = FiveLevelRcaEngine.analyze_batch_incidents(incidents)
      end_time = System.monotonic_time()

      duration_ms = System.convert_time_unit(end_time - start_time, :native, :millisecond)
      # 10 seconds max for 100 incidents
      assert duration_ms < 10_000
      assert length(analyses) == 100
    end

    test "maintains analysis quality under load" do
      # Test quality under load
      high_load_incident = %{
        description: "Complex system failure under load",
        concurrent_symptoms: 50,
        affected_systems: Enum.to_list(1..20)
      }

      assert {:ok, analysis} = FiveLevelRcaEngine.perform_complete_analysis(high_load_incident)
      assert analysis.quality_score >= 0.85
      assert analysis.analysis_completeness >= 0.90
    end
  end

  describe "Property - based testing with PropCheck" do
    property "RCA analysis always produces valid results for any incident" do
      forall incident <- incident_generator() do
        case FiveLevelRcaEngine.perform_complete_analysis(incident) do
          {:ok, analysis} ->
            valid_analysis?(analysis)

          {:error, _reason} ->
            # Errors are acceptable for invalid inputs
            true
        end
      end
    end

    property "Analysis time scales linearly with incident complexity" do
      forall {simple_incident, complex_incident} <-
               {simple_incident_generator(), complex_incident_generator()} do
        {:ok, simple_analysis} = FiveLevelRcaEngine.perform_complete_analysis(simple_incident)
        {:ok, complex_analysis} = FiveLevelRcaEngine.perform_complete_analysis(complex_incident)

        # Complex incidents should not take exponentially longer
        complex_analysis.analysis_time <= simple_analysis.analysis_time * 5
      end
    end
  end

  describe "GDE Enhanced goal validation" do
    test "validates Goal - Directed Execution compliance" do
      # Test goal validation for GDE Enhanced framework
      goal_data = %{
        goal_type: "incident_analysis",
        goal_strategy: "systematic_rca",
        success_criteria: ["all_levels_completed", "actionable_recommendations"]
      }

      assert {:ok, goal_validation} =
               FiveLevelRcaEngine.validate_goal_directed_execution(goal_data)

      assert goal_validation.goal_alignment == true
      assert goal_validation.strategy_effectiveness >= 0.8
    end
  end

  describe "Property - based testing with ExUnitProperties" do
    @tag :property
    property "RCA recommendations are always actionable and prioritized" do
      forall incident <- incident_stream_data() do
        case FiveLevelRcaEngine.perform_complete_analysis(incident) do
          {:ok, analysis} ->
            case FiveLevelRcaEngine.generate_actionable_recommendations(analysis) do
              {:ok, recommendations} ->
                # All recommendations must be actionable
                # Recommendations must be prioritized
                Enum.all?(recommendations.immediate_actions, &actionable?/1) and
                  Enum.all?(recommendations.short_term_improvements, &actionable?/1) and
                  Enum.all?(recommendations.long_term_strategic_changes, &actionable?/1) and
                  recommendations.priority_ranking != [] and
                  length(recommendations.priority_ranking) > 0

              {:error, _} ->
                false
            end

          {:error, _} ->
            false
        end
      end
    end
  end

  # Helper functions for property - based testing
  defp incident_generator do
    let {description, severity, systems} <- {string(), severity_generator(), list(string())} do
      %{
        description: description,
        timestamp: DateTime.utc_now(),
        severity: severity,
        affected_systems: systems
      }
    end
  end

  defp severity_generator, do: oneof([:low, :medium, :high, :critical])

  defp simple_incident_generator do
    %{
      description: "Simple incident",
      timestamp: DateTime.utc_now(),
      severity: :low,
      affected_systems: ["single_system"]
    }
  end

  defp complex_incident_generator do
    %{
      description: "Complex multi - system failure",
      timestamp: DateTime.utc_now(),
      severity: :critical,
      affected_systems: Enum.to_list1()..10 |> Enum.map(&"system_#{&1}"),
      concurrent_symptoms: 25,
      cascade_effects: true
    }
  end

  defp incident_stream_data do
    let {description, severity, systems} <-
          {utf8(), oneof([:low, :medium, :high, :critical]), list(utf8())} do
      %{
        description: description,
        timestamp: DateTime.utc_now(),
        severity: severity,
        affected_systems: systems
      }
    end
  end

  defp valid_analysis?(analysis) do
    analysis.level_1_analysis != nil and
      analysis.level_2_analysis != nil and
      analysis.level_3_analysis != nil and
      analysis.level_4_analysis != nil and
      analysis.level_5_analysis != nil and
      analysis.analysis_chain_valid == true
  end

  defp actionable?(recommendation) do
    Map.has_key?(recommendation, :action) and
      Map.has_key?(recommendation, :timeline) and
      Map.has_key?(recommendation, :responsible_party)
  end
end
