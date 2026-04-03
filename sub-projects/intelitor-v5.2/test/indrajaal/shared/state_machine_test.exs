defmodule Indrajaal.Shared.StateMachineTest do
  @moduledoc """
  TDG-compliant tests for Indrajaal.Shared.StateMachine module.

  Tests comprehensive state machine patterns for:
  - State machine initialization
  - State transition validation
  - Configuration management
  - Valid next state queries
  - Callback behaviour compliance

  Created: 2025-11-27 14:45:00 CEST
  Phase: 2.3 - C1 Security-Critical Testing (Safety & State Modules)
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Shared.StateMachine

  # Mock state machine module for testing
  defmodule TestStateMachine do
    @moduledoc false
    @behaviour Indrajaal.Shared.StateMachine

    @impl true
    def initial_state, do: :idle

    @impl true
    def valid_transitions do
      %{
        idle: [:running, :paused],
        running: [:paused, :stopped, :idle],
        paused: [:running, :stopped],
        stopped: [:idle]
      }
    end

    @impl true
    def handle_transition(from_state, to_state, data) do
      {:ok, Map.merge(data, %{transitioned_from: from_state, transitioned_to: to_state})}
    end
  end

  # Simple state machine for edge case testing
  defmodule SimpleStateMachine do
    @moduledoc false
    @behaviour Indrajaal.Shared.StateMachine

    @impl true
    def initial_state, do: :start

    @impl true
    def valid_transitions do
      %{
        start: [:end],
        end: []
      }
    end

    @impl true
    def handle_transition(_from, _to, data), do: {:ok, data}
  end

  # ============================================================================
  # STATE MACHINE INITIALIZATION TESTS
  # ============================================================================

  describe "new/2 - initialization" do
    test "creates state machine with initial state from module" do
      sm = StateMachine.new(TestStateMachine)

      assert sm.current_state == :idle
    end

    test "creates state machine with empty config by default" do
      sm = StateMachine.new(TestStateMachine)

      assert sm.config == %{}
    end

    test "creates state machine with custom initial config" do
      config = %{timeout: 5000, retries: 3}
      sm = StateMachine.new(TestStateMachine, config)

      assert sm.config == config
    end

    test "stores transitions map from module" do
      sm = StateMachine.new(TestStateMachine)

      assert sm.transitions == TestStateMachine.valid_transitions()
    end

    test "stores callbacks reference to module" do
      sm = StateMachine.new(TestStateMachine)

      assert sm.callbacks == TestStateMachine
    end

    test "works with simple state machine" do
      sm = StateMachine.new(SimpleStateMachine)

      assert sm.current_state == :start
      assert sm.transitions == %{start: [:end], end: []}
    end

    test "creates struct with all required fields" do
      sm = StateMachine.new(TestStateMachine, %{key: "value"})

      assert is_struct(sm, StateMachine)
      assert Map.has_key?(sm, :current_state)
      assert Map.has_key?(sm, :config)
      assert Map.has_key?(sm, :transitions)
      assert Map.has_key?(sm, :callbacks)
    end
  end

  # ============================================================================
  # CURRENT STATE TESTS
  # ============================================================================

  describe "current_state/1" do
    test "returns current state of state machine" do
      sm = StateMachine.new(TestStateMachine)

      assert StateMachine.current_state(sm) == :idle
    end

    test "returns initial state for new state machine" do
      sm = StateMachine.new(SimpleStateMachine)

      assert StateMachine.current_state(sm) == :start
    end
  end

  # ============================================================================
  # VALID NEXT STATES TESTS
  # ============================================================================

  describe "valid_next_states/1" do
    test "returns valid transitions from idle state" do
      sm = StateMachine.new(TestStateMachine)

      assert StateMachine.valid_next_states(sm) == [:running, :paused]
    end

    test "returns valid transitions from running state" do
      sm = %{StateMachine.new(TestStateMachine) | current_state: :running}

      assert StateMachine.valid_next_states(sm) == [:paused, :stopped, :idle]
    end

    test "returns valid transitions from paused state" do
      sm = %{StateMachine.new(TestStateMachine) | current_state: :paused}

      assert StateMachine.valid_next_states(sm) == [:running, :stopped]
    end

    test "returns valid transitions from stopped state" do
      sm = %{StateMachine.new(TestStateMachine) | current_state: :stopped}

      assert StateMachine.valid_next_states(sm) == [:idle]
    end

    test "returns empty list for terminal state" do
      sm = %{StateMachine.new(SimpleStateMachine) | current_state: :end}

      assert StateMachine.valid_next_states(sm) == []
    end

    test "returns empty list for unknown state" do
      sm = %{StateMachine.new(TestStateMachine) | current_state: :unknown}

      assert StateMachine.valid_next_states(sm) == []
    end
  end

  # ============================================================================
  # VALID TRANSITION TESTS
  # ============================================================================

  describe "valid_transition?/2" do
    test "returns true for valid transition from idle to running" do
      sm = StateMachine.new(TestStateMachine)

      assert StateMachine.valid_transition?(sm, :running) == true
    end

    test "returns true for valid transition from idle to paused" do
      sm = StateMachine.new(TestStateMachine)

      assert StateMachine.valid_transition?(sm, :paused) == true
    end

    test "returns false for invalid transition from idle to stopped" do
      sm = StateMachine.new(TestStateMachine)

      assert StateMachine.valid_transition?(sm, :stopped) == false
    end

    test "returns false for self-transition when not allowed" do
      sm = StateMachine.new(TestStateMachine)

      assert StateMachine.valid_transition?(sm, :idle) == false
    end

    test "returns false for any transition from terminal state" do
      sm = %{StateMachine.new(SimpleStateMachine) | current_state: :end}

      assert StateMachine.valid_transition?(sm, :start) == false
      assert StateMachine.valid_transition?(sm, :end) == false
    end

    test "returns true for valid transition from running to idle" do
      sm = %{StateMachine.new(TestStateMachine) | current_state: :running}

      assert StateMachine.valid_transition?(sm, :idle) == true
    end

    test "returns false for unknown target state" do
      sm = StateMachine.new(TestStateMachine)

      assert StateMachine.valid_transition?(sm, :unknown_state) == false
    end
  end

  # ============================================================================
  # CONFIGURATION TESTS
  # ============================================================================

  describe "config/1" do
    test "returns empty config for new state machine" do
      sm = StateMachine.new(TestStateMachine)

      assert StateMachine.config(sm) == %{}
    end

    test "returns initial config" do
      config = %{timeout: 5000, retries: 3}
      sm = StateMachine.new(TestStateMachine, config)

      assert StateMachine.config(sm) == config
    end

    test "returns config with nested values" do
      config = %{settings: %{a: 1, b: 2}, name: "test"}
      sm = StateMachine.new(TestStateMachine, config)

      assert StateMachine.config(sm) == config
    end
  end

  describe "update_config/2" do
    test "updates config with new values" do
      sm = StateMachine.new(TestStateMachine)
      new_config = %{timeout: 10_000}
      updated = StateMachine.update_config(sm, new_config)

      assert StateMachine.config(updated) == new_config
    end

    test "replaces entire config" do
      initial_config = %{a: 1, b: 2}
      new_config = %{c: 3}
      sm = StateMachine.new(TestStateMachine, initial_config)
      updated = StateMachine.update_config(sm, new_config)

      assert StateMachine.config(updated) == new_config
    end

    test "preserves current state when updating config" do
      sm = %{StateMachine.new(TestStateMachine) | current_state: :running}
      updated = StateMachine.update_config(sm, %{new: "config"})

      assert StateMachine.current_state(updated) == :running
    end

    test "preserves transitions when updating config" do
      sm = StateMachine.new(TestStateMachine)
      updated = StateMachine.update_config(sm, %{new: "config"})

      assert updated.transitions == TestStateMachine.valid_transitions()
    end

    test "preserves callbacks when updating config" do
      sm = StateMachine.new(TestStateMachine)
      updated = StateMachine.update_config(sm, %{new: "config"})

      assert updated.callbacks == TestStateMachine
    end
  end

  # ============================================================================
  # TRANSITION FUNCTION TESTS
  # ============================================================================

  describe "transition/3" do
    test "returns state machine (placeholder implementation)" do
      sm = StateMachine.new(TestStateMachine)
      result = StateMachine.transition(sm, :start, %{})

      # Current implementation is a placeholder that returns state machine unchanged
      assert result == sm
    end

    test "accepts action and data parameters" do
      sm = StateMachine.new(TestStateMachine)
      # Should not raise
      result = StateMachine.transition(sm, :some_action, %{key: "value"})

      assert is_struct(result, StateMachine)
    end
  end

  # ============================================================================
  # PROPERTY-BASED TESTS (PropCheck)
  # ============================================================================

  describe "Property Tests (PropCheck)" do
    property "new/2 always creates valid state machine struct" do
      forall config <- PC.map(PC.atom(), PC.any()) do
        sm = StateMachine.new(TestStateMachine, config)

        is_struct(sm, StateMachine) and
          sm.current_state == :idle and
          sm.callbacks == TestStateMachine
      end
    end

    property "valid_next_states always returns a list" do
      forall state <- oneof([:idle, :running, :paused, :stopped, :unknown]) do
        sm = %{StateMachine.new(TestStateMachine) | current_state: state}
        result = StateMachine.valid_next_states(sm)

        is_list(result)
      end
    end

    property "valid_transition? always returns boolean" do
      forall {state, target} <- {
               oneof([:idle, :running, :paused, :stopped]),
               oneof([:idle, :running, :paused, :stopped, :unknown])
             } do
        sm = %{StateMachine.new(TestStateMachine) | current_state: state}
        result = StateMachine.valid_transition?(sm, target)

        is_boolean(result)
      end
    end

    property "update_config preserves state machine structure" do
      forall {initial_config, new_config} <-
               {PC.map(PC.atom(), PC.any()), PC.map(PC.atom(), PC.any())} do
        sm = StateMachine.new(TestStateMachine, initial_config)
        updated = StateMachine.update_config(sm, new_config)

        is_struct(updated, StateMachine) and
          updated.current_state == sm.current_state and
          updated.transitions == sm.transitions and
          updated.callbacks == sm.callbacks
      end
    end

    property "config/1 returns the same config as stored" do
      forall config <- PC.map(PC.atom(), PC.utf8()) do
        sm = StateMachine.new(TestStateMachine, config)
        result = StateMachine.config(sm)

        result == config
      end
    end
  end

  # ============================================================================
  # EDGE CASE TESTS
  # ============================================================================

  describe "Edge Cases" do
    test "handles state machine with single state" do
      defmodule SingleStateStateMachine do
        @behaviour Indrajaal.Shared.StateMachine

        def initial_state, do: :only_state
        def valid_transitions, do: %{only_state: []}
        def handle_transition(_, _, data), do: {:ok, data}
      end

      sm = StateMachine.new(SingleStateStateMachine)

      assert sm.current_state == :only_state
      assert StateMachine.valid_next_states(sm) == []
    end

    test "handles empty transitions map" do
      defmodule EmptyTransitionsStateMachine do
        @behaviour Indrajaal.Shared.StateMachine

        def initial_state, do: :start
        def valid_transitions, do: %{}
        def handle_transition(_, _, data), do: {:ok, data}
      end

      sm = StateMachine.new(EmptyTransitionsStateMachine)

      assert StateMachine.valid_next_states(sm) == []
    end

    test "handles config with special values" do
      config = %{
        nil_value: nil,
        empty_list: [],
        empty_map: %{},
        nested: %{deep: %{value: 1}}
      }

      sm = StateMachine.new(TestStateMachine, config)

      assert StateMachine.config(sm) == config
    end

    test "handles state with many valid transitions" do
      defmodule ManyTransitionsStateMachine do
        @behaviour Indrajaal.Shared.StateMachine

        def initial_state, do: :hub
        def valid_transitions, do: %{hub: [:a, :b, :c, :d, :e, :f, :g, :h, :i, :j]}
        def handle_transition(_, _, data), do: {:ok, data}
      end

      sm = StateMachine.new(ManyTransitionsStateMachine)

      assert length(StateMachine.valid_next_states(sm)) == 10
    end
  end

  # ============================================================================
  # BEHAVIOUR COMPLIANCE TESTS
  # ============================================================================

  describe "Behaviour Compliance" do
    test "TestStateMachine implements all callbacks" do
      assert function_exported?(TestStateMachine, :initial_state, 0)
      assert function_exported?(TestStateMachine, :valid_transitions, 0)
      assert function_exported?(TestStateMachine, :handle_transition, 3)
    end

    test "SimpleStateMachine implements all callbacks" do
      assert function_exported?(SimpleStateMachine, :initial_state, 0)
      assert function_exported?(SimpleStateMachine, :valid_transitions, 0)
      assert function_exported?(SimpleStateMachine, :handle_transition, 3)
    end

    test "handle_transition callback returns expected format" do
      {:ok, data} = TestStateMachine.handle_transition(:idle, :running, %{})

      assert is_map(data)
      assert data.transitioned_from == :idle
      assert data.transitioned_to == :running
    end
  end

  # ============================================================================
  # STRUCT TESTS
  # ============================================================================

  describe "Struct Definition" do
    test "defstruct defines expected fields" do
      sm = %StateMachine{}

      assert Map.has_key?(sm, :current_state)
      assert Map.has_key?(sm, :config)
      assert Map.has_key?(sm, :transitions)
      assert Map.has_key?(sm, :callbacks)
    end

    test "struct fields default to nil" do
      sm = %StateMachine{}

      assert sm.current_state == nil
      assert sm.config == nil
      assert sm.transitions == nil
      assert sm.callbacks == nil
    end
  end

  # ============================================================================
  # INTEGRATION SCENARIO TESTS
  # ============================================================================

  describe "Integration Scenarios" do
    test "complete workflow: create, check states, update config" do
      # Create state machine
      sm = StateMachine.new(TestStateMachine, %{name: "test_workflow"})

      # Verify initial state
      assert StateMachine.current_state(sm) == :idle
      assert StateMachine.config(sm).name == "test_workflow"

      # Check valid transitions
      valid_states = StateMachine.valid_next_states(sm)
      assert :running in valid_states
      assert :paused in valid_states

      # Validate specific transitions
      assert StateMachine.valid_transition?(sm, :running)
      refute StateMachine.valid_transition?(sm, :stopped)

      # Update configuration
      updated = StateMachine.update_config(sm, %{name: "updated", step: 2})
      assert StateMachine.config(updated).name == "updated"
      assert StateMachine.config(updated).step == 2

      # State should be preserved
      assert StateMachine.current_state(updated) == :idle
    end

    test "simulates state progression through manual state updates" do
      sm = StateMachine.new(TestStateMachine)

      # Simulate transitions by updating state directly
      # (Real implementation would use transition/3)
      sm_running = %{sm | current_state: :running}
      assert StateMachine.current_state(sm_running) == :running
      assert StateMachine.valid_transition?(sm_running, :paused)
      assert StateMachine.valid_transition?(sm_running, :stopped)

      sm_paused = %{sm_running | current_state: :paused}
      assert StateMachine.current_state(sm_paused) == :paused
      assert StateMachine.valid_transition?(sm_paused, :running)
      refute StateMachine.valid_transition?(sm_paused, :idle)

      sm_stopped = %{sm_paused | current_state: :stopped}
      assert StateMachine.current_state(sm_stopped) == :stopped
      assert StateMachine.valid_transition?(sm_stopped, :idle)
      refute StateMachine.valid_transition?(sm_stopped, :running)
    end
  end
end
