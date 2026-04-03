defmodule Indrajaal.Substrate.L1.MotorCortex do
  @moduledoc """
  ## Design Intent
  L1 substrate motor cortex — pure functional action planning and sequencing
  module. Models the brain's primary motor cortex, which maps desired outcomes
  to ordered sequences of muscle activations.

  In biology the motor cortex maintains a "motor program" — a pre-compiled
  sequence of commands that can be dispatched to the spinal cord without
  requiring conscious decision at each step. In the substrate layer, the motor
  cortex holds a prioritised action plan as an ordered queue of action items,
  each with a priority, a target actor, and optional parameters. The plan can
  be built up incrementally and then executed step-by-step by the calling layer.

  Model:
    - `plan` is a priority-sorted queue of `action_item` structs
    - `enqueue/3` inserts an item and re-sorts by priority descending
    - `next/1` pops and returns the highest-priority item
    - `cancel/2` removes an item by id
    - `flush/1` clears the entire plan

  ## STAMP Constraints
  - SC-S1-001: Cybernetic VSM S1 — ENFORCED
  - SC-S1-003: S1 operational response — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type action_id :: String.t()
  @type priority :: 0..9
  @type actor :: atom()

  @type action_item :: %{
          id: action_id(),
          action: atom(),
          actor: actor(),
          priority: priority(),
          params: map()
        }

  @type t :: %__MODULE__{
          plan: [action_item()],
          max_plan_size: pos_integer(),
          executed_count: non_neg_integer(),
          cancelled_count: non_neg_integer()
        }

  defstruct plan: [],
            max_plan_size: 64,
            executed_count: 0,
            cancelled_count: 0

  @default_max 64

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Create a new motor cortex.

  Options:
    - `:max_plan_size` (pos_integer, default 64) — maximum queued items

  Returns `{:ok, t()}` or `{:error, reason}`.
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    max = Keyword.get(opts, :max_plan_size, @default_max)

    cond do
      not is_integer(max) or max < 1 ->
        {:error, "max_plan_size must be a positive integer"}

      true ->
        {:ok, %__MODULE__{max_plan_size: max}}
    end
  end

  @doc """
  Enqueue an action item into the motor plan.

  `priority` must be an integer in 0..9 (9 = highest). Items with equal
  priority retain insertion order relative to each other.

  Options:
    - `:params` (map, default %{}) — action parameters
    - `:actor`  (atom, default :system) — target actor

  Returns `{:ok, updated_cortex}` or `{:error, reason}`.
  """
  @spec enqueue(t(), action_id(), atom(), keyword()) ::
          {:ok, t()} | {:error, atom()}
  def enqueue(cortex, id, action, opts \\ [])

  def enqueue(%__MODULE__{} = cortex, id, action, opts)
      when is_binary(id) and is_atom(action) do
    priority = Keyword.get(opts, :priority, 5)
    actor = Keyword.get(opts, :actor, :system)
    params = Keyword.get(opts, :params, %{})

    cond do
      length(cortex.plan) >= cortex.max_plan_size ->
        {:error, :plan_full}

      Enum.any?(cortex.plan, &(&1.id == id)) ->
        {:error, :duplicate_id}

      not is_integer(priority) or priority < 0 or priority > 9 ->
        {:error, :invalid_priority}

      true ->
        item = %{id: id, action: action, actor: actor, priority: priority, params: params}
        sorted = Enum.sort_by([item | cortex.plan], & &1.priority, :desc)
        {:ok, %{cortex | plan: sorted}}
    end
  end

  def enqueue(%__MODULE__{}, _id, _action, _opts), do: {:error, :invalid_args}

  @doc """
  Pop and return the next (highest-priority) action item.

  Returns `{:ok, action_item, updated_cortex}` or `{:error, :empty}`.
  """
  @spec next(t()) :: {:ok, action_item(), t()} | {:error, :empty}
  def next(%__MODULE__{plan: []}), do: {:error, :empty}

  def next(%__MODULE__{plan: [head | rest]} = cortex) do
    updated = %{cortex | plan: rest, executed_count: cortex.executed_count + 1}
    {:ok, head, updated}
  end

  @doc """
  Cancel a queued item by id.

  Returns `{:ok, updated_cortex}` or `{:error, :not_found}`.
  """
  @spec cancel(t(), action_id()) :: {:ok, t()} | {:error, :not_found}
  def cancel(%__MODULE__{} = cortex, id) when is_binary(id) do
    case Enum.find(cortex.plan, &(&1.id == id)) do
      nil ->
        {:error, :not_found}

      _found ->
        new_plan = Enum.reject(cortex.plan, &(&1.id == id))
        {:ok, %{cortex | plan: new_plan, cancelled_count: cortex.cancelled_count + 1}}
    end
  end

  @doc """
  Clear the entire action plan without executing anything.

  Returns `{:ok, updated_cortex}`.
  """
  @spec flush(t()) :: {:ok, t()}
  def flush(%__MODULE__{} = cortex) do
    cancelled = length(cortex.plan)
    {:ok, %{cortex | plan: [], cancelled_count: cortex.cancelled_count + cancelled}}
  end

  @doc """
  Returns a status map summarising the motor cortex state.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = cortex) do
    next_item = List.first(cortex.plan)

    %{
      queued: length(cortex.plan),
      max_plan_size: cortex.max_plan_size,
      executed_count: cortex.executed_count,
      cancelled_count: cortex.cancelled_count,
      next_action:
        if(next_item,
          do: %{id: next_item.id, action: next_item.action, priority: next_item.priority},
          else: nil
        )
    }
  end
end
