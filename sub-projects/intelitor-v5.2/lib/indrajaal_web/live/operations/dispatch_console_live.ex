defmodule IndrajaalWeb.Operations.DispatchConsoleLive do
  @moduledoc """
  Dispatch Console - Operations Center

  Real-time dispatch management for security teams, officers,
  and vehicles with assignment tracking and map visualization.

  ## Features
  - Active assignments overview
  - Available resources (teams, officers, vehicles)
  - Map visualization with real-time positions
  - Assignment creation and reassignment
  - Shift handover support
  - Broadcast messaging

  ## STAMP Compliance
  - SC-HMI-001: Management by Exception
  - SC-HMI-004: Two-step commit for critical actions
  - SC-DSP-001: Dispatch workflow management
  - SC-DSP-002: Resource tracking
  """
  use IndrajaalWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to dispatch events
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "dispatch:events")
      # Refresh positions every 3 seconds
      :timer.send_interval(3000, self(), :refresh_positions)
    end

    {:ok,
     socket
     |> assign(:page_title, "Dispatch Console")
     |> assign(:active_assignments, generate_active_assignments())
     |> assign(:available_teams, generate_teams())
     |> assign(:available_officers, generate_officers())
     |> assign(:available_vehicles, generate_vehicles())
     |> assign(:selected_assignment, nil)
     |> assign(:new_assignment_mode, false)
     |> assign(:map_center, {40.7128, -74.0060})}
  end

  @impl true
  def handle_info(:refresh_positions, socket) do
    {:noreply,
     socket
     |> assign(:active_assignments, generate_active_assignments())
     |> assign(:available_officers, generate_officers())}
  end

  def handle_info({:assignment_update, assignment}, socket) do
    assignments =
      socket.assigns.active_assignments
      |> Enum.map(fn a -> if a.id == assignment.id, do: assignment, else: a end)

    {:noreply, assign(socket, :active_assignments, assignments)}
  end

  @impl true
  def handle_event("select_assignment", %{"id" => id}, socket) do
    assignment = Enum.find(socket.assigns.active_assignments, &(&1.id == id))
    {:noreply, assign(socket, :selected_assignment, assignment)}
  end

  def handle_event("new_assignment", _params, socket) do
    {:noreply, assign(socket, :new_assignment_mode, true)}
  end

  def handle_event("cancel_new_assignment", _params, socket) do
    {:noreply, assign(socket, :new_assignment_mode, false)}
  end

  def handle_event("create_assignment", params, socket) do
    # In production, this would create actual assignment
    {:noreply,
     socket
     |> assign(:new_assignment_mode, false)
     |> put_flash(:info, "Assignment created: #{params["type"]}")}
  end

  def handle_event("track", %{"id" => id}, socket) do
    {:noreply, put_flash(socket, :info, "Tracking assignment #{id}")}
  end

  def handle_event("reassign", %{"id" => id}, socket) do
    {:noreply, put_flash(socket, :info, "Reassigning #{id}...")}
  end

  def handle_event("escalate", %{"id" => id}, socket) do
    {:noreply, put_flash(socket, :warning, "Escalating #{id} to supervisor")}
  end

  def handle_event("divert", %{"id" => id}, socket) do
    {:noreply, put_flash(socket, :info, "Diverting #{id}...")}
  end

  def handle_event("add_task", %{"id" => id}, socket) do
    {:noreply, put_flash(socket, :info, "Adding task to #{id}")}
  end

  def handle_event("broadcast_all", _params, socket) do
    {:noreply, put_flash(socket, :info, "Broadcasting to all units...")}
  end

  def handle_event("shift_handover", _params, socket) do
    {:noreply, put_flash(socket, :info, "Initiating shift handover...")}
  end

  def handle_event("reports", _params, socket) do
    {:noreply, put_flash(socket, :info, "Opening reports...")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- L4-A09: Theme-aware Dispatch Console page (SC-HMI-001, SC-HMI-008) --%>
    <div class="min-h-screen bg-surface-primary text-content-primary p-4">
      <!-- Header -->
      <div class="flex items-center justify-between mb-4">
        <h1 class="text-xl font-bold text-white">Dispatch Console</h1>
        <div class="flex items-center gap-4">
          <button
            phx-click="new_assignment"
            class="px-4 py-2 bg-cyan-600 hover:bg-cyan-500 rounded font-medium"
          >
            New Assignment
          </button>
          <button phx-click="broadcast_all" class="px-4 py-2 bg-amber-600 hover:bg-amber-500 rounded">
            Broadcast All
          </button>
          <button
            phx-click="shift_handover"
            class="px-4 py-2 bg-surface-tertiary hover:bg-surface-tertiary/80 rounded"
          >
            Shift Handover
          </button>
          <button
            phx-click="reports"
            class="px-4 py-2 bg-surface-tertiary hover:bg-surface-tertiary/80 rounded"
          >
            Reports
          </button>
        </div>
      </div>
      
    <!-- Main Content Grid -->
      <div class="grid grid-cols-3 gap-4">
        <!-- Left Column: Active Assignments -->
        <div class="col-span-2 space-y-4">
          <!-- Active Assignments -->
          <div class="bg-surface-secondary rounded-lg p-4">
            <h2 class="font-semibold mb-4">Active Assignments ({length(@active_assignments)})</h2>
            <div class="space-y-3">
              <%= for assignment <- @active_assignments do %>
                <div
                  phx-click="select_assignment"
                  phx-value-id={assignment.id}
                  class={"p-4 rounded-lg cursor-pointer #{if @selected_assignment && @selected_assignment.id == assignment.id, do: "bg-surface-tertiary border border-cyan-500", else: "bg-surface-primary hover:bg-surface-tertiary"}"}
                >
                  <div class="flex items-center justify-between mb-2">
                    <div class="flex items-center gap-3">
                      <span class={status_dot_class(assignment.status)}>●</span>
                      <span class="font-medium text-white">{assignment.id}</span>
                      <span class={priority_badge_class(assignment.priority)}>
                        {String.upcase(to_string(assignment.priority))}
                      </span>
                    </div>
                    <span class="text-content-muted text-sm">ETA: {assignment.eta}</span>
                  </div>
                  <div class="flex items-center justify-between">
                    <div>
                      <div class="text-sm text-content-secondary">
                        {assignment.type} | {assignment.location}
                      </div>
                      <div class="text-sm text-content-muted">
                        Assigned: {assignment.assigned_to}
                      </div>
                    </div>
                    <div class="flex gap-2">
                      <button
                        phx-click="track"
                        phx-value-id={assignment.id}
                        class="px-2 py-1 bg-surface-tertiary hover:bg-surface-tertiary/80 rounded text-xs"
                      >
                        Track
                      </button>
                      <button
                        phx-click="reassign"
                        phx-value-id={assignment.id}
                        class="px-2 py-1 bg-surface-tertiary hover:bg-surface-tertiary/80 rounded text-xs"
                      >
                        Reassign
                      </button>
                      <button
                        phx-click="escalate"
                        phx-value-id={assignment.id}
                        class="px-2 py-1 bg-amber-700 hover:bg-amber-600 rounded text-xs"
                      >
                        Escalate
                      </button>
                    </div>
                  </div>
                  <%= if assignment.status == :in_progress do %>
                    <div class="mt-2">
                      <div class="flex items-center justify-between text-xs text-content-muted mb-1">
                        <span>Progress</span>
                        <span>{assignment.progress}%</span>
                      </div>
                      <div class="w-full bg-surface-tertiary rounded-full h-1.5">
                        <div
                          class="bg-cyan-500 h-1.5 rounded-full"
                          style={"width: #{assignment.progress}%"}
                        >
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
          
    <!-- Dispatch Map -->
          <div class="bg-surface-secondary rounded-lg p-4">
            <h2 class="font-semibold mb-4">Dispatch Map</h2>
            <div class="aspect-video bg-surface-primary rounded-lg flex items-center justify-center relative">
              <!-- Map placeholder -->
              <div class="text-gray-600">
                <div class="text-center">
                  <div class="text-4xl mb-2">&#128_506;</div>
                  <div>Interactive Map</div>
                  <div class="text-sm text-content-muted">Real-time unit positions</div>
                </div>
              </div>
              
    <!-- Map markers (positioned absolutely) -->
              <div class="absolute top-1/4 left-1/3">
                <span class="text-2xl animate-pulse" title="V-001 En Route">🚗</span>
              </div>
              <div class="absolute top-1/2 right-1/4">
                <span class="text-xl" title="Alarm Location">⚠️</span>
              </div>
              
    <!-- Map legend -->
              <div class="absolute bottom-2 left-2 bg-surface-secondary/80 rounded p-2 text-xs">
                <div class="flex items-center gap-2 mb-1">
                  <span>🚗</span><span>Vehicle</span>
                </div>
                <div class="flex items-center gap-2 mb-1">
                  <span>👤</span><span>Officer</span>
                </div>
                <div class="flex items-center gap-2">
                  <span>⚠️</span><span>Incident</span>
                </div>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Right Column: Resources -->
        <div class="space-y-4">
          <!-- Available Teams -->
          <div class="bg-surface-secondary rounded-lg p-4">
            <h2 class="font-semibold mb-3">Teams</h2>
            <div class="space-y-2">
              <%= for team <- @available_teams do %>
                <div class="flex items-center justify-between p-2 bg-surface-primary rounded">
                  <div class="flex items-center gap-2">
                    <span class={availability_class(team.status)}>●</span>
                    <span>{team.name}</span>
                    <span class="text-content-muted text-xs">({team.size})</span>
                  </div>
                  <span class={availability_text_class(team.status)}>
                    {team.status_text}
                  </span>
                </div>
              <% end %>
            </div>
          </div>
          
    <!-- Available Officers -->
          <div class="bg-surface-secondary rounded-lg p-4">
            <h2 class="font-semibold mb-3">Officers</h2>
            <div class="space-y-2">
              <%= for officer <- @available_officers do %>
                <div class="flex items-center justify-between p-2 bg-surface-primary rounded">
                  <div class="flex items-center gap-2">
                    <span class={availability_class(officer.status)}>●</span>
                    <span>{officer.name}</span>
                  </div>
                  <span class={availability_text_class(officer.status)}>
                    {officer.status_text}
                  </span>
                </div>
              <% end %>
            </div>
          </div>
          
    <!-- Available Vehicles -->
          <div class="bg-surface-secondary rounded-lg p-4">
            <h2 class="font-semibold mb-3">Vehicles</h2>
            <div class="space-y-2">
              <%= for vehicle <- @available_vehicles do %>
                <div class="flex items-center justify-between p-2 bg-surface-primary rounded">
                  <div class="flex items-center gap-2">
                    <span class={availability_class(vehicle.status)}>●</span>
                    <span>{vehicle.id}</span>
                  </div>
                  <span class={availability_text_class(vehicle.status)}>
                    {vehicle.status_text}
                  </span>
                </div>
              <% end %>
            </div>
          </div>
          
    <!-- Selected Assignment Detail -->
          <%= if @selected_assignment do %>
            <div class="bg-surface-secondary rounded-lg p-4 border border-cyan-900">
              <h3 class="font-semibold text-cyan-400 mb-3">{@selected_assignment.id}</h3>
              <div class="space-y-2 text-sm">
                <div class="flex justify-between">
                  <span class="text-content-secondary">Status</span>
                  <span class={status_text_class(@selected_assignment.status)}>
                    {String.upcase(to_string(@selected_assignment.status) |> String.replace("_", " "))}
                  </span>
                </div>
                <div class="flex justify-between">
                  <span class="text-content-secondary">Type</span>
                  <span>{@selected_assignment.type}</span>
                </div>
                <div class="flex justify-between">
                  <span class="text-content-secondary">Location</span>
                  <span>{@selected_assignment.location}</span>
                </div>
                <div class="flex justify-between">
                  <span class="text-content-secondary">Assigned</span>
                  <span>{@selected_assignment.assigned_to}</span>
                </div>
                <div class="flex justify-between">
                  <span class="text-content-secondary">ETA</span>
                  <span>{@selected_assignment.eta}</span>
                </div>
              </div>
              <div class="mt-4 flex gap-2">
                <button
                  phx-click="divert"
                  phx-value-id={@selected_assignment.id}
                  class="flex-1 px-3 py-2 bg-surface-tertiary hover:bg-surface-tertiary/80 rounded text-sm"
                >
                  Divert
                </button>
                <button
                  phx-click="add_task"
                  phx-value-id={@selected_assignment.id}
                  class="flex-1 px-3 py-2 bg-cyan-600 hover:bg-cyan-500 rounded text-sm"
                >
                  Add Task
                </button>
              </div>
            </div>
          <% end %>
        </div>
      </div>
      
    <!-- New Assignment Modal -->
      <%= if @new_assignment_mode do %>
        <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div class="bg-surface-secondary rounded-lg p-6 w-96">
            <h2 class="text-xl font-bold text-white mb-4">New Assignment</h2>
            <form phx-submit="create_assignment" class="space-y-4">
              <div>
                <label class="block text-sm text-content-secondary mb-1">Type</label>
                <select
                  name="type"
                  class="w-full bg-surface-tertiary border-border-theme-secondary rounded px-3 py-2"
                >
                  <option value="intrusion">Intrusion Response</option>
                  <option value="patrol">Patrol</option>
                  <option value="escort">Escort</option>
                  <option value="investigation">Investigation</option>
                </select>
              </div>
              <div>
                <label class="block text-sm text-content-secondary mb-1">Location</label>
                <input
                  type="text"
                  name="location"
                  class="w-full bg-surface-tertiary border-border-theme-secondary rounded px-3 py-2"
                  placeholder="Enter location"
                />
              </div>
              <div>
                <label class="block text-sm text-content-secondary mb-1">Priority</label>
                <select
                  name="priority"
                  class="w-full bg-surface-tertiary border-border-theme-secondary rounded px-3 py-2"
                >
                  <option value="high">High</option>
                  <option value="routine" selected>Routine</option>
                  <option value="low">Low</option>
                </select>
              </div>
              <div>
                <label class="block text-sm text-content-secondary mb-1">Assign To</label>
                <select
                  name="assign_to"
                  class="w-full bg-surface-tertiary border-border-theme-secondary rounded px-3 py-2"
                >
                  <option value="">Auto-assign</option>
                  <option value="team_alpha">Team Alpha</option>
                  <option value="team_bravo">Team Bravo</option>
                  <option value="johnson">Officer Johnson</option>
                  <option value="smith">Officer Smith</option>
                </select>
              </div>
              <div class="flex gap-2 pt-2">
                <button
                  type="button"
                  phx-click="cancel_new_assignment"
                  class="flex-1 px-4 py-2 bg-surface-tertiary hover:bg-surface-tertiary/80 rounded"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  class="flex-1 px-4 py-2 bg-cyan-600 hover:bg-cyan-500 rounded font-medium"
                >
                  Create
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Data generation helpers

  defp generate_active_assignments do
    [
      %{
        id: "ASN-001",
        type: "INTRUSION",
        location: "Zone-A",
        status: :en_route,
        priority: :high,
        assigned_to: "Team Alpha",
        eta: "3 min",
        progress: 0
      },
      %{
        id: "ASN-002",
        type: "PATROL",
        location: "Building B",
        status: :in_progress,
        priority: :routine,
        assigned_to: "Officer Johnson",
        eta: "-",
        progress: 60
      }
    ]
  end

  defp generate_teams do
    [
      %{name: "Team Alpha", size: 2, status: :assigned, status_text: "Assigned"},
      %{name: "Team Bravo", size: 3, status: :available, status_text: "Available"},
      %{name: "Team Charlie", size: 2, status: :off_duty, status_text: "Off Duty"}
    ]
  end

  defp generate_officers do
    [
      %{name: "Johnson", status: :assigned, status_text: "On Patrol"},
      %{name: "Smith", status: :available, status_text: "Available"},
      %{name: "Williams", status: :break, status_text: "On Break"}
    ]
  end

  defp generate_vehicles do
    [
      %{id: "V-001", status: :moving, status_text: "Moving"},
      %{id: "V-002", status: :parked, status_text: "Parked"},
      %{id: "V-003", status: :maintenance, status_text: "Maintenance"}
    ]
  end

  # Styling helpers

  defp status_dot_class(:en_route), do: "text-amber-400"
  defp status_dot_class(:in_progress), do: "text-purple-400"
  defp status_dot_class(:completed), do: "text-green-400"
  defp status_dot_class(_), do: "text-gray-400"

  defp status_text_class(:en_route), do: "text-amber-400"
  defp status_text_class(:in_progress), do: "text-purple-400"
  defp status_text_class(:completed), do: "text-green-400"
  defp status_text_class(_), do: "text-gray-400"

  defp priority_badge_class(:high), do: "px-2 py-0.5 bg-red-600 text-white rounded text-xs"
  defp priority_badge_class(:routine), do: "px-2 py-0.5 bg-gray-600 text-white rounded text-xs"
  defp priority_badge_class(:low), do: "px-2 py-0.5 bg-gray-700 text-gray-300 rounded text-xs"
  defp priority_badge_class(_), do: "px-2 py-0.5 bg-gray-600 text-white rounded text-xs"

  defp availability_class(:available), do: "text-green-400"
  defp availability_class(:assigned), do: "text-amber-400"
  defp availability_class(:moving), do: "text-cyan-400"
  defp availability_class(:parked), do: "text-green-400"
  defp availability_class(:break), do: "text-amber-400"
  defp availability_class(:off_duty), do: "text-gray-500"
  defp availability_class(:maintenance), do: "text-red-400"
  defp availability_class(_), do: "text-gray-400"

  defp availability_text_class(:available), do: "text-green-400 text-xs"
  defp availability_text_class(:assigned), do: "text-amber-400 text-xs"
  defp availability_text_class(:moving), do: "text-cyan-400 text-xs"
  defp availability_text_class(:parked), do: "text-green-400 text-xs"
  defp availability_text_class(:break), do: "text-amber-400 text-xs"
  defp availability_text_class(:off_duty), do: "text-gray-500 text-xs"
  defp availability_text_class(:maintenance), do: "text-red-400 text-xs"
  defp availability_text_class(_), do: "text-gray-400 text-xs"
end
