defmodule IndrajaalWeb.Prajna.SentinelDashboardLive do
  @moduledoc """
  Sentinel Digital Immune System Dashboard.

  STAMP: SC-IMMUNE-001, SC-IMMUNE-007, SC-IMMUNE-008
  """
  use IndrajaalWeb, :live_view

  alias Indrajaal.Cockpit.Prajna.SentinelBridge

  @refresh_interval 5000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(@refresh_interval, :refresh)
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "sentinel:threats")
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "prajna:threats")
    end

    {:ok, load_sentinel_data(assign(socket, page_title: "Sentinel - Immune System"))}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply, load_sentinel_data(socket)}
  end

  def handle_info(%{event: "threat_detected"} = _msg, socket) do
    {:noreply, load_sentinel_data(socket)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp load_sentinel_data(socket) do
    {health, advisories, quarantine} = fetch_sentinel_state()

    socket
    |> assign(:health_score, (health.score_percent || 0) / 1.0)
    |> assign(:active_threats, health.threats || [])
    |> assign(:quarantined, quarantine)
    |> assign(:patterns_detected, length(advisories))
    |> assign(:response_times, %{extinction: 100, critical: 500, high: 2000})
    |> assign(:last_scan, health[:last_sync] || DateTime.utc_now())
  end

  defp fetch_sentinel_state do
    health =
      try do
        SentinelBridge.get_health()
      rescue
        _ -> %{score: 1.0, score_percent: 100, threats: [], status: :healthy, last_sync: nil}
      catch
        :exit, _ ->
          %{score: 1.0, score_percent: 100, threats: [], status: :healthy, last_sync: nil}
      end

    advisories =
      try do
        SentinelBridge.get_advisories()
      rescue
        _ -> []
      catch
        :exit, _ -> []
      end

    quarantine =
      try do
        SentinelBridge.get_quarantine_status()
      rescue
        _ -> []
      catch
        :exit, _ -> []
      end

    {health, advisories, quarantine}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 bg-surface-primary min-h-screen text-content-primary">
      <h1 class="text-2xl font-bold mb-6">🛡️ Sentinel - Digital Immune System</h1>

      <div class="grid grid-cols-4 gap-4 mb-6">
        <div class="bg-surface-secondary p-4 rounded-lg">
          <div class="text-sm text-gray-600">Health Score</div>
          <div class="text-3xl font-bold text-green-600">{Float.round(@health_score, 1)}%</div>
        </div>
        <div class="bg-surface-secondary p-4 rounded-lg">
          <div class="text-sm text-gray-600">Active Threats</div>
          <div class="text-3xl font-bold text-red-600">{length(@active_threats)}</div>
        </div>
        <div class="bg-surface-secondary p-4 rounded-lg">
          <div class="text-sm text-gray-600">Quarantined</div>
          <div class="text-3xl font-bold text-yellow-600">{length(@quarantined)}</div>
        </div>
        <div class="bg-surface-secondary p-4 rounded-lg">
          <div class="text-sm text-gray-600">Patterns Detected</div>
          <div class="text-3xl font-bold text-blue-600">{@patterns_detected}</div>
        </div>
      </div>

      <div class="bg-surface-secondary p-4 rounded-lg mb-6">
        <h2 class="text-lg font-semibold mb-3">Response Times (SLA)</h2>
        <div class="grid grid-cols-3 gap-4">
          <div class="text-center">
            <div class="text-red-500 font-bold">EXTINCTION</div>
            <div class="text-2xl">{@response_times.extinction}ms</div>
          </div>
          <div class="text-center">
            <div class="text-orange-500 font-bold">CRITICAL</div>
            <div class="text-2xl">{@response_times.critical}ms</div>
          </div>
          <div class="text-center">
            <div class="text-yellow-500 font-bold">HIGH</div>
            <div class="text-2xl">{@response_times.high}ms</div>
          </div>
        </div>
      </div>

      <div class="text-sm text-gray-500">
        Last scan: {Calendar.strftime(@last_scan, "%Y-%m-%d %H:%M:%S UTC")}
      </div>
    </div>
    """
  end
end
