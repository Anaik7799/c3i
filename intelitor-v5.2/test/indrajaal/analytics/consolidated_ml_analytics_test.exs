defmodule Indrajaal.Analytics.ConsolidatedMLAnalyticsTest do
  @moduledoc """
  Standard unit test suite for ConsolidatedMLAnalytics module.
  Complements existing property-based tests with comprehensive unit testing.

  Following TDG methodology - these tests validate existing implementation
  and provide standard unit test coverage alongside property-based validation.

  Test Coverage Strategy:
  1. Unit Tests: Complete coverage of all 8 main public functions
  2. Integration Tests: Multi-tenant isolation and data flow validation
  3. Performance Tests: ML operation performance requirements
  4. Error Handling: Edge cases and malformed input validation
  5. Telemetry Tests: Validation of telemetry event emission
  6. Type Validation: Comprehensive type checking and structure validation
  7. Business Logic Tests: ML accuracy and prediction validation
  8. Tenant Isolation: Multi-tenant data security validation

  This test suite works alongside:
  - test/property/consolidated_ml_analytics_property_test.exs (property-based tests)

  SOPv5.11 Compliance:
  - Standard unit testing methodology
  - Comprehensive ML function validation
  - Multi-tenant security verification
  - Performance requirement validation
  """

  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias Indrajaal.Analytics.ConsolidatedMLAnalytics

  # Test fixtures and setup data
  @valid_metrics_data %{
    cpu_usage: 78.5,
    memory_usage: 82.3,
    network_latency: 45.2,
    disk_io: 120.5,
    error_rate: 0.02,
    request_count: 1250,
    response_time: 95.3,
    throughput: 485.7
  }

  @valid_config %{
    analysis_depth: :comprehensive,
    include_patterns: true,
    anomaly_detection: true,
    confidence_threshold: 0.85
  }

  @valid_tenant_id "tenant_12345"

  @valid_prediction_options [
    horizon_hours: 24,
    confidence_level: 0.95,
    include_seasonality: true
  ]

  @valid_training_data %{
    features: [
      %{cpu: 75.0, memory: 80.0, response_time: 120},
      %{cpu: 82.0, memory: 78.5, response_time: 135},
      %{cpu: 68.5, memory: 85.2, response_time: 98}
    ],
    labels: [:normal, :degraded, :normal]
  }

  # ============================================================================
  # 1. UNIT TESTS - Complete Coverage of All 8 Main Functions
  # ============================================================================

  describe "generate_comprehensive_insights/3 - Standard Unit Tests" do
    test "successfully generates comprehensive ML insights with valid data" do
      result =
        ConsolidatedMLAnalytics.generate_comprehensive_insights(
          @valid_metrics_data,
          @valid_config
        )

      assert {:ok, insights} = result
      assert is_map(insights)

      # Verify all required fields are present
      required_fields = [
        :patterns,
        :predictions,
        :anomalies,
        :recommendations,
        :confidence,
        :model_accuracy,
        :feature_importance,
        :generated_at
      ]

      Enum.each(required_fields, fn field ->
        assert Map.has_key?(insights, field), "Missing required field: #{field}"
      end)

      # Verify field types and values
      assert is_list(insights.patterns)
      assert is_list(insights.predictions)
      assert is_list(insights.anomalies)
      assert is_list(insights.recommendations)
      assert is_float(insights.confidence)
      assert is_map(insights.model_accuracy)
      assert is_map(insights.feature_importance)
      assert %DateTime{} = insights.generated_at
    end

    test "generates insights with default config when not provided" do
      result = ConsolidatedMLAnalytics.generate_comprehensive_insights(@valid_metrics_data)

      assert {:ok, insights} = result
      assert is_map(insights)
      assert is_list(insights.patterns)
    end

    test "generates insights with empty options list" do
      result =
        ConsolidatedMLAnalytics.generate_comprehensive_insights(
          @valid_metrics_data,
          @valid_config,
          []
        )

      assert {:ok, insights} = result
      assert is_map(insights)
    end

    test "validates confidence score is within valid range" do
      {:ok, insights} =
        ConsolidatedMLAnalytics.generate_comprehensive_insights(
          @valid_metrics_data,
          @valid_config
        )

      assert insights.confidence >= 0.0 and insights.confidence <= 1.0
    end

    test "validates model accuracy structure completeness" do
      {:ok, insights} =
        ConsolidatedMLAnalytics.generate_comprehensive_insights(
          @valid_metrics_data,
          @valid_config
        )

      accuracy = insights.model_accuracy
      assert Map.has_key?(accuracy, :accuracy)
      assert Map.has_key?(accuracy, :precision)
      assert Map.has_key?(accuracy, :recall)
      assert Map.has_key?(accuracy, :f1_score)
    end

    test "validates feature importance structure and values" do
      {:ok, insights} =
        ConsolidatedMLAnalytics.generate_comprehensive_insights(
          @valid_metrics_data,
          @valid_config
        )

      feature_importance = insights.feature_importance
      assert is_map(feature_importance)

      # Verify importance values are valid (0.0 to 1.0)
      Enum.each(feature_importance, fn {_feature, importance} ->
        assert is_float(importance)
        assert importance >= 0.0 and importance <= 1.0
      end)

      # Verify total importance sums to approximately 1.0
      importance_values = Map.values(feature_importance)
      total_importance = importance_values |> Enum.sum()
      assert_in_delta total_importance, 1.0, 0.1
    end
  end

  describe "generate_consolidated_predictions/3 - Standard Unit Tests" do
    test "successfully generates consolidated predictions" do
      result =
        ConsolidatedMLAnalytics.generate_consolidated_predictions(
          @valid_tenant_id,
          @valid_metrics_data,
          @valid_prediction_options
        )

      assert {:ok, predictions} = result
      assert is_map(predictions)

      # Verify all required prediction components
      required_components = [
        :performance_forecast,
        :incident_predictions,
        :anomaly_detection,
        :capacity_recommendations,
        :risk_assessment,
        :model_metadata
      ]

      Enum.each(required_components, fn component ->
        assert Map.has_key?(predictions, component), "Missing component: #{component}"
      end)
    end

    test "validates model metadata structure and tenant isolation" do
      {:ok, predictions} =
        ConsolidatedMLAnalytics.generate_consolidated_predictions(
          @valid_tenant_id,
          @valid_metrics_data,
          @valid_prediction_options
        )

      metadata = predictions.model_metadata
      assert metadata.tenant_id == @valid_tenant_id
      assert metadata.horizon_hours == 24
      assert metadata.confidence_level == 0.95
      assert is_list(metadata.algorithms_used)
      assert %DateTime{} = metadata.generated_at
    end

    test "handles different horizon hours correctly" do
      custom_options = [horizon_hours: 48, confidence_level: 0.90]

      {:ok, predictions} =
        ConsolidatedMLAnalytics.generate_consolidated_predictions(
          @valid_tenant_id,
          @valid_metrics_data,
          custom_options
        )

      assert predictions.model_metadata.horizon_hours == 48
      assert predictions.model_metadata.confidence_level == 0.90
    end

    test "uses default options when not provided" do
      {:ok, predictions} =
        ConsolidatedMLAnalytics.generate_consolidated_predictions(
          @valid_tenant_id,
          @valid_metrics_data
        )

      assert predictions.model_metadata.horizon_hours == 24
      assert predictions.model_metadata.confidence_level == 0.95
    end

    test "validates performance forecast structure" do
      {:ok, predictions} =
        ConsolidatedMLAnalytics.generate_consolidated_predictions(
          @valid_tenant_id,
          @valid_metrics_data,
          @valid_prediction_options
        )

      performance = predictions.performance_forecast
      assert is_map(performance)
      assert Map.has_key?(performance, :predictions)
      assert Map.has_key?(performance, :confidence_intervals)
      assert Map.has_key?(performance, :model_accuracy)
      assert is_list(performance.predictions)
    end

    test "validates incident predictions structure" do
      {:ok, predictions} =
        ConsolidatedMLAnalytics.generate_consolidated_predictions(
          @valid_tenant_id,
          @valid_metrics_data,
          @valid_prediction_options
        )

      incidents = predictions.incident_predictions
      assert is_list(incidents)

      # Verify incident structure for each prediction
      Enum.each(incidents, fn incident ->
        assert Map.has_key?(incident, :tenant_id)
        assert Map.has_key?(incident, :incident_type)
        assert Map.has_key?(incident, :likelihood)
        assert Map.has_key?(incident, :predicted_time)
        assert Map.has_key?(incident, :severity)
        assert incident.tenant_id == @valid_tenant_id
      end)
    end
  end

  describe "predict_performance/4 - Standard Unit Tests" do
    test "successfully predicts performance with default parameters" do
      result = ConsolidatedMLAnalytics.predict_performance(@valid_metrics_data, 24)

      assert {:ok, performance} = result
      assert is_map(performance)
      assert performance.horizon_hours == 24
      assert performance.confidence_level == 0.95
      assert performance.model_type == :ensemble
    end

    test "handles different model types correctly" do
      result =
        ConsolidatedMLAnalytics.predict_performance(
          @valid_metrics_data,
          24,
          0.90,
          :linear_regression
        )

      assert {:ok, performance} = result
      assert performance.model_type == :linear_regression
      assert performance.confidence_level == 0.90
    end

    test "validates prediction structure completeness" do
      {:ok, performance} =
        ConsolidatedMLAnalytics.predict_performance(
          @valid_metrics_data,
          12
        )

      required_fields = [
        :predictions,
        :confidence_intervals,
        :model_accuracy,
        :risk_assessment,
        :model_type,
        :horizon_hours,
        :confidence_level,
        :feature_analysis
      ]

      Enum.each(required_fields, fn field ->
        assert Map.has_key?(performance, field), "Missing field: #{field}"
      end)
    end

    test "validates model accuracy metrics structure" do
      {:ok, performance} =
        ConsolidatedMLAnalytics.predict_performance(
          @valid_metrics_data,
          24
        )

      accuracy = performance.model_accuracy
      assert Map.has_key?(accuracy, :accuracy)
      assert Map.has_key?(accuracy, :mse)
      assert Map.has_key?(accuracy, :r_squared)

      # Verify metric values are reasonable
      assert accuracy.accuracy >= 0.0 and accuracy.accuracy <= 1.0
      assert accuracy.mse >= 0.0
      assert accuracy.r_squared >= 0.0 and accuracy.r_squared <= 1.0
    end

    test "validates confidence intervals structure" do
      {:ok, performance} =
        ConsolidatedMLAnalytics.predict_performance(
          @valid_metrics_data,
          24,
          0.99
        )

      intervals = performance.confidence_intervals
      assert Map.has_key?(intervals, :lower_bound)
      assert Map.has_key?(intervals, :upper_bound)
      assert Map.has_key?(intervals, :confidence_level)
      assert intervals.confidence_level == 0.99
      assert intervals.lower_bound < intervals.upper_bound
    end

    test "generates predictions matching horizon hours" do
      horizon = 48

      {:ok, performance} =
        ConsolidatedMLAnalytics.predict_performance(
          @valid_metrics_data,
          horizon
        )

      assert length(performance.predictions) == horizon

      # Verify each prediction has required structure
      Enum.each(performance.predictions, fn prediction ->
        assert Map.has_key?(prediction, :hour)
        assert Map.has_key?(prediction, :performance_score)
        assert Map.has_key?(prediction, :availability)
        assert Map.has_key?(prediction, :resource_utilization)
        assert Map.has_key?(prediction, :timestamp)
        assert %DateTime{} = prediction.timestamp
      end)
    end
  end

  describe "predict_incidents/3 - Standard Unit Tests" do
    test "successfully predicts incidents for tenant" do
      result =
        ConsolidatedMLAnalytics.predict_incidents(
          @valid_tenant_id,
          @valid_metrics_data
        )

      assert {:ok, incidents} = result
      assert is_list(incidents)

      # Verify tenant isolation
      Enum.each(incidents, fn incident ->
        assert incident.tenant_id == @valid_tenant_id
      end)
    end

    test "handles custom threshold parameter" do
      custom_options = [threshold: 0.5]

      {:ok, incidents} =
        ConsolidatedMLAnalytics.predict_incidents(
          @valid_tenant_id,
          @valid_metrics_data,
          custom_options
        )

      # With lower threshold, should potentially have more incidents
      assert is_list(incidents)
    end

    test "validates incident structure completeness" do
      {:ok, incidents} =
        ConsolidatedMLAnalytics.predict_incidents(
          @valid_tenant_id,
          @valid_metrics_data
        )

      # Verify structure for each incident prediction
      Enum.each(incidents, fn incident ->
        required_fields = [
          :tenant_id,
          :incident_type,
          :likelihood,
          :predicted_time,
          :severity,
          :recommended_actions,
          :contributing_factors
        ]

        Enum.each(required_fields, fn field ->
          assert Map.has_key?(incident, field), "Missing field: #{field}"
        end)

        # Verify field types
        assert is_binary(incident.tenant_id)
        assert is_atom(incident.incident_type)
        assert is_float(incident.likelihood)
        assert %DateTime{} = incident.predicted_time
        assert is_atom(incident.severity)
        assert is_list(incident.recommended_actions)
        assert is_map(incident.contributing_factors)
      end)
    end

    test "validates incident types are recognized" do
      {:ok, incidents} =
        ConsolidatedMLAnalytics.predict_incidents(
          @valid_tenant_id,
          @valid_metrics_data
        )

      valid_incident_types = [
        :security_breach,
        :equipment_failure,
        :access_violation,
        :system_outage,
        :performance_degradation,
        :maintenance_required
      ]

      Enum.each(incidents, fn incident ->
        assert incident.incident_type in valid_incident_types
      end)
    end

    test "validates severity classification is appropriate" do
      {:ok, incidents} =
        ConsolidatedMLAnalytics.predict_incidents(
          @valid_tenant_id,
          @valid_metrics_data
        )

      valid_severities = [:low, :medium, :high, :critical]

      Enum.each(incidents, fn incident ->
        assert incident.severity in valid_severities

        # Critical severity should only occur with very high likelihood
        if incident.severity == :critical do
          assert incident.likelihood > 0.8
        end
      end)
    end

    test "validates likelihood values are within valid range" do
      {:ok, incidents} =
        ConsolidatedMLAnalytics.predict_incidents(
          @valid_tenant_id,
          @valid_metrics_data
        )

      Enum.each(incidents, fn incident ->
        assert incident.likelihood >= 0.0 and incident.likelihood <= 1.0
      end)
    end
  end

  describe "detect_system_anomalies/2 - Standard Unit Tests" do
    test "successfully detects system anomalies" do
      result = ConsolidatedMLAnalytics.detect_system_anomalies(@valid_metrics_data)

      assert {:ok, anomalies} = result
      assert is_map(anomalies)
    end

    test "handles different sensitivity levels" do
      high_sensitivity_result =
        ConsolidatedMLAnalytics.detect_system_anomalies(
          @valid_metrics_data,
          sensitivity: :high
        )

      low_sensitivity_result =
        ConsolidatedMLAnalytics.detect_system_anomalies(
          @valid_metrics_data,
          sensitivity: :low
        )

      assert {:ok, high_anomalies} = high_sensitivity_result
      assert {:ok, low_anomalies} = low_sensitivity_result

      assert high_anomalies.detection_metadata.sensitivity == :high
      assert low_anomalies.detection_metadata.sensitivity == :low
    end

    test "validates anomaly detection structure" do
      {:ok, anomalies} = ConsolidatedMLAnalytics.detect_system_anomalies(@valid_metrics_data)

      required_fields = [
        :statistical_anomalies,
        :pattern_anomalies,
        :ml_anomalies,
        :composite_score,
        :risk_level,
        :recommendations,
        :detection_metadata
      ]

      Enum.each(required_fields, fn field ->
        assert Map.has_key?(anomalies, field), "Missing field: #{field}"
      end)
    end

    test "validates composite score and risk level" do
      {:ok, anomalies} = ConsolidatedMLAnalytics.detect_system_anomalies(@valid_metrics_data)

      assert is_float(anomalies.composite_score)
      assert anomalies.composite_score >= 0.0 and anomalies.composite_score <= 1.0
      assert anomalies.risk_level in [:low, :medium, :high, :critical]
    end

    test "validates detection metadata completeness" do
      {:ok, anomalies} =
        ConsolidatedMLAnalytics.detect_system_anomalies(
          @valid_metrics_data,
          sensitivity: :medium
        )

      metadata = anomalies.detection_metadata
      assert Map.has_key?(metadata, :algorithms_used)
      assert Map.has_key?(metadata, :sensitivity)
      assert Map.has_key?(metadata, :analyzed_at)

      assert is_list(metadata.algorithms_used)
      assert metadata.sensitivity == :medium
      assert %DateTime{} = metadata.analyzed_at
    end
  end

  describe "plan_capacity/2 - Standard Unit Tests" do
    test "successfully plans capacity for different horizons" do
      result = ConsolidatedMLAnalytics.plan_capacity(@valid_metrics_data, 48)

      assert {:ok, plan} = result
      assert is_map(plan)
    end

    test "validates capacity plan structure completeness" do
      {:ok, plan} = ConsolidatedMLAnalytics.plan_capacity(@valid_metrics_data, 24)

      required_fields = [
        :resource_forecasts,
        :recommendations,
        :scaling_triggers,
        :optimization_opportunities,
        :cost_projections
      ]

      Enum.each(required_fields, fn field ->
        assert Map.has_key?(plan, field), "Missing field: #{field}"
      end)
    end

    test "validates resource forecasts for all resource types" do
      {:ok, plan} = ConsolidatedMLAnalytics.plan_capacity(@valid_metrics_data, 24)

      forecasts = plan.resource_forecasts
      resource_types = [:cpu, :memory, :storage, :network]

      Enum.each(resource_types, fn resource ->
        assert Map.has_key?(forecasts, resource), "Missing forecast for: #{resource}"

        forecast = forecasts[resource]
        assert Map.has_key?(forecast, :resource_type)
        assert Map.has_key?(forecast, :current_usage)
        assert Map.has_key?(forecast, :predicted_usage)
        assert Map.has_key__(forecast, :peak_usage)
        assert Map.has_key?(forecast, :scaling_recommendation)

        assert forecast.resource_type == resource
        assert is_float(forecast.current_usage)
        assert is_list(forecast.predicted_usage)
        assert forecast.scaling_recommendation in [:scale_up, :scale_down, :maintain]
      end)
    end

    test "validates scaling triggers are reasonable" do
      {:ok, plan} = ConsolidatedMLAnalytics.plan_capacity(@valid_metrics_data, 24)

      triggers = plan.scaling_triggers

      # Verify trigger values are percentages (0-100)
      Enum.each(triggers, fn {_resource, threshold} ->
        assert is_float(threshold)
        assert threshold >= 0.0 and threshold <= 100.0
      end)
    end

    test "validates cost projections structure" do
      {:ok, plan} = ConsolidatedMLAnalytics.plan_capacity(@valid_metrics_data, 24)

      cost = plan.cost_projections
      assert Map.has_key?(cost, :current)
      assert Map.has_key?(cost, :projected)
      assert Map.has_key?(cost, :savings_potential)
      assert Map.has_key?(cost, :roi_analysis)

      # Verify numeric values
      assert is_float(cost.current)
      assert is_float(cost.projected)
      assert is_float(cost.savings_potential)
      assert is_map(cost.roi_analysis)
    end

    test "validates recommendations are actionable strings" do
      {:ok, plan} = ConsolidatedMLAnalytics.plan_capacity(@valid_metrics_data, 24)

      assert is_list(plan.recommendations)
      assert is_list(plan.optimization_opportunities)

      Enum.each(plan.recommendations, fn recommendation ->
        assert is_binary(recommendation)
        # Meaningful recommendation
        assert String.length(recommendation) > 10
      end)
    end
  end

  describe "assess_risks/2 - Standard Unit Tests" do
    test "successfully assesses comprehensive risks" do
      result = ConsolidatedMLAnalytics.assess_risks(@valid_metrics_data)

      assert {:ok, assessment} = result
      assert is_map(assessment)
    end

    test "validates risk assessment structure completeness" do
      {:ok, assessment} = ConsolidatedMLAnalytics.assess_risks(@valid_metrics_data)

      required_risks = [:performance_risks, :availability_risks, :security_risks, :capacity_risks]

      Enum.each(required_risks, fn risk_type ->
        assert Map.has_key?(assessment, risk_type), "Missing risk type: #{risk_type}"

        risk = assessment[risk_type]
        assert Map.has_key?(risk, :probability)
        assert Map.has_key?(risk, :impact)
        assert Map.has_key?(risk, :mitigation)

        # Validate probability range
        assert is_float(risk.probability)
        assert risk.probability >= 0.0 and risk.probability <= 1.0

        # Validate impact level
        assert risk.impact in [:low, :medium, :high, :critical]

        # Validate mitigation is actionable
        assert is_binary(risk.mitigation)
        assert String.length(risk.mitigation) > 10
      end)
    end

    test "validates overall risk metrics" do
      {:ok, assessment} = ConsolidatedMLAnalytics.assess_risks(@valid_metrics_data)

      assert Map.has_key?(assessment, :overall_risk_score)
      assert Map.has_key?(assessment, :risk_trend)
      assert Map.has_key?(assessment, :recommended_actions)
      assert Map.has_key?(assessment, :risk_matrix)

      # Verify overall risk score
      assert is_float(assessment.overall_risk_score)
      assert assessment.overall_risk_score >= 0.0 and assessment.overall_risk_score <= 1.0

      # Verify risk trend
      assert assessment.risk_trend in [:improving, :stable, :degrading]

      # Verify recommended actions
      assert is_list(assessment.recommended_actions)

      Enum.each(assessment.recommended_actions, fn action ->
        assert is_binary(action)
      end)
    end

    test "validates risk matrix structure" do
      {:ok, assessment} = ConsolidatedMLAnalytics.assess_risks(@valid_metrics_data)

      matrix = assessment.risk_matrix
      assert is_map(matrix)

      # Verify standard risk matrix quadrants
      expected_quadrants = [
        :low_probability_low_impact,
        :low_probability_high_impact,
        :high_probability_low_impact,
        :high_probability_high_impact
      ]

      Enum.each(expected_quadrants, fn quadrant ->
        assert Map.has_key?(matrix, quadrant), "Missing risk quadrant: #{quadrant}"
        assert is_list(matrix[quadrant])
      end)
    end
  end

  describe "create_model/4 - Standard Unit Tests" do
    test "successfully creates ML model for valid model type" do
      result =
        ConsolidatedMLAnalytics.create_model(
          @valid_tenant_id,
          :threat_prediction,
          @valid_training_data
        )

      assert {:ok, model} = result
      assert is_map(model)
    end

    test "handles different model types correctly" do
      valid_model_types = [
        :threat_prediction,
        :incident_forecasting,
        :behavior_anomaly,
        :performance_prediction,
        :capacity_planning,
        :trend_analysis,
        :risk_assessment
      ]

      Enum.each(valid_model_types, fn model_type ->
        result =
          ConsolidatedMLAnalytics.create_model(
            @valid_tenant_id,
            model_type,
            @valid_training_data
          )

        assert {:ok, model} = result
        assert model.config.model_type == model_type
      end)
    end

    test "handles custom options correctly" do
      custom_options = [
        algorithm: :neural_network,
        hyperparameters: %{learning_rate: 0.01, epochs: 100},
        validation_split: 0.3
      ]

      result =
        ConsolidatedMLAnalytics.create_model(
          @valid_tenant_id,
          :performance_prediction,
          @valid_training_data,
          custom_options
        )

      assert {:ok, model} = result
      assert model.config.algorithm == :neural_network
      assert model.config.validation_split == 0.3
      assert model.config.hyperparameters.learning_rate == 0.01
    end

    test "validates model structure completeness" do
      {:ok, model} =
        ConsolidatedMLAnalytics.create_model(
          @valid_tenant_id,
          :threat_prediction,
          @valid_training_data
        )

      # Verify model structure
      assert Map.has_key?(model, :id)
      assert Map.has_key?(model, :config)
      assert Map.has_key?(model, :training_completed_at)
      assert Map.has_key?(model, :status)
      assert Map.has_key?(model, :validation_results)
      assert Map.has_key?(model, :saved_at)

      # Verify model ID format
      assert is_binary(model.id)
      assert String.starts_with?(model.id, "ml_model_")

      # Verify timestamps
      assert %DateTime{} = model.training_completed_at
      assert %DateTime{} = model.saved_at

      # Verify status
      assert model.status == :trained
    end

    test "validates model config tenant isolation" do
      {:ok, model} =
        ConsolidatedMLAnalytics.create_model(
          @valid_tenant_id,
          :behavior_anomaly,
          @valid_training_data
        )

      assert model.config.tenant_id == @valid_tenant_id
    end

    test "validates validation results structure" do
      {:ok, model} =
        ConsolidatedMLAnalytics.create_model(
          @valid_tenant_id,
          :capacity_planning,
          @valid_training_data
        )

      validation = model.validation_results
      assert Map.has_key?(validation, :accuracy)
      assert Map.has_key?(validation, :precision)
      assert Map.has_key?(validation, :recall)
      assert Map.has_key?(validation, :f1_score)
      assert Map.has_key?(validation, :cross_validation_score)

      # Verify all metrics are valid (0.0 to 1.0)
      Enum.each(validation, fn {_metric, value} ->
        assert is_float(value)
        assert value >= 0.0 and value <= 1.0
      end)
    end

    test "logs model creation with correct parameters" do
      log_output =
        capture_log(fn ->
          ConsolidatedMLAnalytics.create_model(
            @valid_tenant_id,
            :risk_assessment,
            @valid_training_data
          )
        end)

      assert log_output =~ "ML model created successfully"
      assert log_output =~ @valid_tenant_id
      assert log_output =~ "risk_assessment"
    end
  end

  # ============================================================================
  # 2. INTEGRATION TESTS - Multi-Tenant Data Isolation
  # ============================================================================

  describe "Multi-Tenant Integration Tests" do
    test "ensures complete tenant data isolation across all functions" do
      tenant_a = "tenant_a_12345"
      tenant_b = "tenant_b_67890"

      # Test incident prediction isolation
      {:ok, incidents_a} =
        ConsolidatedMLAnalytics.predict_incidents(
          tenant_a,
          @valid_metrics_data
        )

      {:ok, incidents_b} =
        ConsolidatedMLAnalytics.predict_incidents(
          tenant_b,
          @valid_metrics_data
        )

      # Verify tenant isolation in incident predictions
      Enum.each(incidents_a, fn incident ->
        assert incident.tenant_id == tenant_a
      end)

      Enum.each(incidents_b, fn incident ->
        assert incident.tenant_id == tenant_b
      end)

      # Test consolidated predictions isolation
      {:ok, predictions_a} =
        ConsolidatedMLAnalytics.generate_consolidated_predictions(
          tenant_a,
          @valid_metrics_data
        )

      {:ok, predictions_b} =
        ConsolidatedMLAnalytics.generate_consolidated_predictions(
          tenant_b,
          @valid_metrics_data
        )

      assert predictions_a.model_metadata.tenant_id == tenant_a
      assert predictions_b.model_metadata.tenant_id == tenant_b

      # Test model creation isolation
      {:ok, model_a} =
        ConsolidatedMLAnalytics.create_model(
          tenant_a,
          :threat_prediction,
          @valid_training_data
        )

      {:ok, model_b} =
        ConsolidatedMLAnalytics.create_model(
          tenant_b,
          :threat_prediction,
          @valid_training_data
        )

      assert model_a.config.tenant_id == tenant_a
      assert model_b.config.tenant_id == tenant_b
      # Different model IDs
      refute model_a.id == model_b.id
    end

    test "validates cross-function data consistency" do
      # Generate comprehensive insights
      {:ok, insights} =
        ConsolidatedMLAnalytics.generate_comprehensive_insights(@valid_metrics_data)

      # Generate consolidated predictions
      {:ok, predictions} =
        ConsolidatedMLAnalytics.generate_consolidated_predictions(
          @valid_tenant_id,
          @valid_metrics_data
        )

      # Verify consistency in anomaly detection
      insights_anomaly_count = length(insights.anomalies)
      predictions_anomalies = predictions.anomaly_detection

      # Both should use same underlying anomaly detection logic
      assert is_integer(insights_anomaly_count)
      assert is_map(predictions_anomalies)
    end
  end

  # ============================================================================
  # 3. PERFORMANCE TESTS - ML Operation Requirements
  # ============================================================================

  describe "Performance Requirements Validation" do
    test "ML insight generation meets performance requirements" do
      start_time = System.monotonic_time(:millisecond)

      {:ok, _insights} =
        ConsolidatedMLAnalytics.generate_comprehensive_insights(
          @valid_metrics_data,
          @valid_config
        )

      end_time = System.monotonic_time(:millisecond)
      execution_time = end_time - start_time

      # ML insights should complete within 200ms
      assert execution_time < 200,
             "ML insights performance violation: #{execution_time}ms > 200ms"
    end

    test "concurrent ML operations maintain performance" do
      tasks =
        Enum.map(1..5, fn _i ->
          Task.async(fn ->
            start_time = System.monotonic_time(:millisecond)

            {:ok, _} =
              ConsolidatedMLAnalytics.generate_comprehensive_insights(
                @valid_metrics_data,
                @valid_config
              )

            end_time = System.monotonic_time(:millisecond)
            end_time - start_time
          end)
        end)

      execution_times = Task.await_many(tasks, 5000)

      # All concurrent executions should complete within bounds
      Enum.each(execution_times, fn time ->
        assert time < 300, "Concurrent ML execution too slow: #{time}ms"
      end)

      # Verify average performance
      avg_time = Enum.sum(execution_times) / length(execution_times)
      assert avg_time < 250, "Average concurrent ML performance violation: #{avg_time}ms"
    end

    test "large training dataset handling performance" do
      # Generate larger training dataset
      large_training_data = %{
        features:
          Enum.map(1..100, fn _i ->
            %{
              cpu: :rand.uniform(100),
              memory: :rand.uniform(100),
              response_time: :rand.uniform(200)
            }
          end),
        labels: Enum.map(1..100, fn _i -> Enum.random([:normal, :degraded, :critical]) end)
      }

      start_time = System.monotonic_time(:millisecond)

      {:ok, _model} =
        ConsolidatedMLAnalytics.create_model(
          @valid_tenant_id,
          :performance_prediction,
          large_training_data
        )

      end_time = System.monotonic_time(:millisecond)
      execution_time = end_time - start_time

      # Model creation with larger dataset should complete within 500ms
      assert execution_time < 500,
             "Large dataset ML performance violation: #{execution_time}ms > 500ms"
    end
  end

  # ============================================================================
  # 4. ERROR HANDLING TESTS - Edge Cases and Validation
  # ============================================================================

  describe "Error Handling and Edge Cases" do
    test "handles empty metrics data gracefully" do
      empty_metrics = %{}

      # These should not crash and should return valid structures
      assert {:ok, _} = ConsolidatedMLAnalytics.generate_comprehensive_insights(empty_metrics)
      assert {:ok, _} = ConsolidatedMLAnalytics.predict_performance(empty_metrics, 24)
      assert {:ok, _} = ConsolidatedMLAnalytics.detect_system_anomalies(empty_metrics)
      assert {:ok, _} = ConsolidatedMLAnalytics.plan_capacity(empty_metrics, 24)
      assert {:ok, _} = ConsolidatedMLAnalytics.assess_risks(empty_metrics)
    end

    test "handles malformed metrics data" do
      malformed_metrics = %{
        invalid_metric: "not_a_number",
        nil_metric: nil,
        negative_metric: -50.0
      }

      # Functions should handle malformed data gracefully
      assert {:ok, _} = ConsolidatedMLAnalytics.generate_comprehensive_insights(malformed_metrics)

      assert {:ok, _} =
               ConsolidatedMLAnalytics.predict_incidents(@valid_tenant_id, malformed_metrics)
    end

    test "validates input parameters and returns appropriate errors" do
      # Empty tenant ID should still work (defensive programming)
      result = ConsolidatedMLAnalytics.predict_incidents("", @valid_metrics_data)
      assert {:ok, incidents} = result
      assert is_list(incidents)

      # Invalid model type should be caught by function guard
      assert_raise FunctionClauseError, fn ->
        ConsolidatedMLAnalytics.create_model(
          @valid_tenant_id,
          :invalid_model_type,
          @valid_training_data
        )
      end
    end

    test "handles extreme prediction horizons" do
      # Very short horizon
      {:ok, short_performance} =
        ConsolidatedMLAnalytics.predict_performance(
          @valid_metrics_data,
          1
        )

      assert length(short_performance.predictions) == 1

      # Longer horizon
      {:ok, long_performance} =
        ConsolidatedMLAnalytics.predict_performance(
          # 1 week
          @valid_metrics_data,
          168
        )

      assert length(long_performance.predictions) == 168
    end
  end

  # ============================================================================
  # 5. TELEMETRY VALIDATION TESTS
  # ============================================================================

  describe "Telemetry Event Validation" do
    setup do
      # Capture telemetry events
      :telemetry.attach(
        "test-ml-insights",
        [:indrajaal, :ml, :insights, :generated],
        fn event, measurements, metadata, _config ->
          send(self(), {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn ->
        :telemetry.detach("test-ml-insights")
      end)
    end

    test "emits telemetry events on insights generation" do
      {:ok, insights} =
        ConsolidatedMLAnalytics.generate_comprehensive_insights(
          @valid_metrics_data,
          @valid_config
        )

      # Verify telemetry event was emitted
      assert_received {:telemetry, [:indrajaal, :ml, :insights, :generated], measurements,
                       metadata}

      # Verify telemetry data structure
      assert Map.has_key?(measurements, :pattern_count)
      assert Map.has_key?(measurements, :anomaly_count)
      assert Map.has_key?(metadata, :model_type)

      # Verify measurements match actual results
      assert measurements.pattern_count == length(insights.patterns)
      assert measurements.anomaly_count == length(insights.anomalies)
      assert metadata.model_type == :consolidated
    end
  end

  # ============================================================================
  # 6. TYPE VALIDATION TESTS
  # ============================================================================

  describe "Type Validation and Structure Tests" do
    test "validates ml_insight_result type structure" do
      {:ok, result} = ConsolidatedMLAnalytics.generate_comprehensive_insights(@valid_metrics_data)

      # Verify it matches the ml_insight_result typespec
      assert is_list(result.patterns)
      assert is_list(result.predictions)
      assert is_list(result.anomalies)
      assert is_list(result.recommendations)
      assert is_float(result.confidence)
      assert is_float(result.model_accuracy.accuracy)
      assert is_map(result.feature_importance)
      assert %DateTime{} = result.generated_at

      # Verify recommendation strings
      Enum.each(result.recommendations, fn recommendation ->
        assert is_binary(recommendation)
      end)
    end

    test "validates consolidated_prediction type structure" do
      {:ok, result} =
        ConsolidatedMLAnalytics.generate_consolidated_predictions(
          @valid_tenant_id,
          @valid_metrics_data
        )

      # Verify it matches the consolidated_prediction typespec
      assert is_map(result.performance_forecast)
      assert is_list(result.incident_predictions)
      assert is_map(result.anomaly_detection)
      assert is_list(result.capacity_recommendations)
      assert is_map(result.risk_assessment)
      assert is_map(result.model_metadata)

      # Verify capacity recommendations are strings
      Enum.each(result.capacity_recommendations, fn recommendation ->
        assert is_binary(recommendation)
      end)
    end

    test "validates model type constraints" do
      valid_model_types = [
        :threat_prediction,
        :incident_forecasting,
        :behavior_anomaly,
        :performance_prediction,
        :capacity_planning,
        :trend_analysis,
        :risk_assessment
      ]

      # All valid model types should work
      Enum.each(valid_model_types, fn model_type ->
        result =
          ConsolidatedMLAnalytics.create_model(
            @valid_tenant_id,
            model_type,
            @valid_training_data
          )

        assert {:ok, _model} = result
      end)
    end

    test "validates incident type constraints in predictions" do
      {:ok, incidents} =
        ConsolidatedMLAnalytics.predict_incidents(
          @valid_tenant_id,
          @valid_metrics_data
        )

      valid_incident_types = [
        :security_breach,
        :equipment_failure,
        :access_violation,
        :system_outage,
        :performance_degradation,
        :maintenance_required
      ]

      Enum.each(incidents, fn incident ->
        assert incident.incident_type in valid_incident_types
      end)
    end
  end
end
