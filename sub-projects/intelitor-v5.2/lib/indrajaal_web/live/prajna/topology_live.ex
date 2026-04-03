defmodule IndrajaalWeb.Prajna.TopologyLive do
  use IndrajaalWeb, :live_view
  alias Indrajaal.Graph.TopologyServer

  @moduledoc """
  Holographic Visualizer (The Eye) - L5 Interface.
  Visualizes the system topology using GraphBLAS engine.
  """

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "topology:updates")
    end

    # Fetch initial state from L2 Server
    state = TopologyServer.get_state()

    node_coords = calculate_circle_layout(length(state.nodes), 200, {250, 250})

    {:ok,
     assign(socket,
       nodes: state.nodes,
       edges: state.edges,
       matrix: state.matrix,
       has_cycle: state.has_cycle,
       centrality: state.centrality,
       node_coords: node_coords,
       page_title: "Holographic Visualizer"
     )}
  end

  @impl true
  def handle_info({:topology_update, state}, socket) do
    node_coords = calculate_circle_layout(length(state.nodes), 200, {250, 250})

    {:noreply,
     assign(socket,
       nodes: state.nodes,
       edges: state.edges,
       matrix: state.matrix,
       has_cycle: state.has_cycle,
       centrality: state.centrality,
       node_coords: node_coords
     )}
  end

  @impl true
  def handle_info({:correction_applied, payload}, socket) do
    # Flash visual cue or update state based on correction
    {:noreply, put_flash(socket, :info, "🧠 Cortex Correction Applied: #{inspect(payload)}")}
  end

  defp calculate_circle_layout(n, radius, {cx, cy}) do
    angle_step = 2 * :math.pi() / n

    Enum.map(0..(n - 1), fn i ->
      angle = i * angle_step
      x = cx + radius * :math.cos(angle)
      y = cy + radius * :math.sin(angle)
      {x, y}
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="prajna-topology bg-surface-primary text-content-primary min-h-screen p-6">
      <h1 class="text-3xl font-bold mb-6 text-blue-600">Holographic Visualizer (The Eye)</h1>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <!-- SVG GRAPH -->
        <div class="card bg-surface-secondary p-6 rounded-lg shadow-lg border border-border-theme-primary">
          <h2 class="text-xl mb-4 font-semibold">Topology Map</h2>
          <svg
            width="500"
            height="500"
            class="border border-border-theme-secondary bg-surface-primary rounded"
          >
            <!-- Edges -->
            <%= for {s, t} <- @edges do %>
              <% {x1, y1} = Enum.at(@node_coords, s) %>
              <% {x2, y2} = Enum.at(@node_coords, t) %>
              <line
                x1={x1}
                y1={y1}
                x2={x2}
                y2={y2}
                stroke="#4B5563"
                stroke-width="2"
                marker-end="url(#arrow)"
              />
            <% end %>
            
    <!-- Nodes -->
            <%= for {name, i} <- Enum.with_index(@nodes) do %>
              <% {x, y} = Enum.at(@node_coords, i) %>
              <% score = Enum.at(@centrality, i) %>
              <% radius = 20 + score * 20 %>
              <!-- Size by centrality -->

              <g>
                <circle
                  cx={x}
                  cy={y}
                  r={radius}
                  fill={if score > 0.5, do: "#EF4444", else: "#3B82F6"}
                  stroke="white"
                  stroke-width="2"
                />
                <text x={x} y={y} dy={radius + 15} text-anchor="middle" fill="white" font-size="12">
                  {name}
                </text>
                <text x={x} y={y} dy="4" text-anchor="middle" fill="white" font-size="10">
                  {Float.round(score, 2)}
                </text>
              </g>
            <% end %>

            <defs>
              <marker
                id="arrow"
                markerWidth="10"
                markerHeight="10"
                refX="25"
                refY="3"
                orient="auto"
                markerUnits="strokeWidth"
              >
                <path d="M0,0 L0,6 L9,3 z" fill="#9CA3AF" />
              </marker>
            </defs>
          </svg>
        </div>
        
    <!-- ANALYTICS PANEL -->
        <div class="card bg-surface-secondary p-6 rounded-lg shadow-lg border border-border-theme-primary">
          <h2 class="text-xl mb-4 font-semibold">GraphBLAS Analytics (L2+)</h2>

          <div class="grid grid-cols-2 gap-4 mb-6">
            <div class="stat p-4 bg-surface-primary rounded">
              <div class="text-gray-600 text-sm">Cycle Detected</div>
              <div class={"text-2xl font-mono #{if @has_cycle, do: "text-red-500", else: "text-green-500"}"}>
                {@has_cycle}
              </div>
            </div>
            <div class="stat p-4 bg-surface-primary rounded">
              <div class="text-gray-600 text-sm">Node Count</div>
              <div class="text-2xl font-mono text-blue-600">{length(@nodes)}</div>
            </div>
          </div>

          <h3 class="text-lg mb-2 text-content-secondary">Centrality Scores (Risk Index)</h3>
          <div class="overflow-x-auto">
            <table class="table w-full text-sm">
              <thead>
                <tr class="text-left border-b border-border-theme-secondary">
                  <th class="pb-2">Node</th>
                  <th class="pb-2">Score</th>
                  <th class="pb-2">Risk Level</th>
                </tr>
              </thead>
              <tbody>
                <%= for {name, i} <- Enum.with_index(@nodes) do %>
                  <% score = Enum.at(@centrality, i) %>
                  <tr class="border-b border-border-theme-primary">
                    <td class="py-2">{name}</td>
                    <td class="py-2 font-mono">{Float.round(score, 4)}</td>
                    <td class="py-2">
                      <span class={"px-2 py-1 rounded text-xs #{if score > 0.5, do: "bg-red-900 text-red-200", else: "bg-green-900 text-green-200"}"}>
                        {if score > 0.5, do: "CRITICAL", else: "NOMINAL"}
                      </span>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <div class="mt-8">
        <h2 class="text-xl mb-2 font-semibold">Adjacency Matrix (Tensor View)</h2>
        <pre class="bg-black p-4 rounded overflow-auto font-mono text-xs text-green-400 shadow-inner">
          <%= inspect(@matrix, limit: :infinity) %>
        </pre>
      </div>
    </div>
    """
  end
end
