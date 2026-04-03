defmodule Indrajaal.Distributed.Dashboard do
  @moduledoc """
  Distributed System Dashboard - Unified Monitoring & Control.

  WHAT: Provides unified dashboard for distributed system monitoring.
  WHY: SC-DASH-001 requires centralized visibility and control.
  CONSTRAINTS: Real-time updates, CEPAF integration, Zenoh control.

  ## Dashboard Components

  1. **Mesh Overview**: Agent and Worker status
  2. **FQUN Registry**: All registered unique names
  3. **CEPAF Integration**: Container monitoring
  4. **Metrics Aggregation**: System-wide metrics
  5. **Control Panel**: Command execution

  ## STAMP Constraints

  - SC-DASH-001: Real-time status updates
  - SC-DASH-002: CEPAF container visibility
  - SC-DASH-003: Metric aggregation
  - SC-DASH-004: Control command execution

  ## Dashboard Sections

  ```
  ┌─────────────────────────────────────────────────────────────┐
  │                    DISTRIBUTED MESH DASHBOARD               │
  ├─────────────────────────────────────────────────────────────┤
  │ MESH OVERVIEW                                               │
  │ ┌─────────────────┐  ┌─────────────────┐                   │
  │ │ Agents: 6/6     │  │ Workers: 4/4    │                   │
  │ │ Status: HEALTHY │  │ Status: HEALTHY │                   │
  │ └─────────────────┘  └─────────────────┘                   │
  ├─────────────────────────────────────────────────────────────┤
  │ CONTAINERS (CEPAF)                                          │
  │ ┌─────────────────────────────────────────────────────────┐│
  │ │ indrajaal-app: HEALTHY  │ indrajaal-db: HEALTHY         ││
  │ │ indrajaal-obs: HEALTHY  │                               ││
  │ └─────────────────────────────────────────────────────────┘│
  ├─────────────────────────────────────────────────────────────┤
  │ FQUN REGISTRY                                               │
  │ Registered: 15  │  Agents: 6  │  Workers: 4  │  Resources: 5│
  ├─────────────────────────────────────────────────────────────┤
  │ SYSTEM METRICS                                              │
  │ CPU: 45%  │  Memory: 60%  │  Latency: 12ms  │  Errors: 0%  │
  └─────────────────────────────────────────────────────────────┘
  ```

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-DASH-001 to SC-DASH-004 |
  """

  use GenServer
  require Logger

  alias Indrajaal.Distributed.{AgentMesh, DistributedMesh, FQUN, WorkerMesh}

  @refresh_interval_ms 5_000

  # ============================================================
  # PUBLIC API
  # ============================================================

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get the full dashboard view.
  """
  @spec get_dashboard() :: map()
  def get_dashboard do
    GenServer.call(__MODULE__, :get_dashboard)
  end

  @doc """
  Get mesh overview section.
  """
  @spec get_mesh_overview() :: map()
  def get_mesh_overview do
    GenServer.call(__MODULE__, :get_mesh_overview)
  end

  @doc """
  Get container status from CEPAF.
  """
  @spec get_container_status() :: list(map())
  def get_container_status do
    GenServer.call(__MODULE__, :get_container_status)
  end

  @doc """
  Get FQUN registry summary.
  """
  @spec get_fqun_summary() :: map()
  def get_fqun_summary do
    GenServer.call(__MODULE__, :get_fqun_summary)
  end

  @doc """
  Get system metrics aggregation.
  """
  @spec get_system_metrics() :: map()
  def get_system_metrics do
    GenServer.call(__MODULE__, :get_system_metrics)
  end

  @doc """
  Execute a control command.
  """
  @spec execute_command(atom(), map()) :: term()
  def execute_command(command, params \\ %{}) do
    GenServer.call(__MODULE__, {:execute_command, command, params})
  end

  @doc """
  Render dashboard as text (for CLI display).
  """
  @spec render_text() :: String.t()
  def render_text do
    GenServer.call(__MODULE__, :render_text)
  end

  # ============================================================
  # GENSERVER CALLBACKS
  # ============================================================

  @impl true
  def init(_opts) do
    Logger.info("[Dashboard] Initializing distributed dashboard - SC-DASH-001")

    # Register dashboard FQUN
    {:ok, fqun} = FQUN.generate(:service, :dashboard, "distributed", "main")

    state = %{
      fqun: fqun,
      started_at: DateTime.utc_now(),

      # Cached data
      mesh_status: nil,
      container_status: nil,
      fqun_registry: nil,
      system_metrics: nil,

      # Refresh tracking
      last_refresh: nil,
      refresh_count: 0
    }

    # Schedule initial refresh
    send(self(), :refresh)

    {:ok, state}
  end

  @impl true
  def handle_call(:get_dashboard, _from, state) do
    dashboard = build_dashboard(state)
    {:reply, dashboard, state}
  end

  @impl true
  def handle_call(:get_mesh_overview, _from, state) do
    overview = build_mesh_overview()
    {:reply, overview, state}
  end

  @impl true
  def handle_call(:get_container_status, _from, state) do
    containers = get_cepaf_status()
    {:reply, containers, state}
  end

  @impl true
  def handle_call(:get_fqun_summary, _from, state) do
    summary = build_fqun_summary()
    {:reply, summary, state}
  end

  @impl true
  def handle_call(:get_system_metrics, _from, state) do
    metrics = build_system_metrics()
    {:reply, metrics, state}
  end

  @impl true
  def handle_call({:execute_command, command, params}, _from, state) do
    result = DistributedMesh.execute_command(command, params)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:render_text, _from, state) do
    text = render_dashboard_text(state)
    {:reply, text, state}
  end

  @impl true
  def handle_info(:refresh, state) do
    new_state = refresh_dashboard(state)

    # Schedule next refresh
    Process.send_after(self(), :refresh, @refresh_interval_ms)

    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ============================================================
  # DASHBOARD BUILDING
  # ============================================================

  defp build_dashboard(state) do
    %{
      title: "DISTRIBUTED MESH DASHBOARD",
      version: "1.0.0",
      timestamp: DateTime.utc_now(),
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at),
      fqun: state.fqun,
      sections: %{
        mesh_overview: build_mesh_overview(),
        containers: get_cepaf_status(),
        fqun_registry: build_fqun_summary(),
        system_metrics: build_system_metrics(),
        agents: get_agent_details(),
        workers: get_worker_details()
      },
      refresh: %{
        last: state.last_refresh,
        count: state.refresh_count,
        interval_ms: @refresh_interval_ms
      }
    }
  end

  defp build_mesh_overview do
    health = DistributedMesh.health_check()

    %{
      overall_health: health.overall_health,
      agents: %{
        total: 6,
        healthy: health.agents.healthy,
        status: agent_status_summary(health.agents)
      },
      workers: %{
        total: 4,
        healthy: health.workers.healthy,
        status: worker_status_summary(health.workers)
      }
    }
  rescue
    _ ->
      %{
        overall_health: :unknown,
        agents: %{total: 6, healthy: 0, status: :unavailable},
        workers: %{total: 4, healthy: 0, status: :unavailable}
      }
  end

  defp get_cepaf_status do
    # Get container status from CEPAF agent
    case AgentMesh.send_command(:cepaf_agent, :list_containers, %{}) do
      {:ok, containers} ->
        %{
          total: length(containers),
          containers: containers,
          status: :connected
        }

      _ ->
        # Return simulated status if CEPAF unavailable
        %{
          total: 3,
          containers: [
            %{name: "indrajaal-app", status: :healthy, type: :application},
            %{name: "indrajaal-db", status: :healthy, type: :database},
            %{name: "indrajaal-obs", status: :healthy, type: :observability}
          ],
          status: :simulated
        }
    end
  rescue
    _ ->
      %{total: 0, containers: [], status: :error}
  end

  defp build_fqun_summary do
    registry = FQUN.list_all()

    by_layer =
      Enum.group_by(registry, fn {fqun, _} ->
        fqun |> String.split("/") |> Enum.at(1)
      end)

    %{
      total: length(registry),
      by_layer: %{
        agents: length(Map.get(by_layer, "agent", [])),
        workers: length(Map.get(by_layer, "worker", [])),
        resources: length(Map.get(by_layer, "resource", [])),
        services: length(Map.get(by_layer, "service", [])),
        supervisors: length(Map.get(by_layer, "supervisor", []))
      },
      recent: Enum.take(registry, 5)
    }
  rescue
    _ ->
      %{total: 0, by_layer: %{}, recent: []}
  end

  defp build_system_metrics do
    # Collect from Cortex agent
    cortex_metrics =
      case AgentMesh.send_command(:cortex_agent, :get_health, %{}) do
        {:ok, health} -> health
        _ -> nil
      end

    # Memory stats
    memory = :erlang.memory()
    total_mem = Keyword.get(memory, :total, 1)
    used_mem = Keyword.get(memory, :processes, 0) + Keyword.get(memory, :binary, 0)

    %{
      cpu_load: estimate_cpu(),
      memory: %{
        used_mb: div(used_mem, 1_048_576),
        total_mb: div(total_mem, 1_048_576),
        percentage: Float.round(used_mem / total_mem * 100, 1)
      },
      processes: length(Process.list()),
      run_queue: :erlang.statistics(:run_queue),
      cortex: cortex_metrics
    }
  rescue
    _ ->
      %{cpu_load: 0, memory: %{}, processes: 0, run_queue: 0, cortex: nil}
  end

  defp get_agent_details do
    AgentMesh.list_agents()
  rescue
    _ -> []
  end

  defp get_worker_details do
    WorkerMesh.list_workers()
  rescue
    _ -> []
  end

  defp refresh_dashboard(state) do
    mesh_status = DistributedMesh.get_status()
    container_status = get_cepaf_status()
    fqun_registry = build_fqun_summary()
    system_metrics = build_system_metrics()

    # Publish to Zenoh
    publish_dashboard_state(mesh_status, system_metrics)

    %{
      state
      | mesh_status: mesh_status,
        container_status: container_status,
        fqun_registry: fqun_registry,
        system_metrics: system_metrics,
        last_refresh: DateTime.utc_now(),
        refresh_count: state.refresh_count + 1
    }
  rescue
    e ->
      Logger.warning("[Dashboard] Refresh failed", error: inspect(e))
      %{state | last_refresh: DateTime.utc_now(), refresh_count: state.refresh_count + 1}
  end

  defp publish_dashboard_state(mesh_status, system_metrics) do
    Indrajaal.Observability.ZenohCoordinator.publish_coord(
      "dashboard/state",
      %{
        mesh: mesh_status,
        metrics: system_metrics,
        timestamp: DateTime.utc_now()
      }
    )
  rescue
    _ -> :ok
  end

  # ============================================================
  # TEXT RENDERING
  # ============================================================

  defp render_dashboard_text(state) do
    overview = build_mesh_overview()
    containers = get_cepaf_status()
    fqun_summary = build_fqun_summary()
    metrics = build_system_metrics()

    """
    ╔═══════════════════════════════════════════════════════════════════╗
    ║              DISTRIBUTED MESH DASHBOARD v1.0.0                    ║
    ║              #{format_timestamp(DateTime.utc_now())}                         ║
    ╠═══════════════════════════════════════════════════════════════════╣
    ║ MESH OVERVIEW                                                     ║
    ║ ┌────────────────────────┐  ┌────────────────────────┐            ║
    ║ │ Agents: #{pad_left(overview.agents.healthy, 1)}/#{overview.agents.total}           │  │ Workers: #{pad_left(overview.workers.healthy, 1)}/#{overview.workers.total}          │            ║
    ║ │ Status: #{pad_right(atom_to_status(overview.overall_health), 13)}│  │ Status: #{pad_right(atom_to_status(overview.overall_health), 13)}│            ║
    ║ └────────────────────────┘  └────────────────────────┘            ║
    ╠═══════════════════════════════════════════════════════════════════╣
    ║ CONTAINERS (CEPAF) - #{containers.status}                                     ║
    #{render_containers(containers.containers)}
    ╠═══════════════════════════════════════════════════════════════════╣
    ║ FQUN REGISTRY                                                     ║
    ║ Total: #{pad_left(fqun_summary.total, 3)} │ Agents: #{pad_left(fqun_summary.by_layer.agents, 2)} │ Workers: #{pad_left(fqun_summary.by_layer.workers, 2)} │ Resources: #{pad_left(fqun_summary.by_layer.resources, 2)}  ║
    ╠═══════════════════════════════════════════════════════════════════╣
    ║ SYSTEM METRICS                                                    ║
    ║ CPU: #{pad_left(metrics.cpu_load, 3)}% │ Memory: #{pad_left(metrics.memory.percentage, 5)}% │ Procs: #{pad_left(metrics.processes, 5)} │ Queue: #{pad_left(metrics.run_queue, 2)}   ║
    ╠═══════════════════════════════════════════════════════════════════╣
    ║ UPTIME: #{format_uptime(state.started_at)} │ REFRESHES: #{pad_left(state.refresh_count, 5)}                    ║
    ╚═══════════════════════════════════════════════════════════════════╝
    """
  end

  defp render_containers(containers) when is_list(containers) do
    Enum.map_join(containers, "\n", fn c ->
      "║ │ #{pad_right(c.name, 20)}: #{pad_right(atom_to_status(c.status), 10)}│"
    end)
  end

  defp render_containers(_),
    do: "║ │ No containers available                                         │"

  defp format_timestamp(dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
  end

  defp format_uptime(started_at) do
    seconds = DateTime.diff(DateTime.utc_now(), started_at)
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    secs = rem(seconds, 60)
    "#{pad_left(hours, 2)}h #{pad_left(minutes, 2)}m #{pad_left(secs, 2)}s"
  end

  defp atom_to_status(:healthy), do: "HEALTHY"
  defp atom_to_status(:degraded), do: "DEGRADED"
  defp atom_to_status(:critical), do: "CRITICAL"
  defp atom_to_status(:running), do: "RUNNING"
  defp atom_to_status(:stopped), do: "STOPPED"
  defp atom_to_status(:unknown), do: "UNKNOWN"
  defp atom_to_status(other), do: String.upcase(to_string(other))

  defp pad_left(val, width) when is_integer(val) do
    String.pad_leading(to_string(val), width)
  end

  defp pad_left(val, width) when is_float(val) do
    String.pad_leading(:erlang.float_to_binary(val, decimals: 1), width)
  end

  defp pad_left(val, width) do
    String.pad_leading(to_string(val), width)
  end

  defp pad_right(val, width) do
    String.pad_trailing(to_string(val), width)
  end

  defp estimate_cpu do
    case :erlang.statistics(:run_queue) do
      0 -> 10
      q when q < 4 -> 30
      q when q < 8 -> 60
      _ -> 90
    end
  end

  defp agent_status_summary(%{healthy: h, total: t}) when h == t, do: :healthy
  defp agent_status_summary(%{healthy: h, total: t}) when h >= t / 2, do: :degraded
  defp agent_status_summary(_), do: :critical

  defp worker_status_summary(%{healthy: h, total: t}) when h == t, do: :healthy
  defp worker_status_summary(%{healthy: h, total: t}) when h >= t / 2, do: :degraded
  defp worker_status_summary(_), do: :critical
end
