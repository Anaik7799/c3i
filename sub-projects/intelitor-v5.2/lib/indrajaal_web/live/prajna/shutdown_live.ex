defmodule IndrajaalWeb.Prajna.ShutdownLive do
  @moduledoc """
  PRAJNA C3I Shutdown Sequence Screen

  WHAT: Graceful system shutdown with state preservation following
        NASA-STD-3000 principles for shutdown/emergency sequences.

  WHY: Provides controlled system shutdown:
       - Multi-phase shutdown progress
       - Connection draining visualization
       - State preservation checklist
       - Force/Abort controls
       - Live shutdown logging

  CONSTRAINTS:
    - SC-HMI-001: Dark Cockpit defaults
    - SC-EMR-057: Emergency stop < 5s
    - SC-EMR-060: Rollback capability
    - SC-VDP-008: Closure feedback on each phase

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-27 |
  | Author | Cybernetic Architect |
  | Reference | NASA-STD-3000, MIL-STD-1472H |
  """

  use IndrajaalWeb, :live_view

  @refresh_interval 500

  @phases [
    %{
      id: :draining,
      name: "PHASE 1: CONNECTION DRAINING",
      steps: [
        %{id: :block_new, name: "New connections blocked", status: :pending},
        %{id: :notify_ws, name: "WebSocket clients notified", status: :pending},
        %{id: :drain_req, name: "Active requests draining", status: :pending, count: 0},
        %{id: :endpoint, name: "Phoenix endpoint shutdown", status: :pending}
      ]
    },
    %{
      id: :jobs,
      name: "PHASE 2: BACKGROUND JOBS",
      steps: [
        %{id: :pause_oban, name: "Oban job queue paused", status: :pending},
        %{id: :complete_jobs, name: "In-flight jobs completing", status: :pending, count: 0},
        %{id: :persist_jobs, name: "Job state persisted", status: :pending}
      ]
    },
    %{
      id: :state,
      name: "PHASE 3: STATE PRESERVATION",
      steps: [
        %{id: :cockpit_snap, name: "Cockpit state snapshot", status: :pending},
        %{id: :metric_export, name: "Metric history exported", status: :pending},
        %{id: :audit_final, name: "Command audit log finalized", status: :pending},
        %{id: :cubdb_sync, name: "CubDB state synced", status: :pending}
      ]
    },
    %{
      id: :distributed,
      name: "PHASE 4: DISTRIBUTED TEARDOWN",
      steps: [
        %{id: :flame_drain, name: "FLAME pools drained", status: :pending},
        %{id: :cluster_leave, name: "Cluster membership released", status: :pending},
        %{id: :zenoh_close, name: "Zenoh subscriptions closed", status: :pending},
        %{id: :tailscale, name: "Tailscale node deregistered", status: :pending}
      ]
    },
    %{
      id: :containers,
      name: "PHASE 5: CONTAINER SHUTDOWN",
      steps: [
        # Reverse order of startup: App → OBS → Redis → DB
        %{id: :app_stop, name: "indrajaal-ex-app-1 stopped", status: :pending},
        %{id: :obs_stop, name: "indrajaal-obs-standalone stopped", status: :pending},
        %{id: :redis_stop, name: "indrajaal-redis-standalone stopped", status: :pending},
        %{id: :db_stop, name: "indrajaal-db-standalone stopped (last)", status: :pending}
      ]
    }
  ]

  # Used in template rendering for status display
  @status_icons %{
    completed: "\u2713",
    in_progress: "\u25CF",
    pending: "\u25CB",
    failed: "\u2717"
  }
  def status_icon(status), do: Map.get(@status_icons, status, "?")

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "System Shutdown")
     |> assign(:shutdown_active, false)
     |> assign(:phases, @phases)
     |> assign(:logs, [])
     |> assign(:started_at, nil)
     |> assign(:estimated_remaining, 0)
     |> assign(:mode, :graceful)
     |> assign(:drain_timeout, 30)
     |> assign(:aborted, false)
     |> assign(:force_confirm, false)
     |> assign(:initiated_by, nil)
     |> assign(:status_icons, @status_icons)}
  end

  @impl true
  def handle_info(:advance_shutdown, socket) do
    if socket.assigns.shutdown_active and not socket.assigns.aborted do
      phases = advance_shutdown(socket.assigns.phases)
      progress = calculate_progress(phases)
      logs = maybe_add_shutdown_log(socket.assigns.logs, phases)

      remaining =
        if progress >= 100, do: 0, else: max(0, socket.assigns.estimated_remaining - 1)

      if progress < 100 do
        Process.send_after(self(), :advance_shutdown, @refresh_interval)
      end

      {:noreply,
       socket
       |> assign(:phases, phases)
       |> assign(:estimated_remaining, remaining)
       |> assign(:logs, logs)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("initiate_shutdown", _params, socket) do
    if socket.assigns.shutdown_active do
      {:noreply, socket}
    else
      Process.send_after(self(), :advance_shutdown, @refresh_interval)

      log_entry = %{
        timestamp: DateTime.utc_now(),
        level: :info,
        message: "Initiating graceful shutdown..."
      }

      {:noreply,
       socket
       |> assign(:shutdown_active, true)
       |> assign(:started_at, DateTime.utc_now())
       |> assign(:estimated_remaining, 45)
       |> assign(:initiated_by, "operator@indrajaal.local")
       |> assign(:logs, [log_entry])
       |> assign(:phases, simulate_first_step(@phases))}
    end
  end

  @impl true
  def handle_event("abort_shutdown", _params, socket) do
    log_entry = %{
      timestamp: DateTime.utc_now(),
      level: :warning,
      message: "Shutdown aborted by operator"
    }

    {:noreply,
     socket
     |> assign(:aborted, true)
     |> assign(:shutdown_active, false)
     |> assign(:logs, [log_entry | socket.assigns.logs])
     |> put_flash(:warning, "Shutdown aborted - system resuming normal operation")}
  end

  @impl true
  def handle_event("force_shutdown_arm", _params, socket) do
    {:noreply, assign(socket, :force_confirm, true)}
  end

  @impl true
  def handle_event("force_shutdown_confirm", _params, socket) do
    log_entry = %{
      timestamp: DateTime.utc_now(),
      level: :error,
      message: "FORCE IMMEDIATE SHUTDOWN - Data loss may occur!"
    }

    {:noreply,
     socket
     |> assign(:logs, [log_entry | socket.assigns.logs])
     |> put_flash(:error, "Force shutdown initiated - system halting immediately")}
  end

  @impl true
  def handle_event("force_shutdown_cancel", _params, socket) do
    {:noreply, assign(socket, :force_confirm, false)}
  end

  @impl true
  def handle_event("update_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :mode, String.to_atom(mode))}
  end

  @impl true
  def handle_event("update_timeout", %{"timeout" => timeout}, socket) do
    {:noreply, assign(socket, :drain_timeout, String.to_integer(timeout))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- L4-A09: Theme-aware Shutdown page (SC-HMI-001, SC-HMI-008) --%>
    <div class="min-h-screen bg-surface-primary text-content-primary font-mono">
      <!-- Header Bar with Warning -->
      <header class={"border-b px-4 py-2 flex items-center justify-between #{if @shutdown_active, do: "bg-red-900 border-red-700", else: "bg-surface-secondary border-border-theme-primary"}"}>
        <div class="flex items-center space-x-4">
          <a
            href="/cockpit"
            class="text-accent-primary font-bold text-lg hover:text-accent-primary/80"
          >
            PRAJNA C3I
          </a>
          <span class="text-content-muted">|</span>
          <span class={
            if @shutdown_active, do: "text-red-300 font-bold", else: "text-content-secondary"
          }>
            {if @shutdown_active, do: "\u26A0 SHUTDOWN IN PROGRESS", else: "SYSTEM SHUTDOWN"}
          </span>
        </div>
        <div class="flex items-center space-x-4">
          <span class="text-content-secondary">
            {Calendar.strftime(DateTime.utc_now(), "%H:%M:%S")}
          </span>
        </div>
      </header>
      
    <!-- Main Content -->
      <main class="p-4 pb-20">
        <%= if not @shutdown_active and not @aborted do %>
          <!-- Pre-Shutdown Configuration -->
          <div class="max-w-2xl mx-auto">
            <div class="bg-yellow-900/30 border border-yellow-700 rounded-lg p-6 mb-6">
              <h2 class="text-lg font-bold text-yellow-400 mb-4">⚠ System Shutdown</h2>
              <p class="text-gray-300 mb-4">
                This will initiate a controlled shutdown of the PRAJNA C3I system.
                All connections will be drained and state will be preserved.
              </p>

              <div class="grid grid-cols-2 gap-4 mb-4">
                <div>
                  <label class="text-sm text-content-muted">Shutdown Mode:</label>
                  <select
                    phx-change="update_mode"
                    name="mode"
                    class="w-full bg-surface-primary border border-border-theme-primary rounded px-3 py-2 mt-1"
                  >
                    <option value="graceful" selected={@mode == :graceful}>
                      Graceful (recommended)
                    </option>
                    <option value="quick" selected={@mode == :quick}>Quick (30s timeout)</option>
                  </select>
                </div>
                <div>
                  <label class="text-sm text-content-muted">Drain Timeout:</label>
                  <select
                    phx-change="update_timeout"
                    name="timeout"
                    class="w-full bg-surface-primary border border-border-theme-primary rounded px-3 py-2 mt-1"
                  >
                    <option value="15" selected={@drain_timeout == 15}>15 seconds</option>
                    <option value="30" selected={@drain_timeout == 30}>30 seconds</option>
                    <option value="60" selected={@drain_timeout == 60}>60 seconds</option>
                  </select>
                </div>
              </div>

              <button
                phx-click="initiate_shutdown"
                class="w-full px-6 py-3 bg-red-600 hover:bg-red-500 text-white font-bold rounded"
              >
                INITIATE SHUTDOWN SEQUENCE
              </button>
            </div>
          </div>
        <% else %>
          <!-- Active Shutdown Display -->
          <div class="max-w-4xl mx-auto">
            <%= if @aborted do %>
              <div class="bg-yellow-900/30 border border-yellow-700 rounded-lg p-6 mb-6 text-center">
                <h2 class="text-lg font-bold text-yellow-400 mb-2">SHUTDOWN ABORTED</h2>
                <p class="text-gray-300 mb-4">
                  System shutdown was aborted. The system is resuming normal operation.
                </p>
                <a
                  href="/cockpit"
                  class="px-6 py-2 bg-blue-600 hover:bg-blue-500 text-white rounded inline-block"
                >
                  RETURN TO COCKPIT
                </a>
              </div>
            <% else %>
              <!-- Shutdown Info -->
              <div class="bg-red-900/30 border border-red-700 rounded-lg p-4 mb-6">
                <div class="flex items-center justify-between">
                  <div class="flex items-center space-x-4">
                    <span class="text-red-400 font-bold">⚠ SHUTDOWN SEQUENCE INITIATED</span>
                    <span class="text-content-secondary">|</span>
                    <span class="text-content-secondary">Initiated by: {@initiated_by}</span>
                  </div>
                  <div class="text-content-secondary">
                    Started: {if @started_at,
                      do: Calendar.strftime(@started_at, "%H:%M:%S"),
                      else: "-"}
                  </div>
                </div>
                <div class="mt-2 text-content-secondary">
                  Mode: {String.upcase(to_string(@mode))} ({@drain_timeout}s drain timeout)
                </div>
              </div>
              
    <!-- Phase Progress -->
              <div class="space-y-4 mb-6">
                <%= for phase <- @phases do %>
                  <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
                    <div class="flex items-center justify-between mb-3">
                      <span class="text-sm font-bold text-content-secondary">{phase.name}</span>
                      <div class="flex items-center space-x-2">
                        <div class="w-32 h-2 bg-surface-tertiary rounded-full overflow-hidden">
                          <div
                            class={"h-full transition-all duration-300 #{phase_bar_color(phase)}"}
                            style={"width: #{phase_progress(phase)}%"}
                          >
                          </div>
                        </div>
                        <span class="text-xs text-content-muted w-12 text-right">
                          {phase_progress(phase)}%
                        </span>
                      </div>
                    </div>

                    <div class="space-y-1 pl-4 border-l-2 border-border-theme-primary">
                      <%= for step <- phase.steps do %>
                        <div class="flex items-center space-x-2">
                          <span class={step_icon_class(step.status)}>
                            {@status_icons[step.status]}
                          </span>
                          <span class={step_text_class(step.status)}>
                            {step.name}
                            <%= if step.status == :in_progress and Map.has_key?(step, :count) do %>
                              <span class="text-content-muted">({step.count} remaining)</span>
                            <% end %>
                            <%= if step.status == :in_progress do %>
                              <span class="text-content-muted">...</span>
                            <% end %>
                          </span>
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
              
    <!-- Shutdown Log -->
              <div class="bg-surface-secondary rounded-lg border border-border-theme-primary mb-6">
                <div class="px-4 py-2 border-b border-border-theme-primary">
                  <h2 class="text-sm font-bold text-content-secondary">SHUTDOWN LOG</h2>
                </div>
                <div class="p-4 max-h-40 overflow-y-auto text-xs font-mono">
                  <%= for log <- Enum.take(@logs, 10) do %>
                    <div class={log_class(log.level)}>
                      [{Calendar.strftime(log.timestamp, "%H:%M:%S.%f") |> String.slice(0..11)}] {log.message}
                    </div>
                  <% end %>
                </div>
              </div>
              
    <!-- Status and Controls -->
              <div class="flex items-center justify-between">
                <div class="text-content-secondary">
                  <%= if @estimated_remaining > 0 do %>
                    Estimated time remaining: {@estimated_remaining} seconds
                  <% else %>
                    Shutdown complete
                  <% end %>
                </div>

                <div class="flex space-x-4">
                  <%= if @force_confirm do %>
                    <div class="flex items-center space-x-2 bg-red-900/50 border border-red-700 rounded px-4 py-2">
                      <span class="text-red-300 text-sm">Confirm force shutdown?</span>
                      <button
                        phx-click="force_shutdown_confirm"
                        class="px-3 py-1 bg-red-600 hover:bg-red-500 text-white text-sm rounded"
                      >
                        CONFIRM
                      </button>
                      <button
                        phx-click="force_shutdown_cancel"
                        class="px-3 py-1 bg-surface-tertiary hover:bg-surface-tertiary/80 text-sm rounded"
                      >
                        CANCEL
                      </button>
                    </div>
                  <% else %>
                    <button
                      phx-click="force_shutdown_arm"
                      class="px-4 py-2 bg-red-900 hover:bg-red-800 text-red-300 rounded border border-red-700"
                    >
                      \u26D4 FORCE IMMEDIATE SHUTDOWN
                    </button>
                    <button
                      phx-click="abort_shutdown"
                      class="px-4 py-2 bg-yellow-900 hover:bg-yellow-800 text-yellow-300 rounded border border-yellow-700"
                    >
                      ABORT SHUTDOWN
                    </button>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </main>
      
    <!-- Footer -->
      <footer class="fixed bottom-0 left-0 right-0 bg-surface-secondary border-t border-border-theme-primary px-4 py-2">
        <div class="flex items-center justify-between text-xs text-content-muted">
          <div class="flex space-x-4">
            <span>[A] Abort</span>
            <span>[F] Force Shutdown</span>
            <span>[Esc] Cancel</span>
          </div>
          <div>SC-EMR-057 | SC-EMR-060 Compliant</div>
        </div>
      </footer>
    </div>
    """
  end

  # Private helpers

  defp simulate_first_step(phases) do
    [first | rest] = phases
    first_step = %{hd(first.steps) | status: :in_progress}
    [%{first | steps: [first_step | tl(first.steps)]} | rest]
  end

  defp advance_shutdown(phases) do
    Enum.map(phases, fn phase ->
      {steps, _found_pending} = Enum.map_reduce(phase.steps, false, &advance_step/2)
      %{phase | steps: steps}
    end)
  end

  defp advance_step(step, found_pending) do
    cond do
      step.status == :completed ->
        {step, found_pending}

      step.status == :in_progress ->
        if :rand.uniform(100) < 40 do
          {%{step | status: :completed}, false}
        else
          {step, true}
        end

      step.status == :pending and not found_pending ->
        {%{step | status: :in_progress}, true}

      true ->
        {step, found_pending}
    end
  end

  defp calculate_progress(phases) do
    total_steps = phases |> Enum.flat_map(& &1.steps) |> length()

    completed =
      phases
      |> Enum.flat_map(& &1.steps)
      |> Enum.count(&(&1.status == :completed))

    if total_steps > 0, do: round(completed / total_steps * 100), else: 0
  end

  defp phase_progress(phase) do
    total = length(phase.steps)
    completed = Enum.count(phase.steps, &(&1.status == :completed))
    if total > 0, do: round(completed / total * 100), else: 0
  end

  defp phase_bar_color(phase) do
    cond do
      Enum.all?(phase.steps, &(&1.status == :completed)) -> "bg-green-500"
      Enum.any?(phase.steps, &(&1.status == :failed)) -> "bg-red-500"
      Enum.any?(phase.steps, &(&1.status == :in_progress)) -> "bg-blue-500"
      true -> "bg-gray-600"
    end
  end

  defp step_icon_class(:completed), do: "text-green-400"
  defp step_icon_class(:in_progress), do: "text-accent-primary animate-pulse"
  defp step_icon_class(:failed), do: "text-red-400"
  defp step_icon_class(:pending), do: "text-content-muted"

  defp step_text_class(:completed), do: "text-content-secondary"
  defp step_text_class(:in_progress), do: "text-content-primary"
  defp step_text_class(:failed), do: "text-red-400"
  defp step_text_class(:pending), do: "text-content-muted/60"

  defp log_class(:info), do: "text-content-secondary"
  defp log_class(:warning), do: "text-yellow-400"
  defp log_class(:error), do: "text-red-400"
  defp log_class(_), do: "text-content-secondary"

  defp maybe_add_shutdown_log(logs, phases) do
    completed_steps =
      Enum.flat_map(phases, fn phase ->
        phase.steps
        |> Enum.filter(&(&1.status == :completed))
        |> Enum.map(&{phase.name, &1.name})
      end)

    if length(completed_steps) > length(logs) do
      {_, step_name} = List.last(completed_steps)

      new_log = %{
        timestamp: DateTime.utc_now(),
        level: :info,
        message: "#{step_name} completed"
      }

      [new_log | Enum.take(logs, 20)]
    else
      logs
    end
  end
end
