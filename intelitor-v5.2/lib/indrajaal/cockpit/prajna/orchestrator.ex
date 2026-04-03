defmodule Indrajaal.Cockpit.Prajna.Orchestrator do
  @moduledoc """
  PRAJNA C3I Mesh Cockpit - Main Orchestrator

  WHAT: The main entry point and state machine for the PRAJNA cockpit system.
        Orchestrates Smart Metrics, AI Copilot, and Dark Cockpit UI.

  WHY: Provides a unified interface for safety-critical distributed control
       with AI-enhanced intelligence and human-in-the-loop design.

  USAGE:
  ```elixir
  {:ok, _} = Indrajaal.Cockpit.Prajna.Supervisor.start_link()
  Indrajaal.Cockpit.Prajna.Orchestrator.start_simulation()
  # System runs until stopped
  Indrajaal.Cockpit.Prajna.Orchestrator.stop()
  ```

  CONSTRAINTS:
    - SC-C3I-001: Data-centric architecture (Zenoh)
    - SC-C3I-002: Safety-critical HMI standards (NASA-STD-3000)
    - SC-C3I-003: AI advisory mode (human in the loop)
    - SC-C3I-004: Audit logging for all commands

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-27 |
  | Author | Cybernetic Architect |
  | STAMP | SC-C3I-001 to SC-C3I-004 |
  """

  use GenServer
  require Logger

  alias Indrajaal.Cockpit.Prajna.Domain
  alias Indrajaal.Cockpit.Prajna.SmartMetrics
  alias Indrajaal.Cockpit.Prajna.AiCopilot
  alias Indrajaal.Cockpit.Prajna.DarkCockpit
  alias Indrajaal.Cockpit.Prajna.GuardianIntegration

  @ui_refresh_interval 100
  @simulation_interval 50

  # ═══════════════════════════════════════════════════════════════════════════
  # CLIENT API
  # ═══════════════════════════════════════════════════════════════════════════

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Get current cockpit state"
  @spec state() :: Domain.cockpit_state()
  def state do
    GenServer.call(__MODULE__, :get_state)
  end

  @doc "Start the cockpit UI (renders to terminal)"
  @spec start_ui() :: :ok
  def start_ui do
    GenServer.cast(__MODULE__, :start_ui)
  end

  @doc "Stop the cockpit UI"
  @spec stop_ui() :: :ok
  def stop_ui do
    GenServer.cast(__MODULE__, :stop_ui)
  end

  @doc "Start simulation mode (generates fake telemetry)"
  @spec start_simulation() :: :ok
  def start_simulation do
    GenServer.cast(__MODULE__, :start_simulation)
  end

  @doc "Stop simulation mode"
  @spec stop_simulation() :: :ok
  def stop_simulation do
    GenServer.cast(__MODULE__, :stop_simulation)
  end

  @doc "Arm a command (two-step commit step 1)"
  @spec arm_command(String.t(), Domain.mesh_command()) :: {:ok, String.t()} | {:error, term()}
  def arm_command(node_id, command) do
    GenServer.call(__MODULE__, {:arm_command, node_id, command})
  end

  @doc "Confirm an armed command (two-step commit step 2)"
  @spec confirm_command(String.t()) :: :ok | {:error, term()}
  def confirm_command(command_id) do
    GenServer.call(__MODULE__, {:confirm_command, command_id})
  end

  @doc "Cancel an armed command"
  @spec cancel_command(String.t()) :: :ok
  def cancel_command(command_id) do
    GenServer.cast(__MODULE__, {:cancel_command, command_id})
  end

  @doc "Change view mode"
  @spec change_view(Domain.view_mode()) :: :ok
  def change_view(view) do
    GenServer.cast(__MODULE__, {:change_view, view})
  end

  @doc "Select a node for detail view"
  @spec select_node(String.t() | nil) :: :ok
  def select_node(node_id) do
    GenServer.cast(__MODULE__, {:select_node, node_id})
  end

  @doc "Record telemetry (from external source)"
  @spec record_telemetry(String.t(), map()) :: :ok
  def record_telemetry(key, payload) do
    GenServer.cast(__MODULE__, {:telemetry, key, payload})
  end

  @doc "Get audit log entries"
  @spec audit_log(integer()) :: list(String.t())
  def audit_log(limit \\ 100) do
    GenServer.call(__MODULE__, {:audit_log, limit})
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # GENSERVER CALLBACKS
  # ═══════════════════════════════════════════════════════════════════════════

  @impl GenServer
  def init(opts) do
    operator_id = Keyword.get(opts, :operator_id, "operator-1")
    state = Domain.create_cockpit_state(operator_id)

    audit("COCKPIT CREATED: Operator=#{operator_id}")

    Logger.info("[Prajna.Orchestrator] Initialized for operator: #{operator_id}")

    {:ok,
     %{
       cockpit: state,
       ui_running: false,
       simulation_running: false,
       spinner_frame: 0,
       audit_log: []
     }}
  end

  @impl GenServer
  def handle_call(:get_state, _from, state) do
    {:reply, state.cockpit, state}
  end

  @impl GenServer
  def handle_call({:arm_command, node_id, command}, _from, state) do
    if state.cockpit.monitor_only do
      {:reply, {:error, :monitor_only}, state}
    else
      cmd_id = generate_id()

      record = %{
        id: cmd_id,
        target_node_id: node_id,
        command: command,
        state: :armed,
        armed_at: DateTime.utc_now(),
        executed_at: nil,
        acknowledged_at: nil,
        error_message: nil,
        requires_confirmation: Domain.critical_command?(command)
      }

      audit("ARMED: #{cmd_id} -> #{inspect(command)} on #{node_id}")

      cockpit = %{
        state.cockpit
        | pending_commands: Map.put(state.cockpit.pending_commands, cmd_id, record)
      }

      {:reply, {:ok, cmd_id}, %{state | cockpit: cockpit}}
    end
  end

  @impl GenServer
  def handle_call({:confirm_command, cmd_id}, _from, state) do
    case Map.get(state.cockpit.pending_commands, cmd_id) do
      %{state: :armed} = record ->
        # 30.1.1.2 - Wire Orchestrator to Guardian
        case GuardianIntegration.submit_proposal(record.command) do
          {:ok, _validated_command} ->
            audit("CONFIRMED & GUARDED: #{cmd_id} executing #{inspect(record.command)}")

            updated_record = %{record | state: :executing, executed_at: DateTime.utc_now()}

            cockpit = %{
              state.cockpit
              | pending_commands: Map.put(state.cockpit.pending_commands, cmd_id, updated_record)
            }

            # Simulate command execution
            send(self(), {:command_result, cmd_id, :ok, nil})

            {:reply, :ok, %{state | cockpit: cockpit}}

          {:veto, reason, _fallback} ->
            audit("VETOED: #{cmd_id} by Guardian: #{inspect(reason)}")

            updated_record = %{
              record
              | state: :failed,
                executed_at: DateTime.utc_now(),
                error_message: "Guardian Veto: #{inspect(reason)}"
            }

            cockpit = %{
              state.cockpit
              | pending_commands: Map.put(state.cockpit.pending_commands, cmd_id, updated_record)
            }

            {:reply, {:error, :guardian_veto}, %{state | cockpit: cockpit}}
        end

      nil ->
        {:reply, {:error, :not_found}, state}

      _ ->
        {:reply, {:error, :invalid_state}, state}
    end
  end

  @impl GenServer
  def handle_call({:audit_log, limit}, _from, state) do
    {:reply, Enum.take(state.audit_log, limit), state}
  end

  @impl GenServer
  def handle_cast(:start_ui, state) do
    if not state.ui_running do
      schedule_ui_tick()
    end

    {:noreply, %{state | ui_running: true}}
  end

  @impl GenServer
  def handle_cast(:stop_ui, state) do
    # Show cursor
    IO.write("\e[?25h")
    {:noreply, %{state | ui_running: false}}
  end

  @impl GenServer
  def handle_cast(:start_simulation, state) do
    if not state.simulation_running do
      audit("SIMULATION STARTED")
      schedule_simulation_tick()
    end

    cockpit = %{state.cockpit | simulation_mode: true}
    {:noreply, %{state | cockpit: cockpit, simulation_running: true}}
  end

  @impl GenServer
  def handle_cast(:stop_simulation, state) do
    audit("SIMULATION STOPPED")
    cockpit = %{state.cockpit | simulation_mode: false}
    {:noreply, %{state | cockpit: cockpit, simulation_running: false}}
  end

  @impl GenServer
  def handle_cast({:cancel_command, cmd_id}, state) do
    audit("CANCELLED: #{cmd_id}")

    cockpit = %{
      state.cockpit
      | pending_commands: Map.delete(state.cockpit.pending_commands, cmd_id)
    }

    {:noreply, %{state | cockpit: cockpit}}
  end

  @impl GenServer
  def handle_cast({:change_view, view}, state) do
    cockpit = %{state.cockpit | current_view: view}
    {:noreply, %{state | cockpit: cockpit}}
  end

  @impl GenServer
  def handle_cast({:select_node, node_id}, state) do
    cockpit = %{state.cockpit | selected_node_id: node_id}
    {:noreply, %{state | cockpit: cockpit}}
  end

  @impl GenServer
  def handle_cast({:telemetry, key, payload}, state) do
    # Parse and record metrics
    Enum.each(payload, fn {metric_name, value} when is_number(value) ->
      metric_id = "#{key}.#{metric_name}"
      SmartMetrics.record(metric_id, to_string(metric_name), value, unit: "%")
    end)

    cockpit = %{
      state.cockpit
      | messages_received: state.cockpit.messages_received + 1,
        last_message_at: DateTime.utc_now()
    }

    {:noreply, %{state | cockpit: cockpit}}
  end

  @impl GenServer
  def handle_cast({:add_audit, entry}, state) do
    log = [entry | state.audit_log] |> Enum.take(1000)
    {:noreply, %{state | audit_log: log}}
  end

  @impl GenServer
  def handle_info(:ui_tick, state) do
    if state.ui_running do
      DarkCockpit.render(state.cockpit, state.spinner_frame)
      schedule_ui_tick()
    end

    {:noreply, %{state | spinner_frame: state.spinner_frame + 1}}
  end

  @impl GenServer
  def handle_info(:simulation_tick, state) do
    if state.simulation_running do
      simulate_telemetry()
      schedule_simulation_tick()
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:command_result, cmd_id, result, message}, state) do
    case Map.get(state.cockpit.pending_commands, cmd_id) do
      nil ->
        {:noreply, state}

      record ->
        final_state = if result == :ok, do: :acknowledged, else: :failed

        final_record = %{
          record
          | state: final_state,
            acknowledged_at: DateTime.utc_now(),
            error_message: message
        }

        audit("ACK: #{cmd_id} -> #{final_state}")

        pending = Map.delete(state.cockpit.pending_commands, cmd_id)
        history = [final_record | state.cockpit.command_history] |> Enum.take(100)

        cockpit = %{state.cockpit | pending_commands: pending, command_history: history}
        {:noreply, %{state | cockpit: cockpit}}
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PRIVATE HELPERS
  # ═══════════════════════════════════════════════════════════════════════════

  defp schedule_ui_tick do
    Process.send_after(self(), :ui_tick, @ui_refresh_interval)
  end

  defp schedule_simulation_tick do
    Process.send_after(self(), :simulation_tick, @simulation_interval + :rand.uniform(100))
  end

  defp simulate_telemetry do
    zones = ["zone-alpha", "zone-beta", "zone-gamma"]
    nodes = ["node-01", "node-02", "node-03", "node-04", "node-05"]

    zone = Enum.random(zones)
    node = Enum.random(nodes)

    # Generate random metrics with occasional spikes
    cpu = 20.0 + :rand.uniform() * 60.0 + if(:rand.uniform(10) == 1, do: 30.0, else: 0.0)
    memory = 30.0 + :rand.uniform() * 50.0
    latency = 10.0 + :rand.uniform() * 100.0

    SmartMetrics.record("#{zone}.#{node}.cpu", "CPU", cpu,
      unit: "%",
      thresholds: %{caution_high: 75.0, warning_high: 90.0}
    )

    SmartMetrics.record("#{zone}.#{node}.memory", "Memory", memory,
      unit: "%",
      thresholds: %{caution_high: 80.0, warning_high: 95.0}
    )

    SmartMetrics.record("#{zone}.#{node}.latency", "Latency", latency,
      unit: "ms",
      thresholds: %{caution_high: 500.0, warning_high: 1000.0}
    )

    # Occasionally trigger AI analysis
    if :rand.uniform(50) == 1 do
      AiCopilot.analyze_now()
    end
  end

  defp audit(message) do
    timestamp = DateTime.utc_now() |> DateTime.to_string()
    entry = "[#{timestamp}] #{message}"
    Logger.info("[Prajna.Audit] #{message}")
    GenServer.cast(self(), {:add_audit, entry})
  end

  defp generate_id do
    random_bytes = :crypto.strong_rand_bytes(4)
    Base.encode16(random_bytes, case: :lower)
  end
end
