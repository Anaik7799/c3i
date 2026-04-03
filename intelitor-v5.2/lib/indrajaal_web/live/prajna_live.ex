defmodule IndrajaalWeb.PrajnaLive do
  @moduledoc """
  PRAJNA C3I Mesh Cockpit - Main Dashboard LiveView

  WHAT: Primary operational dashboard implementing NASA-STD-3000 Dark Cockpit philosophy
        for safety-critical distributed control with AI-enhanced intelligence.

  WHY: Provides single-glance system status awareness through:
       - Health score with trend vectors
       - Safety systems status (Guardian, DMS, Envelope, Sentinel)
       - Mesh node grid with CPU/Memory/Latency
       - AI Copilot insights panel
       - Active alarms with quick actions
       - Container health mini-cards
       - OODA cycle status

  CONSTRAINTS:
    - SC-HMI-001: Dark Cockpit (gray/blue default, amber/red deviations)
    - SC-HMI-002: Trend vectors displayed
    - SC-HMI-003: Staleness visual decay after 5s
    - SC-HMI-004: Two-step commit UI for critical commands
    - SC-HMI-008: Contrast ratio minimum 4.5:1
    - SC-PRF-050: Updates < 50ms latency

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 2.0.0 |
  | Created | 2025-12-27 |
  | Author | Cybernetic Architect |
  | STAMP | SC-HMI-001 to SC-HMI-004, SC-HMI-008, SC-PRF-050 |
  """

  use IndrajaalWeb, :live_view

  alias Indrajaal.Cockpit.Prajna.Messaging

  @refresh_interval 500

  # Simulated mesh nodes for demo
  @demo_nodes [
    %{id: "app-01", role: :supervisor},
    %{id: "app-02", role: :controller},
    %{id: "app-03", role: :controller},
    %{id: "app-04", role: :controller},
    %{id: "app-05", role: :worker}
  ]

  # Simulated containers
  @demo_containers [
    %{id: :app, name: "indrajaal-app", ports: ["4000", "4001"]},
    %{id: :db, name: "indrajaal-db", ports: ["5433"]},
    %{id: :obs, name: "indrajaal-obs", ports: ["8123"]}
  ]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(@refresh_interval, self(), :refresh)
      Messaging.subscribe(:metrics)
      Messaging.subscribe(:alarms)
      Messaging.subscribe(:insights)
      Messaging.subscribe(:ooda)
    end

    {:ok,
     socket
     |> assign(:page_title, "PRAJNA C3I Cockpit")
     |> assign(:current_nav, :dashboard)
     |> assign(:health_score, 94)
     |> assign(:uptime, format_uptime(DateTime.utc_now()))
     |> assign(:started_at, DateTime.utc_now())
     |> assign(:nodes, init_nodes())
     |> assign(:containers, init_containers())
     |> assign(:alarms, init_alarms())
     |> assign(:insights, init_insights())
     |> assign(:safety, init_safety())
     |> assign(:ooda, init_ooda())
     |> assign(:armed_command, nil)
     |> assign(:command_countdown, 300)}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply,
     socket
     |> update_metrics()
     |> update_ooda()
     |> update_command_countdown()}
  end

  @impl true
  def handle_info({:metric_updated, _node_id, _type, _value}, socket) do
    {:noreply, update_metrics(socket)}
  end

  @impl true
  def handle_info({:alarm_raised, _alarm_id, _level, _message}, socket) do
    {:noreply, assign(socket, :alarms, update_alarms(socket.assigns.alarms))}
  end

  @impl true
  def handle_info({:insight_generated, _type, _content, _confidence}, socket) do
    {:noreply, assign(socket, :insights, update_insights())}
  end

  @impl true
  def handle_info({:ooda_phase_changed, phase, cycle_ms}, socket) do
    ooda = %{socket.assigns.ooda | phase: phase, cycle_ms: cycle_ms}
    {:noreply, assign(socket, :ooda, ooda)}
  end

  @impl true
  def handle_event("ack_alarm", %{"id" => alarm_id}, socket) do
    alarms =
      Enum.map(socket.assigns.alarms, fn alarm ->
        if alarm.id == alarm_id, do: %{alarm | acknowledged: true}, else: alarm
      end)

    {:noreply, assign(socket, :alarms, alarms)}
  end

  @impl true
  def handle_event("dismiss_insight", %{"id" => insight_id}, socket) do
    insights = Enum.reject(socket.assigns.insights, &(&1.id == insight_id))
    {:noreply, assign(socket, :insights, insights)}
  end

  @impl true
  def handle_event("arm_command", %{"node" => node_id, "command" => command}, socket) do
    armed = %{
      node: node_id,
      command: command,
      armed_at: DateTime.utc_now(),
      armed_by: "operator@indrajaal.local"
    }

    {:noreply, socket |> assign(:armed_command, armed) |> assign(:command_countdown, 300)}
  end

  @impl true
  def handle_event("confirm_command", _params, socket) do
    # Execute the command (simulated)
    {:noreply, socket |> assign(:armed_command, nil) |> put_flash(:info, "Command executed")}
  end

  @impl true
  def handle_event("cancel_command", _params, socket) do
    {:noreply, assign(socket, :armed_command, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- L4-A09: Theme-aware main container (SC-HMI-001, SC-HMI-008) --%>
    <div class="min-h-screen bg-surface-primary text-content-primary font-mono">
      <!-- Status Bar Header -->
      <.prajna_header
        health_score={@health_score}
        uptime={@uptime}
        node_count={healthy_node_count(@nodes)}
        total_nodes={length(@nodes)}
        alarm_count={active_alarm_count(@alarms)}
      />
      
    <!-- Navigation Tabs -->
      <.prajna_nav current={@current_nav} />
      
    <!-- Main Content -->
      <main class="p-4 space-y-4">
        <!-- Safety Status Bar -->
        <.safety_status
          guardian={@safety.guardian}
          dms={@safety.dms}
          envelope={@safety.envelope}
          sentinel={@safety.sentinel}
          sentinel_total={@safety.sentinel_total}
          violations={@safety.violations}
          heartbeats={@safety.heartbeats}
          utilization={@safety.utilization}
        />

        <div class="grid grid-cols-12 gap-4">
          <!-- Left Column: Nodes + Containers + OODA -->
          <div class="col-span-8 space-y-4">
            <!-- Mesh Nodes -->
            <div class="bg-surface-secondary rounded-lg border border-border-theme-primary">
              <div class="px-4 py-2 border-b border-border-theme-primary flex items-center justify-between">
                <h2 class="text-sm font-bold text-content-secondary">
                  MESH NODES ({length(@nodes)})
                </h2>
                <a
                  href="/cockpit/mesh"
                  class="text-xs text-accent-primary hover:text-accent-primary/80"
                >
                  View Topology →
                </a>
              </div>
              <div class="p-4 grid grid-cols-5 gap-3">
                <%= for node <- @nodes do %>
                  <.node_card
                    id={node.id}
                    cpu={node.cpu}
                    memory={node.memory}
                    latency={node.latency}
                    cpu_trend={node.cpu_trend}
                    memory_trend={node.memory_trend}
                    status={node.status}
                  />
                <% end %>
              </div>
            </div>
            
    <!-- Active Alarms -->
            <div class="bg-surface-secondary rounded-lg border border-border-theme-primary">
              <div class="px-4 py-2 border-b border-border-theme-primary flex items-center justify-between">
                <h2 class="text-sm font-bold text-content-secondary">
                  ACTIVE ALARMS ({active_alarm_count(@alarms)})
                </h2>
                <a
                  href="/cockpit/alarms"
                  class="text-xs text-accent-primary hover:text-accent-primary/80"
                >
                  View Alarm Center →
                </a>
              </div>
              <div class="p-4 space-y-3">
                <%= for alarm <- @alarms |> Enum.filter(& !&1.acknowledged) |> Enum.take(3) do %>
                  <.alarm_card
                    id={alarm.id}
                    level={alarm.level}
                    source={alarm.source}
                    message={alarm.message}
                    age={alarm.age}
                    occurrences={alarm.occurrences}
                    ai_insight={alarm.ai_insight}
                    on_ack="ack_alarm"
                  />
                <% end %>
                <%= if active_alarm_count(@alarms) == 0 do %>
                  <div class="text-center text-content-muted py-4">
                    No active alarms
                  </div>
                <% end %>
              </div>
            </div>
            
    <!-- Containers + OODA -->
            <div class="grid grid-cols-2 gap-4">
              <!-- Container Mini-Cards -->
              <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
                <h3 class="text-xs text-content-muted mb-3">CONTAINERS</h3>
                <div class="space-y-2">
                  <%= for container <- @containers do %>
                    <div class="flex items-center justify-between text-xs">
                      <div class="flex items-center space-x-2">
                        <.status_icon state={container_health(container)} size={:sm} />
                        <span class="text-content-primary">{container.name}</span>
                      </div>
                      <div class="flex items-center space-x-2">
                        <span class="text-content-muted">{hd(container.ports)}</span>
                        <.gauge
                          value={container.cpu}
                          max={100.0}
                          width={5}
                          show_percent={false}
                          alarm_level={cpu_level(container.cpu)}
                        />
                        <span class="text-content-secondary w-8">{round(container.cpu)}%</span>
                      </div>
                    </div>
                  <% end %>
                </div>
                <a
                  href="/cockpit/containers"
                  class="block mt-3 text-xs text-accent-primary hover:text-accent-primary/80"
                >
                  Manage Containers →
                </a>
              </div>
              
    <!-- OODA Cycle Status -->
              <.ooda_status
                phase={@ooda.phase}
                cycle_ms={@ooda.cycle_ms}
                target_ms={@ooda.target_ms}
                quality={@ooda.quality}
              />
            </div>
            
    <!-- Quick Metrics Sparklines -->
            <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
              <h3 class="text-xs text-content-muted mb-3">QUICK METRICS SPARKLINES</h3>
              <div class="space-y-2">
                <div class="flex items-center space-x-2 text-xs">
                  <span class="text-content-muted w-10">CPU</span>
                  <.sparkline
                    values={aggregate_sparkline(@nodes, :cpu_history)}
                    width={40}
                    class="text-content-muted"
                  />
                  <span class="text-content-secondary">avg: {average_metric(@nodes, :cpu)}%</span>
                </div>
                <div class="flex items-center space-x-2 text-xs">
                  <span class="text-content-muted w-10">MEM</span>
                  <.sparkline
                    values={aggregate_sparkline(@nodes, :memory_history)}
                    width={40}
                    class="text-content-muted"
                  />
                  <span class="text-content-secondary">avg: {average_metric(@nodes, :memory)}%</span>
                </div>
                <div class="flex items-center space-x-2 text-xs">
                  <span class="text-content-muted w-10">LAT</span>
                  <.sparkline
                    values={aggregate_sparkline(@nodes, :latency_history)}
                    width={40}
                    class="text-content-muted"
                  />
                  <span class="text-content-secondary">
                    avg: {average_metric(@nodes, :latency)}ms
                  </span>
                </div>
              </div>
            </div>
          </div>
          
    <!-- Right Column: AI Copilot -->
          <div class="col-span-4">
            <div class="bg-surface-secondary rounded-lg border border-border-theme-primary">
              <div class="px-4 py-2 border-b border-border-theme-primary flex items-center justify-between">
                <h2 class="text-sm font-bold text-content-secondary">AI COPILOT</h2>
                <a
                  href="/cockpit/ai-copilot"
                  class="text-xs text-accent-primary hover:text-accent-primary/80"
                >
                  View All →
                </a>
              </div>
              <div class="p-4 space-y-3">
                <%= for insight <- Enum.take(@insights, 3) do %>
                  <.insight_card
                    type={insight.type}
                    confidence={insight.confidence}
                    title={insight.title}
                    content={insight.content}
                    recommendations={insight.recommendations}
                    related_node={insight.related_node}
                    expires_in={insight.expires_in}
                    on_dismiss="dismiss_insight"
                  />
                <% end %>
                <%= if @insights == [] do %>
                  <div class="text-center text-content-muted py-8">
                    <p class="mb-2">System operating normally</p>
                    <p class="text-xs">AI Copilot will alert when anomalies detected</p>
                  </div>
                <% end %>
              </div>
            </div>
            
    <!-- Fractal Log Preview -->
            <div class="mt-4 bg-surface-secondary rounded-lg border border-border-theme-primary">
              <div class="px-4 py-2 border-b border-border-theme-primary flex items-center justify-between">
                <h2 class="text-sm font-bold text-content-secondary">RECENT LOGS</h2>
                <a
                  href="/cockpit/diagnostics"
                  class="text-xs text-accent-primary hover:text-accent-primary/80"
                >
                  View All →
                </a>
              </div>
              <div class="p-2 space-y-1 max-h-32 overflow-hidden">
                <.fractal_log
                  level={:segment}
                  source="Guardian"
                  message="Safety check passed"
                  timestamp={DateTime.utc_now()}
                />
                <.fractal_log
                  level={:fiber}
                  source="OODA"
                  message="Cycle complete: 0.84s"
                  timestamp={DateTime.add(DateTime.utc_now(), -2, :second)}
                />
                <.fractal_log
                  level={:gossamer}
                  source="Telemetry"
                  message="Metric batch processed"
                  timestamp={DateTime.add(DateTime.utc_now(), -5, :second)}
                />
              </div>
            </div>
          </div>
        </div>
      </main>
      
    <!-- Two-Step Commit Modal -->
      <%= if @armed_command do %>
        <.two_step_modal
          command={@armed_command.command}
          target={@armed_command.node}
          countdown={@command_countdown}
          armed_by={@armed_command.armed_by}
          armed_at={@armed_command.armed_at}
          on_confirm="confirm_command"
          on_cancel="cancel_command"
        />
      <% end %>
      
    <!-- Footer -->
      <footer class="fixed bottom-0 left-0 right-0 bg-surface-secondary border-t border-border-theme-primary px-4 py-2">
        <div class="flex items-center justify-between text-xs text-content-muted">
          <div class="flex space-x-4">
            <span>[h/j/k/l] Navigate</span>
            <span>[0-4] Levels</span>
            <span>[a] Ack</span>
            <span>[c] Command</span>
            <span>[?] Help</span>
          </div>
          <div>PRAJNA C3I Mesh Cockpit v1.0.0 | IEC 61_508 SIL-2 Compliant</div>
        </div>
      </footer>
    </div>
    """
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # INITIALIZATION HELPERS
  # ═══════════════════════════════════════════════════════════════════════════

  defp init_nodes do
    Enum.map(@demo_nodes, fn node ->
      cpu = 25 + :rand.uniform(50)
      memory = 50 + :rand.uniform(30)
      latency = 5 + :rand.uniform(15)

      %{
        id: node.id,
        role: node.role,
        cpu: cpu * 1.0,
        memory: memory * 1.0,
        latency: latency * 1.0,
        cpu_trend: random_trend(),
        memory_trend: random_trend(),
        cpu_history: generate_history(cpu, 20),
        memory_history: generate_history(memory, 20),
        latency_history: generate_history(latency, 20),
        status: if(cpu < 90 and memory < 90, do: :healthy, else: :caution)
      }
    end)
  end

  defp init_containers do
    Enum.map(@demo_containers, fn container ->
      cpu = 20 + :rand.uniform(40)
      memory = 40 + :rand.uniform(40)

      Map.merge(container, %{
        cpu: cpu * 1.0,
        memory: memory * 1.0,
        status: :running,
        health: if(cpu < 80, do: :healthy, else: :degraded)
      })
    end)
  end

  defp init_alarms do
    [
      %{
        id: "alm-001",
        level: :caution,
        source: "app-03",
        message: "CPU trending high (45% ↑↑)",
        age: "12 min",
        occurrences: 3,
        ai_insight: "Consider load balancing to app-04 (31% CPU)",
        acknowledged: false
      },
      %{
        id: "alm-002",
        level: :advisory,
        source: "obs",
        message: "SigNoz trace latency elevated",
        age: "45 min",
        occurrences: 1,
        ai_insight: nil,
        acknowledged: false
      }
    ]
  end

  defp init_insights do
    [
      %{
        id: "ins-001",
        type: :summary,
        confidence: 1.0,
        title: "System Status: HEALTHY",
        content: "All 5 nodes operational. 2 alarms active. Health score: 94%.",
        recommendations: [],
        related_node: nil,
        expires_in: 25
      },
      %{
        id: "ins-002",
        type: :anomaly,
        confidence: 0.95,
        title: "High CPU on app-03",
        content:
          "CPU at 45% with trend rising_fast. This pattern often precedes resource exhaustion within 2-4 hours.",
        recommendations: [
          "Consider scaling or load balancing",
          "Check for runaway processes",
          "Review recent deployments"
        ],
        related_node: "app-03",
        expires_in: nil
      },
      %{
        id: "ins-003",
        type: :prediction,
        confidence: 0.78,
        title: "Disk Cleanup Recommended",
        content: "Based on growth trends, disk utilization will reach 85% warning in ~3 days.",
        recommendations: [
          "Schedule log rotation",
          "Archive old TimescaleDB chunks"
        ],
        related_node: "db",
        expires_in: nil
      }
    ]
  end

  defp init_safety do
    %{
      guardian: :active,
      dms: :healthy,
      envelope: :ok,
      sentinel: 3,
      sentinel_total: 3,
      violations: 0,
      heartbeats: 4285,
      utilization: 72
    }
  end

  defp init_ooda do
    %{
      phase: :orient,
      cycle_ms: 847,
      target_ms: 1000,
      quality: 98
    }
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UPDATE HELPERS
  # ═══════════════════════════════════════════════════════════════════════════

  defp update_metrics(socket) do
    nodes =
      Enum.map(socket.assigns.nodes, fn node ->
        delta = (:rand.uniform(10) - 5) / 10.0
        cpu = max(10, min(95, node.cpu + delta))
        memory = max(40, min(95, node.memory + (:rand.uniform(4) - 2) / 10.0))

        %{
          node
          | cpu: cpu,
            memory: memory,
            cpu_trend: calculate_trend(node.cpu_history),
            memory_trend: calculate_trend(node.memory_history),
            cpu_history: [cpu | Enum.take(node.cpu_history, 19)],
            memory_history: [memory | Enum.take(node.memory_history, 19)],
            status: if(cpu < 90 and memory < 90, do: :healthy, else: :caution)
        }
      end)

    containers =
      Enum.map(socket.assigns.containers, fn container ->
        delta = (:rand.uniform(6) - 3) / 10.0
        cpu = max(10, min(90, container.cpu + delta))
        %{container | cpu: cpu, health: if(cpu < 80, do: :healthy, else: :degraded)}
      end)

    # Update health score
    healthy = Enum.count(nodes, &(&1.status == :healthy))
    health_score = round(healthy / length(nodes) * 100)

    socket
    |> assign(:nodes, nodes)
    |> assign(:containers, containers)
    |> assign(:health_score, health_score)
    |> assign(:uptime, format_uptime(socket.assigns.started_at))
  end

  defp update_ooda(socket) do
    ooda = socket.assigns.ooda
    phases = [:observe, :orient, :decide, :act]
    current_idx = Enum.find_index(phases, &(&1 == ooda.phase))
    next_idx = rem(current_idx + 1, 4)
    next_phase = Enum.at(phases, next_idx)

    # Simulate varying cycle time
    cycle_delta = :rand.uniform(100) - 50
    cycle_ms = max(600, min(1200, ooda.cycle_ms + cycle_delta))

    assign(socket, :ooda, %{ooda | phase: next_phase, cycle_ms: cycle_ms})
  end

  defp update_command_countdown(socket) do
    case socket.assigns.armed_command do
      nil ->
        socket

      _ ->
        countdown = socket.assigns.command_countdown - 1

        if countdown <= 0 do
          socket
          |> assign(:armed_command, nil)
          |> assign(:command_countdown, 300)
          |> put_flash(:warning, "Command expired")
        else
          assign(socket, :command_countdown, countdown)
        end
    end
  end

  defp update_alarms(alarms), do: alarms
  defp update_insights, do: []

  # ═══════════════════════════════════════════════════════════════════════════
  # DISPLAY HELPERS
  # ═══════════════════════════════════════════════════════════════════════════

  defp format_uptime(started_at) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, started_at, :second)
    days = div(diff, 86_400)
    hours = div(rem(diff, 86_400), 3600)
    "#{days}d #{hours}h"
  end

  defp healthy_node_count(nodes) do
    Enum.count(nodes, &(&1.status == :healthy))
  end

  defp active_alarm_count(alarms) do
    Enum.count(alarms, &(!&1.acknowledged))
  end

  defp container_health(container) do
    case container.health do
      :healthy -> :healthy
      :degraded -> :caution
      _ -> :warning
    end
  end

  defp cpu_level(cpu) when cpu >= 90, do: :warning
  defp cpu_level(cpu) when cpu >= 75, do: :caution
  defp cpu_level(_), do: :normal

  defp random_trend do
    Enum.random([:rising_fast, :rising, :stable, :falling, :falling_fast])
  end

  defp generate_history(base, count) do
    Enum.map(1..count, fn _ ->
      base + (:rand.uniform(20) - 10)
    end)
  end

  defp calculate_trend(history) when length(history) < 2, do: :stable

  defp calculate_trend(history) do
    [latest | rest] = history
    avg = Enum.sum(rest) / length(rest)
    diff = latest - avg

    cond do
      diff > 5 -> :rising_fast
      diff > 1 -> :rising
      diff < -5 -> :falling_fast
      diff < -1 -> :falling
      true -> :stable
    end
  end

  defp aggregate_sparkline(nodes, field) do
    nodes
    |> Enum.map(&Map.get(&1, field, []))
    |> Enum.zip_with(fn values -> Enum.sum(values) / max(1, length(values)) end)
  end

  defp average_metric(nodes, field) do
    values = Enum.map(nodes, &Map.get(&1, field, 0))
    round(Enum.sum(values) / max(1, length(values)))
  end
end
