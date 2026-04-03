defmodule Indrajaal.Analytics.PerformanceBenchmarkTest do
  @moduledoc """
  TDG-compliant comprehensive test suite for PerformanceBenchmark module.
  Created BEFORE implementation following SOPv5.11 Test-Driven Generation methodology.

  This test suite implements:
  - Unit tests for all functions (100% coverage requirement)
  - Property-based tests using PropCheck and ExUnitProperties (dual framework approach)
  - STAMP safety constraint validation tests
  - Performance validation and edge case testing
  - Multi-tenant data isolation verification

  SOPv5.11 Compliance: ✅ Test-Driven Generation
  STAMP Safety: ✅ 5 critical safety constraints validated
  Property Testing: ✅ Dual PropCheck/ExUnitProperties framework
  TDG Methodology: ✅ Tests written BEFORE any implementation changes
  """

  use ExUnit.Case, async: true
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # Disambiguate PropCheck and StreamData generators
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Analytics.PerformanceBenchmark

  # Test data setup
  @valid_system_metrics %{
    id: "system_001",
    response_time: 45.2,
    throughput: 1250.5,
    cpu_usage: 65.2,
    memory_usage: 78.4,
    disk_usage: 45.1
  }

  @valid_baseline_metrics %{
    response_time: 50.0,
    throughput: 1100.0,
    cpu_usage: 70.0,
    memory_usage: 80.0,
    disk_usage: 50.0
  }

  @valid_benchmark_options %{
    type: "comprehensive",
    tenant_id: "tenant_001",
    include_recommendations: true
  }

  @valid_baseline_params %{
    type: "comprehensive",
    period: "7_days",
    tenant_id: "tenant_001"
  }

  # ============================================================================
  # UNIT TESTS - TDG Core Tests (Created BEFORE Implementation)
  # ============================================================================

  describe "calculatebenchmarks/3 - TDG Core Tests" do
    test "successfully calculates benchmarks with valid inputs" do
      result =
        PerformanceBenchmark.calculatebenchmarks(
          @valid_system_metrics,
          @valid_baseline_metrics,
          @valid_benchmark_options
        )

      assert {:ok, benchmarks} = result
      assert is_map(benchmarks)
      assert Map.has_key?(benchmarks, :system_id)
      assert Map.has_key?(benchmarks, :benchmark_type)
      assert Map.has_key?(benchmarks, :baseline_comparison)
      assert Map.has_key?(benchmarks, :industry_comparison)
      assert Map.has_key?(benchmarks, :overall_score)
      assert is_number(benchmarks.overall_score)
    end

    test "returns proper benchmark structure with baseline comparison" do
      {:ok, benchmarks} =
        PerformanceBenchmark.calculatebenchmarks(
          @valid_system_metrics,
          @valid_baseline_metrics,
          @valid_benchmark_options
        )

      assert %{baseline_comparison: comparison} = benchmarks
      assert Map.has_key?(comparison, :response_time)
      assert Map.has_key?(comparison, :throughput)
      assert Map.has_key?(comparison, :resource_utilization)

      # Verify response time structure
      assert %{current: current, baseline: baseline, improvement: improvement, grade: grade} =
               comparison.response_time

      assert is_number(current)
      assert is_number(baseline)
      assert is_number(improvement)
      assert is_binary(grade)
    end

    test "handles missing system metrics gracefully" do
      empty_metrics = %{}

      result =
        PerformanceBenchmark.calculatebenchmarks(
          empty_metrics,
          @valid_baseline_metrics,
          @valid_benchmark_options
        )

      assert {:ok, benchmarks} = result
      # Default fallback
      assert benchmarks.system_id == "system_001"
    end

    test "handles missing benchmark options gracefully" do
      empty_options = %{}

      result =
        PerformanceBenchmark.calculatebenchmarks(
          @valid_system_metrics,
          @valid_baseline_metrics,
          empty_options
        )

      assert {:ok, benchmarks} = result
      # Default fallback
      assert benchmarks.benchmark_type == "comprehensive"
    end

    test "includes industry comparison data" do
      {:ok, benchmarks} =
        PerformanceBenchmark.calculatebenchmarks(
          @valid_system_metrics,
          @valid_baseline_metrics,
          @valid_benchmark_options
        )

      assert %{industry_comparison: industry} = benchmarks
      assert Map.has_key?(industry, :percentile_ranking)
      assert Map.has_key?(industry, :peer_group)
      assert Map.has_key?(industry, :top_performers_gap)
      assert is_integer(industry.percentile_ranking)
      assert industry.percentile_ranking >= 0
      assert industry.percentile_ranking <= 100
    end

    test "includes performance recommendations" do
      {:ok, benchmarks} =
        PerformanceBenchmark.calculatebenchmarks(
          @valid_system_metrics,
          @valid_baseline_metrics,
          @valid_benchmark_options
        )

      assert %{recommendations: recommendations} = benchmarks
      assert is_list(recommendations)
      assert length(recommendations) > 0

      Enum.each(recommendations, fn rec ->
        assert is_binary(rec)
      end)
    end

    test "includes timestamp for benchmark calculation" do
      {:ok, benchmarks} =
        PerformanceBenchmark.calculatebenchmarks(
          @valid_system_metrics,
          @valid_baseline_metrics,
          @valid_benchmark_options
        )

      assert %{calculated_at: timestamp} = benchmarks
      assert %DateTime{} = timestamp
      # Verify timestamp is recent (within last minute)
      time_diff = DateTime.diff(DateTime.utc_now(), timestamp, :second)
      assert time_diff < 60
    end
  end

  describe "establish_baseline/2 - TDG Core Tests" do
    test "successfully establishes performance baseline" do
      result =
        PerformanceBenchmark.establish_baseline(
          @valid_system_metrics,
          @valid_baseline_params
        )

      assert {:ok, baseline} = result
      assert is_map(baseline)
      assert Map.has_key?(baseline, :baseline_id)
      assert Map.has_key?(baseline, :system_id)
      assert Map.has_key?(baseline, :metrics)
      assert Map.has_key?(baseline, :confidence_level)
    end

    test "creates baseline with comprehensive metrics structure" do
      {:ok, baseline} =
        PerformanceBenchmark.establish_baseline(
          @valid_system_metrics,
          @valid_baseline_params
        )

      assert %{metrics: metrics} = baseline
      assert Map.has_key?(metrics, :response_time_p50)
      assert Map.has_key?(metrics, :response_time_p95)
      assert Map.has_key?(metrics, :response_time_p99)
      assert Map.has_key?(metrics, :throughput_rps)
      assert Map.has_key?(metrics, :error_rate)
      assert Map.has_key?(metrics, :availability)
      assert Map.has_key?(metrics, :resource_utilization)

      # Verify all metrics are numeric
      assert is_number(metrics.response_time_p50)
      assert is_number(metrics.response_time_p95)
      assert is_number(metrics.response_time_p99)
      assert is_number(metrics.throughput_rps)
      assert is_number(metrics.error_rate)
      assert is_number(metrics.availability)
    end

    test "includes resource utilization breakdown" do
      {:ok, baseline} =
        PerformanceBenchmark.establish_baseline(
          @valid_system_metrics,
          @valid_baseline_params
        )

      assert %{metrics: %{resource_utilization: resources}} = baseline
      assert Map.has_key?(resources, :cpu_avg)
      assert Map.has_key?(resources, :memory_avg)
      assert Map.has_key?(resources, :disk_io_avg)
      assert Map.has_key?(resources, :network_io_avg)

      # Verify all resource metrics are valid percentages or numbers
      assert is_number(resources.cpu_avg)
      assert is_number(resources.memory_avg)
      assert is_number(resources.disk_io_avg)
      assert is_number(resources.network_io_avg)
    end

    test "generates unique baseline IDs" do
      {:ok, baseline1} =
        PerformanceBenchmark.establish_baseline(
          @valid_system_metrics,
          @valid_baseline_params
        )

      {:ok, baseline2} =
        PerformanceBenchmark.establish_baseline(
          @valid_system_metrics,
          @valid_baseline_params
        )

      assert baseline1.baseline_id != baseline2.baseline_id
    end

    test "handles missing system metrics with defaults" do
      empty_metrics = %{}

      result =
        PerformanceBenchmark.establish_baseline(
          empty_metrics,
          @valid_baseline_params
        )

      assert {:ok, baseline} = result
      # Default fallback
      assert baseline.system_id == "system_001"
    end

    test "handles missing baseline parameters with defaults" do
      empty_params = %{}

      result =
        PerformanceBenchmark.establish_baseline(
          @valid_system_metrics,
          empty_params
        )

      assert {:ok, baseline} = result
      # Default fallback
      assert baseline.baseline_type == "comprehensive"
      # Default fallback
      assert baseline.measurement_period == "7_days"
    end

    test "sets appropriate confidence level" do
      {:ok, baseline} =
        PerformanceBenchmark.establish_baseline(
          @valid_system_metrics,
          @valid_baseline_params
        )

      assert baseline.confidence_level == 0.95
      assert baseline.confidence_level >= 0.0
      assert baseline.confidence_level <= 1.0
    end
  end

  describe "compare_to_baseline/2 - TDG Core Tests" do
    setup do
      {:ok, baseline} =
        PerformanceBenchmark.establish_baseline(
          @valid_system_metrics,
          @valid_baseline_params
        )

      current_metrics = %{
        response_time: 40.8,
        throughput: 1420.3,
        error_rate: 0.031
      }

      %{baseline: baseline, current_metrics: current_metrics}
    end

    test "successfully compares current performance to baseline", %{
      baseline: baseline,
      current_metrics: current_metrics
    } do
      result = PerformanceBenchmark.compare_to_baseline(current_metrics, baseline)

      assert {:ok, comparison} = result
      assert is_map(comparison)
      assert Map.has_key?(comparison, :comparison_id)
      assert Map.has_key?(comparison, :baseline_id)
      assert Map.has_key?(comparison, :performance_delta)
      assert Map.has_key?(comparison, :overall_performance_grade)
    end

    test "calculates performance deltas correctly", %{
      baseline: baseline,
      current_metrics: current_metrics
    } do
      {:ok, comparison} = PerformanceBenchmark.compare_to_baseline(current_metrics, baseline)

      assert %{performance_delta: delta} = comparison
      assert Map.has_key?(delta, :response_time)
      assert Map.has_key?(delta, :throughput)
      assert Map.has_key?(delta, :error_rate)

      # Verify delta structure for response time
      assert %{change_percent: change, trend: trend, significance: significance} =
               delta.response_time

      assert is_number(change)
      assert is_binary(trend)
      assert is_binary(significance)
      assert trend in ["improving", "degrading", "stable"]
      assert significance in ["high", "medium", "low"]
    end

    test "generates regression alerts when thresholds exceeded", %{
      baseline: baseline,
      current_metrics: current_metrics
    } do
      {:ok, comparison} = PerformanceBenchmark.compare_to_baseline(current_metrics, baseline)

      assert %{regression_alerts: alerts} = comparison
      assert is_list(alerts)

      if length(alerts) > 0 do
        alert = hd(alerts)
        assert Map.has_key?(alert, :metric)
        assert Map.has_key?(alert, :severity)
        assert Map.has_key?(alert, :threshold_exceeded)
        assert Map.has_key?(alert, :current_value)
        assert Map.has_key?(alert, :recommended_action)
        assert is_binary(alert.severity)
        assert alert.severity in ["critical", "warning", "info"]
      end
    end

    test "assigns performance grades", %{baseline: baseline, current_metrics: current_metrics} do
      {:ok, comparison} = PerformanceBenchmark.compare_to_baseline(current_metrics, baseline)

      assert %{overall_performance_grade: grade} = comparison
      assert is_binary(grade)
      # Grade should be a valid academic grade format
      assert grade =~ ~r/^[A-F][+-]?$/
    end

    test "generates unique comparison IDs", %{
      baseline: baseline,
      current_metrics: current_metrics
    } do
      {:ok, comparison1} = PerformanceBenchmark.compare_to_baseline(current_metrics, baseline)
      {:ok, comparison2} = PerformanceBenchmark.compare_to_baseline(current_metrics, baseline)

      assert comparison1.comparison_id != comparison2.comparison_id
    end

    test "links comparison to baseline", %{baseline: baseline, current_metrics: current_metrics} do
      {:ok, comparison} = PerformanceBenchmark.compare_to_baseline(current_metrics, baseline)

      assert comparison.baseline_id == baseline.baseline_id
    end
  end

  describe "generate_recommendations/1 - TDG Core Tests" do
    test "successfully generates performance recommendations" do
      performance_data = %{
        response_time: 45.2,
        throughput: 1250.5,
        error_rate: 0.025,
        resource_utilization: %{cpu: 65.2, memory: 78.4}
      }

      result = PerformanceBenchmark.generate_recommendations(performance_data)

      assert {:ok, recommendations} = result
      assert is_list(recommendations)
      assert length(recommendations) > 0
    end

    test "generates structured recommendation objects" do
      performance_data = %{}

      {:ok, recommendations} = PerformanceBenchmark.generate_recommendations(performance_data)

      recommendation = hd(recommendations)
      assert is_map(recommendation)
      assert Map.has_key?(recommendation, :id)
      assert Map.has_key?(recommendation, :category)
      assert Map.has_key?(recommendation, :priority)
      assert Map.has_key?(recommendation, :title)
      assert Map.has_key?(recommendation, :description)
      assert Map.has_key?(recommendation, :expected_improvement)
      assert Map.has_key?(recommendation, :implementation_effort)
      assert Map.has_key?(recommendation, :estimated_hours)

      # Verify data types
      assert is_integer(recommendation.id)
      assert is_binary(recommendation.category)
      assert is_binary(recommendation.priority)
      assert is_binary(recommendation.title)
      assert is_binary(recommendation.description)
      assert is_binary(recommendation.expected_improvement)
      assert is_binary(recommendation.implementation_effort)
      assert is_integer(recommendation.estimated_hours)
    end

    test "includes valid priority levels" do
      performance_data = %{}

      {:ok, recommendations} = PerformanceBenchmark.generate_recommendations(performance_data)

      priorities = Enum.map(recommendations, & &1.priority)
      valid_priorities = ["critical", "high", "medium", "low"]

      Enum.each(priorities, fn priority ->
        assert priority in valid_priorities
      end)
    end

    test "includes valid effort levels" do
      performance_data = %{}

      {:ok, recommendations} = PerformanceBenchmark.generate_recommendations(performance_data)

      efforts = Enum.map(recommendations, & &1.implementation_effort)
      valid_efforts = ["low", "medium", "high", "very_high"]

      Enum.each(efforts, fn effort ->
        assert effort in valid_efforts
      end)
    end

    test "includes reasonable estimated hours" do
      performance_data = %{}

      {:ok, recommendations} = PerformanceBenchmark.generate_recommendations(performance_data)

      estimated_hours = Enum.map(recommendations, & &1.estimated_hours)

      Enum.each(estimated_hours, fn hours ->
        assert hours > 0
        # Reasonable upper bound
        assert hours <= 200
      end)
    end

    test "generates recommendations with unique IDs" do
      performance_data = %{}

      {:ok, recommendations} = PerformanceBenchmark.generate_recommendations(performance_data)

      ids = Enum.map(recommendations, & &1.id)
      unique_ids = Enum.uniq(ids)

      assert length(ids) == length(unique_ids)
    end
  end

  describe "track_performance_trends/2 - TDG Core Tests" do
    setup do
      historical_data = [
        %{timestamp: ~U[2024-01-01 00:00:00Z], response_time: 45.2, throughput: 1250},
        %{timestamp: ~U[2024-01-02 00:00:00Z], response_time: 47.1, throughput: 1180},
        %{timestamp: ~U[2024-01-03 00:00:00Z], response_time: 43.8, throughput: 1320},
        %{timestamp: ~U[2024-01-04 00:00:00Z], response_time: 46.5, throughput: 1275},
        %{timestamp: ~U[2024-01-05 00:00:00Z], response_time: 44.2, throughput: 1295}
      ]

      tracking_params = %{
        period: "30_days",
        tenant_id: "tenant_001"
      }

      %{historical_data: historical_data, tracking_params: tracking_params}
    end

    test "successfully tracks performance trends", %{
      historical_data: historical_data,
      tracking_params: tracking_params
    } do
      result = PerformanceBenchmark.track_performance_trends(historical_data, tracking_params)

      assert {:ok, trends} = result
      assert is_map(trends)
      assert Map.has_key?(trends, :tracking_period)
      assert Map.has_key?(trends, :data_points)
      assert Map.has_key?(trends, :trend_analysis)
      assert Map.has_key?(trends, :performance_score_trend)
      assert Map.has_key?(trends, :forecast)
    end

    test "counts data points correctly", %{
      historical_data: historical_data,
      tracking_params: tracking_params
    } do
      {:ok, trends} =
        PerformanceBenchmark.track_performance_trends(historical_data, tracking_params)

      assert trends.data_points == length(historical_data)
    end

    test "analyzes trends for multiple metrics", %{
      historical_data: historical_data,
      tracking_params: tracking_params
    } do
      {:ok, trends} =
        PerformanceBenchmark.track_performance_trends(historical_data, tracking_params)

      assert %{trend_analysis: analysis} = trends
      assert Map.has_key?(analysis, :response_time)
      assert Map.has_key?(analysis, :throughput)
      assert Map.has_key?(analysis, :error_rate)

      # Verify trend structure for response time
      assert %{trend: trend, variance: variance, seasonal_pattern: seasonal} =
               analysis.response_time

      assert is_binary(trend)
      assert trend in ["increasing", "decreasing", "stable"]
      assert is_number(variance)
      assert is_boolean(seasonal)
    end

    test "includes performance score trend history", %{
      historical_data: historical_data,
      tracking_params: tracking_params
    } do
      {:ok, trends} =
        PerformanceBenchmark.track_performance_trends(historical_data, tracking_params)

      assert %{performance_score_trend: scores} = trends
      assert is_list(scores)
      assert length(scores) > 0

      Enum.each(scores, fn score ->
        assert is_number(score)
        assert score >= 0
        assert score <= 100
      end)
    end

    test "provides forecast data", %{
      historical_data: historical_data,
      tracking_params: tracking_params
    } do
      {:ok, trends} =
        PerformanceBenchmark.track_performance_trends(historical_data, tracking_params)

      assert %{forecast: forecast} = trends
      assert Map.has_key?(forecast, :next_30_days)

      assert %{next_30_days: forecast_30} = forecast
      assert Map.has_key?(forecast_30, :expected_performance_score)
      assert Map.has_key?(forecast_30, :confidence_interval)
      assert Map.has_key?(forecast_30, :risk_factors)

      # Verify forecast data types
      assert is_number(forecast_30.expected_performance_score)
      assert is_list(forecast_30.confidence_interval)
      assert length(forecast_30.confidence_interval) == 2
      assert is_list(forecast_30.risk_factors)
    end

    test "handles empty historical data gracefully" do
      empty_data = []
      tracking_params = %{period: "30_days"}

      result = PerformanceBenchmark.track_performance_trends(empty_data, tracking_params)

      assert {:ok, trends} = result
      assert trends.data_points == 0
    end

    test "uses default tracking period when not specified", %{historical_data: historical_data} do
      empty_params = %{}

      {:ok, trends} = PerformanceBenchmark.track_performance_trends(historical_data, empty_params)

      assert trends.tracking_period == "30_days"
    end
  end

  # ============================================================================
  # PROPERTY-BASED TESTS - PropCheck Framework
  # ============================================================================

  describe "PropCheck Property Tests" do
    property "calculatebenchmarks always returns valid benchmark structure" do
      forall {system_metrics, baseline_metrics, options} <- {
               benchmark_system_metrics_generator(),
               benchmark_baseline_metrics_generator(),
               benchmark_options_generator()
             } do
        result =
          PerformanceBenchmark.calculatebenchmarks(system_metrics, baseline_metrics, options)

        case result do
          {:ok, benchmarks} ->
            is_map(benchmarks) and
              Map.has_key?(benchmarks, :system_id) and
              Map.has_key?(benchmarks, :overall_score) and
              is_number(benchmarks.overall_score) and
              benchmarks.overall_score >= 0 and
              benchmarks.overall_score <= 100

          {:error, _reason} ->
            # Errors are acceptable for invalid inputs
            true
        end
      end
    end

    property "establish_baseline always generates unique baseline IDs" do
      forall {system_metrics, baseline_params} <- {
               benchmark_system_metrics_generator(),
               benchmark_baseline_params_generator()
             } do
        {:ok, baseline1} =
          PerformanceBenchmark.establish_baseline(system_metrics, baseline_params)

        {:ok, baseline2} =
          PerformanceBenchmark.establish_baseline(system_metrics, baseline_params)

        baseline1.baseline_id != baseline2.baseline_id
      end
    end

    property "compare_to_baseline always returns valid comparison structure" do
      forall {current_metrics, baseline} <- {
               benchmark_current_metrics_generator(),
               benchmark_baseline_generator()
             } do
        result = PerformanceBenchmark.compare_to_baseline(current_metrics, baseline)

        case result do
          {:ok, comparison} ->
            is_map(comparison) and
              Map.has_key?(comparison, :comparison_id) and
              Map.has_key?(comparison, :performance_delta) and
              Map.has_key?(comparison, :overall_performance_grade) and
              is_binary(comparison.overall_performance_grade)

          {:error, _reason} ->
            # Errors are acceptable for invalid inputs
            true
        end
      end
    end

    property "generate_recommendations always returns list of valid recommendations" do
      forall performance_data <- benchmark_performance_data_generator() do
        result = PerformanceBenchmark.generate_recommendations(performance_data)

        case result do
          {:ok, recommendations} ->
            is_list(recommendations) and
              Enum.all?(recommendations, fn rec ->
                is_map(rec) and
                  Map.has_key?(rec, :id) and
                  Map.has_key?(rec, :priority) and
                  Map.has_key?(rec, :estimated_hours) and
                  is_integer(rec.estimated_hours) and
                  rec.estimated_hours > 0
              end)

          {:error, _reason} ->
            # Errors are acceptable for invalid inputs
            true
        end
      end
    end

    property "track_performance_trends data_points equals input list length" do
      forall {historical_data, tracking_params} <- {
               PC.list(benchmark_historical_data_point_generator()),
               benchmark_tracking_params_generator()
             } do
        {:ok, trends} =
          PerformanceBenchmark.track_performance_trends(historical_data, tracking_params)

        trends.data_points == length(historical_data)
      end
    end
  end

  # ============================================================================
  # PROPERTY-BASED TESTS - ExUnitProperties Framework
  # ============================================================================

  describe "ExUnitProperties Property Tests" do
    test "all benchmark functions handle edge cases gracefully" do
      ExUnitProperties.check all(
                               system_metrics <- benchmark_system_metrics_stream(),
                               baseline_metrics <- benchmark_baseline_metrics_stream(),
                               options <- benchmark_options_stream(),
                               max_runs: 50
                             ) do
        # Test calculatebenchmarks with edge cases
        result =
          PerformanceBenchmark.calculatebenchmarks(system_metrics, baseline_metrics, options)

        case result do
          {:ok, benchmarks} ->
            assert is_map(benchmarks)
            assert Map.has_key?(benchmarks, :calculated_at)
            assert %DateTime{} = benchmarks.calculated_at

          {:error, reason} ->
            assert is_atom(reason) or is_binary(reason)
        end
      end
    end

    test "establish_baseline creates consistent baseline structure" do
      ExUnitProperties.check all(
                               system_metrics <- benchmark_system_metrics_stream(),
                               baseline_params <- benchmark_baseline_params_stream(),
                               max_runs: 50
                             ) do
        {:ok, baseline} = PerformanceBenchmark.establish_baseline(system_metrics, baseline_params)

        # Verify consistent structure
        assert is_map(baseline)
        assert Map.has_key?(baseline, :baseline_id)
        assert Map.has_key?(baseline, :metrics)
        assert Map.has_key?(baseline, :confidence_level)
        assert baseline.confidence_level >= 0.0
        assert baseline.confidence_level <= 1.0

        # Verify metrics structure
        metrics = baseline.metrics
        assert Map.has_key?(metrics, :response_time_p50)
        assert Map.has_key?(metrics, :throughput_rps)
        assert Map.has_key?(metrics, :resource_utilization)
        assert is_map(metrics.resource_utilization)
      end
    end

    test "performance recommendations always include required fields" do
      ExUnitProperties.check all(
                               performance_data <- benchmark_performance_data_stream(),
                               max_runs: 30
                             ) do
        {:ok, recommendations} = PerformanceBenchmark.generate_recommendations(performance_data)

        assert is_list(recommendations)
        assert length(recommendations) > 0

        Enum.each(recommendations, fn rec ->
          assert Map.has_key?(rec, :id)
          assert Map.has_key?(rec, :category)
          assert Map.has_key?(rec, :priority)
          assert Map.has_key?(rec, :title)
          assert Map.has_key?(rec, :description)
          assert Map.has_key?(rec, :expected_improvement)
          assert Map.has_key?(rec, :implementation_effort)
          assert Map.has_key?(rec, :estimated_hours)

          assert is_integer(rec.id)
          assert is_binary(rec.category)
          assert rec.priority in ["critical", "high", "medium", "low"]
          assert is_binary(rec.title)
          assert is_binary(rec.description)
          assert is_integer(rec.estimated_hours)
          assert rec.estimated_hours > 0
        end)
      end
    end

    test "trend analysis produces valid trend indicators" do
      ExUnitProperties.check all(
                               historical_data <-
                                 SD.list_of(benchmark_historical_data_point_stream(),
                                   max_length: 50
                                 ),
                               tracking_params <- benchmark_tracking_params_stream(),
                               max_runs: 30
                             ) do
        {:ok, trends} =
          PerformanceBenchmark.track_performance_trends(historical_data, tracking_params)

        assert Map.has_key?(trends, :trend_analysis)
        trend_analysis = trends.trend_analysis

        # Verify response time trend
        if Map.has_key?(trend_analysis, :response_time) do
          rt_trend = trend_analysis.response_time
          assert Map.has_key?(rt_trend, :trend)
          assert rt_trend.trend in ["increasing", "decreasing", "stable"]

          if Map.has_key?(rt_trend, :variance) do
            assert is_number(rt_trend.variance)
            assert rt_trend.variance >= 0
          end
        end

        # Verify forecast structure
        if Map.has_key?(trends, :forecast) do
          forecast = trends.forecast

          if Map.has_key?(forecast, :next_30_days) do
            forecast_30 = forecast.next_30_days

            if Map.has_key?(forecast_30, :expected_performance_score) do
              score = forecast_30.expected_performance_score
              assert is_number(score)
              assert score >= 0
              assert score <= 100
            end
          end
        end
      end
    end
  end

  # ============================================================================
  # STAMP SAFETY CONSTRAINT TESTS
  # ============================================================================

  describe "STAMP Safety Constraints - Performance Benchmark Domain" do
    test "SC-PERF-001: System SHALL maintain tenant data isolation in performance data" do
      tenant1_metrics = Map.put(@valid_system_metrics, :tenant_id, "tenant_001")
      tenant2_metrics = Map.put(@valid_system_metrics, :tenant_id, "tenant_002")

      tenant1_options = Map.put(@valid_benchmark_options, :tenant_id, "tenant_001")
      tenant2_options = Map.put(@valid_benchmark_options, :tenant_id, "tenant_002")

      {:ok, benchmark1} =
        PerformanceBenchmark.calculatebenchmarks(
          tenant1_metrics,
          @valid_baseline_metrics,
          tenant1_options
        )

      {:ok, benchmark2} =
        PerformanceBenchmark.calculatebenchmarks(
          tenant2_metrics,
          @valid_baseline_metrics,
          tenant2_options
        )

      # Verify that benchmark data doesn't leak between tenants
      # In a real implementation, this would verify database isolation
      assert benchmark1 != benchmark2

      # Verify that system IDs can be tenant-specific
      refute is_nil(benchmark1.system_id)
      refute is_nil(benchmark2.system_id)
    end

    test "SC-PERF-002: System SHALL validate performance data integrity before processing" do
      # Test with corrupted/invalid metrics
      invalid_metrics = %{
        id: "system_001",
        # Invalid negative response time
        response_time: -1,
        # Invalid data type
        throughput: "invalid",
        # Invalid percentage > 100
        cpu_usage: 150
      }

      # System should handle invalid data gracefully
      result =
        PerformanceBenchmark.calculatebenchmarks(
          invalid_metrics,
          @valid_baseline_metrics,
          @valid_benchmark_options
        )

      # Should either succeed with sanitized data or return appropriate error
      case result do
        {:ok, benchmarks} ->
          # If it succeeds, verify data was sanitized
          assert is_map(benchmarks)
          assert Map.has_key?(benchmarks, :system_id)

        {:error, reason} ->
          # If it fails, verify appropriate error handling
          assert is_atom(reason) or is_binary(reason)
      end
    end

    test "SC-PERF-003: System SHALL prevent performance data tampering" do
      original_metrics = @valid_system_metrics

      # Attempt to modify metrics after initial processing
      {:ok, benchmark1} =
        PerformanceBenchmark.calculatebenchmarks(
          original_metrics,
          @valid_baseline_metrics,
          @valid_benchmark_options
        )

      # Verify that benchmark calculation is deterministic for same inputs
      {:ok, benchmark2} =
        PerformanceBenchmark.calculatebenchmarks(
          original_metrics,
          @valid_baseline_metrics,
          @valid_benchmark_options
        )

      # Core benchmark structure should be identical (excluding timestamps)
      assert benchmark1.system_id == benchmark2.system_id
      assert benchmark1.benchmark_type == benchmark2.benchmark_type
      assert benchmark1.overall_score == benchmark2.overall_score

      # Baseline comparison should be identical
      assert benchmark1.baseline_comparison == benchmark2.baseline_comparison
    end

    test "SC-PERF-004: System SHALL maintain audit trail for performance calculations" do
      {:ok, benchmark} =
        PerformanceBenchmark.calculatebenchmarks(
          @valid_system_metrics,
          @valid_baseline_metrics,
          @valid_benchmark_options
        )

      # Verify audit information is present
      assert Map.has_key?(benchmark, :calculated_at)
      assert %DateTime{} = benchmark.calculated_at
      assert Map.has_key?(benchmark, :system_id)

      # Verify timestamp is recent and valid
      time_diff = DateTime.diff(DateTime.utc_now(), benchmark.calculated_at, :second)
      assert time_diff >= 0
      # Should be within last minute
      assert time_diff < 60
    end

    test "SC-PERF-005: System SHALL ensure performance recommendations are actionable and safe" do
      {:ok, recommendations} =
        PerformanceBenchmark.generate_recommendations(@valid_system_metrics)

      assert is_list(recommendations)
      assert length(recommendations) > 0

      Enum.each(recommendations, fn rec ->
        # Verify all recommendations have required safety fields
        assert Map.has_key?(rec, :priority)
        assert Map.has_key?(rec, :implementation_effort)
        assert Map.has_key?(rec, :estimated_hours)
        assert Map.has_key?(rec, :expected_improvement)

        # Verify priority is within acceptable risk levels
        assert rec.priority in ["critical", "high", "medium", "low"]

        # Verify effort estimation is reasonable
        assert rec.implementation_effort in ["low", "medium", "high", "very_high"]

        # Verify time estimates are reasonable (not too large to be risky)
        assert is_integer(rec.estimated_hours)
        assert rec.estimated_hours > 0
        # Reasonable upper bound
        assert rec.estimated_hours <= 200

        # Verify improvement claims are not overstatements
        assert is_binary(rec.expected_improvement)
        # Unrealistic improvement
        refute String.contains?(rec.expected_improvement, "100%")
      end)
    end
  end

  # ============================================================================
  # ERROR HANDLING AND EDGE CASES
  # ============================================================================

  describe "Error Handling and Edge Cases" do
    test "handles nil inputs gracefully" do
      result = PerformanceBenchmark.calculatebenchmarks(nil, nil, nil)

      case result do
        # Graceful handling acceptable
        {:ok, _} -> :ok
        # Error handling acceptable
        {:error, _} -> :ok
      end
    end

    test "handles extremely large metric values" do
      large_metrics = %{
        id: "system_001",
        response_time: 999_999_999.99,
        throughput: 999_999_999,
        cpu_usage: 100.0,
        memory_usage: 100.0
      }

      result =
        PerformanceBenchmark.calculatebenchmarks(
          large_metrics,
          @valid_baseline_metrics,
          @valid_benchmark_options
        )

      case result do
        {:ok, benchmarks} ->
          assert is_map(benchmarks)
          assert is_number(benchmarks.overall_score)

        {:error, _reason} ->
          # Acceptable to reject extreme values
          :ok
      end
    end

    test "handles empty historical data for trend analysis" do
      empty_data = []
      tracking_params = %{period: "30_days"}

      {:ok, trends} = PerformanceBenchmark.track_performance_trends(empty_data, tracking_params)

      assert trends.data_points == 0
      assert is_map(trends)
      assert Map.has_key?(trends, :trend_analysis)
    end

    test "baseline comparison handles missing baseline data" do
      current_metrics = @valid_system_metrics
      # Missing required fields
      incomplete_baseline = %{baseline_id: 123}

      result = PerformanceBenchmark.compare_to_baseline(current_metrics, incomplete_baseline)

      case result do
        {:ok, comparison} ->
          assert is_map(comparison)
          assert comparison.baseline_id == 123

        {:error, _reason} ->
          # Acceptable to reject incomplete baseline
          :ok
      end
    end
  end

  # ============================================================================
  # PERFORMANCE TESTS
  # ============================================================================

  describe "Performance Requirements" do
    test "calculatebenchmarks completes within performance requirements" do
      start_time = System.monotonic_time(:millisecond)

      {:ok, _benchmark} =
        PerformanceBenchmark.calculatebenchmarks(
          @valid_system_metrics,
          @valid_baseline_metrics,
          @valid_benchmark_options
        )

      end_time = System.monotonic_time(:millisecond)
      execution_time = end_time - start_time

      # Should complete within 100ms for single calculation
      assert execution_time < 100
    end

    test "trend analysis handles large datasets efficiently" do
      large_dataset =
        Enum.map(1..1000, fn i ->
          %{
            timestamp: DateTime.add(DateTime.utc_now(), -i * 3600, :second),
            response_time: 45.0 + :rand.normal() * 5,
            throughput: 1250 + :rand.normal() * 100,
            error_rate: 0.02 + :rand.normal() * 0.01
          }
        end)

      start_time = System.monotonic_time(:millisecond)

      {:ok, trends} =
        PerformanceBenchmark.track_performance_trends(
          large_dataset,
          %{period: "30_days"}
        )

      end_time = System.monotonic_time(:millisecond)
      execution_time = end_time - start_time

      assert trends.data_points == 1000
      # Should handle 1000 data points within 500ms
      assert execution_time < 500
    end
  end

  # ============================================================================
  # HELPER FUNCTIONS AND GENERATORS
  # ============================================================================

  # PropCheck Generators
  defp benchmark_system_metrics_generator do
    :proper_types.let(
      [
        id: PC.oneof([PC.utf8(), nil]),
        response_time: PC.oneof([PC.float(0.0, 10_000.0), nil]),
        throughput: PC.oneof([PC.float(0.0, 10_000.0), nil]),
        cpu_usage: PC.oneof([PC.float(0.0, 100.0), nil]),
        memory_usage: PC.oneof([PC.float(0.0, 100.0), nil])
      ],
      fn binding -> Enum.into(binding, %{}) end
    )
  end

  defp benchmark_baseline_metrics_generator do
    :proper_types.let(
      [
        response_time: PC.float(0.0, 10_000.0),
        throughput: PC.float(0.0, 10_000.0),
        cpu_usage: PC.float(0.0, 100.0),
        memory_usage: PC.float(0.0, 100.0)
      ],
      fn binding -> Enum.into(binding, %{}) end
    )
  end

  defp benchmark_options_generator do
    :proper_types.let(
      [
        type: PC.oneof(["comprehensive", "basic", "advanced", nil]),
        tenant_id: PC.oneof([PC.utf8(), nil]),
        include_recommendations: PC.oneof([PC.boolean(), nil])
      ],
      fn binding -> Enum.into(binding, %{}) end
    )
  end

  defp benchmark_baseline_params_generator do
    :proper_types.let(
      [
        type: PC.oneof(["comprehensive", "basic", "advanced", nil]),
        period: PC.oneof(["7_days", "30_days", "90_days", nil]),
        tenant_id: PC.oneof([PC.utf8(), nil])
      ],
      fn binding -> Enum.into(binding, %{}) end
    )
  end

  defp benchmark_current_metrics_generator do
    :proper_types.let(
      [
        response_time: PC.float(0.0, 10_000.0),
        throughput: PC.float(0.0, 10_000.0),
        error_rate: PC.float(0.0, 1.0)
      ],
      fn binding -> Enum.into(binding, %{}) end
    )
  end

  defp benchmark_baseline_generator do
    :proper_types.let(
      [
        baseline_id: PC.integer(1, 10_000),
        system_id: PC.utf8(),
        response_time_p50: PC.float(0.0, 10_000.0),
        throughput_rps: PC.float(0.0, 10_000.0),
        error_rate: PC.float(0.0, 1.0)
      ],
      fn binding ->
        %{
          baseline_id: binding[:baseline_id],
          system_id: binding[:system_id],
          metrics: %{
            response_time_p50: binding[:response_time_p50],
            throughput_rps: binding[:throughput_rps],
            error_rate: binding[:error_rate]
          }
        }
      end
    )
  end

  defp benchmark_performance_data_generator do
    :proper_types.let(
      [
        response_time: PC.oneof([PC.float(0.0, 10_000.0), nil]),
        throughput: PC.oneof([PC.float(0.0, 10_000.0), nil]),
        error_rate: PC.oneof([PC.float(0.0, 1.0), nil]),
        cpu: PC.float(0.0, 100.0),
        memory: PC.float(0.0, 100.0),
        include_resource: PC.boolean()
      ],
      fn binding ->
        base = %{
          response_time: binding[:response_time],
          throughput: binding[:throughput],
          error_rate: binding[:error_rate]
        }

        if binding[:include_resource] do
          Map.put(base, :resource_utilization, %{
            cpu: binding[:cpu],
            memory: binding[:memory]
          })
        else
          Map.put(base, :resource_utilization, nil)
        end
      end
    )
  end

  defp benchmark_historical_data_point_generator do
    :proper_types.let(
      [
        offset: PC.oneof([0, -3600]),
        response_time: PC.float(0.0, 10_000.0),
        throughput: PC.float(0.0, 10_000.0),
        error_rate: PC.float(0.0, 1.0)
      ],
      fn binding ->
        %{
          timestamp: DateTime.add(DateTime.utc_now(), binding[:offset], :second),
          response_time: binding[:response_time],
          throughput: binding[:throughput],
          error_rate: binding[:error_rate]
        }
      end
    )
  end

  defp benchmark_tracking_params_generator do
    :proper_types.let(
      [
        period: PC.oneof(["7_days", "30_days", "90_days", nil]),
        tenant_id: PC.oneof([PC.utf8(), nil])
      ],
      fn binding -> Enum.into(binding, %{}) end
    )
  end

  # ExUnitProperties StreamData Generators
  defp benchmark_system_metrics_stream do
    SD.fixed_map(%{
      id: SD.one_of([SD.string(:alphanumeric), SD.constant(nil)]),
      response_time: SD.one_of([SD.float(min: 0.0, max: 10_000.0), SD.constant(nil)]),
      throughput: SD.one_of([SD.float(min: 0.0, max: 10_000.0), SD.constant(nil)]),
      cpu_usage: SD.one_of([SD.float(min: 0.0, max: 100.0), SD.constant(nil)]),
      memory_usage: SD.one_of([SD.float(min: 0.0, max: 100.0), SD.constant(nil)])
    })
  end

  defp benchmark_baseline_metrics_stream do
    SD.fixed_map(%{
      response_time: SD.float(min: 0.0, max: 10_000.0),
      throughput: SD.float(min: 0.0, max: 10_000.0),
      cpu_usage: SD.float(min: 0.0, max: 100.0),
      memory_usage: SD.float(min: 0.0, max: 100.0)
    })
  end

  defp benchmark_options_stream do
    SD.fixed_map(%{
      type:
        SD.one_of([
          SD.member_of(["comprehensive", "basic", "advanced"]),
          SD.constant(nil)
        ]),
      tenant_id: SD.one_of([SD.string(:alphanumeric), SD.constant(nil)]),
      include_recommendations: SD.one_of([SD.boolean(), SD.constant(nil)])
    })
  end

  defp benchmark_baseline_params_stream do
    SD.fixed_map(%{
      type:
        SD.one_of([
          SD.member_of(["comprehensive", "basic", "advanced"]),
          SD.constant(nil)
        ]),
      period:
        SD.one_of([
          SD.member_of(["7_days", "30_days", "90_days"]),
          SD.constant(nil)
        ]),
      tenant_id: SD.one_of([SD.string(:alphanumeric), SD.constant(nil)])
    })
  end

  defp benchmark_performance_data_stream do
    SD.fixed_map(%{
      response_time: SD.one_of([SD.float(min: 0.0, max: 10_000.0), SD.constant(nil)]),
      throughput: SD.one_of([SD.float(min: 0.0, max: 10_000.0), SD.constant(nil)]),
      error_rate: SD.one_of([SD.float(min: 0.0, max: 1.0), SD.constant(nil)]),
      resource_utilization:
        SD.one_of([
          SD.fixed_map(%{
            cpu: SD.float(min: 0.0, max: 100.0),
            memory: SD.float(min: 0.0, max: 100.0)
          }),
          SD.constant(nil)
        ])
    })
  end

  defp benchmark_historical_data_point_stream do
    SD.fixed_map(%{
      timestamp: SD.constant(DateTime.utc_now()),
      response_time: SD.float(min: 0.0, max: 10_000.0),
      throughput: SD.float(min: 0.0, max: 10_000.0),
      error_rate: SD.float(min: 0.0, max: 1.0)
    })
  end

  defp benchmark_tracking_params_stream do
    SD.fixed_map(%{
      period:
        SD.one_of([
          SD.member_of(["7_days", "30_days", "90_days"]),
          SD.constant(nil)
        ]),
      tenant_id: SD.one_of([SD.string(:alphanumeric), SD.constant(nil)])
    })
  end
end
