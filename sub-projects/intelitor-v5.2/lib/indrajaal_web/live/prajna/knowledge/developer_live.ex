defmodule IndrajaalWeb.Prajna.Knowledge.DeveloperLive do
  @moduledoc """
  PRAJNA C3I Developer Knowledge Screen

  WHAT: Developer-centric knowledge management following cognitive load theory
        for optimal engineering decision making.

  WHY: Provides developers with essential knowledge artifacts:
       - Code-to-knowledge links (file ↔ holon mappings)
       - Decision records (ADRs, RFCs, Tech Specs)
       - Design patterns library with usage stats
       - Debug session history and learnings
       - Code review insights

  CONSTRAINTS:
    - SC-HMI-001: Dark Cockpit defaults
    - SC-KMS-001: SQLite+DuckDB only
    - SC-KMS-007: Decision traceability mandatory
    - SC-DEV-001: <50ms query latency

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-30 |
  | Author | Cybernetic Architect |
  | Reference | Fractal Holonic Architecture |
  """

  use IndrajaalWeb, :live_view

  alias Indrajaal.KMS.Developer

  @refresh_interval 10_000

  @decision_status_colors %{
    proposed: "text-blue-600",
    accepted: "text-green-600",
    deprecated: "text-yellow-600",
    superseded: "text-gray-600"
  }
  def status_color(status), do: Map.get(@decision_status_colors, status, "text-content-secondary")

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(@refresh_interval, self(), :refresh)
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "prajna:kms:developer")
    end

    {:ok,
     socket
     |> assign(:page_title, "Developer Knowledge")
     |> assign(:view_mode, :decisions)
     |> assign(:decisions, load_decisions())
     |> assign(:patterns, load_patterns())
     |> assign(:debug_sessions, load_debug_sessions())
     |> assign(:code_links, load_code_links())
     |> assign(:selected_item, nil)
     |> assign(:search_query, "")
     |> assign(:filter_status, :all)}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply,
     socket
     |> assign(:decisions, load_decisions())
     |> assign(:patterns, load_patterns())}
  end

  @impl true
  def handle_info({:developer_event, _event}, socket) do
    {:noreply, assign(socket, :decisions, load_decisions())}
  end

  @impl true
  def handle_event("switch_view", %{"view" => view}, socket) do
    {:noreply, assign(socket, :view_mode, String.to_existing_atom(view))}
  end

  @impl true
  def handle_event("select_item", %{"id" => id, "type" => type}, socket) do
    item = load_item(type, id)
    {:noreply, assign(socket, :selected_item, item)}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, assign(socket, :search_query, query)}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    status_atom = if status == "all", do: :all, else: String.to_existing_atom(status)
    {:noreply, assign(socket, :filter_status, status_atom)}
  end

  @impl true
  def handle_event("use_pattern", %{"id" => id}, socket) do
    case Developer.use_pattern(id) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Pattern usage recorded")
         |> assign(:patterns, load_patterns())}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to record pattern usage")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-surface-primary text-content-primary p-6">
      <header class="mb-6">
        <h1 class="text-2xl font-bold text-cyan-400">📚 Developer Knowledge</h1>
        <p class="text-gray-600 text-sm">Code links, decisions, patterns, debug insights</p>
      </header>
      
    <!-- View Mode Tabs -->
      <nav class="flex space-x-2 mb-6 border-b border-border-theme-primary pb-2">
        <.view_tab view={:decisions} current={@view_mode} label="Decisions" icon="📋" />
        <.view_tab view={:patterns} current={@view_mode} label="Patterns" icon="🧩" />
        <.view_tab view={:debug} current={@view_mode} label="Debug Sessions" icon="🔍" />
        <.view_tab view={:links} current={@view_mode} label="Code Links" icon="🔗" />
      </nav>

      <div class="flex gap-6">
        <!-- Main Content -->
        <div class="flex-1">
          <%= case @view_mode do %>
            <% :decisions -> %>
              <.decisions_view
                decisions={filter_decisions(@decisions, @filter_status, @search_query)}
                filter={@filter_status}
              />
            <% :patterns -> %>
              <.patterns_view patterns={filter_items(@patterns, @search_query)} />
            <% :debug -> %>
              <.debug_view sessions={filter_items(@debug_sessions, @search_query)} />
            <% :links -> %>
              <.links_view links={filter_items(@code_links, @search_query)} />
          <% end %>
        </div>
        
    <!-- Detail Panel -->
        <%= if @selected_item do %>
          <aside class="w-96 bg-surface-secondary rounded-lg p-4 border border-border-theme-primary">
            <.detail_panel item={@selected_item} />
          </aside>
        <% end %>
      </div>
    </div>
    """
  end

  # Components

  defp view_tab(assigns) do
    active_class =
      if assigns.view == assigns.current,
        do: "bg-gray-700 text-cyan-400",
        else: "text-gray-600 hover:bg-surface-secondary"

    assigns = assign(assigns, :active_class, active_class)

    ~H"""
    <button
      phx-click="switch_view"
      phx-value-view={@view}
      class={"px-4 py-2 rounded-t text-sm font-medium #{@active_class}"}
    >
      <span class="mr-1">{@icon}</span>
      {@label}
    </button>
    """
  end

  defp decisions_view(assigns) do
    ~H"""
    <div class="space-y-4">
      <!-- Filters -->
      <div class="flex items-center gap-4 mb-4">
        <select
          phx-change="filter_status"
          name="status"
          class="bg-surface-secondary border border-border-theme-secondary rounded px-3 py-1 text-sm"
        >
          <option value="all" selected={@filter == :all}>All Status</option>
          <option value="proposed" selected={@filter == :proposed}>Proposed</option>
          <option value="accepted" selected={@filter == :accepted}>Accepted</option>
          <option value="deprecated" selected={@filter == :deprecated}>Deprecated</option>
        </select>
        <input
          type="text"
          phx-keyup="search"
          phx-debounce="300"
          name="query"
          placeholder="Search decisions..."
          class="bg-surface-secondary border border-border-theme-secondary rounded px-3 py-1 text-sm flex-1"
        />
      </div>
      
    <!-- Decision List -->
      <div class="space-y-2">
        <%= for decision <- @decisions do %>
          <div
            phx-click="select_item"
            phx-value-id={decision[:id]}
            phx-value-type="decision"
            class="bg-surface-secondary rounded-lg p-4 border border-border-theme-primary hover:border-cyan-500 cursor-pointer"
          >
            <div class="flex items-center justify-between">
              <div>
                <span class={"text-xs font-mono #{status_color(decision[:status])}"}>
                  {decision[:status]}
                </span>
                <h3 class="text-lg font-medium text-content-primary">{decision[:title]}</h3>
                <p class="text-sm text-gray-600 mt-1">
                  {String.slice(decision[:context] || "", 0..120)}...
                </p>
              </div>
              <div class="text-right text-xs text-gray-500">
                <div>{decision[:type]}</div>
                <div>{format_date(decision[:created_at])}</div>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp patterns_view(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="grid grid-cols-2 gap-4">
        <%= for pattern <- @patterns do %>
          <div
            phx-click="select_item"
            phx-value-id={pattern[:id]}
            phx-value-type="pattern"
            class="bg-surface-secondary rounded-lg p-4 border border-border-theme-primary hover:border-cyan-500 cursor-pointer"
          >
            <div class="flex items-center justify-between mb-2">
              <h3 class="font-medium text-cyan-400">{pattern[:name]}</h3>
              <span class="text-xs bg-gray-700 px-2 py-1 rounded">{pattern[:category]}</span>
            </div>
            <p class="text-sm text-gray-600">{String.slice(pattern[:description] || "", 0..80)}...</p>
            <div class="mt-2 flex items-center justify-between text-xs text-gray-500">
              <span>Uses: {pattern[:usage_count] || 0}</span>
              <button
                phx-click="use_pattern"
                phx-value-id={pattern[:id]}
                class="text-cyan-400 hover:underline"
              >
                Use Pattern
              </button>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp debug_view(assigns) do
    ~H"""
    <div class="space-y-4">
      <%= for session <- @sessions do %>
        <div
          phx-click="select_item"
          phx-value-id={session[:id]}
          phx-value-type="debug"
          class="bg-surface-secondary rounded-lg p-4 border border-border-theme-primary hover:border-cyan-500 cursor-pointer"
        >
          <div class="flex items-center justify-between">
            <div>
              <h3 class="font-medium text-content-primary">🔍 {session[:issue_title]}</h3>
              <p class="text-sm text-gray-600 mt-1">
                Root cause: {session[:root_cause] || "Unknown"}
              </p>
            </div>
            <div class="text-right text-xs text-gray-500">
              <div class={(session[:resolved] && "text-green-600") || "text-yellow-600"}>
                {(session[:resolved] && "Resolved") || "Open"}
              </div>
              <div>{format_date(session[:created_at])}</div>
            </div>
          </div>
          <div class="mt-2 flex flex-wrap gap-1">
            <%= for tag <- (session[:tags] || []) do %>
              <span class="text-xs bg-gray-700 px-2 py-0.5 rounded">{tag}</span>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp links_view(assigns) do
    ~H"""
    <div class="space-y-2">
      <p class="text-sm text-gray-600 mb-4">File-to-knowledge mappings for codebase awareness</p>
      <%= for link <- @links do %>
        <div class="bg-surface-secondary rounded p-3 border border-border-theme-primary hover:border-cyan-500">
          <div class="flex items-center justify-between">
            <div>
              <code class="text-sm text-cyan-400">{link[:file_path]}</code>
              <div class="text-xs text-gray-500 mt-1">
                Linked to:
                <span class="text-content-secondary">{link[:holon_count] || 0} holons</span>
              </div>
            </div>
            <span class="text-xs bg-gray-700 px-2 py-1 rounded">{link[:link_type]}</span>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp detail_panel(assigns) do
    ~H"""
    <div>
      <h3 class="text-lg font-bold text-cyan-400 mb-4">{@item[:title] || @item[:name]}</h3>

      <%= if @item[:type] == :decision do %>
        <div class="space-y-3 text-sm">
          <div>
            <label class="text-gray-500">Status</label>
            <p class={status_color(@item[:status])}>{@item[:status]}</p>
          </div>
          <div>
            <label class="text-gray-500">Context</label>
            <p class="text-content-secondary">{@item[:context]}</p>
          </div>
          <div>
            <label class="text-gray-500">Decision</label>
            <p class="text-content-secondary">{@item[:decision]}</p>
          </div>
          <div>
            <label class="text-gray-500">Consequences</label>
            <p class="text-content-secondary">{@item[:consequences]}</p>
          </div>
        </div>
      <% else %>
        <div class="space-y-3 text-sm">
          <div>
            <label class="text-gray-500">Description</label>
            <p class="text-content-secondary">{@item[:description]}</p>
          </div>
          <%= if @item[:example_code] do %>
            <div>
              <label class="text-gray-500">Example</label>
              <pre class="bg-surface-primary p-2 rounded text-xs overflow-x-auto"><%= @item[:example_code] %></pre>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # Data Loading

  defp load_decisions do
    case Developer.list_decisions() do
      {:ok, decisions} -> decisions
      _ -> []
    end
  end

  defp load_patterns do
    case Developer.list_patterns() do
      {:ok, patterns} -> patterns
      _ -> []
    end
  end

  defp load_debug_sessions do
    case Developer.list_debug_sessions() do
      {:ok, sessions} -> sessions
      _ -> []
    end
  end

  defp load_code_links do
    case Developer.list_code_links() do
      {:ok, links} -> links
      _ -> []
    end
  end

  defp load_item("decision", id), do: load_decision(id)
  defp load_item("pattern", id), do: load_pattern(id)
  defp load_item("debug", id), do: load_debug_session(id)
  defp load_item(_, _), do: nil

  defp load_decision(id) do
    case Developer.get_decision(id) do
      {:ok, d} -> Map.put(d, :type, :decision)
      _ -> nil
    end
  end

  defp load_pattern(id) do
    case Developer.get_pattern(id) do
      {:ok, p} -> Map.put(p, :type, :pattern)
      _ -> nil
    end
  end

  defp load_debug_session(id) do
    case Developer.get_debug_session(id) do
      {:ok, s} -> Map.put(s, :type, :debug)
      _ -> nil
    end
  end

  # Filtering

  defp filter_decisions(decisions, :all, query), do: filter_by_query(decisions, query)

  defp filter_decisions(decisions, status, query) do
    decisions
    |> Enum.filter(fn d -> d[:status] == status end)
    |> filter_by_query(query)
  end

  defp filter_items(items, ""), do: items

  defp filter_items(items, query) do
    q = String.downcase(query)

    Enum.filter(items, fn item ->
      title = String.downcase(to_string(item[:title] || item[:name] || ""))
      String.contains?(title, q)
    end)
  end

  defp filter_by_query(items, ""), do: items
  defp filter_by_query(items, query), do: filter_items(items, query)

  defp format_date(nil), do: "-"
  defp format_date(date) when is_binary(date), do: String.slice(date, 0..9)
  defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d")
  defp format_date(_), do: "-"
end
