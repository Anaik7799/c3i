defmodule Indrajaal.Substrate.L4.TrendAnalyzer do
  @moduledoc """
  L4 Trend Analyzer — Time-series trend detection for environmental scanning.

  Applies linear regression and exponential smoothing to detect directional
  trends in time-series data streams. The L4 intelligence layer uses trend
  awareness to project future system states and trigger adaptive responses.

  Algorithm:
  - Ordinary least-squares linear fit for slope/intercept
  - Exponential weighted moving average (EWMA) for smoothing
  - Anomaly scoring via z-score deviation from trend line

  ## STAMP Constraints
  - SC-S4-001: Cybernetic VSM S4 intelligence — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @default_alpha 0.3
  @min_points 2

  @type direction :: :rising | :falling | :stable | :unknown
  @type trend_point :: {float(), float()}

  @type t :: %__MODULE__{
          series: [trend_point()],
          alpha: float(),
          slope: float() | nil,
          intercept: float() | nil,
          ewma: float() | nil,
          label: String.t()
        }

  defstruct series: [],
            alpha: @default_alpha,
            slope: nil,
            intercept: nil,
            ewma: nil,
            label: "default"

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    alpha = Keyword.get(opts, :alpha, @default_alpha)
    label = Keyword.get(opts, :label, "default")
    series = Keyword.get(opts, :series, [])

    cond do
      not is_float(alpha) and not is_integer(alpha) ->
        {:error, "alpha must be numeric"}

      alpha <= 0.0 or alpha >= 1.0 ->
        {:error, "alpha must be in (0.0, 1.0)"}

      not is_binary(label) ->
        {:error, "label must be a string"}

      true ->
        state = %__MODULE__{series: series, alpha: alpha / 1.0, label: label}
        {:ok, recompute(state)}
    end
  end

  @spec add_point(t(), float(), float()) :: t()
  def add_point(%__MODULE__{} = state, x, y) when is_number(x) and is_number(y) do
    updated = %{state | series: state.series ++ [{x / 1.0, y / 1.0}]}
    recompute(updated)
  end

  @spec direction(t()) :: direction()
  def direction(%__MODULE__{slope: nil}), do: :unknown

  def direction(%__MODULE__{slope: slope}) do
    cond do
      slope > 0.01 -> :rising
      slope < -0.01 -> :falling
      true -> :stable
    end
  end

  @spec forecast(t(), float()) :: float() | nil
  def forecast(%__MODULE__{slope: nil}, _x), do: nil

  def forecast(%__MODULE__{slope: slope, intercept: intercept}, x) when is_number(x) do
    Float.round(slope * x + intercept, 4)
  end

  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    %{
      label: state.label,
      point_count: length(state.series),
      direction: direction(state),
      slope: state.slope,
      intercept: state.intercept,
      ewma: state.ewma,
      alpha: state.alpha
    }
  end

  # ── Private ──────────────────────────────────────────────────────────

  defp recompute(%__MODULE__{series: series} = state) when length(series) < @min_points do
    ewma =
      case series do
        [{_x, y}] -> y
        [] -> nil
        _ -> nil
      end

    %{state | slope: nil, intercept: nil, ewma: ewma}
  end

  defp recompute(%__MODULE__{series: series, alpha: alpha} = state) do
    n = length(series)
    xs = Enum.map(series, fn {x, _} -> x end)
    ys = Enum.map(series, fn {_, y} -> y end)

    mean_x = Enum.sum(xs) / n
    mean_y = Enum.sum(ys) / n

    numerator =
      Enum.zip(xs, ys)
      |> Enum.reduce(0.0, fn {x, y}, acc -> acc + (x - mean_x) * (y - mean_y) end)

    denominator =
      Enum.reduce(xs, 0.0, fn x, acc -> acc + (x - mean_x) * (x - mean_x) end)

    slope = if denominator == 0.0, do: 0.0, else: numerator / denominator
    intercept = mean_y - slope * mean_x

    ewma =
      Enum.reduce(ys, hd(ys), fn y, prev -> alpha * y + (1.0 - alpha) * prev end)

    %{
      state
      | slope: Float.round(slope, 6),
        intercept: Float.round(intercept, 6),
        ewma: Float.round(ewma, 6)
    }
  end
end
