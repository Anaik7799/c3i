defmodule IndrajaalWeb.Integration.WebSocketIntegrationTest do
  @moduledoc """
  Integration tests for WebSocket functionality.

  Tests the complete flow of WebSocket connections, channels,
  and real-time features.

  Agent: Helper-4 tests WebSocket integration
  TDG Compliance: ✅
  """

  use IndrajaalWeb.ChannelCase

  alias IndrajaalWeb.{MobileSocket, Presence}

  alias IndrajaalWeb.Channels.{
    AlarmChannel,
    DeviceChannel,
    SiteChannel,
    ConfigChannel,
    NotificationChannel,
    SyncChannel
  }

  alias Indrajaal.{Accounts, Alarms, Devices, Sites}
  alias Indrajaal.Realtime.{ConnectionTracker, RateLimiter, OfflineQueue}
  alias Indrajaal.Notifications.{Push, History}

  setup do
    # Create test tenant and user
    {:ok, tenant} = create_test_tenant()
    {:ok, user} = create_test_user(tenant.id)
    {:ok, token} = generate_jwt_token(user)

    # Create test entities
    {:ok, alarm} = create_test_alarm(tenant.id)
    {:ok, device} = create_test_device(tenant.id)
    {:ok, site} = create_test_site(tenant.id)

    %{
      tenant: tenant,
      user: user,
      token: token,
      alarm: alarm,
      device: device,
      site: site
    }
  end

  describe "WebSocket connection lifecycle" do
    test "successful connection with JWT authentication", %{token: token} do
      # Connect to socket
      {:ok, socket} = connect(MobileSocket, %{"token" => token})

      assert socket.assigns.user_id
      assert socket.assigns.tenant_id

      # Verify connection tracking
      assert ConnectionTracker.get_user_connection_count(socket.assigns.user_id) == 1
    end

    test "connection rejected with invalid token" do
      assert :error = connect(MobileSocket, %{"token" => "invalid-jwt"})
    end

    test "connection rejected when rate limited", %{user: user, token: token} do
      # Exhaust rate limit
      for _ <- 1..10 do
        RateLimiter.check_rate(user.id, :connection_attempts)
      end

      # Next connection should fail
      assert :error = connect(MobileSocket, %{"token" => token})
    end

    test "connection tracking and cleanup", %{token: token, user: user} do
      # Connect
      {:ok, socket} = connect(MobileSocket, %{"token" => token})
      assert ConnectionTracker.get_user_connection_count(user.id) == 1

      # Disconnect
      Process.unlink(socket.channel_pid)
      ref = Process.monitor(socket.channel_pid)
      Process.exit(socket.channel_pid, :shutdown)
      assert_receive {:DOWN, ^ref, _, _, :shutdown}

      # Verify cleanup
      :timer.sleep(100)
      assert ConnectionTracker.get_user_connection_count(user.id) == 0
    end
  end

  describe "Channel subscriptions" do
    setup %{token: token} do
      {:ok, socket} = connect(MobileSocket, %{"token" => token})
      %{socket: socket}
    end

    test "join alarm channel", %{socket: socket, alarm: alarm} do
      # Join channel
      {:ok, _, socket} = subscribe_and_join(socket, AlarmChannel, "alarm:#{alarm.id}")

      # Verify initial state received
      assert_push "alarm_state", state
      assert state.alarm.id == alarm.id
    end

    test "join device channel", %{socket: socket, device: device} do
      {:ok, _, socket} = subscribe_and_join(socket, DeviceChannel, "device:#{device.id}")

      assert_push "device_state", state
      assert state.id == device.id
    end

    test "join site channel", %{socket: socket, site: site} do
      {:ok, _, socket} = subscribe_and_join(socket, SiteChannel, "site:#{site.id}")

      assert_push "site_state", state
      assert state.site.id == site.id
    end

    test "join notification channel", %{socket: socket, user: user} do
      {:ok, _, _socket} =
        subscribe_and_join(
          socket,
          NotificationChannel,
          "notification:user:#{user.id}"
        )

      assert_push "unread_count", %{count: _}
      assert_push "preferences", prefs
      assert prefs.notifications
    end

    test "join sync channel", %{socket: socket} do
      device_id = "test-device-#{System.unique_integer()}"

      {:ok, _, socket} = subscribe_and_join(socket, SyncChannel, "sync:#{device_id}")

      assert_push "sync_ready", %{device_id: ^device_id}
    end
  end

  describe "Real-time alarm operations" do
    setup %{token: token, alarm: alarm} do
      {:ok, socket} = connect(MobileSocket, %{"token" => token})
      {:ok, _, socket} = subscribe_and_join(socket, AlarmChannel, "alarm:#{alarm.id}")
      %{socket: socket}
    end

    test "acknowledge alarm via channel", %{socket: socket, alarm: alarm, user: user} do
      # Send acknowledgment
      ref = push(socket, "acknowledge_alarm", %{"notes" => "Checking"})
      assert_reply ref, :ok, _

      # Verify broadcast
      assert_broadcast "alarm_acknowledged", ack
      assert ack.alarm_id == alarm.id
      assert ack.acknowledged_by == user.id

      # Verify alarm updated
      {:ok, updated} = Alarms.get_alarm(alarm.id)
      assert updated.acknowledged
    end

    test "resolve alarm via channel", %{socket: socket, alarm: alarm} do
      ref =
        push(socket, "resolve_alarm", %{
          "resolution" => "Fixed the issue",
          "root_cause" => "Sensor malfunction"
        })

      assert_reply ref, :ok, _

      assert_broadcast "alarm_resolved", resolution
      assert resolution.alarm_id == alarm.id
    end

    test "escalate alarm via channel", %{socket: socket, alarm: alarm} do
      ref =
        push(socket, "escalate_alarm", %{
          "reason" => "Requires supervisor attention",
          "urgency" => "high"
        })

      assert_reply ref, :ok, _

      assert_broadcast "alarm_escalated", escalation
      assert escalation.alarm_id == alarm.id
    end
  end

  describe "Real-time sync operations" do
    setup %{token: token} do
      {:ok, socket} = connect(MobileSocket, %{"token" => token})
      device_id = "test-device-#{System.unique_integer()}"
      {:ok, _, socket} = subscribe_and_join(socket, SyncChannel, "sync:#{device_id}")
      %{socket: socket, device_id: device_id}
    end

    test "request initial sync", %{socket: socket} do
      ref = push(socket, "request_sync", %{"last_sync" => nil})
      assert_reply ref, :ok, response

      assert response.type == :initial
      assert response.sync_id

      # Should receive data pushes
      assert_push "sync_data", %{type: :alarms}
      assert_push "sync_data", %{type: :devices}
      assert_push "sync_data", %{type: :sites}
    end

    test "request differential sync", %{socket: socket} do
      last_sync = DateTime.add(DateTime.utc_now(), -1, :hour)

      ref =
        push(socket, "request_sync", %{
          "last_sync" => DateTime.to_iso8601(last_sync)
        })

      assert_reply ref, :ok, response

      assert response.type == :differential
      assert response.sync_id
    end

    test "push client changes", %{socket: socket, tenant: tenant} do
      changes = [
        %{
          "entity_type" => "alarm",
          "entity_id" => Ecto.UUID.generate(),
          "operation" => "update",
          "changes" => %{"acknowledged" => true}
        }
      ]

      ref = push(socket, "push_changes", %{"changes" => changes})
      assert_reply ref, :ok, response

      assert response.processed == 1

      assert_push "push_results", results
      assert results.accepted >= 0
    end
  end

  describe "Push notifications" do
    setup %{token: token, user: user} do
      {:ok, socket} = connect(MobileSocket, %{"token" => token})

      {:ok, _, socket} =
        subscribe_and_join(
          socket,
          NotificationChannel,
          "notification:user:#{user.id}"
        )

      # Register a device
      {:ok, device} =
        Push.register_device(%{
          user_id: user.id,
          device_id: "test-device",
          platform: "ios",
          push_token: "test-token"
        })

      %{socket: socket, device: device}
    end

    test "receive push notification", %{socket: _socket, user: user} do
      # Send notification
      {:ok, _} =
        Push.send_notification(
          user.id,
          :alarm_triggered,
          %{alarm_name: "Test Alarm", location: "Building A"}
        )

      # Should receive in-app notification
      assert_push "new_notification", notification
      assert notification.type == "alarm_triggered"
      assert notification.title
      assert notification.body
    end

    test "mark notification as read", %{socket: socket, user: user} do
      # Create notification
      {:ok, notif_id} = Push.send_notification(user.id, :test_notification, %{})

      # Mark as read
      ref = push(socket, "mark_read", %{"notification_id" => notif_id})
      assert_reply ref, :ok

      # Verify unread count updated
      assert_broadcast "unread_count", %{count: 0}
    end

    test "update notification preferences", %{socket: socket} do
      prefs = %{
        "alarm_notifications" => false,
        "quiet_hours_enabled" => true,
        "quiet_hours_start" => "22:00:00",
        "quiet_hours_end" => "07:00:00"
      }

      ref = push(socket, "update_preferences", %{"preferences" => prefs})
      assert_reply ref, :ok, updated

      assert updated.notifications.alarm == false
      assert updated.quiet_hours.enabled == true

      assert_broadcast "preferences_updated", _
    end
  end

  describe "Presence tracking" do
    setup %{token: token, alarm: alarm} do
      {:ok, socket1} = connect(MobileSocket, %{"token" => token})
      {:ok, _, socket1} = subscribe_and_join(socket1, AlarmChannel, "alarm:#{alarm.id}")

      # Create second user
      {:ok, user2} = create_test_user(alarm.tenant_id)
      {:ok, token2} = generate_jwt_token(user2)

      %{socket1: socket1, token2: token2, alarm: alarm}
    end

    test "track multiple users in channel", %{socket1: socket1, token2: token2, alarm: alarm} do
      # Get initial presence
      ref = push(socket1, "presence_state", %{})
      assert_reply ref, :ok, presence1
      assert map_size(presence1) == 1

      # Second user joins
      {:ok, socket2} = connect(MobileSocket, %{"token" => token2})
      {:ok, _, _socket2} = subscribe_and_join(socket2, AlarmChannel, "alarm:#{alarm.id}")

      # Check presence updated
      assert_push "presence_diff", diff
      assert map_size(diff.joins) == 1
      assert map_size(diff.leaves) == 0
    end
  end

  describe "Offline queue" do
    test "messages queued when user offline", %{user: user, alarm: alarm} do
      # Queue messages while offline
      OfflineQueue.queue_message(user.id, "alarm:#{alarm.id}", "alarm_triggered", %{
        alarm_id: alarm.id,
        severity: "high"
      })

      assert OfflineQueue.get_queue_size(user.id) == 1

      # Connect and verify delivery
      {:ok, token} = generate_jwt_token(user)
      {:ok, _socket} = connect(MobileSocket, %{"token" => token})

      # Wait for offline delivery
      :timer.sleep(100)

      # Queue should be empty after delivery
      assert OfflineQueue.get_queue_size(user.id) == 0
    end
  end

  describe "Rate limiting" do
    setup %{token: token, user: user} do
      {:ok, socket} = connect(MobileSocket, %{"token" => token})
      %{socket: socket, user: user}
    end

    test "channel message rate limiting", %{socket: socket, alarm: alarm, user: _user} do
      {:ok, _, socket} = subscribe_and_join(socket, AlarmChannel, "alarm:#{alarm.id}")

      # Send many messages quickly
      results =
        for i <- 1..100 do
          ref = push(socket, "add_comment", %{"text" => "Comment #{i}"})

          receive do
            %Phoenix.Socket.Reply{ref: ^ref, status: status} -> status
          after
            100 -> :timeout
          end
        end

      # Some should be rate limited
      assert Enum.any?(results, &(&1 == :error))
    end
  end

  # Helper functions

  defp create_test_tenant do
    # Create tenant for testing
    {:ok, %{id: Ecto.UUID.generate(), name: "Test Tenant"}}
  end

  defp create_test_user(tenant_id) do
    # Create user for testing
    {:ok,
     %{
       id: Ecto.UUID.generate(),
       tenant_id: tenant_id,
       email: "test@example.com",
       role: "admin"
     }}
  end

  defp create_test_alarm(tenant_id) do
    # Create alarm for testing
    {:ok,
     %{
       id: Ecto.UUID.generate(),
       tenant_id: tenant_id,
       name: "Test Alarm",
       priority: "high",
       acknowledged: false
     }}
  end

  defp create_test_device(tenant_id) do
    # Create device for testing
    {:ok,
     %{
       id: Ecto.UUID.generate(),
       tenant_id: tenant_id,
       name: "Test Device",
       type: "camera",
       online: true
     }}
  end

  defp create_test_site(tenant_id) do
    # Create site for testing
    {:ok,
     %{
       id: Ecto.UUID.generate(),
       tenant_id: tenant_id,
       name: "Test Site",
       code: "TS001"
     }}
  end

  defp generate_jwt_token(user) do
    # Generate JWT for testing
    {:ok, "test-jwt-token-#{user.id}"}
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
