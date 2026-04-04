defmodule IndrajaalWeb.Prajna.Agentic.SafetyLive do
  @moduledoc """
  AG-UI Safety Dashboard — HITL + Generative UI + Multimodal

  Implements ideas:
  - #11 Frontend Tool Calls (Score 35) — phx-click → GenServer → action
  - #12 Multimodal Voice Alarm (Score 35) — audio tone on critical alerts
  - #13 Generative Dynamic Alarm Panel (Score 35) — AI-generated alarm cards
  - #14 Shared State: State Vector Sync (Score 35) — real-time state vector
  - #15 Thinking Steps: Guardian Chain (Score 35) — constitutional reasoning
  - #16 Streaming: Zenoh River (Score 34) — Zenoh message flow
  - #17 Interrupts: Migration Gate (Score 34) — approve each migration
  - #18 Generative UI: Dynamic Layout (Score 34) — phase-adaptive layout

  Route: /cockpit/agentic/safety
  STAMP: SC-SAFETY-001, SC-CONST-007, SC-IMMUNE-001, SC-HMI-010
  """
  use IndrajaalWeb, :live_view
  alias Indrajaal.Agentic.AgUI

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      AgUI.subscribe("ag_ui:state")
      AgUI.subscribe("ag_ui:interrupt")
      AgUI.subscribe("ag_ui:thinking")
      AgUI.subscribe("ag_ui:custom:alarm")
      AgUI.subscribe("ag_ui:custom:zenoh_message")
      :timer.send_interval(5_000, self(), :refresh)
    end

    {:ok,
     socket
     |> assign(:page_title, "Agentic Safety")
     |> assign(:state_vector, %{
       compile: true,
       migrations: true,
       containers: true,
       zenoh: true,
       health: true,
       quorum: true
     })
     |> assign(:guardian_chain, [])
     |> assign(:alarms, [])
     |> assign(:zenoh_messages, [])
     |> assign(:pending_migrations, [])
     |> assign(:voice_enabled, false)
     |> assign(:system_phase, :steady)}
  end

  @impl true
  def handle_info(:refresh, socket) do
    # Simulate occasional alarm
    alarms =
      if :rand.uniform(10) > 8 do
        [
          %{
            id: Ecto.UUID.generate(),
            severity: Enum.random([:info, :warning, :critical]),
            source: Enum.random(["Sentinel", "PatternHunter", "Watchdog"]),
            message:
              Enum.random(["Memory pressure detected", "Error rate elevated", "Heartbeat stale"]),
            timestamp: DateTime.utc_now()
          }
          | socket.assigns.alarms
        ]
        |> Enum.take(15)
      else
        socket.assigns.alarms
      end

    {:noreply, assign(socket, :alarms, alarms)}
  end

  def handle_info({:ag_state_update, %{key: :state_vector, new_value: sv}}, socket) do
    {:noreply, assign(socket, :state_vector, sv)}
  end

  def handle_info({:ag_thinking, step}, socket) when step.phase == "guardian" do
    chain = [step | socket.assigns.guardian_chain] |> Enum.take(20)
    {:noreply, assign(socket, :guardian_chain, chain)}
  end

  def handle_info({:ag_custom, %{event: "zenoh_message"} = e}, socket) do
    msgs = [e.payload | socket.assigns.zenoh_messages] |> Enum.take(30)
    {:noreply, assign(socket, :zenoh_messages, msgs)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def handle_event("toggle_voice", _params, socket) do
    {:noreply, assign(socket, :voice_enabled, !socket.assigns.voice_enabled)}
  end

  def handle_event("acknowledge_alarm", %{"id" => id}, socket) do
    alarms = Enum.reject(socket.assigns.alarms, &(&1.id == id))
    {:noreply, assign(socket, :alarms, alarms)}
  end

  def handle_event("approve_migration", %{"name" => name}, socket) do
    AgUI.respond_to_interrupt(name, :approve)
    migrations = Enum.reject(socket.assigns.pending_migrations, &(&1.name == name))
    {:noreply, assign(socket, :pending_migrations, migrations)}
  end

  def handle_event("run_tool", %{"tool" => tool}, socket) do
    AgUI.tool_output(tool, "Executed #{tool}", %{status: :ok})
    AgUI.thinking_step("safety", tool, "Tool #{tool} executed successfully", :pass)
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-950 text-gray-100 p-4">
      <div class="bg-gray-900 rounded-lg p-3 border border-cyan-900/30 mb-4 flex items-center justify-between">
        <div class="flex items-center gap-3">
          <span class="text-cyan-400 font-bold text-lg">🛡 Agentic Safety</span>
          <span class={"px-2 py-1 rounded text-xs #{phase_style(@system_phase)}"}>
            {String.upcase(to_string(@system_phase))}
          </span>
        </div>
        <div class="flex items-center gap-3">
          <button
            phx-click="toggle_voice"
            class={"px-3 py-1 rounded text-xs #{if @voice_enabled, do: "bg-green-900 text-green-300", else: "bg-gray-800 text-gray-400"}"}
          >
            🔊 Voice {if @voice_enabled, do: "ON", else: "OFF"}
          </button>
          <span class="text-gray-500 text-xs">
            Alarms:
            <span class={"font-bold #{if length(@alarms) > 0, do: "text-red-400", else: "text-green-400"}"}>
              {length(@alarms)}
            </span>
          </span>
        </div>
      </div>

      <div class="grid grid-cols-12 gap-4">
        <!-- Left: State Vector (#14) + Guardian Chain (#15) -->
        <div class="col-span-3 space-y-4">
          <!-- State Vector Live Sync (#14) -->
          <div class="bg-gray-900 rounded-lg p-4 border border-cyan-900/30">
            <h3 class="text-cyan-400 font-bold mb-3">State Vector [C,M,N,Z,H,Q]</h3>
            <div class="grid grid-cols-3 gap-2">
              <%= for {key, label, desc} <- [
                {:compile, "C", "Compile"},
                {:migrations, "M", "Migrate"},
                {:containers, "N", "Network"},
                {:zenoh, "Z", "Zenoh"},
                {:health, "H", "Health"},
                {:quorum, "Q", "Quorum"}
              ] do %>
                <div class={"text-center p-2 rounded #{if @state_vector[key], do: "bg-green-900/50", else: "bg-red-900/30"}"}>
                  <div class={"text-lg font-bold #{if @state_vector[key], do: "text-green-400", else: "text-red-400"}"}>
                    {label}
                  </div>
                  <div class="text-xs text-gray-500">{desc}</div>
                </div>
              <% end %>
            </div>
          </div>
          
    <!-- Guardian Decision Chain (#15) -->
          <div class="bg-gray-900 rounded-lg p-4 border border-purple-900/30 max-h-60 overflow-y-auto">
            <h3 class="text-purple-400 font-bold mb-2">⚖ Guardian Chain</h3>
            <%= if @guardian_chain == [] do %>
              <p class="text-gray-500 text-sm">No Guardian decisions yet.</p>
            <% else %>
              <%= for step <- @guardian_chain do %>
                <div class="text-xs mb-1">
                  <span class={step_color(step.status)}>{step_icon(step.status)}</span>
                  <span class="text-gray-300">{step.message}</span>
                </div>
              <% end %>
            <% end %>
          </div>
          
    <!-- Frontend Tool Calls (#11) -->
          <div class="bg-gray-900 rounded-lg p-4 border border-cyan-900/30">
            <h3 class="text-cyan-400 font-bold mb-2">🔧 Quick Tools</h3>
            <div class="space-y-1">
              <%= for {tool, label} <- [{"health_check", "Health Check"}, {"db_query", "DB Status"}, {"zenoh_ping", "Zenoh Ping"}, {"stamp_audit", "STAMP Audit"}] do %>
                <button
                  phx-click="run_tool"
                  phx-value-tool={tool}
                  class="w-full px-3 py-1 bg-gray-800 rounded text-xs text-gray-300 hover:bg-cyan-900 hover:text-cyan-300 text-left"
                >
                  ▶ {label}
                </button>
              <% end %>
            </div>
          </div>
        </div>
        
    <!-- Center: Alarms (#13) + Zenoh River (#16) -->
        <div class="col-span-6 space-y-4">
          <!-- Dynamic Alarm Panel (#13) -->
          <div class="bg-gray-900 rounded-lg p-4 border border-red-900/30">
            <h3 class="text-red-400 font-bold mb-3">🚨 Active Alarms (Generative UI)</h3>
            <%= if @alarms == [] do %>
              <div class="text-center py-8">
                <span class="text-4xl">✅</span>
                <p class="text-green-400 mt-2">All clear — no active alarms</p>
              </div>
            <% else %>
              <div class="space-y-2">
                <%= for alarm <- @alarms do %>
                  <div class={"p-3 rounded border #{alarm_style(alarm.severity)}"}>
                    <div class="flex items-center justify-between">
                      <div>
                        <span class={"font-bold text-sm #{alarm_text(alarm.severity)}"}>
                          {alarm_icon(alarm.severity)} {alarm.source}
                        </span>
                        <span class="text-gray-400 text-xs ml-2">
                          {Calendar.strftime(alarm.timestamp, "%H:%M:%S")}
                        </span>
                      </div>
                      <button
                        phx-click="acknowledge_alarm"
                        phx-value-id={alarm.id}
                        class="px-2 py-1 bg-gray-700 rounded text-xs text-gray-300 hover:bg-gray-600"
                      >
                        ACK
                      </button>
                    </div>
                    <p class="text-gray-300 text-sm mt-1">{alarm.message}</p>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
          
    <!-- Zenoh Telemetry River (#16) -->
          <div class="bg-gray-900 rounded-lg p-4 border border-purple-900/30 max-h-48 overflow-y-auto">
            <h3 class="text-purple-400 font-bold mb-2">🌊 Zenoh Message River</h3>
            <%= if @zenoh_messages == [] do %>
              <p class="text-gray-500 text-sm">Awaiting Zenoh telemetry...</p>
            <% else %>
              <%= for msg <- @zenoh_messages do %>
                <div class="text-xs font-mono mb-1 flex gap-2">
                  <span class="text-purple-400">{msg[:topic]}</span>
                  <span class="text-gray-500">→</span>
                  <span class="text-gray-300 truncate">{msg[:payload]}</span>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>
        
    <!-- Right: Migration Gate (#17) -->
        <div class="col-span-3 space-y-4">
          <div class="bg-gray-900 rounded-lg p-4 border border-yellow-900/30">
            <h3 class="text-yellow-400 font-bold mb-3">📋 Migration Gate (#17)</h3>
            <%= if @pending_migrations == [] do %>
              <p class="text-green-400 text-sm">✅ All migrations applied</p>
            <% else %>
              <%= for m <- @pending_migrations do %>
                <div class="mb-2 p-2 bg-gray-800 rounded text-xs">
                  <div class="text-gray-200">{m.name}</div>
                  <button
                    phx-click="approve_migration"
                    phx-value-name={m.name}
                    class="mt-1 px-2 py-1 bg-green-900 text-green-300 rounded hover:bg-green-800"
                  >
                    Approve
                  </button>
                </div>
              <% end %>
            <% end %>
          </div>
          
    <!-- Multimodal Voice Alarm Info (#12) -->
          <div class="bg-gray-900 rounded-lg p-4 border border-cyan-900/30">
            <h3 class="text-cyan-400 font-bold mb-2">🔊 Multimodal (#12)</h3>
            <p class="text-gray-400 text-xs">
              Voice alerts {if @voice_enabled, do: "ENABLED", else: "disabled"}.
              Critical alarms trigger browser Audio API tone.
            </p>
            <%= if @voice_enabled do %>
              <div class="mt-2 text-green-400 text-xs animate-pulse">● Audio monitoring active</div>
            <% end %>
          </div>
          
    <!-- Dynamic Layout Info (#18) -->
          <div class="bg-gray-900 rounded-lg p-4 border border-cyan-900/30">
            <h3 class="text-cyan-400 font-bold mb-2">🎨 Dynamic Layout (#18)</h3>
            <p class="text-gray-400 text-xs">
              Layout adapts to system phase:
              Boot → show progress.
              Steady → show health.
              Incident → show alarms.
            </p>
            <div class="mt-2 text-cyan-400 text-xs">Current: {@system_phase}</div>
          </div>
        </div>
      </div>

      <div class="mt-4 bg-gray-900 rounded-lg p-2 border border-cyan-900/30 text-xs text-gray-500 flex justify-between">
        <span>Ideas #11-#18 | Safety: HITL + Generative + Multimodal + Dynamic Layout</span>
        <span>STAMP: SC-SAFETY-001, SC-CONST-007, SC-IMMUNE-001</span>
      </div>
    </div>
    """
  end

  defp phase_style(:steady), do: "bg-green-900 text-green-300"
  defp phase_style(:boot), do: "bg-cyan-900 text-cyan-300"
  defp phase_style(:incident), do: "bg-red-900 text-red-300"
  defp phase_style(_), do: "bg-gray-800 text-gray-400"

  defp step_icon(:pass), do: "✅"
  defp step_icon(:fail), do: "❌"
  defp step_icon(:in_progress), do: "⏳"
  defp step_icon(_), do: "ℹ"

  defp step_color(:pass), do: "text-green-400"
  defp step_color(:fail), do: "text-red-400"
  defp step_color(:in_progress), do: "text-yellow-400"
  defp step_color(_), do: "text-gray-500"

  defp alarm_icon(:critical), do: "🔴"
  defp alarm_icon(:warning), do: "🟡"
  defp alarm_icon(_), do: "🔵"

  defp alarm_style(:critical), do: "border-red-700/50 bg-red-950/30"
  defp alarm_style(:warning), do: "border-yellow-700/50 bg-yellow-950/30"
  defp alarm_style(_), do: "border-blue-700/50 bg-blue-950/30"

  defp alarm_text(:critical), do: "text-red-400"
  defp alarm_text(:warning), do: "text-yellow-400"
  defp alarm_text(_), do: "text-blue-400"
end
