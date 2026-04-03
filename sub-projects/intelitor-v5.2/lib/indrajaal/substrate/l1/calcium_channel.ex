defmodule Indrajaal.Substrate.L1.CalciumChannel do
  @moduledoc """
  ## Design Intent
  L1 substrate calcium channel — pure functional signal gating mechanism.
  Inspired by voltage-gated Ca²⁺ channels in excitable cells: the channel
  opens when membrane potential exceeds a threshold, allowing a calcium influx
  that triggers downstream signaling cascades.

  Channel model:
    - `state`            — `:closed | :open | :inactivated`
    - `voltage`          — current membrane potential [-1.0, 1.0] (normalised)
    - `activation_v`     — voltage threshold to open (default 0.4)
    - `inactivation_v`   — voltage above which channel inactivates (default 0.9)
    - `calcium_current`  — instantaneous Ca²⁺ flow [0.0, 1.0] when open
    - `total_flux`       — cumulative calcium flux since creation
    - `stimulate/2`      — apply a voltage step; returns updated channel
    - `repolarise/1`     — reset voltage to resting, channel returns to :closed

  State machine:
    closed → open   when voltage crosses activation_v (from below)
    open   → inact. when voltage crosses inactivation_v
    inact. → closed when voltage drops below activation_v (repolarise)

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

  @type channel_state :: :closed | :open | :inactivated

  @type t :: %__MODULE__{
          state: channel_state(),
          voltage: float(),
          activation_v: float(),
          inactivation_v: float(),
          calcium_current: float(),
          total_flux: float(),
          open_count: non_neg_integer()
        }

  defstruct state: :closed,
            voltage: -0.7,
            activation_v: 0.4,
            inactivation_v: 0.9,
            calcium_current: 0.0,
            total_flux: 0.0,
            open_count: 0

  @doc """
  Create a new calcium channel struct.

  Options:
    - `:activation_v`   (float in (-1.0, 1.0), default 0.4)
    - `:inactivation_v` (float, must be > activation_v, default 0.9)
    - `:resting_voltage`(float in [-1.0, 1.0], default -0.7)
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    act_v = Keyword.get(opts, :activation_v, 0.4)
    inact_v = Keyword.get(opts, :inactivation_v, 0.9)
    rest_v = Keyword.get(opts, :resting_voltage, -0.7)

    cond do
      not is_float(act_v) or act_v <= -1.0 or act_v >= 1.0 ->
        {:error, "activation_v must be in (-1.0, 1.0)"}

      not is_float(inact_v) or inact_v <= act_v ->
        {:error, "inactivation_v must be > activation_v"}

      not is_float(rest_v) or rest_v < -1.0 or rest_v > 1.0 ->
        {:error, "resting_voltage must be in [-1.0, 1.0]"}

      true ->
        {:ok,
         %__MODULE__{
           activation_v: act_v,
           inactivation_v: inact_v,
           voltage: rest_v
         }}
    end
  end

  @doc """
  Apply a voltage step to the channel.

  Transitions state according to the voltage-gated model and computes
  the calcium current if the channel is open.

  Returns `{:ok, updated_channel}`.
  """
  @spec stimulate(t(), float()) :: {:ok, t()} | {:error, String.t()}
  def stimulate(%__MODULE__{} = ch, voltage) when is_float(voltage) do
    if voltage < -1.0 or voltage > 1.0 do
      {:error, "voltage must be in [-1.0, 1.0]"}
    else
      new_state = next_state(ch.state, voltage, ch.activation_v, ch.inactivation_v)
      current = if new_state == :open, do: compute_current(voltage, ch.activation_v), else: 0.0
      opened = if new_state == :open and ch.state != :open, do: 1, else: 0

      updated = %{
        ch
        | state: new_state,
          voltage: voltage,
          calcium_current: current,
          total_flux: ch.total_flux + current,
          open_count: ch.open_count + opened
      }

      {:ok, updated}
    end
  end

  @doc """
  Repolarise the membrane to resting potential; channel closes.
  Returns `{:ok, updated_channel}`.
  """
  @spec repolarise(t()) :: {:ok, t()}
  def repolarise(%__MODULE__{} = ch) do
    {:ok, %{ch | state: :closed, voltage: -0.7, calcium_current: 0.0}}
  end

  @doc "Return a summary map of the channel's current state."
  @spec status(t()) :: map()
  def status(%__MODULE__{} = ch) do
    %{
      state: ch.state,
      voltage: Float.round(ch.voltage, 4),
      activation_v: ch.activation_v,
      inactivation_v: ch.inactivation_v,
      calcium_current: Float.round(ch.calcium_current, 4),
      total_flux: Float.round(ch.total_flux, 6),
      open_count: ch.open_count,
      is_conducting: ch.state == :open
    }
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec next_state(channel_state(), float(), float(), float()) :: channel_state()
  defp next_state(:closed, v, act_v, _inact_v) when v >= act_v, do: :open
  defp next_state(:closed, _v, _act_v, _inact_v), do: :closed
  defp next_state(:open, v, _act_v, inact_v) when v >= inact_v, do: :inactivated
  defp next_state(:open, _v, _act_v, _inact_v), do: :open
  defp next_state(:inactivated, v, act_v, _inact_v) when v < act_v, do: :closed
  defp next_state(:inactivated, _v, _act_v, _inact_v), do: :inactivated

  @spec compute_current(float(), float()) :: float()
  defp compute_current(voltage, activation_v) do
    excess = voltage - activation_v
    min(1.0, max(0.0, excess))
  end
end
