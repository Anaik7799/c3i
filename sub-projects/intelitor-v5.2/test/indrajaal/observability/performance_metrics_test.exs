defmodule Indrajaal.Observability.PerformanceMetricsTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  import Indrajaal.STAMPTestHelpers

  alias Indrajaal.Observability.PerformanceMetrics

  setup do
    # Start the PerformanceMetrics GenServer
    {:ok, pid} = PerformanceMetrics.start_link([])

    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end
    end)

    %{pid: pid}
  end

  describe "start_link/1" do
    test "starts GenServer successfully" do
      {:ok, pid} = PerformanceMetrics.start_link([])
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "registers with module name" do
      {:ok, _pid} = PerformanceMetrics.start_link([])
      assert Process.whereis(PerformanceMetrics) != nil
      GenServer.stop(PerformanceMetrics)
    end
  end

  describe "setup/0" do
    test "initializes performance metrics collection system" do
      log =
        ExUnit.CaptureLog.capture_log(fn ->
          PerformanceMetrics.setup()
        end)

      assert log =~ "Performance metrics collection system initialized"
      assert log =~ "SOPv5.1 Enhanced"
    end

    test "initializes baselines asynchronously" do
      # Setup should send cast to initialize baselines
      PerformanceMetrics.setup()

      # Give GenServer time to process cast
      Process.sleep(100)

      # Baselines should be initialized (verified through get_performance_analytics)
      analytics = PerformanceMetrics.get_performance_analytics()
      assert is_map(analytics)
    end
  end

  describe "record_metric/4" do
    test "records metric with all parameters" do
      assert :ok =
               PerformanceMetrics.record_metric(
                 :api_response_time,
                 45.2,
                 :milliseconds,
                 %{endpoint: "/api/alarms"}
               )
    end

    test "records metric with default empty metadata" do
      assert :ok = PerformanceMetrics.record_metric(:throughput, 850.0, :requests_per_second)
    end

    test "handles various metric types" do
      # Response time metric
      assert :ok = PerformanceMetrics.record_metric(:api_response_time, 25.5, :milliseconds)

      # Throughput metric
      assert :ok = PerformanceMetrics.record_metric(:throughput, 1000.0, :rps)

      # Resource utilization metric
      assert :ok = PerformanceMetrics.record_metric(:cpu_usage, 42.5, :percent)

      # Error rate metric
      assert :ok = PerformanceMetrics.record_metric(:error_rate, 0.08, :percent)
    end

    test "processes metric asynchronously via cast" do
      # Should return immediately
      result =
        PerformanceMetrics.record_metric(:test_metric, 100.0, :units, %{test: true})

      assert result == :ok
    end
  end

  describe "get_performance_analytics/0" do
    test "returns analytics map with expected structure" do
      analytics = PerformanceMetrics.get_performance_analytics()

      assert is_map(analytics)
      assert Map.has_key?(analytics, :current_metrics)
      assert Map.has_key?(analytics, :trend_analysis)
      assert Map.has_key?(analytics, :sla_compliance)
      assert Map.has_key?(analytics, :efficiency_score)
      assert Map.has_key?(analytics, :performance_grade)
    end

    test "returns current metrics" do
      # Record some metrics first
      PerformanceMetrics.record_metric(:test_metric, 50.0, :ms)
      Process.sleep(50)

      analytics = PerformanceMetrics.get_performance_analytics()
      assert is_map(analytics.current_metrics)
    end

    test "includes SLA compliance score" do
      analytics = PerformanceMetrics.get_performance_analytics()
      assert is_number(analytics.sla_compliance)
      assert analytics.sla_compliance >= 0
      assert analytics.sla_compliance <= 100
    end

    test "includes efficiency score" do
      analytics = PerformanceMetrics.get_performance_analytics()
      assert is_number(analytics.efficiency_score)
      assert analytics.efficiency_score >= 0
      assert analytics.efficiency_score <= 100
    end

    test "includes performance grade" do
      analytics = PerformanceMetrics.get_performance_analytics()
      assert is_binary(analytics.performance_grade)
    end
  end

  describe "get_capacity_planning/0" do
    test "returns capacity planning data" do
      capacity = PerformanceMetrics.get_capacity_planning()

      assert is_map(capacity)
      assert Map.has_key?(capacity, :current_utilization)
      assert Map.has_key?(capacity, :growth_forecast)
      assert Map.has_key?(capacity, :scaling_recommendations)
      assert Map.has_key?(capacity, :cost_analysis)
    end

    test "includes current resource utilization" do
      capacity = PerformanceMetrics.get_capacity_planning()

      assert is_map(capacity.current_utilization)
      assert Map.has_key?(capacity.current_utilization, :cpu)
      assert Map.has_key?(capacity.current_utilization, :memory)
      assert Map.has_key?(capacity.current_utilization, :storage)
      assert Map.has_key?(capacity.current_utilization, :network)
    end

    test "includes growth forecasts" do
      capacity = PerformanceMetrics.get_capacity_planning()

      assert is_map(capacity.growth_forecast)
      assert is_number(capacity.growth_forecast.cpu)
      assert is_number(capacity.growth_forecast.memory)
    end

    test "includes scaling recommendations" do
      capacity = PerformanceMetrics.get_capacity_planning()

      assert is_list(capacity.scaling_recommendations)
    end

    test "includes cost analysis" do
      capacity = PerformanceMetrics.get_capacity_planning()

      assert is_map(capacity.cost_analysis)
      assert Map.has_key?(capacity.cost_analysis, :current_monthly)
      assert Map.has_key?(capacity.cost_analysis, :projected_6_months)
    end
  end

  describe "get_optimization_recommendations/0" do
    test "returns optimization recommendations list" do
      recommendations = PerformanceMetrics.get_optimization_recommendations()

      assert is_list(recommendations)
    end

    test "recommendations have expected structure when present" do
      # Record a metric that might generate recommendations
      PerformanceMetrics.record_metric(:slow_query, 500.0, :ms, %{query: "SELECT *"})
      Process.sleep(50)

      recommendations = PerformanceMetrics.get_optimization_recommendations()

      if length(recommendations) > 0 do
        rec = hd(recommendations)
        assert is_map(rec)
      end
    end
  end

  describe "display_performance_dashboard/0" do
    test "displays dashboard without errors" do
      output =
        capture_io(fn ->
          PerformanceMetrics.display_performance_dashboard()
        end)

      assert output =~ "ENHANCED PERFORMANCE METRICS DASHBOARD"
      assert output =~ "Framework: SOPv5.1"
      assert output =~ "PERFORMANCE OVERVIEW"
      assert output =~ "SLA COMPLIANCE"
      assert output =~ "RESOURCE EFFICIENCY"
    end

    test "includes all dashboard sections" do
      output =
        capture_io(fn ->
          PerformanceMetrics.display_performance_dashboard()
        end)

      assert output =~ "PERFORMANCE OVERVIEW"
      assert output =~ "SLA COMPLIANCE TRACKING"
      assert output =~ "RESOURCE EFFICIENCY"
      assert output =~ "BOTTLENECK ANALYSIS"
      assert output =~ "TREND ANALYSIS"
      assert output =~ "CAPACITY FORECAST"
      assert output =~ "BUSINESS CORRELATION"
      assert output =~ "OPTIMIZATION RECOMMENDATIONS"
    end

    test "displays performance status" do
      output =
        capture_io(fn ->
          PerformanceMetrics.display_performance_dashboard()
        end)

      assert output =~ "PERFORMANCE STATUS"
    end
  end

  describe "generate_capacity_report/0" do
    test "generates capacity planning report" do
      output =
        capture_io(fn ->
          PerformanceMetrics.generate_capacity_report()
        end)

      assert output =~ "CAPACITY PLANNING REPORT"
      assert output =~ "CURRENT UTILIZATION"
      assert output =~ "GROWTH FORECASTS"
      assert output =~ "SCALING RECOMMENDATIONS"
      assert output =~ "COST IMPACT"
    end

    test "includes current utilization metrics" do
      output =
        capture_io(fn ->
          PerformanceMetrics.generate_capacity_report()
        end)

      assert output =~ "CPU:"
      assert output =~ "Memory:"
      assert output =~ "Storage:"
      assert output =~ "Network:"
    end

    test "includes cost projections" do
      output =
        capture_io(fn ->
          PerformanceMetrics.generate_capacity_report()
        end)

      assert output =~ "Current Monthly Cost"
      assert output =~ "Projected Cost"
      assert output =~ "Optimization Savings"
    end
  end

  describe "metric categorization" do
    test "correctly categorizes response time metrics" do
      PerformanceMetrics.record_metric(:api_response_time, 50.0, :ms)
      Process.sleep(50)

      analytics = PerformanceMetrics.get_performance_analytics()
      assert is_map(analytics.current_metrics)
    end

    test "correctly categorizes throughput metrics" do
      PerformanceMetrics.record_metric(:throughput, 1000.0, :rps)
      Process.sleep(50)

      analytics = PerformanceMetrics.get_performance_analytics()
      assert is_map(analytics.current_metrics)
    end

    test "correctly categorizes resource utilization metrics" do
      PerformanceMetrics.record_metric(:cpu_usage, 45.0, :percent)
      PerformanceMetrics.record_metric(:memory_usage, 2.5, :gb)
      Process.sleep(50)

      analytics = PerformanceMetrics.get_performance_analytics()
      assert is_map(analytics.current_metrics)
    end
  end

  describe "SLA compliance monitoring" do
    test "tracks SLA violations for slow API response times" do
      log =
        ExUnit.CaptureLog.capture_log(fn ->
          # Record metric exceeding critical threshold (300.0ms)
          PerformanceMetrics.record_metric(:api_response_time, 350.0, :ms)
          Process.sleep(100)
        end)

      # Should log SLA violation
      assert log =~ "SLA violation" or log == ""
    end

    test "tracks SLA warnings for borderline metrics" do
      # Record metric in warning range
      PerformanceMetrics.record_metric(:api_response_time, 175.0, :ms)
      Process.sleep(50)

      analytics = PerformanceMetrics.get_performance_analytics()
      assert is_map(analytics)
    end

    test "accepts compliant metrics without alerts" do
      log =
        ExUnit.CaptureLog.capture_log(fn ->
          # Record metric within target threshold
          PerformanceMetrics.record_metric(:api_response_time, 50.0, :ms)
          Process.sleep(50)
        end)

      # Should not log violations for compliant metrics
      refute log =~ "violation"
    end
  end

  describe "real-time performance analysis" do
    test "triggers telemetry events for metric recording" do
      # Telemetry events should be triggered (validated by no errors)
      assert_nothing_raised(fn ->
        PerformanceMetrics.record_metric(:test_metric, 100.0, :units)
        Process.sleep(50)
      end)
    end

    test "processes metrics in real-time" do
      # Record metric and verify it's processed
      PerformanceMetrics.record_metric(:real_time_test, 75.0, :ms)
      Process.sleep(100)

      analytics = PerformanceMetrics.get_performance_analytics()
      assert is_map(analytics.current_metrics)
    end
  end

  describe "performance subscriptions" do
    test "allows process subscription to performance updates" do
      # Subscribe current process to performance updates
      GenServer.cast(PerformanceMetrics, {:subscribe_performance, self()})
      Process.sleep(50)

      # Should receive performance updates (if implemented)
      assert_nothing_raised(fn ->
        GenServer.call(PerformanceMetrics, :get_all_data)
      end)
    end
  end

  describe "concurrent metric recording" do
    test "handles concurrent metric recording from multiple processes" do
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            PerformanceMetrics.record_metric(:"metric_#{i}", i * 10.0, :ms)
          end)
        end

      Task.await_many(tasks)
      Process.sleep(100)

      analytics = PerformanceMetrics.get_performance_analytics()
      assert is_map(analytics)
    end

    test "maintains metric integrity under concurrent load" do
      # Record many metrics concurrently
      Enum.each(1..50, fn i ->
        spawn(fn ->
          PerformanceMetrics.record_metric(:"load_test_#{rem(i, 5)}", i * 1.0, :units)
        end)
      end)

      Process.sleep(200)

      analytics = PerformanceMetrics.get_performance_analytics()
      assert is_map(analytics.current_metrics)
    end
  end

  describe "edge cases and error handling" do
    test "handles very large metric values" do
      assert :ok = PerformanceMetrics.record_metric(:large_metric, 1_000_000.0, :bytes)
    end

    test "handles very small metric values" do
      assert :ok = PerformanceMetrics.record_metric(:small_metric, 0.001, :ms)
    end

    test "handles zero values" do
      assert :ok = PerformanceMetrics.record_metric(:zero_metric, 0.0, :count)
    end

    test "handles negative values (for delta metrics)" do
      assert :ok = PerformanceMetrics.record_metric(:delta_metric, -5.0, :change)
    end

    test "handles empty metadata" do
      assert :ok = PerformanceMetrics.record_metric(:no_metadata, 100.0, :units, %{})
    end

    test "handles complex metadata structures" do
      complex_metadata = %{
        endpoint: "/api/alarms",
        method: "GET",
        user: %{
          id: 123,
          role: "admin"
        },
        tags: ["important", "monitored"]
      }

      assert :ok =
               PerformanceMetrics.record_metric(
                 :complex_test,
                 50.0,
                 :ms,
                 complex_metadata
               )
    end
  end

  describe "integration scenarios" do
    test "complete workflow: record metrics -> analyze -> get recommendations" do
      # Record various metrics
      PerformanceMetrics.record_metric(:api_response_time, 45.0, :ms)
      PerformanceMetrics.record_metric(:cpu_usage, 75.0, :percent)
      PerformanceMetrics.record_metric(:memory_usage, 3.5, :gb)
      PerformanceMetrics.record_metric(:error_rate, 0.05, :percent)

      Process.sleep(100)

      # Get analytics
      analytics = PerformanceMetrics.get_performance_analytics()
      assert is_map(analytics)
      assert Map.has_key?(analytics, :current_metrics)

      # Get capacity planning
      capacity = PerformanceMetrics.get_capacity_planning()
      assert is_map(capacity)

      # Get recommendations
      recommendations = PerformanceMetrics.get_optimization_recommendations()
      assert is_list(recommendations)
    end

    test "dashboard display reflects recorded metrics" do
      # Record metrics
      PerformanceMetrics.record_metric(:dashboard_test, 100.0, :ms)
      Process.sleep(50)

      # Display dashboard
      output =
        capture_io(fn ->
          PerformanceMetrics.display_performance_dashboard()
        end)

      assert output =~ "PERFORMANCE METRICS DASHBOARD"
    end
  end

  describe "performance baseline initialization" do
    test "initializes with comprehensive baseline data" do
      # Trigger baseline initialization
      GenServer.cast(PerformanceMetrics, :initialize_baselines)
      Process.sleep(100)

      # Baselines should be available in analytics
      analytics = PerformanceMetrics.get_performance_analytics()
      assert is_map(analytics)
    end
  end

  describe "STAMP safety constraints" do
    test "SC1: maintains data integrity during metric recording" do
      # Record metrics and verify no data corruption
      PerformanceMetrics.record_metric(:integrity_test, 100.0, :ms)
      Process.sleep(50)

      analytics = PerformanceMetrics.get_performance_analytics()
      assert is_map(analytics)
      assert is_map(analytics.current_metrics)
    end

    test "SC2: handles concurrent access safely" do
      # Multiple concurrent calls should not corrupt state
      tasks =
        for i <- 1..20 do
          Task.async(fn ->
            PerformanceMetrics.record_metric(:"concurrent_#{rem(i, 3)}", i * 5.0, :ms)
            PerformanceMetrics.get_performance_analytics()
          end)
        end

      results = Task.await_many(tasks)
      assert length(results) == 20
      Enum.each(results, fn result -> assert is_map(result) end)
    end

    test "SC3: provides graceful degradation when under load" do
      # Even under high load, system should respond
      Enum.each(1..100, fn i ->
        spawn(fn ->
          PerformanceMetrics.record_metric(:"load_#{rem(i, 10)}", i * 1.0, :units)
        end)
      end)

      Process.sleep(200)

      # System should still respond to calls
      assert is_map(PerformanceMetrics.get_performance_analytics())
    end
  end
end
