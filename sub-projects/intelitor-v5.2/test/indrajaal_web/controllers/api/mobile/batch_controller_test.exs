defmodule IndrajaalWeb.Api.Mobile.BatchControllerTest do
  @moduledoc """
  Tests for IndrajaalWeb.Api.Mobile.BatchController.

  WHAT: Verifies batch operation controller functions for the mobile API.
  WHY: Ensures bulk mobile API operations are correctly defined.
  CONSTRAINTS: SC-COV-001, SC-TDG-001
  """

  use IndrajaalWeb.ConnCase, async: true

  @moduletag :zenoh_nif

  alias IndrajaalWeb.Api.Mobile.BatchController

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.Api.Mobile.BatchController)
    end
  end

  describe "controller actions" do
    test "batch_get/2 function exists" do
      assert function_exported?(BatchController, :batch_get, 2)
    end

    test "batch_create/2 function exists" do
      assert function_exported?(BatchController, :batch_create, 2)
    end

    test "batch_update/2 function exists" do
      assert function_exported?(BatchController, :batch_update, 2)
    end

    test "batch_acknowledge/2 function exists" do
      assert function_exported?(BatchController, :batch_acknowledge, 2)
    end

    test "batch_sync/2 function exists" do
      assert function_exported?(BatchController, :batch_sync, 2)
    end
  end
end
