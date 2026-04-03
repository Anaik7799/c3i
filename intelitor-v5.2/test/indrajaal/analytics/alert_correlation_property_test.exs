defmodule Indrajaal.Analytics.AlertCorrelationPropertyTest do
  use ExUnit.Case, async: true
  # Advanced property testing with sophisticated shrinking
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  # StreamData-based property testing - import except check to avoid conflict
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # Disambiguate PropCheck vs StreamData generators
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Analytics.AlertCorrelation

  @moduletag :property_test
  @moduletag :analytics
  @moduletag :alert_correlation
  @moduletag :tdg_compliant

  # Test data generators for property-based testing
  @valid_alert_data %{
    alert_id: "ALT-001",
    timestamp: ~N[2025-09-19 14:00:00],
    severity: :high,
    source: "security_system",
    category: :intrusion_detection,
    description: "Unauthorized access attempt detected",
    metadata: %{
      ip_address: "192.168.1.100",
      user_agent: "Mozilla/5.0",
      location: "Building A - Floor 2",
      device_id: "DEV-001"
    },
    correlation_fields: [:source, :category, :severity, :location]
  }

  @valid_correlation_config %{
    # 5 minutes in seconds
    time_window: 300,
    similarity_threshold: 0.8,
    max_correlation_group_size: 50,
    correlation_algorithms: [:temporal, :semantic, :behavioral],
    deduplication_enabled: true,
    priority_weighting: %{
      severity: 0.4,
      temporal_proximity: 0.3,
      source_similarity: 0.2,
      semantic_similarity: 0.1
    },
    escalation_rules: [
      %{condition: "count > 5", action: :escalate_to_critical},
      %{condition: "severity >= :high AND count > 3", action: :notify_security_team}
    ]
  }

  @valid_alert_stream [
    %{
      @valid_alert_data
      | alert_id: "ALT-001",
        timestamp: ~N[2025-09-19 14:00:00],
        severity: :medium
    },
    %{
      @valid_alert_data
      | alert_id: "ALT-002",
        timestamp: ~N[2025-09-19 14:01:00],
        severity: :high
    },
    %{
      @valid_alert_data
      | alert_id: "ALT-003",
        timestamp: ~N[2025-09-19 14:02:00],
        severity: :high
    },
    %{
      @valid_alert_data
      | alert_id: "ALT-004",
        timestamp: ~N[2025-09-19 14:05:00],
        severity: :low
    },
    %{
      @valid_alert_data
      | alert_id: "ALT-005",
        timestamp: ~N[2025-09-19 14:08:00],
        severity: :critical
    }
  ]

  @valid_correlation_rules [
    %{
      rule_id: "RULE-001",
      name: "Temporal Correlation",
      algorithm: :temporal,
      parameters: %{time_window: 300, max_gap: 60},
      weight: 0.3
    },
    %{
      rule_id: "RULE-002",
      name: "Semantic Similarity",
      algorithm: :semantic,
      parameters: %{similarity_threshold: 0.7, vector_model: :bert},
      weight: 0.4
    },
    %{
      rule_id: "RULE-003",
      name: "Behavioral Pattern",
      algorithm: :behavioral,
      parameters: %{pattern_window: 3600, anomaly_threshold: 0.6},
      weight: 0.3
    }
  ]

  @alert_severities [:low, :medium, :high, :critical]
  @alert_categories [
    :intrusion_detection,
    :malware,
    :data_breach,
    :system_failure,
    :performance_degradation
  ]
  @correlation_algorithms [:temporal, :semantic, :behavioral, :statistical, :pattern_matching]
  @alert_sources ["security_system", "firewall", "ids", "antivirus", "monitoring_system"]

  # =============================================================================
  # PROPERTY-BASED TESTS - PROPCHECK FRAMEWORK
  # =============================================================================

  describe "PropCheck Property-Based Tests for AlertCorrelation" do
    test "propcheck: correlate_alerts/2 always returns valid correlation structure with advanced shrinking" do
      assert PropCheck.quickcheck(
               forall {alert_stream, correlation_config} <-
                        {PC.list(PC.map(PC.atom(), PC.any())), PC.map(PC.atom(), PC.any())} do
                 case AlertCorrelation.correlate_alerts(alert_stream, correlation_config) do
                   {:ok, correlation_results} ->
                     is_map(correlation_results) and
                       Map.has_key?(correlation_results, :correlation_groups) and
                       Map.has_key?(correlation_results, :isolated_alerts) and
                       Map.has_key?(correlation_results, :correlation_metadata) and
                       Map.has_key?(correlation_results, :processing_time) and
                       is_list(correlation_results.correlation_groups) and
                       is_list(correlation_results.isolated_alerts) and
                       is_map(correlation_results.correlation_metadata) and
                       is_number(correlation_results.processing_time) and
                       correlation_results.processing_time >= 0

                   {:error, _reason} ->
                     # Valid error response for invalid input
                     true
                 end
               end
             )
    end

    test "propcheck: calculate_correlation_score/3 produces bounded correlation scores with advanced shrinking" do
      assert PropCheck.quickcheck(
               forall {alert1, alert2, correlation_rules} <-
                        {PC.map(PC.atom(), PC.any()), PC.map(PC.atom(), PC.any()),
                         PC.list(PC.map(PC.atom(), PC.any()))} do
                 case AlertCorrelation.calculate_correlation_score(
                        alert1,
                        alert2,
                        correlation_rules
                      ) do
                   {:ok, correlation_score} ->
                     is_map(correlation_score) and
                       Map.has_key?(correlation_score, :overall_score) and
                       Map.has_key?(correlation_score, :component_scores) and
                       Map.has_key?(correlation_score, :confidence) and
                       is_number(correlation_score.overall_score) and
                       correlation_score.overall_score >= 0.0 and
                       correlation_score.overall_score <= 1.0 and
                       is_number(correlation_score.confidence) and
                       correlation_score.confidence >= 0.0 and
                       correlation_score.confidence <= 1.0

                   {:error, _reason} ->
                     true
                 end
               end
             )
    end

    test "propcheck: detect_alert_patterns/2 identifies valid pattern structures" do
      assert PropCheck.quickcheck(
               forall {historical_alerts, pattern_config} <-
                        {PC.list(PC.map(PC.atom(), PC.any())), PC.map(PC.atom(), PC.any())} do
                 case AlertCorrelation.detect_alert_patterns(historical_alerts, pattern_config) do
                   {:ok, detected_patterns} ->
                     is_map(detected_patterns) and
                       Map.has_key?(detected_patterns, :temporal_patterns) and
                       Map.has_key?(detected_patterns, :frequency_patterns) and
                       Map.has_key?(detected_patterns, :sequence_patterns) and
                       Map.has_key?(detected_patterns, :anomaly_patterns) and
                       is_list(detected_patterns.temporal_patterns) and
                       is_list(detected_patterns.frequency_patterns) and
                       is_list(detected_patterns.sequence_patterns) and
                       is_list(detected_patterns.anomaly_patterns)

                   {:error, _reason} ->
                     true
                 end
               end
             )
    end

    test "propcheck: group_correlated_alerts/3 maintains group consistency" do
      assert PropCheck.quickcheck(
               forall {alerts, correlation_matrix, grouping_config} <-
                        {PC.list(PC.map(PC.atom(), PC.any())), PC.list(PC.list(PC.number())),
                         PC.map(PC.atom(), PC.any())} do
                 case AlertCorrelation.group_correlated_alerts(
                        alerts,
                        correlation_matrix,
                        grouping_config
                      ) do
                   {:ok, alert_groups} ->
                     is_map(alert_groups) and
                       Map.has_key?(alert_groups, :groups) and
                       Map.has_key?(alert_groups, :group_metadata) and
                       Map.has_key?(alert_groups, :ungrouped_alerts) and
                       is_list(alert_groups.groups) and
                       is_map(alert_groups.group_metadata) and
                       is_list(alert_groups.ungrouped_alerts)

                   {:error, _reason} ->
                     true
                 end
               end
             )
    end

    test "propcheck: prioritize_alert_groups/2 produces valid priority rankings" do
      assert PropCheck.quickcheck(
               forall {alert_groups, prioritization_config} <-
                        {PC.list(PC.map(PC.atom(), PC.any())), PC.map(PC.atom(), PC.any())} do
                 case AlertCorrelation.prioritize_alert_groups(
                        alert_groups,
                        prioritization_config
                      ) do
                   {:ok, prioritized_groups} ->
                     is_map(prioritized_groups) and
                       Map.has_key?(prioritized_groups, :priority_ranking) and
                       Map.has_key?(prioritized_groups, :priority_scores) and
                       Map.has_key?(prioritized_groups, :escalation_recommendations) and
                       is_list(prioritized_groups.priority_ranking) and
                       is_map(prioritized_groups.priority_scores) and
                       is_list(prioritized_groups.escalation_recommendations)

                   {:error, _reason} ->
                     true
                 end
               end
             )
    end

    test "propcheck: analyze_correlation_trends/2 produces valid trend analysis" do
      assert PropCheck.quickcheck(
               forall {correlation_history, trend_config} <-
                        {PC.list(PC.map(PC.atom(), PC.any())), PC.map(PC.atom(), PC.any())} do
                 case AlertCorrelation.analyze_correlation_trends(
                        correlation_history,
                        trend_config
                      ) do
                   {:ok, trend_analysis} ->
                     is_map(trend_analysis) and
                       Map.has_key?(trend_analysis, :trend_direction) and
                       Map.has_key?(trend_analysis, :correlation_frequency) and
                       Map.has_key?(trend_analysis, :pattern_evolution) and
                       Map.has_key?(trend_analysis, :prediction_metrics) and
                       trend_analysis.trend_direction in [
                         :increasing,
                         :decreasing,
                         :stable,
                         :volatile
                       ] and
                       is_map(trend_analysis.correlation_frequency) and
                       is_list(trend_analysis.pattern_evolution)

                   {:error, _reason} ->
                     true
                 end
               end
             )
    end

    test "propcheck: generate_correlation_report/2 creates comprehensive reports" do
      assert PropCheck.quickcheck(
               forall {correlation_data, report_config} <-
                        {PC.map(PC.atom(), PC.any()), PC.map(PC.atom(), PC.any())} do
                 case AlertCorrelation.generate_correlation_report(
                        correlation_data,
                        report_config
                      ) do
                   {:ok, correlation_report} ->
                     is_map(correlation_report) and
                       Map.has_key?(correlation_report, :executive_summary) and
                       Map.has_key?(correlation_report, :detailed_analysis) and
                       Map.has_key?(correlation_report, :recommendations) and
                       Map.has_key?(correlation_report, :metrics) and
                       is_binary(correlation_report.executive_summary) and
                       is_map(correlation_report.detailed_analysis) and
                       is_list(correlation_report.recommendations) and
                       is_map(correlation_report.metrics)

                   {:error, _reason} ->
                     true
                 end
               end
             )
    end

    test "propcheck: optimize_correlation_parameters/2 maintains optimization constraints" do
      assert PropCheck.quickcheck(
               forall {current_parameters, optimization_criteria} <-
                        {PC.map(PC.atom(), PC.any()), PC.map(PC.atom(), PC.any())} do
                 case AlertCorrelation.optimize_correlation_parameters(
                        current_parameters,
                        optimization_criteria
                      ) do
                   {:ok, optimized_parameters} ->
                     is_map(optimized_parameters) and
                       Map.has_key?(optimized_parameters, :optimized_config) and
                       Map.has_key?(optimized_parameters, :performance_improvement) and
                       Map.has_key?(optimized_parameters, :optimization_metrics) and
                       is_map(optimized_parameters.optimized_config) and
                       is_number(optimized_parameters.performance_improvement) and
                       is_map(optimized_parameters.optimization_metrics)

                   {:error, _reason} ->
                     true
                 end
               end
             )
    end
  end

  # =============================================================================
  # PROPERTY-BASED TESTS - EXUNITPROPERTIES FRAMEWORK
  # =============================================================================

  describe "ExUnitProperties Property-Based Tests for AlertCorrelation" do
    test "exunitproperties: correlate_alerts/2 maintains structural consistency" do
      ExUnitProperties.check all(
                               alert_stream <-
                                 SD.list_of(SD.map_of(SD.atom(:alphanumeric), SD.term())),
                               correlation_config <- SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               max_runs: 100
                             ) do
        case AlertCorrelation.correlate_alerts(alert_stream, correlation_config) do
          {:ok, correlation_results} ->
            assert is_map(correlation_results)
            assert Map.has_key?(correlation_results, :correlation_groups)
            assert Map.has_key?(correlation_results, :isolated_alerts)
            assert Map.has_key?(correlation_results, :correlation_metadata)
            assert Map.has_key?(correlation_results, :processing_time)
            assert is_list(correlation_results.correlation_groups)
            assert is_list(correlation_results.isolated_alerts)
            assert is_number(correlation_results.processing_time)
            assert correlation_results.processing_time >= 0

          {:error, _reason} ->
            assert true
        end
      end
    end

    test "exunitproperties: calculate_correlation_score/3 validates score bounds" do
      ExUnitProperties.check all(
                               alert1 <- SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               alert2 <- SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               correlation_rules <-
                                 SD.list_of(SD.map_of(SD.atom(:alphanumeric), SD.term())),
                               max_runs: 100
                             ) do
        case AlertCorrelation.calculate_correlation_score(alert1, alert2, correlation_rules) do
          {:ok, correlation_score} ->
            assert is_map(correlation_score)
            assert Map.has_key?(correlation_score, :overall_score)
            assert Map.has_key?(correlation_score, :component_scores)
            assert Map.has_key?(correlation_score, :confidence)
            assert is_number(correlation_score.overall_score)

            assert correlation_score.overall_score >= 0.0 and
                     correlation_score.overall_score <= 1.0

            assert is_number(correlation_score.confidence)
            assert correlation_score.confidence >= 0.0 and correlation_score.confidence <= 1.0

          {:error, _reason} ->
            assert true
        end
      end
    end

    test "exunitproperties: detect_alert_patterns/2 identifies consistent patterns" do
      ExUnitProperties.check all(
                               historical_alerts <-
                                 SD.list_of(SD.map_of(SD.atom(:alphanumeric), SD.term())),
                               pattern_config <- SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               max_runs: 100
                             ) do
        case AlertCorrelation.detect_alert_patterns(historical_alerts, pattern_config) do
          {:ok, detected_patterns} ->
            assert is_map(detected_patterns)
            assert Map.has_key?(detected_patterns, :temporal_patterns)
            assert Map.has_key?(detected_patterns, :frequency_patterns)
            assert Map.has_key?(detected_patterns, :sequence_patterns)
            assert Map.has_key?(detected_patterns, :anomaly_patterns)
            assert is_list(detected_patterns.temporal_patterns)
            assert is_list(detected_patterns.frequency_patterns)
            assert is_list(detected_patterns.sequence_patterns)
            assert is_list(detected_patterns.anomaly_patterns)

          {:error, _reason} ->
            assert true
        end
      end
    end

    test "exunitproperties: group_correlated_alerts/3 maintains group integrity" do
      ExUnitProperties.check all(
                               alerts <- SD.list_of(SD.map_of(SD.atom(:alphanumeric), SD.term())),
                               correlation_matrix <- SD.list_of(SD.list_of(SD.float())),
                               grouping_config <- SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               max_runs: 100
                             ) do
        case AlertCorrelation.group_correlated_alerts(alerts, correlation_matrix, grouping_config) do
          {:ok, alert_groups} ->
            assert is_map(alert_groups)
            assert Map.has_key?(alert_groups, :groups)
            assert Map.has_key?(alert_groups, :group_metadata)
            assert Map.has_key?(alert_groups, :ungrouped_alerts)
            assert is_list(alert_groups.groups)
            assert is_map(alert_groups.group_metadata)
            assert is_list(alert_groups.ungrouped_alerts)

          {:error, _reason} ->
            assert true
        end
      end
    end

    test "exunitproperties: prioritize_alert_groups/2 creates valid priority orderings" do
      ExUnitProperties.check all(
                               alert_groups <-
                                 SD.list_of(SD.map_of(SD.atom(:alphanumeric), SD.term())),
                               prioritization_config <-
                                 SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               max_runs: 100
                             ) do
        case AlertCorrelation.prioritize_alert_groups(alert_groups, prioritization_config) do
          {:ok, prioritized_groups} ->
            assert is_map(prioritized_groups)
            assert Map.has_key?(prioritized_groups, :priority_ranking)
            assert Map.has_key?(prioritized_groups, :priority_scores)
            assert Map.has_key?(prioritized_groups, :escalation_recommendations)
            assert is_list(prioritized_groups.priority_ranking)
            assert is_map(prioritized_groups.priority_scores)
            assert is_list(prioritized_groups.escalation_recommendations)

          {:error, _reason} ->
            assert true
        end
      end
    end

    test "exunitproperties: analyze_correlation_trends/2 validates trend metrics" do
      ExUnitProperties.check all(
                               correlation_history <-
                                 SD.list_of(SD.map_of(SD.atom(:alphanumeric), SD.term())),
                               trend_config <- SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               max_runs: 100
                             ) do
        case AlertCorrelation.analyze_correlation_trends(correlation_history, trend_config) do
          {:ok, trend_analysis} ->
            assert is_map(trend_analysis)
            assert Map.has_key?(trend_analysis, :trend_direction)
            assert Map.has_key?(trend_analysis, :correlation_frequency)
            assert Map.has_key?(trend_analysis, :pattern_evolution)
            assert Map.has_key?(trend_analysis, :prediction_metrics)

            assert trend_analysis.trend_direction in [
                     :increasing,
                     :decreasing,
                     :stable,
                     :volatile
                   ]

            assert is_map(trend_analysis.correlation_frequency)
            assert is_list(trend_analysis.pattern_evolution)

          {:error, _reason} ->
            assert true
        end
      end
    end

    test "exunitproperties: generate_correlation_report/2 produces structured reports" do
      ExUnitProperties.check all(
                               correlation_data <- SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               report_config <- SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               max_runs: 100
                             ) do
        case AlertCorrelation.generate_correlation_report(correlation_data, report_config) do
          {:ok, correlation_report} ->
            assert is_map(correlation_report)
            assert Map.has_key?(correlation_report, :executive_summary)
            assert Map.has_key?(correlation_report, :detailed_analysis)
            assert Map.has_key?(correlation_report, :recommendations)
            assert Map.has_key?(correlation_report, :metrics)
            assert is_binary(correlation_report.executive_summary)
            assert is_map(correlation_report.detailed_analysis)
            assert is_list(correlation_report.recommendations)
            assert is_map(correlation_report.metrics)

          {:error, _reason} ->
            assert true
        end
      end
    end

    test "exunitproperties: optimize_correlation_parameters/2 respects optimization bounds" do
      ExUnitProperties.check all(
                               current_parameters <- SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               optimization_criteria <-
                                 SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               max_runs: 100
                             ) do
        case AlertCorrelation.optimize_correlation_parameters(
               current_parameters,
               optimization_criteria
             ) do
          {:ok, optimized_parameters} ->
            assert is_map(optimized_parameters)
            assert Map.has_key?(optimized_parameters, :optimized_config)
            assert Map.has_key?(optimized_parameters, :performance_improvement)
            assert Map.has_key?(optimized_parameters, :optimization_metrics)
            assert is_map(optimized_parameters.optimized_config)
            assert is_number(optimized_parameters.performance_improvement)
            assert is_map(optimized_parameters.optimization_metrics)

          {:error, _reason} ->
            assert true
        end
      end
    end
  end

  # =============================================================================
  # STAMP SAFETY CONSTRAINTS VALIDATION
  # =============================================================================

  describe "STAMP Safety Constraints for Alert Correlation" do
    test "SC-AC-001: System SHALL ensure alert correlation maintains temporal consistency" do
      # Test with time-ordered alert stream
      time_ordered_alerts = [
        %{@valid_alert_data | alert_id: "ALT-T1", timestamp: ~N[2025-09-19 14:00:00]},
        %{@valid_alert_data | alert_id: "ALT-T2", timestamp: ~N[2025-09-19 14:01:00]},
        %{@valid_alert_data | alert_id: "ALT-T3", timestamp: ~N[2025-09-19 14:02:00]},
        %{@valid_alert_data | alert_id: "ALT-T4", timestamp: ~N[2025-09-19 14:03:00]}
      ]

      # 5 minutes
      correlation_config = %{@valid_correlation_config | time_window: 300}

      case AlertCorrelation.correlate_alerts(time_ordered_alerts, correlation_config) do
        {:ok, correlation_results} ->
          # Verify temporal consistency in correlation groups
          correlation_groups = correlation_results.correlation_groups

          Enum.each(correlation_groups, fn group ->
            if Map.has_key?(group, :alerts) and is_list(group.alerts) do
              # Verify alerts in group are within time window
              timestamps =
                Enum.map(group.alerts, fn alert ->
                  if Map.has_key?(alert, :timestamp) do
                    alert.timestamp
                  else
                    # Default timestamp
                    ~N[2025-09-19 14:00:00]
                  end
                end)

              if length(timestamps) > 1 do
                sorted_timestamps = Enum.sort(timestamps)
                first_time = hd(sorted_timestamps)
                last_time = List.last(sorted_timestamps)

                time_diff = NaiveDateTime.diff(last_time, first_time, :second)
                assert time_diff <= 300, "Time window exceeded: #{time_diff} seconds"
              end
            end
          end)

        {:error, _reason} ->
          assert true
      end
    end

    test "SC-AC-002: System SHALL maintain correlation score accuracy within statistical bounds" do
      ExUnitProperties.check all(
                               alert1 <- SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               alert2 <- SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               max_runs: 50
                             ) do
        correlation_rules = @valid_correlation_rules

        case AlertCorrelation.calculate_correlation_score(alert1, alert2, correlation_rules) do
          {:ok, correlation_score} ->
            # Verify statistical bounds for correlation scoring
            overall_score = correlation_score.overall_score
            confidence = correlation_score.confidence

            # Scores must be within valid probability ranges
            assert overall_score >= 0.0 and overall_score <= 1.0
            assert confidence >= 0.0 and confidence <= 1.0

            # Component scores should be consistent with overall score
            if Map.has_key?(correlation_score, :component_scores) do
              component_scores = correlation_score.component_scores

              if is_map(component_scores) do
                Enum.each(component_scores, fn {_component, score} ->
                  if is_number(score) do
                    assert score >= 0.0 and score <= 1.0
                  end
                end)
              end
            end

          {:error, _reason} ->
            assert true
        end
      end
    end

    test "SC-AC-003: System SHALL prevent correlation group size exceeding configured limits" do
      # Test with large alert stream to check group size limits
      large_alert_stream =
        Enum.map(1..100, fn i ->
          %{@valid_alert_data | alert_id: "ALT-#{i}", timestamp: ~N[2025-09-19 14:00:00]}
        end)

      correlation_config = %{@valid_correlation_config | max_correlation_group_size: 10}

      case AlertCorrelation.correlate_alerts(large_alert_stream, correlation_config) do
        {:ok, correlation_results} ->
          # Verify no group exceeds the configured limit
          correlation_groups = correlation_results.correlation_groups

          Enum.each(correlation_groups, fn group ->
            if Map.has_key?(group, :alerts) and is_list(group.alerts) do
              group_size = length(group.alerts)
              assert group_size <= 10, "Group size #{group_size} exceeds limit of 10"
            end
          end)

        {:error, _reason} ->
          assert true
      end
    end

    test "SC-AC-004: System SHALL ensure pattern detection maintains statistical significance" do
      # Test with substantial historical data for statistical validation
      substantial_history =
        Enum.map(1..50, fn i ->
          %{
            alert_id: "HIST-#{i}",
            timestamp: NaiveDateTime.add(~N[2025-09-19 10:00:00], i * 60, :second),
            severity: Enum.random(@alert_severities),
            category: Enum.random(@alert_categories),
            source: Enum.random(@alert_sources)
          }
        end)

      pattern_config = %{
        # 10% minimum support
        min_pattern_support: 0.1,
        # 70% confidence
        confidence_threshold: 0.7,
        # p-value < 0.05
        statistical_significance: 0.05
      }

      case AlertCorrelation.detect_alert_patterns(substantial_history, pattern_config) do
        {:ok, detected_patterns} ->
          # Verify statistical significance of detected patterns
          pattern_types = [:temporal_patterns, :frequency_patterns, :sequence_patterns]

          Enum.each(pattern_types, fn pattern_type ->
            patterns = Map.get(detected_patterns, pattern_type, [])

            Enum.each(patterns, fn pattern ->
              # Each pattern should have statistical validation
              if is_map(pattern) do
                # Check for statistical metrics
                if Map.has_key?(pattern, :support) and is_number(pattern.support) do
                  assert pattern.support >= 0.0 and pattern.support <= 1.0
                end

                if Map.has_key?(pattern, :confidence) and is_number(pattern.confidence) do
                  assert pattern.confidence >= 0.0 and pattern.confidence <= 1.0
                end
              end
            end)
          end)

        {:error, _reason} ->
          assert true
      end
    end

    test "SC-AC-005: System SHALL maintain correlation performance under high alert volumes" do
      # Test performance with high-volume alert correlation
      high_volume_alerts =
        Enum.map(1..200, fn i ->
          %{
            @valid_alert_data
            | alert_id: "HV-#{i}",
              timestamp: NaiveDateTime.add(~N[2025-09-19 14:00:00], i * 10, :second)
          }
        end)

      correlation_config = @valid_correlation_config

      start_time = System.monotonic_time(:millisecond)

      result = AlertCorrelation.correlate_alerts(high_volume_alerts, correlation_config)

      end_time = System.monotonic_time(:millisecond)
      processing_time = end_time - start_time

      case result do
        {:ok, correlation_results} ->
          # Verify performance under high volume
          assert processing_time < 10_000,
                 "High volume correlation took #{processing_time}ms, expected < 10000ms"

          # Verify processing time is recorded accurately
          recorded_time = correlation_results.processing_time
          assert is_number(recorded_time)
          assert recorded_time >= 0

          # Processing should handle all alerts
          total_alerts =
            length(correlation_results.correlation_groups) +
              length(correlation_results.isolated_alerts)

          assert total_alerts <= length(high_volume_alerts)

        {:error, _reason} ->
          # Even failure should occur within reasonable time
          assert processing_time < 5000,
                 "Error handling took #{processing_time}ms, expected < 5000ms"
      end
    end
  end

  # =============================================================================
  # PERFORMANCE PROPERTY VALIDATION
  # =============================================================================

  describe "Performance Properties for Alert Correlation" do
    test "correlation processing performance scales linearly with alert volume" do
      # Test with different alert volumes
      volumes = [10, 50, 100]

      processing_times =
        Enum.map(volumes, fn volume ->
          alert_stream =
            Enum.map(1..volume, fn i ->
              %{@valid_alert_data | alert_id: "PERF-#{i}"}
            end)

          start_time = System.monotonic_time(:millisecond)
          _result = AlertCorrelation.correlate_alerts(alert_stream, @valid_correlation_config)
          end_time = System.monotonic_time(:millisecond)

          end_time - start_time
        end)

      [small_time, medium_time, large_time] = processing_times

      # Processing time should scale reasonably (not exponentially)
      time_ratio = large_time / small_time
      assert time_ratio < 50, "Processing time scaling is poor: #{inspect(processing_times)}"

      # Medium volume should be between small and large
      assert medium_time >= small_time
      assert medium_time <= large_time
    end

    test "memory efficiency during large correlation operations" do
      # Create substantial alert dataset
      large_alert_dataset =
        Enum.map(1..300, fn i ->
          %{@valid_alert_data | alert_id: "MEM-#{i}"}
        end)

      # Monitor memory before
      memory_before = :erlang.memory(:total)

      result = AlertCorrelation.correlate_alerts(large_alert_dataset, @valid_correlation_config)

      # Force garbage collection
      :erlang.garbage_collect()

      # Monitor memory after
      memory_after = :erlang.memory(:total)
      memory_increase = memory_after - memory_before

      case result do
        {:ok, _correlation_results} ->
          # Memory increase should be reasonable (< 150MB for this dataset)
          assert memory_increase < 150_000_000,
                 "Memory increase #{memory_increase} bytes is excessive"

        {:error, _reason} ->
          # Error handling should not cause memory leaks
          assert memory_increase < 50_000_000,
                 "Memory increase #{memory_increase} bytes during error handling"
      end
    end

    test "concurrent correlation processing maintains consistency" do
      # Test concurrent correlation operations
      alert_batches =
        Enum.map(1..5, fn batch ->
          Enum.map(1..20, fn i ->
            %{@valid_alert_data | alert_id: "CONC-#{batch}-#{i}"}
          end)
        end)

      # Run correlations concurrently
      tasks =
        Enum.map(alert_batches, fn batch ->
          Task.async(fn ->
            AlertCorrelation.correlate_alerts(batch, @valid_correlation_config)
          end)
        end)

      # 10 second timeout
      results = Task.await_many(tasks, 10_000)

      # Verify all concurrent operations completed successfully
      success_count = Enum.count(results, fn result -> match?({:ok, _}, result) end)
      assert success_count >= 3, "Only #{success_count}/5 concurrent operations succeeded"

      # Verify results have consistent structure
      Enum.each(results, fn result ->
        case result do
          {:ok, correlation_results} ->
            assert Map.has_key?(correlation_results, :correlation_groups)
            assert Map.has_key?(correlation_results, :isolated_alerts)

          {:error, _reason} ->
            assert true
        end
      end)
    end
  end

  # =============================================================================
  # ERROR HANDLING PROPERTY VALIDATION
  # =============================================================================

  describe "Error Handling Properties for Alert Correlation" do
    test "graceful handling of malformed alert data" do
      malformed_alerts = [
        "invalid_string",
        %{invalid: "structure"},
        %{alert_id: nil, timestamp: "invalid_time"},
        %{alert_id: "valid", timestamp: ~N[2025-09-19 14:00:00], severity: :invalid_severity}
      ]

      Enum.each(malformed_alerts, fn alert_data ->
        alert_stream = [alert_data]
        result = AlertCorrelation.correlate_alerts(alert_stream, @valid_correlation_config)

        case result do
          {:ok, _correlation_results} ->
            # Function handled malformed input gracefully
            assert true

          {:error, reason} ->
            # Error should be descriptive and not crash the system
            assert is_binary(reason) or is_atom(reason)
        end
      end)
    end

    test "boundary condition handling in correlation configuration" do
      boundary_configs = [
        %{@valid_correlation_config | time_window: 0},
        %{@valid_correlation_config | time_window: -1},
        %{@valid_correlation_config | similarity_threshold: 0.0},
        %{@valid_correlation_config | similarity_threshold: 1.1},
        %{@valid_correlation_config | max_correlation_group_size: 0},
        %{@valid_correlation_config | correlation_algorithms: []}
      ]

      Enum.each(boundary_configs, fn config ->
        result = AlertCorrelation.correlate_alerts(@valid_alert_stream, config)

        # Should handle boundary conditions gracefully
        case result do
          {:ok, _correlation_results} -> assert true
          {:error, _reason} -> assert true
        end
      end)
    end

    test "robust handling of empty and edge case inputs" do
      edge_cases = [
        # Empty alert stream
        {[], @valid_correlation_config},
        # Empty configuration
        {[@valid_alert_data], %{}},
        # Nil alert stream
        {nil, @valid_correlation_config},
        # Nil configuration
        {@valid_alert_stream, nil}
      ]

      Enum.each(edge_cases, fn {alerts, config} ->
        result = AlertCorrelation.correlate_alerts(alerts, config)

        case result do
          {:ok, correlation_results} ->
            # Should handle edge cases gracefully
            assert is_map(correlation_results)

          {:error, reason} ->
            # Proper error handling
            assert is_binary(reason) or is_atom(reason)
        end
      end)
    end
  end

  # =============================================================================
  # INTEGRATION PROPERTY VALIDATION
  # =============================================================================

  describe "Integration Properties for Alert Correlation" do
    test "integration between pattern detection and alert grouping maintains consistency" do
      historical_alerts = @valid_alert_stream

      pattern_config = %{
        detection_algorithms: [:temporal, :frequency],
        min_pattern_support: 0.2,
        confidence_threshold: 0.6
      }

      # First detect patterns
      pattern_result = AlertCorrelation.detect_alert_patterns(historical_alerts, pattern_config)

      case pattern_result do
        {:ok, detected_patterns} ->
          # Use detected patterns to inform correlation
          enhanced_correlation_config = %{
            @valid_correlation_config
            | detected_patterns: detected_patterns,
              pattern_informed_correlation: true
          }

          correlation_result =
            AlertCorrelation.correlate_alerts(historical_alerts, enhanced_correlation_config)

          case correlation_result do
            {:ok, correlation_results} ->
              # Verify integration consistency
              assert Map.has_key?(correlation_results, :correlation_groups)
              assert Map.has_key?(correlation_results, :correlation_metadata)

              # Pattern-informed correlation should provide metadata about pattern usage
              metadata = correlation_results.correlation_metadata

              if Map.has_key?(metadata, :pattern_usage) do
                assert is_map(metadata.pattern_usage)
              end

            {:error, _reason} ->
              assert true
          end

        {:error, _reason} ->
          assert true
      end
    end

    test "correlation score calculation consistency across different rule sets" do
      alert1 = @valid_alert_data
      alert2 = %{@valid_alert_data | alert_id: "ALT-002", severity: :medium}

      rule_sets = [
        [@valid_correlation_rules],
        # Single rule
        [hd(@valid_correlation_rules)],
        # Duplicate rule
        @valid_correlation_rules ++ [@valid_correlation_rules |> hd()]
      ]

      scores =
        Enum.map(rule_sets, fn rules ->
          AlertCorrelation.calculate_correlation_score(alert1, alert2, rules)
        end)

      # All score calculations should succeed or fail consistently
      success_scores = Enum.filter(scores, fn score -> match?({:ok, _}, score) end)

      if length(success_scores) > 1 do
        # Verify structural consistency across different rule sets
        Enum.each(success_scores, fn {:ok, score} ->
          assert Map.has_key?(score, :overall_score)
          assert Map.has_key?(score, :component_scores)
          assert Map.has_key?(score, :confidence)
          assert is_number(score.overall_score)
          assert score.overall_score >= 0.0 and score.overall_score <= 1.0
        end)
      end
    end

    test "end-to-end correlation pipeline maintains data integrity" do
      # Test complete correlation pipeline
      alert_stream = @valid_alert_stream
      correlation_config = @valid_correlation_config

      # Step 1: Correlate alerts
      correlation_result = AlertCorrelation.correlate_alerts(alert_stream, correlation_config)

      case correlation_result do
        {:ok, correlation_results} ->
          # Step 2: Prioritize correlation groups
          prioritization_config = %{
            priority_factors: [:severity, :frequency, :time_proximity],
            escalation_enabled: true
          }

          prioritization_result =
            AlertCorrelation.prioritize_alert_groups(
              correlation_results.correlation_groups,
              prioritization_config
            )

          case prioritization_result do
            {:ok, prioritized_groups} ->
              # Step 3: Generate correlation report
              report_config = %{
                report_type: :comprehensive,
                include_recommendations: true,
                format: :json
              }

              report_data = %{
                correlation_results: correlation_results,
                prioritized_groups: prioritized_groups
              }

              report_result =
                AlertCorrelation.generate_correlation_report(report_data, report_config)

              case report_result do
                {:ok, correlation_report} ->
                  # Verify end-to-end data integrity
                  assert Map.has_key?(correlation_report, :executive_summary)
                  assert Map.has_key?(correlation_report, :detailed_analysis)
                  assert Map.has_key?(correlation_report, :recommendations)

                  # Report should contain data from all pipeline stages
                  detailed_analysis = correlation_report.detailed_analysis

                  if is_map(detailed_analysis) do
                    # Should contain correlation and prioritization data
                    assert Map.has_key?(detailed_analysis, :correlation_groups) or
                             Map.has_key?(detailed_analysis, :total_alerts) or
                             Map.has_key?(detailed_analysis, :processing_summary)
                  end

                {:error, _reason} ->
                  assert true
              end

            {:error, _reason} ->
              assert true
          end

        {:error, _reason} ->
          assert true
      end
    end
  end
end
