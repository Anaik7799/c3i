defmodule IndrajaalWeb.Api.Mobile.Config.LocationsControllerTest do
  @moduledoc """
  Tests for IndrajaalWeb.Api.Mobile.Config.LocationsController.

  WHAT: Verifies locations controller functions for mobile API config.
  WHY: Ensures location management endpoints are correctly defined.
  CONSTRAINTS: SC-COV-001, SC-TDG-001
  """

  use IndrajaalWeb.ConnCase, async: true

  @moduletag :zenoh_nif

  alias IndrajaalWeb.Api.Mobile.Config.LocationsController

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.Api.Mobile.Config.LocationsController)
    end
  end

  describe "CRUD actions" do
    test "index/2 function exists" do
      assert function_exported?(LocationsController, :index, 2)
    end

    test "show/2 function exists" do
      assert function_exported?(LocationsController, :show, 2)
    end

    test "create/2 function exists" do
      assert function_exported?(LocationsController, :create, 2)
    end

    test "update/2 function exists" do
      assert function_exported?(LocationsController, :update, 2)
    end

    test "delete/2 function exists" do
      assert function_exported?(LocationsController, :delete, 2)
    end
  end
end
