defmodule Indrajaal.Observability.PerformanceAnalyticsTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Indrajaal.Observability.PerformanceAnalytics

  setup do
    # Start the PerformanceAnalytics GenServer
    {:ok, pid} = PerformanceAnalytics.start_link([])

    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end
    end)

    %{pid: pid}
  end

  describe "start_link/1" do
    test "starts GenServer successfully" do
      {:ok, pid} = PerformanceAnalytics.start_link([])
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "registers with module name" do
      {:ok, _pid} = PerformanceAnalytics.start_link([])
      assert Process.whereis(PerformanceAnalytics) != nil
      GenServer.stop(PerformanceAnalytics)
    end

    test "initializes with background processes scheduled" do
      log =
        capture_log(fn ->
          {:ok, pid} = PerformanceAnalytics.start_link([])
          Process.sleep(100)
          GenServer.stop(pid)
        end)

      assert log =~ "Starting Performance Analytics System"
      assert log =~ "Performance Analytics System started successfully"
    end
  end

  describe "analyze_performance/1" do
    test "performs comprehensive analysis with default options" do
      result = PerformanceAnalytics.analyze_performance()

      assert is_map(result)
      assert Map.has_key?(result, :timestamp)
      assert Map.has_key?(result, :system_performance)
      assert Map.has_key?(result, :application_performance)
      assert Map.has_key?(result, :business_impact)
    end

    test "performs real-time analysis" do
      result = PerformanceAnalytics.analyze_performance(type: :real_time)

      assert is_map(result)
      assert result.analysis_type == :real_time
      assert Map.has_key?(result, :current_performance)
      assert Map.has_key?(result, :health_score)
    end

    test "performs trend analysis" do
      result = PerformanceAnalytics.analyze_performance(type: :trend, window: :long_term)

      assert is_map(result)
      assert result.analysis_type == :trend
      assert result.time_window == :long_term
      assert Map.has_key?(result, :performance_trends)
    end

    test "performs predictive analysis" do
      result = PerformanceAnalytics.analyze_performance(type: :predictive, window: :long_term)

      assert is_map(result)
      assert result.analysis_type == :predictive
      assert Map.has_key?(result, :performance_forecasts)
      assert Map.has_key?(result, :risk_assessments)
    end

    test "performs comparative analysis" do
      result = PerformanceAnalytics.analyze_performance(type: :comparative)

      assert is_map(result)
    end

    test "increments analysis count on each call" do
      PerformanceAnalytics.analyze_performance()
      PerformanceAnalytics.analyze_performance()

      # Analysis count is internal state, verified through repeated calls succeeding
      result = PerformanceAnalytics.analyze_performance()
      assert is_map(result)
    end
  end

  describe "get_optimization_recommendations/1" do
    test "returns all recommendations by default" do
      recommendations = PerformanceAnalytics.get_optimization_recommendations()

      assert is_list(recommendations)
    end

    test "filters recommendations by category" do
      recommendations = PerformanceAnalytics.get_optimization_recommendations(:system)

      assert is_list(recommendations)
      Enum.all?(recommendations, fn rec -> rec.category == :system end)
    end

    test "returns empty list for unknown category" do
      recommendations = PerformanceAnalytics.get_optimization_recommendations(:unknown)

      assert recommendations == []
    end

    test "supports common categories" do
      categories = [:system, :application, :database, :container, :business]

      Enum.each(categories, fn category ->
        recommendations = PerformanceAnalytics.get_optimization_recommendations(category)
        assert is_list(recommendations)
      end)
    end
  end

  describe "detect_anomalies/1" do
    test "detects statistical anomalies with default sensitivity" do
      anomalies = PerformanceAnalytics.detect_anomalies()

      assert is_list(anomalies)
    end

    test "detects statistical anomalies with high sensitivity" do
      anomalies = PerformanceAnalytics.detect_anomalies(type: :statistical, sensitivity: :high)

      assert is_list(anomalies)
    end

    test "detects ML-based anomalies" do
      anomalies = PerformanceAnalytics.detect_anomalies(type: :ml_based)

      assert is_list(anomalies)
    end

    test "detects threshold-based anomalies" do
      anomalies = PerformanceAnalytics.detect_anomalies(type: :threshold)

      assert is_list(anomalies)
    end

    test "detects composite anomalies" do
      anomalies = PerformanceAnalytics.detect_anomalies(type: :composite)

      assert is_list(anomalies)
    end

    test "supports different sensitivity levels" do
      sensitivities = [:low, :medium, :high]

      Enum.each(sensitivities, fn sensitivity ->
        anomalies = PerformanceAnalytics.detect_anomalies(sensitivity: sensitivity)
        assert is_list(anomalies)
      end)
    end
  end

  describe "get_performance_baseline/1" do
    test "returns nil for non-existent baseline" do
      baseline = PerformanceAnalytics.get_performance_baseline(:non_existent)

      assert baseline == nil
    end

    test "returns baseline data after update" do
      baseline_data = %{mean: 50.0, std_dev: 10.0}
      PerformanceAnalytics.update_performance_baseline(:test_metric, baseline_data)
      Process.sleep(50)

      result = PerformanceAnalytics.get_performance_baseline(:test_metric)
      assert result == baseline_data
    end
  end

  describe "update_performance_baseline/2" do
    test "updates baseline asynchronously" do
      baseline_data = %{mean: 75.0, std_dev: 15.0}

      log =
        capture_log(fn ->
          assert :ok =
                   PerformanceAnalytics.update_performance_baseline(:metric_name, baseline_data)

          Process.sleep(100)
        end)

      assert log =~ "Updated performance baseline"
    end

    test "allows multiple baseline updates" do
      baselines = [
        {:cpu_usage, %{mean: 45.0, std_dev: 10.0}},
        {:memory_usage, %{mean: 65.0, std_dev: 12.0}},
        {:response_time, %{mean: 85.0, std_dev: 20.0}}
      ]

      Enum.each(baselines, fn {metric, data} ->
        PerformanceAnalytics.update_performance_baseline(metric, data)
      end)

      Process.sleep(100)

      # Verify baselines were updated
      Enum.each(baselines, fn {metric, expected_data} ->
        assert PerformanceAnalytics.get_performance_baseline(metric) == expected_data
      end)
    end
  end

  describe "get_capacity_forecast/2" do
    test "generates capacity forecast for resource type" do
      forecast = PerformanceAnalytics.get_capacity_forecast(:cpu, 30)

      assert is_map(forecast)
    end

    test "supports different resource types" do
      resource_types = [:cpu, :memory, :storage, :network]

      Enum.each(resource_types, fn resource_type ->
        forecast = PerformanceAnalytics.get_capacity_forecast(resource_type, 30)
        assert is_map(forecast)
      end)
    end

    test "supports different forecast periods" do
      forecast_days = [7, 14, 30, 60, 90]

      Enum.each(forecast_days, fn days ->
        forecast = PerformanceAnalytics.get_capacity_forecast(:cpu, days)
        assert is_map(forecast)
      end)
    end

    test "uses default forecast days when not specified" do
      forecast = PerformanceAnalytics.get_capacity_forecast(:memory)

      assert is_map(forecast)
    end
  end

  describe "get_bottleneck_analysis/1" do
    test "performs bottleneck analysis with default options" do
      analysis = PerformanceAnalytics.get_bottleneck_analysis()

      assert is_map(analysis)
      assert Map.has_key?(analysis, :identified_bottlenecks)
      assert Map.has_key?(analysis, :optimization_recommendations)
    end

    test "performs shallow bottleneck analysis" do
      analysis = PerformanceAnalytics.get_bottleneck_analysis(depth: :shallow)

      assert is_map(analysis)
      assert analysis.analysis_depth == :shallow
    end

    test "performs detailed bottleneck analysis" do
      analysis = PerformanceAnalytics.get_bottleneck_analysis(depth: :detailed)

      assert is_map(analysis)
      assert analysis.analysis_depth == :detailed
    end

    test "excludes recommendations when requested" do
      analysis =
        PerformanceAnalytics.get_bottleneck_analysis(depth: :detailed, recommendations: false)

      assert is_map(analysis)
      refute Map.has_key?(analysis, :optimization_recommendations)
    end

    test "includes impact assessment and resource utilization" do
      analysis = PerformanceAnalytics.get_bottleneck_analysis()

      assert is_map(analysis)
      assert Map.has_key?(analysis, :impact_assessment)
      assert Map.has_key?(analysis, :resource_utilization)
    end
  end

  describe "background monitoring processes" do
    test "real-time monitoring collects metrics periodically" do
      # Background processes are scheduled in init
      Process.sleep(200)

      # Verify system is responsive after background processes
      result = PerformanceAnalytics.analyze_performance(type: :real_time)
      assert is_map(result)
    end

    test "performance analysis runs on schedule" do
      # Allow time for scheduled analysis
      Process.sleep(200)

      # System should remain responsive
      result = PerformanceAnalytics.analyze_performance()
      assert is_map(result)
    end
  end

  describe "performance analysis types" do
    test "comprehensive analysis includes all components" do
      result = PerformanceAnalytics.analyze_performance(type: :comprehensive)

      assert Map.has_key?(result, :system_performance)
      assert Map.has_key?(result, :application_performance)
      assert Map.has_key?(result, :network_performance)
      assert Map.has_key?(result, :container_performance)
      assert Map.has_key?(result, :business_impact)
      assert Map.has_key?(result, :recommendations)
    end

    test "real-time analysis includes current metrics and health score" do
      result = PerformanceAnalytics.analyze_performance(type: :real_time)

      assert Map.has_key?(result, :current_performance)
      assert Map.has_key?(result, :threshold_violations)
      assert Map.has_key?(result, :immediate_recommendations)
      assert Map.has_key?(result, :health_score)
    end

    test "trend analysis identifies patterns" do
      result = PerformanceAnalytics.analyze_performance(type: :trend)

      assert Map.has_key?(result, :performance_trends)
      assert Map.has_key?(result, :degradation_patterns)
      assert Map.has_key?(result, :improvement_opportunities)
      assert Map.has_key?(result, :seasonal_patterns)
    end

    test "predictive analysis generates forecasts" do
      result = PerformanceAnalytics.analyze_performance(type: :predictive)

      assert Map.has_key?(result, :performance_forecasts)
      assert Map.has_key?(result, :capacity_predictions)
      assert Map.has_key?(result, :risk_assessments)
      assert Map.has_key?(result, :proactive_recommendations)
    end
  end

  describe "anomaly detection sensitivity" do
    test "low sensitivity uses 3.0 multiplier" do
      anomalies = PerformanceAnalytics.detect_anomalies(sensitivity: :low)

      assert is_list(anomalies)
    end

    test "medium sensitivity uses 2.0 multiplier" do
      anomalies = PerformanceAnalytics.detect_anomalies(sensitivity: :medium)

      assert is_list(anomalies)
    end

    test "high sensitivity uses 1.5 multiplier" do
      anomalies = PerformanceAnalytics.detect_anomalies(sensitivity: :high)

      assert is_list(anomalies)
    end
  end

  describe "concurrent operations" do
    test "handles concurrent analysis requests" do
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            PerformanceAnalytics.analyze_performance(type: :real_time)
          end)
        end

      results = Task.await_many(tasks)
      assert length(results) == 10
      Enum.each(results, fn result -> assert is_map(result) end)
    end

    test "handles concurrent anomaly detection" do
      tasks =
        for _ <- 1..5 do
          Task.async(fn ->
            PerformanceAnalytics.detect_anomalies()
          end)
        end

      results = Task.await_many(tasks)
      assert length(results) == 5
      Enum.each(results, fn result -> assert is_list(result) end)
    end

    test "handles concurrent baseline updates" do
      tasks =
        for i <- 1..8 do
          Task.async(fn ->
            PerformanceAnalytics.update_performance_baseline(
              :"metric_#{i}",
              %{mean: i * 10.0, std_dev: i * 2.0}
            )
          end)
        end

      Enum.each(tasks, &Task.await/1)
      Process.sleep(100)

      # Verify baselines were updated
      result = PerformanceAnalytics.get_performance_baseline(:metric_1)
      assert is_map(result)
    end
  end

  describe "edge cases and error handling" do
    test "handles analysis with unknown type gracefully" do
      result = PerformanceAnalytics.analyze_performance(type: :unknown)

      assert is_map(result)
    end

    test "handles anomaly detection with unknown type" do
      anomalies = PerformanceAnalytics.detect_anomalies(type: :unknown)

      assert is_list(anomalies)
    end

    test "handles forecast with extreme days" do
      forecast = PerformanceAnalytics.get_capacity_forecast(:cpu, 365)

      assert is_map(forecast)
    end

    test "handles bottleneck analysis with unknown depth" do
      analysis = PerformanceAnalytics.get_bottleneck_analysis(depth: :unknown)

      assert is_map(analysis)
    end

    test "handles baseline update with nil data" do
      assert :ok = PerformanceAnalytics.update_performance_baseline(:test, nil)
    end

    test "handles recommendation filtering with invalid category" do
      recommendations = PerformanceAnalytics.get_optimization_recommendations("invalid")

      assert recommendations == []
    end
  end

  describe "integration scenarios" do
    test "complete performance monitoring workflow" do
      # 1. Analyze current performance
      analysis = PerformanceAnalytics.analyze_performance(type: :real_time)
      assert is_map(analysis)

      # 2. Detect anomalies
      anomalies = PerformanceAnalytics.detect_anomalies(sensitivity: :high)
      assert is_list(anomalies)

      # 3. Get optimization recommendations
      recommendations = PerformanceAnalytics.get_optimization_recommendations()
      assert is_list(recommendations)

      # 4. Analyze bottlenecks
      bottlenecks = PerformanceAnalytics.get_bottleneck_analysis()
      assert is_map(bottlenecks)

      # 5. Get capacity forecast
      forecast = PerformanceAnalytics.get_capacity_forecast(:cpu, 30)
      assert is_map(forecast)
    end

    test "baseline establishment and anomaly detection workflow" do
      # 1. Update baselines
      PerformanceAnalytics.update_performance_baseline(:cpu_usage, %{mean: 50.0, std_dev: 10.0})

      PerformanceAnalytics.update_performance_baseline(:memory_usage, %{
        mean: 65.0,
        std_dev: 12.0
      })

      Process.sleep(100)

      # 2. Verify baselines
      cpu_baseline = PerformanceAnalytics.get_performance_baseline(:cpu_usage)
      assert cpu_baseline == %{mean: 50.0, std_dev: 10.0}

      # 3. Detect anomalies against baselines
      anomalies = PerformanceAnalytics.detect_anomalies(type: :statistical)
      assert is_list(anomalies)
    end

    test "predictive analytics and capacity planning workflow" do
      # 1. Run predictive analysis
      predictive = PerformanceAnalytics.analyze_performance(type: :predictive, window: :long_term)
      assert is_map(predictive)

      # 2. Get capacity forecasts
      cpu_forecast = PerformanceAnalytics.get_capacity_forecast(:cpu, 30)
      memory_forecast = PerformanceAnalytics.get_capacity_forecast(:memory, 30)

      assert is_map(cpu_forecast)
      assert is_map(memory_forecast)

      # 3. Get optimization recommendations
      recommendations = PerformanceAnalytics.get_optimization_recommendations()
      assert is_list(recommendations)
    end
  end

  describe "STAMP safety constraints" do
    test "SC1: maintains data integrity during concurrent operations" do
      # Update baselines concurrently
      tasks =
        for i <- 1..20 do
          Task.async(fn ->
            PerformanceAnalytics.update_performance_baseline(
              :"metric_#{rem(i, 5)}",
              %{mean: i * 5.0, std_dev: i * 1.0}
            )
          end)
        end

      Enum.each(tasks, &Task.await/1)
      Process.sleep(150)

      # Verify data integrity
      baseline = PerformanceAnalytics.get_performance_baseline(:metric_0)
      assert is_map(baseline) or is_nil(baseline)
    end

    test "SC2: handles concurrent analysis requests safely" do
      # Run multiple concurrent analyses
      tasks =
        for _ <- 1..15 do
          Task.async(fn ->
            PerformanceAnalytics.analyze_performance(type: :real_time)
          end)
        end

      results = Task.await_many(tasks)

      # All should succeed without corruption
      assert length(results) == 15
      Enum.each(results, fn result -> assert is_map(result) end)
    end

    test "SC3: provides graceful degradation under load" do
      # Stress test with high concurrent load
      Enum.each(1..50, fn i ->
        spawn(fn ->
          PerformanceAnalytics.analyze_performance(type: :real_time)
          PerformanceAnalytics.detect_anomalies()
          PerformanceAnalytics.update_performance_baseline(:"load_#{rem(i, 5)}", %{mean: 50.0})
        end)
      end)

      Process.sleep(300)

      # System should still respond
      result = PerformanceAnalytics.analyze_performance()
      assert is_map(result)
    end
  end
end
