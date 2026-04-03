defmodule IndrajaalWeb.Api.Mobile.Config.VideoRecordingControllerTest do
  @moduledoc """
  Tests for IndrajaalWeb.Api.Mobile.Config.VideoRecordingController.

  WHAT: Verifies video recording controller functions for mobile API config.
  WHY: Ensures video recording configuration endpoints are correctly defined.
  CONSTRAINTS: SC-COV-001, SC-TDG-001
  """

  use IndrajaalWeb.ConnCase, async: true

  @moduletag :zenoh_nif

  alias IndrajaalWeb.Api.Mobile.Config.VideoRecordingController

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.Api.Mobile.Config.VideoRecordingController)
    end
  end

  describe "CRUD actions" do
    test "index/2 function exists" do
      assert function_exported?(VideoRecordingController, :index, 2)
    end

    test "show/2 function exists" do
      assert function_exported?(VideoRecordingController, :show, 2)
    end

    test "create/2 function exists" do
      assert function_exported?(VideoRecordingController, :create, 2)
    end

    test "update/2 function exists" do
      assert function_exported?(VideoRecordingController, :update, 2)
    end

    test "delete/2 function exists" do
      assert function_exported?(VideoRecordingController, :delete, 2)
    end
  end
end
