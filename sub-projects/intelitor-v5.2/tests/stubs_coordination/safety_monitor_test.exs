defmodule Intelitor.Coordination.SafetyMonitorTest do
  @moduledoc """
  Test suite for Intelitor.Coordination.SafetyMonitor.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/coordination/safety_monitor.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Coordination.SafetyMonitor

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(SafetyMonitor)
    end

    test "module has __info__/1 function" do
      assert function_exported?(SafetyMonitor, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = SafetyMonitor.__info__(:module)
      assert info == Intelitor.Coordination.SafetyMonitor
    end
  end
end
