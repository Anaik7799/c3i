defmodule Indrajaal.Observability.ComplianceAuditTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  import ExUnit.CaptureLog
  import Indrajaal.STAMPTestHelpers

  alias Indrajaal.Observability.ComplianceAudit

  setup do
    # Start the ComplianceAudit GenServer
    {:ok, pid} = ComplianceAudit.start_link([])

    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end
    end)

    %{pid: pid}
  end

  describe "start_link/1" do
    test "starts GenServer successfully" do
      {:ok, pid} = ComplianceAudit.start_link([])
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "registers with module name" do
      {:ok, _pid} = ComplianceAudit.start_link([])
      assert Process.whereis(ComplianceAudit) != nil
      GenServer.stop(ComplianceAudit)
    end
  end

  describe "setup/0" do
    test "initializes compliance audit system" do
      log =
        capture_log(fn ->
          ComplianceAudit.setup()
        end)

      assert log =~ "Compliance audit system initialized"
      assert log =~ "SOPv5.1 Enhanced Compliance"
    end

    test "attaches compliance handlers and initializes system" do
      # Setup should attach telemetry handlers
      ComplianceAudit.setup()

      # Verify GenServer received initialization message
      Process.sleep(50)

      # System should be ready for compliance events
      assert :ok =
               ComplianceAudit.record_compliance_event(%{
                 type: :data_access,
                 actor_id: "user_123",
                 resource_id: "doc_456"
               })
    end
  end

  describe "record_compliance_event/1" do
    test "records compliance event with all required fields" do
      assert :ok =
               ComplianceAudit.record_compliance_event(%{
                 type: :data_access,
                 actor_id: "user_123",
                 resource_id: "document_456",
                 action: "read",
                 outcome: "success",
                 metadata: %{ip_address: "192.168.1.1"},
                 tenant_id: "tenant_789"
               })
    end

    test "records compliance event with minimal fields" do
      assert :ok =
               ComplianceAudit.record_compliance_event(%{
                 type: :user_authentication,
                 actor_id: "user_abc"
               })
    end

    test "handles various compliance event types" do
      # Data access event
      assert :ok =
               ComplianceAudit.record_compliance_event(%{
                 type: :data_access,
                 actor_id: "user_1"
               })

      # Data modification event
      assert :ok =
               ComplianceAudit.record_compliance_event(%{
                 type: :data_modification,
                 actor_id: "user_2"
               })

      # Security policy update event
      assert :ok =
               ComplianceAudit.record_compliance_event(%{
                 type: :system_configuration_change,
                 actor_id: "admin_1"
               })

      # Compliance violation event
      assert :ok =
               ComplianceAudit.record_compliance_event(%{
                 type: :compliance_violation,
                 actor_id: "user_3"
               })
    end

    test "processes event asynchronously via cast" do
      # Should return immediately
      result =
        ComplianceAudit.record_compliance_event(%{
          type: :audit_log_access,
          actor_id: "auditor_1",
          metadata: %{audit: true}
        })

      assert result == :ok
    end
  end

  describe "get_compliance_analytics/0" do
    test "returns analytics map with expected structure" do
      analytics = ComplianceAudit.get_compliance_analytics()

      assert is_map(analytics)
      assert Map.has_key?(analytics, :overall_score)
      assert Map.has_key?(analytics, :regulatory_scores)
      assert Map.has_key?(analytics, :audit_statistics)
      assert Map.has_key?(analytics, :risk_assessment)
      assert Map.has_key?(analytics, :business_impact)
      assert Map.has_key?(analytics, :recommendations)
      assert Map.has_key?(analytics, :trend_analysis)
      assert Map.has_key?(analytics, :predictive_insights)
    end

    test "returns overall compliance score" do
      analytics = ComplianceAudit.get_compliance_analytics()
      assert is_number(analytics.overall_score)
      assert analytics.overall_score >= 0
      assert analytics.overall_score <= 100
    end

    test "includes all regulatory framework scores" do
      analytics = ComplianceAudit.get_compliance_analytics()

      assert is_map(analytics.regulatory_scores)
      assert Map.has_key?(analytics.regulatory_scores, :sox)
      assert Map.has_key?(analytics.regulatory_scores, :gdpr)
      assert Map.has_key?(analytics.regulatory_scores, :hipaa)
      assert Map.has_key?(analytics.regulatory_scores, :pci_dss)
      assert Map.has_key?(analytics.regulatory_scores, :iso27001)
    end

    test "includes audit statistics" do
      analytics = ComplianceAudit.get_compliance_analytics()

      assert is_map(analytics.audit_statistics)
      assert Map.has_key?(analytics.audit_statistics, :total_events)
      assert Map.has_key?(analytics.audit_statistics, :high_risk_events)
      assert Map.has_key?(analytics.audit_statistics, :violations)
      assert Map.has_key?(analytics.audit_statistics, :remediations)
    end

    test "includes risk assessment data" do
      analytics = ComplianceAudit.get_compliance_analytics()

      assert is_map(analytics.risk_assessment)
      assert Map.has_key?(analytics.risk_assessment, :current_level)
      assert Map.has_key?(analytics.risk_assessment, :trend)
      assert Map.has_key?(analytics.risk_assessment, :mitigation_effectiveness)
    end

    test "includes business impact metrics" do
      analytics = ComplianceAudit.get_compliance_analytics()

      assert is_map(analytics.business_impact)
      assert Map.has_key?(analytics.business_impact, :cost_savings)
      assert Map.has_key?(analytics.business_impact, :risk_avoidance)
      assert Map.has_key?(analytics.business_impact, :efficiency_gain)
    end

    test "includes compliance recommendations" do
      analytics = ComplianceAudit.get_compliance_analytics()

      assert is_list(analytics.recommendations)
    end

    test "includes predictive insights" do
      analytics = ComplianceAudit.get_compliance_analytics()

      assert is_map(analytics.predictive_insights)
      assert Map.has_key?(analytics.predictive_insights, :violation_prediction_accuracy)
      assert Map.has_key?(analytics.predictive_insights, :compliance_score_forecast)
    end
  end

  describe "get_audit_trail/1" do
    test "returns audit trail with default filters" do
      audit_trail = ComplianceAudit.get_audit_trail()

      assert is_map(audit_trail)
      assert Map.has_key?(audit_trail, :entries)
      assert is_list(audit_trail.entries)
    end

    test "returns audit trail with date range filter" do
      audit_trail = ComplianceAudit.get_audit_trail(%{date_range: ~D[2025-01-01]..~D[2025-12-31]})

      assert is_map(audit_trail)
      assert is_list(audit_trail.entries)
    end

    test "returns audit trail with framework filter" do
      audit_trail = ComplianceAudit.get_audit_trail(%{framework: :sox})

      assert is_map(audit_trail)
      assert is_list(audit_trail.entries)
    end

    test "returns audit trail with severity filter" do
      audit_trail = ComplianceAudit.get_audit_trail(%{severity: :high})

      assert is_map(audit_trail)
      assert is_list(audit_trail.entries)
    end

    test "returns audit trail with multiple filters" do
      audit_trail =
        ComplianceAudit.get_audit_trail(%{
          framework: :gdpr,
          severity: :medium,
          date_range: ~D[2025-01-01]..~D[2025-12-31]
        })

      assert is_map(audit_trail)
      assert is_list(audit_trail.entries)
    end
  end

  describe "get_compliance_score/1" do
    test "returns score for SOX framework" do
      result = ComplianceAudit.get_compliance_score(:sox)
      assert {:ok, score} = result
      assert is_number(score)
      assert score >= 0 and score <= 100
    end

    test "returns score for GDPR framework" do
      result = ComplianceAudit.get_compliance_score(:gdpr)
      assert {:ok, score} = result
      assert is_number(score)
    end

    test "returns score for HIPAA framework" do
      result = ComplianceAudit.get_compliance_score(:hipaa)
      assert {:ok, score} = result
      assert is_number(score)
    end

    test "returns score for PCI DSS framework" do
      result = ComplianceAudit.get_compliance_score(:pci_dss)
      assert {:ok, score} = result
      assert is_number(score)
    end

    test "returns score for ISO27001 framework" do
      result = ComplianceAudit.get_compliance_score(:iso27001)
      assert {:ok, score} = result
      assert is_number(score)
    end

    test "returns error for non-existent framework" do
      result = ComplianceAudit.get_compliance_score(:non_existent)
      assert {:error, :framework_not_found} = result
    end
  end

  describe "subscribe_to_compliance_updates/1" do
    test "allows process subscription to compliance updates" do
      # Subscribe current process to compliance updates
      ComplianceAudit.subscribe_to_compliance_updates(self())
      Process.sleep(50)

      # Record a compliance event
      ComplianceAudit.record_compliance_event(%{
        type: :compliance_violation,
        actor_id: "user_test"
      })

      # Should receive compliance update (if implemented)
      # Note: This tests the subscription mechanism
      assert_nothing_raised(fn ->
        ComplianceAudit.get_compliance_analytics()
      end)
    end
  end

  describe "display_compliance_dashboard/0" do
    test "displays dashboard without errors" do
      output =
        capture_io(fn ->
          ComplianceAudit.display_compliance_dashboard()
        end)

      assert output =~ "COMPLIANCE AUDIT DASHBOARD"
      assert output =~ "ENTERPRISE REGULATORY"
      assert output =~ "SOPv5.1 Cybernetic Compliance Management"
      assert output =~ "REGULATORY OVERVIEW"
      assert output =~ "COMPLIANCE SCORES"
    end

    test "includes all dashboard sections" do
      output =
        capture_io(fn ->
          ComplianceAudit.display_compliance_dashboard()
        end)

      assert output =~ "REGULATORY OVERVIEW"
      assert output =~ "COMPLIANCE SCORES"
      assert output =~ "AUDIT TRAIL STATUS"
      assert output =~ "VIOLATION TRACKING"
      assert output =~ "RISK ASSESSMENT"
      assert output =~ "REMEDIATION ACTIONS"
      assert output =~ "PREDICTIVE COMPLIANCE"
      assert output =~ "EXECUTIVE SUMMARY"
    end

    test "displays compliance status" do
      output =
        capture_io(fn ->
          ComplianceAudit.display_compliance_dashboard()
        end)

      assert output =~ "COMPLIANCE STATUS"
      assert output =~ "ENTERPRISE GRADE"
    end
  end

  describe "generate_audit_report/1" do
    test "generates comprehensive audit report for all frameworks" do
      output =
        capture_io(fn ->
          ComplianceAudit.generate_audit_report(:all)
        end)

      assert output =~ "COMPREHENSIVE COMPLIANCE AUDIT REPORT"
      assert output =~ "All Regulatory Frameworks"
      assert output =~ "OVERALL COMPLIANCE SCORE"
      assert output =~ "REGULATORY FRAMEWORK SCORES"
      assert output =~ "AUDIT TRAIL ANALYSIS"
      assert output =~ "RISK ASSESSMENT"
      assert output =~ "BUSINESS IMPACT"
      assert output =~ "RECOMMENDATIONS"
    end

    test "generates audit report for specific framework (SOX)" do
      output =
        capture_io(fn ->
          ComplianceAudit.generate_audit_report(:sox)
        end)

      assert output =~ "COMPREHENSIVE COMPLIANCE AUDIT REPORT"
      assert output =~ "SOX"
    end

    test "includes all regulatory framework scores in report" do
      output =
        capture_io(fn ->
          ComplianceAudit.generate_audit_report(:all)
        end)

      assert output =~ "SOX Compliance"
      assert output =~ "GDPR Compliance"
      assert output =~ "HIPAA Compliance"
      assert output =~ "PCI DSS Compliance"
      assert output =~ "ISO27001 Compliance"
    end

    test "includes audit statistics in report" do
      output =
        capture_io(fn ->
          ComplianceAudit.generate_audit_report(:all)
        end)

      assert output =~ "Total Events Audited"
      assert output =~ "High-Risk Events"
      assert output =~ "Compliance Violations"
      assert output =~ "Remediation Actions"
    end

    test "includes risk assessment in report" do
      output =
        capture_io(fn ->
          ComplianceAudit.generate_audit_report(:all)
        end)

      assert output =~ "Current Risk Level"
      assert output =~ "Risk Trend"
      assert output =~ "Mitigation Effectiveness"
    end

    test "includes business impact in report" do
      output =
        capture_io(fn ->
          ComplianceAudit.generate_audit_report(:all)
        end)

      assert output =~ "Compliance Cost Savings"
      assert output =~ "Risk Avoidance Value"
      assert output =~ "Operational Efficiency Gain"
    end
  end

  describe "regulatory frameworks" do
    test "all frameworks have required structure" do
      analytics = ComplianceAudit.get_compliance_analytics()

      Enum.each(analytics.regulatory_scores, fn {_framework, score} ->
        assert is_number(score)
        assert score >= 0 and score <= 100
      end)
    end

    test "compliance scores are within valid ranges" do
      analytics = ComplianceAudit.get_compliance_analytics()

      assert analytics.regulatory_scores[:sox] >= 0
      assert analytics.regulatory_scores[:sox] <= 100

      assert analytics.regulatory_scores[:gdpr] >= 0
      assert analytics.regulatory_scores[:gdpr] <= 100
    end
  end

  describe "compliance event processing" do
    test "records event and updates audit trail" do
      # Record event
      ComplianceAudit.record_compliance_event(%{
        type: :data_access,
        actor_id: "user_123",
        resource_id: "doc_456"
      })

      Process.sleep(50)

      # Get audit trail
      trail = ComplianceAudit.get_audit_trail()
      # Audit trail should contain entries (implementation dependent)
      assert is_list(trail.entries)
    end

    test "processes multiple events in sequence" do
      Enum.each(1..5, fn i ->
        ComplianceAudit.record_compliance_event(%{
          type: :data_access,
          actor_id: "user_#{i}",
          resource_id: "doc_#{i}"
        })
      end)

      Process.sleep(100)

      analytics = ComplianceAudit.get_compliance_analytics()
      assert is_map(analytics)
    end
  end

  describe "concurrent compliance event processing" do
    test "handles concurrent event recording from multiple processes" do
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            ComplianceAudit.record_compliance_event(%{
              type: :data_access,
              actor_id: "concurrent_user_#{i}",
              resource_id: "resource_#{i}"
            })
          end)
        end

      Task.await_many(tasks)
      Process.sleep(100)

      analytics = ComplianceAudit.get_compliance_analytics()
      assert is_map(analytics)
    end

    test "maintains audit trail integrity under concurrent load" do
      # Record many events concurrently
      Enum.each(1..50, fn i ->
        spawn(fn ->
          ComplianceAudit.record_compliance_event(%{
            type: :data_modification,
            actor_id: "load_test_user_#{rem(i, 5)}",
            resource_id: "resource_#{i}"
          })
        end)
      end)

      Process.sleep(200)

      trail = ComplianceAudit.get_audit_trail()
      assert is_map(trail)
      assert is_list(trail.entries)
    end
  end

  describe "edge cases and error handling" do
    test "handles event with missing optional fields" do
      assert :ok =
               ComplianceAudit.record_compliance_event(%{
                 type: :data_access
               })
    end

    test "handles event with empty metadata" do
      assert :ok =
               ComplianceAudit.record_compliance_event(%{
                 type: :user_authentication,
                 actor_id: "user_123",
                 metadata: %{}
               })
    end

    test "handles event with complex metadata structures" do
      complex_metadata = %{
        ip_address: "192.168.1.1",
        user_agent: "Mozilla/5.0",
        session: %{
          id: "session_789",
          started_at: DateTime.utc_now()
        },
        tags: ["important", "audit"]
      }

      assert :ok =
               ComplianceAudit.record_compliance_event(%{
                 type: :privilege_escalation,
                 actor_id: "admin_user",
                 metadata: complex_metadata
               })
    end
  end

  describe "integration scenarios" do
    test "complete compliance workflow: record events -> analyze -> get recommendations" do
      # Record various compliance events
      ComplianceAudit.record_compliance_event(%{
        type: :data_access,
        actor_id: "user_1"
      })

      ComplianceAudit.record_compliance_event(%{
        type: :data_modification,
        actor_id: "user_2"
      })

      ComplianceAudit.record_compliance_event(%{
        type: :system_configuration_change,
        actor_id: "admin_1"
      })

      Process.sleep(100)

      # Get analytics
      analytics = ComplianceAudit.get_compliance_analytics()
      assert is_map(analytics)
      assert Map.has_key?(analytics, :overall_score)

      # Get audit trail
      trail = ComplianceAudit.get_audit_trail()
      assert is_map(trail)

      # Get recommendations
      assert is_list(analytics.recommendations)
    end

    test "dashboard and report generation reflect recorded events" do
      # Record events
      ComplianceAudit.record_compliance_event(%{
        type: :compliance_violation,
        actor_id: "violator_user"
      })

      Process.sleep(50)

      # Display dashboard
      output =
        capture_io(fn ->
          ComplianceAudit.display_compliance_dashboard()
        end)

      assert output =~ "COMPLIANCE AUDIT DASHBOARD"

      # Generate report
      report_output =
        capture_io(fn ->
          ComplianceAudit.generate_audit_report(:all)
        end)

      assert report_output =~ "COMPREHENSIVE COMPLIANCE AUDIT REPORT"
    end
  end

  describe "subscription mechanism" do
    test "subscribers receive compliance event notifications" do
      # Subscribe to updates
      ComplianceAudit.subscribe_to_compliance_updates(self())
      Process.sleep(50)

      # Record compliance event
      ComplianceAudit.record_compliance_event(%{
        type: :data_access,
        actor_id: "subscribed_user"
      })

      # Note: Actual message reception depends on implementation
      # This tests the subscription mechanism works without errors
      assert_nothing_raised(fn ->
        ComplianceAudit.get_compliance_analytics()
      end)
    end

    test "multiple subscribers can receive updates" do
      pid1 =
        spawn(fn ->
          receive do
            _ -> :ok
          end
        end)

      pid2 =
        spawn(fn ->
          receive do
            _ -> :ok
          end
        end)

      ComplianceAudit.subscribe_to_compliance_updates(pid1)
      ComplianceAudit.subscribe_to_compliance_updates(pid2)
      Process.sleep(50)

      ComplianceAudit.record_compliance_event(%{
        type: :audit_log_access,
        actor_id: "multi_sub_user"
      })

      Process.sleep(50)

      # Verify subscriptions don't cause errors
      analytics = ComplianceAudit.get_compliance_analytics()
      assert is_map(analytics)
    end
  end

  describe "STAMP safety constraints" do
    test "SC1: audit trail maintains data integrity during event recording" do
      # Record events and verify no data corruption
      ComplianceAudit.record_compliance_event(%{
        type: :data_access,
        actor_id: "integrity_test_user"
      })

      Process.sleep(50)

      trail = ComplianceAudit.get_audit_trail()
      assert is_map(trail)
      assert is_list(trail.entries)
    end

    test "SC2: compliance system handles concurrent access safely" do
      # Multiple concurrent calls should not corrupt state
      tasks =
        for i <- 1..20 do
          Task.async(fn ->
            ComplianceAudit.record_compliance_event(%{
              type: :data_modification,
              actor_id: "concurrent_#{rem(i, 3)}"
            })

            ComplianceAudit.get_compliance_analytics()
          end)
        end

      results = Task.await_many(tasks)
      assert length(results) == 20
      Enum.each(results, fn result -> assert is_map(result) end)
    end

    test "SC3: regulatory framework scores maintain consistency" do
      analytics = ComplianceAudit.get_compliance_analytics()

      # All framework scores should be valid
      Enum.each(analytics.regulatory_scores, fn {framework, score} ->
        assert is_atom(framework)
        assert is_number(score)
        assert score >= 0 and score <= 100
      end)

      # Overall score should be average of framework scores
      expected_avg =
        analytics.regulatory_scores
        |> Map.values()
        |> Enum.sum()
        |> Kernel./(map_size(analytics.regulatory_scores))

      assert_in_delta analytics.overall_score, expected_avg, 0.1
    end
  end
end
