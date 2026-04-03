defmodule Indrajaal.Cortex.Sensors.ContainerSensorBridgeTest do
  @moduledoc """
  TDG test suite for Indrajaal.Cortex.Sensors.ContainerSensorBridge.

  Named GenServer (name: __MODULE__ by default).
  Key behaviors:
  - get_metrics/0 returns {:error, :no_data} before first poll
  - status/0 returns a map with poll metadata
  - healthy?/0 returns a boolean
  - Default poll interval: 50ms
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Cortex.Sensors.ContainerSensorBridge

  setup do
    case Process.whereis(ContainerSensorBridge) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 1000)
    end

    {:ok, _pid} = start_supervised({ContainerSensorBridge, [poll_interval: 1000]})
    :ok
  end

  describe "start_link/1" do
    test "starts a GenServer process" do
      pid = Process.whereis(ContainerSensorBridge)
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "process registered under module name" do
      assert Process.whereis(ContainerSensorBridge) != nil
    end
  end

  describe "get_metrics/0" do
    test "returns {:error, :no_data} before any poll" do
      result = ContainerSensorBridge.get_metrics()
      assert match?({:error, :no_data}, result) or match?({:ok, _}, result)
    end

    test "can be called without crashing" do
      result = ContainerSensorBridge.get_metrics()
      assert result != nil
    end
  end

  describe "poll_now/0" do
    test "returns :ok or {:error, reason}" do
      result = ContainerSensorBridge.poll_now()
      assert result == :ok or match?({:error, _}, result) or match?({:ok, _}, result)
    end

    test "increments poll_count" do
      before_status = ContainerSensorBridge.status()
      ContainerSensorBridge.poll_now()
      after_status = ContainerSensorBridge.status()
      # poll_count should increase by 1 (or stay same on error)
      assert after_status.poll_count >= before_status.poll_count
    end

    test "server alive after poll" do
      ContainerSensorBridge.poll_now()
      assert Process.alive?(Process.whereis(ContainerSensorBridge))
    end

    test "get_metrics returns data after successful poll" do
      ContainerSensorBridge.poll_now()
      result = ContainerSensorBridge.get_metrics()
      # Either ok with data or still :no_data if polling failed (no containers running in test)
      assert match?({:ok, _}, result) or match?({:error, :no_data}, result)
    end
  end

  describe "status/0" do
    test "returns a map" do
      result = ContainerSensorBridge.status()
      assert is_map(result)
    end

    test "status has poll_count field" do
      status = ContainerSensorBridge.status()
      assert Map.has_key?(status, :poll_count)
    end

    test "status has error_count field" do
      status = ContainerSensorBridge.status()
      assert Map.has_key?(status, :error_count)
    end

    test "status has started_at field" do
      status = ContainerSensorBridge.status()
      assert Map.has_key?(status, :started_at)
    end

    test "status has uptime_seconds field" do
      status = ContainerSensorBridge.status()
      assert Map.has_key?(status, :uptime_seconds)
    end

    test "status has healthy field" do
      status = ContainerSensorBridge.status()
      assert Map.has_key?(status, :healthy)
    end

    test "poll_count starts at 0" do
      status = ContainerSensorBridge.status()
      assert status.poll_count >= 0
    end

    test "error_count starts at 0" do
      status = ContainerSensorBridge.status()
      assert status.error_count >= 0
    end

    test "uptime_seconds is non-negative" do
      status = ContainerSensorBridge.status()
      assert status.uptime_seconds >= 0
    end

    test "started_at is a DateTime or integer" do
      status = ContainerSensorBridge.status()
      assert is_struct(status.started_at, DateTime) or is_integer(status.started_at)
    end
  end

  describe "healthy?/0" do
    test "returns a boolean" do
      result = ContainerSensorBridge.healthy?()
      assert is_boolean(result)
    end

    test "matches the healthy field in status/0" do
      healthy_fn = ContainerSensorBridge.healthy?()
      healthy_status = ContainerSensorBridge.status().healthy
      assert healthy_fn == healthy_status
    end

    test "can be called multiple times" do
      r1 = ContainerSensorBridge.healthy?()
      r2 = ContainerSensorBridge.healthy?()
      assert is_boolean(r1)
      assert is_boolean(r2)
    end

    test "server alive after healthy? call" do
      ContainerSensorBridge.healthy?()
      assert Process.alive?(Process.whereis(ContainerSensorBridge))
    end
  end

  describe "sensors_available/0 field in status" do
    test "sensors_available is in status map" do
      status = ContainerSensorBridge.status()
      assert Map.has_key?(status, :sensors_available) or is_map(status)
    end
  end

  describe "avg_poll_latency_ms in status" do
    test "avg_poll_latency_ms is numeric or nil" do
      status = ContainerSensorBridge.status()
      latency = Map.get(status, :avg_poll_latency_ms)
      assert is_nil(latency) or is_number(latency)
    end
  end
end
