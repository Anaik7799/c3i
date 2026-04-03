defmodule Indrajaal.Substrate.L7.ClimateModeler do
  @moduledoc """
  L7 Climate Modeler — Environmental climate model for ecosystem intelligence.

  Tracks multi-dimensional environmental indicators (temperature, pressure, humidity,
  carbon proxies) and computes a composite ecosystem health index. Used by the L7
  ecosystem layer to assess macro-environmental conditions and trigger adaptation.

  Algorithm:
  - Climate index: weighted arithmetic mean of normalised indicators
  - Anomaly score: mean absolute deviation from indicator baselines
  - Regime: :nominal, :stressed, :critical based on index + anomaly

  ## STAMP Constraints
  - SC-ECO-001: Ecosystem external boundaries — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @default_stress_threshold 0.65
  @default_critical_threshold 0.85

  @type indicator :: %{name: String.t(), value: float(), baseline: float(), weight: float()}
  @type regime :: :nominal | :stressed | :critical

  @type t :: %__MODULE__{
          region: String.t(),
          indicators: [indicator()],
          climate_index: float(),
          anomaly_score: float(),
          regime: regime(),
          stress_threshold: float(),
          critical_threshold: float()
        }

  defstruct region: "global",
            indicators: [],
            climate_index: 0.5,
            anomaly_score: 0.0,
            regime: :nominal,
            stress_threshold: @default_stress_threshold,
            critical_threshold: @default_critical_threshold

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    region = Keyword.get(opts, :region, "global")
    stress = Keyword.get(opts, :stress_threshold, @default_stress_threshold)
    critical = Keyword.get(opts, :critical_threshold, @default_critical_threshold)

    cond do
      not is_binary(region) ->
        {:error, "region must be a string"}

      not is_number(stress) or stress < 0.0 or stress > 1.0 ->
        {:error, "stress_threshold must be in [0.0, 1.0]"}

      not is_number(critical) or critical <= stress ->
        {:error, "critical_threshold must be > stress_threshold"}

      true ->
        {:ok,
         %__MODULE__{
           region: region,
           stress_threshold: stress / 1.0,
           critical_threshold: critical / 1.0
         }}
    end
  end

  @spec record_indicator(t(), String.t(), float(), float(), float()) ::
          {:ok, t()} | {:error, String.t()}
  def record_indicator(%__MODULE__{} = state, name, value, baseline, weight)
      when is_binary(name) and is_number(value) and is_number(baseline) and is_number(weight) do
    cond do
      weight <= 0.0 ->
        {:error, "weight must be positive"}

      true ->
        indicator = %{
          name: name,
          value: Float.round(value / 1.0, 4),
          baseline: Float.round(baseline / 1.0, 4),
          weight: Float.round(weight / 1.0, 4)
        }

        existing = Enum.reject(state.indicators, &(&1.name == name))
        updated = %{state | indicators: existing ++ [indicator]}
        {:ok, recompute(updated)}
    end
  end

  @spec anomalous_indicators(t()) :: [String.t()]
  def anomalous_indicators(%__MODULE__{indicators: inds}) do
    inds
    |> Enum.filter(fn i -> abs(i.value - i.baseline) / max(abs(i.baseline), 0.001) > 0.2 end)
    |> Enum.map(& &1.name)
  end

  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    %{
      region: state.region,
      climate_index: state.climate_index,
      anomaly_score: state.anomaly_score,
      regime: state.regime,
      indicator_count: length(state.indicators),
      anomalous: anomalous_indicators(state)
    }
  end

  # ── Private ──────────────────────────────────────────────────────────

  defp recompute(%__MODULE__{indicators: []} = state) do
    %{state | climate_index: 0.5, anomaly_score: 0.0, regime: :nominal}
  end

  defp recompute(
         %__MODULE__{indicators: inds, stress_threshold: st, critical_threshold: ct} = state
       ) do
    total_weight = Enum.reduce(inds, 0.0, fn i, acc -> acc + i.weight end)

    normalised =
      Enum.map(inds, fn i ->
        span = max(abs(i.baseline), 0.001)
        capped = abs(i.value - i.baseline) / span
        min(1.0, capped)
      end)

    climate_index =
      if total_weight == 0.0 do
        0.5
      else
        Enum.zip(normalised, inds)
        |> Enum.reduce(0.0, fn {n, i}, acc -> acc + n * i.weight end)
        |> Kernel./(total_weight)
        |> Float.round(4)
      end

    anomaly_score = Float.round(Enum.sum(normalised) / length(normalised), 4)

    regime =
      cond do
        climate_index >= ct or anomaly_score >= 0.5 -> :critical
        climate_index >= st or anomaly_score >= 0.25 -> :stressed
        true -> :nominal
      end

    %{state | climate_index: climate_index, anomaly_score: anomaly_score, regime: regime}
  end
end
