defmodule IndrajaalWeb.Prajna.CommandsLive do
  @moduledoc """
  PRAJNA C3I Two-Step Command Center

  WHAT: Command execution screen implementing two-step commit (Arm → Fire)
        pattern from MIL-STD-1472H for safety-critical operations.

  WHY: Prevents accidental command execution in high-stress situations:
       - Mode confusion is the leading cause of accidents (Redmill & Rajan, 1997)
       - Two-step commit provides cognitive barrier against errors
       - Timeout-based auto-cancel prevents stale armed commands
       - Visual distinction between armed/executing states

  CONSTRAINTS:
    - SC-HMI-004: Two-step commit UI
    - SC-MIL-001 to SC-MIL-004: Feedback latency requirements
    - SC-VDP-008: Closure feedback on command completion
    - SC-EMR-057: Emergency stop capability

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-27 |
  | Author | Cybernetic Architect |
  | Reference | MIL-STD-1472H, NUREG-0700 |
  """

  use IndrajaalWeb, :live_view

  @refresh_interval 1000
  @arm_timeout_seconds 300

  # Command categories following NUREG-0700 safety classification
  @critical_commands [:restart, :shutdown, :power_off, :isolate, :hibernate, :emergency_stop]
  def critical_commands, do: @critical_commands

  @standard_commands [:power_on, :health_check, :clear_alarms, :resume_network]
  def standard_commands, do: @standard_commands

  @scaling_commands [:scale_flame_up, :scale_flame_down, :set_load_balancer]
  def scaling_commands, do: @scaling_commands

  @command_icons %{
    restart: "\u26A0",
    shutdown: "\u26D4",
    power_off: "\u26D4",
    isolate: "\u26D4",
    hibernate: "\u26D4",
    emergency_stop: "\u2622",
    power_on: "\u25B6",
    health_check: "\u2714",
    clear_alarms: "\u2714",
    resume_network: "\u25B6",
    scale_flame_up: "\u2191",
    scale_flame_down: "\u2193",
    set_load_balancer: "\u2696"
  }
  def command_icon(cmd), do: Map.get(@command_icons, cmd, "?")

  @status_icons %{
    idle: "\u25CB",
    armed: "\u25CE",
    executing: "\u25CF",
    success: "\u2713",
    failed: "\u2717",
    cancelled: "\u2718"
  }
  def status_icon(status), do: Map.get(@status_icons, status, "?")

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(@refresh_interval, self(), :tick)
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "prajna:commands")
    end

    {:ok,
     socket
     |> assign(:page_title, "Command Center")
     |> assign(:armed_command, nil)
     |> assign(:arm_countdown, 0)
     |> assign(:selected_target, "app-01")
     |> assign(:targets, available_targets())
     |> assign(:command_history, [])
     |> assign(:confirmation_code, "")
     |> assign(:show_confirmation, false)
     |> assign(:command_icons, @command_icons)
     |> assign(:status_icons, @status_icons)
     |> assign(:critical_commands, @critical_commands)
     |> assign(:standard_commands, @standard_commands)
     |> assign(:scaling_commands, @scaling_commands)}
  end

  @impl true
  def handle_info(:tick, socket) do
    socket =
      if socket.assigns.armed_command do
        countdown = socket.assigns.arm_countdown - 1

        if countdown <= 0 do
          # Auto-cancel expired armed command
          cancel_armed_command(socket)
        else
          assign(socket, :arm_countdown, countdown)
        end
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:command_result, cmd_id, result}, socket) do
    history =
      Enum.map(socket.assigns.command_history, fn cmd ->
        if cmd.id == cmd_id, do: Map.put(cmd, :status, result), else: cmd
      end)

    {:noreply, assign(socket, :command_history, history)}
  end

  @impl true
  def handle_event("select_target", %{"target" => target}, socket) do
    {:noreply, assign(socket, :selected_target, target)}
  end

  @impl true
  def handle_event("arm_command", %{"command" => command}, socket) do
    cmd = String.to_existing_atom(command)

    if cmd in @critical_commands do
      # Two-step commit: arm first
      armed = %{
        id: generate_cmd_id(),
        target: socket.assigns.selected_target,
        command: cmd,
        armed_at: DateTime.utc_now(),
        armed_by: "operator@indrajaal.local"
      }

      {:noreply,
       socket
       |> assign(:armed_command, armed)
       |> assign(:arm_countdown, @arm_timeout_seconds)
       |> assign(:show_confirmation, true)
       |> assign(:confirmation_code, "")}
    else
      # Standard commands execute immediately
      execute_standard_command(socket, cmd)
    end
  end

  @impl true
  def handle_event("update_confirmation", %{"code" => code}, socket) do
    {:noreply, assign(socket, :confirmation_code, code)}
  end

  @impl true
  def handle_event("confirm_command", _params, socket) do
    case socket.assigns.armed_command do
      nil ->
        {:noreply, socket}

      armed ->
        # Verify confirmation code matches expected pattern
        expected_code = generate_expected_code(armed)

        if socket.assigns.confirmation_code == expected_code do
          # Execute the command
          history_entry = %{
            id: armed.id,
            target: armed.target,
            command: armed.command,
            status: :executing,
            executed_at: DateTime.utc_now(),
            duration: nil
          }

          # Simulate command execution
          Process.send_after(self(), {:command_result, armed.id, :success}, 2000)

          {:noreply,
           socket
           |> assign(:armed_command, nil)
           |> assign(:show_confirmation, false)
           |> assign(:confirmation_code, "")
           |> assign(:command_history, [history_entry | socket.assigns.command_history])
           |> put_flash(:info, "Command #{armed.command} executing on #{armed.target}")}
        else
          {:noreply, put_flash(socket, :error, "Invalid confirmation code")}
        end
    end
  end

  @impl true
  def handle_event("cancel_command", _params, socket) do
    {:noreply, cancel_armed_command(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- L4-A09: Theme-aware Commands page (SC-HMI-001, SC-HMI-008) --%>
    <div class="min-h-screen bg-surface-primary text-content-primary font-mono">
      <!-- Header Bar (COP) -->
      <header class="bg-surface-secondary border-b border-border-theme-primary px-4 py-2 flex items-center justify-between">
        <div class="flex items-center space-x-4">
          <a
            href="/cockpit"
            class="text-accent-primary font-bold text-lg hover:text-accent-primary/80"
          >
            PRAJNA C3I
          </a>
          <span class="text-content-muted">|</span>
          <span class="text-content-secondary">COMMAND CENTER</span>
          <%= if @armed_command do %>
            <span class="text-yellow-400 animate-pulse ml-4">
              COMMAND ARMED - {format_countdown(@arm_countdown)}
            </span>
          <% end %>
        </div>
        <div class="flex items-center space-x-4">
          <span class="text-content-secondary">
            {Calendar.strftime(DateTime.utc_now(), "%H:%M:%S")}
          </span>
        </div>
      </header>
      
    <!-- Navigation Tabs -->
      <nav class="bg-surface-secondary border-b border-border-theme-primary px-4">
        <div class="flex space-x-1">
          <%= for {view, label} <- [overview: "Overview", mesh: "Mesh", alarms: "Alarms", commands: "Commands", ai: "AI Copilot", containers: "Containers"] do %>
            <a
              href={"/cockpit" <> if(view == :overview, do: "", else: "/#{view}")}
              class={"px-4 py-2 text-sm font-medium transition-colors #{if view == :commands, do: "text-accent-primary border-b-2 border-accent-primary", else: "text-content-muted hover:text-content-primary"}"}
            >
              {String.upcase(label)}
            </a>
          <% end %>
        </div>
      </nav>
      
    <!-- Main Content -->
      <main class="p-4">
        <%= if @show_confirmation do %>
          <!-- Armed Command Confirmation Modal -->
          <div class="max-w-xl mx-auto">
            <div class="bg-surface-secondary border-2 border-yellow-500 rounded-lg p-6">
              <div class="flex items-center space-x-2 mb-4">
                <span class="text-yellow-500 text-2xl">{@status_icons.armed}</span>
                <h2 class="text-yellow-500 font-bold text-xl">COMMAND ARMED - CONFIRM EXECUTION</h2>
              </div>

              <div class="bg-surface-primary rounded p-4 mb-6 space-y-3">
                <div class="flex justify-between">
                  <span class="text-content-muted">Target:</span>
                  <span class="text-gray-200 font-bold">{@armed_command.target}</span>
                </div>
                <div class="flex justify-between">
                  <span class="text-content-muted">Command:</span>
                  <span class="text-yellow-400 font-bold">
                    {@command_icons[@armed_command.command]}
                    {String.upcase(to_string(@armed_command.command))}
                  </span>
                </div>
                <div class="flex justify-between">
                  <span class="text-content-muted">Armed by:</span>
                  <span class="text-content-secondary">{@armed_command.armed_by}</span>
                </div>
                <div class="flex justify-between">
                  <span class="text-content-muted">Armed at:</span>
                  <span class="text-content-secondary">
                    {Calendar.strftime(@armed_command.armed_at, "%H:%M:%S")}
                  </span>
                </div>
                <div class="flex justify-between">
                  <span class="text-content-muted">Expires in:</span>
                  <span class={if @arm_countdown < 30, do: "text-red-400", else: "text-yellow-400"}>
                    {format_countdown(@arm_countdown)}
                  </span>
                </div>
              </div>

              <div class="bg-yellow-900/30 border border-yellow-700 rounded p-4 mb-6">
                <p class="text-yellow-300 text-sm">
                  <strong>WARNING:</strong>
                  This is a CRITICAL command requiring two-step confirmation. {command_warning(
                    @armed_command.command
                  )}
                </p>
              </div>

              <div class="mb-6">
                <label class="block text-content-secondary text-sm mb-2">
                  Enter confirmation code:
                  <span class="text-yellow-400">{generate_expected_code(@armed_command)}</span>
                </label>
                <input
                  type="text"
                  phx-keyup="update_confirmation"
                  phx-value-code={@confirmation_code}
                  value={@confirmation_code}
                  class="w-full bg-surface-primary border border-border-theme-primary rounded px-4 py-2 text-gray-200 font-mono text-center text-lg tracking-widest"
                  placeholder="Enter code"
                  autofocus
                />
              </div>

              <div class="flex space-x-4">
                <button
                  phx-click="confirm_command"
                  disabled={@confirmation_code != generate_expected_code(@armed_command)}
                  class={"flex-1 px-4 py-3 font-bold rounded transition-colors #{if @confirmation_code == generate_expected_code(@armed_command), do: "bg-yellow-600 hover:bg-yellow-500 text-white", else: "bg-surface-tertiary text-content-muted cursor-not-allowed"}"}
                >
                  CONFIRM {String.upcase(to_string(@armed_command.command))}
                </button>
                <button
                  phx-click="cancel_command"
                  class="flex-1 px-4 py-3 bg-surface-tertiary hover:bg-gray-600 text-white rounded"
                >
                  Cancel
                </button>
              </div>
            </div>
          </div>
        <% else %>
          <!-- Command Selection Interface -->
          <div class="grid grid-cols-12 gap-4">
            <!-- Available Commands -->
            <div class="col-span-8 space-y-4">
              <!-- Target Selection -->
              <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
                <h3 class="text-sm font-bold text-content-secondary mb-3">SELECT TARGET</h3>
                <div class="flex flex-wrap gap-2">
                  <%= for target <- @targets do %>
                    <button
                      phx-click="select_target"
                      phx-value-target={target.id}
                      class={"px-4 py-2 rounded border transition-colors #{if @selected_target == target.id, do: "bg-blue-600 border-blue-500 text-white", else: "bg-surface-tertiary border-border-theme-secondary text-content-primary hover:bg-gray-600"}"}
                    >
                      {target.name}
                      <span class={target_status_class(target.status)}>
                        {target_status_icon(target.status)}
                      </span>
                    </button>
                  <% end %>
                </div>
              </div>
              
    <!-- Critical Commands (Two-Step) -->
              <div class="bg-surface-secondary rounded-lg border border-red-900 p-4">
                <h3 class="text-sm font-bold text-red-400 mb-3">
                  CRITICAL COMMANDS (Two-Step Required)
                </h3>
                <div class="grid grid-cols-3 gap-2">
                  <%= for cmd <- @critical_commands do %>
                    <button
                      phx-click="arm_command"
                      phx-value-command={cmd}
                      class="px-4 py-3 bg-red-900 hover:bg-red-800 text-red-300 rounded border border-red-700 flex items-center justify-center space-x-2"
                    >
                      <span>{@command_icons[cmd]}</span>
                      <span>{format_command_name(cmd)}</span>
                    </button>
                  <% end %>
                </div>
              </div>
              
    <!-- Standard Commands (Immediate) -->
              <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
                <h3 class="text-sm font-bold text-content-secondary mb-3">
                  STANDARD COMMANDS (Immediate)
                </h3>
                <div class="grid grid-cols-4 gap-2">
                  <%= for cmd <- @standard_commands do %>
                    <button
                      phx-click="arm_command"
                      phx-value-command={cmd}
                      class="px-4 py-2 bg-surface-tertiary hover:bg-gray-600 text-content-primary rounded border border-border-theme-secondary flex items-center justify-center space-x-2"
                    >
                      <span>{@command_icons[cmd]}</span>
                      <span>{format_command_name(cmd)}</span>
                    </button>
                  <% end %>
                </div>
              </div>
              
    <!-- Scaling Commands -->
              <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
                <h3 class="text-sm font-bold text-content-secondary mb-3">SCALING</h3>
                <div class="grid grid-cols-3 gap-2">
                  <%= for cmd <- @scaling_commands do %>
                    <button
                      phx-click="arm_command"
                      phx-value-command={cmd}
                      class="px-4 py-2 bg-blue-900 hover:bg-blue-800 text-blue-300 rounded border border-blue-700 flex items-center justify-center space-x-2"
                    >
                      <span>{@command_icons[cmd]}</span>
                      <span>{format_command_name(cmd)}</span>
                    </button>
                  <% end %>
                </div>
              </div>
            </div>
            
    <!-- Command History -->
            <div class="col-span-4 bg-surface-secondary rounded-lg border border-border-theme-primary">
              <div class="px-4 py-2 border-b border-border-theme-primary">
                <h3 class="text-sm font-bold text-content-secondary">COMMAND HISTORY (Last 10)</h3>
              </div>
              <div class="p-4 space-y-2 max-h-96 overflow-y-auto">
                <%= for cmd <- Enum.take(@command_history, 10) do %>
                  <div class="flex items-center justify-between text-xs p-2 bg-surface-primary rounded">
                    <div class="flex items-center space-x-2">
                      <span class={status_class(cmd.status)}>
                        {@status_icons[cmd.status]}
                      </span>
                      <span class="text-content-secondary">
                        {Calendar.strftime(cmd.executed_at, "%H:%M:%S")}
                      </span>
                    </div>
                    <div class="flex items-center space-x-2">
                      <span class="text-content-muted">{cmd.target}</span>
                      <span class="text-content-primary">{format_command_name(cmd.command)}</span>
                    </div>
                    <span class={status_class(cmd.status)}>
                      {String.upcase(to_string(cmd.status))}
                    </span>
                  </div>
                <% end %>
                <%= if @command_history == [] do %>
                  <div class="text-content-muted text-center py-8">No commands executed</div>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
      </main>
      
    <!-- Footer -->
      <footer class="fixed bottom-0 left-0 right-0 bg-surface-secondary border-t border-border-theme-primary px-4 py-2">
        <div class="flex items-center justify-between text-xs text-content-muted">
          <div class="flex space-x-4">
            <span>[A] Arm</span>
            <span>[C] Confirm</span>
            <span>[X] Cancel</span>
            <span>[Esc] Cancel</span>
          </div>
          <div>Two-Step Commit: MIL-STD-1472H Compliant | SC-HMI-004</div>
        </div>
      </footer>
    </div>
    """
  end

  # Private helpers

  defp available_targets do
    [
      %{id: "app-01", name: "app-01", status: :healthy, role: :supervisor},
      %{id: "app-02", name: "app-02", status: :healthy, role: :controller},
      %{id: "app-03", name: "app-03", status: :caution, role: :controller},
      %{id: "app-04", name: "app-04", status: :healthy, role: :controller},
      %{id: "app-05", name: "app-05", status: :healthy, role: :worker}
    ]
  end

  defp generate_cmd_id do
    random_num = :rand.uniform(999_999)
    "CMD-#{random_num |> Integer.to_string() |> String.pad_leading(6, "0")}"
  end

  defp generate_expected_code(%{target: target, command: command}) do
    # Simple confirmation code based on target and command
    first_letter = target |> String.first() |> String.upcase()
    cmd_num = command |> Atom.to_string() |> String.length() |> rem(10)
    "#{first_letter}#{cmd_num}"
  end

  defp format_countdown(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading(to_string(secs), 2, "0")}"
  end

  defp format_command_name(cmd) do
    cmd
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.upcase()
  end

  defp command_warning(:restart),
    do:
      "The node will be restarted, causing temporary unavailability. Active connections will be drained (30s timeout)."

  defp command_warning(:shutdown),
    do: "The node will be shut down completely and must be manually restarted."

  defp command_warning(:power_off),
    do: "The node will be powered off immediately. This may cause data loss."

  defp command_warning(:isolate),
    do: "The node will be isolated from the mesh. No traffic will be routed to it."

  defp command_warning(:hibernate),
    do: "The node will enter hibernation mode. State will be preserved."

  defp command_warning(:emergency_stop),
    do: "EMERGENCY STOP will halt all operations immediately. Use only in critical situations."

  defp command_warning(_), do: "This operation may affect system availability."

  defp cancel_armed_command(socket) do
    socket
    |> assign(:armed_command, nil)
    |> assign(:show_confirmation, false)
    |> assign(:confirmation_code, "")
    |> assign(:arm_countdown, 0)
  end

  defp execute_standard_command(socket, cmd) do
    history_entry = %{
      id: generate_cmd_id(),
      target: socket.assigns.selected_target,
      command: cmd,
      status: :success,
      executed_at: DateTime.utc_now(),
      duration: 1.2
    }

    {:noreply,
     socket
     |> assign(:command_history, [history_entry | socket.assigns.command_history])
     |> put_flash(:info, "#{format_command_name(cmd)} executed successfully")}
  end

  defp target_status_class(:healthy), do: "text-green-400"
  defp target_status_class(:caution), do: "text-yellow-400"
  defp target_status_class(:warning), do: "text-red-400"
  defp target_status_class(_), do: "text-content-secondary"

  defp target_status_icon(:healthy), do: "\u25CF"
  defp target_status_icon(:caution), do: "\u25CF"
  defp target_status_icon(:warning), do: "\u25CF"
  defp target_status_icon(_), do: "\u25CB"

  defp status_class(:success), do: "text-green-400"
  defp status_class(:failed), do: "text-red-400"
  defp status_class(:executing), do: "text-accent-primary animate-pulse"
  defp status_class(:cancelled), do: "text-content-muted"
  defp status_class(_), do: "text-content-secondary"
end
