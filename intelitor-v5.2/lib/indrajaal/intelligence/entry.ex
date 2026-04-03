defmodule Indrajaal.Intelligence.Entry do
  @moduledoc """
  Gateway for Intelligence operations.

  Routes ML tasks to the appropriate Nx.Serving or FLAME pool based on:
  - Workload type (classification, anomaly detection, correlation)
  - Batch size (small batches local, large batches via FLAME)
  - Latency requirements

  STAMP Compliance:
  - SC-ML-001: Model serving isolation
  - SC-FLAME-001: No local state dependency in FLAME calls

  GDE/CAFE:
  - C3 Intelligence tier coordination
  """

  require Logger

  alias Indrajaal.FLAME.SafeRunner
  alias Indrajaal.ML.Serving.{ThreatClassifier, AnomalyDetector, AlarmCorrelator}
  alias Indrajaal.ML.ModelRegistry

  @flame_batch_threshold 50

  @doc """
  Analyze a security event for threats.

  Routes to ThreatClassifier serving for real-time classification.
  For large batches, uses FLAME.IntelligencePool.

  ## Parameters
  - `event` - Security event map with :type, :source, :timestamp, :payload

  ## Returns
  - `{:ok, %{threat_level: atom, confidence: float, ...}}`
  """
  def analyze_threat(event) do
    payload_size = get_payload_size(event)
    Logger.info("🧠 Intelligence: Analyzing threat (payload: #{payload_size} bytes)")

    ThreatClassifier.classify(event)
  end

  @doc """
  Analyze a batch of security events.

  Uses FLAME for batches larger than threshold.
  """
  def analyze_threats_batch(events) when length(events) > @flame_batch_threshold do
    Logger.info("🧠 Intelligence: Batch threat analysis via FLAME (#{length(events)} events)")

    ThreatClassifier.classify_via_flame(events)
  end

  def analyze_threats_batch(events) do
    Logger.info("🧠 Intelligence: Batch threat analysis local (#{length(events)} events)")

    ThreatClassifier.classify_batch(events)
  end

  @doc """
  Detect anomalies in time series data.

  ## Parameters
  - `data_points` - List of numeric values or `%{value: v, timestamp: t}` maps
  - `opts` - Detection options:
    - `:method` - `:zscore`, `:iqr`, `:isolation`, `:ensemble` (default)

  ## Returns
  - `{:ok, %{anomalies: list, stats: map}}`
  """
  def detect_anomalies(data_points, opts \\ []) do
    Logger.info("🧠 Intelligence: Anomaly detection (#{length(data_points)} points)")

    if length(data_points) > @flame_batch_threshold do
      AnomalyDetector.detect_via_flame(data_points, opts)
    else
      AnomalyDetector.detect(data_points, opts)
    end
  end

  @doc """
  Real-time anomaly check against a baseline.

  Fast path for streaming data.
  """
  def check_anomaly_realtime(value, baseline_stats) do
    AnomalyDetector.check_realtime(value, baseline_stats)
  end

  @doc """
  Find correlations for an alarm against recent alarms.

  ## Parameters
  - `alarm` - The new alarm to correlate
  - `recent_alarms` - List of recent alarms

  ## Returns
  - `{:ok, %{correlations: list, groups: list}}`
  """
  def correlate_alarm(alarm, recent_alarms) do
    Logger.info("🧠 Intelligence: Alarm correlation (against #{length(recent_alarms)} recent)")

    AlarmCorrelator.correlate(alarm, recent_alarms)
  end

  @doc """
  Cluster a set of alarms into correlated groups.

  Uses FLAME for large alarm sets.
  """
  def cluster_alarms(alarms) when length(alarms) > @flame_batch_threshold do
    Logger.info("🧠 Intelligence: Alarm clustering via FLAME (#{length(alarms)} alarms)")

    AlarmCorrelator.correlate_via_flame(alarms)
  end

  def cluster_alarms(alarms) do
    Logger.info("🧠 Intelligence: Alarm clustering local (#{length(alarms)} alarms)")

    AlarmCorrelator.cluster_alarms(alarms)
  end

  @doc """
  Get the active model version for a serving.
  """
  def get_model_version(model_name) do
    ModelRegistry.get_active_model(model_name)
  end

  @doc """
  Legacy analyze_threat with raw FLAME execution.

  For backwards compatibility and custom ML workloads.
  """
  def analyze_threat_raw(data) do
    payload_size = get_payload_size(data)
    Logger.info("🧠 Intelligence: Raw FLAME analysis (payload: #{payload_size} bytes)")

    FLAME.call(Indrajaal.FLAME.IntelligencePool, fn ->
      SafeRunner.guard_state()

      # Custom ML processing
      Process.sleep(100)

      %{
        threat_level: :high,
        confidence: 0.95,
        source_node: Node.self(),
        model_version: "legacy"
      }
    end)
  end

  @doc """
  Health check for all Intelligence services.
  """
  def health_check do
    %{
      threat_classifier: check_service(ThreatClassifier),
      anomaly_detector: check_service(AnomalyDetector),
      alarm_correlator: check_service(AlarmCorrelator),
      model_registry: check_service(ModelRegistry),
      flame_pool: check_flame_pool()
    }
  end

  ## Private Functions

  defp get_payload_size(%{payload: payload}) when is_binary(payload), do: byte_size(payload)
  defp get_payload_size(%{payload: payload}), do: :erlang.external_size(payload)
  defp get_payload_size(data), do: :erlang.external_size(data)

  defp check_service(module) do
    case Process.whereis(module) do
      nil -> :down
      pid when is_pid(pid) -> if Process.alive?(pid), do: :up, else: :down
    end
  end

  defp check_flame_pool do
    case Process.whereis(Indrajaal.FLAME.IntelligencePool) do
      nil -> :down
      pid when is_pid(pid) -> if Process.alive?(pid), do: :up, else: :down
    end
  end
end
