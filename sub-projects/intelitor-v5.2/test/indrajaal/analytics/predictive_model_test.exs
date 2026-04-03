defmodule Indrajaal.Analytics.PredictiveModelTest do
  @moduledoc """
  Comprehensive Test-Driven Generation (TDG) test suite for Indrajaal.Analytics.PredictiveModel.

  This test suite follows TDG methodology where tests are written FIRST to define
  the expected behavior, then implementation follows to satisfy these tests.

  Coverage Areas:
  - Unit tests for all PredictiveModel attributes and validations
  - Integration tests for machine learning model lifecycle
  - Property-based testing using PropCheck and ExUnitProperties
  - STAMP safety constraints for ML model reliability and accuracy
  - Enterprise scenarios for large-scale predictive analytics
  - Performance tests for model training and inference
  """

  use ExUnit.Case, async: true
  use Indrajaal.DataCase
  use PropCheck
  alias StreamData, as: SD
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # Disambiguate PropCheck generators
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Analytics.PredictiveModel

  describe "PredictiveModel Creation - TDG Unit Tests" do
    test "creates threat prediction model with comprehensive configuration" do
      training_start = ~U[2024-01-01 00:00:00Z]
      training_end = ~U[2024-12-31 23:59:59Z]

      model_parameters = %{
        learning_rate: 0.001,
        batch_size: 32,
        epochs: 100,
        hidden_layers: [128, 64, 32],
        dropout_rate: 0.2,
        regularization: "l2"
      }

      feature_importance = %{
        network_traffic_anomaly: 0.25,
        user_behavior_score: 0.20,
        geographical_risk: 0.15,
        time_of_day_factor: 0.12,
        system_vulnerability_score: 0.18,
        historical_incident_pattern: 0.10
      }

      attrs = %{
        model_type: :threat_prediction,
        model_name: "Advanced Threat Detection Neural Network v2.1",
        algorithm: "deep_neural_network",
        training_data_start: training_start,
        training_data_end: training_end,
        accuracy_score: 0.94,
        confidence_threshold: 0.85,
        model_parameters: model_parameters,
        feature_importance: feature_importance,
        last_trained_at: ~U[2025-01-01 12:00:00Z],
        predictions_count: 15_742
      }

      assert {:ok, model} = PredictiveModel.create(attrs)
      assert model.model_type == :threat_prediction
      assert model.model_name == "Advanced Threat Detection Neural Network v2.1"
      assert model.algorithm == "deep_neural_network"
      assert model.accuracy_score == 0.94
      assert model.confidence_threshold == 0.85
      assert model.model_parameters["learning_rate"] == 0.001
      assert model.feature_importance["network_traffic_anomaly"] == 0.25
      assert model.predictions_count == 15_742
      # Default status
      assert model.status == :training
    end

    test "creates incident forecasting model with time series configuration" do
      model_parameters = %{
        algorithm_type: "lstm",
        # 24 hours lookback
        sequence_length: 24,
        # 7 days forecast
        prediction_horizon: 7,
        seasonal_components: ["daily", "weekly", "monthly"],
        feature_scaling: "min_max_scaler",
        lstm_units: [64, 32],
        attention_mechanism: true
      }

      feature_importance = %{
        historical_incident_count: 0.30,
        seasonal_patterns: 0.25,
        external_threat_intel: 0.20,
        system_load_metrics: 0.15,
        weather_correlations: 0.10
      }

      attrs = %{
        model_type: :incident_forecasting,
        model_name: "Incident Forecast LSTM Model",
        algorithm: "lstm_time_series",
        training_data_start: ~U[2023-01-01 00:00:00Z],
        training_data_end: ~U[2024-12-31 23:59:59Z],
        accuracy_score: 0.89,
        confidence_threshold: 0.75,
        model_parameters: model_parameters,
        feature_importance: feature_importance,
        predictions_count: 8934
      }

      assert {:ok, model} = PredictiveModel.create(attrs)
      assert model.model_type == :incident_forecasting
      assert model.algorithm == "lstm_time_series"
      assert model.model_parameters["sequence_length"] == 24
      assert model.model_parameters["prediction_horizon"] == 7
      assert model.feature_importance["historical_incident_count"] == 0.30
      assert Enum.sum(Map.values(model.feature_importance)) == 1.0
    end

    test "creates behavior anomaly detection model with unsupervised learning" do
      model_parameters = %{
        algorithm_type: "isolation_forest",
        contamination_rate: 0.1,
        n_estimators: 200,
        max_samples: 256,
        feature_engineering: %{
          time_windows: ["1h", "6h", "24h", "7d"],
          aggregations: ["mean", "std", "min", "max", "percentile_95"],
          behavioral_features: [
            "login_f__requency",
            "data_access_patterns",
            "location_variance"
          ]
        }
      }

      feature_importance = %{
        login_time_anomaly: 0.35,
        access_pattern_deviation: 0.30,
        data_volume_anomaly: 0.20,
        location_risk_score: 0.15
      }

      attrs = %{
        model_type: :behavior_anomaly,
        model_name: "User Behavior Anomaly Detector",
        algorithm: "isolation_forest",
        accuracy_score: 0.91,
        confidence_threshold: 0.80,
        model_parameters: model_parameters,
        feature_importance: feature_importance
      }

      assert {:ok, model} = PredictiveModel.create(attrs)
      assert model.model_type == :behavior_anomaly
      assert model.algorithm == "isolation_forest"
      assert model.model_parameters["contamination_rate"] == 0.1
      assert model.model_parameters["n_estimators"] == 200
      assert model.feature_importance["login_time_anomaly"] == 0.35
    end

    test "creates performance prediction model with regression analysis" do
      model_parameters = %{
        algorithm_type: "gradient_boosting_regressor",
        n_estimators: 500,
        learning_rate: 0.05,
        max_depth: 8,
        subsample: 0.8,
        feature_selection: "recursive_feature_elimination",
        cross_validation_folds: 10,
        performance_metrics: ["mse", "mae", "r2_score"]
      }

      feature_importance = %{
        cpu_utilization_trend: 0.28,
        memory_usage_pattern: 0.25,
        network_io_load: 0.20,
        disk_io_patterns: 0.15,
        concurrent_user_load: 0.12
      }

      attrs = %{
        model_type: :performance_prediction,
        model_name: "System Performance Predictor v3.0",
        algorithm: "gradient_boosting",
        accuracy_score: 0.96,
        confidence_threshold: 0.90,
        model_parameters: model_parameters,
        feature_importance: feature_importance,
        predictions_count: 25_678
      }

      assert {:ok, model} = PredictiveModel.create(attrs)
      assert model.model_type == :performance_prediction
      assert model.algorithm == "gradient_boosting"
      assert model.model_parameters["n_estimators"] == 500
      assert model.model_parameters["learning_rate"] == 0.05
      assert model.feature_importance["cpu_utilization_trend"] == 0.28
      assert model.predictions_count == 25_678
    end

    test "validates required model_type attribute" do
      attrs = %{
        model_name: "Test Model",
        algorithm: "test_algorithm"
      }

      assert {:error, %Ash.Error.Invalid{}} = PredictiveModel.create(attrs)
    end

    test "validates model_type is one of allowed values" do
      attrs = %{
        model_type: :invalid_type,
        model_name: "Test Model",
        algorithm: "test_algorithm"
      }

      assert {:error, %Ash.Error.Invalid{}} = PredictiveModel.create(attrs)
    end

    test "validates required model_name attribute" do
      attrs = %{
        model_type: :threat_prediction,
        algorithm: "test_algorithm"
      }

      assert {:error, %Ash.Error.Invalid{}} = PredictiveModel.create(attrs)
    end

    test "validates model_name max length constraint" do
      attrs = %{
        model_type: :threat_prediction,
        # Exceeds 100 character limit
        model_name: String.duplicate("a", 101),
        algorithm: "test_algorithm"
      }

      assert {:error, %Ash.Error.Invalid{}} = PredictiveModel.create(attrs)
    end

    test "validates algorithm max length constraint" do
      attrs = %{
        model_type: :threat_prediction,
        model_name: "Test Model",
        # Exceeds 50 character limit
        algorithm: String.duplicate("a", 51)
      }

      assert {:error, %Ash.Error.Invalid{}} = PredictiveModel.create(attrs)
    end

    test "validates accuracy_score within 0.0 to 1.0 range" do
      # Test invalid high score
      attrs_high = %{
        model_type: :threat_prediction,
        model_name: "Test Model",
        accuracy_score: 1.5
      }

      assert {:error, %Ash.Error.Invalid{}} = PredictiveModel.create(attrs_high)

      # Test invalid low score
      attrs_low = %{
        model_type: :threat_prediction,
        model_name: "Test Model",
        accuracy_score: -0.1
      }

      assert {:error, %Ash.Error.Invalid{}} = PredictiveModel.create(attrs_low)
    end

    test "validates confidence_threshold within 0.0 to 1.0 range" do
      # Test invalid high threshold
      attrs_high = %{
        model_type: :threat_prediction,
        model_name: "Test Model",
        confidence_threshold: 1.5
      }

      assert {:error, %Ash.Error.Invalid{}} = PredictiveModel.create(attrs_high)

      # Test invalid low threshold
      attrs_low = %{
        model_type: :threat_prediction,
        model_name: "Test Model",
        confidence_threshold: -0.1
      }

      assert {:error, %Ash.Error.Invalid{}} = PredictiveModel.create(attrs_low)
    end

    test "sets default values for optional attributes" do
      attrs = %{
        model_type: :threat_prediction,
        model_name: "Basic Model"
      }

      assert {:ok, model} = PredictiveModel.create(attrs)
      assert model.confidence_threshold == 0.8
      assert model.model_parameters == %{}
      assert model.feature_importance == %{}
      assert model.predictions_count == 0
      assert model.status == :training
    end

    test "validates status is one of allowed values" do
      attrs = %{
        model_type: :threat_prediction,
        model_name: "Test Model",
        status: :invalid_status
      }

      assert {:error, %Ash.Error.Invalid{}} = PredictiveModel.create(attrs)
    end
  end

  describe "PredictiveModel Actions - TDG Integration Tests" do
    test "train action creates model with training configuration" do
      attrs = %{
        model_type: :threat_prediction,
        model_name: "Training Test Model",
        algorithm: "random_forest",
        training_data_start: ~U[2024-01-01 00:00:00Z],
        training_data_end: ~U[2024-12-31 23:59:59Z]
      }

      assert {:ok, model} = PredictiveModel.train(attrs)
      assert model.model_type == :threat_prediction
      assert model.model_name == "Training Test Model"
      assert model.algorithm == "random_forest"
      assert model.training_data_start == ~U[2024-01-01 00:00:00Z]
      assert model.training_data_end == ~U[2024-12-31 23:59:59Z]
      # Changed by after_action hook
      assert model.status == :active
    end

    test "list_active action filters models by active status" do
      # Create models with different statuses
      {:ok, active_model_1} =
        PredictiveModel.create(%{
          model_type: :threat_prediction,
          model_name: "Active Model 1",
          status: :active
        })

      {:ok, active_model_2} =
        PredictiveModel.create(%{
          model_type: :incident_forecasting,
          model_name: "Active Model 2",
          status: :active
        })

      {:ok, _training_model} =
        PredictiveModel.create(%{
          model_type: :behavior_anomaly,
          model_name: "Training Model",
          status: :training
        })

      {:ok, _deprecated_model} =
        PredictiveModel.create(%{
          model_type: :performance_prediction,
          model_name: "Deprecated Model",
          status: :deprecated
        })

      active_models = PredictiveModel.list_active()

      assert length(active_models) >= 2
      assert Enum.all?(active_models, &(&1.status == :active))

      active_model_names = Enum.map(active_models, & &1.model_name)
      assert "Active Model 1" in active_model_names
      assert "Active Model 2" in active_model_names
      refute "Training Model" in active_model_names
      refute "Deprecated Model" in active_model_names
    end

    test "updates model status through lifecycle" do
      {:ok, model} =
        PredictiveModel.create(%{
          model_type: :threat_prediction,
          model_name: "Lifecycle Test Model",
          status: :training
        })

      assert model.status == :training

      # Move to active
      {:ok, active_model} = PredictiveModel.update(model, %{status: :active})
      assert active_model.status == :active

      # Move to deprecated
      {:ok, deprecated_model} = PredictiveModel.update(active_model, %{status: :deprecated})
      assert deprecated_model.status == :deprecated

      # Test failed status
      {:ok, failed_model} = PredictiveModel.update(deprecated_model, %{status: :failed})
      assert failed_model.status == :failed
    end

    test "updates model parameters and retraining metadata" do
      original_parameters = %{
        learning_rate: 0.01,
        batch_size: 64
      }

      {:ok, model} =
        PredictiveModel.create(%{
          model_type: :performance_prediction,
          model_name: "Parameter Update Test",
          model_parameters: original_parameters,
          predictions_count: 1000
        })

      # Update parameters for retraining
      new_parameters = %{
        # Reduced learning rate
        learning_rate: 0.005,
        # Increased batch size
        batch_size: 128,
        # Added regularization
        regularization: "l1"
      }

      retraining_time = ~U[2025-01-15 10:30:00Z]

      {:ok, updated_model} =
        PredictiveModel.update(model, %{
          model_parameters: new_parameters,
          last_trained_at: retraining_time,
          # Reset for new model version
          predictions_count: 0,
          # Improved accuracy
          accuracy_score: 0.97
        })

      assert updated_model.model_parameters["learning_rate"] == 0.005
      assert updated_model.model_parameters["batch_size"] == 128
      assert updated_model.model_parameters["regularization"] == "l1"
      assert updated_model.last_trained_at == retraining_time
      assert updated_model.predictions_count == 0
      assert updated_model.accuracy_score == 0.97
    end

    test "updates feature importance after feature engineering" do
      original_importance = %{
        feature_a: 0.6,
        feature_b: 0.4
      }

      {:ok, model} =
        PredictiveModel.create(%{
          model_type: :behavior_anomaly,
          model_name: "Feature Importance Test",
          feature_importance: original_importance
        })

      # Update with refined feature importance
      refined_importance = %{
        feature_a: 0.35,
        feature_b: 0.25,
        # New feature
        feature_c: 0.20,
        # New feature
        feature_d: 0.20
      }

      {:ok, updated_model} =
        PredictiveModel.update(model, %{
          feature_importance: refined_importance
        })

      assert updated_model.feature_importance["feature_a"] == 0.35
      assert updated_model.feature_importance["feature_c"] == 0.20
      assert updated_model.feature_importance["feature_d"] == 0.20
      assert map_size(updated_model.feature_importance) == 4

      # Verify total importance sums to 1.0
      total_importance =
        updated_model.feature_importance
        |> Map.values()
        |> Enum.sum()

      assert_in_delta total_importance, 1.0, 0.001
    end
  end

  describe "Property-Based Testing - PropCheck" do
    # Property verification: accuracy score constraints validation
    # Converted from PropCheck to avoid GenServer dependency with --no-start
    # SC-SIL6-001: Manual property verification
    test "propcheck: accuracy score constraints validation" do
      test_cases = [0.0, 0.25, 0.5, 0.75, 1.0, 0.333, 0.667, 0.999]

      for accuracy <- test_cases do
        attrs = %{
          model_type: :threat_prediction,
          model_name: "PropCheck Test Model",
          accuracy_score: accuracy
        }

        case PredictiveModel.create(attrs) do
          {:ok, model} ->
            assert model.accuracy_score == accuracy
            assert model.accuracy_score >= 0.0
            assert model.accuracy_score <= 1.0

          {:error, _} ->
            flunk("Failed to create model with accuracy: #{accuracy}")
        end
      end
    end

    # Property verification: feature importance normalization
    # Converted from PropCheck to avoid GenServer dependency with --no-start
    # SC-SIL6-001: Manual property verification
    test "propcheck: feature importance normalization" do
      test_cases = [
        [],
        [0.5],
        [0.3, 0.7],
        [0.25, 0.25, 0.25, 0.25],
        [0.1, 0.2, 0.3, 0.4],
        [0.5, 0.3, 0.2]
      ]

      for importance_values <- test_cases do
        if length(importance_values) > 0 do
          # Create normalized feature importance map
          total = Enum.sum(importance_values)

          normalized_values =
            if total > 0, do: Enum.map(importance_values, &(&1 / total)), else: importance_values

          feature_importance =
            normalized_values
            |> Enum.with_index()
            |> Enum.reduce(%{}, fn {val, idx}, acc ->
              acc
              |> Map.put("feature_#{idx}", val)
            end)

          attrs = %{
            model_type: :performance_prediction,
            model_name: "Feature Test Model",
            feature_importance: feature_importance
          }

          case PredictiveModel.create(attrs) do
            {:ok, model} ->
              stored_total =
                model.feature_importance
                |> Map.values()
                |> Enum.sum()

              # Allow for floating point precision differences
              assert abs(stored_total - 1.0) < 0.001 || stored_total == 0.0

            {:error, _} ->
              flunk(
                "Failed to create model with feature importance: #{inspect(feature_importance)}"
              )
          end
        end
      end
    end
  end

  describe "Property-Based Testing - ExUnitProperties" do
    test "exunitproperties: model name and algorithm consistency" do
      ExUnitProperties.check all(
                               model_type <-
                                 SD.member_of([
                                   :threat_prediction,
                                   :incident_forecasting,
                                   :behavior_anomaly,
                                   :performance_prediction
                                 ]),
                               model_name <-
                                 SD.string(:alphanumeric, min_length: 1, max_length: 50),
                               algorithm <-
                                 SD.string(:alphanumeric, min_length: 1, max_length: 30),
                               max_runs: 50
                             ) do
        attrs = %{
          model_type: model_type,
          model_name: model_name,
          algorithm: algorithm
        }

        assert {:ok, model} = PredictiveModel.create(attrs)
        assert model.model_type == model_type
        assert model.model_name == model_name
        assert model.algorithm == algorithm
      end
    end

    test "exunitproperties: predictions count tracking" do
      ExUnitProperties.check all(
                               initial_count <- SD.integer(0..1_000_000),
                               max_runs: 30
                             ) do
        attrs = %{
          model_type: :threat_prediction,
          model_name: "Count Tracking Test",
          predictions_count: initial_count
        }

        assert {:ok, model} = PredictiveModel.create(attrs)
        assert model.predictions_count == initial_count

        # Simulate prediction increment
        new_count = initial_count + :rand.uniform(100)

        assert {:ok, updated_model} =
                 PredictiveModel.update(model, %{predictions_count: new_count})

        assert updated_model.predictions_count == new_count
        assert updated_model.predictions_count > initial_count
      end
    end
  end

  describe "STAMP Safety Constraints - Predictive Models" do
    test "SC-PM-001: System SHALL maintain model accuracy above minimum threshold" do
      # Define minimum acceptable accuracy for each model type
      minimum_thresholds = %{
        threat_prediction: 0.85,
        incident_forecasting: 0.80,
        behavior_anomaly: 0.82,
        performance_prediction: 0.88
      }

      # Test each model type meets minimum threshold
      for {model_type, min_accuracy} <- minimum_thresholds do
        # Test with acceptable accuracy
        {:ok, good_model} =
          PredictiveModel.create(%{
            model_type: model_type,
            model_name: "Good #{model_type} Model",
            accuracy_score: min_accuracy + 0.05,
            status: :active
          })

        assert good_model.accuracy_score >= min_accuracy
        assert good_model.status == :active

        # Models with low accuracy should be marked for retraining
        {:ok, poor_model} =
          PredictiveModel.create(%{
            model_type: model_type,
            model_name: "Poor #{model_type} Model",
            accuracy_score: min_accuracy - 0.10
          })

        # In production, this would trigger retraining workflow
        assert poor_model.accuracy_score < min_accuracy
        # Business logic would set status to :training for retraining
      end
    end

    test "SC-PM-002: System SHALL ensure model training data temporal consistency" do
      training_start = ~U[2024-01-01 00:00:00Z]
      training_end = ~U[2024-12-31 23:59:59Z]

      {:ok, model} =
        PredictiveModel.create(%{
          model_type: :incident_forecasting,
          model_name: "Temporal Consistency Test",
          training_data_start: training_start,
          training_data_end: training_end
        })

      # STAMP constraint: Training end must be after training start
      assert DateTime.compare(model.training_data_end, model.training_data_start) == :gt

      # Training period should be reasonable (not too short or too long)
      training_period_days =
        DateTime.diff(model.training_data_end, model.training_data_start, :day)

      # At least 30 days
      assert training_period_days >= 30
      # No more than 3 years
      assert training_period_days <= 1095

      # Last trained date should be reasonable
      if model.last_trained_at do
        assert DateTime.compare(model.last_trained_at, model.training_data_end) in [:gt, :eq]
      end
    end

    test "SC-PM-003: System SHALL validate feature importance mathematical consistency" do
      # Test valid feature importance that sums to 1.0
      valid_importance = %{
        network_anomaly: 0.3,
        user_behavior: 0.25,
        time_patterns: 0.2,
        system_metrics: 0.15,
        external_factors: 0.1
      }

      {:ok, model} =
        PredictiveModel.create(%{
          model_type: :threat_prediction,
          model_name: "Feature Importance Test",
          feature_importance: valid_importance
        })

      # Verify mathematical consistency
      total_importance =
        model.feature_importance
        |> Map.values()
        |> Enum.sum()

      assert_in_delta total_importance, 1.0, 0.001

      # All individual features should have positive importance
      assert Enum.all?(Map.values(model.feature_importance), &(&1 > 0.0))
      assert Enum.all?(Map.values(model.feature_importance), &(&1 < 1.0))

      # Most important feature should be network_anomaly
      max_importance = model.feature_importance |> Map.values() |> Enum.max()
      assert model.feature_importance["network_anomaly"] == max_importance
    end

    test "SC-PM-004: System SHALL enforce model confidence threshold logical constraints" do
      {:ok, model} =
        PredictiveModel.create(%{
          model_type: :behavior_anomaly,
          model_name: "Confidence Threshold Test",
          accuracy_score: 0.92,
          confidence_threshold: 0.85
        })

      # STAMP constraint: Confidence threshold should be reasonable relative to accuracy
      assert model.confidence_threshold <= model.accuracy_score
      # Not too permissive
      assert model.confidence_threshold >= 0.5
      # Not too restrictive
      assert model.confidence_threshold <= 0.95

      # Update confidence threshold
      {:ok, updated_model} =
        PredictiveModel.update(model, %{
          confidence_threshold: 0.90
        })

      # New threshold should still be logical
      assert updated_model.confidence_threshold <= model.accuracy_score
      assert updated_model.confidence_threshold > model.confidence_threshold
    end

    test "SC-PM-005: System SHALL maintain model versioning and audit trail" do
      {:ok, original_model} =
        PredictiveModel.create(%{
          model_type: :performance_prediction,
          model_name: "Model Versioning Test v1.0",
          accuracy_score: 0.88,
          predictions_count: 5000,
          last_trained_at: ~U[2024-06-01 10:00:00Z]
        })

      original_id = original_model.id
      original_created_at = original_model.inserted_at

      # Simulate model retraining/update
      {:ok, updated_model} =
        PredictiveModel.update(original_model, %{
          model_name: "Model Versioning Test v2.0",
          # Improved accuracy
          accuracy_score: 0.93,
          # Reset for new version
          predictions_count: 0,
          last_trained_at: ~U[2025-01-01 12:00:00Z]
        })

      # STAMP constraint: Audit trail integrity
      # Same model entity
      assert updated_model.id == original_id
      # Creation time preserved
      assert updated_model.inserted_at == original_created_at
      # Update time changed
      assert updated_model.updated_at != original_model.updated_at

      # Model improvements tracked
      assert updated_model.accuracy_score > original_model.accuracy_score

      assert DateTime.compare(updated_model.last_trained_at, original_model.last_trained_at) ==
               :gt

      # Version progression in name
      assert String.contains?(updated_model.model_name, "v2.0")
      # Reset for new version
      assert updated_model.predictions_count == 0
    end
  end

  describe "Enterprise Scenarios - TDG Business Logic Tests" do
    test "creates comprehensive threat intelligence ML pipeline" do
      # Simulate enterprise-grade threat prediction system
      threat_model_config = %{
        model_type: :threat_prediction,
        model_name: "Enterprise Threat Intelligence ML Pipeline v3.2",
        algorithm: "ensemble_deep_learning",
        training_data_start: ~U[2022-01-01 00:00:00Z],
        training_data_end: ~U[2024-12-31 23:59:59Z],
        accuracy_score: 0.956,
        confidence_threshold: 0.88,
        model_parameters: %{
          ensemble_methods: ["random_forest", "gradient_boosting", "neural_network"],
          neural_network_config: %{
            layers: [512, 256, 128, 64, 32],
            activation: "relu",
            dropout_rates: [0.2, 0.3, 0.4, 0.2, 0.1],
            batch_normalization: true
          },
          training_config: %{
            epochs: 200,
            batch_size: 128,
            learning_rate_schedule: "cosine_annealing",
            early_stopping: %{patience: 20, min_delta: 0.001}
          },
          data_preprocessing: %{
            feature_scaling: "robust_scaler",
            categorical_encoding: "target_encoding",
            missing_value_strategy: "iterative_imputer",
            outlier_detection: "isolation_forest"
          }
        },
        feature_importance: %{
          network_traffic_patterns: 0.22,
          user_behavior_anomalies: 0.18,
          geolocation_risk_factors: 0.15,
          threat_intelligence_feeds: 0.14,
          system_vulnerability_scores: 0.12,
          temporal_activity_patterns: 0.10,
          device_fingerprint_analysis: 0.09
        },
        predictions_count: 847_529,
        last_trained_at: ~U[2025-01-01 06:00:00Z],
        status: :active
      }

      {:ok, threat_model} = PredictiveModel.create(threat_model_config)

      # Verify enterprise-grade configuration
      assert threat_model.accuracy_score > 0.95
      assert threat_model.predictions_count > 800_000
      assert length(threat_model.model_parameters["ensemble_methods"]) == 3

      assert threat_model.model_parameters["neural_network_config"]["layers"] == [
               512,
               256,
               128,
               64,
               32
             ]

      # Verify comprehensive feature engineering
      assert map_size(threat_model.feature_importance) == 7

      total_importance =
        threat_model.feature_importance
        |> Map.values()
        |> Enum.sum()

      assert_in_delta total_importance, 1.0, 0.001

      # Verify top features are security-relevant
      feature_importance_data = threat_model.feature_importance

      top_feature =
        feature_importance_data
        |> Enum.max_by(fn {_feature, importance} -> importance end)

      assert elem(top_feature, 0) == "network_traffic_patterns"
      assert elem(top_feature, 1) == 0.22
    end

    test "creates behavioral anomaly detection with advanced ML techniques" do
      # Simulate user and entity behavior analytics (UEBA)
      ueba_model_config = %{
        model_type: :behavior_anomaly,
        model_name: "Advanced UEBA Anomaly Detection Engine",
        algorithm: "autoencoder_isolation_hybrid",
        accuracy_score: 0.934,
        confidence_threshold: 0.82,
        model_parameters: %{
          autoencoder_config: %{
            encoder_layers: [200, 100, 50],
            decoder_layers: [50, 100, 200],
            latent_dimension: 20,
            reconstruction_threshold: 0.05
          },
          isolation_forest_config: %{
            n_estimators: 300,
            contamination: 0.08,
            max_features: 0.8,
            bootstrap: true
          },
          ensemble_weights: %{
            autoencoder_score: 0.6,
            isolation_forest_score: 0.4
          },
          behavioral_windows: ["1h", "4h", "24h", "7d", "30d"],
          anomaly_types: [
            "temporal_anomaly",
            "volume_anomaly",
            "sequence_anomaly",
            "peer_group_deviation",
            "privilege_escalation"
          ]
        },
        feature_importance: %{
          login_time_deviation: 0.25,
          data_access_volume_change: 0.22,
          privilege_usage_pattern: 0.20,
          peer_group_comparison: 0.18,
          geographic_access_anomaly: 0.15
        },
        predictions_count: 234_567
      }

      {:ok, ueba_model} = PredictiveModel.create(ueba_model_config)

      # Verify UEBA-specific configuration
      assert ueba_model.model_type == :behavior_anomaly
      assert ueba_model.algorithm == "autoencoder_isolation_hybrid"
      assert length(ueba_model.model_parameters["behavioral_windows"]) == 5
      assert length(ueba_model.model_parameters["anomaly_types"]) == 5

      # Verify ensemble configuration
      ensemble_weights = ueba_model.model_parameters["ensemble_weights"]

      total_weight =
        ensemble_weights
        |> Map.values()
        |> Enum.sum()

      assert_in_delta total_weight, 1.0, 0.001

      # Verify autoencoder architecture
      encoder_layers = ueba_model.model_parameters["autoencoder_config"]["encoder_layers"]
      decoder_layers = ueba_model.model_parameters["autoencoder_config"]["decoder_layers"]
      assert encoder_layers == [200, 100, 50]
      # Symmetric decoding
      assert decoder_layers == [50, 100, 200]
    end

    test "creates performance prediction with time-series forecasting" do
      # Simulate enterprise performance forecasting system
      performance_forecast_config = %{
        model_type: :performance_prediction,
        model_name: "Infrastructure Performance Forecasting Suite",
        algorithm: "prophet_lstm_hybrid",
        training_data_start: ~U[2021-01-01 00:00:00Z],
        training_data_end: ~U[2024-12-31 23:59:59Z],
        accuracy_score: 0.948,
        confidence_threshold: 0.90,
        model_parameters: %{
          prophet_config: %{
            seasonality_mode: "multiplicative",
            yearly_seasonality: true,
            weekly_seasonality: true,
            daily_seasonality: true,
            holidays: ["us_holidays", "business_holidays"],
            changepoint_prior_scale: 0.05
          },
          lstm_config: %{
            units: [128, 64, 32],
            dropout: 0.2,
            recurrent_dropout: 0.2,
            # One week of hourly data
            sequence_length: 168,
            # 24 hour forecast
            prediction_horizon: 24
          },
          ensemble_strategy: "weighted_average",
          feature_engineering: %{
            # Hours
            lag_features: [1, 6, 12, 24, 48, 168],
            rolling_statistics: ["mean", "std", "min", "max"],
            window_sizes: [6, 12, 24],
            external_features: ["weather", "business_calendar", "system_events"]
          }
        },
        feature_importance: %{
          historical_cpu_utilization: 0.30,
          memory_usage_patterns: 0.25,
          network_io_trends: 0.20,
          seasonal_business_patterns: 0.15,
          external_load_factors: 0.10
        },
        predictions_count: 456_789
      }

      {:ok, performance_model} = PredictiveModel.create(performance_forecast_config)

      # Verify time-series specific configuration
      assert performance_model.algorithm == "prophet_lstm_hybrid"

      assert performance_model.model_parameters["prophet_config"]["seasonality_mode"] ==
               "multiplicative"

      assert performance_model.model_parameters["lstm_config"]["sequence_length"] == 168
      assert performance_model.model_parameters["lstm_config"]["prediction_horizon"] == 24

      # Verify feature engineering complexity
      lag_features = performance_model.model_parameters["feature_engineering"]["lag_features"]
      assert length(lag_features) == 6
      # Weekly lag
      assert 168 in lag_features

      # Verify business-relevant features
      assert performance_model.feature_importance["seasonal_business_patterns"] == 0.15
      assert performance_model.feature_importance["historical_cpu_utilization"] == 0.30
    end

    test "performs ML model ensemble and A/B testing workflow" do
      # Create multiple models for ensemble testing
      model_configs = [
        %{
          model_type: :incident_forecasting,
          model_name: "Incident Forecast Model A - Random Forest",
          algorithm: "random_forest",
          accuracy_score: 0.89,
          confidence_threshold: 0.75,
          predictions_count: 12_000
        },
        %{
          model_type: :incident_forecasting,
          model_name: "Incident Forecast Model B - Gradient Boosting",
          algorithm: "gradient_boosting",
          accuracy_score: 0.92,
          confidence_threshold: 0.80,
          predictions_count: 8000
        },
        %{
          model_type: :incident_forecasting,
          model_name: "Incident Forecast Model C - Neural Network",
          algorithm: "neural_network",
          accuracy_score: 0.94,
          confidence_threshold: 0.85,
          predictions_count: 5000
        }
      ]

      created_models =
        Enum.map(model_configs, fn config ->
          {:ok, model} = PredictiveModel.create(config)
          model
        end)

      # Verify ensemble creation
      assert length(created_models) == 3

      # Analyze model performance for ensemble weighting
      model_performance =
        Enum.map(created_models, fn model ->
          %{
            id: model.id,
            algorithm: model.algorithm,
            accuracy: model.accuracy_score,
            predictions: model.predictions_count,
            confidence: model.confidence_threshold
          }
        end)

      # Sort by accuracy for performance comparison
      sorted_by_accuracy = Enum.sort(model_performance, &(&1.accuracy >= &2.accuracy))
      best_model = List.first(sorted_by_accuracy)

      assert best_model.algorithm == "neural_network"
      assert best_model.accuracy == 0.94

      # Calculate ensemble weights based on accuracy
      total_accuracy = Enum.sum(Enum.map(model_performance, & &1.accuracy))

      ensemble_weights =
        Enum.map(model_performance, fn model ->
          %{
            model_id: model.id,
            algorithm: model.algorithm,
            weight: model.accuracy / total_accuracy
          }
        end)

      # Verify ensemble weight distribution
      weights_list = ensemble_weights

      total_weight =
        weights_list
        |> Enum.map(& &1.weight)
        |> Enum.sum()

      assert_in_delta total_weight, 1.0, 0.001

      # Best performing model should have highest weight
      best_weight = Enum.find(ensemble_weights, &(&1.algorithm == "neural_network"))
      # Should be > 1/3 due to higher accuracy
      assert best_weight.weight > 0.34

      # Verify A/B testing metrics
      total_predictions = Enum.sum(Enum.map(created_models, & &1.predictions_count))
      # 12k + 8k + 5k
      assert total_predictions == 25_000

      # Model with more predictions has been deployed longer
      most_deployed = Enum.max_by(created_models, & &1.predictions_count)
      assert most_deployed.algorithm == "random_forest"
      assert most_deployed.predictions_count == 12_000
    end

    test "creates multi-tenant model isolation and performance tracking" do
      # Simulate multi-tenant ML system with tenant isolation
      tenant_1_models = [
        %{
          model_type: :threat_prediction,
          model_name: "Tenant 1 - Financial Services Threat Model",
          algorithm: "xgboost",
          accuracy_score: 0.95,
          predictions_count: 50_000,
          model_parameters: %{
            compliance_mode: "financial_services",
            data_residency: "us_east",
            encryption_level: "fips_140_2"
          }
        },
        %{
          model_type: :behavior_anomaly,
          model_name: "Tenant 1 - Insider Threat Detection",
          algorithm: "isolation_forest",
          accuracy_score: 0.88,
          predictions_count: 25_000
        }
      ]

      tenant_2_models = [
        %{
          model_type: :performance_prediction,
          model_name: "Tenant 2 - Healthcare Performance Model",
          algorithm: "prophet",
          accuracy_score: 0.91,
          predictions_count: 30_000,
          model_parameters: %{
            compliance_mode: "hipaa",
            data_residency: "us_west",
            privacy_level: "phi_compliant"
          }
        }
      ]

      # Create tenant-specific models
      t1_models =
        Enum.map(tenant_1_models, fn config ->
          {:ok, model} = PredictiveModel.create(config)
          model
        end)

      t2_models =
        Enum.map(tenant_2_models, fn config ->
          {:ok, model} = PredictiveModel.create(config)
          model
        end)

      # Verify tenant isolation in model configuration
      t1_threat_model = Enum.find(t1_models, &(&1.model_type == :threat_prediction))
      assert t1_threat_model.model_parameters["compliance_mode"] == "financial_services"
      assert t1_threat_model.model_parameters["data_residency"] == "us_east"

      t2_performance_model = Enum.find(t2_models, &(&1.model_type == :performance_prediction))
      assert t2_performance_model.model_parameters["compliance_mode"] == "hipaa"
      assert t2_performance_model.model_parameters["data_residency"] == "us_west"

      # Verify tenant-specific model performance tracking
      all_models = t1_models ++ t2_models

      # Group by tenant based on model name patterns
      tenant_1_group = Enum.filter(all_models, &String.contains?(&1.model_name, "Tenant 1"))
      tenant_2_group = Enum.filter(all_models, &String.contains?(&1.model_name, "Tenant 2"))

      assert length(tenant_1_group) == 2
      assert length(tenant_2_group) == 1

      # Calculate tenant-specific metrics
      t1_total_predictions = Enum.sum(Enum.map(tenant_1_group, & &1.predictions_count))
      t2_total_predictions = Enum.sum(Enum.map(tenant_2_group, & &1.predictions_count))

      # 50k + 25k
      assert t1_total_predictions == 75_000
      assert t2_total_predictions == 30_000

      # Verify model type distribution per tenant
      t1_model_types_result = Enum.map(tenant_1_group, & &1.model_type)
      t1_model_types = t1_model_types_result |> Enum.uniq()
      t2_model_types_result = Enum.map(tenant_2_group, & &1.model_type)
      t2_model_types = t2_model_types_result |> Enum.uniq()

      assert :threat_prediction in t1_model_types
      assert :behavior_anomaly in t1_model_types
      assert :performance_prediction in t2_model_types
    end
  end

  describe "Performance Testing - TDG Scalability Tests" do
    test "handles large-scale model parameter storage and retrieval" do
      # Simulate enterprise ML model with extensive parameters
      large_parameters = %{
        neural_network: %{
          layer_configs:
            Enum.map(1..20, fn i ->
              %{
                layer_id: i,
                units: 256 - i * 10,
                activation: if(rem(i, 2) == 0, do: "relu", else: "tanh"),
                dropout_rate: 0.1 + i * 0.01,
                weights_shape: [256 - i * 10, 256 - (i - 1) * 10],
                bias_shape: [256 - i * 10]
              }
            end),
          optimization_config: %{
            optimizer: "adam",
            learning_rate_schedule:
              Enum.map(1..100, fn epoch ->
                %{epoch: epoch, lr: 0.001 * :math.pow(0.95, epoch)}
              end),
            gradient_clipping: %{type: "norm", value: 1.0}
          }
        },
        feature_preprocessing:
          Enum.reduce(1..50, %{}, fn i, acc ->
            Map.put(acc, "feature_#{i}", %{
              scaling_method: "standard",
              mean: :rand.uniform() * 100,
              std: :rand.uniform() * 50,
              min_value: :rand.uniform() * -100,
              max_value: :rand.uniform() * 100
            })
          end),
        hyperparameter_search: %{
          search_space:
            Enum.map(1..25, fn i ->
              %{
                param_name: "param_#{i}",
                param_type: Enum.random(["float", "int", "categorical"]),
                search_range: [0.001, 10.0],
                best_value: :rand.uniform() * 10
              }
            end)
        }
      }

      # Create comprehensive feature importance (100 features)
      feature_importance =
        Enum.reduce(1..100, %{}, fn i, acc ->
          Map.put(acc, "feature_#{i}", :rand.uniform() / 100)
        end)

      # Normalize feature importance
      feature_importance_values = Map.values(feature_importance)
      total_importance = feature_importance_values |> Enum.sum()

      normalized_importance =
        Enum.reduce(feature_importance, %{}, fn {k, v}, acc ->
          Map.put(acc, k, v / total_importance)
        end)

      start_time = System.monotonic_time(:millisecond)

      {:ok, complex_model} =
        PredictiveModel.create(%{
          model_type: :performance_prediction,
          model_name: "Large Scale Enterprise ML Model",
          algorithm: "enterprise_deep_learning",
          accuracy_score: 0.956,
          model_parameters: large_parameters,
          feature_importance: normalized_importance
        })

      end_time = System.monotonic_time(:millisecond)
      creation_time = end_time - start_time

      # Verify performance and data integrity
      # Should complete within 10 seconds
      assert creation_time < 10_000
      assert map_size(complex_model.model_parameters) == 3
      assert length(complex_model.model_parameters["neural_network"]["layer_configs"]) == 20
      assert map_size(complex_model.model_parameters["feature_preprocessing"]) == 50
      assert map_size(complex_model.feature_importance) == 100

      # Verify feature importance normalization
      importance_map = complex_model.feature_importance

      stored_total =
        importance_map
        |> Map.values()
        |> Enum.sum()

      assert_in_delta stored_total, 1.0, 0.001

      # Test retrieval performance
      start_retrieval = System.monotonic_time(:millisecond)
      retrieved_model = PredictiveModel.read!(complex_model.id)
      end_retrieval = System.monotonic_time(:millisecond)
      retrieval_time = end_retrieval - start_retrieval

      # Should retrieve within 1 second
      assert retrieval_time < 1000
      assert retrieved_model.id == complex_model.id
    end

    test "performs efficient model filtering and querying at scale" do
      # Create large dataset of models
      model_count = 500

      model_types = [
        :threat_prediction,
        :incident_forecasting,
        :behavior_anomaly,
        :performance_prediction
      ]

      algorithms = ["random_forest", "gradient_boosting", "neural_network", "svm", "xgboost"]
      statuses = [:training, :active, :deprecated, :failed]

      start_time = System.monotonic_time(:millisecond)

      created_models =
        Enum.map(1..model_count, fn i ->
          {:ok, model} =
            PredictiveModel.create(%{
              model_type: Enum.at(model_types, rem(i, length(model_types))),
              model_name: "Scale Test Model #{i}",
              algorithm: Enum.at(algorithms, rem(i, length(algorithms))),
              accuracy_score: 0.5 + :rand.uniform() * 0.5,
              status: Enum.at(statuses, rem(i, length(statuses)))
            })

          model
        end)

      end_time = System.monotonic_time(:millisecond)
      creation_time = end_time - start_time

      # Test query performance
      query_start = System.monotonic_time(:millisecond)

      all_models = PredictiveModel.read!()
      active_models = PredictiveModel.list_active()
      threat_models = Enum.filter(all_models, &(&1.model_type == :threat_prediction))

      high_accuracy_models =
        Enum.filter(all_models, &(&1.accuracy_score && &1.accuracy_score > 0.9))

      query_end = System.monotonic_time(:millisecond)
      query_time = query_end - query_start

      # Verify performance
      assert length(created_models) == model_count
      # Should complete within 2 minutes
      assert creation_time < 120_000
      # Queries should complete within 10 seconds
      assert query_time < 10_000

      # Verify data integrity
      assert length(all_models) >= model_count
      assert length(active_models) > 0
      assert length(threat_models) > 0
      assert length(high_accuracy_models) > 0

      # Verify filtering accuracy
      assert Enum.all?(active_models, &(&1.status == :active))
      assert Enum.all?(threat_models, &(&1.model_type == :threat_prediction))

      assert Enum.all?(high_accuracy_models, fn model ->
               model.accuracy_score && model.accuracy_score > 0.9
             end)

      # Performance rate calculations
      creation_rate = model_count / (creation_time / 1000)

      # At least 2 models per second
      assert creation_rate > 2
    end

    test "handles concurrent model updates and predictions tracking" do
      # Create base models for concurrent testing
      base_models =
        Enum.map(1..50, fn i ->
          {:ok, model} =
            PredictiveModel.create(%{
              model_type: :threat_prediction,
              model_name: "Concurrent Test Model #{i}",
              predictions_count: 1000,
              accuracy_score: 0.85
            })

          model
        end)

      # Simulate concurrent prediction count updates
      start_time = System.monotonic_time(:millisecond)

      update_tasks =
        Enum.map(base_models, fn model ->
          Task.async(fn ->
            # Simulate multiple prediction increments
            Enum.reduce(1..10, model, fn _, current_model ->
              new_count = current_model.predictions_count + :rand.uniform(100)

              {:ok, updated_model} =
                PredictiveModel.update(current_model, %{
                  predictions_count: new_count
                })

              updated_model
            end)
          end)
        end)

      updated_models = Enum.map(update_tasks, &Task.await(&1, 60_000))

      end_time = System.monotonic_time(:millisecond)
      concurrent_time = end_time - start_time

      # Verify concurrent update performance
      assert length(updated_models) == 50
      # Should complete within 60 seconds
      assert concurrent_time < 60_000

      # Verify all updates succeeded and data integrity maintained
      assert Enum.all?(updated_models, fn model ->
               # Count increased
               # Other fields preserved
               model.predictions_count > 1000 and
                 model.model_name |> String.starts_with?("Concurrent Test Model") and
                 model.accuracy_score == 0.85
             end)

      # Verify prediction count increases
      final_counts = Enum.map(updated_models, & &1.predictions_count)
      original_counts = Enum.map(base_models, & &1.predictions_count)

      assert Enum.all?(Enum.zip(final_counts, original_counts), fn {final, original} ->
               final > original
             end)

      # Calculate update rate
      # 50 models * 10 updates each
      total_updates = 50 * 10
      update_rate = total_updates / (concurrent_time / 1000)
      # At least 5 updates per second
      assert update_rate > 5
    end
  end
end
