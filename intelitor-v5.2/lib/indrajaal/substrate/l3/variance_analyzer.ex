defmodule Indrajaal.Substrate.L3.VarianceAnalyzer do
  @moduledoc """
  ## Design Intent
  L3 substrate variance analyzer — pure functional module for statistical
  variance tracking over a sliding window of scalar observations.

  Biological metaphor: vestibular variability sensor — detects how much a
  signal is oscillating around its mean. High variance signals instability;
  low variance may indicate stagnation or lock-in.

  Algorithm (Welford online update for numerical stability):
    - Maintains count, mean, and M2 (sum of squared deviations from mean).
    - Variance = M2 / (n - 1) for sample variance (n ≥ 2).
    - Stddev = sqrt(variance).
    - Coefficient of variation (CV) = stddev / |mean| when mean ≠ 0.
    - Window mode: only the last `window_size` observations are kept.

  ## STAMP Constraints
  - SC-S3-001: Cybernetic VSM S3 control — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type t :: %__MODULE__{
          window: [float()],
          window_size: pos_integer(),
          count: non_neg_integer(),
          mean: float(),
          m2: float()
        }

  defstruct window: [],
            window_size: 100,
            count: 0,
            mean: 0.0,
            m2: 0.0

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Create a new VarianceAnalyzer.

  Options:
    - `:window_size` — maximum observations retained (default 100, min 2).
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    window_size = Keyword.get(opts, :window_size, 100)

    cond do
      not is_integer(window_size) ->
        {:error, "window_size must be an integer"}

      window_size < 2 ->
        {:error, "window_size must be >= 2"}

      true ->
        {:ok, %__MODULE__{window_size: window_size}}
    end
  end

  @doc """
  Observe a new scalar value and return the updated state.
  Uses Welford's online algorithm; evicts oldest value when window is full.
  """
  @spec observe(t(), float()) :: t()
  def observe(%__MODULE__{} = state, value) when is_float(value) or is_integer(value) do
    v = value * 1.0

    {new_count, new_mean, new_m2, new_window} =
      if state.count < state.window_size do
        # Window not full — pure online update
        {n, mean, m2} = welford_add(state.count, state.mean, state.m2, v)
        {n, mean, m2, [v | state.window]}
      else
        # Window full — evict oldest, add new
        oldest = List.last(state.window)
        trimmed = Enum.take(state.window, state.window_size - 1)

        # Recompute from remaining window
        new_window = [v | trimmed]
        {n, mean, m2} = recompute(new_window)
        _ = oldest
        {n, mean, m2, new_window}
      end

    %{state | count: new_count, mean: new_mean, m2: new_m2, window: new_window}
  end

  @doc "Observe a list of values in order."
  @spec observe_all(t(), [float()]) :: t()
  def observe_all(%__MODULE__{} = state, values) when is_list(values) do
    Enum.reduce(values, state, &observe(&2, &1))
  end

  @doc """
  Compute current statistics.
  Returns `{:ok, stats_map}` or `{:error, :insufficient_data}` when n < 2.
  """
  @spec stats(t()) :: {:ok, map()} | {:error, :insufficient_data}
  def stats(%__MODULE__{count: n}) when n < 2, do: {:error, :insufficient_data}

  def stats(%__MODULE__{} = state) do
    variance = state.m2 / (state.count - 1)
    stddev = :math.sqrt(variance)
    cv = if abs(state.mean) > 1.0e-9, do: stddev / abs(state.mean), else: 0.0

    {:ok,
     %{
       count: state.count,
       mean: Float.round(state.mean, 6),
       variance: Float.round(variance, 6),
       stddev: Float.round(stddev, 6),
       cv: Float.round(cv, 6)
     }}
  end

  @doc "Returns a summary status map."
  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    base = %{
      count: state.count,
      window_size: state.window_size,
      mean: Float.round(state.mean, 4)
    }

    case stats(state) do
      {:ok, s} -> Map.merge(base, %{variance: s.variance, stddev: s.stddev, cv: s.cv})
      {:error, :insufficient_data} -> Map.put(base, :variance, nil)
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec welford_add(non_neg_integer(), float(), float(), float()) ::
          {pos_integer(), float(), float()}
  defp welford_add(count, mean, m2, value) do
    n = count + 1
    delta = value - mean
    new_mean = mean + delta / n
    delta2 = value - new_mean
    new_m2 = m2 + delta * delta2
    {n, new_mean, new_m2}
  end

  @spec recompute([float()]) :: {non_neg_integer(), float(), float()}
  defp recompute(values) do
    Enum.reduce(values, {0, 0.0, 0.0}, fn v, {n, mean, m2} ->
      welford_add(n, mean, m2, v)
    end)
  end
end
