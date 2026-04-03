defmodule Indrajaal.Substrate.L5.SuccessionPlanner do
  @moduledoc """
  L5 Succession Planner — Leadership succession model for system continuity.

  Models capability succession across roles, tracking readiness scores for
  candidate successors. Used by the L5 identity layer to ensure holon continuity
  under leadership transitions and single-points-of-failure elimination.

  Algorithm:
  - Readiness score: weighted composite of capability, experience, availability
  - Succession gap: max(0, required_readiness - best_candidate_score)
  - Succession risk: CRITICAL if gap > 0.3, HIGH if gap > 0.1

  ## STAMP Constraints
  - SC-S5-001: Cybernetic VSM S5 policy identity — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @default_required_readiness 0.7
  @critical_gap 0.3
  @high_gap 0.1

  @type risk :: :low | :high | :critical

  @type candidate :: %{
          id: String.t(),
          readiness: float(),
          capability: float(),
          availability: float()
        }

  @type t :: %__MODULE__{
          role: String.t(),
          required_readiness: float(),
          candidates: [candidate()],
          gap: float(),
          risk: risk()
        }

  defstruct role: "default",
            required_readiness: @default_required_readiness,
            candidates: [],
            gap: @default_required_readiness,
            risk: :critical

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    role = Keyword.get(opts, :role, "default")
    required = Keyword.get(opts, :required_readiness, @default_required_readiness)

    cond do
      not is_binary(role) ->
        {:error, "role must be a string"}

      not is_number(required) ->
        {:error, "required_readiness must be numeric"}

      required < 0.0 or required > 1.0 ->
        {:error, "required_readiness must be in [0.0, 1.0]"}

      true ->
        state = %__MODULE__{role: role, required_readiness: required / 1.0}
        {:ok, recompute(state)}
    end
  end

  @spec add_candidate(t(), String.t(), float(), float()) :: {:ok, t()} | {:error, String.t()}
  def add_candidate(%__MODULE__{} = state, id, capability, availability)
      when is_binary(id) and is_number(capability) and is_number(availability) do
    cond do
      capability < 0.0 or capability > 1.0 ->
        {:error, "capability must be in [0.0, 1.0]"}

      availability < 0.0 or availability > 1.0 ->
        {:error, "availability must be in [0.0, 1.0]"}

      true ->
        readiness = Float.round(capability / 1.0 * 0.7 + availability / 1.0 * 0.3, 4)

        candidate = %{
          id: id,
          readiness: readiness,
          capability: capability / 1.0,
          availability: availability / 1.0
        }

        existing = Enum.reject(state.candidates, &(&1.id == id))
        updated = %{state | candidates: existing ++ [candidate]}
        {:ok, recompute(updated)}
    end
  end

  @spec best_candidate(t()) :: candidate() | nil
  def best_candidate(%__MODULE__{candidates: []}), do: nil

  def best_candidate(%__MODULE__{candidates: candidates}) do
    Enum.max_by(candidates, & &1.readiness, fn -> nil end)
  end

  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    best = best_candidate(state)

    %{
      role: state.role,
      required_readiness: state.required_readiness,
      candidate_count: length(state.candidates),
      best_candidate: if(best, do: best.id, else: nil),
      best_readiness: if(best, do: best.readiness, else: 0.0),
      gap: state.gap,
      risk: state.risk
    }
  end

  # ── Private ──────────────────────────────────────────────────────────

  defp recompute(%__MODULE__{candidates: [], required_readiness: req} = state) do
    %{state | gap: req, risk: :critical}
  end

  defp recompute(%__MODULE__{required_readiness: req} = state) do
    best_score =
      state.candidates
      |> Enum.map(& &1.readiness)
      |> Enum.max()

    gap = Float.round(max(0.0, req - best_score), 4)

    risk =
      cond do
        gap > @critical_gap -> :critical
        gap > @high_gap -> :high
        true -> :low
      end

    %{state | gap: gap, risk: risk}
  end
end
