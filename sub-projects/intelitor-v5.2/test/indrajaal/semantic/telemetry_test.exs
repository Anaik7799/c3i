defmodule Indrajaal.Semantic.TelemetryTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Semantic.Telemetry

  test "module exists" do
    assert Code.ensure_loaded?(Telemetry)
  end

  test "attach_handlers/0 is exported" do
    assert function_exported?(Telemetry, :attach_handlers, 0)
  end

  test "detach_handlers/0 is exported" do
    assert function_exported?(Telemetry, :detach_handlers, 0)
  end

  test "get_metrics/0 is exported" do
    assert function_exported?(Telemetry, :get_metrics, 0)
  end

  test "publish_metrics/0 is exported" do
    assert function_exported?(Telemetry, :publish_metrics, 0)
  end

  test "dashboard_data/0 is exported" do
    assert function_exported?(Telemetry, :dashboard_data, 0)
  end

  test "get_metrics/0 returns map with expected keys" do
    metrics = Telemetry.get_metrics()
    assert is_map(metrics)
    assert Map.has_key?(metrics, :bridge)
    assert Map.has_key?(metrics, :operations)
    assert Map.has_key?(metrics, :performance)
    assert Map.has_key?(metrics, :health)
  end

  test "dashboard_data/0 returns map with expected keys" do
    data = Telemetry.dashboard_data()
    assert is_map(data)
    assert Map.has_key?(data, :title)
    assert Map.has_key?(data, :status)
    assert Map.has_key?(data, :kpis)
  end
end
