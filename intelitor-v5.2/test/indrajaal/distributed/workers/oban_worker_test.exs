defmodule Indrajaal.Distributed.Workers.ObanWorkerTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Distributed.Workers.ObanWorker

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(ObanWorker)
    end
  end

  describe "public API (injected by BaseWorker)" do
    test "defines start_link/1" do
      assert function_exported?(ObanWorker, :start_link, 1)
    end

    test "defines submit_job/1" do
      assert function_exported?(ObanWorker, :submit_job, 1)
    end

    test "defines submit_job_async/1" do
      assert function_exported?(ObanWorker, :submit_job_async, 1)
    end

    test "defines get_state/0" do
      assert function_exported?(ObanWorker, :get_state, 0)
    end

    test "defines get_metrics/0" do
      assert function_exported?(ObanWorker, :get_metrics, 0)
    end

    test "defines get_fqun/0" do
      assert function_exported?(ObanWorker, :get_fqun, 0)
    end

    test "defines ping/0" do
      assert function_exported?(ObanWorker, :ping, 0)
    end
  end

  describe "BaseWorker callbacks" do
    test "defines worker_init/1" do
      assert function_exported?(ObanWorker, :worker_init, 1)
    end

    test "defines worker_state/1" do
      assert function_exported?(ObanWorker, :worker_state, 1)
    end

    test "defines worker_metrics/1" do
      assert function_exported?(ObanWorker, :worker_metrics, 1)
    end

    test "defines handle_job/2" do
      assert function_exported?(ObanWorker, :handle_job, 2)
    end
  end

  describe "handle_job/2 unknown job" do
    test "returns error for unknown job type" do
      state = %{
        queues: %{default: %{concurrency: 10, paused: false, jobs: 0}},
        jobs: %{},
        job_fquns: %{},
        config: %{
          max_attempts: 5,
          base_delay_ms: 1000,
          max_delay_ms: 300_000,
          pruning_age_days: 7
        },
        state_counts: %{
          scheduled: 0,
          available: 0,
          executing: 0,
          completed: 0,
          retryable: 0,
          discarded: 0
        },
        total_jobs: 0,
        successful_jobs: 0,
        failed_jobs: 0,
        retried_jobs: 0
      }

      result = ObanWorker.handle_job(:unknown_job_type, state)
      assert match?({:error, {:unknown_job, :unknown_job_type}, ^state}, result)
    end
  end

  describe "GenServer" do
    test "defines child_spec/1" do
      assert function_exported?(ObanWorker, :child_spec, 1)
    end
  end
end
