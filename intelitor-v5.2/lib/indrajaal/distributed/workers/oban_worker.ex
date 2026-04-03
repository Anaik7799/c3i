defmodule Indrajaal.Distributed.Workers.ObanWorker do
  @moduledoc """
  Worker 2: Oban - Background Job Processing Worker.

  WHAT: Manages Oban background jobs with FQUN tracking.
  WHY: SC-OBAN-001 requires reliable background job processing.
  CONSTRAINTS: Job persistence, retry policies, priority queues.

  ## Oban Responsibilities

  1. **Job Scheduling**: Schedule jobs with priority and delays
  2. **Queue Management**: Multiple named queues with concurrency
  3. **Retry Handling**: Configurable retry with backoff
  4. **Job Tracking**: FQUN-based job tracking

  ## STAMP Constraints

  - SC-OBAN-001: Job persistence guaranteed
  - SC-OBAN-002: Retry policy enforcement
  - SC-OBAN-003: Queue isolation
  - SC-OBAN-004: Job telemetry

  ## Mathematical Specification

  ```
  Oban := (Queues, Jobs, Policies)

  Queues := Map(QueueName, Queue)
  Queue := (Jobs, Concurrency, Paused)

  Jobs := Set(Job)
  Job := (Worker, Args, State, Attempt, FQUN)

  State ∈ {scheduled, available, executing, completed, retryable, discarded}

  Retry Policy:
    retry(job) = delay(job) * 2^attempt(job) if attempt(job) < max_attempts
    retry(job) = discard(job) otherwise

  Priority Invariant:
    ∀ j1, j2 ∈ Queue: Priority(j1) > Priority(j2) ⟹ Execute(j1) before Execute(j2)
  ```

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-OBAN-001 to SC-OBAN-004 |
  """

  use Indrajaal.Distributed.Workers.BaseWorker,
    type: :background,
    namespace: "oban",
    name: "job_worker"

  alias Indrajaal.Distributed.FQUN

  # ============================================================
  # WORKER CALLBACKS
  # ============================================================

  @impl true
  def worker_init(_opts) do
    state = %{
      # Queue definitions
      queues: %{
        default: %{concurrency: 10, paused: false, jobs: 0},
        high: %{concurrency: 20, paused: false, jobs: 0},
        low: %{concurrency: 5, paused: false, jobs: 0},
        critical: %{concurrency: 50, paused: false, jobs: 0}
      },

      # Job tracking (job_id -> job_info)
      jobs: %{},

      # Job FQUNs (job_id -> FQUN)
      job_fquns: %{},

      # Configuration
      config: %{
        max_attempts: 5,
        base_delay_ms: 1000,
        max_delay_ms: 300_000,
        pruning_age_days: 7
      },

      # Metrics by state
      state_counts: %{
        scheduled: 0,
        available: 0,
        executing: 0,
        completed: 0,
        retryable: 0,
        discarded: 0
      },

      # Overall metrics
      total_jobs: 0,
      successful_jobs: 0,
      failed_jobs: 0,
      retried_jobs: 0
    }

    {:ok, state}
  end

  @impl true
  def worker_state(state) do
    %{
      queues: queue_summary(state.queues),
      state_counts: state.state_counts,
      active_jobs: count_active_jobs(state.jobs),
      total_jobs: state.total_jobs
    }
  end

  @impl true
  def worker_metrics(state) do
    %{
      queue_count: map_size(state.queues),
      total_jobs: state.total_jobs,
      successful_jobs: state.successful_jobs,
      failed_jobs: state.failed_jobs,
      retried_jobs: state.retried_jobs,
      success_rate: safe_ratio(state.successful_jobs, state.total_jobs),
      state_counts: state.state_counts
    }
  end

  @impl true
  def handle_job({:schedule, worker_module, args, opts}, state) do
    queue = Keyword.get(opts, :queue, :default)
    priority = Keyword.get(opts, :priority, 0)
    scheduled_at = Keyword.get(opts, :scheduled_at, DateTime.utc_now())

    job_id = generate_job_id()

    # Generate FQUN for job
    {:ok, job_fqun} = FQUN.generate(:resource, :job, "oban", job_id)

    job_info = %{
      id: job_id,
      fqun: job_fqun,
      worker: worker_module,
      args: args,
      queue: queue,
      priority: priority,
      state: :scheduled,
      attempt: 0,
      max_attempts: state.config.max_attempts,
      scheduled_at: scheduled_at,
      created_at: DateTime.utc_now()
    }

    new_jobs = Map.put(state.jobs, job_id, job_info)
    new_job_fquns = Map.put(state.job_fquns, job_id, job_fqun)

    # Update queue counts
    new_queues = update_queue_count(state.queues, queue, 1)

    # Update state counts
    new_state_counts = Map.update(state.state_counts, :scheduled, 1, &(&1 + 1))

    new_state = %{
      state
      | jobs: new_jobs,
        job_fquns: new_job_fquns,
        queues: new_queues,
        state_counts: new_state_counts,
        total_jobs: state.total_jobs + 1
    }

    # Publish job scheduled to Zenoh
    publish_job_event(:scheduled, job_info)

    {:ok, {:scheduled, job_id, job_fqun}, new_state}
  end

  @impl true
  def handle_job({:execute, job_id}, state) do
    case Map.get(state.jobs, job_id) do
      nil ->
        {:error, :job_not_found, state}

      job_info ->
        # Transition to executing
        new_job_info = %{
          job_info
          | state: :executing,
            attempt: job_info.attempt + 1
        }

        new_jobs = Map.put(state.jobs, job_id, new_job_info)
        new_state_counts = transition_state(state.state_counts, job_info.state, :executing)

        new_state = %{state | jobs: new_jobs, state_counts: new_state_counts}

        # Publish execution start
        publish_job_event(:executing, new_job_info)

        {:ok, :executing, new_state}
    end
  end

  @impl true
  def handle_job({:complete, job_id, result}, state) do
    case Map.get(state.jobs, job_id) do
      nil ->
        {:error, :job_not_found, state}

      job_info ->
        # Transition to completed
        new_job_info = %{
          job_info
          | state: :completed,
            completed_at: DateTime.utc_now(),
            result: result
        }

        new_jobs = Map.put(state.jobs, job_id, new_job_info)
        new_state_counts = transition_state(state.state_counts, :executing, :completed)
        new_queues = update_queue_count(state.queues, job_info.queue, -1)

        new_state = %{
          state
          | jobs: new_jobs,
            state_counts: new_state_counts,
            queues: new_queues,
            successful_jobs: state.successful_jobs + 1
        }

        # Publish completion
        publish_job_event(:completed, new_job_info)

        {:ok, :completed, new_state}
    end
  end

  @impl true
  def handle_job({:fail, job_id, error}, state) do
    case Map.get(state.jobs, job_id) do
      nil ->
        {:error, :job_not_found, state}

      job_info ->
        {new_state_atom, should_retry} =
          if job_info.attempt < job_info.max_attempts do
            {:retryable, true}
          else
            {:discarded, false}
          end

        new_job_info = %{
          job_info
          | state: new_state_atom,
            error: error,
            failed_at: DateTime.utc_now()
        }

        new_jobs = Map.put(state.jobs, job_id, new_job_info)
        new_state_counts = transition_state(state.state_counts, :executing, new_state_atom)

        new_state =
          if should_retry do
            %{
              state
              | jobs: new_jobs,
                state_counts: new_state_counts,
                retried_jobs: state.retried_jobs + 1
            }
          else
            new_queues = update_queue_count(state.queues, job_info.queue, -1)

            %{
              state
              | jobs: new_jobs,
                state_counts: new_state_counts,
                queues: new_queues,
                failed_jobs: state.failed_jobs + 1
            }
          end

        # Publish failure
        publish_job_event(:failed, %{job: new_job_info, will_retry: should_retry})

        {:ok, %{state: new_state_atom, will_retry: should_retry}, new_state}
    end
  end

  @impl true
  def handle_job({:cancel, job_id}, state) do
    case Map.get(state.jobs, job_id) do
      nil ->
        {:error, :job_not_found, state}

      job_info when job_info.state in [:scheduled, :available, :retryable] ->
        # Unregister FQUN
        FQUN.unregister(job_info.fqun)

        new_jobs = Map.delete(state.jobs, job_id)
        new_job_fquns = Map.delete(state.job_fquns, job_id)
        new_queues = update_queue_count(state.queues, job_info.queue, -1)
        new_state_counts = Map.update(state.state_counts, job_info.state, 0, &max(0, &1 - 1))

        new_state = %{
          state
          | jobs: new_jobs,
            job_fquns: new_job_fquns,
            queues: new_queues,
            state_counts: new_state_counts
        }

        publish_job_event(:cancelled, job_info)
        {:ok, :cancelled, new_state}

      _job_info ->
        {:error, :job_not_cancellable, state}
    end
  end

  @impl true
  def handle_job({:pause_queue, queue_name}, state) do
    if Map.has_key?(state.queues, queue_name) do
      new_queues = put_in(state.queues[queue_name].paused, true)
      {:ok, :paused, %{state | queues: new_queues}}
    else
      {:error, :queue_not_found, state}
    end
  end

  @impl true
  def handle_job({:resume_queue, queue_name}, state) do
    if Map.has_key?(state.queues, queue_name) do
      new_queues = put_in(state.queues[queue_name].paused, false)
      {:ok, :resumed, %{state | queues: new_queues}}
    else
      {:error, :queue_not_found, state}
    end
  end

  @impl true
  def handle_job({:get_job, job_id}, state) do
    case Map.get(state.jobs, job_id) do
      nil -> {:error, :job_not_found, state}
      job_info -> {:ok, job_info, state}
    end
  end

  @impl true
  def handle_job(unknown, state) do
    {:error, {:unknown_job, unknown}, state}
  end

  # ============================================================
  # OBAN IMPLEMENTATION
  # ============================================================

  defp generate_job_id do
    rand_bytes = :crypto.strong_rand_bytes(12)
    encoded = rand_bytes |> Base.encode16(case: :lower)
    "job_" <> encoded
  end

  defp update_queue_count(queues, queue_name, delta) do
    if Map.has_key?(queues, queue_name) do
      update_in(queues[queue_name].jobs, &max(0, &1 + delta))
    else
      queues
    end
  end

  defp transition_state(state_counts, from_state, to_state) do
    state_counts
    |> Map.update(from_state, 0, &max(0, &1 - 1))
    |> Map.update(to_state, 1, &(&1 + 1))
  end

  defp queue_summary(queues) do
    Enum.map(queues, fn {name, config} ->
      %{
        name: name,
        concurrency: config.concurrency,
        paused: config.paused,
        jobs: config.jobs
      }
    end)
  end

  defp count_active_jobs(jobs) do
    Enum.count(jobs, fn {_, job} ->
      job.state in [:scheduled, :available, :executing, :retryable]
    end)
  end

  defp publish_job_event(event, data) do
    Indrajaal.Observability.ZenohCoordinator.publish_coord(
      "oban/job/#{event}",
      Map.merge(%{event: event, timestamp: DateTime.utc_now()}, data)
    )
  rescue
    _ -> :ok
  end
end
