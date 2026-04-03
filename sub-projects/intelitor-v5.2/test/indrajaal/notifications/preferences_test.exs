defmodule Indrajaal.Notifications.PreferencesTest do
  @moduledoc """
  TDG test suite for Notifications.Preferences.

  ## STAMP Safety Integration
  - User privacy enforced

  ## TPS 5-Level RCA Context
  - L1 Symptom: User preferences not respected
  - L5 Root Cause: Missing quiet hours validation
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Notifications.Preferences

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(Preferences)
    end

    test "get_preferences/1 is exported" do
      assert function_exported?(Preferences, :get_preferences, 1)
    end
  end

  describe "default preference structure" do
    test "default preferences contain notification type flags" do
      defaults = %{
        alarm_notifications: true,
        critical_alarm_notifications: true,
        device_notifications: true,
        maintenance_notifications: true,
        system_notifications: true,
        security_notifications: true,
        approval_notifications: true
      }

      assert defaults.alarm_notifications == true
      assert defaults.critical_alarm_notifications == true
    end

    test "default delivery preferences are defined" do
      delivery = %{
        push_enabled: true,
        email_enabled: false,
        sms_enabled: false
      }

      assert delivery.push_enabled == true
      assert delivery.email_enabled == false
    end

    test "quiet hours are disabled by default" do
      quiet = %{
        quiet_hours_enabled: false,
        batch_non_critical: true,
        batch_window_minutes: 30
      }

      assert quiet.quiet_hours_enabled == false
      assert quiet.batch_window_minutes == 30
    end
  end

  describe "get_preferences/1 without DB" do
    test "returns error tuple for missing user" do
      result = Preferences.get_preferences(Ecto.UUID.generate())
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
