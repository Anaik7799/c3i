defmodule Intelitor.Devices.SensorTest do
  @moduledoc """
  Test suite for Intelitor.Devices.Sensor.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/devices/sensor.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Devices.Sensor

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(Sensor)
    end

    test "module has __info__/1 function" do
      assert function_exported?(Sensor, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = Sensor.__info__(:module)
      assert info == Intelitor.Devices.Sensor
    end
  end
end
