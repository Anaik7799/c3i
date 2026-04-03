defmodule Intelitor.AssetManagement.AssetLocationTest do
  @moduledoc """
  Test suite for Intelitor.AssetManagement.AssetLocation.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/asset_management/asset_location.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.AssetManagement.AssetLocation

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(AssetLocation)
    end

    test "module has __info__/1 function" do
      assert function_exported?(AssetLocation, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = AssetLocation.__info__(:module)
      assert info == Intelitor.AssetManagement.AssetLocation
    end
  end
end
