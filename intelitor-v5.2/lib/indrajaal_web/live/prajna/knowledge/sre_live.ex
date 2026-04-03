defmodule IndrajaalWeb.Prajna.Knowledge.SRELive do
  @moduledoc """
  PRAJNA C3I SRE Knowledge Screen

  WHAT: SRE-centric knowledge management for operational excellence
        and reliability engineering.

  WHY: Provides SRE teams with essential knowledge artifacts:
       - Runbooks and playbooks for incident response
       - SLO/SLI definitions and current status
       - Postmortem library with action items
       - Chaos engineering experiments
       - Change management tracking

  CONSTRAINTS:
    - SC-HMI-001: Dark Cockpit defaults
    - SC-KMS-001: SQLite+DuckDB only
    - SC-KMS-009: Incident traceability mandatory
    - SC-SRE-001: <50ms query latency for runbooks

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-30 |
  | Author | Cybernetic Architect |
  | Reference | Fractal Holonic Architecture |
  """

  use IndrajaalWeb, :live_view

  alias Indrajaal.KMS.SRE

  @refresh_interval 10_000

  @severity_colors %{
    critical: "text-red-500",
    high: "text-orange-400",
    medium: "text-yellow-600",
    low: "text-green-600"
  }
  def severity_color(sev), do: Map.get(@severity_colors, sev, "text-gray-600")

  @slo_status_colors %{
    healthy: "text-green-600",
    warning: "text-yellow-600",
    breached: "text-red-500"
  }
  def slo_color(status), do: Map.get(@slo_status_colors, status, "text-gray-600")

  @impl true
  def mount(_params, _session, socket) do
    try do
      if connected?(socket) do
        :timer.send_interval(@refresh_interval, self(), :refresh)
        Phoenix.PubSub.subscribe(Indrajaal.PubSub, "prajna:kms:sre")
      end

      {:ok,
       socket
       |> assign(:page_title, "SRE Knowledge")
       |> assign(:view_mode, :runbooks)
       |> assign(:runbooks, load_runbooks())
       |> assign(:slos, load_slos())
       |> assign(:postmortems, load_postmortems())
       |> assign(:chaos_experiments, load_chaos_experiments())
       |> assign(:changes, load_changes())
       |> assign(:toil_items, load_toil_items())
       |> assign(:selected_item, nil)
       |> assign(:search_query, "")
       |> assign(:filter_severity, :all)}
    rescue
      error ->
        require Logger
        Logger.warning("[SRELive] mount/3 failed, rendering with empty data: #{inspect(error)}")

        {:ok,
         socket
         |> assign(:page_title, "SRE Knowledge")
         |> assign(:view_mode, :runbooks)
         |> assign(:runbooks, [])
         |> assign(:slos, [])
         |> assign(:postmortems, [])
         |> assign(:chaos_experiments, [])
         |> assign(:changes, [])
         |> assign(:toil_items, [])
         |> assign(:selected_item, nil)
         |> assign(:search_query, "")
         |> assign(:filter_severity, :all)}
    end
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply,
     socket
     |> assign(:slos, load_slos())
     |> assign(:changes, load_changes())}
  end

  @impl true
  def handle_info({:sre_event, _event}, socket) do
    {:noreply, assign(socket, :runbooks, load_runbooks())}
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
  def handle_event("filter_severity", %{"severity" => severity}, socket) do
    sev_atom = if severity == "all", do: :all, else: String.to_existing_atom(severity)
    {:noreply, assign(socket, :filter_severity, sev_atom)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-surface-primary text-content-primary p-6">
      <header class="mb-6">
        <h1 class="text-2xl font-bold text-orange-400">🔧 SRE Knowledge</h1>
        <p class="text-gray-600 text-sm">Runbooks, SLOs, postmortems, chaos, changes</p>
      </header>
      
    <!-- View Mode Tabs -->
      <nav class="flex space-x-2 mb-6 border-b border-border-theme-primary pb-2">
        <.view_tab view={:runbooks} current={@view_mode} label="Runbooks" icon="📖" />
        <.view_tab view={:slos} current={@view_mode} label="SLOs" icon="📈" />
        <.view_tab view={:postmortems} current={@view_mode} label="Postmortems" icon="📋" />
        <.view_tab view={:chaos} current={@view_mode} label="Chaos" icon="💥" />
        <.view_tab view={:changes} current={@view_mode} label="Changes" icon="🔄" />
        <.view_tab view={:toil} current={@view_mode} label="Toil" icon="⚙️" />
      </nav>

      <div class="flex gap-6">
        <!-- Main Content -->
        <div class="flex-1">
          <%= case @view_mode do %>
            <% :runbooks -> %>
              <.runbooks_view runbooks={filter_items(@runbooks, @search_query)} />
            <% :slos -> %>
              <.slos_view slos={@slos} />
            <% :postmortems -> %>
              <.postmortems_view
                postmortems={filter_by_severity(@postmortems, @filter_severity, @search_query)}
                filter={@filter_severity}
              />
            <% :chaos -> %>
              <.chaos_view experiments={filter_items(@chaos_experiments, @search_query)} />
            <% :changes -> %>
              <.changes_view changes={filter_items(@changes, @search_query)} />
            <% :toil -> %>
              <.toil_view items={filter_items(@toil_items, @search_query)} />
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
        do: "bg-gray-700 text-orange-400",
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

  defp runbooks_view(assigns) do
    ~H"""
    <div class="space-y-4">
      <input
        type="text"
        phx-keyup="search"
        phx-debounce="300"
        name="query"
        placeholder="Search runbooks..."
        class="w-full bg-surface-secondary border border-border-theme-secondary rounded px-3 py-2 text-sm"
      />

      <div class="grid grid-cols-2 gap-4">
        <%= for runbook <- @runbooks do %>
          <div
            phx-click="select_item"
            phx-value-id={runbook[:id]}
            phx-value-type="runbook"
            class="bg-surface-secondary rounded-lg p-4 border border-border-theme-primary hover:border-orange-500 cursor-pointer"
          >
            <div class="flex items-center justify-between mb-2">
              <h3 class="font-medium text-orange-400">📖 {runbook[:title] || runbook[:name]}</h3>
              <span class={"text-xs #{severity_color(runbook[:severity])}"}>
                {runbook[:severity]}
              </span>
            </div>
            <p class="text-sm text-gray-600">{String.slice(runbook[:description] || "", 0..80)}...</p>
            <div class="mt-2 flex flex-wrap gap-1">
              <%= for tag <- (runbook[:tags] || []) do %>
                <span class="text-xs bg-gray-700 px-2 py-0.5 rounded">{tag}</span>
              <% end %>
            </div>
            <div class="mt-2 text-xs text-gray-500">
              Last updated: {format_date(runbook[:updated_at])}
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp slos_view(assigns) do
    ~H"""
    <div class="space-y-4">
      <!-- SLO Summary Cards -->
      <div class="grid grid-cols-4 gap-4 mb-6">
        <div class="bg-surface-secondary rounded-lg p-4 border border-border-theme-primary">
          <div class="text-sm text-gray-600">Healthy</div>
          <div class="text-2xl font-bold text-green-600">{count_slo_status(@slos, :healthy)}</div>
        </div>
        <div class="bg-surface-secondary rounded-lg p-4 border border-border-theme-primary">
          <div class="text-sm text-gray-600">Warning</div>
          <div class="text-2xl font-bold text-yellow-600">{count_slo_status(@slos, :warning)}</div>
        </div>
        <div class="bg-surface-secondary rounded-lg p-4 border border-border-theme-primary">
          <div class="text-sm text-gray-600">Breached</div>
          <div class="text-2xl font-bold text-red-500">{count_slo_status(@slos, :breached)}</div>
        </div>
        <div class="bg-surface-secondary rounded-lg p-4 border border-border-theme-primary">
          <div class="text-sm text-gray-600">Error Budget</div>
          <div class="text-2xl font-bold text-orange-400">{avg_error_budget(@slos)}%</div>
        </div>
      </div>
      
    <!-- SLO List -->
      <div class="space-y-2">
        <%= for slo <- @slos do %>
          <div
            phx-click="select_item"
            phx-value-id={slo[:id]}
            phx-value-type="slo"
            class="bg-surface-secondary rounded-lg p-4 border border-border-theme-primary hover:border-orange-500 cursor-pointer"
          >
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-3">
                <span class={"w-3 h-3 rounded-full #{slo_bg_color(slo[:status])}"}></span>
                <div>
                  <h3 class="font-medium text-content-primary">{slo[:name]}</h3>
                  <p class="text-xs text-gray-500">{slo[:service]}</p>
                </div>
              </div>
              <div class="text-right">
                <div class={"text-lg font-bold #{slo_color(slo[:status])}"}>
                  {slo[:current_value]}%
                </div>
                <div class="text-xs text-gray-500">Target: {slo[:target]}%</div>
              </div>
            </div>
            <div class="mt-3">
              <div class="flex justify-between text-xs text-gray-500 mb-1">
                <span>Error Budget</span>
                <span>{slo[:error_budget_remaining]}% remaining</span>
              </div>
              <div class="h-2 bg-gray-700 rounded">
                <div
                  class={"h-2 rounded #{error_budget_color(slo[:error_budget_remaining])}"}
                  style={"width: #{slo[:error_budget_remaining]}%"}
                >
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp postmortems_view(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex items-center gap-4 mb-4">
        <select
          phx-change="filter_severity"
          name="severity"
          class="bg-surface-secondary border border-border-theme-secondary rounded px-3 py-1 text-sm"
        >
          <option value="all" selected={@filter == :all}>All Severity</option>
          <option value="critical" selected={@filter == :critical}>Critical</option>
          <option value="high" selected={@filter == :high}>High</option>
          <option value="medium" selected={@filter == :medium}>Medium</option>
        </select>
        <input
          type="text"
          phx-keyup="search"
          phx-debounce="300"
          name="query"
          placeholder="Search postmortems..."
          class="bg-surface-secondary border border-border-theme-secondary rounded px-3 py-1 text-sm flex-1"
        />
      </div>

      <%= for pm <- @postmortems do %>
        <div
          phx-click="select_item"
          phx-value-id={pm[:id]}
          phx-value-type="postmortem"
          class="bg-surface-secondary rounded-lg p-4 border border-border-theme-primary hover:border-orange-500 cursor-pointer"
        >
          <div class="flex items-center justify-between mb-2">
            <div>
              <span class={"text-xs font-bold #{severity_color(pm[:severity])}"}>
                {pm[:severity]}
              </span>
              <h3 class="text-lg font-medium text-content-primary">{pm[:title]}</h3>
            </div>
            <div class="text-xs text-gray-500">{format_date(pm[:incident_date])}</div>
          </div>
          <p class="text-sm text-gray-600">{String.slice(pm[:summary] || "", 0..120)}...</p>
          <div class="mt-2 flex items-center justify-between text-xs">
            <span class="text-gray-500">Duration: {pm[:duration_minutes]} min</span>
            <span class={"#{pm[:action_items_completed] && "text-green-600" || "text-yellow-600"}"}>
              Action Items: {(pm[:action_items_completed] && "Complete") || "Pending"}
            </span>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp chaos_view(assigns) do
    ~H"""
    <div class="space-y-4">
      <%= for exp <- @experiments do %>
        <div
          phx-click="select_item"
          phx-value-id={exp[:id]}
          phx-value-type="chaos"
          class="bg-surface-secondary rounded-lg p-4 border border-border-theme-primary hover:border-orange-500 cursor-pointer"
        >
          <div class="flex items-center justify-between mb-2">
            <h3 class="font-medium text-orange-400">💥 {exp[:name]}</h3>
            <span class={"text-xs px-2 py-1 rounded #{chaos_status_class(exp[:status])}"}>
              {exp[:status]}
            </span>
          </div>
          <p class="text-sm text-gray-600">{exp[:hypothesis]}</p>
          <div class="mt-2 grid grid-cols-3 gap-2 text-xs text-gray-500">
            <div>Target: {exp[:target_service]}</div>
            <div>Type: {exp[:fault_type]}</div>
            <div>Blast: {exp[:blast_radius]}</div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp changes_view(assigns) do
    ~H"""
    <div class="space-y-4">
      <%= for change <- @changes do %>
        <div
          phx-click="select_item"
          phx-value-id={change[:id]}
          phx-value-type="change"
          class="bg-surface-secondary rounded-lg p-4 border border-border-theme-primary hover:border-orange-500 cursor-pointer"
        >
          <div class="flex items-center justify-between">
            <div>
              <h3 class="font-medium text-content-primary">
                🔄 {change[:title] || change[:description]}
              </h3>
              <p class="text-sm text-gray-600 mt-1">
                {String.slice(change[:description] || "", 0..80)}...
              </p>
            </div>
            <div class="text-right">
              <span class={"text-xs px-2 py-1 rounded #{change_status_class(change[:status])}"}>
                {change[:status]}
              </span>
              <div class="text-xs text-gray-500 mt-1">{format_date(change[:scheduled_at])}</div>
            </div>
          </div>
          <div class="mt-2 flex items-center gap-4 text-xs text-gray-500">
            <span>
              Risk: <span class={severity_color(change[:risk_level])}>{change[:risk_level]}</span>
            </span>
            <span>Owner: {change[:owner]}</span>
            <span>Services: {length(change[:affected_services] || [])}</span>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp toil_view(assigns) do
    ~H"""
    <div class="space-y-4">
      <!-- Toil Summary -->
      <div class="grid grid-cols-3 gap-4 mb-6">
        <div class="bg-surface-secondary rounded-lg p-4 border border-border-theme-primary">
          <div class="text-sm text-gray-600">Total Toil Hours/Week</div>
          <div class="text-2xl font-bold text-orange-400">{total_toil_hours(@items)}h</div>
        </div>
        <div class="bg-surface-secondary rounded-lg p-4 border border-border-theme-primary">
          <div class="text-sm text-gray-600">Automation Candidates</div>
          <div class="text-2xl font-bold text-green-600">{count_automatable(@items)}</div>
        </div>
        <div class="bg-surface-secondary rounded-lg p-4 border border-border-theme-primary">
          <div class="text-sm text-gray-600">Open Items</div>
          <div class="text-2xl font-bold text-yellow-600">{count_open(@items)}</div>
        </div>
      </div>
      
    <!-- Toil List -->
      <%= for item <- @items do %>
        <div
          phx-click="select_item"
          phx-value-id={item[:id]}
          phx-value-type="toil"
          class="bg-surface-secondary rounded-lg p-4 border border-border-theme-primary hover:border-orange-500 cursor-pointer"
        >
          <div class="flex items-center justify-between">
            <div>
              <h3 class="font-medium text-content-primary">⚙️ {item[:title] || item[:name]}</h3>
              <p class="text-sm text-gray-600 mt-1">
                {String.slice(item[:description] || "", 0..80)}...
              </p>
            </div>
            <div class="text-right">
              <div class="text-lg font-bold text-orange-400">{item[:hours_per_week]}h/wk</div>
              <div class="text-xs text-gray-500">{item[:frequency]}</div>
            </div>
          </div>
          <div class="mt-2 flex items-center gap-4 text-xs">
            <span class={(item[:automatable] && "text-green-600") || "text-gray-500"}>
              {(item[:automatable] && "✓ Automatable") || "Manual"}
            </span>
            <span class="text-gray-500">Priority: {item[:priority]}</span>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp detail_panel(assigns) do
    ~H"""
    <div>
      <h3 class="text-lg font-bold text-orange-400 mb-4">{@item[:title] || @item[:name]}</h3>

      <div class="space-y-3 text-sm">
        <%= if @item[:description] do %>
          <div>
            <label class="text-gray-600">Description</label>
            <p class="text-content-secondary">{@item[:description]}</p>
          </div>
        <% end %>

        <%= if @item[:steps] do %>
          <div>
            <label class="text-gray-600">Steps</label>
            <ol class="list-decimal list-inside text-content-secondary space-y-1">
              <%= for step <- (@item[:steps] || []) do %>
                <li>{step}</li>
              <% end %>
            </ol>
          </div>
        <% end %>

        <%= if @item[:root_cause] do %>
          <div>
            <label class="text-gray-600">Root Cause</label>
            <p class="text-content-secondary">{@item[:root_cause]}</p>
          </div>
        <% end %>

        <%= if @item[:lessons_learned] do %>
          <div>
            <label class="text-gray-600">Lessons Learned</label>
            <ul class="list-disc list-inside text-content-secondary space-y-1">
              <%= for lesson <- (@item[:lessons_learned] || []) do %>
                <li>{lesson}</li>
              <% end %>
            </ul>
          </div>
        <% end %>

        <%= if @item[:action_items] do %>
          <div>
            <label class="text-gray-600">Action Items</label>
            <ul class="space-y-1">
              <%= for action <- (@item[:action_items] || []) do %>
                <li class="flex items-center gap-2 text-content-secondary">
                  <span class={(action[:completed] && "text-green-600") || "text-yellow-600"}>
                    {(action[:completed] && "✓") || "○"}
                  </span>
                  {action[:description]}
                </li>
              <% end %>
            </ul>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Data Loading

  defp load_runbooks do
    case SRE.list_runbooks() do
      {:ok, runbooks} -> runbooks
      _ -> []
    end
  end

  defp load_slos do
    case SRE.list_slos() do
      {:ok, slos} -> slos
      _ -> []
    end
  end

  defp load_postmortems do
    case SRE.list_postmortems() do
      {:ok, pms} -> pms
      _ -> []
    end
  end

  defp load_chaos_experiments do
    case SRE.list_chaos_experiments() do
      {:ok, exps} -> exps
      _ -> []
    end
  end

  defp load_changes do
    case SRE.list_changes() do
      {:ok, changes} -> changes
      _ -> []
    end
  end

  defp load_toil_items do
    case SRE.list_toil_items() do
      {:ok, items} -> items
      _ -> []
    end
  end

  defp load_item("runbook", id), do: load_by_id(&SRE.get_runbook/1, id)
  defp load_item("slo", id), do: load_by_id(&SRE.get_slo/1, id)
  defp load_item("postmortem", id), do: load_by_id(&SRE.get_postmortem/1, id)
  defp load_item("chaos", id), do: load_by_id(&SRE.get_chaos_experiment/1, id)
  defp load_item("change", id), do: load_by_id(&SRE.get_change/1, id)
  defp load_item("toil", id), do: load_by_id(&SRE.get_toil_item/1, id)
  defp load_item(_, _), do: nil

  defp load_by_id(loader, id) do
    case loader.(id) do
      {:ok, item} -> item
      _ -> nil
    end
  end

  # Filtering & Helpers

  defp filter_items(items, ""), do: items

  defp filter_items(items, query) do
    q = String.downcase(query)

    Enum.filter(items, fn item ->
      title = String.downcase(to_string(item[:title] || item[:name] || ""))
      String.contains?(title, q)
    end)
  end

  defp filter_by_severity(items, :all, query), do: filter_items(items, query)

  defp filter_by_severity(items, severity, query) do
    items
    |> Enum.filter(fn i -> i[:severity] == severity end)
    |> filter_items(query)
  end

  defp count_slo_status(slos, status), do: Enum.count(slos, fn s -> s[:status] == status end)

  defp avg_error_budget([]), do: 0.0

  defp avg_error_budget(slos) do
    total = Enum.reduce(slos, 0.0, fn s, acc -> acc + (s[:error_budget_remaining] || 0.0) end)
    Float.round(total / length(slos), 1)
  end

  defp slo_bg_color(:healthy), do: "bg-green-400"
  defp slo_bg_color(:warning), do: "bg-yellow-400"
  defp slo_bg_color(:breached), do: "bg-red-500"
  defp slo_bg_color(_), do: "bg-gray-400"

  defp error_budget_color(budget) when budget > 50, do: "bg-green-500"
  defp error_budget_color(budget) when budget > 20, do: "bg-yellow-500"
  defp error_budget_color(_), do: "bg-red-500"

  defp chaos_status_class(:running), do: "bg-blue-900 text-blue-300"
  defp chaos_status_class(:completed), do: "bg-green-900 text-green-300"
  defp chaos_status_class(:failed), do: "bg-red-900 text-red-300"
  defp chaos_status_class(:scheduled), do: "bg-gray-700 text-gray-300"
  defp chaos_status_class(_), do: "bg-gray-700 text-gray-300"

  defp change_status_class(:approved), do: "bg-green-900 text-green-300"
  defp change_status_class(:pending), do: "bg-yellow-900 text-yellow-300"
  defp change_status_class(:deployed), do: "bg-blue-900 text-blue-300"
  defp change_status_class(:rolled_back), do: "bg-red-900 text-red-300"
  defp change_status_class(_), do: "bg-gray-700 text-gray-300"

  defp total_toil_hours(items),
    do: Enum.reduce(items, 0, fn i, acc -> acc + (i[:hours_per_week] || 0) end)

  defp count_automatable(items), do: Enum.count(items, fn i -> i[:automatable] end)
  defp count_open(items), do: Enum.count(items, fn i -> i[:status] != :resolved end)

  defp format_date(nil), do: "-"
  defp format_date(date) when is_binary(date), do: String.slice(date, 0..9)
  defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d")
  defp format_date(_), do: "-"
end
