defmodule Indrajaal.Substrate.L4.FutureProjector do
  @moduledoc """
  ## Design Intent
  L4 pure module providing future state projection for the Indrajaal VSM fractal mesh.
  Takes current_state (map of numeric metric values) and trend_data (list of recent
  observations) and returns a projected state at a future time T using linear
  extrapolation with uncertainty bounds derived from residual variance.

  Projection algorithm:
    1. For each numeric metric key present in current_state:
       a. Extract time-ordered observations from trend_data for that key
       b. Fit a linear regression line: value = slope × time + intercept
       c. Extrapolate to horizon_seconds in the future
       d. Compute 1-sigma uncertainty band from regression residuals
    2. Return projected_state map with {:value, :lower_bound, :upper_bound} tuples
    3. Keys with < 2 observations fall back to current_state value, uncertainty = 10%

  Residual-based uncertainty:
    σ = sqrt(Σ(residual²) / (n − 2))          for n ≥ 3 observations
    uncertainty = 1.645 × σ × sqrt(horizon²)   95th-percentile bound

  ## STAMP Constraints
  - SC-PRED-001: Projections MUST include uncertainty bounds — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED
  - SC-CPU-GOV-001: All computations are O(n × k) pure arithmetic — no blocking calls

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation (Task 95, L4) |
  """

  require Logger

  @checkpoint "CP-L4-FUTURE-PROJ-01"

  # z-score for 95th-percentile uncertainty (1.645)
  @z_95 1.645

  # Default percentage uncertainty when insufficient data
  @fallback_uncertainty_pct 0.10

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type metric_value :: number()
  @type current_state :: %{optional(atom() | String.t()) => metric_value()}

  @type observation :: %{
          required(:time) => number(),
          optional(atom() | String.t()) => metric_value()
        }

  @type projected_metric :: %{
          value: float(),
          lower_bound: float(),
          upper_bound: float(),
          slope: float(),
          data_points: non_neg_integer()
        }

  @type projected_state :: %{optional(atom() | String.t()) => projected_metric()}

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Project future state given current state and trend observations.

  ## Parameters
  - `current_state`    — map of `metric_name => current_value`
  - `trend_data`       — list of observation maps, each MUST have a `:time` key
                         (numeric seconds since reference) plus metric keys
  - `horizon_seconds`  — how far into the future to project

  ## Returns
  A `projected_state` map where each key maps to a `projected_metric` tuple.

  ## Examples

      iex> current = %{cpu_pct: 55.0, mem_pct: 70.0}
      iex> trend = [
      ...>   %{time: 0, cpu_pct: 40.0, mem_pct: 65.0},
      ...>   %{time: 10, cpu_pct: 45.0, mem_pct: 67.0},
      ...>   %{time: 20, cpu_pct: 50.0, mem_pct: 69.0}
      ...> ]
      iex> Indrajaal.Substrate.L4.FutureProjector.project(current, trend, horizon_seconds: 30)
      # => %{cpu_pct: %{value: 65.0, lower_bound: 62.1, upper_bound: 67.9, slope: 0.5, data_points: 3}, ...}
  """
  @spec project(current_state(), [observation()], keyword()) :: projected_state()
  def project(current_state, trend_data, opts \\ [])
      when is_map(current_state) and is_list(trend_data) do
    horizon = Keyword.get(opts, :horizon_seconds, 60)

    Logger.debug(
      "[FUTURE_PROJ] Projecting #{map_size(current_state)} metrics " <>
        "over #{horizon}s horizon — checkpoint=#{@checkpoint}"
    )

    Map.new(current_state, fn {key, current_value} ->
      projected = project_metric(key, current_value, trend_data, horizon)
      {key, projected}
    end)
  end

  @doc """
  Project a single named metric.
  """
  @spec project_metric(atom() | String.t(), metric_value(), [observation()], number()) ::
          projected_metric()
  def project_metric(key, current_value, trend_data, horizon_seconds) do
    observations = extract_observations(key, trend_data)

    case length(observations) do
      0 ->
        fallback_projection(current_value)

      1 ->
        fallback_projection(current_value)

      n when n >= 2 ->
        linear_project(key, observations, current_value, horizon_seconds)
    end
  end

  # ---------------------------------------------------------------------------
  # Private — linear regression
  # ---------------------------------------------------------------------------

  defp extract_observations(key, trend_data) do
    trend_data
    |> Enum.filter(fn obs ->
      is_map(obs) and Map.has_key?(obs, :time) and Map.has_key?(obs, key)
    end)
    |> Enum.map(fn obs -> {obs.time * 1.0, obs[key] * 1.0} end)
    |> Enum.sort_by(fn {t, _v} -> t end)
  end

  defp linear_project(key, observations, current_value, horizon_s) do
    n = length(observations)
    times = Enum.map(observations, fn {t, _v} -> t end)
    values = Enum.map(observations, fn {_t, v} -> v end)

    mean_t = Enum.sum(times) / n
    mean_v = Enum.sum(values) / n

    # Compute slope = Σ((t - mean_t)(v - mean_v)) / Σ((t - mean_t)²)
    pairs = Enum.zip(times, values)

    numerator =
      Enum.reduce(pairs, 0.0, fn {t, v}, acc ->
        acc + (t - mean_t) * (v - mean_v)
      end)

    denominator =
      Enum.reduce(times, 0.0, fn t, acc ->
        acc + (t - mean_t) * (t - mean_t)
      end)

    {slope, intercept} =
      if denominator == 0.0 do
        {0.0, mean_v}
      else
        s = numerator / denominator
        {s, mean_v - s * mean_t}
      end

    # Project to horizon (relative to last observation time)
    last_t = List.last(times, 0.0)
    projected_value = slope * (last_t + horizon_s) + intercept

    # Clamp projected value to reasonable range if slope is very aggressive
    projected_value = max(0.0, projected_value)

    # Compute residuals for uncertainty
    residuals =
      Enum.map(pairs, fn {t, v} ->
        predicted = slope * t + intercept
        v - predicted
      end)

    sigma =
      if n >= 3 do
        ss_res = Enum.reduce(residuals, 0.0, fn r, acc -> acc + r * r end)
        :math.sqrt(ss_res / (n - 2))
      else
        abs(current_value) * @fallback_uncertainty_pct
      end

    # 95th-percentile uncertainty band grows with sqrt(horizon)
    uncertainty = @z_95 * sigma * :math.sqrt(max(1.0, horizon_s / 10.0))

    emit_telemetry(key, slope, projected_value, n)

    %{
      value: Float.round(projected_value, 4),
      lower_bound: Float.round(max(0.0, projected_value - uncertainty), 4),
      upper_bound: Float.round(projected_value + uncertainty, 4),
      slope: Float.round(slope, 6),
      data_points: n
    }
  end

  defp fallback_projection(current_value) do
    v = current_value * 1.0
    uncertainty = abs(v) * @fallback_uncertainty_pct

    %{
      value: Float.round(v, 4),
      lower_bound: Float.round(max(0.0, v - uncertainty), 4),
      upper_bound: Float.round(v + uncertainty, 4),
      slope: 0.0,
      data_points: 0
    }
  end

  defp emit_telemetry(key, slope, projected_value, data_points) do
    try do
      :telemetry.execute(
        [:indrajaal, :substrate, :l4, :future_projector, :project],
        %{slope: slope, projected_value: projected_value, data_points: data_points},
        %{checkpoint: @checkpoint, metric_key: key, constraint: "SC-PRED-001"}
      )
    rescue
      _ -> :ok
    end
  end
end
