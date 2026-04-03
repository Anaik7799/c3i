defmodule Indrajaal.Distributed.DistributedMesh do
  @moduledoc """
  Distributed Mesh Supervisor - Top-Level Distributed System Controller.

  WHAT: Supervises AgentMesh and WorkerMesh with Zenoh control plane.
  WHY: SC-MESH-001 requires unified distributed system management.
  CONSTRAINTS: All components must have FQUNs, Zenoh for control.

  ## Architecture

  ```
  DistributedMesh (Supervisor)
  ├── AgentMesh (6 Agents)
  │   ├── OODAAgent
  │   ├── ACEAgent
  │   ├── CortexAgent
  │   ├── FractalAgent
  │   ├── CEPAFAgent
  │   └── SentinelAgent
  ├── WorkerMesh (4 Workers)
  │   ├── FLAMEWorker
  │   ├── ObanWorker
  │   ├── BroadwayWorker
  │   └── BatchWorker
  └── ZenohControlPlane (Control & State)
  ```

  ## STAMP Constraints

  - SC-MESH-001: Unified mesh supervision
  - SC-MESH-002: Worker supervision
  - SC-MESH-003: Agent supervision
  - SC-ZENOH-001: Control plane integration

  ## Zenoh Topics

  - `mesh/status` - Overall mesh status
  - `mesh/agents/*` - Agent-specific topics
  - `mesh/workers/*` - Worker-specific topics
  - `mesh/control/*` - Control commands

  ## Mathematical Specification

  ```
  DistributedMesh := Supervisor(AgentMesh, WorkerMesh, ControlPlane)

  Components := Agents ∪ Workers
  |Agents| = 6, |Workers| = 4

  Control Plane:
    ControlPlane: Commands → Effects
    Commands := {Start, Stop, Pause, Resume, Scale, Configure}

  Mesh Invariants:
    ∀ c ∈ Components: HasFQUN(c) ∧ Registered(c.FQUN)
    ∀ c ∈ Components: PublishesState(c, Zenoh)
  ```

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-MESH-001 to SC-ZENOH-001 |
  """

  use Supervisor
  require Logger

  alias Indrajaal.Distributed.{AgentMesh, FQUN, WorkerMesh}

  @mesh_status_interval_ms 30_000

  # ============================================================
  # PUBLIC API
  # ============================================================

  @spec start_link(Keyword.t()) :: Supervisor.on_start()
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get overall mesh status including all agents and workers.
  """
  @spec get_status() :: map()
  def get_status do
    %{
      mesh_fqun: get_mesh_fqun(),
      timestamp: DateTime.utc_now(),
      agents: AgentMesh.list_agents(),
      workers: WorkerMesh.list_workers(),
      summary: %{
        total_agents: 6,
        total_workers: 4,
        agents_running: count_running_agents(),
        workers_running: count_running_workers()
      }
    }
  end

  @doc """
  Get mesh FQUN.
  """
  @spec get_mesh_fqun() :: map() | nil
  def get_mesh_fqun do
    case FQUN.lookup(:supervisor, :cluster, "distributed", "mesh") do
      {:ok, fqun} -> fqun
      {:error, _reason} -> nil
    end
  end

  @doc """
  Get aggregated metrics from all components.
  """
  @spec get_all_metrics() :: map()
  def get_all_metrics do
    %{
      timestamp: DateTime.utc_now(),
      agents: AgentMesh.get_all_metrics(),
      workers: WorkerMesh.get_all_metrics()
    }
  end

  @doc """
  Ping all components and return health status.
  """
  @spec health_check() :: map()
  def health_check do
    agent_pings = AgentMesh.ping_all()
    worker_pings = WorkerMesh.ping_all()

    agent_health = Enum.count(agent_pings, fn {_, r} -> match?({:pong, _}, r) end)
    worker_health = Enum.count(worker_pings, fn {_, r} -> match?({:pong, _}, r) end)

    %{
      timestamp: DateTime.utc_now(),
      overall_health: calculate_health(agent_health, worker_health),
      agents: %{
        total: 6,
        healthy: agent_health,
        pings: agent_pings
      },
      workers: %{
        total: 4,
        healthy: worker_health,
        pings: worker_pings
      }
    }
  end

  @doc """
  Execute a control command on the mesh.
  """
  @spec execute_command(atom(), map()) :: {:ok, term()} | {:error, atom()}
  def execute_command(command, params \\ %{}) do
    Logger.info("[DistributedMesh] Executing command", command: command, params: params)

    case command do
      :status ->
        {:ok, get_status()}

      :health ->
        {:ok, health_check()}

      :metrics ->
        {:ok, get_all_metrics()}

      :list_agents ->
        {:ok, AgentMesh.list_agents()}

      :list_workers ->
        {:ok, WorkerMesh.list_workers()}

      {:agent_command, agent_id, agent_cmd} ->
        AgentMesh.send_command(agent_id, agent_cmd, params)

      {:worker_job, worker_id, job} ->
        WorkerMesh.submit_job(worker_id, job)

      _ ->
        {:error, :unknown_command}
    end
  end

  @doc """
  Publish mesh status to Zenoh control plane.
  """
  @spec publish_status() :: {:ok, map()} | {:error, atom()}
  def publish_status do
    status = get_status()

    Indrajaal.Observability.ZenohCoordinator.publish_coord(
      "mesh/status",
      status
    )

    {:ok, status}
  rescue
    _ -> {:error, :zenoh_unavailable}
  end

  @doc """
  Subscribe to control commands from Zenoh.
  """
  @spec subscribe_to_control() :: :ok | {:error, atom()}
  def subscribe_to_control do
    Indrajaal.Observability.ZenohCoordinator.subscribe_coord(
      "mesh/control/*",
      fn topic, payload ->
        handle_control_message(topic, payload)
      end
    )
  rescue
    _ -> {:error, :zenoh_unavailable}
  end

  # ============================================================
  # SUPERVISOR CALLBACKS
  # ============================================================

  @impl true
  def init(_opts) do
    Logger.info("[DistributedMesh] Initializing distributed mesh - SC-MESH-001")

    # Register mesh supervisor FQUN (use :cluster type which is valid for supervisor layer)
    mesh_fqun =
      case FQUN.generate(:supervisor, :cluster, "distributed", "mesh") do
        {:ok, fqun} ->
          fqun

        {:error, reason} ->
          Logger.warning("[DistributedMesh] Could not register FQUN: #{inspect(reason)}")
          nil
      end

    Logger.info("[DistributedMesh] Mesh FQUN registered",
      fqun: mesh_fqun,
      agents: 6,
      workers: 4
    )

    children = [
      # Agent Mesh (6 agents)
      {AgentMesh, []},

      # Worker Mesh (4 workers)
      {WorkerMesh, []},

      # Status publisher
      {Task, fn -> start_status_publisher() end}
    ]

    Supervisor.init(children,
      strategy: :one_for_one,
      max_restarts: 10,
      max_seconds: 60
    )
  end

  # ============================================================
  # PRIVATE FUNCTIONS
  # ============================================================

  defp start_status_publisher do
    # Wait for meshes to initialize
    Process.sleep(5000)

    Logger.info("[DistributedMesh] Starting status publisher")

    # Initial publish
    publish_status()

    # Periodic publish loop
    status_publish_loop()
  end

  defp status_publish_loop do
    Process.sleep(@mesh_status_interval_ms)
    publish_status()
    status_publish_loop()
  end

  defp handle_control_message(topic, payload) do
    Logger.debug("[DistributedMesh] Control message received",
      topic: topic,
      payload: inspect(payload)
    )

    # Parse control command from topic
    command =
      topic
      |> String.split("/")
      |> List.last()
      |> String.to_atom()

    execute_command(command, payload)
  end

  defp count_running_agents do
    AgentMesh.list_agents()
    |> Enum.count(&(&1.status == :running))
  rescue
    _ -> 0
  end

  defp count_running_workers do
    WorkerMesh.list_workers()
    |> Enum.count(&(&1.status == :running))
  rescue
    _ -> 0
  end

  defp calculate_health(agent_health, worker_health) do
    total = 10
    healthy = agent_health + worker_health
    percentage = healthy / total * 100

    cond do
      percentage >= 90 -> :healthy
      percentage >= 50 -> :degraded
      true -> :critical
    end
  end
end
