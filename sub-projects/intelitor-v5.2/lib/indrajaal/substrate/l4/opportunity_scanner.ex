defmodule Indrajaal.Substrate.L4.OpportunityScanner do
  @moduledoc """
  L4 Opportunity Scanner — Opportunity detection and scoring for adaptive intelligence.

  Continuously evaluates the environment for exploitable gaps between current
  capability and environmental demand. Each opportunity is scored across four
  axes: novelty, feasibility, strategic_fit, and time_sensitivity.

  Metaphor: The prefrontal cortex of the VSM — scanning future state space for
  actionable leverage points before competitors can exploit them.

  Scoring formula:
    opportunity_score = (novelty + feasibility + strategic_fit) × time_sensitivity

  ## STAMP Constraints
  - SC-S4-001: Cybernetic VSM S4 intelligence — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type opportunity :: %{
          id: String.t(),
          label: String.t(),
          novelty: float(),
          feasibility: float(),
          strategic_fit: float(),
          time_sensitivity: float(),
          score: float(),
          detected_at: DateTime.t()
        }

  @type t :: %__MODULE__{
          opportunities: [opportunity()],
          threshold: float(),
          label: String.t()
        }

  defstruct opportunities: [],
            threshold: 0.5,
            label: "default"

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    threshold = Keyword.get(opts, :threshold, 0.5)
    label = Keyword.get(opts, :label, "default")

    cond do
      not is_number(threshold) ->
        {:error, "threshold must be numeric"}

      threshold < 0.0 or threshold > 1.0 ->
        {:error, "threshold must be in [0.0, 1.0]"}

      not is_binary(label) ->
        {:error, "label must be a string"}

      true ->
        {:ok, %__MODULE__{threshold: threshold / 1.0, label: label}}
    end
  end

  @spec scan(t(), String.t(), map()) :: {t(), opportunity()}
  def scan(%__MODULE__{} = state, label, attrs) when is_binary(label) and is_map(attrs) do
    novelty = clamp(Map.get(attrs, :novelty, 0.5))
    feasibility = clamp(Map.get(attrs, :feasibility, 0.5))
    strategic_fit = clamp(Map.get(attrs, :strategic_fit, 0.5))
    time_sensitivity = clamp(Map.get(attrs, :time_sensitivity, 0.5))

    raw_score = (novelty + feasibility + strategic_fit) / 3.0 * time_sensitivity

    opp = %{
      id: generate_id(),
      label: label,
      novelty: novelty,
      feasibility: feasibility,
      strategic_fit: strategic_fit,
      time_sensitivity: time_sensitivity,
      score: Float.round(raw_score, 4),
      detected_at: DateTime.utc_now()
    }

    updated = %{state | opportunities: state.opportunities ++ [opp]}
    {updated, opp}
  end

  @spec viable_opportunities(t()) :: [opportunity()]
  def viable_opportunities(%__MODULE__{opportunities: opps, threshold: threshold}) do
    opps
    |> Enum.filter(fn o -> o.score >= threshold end)
    |> Enum.sort_by(& &1.score, :desc)
  end

  @spec top_opportunity(t()) :: opportunity() | nil
  def top_opportunity(%__MODULE__{} = state) do
    state
    |> viable_opportunities()
    |> List.first()
  end

  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    viable = viable_opportunities(state)
    top = top_opportunity(state)

    %{
      label: state.label,
      total_scanned: length(state.opportunities),
      viable_count: length(viable),
      threshold: state.threshold,
      top_opportunity: if(top, do: top.label, else: nil),
      top_score: if(top, do: top.score, else: nil)
    }
  end

  # ── Private ──────────────────────────────────────────────────────────

  defp clamp(v) when is_number(v), do: Float.round(min(1.0, max(0.0, v / 1.0)), 4)
  defp clamp(_), do: 0.5

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
