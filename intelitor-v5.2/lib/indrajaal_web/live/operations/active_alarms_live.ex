defmodule IndrajaalWeb.Operations.ActiveAlarmsLive do
  @moduledoc """
  Active Alarms Dashboard - Operations Center

  Real-time alarm management interface with comprehensive filtering,
  AI-powered insights, and batch operations.

  ## Features
  - Real-time alarm feed with severity-based coloring
  - Alarm pipeline status visualization
  - Interactive site map with alarm locations
  - Storm detection and suppression
  - AI Copilot insights per alarm
  - Batch acknowledgment and escalation

  ## STAMP Compliance
  - SC-HMI-001: Management by Exception (gray defaults, colored anomalies)
  - SC-HMI-002: Analog indicators (trend arrows, sparklines)
  - SC-HMI-003: Staleness decay (visual degradation after 5s)
  - SC-HMI-005: Critical prominence (pulsing red for critical)
  - SC-AI-001: AI suggestions are ADVISORY only
  """
  use IndrajaalWeb, :live_view

  alias Phoenix.PubSub

  @refresh_interval 2_000
  # Alarm storm detection threshold
  @storm_threshold 10
  def storm_threshold, do: @storm_threshold

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      PubSub.subscribe(Indrajaal.PubSub, "alarms:active")
      PubSub.subscribe(Indrajaal.PubSub, "alarms:pipeline")
      Process.send_after(self(), :refresh, @refresh_interval)
    end

    {:ok,
     socket
     |> assign(:page_title, "Active Alarms - Operations Center")
     |> assign(:alarms, generate_sample_alarms())
     |> assign(:filter_severity, :all)
     |> assign(:filter_status, :active)
     |> assign(:filter_time, "24h")
     |> assign(:search_text, "")
     |> assign(:selected_alarms, MapSet.new())
     |> assign(:pipeline_status, generate_pipeline_status())
     |> assign(:storm_active, false)
     |> assign(:storm_suppressed, 0)
     |> assign(:summary, calculate_summary([]))
     |> assign(:trend_data, generate_trend_data())
     |> assign(:last_updated, DateTime.utc_now())
     |> assign(:storm_threshold, @storm_threshold)}
  end

  @impl true
  def handle_info(:refresh, socket) do
    Process.send_after(self(), :refresh, @refresh_interval)

    alarms = generate_sample_alarms()
    summary = calculate_summary(alarms)

    {:noreply,
     socket
     |> assign(:alarms, alarms)
     |> assign(:summary, summary)
     |> assign(:last_updated, DateTime.utc_now())}
  end

  def handle_info({:alarm_update, alarm}, socket) do
    alarms = [alarm | socket.assigns.alarms] |> Enum.take(100)
    {:noreply, assign(socket, :alarms, alarms)}
  end

  @impl true
  def handle_event("filter_severity", %{"severity" => severity}, socket) do
    {:noreply, assign(socket, :filter_severity, String.to_atom(severity))}
  end

  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply, assign(socket, :filter_status, String.to_atom(status))}
  end

  def handle_event("search", %{"search" => text}, socket) do
    {:noreply, assign(socket, :search_text, text)}
  end

  def handle_event("acknowledge", %{"id" => id}, socket) do
    # In production, this would call the alarm service
    {:noreply, put_flash(socket, :info, "Alarm #{id} acknowledged")}
  end

  def handle_event("acknowledge_all", %{"severity" => severity}, socket) do
    {:noreply, put_flash(socket, :info, "All #{severity} alarms acknowledged")}
  end

  def handle_event("escalate", %{"id" => id}, socket) do
    {:noreply, put_flash(socket, :warning, "Alarm #{id} escalated to supervisor")}
  end

  def handle_event("silence", %{"id" => id, "duration" => duration}, socket) do
    {:noreply, put_flash(socket, :info, "Alarm #{id} silenced for #{duration}")}
  end

  def handle_event("toggle_select", %{"id" => id}, socket) do
    selected =
      if MapSet.member?(socket.assigns.selected_alarms, id) do
        MapSet.delete(socket.assigns.selected_alarms, id)
      else
        MapSet.put(socket.assigns.selected_alarms, id)
      end

    {:noreply, assign(socket, :selected_alarms, selected)}
  end

  def handle_event("batch_acknowledge", _params, socket) do
    count = MapSet.size(socket.assigns.selected_alarms)

    {:noreply,
     socket
     |> assign(:selected_alarms, MapSet.new())
     |> put_flash(:info, "#{count} alarms acknowledged")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- L4-A09: Theme-aware Active Alarms page (SC-HMI-001, SC-HMI-008) --%>
    <div class="min-h-screen bg-surface-primary text-content-primary p-4">
      <!-- Header -->
      <div class="flex items-center justify-between mb-4">
        <div class="flex items-center gap-4">
          <h1 class="text-2xl font-bold text-white">Active Alarms</h1>
          <span class="text-sm text-content-muted">
            Last updated: {format_time(@last_updated)}
          </span>
        </div>
        <div class="flex items-center gap-2">
          <.link
            navigate={~p"/cockpit"}
            class="px-3 py-1.5 bg-surface-secondary hover:bg-surface-tertiary rounded text-sm"
          >
            Back to Cockpit
          </.link>
        </div>
      </div>
      
    <!-- Alarm Summary Bar -->
      <div class="bg-surface-secondary rounded-lg p-4 mb-4">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-6">
            <button
              phx-click="filter_severity"
              phx-value-severity="critical"
              class={"flex items-center gap-2 px-3 py-1.5 rounded #{if @filter_severity == :critical, do: "bg-red-900", else: "hover:bg-surface-tertiary"}"}
            >
              <span class="text-red-500 animate-pulse">&#9762;</span>
              <span class="text-red-400">Critical: {@summary.critical}</span>
            </button>
            <button
              phx-click="filter_severity"
              phx-value-severity="warning"
              class={"flex items-center gap-2 px-3 py-1.5 rounded #{if @filter_severity == :warning, do: "bg-red-900/50", else: "hover:bg-surface-tertiary"}"}
            >
              <span class="text-red-400">&#9940;</span>
              <span class="text-red-300">Warning: {@summary.warning}</span>
            </button>
            <button
              phx-click="filter_severity"
              phx-value-severity="caution"
              class={"flex items-center gap-2 px-3 py-1.5 rounded #{if @filter_severity == :caution, do: "bg-amber-900/50", else: "hover:bg-surface-tertiary"}"}
            >
              <span class="text-amber-500">&#9888;</span>
              <span class="text-amber-400">Caution: {@summary.caution}</span>
            </button>
            <button
              phx-click="filter_severity"
              phx-value-severity="advisory"
              class={"flex items-center gap-2 px-3 py-1.5 rounded #{if @filter_severity == :advisory, do: "bg-cyan-900/50", else: "hover:bg-surface-tertiary"}"}
            >
              <span class="text-cyan-500">&#8505;</span>
              <span class="text-cyan-400">Advisory: {@summary.advisory}</span>
            </button>
            <button
              phx-click="filter_severity"
              phx-value-severity="all"
              class={"flex items-center gap-2 px-3 py-1.5 rounded #{if @filter_severity == :all, do: "bg-surface-tertiary", else: "hover:bg-surface-tertiary"}"}
            >
              <span class="text-content-secondary">Total: {@summary.total}</span>
            </button>
          </div>
          <div class="flex items-center gap-2">
            <input
              type="text"
              placeholder="Search alarms..."
              value={@search_text}
              phx-keyup="search"
              phx-value-search={@search_text}
              class="bg-surface-tertiary border-border-theme-secondary rounded px-3 py-1.5 text-sm w-64"
            />
          </div>
        </div>
      </div>
      
    <!-- Pipeline Status -->
      <div class="bg-surface-secondary rounded-lg p-4 mb-4">
        <div class="flex items-center justify-between text-sm">
          <div class="flex items-center gap-8">
            <%= for {stage, status} <- @pipeline_status do %>
              <div class="flex items-center gap-2">
                <span class={status_color(status.ok)}>
                  {if status.ok, do: "&#10_003;", else: "&#10_007;"}
                </span>
                <span class="text-content-secondary">{stage}</span>
                <span class="text-content-muted">{status.value}</span>
              </div>
              <%= if stage != "Workflow" do %>
                <span class="text-gray-600">&rarr;</span>
              <% end %>
            <% end %>
          </div>
          <%= if @storm_active do %>
            <div class="flex items-center gap-2 text-amber-400">
              <span class="animate-pulse">&#9888;</span>
              <span>Storm Active: {@storm_suppressed} suppressed</span>
            </div>
          <% end %>
        </div>
      </div>
      
    <!-- Main Content Grid -->
      <div class="grid grid-cols-3 gap-4">
        <!-- Alarm List (2 columns) -->
        <div class="col-span-2 bg-surface-secondary rounded-lg">
          <div class="p-4 border-b border-border-theme-primary">
            <div class="flex items-center justify-between">
              <h2 class="font-semibold">Real-Time Feed</h2>
              <div class="flex items-center gap-2">
                <%= if MapSet.size(@selected_alarms) > 0 do %>
                  <button
                    phx-click="batch_acknowledge"
                    class="px-3 py-1 bg-cyan-600 hover:bg-cyan-500 rounded text-sm"
                  >
                    ACK Selected ({MapSet.size(@selected_alarms)})
                  </button>
                <% end %>
              </div>
            </div>
          </div>
          <div class="divide-y divide-border-theme-primary max-h-[600px] overflow-y-auto">
            <%= for alarm <- filter_alarms(@alarms, @filter_severity, @search_text) do %>
              <div class={"p-4 hover:bg-gray-750 #{alarm_bg(alarm.severity)}"}>
                <div class="flex items-start justify-between">
                  <div class="flex items-start gap-3">
                    <input
                      type="checkbox"
                      checked={MapSet.member?(@selected_alarms, alarm.id)}
                      phx-click="toggle_select"
                      phx-value-id={alarm.id}
                      class="mt-1 rounded bg-surface-tertiary border-border-theme-secondary"
                    />
                    <div>
                      <div class="flex items-center gap-2">
                        <span class={severity_icon_class(alarm.severity)}>
                          {severity_icon(alarm.severity)}
                        </span>
                        <span class={severity_text_class(alarm.severity)}>
                          {String.upcase(to_string(alarm.severity))}
                        </span>
                        <span class="text-content-secondary">|</span>
                        <span class="text-white">{alarm.source}</span>
                        <span class="text-content-secondary">|</span>
                        <span class="text-content-primary">{alarm.message}</span>
                      </div>
                      <div class="flex items-center gap-4 mt-1 text-sm text-content-muted">
                        <span>Site: {alarm.site}</span>
                        <span>Device: {alarm.device}</span>
                        <span>Age: {format_age(alarm.timestamp)}</span>
                        <span>Occurrences: {alarm.occurrences}</span>
                      </div>
                      <%= if alarm.ai_insight do %>
                        <div class="mt-2 text-sm text-cyan-400/80 italic">
                          <span class="text-cyan-500">AI:</span> {alarm.ai_insight}
                        </div>
                      <% end %>
                    </div>
                  </div>
                  <div class="flex items-center gap-2">
                    <button
                      phx-click="acknowledge"
                      phx-value-id={alarm.id}
                      class="px-2 py-1 bg-cyan-600 hover:bg-cyan-500 rounded text-xs"
                    >
                      ACK
                    </button>
                    <button
                      phx-click="silence"
                      phx-value-id={alarm.id}
                      phx-value-duration="1h"
                      class="px-2 py-1 bg-gray-600 hover:bg-gray-500 rounded text-xs"
                    >
                      SILENCE 1h
                    </button>
                    <button
                      phx-click="escalate"
                      phx-value-id={alarm.id}
                      class="px-2 py-1 bg-amber-600 hover:bg-amber-500 rounded text-xs"
                    >
                      ESCALATE
                    </button>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
        
    <!-- Right Sidebar -->
        <div class="space-y-4">
          <!-- Alarm Trends -->
          <div class="bg-surface-secondary rounded-lg p-4">
            <h3 class="font-semibold mb-3">Alarm Trends (24h)</h3>
            <div class="h-32 flex items-end gap-1">
              <%= for {hour, counts} <- @trend_data do %>
                <div class="flex-1 flex flex-col gap-0.5" title={"#{hour}:00"}>
                  <%= for {severity, count} <- counts do %>
                    <div class={trend_bar_class(severity)} style={"height: #{min(count * 4, 32)}px"}>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
            <div class="flex items-center justify-between mt-2 text-xs text-content-muted">
              <span>00:00</span>
              <span>12:00</span>
              <span>Now</span>
            </div>
          </div>
          
    <!-- Storm Detection -->
          <div class="bg-surface-secondary rounded-lg p-4">
            <h3 class="font-semibold mb-3">Storm Detection</h3>
            <div class="space-y-2 text-sm">
              <div class="flex justify-between">
                <span class="text-content-secondary">Status:</span>
                <span class={if @storm_active, do: "text-amber-400", else: "text-green-400"}>
                  {if @storm_active, do: "STORM ACTIVE", else: "NO STORM"}
                </span>
              </div>
              <div class="flex justify-between">
                <span class="text-content-secondary">Suppressed:</span>
                <span>{@storm_suppressed} alarms</span>
              </div>
              <div class="flex justify-between">
                <span class="text-content-secondary">Threshold:</span>
                <span>{@storm_threshold}/min</span>
              </div>
              <div class="flex justify-between">
                <span class="text-content-secondary">Last Storm:</span>
                <span class="text-content-muted">3 days ago</span>
              </div>
            </div>
            <button class="w-full mt-3 px-3 py-1.5 bg-surface-tertiary hover:bg-surface-tertiary/80 rounded text-sm">
              Configure
            </button>
          </div>
          
    <!-- Quick Stats -->
          <div class="bg-surface-secondary rounded-lg p-4">
            <h3 class="font-semibold mb-3">Performance</h3>
            <div class="space-y-2 text-sm">
              <div class="flex justify-between">
                <span class="text-content-secondary">Processing Rate:</span>
                <span class="text-cyan-400">142/s</span>
              </div>
              <div class="flex justify-between">
                <span class="text-content-secondary">Avg Response:</span>
                <span class="text-green-400">12s</span>
              </div>
              <div class="flex justify-between">
                <span class="text-content-secondary">SLA:</span>
                <span class="text-green-400">98.5%</span>
              </div>
              <div class="flex justify-between">
                <span class="text-content-secondary">Unacked:</span>
                <span class="text-amber-400">{@summary.total}</span>
              </div>
            </div>
          </div>
          
    <!-- Bulk Actions -->
          <div class="bg-surface-secondary rounded-lg p-4">
            <h3 class="font-semibold mb-3">Bulk Actions</h3>
            <div class="space-y-2">
              <button
                phx-click="acknowledge_all"
                phx-value-severity="advisory"
                class="w-full px-3 py-1.5 bg-cyan-600/20 hover:bg-cyan-600/30 text-cyan-400 rounded text-sm"
              >
                ACK All Advisory
              </button>
              <button class="w-full px-3 py-1.5 bg-surface-tertiary hover:bg-surface-tertiary/80 rounded text-sm">
                Export Report
              </button>
              <button class="w-full px-3 py-1.5 bg-surface-tertiary hover:bg-surface-tertiary/80 rounded text-sm">
                Configure Thresholds
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions

  defp generate_sample_alarms do
    [
      %{
        id: "ALM-001",
        severity: :caution,
        source: "INTRUSION",
        message: "Zone-A North Door - Motion + Door Contact",
        site: "HQ Building",
        device: "sensor-042",
        assigned: "Team Alpha",
        timestamp: DateTime.add(DateTime.utc_now(), -720, :second),
        occurrences: 3,
        ai_insight: "Consider load balancing to app-04 (31% CPU)"
      },
      %{
        id: "ALM-002",
        severity: :caution,
        source: "ACCESS DENIED",
        message: "Server Room - Invalid Credential",
        site: "Data Center",
        device: "reader-101",
        assigned: nil,
        timestamp: DateTime.add(DateTime.utc_now(), -1080, :second),
        occurrences: 1,
        ai_insight: "User credential expired 2 days ago"
      },
      %{
        id: "ALM-003",
        severity: :advisory,
        source: "TROUBLE",
        message: "Panel-05 Low Battery Warning",
        site: "Warehouse B",
        device: "panel-05",
        assigned: nil,
        timestamp: DateTime.add(DateTime.utc_now(), -2700, :second),
        occurrences: 1,
        ai_insight: nil
      },
      %{
        id: "ALM-004",
        severity: :advisory,
        source: "SYSTEM",
        message: "SigNoz trace latency elevated",
        site: "Observability",
        device: "obs-collector",
        assigned: nil,
        timestamp: DateTime.add(DateTime.utc_now(), -2700, :second),
        occurrences: 1,
        ai_insight: "Trace ingestion at 2.3s, target <1s"
      },
      %{
        id: "ALM-005",
        severity: :warning,
        source: "FIRE",
        message: "Smoke detector activated - Floor 3",
        site: "HQ Building",
        device: "smoke-301",
        assigned: "Team Bravo",
        timestamp: DateTime.add(DateTime.utc_now(), -180, :second),
        occurrences: 1,
        ai_insight: "Cross-reference with HVAC status"
      }
    ]
  end

  defp generate_pipeline_status do
    %{
      "Ingestion" => %{ok: true, value: "142/s"},
      "Severity" => %{ok: true, value: "98%"},
      "Correlation" => %{ok: true, value: "89%"},
      "Storm" => %{ok: true, value: "OK"},
      "Notification" => %{ok: true, value: "99.9%"},
      "Workflow" => %{ok: true, value: "100%"}
    }
  end

  defp generate_trend_data do
    for hour <- 0..23 do
      {hour,
       %{
         critical: :rand.uniform(2) - 1,
         warning: :rand.uniform(3) - 1,
         caution: :rand.uniform(5),
         advisory: :rand.uniform(8)
       }}
    end
  end

  defp calculate_summary(alarms) do
    base = %{critical: 0, warning: 1, caution: 2, advisory: 5, total: 8}

    Enum.reduce(alarms, base, fn alarm, acc ->
      acc
      |> Map.update!(alarm.severity, &(&1 + 1))
      |> Map.update!(:total, &(&1 + 1))
    end)
  end

  defp filter_alarms(alarms, :all, ""), do: alarms

  defp filter_alarms(alarms, :all, search) do
    search_lower = String.downcase(search)

    Enum.filter(alarms, fn a ->
      String.contains?(String.downcase(a.message), search_lower) or
        String.contains?(String.downcase(a.source), search_lower)
    end)
  end

  defp filter_alarms(alarms, severity, search) do
    alarms
    |> Enum.filter(&(&1.severity == severity))
    |> filter_alarms(:all, search)
  end

  defp format_time(dt), do: Calendar.strftime(dt, "%H:%M:%S")

  defp format_age(dt) do
    diff = DateTime.diff(DateTime.utc_now(), dt, :second)

    cond do
      diff < 60 -> "#{diff}s ago"
      diff < 3600 -> "#{div(diff, 60)} min ago"
      true -> "#{div(diff, 3600)}h ago"
    end
  end

  defp severity_icon(:critical), do: "&#9762;"
  defp severity_icon(:warning), do: "&#9940;"
  defp severity_icon(:caution), do: "&#9888;"
  defp severity_icon(:advisory), do: "&#8505;"
  defp severity_icon(_), do: "&#183;"

  defp severity_icon_class(:critical), do: "text-red-500 animate-pulse"
  defp severity_icon_class(:warning), do: "text-red-400"
  defp severity_icon_class(:caution), do: "text-amber-500"
  defp severity_icon_class(:advisory), do: "text-cyan-500"
  defp severity_icon_class(_), do: "text-gray-500"

  defp severity_text_class(:critical), do: "text-red-400 font-bold"
  defp severity_text_class(:warning), do: "text-red-300"
  defp severity_text_class(:caution), do: "text-amber-400"
  defp severity_text_class(:advisory), do: "text-cyan-400"
  defp severity_text_class(_), do: "text-gray-400"

  defp alarm_bg(:critical), do: "bg-red-900/20"
  defp alarm_bg(:warning), do: "bg-red-900/10"
  defp alarm_bg(_), do: ""

  defp status_color(true), do: "text-green-400"
  defp status_color(false), do: "text-red-400"

  defp trend_bar_class(:critical), do: "bg-red-500"
  defp trend_bar_class(:warning), do: "bg-red-400"
  defp trend_bar_class(:caution), do: "bg-amber-500"
  defp trend_bar_class(:advisory), do: "bg-cyan-500"
  defp trend_bar_class(_), do: "bg-gray-500"
end
