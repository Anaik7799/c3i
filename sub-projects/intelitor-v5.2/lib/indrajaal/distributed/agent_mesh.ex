defmodule Indrajaal.Distributed.AgentMesh do
  @moduledoc """
  7-Agent Mesh Architecture with Zenoh State/Control Communication.

  WHAT: Manages 7 specialized agents for distributed system operation.
  WHY: SC-AGENT-001 requires multi-agent coordination for complex operations.
  CONSTRAINTS: All agents must have FQUNs, communicate via Zenoh, support mesh discovery.

  ## Agent Architecture (7 Agents)

  ```
  ┌─────────────────────────────────────────────────────────────────────────────┐
  │                         AGENT MESH SUPERVISOR                               │
  │                             (AgentMesh)                                     │
  └───────────────────────────────────┬─────────────────────────────────────────┘
                                      │
    ┌─────────────────────────────────┼───────────────────────────────────────┐
    │                                 │                                       │
    ▼                                 ▼                                       ▼
  ┌───────────────┐  ┌─────────────────────────┐  ┌───────────────────────────┐
  │ Agent 1:      │  │ Agent 2:                │  │ Agent 3:                  │
  │ OODA          │  │ ACE                     │  │ Cortex                    │
  │ Controller    │  │ (Autonomic Compute)     │  │ (Cognitive Control)       │
  │               │  │                         │  │                           │
  │ - Observe     │  │ - Resource Monitor      │  │ - Stress Analysis         │
  │ - Orient      │  │ - Elastic Scaling       │  │ - Homeostasis             │
  │ - Decide      │  │ - FLAME Management      │  │ - Reflexes                │
  │ - Act         │  │                         │  │                           │
  └───────────────┘  └─────────────────────────┘  └───────────────────────────┘
    │                                 │                                       │
    └─────────────────────────────────┼───────────────────────────────────────┘
                                      │
    ┌─────────────────────────────────┼───────────────────────────────────────┐
    │                                 │                                       │
    ▼                                 ▼                                       ▼
  ┌───────────────┐  ┌─────────────────────────┐  ┌───────────────────────────┐
  │ Agent 4:      │  │ Agent 5:                │  │ Agent 6:                  │
  │ Fractal       │  │ CEPAF                   │  │ Sentinel                  │
  │ Logger        │  │ Bridge                  │  │ Guardian                  │
  │               │  │                         │  │                           │
  │ - 5-Level     │  │ - Container Ops         │  │ - Health Monitoring       │
  │ - Batching    │  │ - F# CLI Interface      │  │ - Quorum Management       │
  │ - Routing     │  │ - Telemetry             │  │ - Split-Brain Prevent     │
  └───────────────┘  └─────────────────────────┘  └───────────────────────────┘
                                      │
                                      ▼
                    ┌─────────────────────────────────────┐
                    │ Agent 7: KPI DASHBOARD              │
                    │ (Real-Time Progress Tracking)       │
                    │                                     │
                    │ - TodoList Tracking (30s refresh)   │
                    │ - Agent/Worker Metrics              │
                    │ - System KPIs                       │
                    │ - Full-Screen Dashboard             │
                    │ - Zenoh Coordination                │
                    └─────────────────────────────────────┘
  ```

  ## STAMP Constraints
  - SC-AGENT-001: All agents MUST have FQUN
  - SC-AGENT-002: Agent communication via Zenoh
  - SC-AGENT-003: Agent state published to Zenoh
  - SC-AGENT-004: Agents respond to control commands

  ## AOR Rules
  - AOR-AGENT-001: Agents MUST register FQUN on start
  - AOR-AGENT-002: Agents MUST publish heartbeat every 5s
  - AOR-AGENT-003: Agents MUST respond to ping within 100ms
  - AOR-AGENT-004: Agents MUST gracefully shutdown on terminate

  ## Mathematical Specification

  ```
  AgentMesh := (Agents, Topology, Communication)

  where:
    Agents = {OODA, ACE, Cortex, Fractal, CEPAF, Sentinel}
    |Agents| = 6

    Topology := FullMesh(Agents)
    ∀ a₁, a₂ ∈ Agents: a₁ ≠ a₂ ⟹ Connected(a₁, a₂)

    Communication := Zenoh(KeySpace, Protocol)
    KeySpace = "indrajaal/agent/**"
    Protocol = {state, control, heartbeat}

  Liveness Invariant:
    ∀ agent ∈ Agents: □(Running(agent) ⟹ ◇Heartbeat(agent))
  ```
  """

  use Supervisor
  require Logger

  alias Indrajaal.Distributed.FQUN

  # ============================================================
  # AGENT DEFINITIONS
  # ============================================================

  @agents [
    # Agent 1: OODA Controller - Cybernetic decision loop
    %{
      id: :ooda_agent,
      module: Indrajaal.Distributed.Agents.OODAAgent,
      type: :cybernetic,
      namespace: "ooda",
      name: "controller",
      description: "OODA loop controller for observe-orient-decide-act cycles"
    },
    # Agent 2: ACE - Autonomic Computing Engine
    %{
      id: :ace_agent,
      module: Indrajaal.Distributed.Agents.ACEAgent,
      type: :cybernetic,
      namespace: "ace",
      name: "engine",
      description: "Autonomic computing engine for self-management"
    },
    # Agent 3: Cortex - Cognitive Controller
    %{
      id: :cortex_agent,
      module: Indrajaal.Distributed.Agents.CortexAgent,
      type: :cybernetic,
      namespace: "cortex",
      name: "controller",
      description: "Cortex cognitive controller for stress and homeostasis"
    },
    # Agent 4: Fractal - 5-Level Logging
    %{
      id: :fractal_agent,
      module: Indrajaal.Distributed.Agents.FractalAgent,
      type: :observability,
      namespace: "fractal",
      name: "logger",
      description: "Fractal 5-level controllable logging agent"
    },
    # Agent 5: CEPAF - Container Bridge
    %{
      id: :cepaf_agent,
      module: Indrajaal.Distributed.Agents.CEPAFAgent,
      type: :integration,
      namespace: "cepaf",
      name: "bridge",
      description: "CEPAF container operations bridge"
    },
    # Agent 6: Sentinel - Health Guardian
    %{
      id: :sentinel_agent,
      module: Indrajaal.Distributed.Agents.SentinelAgent,
      type: :cybernetic,
      namespace: "sentinel",
      name: "guardian",
      description: "Sentinel health and quorum guardian"
    },
    # Agent 7: KPI Dashboard - Real-Time Progress Tracking
    %{
      id: :kpi_dashboard_agent,
      module: Indrajaal.Distributed.Agents.KPIDashboardAgent,
      type: :observability,
      namespace: "kpi",
      name: "dashboard",
      description: "CEPAF KPI dashboard agent for real-time progress tracking"
    }
  ]

  @zenoh_prefix "indrajaal/agent"

  # ============================================================
  # CLIENT API
  # ============================================================

  @spec start_link(Keyword.t()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Get all agent definitions."
  @spec agents() :: list(map())
  def agents, do: @agents

  @doc "Get agent count."
  @spec agent_count() :: non_neg_integer()
  def agent_count, do: length(@agents)

  @doc "Get agent by ID."
  @spec get_agent(atom()) :: map() | nil
  def get_agent(id) do
    Enum.find(@agents, fn a -> a.id == id end)
  end

  @doc "Get all agent FQUNs."
  @spec agent_fquns() :: list(map())
  def agent_fquns do
    FQUN.find_by_layer(:agent)
  end

  @doc "Get mesh status."
  @spec mesh_status() :: map()
  def mesh_status do
    agents_status =
      @agents
      |> Enum.map(fn agent ->
        pid = Process.whereis(agent.module)

        status =
          if pid && Process.alive?(pid) do
            :running
          else
            :stopped
          end

        {agent.id, %{status: status, pid: pid, description: agent.description}}
      end)
      |> Map.new()

    %{
      total_agents: length(@agents),
      running: Enum.count(agents_status, fn {_, s} -> s.status == :running end),
      stopped: Enum.count(agents_status, fn {_, s} -> s.status == :stopped end),
      agents: agents_status,
      zenoh_prefix: @zenoh_prefix
    }
  end

  @doc "Publish agent state to Zenoh."
  @spec publish_state(atom(), map()) :: :ok | {:error, term()}
  def publish_state(agent_id, state) do
    key = "#{@zenoh_prefix}/#{agent_id}/state"
    payload = Map.put(state, :timestamp, DateTime.utc_now())

    Indrajaal.Observability.ZenohCoordinator.publish_coord(key, payload)
  end

  @doc "Send control command to agent."
  @spec send_command(atom(), atom(), map()) :: term()
  def send_command(agent_id, command, params \\ %{}) do
    agent = get_agent(agent_id)

    if agent do
      GenServer.call(agent.module, {:command, command, params})
    else
      {:error, :agent_not_found}
    end
  rescue
    _ -> {:error, :agent_unavailable}
  end

  @doc "Broadcast command to all agents."
  @spec broadcast_command(atom(), map()) :: map()
  def broadcast_command(command, params \\ %{}) do
    @agents
    |> Enum.map(fn agent ->
      result = send_command(agent.id, command, params)
      {agent.id, result}
    end)
    |> Map.new()
  end

  @doc "List all agents with their current status."
  @spec list_agents() :: list(map())
  def list_agents do
    Enum.map(@agents, fn agent ->
      status = get_agent_status(agent.module)

      %{
        id: agent.id,
        module: agent.module,
        type: agent.type,
        namespace: agent.namespace,
        name: agent.name,
        description: agent.description,
        status: status
      }
    end)
  end

  @doc "Get metrics from all agents."
  @spec get_all_metrics() :: map()
  def get_all_metrics do
    Enum.reduce(@agents, %{}, fn agent, acc ->
      metrics =
        try do
          agent.module.get_metrics()
        rescue
          _ -> %{status: :not_available}
        catch
          :exit, _ -> %{status: :not_running}
        end

      Map.put(acc, agent.id, metrics)
    end)
  end

  @doc "Ping all agents and return status."
  @spec ping_all() :: map()
  def ping_all do
    @agents
    |> Enum.map(fn agent ->
      result =
        try do
          agent.module.ping()
        rescue
          _ -> {:error, :not_responding}
        catch
          :exit, _ -> {:error, :not_running}
        end

      {agent.id, result}
    end)
    |> Map.new()
  end

  defp get_agent_status(module) do
    case Process.whereis(module) do
      nil -> :not_running
      pid when is_pid(pid) -> :running
    end
  rescue
    _ -> :error
  end

  # ============================================================
  # SUPERVISOR CALLBACKS
  # ============================================================

  @impl true
  def init(_opts) do
    # Build child specifications
    children =
      Enum.map(@agents, fn agent ->
        {agent.module,
         [
           id: agent.id,
           type: agent.type,
           namespace: agent.namespace,
           name: agent.name
         ]}
      end)

    Logger.info("[AgentMesh] Starting 6-agent mesh - SC-AGENT-001",
      agents: Enum.map(@agents, & &1.id),
      zenoh_prefix: @zenoh_prefix
    )

    Supervisor.init(children, strategy: :one_for_one, max_restarts: 10, max_seconds: 60)
  end
end
