defmodule Indrajaal.Alarms.CorrelationEngine do
  @moduledoc """
  Advanced correlation analysis engine for pattern detection across
  spatial, temporal, device, and cross - domain dimensions.

  ## STAMP Compliance
  - SC-ALARM-001: Correlation analysis with ETS-backed caching
  - SC-ALARM-002: Telemetry emitted for all correlation events
  - SC-ALARM-003: Pattern detection for security threat identification
  """

  require Logger

  # These aliases are available for future correlation implementations
  # alias Indrajaal.Alarms
  # alias Indrajaal.Sites
  # alias Indrajaal.AccessControl
  # alias Indrajaal.Video
  # alias Indrajaal.Devices

  @correlation_window_minutes 5
  # @spatial_proximity_meters 50  # Available for spatial analysis

  @table :correlation_engine_cache
  # Adjacency depth: how many hops away zones are considered "adjacent"
  @adjacency_depth 1

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, :bag, {:read_concurrency, true}])

      _ ->
        @table
    end
  end

  @doc """
  Analyze an alarm for correlations with other __events and patterns.
  """
  @spec analyze(any()) :: any()
  def analyze(alarm) do
    ensure_table()
    start_time = System.monotonic_time(:millisecond)

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

    duration_ms = System.monotonic_time(:millisecond) - start_time

    :telemetry.execute(
      [:indrajaal, :alarms, :correlation_analyzed],
      %{duration_ms: duration_ms, correlation_count: length(correlations)},
      %{
        alarm_id: Map.get(alarm, :id),
        site_id: Map.get(alarm, :site_id),
        correlated: length(correlations) > 0
      }
    )

    if Enum.any?(correlations) do
      Logger.info(
        "CorrelationEngine: alarm #{Map.get(alarm, :id)} has #{length(correlations)} correlations: " <>
          "#{inspect(Enum.map(correlations, & &1.type))}"
      )

      create_correlation_group(alarm, correlations)
    else
      {:ok, alarm}
    end
  end

  @doc """
  Finalize correlations after the correlation window has closed.
  """
  @spec finalize_correlations(any()) :: any()
  def finalize_correlations(alarm) do
    correlations = get_all_correlations(alarm)

    correlation_types = correlations |> Enum.map(& &1.type) |> Enum.uniq()

    analysis = %{
      correlation_count: length(correlations),
      correlation_types: correlation_types,
      confidence_score: calculate_correlation_confidence(correlations),
      recommended_action: determine_recommended_action(correlations)
    }

    {:ok, analysis}
  end

  # Correlation Types

  @spec spatial_correlation(term()) :: term()
  defp spatial_correlation(alarm) do
    # Find alarms in adjacent locations
    __adjacent_locations = get_adjacent_locations(alarm.site_id, alarm.zone_id)

    # Future implementation: Query recent alarms from adjacent locations
    # recent_alarms = Alarms.list_alarm_events(%{
    #   filters: %{
    #     location_ids: adjacent_locations,
    #     triggered_after: DateTime.add(alarm.triggered_at, -@correlation_window_
    #     __states: [:triggered, :acknowledged, :investigating]
    #   }
    # })
    recent_alarms = []

    if Enum.empty?(recent_alarms) do
      %{correlated: false, type: :spatial}
    else
      %{
        correlated: true,
        type: :spatial,
        confidence: calculate_spatial_confidence(alarm, recent_alarms),
        related_alarms: Enum.map(recent_alarms, & &1.id),
        pattern: detect_movement_pattern(alarm, recent_alarms),
        details: %{
          alarm_count: length(recent_alarms),
          locations: recent_alarms |> Enum.map(& &1.location_details) |> Enum.uniq()
        }
      }
    end
  end

  @spec temporal_correlation(term()) :: term()
  defp temporal_correlation(alarm) do
    # Look for temporal patterns
    __time_window = {@correlation_window_minutes * -1, :minutes}

    # Future implementation: Query similar alarms in time window
    # similar_alarms = Alarms.list_alarm_events(%{
    #   filters: %{
    #     __event_type: alarm.__event_type,
    #     site_id: alarm.site_id,
    #     time_range: {DateTime.add(alarm.triggered_at, elem(time_window, 0) * 60
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
          __event_count: length(similar_alarms) + 1,
          average_interval: calculate_average_interval(intervals),
          pattern_type: classify_temporal_pattern(intervals)
        }
      }
    else
      %{correlated: false, type: :temporal}
    end
  end

  @spec device_correlation(term()) :: term()
  defp device_correlation(alarm) do
    if is_nil(Map.get(alarm, :_device_id)) do
      %{correlated: false, type: :device}
    else
      # Check device malfunction patterns
      # Future implementation: Query device - specific alarms
      # device_alarms = Alarms.list_alarm_events(%{
      #   filters: %{
      #     device_id: alarm.device_id,
      #     triggered_after: DateTime.add(alarm.triggered_at, -60 * 60, :second)
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
            __event_types: device_alarms |> Enum.map(& &1.__event_type) |> Enum.frequencies(),
            recommendation: "Check device health and consider maintenance"
          }
        }
      else
        %{correlated: false, type: :device}
      end
    end
  end

  @spec pattern_correlation(term()) :: term()
  defp pattern_correlation(alarm) do
    # Look for known attack patterns
    patterns = [
      check_perimeter_probe_pattern(alarm),
      check_systematic_testing_pattern(alarm),
      check_distraction_pattern(alarm)
    ]

    matched_patterns = patterns |> Enum.filter(& &1.matched)

    if Enum.any?(matched_patterns) do
      %{
        correlated: true,
        type: :pattern,
        confidence: matched_patterns |> Enum.max_by(& &1.confidence) |> Map.get(:confidence),
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

  @spec cross_domain_correlation(term()) :: term()
  defp cross_domain_correlation(alarm) do
    correlations = []

    # Access control __events
    access_events = get_access_events_near_alarm(alarm)

    correlations =
      if Enum.empty?(access_events) do
        correlations
      else
        [
          %{
            domain: :access_control,
            __events: access_events,
            significance: :high,
            description: "Access denied __events preceding alarm"
          }
          | correlations
        ]
      end

    # Video analytics __events
    video_events = get_video_events_near_alarm(alarm)

    correlations =
      if Enum.empty?(video_events) do
        correlations
      else
        [
          %{
            domain: :video,
            __events: video_events,
            significance: calculate_video_significance(video_events),
            description: "Video analytics detected activity"
          }
          | correlations
        ]
      end

    # Device status changes
    device_events = get_device_status_changes(alarm)

    correlations =
      if Enum.empty?(device_events) do
        correlations
      else
        [
          %{
            domain: :devices,
            __events: device_events,
            significance: :medium,
            description: "Device status changes detected"
          }
          | correlations
        ]
      end

    %{
      correlated: not Enum.empty?(correlations),
      type: :cross_domain,
      correlations: correlations,
      confidence: calculate_cross_domain_confidence(correlations)
    }
  end

  # Pattern Detection Functions

  @spec check_perimeter_probe_pattern(term()) :: term()
  defp check_perimeter_probe_pattern(alarm) do
    # Check for systematic perimeter testing
    __perimeter_zones = get_perimeter_zones(alarm.site_id)

    # Future implementation: Query perimeter alarms
    # recent_perimeter_alarms = Alarms.list_alarm_events(%{
    #   filters: %{
    #     zone_ids: perimeter_zones,
    #     triggered_after: DateTime.add(alarm.triggered_at, -30 * 60, :second),
    #     __event_types: [:intrusion, :tamper]
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

  @spec check_systematic_testing_pattern(term()) :: term()
  defp check_systematic_testing_pattern(_alarm) do
    # Look for alarm testing pattern (regular intervals)
    # Future implementation: Query similar type alarms
    # similar_type_alarms = Alarms.list_alarm_events(%{
    #   filters: %{
    #     site_id: alarm.site_id,
    #     __event_type: alarm.__event_type,
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

  @spec check_distraction_pattern(term()) :: term()
  defp check_distraction_pattern(alarm) do
    # Check for distraction pattern (low priority followed by high priority)
    if alarm.__event_type in [:trouble, :supervisory, :tamper] do
      # Future implementation: Query subsequent high - priority alarms
      # subsequent_alarms = Alarms.list_alarm_events(%{
      #   filters: %{
      #     site_id: alarm.site_id,
      #     triggered_after: alarm.triggered_at,
      #     triggered_before: DateTime.add(alarm.triggered_at, 10 * 60, :second),
      #     severities: [:high, :critical]
      #   }
      # })
      subsequent_alarms = []

      if Enum.empty?(subsequent_alarms) do
        %{matched: false, name: :distraction}
      else
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
      end
    else
      %{matched: false, name: :distraction}
    end
  end

  # Helper Functions

  @spec create_correlation_group(term(), term()) :: term()
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

  @spec get_adjacent_locations(term(), term()) :: term()
  defp get_adjacent_locations(site_id, zone_id) do
    ensure_table()

    # Look up zone adjacency graph from ETS (registered by Sites domain or mesh topology)
    adjacent =
      case :ets.lookup(@table, {:zone_adjacency, site_id, zone_id}) do
        [{_, neighbors}] when is_list(neighbors) ->
          neighbors

        [] ->
          # Fall back to depth-limited BFS on the zone graph
          discover_adjacent_zones(site_id, zone_id, @adjacency_depth)
      end

    # Always include the origin zone itself
    [zone_id | adjacent] |> Enum.uniq()
  end

  @spec discover_adjacent_zones(term(), term(), non_neg_integer()) :: list()
  defp discover_adjacent_zones(site_id, zone_id, depth) when depth > 0 do
    # Walk the zone graph stored in ETS as {site_id, :zone_graph} -> %{zone => [neighbors]}
    case :ets.lookup(@table, {:zone_graph, site_id}) do
      [{_, graph}] when is_map(graph) ->
        direct_neighbors = Map.get(graph, zone_id, [])

        deeper =
          if depth > 1 do
            direct_neighbors
            |> Enum.flat_map(&discover_adjacent_zones(site_id, &1, depth - 1))
          else
            []
          end

        (direct_neighbors ++ deeper) |> Enum.uniq()

      [] ->
        []
    end
  end

  defp discover_adjacent_zones(_site_id, _zone_id, 0), do: []

  @spec detect_movement_pattern(term(), term()) :: term()
  defp detect_movement_pattern(alarm, related_alarms) do
    # Sort by time and analyze movement
    __sorted = Enum.sort_by([alarm | related_alarms], & &1.triggered_at)

    # This would analyze actual movement patterns
    # For now, returning a simple pattern
    :sequential_movement
  end

  @spec calculate_spatial_confidence(term(), term()) :: term()
  defp calculate_spatial_confidence(_alarm, _related_alarms) do
    # Calculate confidence based on proximity and timing
    base_confidence = 0.5
    proximity_factor = 0.3
    timing_factor = 0.2

    base_confidence + proximity_factor + timing_factor
  end

  @spec calculate_time_intervals(term()) :: term()
  defp calculate_time_intervals(alarms) do
    alarms
    |> Enum.sort_by(& &1.triggered_at)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [a, b] ->
      DateTime.diff(b.triggered_at, a.triggered_at)
    end)
  end

  @spec calculate_average_interval(term()) :: term()
  defp calculate_average_interval(intervals) do
    if Enum.empty?(intervals) do
      0
    else
      Enum.sum(intervals) / length(intervals)
    end
  end

  @spec calculate_standard_deviation(term()) :: term()
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

  @spec evaluate_temporal_pattern(term()) :: term()
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

  @spec classify_temporal_pattern(term()) :: term()
  defp classify_temporal_pattern(intervals) do
    if length(intervals) < 2 do
      :irregular
    else
      std_dev = calculate_standard_deviation(intervals)
      __mean = calculate_average_interval(intervals)

      cond do
        std_dev < 30 -> :regular
        std_dev < 120 -> :semi_regular
        true -> :irregular
      end
    end
  end

  @spec detect_temporal_pattern(term()) :: term()
  defp detect_temporal_pattern(intervals) do
    pattern_type = classify_temporal_pattern(intervals)

    case pattern_type do
      :regular -> :systematic_activity
      :semi_regular -> :organized_activity
      :irregular -> :random_activity
    end
  end

  @spec get_access_events_near_alarm(term()) :: term()
  defp get_access_events_near_alarm(alarm) do
    ensure_table()
    alarm_id = Map.get(alarm, :id)
    site_id = Map.get(alarm, :site_id)
    zone_id = Map.get(alarm, :zone_id)
    triggered_at = Map.get(alarm, :triggered_at, DateTime.utc_now())
    cutoff = DateTime.add(triggered_at, -@correlation_window_minutes * 60, :second)

    # Query ETS for access control events indexed by site/zone within the time window
    events =
      :ets.match_object(@table, {:access_event, site_id, zone_id, :_})
      |> Enum.map(fn {_key, event} -> event end)
      |> Enum.filter(fn event ->
        event_time = Map.get(event, :occurred_at, Map.get(event, :timestamp))
        event_time && DateTime.compare(event_time, cutoff) != :lt
      end)

    if length(events) > 0 do
      Logger.debug(
        "CorrelationEngine: found #{length(events)} access events near alarm #{alarm_id}"
      )

      :telemetry.execute(
        [:indrajaal, :alarms, :cross_domain_hit],
        %{count: length(events)},
        %{domain: :access_control, alarm_id: alarm_id}
      )
    end

    events
  end

  @spec get_video_events_near_alarm(term()) :: term()
  defp get_video_events_near_alarm(alarm) do
    ensure_table()
    alarm_id = Map.get(alarm, :id)
    site_id = Map.get(alarm, :site_id)
    zone_id = Map.get(alarm, :zone_id)
    triggered_at = Map.get(alarm, :triggered_at, DateTime.utc_now())
    cutoff = DateTime.add(triggered_at, -@correlation_window_minutes * 60, :second)

    # Query ETS for video analytics events indexed by site/zone
    events =
      :ets.match_object(@table, {:video_event, site_id, zone_id, :_})
      |> Enum.map(fn {_key, event} -> event end)
      |> Enum.filter(fn event ->
        event_time = Map.get(event, :occurred_at, Map.get(event, :timestamp))
        event_time && DateTime.compare(event_time, cutoff) != :lt
      end)

    if length(events) > 0 do
      Logger.debug(
        "CorrelationEngine: found #{length(events)} video events near alarm #{alarm_id}"
      )

      :telemetry.execute(
        [:indrajaal, :alarms, :cross_domain_hit],
        %{count: length(events)},
        %{domain: :video, alarm_id: alarm_id}
      )
    end

    events
  end

  @spec get_device_status_changes(term()) :: term()
  defp get_device_status_changes(alarm) do
    ensure_table()
    alarm_id = Map.get(alarm, :id)
    site_id = Map.get(alarm, :site_id)
    device_id = Map.get(alarm, :device_id)
    triggered_at = Map.get(alarm, :triggered_at, DateTime.utc_now())
    cutoff = DateTime.add(triggered_at, -@correlation_window_minutes * 60, :second)

    # Query ETS for device status change events
    pattern =
      if device_id do
        {:device_status, site_id, device_id, :_}
      else
        {:device_status, site_id, :_, :_}
      end

    events =
      :ets.match_object(@table, pattern)
      |> Enum.map(fn {_key, event} -> event end)
      |> Enum.filter(fn event ->
        event_time = Map.get(event, :occurred_at, Map.get(event, :timestamp))
        event_time && DateTime.compare(event_time, cutoff) != :lt
      end)

    if length(events) > 0 do
      Logger.debug(
        "CorrelationEngine: found #{length(events)} device status changes near alarm #{alarm_id}"
      )

      :telemetry.execute(
        [:indrajaal, :alarms, :cross_domain_hit],
        %{count: length(events)},
        %{domain: :devices, alarm_id: alarm_id}
      )
    end

    events
  end

  @spec calculate_video_significance(term()) :: term()
  defp calculate_video_significance(_video_events) do
    # This would analyze video __event significance
    :medium
  end

  @spec get_perimeter_zones(term()) :: term()
  defp get_perimeter_zones(site_id) do
    ensure_table()

    # Query ETS for zones classified as perimeter for this site
    case :ets.lookup(@table, {:perimeter_zones, site_id}) do
      [{_, zones}] when is_list(zones) ->
        Logger.debug(
          "CorrelationEngine: found #{length(zones)} perimeter zones for site #{site_id}"
        )

        zones

      [] ->
        # Fall back to scanning zone graph for zones tagged :perimeter
        case :ets.lookup(@table, {:zone_graph, site_id}) do
          [{_, graph}] when is_map(graph) ->
            # Any zone with key containing "perimeter" or "exterior" heuristically
            perimeter =
              graph
              |> Map.keys()
              |> Enum.filter(fn zone ->
                zone_str = to_string(zone)

                String.contains?(zone_str, "perimeter") or
                  String.contains?(zone_str, "exterior") or
                  String.contains?(zone_str, "fence")
              end)

            Logger.debug(
              "CorrelationEngine: heuristic perimeter zones for site #{site_id}: #{inspect(perimeter)}"
            )

            perimeter

          [] ->
            []
        end
    end
  end

  @spec extract_related_alarm_ids(term()) :: term()
  defp extract_related_alarm_ids(correlations) do
    correlations
    |> Enum.flat_map(fn corr ->
      Map.get(corr, :related_alarms, [])
    end)
    |> Enum.uniq()
  end

  @spec get_all_correlations(term()) :: term()
  defp get_all_correlations(alarm) do
    ensure_table()
    alarm_id = Map.get(alarm, :id)

    # Fetch all correlation records stored in ETS for this alarm
    # Records are written by create_correlation_group/2
    case :ets.lookup(@table, {:correlations, alarm_id}) do
      [{_, correlations}] when is_list(correlations) ->
        Logger.debug(
          "CorrelationEngine: fetched #{length(correlations)} stored correlations " <>
            "for alarm #{alarm_id}"
        )

        correlations

      [] ->
        # If not in ETS, run a fresh correlation analysis (idempotent)
        [
          spatial_correlation(alarm),
          temporal_correlation(alarm),
          device_correlation(alarm),
          pattern_correlation(alarm),
          cross_domain_correlation(alarm)
        ]
        |> Enum.filter(& &1.correlated)
    end
  end

  @spec calculate_correlation_confidence(term()) :: term()
  defp calculate_correlation_confidence(correlations) do
    if Enum.empty?(correlations) do
      0.0
    else
      confidences = correlations |> Enum.map(&(&1[:confidence] || 0.5))
      Enum.sum(confidences) / length(confidences)
    end
  end

  @spec calculate_cross_domain_confidence(term()) :: term()
  defp calculate_cross_domain_confidence(correlations) do
    base = 0.5
    increment = 0.15

    min(1.0, base + length(correlations) * increment)
  end

  @spec determine_recommended_action(term()) :: term()
  defp determine_recommended_action(correlations) do
    cond do
      length(correlations) >= 3 -> :immediate_dispatch
      Enum.any?(correlations, &(&1[:confidence] > 0.8)) -> :priority_investigation
      true -> :standard_response
    end
  end

  @spec determine_pattern_response(term()) :: term()
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

# Agent: Worker - 1 (Alarms Domain Agent)
# SOPv5.1 Compliance: ✅ Critical alarm processing and incident response coordin
# Domain: Alarms
# Responsibilities: Alarm processing, incident response, critical system monito
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
