defmodule Intelitor.Devices.PanelTest do
  @moduledoc """
  Test suite for Intelitor.Devices.Panel.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/devices/panel.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Devices.Panel

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(Panel)
    end

    test "module has __info__/1 function" do
      assert function_exported?(Panel, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = Panel.__info__(:module)
      assert info == Intelitor.Devices.Panel
    end
  end
end
