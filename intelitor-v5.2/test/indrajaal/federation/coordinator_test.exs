defmodule Indrajaal.Federation.CoordinatorTest do
  @moduledoc """
  TDG Sprint 54: Module coverage tests for Indrajaal.Federation.Coordinator.
  Tests GenServer init contract and federation coordination API.
  STAMP: SC-SIL6-001 (mesh boot stages), SC-SIL6-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Federation.Coordinator

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Coordinator)
    end

    test "implements GenServer behaviour" do
      assert function_exported?(Coordinator, :start_link, 1)
      assert function_exported?(Coordinator, :init, 1)
    end
  end

  describe "public API surface" do
    test "exports register_node/2" do
      assert function_exported?(Coordinator, :register_node, 2)
    end

    test "exports unregister_node/1" do
      assert function_exported?(Coordinator, :unregister_node, 1)
    end

    test "exports status/0" do
      assert function_exported?(Coordinator, :status, 0)
    end

    test "exports broadcast/1" do
      assert function_exported?(Coordinator, :broadcast, 1)
    end

    test "exports enter_emergency/1" do
      assert function_exported?(Coordinator, :enter_emergency, 1)
    end

    test "exports exit_emergency/0" do
      assert function_exported?(Coordinator, :exit_emergency, 0)
    end

    test "exports health_report/0" do
      assert function_exported?(Coordinator, :health_report, 0)
    end
  end

  describe "start_link/1 contract" do
    test "starts GenServer with empty opts" do
      {:ok, pid} = start_supervised({Coordinator, []})
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "initial state is a map" do
      {:ok, pid} = start_supervised({Coordinator, []})
      state = :sys.get_state(pid)
      assert is_map(state)
    end
  end

  describe "child_spec/1" do
    test "returns valid child spec" do
      spec = Coordinator.child_spec([])
      assert is_map(spec)
      assert Map.has_key?(spec, :id)
    end
  end
end
