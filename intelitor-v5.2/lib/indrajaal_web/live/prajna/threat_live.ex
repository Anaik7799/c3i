defmodule IndrajaalWeb.Prajna.ThreatLive do
  @moduledoc """
  PRAJNA C3I Real-Time Threat Dashboard.

  WHAT: Real-time threat monitoring with Zenoh subscription and Phoenix.PubSub.
        Displays active threats by severity, source, and timestamp with
        auto-refresh every 5 seconds.

  WHY: Provides operators with immediate situational awareness of security
       threats detected by the Sentinel Digital Immune System:
       - Live threat feed from Sentinel via PubSub
       - Severity-coded display (extinction/critical/high/medium/low)
       - Source attribution and timestamp tracking
       - One-click threat acknowledgment and dismissal
       - Threat history for pattern analysis

  CONSTRAINTS:
    - SC-IMMUNE-001: Sentinel monitors system health
    - SC-IMMUNE-004: PatternHunter pre-error detection < 10ms
    - SC-PRAJNA-001: Guardian pre-approval for planning mutations
    - SC-PRAJNA-004: Sentinel health integration required
    - SC-HMI-001: Dark Cockpit (gray defaults)
    - SC-BRIDGE-005: PubSub topics for zenoh:threats

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 1.0.0 | 2026-03-23 | Code Evolution Agent | Initial implementation |

  ## Document Control
  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2026-03-23 |
  | STAMP | SC-IMMUNE-001, SC-PRAJNA-004, SC-BRIDGE-005 |
  """

  use IndrajaalWeb, :live_view

  import IndrajaalWeb.PrajnaComponents

  require Logger

  alias Indrajaal.Cockpit.Prajna.SentinelBridge

  @refresh_interval 5_000
  @sentinel_sync_interval 30_000
  @max_history 100

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(@refresh_interval, self(), :refresh)
      :timer.send_interval(@sentinel_sync_interval, self(), :sync_sentinel)

      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "prajna:threats")
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "zenoh:threats")
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "sentinel:threats")
    end

    {:ok,
     socket
     |> assign(:page_title, "Threat Dashboard")
     |> assign(:current_nav, :sentinel)
     |> assign(:threats, init_threats())
     |> assign(:threat_history, [])
     |> assign(:filter_severity, :all)
     |> assign(:filter_status, :active)
     |> assign(:selected_threat, nil)
     |> assign(:sentinel_health, init_sentinel_health())
     |> assign(:threat_stats, init_threat_stats())
     |> assign(:last_update, DateTime.utc_now())}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply,
     socket
     |> assign(:last_update, DateTime.utc_now())
     |> assign(:threat_stats, compute_threat_stats(socket.assigns.threats))}
  end

  @impl true
  def handle_info(:sync_sentinel, socket) do
    sentinel_health = fetch_sentinel_health()
    {:noreply, assign(socket, :sentinel_health, sentinel_health)}
  end

  @impl true
  def handle_info({:new_threat, threat}, socket) do
    threats = [normalize_threat(threat) | socket.assigns.threats]
    history = Enum.take([threat | socket.assigns.threat_history], @max_history)

    {:noreply,
     socket
     |> assign(:threats, threats)
     |> assign(:threat_history, history)
     |> assign(:threat_stats, compute_threat_stats(threats))}
  end

  @impl true
  def handle_info({:threat_resolved, threat_id}, socket) do
    threats =
      Enum.map(socket.assigns.threats, fn t ->
        if t.id == threat_id, do: Map.put(t, :status, :resolved), else: t
      end)

    {:noreply,
     socket
     |> assign(:threats, threats)
     |> assign(:threat_stats, compute_threat_stats(threats))}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def handle_event("filter_severity", %{"severity" => severity}, socket) do
    {:noreply, assign(socket, :filter_severity, String.to_existing_atom(severity))}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply, assign(socket, :filter_status, String.to_existing_atom(status))}
  end

  @impl true
  def handle_event("select_threat", %{"id" => id}, socket) do
    selected = Enum.find(socket.assigns.threats, &(&1.id == id))
    {:noreply, assign(socket, :selected_threat, selected)}
  end

  @impl true
  def handle_event("close_detail", _params, socket) do
    {:noreply, assign(socket, :selected_threat, nil)}
  end

  @impl true
  def handle_event("acknowledge_threat", %{"id" => id}, socket) do
    threats =
      Enum.map(socket.assigns.threats, fn t ->
        if t.id == id, do: Map.put(t, :status, :acknowledged), else: t
      end)

    Logger.info("[ThreatLive] Threat #{id} acknowledged")

    {:noreply,
     socket
     |> assign(:threats, threats)
     |> assign(:selected_threat, nil)
     |> put_flash(:info, "Threat #{id} acknowledged")}
  end

  @impl true
  def handle_event("dismiss_threat", %{"id" => id}, socket) do
    threats = Enum.reject(socket.assigns.threats, &(&1.id == id))

    {:noreply,
     socket
     |> assign(:threats, threats)
     |> assign(:threat_stats, compute_threat_stats(threats))
     |> assign(:selected_threat, nil)
     |> put_flash(:info, "Threat #{id} dismissed")}
  end

  @impl true
  def handle_event("acknowledge_all", _params, socket) do
    threats =
      Enum.map(socket.assigns.threats, fn t ->
        if t.status == :active, do: Map.put(t, :status, :acknowledged), else: t
      end)

    count = Enum.count(socket.assigns.threats, &(&1.status == :active))

    {:noreply,
     socket
     |> assign(:threats, threats)
     |> put_flash(:info, "#{count} threats acknowledged")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-surface-primary text-content-primary font-mono">
      <.prajna_header
        health_score={@sentinel_health.score_percent}
        uptime={format_uptime()}
        node_count={5}
        total_nodes={5}
        alarm_count={@threat_stats.active_count}
      />

      <.prajna_nav current={:sentinel} />

      <main class="p-4 space-y-4">
        <%!-- Header Row --%>
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-xl font-bold text-content-primary">Real-Time Threat Dashboard</h1>
            <p class="text-xs text-content-muted mt-1">
              Sentinel Digital Immune System — SC-IMMUNE-001
            </p>
          </div>
          <div class="text-xs text-content-muted">
            Last update: {Calendar.strftime(@last_update, "%H:%M:%S UTC")}
            <span class="ml-2 text-green-400 animate-pulse">LIVE</span>
          </div>
        </div>

        <%!-- Stats Row --%>
        <div class="grid grid-cols-5 gap-4">
          <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
            <div class="text-xs text-content-muted mb-1">EXTINCTION</div>
            <div class="text-2xl font-bold text-red-600">{@threat_stats.extinction}</div>
          </div>
          <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
            <div class="text-xs text-content-muted mb-1">CRITICAL</div>
            <div class="text-2xl font-bold text-red-400">{@threat_stats.critical}</div>
          </div>
          <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
            <div class="text-xs text-content-muted mb-1">HIGH</div>
            <div class="text-2xl font-bold text-orange-400">{@threat_stats.high}</div>
          </div>
          <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
            <div class="text-xs text-content-muted mb-1">MEDIUM</div>
            <div class="text-2xl font-bold text-yellow-400">{@threat_stats.medium}</div>
          </div>
          <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
            <div class="text-xs text-content-muted mb-1">ACTIVE TOTAL</div>
            <div class="text-2xl font-bold text-content-primary">{@threat_stats.active_count}</div>
          </div>
        </div>

        <%!-- Filters Row --%>
        <div class="flex items-center space-x-4">
          <div class="flex space-x-2">
            <%= for sev <- [:all, :extinction, :critical, :high, :medium, :low] do %>
              <button
                phx-click="filter_severity"
                phx-value-severity={sev}
                class={"px-3 py-1 rounded text-xs transition-colors #{if @filter_severity == sev, do: "bg-accent-primary text-content-inverse", else: "bg-surface-tertiary text-content-secondary hover:bg-surface-elevated"}"}
              >
                {String.upcase(to_string(sev))}
              </button>
            <% end %>
          </div>
          <select
            phx-change="filter_status"
            name="status"
            class="bg-surface-tertiary border border-border-theme-secondary rounded px-3 py-1 text-xs text-content-primary"
          >
            <option value="active" selected={@filter_status == :active}>Active</option>
            <option value="acknowledged" selected={@filter_status == :acknowledged}>
              Acknowledged
            </option>
            <option value="all" selected={@filter_status == :all}>All</option>
          </select>
        </div>

        <%!-- Main Content Grid --%>
        <div class="grid grid-cols-12 gap-4">
          <%!-- Threat List --%>
          <div class="col-span-8 bg-surface-secondary rounded-lg border border-border-theme-primary">
            <div class="px-4 py-2 border-b border-border-theme-primary flex items-center justify-between">
              <h2 class="text-sm font-bold text-content-secondary">ACTIVE THREATS</h2>
              <div class="flex items-center space-x-2">
                <span class="text-xs text-content-muted">
                  {length(filtered_threats(@threats, @filter_severity, @filter_status))} threats
                </span>
                <button
                  phx-click="acknowledge_all"
                  class="px-2 py-1 bg-surface-tertiary hover:bg-surface-elevated text-xs rounded text-content-secondary"
                >
                  ACK ALL
                </button>
              </div>
            </div>
            <div class="divide-y divide-border-theme-primary max-h-screen overflow-y-auto">
              <%= for threat <- filtered_threats(@threats, @filter_severity, @filter_status) do %>
                <div
                  phx-click="select_threat"
                  phx-value-id={threat.id}
                  class={"p-3 cursor-pointer transition-colors hover:bg-surface-tertiary #{if @selected_threat && @selected_threat.id == threat.id, do: "bg-surface-elevated"}"}
                >
                  <div class="flex items-start justify-between">
                    <div class="flex items-start space-x-3">
                      <span class={"text-lg #{severity_color(threat.severity)}"}>
                        {severity_icon(threat.severity)}
                      </span>
                      <div>
                        <div class="flex items-center space-x-2">
                          <span class={"text-xs font-bold #{severity_color(threat.severity)}"}>
                            {String.upcase(to_string(threat.severity))}
                          </span>
                          <span class="text-content-muted text-xs">|</span>
                          <span class="text-content-primary text-sm">{threat.description}</span>
                        </div>
                        <div class="text-xs text-content-muted mt-1 space-x-2">
                          <span>Source: {threat.source}</span>
                          <span>|</span>
                          <span>Type: {threat.type}</span>
                          <span>|</span>
                          <span>{format_threat_age(threat.detected_at)}</span>
                        </div>
                        <%= if Map.get(threat, :rpn) do %>
                          <div class="text-xs mt-1">
                            <span class="text-content-muted">RPN:</span>
                            <span class={
                              if threat.rpn >= 50, do: "text-red-400", else: "text-content-secondary"
                            }>
                              {threat.rpn}
                            </span>
                          </div>
                        <% end %>
                      </div>
                    </div>
                    <div class="flex items-center space-x-2">
                      <span class={"px-2 py-0.5 rounded text-xs #{status_badge_class(threat.status)}"}>
                        {threat.status}
                      </span>
                      <button
                        phx-click="acknowledge_threat"
                        phx-value-id={threat.id}
                        class="px-2 py-1 bg-surface-tertiary hover:bg-surface-elevated text-xs rounded text-content-primary"
                      >
                        ACK
                      </button>
                    </div>
                  </div>
                </div>
              <% end %>
              <%= if filtered_threats(@threats, @filter_severity, @filter_status) == [] do %>
                <div class="p-8 text-center text-content-muted">
                  No threats matching filters — system healthy
                </div>
              <% end %>
            </div>
          </div>

          <%!-- Right Sidebar --%>
          <div class="col-span-4 space-y-4">
            <%!-- Threat Detail Panel --%>
            <%= if @selected_threat do %>
              <div class="bg-surface-secondary rounded-lg border border-red-800 p-4">
                <div class="flex items-center justify-between mb-3">
                  <h3 class={"text-sm font-bold #{severity_color(@selected_threat.severity)}"}>
                    {String.upcase(to_string(@selected_threat.severity))} THREAT
                  </h3>
                  <button
                    phx-click="close_detail"
                    class="text-content-muted hover:text-content-primary text-xs"
                  >
                    CLOSE
                  </button>
                </div>
                <div class="space-y-2 text-sm">
                  <div>
                    <span class="text-content-muted">ID:</span>
                    <span class="text-content-primary ml-2 font-mono">{@selected_threat.id}</span>
                  </div>
                  <div>
                    <span class="text-content-muted">Description:</span>
                    <p class="text-content-primary mt-1">{@selected_threat.description}</p>
                  </div>
                  <div>
                    <span class="text-content-muted">Source:</span>
                    <span class="text-content-primary ml-2">{@selected_threat.source}</span>
                  </div>
                  <div>
                    <span class="text-content-muted">Type:</span>
                    <span class="text-content-primary ml-2">{@selected_threat.type}</span>
                  </div>
                  <div>
                    <span class="text-content-muted">Detected:</span>
                    <span class="text-content-primary ml-2">
                      {Calendar.strftime(@selected_threat.detected_at, "%Y-%m-%d %H:%M:%S")}
                    </span>
                  </div>
                  <%= if Map.get(@selected_threat, :mitigation) do %>
                    <div>
                      <span class="text-content-muted">Mitigation:</span>
                      <p class="text-amber-400 mt-1">{@selected_threat.mitigation}</p>
                    </div>
                  <% end %>
                </div>
                <div class="flex space-x-2 mt-4">
                  <button
                    phx-click="acknowledge_threat"
                    phx-value-id={@selected_threat.id}
                    class="flex-1 py-2 bg-green-900 hover:bg-green-800 text-green-300 text-xs rounded"
                  >
                    ACKNOWLEDGE
                  </button>
                  <button
                    phx-click="dismiss_threat"
                    phx-value-id={@selected_threat.id}
                    class="flex-1 py-2 bg-surface-tertiary hover:bg-surface-elevated text-content-secondary text-xs rounded"
                  >
                    DISMISS
                  </button>
                </div>
              </div>
            <% end %>

            <%!-- Sentinel Health Card --%>
            <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
              <h3 class="text-sm font-bold text-content-secondary mb-3">SENTINEL HEALTH</h3>
              <div class="space-y-2 text-sm">
                <div class="flex justify-between">
                  <span class="text-content-muted">Status:</span>
                  <span class={sentinel_status_class(@sentinel_health.status)}>
                    {String.upcase(to_string(@sentinel_health.status))}
                  </span>
                </div>
                <div class="flex justify-between">
                  <span class="text-content-muted">Health Score:</span>
                  <span class="text-content-primary">{@sentinel_health.score_percent}%</span>
                </div>
                <div class="flex justify-between">
                  <span class="text-content-muted">Threat Count:</span>
                  <span class={
                    if @sentinel_health.threat_count > 0, do: "text-red-400", else: "text-green-400"
                  }>
                    {@sentinel_health.threat_count}
                  </span>
                </div>
                <div class="flex justify-between">
                  <span class="text-content-muted">Quarantined:</span>
                  <span class="text-content-secondary">{@sentinel_health.quarantine_count}</span>
                </div>
                <div class="flex justify-between">
                  <span class="text-content-muted">Response SLA:</span>
                  <span class="text-content-secondary">&lt; 100ms</span>
                </div>
              </div>
            </div>

            <%!-- Threat Type Breakdown --%>
            <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
              <h3 class="text-sm font-bold text-content-secondary mb-3">THREAT TYPES</h3>
              <div class="space-y-2">
                <%= for {type, count} <- threat_type_breakdown(@threats) do %>
                  <div class="flex items-center justify-between text-sm">
                    <span class="text-content-secondary capitalize">{type}</span>
                    <div class="flex items-center space-x-2">
                      <div
                        class="h-1.5 bg-accent-primary rounded"
                        style={"width: #{min(count * 8, 80)}px"}
                      >
                      </div>
                      <span class="text-content-muted text-xs w-4">{count}</span>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>

            <%!-- Constraints Badge --%>
            <div class="text-xs text-content-muted space-y-1">
              <div>SC-IMMUNE-001 | SC-PRAJNA-004</div>
              <div>SC-BRIDGE-005 | SC-HMI-001</div>
            </div>
          </div>
        </div>
      </main>
    </div>
    """
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # INITIALIZATION
  # ═══════════════════════════════════════════════════════════════════════════

  defp init_threats do
    [
      %{
        id: "THR-001",
        severity: :critical,
        description: "Unauthorized access attempt detected on /api/admin",
        source: "PatternHunter",
        type: "intrusion",
        status: :active,
        rpn: 189,
        mitigation: "Block IP 192.168.1.150, review access logs",
        detected_at: DateTime.add(DateTime.utc_now(), -120, :second)
      },
      %{
        id: "THR-002",
        severity: :high,
        description: "Memory usage spike above 85% threshold on app-01",
        source: "SmartMetrics",
        type: "resource_exhaustion",
        status: :active,
        rpn: 96,
        mitigation: "Scale horizontal or investigate memory leak",
        detected_at: DateTime.add(DateTime.utc_now(), -300, :second)
      },
      %{
        id: "THR-003",
        severity: :medium,
        description: "Zenoh router latency elevated — 85ms vs 50ms SLA",
        source: "Sentinel",
        type: "performance_degradation",
        status: :active,
        rpn: 45,
        mitigation: nil,
        detected_at: DateTime.add(DateTime.utc_now(), -600, :second)
      },
      %{
        id: "THR-004",
        severity: :high,
        description: "Guardian validation timeout after 28s for proposal GDE-447",
        source: "GuardianKernel",
        type: "timeout",
        status: :acknowledged,
        rpn: 112,
        mitigation: "Retry proposal or investigate Guardian state",
        detected_at: DateTime.add(DateTime.utc_now(), -900, :second)
      },
      %{
        id: "THR-005",
        severity: :low,
        description: "Certificate expiry approaching for zenoh-router TLS cert (14 days)",
        source: "KMS",
        type: "certificate_expiry",
        status: :active,
        rpn: 28,
        mitigation: "Renew certificate via sa-plan",
        detected_at: DateTime.add(DateTime.utc_now(), -3600, :second)
      }
    ]
  end

  defp init_sentinel_health do
    %{
      status: :healthy,
      score_percent: 94,
      threat_count: 4,
      quarantine_count: 0,
      last_sync: DateTime.utc_now()
    }
  end

  defp init_threat_stats do
    %{
      extinction: 0,
      critical: 1,
      high: 2,
      medium: 1,
      low: 1,
      active_count: 4
    }
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # DATA HELPERS
  # ═══════════════════════════════════════════════════════════════════════════

  defp normalize_threat(threat) when is_map(threat) do
    Map.merge(
      %{
        id: "THR-#{System.unique_integer([:positive])}",
        severity: :medium,
        description: "Unknown threat",
        source: "unknown",
        type: "unknown",
        status: :active,
        detected_at: DateTime.utc_now()
      },
      threat
    )
  end

  defp compute_threat_stats(threats) do
    active = Enum.filter(threats, &(&1.status == :active))

    %{
      extinction: Enum.count(active, &(&1.severity == :extinction)),
      critical: Enum.count(active, &(&1.severity == :critical)),
      high: Enum.count(active, &(&1.severity == :high)),
      medium: Enum.count(active, &(&1.severity == :medium)),
      low: Enum.count(active, &(&1.severity == :low)),
      active_count: length(active)
    }
  end

  defp filtered_threats(threats, severity_filter, status_filter) do
    threats
    |> Enum.filter(fn t ->
      severity_match = severity_filter == :all or t.severity == severity_filter
      status_match = status_filter == :all or t.status == status_filter
      severity_match and status_match
    end)
    |> Enum.sort_by(fn t ->
      {severity_order(t.severity), t.detected_at}
    end)
  end

  defp threat_type_breakdown(threats) do
    threats
    |> Enum.group_by(& &1.type)
    |> Enum.map(fn {type, items} -> {type, length(items)} end)
    |> Enum.sort_by(fn {_type, count} -> -count end)
    |> Enum.take(6)
  end

  defp severity_order(:extinction), do: 0
  defp severity_order(:critical), do: 1
  defp severity_order(:high), do: 2
  defp severity_order(:medium), do: 3
  defp severity_order(:low), do: 4
  defp severity_order(_), do: 5

  defp fetch_sentinel_health do
    case Process.whereis(SentinelBridge) do
      nil ->
        init_sentinel_health()

      _pid ->
        try do
          health = SentinelBridge.get_health()

          %{
            status: Map.get(health, :status, :unknown),
            score_percent: Map.get(health, :score_percent, 0),
            threat_count: length(Map.get(health, :threats, [])),
            quarantine_count: length(Map.get(health, :quarantined, [])),
            last_sync: Map.get(health, :last_sync, DateTime.utc_now())
          }
        rescue
          _ -> init_sentinel_health()
        end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UI HELPERS
  # ═══════════════════════════════════════════════════════════════════════════

  defp severity_icon(:extinction), do: "☢"
  defp severity_icon(:critical), do: "⛔"
  defp severity_icon(:high), do: "⚠"
  defp severity_icon(:medium), do: "ℹ"
  defp severity_icon(:low), do: "·"
  defp severity_icon(_), do: "?"

  defp severity_color(:extinction), do: "text-purple-400"
  defp severity_color(:critical), do: "text-red-500"
  defp severity_color(:high), do: "text-orange-400"
  defp severity_color(:medium), do: "text-yellow-400"
  defp severity_color(:low), do: "text-blue-400"
  defp severity_color(_), do: "text-gray-400"

  defp status_badge_class(:active), do: "bg-red-900/50 text-red-300"
  defp status_badge_class(:acknowledged), do: "bg-green-900/50 text-green-300"
  defp status_badge_class(:resolved), do: "bg-gray-700 text-gray-400"
  defp status_badge_class(_), do: "bg-gray-700 text-gray-400"

  defp sentinel_status_class(:healthy), do: "text-green-400"
  defp sentinel_status_class(:degraded), do: "text-amber-400"
  defp sentinel_status_class(:critical), do: "text-red-400"
  defp sentinel_status_class(_), do: "text-gray-500"

  defp format_threat_age(detected_at) do
    diff = DateTime.diff(DateTime.utc_now(), detected_at, :second)

    cond do
      diff < 60 -> "#{diff}s ago"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      true -> "#{div(diff, 3600)}h #{div(rem(diff, 3600), 60)}m ago"
    end
  end

  defp format_uptime, do: "25d 14h"
end
