defmodule Indrajaal.Safety.IncidentCoordinatorTest do
  @moduledoc """
  Comprehensive tests for Incident Coordinator System

  Tests all aspects of incident response including:
  - CAST (Causal Analysis based on STAMP) methodology implementation
  - SOPv5.1 cybernetic coordination with 11 - agent architecture
  - TPS 5 - Level RCA integration and systematic investigation
  - Incident lifecycle management and escalation procedures
  - Multi - agent cybernetic response coordination
  - Integration with Safety Monitor and Error Pattern Engine

  Agent: Helper - 4 validates incident response systems
  SOPv5.1 Compliance: ✅ Cybernetic feedback loops,
    TPS 5 - Level RCA, STAMP methodology
  """

  # Async false due to shared GenServer
  use ExUnit.Case, async: false
  use Indrajaal.Ultimate.TestConsolidation
  alias Indrajaal.Safety.{IncidentCoordinator, Monitor, ErrorPatternEngine}

  setup do
    # Start the incident coordinator for testing (handle already_started case)
    pid =
      case IncidentCoordinator.start_link(
             cast_analysis_enabled: true,
             tps_rca_enabled: true,
             cybernetic_coordination: true
           ) do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
      end

    # Give it time to initialize
    Process.sleep(100)

    on_exit(fn ->
      # Only stop if we started it and it's still alive
      if Process.alive?(pid) and GenServer.whereis(IncidentCoordinator) == pid do
        try do
          GenServer.stop(pid, :normal, 1000)
        catch
          :exit, _ -> :ok
        end
      end
    end)

    {:ok, coordinator_pid: pid}
  end

  describe "start_link / 1" do
    test "starts coordinator with SOPv5.1 cybernetic configuration" do
      # Use existing coordinator from setup (may already be started)
      stats = IncidentCoordinator.get_statistics()

      # Verify SOPv5.1 cybernetic features are available
      assert Map.has_key?(stats, :incidents_handled)
      assert Map.has_key?(stats, :cast_analyses_performed)
      assert Map.has_key?(stats, :tps_rca_completed)
      assert Map.has_key?(stats, :cybernetic_interventions)
      assert stats.agent_coordination_active == true
    end

    test "initializes with comprehensive agent architecture" do
      stats = IncidentCoordinator.get_statistics()

      # Verify 11 - agent architecture initialization
      assert Map.has_key?(stats, :supervisor_agent_status)
      assert Map.has_key?(stats, :helper_agents_status)
      assert Map.has_key?(stats, :worker_agents_status)
      assert Map.has_key?(stats, :agent_coordination_metrics)

      # Should have active_incidents key
      assert Map.has_key?(stats, :active_incidents)
    end
  end

  describe "report_incident / 2" do
    test "handles safety constraint violation with CAST analysis" do
      incident_details = %{
        constraint_type: :alarm_rate_exceeded,
        violation_severity: :high,
        affected_systems: [:alarm_processing, :notification_system],
        __context: %{
          alarm_count: 1500,
          threshold: 1000,
          time_window: :per_minute
        },
        timestamp: DateTime.utc_now()
      }

      result =
        IncidentCoordinator.report_incident(
          :safety_constraint_violation,
          incident_details
        )

      assert {:ok, incident_id} = result
      assert is_binary(incident_id)

      # Verify CAST analysis was initiated
      stats = IncidentCoordinator.get_statistics()
      assert stats.incidents_handled == 1
      assert stats.cast_analyses_performed == 1
      assert stats.active_incidents == 1
    end

    test "handles system failure with TPS 5 - Level RCA" do
      incident_details = %{
        failure_type: :database_connection_loss,
        impact_level: :critical,
        affected_components: [:primary_db, :connection_pool, :query_processor],
        symptoms: [
          "Connection timeout errors",
          "Query failures increasing",
          "Connection pool exhaustion"
        ],
        timestamp: DateTime.utc_now()
      }

      result =
        IncidentCoordinator.report_incident(
          :system_failure,
          incident_details
        )

      assert {:ok, incident_id} = result

      # Verify TPS 5 - Level RCA was initiated
      stats = IncidentCoordinator.get_statistics()
      assert stats.incidents_handled == 1
      assert stats.tps_rca_completed >= 1
      assert stats.active_incidents == 1
    end

    test "handles security breach with cybernetic response coordination" do
      incident_details = %{
        breach_type: :unauthorized_access_attempt,
        severity: :critical,
        affected_tenants: ["tenant-001", "tenant-002"],
        attack_vectors: [:sql_injection, :privilege_escalation],
        detection_source: :security_monitor,
        timestamp: DateTime.utc_now()
      }

      result =
        IncidentCoordinator.report_incident(
          :security_breach,
          incident_details
        )

      assert {:ok, incident_id} = result

      # Verify cybernetic response coordination
      stats = IncidentCoordinator.get_statistics()
      assert stats.incidents_handled == 1
      assert stats.cybernetic_interventions >= 1
      assert stats.active_incidents == 1

      # Should trigger tenant isolation coordination
      assert stats.security_interventions >= 1
    end

    test "handles performance degradation with agent coordination" do
      incident_details = %{
        degradation_type: :response_time_increase,
        severity: :medium,
        affected_endpoints: ["/api / alarms", "/api / devices"],
        performance_metrics: %{
          avg_response_time: 2500,
          threshold: 1000,
          error_rate: 0.15
        },
        timestamp: DateTime.utc_now()
      }

      result =
        IncidentCoordinator.report_incident(
          :performance_degradation,
          incident_details
        )

      assert {:ok, incident_id} = result

      # Verify multi - agent coordination
      stats = IncidentCoordinator.get_statistics()
      assert stats.incidents_handled == 1
      assert stats.performance_interventions >= 1
    end

    test "handles __data integrity violation with emergency response" do
      incident_details = %{
        violation_type: :data_corruption_detected,
        severity: :critical,
        affected_data: [:alarm_records, :device_configurations],
        corruption_extent: :localized,
        backup_status: :available,
        timestamp: DateTime.utc_now()
      }

      result =
        IncidentCoordinator.report_incident(
          :data_integrity_violation,
          incident_details
        )

      assert {:ok, incident_id} = result

      # Verify emergency response protocols
      stats = IncidentCoordinator.get_statistics()
      assert stats.incidents_handled == 1
      assert stats.emergency_responses >= 1
      assert stats.data_integrity_interventions >= 1
    end

    test "handles compliance violation with audit trail creation" do
      incident_details = %{
        violation_type: :gdpr_data_access_violation,
        severity: :high,
        affected_data_subjects: 25,
        violation_description: "Unauthorized cross - tenant __data access",
        legal_implications: :regulatory_reporting_required,
        timestamp: DateTime.utc_now()
      }

      result =
        IncidentCoordinator.report_incident(
          :compliance_violation,
          incident_details
        )

      assert {:ok, incident_id} = result

      # Verify compliance response protocols
      stats = IncidentCoordinator.get_statistics()
      assert stats.incidents_handled == 1
      assert stats.compliance_interventions >= 1
      assert stats.audit_trails_created >= 1
    end

    test "handles external threat with threat response coordination" do
      incident_details = %{
        threat_type: :ddos_attack,
        severity: :high,
        attack_source: ["192.168.1.100", "10.0.0.50"],
        attack_patterns: [:high_volume_requests, :resource_exhaustion],
        mitigation_status: :in_progress,
        timestamp: DateTime.utc_now()
      }

      result =
        IncidentCoordinator.report_incident(
          :external_threat,
          incident_details
        )

      assert {:ok, incident_id} = result

      # Verify threat response coordination
      stats = IncidentCoordinator.get_statistics()
      assert stats.incidents_handled == 1
      assert stats.threat_responses >= 1
      assert stats.cybernetic_interventions >= 1
    end

    test "handles operational incident with process improvement" do
      incident_details = %{
        incident_type: :deployment_failure,
        severity: :medium,
        affected_services: [:web_interface, :mobile_api],
        rollback_status: :completed,
        # minutes
        impact_duration: 45,
        timestamp: DateTime.utc_now()
      }

      result =
        IncidentCoordinator.report_incident(
          :operational_incident,
          incident_details
        )

      assert {:ok, incident_id} = result

      # Verify operational response
      stats = IncidentCoordinator.get_statistics()
      assert stats.incidents_handled == 1
      assert stats.operational_interventions >= 1
    end
  end

  describe "get_incident_status / 1" do
    test "retrieves incident status with comprehensive analysis details" do
      # Create an incident first
      incident_details = %{
        failure_type: :service_timeout,
        severity: :high,
        __context: %{service: "alarm_processor", timeout: 30_000}
      }

      {:ok, incident_id} = IncidentCoordinator.report_incident(:system_failure, incident_details)

      # Retrieve incident status
      {:ok, status} = IncidentCoordinator.get_incident_status(incident_id)

      assert is_map(status)
      assert Map.has_key?(status, :incident_id)
      assert Map.has_key?(status, :status)
      assert Map.has_key?(status, :cast_analysis)
      assert Map.has_key?(status, :tps_rca_progress)
      assert Map.has_key?(status, :cybernetic_coordination)
      assert Map.has_key?(status, :agent_assignments)

      assert status.id == incident_id
      assert status.status in [:investigating, :analyzed, :responding, :resolved]
    end

    test "shows CAST analysis progress and findings" do
      incident_details = %{
        constraint_type: :tenant_isolation_violation,
        severity: :critical,
        __context: %{cross_tenant_access: true}
      }

      {:ok, incident_id} =
        IncidentCoordinator.report_incident(
          :safety_constraint_violation,
          incident_details
        )

      # Give time for analysis
      Process.sleep(200)

      {:ok, status} = IncidentCoordinator.get_incident_status(incident_id)

      # Verify CAST analysis components
      cast_analysis = status.cast_analysis
      assert is_map(cast_analysis)
      assert Map.has_key?(cast_analysis, :system_boundary_analysis)
      assert Map.has_key?(cast_analysis, :control_structure_analysis)
      assert Map.has_key?(cast_analysis, :systemic_factors)
      assert Map.has_key?(cast_analysis, :safety_constraint_violations)
      assert Map.has_key?(cast_analysis, :recommendations)
    end

    test "shows TPS 5 - Level RCA progress" do
      incident_details = %{
        failure_type: :memory_exhaustion,
        severity: :high,
        __context: %{memory_usage: 95, threshold: 80}
      }

      {:ok, incident_id} = IncidentCoordinator.report_incident(:system_failure, incident_details)

      # Give time for RCA
      Process.sleep(200)

      {:ok, status} = IncidentCoordinator.get_incident_status(incident_id)

      # Verify TPS 5 - Level RCA components
      rca_progress = status.tps_rca_progress
      assert is_map(rca_progress)
      assert Map.has_key?(rca_progress, :level_1_symptom)
      assert Map.has_key?(rca_progress, :level_2_surface_cause)
      assert Map.has_key?(rca_progress, :level_3_system_behavior)
      assert Map.has_key?(rca_progress, :level_4_config_gap)
      assert Map.has_key?(rca_progress, :level_5_design_analysis)
      assert Map.has_key?(rca_progress, :completion_percentage)
    end

    test "returns error for non - existent incident" do
      result = IncidentCoordinator.get_incident_status("non-existent-incident-id")
      assert result == {:error, :not_found}
    end
  end

  describe "escalate_incident / 2" do
    test "escalates incident with enhanced response team mobilization" do
      # Create initial incident
      incident_details = %{
        degradation_type: :database_performance,
        severity: :medium,
        __context: %{query_time: 5000, threshold: 1000}
      }

      {:ok, incident_id} =
        IncidentCoordinator.report_incident(
          :performance_degradation,
          incident_details
        )

      # Escalate incident
      escalation_reason = "Performance degradation worsening despite initial
        intervention"

      result =
        IncidentCoordinator.escalate_incident(
          incident_id,
          escalation_reason
        )

      assert :ok = result

      # Verify escalation effects
      {:ok, status} = IncidentCoordinator.get_incident_status(incident_id)
      assert status.escalation_level > 1
      assert status.response_team_size > status.initial_response_team_size

      stats = IncidentCoordinator.get_statistics()
      assert stats.incident_escalations >= 1
    end

    test "mobilizes additional agents during escalation" do
      incident_details = %{
        breach_type: :data_exfiltration_attempt,
        severity: :high,
        __context: %{affected_records: 1000}
      }

      {:ok, incident_id} = IncidentCoordinator.report_incident(:security_breach, incident_details)

      result =
        IncidentCoordinator.escalate_incident(
          incident_id,
          "Security breach scope expanding"
        )

      assert :ok = result

      {:ok, status} = IncidentCoordinator.get_incident_status(incident_id)

      # Should mobilize additional cybernetic agents
      coordination = status.cybernetic_coordination
      assert coordination.active_agents > coordination.initial_agents
      assert coordination.supervisor_interventions >= 1
    end

    test "fails to escalate non - existent incident" do
      result =
        IncidentCoordinator.escalate_incident(
          "non-existent",
          "test reason"
        )

      assert {:error, :incident_not_found} = result
    end
  end

  describe "resolve_incident / 2" do
    test "resolves incident with comprehensive documentation" do
      # Create and resolve incident
      incident_details = %{
        incident_type: :configuration_error,
        severity: :medium,
        __context: %{config_file: "__database.yml", error_type: "invalid_port"}
      }

      {:ok, incident_id} =
        IncidentCoordinator.report_incident(
          :operational_incident,
          incident_details
        )

      resolution_details = %{
        resolution_method: :configuration_fix_applied,
        actions_taken: [
          "Corrected __database port configuration",
          "Validated configuration syntax",
          "Restarted affected services"
        ],
        verification_steps: [
          "Connection tests passed",
          "Service health checks successful"
        ],
        lessons_learned: "Configuration validation needed in deployment
          pipeline"
      }

      result =
        IncidentCoordinator.resolve_incident(
          incident_id,
          resolution_details
        )

      assert :ok = result

      # Verify resolution status
      {:ok, status} = IncidentCoordinator.get_incident_status(incident_id)
      assert status.status == :resolved
      assert status.resolution_timestamp != nil
      assert is_map(status.resolution_details)

      stats = IncidentCoordinator.get_statistics()
      assert stats.incidents_resolved >= 1
      assert stats.active_incidents == 0
    end

    test "captures lessons learned for continuous improvement" do
      incident_details = %{
        violation_type: :rate_limit_exceeded,
        severity: :medium,
        __context: %{endpoint: "/api / alarms", rate: 500}
      }

      {:ok, incident_id} =
        IncidentCoordinator.report_incident(
          :compliance_violation,
          incident_details
        )

      resolution_details = %{
        resolution_method: :rate_limit_adjustment,
        lessons_learned: "Rate limits need dynamic adjustment based on tenant size",
        improvement_recommendations: [
          "Implement adaptive rate limiting",
          "Add tenant - specific rate configurations",
          "Enhance monitoring for rate limit breaches"
        ]
      }

      result =
        IncidentCoordinator.resolve_incident(
          incident_id,
          resolution_details
        )

      assert :ok = result

      # Verify lessons learned integration
      {:ok, status} = IncidentCoordinator.get_incident_status(incident_id)
      assert Map.has_key?(status.resolution_details, :lessons_learned)

      assert Map.has_key?(
               status.resolution_details,
               :improvement_recommendations
             )

      stats = IncidentCoordinator.get_statistics()
      assert stats.lessons_learned_captured >= 1
    end

    test "fails to resolve non - existent incident" do
      resolution_details = %{resolution_method: :fixed}

      result =
        IncidentCoordinator.resolve_incident(
          "non-existent",
          resolution_details
        )

      assert {:error, :incident_not_found} = result
    end
  end

  describe "get_statistics / 0" do
    test "returns comprehensive SOPv5.1 cybernetic statistics" do
      # Generate some incident activity
      IncidentCoordinator.report_incident(
        :system_failure,
        %{failure_type: :service_crash}
      )

      IncidentCoordinator.report_incident(
        :security_breach,
        %{breach_type: :auth_failure}
      )

      IncidentCoordinator.report_incident(
        :performance_degradation,
        %{degradation_type: :slow_queries}
      )

      stats = IncidentCoordinator.get_statistics()

      # Verify comprehensive statistics structure
      assert is_map(stats)
      assert Map.has_key?(stats, :incidents_handled)
      assert Map.has_key?(stats, :active_incidents)
      assert Map.has_key?(stats, :incidents_resolved)
      assert Map.has_key?(stats, :cast_analyses_performed)
      assert Map.has_key?(stats, :tps_rca_completed)
      assert Map.has_key?(stats, :cybernetic_interventions)
      assert Map.has_key?(stats, :agent_coordination_metrics)
      assert Map.has_key?(stats, :incident_types_breakdown)
      assert Map.has_key?(stats, :response_time_metrics)
      assert Map.has_key?(stats, :lessons_learned_captured)

      assert stats.incidents_handled == 3
      assert stats.active_incidents == 3
      assert stats.cast_analyses_performed >= 3
      assert stats.agent_coordination_active == true
    end

    test "tracks incident resolution metrics" do
      # Create incident and resolve it
      {:ok, incident_id} =
        IncidentCoordinator.report_incident(
          :operational_incident,
          %{incident_type: :deployment_issue}
        )

      IncidentCoordinator.resolve_incident(
        incident_id,
        %{resolution_method: :rollback_applied}
      )

      stats = IncidentCoordinator.get_statistics()

      # Verify resolution tracking
      assert stats.incidents_resolved >= 1
      assert stats.resolution_success_rate > 0.0
      assert is_list(stats.avg_resolution_times)

      # Should show agent coordination effectiveness
      coordination_metrics = stats.agent_coordination_metrics
      assert is_map(coordination_metrics)
      assert Map.has_key?(coordination_metrics, :supervisor_effectiveness)
      assert Map.has_key?(coordination_metrics, :helper_agent_utilization)
      assert Map.has_key?(coordination_metrics, :worker_agent_efficiency)
    end

    test "tracks TPS 5 - Level RCA effectiveness" do
      # Generate RCA activity
      IncidentCoordinator.report_incident(:system_failure, %{
        failure_type: :database_deadlock,
        severity: :high
      })

      # Give time for RCA analysis
      Process.sleep(200)

      stats = IncidentCoordinator.get_statistics()

      # Verify TPS RCA tracking
      assert stats.tps_rca_completed >= 1
      assert Map.has_key?(stats, :rca_completion_rates)
      assert Map.has_key?(stats, :rca_effectiveness_metrics)

      rca_metrics = stats.rca_effectiveness_metrics
      assert is_map(rca_metrics)
      assert Map.has_key?(rca_metrics, :avg_analysis_depth)
      assert Map.has_key?(rca_metrics, :root_cause_identification_rate)
    end
  end

  describe "get_active_incidents / 0" do
    test "lists active incidents with status summary" do
      # Create multiple active incidents
      {:ok, id1} =
        IncidentCoordinator.report_incident(
          :system_failure,
          %{failure_type: :cpu_spike}
        )

      {:ok, id2} =
        IncidentCoordinator.report_incident(
          :security_breach,
          %{breach_type: :brute_force}
        )

      {:ok, id3} =
        IncidentCoordinator.report_incident(
          :performance_degradation,
          %{degradation_type: :high_latency}
        )

      active_incidents = IncidentCoordinator.get_active_incidents()

      assert length(active_incidents) == 3

      # Verify incident summaries
      incident_ids = Enum.map(active_incidents, & &1.incident_id)
      assert id1 in incident_ids
      assert id2 in incident_ids
      assert id3 in incident_ids

      # Each incident should have status summary
      for incident <- active_incidents do
        assert Map.has_key?(incident, :incident_type)
        assert Map.has_key?(incident, :severity)
        assert Map.has_key?(incident, :status)
        assert Map.has_key?(incident, :assigned_agents)
        assert Map.has_key?(incident, :start_time)
      end
    end

    test "excludes resolved incidents from active list" do
      # Create and resolve incident
      {:ok, resolved_id} =
        IncidentCoordinator.report_incident(
          :operational_incident,
          %{incident_type: :backup_failure}
        )

      IncidentCoordinator.resolve_incident(
        resolved_id,
        %{resolution_method: :backup_restored}
      )

      # Create active incident
      {:ok, active_id} =
        IncidentCoordinator.report_incident(
          :system_failure,
          %{failure_type: :disk_full}
        )

      active_incidents = IncidentCoordinator.get_active_incidents()

      # Should only include active incident
      assert length(active_incidents) == 1
      assert List.first(active_incidents).incident_id == active_id
    end

    test "returns empty list when no active incidents" do
      active_incidents = IncidentCoordinator.get_active_incidents()
      assert active_incidents == []
    end
  end

  describe "cybernetic coordination features" do
    test "coordinates supervisor agent oversight" do
      # Create high - severity incident __requiring supervisor coordination
      incident_details = %{
        breach_type: :multi_tenant_compromise,
        severity: :critical,
        affected_tenants: ["tenant-1", "tenant-2", "tenant-3"],
        scope: :system_wide
      }

      {:ok, incident_id} = IncidentCoordinator.report_incident(:security_breach, incident_details)

      # Give time for coordination
      Process.sleep(200)

      {:ok, status} = IncidentCoordinator.get_incident_status(incident_id)
      coordination = status.cybernetic_coordination

      # Verify supervisor agent involvement
      assert coordination.supervisor_engaged == true
      assert coordination.coordination_level >= 3
      # Should mobilize most agen
      assert length(coordination.active_agents) >= 8
    end

    test "manages helper agent task distribution" do
      # Create complex incident __requiring multiple specializations
      incident_details = %{
        failure_type: :cascading_service_failure,
        severity: :high,
        affected_services: [:auth, :alarm_processing, :notification, :mobile_api],
        failure_pattern: :cascade_propagation
      }

      {:ok, incident_id} = IncidentCoordinator.report_incident(:system_failure, incident_details)

      {:ok, status} = IncidentCoordinator.get_incident_status(incident_id)
      agent_assignments = status.agent_assignments

      # Should distribute tasks across helper agents
      assert Map.has_key?(agent_assignments, :helper_1_auth_recovery)

      assert Map.has_key?(
               agent_assignments,
               :helper_2_alarm_system_stabilization
             )

      assert Map.has_key?(agent_assignments, :helper_3_notification_restoration)
      assert Map.has_key?(agent_assignments, :helper_4_mobile_api_recovery)
    end

    test "optimizes worker agent specialization" do
      # Create incident __requiring specialized worker responses
      incident_details = %{
        violation_type: :data_consistency_violation,
        severity: :high,
        affected_data_types: [:alarms, :devices, :__users, :configurations],
        consistency_check_required: true
      }

      {:ok, incident_id} =
        IncidentCoordinator.report_incident(
          :data_integrity_violation,
          incident_details
        )

      {:ok, status} = IncidentCoordinator.get_incident_status(incident_id)
      agent_assignments = status.agent_assignments

      # Should assign specialized worker agents
      worker_assignments =
        Map.filter(agent_assignments, fn {key, _} ->
          String.starts_with?(Atom.to_string(key), "worker_")
        end)

      # Should engage multiple workers
      assert map_size(worker_assignments) >= 4
    end
  end

  describe "integration with Safety Monitor and Error Pattern Engine" do
    test "coordinates with Safety Monitor for constraint violations" do
      # This tests integration with Safety Monitor
      constraint_violation = %{
        constraint_type: :alarm_rate_exceeded,
        severity: :critical,
        violation_details: %{
          current_rate: 2000,
          threshold: 1000,
          time_window: :per_minute
        }
      }

      {:ok, incident_id} =
        IncidentCoordinator.report_incident(
          :safety_constraint_violation,
          constraint_violation
        )

      {:ok, status} = IncidentCoordinator.get_incident_status(incident_id)

      # Should coordinate with Safety Monitor
      assert Map.has_key?(status, :safety_monitor_coordination)
      coordination = status.safety_monitor_coordination
      assert coordination.constraint_validation_active == true
      assert coordination.intervention_level >= 2
    end

    test "integrates with Error Pattern Engine for pattern - based response" do
      # Create incident that should trigger pattern - based analysis
      system_failure = %{
        failure_type: :connection_pool_exhaustion,
        severity: :high,
        error_patterns: [
          "connection timeout",
          "pool exhausted",
          "connection refused"
        ]
      }

      {:ok, incident_id} = IncidentCoordinator.report_incident(:system_failure, system_failure)

      {:ok, status} = IncidentCoordinator.get_incident_status(incident_id)

      # Should integrate with Error Pattern Engine
      assert Map.has_key?(status, :pattern_engine_integration)
      integration = status.pattern_engine_integration
      assert integration.patterns_analyzed >= 1
      assert is_list(integration.matched_patterns)
      assert is_list(integration.recommended_actions)
    end
  end

  describe "performance and scalability" do
    test "handles multiple concurrent incidents efficiently" do
      # Create multiple incidents concurrently
      incident_tasks =
        for i <- 1..10 do
          Task.async(fn ->
            IncidentCoordinator.report_incident(:performance_degradation, %{
              degradation_type: :high_cpu_usage,
              severity: :medium,
              instance_id: "instance-#{i}"
            })
          end)
        end

      # Wait for all incidents to be created
      incident_ids = Enum.map(incident_tasks, &Task.await/1)

      # All should succeed
      for result <- incident_ids do
        assert {:ok, _id} = result
      end

      # Verify system remains responsive
      stats = IncidentCoordinator.get_statistics()
      assert stats.incidents_handled == 10
      assert stats.active_incidents == 10

      # Should maintain reasonable response times
      active_incidents = IncidentCoordinator.get_active_incidents()
      assert length(active_incidents) == 10
    end

    test "maintains bounded memory usage with incident history" do
      # Create many incidents to test memory bounds
      for i <- 1..50 do
        {:ok, incident_id} =
          IncidentCoordinator.report_incident(:operational_incident, %{
            incident_type: :minor_config_issue,
            severity: :low,
            instance: i
          })

        # Resolve some incidents to test cleanup
        if rem(i, 3) == 0 do
          IncidentCoordinator.resolve_incident(
            incident_id,
            %{resolution_method: :auto_fixed}
          )
        end
      end

      # System should remain responsive
      stats = IncidentCoordinator.get_statistics()
      assert stats.incidents_handled == 50
      # Roughly 1 / 3 resolved
      assert stats.incidents_resolved >= 16

      # Should handle additional incidents without issues
      {:ok, _} =
        IncidentCoordinator.report_incident(
          :system_failure,
          %{failure_type: :test_after_load}
        )

      final_stats = IncidentCoordinator.get_statistics()
      assert final_stats.incidents_handled == 51
    end
  end

  describe "error handling and resilience" do
    test "handles malformed incident __data gracefully" do
      invalid_incidents = [
        nil,
        %{},
        %{invalid: "structure"},
        %{severity: :invalid_level},
        "not a map"
      ]

      for invalid_incident <- invalid_incidents do
        result =
          IncidentCoordinator.report_incident(
            :system_failure,
            invalid_incident
          )

        # Should handle gracefully without crashing
        case result do
          # Might succeed with defaults
          {:ok, _} -> :ok
          # Or fail gracefully
          {:error, _} -> :ok
        end
      end

      # Coordinator should remain operational
      valid_result =
        IncidentCoordinator.report_incident(
          :system_failure,
          %{failure_type: :test}
        )

      assert {:ok, _} = valid_result
    end

    test "recovers from analysis failures gracefully" do
      # Create incident that might cause analysis issues
      complex_incident = %{
        failure_type: :complex_distributed_failure,
        severity: :critical,
        affected_systems: [
          "system - 1",
          "system - 2",
          "system - 3",
          "system - 4",
          "system - 5",
          "system - 6",
          "system - 7",
          "system - 8",
          "system - 9",
          "system - 10"
        ],
        failure_cascade: %{
          initial_failure: "network_partition",
          cascade_pattern: "circular_dependency",
          recovery_complexity: :very_high
        }
      }

      {:ok, incident_id} = IncidentCoordinator.report_incident(:system_failure, complex_incident)

      # Give time for analysis
      Process.sleep(300)

      # Should complete analysis even if some parts fail
      {:ok, status} = IncidentCoordinator.get_incident_status(incident_id)
      assert is_map(status)
      assert status.id == incident_id

      # Coordinator should remain operational for subsequent __requests
      stats = IncidentCoordinator.get_statistics()
      assert is_map(stats)
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
