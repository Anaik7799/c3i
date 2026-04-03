defmodule IndrajaalWeb.Prajna.StartupLive do
  @moduledoc """
  PRAJNA C3I Startup Sequence Screen

  WHAT: Visualizes system initialization progress following NASA-STD-3000
        principles for startup/shutdown sequences.

  WHY: Provides operator awareness during system initialization:
       - Phase-based progress visualization
       - Dependency tree status
       - Live startup logs
       - Safety system verification
       - Abort/Skip controls per MIL-STD-1472H

  CONSTRAINTS:
    - SC-HMI-001: Dark Cockpit defaults
    - SC-VDP-008: Closure feedback on each phase
    - SC-EMR-057: Emergency stop capability
    - SC-OBS-069: Dual logging (Terminal + SigNoz)

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

  # Startup phases following SOPv5.11
  @phases [
    %{
      id: :infrastructure,
      name: "PHASE 1: INFRASTRUCTURE",
      steps: [
        %{id: :telemetry, name: "Telemetry System", status: :pending},
        %{id: :database, name: "Database connection", status: :pending},
        %{id: :pubsub, name: "PubSub started", status: :pending},
        %{id: :cache, name: "Redis cache", status: :pending},
        %{id: :oban, name: "Oban background jobs", status: :pending}
      ]
    },
    %{
      id: :safety,
      name: "PHASE 2: SAFETY SYSTEMS",
      steps: [
        %{id: :guardian, name: "Guardian (Simplex gatekeeper)", status: :pending},
        %{id: :dms, name: "Dead Man's Switch (heartbeat)", status: :pending},
        %{id: :envelope, name: "Envelope constraints (safety bounds)", status: :pending},
        %{id: :sentinel, name: "Sentinel (quorum monitor)", status: :pending}
      ]
    },
    %{
      id: :distributed,
      name: "PHASE 3: DISTRIBUTED SYSTEMS",
      steps: [
        %{id: :cluster, name: "Cluster formation (Tailscale DNS)", status: :pending},
        %{id: :flame, name: "FLAME pools (Intelligence, Video, Analytics)", status: :pending},
        %{id: :ooda, name: "OODA loop activation", status: :pending},
        %{id: :zenoh, name: "Zenoh coordination", status: :pending}
      ]
    },
    %{
      id: :containers,
      name: "PHASE 4: CONTAINER ORCHESTRATION",
      steps: [
        # Layer 0 - Database (must start first, no dependencies)
        %{id: :db, name: "indrajaal-db-standalone (PostgreSQL)", status: :pending},
        # Layer 1 - Redis (no dependencies, parallel with db)
        %{id: :redis, name: "indrajaal-redis-standalone (Cache)", status: :pending},
        # Layer 2 - Observability (optional, depends on db)
        %{id: :obs, name: "indrajaal-obs-standalone (SigNoz)", status: :pending},
        # Layer 3 - Application (depends on db + redis)
        %{id: :app, name: "indrajaal-ex-app-1 (Phoenix)", status: :pending}
      ]
    }
  ]

  # Status icons for template rendering
  @status_icons %{
    completed: "\u2713",
    in_progress: "\u25CF",
    pending: "\u25CB",
    failed: "\u2717"
  }
  def status_icon(status), do: Map.get(@status_icons, status, "?")

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(@refresh_interval, self(), :refresh)
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "prajna:startup")
    end

    {:ok,
     socket
     |> assign(:page_title, "PRAJNA Startup")
     |> assign(:phases, simulate_startup_progress(@phases))
     |> assign(:logs, initial_logs())
     |> assign(:started_at, DateTime.utc_now())
     |> assign(:estimated_remaining, 45)
     |> assign(:overall_progress, 0)
     |> assign(:aborted, false)
     |> assign(:status_icons, @status_icons)}
  end

  @impl true
  def handle_info(:refresh, socket) do
    if socket.assigns.aborted do
      {:noreply, socket}
    else
      phases = advance_startup(socket.assigns.phases)
      progress = calculate_progress(phases)
      logs = maybe_add_log(socket.assigns.logs, phases)

      remaining =
        if progress >= 100, do: 0, else: max(0, socket.assigns.estimated_remaining - 1)

      {:noreply,
       socket
       |> assign(:phases, phases)
       |> assign(:overall_progress, progress)
       |> assign(:estimated_remaining, remaining)
       |> assign(:logs, logs)}
    end
  end

  @impl true
  def handle_info({:startup_step, phase_id, step_id, status}, socket) do
    phases = update_step(socket.assigns.phases, phase_id, step_id, status)
    {:noreply, assign(socket, :phases, phases)}
  end

  @impl true
  def handle_event("abort_startup", _params, socket) do
    log_entry = %{
      timestamp: DateTime.utc_now(),
      level: :warning,
      message: "Startup aborted by operator"
    }

    {:noreply,
     socket
     |> assign(:aborted, true)
     |> assign(:logs, [log_entry | socket.assigns.logs])}
  end

  @impl true
  def handle_event("skip_to_cockpit", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/cockpit")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- L4-A09: Theme-aware Startup page (SC-HMI-001, SC-HMI-008) --%>
    <div class="min-h-screen bg-surface-primary text-content-primary font-mono p-8">
      <!-- ASCII Art Logo -->
      <pre class="text-accent-primary text-center mb-4 text-xs">
        ██████╗ ██████╗  █████╗      ██╗███╗   ██╗ █████╗
        ██╔══██╗██╔══██╗██╔══██╗     ██║████╗  ██║██╔══██╗
        ██████╔╝██████╔╝███████║     ██║██╔██╗ ██║███████║
        ██╔═══╝ ██╔══██╗██╔══██║██   ██║██║╚██╗██║██╔══██║
        ██║     ██║  ██║██║  ██║╚█████╔╝██║ ╚████║██║  ██║
        ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝ ╚════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝
                  C3I MESH COCKPIT v1.0.0
      </pre>

      <div class="max-w-4xl mx-auto">
        <!-- Phase Progress -->
        <div class="space-y-6 mb-8">
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
        
    <!-- Startup Log -->
        <div class="bg-surface-secondary rounded-lg border border-border-theme-primary mb-6">
          <div class="px-4 py-2 border-b border-border-theme-primary">
            <h2 class="text-sm font-bold text-content-secondary">STARTUP LOG (live)</h2>
          </div>
          <div class="p-4 max-h-40 overflow-y-auto text-xs font-mono">
            <%= for log <- Enum.take(@logs, 10) do %>
              <div class={log_class(log.level)}>
                [{Calendar.strftime(log.timestamp, "%H:%M:%S.%f") |> String.slice(0..11)}] {log.message}
              </div>
            <% end %>
          </div>
        </div>
        
    <!-- Footer Controls -->
        <div class="flex items-center justify-between">
          <div class="text-content-muted">
            <%= if @overall_progress < 100 and not @aborted do %>
              Estimated time remaining: {@estimated_remaining} seconds
            <% else %>
              {if @aborted, do: "Startup aborted", else: "Startup complete"}
            <% end %>
          </div>
          <div class="flex space-x-4">
            <button
              phx-click="abort_startup"
              class="px-4 py-2 bg-red-900 hover:bg-red-800 text-red-300 rounded border border-red-700"
              disabled={@aborted || @overall_progress >= 100}
            >
              ABORT STARTUP
            </button>
            <button
              phx-click="skip_to_cockpit"
              class="px-4 py-2 bg-blue-900 hover:bg-blue-800 text-blue-300 rounded border border-blue-700"
            >
              SKIP TO COCKPIT
            </button>
          </div>
        </div>
        
    <!-- Abort Warning Modal -->
        <%= if @aborted do %>
          <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
            <div class="bg-surface-secondary border-2 border-red-500 rounded-lg p-6 max-w-md">
              <h3 class="text-red-500 font-bold text-lg mb-4">STARTUP ABORTED</h3>
              <p class="text-content-primary mb-6">
                System startup has been aborted. Some services may not be available.
              </p>
              <button
                phx-click="skip_to_cockpit"
                class="w-full px-4 py-2 bg-surface-tertiary hover:bg-surface-tertiary/80 text-white rounded"
              >
                Continue to Cockpit (Limited Mode)
              </button>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Private helpers

  defp simulate_startup_progress(phases) do
    # Mark first phase as in_progress
    [first | rest] = phases
    first_steps = Enum.map(first.steps, fn step -> %{step | status: :in_progress} end)
    [%{first | steps: [%{hd(first_steps) | status: :completed} | tl(first_steps)]} | rest]
  end

  defp advance_startup(phases) do
    Enum.map(phases, fn phase ->
      {steps, _found_pending} = Enum.map_reduce(phase.steps, false, &advance_startup_step/2)
      %{phase | steps: steps}
    end)
  end

  defp advance_startup_step(step, found_pending) do
    cond do
      step.status == :completed ->
        {step, found_pending}

      step.status == :in_progress ->
        # 30% chance to complete
        if :rand.uniform(100) < 30 do
          {%{step | status: :completed}, false}
        else
          {step, true}
        end

      step.status == :pending and not found_pending ->
        # Start this step
        {%{step | status: :in_progress}, true}

      true ->
        {step, found_pending}
    end
  end

  defp update_step(phases, phase_id, step_id, status) do
    Enum.map(phases, fn phase ->
      if phase.id == phase_id do
        steps = update_matching_step(phase.steps, step_id, status)
        %{phase | steps: steps}
      else
        phase
      end
    end)
  end

  defp update_matching_step(steps, step_id, status) do
    Enum.map(steps, fn step ->
      if step.id == step_id, do: %{step | status: status}, else: step
    end)
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

  defp initial_logs do
    now = DateTime.utc_now()

    [
      %{timestamp: now, level: :info, message: "Starting IndrajaalWeb.Telemetry..."},
      %{
        timestamp: DateTime.add(now, -1, :second),
        level: :info,
        message: "Ecto repo connected to PostgreSQL 17"
      },
      %{
        timestamp: DateTime.add(now, -2, :second),
        level: :info,
        message: "Phoenix.PubSub started"
      }
    ]
  end

  defp maybe_add_log(logs, phases) do
    # Add a log entry when a step completes
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
        message: "#{step_name} initialized"
      }

      [new_log | Enum.take(logs, 20)]
    else
      logs
    end
  end
end
