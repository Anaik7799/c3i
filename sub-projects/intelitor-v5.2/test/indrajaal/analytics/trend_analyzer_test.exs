defmodule Indrajaal.Analytics.TrendAnalyzerTest do
  @moduledoc """
  TDG-compliant comprehensive test suite for TrendAnalyzer module.
  Created BEFORE implementation following SOPv5.11 Test-Driven Generation methodology.

  Test Coverage Strategy:
  1. Unit Tests: Complete coverage of all 5 main functions
  2. Property-Based Tests: Using both PropCheck and ExUnitProperties
  3. STAMP Safety Constraints: 5 domain-specific safety validations
  4. Performance Tests: Trend analysis performance requirements
  5. Integration Tests: Multi-tenant isolation and data integrity
  6. Edge Cases: Error handling, boundary conditions, invalid inputs
  7. Regression Tests: EP-110/EP-111 prevention patterns
  8. Analytics Domain Tests: Time-series validation, forecasting accuracy

  SOPv5.11 Compliance:
  - TDG Methodology: Tests written BEFORE any implementation changes
  - STAMP Safety: 5 critical trend analysis safety constraints
  - Multi-Agent Coordination: Compatible with 15-agent architecture
  - Container-Native: Fully compatible with container execution
  - Performance Requirements: <10ms per trend analysis, <100ms for forecasting
  """

  use ExUnit.Case, async: true
  # Advanced property testing with sophisticated shrinking
  use PropCheck
  alias StreamData, as: SD
  # StreamData-based property testing
  # # use ExUnitProperties  # Disabled - PropCheck conflict (SC-TDG-002)  # Disabled - PropCheck property/2 conflict
  import StreamData, except: [list: 2]

  # Disambiguate PropCheck generators
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Analytics.TrendAnalyzer

  # Test fixtures and setup data
  @valid_metrics [
    %{timestamp: ~U[2024-01-01 00:00:00Z], value: 100.0, metric: "cpu_usage"},
    %{timestamp: ~U[2024-01-01 01:00:00Z], value: 105.0, metric: "cpu_usage"},
    %{timestamp: ~U[2024-01-01 02:00:00Z], value: 98.0, metric: "cpu_usage"},
    %{timestamp: ~U[2024-01-01 03:00:00Z], value: 102.0, metric: "cpu_usage"},
    %{timestamp: ~U[2024-01-01 04:00:00Z], value: 110.0, metric: "cpu_usage"}
  ]

  @valid_timeperiod %{
    start_time: ~U[2024-01-01 00:00:00Z],
    end_time: ~U[2024-01-01 06:00:00Z],
    granularity: "hourly",
    timezone: "UTC"
  }

  @valid_analysis_options %{
    type: "linear",
    confidence_level: 0.95,
    include_seasonal: true,
    detect_anomalies: true
  }

  @valid_data_points [
    %{x: 1, y: 100.0, timestamp: ~U[2024-01-01 00:00:00Z]},
    %{x: 2, y: 105.0, timestamp: ~U[2024-01-01 01:00:00Z]},
    %{x: 3, y: 98.0, timestamp: ~U[2024-01-01 02:00:00Z]},
    %{x: 4, y: 102.0, timestamp: ~U[2024-01-01 03:00:00Z]},
    %{x: 5, y: 110.0, timestamp: ~U[2024-01-01 04:00:00Z]}
  ]

  @valid_detection_params %{
    threshold: 2.5,
    method: "statistical",
    window_size: 10,
    sensitivity: "medium"
  }

  @valid_forecast_params %{
    model: "linear_regression",
    horizon: 24,
    confidence: 0.95,
    include_seasonality: true
  }

  # ============================================================================
  # 1. UNIT TESTS - Complete Coverage of All Functions
  # ============================================================================

  describe "analyze_metrics_trends/3 - TDG Core Tests" do
    test "successfully analyzes metrics trends with valid inputs" do
      result =
        TrendAnalyzer.analyze_metrics_trends(
          @valid_metrics,
          @valid_timeperiod,
          @valid_analysis_options
        )

      assert {:ok, trend_analysis} = result
      assert is_map(trend_analysis)
      assert trend_analysis.metrics_count == length(@valid_metrics)
      assert trend_analysis.time_period == @valid_timeperiod
      assert is_binary(trend_analysis.trend_direction)
      assert is_float(trend_analysis.confidence_score)
      assert is_list(trend_analysis.predicted_values)
      assert is_integer(trend_analysis.anomalies_detected)
      assert is_map(trend_analysis.seasonal_patterns)
      assert %DateTime{} = trend_analysis.analysis_timestamp
    end

    test "handles empty metrics list" do
      result =
        TrendAnalyzer.analyze_metrics_trends(
          [],
          @valid_timeperiod,
          @valid_analysis_options
        )

      assert {:ok, trend_analysis} = result
      assert trend_analysis.metrics_count == 0
    end

    test "handles different analysis types" do
      analysis_options = %{@valid_analysis_options | type: "exponential"}

      result =
        TrendAnalyzer.analyze_metrics_trends(
          @valid_metrics,
          @valid_timeperiod,
          analysis_options
        )

      assert {:ok, trend_analysis} = result
      assert trend_analysis.analysis_type == "exponential"
    end

    test "defaults analysis type when not provided" do
      result =
        TrendAnalyzer.analyze_metrics_trends(
          @valid_metrics,
          @valid_timeperiod,
          %{}
        )

      assert {:ok, trend_analysis} = result
      assert trend_analysis.analysis_type == "linear"
    end

    test "validates trend analysis structure completeness" do
      {:ok, trend_analysis} =
        TrendAnalyzer.analyze_metrics_trends(
          @valid_metrics,
          @valid_timeperiod,
          @valid_analysis_options
        )

      required_fields = [
        :metrics_count,
        :time_period,
        :analysis_type,
        :trend_direction,
        :confidence_score,
        :predicted_values,
        :anomalies_detected,
        :seasonal_patterns,
        :analysis_timestamp
      ]

      Enum.each(required_fields, fn field ->
        assert Map.has_key?(trend_analysis, field), "Missing required field: #{field}"
      end)
    end
  end

  describe "identifytrend_patterns/1 - TDG Core Tests" do
    test "successfully identifies trend patterns" do
      result = TrendAnalyzer.identifytrend_patterns(@valid_data_points)

      assert {:ok, patterns} = result
      assert is_list(patterns)
      assert length(patterns) >= 1

      # Validate pattern structure
      Enum.each(patterns, fn pattern ->
        assert is_map(pattern)
        assert Map.has_key?(pattern, :type)
        assert Map.has_key?(pattern, :pattern)
        assert Map.has_key?(pattern, :confidence)
        assert is_binary(pattern.type)
        assert is_binary(pattern.pattern)
        assert is_float(pattern.confidence)
      end)
    end

    test "identifies seasonal patterns correctly" do
      {:ok, patterns} = TrendAnalyzer.identifytrend_patterns(@valid_data_points)

      seasonal_patterns = Enum.filter(patterns, &(&1.type == "seasonal"))
      assert length(seasonal_patterns) >= 1

      seasonal_pattern = hd(seasonal_patterns)
      assert seasonal_pattern.pattern == "daily_peak"
      assert seasonal_pattern.confidence > 0.8
    end

    test "identifies cyclical patterns correctly" do
      {:ok, patterns} = TrendAnalyzer.identifytrend_patterns(@valid_data_points)

      cyclical_patterns = Enum.filter(patterns, &(&1.type == "cyclical"))
      assert length(cyclical_patterns) >= 1

      cyclical_pattern = hd(cyclical_patterns)
      assert cyclical_pattern.pattern == "weekly_cycle"
      assert Map.has_key?(cyclical_pattern, :amplitude)
    end

    test "identifies trending patterns correctly" do
      {:ok, patterns} = TrendAnalyzer.identifytrend_patterns(@valid_data_points)

      trending_patterns = Enum.filter(patterns, &(&1.type == "trending"))
      assert length(trending_patterns) >= 1

      trending_pattern = hd(trending_patterns)
      assert trending_pattern.pattern == "upward_trend"
      assert Map.has_key?(trending_pattern, :slope)
      assert Map.has_key?(trending_pattern, :r_squared)
    end

    test "handles empty data points gracefully" do
      result = TrendAnalyzer.identifytrend_patterns([])
      assert {:ok, patterns} = result
      assert is_list(patterns)
    end
  end

  describe "detect_trend_anomalies/2 - TDG Core Tests" do
    test "successfully detects trend anomalies" do
      result =
        TrendAnalyzer.detect_trend_anomalies(
          @valid_data_points,
          @valid_detection_params
        )

      assert {:ok, anomalies} = result
      assert is_list(anomalies)

      # Validate anomaly structure
      Enum.each(anomalies, fn anomaly ->
        assert is_map(anomaly)
        assert Map.has_key?(anomaly, :id)
        assert Map.has_key?(anomaly, :timestamp)
        assert Map.has_key?(anomaly, :value)
        assert Map.has_key?(anomaly, :expected_value)
        assert Map.has_key?(anomaly, :deviation_score)
        assert Map.has_key?(anomaly, :severity)
        assert Map.has_key?(anomaly, :type)

        assert is_integer(anomaly.id)
        assert %DateTime{} = anomaly.timestamp
        assert is_float(anomaly.value)
        assert is_float(anomaly.expected_value)
        assert is_binary(anomaly.severity)
        assert is_binary(anomaly.type)
      end)
    end

    test "detects spike anomalies correctly" do
      {:ok, anomalies} =
        TrendAnalyzer.detect_trend_anomalies(
          @valid_data_points,
          @valid_detection_params
        )

      spike_anomalies = Enum.filter(anomalies, &(&1.type == "spike"))
      assert length(spike_anomalies) >= 1

      spike_anomaly = hd(spike_anomalies)
      assert spike_anomaly.severity == "high"
      assert spike_anomaly.deviation_score > 0
    end

    test "detects drop anomalies correctly" do
      {:ok, anomalies} =
        TrendAnalyzer.detect_trend_anomalies(
          @valid_data_points,
          @valid_detection_params
        )

      drop_anomalies = Enum.filter(anomalies, &(&1.type == "drop"))
      assert length(drop_anomalies) >= 1

      drop_anomaly = hd(drop_anomalies)
      assert drop_anomaly.severity in ["medium", "high"]
      assert drop_anomaly.deviation_score < 0
    end

    test "handles different detection parameters" do
      custom_params = %{@valid_detection_params | threshold: 3.0, sensitivity: "high"}

      result =
        TrendAnalyzer.detect_trend_anomalies(
          @valid_data_points,
          custom_params
        )

      assert {:ok, anomalies} = result
      assert is_list(anomalies)
    end

    test "handles empty data points" do
      result = TrendAnalyzer.detect_trend_anomalies([], @valid_detection_params)
      assert {:ok, anomalies} = result
      assert is_list(anomalies)
    end
  end

  describe "forecast_trends/2 - TDG Core Tests" do
    test "successfully forecasts future trends" do
      result =
        TrendAnalyzer.forecast_trends(
          @valid_data_points,
          @valid_forecast_params
        )

      assert {:ok, forecast} = result
      assert is_map(forecast)
      assert forecast.model_type == @valid_forecast_params.model
      assert forecast.forecast_horizon == @valid_forecast_params.horizon
      assert is_float(forecast.confidence_interval)
      assert is_list(forecast.predicted_values)
      assert is_map(forecast.accuracy_metrics)
      assert %DateTime{} = forecast.model_updated
    end

    test "validates predicted values structure" do
      {:ok, forecast} =
        TrendAnalyzer.forecast_trends(
          @valid_data_points,
          @valid_forecast_params
        )

      Enum.each(forecast.predicted_values, fn prediction ->
        assert is_map(prediction)
        assert Map.has_key?(prediction, :timestamp)
        assert Map.has_key?(prediction, :value)
        assert Map.has_key?(prediction, :confidence)
        assert %DateTime{} = prediction.timestamp
        assert is_float(prediction.value)
        assert is_float(prediction.confidence)
      end)
    end

    test "validates accuracy metrics structure" do
      {:ok, forecast} =
        TrendAnalyzer.forecast_trends(
          @valid_data_points,
          @valid_forecast_params
        )

      accuracy_metrics = forecast.accuracy_metrics
      # Mean Absolute Error
      assert Map.has_key?(accuracy_metrics, :mae)
      # Root Mean Square Error
      assert Map.has_key?(accuracy_metrics, :rmse)
      # Mean Absolute Percentage Error
      assert Map.has_key?(accuracy_metrics, :mape)

      assert is_float(accuracy_metrics.mae)
      assert is_float(accuracy_metrics.rmse)
      assert is_float(accuracy_metrics.mape)
    end

    test "handles different forecast models" do
      custom_params = %{@valid_forecast_params | model: "exponential_smoothing"}

      result =
        TrendAnalyzer.forecast_trends(
          @valid_data_points,
          custom_params
        )

      assert {:ok, forecast} = result
      assert forecast.model_type == "exponential_smoothing"
    end

    test "defaults forecast parameters when not provided" do
      result = TrendAnalyzer.forecast_trends(@valid_data_points, %{})

      assert {:ok, forecast} = result
      assert forecast.model_type == "linear_regression"
      assert forecast.forecast_horizon == 24
    end
  end

  describe "calculate_trend_statistics/1 - TDG Core Tests" do
    test "successfully calculates trend statistics" do
      result = TrendAnalyzer.calculate_trend_statistics(@valid_data_points)

      assert {:ok, statistics} = result
      assert is_map(statistics)
      assert statistics.data_points_count == length(@valid_data_points)
      assert is_float(statistics.mean)
      assert is_float(statistics.median)
      assert is_float(statistics.std_deviation)
      assert is_float(statistics.min_value)
      assert is_float(statistics.max_value)
      assert is_float(statistics.trend_slope)
      assert is_float(statistics.correlation_coefficient)
      assert is_float(statistics.volatility)
      assert %DateTime{} = statistics.calculated_at
    end

    test "validates all required statistical measures present" do
      {:ok, statistics} = TrendAnalyzer.calculate_trend_statistics(@valid_data_points)

      required_stats = [
        :data_points_count,
        :mean,
        :median,
        :std_deviation,
        :min_value,
        :max_value,
        :trend_slope,
        :correlation_coefficient,
        :volatility,
        :calculated_at
      ]

      Enum.each(required_stats, fn stat ->
        assert Map.has_key?(statistics, stat), "Missing required statistic: #{stat}"
      end)
    end

    test "handles empty data points" do
      result = TrendAnalyzer.calculate_trend_statistics([])

      assert {:ok, statistics} = result
      assert statistics.data_points_count == 0
    end

    test "handles single data point" do
      single_point = [%{x: 1, y: 100.0, timestamp: ~U[2024-01-01 00:00:00Z]}]
      result = TrendAnalyzer.calculate_trend_statistics(single_point)

      assert {:ok, statistics} = result
      assert statistics.data_points_count == 1
    end
  end

  # ============================================================================
  # 2. PROPERTY-BASED TESTS - Advanced Validation with Dual Frameworks
  # ============================================================================

  describe "Property-Based Tests - PropCheck Framework" do
    test "propcheck: analyze_metrics_trends always returns valid structure" do
      assert PropCheck.quickcheck(
               forall {metrics, timeperiod, options} <- {
                        PC.list(metric_generator()),
                        timeperiod_generator(),
                        analysis_options_generator()
                      } do
                 case TrendAnalyzer.analyze_metrics_trends(metrics, timeperiod, options) do
                   {:ok, trend_analysis} ->
                     is_map(trend_analysis) and
                       Map.has_key?(trend_analysis, :metrics_count) and
                       Map.has_key?(trend_analysis, :analysis_timestamp) and
                       trend_analysis.metrics_count == length(metrics)

                   {:error, _} ->
                     # Error responses are acceptable
                     true
                 end
               end
             )
    end

    test "propcheck: identifytrend_patterns always returns list" do
      assert PropCheck.quickcheck(
               forall data_points <- PC.list(data_point_generator()) do
                 {:ok, patterns} = TrendAnalyzer.identifytrend_patterns(data_points)

                 is_list(patterns) and
                   Enum.all?(patterns, fn pattern ->
                     is_map(pattern) and
                       Map.has_key?(pattern, :type) and
                       Map.has_key?(pattern, :confidence)
                   end)
               end
             )
    end

    test "propcheck: detect_trend_anomalies maintains anomaly structure" do
      assert PropCheck.quickcheck(
               forall {data_points, params} <- {
                        PC.list(data_point_generator()),
                        detection_params_generator()
                      } do
                 {:ok, anomalies} = TrendAnalyzer.detect_trend_anomalies(data_points, params)

                 is_list(anomalies) and
                   Enum.all?(anomalies, fn anomaly ->
                     is_map(anomaly) and
                       Map.has_key?(anomaly, :id) and
                       Map.has_key?(anomaly, :severity) and
                       Map.has_key?(anomaly, :type)
                   end)
               end
             )
    end
  end

  describe "Property-Based Tests - ExUnitProperties Framework" do
    test "exunitproperties: forecast_trends maintains forecast structure" do
      # Generate test data using StreamData
      for _ <- 1..20 do
        historical_data_gen = SD.list_of(data_point_generator())
        historical_data_result = historical_data_gen |> SD.resize(10)

        historical_data =
          historical_data_result
          |> Enum.take(1)
          |> List.first()

        forecast_params_result = forecast_params_generator()

        forecast_params =
          forecast_params_result
          |> Enum.take(1)
          |> List.first()

        {:ok, forecast} = TrendAnalyzer.forecast_trends(historical_data, forecast_params)
        assert is_map(forecast)
        assert Map.has_key?(forecast, :predicted_values)
        assert Map.has_key?(forecast, :accuracy_metrics)
        assert is_list(forecast.predicted_values)
      end
    end

    test "exunitproperties: calculate_trend_statistics data consistency" do
      # Generate test data using StreamData
      for _ <- 1..20 do
        data_points_gen = SD.list_of(data_point_generator())
        data_points_result = data_points_gen |> SD.resize(10)

        data_points =
          data_points_result
          |> Enum.take(1)
          |> List.first()

        {:ok, statistics} = TrendAnalyzer.calculate_trend_statistics(data_points)
        assert statistics.data_points_count == length(data_points)
        assert is_float(statistics.mean)
        assert is_float(statistics.std_deviation)
        assert statistics.min_value <= statistics.max_value
      end
    end
  end

  # ============================================================================
  # 3. STAMP SAFETY CONSTRAINTS - Critical Safety Validations
  # ============================================================================

  describe "STAMP Safety Constraints - Critical Trend Analysis Safety" do
    test "SC-TREND-001: System SHALL maintain tenant data isolation in trend analysis" do
      # Verify tenant isolation in trend data processing
      tenant_a_metrics = Enum.map(@valid_metrics, &Map.put(&1, :tenant_id, "tenant_a"))
      tenant_b_metrics = Enum.map(@valid_metrics, &Map.put(&1, :tenant_id, "tenant_b"))

      {:ok, analysis_a} =
        TrendAnalyzer.analyze_metrics_trends(
          tenant_a_metrics,
          @valid_timeperiod,
          @valid_analysis_options
        )

      {:ok, analysis_b} =
        TrendAnalyzer.analyze_metrics_trends(
          tenant_b_metrics,
          @valid_timeperiod,
          @valid_analysis_options
        )

      # Verify no data leakage between tenants
      assert analysis_a != analysis_b
      assert analysis_a.metrics_count == length(tenant_a_metrics)
      assert analysis_b.metrics_count == length(tenant_b_metrics)
    end

    test "SC-TREND-002: System SHALL ensure trend predictions are statistically sound" do
      {:ok, forecast} = TrendAnalyzer.forecast_trends(@valid_data_points, @valid_forecast_params)

      # Verify confidence intervals are reasonable (0.0 to 1.0)
      assert forecast.confidence_interval >= 0.0 and forecast.confidence_interval <= 1.0

      # Verify all predictions have valid confidence scores
      Enum.each(forecast.predicted_values, fn prediction ->
        assert prediction.confidence >= 0.0 and prediction.confidence <= 1.0
      end)

      # Verify accuracy metrics are positive
      assert forecast.accuracy_metrics.mae >= 0.0
      assert forecast.accuracy_metrics.rmse >= 0.0
      assert forecast.accuracy_metrics.mape >= 0.0
    end

    test "SC-TREND-003: System SHALL prevent false positive anomaly detection" do
      {:ok, anomalies} =
        TrendAnalyzer.detect_trend_anomalies(
          @valid_data_points,
          @valid_detection_params
        )

      # Verify anomalies have reasonable deviation scores
      Enum.each(anomalies, fn anomaly ->
        # Deviation score should be significant for a true anomaly
        assert abs(anomaly.deviation_score) >= 1.5,
               "Anomaly deviation score too low: #{anomaly.deviation_score}"

        # Verify severity matches deviation score
        case anomaly.severity do
          "high" -> assert abs(anomaly.deviation_score) >= 3.0
          "medium" -> assert abs(anomaly.deviation_score) >= 2.0
          "low" -> assert abs(anomaly.deviation_score) >= 1.5
        end
      end)
    end

    test "SC-TREND-004: System SHALL ensure pattern identification accuracy" do
      {:ok, patterns} = TrendAnalyzer.identifytrend_patterns(@valid_data_points)

      # Verify all patterns have reasonable confidence scores
      Enum.each(patterns, fn pattern ->
        assert pattern.confidence >= 0.5,
               "Pattern confidence too low: #{pattern.confidence}"

        assert pattern.confidence <= 1.0,
               "Pattern confidence invalid: #{pattern.confidence}"

        # Verify pattern types are recognized
        assert pattern.type in ["seasonal", "cyclical", "trending"],
               "Unknown pattern type: #{pattern.type}"
      end)
    end

    test "SC-TREND-005: System SHALL maintain trend analysis performance requirements" do
      start_time = System.monotonic_time(:millisecond)

      # Execute trend analysis operations
      {:ok, _} =
        TrendAnalyzer.analyze_metrics_trends(
          @valid_metrics,
          @valid_timeperiod,
          @valid_analysis_options
        )

      {:ok, _} = TrendAnalyzer.identifytrend_patterns(@valid_data_points)
      {:ok, _} = TrendAnalyzer.calculate_trend_statistics(@valid_data_points)

      end_time = System.monotonic_time(:millisecond)
      execution_time = end_time - start_time

      # Verify performance requirement: <50ms for basic trend operations
      assert execution_time < 50,
             "Trend analysis performance violation: #{execution_time}ms > 50ms"

      # Test forecasting separately (allowed higher latency)
      forecast_start = System.monotonic_time(:millisecond)
      {:ok, _} = TrendAnalyzer.forecast_trends(@valid_data_points, @valid_forecast_params)
      forecast_end = System.monotonic_time(:millisecond)
      forecast_time = forecast_end - forecast_start

      # Verify forecasting performance: <100ms
      assert forecast_time < 100,
             "Forecasting performance violation: #{forecast_time}ms > 100ms"
    end
  end

  # ============================================================================
  # 4. PERFORMANCE TESTS - Analytics Performance Requirements
  # ============================================================================

  describe "Performance Requirements Validation" do
    test "trend analysis handles large datasets efficiently" do
      # Generate large dataset
      large_dataset =
        Enum.map(1..1000, fn i ->
          %{
            x: i,
            y: :rand.uniform(100) + i * 0.1,
            timestamp: DateTime.add(~U[2024-01-01 00:00:00Z], i * 3600, :second)
          }
        end)

      start_time = System.monotonic_time(:millisecond)
      {:ok, statistics} = TrendAnalyzer.calculate_trend_statistics(large_dataset)
      end_time = System.monotonic_time(:millisecond)

      execution_time = end_time - start_time
      assert execution_time < 200, "Large dataset processing too slow: #{execution_time}ms"
      assert statistics.data_points_count == 1000
    end

    test "concurrent trend analysis maintains performance" do
      tasks =
        Enum.map(1..10, fn _i ->
          Task.async(fn ->
            start_time = System.monotonic_time(:millisecond)

            {:ok, _} =
              TrendAnalyzer.analyze_metrics_trends(
                @valid_metrics,
                @valid_timeperiod,
                @valid_analysis_options
              )

            end_time = System.monotonic_time(:millisecond)
            end_time - start_time
          end)
        end)

      execution_times = Task.await_many(tasks, 5000)

      # Verify all concurrent executions completed within performance bounds
      Enum.each(execution_times, fn time ->
        assert time < 100, "Concurrent execution too slow: #{time}ms"
      end)

      # Verify average performance
      avg_time = Enum.sum(execution_times) / length(execution_times)
      assert avg_time < 50, "Average concurrent performance violation: #{avg_time}ms"
    end
  end

  # ============================================================================
  # 5. ERROR HANDLING TESTS - Edge Cases and Invalid Inputs
  # ============================================================================

  describe "Error Handling and Edge Cases" do
    test "handles nil inputs gracefully" do
      # These should not crash the system
      assert {:ok, _} = TrendAnalyzer.analyze_metrics_trends([], %{}, %{})
      assert {:ok, _} = TrendAnalyzer.identifytrend_patterns([])
      assert {:ok, _} = TrendAnalyzer.detect_trend_anomalies([], %{})
      assert {:ok, _} = TrendAnalyzer.forecast_trends([], %{})
      assert {:ok, _} = TrendAnalyzer.calculate_trend_statistics([])
    end

    test "validates input parameter types" do
      # Test with invalid parameter types
      invalid_metrics = "not_a_list"
      invalid_timeperiod = "not_a_map"
      invalid_options = "not_a_map"

      # Functions should handle gracefully (return ok with defensive programming)
      result = TrendAnalyzer.analyze_metrics_trends([], invalid_timeperiod, invalid_options)
      assert {:ok, _} = result
    end

    test "handles malformed data points" do
      malformed_points = [
        %{invalid_key: "value"},
        %{},
        "not_a_map"
      ]

      # Should not crash, should handle gracefully
      assert {:ok, _} = TrendAnalyzer.identifytrend_patterns(malformed_points)
      assert {:ok, _} = TrendAnalyzer.detect_trend_anomalies(malformed_points, %{})
      assert {:ok, _} = TrendAnalyzer.calculate_trend_statistics(malformed_points)
    end
  end

  # ============================================================================
  # 6. INTEGRATION TESTS - Multi-Tenant and Data Integrity
  # ============================================================================

  describe "Integration Tests - Multi-Tenant Data Isolation" do
    test "verifies complete tenant isolation across all functions" do
      tenant_a_data = %{
        metrics: Enum.map(@valid_metrics, &Map.put(&1, :tenant_id, "tenant_a")),
        data_points: Enum.map(@valid_data_points, &Map.put(&1, :tenant_id, "tenant_a"))
      }

      tenant_b_data = %{
        metrics: Enum.map(@valid_metrics, &Map.put(&1, :tenant_id, "tenant_b")),
        data_points: Enum.map(@valid_data_points, &Map.put(&1, :tenant_id, "tenant_b"))
      }

      # Execute all functions for both tenants
      {:ok, trends_a} =
        TrendAnalyzer.analyze_metrics_trends(
          tenant_a_data.metrics,
          @valid_timeperiod,
          @valid_analysis_options
        )

      {:ok, trends_b} =
        TrendAnalyzer.analyze_metrics_trends(
          tenant_b_data.metrics,
          @valid_timeperiod,
          @valid_analysis_options
        )

      {:ok, patterns_a} = TrendAnalyzer.identifytrend_patterns(tenant_a_data.data_points)
      {:ok, patterns_b} = TrendAnalyzer.identifytrend_patterns(tenant_b_data.data_points)

      # Verify isolation (results should be independent)
      assert trends_a.metrics_count == trends_b.metrics_count
      assert length(patterns_a) == length(patterns_b)

      # But ensure they're processed independently
      refute trends_a.analysis_timestamp == trends_b.analysis_timestamp
    end

    test "validates data integrity across trend operations" do
      original_count = length(@valid_metrics)
      original_data_count = length(@valid_data_points)

      # Execute all functions
      {:ok, trends} =
        TrendAnalyzer.analyze_metrics_trends(
          @valid_metrics,
          @valid_timeperiod,
          @valid_analysis_options
        )

      {:ok, patterns} = TrendAnalyzer.identifytrend_patterns(@valid_data_points)

      {:ok, anomalies} =
        TrendAnalyzer.detect_trend_anomalies(
          @valid_data_points,
          @valid_detection_params
        )

      {:ok, forecast} = TrendAnalyzer.forecast_trends(@valid_data_points, @valid_forecast_params)
      {:ok, statistics} = TrendAnalyzer.calculate_trend_statistics(@valid_data_points)

      # Verify data integrity (counts preserved)
      assert trends.metrics_count == original_count
      assert statistics.data_points_count == original_data_count
      assert is_list(patterns)
      assert is_list(anomalies)
      assert is_list(forecast.predicted_values)
    end
  end

  # ============================================================================
  # 7. REGRESSION TESTS - EP-110/EP-111 Prevention
  # ============================================================================

  describe "Regression Tests - False Positive Prevention" do
    test "EP-110 prevention: validates actual trend analysis execution" do
      # Execute actual trend analysis
      {:ok, result} =
        TrendAnalyzer.analyze_metrics_trends(
          @valid_metrics,
          @valid_timeperiod,
          @valid_analysis_options
        )

      # Verify it's not a mock/stub response
      assert result.analysis_timestamp != nil
      assert %DateTime{} = result.analysis_timestamp

      # Verify structural completeness
      result_keys = Map.keys(result)
      assert result_keys |> length() >= 8
      assert is_list(result.predicted_values)
      assert is_map(result.seasonal_patterns)
    end

    test "EP-111 prevention: detects process drift in trend calculations" do
      # Execute same operation multiple times
      results =
        Enum.map(1..3, fn _i ->
          {:ok, result} = TrendAnalyzer.calculate_trend_statistics(@valid_data_points)
          result
        end)

      # Verify consistency (no drift)
      [first | rest] = results

      Enum.each(rest, fn result ->
        assert result.data_points_count == first.data_points_count
        assert result.mean == first.mean
        assert result.median == first.median
        assert result.std_deviation == first.std_deviation
      end)
    end
  end

  # ============================================================================
  # PROPERTY GENERATORS - Supporting Functions for Property-Based Tests
  # ============================================================================

  defp metric_generator do
    SD.fixed_map(%{
      timestamp: datetime_generator(),
      value: SD.float(min: 0.0, max: 1000.0),
      metric: SD.member_of(["cpu_usage", "memory_usage", "disk_io", "network_io"])
    })
  end

  defp timeperiod_generator do
    SD.fixed_map(%{
      start_time: datetime_generator(),
      end_time: datetime_generator(),
      granularity: SD.member_of(["hourly", "daily", "weekly"]),
      timezone: SD.member_of(["UTC", "EST", "PST"])
    })
  end

  defp analysis_options_generator do
    SD.fixed_map(%{
      type: SD.member_of(["linear", "exponential", "polynomial"]),
      confidence_level: SD.float(min: 0.8, max: 0.99),
      include_seasonal: SD.boolean(),
      detect_anomalies: SD.boolean()
    })
  end

  defp data_point_generator do
    SD.fixed_map(%{
      x: SD.integer(1..1000),
      y: SD.float(min: 0.0, max: 1000.0),
      timestamp: datetime_generator()
    })
  end

  defp detection_params_generator do
    SD.fixed_map(%{
      threshold: SD.float(min: 1.0, max: 5.0),
      method: SD.member_of(["statistical", "ml", "threshold"]),
      window_size: SD.integer(5..50),
      sensitivity: SD.member_of(["low", "medium", "high"])
    })
  end

  defp forecast_params_generator do
    SD.fixed_map(%{
      model: SD.member_of(["linear_regression", "exponential_smoothing", "arima"]),
      horizon: SD.integer(12..48),
      confidence: SD.float(min: 0.8, max: 0.99),
      include_seasonality: SD.boolean()
    })
  end

  defp datetime_generator do
    # Generate datetime within last year
    base_time = ~U[2024-01-01 00:00:00Z]
    # Up to 1 year
    SD.bind(SD.integer(0..(365 * 24 * 3600)), fn seconds_to_add ->
      SD.constant(DateTime.add(base_time, seconds_to_add, :second))
    end)
  end
end
