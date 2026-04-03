defmodule Indrajaal.Distributed.Workers.BroadwayWorkerTest do
  @moduledoc """
  Tests for Indrajaal.Distributed.Workers.BroadwayWorker.

  WHAT: Validates worker lifecycle callbacks and handle_job/2 for pipeline management.
  WHY: Tests behavioral correctness of the BroadwayWorker pipeline lifecycle.
  CONSTRAINTS: async: true (worker callbacks are pure functions, no GenServer registration).
  Note: handle_job({:create_pipeline, ...}, state) calls FQUN.generate/5 internally.
        Only FQUN-free paths are tested here to avoid external dependencies.
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Distributed.Workers.BroadwayWorker

  # Build a fresh worker state by calling worker_init/1 directly.
  defp fresh_state do
    {:ok, state} = BroadwayWorker.worker_init([])
    state
  end

  describe "worker_init/1" do
    test "returns {:ok, state} tuple" do
      result = BroadwayWorker.worker_init([])
      assert match?({:ok, %{}}, result)
    end

    test "initial state contains :pipelines map" do
      {:ok, state} = BroadwayWorker.worker_init([])
      assert Map.has_key?(state, :pipelines)
      assert state.pipelines == %{}
    end

    test "initial state contains :pipeline_fquns map" do
      {:ok, state} = BroadwayWorker.worker_init([])
      assert Map.has_key?(state, :pipeline_fquns)
      assert state.pipeline_fquns == %{}
    end

    test "initial state contains :buffers map" do
      {:ok, state} = BroadwayWorker.worker_init([])
      assert Map.has_key?(state, :buffers)
      assert state.buffers == %{}
    end

    test "initial state contains :config map with expected keys" do
      {:ok, state} = BroadwayWorker.worker_init([])
      assert Map.has_key?(state, :config)
      assert Map.has_key?(state.config, :default_batch_size)
      assert Map.has_key?(state.config, :max_buffer_size)
    end

    test "initial metric counters are all zero" do
      {:ok, state} = BroadwayWorker.worker_init([])
      assert state.pipelines_created == 0
      assert state.pipelines_destroyed == 0
      assert state.messages_processed == 0
      assert state.batches_processed == 0
      assert state.messages_failed == 0
    end

    test "accepts opts list" do
      result = BroadwayWorker.worker_init(worker_id: "broadway-001")
      assert match?({:ok, _}, result)
    end
  end

  describe "worker_state/1" do
    test "returns a map" do
      state = fresh_state()
      result = BroadwayWorker.worker_state(state)
      assert is_map(result)
    end

    test "includes :pipeline_count key" do
      state = fresh_state()
      result = BroadwayWorker.worker_state(state)
      assert Map.has_key?(result, :pipeline_count)
    end

    test "pipeline_count is 0 on fresh state" do
      state = fresh_state()
      result = BroadwayWorker.worker_state(state)
      assert result.pipeline_count == 0
    end

    test "includes :pipelines key" do
      state = fresh_state()
      result = BroadwayWorker.worker_state(state)
      assert Map.has_key?(result, :pipelines)
    end

    test "pipelines is an empty list on fresh state" do
      state = fresh_state()
      result = BroadwayWorker.worker_state(state)
      assert result.pipelines == []
    end

    test "includes :messages_processed key" do
      state = fresh_state()
      result = BroadwayWorker.worker_state(state)
      assert Map.has_key?(result, :messages_processed)
      assert result.messages_processed == 0
    end
  end

  describe "worker_metrics/1" do
    test "returns a map" do
      state = fresh_state()
      result = BroadwayWorker.worker_metrics(state)
      assert is_map(result)
    end

    test "includes :pipeline_count key" do
      state = fresh_state()
      result = BroadwayWorker.worker_metrics(state)
      assert Map.has_key?(result, :pipeline_count)
      assert result.pipeline_count == 0
    end

    test "includes :pipelines_created counter" do
      state = fresh_state()
      result = BroadwayWorker.worker_metrics(state)
      assert Map.has_key?(result, :pipelines_created)
      assert result.pipelines_created == 0
    end

    test "includes :pipelines_destroyed counter" do
      state = fresh_state()
      result = BroadwayWorker.worker_metrics(state)
      assert Map.has_key?(result, :pipelines_destroyed)
      assert result.pipelines_destroyed == 0
    end

    test "includes :messages_processed counter" do
      state = fresh_state()
      result = BroadwayWorker.worker_metrics(state)
      assert Map.has_key?(result, :messages_processed)
      assert result.messages_processed == 0
    end

    test "includes :messages_failed counter" do
      state = fresh_state()
      result = BroadwayWorker.worker_metrics(state)
      assert Map.has_key?(result, :messages_failed)
      assert result.messages_failed == 0
    end

    test "includes :success_rate key" do
      state = fresh_state()
      result = BroadwayWorker.worker_metrics(state)
      assert Map.has_key?(result, :success_rate)
    end
  end

  describe "handle_job/2 — unknown job" do
    test "returns exact error tuple for atom job" do
      state = fresh_state()
      result = BroadwayWorker.handle_job(:unknown_job_type, state)
      assert match?({:error, {:unknown_job, :unknown_job_type}, ^state}, result)
    end

    test "returns exact error tuple for map job without :pipeline_name key" do
      state = fresh_state()
      job = %{type: :mystery}
      result = BroadwayWorker.handle_job(job, state)
      assert match?({:error, {:unknown_job, ^job}, ^state}, result)
    end

    test "state is unchanged after unknown job" do
      state = fresh_state()
      {:error, _, returned_state} = BroadwayWorker.handle_job(:noop, state)
      assert returned_state == state
    end

    test "returns {:error, {:unknown_job, _}, state} for a tuple job" do
      state = fresh_state()
      result = BroadwayWorker.handle_job({:mystery_op, "arg"}, state)
      assert match?({:error, {:unknown_job, _}, ^state}, result)
    end
  end

  describe "handle_job/2 — pipeline not found" do
    test "{:destroy_pipeline, id} returns error for unknown id" do
      state = fresh_state()
      result = BroadwayWorker.handle_job({:destroy_pipeline, "nonexistent-pipeline-id"}, state)
      assert match?({:error, _, _}, result)
    end

    test "{:get_pipeline, id} returns error for unknown id" do
      state = fresh_state()
      result = BroadwayWorker.handle_job({:get_pipeline, "nonexistent-pipeline-id"}, state)
      assert match?({:error, _, _}, result)
    end

    test "{:push_message, id, msg} returns error for unknown pipeline" do
      state = fresh_state()
      result = BroadwayWorker.handle_job({:push_message, "nonexistent-id", %{data: "x"}}, state)
      assert match?({:error, _, _}, result)
    end

    test "{:flush_pipeline, id} returns error for unknown id" do
      state = fresh_state()
      result = BroadwayWorker.handle_job({:flush_pipeline, "nonexistent-id"}, state)
      assert match?({:error, _, _}, result)
    end

    test "{:get_buffer_depth, id} returns error for unknown id" do
      state = fresh_state()
      result = BroadwayWorker.handle_job({:get_buffer_depth, "nonexistent-id"}, state)
      assert match?({:error, _, _}, result)
    end
  end
end
