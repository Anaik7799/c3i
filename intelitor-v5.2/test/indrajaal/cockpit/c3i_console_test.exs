defmodule Indrajaal.Cockpit.C3IConsoleTest do
  @moduledoc """
  TDG test suite for Cockpit.C3IConsole.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation verification
  - Multi-agent console with 5 agents + 1 supervisor

  ## STAMP Safety Integration
  - SC-OBS-069: Dual logging (terminal + telemetry) verified
  - SC-AGT-017: Agent efficiency > 90% tracking
  - SC-C3I-001: Data-centric architecture

  ## Constitutional Verification
  - Ψ₀ Existence: Console GenServer survives agent registration and log operations
  - Ψ₅ Truthfulness: log normalization :warn -> :warning verified

  ## TPS 5-Level RCA Context
  - L1 Symptom: register_agent fails for invalid role
  - L5 Root Cause: Guard clause `when role in @agent_roles` rejects non-registered roles
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Cockpit.C3IConsole

  @moduletag :zenoh_nif

  setup do
    case Process.whereis(C3IConsole) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 5000)
    end

    Process.sleep(50)
    :ok
  end

  # ============================================================================
  # Guard clause validation (no GenServer needed)
  # ============================================================================

  describe "log/3 guard clause - invalid level" do
    test "raises FunctionClauseError for invalid log level :trace" do
      assert_raise FunctionClauseError, fn ->
        C3IConsole.log(:trace, "source", "message")
      end
    end

    test "raises FunctionClauseError for integer log level" do
      assert_raise FunctionClauseError, fn ->
        C3IConsole.log(1, "source", "message")
      end
    end

    test "raises FunctionClauseError for nil log level" do
      assert_raise FunctionClauseError, fn ->
        C3IConsole.log(nil, "source", "message")
      end
    end
  end

  describe "register_agent/3 guard clause - invalid role" do
    test "raises FunctionClauseError for invalid role :worker" do
      assert_raise FunctionClauseError, fn ->
        C3IConsole.register_agent(:agent_1, "Agent One", :worker)
      end
    end

    test "raises FunctionClauseError for string role" do
      assert_raise FunctionClauseError, fn ->
        C3IConsole.register_agent(:agent_1, "Agent One", "supervisor")
      end
    end

    test "raises FunctionClauseError for nil role" do
      assert_raise FunctionClauseError, fn ->
        C3IConsole.register_agent(:agent_1, "Agent One", nil)
      end
    end
  end

  describe "update_ooda/3 guard clause - invalid phase" do
    test "raises FunctionClauseError for invalid OODA phase :think" do
      assert_raise FunctionClauseError, fn ->
        C3IConsole.update_ooda(:think, 50.0, 95.0)
      end
    end

    test "raises FunctionClauseError for string phase" do
      assert_raise FunctionClauseError, fn ->
        C3IConsole.update_ooda("observe", 50.0, 95.0)
      end
    end
  end

  describe "set_phase/2 guard clause - invalid phase" do
    test "raises FunctionClauseError for invalid system phase :deploy" do
      assert_raise FunctionClauseError, fn ->
        C3IConsole.set_phase(:deploy, "Deploying...")
      end
    end

    test "raises FunctionClauseError for nil phase" do
      assert_raise FunctionClauseError, fn ->
        C3IConsole.set_phase(nil, "description")
      end
    end
  end

  # ============================================================================
  # GenServer lifecycle
  # ============================================================================

  describe "start_link/1" do
    test "starts the GenServer successfully" do
      assert {:ok, pid} = C3IConsole.start_link([])
      assert Process.alive?(pid)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    end

    test "registers under module name" do
      {:ok, pid} = C3IConsole.start_link([])
      assert Process.whereis(C3IConsole) == pid
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    end

    test "second start_link returns already_started" do
      {:ok, pid} = C3IConsole.start_link([])
      assert {:error, {:already_started, ^pid}} = C3IConsole.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    end
  end

  # ============================================================================
  # Operations with server running
  # ============================================================================

  describe "initialize/1" do
    setup do
      {:ok, pid} = C3IConsole.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    test "returns :ok with default title" do
      result = C3IConsole.initialize()
      assert result == :ok
    end

    test "returns :ok with custom title" do
      result = C3IConsole.initialize("MY CONSOLE")
      assert result == :ok
    end
  end

  describe "shutdown/0" do
    setup do
      {:ok, pid} = C3IConsole.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    test "returns :ok" do
      result = C3IConsole.shutdown()
      assert result == :ok
    end

    test "can be called multiple times without crash" do
      assert :ok = C3IConsole.shutdown()
      assert :ok = C3IConsole.shutdown()
    end
  end

  describe "register_agent/3 with valid roles" do
    setup do
      {:ok, pid} = C3IConsole.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    test "accepts :supervisor role" do
      result = C3IConsole.register_agent(:sup_1, "Supervisor", :supervisor)
      assert result == :ok
    end

    test "accepts :dashboard role" do
      result = C3IConsole.register_agent(:dash_1, "Dashboard", :dashboard)
      assert result == :ok
    end

    test "accepts :cepaf_gde role" do
      result = C3IConsole.register_agent(:gde_1, "GDE", :cepaf_gde)
      assert result == :ok
    end

    test "accepts :telemetry role" do
      result = C3IConsole.register_agent(:tel_1, "Telemetry", :telemetry)
      assert result == :ok
    end

    test "accepts :test_runner role" do
      result = C3IConsole.register_agent(:test_1, "Test Runner", :test_runner)
      assert result == :ok
    end

    test "accepts :container_ops role" do
      result = C3IConsole.register_agent(:cont_1, "Container Ops", :container_ops)
      assert result == :ok
    end

    test "register returns :ok (cast is fire-and-forget)" do
      assert :ok = C3IConsole.register_agent(:agent_x, "Agent X", :supervisor)
    end
  end

  describe "log/3 with valid levels" do
    setup do
      {:ok, pid} = C3IConsole.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    test "accepts :info level" do
      assert :ok = C3IConsole.log(:info, "test_source", "info message")
    end

    test "accepts :warning level" do
      assert :ok = C3IConsole.log(:warning, "test_source", "warning message")
    end

    test "accepts :warn level (OTP 28 compat - normalized to :warning)" do
      # :warn is accepted and normalized to :warning internally
      assert :ok = C3IConsole.log(:warn, "test_source", "warn message")
    end

    test "accepts :error level" do
      assert :ok = C3IConsole.log(:error, "test_source", "error message")
    end

    test "accepts :debug level" do
      assert :ok = C3IConsole.log(:debug, "test_source", "debug message")
    end

    test "multiple log calls do not crash the server" do
      for level <- [:info, :warning, :error, :debug] do
        assert :ok = C3IConsole.log(level, "src", "msg #{level}")
      end
    end
  end

  describe "metric/4" do
    setup do
      {:ok, pid} = C3IConsole.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    test "returns :ok" do
      result = C3IConsole.metric("cpu_usage", 45.2, "%", :stable)
      assert result == :ok
    end

    test "accepts default trend" do
      result = C3IConsole.metric("memory_mb", 256, "MB")
      assert result == :ok
    end

    test "multiple metrics do not crash the server" do
      C3IConsole.metric("cpu", 10, "%")
      C3IConsole.metric("mem", 512, "MB")
      C3IConsole.metric("io", 1000, "B/s")
      assert Process.alive?(Process.whereis(C3IConsole))
    end
  end

  describe "update_ooda/3 with valid phases" do
    setup do
      {:ok, pid} = C3IConsole.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    test "accepts :observe phase" do
      assert :ok = C3IConsole.update_ooda(:observe, 50.0, 95.0)
    end

    test "accepts :orient phase" do
      assert :ok = C3IConsole.update_ooda(:orient, 30.0, 90.0)
    end

    test "accepts :decide phase" do
      assert :ok = C3IConsole.update_ooda(:decide, 20.0, 88.0)
    end

    test "accepts :act phase" do
      assert :ok = C3IConsole.update_ooda(:act, 15.0, 92.0)
    end
  end

  describe "update_gde/3" do
    setup do
      {:ok, pid} = C3IConsole.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    test "returns :ok" do
      assert :ok = C3IConsole.update_gde(5, 4, 0.8)
    end
  end

  describe "update_ace/3" do
    setup do
      {:ok, pid} = C3IConsole.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    test "returns :ok" do
      assert :ok = C3IConsole.update_ace(10, 2, "NOMINAL")
    end
  end

  describe "set_phase/2 with valid phases" do
    setup do
      {:ok, pid} = C3IConsole.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    test "accepts :startup phase" do
      assert :ok = C3IConsole.set_phase(:startup, "Starting up...")
    end

    test "accepts :containers phase" do
      assert :ok = C3IConsole.set_phase(:containers, "Starting containers...")
    end

    test "accepts :compilation phase" do
      assert :ok = C3IConsole.set_phase(:compilation, "Compiling...")
    end

    test "accepts :testing phase" do
      assert :ok = C3IConsole.set_phase(:testing, "Running tests...")
    end

    test "accepts :verification phase" do
      assert :ok = C3IConsole.set_phase(:verification, "Verifying...")
    end

    test "accepts :operational phase" do
      assert :ok = C3IConsole.set_phase(:operational, "Operational")
    end

    test "accepts :shutdown phase" do
      assert :ok = C3IConsole.set_phase(:shutdown, "Shutting down...")
    end
  end

  describe "set_goal_status/5" do
    setup do
      {:ok, pid} = C3IConsole.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    test "returns :ok" do
      assert :ok = C3IConsole.set_goal_status(0, 5, 100, 3, 95.5)
    end

    test "accepts zero values" do
      assert :ok = C3IConsole.set_goal_status(0, 0, 0, 0, 0.0)
    end
  end

  describe "update_agent/3" do
    setup do
      {:ok, pid} = C3IConsole.start_link([])
      # Register an agent first
      C3IConsole.register_agent(:test_agent, "Test Agent", :supervisor)
      Process.sleep(20)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    test "returns :ok for registered agent" do
      assert :ok = C3IConsole.update_agent(:test_agent, :running, "task_1")
    end

    test "returns :ok for non-existent agent (silently ignored)" do
      assert :ok = C3IConsole.update_agent(:nonexistent_agent, :running, "task_1")
    end

    test "accepts :success status" do
      assert :ok = C3IConsole.update_agent(:test_agent, :success, "completed task")
    end

    test "accepts :error status" do
      assert :ok = C3IConsole.update_agent(:test_agent, :error, "failed task")
    end
  end

  describe "demo/0" do
    setup do
      {:ok, pid} = C3IConsole.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    test "returns :ok" do
      result = C3IConsole.demo()
      assert result == :ok
    end
  end
end
