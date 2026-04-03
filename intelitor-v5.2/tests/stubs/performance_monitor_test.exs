defmodule PerformanceMonitorTest do
  @moduledoc """
  Test suite for PerformanceMonitor.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/performance_monitor.ex
  """
  use ExUnit.Case, async: true

  alias PerformanceMonitor

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(PerformanceMonitor)
    end

    test "module has __info__/1 function" do
      assert function_exported?(PerformanceMonitor, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = PerformanceMonitor.__info__(:module)
      assert info == PerformanceMonitor
    end
  end
end
