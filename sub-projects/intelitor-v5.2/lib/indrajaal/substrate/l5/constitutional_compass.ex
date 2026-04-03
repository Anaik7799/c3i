defmodule Indrajaal.Substrate.L5.ConstitutionalCompass do
  @moduledoc """
  L5 Constitutional Compass — Constitutional alignment checker.

  Evaluates proposed actions against the holon's immutable constitutional
  axioms (L0 Ψ-principles). Each axiom carries a criticality weight; the
  overall alignment score is a weighted harmonic mean across all evaluated
  axioms.

  Algorithm:
  - Alignment score per axiom: 0.0 (violates) to 1.0 (fully aligned)
  - Composite: weighted harmonic mean prevents high scores masking zero axioms
  - Verdict: :aligned (>=0.85), :caution (>=0.70), :blocked (<0.70)

  ## STAMP Constraints
  - SC-S5-001: Cybernetic VSM S5 policy identity — ENFORCED
  - SC-SAFETY-001: Guardian pre-approval for mutations — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @min_score 0.0
  @aligned_threshold 0.85
  @caution_threshold 0.70

  @type axiom_id :: atom()
  @type verdict :: :aligned | :caution | :blocked

  @type evaluation :: %{
          axiom: axiom_id(),
          score: float(),
          weight: float(),
          note: String.t()
        }

  @type t :: %__MODULE__{
          context: String.t(),
          evaluations: [evaluation()],
          composite: float(),
          verdict: verdict()
        }

  defstruct context: "default",
            evaluations: [],
            composite: 1.0,
            verdict: :aligned

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    context = Keyword.get(opts, :context, "default")

    cond do
      not is_binary(context) ->
        {:error, "context must be a string"}

      true ->
        {:ok, %__MODULE__{context: context}}
    end
  end

  @spec evaluate_axiom(t(), axiom_id(), float(), float(), String.t()) ::
          {:ok, t()} | {:error, String.t()}
  def evaluate_axiom(%__MODULE__{} = state, axiom, score, weight, note)
      when is_atom(axiom) and is_number(score) and is_number(weight) and is_binary(note) do
    cond do
      score < @min_score or score > 1.0 ->
        {:error, "score must be in [0.0, 1.0]"}

      weight <= 0.0 ->
        {:error, "weight must be positive"}

      true ->
        entry = %{
          axiom: axiom,
          score: Float.round(score / 1.0, 4),
          weight: Float.round(weight / 1.0, 4),
          note: note
        }

        existing = Enum.reject(state.evaluations, &(&1.axiom == axiom))
        updated = %{state | evaluations: existing ++ [entry]}
        {:ok, recompute(updated)}
    end
  end

  @spec verdict(t()) :: verdict()
  def verdict(%__MODULE__{verdict: v}), do: v

  @spec blocking_axioms(t()) :: [axiom_id()]
  def blocking_axioms(%__MODULE__{evaluations: evals}) do
    evals
    |> Enum.filter(&(&1.score < @caution_threshold))
    |> Enum.map(& &1.axiom)
  end

  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    %{
      context: state.context,
      composite: state.composite,
      verdict: state.verdict,
      axiom_count: length(state.evaluations),
      blocking: blocking_axioms(state)
    }
  end

  # ── Private ──────────────────────────────────────────────────────────

  defp recompute(%__MODULE__{evaluations: []} = state) do
    %{state | composite: 1.0, verdict: :aligned}
  end

  defp recompute(%__MODULE__{evaluations: evals} = state) do
    # Weighted harmonic mean: 1 / Σ(w_i / score_i) * Σ(w_i)
    total_weight = Enum.reduce(evals, 0.0, fn e, acc -> acc + e.weight end)

    harmonic_denom =
      Enum.reduce(evals, 0.0, fn e, acc ->
        if e.score > 0.0, do: acc + e.weight / e.score, else: acc + e.weight / 0.001
      end)

    composite =
      if harmonic_denom == 0.0 do
        0.0
      else
        Float.round(total_weight / harmonic_denom, 4)
      end

    verdict =
      cond do
        composite >= @aligned_threshold -> :aligned
        composite >= @caution_threshold -> :caution
        true -> :blocked
      end

    %{state | composite: composite, verdict: verdict}
  end
end
