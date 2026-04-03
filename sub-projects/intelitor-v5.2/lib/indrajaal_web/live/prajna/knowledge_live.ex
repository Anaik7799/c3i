defmodule IndrajaalWeb.Prajna.KnowledgeLive do
  @moduledoc """
  PRAJNA C3I Knowledge Management Screen

  WHAT: Fractal Holonic Knowledge Management System dashboard following
        NASA-STD-3000 principles for information architecture.

  WHY: Provides operator awareness of organizational knowledge state:
       - Holon tree hierarchy (knowledge, process, agent, artifact)
       - Decision records (ADRs, RFCs, Tech Specs)
       - Technical debt tracking and remediation
       - Technology radar visualization
       - Architecture coherence status

  CONSTRAINTS:
    - SC-HMI-001: Dark Cockpit defaults
    - SC-KMS-001: SQLite+DuckDB only (no external dependencies)
    - SC-KMS-004: OODA cycle <100ms for queries
    - SC-KMS-007: Decision traceability mandatory

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-30 |
  | Author | Cybernetic Architect |
  | Reference | Fractal Holonic Architecture |
  """

  use IndrajaalWeb, :live_view

  alias Indrajaal.KMS
  alias Indrajaal.KMS.TechnicalLeadership

  @refresh_interval 5000

  @type_icons %{
    knowledge: "\u{1F4DA}",
    process: "\u{2699}",
    agent: "\u{1F916}",
    artifact: "\u{1F4E6}",
    index: "\u{1F4C1}",
    decision: "\u{1F4DD}",
    architecture: "\u{1F3D7}",
    debt: "\u{26A0}",
    radar: "\u{1F4E1}",
    capability: "\u{1F465}"
  }
  def type_icon(type), do: Map.get(@type_icons, type, "\u{25CF}")

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(@refresh_interval, self(), :refresh)
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "prajna:kms")
    end

    {:ok,
     socket
     |> assign(:page_title, "Knowledge Management")
     |> assign(:view_mode, :tree)
     |> assign(:selected_holon, nil)
     |> assign(:holons, load_holons())
     |> assign(:tree, build_tree())
     |> assign(:health_report, load_health_report())
     |> assign(:debt_summary, load_debt_summary())
     |> assign(:radar_snapshot, load_radar_snapshot())
     |> assign(:recent_decisions, load_recent_decisions())
     |> assign(:search_query, "")
     |> assign(:search_results, [])
     |> assign(:filter_type, nil)
     |> assign(:expanded_nodes, MapSet.new())}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply,
     socket
     |> assign(:health_report, load_health_report())
     |> assign(:debt_summary, load_debt_summary())}
  end

  @impl true
  def handle_info({:kms_event, event}, socket) do
    # Handle real-time KMS updates via PubSub
    case event do
      {:holon_created, holon} ->
        {:noreply,
         socket
         |> assign(:holons, [holon | socket.assigns.holons])
         |> assign(:tree, build_tree())}

      {:holon_updated, holon} ->
        holons =
          Enum.map(socket.assigns.holons, fn h ->
            if h.id == holon.id, do: holon, else: h
          end)

        {:noreply, assign(socket, :holons, holons)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_holon", %{"id" => id}, socket) do
    holon =
      Enum.find(socket.assigns.holons, fn h ->
        (h[:id] || h["id"]) == id
      end)

    {:noreply, assign(socket, :selected_holon, holon)}
  end

  @impl true
  def handle_event("toggle_expand", %{"id" => id}, socket) do
    expanded = socket.assigns.expanded_nodes

    expanded =
      if MapSet.member?(expanded, id) do
        MapSet.delete(expanded, id)
      else
        MapSet.put(expanded, id)
      end

    {:noreply, assign(socket, :expanded_nodes, expanded)}
  end

  @impl true
  def handle_event("change_view", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :view_mode, String.to_atom(mode))}
  end

  @impl true
  def handle_event("filter_type", %{"type" => type}, socket) do
    filter = if type == "all", do: nil, else: String.to_atom(type)
    {:noreply, assign(socket, :filter_type, filter)}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    results =
      if String.trim(query) == "" do
        []
      else
        case KMS.search(query, limit: 20) do
          {:ok, results} -> results
          _ -> []
        end
      end

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:search_results, results)}
  end

  @impl true
  def handle_event("create_adr", _params, socket) do
    {:noreply, put_flash(socket, :info, "ADR creation wizard opened")}
  end

  @impl true
  def handle_event("create_holon", _params, socket) do
    {:noreply, put_flash(socket, :info, "Holon creation wizard opened")}
  end

  @impl true
  def handle_event("view_debt", _params, socket) do
    {:noreply, assign(socket, :view_mode, :debt)}
  end

  @impl true
  def handle_event("view_radar", _params, socket) do
    {:noreply, assign(socket, :view_mode, :radar)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- L4-A09: Theme-aware Knowledge Management page (SC-HMI-001, SC-HMI-008) --%>
    <div class="min-h-screen bg-surface-primary text-content-primary font-mono">
      <!-- Header Bar (COP) -->
      <header class="bg-surface-secondary border-b border-border-theme-primary px-4 py-2 flex items-center justify-between">
        <div class="flex items-center space-x-4">
          <a
            href="/cockpit"
            class="text-accent-primary font-bold text-lg hover:text-accent-primary/80"
          >
            PRAJNA C3I
          </a>
          <span class="text-content-muted">|</span>
          <span class="text-content-secondary">KNOWLEDGE MANAGEMENT</span>
        </div>
        <div class="flex items-center space-x-4">
          <span class={health_badge_class(@health_report.overall_health)}>
            KMS: {format_health(@health_report.overall_health)}
          </span>
          <span class="text-content-secondary">
            {Calendar.strftime(DateTime.utc_now(), "%H:%M:%S")}
          </span>
        </div>
      </header>
      
    <!-- Navigation Tabs -->
      <nav class="bg-surface-secondary border-b border-border-theme-primary px-4">
        <div class="flex space-x-1">
          <%= for {view, label} <- [overview: "Overview", mesh: "Mesh", alarms: "Alarms", commands: "Commands", ai: "AI Copilot", containers: "Containers", cluster: "Cluster", knowledge: "Knowledge"] do %>
            <a
              href={"/cockpit" <> if(view == :overview, do: "", else: "/#{if view == :ai, do: "ai-copilot", else: view}")}
              class={"px-4 py-2 text-sm font-medium transition-colors #{if view == :knowledge, do: "text-accent-primary border-b-2 border-accent-primary", else: "text-content-muted hover:text-content-primary"}"}
            >
              {String.upcase(label)}
            </a>
          <% end %>
        </div>
      </nav>
      
    <!-- Sub-Navigation -->
      <div class="bg-surface-tertiary border-b border-border-theme-primary px-4 py-2 flex items-center justify-between">
        <div class="flex space-x-2">
          <%= for {mode, label} <- [tree: "Tree View", list: "List View", decisions: "Decisions", debt: "Tech Debt", radar: "Radar"] do %>
            <button
              phx-click="change_view"
              phx-value-mode={mode}
              class={"px-3 py-1 text-xs rounded #{if @view_mode == mode, do: "bg-accent-primary text-white", else: "bg-surface-secondary text-content-secondary hover:bg-surface-secondary/80"}"}
            >
              {label}
            </button>
          <% end %>
        </div>
        <div class="flex items-center space-x-2">
          <input
            type="text"
            placeholder="Search holons..."
            phx-keyup="search"
            phx-debounce="300"
            value={@search_query}
            class="px-3 py-1 bg-surface-secondary border border-border-theme-primary rounded text-sm text-content-primary placeholder-content-muted focus:outline-none focus:border-accent-primary"
          />
          <select
            phx-change="filter_type"
            name="type"
            class="px-2 py-1 bg-surface-secondary border border-border-theme-primary rounded text-sm text-content-primary"
          >
            <option value="all">All Types</option>
            <option value="knowledge">Knowledge</option>
            <option value="process">Process</option>
            <option value="agent">Agent</option>
            <option value="artifact">Artifact</option>
            <option value="decision">Decision</option>
            <option value="architecture">Architecture</option>
            <option value="debt">Tech Debt</option>
          </select>
        </div>
      </div>
      
    <!-- Main Content -->
      <main class="p-4">
        <!-- Stats Bar -->
        <div class="grid grid-cols-6 gap-4 mb-4">
          <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-3">
            <div class="text-2xl font-bold text-accent-primary">{@health_report.total_holons}</div>
            <div class="text-xs text-content-muted">Total Holons</div>
          </div>
          <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-3">
            <div class="text-2xl font-bold text-blue-400">{length(@recent_decisions)}</div>
            <div class="text-xs text-content-muted">Decisions</div>
          </div>
          <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-3">
            <div class="text-2xl font-bold text-yellow-400">{@debt_summary.total_items}</div>
            <div class="text-xs text-content-muted">Debt Items</div>
          </div>
          <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-3">
            <div class="text-2xl font-bold text-green-400">{@radar_snapshot.total_entries}</div>
            <div class="text-xs text-content-muted">Radar Entries</div>
          </div>
          <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-3">
            <div class="text-2xl font-bold text-purple-400">{@health_report.entropy_count}</div>
            <div class="text-xs text-content-muted">Stale Items</div>
          </div>
          <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-3">
            <div class={"text-2xl font-bold #{coherence_color(@health_report.coherence_score)}"}>
              {format_percent(@health_report.coherence_score)}
            </div>
            <div class="text-xs text-content-muted">Coherence</div>
          </div>
        </div>
        
    <!-- Search Results (if searching) -->
        <%= if @search_query != "" and length(@search_results) > 0 do %>
          <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4 mb-4">
            <h3 class="text-sm font-bold text-content-secondary mb-3">
              Search Results ({length(@search_results)})
            </h3>
            <div class="space-y-2 max-h-[200px] overflow-y-auto">
              <%= for holon <- @search_results do %>
                <div
                  phx-click="select_holon"
                  phx-value-id={holon[:id] || holon["id"]}
                  class="flex items-center space-x-2 p-2 hover:bg-surface-tertiary rounded cursor-pointer"
                >
                  <span>{type_icon(holon[:type] || holon["type"])}</span>
                  <span class="font-medium">{holon[:name] || holon["name"]}</span>
                  <span class="text-content-muted text-xs">({holon[:type] || holon["type"]})</span>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <div class="grid grid-cols-12 gap-4">
          <!-- Main Content Area -->
          <div class="col-span-8">
            <%= case @view_mode do %>
              <% :tree -> %>
                {render_tree_view(assigns)}
              <% :list -> %>
                {render_list_view(assigns)}
              <% :decisions -> %>
                {render_decisions_view(assigns)}
              <% :debt -> %>
                {render_debt_view(assigns)}
              <% :radar -> %>
                {render_radar_view(assigns)}
              <% _ -> %>
                {render_tree_view(assigns)}
            <% end %>
          </div>
          
    <!-- Detail Panel -->
          <div class="col-span-4">
            <%= if @selected_holon do %>
              {render_holon_detail(assigns)}
            <% else %>
              <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
                <div class="text-content-muted text-center py-8">
                  Select a holon to view details
                </div>
              </div>
            <% end %>
          </div>
        </div>
        
    <!-- Action Buttons -->
        <div class="mt-4 flex space-x-4">
          <button
            phx-click="create_holon"
            class="px-4 py-2 bg-green-900 hover:bg-green-800 text-green-300 rounded border border-green-700"
          >
            CREATE HOLON
          </button>
          <button
            phx-click="create_adr"
            class="px-4 py-2 bg-blue-900 hover:bg-blue-800 text-blue-300 rounded border border-blue-700"
          >
            NEW ADR
          </button>
          <button
            phx-click="view_debt"
            class="px-4 py-2 bg-yellow-900 hover:bg-yellow-800 text-yellow-300 rounded border border-yellow-700"
          >
            TECH DEBT
          </button>
          <button
            phx-click="view_radar"
            class="px-4 py-2 bg-purple-900 hover:bg-purple-800 text-purple-300 rounded border border-purple-700"
          >
            TECH RADAR
          </button>
        </div>
      </main>
      
    <!-- Footer -->
      <footer class="fixed bottom-0 left-0 right-0 bg-surface-secondary border-t border-border-theme-primary px-4 py-2">
        <div class="flex items-center justify-between text-xs text-content-muted">
          <div class="flex space-x-4">
            <span>[N] New Holon</span>
            <span>[D] New Decision</span>
            <span>[S] Search</span>
            <span>[T] Toggle Tree</span>
          </div>
          <div>Fractal Holonic KMS | SQLite + DuckDB</div>
        </div>
      </footer>
    </div>
    """
  end

  # ============================================================================
  # SUB-RENDERS
  # ============================================================================

  defp render_tree_view(assigns) do
    ~H"""
    <div class="bg-surface-secondary rounded-lg border border-border-theme-primary">
      <div class="px-4 py-2 border-b border-border-theme-primary flex items-center justify-between">
        <h2 class="text-sm font-bold text-content-secondary">HOLON TREE</h2>
        <span class="text-xs text-content-muted">{length(@holons)} holons</span>
      </div>
      <div class="p-4 max-h-[500px] overflow-y-auto">
        <%= for node <- @tree do %>
          {render_tree_node(assigns, node, 0)}
        <% end %>
        <%= if Enum.empty?(@tree) do %>
          <div class="text-content-muted text-center py-4">No holons found</div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_tree_node(assigns, node, depth) do
    holon = node.holon
    id = holon[:id] || holon["id"]
    name = holon[:name] || holon["name"]
    type = holon[:type] || holon["type"]
    has_children = length(node.children) > 0
    is_expanded = MapSet.member?(assigns.expanded_nodes, id)

    is_selected =
      assigns.selected_holon &&
        (assigns.selected_holon[:id] || assigns.selected_holon["id"]) == id

    assigns = assign(assigns, :node, node)
    assigns = assign(assigns, :holon, holon)
    assigns = assign(assigns, :id, id)
    assigns = assign(assigns, :name, name)
    assigns = assign(assigns, :type, type)
    assigns = assign(assigns, :depth, depth)
    assigns = assign(assigns, :has_children, has_children)
    assigns = assign(assigns, :is_expanded, is_expanded)
    assigns = assign(assigns, :is_selected, is_selected)

    ~H"""
    <div style={"margin-left: #{@depth * 20}px"}>
      <div class={"flex items-center space-x-2 py-1 px-2 rounded cursor-pointer #{if @is_selected, do: "bg-accent-primary/20", else: "hover:bg-surface-tertiary"}"}>
        <%= if @has_children do %>
          <button
            phx-click="toggle_expand"
            phx-value-id={@id}
            class="text-content-muted hover:text-content-primary"
          >
            {if @is_expanded, do: "\u25BC", else: "\u25B6"}
          </button>
        <% else %>
          <span class="w-4"></span>
        <% end %>
        <span phx-click="select_holon" phx-value-id={@id} class="flex items-center space-x-2 flex-1">
          <span>{type_icon(@type)}</span>
          <span class="font-medium">{@name}</span>
          <span class="text-content-muted text-xs">({@type})</span>
        </span>
      </div>
      <%= if @is_expanded do %>
        <%= for child <- @node.children do %>
          {render_tree_node(assigns, child, @depth + 1)}
        <% end %>
      <% end %>
    </div>
    """
  end

  defp render_list_view(assigns) do
    filtered = filter_holons(assigns.holons, assigns.filter_type)

    assigns = assign(assigns, :filtered, filtered)

    ~H"""
    <div class="bg-surface-secondary rounded-lg border border-border-theme-primary">
      <div class="px-4 py-2 border-b border-border-theme-primary flex items-center justify-between">
        <h2 class="text-sm font-bold text-content-secondary">HOLON LIST</h2>
        <span class="text-xs text-content-muted">{length(@filtered)} items</span>
      </div>
      <div class="divide-y divide-border-theme-primary max-h-[500px] overflow-y-auto">
        <%= for holon <- @filtered do %>
          <% id = holon[:id] || holon["id"] %>
          <% is_selected = @selected_holon && (@selected_holon[:id] || @selected_holon["id"]) == id %>
          <div
            phx-click="select_holon"
            phx-value-id={id}
            class={"p-4 cursor-pointer #{if is_selected, do: "bg-surface-tertiary", else: "hover:bg-surface-tertiary/50"}"}
          >
            <div class="flex items-center justify-between">
              <div class="flex items-center space-x-2">
                <span>{type_icon(holon[:type] || holon["type"])}</span>
                <span class="font-medium">{holon[:name] || holon["name"]}</span>
              </div>
              <span class={health_badge_class(get_health(holon))}>
                {format_health(get_health(holon))}
              </span>
            </div>
            <div class="mt-1 text-xs text-content-muted">
              ID: {id} | Type: {holon[:type] || holon["type"]}
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_decisions_view(assigns) do
    ~H"""
    <div class="bg-surface-secondary rounded-lg border border-border-theme-primary">
      <div class="px-4 py-2 border-b border-border-theme-primary flex items-center justify-between">
        <h2 class="text-sm font-bold text-content-secondary">DECISION RECORDS</h2>
        <button
          phx-click="create_adr"
          class="px-2 py-1 bg-blue-900 hover:bg-blue-800 text-blue-300 text-xs rounded border border-blue-700"
        >
          NEW ADR
        </button>
      </div>
      <div class="divide-y divide-border-theme-primary max-h-[500px] overflow-y-auto">
        <%= for decision <- @recent_decisions do %>
          <% payload = decision[:payload] || decision["payload"] || %{} %>
          <% status = payload[:status] || payload["status"] || "draft" %>
          <div
            phx-click="select_holon"
            phx-value-id={decision[:id] || decision["id"]}
            class="p-4 cursor-pointer hover:bg-surface-tertiary/50"
          >
            <div class="flex items-center justify-between mb-2">
              <span class="font-medium">{decision[:name] || decision["name"]}</span>
              <span class={decision_status_class(status)}>
                {String.upcase(to_string(status))}
              </span>
            </div>
            <div class="text-xs text-content-muted">
              {payload[:type] || payload["type"] || "decision"} |
              Created: {format_date(payload[:created_at] || payload["created_at"])}
            </div>
          </div>
        <% end %>
        <%= if Enum.empty?(@recent_decisions) do %>
          <div class="p-4 text-content-muted text-center">No decisions recorded yet</div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_debt_view(assigns) do
    ~H"""
    <div class="space-y-4">
      <!-- Debt Summary -->
      <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
        <h2 class="text-sm font-bold text-content-secondary mb-4">TECHNICAL DEBT SUMMARY</h2>
        <div class="grid grid-cols-4 gap-4">
          <div>
            <div class="text-2xl font-bold text-yellow-400">{@debt_summary.total_items}</div>
            <div class="text-xs text-content-muted">Total Items</div>
          </div>
          <div>
            <div class="text-2xl font-bold text-red-400">
              {@debt_summary.by_severity[:critical] || 0}
            </div>
            <div class="text-xs text-content-muted">Critical</div>
          </div>
          <div>
            <div class="text-2xl font-bold text-orange-400">
              {@debt_summary.by_severity[:high] || 0}
            </div>
            <div class="text-xs text-content-muted">High</div>
          </div>
          <div>
            <div class="text-2xl font-bold text-content-secondary">
              {@debt_summary.total_estimated_hours}h
            </div>
            <div class="text-xs text-content-muted">Est. Effort</div>
          </div>
        </div>
      </div>
      
    <!-- High Priority Debt -->
      <div class="bg-surface-secondary rounded-lg border border-border-theme-primary">
        <div class="px-4 py-2 border-b border-border-theme-primary">
          <h3 class="text-sm font-bold text-content-secondary">HIGH PRIORITY DEBT</h3>
        </div>
        <div class="divide-y divide-border-theme-primary max-h-[300px] overflow-y-auto">
          <%= for item <- @debt_summary.highest_priority do %>
            <% payload = item[:payload] || item["payload"] || %{} %>
            <% score = payload[:composite_score] || payload["composite_score"] || 0 %>
            <div
              phx-click="select_holon"
              phx-value-id={item[:id] || item["id"]}
              class="p-4 cursor-pointer hover:bg-surface-tertiary/50"
            >
              <div class="flex items-center justify-between mb-2">
                <span class="font-medium">{item[:name] || item["name"]}</span>
                <span class={debt_score_class(score)}>
                  Score: {Float.round(score, 1)}
                </span>
              </div>
              <div class="text-xs text-content-muted">
                Est: {payload[:estimated_effort_hours] || payload["estimated_effort_hours"] || "?"}h |
                Status: {payload[:status] || payload["status"] || "identified"}
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_radar_view(assigns) do
    ~H"""
    <div class="bg-surface-secondary rounded-lg border border-border-theme-primary">
      <div class="px-4 py-2 border-b border-border-theme-primary">
        <h2 class="text-sm font-bold text-content-secondary">TECHNOLOGY RADAR</h2>
      </div>
      <div class="p-4">
        <div class="grid grid-cols-2 gap-4">
          <%= for {quadrant, label} <- [techniques: "Techniques", tools: "Tools", platforms: "Platforms", languages_frameworks: "Languages & Frameworks"] do %>
            <div class="border border-border-theme-primary rounded p-3">
              <h3 class="text-sm font-bold text-content-secondary mb-2">{label}</h3>
              <%= for {ring, entries} <- (@radar_snapshot[quadrant] || %{}) do %>
                <div class="mb-2">
                  <div class={"text-xs font-medium #{ring_color(ring)} mb-1"}>
                    {String.upcase(to_string(ring))}
                  </div>
                  <%= for entry <- entries do %>
                    <div class="text-xs text-content-secondary pl-2">
                      • {entry[:name] || entry["name"]}
                    </div>
                  <% end %>
                </div>
              <% end %>
              <%= if Enum.empty?(@radar_snapshot[quadrant] || %{}) do %>
                <div class="text-xs text-content-muted">No entries</div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_holon_detail(assigns) do
    holon = assigns.selected_holon
    payload = holon[:payload] || holon["payload"] || %{}
    vital_signs = holon[:vital_signs] || holon["vital_signs"] || %{}
    genome = holon[:genome] || holon["genome"] || %{}

    assigns = assign(assigns, :holon, holon)
    assigns = assign(assigns, :payload, payload)
    assigns = assign(assigns, :vital_signs, vital_signs)
    assigns = assign(assigns, :genome, genome)

    ~H"""
    <div class="bg-surface-secondary rounded-lg border border-border-theme-primary">
      <div class="px-4 py-2 border-b border-border-theme-primary flex items-center justify-between">
        <h2 class="text-sm font-bold text-content-secondary">HOLON DETAIL</h2>
        <span class={health_badge_class(get_health(@holon))}>
          {format_health(get_health(@holon))}
        </span>
      </div>
      <div class="p-4 space-y-4">
        <!-- Basic Info -->
        <div>
          <div class="text-lg font-bold">{@holon[:name] || @holon["name"]}</div>
          <div class="text-sm text-content-muted">
            {type_icon(@holon[:type] || @holon["type"])} {@holon[:type] || @holon["type"]}
          </div>
        </div>
        
    <!-- ID & FQUN -->
        <div class="text-xs space-y-1">
          <div><span class="text-content-muted">ID:</span> {@holon[:id] || @holon["id"]}</div>
          <div>
            <span class="text-content-muted">FQUN:</span> {@holon[:fqun] || @holon["fqun"] || "N/A"}
          </div>
          <div>
            <span class="text-content-muted">Parent:</span> {@holon[:parent_id] || @holon["parent_id"] ||
              "Root"}
          </div>
        </div>
        
    <!-- Vital Signs -->
        <%= if map_size(@vital_signs) > 0 do %>
          <div>
            <div class="text-xs font-bold text-content-secondary mb-2">VITAL SIGNS</div>
            <div class="grid grid-cols-2 gap-2 text-xs">
              <%= for {key, value} <- @vital_signs do %>
                <div class="flex justify-between">
                  <span class="text-content-muted">{key}:</span>
                  <span>{format_vital(value)}</span>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
        
    <!-- Genome -->
        <%= if map_size(@genome) > 0 do %>
          <div>
            <div class="text-xs font-bold text-content-secondary mb-2">GENOME</div>
            <div class="text-xs space-y-1">
              <%= for {key, value} <- @genome do %>
                <div><span class="text-content-muted">{key}:</span> {inspect(value)}</div>
              <% end %>
            </div>
          </div>
        <% end %>
        
    <!-- Payload Preview -->
        <%= if map_size(@payload) > 0 do %>
          <div>
            <div class="text-xs font-bold text-content-secondary mb-2">PAYLOAD</div>
            <div class="bg-surface-tertiary rounded p-2 text-xs font-mono max-h-[200px] overflow-y-auto">
              <pre>{Jason.encode!(@payload, pretty: true) |> String.slice(0, 1000)}</pre>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # DATA LOADERS
  # ============================================================================

  defp load_holons do
    case KMS.list_holons(limit: 100) do
      {:ok, holons} -> holons
      _ -> []
    end
  end

  defp build_tree do
    holons = load_holons()

    # Build tree from flat list
    holons_by_id = Map.new(holons, fn h -> {h[:id] || h["id"], h} end)

    roots =
      Enum.filter(holons, fn h ->
        parent = h[:parent_id] || h["parent_id"]
        is_nil(parent) or parent == ""
      end)

    Enum.map(roots, fn root ->
      build_tree_node(root, holons_by_id, holons)
    end)
  end

  defp build_tree_node(holon, holons_by_id, all_holons) do
    id = holon[:id] || holon["id"]

    children =
      Enum.filter(all_holons, fn h ->
        parent = h[:parent_id] || h["parent_id"]
        parent == id
      end)

    %{
      holon: holon,
      children: Enum.map(children, fn c -> build_tree_node(c, holons_by_id, all_holons) end)
    }
  end

  defp load_health_report do
    case KMS.health_report() do
      {:ok, report} ->
        %{
          overall_health: report[:overall_health] || report["overall_health"] || 0.8,
          total_holons: report[:total_holons] || report["total_holons"] || 0,
          entropy_count: report[:entropy_count] || report["entropy_count"] || 0,
          coherence_score: report[:coherence_score] || report["coherence_score"] || 0.9
        }

      _ ->
        %{overall_health: 0.8, total_holons: 0, entropy_count: 0, coherence_score: 0.9}
    end
  end

  defp load_debt_summary do
    case TechnicalLeadership.debt_summary() do
      {:ok, summary} ->
        summary

      _ ->
        %{
          total_items: 0,
          by_severity: %{},
          total_estimated_hours: 0,
          highest_priority: [],
          average_score: 0
        }
    end
  end

  defp load_radar_snapshot do
    case TechnicalLeadership.radar_snapshot() do
      {:ok, snapshot} ->
        snapshot

      _ ->
        %{
          techniques: %{},
          tools: %{},
          platforms: %{},
          languages_frameworks: %{},
          total_entries: 0
        }
    end
  end

  defp load_recent_decisions do
    case TechnicalLeadership.list_adrs() do
      {:ok, adrs} -> Enum.take(adrs, 10)
      _ -> []
    end
  end

  # ============================================================================
  # HELPERS
  # ============================================================================

  defp filter_holons(holons, nil), do: holons

  defp filter_holons(holons, type) do
    Enum.filter(holons, fn h ->
      (h[:type] || h["type"]) == type
    end)
  end

  defp get_health(holon) do
    vital_signs = holon[:vital_signs] || holon["vital_signs"] || %{}
    vital_signs[:health] || vital_signs["health"] || 0.8
  end

  defp format_health(health) when is_number(health), do: "#{round(health * 100)}%"
  defp format_health(_), do: "N/A"

  defp format_percent(value) when is_number(value), do: "#{round(value * 100)}%"
  defp format_percent(_), do: "N/A"

  defp format_vital(value) when is_number(value), do: Float.round(value, 2)
  defp format_vital(value), do: inspect(value)

  defp format_date(nil), do: "N/A"

  defp format_date(date) when is_binary(date) do
    case DateTime.from_iso8601(date) do
      {:ok, dt, _} -> Calendar.strftime(dt, "%Y-%m-%d")
      _ -> date
    end
  end

  defp format_date(date), do: inspect(date)

  defp health_badge_class(health) when is_number(health) do
    cond do
      health >= 0.8 -> "px-2 py-1 bg-green-900/50 text-green-400 rounded text-xs"
      health >= 0.5 -> "px-2 py-1 bg-yellow-900/50 text-yellow-400 rounded text-xs"
      true -> "px-2 py-1 bg-red-900/50 text-red-400 rounded text-xs"
    end
  end

  defp health_badge_class(_),
    do: "px-2 py-1 bg-surface-tertiary text-content-muted rounded text-xs"

  defp coherence_color(score) when is_number(score) do
    cond do
      score >= 0.8 -> "text-green-400"
      score >= 0.5 -> "text-yellow-400"
      true -> "text-red-400"
    end
  end

  defp coherence_color(_), do: "text-content-muted"

  defp decision_status_class(status) do
    case to_string(status) do
      "accepted" -> "px-2 py-1 bg-green-900/50 text-green-400 rounded text-xs"
      "proposed" -> "px-2 py-1 bg-blue-900/50 text-blue-400 rounded text-xs"
      "draft" -> "px-2 py-1 bg-surface-tertiary text-content-muted rounded text-xs"
      "deprecated" -> "px-2 py-1 bg-red-900/50 text-red-400 rounded text-xs"
      "superseded" -> "px-2 py-1 bg-purple-900/50 text-purple-400 rounded text-xs"
      _ -> "px-2 py-1 bg-surface-tertiary text-content-muted rounded text-xs"
    end
  end

  defp debt_score_class(score) when is_number(score) do
    cond do
      score >= 8 -> "text-red-400 font-bold"
      score >= 6 -> "text-orange-400"
      score >= 4 -> "text-yellow-400"
      true -> "text-content-secondary"
    end
  end

  defp debt_score_class(_), do: "text-content-muted"

  defp ring_color(ring) do
    case ring do
      :adopt -> "text-green-400"
      :trial -> "text-blue-400"
      :assess -> "text-yellow-400"
      :hold -> "text-red-400"
      _ -> "text-content-muted"
    end
  end
end
