defmodule IndrajaalWeb.Prajna.GitIntelligenceLive do
  @moduledoc """
  Git Intelligence Dashboard — Real-time Git Health Score (GHS) monitoring.

  WHAT: Displays GHS, biomorphic health, detected threats, constitutional
        alignment, and homeostatic mode from the F# GitIntelligence subsystem.

  WHY: Closes the LiveView consumption gap in the F#→Zenoh→Elixir pipeline.
       14 Zenoh topics flow through GitZenohSubscriber into ETS/PubSub, and
       this panel renders them for human operators in the Prajna cockpit.

  CONSTRAINTS:
    - SC-BRIDGE-001: Message buffer FIFO
    - SC-BRIDGE-003: Latency budget 50ms
    - SC-IMMUNE-001: Sentinel threat escalation displayed
    - SC-BIO-EXT-001: PatternHunter pre-error detection < 10ms
    - SC-HMI-002: Trend vectors displayed
  """
  use IndrajaalWeb, :live_view

  alias Indrajaal.Observability.GitIntegration.GitZenohSubscriber

  @refresh_interval_ms 3_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "git_intelligence")
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "git_intelligence:health")
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "git_intelligence:threat")
      :timer.send_interval(@refresh_interval_ms, :refresh)
    end

    {:ok, assign_defaults(socket)}
  end

  defp assign_defaults(socket) do
    metrics = safe_get_metrics()

    assign(socket,
      page_title: "Git Intelligence",
      ghs: metrics[:ghs] || 0.0,
      ghs_at: metrics[:ghs_at],
      icp_adoption: metrics[:icp_adoption] || 0.0,
      biomorphic_health: metrics[:biomorphic_health] || %{},
      threat_level: metrics[:threat_level] || "none",
      vital_signs: metrics[:vital_signs] || %{},
      founder_alignment: metrics[:founder_alignment] || %{},
      recent_events: [],
      subscriber_stats: safe_get_stats(),
      last_refresh: DateTime.utc_now()
    )
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply, refresh_from_ets(socket)}
  end

  # PubSub: general git intelligence events
  @impl true
  def handle_info({:git_intelligence, event_data}, socket) do
    events = [event_data | Enum.take(socket.assigns.recent_events, 19)]
    {:noreply, assign(socket, :recent_events, events)}
  end

  # PubSub: GHS health updates
  @impl true
  def handle_info({:git_intelligence_health, health_data}, socket) do
    socket =
      socket
      |> assign(:ghs, Map.get(health_data, "ghs", socket.assigns.ghs))
      |> assign(:icp_adoption, Map.get(health_data, "icp_adoption", socket.assigns.icp_adoption))

    {:noreply, socket}
  end

  # PubSub: threat escalation
  @impl true
  def handle_info({:git_intelligence_threat, threat_data}, socket) do
    socket =
      socket
      |> assign(:threat_level, Map.get(threat_data, "threat_level", socket.assigns.threat_level))

    events = [threat_data | Enum.take(socket.assigns.recent_events, 19)]
    {:noreply, assign(socket, :recent_events, events)}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp refresh_from_ets(socket) do
    metrics = safe_get_metrics()

    assign(socket,
      ghs: metrics[:ghs] || socket.assigns.ghs,
      ghs_at: metrics[:ghs_at] || socket.assigns.ghs_at,
      icp_adoption: metrics[:icp_adoption] || socket.assigns.icp_adoption,
      biomorphic_health: metrics[:biomorphic_health] || socket.assigns.biomorphic_health,
      threat_level: metrics[:threat_level] || socket.assigns.threat_level,
      vital_signs: metrics[:vital_signs] || socket.assigns.vital_signs,
      founder_alignment: metrics[:founder_alignment] || socket.assigns.founder_alignment,
      subscriber_stats: safe_get_stats(),
      last_refresh: DateTime.utc_now()
    )
  end

  defp safe_get_metrics do
    try do
      GitZenohSubscriber.get_metrics()
    rescue
      _ -> %{}
    catch
      :exit, _ -> %{}
    end
  end

  defp safe_get_stats do
    try do
      GitZenohSubscriber.get_stats()
    rescue
      _ -> %{}
    catch
      :exit, _ -> %{}
    end
  end

  defp ghs_color(ghs) when ghs >= 0.8, do: "text-green-600"
  defp ghs_color(ghs) when ghs >= 0.6, do: "text-yellow-600"
  defp ghs_color(ghs) when ghs >= 0.4, do: "text-orange-400"
  defp ghs_color(_ghs), do: "text-red-600"

  defp ghs_bar_color(ghs) when ghs >= 0.8, do: "bg-green-500"
  defp ghs_bar_color(ghs) when ghs >= 0.6, do: "bg-yellow-500"
  defp ghs_bar_color(ghs) when ghs >= 0.4, do: "bg-orange-500"
  defp ghs_bar_color(_ghs), do: "bg-red-500"

  defp threat_color("none"), do: "text-green-600"
  defp threat_color("low"), do: "text-blue-600"
  defp threat_color("medium"), do: "text-yellow-600"
  defp threat_color("high"), do: "text-orange-400"
  defp threat_color("critical"), do: "text-red-600"
  defp threat_color("emergency"), do: "text-red-600 animate-pulse"
  defp threat_color(_), do: "text-gray-600"

  defp threat_bg("none"), do: "bg-green-900/30"
  defp threat_bg("low"), do: "bg-blue-900/30"
  defp threat_bg("medium"), do: "bg-yellow-900/30"
  defp threat_bg("high"), do: "bg-orange-900/30"
  defp threat_bg("critical"), do: "bg-red-900/30"
  defp threat_bg("emergency"), do: "bg-red-900/50"
  defp threat_bg(_), do: "bg-surface-secondary/30"

  defp format_ghs(ghs) when is_float(ghs), do: :erlang.float_to_binary(ghs * 100, decimals: 1)
  defp format_ghs(ghs) when is_integer(ghs), do: Integer.to_string(ghs)
  defp format_ghs(_), do: "—"

  defp format_pct(val) when is_float(val), do: :erlang.float_to_binary(val * 100, decimals: 1)
  defp format_pct(val) when is_integer(val), do: Integer.to_string(val)
  defp format_pct(_), do: "—"

  defp format_timestamp(nil), do: "—"

  defp format_timestamp(%DateTime{} = dt),
    do: Calendar.strftime(dt, "%H:%M:%S UTC")

  defp format_timestamp(iso) when is_binary(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, dt, _} -> Calendar.strftime(dt, "%H:%M:%S UTC")
      _ -> iso
    end
  end

  defp format_timestamp(_), do: "—"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 bg-surface-primary min-h-screen text-content-primary">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold">Git Intelligence Dashboard</h1>
        <div class="text-sm text-gray-600">
          Last refresh: {format_timestamp(@last_refresh)}
        </div>
      </div>

      <%!-- Row 1: Primary KPIs --%>
      <div class="grid grid-cols-4 gap-4 mb-6">
        <%!-- GHS Card --%>
        <div class="bg-surface-secondary p-4 rounded-lg">
          <div class="text-sm text-gray-600">Git Health Score</div>
          <div class={"text-3xl font-bold #{ghs_color(@ghs)}"}>
            {format_ghs(@ghs)}%
          </div>
          <div class="w-full bg-gray-700 rounded-full h-2 mt-2">
            <div
              class={"h-2 rounded-full #{ghs_bar_color(@ghs)}"}
              style={"width: #{min((@ghs || 0) * 100, 100)}%"}
            >
            </div>
          </div>
          <div class="text-xs text-gray-600 mt-1">
            Updated: {format_timestamp(@ghs_at)}
          </div>
        </div>

        <%!-- ICP Adoption Card --%>
        <div class="bg-surface-secondary p-4 rounded-lg">
          <div class="text-sm text-gray-600">ICP v2.0 Adoption</div>
          <div class="text-3xl font-bold text-blue-600">
            {format_pct(@icp_adoption)}%
          </div>
          <div class="text-xs text-gray-600 mt-1">
            Commit convention compliance
          </div>
        </div>

        <%!-- Threat Level Card --%>
        <div class={"bg-surface-secondary p-4 rounded-lg border-l-4 #{threat_bg(@threat_level)}"}>
          <div class="text-sm text-gray-600">Threat Level</div>
          <div class={"text-3xl font-bold uppercase #{threat_color(@threat_level)}"}>
            {@threat_level}
          </div>
          <div class="text-xs text-gray-600 mt-1">
            Anti-pattern detection
          </div>
        </div>

        <%!-- Subscriber Status Card --%>
        <div class="bg-surface-secondary p-4 rounded-lg">
          <div class="text-sm text-gray-600">Subscriber</div>
          <div class="text-3xl font-bold text-cyan-600">
            {Map.get(@subscriber_stats, :messages_received, 0)}
          </div>
          <div class="text-xs text-gray-600 mt-1">
            Messages received
          </div>
        </div>
      </div>

      <%!-- Row 2: Biomorphic Health + Vital Signs --%>
      <div class="grid grid-cols-2 gap-4 mb-6">
        <%!-- Biomorphic Health Panel --%>
        <div class="bg-surface-secondary p-4 rounded-lg">
          <h2 class="text-lg font-semibold mb-3">Biomorphic Health</h2>
          <div :if={@biomorphic_health != %{}} class="space-y-2">
            <.bio_bar label="Immune" value={Map.get(@biomorphic_health, "immune", 0)} color="red" />
            <.bio_bar label="Neural" value={Map.get(@biomorphic_health, "neural", 0)} color="purple" />
            <.bio_bar
              label="Homeostatic"
              value={Map.get(@biomorphic_health, "homeostatic", 0)}
              color="yellow"
            />
            <.bio_bar
              label="Regenerative"
              value={Map.get(@biomorphic_health, "regenerative", 0)}
              color="green"
            />
            <.bio_bar
              label="Symbiotic"
              value={Map.get(@biomorphic_health, "symbiotic", 0)}
              color="blue"
            />
          </div>
          <div :if={@biomorphic_health == %{}} class="text-gray-600 text-sm">
            Awaiting biomorphic assessment data...
          </div>
        </div>

        <%!-- Vital Signs Panel --%>
        <div class="bg-surface-secondary p-4 rounded-lg">
          <h2 class="text-lg font-semibold mb-3">Vital Signs</h2>
          <div :if={@vital_signs != %{}} class="grid grid-cols-3 gap-4">
            <div class="text-center">
              <div class="text-sm text-gray-600">Health</div>
              <div class="text-2xl font-bold text-green-600">
                {format_pct(Map.get(@vital_signs, "health_index", 0))}
              </div>
            </div>
            <div class="text-center">
              <div class="text-sm text-gray-600">Stress</div>
              <div class="text-2xl font-bold text-orange-400">
                {format_pct(Map.get(@vital_signs, "stress_index", 0))}
              </div>
            </div>
            <div class="text-center">
              <div class="text-sm text-gray-600">Energy</div>
              <div class="text-2xl font-bold text-blue-600">
                {format_pct(Map.get(@vital_signs, "energy_index", 0))}
              </div>
            </div>
          </div>

          <div :if={@founder_alignment != %{}} class="mt-4 pt-4 border-t border-border-theme-primary">
            <h3 class="text-sm font-semibold text-gray-600 mb-2">Founder's Directive Alignment</h3>
            <div class="grid grid-cols-3 gap-2 text-center text-xs">
              <div>
                <div class="text-gray-600">Survival</div>
                <div class="text-lg font-bold text-green-600">
                  {format_pct(Map.get(@founder_alignment, "survival", 0))}
                </div>
              </div>
              <div>
                <div class="text-gray-600">Sentience</div>
                <div class="text-lg font-bold text-purple-700">
                  {format_pct(Map.get(@founder_alignment, "sentience", 0))}
                </div>
              </div>
              <div>
                <div class="text-gray-600">Power</div>
                <div class="text-lg font-bold text-amber-400">
                  {format_pct(Map.get(@founder_alignment, "power", 0))}
                </div>
              </div>
            </div>
          </div>

          <div :if={@vital_signs == %{}} class="text-gray-600 text-sm">
            Awaiting vital signs data...
          </div>
        </div>
      </div>

      <%!-- Row 3: Recent Events Feed --%>
      <div class="bg-surface-secondary p-4 rounded-lg">
        <h2 class="text-lg font-semibold mb-3">Recent Events</h2>
        <div :if={@recent_events != []} class="space-y-1 max-h-48 overflow-y-auto">
          <div
            :for={event <- @recent_events}
            class="text-sm font-mono text-content-secondary py-1 border-b border-border-theme-secondary/50"
          >
            <span class="text-gray-600">{format_event_time(event)}</span>
            <span class="ml-2">{format_event_summary(event)}</span>
          </div>
        </div>
        <div :if={@recent_events == []} class="text-gray-600 text-sm">
          No events received yet. Waiting for F# GitIntelligence to publish via Zenoh...
        </div>
      </div>
    </div>
    """
  end

  # ════════════════════════════════════════════════════════════
  # FUNCTION COMPONENTS
  # ════════════════════════════════════════════════════════════

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :color, :string, required: true

  defp bio_bar(assigns) do
    pct = normalize_pct(assigns.value)

    color_class =
      case assigns.color do
        "red" -> "bg-red-500"
        "purple" -> "bg-purple-500"
        "yellow" -> "bg-yellow-500"
        "green" -> "bg-green-500"
        "blue" -> "bg-blue-500"
        _ -> "bg-gray-500"
      end

    assigns = assign(assigns, pct: pct, color_class: color_class)

    ~H"""
    <div class="flex items-center gap-2">
      <div class="w-24 text-sm text-gray-600">{@label}</div>
      <div class="flex-1 bg-gray-700 rounded-full h-3">
        <div class={"h-3 rounded-full #{@color_class}"} style={"width: #{@pct}%"}></div>
      </div>
      <div class="w-12 text-right text-sm">{format_pct(@value)}</div>
    </div>
    """
  end

  defp normalize_pct(val) when is_float(val) and val <= 1.0, do: val * 100
  defp normalize_pct(val) when is_float(val), do: min(val, 100)
  defp normalize_pct(val) when is_integer(val), do: min(val, 100)
  defp normalize_pct(_), do: 0

  defp format_event_time(%{"timestamp" => ts}), do: format_timestamp(ts)
  defp format_event_time(%{timestamp: ts}), do: format_timestamp(ts)
  defp format_event_time(_), do: "—"

  defp format_event_summary(%{"topic" => topic} = event) do
    type = String.replace(topic, "indrajaal/git/", "")
    msg = Map.get(event, "message", Map.get(event, "summary", type))
    "[#{type}] #{msg}"
  end

  defp format_event_summary(%{topic: topic} = event) do
    type = String.replace(to_string(topic), "indrajaal/git/", "")
    msg = Map.get(event, :message, Map.get(event, :summary, type))
    "[#{type}] #{msg}"
  end

  defp format_event_summary(event) when is_map(event) do
    inspect(event, limit: 80)
  end

  defp format_event_summary(_), do: "unknown event"
end
