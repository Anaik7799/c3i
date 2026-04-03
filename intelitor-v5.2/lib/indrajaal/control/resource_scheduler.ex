defmodule Indrajaal.Control.ResourceScheduler do
  @moduledoc """
  L3 Control Layer — resource-constrained task scheduling.

  ## Design Intent
  Maintains a priority-ordered queue of tasks using `:gb_trees` for O(log n)
  insert and min-extraction.  Priority keys are composed as
  `{urgency_inverse, deadline_unix, insertion_seq}` so tasks with lower
  numeric urgency (higher priority) and earlier deadlines sort first.

  Before dispatching a task the scheduler verifies that sufficient resources
  are available (via BudgetAllocator read).  If resources are insufficient the
  task stays queued.  On successful dispatch a PubSub message is broadcast on
  `"control:scheduled"`.

  ## STAMP Constraints
  - SC-RCPSP-001: Resource constraints MUST be checked before dispatch
  - SC-ORCH-001: Task creation MUST coordinate Prajna/Smriti/Chaya
  - SC-S3-001: Budget enforcement is upstream of this module
  - SC-BUS-001: PubSub dispatch notification is async

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation (L3 control layer) |
  """

  use GenServer

  require Logger

  alias Indrajaal.Control.BudgetAllocator

  @pubsub Indrajaal.PubSub
  @scheduled_topic "control:scheduled"
  @dispatch_interval_ms 500

  @type priority :: :critical | :high | :normal | :low

  @type task :: %{
          id: reference(),
          domain: atom(),
          action: term(),
          priority: priority(),
          deadline: DateTime.t() | nil,
          required_cpu_pct: non_neg_integer(),
          required_memory_mb: non_neg_integer(),
          required_processes: non_neg_integer(),
          enqueued_at: DateTime.t()
        }

  @type dispatch_result :: %{
          task_id: reference(),
          domain: atom(),
          dispatched_at: DateTime.t(),
          wait_ms: non_neg_integer()
        }

  @type scheduler_state :: %{
          queue: :gb_trees.tree(),
          seq: non_neg_integer(),
          metrics: %{
            enqueued: non_neg_integer(),
            dispatched: non_neg_integer(),
            resource_blocked: non_neg_integer()
          }
        }

  @priority_weight %{critical: 0, high: 1, normal: 2, low: 3}

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc "Start the ResourceScheduler GenServer."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Enqueue a task for resource-constrained scheduling.

  `task_spec` map keys:
  - `:domain` (required atom)
  - `:action` (required term)
  - `:priority` — `:critical | :high | :normal | :low` (default `:normal`)
  - `:deadline` — `DateTime.t()` or `nil`
  - `:required_cpu_pct` — default `0`
  - `:required_memory_mb` — default `0`
  - `:required_processes` — default `0`

  Returns `{:ok, task_id}`.
  """
  @spec enqueue(map()) :: {:ok, reference()} | {:error, term()}
  def enqueue(%{domain: _domain, action: _action} = task_spec) do
    GenServer.call(__MODULE__, {:enqueue, task_spec})
  end

  def enqueue(_), do: {:error, :missing_required_fields}

  @doc "Return the current queue depth."
  @spec queue_depth() :: non_neg_integer()
  def queue_depth do
    GenServer.call(__MODULE__, :queue_depth)
  end

  @doc "Return current scheduler metrics."
  @spec metrics() :: map()
  def metrics do
    GenServer.call(__MODULE__, :metrics)
  end

  @doc "Trigger an immediate dispatch cycle (useful for testing)."
  @spec dispatch_now() :: :ok
  def dispatch_now do
    GenServer.cast(__MODULE__, :dispatch_now)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :dispatch_interval_ms, @dispatch_interval_ms)

    state = %{
      queue: :gb_trees.empty(),
      seq: 0,
      dispatch_interval_ms: interval,
      metrics: %{enqueued: 0, dispatched: 0, resource_blocked: 0}
    }

    schedule_dispatch(interval)
    Logger.info("[ResourceScheduler] L3 resource scheduler started (SC-RCPSP-001)")
    {:ok, state}
  end

  @impl true
  def handle_call({:enqueue, task_spec}, _from, state) do
    task_id = make_ref()

    task = %{
      id: task_id,
      domain: Map.fetch!(task_spec, :domain),
      action: Map.fetch!(task_spec, :action),
      priority: Map.get(task_spec, :priority, :normal),
      deadline: Map.get(task_spec, :deadline),
      required_cpu_pct: Map.get(task_spec, :required_cpu_pct, 0),
      required_memory_mb: Map.get(task_spec, :required_memory_mb, 0),
      required_processes: Map.get(task_spec, :required_processes, 0),
      enqueued_at: DateTime.utc_now()
    }

    key = priority_key(task, state.seq)
    new_queue = :gb_trees.insert(key, task, state.queue)
    new_seq = state.seq + 1
    new_metrics = Map.update!(state.metrics, :enqueued, &(&1 + 1))

    emit_telemetry(:enqueue, %{domain: task.domain, priority: task.priority})
    {:reply, {:ok, task_id}, %{state | queue: new_queue, seq: new_seq, metrics: new_metrics}}
  end

  @impl true
  def handle_call(:queue_depth, _from, state) do
    {:reply, :gb_trees.size(state.queue), state}
  end

  @impl true
  def handle_call(:metrics, _from, state) do
    {:reply, Map.put(state.metrics, :queue_depth, :gb_trees.size(state.queue)), state}
  end

  @impl true
  def handle_cast(:dispatch_now, state) do
    new_state = run_dispatch_cycle(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:dispatch_tick, state) do
    new_state = run_dispatch_cycle(state)
    schedule_dispatch(state.dispatch_interval_ms)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp run_dispatch_cycle(state) do
    if :gb_trees.is_empty(state.queue) do
      state
    else
      {_key, task, remaining_queue} = :gb_trees.take_smallest(state.queue)
      attempt_dispatch(task, %{state | queue: remaining_queue})
    end
  end

  defp attempt_dispatch(task, state) do
    case check_resources(task) do
      :ok ->
        dispatch_task(task, state)

      {:error, :insufficient_resources} ->
        # Requeue the task — put it back
        key = priority_key(task, state.seq)
        requeued = :gb_trees.insert(key, task, state.queue)
        new_metrics = Map.update!(state.metrics, :resource_blocked, &(&1 + 1))

        Logger.debug(
          "[ResourceScheduler] Resource-blocked domain=#{task.domain} action=#{inspect(task.action)}"
        )

        %{state | queue: requeued, seq: state.seq + 1, metrics: new_metrics}
    end
  end

  defp dispatch_task(task, state) do
    now = DateTime.utc_now()
    wait_ms = DateTime.diff(now, task.enqueued_at, :millisecond)

    result = %{
      task_id: task.id,
      domain: task.domain,
      action: task.action,
      dispatched_at: now,
      wait_ms: wait_ms
    }

    broadcast_scheduled(result)
    emit_telemetry(:dispatch, %{domain: task.domain, wait_ms: wait_ms})

    Logger.debug("[ResourceScheduler] Dispatched domain=#{task.domain} wait_ms=#{wait_ms}")

    new_metrics = Map.update!(state.metrics, :dispatched, &(&1 + 1))
    %{state | metrics: new_metrics}
  end

  @spec check_resources(task()) :: :ok | {:error, :insufficient_resources}
  defp check_resources(task) do
    if task.required_cpu_pct == 0 and task.required_memory_mb == 0 and
         task.required_processes == 0 do
      :ok
    else
      case BudgetAllocator.get_allocation(task.domain) do
        nil ->
          # No allocation on record — allow if requirements are modest
          if task.required_cpu_pct <= 10 and task.required_memory_mb <= 64,
            do: :ok,
            else: {:error, :insufficient_resources}

        alloc ->
          if alloc.cpu_pct >= task.required_cpu_pct and
               alloc.memory_mb >= task.required_memory_mb and
               alloc.process_count >= task.required_processes do
            :ok
          else
            {:error, :insufficient_resources}
          end
      end
    end
  rescue
    _ -> :ok
  end

  # Build a gb_trees key that sorts by priority first, then deadline, then seq.
  # Lower numeric value = higher scheduling priority.
  @spec priority_key(task(), non_neg_integer()) ::
          {non_neg_integer(), non_neg_integer(), non_neg_integer()}
  defp priority_key(task, seq) do
    weight = Map.get(@priority_weight, task.priority, 2)

    deadline_unix =
      case task.deadline do
        %DateTime{} = dt -> DateTime.to_unix(dt)
        nil -> 9_999_999_999
      end

    {weight, deadline_unix, seq}
  end

  defp broadcast_scheduled(result) do
    try do
      Phoenix.PubSub.broadcast(@pubsub, @scheduled_topic, {:task_scheduled, result})
    rescue
      _ -> :ok
    end
  end

  defp schedule_dispatch(interval) do
    Process.send_after(self(), :dispatch_tick, interval)
  end

  defp emit_telemetry(event, measurements) do
    :telemetry.execute(
      [:indrajaal, :control, :resource_scheduler, event],
      measurements,
      %{timestamp: DateTime.utc_now()}
    )
  end
end
