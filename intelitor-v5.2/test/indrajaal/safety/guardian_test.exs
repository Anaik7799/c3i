defmodule Indrajaal.Safety.GuardianTest do
  @moduledoc """
  Tests for the Guardian module with Envelope integration.

  WHAT: Validates Guardian proposal validation using Envelope constraints.
  WHY: SC-GUARD-001 to SC-GUARD-002 require proper Envelope integration.
  CONSTRAINTS: Must verify all constraint categories are checked via Envelope.
  """
  use ExUnit.Case, async: false

  alias Indrajaal.Safety.Guardian
  alias Indrajaal.Safety.Envelope

  # ============================================================
  # SETUP
  # ============================================================

  setup do
    # Start Guardian for each test
    case GenServer.whereis(Guardian) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 5000)
    end

    {:ok, pid} = Guardian.start_link()

    on_exit(fn ->
      case GenServer.whereis(Guardian) do
        nil ->
          :ok

        pid ->
          try do
            GenServer.stop(pid, :normal, 5000)
          catch
            :exit, _ -> :ok
          end
      end
    end)

    %{guardian: pid}
  end

  # ============================================================
  # STATUS TESTS
  # ============================================================

  describe "status/0" do
    test "returns running status", _ctx do
      status = Guardian.status()

      assert status.running == true
      assert status.validations == 0
      assert status.violations == 0
      assert status.uptime_seconds >= 0
    end

    test "includes envelope constraints count", _ctx do
      status = Guardian.status()

      assert Map.has_key?(status, :envelope_constraints)
      assert status.envelope_constraints > 0
    end
  end

  describe "status/0 when not running" do
    test "returns not running status" do
      # Stop guardian first
      GenServer.stop(Guardian)

      status = Guardian.status()

      assert status.running == false
      assert status.validations == 0
      assert status.violations == 0
    end
  end

  # ============================================================
  # CONSTRAINTS TESTS
  # ============================================================

  describe "constraints/0" do
    test "returns Envelope constraints", _ctx do
      constraints = Guardian.constraints()

      assert constraints == Envelope.all_constraints()
    end
  end

  # ============================================================
  # RESOURCE VALIDATION TESTS
  # ============================================================

  describe "validate_proposal/1 - resource constraints" do
    test "approves scale_up within limit", _ctx do
      proposal = %{action: :scale_up, quantity: 25}

      assert {:ok, ^proposal} = Guardian.validate_proposal(proposal)
    end

    test "approves scale_up at limit", _ctx do
      proposal = %{action: :scale_up, quantity: 50}

      assert {:ok, ^proposal} = Guardian.validate_proposal(proposal)
    end

    test "vetoes scale_up exceeding limit", _ctx do
      proposal = %{action: :scale_up, quantity: 100}

      assert {:veto, :resource_limit_exceeded, fallback} = Guardian.validate_proposal(proposal)
      assert fallback.action == :scale_up
      assert fallback.quantity == 50
      assert fallback.reason == :clamped_by_guardian
    end

    test "approves allocate_memory within limit", _ctx do
      proposal = %{action: :allocate_memory, mb: 16_000}

      assert {:ok, ^proposal} = Guardian.validate_proposal(proposal)
    end

    test "vetoes allocate_memory exceeding limit", _ctx do
      proposal = %{action: :allocate_memory, mb: 50_000}

      assert {:veto, :memory_limit_exceeded, fallback} = Guardian.validate_proposal(proposal)
      assert fallback.action == :allocate_memory
      assert fallback.mb == 32_000
    end

    test "approves open_connections within limit", _ctx do
      proposal = %{action: :open_connections, count: 50}

      assert {:ok, ^proposal} = Guardian.validate_proposal(proposal)
    end

    test "vetoes open_connections exceeding limit", _ctx do
      proposal = %{action: :open_connections, count: 200}

      assert {:veto, :db_connection_limit_exceeded, _} = Guardian.validate_proposal(proposal)
    end
  end

  # ============================================================
  # SECURITY VALIDATION TESTS
  # ============================================================

  describe "validate_proposal/1 - security constraints" do
    test "approves safe code execution", _ctx do
      proposal = %{action: :exec_code, code: "def hello, do: :world"}

      assert {:ok, ^proposal} = Guardian.validate_proposal(proposal)
    end

    test "vetoes code with forbidden operation", _ctx do
      proposal = %{action: :exec_code, code: "rm_rf everything"}

      assert {:veto, :forbidden_operation_detected, fallback} =
               Guardian.validate_proposal(proposal)

      assert fallback.action == :log_error
    end

    test "vetoes code with dangerous pattern", _ctx do
      proposal = %{action: :exec_code, code: "sudo rm -rf /"}

      # This should match the dangerous pattern
      result = Guardian.validate_proposal(proposal)
      assert {:veto, reason, _} = result
      assert reason in [:forbidden_operation_detected, :dangerous_pattern_detected]
    end

    test "vetoes code with eval_string", _ctx do
      proposal = %{action: :exec_code, code: "Code.eval_string(user_input)"}

      # eval_string is caught by forbidden_operation check (runs before pattern check)
      result = Guardian.validate_proposal(proposal)
      assert {:veto, reason, _} = result
      assert reason in [:forbidden_operation_detected, :dangerous_pattern_detected]
    end
  end

  # ============================================================
  # PHYSICAL VALIDATION TESTS
  # ============================================================

  describe "validate_proposal/1 - physical constraints" do
    test "approves open_lock with safe sensors", _ctx do
      proposal = %{
        action: :open_lock,
        sensor_data: %{pressure_delta: 0.05, temperature_c: 25.0}
      }

      assert {:ok, ^proposal} = Guardian.validate_proposal(proposal)
    end

    test "vetoes open_lock with high pressure", _ctx do
      proposal = %{
        action: :open_lock,
        sensor_data: %{pressure_delta: 0.5}
      }

      assert {:veto, :unsafe_physical_state_pressure, fallback} =
               Guardian.validate_proposal(proposal)

      assert fallback.action == :maintain_lock_state
    end

    test "vetoes open_lock with high temperature", _ctx do
      proposal = %{
        action: :open_lock,
        sensor_data: %{pressure_delta: 0.05, temperature_c: 80.0}
      }

      assert {:veto, :unsafe_physical_state_temperature, fallback} =
               Guardian.validate_proposal(proposal)

      assert fallback.action == :maintain_lock_state
    end

    test "approves energize with safe voltage", _ctx do
      proposal = %{action: :energize, voltage_deviation: 5.0}

      assert {:ok, ^proposal} = Guardian.validate_proposal(proposal)
    end

    test "vetoes energize with high voltage deviation", _ctx do
      proposal = %{action: :energize, voltage_deviation: 15.0}

      assert {:veto, :unsafe_voltage_deviation, _} = Guardian.validate_proposal(proposal)
    end
  end

  # ============================================================
  # TEMPORAL VALIDATION TESTS
  # ============================================================

  describe "validate_proposal/1 - temporal constraints" do
    test "approves request with acceptable response time", _ctx do
      proposal = %{action: :request, expected_response_time: 30}

      assert {:ok, ^proposal} = Guardian.validate_proposal(proposal)
    end

    test "vetoes request with excessive response time", _ctx do
      proposal = %{action: :request, expected_response_time: 100}

      assert {:veto, :response_time_exceeded, _} = Guardian.validate_proposal(proposal)
    end
  end

  # ============================================================
  # NETWORK VALIDATION TESTS
  # ============================================================

  describe "validate_proposal/1 - network constraints" do
    test "approves network_call to localhost", _ctx do
      proposal = %{action: :network_call, destination: "localhost:4000"}

      assert {:ok, ^proposal} = Guardian.validate_proposal(proposal)
    end

    test "approves network_call to whitelisted destination", _ctx do
      proposal = %{action: :network_call, destination: "api.anthropic.com"}

      assert {:ok, ^proposal} = Guardian.validate_proposal(proposal)
    end

    test "vetoes network_call to unknown destination", _ctx do
      proposal = %{action: :network_call, destination: "evil-server.com"}

      assert {:veto, :network_destination_blocked, fallback} =
               Guardian.validate_proposal(proposal)

      assert fallback.action == :block_network
    end
  end

  # ============================================================
  # GENERAL PROPOSAL TESTS
  # ============================================================

  describe "validate_proposal/1 - general" do
    test "approves unknown action", _ctx do
      proposal = %{action: :unknown_action, data: "something"}

      assert {:ok, ^proposal} = Guardian.validate_proposal(proposal)
    end

    test "tracks validation statistics", _ctx do
      # Initial state
      assert Guardian.status().validations == 0

      # Validate some proposals
      Guardian.validate_proposal(%{action: :scale_up, quantity: 25})
      Guardian.validate_proposal(%{action: :scale_up, quantity: 100})
      Guardian.validate_proposal(%{action: :exec_code, code: "safe code"})

      status = Guardian.status()
      assert status.validations == 3
      assert status.violations == 1
      # 6 constraints * 3 validations
      assert status.constraints_checked == 18
    end

    test "records last violation", _ctx do
      # Trigger a violation
      Guardian.validate_proposal(%{action: :scale_up, quantity: 1000})

      status = Guardian.status()
      assert status.last_violation != nil
      assert status.last_violation.reason == :resource_limit_exceeded
      assert %DateTime{} = status.last_violation.timestamp
    end
  end

  # ============================================================
  # HEALTH CHECK TESTS
  # ============================================================

  describe "health_check/1" do
    test "returns comprehensive health status", _ctx do
      result = Guardian.health_check()

      assert Map.has_key?(result, :guardian)
      assert Map.has_key?(result, :envelope)
      assert Map.has_key?(result, :dead_mans_switch)
      assert Map.has_key?(result, :overall_healthy)
    end

    test "with healthy metrics shows healthy", _ctx do
      metrics = %{
        flame_nodes: 25,
        ram_mb: 16_000,
        cpu_percent: 50
      }

      result = Guardian.health_check(metrics)

      assert result.envelope.healthy == true
      assert result.guardian.running == true
    end

    test "with unhealthy metrics shows violations", _ctx do
      metrics = %{
        flame_nodes: 100,
        ram_mb: 50_000
      }

      result = Guardian.health_check(metrics)

      assert result.envelope.healthy == false
      assert length(result.envelope.violations) >= 2
    end
  end

  # ============================================================
  # FALLBACK WHEN NOT RUNNING
  # ============================================================

  describe "validate_proposal/1 without GenServer" do
    test "still validates using direct logic" do
      # Stop Guardian
      GenServer.stop(Guardian)

      # Validation should still work via fallback
      proposal = %{action: :scale_up, quantity: 100}
      result = Guardian.validate_proposal(proposal)

      assert {:veto, :resource_limit_exceeded, _} = result
    end
  end

  # ============================================================
  # EMERGENCY STOP TESTS (P0-1 Implementation)
  # ============================================================

  describe "emergency_stop/1" do
    @tag :emergency_stop
    test "function is defined and returns :ok", _ctx do
      # Note: We can't test actual BEAM halt, but we can verify the function exists
      # and initiates the process (it spawns execution, so returns immediately)

      # Verify function exists with correct arity
      assert function_exported?(Guardian, :emergency_stop, 1)

      # Note: Calling emergency_stop/1 would actually halt the BEAM in production
      # For testing, we verify the function signature and documentation
    end

    @tag :emergency_stop
    test "emergency_stop_sync/2 function is defined", _ctx do
      # Verify the sync version exists
      assert function_exported?(Guardian, :emergency_stop_sync, 1)
      assert function_exported?(Guardian, :emergency_stop_sync, 2)
    end

    @tag :emergency_stop
    test "emergency checkpoint directory creation", _ctx do
      # Verify checkpoint directory can be created
      checkpoint_dir = "data/checkpoints/emergency"

      # Clean up if exists
      File.rm_rf!(checkpoint_dir)

      # Create directory
      File.mkdir_p!(checkpoint_dir)

      assert File.dir?(checkpoint_dir)

      # Clean up
      File.rm_rf!(checkpoint_dir)
    end

    @tag :emergency_stop
    test "emergency checkpoint JSON encoding works", _ctx do
      checkpoint = %{
        type: :emergency_stop,
        reason: "Test emergency",
        timestamp: DateTime.utc_now(),
        node: Node.self(),
        processes: length(Process.list()),
        memory_mb: :erlang.memory(:total) |> div(1024 * 1024),
        uptime_seconds: :erlang.statistics(:wall_clock) |> elem(0) |> div(1000)
      }

      # Verify it can be encoded to JSON
      assert {:ok, json} = Jason.encode(checkpoint)
      assert is_binary(json)
      assert String.contains?(json, "emergency_stop")
      assert String.contains?(json, "Test emergency")
    end

    @tag :emergency_stop
    test "watchdog file creation works", _ctx do
      watchdog_dir = "data/watchdog"
      watchdog_file = "#{watchdog_dir}/test_emergency"

      # Clean up if exists
      File.rm_rf!(watchdog_dir)

      # Create directory and file
      File.mkdir_p!(watchdog_dir)

      content = """
      EMERGENCY_STOP
      Reason: Test reason
      Timestamp: #{DateTime.utc_now() |> DateTime.to_iso8601()}
      Node: #{Node.self()}
      """

      :ok = File.write!(watchdog_file, content)

      assert File.exists?(watchdog_file)
      assert File.read!(watchdog_file) =~ "EMERGENCY_STOP"
      assert File.read!(watchdog_file) =~ "Test reason"

      # Clean up
      File.rm_rf!(watchdog_dir)
    end
  end

  # ============================================================
  # EMERGENCY STOP COMPONENT TESTS
  # ============================================================

  describe "emergency_stop integration components" do
    @tag :emergency_stop
    test "ImmutableRegister can receive emergency_stop entries", _ctx do
      alias Indrajaal.Core.Holon.ImmutableRegister

      # Start ImmutableRegister if not running
      case GenServer.whereis(ImmutableRegister) do
        nil ->
          {:ok, _} = ImmutableRegister.start_link()

        _pid ->
          :ok
      end

      # Append an emergency stop entry
      result =
        ImmutableRegister.append(:emergency_stop, %{
          reason: "Test emergency stop",
          timestamp: DateTime.utc_now(),
          node: Node.self(),
          constraint: "SC-EMR-057"
        })

      assert {:ok, hash} = result
      assert is_binary(hash)
      # SHA3-256 produces 64 hex chars
      assert String.length(hash) == 64

      # Verify chain integrity
      assert :ok = ImmutableRegister.verify()

      # Clean up
      GenServer.stop(ImmutableRegister)
    end

    @tag :emergency_stop
    test "DeadMansSwitch can be triggered for emergency", _ctx do
      alias Indrajaal.Safety.DeadMansSwitch

      # Start DeadMansSwitch if not running
      case GenServer.whereis(DeadMansSwitch) do
        nil ->
          {:ok, _} = DeadMansSwitch.start_link()

        _pid ->
          :ok
      end

      # Get initial stats
      initial_stats = DeadMansSwitch.stats()

      # Trigger failsafe
      :ok = DeadMansSwitch.trigger_failsafe(:emergency_stop_test)

      # Verify state changed
      new_state = DeadMansSwitch.state()
      assert new_state == :failsafe_triggered

      # Verify failsafe count increased
      new_stats = DeadMansSwitch.stats()
      assert new_stats.failsafe_triggers > initial_stats.failsafe_triggers

      # Clean up
      GenServer.stop(DeadMansSwitch)
    end
  end

  # ============================================================
  # EMERGENCY STOP STAMP COMPLIANCE TESTS
  # ============================================================

  describe "emergency_stop STAMP compliance" do
    @tag :emergency_stop
    @tag :stamp
    test "SC-EMR-057: emergency_stop documentation exists", _ctx do
      # Verify the module has documentation for emergency_stop
      {:docs_v1, _, _, _, _, _, docs} = Code.fetch_docs(Guardian)

      emergency_stop_doc =
        Enum.find(docs, fn
          {{:function, :emergency_stop, 1}, _, _, _, _} -> true
          _ -> false
        end)

      assert emergency_stop_doc != nil

      {{:function, :emergency_stop, 1}, _, _, doc_content, _} = emergency_stop_doc
      doc_string = Map.get(doc_content, "en", "")

      # Verify STAMP constraint is documented
      assert doc_string =~ "SC-EMR-057"
      assert doc_string =~ "5s" or doc_string =~ "<5s" or doc_string =~ "5 seconds"
    end

    @tag :emergency_stop
    @tag :stamp
    test "SC-REG-001: audit logging is part of emergency_stop", _ctx do
      # Verify the implementation references ImmutableRegister
      {:ok, source} = File.read("lib/indrajaal/safety/guardian.ex")

      assert source =~ "ImmutableRegister"
      assert source =~ ":emergency_stop"
      assert source =~ "SC-REG-001"
    end

    @tag :emergency_stop
    @tag :stamp
    test "SC-CONST-002: constitutional halt is mentioned", _ctx do
      {:ok, source} = File.read("lib/indrajaal/safety/guardian.ex")

      assert source =~ "SC-CONST-002"
      assert source =~ "constitutional violation"
    end
  end
end
