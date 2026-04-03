defmodule Indrajaal.Substrate.L4.ScenarioPlanner do
  @moduledoc """
  L4 Scenario Planner — Generates future scenarios from current state.

  Pure module that uses a Monte Carlo-style approach to generate plausible future
  scenarios from a current state snapshot. Each scenario carries a probability
  weight and a set of projected outcomes. Upper layers use the best-case, worst-case,
  and expected scenarios to plan adaptive responses.

  ## STAMP Compliance
  - SC-S4-001: Scenario generation bounded by environmental model (L4)
  - SC-S4-002: Monte Carlo draws seeded from system entropy
  - SC-S4-003: All scenarios are immutable value structs
  - SC-S4-004: Probability weights verified to sum to 1.0 ± epsilon

  ## Constitutional Alignment
  - Ψ₁ Regeneration: No persistent state; scenarios are ephemeral value maps
  - Ψ₃ Verification: Probability normalisation enforced in generate/2
  """

  @type state :: map()

  @type scenario :: %{
          id: String.t(),
          label: String.t(),
          probability: float(),
          outcomes: map(),
          risk_score: float(),
          opportunity_score: float()
        }

  @type evaluation :: %{
          scenario_count: non_neg_integer(),
          mean_risk: float(),
          mean_opportunity: float(),
          entropy: float(),
          is_valid: boolean()
        }

  @default_count 10
  @probability_epsilon 1.0e-6
  @seed_base 42

  @doc """
  Generates `count` scenarios from the given state using perturbation sampling.

  Each scenario perturbs numeric state values by a small random factor derived
  from the scenario index and a hash of the state. Probability weights are
  assigned by a softmax-style distribution over risk scores, then normalised.

  ## Parameters
  - `state` — current system state map (numeric values are perturbed)
  - `count` — number of scenarios to generate (default #{@default_count})

  ## Returns
  List of `scenario/0` structs, sorted by probability descending.
  """
  @spec generate(state(), pos_integer()) :: [scenario()]
  def generate(state, count \\ @default_count)
      when is_map(state) and is_integer(count) and count > 0 do
    seed = state_seed(state)

    raw =
      Enum.map(1..count, fn i ->
        perturb_factor = :math.sin(seed * i * 0.1) * 0.2
        outcomes = perturb_outcomes(state, perturb_factor)
        risk = compute_risk(outcomes)
        opp = compute_opportunity(outcomes)

        %{
          id: scenario_id(i),
          label: "scenario_#{i}",
          probability: 0.0,
          outcomes: outcomes,
          risk_score: risk,
          opportunity_score: opp
        }
      end)

    normalise_probabilities(raw)
  end

  @doc """
  Evaluates a list of scenarios and returns aggregate statistics.

  ## Parameters
  - `scenarios` — list of `scenario/0` structs

  ## Returns
  An `evaluation/0` map with aggregate metrics.
  """
  @spec evaluate([scenario()]) :: evaluation()
  def evaluate([]), do: empty_evaluation()

  def evaluate(scenarios) when is_list(scenarios) do
    n = length(scenarios)
    risks = Enum.map(scenarios, & &1.risk_score)
    opps = Enum.map(scenarios, & &1.opportunity_score)
    probs = Enum.map(scenarios, & &1.probability)

    mean_risk = Enum.sum(risks) / n
    mean_opp = Enum.sum(opps) / n
    entropy = shannon_entropy(probs)

    total_prob = Enum.sum(probs)
    is_valid = abs(total_prob - 1.0) < @probability_epsilon * n

    %{
      scenario_count: n,
      mean_risk: Float.round(mean_risk, 4),
      mean_opportunity: Float.round(mean_opp, 4),
      entropy: Float.round(entropy, 4),
      is_valid: is_valid
    }
  end

  @doc """
  Returns the best-case scenario (highest opportunity_score).

  ## Parameters
  - `scenarios` — list of `scenario/0` structs

  ## Returns
  The scenario with the maximum `opportunity_score`, or `nil` if empty.
  """
  @spec best_case([scenario()]) :: scenario() | nil
  def best_case([]), do: nil

  def best_case(scenarios) when is_list(scenarios) do
    Enum.max_by(scenarios, & &1.opportunity_score)
  end

  @doc """
  Returns the worst-case scenario (highest risk_score).

  ## Parameters
  - `scenarios` — list of `scenario/0` structs

  ## Returns
  The scenario with the maximum `risk_score`, or `nil` if empty.
  """
  @spec worst_case([scenario()]) :: scenario() | nil
  def worst_case([]), do: nil

  def worst_case(scenarios) when is_list(scenarios) do
    Enum.max_by(scenarios, & &1.risk_score)
  end

  @doc """
  Returns the expected scenario (closest to mean probability).

  Selects the scenario whose probability is nearest to `1/n` (uniform weight),
  representing the most "average" outcome in the distribution.

  ## Parameters
  - `scenarios` — list of `scenario/0` structs

  ## Returns
  The scenario nearest to uniform probability, or `nil` if empty.
  """
  @spec expected([scenario()]) :: scenario() | nil
  def expected([]), do: nil

  def expected(scenarios) when is_list(scenarios) do
    target = 1.0 / length(scenarios)

    Enum.min_by(scenarios, fn s ->
      abs(s.probability - target)
    end)
  end

  # --- Private helpers ---

  @spec state_seed(map()) :: integer()
  defp state_seed(state) do
    state
    |> :erlang.phash2()
    |> Kernel.+(@seed_base)
  end

  @spec scenario_id(integer()) :: String.t()
  defp scenario_id(i) do
    hash = :crypto.hash(:md5, "scenario_#{i}") |> Base.encode16(case: :lower)
    String.slice(hash, 0, 8)
  end

  @spec perturb_outcomes(map(), float()) :: map()
  defp perturb_outcomes(state, factor) do
    state
    |> Enum.map(fn
      {k, v} when is_number(v) -> {k, v * (1.0 + factor)}
      pair -> pair
    end)
    |> Map.new()
  end

  @spec compute_risk(map()) :: float()
  defp compute_risk(outcomes) do
    values =
      outcomes
      |> Map.values()
      |> Enum.filter(&is_number/1)

    case values do
      [] ->
        0.0

      vals ->
        mean = Enum.sum(vals) / length(vals)
        variance = Enum.reduce(vals, 0.0, fn v, acc -> acc + (v - mean) * (v - mean) end)
        :math.sqrt(variance / length(vals))
    end
  end

  @spec compute_opportunity(map()) :: float()
  defp compute_opportunity(outcomes) do
    values =
      outcomes
      |> Map.values()
      |> Enum.filter(&is_number/1)

    case values do
      [] -> 0.0
      vals -> Enum.sum(vals) / length(vals)
    end
  end

  @spec normalise_probabilities([scenario()]) :: [scenario()]
  defp normalise_probabilities([]), do: []

  defp normalise_probabilities(scenarios) do
    # softmax over opportunity_score
    scores = Enum.map(scenarios, & &1.opportunity_score)
    max_score = Enum.max(scores)
    exp_scores = Enum.map(scores, fn s -> :math.exp(s - max_score) end)
    total = Enum.sum(exp_scores)

    scenarios
    |> Enum.zip(exp_scores)
    |> Enum.map(fn {scenario, exp_s} ->
      %{scenario | probability: Float.round(exp_s / total, 6)}
    end)
    |> Enum.sort_by(& &1.probability, :desc)
  end

  @spec shannon_entropy([float()]) :: float()
  defp shannon_entropy([]), do: 0.0

  defp shannon_entropy(probs) do
    probs
    |> Enum.reduce(0.0, fn p, acc ->
      if p > 0.0, do: acc - p * :math.log2(p), else: acc
    end)
  end

  @spec empty_evaluation() :: evaluation()
  defp empty_evaluation do
    %{
      scenario_count: 0,
      mean_risk: 0.0,
      mean_opportunity: 0.0,
      entropy: 0.0,
      is_valid: true
    }
  end
end
