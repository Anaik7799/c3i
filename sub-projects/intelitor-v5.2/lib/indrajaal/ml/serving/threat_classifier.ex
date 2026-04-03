defmodule Indrajaal.ML.Serving.ThreatClassifier do
  @moduledoc """
  Nx.Serving-based threat classification for security events.

  Classifies incoming events into threat categories:
  - :critical - Immediate response required
  - :high - Urgent investigation needed
  - :medium - Standard investigation
  - :low - Monitoring only
  - :benign - False positive / normal activity

  STAMP Compliance:
  - SC-ML-001: Model serving isolation
  - SC-SEC-001: Security event classification accuracy

  Integration:
  - FLAME.IntelligencePool for heavy batch inference
  - Telemetry for latency and accuracy tracking
  """

  use GenServer

  require Logger

  @default_batch_size 10
  @default_batch_timeout 100

  # Feature extraction weights (simulated model)
  @feature_weights %{
    event_type_score: 0.25,
    source_reputation: 0.20,
    time_anomaly: 0.15,
    frequency_score: 0.15,
    pattern_match: 0.15,
    context_score: 0.10
  }

  # Threat thresholds
  @thresholds %{
    critical: 0.9,
    high: 0.7,
    medium: 0.5,
    low: 0.3
  }

  ## Client API

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Classify a single security event.

  ## Parameters
  - `event` - Map with event data (type, source, timestamp, payload)

  ## Returns
  - `{:ok, %{threat_level: atom, confidence: float, factors: map}}`
  """
  def classify(event, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5_000)
    GenServer.call(__MODULE__, {:classify, event}, timeout)
  end

  @doc """
  Classify a batch of events.
  """
  def classify_batch(events, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    GenServer.call(__MODULE__, {:classify_batch, events}, timeout)
  end

  @doc """
  Run inference via FLAME for heavy workloads.
  """
  def classify_via_flame(events) do
    alias Indrajaal.FLAME.SafeRunner

    FLAME.call(Indrajaal.FLAME.IntelligencePool, fn ->
      SafeRunner.guard_state()
      do_classify_batch(events)
    end)
  end

  ## Server Callbacks

  @impl true
  def init(opts) do
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)
    batch_timeout = Keyword.get(opts, :batch_timeout, @default_batch_timeout)

    Logger.info(
      "🎯 ThreatClassifier: Starting (batch_size: #{batch_size}, timeout: #{batch_timeout}ms)"
    )

    state = %{
      batch_size: batch_size,
      batch_timeout: batch_timeout,
      model_version: "1.0.0",
      stats: %{
        total_classified: 0,
        by_level: %{critical: 0, high: 0, medium: 0, low: 0, benign: 0}
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:classify, event}, _from, state) do
    start_time = System.monotonic_time(:microsecond)

    result = do_classify(event)

    latency_us = System.monotonic_time(:microsecond) - start_time
    emit_telemetry(:classify, latency_us, result.threat_level)

    # Update stats
    new_stats = update_stats(state.stats, result.threat_level)

    {:reply, {:ok, result}, %{state | stats: new_stats}}
  end

  @impl true
  def handle_call({:classify_batch, events}, _from, state) do
    start_time = System.monotonic_time(:microsecond)

    results = do_classify_batch(events)

    latency_us = System.monotonic_time(:microsecond) - start_time
    emit_telemetry(:classify_batch, latency_us, length(events))

    {:reply, {:ok, results}, state}
  end

  ## Private Functions

  defp do_classify(event) do
    # Extract features from event
    features = extract_features(event)

    # Compute threat score using weighted features
    threat_score = compute_threat_score(features)

    # Determine threat level
    threat_level = score_to_level(threat_score)

    %{
      threat_level: threat_level,
      confidence: threat_score,
      factors: features,
      model_version: "1.0.0",
      classified_at: DateTime.utc_now()
    }
  end

  defp do_classify_batch(events) do
    Enum.map(events, &do_classify/1)
  end

  defp extract_features(event) do
    %{
      event_type_score: event_type_score(event),
      source_reputation: source_reputation_score(event),
      time_anomaly: time_anomaly_score(event),
      frequency_score: frequency_score(event),
      pattern_match: pattern_match_score(event),
      context_score: context_score(event)
    }
  end

  # Event type scoring
  defp event_type_score(event) do
    type = Map.get(event, :type, :unknown)

    case type do
      :intrusion_attempt -> 1.0
      :authentication_failure -> 0.8
      :malware_detected -> 1.0
      :unauthorized_access -> 0.9
      :policy_violation -> 0.6
      :anomaly_detected -> 0.7
      :tamper_alert -> 0.85
      :system_error -> 0.4
      :info -> 0.1
      _ -> 0.5
    end
  end

  # Source reputation scoring (simulated)
  defp source_reputation_score(event) do
    source = Map.get(event, :source, %{})
    known = Map.get(source, :known, true)
    internal = Map.get(source, :internal, true)

    cond do
      not known -> 0.9
      not internal -> 0.6
      true -> 0.2
    end
  end

  # Time anomaly scoring (off-hours activity)
  defp time_anomaly_score(event) do
    timestamp = Map.get(event, :timestamp, DateTime.utc_now())
    hour = timestamp.hour

    cond do
      # Late night
      hour >= 0 and hour < 6 -> 0.8
      # Evening/early morning
      hour >= 22 or hour < 6 -> 0.6
      # Business hours
      true -> 0.2
    end
  end

  # Frequency scoring (rate of similar events)
  defp frequency_score(event) do
    # In production, this would check event frequency from a sliding window
    frequency = Map.get(event, :frequency, 1)

    cond do
      frequency > 100 -> 0.9
      frequency > 50 -> 0.7
      frequency > 10 -> 0.5
      true -> 0.2
    end
  end

  # Pattern matching against known attack signatures
  defp pattern_match_score(event) do
    payload = Map.get(event, :payload, "")

    attack_patterns = [
      ~r/sql.*injection/i,
      ~r/xss|<script>/i,
      ~r/\/etc\/passwd/i,
      ~r/cmd\.exe|powershell/i,
      ~r/\.\.\//
    ]

    matches = Enum.count(attack_patterns, &Regex.match?(&1, to_string(payload)))

    min(matches * 0.25, 1.0)
  end

  # Context-based scoring
  defp context_score(event) do
    context = Map.get(event, :context, %{})

    factors = [
      if(Map.get(context, :privileged_user), do: 0.3, else: 0),
      if(Map.get(context, :sensitive_resource), do: 0.3, else: 0),
      if(Map.get(context, :cross_boundary), do: 0.2, else: 0),
      if(Map.get(context, :first_occurrence), do: 0.2, else: 0)
    ]

    Enum.sum(factors)
  end

  defp compute_threat_score(features) do
    @feature_weights
    |> Enum.reduce(0.0, fn {feature, weight}, acc ->
      value = Map.get(features, feature, 0.0)
      acc + value * weight
    end)
    |> Float.round(3)
  end

  defp score_to_level(score) do
    cond do
      score >= @thresholds.critical -> :critical
      score >= @thresholds.high -> :high
      score >= @thresholds.medium -> :medium
      score >= @thresholds.low -> :low
      true -> :benign
    end
  end

  defp update_stats(stats, level) do
    %{
      stats
      | total_classified: stats.total_classified + 1,
        by_level: Map.update!(stats.by_level, level, &(&1 + 1))
    }
  end

  defp emit_telemetry(operation, latency_us, metadata) do
    :telemetry.execute(
      [:indrajaal, :ml, :threat_classifier, operation],
      %{latency_us: latency_us},
      %{metadata: metadata, model: "threat_classifier", version: "1.0.0"}
    )
  end
end
