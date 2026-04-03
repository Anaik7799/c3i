defmodule Indrajaal.Substrate.L7.SuccessionModel do
  @moduledoc """
  ## Design Intent
  L7 substrate Succession Model — pure functional ecological succession stages.
  Models the progression of a holon or ecosystem through successional phases,
  analogous to ecological succession (pioneer → intermediate → climax community).

  Succession stages (ordinal):
    :pioneer → :early_secondary → :late_secondary → :climax → :disturbance

  Transition conditions are scored via a resilience-weighted readiness index.
  Regression (disturbance) can occur when resilience drops below a threshold.

  Readiness formula:
    readiness = (stability × diversity) / max(stress, 0.01)

  ## STAMP Constraints
  - SC-ECO-001: Ecosystem boundaries — ENFORCED (L7)
  - SC-ECO-003: External system integration boundaries — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @stages [:pioneer, :early_secondary, :late_secondary, :climax, :disturbance]
  @stage_order %{
    pioneer: 0,
    early_secondary: 1,
    late_secondary: 2,
    climax: 3,
    disturbance: -1
  }
  @advance_threshold 0.65
  @disturbance_threshold 0.2

  @type stage ::
          :pioneer
          | :early_secondary
          | :late_secondary
          | :climax
          | :disturbance

  @type t :: %__MODULE__{
          stage: stage(),
          stability: float(),
          diversity: float(),
          stress: float(),
          readiness: float(),
          transitions: non_neg_integer()
        }

  defstruct stage: :pioneer,
            stability: 0.3,
            diversity: 0.2,
            stress: 0.5,
            readiness: 0.0,
            transitions: 0

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    stage = Keyword.get(opts, :stage, :pioneer)

    cond do
      stage not in @stages ->
        {:error, "stage must be one of #{inspect(@stages)}"}

      true ->
        stability = Keyword.get(opts, :stability, 0.3) |> clamp(0.0, 1.0)
        diversity = Keyword.get(opts, :diversity, 0.2) |> clamp(0.0, 1.0)
        stress = Keyword.get(opts, :stress, 0.5) |> clamp(0.0, 1.0)
        readiness = compute_readiness(stability, diversity, stress)

        state = %__MODULE__{
          stage: stage,
          stability: stability,
          diversity: diversity,
          stress: stress,
          readiness: readiness
        }

        {:ok, state}
    end
  end

  @doc """
  Update ecological indicators and recompute readiness.
  Returns updated state with possible stage transition.
  """
  @spec update(t(), map()) :: {:ok, t(), :advanced | :regressed | :stable}
  def update(%__MODULE__{} = state, indicators) when is_map(indicators) do
    stability = Map.get(indicators, :stability, state.stability) |> clamp(0.0, 1.0)
    diversity = Map.get(indicators, :diversity, state.diversity) |> clamp(0.0, 1.0)
    stress = Map.get(indicators, :stress, state.stress) |> clamp(0.0, 1.0)
    readiness = compute_readiness(stability, diversity, stress)

    updated = %{
      state
      | stability: stability,
        diversity: diversity,
        stress: stress,
        readiness: readiness
    }

    {next_stage, transition} = determine_transition(updated)

    if next_stage == state.stage do
      {:ok, updated, :stable}
    else
      new_state = %{updated | stage: next_stage, transitions: updated.transitions + 1}
      {:ok, new_state, transition}
    end
  end

  @doc """
  Determine the next successional stage without mutating state.
  """
  @spec next_stage(t()) :: stage()
  def next_stage(%__MODULE__{} = state) do
    {stage, _} = determine_transition(state)
    stage
  end

  @doc """
  Return the ordinal rank of the current stage (higher = more mature).
  Disturbance returns -1.
  """
  @spec maturity_rank(t()) :: integer()
  def maturity_rank(%__MODULE__{} = state) do
    Map.fetch!(@stage_order, state.stage)
  end

  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    %{
      stage: state.stage,
      maturity_rank: maturity_rank(state),
      stability: Float.round(state.stability, 3),
      diversity: Float.round(state.diversity, 3),
      stress: Float.round(state.stress, 3),
      readiness: Float.round(state.readiness, 3),
      transitions: state.transitions
    }
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp compute_readiness(stability, diversity, stress) do
    denom = max(stress, 0.01)
    Float.round(stability * diversity / denom, 4)
  end

  defp determine_transition(%__MODULE__{stage: stage, readiness: readiness, stress: stress}) do
    cond do
      stress > 1.0 - @disturbance_threshold ->
        {:disturbance, :regressed}

      stage == :disturbance and readiness >= @advance_threshold ->
        {:pioneer, :advanced}

      readiness >= @advance_threshold ->
        {advance(stage), :advanced}

      true ->
        {stage, :stable}
    end
  end

  defp advance(:pioneer), do: :early_secondary
  defp advance(:early_secondary), do: :late_secondary
  defp advance(:late_secondary), do: :climax
  defp advance(:climax), do: :climax
  defp advance(:disturbance), do: :pioneer

  defp clamp(v, lo, hi) when is_number(v), do: v |> max(lo) |> min(hi)
  defp clamp(_v, lo, _hi), do: lo
end
