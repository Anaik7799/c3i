defmodule Indrajaal.Substrate.L7.MutualismEngine do
  @moduledoc """
  ## Design Intent
  L7 substrate Mutualism Engine — pure functional mutual benefit optimization.
  Models symbiotic relationships between ecosystem participants using Pareto-frontier
  analysis. Each relationship is scored on a give/receive balance ratio and an
  overall mutualism coefficient.

  Mutualism coefficient formula:
    μ = (benefit_a × benefit_b) / max(cost_a + cost_b, 1)

  Pareto dominance: relationship R1 dominates R2 when
    benefit_a(R1) >= benefit_a(R2) AND benefit_b(R1) >= benefit_b(R2)
    with at least one strict inequality.

  ## STAMP Constraints
  - SC-ECO-001: Ecosystem boundaries — ENFORCED (L7)
  - SC-ECO-002: External API gateway integration — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED
  - SC-S5-001: VSM S5 policy alignment — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @max_relationships 256

  @type relationship :: %{
          id: String.t(),
          participant_a: String.t(),
          participant_b: String.t(),
          benefit_a: float(),
          benefit_b: float(),
          cost_a: float(),
          cost_b: float(),
          mutualism_coefficient: float()
        }

  @type t :: %__MODULE__{
          relationships: [relationship()],
          total_mutualism: float(),
          pareto_frontier: [String.t()]
        }

  defstruct relationships: [],
            total_mutualism: 0.0,
            pareto_frontier: []

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    relationships = Keyword.get(opts, :relationships, [])

    cond do
      length(relationships) > @max_relationships ->
        {:error, "relationships exceeds max #{@max_relationships}"}

      true ->
        parsed = Enum.map(relationships, &enrich_relationship/1)
        state = %__MODULE__{relationships: parsed}
        {:ok, recompute(state)}
    end
  end

  @doc """
  Add a relationship between two participants.
  Benefits and costs must be non-negative floats.
  """
  @spec add_relationship(t(), map()) :: {:ok, t()} | {:error, String.t()}
  def add_relationship(%__MODULE__{} = state, attrs) when is_map(attrs) do
    cond do
      length(state.relationships) >= @max_relationships ->
        {:error, "max relationships reached"}

      not is_binary(Map.get(attrs, :participant_a, nil)) ->
        {:error, "participant_a must be a string"}

      not is_binary(Map.get(attrs, :participant_b, nil)) ->
        {:error, "participant_b must be a string"}

      true ->
        rel = enrich_relationship(attrs)
        new_state = %{state | relationships: [rel | state.relationships]}
        {:ok, recompute(new_state)}
    end
  end

  @doc """
  Return relationships on the Pareto frontier (non-dominated set).
  """
  @spec pareto_optimal(t()) :: [relationship()]
  def pareto_optimal(%__MODULE__{} = state) do
    frontier_ids = MapSet.new(state.pareto_frontier)
    Enum.filter(state.relationships, fn r -> MapSet.member?(frontier_ids, r.id) end)
  end

  @doc """
  Score a proposed new relationship without mutating state.
  Returns `{:ok, coefficient}` if viable (coefficient >= 0.1).
  """
  @spec evaluate(map()) :: {:ok, float()} | {:error, String.t()}
  def evaluate(attrs) when is_map(attrs) do
    benefit_a = clamp(Map.get(attrs, :benefit_a, 0.0), 0.0, 1.0)
    benefit_b = clamp(Map.get(attrs, :benefit_b, 0.0), 0.0, 1.0)
    cost_a = clamp(Map.get(attrs, :cost_a, 0.0), 0.0, 1.0)
    cost_b = clamp(Map.get(attrs, :cost_b, 0.0), 0.0, 1.0)
    coeff = mutualism_coefficient(benefit_a, benefit_b, cost_a, cost_b)

    if coeff >= 0.1 do
      {:ok, Float.round(coeff, 4)}
    else
      {:error, "mutualism coefficient #{Float.round(coeff, 4)} below viable threshold 0.1"}
    end
  end

  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    %{
      relationship_count: length(state.relationships),
      total_mutualism: Float.round(state.total_mutualism, 4),
      pareto_frontier_size: length(state.pareto_frontier),
      avg_mutualism:
        if(length(state.relationships) > 0,
          do:
            Float.round(
              state.total_mutualism / length(state.relationships),
              4
            ),
          else: 0.0
        )
    }
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp enrich_relationship(attrs) do
    benefit_a = clamp(Map.get(attrs, :benefit_a, 0.5), 0.0, 1.0)
    benefit_b = clamp(Map.get(attrs, :benefit_b, 0.5), 0.0, 1.0)
    cost_a = clamp(Map.get(attrs, :cost_a, 0.1), 0.0, 1.0)
    cost_b = clamp(Map.get(attrs, :cost_b, 0.1), 0.0, 1.0)
    coeff = mutualism_coefficient(benefit_a, benefit_b, cost_a, cost_b)
    id = Map.get(attrs, :id, random_id())

    %{
      id: id,
      participant_a: Map.get(attrs, :participant_a, "unknown_a"),
      participant_b: Map.get(attrs, :participant_b, "unknown_b"),
      benefit_a: benefit_a,
      benefit_b: benefit_b,
      cost_a: cost_a,
      cost_b: cost_b,
      mutualism_coefficient: Float.round(coeff, 4)
    }
  end

  defp mutualism_coefficient(ba, bb, ca, cb) do
    denom = max(ca + cb, 1.0e-6)
    ba * bb / denom
  end

  defp recompute(%__MODULE__{} = state) do
    total =
      Enum.reduce(state.relationships, 0.0, fn r, acc ->
        acc + r.mutualism_coefficient
      end)

    frontier = compute_pareto(state.relationships)
    %{state | total_mutualism: total, pareto_frontier: frontier}
  end

  defp compute_pareto(relationships) do
    relationships
    |> Enum.filter(fn r1 ->
      not Enum.any?(relationships, fn r2 ->
        r2.id != r1.id and
          r2.benefit_a >= r1.benefit_a and
          r2.benefit_b >= r1.benefit_b and
          (r2.benefit_a > r1.benefit_a or r2.benefit_b > r1.benefit_b)
      end)
    end)
    |> Enum.map(& &1.id)
  end

  defp clamp(v, lo, hi) when is_number(v), do: v |> max(lo) |> min(hi)
  defp clamp(_v, lo, _hi), do: lo

  defp random_id do
    :crypto.strong_rand_bytes(6) |> Base.encode16(case: :lower)
  end
end
