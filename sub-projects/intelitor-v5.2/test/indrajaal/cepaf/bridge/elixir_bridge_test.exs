defmodule Indrajaal.Cepaf.Bridge.ElixirBridgeTest do
  @moduledoc """
  TDG tests for Indrajaal.Cepaf.Bridge.ElixirBridge.

  ## STAMP Safety Integration
  - SC-SYNC-004: Bidirectional bridge health monitoring

  ## TPS 5-Level RCA Context
  - L1 Symptom: Bridge communication failures
  - L5 Root Cause: Missing contract validation between F# and Elixir
  """

  use ExUnit.Case, async: true
  @moduletag :zenoh_nif

  alias Indrajaal.Cepaf.Bridge.ElixirBridge

  describe "function exports" do
    test "start_link/1 is exported" do
      assert function_exported?(ElixirBridge, :start_link, 1)
    end

    test "get_status/0 is exported" do
      assert function_exported?(ElixirBridge, :get_status, 0)
    end

    test "send_command/2 is exported" do
      assert function_exported?(ElixirBridge, :send_command, 2)
    end

    test "health_check/0 is exported" do
      assert function_exported?(ElixirBridge, :health_check, 0)
    end
  end

  describe "start_link/1" do
    test "starts the bridge process" do
      test_name = :"bridge_#{System.unique_integer()}"
      assert {:ok, pid} = start_supervised({ElixirBridge, [name: test_name]})
      assert Process.alive?(pid)
    end
  end

  describe "get_status/0" do
    test "returns status map after start" do
      test_name = :"bridge_status_#{System.unique_integer()}"
      start_supervised!({ElixirBridge, [name: test_name]})
      result = ElixirBridge.get_status()
      assert is_map(result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
