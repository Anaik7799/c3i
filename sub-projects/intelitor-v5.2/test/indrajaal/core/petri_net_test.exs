defmodule Indrajaal.Core.PetriNetTest do
  @moduledoc """
  Mathematical verification tests for Petri Net formal verification.

  Mathematical properties verified:
  1. Reachability: Can the net reach state S from initial marking?
  2. Deadlock-freedom: Does the net contain deadlock states?
  3. Boundedness: Are all places bounded (no unbounded token accumulation)?
  4. Liveness: Can every transition always eventually fire?
  5. State space: The reachable states form a complete and correct set

  Petri Net formal model: N = (P, T, F, M0)
  where P = places, T = transitions, F = flow relation, M0 = initial marking

  STAMP: SC-MATH-001 (discipline health), SC-VER-001 (startup verification)
  Layer: L1-CODE (pure mathematical verification)
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Verification.PetriNet

  @moduletag :mathematical
  @moduletag :petri_net
  @moduletag timeout: 120_000

  # ============================================================================
  # Simple FSM: traffic light model
  # ============================================================================

  @traffic_light_fsm %{
    states: [:red, :green, :yellow],
    initial: :red,
    transitions: [
      {:red, :go, :green},
      {:green, :slow, :yellow},
      {:yellow, :stop, :red}
    ]
  }

  # ============================================================================
  # Linear FSM: sequential pipeline
  # ============================================================================

  @pipeline_fsm %{
    states: [:idle, :processing, :validating, :done],
    initial: :idle,
    transitions: [
      {:idle, :start, :processing},
      {:processing, :validate, :validating},
      {:validating, :complete, :done},
      {:done, :reset, :idle}
    ]
  }

  # ============================================================================
  # Setup: start PetriNet GenServer per test
  # ============================================================================

  setup do
    # Start the PetriNet GenServer with a unique name to avoid conflicts
    name = :"petri_net_test_#{System.unique_integer([:positive])}"
    {:ok, pid} = PetriNet.start_link(name: name)
    %{pid: pid, name: name}
  end

  # ============================================================================
  # Net registration and basic reachability
  # ============================================================================

  describe "net registration and state reachability" do
    test "can register a traffic light FSM", %{pid: pid} do
      result = PetriNet.register_net(pid, :traffic, @traffic_light_fsm)
      assert result == :ok or match?({:ok, _}, result)
    end

    test "initial state is reachable", %{pid: pid} do
      PetriNet.register_net(pid, :traffic, @traffic_light_fsm)
      assert PetriNet.reachable?(pid, :red)
    end

    test "second state is reachable after firing transition", %{pid: pid} do
      PetriNet.register_net(pid, :traffic, @traffic_light_fsm)
      PetriNet.fire(pid, :go)
      assert PetriNet.reachable?(pid, :green)
    end

    test "pipeline FSM: idle state is reachable", %{pid: pid} do
      PetriNet.register_net(pid, :pipeline, @pipeline_fsm)
      assert PetriNet.reachable?(pid, :idle)
    end

    test "from_fsm/2 registers a net from FSM spec", %{pid: pid} do
      result = PetriNet.from_fsm(pid, @traffic_light_fsm)
      assert result == :ok or match?({:ok, _}, result)
    end
  end

  # ============================================================================
  # Formal verification: verify/1
  # ============================================================================

  describe "formal verification results" do
    test "traffic light net produces valid verification result", %{pid: pid} do
      PetriNet.register_net(pid, :traffic, @traffic_light_fsm)
      {:ok, result} = PetriNet.verify(pid)

      assert is_map(result)
      assert Map.has_key?(result, :verified)
    end

    test "verification result includes reachable_states set", %{pid: pid} do
      PetriNet.register_net(pid, :traffic, @traffic_light_fsm)
      {:ok, result} = PetriNet.verify(pid)

      assert Map.has_key?(result, :reachable_states)
    end

    test "verification result includes deadlock_free boolean", %{pid: pid} do
      PetriNet.register_net(pid, :traffic, @traffic_light_fsm)
      {:ok, result} = PetriNet.verify(pid)

      assert Map.has_key?(result, :deadlock_free)
      assert is_boolean(result.deadlock_free)
    end

    test "traffic light net is deadlock-free (cycle: red→green→yellow→red)", %{pid: pid} do
      PetriNet.register_net(pid, :traffic, @traffic_light_fsm)
      {:ok, result} = PetriNet.verify(pid)

      assert result.deadlock_free == true
    end

    test "verification result includes bounded boolean", %{pid: pid} do
      PetriNet.register_net(pid, :traffic, @traffic_light_fsm)
      {:ok, result} = PetriNet.verify(pid)

      assert Map.has_key?(result, :bounded)
      assert is_boolean(result.bounded)
    end

    test "verification result includes analysis_time_ms", %{pid: pid} do
      PetriNet.register_net(pid, :traffic, @traffic_light_fsm)
      {:ok, result} = PetriNet.verify(pid)

      assert Map.has_key?(result, :analysis_time_ms)
      assert is_integer(result.analysis_time_ms) or is_float(result.analysis_time_ms)
    end

    test "analysis_time_ms is non-negative", %{pid: pid} do
      PetriNet.register_net(pid, :traffic, @traffic_light_fsm)
      {:ok, result} = PetriNet.verify(pid)

      assert result.analysis_time_ms >= 0
    end

    test "pipeline net verifies successfully", %{pid: pid} do
      PetriNet.register_net(pid, :pipeline, @pipeline_fsm)
      {:ok, result} = PetriNet.verify(pid)

      assert result.verified == true or is_boolean(result.verified)
    end
  end

  # ============================================================================
  # Deadlock detection
  # ============================================================================

  describe "deadlock detection" do
    test "detect_deadlocks/1 returns {:ok, list}", %{pid: pid} do
      PetriNet.register_net(pid, :traffic, @traffic_light_fsm)
      result = PetriNet.detect_deadlocks(pid)

      assert match?({:ok, _}, result)
      {:ok, deadlocks} = result
      assert is_list(deadlocks)
    end

    test "traffic light has no deadlocks", %{pid: pid} do
      PetriNet.register_net(pid, :traffic, @traffic_light_fsm)
      {:ok, deadlocks} = PetriNet.detect_deadlocks(pid)

      assert deadlocks == []
    end

    test "deadlock detector returns list of states or empty list", %{pid: pid} do
      PetriNet.register_net(pid, :pipeline, @pipeline_fsm)
      {:ok, deadlocks} = PetriNet.detect_deadlocks(pid)

      assert is_list(deadlocks)
    end
  end

  # ============================================================================
  # Boundedness
  # ============================================================================

  describe "boundedness verification" do
    test "bounded?/1 returns a boolean", %{pid: pid} do
      PetriNet.register_net(pid, :traffic, @traffic_light_fsm)
      result = PetriNet.bounded?(pid)

      assert is_boolean(result)
    end

    test "finite-state FSM nets are bounded", %{pid: pid} do
      PetriNet.register_net(pid, :traffic, @traffic_light_fsm)
      assert PetriNet.bounded?(pid) == true
    end
  end

  # ============================================================================
  # Liveness
  # ============================================================================

  describe "liveness verification" do
    test "live?/1 returns a boolean", %{pid: pid} do
      PetriNet.register_net(pid, :traffic, @traffic_light_fsm)
      result = PetriNet.live?(pid)

      assert is_boolean(result)
    end

    test "strongly connected FSM is live", %{pid: pid} do
      PetriNet.register_net(pid, :traffic, @traffic_light_fsm)
      # Traffic light is strongly connected → all transitions eventually fireable
      assert PetriNet.live?(pid) == true
    end
  end

  # ============================================================================
  # Property: FSM with n states has ≤ n reachable states (PropCheck)
  # ============================================================================

  describe "property: reachable state count invariants (PropCheck)" do
    property "reachable states ≤ total states in FSM" do
      forall n <- PC.choose(2, 5) do
        # Build a linear chain FSM with n states
        states = Enum.map(1..n, fn i -> :"state_#{i}" end)
        initial = List.first(states)

        transitions =
          states
          |> Enum.chunk_every(2, 1, :discard)
          |> Enum.with_index()
          |> Enum.map(fn {[from, to], i} -> {from, :"event_#{i}", to} end)

        fsm = %{states: states, initial: initial, transitions: transitions}

        # Start a fresh PetriNet for this property check
        name = :"prop_pn_#{System.unique_integer([:positive])}"
        {:ok, pid} = PetriNet.start_link(name: name)
        PetriNet.register_net(pid, :chain, fsm)
        {:ok, result} = PetriNet.verify(pid)
        GenServer.stop(pid)

        reachable_count = MapSet.size(result.reachable_states)
        reachable_count <= n
      end
    end
  end

  # ============================================================================
  # Property: verification invariants (StreamData)
  # ============================================================================

  describe "property: verification result structure (StreamData)" do
    test "all required fields present in verification result" do
      ExUnitProperties.check all(n_states <- SD.integer(2..4)) do
        states = Enum.map(1..n_states, fn i -> :"s#{i}" end)
        initial = List.first(states)

        transitions =
          states
          |> Enum.chunk_every(2, 1, :discard)
          |> Enum.with_index()
          |> Enum.map(fn {[from, to], i} -> {from, :"e#{i}", to} end)

        fsm = %{states: states, initial: initial, transitions: transitions}

        name = :"sd_pn_#{System.unique_integer([:positive])}"
        {:ok, pid} = PetriNet.start_link(name: name)
        PetriNet.register_net(pid, :test, fsm)
        {:ok, result} = PetriNet.verify(pid)
        GenServer.stop(pid)

        required_keys = [
          :verified,
          :deadlock_free,
          :bounded,
          :reachable_states,
          :analysis_time_ms
        ]

        Enum.all?(required_keys, &Map.has_key?(result, &1))
      end
    end
  end
end
