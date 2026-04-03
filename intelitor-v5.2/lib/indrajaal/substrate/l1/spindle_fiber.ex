defmodule Indrajaal.Substrate.L1.SpindleFiber do
  @moduledoc """
  ## Design Intent
  L1 substrate spindle fiber — pure functional length/velocity sensor.
  Inspired by the muscle spindle (intrafusal fiber), a proprioceptive receptor
  that detects both absolute muscle length and the rate of change (velocity).
  Its Ia afferents encode velocity (dynamic response); II afferents encode
  static length.

  Spindle model:
    - `length`           — current normalised muscle length [0.0, 2.0]
    - `velocity`         — rate of length change per tick (set by `update/2`)
    - `gamma_bias`       — fusimotor bias [0.0, 1.0] (shifts sensitivity, default 0.3)
    - `ia_signal`        — dynamic Ia output: encodes velocity + length (default 0.0)
    - `ii_signal`        — static II output: encodes length only (default 0.0)
    - `update/2`         — provide new length; compute velocity, Ia, II signals
    - `set_gamma/2`      — adjust fusimotor bias (gamma-motor drive)

  Signal equations:
    ia_signal  = clamp(velocity × (1 + gamma_bias) + length_deviation, 0, 1)
    ii_signal  = clamp(length_deviation × (1 + gamma_bias × 0.5), 0, 1)
    length_deviation = |length - 1.0| (deviation from resting normalised length)

  All functions are pure. No GenServer, no ETS.

  ## STAMP Constraints
  - SC-S1-001: Cybernetic VSM S1 operations — ENFORCED
  - SC-S1-002: S1 sensory input processing — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type t :: %__MODULE__{
          length: float(),
          prev_length: float(),
          velocity: float(),
          gamma_bias: float(),
          ia_signal: float(),
          ii_signal: float(),
          sample_count: non_neg_integer()
        }

  defstruct length: 1.0,
            prev_length: 1.0,
            velocity: 0.0,
            gamma_bias: 0.3,
            ia_signal: 0.0,
            ii_signal: 0.0,
            sample_count: 0

  @resting_length 1.0
  @max_length 2.0

  @doc """
  Create a new spindle fiber struct.

  Options:
    - `:length`      (float in [0.0, 2.0], default 1.0)
    - `:gamma_bias`  (float in [0.0, 1.0], default 0.3)
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    len = Keyword.get(opts, :length, 1.0)
    gamma = Keyword.get(opts, :gamma_bias, 0.3)

    cond do
      not is_float(len) or len < 0.0 or len > @max_length ->
        {:error, "length must be in [0.0, #{@max_length}]"}

      not is_float(gamma) or gamma < 0.0 or gamma > 1.0 ->
        {:error, "gamma_bias must be in [0.0, 1.0]"}

      true ->
        {:ok, %__MODULE__{length: len, prev_length: len, gamma_bias: gamma}}
    end
  end

  @doc """
  Update the spindle with a new length measurement.

  Computes velocity (difference from previous), then derives Ia and II signals.
  Returns `{:ok, {ia, ii}, updated_spindle}`.
  """
  @spec update(t(), float()) :: {:ok, {float(), float()}, t()} | {:error, String.t()}
  def update(%__MODULE__{} = sp, new_length) when is_float(new_length) do
    if new_length < 0.0 or new_length > @max_length do
      {:error, "new_length must be in [0.0, #{@max_length}]"}
    else
      velocity = new_length - sp.length
      length_dev = abs(new_length - @resting_length)

      ia = clamp(velocity * (1.0 + sp.gamma_bias) + length_dev, 0.0, 1.0)
      ii = clamp(length_dev * (1.0 + sp.gamma_bias * 0.5), 0.0, 1.0)

      updated = %{
        sp
        | length: new_length,
          prev_length: sp.length,
          velocity: velocity,
          ia_signal: ia,
          ii_signal: ii,
          sample_count: sp.sample_count + 1
      }

      {:ok, {ia, ii}, updated}
    end
  end

  @doc """
  Set the gamma-motor bias [0.0, 1.0] (fusimotor drive).
  Returns `{:ok, updated_spindle}` or `{:error, reason}`.
  """
  @spec set_gamma(t(), float()) :: {:ok, t()} | {:error, String.t()}
  def set_gamma(%__MODULE__{} = sp, gamma) when is_float(gamma) do
    if gamma < 0.0 or gamma > 1.0 do
      {:error, "gamma_bias must be in [0.0, 1.0]"}
    else
      {:ok, %{sp | gamma_bias: gamma}}
    end
  end

  @doc "Return a summary map of the spindle's current state."
  @spec status(t()) :: map()
  def status(%__MODULE__{} = sp) do
    %{
      length: Float.round(sp.length, 4),
      velocity: Float.round(sp.velocity, 4),
      gamma_bias: Float.round(sp.gamma_bias, 4),
      ia_signal: Float.round(sp.ia_signal, 4),
      ii_signal: Float.round(sp.ii_signal, 4),
      sample_count: sp.sample_count,
      is_stretched: sp.length > @resting_length,
      is_shortening: sp.velocity < 0.0
    }
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec clamp(float(), float(), float()) :: float()
  defp clamp(v, lo, hi), do: max(lo, min(hi, v))
end
