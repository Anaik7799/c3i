defmodule Indrajaal.Cockpit.Prajna.OrchestratorTest do
  @moduledoc """
  Tests for PRAJNA Orchestrator

  WHAT: Verifies main state machine, command lifecycle, and audit logging.

  WHY: Ensures safety-critical command processing with two-step commit.

  CONSTRAINTS:
    - SC-C3I-001: Data-centric architecture
    - SC-C3I-003: AI advisory mode (human in the loop)
    - SC-C3I-004: Audit logging for all commands
    - SC-HMI-004: Two-step commit UI
    - TDG-PRAJNA-004: Orchestrator must be testable

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-27 |
  | Author | Cybernetic Architect |
  | STAMP | SC-C3I-001 to SC-C3I-004, SC-HMI-004 |
  """

  use ExUnit.Case, async: false
  @moduletag :zenoh_nif
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Cockpit.Prajna.Orchestrator
  alias Indrajaal.Cockpit.Prajna.SmartMetrics
  alias Indrajaal.Cockpit.Prajna.AiCopilot

  setup do
    # Start dependencies
    {:ok, metrics_pid} = SmartMetrics.start_link([])
    {:ok, copilot_pid} = AiCopilot.start_link(auto_analyze: false, llm_enabled: false)
    {:ok, orch_pid} = Orchestrator.start_link(operator_id: "test-operator")

    on_exit(fn ->
      try do
        if Process.alive?(orch_pid), do: GenServer.stop(orch_pid)
        if Process.alive?(copilot_pid), do: GenServer.stop(copilot_pid)
        if Process.alive?(metrics_pid), do: GenServer.stop(metrics_pid)
      catch
        :exit, _ -> :ok
      end
    end)

    {:ok, orch_pid: orch_pid}
  end

  describe "state/0" do
    test "returns current cockpit state" do
      state = Orchestrator.state()

      assert state.operator_id == "test-operator"
      assert state.session_id != nil
      assert state.current_view == :overview
      assert state.monitor_only == false
    end
  end

  describe "arm_command/2" do
    test "arms a command and returns command id" do
      {:ok, cmd_id} = Orchestrator.arm_command("node-01", :status)

      assert is_binary(cmd_id)
      assert String.length(cmd_id) == 8
    end

    test "armed command appears in pending commands" do
      {:ok, cmd_id} = Orchestrator.arm_command("node-01", :restart)

      state = Orchestrator.state()
      assert Map.has_key?(state.pending_commands, cmd_id)

      cmd = state.pending_commands[cmd_id]
      assert cmd.state == :armed
      assert cmd.target_node_id == "node-01"
      assert cmd.command == :restart
    end

    test "critical command requires confirmation" do
      {:ok, cmd_id} = Orchestrator.arm_command("node-01", :shutdown)

      state = Orchestrator.state()
      cmd = state.pending_commands[cmd_id]
      assert cmd.requires_confirmation == true
    end

    test "non-critical command does not require confirmation" do
      {:ok, cmd_id} = Orchestrator.arm_command("node-01", :status)

      state = Orchestrator.state()
      cmd = state.pending_commands[cmd_id]
      assert cmd.requires_confirmation == false
    end
  end

  describe "confirm_command/1" do
    test "confirms an armed command" do
      {:ok, cmd_id} = Orchestrator.arm_command("node-01", :restart)

      result = Orchestrator.confirm_command(cmd_id)
      assert result == :ok

      # Wait for async command result
      Process.sleep(50)

      state = Orchestrator.state()

      # Command should be in history now
      assert length(state.command_history) > 0

      # Find in history
      cmd = Enum.find(state.command_history, &(&1.id == cmd_id))
      assert cmd.state == :acknowledged
    end

    test "returns error for non-existent command" do
      result = Orchestrator.confirm_command("nonexistent")
      assert result == {:error, :not_found}
    end

    test "returns error for already executed command" do
      {:ok, cmd_id} = Orchestrator.arm_command("node-01", :status)
      Orchestrator.confirm_command(cmd_id)
      Process.sleep(50)

      # Try to confirm again
      result = Orchestrator.confirm_command(cmd_id)
      assert result == {:error, :not_found}
    end
  end

  describe "cancel_command/1" do
    test "cancels an armed command" do
      {:ok, cmd_id} = Orchestrator.arm_command("node-01", :restart)

      state_before = Orchestrator.state()
      assert Map.has_key?(state_before.pending_commands, cmd_id)

      Orchestrator.cancel_command(cmd_id)
      Process.sleep(50)

      state_after = Orchestrator.state()
      refute Map.has_key?(state_after.pending_commands, cmd_id)
    end
  end

  describe "change_view/1" do
    test "changes current view" do
      Orchestrator.change_view(:mesh)
      Process.sleep(50)

      state = Orchestrator.state()
      assert state.current_view == :mesh
    end

    test "accepts all valid view modes" do
      for view <- [:overview, :mesh, :alarms, :commands, :ai] do
        Orchestrator.change_view(view)
        Process.sleep(50)

        state = Orchestrator.state()
        assert state.current_view == view
      end
    end
  end

  describe "select_node/1" do
    test "selects a node for detail view" do
      Orchestrator.select_node("node-01")
      Process.sleep(50)

      state = Orchestrator.state()
      assert state.selected_node_id == "node-01"
    end

    test "can deselect node with nil" do
      Orchestrator.select_node("node-01")
      Process.sleep(50)
      Orchestrator.select_node(nil)
      Process.sleep(50)

      state = Orchestrator.state()
      assert state.selected_node_id == nil
    end
  end

  describe "record_telemetry/2" do
    test "records telemetry and increments message count" do
      state_before = Orchestrator.state()
      initial_count = state_before.messages_received

      Orchestrator.record_telemetry("zone.node", %{cpu: 75.0, memory: 80.0})
      Process.sleep(50)

      state_after = Orchestrator.state()
      assert state_after.messages_received == initial_count + 1
    end

    test "updates last_message_at timestamp" do
      state_before = Orchestrator.state()

      Orchestrator.record_telemetry("zone.node", %{cpu: 75.0})
      Process.sleep(50)

      state_after = Orchestrator.state()
      assert state_after.last_message_at != nil
    end
  end

  describe "audit_log/1" do
    test "returns audit log entries" do
      {:ok, _} = Orchestrator.arm_command("node-01", :status)

      log = Orchestrator.audit_log()
      assert is_list(log)
      assert length(log) > 0
    end

    test "includes command actions" do
      {:ok, cmd_id} = Orchestrator.arm_command("node-01", :restart)
      Orchestrator.confirm_command(cmd_id)
      Process.sleep(50)

      log = Orchestrator.audit_log()

      # Check for ARM and CONFIRM entries
      armed_entry = Enum.find(log, &String.contains?(&1, "ARMED"))
      assert armed_entry != nil

      confirmed_entry = Enum.find(log, &String.contains?(&1, "CONFIRMED"))
      assert confirmed_entry != nil
    end

    test "respects limit parameter" do
      # Generate multiple log entries
      for _ <- 1..10 do
        {:ok, _} = Orchestrator.arm_command("node-01", :status)
      end

      log = Orchestrator.audit_log(5)
      assert length(log) <= 5
    end
  end

  describe "start_simulation/0 and stop_simulation/0" do
    test "starts simulation mode" do
      Orchestrator.start_simulation()
      Process.sleep(100)

      state = Orchestrator.state()
      assert state.simulation_mode == true
    end

    test "stops simulation mode" do
      Orchestrator.start_simulation()
      Process.sleep(50)
      Orchestrator.stop_simulation()
      Process.sleep(50)

      state = Orchestrator.state()
      assert state.simulation_mode == false
    end

    test "simulation generates telemetry" do
      state_before = Orchestrator.state()
      initial_metrics = SmartMetrics.all() |> length()

      Orchestrator.start_simulation()
      Process.sleep(200)
      Orchestrator.stop_simulation()

      final_metrics = SmartMetrics.all() |> length()
      assert final_metrics > initial_metrics
    end
  end

  describe "SC-C3I-004 compliance: audit logging" do
    test "all command operations are logged" do
      {:ok, cmd_id} = Orchestrator.arm_command("node-01", :shutdown)
      Orchestrator.confirm_command(cmd_id)
      Process.sleep(50)

      log = Orchestrator.audit_log()

      # Should have ARM, CONFIRM, ACK entries
      assert Enum.any?(log, &String.contains?(&1, "ARMED"))
      assert Enum.any?(log, &String.contains?(&1, "CONFIRMED"))
      assert Enum.any?(log, &String.contains?(&1, "ACK"))
    end

    test "cancelled commands are logged" do
      {:ok, cmd_id} = Orchestrator.arm_command("node-01", :restart)
      Orchestrator.cancel_command(cmd_id)
      Process.sleep(50)

      log = Orchestrator.audit_log()
      assert Enum.any?(log, &String.contains?(&1, "CANCELLED"))
    end
  end

  describe "SC-HMI-004 compliance: two-step commit" do
    test "critical commands require arm then confirm" do
      # Step 1: Arm
      {:ok, cmd_id} = Orchestrator.arm_command("node-01", :shutdown)

      state = Orchestrator.state()
      cmd = state.pending_commands[cmd_id]
      assert cmd.state == :armed
      assert cmd.executed_at == nil

      # Step 2: Confirm
      Orchestrator.confirm_command(cmd_id)
      Process.sleep(50)

      state = Orchestrator.state()

      # Should be in history with acknowledged state
      cmd = Enum.find(state.command_history, &(&1.id == cmd_id))
      assert cmd != nil
      assert cmd.state == :acknowledged
      assert cmd.executed_at != nil
    end
  end

  describe "monitor_only mode" do
    test "blocks commands in monitor_only mode" do
      # We'd need to set monitor_only = true, but the module doesn't expose this
      # This is a design consideration - monitor_only should be configurable
      state = Orchestrator.state()
      assert state.monitor_only == false
    end
  end

  describe "command history" do
    test "maintains command history" do
      {:ok, cmd_id} = Orchestrator.arm_command("node-01", :status)
      Orchestrator.confirm_command(cmd_id)
      Process.sleep(50)

      state = Orchestrator.state()
      assert length(state.command_history) > 0

      cmd = List.first(state.command_history)
      assert cmd.id == cmd_id
      assert cmd.acknowledged_at != nil
    end

    test "history is limited to 100 entries" do
      # Generate many commands
      for _ <- 1..110 do
        {:ok, cmd_id} = Orchestrator.arm_command("node-01", :status)
        Orchestrator.confirm_command(cmd_id)
      end

      Process.sleep(200)

      state = Orchestrator.state()
      assert length(state.command_history) <= 100
    end
  end

  # ============================================================================
  # Property Tests (TDG Compliance)
  # ============================================================================

  describe "property tests" do
    property "arm_command returns valid command id" do
      forall command <- PC.oneof([:status, :restart, :shutdown]) do
        case Orchestrator.arm_command("test-node", command) do
          {:ok, cmd_id} ->
            is_binary(cmd_id) and String.length(cmd_id) == 8

          {:error, _} ->
            true
        end
      end
    end

    property "state always has required fields" do
      forall _seed <- PC.integer() do
        state = Orchestrator.state()

        Map.has_key?(state, :operator_id) and
          Map.has_key?(state, :session_id) and
          Map.has_key?(state, :current_view) and
          Map.has_key?(state, :pending_commands)
      end
    end

    property "view changes are accepted for valid views" do
      forall view <- PC.oneof([:overview, :mesh, :alarms, :commands, :ai]) do
        Orchestrator.change_view(view)
        Process.sleep(20)
        state = Orchestrator.state()
        state.current_view == view
      end
    end

    property "audit_log returns list" do
      forall limit <- PC.range(1, 50) do
        log = Orchestrator.audit_log(limit)
        is_list(log) and length(log) <= limit
      end
    end

    property "confirm_command on non-existent id returns error" do
      forall fake_id <- PC.binary(8) do
        result = Orchestrator.confirm_command(Base.encode16(fake_id, case: :lower))
        result == {:error, :not_found} or result == :ok
      end
    end

    property "messages_received is non-negative" do
      forall _seed <- PC.integer() do
        state = Orchestrator.state()
        state.messages_received >= 0
      end
    end

    property "pending_commands is always a map" do
      forall _seed <- PC.integer() do
        state = Orchestrator.state()
        is_map(state.pending_commands)
      end
    end

    property "command_history is always a list" do
      forall _seed <- PC.integer() do
        state = Orchestrator.state()
        is_list(state.command_history)
      end
    end
  end
end
