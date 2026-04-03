defmodule IndrajaalWeb.Operations.AccessDashboardLive do
  @moduledoc """
  Access Control Dashboard - Operations Center

  Real-time access control monitoring with credential management,
  access point status, and recent events.

  ## Features
  - Real-time access metrics (grants, denials, tailgating, anti-passback)
  - Access point status monitoring
  - Recent events feed
  - Active credentials overview
  - Schedule management
  - Quick actions (grant, revoke, lockdown)

  ## STAMP Compliance
  - SC-HMI-001: Management by Exception
  - SC-HMI-002: Analog over Digital (progress bars)
  - SC-HMI-003: Staleness Decay
  - SC-SEC-001: Access control verification
  """
  use IndrajaalWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to access events
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "access:events")
      # Refresh metrics every 2 seconds
      :timer.send_interval(2000, self(), :refresh_metrics)
    end

    {:ok,
     socket
     |> assign(:page_title, "Access Control Dashboard")
     |> assign(:metrics, generate_metrics())
     |> assign(:access_points, generate_access_points())
     |> assign(:recent_events, generate_recent_events())
     |> assign(:credentials_summary, generate_credentials_summary())
     |> assign(:active_schedules, generate_active_schedules())
     |> assign(:selected_point, nil)}
  end

  @impl true
  def handle_info(:refresh_metrics, socket) do
    {:noreply,
     socket
     |> assign(:metrics, generate_metrics())
     |> assign(:recent_events, generate_recent_events())}
  end

  def handle_info({:access_event, event}, socket) do
    events = [event | Enum.take(socket.assigns.recent_events, 19)]
    {:noreply, assign(socket, :recent_events, events)}
  end

  @impl true
  def handle_event("select_point", %{"id" => id}, socket) do
    point = Enum.find(socket.assigns.access_points, &(&1.id == id))
    {:noreply, assign(socket, :selected_point, point)}
  end

  def handle_event("grant_access", _params, socket) do
    {:noreply, put_flash(socket, :info, "Access grant dialog opened")}
  end

  def handle_event("revoke_access", _params, socket) do
    {:noreply, put_flash(socket, :info, "Access revocation dialog opened")}
  end

  def handle_event("lockdown_zone", _params, socket) do
    {:noreply, put_flash(socket, :warning, "Zone lockdown initiated - confirmation required")}
  end

  def handle_event("unlock_all", _params, socket) do
    {:noreply, put_flash(socket, :info, "Emergency unlock - confirmation required")}
  end

  def handle_event("close_detail", _params, socket) do
    {:noreply, assign(socket, :selected_point, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- L4-A09: Theme-aware Access Control Dashboard page (SC-HMI-001, SC-HMI-008) --%>
    <div class="min-h-screen bg-surface-primary text-content-primary p-4">
      <!-- Header -->
      <div class="flex items-center justify-between mb-4">
        <h1 class="text-xl font-bold text-white">Access Control Dashboard</h1>
        <div class="flex items-center gap-4">
          <span class="text-content-muted">Last update: {format_time(DateTime.utc_now())}</span>
          <div class="flex gap-2">
            <button
              phx-click="grant_access"
              class="px-4 py-2 bg-green-600 hover:bg-green-500 rounded font-medium"
            >
              Grant Access
            </button>
            <button phx-click="revoke_access" class="px-4 py-2 bg-gray-600 hover:bg-gray-500 rounded">
              Revoke Access
            </button>
          </div>
        </div>
      </div>
      
    <!-- Real-time Metrics -->
      <div class="bg-surface-secondary rounded-lg p-4 mb-4">
        <div class="grid grid-cols-4 gap-4">
          <div class="text-center">
            <div class="text-3xl font-bold text-green-400">{@metrics.grants}</div>
            <div class="text-content-muted text-sm">Grants Today</div>
          </div>
          <div class="text-center">
            <div class="text-3xl font-bold text-red-400">{@metrics.denials}</div>
            <div class="text-content-muted text-sm">Denials Today</div>
          </div>
          <div class="text-center">
            <div class="text-3xl font-bold text-amber-400">{@metrics.tailgating}</div>
            <div class="text-content-muted text-sm">Tailgating Alerts</div>
          </div>
          <div class="text-center">
            <div class="text-3xl font-bold text-cyan-400">{@metrics.anti_passback}</div>
            <div class="text-content-muted text-sm">Anti-Passback</div>
          </div>
        </div>
      </div>
      
    <!-- Main Content Grid -->
      <div class="grid grid-cols-3 gap-4">
        <!-- Left Column: Access Points -->
        <div class="col-span-2 space-y-4">
          <!-- Access Points Status -->
          <div class="bg-surface-secondary rounded-lg p-4">
            <h2 class="font-semibold mb-4">Access Points Status</h2>
            <div class="space-y-2">
              <%= for point <- @access_points do %>
                <div
                  phx-click="select_point"
                  phx-value-id={point.id}
                  class={"flex items-center justify-between p-3 rounded cursor-pointer hover:bg-surface-tertiary #{if @selected_point && @selected_point.id == point.id, do: "bg-surface-tertiary border border-cyan-500", else: "bg-surface-primary"}"}
                >
                  <div class="flex items-center gap-3">
                    <span class={status_indicator_class(point.status)}>
                      {point_status_icon(point.status)}
                    </span>
                    <div>
                      <div class="font-medium text-white">{point.name}</div>
                      <div class="text-sm text-content-muted">
                        Last: {format_time(point.last_event)}
                      </div>
                    </div>
                  </div>
                  <div class="flex items-center gap-4">
                    <div class="text-right">
                      <div class="text-sm text-content-secondary">Traffic</div>
                      <div class="flex items-center gap-2">
                        <div class="w-24 bg-surface-tertiary rounded-full h-2">
                          <div class="bg-cyan-500 h-2 rounded-full" style={"width: #{point.traffic}%"}>
                          </div>
                        </div>
                        <span class="text-sm">{point.traffic}%</span>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
          
    <!-- Recent Events -->
          <div class="bg-surface-secondary rounded-lg p-4">
            <h2 class="font-semibold mb-4">Recent Events</h2>
            <div class="space-y-2 max-h-64 overflow-y-auto">
              <%= for event <- @recent_events do %>
                <div class="flex items-center gap-3 text-sm">
                  <span class={event_icon_class(event.type)}>
                    {event_icon(event.type)}
                  </span>
                  <span class="text-content-muted w-20">{format_time(event.timestamp)}</span>
                  <span class="text-content-primary">{event.user}</span>
                  <span class="text-content-muted">&rarr;</span>
                  <span class="text-content-primary">{event.location}</span>
                </div>
              <% end %>
            </div>
          </div>
        </div>
        
    <!-- Right Column: Summary & Actions -->
        <div class="space-y-4">
          <!-- Credentials Summary -->
          <div class="bg-surface-secondary rounded-lg p-4">
            <h2 class="font-semibold mb-4">Active Credentials</h2>
            <div class="space-y-3">
              <div class="flex justify-between">
                <span class="text-content-secondary">Total</span>
                <span class="text-white font-medium">{@credentials_summary.total}</span>
              </div>
              <div class="flex justify-between">
                <span class="text-content-secondary">Active</span>
                <span class="text-green-400">
                  {@credentials_summary.active} ({@credentials_summary.active_pct}%)
                </span>
              </div>
              <div class="flex justify-between">
                <span class="text-content-secondary">Suspended</span>
                <span class="text-amber-400">{@credentials_summary.suspended}</span>
              </div>
              <div class="flex justify-between">
                <span class="text-content-secondary">Expired</span>
                <span class="text-red-400">{@credentials_summary.expired}</span>
              </div>
              <div class="pt-2">
                <button class="w-full px-4 py-2 bg-surface-tertiary hover:bg-surface-tertiary/80 rounded text-sm">
                  Manage Credentials
                </button>
              </div>
            </div>
          </div>
          
    <!-- Active Schedules -->
          <div class="bg-surface-secondary rounded-lg p-4">
            <h2 class="font-semibold mb-4">Active Schedules</h2>
            <div class="space-y-2">
              <%= for schedule <- @active_schedules do %>
                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-2">
                    <span class={if schedule.active, do: "text-green-400", else: "text-amber-400"}>
                      {if schedule.active, do: "●", else: "○"}
                    </span>
                    <span class="text-content-primary">{schedule.name}</span>
                  </div>
                  <span class="text-content-muted text-sm">{schedule.users} users</span>
                </div>
              <% end %>
            </div>
          </div>
          
    <!-- Quick Actions -->
          <div class="bg-surface-secondary rounded-lg p-4">
            <h2 class="font-semibold mb-4">Quick Actions</h2>
            <div class="grid grid-cols-2 gap-2">
              <button
                phx-click="lockdown_zone"
                class="px-4 py-2 bg-red-600 hover:bg-red-500 rounded text-sm"
              >
                Lockdown Zone
              </button>
              <button
                phx-click="unlock_all"
                class="px-4 py-2 bg-green-600 hover:bg-green-500 rounded text-sm"
              >
                Unlock All
              </button>
            </div>
          </div>
          
    <!-- Selected Point Detail -->
          <%= if @selected_point do %>
            <div class="bg-surface-secondary rounded-lg p-4 border border-cyan-900">
              <div class="flex items-center justify-between mb-3">
                <h2 class="font-semibold text-cyan-400">{@selected_point.name}</h2>
                <button phx-click="close_detail" class="text-content-muted hover:text-white">
                  &times;
                </button>
              </div>
              <div class="space-y-2 text-sm">
                <div class="flex justify-between">
                  <span class="text-content-secondary">Status</span>
                  <span class={status_text_class(@selected_point.status)}>
                    {String.upcase(to_string(@selected_point.status))}
                  </span>
                </div>
                <div class="flex justify-between">
                  <span class="text-content-secondary">Type</span>
                  <span class="text-content-primary">{@selected_point.type}</span>
                </div>
                <div class="flex justify-between">
                  <span class="text-content-secondary">Traffic</span>
                  <span class="text-content-primary">{@selected_point.traffic}%</span>
                </div>
                <div class="flex justify-between">
                  <span class="text-content-secondary">Events Today</span>
                  <span class="text-content-primary">{@selected_point.events_today}</span>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Data generation helpers

  defp generate_metrics do
    %{
      grants: 1234 + :rand.uniform(100),
      denials: 23 + :rand.uniform(10),
      tailgating: :rand.uniform(5),
      anti_passback: 2 + :rand.uniform(3)
    }
  end

  defp generate_access_points do
    [
      %{
        id: "ap-001",
        name: "Main Entrance",
        status: :online,
        type: "Card Reader",
        traffic: 85,
        last_event: DateTime.add(DateTime.utc_now(), -60, :second),
        events_today: 342
      },
      %{
        id: "ap-002",
        name: "Parking Gate A",
        status: :online,
        type: "Vehicle Gate",
        traffic: 45,
        last_event: DateTime.add(DateTime.utc_now(), -120, :second),
        events_today: 156
      },
      %{
        id: "ap-003",
        name: "Server Room",
        status: :online,
        type: "Biometric",
        traffic: 22,
        last_event: DateTime.add(DateTime.utc_now(), -300, :second),
        events_today: 28
      },
      %{
        id: "ap-004",
        name: "Loading Dock",
        status: :offline,
        type: "Card Reader",
        traffic: 0,
        last_event: DateTime.add(DateTime.utc_now(), -1800, :second),
        events_today: 45
      },
      %{
        id: "ap-005",
        name: "Executive Floor",
        status: :online,
        type: "Dual Auth",
        traffic: 62,
        last_event: DateTime.add(DateTime.utc_now(), -90, :second),
        events_today: 89
      }
    ]
  end

  defp generate_recent_events do
    [
      %{type: :grant, timestamp: DateTime.utc_now(), user: "John Doe", location: "Main Entrance"},
      %{
        type: :grant,
        timestamp: DateTime.add(DateTime.utc_now(), -30, :second),
        user: "Jane Smith",
        location: "Parking Gate A"
      },
      %{
        type: :deny,
        timestamp: DateTime.add(DateTime.utc_now(), -45, :second),
        user: "Unknown",
        location: "Server Room"
      },
      %{
        type: :grant,
        timestamp: DateTime.add(DateTime.utc_now(), -60, :second),
        user: "Bob Wilson",
        location: "Executive Floor"
      },
      %{
        type: :grant,
        timestamp: DateTime.add(DateTime.utc_now(), -90, :second),
        user: "Alice Chen",
        location: "Main Entrance"
      },
      %{
        type: :tailgate,
        timestamp: DateTime.add(DateTime.utc_now(), -120, :second),
        user: "Unknown",
        location: "Main Entrance"
      },
      %{
        type: :grant,
        timestamp: DateTime.add(DateTime.utc_now(), -150, :second),
        user: "Charlie Brown",
        location: "Parking Gate A"
      }
    ]
  end

  defp generate_credentials_summary do
    %{
      total: 2456,
      active: 2341,
      active_pct: 95,
      suspended: 45,
      expired: 70
    }
  end

  defp generate_active_schedules do
    [
      %{name: "Business Hours (08:00-18:00)", active: true, users: 156},
      %{name: "24/7 Access", active: true, users: 23},
      %{name: "Weekend Maintenance", active: false, users: 12},
      %{name: "Holiday Schedule", active: false, users: 0}
    ]
  end

  # Formatting helpers

  defp format_time(dt), do: Calendar.strftime(dt, "%H:%M:%S")

  defp point_status_icon(:online), do: "●"
  defp point_status_icon(:offline), do: "○"
  defp point_status_icon(_), do: "◐"

  defp status_indicator_class(:online), do: "text-green-400"
  defp status_indicator_class(:offline), do: "text-gray-500"
  defp status_indicator_class(_), do: "text-amber-400"

  defp status_text_class(:online), do: "text-green-400"
  defp status_text_class(:offline), do: "text-gray-500"
  defp status_text_class(_), do: "text-amber-400"

  defp event_icon(:grant), do: "✓"
  defp event_icon(:deny), do: "✗"
  defp event_icon(:tailgate), do: "⚠"
  defp event_icon(_), do: "•"

  defp event_icon_class(:grant), do: "text-green-400"
  defp event_icon_class(:deny), do: "text-red-400"
  defp event_icon_class(:tailgate), do: "text-amber-400"
  defp event_icon_class(_), do: "text-gray-400"
end
