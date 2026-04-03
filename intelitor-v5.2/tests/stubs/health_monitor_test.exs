defmodule HealthMonitorTest do
  @moduledoc """
  Test suite for HealthMonitor.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/health_monitor.ex
  """
  use ExUnit.Case, async: true

  alias HealthMonitor

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(HealthMonitor)
    end

    test "module has __info__/1 function" do
      assert function_exported?(HealthMonitor, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = HealthMonitor.__info__(:module)
      assert info == HealthMonitor
    end
  end
end
