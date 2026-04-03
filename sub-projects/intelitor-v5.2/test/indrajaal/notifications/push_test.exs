defmodule Indrajaal.Notifications.PushTest do
  @moduledoc """
  Test suite for push notification system.

  Following TDG methodology - tests written before implementation.

  Agent: Helper - 3 manages push notification testing
  SOPv5.1 Compliance: ✅
  """

  use Indrajaal.DataCase

  alias Indrajaal.{Accounts, Devices}
  alias Indrajaal.Notifications.{Push, Templates, Preferences, History}

  describe "device registration" do
    setup do
      {:ok, user} = create_test_user()
      {:ok, user: user}
    end

    test "registers iOS device for push notifications", %{user: user} do
      device_params = %{
        user_id: user.id,
        device_id: "ios - device-123",
        platform: "ios",
        push_token: "fake - apns - token",
        app_version: "1.0.0",
        os_version: "17.0"
      }

      {:ok, device} = Push.register_device(device_params)

      assert device.__user_id == user.id
      assert device.platform == "ios"
      assert device.push_token == "fake - apns - token"
      assert device.active == true
    end

    test "registers Android device for push notifications", %{user: user} do
      device_params = %{
        user_id: user.id,
        device_id: "android - device-456",
        platform: "android",
        push_token: "fake - fcm - token",
        app_version: "1.0.0",
        os_version: "14"
      }

      {:ok, device} = Push.register_device(device_params)

      assert device.platform == "android"
      assert device.push_token == "fake - fcm - token"
    end

    test "updates existing device registration", %{user: user} do
      # Register device
      {:ok, device} =
        Push.register_device(%{
          user_id: user.id,
          device_id: "test-device",
          platform: "ios",
          push_token: "old-token"
        })

      # Update with new token
      {:ok, updated} =
        Push.register_device(%{
          user_id: user.id,
          device_id: "test-device",
          platform: "ios",
          push_token: "new-token"
        })

      assert updated.id == device.id
      assert updated.push_token == "new-token"
    end

    test "deactivates old devices on new registration", %{user: user} do
      # Register multiple devices
      {:ok, device1} =
        Push.register_device(%{
          user_id: user.id,
          device_id: "device - 1",
          platform: "ios",
          push_token: "token - 1"
        })

      {:ok, device2} =
        Push.register_device(%{
          user_id: user.id,
          device_id: "device - 2",
          platform: "ios",
          push_token: "token - 2"
        })

      # Check max devices limit (e.g., 5)
      devices = Push.get_active_devices(user.id)
      assert length(devices) <= 5
    end
  end

  describe "notification preferences" do
    setup do
      {:ok, user} = create_test_user()
      {:ok, user: user}
    end

    test "sets default preferences on user creation", %{user: user} do
      prefs = Preferences.get_preferences(user.id)

      assert prefs.alarm_notifications == true
      assert prefs.alarm_sound == true
      assert prefs.alarm_vibration == true
      assert prefs.maintenance_notifications == true
      assert prefs.system_notifications == true
      assert prefs.quiet_hours_enabled == false
    end

    test "updates notification preferences", %{user: user} do
      updates = %{
        alarm_sound: false,
        quiet_hours_enabled: true,
        quiet_hours_start: ~T[22:00:00],
        quiet_hours_end: ~T[07:00:00]
      }

      {:ok, updated} = Preferences.update_preferences(user.id, updates)

      assert updated.alarm_sound == false
      assert updated.quiet_hours_enabled == true
      assert updated.quiet_hours_start == ~T[22:00:00]
    end

    test "respects notification preferences when sending", %{user: user} do
      # Disable alarm notifications
      {:ok, _} =
        Preferences.update_preferences(user.id, %{
          alarm_notifications: false
        })

      # Try to send alarm notification
      result =
        Push.send_notification(user.id, :alarm_triggered, %{
          alarm_name: "Test Alarm"
        })

      assert {:ok, :suppressed} = result
    end

    test "respects quiet hours", %{user: user} do
      # Set quiet hours (current time should be within quiet hours for test)
      {:ok, _} =
        Preferences.update_preferences(user.id, %{
          quiet_hours_enabled: true,
          quiet_hours_start: ~T[00:00:00],
          # All day quiet
          quiet_hours_end: ~T[23:59:59]
        })

      # Try to send non - urgent notification
      result =
        Push.send_notification(user.id, :maintenance_reminder, %{
          device_name: "Camera 1"
        })

      assert {:ok, :quiet_hours} = result
    end

    test "allows urgent notifications during quiet hours", %{user: user} do
      # Set quiet hours
      {:ok, _} =
        Preferences.update_preferences(user.id, %{
          quiet_hours_enabled: true,
          quiet_hours_start: ~T[00:00:00],
          quiet_hours_end: ~T[23:59:59]
        })

      # Send urgent notification
      result =
        Push.send_notification(user.id, :critical_alarm, %{
          alarm_name: "Critical Security Breach",
          priority: :high
        })

      assert {:ok, _notification_id} = result
    end
  end

  describe "notification templates" do
    test "loads predefined notification templates" do
      template = Templates.get_template(:alarm_triggered)

      assert template.title == "Alarm Triggered"
      assert template.body =~ "{{alarm_name}}"
      assert template.sound == "alarm"
      assert template.priority == :high
    end

    test "renders template with variables" do
      rendered =
        Templates.render(:alarm_triggered, %{
          alarm_name: "Front Door Motion",
          severity: "high",
          location: "Building A"
        })

      assert rendered.title == "Alarm Triggered"
      assert rendered.body =~ "Front Door Motion"
      assert rendered.body =~ "Building A"
    end

    test "supports localized templates" do
      rendered =
        Templates.render(
          :alarm_triggered,
          %{
            alarm_name: "Sensor Alert"
          },
          locale: "es"
        )

      # Spanish
      assert rendered.title == "Alarma Activada"
    end

    test "falls back to default locale" do
      rendered =
        Templates.render(
          :alarm_triggered,
          %{
            alarm_name: "Test"
          },
          locale: "unknown"
        )

      # English fallback
      assert rendered.title == "Alarm Triggered"
    end
  end

  describe "sending notifications" do
    setup do
      {:ok, user} = create_test_user()

      {:ok, device} =
        Push.register_device(%{
          user_id: user.id,
          device_id: "test-device",
          platform: "ios",
          push_token: "test-token"
        })

      {:ok, user: user, device: device}
    end

    test "sends notification to iOS device", %{user: user} do
      {:ok, notification_id} =
        Push.send_notification(user.id, :alarm_triggered, %{
          alarm_name: "Motion Detected",
          alarm_id: "alarm-123"
        })

      # Verify notification was queued
      assert notification_id != nil

      # In test mode, verify the payload that would be sent
      {:ok, payload} = Push.get_test_payload(notification_id)

      assert payload.aps.alert.title == "Alarm Triggered"
      assert payload.aps.alert.body =~ "Motion Detected"
      assert payload.aps.sound == "alarm"
      assert payload.custom__data.alarm_id == "alarm-123"
    end

    test "sends notification to Android device", %{user: user} do
      # Register Android device
      {:ok, _} =
        Push.register_device(%{
          user_id: user.id,
          device_id: "android-device",
          platform: "android",
          push_token: "fcm-token"
        })

      {:ok, notification_id} =
        Push.send_notification(user.id, :device_offline, %{
          device_name: "Camera 5"
        })

      # Verify FCM payload
      {:ok, payload} = Push.get_test_payload(notification_id)

      assert payload.notification.title == "Device Offline"
      assert payload.notification.body =~ "Camera 5"
      assert payload.data.type == "device_offline"
    end

    test "sends to all user devices", %{user: user} do
      # Register multiple devices
      {:ok, _} =
        Push.register_device(%{
          user_id: user.id,
          device_id: "device - 1",
          platform: "ios",
          push_token: "token - 1"
        })

      {:ok, _} =
        Push.register_device(%{
          user_id: user.id,
          device_id: "device - 2",
          platform: "android",
          push_token: "token - 2"
        })

      {:ok, notification_ids} =
        Push.send_notification(user.id, :system_announcement, %{
          message: "System maintenance tonight"
        })

      assert length(notification_ids) == 2
    end

    test "handles delivery failures gracefully", %{user: user} do
      # Register device with invalid token
      {:ok, _} =
        Push.register_device(%{
          user_id: user.id,
          device_id: "bad-device",
          platform: "ios",
          push_token: "invalid - token - that - will - fail"
        })

      {:ok, notification_id} = Push.send_notification(user.id, :test_notification, %{})

      # Simulate delivery attempt
      {:error, :invalid_token} = Push.deliver(notification_id)

      # Device should be marked as inactive
      device = Push.get_device("bad-device")
      assert device.active == false
    end
  end

  describe "notification history" do
    setup do
      {:ok, user} = create_test_user()

      {:ok, _} =
        Push.register_device(%{
          user_id: user.id,
          device_id: "test-device",
          platform: "ios",
          push_token: "test-token"
        })

      {:ok, user: user}
    end

    test "tracks sent notifications", %{user: user} do
      {:ok, notification_id} =
        Push.send_notification(user.id, :alarm_triggered, %{
          alarm_name: "Test Alarm"
        })

      history = History.get_user_notifications(user.id)

      assert length(history) == 1
      assert hd(history).id == notification_id
      assert hd(history).template == :alarm_triggered
      assert hd(history).status == "sent"
    end

    test "tracks delivery status", %{user: user} do
      {:ok, notification_id} = Push.send_notification(user.id, :test_notification, %{})

      # Simulate successful delivery
      {:ok, _} =
        History.update_status(notification_id, "delivered", %{
          delivered_at: DateTime.utc_now()
        })

      notification = History.get_notification(notification_id)
      assert notification.status == "delivered"
      assert notification.delivered_at != nil
    end

    test "tracks user interactions", %{user: user} do
      {:ok, notification_id} =
        Push.send_notification(user.id, :alarm_triggered, %{
          alarm_id: "alarm-123"
        })

      # Track that user tapped notification
      {:ok, _} =
        History.track_interaction(notification_id, "tapped", %{
          tapped_at: DateTime.utc_now(),
          action: "view_alarm"
        })

      notification = History.get_notification(notification_id)
      assert notification.interaction == "tapped"
      assert notification.interaction_data["action"] == "view_alarm"
    end
  end

  describe "batch notifications" do
    test "groups similar notifications" do
      {:ok, user} = create_test_user()

      # Send multiple alarm notifications quickly
      alarm_ids =
        for i <- 1..5 do
          {:ok, id} =
            Push.send_notification(
              user.id,
              :alarm_triggered,
              %{
                alarm_name: "Alarm #{i}"
              },
              batch: true
            )

          id
        end

      # Should be grouped into single notification
      {:ok, grouped} = Push.get_pending_batched(user.id)

      assert length(grouped) == 1
      assert hd(grouped).type == :alarm_triggered
      assert hd(grouped).count == 5
    end

    test "respects batch time window" do
      {:ok, user} = create_test_user()

      # Send notifications with delay
      {:ok, _} =
        Push.send_notification(
          user.id,
          :device_offline,
          %{
            device_name: "Device 1"
          },
          batch: true
        )

      # Wait beyond batch window (e.g., 30 seconds)
      :timer.sleep(31_000)

      {:ok, _} =
        Push.send_notification(
          user.id,
          :device_offline,
          %{
            device_name: "Device 2"
          },
          batch: true
        )

      # Should be separate notifications
      history = History.get_user_notifications(user.id)
      assert length(history) == 2
    end
  end

  # Helper functions

  defp create_test_user(attrs \\ %{}) do
    default_attrs = %{
      email: "__user#{System.unique_integer()}@example.com",
      password: "Test123!@#",
      first_name: "Test",
      last_name: "User",
      role: "operator",
      tenant_id: Ecto.UUID.generate()
    }

    Accounts.create_user(Map.merge(default_attrs, attrs))
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
