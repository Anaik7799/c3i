defmodule Indrajaal.Substrate.L1.FatigueAccumulator do
  @moduledoc """
  ## Design Intent
  L1 substrate fatigue accumulator — pure functional tracker of cumulative
  fatigue buildup across repeated operational cycles.

  Biological metaphor: Muscle ATP depletion and lactate accumulation.
  Each work unit adds fatigue proportional to its intensity. Recovery
  events reduce fatigue at a configurable rate. When accumulated fatigue
  crosses the `critical_threshold`, the unit enters a degraded state.

  Algorithm:
    - `accumulate/2` adds `intensity × cost_factor` to current fatigue.
    - `recover/2` subtracts `recovery_units × recovery_rate`, clamped to 0.
    - `fatigue_level/1` returns normalised fatigue in [0.0, 1.0].
    - `state/1` classifies current fatigue as :fresh | :tired | :critical.
    - Fatigue is clamped to [0.0, 1.0] at all times.

  ## STAMP Constraints
  - SC-S1-001: Cybernetic VSM S1 subsystem actuation — ENFORCED
  - SC-S1-003: S1 operational response — ENFORCED
  - SC-BIO-001: Biomorphic substrate layer L1 — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type fatigue_state :: :fresh | :tired | :critical

  @type t :: %__MODULE__{
          fatigue: float(),
          cost_factor: float(),
          recovery_rate: float(),
          tired_threshold: float(),
          critical_threshold: float(),
          accumulation_count: non_neg_integer(),
          recovery_count: non_neg_integer(),
          peak_fatigue: float()
        }

  defstruct fatigue: 0.0,
            cost_factor: 0.10,
            recovery_rate: 0.05,
            tired_threshold: 0.50,
            critical_threshold: 0.85,
            accumulation_count: 0,
            recovery_count: 0,
            peak_fatigue: 0.0

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Create a new FatigueAccumulator.

  Options:
    - `:cost_factor`        (float, default 0.10) — fatigue per unit intensity
    - `:recovery_rate`      (float, default 0.05) — fatigue removed per recovery unit
    - `:tired_threshold`    (float, default 0.50) — threshold for :tired state
    - `:critical_threshold` (float, default 0.85) — threshold for :critical state

  Returns `{:ok, t()}` or `{:error, reason}`.
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    cost_factor = Keyword.get(opts, :cost_factor, 0.10)
    recovery_rate = Keyword.get(opts, :recovery_rate, 0.05)
    tired_threshold = Keyword.get(opts, :tired_threshold, 0.50)
    critical_threshold = Keyword.get(opts, :critical_threshold, 0.85)

    cond do
      not is_float(cost_factor) or cost_factor <= 0.0 ->
        {:error, "cost_factor must be a positive float"}

      not is_float(recovery_rate) or recovery_rate <= 0.0 ->
        {:error, "recovery_rate must be a positive float"}

      not is_float(tired_threshold) or tired_threshold <= 0.0 or tired_threshold >= 1.0 ->
        {:error, "tired_threshold must be in (0.0, 1.0)"}

      not is_float(critical_threshold) or critical_threshold <= tired_threshold or
          critical_threshold > 1.0 ->
        {:error, "critical_threshold must be in (tired_threshold, 1.0]"}

      true ->
        {:ok,
         %__MODULE__{
           cost_factor: cost_factor,
           recovery_rate: recovery_rate,
           tired_threshold: tired_threshold,
           critical_threshold: critical_threshold
         }}
    end
  end

  @doc """
  Accumulate fatigue from a work unit with given intensity.

  Intensity is clamped to [0.0, 1.0]. Fatigue increase =
  `intensity × cost_factor`, added to current fatigue (clamped to 1.0).

  Returns `{:ok, updated}` always. When fatigue reaches 1.0 the
  accumulator is saturated and accepts no further increase.
  """
  @spec accumulate(t(), float()) :: {:ok, t()}
  def accumulate(%__MODULE__{} = acc, intensity) when is_float(intensity) do
    clamped = clamp(intensity, 0.0, 1.0)
    increase = clamped * acc.cost_factor
    new_fatigue = clamp(acc.fatigue + increase, 0.0, 1.0)
    new_peak = max(acc.peak_fatigue, new_fatigue)

    updated = %{
      acc
      | fatigue: new_fatigue,
        peak_fatigue: new_peak,
        accumulation_count: acc.accumulation_count + 1
    }

    {:ok, updated}
  end

  def accumulate(%__MODULE__{} = acc, _intensity), do: {:ok, acc}

  @doc """
  Recover from fatigue by a number of recovery units.

  Each recovery unit reduces fatigue by `recovery_rate`, clamped to 0.0.

  Returns `{:ok, updated}`.
  """
  @spec recover(t(), non_neg_integer()) :: {:ok, t()}
  def recover(acc, units \\ 1)

  def recover(%__MODULE__{} = acc, units) when is_integer(units) and units >= 0 do
    reduction = units * acc.recovery_rate
    new_fatigue = clamp(acc.fatigue - reduction, 0.0, 1.0)

    updated = %{
      acc
      | fatigue: new_fatigue,
        recovery_count: acc.recovery_count + units
    }

    {:ok, updated}
  end

  def recover(%__MODULE__{} = acc, _units), do: {:ok, acc}

  @doc """
  Returns the current fatigue level in [0.0, 1.0].
  """
  @spec fatigue_level(t()) :: float()
  def fatigue_level(%__MODULE__{fatigue: f}), do: f

  @doc """
  Classifies the current fatigue level as :fresh, :tired, or :critical.
  """
  @spec state(t()) :: fatigue_state()
  def state(%__MODULE__{} = acc) do
    cond do
      acc.fatigue >= acc.critical_threshold -> :critical
      acc.fatigue >= acc.tired_threshold -> :tired
      true -> :fresh
    end
  end

  @doc """
  Returns a status summary map.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = acc) do
    %{
      fatigue: acc.fatigue,
      state: state(acc),
      peak_fatigue: acc.peak_fatigue,
      cost_factor: acc.cost_factor,
      recovery_rate: acc.recovery_rate,
      tired_threshold: acc.tired_threshold,
      critical_threshold: acc.critical_threshold,
      accumulation_count: acc.accumulation_count,
      recovery_count: acc.recovery_count
    }
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec clamp(float(), float(), float()) :: float()
  defp clamp(v, lo, hi), do: max(lo, min(hi, v))
end
