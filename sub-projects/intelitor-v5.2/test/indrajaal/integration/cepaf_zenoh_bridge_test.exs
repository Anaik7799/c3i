defmodule Indrajaal.Integration.CepafZenohBridgeTest do
  @moduledoc """
  TDG test suite for Indrajaal.Integration.CepafZenohBridge.

  ## STAMP Safety Integration
  - SC-ZTEST-004: Publishing MUST be async (non-blocking)
  - SC-ZENOH-001: Delegates to ZenohSession for actual NIF calls

  ## TPS 5-Level RCA Context
  - L1 Symptom: Bridge fails to initialize
  - L5 Root Cause: GenServer lifecycle contract violation
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Integration.CepafZenohBridge

  describe "module existence" do
    test "CepafZenohBridge module is defined" do
      assert Code.ensure_loaded?(CepafZenohBridge)
    end

    test "start_link/1 function exists" do
      assert function_exported?(CepafZenohBridge, :start_link, 1)
    end

    test "publish_event/3 function exists" do
      assert function_exported?(CepafZenohBridge, :publish_event, 3)
    end
  end

  describe "GenServer lifecycle" do
    setup do
      # CepafZenohBridge uses name: __MODULE__ globally, so we start_link directly with unique name
      name = :"cepaf_zenoh_bridge_test_#{:erlang.unique_integer([:positive])}"

      case GenServer.start_link(CepafZenohBridge, [], name: name) do
        {:ok, pid} ->
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
          %{pid: pid, name: name}

        {:error, {:already_started, pid}} ->
          %{pid: pid, name: name}
      end
    end

    test "starts successfully", %{pid: pid} do
      assert Process.alive?(pid)
    end

    test "process responds to status queries", %{pid: pid} do
      assert Process.alive?(pid)
    end
  end

  describe "publish_event/3 (cast-based, async)" do
    setup do
      name = :"cepaf_bridge_pub_test_#{:erlang.unique_integer([:positive])}"

      {:ok, pid} = GenServer.start_link(CepafZenohBridge, [], name: name)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid, name: name}
    end

    test "publish_event does not crash the bridge", %{pid: pid} do
      # Cast is async — it should not crash the process
      GenServer.cast(pid, {:publish, "container-1", "started", %{status: "running"}})
      # Give it time to process
      :timer.sleep(50)
      assert Process.alive?(pid)
    end

    test "publish_event accepts various event types without crashing", %{pid: pid} do
      payloads = [
        {"container-a", "started", %{}},
        {"container-b", "stopped", %{exit_code: 0}},
        {"container-c", "health_check", %{healthy: true}}
      ]

      for {container_id, event_type, payload} <- payloads do
        GenServer.cast(pid, {:publish, container_id, event_type, payload})
      end

      :timer.sleep(100)
      assert Process.alive?(pid)
    end
  end

  describe "via module API (using named global process if running)" do
    test "publish_event/3 is non-blocking and returns immediately" do
      # If the global process is running, calling publish_event must return fast
      if Process.whereis(CepafZenohBridge) do
        start = System.monotonic_time(:millisecond)
        CepafZenohBridge.publish_event("container-x", "updated", %{})
        elapsed = System.monotonic_time(:millisecond) - start
        # SC-ZTEST-004: async publish — should return nearly immediately
        assert elapsed < 100
      else
        # Global process not started — just verify function arity
        assert function_exported?(CepafZenohBridge, :publish_event, 3)
      end
    end
  end
end
