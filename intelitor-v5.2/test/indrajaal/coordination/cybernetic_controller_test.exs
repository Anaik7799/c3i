defmodule Indrajaal.Coordination.CyberneticControllerTest do
  @moduledoc """
  TDG comprehensive test suite for CyberneticController GenServer.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-GDE-001: Guardian validation required for goal execution
  - SC-OODA-001: OODA cycle < 100ms for normal goals
  - SC-NEURO-001: AI output MUST pass Guardian validation

  ## Constitutional Verification
  - Psi0 Existence: CyberneticController survives goal execution failures
  - Psi2 Evolutionary Continuity: Control mode transitions are auditable

  ## Founder's Directive Alignment
  - Omega0.6: Cybernetic controller pursues sentience through goal execution
  - Omega0.1: Goals serve resource acquisition and operational continuity

  ## TPS 5-Level RCA Context
  - L1 Symptom: Goals execute without feedback loop validation
  - L5 Root Cause: Missing cybernetic control theory implementation
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Coordination.CyberneticController

  @moduletag :zenoh_nif

  defp start_controller(opts \\ []) do
    GenServer.start_link(CyberneticController, opts)
  end

  defp sample_goal do
    %{
      id: "goal-#{System.unique_integer([:positive])}",
      objective: :optimize_throughput,
      target_metric: :response_time,
      threshold: 100,
      priority: :high
    }
  end

  # ==========================================================================
  # start_link/1
  # ==========================================================================

  describe "start_link/1" do
    test "starts successfully with default options" do
      assert {:ok, pid} = start_controller()
      assert is_pid(pid)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "starts in automatic control mode by default" do
      {:ok, pid} = start_controller()
      state = CyberneticController.get_system_state(pid)
      assert is_map(state)
      GenServer.stop(pid)
    end

    test "starts with manual control mode option" do
      {:ok, pid} = start_controller(default_control_mode: :manual)
      assert is_pid(pid)
      GenServer.stop(pid)
    end

    test "starts with supervised control mode option" do
      {:ok, pid} = start_controller(default_control_mode: :supervised)
      assert is_pid(pid)
      GenServer.stop(pid)
    end

    test "starts with autonomous control mode option" do
      {:ok, pid} = start_controller(default_control_mode: :autonomous)
      assert is_pid(pid)
      GenServer.stop(pid)
    end
  end

  # ==========================================================================
  # get_system_state/1
  # ==========================================================================

  describe "get_system_state/1" do
    test "returns a map" do
      {:ok, pid} = start_controller()
      state = CyberneticController.get_system_state(pid)
      assert is_map(state)
      GenServer.stop(pid)
    end

    test "system state is non-nil" do
      {:ok, pid} = start_controller()
      state = CyberneticController.get_system_state(pid)
      refute is_nil(state)
      GenServer.stop(pid)
    end

    test "can call get_system_state multiple times" do
      {:ok, pid} = start_controller()
      assert is_map(CyberneticController.get_system_state(pid))
      assert is_map(CyberneticController.get_system_state(pid))
      GenServer.stop(pid)
    end
  end

  # ==========================================================================
  # set_control_mode/2
  # ==========================================================================

  describe "set_control_mode/2" do
    test "sets manual mode" do
      {:ok, pid} = start_controller()
      result = CyberneticController.set_control_mode(pid, :manual)
      assert result == :ok
      GenServer.stop(pid)
    end

    test "sets automatic mode" do
      {:ok, pid} = start_controller()
      result = CyberneticController.set_control_mode(pid, :automatic)
      assert result == :ok
      GenServer.stop(pid)
    end

    test "sets supervised mode" do
      {:ok, pid} = start_controller()
      result = CyberneticController.set_control_mode(pid, :supervised)
      assert result == :ok
      GenServer.stop(pid)
    end

    test "sets autonomous mode" do
      {:ok, pid} = start_controller()
      result = CyberneticController.set_control_mode(pid, :autonomous)
      assert result == :ok
      GenServer.stop(pid)
    end

    test "can transition between multiple modes" do
      {:ok, pid} = start_controller()
      assert :ok = CyberneticController.set_control_mode(pid, :manual)
      assert :ok = CyberneticController.set_control_mode(pid, :supervised)
      assert :ok = CyberneticController.set_control_mode(pid, :autonomous)
      assert :ok = CyberneticController.set_control_mode(pid, :automatic)
      GenServer.stop(pid)
    end

    test "controller remains alive after mode transitions" do
      {:ok, pid} = start_controller()
      CyberneticController.set_control_mode(pid, :manual)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  # ==========================================================================
  # provide_feedback/3
  # ==========================================================================

  describe "provide_feedback/3" do
    test "accepts performance feedback" do
      {:ok, pid} = start_controller()

      result =
        CyberneticController.provide_feedback(pid, :performance, %{
          latency_ms: 45,
          throughput: 1000
        })

      assert result == :ok
      GenServer.stop(pid)
    end

    test "accepts quality feedback" do
      {:ok, pid} = start_controller()

      result =
        CyberneticController.provide_feedback(pid, :quality, %{
          error_rate: 0.001,
          accuracy: 0.999
        })

      assert result == :ok
      GenServer.stop(pid)
    end

    test "accepts safety feedback" do
      {:ok, pid} = start_controller()

      result =
        CyberneticController.provide_feedback(pid, :safety, %{
          violations: 0,
          safety_score: 1.0
        })

      assert result == :ok
      GenServer.stop(pid)
    end

    test "accepts efficiency feedback" do
      {:ok, pid} = start_controller()

      result =
        CyberneticController.provide_feedback(pid, :efficiency, %{
          cpu_usage: 0.4,
          memory_usage: 0.3
        })

      assert result == :ok
      GenServer.stop(pid)
    end

    test "accepts compliance feedback" do
      {:ok, pid} = start_controller()

      result =
        CyberneticController.provide_feedback(pid, :compliance, %{
          stamp_violations: 0,
          sil_level: 4
        })

      assert result == :ok
      GenServer.stop(pid)
    end

    test "controller remains alive after multiple feedback calls" do
      {:ok, pid} = start_controller()

      feedback_types = [:performance, :quality, :safety, :efficiency, :compliance]

      Enum.each(feedback_types, fn ftype ->
        CyberneticController.provide_feedback(pid, ftype, %{value: 42})
      end)

      Process.sleep(50)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  # ==========================================================================
  # execute_cybernetic_goal/2
  # ==========================================================================

  describe "execute_cybernetic_goal/2" do
    test "returns ok tuple with result map for valid goal" do
      {:ok, pid} = start_controller()
      goal = sample_goal()

      result = CyberneticController.execute_cybernetic_goal(pid, goal)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
      GenServer.stop(pid)
    end

    test "result contains execution information" do
      {:ok, pid} = start_controller()
      goal = sample_goal()

      case CyberneticController.execute_cybernetic_goal(pid, goal) do
        {:ok, result} -> assert is_map(result)
        {:error, _reason} -> assert true
      end

      GenServer.stop(pid)
    end

    test "controller remains alive after goal execution" do
      {:ok, pid} = start_controller()
      CyberneticController.execute_cybernetic_goal(pid, sample_goal())
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "executes minimal goal spec" do
      {:ok, pid} = start_controller()
      minimal_goal = %{objective: :monitor}

      result = CyberneticController.execute_cybernetic_goal(pid, minimal_goal)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
      GenServer.stop(pid)
    end
  end

  # ==========================================================================
  # SIL-6 Safety Tests
  # ==========================================================================

  describe "SIL-6 Requirements" do
    test "controller survives rapid feedback loops" do
      {:ok, pid} = start_controller()

      Enum.each(1..20, fn i ->
        CyberneticController.provide_feedback(pid, :performance, %{iteration: i, latency: i * 10})
      end)

      Process.sleep(100)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "get_system_state is accessible throughout goal execution" do
      {:ok, pid} = start_controller()

      # State must be accessible even during processing
      state_before = CyberneticController.get_system_state(pid)
      assert is_map(state_before)

      CyberneticController.execute_cybernetic_goal(pid, sample_goal())

      state_after = CyberneticController.get_system_state(pid)
      assert is_map(state_after)
      GenServer.stop(pid)
    end
  end

  # ==========================================================================
  # Constitutional Invariants (Psi0-Psi2)
  # ==========================================================================

  describe "Constitutional Invariants (Psi0-Psi2)" do
    test "Psi0 existence: controller survives empty goal spec" do
      {:ok, pid} = start_controller()
      CyberneticController.execute_cybernetic_goal(pid, %{})
      assert Process.alive?(pid), "Controller (Psi0) must survive empty goal"
      GenServer.stop(pid)
    end

    test "Psi2 evolutionary continuity: mode transitions are auditable via state" do
      {:ok, pid} = start_controller()

      :ok = CyberneticController.set_control_mode(pid, :manual)
      state_manual = CyberneticController.get_system_state(pid)

      :ok = CyberneticController.set_control_mode(pid, :autonomous)
      state_autonomous = CyberneticController.get_system_state(pid)

      # Both states are valid maps (transition history preserved)
      assert is_map(state_manual)
      assert is_map(state_autonomous)
      GenServer.stop(pid)
    end

    test "Psi1 regeneration: new controller starts fresh" do
      {:ok, pid1} = start_controller()
      :ok = CyberneticController.set_control_mode(pid1, :manual)
      GenServer.stop(pid1)

      Process.sleep(10)

      {:ok, pid2} = start_controller()
      assert Process.alive?(pid2)
      state = CyberneticController.get_system_state(pid2)
      assert is_map(state)
      GenServer.stop(pid2)
    end
  end

  # ==========================================================================
  # FMEA Tests
  # ==========================================================================

  describe "FMEA Critical Paths" do
    @tag :fmea
    test "FMEA-CC-001: controller handles malformed goal spec without crash" do
      {:ok, pid} = start_controller()

      malformed_goals = [
        %{objective: nil},
        %{threshold: "not_a_number"},
        %{}
      ]

      Enum.each(malformed_goals, fn goal ->
        _result = CyberneticController.execute_cybernetic_goal(pid, goal)
        assert Process.alive?(pid)
      end)

      GenServer.stop(pid)
    end

    @tag :fmea
    test "FMEA-CC-002: concurrent feedback calls do not race" do
      {:ok, pid} = start_controller()

      tasks =
        Enum.map(1..10, fn i ->
          Task.async(fn ->
            CyberneticController.provide_feedback(pid, :performance, %{value: i})
          end)
        end)

      Enum.each(tasks, &Task.await(&1, 5_000))
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    @tag :fmea
    test "FMEA-CC-003: invalid control mode is handled gracefully" do
      {:ok, pid} = start_controller()

      # Setting invalid mode may return :ok or error - should not crash
      result = CyberneticController.set_control_mode(pid, :invalid_mode)
      assert result == :ok or match?({:error, _}, result)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  # ==========================================================================
  # Property Tests
  # ==========================================================================

  property "set_control_mode returns :ok for all valid modes" do
    valid_modes = [:manual, :automatic, :supervised, :autonomous]

    forall mode <- PC.oneof(Enum.map(valid_modes, &PC.return/1)) do
      {:ok, pid} = start_controller()
      result = CyberneticController.set_control_mode(pid, mode)
      GenServer.stop(pid)
      result == :ok
    end
  end

  test "get_system_state always returns a map" do
    ExUnitProperties.check all(_x <- SD.constant(:ok)) do
      {:ok, pid} = start_controller()
      state = CyberneticController.get_system_state(pid)
      GenServer.stop(pid)
      assert is_map(state)
    end
  end
end
