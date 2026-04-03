defmodule Indrajaal.Analytics.PredictiveAnalyticsTest do
  @moduledoc """
  TDG Test Suite for Predictive Analytics Module

  This comprehensive test suite follows Test-Driven Generation (TDG) methodology
  with tests written FIRST before implementation. Includes dual property-based testing
  using both PropCheck and ExUnitProperties, STAMP safety constraints, and
  SOPv5.11 cybernetic framework compliance.

  Created: #{DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC")}
  TDG Compliance: 100% - All tests written before implementation
  STAMP Safety: 5 safety constraints validated
  Framework: SOPv5.11 cybernetic coordination with 15-agent architecture
  """

  use ExUnit.Case, async: true
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # Disambiguate PropCheck vs StreamData generators (EP-GEN-014)
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Analytics.PredictiveAnalytics

  @moduletag :analytics
  @moduletag :tdd
  @moduletag :predictive

  describe "TDG Unit Tests - Core Predictive Analytics Functions" do
    test "analyze_trends/2 returns structured trend analysis" do
      data = generate_time_series_data()
      context = %{time_window: :daily, confidence_threshold: 0.8}

      result = PredictiveAnalytics.analyze_trends(data, context)

      assert %{
               trends: trends,
               confidence: confidence,
               predictions: predictions,
               metadata: metadata
             } = result

      assert is_list(trends)
      assert confidence >= 0.0 and confidence <= 1.0
      assert is_list(predictions)
      assert is_map(metadata)
      assert Map.has_key?(metadata, :algorithm)
      assert Map.has_key?(metadata, :analysis_timestamp)
    end

    test "predict_incidents/3 generates incident predictions with confidence scores" do
      historical_data = generate_incident_history()
      context = %{prediction_window: :next_week, model_type: :machine_learning}
      options = %{min_confidence: 0.7, max_predictions: 10}

      result = PredictiveAnalytics.predict_incidents(historical_data, context, options)

      assert %{
               predictions: predictions,
               confidence_scores: scores,
               risk_factors: factors,
               recommendations: recommendations
             } = result

      assert is_list(predictions)
      assert length(predictions) <= 10

      Enum.each(predictions, fn prediction ->
        assert Map.has_key?(prediction, :incident_type)
        assert Map.has_key?(prediction, :probability)
        assert Map.has_key?(prediction, :estimated_time)
        assert prediction.probability >= 0.7
      end)

      assert is_list(scores)
      assert is_list(factors)
      assert is_list(recommendations)
    end

    test "forecast_resource_usage/2 predicts resource utilization patterns" do
      usage_history = generate_resource_usage_data()
      forecast_params = %{horizon: :one_month, granularity: :daily}

      result = PredictiveAnalytics.forecast_resource_usage(usage_history, forecast_params)

      assert %{
               cpu_forecast: cpu_forecast,
               memory_forecast: memory_forecast,
               storage_forecast: storage_forecast,
               network_forecast: network_forecast,
               accuracy_metrics: metrics
             } = result

      # Validate forecast structure
      Enum.each(
        [cpu_forecast, memory_forecast, storage_forecast, network_forecast],
        fn forecast ->
          assert is_list(forecast)
          assert length(forecast) > 0

          Enum.each(forecast, fn point ->
            assert Map.has_key?(point, :timestamp)
            assert Map.has_key?(point, :predicted_value)
            assert Map.has_key?(point, :confidence_interval)
            assert point.predicted_value >= 0
          end)
        end
      )

      assert is_map(metrics)
      assert Map.has_key?(metrics, :mean_absolute_error)
      assert Map.has_key?(metrics, :root_mean_square_error)
    end
  end

  describe "TDG Integration Tests - Predictive Analytics Workflows" do
    test "end_to_end_prediction_pipeline processes complete prediction workflow" do
      input_data = %{
        historical_incidents: generate_incident_history(),
        resource_usage: generate_resource_usage_data(),
        environmental_factors: generate_environmental_data()
      }

      pipeline_config = %{
        prediction_models: [:trend_analysis, :machine_learning, :statistical],
        ensemble_method: :weighted_voting,
        validation_split: 0.2
      }

      result = PredictiveAnalytics.run_prediction_pipeline(input_data, pipeline_config)

      assert %{
               incident_predictions: incident_predictions,
               resource_forecasts: resource_forecasts,
               anomaly_predictions: anomaly_predictions,
               model_performance: performance,
               ensemble_metrics: ensemble_metrics
             } = result

      # Validate pipeline outputs
      assert is_list(incident_predictions)
      assert is_map(resource_forecasts)
      assert is_list(anomaly_predictions)
      assert is_map(performance)
      assert is_map(ensemble_metrics)

      # Validate model performance metrics
      assert Map.has_key?(performance, :accuracy)
      assert Map.has_key?(performance, :precision)
      assert Map.has_key?(performance, :recall)
      assert Map.has_key?(performance, :f1_score)

      assert performance.accuracy >= 0.7
      assert performance.precision >= 0.6
      assert performance.recall >= 0.6
    end

    test "real_time_prediction_updates maintain prediction accuracy over time" do
      initial_state = PredictiveAnalytics.initialize_prediction_state()

      # Simulate real-time data updates
      updates = generate_real_time_updates(5)

      final_state =
        Enum.reduce(updates, initial_state, fn update, state ->
          PredictiveAnalytics.update_predictions(state, update)
        end)

      assert %{
               active_predictions: predictions,
               model_drift_metrics: drift_metrics,
               recalibration_needed: recalibration_status,
               performance_tracking: tracking
             } = final_state

      assert is_list(predictions)
      assert is_map(drift_metrics)
      assert is_boolean(recalibration_status)
      assert is_map(tracking)

      # Validate model drift detection
      assert Map.has_key?(drift_metrics, :prediction_drift_score)
      assert Map.has_key?(drift_metrics, :feature_drift_score)
      assert drift_metrics.prediction_drift_score >= 0.0
    end
  end

  describe "PropCheck Property-Based Tests - Advanced Shrinking" do
    property "prediction confidence scores always between 0 and 1" do
      forall {data, context} <-
               {prediction_data_generator(), prediction_context_generator()} do
        result = PredictiveAnalytics.analyze_trends(data, context)

        # All confidence scores must be valid probabilities
        result.confidence >= 0.0 and result.confidence <= 1.0 and
          Enum.all?(result.predictions, fn pred ->
            pred[:confidence] >= 0.0 and pred[:confidence] <= 1.0
          end)
      end
    end

    property "prediction results maintain temporal consistency" do
      forall {historical_data, prediction_window} <-
               {time_series_generator(), prediction_window_generator()} do
        result = PredictiveAnalytics.forecast_resource_usage(historical_data, prediction_window)

        # Predictions should be temporally ordered
        timestamps = Enum.map(result.cpu_forecast, & &1.timestamp)
        sorted_timestamps = Enum.sort(timestamps, DateTime)

        timestamps == sorted_timestamps and
          length(result.cpu_forecast) > 0 and
          length(result.memory_forecast) > 0
      end
    end

    property "prediction accuracy improves with more historical data" do
      forall {base_data, additional_data} <-
               {limited_historical_data_generator(), additional_data_generator()} do
        small_dataset_result = PredictiveAnalytics.evaluate_model_accuracy(base_data)

        large_dataset_result =
          PredictiveAnalytics.evaluate_model_accuracy(base_data ++ additional_data)

        # More data should generally improve or maintain accuracy
        large_dataset_result.accuracy >= small_dataset_result.accuracy * 0.95 and
          large_dataset_result.confidence >= small_dataset_result.confidence * 0.9
      end
    end
  end

  describe "ExUnitProperties StreamData Tests" do
    test "resource forecasts respect physical constraints" do
      ExUnitProperties.check all(
                               usage_data <- resource_usage_stream(),
                               forecast_params <- forecast_params_stream()
                             ) do
        result = PredictiveAnalytics.forecast_resource_usage(usage_data, forecast_params)

        # CPU usage predictions should be between 0% and 100%
        assert Enum.all?(result.cpu_forecast, fn point ->
                 point.predicted_value >= 0.0 and point.predicted_value <= 100.0
               end)

        # Memory predictions should be non-negative
        assert Enum.all?(result.memory_forecast, fn point ->
                 point.predicted_value >= 0.0
               end)

        # Storage predictions should be monotonically increasing (usage can't decrease)
        storage_values = Enum.map(result.storage_forecast, & &1.predicted_value)
        assert storage_values == Enum.sort(storage_values)
      end
    end

    test "incident predictions maintain probabilistic coherence" do
      ExUnitProperties.check all(
                               incident_data <- incident_history_stream(),
                               prediction_config <- prediction_config_stream()
                             ) do
        result = PredictiveAnalytics.predict_incidents(incident_data, prediction_config, %{})

        # Probabilities must sum to <= 1.0 for mutually exclusive events
        exclusive_events = Enum.filter(result.predictions, & &1.mutually_exclusive)
        total_probability = Enum.reduce(exclusive_events, 0.0, &(&1.probability + &2))

        # Small tolerance for floating point
        assert total_probability <= 1.01
        assert length(result.predictions) >= 0
      end
    end
  end

  describe "STAMP Safety Constraints" do
    test "SC-PA-001: Prediction system SHALL NOT generate false alarms > 5% rate" do
      test_data = generate_known_outcome_data()

      predictions =
        PredictiveAnalytics.predict_incidents(test_data.historical, test_data.context, %{})

      false_alarm_rate =
        calculate_false_alarm_rate(predictions.predictions, test_data.actual_outcomes)

      assert false_alarm_rate <= 0.05, "False alarm rate #{false_alarm_rate} exceeds 5% threshold"
    end

    test "SC-PA-002: Prediction system SHALL detect 90%+ of critical incidents" do
      critical_incident_data = generate_critical_incident_test_data()

      predictions =
        PredictiveAnalytics.predict_incidents(
          critical_incident_data.historical,
          critical_incident_data.context,
          %{focus: :critical_incidents}
        )

      detection_rate =
        calculate_critical_detection_rate(
          predictions.predictions,
          critical_incident_data.known_critical
        )

      assert detection_rate >= 0.90,
             "Critical incident detection rate #{detection_rate} below 90% requirement"
    end

    test "SC-PA-003: Prediction system SHALL provide confidence intervals for all forecasts" do
      forecast_data = generate_forecast_test_data()

      result =
        PredictiveAnalytics.forecast_resource_usage(forecast_data.usage, forecast_data.params)

      # Every forecast point must have confidence interval
      Enum.each(
        [result.cpu_forecast, result.memory_forecast, result.storage_forecast],
        fn forecast ->
          Enum.each(forecast, fn point ->
            assert Map.has_key?(point, :confidence_interval)
            assert Map.has_key?(point.confidence_interval, :lower_bound)
            assert Map.has_key?(point.confidence_interval, :upper_bound)
            assert point.confidence_interval.lower_bound <= point.predicted_value
            assert point.confidence_interval.upper_bound >= point.predicted_value
          end)
        end
      )
    end

    test "SC-PA-004: Prediction system SHALL maintain audit trail of all predictions" do
      prediction_data = generate_audit_test_data()

      result = PredictiveAnalytics.analyze_trends(prediction_data.data, prediction_data.context)

      assert Map.has_key?(result.metadata, :audit_trail)
      audit_trail = result.metadata.audit_trail

      assert Map.has_key?(audit_trail, :prediction_id)
      assert Map.has_key?(audit_trail, :model_version)
      assert Map.has_key?(audit_trail, :input_data_hash)
      assert Map.has_key?(audit_trail, :processing_timestamp)
      assert Map.has_key?(audit_trail, :algorithm_parameters)
    end

    test "SC-PA-005: Prediction system SHALL fail gracefully with insufficient data" do
      insufficient_data = generate_insufficient_data()

      result = PredictiveAnalytics.analyze_trends(insufficient_data, %{})

      assert %{
               status: :insufficient_data,
               message: message,
               minimum_requirements: requirements,
               current_data_points: current_points
             } = result

      assert is_binary(message)
      assert is_map(requirements)
      assert is_integer(current_points)
      assert current_points < requirements.minimum_data_points
    end
  end

  describe "Performance & Error Handling Tests" do
    test "handles large datasets within performance constraints" do
      large_dataset = generate_large_dataset(10_000)

      {time_microseconds, result} =
        :timer.tc(fn ->
          PredictiveAnalytics.analyze_trends(large_dataset, %{optimization: :performance})
        end)

      # Should complete within 5 seconds for 10k data points
      assert time_microseconds < 5_000_000
      assert is_map(result)
      assert Map.has_key?(result, :trends)
    end

    test "recovers gracefully from corrupted input data" do
      corrupted_data = generate_corrupted_data()

      result = PredictiveAnalytics.analyze_trends(corrupted_data, %{error_handling: :graceful})

      assert %{
               status: status,
               processed_data_points: processed,
               skipped_data_points: skipped,
               data_quality_score: quality_score
             } = result

      assert status in [:success_with_warnings, :partial_success]
      assert is_integer(processed)
      assert is_integer(skipped)
      assert quality_score >= 0.0 and quality_score <= 1.0
    end
  end

  # Data generators for testing
  defp generate_time_series_data do
    now = DateTime.utc_now()

    0..100
    |> Enum.map(fn i ->
      %{
        timestamp: DateTime.add(now, -i * 3600, :second),
        value: :rand.uniform(100) + :math.sin(i / 10) * 20,
        metadata: %{source: "test_generator", quality: :high}
      }
    end)
    |> Enum.reverse()
  end

  defp generate_incident_history do
    now = DateTime.utc_now()

    0..50
    |> Enum.map(fn i ->
      %{
        incident_id: "INC-#{String.pad_leading(to_string(i), 5, "0")}",
        timestamp: DateTime.add(now, -i * 86_400, :second),
        type:
          Enum.random([
            :security_breach,
            :performance_degradation,
            :system_failure,
            :maintenance_required
          ]),
        severity: Enum.random([:low, :medium, :high, :critical]),
        resolved_at: DateTime.add(now, -i * 86_400 + :rand.uniform(7200), :second),
        root_cause: generate_random_root_cause()
      }
    end)
  end

  defp generate_resource_usage_data do
    now = DateTime.utc_now()

    # One week of hourly data
    0..168
    |> Enum.map(fn i ->
      %{
        timestamp: DateTime.add(now, -i * 3600, :second),
        cpu_usage: max(5.0, min(95.0, 30 + :rand.normal() * 15)),
        memory_usage: max(10.0, min(90.0, 45 + :rand.normal() * 20)),
        storage_used_gb: 1000 + i * 0.5 + :rand.uniform(5),
        network_throughput_mbps: max(1.0, 50 + :rand.normal() * 25)
      }
    end)
    |> Enum.reverse()
  end

  defp generate_environmental_data do
    %{
      temperature: 22.5 + :rand.normal() * 3,
      humidity: 45 + :rand.uniform(20),
      power_consumption: 500 + :rand.uniform(200),
      network_latency: 5 + :rand.uniform(15)
    }
  end

  defp generate_real_time_updates(count) do
    1..count
    |> Enum.map(fn i ->
      %{
        timestamp: DateTime.utc_now(),
        event_type: Enum.random([:metric_update, :incident_resolved, :new_data_source]),
        data: generate_random_metric_data(),
        sequence_number: i
      }
    end)
  end

  defp generate_random_root_cause do
    causes = [
      "Memory leak in application server",
      "Database connection pool exhaustion",
      "Network congestion during peak hours",
      "Disk space exhaustion on primary storage",
      "Authentication service timeout",
      "Cache invalidation storm",
      "Distributed system clock drift"
    ]

    Enum.random(causes)
  end

  defp generate_random_metric_data do
    %{
      cpu: :rand.uniform(100),
      memory: :rand.uniform(100),
      connections: :rand.uniform(1000),
      response_time: :rand.uniform(5000)
    }
  end

  # PropCheck generators
  defp prediction_data_generator do
    let {data_points, time_range} <- {integer(10, 1000), integer(1, 365)} do
      generate_synthetic_time_series(data_points, time_range)
    end
  end

  defp prediction_context_generator do
    let {window, threshold} <- {oneof([:hourly, :daily, :weekly]), float(0.1, 0.95)} do
      %{time_window: window, confidence_threshold: threshold}
    end
  end

  defp time_series_generator do
    let data_points <-
          PC.list(
            Indrajaal.PropCheckHelpers.fixed_map(%{
              timestamp: datetime(),
              value: PC.float(0.0, 1000.0),
              quality: PC.oneof([:high, :medium, :low])
            })
          ) do
      data_points
    end
  end

  defp limited_historical_data_generator do
    let count <- PC.integer(50, 200) do
      generate_synthetic_time_series(count, 30)
    end
  end

  defp additional_data_generator do
    let count <- PC.integer(100, 500) do
      generate_synthetic_time_series(count, 60)
    end
  end

  defp prediction_window_generator do
    let {horizon, granularity} <-
          {oneof([:one_day, :one_week, :one_month]), oneof([:hourly, :daily])} do
      %{horizon: horizon, granularity: granularity}
    end
  end

  # StreamData generators
  defp resource_usage_stream do
    resource_map =
      Indrajaal.PropCheckHelpers.fixed_map(%{
        cpu_usage: SD.float(min: 0.0, max: 100.0),
        memory_usage: SD.float(min: 0.0, max: 100.0),
        storage_gb: SD.float(min: 0.0, max: 10_000.0),
        timestamp: SD.constant(DateTime.utc_now())
      })

    resource_map
    |> SD.list_of(length: 10..100)
  end

  defp forecast_params_stream do
    Indrajaal.PropCheckHelpers.fixed_map(%{
      horizon: SD.member_of([:one_hour, :one_day, :one_week, :one_month]),
      granularity: SD.member_of([:minute, :hour, :day]),
      model: SD.member_of([:linear, :exponential, :seasonal])
    })
  end

  defp incident_history_stream do
    incident_map =
      Indrajaal.PropCheckHelpers.fixed_map(%{
        incident_id: SD.string(:alphanumeric, min_length: 5, max_length: 20),
        timestamp: SD.constant(DateTime.utc_now()),
        severity: SD.member_of([:low, :medium, :high, :critical]),
        type: SD.member_of([:security, :performance, :availability, :data])
      })

    incident_map
    |> SD.list_of(length: 5..50)
  end

  defp prediction_config_stream do
    Indrajaal.PropCheckHelpers.fixed_map(%{
      prediction_window: SD.member_of([:next_hour, :next_day, :next_week]),
      model_type: SD.member_of([:statistical, :machine_learning, :hybrid]),
      confidence_threshold: SD.float(min: 0.1, max: 0.95)
    })
  end

  # Helper functions for STAMP constraint testing
  defp generate_known_outcome_data do
    %{
      historical: generate_incident_history(),
      context: %{validation_mode: true},
      actual_outcomes: generate_known_outcomes()
    }
  end

  defp generate_known_outcomes do
    # Generate predetermined outcomes for validation
    0..20
    |> Enum.map(fn i ->
      %{
        incident_id: "KNOWN-#{i}",
        # 25% occurrence rate
        occurred: rem(i, 4) == 0,
        timestamp: DateTime.add(DateTime.utc_now(), i * 3600, :second)
      }
    end)
  end

  defp calculate_false_alarm_rate(predictions, actual_outcomes) do
    false_alarms =
      Enum.count(predictions, fn pred ->
        actual = Enum.find(actual_outcomes, &(&1.incident_id == pred.incident_id))
        actual && !actual.occurred && pred.probability > 0.5
      end)

    total_predictions = length(predictions)
    if total_predictions > 0, do: false_alarms / total_predictions, else: 0.0
  end

  defp generate_critical_incident_test_data do
    known_critical = generate_known_critical_incidents()

    %{
      historical: generate_incident_history(),
      context: %{focus: :critical_incidents},
      known_critical: known_critical
    }
  end

  defp generate_known_critical_incidents do
    0..10
    |> Enum.map(fn i ->
      %{
        incident_id: "CRIT-#{i}",
        severity: :critical,
        timestamp: DateTime.add(DateTime.utc_now(), i * 86_400, :second),
        will_occur: rem(i, 3) == 0
      }
    end)
  end

  defp calculate_critical_detection_rate(predictions, known_critical) do
    detected_critical =
      Enum.count(known_critical, fn critical ->
        critical.will_occur &&
          Enum.any?(
            predictions,
            &(&1.incident_id == critical.incident_id && &1.probability > 0.7)
          )
      end)

    total_critical = Enum.count(known_critical, & &1.will_occur)
    if total_critical > 0, do: detected_critical / total_critical, else: 1.0
  end

  defp generate_forecast_test_data do
    %{
      usage: generate_resource_usage_data(),
      params: %{horizon: :one_week, granularity: :daily}
    }
  end

  defp generate_audit_test_data do
    %{
      data: generate_time_series_data(),
      context: %{audit_required: true, compliance_mode: :strict}
    }
  end

  defp generate_insufficient_data do
    # Generate less than minimum required data points
    0..3
    |> Enum.map(fn i ->
      %{timestamp: DateTime.add(DateTime.utc_now(), -i * 3600, :second), value: i * 10}
    end)
  end

  defp generate_large_dataset(size) do
    now = DateTime.utc_now()

    0..size
    |> Enum.map(fn i ->
      %{
        timestamp: DateTime.add(now, -i * 60, :second),
        value: :rand.uniform(1000),
        metadata: %{batch_id: div(i, 100)}
      }
    end)
  end

  defp generate_corrupted_data do
    valid_data = generate_time_series_data()

    # Introduce various types of corruption
    corrupted_data = [
      # Null timestamp
      %{timestamp: nil, value: 50, metadata: %{}},
      # Wrong type
      %{timestamp: DateTime.utc_now(), value: "invalid", metadata: %{}},
      # Invalid value
      %{timestamp: DateTime.utc_now(), value: :infinity, metadata: %{}},
      # Negative value
      %{timestamp: DateTime.utc_now(), value: -1000, metadata: %{}}
    ]

    valid_data ++ corrupted_data
  end

  defp generate_synthetic_time_series(data_points, _time_range) do
    now = DateTime.utc_now()

    0..data_points
    |> Enum.map(fn i ->
      %{
        timestamp: DateTime.add(now, -i * 60, :second),
        value: 50 + :math.sin(i / 10) * 20 + :rand.normal() * 5
      }
    end)
  end

  defp datetime do
    # Simple datetime generator for PropCheck
    let timestamp <- SD.integer(0..1_000_000_000) do
      DateTime.add(DateTime.utc_now(), -timestamp, :second)
    end
  end
end
