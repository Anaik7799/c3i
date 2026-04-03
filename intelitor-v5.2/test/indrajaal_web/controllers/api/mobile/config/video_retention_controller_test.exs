defmodule IndrajaalWeb.Api.Mobile.Config.VideoRetentionControllerTest do
  @moduledoc """
  Tests for IndrajaalWeb.Api.Mobile.Config.VideoRetentionController.

  WHAT: Verifies video retention controller functions for mobile API config.
  WHY: Ensures video retention policy configuration endpoints are correctly defined.
  CONSTRAINTS: SC-COV-001, SC-TDG-001
  """

  use IndrajaalWeb.ConnCase, async: true

  @moduletag :zenoh_nif

  alias IndrajaalWeb.Api.Mobile.Config.VideoRetentionController

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.Api.Mobile.Config.VideoRetentionController)
    end
  end

  describe "CRUD actions" do
    test "index/2 function exists" do
      assert function_exported?(VideoRetentionController, :index, 2)
    end

    test "show/2 function exists" do
      assert function_exported?(VideoRetentionController, :show, 2)
    end

    test "create/2 function exists" do
      assert function_exported?(VideoRetentionController, :create, 2)
    end

    test "update/2 function exists" do
      assert function_exported?(VideoRetentionController, :update, 2)
    end

    test "delete/2 function exists" do
      assert function_exported?(VideoRetentionController, :delete, 2)
    end
  end
end
