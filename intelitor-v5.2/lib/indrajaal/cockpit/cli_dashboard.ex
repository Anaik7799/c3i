defmodule Indrajaal.Cockpit.CLIDashboard do
  @moduledoc """
  Reusable Full-Screen CLI Dashboard Component for System Operations.

  WHAT: Terminal-based dashboard with dynamic updates, agent status,
        telemetry visualization, and interactive user feedback.

  WHY: Provides a unified, reusable UX component for CLI-based system
       operations including startup, operational monitoring, testing,
       and shutdown processes.

  CONSTRAINTS: Must work in standard terminals (80x24 minimum),
               support ANSI colors, and be fully modular/reusable.

  ## STAMP Compliance
  - SC-OBS-069: Dual logging (terminal + telemetry)
  - SC-PRF-050: Response time < 50ms for updates
  - SC-AGT-017: Agent efficiency > 90%

  ## Features
  - Multi-panel layout with automatic sizing
  - Real-time telemetry streaming
  - Agent status visualization
  - Progress tracking with ETA
  - Interactive prompts with smart defaults
  - Full-screen optimization
  """

  use GenServer
  require Logger

  # ═══════════════════════════════════════════════════════════════════════════
  # TYPES & CONSTANTS
  # ═══════════════════════════════════════════════════════════════════════════

  @type panel_id :: atom()
  @type agent_status :: :idle | :running | :success | :error | :waiting

  @refresh_interval 250
  @ansi %{
    reset: "\e[0m",
    bold: "\e[1m",
    dim: "\e[2m",
    green: "\e[32m",
    yellow: "\e[33m",
    red: "\e[31m",
    blue: "\e[34m",
    cyan: "\e[36m",
    magenta: "\e[35m",
    white: "\e[37m",
    bg_blue: "\e[44m",
    bg_green: "\e[42m",
    bg_red: "\e[41m",
    clear: "\e[2J\e[H",
    hide_cursor: "\e[?25l",
    show_cursor: "\e[?25h"
  }

  @box %{
    tl: "╔",
    tr: "╗",
    bl: "╚",
    br: "╝",
    h: "═",
    v: "║",
    t_down: "╦",
    t_up: "╩",
    t_right: "╠",
    t_left: "╣",
    cross: "╬"
  }

  @icons %{
    success: "✓",
    error: "✗",
    running: "●",
    waiting: "○",
    idle: "◌",
    arrow_right: "→",
    arrow_up: "↑",
    arrow_down: "↓",
    bar_full: "█",
    bar_empty: "░",
    spinner: ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
  }

  # ═══════════════════════════════════════════════════════════════════════════
  # CLIENT API
  # ═══════════════════════════════════════════════════════════════════════════

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :temporary
    }
  end

  @doc "Initialize dashboard with title and configuration"
  def init_dashboard(title, config \\ %{}) do
    GenServer.call(__MODULE__, {:init_dashboard, title, config})
  end

  @doc "Register an agent with initial status"
  def register_agent(agent_id, name, role) do
    GenServer.cast(__MODULE__, {:register_agent, agent_id, name, role})
  end

  @doc "Update agent status and current task"
  def update_agent(agent_id, status, task \\ nil) do
    GenServer.cast(__MODULE__, {:update_agent, agent_id, status, task})
  end

  @doc "Add log entry"
  def log(level, message, source \\ nil) do
    GenServer.cast(__MODULE__, {:log, level, message, source})
  end

  @doc "Update progress bar"
  def progress(id, label, current, total) do
    GenServer.cast(__MODULE__, {:progress, id, label, current, total})
  end

  @doc "Update metric"
  def metric(id, label, value, unit \\ "") do
    GenServer.cast(__MODULE__, {:metric, id, label, value, unit})
  end

  @doc "Set current phase"
  def phase(name, description \\ nil) do
    GenServer.cast(__MODULE__, {:phase, name, description})
  end

  @doc "Show prompt and get response"
  def prompt(question, options, default \\ nil) do
    GenServer.call(__MODULE__, {:prompt, question, options, default}, :infinity)
  end

  @doc "Stop dashboard"
  def stop do
    GenServer.stop(__MODULE__, :normal)
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # GENSERVER CALLBACKS
  # ═══════════════════════════════════════════════════════════════════════════

  @impl GenServer
  def init(opts) do
    {cols, rows} = get_terminal_size()

    state = %{
      cols: cols,
      rows: rows,
      title: Keyword.get(opts, :title, "INTELITOR COCKPIT"),
      started_at: System.monotonic_time(:millisecond),
      phase: "INITIALIZING",
      phase_desc: "Starting up...",
      agents: %{},
      logs: [],
      max_logs: 20,
      progress: %{},
      metrics: %{},
      spinner_frame: 0,
      prompt: nil,
      auto_refresh: true
    }

    IO.write(@ansi.hide_cursor)
    schedule_refresh()

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:init_dashboard, title, config}, _from, state) do
    new_state = %{
      state
      | title: title,
        phase: Map.get(config, :phase, "READY"),
        phase_desc: Map.get(config, :description, "Initialized")
    }

    render(new_state)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:prompt, question, options, default}, from, state) do
    new_state = %{
      state
      | prompt: %{question: question, options: options, default: default, from: from}
    }

    render(new_state)
    # Auto-respond with default after 3 seconds for demo
    Process.send_after(self(), {:auto_respond, default || hd(options)}, 3000)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast({:register_agent, id, name, role}, state) do
    agent = %{name: name, role: role, status: :idle, task: nil, updated: now_ms()}
    new_state = %{state | agents: Map.put(state.agents, id, agent)}
    render(new_state)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast({:update_agent, id, status, task}, state) do
    case Map.get(state.agents, id) do
      nil ->
        {:noreply, state}

      agent ->
        updated = %{agent | status: status, task: task, updated: now_ms()}
        new_state = %{state | agents: Map.put(state.agents, id, updated)}
        render(new_state)
        {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_cast({:log, level, message, source}, state) do
    entry = %{level: level, message: message, source: source, time: now_ms()}
    logs = [entry | state.logs] |> Enum.take(state.max_logs)
    new_state = %{state | logs: logs}
    render(new_state)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast({:progress, id, label, current, total}, state) do
    pct = if total > 0, do: round(current / total * 100), else: 0
    prog = %{label: label, current: current, total: total, pct: pct}
    new_state = %{state | progress: Map.put(state.progress, id, prog)}
    render(new_state)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast({:metric, id, label, value, unit}, state) do
    m = %{label: label, value: value, unit: unit}
    new_state = %{state | metrics: Map.put(state.metrics, id, m)}
    render(new_state)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast({:phase, name, desc}, state) do
    new_state = %{state | phase: name, phase_desc: desc || name}
    render(new_state)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(:refresh, state) do
    {cols, rows} = get_terminal_size()
    new_state = %{state | cols: cols, rows: rows, spinner_frame: rem(state.spinner_frame + 1, 10)}
    render(new_state)
    if state.auto_refresh, do: schedule_refresh()
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info({:auto_respond, response}, state) do
    if state.prompt do
      GenServer.reply(state.prompt.from, response)
      new_state = %{state | prompt: nil}
      render(new_state)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl GenServer
  def terminate(_reason, _state) do
    IO.write(@ansi.show_cursor)
    IO.write(@ansi.clear)
    IO.puts("#{@ansi.green}Dashboard terminated.#{@ansi.reset}")
    :ok
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # RENDERING
  # ═══════════════════════════════════════════════════════════════════════════

  defp render(state) do
    screen = build_screen(state)
    IO.write(screen)
  end

  defp build_screen(state) do
    cols = state.cols
    rows = state.rows

    header = build_header(state, cols)
    agents_panel = build_agents_panel(state, div(cols, 2) - 1, div(rows - 6, 2))
    progress_panel = build_progress_panel(state, div(cols, 2) - 1, div(rows - 6, 2))
    metrics_panel = build_metrics_panel(state, div(cols, 2), 8)
    logs_panel = build_logs_panel(state, div(cols, 2), rows - 14)
    footer = build_footer(state, cols)

    [
      @ansi.clear,
      header,
      "\n",
      merge_horizontal(agents_panel, metrics_panel),
      merge_horizontal(progress_panel, logs_panel),
      footer
    ]
    |> IO.iodata_to_binary()
  end

  defp build_header(state, cols) do
    spinner = Enum.at(@icons.spinner, state.spinner_frame)
    uptime = format_uptime(state.started_at)
    ts = Calendar.strftime(DateTime.utc_now(), "%H:%M:%S")

    title = " #{state.title} "
    phase = "[#{state.phase}]"

    line1 = "#{@box.tl}#{String.duplicate(@box.h, cols - 2)}#{@box.tr}"

    content =
      [
        @ansi.bold,
        @ansi.bg_blue,
        @ansi.white,
        title,
        @ansi.reset,
        " ",
        @ansi.cyan,
        spinner,
        " ",
        phase,
        @ansi.reset,
        " ",
        @ansi.dim,
        state.phase_desc,
        @ansi.reset
      ]
      |> IO.iodata_to_binary()

    right = "#{@ansi.dim}#{uptime} │ #{ts}#{@ansi.reset}"
    padding = cols - 4 - visible_length(content) - visible_length(right)
    line2 = "#{@box.v} #{content}#{String.duplicate(" ", max(0, padding))}#{right} #{@box.v}"

    line3 = "#{@box.t_right}#{String.duplicate(@box.h, cols - 2)}#{@box.t_left}"

    [line1, "\n", line2, "\n", line3]
  end

  defp build_agents_panel(state, width, height) do
    title = " AGENTS (#{map_size(state.agents)}) "
    header = panel_header(title, width)

    lines =
      state.agents
      |> Enum.take(height - 2)
      |> Enum.map(fn {_id, a} ->
        icon = status_icon(a.status)
        color = status_color(a.status)
        name = String.pad_trailing(a.name, 12)
        role = String.pad_trailing("[#{a.role}]", 14)
        task = String.slice(a.task || "", 0, width - 35)

        content =
          "#{color}#{icon}#{@ansi.reset} #{@ansi.bold}#{name}#{@ansi.reset} #{@ansi.dim}#{role}#{@ansi.reset} #{task}"

        panel_line(content, width)
      end)

    remaining = height - 2 - length(lines)
    empty = for _ <- 1..max(0, remaining), do: panel_line("", width)

    [header | lines ++ empty]
  end

  defp build_progress_panel(state, width, height) do
    title = " PROGRESS "
    header = panel_header(title, width)

    lines =
      state.progress
      |> Enum.take(height - 2)
      |> Enum.map(fn {_id, p} ->
        bar_w = width - 25
        filled = div(p.pct * bar_w, 100)
        empty = bar_w - filled

        bar =
          "#{@ansi.green}#{String.duplicate(@icons.bar_full, filled)}#{@ansi.dim}#{String.duplicate(@icons.bar_empty, empty)}#{@ansi.reset}"

        label = String.pad_trailing(p.label, 10)
        pct = String.pad_leading("#{p.pct}%", 4)

        panel_line(" #{label} #{bar} #{pct}", width)
      end)

    remaining = height - 2 - length(lines)
    empty = for _ <- 1..max(0, remaining), do: panel_line("", width)

    [header | lines ++ empty]
  end

  defp build_metrics_panel(state, width, height) do
    title = " TELEMETRY "
    header = panel_header(title, width)

    lines =
      state.metrics
      |> Enum.take(height - 2)
      |> Enum.map(fn {_id, m} ->
        label = String.pad_trailing(m.label, 18)
        value = format_value(m.value)
        unit = m.unit

        panel_line(
          " #{@ansi.cyan}#{label}#{@ansi.reset} #{@ansi.bold}#{value}#{@ansi.reset} #{@ansi.dim}#{unit}#{@ansi.reset}",
          width
        )
      end)

    remaining = height - 2 - length(lines)
    empty = for _ <- 1..max(0, remaining), do: panel_line("", width)

    [header | lines ++ empty]
  end

  defp build_logs_panel(state, width, height) do
    title = " ACTIVITY LOG "
    header = panel_header(title, width)

    lines =
      state.logs
      |> Enum.take(height - 2)
      |> Enum.map(fn l ->
        time = format_time(l.time, state.started_at)
        level = level_badge(l.level)
        source = if l.source, do: "[#{l.source}] ", else: ""
        msg = String.slice(l.message, 0, width - 25)

        panel_line(" #{@ansi.dim}#{time}#{@ansi.reset} #{level} #{source}#{msg}", width)
      end)

    remaining = height - 2 - length(lines)
    empty = for _ <- 1..max(0, remaining), do: panel_line("", width)

    [header | lines ++ empty]
  end

  defp build_footer(state, cols) do
    content =
      if state.prompt do
        p = state.prompt
        opts = Enum.join(p.options, "/")
        "#{@ansi.yellow}? #{p.question} [#{opts}] (default: #{p.default}): _#{@ansi.reset}"
      else
        "#{@ansi.dim}Press Ctrl+C to exit │ Auto-refreshing every #{@refresh_interval}ms#{@ansi.reset}"
      end

    line1 = "#{@box.bl}#{String.duplicate(@box.h, cols - 2)}#{@box.br}"
    ["\n", line1, "\n ", content, "\n"]
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # HELPERS
  # ═══════════════════════════════════════════════════════════════════════════

  defp schedule_refresh, do: Process.send_after(self(), :refresh, @refresh_interval)

  defp now_ms, do: System.monotonic_time(:millisecond)

  defp get_terminal_size do
    case System.cmd("tput", ["cols"], stderr_to_stdout: true) do
      {cols_str, 0} ->
        case System.cmd("tput", ["lines"], stderr_to_stdout: true) do
          {rows_str, 0} ->
            {cols_str |> String.trim() |> String.to_integer() |> max(80),
             rows_str |> String.trim() |> String.to_integer() |> max(24)}

          _ ->
            {120, 40}
        end

      _ ->
        {120, 40}
    end
  rescue
    _ -> {120, 40}
  end

  defp format_uptime(started_at) do
    diff = div(System.monotonic_time(:millisecond) - started_at, 1000)
    h = div(diff, 3600)
    m = div(rem(diff, 3600), 60)
    s = rem(diff, 60)
    "#{pad2(h)}:#{pad2(m)}:#{pad2(s)}"
  end

  defp format_time(ms, started_at) do
    diff = div(ms - started_at, 1000)
    m = div(diff, 60)
    s = rem(diff, 60)
    "+#{pad2(m)}:#{pad2(s)}"
  end

  defp pad2(n), do: String.pad_leading("#{n}", 2, "0")

  defp format_value(v) when is_float(v), do: :erlang.float_to_binary(v, decimals: 2)
  defp format_value(v) when is_integer(v), do: Integer.to_string(v)
  defp format_value(v), do: to_string(v)

  defp status_icon(:success), do: @icons.success
  defp status_icon(:error), do: @icons.error
  defp status_icon(:running), do: @icons.running
  defp status_icon(:waiting), do: @icons.waiting
  defp status_icon(_), do: @icons.idle

  defp status_color(:success), do: @ansi.green
  defp status_color(:error), do: @ansi.red
  defp status_color(:running), do: @ansi.blue
  defp status_color(:waiting), do: @ansi.yellow
  defp status_color(_), do: @ansi.dim

  defp level_badge(:error), do: "#{@ansi.bg_red}#{@ansi.white}ERR#{@ansi.reset}"
  # SC-SIL6-001: Handle both :warn (deprecated) and :warning (OTP 28)
  defp level_badge(:warn), do: "#{@ansi.yellow}WRN#{@ansi.reset}"
  defp level_badge(:warning), do: "#{@ansi.yellow}WRN#{@ansi.reset}"
  defp level_badge(:info), do: "#{@ansi.blue}INF#{@ansi.reset}"
  defp level_badge(:success), do: "#{@ansi.green}OK #{@ansi.reset}"
  defp level_badge(_), do: "#{@ansi.dim}---#{@ansi.reset}"

  defp panel_header(title, width) do
    padding = width - String.length(title) - 2

    "#{@box.t_right}#{@ansi.bold}#{title}#{@ansi.reset}#{String.duplicate(@box.h, max(0, padding))}#{@box.t_left}\n"
  end

  defp panel_line(content, width) do
    visible_len = visible_length(content)
    padding = width - visible_len - 2
    "#{@box.v}#{content}#{String.duplicate(" ", max(0, padding))}#{@box.v}\n"
  end

  defp visible_length(str) do
    str
    |> then(&Regex.replace(~r/\e\[[0-9;]*m/, &1, ""))
    |> String.length()
  end

  defp merge_horizontal(left, right) do
    left_lines = left |> IO.iodata_to_binary() |> String.split("\n", trim: true)
    right_lines = right |> IO.iodata_to_binary() |> String.split("\n", trim: true)

    max_len = max(length(left_lines), length(right_lines))

    Enum.map(0..(max_len - 1), fn i ->
      l = Enum.at(left_lines, i, "")
      r = Enum.at(right_lines, i, "")
      l <> r <> "\n"
    end)
  end
end
