defmodule Intelitor.Alarms.CorrelationEngine do
  @moduledoc """
  Advanced correlation analysis engine for pattern detection across
  spatial, temporal, device, and cross-domain dimensions.
  """

  # These aliases are available for future correlation implementations
  # alias Intelitor.Alarms
  # alias Intelitor.Sites
  # alias Intelitor.AccessControl
  # alias Intelitor.Video
  # alias Intelitor.Devices

  @correlation_window_minutes 5
  # @spatial_proximity_meters 50  # Available for spatial analysis

  @doc """
  Analyze an alarm for correlations with other events and patterns.
  """
  def analyze(alarm) do
    correlations =
      [
        &spatial_correlation/1,
        &temporal_correlation/1,
        &device_correlation/1,
        &pattern_correlation/1,
        &cross_domain_correlation/1
      ]
      |> Enum.map(& &1.(alarm))
      |> Enum.filter(& &1.correlated)

    if Enum.any?(correlations) do
      create_correlation_group(alarm, correlations)
    else
      {:ok, alarm}
    end
  end

  @doc """
  Finalize correlations after the correlation window has closed.
  """
  def finalize_correlations(alarm) do
    correlations = get_all_correlations(alarm)

    analysis = %{
      correlation_count: length(correlations),
      correlation_types: Enum.map(correlations, & &1.type) |> Enum.uniq(),
      confidence_score: calculate_correlation_confidence(correlations),
      recommended_action: determine_recommended_action(correlations)
    }

    {:ok, analysis}
  end

  # Correlation Types

  defp spatial_correlation(alarm) do
    # Find alarms in adjacent locations
    _adjacent_locations = get_adjacent_locations(alarm.site_id, alarm.zone_id)

    # Future implementation: Query recent alarms from adjacent locations
    # recent_alarms = Alarms.list_alarm_events(%{
    #   filters: %{
    #     location_ids: adjacent_locations,
    #     triggered_after: DateTime.add(alarm.triggered_at, -@correlation_window_minutes * 60, :second),
    #     states: [:triggered, :acknowledged, :investigating]
    #   }
    # })
    recent_alarms = []

    if not Enum.empty?(recent_alarms) do
      %{
        correlated: true,
        type: :spatial,
        confidence: calculate_spatial_confidence(alarm, recent_alarms),
        related_alarms: Enum.map(recent_alarms, & &1.id),
        pattern: detect_movement_pattern(alarm, recent_alarms),
        details: %{
          alarm_count: length(recent_alarms),
          locations:
            recent_alarms
            |> Enum.map(& &1.location_details)
            |> Enum.uniq()
        }
      }
    else
      %{correlated: false, type: :spatial}
    end
  end

  defp temporal_correlation(alarm) do
    # Look for temporal patterns
    _time_window = {@correlation_window_minutes * -1, :minutes}

    # Future implementation: Query similar alarms in time window
    # similar_alarms = Alarms.list_alarm_events(%{
    #   filters: %{
    #     event_type: alarm.event_type,
    #     site_id: alarm.site_id,
    #     time_range: {DateTime.add(alarm.triggered_at, elem(time_window, 0) * 60, :second), alarm.triggered_at}
    #   }
    # })
    similar_alarms = []

    if length(similar_alarms) >= 2 do
      intervals = calculate_time_intervals(similar_alarms ++ [alarm])

      %{
        correlated: true,
        type: :temporal,
        confidence: evaluate_temporal_pattern(intervals),
        related_alarms: Enum.map(similar_alarms, & &1.id),
        pattern: detect_temporal_pattern(intervals),
        details: %{
          event_count: length(similar_alarms) + 1,
          average_interval: calculate_average_interval(intervals),
          pattern_type: classify_temporal_pattern(intervals)
        }
      }
    else
      %{correlated: false, type: :temporal}
    end
  end

  defp device_correlation(alarm) do
    if is_nil(alarm.device_id) do
      %{correlated: false, type: :device}
    else
      # Check device malfunction patterns
      # Future implementation: Query device-specific alarms
      # device_alarms = Alarms.list_alarm_events(%{
      #   filters: %{
      #     device_id: alarm.device_id,
      #     triggered_after: DateTime.add(alarm.triggered_at, -60 * 60, :second)  # Last hour
      #   }
      # })
      device_alarms = []

      if length(device_alarms) >= 5 do
        %{
          correlated: true,
          type: :device,
          confidence: 0.8,
          related_alarms: Enum.map(device_alarms, & &1.id),
          pattern: :potential_malfunction,
          details: %{
            alarm_count: length(device_alarms),
            event_types:
              device_alarms
              |> Enum.map(& &1.event_type)
              |> Enum.frequencies(),
            recommendation: "Check device health and consider maintenance"
          }
        }
      else
        %{correlated: false, type: :device}
      end
    end
  end

  defp pattern_correlation(alarm) do
    # Look for known attack patterns
    patterns = [
      check_perimeter_probe_pattern(alarm),
      check_systematic_testing_pattern(alarm),
      check_distraction_pattern(alarm)
    ]

    matched_patterns = Enum.filter(patterns, & &1.matched)

    if Enum.any?(matched_patterns) do
      %{
        correlated: true,
        type: :pattern,
        confidence:
          matched_patterns
          |> Enum.max_by(& &1.confidence)
          |> Map.get(:confidence),
        patterns: matched_patterns,
        details: %{
          pattern_names: Enum.map(matched_patterns, & &1.name),
          recommended_response: determine_pattern_response(matched_patterns)
        }
      }
    else
      %{correlated: false, type: :pattern}
    end
  end

  defp cross_domain_correlation(alarm) do
    correlations = []

    # Access control events
    access_events = get_access_events_near_alarm(alarm)

    correlations =
      if not Enum.empty?(access_events) do
        [
          %{
            domain: :access_control,
            events: access_events,
            significance: :high,
            description: "Access denied events preceding alarm"
          }
          | correlations
        ]
      else
        correlations
      end

    # Video analytics events
    video_events = get_video_events_near_alarm(alarm)

    correlations =
      if not Enum.empty?(video_events) do
        [
          %{
            domain: :video,
            events: video_events,
            significance: calculate_video_significance(video_events),
            description: "Video analytics detected activity"
          }
          | correlations
        ]
      else
        correlations
      end

    # Device status changes
    device_events = get_device_status_changes(alarm)

    correlations =
      if not Enum.empty?(device_events) do
        [
          %{
            domain: :devices,
            events: device_events,
            significance: :medium,
            description: "Device status changes detected"
          }
          | correlations
        ]
      else
        correlations
      end

    %{
      correlated: not Enum.empty?(correlations),
      type: :cross_domain,
      correlations: correlations,
      confidence: calculate_cross_domain_confidence(correlations)
    }
  end

  # Pattern Detection Functions

  defp check_perimeter_probe_pattern(alarm) do
    # Check for systematic perimeter testing
    _perimeter_zones = get_perimeter_zones(alarm.site_id)

    # Future implementation: Query perimeter alarms
    # recent_perimeter_alarms = Alarms.list_alarm_events(%{
    #   filters: %{
    #     zone_ids: perimeter_zones,
    #     triggered_after: DateTime.add(alarm.triggered_at, -30 * 60, :second),
    #     event_types: [:intrusion, :tamper]
    #   }
    # })
    recent_perimeter_alarms = []

    if length(recent_perimeter_alarms) >= 3 do
      %{
        matched: true,
        name: :perimeter_probe,
        confidence: min(0.9, length(recent_perimeter_alarms) * 0.2),
        description: "Systematic perimeter testing detected",
        evidence: Enum.map(recent_perimeter_alarms, & &1.id)
      }
    else
      %{matched: false, name: :perimeter_probe}
    end
  end

  defp check_systematic_testing_pattern(_alarm) do
    # Look for alarm testing pattern (regular intervals)
    # Future implementation: Query similar type alarms
    # similar_type_alarms = Alarms.list_alarm_events(%{
    #   filters: %{
    #     site_id: alarm.site_id,
    #     event_type: alarm.event_type,
    #     triggered_after: DateTime.add(alarm.triggered_at, -120 * 60, :second)
    #   }
    # })
    similar_type_alarms = []

    if length(similar_type_alarms) >= 4 do
      intervals = calculate_time_intervals(similar_type_alarms)
      std_dev = calculate_standard_deviation(intervals)

      # Less than 1 minute deviation
      if std_dev < 60 do
        %{
          matched: true,
          name: :systematic_testing,
          confidence: 0.85,
          description: "Regular interval testing pattern detected",
          evidence: %{
            interval_seconds: Enum.sum(intervals) / length(intervals),
            standard_deviation: std_dev
          }
        }
      else
        %{matched: false, name: :systematic_testing}
      end
    else
      %{matched: false, name: :systematic_testing}
    end
  end

  defp check_distraction_pattern(alarm) do
    # Check for distraction pattern (low priority followed by high priority)
    if alarm.event_type in [:trouble, :supervisory, :tamper] do
      # Future implementation: Query subsequent high-priority alarms
      # subsequent_alarms = Alarms.list_alarm_events(%{
      #   filters: %{
      #     site_id: alarm.site_id,
      #     triggered_after: alarm.triggered_at,
      #     triggered_before: DateTime.add(alarm.triggered_at, 10 * 60, :second),
      #     severities: [:high, :critical]
      #   }
      # })
      subsequent_alarms = []

      if not Enum.empty?(subsequent_alarms) do
        %{
          matched: true,
          name: :distraction,
          confidence: 0.75,
          description: "Potential distraction pattern detected",
          evidence: %{
            distraction_alarm: alarm.id,
            target_alarms: Enum.map(subsequent_alarms, & &1.id)
          }
        }
      else
        %{matched: false, name: :distraction}
      end
    else
      %{matched: false, name: :distraction}
    end
  end

  # Helper Functions

  defp create_correlation_group(alarm, correlations) do
    correlation_data = %{
      correlations: correlations,
      correlation_id: Ecto.UUID.generate(),
      correlated_at: DateTime.utc_now()
    }

    updated_metadata = Map.merge(alarm.metadata || %{}, correlation_data)

    # Future implementation: Update alarm with correlation data
    # Alarms.update_alarm_event(alarm, %{
    #   metadata: updated_metadata,
    #   correlated_events: extract_related_alarm_ids(correlations)
    # })
    {:ok,
     Map.merge(alarm, %{
       metadata: updated_metadata,
       correlated_events: extract_related_alarm_ids(correlations)
     })}
  end

  defp get_adjacent_locations(_site_id, zone_id) do
    # This would fetch actual adjacent locations from Sites domain
    # For now, returning mock data
    [zone_id]
  end

  defp detect_movement_pattern(alarm, related_alarms) do
    # Sort by time and analyze movement
    _sorted = Enum.sort_by([alarm | related_alarms], & &1.triggered_at)

    # This would analyze actual movement patterns
    # For now, returning a simple pattern
    :sequential_movement
  end

  defp calculate_spatial_confidence(_alarm, _related_alarms) do
    # Calculate confidence based on proximity and timing
    base_confidence = 0.5
    proximity_factor = 0.3
    timing_factor = 0.2

    base_confidence + proximity_factor + timing_factor
  end

  defp calculate_time_intervals(alarms) do
    sorted = Enum.sort_by(alarms, & &1.triggered_at)

    sorted
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [a, b] ->
      DateTime.diff(b.triggered_at, a.triggered_at)
    end)
  end

  defp calculate_average_interval(intervals) do
    if not Enum.empty?(intervals) do
      Enum.sum(intervals) / length(intervals)
    else
      0
    end
  end

  defp calculate_standard_deviation(intervals) do
    if Enum.empty?(intervals) do
      0
    else
      mean = calculate_average_interval(intervals)

      variance =
        Enum.reduce(intervals, 0, fn x, acc ->
          acc + :math.pow(x - mean, 2)
        end) / length(intervals)

      :math.sqrt(variance)
    end
  end

  defp evaluate_temporal_pattern(intervals) do
    if length(intervals) < 2 do
      0.0
    else
      std_dev = calculate_standard_deviation(intervals)
      mean = calculate_average_interval(intervals)

      # Lower std deviation means higher confidence in pattern
      if mean > 0 do
        coefficient_of_variation = std_dev / mean
        max(0.0, 1.0 - coefficient_of_variation)
      else
        0.0
      end
    end
  end

  defp classify_temporal_pattern(intervals) do
    if length(intervals) < 2 do
      :irregular
    else
      std_dev = calculate_standard_deviation(intervals)
      _mean = calculate_average_interval(intervals)

      cond do
        std_dev < 30 -> :regular
        std_dev < 120 -> :semi_regular
        true -> :irregular
      end
    end
  end

  defp detect_temporal_pattern(intervals) do
    pattern_type = classify_temporal_pattern(intervals)

    case pattern_type do
      :regular -> :systematic_activity
      :semi_regular -> :organized_activity
      :irregular -> :random_activity
    end
  end

  defp get_access_events_near_alarm(_alarm) do
    # This would query AccessControl domain
    # For now, returning empty list
    []
  end

  defp get_video_events_near_alarm(_alarm) do
    # This would query Video domain
    # For now, returning empty list
    []
  end

  defp get_device_status_changes(_alarm) do
    # This would query Devices domain
    # For now, returning empty list
    []
  end

  defp calculate_video_significance(_video_events) do
    # This would analyze video event significance
    :medium
  end

  defp get_perimeter_zones(_site_id) do
    # This would fetch actual perimeter zones
    []
  end

  defp extract_related_alarm_ids(correlations) do
    correlations
    |> Enum.flat_map(fn corr ->
      Map.get(corr, :related_alarms, [])
    end)
    |> Enum.uniq()
  end

  defp get_all_correlations(_alarm) do
    # This would fetch all correlations for the alarm
    []
  end

  defp calculate_correlation_confidence(correlations) do
    if not Enum.empty?(correlations) do
      confidences = Enum.map(correlations, &(&1[:confidence] || 0.5))
      Enum.sum(confidences) / length(confidences)
    else
      0.0
    end
  end

  defp calculate_cross_domain_confidence(correlations) do
    base = 0.5
    increment = 0.15

    min(1.0, base + length(correlations) * increment)
  end

  defp determine_recommended_action(correlations) do
    cond do
      length(correlations) >= 3 -> :immediate_dispatch
      Enum.any?(correlations, &(&1[:confidence] > 0.8)) -> :priority_investigation
      true -> :standard_response
    end
  end

  defp determine_pattern_response(patterns) do
    priority_pattern = Enum.max_by(patterns, & &1.confidence)

    case priority_pattern.name do
      :perimeter_probe -> "Dispatch to perimeter, review video footage"
      :systematic_testing -> "Investigate potential system compromise"
      :distraction -> "High alert - check all secure areas"
      _ -> "Standard investigation protocol"
    end
  end
end
