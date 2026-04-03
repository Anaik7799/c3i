defmodule Indrajaal.HealthMonitorTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.HealthMonitor

  test "module exists" do
    assert Code.ensure_loaded?(HealthMonitor)
  end

  test "status/0 is exported" do
    assert function_exported?(HealthMonitor, :status, 0)
  end

  test "healthy?/1 is exported" do
    assert function_exported?(HealthMonitor, :healthy?, 1)
  end

  test "all_components/0 is exported" do
    assert function_exported?(HealthMonitor, :all_components, 0)
  end
end
