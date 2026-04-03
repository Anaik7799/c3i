defmodule Indrajaal.Substrate.L5.EthicalCompass do
  @moduledoc """
  L5 Ethical Compass — Value alignment scorer for the identity and policy layer.

  Scores proposed actions against a registered value set using weighted
  alignment vectors. Each value has a priority weight; misalignment penalties
  are proportional to both weight and severity of conflict.

  Value axes tracked (default set):
  - :human_welfare — benefit to humans
  - :fairness — equitable treatment
  - :transparency — openness and explainability
  - :autonomy_preservation — preserving human agency
  - :harm_avoidance — preventing negative outcomes
  - :sustainability — long-term viability

  Alignment score ∈ [0.0, 1.0]; score ≥ 0.7 is considered aligned.

  ## STAMP Constraints
  - SC-S5-001: Cybernetic VSM S5 policy — ENFORCED
  - SC-SAFETY-013: Ψ₄ Human alignment verified — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type value_axis ::
          :human_welfare
          | :fairness
          | :transparency
          | :autonomy_preservation
          | :harm_avoidance
          | :sustainability
          | atom()

  @type value_entry :: %{
          axis: value_axis(),
          weight: float(),
          description: String.t()
        }

  @type alignment_result :: %{
          score: float(),
          aligned: boolean(),
          axis_scores: map(),
          evaluated_at: DateTime.t()
        }

  @type t :: %__MODULE__{
          values: [value_entry()],
          alignment_threshold: float(),
          label: String.t()
        }

  defstruct values: [],
            alignment_threshold: 0.7,
            label: "default"

  @default_values [
    %{axis: :human_welfare, weight: 1.0, description: "Benefit to human beings"},
    %{axis: :fairness, weight: 0.9, description: "Equitable treatment of all parties"},
    %{axis: :transparency, weight: 0.8, description: "Openness and explainability"},
    %{axis: :autonomy_preservation, weight: 0.85, description: "Preserving human agency"},
    %{axis: :harm_avoidance, weight: 1.0, description: "Preventing negative outcomes"},
    %{axis: :sustainability, weight: 0.75, description: "Long-term viability"}
  ]

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    threshold = Keyword.get(opts, :alignment_threshold, 0.7)
    label = Keyword.get(opts, :label, "default")
    use_defaults = Keyword.get(opts, :use_defaults, true)

    cond do
      not is_number(threshold) ->
        {:error, "alignment_threshold must be numeric"}

      threshold < 0.0 or threshold > 1.0 ->
        {:error, "alignment_threshold must be in [0.0, 1.0]"}

      not is_binary(label) ->
        {:error, "label must be a string"}

      true ->
        values = if use_defaults, do: @default_values, else: []
        {:ok, %__MODULE__{values: values, alignment_threshold: threshold / 1.0, label: label}}
    end
  end

  @spec add_value(t(), value_axis(), float(), String.t()) :: t()
  def add_value(%__MODULE__{} = state, axis, weight, description)
      when is_atom(axis) and is_binary(description) do
    entry = %{axis: axis, weight: clamp(weight), description: description}
    %{state | values: state.values ++ [entry]}
  end

  @spec score(t(), map()) :: alignment_result()
  def score(%__MODULE__{values: [], alignment_threshold: threshold}, _action) do
    %{score: 1.0, aligned: 1.0 >= threshold, axis_scores: %{}, evaluated_at: DateTime.utc_now()}
  end

  def score(%__MODULE__{values: values, alignment_threshold: threshold}, action)
      when is_map(action) do
    axis_scores =
      Map.new(values, fn v ->
        raw = Map.get(action, v.axis, 1.0)
        normalized = clamp(raw)
        {v.axis, Float.round(normalized, 4)}
      end)

    total_weight = Enum.sum(Enum.map(values, & &1.weight))

    weighted_sum =
      Enum.reduce(values, 0.0, fn v, acc ->
        acc + Map.get(axis_scores, v.axis, 1.0) * v.weight
      end)

    final_score = if total_weight == 0.0, do: 1.0, else: weighted_sum / total_weight

    %{
      score: Float.round(final_score, 4),
      aligned: final_score >= threshold,
      axis_scores: axis_scores,
      evaluated_at: DateTime.utc_now()
    }
  end

  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    %{
      label: state.label,
      value_count: length(state.values),
      alignment_threshold: state.alignment_threshold,
      axes: Enum.map(state.values, & &1.axis)
    }
  end

  # ── Private ──────────────────────────────────────────────────────────

  defp clamp(v) when is_number(v), do: Float.round(min(1.0, max(0.0, v / 1.0)), 4)
  defp clamp(_), do: 0.5
end
