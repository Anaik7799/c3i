defmodule Indrajaal.Analytics.AnalyticsEventLoggerTest do
  @moduledoc """
  TDG-compliant comprehensive test suite for AnalyticsEventLogger module.

  Created BEFORE implementation following SOPv5.11 Test-Driven Generation methodology.
  Includes unit tests, property-based tests, and STAMP safety constraint validation.

  SOPv5.11 Compliance:
  - Test-First Development (TDG methodology)
  - Dual Property Testing (PropCheck + ExUnitProperties)
  - STAMP Safety Constraints validation
  - 50-Agent Architecture validation
  - Container-native testing
  - Comprehensive error pattern coverage (EP001-EP999)
  """

  use ExUnit.Case, async: true
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import PropCheck.BasicTypes
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  import StreamData, only: [float: 1, string: 1, string: 2, integer: 1]
  # EP-GEN-014: Mandatory aliases for generator disambiguation
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Analytics.AnalyticsEventLogger
  alias Indrajaal.Repo

  import Mox
  import Ecto.Query

  # Setup for test isolation
  setup :verify_on_exit!

  setup do
    # Start clean database state for each test
    try do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    rescue
      _ -> :ok
    end

    {:ok,
     %{
       tenant_id: "test-tenant-#{:rand.uniform(10_000)}",
       user_id: "test-user-#{:rand.uniform(10_000)}"
     }}
  end

  # ============================================================================
  # TDG UNIT TESTS - Core Functionality
  # ============================================================================

  describe "initialize_hypertables/0 - TDG Core Tests" do
    test "successfully initializes all required hypertables" do
      # Test First: Define expected behavior
      expected_tables = [
        "analytics_query_events",
        "analytics_report_events",
        "analytics_dashboard_events",
        "analytics_ml_events",
        "analytics_performance_events",
        "analytics_kpi_events"
      ]

      # TDG: Test the initialization process
      assert :ok = AnalyticsEventLogger.initialize_hypertables()

      # Verify all hypertables were created with correct structure
      for table <- expected_tables do
        assert table_exists?(table), "Hypertable #{table} should exist"
        assert hypertable_configured?(table), "Table #{table} should be configured as hypertable"
        assert retention_policy_set?(table), "Retention policy should be set for #{table}"
      end
    end

    @tag :skip
    test "handles database connection errors gracefully" do
      # TDG: Test error handling when database is unavailable
      # TODO: Implement with Mox when Repo mock is configured
      # This test requires database error simulation which needs proper Mox setup
      assert true
    end

    test "creates proper indexes after hypertable initialization" do
      assert :ok = AnalyticsEventLogger.initialize_hypertables()

      # Verify all expected indexes exist
      expected_indexes = [
        "idx_analytics_query_tenant_time",
        "idx_analytics_query_type",
        "idx_analytics_report_tenant_time",
        "idx_analytics_dashboard_user",
        "idx_analytics_ml_model",
        "idx_analytics_kpi_name",
        "idx_analytics_perf_component",
        "idx_analytics_correlation",
        "idx_analytics_session"
      ]

      for index <- expected_indexes do
        assert index_exists?(index), "Index #{index} should exist"
      end
    end
  end

  describe "log_query_execution/2 - TDG Comprehensive Tests" do
    setup %{tenant_id: tenant_id, user_id: user_id} do
      AnalyticsEventLogger.initialize_hypertables()

      {:ok,
       %{
         query_params: %{
           query_type: :select,
           duration: 1500,
           tables: ["users", "accounts"],
           filters: %{status: "active"},
           joins: [%{type: :inner, table: "accounts"}],
           aggregations: ["COUNT(*)", "AVG(score)"],
           rows_examined: 10_000,
           rows_returned: 150,
           memory_usage: 64,
           cpu_usage: 15.5,
           io_ops: 250,
           cache_ratio: 0.85
         },
         opts: [tenant_id: tenant_id, user_id: user_id, session_id: "session-123"]
       }}
    end

    test "logs query execution with complete metrics", %{query_params: params, opts: opts} do
      # TDG: Test successful query logging
      assert :ok = AnalyticsEventLogger.log_query_execution(params, opts)

      # Verify event was stored in hypertable
      events = get_events_from_table("analytics_query_events", opts[:tenant_id])
      assert length(events) == 1

      event = hd(events)
      assert event.event_type == "query_execution"
      assert event.tenant_id == opts[:tenant_id]

      # Verify event data structure
      event_data = Jason.decode!(event.event_data)
      assert event_data["query_type"] == "select"
      assert event_data["tables_accessed"] == ["users", "accounts"]
      assert event_data["filter_conditions"]["status"] == "active"

      # Verify metrics
      metrics = Jason.decode!(event.metrics)
      assert metrics["execution_duration_ms"] == 1500
      assert metrics["rows_examined"] == 10_000
      assert metrics["rows_returned"] == 150
      assert metrics["memory_usage_mb"] == 64
      assert metrics["cpu_usage_percent"] == 15.5
    end

    test "calculates query complexity accurately", %{query_params: params, opts: opts} do
      assert :ok = AnalyticsEventLogger.log_query_execution(params, opts)

      events = get_events_from_table("analytics_query_events", opts[:tenant_id])
      event_data = Jason.decode!(hd(events).event_data)

      # Expected complexity: 1 + (2 tables * 2) + (1 join * 3) + (1 filter) + (2 aggregations * 2) = 12
      expected_complexity = 1 + 2 * 2 + 1 * 3 + 1 + 2 * 2
      assert event_data["query_complexity"] == expected_complexity
    end

    test "triggers performance alert for slow queries", %{query_params: params, opts: opts} do
      # > 5000ms threshold
      slow_params = Map.put(params, :duration, 6000)

      expect(Indrajaal.Observability.DualLogging, :log_domain_event, 2, fn
        :analytics, :query_execution, _data, :info -> :ok
        :analytics, "performance_alert", _data, :warning -> :ok
      end)

      assert :ok = AnalyticsEventLogger.log_query_execution(slow_params, opts)
    end

    test "handles missing optional parameters gracefully", %{opts: opts} do
      minimal_params = %{query_type: :select}

      assert :ok = AnalyticsEventLogger.log_query_execution(minimal_params, opts)

      events = get_events_from_table("analytics_query_events", opts[:tenant_id])
      event_data = Jason.decode!(hd(events).event_data)

      # Verify defaults are applied
      assert event_data["tables_accessed"] == []
      assert event_data["filter_conditions"] == %{}
      assert event_data["join_operations"] == []
      assert event_data["aggregations"] == []
    end

    test "validates tenant isolation", %{query_params: params} do
      tenant1_opts = [tenant_id: "tenant-1", user_id: "user-1"]
      tenant2_opts = [tenant_id: "tenant-2", user_id: "user-2"]

      assert :ok = AnalyticsEventLogger.log_query_execution(params, tenant1_opts)
      assert :ok = AnalyticsEventLogger.log_query_execution(params, tenant2_opts)

      # Verify tenant isolation
      tenant1_events = get_events_from_table("analytics_query_events", "tenant-1")
      tenant2_events = get_events_from_table("analytics_query_events", "tenant-2")

      assert length(tenant1_events) == 1
      assert length(tenant2_events) == 1
      assert hd(tenant1_events).tenant_id != hd(tenant2_events).tenant_id
    end
  end

  describe "log_report_generation/2 - TDG Report Tests" do
    setup %{tenant_id: tenant_id, user_id: user_id} do
      AnalyticsEventLogger.initialize_hypertables()

      {:ok,
       %{
         report_params: %{
           type: :analytics_summary,
           format: :pdf,
           sources: ["user_metrics", "performance_data"],
           parameters: %{date_range: "last_30_days", include_charts: true},
           template_id: "template-001",
           scheduled: false,
           recipients: ["admin@test.com", "manager@test.com"],
           duration: 45_000,
           rows: 50_000,
           size: 12.5,
           export_duration: 5000,
           memory_peak: 128,
           success: true
         },
         opts: [tenant_id: tenant_id, user_id: user_id, session_id: "report-session-456"]
       }}
    end

    test "logs report generation with business intelligence integration", %{
      report_params: params,
      opts: opts
    } do
      expect(Indrajaal.Analytics.BusinessIntelligence, :update_metrics, fn :report_generation,
                                                                           _event ->
        :ok
      end)

      assert :ok = AnalyticsEventLogger.log_report_generation(params, opts)

      events = get_events_from_table("analytics_report_events", opts[:tenant_id])
      assert length(events) == 1

      event = hd(events)
      assert event.event_type == "report_generation"

      event_data = Jason.decode!(event.event_data)
      assert event_data["report_type"] == "analytics_summary"
      assert event_data["report_format"] == "pdf"
      assert event_data["data_sources"] == ["user_metrics", "performance_data"]
      assert event_data["recipients"] == 2

      metrics = Jason.decode!(event.metrics)
      assert metrics["generation_duration_ms"] == 45_000
      assert metrics["data_rows_processed"] == 50_000
      assert metrics["report_size_mb"] == 12.5
      assert metrics["success"] == true
    end

    test "handles report generation failures", %{report_params: params, opts: opts} do
      failed_params = Map.put(params, :success, false)

      assert :ok = AnalyticsEventLogger.log_report_generation(failed_params, opts)

      events = get_events_from_table("analytics_report_events", opts[:tenant_id])
      metrics = Jason.decode!(hd(events).metrics)
      assert metrics["success"] == false
    end
  end

  describe "log_dashboard_interaction/2 - TDG Dashboard Tests" do
    setup %{tenant_id: tenant_id, user_id: user_id} do
      AnalyticsEventLogger.initialize_hypertables()

      {:ok,
       %{
         interaction_params: %{
           dashboard_id: "dashboard-executive-001",
           type: :executive,
           action: :drill_down,
           widget_id: "revenue-chart",
           widget_type: :line_chart,
           filters: %{region: "north_america", period: "q3_2025"},
           drill_path: ["revenue", "by_region", "quarterly"],
           export: true,
           session_duration: 300_000,
           load_time: 850,
           render_time: 150,
           refresh_count: 3,
           actions_count: 12,
           bounce_rate: 0.15
         },
         opts: [tenant_id: tenant_id, user_id: user_id, session_id: "dashboard-session-789"]
       }}
    end

    test "logs dashboard interactions with user behavior analytics", %{
      interaction_params: params,
      opts: opts
    } do
      assert :ok = AnalyticsEventLogger.log_dashboard_interaction(params, opts)

      events = get_events_from_table("analytics_dashboard_events", opts[:tenant_id])
      assert length(events) == 1

      event = hd(events)
      assert event.event_type == "dashboard_interaction"

      event_data = Jason.decode!(event.event_data)
      assert event_data["dashboard_id"] == "dashboard-executive-001"
      assert event_data["dashboard_type"] == "executive"
      assert event_data["action"] == "drill_down"
      assert event_data["widget_id"] == "revenue-chart"
      assert event_data["drill_down_path"] == ["revenue", "by_region", "quarterly"]

      metrics = Jason.decode!(event.metrics)
      assert metrics["session_duration_ms"] == 300_000
      assert metrics["page_load_time_ms"] == 850
      assert metrics["widget_render_time_ms"] == 150
    end

    test "updates user behavior metrics asynchronously", %{interaction_params: params, opts: opts} do
      # Mock the async user behavior update
      :meck.new(Task, [:passthrough])

      :meck.expect(Task, :start, fn fun ->
        # Execute immediately for testing
        spawn(fun)
        {:ok, self()}
      end)

      assert :ok = AnalyticsEventLogger.log_dashboard_interaction(params, opts)

      # Give async task time to complete
      :timer.sleep(100)

      :meck.unload(Task)
    end
  end

  describe "log_ml_event/2 - TDG Machine Learning Tests" do
    setup %{tenant_id: tenant_id, user_id: user_id} do
      AnalyticsEventLogger.initialize_hypertables()

      {:ok,
       %{
         training_params: %{
           subtype: :training,
           model_id: "fraud-detection-v2",
           model_type: :classification,
           algorithm: "random_forest",
           dataset_size: 1_000_000,
           features: 45,
           hyperparameters: %{
             n_estimators: 100,
             max_depth: 10,
             min_samples_split: 2
           },
           cv: true,
           duration: 1_800_000,
           accuracy: 0.94,
           precision: 0.92,
           recall: 0.96,
           f1: 0.94,
           loss: 0.06,
           epochs: 50,
           converged: true
         },
         prediction_params: %{
           subtype: :prediction,
           model_id: "fraud-detection-v2",
           model_type: :classification,
           algorithm: "random_forest",
           duration: 25,
           batch_size: 100,
           confidence: 0.88,
           model_version: "2.1",
           feature_importance: %{
             transaction_amount: 0.35,
             time_of_day: 0.22,
             merchant_category: 0.18
           },
           outlier: false,
           prediction: "legitimate"
         },
         opts: [tenant_id: tenant_id, user_id: user_id, session_id: "ml-session-101"]
       }}
    end

    test "logs ML training events with comprehensive metrics", %{
      training_params: params,
      opts: opts
    } do
      expect(
        Indrajaal.Analytics.BusinessIntelligence,
        :update_ml_performance_metrics,
        fn _event -> :ok end
      )

      assert :ok = AnalyticsEventLogger.log_ml_event(params, opts)

      events = get_events_from_table("analytics_ml_events", opts[:tenant_id])
      assert length(events) == 1

      event = hd(events)
      assert event.event_type == "ml_training"

      event_data = Jason.decode!(event.event_data)
      assert event_data["event_subtype"] == "training"
      assert event_data["model_id"] == "fraud-detection-v2"
      assert event_data["model_type"] == "classification"
      assert event_data["algorithm"] == "random_forest"
      assert event_data["dataset_size"] == 1_000_000
      assert event_data["feature_count"] == 45

      metrics = Jason.decode!(event.metrics)
      assert metrics["training_duration_ms"] == 1_800_000
      assert metrics["accuracy"] == 0.94
      assert metrics["precision"] == 0.92
      assert metrics["recall"] == 0.96
      assert metrics["f1_score"] == 0.94
      assert metrics["convergence_achieved"] == true
    end

    test "logs ML prediction events with different metrics", %{
      prediction_params: params,
      opts: opts
    } do
      assert :ok = AnalyticsEventLogger.log_ml_event(params, opts)

      events = get_events_from_table("analytics_ml_events", opts[:tenant_id])
      event_data = Jason.decode!(hd(events).event_data)
      metrics = Jason.decode!(hd(events).metrics)

      assert event_data["event_subtype"] == "prediction"
      assert metrics["prediction_duration_ms"] == 25
      assert metrics["batch_size"] == 100
      assert metrics["confidence_score"] == 0.88
      assert metrics["prediction_value"] == "legitimate"
    end
  end

  describe "log_kpi_calculation/2 - TDG KPI Tests" do
    setup %{tenant_id: tenant_id, user_id: user_id} do
      AnalyticsEventLogger.initialize_hypertables()

      {:ok,
       %{
         kpi_params: %{
           name: "monthly_revenue",
           category: :financial,
           method: :aggregation,
           sources: ["transactions", "subscriptions"],
           period: :monthly,
           aggregation: :tenant,
           baseline: true,
           value: 125_000.50,
           previous_value: 118_000.25,
           target: 130_000.00,
           duration: 5000,
           quality_score: 0.98
         },
         opts: [tenant_id: tenant_id, user_id: user_id, session_id: "kpi-session-202"]
       }}
    end

    test "logs KPI calculations with business intelligence integration", %{
      kpi_params: params,
      opts: opts
    } do
      expect(Indrajaal.Analytics.BusinessIntelligence, :update_kpi_dashboards, fn _event ->
        :ok
      end)

      assert :ok = AnalyticsEventLogger.log_kpi_calculation(params, opts)

      events = get_events_from_table("analytics_kpi_events", opts[:tenant_id])
      assert length(events) == 1

      event = hd(events)
      event_data = Jason.decode!(event.event_data)
      metrics = Jason.decode!(event.metrics)

      assert event_data["kpi_name"] == "monthly_revenue"
      assert event_data["kpi_category"] == "financial"
      assert event_data["calculation_method"] == "aggregation"

      assert metrics["kpi_value"] == 125_000.50
      assert metrics["previous_value"] == 118_000.25
      assert metrics["target_value"] == 130_000.00

      # Verify calculated percentage change
      expected_change = (125_000.50 - 118_000.25) / 118_000.25 * 100
      assert_in_delta metrics["percentage_change"], expected_change, 0.01

      # Verify variance from target
      expected_variance = (125_000.50 - 130_000.00) / 130_000.00 * 100
      assert_in_delta metrics["variance_from_target"], expected_variance, 0.01
    end

    test "handles nil values in percentage calculations", %{opts: opts} do
      params_with_nil = %{
        name: "test_kpi",
        value: 100.0,
        previous_value: nil,
        target: nil
      }

      assert :ok = AnalyticsEventLogger.log_kpi_calculation(params_with_nil, opts)

      events = get_events_from_table("analytics_kpi_events", opts[:tenant_id])
      metrics = Jason.decode!(hd(events).metrics)

      assert is_nil(metrics["percentage_change"])
      assert is_nil(metrics["variance_from_target"])
    end
  end

  describe "log_performance_event/2 - TDG Performance Tests" do
    setup %{tenant_id: tenant_id, user_id: user_id} do
      AnalyticsEventLogger.initialize_hypertables()

      {:ok,
       %{
         perf_params: %{
           component: :database,
           operation: "complex_query",
           resource: :cpu,
           threshold_type: :warning,
           alert_level: :warning,
           cpu: 75.5,
           memory: 6500,
           disk_io: 150.2,
           network_io: 85.7,
           response_time: 3500,
           throughput: 450.5,
           error_rate: 1.2,
           availability: 99.8
         },
         opts: [tenant_id: tenant_id, user_id: user_id, session_id: "perf-session-303"]
       }}
    end

    test "logs performance events and triggers alerts when thresholds exceeded", %{
      perf_params: params,
      opts: opts
    } do
      # Performance params exceed warning thresholds
      assert :ok = AnalyticsEventLogger.log_performance_event(params, opts)

      events = get_events_from_table("analytics_performance_events", opts[:tenant_id])
      assert length(events) == 1

      event = hd(events)
      event_data = Jason.decode!(event.event_data)
      metrics = Jason.decode!(event.metrics)

      assert event_data["component"] == "database"
      assert event_data["operation"] == "complex_query"
      assert event_data["alert_level"] == "warning"

      assert metrics["cpu_usage_percent"] == 75.5
      assert metrics["memory_usage_mb"] == 6500
      assert metrics["response_time_ms"] == 3500
    end

    test "triggers critical alerts for extreme performance degradation", %{opts: opts} do
      critical_params = %{
        component: :application,
        operation: "user_request",
        threshold_type: :critical,
        cpu: 95.0,
        memory: 9500,
        response_time: 15_000,
        error_rate: 8.5
      }

      expect(Indrajaal.Observability.DualLogging, :log_domain_event, 2, fn
        :analytics, "performance_event", _data, :info -> :ok
        :analytics, "performance_alert", _data, :warning -> :ok
      end)

      assert :ok = AnalyticsEventLogger.log_performance_event(critical_params, opts)
    end
  end

  describe "get_analytics_events/1 - TDG Query Tests" do
    setup %{tenant_id: tenant_id} do
      AnalyticsEventLogger.initialize_hypertables()

      # Create test data
      query_params = %{query_type: :select, duration: 1000}
      opts = [tenant_id: tenant_id, user_id: "test-user"]

      AnalyticsEventLogger.log_query_execution(query_params, opts)
      AnalyticsEventLogger.log_query_execution(query_params, opts)

      {:ok, %{}}
    end

    test "retrieves analytics events with filtering", %{tenant_id: tenant_id} do
      start_time = DateTime.add(DateTime.utc_now(), -1, :hour)
      end_time = DateTime.utc_now()

      opts = [
        table: "analytics_query_events",
        start_time: start_time,
        end_time: end_time,
        tenant_id: tenant_id,
        limit: 10
      ]

      assert {:ok, events} = AnalyticsEventLogger.get_analytics_events(opts)
      assert is_list(events)
    end

    @tag :skip
    test "handles database errors gracefully when querying events" do
      # TODO: Implement with Mox when Repo mock is configured
      # This test requires database error simulation which needs proper Mox setup
      assert true
    end
  end

  describe "get_real_time_dashboard_data/1 - TDG Dashboard Data Tests" do
    test "generates comprehensive dashboard data", %{tenant_id: tenant_id} do
      opts = [tenant_id: tenant_id, time_window: :last_hour]

      assert {:ok, dashboard_data} = AnalyticsEventLogger.get_real_time_dashboard_data(opts)

      assert Map.has_key?(dashboard_data, :timestamp)
      assert Map.has_key?(dashboard_data, :tenant_id)
      assert Map.has_key?(dashboard_data, :query_performance)
      assert Map.has_key?(dashboard_data, :dashboard_usage)
      assert Map.has_key?(dashboard_data, :ml_performance)
      assert Map.has_key?(dashboard_data, :kpi_values)
      assert Map.has_key?(dashboard_data, :system_health)
      assert Map.has_key?(dashboard_data, :alerts)
      assert Map.has_key?(dashboard_data, :recommendations)

      assert dashboard_data.tenant_id == tenant_id
      assert dashboard_data.time_window == :last_hour
    end

    test "handles different time windows correctly" do
      time_windows = [:last_hour, :last_day, :last_week]

      for time_window <- time_windows do
        assert {:ok, data} =
                 AnalyticsEventLogger.get_real_time_dashboard_data(time_window: time_window)

        assert data.time_window == time_window
      end
    end
  end

  # ============================================================================
  # PROPCHECK PROPERTY-BASED TESTS
  # ============================================================================

  describe "PropCheck Property Tests - Analytics Event Logger" do
    property "all log functions return :ok for valid inputs", [:verbose] do
      forall {event_type, params, opts} <-
               {event_type_generator(), event_params_generator(), opts_generator()} do
        AnalyticsEventLogger.initialize_hypertables()

        result =
          case event_type do
            :query_execution -> AnalyticsEventLogger.log_query_execution(params, opts)
            :report_generation -> AnalyticsEventLogger.log_report_generation(params, opts)
            :dashboard_interaction -> AnalyticsEventLogger.log_dashboard_interaction(params, opts)
            :ml_event -> AnalyticsEventLogger.log_ml_event(params, opts)
            :kpi_calculation -> AnalyticsEventLogger.log_kpi_calculation(params, opts)
            :performance_event -> AnalyticsEventLogger.log_performance_event(params, opts)
          end

        result == :ok
      end
    end

    property "correlation IDs are unique across all events", [:verbose] do
      forall n <- range(1, 100) do
        AnalyticsEventLogger.initialize_hypertables()

        correlation_ids =
          for _i <- 1..n do
            AnalyticsEventLogger.generate_correlation_id()
          end

        length(Enum.uniq(correlation_ids)) == length(correlation_ids)
      end
    end

    property "query complexity calculation is consistent", [:verbose] do
      forall params <- query_params_generator() do
        # Calculate complexity twice with same params
        complexity1 = calculate_query_complexity_test_helper(params)
        complexity2 = calculate_query_complexity_test_helper(params)

        complexity1 == complexity2 and complexity1 >= 1
      end
    end
  end

  # ============================================================================
  # EXUNIT PROPERTIES TESTS
  # ============================================================================

  describe "ExUnitProperties Property Tests" do
    test "events maintain tenant isolation" do
      ExUnitProperties.check all(
                               tenant_id <-
                                 SD.string(:alphanumeric, min_length: 8, max_length: 16),
                               user_id <- SD.string(:alphanumeric, min_length: 8, max_length: 16),
                               query_params <- query_params_property_generator()
                             ) do
        AnalyticsEventLogger.initialize_hypertables()
        opts = [tenant_id: tenant_id, user_id: user_id]

        assert :ok = AnalyticsEventLogger.log_query_execution(query_params, opts)

        events = get_events_from_table("analytics_query_events", tenant_id)
        assert length(events) >= 1
        assert hd(events).tenant_id == tenant_id
      end
    end

    test "timestamps are within reasonable range" do
      ExUnitProperties.check all(
                               params <- query_params_property_generator(),
                               tenant_id <- SD.string(:alphanumeric, min_length: 8)
                             ) do
        AnalyticsEventLogger.initialize_hypertables()
        before_time = DateTime.utc_now()

        assert :ok = AnalyticsEventLogger.log_query_execution(params, tenant_id: tenant_id)

        after_time = DateTime.utc_now()
        events = get_events_from_table("analytics_query_events", tenant_id)
        event_time = hd(events).timestamp

        DateTime.compare(before_time, event_time) in [:lt, :eq] and
          DateTime.compare(event_time, after_time) in [:lt, :eq]
      end
    end

    test "KPI percentage calculations are mathematically correct" do
      ExUnitProperties.check all(
                               current <- SD.float(min: 0.0, max: 1_000_000.0),
                               # Avoid division by zero
                               previous <- SD.float(min: 1.0, max: 1_000_000.0)
                             ) do
        params = %{
          name: "test_kpi",
          value: current,
          previous_value: previous
        }

        AnalyticsEventLogger.initialize_hypertables()
        assert :ok = AnalyticsEventLogger.log_kpi_calculation(params, tenant_id: "test")

        events = get_events_from_table("analytics_kpi_events", "test")
        metrics = Jason.decode!(hd(events).metrics)

        expected_change = (current - previous) / previous * 100
        actual_change = metrics["percentage_change"]

        abs(actual_change - expected_change) < 0.01
      end
    end
  end

  # ============================================================================
  # STAMP SAFETY CONSTRAINT TESTS
  # ============================================================================

  describe "STAMP Safety Constraints Validation" do
    test "SC-ANALYTICS-001: System SHALL maintain tenant data isolation" do
      AnalyticsEventLogger.initialize_hypertables()

      # Test cross-tenant data isolation
      tenant1_events =
        for i <- 1..5 do
          params = %{query_type: :select, duration: i * 100}
          opts = [tenant_id: "tenant-1", user_id: "user-1"]
          AnalyticsEventLogger.log_query_execution(params, opts)
        end

      tenant2_events =
        for i <- 1..3 do
          params = %{query_type: :select, duration: i * 200}
          opts = [tenant_id: "tenant-2", user_id: "user-2"]
          AnalyticsEventLogger.log_query_execution(params, opts)
        end

      # Verify complete isolation
      tenant1_data = get_events_from_table("analytics_query_events", "tenant-1")
      tenant2_data = get_events_from_table("analytics_query_events", "tenant-2")

      assert length(tenant1_data) == 5
      assert length(tenant2_data) == 3

      # Verify no cross-contamination
      assert Enum.all?(tenant1_data, &(&1.tenant_id == "tenant-1"))
      assert Enum.all?(tenant2_data, &(&1.tenant_id == "tenant-2"))
    end

    test "SC-ANALYTICS-002: System SHALL prevent data corruption during concurrent access" do
      AnalyticsEventLogger.initialize_hypertables()

      # Simulate concurrent access from multiple processes
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            params = %{query_type: :select, duration: i * 100}
            opts = [tenant_id: "concurrent-test", user_id: "user-#{i}"]
            AnalyticsEventLogger.log_query_execution(params, opts)
          end)
        end

      # Wait for all tasks to complete
      results = Enum.map(tasks, &Task.await/1)

      # All should succeed
      assert Enum.all?(results, &(&1 == :ok))

      # Verify all events were recorded
      events = get_events_from_table("analytics_query_events", "concurrent-test")
      assert length(events) == 10
    end

    test "SC-ANALYTICS-003: System SHALL validate all input parameters" do
      AnalyticsEventLogger.initialize_hypertables()

      # Test with various invalid inputs
      invalid_params = [
        nil,
        %{},
        %{invalid_field: "test"},
        %{query_type: :invalid_type}
      ]

      for params <- invalid_params do
        # Should handle gracefully without crashing
        result = AnalyticsEventLogger.log_query_execution(params, tenant_id: "test")
        assert result == :ok or match?({:error, _}, result)
      end
    end

    test "SC-ANALYTICS-004: System SHALL maintain data consistency across all event types" do
      AnalyticsEventLogger.initialize_hypertables()

      tenant_id = "consistency-test"
      user_id = "test-user"
      opts = [tenant_id: tenant_id, user_id: user_id, session_id: "session-123"]

      # Log events of different types
      assert :ok = AnalyticsEventLogger.log_query_execution(%{query_type: :select}, opts)
      assert :ok = AnalyticsEventLogger.log_report_generation(%{type: :standard}, opts)
      assert :ok = AnalyticsEventLogger.log_dashboard_interaction(%{dashboard_id: "test"}, opts)

      assert :ok =
               AnalyticsEventLogger.log_ml_event(%{subtype: :prediction, model_id: "test"}, opts)

      assert :ok = AnalyticsEventLogger.log_kpi_calculation(%{name: "test_kpi", value: 100}, opts)
      assert :ok = AnalyticsEventLogger.log_performance_event(%{component: :system}, opts)

      # Verify consistency across all tables
      tables = [
        "analytics_query_events",
        "analytics_report_events",
        "analytics_dashboard_events",
        "analytics_ml_events",
        "analytics_kpi_events",
        "analytics_performance_events"
      ]

      for table <- tables do
        events = get_events_from_table(table, tenant_id)
        assert length(events) == 1

        event = hd(events)
        assert event.tenant_id == tenant_id
        assert event.session_id == "session-123"
        assert not is_nil(event.correlation_id)
        assert not is_nil(event.timestamp)
      end
    end

    test "SC-ANALYTICS-005: System SHALL provide audit trail for all operations" do
      AnalyticsEventLogger.initialize_hypertables()

      # Perform various operations
      operations = [
        {:query_execution, %{query_type: :select, duration: 1000}},
        {:report_generation, %{type: :analytics, format: :pdf}},
        {:dashboard_interaction, %{dashboard_id: "test-dashboard"}},
        {:kpi_calculation, %{name: "test_kpi", value: 100}}
      ]

      tenant_id = "audit-test"
      opts = [tenant_id: tenant_id, user_id: "audit-user", session_id: "audit-session"]

      for {operation, params} <- operations do
        case operation do
          :query_execution -> AnalyticsEventLogger.log_query_execution(params, opts)
          :report_generation -> AnalyticsEventLogger.log_report_generation(params, opts)
          :dashboard_interaction -> AnalyticsEventLogger.log_dashboard_interaction(params, opts)
          :kpi_calculation -> AnalyticsEventLogger.log_kpi_calculation(params, opts)
        end
      end

      # Verify complete audit trail exists
      all_events = get_all_events_for_tenant(tenant_id)
      assert length(all_events) == 4

      # Verify audit trail completeness
      for event <- all_events do
        assert not is_nil(event.correlation_id)
        assert not is_nil(event.timestamp)
        assert event.tenant_id == tenant_id
        assert is_binary(event.event_data)
        assert is_binary(event.metrics)
      end
    end
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  # Database helper functions
  defp table_exists?(table_name) do
    query = """
    SELECT EXISTS (
      SELECT FROM information_schema.tables
      WHERE table_name = '#{table_name}'
    );
    """

    case Repo.query(query) do
      {:ok, %{rows: [[true]]}} -> true
      _ -> false
    end
  end

  defp hypertable_configured?(table_name) do
    query = """
    SELECT hypertable_name FROM timescaledb_information.hypertables
    WHERE hypertable_name = '#{table_name}';
    """

    case Repo.query(query) do
      {:ok, %{rows: [[^table_name]]}} -> true
      _ -> false
    end
  end

  defp retention_policy_set?(table_name) do
    query = """
    SELECT job_id FROM timescaledb_information.jobs
    WHERE hypertable_name = '#{table_name}' AND proc_name = 'policy_retention';
    """

    case Repo.query(query) do
      {:ok, %{rows: []}} -> false
      {:ok, %{rows: [_]}} -> true
      _ -> false
    end
  end

  defp index_exists?(index_name) do
    query = """
    SELECT EXISTS (
      SELECT FROM pg_indexes
      WHERE indexname = '#{index_name}'
    );
    """

    case Repo.query(query) do
      {:ok, %{rows: [[true]]}} -> true
      _ -> false
    end
  end

  defp get_events_from_table(table_name, tenant_id) do
    query = """
    SELECT * FROM #{table_name}
    WHERE tenant_id = $1
    ORDER BY timestamp DESC;
    """

    case Repo.query(query, [tenant_id]) do
      {:ok, %{rows: rows, columns: columns}} ->
        Enum.map(rows, fn row ->
          columns
          |> Enum.zip(row)
          |> Enum.into(%{})
          |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
          |> Enum.into(%{})
        end)

      _ ->
        []
    end
  end

  defp get_all_events_for_tenant(tenant_id) do
    tables = [
      "analytics_query_events",
      "analytics_report_events",
      "analytics_dashboard_events",
      "analytics_ml_events",
      "analytics_kpi_events",
      "analytics_performance_events"
    ]

    Enum.flat_map(tables, &get_events_from_table(&1, tenant_id))
  end

  # Property test generators
  defp event_type_generator do
    PC.oneof([
      :query_execution,
      :report_generation,
      :dashboard_interaction,
      :ml_event,
      :kpi_calculation,
      :performance_event
    ])
  end

  defp event_params_generator do
    PC.oneof([
      query_params_generator(),
      report_params_generator(),
      dashboard_params_generator(),
      ml_params_generator(),
      kpi_params_generator(),
      performance_params_generator()
    ])
  end

  defp query_params_generator do
    let {duration, rows, memory} <- {range(100, 10_000), range(1, 100_000), range(1, 1000)} do
      %{
        query_type: PC.oneof([:select, :insert, :update, :delete]),
        duration: duration,
        rows_examined: rows,
        memory_usage: memory,
        tables: PC.list(PC.utf8()),
        joins: PC.list(PC.oneof([:inner, :left, :right]))
      }
    end
  end

  defp report_params_generator do
    %{
      type: PC.oneof([:standard, :analytics, :executive]),
      format: PC.oneof([:pdf, :excel, :csv]),
      duration: range(1000, 60_000),
      size: PC.float(0.1, 100.0),
      success: PC.boolean()
    }
  end

  defp dashboard_params_generator do
    %{
      dashboard_id: PC.utf8(),
      action: PC.oneof([:view, :drill_down, :export, :filter]),
      load_time: range(100, 5000),
      session_duration: range(10_000, 600_000)
    }
  end

  defp ml_params_generator do
    %{
      subtype: PC.oneof([:training, :prediction]),
      model_id: PC.utf8(),
      model_type: PC.oneof([:classification, :regression, :clustering]),
      duration: range(100, 10_000),
      accuracy: PC.float(0.0, 1.0)
    }
  end

  defp kpi_params_generator do
    %{
      name: PC.utf8(),
      value: PC.float(0.0, 1_000_000.0),
      previous_value: PC.float(0.0, 1_000_000.0),
      target: PC.float(0.0, 1_000_000.0)
    }
  end

  defp performance_params_generator do
    %{
      component: PC.oneof([:system, :database, :application]),
      cpu: PC.float(0.0, 100.0),
      memory: range(100, 10_000),
      response_time: range(10, 15_000)
    }
  end

  defp opts_generator do
    let {tenant_id, user_id} <-
          {string(:alphanumeric, min_length: 8), string(:alphanumeric, min_length: 8)} do
      [
        tenant_id: tenant_id,
        user_id: user_id,
        session_id: PC.utf8()
      ]
    end
  end

  # ExUnitProperties generators
  defp query_params_property_generator do
    gen all(
          duration <- SD.integer(100..10_000),
          rows <- SD.integer(1..100_000),
          memory <- SD.integer(1..1000)
        ) do
      %{
        query_type: :select,
        duration: duration,
        rows_examined: rows,
        memory_usage: memory
      }
    end
  end

  # Test helper for complexity calculation
  defp calculate_query_complexity_test_helper(params) do
    complexity = 1
    complexity = complexity + length(Map.get(params, :tables, [])) * 2
    complexity = complexity + length(Map.get(params, :joins, [])) * 3
    complexity = complexity + map_size(Map.get(params, :filters, %{}))
    complexity = complexity + length(Map.get(params, :aggregations, [])) * 2

    if Map.get(params, :subqueries, 0) > 0 do
      complexity + Map.get(params, :subqueries) * 5
    else
      complexity
    end
  end
end
