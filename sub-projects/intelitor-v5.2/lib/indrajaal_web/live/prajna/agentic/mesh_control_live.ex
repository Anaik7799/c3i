defmodule IndrajaalWeb.Prajna.Agentic.MeshControlLive do
  @moduledoc """
  AG-UI Mesh Control Dashboard — Agent Steering + Sub-Agents + Tool Streaming

  Implements ideas:
  - #7  Agent Steering: Ignition Override (Score 37) — steer boot sequence in real-time
  - #8  Sub-Agent Composition (Score 36) — multi-container health as nested results
  - #9  Tool Output Streaming (Score 36) — live podman build/exec output
  - #10 STAMP Violation Alert (Score 36) — custom event for constraint breaches
  - #19 Agent Steering: OODA Control (Score 34) — adjust OODA interval live
  - #23 Container Resource Gauges (Score 34) — per-container CPU/memory
  - #24 NIF Crash Detector (Score 34) — exit 139 monitor

  Route: /cockpit/agentic/mesh-control
  STAMP: SC-HMI-010, SC-CPU-GOV-001, SC-OODA-009, SC-NIF-006
  """
  use IndrajaalWeb, :live_view
  alias Indrajaal.Agentic.AgUI

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      AgUI.subscribe("ag_ui:steer")
      AgUI.subscribe("ag_ui:tool")
      AgUI.subscribe("ag_ui:custom:stamp_violation")
      AgUI.subscribe("ag_ui:custom:nif_crash")
      :timer.send_interval(3_000, self(), :refresh_containers)
    end

    {:ok,
     socket
     |> assign(:page_title, "Mesh Control")
     |> assign(:containers, [])
     |> assign(:ooda_interval_ms, 10_000)
     |> assign(:cpu_governor_mode, "auto")
     |> assign(:tool_stream, [])
     |> assign(:stamp_violations, [])
     |> assign(:nif_crashes, [])
     |> assign(:boot_tier_override, nil)
     |> assign(:sub_agent_results, %{})}
  end

  @impl true
  def handle_info(:refresh_containers, socket) do
    # In production: query podman for container stats
    containers = [
      %{
        name: "zenoh-router-1",
        status: "running",
        cpu: :rand.uniform(15),
        mem_mb: 120 + :rand.uniform(30),
        tier: 0
      },
      %{
        name: "zenoh-router-2",
        status: "running",
        cpu: :rand.uniform(10),
        mem_mb: 115 + :rand.uniform(25),
        tier: 0
      },
      %{
        name: "zenoh-router-3",
        status: "running",
        cpu: :rand.uniform(12),
        mem_mb: 118 + :rand.uniform(28),
        tier: 0
      },
      %{
        name: "indrajaal-db-prod",
        status: "running",
        cpu: 5 + :rand.uniform(20),
        mem_mb: 350 + :rand.uniform(100),
        tier: 1
      },
      %{
        name: "indrajaal-obs-prod",
        status: "running",
        cpu: 3 + :rand.uniform(15),
        mem_mb: 280 + :rand.uniform(80),
        tier: 2
      },
      %{
        name: "indrajaal-cortex",
        status: "running",
        cpu: :rand.uniform(8),
        mem_mb: 200 + :rand.uniform(50),
        tier: 3
      },
      %{
        name: "cepaf-bridge",
        status: "running",
        cpu: :rand.uniform(5),
        mem_mb: 90 + :rand.uniform(20),
        tier: 3
      },
      %{
        name: "indrajaal-ex-app-1",
        status: "running",
        cpu: 10 + :rand.uniform(25),
        mem_mb: 1200 + :rand.uniform(500),
        tier: 4
      }
    ]

    {:noreply, assign(socket, :containers, containers)}
  end

  def handle_info({:ag_tool_output, output}, socket) do
    stream = [output | socket.assigns.tool_stream] |> Enum.take(30)
    {:noreply, assign(socket, :tool_stream, stream)}
  end

  def handle_info({:ag_custom, %{event: "stamp_violation"} = e}, socket) do
    violations = [e.payload | socket.assigns.stamp_violations] |> Enum.take(20)
    {:noreply, assign(socket, :stamp_violations, violations)}
  end

  def handle_info({:ag_custom, %{event: "nif_crash"} = e}, socket) do
    crashes = [e.payload | socket.assigns.nif_crashes] |> Enum.take(10)
    {:noreply, assign(socket, :nif_crashes, crashes)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def handle_event("set_ooda_interval", %{"interval" => interval}, socket) do
    ms = String.to_integer(interval)
    AgUI.steer("ooda_loop", "set_interval", %{interval_ms: ms})
    AgUI.thinking_step("mesh_control", "steer", "OODA interval → #{ms}ms", :pass)
    {:noreply, assign(socket, :ooda_interval_ms, ms)}
  end

  def handle_event("set_governor_mode", %{"mode" => mode}, socket) do
    AgUI.steer("cpu_governor", "set_mode", %{mode: mode})
    {:noreply, assign(socket, :cpu_governor_mode, mode)}
  end

  def handle_event("skip_tier", %{"tier" => tier}, socket) do
    AgUI.steer("ignition", "skip_tier", %{tier: String.to_integer(tier)})
    AgUI.thinking_step("mesh_control", "steer", "Skipping tier #{tier}", :pass)
    {:noreply, assign(socket, :boot_tier_override, "skip:#{tier}")}
  end

  def handle_event("restart_container", %{"name" => name}, socket) do
    AgUI.request_approval("restart_container", %{container: name, reason: "Operator request"})
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-950 text-gray-100 p-4">
      <div class="bg-gray-900 rounded-lg p-3 border border-cyan-900/30 mb-4 flex items-center justify-between">
        <span class="text-cyan-400 font-bold text-lg">🎛 Mesh Control</span>
        <span class="text-gray-500 text-sm">Agent Steering + Sub-Agents + Tool Streaming</span>
      </div>

      <div class="grid grid-cols-12 gap-4">
        <!-- Left: Agent Steering Controls (#7, #19) -->
        <div class="col-span-3 space-y-4">
          <div class="bg-gray-900 rounded-lg p-4 border border-cyan-900/30">
            <h3 class="text-cyan-400 font-bold mb-3">🎮 Agent Steering</h3>
            
    <!-- OODA Interval Slider (#19) -->
            <div class="mb-4">
              <label class="text-gray-400 text-xs block mb-1">OODA Cycle Interval</label>
              <input
                type="range"
                min="1000"
                max="60000"
                step="1000"
                value={@ooda_interval_ms}
                phx-change="set_ooda_interval"
                name="interval"
                class="w-full accent-cyan-500"
              />
              <div class="flex justify-between text-xs text-gray-500 mt-1">
                <span>1s</span>
                <span class="text-cyan-400 font-bold">{div(@ooda_interval_ms, 1000)}s</span>
                <span>60s</span>
              </div>
            </div>
            
    <!-- CPU Governor Mode -->
            <div class="mb-4">
              <label class="text-gray-400 text-xs block mb-1">CPU Governor</label>
              <div class="flex gap-1">
                <%= for mode <- ["auto", "full", "throttle", "eco"] do %>
                  <button
                    phx-click="set_governor_mode"
                    phx-value-mode={mode}
                    class={"flex-1 px-2 py-1 rounded text-xs #{if @cpu_governor_mode == mode, do: "bg-cyan-900 text-cyan-300", else: "bg-gray-800 text-gray-400"}"}
                  >
                    {mode}
                  </button>
                <% end %>
              </div>
            </div>
            
    <!-- Tier Skip (#7) -->
            <div>
              <label class="text-gray-400 text-xs block mb-1">Boot Tier Override</label>
              <div class="grid grid-cols-4 gap-1">
                <%= for tier <- 0..7 do %>
                  <button
                    phx-click="skip_tier"
                    phx-value-tier={tier}
                    class="px-2 py-1 bg-gray-800 rounded text-xs text-gray-400 hover:bg-yellow-900 hover:text-yellow-300"
                  >
                    T{tier}
                  </button>
                <% end %>
              </div>
            </div>
          </div>
          
    <!-- STAMP Violations (#10) -->
          <div class="bg-gray-900 rounded-lg p-4 border border-red-900/30">
            <h3 class="text-red-400 font-bold mb-2">⚠ STAMP Violations</h3>
            <%= if @stamp_violations == [] do %>
              <p class="text-green-400 text-sm">✅ No violations</p>
            <% else %>
              <%= for v <- @stamp_violations do %>
                <div class="mb-2 p-2 bg-red-950/30 rounded text-xs border border-red-800/30">
                  <span class="text-red-300 font-bold">{v[:id]}</span>
                  <span class="text-gray-400">{v[:message]}</span>
                </div>
              <% end %>
            <% end %>
          </div>
          
    <!-- NIF Crash Monitor (#24) -->
          <div class="bg-gray-900 rounded-lg p-4 border border-orange-900/30">
            <h3 class="text-orange-400 font-bold mb-2">💥 NIF Crashes</h3>
            <%= if @nif_crashes == [] do %>
              <p class="text-green-400 text-sm">✅ No NIF crashes</p>
            <% else %>
              <%= for c <- @nif_crashes do %>
                <div class="text-xs text-orange-300 mb-1">{c[:nif]}: exit {c[:code]}</div>
              <% end %>
            <% end %>
          </div>
        </div>
        
    <!-- Center: Container Resource Gauges (#23) + Sub-Agent Results (#8) -->
        <div class="col-span-6">
          <div class="bg-gray-900 rounded-lg p-4 border border-cyan-900/30">
            <h3 class="text-cyan-400 font-bold mb-3">
              📊 Container Resources (Sub-Agent Composition)
            </h3>
            <table class="w-full text-sm">
              <thead>
                <tr class="text-gray-400 border-b border-gray-800">
                  <th class="text-left py-2">Container</th>
                  <th class="text-left">Tier</th>
                  <th class="text-left">Status</th>
                  <th class="text-left">CPU %</th>
                  <th class="text-left">Memory</th>
                  <th class="text-left">Actions</th>
                </tr>
              </thead>
              <tbody>
                <%= for c <- @containers do %>
                  <tr class="border-b border-gray-900/50">
                    <td class="py-2">
                      <span class={"mr-1 #{if c.status == "running", do: "text-green-400", else: "text-red-400"}"}>
                        {if c.status == "running", do: "●", else: "○"}
                      </span>
                      <span class="text-gray-200">{c.name}</span>
                    </td>
                    <td class="text-gray-500">T{c.tier}</td>
                    <td class={"#{if c.status == "running", do: "text-green-400", else: "text-red-400"}"}>
                      {c.status}
                    </td>
                    <td>
                      <div class="flex items-center gap-1">
                        <div class="w-16 bg-gray-800 rounded-full h-2">
                          <div
                            class={"h-2 rounded-full #{cpu_bar_color(c.cpu)}"}
                            style={"width: #{c.cpu}%"}
                          >
                          </div>
                        </div>
                        <span class="text-xs text-gray-400">{c.cpu}%</span>
                      </div>
                    </td>
                    <td>
                      <span class={"text-xs #{if c.mem_mb > 1000, do: "text-yellow-400", else: "text-gray-400"}"}>
                        {c.mem_mb}MB
                      </span>
                    </td>
                    <td>
                      <button
                        phx-click="restart_container"
                        phx-value-name={c.name}
                        class="px-2 py-1 bg-gray-800 rounded text-xs text-gray-400 hover:bg-red-900 hover:text-red-300"
                      >
                        ↻
                      </button>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
          
    <!-- Tool Output Stream (#9) -->
          <div class="mt-4 bg-gray-900 rounded-lg p-4 border border-cyan-900/30 max-h-48 overflow-y-auto">
            <h3 class="text-cyan-400 font-bold mb-2">📡 Tool Output Stream</h3>
            <%= if @tool_stream == [] do %>
              <p class="text-gray-500 text-sm">No tool outputs yet.</p>
            <% else %>
              <%= for t <- @tool_stream do %>
                <div class="text-xs font-mono mb-1">
                  <span class="text-purple-400">{t.tool}</span>
                  <span class="text-gray-300">→ {String.slice(inspect(t.output), 0, 80)}</span>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>
        
    <!-- Right: Boot Topology -->
        <div class="col-span-3">
          <div class="bg-gray-900 rounded-lg p-4 border border-cyan-900/30">
            <h3 class="text-cyan-400 font-bold mb-3">🗺 Boot Topology</h3>
            <div class="space-y-2 text-sm">
              <%= for {tier, label, containers} <- [
                {0, "Zenoh", ["ZR-1", "ZR-2", "ZR-3"]},
                {1, "Database", ["DB"]},
                {2, "Observability", ["OBS"]},
                {3, "Cognitive", ["Bridge", "Cortex"]},
                {4, "Application", ["APP-1"]}
              ] do %>
                <div class="flex items-center gap-2">
                  <span class="text-gray-500 w-6">T{tier}</span>
                  <div class="flex-1 h-6 bg-gray-800 rounded flex items-center px-2 gap-1">
                    <%= for c <- containers do %>
                      <span class="text-green-400 text-xs">● {c}</span>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <div class="mt-4 bg-gray-900 rounded-lg p-2 border border-cyan-900/30 text-xs text-gray-500 flex justify-between">
        <span>Ideas #7,#8,#9,#10,#19,#23,#24 | AG-UI: Steering + Sub-Agents + Tool Streaming</span>
        <span>STAMP: SC-CPU-GOV-001, SC-OODA-009, SC-NIF-006</span>
      </div>
    </div>
    """
  end

  defp cpu_bar_color(cpu) when cpu < 50, do: "bg-green-500"
  defp cpu_bar_color(cpu) when cpu < 75, do: "bg-yellow-500"
  defp cpu_bar_color(_), do: "bg-red-500"
end
