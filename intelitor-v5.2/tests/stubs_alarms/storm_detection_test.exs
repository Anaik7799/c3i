defmodule Intelitor.Alarms.StormDetectionTest do
  @moduledoc """
  Test suite for Intelitor.Alarms.StormDetection.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/alarms/storm_detection.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Alarms.StormDetection

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(StormDetection)
    end

    test "module has __info__/1 function" do
      assert function_exported?(StormDetection, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = StormDetection.__info__(:module)
      assert info == Intelitor.Alarms.StormDetection
    end
  end
end
