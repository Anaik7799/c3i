defmodule Indrajaal.ML.Serving.AnomalyDetectorTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.ML.Serving.AnomalyDetector

  test "module is loaded" do
    assert Code.ensure_loaded?(AnomalyDetector)
  end

  test "start_link/1 is defined" do
    assert function_exported?(AnomalyDetector, :start_link, 1)
  end

  test "detect/2 is defined" do
    assert function_exported?(AnomalyDetector, :detect, 2)
  end

  test "detect_via_flame/2 is defined" do
    assert function_exported?(AnomalyDetector, :detect_via_flame, 2)
  end

  test "check_realtime/2 is defined" do
    assert function_exported?(AnomalyDetector, :check_realtime, 2)
  end

  test "get_stats/0 is defined" do
    assert function_exported?(AnomalyDetector, :get_stats, 0)
  end

  test "module uses GenServer behaviour" do
    behaviours = AnomalyDetector.__info__(:attributes)[:behaviour] || []
    assert GenServer in behaviours
  end

  test "child_spec/1 is defined for supervision" do
    assert function_exported?(AnomalyDetector, :child_spec, 1)
  end

  test "can start under a test supervisor" do
    name = :"test_anomaly_detector_#{System.unique_integer([:positive])}"
    assert {:ok, pid} = start_supervised({AnomalyDetector, name: name})
    assert is_pid(pid)
    assert Process.alive?(pid)
  end
end
