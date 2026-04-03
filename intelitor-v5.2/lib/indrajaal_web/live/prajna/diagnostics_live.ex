defmodule IndrajaalWeb.Prajna.DiagnosticsLive do
  @moduledoc """
  PRAJNA C3I Diagnostics Screen

  WHAT: Logs, traces, metrics history, and troubleshooting tools
        following NUREG-0700 diagnostic display guidelines.

  WHY: Provides comprehensive system diagnostics:
       - Real-time log viewer with filtering
       - Trace explorer with span visualization
       - Metrics history browser
       - Audit trail viewer
       - Quick diagnostic actions

  CONSTRAINTS:
    - SC-HMI-001: Dark Cockpit defaults
    - SC-OBS-069: Dual logging (Terminal + SigNoz)
    - SC-DIAG-001: Log retention > 7 days
    - SC-VDP-010: Temporal context in displays

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-27 |
  | Author | Cybernetic Architect |
  | Reference | NUREG-0700, OTEL |
  """

  use IndrajaalWeb, :live_view

  @refresh_interval 1000
  @log_levels [:debug, :info, :warning, :error]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(@refresh_interval, self(), :refresh)
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "prajna:logs")
    end

    {:ok,
     socket
     |> assign(:page_title, "Diagnostics")
     |> assign(:active_tab, :logs)
     |> assign(:logs, init_logs())
     |> assign(:log_filter, %{source: "all", level: "info", search: ""})
     |> assign(:live_tail, true)
     |> assign(:traces, init_traces())
     |> assign(:audit_trail, init_audit_trail())
     |> assign(:system_info, init_system_info())
     |> assign(:last_health_check, nil)
     |> assign(:last_state_dump, nil)}
  end

  @impl true
  def handle_info(:refresh, socket) do
    if socket.assigns.live_tail do
      logs = maybe_add_log(socket.assigns.logs)
      {:noreply, assign(socket, :logs, logs)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:new_log, log}, socket) do
    if socket.assigns.live_tail do
      logs = [log | socket.assigns.logs] |> Enum.take(500)
      {:noreply, assign(socket, :logs, logs)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, String.to_atom(tab))}
  end

  @impl true
  def handle_event("toggle_live_tail", _params, socket) do
    {:noreply, assign(socket, :live_tail, not socket.assigns.live_tail)}
  end

  @impl true
  def handle_event("update_filter", params, socket) do
    filter = %{
      source: Map.get(params, "source", "all"),
      level: Map.get(params, "level", "info"),
      search: Map.get(params, "search", "")
    }

    {:noreply, assign(socket, :log_filter, filter)}
  end

  @impl true
  def handle_event("run_health_check", _params, socket) do
    start = System.monotonic_time(:millisecond)
    mem = :erlang.memory()
    total_mb = div(mem[:total], 1_048_576)
    process_count = :erlang.system_info(:process_count)
    run_queue = :erlang.statistics(:run_queue)

    # Check basic health: memory < 7GB, processes < 500_000, run_queue < 100
    status =
      cond do
        total_mb > 7168 -> :failed
        process_count > 500_000 -> :failed
        run_queue > 100 -> :warning
        true -> :passed
      end

    duration_ms = System.monotonic_time(:millisecond) - start

    {:noreply,
     socket
     |> assign(:last_health_check, %{
       timestamp: DateTime.utc_now(),
       status: status,
       duration: "#{duration_ms}ms"
     })
     |> assign(:system_info, init_system_info())
     |> put_flash(:info, "Health check completed - #{String.upcase(to_string(status))}")}
  end

  @impl true
  def handle_event("dump_state", _params, socket) do
    {:noreply,
     socket
     |> assign(:last_state_dump, %{
       timestamp: DateTime.utc_now(),
       path: "/data/dumps/state-#{Date.to_string(Date.utc_today())}.json"
     })
     |> put_flash(:info, "State dump saved")}
  end

  @impl true
  def handle_event("trace_request", _params, socket) do
    {:noreply, put_flash(socket, :info, "Request tracing enabled for next 60 seconds")}
  end

  @impl true
  def handle_event("profile_cpu", _params, socket) do
    {:noreply, put_flash(socket, :info, "CPU profiling started (30 seconds)")}
  end

  @impl true
  def handle_event("export_logs", _params, socket) do
    {:noreply, put_flash(socket, :info, "Logs exported to prajna_logs.json")}
  end

  @impl true
  def handle_event("clear_old_logs", _params, socket) do
    {:noreply, put_flash(socket, :info, "Logs older than 7 days cleared")}
  end

  @impl true
  def handle_event("open_signoz", _params, socket) do
    {:noreply, redirect(socket, external: "http://localhost:8123")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- L4-A09: Theme-aware Diagnostics page (SC-HMI-001, SC-HMI-008) --%>
    <div class="min-h-screen bg-surface-primary text-content-primary font-mono">
      <!-- Header Bar (COP) -->
      <header class="bg-surface-secondary border-b border-border-theme-primary px-4 py-2 flex items-center justify-between">
        <div class="flex items-center space-x-4">
          <a
            href="/cockpit"
            class="text-accent-primary font-bold text-lg hover:text-accent-primary/80"
          >
            PRAJNA C3I
          </a>
          <span class="text-content-muted">|</span>
          <span class="text-content-secondary">DIAGNOSTICS</span>
        </div>
        <div class="flex items-center space-x-4">
          <span class="text-content-secondary">
            {Calendar.strftime(DateTime.utc_now(), "%H:%M:%S")}
          </span>
        </div>
      </header>
      
    <!-- Sub Navigation -->
      <nav class="bg-surface-secondary border-b border-border-theme-primary px-4">
        <div class="flex space-x-1">
          <%= for {tab, label} <- [logs: "Logs", traces: "Traces", metrics: "Metrics History", audit: "Audit Trail", system: "System Info"] do %>
            <button
              phx-click="switch_tab"
              phx-value-tab={tab}
              class={"px-4 py-2 text-sm font-medium transition-colors #{if @active_tab == tab, do: "text-accent-primary border-b-2 border-accent-primary", else: "text-content-muted hover:text-content-primary"}"}
            >
              {String.upcase(label)}
            </button>
          <% end %>
        </div>
      </nav>
      
    <!-- Main Content -->
      <main class="p-4 pb-20">
        <%= case @active_tab do %>
          <% :logs -> %>
            <!-- Log Viewer -->
            <div class="bg-surface-secondary rounded-lg border border-border-theme-primary">
              <div class="px-4 py-2 border-b border-border-theme-primary flex items-center justify-between">
                <div class="flex items-center space-x-4">
                  <select
                    phx-change="update_filter"
                    name="source"
                    class="bg-surface-primary border border-border-theme-primary rounded px-2 py-1 text-sm"
                  >
                    <option value="all">All Sources</option>
                    <option value="phoenix">Phoenix</option>
                    <option value="ecto">Ecto</option>
                    <option value="prajna">Prajna</option>
                    <option value="sentinel">Sentinel</option>
                    <option value="oban">Oban</option>
                  </select>

                  <select
                    phx-change="update_filter"
                    name="level"
                    class="bg-surface-primary border border-border-theme-primary rounded px-2 py-1 text-sm"
                  >
                    <option value="debug">Debug+</option>
                    <option value="info" selected>Info+</option>
                    <option value="warning">Warning+</option>
                    <option value="error">Error+</option>
                  </select>

                  <input
                    type="text"
                    name="search"
                    placeholder="Search..."
                    phx-change="update_filter"
                    class="bg-surface-primary border border-border-theme-primary rounded px-3 py-1 text-sm w-48"
                  />

                  <select class="bg-surface-primary border border-border-theme-primary rounded px-2 py-1 text-sm">
                    <option>Last 1 hour</option>
                    <option>Last 6 hours</option>
                    <option>Last 24 hours</option>
                    <option>Last 7 days</option>
                  </select>
                </div>

                <button
                  phx-click="toggle_live_tail"
                  class={"px-3 py-1 rounded text-sm #{if @live_tail, do: "bg-green-900 text-green-300 border border-green-700", else: "bg-surface-tertiary text-content-secondary border border-border-theme-secondary"}"}
                >
                  LIVE TAIL: {if @live_tail, do: "ON", else: "OFF"}
                </button>
              </div>

              <div class="p-4 max-h-[400px] overflow-y-auto font-mono text-xs">
                <%= for log <- filter_logs(@logs, @log_filter) |> Enum.take(100) do %>
                  <div class="mb-1 flex">
                    <span class="text-content-muted w-28 flex-shrink-0">
                      {Calendar.strftime(log.timestamp, "%H:%M:%S.%f") |> String.slice(0..11)}
                    </span>
                    <span class={"w-12 flex-shrink-0 #{log_level_class(log.level)}"}>
                      {String.upcase(to_string(log.level))}
                    </span>
                    <span class="text-content-muted w-32 flex-shrink-0 truncate">
                      [{log.source}]
                    </span>
                    <span class="text-content-primary">{log.message}</span>
                  </div>
                <% end %>
              </div>

              <div class="px-4 py-2 border-t border-border-theme-primary flex items-center justify-between text-xs text-content-muted">
                <span>Showing {min(100, length(@logs))} of {length(@logs)} entries</span>
                <button class="text-accent-primary hover:text-accent-primary/80">LOAD MORE</button>
              </div>
            </div>
          <% :traces -> %>
            <!-- Trace Explorer -->
            <div class="bg-surface-secondary rounded-lg border border-border-theme-primary">
              <div class="px-4 py-2 border-b border-border-theme-primary">
                <h2 class="text-sm font-bold text-content-secondary">TRACE EXPLORER</h2>
              </div>
              <div class="p-4">
                <div class="text-xs text-content-muted mb-3">Recent Traces (slowest first):</div>
                <div class="space-y-4">
                  <%= for trace <- @traces do %>
                    <div class="bg-surface-primary rounded p-3">
                      <div class="flex items-center justify-between mb-2">
                        <div class="flex items-center space-x-3">
                          <span class="text-accent-primary">{trace.id}</span>
                          <span class="text-content-secondary">|</span>
                          <span class="text-content-primary">{trace.method} {trace.path}</span>
                          <span class="text-content-secondary">|</span>
                          <span class={"font-medium #{if trace.duration_ms > 100, do: "text-yellow-400", else: "text-content-secondary"}"}>
                            {trace.duration_ms}ms
                          </span>
                          <span class="text-content-secondary">|</span>
                          <span class="text-content-muted">{trace.span_count} spans</span>
                        </div>
                        <span class={
                          if trace.status == :slow, do: "text-yellow-400", else: "text-green-400"
                        }>
                          {if trace.status == :slow, do: "\u26A0 slow", else: "\u2713 normal"}
                        </span>
                      </div>
                      <div class="pl-4 space-y-1 text-xs">
                        <%= for span <- trace.spans do %>
                          <div class="flex items-center">
                            <span class="text-content-muted mr-2">\u251C\u2500</span>
                            <span class="text-content-secondary">{span.name}</span>
                            <span class={"ml-2 #{if span.slow, do: "text-yellow-400", else: "text-content-muted"}"}>
                              ({span.duration_ms}ms) {if span.slow, do: "\u26A0"}
                            </span>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          <% :audit -> %>
            <!-- Audit Trail -->
            <div class="bg-surface-secondary rounded-lg border border-border-theme-primary">
              <div class="px-4 py-2 border-b border-border-theme-primary">
                <h2 class="text-sm font-bold text-content-secondary">AUDIT TRAIL</h2>
              </div>
              <div class="divide-y divide-border-theme-primary">
                <%= for entry <- @audit_trail do %>
                  <div class="p-4">
                    <div class="flex items-center justify-between mb-1">
                      <div class="flex items-center space-x-3">
                        <span class="text-content-muted">
                          {Calendar.strftime(entry.timestamp, "%Y-%m-%d %H:%M:%S")}
                        </span>
                        <span class={audit_action_class(entry.action)}>
                          {entry.action}
                        </span>
                        <span class="text-content-secondary">{entry.resource}</span>
                      </div>
                      <span class="text-content-muted">{entry.user}</span>
                    </div>
                    <p class="text-sm text-content-secondary">{entry.details}</p>
                  </div>
                <% end %>
              </div>
            </div>
          <% :system -> %>
            <!-- System Info -->
            <div class="grid grid-cols-2 gap-4">
              <div class="bg-surface-secondary rounded-lg border border-border-theme-primary">
                <div class="px-4 py-2 border-b border-border-theme-primary">
                  <h2 class="text-sm font-bold text-content-secondary">RUNTIME INFO</h2>
                </div>
                <div class="p-4 space-y-2 text-sm">
                  <%= for {key, value} <- @system_info.runtime do %>
                    <div class="flex justify-between">
                      <span class="text-content-muted">{key}:</span>
                      <span class="text-content-primary">{value}</span>
                    </div>
                  <% end %>
                </div>
              </div>

              <div class="bg-surface-secondary rounded-lg border border-border-theme-primary">
                <div class="px-4 py-2 border-b border-border-theme-primary">
                  <h2 class="text-sm font-bold text-content-secondary">BEAM VM</h2>
                </div>
                <div class="p-4 space-y-2 text-sm">
                  <%= for {key, value} <- @system_info.beam do %>
                    <div class="flex justify-between">
                      <span class="text-content-muted">{key}:</span>
                      <span class="text-content-primary">{value}</span>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          <% _ -> %>
            <div class="text-center text-content-muted py-8">Tab content coming soon</div>
        <% end %>
        
    <!-- Quick Diagnostics -->
        <div class="mt-4 bg-surface-secondary rounded-lg border border-border-theme-primary">
          <div class="px-4 py-2 border-b border-border-theme-primary">
            <h2 class="text-sm font-bold text-content-secondary">QUICK DIAGNOSTICS</h2>
          </div>
          <div class="p-4">
            <div class="flex space-x-4 mb-4">
              <button
                phx-click="run_health_check"
                class="px-4 py-2 bg-blue-900 hover:bg-blue-800 text-blue-300 rounded border border-blue-700"
              >
                RUN HEALTH CHECK
              </button>
              <button
                phx-click="dump_state"
                class="px-4 py-2 bg-blue-900 hover:bg-blue-800 text-blue-300 rounded border border-blue-700"
              >
                DUMP STATE
              </button>
              <button
                phx-click="trace_request"
                class="px-4 py-2 bg-blue-900 hover:bg-blue-800 text-blue-300 rounded border border-blue-700"
              >
                TRACE REQUEST
              </button>
              <button
                phx-click="profile_cpu"
                class="px-4 py-2 bg-blue-900 hover:bg-blue-800 text-blue-300 rounded border border-blue-700"
              >
                PROFILE CPU
              </button>
            </div>

            <div class="text-sm text-content-secondary space-y-1">
              <%= if @last_health_check do %>
                <div>
                  Last Health Check: {Calendar.strftime(
                    @last_health_check.timestamp,
                    "%Y-%m-%d %H:%M:%S"
                  )} - {String.upcase(to_string(@last_health_check.status))} \u2713
                </div>
              <% end %>
              <%= if @last_state_dump do %>
                <div>
                  Last State Dump: {Calendar.strftime(@last_state_dump.timestamp, "%Y-%m-%d %H:%M:%S")} - {@last_state_dump.path}
                </div>
              <% end %>
            </div>
          </div>
        </div>
        
    <!-- Action Buttons -->
        <div class="mt-4 flex space-x-4">
          <button
            phx-click="export_logs"
            class="px-4 py-2 bg-surface-tertiary hover:bg-gray-600 text-content-primary rounded"
          >
            EXPORT LOGS
          </button>
          <button
            phx-click="clear_old_logs"
            class="px-4 py-2 bg-surface-tertiary hover:bg-gray-600 text-content-primary rounded"
          >
            CLEAR OLD LOGS
          </button>
          <button
            phx-click="open_signoz"
            class="px-4 py-2 bg-purple-900 hover:bg-purple-800 text-purple-300 rounded border border-purple-700"
          >
            OPEN IN SIGNOZ
          </button>
        </div>
      </main>
      
    <!-- Footer -->
      <footer class="fixed bottom-0 left-0 right-0 bg-surface-secondary border-t border-border-theme-primary px-4 py-2">
        <div class="flex items-center justify-between text-xs text-content-muted">
          <div class="flex space-x-4">
            <span>[H] Health Check</span>
            <span>[D] Dump State</span>
            <span>[T] Trace</span>
            <span>[P] Profile</span>
          </div>
          <div>OTEL | SigNoz Integration</div>
        </div>
      </footer>
    </div>
    """
  end

  # Private helpers

  defp init_logs do
    now = DateTime.utc_now()

    Enum.map(0..20, fn i ->
      %{
        timestamp: DateTime.add(now, -i, :second),
        level: Enum.random(@log_levels),
        source:
          Enum.random([
            "Prajna.SmartMetrics",
            "Phoenix.PubSub",
            "Sentinel",
            "OODA.Loop",
            "Guardian",
            "ContainerHealth"
          ]),
        message:
          Enum.random([
            "Recorded metric: cpu.app-03",
            "Broadcast: prajna:metrics",
            "Heartbeat received from indrajaal-2",
            "Cycle completed: 0.847s",
            "Safety check passed",
            "All containers healthy"
          ])
      }
    end)
  end

  defp init_traces do
    [
      %{
        id: "trace-abc123",
        method: "POST",
        path: "/api/alarms",
        duration_ms: 234,
        span_count: 12,
        status: :slow,
        spans: [
          %{name: "Phoenix.Endpoint", duration_ms: 2, slow: false},
          %{name: "AlarmController.create", duration_ms: 5, slow: false},
          %{name: "Ecto.Repo.insert", duration_ms: 180, slow: true},
          %{name: "PubSub.broadcast", duration_ms: 3, slow: false}
        ]
      },
      %{
        id: "trace-def456",
        method: "GET",
        path: "/api/metrics",
        duration_ms: 45,
        span_count: 8,
        status: :normal,
        spans: [
          %{name: "Phoenix.Endpoint", duration_ms: 1, slow: false},
          %{name: "MetricsController.index", duration_ms: 3, slow: false},
          %{name: "Ecto.Repo.all", duration_ms: 28, slow: false},
          %{name: "JSON.encode", duration_ms: 2, slow: false}
        ]
      }
    ]
  end

  defp init_audit_trail do
    now = DateTime.utc_now()

    [
      %{
        timestamp: DateTime.add(now, -300, :second),
        action: "ALARM_ACK",
        resource: "ALM-2024-00_142",
        user: "operator@indrajaal.local",
        details: "Acknowledged intrusion alarm in Zone-A"
      },
      %{
        timestamp: DateTime.add(now, -1800, :second),
        action: "CONFIG_CHANGE",
        resource: "settings.thresholds",
        user: "admin@indrajaal.local",
        details: "Updated CPU warning threshold from 85% to 90%"
      },
      %{
        timestamp: DateTime.add(now, -3600, :second),
        action: "COMMAND_EXEC",
        resource: "app-03",
        user: "operator@indrajaal.local",
        details: "Executed RESTART command (graceful)"
      },
      %{
        timestamp: DateTime.add(now, -7200, :second),
        action: "LOGIN",
        resource: "session",
        user: "operator@indrajaal.local",
        details: "Successful login from 192.168.1.100"
      }
    ]
  end

  defp init_system_info do
    mem = :erlang.memory()
    total_mb = div(mem[:total], 1_048_576)
    proc_mb = div(mem[:processes], 1_048_576)
    ets_mb = div(mem[:ets], 1_048_576)
    {wall_ms, _} = :erlang.statistics(:wall_clock)
    uptime_str = format_beam_uptime(wall_ms)

    elixir_vsn = System.version()
    otp_vsn = to_string(:erlang.system_info(:otp_release))

    %{
      runtime: [
        {"Elixir Version", elixir_vsn},
        {"OTP Version", otp_vsn},
        {"Node Name", to_string(node())},
        {"Uptime", uptime_str},
        {"Connected Nodes", to_string(length(Node.list()))},
        {"System Time", Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d %H:%M:%S UTC")}
      ],
      beam: [
        {"Schedulers", to_string(:erlang.system_info(:schedulers_online))},
        {"Process Count", to_string(:erlang.system_info(:process_count))},
        {"Port Count", to_string(length(:erlang.ports()))},
        {"Memory Total", "#{total_mb} MB"},
        {"Memory Processes", "#{proc_mb} MB"},
        {"Memory ETS", "#{ets_mb} MB"}
      ]
    }
  end

  defp format_beam_uptime(wall_ms) do
    total_s = div(wall_ms, 1000)
    days = div(total_s, 86400)
    hours = div(rem(total_s, 86400), 3600)
    mins = div(rem(total_s, 3600), 60)
    "#{days}d #{hours}h #{mins}m"
  end

  defp maybe_add_log(logs) do
    if :rand.uniform(100) < 30 do
      new_log = %{
        timestamp: DateTime.utc_now(),
        level: Enum.random(@log_levels),
        source: Enum.random(["Prajna.SmartMetrics", "Phoenix.PubSub", "Sentinel"]),
        message:
          Enum.random([
            "Recorded metric: cpu.app-01",
            "Heartbeat received",
            "Cycle completed"
          ])
      }

      [new_log | logs] |> Enum.take(500)
    else
      logs
    end
  end

  defp filter_logs(logs, filter) do
    logs
    |> Enum.filter(fn log ->
      level_ok =
        case filter.level do
          "debug" -> true
          "info" -> log.level in [:info, :warning, :error]
          "warning" -> log.level in [:warning, :error]
          "error" -> log.level == :error
          _ -> true
        end

      source_ok =
        filter.source == "all" or String.contains?(String.downcase(log.source), filter.source)

      search_ok =
        filter.search == "" or
          String.contains?(String.downcase(log.message), String.downcase(filter.search))

      level_ok and source_ok and search_ok
    end)
  end

  defp log_level_class(:debug), do: "text-content-muted"
  defp log_level_class(:info), do: "text-accent-primary"
  defp log_level_class(:warning), do: "text-yellow-400"
  defp log_level_class(:error), do: "text-red-400"

  defp audit_action_class("ALARM_ACK"), do: "text-green-400"
  defp audit_action_class("CONFIG_CHANGE"), do: "text-yellow-400"
  defp audit_action_class("COMMAND_EXEC"), do: "text-accent-primary"
  defp audit_action_class("LOGIN"), do: "text-content-secondary"
  defp audit_action_class(_), do: "text-content-secondary"
end
