defmodule Indrajaal.Stamp.SafetyAnalysisEngineTest do
  @moduledoc """
  Comprehensive test suite for STAMP Safety Analysis Engine.

  This test suite validates the complete STAMP (System - Theoretic Accident Model
  and Processes) methodology implementation with SOPv5.1 compliance and
    enterprise - grade quality.

  Created: 2025 - 08 - 05 11:31:00 CEST
  Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Container - Only
  TDG: ✅ Tests written BEFORE implementation (mandatory)
  GDE Enhanced: ✅ Goal - Directed Execution with adaptive strategy selection
  STAMP Safety: ✅ All safety constraints (SC1, SC2, SC3) validated
  """

  use ExUnit.Case, async: true
  use Indrajaal.Ultimate.TestConsolidation
  use PropCheck
  alias StreamData, as: SD
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  alias PropCheck.BasicTypes, as: PC
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias Indrajaal.Stamp.SafetyAnalysisEngine

  describe "STAMP Safety Analysis Engine initialization" do
    test "initializes safety engine with SOPv5.1 compliance" do
      # Test that the safety engine starts with proper SOPv5.1 configuration
      assert {:ok, engine} = SafetyAnalysisEngine.start_link([])
      assert is_pid(engine)

      # Validate SOPv5.1 compliance configuration
      state = :sys.get_state(engine)
      assert state.sopv51_compliant == true
      assert state.stamp_methodology_enabled == true
      assert state.claude_logging_enabled == true
    end

    test "validates __required STAMP configuration parameters" do
      # Test __required STAMP configuration validation
      config = %{
        stpa_enabled: true,
        cast_enabled: true,
        safety_constraints_validation: true,
        control_structure_analysis: true,
        uca_identification: true
      }

      assert :ok = SafetyAnalysisEngine.validate_stamp_config(config)
    end

    test "rejects invalid STAMP configuration" do
      # Test configuration validation with missing __required parameters
      invalid_config = %{stpa_enabled: false}

      assert {:error, :stamp_configuration_invalid} =
               SafetyAnalysisEngine.validate_stamp_config(invalid_config)
    end
  end

  describe "STPA (Systems - Theoretic Process Analysis) - Proactive Analysis" do
    test "performs complete STPA analysis for system hazards" do
      # Test complete STPA proactive analysis
      system_definition = %{
        system_name: "Container Orchestration System",
        system_boundary: ["containers", "orchestrator", "health_monitor"],
        system_purpose: "Reliable container management and monitoring",
        hazards: ["container_failure", "__data_loss", "security_breach"]
      }

      assert {:ok, stpa_analysis} = SafetyAnalysisEngine.perform_stpa_analysis(system_definition)
      assert stpa_analysis.analysis_type == :stpa
      assert stpa_analysis.safety_constraints != []
      assert stpa_analysis.control_structure != nil
      assert stpa_analysis.unsafe_control_actions != []
    end

    test "identifies safety constraints from system hazards" do
      # Test safety constraint identification
      hazards = [
        %{id: "H1", description: "Container orchestration failure", severity: :critical},
        %{id: "H2", description: "Data corruption during transfer", severity: :high},
        %{id: "H3", description: "Unauthorized access to containers", severity: :medium}
      ]

      assert {:ok, constraints} = SafetyAnalysisEngine.identify_safety_constraints(hazards)
      assert length(constraints) == 3

      assert Enum.all?(constraints, fn constraint ->
               Map.has_key?(constraint, :constraint_id) and
                 Map.has_key?(constraint, :description) and
                 Map.has_key?(constraint, :associated_hazard)
             end)
    end

    test "models control structure for system components" do
      # Test control structure modeling
      system_components = [
        %{name: "orchestrator", type: :controller, controls: ["containers"]},
        %{name: "containers", type: :controlled_process, controlled_by: ["orchestrator"]},
        %{name: "health_monitor", type: :sensor, monitors: ["containers"]}
      ]

      assert {:ok, control_structure} =
               SafetyAnalysisEngine.model_control_structure(system_components)

      assert control_structure.controllers != []
      assert control_structure.controlled_processes != []
      assert control_structure.control_actions != []
      assert control_structure.feedback_loops != []
    end

    test "identifies unsafe control actions (UCAs)" do
      # Test UCA identification
      control_structure = %{
        control_actions: [
          %{
            controller: "orchestrator",
            action: "start_container",
            controlled_process: "container"
          },
          %{controller: "orchestrator", action: "stop_container", controlled_process: "container"}
        ],
        safety_constraints: [
          %{id: "SC1", description: "Containers must start successfully"}
        ]
      }

      assert {:ok, ucas} = SafetyAnalysisEngine.identify_unsafe_control_actions(control_structure)
      assert is_list(ucas)

      assert Enum.all?(ucas, fn uca ->
               Map.has_key?(uca, :uca_id) and
                 Map.has_key?(uca, :control_action) and
                 Map.has_key?(uca, :unsafe__context) and
                 Map.has_key?(uca, :potential_consequences)
             end)
    end

    test "generates STPA mitigation strategies" do
      # Test STPA mitigation strategy generation
      ucas = [
        %{
          uca_id: "UCA1",
          control_action: "start_container",
          unsafe_context: "when_resource_exhausted",
          potential_consequences: ["system_failure", "cascade_effects"]
        }
      ]

      assert {:ok, mitigations} = SafetyAnalysisEngine.generate_stpa_mitigations(ucas)
      assert is_list(mitigations)

      assert Enum.all?(mitigations, fn mitigation ->
               Map.has_key?(mitigation, :mitigation_id) and
                 Map.has_key?(mitigation, :strategy) and
                 Map.has_key?(mitigation, :implementation_approach)
             end)
    end
  end

  describe "CAST (Causal Analysis based on STAMP) - Reactive Analysis" do
    test "performs complete CAST analysis for incidents" do
      # Test complete CAST reactive analysis
      incident = %{
        incident_id: "INC - 001",
        description: "Container orchestration system failure",
        timestamp: DateTime.utc_now(),
        impact: :critical,
        affected_systems: ["orchestrator", "containers", "monitoring"]
      }

      assert {:ok, cast_analysis} = SafetyAnalysisEngine.perform_cast_analysis(incident)
      assert cast_analysis.analysis_type == :cast
      assert cast_analysis.system_model != nil
      assert cast_analysis.control_structure_at_time_of_incident != nil
      assert cast_analysis.safety_constraint_violations != []
      assert cast_analysis.systemic_factors != []
    end

    test "analyzes control structure at time of incident" do
      # Test incident - time control structure analysis
      incident_context = %{
        timestamp: DateTime.utc_now(),
        system_state: %{
          orchestrator_status: "degraded",
          container_states: ["failed", "running", "restarting"],
          monitor_status: "active"
        }
      }

      assert {:ok, control_analysis} =
               SafetyAnalysisEngine.analyze_incident_control_structure(incident_context)

      assert control_analysis.control_structure_snapshot != nil
      assert control_analysis.control_failures != []
      assert control_analysis.communication_breakdowns != []
    end

    test "identifies safety constraint violations" do
      # Test safety constraint violation identification
      incident_data = %{
        observed_behavior: "containers_failed_to_restart",
        expected_behavior: "containers_restart_automatically",
        safety_constraints: [
          %{id: "SC1", description: "Container restart must succeed within 30 seconds"}
        ]
      }

      assert {:ok, violations} =
               SafetyAnalysisEngine.identify_constraint_violations(incident_data)

      assert is_list(violations)

      assert Enum.all?(violations, fn violation ->
               Map.has_key?(violation, :constraint_id) and
                 Map.has_key?(violation, :violation_type) and
                 Map.has_key?(violation, :contributing_factors)
             end)
    end

    test "analyzes systemic factors contributing to incidents" do
      # Test systemic factor analysis
      incident_context = %{
        organizational_factors: ["inadequate_monitoring", "insufficient_redundancy"],
        technical_factors: ["resource_constraints", "configuration_errors"],
        human_factors: ["manual_intervention_delays", "inadequate_training"]
      }

      assert {:ok, systemic_analysis} =
               SafetyAnalysisEngine.analyze_systemic_factors(incident_context)

      assert systemic_analysis.organizational_contributions != []
      assert systemic_analysis.technical_contributions != []
      assert systemic_analysis.human_contributions != []
      assert systemic_analysis.interaction_effects != []
    end

    test "generates CAST recommendations" do
      # Test CAST recommendation generation
      cast_analysis = %{
        constraint_violations: [%{constraint_id: "SC1", severity: :high}],
        systemic_factors: [%{factor: "inadequate_monitoring", impact: :medium}],
        control_failures: [%{failure_type: "feedback_delay", criticality: :high}]
      }

      assert {:ok, recommendations} =
               SafetyAnalysisEngine.generate_cast_recommendations(cast_analysis)

      assert recommendations.immediate_actions != []
      assert recommendations.system_improvements != []
      assert recommendations.process_changes != []
      assert recommendations.design_modifications != []
    end
  end

  describe "Safety constraint validation and monitoring" do
    test "validates safety constraints in real - time" do
      # Test real - time safety constraint validation
      constraints = [
        %{id: "SC1", description: "Response time < 100ms", validation_rule: :response_time_check},
        %{id: "SC2", description: "Availability > 99.9%", validation_rule: :availability_check},
        %{id: "SC3", description: "Data integrity maintained", validation_rule: :integrity_check}
      ]

      system_state = %{
        response_times: [45, 67, 89, 23],
        availability: 99.95,
        __data_integrity_score: 1.0
      }

      assert {:ok, validation_results} =
               SafetyAnalysisEngine.validate_safety_constraints(
                 constraints,
                 system_state
               )

      assert validation_results.all_constraints_valid == true
      assert length(validation_results.individual_results) == 3
    end

    test "monitors safety constraint compliance over time" do
      # Test continuous safety monitoring
      monitoring_config = %{
        constraints: ["SC1", "SC2", "SC3"],
        # milliseconds
        monitoring_interval: 1000,
        alert_thresholds: %{violation_count: 3, time_window: 60_000}
      }

      assert {:ok, monitor} = SafetyAnalysisEngine.start_constraint_monitoring(monitoring_config)
      assert is_pid(monitor)

      # Simulate constraint violations
      violations = [
        %{constraint_id: "SC1", timestamp: DateTime.utc_now(), severity: :medium}
      ]

      assert :ok =
               SafetyAnalysisEngine.report_constraint_violations(
                 monitor,
                 violations
               )
    end

    test "generates safety alerts for constraint violations" do
      # Test safety alert generation
      violations = [
        %{
          constraint_id: "SC1",
          violation_type: "threshold_exceeded",
          severity: :critical,
          timestamp: DateTime.utc_now(),
          __context: %{actual_value: 150, threshold: 100}
        }
      ]

      assert {:ok, alerts} = SafetyAnalysisEngine.generate_safety_alerts(violations)
      assert is_list(alerts)

      assert Enum.all?(alerts, fn alert ->
               Map.has_key?(alert, :alert_id) and
                 Map.has_key?(alert, :priority) and
                 Map.has_key?(alert, :recommended_actions)
             end)
    end
  end

  describe "Integration with SOPv5.1 framework" do
    test "integrates with 11 - agent architecture" do
      # Test 11 - agent architecture integration
      agent_config = %{
        supervisor: 1,
        helpers: 4,
        workers: 6,
        coordination_mode: :advanced
      }

      assert {:ok, integration} = SafetyAnalysisEngine.integrate_with_agents(agent_config)
      assert integration.agents_coordinated == 11
      assert integration.safety_analysis_distribution != nil
    end

    test "maintains Claude logging compliance" do
      # Test Claude logging compliance
      safety_activity = %{
        analysis_type: "stamp_safety",
        analysis_id: "STAMP - 001",
        completion_status: :success
      }

      assert :ok = SafetyAnalysisEngine.log_claude_activity(safety_activity)

      # Verify log file creation
      log_files = Path.wildcard("./__data / tmp / claude_stamp_safety_*.log")
      assert length(log_files) > 0
    end

    test "validates TPS integration for safety analysis" do
      # Test TPS methodology integration
      incident_data = %{
        incident_id: "INC - 002",
        tps_rca_completed: true,
        stamp_analysis_required: true
      }

      assert {:ok, integration_result} = SafetyAnalysisEngine.integrate_with_tps(incident_data)
      assert integration_result.tps_stamp_alignment == true
      assert integration_result.comprehensive_analysis != nil
    end

    test "supports container - only execution" do
      # Test container - only execution support
      container_context = %{
        execution_environment: "container",
        container_runtime: "podman",
        nixos_compliance: true
      }

      assert {:ok, container_validation} =
               SafetyAnalysisEngine.validate_container_execution(container_context)

      assert container_validation.container_compliant == true
      assert container_validation.nixos_validated == true
    end
  end

  describe "Performance and scalability" do
    test "handles high - volume safety analysis" do
      # Test high - volume performance
      incidents =
        Enum.map(1..50, fn i ->
          %{
            incident_id: "INC-#{i}",
            description: "Test incident #{i}",
            timestamp: DateTime.utc_now(),
            severity: Enum.random([:low, :medium, :high, :critical])
          }
        end)

      start_time = System.monotonic_time()
      assert {:ok, analyses} = SafetyAnalysisEngine.analyze_batch_incidents(incidents)
      end_time = System.monotonic_time()

      duration_ms = System.convert_time_unit(end_time - start_time, :native, :millisecond)
      # 5 seconds max for 50 incidents
      assert duration_ms < 5000
      assert length(analyses) == 50
    end

    test "maintains analysis quality under load" do
      # Test quality under load
      high_load_system = %{
        concurrent_analyses: 25,
        system_complexity: :high,
        constraint_count: 15
      }

      assert {:ok, analysis} = SafetyAnalysisEngine.perform_analysis_under_load(high_load_system)
      assert analysis.quality_score >= 0.85
      assert analysis.analysis_completeness >= 0.90
    end
  end

  describe "GDE Enhanced goal validation" do
    test "validates Goal - Directed Execution compliance for safety analysis" do
      # Test goal validation for GDE Enhanced framework
      goal_data = %{
        goal_type: "safety_analysis",
        goal_strategy: "stamp_methodology",
        success_criteria: ["stpa_completed", "cast_available", "constraints_validated"]
      }

      assert {:ok, goal_validation} =
               SafetyAnalysisEngine.validate_goal_directed_execution(goal_data)

      assert goal_validation.goal_alignment == true
      assert goal_validation.strategy_effectiveness >= 0.8
    end
  end

  describe "Property - based testing with PropCheck" do
    property "STAMP analysis always produces valid safety constraints for
      any system" do
      forall system_definition <- system_generator() do
        case SafetyAnalysisEngine.perform_stpa_analysis(system_definition) do
          {:ok, analysis} ->
            valid_stamp_analysis?(analysis)

          {:error, _reason} ->
            # Errors are acceptable for invalid inputs
            true
        end
      end
    end

    property "Safety constraint violations are always detectable and actionable" do
      forall {constraints, system_state} <- {constraint_generator(), system_state_generator()} do
        {:ok, validation} =
          SafetyAnalysisEngine.validate_safety_constraints(
            constraints,
            system_state
          )

        # All violations must be detectable and have mitigation strategies
        violations =
          validation.individual_results
          |> Enum.filter(&(&1.status == :violated))

        Enum.all?(violations, fn violation ->
          Map.has_key?(violation, :violation_details) and
            Map.has_key?(violation, :recommended_mitigations)
        end)
      end
    end
  end

  describe "Property - based testing with ExUnitProperties" do
    test "CAST analysis provides comprehensive incident investigation" do
      ExUnitProperties.check all(incident <- incident_stream_data()) do
        {:ok, analysis} = SafetyAnalysisEngine.perform_cast_analysis(incident)
        {:ok, recommendations} = SafetyAnalysisEngine.generate_cast_recommendations(analysis)

        # All CAST analyses must be comprehensive and actionable
        assert analysis.analysis_type == :cast
        assert analysis.systemic_factors != []
        assert recommendations.immediate_actions != []
        assert recommendations.system_improvements != []
      end
    end
  end

  # Helper functions for property - based testing
  defp system_generator do
    let {name, components, hazards} <- {PC.utf8(), PC.list(PC.utf8()), PC.list(PC.utf8())} do
      %{
        system_name: name,
        system_boundary: components,
        system_purpose: "Test system purpose",
        hazards: hazards
      }
    end
  end

  defp constraint_generator do
    let constraints <- PC.list(constraint_item_generator()) do
      constraints
    end
  end

  defp constraint_item_generator do
    let {id, desc, rule} <-
          {PC.utf8(), PC.utf8(),
           PC.oneof([:response_time_check, :availability_check, :integrity_check])} do
      %{
        id: id,
        description: desc,
        validation_rule: rule
      }
    end
  end

  defp system_state_generator do
    let {times, avail, integrity} <- {PC.list(PC.integer(1, 1000)), PC.float(), PC.float()} do
      %{
        response_times: times,
        # Normalized to 90.0-100.0 range
        availability: 90.0 + abs(avail) * 10.0,
        # Normalized to 0.0-1.0 range
        __data_integrity_score: abs(rem_float(integrity))
      }
    end
  end

  defp rem_float(f) when is_float(f), do: f - Float.floor(f)

  defp incident_stream_data do
    let {description, severity, systems} <-
          {PC.utf8(), PC.oneof([:low, :medium, :high, :critical]),
           PC.non_empty(PC.list(PC.utf8()))} do
      %{
        incident_id: "INC-#{:rand.uniform(1000)}",
        description: description,
        timestamp: DateTime.utc_now(),
        impact: severity,
        # Limit to max 5 systems
        affected_systems: Enum.take(systems, 5)
      }
    end
  end

  defp valid_stamp_analysis?(analysis) do
    analysis.analysis_type == :stpa and
      analysis.safety_constraints != nil and
      analysis.control_structure != nil and
      analysis.unsafe_control_actions != nil
  end
end
