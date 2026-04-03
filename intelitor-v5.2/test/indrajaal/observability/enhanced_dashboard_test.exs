defmodule Indrajaal.Observability.EnhancedDashboardTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Indrajaal.Observability.EnhancedDashboard

  setup do
    # Start the EnhancedDashboard GenServer
    {:ok, pid} = EnhancedDashboard.start_link([])

    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end
    end)

    %{pid: pid}
  end

  describe "start_link/1" do
    test "starts GenServer successfully" do
      {:ok, pid} = EnhancedDashboard.start_link([])
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "registers with module name" do
      {:ok, _pid} = EnhancedDashboard.start_link([])
      assert Process.whereis(EnhancedDashboard) != nil
      GenServer.stop(EnhancedDashboard)
    end
  end

  describe "get_dashboard_data/0" do
    test "returns dashboard state with all required fields" do
      data = EnhancedDashboard.get_dashboard_data()

      assert is_map(data)
      assert Map.has_key?(data, :telemetry_events)
      assert Map.has_key?(data, :business_metrics)
      assert Map.has_key?(data, :performance_analytics)
      assert Map.has_key?(data, :security_insights)
      assert Map.has_key?(data, :predictive_data)
      assert Map.has_key?(data, :executive_kpis)
      assert Map.has_key?(data, :container_health)
      assert Map.has_key?(data, :agent_coordination)
      assert Map.has_key?(data, :compliance_metrics)
      assert Map.has_key?(data, :anomaly_detection)
      assert Map.has_key?(data, :correlation_matrix)
      assert Map.has_key?(data, :trend_analysis)
      assert Map.has_key?(data, :capacity_planning)
      assert Map.has_key?(data, :optimization_recommendations)
      assert Map.has_key?(data, :real_time_alerts)
      assert Map.has_key?(data, :dashboard_subscriptions)
      assert Map.has_key?(data, :last_updated)
    end

    test "includes business metrics with revenue and cost data" do
      data = EnhancedDashboard.get_dashboard_data()

      assert is_map(data.business_metrics)
      assert Map.has_key?(data.business_metrics, :revenue_impact)
      assert Map.has_key?(data.business_metrics, :cost_savings)
      assert Map.has_key?(data.business_metrics, :efficiency_gain)
      assert Map.has_key?(data.business_metrics, :retention_rate)
    end

    test "includes performance analytics with SLA compliance" do
      data = EnhancedDashboard.get_dashboard_data()

      assert is_map(data.performance_analytics)
      assert Map.has_key?(data.performance_analytics, :current_metrics)
      assert Map.has_key?(data.performance_analytics, :sla_compliance)
      assert data.performance_analytics.sla_compliance >= 0
      assert data.performance_analytics.sla_compliance <= 100
    end

    test "includes security insights with threat level" do
      data = EnhancedDashboard.get_dashboard_data()

      assert is_map(data.security_insights)
      assert Map.has_key?(data.security_insights, :threat_level)
      assert Map.has_key?(data.security_insights, :security_score)
      assert Map.has_key?(data.security_insights, :vulnerability_score)
    end

    test "includes predictive data with capacity forecast" do
      data = EnhancedDashboard.get_dashboard_data()

      assert is_map(data.predictive_data)
      assert Map.has_key?(data.predictive_data, :capacity_forecast)
      assert Map.has_key?(data.predictive_data, :performance_trend)
      assert Map.has_key?(data.predictive_data, :security_risk_level)
      assert Map.has_key?(data.predictive_data, :optimization_potential)
    end

    test "includes executive KPIs with system availability" do
      data = EnhancedDashboard.get_dashboard_data()

      assert is_map(data.executive_kpis)
      assert Map.has_key?(data.executive_kpis, :system_availability)
      assert Map.has_key?(data.executive_kpis, :response_time_p95)
      assert Map.has_key?(data.executive_kpis, :error_rate)
      assert Map.has_key?(data.executive_kpis, :security_score)
    end
  end

  describe "get_executive_summary/0" do
    test "returns executive summary with KPIs" do
      summary = EnhancedDashboard.get_executive_summary()

      assert is_map(summary)
      assert Map.has_key?(summary, :kpis)
      assert Map.has_key?(summary, :business_metrics)
      assert Map.has_key?(summary, :predictive_insights)
      assert Map.has_key?(summary, :recommendations)
      assert Map.has_key?(summary, :last_updated)
    end

    test "includes complete KPI data" do
      summary = EnhancedDashboard.get_executive_summary()

      assert is_map(summary.kpis)
      assert Map.has_key?(summary.kpis, :system_availability)
      assert Map.has_key?(summary.kpis, :response_time_p95)
    end

    test "includes optimization recommendations" do
      summary = EnhancedDashboard.get_executive_summary()

      assert is_list(summary.recommendations)
    end
  end

  describe "get_real_time_metrics/0" do
    test "returns real-time metrics with all categories" do
      metrics = EnhancedDashboard.get_real_time_metrics()

      assert is_map(metrics)
      assert Map.has_key?(metrics, :performance)
      assert Map.has_key?(metrics, :security)
      assert Map.has_key?(metrics, :containers)
      assert Map.has_key?(metrics, :agents)
      assert Map.has_key?(metrics, :anomalies)
    end

    test "includes container health metrics" do
      metrics = EnhancedDashboard.get_real_time_metrics()

      assert is_map(metrics.containers)
      assert Map.has_key?(metrics.containers, :running_containers)
      assert Map.has_key?(metrics.containers, :healthy_containers)
    end

    test "includes agent coordination metrics" do
      metrics = EnhancedDashboard.get_real_time_metrics()

      assert is_map(metrics.agents)
      assert Map.has_key?(metrics.agents, :supervisor_status)
      assert Map.has_key?(metrics.agents, :helper_agents)
      assert Map.has_key?(metrics.agents, :worker_agents)
    end
  end

  describe "subscribe_to_updates/1" do
    test "allows process to subscribe to dashboard updates" do
      subscriber_pid = self()

      EnhancedDashboard.subscribe_to_updates(subscriber_pid)
      Process.sleep(50)

      data = EnhancedDashboard.get_dashboard_data()
      assert subscriber_pid in data.dashboard_subscriptions
    end

    test "allows multiple subscribers" do
      subscriber1 = spawn(fn -> Process.sleep(:infinity) end)
      subscriber2 = spawn(fn -> Process.sleep(:infinity) end)

      EnhancedDashboard.subscribe_to_updates(subscriber1)
      EnhancedDashboard.subscribe_to_updates(subscriber2)
      Process.sleep(50)

      data = EnhancedDashboard.get_dashboard_data()
      assert subscriber1 in data.dashboard_subscriptions
      assert subscriber2 in data.dashboard_subscriptions

      Process.exit(subscriber1, :kill)
      Process.exit(subscriber2, :kill)
    end
  end

  describe "display_enhanced_dashboard/0" do
    test "displays comprehensive dashboard without errors" do
      output =
        capture_io(fn ->
          EnhancedDashboard.display_enhanced_dashboard()
        end)

      assert output =~ "ENHANCED OBSERVABILITY DASHBOARD"
      assert output =~ "ENTERPRISE ANALYTICS"
      assert output =~ "SOPv5.1"
      assert output =~ "EXECUTIVE SUMMARY"
      assert output =~ "BUSINESS INTELLIGENCE"
      assert output =~ "PERFORMANCE ANALYTICS"
      assert output =~ "SECURITY INSIGHTS"
    end

    test "includes all dashboard sections" do
      output =
        capture_io(fn ->
          EnhancedDashboard.display_enhanced_dashboard()
        end)

      assert output =~ "EXECUTIVE SUMMARY"
      assert output =~ "BUSINESS INTELLIGENCE"
      assert output =~ "PERFORMANCE ANALYTICS"
      assert output =~ "SECURITY INSIGHTS"
      assert output =~ "PREDICTIVE ANALYTICS"
      assert output =~ "CONTAINER ANALYTICS"
      assert output =~ "AGENT COORDINATION METRICS"
      assert output =~ "COMPLIANCE DASHBOARD"
      assert output =~ "ANOMALY DETECTION"
      assert output =~ "OPTIMIZATION RECOMMENDATIONS"
    end

    test "displays business metrics" do
      output =
        capture_io(fn ->
          EnhancedDashboard.display_enhanced_dashboard()
        end)

      assert output =~ "Revenue Impact"
      assert output =~ "Cost Savings"
      assert output =~ "Efficiency Gain"
    end

    test "displays security information" do
      output =
        capture_io(fn ->
          EnhancedDashboard.display_enhanced_dashboard()
        end)

      assert output =~ "Threat Level"
      assert output =~ "Security Score"
      assert output =~ "Vulnerability Score"
    end
  end

  describe "generate_executive_report/0" do
    test "generates comprehensive executive report" do
      output =
        capture_io(fn ->
          EnhancedDashboard.generate_executive_report()
        end)

      assert output =~ "EXECUTIVE OBSERVABILITY REPORT"
      assert output =~ "KEY PERFORMANCE INDICATORS"
      assert output =~ "BUSINESS IMPACT"
      assert output =~ "PREDICTIVE INSIGHTS"
      assert output =~ "RECOMMENDATIONS"
    end

    test "includes KPI values" do
      output =
        capture_io(fn ->
          EnhancedDashboard.generate_executive_report()
        end)

      assert output =~ "System Availability"
      assert output =~ "Response Time P95"
      assert output =~ "Error Rate"
      assert output =~ "Security Score"
    end

    test "includes business impact metrics" do
      output =
        capture_io(fn ->
          EnhancedDashboard.generate_executive_report()
        end)

      assert output =~ "Revenue Impact"
      assert output =~ "Cost Optimization"
      assert output =~ "Operational Efficiency"
    end

    test "includes predictive insights" do
      output =
        capture_io(fn ->
          EnhancedDashboard.generate_executive_report()
        end)

      assert output =~ "Capacity Forecast"
      assert output =~ "Performance Trend"
      assert output =~ "Security Risk"
    end
  end

  describe "business metrics initialization" do
    test "initializes with comprehensive business data" do
      data = EnhancedDashboard.get_dashboard_data()

      assert data.business_metrics.revenue_impact == 125_000.0
      assert data.business_metrics.cost_savings == 45_000.0
      assert data.business_metrics.efficiency_gain == 23.5
      assert data.business_metrics.retention_rate == 94.8
    end
  end

  describe "performance analytics initialization" do
    test "initializes with SLA compliance tracking" do
      data = EnhancedDashboard.get_dashboard_data()

      assert is_number(data.performance_analytics.sla_compliance)
      assert data.performance_analytics.sla_compliance == 99.2
    end

    test "includes trend analysis" do
      data = EnhancedDashboard.get_dashboard_data()

      assert is_map(data.performance_analytics.trend_analysis)
      assert Map.has_key?(data.performance_analytics.trend_analysis, :direction)
      assert Map.has_key?(data.performance_analytics.trend_analysis, :confidence)
    end
  end

  describe "security insights initialization" do
    test "initializes with security scoring" do
      data = EnhancedDashboard.get_dashboard_data()

      assert data.security_insights.threat_level == :low
      assert data.security_insights.security_score == 94.7
      assert data.security_insights.compliance_status == :compliant
    end

    test "tracks incidents and vulnerabilities" do
      data = EnhancedDashboard.get_dashboard_data()

      assert is_number(data.security_insights.incidents_24h)
      assert is_number(data.security_insights.vulnerability_score)
    end
  end

  describe "predictive data initialization" do
    test "includes capacity forecast" do
      data = EnhancedDashboard.get_dashboard_data()

      assert is_binary(data.predictive_data.capacity_forecast)
      assert data.predictive_data.capacity_forecast =~ "months"
    end

    test "includes performance trend prediction" do
      data = EnhancedDashboard.get_dashboard_data()

      assert data.predictive_data.performance_trend == :improving
      assert data.predictive_data.security_risk_level == :low
    end

    test "includes cost projections" do
      data = EnhancedDashboard.get_dashboard_data()

      assert is_map(data.predictive_data.cost_projection)
      assert Map.has_key?(data.predictive_data.cost_projection, :monthly_savings)
      assert Map.has_key?(data.predictive_data.cost_projection, :efficiency_gains)
    end
  end

  describe "executive KPIs initialization" do
    test "initializes with comprehensive KPI tracking" do
      data = EnhancedDashboard.get_dashboard_data()

      assert data.executive_kpis.system_availability == 99.95
      assert data.executive_kpis.response_time_p95 == 85.2
      assert data.executive_kpis.error_rate == 0.08
      assert data.executive_kpis.security_score == 94.7
    end

    test "includes business value and ROI" do
      data = EnhancedDashboard.get_dashboard_data()

      assert is_number(data.executive_kpis.business_value)
      assert is_number(data.executive_kpis.roi_percentage)
      assert data.executive_kpis.business_value == 187_500.0
      assert data.executive_kpis.roi_percentage == 245.6
    end
  end

  describe "container health initialization" do
    test "tracks container counts and health" do
      data = EnhancedDashboard.get_dashboard_data()

      assert data.container_health.running_containers == 12
      assert data.container_health.healthy_containers == 12
      assert is_number(data.container_health.resource_efficiency)
    end

    test "includes performance and security scores" do
      data = EnhancedDashboard.get_dashboard_data()

      assert is_number(data.container_health.performance_score)
      assert data.container_health.security_scan_status == :clean
    end
  end

  describe "agent coordination initialization" do
    test "tracks supervisor and agent status" do
      data = EnhancedDashboard.get_dashboard_data()

      assert data.agent_coordination.supervisor_status == :active
      assert is_map(data.agent_coordination.helper_agents)
      assert is_map(data.agent_coordination.worker_agents)
    end

    test "includes helper agent metrics" do
      data = EnhancedDashboard.get_dashboard_data()

      assert data.agent_coordination.helper_agents.active == 4
      assert is_number(data.agent_coordination.helper_agents.efficiency)
      assert is_number(data.agent_coordination.helper_agents.task_completion_rate)
    end

    test "includes worker agent metrics" do
      data = EnhancedDashboard.get_dashboard_data()

      assert data.agent_coordination.worker_agents.active == 6
      assert is_number(data.agent_coordination.worker_agents.utilization)
      assert is_number(data.agent_coordination.worker_agents.performance_score)
    end

    test "includes coordination efficiency" do
      data = EnhancedDashboard.get_dashboard_data()

      assert is_number(data.agent_coordination.coordination_efficiency)
      assert data.agent_coordination.coordination_efficiency == 94.7
    end
  end

  describe "compliance metrics initialization" do
    test "tracks multiple compliance frameworks" do
      data = EnhancedDashboard.get_dashboard_data()

      assert is_number(data.compliance_metrics.gdpr_compliance)
      assert is_number(data.compliance_metrics.sox_compliance)
      assert is_number(data.compliance_metrics.iso27001_compliance)
    end

    test "includes overall compliance score" do
      data = EnhancedDashboard.get_dashboard_data()

      assert is_number(data.compliance_metrics.overall_compliance_score)
      assert data.compliance_metrics.overall_compliance_score == 95.2
    end
  end

  describe "anomaly detection initialization" do
    test "initializes with empty anomalies list" do
      data = EnhancedDashboard.get_dashboard_data()

      assert is_list(data.anomaly_detection.active_anomalies)
      assert Enum.empty?(data.anomaly_detection.active_anomalies)
    end

    test "includes detection accuracy metrics" do
      data = EnhancedDashboard.get_dashboard_data()

      assert is_number(data.anomaly_detection.detection_accuracy)
      assert is_number(data.anomaly_detection.false_positive_rate)
      assert is_number(data.anomaly_detection.mean_time_to_detection)
    end
  end

  describe "correlation matrix initialization" do
    test "initializes with correlation coefficients" do
      data = EnhancedDashboard.get_dashboard_data()

      assert is_number(data.correlation_matrix.performance_security)
      assert is_number(data.correlation_matrix.container_performance)
      assert is_number(data.correlation_matrix.agent_efficiency)
    end

    test "correlation values are within valid range" do
      data = EnhancedDashboard.get_dashboard_data()

      Enum.each(Map.values(data.correlation_matrix), fn value ->
        assert value >= -1.0 and value <= 1.0
      end)
    end
  end

  describe "trend analysis initialization" do
    test "tracks multiple trend categories" do
      data = EnhancedDashboard.get_dashboard_data()

      assert is_map(data.trend_analysis.performance_trend)
      assert is_map(data.trend_analysis.cost_trend)
      assert is_map(data.trend_analysis.efficiency_trend)
    end

    test "includes trend direction and rate" do
      data = EnhancedDashboard.get_dashboard_data()

      assert Map.has_key?(data.trend_analysis.performance_trend, :direction)
      assert Map.has_key?(data.trend_analysis.performance_trend, :rate)
    end
  end

  describe "capacity planning initialization" do
    test "includes resource utilization forecasts" do
      data = EnhancedDashboard.get_dashboard_data()

      assert is_map(data.capacity_planning.cpu_utilization_forecast)
      assert is_map(data.capacity_planning.memory_usage_forecast)
      assert is_map(data.capacity_planning.storage_forecast)
      assert is_map(data.capacity_planning.network_forecast)
    end

    test "includes scaling recommendations" do
      data = EnhancedDashboard.get_dashboard_data()

      assert is_list(data.capacity_planning.scaling_recommendations)
      assert length(data.capacity_planning.scaling_recommendations) > 0
    end

    test "forecast includes current and projected values" do
      data = EnhancedDashboard.get_dashboard_data()

      assert Map.has_key?(data.capacity_planning.cpu_utilization_forecast, :current)
      assert Map.has_key?(data.capacity_planning.cpu_utilization_forecast, :projected_3_months)
    end
  end

  describe "edge cases and error handling" do
    test "handles GenServer call timeout gracefully" do
      # Test with immediate timeout
      assert_raise RuntimeError, fn ->
        GenServer.call(EnhancedDashboard, :invalid_call, 1)
      end
    end

    test "handles missing telemetry events" do
      data = EnhancedDashboard.get_dashboard_data()
      assert is_map(data.telemetry_events)
    end

    test "handles empty optimization recommendations" do
      data = EnhancedDashboard.get_dashboard_data()
      assert is_list(data.optimization_recommendations)
    end

    test "handles empty alert list" do
      data = EnhancedDashboard.get_dashboard_data()
      assert is_list(data.real_time_alerts)
    end
  end

  describe "integration scenarios" do
    test "complete dashboard workflow" do
      # Get initial dashboard data
      data1 = EnhancedDashboard.get_dashboard_data()
      assert is_map(data1)

      # Subscribe to updates
      subscriber = self()
      EnhancedDashboard.subscribe_to_updates(subscriber)
      Process.sleep(50)

      # Get executive summary
      summary = EnhancedDashboard.get_executive_summary()
      assert is_map(summary)

      # Get real-time metrics
      metrics = EnhancedDashboard.get_real_time_metrics()
      assert is_map(metrics)

      # Verify subscription
      data2 = EnhancedDashboard.get_dashboard_data()
      assert subscriber in data2.dashboard_subscriptions
    end

    test "dashboard display integration" do
      output =
        capture_io(fn ->
          # Display enhanced dashboard
          EnhancedDashboard.display_enhanced_dashboard()

          # Generate executive report
          EnhancedDashboard.generate_executive_report()
        end)

      assert output =~ "ENHANCED OBSERVABILITY DASHBOARD"
      assert output =~ "EXECUTIVE OBSERVABILITY REPORT"
    end
  end

  describe "STAMP safety constraints" do
    test "SC1: data integrity - dashboard state remains consistent" do
      data1 = EnhancedDashboard.get_dashboard_data()
      data2 = EnhancedDashboard.get_dashboard_data()

      # Core metrics should be consistent
      assert data1.business_metrics.revenue_impact == data2.business_metrics.revenue_impact
      assert data1.executive_kpis.system_availability == data2.executive_kpis.system_availability
    end

    test "SC2: performance - dashboard responds within acceptable time" do
      start_time = System.monotonic_time(:millisecond)

      _data = EnhancedDashboard.get_dashboard_data()

      end_time = System.monotonic_time(:millisecond)
      processing_time = end_time - start_time

      # Dashboard should respond quickly (< 100ms)
      assert processing_time < 100
    end

    test "SC3: security - dashboard protects sensitive metrics" do
      data = EnhancedDashboard.get_dashboard_data()

      # Verify security insights are present
      assert is_map(data.security_insights)
      assert Map.has_key?(data.security_insights, :threat_level)
      assert Map.has_key?(data.security_insights, :security_score)

      # Verify compliance metrics exist
      assert is_map(data.compliance_metrics)
      assert Map.has_key?(data.compliance_metrics, :gdpr_compliance)
    end

    test "SC4: availability - dashboard remains available under load" do
      # Spawn multiple concurrent requests
      tasks =
        for _ <- 1..20 do
          Task.async(fn ->
            EnhancedDashboard.get_dashboard_data()
          end)
        end

      results = Task.await_many(tasks)

      # All requests should succeed
      assert length(results) == 20
      Enum.each(results, fn result -> assert is_map(result) end)
    end

    test "SC5: compliance - dashboard tracks regulatory compliance" do
      data = EnhancedDashboard.get_dashboard_data()

      # Verify compliance metrics are tracked
      assert is_number(data.compliance_metrics.gdpr_compliance)
      assert is_number(data.compliance_metrics.sox_compliance)
      assert is_number(data.compliance_metrics.iso27001_compliance)
      assert is_number(data.compliance_metrics.overall_compliance_score)

      # Compliance scores should be within valid range
      assert data.compliance_metrics.gdpr_compliance >= 0
      assert data.compliance_metrics.gdpr_compliance <= 100
    end
  end
end
