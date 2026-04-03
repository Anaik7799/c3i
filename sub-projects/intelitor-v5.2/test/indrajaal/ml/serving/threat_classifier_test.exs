defmodule Indrajaal.ML.Serving.ThreatClassifierTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.ML.Serving.ThreatClassifier

  test "module is loaded" do
    assert Code.ensure_loaded?(ThreatClassifier)
  end

  test "start_link/1 is defined" do
    assert function_exported?(ThreatClassifier, :start_link, 1)
  end

  test "classify/2 is defined" do
    assert function_exported?(ThreatClassifier, :classify, 2)
  end

  test "classify_batch/2 is defined" do
    assert function_exported?(ThreatClassifier, :classify_batch, 2)
  end

  test "classify_via_flame/1 is defined" do
    assert function_exported?(ThreatClassifier, :classify_via_flame, 1)
  end

  test "module uses GenServer behaviour" do
    behaviours = ThreatClassifier.__info__(:attributes)[:behaviour] || []
    assert GenServer in behaviours
  end

  test "child_spec/1 is defined for supervision" do
    assert function_exported?(ThreatClassifier, :child_spec, 1)
  end

  test "can start under a test supervisor" do
    name = :"test_threat_classifier_#{System.unique_integer([:positive])}"
    assert {:ok, pid} = start_supervised({ThreatClassifier, name: name})
    assert is_pid(pid)
    assert Process.alive?(pid)
  end
end
