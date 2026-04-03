defmodule IndrajaalWeb.Api.Mobile.Config.VideoStreamsControllerTest do
  @moduledoc """
  Tests for IndrajaalWeb.Api.Mobile.Config.VideoStreamsController.

  WHAT: Verifies video streams controller functions for mobile API config.
  WHY: Ensures video stream configuration endpoints are correctly defined.
  CONSTRAINTS: SC-COV-001, SC-TDG-001
  """

  use IndrajaalWeb.ConnCase, async: true

  @moduletag :zenoh_nif

  alias IndrajaalWeb.Api.Mobile.Config.VideoStreamsController

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.Api.Mobile.Config.VideoStreamsController)
    end
  end

  describe "CRUD actions" do
    test "index/2 function exists" do
      assert function_exported?(VideoStreamsController, :index, 2)
    end

    test "show/2 function exists" do
      assert function_exported?(VideoStreamsController, :show, 2)
    end

    test "create/2 function exists" do
      assert function_exported?(VideoStreamsController, :create, 2)
    end

    test "update/2 function exists" do
      assert function_exported?(VideoStreamsController, :update, 2)
    end

    test "delete/2 function exists" do
      assert function_exported?(VideoStreamsController, :delete, 2)
    end
  end
end
