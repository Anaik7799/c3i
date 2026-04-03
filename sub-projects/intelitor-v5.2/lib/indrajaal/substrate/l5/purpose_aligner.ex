defmodule Indrajaal.Substrate.L5.PurposeAligner do
  @moduledoc """
  L5 Purpose Aligner — Purpose-action alignment scorer for constitutional fidelity.

  Computes alignment between declared purpose statements and observed actions.
  Each action is scored against each active purpose, then aggregated into an
  overall coherence score that the L5 identity layer uses for policy enforcement.

  Algorithm:
  - Purpose-action alignment: cosine similarity of keyword vectors (simplified)
  - Coherence: geometric mean of per-purpose alignment scores
  - Drift flag: coherence below threshold for N consecutive evaluations

  ## STAMP Constraints
  - SC-S5-001: Cybernetic VSM S5 policy identity — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @default_threshold 0.65
  @drift_window 3

  @type purpose :: %{id: atom(), statement: String.t(), weight: float()}

  @type t :: %__MODULE__{
          purposes: [purpose()],
          scores: [float()],
          coherence: float(),
          threshold: float(),
          consecutive_low: non_neg_integer(),
          drifting: boolean()
        }

  defstruct purposes: [],
            scores: [],
            coherence: 1.0,
            threshold: @default_threshold,
            consecutive_low: 0,
            drifting: false

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    threshold = Keyword.get(opts, :threshold, @default_threshold)

    cond do
      not is_number(threshold) ->
        {:error, "threshold must be numeric"}

      threshold < 0.0 or threshold > 1.0 ->
        {:error, "threshold must be in [0.0, 1.0]"}

      true ->
        {:ok, %__MODULE__{threshold: threshold / 1.0}}
    end
  end

  @spec add_purpose(t(), atom(), String.t(), float()) :: {:ok, t()} | {:error, String.t()}
  def add_purpose(%__MODULE__{} = state, id, statement, weight)
      when is_atom(id) and is_binary(statement) and is_number(weight) do
    cond do
      weight <= 0.0 ->
        {:error, "weight must be positive"}

      true ->
        p = %{id: id, statement: statement, weight: weight / 1.0}
        existing = Enum.reject(state.purposes, &(&1.id == id))
        {:ok, %{state | purposes: existing ++ [p]}}
    end
  end

  @spec record_action(t(), String.t()) :: t()
  def record_action(%__MODULE__{purposes: []} = state, _action), do: state

  def record_action(%__MODULE__{purposes: purposes, threshold: threshold} = state, action)
      when is_binary(action) do
    action_tokens = tokenise(action)

    per_purpose =
      Enum.map(purposes, fn p ->
        purpose_tokens = tokenise(p.statement)
        score = similarity(action_tokens, purpose_tokens)
        {score, p.weight}
      end)

    total_weight = Enum.reduce(per_purpose, 0.0, fn {_, w}, acc -> acc + w end)

    coherence =
      if total_weight == 0.0 do
        0.0
      else
        per_purpose
        |> Enum.reduce(0.0, fn {s, w}, acc -> acc + s * w end)
        |> Kernel./(total_weight)
        |> Float.round(4)
      end

    low_count = if coherence < threshold, do: state.consecutive_low + 1, else: 0
    drifting = low_count >= @drift_window

    history = Enum.take([coherence | state.scores], 20)

    %{
      state
      | scores: history,
        coherence: coherence,
        consecutive_low: low_count,
        drifting: drifting
    }
  end

  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    %{
      purpose_count: length(state.purposes),
      coherence: state.coherence,
      threshold: state.threshold,
      drifting: state.drifting,
      consecutive_low: state.consecutive_low,
      recent_mean: mean(state.scores)
    }
  end

  # ── Private ──────────────────────────────────────────────────────────

  defp tokenise(text) do
    text
    |> String.downcase()
    |> String.split(~r/\W+/, trim: true)
    |> MapSet.new()
  end

  defp similarity(a, b) do
    intersection = MapSet.intersection(a, b) |> MapSet.size()
    union = MapSet.union(a, b) |> MapSet.size()
    if union == 0, do: 0.0, else: Float.round(intersection / union, 4)
  end

  defp mean([]), do: 0.0

  defp mean(xs) do
    Float.round(Enum.sum(xs) / length(xs), 4)
  end
end
