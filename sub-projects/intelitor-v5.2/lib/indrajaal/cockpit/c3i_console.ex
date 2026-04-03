defmodule Indrajaal.Cockpit.C3IConsole do
  @moduledoc """
  C3I Multi-Agent Console Dashboard - Full-Screen Verbose Telemetry System

  WHAT: A comprehensive multi-agent orchestration dashboard with:
        - 5 Agents + 1 Supervisor architecture
        - Real-time verbose telemetry output
        - Full AEE mode with GDE/OODA/ACE automation
        - Complete pipeline visualization

  WHY: Enables operators to see every aspect of system operation:
        - Startup, operational, testing, shutdown phases
        - User feedback and smart prompts
        - Task execution in verbose mode
        - All key telemetry to console

  STAMP Compliance:
    - SC-OBS-069: Dual logging (terminal + telemetry)
    - SC-AGT-017: Agent efficiency > 90%
    - SC-C3I-001: Data-centric architecture
    - SC-PRF-050: Response time < 50ms
  """

  use GenServer
  require Logger

  # ═══════════════════════════════════════════════════════════════════════════
  # ANSI CODES (Full-Screen Terminal Support)
  # ═══════════════════════════════════════════════════════════════════════════

  @reset "\e[0m"
  @bold "\e[1m"
  @dim "\e[2m"
  @red "\e[31m"
  @green "\e[32m"
  @yellow "\e[33m"
  @blue "\e[34m"
  @magenta "\e[35m"
  @cyan "\e[36m"
  @bright_yellow "\e[93m"
  @bright_blue "\e[94m"
  @bg_blue "\e[44m"
  @clear "\e[2J\e[H"
  @hide_cursor "\e[?25l"
  @show_cursor "\e[?25h"

  # Box drawing characters
  @box_tl "╔"
  @box_tr "╗"
  @box_bl "╚"
  @box_br "╝"
  @box_h "═"
  @box_v "║"
  @box_t_right "╠"
  @box_t_left "╣"

  # Icons
  @icon_success "✓"
  @icon_error "✗"
  @icon_running "●"
  @icon_waiting "○"

  # Agent roles
  @agent_roles [:supervisor, :dashboard, :cepaf_gde, :telemetry, :test_runner, :container_ops]

  # OODA phases
  @ooda_phases [:observe, :orient, :decide, :act]

  # System phases
  @phases [:startup, :containers, :compilation, :testing, :verification, :operational, :shutdown]

  # ═══════════════════════════════════════════════════════════════════════════
  # TYPES
  # ═══════════════════════════════════════════════════════════════════════════

  defmodule Agent do
    @moduledoc false
    defstruct [
      :id,
      :name,
      :role,
      status: :idle,
      current_task: nil,
      completed_tasks: 0,
      failed_tasks: 0,
      efficiency: 100.0,
      last_update: nil
    ]
  end

  defmodule OodaState do
    @moduledoc false
    defstruct current_phase: :observe,
              cycle_count: 0,
              cycle_time_ms: 0.0,
              target_ms: 1000.0,
              quality: 100.0,
              violations: 0,
              last_decision: nil
  end

  defmodule GDEState do
    @moduledoc false
    defstruct proposals_generated: 0,
              proposals_validated: 0,
              success_rate: 0.0,
              goal_progress: 0.0,
              current_goal: "Zero Defects",
              evolution_stage: 0
  end

  defmodule ACEState do
    @moduledoc false
    defstruct safety_checks: 0,
              violations_blocked: 0,
              envelope_status: "NOMINAL",
              guardian_active: true
  end

  defmodule LogEntry do
    @moduledoc false
    defstruct [
      :timestamp,
      :level,
      :source,
      :message
    ]
  end

  defmodule Metric do
    @moduledoc false
    defstruct [
      :name,
      :value,
      :unit,
      :trend
    ]
  end

  defmodule State do
    @moduledoc false
    defstruct title: "PRAJNA C3I MULTI-AGENT COCKPIT",
              version: "1.0.0",
              phase: :startup,
              phase_description: "Initializing...",
              started_at: nil,
              agents: %{},
              logs: [],
              metrics: %{},
              ooda: %OodaState{},
              gde: %GDEState{},
              ace: %ACEState{},
              errors: 0,
              warnings: 0,
              tests_passed: 0,
              tests_failed: 0,
              coverage: 0.0,
              goal_achieved: false,
              spinner_frame: 0,
              ooda_frame: 0,
              cols: 120,
              rows: 40,
              render_timer: nil,
              running: false
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # CLIENT API
  # ═══════════════════════════════════════════════════════════════════════════

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def initialize(title \\ "PRAJNA C3I MULTI-AGENT COCKPIT") do
    GenServer.call(__MODULE__, {:initialize, title})
  end

  def shutdown do
    GenServer.call(__MODULE__, :shutdown)
  end

  def register_agent(id, name, role) when role in @agent_roles do
    GenServer.cast(__MODULE__, {:register_agent, id, name, role})
  end

  def update_agent(id, status, task) do
    GenServer.cast(__MODULE__, {:update_agent, id, status, task})
  end

  # SC-SIL6-001: Accept both :warn and :warning for OTP 28 compatibility
  def log(level, source, message) when level in [:info, :warn, :warning, :error, :debug] do
    # Normalize deprecated :warn to :warning
    normalized_level = if level == :warn, do: :warning, else: level
    GenServer.cast(__MODULE__, {:log, normalized_level, source, message})
  end

  def metric(name, value, unit, trend \\ :stable) do
    GenServer.cast(__MODULE__, {:metric, name, value, unit, trend})
  end

  def update_ooda(phase, cycle_ms, quality) when phase in @ooda_phases do
    GenServer.cast(__MODULE__, {:update_ooda, phase, cycle_ms, quality})
  end

  def update_gde(proposals, validated, progress) do
    GenServer.cast(__MODULE__, {:update_gde, proposals, validated, progress})
  end

  def update_ace(checks, blocked, status) do
    GenServer.cast(__MODULE__, {:update_ace, checks, blocked, status})
  end

  def set_phase(phase, description) when phase in @phases do
    GenServer.cast(__MODULE__, {:set_phase, phase, description})
  end

  def set_goal_status(errors, warnings, passed, failed, coverage) do
    GenServer.cast(__MODULE__, {:set_goal_status, errors, warnings, passed, failed, coverage})
  end

  def demo do
    GenServer.call(__MODULE__, :demo)
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # SERVER CALLBACKS
  # ═══════════════════════════════════════════════════════════════════════════

  @impl true
  def init(_opts) do
    {:ok, %State{}}
  end

  @impl true
  def handle_call({:initialize, title}, _from, %State{} = state) do
    IO.write(@hide_cursor)
    IO.write(@clear)

    new_state = %{
      state
      | title: title,
        started_at: DateTime.utc_now(),
        running: true,
        phase: :startup,
        phase_description: "Initializing agents..."
    }

    # Start render timer (100ms refresh)
    {:ok, timer} = :timer.send_interval(100, :render)

    {:reply, :ok, %{new_state | render_timer: timer}}
  end

  @impl true
  def handle_call(:shutdown, _from, state) do
    if state.render_timer do
      :timer.cancel(state.render_timer)
    end

    IO.write(@show_cursor)
    IO.write("\n\n#{@green}C3I Console shutdown complete.#{@reset}\n")

    {:reply, :ok, %{state | running: false, render_timer: nil}}
  end

  @impl true
  def handle_call(:demo, _from, state) do
    spawn(fn -> run_demo() end)
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:register_agent, id, name, role}, state) do
    agent = %Agent{
      id: id,
      name: name,
      role: role,
      status: :idle,
      last_update: DateTime.utc_now()
    }

    {:noreply, %{state | agents: Map.put(state.agents, id, agent)}}
  end

  @impl true
  def handle_cast({:update_agent, id, status, task}, state) do
    case Map.get(state.agents, id) do
      nil ->
        {:noreply, state}

      agent ->
        completed =
          if status == :success, do: agent.completed_tasks + 1, else: agent.completed_tasks

        failed = if status == :error, do: agent.failed_tasks + 1, else: agent.failed_tasks
        total = completed + failed
        efficiency = if total > 0, do: completed / total * 100.0, else: 100.0

        updated = %{
          agent
          | status: status,
            current_task: task,
            completed_tasks: completed,
            failed_tasks: failed,
            efficiency: efficiency,
            last_update: DateTime.utc_now()
        }

        {:noreply, %{state | agents: Map.put(state.agents, id, updated)}}
    end
  end

  @impl true
  def handle_cast({:log, level, source, message}, state) do
    entry = %LogEntry{
      timestamp: DateTime.utc_now(),
      level: level,
      source: source,
      message: message
    }

    # Keep last 20 log entries
    logs = [entry | state.logs] |> Enum.take(20)
    {:noreply, %{state | logs: logs}}
  end

  @impl true
  def handle_cast({:metric, name, value, unit, trend}, state) do
    metric = %Metric{name: name, value: value, unit: unit, trend: trend}
    {:noreply, %{state | metrics: Map.put(state.metrics, name, metric)}}
  end

  @impl true
  def handle_cast({:update_ooda, phase, cycle_ms, quality}, state) do
    violations =
      if cycle_ms > state.ooda.target_ms,
        do: state.ooda.violations + 1,
        else: state.ooda.violations

    ooda = %{
      state.ooda
      | current_phase: phase,
        cycle_time_ms: cycle_ms,
        quality: quality,
        cycle_count: state.ooda.cycle_count + 1,
        violations: violations
    }

    {:noreply, %{state | ooda: ooda}}
  end

  @impl true
  def handle_cast({:update_gde, proposals, validated, progress}, state) do
    rate = if proposals > 0, do: validated / proposals * 100.0, else: 0.0

    gde = %{
      state.gde
      | proposals_generated: proposals,
        proposals_validated: validated,
        success_rate: rate,
        goal_progress: progress
    }

    {:noreply, %{state | gde: gde}}
  end

  @impl true
  def handle_cast({:update_ace, checks, blocked, status}, state) do
    ace = %{
      state.ace
      | safety_checks: checks,
        violations_blocked: blocked,
        envelope_status: status
    }

    {:noreply, %{state | ace: ace}}
  end

  @impl true
  def handle_cast({:set_phase, phase, description}, state) do
    {:noreply, %{state | phase: phase, phase_description: description}}
  end

  @impl true
  def handle_cast({:set_goal_status, errors, warnings, passed, failed, coverage}, state) do
    achieved = errors == 0 and warnings == 0 and failed == 0 and coverage >= 100.0

    {:noreply,
     %{
       state
       | errors: errors,
         warnings: warnings,
         tests_passed: passed,
         tests_failed: failed,
         coverage: coverage,
         goal_achieved: achieved
     }}
  end

  @impl true
  def handle_info(:render, state) do
    if state.running do
      render(state)

      new_state = %{
        state
        | spinner_frame: state.spinner_frame + 1,
          ooda_frame: state.ooda_frame + 1
      }

      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # RENDERING
  # ═══════════════════════════════════════════════════════════════════════════

  @spinners ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
  @ooda_anim ["◐", "◓", "◑", "◒"]

  defp render(state) do
    cols = get_terminal_cols()

    output = [
      # Move to top
      "\e[H",
      # Header
      render_header(state, cols),
      # Goal status bar
      render_goal_bar(state, cols),
      # Control loops (OODA/GDE/ACE)
      render_control_loops(state, cols),
      # Agents panel
      render_agents(state, cols),
      # Metrics panel
      render_metrics(state, cols),
      # Log panel
      render_logs(state, cols),
      # Footer
      render_footer(state, cols)
    ]

    IO.write(output)
  end

  defp render_header(state, cols) do
    spinner = Enum.at(@spinners, rem(state.spinner_frame, length(@spinners)))
    uptime = format_uptime(state.started_at)
    ts = DateTime.utc_now() |> Calendar.strftime("%H:%M:%S")
    phase_color = phase_color(state.phase)
    phase_str = to_string(state.phase)
    phase_name = String.upcase(phase_str)

    [
      @box_tl,
      String.duplicate(@box_h, cols - 2),
      @box_tr,
      "\n",
      @box_v,
      " ",
      @bold,
      @bg_blue,
      " PRAJNA C3I MULTI-AGENT COCKPIT ",
      @reset,
      " ",
      phase_color,
      spinner,
      " [",
      phase_name,
      "] ",
      state.phase_description,
      @reset,
      String.duplicate(" ", max(1, cols - 80)),
      @dim,
      uptime,
      " │ ",
      ts,
      @reset,
      " ",
      @box_v,
      "\n",
      @box_t_right,
      String.duplicate(@box_h, cols - 2),
      @box_t_left,
      "\n"
    ]
  end

  defp render_goal_bar(state, cols) do
    goal_icon =
      if state.goal_achieved,
        do: "#{@green}#{@icon_success}#{@reset}",
        else: "#{@yellow}#{@icon_running}#{@reset}"

    err_str =
      if state.errors == 0, do: "#{@green}0#{@reset}", else: "#{@red}#{state.errors}#{@reset}"

    wrn_str =
      if state.warnings == 0,
        do: "#{@green}0#{@reset}",
        else: "#{@yellow}#{state.warnings}#{@reset}"

    test_str = "#{@green}#{state.tests_passed}#{@reset}/#{@red}#{state.tests_failed}#{@reset}"

    cov_str =
      if state.coverage >= 100.0,
        do: "#{@green}100%#{@reset}",
        else: "#{@yellow}#{Float.round(state.coverage, 1)}%#{@reset}"

    line =
      "#{@box_v} #{goal_icon} GDE GOAL: #{@bold}Zero Errors#{@reset} │ Errors: #{err_str} │ Warnings: #{wrn_str} │ Tests: #{test_str} │ Coverage: #{cov_str}"

    [
      line,
      String.duplicate(" ", max(1, cols - visible_length(line) - 2)),
      @box_v,
      "\n",
      @box_t_right,
      String.duplicate(@box_h, cols - 2),
      @box_t_left,
      "\n"
    ]
  end

  defp render_control_loops(state, cols) do
    ooda_anim = Enum.at(@ooda_anim, rem(state.ooda_frame, length(@ooda_anim)))
    ooda_phase_str = to_string(state.ooda.current_phase)
    ooda_phase = String.upcase(ooda_phase_str)
    cycle_color = if state.ooda.cycle_time_ms < state.ooda.target_ms, do: @green, else: @red

    ooda_str =
      "#{@cyan}#{ooda_anim} OODA#{@reset}: #{@bold}#{ooda_phase}#{@reset} #{cycle_color}#{Float.round(state.ooda.cycle_time_ms, 0)}ms#{@reset} (<#{Float.round(state.ooda.target_ms, 0)}) Q:#{Float.round(state.ooda.quality, 0)}% V:#{state.ooda.violations}"

    gde_color = if state.gde.goal_progress >= 100.0, do: @green, else: @yellow

    gde_str =
      "#{@magenta}GDE#{@reset}: #{gde_color}#{Float.round(state.gde.goal_progress, 0)}%#{@reset} P:#{state.gde.proposals_generated}/#{state.gde.proposals_validated} (#{Float.round(state.gde.success_rate, 0)}%)"

    ace_color = if state.ace.envelope_status == "NOMINAL", do: @green, else: @red

    ace_str =
      "#{@blue}ACE#{@reset}: #{ace_color}#{state.ace.envelope_status}#{@reset} C:#{state.ace.safety_checks} B:#{state.ace.violations_blocked}"

    [
      @box_v,
      " ",
      ooda_str,
      " │ ",
      gde_str,
      " │ ",
      ace_str,
      String.duplicate(
        " ",
        max(1, cols - visible_length("#{@box_v} #{ooda_str} │ #{gde_str} │ #{ace_str}") - 2)
      ),
      @box_v,
      "\n",
      @box_t_right,
      String.duplicate(@box_h, cols - 2),
      @box_t_left,
      "\n"
    ]
  end

  defp render_agents(state, cols) do
    header = "#{@box_v} #{@bold}AGENTS#{@reset}"

    agents_list =
      state.agents
      |> Enum.map(fn {_id, agent} ->
        status_icon = agent_status_icon(agent.status)
        role_icon = role_icon(agent.role)
        task = agent.current_task || "idle"
        eff = Float.round(agent.efficiency, 0)

        "#{@box_v}   #{role_icon} #{agent.name} #{status_icon} [#{task}] E:#{eff}%"
      end)

    if Enum.empty?(agents_list) do
      [header, " (no agents registered)", String.duplicate(" ", max(1, cols - 40)), @box_v, "\n"]
    else
      [
        header,
        String.duplicate(" ", max(1, cols - visible_length(header) - 2)),
        @box_v,
        "\n",
        Enum.map(agents_list, fn line ->
          [line, String.duplicate(" ", max(1, cols - visible_length(line) - 2)), @box_v, "\n"]
        end),
        @box_t_right,
        String.duplicate(@box_h, cols - 2),
        @box_t_left,
        "\n"
      ]
    end
  end

  defp render_metrics(state, cols) do
    header = "#{@box_v} #{@bold}METRICS#{@reset}"

    metrics_list =
      state.metrics
      |> Enum.take(5)
      |> Enum.map(fn {_name, m} ->
        trend_icon = trend_icon(m.trend)
        "#{@box_v}   #{m.name}: #{m.value}#{m.unit} #{trend_icon}"
      end)

    if Enum.empty?(metrics_list) do
      [header, " (no metrics)", String.duplicate(" ", max(1, cols - 30)), @box_v, "\n"]
    else
      [
        header,
        String.duplicate(" ", max(1, cols - visible_length(header) - 2)),
        @box_v,
        "\n",
        Enum.map(metrics_list, fn line ->
          [line, String.duplicate(" ", max(1, cols - visible_length(line) - 2)), @box_v, "\n"]
        end),
        @box_t_right,
        String.duplicate(@box_h, cols - 2),
        @box_t_left,
        "\n"
      ]
    end
  end

  defp render_logs(state, cols) do
    header = "#{@box_v} #{@bold}LOGS#{@reset} (Last 5)"

    logs_list =
      state.logs
      |> Enum.take(5)
      |> Enum.map(fn entry ->
        ts = Calendar.strftime(entry.timestamp, "%H:%M:%S")
        level_str = log_level_str(entry.level)
        msg = String.slice(entry.message, 0, cols - 40)
        "#{@box_v}   #{ts} #{level_str} [#{entry.source}] #{msg}"
      end)

    if Enum.empty?(logs_list) do
      [header, " (no logs)", String.duplicate(" ", max(1, cols - 25)), @box_v, "\n"]
    else
      [
        header,
        String.duplicate(" ", max(1, cols - visible_length(header) - 2)),
        @box_v,
        "\n",
        Enum.map(logs_list, fn line ->
          truncated = String.slice(line, 0, cols - 3)

          [
            truncated,
            String.duplicate(" ", max(1, cols - visible_length(truncated) - 2)),
            @box_v,
            "\n"
          ]
        end)
      ]
    end
  end

  defp render_footer(state, cols) do
    status =
      cond do
        state.goal_achieved -> "#{@green}#{@bold}GOAL ACHIEVED#{@reset}"
        state.errors > 0 -> "#{@red}ERRORS#{@reset}"
        state.warnings > 0 -> "#{@yellow}WARNINGS#{@reset}"
        true -> "#{@green}RUNNING#{@reset}"
      end

    [
      @box_bl,
      String.duplicate(@box_h, cols - 2),
      @box_br,
      "\n",
      " ",
      @dim,
      "Ctrl+C to exit",
      @reset,
      " │ Status: ",
      status,
      " │ ",
      @dim,
      "Elixir PRAJNA C3I v",
      state.version,
      @reset,
      "\n"
    ]
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # HELPERS
  # ═══════════════════════════════════════════════════════════════════════════

  defp get_terminal_cols do
    case :io.columns() do
      {:ok, cols} -> cols
      _ -> 120
    end
  end

  defp format_uptime(nil), do: "00:00:00"

  defp format_uptime(started_at) do
    diff = DateTime.diff(DateTime.utc_now(), started_at, :second)
    hours = div(diff, 3600)
    minutes = div(rem(diff, 3600), 60)
    seconds = rem(diff, 60)
    formatted = :io_lib.format("~2..0B:~2..0B:~2..0B", [hours, minutes, seconds])
    to_string(formatted)
  end

  defp phase_color(:startup), do: @cyan
  defp phase_color(:containers), do: @blue
  defp phase_color(:compilation), do: @magenta
  defp phase_color(:testing), do: @yellow
  defp phase_color(:verification), do: @bright_blue
  defp phase_color(:operational), do: @green
  defp phase_color(:shutdown), do: @red
  defp phase_color(_), do: @reset

  defp agent_status_icon(:idle), do: "#{@dim}#{@icon_waiting}#{@reset}"
  defp agent_status_icon(:running), do: "#{@green}#{@icon_running}#{@reset}"
  defp agent_status_icon(:success), do: "#{@green}#{@icon_success}#{@reset}"
  defp agent_status_icon(:error), do: "#{@red}#{@icon_error}#{@reset}"
  defp agent_status_icon(_), do: "#{@dim}?#{@reset}"

  defp role_icon(:supervisor), do: "#{@bright_yellow}★#{@reset}"
  defp role_icon(:dashboard), do: "#{@cyan}◉#{@reset}"
  defp role_icon(:cepaf_gde), do: "#{@magenta}◆#{@reset}"
  defp role_icon(:telemetry), do: "#{@blue}◈#{@reset}"
  defp role_icon(:test_runner), do: "#{@green}◇#{@reset}"
  defp role_icon(:container_ops), do: "#{@yellow}◎#{@reset}"
  defp role_icon(_), do: "○"

  defp trend_icon(:rising), do: "#{@green}↑#{@reset}"
  defp trend_icon(:falling), do: "#{@red}↓#{@reset}"
  defp trend_icon(:stable), do: "#{@dim}→#{@reset}"
  defp trend_icon(_), do: ""

  defp log_level_str(:info), do: "#{@green}INFO#{@reset}"
  defp log_level_str(:warn), do: "#{@yellow}WARN#{@reset}"
  defp log_level_str(:error), do: "#{@red}ERR #{@reset}"
  defp log_level_str(:debug), do: "#{@dim}DBG #{@reset}"
  defp log_level_str(_), do: "    "

  # Calculate visible length (without ANSI codes)
  defp visible_length(str) when is_binary(str) do
    str
    |> String.replace(~r/\e\[[0-9;]*m/, "")
    |> String.length()
  end

  defp visible_length(list) when is_list(list) do
    list |> IO.iodata_to_binary() |> visible_length()
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # DEMO EXECUTION
  # ═══════════════════════════════════════════════════════════════════════════

  defp run_demo do
    initialize("PRAJNA C3I MULTI-AGENT COCKPIT")
    demo_register_agents()
    demo_phase_startup()
    demo_phase_containers()
    demo_phase_compilation()
    demo_phase_testing()
    demo_phase_verification()
    demo_phase_operational()
    demo_phase_shutdown()
  end

  defp demo_register_agents do
    register_agent(0, "SUPERVISOR", :supervisor)
    register_agent(1, "DASHBOARD", :dashboard)
    register_agent(2, "CEPAF/GDE", :cepaf_gde)
    register_agent(3, "TELEMETRY", :telemetry)
    register_agent(4, "TEST_RUN", :test_runner)
    register_agent(5, "CONTAINER", :container_ops)
    Process.sleep(500)
  end

  defp demo_phase_startup do
    set_phase(:startup, "Initializing system components...")
    log(:info, "System", "C3I Multi-Agent Dashboard starting")

    for i <- 0..5 do
      update_agent(i, :running, "Initializing")
      Process.sleep(200)
    end

    Process.sleep(1000)
  end

  defp demo_phase_containers do
    set_phase(:containers, "Deploying containers...")
    update_agent(5, :running, "Starting containers")

    for {name, metric_name} <- [
          {"indrajaal-db", "db_cpu"},
          {"indrajaal-app", "app_cpu"},
          {"indrajaal-obs", "obs_cpu"}
        ] do
      log(:info, "Container", "Starting #{name}")
      metric(metric_name, 0.0, "%", :stable)
      Process.sleep(500)
    end

    update_agent(5, :success, nil)
  end

  defp demo_phase_compilation do
    set_phase(:compilation, "Compiling Elixir application...")
    update_agent(2, :running, "Running mix compile")
    log(:info, "Compile", "Starting Patient Mode compilation")
    update_ace(1, 0, "NOMINAL")

    for i <- 1..10 do
      update_ooda(:observe, :rand.uniform(100) + 700, 95.0 + :rand.uniform(5))
      metric("compile_progress", i * 10, "%", :rising)
      log(:debug, "Compile", "Compiling module #{i}/10")
      Process.sleep(300)
    end

    update_agent(2, :success, nil)
    set_goal_status(0, 0, 0, 0, 0.0)
    log(:info, "Compile", "Compilation complete - 0 errors, 0 warnings")
    Process.sleep(500)
  end

  defp demo_phase_testing do
    set_phase(:testing, "Running test suite...")
    update_agent(4, :running, "Executing tests")
    log(:info, "Test", "Starting test suite execution")

    for i <- 1..20 do
      update_ooda(:orient, :rand.uniform(50) + 750, 96.0 + :rand.uniform(4))
      passed = i * 5
      set_goal_status(0, 0, passed, 0, passed * 1.0)
      update_gde(i, i - :rand.uniform(2), passed * 1.0)
      log(:debug, "Test", "Test batch #{i}: #{passed} passed")
      Process.sleep(200)
    end

    update_agent(4, :success, nil)
    set_goal_status(0, 0, 100, 0, 100.0)
    log(:info, "Test", "All 100 tests passed - 100% coverage")
    Process.sleep(500)
  end

  defp demo_phase_verification do
    set_phase(:verification, "Running formal verification...")
    update_agent(1, :running, "FPPS Verification")
    log(:info, "Verify", "Starting 5-point consensus verification")

    for method <- ["Pattern", "AST", "Statistical", "Binary", "LineByLine"] do
      update_ooda(:decide, :rand.uniform(100) + 800, 97.0 + :rand.uniform(3))
      update_ace(state_ace().safety_checks + 1, 0, "VERIFIED")
      log(:info, "FPPS", "#{method} verification: PASS")
      Process.sleep(400)
    end

    update_agent(1, :success, nil)
    update_gde(25, 25, 100.0)
    log(:info, "Verify", "FPPS consensus achieved - all 5 methods agree")
    Process.sleep(500)
  end

  defp demo_phase_operational do
    set_phase(:operational, "System fully operational")
    for i <- 0..5, do: update_agent(i, :success, nil)

    log(:info, "System", "GDE GOAL ACHIEVED: Zero Errors, Zero Warnings, 100% Coverage")
    update_ace(10, 0, "GOAL_ACHIEVED")

    for _ <- 1..30 do
      update_ooda(:act, :rand.uniform(200) + 600, 98.0 + :rand.uniform(2))
      metric("db_cpu", :rand.uniform(30) + 10, "%", :stable)
      metric("app_cpu", :rand.uniform(40) + 20, "%", :stable)
      metric("latency", :rand.uniform(20) + 5, "ms", :stable)
      Process.sleep(500)
    end
  end

  defp demo_phase_shutdown do
    set_phase(:shutdown, "Graceful shutdown initiated")
    log(:info, "System", "Initiating graceful shutdown")
    Process.sleep(2000)
    shutdown()
  end

  defp state_ace do
    case :sys.get_state(__MODULE__) do
      %State{ace: ace} -> ace
      _ -> %ACEState{}
    end
  end
end
