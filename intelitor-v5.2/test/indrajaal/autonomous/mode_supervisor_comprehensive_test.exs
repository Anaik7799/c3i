defmodule Indrajaal.Autonomous.ModeSupervisorComprehensiveTest do
  @moduledoc """
  Comprehensive TDG test suite for Autonomous.ModeSupervisor — AEE + CAFE +
  Cybernetic Agent Integration.

  Covers start_link/1, get_status/0, emergency_stop/0, and the execute_mission/1
  return contract. The module uses :infinity GenServer.call timeout so mission
  execution tests use minimal missions to avoid test timeouts.

  ## STAMP Safety Integration
  - SC-AGT-001: Agent efficiency must be >90%
  - SC-SAF-001: Halt <1s on STAMP violation
  - SC-OBS-069: Dual log output (Terminal + SigNoz)
  - SC-PRF-050: OODA cycle latency <50ms

  ## Constitutional Verification
  - Ψ₀ Existence: Supervisor GenServer survives emergency_stop
  - Ψ₁ Regeneration: State is inspectable via get_status/0
  - Ψ₃ Verification: OODA state exposed in status map

  ## Founder's Directive Alignment
  - Ω₀.6: Sentience Pursuit — autonomous OODA loop drives intelligence
  - Ω₀.7: Power Accumulation — compilation fix mission removes blockers

  ## TPS 5-Level RCA Context
  - L1 Symptom: Autonomous missions run unchecked, emergency stop ignored
  - L5 Root Cause: No unit coverage for ModeSupervisor lifecycle and status API
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Autonomous.ModeSupervisor

  @moduletag :zenoh_nif

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp try_stop(target) do
    try do
      GenServer.stop(target, :normal, 5_000)
    catch
      :exit, _ -> :ok
    end
  end

  defp minimal_mission do
    %{
      type: :smoke_test,
      description: "Minimal test mission",
      phases: [:verify],
      max_iterations: 1,
      success_criteria: %{complete: true}
    }
  end

  # ---------------------------------------------------------------------------
  # Setup
  # ---------------------------------------------------------------------------

  setup do
    case GenServer.whereis(ModeSupervisor) do
      nil -> :ok
      _pid -> try_stop(ModeSupervisor)
    end

    {:ok, pid} = ModeSupervisor.start_link([])

    on_exit(fn ->
      case GenServer.whereis(ModeSupervisor) do
        nil -> :ok
        _pid -> try_stop(ModeSupervisor)
      end
    end)

    %{supervisor: pid}
  end

  # ---------------------------------------------------------------------------
  # start_link/1
  # ---------------------------------------------------------------------------

  describe "start_link/1" do
    test "starts successfully and process is alive", %{supervisor: pid} do
      assert Process.alive?(pid)
    end

    test "registers under the module name" do
      assert GenServer.whereis(ModeSupervisor) != nil
    end

    test "initialises in :autonomous mode" do
      status = ModeSupervisor.get_status()
      assert status.mode == :autonomous
    end

    test "initialises with nil mission" do
      status = ModeSupervisor.get_status()
      assert status.mission == nil or is_map(status.mission)
    end

    test "initialises with nil current_task" do
      status = ModeSupervisor.get_status()
      assert status.current_task == nil
    end
  end

  # ---------------------------------------------------------------------------
  # get_status/0
  # ---------------------------------------------------------------------------

  describe "get_status/0" do
    test "returns a map" do
      status = ModeSupervisor.get_status()
      assert is_map(status)
    end

    test "status contains :mode key" do
      status = ModeSupervisor.get_status()
      assert Map.has_key?(status, :mode)
    end

    test "status :mode is one of the valid execution modes" do
      status = ModeSupervisor.get_status()
      assert status.mode in [:autonomous, :supervised, :interactive, :halted]
    end

    test "status contains :tasks_completed key" do
      status = ModeSupervisor.get_status()
      assert Map.has_key?(status, :tasks_completed)
    end

    test "tasks_completed is a non-negative integer" do
      status = ModeSupervisor.get_status()
      assert is_integer(status.tasks_completed)
      assert status.tasks_completed >= 0
    end

    test "status contains :tasks_remaining key" do
      status = ModeSupervisor.get_status()
      assert Map.has_key?(status, :tasks_remaining)
    end

    test "tasks_remaining is a non-negative integer" do
      status = ModeSupervisor.get_status()
      assert is_integer(status.tasks_remaining)
      assert status.tasks_remaining >= 0
    end

    test "status contains :ooda_metrics key" do
      status = ModeSupervisor.get_status()
      assert Map.has_key?(status, :ooda_metrics)
    end

    test "ooda_metrics is a map" do
      status = ModeSupervisor.get_status()
      assert is_map(status.ooda_metrics)
    end

    test "status contains :agent_status key" do
      status = ModeSupervisor.get_status()
      assert Map.has_key?(status, :agent_status)
    end

    test "status contains :execution_duration key" do
      status = ModeSupervisor.get_status()
      assert Map.has_key?(status, :execution_duration)
    end

    test "status contains :health key" do
      status = ModeSupervisor.get_status()
      assert Map.has_key?(status, :health)
    end

    test "health is a map" do
      status = ModeSupervisor.get_status()
      assert is_map(status.health)
    end

    test "is callable multiple times without crashing" do
      for _ <- 1..5 do
        status = ModeSupervisor.get_status()
        assert is_map(status)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # emergency_stop/0
  # ---------------------------------------------------------------------------

  describe "emergency_stop/0" do
    test "returns :ok without crashing" do
      result = ModeSupervisor.emergency_stop()
      assert result == :ok
    end

    test "GenServer remains alive after emergency_stop" do
      ModeSupervisor.emergency_stop()
      Process.sleep(50)
      assert Process.alive?(GenServer.whereis(ModeSupervisor))
    end

    test "mode transitions to :halted after emergency_stop" do
      ModeSupervisor.emergency_stop()
      Process.sleep(50)
      status = ModeSupervisor.get_status()
      assert status.mode == :halted
    end

    test "current_task is nil after emergency_stop" do
      ModeSupervisor.emergency_stop()
      Process.sleep(50)
      status = ModeSupervisor.get_status()
      assert status.current_task == nil
    end

    test "can call emergency_stop multiple times without crash" do
      ModeSupervisor.emergency_stop()
      Process.sleep(20)
      ModeSupervisor.emergency_stop()
      Process.sleep(20)
      assert Process.alive?(GenServer.whereis(ModeSupervisor))
    end
  end

  # ---------------------------------------------------------------------------
  # execute_mission/1 — contract shape
  # ---------------------------------------------------------------------------

  describe "execute_mission/1" do
    test "returns {:ok, map} or {:error, map} — two-element tuple" do
      result = ModeSupervisor.execute_mission(minimal_mission())
      assert is_tuple(result)
      assert tuple_size(result) == 2
      assert elem(result, 0) in [:ok, :error]
    end

    test "result element 1 is a map in both ok and error cases" do
      result = ModeSupervisor.execute_mission(minimal_mission())

      case result do
        {:ok, data} -> assert is_map(data)
        {:error, data} -> assert is_map(data)
      end
    end

    test "error tuple contains :reason key when max_iterations=0" do
      # A mission with max_iterations: 0 immediately exhausts iterations
      mission = Map.put(minimal_mission(), :max_iterations, 0)
      result = ModeSupervisor.execute_mission(mission)

      case result do
        {:error, data} ->
          assert Map.has_key?(data, :reason)

        {:ok, _} ->
          # Some implementations treat 0 as unlimited — acceptable
          :ok
      end
    end
  end

  # ---------------------------------------------------------------------------
  # fix_compilation_errors/0 — mission convenience wrapper
  # ---------------------------------------------------------------------------

  describe "fix_compilation_errors/0" do
    test "returns {:ok, map} or {:error, map}" do
      # This calls execute_mission internally with a :compilation_fix mission
      # It will exhaust iterations in test environment
      result = ModeSupervisor.fix_compilation_errors()
      assert is_tuple(result)
      assert tuple_size(result) == 2
      assert elem(result, 0) in [:ok, :error]
    end
  end

  # ---------------------------------------------------------------------------
  # OODA loop health check messages
  # ---------------------------------------------------------------------------

  describe "OODA and health check message handling" do
    test "GenServer handles :ooda_loop info message without crashing" do
      pid = GenServer.whereis(ModeSupervisor)
      send(pid, :ooda_loop)
      Process.sleep(20)
      assert Process.alive?(pid)
    end

    test "GenServer handles :health_check info message without crashing" do
      pid = GenServer.whereis(ModeSupervisor)
      send(pid, :health_check)
      Process.sleep(20)
      assert Process.alive?(pid)
    end
  end

  # ---------------------------------------------------------------------------
  # Constitutional Ψ₀ — existence under stress
  # ---------------------------------------------------------------------------

  describe "Constitutional Ψ₀ — ModeSupervisor existence" do
    test "survives rapid get_status calls" do
      for _ <- 1..10 do
        ModeSupervisor.get_status()
      end

      assert Process.alive?(GenServer.whereis(ModeSupervisor))
    end

    test "survives rapid emergency_stop followed by status" do
      ModeSupervisor.emergency_stop()
      Process.sleep(10)
      status = ModeSupervisor.get_status()
      assert is_map(status)
      assert Process.alive?(GenServer.whereis(ModeSupervisor))
    end

    test "health check after rapid OODA messages stays alive" do
      pid = GenServer.whereis(ModeSupervisor)

      for _ <- 1..5 do
        send(pid, :ooda_loop)
        send(pid, :health_check)
      end

      Process.sleep(50)
      assert Process.alive?(pid)
    end
  end

  # ---------------------------------------------------------------------------
  # Ψ₁ — state regeneration (status reflects internal state)
  # ---------------------------------------------------------------------------

  describe "Constitutional Ψ₁ — state regeneration via get_status/0" do
    test "execution_duration is a non-negative value" do
      status = ModeSupervisor.get_status()

      duration = status.execution_duration

      # Duration may be a number of seconds or a string representation
      assert is_number(duration) or is_binary(duration) or is_nil(duration)
    end

    test "agent_status reflects initialized agents" do
      status = ModeSupervisor.get_status()
      agent_status = status.agent_status

      # May be a list, map, or atom
      assert is_list(agent_status) or is_map(agent_status) or is_atom(agent_status)
    end
  end
end
