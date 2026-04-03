defmodule Indrajaal.ProductionReadiness.ControlActionExecutorTest do
  @moduledoc """
  TDG test suite for ControlActionExecutor GenServer.

  ## STAMP Safety Integration
  - SC-010: Performance adjustments must not cause instability
  - UCA-008: Prevent resource exhaustion from scaling

  ## TPS 5-Level RCA Context
  - L1 Symptom: Control actions exceed resource limits
  - L5 Root Cause: Missing safety validation on scaling operations
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.ProductionReadiness.ControlActionExecutor

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(ControlActionExecutor)
    end

    test "public API functions are defined" do
      assert function_exported?(ControlActionExecutor, :start_link, 1)
      assert function_exported?(ControlActionExecutor, :execute, 1)
      assert function_exported?(ControlActionExecutor, :get_resource_usage, 0)
      assert function_exported?(ControlActionExecutor, :rollback, 1)
    end
  end

  describe "start_link/1" do
    test "starts the GenServer with default config" do
      name = :"control_executor_test_#{System.unique_integer([:positive])}"
      result = GenServer.start_link(ControlActionExecutor, %{}, name: name)
      assert match?({:ok, _pid}, result)
      {:ok, pid} = result
      GenServer.stop(pid)
    end
  end

  describe "execute/1 without valid state" do
    test "returns error for empty actions list when not started" do
      # When process not running, call returns error
      result = catch_exit(ControlActionExecutor.execute([]))
      # Should raise or return error - exit is expected when process not running
      assert result != nil
    end
  end

  describe "start_link with custom config" do
    test "accepts custom resource limits" do
      name = :"control_executor_custom_#{System.unique_integer([:positive])}"

      result =
        GenServer.start_link(ControlActionExecutor, %{max_total_memory_gb: 8}, name: name)

      assert match?({:ok, _pid}, result)
      {:ok, pid} = result
      GenServer.stop(pid)
    end
  end
end
