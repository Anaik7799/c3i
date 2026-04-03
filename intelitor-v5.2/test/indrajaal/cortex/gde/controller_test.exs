defmodule Indrajaal.Cortex.GDE.ControllerTest do
  @moduledoc """
  TDG Sprint 54: Module coverage tests for Indrajaal.Cortex.GDE.Controller.
  Tests GenServer init contract and public API shape.
  STAMP: SC-GDE-001 (Guardian validation), SC-GDE-002 (Shadow testing)
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cortex.GDE.Controller

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Controller)
    end

    test "module implements GenServer behaviour" do
      assert function_exported?(Controller, :start_link, 1)
      assert function_exported?(Controller, :init, 1)
    end
  end

  describe "public API surface" do
    test "exports define_goal/3" do
      assert function_exported?(Controller, :define_goal, 3)
    end

    test "exports activate_goal/1" do
      assert function_exported?(Controller, :activate_goal, 1)
    end

    test "exports goal_status/1" do
      assert function_exported?(Controller, :goal_status, 1)
    end

    test "exports list_goals/1" do
      assert function_exported?(Controller, :list_goals, 1)
    end

    test "exports abandon_goal/2" do
      assert function_exported?(Controller, :abandon_goal, 2)
    end

    test "exports set_strategy/1" do
      assert function_exported?(Controller, :set_strategy, 1)
    end

    test "exports get_strategy/0" do
      assert function_exported?(Controller, :get_strategy, 0)
    end

    test "exports pending_changes/0" do
      assert function_exported?(Controller, :pending_changes, 0)
    end

    test "exports trigger_evolution/0" do
      assert function_exported?(Controller, :trigger_evolution, 0)
    end

    test "exports metrics/0" do
      assert function_exported?(Controller, :metrics, 0)
    end

    test "exports status/0" do
      assert function_exported?(Controller, :status, 0)
    end
  end

  describe "start_link/1 contract" do
    test "start_link accepts opts list and starts process" do
      {:ok, pid} = start_supervised({Controller, []})
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "initial state is a map" do
      {:ok, pid} = start_supervised({Controller, []})
      state = :sys.get_state(pid)
      assert is_map(state)
    end
  end

  describe "child_spec/1" do
    test "returns valid child spec" do
      spec = Controller.child_spec([])
      assert is_map(spec)
      assert Map.has_key?(spec, :id)
      assert Map.has_key?(spec, :start)
    end
  end
end
