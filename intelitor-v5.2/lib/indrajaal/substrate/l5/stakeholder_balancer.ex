defmodule Indrajaal.Substrate.L5.StakeholderBalancer do
  @moduledoc """
  ## Design Intent
  L5 substrate stakeholder balancer — pure functional module that computes
  multi-stakeholder equilibrium scores for proposed decisions.

  Biological metaphor: ecological trophic balance — each species (stakeholder)
  has energy flow requirements; a sustainable ecosystem satisfies all at once.
  A decision that starves one group propagates collapse through the network.

  Algorithm:
    - Each stakeholder has: weight (relative influence), satisfaction function
      encoded as a `{min_score, max_score}` acceptable range.
    - `balance/2` receives a decision impact map `%{stakeholder_id => impact_score}`
      where `impact_score ∈ [-1.0, 1.0]` (positive = beneficial).
    - Satisfaction = 1.0 if impact is within range; partial credit for range proximity.
    - Equilibrium score = weighted mean satisfaction across all stakeholders.
    - Gini coefficient of satisfactions measures inequality.

  ## STAMP Constraints
  - SC-S5-001: Cybernetic VSM S5 policy — ENFORCED
  - SC-S5-002: VSM S5 identity and ethos — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type stakeholder :: %{
          weight: float(),
          min_acceptable: float(),
          max_acceptable: float()
        }

  @type balance_result :: %{
          equilibrium_score: float(),
          gini_coefficient: float(),
          unsatisfied: [String.t()],
          satisfactions: %{String.t() => float()}
        }

  @type t :: %__MODULE__{
          stakeholders: %{String.t() => stakeholder()},
          balance_count: non_neg_integer()
        }

  defstruct stakeholders: %{},
            balance_count: 0

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Create a new StakeholderBalancer.

  Options:
    - `:stakeholders` — `%{id => %{weight: float, min_acceptable: float, max_acceptable: float}}`
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    raw = Keyword.get(opts, :stakeholders, %{})

    cond do
      not is_map(raw) ->
        {:error, "stakeholders must be a map"}

      not all_stakeholders_valid?(raw) ->
        {:error, "each stakeholder needs weight > 0, min_acceptable <= max_acceptable in [-1, 1]"}

      true ->
        {:ok, %__MODULE__{stakeholders: raw}}
    end
  end

  @doc "Register or update a stakeholder."
  @spec register(t(), String.t(), float(), float(), float()) ::
          {:ok, t()} | {:error, String.t()}
  def register(%__MODULE__{} = state, id, weight, min_acc, max_acc)
      when is_binary(id) do
    cond do
      weight <= 0.0 ->
        {:error, "weight must be > 0"}

      min_acc > max_acc ->
        {:error, "min_acceptable must be <= max_acceptable"}

      min_acc < -1.0 or max_acc > 1.0 ->
        {:error, "acceptable range must be within [-1.0, 1.0]"}

      true ->
        sh = %{weight: weight, min_acceptable: min_acc, max_acceptable: max_acc}
        {:ok, %{state | stakeholders: Map.put(state.stakeholders, id, sh)}}
    end
  end

  def register(%__MODULE__{}, _id, _w, _min, _max),
    do: {:error, "id must be a string"}

  @doc """
  Compute multi-stakeholder balance for a decision impact map.

  `impacts` maps stakeholder IDs to impact scores ∈ [-1.0, 1.0].
  Unknown stakeholders in the impact map are ignored.
  Stakeholders not in the impact map receive 0.0 impact (neutral).
  """
  @spec balance(t(), %{String.t() => float()}) :: {balance_result(), t()}
  def balance(%__MODULE__{} = state, impacts) when is_map(impacts) do
    satisfactions =
      Map.new(state.stakeholders, fn {id, sh} ->
        impact = Map.get(impacts, id, 0.0)
        sat = compute_satisfaction(impact, sh.min_acceptable, sh.max_acceptable)
        {id, sat}
      end)

    eq_score = weighted_mean(satisfactions, state.stakeholders)
    gini = gini_coefficient(Map.values(satisfactions))
    unsatisfied = Enum.filter(satisfactions, fn {_k, v} -> v < 0.5 end) |> Enum.map(&elem(&1, 0))

    result = %{
      equilibrium_score: Float.round(eq_score, 4),
      gini_coefficient: Float.round(gini, 4),
      unsatisfied: unsatisfied,
      satisfactions: Map.new(satisfactions, fn {k, v} -> {k, Float.round(v, 4)} end)
    }

    {result, %{state | balance_count: state.balance_count + 1}}
  end

  @doc "Returns a summary status map."
  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    %{
      stakeholder_count: map_size(state.stakeholders),
      balance_count: state.balance_count,
      stakeholder_ids: Map.keys(state.stakeholders)
    }
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec compute_satisfaction(float(), float(), float()) :: float()
  defp compute_satisfaction(impact, min_acc, max_acc) do
    clamped = max(-1.0, min(1.0, impact))

    if clamped >= min_acc and clamped <= max_acc do
      1.0
    else
      # Partial credit: distance from nearest acceptable boundary
      dist = min(abs(clamped - min_acc), abs(clamped - max_acc))
      max(0.0, 1.0 - dist)
    end
  end

  @spec weighted_mean(%{String.t() => float()}, %{String.t() => stakeholder()}) :: float()
  defp weighted_mean(_satisfactions, stakeholders) when map_size(stakeholders) == 0, do: 0.0

  defp weighted_mean(satisfactions, stakeholders) do
    total_weight =
      stakeholders |> Map.values() |> Enum.reduce(0.0, fn s, acc -> acc + s.weight end)

    if total_weight == 0.0 do
      0.0
    else
      weighted_sum =
        Enum.reduce(satisfactions, 0.0, fn {id, sat}, acc ->
          weight = get_in(stakeholders, [id, :weight]) || 0.0
          acc + sat * weight
        end)

      weighted_sum / total_weight
    end
  end

  @spec gini_coefficient([float()]) :: float()
  defp gini_coefficient([]), do: 0.0
  defp gini_coefficient([_]), do: 0.0

  defp gini_coefficient(values) do
    n = length(values)
    sorted = Enum.sort(values)

    indexed_sum =
      sorted
      |> Enum.with_index(1)
      |> Enum.reduce(0.0, fn {v, i}, acc -> acc + (2 * i - n - 1) * v end)

    total = Enum.sum(sorted)

    if total == 0.0 do
      0.0
    else
      abs(indexed_sum) / (n * total)
    end
  end

  @spec all_stakeholders_valid?(map()) :: boolean()
  defp all_stakeholders_valid?(sh_map) do
    Enum.all?(sh_map, fn
      {_k, %{weight: w, min_acceptable: mn, max_acceptable: mx}}
      when is_float(w) and is_float(mn) and is_float(mx) ->
        w > 0.0 and mn <= mx and mn >= -1.0 and mx <= 1.0

      _ ->
        false
    end)
  end
end
