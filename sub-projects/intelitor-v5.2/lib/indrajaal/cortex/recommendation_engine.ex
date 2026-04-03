defmodule Indrajaal.Cortex.RecommendationEngine do
  @moduledoc """
  FMEA-Prioritized Recommendation Engine for the Cortex cognitive layer.

  WHAT: Generates AI-powered system recommendations ranked by FMEA RPN scores.
  WHY: Enables proactive system management by surfacing highest-risk issues first,
       combining domain heuristics with OpenRouter AI inference.
  CONSTRAINTS: SC-GDE-001 (Guardian validation), SC-FMEA-002 (RPN formula),
               SC-FMEA-004 (RPN ≥ 200 critical), SC-NEURO-001 (Simplex principle),
               SC-BUS-001 (async messaging), SC-SENS-001 (non-blocking).

  ## Architecture

  ```
  ┌──────────────────────────────────────────────────────────────┐
  │               RECOMMENDATION ENGINE                          │
  │                                                              │
  │  Observations ──► FMEA Scorer ──► RPN Ranker               │
  │                        │                                    │
  │                        ▼                                    │
  │               OpenRouter AI (gated)                         │
  │                        │                                    │
  │                        ▼                                    │
  │            Guardian Validation ──► Ranked Recommendations   │
  │                                          │                  │
  │                               TrainingGym + Zenoh           │
  └──────────────────────────────────────────────────────────────┘
  ```

  ## FMEA RPN Formula (SC-FMEA-002)

  RPN = Severity × Occurrence × Detection (each 1-10)
  - Severity: Impact if failure occurs
  - Occurrence: Likelihood of failure
  - Detection: Difficulty of detecting before impact

  RPN ≥ 200 = CRITICAL (SC-FMEA-004)

  ## Change History

  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 1.0.0 | 2026-03-23 | Claude Sonnet 4.6 | Initial implementation |
  """

  use GenServer
  require Logger

  alias Indrajaal.AI.OpenRouterClient
  alias Indrajaal.Safety.Guardian

  # ============================================================
  # CONSTANTS
  # ============================================================

  @ets_table :recommendation_engine_state
  @critical_rpn_threshold 200
  @default_max_recommendations 10
  @default_min_confidence 0.65
  @ai_timeout 15_000

  # ============================================================
  # TYPE DEFINITIONS
  # ============================================================

  @type observation :: %{
          domain: atom(),
          issue: String.t(),
          severity: 1..10,
          occurrence: 1..10,
          detection: 1..10,
          metadata: map()
        }

  @type recommendation :: %{
          id: String.t(),
          domain: atom(),
          issue: String.t(),
          rpn: pos_integer(),
          severity: 1..10,
          occurrence: 1..10,
          detection: 1..10,
          priority: :critical | :high | :medium | :low,
          action: String.t(),
          rationale: String.t(),
          confidence: float(),
          source: :ai | :heuristic,
          guardian_approved: boolean(),
          timestamp: DateTime.t()
        }

  @type engine_state :: %{
          recommendations: [recommendation()],
          last_run: DateTime.t() | nil,
          total_cycles: non_neg_integer(),
          ai_calls: non_neg_integer(),
          heuristic_fallbacks: non_neg_integer()
        }

  # ============================================================
  # CLIENT API
  # ============================================================

  @doc """
  Starts the RecommendationEngine GenServer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Generates FMEA-prioritized recommendations from system observations.

  ## Parameters
  - observations: List of system observations with severity/occurrence/detection
  - opts: Options (max_recommendations, min_confidence, timeout)

  ## Returns
  - {:ok, [recommendation()]} sorted by RPN descending
  - {:error, reason}
  """
  @spec recommend(
          [observation()],
          keyword()
        ) :: {:ok, [recommendation()]} | {:error, term()}
  def recommend(observations, opts \\ []) when is_list(observations) do
    GenServer.call(__MODULE__, {:recommend, observations, opts}, @ai_timeout + 5_000)
  end

  @doc """
  Returns the most recent recommendations without triggering a new cycle.
  """
  @spec get_cached_recommendations() :: [recommendation()]
  def get_cached_recommendations do
    GenServer.call(__MODULE__, :get_cached)
  end

  @doc """
  Returns engine statistics.
  """
  @spec stats() :: engine_state()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc """
  Checks if the engine is available and healthy.
  """
  @spec available?() :: boolean()
  def available? do
    case Process.whereis(__MODULE__) do
      nil -> false
      pid -> Process.alive?(pid)
    end
  end

  @doc """
  Responds to :ping for health checks.
  """
  @spec ping() :: :pong
  def ping do
    GenServer.call(__MODULE__, :ping)
  end

  # ============================================================
  # GENSERVER CALLBACKS
  # ============================================================

  @impl true
  def init(_opts) do
    Logger.info("[RecommendationEngine] Starting FMEA-prioritized recommendation engine")

    # Initialize ETS table for state persistence (Ψ₁ Regeneration)
    if :ets.whereis(@ets_table) == :undefined do
      :ets.new(@ets_table, [:named_table, :public, :set, read_concurrency: true])
    end

    state = %{
      recommendations: [],
      last_run: nil,
      total_cycles: 0,
      ai_calls: 0,
      heuristic_fallbacks: 0
    }

    persist_state(state)

    :telemetry.execute(
      [:cortex, :recommendation_engine, :started],
      %{timestamp: System.system_time(:millisecond)},
      %{}
    )

    {:ok, state}
  end

  @impl true
  def handle_call(:ping, _from, state), do: {:reply, :pong, state}

  @impl true
  def handle_call(:get_cached, _from, state) do
    {:reply, state.recommendations, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:recommend, observations, opts}, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    max_recs = Keyword.get(opts, :max_recommendations, @default_max_recommendations)
    min_confidence = Keyword.get(opts, :min_confidence, @default_min_confidence)

    Logger.info("[RecommendationEngine] Processing #{length(observations)} observations")

    # Step 1: Compute FMEA RPN scores for all observations
    scored = compute_rpn_scores(observations)

    # Step 2: Generate recommendations (AI or heuristic)
    {recommendations, ai_used} = generate_recommendations(scored, min_confidence)

    # Step 3: Sort by RPN descending (highest risk first per SC-FMEA-004)
    sorted =
      recommendations
      |> Enum.sort_by(& &1.rpn, :desc)
      |> Enum.take(max_recs)

    elapsed = System.monotonic_time(:millisecond) - start_time

    new_state = %{
      state
      | recommendations: sorted,
        last_run: DateTime.utc_now(),
        total_cycles: state.total_cycles + 1,
        ai_calls: state.ai_calls + if(ai_used, do: 1, else: 0),
        heuristic_fallbacks: state.heuristic_fallbacks + if(ai_used, do: 0, else: 1)
    }

    persist_state(new_state)
    publish_telemetry(sorted, elapsed)
    record_to_training_gym(observations, sorted, ai_used)

    {:reply, {:ok, sorted}, new_state}
  end

  # ============================================================
  # FMEA SCORING
  # ============================================================

  @spec compute_rpn_scores([observation()]) :: [{observation(), pos_integer()}]
  defp compute_rpn_scores(observations) do
    Enum.map(observations, fn obs ->
      rpn = obs.severity * obs.occurrence * obs.detection
      {obs, rpn}
    end)
  end

  # ============================================================
  # RECOMMENDATION GENERATION
  # ============================================================

  @spec generate_recommendations([{observation(), pos_integer()}], float()) ::
          {[recommendation()], boolean()}
  defp generate_recommendations(scored_observations, min_confidence) do
    # Try AI-powered recommendations first
    case try_ai_recommendations(scored_observations, min_confidence) do
      {:ok, recommendations} ->
        {recommendations, true}

      {:error, reason} ->
        Logger.warning(
          "[RecommendationEngine] AI unavailable (#{inspect(reason)}), using heuristics"
        )

        {local_recommendations(scored_observations, min_confidence), false}
    end
  end

  @spec try_ai_recommendations([{observation(), pos_integer()}], float()) ::
          {:ok, [recommendation()]} | {:error, term()}
  defp try_ai_recommendations(scored_observations, min_confidence) do
    prompt = build_recommendation_prompt(scored_observations)

    case call_openrouter(prompt, :fast) do
      {:ok, response} ->
        recommendations =
          scored_observations
          |> parse_ai_recommendations(response)
          |> Enum.filter(&(&1.confidence >= min_confidence))
          |> validate_with_guardian()

        {:ok, recommendations}

      {:error, :missing_api_key} ->
        {:error, :api_key_missing}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec call_openrouter(String.t(), atom()) :: {:ok, String.t()} | {:error, term()}
  defp call_openrouter(prompt, model_type) do
    messages = [%{role: "user", content: prompt}]
    model_id = to_string(model_type)

    case OpenRouterClient.full_pre_flight_check(__MODULE__, model_id, prompt) do
      {:ok, _} ->
        OpenRouterClient.chat(messages, model: model_type, timeout: @ai_timeout)

      :ok ->
        OpenRouterClient.chat(messages, model: model_type, timeout: @ai_timeout)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ============================================================
  # GUARDIAN VALIDATION (SC-NEURO-001)
  # ============================================================

  @spec validate_with_guardian([recommendation()]) :: [recommendation()]
  defp validate_with_guardian(recommendations) do
    Enum.map(recommendations, fn rec ->
      proposal = %{
        source: :recommendation_engine,
        target: rec.domain,
        action: rec.action,
        confidence: rec.confidence,
        rpn: rec.rpn,
        guardian_approved: false
      }

      case Guardian.validate_proposal(proposal) do
        {:ok, _validated} ->
          %{rec | guardian_approved: true}

        {:veto, _reason} ->
          Logger.debug("[RecommendationEngine] Guardian vetoed recommendation for #{rec.domain}")

          %{rec | guardian_approved: false, confidence: rec.confidence * 0.5}

        _ ->
          rec
      end
    end)
  rescue
    _ -> recommendations
  end

  # ============================================================
  # AI RESPONSE PARSING
  # ============================================================

  @spec parse_ai_recommendations([{observation(), pos_integer()}], String.t()) ::
          [recommendation()]
  defp parse_ai_recommendations(scored_observations, ai_response) do
    lines = String.split(ai_response, "\n", trim: true)

    scored_observations
    |> Enum.with_index()
    |> Enum.map(fn {{obs, rpn}, idx} ->
      # Extract relevant line from AI response or generate from observation
      action_line =
        lines
        |> Enum.at(idx, "")
        |> String.trim()
        |> case do
          "" -> heuristic_action(obs, rpn)
          line -> sanitize_action(line)
        end

      %{
        id: generate_id(obs, rpn),
        domain: obs.domain,
        issue: obs.issue,
        rpn: rpn,
        severity: obs.severity,
        occurrence: obs.occurrence,
        detection: obs.detection,
        priority: classify_priority(rpn),
        action: action_line,
        rationale: "AI-generated recommendation (RPN=#{rpn})",
        confidence: ai_confidence_from_rpn(rpn),
        source: :ai,
        guardian_approved: false,
        timestamp: DateTime.utc_now()
      }
    end)
  end

  # ============================================================
  # LOCAL HEURISTIC RECOMMENDATIONS (FALLBACK)
  # ============================================================

  @spec local_recommendations([{observation(), pos_integer()}], float()) :: [recommendation()]
  defp local_recommendations(scored_observations, _min_confidence) do
    Enum.map(scored_observations, fn {obs, rpn} ->
      %{
        id: generate_id(obs, rpn),
        domain: obs.domain,
        issue: obs.issue,
        rpn: rpn,
        severity: obs.severity,
        occurrence: obs.occurrence,
        detection: obs.detection,
        priority: classify_priority(rpn),
        action: heuristic_action(obs, rpn),
        rationale:
          "Heuristic recommendation based on RPN=#{rpn} (S#{obs.severity}×O#{obs.occurrence}×D#{obs.detection})",
        confidence: heuristic_confidence_from_rpn(rpn),
        source: :heuristic,
        guardian_approved: false,
        timestamp: DateTime.utc_now()
      }
    end)
  end

  # ============================================================
  # PROMPT BUILDING
  # ============================================================

  @spec build_recommendation_prompt([{observation(), pos_integer()}]) :: String.t()
  defp build_recommendation_prompt(scored_observations) do
    top_issues =
      scored_observations
      |> Enum.sort_by(fn {_obs, rpn} -> rpn end, :desc)
      |> Enum.take(10)
      |> Enum.map(fn {obs, rpn} ->
        "- [RPN=#{rpn}] #{obs.domain}/#{obs.issue} (S:#{obs.severity} O:#{obs.occurrence} D:#{obs.detection})"
      end)
      |> Enum.join("\n")

    """
    You are an SRE expert analyzing a safety-critical system (IEC 61508 SIL-6).
    For each issue below, provide ONE concise remediation action (imperative, <80 chars).
    Prioritize by RPN score. Format: one action per line, same order as input.

    Issues (sorted by FMEA RPN, highest risk first):
    #{top_issues}

    Provide #{length(scored_observations)} remediation actions, one per line:
    """
  end

  # ============================================================
  # HELPERS
  # ============================================================

  @spec classify_priority(pos_integer()) :: :critical | :high | :medium | :low
  defp classify_priority(rpn) when rpn >= @critical_rpn_threshold, do: :critical
  defp classify_priority(rpn) when rpn >= 100, do: :high
  defp classify_priority(rpn) when rpn >= 50, do: :medium
  defp classify_priority(_rpn), do: :low

  @spec heuristic_action(observation(), pos_integer()) :: String.t()
  defp heuristic_action(obs, rpn) when rpn >= @critical_rpn_threshold do
    "CRITICAL: Immediately investigate and remediate #{obs.issue} in #{obs.domain}"
  end

  defp heuristic_action(obs, rpn) when rpn >= 100 do
    "HIGH: Review and address #{obs.issue} in #{obs.domain} within 24h"
  end

  defp heuristic_action(obs, rpn) when rpn >= 50 do
    "MEDIUM: Schedule remediation of #{obs.issue} in #{obs.domain} this sprint"
  end

  defp heuristic_action(obs, _rpn) do
    "LOW: Monitor #{obs.issue} in #{obs.domain} for recurrence"
  end

  @spec ai_confidence_from_rpn(pos_integer()) :: float()
  defp ai_confidence_from_rpn(rpn) when rpn >= @critical_rpn_threshold, do: 0.92
  defp ai_confidence_from_rpn(rpn) when rpn >= 100, do: 0.85
  defp ai_confidence_from_rpn(rpn) when rpn >= 50, do: 0.75
  defp ai_confidence_from_rpn(_rpn), do: 0.65

  @spec heuristic_confidence_from_rpn(pos_integer()) :: float()
  defp heuristic_confidence_from_rpn(rpn) when rpn >= @critical_rpn_threshold, do: 0.80
  defp heuristic_confidence_from_rpn(rpn) when rpn >= 100, do: 0.72
  defp heuristic_confidence_from_rpn(rpn) when rpn >= 50, do: 0.65
  defp heuristic_confidence_from_rpn(_rpn), do: 0.55

  @spec generate_id(observation(), pos_integer()) :: String.t()
  defp generate_id(obs, rpn) do
    hash =
      :crypto.hash(:sha256, "#{obs.domain}:#{obs.issue}:#{rpn}")
      |> Base.encode16(case: :lower)
      |> binary_part(0, 8)

    "rec-#{hash}"
  end

  @spec sanitize_action(String.t()) :: String.t()
  defp sanitize_action(line) do
    line
    |> String.replace(~r/^\d+\.\s*/, "")
    |> String.replace(~r/^[-*]\s*/, "")
    |> String.slice(0, 200)
    |> String.trim()
  end

  # ============================================================
  # STATE PERSISTENCE (Ψ₁ Regeneration via ETS)
  # ============================================================

  @spec persist_state(engine_state()) :: true
  defp persist_state(state) do
    :ets.insert(@ets_table, {:engine_state, state})
  end

  # ============================================================
  # TELEMETRY (SC-BUS-001, SC-ZENOH-006)
  # ============================================================

  @spec publish_telemetry([recommendation()], non_neg_integer()) :: :ok
  defp publish_telemetry(recommendations, elapsed_ms) do
    critical_count = Enum.count(recommendations, &(&1.priority == :critical))
    high_count = Enum.count(recommendations, &(&1.priority == :high))
    max_rpn = recommendations |> Enum.map(& &1.rpn) |> Enum.max(fn -> 0 end)

    :telemetry.execute(
      [:cortex, :recommendation_engine, :cycle_complete],
      %{
        count: length(recommendations),
        critical: critical_count,
        high: high_count,
        max_rpn: max_rpn,
        elapsed_ms: elapsed_ms
      },
      %{}
    )

    if Code.ensure_loaded?(Indrajaal.Observability.ZenohEvolutionPublisher) do
      payload = %{
        type: :recommendation_cycle,
        count: length(recommendations),
        critical: critical_count,
        max_rpn: max_rpn,
        elapsed_ms: elapsed_ms,
        timestamp: DateTime.utc_now()
      }

      Indrajaal.Observability.ZenohEvolutionPublisher.publish_training_episode(payload)
    end

    :ok
  rescue
    _ -> :ok
  end

  # ============================================================
  # TRAINING GYM RECORDING (AOR-CAE-003)
  # ============================================================

  @spec record_to_training_gym([observation()], [recommendation()], boolean()) :: :ok
  defp record_to_training_gym(observations, recommendations, ai_used) do
    if Code.ensure_loaded?(Indrajaal.Cortex.Evolution.TrainingGym) do
      Indrajaal.Cortex.Evolution.TrainingGym.record_success(
        %{},
        :recommendation_cycle,
        %{
          observations_count: length(observations),
          recommendations_count: length(recommendations),
          ai_used: ai_used,
          critical_count: Enum.count(recommendations, &(&1.priority == :critical)),
          max_rpn: recommendations |> Enum.map(& &1.rpn) |> Enum.max(fn -> 0 end),
          timestamp: DateTime.utc_now()
        }
      )
    end

    :ok
  rescue
    _ -> :ok
  end
end
