defmodule SecurityTestFramework do
  @moduledoc """
  Security Test Framework - Phase T consolidation

  Eliminates duplications between ML threat detection and behavioral analytics tests.
  """

  import ExUnit.Assertions

  @doc """
  Common security event setup (mass:25-28)
  """
  @spec setup_security_event(term(), map()) :: term()
  def setup_security_event(type, attrs \\ %{}) do
    base_event = %{
      timestamp: DateTime.utc_now(),
      event_type: type,
      severity: :medium,
      source_ip: "192.168.1.100",
      user_id: "user_123",
      tenant_id: "tenant_456"
    }

    Map.merge(base_event, attrs)
  end

  @doc """
  Common threat detection assertion
  """
  @spec assert_threat_detected(term(), term()) :: term()
  def assert_threat_detected(result, expected_threat_level) do
    assert {:ok, detection} = result
    assert detection.threat_level == expected_threat_level
    assert detection.confidence > 0.7
    assert is_list(detection.indicators)
    assert length(detection.indicators) > 0
    detection
  end

  @doc """
  Common behavioral analysis assertion
  """
  @spec assert_behavior_analyzed(term(), term()) :: term()
  def assert_behavior_analyzed(result, expected_risk_score) do
    assert {:ok, analysis} = result
    assert_in_delta analysis.risk_score, expected_risk_score, 0.1
    assert is_map(analysis.patterns)
    assert is_list(analysis.anomalies)
    analysis
  end

  @doc """
  Common ML model assertion
  """
  @spec assert_ml_prediction(term(), term()) :: term()
  def assert_ml_prediction(result, expected_classification) do
    assert {:ok, prediction} = result
    assert prediction.classification == expected_classification
    assert prediction.confidence >= 0.0 and prediction.confidence <= 1.0
    assert is_map(prediction.features)
    prediction
  end
end
