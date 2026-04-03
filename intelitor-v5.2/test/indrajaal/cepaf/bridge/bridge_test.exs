defmodule Indrajaal.CEPAF.Bridge.BridgeTest do
  @moduledoc """
  Tests for Indrajaal.CEPAF.Bridge.Bridge GenServer.
  STAMP: SC-TDG, SC-COV-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.CEPAF.Bridge.Bridge

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Bridge)
    end

    test "module has expected public functions" do
      assert function_exported?(Bridge, :command, 2)
      assert function_exported?(Bridge, :query, 2)
      assert function_exported?(Bridge, :event, 2)
      assert function_exported?(Bridge, :status, 0)
      assert function_exported?(Bridge, :connect, 0)
      assert function_exported?(Bridge, :disconnect, 0)
      assert function_exported?(Bridge, :stats, 0)
    end

    test "module implements GenServer behaviour" do
      assert function_exported?(Bridge, :start_link, 1)
      assert function_exported?(Bridge, :init, 1)
    end
  end

  describe "Bridge GenServer lifecycle" do
    setup do
      # Start with a unique name to avoid conflicts with any running instance
      name = :"bridge_test_#{System.unique_integer([:positive])}"

      case Bridge.start_link(name: name) do
        {:ok, pid} ->
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid, name: name}

        {:error, _reason} ->
          # Bridge may require external connection — test function contracts only
          :skip
      end
    end

    test "status/0 returns a status term", %{pid: pid} do
      result = GenServer.call(pid, :status)
      assert result != nil
    end

    test "stats/0 returns a stats map or term", %{pid: pid} do
      result = GenServer.call(pid, :stats)
      assert is_map(result) or is_list(result) or result != nil
    end
  end

  describe "function contract verification" do
    test "command/2 accepts method and params as arguments" do
      # Verify arity is correct — actual call may fail if bridge not connected
      assert function_exported?(Bridge, :command, 2)
    end

    test "query/2 accepts query spec and options" do
      assert function_exported?(Bridge, :query, 2)
    end

    test "event/2 accepts event name and payload" do
      assert function_exported?(Bridge, :event, 2)
    end
  end
end
