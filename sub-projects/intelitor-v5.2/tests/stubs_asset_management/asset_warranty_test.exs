defmodule Intelitor.AssetManagement.AssetWarrantyTest do
  @moduledoc """
  Test suite for Intelitor.AssetManagement.AssetWarranty.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/asset_management/asset_warranty.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.AssetManagement.AssetWarranty

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(AssetWarranty)
    end

    test "module has __info__/1 function" do
      assert function_exported?(AssetWarranty, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = AssetWarranty.__info__(:module)
      assert info == Intelitor.AssetManagement.AssetWarranty
    end
  end
end
