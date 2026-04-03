defmodule Indrajaal.Distributed.Workers.BatchWorkerTest do
  @moduledoc """
  Tests for Indrajaal.Distributed.Workers.BatchWorker.

  WHAT: Validates worker lifecycle callbacks and handle_job/2 for safe, FQUN-free paths.
  WHY: SC-BATCH-001 (atomicity), SC-BATCH-002 (checkpointing), SC-BATCH-003 (rollback).
  CONSTRAINTS: async: true (no name registration for the worker callbacks under test).
  Note: handle_job({:create_batch, ...}, state) calls FQUN.generate/5, so those tests
        require FQUN running. Only FQUN-free paths are tested here.
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Distributed.Workers.BatchWorker

  # Build a fresh worker state by calling worker_init/1 directly.
  defp fresh_state do
    {:ok, state} = BatchWorker.worker_init([])
    state
  end

  describe "worker_init/1" do
    test "returns {:ok, state} tuple" do
      result = BatchWorker.worker_init([])
      assert match?({:ok, %{}}, result)
    end

    test "initial state contains :batches map" do
      {:ok, state} = BatchWorker.worker_init([])
      assert Map.has_key?(state, :batches)
      assert state.batches == %{}
    end

    test "initial state contains :checkpoints map" do
      {:ok, state} = BatchWorker.worker_init([])
      assert Map.has_key?(state, :checkpoints)
      assert state.checkpoints == %{}
    end

    test "initial state contains :batch_fquns map" do
      {:ok, state} = BatchWorker.worker_init([])
      assert Map.has_key?(state, :batch_fquns)
      assert state.batch_fquns == %{}
    end

    test "initial state contains :config map with expected keys" do
      {:ok, state} = BatchWorker.worker_init([])
      assert Map.has_key?(state, :config)
      assert Map.has_key?(state.config, :checkpoint_interval)
      assert Map.has_key?(state.config, :max_concurrent_batches)
    end

    test "initial metric counters are all zero" do
      {:ok, state} = BatchWorker.worker_init([])
      assert state.batches_created == 0
      assert state.batches_completed == 0
      assert state.batches_failed == 0
      assert state.batches_rolled_back == 0
      assert state.total_operations == 0
      assert state.checkpoints_saved == 0
    end

    test "accepts opts list" do
      result = BatchWorker.worker_init(worker_id: "test-001")
      assert match?({:ok, _}, result)
    end
  end

  describe "worker_state/1" do
    test "returns a map" do
      state = fresh_state()
      result = BatchWorker.worker_state(state)
      assert is_map(result)
    end

    test "includes :active_batches key" do
      state = fresh_state()
      result = BatchWorker.worker_state(state)
      assert Map.has_key?(result, :active_batches)
    end

    test "active_batches is 0 on fresh state" do
      state = fresh_state()
      result = BatchWorker.worker_state(state)
      assert result.active_batches == 0
    end

    test "includes :batches key" do
      state = fresh_state()
      result = BatchWorker.worker_state(state)
      assert Map.has_key?(result, :batches)
    end

    test "includes :checkpoints_saved key" do
      state = fresh_state()
      result = BatchWorker.worker_state(state)
      assert Map.has_key?(result, :checkpoints_saved)
      assert result.checkpoints_saved == 0
    end

    test "includes :batches_completed key" do
      state = fresh_state()
      result = BatchWorker.worker_state(state)
      assert Map.has_key?(result, :batches_completed)
      assert result.batches_completed == 0
    end
  end

  describe "worker_metrics/1" do
    test "returns a map" do
      state = fresh_state()
      result = BatchWorker.worker_metrics(state)
      assert is_map(result)
    end

    test "includes :batches_created counter" do
      state = fresh_state()
      result = BatchWorker.worker_metrics(state)
      assert Map.has_key?(result, :batches_created)
      assert result.batches_created == 0
    end

    test "includes :batches_completed counter" do
      state = fresh_state()
      result = BatchWorker.worker_metrics(state)
      assert Map.has_key?(result, :batches_completed)
    end

    test "includes :batches_failed counter" do
      state = fresh_state()
      result = BatchWorker.worker_metrics(state)
      assert Map.has_key?(result, :batches_failed)
      assert result.batches_failed == 0
    end

    test "includes :batches_rolled_back counter" do
      state = fresh_state()
      result = BatchWorker.worker_metrics(state)
      assert Map.has_key?(result, :batches_rolled_back)
      assert result.batches_rolled_back == 0
    end

    test "includes :total_operations counter" do
      state = fresh_state()
      result = BatchWorker.worker_metrics(state)
      assert Map.has_key?(result, :total_operations)
      assert result.total_operations == 0
    end

    test "includes :success_rate key" do
      state = fresh_state()
      result = BatchWorker.worker_metrics(state)
      assert Map.has_key?(result, :success_rate)
    end

    test "includes :active_batches key" do
      state = fresh_state()
      result = BatchWorker.worker_metrics(state)
      assert Map.has_key?(result, :active_batches)
      assert result.active_batches == 0
    end
  end

  describe "handle_job/2 — unknown job" do
    test "returns {:error, {:unknown_job, _}, state} for an atom job" do
      state = fresh_state()
      result = BatchWorker.handle_job(:unknown_job_type, state)
      assert match?({:error, {:unknown_job, :unknown_job_type}, ^state}, result)
    end

    test "returns {:error, {:unknown_job, _}, state} for a plain map job" do
      state = fresh_state()
      result = BatchWorker.handle_job(%{type: :mystery_job}, state)
      assert match?({:error, {:unknown_job, _}, ^state}, result)
    end

    test "state is unchanged after unknown job" do
      state = fresh_state()
      {:error, _, returned_state} = BatchWorker.handle_job(:noop, state)
      assert returned_state == state
    end
  end

  describe "handle_job/2 — batch not found" do
    test "{:start_batch, id} returns {:error, :batch_not_found, state} for unknown id" do
      state = fresh_state()
      result = BatchWorker.handle_job({:start_batch, "nonexistent-batch-id"}, state)
      assert match?({:error, :batch_not_found, _}, result)
    end

    test "{:checkpoint, id} returns {:error, :batch_not_found, state} for unknown id" do
      state = fresh_state()
      result = BatchWorker.handle_job({:checkpoint, "nonexistent-batch-id"}, state)
      assert match?({:error, :batch_not_found, _}, result)
    end

    test "{:rollback, id} returns {:error, :batch_not_found, state} for unknown id" do
      state = fresh_state()
      result = BatchWorker.handle_job({:rollback, "nonexistent-batch-id"}, state)
      assert match?({:error, :batch_not_found, _}, result)
    end

    test "{:cancel_batch, id} returns {:error, :batch_not_found, state} for unknown id" do
      state = fresh_state()
      result = BatchWorker.handle_job({:cancel_batch, "nonexistent-batch-id"}, state)
      assert match?({:error, :batch_not_found, _}, result)
    end

    test "{:pause_batch, id} returns {:error, :batch_not_found, state} for unknown id" do
      state = fresh_state()
      result = BatchWorker.handle_job({:pause_batch, "nonexistent-batch-id"}, state)
      assert match?({:error, :batch_not_found, _}, result)
    end

    test "{:resume_batch, id} returns {:error, :batch_not_found, state} for unknown id" do
      state = fresh_state()
      result = BatchWorker.handle_job({:resume_batch, "nonexistent-batch-id"}, state)
      assert match?({:error, :batch_not_found, _}, result)
    end

    test "{:get_batch, id} returns {:error, :batch_not_found, state} for unknown id" do
      state = fresh_state()
      result = BatchWorker.handle_job({:get_batch, "nonexistent-batch-id"}, state)
      assert match?({:error, :batch_not_found, _}, result)
    end

    test "{:get_progress, id} returns {:error, :batch_not_found, state} for unknown id" do
      state = fresh_state()
      result = BatchWorker.handle_job({:get_progress, "nonexistent-batch-id"}, state)
      assert match?({:error, :batch_not_found, _}, result)
    end
  end
end
