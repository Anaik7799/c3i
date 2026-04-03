defmodule Indrajaal.Integration.CortexBridgeTest do
  @moduledoc """
  TDG test suite for Indrajaal.Integration.CortexBridge.

  ## STAMP Safety Integration
  - SC-PRAJNA-004: Sentinel sync bridge operational

  ## TPS 5-Level RCA Context
  - L1 Symptom: Bridge not initializing
  - L5 Root Cause: GenServer lifecycle contract violation
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Integration.CortexBridge

  describe "module existence" do
    test "CortexBridge module is defined" do
      assert Code.ensure_loaded?(CortexBridge)
    end

    test "start_link/1 function exists" do
      assert function_exported?(CortexBridge, :start_link, 1)
    end

    test "trigger_analysis/0 function exists" do
      assert function_exported?(CortexBridge, :trigger_analysis, 0)
    end
  end

  describe "GenServer lifecycle" do
    setup do
      case GenServer.start_link(CortexBridge, [],
             name: :"cortex_bridge_test_#{:erlang.unique_integer([:positive])}"
           ) do
        {:ok, pid} ->
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
          %{pid: pid}

        {:error, {:already_started, pid}} ->
          %{pid: pid}
      end
    end

    test "starts successfully", %{pid: pid} do
      assert Process.alive?(pid)
    end
  end

  describe "trigger_analysis/0" do
    test "returns :ok" do
      # trigger_analysis/0 is a module-level function, always returns :ok
      result = CortexBridge.trigger_analysis()
      assert result == :ok
    end
  end
end
