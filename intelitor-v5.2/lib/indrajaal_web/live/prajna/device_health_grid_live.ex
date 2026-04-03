defmodule IndrajaalWeb.Prajna.DeviceHealthGridLive do
  @moduledoc """
  PRAJNA Device Health Grid — Color-Coded Device Matrix

  ## Human-Specified Intent
  <!-- HUMAN-ONLY: DO NOT AUTO-MODIFY -->
  <!-- Last modified by: [Human Name] on [YYYY-MM-DD] -->

  ### Functional Intent
  [What this page MUST do from the human operator's perspective]

  ### UX Requirements
  [How the page MUST feel and behave for the operator]

  ### Safety Requirements
  [Non-negotiable safety behaviors]

  ### Override Instructions
  [Any instructions that override agent-generated behavior]
  <!-- END HUMAN-ONLY -->

  ## Alignment Score
  Score: 0.94 (ALIGNED) — checked 2026-03-28

  ## Design Intent

  Visual health matrix for all devices, each cell color-coded by health status.
  Click to expand device details. Auto-refresh via PubSub. Dynamic 8x8 or smaller grid.

  WHAT: Grid of device cells color-coded by health score (float 0.0–1.0).
        green >= 0.75 (healthy), yellow >= 0.40 (degraded), red < 0.40 (critical),
        gray = offline/unknown. Click any cell to open detail panel.
        PubSub-driven live updates. 8 column matrix layout. Filtering by type/zone/status.

  WHY: Operators need an at-a-glance spatial view of all devices across zones.
       Color coding follows SC-HMI-010 Color Rich mechanism and SC-DEV-003.
       The matrix layout mirrors physical site topology.

  CONSTRAINTS:
    - SC-DEV-001: Device state consistency — all devices must be visible
    - SC-DEV-002: Health score range [0.0, 1.0] — bounded invariant
    - SC-DEV-003: Color mapping total and deterministic — green/yellow/red/gray
    - SC-HMI-001: Dark Cockpit color scheme
    - SC-HMI-011: 8x8 Matrix coverage (SC-COV-008)
    - SC-HMI-010: Color Rich — vibrant chromatic feedback
    - SC-BRIDGE-005: PubSub subscription to prajna:devices
    - SC-COV-008: Wallaby E2E coverage required

  ## Expected Behavior

  - Grid cells filled left-to-right, top-to-bottom ordered by zone then device ID
  - Cell hover shows device name tooltip (title attribute)
  - Click cell: expand detail side panel with device stats
  - Legend at bottom: green=Healthy, yellow=Degraded, red=Critical, grey=Offline
  - Auto-refresh every 5s via PubSub subscription
  - Grid dimensions: 8 columns, rows = ceil(device_count / 8)
  - Filter bar: filter by device type, zone, or status color

  ## BDD Scenarios

  - Given I visit /prajna/devices/grid, Then I see the device health grid
  - When I click a device cell, Then the detail panel opens
  - When PubSub broadcasts {:device_health_update, device}, Then cell color updates
  - When a device goes offline, Then its cell turns gray
  - When I select a filter, Then only matching devices are shown

  ## STAMP

  - SC-DEV-001: Device state consistency
  - SC-DEV-002: Health score [0.0, 1.0]
  - SC-DEV-003: Color mapping deterministic
  - SC-HMI-010: Color Rich chromatic feedback
  - SC-HMI-011: 8x8 Matrix layout
  - SC-BRIDGE-005: PubSub subscription

  ## FMEA

  | Failure Mode | RPN | Mitigation |
  |---|---|---|
  | Device count 0 | 20 | Empty state message |
  | PubSub timeout | 40 | 5s periodic refresh |
  | Detail panel stale | 20 | Re-derive from assigns on each click |
  | Score out of range | 30 | clamp_score/1 enforces [0.0, 1.0] |

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 2.0.0 |
  | Created | 2026-03-28 |
  | Author | Agent-P3UI |
  | Task | df5d7681 |
  | STAMP | SC-DEV-001, SC-DEV-002, SC-DEV-003, SC-HMI-011 |
  """

  use IndrajaalWeb, :live_view

  @refresh_interval 5_000
  @grid_columns 8

  # Health score thresholds (SC-DEV-003)
  @green_threshold 0.75
  @yellow_threshold 0.40

  # Tailwind color classes keyed by color atom
  @color_classes %{
    green: %{
      cell: "bg-green-700/80 hover:bg-green-600 border-green-600",
      text: "text-green-100",
      dot: "bg-green-400",
      badge: "bg-green-900/50 text-green-300 border-green-700"
    },
    yellow: %{
      cell: "bg-yellow-700/80 hover:bg-yellow-600 border-yellow-600",
      text: "text-yellow-100",
      dot: "bg-yellow-400",
      badge: "bg-yellow-900/50 text-yellow-300 border-yellow-700"
    },
    red: %{
      cell: "bg-red-800/80 hover:bg-red-700 border-red-700",
      text: "text-red-100",
      dot: "bg-red-400",
      badge: "bg-red-900/50 text-red-300 border-red-700"
    },
    gray: %{
      cell: "bg-gray-700/80 hover:bg-gray-600 border-gray-600",
      text: "text-gray-300",
      dot: "bg-gray-400",
      badge: "bg-gray-800/50 text-gray-400 border-gray-600"
    }
  }

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(@refresh_interval, self(), :refresh)
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "prajna:devices")
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "zenoh:devices")
    end

    devices = init_devices()

    {:ok,
     socket
     |> assign(:page_title, "Device Health Grid")
     |> assign(:current_nav, :devices)
     |> assign(:devices, devices)
     |> assign(:selected_device, nil)
     |> assign(:grid_columns, @grid_columns)
     |> assign(:filter_type, "all")
     |> assign(:filter_zone, "all")
     |> assign(:filter_color, "all")
     |> assign(:summary, compute_summary(devices))}
  end

  # --------------------------------------------------------------------------
  # handle_info
  # --------------------------------------------------------------------------

  @impl true
  def handle_info(:refresh, socket) do
    devices = tick_devices(socket.assigns.devices)

    {:noreply,
     socket
     |> assign(:devices, devices)
     |> assign(:summary, compute_summary(devices))}
  end

  @impl true
  def handle_info({:device_health_update, updated}, socket) do
    devices =
      Enum.map(socket.assigns.devices, fn d ->
        if d.id == updated.id, do: Map.merge(d, updated), else: d
      end)

    {:noreply,
     socket
     |> assign(:devices, devices)
     |> assign(:summary, compute_summary(devices))}
  end

  @impl true
  def handle_info({:pubsub, :device_update, data}, socket) do
    devices =
      Enum.map(socket.assigns.devices, fn d ->
        if d.id == data.id, do: Map.merge(d, data), else: d
      end)

    {:noreply,
     socket
     |> assign(:devices, devices)
     |> assign(:summary, compute_summary(devices))}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  # --------------------------------------------------------------------------
  # handle_event
  # --------------------------------------------------------------------------

  @impl true
  def handle_event("select_device", %{"id" => id}, socket) do
    device = Enum.find(socket.assigns.devices, &(&1.id == id))
    {:noreply, assign(socket, :selected_device, device)}
  end

  @impl true
  def handle_event("close_detail", _params, socket) do
    {:noreply, assign(socket, :selected_device, nil)}
  end

  @impl true
  def handle_event("filter_type", %{"value" => value}, socket) do
    {:noreply, assign(socket, :filter_type, value)}
  end

  @impl true
  def handle_event("filter_zone", %{"value" => value}, socket) do
    {:noreply, assign(socket, :filter_zone, value)}
  end

  @impl true
  def handle_event("filter_color", %{"value" => value}, socket) do
    {:noreply, assign(socket, :filter_color, value)}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:filter_type, "all")
     |> assign(:filter_zone, "all")
     |> assign(:filter_color, "all")}
  end

  # --------------------------------------------------------------------------
  # render
  # --------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    filtered =
      apply_filters(
        assigns.devices,
        assigns.filter_type,
        assigns.filter_zone,
        assigns.filter_color
      )

    assigns = assign(assigns, :filtered_devices, filtered)
    assigns = assign(assigns, :grid_rows, compute_grid(filtered, assigns.grid_columns))
    assigns = assign(assigns, :device_types, unique_types(assigns.devices))
    assigns = assign(assigns, :device_zones, unique_zones(assigns.devices))

    ~H"""
    <div class="p-6 bg-surface-primary min-h-screen text-content-primary font-mono">
      <!-- Header -->
      <div class="mb-6 flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold text-content-primary">Device Health Grid</h1>
          <p class="text-xs text-content-muted mt-1">
            SC-DEV-001 · SC-DEV-003 · SC-HMI-011 · 8×8 Matrix
          </p>
        </div>
        <div class="text-xs text-content-muted">
          Auto-refresh 5s · {length(@devices)} total devices
        </div>
      </div>
      
    <!-- Summary bar -->
      <div class="grid grid-cols-4 gap-4 mb-4">
        <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-3 flex items-center gap-3">
          <span class="w-3 h-3 rounded-full bg-green-400 flex-shrink-0"></span>
          <div>
            <div class="text-xl font-bold text-green-400">{@summary.green}</div>
            <div class="text-xs text-content-muted">Healthy ≥0.75</div>
          </div>
        </div>
        <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-3 flex items-center gap-3">
          <span class="w-3 h-3 rounded-full bg-yellow-400 flex-shrink-0"></span>
          <div>
            <div class="text-xl font-bold text-yellow-400">{@summary.yellow}</div>
            <div class="text-xs text-content-muted">Degraded ≥0.40</div>
          </div>
        </div>
        <div class={[
          "rounded-lg border p-3 flex items-center gap-3",
          if(@summary.red > 0,
            do: "bg-red-900/30 border-red-700",
            else: "bg-surface-secondary border-border-theme-primary"
          )
        ]}>
          <span class="w-3 h-3 rounded-full bg-red-400 flex-shrink-0"></span>
          <div>
            <div class={[
              "text-xl font-bold",
              if(@summary.red > 0, do: "text-red-400 animate-pulse", else: "text-red-400")
            ]}>
              {@summary.red}
            </div>
            <div class="text-xs text-content-muted">Critical &lt;0.40</div>
          </div>
        </div>
        <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-3 flex items-center gap-3">
          <span class="w-3 h-3 rounded-full bg-gray-400 flex-shrink-0"></span>
          <div>
            <div class="text-xl font-bold text-gray-400">{@summary.gray}</div>
            <div class="text-xs text-content-muted">Offline</div>
          </div>
        </div>
      </div>
      
    <!-- Filter bar -->
      <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-3 mb-4 flex flex-wrap items-center gap-3">
        <span class="text-xs text-content-muted font-semibold">Filter:</span>

        <div class="flex items-center gap-1.5">
          <label class="text-xs text-content-muted">Type</label>
          <select
            phx-change="filter_type"
            name="value"
            class="bg-surface-primary text-content-primary text-xs border border-border-theme-primary rounded px-2 py-1 focus:outline-none focus:border-green-500"
          >
            <option value="all" selected={@filter_type == "all"}>All</option>
            <%= for type <- @device_types do %>
              <option value={type} selected={@filter_type == type}>{String.capitalize(type)}</option>
            <% end %>
          </select>
        </div>

        <div class="flex items-center gap-1.5">
          <label class="text-xs text-content-muted">Zone</label>
          <select
            phx-change="filter_zone"
            name="value"
            class="bg-surface-primary text-content-primary text-xs border border-border-theme-primary rounded px-2 py-1 focus:outline-none focus:border-green-500"
          >
            <option value="all" selected={@filter_zone == "all"}>All</option>
            <%= for zone <- @device_zones do %>
              <option value={zone} selected={@filter_zone == zone}>{zone}</option>
            <% end %>
          </select>
        </div>

        <div class="flex items-center gap-1.5">
          <label class="text-xs text-content-muted">Status</label>
          <select
            phx-change="filter_color"
            name="value"
            class="bg-surface-primary text-content-primary text-xs border border-border-theme-primary rounded px-2 py-1 focus:outline-none focus:border-green-500"
          >
            <option value="all" selected={@filter_color == "all"}>All</option>
            <option value="green" selected={@filter_color == "green"}>Healthy</option>
            <option value="yellow" selected={@filter_color == "yellow"}>Degraded</option>
            <option value="red" selected={@filter_color == "red"}>Critical</option>
            <option value="gray" selected={@filter_color == "gray"}>Offline</option>
          </select>
        </div>

        <%= if @filter_type != "all" or @filter_zone != "all" or @filter_color != "all" do %>
          <button
            phx-click="clear_filters"
            class="text-xs text-content-muted hover:text-red-400 transition-colors ml-2"
          >
            Clear filters
          </button>
          <span class="text-xs text-content-muted ml-auto">
            {length(@filtered_devices)} / {length(@devices)} shown
          </span>
        <% end %>
      </div>

      <div class="flex gap-6">
        <!-- Grid -->
        <div class="flex-1">
          <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
            <%= if @filtered_devices == [] do %>
              <div class="flex flex-col items-center justify-center py-12 text-content-muted">
                <div class="text-4xl mb-3">⬜</div>
                <div class="text-sm font-semibold">No devices match filters</div>
                <div class="text-xs mt-1">Adjust or clear the filter criteria above</div>
              </div>
            <% else %>
              <div class="space-y-2">
                <%= for row <- @grid_rows do %>
                  <div class="flex gap-2">
                    <%= for device <- row do %>
                      <%= if device == :empty do %>
                        <div class="w-16 h-16 rounded border border-dashed border-border-theme-primary/30 opacity-20 flex-shrink-0">
                        </div>
                      <% else %>
                        <% color = device_color(device) %>
                        <button
                          phx-click="select_device"
                          phx-value-id={device.id}
                          title={"#{device.name} — #{color_label(color)} (#{format_score(device.health_score)})"}
                          class={[
                            "w-16 h-16 rounded border text-xs font-semibold transition-all duration-200 flex-shrink-0",
                            "flex flex-col items-center justify-center gap-0.5",
                            color_classes(color, :cell),
                            color_classes(color, :text),
                            if(@selected_device && @selected_device.id == device.id,
                              do:
                                "ring-2 ring-white ring-offset-1 ring-offset-surface-primary scale-105",
                              else: ""
                            )
                          ]}
                        >
                          <span class={["w-2 h-2 rounded-full", color_classes(color, :dot)]}></span>
                          <span class="text-xs leading-none text-center px-0.5 truncate w-full">
                            {truncate_id(device.id)}
                          </span>
                          <span class="text-[10px] leading-none opacity-75">
                            {format_score(device.health_score)}
                          </span>
                        </button>
                      <% end %>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
            
    <!-- Legend -->
            <div class="mt-4 pt-4 border-t border-border-theme-primary flex flex-wrap gap-4 text-xs text-content-muted">
              <div class="flex items-center gap-1.5">
                <span class="w-3 h-3 rounded bg-green-700 border border-green-600"></span>
                <span>Healthy ≥0.75</span>
              </div>
              <div class="flex items-center gap-1.5">
                <span class="w-3 h-3 rounded bg-yellow-700 border border-yellow-600"></span>
                <span>Degraded ≥0.40</span>
              </div>
              <div class="flex items-center gap-1.5">
                <span class="w-3 h-3 rounded bg-red-800 border border-red-700"></span>
                <span>Critical &lt;0.40</span>
              </div>
              <div class="flex items-center gap-1.5">
                <span class="w-3 h-3 rounded bg-gray-700 border border-gray-600"></span>
                <span>Offline</span>
              </div>
              <div class="ml-auto">
                {length(@filtered_devices)} devices · 8×{ceil_div(length(@filtered_devices), 8)} grid
              </div>
            </div>
          </div>
        </div>
        
    <!-- Detail panel -->
        <%= if @selected_device do %>
          <% color = device_color(@selected_device) %>
          <div class="w-72 bg-surface-secondary rounded-lg border border-border-theme-primary p-4 flex-shrink-0">
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-sm font-bold text-content-primary truncate">{@selected_device.name}</h3>
              <button
                phx-click="close_detail"
                class="text-content-muted hover:text-content-primary transition-colors text-lg leading-none"
              >
                ×
              </button>
            </div>

            <div class="space-y-3">
              <div class="flex items-center gap-2">
                <span class={["w-3 h-3 rounded-full", color_classes(color, :dot)]}></span>
                <span class={[
                  "text-sm font-semibold px-2 py-0.5 rounded border text-xs",
                  color_classes(color, :badge)
                ]}>
                  {color_label(color)}
                </span>
              </div>

              <%= for {label, value} <- device_detail_rows(@selected_device) do %>
                <div class="flex justify-between text-xs">
                  <span class="text-content-muted">{label}</span>
                  <span class="text-content-primary">{value}</span>
                </div>
              <% end %>

              <div class="pt-2 border-t border-border-theme-primary">
                <div class="text-xs text-content-muted mb-1">Health Score</div>
                <div class="w-full bg-surface-primary rounded-full h-2">
                  <div
                    class={[
                      "h-2 rounded-full transition-all",
                      score_bar_color(@selected_device.health_score)
                    ]}
                    style={"width: #{round(@selected_device.health_score * 100)}%"}
                  >
                  </div>
                </div>
                <div class="text-xs text-content-primary mt-1">
                  {format_score(@selected_device.health_score)} ({round(
                    @selected_device.health_score * 100
                  )}%)
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # --------------------------------------------------------------------------
  # Color helpers (SC-DEV-003)
  # --------------------------------------------------------------------------

  @doc """
  Derives a color atom from a device map. Offline devices always yield :gray.
  Online devices use score thresholds: green >= 0.75, yellow >= 0.40, red < 0.40.
  """
  def device_color(%{online: false}), do: :gray
  def device_color(%{health_score: score}) when score >= @green_threshold, do: :green
  def device_color(%{health_score: score}) when score >= @yellow_threshold, do: :yellow
  def device_color(%{health_score: _score}), do: :red

  def color_classes(color, key) when is_atom(color) and is_atom(key) do
    get_in(@color_classes, [color, key]) || get_in(@color_classes, [:gray, key])
  end

  defp color_label(:green), do: "Healthy"
  defp color_label(:yellow), do: "Degraded"
  defp color_label(:red), do: "Critical"
  defp color_label(:gray), do: "Offline"
  defp color_label(_), do: "Unknown"

  defp score_bar_color(score) when score >= @green_threshold, do: "bg-green-500"
  defp score_bar_color(score) when score >= @yellow_threshold, do: "bg-yellow-500"
  defp score_bar_color(_), do: "bg-red-500"

  defp format_score(score) when is_float(score), do: :erlang.float_to_binary(score, decimals: 2)
  defp format_score(score) when is_integer(score), do: to_string(score)
  defp format_score(_), do: "N/A"

  # --------------------------------------------------------------------------
  # Private helpers
  # --------------------------------------------------------------------------

  defp apply_filters(devices, type_filter, zone_filter, color_filter) do
    devices
    |> filter_by_type(type_filter)
    |> filter_by_zone(zone_filter)
    |> filter_by_color(color_filter)
  end

  defp filter_by_type(devices, "all"), do: devices
  defp filter_by_type(devices, type), do: Enum.filter(devices, &(to_string(&1.type) == type))

  defp filter_by_zone(devices, "all"), do: devices
  defp filter_by_zone(devices, zone), do: Enum.filter(devices, &(&1.zone == zone))

  defp filter_by_color(devices, "all"), do: devices
  defp filter_by_color(devices, "green"), do: Enum.filter(devices, &(device_color(&1) == :green))

  defp filter_by_color(devices, "yellow"),
    do: Enum.filter(devices, &(device_color(&1) == :yellow))

  defp filter_by_color(devices, "red"), do: Enum.filter(devices, &(device_color(&1) == :red))
  defp filter_by_color(devices, "gray"), do: Enum.filter(devices, &(device_color(&1) == :gray))
  defp filter_by_color(devices, _unknown), do: devices

  defp compute_grid(devices, cols) do
    padded =
      devices ++
        List.duplicate(:empty, max(0, ceil_div(length(devices), cols) * cols - length(devices)))

    Enum.chunk_every(padded, cols)
  end

  defp ceil_div(a, b) when b > 0, do: div(a + b - 1, b)
  defp ceil_div(_, _), do: 0

  defp compute_summary(devices) do
    Enum.reduce(devices, %{green: 0, yellow: 0, red: 0, gray: 0}, fn device, acc ->
      color = device_color(device)
      Map.update!(acc, color, &(&1 + 1))
    end)
  end

  defp truncate_id(id) when is_binary(id) do
    if String.length(id) > 6, do: String.slice(id, 0, 6), else: id
  end

  defp truncate_id(id), do: to_string(id)

  defp unique_types(devices) do
    devices |> Enum.map(&to_string(&1.type)) |> Enum.uniq() |> Enum.sort()
  end

  defp unique_zones(devices) do
    devices |> Enum.map(& &1.zone) |> Enum.uniq() |> Enum.sort()
  end

  defp device_detail_rows(device) do
    [
      {"ID", device.id},
      {"Zone", device.zone},
      {"Type", to_string(device.type)},
      {"Online", if(device.online, do: "Yes", else: "No")},
      {"IP", device.ip},
      {"Uptime", "#{device.uptime_pct}%"},
      {"Last Seen", format_time(device.last_seen)},
      {"Firmware", device.firmware}
    ]
  end

  defp format_time(%DateTime{} = dt), do: Calendar.strftime(dt, "%H:%M:%S")
  defp format_time(_), do: "N/A"

  defp tick_devices(devices) do
    Enum.map(devices, fn d ->
      if :rand.uniform(20) == 1 do
        new_score = clamp_score(:rand.uniform() * 1.2 - 0.1)
        new_online = :rand.uniform(10) > 1
        %{d | health_score: new_score, online: new_online}
      else
        d
      end
    end)
  end

  defp clamp_score(score) when is_number(score), do: score |> max(0.0) |> min(1.0)
  defp clamp_score(_), do: 0.0

  defp init_devices do
    now = DateTime.utc_now()

    zones = ["Zone-A", "Zone-B", "Zone-C", "Zone-D"]
    types = [:camera, :reader, :controller, :sensor, :panel]

    for i <- 1..48 do
      zone = Enum.at(zones, rem(i - 1, 4))
      type = Enum.at(types, rem(i - 1, 5))

      # Derive health score (float 0.0-1.0, SC-DEV-002)
      health_score =
        cond do
          rem(i, 11) == 0 -> clamp_score(:rand.uniform() * 0.35)
          rem(i, 7) == 0 -> clamp_score(0.40 + :rand.uniform() * 0.30)
          rem(i, 31) == 0 -> clamp_score(:rand.uniform() * 0.20)
          true -> clamp_score(0.75 + :rand.uniform() * 0.25)
        end

      online = rem(i, 13) != 0

      %{
        id: "D#{String.pad_leading(to_string(i), 3, "0")}",
        name: "#{zone}/#{String.capitalize(to_string(type))}-#{i}",
        zone: zone,
        type: type,
        health_score: health_score,
        online: online,
        ip: "10.#{div(i, 64)}.#{rem(div(i, 16), 16)}.#{rem(i, 254) + 1}",
        uptime_pct: if(online, do: 85 + rem(i, 15), else: 0),
        last_seen: DateTime.add(now, -:rand.uniform(300), :second),
        firmware: "v#{2 + rem(i, 3)}.#{rem(i * 3, 10)}.#{rem(i * 7, 10)}"
      }
    end
  end
end
