defmodule Intelitor.DevicesTest do
  @moduledoc """
  Test suite for Devices root module.
  SOPv5.11 TDG Compliance - Root module test coverage.
  """
  use ExUnit.Case, async: true

  alias Intelitor.Devices

  describe "module definition" do
    test "module is defined" do
      assert Code.ensure_loaded?(Devices)
    end

    test "module has expected functions" do
      assert function_exported?(Devices, :__info__, 1)
    end
  end
end
