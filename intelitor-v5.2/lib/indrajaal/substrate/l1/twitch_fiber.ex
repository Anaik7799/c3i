defmodule Indrajaal.Substrate.L1.TwitchFiber do
  @moduledoc """
  ## Design Intent
  L1 substrate twitch fiber — pure functional fast-response fiber unit for
  rapid, short-duration, high-intensity activations.

  Biological metaphor: Type-II fast-twitch muscle fiber. Generates maximal
  force quickly but fatigues rapidly and has a mandatory refractory period
  before re-activation is possible. Suited for burst operations, emergency
  responses, and impulse-style commands.

  Algorithm:
    - `activate/2` fires the fiber at an optional intensity (default 1.0).
    - Activation is refused if:
      (a) refractory period has not elapsed since last activation, or
      (b) accumulated fatigue >= `fatigue_cap`.
    - Each activation increments `fatigue` by `intensity × fatigue_rate`.
    - `cool_down/2` reduces fatigue by `steps × recovery_rate`, clamped to 0.
    - `ready?/2` returns true only when refractory period has elapsed.

  ## STAMP Constraints
  - SC-S1-001: Cybernetic VSM S1 subsystem actuation — ENFORCED
  - SC-S1-002: VSM S1 response latency — ENFORCED
  - SC-BIO-001: Biomorphic substrate layer L1 — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type t :: %__MODULE__{
          fatigue: float(),
          fatigue_rate: float(),
          fatigue_cap: float(),
          recovery_rate: float(),
          refractory_ms: non_neg_integer(),
          last_fired_at: integer() | nil,
          activation_count: non_neg_integer(),
          peak_intensity: float()
        }

  defstruct fatigue: 0.0,
            fatigue_rate: 0.20,
            fatigue_cap: 0.90,
            recovery_rate: 0.08,
            refractory_ms: 100,
            last_fired_at: nil,
            activation_count: 0,
            peak_intensity: 0.0

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Create a new TwitchFiber.

  Options:
    - `:fatigue_rate`   (float, default 0.20) — fatigue per unit intensity
    - `:fatigue_cap`    (float, default 0.90) — refuse activation above this fatigue
    - `:recovery_rate`  (float, default 0.08) — fatigue removed per cool-down step
    - `:refractory_ms`  (integer >= 0, default 100) — minimum ms between activations

  Returns `{:ok, t()}` or `{:error, reason}`.
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    fatigue_rate = Keyword.get(opts, :fatigue_rate, 0.20)
    fatigue_cap = Keyword.get(opts, :fatigue_cap, 0.90)
    recovery_rate = Keyword.get(opts, :recovery_rate, 0.08)
    refractory_ms = Keyword.get(opts, :refractory_ms, 100)

    cond do
      not is_float(fatigue_rate) or fatigue_rate <= 0.0 ->
        {:error, "fatigue_rate must be a positive float"}

      not is_float(fatigue_cap) or fatigue_cap <= 0.0 or fatigue_cap > 1.0 ->
        {:error, "fatigue_cap must be in (0.0, 1.0]"}

      not is_float(recovery_rate) or recovery_rate <= 0.0 ->
        {:error, "recovery_rate must be a positive float"}

      not is_integer(refractory_ms) or refractory_ms < 0 ->
        {:error, "refractory_ms must be a non-negative integer"}

      true ->
        {:ok,
         %__MODULE__{
           fatigue_rate: fatigue_rate,
           fatigue_cap: fatigue_cap,
           recovery_rate: recovery_rate,
           refractory_ms: refractory_ms
         }}
    end
  end

  @doc """
  Attempt to activate the fiber at the given intensity (default 1.0).

  Returns:
    - `{:ok, intensity, updated}` — activation succeeded
    - `{:error, :refractory}` — still within refractory period
    - `{:error, :fatigued}` — fatigue at or above cap

  Uses `System.monotonic_time(:millisecond)` as the clock source.
  """
  @spec activate(t(), float()) ::
          {:ok, float(), t()} | {:error, :refractory | :fatigued}
  def activate(fiber, intensity \\ 1.0)

  def activate(%__MODULE__{} = fiber, intensity) when is_float(intensity) do
    now = System.monotonic_time(:millisecond)
    clamped = clamp(intensity, 0.0, 1.0)

    cond do
      in_refractory?(fiber, now) ->
        {:error, :refractory}

      fiber.fatigue >= fiber.fatigue_cap ->
        {:error, :fatigued}

      true ->
        new_fatigue = clamp(fiber.fatigue + clamped * fiber.fatigue_rate, 0.0, 1.0)
        new_peak = max(fiber.peak_intensity, clamped)

        updated = %{
          fiber
          | fatigue: new_fatigue,
            last_fired_at: now,
            activation_count: fiber.activation_count + 1,
            peak_intensity: new_peak
        }

        {:ok, clamped, updated}
    end
  end

  def activate(%__MODULE__{} = _fiber, _intensity), do: {:error, :fatigued}

  @doc """
  Cool down the fiber by `steps` recovery steps (default 1).

  Each step reduces fatigue by `recovery_rate`, clamped to 0.0.

  Returns `{:ok, updated}`.
  """
  @spec cool_down(t(), non_neg_integer()) :: {:ok, t()}
  def cool_down(fiber, steps \\ 1)

  def cool_down(%__MODULE__{} = fiber, steps) when is_integer(steps) and steps >= 0 do
    reduction = steps * fiber.recovery_rate
    new_fatigue = clamp(fiber.fatigue - reduction, 0.0, 1.0)
    {:ok, %{fiber | fatigue: new_fatigue}}
  end

  def cool_down(%__MODULE__{} = fiber, _steps), do: {:ok, fiber}

  @doc """
  Returns true if the fiber is ready (not in refractory, not fatigued).

  Uses `System.monotonic_time(:millisecond)` as the clock source.
  """
  @spec ready?(t()) :: boolean()
  def ready?(%__MODULE__{} = fiber) do
    now = System.monotonic_time(:millisecond)
    not in_refractory?(fiber, now) and fiber.fatigue < fiber.fatigue_cap
  end

  @doc """
  Returns a status summary map.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = fiber) do
    now = System.monotonic_time(:millisecond)
    refractory_remaining = refractory_remaining_ms(fiber, now)

    %{
      fatigue: fiber.fatigue,
      fatigue_rate: fiber.fatigue_rate,
      fatigue_cap: fiber.fatigue_cap,
      recovery_rate: fiber.recovery_rate,
      refractory_ms: fiber.refractory_ms,
      refractory_remaining_ms: refractory_remaining,
      activation_count: fiber.activation_count,
      peak_intensity: fiber.peak_intensity,
      ready: refractory_remaining == 0 and fiber.fatigue < fiber.fatigue_cap
    }
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec in_refractory?(t(), integer()) :: boolean()
  defp in_refractory?(%__MODULE__{last_fired_at: nil}, _now), do: false

  defp in_refractory?(%__MODULE__{last_fired_at: fired, refractory_ms: ref_ms}, now) do
    now - fired < ref_ms
  end

  @spec refractory_remaining_ms(t(), integer()) :: non_neg_integer()
  defp refractory_remaining_ms(%__MODULE__{last_fired_at: nil}, _now), do: 0

  defp refractory_remaining_ms(%__MODULE__{last_fired_at: fired, refractory_ms: ref_ms}, now) do
    elapsed = now - fired
    max(0, ref_ms - elapsed)
  end

  @spec clamp(float(), float(), float()) :: float()
  defp clamp(v, lo, hi), do: max(lo, min(hi, v))
end
