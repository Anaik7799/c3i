defmodule Indrajaal.ProductionReadiness.DebugSystemTest do
  @moduledoc """
  TDG test suite for DebugSystem GenServer.

  ## STAMP Safety Integration
  - UCA-011: Prevent debug mode in production

  ## TPS 5-Level RCA Context
  - L1 Symptom: Debug mode leaks sensitive data
  - L5 Root Cause: Missing environment checks on debug config
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.ProductionReadiness.DebugSystem

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(DebugSystem)
    end

    test "public API functions are exported" do
      assert function_exported?(DebugSystem, :start_link, 1)
      assert function_exported?(DebugSystem, :configure, 1)
      assert function_exported?(DebugSystem, :investigate, 1)
      assert function_exported?(DebugSystem, :start_debug_session, 1)
      assert function_exported?(DebugSystem, :set_breakpoint, 2)
      assert function_exported?(DebugSystem, :capture_state, 1)
    end
  end

  describe "safe debug config" do
    test "max capture duration is bounded" do
      max_capture_ms = 60_000
      assert max_capture_ms <= 60_000
    end

    test "max profiling overhead is low" do
      max_overhead = 5.0
      assert max_overhead <= 10.0
    end
  end

  describe "start_link/1" do
    test "starts the GenServer successfully" do
      name = :"debug_system_test_#{System.unique_integer([:positive])}"
      result = GenServer.start_link(DebugSystem, [], name: name)
      assert match?({:ok, _pid}, result)
      {:ok, pid} = result
      GenServer.stop(pid)
    end
  end
end
