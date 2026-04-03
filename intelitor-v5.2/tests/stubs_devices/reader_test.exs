defmodule Intelitor.Devices.ReaderTest do
  @moduledoc """
  Test suite for Intelitor.Devices.Reader.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/devices/reader.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Devices.Reader

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(Reader)
    end

    test "module has __info__/1 function" do
      assert function_exported?(Reader, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = Reader.__info__(:module)
      assert info == Intelitor.Devices.Reader
    end
  end
end
