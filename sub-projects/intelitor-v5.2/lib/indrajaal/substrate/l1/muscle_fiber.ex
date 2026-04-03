defmodule Indrajaal.Substrate.L1.MuscleFiber do
  @moduledoc """
  ## Design Intent
  L1 substrate muscle fiber — pure functional actuator module wrapping system
  action execution with force limiting and fatigue tracking. Inspired by
  biological muscle physiology where repeated maximal contractions deplete
  ATP and degrade force output.

  Fatigue model:
    - Each action execution at `force` level increments fatigue by `force × cost_factor`
    - Fatigue is normalised to [0.0, 1.0] where 1.0 = fully exhausted
    - Effective force = requested_force × (1.0 - fatigue_level)
    - `recover/1` decreases fatigue by `recovery_rate` (default 0.1 per call)
    - When fatigue >= `fatigue_threshold` (default 0.9), actions are refused

  Force limiting:
    - Maximum requestable force is `max_force` (default 1.0)
    - Requested force is clamped to [0.0, max_force]
    - Effective force is always <= max_force

  Available actions are defined at module build time via `@known_actions`.
  Unknown action atoms return `{:error, :unknown_action}`.

  All functions are pure — the fiber struct is explicit state passed in and
  returned. No GenServer, no side effects.

  ## STAMP Constraints
  - SC-BIO-001: Biomorphic substrate layer L1 — ENFORCED
  - SC-S1-001:  Cybernetic VSM S1 subsystem actuation — ENFORCED
  - SC-S1-003:  S1 operational response — ENFORCED
  - SC-S1-004:  S1 resource management — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type action :: atom()
  @type force :: float()
  @type fatigue :: float()

  @type t :: %__MODULE__{
          fatigue_level: fatigue(),
          max_force: force(),
          cost_factor: float(),
          recovery_rate: float(),
          fatigue_threshold: float(),
          execution_count: non_neg_integer(),
          last_action: action() | nil,
          last_force: force()
        }

  defstruct fatigue_level: 0.0,
            max_force: 1.0,
            cost_factor: 0.15,
            recovery_rate: 0.10,
            fatigue_threshold: 0.90,
            execution_count: 0,
            last_action: nil,
            last_force: 0.0

  # Built-in known actions (extensible via register_reflex or custom atoms)
  @known_actions [
    :alert,
    :broadcast,
    :checkpoint,
    :compress,
    :dispatch,
    :evict,
    :gc,
    :heal,
    :index,
    :kill_process,
    :log,
    :migrate,
    :notify,
    :pause,
    :reconnect,
    :restart,
    :retry,
    :scale_down,
    :scale_up,
    :shutdown,
    :snapshot,
    :sync,
    :throttle,
    :unthrottle,
    :upgrade
  ]

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Create a new muscle fiber struct.

  Options:
    - `:max_force`          (float, default 1.0)
    - `:cost_factor`        (float, default 0.15) — fatigue per unit force
    - `:recovery_rate`      (float, default 0.10) — fatigue removed per `recover/1`
    - `:fatigue_threshold`  (float, default 0.90) — refuse actions above this level

  Returns `{:ok, t()}` or `{:error, reason}`.
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    max_force = Keyword.get(opts, :max_force, 1.0)
    cost_factor = Keyword.get(opts, :cost_factor, 0.15)
    recovery_rate = Keyword.get(opts, :recovery_rate, 0.10)
    fatigue_threshold = Keyword.get(opts, :fatigue_threshold, 0.90)

    cond do
      not is_float(max_force) or max_force <= 0.0 ->
        {:error, "max_force must be a positive float"}

      not is_float(cost_factor) or cost_factor <= 0.0 ->
        {:error, "cost_factor must be a positive float"}

      not is_float(recovery_rate) or recovery_rate <= 0.0 ->
        {:error, "recovery_rate must be a positive float"}

      not is_float(fatigue_threshold) or fatigue_threshold <= 0.0 or fatigue_threshold > 1.0 ->
        {:error, "fatigue_threshold must be in (0.0, 1.0]"}

      true ->
        {:ok,
         %__MODULE__{
           max_force: max_force,
           cost_factor: cost_factor,
           recovery_rate: recovery_rate,
           fatigue_threshold: fatigue_threshold
         }}
    end
  end

  @doc """
  Execute an action at the requested force level.

  Returns:
    - `{:ok, effective_force, updated_fiber}` — action executed
    - `{:error, :unknown_action}`             — action not in known set
    - `{:error, :fatigue_exceeded}`           — fiber too exhausted to act

  `effective_force` = `requested_force × (1.0 - fatigue_level)`, clamped to
  `[0.0, max_force]`.
  """
  @spec execute(t(), action(), force()) ::
          {:ok, force(), t()} | {:error, :unknown_action | :fatigue_exceeded}
  def execute(fiber, action, requested_force \\ 1.0)

  def execute(%__MODULE__{} = fiber, action, requested_force)
      when is_atom(action) and is_float(requested_force) do
    cond do
      action not in @known_actions ->
        {:error, :unknown_action}

      fiber.fatigue_level >= fiber.fatigue_threshold ->
        {:error, :fatigue_exceeded}

      true ->
        clamped_force = clamp(requested_force, 0.0, fiber.max_force)
        effective_force = clamped_force * (1.0 - fiber.fatigue_level)
        fatigue_increase = clamped_force * fiber.cost_factor
        new_fatigue = clamp(fiber.fatigue_level + fatigue_increase, 0.0, 1.0)

        updated = %{
          fiber
          | fatigue_level: new_fatigue,
            execution_count: fiber.execution_count + 1,
            last_action: action,
            last_force: effective_force
        }

        {:ok, effective_force, updated}
    end
  end

  @doc """
  Returns the current fatigue level of the fiber (0.0 = fresh, 1.0 = exhausted).
  """
  @spec fatigue_level(t()) :: fatigue()
  def fatigue_level(%__MODULE__{fatigue_level: f}), do: f

  @doc """
  Reduce fatigue by one `recovery_rate` step.

  Returns `{:ok, updated_fiber}`.
  """
  @spec recover(t()) :: {:ok, t()}
  def recover(%__MODULE__{} = fiber) do
    new_fatigue = clamp(fiber.fatigue_level - fiber.recovery_rate, 0.0, 1.0)
    {:ok, %{fiber | fatigue_level: new_fatigue}}
  end

  @doc """
  Returns the list of known action atoms this fiber can execute.
  """
  @spec available_actions() :: [action()]
  def available_actions, do: @known_actions

  @doc """
  Returns a status map summarising the fiber's current state.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = fiber) do
    %{
      fatigue_level: fiber.fatigue_level,
      max_force: fiber.max_force,
      cost_factor: fiber.cost_factor,
      recovery_rate: fiber.recovery_rate,
      fatigue_threshold: fiber.fatigue_threshold,
      execution_count: fiber.execution_count,
      last_action: fiber.last_action,
      last_force: fiber.last_force,
      is_exhausted: fiber.fatigue_level >= fiber.fatigue_threshold,
      available_actions_count: length(@known_actions)
    }
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec clamp(float(), float(), float()) :: float()
  defp clamp(v, lo, hi), do: max(lo, min(hi, v))
end
