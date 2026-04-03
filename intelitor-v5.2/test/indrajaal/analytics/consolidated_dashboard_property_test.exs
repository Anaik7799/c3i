defmodule Indrajaal.Analytics.ConsolidatedDashboardPropertyTest do
  @moduledoc """
  Property-based tests for ConsolidatedDashboard module.

  Tests dashboard consolidation functionality using dual property testing approach:
  - PropCheck: Advanced property testing with sophisticated shrinking
  - ExUnitProperties: StreamData-based property testing

  Agent: Executive Director validates dashboard consolidation via property testing
  SOPv5.11 Compliance: Cybernetic feedback loops with comprehensive validation
  TDG Methodology: Tests written before implementation for consolidated dashboard
  """

  use ExUnit.Case, async: true
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  # EP-GEN-014: Import ExUnitProperties with except clause to avoid conflicts
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # Disambiguation aliases per EP-GEN-014 pattern
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Analytics.ConsolidatedDashboard

  @moduletag :property_test

  # PropCheck generators for dashboard testing
  def tenant_id_gen do
    let id <- non_empty(PC.binary()) do
      "tenant_#{id}"
    end
  end

  def widget_type_gen do
    PC.oneof([
      :kpi_metric,
      :time_series_chart,
      :real_time_gauge,
      :trend_analysis,
      :predictive_forecast,
      :compliance_status,
      :business_intelligence,
      :performance_metric
    ])
  end

  def widget_config_gen do
    let {id, type, title, x, y, width, height} <- {
          non_empty(PC.binary()),
          widget_type_gen(),
          non_empty(PC.binary()),
          pos_integer(),
          pos_integer(),
          range(1, 12),
          range(1, 8)
        } do
      %{
        widget_id: "widget_#{id}",
        widget_type: type,
        title: title,
        data_source: "source_#{id}",
        config: %{},
        position: %{x: x, y: y, width: width, height: height}
      }
    end
  end

  def dashboard_config_gen do
    let {tenant_id, dashboard_type, widgets, refresh_interval} <- {
          tenant_id_gen(),
          PC.oneof([:strategic, :operational, :business_intelligence, :compliance]),
          PC.list(widget_config_gen()),
          range(1000, 300_000)
        } do
      %{
        tenant_id: tenant_id,
        dashboard_type: dashboard_type,
        widgets: widgets,
        refresh_interval: refresh_interval,
        permissions: ["read", "write"]
      }
    end
  end

  # PropCheck property tests with advanced shrinking
  describe "PropCheck property tests" do
    property "strategic metrics always return valid percentages", [:verbose] do
      forall tenant_id <- tenant_id_gen() do
        result =
          case ConsolidatedDashboard.get_strategic_metrics(tenant_id) do
            {:ok, metrics} ->
              validate_strategic_metrics_structure(metrics) and
                validate_percentage_ranges(metrics) and
                validate_overall_score_calculation(metrics)

            {:error, _reason} ->
              # Error cases are acceptable for invalid tenant IDs
              true
          end

        classify(
          String.length(tenant_id) > 10,
          :long_tenant_id,
          classify(String.length(tenant_id) <= 10, :short_tenant_id, result)
        )
      end
    end

    property "dashboard data retrieval is consistent and complete", [:verbose] do
      forall tenant_id <- tenant_id_gen() do
        case ConsolidatedDashboard.get_dashboard_data(tenant_id) do
          {:ok, data} ->
            validate_dashboard_data_structure(data) and
              validate_data_consistency(data) and
              validate_timestamp_recency(data)

          {:error, _reason} ->
            true
        end
      end
    end

    property "widget configurations are properly validated", [:verbose] do
      forall widget_config <- widget_config_gen() do
        case ConsolidatedDashboard.create_widget("test_tenant", widget_config) do
          {:ok, created_widget} ->
            validate_widget_creation(widget_config, created_widget)

          {:error, reason} ->
            # Validation errors are acceptable for invalid configurations
            is_atom(reason)
        end
      end
    end

    property "dashboard creation handles various configurations", [:verbose] do
      forall dashboard_config <- dashboard_config_gen() do
        tenant_id = dashboard_config.tenant_id

        case ConsolidatedDashboard.create_dashboard(tenant_id, dashboard_config) do
          {:ok, created_dashboard} ->
            validate_dashboard_creation(dashboard_config, created_dashboard)

          {:error, reason} ->
            is_atom(reason)
        end
      end
    end
  end

  # ExUnitProperties tests with StreamData
  describe "ExUnitProperties tests" do
    test "real-time metrics maintain data integrity" do
      ExUnitProperties.check all(
                               tenant_id <- SD.string(:alphanumeric, min_length: 5),
                               include_predictive <- SD.boolean(),
                               max_runs: 100
                             ) do
        opts = [include_predictive: include_predictive]

        case ConsolidatedDashboard.get_real_time_metrics(tenant_id, opts) do
          {:ok, metrics} ->
            assert is_map(metrics)
            assert Map.has_key?(metrics, :system_performance)
            assert Map.has_key?(metrics, :operational_kpis)

            if include_predictive do
              assert Map.has_key?(metrics, :predictive_trends)
            end

            validate_real_time_metrics_structure(metrics)

          {:error, _reason} ->
            :ok
        end
      end
    end

    test "business intelligence data follows expected patterns" do
      ExUnitProperties.check all(
                               tenant_id <- SD.string(:alphanumeric, min_length: 3),
                               max_runs: 50
                             ) do
        case ConsolidatedDashboard.get_business_intelligence_data(tenant_id) do
          {:ok, bi_data} ->
            assert is_map(bi_data)
            assert Map.has_key?(bi_data, :revenue_analytics)
            assert Map.has_key?(bi_data, :customer_analytics)
            assert Map.has_key?(bi_data, :operational_analytics)

            validate_business_intelligence_structure(bi_data)

          {:error, _reason} ->
            :ok
        end
      end
    end

    test "compliance status provides complete coverage" do
      ExUnitProperties.check all(
                               tenant_id <- SD.string(:alphanumeric, min_length: 4),
                               max_runs: 75
                             ) do
        case ConsolidatedDashboard.get_compliance_status(tenant_id) do
          {:ok, compliance} ->
            assert is_map(compliance)

            required_keys = [
              :gdpr_compliance,
              :sox_compliance,
              :iso27001_status,
              :audit_readiness,
              :security_score,
              :data_protection_score
            ]

            Enum.each(required_keys, fn key ->
              assert Map.has_key?(compliance, key)
            end)

            validate_compliance_scores(compliance)

          {:error, _reason} ->
            :ok
        end
      end
    end

    test "widget positions are within valid grid bounds" do
      ExUnitProperties.check all(
                               widget <-
                                 SD.fixed_map(%{
                                   widget_id: SD.string(:alphanumeric, min_length: 1),
                                   widget_type:
                                     SD.member_of([
                                       :kpi_metric,
                                       :time_series_chart,
                                       :real_time_gauge
                                     ]),
                                   title: SD.string(:printable, min_length: 1),
                                   data_source: SD.string(:alphanumeric, min_length: 1),
                                   config: SD.map_of(SD.atom(:alphanumeric), SD.term()),
                                   position:
                                     SD.fixed_map(%{
                                       x: SD.integer(0..11),
                                       y: SD.integer(0..7),
                                       width: SD.integer(1..12),
                                       height: SD.integer(1..8)
                                     })
                                 }),
                               max_runs: 200
                             ) do
        # Validate widget position constraints
        position = widget.position
        assert position.x >= 0 and position.x <= 11
        assert position.y >= 0 and position.y <= 7
        assert position.width >= 1 and position.width <= 12
        assert position.height >= 1 and position.height <= 8

        # Validate that widget doesn't exceed grid bounds
        assert position.x + position.width <= 12
        assert position.y + position.height <= 8
      end
    end

    test "dashboard refresh intervals are within acceptable ranges" do
      ExUnitProperties.check all(
                               refresh_interval <- SD.integer(1000..300_000),
                               max_runs: 100
                             ) do
        # Validate refresh interval constraints
        # Minimum 1 second
        assert refresh_interval >= 1000
        # Maximum 5 minutes
        assert refresh_interval <= 300_000

        # Test with dashboard config
        dashboard_config = %{
          tenant_id: "test_tenant",
          dashboard_type: :operational,
          widgets: [],
          refresh_interval: refresh_interval,
          permissions: ["read"]
        }

        case ConsolidatedDashboard.create_dashboard("test_tenant", dashboard_config) do
          {:ok, created} ->
            assert created.refresh_interval == refresh_interval

          {:error, _reason} ->
            :ok
        end
      end
    end
  end

  # Validation helper functions
  defp validate_strategic_metrics_structure(metrics) do
    required_keys = [
      :market_leadership,
      :competitive_advantage,
      :innovation_index,
      :customer_satisfaction,
      :financial_performance,
      :overall_score
    ]

    Enum.all?(required_keys, &Map.has_key?(metrics, &1))
  end

  defp validate_percentage_ranges(metrics) do
    percentage_fields = [
      :market_leadership,
      :competitive_advantage,
      :innovation_index,
      :customer_satisfaction,
      :financial_performance,
      :overall_score
    ]

    Enum.all?(percentage_fields, fn field ->
      value = Map.get(metrics, field, 0)
      is_number(value) and value >= 0 and value <= 100
    end)
  end

  defp validate_overall_score_calculation(metrics) do
    # Overall score should be within reasonable range of individual metrics
    individual_scores = [
      metrics.market_leadership,
      metrics.competitive_advantage,
      metrics.innovation_index,
      metrics.customer_satisfaction,
      metrics.financial_performance
    ]

    avg_score = Enum.sum(individual_scores) / length(individual_scores)
    overall_score = metrics.overall_score

    # Overall score should be within 20 points of average (weighted calculation)
    abs(overall_score - avg_score) <= 20
  end

  defp validate_dashboard_data_structure(data) do
    required_keys = [
      :strategic_metrics,
      :real_time_metrics,
      :business_intelligence,
      :predictive_analytics,
      :compliance_status,
      :generated_at
    ]

    Enum.all?(required_keys, &Map.has_key?(data, &1)) and
      match?(%DateTime{}, data.generated_at)
  end

  defp validate_data_consistency(data) do
    # All main sections should be maps
    is_map(data.strategic_metrics) and
      is_map(data.real_time_metrics) and
      is_map(data.business_intelligence) and
      is_map(data.predictive_analytics) and
      is_map(data.compliance_status)
  end

  defp validate_timestamp_recency(data) do
    # Generated timestamp should be recent (within last minute)
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, data.generated_at, :second)
    diff_seconds >= 0 and diff_seconds <= 60
  end

  defp validate_widget_creation(original_config, created_widget) do
    created_widget.widget_id == original_config.widget_id and
      created_widget.widget_type == original_config.widget_type and
      created_widget.title == original_config.title and
      Map.has_key?(created_widget, :id)
  end

  defp validate_dashboard_creation(original_config, created_dashboard) do
    created_dashboard.tenant_id == original_config.tenant_id and
      created_dashboard.dashboard_type == original_config.dashboard_type and
      length(created_dashboard.widgets) == length(original_config.widgets) and
      Map.has_key?(created_dashboard, :id)
  end

  defp validate_real_time_metrics_structure(metrics) do
    required_keys = [
      :system_performance,
      :operational_kpis,
      :alert_summary,
      :user_activity,
      :resource_utilization
    ]

    Enum.all?(required_keys, &Map.has_key?(metrics, &1))
  end

  defp validate_business_intelligence_structure(bi_data) do
    required_keys = [
      :revenue_analytics,
      :customer_analytics,
      :operational_analytics,
      :market_trends,
      :competitive_insights
    ]

    Enum.all?(required_keys, &Map.has_key?(bi_data, &1))
  end

  defp validate_compliance_scores(compliance) do
    score_fields = [
      :gdpr_compliance,
      :sox_compliance,
      :audit_readiness,
      :security_score,
      :data_protection_score
    ]

    Enum.all?(score_fields, fn field ->
      case Map.get(compliance, field) do
        score when is_number(score) -> score >= 0 and score <= 100
        _ -> false
      end
    end) and
      compliance.iso27001_status in [:compliant, :non_compliant, :pending]
  end

  # Integration tests for dashboard consolidation
  describe "Dashboard consolidation integration" do
    test "consolidated dashboard provides same functionality as original GenServers" do
      tenant_id = "integration_test_tenant"

      # Test strategic metrics functionality
      assert {:ok, strategic} = ConsolidatedDashboard.get_strategic_metrics(tenant_id)
      assert validate_strategic_metrics_structure(strategic)

      # Test real-time metrics functionality
      assert {:ok, real_time} = ConsolidatedDashboard.get_real_time_metrics(tenant_id)
      assert validate_real_time_metrics_structure(real_time)

      # Test business intelligence functionality
      assert {:ok, bi_data} = ConsolidatedDashboard.get_business_intelligence_data(tenant_id)
      assert validate_business_intelligence_structure(bi_data)

      # Test comprehensive dashboard data
      assert {:ok, dashboard_data} = ConsolidatedDashboard.get_dashboard_data(tenant_id)
      assert validate_dashboard_data_structure(dashboard_data)
    end

    test "widget creation and configuration management" do
      tenant_id = "widget_test_tenant"

      widget_config = %{
        widget_id: "test_widget_001",
        widget_type: :kpi_metric,
        title: "Test KPI Widget",
        data_source: "test_source",
        config: %{threshold: 95.0},
        position: %{x: 0, y: 0, width: 4, height: 2}
      }

      assert {:ok, created_widget} = ConsolidatedDashboard.create_widget(tenant_id, widget_config)
      assert validate_widget_creation(widget_config, created_widget)
    end

    test "dashboard configuration with multiple widgets" do
      tenant_id = "dashboard_test_tenant"

      widgets = [
        %{
          widget_id: "widget_1",
          widget_type: :kpi_metric,
          title: "Performance KPI",
          data_source: "performance_source",
          config: %{},
          position: %{x: 0, y: 0, width: 6, height: 3}
        },
        %{
          widget_id: "widget_2",
          widget_type: :time_series_chart,
          title: "Trend Analysis",
          data_source: "trend_source",
          config: %{},
          position: %{x: 6, y: 0, width: 6, height: 3}
        }
      ]

      dashboard_config = %{
        tenant_id: tenant_id,
        dashboard_type: :operational,
        widgets: widgets,
        refresh_interval: 30_000,
        permissions: ["read", "write"]
      }

      assert {:ok, created_dashboard} =
               ConsolidatedDashboard.create_dashboard(tenant_id, dashboard_config)

      assert validate_dashboard_creation(dashboard_config, created_dashboard)
    end
  end

  # Performance property tests
  describe "Performance property tests" do
    property "dashboard data retrieval scales with tenant complexity", [:verbose] do
      forall {tenant_id, widget_count} <- {tenant_id_gen(), PC.range(1, 20)} do
        start_time = System.monotonic_time(:millisecond)

        case ConsolidatedDashboard.get_dashboard_data(tenant_id) do
          {:ok, _data} ->
            end_time = System.monotonic_time(:millisecond)
            duration = end_time - start_time

            # Dashboard data retrieval should complete within reasonable time
            # Allowing more time for larger widget counts
            max_duration = 1000 + widget_count * 10
            duration <= max_duration

          {:error, _reason} ->
            true
        end
      end
    end

    property "memory usage remains bounded during dashboard operations" do
      forall operations <-
               PC.list(
                 PC.oneof([
                   {:get_dashboard_data, tenant_id_gen()},
                   {:get_strategic_metrics, tenant_id_gen()},
                   {:get_real_time_metrics, tenant_id_gen()},
                   {:create_widget, tenant_id_gen(), widget_config_gen()}
                 ])
               ) do
        initial_memory = :erlang.memory(:total)

        # Execute operations
        Enum.each(operations, fn
          {:get_dashboard_data, tenant_id} ->
            ConsolidatedDashboard.get_dashboard_data(tenant_id)

          {:get_strategic_metrics, tenant_id} ->
            ConsolidatedDashboard.get_strategic_metrics(tenant_id)

          {:get_real_time_metrics, tenant_id} ->
            ConsolidatedDashboard.get_real_time_metrics(tenant_id)

          {:create_widget, tenant_id, widget_config} ->
            ConsolidatedDashboard.create_widget(tenant_id, widget_config)
        end)

        # Force garbage collection
        :erlang.garbage_collect()
        final_memory = :erlang.memory(:total)

        # Memory increase should be reasonable (less than 10MB for test operations)
        memory_increase = final_memory - initial_memory
        memory_increase < 10_000_000
      end
    end
  end
end
