defmodule Intelitor.Alarms.DispatchLogTest do
  @moduledoc """
  Test suite for Intelitor.Alarms.DispatchLog.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/alarms/dispatch_log.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Alarms.DispatchLog

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(DispatchLog)
    end

    test "module has __info__/1 function" do
      assert function_exported?(DispatchLog, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = DispatchLog.__info__(:module)
      assert info == Intelitor.Alarms.DispatchLog
    end
  end
end
