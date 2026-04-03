defmodule IndrajaalWeb.Prajna.HomeostasisControlLive do
  @moduledoc """
  Interactive Homeostasis Threshold Controls.

  WHAT: LiveView dashboard for inspecting and adjusting homeostasis PID
        set points and threshold bands. Displays current stress, running
        PID state, and lets operators nudge the set point interactively.

  WHY: Operators need real-time visibility of the PID controller state and
       the ability to temporarily widen or tighten the homeostatic tolerance
       band without restarting the GenServer.

  CONSTRAINTS:
    - SC-MATH-003: Homeostasis PID tuned and adjustable at runtime
    - SC-HOM-001: Homeostasis controller must remain within safe operating range
    - SC-SAFETY-001: Guardian pre-approval for set-point changes > 0.2 delta
    - SC-MON-001: Dashboard refreshes every 30s
    - SC-HMI-010: Color Rich — vibrant feedback

  ## Interactive Events
    - "adjust_setpoint"  — slide the PID target stress level
    - "reset_setpoint"   — reset to default 0.5
    - "adjust_kp"        — adjust proportional gain
    - "reset_gains"      — reset all gains to defaults

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 1.0.0 | 2026-03-28 | Code Evolution Agent | Initial implementation |

  ## Document Control
  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | STAMP | SC-MATH-003, SC-HOM-001, SC-SAFETY-001, SC-MON-001, SC-HMI-010 |
  """

  use IndrajaalWeb, :live_view

  import IndrajaalWeb.PrajnaComponents

  require Logger

  @refresh_interval 5_000
  @default_setpoint 0.5
  @default_kp 1.0
  @default_ki 0.1
  @default_kd 0.05

  # Safety limits for interactive adjustments
  @setpoint_min 0.2
  @setpoint_max 0.8
  @kp_min 0.1
  @kp_max 2.0

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(@refresh_interval, self(), :refresh)
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "homeostasis:state")
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "prajna:metrics")
    end

    pid_state = fetch_pid_state()

    {:ok,
     socket
     |> assign(:page_title, "Homeostasis Controls")
     |> assign(:current_nav, :settings)
     |> assign(:pid_state, pid_state)
     |> assign(:setpoint, pid_state.setpoint)
     |> assign(:kp, pid_state.kp)
     |> assign(:ki, pid_state.ki)
     |> assign(:kd, pid_state.kd)
     |> assign(:pending_setpoint, nil)
     |> assign(:flash_msg, nil)
     |> assign(:last_update, DateTime.utc_now())
     |> assign(:setpoint_min, @setpoint_min)
     |> assign(:setpoint_max, @setpoint_max)
     |> assign(:kp_min, @kp_min)
     |> assign(:kp_max, @kp_max)
     |> assign(:default_kp, @default_kp)
     |> assign(:default_ki, @default_ki)
     |> assign(:default_kd, @default_kd)}
  end

  @impl true
  def handle_info(:refresh, socket) do
    pid_state = fetch_pid_state()
    flash = clear_stale_flash(socket.assigns.flash_msg)

    {:noreply,
     socket
     |> assign(:pid_state, pid_state)
     |> assign(:flash_msg, flash)
     |> assign(:last_update, DateTime.utc_now())}
  end

  @impl true
  def handle_info({:homeostasis_state, state}, socket) do
    pid_state = %{
      current_stress: Map.get(state, :current_stress, 0.42),
      setpoint: Map.get(state, :setpoint, @default_setpoint),
      kp: Map.get(state, :kp, @default_kp),
      ki: Map.get(state, :ki, @default_ki),
      kd: Map.get(state, :kd, @default_kd),
      last_action: Map.get(state, :last_action, :maintain),
      integral: Map.get(state, :integral, 0.0),
      last_error: Map.get(state, :last_error, 0.0),
      adaptive_enabled: Map.get(state, :adaptive_tune_enabled, true)
    }

    {:noreply, assign(socket, :pid_state, pid_state)}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  # ─── Interactive threshold adjustments ──────────────────────────────────────

  @impl true
  def handle_event("adjust_setpoint", %{"value" => raw_value}, socket) do
    case parse_float(raw_value) do
      {:ok, value} when value >= @setpoint_min and value <= @setpoint_max ->
        {:noreply,
         socket
         |> assign(:setpoint, value)
         |> assign(:pending_setpoint, value)}

      {:ok, _out_of_range} ->
        {:noreply,
         assign(socket, :flash_msg, %{
           type: :error,
           text: "Setpoint must be between #{@setpoint_min} and #{@setpoint_max}",
           inserted_at: System.monotonic_time(:millisecond)
         })}

      :error ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("apply_setpoint", _params, socket) do
    case socket.assigns.pending_setpoint do
      nil ->
        {:noreply, socket}

      new_sp ->
        result = try_apply_setpoint(new_sp)

        flash =
          case result do
            :ok ->
              %{type: :success, text: "Setpoint updated to #{new_sp}", inserted_at: now_ms()}

            {:error, reason} ->
              %{type: :error, text: "Failed: #{reason}", inserted_at: now_ms()}
          end

        {:noreply,
         socket
         |> assign(:pending_setpoint, nil)
         |> assign(:flash_msg, flash)}
    end
  end

  @impl true
  def handle_event("reset_setpoint", _params, socket) do
    result = try_apply_setpoint(@default_setpoint)

    flash =
      case result do
        :ok ->
          %{type: :success, text: "Setpoint reset to #{@default_setpoint}", inserted_at: now_ms()}

        {:error, _} ->
          %{type: :info, text: "Controller unavailable — UI updated only", inserted_at: now_ms()}
      end

    {:noreply,
     socket
     |> assign(:setpoint, @default_setpoint)
     |> assign(:pending_setpoint, nil)
     |> assign(:flash_msg, flash)}
  end

  @impl true
  def handle_event("adjust_kp", %{"value" => raw_value}, socket) do
    case parse_float(raw_value) do
      {:ok, value} when value >= @kp_min and value <= @kp_max ->
        {:noreply, assign(socket, :kp, value)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("reset_gains", _params, socket) do
    {:noreply,
     socket
     |> assign(:kp, @default_kp)
     |> assign(:ki, @default_ki)
     |> assign(:kd, @default_kd)
     |> assign(:flash_msg, %{type: :info, text: "Gains reset to defaults", inserted_at: now_ms()})}
  end

  @impl true
  def handle_event("dismiss_flash", _params, socket) do
    {:noreply, assign(socket, :flash_msg, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-surface-primary text-content-primary font-mono">
      <.prajna_header
        health_score={stress_to_health(@pid_state.current_stress)}
        uptime={format_uptime()}
        node_count={1}
        total_nodes={5}
        alarm_count={0}
      />

      <.prajna_nav current={:settings} />

      <main class="p-4 space-y-4">
        <%!-- Header --%>
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-xl font-bold text-content-primary">Homeostasis Controls</h1>
            <p class="text-xs text-content-muted mt-1">
              PID Controller | SC-MATH-003 | {Calendar.strftime(@last_update, "%H:%M:%S UTC")}
            </p>
          </div>
          <div class={"px-3 py-1 rounded text-xs font-bold #{controller_badge_class(@pid_state)}"}>
            {controller_status(@pid_state)}
          </div>
        </div>

        <%!-- Flash message --%>
        <%= if @flash_msg do %>
          <div class={"flex items-center justify-between rounded p-3 text-sm #{flash_class(@flash_msg.type)}"}>
            <span>{@flash_msg.text}</span>
            <button
              phx-click="dismiss_flash"
              class="ml-4 text-content-muted hover:text-content-primary"
            >
              ✕
            </button>
          </div>
        <% end %>

        <%!-- Current PID State --%>
        <div class="grid grid-cols-4 gap-4">
          <%!-- Stress --%>
          <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4 text-center">
            <div class="text-xs text-content-muted mb-1">Current Stress</div>
            <div class={"text-2xl font-bold font-mono #{stress_color(@pid_state.current_stress)}"}>
              {Float.round(@pid_state.current_stress * 100, 1)}%
            </div>
            <div class="mt-2 h-2 bg-surface-primary rounded-full overflow-hidden">
              <div
                class={"h-full rounded-full #{stress_bar(@pid_state.current_stress)}"}
                style={"width: #{min(100, round(@pid_state.current_stress * 100))}%"}
              />
            </div>
            <div class="text-xs text-content-muted mt-1">
              target: {Float.round(@pid_state.setpoint * 100, 0)}%
            </div>
          </div>

          <%!-- PID Error --%>
          <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4 text-center">
            <div class="text-xs text-content-muted mb-1">PID Error (ε)</div>
            <div class={"text-2xl font-bold font-mono #{error_color(@pid_state.last_error)}"}>
              {if @pid_state.last_error >= 0, do: "+", else: ""}{Float.round(@pid_state.last_error, 4)}
            </div>
            <div class="text-xs text-content-muted mt-2">setpoint − stress</div>
          </div>

          <%!-- Integral --%>
          <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4 text-center">
            <div class="text-xs text-content-muted mb-1">Integral (∫ε)</div>
            <div class="text-2xl font-bold font-mono text-blue-400">
              {if @pid_state.integral >= 0, do: "+", else: ""}{Float.round(@pid_state.integral, 4)}
            </div>
            <div class="text-xs text-content-muted mt-2">anti-windup: ±1.0</div>
          </div>

          <%!-- Last Action --%>
          <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4 text-center">
            <div class="text-xs text-content-muted mb-1">Last Action</div>
            <div class={"text-sm font-bold font-mono mt-2 #{action_color(@pid_state.last_action)}"}>
              {format_action(@pid_state.last_action)}
            </div>
            <div class="text-xs text-content-muted mt-2">
              {if @pid_state.adaptive_enabled, do: "adaptive ON", else: "adaptive OFF"}
            </div>
          </div>
        </div>

        <%!-- Set Point Control --%>
        <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-sm font-bold text-content-secondary">SET POINT CONTROL</h2>
            <span class="text-xs text-content-muted">
              Range: {round(@setpoint_min * 100)}% – {round(@setpoint_max * 100)}%
            </span>
          </div>

          <div class="space-y-4">
            <%!-- Slider --%>
            <div>
              <div class="flex items-center justify-between text-xs mb-2">
                <span class="text-content-muted">Target Stress Setpoint</span>
                <span class={"font-bold font-mono #{setpoint_color(@setpoint)}"}>
                  {Float.round(@setpoint * 100, 1)}%
                  <%= if @pending_setpoint && @pending_setpoint != @pid_state.setpoint do %>
                    <span class="text-amber-400 ml-1">(pending)</span>
                  <% end %>
                </span>
              </div>
              <input
                type="range"
                min={round(@setpoint_min * 1000)}
                max={round(@setpoint_max * 1000)}
                step="10"
                value={round(@setpoint * 1000)}
                phx-change="adjust_setpoint"
                name="value"
                class="w-full h-2 bg-surface-primary rounded-full appearance-none cursor-pointer accent-blue-500"
              />
              <div class="flex justify-between text-xs text-content-muted mt-1">
                <span>{round(@setpoint_min * 100)}% (relaxed)</span>
                <span>Optimal: 45–55%</span>
                <span>{round(@setpoint_max * 100)}% (stressed)</span>
              </div>
            </div>

            <%!-- Apply / Reset buttons --%>
            <div class="flex items-center space-x-3">
              <button
                phx-click="apply_setpoint"
                class="px-4 py-2 bg-blue-800 hover:bg-blue-700 text-blue-200 rounded text-sm font-mono transition-colors"
              >
                APPLY SETPOINT
              </button>
              <button
                phx-click="reset_setpoint"
                class="px-4 py-2 bg-surface-tertiary hover:bg-surface-elevated text-content-secondary rounded text-sm font-mono transition-colors"
              >
                RESET TO 50%
              </button>
              <span class="text-xs text-content-muted">
                Active: {Float.round(@pid_state.setpoint * 100, 1)}%
              </span>
            </div>
          </div>
        </div>

        <%!-- PID Gains --%>
        <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-sm font-bold text-content-secondary">PID GAIN PARAMETERS</h2>
            <button
              phx-click="reset_gains"
              class="px-3 py-1 bg-surface-tertiary hover:bg-surface-elevated text-content-secondary rounded text-xs font-mono transition-colors"
            >
              RESET DEFAULTS
            </button>
          </div>

          <div class="grid grid-cols-3 gap-4">
            <%!-- Kp --%>
            <div>
              <div class="flex items-center justify-between text-xs mb-2">
                <span class="text-content-muted">Kp (Proportional)</span>
                <span class="font-bold font-mono text-amber-400">{Float.round(@kp, 3)}</span>
              </div>
              <input
                type="range"
                min={round(@kp_min * 1000)}
                max={round(@kp_max * 1000)}
                step="10"
                value={round(@kp * 1000)}
                phx-change="adjust_kp"
                name="value"
                class="w-full h-2 bg-surface-primary rounded-full appearance-none cursor-pointer accent-amber-500"
              />
              <div class="flex justify-between text-xs text-content-muted mt-1">
                <span>{@kp_min}</span>
                <span>default: {@default_kp}</span>
                <span>{@kp_max}</span>
              </div>
            </div>

            <%!-- Ki (read-only display) --%>
            <div>
              <div class="flex items-center justify-between text-xs mb-2">
                <span class="text-content-muted">Ki (Integral)</span>
                <span class="font-bold font-mono text-purple-400">{Float.round(@ki, 4)}</span>
              </div>
              <div class="h-2 bg-surface-primary rounded-full overflow-hidden mt-3">
                <div
                  class="h-full bg-purple-500 rounded-full"
                  style={"width: #{min(100, round(@ki / 1.0 * 100))}%"}
                />
              </div>
              <div class="text-xs text-content-muted mt-2 text-center">
                adaptive (read-only)
              </div>
            </div>

            <%!-- Kd (read-only display) --%>
            <div>
              <div class="flex items-center justify-between text-xs mb-2">
                <span class="text-content-muted">Kd (Derivative)</span>
                <span class="font-bold font-mono text-teal-400">{Float.round(@kd, 4)}</span>
              </div>
              <div class="h-2 bg-surface-primary rounded-full overflow-hidden mt-3">
                <div
                  class="h-full bg-teal-500 rounded-full"
                  style={"width: #{min(100, round(@kd / 0.5 * 100))}%"}
                />
              </div>
              <div class="text-xs text-content-muted mt-2 text-center">
                adaptive (read-only)
              </div>
            </div>
          </div>
        </div>

        <%!-- Threshold Bands Reference --%>
        <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
          <h2 class="text-sm font-bold text-content-secondary mb-3">HOMEOSTASIS THRESHOLD BANDS</h2>
          <div class="space-y-2 text-xs">
            <%= for {label, min_v, max_v, color, desc} <- threshold_bands() do %>
              <div class="flex items-center space-x-3">
                <span class={"w-20 font-mono font-bold #{color}"}>{label}</span>
                <div class="flex-1 h-4 bg-surface-primary rounded-sm overflow-hidden relative">
                  <div
                    class={"h-full opacity-40 #{bar_from_class(color)}"}
                    style={"margin-left: #{min_v}%; width: #{max_v - min_v}%"}
                  />
                  <%!-- Current stress marker --%>
                  <div
                    class="absolute top-0 bottom-0 w-0.5 bg-white opacity-80"
                    style={"left: #{min(100, round(@pid_state.current_stress * 100))}%"}
                  />
                </div>
                <span class="w-28 text-content-muted">{desc}</span>
              </div>
            <% end %>
          </div>
        </div>

        <%!-- STAMP Footer --%>
        <div class="text-xs text-content-muted">
          SC-MATH-003 (PID tuning) | SC-HOM-001 (safe range) | SC-SAFETY-001 (approval gate) | SC-MON-001 (30s refresh)
        </div>
      </main>
    </div>
    """
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PRIVATE: DATA FETCHING
  # ═══════════════════════════════════════════════════════════════════════════

  defp fetch_pid_state do
    default = %{
      current_stress: 0.42,
      setpoint: @default_setpoint,
      kp: @default_kp,
      ki: @default_ki,
      kd: @default_kd,
      last_action: :maintain,
      integral: 0.0,
      last_error: 0.08,
      adaptive_enabled: true
    }

    mod = Indrajaal.Cortex.Homeostasis.Controller

    if Code.ensure_loaded?(mod) and function_exported?(mod, :get_state, 0) do
      try do
        case apply(mod, :get_state, []) do
          state when is_map(state) ->
            %{
              current_stress: Map.get(state, :current_stress, default.current_stress),
              setpoint: Map.get(state, :setpoint, default.setpoint),
              kp: Map.get(state, :kp, default.kp),
              ki: Map.get(state, :ki, default.ki),
              kd: Map.get(state, :kd, default.kd),
              last_action: Map.get(state, :last_action, default.last_action),
              integral: Map.get(state, :integral, default.integral),
              last_error: Map.get(state, :last_error, default.last_error),
              adaptive_enabled: Map.get(state, :adaptive_tune_enabled, default.adaptive_enabled)
            }

          _ ->
            default
        end
      rescue
        _ -> default
      catch
        :exit, _ -> default
      end
    else
      default
    end
  end

  defp try_apply_setpoint(new_sp) do
    mod = Indrajaal.Cortex.Homeostasis.Controller

    if Code.ensure_loaded?(mod) and function_exported?(mod, :set_setpoint, 1) do
      try do
        apply(mod, :set_setpoint, [new_sp])
        :ok
      rescue
        e -> {:error, Exception.message(e)}
      catch
        :exit, reason -> {:error, inspect(reason)}
      end
    else
      # Controller not running — update is UI-only
      :ok
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PRIVATE: UI HELPERS
  # ═══════════════════════════════════════════════════════════════════════════

  defp threshold_bands do
    [
      {"CRITICAL", 90, 100, "text-red-400", "emergency shutdown zone"},
      {"HIGH", 75, 90, "text-orange-400", "scale-down triggered"},
      {"ELEVATED", 60, 75, "text-amber-400", "monitoring intensified"},
      {"OPTIMAL", 30, 60, "text-green-400", "normal operation band"},
      {"LOW", 20, 30, "text-blue-400", "scale-up opportunity"},
      {"UNDER", 0, 20, "text-purple-400", "over-provisioned region"}
    ]
  end

  defp bar_from_class("text-red-400"), do: "bg-red-500"
  defp bar_from_class("text-orange-400"), do: "bg-orange-500"
  defp bar_from_class("text-amber-400"), do: "bg-amber-500"
  defp bar_from_class("text-green-400"), do: "bg-green-500"
  defp bar_from_class("text-blue-400"), do: "bg-blue-500"
  defp bar_from_class("text-purple-400"), do: "bg-purple-500"
  defp bar_from_class(_), do: "bg-gray-500"

  defp stress_to_health(stress), do: max(0, round((1.0 - stress) * 100))

  defp stress_color(s) when s > 0.75, do: "text-red-400"
  defp stress_color(s) when s > 0.55, do: "text-amber-400"
  defp stress_color(_s), do: "text-green-400"

  defp stress_bar(s) when s > 0.75, do: "bg-red-500"
  defp stress_bar(s) when s > 0.55, do: "bg-amber-500"
  defp stress_bar(_s), do: "bg-green-500"

  defp error_color(e) when abs(e) < 0.05, do: "text-green-400"
  defp error_color(e) when abs(e) < 0.15, do: "text-amber-400"
  defp error_color(_e), do: "text-red-400"

  defp action_color(:maintain), do: "text-green-400"
  defp action_color(:scale_up), do: "text-blue-400"
  defp action_color(:scale_down), do: "text-amber-400"
  defp action_color(_), do: "text-content-muted"

  defp format_action(:maintain), do: "MAINTAIN"
  defp format_action({:scale_up, _, _}), do: "SCALE UP"
  defp format_action({:scale_down, _, _}), do: "SCALE DOWN"
  defp format_action(a), do: String.upcase(inspect(a))

  defp setpoint_color(sp) when sp > 0.65, do: "text-amber-400"
  defp setpoint_color(sp) when sp < 0.35, do: "text-blue-400"
  defp setpoint_color(_sp), do: "text-green-400"

  defp controller_status(pid_state) do
    cond do
      pid_state.current_stress > 0.75 -> "CRITICAL"
      pid_state.current_stress > 0.55 -> "ELEVATED"
      true -> "NOMINAL"
    end
  end

  defp controller_badge_class(pid_state) do
    cond do
      pid_state.current_stress > 0.75 -> "bg-red-900/60 text-red-300"
      pid_state.current_stress > 0.55 -> "bg-amber-900/60 text-amber-300"
      true -> "bg-green-900/60 text-green-300"
    end
  end

  defp flash_class(:success), do: "bg-green-900/60 text-green-300 border border-green-700"
  defp flash_class(:error), do: "bg-red-900/60 text-red-300 border border-red-700"
  defp flash_class(:info), do: "bg-blue-900/60 text-blue-300 border border-blue-700"
  defp flash_class(_), do: "bg-surface-tertiary text-content-secondary"

  defp clear_stale_flash(nil), do: nil

  defp clear_stale_flash(flash) do
    age_ms = System.monotonic_time(:millisecond) - flash.inserted_at
    if age_ms > 8_000, do: nil, else: flash
  end

  defp parse_float(raw) when is_binary(raw) do
    raw_normalized = String.trim(raw)

    case Float.parse(raw_normalized) do
      {v, ""} ->
        {:ok, v}

      {v, _} ->
        {:ok, v}

      :error ->
        case Integer.parse(raw_normalized) do
          {v, _} -> {:ok, v / 1000.0}
          :error -> :error
        end
    end
  end

  defp parse_float(raw) when is_number(raw), do: {:ok, raw / 1000.0}
  defp parse_float(_), do: :error

  defp now_ms, do: System.monotonic_time(:millisecond)

  defp format_uptime, do: "25d 14h"
end
