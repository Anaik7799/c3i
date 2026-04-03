defmodule Indrajaal.Distributed.Workers.BroadwayWorker do
  @moduledoc """
  Worker 3: Broadway - Data Pipeline Processing Worker.

  WHAT: Manages Broadway data pipelines with FQUN tracking.
  WHY: SC-BROADWAY-001 requires streaming data processing.
  CONSTRAINTS: Backpressure, batching, pipeline telemetry.

  ## Broadway Responsibilities

  1. **Pipeline Management**: Create and manage data pipelines
  2. **Message Processing**: Process streaming messages
  3. **Batching**: Configure batch sizes and timeouts
  4. **Backpressure**: Handle producer-consumer balance

  ## STAMP Constraints

  - SC-BROADWAY-001: Pipeline creation < 2s
  - SC-BROADWAY-002: Message latency < 100ms
  - SC-BROADWAY-003: Batch processing metrics
  - SC-BROADWAY-004: Backpressure handling

  ## Mathematical Specification

  ```
  Broadway := (Pipelines, Messages, Batches)

  Pipelines := Map(PipelineID, Pipeline)
  Pipeline := (Producers, Processors, Batchers, FQUN)

  Messages := Stream(Message)
  Message := (Data, Metadata, Acknowledger)

  Batches := List(Batch)
  Batch := (Messages, Size, Timeout)

  Processing Rate:
    rate(pipeline) = messages_processed / time_window

  Backpressure Invariant:
    producer_rate > consumer_rate ⟹ Buffer(messages) until Buffer < max_buffer

  Batching Rule:
    emit_batch(batch) ⟺ |batch| ≥ batch_size ∨ elapsed > batch_timeout
  ```

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-BROADWAY-001 to SC-BROADWAY-004 |
  """

  use Indrajaal.Distributed.Workers.BaseWorker,
    type: :pipeline,
    namespace: "broadway",
    name: "pipeline_worker"

  alias Indrajaal.Distributed.FQUN

  # ============================================================
  # WORKER CALLBACKS
  # ============================================================

  @impl true
  def worker_init(_opts) do
    state = %{
      # Pipeline tracking (pipeline_id -> pipeline_info)
      pipelines: %{},

      # Pipeline FQUNs
      pipeline_fquns: %{},

      # Message buffers per pipeline
      buffers: %{},

      # Batch state per pipeline
      batch_state: %{},

      # Configuration
      config: %{
        default_batch_size: 100,
        default_batch_timeout_ms: 1000,
        max_buffer_size: 10_000,
        default_processors: System.schedulers_online()
      },

      # Metrics
      pipelines_created: 0,
      pipelines_destroyed: 0,
      messages_processed: 0,
      batches_processed: 0,
      messages_failed: 0
    }

    {:ok, state}
  end

  @impl true
  def worker_state(state) do
    %{
      pipeline_count: map_size(state.pipelines),
      pipelines: pipeline_summary(state.pipelines),
      buffer_depths: buffer_depths(state.buffers),
      messages_processed: state.messages_processed
    }
  end

  @impl true
  def worker_metrics(state) do
    %{
      pipeline_count: map_size(state.pipelines),
      pipelines_created: state.pipelines_created,
      pipelines_destroyed: state.pipelines_destroyed,
      messages_processed: state.messages_processed,
      batches_processed: state.batches_processed,
      messages_failed: state.messages_failed,
      success_rate:
        safe_ratio(state.messages_processed, state.messages_processed + state.messages_failed)
    }
  end

  @impl true
  def handle_job({:create_pipeline, pipeline_name, opts}, state) do
    # Generate FQUN for pipeline
    {:ok, pipeline_fqun} = FQUN.generate(:resource, :pipeline, "broadway", pipeline_name)

    batch_size = Keyword.get(opts, :batch_size, state.config.default_batch_size)
    batch_timeout = Keyword.get(opts, :batch_timeout_ms, state.config.default_batch_timeout_ms)
    processors = Keyword.get(opts, :processors, state.config.default_processors)

    pipeline_info = %{
      name: pipeline_name,
      fqun: pipeline_fqun,
      status: :active,
      batch_size: batch_size,
      batch_timeout_ms: batch_timeout,
      processors: processors,
      created_at: DateTime.utc_now(),
      messages_processed: 0,
      batches_processed: 0
    }

    batch_info = %{
      current_batch: [],
      batch_count: 0,
      last_flush: DateTime.utc_now()
    }

    new_pipelines = Map.put(state.pipelines, pipeline_name, pipeline_info)
    new_pipeline_fquns = Map.put(state.pipeline_fquns, pipeline_name, pipeline_fqun)
    new_buffers = Map.put(state.buffers, pipeline_name, :queue.new())
    new_batch_state = Map.put(state.batch_state, pipeline_name, batch_info)

    new_state = %{
      state
      | pipelines: new_pipelines,
        pipeline_fquns: new_pipeline_fquns,
        buffers: new_buffers,
        batch_state: new_batch_state,
        pipelines_created: state.pipelines_created + 1
    }

    # Publish pipeline creation to Zenoh
    publish_pipeline_event(:created, pipeline_info)

    {:ok, {:pipeline_created, pipeline_fqun}, new_state}
  end

  @impl true
  def handle_job({:destroy_pipeline, pipeline_name}, state) do
    case Map.get(state.pipelines, pipeline_name) do
      nil ->
        {:error, :pipeline_not_found, state}

      pipeline_info ->
        # Unregister FQUN
        FQUN.unregister(pipeline_info.fqun)

        new_pipelines = Map.delete(state.pipelines, pipeline_name)
        new_pipeline_fquns = Map.delete(state.pipeline_fquns, pipeline_name)
        new_buffers = Map.delete(state.buffers, pipeline_name)
        new_batch_state = Map.delete(state.batch_state, pipeline_name)

        new_state = %{
          state
          | pipelines: new_pipelines,
            pipeline_fquns: new_pipeline_fquns,
            buffers: new_buffers,
            batch_state: new_batch_state,
            pipelines_destroyed: state.pipelines_destroyed + 1
        }

        # Publish pipeline destruction
        publish_pipeline_event(:destroyed, pipeline_info)

        {:ok, :pipeline_destroyed, new_state}
    end
  end

  @impl true
  def handle_job({:push_message, pipeline_name, message}, state) do
    case Map.get(state.pipelines, pipeline_name) do
      nil ->
        {:error, :pipeline_not_found, state}

      pipeline_info when pipeline_info.status == :active ->
        buffer = Map.get(state.buffers, pipeline_name)
        buffer_size = :queue.len(buffer)

        if buffer_size >= state.config.max_buffer_size do
          {:error, :buffer_full, state}
        else
          # Add message to buffer
          new_buffer = :queue.in(message, buffer)
          new_buffers = Map.put(state.buffers, pipeline_name, new_buffer)

          new_state = %{state | buffers: new_buffers}

          # Check if batch should be processed
          new_state = maybe_process_batch(new_state, pipeline_name)

          {:ok, :queued, new_state}
        end

      _pipeline_info ->
        {:error, :pipeline_not_active, state}
    end
  end

  @impl true
  def handle_job({:push_messages, pipeline_name, messages}, state) when is_list(messages) do
    case Map.get(state.pipelines, pipeline_name) do
      nil ->
        {:error, :pipeline_not_found, state}

      pipeline_info when pipeline_info.status == :active ->
        buffer = Map.get(state.buffers, pipeline_name)
        buffer_size = :queue.len(buffer)

        if buffer_size + length(messages) > state.config.max_buffer_size do
          {:error, :buffer_full, state}
        else
          # Add all messages to buffer
          new_buffer =
            Enum.reduce(messages, buffer, fn msg, buf ->
              :queue.in(msg, buf)
            end)

          new_buffers = Map.put(state.buffers, pipeline_name, new_buffer)
          new_state = %{state | buffers: new_buffers}

          # Check if batch should be processed
          new_state = maybe_process_batch(new_state, pipeline_name)

          {:ok, {:queued, length(messages)}, new_state}
        end

      _pipeline_info ->
        {:error, :pipeline_not_active, state}
    end
  end

  @impl true
  def handle_job({:flush_pipeline, pipeline_name}, state) do
    case Map.get(state.pipelines, pipeline_name) do
      nil ->
        {:error, :pipeline_not_found, state}

      _pipeline_info ->
        new_state = process_all_batches(state, pipeline_name)
        {:ok, :flushed, new_state}
    end
  end

  @impl true
  def handle_job({:pause_pipeline, pipeline_name}, state) do
    case Map.get(state.pipelines, pipeline_name) do
      nil ->
        {:error, :pipeline_not_found, state}

      pipeline_info ->
        new_pipeline_info = %{pipeline_info | status: :paused}
        new_pipelines = Map.put(state.pipelines, pipeline_name, new_pipeline_info)
        {:ok, :paused, %{state | pipelines: new_pipelines}}
    end
  end

  @impl true
  def handle_job({:resume_pipeline, pipeline_name}, state) do
    case Map.get(state.pipelines, pipeline_name) do
      nil ->
        {:error, :pipeline_not_found, state}

      pipeline_info ->
        new_pipeline_info = %{pipeline_info | status: :active}
        new_pipelines = Map.put(state.pipelines, pipeline_name, new_pipeline_info)
        new_state = %{state | pipelines: new_pipelines}

        # Resume processing
        new_state = maybe_process_batch(new_state, pipeline_name)

        {:ok, :resumed, new_state}
    end
  end

  @impl true
  def handle_job({:get_pipeline, pipeline_name}, state) do
    case Map.get(state.pipelines, pipeline_name) do
      nil -> {:error, :pipeline_not_found, state}
      pipeline_info -> {:ok, pipeline_info, state}
    end
  end

  @impl true
  def handle_job({:get_buffer_depth, pipeline_name}, state) do
    case Map.get(state.buffers, pipeline_name) do
      nil -> {:error, :pipeline_not_found, state}
      buffer -> {:ok, :queue.len(buffer), state}
    end
  end

  @impl true
  def handle_job(unknown, state) do
    {:error, {:unknown_job, unknown}, state}
  end

  # ============================================================
  # BROADWAY IMPLEMENTATION
  # ============================================================

  defp maybe_process_batch(state, pipeline_name) do
    pipeline_info = Map.get(state.pipelines, pipeline_name)
    buffer = Map.get(state.buffers, pipeline_name)
    _batch_state = Map.get(state.batch_state, pipeline_name)

    buffer_size = :queue.len(buffer)

    if buffer_size >= pipeline_info.batch_size do
      process_batch(state, pipeline_name, pipeline_info.batch_size)
    else
      state
    end
  end

  defp process_all_batches(state, pipeline_name) do
    _pipeline_info = Map.get(state.pipelines, pipeline_name)
    buffer = Map.get(state.buffers, pipeline_name)

    buffer_size = :queue.len(buffer)

    if buffer_size > 0 do
      # Process all remaining messages
      process_batch(state, pipeline_name, buffer_size)
    else
      state
    end
  end

  defp process_batch(state, pipeline_name, count) do
    buffer = Map.get(state.buffers, pipeline_name)
    pipeline_info = Map.get(state.pipelines, pipeline_name)
    batch_state = Map.get(state.batch_state, pipeline_name)

    # Extract batch from buffer
    {batch, new_buffer} = take_from_queue(buffer, count)

    # Simulate batch processing
    processed_count = length(batch)

    Logger.debug("[BroadwayWorker] Processing batch",
      pipeline: pipeline_name,
      batch_size: processed_count
    )

    # Update pipeline metrics
    new_pipeline_info = %{
      pipeline_info
      | messages_processed: pipeline_info.messages_processed + processed_count,
        batches_processed: pipeline_info.batches_processed + 1
    }

    new_batch_state = %{
      batch_state
      | batch_count: batch_state.batch_count + 1,
        last_flush: DateTime.utc_now()
    }

    new_buffers = Map.put(state.buffers, pipeline_name, new_buffer)
    new_pipelines = Map.put(state.pipelines, pipeline_name, new_pipeline_info)
    new_batch_states = Map.put(state.batch_state, pipeline_name, new_batch_state)

    new_state = %{
      state
      | buffers: new_buffers,
        pipelines: new_pipelines,
        batch_state: new_batch_states,
        messages_processed: state.messages_processed + processed_count,
        batches_processed: state.batches_processed + 1
    }

    # Publish batch processed event
    publish_pipeline_event(:batch_processed, %{
      pipeline: pipeline_name,
      batch_size: processed_count,
      total_processed: new_pipeline_info.messages_processed
    })

    new_state
  end

  defp take_from_queue(queue, count) do
    take_from_queue(queue, count, [])
  end

  defp take_from_queue(queue, 0, acc), do: {Enum.reverse(acc), queue}

  defp take_from_queue(queue, count, acc) do
    case :queue.out(queue) do
      {{:value, item}, new_queue} ->
        take_from_queue(new_queue, count - 1, [item | acc])

      {:empty, _queue} ->
        {Enum.reverse(acc), queue}
    end
  end

  defp pipeline_summary(pipelines) do
    Enum.map(pipelines, fn {name, info} ->
      %{
        name: name,
        fqun: info.fqun,
        status: info.status,
        messages_processed: info.messages_processed
      }
    end)
  end

  defp buffer_depths(buffers) do
    mapped_buffers =
      Enum.map(buffers, fn {name, buffer} ->
        {name, :queue.len(buffer)}
      end)

    Map.new(mapped_buffers)
  end

  defp publish_pipeline_event(event, data) do
    Indrajaal.Observability.ZenohCoordinator.publish_coord(
      "broadway/pipeline/#{event}",
      Map.merge(%{event: event, timestamp: DateTime.utc_now()}, data)
    )
  rescue
    _ -> :ok
  end
end
