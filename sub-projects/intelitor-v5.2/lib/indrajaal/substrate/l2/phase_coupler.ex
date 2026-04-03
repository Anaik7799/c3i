defmodule Indrajaal.Substrate.L2.PhaseCoupler do
  @moduledoc """
  ## Design Intent
  L2 substrate phase coupler — pure functional phase synchronization between oscillators.

  Biomorphic metaphor: gap junctions between cardiac pacemaker cells that align their
  firing phases into a coherent heartbeat. Implements a discrete-time version of the
  Kuramoto model: each oscillator advances its phase at its natural frequency, but is
  pulled toward the mean phase of the ensemble with coupling strength K.

  Algorithm:
  1. Represent each oscillator as `{phase, frequency}` where phase ∈ [0, 2π).
  2. On each tick, advance phase by `frequency * dt`.
  3. Compute the Kuramoto order parameter R = |Σ exp(iθ)|/N and mean phase φ.
  4. Apply coupling: Δθᵢ += K * R * sin(φ - θᵢ).
  5. Wrap phases into [0, 2π).

  ## STAMP Constraints
  - SC-S2-001: Cybernetic VSM S2 coordination — ENFORCED
  - SC-S2-003: Subsystem synchronisation signal — ENFORCED
  - SC-BIO-001: Biomorphic substrate layer L2 — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  import :math, only: [sin: 1, cos: 1, sqrt: 1, atan2: 2]

  @two_pi 2.0 * :math.pi()

  @type oscillator :: %{phase: float(), frequency: float()}

  @type t :: %__MODULE__{
          coupling_strength: float(),
          oscillators: [oscillator()],
          order_parameter: float(),
          mean_phase: float(),
          tick_count: non_neg_integer()
        }

  defstruct coupling_strength: 0.5,
            oscillators: [],
            order_parameter: 0.0,
            mean_phase: 0.0,
            tick_count: 0

  @doc """
  Create a new PhaseCoupler.

  Options:
  - `:coupling_strength` — Kuramoto K ∈ [0.0, 10.0], default 0.5
  - `:oscillators` — list of `%{phase: float, frequency: float}`, default []
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    k = Keyword.get(opts, :coupling_strength, 0.5)
    oscillators = Keyword.get(opts, :oscillators, [])

    cond do
      not is_number(k) ->
        {:error, "coupling_strength must be a number"}

      k < 0.0 or k > 10.0 ->
        {:error, "coupling_strength must be in [0.0, 10.0]"}

      not is_list(oscillators) ->
        {:error, "oscillators must be a list"}

      true ->
        {:ok, %__MODULE__{coupling_strength: k * 1.0, oscillators: oscillators}}
    end
  end

  @doc """
  Add an oscillator with given initial phase (radians) and natural frequency (rad/tick).
  """
  @spec add_oscillator(t(), float(), float()) :: t()
  def add_oscillator(%__MODULE__{} = state, phase, frequency)
      when is_number(phase) and is_number(frequency) do
    osc = %{phase: wrap(phase * 1.0), frequency: frequency * 1.0}
    %__MODULE__{state | oscillators: state.oscillators ++ [osc]}
  end

  @doc """
  Advance all oscillators by one tick with time step `dt` (default 0.01).
  Returns the updated coupler with new phases and Kuramoto order parameter.
  """
  @spec tick(t(), float()) :: t()
  def tick(state, dt \\ 0.01)

  def tick(%__MODULE__{oscillators: []} = state, _dt), do: state

  def tick(%__MODULE__{} = state, dt) when is_number(dt) do
    {order_r, mean_phi} = kuramoto_order(state.oscillators)

    new_oscillators =
      Enum.map(state.oscillators, fn osc ->
        coupling_delta = state.coupling_strength * order_r * sin(mean_phi - osc.phase)
        new_phase = wrap(osc.phase + osc.frequency * dt + coupling_delta * dt)
        %{osc | phase: new_phase}
      end)

    %__MODULE__{
      state
      | oscillators: new_oscillators,
        order_parameter: order_r,
        mean_phase: mean_phi,
        tick_count: state.tick_count + 1
    }
  end

  @doc """
  Returns a summary map of the coupler state.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    %{
      coupling_strength: state.coupling_strength,
      oscillator_count: length(state.oscillators),
      order_parameter: state.order_parameter,
      mean_phase: state.mean_phase,
      tick_count: state.tick_count,
      synchronized: state.order_parameter >= 0.9
    }
  end

  # ── Private helpers ────────────────────────────────────────────────────────

  @spec kuramoto_order([oscillator()]) :: {float(), float()}
  defp kuramoto_order([]), do: {0.0, 0.0}

  defp kuramoto_order(oscillators) do
    n = length(oscillators)
    sum_cos = Enum.reduce(oscillators, 0.0, fn osc, acc -> acc + cos(osc.phase) end)
    sum_sin = Enum.reduce(oscillators, 0.0, fn osc, acc -> acc + sin(osc.phase) end)
    r = sqrt(sum_cos * sum_cos + sum_sin * sum_sin) / n
    phi = atan2(sum_sin / n, sum_cos / n)
    {r, phi}
  end

  @spec wrap(float()) :: float()
  defp wrap(phase) do
    phase = :math.fmod(phase, @two_pi)
    if phase < 0.0, do: phase + @two_pi, else: phase
  end
end
