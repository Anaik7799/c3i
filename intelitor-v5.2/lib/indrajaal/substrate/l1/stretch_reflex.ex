defmodule Indrajaal.Substrate.L1.StretchReflex do
  @moduledoc """
  ## Design Intent
  L1 substrate stretch reflex — pure functional automatic response arc that
  evaluates a stimulus against threshold rules and fires a corrective action
  without involving higher-level cognition.

  The biological stretch reflex (monosynaptic reflex) bypasses the brain: a
  muscle spindle detects over-stretch and sends a signal directly to the spinal
  interneuron, which commands the same muscle to contract — all within ~30 ms.
  In the substrate layer, a stretch reflex monitors a continuously updated
  metric value and fires a `response_action` whenever the value crosses a
  `trigger_threshold`. A `refractory_period` (in samples) prevents continuous
  re-triggering.

  Model:
    - Each call to `update/2` feeds a new sample value
    - If `value >= trigger_threshold` and the arc is not in refractory period,
      `fire?` → true and the refractory counter resets
    - If `value < trigger_threshold`, the refractory counter decrements by 1
    - `reset/1` clears history and refractory state

  ## STAMP Constraints
  - SC-S1-001: Cybernetic VSM S1 — ENFORCED
  - SC-S1-002: S1 operational responsiveness — ENFORCED
  - SC-DMS-002: Failsafe triggers within 50ms — REFERENCE
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type t :: %__MODULE__{
          trigger_threshold: float(),
          response_action: atom(),
          refractory_period: non_neg_integer(),
          refractory_remaining: non_neg_integer(),
          last_value: float() | nil,
          fire_count: non_neg_integer(),
          sample_count: non_neg_integer()
        }

  defstruct trigger_threshold: 0.80,
            response_action: :alert,
            refractory_period: 3,
            refractory_remaining: 0,
            last_value: nil,
            fire_count: 0,
            sample_count: 0

  @default_threshold 0.80
  @default_refractory 3

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Create a new stretch reflex arc.

  Options:
    - `:trigger_threshold` (float in (0.0, 1.0], default 0.80)
    - `:response_action`   (atom, default :alert)
    - `:refractory_period` (non_neg_integer, default 3) — samples to skip after firing

  Returns `{:ok, t()}` or `{:error, reason}`.
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    threshold = Keyword.get(opts, :trigger_threshold, @default_threshold)
    action = Keyword.get(opts, :response_action, :alert)
    refractory = Keyword.get(opts, :refractory_period, @default_refractory)

    cond do
      not is_float(threshold) or threshold <= 0.0 or threshold > 1.0 ->
        {:error, "trigger_threshold must be a float in (0.0, 1.0]"}

      not is_atom(action) ->
        {:error, "response_action must be an atom"}

      not is_integer(refractory) or refractory < 0 ->
        {:error, "refractory_period must be a non-negative integer"}

      true ->
        {:ok,
         %__MODULE__{
           trigger_threshold: threshold,
           response_action: action,
           refractory_period: refractory
         }}
    end
  end

  @doc """
  Feed a new sample value into the reflex arc.

  Returns:
    - `{:fired, response_action, updated_arc}` — threshold exceeded and not in
      refractory period; caller should execute `response_action`
    - `{:ok, updated_arc}` — no firing (below threshold or in refractory)

  `value` must be a float in [0.0, 1.0].
  """
  @spec update(t(), float()) ::
          {:fired, atom(), t()} | {:ok, t()} | {:error, String.t()}
  def update(%__MODULE__{} = arc, value)
      when is_float(value) and value >= 0.0 and value <= 1.0 do
    new_count = arc.sample_count + 1
    arc = %{arc | last_value: value, sample_count: new_count}

    cond do
      arc.refractory_remaining > 0 ->
        # Still refractory — decrement and suppress firing
        {:ok, %{arc | refractory_remaining: arc.refractory_remaining - 1}}

      value >= arc.trigger_threshold ->
        # Threshold breached — fire and enter refractory
        updated = %{
          arc
          | fire_count: arc.fire_count + 1,
            refractory_remaining: arc.refractory_period
        }

        {:fired, arc.response_action, updated}

      true ->
        {:ok, arc}
    end
  end

  def update(%__MODULE__{}, _value),
    do: {:error, "value must be a float in [0.0, 1.0]"}

  @doc """
  Reset the arc to ground state (clears refractory counter and history).

  Returns `{:ok, updated_arc}`.
  """
  @spec reset(t()) :: {:ok, t()}
  def reset(%__MODULE__{} = arc) do
    {:ok,
     %{
       arc
       | refractory_remaining: 0,
         last_value: nil,
         fire_count: 0,
         sample_count: 0
     }}
  end

  @doc """
  Returns true when the arc is currently in its refractory (suppressed) period.
  """
  @spec refractory?(t()) :: boolean()
  def refractory?(%__MODULE__{refractory_remaining: r}), do: r > 0

  @doc """
  Returns a status map summarising the arc state.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = arc) do
    %{
      trigger_threshold: arc.trigger_threshold,
      response_action: arc.response_action,
      refractory_period: arc.refractory_period,
      refractory_remaining: arc.refractory_remaining,
      is_refractory: refractory?(arc),
      last_value: arc.last_value,
      fire_count: arc.fire_count,
      sample_count: arc.sample_count,
      fire_rate_pct:
        if arc.sample_count > 0 do
          Float.round(arc.fire_count / arc.sample_count * 100.0, 1)
        else
          0.0
        end
    }
  end
end
