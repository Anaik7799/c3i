defmodule IndrajaalWeb.Api.Mobile.MobileApiControllerTest do
  @moduledoc """
  Tests for IndrajaalWeb.Api.Mobile.MobileApiController.

  WHAT: Verifies mobile API controller functions for authentication, alarms, and devices.
  WHY: Ensures core mobile API endpoints are correctly defined.
  CONSTRAINTS: SC-COV-001, SC-TDG-001
  """

  use IndrajaalWeb.ConnCase, async: true

  @moduletag :zenoh_nif

  alias IndrajaalWeb.Api.Mobile.MobileApiController

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.Api.Mobile.MobileApiController)
    end
  end

  describe "authentication actions" do
    test "login/2 function exists" do
      assert function_exported?(MobileApiController, :login, 2)
    end

    test "refresh_token/2 function exists" do
      assert function_exported?(MobileApiController, :refresh_token, 2)
    end

    test "logout/2 function exists" do
      assert function_exported?(MobileApiController, :logout, 2)
    end
  end

  describe "alarm actions" do
    test "get_alarms/2 function exists" do
      assert function_exported?(MobileApiController, :get_alarms, 2)
    end

    test "get_alarm/2 function exists" do
      assert function_exported?(MobileApiController, :get_alarm, 2)
    end

    test "acknowledge_alarm/2 function exists" do
      assert function_exported?(MobileApiController, :acknowledge_alarm, 2)
    end

    test "resolve_alarm/2 function exists" do
      assert function_exported?(MobileApiController, :resolve_alarm, 2)
    end

    test "escalate_alarm/2 function exists" do
      assert function_exported?(MobileApiController, :escalate_alarm, 2)
    end
  end

  describe "device and site actions" do
    test "get_devices/2 function exists" do
      assert function_exported?(MobileApiController, :get_devices, 2)
    end

    test "get_sites/2 function exists" do
      assert function_exported?(MobileApiController, :get_sites, 2)
    end
  end

  describe "notification actions" do
    test "register_push_notifications/2 function exists" do
      assert function_exported?(MobileApiController, :register_push_notifications, 2)
    end

    test "get_notification_preferences/2 function exists" do
      assert function_exported?(MobileApiController, :get_notification_preferences, 2)
    end

    test "update_notification_preferences/2 function exists" do
      assert function_exported?(MobileApiController, :update_notification_preferences, 2)
    end
  end

  describe "dashboard actions" do
    test "get_dashboard/2 function exists" do
      assert function_exported?(MobileApiController, :get_dashboard, 2)
    end
  end
end
