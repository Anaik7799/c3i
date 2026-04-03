defmodule Indrajaal.Distributed.WorkerMesh do
  @moduledoc """
  Worker Mesh Supervisor - Manages 4 Distributed Workers.

  WHAT: Supervises all distributed workers with FQUN registration.
  WHY: SC-MESH-002 requires centralized worker supervision.
  CONSTRAINTS: Workers must register FQUNs, publish state to Zenoh.

  ## Supervised Workers

  1. **FLAMEWorker**: Elastic compute pool operations
  2. **ObanWorker**: Background job processing
  3. **BroadwayWorker**: Data pipeline processing
  4. **BatchWorker**: Batch processing operations

  ## STAMP Constraints

  - SC-MESH-002: Worker supervision required
  - SC-WORKER-001: Consistent worker interface
  - SC-WORKER-002: FQUN registration mandatory

  ## Mathematical Specification

  ```
  WorkerMesh := Supervisor(Workers)

  Workers := {FLAME, Oban, Broadway, Batch}

  Supervision Strategy:
    strategy = one_for_one
    max_restarts = 10
    max_seconds = 60

  Health Invariant:
    ∀ w ∈ Workers: Alive(w) ∨ Restarting(w)
  ```

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-MESH-002, SC-WORKER-001 |
  """

  use Supervisor
  require Logger

  alias Indrajaal.Distributed.FQUN
  alias Indrajaal.Distributed.Workers.{BatchWorker, BroadwayWorker, FLAMEWorker, ObanWorker}

  @workers [
    %{
      id: :flame_worker,
      module: FLAMEWorker,
      type: :compute,
      namespace: "flame",
      name: "pool_worker",
      description: "Elastic compute pool operations"
    },
    %{
      id: :oban_worker,
      module: ObanWorker,
      type: :background,
      namespace: "oban",
      name: "job_worker",
      description: "Background job processing"
    },
    %{
      id: :broadway_worker,
      module: BroadwayWorker,
      type: :pipeline,
      namespace: "broadway",
      name: "pipeline_worker",
      description: "Data pipeline processing"
    },
    %{
      id: :batch_worker,
      module: BatchWorker,
      type: :batch,
      namespace: "batch",
      name: "processor",
      description: "Batch processing operations"
    }
  ]

  # ============================================================
  # PUBLIC API
  # ============================================================

  @spec start_link(Keyword.t()) :: Supervisor.on_start()
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  List all workers with their status.
  """
  @spec list_workers() :: list(map())
  def list_workers do
    Enum.map(@workers, fn worker_def ->
      status = get_worker_status(worker_def.module)

      %{
        id: worker_def.id,
        module: worker_def.module,
        type: worker_def.type,
        namespace: worker_def.namespace,
        name: worker_def.name,
        description: worker_def.description,
        status: status
      }
    end)
  end

  @doc """
  Get a specific worker by ID.
  """
  @spec get_worker(atom()) :: {:ok, atom()} | {:error, :worker_not_found}
  def get_worker(worker_id) do
    case Enum.find(@workers, &(&1.id == worker_id)) do
      nil -> {:error, :worker_not_found}
      worker_def -> {:ok, worker_def.module}
    end
  end

  @doc """
  Get the state of a specific worker.
  """
  @spec get_worker_state(atom()) :: term()
  def get_worker_state(worker_id) do
    case get_worker(worker_id) do
      {:ok, module} -> module.get_state()
      error -> error
    end
  end

  @doc """
  Get metrics from a specific worker.
  """
  @spec get_worker_metrics(atom()) :: term()
  def get_worker_metrics(worker_id) do
    case get_worker(worker_id) do
      {:ok, module} -> module.get_metrics()
      error -> error
    end
  end

  @doc """
  Get aggregated metrics from all workers.
  """
  @spec get_all_metrics() :: map()
  def get_all_metrics do
    Enum.reduce(@workers, %{}, fn worker_def, acc ->
      case get_worker_status(worker_def.module) do
        :running ->
          metrics = worker_def.module.get_metrics()
          Map.put(acc, worker_def.id, metrics)

        _status ->
          Map.put(acc, worker_def.id, %{status: :not_running})
      end
    end)
  end

  @doc """
  Get the FQUN of a worker.
  """
  @spec get_worker_fqun(atom()) :: term()
  def get_worker_fqun(worker_id) do
    case get_worker(worker_id) do
      {:ok, module} -> module.get_fqun()
      error -> error
    end
  end

  @doc """
  Submit a job to a worker.
  """
  @spec submit_job(atom(), term()) :: term()
  def submit_job(worker_id, job) do
    case get_worker(worker_id) do
      {:ok, module} -> module.submit_job(job)
      error -> error
    end
  end

  @doc """
  Submit a job asynchronously to a worker.
  """
  @spec submit_job_async(atom(), term()) :: :ok | {:error, :worker_not_found}
  def submit_job_async(worker_id, job) do
    case get_worker(worker_id) do
      {:ok, module} ->
        module.submit_job_async(job)
        :ok

      error ->
        error
    end
  end

  @doc """
  Ping all workers and return their status.
  """
  @spec ping_all() :: map()
  def ping_all do
    results =
      Enum.map(@workers, fn worker_def ->
        result =
          try do
            worker_def.module.ping()
          rescue
            _ -> {:error, :not_responding}
          catch
            :exit, _ -> {:error, :not_running}
          end

        {worker_def.id, result}
      end)

    Map.new(results)
  end

  @doc """
  Get worker definitions.
  """
  @spec worker_definitions() :: list(map())
  def worker_definitions, do: @workers

  # ============================================================
  # SUPERVISOR CALLBACKS
  # ============================================================

  @impl true
  def init(_opts) do
    Logger.info("[WorkerMesh] Initializing 4-worker mesh - SC-MESH-002")

    # Register mesh supervisor FQUN
    {:ok, mesh_fqun} = FQUN.generate(:supervisor, :worker, "mesh", "worker_mesh")

    Logger.info("[WorkerMesh] Mesh FQUN registered",
      fqun: mesh_fqun,
      workers: length(@workers)
    )

    children =
      Enum.map(@workers, fn worker_def ->
        {worker_def.module,
         [
           type: worker_def.type,
           namespace: worker_def.namespace,
           name: worker_def.name
         ]}
      end)

    Supervisor.init(children,
      strategy: :one_for_one,
      max_restarts: 10,
      max_seconds: 60
    )
  end

  # ============================================================
  # PRIVATE FUNCTIONS
  # ============================================================

  defp get_worker_status(module) do
    case Process.whereis(module) do
      nil -> :not_running
      pid when is_pid(pid) -> :running
    end
  rescue
    _ -> :error
  end
end
