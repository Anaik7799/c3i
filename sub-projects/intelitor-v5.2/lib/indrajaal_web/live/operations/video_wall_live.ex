defmodule IndrajaalWeb.Operations.VideoWallLive do
  @moduledoc """
  Live Video Wall - Operations Center

  Multi-camera video surveillance display with analytics integration,
  PTZ control, and recording management.

  ## Features
  - Configurable grid layouts (2x2, 3x3, 4x4, custom)
  - Camera groups and filtering
  - Real-time analytics events overlay
  - PTZ control for supported cameras
  - Quick snapshot and clip export
  - Recording status indicators

  ## STAMP Compliance
  - SC-HMI-001: Management by Exception (analytics alerts)
  - SC-HMI-002: Analog over Digital (visual indicators)
  - SC-VID-001: Video stream management
  - SC-VID-002: Analytics integration
  """
  use IndrajaalWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # Establish safe defaults before any service calls so the template always
    # has every assign it references, even if the Video service is offline.
    socket =
      socket
      |> assign(:page_title, "Live Video Wall")
      |> assign(:grid_layout, "2x2")
      |> assign(:camera_group, "all")
      |> assign(:cameras, [])
      |> assign(:analytics_events, [])
      |> assign(:selected_camera, nil)
      |> assign(:ptz_active, false)
      |> assign(:fullscreen, false)
      |> assign(:video_wall_offline, false)

    if connected?(socket) do
      # Subscribe to analytics events — degrade gracefully if PubSub is not running.
      try do
        Phoenix.PubSub.subscribe(Indrajaal.PubSub, "video:analytics")
        :timer.send_interval(5000, self(), :refresh_cameras)
      rescue
        e ->
          require Logger
          Logger.warning("[VideoWallLive] PubSub/timer setup failed: #{Exception.message(e)}")
      end
    end

    # Load initial data — degrade gracefully if the Video service is unavailable.
    socket =
      try do
        socket
        |> assign(:cameras, generate_cameras())
        |> assign(:analytics_events, generate_analytics_events())
      rescue
        e ->
          require Logger
          Logger.error("[VideoWallLive] Video service unavailable: #{Exception.message(e)}")
          assign(socket, :video_wall_offline, true)
      end

    {:ok, socket}
  end

  @impl true
  def handle_info(:refresh_cameras, socket) do
    socket =
      try do
        socket
        |> assign(:cameras, generate_cameras())
        |> assign(:analytics_events, generate_analytics_events())
        |> assign(:video_wall_offline, false)
      rescue
        e ->
          require Logger
          Logger.warning("[VideoWallLive] Camera refresh failed: #{Exception.message(e)}")
          assign(socket, :video_wall_offline, true)
      end

    {:noreply, socket}
  end

  def handle_info({:analytics_event, event}, socket) do
    events = [event | Enum.take(socket.assigns.analytics_events, 9)]
    {:noreply, assign(socket, :analytics_events, events)}
  end

  @impl true
  def handle_event("set_layout", %{"layout" => layout}, socket) do
    {:noreply, assign(socket, :grid_layout, layout)}
  end

  def handle_event("set_group", %{"group" => group}, socket) do
    {:noreply, assign(socket, :camera_group, group)}
  end

  def handle_event("select_camera", %{"id" => id}, socket) do
    camera = Enum.find(socket.assigns.cameras, &(&1.id == id))
    {:noreply, assign(socket, :selected_camera, camera)}
  end

  def handle_event("toggle_fullscreen", _params, socket) do
    {:noreply, assign(socket, :fullscreen, !socket.assigns.fullscreen)}
  end

  def handle_event("toggle_ptz", _params, socket) do
    {:noreply, assign(socket, :ptz_active, !socket.assigns.ptz_active)}
  end

  def handle_event("ptz_command", %{"direction" => direction}, socket) do
    # In production, this would send PTZ command to camera
    {:noreply, put_flash(socket, :info, "PTZ: #{direction}")}
  end

  def handle_event("snapshot", %{"id" => id}, socket) do
    {:noreply, put_flash(socket, :info, "Snapshot saved for camera #{id}")}
  end

  def handle_event("start_clip", %{"id" => id}, socket) do
    {:noreply, put_flash(socket, :info, "Recording clip for camera #{id}")}
  end

  def handle_event("search_recordings", _params, socket) do
    {:noreply, put_flash(socket, :info, "Opening recordings search...")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- L4-A09: Theme-aware Video Wall page (SC-HMI-001, SC-HMI-008) --%>
    <div class="min-h-screen bg-surface-primary text-content-primary p-4">
      <!-- Offline Banner (SC-HMI-001: Management by Exception) -->
      <%= if @video_wall_offline do %>
        <div class="mb-4 px-4 py-3 bg-amber-900/60 border border-amber-500 rounded-lg flex items-center gap-3">
          <span class="text-amber-400 font-bold text-lg">&#9888;</span>
          <div>
            <div class="text-amber-300 font-semibold">Video wall offline</div>
            <div class="text-amber-400/80 text-sm">
              The Video service is currently unavailable. Camera feeds and analytics are suspended.
              The system will reconnect automatically.
            </div>
          </div>
        </div>
      <% end %>
      <!-- Header -->
      <div class="flex items-center justify-between mb-4">
        <h1 class="text-xl font-bold text-white">Live Video Wall</h1>
        <div class="flex items-center gap-4">
          <!-- Layout Selector -->
          <div class="flex items-center gap-2">
            <span class="text-content-muted text-sm">Layout:</span>
            <div class="flex gap-1">
              <%= for layout <- ["2x2", "3x3", "4x4"] do %>
                <button
                  phx-click="set_layout"
                  phx-value-layout={layout}
                  class={"px-3 py-1 rounded text-sm #{if @grid_layout == layout, do: "bg-cyan-600 text-white", else: "bg-surface-tertiary hover:bg-surface-tertiary/80"}"}
                >
                  {layout}
                </button>
              <% end %>
            </div>
          </div>
          
    <!-- Group Selector -->
          <div class="flex items-center gap-2">
            <span class="text-content-muted text-sm">Group:</span>
            <select
              phx-change="set_group"
              name="group"
              class="bg-surface-tertiary border-border-theme-secondary rounded px-3 py-1 text-sm"
            >
              <option value="all" selected={@camera_group == "all"}>All Cameras</option>
              <option value="entrances" selected={@camera_group == "entrances"}>Entrances</option>
              <option value="parking" selected={@camera_group == "parking"}>Parking</option>
              <option value="interior" selected={@camera_group == "interior"}>Interior</option>
            </select>
          </div>

          <button
            phx-click="search_recordings"
            class="px-4 py-2 bg-surface-tertiary hover:bg-surface-tertiary/80 rounded text-sm"
          >
            Search Recordings
          </button>
        </div>
      </div>
      
    <!-- Video Grid -->
      <div class={"grid gap-2 mb-4 #{grid_class(@grid_layout)}"}>
        <%= for camera <- visible_cameras(@cameras, @grid_layout) do %>
          <div
            phx-click="select_camera"
            phx-value-id={camera.id}
            class={"bg-surface-secondary rounded-lg overflow-hidden cursor-pointer #{if @selected_camera && @selected_camera.id == camera.id, do: "ring-2 ring-cyan-500", else: ""}"}
          >
            <!-- Camera Header -->
            <div class="flex items-center justify-between px-3 py-2 bg-surface-primary">
              <div class="flex items-center gap-2">
                <span class={recording_indicator_class(camera.recording)}>
                  {if camera.recording, do: "REC", else: ""}
                </span>
                <span class="font-medium text-sm">{camera.name}</span>
              </div>
              <div class="flex items-center gap-2 text-xs text-content-muted">
                <span>{camera.resolution}</span>
                <span>{camera.fps}fps</span>
              </div>
            </div>
            
    <!-- Video Feed Area -->
            <div class="aspect-video bg-surface-primary flex items-center justify-center relative">
              <!-- Placeholder for video stream -->
              <div class="text-gray-600 text-4xl">&#9654;</div>
              
    <!-- Analytics Overlay -->
              <%= if camera.motion_detected do %>
                <div class="absolute top-2 right-2 px-2 py-1 bg-amber-500/80 text-black text-xs rounded animate-pulse">
                  MOTION
                </div>
              <% end %>
              
    <!-- Status Overlay -->
              <%= if camera.status != :online do %>
                <div class="absolute inset-0 bg-surface-primary/80 flex items-center justify-center">
                  <span class="text-red-400 font-medium">
                    {String.upcase(to_string(camera.status))}
                  </span>
                </div>
              <% end %>
            </div>
            
    <!-- Camera Footer -->
            <div class="flex items-center justify-between px-3 py-2 text-xs text-content-muted">
              <span>Analytics: {if camera.analytics, do: "ON", else: "OFF"}</span>
              <div class="flex gap-2">
                <button
                  phx-click="snapshot"
                  phx-value-id={camera.id}
                  class="hover:text-white"
                  title="Snapshot"
                >
                  &#128247;
                </button>
                <button
                  phx-click="start_clip"
                  phx-value-id={camera.id}
                  class="hover:text-white"
                  title="Start Clip"
                >
                  &#9899;
                </button>
              </div>
            </div>
          </div>
        <% end %>
      </div>
      
    <!-- Analytics Events Feed -->
      <div class="bg-surface-secondary rounded-lg p-4">
        <h2 class="font-semibold mb-3">Analytics Events</h2>
        <div class="flex gap-4 overflow-x-auto pb-2">
          <%= for event <- @analytics_events do %>
            <div class="flex-shrink-0 bg-surface-primary rounded p-3 min-w-64">
              <div class="flex items-center gap-2 mb-2">
                <span class={analytics_event_class(event.type)}>
                  {analytics_event_icon(event.type)}
                </span>
                <span class="font-medium text-sm">{event.camera}</span>
                <span class="text-content-muted text-xs">{format_time(event.timestamp)}</span>
              </div>
              <div class="text-sm text-content-secondary">{event.description}</div>
            </div>
          <% end %>
        </div>
      </div>
      
    <!-- Selected Camera Controls -->
      <%= if @selected_camera do %>
        <div class="fixed bottom-4 right-4 bg-surface-secondary rounded-lg p-4 shadow-xl border border-border-theme-primary w-80">
          <div class="flex items-center justify-between mb-4">
            <h3 class="font-semibold text-white">{@selected_camera.name}</h3>
            <button phx-click="toggle_fullscreen" class="text-content-secondary hover:text-white">
              {if @fullscreen, do: "Exit Fullscreen", else: "Fullscreen"}
            </button>
          </div>
          
    <!-- PTZ Controls -->
          <%= if @selected_camera.ptz do %>
            <div class="mb-4">
              <div class="flex items-center justify-between mb-2">
                <span class="text-sm text-content-secondary">PTZ Control</span>
                <button
                  phx-click="toggle_ptz"
                  class={"text-xs px-2 py-1 rounded #{if @ptz_active, do: "bg-cyan-600", else: "bg-surface-tertiary"}"}
                >
                  {if @ptz_active, do: "Active", else: "Inactive"}
                </button>
              </div>
              <%= if @ptz_active do %>
                <div class="grid grid-cols-3 gap-1 text-center">
                  <div></div>
                  <button
                    phx-click="ptz_command"
                    phx-value-direction="up"
                    class="bg-surface-tertiary hover:bg-surface-tertiary/80 rounded py-2"
                  >
                    ▲
                  </button>
                  <div></div>
                  <button
                    phx-click="ptz_command"
                    phx-value-direction="left"
                    class="bg-surface-tertiary hover:bg-surface-tertiary/80 rounded py-2"
                  >
                    ◀
                  </button>
                  <button
                    phx-click="ptz_command"
                    phx-value-direction="home"
                    class="bg-surface-tertiary hover:bg-surface-tertiary/80 rounded py-2"
                  >
                    ●
                  </button>
                  <button
                    phx-click="ptz_command"
                    phx-value-direction="right"
                    class="bg-surface-tertiary hover:bg-surface-tertiary/80 rounded py-2"
                  >
                    ▶
                  </button>
                  <div></div>
                  <button
                    phx-click="ptz_command"
                    phx-value-direction="down"
                    class="bg-surface-tertiary hover:bg-surface-tertiary/80 rounded py-2"
                  >
                    ▼
                  </button>
                  <div></div>
                </div>
                <div class="flex gap-2 mt-2">
                  <button
                    phx-click="ptz_command"
                    phx-value-direction="zoom_in"
                    class="flex-1 bg-surface-tertiary hover:bg-surface-tertiary/80 rounded py-2 text-sm"
                  >
                    Zoom +
                  </button>
                  <button
                    phx-click="ptz_command"
                    phx-value-direction="zoom_out"
                    class="flex-1 bg-surface-tertiary hover:bg-surface-tertiary/80 rounded py-2 text-sm"
                  >
                    Zoom -
                  </button>
                </div>
              <% end %>
            </div>
          <% end %>
          
    <!-- Quick Actions -->
          <div class="flex gap-2">
            <button
              phx-click="snapshot"
              phx-value-id={@selected_camera.id}
              class="flex-1 px-3 py-2 bg-surface-tertiary hover:bg-surface-tertiary/80 rounded text-sm"
            >
              Snapshot
            </button>
            <button
              phx-click="start_clip"
              phx-value-id={@selected_camera.id}
              class="flex-1 px-3 py-2 bg-cyan-600 hover:bg-cyan-500 rounded text-sm"
            >
              Record Clip
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Data generation helpers

  defp generate_cameras do
    [
      %{
        id: "cam-001",
        name: "Main Entrance",
        status: :online,
        resolution: "HD",
        fps: 30,
        recording: true,
        analytics: true,
        motion_detected: false,
        ptz: true,
        group: "entrances"
      },
      %{
        id: "cam-002",
        name: "Parking A",
        status: :online,
        resolution: "HD",
        fps: 30,
        recording: true,
        analytics: true,
        motion_detected: false,
        ptz: false,
        group: "parking"
      },
      %{
        id: "cam-003",
        name: "Server Room",
        status: :online,
        resolution: "4K",
        fps: 15,
        recording: true,
        analytics: true,
        motion_detected: false,
        ptz: false,
        group: "interior"
      },
      %{
        id: "cam-004",
        name: "Loading Dock",
        status: :online,
        resolution: "HD",
        fps: 30,
        recording: true,
        analytics: true,
        motion_detected: :rand.uniform(10) > 7,
        ptz: true,
        group: "entrances"
      },
      %{
        id: "cam-005",
        name: "Lobby",
        status: :online,
        resolution: "HD",
        fps: 30,
        recording: true,
        analytics: true,
        motion_detected: false,
        ptz: true,
        group: "interior"
      },
      %{
        id: "cam-006",
        name: "Parking B",
        status: :online,
        resolution: "HD",
        fps: 30,
        recording: true,
        analytics: true,
        motion_detected: false,
        ptz: false,
        group: "parking"
      },
      %{
        id: "cam-007",
        name: "Emergency Exit",
        status: :online,
        resolution: "HD",
        fps: 30,
        recording: true,
        analytics: false,
        motion_detected: false,
        ptz: false,
        group: "entrances"
      },
      %{
        id: "cam-008",
        name: "Warehouse",
        status: :offline,
        resolution: "HD",
        fps: 30,
        recording: false,
        analytics: false,
        motion_detected: false,
        ptz: false,
        group: "interior"
      },
      %{
        id: "cam-009",
        name: "Rooftop",
        status: :online,
        resolution: "HD",
        fps: 15,
        recording: true,
        analytics: false,
        motion_detected: false,
        ptz: true,
        group: "exterior"
      }
    ]
  end

  defp generate_analytics_events do
    [
      %{
        type: :motion,
        camera: "CAM-004",
        timestamp: DateTime.utc_now(),
        description: "Motion detected at loading dock"
      },
      %{
        type: :face,
        camera: "CAM-001",
        timestamp: DateTime.add(DateTime.utc_now(), -30, :second),
        description: "Face recognized: John Doe"
      },
      %{
        type: :vehicle,
        camera: "CAM-002",
        timestamp: DateTime.add(DateTime.utc_now(), -60, :second),
        description: "Vehicle LPN ABC-1234 entered"
      },
      %{
        type: :loiter,
        camera: "CAM-005",
        timestamp: DateTime.add(DateTime.utc_now(), -120, :second),
        description: "Loitering detected (>5 min)"
      },
      %{
        type: :motion,
        camera: "CAM-003",
        timestamp: DateTime.add(DateTime.utc_now(), -180, :second),
        description: "Motion detected in server room"
      }
    ]
  end

  defp visible_cameras(cameras, layout) do
    count =
      case layout do
        "2x2" -> 4
        "3x3" -> 9
        "4x4" -> 16
        _ -> 4
      end

    Enum.take(cameras, count)
  end

  defp grid_class("2x2"), do: "grid-cols-2"
  defp grid_class("3x3"), do: "grid-cols-3"
  defp grid_class("4x4"), do: "grid-cols-4"
  defp grid_class(_), do: "grid-cols-2"

  defp format_time(dt), do: Calendar.strftime(dt, "%H:%M:%S")

  defp recording_indicator_class(true), do: "text-red-500 text-xs font-bold animate-pulse"
  defp recording_indicator_class(false), do: "hidden"

  defp analytics_event_icon(:motion), do: "🔴"
  defp analytics_event_icon(:face), do: "👤"
  defp analytics_event_icon(:vehicle), do: "🚗"
  defp analytics_event_icon(:loiter), do: "⚠️"
  defp analytics_event_icon(_), do: "•"

  defp analytics_event_class(:motion), do: "text-red-400"
  defp analytics_event_class(:face), do: "text-green-400"
  defp analytics_event_class(:vehicle), do: "text-cyan-400"
  defp analytics_event_class(:loiter), do: "text-amber-400"
  defp analytics_event_class(_), do: "text-gray-400"
end
