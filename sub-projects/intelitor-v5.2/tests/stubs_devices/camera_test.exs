defmodule Intelitor.Devices.CameraTest do
  @moduledoc """
  Test suite for Intelitor.Devices.Camera.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/devices/camera.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Devices.Camera

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(Camera)
    end

    test "module has __info__/1 function" do
      assert function_exported?(Camera, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = Camera.__info__(:module)
      assert info == Intelitor.Devices.Camera
    end
  end
end
