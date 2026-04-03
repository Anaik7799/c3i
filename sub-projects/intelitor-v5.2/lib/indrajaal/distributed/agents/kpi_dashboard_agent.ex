defmodule Indrajaal.Distributed.Agents.KPIDashboardAgent do
  @moduledoc """
  CEPAF KPI Dashboard Agent for Real-Time Progress Tracking.

  WHAT: Provides real-time KPI tracking and dashboard rendering for Claude+CEPAF development.
  WHY: SC-OBS-001 requires continuous observability during development operations.
  CONSTRAINTS: Updates every 30 seconds, full-screen rendering, Zenoh coordination.

  ## Architecture (5-Level Fractal Design)

  ```
  ┌─────────────────────────────────────────────────────────────────────────────┐
  │                    CEPAF KPI DASHBOARD AGENT                                │
  │                         (Full-Screen Mode)                                  │
  └─────────────────────────────────────────────────────────────────────────────┘
  │
  ├── Level 1: Executive Summary (Top Bar)
  │   ├── Overall Progress: ██████████░░░░░░░░░░ 45%
  │   ├── Tasks: 12/27 Complete
  │   └── Health: ●●●○○ 3/5 Systems OK
  │
  ├── Level 2: Agent Status (4 Columns)
  │   ├── OODA Agent:     [RUNNING] Cycles: 28,583 | Latency: 1ms
  │   ├── ACE Agent:      [RUNNING] MAPE-K: Active | Knowledge: 156 items
  │   ├── Cortex Agent:   [RUNNING] Stress: 0.23 | Reflexes: 0
  │   └── Fractal Agent:  [RUNNING] Level: 3 | Events: 45,230
  │
  ├── Level 3: Worker Metrics (4 Columns)
  │   ├── FLAME Worker:   Pools: 2 | Dispatched: 1,234 | Utilization: 67%
  │   ├── Oban Worker:    Jobs: 89/120 | Failed: 3 | Retrying: 2
  │   ├── Broadway:       Pipelines: 1 | Processed: 56,789 | Lag: 12ms
  │   └── Batch Worker:   Active: 1 | Checkpoints: 8 | Progress: 78%
  │
  ├── Level 4: TodoList Progress (Full Width)
  │   ├── [✓] Fix Guardian GenServer         | COMPLETED | 14:02:33
  │   ├── [✓] Create HybridLogicalClock      | COMPLETED | 14:03:15
  │   ├── [→] Create CEPAF KPI Dashboard     | IN_PROGRESS | 14:05:00
  │   ├── [ ] Add Zenoh coordination         | PENDING
  │   └── [ ] Run distributed mesh tests     | PENDING
  │
  └── Level 5: System Metrics (Bottom Bar)
      ├── CPU: 34% | Memory: 2.1GB/8GB | Containers: 3/3 UP
      ├── FQUN Registry: 47 items | Zenoh: Connected
      └── Last Update: 2025-12-26 14:05:30 | Next: 30s
  ```

  ## STAMP Constraints
  - SC-OBS-001: Dashboard MUST update every 30 seconds
  - SC-OBS-002: All KPIs MUST be collected via Zenoh
  - SC-OBS-003: Dashboard MUST handle missing data gracefully

  ## AOR Rules
  - AOR-KPI-001: KPI Agent MUST publish status to Zenoh
  - AOR-KPI-002: Dashboard refresh MUST complete < 1s
  - AOR-KPI-003: All metrics MUST include timestamps
  """

  use Indrajaal.Distributed.Agents.BaseAgent

  alias Indrajaal.Distributed.FQUN
  alias Indrajaal.Distributed.AgentMesh
  alias Indrajaal.Distributed.WorkerMesh

  require Logger

  # 30 seconds
  @refresh_interval 30_000
  @zenoh_topic "indrajaal/kpi/dashboard"

  # ============================================================
  # AGENT CALLBACKS
  # ============================================================

  @impl true
  def agent_init(_opts) do
    # Schedule first refresh
    Process.send_after(self(), :refresh_kpis, 1000)

    state = %{
      kpis: %{
        overall_progress: 0,
        tasks_completed: 0,
        tasks_total: 0,
        agents_running: 0,
        workers_running: 0,
        fqun_count: 0,
        last_update: nil
      },
      todolist: [],
      agent_metrics: %{},
      worker_metrics: %{},
      system_metrics: %{},
      refresh_count: 0,
      render_mode: :full_screen
    }

    {:ok, state}
  end

  @impl true
  def agent_state(state) do
    Map.take(state, [:kpis, :todolist, :refresh_count, :render_mode])
  end

  @impl true
  def agent_metrics(state) do
    %{
      refresh_count: state.refresh_count,
      kpis: state.kpis,
      render_mode: state.render_mode,
      last_update: state.kpis.last_update
    }
  end

  @impl true
  def handle_command(:refresh, _params, state) do
    new_state = collect_all_kpis(state)
    {:ok, :refreshed, new_state}
  end

  @impl true
  def handle_command(:set_render_mode, %{mode: mode}, state)
      when mode in [:full_screen, :compact, :minimal] do
    {:ok, {:mode_set, mode}, %{state | render_mode: mode}}
  end

  @impl true
  def handle_command(:get_dashboard, _params, state) do
    dashboard = render_dashboard(state)
    {:ok, dashboard, state}
  end

  @impl true
  def handle_command(:get_todolist, _params, state) do
    {:ok, state.todolist, state}
  end

  @impl true
  def handle_command(cmd, _params, state) do
    {:error, {:unknown_command, cmd}, state}
  end

  @impl true
  def handle_agent_info(:refresh_kpis, state) do
    new_state = collect_all_kpis(state)
    dashboard = render_dashboard(new_state)

    # Publish to Zenoh for external consumers
    publish_to_zenoh(dashboard)

    # Log dashboard to console
    Logger.info("[KPI Dashboard] Refresh ##{new_state.refresh_count}\n#{dashboard}")

    # Schedule next refresh
    Process.send_after(self(), :refresh_kpis, @refresh_interval)

    {:noreply, new_state}
  end

  def handle_agent_info(_msg, state), do: {:noreply, state}

  # ============================================================
  # KPI COLLECTION
  # ============================================================

  defp collect_all_kpis(state) do
    now = DateTime.utc_now()

    # Collect agent metrics
    agent_metrics = collect_agent_metrics()

    # Collect worker metrics
    worker_metrics = collect_worker_metrics()

    # Collect system metrics
    system_metrics = collect_system_metrics()

    # Collect todolist
    todolist = collect_todolist()

    # Calculate KPIs
    tasks_completed = Enum.count(todolist, fn t -> t.status == :completed end)
    tasks_total = length(todolist)

    kpis = %{
      overall_progress: calculate_progress(tasks_completed, tasks_total),
      tasks_completed: tasks_completed,
      tasks_total: tasks_total,
      agents_running: count_running(agent_metrics),
      workers_running: count_running(worker_metrics),
      fqun_count: count_fquns(),
      last_update: now
    }

    %{
      state
      | kpis: kpis,
        todolist: todolist,
        agent_metrics: agent_metrics,
        worker_metrics: worker_metrics,
        system_metrics: system_metrics,
        refresh_count: state.refresh_count + 1
    }
  end

  defp collect_agent_metrics do
    try do
      AgentMesh.list_agents()
      |> Enum.map(fn agent ->
        metrics =
          try do
            agent.module.get_metrics()
          rescue
            _ -> %{status: :not_available}
          catch
            :exit, _ -> %{status: :not_running}
          end

        {agent.id, Map.merge(agent, %{metrics: metrics})}
      end)
      |> Map.new()
    rescue
      _ -> %{}
    end
  end

  defp collect_worker_metrics do
    try do
      WorkerMesh.list_workers()
      |> Enum.map(fn worker ->
        metrics =
          try do
            worker.module.get_metrics()
          rescue
            _ -> %{status: :not_available}
          catch
            :exit, _ -> %{status: :not_running}
          end

        {worker.id, Map.merge(worker, %{metrics: metrics})}
      end)
      |> Map.new()
    rescue
      _ -> %{}
    end
  end

  defp collect_system_metrics do
    memory = :erlang.memory()

    %{
      cpu_percent: get_cpu_percent(),
      memory_used_mb: div(memory[:total], 1024 * 1024),
      memory_processes_mb: div(memory[:processes], 1024 * 1024),
      process_count: length(Process.list()),
      uptime_seconds: get_uptime_seconds(),
      node: node(),
      otp_release: System.otp_release()
    }
  end

  defp collect_todolist do
    # This would integrate with PROJECT_TODOLIST.md or mix todo
    # For now, return the current session tasks
    [
      %{
        id: 1,
        content: "Fix Guardian GenServer and compile",
        status: :completed,
        timestamp: ~U[2025-12-26 14:02:33Z]
      },
      %{
        id: 2,
        content: "Create HybridLogicalClock module",
        status: :completed,
        timestamp: ~U[2025-12-26 14:03:15Z]
      },
      %{
        id: 3,
        content: "Fix PropCheck let syntax in FQUN tests",
        status: :completed,
        timestamp: ~U[2025-12-26 14:04:00Z]
      },
      %{
        id: 4,
        content: "Create CEPAF KPI Dashboard Agent",
        status: :in_progress,
        timestamp: ~U[2025-12-26 14:05:00Z]
      },
      %{id: 5, content: "Create TodoList tracking dashboard", status: :pending, timestamp: nil},
      %{id: 6, content: "Add Zenoh coordination", status: :pending, timestamp: nil},
      %{id: 7, content: "Create 5-level journal entry", status: :pending, timestamp: nil},
      %{id: 8, content: "Run distributed mesh tests", status: :pending, timestamp: nil}
    ]
  end

  # ============================================================
  # DASHBOARD RENDERING
  # ============================================================

  defp render_dashboard(state) do
    case state.render_mode do
      :full_screen -> render_full_screen(state)
      :compact -> render_compact(state)
      :minimal -> render_minimal(state)
    end
  end

  defp render_full_screen(state) do
    width = 100

    [
      render_header(width),
      render_level1_executive_summary(state, width),
      render_separator(width),
      render_level2_agents(state, width),
      render_separator(width),
      render_level3_workers(state, width),
      render_separator(width),
      render_level4_todolist(state, width),
      render_separator(width),
      render_level5_system(state, width),
      render_footer(state, width)
    ]
    |> Enum.join("\n")
  end

  defp render_compact(state) do
    kpis = state.kpis

    """
    [KPI] Progress: #{kpis.overall_progress}% | Tasks: #{kpis.tasks_completed}/#{kpis.tasks_total} | Agents: #{kpis.agents_running} | Workers: #{kpis.workers_running}
    """
  end

  defp render_minimal(state) do
    "#{state.kpis.overall_progress}% Complete"
  end

  defp render_header(width) do
    title = "CEPAF KPI DASHBOARD - Real-Time Progress Tracking"
    pad = div(width - String.length(title), 2)
    border = String.duplicate("═", width)

    """
    ╔#{border}╗
    ║#{String.duplicate(" ", pad)}#{title}#{String.duplicate(" ", width - pad - String.length(title))}║
    ╠#{border}╣
    """
  end

  defp render_level1_executive_summary(state, width) do
    kpis = state.kpis
    progress_bar = render_progress_bar(kpis.overall_progress, 30)

    line1 = "│ Level 1: EXECUTIVE SUMMARY"
    line2 = "│  Progress: #{progress_bar} #{kpis.overall_progress}%"

    line3 =
      "│  Tasks: #{kpis.tasks_completed}/#{kpis.tasks_total} Complete | Agents: #{kpis.agents_running} Running | Workers: #{kpis.workers_running} Running"

    [
      String.pad_trailing(line1, width) <> "│",
      String.pad_trailing(line2, width) <> "│",
      String.pad_trailing(line3, width) <> "│"
    ]
    |> Enum.join("\n")
  end

  defp render_level2_agents(state, width) do
    agents = state.agent_metrics
    header = "│ Level 2: AGENT STATUS"

    agent_lines =
      agents
      |> Enum.take(4)
      |> Enum.map(fn {id, agent} ->
        status = if agent.status == :running, do: "[RUNNING]", else: "[STOPPED]"
        "│  #{format_id(id)}: #{status} | #{inspect(Map.get(agent.metrics, :summary, %{}))}"
      end)

    if Enum.empty?(agent_lines) do
      [
        String.pad_trailing(header, width) <> "│",
        String.pad_trailing("│  (No agents available)", width) <> "│"
      ]
      |> Enum.join("\n")
    else
      [
        String.pad_trailing(header, width) <> "│"
        | agent_lines |> Enum.map(&(String.pad_trailing(&1, width) <> "│"))
      ]
      |> Enum.join("\n")
    end
  end

  defp render_level3_workers(state, width) do
    workers = state.worker_metrics
    header = "│ Level 3: WORKER METRICS"

    worker_lines =
      workers
      |> Enum.take(4)
      |> Enum.map(fn {id, worker} ->
        status = if worker.status == :running, do: "[RUNNING]", else: "[STOPPED]"
        "│  #{format_id(id)}: #{status} | #{inspect(Map.get(worker.metrics, :summary, %{}))}"
      end)

    if Enum.empty?(worker_lines) do
      [
        String.pad_trailing(header, width) <> "│",
        String.pad_trailing("│  (No workers available)", width) <> "│"
      ]
      |> Enum.join("\n")
    else
      [
        String.pad_trailing(header, width) <> "│"
        | worker_lines |> Enum.map(&(String.pad_trailing(&1, width) <> "│"))
      ]
      |> Enum.join("\n")
    end
  end

  defp render_level4_todolist(state, width) do
    header = "│ Level 4: TODOLIST PROGRESS"

    todo_lines =
      state.todolist
      |> Enum.map(fn task ->
        icon =
          case task.status do
            :completed -> "✓"
            :in_progress -> "→"
            :pending -> " "
          end

        status_str = task.status |> Atom.to_string() |> String.upcase()

        time =
          if task.timestamp, do: " | #{Calendar.strftime(task.timestamp, "%H:%M:%S")}", else: ""

        "│  [#{icon}] #{String.slice(task.content, 0, 45)}... | #{status_str}#{time}"
      end)

    [
      String.pad_trailing(header, width) <> "│"
      | todo_lines |> Enum.map(&(String.pad_trailing(String.slice(&1, 0, width), width) <> "│"))
    ]
    |> Enum.join("\n")
  end

  defp render_level5_system(state, width) do
    sys = state.system_metrics
    header = "│ Level 5: SYSTEM METRICS"

    line1 =
      "│  CPU: #{sys.cpu_percent}% | Memory: #{sys.memory_used_mb}MB | Processes: #{sys.process_count}"

    line2 = "│  FQUN Registry: #{state.kpis.fqun_count} items | Node: #{sys.node}"
    line3 = "│  OTP: #{sys.otp_release} | Uptime: #{format_uptime(sys.uptime_seconds)}"

    [
      String.pad_trailing(header, width) <> "│",
      String.pad_trailing(line1, width) <> "│",
      String.pad_trailing(line2, width) <> "│",
      String.pad_trailing(line3, width) <> "│"
    ]
    |> Enum.join("\n")
  end

  defp render_footer(state, width) do
    now = DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S")
    line = "│ Last Update: #{now} | Refresh ##{state.refresh_count} | Next: 30s"
    border = String.duplicate("═", width)

    """
    #{String.pad_trailing(line, width)}│
    ╚#{border}╝
    """
  end

  defp render_separator(width) do
    "╟#{String.duplicate("─", width)}╢"
  end

  defp render_progress_bar(percent, width) do
    filled = div(percent * width, 100)
    empty = width - filled
    "█" |> String.duplicate(filled) |> Kernel.<>(String.duplicate("░", empty))
  end

  # ============================================================
  # HELPERS
  # ============================================================

  defp calculate_progress(completed, total) when total > 0 do
    div(completed * 100, total)
  end

  defp calculate_progress(_, _), do: 0

  defp count_running(metrics) do
    metrics
    |> Enum.count(fn {_, m} -> m.status == :running end)
  end

  defp count_fquns do
    try do
      FQUN.list_all() |> length()
    rescue
      _ -> 0
    end
  end

  defp get_cpu_percent do
    try do
      :cpu_sup.util()
    rescue
      _ -> 0
    catch
      :exit, _ -> 0
    end
  end

  defp get_uptime_seconds do
    {uptime_ms, _} = :erlang.statistics(:wall_clock)
    div(uptime_ms, 1000)
  end

  defp format_uptime(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    secs = rem(seconds, 60)
    "#{hours}h #{minutes}m #{secs}s"
  end

  defp format_id(id) do
    id
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
    |> String.pad_trailing(15)
  end

  defp publish_to_zenoh(dashboard) do
    try do
      Indrajaal.Observability.ZenohCoordinator.publish_coord(@zenoh_topic, %{
        dashboard: dashboard,
        timestamp: DateTime.utc_now()
      })
    rescue
      _ -> :ok
    end
  end
end
