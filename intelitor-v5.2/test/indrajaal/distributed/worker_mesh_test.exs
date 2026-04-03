defmodule Indrajaal.Distributed.WorkerMeshTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Distributed.WorkerMesh

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(WorkerMesh)
    end
  end

  describe "public API" do
    test "defines start_link/1" do
      assert function_exported?(WorkerMesh, :start_link, 1)
    end

    test "defines list_workers/0" do
      assert function_exported?(WorkerMesh, :list_workers, 0)
    end

    test "defines get_worker/1" do
      assert function_exported?(WorkerMesh, :get_worker, 1)
    end

    test "defines get_worker_state/1" do
      assert function_exported?(WorkerMesh, :get_worker_state, 1)
    end

    test "defines get_worker_metrics/1" do
      assert function_exported?(WorkerMesh, :get_worker_metrics, 1)
    end

    test "defines get_all_metrics/0" do
      assert function_exported?(WorkerMesh, :get_all_metrics, 0)
    end

    test "defines get_worker_fqun/1" do
      assert function_exported?(WorkerMesh, :get_worker_fqun, 1)
    end

    test "defines submit_job/2" do
      assert function_exported?(WorkerMesh, :submit_job, 2)
    end

    test "defines submit_job_async/2" do
      assert function_exported?(WorkerMesh, :submit_job_async, 2)
    end

    test "defines ping_all/0" do
      assert function_exported?(WorkerMesh, :ping_all, 0)
    end

    test "defines worker_definitions/0" do
      assert function_exported?(WorkerMesh, :worker_definitions, 0)
    end
  end

  describe "worker_definitions/0 static data" do
    test "returns a list" do
      workers = WorkerMesh.worker_definitions()
      assert is_list(workers)
    end

    test "each worker has required fields" do
      for worker <- WorkerMesh.worker_definitions() do
        assert Map.has_key?(worker, :id)
        assert Map.has_key?(worker, :module)
      end
    end
  end

  describe "Supervisor" do
    test "defines child_spec/1" do
      assert function_exported?(WorkerMesh, :child_spec, 1)
    end
  end

  describe "get_worker/1 error handling" do
    test "returns nil for unknown worker id" do
      result = WorkerMesh.get_worker(:nonexistent_worker)
      assert is_nil(result)
    end
  end
end
