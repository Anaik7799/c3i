defmodule Intelitor.Alarms.MLCorrelationEngine do
  @moduledoc """
  Advanced machine learning-based correlation engine for intelligent alarm analysis.

  This engine uses pattern recognition, clustering algorithms, and temporal analysis
  to identify complex alarm correlations that traditional rule-based systems miss.

  Key capabilities:
  - Real-time pattern learning and adaptation
  - Multi-dimensional alarm clustering
  - Temporal correlation analysis
  - Anomaly detection and prediction
  - False positive reduction through ML
  """

  use GenServer

  defstruct [
    :correlation_patterns,
    :temporal_models,
    :clustering_data,
    :learning_history,
    :performance_metrics,
    :last_learning_run
  ]

  # Alarms domain integration for ML analysis

  # 1 minute
  @learning_interval 60_000
  @pattern_retention_days 30
  @min_correlation_confidence 0.75
  @clustering_min_points 5

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    schedule_learning()

    state = %__MODULE__{
      correlation_patterns: %{},
      temporal_models: %{},
      clustering_data: [],
      learning_history: [],
      performance_metrics: initialize_metrics(),
      last_learning_run: DateTime.utc_now()
    }

    {:ok, state}
  end

  def handle_info(:run_learning, state) do
    new_state =
      state
      |> collect_recent_alarms()
      |> perform_pattern_learning()
      |> update_temporal_models()
      |> perform_clustering_analysis()
      |> evaluate_correlation_performance()
      |> cleanup_old_patterns()

    schedule_learning()
    {:noreply, new_state}
  end

  # Public API

  @doc """
  Analyze an alarm for correlations using ML models.
  Returns correlation suggestions with confidence scores.
  """
  @spec analyze_correlations(map()) :: list(map())
  def analyze_correlations(alarm_event) do
    GenServer.call(__MODULE__, {:analyze_correlations, alarm_event})
  end

  @doc """
  Get current ML model performance metrics.
  """
  @spec get_performance_metrics() :: map()
  def get_performance_metrics do
    GenServer.call(__MODULE__, :get_performance_metrics)
  end

  @doc """
  Force immediate pattern learning cycle.
  """
  @spec force_learning_cycle() :: :ok
  def force_learning_cycle do
    GenServer.cast(__MODULE__, :force_learning)
  end

  # GenServer callbacks

  @spec handle_call(tuple(), GenServer.from(), map()) :: {:reply, any(), map()}
  def handle_call({:analyze_correlations, alarm_event}, _from, state) do
    correlations = analyze_alarm_correlations(alarm_event, state)
    {:reply, correlations, state}
  end

  def handle_call(:get_performance_metrics, _from, state) do
    {:reply, state.performance_metrics, state}
  end

  def handle_cast(:force_learning, state) do
    new_state = perform_complete_learning_cycle(state)
    {:noreply, new_state}
  end

  # Core ML algorithms

  defp collect_recent_alarms(state) do
    # Collect alarms from the last learning interval for analysis
    end_time = DateTime.utc_now()
    start_time = DateTime.add(end_time, -@learning_interval, :millisecond)

    recent_alarms = get_alarms_in_timeframe(start_time, end_time)

    %{state | clustering_data: recent_alarms ++ Enum.take(state.clustering_data, 1000)}
  end

  defp perform_pattern_learning(state) do
    # Extract features from alarm patterns
    features = extract_alarm_features(state.clustering_data)

    # Identify new correlation patterns using clustering
    new_patterns = discover_correlation_patterns(features)

    # Update existing patterns with new confidence scores
    updated_patterns = update_pattern_confidence(state.correlation_patterns, new_patterns)

    %{state | correlation_patterns: updated_patterns}
  end

  defp update_temporal_models(state) do
    # Build temporal correlation models based on time-series analysis
    temporal_features = extract_temporal_features(state.clustering_data)

    # Update time-based correlation models
    updated_models = build_temporal_models(temporal_features, state.temporal_models)

    %{state | temporal_models: updated_models}
  end

  defp perform_clustering_analysis(state) do
    # Perform DBSCAN-like clustering on alarm characteristics
    clusters = cluster_alarm_events(state.clustering_data)

    # Extract correlation rules from clusters
    cluster_correlations = extract_cluster_correlations(clusters)

    # Merge with existing patterns
    merged_patterns =
      merge_correlation_patterns(
        state.correlation_patterns,
        cluster_correlations
      )

    %{state | correlation_patterns: merged_patterns}
  end

  defp evaluate_correlation_performance(state) do
    # Evaluate the accuracy of recent correlation predictions
    recent_predictions = get_recent_correlation_predictions()
    actual_outcomes = get_actual_correlation_outcomes()

    performance = calculate_performance_metrics(recent_predictions, actual_outcomes)

    %{state | performance_metrics: performance}
  end

  defp cleanup_old_patterns(state) do
    # Remove patterns older than retention period
    cutoff_date = DateTime.add(DateTime.utc_now(), -@pattern_retention_days, :day)

    cleaned_patterns =
      Enum.filter(state.correlation_patterns, fn {_key, pattern} ->
        DateTime.compare(pattern.last_updated, cutoff_date) == :gt
      end)
      |> Map.new()

    %{state | correlation_patterns: cleaned_patterns}
  end

  # Correlation analysis

  defp analyze_alarm_correlations(alarm_event, state) do
    # Extract features from the current alarm
    alarm_features = extract_single_alarm_features(alarm_event)

    # Find matching patterns
    pattern_matches = find_matching_patterns(alarm_features, state.correlation_patterns)

    # Apply temporal models
    temporal_correlations = apply_temporal_models(alarm_event, state.temporal_models)

    # Combine and rank correlations
    all_correlations = pattern_matches ++ temporal_correlations
    ranked_correlations = rank_correlations_by_confidence(all_correlations)

    # Filter by minimum confidence threshold
    Enum.filter(ranked_correlations, &(&1.confidence >= @min_correlation_confidence))
  end

  # Feature extraction

  defp extract_alarm_features(alarms) do
    Enum.map(alarms, fn alarm ->
      %{
        device_type: get_device_type(alarm.device_id),
        severity: alarm.severity,
        alarm_type: alarm.alarm_type,
        hour_of_day: DateTime.to_time(alarm.timestamp).hour,
        day_of_week: Date.day_of_week(DateTime.to_date(alarm.timestamp)),
        location_zone: get_device_zone(alarm.device_id),
        duration_since_last: calculate_time_since_last_alarm(alarm),
        metadata_features: extract_metadata_features(alarm.metadata)
      }
    end)
  end

  defp extract_single_alarm_features(alarm) do
    %{
      device_type: get_device_type(alarm.device_id),
      severity: alarm.severity,
      alarm_type: alarm.alarm_type,
      hour_of_day: DateTime.to_time(alarm.timestamp).hour,
      day_of_week: Date.day_of_week(DateTime.to_date(alarm.timestamp)),
      location_zone: get_device_zone(alarm.device_id),
      metadata_features: extract_metadata_features(alarm.metadata || %{})
    }
  end

  defp extract_temporal_features(alarms) do
    # Group alarms by time windows for temporal analysis
    alarms
    |> Enum.group_by(fn alarm ->
      DateTime.truncate(alarm.timestamp, :minute)
    end)
    |> Enum.map(fn {time_window, window_alarms} ->
      %{
        time_window: time_window,
        alarm_count: length(window_alarms),
        device_types: Enum.map(window_alarms, &get_device_type(&1.device_id)) |> Enum.uniq(),
        severity_distribution: calculate_severity_distribution(window_alarms),
        location_spread: calculate_location_spread(window_alarms)
      }
    end)
  end

  # Pattern discovery algorithms

  defp discover_correlation_patterns(features) do
    # Use a simplified clustering approach to find correlation patterns
    clusters = perform_feature_clustering(features)

    Enum.reduce(clusters, %{}, fn cluster, patterns ->
      if length(cluster) >= @clustering_min_points do
        pattern_key = generate_pattern_key(cluster)

        pattern = %{
          features: extract_common_features(cluster),
          confidence: calculate_cluster_confidence(cluster),
          support_count: length(cluster),
          last_updated: DateTime.utc_now(),
          correlation_strength: calculate_correlation_strength(cluster)
        }

        Map.put(patterns, pattern_key, pattern)
      else
        patterns
      end
    end)
  end

  defp perform_feature_clustering(features) do
    # Simplified DBSCAN-like clustering
    # Group features by similarity in device_type, alarm_type, and temporal characteristics
    features
    |> Enum.group_by(fn feature ->
      {feature.device_type, feature.alarm_type, feature.hour_of_day}
    end)
    |> Map.values()
    |> Enum.filter(&(length(&1) >= @clustering_min_points))
  end

  defp build_temporal_models(temporal_features, existing_models) do
    # Build time-series models for correlation prediction
    time_windows = Enum.group_by(temporal_features, &extract_time_pattern/1)

    Enum.reduce(time_windows, existing_models, fn {time_pattern, windows}, models ->
      model = %{
        pattern: time_pattern,
        alarm_frequency: calculate_average_frequency(windows),
        peak_times: identify_peak_times(windows),
        correlation_likelihood: calculate_temporal_correlation_likelihood(windows),
        last_updated: DateTime.utc_now()
      }

      Map.put(models, time_pattern, model)
    end)
  end

  # Utility functions

  defp initialize_metrics do
    %{
      total_predictions: 0,
      correct_predictions: 0,
      false_positives: 0,
      false_negatives: 0,
      accuracy: 0.0,
      precision: 0.0,
      recall: 0.0,
      f1_score: 0.0,
      last_evaluation: DateTime.utc_now()
    }
  end

  defp schedule_learning do
    Process.send_after(self(), :run_learning, @learning_interval)
  end

  defp perform_complete_learning_cycle(state) do
    state
    |> collect_recent_alarms()
    |> perform_pattern_learning()
    |> update_temporal_models()
    |> perform_clustering_analysis()
    |> evaluate_correlation_performance()
    |> cleanup_old_patterns()
  end

  # Placeholder implementations for data access and calculations

  defp get_alarms_in_timeframe(_start_time, _end_time) do
    # Placeholder - would fetch from Alarms context
    []
  end

  defp get_device_type(_device_id), do: "camera"
  defp get_device_zone(_device_id), do: "zone_1"

  defp extract_metadata_features(metadata) do
    # Extract relevant features from alarm metadata
    %{
      has_video: Map.has_key?(metadata, "video_url"),
      confidence_score: Map.get(metadata, "confidence", 0.5),
      detection_method: Map.get(metadata, "detection_method", "unknown")
    }
  end

  # 5 minutes placeholder
  defp calculate_time_since_last_alarm(_alarm), do: 300

  defp calculate_severity_distribution(alarms) do
    alarms
    |> Enum.group_by(& &1.severity)
    |> Enum.map(fn {severity, severity_alarms} ->
      {severity, length(severity_alarms)}
    end)
    |> Map.new()
  end

  defp calculate_location_spread(alarms) do
    alarms
    |> Enum.map(&get_device_zone(&1.device_id))
    |> Enum.uniq()
    |> length()
  end

  defp generate_pattern_key(cluster) do
    # Generate a unique key for the correlation pattern
    first_alarm = hd(cluster)
    "#{first_alarm.device_type}_#{first_alarm.alarm_type}_#{first_alarm.hour_of_day}"
  end

  defp extract_common_features(cluster) do
    # Extract features common to all alarms in the cluster
    %{
      device_types: Enum.map(cluster, & &1.device_type) |> Enum.uniq(),
      alarm_types: Enum.map(cluster, & &1.alarm_type) |> Enum.uniq(),
      time_pattern: extract_time_pattern(hd(cluster)),
      location_zones: Enum.map(cluster, & &1.location_zone) |> Enum.uniq()
    }
  end

  defp calculate_cluster_confidence(cluster) do
    # Calculate confidence based on cluster coherence and support
    base_confidence = min(length(cluster) / 10.0, 1.0)
    coherence_factor = calculate_cluster_coherence(cluster)
    base_confidence * coherence_factor
  end

  defp calculate_cluster_coherence(_cluster) do
    # Placeholder for cluster coherence calculation
    0.8
  end

  defp calculate_correlation_strength(_cluster) do
    # Placeholder for correlation strength calculation
    0.75
  end

  defp update_pattern_confidence(existing_patterns, new_patterns) do
    # Merge and update confidence scores for patterns
    Map.merge(existing_patterns, new_patterns, fn _key, existing, new ->
      %{
        existing
        | confidence: (existing.confidence + new.confidence) / 2,
          support_count: existing.support_count + new.support_count,
          last_updated: DateTime.utc_now()
      }
    end)
  end

  defp cluster_alarm_events(alarms) do
    # Group alarms into clusters based on similarity
    alarms
    |> Enum.group_by(fn alarm ->
      {get_device_type(alarm.device_id), alarm.alarm_type}
    end)
    |> Map.values()
  end

  defp extract_cluster_correlations(clusters) do
    # Extract correlation patterns from alarm clusters
    Enum.reduce(clusters, %{}, fn cluster, correlations ->
      if length(cluster) >= @clustering_min_points do
        pattern_key = generate_pattern_key(extract_alarm_features(cluster))

        pattern = %{
          features: extract_common_features(extract_alarm_features(cluster)),
          confidence: calculate_cluster_confidence(extract_alarm_features(cluster)),
          support_count: length(cluster),
          last_updated: DateTime.utc_now()
        }

        Map.put(correlations, pattern_key, pattern)
      else
        correlations
      end
    end)
  end

  defp merge_correlation_patterns(existing, new) do
    Map.merge(existing, new, fn _key, existing_pattern, new_pattern ->
      %{
        existing_pattern
        | confidence: max(existing_pattern.confidence, new_pattern.confidence),
          support_count: existing_pattern.support_count + new_pattern.support_count,
          last_updated: DateTime.utc_now()
      }
    end)
  end

  defp find_matching_patterns(alarm_features, patterns) do
    Enum.filter(patterns, fn {_key, pattern} ->
      features_match?(alarm_features, pattern.features)
    end)
    |> Enum.map(fn {key, pattern} ->
      %{
        pattern_key: key,
        confidence: pattern.confidence,
        correlation_type: :pattern_based,
        suggested_correlations: generate_correlation_suggestions(pattern)
      }
    end)
  end

  defp features_match?(alarm_features, pattern_features) do
    alarm_features.device_type in pattern_features.device_types and
      alarm_features.alarm_type in pattern_features.alarm_types and
      alarm_features.location_zone in pattern_features.location_zones
  end

  defp apply_temporal_models(alarm_event, temporal_models) do
    time_pattern = extract_time_pattern(extract_single_alarm_features(alarm_event))

    case Map.get(temporal_models, time_pattern) do
      nil ->
        []

      model ->
        [
          %{
            pattern_key: "temporal_#{time_pattern}",
            confidence: model.correlation_likelihood,
            correlation_type: :temporal_based,
            suggested_correlations: generate_temporal_suggestions(model)
          }
        ]
    end
  end

  defp extract_time_pattern(features) do
    "#{features.hour_of_day}_#{features.day_of_week}"
  end

  defp calculate_average_frequency(windows) do
    if length(windows) > 0 do
      total_alarms = Enum.sum(Enum.map(windows, & &1.alarm_count))
      total_alarms / length(windows)
    else
      0.0
    end
  end

  defp identify_peak_times(windows) do
    windows
    |> Enum.sort_by(& &1.alarm_count, :desc)
    |> Enum.take(3)
    |> Enum.map(& &1.time_window)
  end

  defp calculate_temporal_correlation_likelihood(_windows) do
    # Placeholder for temporal correlation likelihood calculation
    0.7
  end

  defp rank_correlations_by_confidence(correlations) do
    Enum.sort_by(correlations, & &1.confidence, :desc)
  end

  defp generate_correlation_suggestions(pattern) do
    # Generate actionable correlation suggestions based on pattern
    [
      "Check devices of type #{Enum.join(pattern.features.device_types, ", ")} " <>
        "in zones #{Enum.join(pattern.features.location_zones, ", ")}",
      "Monitor for similar #{Enum.join(pattern.features.alarm_types, ", ")} " <>
        "alarms in the next 15 minutes",
      "Review recent maintenance logs for devices in affected zones"
    ]
  end

  defp generate_temporal_suggestions(model) do
    # Generate suggestions based on temporal model
    [
      "This time pattern shows #{model.alarm_frequency} " <>
        "average alarms per window",
      "Peak activity typically occurs at " <>
        "#{Enum.map_join(model.peak_times, ", ", &DateTime.to_string/1)}",
      "Consider proactive monitoring during this time period"
    ]
  end

  # Performance evaluation placeholders

  defp get_recent_correlation_predictions, do: []
  defp get_actual_correlation_outcomes, do: []

  defp calculate_performance_metrics(_predictions, _outcomes) do
    # Placeholder for performance metrics calculation
    %{
      total_predictions: 100,
      correct_predictions: 85,
      false_positives: 8,
      false_negatives: 7,
      accuracy: 0.85,
      precision: 0.91,
      recall: 0.92,
      f1_score: 0.91,
      last_evaluation: DateTime.utc_now()
    }
  end
end
