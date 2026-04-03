defmodule IndrajaalWeb.Prajna.Knowledge.ProductLive do
  @moduledoc """
  PRAJNA C3I Product Knowledge Screen

  WHAT: Product-centric knowledge management for strategic decision making
        and stakeholder alignment.

  WHY: Provides product managers with essential knowledge artifacts:
       - Feature lifecycle tracking (proposed → shipped)
       - Release management and deployment history
       - Customer feedback aggregation and insights
       - A/B experiments and their outcomes
       - Product KPIs and roadmap alignment

  CONSTRAINTS:
    - SC-HMI-001: Dark Cockpit defaults
    - SC-KMS-001: SQLite+DuckDB only
    - SC-KMS-008: Feedback traceability mandatory
    - SC-PROD-001: <100ms query latency

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-30 |
  | Author | Cybernetic Architect |
  | Reference | Fractal Holonic Architecture |
  """

  use IndrajaalWeb, :live_view

  alias Indrajaal.KMS.Product

  @refresh_interval 15_000

  @feature_status_colors %{
    proposed: "text-blue-600",
    approved: "text-cyan-400",
    in_progress: "text-yellow-600",
    shipped: "text-green-600",
    deprecated: "text-gray-600"
  }
  def status_color(status), do: Map.get(@feature_status_colors, status, "text-content-secondary")

  @priority_icons %{
    critical: "🔴",
    high: "🟠",
    medium: "🟡",
    low: "🟢"
  }
  def priority_icon(priority), do: Map.get(@priority_icons, priority, "⚪")

  @impl true
  def mount(_params, _session, socket) do
    try do
      if connected?(socket) do
        :timer.send_interval(@refresh_interval, self(), :refresh)

        try do
          Phoenix.PubSub.subscribe(Indrajaal.PubSub, "prajna:kms:product")
        rescue
          _ -> :ok
        catch
          _, _ -> :ok
        end
      end

      {:ok,
       socket
       |> assign(:page_title, "Product Knowledge")
       |> assign(:view_mode, :features)
       |> assign(:features, load_features())
       |> assign(:releases, load_releases())
       |> assign(:feedback, load_feedback())
       |> assign(:experiments, load_experiments())
       |> assign(:kpis, load_kpis())
       |> assign(:roadmap, load_roadmap())
       |> assign(:selected_item, nil)
       |> assign(:search_query, "")
       |> assign(:filter_status, :all)
       |> assign(:kms_error, nil)}
    rescue
      error ->
        require Logger

        Logger.warning(
          "[ProductLive] KMS backend unavailable, rendering with placeholder data: #{inspect(error)}"
        )

        {:ok,
         socket
         |> assign(:page_title, "Product Knowledge")
         |> assign(:view_mode, :features)
         |> assign(:features, [])
         |> assign(:releases, [])
         |> assign(:feedback, [])
         |> assign(:experiments, [])
         |> assign(:kpis, [])
         |> assign(:roadmap, [])
         |> assign(:selected_item, nil)
         |> assign(:search_query, "")
         |> assign(:filter_status, :all)
         |> assign(
           :kms_error,
           "KMS backend unavailable — data will load when the system is ready."
         )}
    catch
      kind, error ->
        require Logger

        Logger.warning(
          "[ProductLive] Unexpected error in mount (#{kind}): #{inspect(error)}, rendering placeholder"
        )

        {:ok,
         socket
         |> assign(:page_title, "Product Knowledge")
         |> assign(:view_mode, :features)
         |> assign(:features, [])
         |> assign(:releases, [])
         |> assign(:feedback, [])
         |> assign(:experiments, [])
         |> assign(:kpis, [])
         |> assign(:roadmap, [])
         |> assign(:selected_item, nil)
         |> assign(:search_query, "")
         |> assign(:filter_status, :all)
         |> assign(:kms_error, "System initialising — data will load when the system is ready.")}
    end
  end

  @impl true
  def handle_info(:refresh, socket) do
    try do
      {:noreply,
       socket
       |> assign(:features, load_features())
       |> assign(:kpis, load_kpis())
       |> assign(:kms_error, nil)}
    rescue
      _ -> {:noreply, socket}
    catch
      _, _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:product_event, _event}, socket) do
    {:noreply, assign(socket, :features, load_features())}
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
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-surface-primary text-content-primary p-6">
      <header class="mb-6">
        <h1 class="text-2xl font-bold text-purple-700">📦 Product Knowledge</h1>
        <p class="text-gray-600 text-sm">Features, releases, feedback, experiments, KPIs</p>
      </header>

      <%= if @kms_error do %>
        <div class="mb-4 px-4 py-3 rounded border border-yellow-600 bg-yellow-900/30 text-yellow-300 text-sm flex items-center gap-2">
          <span>⚠</span>
          <span>{@kms_error}</span>
        </div>
      <% end %>
      
    <!-- View Mode Tabs -->
      <nav class="flex space-x-2 mb-6 border-b border-border-theme-primary pb-2">
        <.view_tab view={:features} current={@view_mode} label="Features" icon="✨" />
        <.view_tab view={:releases} current={@view_mode} label="Releases" icon="🚀" />
        <.view_tab view={:feedback} current={@view_mode} label="Feedback" icon="💬" />
        <.view_tab view={:experiments} current={@view_mode} label="Experiments" icon="🧪" />
        <.view_tab view={:kpis} current={@view_mode} label="KPIs" icon="📊" />
        <.view_tab view={:roadmap} current={@view_mode} label="Roadmap" icon="🗺️" />
      </nav>

      <div class="flex gap-6">
        <!-- Main Content -->
        <div class="flex-1">
          <%= case @view_mode do %>
            <% :features -> %>
              <.features_view
                features={filter_by_status(@features, @filter_status, @search_query)}
                filter={@filter_status}
              />
            <% :releases -> %>
              <.releases_view releases={filter_items(@releases, @search_query)} />
            <% :feedback -> %>
              <.feedback_view feedback={filter_items(@feedback, @search_query)} />
            <% :experiments -> %>
              <.experiments_view experiments={filter_items(@experiments, @search_query)} />
            <% :kpis -> %>
              <.kpis_view kpis={@kpis} />
            <% :roadmap -> %>
              <.roadmap_view items={@roadmap} />
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
        do: "bg-gray-700 text-purple-700",
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

  defp features_view(assigns) do
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
          <option value="approved" selected={@filter == :approved}>Approved</option>
          <option value="in_progress" selected={@filter == :in_progress}>In Progress</option>
          <option value="shipped" selected={@filter == :shipped}>Shipped</option>
        </select>
        <input
          type="text"
          phx-keyup="search"
          phx-debounce="300"
          name="query"
          placeholder="Search features..."
          class="bg-surface-secondary border border-border-theme-secondary rounded px-3 py-1 text-sm flex-1"
        />
      </div>
      
    <!-- Feature Cards -->
      <div class="grid grid-cols-2 gap-4">
        <%= for feature <- @features do %>
          <div
            phx-click="select_item"
            phx-value-id={feature[:id]}
            phx-value-type="feature"
            class="bg-surface-secondary rounded-lg p-4 border border-border-theme-primary hover:border-purple-500 cursor-pointer"
          >
            <div class="flex items-center justify-between mb-2">
              <span class={"text-xs font-mono #{status_color(feature[:status])}"}>
                {feature[:status]}
              </span>
              <span>{priority_icon(feature[:priority])}</span>
            </div>
            <h3 class="text-lg font-medium text-content-primary">{feature[:name]}</h3>
            <p class="text-sm text-gray-600 mt-1">
              {String.slice(feature[:description] || "", 0..80)}...
            </p>
            <div class="mt-2 text-xs text-gray-500">
              Owner: {feature[:owner] || "Unassigned"}
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp releases_view(assigns) do
    ~H"""
    <div class="space-y-4">
      <%= for release <- @releases do %>
        <div
          phx-click="select_item"
          phx-value-id={release[:id]}
          phx-value-type="release"
          class="bg-surface-secondary rounded-lg p-4 border border-border-theme-primary hover:border-purple-500 cursor-pointer"
        >
          <div class="flex items-center justify-between">
            <div>
              <h3 class="text-lg font-bold text-purple-700">v{release[:version]}</h3>
              <p class="text-sm text-gray-600 mt-1">{release[:notes] |> String.slice(0..100)}...</p>
            </div>
            <div class="text-right">
              <div class={"text-sm #{release[:deployed] && "text-green-600" || "text-yellow-600"}"}>
                {(release[:deployed] && "Deployed") || "Pending"}
              </div>
              <div class="text-xs text-gray-500">{format_date(release[:release_date])}</div>
            </div>
          </div>
          <div class="mt-2 text-xs text-gray-500">
            Features: {length(release[:feature_ids] || [])}
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp feedback_view(assigns) do
    ~H"""
    <div class="space-y-4">
      <%= for item <- @feedback do %>
        <div
          phx-click="select_item"
          phx-value-id={item[:id]}
          phx-value-type="feedback"
          class="bg-surface-secondary rounded-lg p-4 border border-border-theme-primary hover:border-purple-500 cursor-pointer"
        >
          <div class="flex items-center justify-between mb-2">
            <span class="text-xs bg-gray-700 px-2 py-1 rounded">{item[:source]}</span>
            <span class={"text-sm #{sentiment_color(item[:sentiment])}"}>
              {sentiment_icon(item[:sentiment])} {item[:sentiment]}
            </span>
          </div>
          <p class="text-content-secondary">{String.slice(item[:content] || "", 0..150)}...</p>
          <div class="mt-2 flex flex-wrap gap-1">
            <%= for tag <- (item[:tags] || []) do %>
              <span class="text-xs bg-gray-700 px-2 py-0.5 rounded">{tag}</span>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp experiments_view(assigns) do
    ~H"""
    <div class="space-y-4">
      <%= for exp <- @experiments do %>
        <div
          phx-click="select_item"
          phx-value-id={exp[:id]}
          phx-value-type="experiment"
          class="bg-surface-secondary rounded-lg p-4 border border-border-theme-primary hover:border-purple-500 cursor-pointer"
        >
          <div class="flex items-center justify-between mb-2">
            <h3 class="font-medium text-purple-700">🧪 {exp[:name]}</h3>
            <span class={"text-xs px-2 py-1 rounded #{experiment_status_class(exp[:status])}"}>
              {exp[:status]}
            </span>
          </div>
          <p class="text-sm text-gray-600">{exp[:hypothesis]}</p>
          <div class="mt-2 grid grid-cols-2 gap-2 text-xs text-gray-500">
            <div>Control: {exp[:control_size] || 0}</div>
            <div>Treatment: {exp[:treatment_size] || 0}</div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp kpis_view(assigns) do
    ~H"""
    <div class="grid grid-cols-3 gap-4">
      <%= for kpi <- @kpis do %>
        <div class="bg-surface-secondary rounded-lg p-4 border border-border-theme-primary">
          <div class="text-sm text-gray-600">{kpi[:name]}</div>
          <div class="text-2xl font-bold text-purple-700 mt-1">
            {format_kpi_value(kpi[:current_value], kpi[:unit])}
          </div>
          <div class="mt-2 flex items-center text-xs">
            <span class={trend_color(kpi[:trend])}>
              {trend_icon(kpi[:trend])} {kpi[:trend]}
            </span>
            <span class="ml-2 text-gray-500">
              Target: {format_kpi_value(kpi[:target], kpi[:unit])}
            </span>
          </div>
          <div class="mt-2 h-1 bg-gray-700 rounded">
            <div class="h-1 bg-purple-500 rounded" style={"width: #{progress_percent(kpi)}%"}></div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp roadmap_view(assigns) do
    ~H"""
    <div class="space-y-6">
      <%= for {quarter, items} <- group_by_quarter(@items) do %>
        <div>
          <h3 class="text-lg font-bold text-purple-700 mb-3">{quarter}</h3>
          <div class="space-y-2">
            <%= for item <- items do %>
              <div class="bg-surface-secondary rounded p-3 border border-border-theme-primary flex items-center justify-between">
                <div>
                  <span class="mr-2">{priority_icon(item[:priority])}</span>
                  <span class="text-content-primary">{item[:title]}</span>
                </div>
                <span class={"text-xs px-2 py-1 rounded #{status_color(item[:status])}"}>
                  {item[:status]}
                </span>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp detail_panel(assigns) do
    ~H"""
    <div>
      <h3 class="text-lg font-bold text-purple-700 mb-4">{@item[:name] || @item[:title]}</h3>

      <div class="space-y-3 text-sm">
        <%= if @item[:description] do %>
          <div>
            <label class="text-gray-500">Description</label>
            <p class="text-content-secondary">{@item[:description]}</p>
          </div>
        <% end %>

        <%= if @item[:hypothesis] do %>
          <div>
            <label class="text-gray-500">Hypothesis</label>
            <p class="text-content-secondary">{@item[:hypothesis]}</p>
          </div>
        <% end %>

        <%= if @item[:content] do %>
          <div>
            <label class="text-gray-500">Content</label>
            <p class="text-content-secondary">{@item[:content]}</p>
          </div>
        <% end %>

        <%= if @item[:metrics] do %>
          <div>
            <label class="text-gray-500">Metrics</label>
            <pre class="bg-surface-primary p-2 rounded text-xs"><%= inspect(@item[:metrics], pretty: true) %></pre>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Data Loading

  defp load_features do
    case Product.list_features() do
      {:ok, features} -> features
      _ -> []
    end
  end

  defp load_releases do
    case Product.list_releases() do
      {:ok, releases} -> releases
      _ -> []
    end
  end

  defp load_feedback do
    case Product.list_feedback() do
      {:ok, feedback} -> feedback
      _ -> []
    end
  end

  defp load_experiments do
    case Product.list_experiments() do
      {:ok, experiments} -> experiments
      _ -> []
    end
  end

  defp load_kpis do
    case Product.list_kpis() do
      {:ok, kpis} -> kpis
      _ -> []
    end
  end

  defp load_roadmap do
    case Product.get_roadmap() do
      {:ok, items} -> items
      _ -> []
    end
  end

  defp load_item("feature", id), do: load_by_id(&Product.get_feature/1, id)
  defp load_item("release", id), do: load_by_id(&Product.get_release/1, id)
  defp load_item("feedback", id), do: load_by_id(&Product.get_feedback/1, id)
  defp load_item("experiment", id), do: load_by_id(&Product.get_experiment/1, id)
  defp load_item(_, _), do: nil

  defp load_by_id(loader, id) do
    case loader.(id) do
      {:ok, item} -> item
      _ -> nil
    end
  end

  # Filtering & Helpers

  defp filter_by_status(items, :all, query), do: filter_items(items, query)

  defp filter_by_status(items, status, query) do
    items
    |> Enum.filter(fn i -> i[:status] == status end)
    |> filter_items(query)
  end

  defp filter_items(items, ""), do: items

  defp filter_items(items, query) do
    q = String.downcase(query)

    Enum.filter(items, fn item ->
      name = String.downcase(to_string(item[:name] || item[:title] || item[:content] || ""))
      String.contains?(name, q)
    end)
  end

  defp sentiment_color(:positive), do: "text-green-600"
  defp sentiment_color(:neutral), do: "text-gray-600"
  defp sentiment_color(:negative), do: "text-red-600"
  defp sentiment_color(_), do: "text-gray-600"

  defp sentiment_icon(:positive), do: "😊"
  defp sentiment_icon(:neutral), do: "😐"
  defp sentiment_icon(:negative), do: "😞"
  defp sentiment_icon(_), do: "❓"

  defp experiment_status_class(:running), do: "bg-blue-900 text-blue-300"
  defp experiment_status_class(:completed), do: "bg-green-900 text-green-300"
  defp experiment_status_class(:stopped), do: "bg-red-900 text-red-300"
  defp experiment_status_class(_), do: "bg-gray-700 text-gray-300"

  defp trend_color(:up), do: "text-green-600"
  defp trend_color(:down), do: "text-red-600"
  defp trend_color(:stable), do: "text-gray-600"
  defp trend_color(_), do: "text-gray-600"

  defp trend_icon(:up), do: "↗"
  defp trend_icon(:down), do: "↘"
  defp trend_icon(:stable), do: "→"
  defp trend_icon(_), do: "•"

  defp format_kpi_value(nil, _), do: "-"
  defp format_kpi_value(value, :percent), do: "#{value}%"
  defp format_kpi_value(value, :currency), do: "$#{value}"
  defp format_kpi_value(value, _), do: to_string(value)

  defp progress_percent(%{current_value: current, target: target})
       when is_number(current) and is_number(target) and target > 0 do
    min(100, round(current / target * 100))
  end

  defp progress_percent(_), do: 0

  defp group_by_quarter(items) do
    items
    |> Enum.group_by(fn i -> i[:quarter] || "Backlog" end)
    |> Enum.sort_by(fn {q, _} -> q end)
  end

  defp format_date(nil), do: "-"
  defp format_date(date) when is_binary(date), do: String.slice(date, 0..9)
  defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d")
  defp format_date(_), do: "-"
end
