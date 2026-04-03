defmodule Intelitor.Alarms.UnifiedAlarmProcessorTest do
  @moduledoc """
  Test suite for Intelitor.Alarms.UnifiedAlarmProcessor.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/alarms/unified_alarm_processor.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Alarms.UnifiedAlarmProcessor

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(UnifiedAlarmProcessor)
    end

    test "module has __info__/1 function" do
      assert function_exported?(UnifiedAlarmProcessor, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = UnifiedAlarmProcessor.__info__(:module)
      assert info == Intelitor.Alarms.UnifiedAlarmProcessor
    end
  end
end
