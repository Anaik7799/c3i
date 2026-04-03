defmodule PerformanceMonitorTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  test "module exists" do
    assert Code.ensure_loaded?(PerformanceMonitor)
  end

  test "placeholder/0 is exported" do
    assert function_exported?(PerformanceMonitor, :placeholder, 0)
  end

  test "placeholder/0 returns :ok" do
    assert :ok = PerformanceMonitor.placeholder()
  end
end
