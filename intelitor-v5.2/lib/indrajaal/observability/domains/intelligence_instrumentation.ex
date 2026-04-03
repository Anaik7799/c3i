defmodule Indrajaal.Observability.Domains.IntelligenceInstrumentation do
  @moduledoc """
  Domain-specific instrumentation for the Intelligence domain.

  Provides comprehensive telemetry and tracing for threat detection, anomaly detection,
  ML model inference, behavioral analysis, and alert correlation.

  ## Telemetry Events

  Threat Detection Events:
  - `[:indrajaal, :intelligence, :threat_detection, :score]`
  - `[:indrajaal, :intelligence, :anomaly_detection, :triggered]`
  - `[:indrajaal, :intelligence, :behavioral_analysis, :complete]`

  ML Model Events:
  - `[:indrajaal, :intelligence, :ml_model, :inference_start]`
  - `[:indrajaal, :intelligence, :ml_model, :inference_stop]`

  Alert Events:
  - `[:indrajaal, :intelligence, :alert_correlation, :found]`
  - `[:indrajaal, :intelligence, :predictive_alert, :issued]`
  - `[:indrajaal, :intelligence, :false_positive, :detected]`

  ## Tracing Spans

  - `intelligence.threat_analysis` (root)
  - `intelligence.data_collection`
  - `intelligence.model_inference`
  - `intelligence.score_calculation`
  - `intelligence.alert_generation`

  ## STAMP Safety Constraints

  - SC-OBS-065: Logging enabled for ALL key operations
  - SC-OBS-066: OpenTelemetry validation at startup
  - SC-OBS-069: Dual logging (Terminal + SigNoz)
  - SC-OBS-070: Trace context injection
  """

  use Indrajaal.Observability.InstrumentationBase, domain: :intelligence

  @threat_levels [:critical, :high, :medium, :low, :none]
  @anomaly_types [:behavioral, :temporal, :spatial, :statistical]

  @doc """
  Sets up telemetry handlers for the Intelligence domain.
  """
  def setup do
    Logger.info("Setting up Intelligence domain instrumentation")
    attach_handlers()
    :ok
  end

  def handle_event(event, measurements, metadata) do
    :telemetry.execute(
      [:indrajaal, :observability, :intelligence, :event],
      measurements,
      Map.merge(metadata, %{original_event: event})
    )

    :ok
  end

  def get_metrics do
    {:ok, %{status: :active, domain: :intelligence}}
  end

  def record_metric(name, value) do
    :telemetry.execute(
      [:indrajaal, :observability, :intelligence, :metric],
      %{value: value},
      %{name: name}
    )

    :ok
  end

  def configure(_opts) do
    :ok
  end

  def get_configuration do
    {:ok,
     [
       domain: :intelligence,
       threat_levels: @threat_levels,
       anomaly_types: @anomaly_types
     ]}
  end

  def shutdown do
    :ok
  end

  @doc """
  Attaches all telemetry handlers for the Intelligence domain.
  """
  def attach_handlers do
    # Threat detection handlers
    :telemetry.attach_many(
      "intelligence-threat-detection",
      [
        [:indrajaal, :intelligence, :threat_detection, :score],
        [:indrajaal, :intelligence, :anomaly_detection, :triggered],
        [:indrajaal, :intelligence, :behavioral_analysis, :complete]
      ],
      &handle_threat_detection_event/4,
      %{}
    )

    # ML model handlers
    :telemetry.attach_many(
      "intelligence-ml-model",
      [
        [:indrajaal, :intelligence, :ml_model, :inference_start],
        [:indrajaal, :intelligence, :ml_model, :inference_stop]
      ],
      &handle_ml_model_event/4,
      %{}
    )

    # Alert handlers
    :telemetry.attach_many(
      "intelligence-alerts",
      [
        [:indrajaal, :intelligence, :alert_correlation, :found],
        [:indrajaal, :intelligence, :predictive_alert, :issued],
        [:indrajaal, :intelligence, :false_positive, :detected]
      ],
      &handle_alert_event/4,
      %{}
    )

    Logger.debug("Intelligence domain telemetry handlers attached")
    :ok
  end

  # =============================================================================
  # Threat Detection Instrumentation
  # =============================================================================

  @doc """
  Emits telemetry for threat detection score calculation.

  ## Parameters
  - `threat_level` - Calculated threat level (:critical, :high, :medium, :low, :none)
  - `score` - Numeric threat score (0.0 - 1.0)
  - `factors` - List of contributing factors
  - `metadata` - Additional metadata (tenant_id, entity_id, etc.)
  """
  def emit_threat_score(threat_level, score, factors, metadata \\ %{})
      when threat_level in @threat_levels do
    measurements = %{
      score: score,
      factor_count: length(factors),
      system_time: System.system_time(:millisecond)
    }

    analysis_id = generate_analysis_id()

    enriched_metadata =
      metadata
      |> Map.put(:analysis_id, analysis_id)
      |> Map.put(:threat_level, threat_level)
      |> Map.put(:factors, factors)
      |> Map.put(:requires_action, threat_level in [:critical, :high])

    :telemetry.execute(
      [:indrajaal, :intelligence, :threat_detection, :score],
      measurements,
      enriched_metadata
    )

    log_level = if threat_level in [:critical, :high], do: :warning, else: :info

    Logger.log(log_level, "Threat score calculated",
      analysis_id: analysis_id,
      threat_level: threat_level,
      score: score,
      factor_count: length(factors),
      tenant_id: metadata[:tenant_id]
    )

    {analysis_id, threat_level}
  end

  @doc """
  Emits telemetry for anomaly detection trigger.

  ## Parameters
  - `anomaly_type` - Type of anomaly (:behavioral, :temporal, :spatial, :statistical)
  - `severity` - Anomaly severity (0.0 - 1.0)
  - `context` - Contextual information about the anomaly
  - `metadata` - Additional metadata
  """
  def emit_anomaly_triggered(anomaly_type, severity, context, metadata \\ %{})
      when anomaly_type in @anomaly_types do
    measurements = %{
      severity: severity,
      system_time: System.system_time(:millisecond)
    }

    anomaly_id = generate_analysis_id()

    enriched_metadata =
      metadata
      |> Map.put(:anomaly_id, anomaly_id)
      |> Map.put(:anomaly_type, anomaly_type)
      |> Map.put(:context, context)
      |> Map.put(:high_severity, severity >= 0.7)

    :telemetry.execute(
      [:indrajaal, :intelligence, :anomaly_detection, :triggered],
      measurements,
      enriched_metadata
    )

    log_level = if severity >= 0.7, do: :warning, else: :info

    Logger.log(log_level, "Anomaly detected",
      anomaly_id: anomaly_id,
      anomaly_type: anomaly_type,
      severity: severity,
      tenant_id: metadata[:tenant_id]
    )

    anomaly_id
  end

  @doc """
  Emits telemetry for behavioral analysis completion.

  ## Parameters
  - `entity_type` - Type of entity analyzed (user, device, location)
  - `entity_id` - Entity identifier
  - `profile_deviation` - Deviation from baseline profile (0.0 - 1.0)
  - `duration_ms` - Analysis duration in milliseconds
  - `metadata` - Additional metadata
  """
  def emit_behavioral_analysis_complete(
        entity_type,
        entity_id,
        profile_deviation,
        duration_ms,
        metadata \\ %{}
      ) do
    measurements = %{
      profile_deviation: profile_deviation,
      duration: duration_ms,
      system_time: System.system_time(:millisecond)
    }

    enriched_metadata =
      metadata
      |> Map.put(:entity_type, entity_type)
      |> Map.put(:entity_id, entity_id)
      |> Map.put(:significant_deviation, profile_deviation >= 0.5)

    :telemetry.execute(
      [:indrajaal, :intelligence, :behavioral_analysis, :complete],
      measurements,
      enriched_metadata
    )

    Logger.info("Behavioral analysis completed",
      entity_type: entity_type,
      entity_id: entity_id,
      profile_deviation: profile_deviation,
      duration_ms: duration_ms,
      tenant_id: metadata[:tenant_id]
    )
  end

  # =============================================================================
  # ML Model Instrumentation
  # =============================================================================

  @doc """
  Emits telemetry for ML model inference start.

  ## Parameters
  - `model_name` - Name of the ML model
  - `model_version` - Model version
  - `input_features` - Number of input features
  - `metadata` - Additional metadata
  """
  def emit_ml_inference_start(model_name, model_version, input_features, metadata \\ %{}) do
    measurements = %{
      input_features: input_features,
      system_time: System.system_time(:millisecond)
    }

    inference_id = generate_analysis_id()

    enriched_metadata =
      metadata
      |> Map.put(:inference_id, inference_id)
      |> Map.put(:model_name, model_name)
      |> Map.put(:model_version, model_version)

    :telemetry.execute(
      [:indrajaal, :intelligence, :ml_model, :inference_start],
      measurements,
      enriched_metadata
    )

    Logger.info("ML model inference started",
      inference_id: inference_id,
      model_name: model_name,
      model_version: model_version,
      input_features: input_features,
      tenant_id: metadata[:tenant_id]
    )

    inference_id
  end

  @doc """
  Emits telemetry for ML model inference completion.

  ## Parameters
  - `inference_id` - Inference ID from emit_ml_inference_start
  - `result` - Inference result (:success, :failure)
  - `confidence` - Model confidence score (0.0 - 1.0)
  - `duration_ms` - Inference duration in milliseconds
  - `metadata` - Additional metadata
  """
  def emit_ml_inference_stop(inference_id, result, confidence, duration_ms, metadata \\ %{}) do
    measurements = %{
      confidence: confidence,
      duration: duration_ms,
      system_time: System.system_time(:millisecond)
    }

    enriched_metadata =
      metadata
      |> Map.put(:inference_id, inference_id)
      |> Map.put(:result, result)
      |> Map.put(:success, result == :success)
      |> Map.put(:low_confidence, confidence < 0.5)

    :telemetry.execute(
      [:indrajaal, :intelligence, :ml_model, :inference_stop],
      measurements,
      enriched_metadata
    )

    log_level = if result == :failure, do: :error, else: :info

    Logger.log(log_level, "ML model inference completed",
      inference_id: inference_id,
      result: result,
      confidence: confidence,
      duration_ms: duration_ms,
      tenant_id: metadata[:tenant_id]
    )
  end

  # =============================================================================
  # Alert Instrumentation
  # =============================================================================

  @doc """
  Emits telemetry for alert correlation discovery.

  ## Parameters
  - `correlation_type` - Type of correlation found
  - `alert_ids` - List of correlated alert IDs
  - `correlation_score` - Correlation score (0.0 - 1.0)
  - `metadata` - Additional metadata
  """
  def emit_alert_correlation_found(
        correlation_type,
        alert_ids,
        correlation_score,
        metadata \\ %{}
      ) do
    measurements = %{
      alert_count: length(alert_ids),
      correlation_score: correlation_score,
      system_time: System.system_time(:millisecond)
    }

    correlation_id = generate_analysis_id()

    enriched_metadata =
      metadata
      |> Map.put(:correlation_id, correlation_id)
      |> Map.put(:correlation_type, correlation_type)
      |> Map.put(:alert_ids, alert_ids)
      |> Map.put(:strong_correlation, correlation_score >= 0.8)

    :telemetry.execute(
      [:indrajaal, :intelligence, :alert_correlation, :found],
      measurements,
      enriched_metadata
    )

    Logger.info("Alert correlation found",
      correlation_id: correlation_id,
      correlation_type: correlation_type,
      alert_count: length(alert_ids),
      correlation_score: correlation_score,
      tenant_id: metadata[:tenant_id]
    )

    correlation_id
  end

  @doc """
  Emits telemetry for predictive alert issuance.

  ## Parameters
  - `prediction_type` - Type of prediction
  - `confidence` - Prediction confidence (0.0 - 1.0)
  - `predicted_time` - Predicted event time (DateTime or nil)
  - `metadata` - Additional metadata
  """
  def emit_predictive_alert_issued(prediction_type, confidence, predicted_time, metadata \\ %{}) do
    measurements = %{
      confidence: confidence,
      system_time: System.system_time(:millisecond)
    }

    alert_id = generate_analysis_id()

    enriched_metadata =
      metadata
      |> Map.put(:alert_id, alert_id)
      |> Map.put(:prediction_type, prediction_type)
      |> Map.put(:predicted_time, predicted_time)
      |> Map.put(:high_confidence, confidence >= 0.8)

    :telemetry.execute(
      [:indrajaal, :intelligence, :predictive_alert, :issued],
      measurements,
      enriched_metadata
    )

    Logger.info("Predictive alert issued",
      alert_id: alert_id,
      prediction_type: prediction_type,
      confidence: confidence,
      predicted_time: predicted_time,
      tenant_id: metadata[:tenant_id]
    )

    alert_id
  end

  @doc """
  Emits telemetry for false positive detection.

  ## Parameters
  - `original_alert_id` - ID of the original alert
  - `detection_method` - Method used to detect false positive
  - `confidence` - Confidence in false positive determination (0.0 - 1.0)
  - `metadata` - Additional metadata
  """
  def emit_false_positive_detected(
        original_alert_id,
        detection_method,
        confidence,
        metadata \\ %{}
      ) do
    measurements = %{
      confidence: confidence,
      system_time: System.system_time(:millisecond)
    }

    enriched_metadata =
      metadata
      |> Map.put(:original_alert_id, original_alert_id)
      |> Map.put(:detection_method, detection_method)
      |> Map.put(:high_confidence, confidence >= 0.9)

    :telemetry.execute(
      [:indrajaal, :intelligence, :false_positive, :detected],
      measurements,
      enriched_metadata
    )

    Logger.info("False positive detected",
      original_alert_id: original_alert_id,
      detection_method: detection_method,
      confidence: confidence,
      tenant_id: metadata[:tenant_id]
    )
  end

  # =============================================================================
  # OpenTelemetry Tracing
  # =============================================================================

  @doc """
  Wraps a threat analysis operation with OpenTelemetry tracing span.

  ## Parameters
  - `entity_type` - Type of entity being analyzed
  - `entity_id` - Entity identifier
  - `metadata` - Additional metadata
  - `fun` - The function to execute within the span
  """
  def with_threat_analysis_span(entity_type, entity_id, metadata \\ %{}, fun) do
    attributes = %{
      "intelligence.entity_type" => to_string(entity_type),
      "intelligence.entity_id" => to_string(entity_id),
      "intelligence.tenant_id" => metadata[:tenant_id] || "unknown"
    }

    Tracing.with_span("intelligence.threat_analysis", attributes, fn ->
      with_nested_analysis_spans(fun)
    end)
  end

  defp with_nested_analysis_spans(fun) do
    with_data_collection_span(fn ->
      with_model_inference_span(fn ->
        with_score_calculation_span(fn ->
          execute_and_handle_result(fun)
        end)
      end)
    end)
  end

  defp execute_and_handle_result(fun) do
    result = fun.()

    case result do
      {:alert, _} -> with_alert_generation_span(fn -> result end)
      _ -> result
    end
  end

  defp with_data_collection_span(fun) do
    Tracing.with_span("intelligence.data_collection", %{}, fun)
  end

  defp with_model_inference_span(fun) do
    Tracing.with_span("intelligence.model_inference", %{}, fun)
  end

  defp with_score_calculation_span(fun) do
    Tracing.with_span("intelligence.score_calculation", %{}, fun)
  end

  defp with_alert_generation_span(fun) do
    Tracing.with_span("intelligence.alert_generation", %{}, fun)
  end

  # =============================================================================
  # Event Handlers
  # =============================================================================

  defp handle_threat_detection_event(event, measurements, metadata, _config) do
    event_type = List.last(event)

    case event_type do
      :score ->
        Logger.debug("Threat score event",
          threat_level: metadata[:threat_level],
          score: measurements[:score]
        )

      :triggered ->
        Logger.debug("Anomaly triggered",
          anomaly_type: metadata[:anomaly_type],
          severity: measurements[:severity]
        )

      :complete ->
        Logger.debug("Behavioral analysis complete",
          entity_type: metadata[:entity_type],
          deviation: measurements[:profile_deviation]
        )
    end
  end

  defp handle_ml_model_event(event, measurements, metadata, _config) do
    phase = List.last(event)

    case phase do
      :inference_start ->
        Logger.debug("ML inference started",
          model_name: metadata[:model_name],
          input_features: measurements[:input_features]
        )

      :inference_stop ->
        Logger.debug("ML inference completed",
          result: metadata[:result],
          confidence: measurements[:confidence],
          duration_ms: measurements[:duration]
        )
    end
  end

  defp handle_alert_event(event, measurements, metadata, _config) do
    event_type = List.last(event)

    case event_type do
      :found ->
        Logger.debug("Alert correlation found",
          correlation_type: metadata[:correlation_type],
          alert_count: measurements[:alert_count]
        )

      :issued ->
        Logger.debug("Predictive alert issued",
          prediction_type: metadata[:prediction_type],
          confidence: measurements[:confidence]
        )

      :detected ->
        Logger.debug("False positive detected",
          original_alert_id: metadata[:original_alert_id],
          confidence: measurements[:confidence]
        )
    end
  end

  # =============================================================================
  # Helper Functions
  # =============================================================================

  defp generate_analysis_id do
    bytes = :crypto.strong_rand_bytes(8)
    bytes |> Base.encode16(case: :lower)
  end
end
