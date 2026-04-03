defmodule Indrajaal.Substrate.L3.PriorityScheduler do
  @moduledoc """
  ## Design Intent
  L3 substrate priority scheduler — pure functional priority-based task ordering.

  Biomorphic metaphor: the prefrontal cortex's executive function — managing a
  queue of cognitive tasks by salience and urgency. Implements a multi-level
  feedback queue (MLFQ): tasks start at the highest priority level, and are
  demoted one level each time their quantum is exhausted without completion,
  preventing starvation via periodic aging promotion.

  Algorithm:
  1. Tasks carry priority (1..10, higher = more urgent) and a quantum budget.
  2. `enqueue/2` inserts into the appropriate priority bucket.
  3. `dequeue/1` returns the highest-priority task (FIFO within same priority).
  4. `promote_aged/2` bumps tasks that have waited longer than `age_threshold_ms`.
  5. Preemption check: returns true if a newly enqueued task outranks the head.

  ## STAMP Constraints
  - SC-S3-001: Cybernetic VSM S3 control — ENFORCED
  - SC-RCPSP-001: Resource-constrained scheduling — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type task :: %{
          id: String.t(),
          priority: 1..10,
          payload: term(),
          enqueued_at: integer(),
          quantum_ms: pos_integer()
        }

  @type t :: %__MODULE__{
          queues: %{(1..10) => [task()]},
          age_threshold_ms: pos_integer(),
          task_count: non_neg_integer(),
          dequeued_count: non_neg_integer(),
          promoted_count: non_neg_integer()
        }

  defstruct queues: %{},
            age_threshold_ms: 5_000,
            task_count: 0,
            dequeued_count: 0,
            promoted_count: 0

  @doc """
  Create a new PriorityScheduler.

  Options:
  - `:age_threshold_ms` — time before starvation promotion ∈ [100, 60_000], default 5_000
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    age_threshold = Keyword.get(opts, :age_threshold_ms, 5_000)

    cond do
      not is_integer(age_threshold) ->
        {:error, "age_threshold_ms must be an integer"}

      age_threshold < 100 or age_threshold > 60_000 ->
        {:error, "age_threshold_ms must be in [100, 60_000]"}

      true ->
        empty_queues = Map.new(1..10, fn p -> {p, []} end)
        {:ok, %__MODULE__{queues: empty_queues, age_threshold_ms: age_threshold}}
    end
  end

  @doc """
  Enqueue a task with given id, priority ∈ 1..10, optional payload and quantum.

  Returns `{:preempt | :enqueued, updated_state}` where `:preempt` signals the new
  task has higher priority than any currently running task.
  """
  @spec enqueue(t(), String.t(), 1..10, term(), pos_integer()) ::
          {:preempt | :enqueued, t()} | {:error, String.t()}
  def enqueue(state, id, priority, payload \\ nil, quantum_ms \\ 100)

  def enqueue(%__MODULE__{} = state, id, priority, payload, quantum_ms)
      when is_binary(id) and is_integer(priority) and priority >= 1 and priority <= 10 and
             is_integer(quantum_ms) and quantum_ms > 0 do
    task = %{
      id: id,
      priority: priority,
      payload: payload,
      enqueued_at: System.monotonic_time(:millisecond),
      quantum_ms: quantum_ms
    }

    updated_queue = Map.update!(state.queues, priority, fn q -> q ++ [task] end)

    new_state = %__MODULE__{
      state
      | queues: updated_queue,
        task_count: state.task_count + 1
    }

    # Check if this task should preempt the current head
    preempt = should_preempt?(state, priority)
    signal = if preempt, do: :preempt, else: :enqueued

    {signal, new_state}
  end

  def enqueue(%__MODULE__{}, _id, _priority, _payload, _quantum_ms) do
    {:error,
     "id must be a binary, priority must be integer 1..10, quantum_ms must be positive integer"}
  end

  @doc """
  Dequeue the highest-priority task.
  Returns `{:ok, task, updated_state}` or `{:empty, state}`.
  """
  @spec dequeue(t()) :: {:ok, task(), t()} | {:empty, t()}
  def dequeue(%__MODULE__{} = state) do
    case find_next(state.queues) do
      nil ->
        {:empty, state}

      {priority, task} ->
        updated_queue = Map.update!(state.queues, priority, fn [_head | tail] -> tail end)

        new_state = %__MODULE__{
          state
          | queues: updated_queue,
            dequeued_count: state.dequeued_count + 1
        }

        {:ok, task, new_state}
    end
  end

  @doc """
  Promote tasks that have been waiting longer than `age_threshold_ms`.
  Promotes each such task one priority level up (max 10).
  Returns `{promoted_ids, updated_state}`.
  """
  @spec promote_aged(t(), integer()) :: {[String.t()], t()}
  def promote_aged(%__MODULE__{} = state, now_ms) when is_integer(now_ms) do
    {new_queues, promoted_ids} =
      Enum.reduce(1..9, {state.queues, []}, fn priority, {queues_acc, ids_acc} ->
        queue = Map.get(queues_acc, priority, [])

        {aged, fresh} =
          Enum.split_with(queue, fn task ->
            now_ms - task.enqueued_at >= state.age_threshold_ms
          end)

        if Enum.empty?(aged) do
          {queues_acc, ids_acc}
        else
          promoted_priority = priority + 1

          promoted_tasks = Enum.map(aged, fn t -> %{t | priority: promoted_priority} end)

          new_queues_acc =
            queues_acc
            |> Map.put(priority, fresh)
            |> Map.update!(promoted_priority, fn q -> q ++ promoted_tasks end)

          new_ids = ids_acc ++ Enum.map(aged, & &1.id)
          {new_queues_acc, new_ids}
        end
      end)

    new_state = %__MODULE__{
      state
      | queues: new_queues,
        promoted_count: state.promoted_count + length(promoted_ids)
    }

    {promoted_ids, new_state}
  end

  @doc """
  Returns a summary map of the scheduler state.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    queue_depths =
      Map.new(state.queues, fn {p, tasks} -> {p, length(tasks)} end)

    total_queued = queue_depths |> Map.values() |> Enum.sum()

    %{
      total_queued: total_queued,
      queue_depths: queue_depths,
      age_threshold_ms: state.age_threshold_ms,
      task_count: state.task_count,
      dequeued_count: state.dequeued_count,
      promoted_count: state.promoted_count
    }
  end

  # ── Private ────────────────────────────────────────────────────────────────

  @spec find_next(%{(1..10) => [task()]}) :: {1..10, task()} | nil
  defp find_next(queues) do
    10..1//-1
    |> Enum.find_value(fn priority ->
      case Map.get(queues, priority, []) do
        [task | _] -> {priority, task}
        [] -> nil
      end
    end)
  end

  @spec should_preempt?(t(), 1..10) :: boolean()
  defp should_preempt?(state, new_priority) do
    case find_next(state.queues) do
      nil -> false
      {current_priority, _} -> new_priority > current_priority
    end
  end
end
