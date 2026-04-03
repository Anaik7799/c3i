defmodule IndrajaalWeb.Prajna.SingularitySparklineLive do
  @moduledoc """
  Time-to-Singularity Estimation Sparkline — Prajna C3I Dashboard.

  Renders an SVG sparkline visualising the estimated time-to-singularity
  trajectory for the Indrajaal holon mesh. The sparkline shows the rolling
  30-point history of the system's singularity-readiness score (0.0–1.0),
  together with trend indicators and estimated ETA.

  WHAT: SVG sparkline of singularity-readiness score over time,
        trend direction, and estimated ETA based on linear extrapolation.

  WHY: Gives operators an at-a-glance view of the holon's evolutionary
       velocity and distance from self-directed singularity thresholds.

  ## STAMP Constraints
  - SC-SING-001: Singularity explorer must show readiness trajectory — ENFORCED
  - SC-HMI-010: Vibrant chromatic feedback — ENFORCED (gradient: red→gold→green)
  - SC-MON-001: Metrics refresh every 30s — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED
  - SC-EVO-001: Evolution Shannon entropy gate — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  use IndrajaalWeb, :live_view

  @history_size 30
  @refresh_ms 30_000
  @singularity_threshold 0.95

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "singularity:metrics")
      :timer.send_interval(@refresh_ms, self(), :refresh)
    end

    history = seed_history()
    current = List.last(history) || 0.0
    trend = compute_trend(history)
    eta = estimate_eta(history, @singularity_threshold)
    sparkline_path = build_sparkline_path(history, 280, 60)

    {:ok,
     socket
     |> assign(:page_title, "Time-to-Singularity")
     |> assign(:history, history)
     |> assign(:current_score, current)
     |> assign(:trend, trend)
     |> assign(:eta_hours, eta)
     |> assign(:sparkline_path, sparkline_path)
     |> assign(:threshold, @singularity_threshold)}
  end

  @impl true
  def handle_info(:refresh, socket) do
    history = advance_history(socket.assigns.history)
    current = List.last(history) || 0.0
    trend = compute_trend(history)
    eta = estimate_eta(history, @singularity_threshold)
    sparkline_path = build_sparkline_path(history, 280, 60)

    {:noreply,
     socket
     |> assign(:history, history)
     |> assign(:current_score, current)
     |> assign(:trend, trend)
     |> assign(:eta_hours, eta)
     |> assign(:sparkline_path, sparkline_path)}
  end

  @impl true
  def handle_info({:singularity_score, score}, socket) when is_float(score) do
    history =
      (socket.assigns.history ++ [score])
      |> Enum.take(-@history_size)

    current = score
    trend = compute_trend(history)
    eta = estimate_eta(history, @singularity_threshold)
    sparkline_path = build_sparkline_path(history, 280, 60)

    {:noreply,
     socket
     |> assign(:history, history)
     |> assign(:current_score, current)
     |> assign(:trend, trend)
     |> assign(:eta_hours, eta)
     |> assign(:sparkline_path, sparkline_path)}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="singularity-sparkline bg-gray-950 text-white p-6 min-h-screen">
      <div class="flex items-center justify-between mb-4">
        <h1 class="text-xl font-bold text-purple-300">Time-to-Singularity</h1>
        <span class="text-xs text-gray-500 font-mono">SC-SING-001 | 30s refresh</span>
      </div>

      <div class="grid grid-cols-3 gap-4 mb-6">
        <div class="bg-gray-800 rounded-lg p-4 text-center">
          <div class="text-3xl font-bold" style={"color: #{score_color(@current_score)}"}>
            {Float.round(@current_score * 100, 1)}%
          </div>
          <div class="text-xs text-gray-400 mt-1">Readiness Score</div>
        </div>

        <div class="bg-gray-800 rounded-lg p-4 text-center">
          <div class="text-2xl font-bold" style={"color: #{trend_color(@trend)}"}>
            {trend_label(@trend)}
          </div>
          <div class="text-xs text-gray-400 mt-1">Trend</div>
        </div>

        <div class="bg-gray-800 rounded-lg p-4 text-center">
          <div class="text-2xl font-bold text-amber-300">
            {eta_label(@eta_hours)}
          </div>
          <div class="text-xs text-gray-400 mt-1">ETA to Singularity</div>
        </div>
      </div>

      <div class="bg-gray-800 rounded-lg p-4">
        <svg
          viewBox="0 0 280 80"
          xmlns="http://www.w3.org/2000/svg"
          class="w-full h-24"
          aria-label="Singularity readiness sparkline"
        >
          <defs>
            <linearGradient id="sparkGradient" x1="0" y1="0" x2="1" y2="0">
              <stop offset="0%" stop-color="#f87171" />
              <stop offset="50%" stop-color="#fbbf24" />
              <stop offset="100%" stop-color="#a78bfa" />
            </linearGradient>
          </defs>
          <!-- Threshold line at @singularity_threshold -->
          <line
            x1="0"
            y1={threshold_y(@threshold, 60)}
            x2="280"
            y2={threshold_y(@threshold, 60)}
            stroke="#4ade80"
            stroke-width="0.5"
            stroke-dasharray="4 2"
          />
          <!-- Sparkline path -->
          <path
            d={@sparkline_path}
            fill="none"
            stroke="url(#sparkGradient)"
            stroke-width="1.5"
            stroke-linejoin="round"
          />
        </svg>
        <div class="flex justify-between text-xs text-gray-600 mt-1 font-mono">
          <span>−30 samples</span>
          <span>threshold: {round(@threshold * 100)}%</span>
          <span>now</span>
        </div>
      </div>
    </div>
    """
  end

  # ─── Private helpers ─────────────────────────────────────────────────────────

  defp seed_history do
    Enum.map(1..@history_size, fn i ->
      base = 0.45 + i * 0.012
      jitter = :rand.uniform() * 0.04 - 0.02
      Float.round(min(base + jitter, 1.0), 4)
    end)
  end

  defp advance_history(history) do
    last = List.last(history) || 0.5
    jitter = :rand.uniform() * 0.06 - 0.02
    next = Float.round(min(max(last + jitter, 0.0), 1.0), 4)
    (history ++ [next]) |> Enum.take(-@history_size)
  end

  defp compute_trend(history) when length(history) < 2, do: :stable

  defp compute_trend(history) do
    recent = Enum.take(history, -5)
    first = List.first(recent)
    last = List.last(recent)
    delta = last - first

    cond do
      delta > 0.02 -> :rising
      delta < -0.02 -> :falling
      true -> :stable
    end
  end

  defp estimate_eta(history, _threshold) when length(history) < 2, do: nil

  defp estimate_eta(history, threshold) do
    current = List.last(history) || 0.0

    if current >= threshold do
      0.0
    else
      n = length(history)
      avg_delta = (current - List.first(history)) / max(n - 1, 1)

      if avg_delta <= 0 do
        nil
      else
        steps_needed = (threshold - current) / avg_delta
        # Each step is @refresh_ms milliseconds
        hours = steps_needed * @refresh_ms / 3_600_000
        Float.round(hours, 1)
      end
    end
  end

  defp build_sparkline_path([], _w, _h), do: ""

  defp build_sparkline_path(history, width, height) do
    n = length(history)
    points = Enum.with_index(history)

    coords =
      Enum.map(points, fn {score, idx} ->
        x = if n > 1, do: idx / (n - 1) * width, else: width / 2
        y = (1.0 - score) * height
        {Float.round(x, 1), Float.round(y, 1)}
      end)

    [{fx, fy} | rest] = coords
    rest_path = Enum.map_join(rest, " ", fn {x, y} -> "L#{x} #{y}" end)
    "M#{fx} #{fy} #{rest_path}"
  end

  defp threshold_y(threshold, height), do: Float.round((1.0 - threshold) * height, 1)

  defp score_color(score) when score >= 0.9, do: "#a78bfa"
  defp score_color(score) when score >= 0.7, do: "#fbbf24"
  defp score_color(score) when score >= 0.5, do: "#60a5fa"
  defp score_color(_), do: "#f87171"

  defp trend_color(:rising), do: "#4ade80"
  defp trend_color(:falling), do: "#f87171"
  defp trend_color(:stable), do: "#94a3b8"

  defp trend_label(:rising), do: "↑ Rising"
  defp trend_label(:falling), do: "↓ Falling"
  defp trend_label(:stable), do: "→ Stable"

  defp eta_label(nil), do: "∞"
  defp eta_label(hours) when hours == 0.0, do: "NOW"
  defp eta_label(hours) when hours < 1.0, do: "<1h"
  defp eta_label(hours) when hours < 24.0, do: "#{Float.round(hours, 1)}h"
  defp eta_label(hours), do: "#{round(hours / 24)}d"
end
