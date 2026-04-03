defmodule Indrajaal.Distributed.Workers.FLAMEWorkerTest do
  @moduledoc """
  Tests for Indrajaal.Distributed.Workers.FLAMEWorker.

  WHAT: Validates worker lifecycle callbacks and handle_job/2 for elastic pool management.
  WHY: SC-FLAME-001 (pool creation), SC-FLAME-002 (job dispatch), SC-FLAME-004 (graceful shutdown).
  CONSTRAINTS: async: true (worker callbacks are pure functions, no GenServer registration).
  Note: handle_job({:create_pool, ...}, state) calls FQUN.generate/5 internally.
        Only FQUN-free paths are tested here to avoid external dependencies.
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Distributed.Workers.FLAMEWorker

  # Build a fresh worker state by calling worker_init/1 directly.
  defp fresh_state do
    {:ok, state} = FLAMEWorker.worker_init([])
    state
  end

  describe "worker_init/1" do
    test "returns {:ok, state} tuple" do
      result = FLAMEWorker.worker_init([])
      assert match?({:ok, %{}}, result)
    end

    test "initial state contains :pools map" do
      {:ok, state} = FLAMEWorker.worker_init([])
      assert Map.has_key?(state, :pools)
      assert state.pools == %{}
    end

    test "initial state contains :pool_fquns map" do
      {:ok, state} = FLAMEWorker.worker_init([])
      assert Map.has_key?(state, :pool_fquns)
      assert state.pool_fquns == %{}
    end

    test "initial state contains :pending_by_pool map" do
      {:ok, state} = FLAMEWorker.worker_init([])
      assert Map.has_key?(state, :pending_by_pool)
      assert state.pending_by_pool == %{}
    end

    test "initial state contains :utilization map" do
      {:ok, state} = FLAMEWorker.worker_init([])
      assert Map.has_key?(state, :utilization)
      assert state.utilization == %{}
    end

    test "initial state contains :config with expected keys" do
      {:ok, state} = FLAMEWorker.worker_init([])
      assert Map.has_key?(state, :config)
      assert Map.has_key?(state.config, :default_min_runners)
      assert Map.has_key?(state.config, :default_max_runners)
      assert Map.has_key?(state.config, :scale_up_threshold)
      assert Map.has_key?(state.config, :scale_down_threshold)
    end

    test "initial metric counters are all zero" do
      {:ok, state} = FLAMEWorker.worker_init([])
      assert state.pools_created == 0
      assert state.pools_destroyed == 0
      assert state.jobs_dispatched == 0
      assert state.scale_events == 0
    end

    test "accepts opts list" do
      result = FLAMEWorker.worker_init(worker_id: "flame-001")
      assert match?({:ok, _}, result)
    end
  end

  describe "worker_state/1" do
    test "returns a map" do
      state = fresh_state()
      result = FLAMEWorker.worker_state(state)
      assert is_map(result)
    end

    test "includes :pool_count key" do
      state = fresh_state()
      result = FLAMEWorker.worker_state(state)
      assert Map.has_key?(result, :pool_count)
    end

    test "pool_count is 0 on fresh state" do
      state = fresh_state()
      result = FLAMEWorker.worker_state(state)
      assert result.pool_count == 0
    end

    test "includes :pools key" do
      state = fresh_state()
      result = FLAMEWorker.worker_state(state)
      assert Map.has_key?(result, :pools)
    end

    test "pools is an empty list on fresh state" do
      state = fresh_state()
      result = FLAMEWorker.worker_state(state)
      assert result.pools == []
    end

    test "includes :utilization key" do
      state = fresh_state()
      result = FLAMEWorker.worker_state(state)
      assert Map.has_key?(result, :utilization)
    end

    test "includes :jobs_dispatched key" do
      state = fresh_state()
      result = FLAMEWorker.worker_state(state)
      assert Map.has_key?(result, :jobs_dispatched)
      assert result.jobs_dispatched == 0
    end
  end

  describe "worker_metrics/1" do
    test "returns a map" do
      state = fresh_state()
      result = FLAMEWorker.worker_metrics(state)
      assert is_map(result)
    end

    test "includes :pool_count key" do
      state = fresh_state()
      result = FLAMEWorker.worker_metrics(state)
      assert Map.has_key?(result, :pool_count)
      assert result.pool_count == 0
    end

    test "includes :pools_created counter" do
      state = fresh_state()
      result = FLAMEWorker.worker_metrics(state)
      assert Map.has_key?(result, :pools_created)
      assert result.pools_created == 0
    end

    test "includes :pools_destroyed counter" do
      state = fresh_state()
      result = FLAMEWorker.worker_metrics(state)
      assert Map.has_key?(result, :pools_destroyed)
      assert result.pools_destroyed == 0
    end

    test "includes :jobs_dispatched counter" do
      state = fresh_state()
      result = FLAMEWorker.worker_metrics(state)
      assert Map.has_key?(result, :jobs_dispatched)
      assert result.jobs_dispatched == 0
    end

    test "includes :scale_events counter" do
      state = fresh_state()
      result = FLAMEWorker.worker_metrics(state)
      assert Map.has_key?(result, :scale_events)
      assert result.scale_events == 0
    end

    test "includes :avg_utilization key" do
      state = fresh_state()
      result = FLAMEWorker.worker_metrics(state)
      assert Map.has_key?(result, :avg_utilization)
    end
  end

  describe "handle_job/2 — unknown job" do
    test "returns exact error tuple for atom job" do
      state = fresh_state()
      result = FLAMEWorker.handle_job(:unknown_job_type, state)
      assert match?({:error, {:unknown_job, :unknown_job_type}, ^state}, result)
    end

    test "returns exact error tuple for map job" do
      state = fresh_state()
      job = %{type: :mystery_compute}
      result = FLAMEWorker.handle_job(job, state)
      assert match?({:error, {:unknown_job, ^job}, ^state}, result)
    end

    test "state is unchanged after unknown job" do
      state = fresh_state()
      {:error, _, returned_state} = FLAMEWorker.handle_job(:noop, state)
      assert returned_state == state
    end

    test "returns {:error, {:unknown_job, _}, state} for a binary job" do
      state = fresh_state()
      result = FLAMEWorker.handle_job("bad_job", state)
      assert match?({:error, {:unknown_job, "bad_job"}, ^state}, result)
    end
  end

  describe "handle_job/2 — pool not found" do
    test "{:destroy_pool, id} returns error for unknown pool id" do
      state = fresh_state()
      result = FLAMEWorker.handle_job({:destroy_pool, "nonexistent-pool-id"}, state)
      assert match?({:error, _, _}, result)
    end

    test "{:get_pool, id} returns error for unknown pool id" do
      state = fresh_state()
      result = FLAMEWorker.handle_job({:get_pool, "nonexistent-pool-id"}, state)
      assert match?({:error, _, _}, result)
    end

    test "{:dispatch, id, fn_ref} returns error for unknown pool id" do
      state = fresh_state()
      result = FLAMEWorker.handle_job({:dispatch, "nonexistent-pool-id", fn -> :ok end}, state)
      assert match?({:error, _, _}, result)
    end

    test "{:scale, id, size} returns error for unknown pool id" do
      state = fresh_state()
      result = FLAMEWorker.handle_job({:scale, "nonexistent-pool-id", 3}, state)
      assert match?({:error, _, _}, result)
    end
  end
end
