defmodule Indrajaal.Cortex.Synapse.ModelSelector do
  @moduledoc """
  WHAT: Cost/latency/quality ranking engine scoped to the Cortex Synapse subsystem.
  WHY: Provides Synapse with a dedicated model selection facade that enforces
       SC-NEURO-002 resource bounding and SC-OPENROUTER-001 free-model preference
       without coupling the Synapse GenServer to selection policy details.
  CONSTRAINTS:
  - SC-NEURO-002: Resource bounding — hard limits on AI requests
  - SC-NEURO-001: Simplex principle — AI output MUST pass Guardian.validate_proposal/1
  - SC-OPENROUTER-001: Free models first (`:free` suffix models exclusively)
  - SC-OPENROUTER-003: Cache successful selections
  - SC-CTX-001 to SC-CTX-005: Context window enforcement
  - AOR-OPENROUTER-001: Free suffix models exclusively
  - AOR-OPENROUTER-003: Cache results

  ## Architecture

  ```
  Synapse GenServer
      │
      ▼
  Synapse.ModelSelector     ◄── this module (Cortex Synapse L2)
      │
      ├─ rank_models/2   — sorted [{model, score}] list
      ├─ select_best/2   — {:ok, model} | {:error, :no_suitable_model}
      └─ score_model/2   — composite float score for one model
  ```

  ## Scoring Dimensions

  | Dimension | Weight | Notes                             |
  |-----------|--------|-----------------------------------|
  | Cost      |  0.40  | :free > paid; SC-OPENROUTER-001   |
  | Latency   |  0.35  | ms budget vs estimated latency    |
  | Quality   |  0.25  | accuracy floor per task type      |

  ## Change History
  | Version | Date       | Author            | Change           |
  |---------|------------|-------------------|------------------|
  | 21.3.0  | 2026-03-23 | Claude Sonnet 4.6 | Initial creation |
  """

  require Logger

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type model_id :: String.t() | :local
  @type score :: float()

  @type model_candidate :: %{
          model: model_id(),
          tier: :local | :free | :smart | :premium,
          estimated_cost: :free | {:paid, float()},
          estimated_latency_ms: pos_integer()
        }

  @type ranked_model :: %{
          model: model_id(),
          tier: :local | :free | :smart | :premium,
          score: score(),
          estimated_cost: :free | {:paid, float()},
          estimated_latency_ms: pos_integer()
        }

  @type select_opts :: [
          latency_budget_ms: pos_integer(),
          quality_floor: float(),
          force_free: boolean()
        ]

  # ---------------------------------------------------------------------------
  # Constants
  # ---------------------------------------------------------------------------

  # Default latency budget used when no option is provided (ms)
  @default_latency_budget_ms 10_000

  # Known free models (SC-OPENROUTER-001)
  @free_models [
    "meta-llama/llama-3.1-8b-instruct:free",
    "meta-llama/llama-3.2-3b-instruct:free",
    "qwen/qwen-2-7b-instruct:free",
    "google/gemma-2-9b-it:free"
  ]

  # Quality scores per tier (0.0–1.0)
  @quality_by_tier %{
    local: 0.50,
    free: 0.70,
    smart: 0.85,
    premium: 0.95
  }

  # Estimated latency per tier (ms)
  @latency_by_tier %{
    local: 50,
    free: 500,
    smart: 2_000,
    premium: 5_000
  }

  # Scoring dimension weights (must sum to 1.0)
  @weight_cost 0.40
  @weight_latency 0.35
  @weight_quality 0.25

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Ranks all candidate models by composite score (cost × latency × quality).

  Returns a descending list of `ranked_model()` maps; highest score is best fit.

  ## Parameters
  - `task_type` — atom categorising the task (`:general | :code | :fmea | :formal`)
  - `opts` — `select_opts()`

  ## Examples

      iex> Indrajaal.Cortex.Synapse.ModelSelector.rank_models(:general)
      [%{tier: :free, score: 0.9, ...}, ...]

      iex> Indrajaal.Cortex.Synapse.ModelSelector.rank_models(:general, quality_floor: 0.9)
      [%{tier: :premium, ...}, ...]

  """
  @spec rank_models(atom(), select_opts()) :: [ranked_model()]
  def rank_models(task_type \\ :general, opts \\ []) do
    latency_budget_ms = Keyword.get(opts, :latency_budget_ms, @default_latency_budget_ms)
    quality_floor = Keyword.get(opts, :quality_floor, 0.0)
    force_free = Keyword.get(opts, :force_free, false)

    candidates = build_candidates(task_type)

    candidates
    |> Enum.map(fn candidate ->
      s =
        score_model(candidate, %{
          latency_budget_ms: latency_budget_ms,
          quality_floor: quality_floor,
          force_free: force_free
        })

      Map.put(candidate, :score, s)
    end)
    |> Enum.reject(fn c -> c.score <= 0.0 end)
    |> Enum.sort_by(& &1.score, :desc)
  end

  @doc """
  Selects the single best model for the given task type and options.

  Returns `{:ok, model_id()}` or `{:error, :no_suitable_model}`.

  ## Examples

      iex> Indrajaal.Cortex.Synapse.ModelSelector.select_best(:general)
      {:ok, "meta-llama/llama-3.1-8b-instruct:free"}

      iex> Indrajaal.Cortex.Synapse.ModelSelector.select_best(:code, quality_floor: 0.95)
      {:error, :no_suitable_model}

  """
  @spec select_best(atom(), select_opts()) ::
          {:ok, model_id()} | {:error, :no_suitable_model}
  def select_best(task_type \\ :general, opts \\ []) do
    case rank_models(task_type, opts) do
      [best | _] ->
        model =
          case best.tier do
            :local -> :local
            _ -> best.model
          end

        Logger.debug(
          "[Synapse.ModelSelector] selected tier=#{best.tier} model=#{inspect(model)} " <>
            "score=#{Float.round(best.score, 3)} task=#{task_type}"
        )

        {:ok, model}

      [] ->
        Logger.warning(
          "[Synapse.ModelSelector] no suitable model for task=#{task_type} opts=#{inspect(opts)}"
        )

        {:error, :no_suitable_model}
    end
  end

  @doc """
  Computes the composite score for a single model candidate.

  Returns a float in `[0.0, 1.0]`; returns `0.0` when any hard constraint is violated.

  ## Parameters
  - `candidate` — `model_candidate()` map
  - `constraints` — map with `latency_budget_ms`, `quality_floor`, `force_free`

  ## Examples

      iex> candidate = %{tier: :free, model: "meta-llama/llama-3.1-8b-instruct:free",
      ...>               estimated_cost: :free, estimated_latency_ms: 500}
      iex> Indrajaal.Cortex.Synapse.ModelSelector.score_model(candidate, %{
      ...>   latency_budget_ms: 2000, quality_floor: 0.0, force_free: false
      ...> })
      0.775

  """
  @spec score_model(model_candidate(), map()) :: float()
  def score_model(candidate, constraints) do
    latency_budget_ms = Map.get(constraints, :latency_budget_ms, @default_latency_budget_ms)
    quality_floor = Map.get(constraints, :quality_floor, 0.0)
    force_free = Map.get(constraints, :force_free, false)

    tier = candidate.tier
    quality = Map.get(@quality_by_tier, tier, 0.5)

    cond do
      # Hard constraint: latency budget exceeded
      candidate.estimated_latency_ms > latency_budget_ms ->
        0.0

      # Hard constraint: quality floor not met
      quality < quality_floor ->
        0.0

      # Hard constraint: force_free disqualifies paid models for non-local tasks
      force_free and tier in [:smart, :premium] ->
        0.0

      true ->
        cost_score = cost_dimension(candidate.estimated_cost)
        latency_score = latency_dimension(candidate.estimated_latency_ms, latency_budget_ms)
        quality_score = quality

        raw =
          cost_score * @weight_cost +
            latency_score * @weight_latency +
            quality_score * @weight_quality

        Float.round(raw, 4)
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec build_candidates(atom()) :: [model_candidate()]
  defp build_candidates(task_type) do
    free_model = pick_free_model(task_type)

    [
      %{
        tier: :local,
        model: :local,
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

  @spec pick_free_model(atom()) :: String.t()
  defp pick_free_model(task_type) do
    case task_type do
      :code -> Enum.at(@free_models, 0)
      :fmea -> Enum.at(@free_models, 1)
      :formal -> Enum.at(@free_models, 2)
      _ -> Enum.at(@free_models, 0)
    end
  end

  @spec cost_dimension(:free | {:paid, float()}) :: float()
  defp cost_dimension(:free), do: 1.0
  defp cost_dimension({:paid, amount}) when amount > 0, do: max(0.0, 1.0 - amount / 0.05)
  defp cost_dimension(_), do: 0.5

  @spec latency_dimension(pos_integer(), pos_integer()) :: float()
  defp latency_dimension(estimated_ms, budget_ms) when budget_ms > 0 do
    ratio = estimated_ms / budget_ms
    max(0.0, 1.0 - ratio)
  end

  defp latency_dimension(_, _), do: 0.0
end
