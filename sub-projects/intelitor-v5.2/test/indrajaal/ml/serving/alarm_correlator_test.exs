defmodule Indrajaal.ML.Serving.AlarmCorrelatorTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.ML.Serving.AlarmCorrelator

  test "module is loaded" do
    assert Code.ensure_loaded?(AlarmCorrelator)
  end

  test "start_link/1 is defined" do
    assert function_exported?(AlarmCorrelator, :start_link, 1)
  end

  test "correlate/3 is defined" do
    assert function_exported?(AlarmCorrelator, :correlate, 3)
  end

  test "cluster_alarms/2 is defined" do
    assert function_exported?(AlarmCorrelator, :cluster_alarms, 2)
  end

  test "correlate_via_flame/1 is defined" do
    assert function_exported?(AlarmCorrelator, :correlate_via_flame, 1)
  end

  test "text_similarity/2 is defined" do
    assert function_exported?(AlarmCorrelator, :text_similarity, 2)
  end

  test "module uses GenServer behaviour" do
    behaviours = AlarmCorrelator.__info__(:attributes)[:behaviour] || []
    assert GenServer in behaviours
  end

  test "child_spec/1 is defined for supervision" do
    assert function_exported?(AlarmCorrelator, :child_spec, 1)
  end

  test "can start under a test supervisor" do
    name = :"test_alarm_correlator_#{System.unique_integer([:positive])}"
    assert {:ok, pid} = start_supervised({AlarmCorrelator, name: name})
    assert is_pid(pid)
    assert Process.alive?(pid)
  end
end
