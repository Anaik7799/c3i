defmodule Indrajaal.Cortex.DigitalTwinTest do
  @moduledoc """
  TDG Sprint 54: Module coverage tests for Indrajaal.Cortex.DigitalTwin.
  Tests GenServer start_link/init contract and public API.
  STAMP: SC-CHAYA-001, SC-GDE-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cortex.DigitalTwin

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(DigitalTwin)
    end

    test "module implements GenServer behaviour" do
      assert function_exported?(DigitalTwin, :start_link, 1)
      assert function_exported?(DigitalTwin, :init, 1)
    end

    test "module exports get_state/0" do
      assert function_exported?(DigitalTwin, :get_state, 0)
    end

    test "module exports update_component/3" do
      assert function_exported?(DigitalTwin, :update_component, 3)
    end
  end

  describe "start_link/1 contract" do
    test "start_link accepts opts list" do
      {:ok, pid} = start_supervised({DigitalTwin, []})
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "started process is a GenServer" do
      {:ok, pid} = start_supervised({DigitalTwin, []})
      assert :sys.get_state(pid) |> is_map()
    end
  end

  describe "get_state/0" do
    test "returns a map when server is running" do
      start_supervised!({DigitalTwin, []})
      # Use GenServer call via registered name pattern
      state = DigitalTwin.get_state()
      assert is_map(state)
    end
  end

  describe "child_spec/1" do
    test "returns valid child spec" do
      spec = DigitalTwin.child_spec([])
      assert is_map(spec)
      assert Map.has_key?(spec, :id)
      assert Map.has_key?(spec, :start)
    end
  end
end
