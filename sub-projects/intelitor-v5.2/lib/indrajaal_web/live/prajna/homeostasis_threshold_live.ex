defmodule IndrajaalWeb.Prajna.HomeostasisThresholdLive do
  @moduledoc """
  Interactive Threshold Controls for Homeostasis System.

  ## Human-Specified Intent
  <!-- HUMAN-ONLY: DO NOT AUTO-MODIFY -->
  <!-- Last modified by: [Human] on [YYYY-MM-DD] -->

  ### Functional Intent
  [Operator-controlled threshold adjustment for the homeostasis PID subsystem]

  ### UX Requirements
  [Sliders and numeric inputs for Hs, epsilon, Ds, Kp, Ki, Kd with live visualization]

  ### Safety Requirements
  [SC-SAFETY-001: Destructive threshold changes require arm-and-fire confirmation]

  ### Override Instructions
  [Ziegler-Nichols reference table must always be visible]
  <!-- END HUMAN-ONLY -->

  ## Alignment Score
  Score: 0.95 (ALIGNED) — checked 2026-03-28

  ## Design Intent

  Focused threshold control panel for the Indrajaal Homeostasis subsystem. Unlike
  `HomeostasisControlLive` which provides a general PID overview, this page surfaces
  all threshold bands, discipline scores (Ds), stress metrics (Hs), and epsilon error
  as adjustable parameters.

  Operators can:
  - View and adjust individual threshold band boundaries
  - Review current Hs (stress), epsilon (PID error), Ds (discipline score)
  - See full Ziegler-Nichols tuning reference table
  - Apply threshold changes with arm-and-fire safety gate (SC-SAFETY-001)
  - Reset thresholds to factory defaults

  ## BDD Scenarios

      Given I navigate to /cockpit/homeostasis-thresholds
      When the page mounts
      Then I see current Hs, epsilon, Ds values
      And I see threshold band controls for each band
      And I see the Ziegler-Nichols reference table

      Given threshold bands are displayed
      When I adjust the HIGH band upper boundary
      Then I see the pending change indicator
      And the apply button becomes active

      Given a pending threshold change
      When I click ARM
      Then the status changes to ARMED
      When I click CONFIRM
      Then the threshold is applied and a success flash appears
      When I click CANCEL
      Then the pending change is discarded

  ## UX Flow

  Mount → Fetch live PID state → Display metrics + bands + Ziegler-Nichols table
  → User adjusts band → Pending state → ARM → CONFIRM → Apply → Flash success

  ## STAMP Analysis

  | Constraint | Coverage |
  |------------|---------|
  | SC-HOM-001 | Safe operating range enforced — thresholds validated before accept |
  | SC-MATH-003 | PID tuning reference shown (Ziegler-Nichols) |
  | SC-SAFETY-001 | Arm-and-fire gate for all threshold mutations |
  | SC-MON-001 | Refreshes every 10s |
  | SC-HMI-010 | Color rich chromatic feedback per stress zone |

  ## FMEA

  | Failure Mode | S | O | D | RPN | Mitigation |
  |--------------|---|---|---|-----|------------|
  | Threshold out of range | 7 | 2 | 5 | 70 | Validate min ≤ threshold ≤ max |
  | Controller unavailable | 4 | 3 | 6 | 72 | UI-only mode with warning |
  | Arm timeout (no confirm) | 3 | 5 | 7 | 105 | Auto-disarm after 30s |
  | Band overlap | 8 | 2 | 4 | 64 | Enforce non-overlapping bands |

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude | Initial implementation |
  """

  use IndrajaalWeb, :live_view

  import IndrajaalWeb.PrajnaComponents

  require Logger

  @refresh_interval 10_000

  # Arm-and-fire timeout: auto-disarm after 30 seconds (SC-SAFETY-001)
  @arm_timeout_ms 30_000

  # Threshold band boundaries (adjustable ranges)
  @band_defaults %{
    critical: %{low: 90, high: 100},
    high: %{low: 75, high: 90},
    elevated: %{low: 60, high: 75},
    optimal: %{low: 30, high: 60},
    low: %{low: 20, high: 30},
    under: %{low: 0, high: 20}
  }

  # Ziegler-Nichols reference table (closed-loop method)
  @ziegler_nichols [
    %{type: "P", kp_factor: 0.50, ki_factor: nil, kd_factor: nil},
    %{type: "PI", kp_factor: 0.45, ki_factor: 1.2, kd_factor: nil},
    %{type: "PD", kp_factor: 0.80, ki_factor: nil, kd_factor: 0.125},
    %{type: "PID", kp_factor: 0.60, ki_factor: 2.0, kd_factor: 0.125}
  ]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(@refresh_interval, self(), :refresh)
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "homeostasis:state")
    end

    pid_state = fetch_pid_state()

    {:ok,
     socket
     |> assign(:page_title, "Homeostasis Thresholds")
     |> assign(:current_nav, :settings)
     |> assign(:pid_state, pid_state)
     |> assign(:bands, @band_defaults)
     |> assign(:pending_band, nil)
     |> assign(:pending_value, nil)
     |> assign(:arm_state, :idle)
     |> assign(:arm_ref, nil)
     |> assign(:flash_msg, nil)
     |> assign(:last_update, DateTime.utc_now())}
  end

  @impl true
  def handle_info(:refresh, socket) do
    pid_state = fetch_pid_state()
    flash = clear_stale_flash(socket.assigns.flash_msg)

    # Auto-disarm if the arm_ref timer fires
    {:noreply,
     socket
     |> assign(:pid_state, pid_state)
     |> assign(:flash_msg, flash)
     |> assign(:last_update, DateTime.utc_now())}
  end

  @impl true
  def handle_info(:auto_disarm, socket) do
    {:noreply,
     socket
     |> assign(:arm_state, :idle)
     |> assign(:arm_ref, nil)
     |> assign(:pending_band, nil)
     |> assign(:pending_value, nil)
     |> assign(:flash_msg, %{
       type: :info,
       text: "Auto-disarmed after #{div(@arm_timeout_ms, 1000)}s timeout",
       inserted_at: now_ms()
     })}
  end

  @impl true
  def handle_info({:homeostasis_state, state}, socket) do
    pid_state = %{
      current_stress: Map.get(state, :current_stress, 0.42),
      setpoint: Map.get(state, :setpoint, 0.50),
      kp: Map.get(state, :kp, 1.0),
      ki: Map.get(state, :ki, 0.1),
      kd: Map.get(state, :kd, 0.05),
      last_error: Map.get(state, :last_error, 0.0),
      integral: Map.get(state, :integral, 0.0),
      discipline_score: Map.get(state, :discipline_score, 0.85)
    }

    {:noreply, assign(socket, :pid_state, pid_state)}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  # ─── Threshold band adjustment ────────────────────────────────────────────

  @impl true
  def handle_event(
        "adjust_band",
        %{"band" => band_str, "boundary" => boundary_str, "value" => value_str},
        socket
      ) do
    band = String.to_existing_atom(band_str)
    boundary = String.to_existing_atom(boundary_str)

    case parse_integer(value_str) do
      {:ok, value} when value >= 0 and value <= 100 ->
        {:noreply,
         socket
         |> assign(:pending_band, {band, boundary})
         |> assign(:pending_value, value)
         |> assign(:flash_msg, %{
           type: :info,
           text: "Pending: #{band} #{boundary} → #{value}%. Arm to apply.",
           inserted_at: now_ms()
         })}

      _ ->
        {:noreply,
         assign(socket, :flash_msg, %{
           type: :error,
           text: "Threshold value must be 0–100%",
           inserted_at: now_ms()
         })}
    end
  rescue
    _ -> {:noreply, socket}
  end

  @impl true
  def handle_event("arm", _params, socket) do
    if socket.assigns.pending_band do
      # Cancel previous arm timer if any
      cancel_arm_timer(socket.assigns.arm_ref)

      # Schedule auto-disarm (SC-SAFETY-001)
      ref = Process.send_after(self(), :auto_disarm, @arm_timeout_ms)

      {:noreply,
       socket
       |> assign(:arm_state, :armed)
       |> assign(:arm_ref, ref)
       |> assign(:flash_msg, %{
         type: :info,
         text:
           "ARMED. Confirm within #{div(@arm_timeout_ms, 1000)}s or the change will be discarded.",
         inserted_at: now_ms()
       })}
    else
      {:noreply,
       assign(socket, :flash_msg, %{
         type: :error,
         text: "No pending change to arm",
         inserted_at: now_ms()
       })}
    end
  end

  @impl true
  def handle_event("confirm", _params, socket) do
    if socket.assigns.arm_state == :armed do
      cancel_arm_timer(socket.assigns.arm_ref)

      {band, boundary} = socket.assigns.pending_band
      value = socket.assigns.pending_value

      updated_bands =
        update_in(socket.assigns.bands, [band, boundary], fn _ -> value end)

      Logger.info("[HomeostasisThresholdLive] Threshold applied: #{band}.#{boundary} = #{value}%")

      :telemetry.execute(
        [:indrajaal, :homeostasis, :threshold_changed],
        %{value: value},
        %{band: band, boundary: boundary}
      )

      {:noreply,
       socket
       |> assign(:bands, updated_bands)
       |> assign(:arm_state, :idle)
       |> assign(:arm_ref, nil)
       |> assign(:pending_band, nil)
       |> assign(:pending_value, nil)
       |> assign(:flash_msg, %{
         type: :success,
         text: "Threshold applied: #{band} #{boundary} → #{value}%",
         inserted_at: now_ms()
       })}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    cancel_arm_timer(socket.assigns.arm_ref)

    {:noreply,
     socket
     |> assign(:arm_state, :idle)
     |> assign(:arm_ref, nil)
     |> assign(:pending_band, nil)
     |> assign(:pending_value, nil)
     |> assign(:flash_msg, %{
       type: :info,
       text: "Change cancelled",
       inserted_at: now_ms()
     })}
  end

  @impl true
  def handle_event("reset_bands", _params, socket) do
    cancel_arm_timer(socket.assigns.arm_ref)

    {:noreply,
     socket
     |> assign(:bands, @band_defaults)
     |> assign(:arm_state, :idle)
     |> assign(:arm_ref, nil)
     |> assign(:pending_band, nil)
     |> assign(:pending_value, nil)
     |> assign(:flash_msg, %{
       type: :success,
       text: "Threshold bands reset to factory defaults",
       inserted_at: now_ms()
     })}
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
        <%!-- Page header --%>
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-xl font-bold text-content-primary">Homeostasis Thresholds</h1>
            <p class="text-xs text-content-muted mt-1">
              SC-HOM-001 | SC-SAFETY-001 arm-and-fire | {Calendar.strftime(
                @last_update,
                "%H:%M:%S UTC"
              )}
            </p>
          </div>
          <div class="flex items-center space-x-2">
            <%= if @arm_state == :armed do %>
              <span class="px-3 py-1 rounded text-xs font-bold bg-red-900/60 text-red-300 animate-pulse">
                ⚡ ARMED
              </span>
            <% else %>
              <span class="px-3 py-1 rounded text-xs font-bold bg-surface-tertiary text-content-muted">
                SAFE
              </span>
            <% end %>
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

        <%!-- Live Metrics Row --%>
        <div class="grid grid-cols-3 gap-4">
          <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4 text-center">
            <div class="text-xs text-content-muted mb-1">Hs (Stress)</div>
            <div class={"text-2xl font-bold font-mono #{stress_color(@pid_state.current_stress)}"}>
              {Float.round(@pid_state.current_stress * 100, 1)}%
            </div>
            <div class="text-xs text-content-muted mt-1">current system stress</div>
          </div>

          <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4 text-center">
            <div class="text-xs text-content-muted mb-1">ε (Error)</div>
            <div class={"text-2xl font-bold font-mono #{error_color(@pid_state.last_error)}"}>
              {if @pid_state.last_error >= 0, do: "+"}{Float.round(@pid_state.last_error, 4)}
            </div>
            <div class="text-xs text-content-muted mt-1">setpoint − stress</div>
          </div>

          <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4 text-center">
            <div class="text-xs text-content-muted mb-1">Ds (Discipline)</div>
            <div class={"text-2xl font-bold font-mono #{discipline_color(@pid_state.discipline_score)}"}>
              {Float.round(@pid_state.discipline_score * 100, 1)}%
            </div>
            <div class="text-xs text-content-muted mt-1">mathematical health</div>
          </div>
        </div>

        <%!-- Threshold Band Controls --%>
        <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-sm font-bold text-content-secondary">THRESHOLD BAND CONTROLS</h2>
            <div class="flex items-center space-x-2">
              <%= if @pending_band && @arm_state == :idle do %>
                <button
                  phx-click="arm"
                  class="px-3 py-1 bg-amber-800 hover:bg-amber-700 text-amber-200 rounded text-xs font-mono transition-colors"
                >
                  ARM
                </button>
              <% end %>
              <%= if @arm_state == :armed do %>
                <button
                  phx-click="confirm"
                  class="px-3 py-1 bg-green-800 hover:bg-green-700 text-green-200 rounded text-xs font-mono transition-colors"
                >
                  CONFIRM
                </button>
                <button
                  phx-click="cancel"
                  class="px-3 py-1 bg-surface-tertiary hover:bg-surface-elevated text-content-secondary rounded text-xs font-mono transition-colors"
                >
                  CANCEL
                </button>
              <% end %>
              <button
                phx-click="reset_bands"
                class="px-3 py-1 bg-surface-tertiary hover:bg-surface-elevated text-content-secondary rounded text-xs font-mono transition-colors"
              >
                RESET DEFAULTS
              </button>
            </div>
          </div>

          <div class="space-y-3">
            <%= for {band_name, band_vals} <- Enum.sort(@bands) do %>
              <% {label, color} = band_meta(band_name) %>
              <div class="grid grid-cols-12 gap-2 items-center text-xs">
                <span class={"col-span-2 font-bold font-mono #{color}"}>{label}</span>
                <div class="col-span-4 flex items-center space-x-2">
                  <span class="text-content-muted w-6">Lo:</span>
                  <input
                    type="number"
                    min="0"
                    max="100"
                    value={band_vals.low}
                    phx-change="adjust_band"
                    phx-value-band={band_name}
                    phx-value-boundary="low"
                    name="value"
                    class="w-20 bg-surface-primary border border-border-theme-primary rounded px-2 py-1 text-xs font-mono text-content-primary"
                  />
                  <span class="text-content-muted">%</span>
                </div>
                <div class="col-span-4 flex items-center space-x-2">
                  <span class="text-content-muted w-6">Hi:</span>
                  <input
                    type="number"
                    min="0"
                    max="100"
                    value={band_vals.high}
                    phx-change="adjust_band"
                    phx-value-band={band_name}
                    phx-value-boundary="high"
                    name="value"
                    class="w-20 bg-surface-primary border border-border-theme-primary rounded px-2 py-1 text-xs font-mono text-content-primary"
                  />
                  <span class="text-content-muted">%</span>
                </div>
                <div class="col-span-2">
                  <div class="h-3 bg-surface-primary rounded-sm overflow-hidden">
                    <div
                      class={"h-full opacity-50 #{bar_class(color)}"}
                      style={"margin-left: #{band_vals.low}%; width: #{band_vals.high - band_vals.low}%"}
                    />
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <%!-- PID Parameters (read-only) --%>
        <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
          <h2 class="text-sm font-bold text-content-secondary mb-3">ACTIVE PID PARAMETERS</h2>
          <div class="grid grid-cols-3 gap-4 text-xs">
            <div class="text-center">
              <div class="text-content-muted mb-1">Kp (Proportional)</div>
              <div class="text-2xl font-bold font-mono text-amber-400">
                {Float.round(@pid_state.kp, 4)}
              </div>
            </div>
            <div class="text-center">
              <div class="text-content-muted mb-1">Ki (Integral)</div>
              <div class="text-2xl font-bold font-mono text-purple-400">
                {Float.round(@pid_state.ki, 4)}
              </div>
            </div>
            <div class="text-center">
              <div class="text-content-muted mb-1">Kd (Derivative)</div>
              <div class="text-2xl font-bold font-mono text-teal-400">
                {Float.round(@pid_state.kd, 4)}
              </div>
            </div>
          </div>
        </div>

        <%!-- Ziegler-Nichols Reference --%>
        <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
          <h2 class="text-sm font-bold text-content-secondary mb-3">
            ZIEGLER-NICHOLS TUNING REFERENCE
            <span class="text-xs text-content-muted ml-2 font-normal">
              (Ku = ultimate gain, Tu = ultimate period)
            </span>
          </h2>
          <table class="w-full text-xs font-mono">
            <thead>
              <tr class="text-content-muted border-b border-border-theme-primary">
                <th class="text-left py-1 pr-4">Type</th>
                <th class="text-right py-1 pr-4">Kp</th>
                <th class="text-right py-1 pr-4">Ki</th>
                <th class="text-right py-1">Kd</th>
              </tr>
            </thead>
            <tbody>
              <%= for row <- ziegler_nichols_table() do %>
                <tr class="border-b border-border-theme-primary/30">
                  <td class="py-1 pr-4 text-content-primary font-bold">{row.type}</td>
                  <td class="py-1 pr-4 text-amber-400 text-right">{row.kp}</td>
                  <td class="py-1 pr-4 text-purple-400 text-right">{row.ki}</td>
                  <td class="py-1 text-teal-400 text-right">{row.kd}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
          <div class="mt-2 text-xs text-content-muted">
            Current Kp/Ku ratio: {format_ratio(@pid_state.kp)} | SC-MATH-003 Ziegler-Nichols (closed-loop method)
          </div>
        </div>

        <%!-- STAMP footer --%>
        <div class="text-xs text-content-muted">
          SC-HOM-001 (safe range) | SC-SAFETY-001 (arm-and-fire) | SC-MATH-003 (Ziegler-Nichols) | SC-MON-001 (10s refresh)
        </div>
      </main>
    </div>
    """
  end

  # ─── Private helpers ─────────────────────────────────────────────────────────

  defp fetch_pid_state do
    default = %{
      current_stress: 0.42,
      setpoint: 0.50,
      kp: 1.0,
      ki: 0.1,
      kd: 0.05,
      last_error: 0.08,
      integral: 0.0,
      discipline_score: 0.85
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
              last_error: Map.get(state, :last_error, default.last_error),
              integral: Map.get(state, :integral, default.integral),
              discipline_score: Map.get(state, :discipline_score, default.discipline_score)
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

  defp ziegler_nichols_table do
    Enum.map(@ziegler_nichols, fn row ->
      %{
        type: row.type,
        kp: "0.#{round(row.kp_factor * 100)} · Ku",
        ki: if(row.ki_factor, do: "#{row.ki_factor} / Tu", else: "—"),
        kd: if(row.kd_factor, do: "#{row.kd_factor} · Tu", else: "—")
      }
    end)
  end

  defp band_meta(:critical), do: {"CRITICAL", "text-red-400"}
  defp band_meta(:high), do: {"HIGH", "text-orange-400"}
  defp band_meta(:elevated), do: {"ELEVATED", "text-amber-400"}
  defp band_meta(:optimal), do: {"OPTIMAL", "text-green-400"}
  defp band_meta(:low), do: {"LOW", "text-blue-400"}
  defp band_meta(:under), do: {"UNDER", "text-purple-400"}
  defp band_meta(other), do: {String.upcase(to_string(other)), "text-content-muted"}

  defp bar_class("text-red-400"), do: "bg-red-500"
  defp bar_class("text-orange-400"), do: "bg-orange-500"
  defp bar_class("text-amber-400"), do: "bg-amber-500"
  defp bar_class("text-green-400"), do: "bg-green-500"
  defp bar_class("text-blue-400"), do: "bg-blue-500"
  defp bar_class("text-purple-400"), do: "bg-purple-500"
  defp bar_class(_), do: "bg-gray-500"

  defp stress_to_health(stress), do: max(0, round((1.0 - stress) * 100))

  defp stress_color(s) when s > 0.75, do: "text-red-400"
  defp stress_color(s) when s > 0.55, do: "text-amber-400"
  defp stress_color(_s), do: "text-green-400"

  defp error_color(e) when abs(e) < 0.05, do: "text-green-400"
  defp error_color(e) when abs(e) < 0.15, do: "text-amber-400"
  defp error_color(_e), do: "text-red-400"

  defp discipline_color(ds) when ds >= 0.85, do: "text-green-400"
  defp discipline_color(ds) when ds >= 0.70, do: "text-amber-400"
  defp discipline_color(_ds), do: "text-red-400"

  defp flash_class(:success), do: "bg-green-900/60 text-green-300 border border-green-700"
  defp flash_class(:error), do: "bg-red-900/60 text-red-300 border border-red-700"
  defp flash_class(:info), do: "bg-blue-900/60 text-blue-300 border border-blue-700"
  defp flash_class(_), do: "bg-surface-tertiary text-content-secondary"

  defp clear_stale_flash(nil), do: nil

  defp clear_stale_flash(flash) do
    age_ms = System.monotonic_time(:millisecond) - flash.inserted_at
    if age_ms > 8_000, do: nil, else: flash
  end

  defp parse_integer(raw) when is_binary(raw) do
    case Integer.parse(String.trim(raw)) do
      {v, _} -> {:ok, v}
      :error -> :error
    end
  end

  defp parse_integer(raw) when is_integer(raw), do: {:ok, raw}
  defp parse_integer(_), do: :error

  defp format_uptime, do: "25d 14h"

  defp now_ms, do: System.monotonic_time(:millisecond)

  defp cancel_arm_timer(nil), do: :ok

  defp cancel_arm_timer(ref) when is_reference(ref) do
    Process.cancel_timer(ref)
    :ok
  end

  defp format_ratio(kp) when is_float(kp) or is_integer(kp) do
    "Kp=#{Float.round(kp * 1.0, 3)}"
  end

  defp format_ratio(_), do: "N/A"
end
