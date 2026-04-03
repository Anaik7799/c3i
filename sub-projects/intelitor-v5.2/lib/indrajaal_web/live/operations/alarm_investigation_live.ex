defmodule IndrajaalWeb.Operations.AlarmInvestigationLive do
  @moduledoc """
  Alarm Investigation View - Operations Center

  Detailed alarm investigation interface with timeline, correlated events,
  video clips, AI insights, and resolution workflow.

  ## Features
  - Full alarm timeline with status changes
  - Correlated events from multiple sources
  - Video clip viewer for camera-linked alarms
  - AI Copilot analysis and recommendations
  - Investigation notes and actions
  - Resolution workflow (Verify, False Alarm, Escalate, Close)

  ## STAMP Compliance
  - SC-HMI-001: Management by Exception
  - SC-HMI-004: Two-step commit for critical actions
  - SC-AI-001: AI suggestions are ADVISORY only
  """
  use IndrajaalWeb, :live_view

  @impl true
  def mount(%{"id" => alarm_id}, _session, socket) do
    alarm = get_alarm(alarm_id)

    {:ok,
     socket
     |> assign(:page_title, "Investigation: #{alarm_id}")
     |> assign(:alarm, alarm)
     |> assign(:timeline, generate_timeline(alarm))
     |> assign(:correlated_events, generate_correlated_events())
     |> assign(:ai_insight, generate_ai_insight())
     |> assign(:notes, "")
     |> assign(:video_playing, false)}
  end

  def mount(_params, _session, socket) do
    # Default to sample alarm if no ID provided
    alarm = get_alarm("ALM-2024-00_142")

    {:ok,
     socket
     |> assign(:page_title, "Alarm Investigation")
     |> assign(:alarm, alarm)
     |> assign(:timeline, generate_timeline(alarm))
     |> assign(:correlated_events, generate_correlated_events())
     |> assign(:ai_insight, generate_ai_insight())
     |> assign(:notes, "")
     |> assign(:video_playing, false)}
  end

  @impl true
  def handle_event("verify", _params, socket) do
    {:noreply,
     socket
     |> update_alarm_status(:verified)
     |> put_flash(:info, "Alarm verified - dispatching response team")}
  end

  def handle_event("false_alarm", _params, socket) do
    {:noreply,
     socket
     |> update_alarm_status(:false_alarm)
     |> put_flash(:info, "Marked as false alarm")}
  end

  def handle_event("escalate", _params, socket) do
    {:noreply,
     socket
     |> update_alarm_status(:escalated)
     |> put_flash(:warning, "Escalated to supervisor")}
  end

  def handle_event("close", _params, socket) do
    {:noreply,
     socket
     |> update_alarm_status(:closed)
     |> put_flash(:info, "Alarm closed")}
  end

  def handle_event("add_note", %{"note" => note}, socket) do
    {:noreply,
     socket
     |> add_timeline_entry(:note, note)
     |> assign(:notes, "")}
  end

  def handle_event("play_video", _params, socket) do
    {:noreply, assign(socket, :video_playing, true)}
  end

  def handle_event("export_clip", _params, socket) do
    {:noreply, put_flash(socket, :info, "Video clip exported")}
  end

  defp update_alarm_status(socket, status) do
    alarm = Map.put(socket.assigns.alarm, :status, status)
    assign(socket, :alarm, alarm)
  end

  defp add_timeline_entry(socket, type, content) do
    entry = %{
      timestamp: DateTime.utc_now(),
      type: type,
      content: content,
      user: "operator@indrajaal.local"
    }

    timeline = socket.assigns.timeline ++ [entry]
    assign(socket, :timeline, timeline)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- L4-A09: Theme-aware Alarm Investigation page (SC-HMI-001, SC-HMI-008) --%>
    <div class="min-h-screen bg-surface-primary text-content-primary p-4">
      <!-- Header -->
      <div class="flex items-center justify-between mb-4">
        <div class="flex items-center gap-4">
          <.link navigate={~p"/operations/alarms"} class="text-content-secondary hover:text-white">
            &larr; Back to Active Alarms
          </.link>
          <h1 class="text-xl font-bold text-white">
            Investigation: {@alarm.id}
          </h1>
        </div>
        <div class="flex items-center gap-2">
          <span class={status_badge_class(@alarm.status)}>
            {String.upcase(to_string(@alarm.status))}
          </span>
          <span class={severity_badge_class(@alarm.severity)}>
            {severity_icon(@alarm.severity)} {String.upcase(to_string(@alarm.severity))}
          </span>
          <span class="text-content-muted">Age: {format_age(@alarm.timestamp)}</span>
        </div>
      </div>
      
    <!-- Alarm Summary -->
      <div class="bg-surface-secondary rounded-lg p-4 mb-4">
        <div class="grid grid-cols-4 gap-4">
          <div>
            <span class="text-content-muted text-sm">Type</span>
            <p class="text-white">{@alarm.type}</p>
          </div>
          <div>
            <span class="text-content-muted text-sm">Site</span>
            <p class="text-white">{@alarm.site}</p>
          </div>
          <div>
            <span class="text-content-muted text-sm">Zone</span>
            <p class="text-white">{@alarm.zone}</p>
          </div>
          <div>
            <span class="text-content-muted text-sm">Device</span>
            <p class="text-white">{@alarm.device}</p>
          </div>
        </div>
      </div>
      
    <!-- Main Content Grid -->
      <div class="grid grid-cols-2 gap-4">
        <!-- Left Column -->
        <div class="space-y-4">
          <!-- Timeline -->
          <div class="bg-surface-secondary rounded-lg p-4">
            <h2 class="font-semibold mb-4">Timeline</h2>
            <div class="space-y-3 max-h-64 overflow-y-auto">
              <%= for entry <- @timeline do %>
                <div class="flex items-start gap-3">
                  <span class="text-content-muted text-sm w-20 flex-shrink-0">
                    {format_time(entry.timestamp)}
                  </span>
                  <span class={timeline_type_class(entry.type)}>
                    {String.upcase(to_string(entry.type))}
                  </span>
                  <span class="text-content-primary">{entry.content}</span>
                </div>
              <% end %>
            </div>
          </div>
          
    <!-- Correlated Events -->
          <div class="bg-surface-secondary rounded-lg p-4">
            <h2 class="font-semibold mb-4">Correlated Events</h2>
            <div class="space-y-2">
              <%= for event <- @correlated_events do %>
                <div class="flex items-center gap-2 text-sm">
                  <span class="text-content-muted">&bull;</span>
                  <span class="text-content-primary">{event.description}</span>
                  <span class="text-content-muted text-xs">({event.source})</span>
                </div>
              <% end %>
            </div>
          </div>
          
    <!-- Investigation Notes -->
          <div class="bg-surface-secondary rounded-lg p-4">
            <h2 class="font-semibold mb-4">Investigation Notes</h2>
            <form phx-submit="add_note" class="space-y-2">
              <textarea
                name="note"
                value={@notes}
                placeholder="Add investigation notes..."
                class="w-full bg-surface-tertiary border-border-theme-secondary rounded px-3 py-2 text-sm h-20"
              ></textarea>
              <button type="submit" class="px-4 py-1.5 bg-cyan-600 hover:bg-cyan-500 rounded text-sm">
                Add Note
              </button>
            </form>
          </div>
        </div>
        
    <!-- Right Column -->
        <div class="space-y-4">
          <!-- Video Clip -->
          <div class="bg-surface-secondary rounded-lg p-4">
            <h2 class="font-semibold mb-4">Video Clip - {@alarm.camera || "CAM-042"}</h2>
            <div class="bg-surface-primary rounded aspect-video flex items-center justify-center">
              <%= if @video_playing do %>
                <div class="text-center">
                  <div class="text-cyan-400 mb-2">&#9654; Playing...</div>
                  <div class="text-content-muted text-sm">00:00:15 / 00:00:30</div>
                </div>
              <% else %>
                <button
                  phx-click="play_video"
                  class="text-6xl text-gray-600 hover:text-white transition-colors"
                >
                  &#9654;
                </button>
              <% end %>
            </div>
            <div class="flex items-center justify-between mt-3">
              <span class="text-sm text-content-muted">Motion detected at 14:32:43</span>
              <div class="flex gap-2">
                <button
                  phx-click="export_clip"
                  class="px-3 py-1 bg-surface-tertiary hover:bg-surface-tertiary/80 rounded text-sm"
                >
                  Export
                </button>
                <button class="px-3 py-1 bg-surface-tertiary hover:bg-surface-tertiary/80 rounded text-sm">
                  Save Clip
                </button>
              </div>
            </div>
          </div>
          
    <!-- AI Copilot Insight -->
          <div class="bg-surface-secondary rounded-lg p-4 border border-cyan-900/50">
            <div class="flex items-center justify-between mb-3">
              <h2 class="font-semibold text-cyan-400">AI Copilot Insight</h2>
              <span class="text-sm text-content-muted">Confidence: {@ai_insight.confidence}</span>
            </div>
            <p class="text-content-primary mb-3">{@ai_insight.analysis}</p>
            <div class="space-y-1">
              <p class="text-sm text-content-secondary">Recommendations:</p>
              <%= for rec <- @ai_insight.recommendations do %>
                <div class="flex items-center gap-2 text-sm">
                  <span class="text-cyan-500">&bull;</span>
                  <span class="text-content-primary">{rec}</span>
                </div>
              <% end %>
            </div>
            <p class="text-xs text-content-muted mt-3 italic">
              Note: AI suggestions are ADVISORY only. Human operator makes final decisions.
            </p>
          </div>
          
    <!-- Actions -->
          <div class="bg-surface-secondary rounded-lg p-4">
            <h2 class="font-semibold mb-4">Actions</h2>
            <div class="grid grid-cols-2 gap-2">
              <button
                phx-click="verify"
                class="px-4 py-2 bg-green-600 hover:bg-green-500 rounded font-medium"
              >
                Verify Alarm
              </button>
              <button phx-click="false_alarm" class="px-4 py-2 bg-gray-600 hover:bg-gray-500 rounded">
                False Alarm
              </button>
              <button phx-click="escalate" class="px-4 py-2 bg-amber-600 hover:bg-amber-500 rounded">
                Escalate
              </button>
              <button phx-click="close" class="px-4 py-2 bg-cyan-600 hover:bg-cyan-500 rounded">
                Close
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Data generation helpers

  defp get_alarm(id) do
    %{
      id: id,
      status: :investigating,
      severity: :caution,
      type: "INTRUSION",
      site: "HQ Building",
      zone: "Zone-A North",
      device: "sensor-042",
      camera: "CAM-042",
      timestamp: DateTime.add(DateTime.utc_now(), -2700, :second),
      triggered_by: "Motion + Door Contact"
    }
  end

  defp generate_timeline(alarm) do
    base_time = alarm.timestamp

    [
      %{
        timestamp: base_time,
        type: :triggered,
        content: "Motion detected + Door contact",
        user: "system"
      },
      %{
        timestamp: DateTime.add(base_time, 2, :second),
        type: :enriched,
        content: "Location: Zone-A, Floor 2, Room 204",
        user: "system"
      },
      %{
        timestamp: DateTime.add(base_time, 27, :second),
        type: :acknowledged,
        content: "By: Sarah (Operator)",
        user: "sarah@indrajaal.local"
      },
      %{
        timestamp: DateTime.add(base_time, 60, :second),
        type: :dispatched,
        content: "Team Alpha assigned (ETA: 5 min)",
        user: "dispatch@indrajaal.local"
      },
      %{
        timestamp: DateTime.add(base_time, 157, :second),
        type: :investigating,
        content: "Notes: Officer en route",
        user: "officer@indrajaal.local"
      }
    ]
  end

  defp generate_correlated_events do
    [
      %{
        description: "Access granted to John Doe at 14:30:22 (same zone)",
        source: "Access Control"
      },
      %{description: "Camera CAM-042 detected motion at 14:32:43", source: "Video Analytics"},
      %{description: "Similar alarm 3 days ago (resolved: maintenance worker)", source: "History"}
    ]
  end

  defp generate_ai_insight do
    %{
      confidence: "0.78",
      analysis:
        "Low threat. Pattern matches authorized personnel entering during business hours.",
      recommendations: [
        "Verify with access log correlation",
        "Check employee schedule for Zone-A",
        "Review camera footage for positive ID"
      ]
    }
  end

  # Formatting helpers

  defp format_time(dt), do: Calendar.strftime(dt, "%H:%M:%S")

  defp format_age(dt) do
    diff = DateTime.diff(DateTime.utc_now(), dt, :second)

    cond do
      diff < 60 -> "#{diff}s"
      diff < 3600 -> "#{div(diff, 60)} min"
      true -> "#{div(diff, 3600)}h #{rem(div(diff, 60), 60)}m"
    end
  end

  defp severity_icon(:critical), do: "&#9762;"
  defp severity_icon(:warning), do: "&#9940;"
  defp severity_icon(:caution), do: "&#9888;"
  defp severity_icon(:advisory), do: "&#8505;"
  defp severity_icon(_), do: "&#183;"

  defp severity_badge_class(:critical),
    do: "px-2 py-1 bg-red-600 text-white rounded text-sm animate-pulse"

  defp severity_badge_class(:warning), do: "px-2 py-1 bg-red-500 text-white rounded text-sm"
  defp severity_badge_class(:caution), do: "px-2 py-1 bg-amber-500 text-black rounded text-sm"
  defp severity_badge_class(:advisory), do: "px-2 py-1 bg-cyan-500 text-black rounded text-sm"
  defp severity_badge_class(_), do: "px-2 py-1 bg-gray-500 text-white rounded text-sm"

  defp status_badge_class(:investigating), do: "px-2 py-1 bg-amber-600 text-white rounded text-sm"
  defp status_badge_class(:verified), do: "px-2 py-1 bg-red-600 text-white rounded text-sm"
  defp status_badge_class(:false_alarm), do: "px-2 py-1 bg-gray-600 text-white rounded text-sm"
  defp status_badge_class(:escalated), do: "px-2 py-1 bg-purple-600 text-white rounded text-sm"
  defp status_badge_class(:closed), do: "px-2 py-1 bg-green-600 text-white rounded text-sm"
  defp status_badge_class(_), do: "px-2 py-1 bg-gray-600 text-white rounded text-sm"

  defp timeline_type_class(:triggered), do: "text-red-400 text-sm font-medium"
  defp timeline_type_class(:enriched), do: "text-cyan-400 text-sm"
  defp timeline_type_class(:acknowledged), do: "text-green-400 text-sm"
  defp timeline_type_class(:dispatched), do: "text-amber-400 text-sm"
  defp timeline_type_class(:investigating), do: "text-purple-400 text-sm"
  defp timeline_type_class(:note), do: "text-gray-400 text-sm"
  defp timeline_type_class(_), do: "text-gray-400 text-sm"
end
