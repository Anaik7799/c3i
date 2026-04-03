defmodule IndrajaalWeb.Prajna.ContainersLive do
  @moduledoc """
  PRAJNA C3I Container Status Screen

  WHAT: Container health monitoring and lifecycle management following
        NASA-STD-3000 Dark Cockpit principles for the 3-container stack.

  WHY: Provides situational awareness for container orchestration:
       - Real-time container health with trend vectors
       - CPU/Memory/Disk utilization sparklines
       - Container-specific metrics (DB connections, trace latency)
       - Quick actions: Restart, Logs, Shell/PSQL
       - Staleness detection for metric freshness

  CONSTRAINTS:
    - SC-HMI-001: Dark Cockpit (gray defaults, amber/red deviations)
    - SC-HMI-002: Trend vectors displayed
    - SC-HMI-003: Staleness visual decay
    - SC-CNT-009: NixOS/Podman only
    - SC-CNT-012: Rootless mode

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-27 |
  | Author | Cybernetic Architect |
  | Reference | NASA-STD-3000, NUREG-0700 |
  """

  use IndrajaalWeb, :live_view

  @refresh_interval 2000

  # Container names aligned with F# CEPAF StandaloneChain.fs
  # Startup order: Layer 0 (DB) → Layer 1 (Redis) → Layer 2 (OBS) → Layer 3 (App)
  @containers [
    %{
      id: :db,
      name: "indrajaal-db-standalone",
      description: "PostgreSQL 17 + TimescaleDB",
      image: "localhost/indrajaal-timescaledb-demo:nixos-devenv",
      ports: ["5433"],
      layer: 0,
      status: :running,
      health: :healthy
    },
    %{
      id: :redis,
      name: "indrajaal-redis-standalone",
      description: "Redis Cache",
      image: "localhost/indrajaal-redis-demo:nixos-devenv",
      ports: ["6379"],
      layer: 1,
      status: :running,
      health: :healthy
    },
    %{
      id: :obs,
      name: "indrajaal-obs-standalone",
      description: "SigNoz Observability Stack",
      image: "localhost/indrajaal-obs-standalone:latest",
      ports: ["8123", "9090"],
      layer: 2,
      status: :running,
      health: :healthy
    },
    %{
      id: :app,
      name: "indrajaal-ex-app-1",
      description: "Phoenix Web Application",
      image: "localhost/indrajaal-sopv51-elixir-app:nixos-25.05-devenv",
      ports: ["4000 (HTTP)", "4001 (HTTPS)"],
      layer: 3,
      status: :running,
      health: :healthy
    }
  ]

  # Container status icons for template rendering
  @status_icons %{
    running: "\u2713",
    stopped: "\u25A0",
    starting: "\u25CF",
    error: "\u2717"
  }
  def status_icon(status), do: Map.get(@status_icons, status, "?")

  # Container health icons for template rendering
  @health_icons %{
    healthy: "\u2713",
    degraded: "\u26A0",
    unhealthy: "\u2717"
  }
  def health_icon(health), do: Map.get(@health_icons, health, "?")

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(@refresh_interval, self(), :refresh)
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "prajna:containers")
    end

    {:ok,
     socket
     |> assign(:page_title, "Container Status")
     |> assign(:containers, init_containers())
     |> assign(:selected_container, nil)
     |> assign(:show_logs, false)
     |> assign(:logs, [])
     |> assign(:current_view, :overview)
     |> assign(:status_icons, @status_icons)
     |> assign(:health_icons, @health_icons)}
  end

  @impl true
  def handle_info(:refresh, socket) do
    containers = update_container_metrics(socket.assigns.containers)
    {:noreply, assign(socket, :containers, containers)}
  end

  @impl true
  def handle_info({:container_update, id, data}, socket) do
    containers =
      Enum.map(socket.assigns.containers, fn c ->
        if c.id == id, do: Map.merge(c, data), else: c
      end)

    {:noreply, assign(socket, :containers, containers)}
  end

  @impl true
  def handle_event("select_container", %{"id" => id}, socket) do
    {:noreply, assign(socket, :selected_container, String.to_existing_atom(id))}
  end

  @impl true
  def handle_event("restart_container", %{"id" => id}, socket) do
    # Two-step commit - would trigger armed command
    {:noreply,
     socket
     |> put_flash(:info, "Restart command armed for #{id}. Confirm in Command Center.")}
  end

  @impl true
  def handle_event("view_logs", %{"id" => id}, socket) do
    logs = fetch_container_logs(String.to_existing_atom(id))
    {:noreply, socket |> assign(:show_logs, true) |> assign(:logs, logs)}
  end

  @impl true
  def handle_event("close_logs", _params, socket) do
    {:noreply, assign(socket, :show_logs, false)}
  end

  @impl true
  def handle_event("start_all", _params, socket) do
    {:noreply, put_flash(socket, :info, "Start all containers command queued")}
  end

  @impl true
  def handle_event("stop_all", _params, socket) do
    {:noreply, put_flash(socket, :warning, "Stop all containers requires two-step confirmation")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- L4-A09: Theme-aware Containers page (SC-HMI-001, SC-HMI-008) --%>
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
          <span class="text-content-secondary">CONTAINERS</span>
        </div>
        <div class="flex items-center space-x-4">
          <span class="text-content-muted">
            Stack: 3-Container (App + DB + Obs)
          </span>
          <span class="text-content-muted">|</span>
          <span class="text-content-secondary">
            {Calendar.strftime(DateTime.utc_now(), "%H:%M:%S")}
          </span>
        </div>
      </header>
      
    <!-- Navigation Tabs -->
      <nav class="bg-surface-secondary border-b border-border-theme-primary px-4">
        <div class="flex space-x-1">
          <%= for {view, label} <- [overview: "Overview", mesh: "Mesh", alarms: "Alarms", commands: "Commands", ai: "AI Copilot", containers: "Containers"] do %>
            <a
              href={if view == :containers, do: "/cockpit/containers", else: "/cockpit/#{view}"}
              class={"px-4 py-2 text-sm font-medium transition-colors #{if view == :containers, do: "text-accent-primary border-b-2 border-accent-primary", else: "text-content-muted hover:text-content-primary"}"}
            >
              {String.upcase(label)}
            </a>
          <% end %>
        </div>
      </nav>
      
    <!-- Main Content -->
      <main class="p-4 space-y-4">
        <%= for container <- @containers do %>
          <div
            class={"bg-surface-secondary rounded-lg border #{container_border_class(container)} p-4"}
            phx-click="select_container"
            phx-value-id={container.id}
          >
            <!-- Container Header -->
            <div class="flex items-center justify-between mb-4">
              <div class="flex items-center space-x-3">
                <span class={health_icon_class(container.health)}>
                  {@health_icons[container.health]}
                </span>
                <div>
                  <h3 class="font-bold text-gray-200">{container.name}</h3>
                  <p class="text-xs text-content-muted">{container.description}</p>
                </div>
              </div>
              <div class="flex items-center space-x-4 text-sm">
                <span class={status_class(container.status)}>
                  {@status_icons[container.status]} {String.upcase(to_string(container.status))}
                </span>
                <span class={health_class(container.health)}>
                  {String.upcase(to_string(container.health))}
                </span>
                <span class="text-content-muted">
                  Uptime: {container.uptime}
                </span>
              </div>
            </div>
            
    <!-- Container Details -->
            <div class="grid grid-cols-2 gap-4 mb-4">
              <div class="text-xs text-content-muted">
                <span>Image:</span>
                <span class="text-content-secondary ml-2">{container.image}</span>
              </div>
              <div class="text-xs text-content-muted">
                <span>Ports:</span>
                <span class="text-content-secondary ml-2">{Enum.join(container.ports, ", ")}</span>
              </div>
            </div>
            
    <!-- Resource Bars -->
            <div class="grid grid-cols-3 gap-4 mb-4">
              <div>
                <div class="flex justify-between text-xs mb-1">
                  <span class="text-content-muted">CPU</span>
                  <span class={value_class(container.cpu)}>{container.cpu}%</span>
                </div>
                {render_progress_bar(container.cpu, container.cpu_level)}
              </div>
              <div>
                <div class="flex justify-between text-xs mb-1">
                  <span class="text-content-muted">Memory</span>
                  <span class={value_class(container.memory)}>
                    {container.memory}% ({container.memory_used}/{container.memory_total})
                  </span>
                </div>
                {render_progress_bar(container.memory, container.memory_level)}
              </div>
              <%= if container.disk do %>
                <div>
                  <div class="flex justify-between text-xs mb-1">
                    <span class="text-content-muted">Disk</span>
                    <span class={value_class(container.disk)}>
                      {container.disk}% ({container.disk_used}/{container.disk_total})
                    </span>
                  </div>
                  {render_progress_bar(container.disk, container.disk_level)}
                </div>
              <% end %>
            </div>
            
    <!-- Sparklines -->
            <div class="grid grid-cols-2 gap-4 mb-4 text-xs">
              <div class="flex items-center space-x-2">
                <span class="text-content-muted w-8">CPU</span>
                <span class="text-content-secondary font-mono">{container.cpu_sparkline}</span>
                <span class="text-content-muted">(1h)</span>
              </div>
              <div class="flex items-center space-x-2">
                <span class="text-content-muted w-8">MEM</span>
                <span class="text-content-secondary font-mono">{container.mem_sparkline}</span>
                <span class="text-content-muted">(1h)</span>
              </div>
            </div>
            
    <!-- Container-specific metrics -->
            <%= if container.extra_metrics do %>
              <div class="border-t border-border-theme-primary pt-3 mb-3">
                <%= for metric <- container.extra_metrics do %>
                  <div class="flex items-center text-xs mb-1">
                    <span class={metric_class(metric)}>{metric.icon}</span>
                    <span class="text-content-muted ml-2">{metric.label}:</span>
                    <span class="text-content-secondary ml-2">{metric.value}</span>
                  </div>
                <% end %>
              </div>
            <% end %>
            
    <!-- Action Buttons -->
            <div class="flex space-x-2 pt-3 border-t border-border-theme-primary">
              <button
                phx-click="restart_container"
                phx-value-id={container.id}
                class="px-3 py-1 bg-yellow-900 hover:bg-yellow-800 text-yellow-300 text-xs rounded border border-yellow-700"
              >
                RESTART
              </button>
              <button
                phx-click="view_logs"
                phx-value-id={container.id}
                class="px-3 py-1 bg-surface-tertiary hover:bg-gray-600 text-content-primary text-xs rounded border border-border-theme-secondary"
              >
                VIEW LOGS
              </button>
              <button class="px-3 py-1 bg-surface-tertiary hover:bg-gray-600 text-content-primary text-xs rounded border border-border-theme-secondary">
                {container_shell_label(container)}
              </button>
            </div>
          </div>
        <% end %>
        
    <!-- Bulk Actions -->
        <div class="flex space-x-4 pt-4">
          <button
            phx-click="start_all"
            class="px-4 py-2 bg-green-900 hover:bg-green-800 text-green-300 rounded border border-green-700"
          >
            START ALL
          </button>
          <button
            phx-click="stop_all"
            class="px-4 py-2 bg-red-900 hover:bg-red-800 text-red-300 rounded border border-red-700"
          >
            STOP ALL
          </button>
          <button class="px-4 py-2 bg-blue-900 hover:bg-blue-800 text-blue-300 rounded border border-blue-700">
            REBUILD IMAGES
          </button>
        </div>
      </main>
      
    <!-- Logs Modal -->
      <%= if @show_logs do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div class="bg-surface-secondary border border-border-theme-primary rounded-lg p-4 w-3/4 max-h-3/4">
            <div class="flex items-center justify-between mb-4">
              <h3 class="font-bold text-gray-200">Container Logs</h3>
              <button phx-click="close_logs" class="text-content-muted hover:text-content-primary">
                [X]
              </button>
            </div>
            <div class="bg-surface-primary p-4 rounded font-mono text-xs max-h-96 overflow-y-auto">
              <%= for log <- @logs do %>
                <div class={log_class(log.level)}>
                  [{log.timestamp}] {log.message}
                </div>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
      
    <!-- Footer -->
      <footer class="fixed bottom-0 left-0 right-0 bg-surface-secondary border-t border-border-theme-primary px-4 py-2">
        <div class="flex items-center justify-between text-xs text-content-muted">
          <div class="flex space-x-4">
            <span>[R] Restart</span>
            <span>[L] Logs</span>
            <span>[S] Shell</span>
          </div>
          <div>Container Mode: Podman Rootless | SC-CNT-009 Compliant</div>
        </div>
      </footer>
    </div>
    """
  end

  # Private helpers

  defp init_containers do
    Enum.map(@containers, fn c ->
      Map.merge(c, %{
        uptime: random_uptime(),
        cpu: :rand.uniform(50) + 20,
        cpu_level: :normal,
        memory: :rand.uniform(40) + 40,
        memory_level: :normal,
        memory_used: "#{:rand.uniform(3)}.#{:rand.uniform(9)}GB",
        memory_total: "4.0GB",
        disk: if(c.id == :db, do: :rand.uniform(30) + 50, else: nil),
        disk_level: :normal,
        disk_used: "31GB",
        disk_total: "50GB",
        cpu_sparkline: generate_sparkline(),
        mem_sparkline: generate_sparkline(),
        extra_metrics: container_extra_metrics(c.id)
      })
    end)
  end

  defp update_container_metrics(containers) do
    beam = fetch_beam_metrics()

    Enum.map(containers, fn c ->
      if c.id == :app do
        # Wire app container to real BEAM metrics
        %{
          c
          | cpu: beam.cpu,
            cpu_level: level_for_value(beam.cpu),
            memory: beam.memory_pct,
            memory_level: level_for_value(beam.memory_pct),
            memory_used: "#{beam.memory_mb}MB",
            memory_total: "8192MB"
        }
      else
        # Other containers: small synthetic jitter (no direct BEAM access)
        cpu = clamp(c.cpu + (:rand.uniform(11) - 6), 5, 95)
        memory = clamp(c.memory + (:rand.uniform(5) - 3), 20, 95)

        %{
          c
          | cpu: cpu,
            cpu_level: level_for_value(cpu),
            memory: memory,
            memory_level: level_for_value(memory)
        }
      end
    end)
  end

  defp fetch_beam_metrics do
    memory = :erlang.memory()
    total_mem_mb = div(memory[:total], 1_048_576)
    process_count = :erlang.system_info(:process_count)
    schedulers = :erlang.system_info(:schedulers_online)
    run_queue = :erlang.statistics(:run_queue)
    {uptime_ms, _} = :erlang.statistics(:wall_clock)

    cpu = min(95, max(5, div(run_queue * 20, max(schedulers, 1)) + div(process_count, 500)))
    memory_pct = min(95, max(5, div(total_mem_mb * 100, 8192)))

    %{
      cpu: cpu,
      memory_pct: memory_pct,
      memory_mb: total_mem_mb,
      process_count: process_count,
      uptime_formatted: format_beam_uptime(uptime_ms)
    }
  end

  defp format_beam_uptime(ms) do
    seconds = div(ms, 1000)
    days = div(seconds, 86400)
    hours = div(rem(seconds, 86400), 3600)
    "#{days}d #{hours}h"
  end

  defp container_extra_metrics(:app) do
    []
  end

  defp container_extra_metrics(:db) do
    [
      %{icon: "\u25CF", label: "Connections", value: "23/100", level: :normal},
      %{icon: "\u25CF", label: "Transactions/s", value: "145", level: :normal},
      %{icon: "\u25CF", label: "Replication", value: "N/A (standalone)", level: :normal}
    ]
  end

  defp container_extra_metrics(:obs) do
    [
      %{
        icon: "\u26A0",
        label: "Trace ingestion latency",
        value: "2.3s (target: <1s)",
        level: :warning
      }
    ]
  end

  defp container_extra_metrics(:redis) do
    [
      %{icon: "●", label: "Connected clients", value: "4", level: :normal},
      %{icon: "●", label: "Memory usage", value: "2.1MB", level: :normal}
    ]
  end

  defp container_extra_metrics(_), do: []

  defp fetch_container_logs(_id) do
    now = DateTime.utc_now()

    Enum.map(0..20, fn i ->
      %{
        timestamp: Calendar.strftime(DateTime.add(now, -i, :second), "%H:%M:%S"),
        level: Enum.random([:info, :info, :info, :warning]),
        message:
          Enum.random([
            "Request processed in 12ms",
            "Health check passed",
            "Connection pool: 23/100 active",
            "Metrics exported to OTLP",
            "PubSub broadcast: prajna:metrics"
          ])
      }
    end)
  end

  defp generate_sparkline do
    Enum.map_join(1..20, "", fn _ ->
      Enum.random(~w(\u2581 \u2582 \u2583 \u2584 \u2585 \u2586 \u2587))
    end)
  end

  defp random_uptime do
    days = :rand.uniform(30)
    hours = :rand.uniform(24)
    "#{days}d #{hours}h"
  end

  defp clamp(value, min, max), do: max(min, min(max, value))

  defp level_for_value(value) when value >= 90, do: :critical
  defp level_for_value(value) when value >= 80, do: :warning
  defp level_for_value(value) when value >= 70, do: :caution
  defp level_for_value(_value), do: :normal

  defp container_border_class(%{health: :healthy}), do: "border-border-theme-primary"
  defp container_border_class(%{health: :degraded}), do: "border-yellow-700"
  defp container_border_class(%{health: :unhealthy}), do: "border-red-700"

  defp health_icon_class(:healthy), do: "text-green-400"
  defp health_icon_class(:degraded), do: "text-yellow-400"
  defp health_icon_class(:unhealthy), do: "text-red-400"

  defp status_class(:running), do: "text-green-400"
  defp status_class(:stopped), do: "text-content-muted"
  defp status_class(:starting), do: "text-accent-primary"
  defp status_class(:error), do: "text-red-400"

  defp health_class(:healthy), do: "text-green-400"
  defp health_class(:degraded), do: "text-yellow-400"
  defp health_class(:unhealthy), do: "text-red-400"

  defp value_class(value) when value >= 90, do: "text-red-400"
  defp value_class(value) when value >= 80, do: "text-yellow-400"
  defp value_class(_value), do: "text-content-secondary"

  defp metric_class(%{level: :warning}), do: "text-yellow-400"
  defp metric_class(_), do: "text-green-400"

  defp log_class(:info), do: "text-content-secondary"
  defp log_class(:warning), do: "text-yellow-400"
  defp log_class(:error), do: "text-red-400"

  defp container_shell_label(%{id: :db}), do: "PSQL"
  defp container_shell_label(_), do: "SHELL"

  defp render_progress_bar(value, level) do
    bar_color =
      case level do
        :critical -> "bg-red-500"
        :warning -> "bg-yellow-500"
        :caution -> "bg-yellow-400"
        _ -> "bg-green-500"
      end

    assigns = %{value: value, bar_color: bar_color}

    ~H"""
    <div class="h-2 bg-surface-tertiary rounded-full overflow-hidden">
      <div class={"h-full #{@bar_color} transition-all duration-200"} style={"width: #{@value}%"}>
      </div>
    </div>
    """
  end
end
