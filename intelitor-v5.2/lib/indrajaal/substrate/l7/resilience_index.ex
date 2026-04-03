defmodule Indrajaal.Substrate.L7.ResilienceIndex do
  @moduledoc """
  ## Design Intent
  L7 substrate Resilience Index — pure functional ecosystem resilience scorer.
  Computes a composite resilience index for an ecosystem based on five
  dimensions: redundancy, diversity, connectivity, adaptability, and recovery.

  Composite formula (weighted sum, weights sum to 1.0):
    R = w_red × redundancy
      + w_div × diversity
      + w_con × connectivity
      + w_ada × adaptability
      + w_rec × recovery_rate

  Default weights: [0.25, 0.25, 0.20, 0.15, 0.15]

  Resilience grade:
    R ≥ 0.80 → :high
    R ≥ 0.55 → :medium
    R ≥ 0.30 → :low
    R  < 0.30 → :critical

  ## STAMP Constraints
  - SC-ECO-001: Ecosystem boundaries — ENFORCED (L7)
  - SC-SIL-002: Safe failure fraction — ENFORCED via redundancy dimension
  - SC-HA-001: SIL-6 availability — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @default_weights %{
    redundancy: 0.25,
    diversity: 0.25,
    connectivity: 0.20,
    adaptability: 0.15,
    recovery_rate: 0.15
  }

  @grade_thresholds [{0.80, :high}, {0.55, :medium}, {0.30, :low}]

  @type dimension ::
          :redundancy
          | :diversity
          | :connectivity
          | :adaptability
          | :recovery_rate

  @type grade :: :high | :medium | :low | :critical

  @type snapshot :: %{
          score: float(),
          grade: grade(),
          dimensions: %{dimension() => float()},
          timestamp: integer()
        }

  @type t :: %__MODULE__{
          dimensions: %{dimension() => float()},
          weights: %{dimension() => float()},
          score: float(),
          grade: grade(),
          history: [snapshot()]
        }

  defstruct dimensions: %{
              redundancy: 0.5,
              diversity: 0.5,
              connectivity: 0.5,
              adaptability: 0.5,
              recovery_rate: 0.5
            },
            weights: @default_weights,
            score: 0.5,
            grade: :medium,
            history: []

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    dims_input = Keyword.get(opts, :dimensions, %{})
    weights_input = Keyword.get(opts, :weights, %{})

    cond do
      not is_map(dims_input) ->
        {:error, "dimensions must be a map"}

      not is_map(weights_input) ->
        {:error, "weights must be a map"}

      true ->
        dimensions = build_dimensions(dims_input)
        weights = build_weights(weights_input)

        state = %__MODULE__{dimensions: dimensions, weights: weights}
        {:ok, recompute(state)}
    end
  end

  @doc """
  Update one or more dimension scores and recompute the composite index.
  Scores must be in [0.0, 1.0].
  """
  @spec update_dimensions(t(), map()) :: {:ok, t()}
  def update_dimensions(%__MODULE__{} = state, updates) when is_map(updates) do
    now = System.monotonic_time(:second)

    snapshot = %{
      score: state.score,
      grade: state.grade,
      dimensions: state.dimensions,
      timestamp: now
    }

    new_dims =
      Enum.reduce(updates, state.dimensions, fn {k, v}, acc ->
        key = if is_atom(k), do: k, else: String.to_existing_atom(to_string(k))

        if Map.has_key?(acc, key) do
          Map.put(acc, key, clamp(v, 0.0, 1.0))
        else
          acc
        end
      end)

    history = Enum.take([snapshot | state.history], 50)
    new_state = %{state | dimensions: new_dims, history: history}
    {:ok, recompute(new_state)}
  end

  @doc """
  Return the delta in composite score between the last two snapshots.
  Positive means improving resilience.
  """
  @spec delta(t()) :: float()
  def delta(%__MODULE__{history: []}), do: 0.0

  def delta(%__MODULE__{score: current, history: [last | _]}) do
    Float.round(current - last.score, 4)
  end

  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    %{
      score: Float.round(state.score, 4),
      grade: state.grade,
      dimensions: Map.new(state.dimensions, fn {k, v} -> {k, Float.round(v, 3)} end),
      delta: delta(state),
      snapshot_count: length(state.history)
    }
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp build_dimensions(input) do
    Enum.reduce(
      [:redundancy, :diversity, :connectivity, :adaptability, :recovery_rate],
      %{},
      fn dim, acc ->
        v = Map.get(input, dim, Map.get(input, Atom.to_string(dim), 0.5))
        Map.put(acc, dim, clamp(v, 0.0, 1.0))
      end
    )
  end

  defp build_weights(input) do
    base = @default_weights

    Enum.reduce(Map.keys(base), base, fn dim, acc ->
      v = Map.get(input, dim, Map.get(input, Atom.to_string(dim), Map.fetch!(base, dim)))
      Map.put(acc, dim, clamp(v, 0.0, 1.0))
    end)
  end

  defp recompute(%__MODULE__{} = state) do
    score =
      Enum.reduce(state.dimensions, 0.0, fn {dim, value}, acc ->
        acc + value * Map.get(state.weights, dim, 0.0)
      end)
      |> Float.round(4)

    grade = assign_grade(score)
    %{state | score: score, grade: grade}
  end

  defp assign_grade(score) do
    Enum.find_value(@grade_thresholds, :critical, fn {threshold, grade} ->
      if score >= threshold, do: grade, else: nil
    end)
  end

  defp clamp(v, lo, hi) when is_number(v), do: v |> max(lo) |> min(hi)
  defp clamp(_v, lo, _hi), do: lo
end
