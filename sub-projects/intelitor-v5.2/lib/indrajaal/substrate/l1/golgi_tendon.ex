defmodule Indrajaal.Substrate.L1.GolgiTendon do
  @moduledoc """
  ## Design Intent
  L1 substrate Golgi tendon organ — pure functional force-limit sensor.
  Inspired by the Golgi tendon organ (GTO), a proprioceptive receptor in
  muscle tendons that detects excessive tension and triggers inhibitory
  reflexes to protect tissue from injury.

  GTO model:
    - `force`            — current measured force [0.0, 1.0]
    - `threshold`        — force level that triggers inhibition (default 0.75)
    - `sensitivity`      — how sharply the GTO responds around threshold (default 5.0)
    - `inhibition_signal`— output [0.0, 1.0]: 0 = no inhibition, 1 = full inhibition
    - Inhibition computed via a sigmoid: σ((force - threshold) × sensitivity)
    - `sense/2`          — apply a force measurement; returns updated state + signal
    - `reset/1`          — zero force and inhibition
    - `calibrate/2`      — adjust threshold in-place

  All functions are pure. No GenServer, no ETS.

  ## STAMP Constraints
  - SC-S1-001: Cybernetic VSM S1 operations — ENFORCED
  - SC-S1-002: S1 sensory input processing — ENFORCED
  - SC-S1-004: S1 resource management — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type t :: %__MODULE__{
          force: float(),
          threshold: float(),
          sensitivity: float(),
          inhibition_signal: float(),
          peak_force: float(),
          trigger_count: non_neg_integer()
        }

  defstruct force: 0.0,
            threshold: 0.75,
            sensitivity: 5.0,
            inhibition_signal: 0.0,
            peak_force: 0.0,
            trigger_count: 0

  @doc """
  Create a new Golgi tendon organ struct.

  Options:
    - `:threshold`    (float in (0.0, 1.0], default 0.75)
    - `:sensitivity`  (positive float, default 5.0; higher = sharper response)
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    thresh = Keyword.get(opts, :threshold, 0.75)
    sens = Keyword.get(opts, :sensitivity, 5.0)

    cond do
      not is_float(thresh) or thresh <= 0.0 or thresh > 1.0 ->
        {:error, "threshold must be a float in (0.0, 1.0]"}

      not is_float(sens) or sens <= 0.0 ->
        {:error, "sensitivity must be a positive float"}

      true ->
        {:ok, %__MODULE__{threshold: thresh, sensitivity: sens}}
    end
  end

  @doc """
  Apply a force measurement to the GTO.

  Computes inhibition via sigmoid and returns
  `{:ok, inhibition_signal, updated}` or
  `{:triggered, inhibition_signal, updated}` when inhibition > 0.5.
  """
  @spec sense(t(), float()) ::
          {:ok, float(), t()} | {:triggered, float(), t()} | {:error, String.t()}
  def sense(%__MODULE__{} = gto, force) when is_float(force) do
    if force < 0.0 or force > 1.0 do
      {:error, "force must be in [0.0, 1.0]"}
    else
      inhibition = sigmoid((force - gto.threshold) * gto.sensitivity)
      new_peak = max(gto.peak_force, force)
      triggered = inhibition > 0.5

      updated = %{
        gto
        | force: force,
          inhibition_signal: inhibition,
          peak_force: new_peak,
          trigger_count: gto.trigger_count + if(triggered, do: 1, else: 0)
      }

      if triggered, do: {:triggered, inhibition, updated}, else: {:ok, inhibition, updated}
    end
  end

  @doc """
  Reset the GTO: zero force and inhibition.
  Returns `{:ok, updated}`.
  """
  @spec reset(t()) :: {:ok, t()}
  def reset(%__MODULE__{} = gto) do
    {:ok, %{gto | force: 0.0, inhibition_signal: 0.0}}
  end

  @doc """
  Adjust the force threshold.
  Returns `{:ok, updated}` or `{:error, reason}`.
  """
  @spec calibrate(t(), float()) :: {:ok, t()} | {:error, String.t()}
  def calibrate(%__MODULE__{} = gto, new_threshold) when is_float(new_threshold) do
    if new_threshold <= 0.0 or new_threshold > 1.0 do
      {:error, "threshold must be in (0.0, 1.0]"}
    else
      {:ok, %{gto | threshold: new_threshold}}
    end
  end

  @doc "Return a summary map of the GTO's current state."
  @spec status(t()) :: map()
  def status(%__MODULE__{} = gto) do
    %{
      force: Float.round(gto.force, 4),
      threshold: gto.threshold,
      sensitivity: gto.sensitivity,
      inhibition_signal: Float.round(gto.inhibition_signal, 4),
      peak_force: Float.round(gto.peak_force, 4),
      trigger_count: gto.trigger_count,
      is_inhibiting: gto.inhibition_signal > 0.5
    }
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec sigmoid(float()) :: float()
  defp sigmoid(x), do: 1.0 / (1.0 + :math.exp(-x))
end
