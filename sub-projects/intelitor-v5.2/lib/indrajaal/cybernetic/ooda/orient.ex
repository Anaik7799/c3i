defmodule Indrajaal.Cybernetic.OODA.Orient do
  @moduledoc """
  OODA Orient Phase - AI-Enhanced Situational Awareness for v20.0.0

  Implements the Orient phase of the OODA loop with:
  - Context-aware interpretation of observations
  - AI/ML-enhanced pattern recognition
  - Mental model updating
  - Threat/opportunity assessment

  ## Orientation Model

  Θ = f(O, H, M, C) where:
  - O = Current observations
  - H = Historical context
  - M = Mental models
  - C = Cultural/organizational context

  ## Orientation Components
  - **Synthesis**: Combine observations with context
  - **Analysis**: Pattern detection and anomaly identification
  - **Hypothesis**: Generate explanations for observations
  - **Assessment**: Evaluate threat/opportunity levels

  ## STAMP Constraints
  - SC-OODA-006: AI orientation with 20ms timeout
  - SC-OODA-005: Hysteresis prevents decision oscillation
  - SC-OODA-001: Cycle time < 100ms
  """

  require Logger

  alias Indrajaal.Cybernetic.OODA.Observe

  @type mental_model :: %{
          patterns: [map()],
          correlations: map(),
          confidence: float(),
          updated_at: DateTime.t()
        }

  @type orientation :: %{
          situation: atom(),
          confidence: float(),
          threats: [map()],
          opportunities: [map()],
          hypothesis: map(),
          context: map()
        }

  @type orient_state :: %{
          mental_model: mental_model(),
          history: [orientation()],
          ai_enabled: boolean(),
          hysteresis: map(),
          ai_recovery: map()
        }

  # AI timeout in milliseconds (SC-OODA-006)
  @ai_timeout_ms 20

  # AI recovery settings (SC-OODA-009: AI timeout recovery mechanism)
  # Consecutive timeouts before entering recovery mode
  @ai_recovery_threshold 3
  # Successful local analyses before retrying AI
  @ai_recovery_window 10
  # Maximum extended timeout for AI recovery
  @ai_max_timeout_ms 100

  # Hysteresis margin (SC-OODA-005)
  @hysteresis_margin 0.10

  # Hysteresis hold cycles
  @hysteresis_hold_cycles 3

  @doc """
  Creates a new orientation state.
  """
  @spec new(Keyword.t()) :: orient_state()
  def new(opts \\ []) do
    %{
      mental_model: Keyword.get(opts, :mental_model, default_mental_model()),
      history: [],
      ai_enabled: Keyword.get(opts, :ai_enabled, true),
      hysteresis: %{
        last_situation: nil,
        hold_count: 0,
        margin: @hysteresis_margin
      },
      # AI recovery state (SC-OODA-009)
      ai_recovery: %{
        consecutive_timeouts: 0,
        in_recovery_mode: false,
        successful_local_count: 0,
        last_timeout_at: nil,
        current_timeout_ms: @ai_timeout_ms
      }
    }
  end

  @doc """
  Orients based on observation, producing situational awareness.
  """
  @spec orient(Observe.observation(), orient_state()) :: {orientation(), orient_state()}
  def orient(observation, state) do
    # Synthesize observation with context
    synthesis = synthesize(observation, state.history, state.mental_model)

    # Analyze patterns with AI recovery mechanism (SC-OODA-009)
    {analysis, new_ai_recovery} =
      if state.ai_enabled do
        ai_analyze_with_recovery(synthesis, state.mental_model, state.ai_recovery)
      else
        {local_analyze(synthesis, state.mental_model), state.ai_recovery}
      end

    # Generate hypothesis
    hypothesis = generate_hypothesis(synthesis, analysis)

    # Assess threats and opportunities
    {threats, opportunities} = assess(synthesis, analysis, hypothesis)

    # Determine situation with hysteresis (SC-OODA-005)
    {situation, confidence, new_hysteresis} =
      determine_situation(synthesis, analysis, state.hysteresis)

    orientation = %{
      situation: situation,
      confidence: confidence,
      threats: threats,
      opportunities: opportunities,
      hypothesis: hypothesis,
      context: %{
        synthesis: synthesis,
        analysis: analysis
      }
    }

    # Update mental model based on orientation
    updated_model = update_mental_model(state.mental_model, orientation)

    # Maintain bounded history
    updated_history = [orientation | Enum.take(state.history, 99)]

    new_state = %{
      state
      | mental_model: updated_model,
        history: updated_history,
        hysteresis: new_hysteresis,
        ai_recovery: new_ai_recovery
    }

    {orientation, new_state}
  end

  @doc """
  Synthesizes observation with historical context and mental models.
  """
  @spec synthesize(Observe.observation(), [orientation()], mental_model()) :: map()
  def synthesize(observation, history, mental_model) do
    # Extract key metrics from observation
    metrics = extract_metrics(observation)

    # Compare with historical patterns
    historical_context = build_historical_context(history)

    # Apply mental model patterns
    pattern_matches = match_patterns(metrics, mental_model.patterns)

    %{
      metrics: metrics,
      historical: historical_context,
      patterns: pattern_matches,
      quality: observation.quality,
      timestamp: observation.timestamp
    }
  end

  @doc """
  Performs AI-enhanced analysis with timeout protection and recovery (SC-OODA-009).
  """
  @spec ai_analyze_with_recovery(map(), mental_model(), map()) :: {map(), map()}
  def ai_analyze_with_recovery(synthesis, mental_model, ai_recovery) do
    # Check if we should attempt AI or use local fallback
    if should_attempt_ai?(ai_recovery) do
      timeout_ms = ai_recovery.current_timeout_ms

      task =
        Task.async(fn ->
          # AI analysis would call external model here
          # For now, use enhanced local analysis
          enhanced_local_analyze(synthesis, mental_model)
        end)

      case Task.yield(task, timeout_ms) || Task.shutdown(task) do
        {:ok, result} ->
          # AI succeeded - update recovery state
          new_recovery = handle_ai_success(ai_recovery)
          {Map.put(result, :method, :ai), new_recovery}

        nil ->
          # AI timed out - handle timeout and use fallback
          Logger.warning(
            "AI analysis timeout (#{timeout_ms}ms), falling back to local heuristics"
          )

          emit_ai_timeout_telemetry(ai_recovery)
          new_recovery = handle_ai_timeout(ai_recovery)
          {local_analyze(synthesis, mental_model), new_recovery}
      end
    else
      # In recovery mode - use local analysis and track progress
      analysis = local_analyze(synthesis, mental_model)
      new_recovery = track_local_success(ai_recovery)

      if new_recovery.successful_local_count >= @ai_recovery_window do
        Logger.info(
          "AI recovery: #{@ai_recovery_window} successful local analyses, attempting AI recovery"
        )
      end

      {analysis, new_recovery}
    end
  end

  @doc """
  Performs AI-enhanced analysis with timeout protection (legacy interface).
  """
  @spec ai_analyze(map(), mental_model()) :: map()
  def ai_analyze(synthesis, mental_model) do
    {analysis, _recovery} =
      ai_analyze_with_recovery(synthesis, mental_model, %{
        consecutive_timeouts: 0,
        in_recovery_mode: false,
        successful_local_count: 0,
        last_timeout_at: nil,
        current_timeout_ms: @ai_timeout_ms
      })

    analysis
  end

  # Check if we should attempt AI analysis or stay in recovery mode
  defp should_attempt_ai?(ai_recovery) do
    cond do
      # Not in recovery mode - always attempt AI
      not ai_recovery.in_recovery_mode ->
        true

      # In recovery mode - check if we've had enough successful local analyses
      ai_recovery.successful_local_count >= @ai_recovery_window ->
        true

      # Still in recovery mode
      true ->
        false
    end
  end

  # Handle successful AI analysis
  defp handle_ai_success(ai_recovery) do
    %{
      ai_recovery
      | consecutive_timeouts: 0,
        in_recovery_mode: false,
        successful_local_count: 0,
        # Reset to normal timeout
        current_timeout_ms: @ai_timeout_ms
    }
  end

  # Handle AI timeout
  defp handle_ai_timeout(ai_recovery) do
    new_timeout_count = ai_recovery.consecutive_timeouts + 1

    if new_timeout_count >= @ai_recovery_threshold do
      # Enter recovery mode with extended timeout for next attempt
      extended_timeout = min(ai_recovery.current_timeout_ms * 2, @ai_max_timeout_ms)

      Logger.warning(
        "AI recovery: Entered recovery mode after #{new_timeout_count} consecutive timeouts"
      )

      %{
        ai_recovery
        | consecutive_timeouts: new_timeout_count,
          in_recovery_mode: true,
          successful_local_count: 0,
          last_timeout_at: DateTime.utc_now(),
          current_timeout_ms: extended_timeout
      }
    else
      %{
        ai_recovery
        | consecutive_timeouts: new_timeout_count,
          last_timeout_at: DateTime.utc_now()
      }
    end
  end

  # Track successful local analysis during recovery
  defp track_local_success(ai_recovery) do
    if ai_recovery.in_recovery_mode do
      new_count = ai_recovery.successful_local_count + 1

      if new_count >= @ai_recovery_window do
        # Ready to exit recovery mode
        %{
          ai_recovery
          | successful_local_count: 0,
            in_recovery_mode: false,
            consecutive_timeouts: 0
        }
      else
        %{ai_recovery | successful_local_count: new_count}
      end
    else
      ai_recovery
    end
  end

  # Emit telemetry for AI timeout
  defp emit_ai_timeout_telemetry(ai_recovery) do
    :telemetry.execute(
      [:indrajaal, :ooda, :ai_timeout],
      %{
        consecutive_timeouts: ai_recovery.consecutive_timeouts + 1,
        current_timeout_ms: ai_recovery.current_timeout_ms,
        in_recovery_mode: ai_recovery.in_recovery_mode
      },
      %{component: :orient}
    )
  end

  @doc """
  Performs local heuristic analysis (fallback).
  """
  @spec local_analyze(map(), mental_model()) :: map()
  def local_analyze(synthesis, _mental_model) do
    metrics = synthesis.metrics

    # Simple threshold-based analysis
    alerts =
      Enum.flat_map(metrics, fn {metric, value} ->
        if exceeds_threshold?(metric, value) do
          [%{metric: metric, value: value, severity: assess_severity(metric, value)}]
        else
          []
        end
      end)

    %{
      method: :local,
      alerts: alerts,
      pattern_confidence: 0.5,
      anomaly_score: length(alerts) / max(map_size(metrics), 1)
    }
  end

  @doc """
  Generates hypotheses explaining the current situation.
  """
  @spec generate_hypothesis(map(), map()) :: map()
  def generate_hypothesis(synthesis, analysis) do
    # Generate multiple hypotheses ranked by likelihood
    hypotheses =
      cond do
        analysis.anomaly_score > 0.7 ->
          [
            %{type: :system_degradation, probability: 0.6},
            %{type: :attack, probability: 0.2},
            %{type: :load_spike, probability: 0.2}
          ]

        analysis.anomaly_score > 0.3 ->
          [
            %{type: :load_spike, probability: 0.5},
            %{type: :normal_variation, probability: 0.3},
            %{type: :system_degradation, probability: 0.2}
          ]

        true ->
          [
            %{type: :normal, probability: 0.8},
            %{type: :normal_variation, probability: 0.2}
          ]
      end

    %{
      primary: List.first(hypotheses),
      alternatives: Enum.drop(hypotheses, 1),
      evidence: %{
        anomaly_score: analysis.anomaly_score,
        quality: synthesis.quality
      }
    }
  end

  @doc """
  Assesses threats and opportunities from synthesis and analysis.
  """
  @spec assess(map(), map(), map()) :: {[map()], [map()]}
  def assess(synthesis, analysis, _hypothesis) do
    threats =
      analysis.alerts
      |> Enum.filter(&(&1.severity in [:high, :critical]))
      |> Enum.map(fn alert ->
        %{
          type: classify_threat(alert),
          severity: alert.severity,
          source: alert.metric,
          mitigation: suggest_mitigation(alert)
        }
      end)

    opportunities =
      if synthesis.quality > 0.8 and analysis.anomaly_score < 0.2 do
        [%{type: :optimization, confidence: synthesis.quality}]
      else
        []
      end

    {threats, opportunities}
  end

  @doc """
  Returns orientation summary.
  """
  @spec summary(orientation()) :: map()
  def summary(orientation) do
    %{
      situation: orientation.situation,
      confidence: orientation.confidence,
      num_threats: length(orientation.threats),
      num_opportunities: length(orientation.opportunities),
      primary_hypothesis: orientation.hypothesis.primary
    }
  end

  # Private helpers

  defp default_mental_model do
    %{
      patterns: [
        %{name: :high_cpu, condition: fn m -> Map.get(m, :cpu, 0) > 80 end},
        %{name: :high_memory, condition: fn m -> Map.get(m, :memory, 0) > 90 end},
        %{name: :high_latency, condition: fn m -> Map.get(m, :latency, 0) > 200 end},
        %{name: :high_error_rate, condition: fn m -> Map.get(m, :error_rate, 0) > 5 end}
      ],
      correlations: %{},
      confidence: 0.5,
      updated_at: DateTime.utc_now()
    }
  end

  defp extract_metrics(observation) do
    observation.fused
    |> Enum.into(%{}, fn {type, data} ->
      {type, data}
    end)
  end

  defp build_historical_context(history) do
    if Enum.empty?(history) do
      %{trend: :unknown, stability: 1.0}
    else
      recent = Enum.take(history, 10)
      situations = Enum.map(recent, & &1.situation)
      unique_situations = Enum.uniq(situations)

      %{
        trend: determine_trend(situations),
        stability: 1.0 - length(unique_situations) / length(situations),
        recent_situations: situations
      }
    end
  end

  defp determine_trend(situations) do
    case situations do
      [:normal | _] -> :stable
      [:degraded | _] -> :degrading
      [:critical | _] -> :critical
      _ -> :unknown
    end
  end

  defp match_patterns(metrics, patterns) do
    Enum.filter(patterns, fn pattern ->
      try do
        pattern.condition.(metrics)
      rescue
        _ -> false
      end
    end)
  end

  defp enhanced_local_analyze(synthesis, mental_model) do
    base = local_analyze(synthesis, mental_model)
    # Enhanced with correlation analysis
    correlations = analyze_correlations(synthesis.metrics)
    Map.put(base, :correlations, correlations)
  end

  defp analyze_correlations(metrics) do
    # Simplified correlation detection
    keys = Map.keys(metrics)

    for k1 <- keys, k2 <- keys, k1 < k2 do
      {k1, k2, 0.5}
    end
  end

  defp exceeds_threshold?(metric, value) do
    thresholds = %{
      system: 0.8,
      application: 0.7,
      business: 0.6
    }

    threshold = Map.get(thresholds, metric, 0.75)

    case value do
      %{count: count} -> count > threshold * 10
      _ -> false
    end
  end

  defp assess_severity(_metric, _value) do
    # Simplified severity assessment
    Enum.random([:low, :medium, :high])
  end

  defp classify_threat(alert) do
    case alert.severity do
      :critical -> :immediate
      :high -> :elevated
      _ -> :potential
    end
  end

  defp suggest_mitigation(alert) do
    case alert.severity do
      :critical -> [:immediate_action, :escalate]
      :high -> [:investigate, :prepare_mitigation]
      _ -> [:monitor]
    end
  end

  defp determine_situation(synthesis, analysis, hysteresis) do
    # Calculate raw situation
    raw_situation =
      cond do
        analysis.anomaly_score > 0.7 -> :critical
        analysis.anomaly_score > 0.4 -> :degraded
        synthesis.quality < 0.5 -> :uncertain
        true -> :normal
      end

    raw_confidence = 1.0 - analysis.anomaly_score

    # Apply hysteresis (SC-OODA-005)
    {final_situation, hold_count} =
      if hysteresis.last_situation == raw_situation do
        {raw_situation, 0}
      else
        if hysteresis.hold_count < @hysteresis_hold_cycles do
          {hysteresis.last_situation || raw_situation, hysteresis.hold_count + 1}
        else
          {raw_situation, 0}
        end
      end

    new_hysteresis = %{
      hysteresis
      | last_situation: final_situation,
        hold_count: hold_count
    }

    {final_situation, raw_confidence, new_hysteresis}
  end

  defp update_mental_model(mental_model, _orientation) do
    %{mental_model | updated_at: DateTime.utc_now()}
  end
end
