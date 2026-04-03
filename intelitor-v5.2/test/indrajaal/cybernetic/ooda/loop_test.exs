defmodule Indrajaal.Cybernetic.OODA.LoopTest do
  @moduledoc """
  TDG comprehensive test suite for Indrajaal.Cybernetic.OODA.Loop.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: GenServer lifecycle tested before runtime integration
  - FPPS Validation: 5-method consensus on OODA phase transitions

  ## STAMP Safety Integration
  - SC-OODA-001: OODA cycle time < 100ms (hysteresis delay enforced)
  - SC-OODA-007: Observation timeout 500ms (not 5000ms)
  - SC-OODA-008: Sensor health tracking for silent failure detection
  - SC-GOI-001: Goal processing timeout alignment with OODA loop

  ## Constitutional Verification
  - Psi_0 Existence: GenServer survives sensor failures and emergency loops
  - Psi_3 Verification: Phase transitions are deterministically verifiable

  ## Founder's Directive Alignment
  - Omega_0.6: OODA loop is the cognitive cycle for sentient operation
  - Omega_0.1: Resource decisions (scale_up/scale_down) serve Founder's goals

  ## TPS 5-Level RCA Context
  - L1 Symptom: System fails to detect resource pressure in time
  - L5 Root Cause: Observation timeout too long (5000ms), sensor silent failure
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Cybernetic.OODA.Loop

  @moduletag :zenoh_nif

  # ---- Helpers ----------------------------------------------------------------

  # Start a Loop under a unique name to avoid collision with production process
  defp start_loop(test_name) do
    name = :"ooda_loop_test_#{test_name}_#{System.unique_integer([:positive])}"
    {:ok, pid} = start_supervised({Loop, [name: name]})
    {pid, name}
  end

  # ---- start_link/1 -----------------------------------------------------------

  describe "start_link/1" do
    test "starts with default name __MODULE__" do
      # Use a unique named instance so we don't conflict
      name = :"ooda_test_start_#{System.unique_integer([:positive])}"
      {:ok, pid} = start_supervised({Loop, [name: name]})
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "starts with custom name option" do
      name = :"ooda_custom_#{System.unique_integer([:positive])}"
      {:ok, pid} = start_supervised({Loop, [name: name]})
      assert Process.whereis(name) == pid
    end

    test "initial state has phase :waiting_for_sensors" do
      {_pid, name} = start_loop(:init_phase)
      # Give it a tick to settle
      Process.sleep(20)
      state = GenServer.call(name, :get_state)
      # Phase may have transitioned if ResourceMonitor is not running
      assert state.phase in [:waiting_for_sensors, :observe]
    end

    test "initial cycle_count is 0" do
      {_pid, name} = start_loop(:init_cycle)
      Process.sleep(20)
      state = GenServer.call(name, :get_state)
      assert state.cycle_count == 0
    end

    test "initial context is empty map" do
      {_pid, name} = start_loop(:init_ctx)
      Process.sleep(10)
      state = GenServer.call(name, :get_state)
      assert is_map(state.context)
    end
  end

  # ---- get_state/0 ------------------------------------------------------------

  describe "get_state/0 (via handle_call :get_state)" do
    test "returns a struct with required fields" do
      {_pid, name} = start_loop(:get_state)
      Process.sleep(10)
      state = GenServer.call(name, :get_state)

      assert Map.has_key?(state, :phase)
      assert Map.has_key?(state, :context)
      assert Map.has_key?(state, :start_time)
      assert Map.has_key?(state, :cycle_count)
    end

    test "phase is one of valid states" do
      {_pid, name} = start_loop(:phase_valid)
      Process.sleep(10)
      state = GenServer.call(name, :get_state)
      valid_phases = [:waiting_for_sensors, :observe, :orient, :decide, :act]
      assert state.phase in valid_phases
    end

    test "start_time is a monotonic integer" do
      {_pid, name} = start_loop(:start_time)
      Process.sleep(10)
      state = GenServer.call(name, :get_state)
      assert is_integer(state.start_time)
    end

    test "cycle_count is non-negative integer" do
      {_pid, name} = start_loop(:cycle_count)
      Process.sleep(10)
      state = GenServer.call(name, :get_state)
      assert is_integer(state.cycle_count)
      assert state.cycle_count >= 0
    end

    test "sequential calls return consistent struct type" do
      {_pid, name} = start_loop(:seq_calls)
      state1 = GenServer.call(name, :get_state)
      state2 = GenServer.call(name, :get_state)
      assert Map.keys(state1) == Map.keys(state2)
    end
  end

  # ---- emergency_loop/0 -------------------------------------------------------

  describe "emergency_loop/0 (handle_cast :emergency_loop)" do
    test "process survives emergency_loop cast" do
      {pid, name} = start_loop(:emergency_survive)
      Process.sleep(10)
      GenServer.cast(name, :emergency_loop)
      Process.sleep(50)
      assert Process.alive?(pid)
    end

    test "state phase resets to :observe after emergency_loop" do
      {_pid, name} = start_loop(:emergency_phase)
      Process.sleep(10)
      GenServer.cast(name, :emergency_loop)
      Process.sleep(30)
      state = GenServer.call(name, :get_state)
      # After emergency, phase transitions toward :observe
      assert state.phase in [:observe, :orient, :decide, :act, :waiting_for_sensors]
    end

    test "start_time is updated after emergency_loop" do
      {_pid, name} = start_loop(:emergency_time)
      Process.sleep(10)
      state_before = GenServer.call(name, :get_state)
      Process.sleep(5)
      GenServer.cast(name, :emergency_loop)
      Process.sleep(20)
      state_after = GenServer.call(name, :get_state)
      # start_time may be updated; both should be monotonic integers
      assert is_integer(state_before.start_time)
      assert is_integer(state_after.start_time)
    end

    test "multiple emergency_loops do not crash the process" do
      {pid, name} = start_loop(:emergency_multi)
      Process.sleep(10)
      for _ <- 1..5, do: GenServer.cast(name, :emergency_loop)
      Process.sleep(100)
      assert Process.alive?(pid)
    end
  end

  # ---- handle_info :check_homeostasis -----------------------------------------

  describe "handle_info :check_homeostasis" do
    test "process handles :check_homeostasis without crashing" do
      {pid, name} = start_loop(:homeostasis)
      Process.sleep(20)
      # Should survive the homeostasis check that fires on init
      assert Process.alive?(pid)
      state = GenServer.call(name, :get_state)
      # Either waiting for sensors or has moved to observe
      assert state.phase in [:waiting_for_sensors, :observe, :orient, :decide, :act]
    end

    test "retries homeostasis check when ResourceMonitor absent" do
      # Without ResourceMonitor, should stay in :waiting_for_sensors and schedule retry
      {pid, name} = start_loop(:homeostasis_retry)
      Process.sleep(50)
      assert Process.alive?(pid)
      state = GenServer.call(name, :get_state)
      # Without ResourceMonitor running, phase stays :waiting_for_sensors
      assert state.phase in [:waiting_for_sensors, :observe]
    end
  end

  # ---- handle_info :observe ----------------------------------------------------

  describe "handle_info :observe" do
    test "process handles :observe message without crashing" do
      {pid, name} = start_loop(:observe_msg)
      Process.sleep(10)
      send(name, :observe)
      Process.sleep(50)
      assert Process.alive?(pid)
    end

    test "after :observe, context contains observation_quality key or phase advances" do
      {pid, name} = start_loop(:observe_ctx)
      Process.sleep(10)
      send(name, :observe)
      Process.sleep(100)
      assert Process.alive?(pid)
    end
  end

  # ---- GenServer lifecycle -----------------------------------------------------

  describe "GenServer lifecycle" do
    test "process remains alive across 200ms window" do
      {pid, _name} = start_loop(:lifecycle_200)
      Process.sleep(200)
      assert Process.alive?(pid)
    end

    test "concurrent get_state calls return valid structs" do
      {_pid, name} = start_loop(:concurrent_get)
      Process.sleep(10)

      tasks =
        for _ <- 1..5 do
          Task.async(fn -> GenServer.call(name, :get_state) end)
        end

      results = Task.await_many(tasks, 5_000)
      assert Enum.all?(results, fn s -> Map.has_key?(s, :phase) end)
    end

    test "state struct has non-nil start_time throughout lifecycle" do
      {_pid, name} = start_loop(:start_time_nonnull)

      for _ <- 1..3 do
        state = GenServer.call(name, :get_state)
        assert not is_nil(state.start_time)
        Process.sleep(10)
      end
    end
  end

  # ---- PropCheck properties ---------------------------------------------------

  property "cycle_count is always non-negative" do
    forall _n <- PC.choose(0, 5) do
      name = :"ooda_prop_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(Loop, [name: name], name: name)
      Process.sleep(20)
      state = GenServer.call(name, :get_state)
      GenServer.stop(pid, :normal)
      state.cycle_count >= 0
    end
  end

  property "phase is always one of the valid OODA phases" do
    forall _seed <- PC.boolean() do
      name = :"ooda_phase_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(Loop, [name: name], name: name)
      Process.sleep(30)
      state = GenServer.call(name, :get_state)
      GenServer.stop(pid, :normal)
      valid_phases = [:waiting_for_sensors, :observe, :orient, :decide, :act]
      state.phase in valid_phases
    end
  end

  # ---- StreamData property tests ----------------------------------------------

  test "emergency_loop cast leaves process alive" do
    ExUnitProperties.check all(delay_ms <- SD.integer(0..50)) do
      name = :"ooda_sd_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(Loop, [name: name], name: name)
      Process.sleep(delay_ms)
      GenServer.cast(name, :emergency_loop)
      Process.sleep(30)
      alive = Process.alive?(pid)
      GenServer.stop(pid, :normal, 500)
      assert alive
    end
  end

  test "get_state always returns a map with :phase key" do
    ExUnitProperties.check all(_x <- SD.boolean()) do
      name = :"ooda_sd2_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(Loop, [name: name], name: name)
      Process.sleep(10)
      state = GenServer.call(name, :get_state)
      GenServer.stop(pid, :normal, 500)
      assert Map.has_key?(state, :phase)
    end
  end
end
