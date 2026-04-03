defmodule IndrajaalWeb.Api.Mobile.Config.ZonesControllerTest do
  @moduledoc """
  Tests for IndrajaalWeb.Api.Mobile.Config.ZonesController.

  WHAT: Verifies zones controller functions for mobile API config.
  WHY: Ensures zone configuration endpoints are correctly defined.
  CONSTRAINTS: SC-COV-001, SC-TDG-001
  """

  use IndrajaalWeb.ConnCase, async: true

  @moduletag :zenoh_nif

  alias IndrajaalWeb.Api.Mobile.Config.ZonesController

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.Api.Mobile.Config.ZonesController)
    end
  end

  describe "CRUD actions" do
    test "index/2 function exists" do
      assert function_exported?(ZonesController, :index, 2)
    end

    test "show/2 function exists" do
      assert function_exported?(ZonesController, :show, 2)
    end

    test "create/2 function exists" do
      assert function_exported?(ZonesController, :create, 2)
    end

    test "update/2 function exists" do
      assert function_exported?(ZonesController, :update, 2)
    end

    test "delete/2 function exists" do
      assert function_exported?(ZonesController, :delete, 2)
    end
  end
end
