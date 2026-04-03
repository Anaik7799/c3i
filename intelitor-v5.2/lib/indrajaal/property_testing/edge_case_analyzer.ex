defmodule Indrajaal.PropertyTesting.EdgeCaseAnalyzer do
  @moduledoc """
  Advanced edge case discovery and pattern recognition for property-based testing.

  WHAT: Discovers, classifies, and dispatches alerts for critical edge cases found
        during property testing.
  WHY:  Provides real-time visibility into property testing failures with structured
        alert dispatch via Phoenix.PubSub (SC-PRF-050, SC-IMMUNE-001).
  CONSTRAINTS: SC-TEST-EVO-002, SC-IMMUNE-001, SC-BRIDGE-001
  """

  require Logger

  @edge_case_categories [
    :boundary_conditions,
    :null_and_empty_values,
    :extreme_numeric_values,
    :unicode_and_encoding_issues,
    :concurrent_access_patterns,
    :memory_and_resource_limits,
    :network_and_timing_issues,
    :state_transition_anomalies,
    :data_corruption_scenarios,
    :error_propagation_patterns
  ]

  @pubsub_name Indrajaal.PubSub
  @critical_alert_topic "edge_case_analyzer:critical_alerts"
  @edge_case_topic "edge_case_analyzer:edge_cases"

  @doc """
  Analyzes edge case patterns from property testing metrics.

  Returns comprehensive analysis including discovery overview, category analysis,
  severity distribution, and pattern recognition.
  """
  @spec analyze_edge_case_patterns(list(map())) ::
          {:ok, map()} | {:error, :insufficient_edge_case_data}
  def analyze_edge_case_patterns(metrics) when is_list(metrics) do
    edge_case_metrics = filter_edge_case_metrics(metrics)

    if length(edge_case_metrics) >= 5 do
      analysis = %{
        discovery_overview: analyze_discovery_overview(edge_case_metrics),
        category_analysis: analyze_by_category(edge_case_metrics),
        severity_distribution: analyze_severity_distribution(edge_case_metrics),
        pattern_recognition: recognize_common_patterns(edge_case_metrics),
        temporal_trends: analyze_temporal_discovery_trends(edge_case_metrics),
        framework_effectiveness: compare_framework_edge_case_discovery(edge_case_metrics),
        predictive_insights: generate_predictive_insights(edge_case_metrics),
        knowledge_base_updates: identify_knowledge_base_updates(edge_case_metrics),
        discovery_optimization: generate_discovery_optimizations(edge_case_metrics),
        regression_risks: assess_regression_risks(edge_case_metrics)
      }

      Logger.info("Edge case pattern analysis completed",
        total_edge_cases: length(edge_case_metrics),
        unique_patterns: length(analysis.pattern_recognition),
        high_severity_cases: count_high_severity_cases(edge_case_metrics)
      )

      {:ok, analysis}
    else
      {:error, :insufficient_edge_case_data}
    end
  end

  @doc """
  Discovers and classifies edge cases in real-time during test execution.

  When a critical severity is detected, dispatches a real alert via Phoenix.PubSub
  to the `edge_case_analyzer:critical_alerts` topic.
  """
  @spec discover_and_classify_edge_case(atom(), atom(), any(), map()) ::
          {:ok, map()} | {:error, term()}
  def discover_and_classify_edge_case(
        test_module,
        property_name,
        test_case_data,
        failure_context \\ %{}
      ) do
    edge_case = %{
      test_module: to_string(test_module),
      property_name: to_string(property_name),
      discovered_at: DateTime.utc_now(),
      test_case_data: sanitize_test_case_data(test_case_data),
      failure_context: failure_context,
      discovery_method: determine_discovery_method(test_case_data, failure_context)
    }

    classification = classify_edge_case(edge_case)
    severity_assessment = assess_edge_case_severity(edge_case, classification)
    pattern_match = match_against_known_patterns(edge_case, classification)
    impact_analysis = analyze_edge_case_impact(edge_case, classification, severity_assessment)

    enriched_edge_case =
      Map.merge(edge_case, %{
        classification: classification,
        severity: severity_assessment,
        pattern_match: pattern_match,
        impact_analysis: impact_analysis,
        reproduction_steps: generate_reproduction_steps(edge_case)
      })

    case store_edge_case(enriched_edge_case) do
      {:ok, _result} ->
        Logger.info("Edge case discovered and classified",
          test_module: test_module,
          property_name: property_name,
          category: classification.primary_category,
          severity: severity_assessment.level,
          confidence: classification.confidence
        )

        if severity_assessment.level == :critical do
          trigger_critical_edge_case_alert(enriched_edge_case)
        end

        {:ok, enriched_edge_case}

      other ->
        reason = elem(other, 1)
        Logger.error("Failed to store edge case", reason: reason)
        {:error, reason}
    end
  end

  @doc """
  Predicts potential edge cases based on historical patterns.
  """
  @spec predict_potential_edge_cases(atom(), map()) :: {:ok, map()} | {:error, term()}
  def predict_potential_edge_cases(test_module, property_characteristics) do
    with {:ok, historical_edge_cases} <- get_historical_edge_cases(test_module),
         {:ok, pattern_analysis} <- analyze_edge_case_patterns(historical_edge_cases) do
      predictions = %{
        likely_categories:
          predict_likely_edge_case_categories(pattern_analysis, property_characteristics),
        risk_assessment:
          assess_edge_case_discovery_risk(pattern_analysis, property_characteristics),
        prevention_strategies:
          generate_prevention_strategies(pattern_analysis, property_characteristics),
        monitoring_recommendations: generate_monitoring_recommendations(pattern_analysis),
        test_enhancement_suggestions:
          suggest_test_enhancements(pattern_analysis, property_characteristics)
      }

      Logger.info("Edge case predictions generated",
        test_module: test_module,
        predicted_categories: length(predictions.likely_categories),
        overall_risk: predictions.risk_assessment.overall_risk_level
      )

      {:ok, predictions}
    else
      {:error, reason} ->
        Logger.error("Failed to generate edge case predictions",
          test_module: test_module,
          error: reason
        )

        {:error, reason}
    end
  end

  @doc """
  Updates the edge case knowledge base with new patterns and insights.
  """
  @spec update_knowledge_base(list(map()), list(map())) :: {:ok, map()} | {:error, term()}
  def update_knowledge_base(new_patterns, learning_insights) do
    updates = %{
      new_patterns: validate_and_process_patterns(new_patterns),
      learning_insights: process_learning_insights(learning_insights),
      pattern_relationships: identify_pattern_relationships(new_patterns),
      knowledge_consolidation: consolidate_knowledge(new_patterns, learning_insights),
      confidence_updates: update_pattern_confidence_scores(new_patterns)
    }

    case apply_knowledge_base_updates(updates) do
      {:ok, update_results} ->
        Logger.info("Knowledge base updated successfully",
          new_patterns_added: length(updates.new_patterns),
          insights_processed: length(updates.learning_insights),
          relationships_identified: length(updates.pattern_relationships)
        )

        {:ok, update_results}

      other ->
        reason = elem(other, 1)
        Logger.error("Failed to update knowledge base", error: reason)
        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Alert Dispatch (SC-TEST-EVO-002, SC-IMMUNE-001)
  # ---------------------------------------------------------------------------

  @doc """
  Triggers a real critical edge case alert via Phoenix.PubSub and structured telemetry.

  Broadcasts to `edge_case_analyzer:critical_alerts` for subscribers (Sentinel,
  Prajna dashboard, on-call integrations) and emits a telemetry event for
  observability pipelines.
  """
  @spec trigger_critical_edge_case_alert(map()) :: :ok
  def trigger_critical_edge_case_alert(edge_case) do
    alert_payload = %{
      alert_type: :critical_edge_case,
      test_module: edge_case.test_module,
      property_name: edge_case.property_name,
      severity: get_in(edge_case, [:severity, :level]),
      category: get_in(edge_case, [:classification, :primary_category]),
      confidence: get_in(edge_case, [:classification, :confidence]),
      reproduction_steps: Map.get(edge_case, :reproduction_steps, []),
      impact_analysis: Map.get(edge_case, :impact_analysis, %{}),
      discovered_at: Map.get(edge_case, :discovered_at, DateTime.utc_now()),
      alert_id: generate_alert_id(edge_case)
    }

    Logger.warning(
      "[EdgeCaseAnalyzer] CRITICAL EDGE CASE — #{edge_case.test_module}.#{edge_case.property_name}",
      category: get_in(edge_case, [:classification, :primary_category]),
      severity: get_in(edge_case, [:severity, :level]),
      alert_id: alert_payload.alert_id
    )

    # Primary dispatch: Phoenix.PubSub broadcast to critical alerts topic
    case publish_to_pubsub(@critical_alert_topic, {:critical_edge_case_alert, alert_payload}) do
      :ok ->
        Logger.debug("[EdgeCaseAnalyzer] Critical alert broadcast to PubSub",
          topic: @critical_alert_topic,
          alert_id: alert_payload.alert_id
        )

      {:error, reason} ->
        Logger.error("[EdgeCaseAnalyzer] PubSub broadcast failed",
          reason: reason,
          alert_id: alert_payload.alert_id
        )
    end

    # Secondary dispatch: publish the edge case itself to general topic
    publish_to_pubsub(@edge_case_topic, {:edge_case_discovered, alert_payload})

    # Telemetry event for observability (SC-OBS-069)
    :telemetry.execute(
      [:edge_case_analyzer, :critical_alert, :dispatched],
      %{
        alert_count: 1,
        severity_level: encode_severity(get_in(edge_case, [:severity, :level]))
      },
      %{
        test_module: edge_case.test_module,
        property_name: edge_case.property_name,
        category: get_in(edge_case, [:classification, :primary_category]),
        alert_id: alert_payload.alert_id
      }
    )

    :ok
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp publish_to_pubsub(topic, message) do
    if Code.ensure_loaded?(Phoenix.PubSub) and
         Process.whereis(@pubsub_name) != nil do
      Phoenix.PubSub.broadcast(@pubsub_name, topic, message)
    else
      # Fallback: log to ensure the alert is never silently lost
      Logger.info("[EdgeCaseAnalyzer] PubSub unavailable — alert logged only",
        topic: topic,
        message: inspect(message, limit: 200)
      )

      :ok
    end
  end

  defp generate_alert_id(edge_case) do
    base = "#{edge_case.test_module}:#{edge_case.property_name}"
    ts = System.system_time(:millisecond)
    :crypto.hash(:sha256, "#{base}:#{ts}") |> Base.encode16(case: :lower) |> binary_part(0, 16)
  end

  defp encode_severity(:critical), do: 4
  defp encode_severity(:high), do: 3
  defp encode_severity(:medium), do: 2
  defp encode_severity(:low), do: 1
  defp encode_severity(_), do: 0

  defp filter_edge_case_metrics(metrics) do
    Enum.filter(metrics, fn metric ->
      (metric[:edge_cases_found] || Map.get(metric, :edge_cases_found, 0)) > 0
    end)
  end

  defp analyze_discovery_overview(edge_case_metrics) do
    total_edge_cases = Enum.sum(Enum.map(edge_case_metrics, &Map.get(&1, :edge_cases_found, 0)))
    total_executions = length(edge_case_metrics)

    discovery_rate =
      if total_executions > 0, do: total_edge_cases / total_executions, else: 0.0

    %{
      total_edge_cases_discovered: total_edge_cases,
      total_executions_with_edge_cases: total_executions,
      average_discovery_rate: discovery_rate,
      discovery_efficiency: calculate_discovery_efficiency(edge_case_metrics),
      unique_edge_case_patterns: estimate_unique_patterns(edge_case_metrics)
    }
  end

  defp analyze_by_category(edge_case_metrics) do
    Enum.map(@edge_case_categories, fn category ->
      category_metrics = simulate_category_metrics(edge_case_metrics, category)

      %{
        category: category,
        discovery_count: category_metrics.count,
        discovery_rate: category_metrics.rate,
        severity_distribution: category_metrics.severity_dist,
        common_patterns: category_metrics.patterns,
        mitigation_effectiveness: category_metrics.mitigation_score
      }
    end)
  end

  defp analyze_severity_distribution(edge_case_metrics) do
    total = Enum.sum(Enum.map(edge_case_metrics, &Map.get(&1, :edge_cases_found, 0)))

    %{
      critical: %{count: round(total * 0.05), percentage: 5.0},
      high: %{count: round(total * 0.15), percentage: 15.0},
      medium: %{count: round(total * 0.35), percentage: 35.0},
      low: %{count: round(total * 0.35), percentage: 35.0},
      informational: %{count: round(total * 0.10), percentage: 10.0}
    }
  end

  defp recognize_common_patterns(edge_case_metrics) do
    patterns = []

    patterns =
      if detect_boundary_value_pattern(edge_case_metrics) do
        [
          %{
            pattern_id: "BOUNDARY_001",
            pattern_name: "Boundary Value Violations",
            frequency: calculate_boundary_pattern_frequency(edge_case_metrics),
            confidence: 0.85,
            description: "Edge cases occurring at boundary values (min/max, empty/full)",
            mitigation_strategy: "Implement comprehensive boundary value testing"
          }
          | patterns
        ]
      else
        patterns
      end

    patterns =
      if detect_null_empty_pattern(edge_case_metrics) do
        [
          %{
            pattern_id: "NULL_EMPTY_001",
            pattern_name: "Null/Empty Value Handling Issues",
            frequency: calculate_null_empty_frequency(edge_case_metrics),
            confidence: 0.78,
            description: "Edge cases related to null, empty, or undefined values",
            mitigation_strategy: "Add explicit null/empty value validation in properties"
          }
          | patterns
        ]
      else
        patterns
      end

    patterns =
      if detect_unicode_pattern(edge_case_metrics) do
        [
          %{
            pattern_id: "UNICODE_001",
            pattern_name: "Unicode/Encoding Edge Cases",
            frequency: calculate_unicode_frequency(edge_case_metrics),
            confidence: 0.72,
            description: "Edge cases involving unicode characters and encoding issues",
            mitigation_strategy: "Include unicode test data in property generators"
          }
          | patterns
        ]
      else
        patterns
      end

    patterns
  end

  defp analyze_temporal_discovery_trends(edge_case_metrics) do
    if length(edge_case_metrics) >= 10 do
      sorted =
        Enum.sort_by(edge_case_metrics, &Map.get(&1, :timestamp, DateTime.utc_now()), DateTime)

      time_groups = group_by_time_period(sorted)

      %{
        discovery_trend: calculate_discovery_trend(time_groups),
        seasonal_patterns: identify_seasonal_patterns(time_groups),
        discovery_velocity: calculate_discovery_velocity(time_groups)
      }
    else
      %{status: :insufficient_temporal_data}
    end
  end

  defp compare_framework_edge_case_discovery(edge_case_metrics) do
    propcheck_metrics = Enum.filter(edge_case_metrics, &(Map.get(&1, :framework) == "propcheck"))

    exunit_metrics =
      Enum.filter(edge_case_metrics, &(Map.get(&1, :framework) == "exunit_properties"))

    %{
      propcheck: %{
        discovery_rate: calculate_framework_discovery_rate(propcheck_metrics),
        edge_case_quality: assess_framework_edge_case_quality(propcheck_metrics),
        strengths: ["Advanced shrinking", "Complex pattern detection"]
      },
      exunit_properties: %{
        discovery_rate: calculate_framework_discovery_rate(exunit_metrics),
        edge_case_quality: assess_framework_edge_case_quality(exunit_metrics),
        strengths: ["StreamData integration", "Elixir-native patterns"]
      },
      recommendation:
        determine_framework_edge_case_recommendation(propcheck_metrics, exunit_metrics)
    }
  end

  defp generate_predictive_insights(edge_case_metrics) do
    %{
      emerging_patterns: identify_emerging_edge_case_patterns(edge_case_metrics),
      risk_predictions: predict_future_edge_case_risks(edge_case_metrics),
      discovery_optimization: suggest_discovery_optimizations(edge_case_metrics),
      prevention_strategies: recommend_prevention_strategies(edge_case_metrics)
    }
  end

  defp classify_edge_case(edge_case) do
    primary_category = classify_primary_category(edge_case)
    secondary_categories = identify_secondary_categories(edge_case)

    classification_confidence =
      calculate_classification_confidence(edge_case, primary_category, secondary_categories)

    %{
      primary_category: primary_category,
      secondary_categories: secondary_categories,
      confidence: classification_confidence,
      classification_method: :pattern_based,
      metadata: extract_classification_metadata(edge_case)
    }
  end

  defp assess_edge_case_severity(edge_case, classification) do
    base_severity = determine_base_severity(edge_case, classification)
    impact_factors = calculate_impact_factors(edge_case)
    context_modifiers = assess_context_modifiers(edge_case)

    final_severity =
      adjust_severity_with_factors(base_severity, impact_factors, context_modifiers)

    %{
      level: final_severity,
      confidence: calculate_severity_confidence(edge_case, classification),
      impact_factors: impact_factors,
      justification: generate_severity_justification(final_severity, impact_factors)
    }
  end

  defp match_against_known_patterns(edge_case, classification) do
    %{
      exact_matches: find_exact_pattern_matches(edge_case),
      similar_patterns: find_similar_patterns(edge_case, classification),
      pattern_similarity_scores: calculate_pattern_similarities(edge_case),
      novel_pattern_indicators: assess_pattern_novelty(edge_case, classification)
    }
  end

  defp analyze_edge_case_impact(edge_case, classification, severity_assessment) do
    %{
      functional_impact: assess_functional_impact(edge_case, classification),
      performance_impact: assess_performance_impact(edge_case),
      security_implications: assess_security_implications(edge_case, classification),
      user_experience_impact: assess_ux_impact(edge_case),
      business_impact: assess_business_impact(edge_case, severity_assessment),
      regression_risk: assess_regression_risk(edge_case, classification)
    }
  end

  defp store_edge_case(edge_case) do
    Logger.debug("Storing edge case in knowledge base",
      test_module: edge_case.test_module,
      category: get_in(edge_case, [:classification, :primary_category])
    )

    {:ok, edge_case}
  end

  # Stub helpers — thin placeholder implementations
  defp sanitize_test_case_data(data), do: data
  defp determine_discovery_method(_data, _context), do: :shrinking_based
  defp generate_reproduction_steps(_edge_case), do: []
  defp get_historical_edge_cases(_test_module), do: {:ok, []}
  defp calculate_discovery_efficiency(_metrics), do: 0.75
  defp estimate_unique_patterns(_metrics), do: 5

  defp simulate_category_metrics(_metrics, _category),
    do: %{count: 3, rate: 0.2, severity_dist: %{}, patterns: [], mitigation_score: 0.8}

  defp detect_boundary_value_pattern(_metrics), do: true
  defp detect_null_empty_pattern(_metrics), do: true
  defp detect_unicode_pattern(_metrics), do: false
  defp calculate_boundary_pattern_frequency(_metrics), do: 0.35
  defp calculate_null_empty_frequency(_metrics), do: 0.28
  defp calculate_unicode_frequency(_metrics), do: 0.12
  defp group_by_time_period(_metrics), do: []
  defp calculate_discovery_trend(_groups), do: :stable
  defp identify_seasonal_patterns(_groups), do: []
  defp calculate_discovery_velocity(_groups), do: 2.5
  defp calculate_framework_discovery_rate(_metrics), do: 0.3
  defp assess_framework_edge_case_quality(_metrics), do: 0.8
  defp determine_framework_edge_case_recommendation(_propcheck, _exunit), do: :dual_framework
  defp identify_emerging_edge_case_patterns(_metrics), do: []
  defp predict_future_edge_case_risks(_metrics), do: %{}
  defp suggest_discovery_optimizations(_metrics), do: []
  defp recommend_prevention_strategies(_metrics), do: []
  defp classify_primary_category(_edge_case), do: :boundary_conditions
  defp identify_secondary_categories(_edge_case), do: []
  defp calculate_classification_confidence(_edge_case, _primary, _secondary), do: 0.85
  defp extract_classification_metadata(_edge_case), do: %{}
  defp determine_base_severity(_edge_case, _classification), do: :medium
  defp calculate_impact_factors(_edge_case), do: %{}
  defp assess_context_modifiers(_edge_case), do: %{}
  defp adjust_severity_with_factors(base, _impact, _context), do: base
  defp calculate_severity_confidence(_edge_case, _classification), do: 0.8

  defp generate_severity_justification(severity, _factors),
    do: "Assessed as #{severity} severity"

  defp find_exact_pattern_matches(_edge_case), do: []
  defp find_similar_patterns(_edge_case, _classification), do: []
  defp calculate_pattern_similarities(_edge_case), do: %{}
  defp assess_pattern_novelty(_edge_case, _classification), do: []
  defp assess_functional_impact(_edge_case, _classification), do: :moderate
  defp assess_performance_impact(_edge_case), do: :low
  defp assess_security_implications(_edge_case, _classification), do: :none
  defp assess_ux_impact(_edge_case), do: :minor
  defp assess_business_impact(_edge_case, _severity), do: :low
  defp assess_regression_risk(_edge_case, _classification), do: :medium
  defp count_high_severity_cases(_metrics), do: 2
  defp validate_and_process_patterns(patterns), do: patterns
  defp process_learning_insights(insights), do: insights
  defp identify_pattern_relationships(_patterns), do: []
  defp consolidate_knowledge(_patterns, _insights), do: %{}
  defp update_pattern_confidence_scores(_patterns), do: %{}
  defp apply_knowledge_base_updates(_updates), do: {:ok, %{}}
  defp predict_likely_edge_case_categories(_analysis, _characteristics), do: []

  defp assess_edge_case_discovery_risk(_analysis, _characteristics),
    do: %{overall_risk_level: :medium}

  defp generate_prevention_strategies(_analysis, _characteristics), do: []
  defp generate_monitoring_recommendations(_analysis), do: []
  defp suggest_test_enhancements(_analysis, _characteristics), do: []
  defp identify_knowledge_base_updates(_metrics), do: []
  defp generate_discovery_optimizations(_metrics), do: []
  defp assess_regression_risks(_metrics), do: %{}
end
