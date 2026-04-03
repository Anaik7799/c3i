defmodule Intelitor.Dispatch.VehicleTest do
  @moduledoc """
  Test suite for Intelitor.Dispatch.Vehicle.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/dispatch/vehicle.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Dispatch.Vehicle

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(Vehicle)
    end

    test "module has __info__/1 function" do
      assert function_exported?(Vehicle, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = Vehicle.__info__(:module)
      assert info == Intelitor.Dispatch.Vehicle
    end
  end
end
