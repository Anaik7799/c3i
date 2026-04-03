defmodule IndrajaalWeb.Api.Mobile.Config.VideoAnalyticsControllerTest do
  @moduledoc """
  Tests for IndrajaalWeb.Api.Mobile.Config.VideoAnalyticsController.

  WHAT: Verifies video analytics controller functions for mobile API config.
  WHY: Ensures video analytics configuration endpoints are correctly defined.
  CONSTRAINTS: SC-COV-001, SC-TDG-001
  """

  use IndrajaalWeb.ConnCase, async: true

  @moduletag :zenoh_nif

  alias IndrajaalWeb.Api.Mobile.Config.VideoAnalyticsController

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.Api.Mobile.Config.VideoAnalyticsController)
    end
  end

  describe "CRUD actions" do
    test "index/2 function exists" do
      assert function_exported?(VideoAnalyticsController, :index, 2)
    end

    test "show/2 function exists" do
      assert function_exported?(VideoAnalyticsController, :show, 2)
    end

    test "create/2 function exists" do
      assert function_exported?(VideoAnalyticsController, :create, 2)
    end

    test "update/2 function exists" do
      assert function_exported?(VideoAnalyticsController, :update, 2)
    end

    test "delete/2 function exists" do
      assert function_exported?(VideoAnalyticsController, :delete, 2)
    end
  end
end
