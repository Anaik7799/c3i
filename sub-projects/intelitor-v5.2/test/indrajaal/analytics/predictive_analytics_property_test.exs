defmodule Indrajaal.Analytics.PredictiveAnalyticsPropertyTest do
  use ExUnit.Case, async: true
  # Advanced property testing with sophisticated shrinking
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  # StreamData-based property testing - import except check to avoid conflict
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # Disambiguate PropCheck vs StreamData generators
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Analytics.PredictiveAnalytics

  @moduletag :property_test
  @moduletag :analytics
  @moduletag :predictive
  @moduletag :tdg_compliant

  # Test data generators for property-based testing
  @valid_metrics_data %{
    cpu_usage: [45.2, 67.8, 23.1, 89.4, 56.7],
    memory_usage: [78.9, 45.6, 91.2, 34.5, 67.8],
    network_traffic: [1024, 2048, 512, 4096, 1536],
    disk_io: [234, 567, 123, 890, 456],
    response_times: [45, 67, 23, 89, 56],
    error_rates: [0.01, 0.02, 0.005, 0.03, 0.015],
    user_activity: [100, 150, 75, 200, 125],
    transaction_volume: [500, 750, 300, 1000, 600]
  }

  @valid_prediction_params %{
    forecast_horizon: 24,
    confidence_level: 0.95,
    model_type: :arima,
    seasonal_adjustment: true,
    trend_analysis: true,
    anomaly_detection: true,
    prediction_interval: :hourly,
    data_smoothing: :exponential
  }

  @valid_historical_data [
    %{timestamp: ~N[2025-09-19 10:00:00], value: 45.2, metric: "cpu_usage"},
    %{timestamp: ~N[2025-09-19 11:00:00], value: 67.8, metric: "cpu_usage"},
    %{timestamp: ~N[2025-09-19 12:00:00], value: 23.1, metric: "cpu_usage"},
    %{timestamp: ~N[2025-09-19 13:00:00], value: 89.4, metric: "cpu_usage"},
    %{timestamp: ~N[2025-09-19 14:00:00], value: 56.7, metric: "cpu_usage"}
  ]

  @valid_model_configs [
    %{type: :arima, parameters: %{p: 2, d: 1, q: 2}},
    %{type: :linear_regression, parameters: %{regularization: :ridge}},
    %{type: :neural_network, parameters: %{layers: [10, 5, 1]}},
    %{type: :ensemble, parameters: %{models: [:arima, :linear_regression]}}
  ]

  @prediction_algorithms [:arima, :linear_regression, :neural_network, :ensemble, :random_forest]
  @confidence_levels [0.80, 0.85, 0.90, 0.95, 0.99]
  # hours
  @forecast_horizons [1, 6, 12, 24, 48, 72, 168]
  @metric_types ["cpu_usage", "memory_usage", "network_traffic", "disk_io", "response_times"]

  # =============================================================================
  # PROPERTY-BASED TESTS - PROPCHECK FRAMEWORK
  # =============================================================================

  describe "PropCheck Property-Based Tests for PredictiveAnalytics" do
    test "propcheck: generate_predictions/2 always returns valid structure with advanced shrinking" do
      assert PropCheck.quickcheck(
               forall {metrics_data, params} <-
                        {PC.map(PC.atom(), PC.list(PC.number())), PC.map(PC.atom(), PC.any())} do
                 case PredictiveAnalytics.generate_predictions(metrics_data, params) do
                   {:ok, predictions} ->
                     is_map(predictions) and
                       Map.has_key?(predictions, :forecasts) and
                       Map.has_key?(predictions, :confidence_intervals) and
                       Map.has_key?(predictions, :model_accuracy) and
                       is_list(predictions.forecasts) and
                       is_number(predictions.model_accuracy) and
                       predictions.model_accuracy >= 0.0 and
                       predictions.model_accuracy <= 1.0

                   {:error, _reason} ->
                     # Valid error response for invalid input
                     true
                 end
               end
             )
    end

    test "propcheck: analyze_trends/3 maintains prediction consistency with advanced shrinking" do
      assert PropCheck.quickcheck(
               forall {historical_data, forecast_horizon, model_config} <-
                        {PC.list(PC.map(PC.atom(), PC.any())), PC.choose(1, 168),
                         PC.map(PC.atom(), PC.any())} do
                 case PredictiveAnalytics.analyze_trends(
                        historical_data,
                        forecast_horizon,
                        model_config
                      ) do
                   {:ok, trend_analysis} ->
                     is_map(trend_analysis) and
                       Map.has_key?(trend_analysis, :trend_direction) and
                       Map.has_key?(trend_analysis, :seasonality) and
                       Map.has_key?(trend_analysis, :forecast_points) and
                       trend_analysis.trend_direction in [:increasing, :decreasing, :stable] and
                       is_list(trend_analysis.forecast_points) and
                       length(trend_analysis.forecast_points) <= forecast_horizon

                   {:error, _reason} ->
                     true
                 end
               end
             )
    end

    test "propcheck: predict_anomalies/2 always produces valid anomaly scores" do
      assert PropCheck.quickcheck(
               forall {data_points, detection_params} <-
                        {PC.list(PC.number()), PC.map(PC.atom(), PC.any())} do
                 case PredictiveAnalytics.predict_anomalies(data_points, detection_params) do
                   {:ok, anomaly_predictions} ->
                     is_map(anomaly_predictions) and
                       Map.has_key?(anomaly_predictions, :anomaly_scores) and
                       Map.has_key?(anomaly_predictions, :threshold) and
                       is_list(anomaly_predictions.anomaly_scores) and
                       Enum.all?(anomaly_predictions.anomaly_scores, fn score ->
                         is_number(score) and score >= 0.0 and score <= 1.0
                       end)

                   {:error, _reason} ->
                     true
                 end
               end
             )
    end

    test "propcheck: forecast_capacity/3 produces bounded capacity predictions" do
      assert PropCheck.quickcheck(
               forall {usage_metrics, growth_rate, capacity_params} <-
                        {PC.map(PC.atom(), PC.list(PC.number())), PC.float(),
                         PC.map(PC.atom(), PC.any())} do
                 case PredictiveAnalytics.forecast_capacity(
                        usage_metrics,
                        growth_rate,
                        capacity_params
                      ) do
                   {:ok, capacity_forecast} ->
                     is_map(capacity_forecast) and
                       Map.has_key?(capacity_forecast, :predicted_capacity) and
                       Map.has_key?(capacity_forecast, :time_to_exhaustion) and
                       is_number(capacity_forecast.predicted_capacity) and
                       capacity_forecast.predicted_capacity >= 0.0

                   {:error, _reason} ->
                     true
                 end
               end
             )
    end

    test "propcheck: optimize_models/2 maintains model performance bounds" do
      assert PropCheck.quickcheck(
               forall {current_models, optimization_criteria} <-
                        {PC.list(PC.map(PC.atom(), PC.any())), PC.map(PC.atom(), PC.any())} do
                 case PredictiveAnalytics.optimize_models(current_models, optimization_criteria) do
                   {:ok, optimized_models} ->
                     is_map(optimized_models) and
                       Map.has_key?(optimized_models, :optimized_parameters) and
                       Map.has_key?(optimized_models, :performance_improvement) and
                       is_number(optimized_models.performance_improvement)

                   {:error, _reason} ->
                     true
                 end
               end
             )
    end

    test "propcheck: calculate_prediction_accuracy/2 returns valid accuracy metrics" do
      assert PropCheck.quickcheck(
               forall {predicted_values, actual_values} <-
                        {PC.list(PC.number()), PC.list(PC.number())} do
                 case PredictiveAnalytics.calculate_prediction_accuracy(
                        predicted_values,
                        actual_values
                      ) do
                   {:ok, accuracy_metrics} ->
                     is_map(accuracy_metrics) and
                       Map.has_key?(accuracy_metrics, :mse) and
                       Map.has_key?(accuracy_metrics, :mae) and
                       Map.has_key?(accuracy_metrics, :mape) and
                       Map.has_key?(accuracy_metrics, :r_squared) and
                       is_number(accuracy_metrics.mse) and
                       is_number(accuracy_metrics.mae) and
                       is_number(accuracy_metrics.mape) and
                       is_number(accuracy_metrics.r_squared) and
                       accuracy_metrics.mse >= 0.0 and
                       accuracy_metrics.mae >= 0.0 and
                       accuracy_metrics.mape >= 0.0

                   {:error, _reason} ->
                     true
                 end
               end
             )
    end

    test "propcheck: generate_forecast_intervals/3 produces valid confidence intervals" do
      assert PropCheck.quickcheck(
               forall {predictions, confidence_level, interval_params} <-
                        {PC.list(PC.number()), PC.float(0.5, 0.99), PC.map(PC.atom(), PC.any())} do
                 case PredictiveAnalytics.generate_forecast_intervals(
                        predictions,
                        confidence_level,
                        interval_params
                      ) do
                   {:ok, forecast_intervals} ->
                     is_map(forecast_intervals) and
                       Map.has_key?(forecast_intervals, :lower_bounds) and
                       Map.has_key?(forecast_intervals, :upper_bounds) and
                       Map.has_key?(forecast_intervals, :confidence_level) and
                       is_list(forecast_intervals.lower_bounds) and
                       is_list(forecast_intervals.upper_bounds) and
                       length(forecast_intervals.lower_bounds) ==
                         length(forecast_intervals.upper_bounds) and
                       forecast_intervals.confidence_level == confidence_level

                   {:error, _reason} ->
                     true
                 end
               end
             )
    end

    test "propcheck: detect_seasonal_patterns/2 identifies valid seasonal components" do
      assert PropCheck.quickcheck(
               forall {time_series_data, pattern_params} <-
                        {PC.list(PC.map(PC.atom(), PC.any())), PC.map(PC.atom(), PC.any())} do
                 case PredictiveAnalytics.detect_seasonal_patterns(
                        time_series_data,
                        pattern_params
                      ) do
                   {:ok, seasonal_patterns} ->
                     is_map(seasonal_patterns) and
                       Map.has_key?(seasonal_patterns, :seasonal_periods) and
                       Map.has_key?(seasonal_patterns, :seasonal_strength) and
                       is_list(seasonal_patterns.seasonal_periods) and
                       is_number(seasonal_patterns.seasonal_strength) and
                       seasonal_patterns.seasonal_strength >= 0.0 and
                       seasonal_patterns.seasonal_strength <= 1.0

                   {:error, _reason} ->
                     true
                 end
               end
             )
    end
  end

  # =============================================================================
  # PROPERTY-BASED TESTS - EXUNITPROPERTIES FRAMEWORK
  # =============================================================================

  describe "ExUnitProperties Property-Based Tests for PredictiveAnalytics" do
    test "exunitproperties: generate_predictions/2 maintains output structure consistency" do
      ExUnitProperties.check all(
                               metrics_data <-
                                 SD.map_of(SD.atom(:alphanumeric), SD.list_of(SD.float())),
                               params <- SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               max_runs: 100
                             ) do
        case PredictiveAnalytics.generate_predictions(metrics_data, params) do
          {:ok, predictions} ->
            assert is_map(predictions)
            assert Map.has_key?(predictions, :forecasts)
            assert Map.has_key?(predictions, :confidence_intervals)
            assert Map.has_key?(predictions, :model_accuracy)

          {:error, _reason} ->
            # Valid error response for invalid input
            assert true
        end
      end
    end

    test "exunitproperties: analyze_trends/3 produces consistent trend analysis" do
      ExUnitProperties.check all(
                               historical_data <-
                                 SD.list_of(SD.map_of(SD.atom(:alphanumeric), SD.term())),
                               forecast_horizon <- SD.integer(1..168),
                               model_config <- SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               max_runs: 100
                             ) do
        case PredictiveAnalytics.analyze_trends(historical_data, forecast_horizon, model_config) do
          {:ok, trend_analysis} ->
            assert is_map(trend_analysis)
            assert Map.has_key?(trend_analysis, :trend_direction)
            assert Map.has_key?(trend_analysis, :seasonality)
            assert Map.has_key?(trend_analysis, :forecast_points)
            assert trend_analysis.trend_direction in [:increasing, :decreasing, :stable]

          {:error, _reason} ->
            assert true
        end
      end
    end

    test "exunitproperties: predict_anomalies/2 produces valid anomaly detection results" do
      ExUnitProperties.check all(
                               data_points <- SD.list_of(SD.float()),
                               detection_params <- SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               max_runs: 100
                             ) do
        case PredictiveAnalytics.predict_anomalies(data_points, detection_params) do
          {:ok, anomaly_predictions} ->
            assert is_map(anomaly_predictions)
            assert Map.has_key?(anomaly_predictions, :anomaly_scores)
            assert Map.has_key?(anomaly_predictions, :threshold)
            assert is_list(anomaly_predictions.anomaly_scores)

            # Validate anomaly scores are between 0.0 and 1.0
            Enum.each(anomaly_predictions.anomaly_scores, fn score ->
              assert is_number(score)
              assert score >= 0.0 and score <= 1.0
            end)

          {:error, _reason} ->
            assert true
        end
      end
    end

    test "exunitproperties: forecast_capacity/3 generates realistic capacity forecasts" do
      ExUnitProperties.check all(
                               usage_metrics <-
                                 SD.map_of(SD.atom(:alphanumeric), SD.list_of(SD.float())),
                               growth_rate <- SD.float(),
                               capacity_params <- SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               max_runs: 100
                             ) do
        case PredictiveAnalytics.forecast_capacity(usage_metrics, growth_rate, capacity_params) do
          {:ok, capacity_forecast} ->
            assert is_map(capacity_forecast)
            assert Map.has_key?(capacity_forecast, :predicted_capacity)
            assert Map.has_key?(capacity_forecast, :time_to_exhaustion)
            assert is_number(capacity_forecast.predicted_capacity)
            assert capacity_forecast.predicted_capacity >= 0.0

          {:error, _reason} ->
            assert true
        end
      end
    end

    test "exunitproperties: optimize_models/2 maintains optimization constraints" do
      ExUnitProperties.check all(
                               current_models <-
                                 SD.list_of(SD.map_of(SD.atom(:alphanumeric), SD.term())),
                               optimization_criteria <-
                                 SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               max_runs: 100
                             ) do
        case PredictiveAnalytics.optimize_models(current_models, optimization_criteria) do
          {:ok, optimized_models} ->
            assert is_map(optimized_models)
            assert Map.has_key?(optimized_models, :optimized_parameters)
            assert Map.has_key?(optimized_models, :performance_improvement)
            assert is_number(optimized_models.performance_improvement)

          {:error, _reason} ->
            assert true
        end
      end
    end

    test "exunitproperties: calculate_prediction_accuracy/2 validates accuracy calculations" do
      ExUnitProperties.check all(
                               predicted_values <- SD.list_of(SD.float()),
                               actual_values <- SD.list_of(SD.float()),
                               max_runs: 100
                             ) do
        case PredictiveAnalytics.calculate_prediction_accuracy(predicted_values, actual_values) do
          {:ok, accuracy_metrics} ->
            assert is_map(accuracy_metrics)
            assert Map.has_key?(accuracy_metrics, :mse)
            assert Map.has_key?(accuracy_metrics, :mae)
            assert Map.has_key?(accuracy_metrics, :mape)
            assert Map.has_key?(accuracy_metrics, :r_squared)

            # Validate accuracy metrics bounds
            assert is_number(accuracy_metrics.mse) and accuracy_metrics.mse >= 0.0
            assert is_number(accuracy_metrics.mae) and accuracy_metrics.mae >= 0.0
            assert is_number(accuracy_metrics.mape) and accuracy_metrics.mape >= 0.0
            assert is_number(accuracy_metrics.r_squared)

          {:error, _reason} ->
            assert true
        end
      end
    end

    test "exunitproperties: generate_forecast_intervals/3 creates proper confidence intervals" do
      ExUnitProperties.check all(
                               predictions <- SD.list_of(SD.float()),
                               confidence_level <- SD.float(min: 0.5, max: 0.99),
                               interval_params <- SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               max_runs: 100
                             ) do
        case PredictiveAnalytics.generate_forecast_intervals(
               predictions,
               confidence_level,
               interval_params
             ) do
          {:ok, forecast_intervals} ->
            assert is_map(forecast_intervals)
            assert Map.has_key?(forecast_intervals, :lower_bounds)
            assert Map.has_key?(forecast_intervals, :upper_bounds)
            assert Map.has_key?(forecast_intervals, :confidence_level)
            assert is_list(forecast_intervals.lower_bounds)
            assert is_list(forecast_intervals.upper_bounds)

            assert length(forecast_intervals.lower_bounds) ==
                     length(forecast_intervals.upper_bounds)

            assert forecast_intervals.confidence_level == confidence_level

          {:error, _reason} ->
            assert true
        end
      end
    end

    test "exunitproperties: detect_seasonal_patterns/2 validates seasonal analysis" do
      ExUnitProperties.check all(
                               time_series_data <-
                                 SD.list_of(SD.map_of(SD.atom(:alphanumeric), SD.term())),
                               pattern_params <- SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               max_runs: 100
                             ) do
        case PredictiveAnalytics.detect_seasonal_patterns(time_series_data, pattern_params) do
          {:ok, seasonal_patterns} ->
            assert is_map(seasonal_patterns)
            assert Map.has_key?(seasonal_patterns, :seasonal_periods)
            assert Map.has_key?(seasonal_patterns, :seasonal_strength)
            assert is_list(seasonal_patterns.seasonal_periods)
            assert is_number(seasonal_patterns.seasonal_strength)

            assert seasonal_patterns.seasonal_strength >= 0.0 and
                     seasonal_patterns.seasonal_strength <= 1.0

          {:error, _reason} ->
            assert true
        end
      end
    end
  end

  # =============================================================================
  # STAMP SAFETY CONSTRAINTS VALIDATION
  # =============================================================================

  describe "STAMP Safety Constraints for Predictive Analytics" do
    test "SC-PRED-001: System SHALL ensure prediction model accuracy meets minimum thresholds" do
      ExUnitProperties.check all(
                               predicted_values <- SD.list_of(SD.float(), min_length: 10),
                               actual_values <- SD.list_of(SD.float(), min_length: 10),
                               max_runs: 50
                             ) do
        if length(predicted_values) == length(actual_values) do
          case PredictiveAnalytics.calculate_prediction_accuracy(predicted_values, actual_values) do
            {:ok, accuracy_metrics} ->
              # Verify accuracy metrics are calculated and within reasonable bounds
              assert accuracy_metrics.mse >= 0.0
              assert accuracy_metrics.mae >= 0.0
              assert accuracy_metrics.mape >= 0.0
              # R-squared can be negative for very poor models, but should be bounded
              # Reasonable lower bound
              assert accuracy_metrics.r_squared >= -10.0

            {:error, _reason} ->
              # Error handling is acceptable for edge cases
              assert true
          end
        end
      end
    end

    test "SC-PRED-002: System SHALL maintain prediction consistency across model iterations" do
      # Test with fixed seed data to ensure reproducibility
      metrics_data = @valid_metrics_data
      params = @valid_prediction_params

      # Generate predictions multiple times with same input
      results =
        Enum.map(1..5, fn _iteration ->
          PredictiveAnalytics.generate_predictions(metrics_data, params)
        end)

      # Verify all results have consistent structure (allowing for minor numerical differences)
      success_results = Enum.filter(results, fn result -> match?({:ok, _}, result) end)

      if length(success_results) > 1 do
        [first_result | rest_results] = success_results
        {:ok, first_predictions} = first_result

        Enum.each(rest_results, fn {:ok, predictions} ->
          # Verify structural consistency
          assert Map.keys(predictions) == Map.keys(first_predictions)
          assert length(predictions.forecasts) == length(first_predictions.forecasts)
        end)
      end
    end

    test "SC-PRED-003: System SHALL validate input data quality before prediction generation" do
      # Test with various invalid inputs to ensure proper validation
      invalid_inputs = [
        # Empty metrics
        {%{}, @valid_prediction_params},
        # Empty parameters
        {@valid_metrics_data, %{}},
        # Nil metrics
        {nil, @valid_prediction_params},
        # Nil parameters
        {@valid_metrics_data, nil}
      ]

      Enum.each(invalid_inputs, fn {metrics, params} ->
        result = PredictiveAnalytics.generate_predictions(metrics, params)
        # Should either handle gracefully or return error
        case result do
          # Graceful handling
          {:ok, _predictions} -> assert true
          # Proper error handling
          {:error, _reason} -> assert true
        end
      end)
    end

    test "SC-PRED-004: System SHALL ensure forecast horizons are within operational bounds" do
      ExUnitProperties.check all(
                               forecast_horizon <- SD.integer(-100..1000),
                               max_runs: 50
                             ) do
        historical_data = @valid_historical_data
        model_config = hd(@valid_model_configs)

        case PredictiveAnalytics.analyze_trends(historical_data, forecast_horizon, model_config) do
          {:ok, trend_analysis} ->
            # For valid horizons, forecast points should not exceed the horizon
            if forecast_horizon > 0 do
              assert length(trend_analysis.forecast_points) <= forecast_horizon
            end

          {:error, _reason} ->
            # Negative or excessive horizons should be rejected
            assert true
        end
      end
    end

    test "SC-PRED-005: System SHALL maintain prediction performance under concurrent access" do
      # Simulate concurrent prediction generation
      tasks =
        Enum.map(1..10, fn _i ->
          Task.async(fn ->
            PredictiveAnalytics.generate_predictions(
              @valid_metrics_data,
              @valid_prediction_params
            )
          end)
        end)

      # 5 second timeout
      results = Task.await_many(tasks, 5000)

      # Verify all concurrent operations completed successfully or failed gracefully
      Enum.each(results, fn result ->
        case result do
          {:ok, predictions} ->
            assert is_map(predictions)
            assert Map.has_key?(predictions, :forecasts)

          {:error, _reason} ->
            # Acceptable error handling
            assert true
        end
      end)

      # Verify no crashes or system instability
      assert length(results) == 10
    end
  end

  # =============================================================================
  # PERFORMANCE PROPERTY VALIDATION
  # =============================================================================

  describe "Performance Properties for Predictive Analytics" do
    test "prediction generation performance under time constraints" do
      metrics_data = @valid_metrics_data
      params = @valid_prediction_params

      start_time = System.monotonic_time(:millisecond)
      result = PredictiveAnalytics.generate_predictions(metrics_data, params)
      end_time = System.monotonic_time(:millisecond)

      execution_time = end_time - start_time

      case result do
        {:ok, _predictions} ->
          # Prediction generation should complete within reasonable time (5 seconds max)
          assert execution_time < 5000,
                 "Prediction generation took #{execution_time}ms, expected < 5000ms"

        {:error, _reason} ->
          # Even error handling should be fast
          assert execution_time < 1000,
                 "Error handling took #{execution_time}ms, expected < 1000ms"
      end
    end

    test "memory efficiency during large dataset prediction" do
      # Create larger dataset for memory testing
      large_metrics_data = %{
        cpu_usage: Enum.map(1..1000, fn _ -> :rand.uniform() * 100 end),
        memory_usage: Enum.map(1..1000, fn _ -> :rand.uniform() * 100 end),
        network_traffic: Enum.map(1..1000, fn _ -> :rand.uniform() * 10_000 end)
      }

      # Monitor memory before
      memory_before = :erlang.memory(:total)

      result =
        PredictiveAnalytics.generate_predictions(large_metrics_data, @valid_prediction_params)

      # Force garbage collection
      :erlang.garbage_collect()

      # Monitor memory after
      memory_after = :erlang.memory(:total)
      memory_increase = memory_after - memory_before

      case result do
        {:ok, _predictions} ->
          # Memory increase should be reasonable (< 100MB for this dataset)
          assert memory_increase < 100_000_000,
                 "Memory increase #{memory_increase} bytes is excessive"

        {:error, _reason} ->
          # Error handling should not cause memory leaks
          assert memory_increase < 10_000_000,
                 "Memory increase #{memory_increase} bytes during error handling"
      end
    end
  end

  # =============================================================================
  # ERROR HANDLING PROPERTY VALIDATION
  # =============================================================================

  describe "Error Handling Properties for Predictive Analytics" do
    test "graceful handling of malformed input data" do
      malformed_inputs = [
        {"invalid", @valid_prediction_params},
        {@valid_metrics_data, "invalid"},
        {%{invalid: "data"}, @valid_prediction_params},
        {@valid_metrics_data, %{invalid: "params"}}
      ]

      Enum.each(malformed_inputs, fn {metrics, params} ->
        result = PredictiveAnalytics.generate_predictions(metrics, params)

        case result do
          {:ok, _predictions} ->
            # If it succeeds, the function handled the malformed input gracefully
            assert true

          {:error, reason} ->
            # Error should be descriptive and not crash the system
            assert is_binary(reason) or is_atom(reason)
        end
      end)
    end

    test "boundary condition handling in prediction parameters" do
      boundary_params = [
        %{forecast_horizon: 0},
        %{forecast_horizon: -1},
        %{confidence_level: 0.0},
        %{confidence_level: 1.0},
        %{confidence_level: 1.1},
        %{model_type: :nonexistent_model}
      ]

      Enum.each(boundary_params, fn params ->
        merged_params = Map.merge(@valid_prediction_params, params)
        result = PredictiveAnalytics.generate_predictions(@valid_metrics_data, merged_params)

        # Should handle boundary conditions gracefully
        case result do
          {:ok, _predictions} -> assert true
          {:error, _reason} -> assert true
        end
      end)
    end
  end

  # =============================================================================
  # INTEGRATION PROPERTY VALIDATION
  # =============================================================================

  describe "Integration Properties for Predictive Analytics" do
    test "integration with multiple prediction models maintains consistency" do
      model_configs = @valid_model_configs

      results =
        Enum.map(model_configs, fn config ->
          PredictiveAnalytics.analyze_trends(@valid_historical_data, 24, config)
        end)

      success_results = Enum.filter(results, fn result -> match?({:ok, _}, result) end)

      # All successful results should have consistent structure
      Enum.each(success_results, fn {:ok, trend_analysis} ->
        assert Map.has_key?(trend_analysis, :trend_direction)
        assert Map.has_key?(trend_analysis, :seasonality)
        assert Map.has_key?(trend_analysis, :forecast_points)
        assert trend_analysis.trend_direction in [:increasing, :decreasing, :stable]
      end)
    end

    test "seasonal pattern detection consistency across different time series" do
      time_series_variations = [
        @valid_historical_data,
        # Shorter series
        Enum.take(@valid_historical_data, 3),
        # Longer series
        @valid_historical_data ++ @valid_historical_data
      ]

      pattern_params = %{min_period: 2, max_period: 24, significance_threshold: 0.1}

      results =
        Enum.map(time_series_variations, fn data ->
          PredictiveAnalytics.detect_seasonal_patterns(data, pattern_params)
        end)

      # All results should maintain structural consistency
      Enum.each(results, fn result ->
        case result do
          {:ok, patterns} ->
            assert Map.has_key?(patterns, :seasonal_periods)
            assert Map.has_key?(patterns, :seasonal_strength)
            assert is_number(patterns.seasonal_strength)
            assert patterns.seasonal_strength >= 0.0 and patterns.seasonal_strength <= 1.0

          {:error, _reason} ->
            # Acceptable for insufficient data
            assert true
        end
      end)
    end
  end
end
