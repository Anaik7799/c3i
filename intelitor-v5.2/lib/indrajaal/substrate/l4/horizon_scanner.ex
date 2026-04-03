defmodule Indrajaal.Substrate.L4.HorizonScanner do
  @moduledoc """
  L4 Horizon Scanner — Monitors external environment for emerging trends.

  Pure module that analyzes incoming metrics and environmental signals to detect
  trends, forecast future states, and compute confidence scores. Operates at
  the L4 (Environmental Intelligence) layer of the VSM fractal hierarchy.

  ## STAMP Compliance
  - SC-S4-001: Environmental scanning at L4 boundary
  - SC-S4-002: Trend detection from metabolic telemetry
  - SC-S4-003: Forecast horizon aligned with OODA cycle
  - SC-S4-004: Confidence bounds verified before actuation

  ## Constitutional Alignment
  - Ψ₁ Regeneration: All scan results are stateless; state in SQLite/DuckDB
  - Ψ₃ Verification: Confidence thresholds enforced per SC-S4-004

  ## Design Intent
  The scanner maintains no internal state. All functions are pure transformations
  over metric maps, producing typed analysis results that upper layers may act on.
  """

  @type metric_key :: atom() | String.t()
  @type metric_value :: number()
  @type metrics :: %{metric_key() => metric_value()}

  @type trend :: %{
          key: metric_key(),
          direction: :rising | :falling | :stable,
          magnitude: float(),
          velocity: float()
        }

  @type forecast :: %{
          horizon_steps: non_neg_integer(),
          predicted_value: float(),
          lower_bound: float(),
          upper_bound: float(),
          confidence: float()
        }

  @type scan_result :: %{
          scanned_at: integer(),
          metric_count: non_neg_integer(),
          trend_count: non_neg_integer(),
          dominant_trend: trend() | nil,
          health_index: float()
        }

  @trend_threshold 0.05
  @confidence_decay 0.95
  @default_horizon 10

  @doc """
  Scans a metrics map and returns a summary scan result.

  ## Parameters
  - `metrics` — map of metric keys to numeric values

  ## Returns
  A `scan_result/0` struct summarizing the current environmental state.

  ## Examples

      iex> HorizonScanner.scan(%{cpu: 0.72, mem: 0.55, latency: 120.0})
      %{scanned_at: _, metric_count: 3, trend_count: 0, dominant_trend: nil, health_index: _}
  """
  @spec scan(metrics()) :: scan_result()
  def scan(metrics) when is_map(metrics) do
    trends = detect_trends(metrics, %{})
    dominant = find_dominant(trends)

    health =
      metrics
      |> Map.values()
      |> Enum.filter(&is_number/1)
      |> compute_health_index()

    %{
      scanned_at: System.monotonic_time(:millisecond),
      metric_count: map_size(metrics),
      trend_count: length(trends),
      dominant_trend: dominant,
      health_index: health
    }
  end

  def scan(_), do: scan(%{})

  @doc """
  Detects trends by comparing current metrics against a baseline.

  When `baseline` is an empty map, all metrics are treated as stable.
  Returns a list of `trend/0` structs for metrics that exceed the threshold.

  ## Parameters
  - `current` — current metrics snapshot
  - `baseline` — prior metrics snapshot for comparison

  ## Returns
  List of detected trends, sorted by magnitude descending.
  """
  @spec detect_trends(metrics(), metrics()) :: [trend()]
  def detect_trends(current, baseline)
      when is_map(current) and is_map(baseline) do
    current
    |> Enum.flat_map(fn {key, value} ->
      with true <- is_number(value),
           {:ok, base_val} <- Map.fetch(baseline, key),
           true <- is_number(base_val) do
        delta = value - base_val
        magnitude = abs(delta)

        if magnitude > @trend_threshold do
          direction = if delta > 0, do: :rising, else: :falling
          velocity = if base_val != 0.0, do: delta / base_val, else: delta

          [
            %{
              key: key,
              direction: direction,
              magnitude: magnitude,
              velocity: velocity
            }
          ]
        else
          []
        end
      else
        _ -> []
      end
    end)
    |> Enum.sort_by(& &1.magnitude, :desc)
  end

  def detect_trends(current, _) when is_map(current) do
    current
    |> Enum.flat_map(fn {key, value} ->
      if is_number(value) do
        [%{key: key, direction: :stable, magnitude: 0.0, velocity: 0.0}]
      else
        []
      end
    end)
  end

  @doc """
  Produces a simple linear forecast for a given metric key.

  Uses the velocity from detected trends to project forward `horizon` steps.
  Confidence degrades exponentially over the horizon.

  ## Parameters
  - `trends` — list of trends from `detect_trends/2`
  - `horizon` — number of steps to forecast (defaults to #{@default_horizon})

  ## Returns
  Map of metric keys to `forecast/0` structs.
  """
  @spec forecast([trend()], non_neg_integer()) :: %{metric_key() => forecast()}
  def forecast(trends, horizon \\ @default_horizon)
      when is_list(trends) and is_integer(horizon) and horizon >= 0 do
    trends
    |> Enum.reduce(%{}, fn trend, acc ->
      base = trend.magnitude
      projected = base + trend.velocity * horizon
      conf = :math.pow(@confidence_decay, horizon)
      spread = base * (1.0 - conf) * 0.5

      entry = %{
        horizon_steps: horizon,
        predicted_value: projected,
        lower_bound: projected - spread,
        upper_bound: projected + spread,
        confidence: conf
      }

      Map.put(acc, trend.key, entry)
    end)
  end

  @doc """
  Computes an aggregate confidence score over a set of forecasts.

  Returns the harmonic mean of individual forecast confidence values,
  or 0.0 if the input map is empty.

  ## Parameters
  - `forecasts` — map returned by `forecast/2`

  ## Returns
  Float in [0.0, 1.0] representing aggregate confidence.
  """
  @spec confidence(%{metric_key() => forecast()}) :: float()
  def confidence(forecasts) when is_map(forecasts) and map_size(forecasts) == 0, do: 0.0

  def confidence(forecasts) when is_map(forecasts) do
    values =
      forecasts
      |> Map.values()
      |> Enum.map(& &1.confidence)
      |> Enum.filter(&(&1 > 0.0))

    case values do
      [] ->
        0.0

      confs ->
        n = length(confs)
        reciprocal_sum = Enum.reduce(confs, 0.0, fn c, acc -> acc + 1.0 / c end)
        n / reciprocal_sum
    end
  end

  def confidence(_), do: 0.0

  # --- Private helpers ---

  @spec find_dominant([trend()]) :: trend() | nil
  defp find_dominant([]), do: nil
  defp find_dominant([head | _]), do: head

  @spec compute_health_index([number()]) :: float()
  defp compute_health_index([]), do: 1.0

  defp compute_health_index(values) do
    n = length(values)
    mean = Enum.sum(values) / n
    variance = Enum.reduce(values, 0.0, fn v, acc -> acc + (v - mean) * (v - mean) end) / n
    stability = 1.0 / (1.0 + variance)
    Float.round(stability, 4)
  end
end
