defmodule Indrajaal.Substrate.L0.ThermalVent do
  @moduledoc """
  ## Design Intent
  L0 substrate thermal vent — pure functional module modelling an energy
  source driven by thermal differential.  Inspired by deep-sea hydrothermal
  vents where chemical energy gradients power the first metabolic cycles.

  Energy model:
    - `temperature`      — current vent temperature [0.0, 1.0] (normalised)
    - `ambient`          — surrounding environment temperature [0.0, 1.0]
    - `flux_rate`        — energy output per unit time (default 0.05)
    - `heat_dissipation` — rate at which temperature drops per tick (default 0.02)
    - Energy produced per tick = max(0, temperature - ambient) × flux_rate
    - `tick/1`           — advance one time step: produce energy, dissipate heat
    - `reheat/2`         — replenish temperature by delta (external heat source)

  All functions are pure. No GenServer, no ETS.

  ## STAMP Constraints
  - SC-BIO-001: Biomorphic substrate layer L0 — ENFORCED
  - SC-SAFETY-009: Ψ₀ (Existence) validated for all operations — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type t :: %__MODULE__{
          temperature: float(),
          ambient: float(),
          flux_rate: float(),
          heat_dissipation: float(),
          total_energy_produced: float(),
          tick_count: non_neg_integer()
        }

  defstruct temperature: 0.8,
            ambient: 0.1,
            flux_rate: 0.05,
            heat_dissipation: 0.02,
            total_energy_produced: 0.0,
            tick_count: 0

  @doc """
  Create a new thermal vent struct.

  Options:
    - `:temperature`      (float in [0.0, 1.0], default 0.8)
    - `:ambient`          (float in [0.0, 1.0], default 0.1)
    - `:flux_rate`        (positive float, default 0.05)
    - `:heat_dissipation` (positive float, default 0.02)
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    temp = Keyword.get(opts, :temperature, 0.8)
    ambient = Keyword.get(opts, :ambient, 0.1)
    flux = Keyword.get(opts, :flux_rate, 0.05)
    dissip = Keyword.get(opts, :heat_dissipation, 0.02)

    cond do
      not is_float(temp) or temp < 0.0 or temp > 1.0 ->
        {:error, "temperature must be a float in [0.0, 1.0]"}

      not is_float(ambient) or ambient < 0.0 or ambient > 1.0 ->
        {:error, "ambient must be a float in [0.0, 1.0]"}

      not is_float(flux) or flux <= 0.0 ->
        {:error, "flux_rate must be a positive float"}

      not is_float(dissip) or dissip <= 0.0 ->
        {:error, "heat_dissipation must be a positive float"}

      true ->
        {:ok,
         %__MODULE__{
           temperature: temp,
           ambient: ambient,
           flux_rate: flux,
           heat_dissipation: dissip
         }}
    end
  end

  @doc """
  Advance the vent by one time step.

  Computes energy produced, dissipates heat, returns
  `{:ok, energy_produced, updated_vent}`.
  """
  @spec tick(t()) :: {:ok, float(), t()}
  def tick(%__MODULE__{} = vent) do
    differential = max(0.0, vent.temperature - vent.ambient)
    energy = differential * vent.flux_rate
    new_temp = max(vent.ambient, vent.temperature - vent.heat_dissipation)

    updated = %{
      vent
      | temperature: new_temp,
        total_energy_produced: vent.total_energy_produced + energy,
        tick_count: vent.tick_count + 1
    }

    {:ok, energy, updated}
  end

  @doc """
  Replenish vent temperature by `delta` (clamped to [0.0, 1.0]).
  Models a geothermal recharge event.
  Returns `{:ok, updated_vent}`.
  """
  @spec reheat(t(), float()) :: {:ok, t()} | {:error, String.t()}
  def reheat(%__MODULE__{} = vent, delta) when is_float(delta) do
    if delta < 0.0 do
      {:error, "delta must be >= 0.0"}
    else
      new_temp = min(1.0, vent.temperature + delta)
      {:ok, %{vent | temperature: new_temp}}
    end
  end

  @doc """
  Returns the current differential (vent temp minus ambient).
  """
  @spec differential(t()) :: float()
  def differential(%__MODULE__{} = vent) do
    max(0.0, vent.temperature - vent.ambient)
  end

  @doc "Return a summary map of the vent's current state."
  @spec status(t()) :: map()
  def status(%__MODULE__{} = vent) do
    %{
      temperature: Float.round(vent.temperature, 4),
      ambient: Float.round(vent.ambient, 4),
      differential: Float.round(differential(vent), 4),
      flux_rate: vent.flux_rate,
      heat_dissipation: vent.heat_dissipation,
      total_energy_produced: Float.round(vent.total_energy_produced, 6),
      tick_count: vent.tick_count,
      is_active: vent.temperature > vent.ambient
    }
  end
end
