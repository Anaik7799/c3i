defmodule Indrajaal.MetricsCollectorTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.MetricsCollector

  test "module exists" do
    assert Code.ensure_loaded?(MetricsCollector)
  end

  test "get_metrics_for_module/2 is exported" do
    assert function_exported?(MetricsCollector, :get_metrics_for_module, 2)
  end

  test "record_auth_failure/1 is exported" do
    assert function_exported?(MetricsCollector, :record_auth_failure, 1)
  end

  test "get_metrics_for_module/2 returns ok tuple" do
    assert {:ok, _} = MetricsCollector.get_metrics_for_module(MetricsCollector, [])
  end

  test "record_auth_failure/1 returns :ok" do
    assert :ok = MetricsCollector.record_auth_failure("user-123")
  end
end
