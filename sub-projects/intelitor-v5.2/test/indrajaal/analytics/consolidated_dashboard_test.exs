defmodule Indrajaal.Analytics.ConsolidatedDashboardTest do
  @moduledoc """
  Unit tests for ConsolidatedDashboard module.

  Provides comprehensive unit testing for dashboard consolidation functionality.
  Complements property-based tests with specific scenario validation.

  Agent: Executive Director validates dashboard consolidation via unit testing
  SOPv5.11 Compliance: Cybernetic feedback loops with systematic validation
  TDG Methodology: Tests written before implementation for consolidated dashboard
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Analytics.ConsolidatedDashboard

  @moduletag :unit_test

  describe "get_strategic_metrics/2" do
    test "returns valid strategic metrics structure" do
      tenant_id = "test_tenant_001"

      assert {:ok, metrics} = ConsolidatedDashboard.get_strategic_metrics(tenant_id)

      assert is_map(metrics)
      assert Map.has_key?(metrics, :market_leadership)
      assert Map.has_key?(metrics, :competitive_advantage)
      assert Map.has_key?(metrics, :innovation_index)
      assert Map.has_key?(metrics, :customer_satisfaction)
      assert Map.has_key?(metrics, :financial_performance)
      assert Map.has_key?(metrics, :overall_score)

      # All metrics should be numbers between 0 and 100
      Enum.each(metrics, fn {_key, value} ->
        assert is_number(value)
        assert value >= 0
        assert value <= 100
      end)
    end

    test "handles different timeframe options" do
      tenant_id = "test_tenant_002"

      assert {:ok, current} =
               ConsolidatedDashboard.get_strategic_metrics(tenant_id, timeframe: :current_month)

      assert {:ok, last_month} =
               ConsolidatedDashboard.get_strategic_metrics(tenant_id, timeframe: :last_month)

      # Both should return valid metric structures
      assert is_map(current)
      assert is_map(last_month)
      assert Map.keys(current) == Map.keys(last_month)
    end

    test "overall score is calculated within expected range" do
      tenant_id = "test_tenant_003"

      assert {:ok, metrics} = ConsolidatedDashboard.get_strategic_metrics(tenant_id)

      individual_scores = [
        metrics.market_leadership,
        metrics.competitive_advantage,
        metrics.innovation_index,
        metrics.customer_satisfaction,
        metrics.financial_performance
      ]

      min_score = Enum.min(individual_scores)
      max_score = Enum.max(individual_scores)

      # Overall score should be within the range of individual scores
      assert metrics.overall_score >= min_score - 10
      assert metrics.overall_score <= max_score + 10
    end
  end

  describe "get_dashboard_data/2" do
    test "returns comprehensive dashboard data" do
      tenant_id = "dashboard_test_001"

      assert {:ok, data} = ConsolidatedDashboard.get_dashboard_data(tenant_id)

      assert is_map(data)
      assert Map.has_key?(data, :strategic_metrics)
      assert Map.has_key?(data, :real_time_metrics)
      assert Map.has_key?(data, :business_intelligence)
      assert Map.has_key?(data, :predictive_analytics)
      assert Map.has_key?(data, :compliance_status)
      assert Map.has_key?(data, :generated_at)

      # Verify timestamp is recent
      assert %DateTime{} = data.generated_at
      now = DateTime.utc_now()
      diff_seconds = DateTime.diff(now, data.generated_at, :second)
      assert diff_seconds >= 0
      assert diff_seconds <= 60
    end

    test "all data sections are properly structured" do
      tenant_id = "dashboard_test_002"

      assert {:ok, data} = ConsolidatedDashboard.get_dashboard_data(tenant_id)

      # Strategic metrics
      assert is_map(data.strategic_metrics)
      assert Map.has_key?(data.strategic_metrics, :overall_score)

      # Real-time metrics
      assert is_map(data.real_time_metrics)
      assert Map.has_key?(data.real_time_metrics, :system_performance)

      # Business intelligence
      assert is_map(data.business_intelligence)
      assert Map.has_key?(data.business_intelligence, :revenue_analytics)

      # Predictive analytics
      assert is_map(data.predictive_analytics)
      assert Map.has_key?(data.predictive_analytics, :demand_forecast)

      # Compliance status
      assert is_map(data.compliance_status)
      assert Map.has_key?(data.compliance_status, :gdpr_compliance)
    end

    test "handles options properly" do
      tenant_id = "dashboard_test_003"

      # Test with different options
      assert {:ok, data1} =
               ConsolidatedDashboard.get_dashboard_data(tenant_id, include_predictive: true)

      assert {:ok, data2} =
               ConsolidatedDashboard.get_dashboard_data(tenant_id, include_predictive: false)

      # Both should be valid but may have different real-time metrics
      assert is_map(data1)
      assert is_map(data2)
    end
  end

  describe "get_real_time_metrics/2" do
    test "returns complete real-time metrics structure" do
      tenant_id = "realtime_test_001"

      assert {:ok, metrics} = ConsolidatedDashboard.get_real_time_metrics(tenant_id)

      assert is_map(metrics)
      assert Map.has_key?(metrics, :system_performance)
      assert Map.has_key?(metrics, :operational_kpis)
      assert Map.has_key?(metrics, :alert_summary)
      assert Map.has_key?(metrics, :user_activity)
      assert Map.has_key?(metrics, :resource_utilization)
    end

    test "includes predictive trends when requested" do
      tenant_id = "realtime_test_002"

      assert {:ok, with_predictive} =
               ConsolidatedDashboard.get_real_time_metrics(tenant_id, include_predictive: true)

      assert {:ok, without_predictive} =
               ConsolidatedDashboard.get_real_time_metrics(tenant_id, include_predictive: false)

      assert Map.has_key?(with_predictive, :predictive_trends)
      refute Map.has_key?(without_predictive, :predictive_trends)
    end

    test "system performance metrics have expected structure" do
      tenant_id = "realtime_test_003"

      assert {:ok, metrics} = ConsolidatedDashboard.get_real_time_metrics(tenant_id)

      perf = metrics.system_performance
      assert is_map(perf)
      assert Map.has_key?(perf, :cpu_usage)
      assert Map.has_key?(perf, :memory_usage)
      assert Map.has_key?(perf, :disk_usage)
      assert Map.has_key?(perf, :network_latency)

      # All performance metrics should be numbers
      Enum.each(perf, fn {_key, value} ->
        assert is_number(value)
        assert value >= 0
      end)
    end
  end

  describe "get_business_intelligence_data/2" do
    test "returns comprehensive business intelligence structure" do
      tenant_id = "bi_test_001"

      assert {:ok, bi_data} = ConsolidatedDashboard.get_business_intelligence_data(tenant_id)

      assert is_map(bi_data)
      assert Map.has_key?(bi_data, :revenue_analytics)
      assert Map.has_key?(bi_data, :customer_analytics)
      assert Map.has_key?(bi_data, :operational_analytics)
      assert Map.has_key?(bi_data, :market_trends)
      assert Map.has_key?(bi_data, :competitive_insights)
    end

    test "market trends include expected metrics" do
      tenant_id = "bi_test_002"

      assert {:ok, bi_data} = ConsolidatedDashboard.get_business_intelligence_data(tenant_id)

      trends = bi_data.market_trends
      assert is_map(trends)
      assert Map.has_key?(trends, :market_growth)
      assert Map.has_key?(trends, :market_share)
      assert Map.has_key?(trends, :competitive_position)

      assert is_number(trends.market_growth)
      assert is_number(trends.market_share)
      assert trends.competitive_position in [:leader, :challenger, :follower, :niche]
    end
  end

  describe "get_predictive_analytics_data/2" do
    test "returns predictive analytics with forecasting data" do
      tenant_id = "predictive_test_001"

      assert {:ok, predictive} = ConsolidatedDashboard.get_predictive_analytics_data(tenant_id)

      assert is_map(predictive)
      assert Map.has_key?(predictive, :demand_forecast)
      assert Map.has_key?(predictive, :revenue_forecast)
      assert Map.has_key?(predictive, :risk_analysis)
      assert Map.has_key?(predictive, :optimization_recommendations)
      assert Map.has_key?(predictive, :scenario_analysis)
    end

    test "scenario analysis includes required scenarios" do
      tenant_id = "predictive_test_002"

      assert {:ok, predictive} = ConsolidatedDashboard.get_predictive_analytics_data(tenant_id)

      scenarios = predictive.scenario_analysis
      assert is_map(scenarios)
      assert Map.has_key?(scenarios, :best_case)
      assert Map.has_key?(scenarios, :worst_case)
      assert Map.has_key?(scenarios, :most_likely)

      # Each scenario should have growth/decline and confidence
      Enum.each(scenarios, fn {_scenario, data} ->
        assert is_map(data)
        assert Map.has_key?(data, :confidence)
        assert is_number(data.confidence)
        assert data.confidence >= 0 and data.confidence <= 1
      end)
    end

    test "optimization recommendations are actionable" do
      tenant_id = "predictive_test_003"

      assert {:ok, predictive} = ConsolidatedDashboard.get_predictive_analytics_data(tenant_id)

      recommendations = predictive.optimization_recommendations
      assert is_list(recommendations)
      assert length(recommendations) > 0

      # All recommendations should be strings
      Enum.each(recommendations, fn recommendation ->
        assert is_binary(recommendation)
        assert String.length(recommendation) > 10
      end)
    end
  end

  describe "get_compliance_status/2" do
    test "returns complete compliance metrics" do
      tenant_id = "compliance_test_001"

      assert {:ok, compliance} = ConsolidatedDashboard.get_compliance_status(tenant_id)

      assert is_map(compliance)
      assert Map.has_key?(compliance, :gdpr_compliance)
      assert Map.has_key?(compliance, :sox_compliance)
      assert Map.has_key?(compliance, :iso27001_status)
      assert Map.has_key?(compliance, :audit_readiness)
      assert Map.has_key?(compliance, :security_score)
      assert Map.has_key?(compliance, :data_protection_score)
    end

    test "compliance scores are within valid ranges" do
      tenant_id = "compliance_test_002"

      assert {:ok, compliance} = ConsolidatedDashboard.get_compliance_status(tenant_id)

      score_fields = [
        :gdpr_compliance,
        :sox_compliance,
        :audit_readiness,
        :security_score,
        :data_protection_score
      ]

      Enum.each(score_fields, fn field ->
        score = Map.get(compliance, field)
        assert is_number(score)
        assert score >= 0 and score <= 100
      end)

      # ISO27001 status should be an atom
      assert compliance.iso27001_status in [:compliant, :non_compliant, :pending]
    end
  end

  describe "create_dashboard/2" do
    test "creates dashboard with valid configuration" do
      tenant_id = "create_test_001"

      dashboard_config = %{
        tenant_id: tenant_id,
        dashboard_type: :operational,
        widgets: [],
        refresh_interval: 30_000,
        permissions: ["read", "write"]
      }

      assert {:ok, created} = ConsolidatedDashboard.create_dashboard(tenant_id, dashboard_config)

      assert is_map(created)
      assert created.tenant_id == tenant_id
      assert created.dashboard_type == :operational
      assert created.refresh_interval == 30_000
      assert Map.has_key?(created, :id)
    end

    test "validates dashboard configuration" do
      tenant_id = "create_test_002"

      # Invalid configuration - missing required fields
      invalid_config = %{
        tenant_id: tenant_id
        # Missing dashboard_type, widgets, etc.
      }

      assert {:error, :invalid_dashboard_config} =
               ConsolidatedDashboard.create_dashboard(tenant_id, invalid_config)
    end

    test "creates dashboard with multiple widgets" do
      tenant_id = "create_test_003"

      widgets = [
        %{
          widget_id: "widget_1",
          widget_type: :kpi_metric,
          title: "KPI Widget",
          data_source: "source_1",
          config: %{},
          position: %{x: 0, y: 0, width: 4, height: 2}
        },
        %{
          widget_id: "widget_2",
          widget_type: :time_series_chart,
          title: "Chart Widget",
          data_source: "source_2",
          config: %{},
          position: %{x: 4, y: 0, width: 8, height: 4}
        }
      ]

      dashboard_config = %{
        tenant_id: tenant_id,
        dashboard_type: :business_intelligence,
        widgets: widgets,
        refresh_interval: 60_000,
        permissions: ["read"]
      }

      assert {:ok, created} = ConsolidatedDashboard.create_dashboard(tenant_id, dashboard_config)
      assert length(created.widgets) == 2
    end
  end

  describe "create_widget/2" do
    test "creates widget with valid configuration" do
      tenant_id = "widget_test_001"

      widget_config = %{
        widget_id: "test_widget",
        widget_type: :kpi_metric,
        title: "Test Widget",
        data_source: "test_source",
        config: %{threshold: 95.0},
        position: %{x: 0, y: 0, width: 4, height: 2}
      }

      assert {:ok, created} = ConsolidatedDashboard.create_widget(tenant_id, widget_config)

      assert is_map(created)
      assert created.widget_id == "test_widget"
      assert created.widget_type == :kpi_metric
      assert created.title == "Test Widget"
      assert Map.has_key?(created, :id)
    end

    test "validates widget configuration" do
      tenant_id = "widget_test_002"

      # Invalid widget type
      invalid_config = %{
        widget_id: "invalid_widget",
        widget_type: :invalid_type,
        title: "Invalid Widget",
        data_source: "source",
        config: %{},
        position: %{x: 0, y: 0, width: 4, height: 2}
      }

      assert {:error, :invalid_widget_config} =
               ConsolidatedDashboard.create_widget(tenant_id, invalid_config)
    end

    test "supports all widget types" do
      tenant_id = "widget_test_003"

      widget_types = [
        :kpi_metric,
        :time_series_chart,
        :real_time_gauge,
        :trend_analysis,
        :predictive_forecast,
        :compliance_status,
        :business_intelligence,
        :performance_metric
      ]

      Enum.each(widget_types, fn widget_type ->
        widget_config = %{
          widget_id: "widget_#{widget_type}",
          widget_type: widget_type,
          title: "#{widget_type} Widget",
          data_source: "source_#{widget_type}",
          config: %{},
          position: %{x: 0, y: 0, width: 4, height: 2}
        }

        assert {:ok, created} = ConsolidatedDashboard.create_widget(tenant_id, widget_config)
        assert created.widget_type == widget_type
      end)
    end
  end

  describe "edge cases and error handling" do
    test "handles empty tenant ID gracefully" do
      assert {:ok, _metrics} = ConsolidatedDashboard.get_strategic_metrics("")
      assert {:ok, _data} = ConsolidatedDashboard.get_dashboard_data("")
    end

    test "handles very long tenant IDs" do
      long_tenant_id = String.duplicate("a", 1000)

      assert {:ok, _metrics} = ConsolidatedDashboard.get_strategic_metrics(long_tenant_id)
      assert {:ok, _data} = ConsolidatedDashboard.get_dashboard_data(long_tenant_id)
    end

    test "handles special characters in tenant IDs" do
      special_tenant_id = "tenant-with_special.chars@domain.com"

      assert {:ok, _metrics} = ConsolidatedDashboard.get_strategic_metrics(special_tenant_id)
      assert {:ok, _data} = ConsolidatedDashboard.get_dashboard_data(special_tenant_id)
    end

    test "widget creation with edge case positions" do
      tenant_id = "edge_case_test"

      # Widget at maximum grid position
      max_position_config = %{
        widget_id: "max_position_widget",
        widget_type: :kpi_metric,
        title: "Max Position",
        data_source: "source",
        config: %{},
        position: %{x: 8, y: 6, width: 4, height: 2}
      }

      assert {:ok, _created} = ConsolidatedDashboard.create_widget(tenant_id, max_position_config)

      # Widget with minimum size
      min_size_config = %{
        widget_id: "min_size_widget",
        widget_type: :real_time_gauge,
        title: "Min Size",
        data_source: "source",
        config: %{},
        position: %{x: 0, y: 0, width: 1, height: 1}
      }

      assert {:ok, _created} = ConsolidatedDashboard.create_widget(tenant_id, min_size_config)
    end
  end

  describe "performance and memory tests" do
    test "dashboard data retrieval completes within reasonable time" do
      tenant_id = "performance_test_001"

      start_time = System.monotonic_time(:millisecond)
      assert {:ok, _data} = ConsolidatedDashboard.get_dashboard_data(tenant_id)
      end_time = System.monotonic_time(:millisecond)

      duration = end_time - start_time
      # Should complete within 1 second
      assert duration < 1000
    end

    test "multiple concurrent dashboard requests" do
      tenant_ids = for i <- 1..10, do: "concurrent_test_#{i}"

      tasks =
        Enum.map(tenant_ids, fn tenant_id ->
          Task.async(fn ->
            ConsolidatedDashboard.get_dashboard_data(tenant_id)
          end)
        end)

      results = Task.await_many(tasks, 5000)

      # All requests should succeed
      Enum.each(results, fn result ->
        assert {:ok, _data} = result
      end)
    end

    test "memory usage remains stable across operations" do
      tenant_id = "memory_test_001"

      initial_memory = :erlang.memory(:total)

      # Perform multiple operations
      for _i <- 1..100 do
        {:ok, _} = ConsolidatedDashboard.get_strategic_metrics(tenant_id)
        {:ok, _} = ConsolidatedDashboard.get_real_time_metrics(tenant_id)
      end

      # Force garbage collection
      :erlang.garbage_collect()
      final_memory = :erlang.memory(:total)

      # Memory increase should be minimal
      memory_increase = final_memory - initial_memory
      # Less than 5MB increase
      assert memory_increase < 5_000_000
    end
  end
end
