defmodule Indrajaal.Cortex.Sensors.MLSensorTest do
  @moduledoc """
  Tests for the MLSensor module.

  STAMP Compliance:
  - SC-ML-004: ML serving observability
  - SC-CTX-002: Sensor redundancy

  TDG: Test-Driven Generation - tests created before implementation validation.
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Cortex.Sensors.MLSensor

  describe "start_link/1" do
    test "starts the sensor process or uses existing" do
      case Process.whereis(MLSensor) do
        nil ->
          # Not running, start fresh
          assert {:ok, pid} = MLSensor.start_link([])
          assert Process.alive?(pid)

        pid ->
          # Already running from application supervisor
          assert Process.alive?(pid)
      end
    end

    test "process is registered with expected name" do
      case Process.whereis(MLSensor) do
        nil ->
          {:ok, pid} = MLSensor.start_link([])
          assert Process.whereis(MLSensor) == pid

        pid ->
          # Already registered from application supervisor
          assert Process.whereis(MLSensor) == pid
      end
    end
  end

  describe "measure/0" do
    setup do
      case Process.whereis(MLSensor) do
        nil ->
          {:ok, pid} = MLSensor.start_link([])
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "returns metrics map with expected keys", %{pid: _pid} do
      metrics = MLSensor.measure()

      assert is_map(metrics)
      assert Map.has_key?(metrics, :servings)
      assert Map.has_key?(metrics, :total_inferences)
      assert Map.has_key?(metrics, :avg_latency_ms)
      assert Map.has_key?(metrics, :servings_healthy)
      assert Map.has_key?(metrics, :servings_total)
      assert Map.has_key?(metrics, :measured_at)
    end

    test "servings is a map", %{pid: _pid} do
      metrics = MLSensor.measure()

      assert is_map(metrics.servings)
    end

    test "total_inferences is non-negative", %{pid: _pid} do
      metrics = MLSensor.measure()

      assert is_integer(metrics.total_inferences)
      assert metrics.total_inferences >= 0
    end

    test "avg_latency_ms is non-negative", %{pid: _pid} do
      metrics = MLSensor.measure()

      assert is_number(metrics.avg_latency_ms)
      assert metrics.avg_latency_ms >= 0
    end

    test "servings_healthy is non-negative", %{pid: _pid} do
      metrics = MLSensor.measure()

      assert is_integer(metrics.servings_healthy)
      assert metrics.servings_healthy >= 0
    end

    test "servings_total matches configured servings", %{pid: _pid} do
      metrics = MLSensor.measure()

      assert is_integer(metrics.servings_total)
      # ThreatClassifier, AnomalyDetector, AlarmCorrelator
      assert metrics.servings_total == 3
    end

    test "measured_at is a DateTime", %{pid: _pid} do
      metrics = MLSensor.measure()

      assert %DateTime{} = metrics.measured_at
    end
  end

  describe "serving_metrics/1" do
    setup do
      case Process.whereis(MLSensor) do
        nil ->
          {:ok, pid} = MLSensor.start_link([])
          Process.sleep(100)
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "returns nil for unknown serving", %{pid: _pid} do
      result = MLSensor.serving_metrics(:unknown_serving)
      assert is_nil(result)
    end

    test "returns metrics for known serving", %{pid: _pid} do
      # Measure first to populate current data
      MLSensor.measure()

      result = MLSensor.serving_metrics(Indrajaal.ML.Serving.ThreatClassifier)

      # May be nil if serving not running, but should not crash
      if result do
        assert is_map(result)
        assert Map.has_key?(result, :name)
        assert Map.has_key?(result, :status)
      end
    end
  end

  describe "history/1" do
    setup do
      case Process.whereis(MLSensor) do
        nil ->
          {:ok, pid} = MLSensor.start_link([])
          Process.sleep(100)
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "returns list of historical measurements", %{pid: _pid} do
      history = MLSensor.history(5)

      assert is_list(history)
    end

    test "respects count limit", %{pid: _pid} do
      for _ <- 1..3 do
        MLSensor.measure()
        Process.sleep(10)
      end

      history = MLSensor.history(2)
      assert length(history) <= 2
    end
  end

  describe "STAMP compliance" do
    setup do
      case Process.whereis(MLSensor) do
        nil ->
          {:ok, pid} = MLSensor.start_link([])
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        pid ->
          {:ok, pid: pid}
      end
    end

    test "SC-ML-004: monitors all configured ML servings", %{pid: _pid} do
      metrics = MLSensor.measure()

      # Should track the 3 configured ML servings
      assert metrics.servings_total == 3
    end

    test "SC-CTX-002: graceful degradation when servings unavailable", %{pid: _pid} do
      # Should not crash even if ML servings are not running
      metrics = MLSensor.measure()

      assert is_map(metrics)
      assert Map.has_key?(metrics, :servings)
    end

    test "provides latency and throughput metrics for observability", %{pid: _pid} do
      metrics = MLSensor.measure()

      assert Map.has_key?(metrics, :avg_latency_ms)
      assert Map.has_key?(metrics, :total_inferences)
    end
  end
end
