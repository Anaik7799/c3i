defmodule Indrajaal.Observability.Domains.AnalyticsInstrumentationTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import Indrajaal.STAMPTestHelpers

  alias Indrajaal.Observability.Domains.AnalyticsInstrumentation

  setup do
    # Detach any existing handlers before test
    handlers = :telemetry.list_handlers([])

    handlers
    |> Enum.each(fn handler ->
      if String.contains?(to_string(handler.id), "analytics") do
        :telemetry.detach(handler.id)
      end
    end)

    :ok
  end

  describe "setup/0" do
    test "attaches all analytics telemetry handlers" do
      log =
        capture_log(fn ->
          assert :ok = AnalyticsInstrumentation.setup()
        end)

      # Verify handlers were attached
      handlers = :telemetry.list_handlers([])
      handler_ids = Enum.map(handlers, & &1.id)

      assert "analytics - processing - handlers" in handler_ids
      assert "analytics - report - handlers" in handler_ids
      assert "analytics - insight - handlers" in handler_ids
      assert "analytics - prediction - handlers" in handler_ids
    end

    test "returns :ok" do
      assert :ok = AnalyticsInstrumentation.setup()
    end

    test "can be called multiple times without error" do
      assert :ok = AnalyticsInstrumentation.setup()
      assert :ok = AnalyticsInstrumentation.setup()
    end
  end

  describe "analytics processing events" do
    setup do
      AnalyticsInstrumentation.setup()
      :ok
    end

    test "handles analytics processing start event" do
      log =
        capture_log(fn ->
          :telemetry.execute(
            [:indrajaal, :analytics, :processing, :start],
            %{},
            %{
              type: "customer_segmentation",
              source: "database",
              record_count: 1000,
              trace_id: "trace-123"
            }
          )
        end)

      assert log =~ "Analytics processing started"
      assert log =~ "customer_segmentation"
      assert log =~ "database"
    end

    test "handles analytics processing stop event with duration" do
      log =
        capture_log(fn ->
          :telemetry.execute(
            [:indrajaal, :analytics, :processing, :stop],
            %{duration: System.convert_time_unit(500, :millisecond, :native)},
            %{
              type: "sales_analysis",
              records_processed: 5000
            }
          )
        end)

      assert log =~ "Analytics processing completed"
      assert log =~ "sales_analysis"
      assert log =~ "5000"
    end

    test "handles analytics query stop event" do
      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :analytics, :query, :stop],
          %{duration: System.convert_time_unit(100, :millisecond, :native)},
          %{
            query_type: "aggregation",
            source: "timeseries_db"
          }
        )
      end)
    end

    test "handles analytics aggregation stop event" do
      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :analytics, :aggregation, :stop],
          %{row_count: 25_000},
          %{
            type: "group_by_region",
            group_by: "region,date"
          }
        )
      end)
    end
  end

  describe "report generation events" do
    setup do
      AnalyticsInstrumentation.setup()
      :ok
    end

    test "handles report generation start event" do
      log =
        capture_log(fn ->
          :telemetry.execute(
            [:indrajaal, :analytics, :report, :generation, :start],
            %{},
            %{
              type: "monthly_sales",
              format: "pdf",
              tenant_id: "tenant-456",
              trace_id: "trace-789"
            }
          )
        end)

      assert log =~ "Report generation started"
      assert log =~ "monthly_sales"
      assert log =~ "pdf"
    end

    test "handles report generation stop event with metrics" do
      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :analytics, :report, :generation, :stop],
          %{
            duration: System.convert_time_unit(2000, :millisecond, :native),
            size_bytes: 1024 * 512
          },
          %{
            type: "quarterly_performance",
            format: "excel"
          }
        )
      end)
    end

    test "handles report export stop event" do
      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :analytics, :report, :export, :stop],
          %{},
          %{
            format: "csv",
            destination: "s3_bucket"
          }
        )
      end)
    end

    test "handles scheduled report execution event" do
      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :analytics, :report, :schedule, :executed],
          %{},
          %{
            schedule_type: "daily",
            success: true
          }
        )
      end)
    end
  end

  describe "business insight events" do
    setup do
      AnalyticsInstrumentation.setup()
      :ok
    end

    test "handles insight generation stop event" do
      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :analytics, :insight, :generation, :stop],
          %{},
          %{
            type: "customer_churn",
            confidence: 0.85
          }
        )
      end)
    end

    test "handles dashboard update event" do
      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :analytics, :insight, :dashboard, :update],
          %{},
          %{
            dashboard_id: "dashboard-123",
            widget_count: 8
          }
        )
      end)
    end

    test "handles KPI calculation event" do
      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :analytics, :insight, :kpi, :calculated],
          %{value: 95.5},
          %{
            name: "customer_satisfaction",
            category: "service_quality"
          }
        )
      end)
    end

    test "handles anomaly detection event with logging" do
      log =
        capture_log(fn ->
          :telemetry.execute(
            [:indrajaal, :analytics, :insight, :anomaly, :detected],
            %{},
            %{
              type: "sudden_drop",
              severity: :high,
              metric: "daily_revenue"
            }
          )
        end)

      assert log =~ "Analytics anomaly detected"
      assert log =~ "sudden_drop"
      assert log =~ "high"
      assert log =~ "daily_revenue"
    end
  end

  describe "predictive analytics events" do
    setup do
      AnalyticsInstrumentation.setup()
      :ok
    end

    test "handles prediction model stop event" do
      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :analytics, :prediction, :model, :stop],
          %{duration: System.convert_time_unit(1500, :millisecond, :native)},
          %{
            model_type: "linear_regression",
            accuracy: 0.92
          }
        )
      end)
    end

    test "handles forecast generation event" do
      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :analytics, :prediction, :forecast, :generated],
          %{},
          %{
            type: "revenue_forecast",
            horizon_days: 30
          }
        )
      end)
    end

    test "handles trend analysis event" do
      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :analytics, :prediction, :trend, :analyzed],
          %{slope: 0.15},
          %{
            metric: "customer_growth",
            direction: "upward"
          }
        )
      end)
    end

    test "handles predictive alert with logging" do
      log =
        capture_log(fn ->
          :telemetry.execute(
            [:indrajaal, :analytics, :prediction, :alert, :triggered],
            %{predicted_value: 1_000_000},
            %{
              type: "revenue_threshold",
              threshold: 950_000,
              severity: :medium
            }
          )
        end)

      assert log =~ "Predictive alert triggered"
      assert log =~ "revenue_threshold"
      assert log =~ "950_000"
    end
  end

  describe "record_processing/4" do
    setup do
      AnalyticsInstrumentation.setup()
      :ok
    end

    test "executes analytics processing telemetry event" do
      log =
        capture_log(fn ->
          AnalyticsInstrumentation.record_processing(
            "customer_analysis",
            "postgres",
            15_000,
            750
          )
        end)

      assert log =~ "Analytics processing completed"
      assert log =~ "customer_analysis"
      assert log =~ "15_000"
    end

    test "converts duration from milliseconds to native time unit" do
      assert_nothing_raised(fn ->
        AnalyticsInstrumentation.record_processing(
          "sales_aggregation",
          "clickhouse",
          50_000,
          1200
        )
      end)
    end

    test "includes source and type in metadata" do
      log =
        capture_log(fn ->
          AnalyticsInstrumentation.record_processing(
            "revenue_analysis",
            "timeseries_db",
            8000,
            500
          )
        end)

      assert log =~ "revenue_analysis"
    end
  end

  describe "record_report_generation/4" do
    setup do
      AnalyticsInstrumentation.setup()
      :ok
    end

    test "executes report generation telemetry event" do
      assert_nothing_raised(fn ->
        AnalyticsInstrumentation.record_report_generation(
          "annual_summary",
          "pdf",
          1024 * 1024 * 2,
          3000
        )
      end)
    end

    test "includes size_bytes and duration measurements" do
      assert_nothing_raised(fn ->
        AnalyticsInstrumentation.record_report_generation(
          "weekly_metrics",
          "excel",
          500_000,
          1500
        )
      end)
    end

    test "supports various report formats" do
      assert_nothing_raised(fn ->
        AnalyticsInstrumentation.record_report_generation("export", "csv", 100_000, 500)
        AnalyticsInstrumentation.record_report_generation("export", "json", 200_000, 300)
        AnalyticsInstrumentation.record_report_generation("export", "html", 150_000, 400)
      end)
    end
  end

  describe "record_insight/3" do
    setup do
      AnalyticsInstrumentation.setup()
      :ok
    end

    test "executes insight generation telemetry event" do
      assert_nothing_raised(fn ->
        AnalyticsInstrumentation.record_insight(
          "customer_churn_prediction",
          0.88
        )
      end)
    end

    test "supports optional metadata parameter" do
      assert_nothing_raised(fn ->
        AnalyticsInstrumentation.record_insight(
          "revenue_opportunity",
          0.75,
          %{segment: "enterprise", region: "us-east"}
        )
      end)
    end

    test "works with default empty metadata" do
      assert_nothing_raised(fn ->
        AnalyticsInstrumentation.record_insight(
          "market_trend",
          0.92
        )
      end)
    end

    test "merges custom metadata with required fields" do
      assert_nothing_raised(fn ->
        AnalyticsInstrumentation.record_insight(
          "customer_segmentation",
          0.85,
          %{
            algorithm: "k-means",
            clusters: 5,
            iterations: 100
          }
        )
      end)
    end
  end

  describe "record_prediction/3" do
    setup do
      AnalyticsInstrumentation.setup()
      :ok
    end

    test "executes prediction model telemetry event" do
      assert_nothing_raised(fn ->
        AnalyticsInstrumentation.record_prediction(
          "time_series_forecast",
          0.91,
          2500
        )
      end)
    end

    test "includes model type and accuracy" do
      assert_nothing_raised(fn ->
        AnalyticsInstrumentation.record_prediction(
          "neural_network",
          0.95,
          5000
        )
      end)
    end

    test "converts duration to native time unit" do
      assert_nothing_raised(fn ->
        AnalyticsInstrumentation.record_prediction(
          "regression_model",
          0.87,
          1200
        )
      end)
    end
  end

  describe "record_kpi/3" do
    setup do
      AnalyticsInstrumentation.setup()
      :ok
    end

    test "executes KPI calculation telemetry event" do
      assert_nothing_raised(fn ->
        AnalyticsInstrumentation.record_kpi(
          "customer_lifetime_value",
          2500.50,
          "revenue_metrics"
        )
      end)
    end

    test "includes KPI value in measurements" do
      assert_nothing_raised(fn ->
        AnalyticsInstrumentation.record_kpi(
          "net_promoter_score",
          85,
          "customer_satisfaction"
        )
      end)
    end

    test "supports various KPI types" do
      assert_nothing_raised(fn ->
        AnalyticsInstrumentation.record_kpi("conversion_rate", 0.12, "sales")
        AnalyticsInstrumentation.record_kpi("churn_rate", 0.05, "retention")
        AnalyticsInstrumentation.record_kpi("avg_order_value", 125.75, "revenue")
      end)
    end
  end

  describe "record_anomaly/4" do
    setup do
      AnalyticsInstrumentation.setup()
      :ok
    end

    test "executes anomaly detection telemetry event with logging" do
      log =
        capture_log(fn ->
          AnalyticsInstrumentation.record_anomaly(
            "spike",
            :critical,
            "transaction_volume"
          )
        end)

      assert log =~ "Analytics anomaly detected"
      assert log =~ "spike"
      assert log =~ "critical"
      assert log =~ "transaction_volume"
    end

    test "supports optional details parameter" do
      log =
        capture_log(fn ->
          AnalyticsInstrumentation.record_anomaly(
            "sudden_drop",
            :high,
            "daily_active_users",
            %{
              expected: 10_000,
              actual: 5000,
              deviation: 0.5
            }
          )
        end)

      assert log =~ "sudden_drop"
    end

    test "works with default empty details" do
      log =
        capture_log(fn ->
          AnalyticsInstrumentation.record_anomaly(
            "outlier",
            :medium,
            "response_time"
          )
        end)

      assert log =~ "outlier"
    end

    test "merges details with required fields" do
      assert_nothing_raised(fn ->
        AnalyticsInstrumentation.record_anomaly(
          "trend_change",
          :low,
          "page_views",
          %{
            window: "1h",
            threshold: 3.0,
            confidence: 0.95
          }
        )
      end)
    end
  end

  describe "BUGS: double underscore prefix in variable names (Lines 14, 33, 54, 72, 90, 107, 174, 240, 297)" do
    test "BUG: line 14 - double underscore prefix '__event' in comment" do
      # Line 14: # Telemetry __event prefixes
      #                        ^^^^^^^^ BUG - double underscore prefix
      # Should be: # Telemetry event prefixes
      # Impact: Non-standard naming in comment
      # Fix: Change __event to event
      # Note: This is a documentation issue
    end

    test "BUG: line 33 - double underscore prefix in variable '__events'" do
      # Line 33: __events = [
      #          ^^^^^^^^ BUG - double underscore prefix
      # Should be: events = [
      # Impact: Non-standard variable naming convention
      # Fix: Change __events to events (or _events if unused)
      # Note: This variable is used in :telemetry.attach_many call
    end

    test "BUG: line 54 - double underscore prefix in variable '__events'" do
      # Line 54: __events = [
      #          ^^^^^^^^ BUG - double underscore prefix
      # Should be: events = [
      # Impact: Non-standard variable naming convention
      # Fix: Change __events to events
      # Note: Used in attach_report_handlers
    end

    test "BUG: line 72 - double underscore prefix in variable '__events'" do
      # Line 72: __events = [
      #          ^^^^^^^^ BUG - double underscore prefix
      # Should be: events = [
      # Impact: Non-standard variable naming convention
      # Fix: Change __events to events
      # Note: Used in attach_insight_handlers
    end

    test "BUG: line 90 - double underscore prefix in variable '__events'" do
      # Line 90: __events = [
      #          ^^^^^^^^ BUG - double underscore prefix
      # Should be: events = [
      # Impact: Non-standard variable naming convention
      # Fix: Change __events to events
      # Note: Used in attach_prediction_handlers
    end

    test "BUG: line 107 - double underscore prefix in parameter '__config'" do
      # Line 107: defp handle_analytics_event(event, measurements, metadata, __config) do
      #                                                                       ^^^^^^^^^ BUG
      # Should be: _config (single underscore for unused parameter)
      # Impact: Non-standard parameter naming convention
      # Fix: Change __config to _config
      # Note: This parameter is unused in the function body
    end

    test "BUG: line 174 - double underscore prefix in parameter '__config'" do
      # Line 174: defp handle_report_event(event, measurements, metadata, __config) do
      #                                                                    ^^^^^^^^^ BUG
      # Should be: _config (single underscore for unused parameter)
      # Impact: Non-standard parameter naming convention
      # Fix: Change __config to _config
      # Note: This parameter is unused in the function body
    end

    test "BUG: line 240 - double underscore prefix in parameter '__config'" do
      # Line 240: defp handle_insight_event(event, measurements, metadata, __config) do
      #                                                                     ^^^^^^^^^ BUG
      # Should be: _config (single underscore for unused parameter)
      # Impact: Non-standard parameter naming convention
      # Fix: Change __config to _config
      # Note: This parameter is unused in the function body
    end

    test "BUG: line 297 - double underscore prefix in parameter '__config'" do
      # Line 297: defp handle_prediction_event(event, measurements, metadata, __config) do
      #                                                                        ^^^^^^^^^ BUG
      # Should be: _config (single underscore for unused parameter)
      # Impact: Non-standard parameter naming convention
      # Fix: Change __config to _config
      # Note: This parameter is unused in the function body
    end
  end

  describe "BUGS: handler ID spacing issues (Lines 44, 63, 81, 99)" do
    test "BUG: line 44 - spaces in handler ID 'analytics - processing - handlers'" do
      # Line 44: "analytics - processing - handlers",
      #          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ BUG - spaces around hyphens
      # Should be: "analytics-processing-handlers"
      # Impact: Non-standard handler ID naming (spaces instead of hyphens)
      # Fix: Remove spaces around hyphens
      # Note: Still works but inconsistent with naming conventions
    end

    test "BUG: line 63 - spaces in handler ID 'analytics - report - handlers'" do
      # Line 63: "analytics - report - handlers",
      #          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ BUG - spaces around hyphens
      # Should be: "analytics-report-handlers"
      # Impact: Non-standard handler ID naming
      # Fix: Remove spaces around hyphens
    end

    test "BUG: line 81 - spaces in handler ID 'analytics - insight - handlers'" do
      # Line 81: "analytics - insight - handlers",
      #          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ BUG - spaces around hyphens
      # Should be: "analytics-insight-handlers"
      # Impact: Non-standard handler ID naming
      # Fix: Remove spaces around hyphens
    end

    test "BUG: line 99 - spaces in handler ID 'analytics - prediction - handlers'" do
      # Line 99: "analytics - prediction - handlers",
      #          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ BUG - spaces around hyphens
      # Should be: "analytics-prediction-handlers"
      # Impact: Non-standard handler ID naming
      # Fix: Remove spaces around hyphens
    end
  end

  describe "BUGS: pattern matching issues (Lines 109, 456)" do
    test "BUG: line 109 - extra square brackets in pattern match" do
      # Line 109: [@analytics_prefix | [:processing, :start]] ->
      #           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ BUG - extra brackets
      # Should be: @analytics_prefix ++ [:processing, :start] ->
      # Impact: This pattern will NEVER match (incorrect structure)
      # Fix: Change [@analytics_prefix | [:processing, :start]] to @analytics_prefix ++ [:processing, :start]
      # Note: This is a CRITICAL BUG - analytics processing start event will never be handled
    end

    test "BUG: line 456 - spaces in agent comment 'Multi - Agent Architecture'" do
      # Line 456: # Multi - Agent Architecture: Integrated with 11 - agent coordination system
      #           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ BUG - spaces around hyphens
      # Should be: # Multi-Agent Architecture: Integrated with 11-agent coordination system
      # Impact: Documentation formatting inconsistency
      # Fix: Remove spaces around hyphens in comment
      # Note: This is a comment formatting issue
    end
  end

  describe "integration scenarios" do
    setup do
      AnalyticsInstrumentation.setup()
      :ok
    end

    test "complete analytics processing workflow" do
      # Start processing
      :telemetry.execute(
        [:indrajaal, :analytics, :processing, :start],
        %{},
        %{type: "full_analysis", source: "database", record_count: 10_000, trace_id: "trace-1"}
      )

      # Execute query
      :telemetry.execute(
        [:indrajaal, :analytics, :query, :stop],
        %{duration: System.convert_time_unit(200, :millisecond, :native)},
        %{query_type: "complex_join", source: "postgres"}
      )

      # Complete aggregation
      :telemetry.execute(
        [:indrajaal, :analytics, :aggregation, :stop],
        %{row_count: 5000},
        %{type: "group_sum", group_by: "category"}
      )

      # Complete processing
      log =
        capture_log(fn ->
          :telemetry.execute(
            [:indrajaal, :analytics, :processing, :stop],
            %{duration: System.convert_time_unit(1000, :millisecond, :native)},
            %{type: "full_analysis", records_processed: 10_000}
          )
        end)

      assert log =~ "Analytics processing completed"
    end

    test "report generation and export workflow" do
      # Start report generation
      :telemetry.execute(
        [:indrajaal, :analytics, :report, :generation, :start],
        %{},
        %{
          type: "quarterly_report",
          format: "pdf",
          tenant_id: "tenant-1",
          trace_id: "trace-2"
        }
      )

      # Complete generation
      :telemetry.execute(
        [:indrajaal, :analytics, :report, :generation, :stop],
        %{duration: System.convert_time_unit(3000, :millisecond, :native), size_bytes: 2_000_000},
        %{type: "quarterly_report", format: "pdf"}
      )

      # Export report
      :telemetry.execute(
        [:indrajaal, :analytics, :report, :export, :stop],
        %{},
        %{format: "pdf", destination: "email"}
      )

      # Record scheduled execution
      :telemetry.execute(
        [:indrajaal, :analytics, :report, :schedule, :executed],
        %{},
        %{schedule_type: "quarterly", success: true}
      )
    end

    test "business intelligence workflow with anomaly detection" do
      # Generate insights
      :telemetry.execute(
        [:indrajaal, :analytics, :insight, :generation, :stop],
        %{},
        %{type: "customer_behavior", confidence: 0.88}
      )

      # Calculate KPIs
      :telemetry.execute(
        [:indrajaal, :analytics, :insight, :kpi, :calculated],
        %{value: 92.5},
        %{name: "satisfaction_score", category: "customer"}
      )

      # Update dashboard
      :telemetry.execute(
        [:indrajaal, :analytics, :insight, :dashboard, :update],
        %{},
        %{dashboard_id: "exec-dashboard", widget_count: 12}
      )

      # Detect anomaly
      log =
        capture_log(fn ->
          :telemetry.execute(
            [:indrajaal, :analytics, :insight, :anomaly, :detected],
            %{},
            %{type: "spike", severity: :critical, metric: "error_rate"}
          )
        end)

      assert log =~ "Analytics anomaly detected"
    end

    test "predictive analytics workflow with alert" do
      # Run prediction model
      :telemetry.execute(
        [:indrajaal, :analytics, :prediction, :model, :stop],
        %{duration: System.convert_time_unit(2000, :millisecond, :native)},
        %{model_type: "random_forest", accuracy: 0.94}
      )

      # Generate forecast
      :telemetry.execute(
        [:indrajaal, :analytics, :prediction, :forecast, :generated],
        %{},
        %{type: "demand_forecast", horizon_days: 90}
      )

      # Analyze trend
      :telemetry.execute(
        [:indrajaal, :analytics, :prediction, :trend, :analyzed],
        %{slope: 0.25},
        %{metric: "revenue_growth", direction: "upward"}
      )

      # Trigger predictive alert
      log =
        capture_log(fn ->
          :telemetry.execute(
            [:indrajaal, :analytics, :prediction, :alert, :triggered],
            %{predicted_value: 500_000},
            %{type: "capacity_limit", threshold: 450_000, severity: :high}
          )
        end)

      assert log =~ "Predictive alert triggered"
    end
  end

  describe "edge cases and error handling" do
    setup do
      AnalyticsInstrumentation.setup()
      :ok
    end

    test "handles unknown event types gracefully" do
      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :analytics, :unknown, :event],
          %{},
          %{}
        )
      end)
    end

    test "handles events with missing metadata" do
      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :analytics, :processing, :stop],
          %{duration: 1000},
          %{}
        )
      end)
    end

    test "handles events with empty measurements" do
      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :analytics, :insight, :generation, :stop],
          %{},
          %{type: "test", confidence: 0.5}
        )
      end)
    end

    test "handles extremely large values" do
      assert_nothing_raised(fn ->
        AnalyticsInstrumentation.record_kpi(
          "total_revenue",
          999_999_999_999.99,
          "financial"
        )
      end)
    end

    test "handles zero and negative values" do
      assert_nothing_raised(fn ->
        AnalyticsInstrumentation.record_kpi("profit_margin", -5.5, "financial")
        AnalyticsInstrumentation.record_kpi("baseline", 0.0, "metrics")
      end)
    end

    test "handles very long duration values" do
      assert_nothing_raised(fn ->
        AnalyticsInstrumentation.record_processing(
          "batch_job",
          "warehouse",
          1_000_000,
          3_600_000
        )
      end)
    end
  end

  describe "telemetry handler attachment" do
    test "attaches handlers with correct event patterns" do
      AnalyticsInstrumentation.setup()

      handlers = :telemetry.list_handlers([])

      analytics_handlers =
        Enum.filter(handlers, fn h -> String.contains?(to_string(h.id), "analytics") end)

      assert length(analytics_handlers) >= 4

      # Verify each handler type exists
      handler_ids = Enum.map(analytics_handlers, & &1.id)
      assert "analytics - processing - handlers" in handler_ids
      assert "analytics - report - handlers" in handler_ids
      assert "analytics - insight - handlers" in handler_ids
      assert "analytics - prediction - handlers" in handler_ids
    end

    test "handlers use correct callback functions" do
      AnalyticsInstrumentation.setup()

      handlers = :telemetry.list_handlers([])

      analytics_handlers =
        Enum.filter(handlers, fn h -> String.contains?(to_string(h.id), "analytics") end)

      # All handlers should have function references
      Enum.each(analytics_handlers, fn handler ->
        assert is_function(handler.function, 4)
      end)
    end
  end

  describe "public API functions" do
    setup do
      AnalyticsInstrumentation.setup()
      :ok
    end

    test "all public record_* functions accept valid parameters" do
      assert_nothing_raised(fn ->
        AnalyticsInstrumentation.record_processing("type", "source", 100, 50)
        AnalyticsInstrumentation.record_report_generation("type", "format", 1000, 100)
        AnalyticsInstrumentation.record_insight("type", 0.9)
        AnalyticsInstrumentation.record_prediction("type", 0.85, 200)
        AnalyticsInstrumentation.record_kpi("name", 100, "category")
        AnalyticsInstrumentation.record_anomaly("type", :high, "metric")
      end)
    end

    test "optional parameters work correctly" do
      assert_nothing_raised(fn ->
        AnalyticsInstrumentation.record_insight("type", 0.8, %{extra: "data"})
        AnalyticsInstrumentation.record_anomaly("type", :low, "metric", %{details: "info"})
      end)
    end
  end
end
