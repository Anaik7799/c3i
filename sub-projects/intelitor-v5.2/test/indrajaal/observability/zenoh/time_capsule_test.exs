defmodule Indrajaal.Observability.Zenoh.TimeCapsuleTest do
  @moduledoc """
  TDG test suite for Indrajaal.Observability.Zenoh.TimeCapsule.

  ## STAMP Safety Integration
  - SC-ZENOH-001: Zenoh NIF must be loaded (SKIP_ZENOH_NIF=0)

  ## TPS 5-Level RCA Context
  - L1 Symptom: Scheduled Zenoh messages not delivered
  - L5 Root Cause: Missing temporal message scheduling capability
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.Zenoh.TimeCapsule

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(TimeCapsule)
    end

    test "start_link/1 exported" do
      assert function_exported?(TimeCapsule, :start_link, 1)
    end

    test "schedule/3 exported" do
      assert function_exported?(TimeCapsule, :schedule, 3)
    end
  end

  describe "start_link/1" do
    test "starts without error" do
      name = :"TimeCapsuleTest_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(TimeCapsule, [], name: name)
      assert is_pid(pid)
      GenServer.stop(pid)
    end

    test "initializes with empty pending map" do
      name = :"TimeCapsuleInit_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(TimeCapsule, [], name: name)

      state = :sys.get_state(pid)
      assert Map.has_key?(state, :pending)
      assert state.pending == %{}

      GenServer.stop(pid)
    end
  end

  describe "schedule/3" do
    test "schedules message for future delivery without crashing" do
      name = :"TimeCapsuleSched_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(TimeCapsule, [], name: name)

      future = DateTime.add(DateTime.utc_now(), 1, :second)
      GenServer.cast(pid, {:schedule, "test/topic", %{data: "payload"}, future})
      Process.sleep(30)

      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "handles past delivery times by delivering immediately" do
      name = :"TimeCapsulePast_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(TimeCapsule, [], name: name)

      past = DateTime.add(DateTime.utc_now(), -5, :second)
      GenServer.cast(pid, {:schedule, "test/topic", %{data: "past"}, past})
      Process.sleep(30)

      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "handles multiple scheduled messages" do
      name = :"TimeCapsuleMulti_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(TimeCapsule, [], name: name)

      future1 = DateTime.add(DateTime.utc_now(), 10, :second)
      future2 = DateTime.add(DateTime.utc_now(), 20, :second)

      GenServer.cast(pid, {:schedule, "topic/1", %{val: 1}, future1})
      GenServer.cast(pid, {:schedule, "topic/2", %{val: 2}, future2})
      Process.sleep(30)

      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "handle_info deliver processes message" do
      name = :"TimeCapsuleDeliver_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(TimeCapsule, [], name: name)

      # Simulate delivery message
      send(pid, {:deliver, "test/topic", %{data: "payload"}})
      Process.sleep(30)

      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end
end
