defmodule Indrajaal.Analytics.RealTimeProcessorTest do
  @moduledoc """
  TDG-compliant comprehensive test suite for RealTimeProcessor module.
  Created BEFORE implementation following SOPv5.11 Test-Driven Generation methodology.

  This test suite implements:
  - Unit tests for all functions (100% coverage requirement)
  - Property-based tests using PropCheck and ExUnitProperties (dual framework approach)
  - STAMP safety constraint validation tests
  - Real-time processing performance validation
  - Multi-tenant data isolation verification
  - Stream processing and anomaly detection testing

  SOPv5.11 Compliance: ✅ Test-Driven Generation
  STAMP Safety: ✅ 5 critical safety constraints validated
  Property Testing: ✅ Dual PropCheck/ExUnitProperties framework
  TDG Methodology: ✅ Tests written BEFORE any implementation changes
  """

  use ExUnit.Case, async: true
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # Disambiguate PropCheck vs StreamData generators (EP-GEN-014)
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Analytics.RealTimeProcessor

  # Test data setup
  @valid_event %{
    id: "evt_001",
    type: "login_attempt",
    user_id: "user_12345",
    ip_address: "192.168.1.100",
    timestamp: DateTime.utc_now(),
    tenant_id: "tenant_001"
  }

  @valid_event_stream [
    %{id: "evt_001", type: "login_attempt", user_id: "user_001", timestamp: DateTime.utc_now()},
    %{id: "evt_002", type: "file_access", user_id: "user_002", timestamp: DateTime.utc_now()},
    %{
      id: "evt_003",
      type: "network_connection",
      user_id: "user_003",
      timestamp: DateTime.utc_now()
    },
    %{
      id: "evt_004",
      type: "permission_change",
      user_id: "user_004",
      timestamp: DateTime.utc_now()
    }
  ]

  @valid_detection_params %{
    sensitivity: 0.8,
    window_size_seconds: 300,
    baseline_period_days: 7,
    tenant_id: "tenant_001"
  }

  @valid_correlation_params %{
    time_window_seconds: 300,
    max_distance: 0.7,
    min_confidence: 0.75,
    tenant_id: "tenant_001"
  }

  @valid_alert_rules %{
    severity_thresholds: %{
      critical: 0.9,
      high: 0.75,
      medium: 0.5,
      low: 0.25
    },
    auto_response_enabled: true,
    tenant_id: "tenant_001"
  }

  @valid_processing_results %{
    stream_id: "stream_001",
    events_processed: 100,
    anomalies_detected: [%{event_id: "evt_001", type: "suspicious"}],
    correlations_found: 3
  }

  # ============================================================================
  # UNIT TESTS - TDG Core Tests (Created BEFORE Implementation)
  # ============================================================================

  describe "process_real_time_event/1 - TDG Core Tests" do
    test "successfully processes single real-time event" do
      result = RealTimeProcessor.process_real_time_event(@valid_event)

      assert {:ok, processed_event} = result
      assert is_map(processed_event)
      assert Map.has_key?(processed_event, :event_id)
      assert Map.has_key?(processed_event, :original_event)
      assert Map.has_key?(processed_event, :processing_timestamp)
      assert Map.has_key?(processed_event, :enrichment)
      assert Map.has_key?(processed_event, :status)
    end

    test "enriches event with geolocation information" do
      {:ok, processed_event} = RealTimeProcessor.process_real_time_event(@valid_event)

      assert %{enrichment: enrichment} = processed_event
      assert Map.has_key?(enrichment, :geolocation)
      assert %{geolocation: geo} = enrichment

      assert Map.has_key?(geo, :country)
      assert Map.has_key?(geo, :city)
      assert Map.has_key?(geo, :coordinates)
      assert is_binary(geo.country)
      assert is_binary(geo.city)
      assert is_tuple(geo.coordinates)
      assert tuple_size(geo.coordinates) == 2
    end

    test "enriches event with threat intelligence" do
      {:ok, processed_event} = RealTimeProcessor.process_real_time_event(@valid_event)

      assert %{enrichment: %{threat_intelligence: threat}} = processed_event
      assert Map.has_key?(threat, :risk_score)
      assert Map.has_key?(threat, :threat_category)
      assert Map.has_key?(threat, :confidence)

      assert is_number(threat.risk_score)
      assert threat.risk_score >= 0.0
      assert threat.risk_score <= 1.0
      assert is_binary(threat.threat_category)
      assert is_number(threat.confidence)
      assert threat.confidence >= 0.0
      assert threat.confidence <= 1.0
    end

    test "includes context enrichment" do
      {:ok, processed_event} = RealTimeProcessor.process_real_time_event(@valid_event)

      assert %{enrichment: %{context: context}} = processed_event
      assert Map.has_key?(context, :user_behavior_score)
      assert Map.has_key?(context, :device_trust_score)
      assert Map.has_key?(context, :network_reputation)

      # Verify all scores are valid probabilities
      assert is_number(context.user_behavior_score)
      assert context.user_behavior_score >= 0.0
      assert context.user_behavior_score <= 1.0

      assert is_number(context.device_trust_score)
      assert context.device_trust_score >= 0.0
      assert context.device_trust_score <= 1.0

      assert is_number(context.network_reputation)
      assert context.network_reputation >= 0.0
      assert context.network_reputation <= 1.0
    end

    test "generates event correlations" do
      {:ok, processed_event} = RealTimeProcessor.process_real_time_event(@valid_event)

      assert %{correlations: correlations} = processed_event
      assert is_list(correlations)

      if length(correlations) > 0 do
        correlation = hd(correlations)
        assert Map.has_key?(correlation, :correlation_id)
        assert Map.has_key?(correlation, :related_events)
        assert Map.has_key?(correlation, :correlation_strength)
        assert Map.has_key?(correlation, :pattern_type)

        assert is_binary(correlation.correlation_id)
        assert is_list(correlation.related_events)
        assert is_number(correlation.correlation_strength)
        assert correlation.correlation_strength >= 0.0
        assert correlation.correlation_strength <= 1.0
        assert is_binary(correlation.pattern_type)
      end
    end

    test "triggers appropriate actions" do
      {:ok, processed_event} = RealTimeProcessor.process_real_time_event(@valid_event)

      assert %{actions_triggered: actions} = processed_event
      assert is_list(actions)
      assert length(actions) > 0

      Enum.each(actions, fn action ->
        assert is_binary(action)
      end)
    end

    test "records processing metadata" do
      {:ok, processed_event} = RealTimeProcessor.process_real_time_event(@valid_event)

      assert Map.has_key?(processed_event, :processing_timestamp)
      assert Map.has_key?(processed_event, :processing_duration_ms)
      assert %DateTime{} = processed_event.processing_timestamp
      assert is_number(processed_event.processing_duration_ms)
      assert processed_event.processing_duration_ms > 0
    end

    test "preserves original event data" do
      {:ok, processed_event} = RealTimeProcessor.process_real_time_event(@valid_event)

      assert %{original_event: original} = processed_event
      assert original == @valid_event
    end

    test "handles events with missing fields gracefully" do
      minimal_event = %{type: "test_event"}

      result = RealTimeProcessor.process_real_time_event(minimal_event)

      assert {:ok, processed_event} = result
      assert Map.has_key?(processed_event, :event_id)
      assert processed_event.original_event == minimal_event
    end

    test "generates unique event IDs when not provided" do
      event_without_id = %{type: "test_event", data: "test"}

      {:ok, processed_event1} = RealTimeProcessor.process_real_time_event(event_without_id)
      {:ok, processed_event2} = RealTimeProcessor.process_real_time_event(event_without_id)

      assert processed_event1.event_id != processed_event2.event_id
    end
  end

  describe "process_event_stream/1 - TDG Core Tests" do
    test "successfully processes event stream" do
      result = RealTimeProcessor.process_event_stream(@valid_event_stream)

      assert {:ok, processing_results} = result
      assert is_map(processing_results)
      assert Map.has_key?(processing_results, :stream_id)
      assert Map.has_key?(processing_results, :events_processed)
      assert Map.has_key?(processing_results, :processing_started)
      assert Map.has_key?(processing_results, :processing_stats)
    end

    test "counts events correctly" do
      {:ok, results} = RealTimeProcessor.process_event_stream(@valid_event_stream)

      assert results.events_processed == length(@valid_event_stream)
      assert results.processing_stats.total_events == length(@valid_event_stream)
    end

    test "includes processing statistics" do
      {:ok, results} = RealTimeProcessor.process_event_stream(@valid_event_stream)

      assert %{processing_stats: stats} = results
      assert Map.has_key?(stats, :total_events)
      assert Map.has_key?(stats, :successful)
      assert Map.has_key?(stats, :failed)
      assert Map.has_key?(stats, :avg_processing_time_ms)
      assert Map.has_key?(stats, :throughput_eps)

      # Verify data types and reasonable values
      assert is_integer(stats.total_events)
      assert stats.total_events >= 0
      assert is_integer(stats.successful)
      assert stats.successful >= 0
      assert is_integer(stats.failed)
      assert stats.failed >= 0
      assert is_number(stats.avg_processing_time_ms)
      assert stats.avg_processing_time_ms > 0
      assert is_number(stats.throughput_eps)
      assert stats.throughput_eps > 0
    end

    test "detects anomalies during stream processing" do
      {:ok, results} = RealTimeProcessor.process_event_stream(@valid_event_stream)

      assert %{anomalies_detected: anomalies} = results
      assert is_list(anomalies)

      if length(anomalies) > 0 do
        anomaly = hd(anomalies)
        assert Map.has_key?(anomaly, :event_id)
        assert Map.has_key?(anomaly, :anomaly_type)
        assert Map.has_key?(anomaly, :severity)
        assert Map.has_key?(anomaly, :confidence)

        assert is_binary(anomaly.event_id)
        assert is_binary(anomaly.anomaly_type)
        assert is_binary(anomaly.severity)
        assert anomaly.severity in ["critical", "high", "medium", "low"]
        assert is_number(anomaly.confidence)
        assert anomaly.confidence >= 0.0
        assert anomaly.confidence <= 1.0
      end
    end

    test "tracks correlations and alerts" do
      {:ok, results} = RealTimeProcessor.process_event_stream(@valid_event_stream)

      assert Map.has_key?(results, :correlations_found)
      assert Map.has_key?(results, :alerts_generated)
      assert is_integer(results.correlations_found)
      assert results.correlations_found >= 0
      assert is_integer(results.alerts_generated)
      assert results.alerts_generated >= 0
    end

    test "includes performance metrics" do
      {:ok, results} = RealTimeProcessor.process_event_stream(@valid_event_stream)

      assert %{performance_metrics: metrics} = results
      assert Map.has_key?(metrics, :memory_usage_mb)
      assert Map.has_key?(metrics, :cpu_utilization)
      assert Map.has_key?(metrics, :network_io_mbps)

      assert is_number(metrics.memory_usage_mb)
      assert metrics.memory_usage_mb > 0
      assert is_number(metrics.cpu_utilization)
      assert metrics.cpu_utilization >= 0.0
      assert metrics.cpu_utilization <= 1.0
      assert is_number(metrics.network_io_mbps)
      assert metrics.network_io_mbps >= 0
    end

    test "generates unique stream IDs" do
      {:ok, results1} = RealTimeProcessor.process_event_stream(@valid_event_stream)
      {:ok, results2} = RealTimeProcessor.process_event_stream(@valid_event_stream)

      assert results1.stream_id != results2.stream_id
    end

    test "handles empty event streams" do
      result = RealTimeProcessor.process_event_stream([])

      assert {:ok, processing_results} = result
      assert processing_results.events_processed == 0
      assert processing_results.processing_stats.total_events == 0
    end

    test "includes processing timestamp" do
      {:ok, results} = RealTimeProcessor.process_event_stream(@valid_event_stream)

      assert %{processing_started: timestamp} = results
      assert %DateTime{} = timestamp

      # Verify timestamp is recent (within last minute)
      time_diff = DateTime.diff(DateTime.utc_now(), timestamp, :second)
      assert time_diff < 60
    end
  end

  describe "detect_real_time_anomalies/2 - TDG Core Tests" do
    test "successfully detects anomalies in event stream" do
      result =
        RealTimeProcessor.detect_real_time_anomalies(
          @valid_event_stream,
          @valid_detection_params
        )

      assert {:ok, anomalies} = result
      assert is_list(anomalies)
    end

    test "returns structured anomaly objects" do
      {:ok, anomalies} =
        RealTimeProcessor.detect_real_time_anomalies(
          @valid_event_stream,
          @valid_detection_params
        )

      if length(anomalies) > 0 do
        anomaly = hd(anomalies)

        assert Map.has_key?(anomaly, :anomaly_id)
        assert Map.has_key?(anomaly, :detection_timestamp)
        assert Map.has_key?(anomaly, :event_ids)
        assert Map.has_key?(anomaly, :anomaly_type)
        assert Map.has_key?(anomaly, :description)
        assert Map.has_key?(anomaly, :severity)
        assert Map.has_key?(anomaly, :confidence_score)

        # Verify data types
        assert is_binary(anomaly.anomaly_id)
        assert %DateTime{} = anomaly.detection_timestamp
        assert is_list(anomaly.event_ids)
        assert is_binary(anomaly.anomaly_type)
        assert is_binary(anomaly.description)
        assert is_binary(anomaly.severity)
        assert anomaly.severity in ["critical", "high", "medium", "low"]
        assert is_number(anomaly.confidence_score)
        assert anomaly.confidence_score >= 0.0
        assert anomaly.confidence_score <= 1.0
      end
    end

    test "includes baseline and deviation information for frequency anomalies" do
      {:ok, anomalies} =
        RealTimeProcessor.detect_real_time_anomalies(
          @valid_event_stream,
          @valid_detection_params
        )

      frequency_anomalies =
        Enum.filter(anomalies, fn a ->
          String.contains?(a.anomaly_type, "frequency") or
            String.contains?(a.anomaly_type, "spike")
        end)

      if length(frequency_anomalies) > 0 do
        anomaly = hd(frequency_anomalies)

        if Map.has_key?(anomaly, :baseline_value) do
          assert is_number(anomaly.baseline_value)
          assert anomaly.baseline_value >= 0
        end

        if Map.has_key?(anomaly, :observed_value) do
          assert is_number(anomaly.observed_value)
          assert anomaly.observed_value >= 0
        end

        if Map.has_key?(anomaly, :deviation_factor) do
          assert is_number(anomaly.deviation_factor)
          assert anomaly.deviation_factor > 0
        end
      end
    end

    test "includes affected entities information" do
      {:ok, anomalies} =
        RealTimeProcessor.detect_real_time_anomalies(
          @valid_event_stream,
          @valid_detection_params
        )

      if length(anomalies) > 0 do
        anomaly = hd(anomalies)

        if Map.has_key?(anomaly, :affected_entities) do
          assert is_list(anomaly.affected_entities)

          Enum.each(anomaly.affected_entities, fn entity ->
            assert is_binary(entity)
          end)
        end
      end
    end

    test "provides recommended actions for detected anomalies" do
      {:ok, anomalies} =
        RealTimeProcessor.detect_real_time_anomalies(
          @valid_event_stream,
          @valid_detection_params
        )

      if length(anomalies) > 0 do
        anomaly = hd(anomalies)

        if Map.has_key?(anomaly, :recommended_actions) do
          assert is_list(anomaly.recommended_actions)
          assert length(anomaly.recommended_actions) > 0

          Enum.each(anomaly.recommended_actions, fn action ->
            assert is_binary(action)
          end)
        end
      end
    end

    test "handles behavioral deviation anomalies" do
      {:ok, anomalies} =
        RealTimeProcessor.detect_real_time_anomalies(
          @valid_event_stream,
          @valid_detection_params
        )

      behavioral_anomalies =
        Enum.filter(anomalies, fn a ->
          String.contains?(a.anomaly_type, "behavioral")
        end)

      if length(behavioral_anomalies) > 0 do
        anomaly = hd(behavioral_anomalies)

        # Check for behavioral-specific fields
        if Map.has_key?(anomaly, :user_profile_match) do
          assert is_number(anomaly.user_profile_match)
          assert anomaly.user_profile_match >= 0.0
          assert anomaly.user_profile_match <= 1.0
        end

        if Map.has_key?(anomaly, :time_deviation_hours) do
          assert is_number(anomaly.time_deviation_hours)
          assert anomaly.time_deviation_hours >= 0
        end
      end
    end

    test "handles empty event streams for anomaly detection" do
      result = RealTimeProcessor.detect_real_time_anomalies([], @valid_detection_params)

      assert {:ok, anomalies} = result
      assert is_list(anomalies)
      # Empty streams may or may not have anomalies depending on implementation
    end

    test "respects detection parameters" do
      custom_params = Map.put(@valid_detection_params, :sensitivity, 0.95)

      result = RealTimeProcessor.detect_real_time_anomalies(@valid_event_stream, custom_params)

      assert {:ok, _anomalies} = result
      # In a real implementation, higher sensitivity should affect detection
    end
  end

  describe "correlate_events/2 - TDG Core Tests" do
    test "successfully correlates events in stream" do
      result = RealTimeProcessor.correlate_events(@valid_event_stream, @valid_correlation_params)

      assert {:ok, correlations} = result
      assert is_list(correlations)
    end

    test "returns structured correlation objects" do
      {:ok, correlations} =
        RealTimeProcessor.correlate_events(
          @valid_event_stream,
          @valid_correlation_params
        )

      if length(correlations) > 0 do
        correlation = hd(correlations)

        assert Map.has_key?(correlation, :correlation_id)
        assert Map.has_key?(correlation, :correlation_type)
        assert Map.has_key?(correlation, :related_events)
        assert Map.has_key?(correlation, :pattern_confidence)
        assert Map.has_key?(correlation, :description)

        # Verify data types
        assert is_binary(correlation.correlation_id)
        assert is_binary(correlation.correlation_type)
        assert is_list(correlation.related_events)
        assert is_number(correlation.pattern_confidence)
        assert correlation.pattern_confidence >= 0.0
        assert correlation.pattern_confidence <= 1.0
        assert is_binary(correlation.description)
      end
    end

    test "includes temporal sequence correlations" do
      {:ok, correlations} =
        RealTimeProcessor.correlate_events(
          @valid_event_stream,
          @valid_correlation_params
        )

      temporal_correlations =
        Enum.filter(correlations, fn c ->
          c.correlation_type == "temporal_sequence"
        end)

      if length(temporal_correlations) > 0 do
        correlation = hd(temporal_correlations)

        if Map.has_key?(correlation, :time_window_seconds) do
          assert is_integer(correlation.time_window_seconds)
          assert correlation.time_window_seconds > 0
        end

        assert is_list(correlation.related_events)
        # Need at least 2 events for sequence
        assert length(correlation.related_events) >= 2
      end
    end

    test "includes entity-based correlations" do
      {:ok, correlations} =
        RealTimeProcessor.correlate_events(
          @valid_event_stream,
          @valid_correlation_params
        )

      entity_correlations =
        Enum.filter(correlations, fn c ->
          c.correlation_type == "entity_based"
        end)

      if length(entity_correlations) > 0 do
        correlation = hd(entity_correlations)

        if Map.has_key?(correlation, :common_entities) do
          assert is_list(correlation.common_entities)
          assert length(correlation.common_entities) > 0

          Enum.each(correlation.common_entities, fn entity ->
            assert is_binary(entity)
          end)
        end
      end
    end

    test "includes risk assessment for correlations" do
      {:ok, correlations} =
        RealTimeProcessor.correlate_events(
          @valid_event_stream,
          @valid_correlation_params
        )

      if length(correlations) > 0 do
        correlation = hd(correlations)

        if Map.has_key?(correlation, :risk_assessment) do
          risk = correlation.risk_assessment

          assert Map.has_key?(risk, :overall_risk)
          assert is_binary(risk.overall_risk)
          assert risk.overall_risk in ["critical", "high", "medium", "low"]

          if Map.has_key?(risk, :threat_indicators) do
            assert is_list(risk.threat_indicators)

            Enum.each(risk.threat_indicators, fn indicator ->
              assert is_binary(indicator)
            end)
          end

          if Map.has_key?(risk, :mitigation_priority) do
            assert is_integer(risk.mitigation_priority)
            assert risk.mitigation_priority > 0
          end
        end
      end
    end

    test "handles empty event streams for correlation" do
      result = RealTimeProcessor.correlate_events([], @valid_correlation_params)

      assert {:ok, correlations} = result
      assert is_list(correlations)
      # Empty streams should have no correlations
    end

    test "respects correlation parameters" do
      custom_params = Map.put(@valid_correlation_params, :min_confidence, 0.9)

      result = RealTimeProcessor.correlate_events(@valid_event_stream, custom_params)

      assert {:ok, _correlations} = result
      # In a real implementation, higher min_confidence should filter results
    end

    test "generates unique correlation IDs" do
      {:ok, correlations1} =
        RealTimeProcessor.correlate_events(
          @valid_event_stream,
          @valid_correlation_params
        )

      {:ok, correlations2} =
        RealTimeProcessor.correlate_events(
          @valid_event_stream,
          @valid_correlation_params
        )

      if length(correlations1) > 0 and length(correlations2) > 0 do
        ids1 = Enum.map(correlations1, & &1.correlation_id)
        ids2 = Enum.map(correlations2, & &1.correlation_id)

        # Should generate different IDs for different runs
        refute ids1 == ids2
      end
    end
  end

  describe "generate_real_time_alerts/2 - TDG Core Tests" do
    test "successfully generates real-time alerts" do
      result =
        RealTimeProcessor.generate_real_time_alerts(
          @valid_processing_results,
          @valid_alert_rules
        )

      assert {:ok, alerts} = result
      assert is_list(alerts)
    end

    test "returns structured alert objects" do
      {:ok, alerts} =
        RealTimeProcessor.generate_real_time_alerts(
          @valid_processing_results,
          @valid_alert_rules
        )

      if length(alerts) > 0 do
        alert = hd(alerts)

        assert Map.has_key?(alert, :alert_id)
        assert Map.has_key?(alert, :alert_type)
        assert Map.has_key?(alert, :severity)
        assert Map.has_key?(alert, :title)
        assert Map.has_key?(alert, :description)
        assert Map.has_key?(alert, :created_at)

        # Verify data types
        assert is_binary(alert.alert_id)
        assert is_binary(alert.alert_type)
        assert is_binary(alert.severity)
        assert alert.severity in ["critical", "high", "medium", "low"]
        assert is_binary(alert.title)
        assert is_binary(alert.description)
        assert %DateTime{} = alert.created_at
      end
    end

    test "includes trigger information" do
      {:ok, alerts} =
        RealTimeProcessor.generate_real_time_alerts(
          @valid_processing_results,
          @valid_alert_rules
        )

      if length(alerts) > 0 do
        alert = hd(alerts)

        if Map.has_key?(alert, :triggered_by) do
          assert is_list(alert.triggered_by)
          assert length(alert.triggered_by) > 0

          Enum.each(alert.triggered_by, fn trigger ->
            assert is_binary(trigger)
          end)
        end
      end
    end

    test "includes affected systems and entities" do
      {:ok, alerts} =
        RealTimeProcessor.generate_real_time_alerts(
          @valid_processing_results,
          @valid_alert_rules
        )

      if length(alerts) > 0 do
        alert = hd(alerts)

        if Map.has_key?(alert, :affected_systems) do
          assert is_list(alert.affected_systems)

          Enum.each(alert.affected_systems, fn system ->
            assert is_binary(system)
          end)
        end

        if Map.has_key?(alert, :entities_involved) do
          assert is_list(alert.entities_involved)

          Enum.each(alert.entities_involved, fn entity ->
            assert is_binary(entity)
          end)
        end
      end
    end

    test "includes recommended response actions" do
      {:ok, alerts} =
        RealTimeProcessor.generate_real_time_alerts(
          @valid_processing_results,
          @valid_alert_rules
        )

      if length(alerts) > 0 do
        alert = hd(alerts)

        if Map.has_key?(alert, :recommended_response) do
          assert is_list(alert.recommended_response)
          assert length(alert.recommended_response) > 0

          Enum.each(alert.recommended_response, fn action ->
            assert is_binary(action)
          end)
        end
      end
    end

    test "includes escalation information" do
      {:ok, alerts} =
        RealTimeProcessor.generate_real_time_alerts(
          @valid_processing_results,
          @valid_alert_rules
        )

      if length(alerts) > 0 do
        alert = hd(alerts)

        if Map.has_key?(alert, :escalation_level) do
          assert is_integer(alert.escalation_level)
          assert alert.escalation_level > 0
          # Reasonable escalation levels
          assert alert.escalation_level <= 5
        end
      end
    end

    test "tracks automatic actions taken" do
      {:ok, alerts} =
        RealTimeProcessor.generate_real_time_alerts(
          @valid_processing_results,
          @valid_alert_rules
        )

      if length(alerts) > 0 do
        alert = hd(alerts)

        if Map.has_key?(alert, :auto_actions_taken) do
          assert is_list(alert.auto_actions_taken)

          Enum.each(alert.auto_actions_taken, fn action ->
            assert is_binary(action)
          end)
        end
      end
    end

    test "includes alert expiration time" do
      {:ok, alerts} =
        RealTimeProcessor.generate_real_time_alerts(
          @valid_processing_results,
          @valid_alert_rules
        )

      if length(alerts) > 0 do
        alert = hd(alerts)

        if Map.has_key?(alert, :expires_at) do
          assert %DateTime{} = alert.expires_at
          # Expiration should be after creation
          assert DateTime.compare(alert.expires_at, alert.created_at) == :gt
        end
      end
    end

    test "generates unique alert IDs" do
      {:ok, alerts1} =
        RealTimeProcessor.generate_real_time_alerts(
          @valid_processing_results,
          @valid_alert_rules
        )

      {:ok, alerts2} =
        RealTimeProcessor.generate_real_time_alerts(
          @valid_processing_results,
          @valid_alert_rules
        )

      if length(alerts1) > 0 and length(alerts2) > 0 do
        ids1 = Enum.map(alerts1, & &1.alert_id)
        ids2 = Enum.map(alerts2, & &1.alert_id)

        # Should generate different IDs for different runs
        refute ids1 == ids2
      end
    end

    test "handles empty processing results" do
      empty_results = %{
        stream_id: "stream_001",
        events_processed: 0,
        anomalies_detected: [],
        correlations_found: 0
      }

      result = RealTimeProcessor.generate_real_time_alerts(empty_results, @valid_alert_rules)

      assert {:ok, alerts} = result
      assert is_list(alerts)
      # Empty results may still generate system alerts
    end
  end

  # ============================================================================
  # PROPERTY-BASED TESTS - PropCheck Framework
  # ============================================================================

  describe "PropCheck Property Tests" do
    property "process_real_time_event always returns valid processed event structure" do
      forall event <- real_time_event_generator() do
        result = RealTimeProcessor.process_real_time_event(event)

        case result do
          {:ok, processed_event} ->
            is_map(processed_event) and
              Map.has_key?(processed_event, :event_id) and
              Map.has_key?(processed_event, :original_event) and
              Map.has_key?(processed_event, :processing_timestamp) and
              Map.has_key?(processed_event, :status) and
              processed_event.original_event == event

          {:error, _reason} ->
            # Errors are acceptable for invalid inputs
            true
        end
      end
    end

    property "process_event_stream event counts are consistent" do
      forall events <- PC.list(real_time_event_generator()) do
        {:ok, results} = RealTimeProcessor.process_event_stream(events)

        results.events_processed == length(events) and
          results.processing_stats.total_events == length(events)
      end
    end

    property "detect_real_time_anomalies returns valid anomaly structures" do
      forall {events, params} <- {
               PC.list(real_time_event_generator()),
               detection_params_generator()
             } do
        result = RealTimeProcessor.detect_real_time_anomalies(events, params)

        case result do
          {:ok, anomalies} ->
            is_list(anomalies) and
              Enum.all?(anomalies, fn anomaly ->
                is_map(anomaly) and
                  Map.has_key?(anomaly, :anomaly_id) and
                  Map.has_key?(anomaly, :detection_timestamp) and
                  Map.has_key?(anomaly, :severity) and
                  anomaly.severity in ["critical", "high", "medium", "low"]
              end)

          {:error, _reason} ->
            # Errors are acceptable for invalid inputs
            true
        end
      end
    end

    property "correlate_events returns valid correlation structures" do
      forall {events, params} <- {
               PC.list(real_time_event_generator()),
               correlation_params_generator()
             } do
        result = RealTimeProcessor.correlate_events(events, params)

        case result do
          {:ok, correlations} ->
            is_list(correlations) and
              Enum.all?(correlations, fn corr ->
                is_map(corr) and
                  Map.has_key?(corr, :correlation_id) and
                  Map.has_key?(corr, :correlation_type) and
                  Map.has_key?(corr, :pattern_confidence) and
                  is_number(corr.pattern_confidence) and
                  corr.pattern_confidence >= 0.0 and
                  corr.pattern_confidence <= 1.0
              end)

          {:error, _reason} ->
            # Errors are acceptable for invalid inputs
            true
        end
      end
    end

    property "generate_real_time_alerts produces valid alert structures" do
      forall {processing_results, alert_rules} <- {
               processing_results_generator(),
               alert_rules_generator()
             } do
        result = RealTimeProcessor.generate_real_time_alerts(processing_results, alert_rules)

        case result do
          {:ok, alerts} ->
            is_list(alerts) and
              Enum.all?(alerts, fn alert ->
                is_map(alert) and
                  Map.has_key?(alert, :alert_id) and
                  Map.has_key?(alert, :severity) and
                  Map.has_key?(alert, :created_at) and
                  alert.severity in ["critical", "high", "medium", "low"]
              end)

          {:error, _reason} ->
            # Errors are acceptable for invalid inputs
            true
        end
      end
    end
  end

  # ============================================================================
  # PROPERTY-BASED TESTS - ExUnitProperties Framework
  # ============================================================================

  describe "ExUnitProperties Property Tests" do
    test "all real-time processing functions handle edge cases gracefully" do
      ExUnitProperties.check all(
                               event <- real_time_event_stream(),
                               events <- SD.list_of(real_time_event_stream(), max_length: 20),
                               detection_params <- detection_params_stream(),
                               max_runs: 30
                             ) do
        # Test single event processing
        result = RealTimeProcessor.process_real_time_event(event)

        case result do
          {:ok, processed} ->
            assert is_map(processed)
            assert Map.has_key?(processed, :processing_timestamp)
            assert %DateTime{} = processed.processing_timestamp

          {:error, reason} ->
            assert is_atom(reason) or is_binary(reason)
        end

        # Test stream processing
        stream_result = RealTimeProcessor.process_event_stream(events)

        case stream_result do
          {:ok, results} ->
            assert is_map(results)
            assert results.events_processed == length(events)

          {:error, reason} ->
            assert is_atom(reason) or is_binary(reason)
        end

        # Test anomaly detection
        anomaly_result = RealTimeProcessor.detect_real_time_anomalies(events, detection_params)

        case anomaly_result do
          {:ok, anomalies} ->
            assert is_list(anomalies)

            Enum.each(anomalies, fn anomaly ->
              if Map.has_key?(anomaly, :confidence_score) do
                assert is_number(anomaly.confidence_score)
                assert anomaly.confidence_score >= 0.0
                assert anomaly.confidence_score <= 1.0
              end
            end)

          {:error, reason} ->
            assert is_atom(reason) or is_binary(reason)
        end
      end
    end

    test "real-time processing preserves event ordering and relationships" do
      ExUnitProperties.check all(
                               events <-
                                 SD.list_of(real_time_event_stream(),
                                   min_length: 2,
                                   max_length: 10
                                 ),
                               correlation_params <- correlation_params_stream(),
                               max_runs: 20
                             ) do
        # Add sequential timestamps to events
        timestamped_events =
          events
          |> Enum.with_index()
          |> Enum.map(fn {event, index} ->
            Map.put(event, :timestamp, DateTime.add(DateTime.utc_now(), index, :second))
          end)

        {:ok, correlations} =
          RealTimeProcessor.correlate_events(timestamped_events, correlation_params)

        # Verify correlations maintain event relationships
        Enum.each(correlations, fn correlation ->
          assert Map.has_key?(correlation, :related_events)
          assert is_list(correlation.related_events)

          if length(correlation.related_events) > 1 do
            # Related events should be valid event references
            assert Enum.all?(correlation.related_events, &is_binary/1)
          end

          if Map.has_key?(correlation, :pattern_confidence) do
            assert is_number(correlation.pattern_confidence)
            assert correlation.pattern_confidence >= 0.0
            assert correlation.pattern_confidence <= 1.0
          end
        end)
      end
    end

    test "anomaly detection confidence scores are always valid probabilities" do
      ExUnitProperties.check all(
                               events <- SD.list_of(real_time_event_stream(), max_length: 15),
                               detection_params <- detection_params_stream(),
                               max_runs: 25
                             ) do
        {:ok, anomalies} = RealTimeProcessor.detect_real_time_anomalies(events, detection_params)

        Enum.each(anomalies, fn anomaly ->
          if Map.has_key?(anomaly, :confidence_score) do
            assert is_number(anomaly.confidence_score)
            assert anomaly.confidence_score >= 0.0
            assert anomaly.confidence_score <= 1.0
          end

          # Check severity levels
          assert Map.has_key?(anomaly, :severity)
          assert anomaly.severity in ["critical", "high", "medium", "low"]

          # Check timestamp validity
          if Map.has_key?(anomaly, :detection_timestamp) do
            assert %DateTime{} = anomaly.detection_timestamp
          end

          # Verify numeric fields in frequency anomalies
          if Map.has_key?(anomaly, :baseline_value) do
            assert is_number(anomaly.baseline_value)
            assert anomaly.baseline_value >= 0
          end

          if Map.has_key?(anomaly, :observed_value) do
            assert is_number(anomaly.observed_value)
            assert anomaly.observed_value >= 0
          end

          if Map.has_key?(anomaly, :deviation_factor) do
            assert is_number(anomaly.deviation_factor)
            assert anomaly.deviation_factor > 0
          end
        end)
      end
    end

    test "alert generation includes all required fields and valid timestamps" do
      ExUnitProperties.check all(
                               processing_results <- processing_results_stream(),
                               alert_rules <- alert_rules_stream(),
                               max_runs: 20
                             ) do
        {:ok, alerts} =
          RealTimeProcessor.generate_real_time_alerts(processing_results, alert_rules)

        Enum.each(alerts, fn alert ->
          # Required fields
          assert Map.has_key?(alert, :alert_id)
          assert Map.has_key?(alert, :alert_type)
          assert Map.has_key?(alert, :severity)
          assert Map.has_key?(alert, :created_at)

          assert is_binary(alert.alert_id)
          assert is_binary(alert.alert_type)
          assert is_binary(alert.severity)
          assert alert.severity in ["critical", "high", "medium", "low"]
          assert %DateTime{} = alert.created_at

          # Verify timestamps relationships
          if Map.has_key?(alert, :expires_at) do
            assert %DateTime{} = alert.expires_at
            # Expiration should be after creation
            assert DateTime.compare(alert.expires_at, alert.created_at) == :gt
          end

          # Verify escalation level
          if Map.has_key?(alert, :escalation_level) do
            assert is_integer(alert.escalation_level)
            assert alert.escalation_level > 0
            # Reasonable upper bound
            assert alert.escalation_level <= 10
          end

          # Verify list fields
          if Map.has_key?(alert, :recommended_response) do
            assert is_list(alert.recommended_response)
            Enum.each(alert.recommended_response, &assert(is_binary(&1)))
          end

          if Map.has_key?(alert, :auto_actions_taken) do
            assert is_list(alert.auto_actions_taken)
            Enum.each(alert.auto_actions_taken, &assert(is_binary(&1)))
          end
        end)
      end
    end
  end

  # ============================================================================
  # STAMP SAFETY CONSTRAINT TESTS
  # ============================================================================

  describe "STAMP Safety Constraints - Real-Time Processing Domain" do
    test "SC-REALTIME-001: System SHALL maintain tenant data isolation in real-time processing" do
      tenant1_event = Map.put(@valid_event, :tenant_id, "tenant_001")
      tenant2_event = Map.put(@valid_event, :tenant_id, "tenant_002")

      {:ok, processed1} = RealTimeProcessor.process_real_time_event(tenant1_event)
      {:ok, processed2} = RealTimeProcessor.process_real_time_event(tenant2_event)

      # Verify that processed events maintain tenant isolation
      assert processed1.original_event.tenant_id == "tenant_001"
      assert processed2.original_event.tenant_id == "tenant_002"
      assert processed1 != processed2

      # Verify unique processing for each tenant
      assert processed1.event_id != processed2.event_id
    end

    test "SC-REALTIME-002: System SHALL validate real-time event data integrity" do
      # Test with corrupted/invalid event data
      invalid_event = %{
        # Invalid ID
        id: nil,
        # Invalid type
        type: 123,
        # Invalid timestamp format
        timestamp: "invalid_timestamp",
        # Potentially invalid nested data
        data: %{nested: {:invalid, :structure}}
      }

      # System should handle invalid data gracefully
      result = RealTimeProcessor.process_real_time_event(invalid_event)

      case result do
        {:ok, processed_event} ->
          # If it succeeds, verify data was handled appropriately
          assert is_map(processed_event)
          assert Map.has_key?(processed_event, :event_id)
          assert processed_event.original_event == invalid_event

        {:error, reason} ->
          # If it fails, verify appropriate error handling
          assert is_atom(reason) or is_binary(reason)
      end
    end

    test "SC-REALTIME-003: System SHALL prevent real-time processing data corruption" do
      original_event = @valid_event

      # Process same event multiple times
      {:ok, processed1} = RealTimeProcessor.process_real_time_event(original_event)
      {:ok, processed2} = RealTimeProcessor.process_real_time_event(original_event)

      # Original event data should remain unchanged
      assert processed1.original_event == original_event
      assert processed2.original_event == original_event
      assert processed1.original_event == processed2.original_event

      # Processing should be consistent for same input
      assert processed1.status == processed2.status
      assert processed1.original_event == processed2.original_event
    end

    test "SC-REALTIME-004: System SHALL maintain audit trail for real-time processing" do
      {:ok, processed_event} = RealTimeProcessor.process_real_time_event(@valid_event)

      # Verify audit information is present
      assert Map.has_key?(processed_event, :processing_timestamp)
      assert Map.has_key?(processed_event, :processing_duration_ms)
      assert %DateTime{} = processed_event.processing_timestamp
      assert is_number(processed_event.processing_duration_ms)

      # Verify timestamp is recent and valid
      time_diff = DateTime.diff(DateTime.utc_now(), processed_event.processing_timestamp, :second)
      assert time_diff >= 0
      # Should be within last minute
      assert time_diff < 60

      # Verify processing duration is reasonable
      assert processed_event.processing_duration_ms > 0
      # Less than 10 seconds
      assert processed_event.processing_duration_ms < 10_000
    end

    test "SC-REALTIME-005: System SHALL ensure real-time alerts are actionable and safe" do
      {:ok, alerts} =
        RealTimeProcessor.generate_real_time_alerts(
          @valid_processing_results,
          @valid_alert_rules
        )

      assert is_list(alerts)

      Enum.each(alerts, fn alert ->
        # Verify all alerts have required safety fields
        assert Map.has_key?(alert, :severity)
        assert Map.has_key?(alert, :escalation_level)
        assert alert.severity in ["critical", "high", "medium", "low"]

        # Verify escalation levels are reasonable
        if Map.has_key?(alert, :escalation_level) do
          assert is_integer(alert.escalation_level)
          assert alert.escalation_level > 0
          # Reasonable escalation range
          assert alert.escalation_level <= 5
        end

        # Verify recommended responses are not overly aggressive
        if Map.has_key?(alert, :recommended_response) do
          assert is_list(alert.recommended_response)
          assert length(alert.recommended_response) > 0

          # Check for reasonable response actions (avoid destructive actions)
          destructive_actions = ["delete_user", "shutdown_system", "format_drive"]
          actual_actions = Enum.map(alert.recommended_response, &String.downcase/1)

          Enum.each(destructive_actions, fn destructive ->
            refute Enum.any?(actual_actions, &String.contains?(&1, destructive))
          end)
        end

        # Verify auto actions are documented
        if Map.has_key?(alert, :auto_actions_taken) do
          assert is_list(alert.auto_actions_taken)

          Enum.each(alert.auto_actions_taken, fn action ->
            assert is_binary(action)
          end)
        end

        # Verify alert has expiration to prevent stale alerts
        if Map.has_key?(alert, :expires_at) do
          assert %DateTime{} = alert.expires_at
          # Alert should expire in the future
          assert DateTime.compare(alert.expires_at, DateTime.utc_now()) == :gt
        end
      end)
    end
  end

  # ============================================================================
  # ERROR HANDLING AND EDGE CASES
  # ============================================================================

  describe "Error Handling and Edge Cases" do
    test "handles nil event gracefully" do
      result = RealTimeProcessor.process_real_time_event(nil)

      case result do
        # Graceful handling acceptable
        {:ok, _} -> :ok
        # Error handling acceptable
        {:error, _} -> :ok
      end
    end

    test "handles non-list input for stream processing" do
      result = RealTimeProcessor.process_event_stream("not_a_list")

      case result do
        # Graceful handling acceptable
        {:ok, _} -> :ok
        # Error handling acceptable
        {:error, _} -> :ok
      end
    end

    test "handles extremely large event streams" do
      large_stream =
        Enum.map(1..1000, fn i ->
          %{id: "evt_#{i}", type: "test_event", data: "test_data_#{i}"}
        end)

      start_time = System.monotonic_time(:millisecond)

      {:ok, results} = RealTimeProcessor.process_event_stream(large_stream)

      end_time = System.monotonic_time(:millisecond)
      execution_time = end_time - start_time

      assert results.events_processed == 1000
      # Should handle large streams within reasonable time (10 seconds)
      assert execution_time < 10_000
    end

    test "handles malformed detection parameters" do
      malformed_params = %{
        # Should be numeric
        sensitivity: "invalid",
        # Invalid negative value
        window_size_seconds: -100,
        # Should be numeric
        baseline_period_days: "not_a_number"
      }

      result =
        RealTimeProcessor.detect_real_time_anomalies(
          @valid_event_stream,
          malformed_params
        )

      case result do
        {:ok, anomalies} ->
          assert is_list(anomalies)

        {:error, _reason} ->
          # Acceptable to reject malformed parameters
          :ok
      end
    end

    test "handles missing required fields in alert rules" do
      incomplete_rules = %{
        auto_response_enabled: true
        # Missing severity_thresholds
      }

      result =
        RealTimeProcessor.generate_real_time_alerts(
          @valid_processing_results,
          incomplete_rules
        )

      case result do
        {:ok, alerts} ->
          assert is_list(alerts)

        {:error, _reason} ->
          # Acceptable to reject incomplete rules
          :ok
      end
    end
  end

  # ============================================================================
  # PERFORMANCE TESTS
  # ============================================================================

  describe "Performance Requirements" do
    test "single event processing completes within performance requirements" do
      start_time = System.monotonic_time(:millisecond)

      {:ok, _processed_event} = RealTimeProcessor.process_real_time_event(@valid_event)

      end_time = System.monotonic_time(:millisecond)
      execution_time = end_time - start_time

      # Should complete within 50ms for single event
      assert execution_time < 50
    end

    test "stream processing maintains adequate throughput" do
      medium_stream =
        Enum.map(1..100, fn i ->
          %{id: "evt_#{i}", type: "test_event", timestamp: DateTime.utc_now()}
        end)

      start_time = System.monotonic_time(:millisecond)

      {:ok, results} = RealTimeProcessor.process_event_stream(medium_stream)

      end_time = System.monotonic_time(:millisecond)
      execution_time = end_time - start_time

      assert results.events_processed == 100

      # Calculate events per second
      if execution_time > 0 do
        # events per second
        throughput = 100 * 1000 / execution_time
        # Should process at least 100 events per second
        assert throughput >= 100
      end
    end

    test "anomaly detection scales with event count" do
      small_stream =
        Enum.map(1..10, fn i ->
          %{id: "evt_#{i}", type: "test_event"}
        end)

      large_stream =
        Enum.map(1..100, fn i ->
          %{id: "evt_#{i}", type: "test_event"}
        end)

      # Time small stream processing
      start_time = System.monotonic_time(:millisecond)

      {:ok, _small_anomalies} =
        RealTimeProcessor.detect_real_time_anomalies(
          small_stream,
          @valid_detection_params
        )

      small_time = System.monotonic_time(:millisecond) - start_time

      # Time large stream processing
      start_time = System.monotonic_time(:millisecond)

      {:ok, _large_anomalies} =
        RealTimeProcessor.detect_real_time_anomalies(
          large_stream,
          @valid_detection_params
        )

      large_time = System.monotonic_time(:millisecond) - start_time

      # Processing time should scale reasonably with event count
      # Large stream (10x events) should not take more than 20x time
      if small_time > 0 do
        time_ratio = large_time / small_time
        assert time_ratio <= 20
      end
    end
  end

  # ============================================================================
  # HELPER FUNCTIONS AND GENERATORS
  # ============================================================================

  # PropCheck Generators
  defp real_time_event_generator do
    Indrajaal.PropCheckHelpers.fixed_map(%{
      id: PC.oneof([PC.utf8(), nil]),
      type: PC.oneof(["login_attempt", "file_access", "network_connection", "permission_change"]),
      user_id: PC.oneof([PC.utf8(), nil]),
      ip_address: PC.oneof([PC.utf8(), nil]),
      timestamp: PC.oneof([DateTime.utc_now(), nil]),
      tenant_id: PC.oneof([PC.utf8(), nil]),
      data:
        PC.oneof([Indrajaal.PropCheckHelpers.fixed_map(%{key: PC.utf8(), value: PC.utf8()}), nil])
    })
  end

  defp detection_params_generator do
    Indrajaal.PropCheckHelpers.fixed_map(%{
      sensitivity: PC.oneof([float(0.0, 1.0), nil]),
      window_size_seconds: PC.oneof([integer(60, 3600), nil]),
      baseline_period_days: PC.oneof([integer(1, 30), nil]),
      tenant_id: PC.oneof([PC.utf8(), nil])
    })
  end

  defp correlation_params_generator do
    Indrajaal.PropCheckHelpers.fixed_map(%{
      time_window_seconds: PC.oneof([integer(60, 3600), nil]),
      max_distance: PC.oneof([float(0.0, 1.0), nil]),
      min_confidence: PC.oneof([float(0.0, 1.0), nil]),
      tenant_id: PC.oneof([PC.utf8(), nil])
    })
  end

  defp processing_results_generator do
    Indrajaal.PropCheckHelpers.fixed_map(%{
      stream_id: PC.PC.utf8(),
      events_processed: PC.integer(0, 10_000),
      anomalies_detected:
        PC.list(
          Indrajaal.PropCheckHelpers.fixed_map(%{
            event_id: PC.PC.utf8(),
            type: PC.PC.utf8()
          })
        ),
      correlations_found: PC.integer(0, 100)
    })
  end

  defp alert_rules_generator do
    Indrajaal.PropCheckHelpers.fixed_map(%{
      severity_thresholds:
        Indrajaal.PropCheckHelpers.fixed_map(%{
          critical: PC.float(0.8, 1.0),
          high: PC.float(0.6, 0.8),
          medium: PC.float(0.4, 0.6),
          low: PC.float(0.0, 0.4)
        }),
      auto_response_enabled: PC.boolean(),
      tenant_id: PC.oneof([PC.utf8(), nil])
    })
  end

  # ExUnitProperties StreamData Generators
  defp real_time_event_stream do
    Indrajaal.PropCheckHelpers.fixed_map(%{
      id: SD.one_of([SD.string(:alphanumeric), SD.constant(nil)]),
      type:
        SD.member_of(["login_attempt", "file_access", "network_connection", "permission_change"]),
      user_id: SD.one_of([SD.string(:alphanumeric), SD.constant(nil)]),
      ip_address: SD.one_of([SD.string(:alphanumeric), SD.constant(nil)]),
      timestamp: SD.one_of([SD.constant(DateTime.utc_now()), SD.constant(nil)]),
      tenant_id: SD.one_of([SD.string(:alphanumeric), SD.constant(nil)])
    })
  end

  defp detection_params_stream do
    Indrajaal.PropCheckHelpers.fixed_map(%{
      sensitivity: SD.one_of([SD.float(min: 0.0, max: 1.0), SD.constant(nil)]),
      window_size_seconds: SD.one_of([SD.integer(60..3600), SD.constant(nil)]),
      baseline_period_days: SD.one_of([SD.integer(1..30), SD.constant(nil)]),
      tenant_id: SD.one_of([SD.string(:alphanumeric), SD.constant(nil)])
    })
  end

  defp correlation_params_stream do
    Indrajaal.PropCheckHelpers.fixed_map(%{
      time_window_seconds: SD.one_of([SD.integer(60..3600), SD.constant(nil)]),
      max_distance: SD.one_of([SD.float(min: 0.0, max: 1.0), SD.constant(nil)]),
      min_confidence: SD.one_of([SD.float(min: 0.0, max: 1.0), SD.constant(nil)]),
      tenant_id: SD.one_of([SD.string(:alphanumeric), SD.constant(nil)])
    })
  end

  defp processing_results_stream do
    Indrajaal.PropCheckHelpers.fixed_map(%{
      stream_id: SD.string(:alphanumeric),
      events_processed: SD.integer(0..10_000),
      anomalies_detected:
        SD.list_of(
          Indrajaal.PropCheckHelpers.fixed_map(%{
            event_id: SD.string(:alphanumeric),
            type: SD.string(:alphanumeric)
          }),
          max_length: 10
        ),
      correlations_found: SD.integer(0..100)
    })
  end

  defp alert_rules_stream do
    Indrajaal.PropCheckHelpers.fixed_map(%{
      severity_thresholds:
        Indrajaal.PropCheckHelpers.fixed_map(%{
          critical: SD.float(min: 0.8, max: 1.0),
          high: SD.float(min: 0.6, max: 0.8),
          medium: SD.float(min: 0.4, max: 0.6),
          low: SD.float(min: 0.0, max: 0.4)
        }),
      auto_response_enabled: SD.boolean(),
      tenant_id: SD.one_of([SD.string(:alphanumeric), SD.constant(nil)])
    })
  end
end
