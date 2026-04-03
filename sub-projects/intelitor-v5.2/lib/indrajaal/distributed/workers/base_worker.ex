defmodule Indrajaal.Distributed.Workers.BaseWorker do
  @moduledoc """
  Base Worker Behaviour for Distributed Mesh Workers.

  WHAT: Provides common functionality for all mesh workers.
  WHY: SC-WORKER-001 requires consistent worker interface and lifecycle.
  CONSTRAINTS: All workers MUST implement callbacks and register FQUN.

  ## Required Callbacks

  - `handle_job/2` - Process individual jobs
  - `worker_init/1` - Worker-specific initialization
  - `worker_state/1` - Get worker-specific state
  - `worker_metrics/1` - Get worker metrics

  ## Provided Functionality

  - FQUN registration and lifecycle
  - Job queue management
  - State publishing to Zenoh
  - Telemetry integration
  - Backpressure handling

  ## STAMP Constraints

  - SC-WORKER-001: Consistent worker interface
  - SC-WORKER-002: FQUN registration mandatory
  - SC-WORKER-003: Job metrics tracking
  - SC-WORKER-004: Graceful shutdown

  ## Mathematical Specification

  ```
  Worker := (Queue, State, Metrics)

  Queue: FIFO(Job)
  State: WorkerState × JobState

  Processing Invariant:
    ∀ job ∈ Queue: Eventually(Processed(job) ∨ Failed(job))

  Backpressure:
    |Queue| > MaxQueueSize ⟹ Reject(new_jobs)
  ```

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-WORKER-001, SC-WORKER-002 |
  """

  @callback handle_job(job :: term(), state :: map()) ::
              {:ok, result :: term(), new_state :: map()}
              | {:error, reason :: term(), state :: map()}
              | {:retry, reason :: term(), state :: map()}

  @callback worker_init(opts :: keyword()) :: {:ok, state :: map()} | {:error, term()}

  @callback worker_state(state :: map()) :: map()

  @callback worker_metrics(state :: map()) :: map()

  @callback handle_worker_info(msg :: term(), state :: map()) ::
              {:ok, new_state :: map()}
              | {:noreply, new_state :: map()}
              | :ignore

  defmacro __using__(opts) do
    quote location: :keep do
      use GenServer
      require Logger

      alias Indrajaal.Distributed.FQUN

      @behaviour Indrajaal.Distributed.Workers.BaseWorker

      @heartbeat_interval_ms 10_000
      @state_publish_interval_ms 30_000
      @max_queue_size 1000
      @worker_opts unquote(opts)

      unquote(client_api())
      unquote(genserver_callbacks())
      unquote(private_functions())

      # Default implementation for custom message handling
      def handle_worker_info(_msg, _state), do: :ignore

      defoverridable handle_worker_info: 2
    end
  end

  # Split: Client API section
  defp client_api do
    quote do
      # ============================================================
      # CLIENT API
      # ============================================================

      def start_link(opts) do
        merged_opts = Keyword.merge(@worker_opts, opts)
        GenServer.start_link(__MODULE__, merged_opts, name: __MODULE__)
      end

      def submit_job(job) do
        GenServer.call(__MODULE__, {:submit_job, job})
      end

      def submit_job_async(job) do
        GenServer.cast(__MODULE__, {:submit_job_async, job})
      end

      def get_state do
        GenServer.call(__MODULE__, :get_state)
      end

      def get_metrics do
        GenServer.call(__MODULE__, :get_metrics)
      end

      def get_fqun do
        GenServer.call(__MODULE__, :get_fqun)
      end

      def get_queue_depth do
        GenServer.call(__MODULE__, :get_queue_depth)
      end

      def ping do
        GenServer.call(__MODULE__, :ping, 100)
      end
    end
  end

  # Split: GenServer callbacks section
  defp genserver_callbacks do
    quote do
      unquote(worker_init_callback())
      unquote(worker_call_callbacks())
      unquote(worker_cast_callbacks())
      unquote(worker_info_callbacks())
      unquote(worker_terminate_callback())
    end
  end

  # Split: Worker init callback
  defp worker_init_callback do
    quote do
      # ============================================================
      # GENSERVER CALLBACKS
      # ============================================================

      @impl GenServer
      def init(opts) do
        # Extract FQUN components
        type = Keyword.fetch!(opts, :type)
        namespace = Keyword.fetch!(opts, :namespace)
        name = Keyword.fetch!(opts, :name)

        # Generate FQUN for worker
        {:ok, fqun} = FQUN.generate(:worker, type, namespace, name)

        # Initialize base state
        base_state = %{
          fqun: fqun,
          type: type,
          namespace: namespace,
          name: name,
          started_at: DateTime.utc_now(),

          # Queue state
          queue: :queue.new(),
          queue_depth: 0,
          max_queue_size: @max_queue_size,

          # Metrics
          jobs_submitted: 0,
          jobs_completed: 0,
          jobs_failed: 0,
          jobs_retried: 0,
          total_processing_time_ms: 0,

          # Status
          status: :initializing,
          processing: false,
          current_job: nil
        }

        # Call worker-specific init
        # Using apply/3 to prevent compile-time type narrowing on callback returns
        case apply(__MODULE__, :worker_init, [opts]) do
          {:ok, worker_state} ->
            state = Map.merge(base_state, %{worker_state: worker_state, status: :idle})

            # Schedule periodic tasks
            schedule_heartbeat()
            schedule_state_publish()

            Logger.info("[#{__MODULE__}] Worker started - SC-WORKER-001",
              fqun: fqun,
              type: type,
              namespace: namespace,
              name: name
            )

            {:ok, state}

          {:error, reason} ->
            Logger.error("[#{__MODULE__}] Worker init failed", error: reason)
            {:stop, reason}
        end
      end
    end
  end

  # Split: Worker call callbacks
  defp worker_call_callbacks do
    quote do
      @impl GenServer
      def handle_call({:submit_job, job}, _from, state) do
        case try_enqueue(state, job) do
          {:ok, new_state} ->
            new_state = maybe_process_next(new_state)
            {:reply, {:ok, :queued}, new_state}

          {:error, :queue_full} ->
            {:reply, {:error, :queue_full}, state}
        end
      end

      @impl GenServer
      def handle_call(:get_state, _from, state) do
        worker_specific = worker_state(state.worker_state)

        full_state = %{
          fqun: state.fqun,
          type: state.type,
          namespace: state.namespace,
          name: state.name,
          status: state.status,
          started_at: state.started_at,
          queue_depth: state.queue_depth,
          processing: state.processing,
          worker: worker_specific
        }

        {:reply, full_state, state}
      end

      @impl GenServer
      def handle_call(:get_metrics, _from, state) do
        worker_metrics = worker_metrics(state.worker_state)

        avg_processing_time =
          if state.jobs_completed > 0 do
            state.total_processing_time_ms / state.jobs_completed
          else
            0.0
          end

        metrics = %{
          fqun: state.fqun,
          uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at),
          queue_depth: state.queue_depth,
          jobs_submitted: state.jobs_submitted,
          jobs_completed: state.jobs_completed,
          jobs_failed: state.jobs_failed,
          jobs_retried: state.jobs_retried,
          success_rate:
            safe_ratio(state.jobs_completed, state.jobs_completed + state.jobs_failed),
          avg_processing_time_ms: Float.round(avg_processing_time, 2),
          status: state.status,
          worker: worker_metrics
        }

        {:reply, metrics, state}
      end

      @impl GenServer
      def handle_call(:get_fqun, _from, state) do
        {:reply, state.fqun, state}
      end

      @impl GenServer
      def handle_call(:get_queue_depth, _from, state) do
        {:reply, state.queue_depth, state}
      end

      @impl GenServer
      def handle_call(:ping, _from, state) do
        {:reply, {:pong, DateTime.utc_now()}, state}
      end
    end
  end

  # Split: Worker cast callbacks
  defp worker_cast_callbacks do
    quote do
      @impl GenServer
      def handle_cast({:submit_job_async, job}, state) do
        case try_enqueue(state, job) do
          {:ok, new_state} ->
            new_state = maybe_process_next(new_state)
            {:noreply, new_state}

          {:error, :queue_full} ->
            Logger.warning("[#{__MODULE__}] Job rejected - queue full",
              queue_depth: state.queue_depth,
              max_queue_size: state.max_queue_size
            )

            {:noreply, state}
        end
      end
    end
  end

  # Split: Worker info callbacks
  defp worker_info_callbacks do
    quote do
      @impl GenServer
      def handle_info(:process_next, state) do
        new_state = process_next_job(state)
        {:noreply, new_state}
      end

      @impl GenServer
      def handle_info(:heartbeat, state) do
        heartbeat_payload = build_heartbeat_payload(state)

        Indrajaal.Observability.ZenohCoordinator.publish_coord(
          "worker/#{state.namespace}/#{state.name}/heartbeat",
          heartbeat_payload
        )

        schedule_heartbeat()
        {:noreply, state}
      end

      @impl GenServer
      def handle_info(:publish_state, state) do
        metrics = build_metrics_payload(state)

        Indrajaal.Observability.ZenohCoordinator.publish_coord(
          "worker/#{state.namespace}/#{state.name}/metrics",
          metrics
        )

        schedule_state_publish()
        {:noreply, state}
      end

      @impl GenServer
      def handle_info(msg, state) do
        handle_custom_message(msg, state)
      end

      defp build_heartbeat_payload(state) do
        %{
          fqun: state.fqun,
          status: state.status,
          queue_depth: state.queue_depth,
          processing: state.processing,
          timestamp: DateTime.utc_now()
        }
      end

      defp build_metrics_payload(state) do
        %{
          fqun: state.fqun,
          queue_depth: state.queue_depth,
          jobs_completed: state.jobs_completed,
          jobs_failed: state.jobs_failed,
          success_rate:
            safe_ratio(state.jobs_completed, state.jobs_completed + state.jobs_failed),
          timestamp: DateTime.utc_now()
        }
      end

      defp handle_custom_message(msg, state) do
        case apply(__MODULE__, :handle_worker_info, [msg, state.worker_state]) do
          {:ok, new_worker_state} ->
            {:noreply, %{state | worker_state: new_worker_state}}

          {:noreply, new_worker_state} ->
            {:noreply, %{state | worker_state: new_worker_state}}

          :ignore ->
            {:noreply, state}

          _ ->
            {:noreply, state}
        end
      end
    end
  end

  # Split: Worker terminate callback
  defp worker_terminate_callback do
    quote do
      @impl GenServer
      def terminate(reason, state) do
        Logger.info("[#{__MODULE__}] Worker terminating - SC-WORKER-004",
          fqun: state.fqun,
          reason: reason,
          pending_jobs: state.queue_depth
        )

        # Unregister FQUN
        FQUN.unregister(state.fqun)
        :ok
      end
    end
  end

  # Split: Private functions section
  defp private_functions do
    quote do
      # ============================================================
      # PRIVATE FUNCTIONS
      # ============================================================

      defp try_enqueue(state, job) do
        if state.queue_depth >= state.max_queue_size do
          {:error, :queue_full}
        else
          new_queue = :queue.in(job, state.queue)

          {:ok,
           %{
             state
             | queue: new_queue,
               queue_depth: state.queue_depth + 1,
               jobs_submitted: state.jobs_submitted + 1
           }}
        end
      end

      defp maybe_process_next(state) do
        if not state.processing and state.queue_depth > 0 do
          send(self(), :process_next)
        end

        state
      end

      defp process_next_job(state) do
        case :queue.out(state.queue) do
          {{:value, job}, new_queue} ->
            start_time = System.monotonic_time(:millisecond)

            new_state = %{
              state
              | queue: new_queue,
                queue_depth: state.queue_depth - 1,
                processing: true,
                status: :processing,
                current_job: job
            }

            # Process the job
            # Using apply/3 to prevent compile-time type narrowing on callback returns
            case apply(__MODULE__, :handle_job, [job, new_state.worker_state]) do
              {:ok, _result, new_worker_state} ->
                handle_job_success(new_state, new_worker_state, start_time)

              {:error, reason, new_worker_state} ->
                handle_job_failure(new_state, new_worker_state, job, reason)

              {:retry, reason, new_worker_state} ->
                handle_job_retry(new_state, new_worker_state, job, reason)
            end

          {:empty, _queue} ->
            %{state | processing: false, status: :idle, current_job: nil}
        end
      end

      # Extract job success handler to reduce cyclomatic complexity
      defp handle_job_success(new_state, new_worker_state, start_time) do
        elapsed = System.monotonic_time(:millisecond) - start_time

        completed_state = %{
          new_state
          | worker_state: new_worker_state,
            jobs_completed: new_state.jobs_completed + 1,
            total_processing_time_ms: new_state.total_processing_time_ms + elapsed,
            processing: false,
            status: :idle,
            current_job: nil
        }

        maybe_process_next(completed_state)
      end

      # Extract job failure handler to reduce cyclomatic complexity
      defp handle_job_failure(new_state, new_worker_state, job, reason) do
        Logger.warning("[#{__MODULE__}] Job failed",
          job: inspect(job),
          reason: reason
        )

        failed_state = %{
          new_state
          | worker_state: new_worker_state,
            jobs_failed: new_state.jobs_failed + 1,
            processing: false,
            status: :idle,
            current_job: nil
        }

        maybe_process_next(failed_state)
      end

      # Extract job retry handler to reduce cyclomatic complexity
      defp handle_job_retry(new_state, new_worker_state, job, reason) do
        Logger.debug("[#{__MODULE__}] Job retrying", reason: reason)

        retry_queue = :queue.in_r(job, new_state.queue)

        retry_state = %{
          new_state
          | queue: retry_queue,
            queue_depth: new_state.queue_depth + 1,
            worker_state: new_worker_state,
            jobs_retried: new_state.jobs_retried + 1,
            processing: false,
            status: :idle,
            current_job: nil
        }

        Process.send_after(self(), :process_next, 100)
        retry_state
      end

      defp schedule_heartbeat do
        Process.send_after(self(), :heartbeat, @heartbeat_interval_ms)
      end

      defp schedule_state_publish do
        Process.send_after(self(), :publish_state, @state_publish_interval_ms)
      end

      defp safe_ratio(_, 0), do: 0.0
      defp safe_ratio(num, denom), do: Float.round(num / denom, 3)
    end
  end
end
