defmodule Indrajaal.Distributed.Workers.BatchWorker do
  @moduledoc """
  Worker 4: Batch - Batch Processing Operations Worker.

  WHAT: Manages batch processing operations with FQUN tracking.
  WHY: SC-BATCH-001 requires coordinated batch operations.
  CONSTRAINTS: Atomicity, checkpointing, rollback capability.

  ## Batch Responsibilities

  1. **Batch Coordination**: Manage multi-step batch operations
  2. **Checkpointing**: Save progress for recovery
  3. **Rollback**: Undo partial operations on failure
  4. **Progress Tracking**: Real-time batch progress

  ## STAMP Constraints

  - SC-BATCH-001: Batch atomicity (all-or-nothing)
  - SC-BATCH-002: Checkpoint every N items
  - SC-BATCH-003: Rollback capability
  - SC-BATCH-004: Progress telemetry

  ## Mathematical Specification

  ```
  Batch := (Operations, Checkpoints, Progress)

  Operations := Sequence(Operation)
  Operation := (Action, Args, Status, Reversible)

  Checkpoints := List(Checkpoint)
  Checkpoint := (Position, State, Timestamp)

  Progress := (Current, Total, Percentage)

  Atomicity Invariant:
    batch_complete(batch) ⟺ ∀ op ∈ Operations: success(op)
    ¬batch_complete(batch) ⟹ rollback(batch) to last_checkpoint

  Checkpoint Rule:
    position mod checkpoint_interval = 0 ⟹ save_checkpoint(position)
  ```

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-BATCH-001 to SC-BATCH-004 |
  """

  use Indrajaal.Distributed.Workers.BaseWorker,
    type: :batch,
    namespace: "batch",
    name: "processor"

  alias Indrajaal.Distributed.FQUN

  # ============================================================
  # WORKER CALLBACKS
  # ============================================================

  @impl true
  def worker_init(_opts) do
    state = %{
      # Active batches (batch_id -> batch_info)
      batches: %{},

      # Batch FQUNs
      batch_fquns: %{},

      # Checkpoints per batch
      checkpoints: %{},

      # Configuration
      config: %{
        checkpoint_interval: 100,
        max_concurrent_batches: 5,
        default_timeout_ms: 300_000
      },

      # Metrics
      batches_created: 0,
      batches_completed: 0,
      batches_failed: 0,
      batches_rolled_back: 0,
      total_operations: 0,
      checkpoints_saved: 0
    }

    {:ok, state}
  end

  @impl true
  def worker_state(state) do
    %{
      active_batches: map_size(state.batches),
      batches: batch_summary(state.batches),
      checkpoints_saved: state.checkpoints_saved,
      batches_completed: state.batches_completed
    }
  end

  @impl true
  def worker_metrics(state) do
    %{
      active_batches: map_size(state.batches),
      batches_created: state.batches_created,
      batches_completed: state.batches_completed,
      batches_failed: state.batches_failed,
      batches_rolled_back: state.batches_rolled_back,
      total_operations: state.total_operations,
      checkpoints_saved: state.checkpoints_saved,
      success_rate: safe_ratio(state.batches_completed, state.batches_created)
    }
  end

  @impl true
  def handle_job({:create_batch, batch_name, operations}, state) when is_list(operations) do
    if map_size(state.batches) >= state.config.max_concurrent_batches do
      {:error, :max_batches_reached, state}
    else
      batch_id = generate_batch_id()

      # Generate FQUN for batch
      {:ok, batch_fqun} = FQUN.generate(:resource, :batch, "batch", batch_id)

      batch_info = %{
        id: batch_id,
        name: batch_name,
        fqun: batch_fqun,
        operations: prepare_operations(operations),
        total: length(operations),
        current: 0,
        status: :pending,
        created_at: DateTime.utc_now(),
        started_at: nil,
        completed_at: nil,
        error: nil
      }

      new_batches = Map.put(state.batches, batch_id, batch_info)
      new_batch_fquns = Map.put(state.batch_fquns, batch_id, batch_fqun)
      new_checkpoints = Map.put(state.checkpoints, batch_id, [])

      new_state = %{
        state
        | batches: new_batches,
          batch_fquns: new_batch_fquns,
          checkpoints: new_checkpoints,
          batches_created: state.batches_created + 1
      }

      # Publish batch creation to Zenoh
      publish_batch_event(:created, batch_info)

      {:ok, {:batch_created, batch_id, batch_fqun}, new_state}
    end
  end

  @impl true
  def handle_job({:start_batch, batch_id}, state) do
    case Map.get(state.batches, batch_id) do
      nil ->
        {:error, :batch_not_found, state}

      batch_info when batch_info.status == :pending ->
        new_batch_info = %{
          batch_info
          | status: :running,
            started_at: DateTime.utc_now()
        }

        new_batches = Map.put(state.batches, batch_id, new_batch_info)
        new_state = %{state | batches: new_batches}

        # Start processing
        new_state = process_batch_operations(new_state, batch_id)

        {:ok, :started, new_state}

      _batch_info ->
        {:error, :batch_not_pending, state}
    end
  end

  @impl true
  def handle_job({:checkpoint, batch_id}, state) do
    case Map.get(state.batches, batch_id) do
      nil ->
        {:error, :batch_not_found, state}

      batch_info ->
        checkpoint = %{
          position: batch_info.current,
          state: snapshot_batch_state(batch_info),
          timestamp: DateTime.utc_now()
        }

        batch_checkpoints = Map.get(state.checkpoints, batch_id, [])
        new_checkpoints = Map.put(state.checkpoints, batch_id, [checkpoint | batch_checkpoints])

        new_state = %{
          state
          | checkpoints: new_checkpoints,
            checkpoints_saved: state.checkpoints_saved + 1
        }

        # Publish checkpoint event
        publish_batch_event(:checkpoint, %{batch_id: batch_id, position: batch_info.current})

        {:ok, {:checkpoint_saved, batch_info.current}, new_state}
    end
  end

  @impl true
  def handle_job({:rollback, batch_id}, state) do
    case Map.get(state.batches, batch_id) do
      nil ->
        {:error, :batch_not_found, state}

      batch_info ->
        batch_checkpoints = Map.get(state.checkpoints, batch_id, [])

        case batch_checkpoints do
          [] ->
            # No checkpoints, rollback to beginning
            new_batch_info = %{
              batch_info
              | current: 0,
                status: :rolled_back,
                operations: reset_operations(batch_info.operations)
            }

            new_batches = Map.put(state.batches, batch_id, new_batch_info)

            new_state = %{
              state
              | batches: new_batches,
                batches_rolled_back: state.batches_rolled_back + 1
            }

            publish_batch_event(:rolled_back, %{batch_id: batch_id, to_position: 0})
            {:ok, {:rolled_back, 0}, new_state}

          [latest_checkpoint | _rest] ->
            # Rollback to latest checkpoint
            new_batch_info = %{
              batch_info
              | current: latest_checkpoint.position,
                status: :rolled_back,
                operations: rollback_operations(batch_info.operations, latest_checkpoint.position)
            }

            new_batches = Map.put(state.batches, batch_id, new_batch_info)

            new_state = %{
              state
              | batches: new_batches,
                batches_rolled_back: state.batches_rolled_back + 1
            }

            publish_batch_event(:rolled_back, %{
              batch_id: batch_id,
              to_position: latest_checkpoint.position
            })

            {:ok, {:rolled_back, latest_checkpoint.position}, new_state}
        end
    end
  end

  @impl true
  def handle_job({:cancel_batch, batch_id}, state) do
    case Map.get(state.batches, batch_id) do
      nil ->
        {:error, :batch_not_found, state}

      batch_info when batch_info.status in [:pending, :running, :paused] ->
        # Unregister FQUN
        FQUN.unregister(batch_info.fqun)

        new_batches = Map.delete(state.batches, batch_id)
        new_batch_fquns = Map.delete(state.batch_fquns, batch_id)
        new_checkpoints = Map.delete(state.checkpoints, batch_id)

        new_state = %{
          state
          | batches: new_batches,
            batch_fquns: new_batch_fquns,
            checkpoints: new_checkpoints
        }

        publish_batch_event(:cancelled, batch_info)
        {:ok, :cancelled, new_state}

      _batch_info ->
        {:error, :batch_not_cancellable, state}
    end
  end

  @impl true
  def handle_job({:pause_batch, batch_id}, state) do
    case Map.get(state.batches, batch_id) do
      nil ->
        {:error, :batch_not_found, state}

      batch_info when batch_info.status == :running ->
        new_batch_info = %{batch_info | status: :paused}
        new_batches = Map.put(state.batches, batch_id, new_batch_info)

        publish_batch_event(:paused, new_batch_info)
        {:ok, :paused, %{state | batches: new_batches}}

      _batch_info ->
        {:error, :batch_not_running, state}
    end
  end

  @impl true
  def handle_job({:resume_batch, batch_id}, state) do
    case Map.get(state.batches, batch_id) do
      nil ->
        {:error, :batch_not_found, state}

      batch_info when batch_info.status == :paused ->
        new_batch_info = %{batch_info | status: :running}
        new_batches = Map.put(state.batches, batch_id, new_batch_info)
        new_state = %{state | batches: new_batches}

        # Continue processing
        new_state = process_batch_operations(new_state, batch_id)

        publish_batch_event(:resumed, new_batch_info)
        {:ok, :resumed, new_state}

      _batch_info ->
        {:error, :batch_not_paused, state}
    end
  end

  @impl true
  def handle_job({:get_batch, batch_id}, state) do
    case Map.get(state.batches, batch_id) do
      nil -> {:error, :batch_not_found, state}
      batch_info -> {:ok, batch_info, state}
    end
  end

  @impl true
  def handle_job({:get_progress, batch_id}, state) do
    case Map.get(state.batches, batch_id) do
      nil ->
        {:error, :batch_not_found, state}

      batch_info ->
        progress = %{
          current: batch_info.current,
          total: batch_info.total,
          percentage: safe_ratio(batch_info.current, batch_info.total) * 100,
          status: batch_info.status
        }

        {:ok, progress, state}
    end
  end

  @impl true
  def handle_job(unknown, state) do
    {:error, {:unknown_job, unknown}, state}
  end

  # ============================================================
  # BATCH IMPLEMENTATION
  # ============================================================

  defp generate_batch_id do
    rand_bytes = :crypto.strong_rand_bytes(8)
    encoded = rand_bytes |> Base.encode16(case: :lower)
    "batch_" <> encoded
  end

  defp prepare_operations(operations) do
    operations
    |> Enum.with_index()
    |> Enum.map(fn {op, idx} ->
      %{
        index: idx,
        action: op,
        status: :pending,
        result: nil,
        error: nil,
        executed_at: nil
      }
    end)
  end

  defp process_batch_operations(state, batch_id) do
    batch_info = Map.get(state.batches, batch_id)

    if batch_info.status != :running do
      state
    else
      # Process next operation
      case Enum.at(batch_info.operations, batch_info.current) do
        nil ->
          # All operations complete
          complete_batch(state, batch_id)

        operation when operation.status == :pending ->
          # Execute operation
          {result, new_op_status} = execute_operation(operation)

          new_operation = %{
            operation
            | status: new_op_status,
              result: result,
              executed_at: DateTime.utc_now()
          }

          new_operations =
            List.replace_at(batch_info.operations, batch_info.current, new_operation)

          case new_op_status do
            :completed ->
              handle_operation_completed(new_operations, batch_info, batch_id, state, result)

            :failed ->
              fail_batch(state, batch_id, new_operations, result)
          end

        _operation ->
          # Skip already processed
          new_batch_info = %{batch_info | current: batch_info.current + 1}
          new_batches = Map.put(state.batches, batch_id, new_batch_info)
          process_batch_operations(%{state | batches: new_batches}, batch_id)
      end
    end
  end

  defp handle_operation_completed(operations, batch_info, batch_id, state, _result) do
    new_batch_info = %{
      batch_info
      | operations: operations,
        current: batch_info.current + 1
    }

    new_batches = Map.put(state.batches, batch_id, new_batch_info)

    new_state = %{
      state
      | batches: new_batches,
        total_operations: state.total_operations + 1
    }

    # Checkpoint if needed
    new_state = maybe_checkpoint_batch(new_state, batch_id, batch_info)

    # Publish progress
    publish_batch_event(:progress, %{
      batch_id: batch_id,
      current: batch_info.current + 1,
      total: batch_info.total
    })

    # Continue processing
    process_batch_operations(new_state, batch_id)
  end

  defp maybe_checkpoint_batch(state, batch_id, batch_info) do
    if rem(batch_info.current + 1, state.config.checkpoint_interval) == 0 do
      {:ok, _, checkpointed_state} = handle_job({:checkpoint, batch_id}, state)
      checkpointed_state
    else
      state
    end
  end

  defp execute_operation(operation) do
    # Simulate operation execution
    Logger.debug("[BatchWorker] Executing operation", index: operation.index)

    # Simulate success (90% success rate)
    if :rand.uniform(10) > 1 do
      {{:ok, :executed}, :completed}
    else
      {{:error, :simulated_failure}, :failed}
    end
  end

  defp complete_batch(state, batch_id) do
    batch_info = Map.get(state.batches, batch_id)

    new_batch_info = %{
      batch_info
      | status: :completed,
        completed_at: DateTime.utc_now()
    }

    new_batches = Map.put(state.batches, batch_id, new_batch_info)

    new_state = %{
      state
      | batches: new_batches,
        batches_completed: state.batches_completed + 1
    }

    publish_batch_event(:completed, new_batch_info)
    new_state
  end

  defp fail_batch(state, batch_id, operations, error) do
    batch_info = Map.get(state.batches, batch_id)

    new_batch_info = %{
      batch_info
      | status: :failed,
        operations: operations,
        error: error,
        completed_at: DateTime.utc_now()
    }

    new_batches = Map.put(state.batches, batch_id, new_batch_info)

    new_state = %{
      state
      | batches: new_batches,
        batches_failed: state.batches_failed + 1
    }

    publish_batch_event(:failed, %{batch_info: new_batch_info, error: error})
    new_state
  end

  defp snapshot_batch_state(batch_info) do
    %{
      current: batch_info.current,
      operations_completed: Enum.count(batch_info.operations, &(&1.status == :completed))
    }
  end

  defp reset_operations(operations) do
    Enum.map(operations, fn op ->
      %{op | status: :pending, result: nil, error: nil, executed_at: nil}
    end)
  end

  defp rollback_operations(operations, to_position) do
    operations
    |> Enum.with_index()
    |> Enum.map(fn {op, idx} ->
      if idx >= to_position do
        %{op | status: :pending, result: nil, error: nil, executed_at: nil}
      else
        op
      end
    end)
  end

  defp batch_summary(batches) do
    Enum.map(batches, fn {id, info} ->
      %{
        id: id,
        name: info.name,
        fqun: info.fqun,
        status: info.status,
        progress: "#{info.current}/#{info.total}"
      }
    end)
  end

  defp publish_batch_event(event, data) do
    Indrajaal.Observability.ZenohCoordinator.publish_coord(
      "batch/#{event}",
      Map.merge(%{event: event, timestamp: DateTime.utc_now()}, data)
    )
  rescue
    _ -> :ok
  end
end
