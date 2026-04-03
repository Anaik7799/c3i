defmodule Indrajaal.ML.TelemetryTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.ML.Telemetry

  test "module is loaded" do
    assert Code.ensure_loaded?(Telemetry)
  end

  test "start_link/1 is defined" do
    assert function_exported?(Telemetry, :start_link, 1)
  end

  test "attach/0 is defined" do
    assert function_exported?(Telemetry, :attach, 0)
  end

  test "detach/0 is defined" do
    assert function_exported?(Telemetry, :detach, 0)
  end

  test "get_metrics/0 is defined" do
    assert function_exported?(Telemetry, :get_metrics, 0)
  end

  test "handle_event/4 is defined" do
    assert function_exported?(Telemetry, :handle_event, 4)
  end

  test "module uses GenServer behaviour" do
    behaviours = Telemetry.__info__(:attributes)[:behaviour] || []
    assert GenServer in behaviours
  end

  test "child_spec/1 is defined for supervision" do
    assert function_exported?(Telemetry, :child_spec, 1)
  end

  test "can start under a test supervisor" do
    name = :"test_ml_telemetry_#{System.unique_integer([:positive])}"
    assert {:ok, pid} = start_supervised({Telemetry, name: name})
    assert is_pid(pid)
    assert Process.alive?(pid)
  end
end
