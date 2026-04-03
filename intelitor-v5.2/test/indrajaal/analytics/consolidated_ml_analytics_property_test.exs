defmodule Indrajaal.Analytics.ConsolidatedMLAnalyticsPropertyTest do
  @moduledoc """
  Property-based tests for ConsolidatedMLAnalytics module.

  Tests ML analytics functionality using dual property testing approach:
  - PropCheck: Advanced property testing with sophisticated shrinking
  - ExUnitProperties: StreamData-based property testing

  Agent: Executive Director validates ML analytics via property testing
  SOPv5.11 Compliance: Cybernetic feedback loops with comprehensive validation
  TDG Methodology: Tests written before implementation for consolidated ML analytics
  """

  use ExUnit.Case, async: true
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  # EP-GEN-014: Import ExUnitProperties with except clause to avoid conflicts
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # Disambiguation aliases per EP-GEN-014 pattern
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Analytics.ConsolidatedMLAnalytics

  @moduletag :property_test

  # PropCheck generators for ML testing
  def tenant_id_gen do
    let id <- non_empty(PC.binary()) do
      "tenant_#{id}"
    end
  end

  def model_type_gen do
    PC.oneof([
      :threat_prediction,
      :incident_forecasting,
      :behavior_anomaly,
      :performance_prediction,
      :capacity_planning,
      :trend_analysis,
      :risk_assessment
    ])
  end

  def incident_type_gen do
    PC.oneof([
      :security_breach,
      :equipment_failure,
      :access_violation,
      :system_outage,
      :performance_degradation,
      :maintenance_required
    ])
  end

  def metrics_data_gen do
    let {cpu, memory, network, disk, error_rate, request_count} <- {
          choose(0, 100),
          choose(0, 100),
          choose(0, 1000),
          choose(0, 100),
          choose(0, 100),
          choose(0, 10_000)
        } do
      %{
        cpu_usage: cpu,
        memory_usage: memory,
        network_latency: network,
        disk_io: disk,
        error_rate: error_rate,
        request_count: request_count,
        timestamp: DateTime.utc_now()
      }
    end
  end

  def ml_config_gen do
    let {algorithm, horizon, confidence_raw, threshold_raw} <- {
          PC.oneof([:ensemble, :linear_regression, :neural_network]),
          choose(1, 168),
          choose(50, 99),
          choose(50, 95)
        } do
      confidence = confidence_raw |> resize(fn x -> x / 100 end)
      threshold = threshold_raw |> resize(fn x -> x / 100 end)

      %{
        algorithm: algorithm,
        horizon_hours: horizon,
        confidence_level: confidence,
        threshold: threshold
      }
    end
  end

  # PropCheck property tests with advanced shrinking
  describe "PropCheck property tests" do
    property "comprehensive insights always return valid structure", [:verbose] do
      forall {metrics, config} <- {metrics_data_gen(), ml_config_gen()} do
        result =
          case ConsolidatedMLAnalytics.generate_comprehensive_insights(metrics, config) do
            {:ok, insights} ->
              validate_insight_structure(insights) and
                validate_confidence_bounds(insights) and
                validate_timestamps(insights)

            {:error, _reason} ->
              # Error cases are acceptable for invalid inputs
              true
          end

        classify(
          metrics.cpu_usage > 80,
          :high_cpu,
          classify(
            metrics.memory_usage > 80,
            :high_memory,
            classify(metrics.error_rate > 50, :high_error_rate, result)
          )
        )
      end
    end

    property "performance predictions maintain consistency", [:verbose] do
      forall {metrics, horizon, confidence} <-
               {metrics_data_gen(), choose(1, 72), choose(0.5, 0.99)} do
        case ConsolidatedMLAnalytics.predict_performance(metrics, horizon, confidence) do
          {:ok, predictions} ->
            validate_performance_structure(predictions) and
              validate_prediction_horizon(predictions, horizon) and
              validate_confidence_intervals(predictions, confidence)

          {:error, _reason} ->
            true
        end
      end
    end

    property "incident predictions have valid likelihoods", [:verbose] do
      forall {tenant_id, metrics} <- {tenant_id_gen(), metrics_data_gen()} do
        case ConsolidatedMLAnalytics.predict_incidents(tenant_id, metrics) do
          {:ok, incidents} ->
            Enum.all?(incidents, fn incident ->
              validate_incident_structure(incident) and
                validate_likelihood_bounds(incident) and
                validate_incident_types(incident)
            end)

          {:error, _reason} ->
            true
        end
      end
    end

    property "anomaly detection returns bounded scores", [:verbose] do
      forall metrics <- metrics_data_gen() do
        case ConsolidatedMLAnalytics.detect_system_anomalies(metrics) do
          {:ok, anomalies} ->
            validate_anomaly_structure(anomalies) and
              validate_anomaly_scores(anomalies) and
              validate_risk_levels(anomalies)

          {:error, _reason} ->
            true
        end
      end
    end

    property "capacity planning provides valid forecasts", [:verbose] do
      forall {metrics, horizon} <- {metrics_data_gen(), PC.choose(1, 168)} do
        case ConsolidatedMLAnalytics.plan_capacity(metrics, horizon) do
          {:ok, capacity} ->
            validate_capacity_structure(capacity) and
              validate_resource_forecasts(capacity) and
              validate_scaling_triggers(capacity)

          {:error, _reason} ->
            true
        end
      end
    end

    property "risk assessment produces valid risk scores", [:verbose] do
      forall metrics <- metrics_data_gen() do
        case ConsolidatedMLAnalytics.assess_risks(metrics) do
          {:ok, risks} ->
            validate_risk_structure(risks) and
              validate_risk_probabilities(risks) and
              validate_risk_impacts(risks)

          {:error, _reason} ->
            true
        end
      end
    end

    property "model creation handles various configurations", [:verbose] do
      forall {tenant_id, model_type, training_data} <- {
               tenant_id_gen(),
               model_type_gen(),
               PC.map(PC.atom(:alphanumeric), PC.term())
             } do
        case ConsolidatedMLAnalytics.create_model(tenant_id, model_type, training_data) do
          {:ok, model} ->
            validate_model_structure(model) and
              validate_model_metadata(model, tenant_id, model_type)

          {:error, reason} ->
            is_atom(reason)
        end
      end
    end
  end

  # ExUnitProperties tests with StreamData
  describe "ExUnitProperties tests" do
    test "ML insights maintain data integrity across metrics variations" do
      ExUnitProperties.check all(
                               metrics <-
                                 SD.fixed_map(%{
                                   cpu_usage: SD.integer(0..100),
                                   memory_usage: SD.integer(0..100),
                                   network_latency: SD.integer(0..1000),
                                   disk_io: SD.integer(0..100),
                                   error_rate: SD.integer(0..100),
                                   request_count: SD.integer(0..10_000),
                                   timestamp: SD.constant(DateTime.utc_now())
                                 }),
                               config <-
                                 SD.fixed_map(%{
                                   algorithm:
                                     SD.member_of([
                                       :ensemble,
                                       :linear_regression,
                                       :neural_network
                                     ]),
                                   horizon_hours: SD.integer(1..72),
                                   confidence_level: SD.float(min: 0.5, max: 0.99),
                                   threshold: SD.float(min: 0.5, max: 0.95)
                                 }),
                               max_runs: 100
                             ) do
        case ConsolidatedMLAnalytics.generate_comprehensive_insights(metrics, config) do
          {:ok, insights} ->
            assert is_map(insights)
            assert Map.has_key?(insights, :patterns)
            assert Map.has_key?(insights, :predictions)
            assert Map.has_key?(insights, :anomalies)
            assert Map.has_key?(insights, :recommendations)
            assert Map.has_key?(insights, :confidence)

            # Validate confidence is within bounds
            assert insights.confidence >= 0.0
            assert insights.confidence <= 1.0

            # Validate structure integrity
            validate_comprehensive_insight_structure(insights)

          {:error, _reason} ->
            :ok
        end
      end
    end

    test "consolidated predictions provide comprehensive coverage" do
      ExUnitProperties.check all(
                               tenant_id <- SD.string(:alphanumeric, min_length: 5),
                               metrics <-
                                 SD.fixed_map(%{
                                   cpu_usage: SD.integer(0..100),
                                   memory_usage: SD.integer(0..100),
                                   response_time: SD.integer(1..5000),
                                   throughput: SD.integer(1..10_000)
                                 }),
                               max_runs: 50
                             ) do
        case ConsolidatedMLAnalytics.generate_consolidated_predictions(tenant_id, metrics) do
          {:ok, consolidated} ->
            assert is_map(consolidated)

            required_keys = [
              :performance_forecast,
              :incident_predictions,
              :anomaly_detection,
              :capacity_recommendations,
              :risk_assessment,
              :model_metadata
            ]

            Enum.each(required_keys, fn key ->
              assert Map.has_key?(consolidated, key)
            end)

            # Validate metadata consistency
            assert consolidated.model_metadata.tenant_id == tenant_id

            validate_consolidated_prediction_structure(consolidated)

          {:error, _reason} ->
            :ok
        end
      end
    end

    test "performance predictions scale with horizon" do
      ExUnitProperties.check all(
                               metrics <-
                                 SD.fixed_map(%{
                                   cpu_usage: SD.integer(0..100),
                                   memory_usage: SD.integer(0..100)
                                 }),
                               horizon <- SD.integer(1..168),
                               confidence <- SD.float(min: 0.8, max: 0.99),
                               max_runs: 75
                             ) do
        case ConsolidatedMLAnalytics.predict_performance(metrics, horizon, confidence) do
          {:ok, performance} ->
            assert is_map(performance)
            assert Map.has_key?(performance, :predictions)
            assert Map.has_key?(performance, :horizon_hours)
            assert Map.has_key?(performance, :confidence_level)

            # Validate horizon consistency
            assert performance.horizon_hours == horizon
            assert performance.confidence_level == confidence

            # Validate predictions length matches horizon
            if is_list(performance.predictions) do
              assert length(performance.predictions) == horizon
            end

            validate_performance_prediction_structure(performance)

          {:error, _reason} ->
            :ok
        end
      end
    end

    test "incident predictions maintain valid probability bounds" do
      ExUnitProperties.check all(
                               tenant_id <- SD.string(:alphanumeric, min_length: 3),
                               metrics <-
                                 SD.map_of(SD.atom(:alphanumeric), SD.integer(0..100),
                                   min_length: 1
                                 ),
                               max_runs: 100
                             ) do
        case ConsolidatedMLAnalytics.predict_incidents(tenant_id, metrics) do
          {:ok, incidents} ->
            assert is_list(incidents)

            # Validate each incident prediction
            Enum.each(incidents, fn incident ->
              assert Map.has_key?(incident, :likelihood)
              assert Map.has_key?(incident, :incident_type)
              assert Map.has_key?(incident, :tenant_id)

              # Validate likelihood bounds
              assert incident.likelihood >= 0.0
              assert incident.likelihood <= 1.0

              # Validate tenant consistency
              assert incident.tenant_id == tenant_id
            end)

            validate_incident_predictions_structure(incidents)

          {:error, _reason} ->
            :ok
        end
      end
    end

    test "anomaly detection provides consistent risk classification" do
      ExUnitProperties.check all(
                               metrics <-
                                 SD.fixed_map(%{
                                   cpu_usage: SD.integer(0..100),
                                   memory_usage: SD.integer(0..100),
                                   error_rate: SD.integer(0..100)
                                 }),
                               max_runs: 100
                             ) do
        case ConsolidatedMLAnalytics.detect_system_anomalies(metrics) do
          {:ok, anomalies} ->
            assert is_map(anomalies)
            assert Map.has_key?(anomalies, :composite_score)
            assert Map.has_key?(anomalies, :risk_level)

            # Validate risk level consistency
            valid_risk_levels = [:low, :medium, :high, :critical]
            assert anomalies.risk_level in valid_risk_levels

            # Validate composite score bounds
            assert is_number(anomalies.composite_score)
            assert anomalies.composite_score >= 0.0
            assert anomalies.composite_score <= 1.0

            validate_anomaly_detection_structure(anomalies)

          {:error, _reason} ->
            :ok
        end
      end
    end

    test "capacity planning generates actionable recommendations" do
      ExUnitProperties.check all(
                               metrics <-
                                 SD.map_of(SD.atom(:alphanumeric), SD.integer(0..100),
                                   min_length: 1
                                 ),
                               horizon <- SD.integer(1..72),
                               max_runs: 50
                             ) do
        case ConsolidatedMLAnalytics.plan_capacity(metrics, horizon) do
          {:ok, capacity} ->
            assert is_map(capacity)
            assert Map.has_key?(capacity, :resource_forecasts)
            assert Map.has_key?(capacity, :recommendations)
            assert Map.has_key?(capacity, :scaling_triggers)

            # Validate recommendations are actionable
            assert is_list(capacity.recommendations)
            assert length(capacity.recommendations) > 0

            # Validate scaling triggers are valid percentages
            Enum.each(capacity.scaling_triggers, fn {_resource, trigger} ->
              assert is_number(trigger)
              assert trigger >= 0.0
              assert trigger <= 100.0
            end)

            validate_capacity_planning_structure(capacity)

          {:error, _reason} ->
            :ok
        end
      end
    end

    test "model creation validates input parameters" do
      ExUnitProperties.check all(
                               tenant_id <- SD.string(:alphanumeric, min_length: 1),
                               model_type <-
                                 SD.member_of([
                                   :threat_prediction,
                                   :incident_forecasting,
                                   :behavior_anomaly,
                                   :performance_prediction
                                 ]),
                               training_data <-
                                 SD.map_of(SD.atom(:alphanumeric), SD.term(), min_length: 1),
                               max_runs: 30
                             ) do
        case ConsolidatedMLAnalytics.create_model(tenant_id, model_type, training_data) do
          {:ok, model} ->
            assert is_map(model)
            assert Map.has_key?(model, :id)
            assert Map.has_key?(model, :config)

            # Validate model configuration
            assert model.config.tenant_id == tenant_id
            assert model.config.model_type == model_type

            validate_model_creation_structure(model)

          {:error, reason} ->
            assert is_atom(reason)
            :ok
        end
      end
    end
  end

  # Validation helper functions
  defp validate_insight_structure(insights) do
    required_keys = [
      :patterns,
      :predictions,
      :anomalies,
      :recommendations,
      :confidence,
      :model_accuracy,
      :feature_importance,
      :generated_at
    ]

    Enum.all?(required_keys, &Map.has_key?(insights, &1)) and
      is_list(insights.patterns) and
      is_list(insights.predictions) and
      is_list(insights.anomalies) and
      is_list(insights.recommendations) and
      is_number(insights.confidence) and
      is_map(insights.model_accuracy) and
      is_map(insights.feature_importance) and
      match?(%DateTime{}, insights.generated_at)
  end

  defp validate_confidence_bounds(insights) do
    insights.confidence >= 0.0 and insights.confidence <= 1.0
  end

  defp validate_timestamps(insights) do
    DateTime.diff(DateTime.utc_now(), insights.generated_at, :second) <= 60
  end

  defp validate_performance_structure(predictions) do
    required_keys = [
      :predictions,
      :confidence_intervals,
      :model_accuracy,
      :horizon_hours,
      :confidence_level
    ]

    Enum.all?(required_keys, &Map.has_key?(predictions, &1))
  end

  defp validate_prediction_horizon(predictions, expected_horizon) do
    predictions.horizon_hours == expected_horizon
  end

  defp validate_confidence_intervals(predictions, expected_confidence) do
    predictions.confidence_level == expected_confidence and
      Map.has_key?(predictions.confidence_intervals, :lower_bound) and
      Map.has_key?(predictions.confidence_intervals, :upper_bound)
  end

  defp validate_incident_structure(incident) do
    required_keys = [
      :tenant_id,
      :incident_type,
      :likelihood,
      :predicted_time,
      :severity,
      :recommended_actions
    ]

    Enum.all?(required_keys, &Map.has_key?(incident, &1))
  end

  defp validate_likelihood_bounds(incident) do
    incident.likelihood >= 0.0 and incident.likelihood <= 1.0
  end

  defp validate_incident_types(incident) do
    valid_types = [
      :security_breach,
      :equipment_failure,
      :access_violation,
      :system_outage,
      :performance_degradation,
      :maintenance_required
    ]

    incident.incident_type in valid_types
  end

  defp validate_anomaly_structure(anomalies) do
    required_keys = [
      :statistical_anomalies,
      :pattern_anomalies,
      :ml_anomalies,
      :composite_score,
      :risk_level,
      :recommendations
    ]

    Enum.all?(required_keys, &Map.has_key?(anomalies, &1))
  end

  defp validate_anomaly_scores(anomalies) do
    is_number(anomalies.composite_score) and
      anomalies.composite_score >= 0.0 and
      anomalies.composite_score <= 1.0
  end

  defp validate_risk_levels(anomalies) do
    valid_levels = [:low, :medium, :high, :critical]
    anomalies.risk_level in valid_levels
  end

  defp validate_capacity_structure(capacity) do
    required_keys = [
      :resource_forecasts,
      :recommendations,
      :scaling_triggers,
      :optimization_opportunities,
      :cost_projections
    ]

    Enum.all?(required_keys, &Map.has_key?(capacity, &1))
  end

  defp validate_resource_forecasts(capacity) do
    required_resources = [:cpu, :memory, :storage, :network]

    Enum.all?(required_resources, &Map.has_key?(capacity.resource_forecasts, &1))
  end

  defp validate_scaling_triggers(capacity) do
    Enum.all?(capacity.scaling_triggers, fn {_resource, trigger} ->
      is_number(trigger) and trigger >= 0.0 and trigger <= 100.0
    end)
  end

  defp validate_risk_structure(risks) do
    required_keys = [
      :performance_risks,
      :availability_risks,
      :security_risks,
      :capacity_risks,
      :overall_risk_score,
      :recommended_actions
    ]

    Enum.all?(required_keys, &Map.has_key?(risks, &1))
  end

  defp validate_risk_probabilities(risks) do
    risk_categories = [:performance_risks, :availability_risks, :security_risks, :capacity_risks]

    Enum.all?(risk_categories, fn category ->
      risk = Map.get(risks, category)

      is_map(risk) and
        Map.has_key?(risk, :probability) and
        is_number(risk.probability) and
        risk.probability >= 0.0 and
        risk.probability <= 1.0
    end)
  end

  defp validate_risk_impacts(risks) do
    valid_impacts = [:low, :medium, :high, :critical]
    risk_categories = [:performance_risks, :availability_risks, :security_risks, :capacity_risks]

    Enum.all?(risk_categories, fn category ->
      risk = Map.get(risks, category)
      Map.has_key?(risk, :impact) and risk.impact in valid_impacts
    end)
  end

  defp validate_model_structure(model) do
    required_keys = [:id, :config, :training_completed_at, :status]

    Enum.all?(required_keys, &Map.has_key?(model, &1))
  end

  defp validate_model_metadata(model, expected_tenant_id, expected_model_type) do
    model.config.tenant_id == expected_tenant_id and
      model.config.model_type == expected_model_type
  end

  # ExUnitProperties specific validation functions
  defp validate_comprehensive_insight_structure(insights) do
    assert is_list(insights.patterns)
    assert is_list(insights.predictions)
    assert is_list(insights.anomalies)
    assert is_list(insights.recommendations)
    assert is_map(insights.model_accuracy)
    assert is_map(insights.feature_importance)
    assert %DateTime{} = insights.generated_at
  end

  defp validate_consolidated_prediction_structure(consolidated) do
    assert is_map(consolidated.performance_forecast)
    assert is_list(consolidated.incident_predictions)
    assert is_map(consolidated.anomaly_detection)
    assert is_list(consolidated.capacity_recommendations)
    assert is_map(consolidated.risk_assessment)
    assert is_map(consolidated.model_metadata)
  end

  defp validate_performance_prediction_structure(performance) do
    assert Map.has_key?(performance, :model_accuracy)
    assert Map.has_key?(performance, :confidence_intervals)
    assert is_map(performance.confidence_intervals)
  end

  defp validate_incident_predictions_structure(incidents) do
    Enum.each(incidents, fn incident ->
      assert is_binary(incident.tenant_id)
      assert is_atom(incident.incident_type)
      assert is_number(incident.likelihood)
      assert %DateTime{} = incident.predicted_time
    end)
  end

  defp validate_anomaly_detection_structure(anomalies) do
    assert is_list(anomalies.statistical_anomalies)
    assert is_list(anomalies.pattern_anomalies)
    assert is_list(anomalies.ml_anomalies)
    assert is_list(anomalies.recommendations)
  end

  defp validate_capacity_planning_structure(capacity) do
    assert is_map(capacity.resource_forecasts)
    assert is_list(capacity.recommendations)
    assert is_map(capacity.scaling_triggers)
    assert is_list(capacity.optimization_opportunities)
  end

  defp validate_model_creation_structure(model) do
    assert is_binary(model.id)
    assert is_map(model.config)
    assert %DateTime{} = model.training_completed_at
    assert model.status == :trained
  end

  # Integration tests for ML consolidation
  describe "ML consolidation integration" do
    test "consolidated ML analytics provides same functionality as original modules" do
      tenant_id = "integration_test_tenant"

      metrics_data = %{
        cpu_usage: 75.5,
        memory_usage: 68.3,
        network_latency: 25.7,
        disk_io: 45.2,
        error_rate: 2.1,
        request_count: 1500
      }

      # Test comprehensive insights functionality
      assert {:ok, insights} =
               ConsolidatedMLAnalytics.generate_comprehensive_insights(metrics_data)

      assert validate_insight_structure(insights)

      # Test consolidated predictions functionality
      assert {:ok, predictions} =
               ConsolidatedMLAnalytics.generate_consolidated_predictions(tenant_id, metrics_data)

      assert validate_consolidated_prediction_structure(predictions)

      # Test performance prediction functionality
      assert {:ok, performance} = ConsolidatedMLAnalytics.predict_performance(metrics_data, 24)
      assert validate_performance_structure(performance)

      # Test incident prediction functionality
      assert {:ok, incidents} = ConsolidatedMLAnalytics.predict_incidents(tenant_id, metrics_data)
      assert is_list(incidents)
    end

    test "ML model creation and management" do
      tenant_id = "ml_model_test_tenant"
      model_type = :performance_prediction

      training_data = %{
        historical_metrics: [%{cpu: 70, memory: 60}, %{cpu: 80, memory: 75}],
        labels: [0.8, 0.9]
      }

      assert {:ok, model} =
               ConsolidatedMLAnalytics.create_model(tenant_id, model_type, training_data)

      assert validate_model_structure(model)
      assert model.config.tenant_id == tenant_id
      assert model.config.model_type == model_type
    end

    test "capacity planning with multiple resource types" do
      resource_metrics = %{
        cpu_history: [70, 75, 80, 85],
        memory_history: [60, 65, 70, 75],
        storage_history: [40, 45, 50, 55],
        network_history: [30, 35, 40, 45]
      }

      assert {:ok, capacity_plan} = ConsolidatedMLAnalytics.plan_capacity(resource_metrics, 48)
      assert validate_capacity_structure(capacity_plan)
      assert Map.has_key?(capacity_plan.resource_forecasts, :cpu)
      assert Map.has_key?(capacity_plan.resource_forecasts, :memory)
      assert Map.has_key?(capacity_plan.resource_forecasts, :storage)
      assert Map.has_key?(capacity_plan.resource_forecasts, :network)
    end
  end

  # Performance property tests
  describe "Performance property tests" do
    property "ML operations scale with data complexity", [:verbose] do
      forall {metrics_size, complexity_factor} <- {PC.choose(10, 1000), PC.choose(1, 10)} do
        metrics_data = generate_complex_metrics(metrics_size, complexity_factor)
        start_time = System.monotonic_time(:millisecond)

        case ConsolidatedMLAnalytics.generate_comprehensive_insights(metrics_data) do
          {:ok, _insights} ->
            end_time = System.monotonic_time(:millisecond)
            duration = end_time - start_time

            # ML operations should complete within reasonable time
            # Allowing more time for complex metrics
            max_duration = 1000 + metrics_size * complexity_factor * 0.1
            duration <= max_duration

          {:error, _reason} ->
            true
        end
      end
    end

    property "memory usage remains bounded during ML operations" do
      forall operations <-
               PC.list(
                 PC.oneof([
                   {:generate_insights, metrics_data_gen()},
                   {:predict_performance, metrics_data_gen(), choose(1, 48)},
                   {:predict_incidents, tenant_id_gen(), metrics_data_gen()},
                   {:detect_anomalies, metrics_data_gen()},
                   {:plan_capacity, metrics_data_gen(), choose(1, 72)}
                 ])
               ) do
        initial_memory = :erlang.memory(:total)

        # Execute ML operations
        Enum.each(operations, fn
          {:generate_insights, metrics} ->
            ConsolidatedMLAnalytics.generate_comprehensive_insights(metrics)

          {:predict_performance, metrics, horizon} ->
            ConsolidatedMLAnalytics.predict_performance(metrics, horizon)

          {:predict_incidents, tenant_id, metrics} ->
            ConsolidatedMLAnalytics.predict_incidents(tenant_id, metrics)

          {:detect_anomalies, metrics} ->
            ConsolidatedMLAnalytics.detect_system_anomalies(metrics)

          {:plan_capacity, metrics, horizon} ->
            ConsolidatedMLAnalytics.plan_capacity(metrics, horizon)
        end)

        # Force garbage collection
        :erlang.garbage_collect()
        final_memory = :erlang.memory(:total)

        # Memory increase should be reasonable (less than 20MB for ML operations)
        memory_increase = final_memory - initial_memory
        memory_increase < 20_000_000
      end
    end
  end

  # Helper function for complex metrics generation
  defp generate_complex_metrics(size, complexity) do
    base_metrics = %{
      cpu_usage: 50.0,
      memory_usage: 60.0,
      network_latency: 100.0,
      disk_io: 40.0,
      error_rate: 1.0,
      request_count: 1000
    }

    # Add complexity by generating historical data
    historical_data =
      Enum.map(1..size, fn i ->
        variance = complexity * :rand.normal()

        %{
          timestamp: DateTime.add(DateTime.utc_now(), -i * 60, :second),
          cpu_usage: max(0, base_metrics.cpu_usage + variance),
          memory_usage: max(0, base_metrics.memory_usage + variance),
          network_latency: max(0, base_metrics.network_latency + variance * 10),
          disk_io: max(0, base_metrics.disk_io + variance),
          error_rate: max(0, base_metrics.error_rate + variance * 0.1),
          request_count: max(0, base_metrics.request_count + variance * 100)
        }
      end)

    Map.put(base_metrics, :historical_data, historical_data)
  end
end
