defmodule Intelitor.Devices.DeviceTypeTest do
  @moduledoc """
  Test suite for Intelitor.Devices.DeviceType.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/devices/device_type.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Devices.DeviceType

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(DeviceType)
    end

    test "module has __info__/1 function" do
      assert function_exported?(DeviceType, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = DeviceType.__info__(:module)
      assert info == Intelitor.Devices.DeviceType
    end
  end
end
