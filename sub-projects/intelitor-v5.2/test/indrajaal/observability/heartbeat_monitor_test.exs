defmodule Indrajaal.Observability.HeartbeatMonitorTest do
  @moduledoc """
  TDG test suite for Indrajaal.Observability.HeartbeatMonitor.

  ## STAMP Safety Integration
  - SC-SIL6-005: Symbiotic Binding - heartbeat monitoring critical

  ## TPS 5-Level RCA Context
  - L1 Symptom: Missed heartbeats undetected
  - L5 Root Cause: Arrhythmia goes undetected leading to asystole
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.HeartbeatMonitor

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(HeartbeatMonitor)
    end

    test "start_link/1 exported" do
      assert function_exported?(HeartbeatMonitor, :start_link, 1)
    end

    test "record_pulse/1 exported" do
      assert function_exported?(HeartbeatMonitor, :record_pulse, 1)
    end
  end

  describe "start_link/1" do
    test "starts without error" do
      name = :"HeartbeatMonitor_#{System.unique_integer([:positive])}"
      {:ok, pid} = start_supervised!({HeartbeatMonitor, [name: name]})
      assert is_pid(pid)
    end

    test "initializes with timestamp state for all planes" do
      name = :"HeartbeatInit_#{System.unique_integer([:positive])}"
      {:ok, pid} = HeartbeatMonitor.start_link(name: name)

      state = :sys.get_state(pid)
      assert Map.has_key?(state, :data_plane)
      assert Map.has_key?(state, :state_plane)
      assert Map.has_key?(state, :log_plane)

      GenServer.stop(pid)
    end
  end

  describe "record_pulse/1" do
    test "records pulse for data_plane without crashing" do
      name = :"HeartbeatPulse_#{System.unique_integer([:positive])}"
      {:ok, pid} = HeartbeatMonitor.start_link(name: name)

      # Cast is fire-and-forget
      GenServer.cast(pid, {:record_pulse, :data_plane})
      Process.sleep(20)

      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "records pulse for state_plane" do
      name = :"HeartbeatState_#{System.unique_integer([:positive])}"
      {:ok, pid} = HeartbeatMonitor.start_link(name: name)

      GenServer.cast(pid, {:record_pulse, :state_plane})
      Process.sleep(20)

      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "records pulse for log_plane" do
      name = :"HeartbeatLog_#{System.unique_integer([:positive])}"
      {:ok, pid} = HeartbeatMonitor.start_link(name: name)

      GenServer.cast(pid, {:record_pulse, :log_plane})
      Process.sleep(20)

      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "multiple pulses update history" do
      name = :"HeartbeatMulti_#{System.unique_integer([:positive])}"
      {:ok, pid} = HeartbeatMonitor.start_link(name: name)

      GenServer.cast(pid, {:record_pulse, :data_plane})
      GenServer.cast(pid, {:record_pulse, :data_plane})
      Process.sleep(50)

      state = :sys.get_state(pid)
      {_last_seen, history} = state.data_plane
      assert length(history) >= 1

      GenServer.stop(pid)
    end
  end
end
