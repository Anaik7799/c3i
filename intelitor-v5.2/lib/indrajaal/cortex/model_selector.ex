defmodule Indrajaal.Cortex.ModelSelector do
  @moduledoc """
  WHAT: Cost/latency/quality ranking engine for Cortex AI model selection.
  WHY: Decouples model selection policy from Synapse GenServer, enabling
       optimised routing by task complexity, token cost, and quality requirements.
  CONSTRAINTS: SC-OPENROUTER-001 (free models first), SC-OPENROUTER-004 (max 10 concurrent),
               SC-OPENROUTER-005 (4K context window), SC-NEURO-001 (Guardian simplex),
               SC-CTX-001 to SC-CTX-005 (context window enforcement),
               AOR-OPENROUTER-001 (free suffix), AOR-OPENROUTER-003 (cache results).

  ## Architecture

  ```
  Synapse GenServer
      │
      ▼
  ModelSelector          ◄─── this module (Cortex L3)
      │
      ├─ ComplexityRanker   — 0.0–1.0 score
      ├─ CostRanker         — token cost / free priority
      ├─ LatencyRanker      — response time budget
      └─ QualityRanker      — accuracy requirements
  ```

  ## Selection Algorithm

  1. Score task complexity (0.0 = trivial, 1.0 = maximum).
  2. Apply cost constraint: prefer `:free` models (SC-OPENROUTER-001).
  3. Apply latency budget: fast tasks use local/fast track.
  4. Apply quality floor: critical tasks require higher-quality models.
  5. Return ranked `[{model, score}]` list; caller picks first entry.

  ## Model Tiers

  | Tier     | Condition          | Strategy          |
  |----------|--------------------|-------------------|
  | :local   | complexity < 0.3   | LocalModel fast   |
  | :free    | complexity 0.3–0.7 | OpenRouter :free  |
  | :smart   | complexity > 0.7   | OpenRouter best   |
  | :premium | critical + quality | Paid model        |
  """

  require Logger

  alias Indrajaal.Cortex.SynapseOpenRouter

  @type complexity :: float()
  @type tier :: :local | :free | :smart | :premium
  @type ranking_opts :: [
          task_type: atom(),
          latency_budget_ms: pos_integer(),
          quality_floor: float(),
          force_free: boolean()
        ]

  @type ranked_model :: %{
          model: String.t(),
          tier: tier(),
          score: float(),
          estimated_cost: :free | {:paid, float()},
          estimated_latency_ms: pos_integer()
        }

  # Complexity thresholds (SC-CTX-001)
  @local_threshold 0.3
  @free_threshold 0.7

  # Default latency budgets per tier (ms)
  @latency_by_tier %{
    local: 50,
    free: 500,
    smart: 2_000,
    premium: 5_000
  }

  # Quality scores per tier (0.0–1.0)
  @quality_by_tier %{
    local: 0.5,
    free: 0.7,
    smart: 0.85,
    premium: 0.95
  }

  @doc """
  Scores and ranks available models for a given task.

  Returns models sorted by composite score (higher = better fit).

  ## Parameters
  - `complexity` — 0.0–1.0 task complexity score
  - `task_type` — atom key for task category (maps to free model selection)
  - `opts` — ranking options (see `t:ranking_opts/0`)

  ## Returns
  - `[ranked_model()]` sorted descending by score

  ## Examples

      iex> ModelSelector.rank_models(0.2, :code_analysis)
      [%{tier: :local, score: 0.9, ...}, ...]

      iex> ModelSelector.rank_models(0.8, :fmea_analysis)
      [%{tier: :smart, score: 0.85, ...}, ...]
  """
  @spec rank_models(complexity(), atom(), ranking_opts()) :: [ranked_model()]
  def rank_models(complexity, task_type \\ :general, opts \\ []) when is_float(complexity) do
    clipped = max(0.0, min(1.0, complexity))
    force_free = Keyword.get(opts, :force_free, false)
    quality_floor = Keyword.get(opts, :quality_floor, 0.0)
    latency_budget_ms = Keyword.get(opts, :latency_budget_ms, 10_000)

    candidates = build_candidates(task_type)

    candidates
    |> Enum.map(fn candidate ->
      score = compute_score(candidate, clipped, force_free, quality_floor, latency_budget_ms)
      Map.put(candidate, :score, score)
    end)
    |> Enum.filter(fn c -> c.score > 0.0 end)
    |> Enum.sort_by(& &1.score, :desc)
  end

  @doc """
  Selects the best model for a task based on complexity and requirements.

  Returns `{:ok, model_name}` or `{:error, :no_suitable_model}`.

  ## Parameters
  - `complexity` — 0.0–1.0 task complexity
  - `task_type` — atom key for model lookup
  - `opts` — `ranking_opts()`

  ## Examples

      iex> ModelSelector.select(0.5, :property_gen)
      {:ok, "meta-llama/llama-3.1-8b-instruct:free"}

      iex> ModelSelector.select(0.9, :fmea_analysis, quality_floor: 0.9)
      {:ok, "meta-llama/llama-3.1-8b-instruct:free"}
  """
  @spec select(complexity(), atom(), ranking_opts()) ::
          {:ok, String.t() | :local} | {:error, :no_suitable_model}
  def select(complexity, task_type \\ :general, opts \\ []) do
    case rank_models(complexity, task_type, opts) do
      [best | _] ->
        model =
          case best.tier do
            :local -> :local
            _ -> best.model
          end

        Logger.debug(
          "[ModelSelector] selected tier=#{best.tier} model=#{inspect(model)} " <>
            "complexity=#{Float.round(complexity, 2)} score=#{Float.round(best.score, 3)}"
        )

        {:ok, model}

      [] ->
        {:error, :no_suitable_model}
    end
  end

  @doc """
  Assesses task complexity from goal string and triage context.

  Returns a 0.0–1.0 score used by rank_models/3.

  ## Parameters
  - `goal` — string describing the goal/task
  - `context` — optional map with triage information (e.g. `%{token_count: N}`)

  ## Scoring factors
  - Token count in context
  - Presence of safety/constitutional keywords
  - Presence of formal verification keywords
  - Length/entropy of goal string
  """
  @spec assess_complexity(String.t(), map()) :: float()
  def assess_complexity(goal, context \\ %{}) when is_binary(goal) do
    token_count = Map.get(context, :token_count, 0)
    triage_score = Map.get(context, :triage_score, 0.0)

    # Factor 1: goal string complexity (length heuristic)
    length_factor = min(1.0, String.length(goal) / 500.0) * 0.2

    # Factor 2: safety/constitutional keywords
    safety_factor =
      if goal =~ ~r/guardian|constitutional|sil.?6|fmea|apoptosis/i, do: 0.3, else: 0.0

    # Factor 3: formal verification keywords
    formal_factor =
      if goal =~ ~r/agda|quint|proof|formal|verify|theorem/i, do: 0.25, else: 0.0

    # Factor 4: token count pressure
    token_factor = min(1.0, token_count / 3_000.0) * 0.15

    # Factor 5: upstream triage signal
    triage_factor = triage_score * 0.1

    raw = length_factor + safety_factor + formal_factor + token_factor + triage_factor
    Float.round(min(1.0, raw), 4)
  end

  @doc """
  Derives the model tier from a complexity score.

  ## Examples

      iex> ModelSelector.tier_for(0.1)
      :local

      iex> ModelSelector.tier_for(0.5)
      :free

      iex> ModelSelector.tier_for(0.9)
      :smart
  """
  @spec tier_for(complexity()) :: tier()
  def tier_for(complexity) when is_float(complexity) do
    cond do
      complexity < @local_threshold -> :local
      complexity < @free_threshold -> :free
      true -> :smart
    end
  end

  @doc """
  Returns all configured free models grouped by tier.
  """
  @spec model_catalogue() :: %{tier() => [String.t()]}
  def model_catalogue do
    free = SynapseOpenRouter.free_models()

    %{
      local: [:local_fast],
      free: Map.values(free) |> Enum.uniq(),
      smart: Map.values(free) |> Enum.uniq(),
      premium: []
    }
  end

  @doc """
  Returns estimated latency (ms) for a given tier.
  """
  @spec latency_estimate(tier()) :: pos_integer()
  def latency_estimate(tier), do: Map.get(@latency_by_tier, tier, 5_000)

  @doc """
  Returns quality score for a given tier (0.0–1.0).
  """
  @spec quality_score(tier()) :: float()
  def quality_score(tier), do: Map.get(@quality_by_tier, tier, 0.5)

  # ---- Private ----

  @spec build_candidates(atom()) :: [map()]
  defp build_candidates(task_type) do
    free_model = SynapseOpenRouter.model_for(task_type)

    [
      %{
        tier: :local,
        model: :local_fast,
        estimated_cost: :free,
        estimated_latency_ms: @latency_by_tier.local
      },
      %{
        tier: :free,
        model: free_model,
        estimated_cost: :free,
        estimated_latency_ms: @latency_by_tier.free
      },
      %{
        tier: :smart,
        model: free_model,
        estimated_cost: :free,
        estimated_latency_ms: @latency_by_tier.smart
      }
    ]
  end

  @spec compute_score(map(), float(), boolean(), float(), pos_integer()) :: float()
  defp compute_score(candidate, complexity, force_free, quality_floor, latency_budget_ms) do
    tier = candidate.tier

    # Disqualify if latency budget exceeded
    if candidate.estimated_latency_ms > latency_budget_ms do
      0.0
    else
      # Disqualify if quality floor not met
      quality = quality_score(tier)

      if quality < quality_floor do
        0.0
      else
        # Disqualify local if force_free and complexity above local threshold
        if force_free and tier == :local and complexity >= @local_threshold do
          0.0
        else
          base_fitness = tier_fitness(tier, complexity)
          latency_penalty = latency_penalty(candidate.estimated_latency_ms, latency_budget_ms)
          quality_bonus = quality * 0.1
          Float.round(base_fitness - latency_penalty + quality_bonus, 4)
        end
      end
    end
  end

  @spec tier_fitness(tier(), float()) :: float()
  defp tier_fitness(:local, complexity), do: max(0.0, 1.0 - complexity / @local_threshold)

  defp tier_fitness(:free, complexity) do
    cond do
      complexity < @local_threshold -> 0.5
      complexity < @free_threshold -> 1.0 - abs(complexity - 0.5) * 0.5
      true -> 0.6
    end
  end

  defp tier_fitness(:smart, complexity) do
    cond do
      complexity < @local_threshold -> 0.2
      complexity < @free_threshold -> 0.65
      true -> 1.0
    end
  end

  defp tier_fitness(:premium, complexity), do: max(0.5, complexity)

  @spec latency_penalty(pos_integer(), pos_integer()) :: float()
  defp latency_penalty(estimated, budget) when budget > 0 do
    ratio = estimated / budget
    if ratio > 1.0, do: 1.0, else: ratio * 0.1
  end

  defp latency_penalty(_, _), do: 0.0
end
