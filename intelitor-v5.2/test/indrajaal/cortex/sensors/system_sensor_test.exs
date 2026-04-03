defmodule Indrajaal.Cortex.Sensors.SystemSensorTest do
  @moduledoc """
  Tests for the SystemSensor module.

  STAMP Compliance:
  - SC-CTX-002: Sensor redundancy
  - SC-OBS-065: System metrics observability

  TDG: Test-Driven Generation - tests created before implementation validation.
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Cortex.Sensors.SystemSensor

  describe "start_link/1" do
    test "starts the sensor process or uses existing" do
      case Process.whereis(SystemSensor) do
        nil ->
          # Not running, start fresh
          assert {:ok, pid} = SystemSensor.start_link([])
          assert Process.alive?(pid)

        pid ->
          # Already running from application supervisor
          assert Process.alive?(pid)
      end
    end

    test "process is registered with expected name" do
      case Process.whereis(SystemSensor) do
        nil ->
          {:ok, pid} = SystemSensor.start_link([])
          assert Process.whereis(SystemSensor) == pid

        pid ->
          # Already registered from application supervisor
          assert Process.whereis(SystemSensor) == pid
      end
    end
  end

  describe "measure/0" do
    setup do
      # Ensure sensor is running
      case Process.whereis(SystemSensor) do
        nil ->
          {:ok, pid} = SystemSensor.start_link([])
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "returns metrics map with expected keys", %{pid: _pid} do
      metrics = SystemSensor.measure()

      assert is_map(metrics)
      assert Map.has_key?(metrics, :memory_usage)
      assert Map.has_key?(metrics, :cpu_usage)
      assert Map.has_key?(metrics, :run_queue)
      assert Map.has_key?(metrics, :process_count)
      assert Map.has_key?(metrics, :measured_at)
    end

    test "memory_usage is between 0 and 1", %{pid: _pid} do
      metrics = SystemSensor.measure()

      assert is_number(metrics.memory_usage)
      assert metrics.memory_usage >= 0.0
      assert metrics.memory_usage <= 1.0
    end

    test "cpu_usage is between 0 and 1", %{pid: _pid} do
      metrics = SystemSensor.measure()

      assert is_number(metrics.cpu_usage)
      assert metrics.cpu_usage >= 0.0
      assert metrics.cpu_usage <= 1.0
    end

    test "run_queue is non-negative", %{pid: _pid} do
      metrics = SystemSensor.measure()

      assert is_integer(metrics.run_queue)
      assert metrics.run_queue >= 0
    end

    test "process_count is positive", %{pid: _pid} do
      metrics = SystemSensor.measure()

      assert is_integer(metrics.process_count)
      assert metrics.process_count > 0
    end

    test "measured_at is a DateTime", %{pid: _pid} do
      metrics = SystemSensor.measure()

      assert %DateTime{} = metrics.measured_at
    end

    test "includes memory metrics", %{pid: _pid} do
      metrics = SystemSensor.measure()

      # Memory metrics are at top level, not nested
      assert Map.has_key?(metrics, :memory_total)
      assert Map.has_key?(metrics, :memory_processes)
      assert Map.has_key?(metrics, :memory_ets)
      assert Map.has_key?(metrics, :memory_binary)
      assert Map.has_key?(metrics, :memory_atom)
      assert metrics.memory_total > 0
    end

    test "includes scheduler metrics", %{pid: _pid} do
      metrics = SystemSensor.measure()

      assert Map.has_key?(metrics, :schedulers_online)
      assert metrics.schedulers_online > 0
    end
  end

  describe "history/1" do
    setup do
      case Process.whereis(SystemSensor) do
        nil ->
          {:ok, pid} = SystemSensor.start_link([])
          # Allow initial measurement
          Process.sleep(100)
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "returns list of historical measurements", %{pid: _pid} do
      history = SystemSensor.history(5)

      assert is_list(history)
    end

    test "respects count limit", %{pid: _pid} do
      # Take some measurements
      for _ <- 1..3 do
        SystemSensor.measure()
        Process.sleep(10)
      end

      history = SystemSensor.history(2)
      assert length(history) <= 2
    end

    test "historical entries have timestamps", %{pid: _pid} do
      SystemSensor.measure()
      Process.sleep(10)

      history = SystemSensor.history(1)

      if length(history) > 0 do
        [entry | _] = history
        assert Map.has_key?(entry, :measured_at)
      end
    end
  end

  describe "STAMP compliance" do
    setup do
      case Process.whereis(SystemSensor) do
        nil ->
          {:ok, pid} = SystemSensor.start_link([])
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "SC-CTX-002: sensor provides continuous metrics", %{pid: _pid} do
      # Take multiple measurements
      metrics1 = SystemSensor.measure()
      Process.sleep(50)
      metrics2 = SystemSensor.measure()

      # Both should return valid data
      assert is_map(metrics1)
      assert is_map(metrics2)
      assert metrics1.measured_at != metrics2.measured_at
    end

    test "SC-OBS-065: metrics are observable and complete", %{pid: _pid} do
      metrics = SystemSensor.measure()

      # All critical system metrics should be present
      required_keys = [:memory_usage, :cpu_usage, :run_queue, :process_count]

      for key <- required_keys do
        assert Map.has_key?(metrics, key),
               "Missing required metric: #{key}"
      end
    end
  end
end
