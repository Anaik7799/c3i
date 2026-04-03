defmodule Indrajaal.Substrate.L2.OscillationDamper do
  @moduledoc """
  ## Design Intent
  L2 substrate oscillation damper — pure functional vibration and oscillation suppression.

  Biomorphic metaphor: the cerebellum's role in smoothing motor output, eliminating
  tremor by applying velocity-dependent damping. Analogous to a dashpot in a mechanical
  system: the damping force is proportional to the rate of change of the signal.

  Algorithm:
  1. Compute the velocity (first derivative) of the input signal using exponential
     moving average (EMA) filtering.
  2. Apply a damping coefficient to the velocity term to generate a correction force.
  3. Clamp output to valid signal range to prevent saturation.
  4. Track energy dissipated to provide observability into damping activity.

  ## STAMP Constraints
  - SC-S2-001: Cybernetic VSM S2 coordination — ENFORCED
  - SC-S2-002: Oscillation detection mandatory — ENFORCED
  - SC-BIO-001: Biomorphic substrate layer L2 — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type t :: %__MODULE__{
          damping_coefficient: float(),
          alpha: float(),
          last_input: float(),
          ema_velocity: float(),
          output: float(),
          energy_dissipated: float(),
          sample_count: non_neg_integer()
        }

  defstruct damping_coefficient: 0.7,
            alpha: 0.2,
            last_input: 0.0,
            ema_velocity: 0.0,
            output: 0.0,
            energy_dissipated: 0.0,
            sample_count: 0

  @doc """
  Create a new OscillationDamper.

  Options:
  - `:damping_coefficient` — damping ratio ∈ (0.0, 2.0], default 0.7
  - `:alpha` — EMA smoothing factor ∈ (0.0, 1.0], default 0.2
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    dc = Keyword.get(opts, :damping_coefficient, 0.7)
    alpha = Keyword.get(opts, :alpha, 0.2)

    cond do
      not is_float(dc) and not is_integer(dc) ->
        {:error, "damping_coefficient must be a number"}

      dc <= 0.0 or dc > 2.0 ->
        {:error, "damping_coefficient must be in (0.0, 2.0]"}

      not is_float(alpha) and not is_integer(alpha) ->
        {:error, "alpha must be a number"}

      alpha <= 0.0 or alpha > 1.0 ->
        {:error, "alpha must be in (0.0, 1.0]"}

      true ->
        {:ok,
         %__MODULE__{
           damping_coefficient: dc * 1.0,
           alpha: alpha * 1.0
         }}
    end
  end

  @doc """
  Apply damping to a new input sample.

  Returns `{damped_output, updated_state}`.
  """
  @spec damp(t(), float()) :: {float(), t()}
  def damp(%__MODULE__{} = state, input) when is_number(input) do
    velocity = input - state.last_input
    new_ema_velocity = state.alpha * velocity + (1.0 - state.alpha) * state.ema_velocity
    correction = state.damping_coefficient * new_ema_velocity
    raw_output = input - correction
    clamped = clamp(raw_output, -1.0e9, 1.0e9)
    dissipated = state.energy_dissipated + abs(correction)

    new_state = %__MODULE__{
      state
      | last_input: input * 1.0,
        ema_velocity: new_ema_velocity,
        output: clamped,
        energy_dissipated: dissipated,
        sample_count: state.sample_count + 1
    }

    {clamped, new_state}
  end

  @doc """
  Reset the damper's internal state while keeping configuration.
  """
  @spec reset(t()) :: t()
  def reset(%__MODULE__{} = state) do
    %__MODULE__{
      state
      | last_input: 0.0,
        ema_velocity: 0.0,
        output: 0.0,
        energy_dissipated: 0.0,
        sample_count: 0
    }
  end

  @doc """
  Returns a summary map of the current damper state.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    %{
      damping_coefficient: state.damping_coefficient,
      alpha: state.alpha,
      last_input: state.last_input,
      ema_velocity: state.ema_velocity,
      output: state.output,
      energy_dissipated: state.energy_dissipated,
      sample_count: state.sample_count
    }
  end

  @spec clamp(float(), float(), float()) :: float()
  defp clamp(value, lo, hi), do: value |> max(lo) |> min(hi)
end
