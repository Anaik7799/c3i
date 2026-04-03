defmodule IndrajaalWeb.AlarmChannelTest do
  @moduledoc """
  Test suite for alarm real-time updates channel.

  Following TDG methodology - tests written before implementation.

  Agent: Worker-1 manages alarm channel testing
  SOPv5.1 Compliance: ✅
  """

  use IndrajaalWeb.ChannelCase

  import Indrajaal.Factory

  alias IndrajaalWeb.{MobileSocket, AlarmChannel}
  alias Indrajaal.Alarms
  alias Indrajaal.Authentication.JWT

  setup do
    {:ok, test_user} = create_test_user()
    {:ok, token, _} = JWT.generate_token(test_user)
    {:ok, socket} = connect(MobileSocket, %{"token" => token})

    {:ok, socket: socket, user: test_user}
  end

  describe "channel join" do
    test "joins alarm channel for tenant", %{socket: socket, user: user} do
      {:ok, _, socket} = subscribe_and_join(socket, AlarmChannel, "alarm:#{user.tenant_id}")
      assert socket.assigns.tenant_id == user.tenant_id
    end

    test "joins specific alarm channel", %{socket: socket, user: user} do
      {:ok, alarm} = create_test_alarm(user.tenant_id)

      {:ok, _, socket} = subscribe_and_join(socket, AlarmChannel, "alarm:#{alarm.id}")
      assert socket.assigns.alarm_id == alarm.id
    end

    test "prevents joining other tenant's alarm channel", %{socket: socket} do
      other_tenant_id = Ecto.UUID.generate()

      assert {:error, %{reason: "unauthorized"}} =
               subscribe_and_join(socket, AlarmChannel, "alarm:#{other_tenant_id}")
    end

    test "requires proper permissions for alarm channel", %{socket: socket, user: user} do
      # Create user without alarm permissions
      {:ok, restricted_user} = create_test_user(role: "viewer")
      {:ok, restricted_token, _} = JWT.generate_token(restricted_user)
      {:ok, restricted_socket} = connect(MobileSocket, %{"token" => restricted_token})

      # Should still be able to join for viewing
      {:ok, _, _} =
        subscribe_and_join(restricted_socket, AlarmChannel, "alarm:#{user.tenant_id}")
    end
  end

  describe "alarm events" do
    setup %{socket: socket, user: user} do
      {:ok, _, socket} = subscribe_and_join(socket, AlarmChannel, "alarm:#{user.tenant_id}")
      {:ok, socket: socket, user: user}
    end

    test "broadcasts new alarm creation", %{socket: _socket, user: user} do
      # Create alarm (will trigger broadcast)
      alarm_params = %{
        name: "Test Alarm",
        severity: "high",
        source: "test_device",
        tenant_id: user.tenant_id
      }

      {:ok, alarm} = Alarms.create_alarm(alarm_params)

      # Should receive the broadcast
      assert_broadcast "alarm:created", %{alarm: broadcast_alarm}
      assert broadcast_alarm.id == alarm.id
      assert broadcast_alarm.name == "Test Alarm"
    end

    test "broadcasts alarm updates", %{socket: _socket, user: user} do
      {:ok, alarm} = create_test_alarm(user.tenant_id)

      # Update alarm
      {:ok, updated} = Alarms.update_alarm(alarm, %{severity: "critical"})

      assert_broadcast "alarm:updated", %{alarm: broadcast_alarm}
      assert broadcast_alarm.id == updated.id
      assert broadcast_alarm.severity == "critical"
    end

    test "broadcasts alarm acknowledgment", %{socket: _socket, user: user} do
      {:ok, alarm} = create_test_alarm(user.tenant_id)

      # Acknowledge alarm
      {:ok, _ack} = Alarms.acknowledge_alarm(alarm, user, %{notes: "Investigating"})

      assert_broadcast "alarm:acknowledged", %{
        alarm_id: alarm_id,
        acknowledgment: acknowledgment
      }

      assert alarm_id == alarm.id
      assert acknowledgment.user_id == user.id
      assert acknowledgment.notes == "Investigating"
    end

    test "broadcasts alarm resolution", %{socket: _socket, user: user} do
      {:ok, alarm} = create_test_alarm(user.tenant_id)

      # Resolve alarm
      {:ok, _resolved} =
        Alarms.resolve_alarm(alarm, user, %{
          resolution: "Fixed the issue",
          root_cause: "Configuration error"
        })

      assert_broadcast "alarm:resolved", %{
        alarm: broadcast_alarm,
        resolution: resolution
      }

      assert broadcast_alarm.id == alarm.id
      assert resolution.resolution == "Fixed the issue"
    end

    test "broadcasts alarm escalation", %{socket: _socket, user: user} do
      {:ok, alarm} = create_test_alarm(user.tenant_id)

      # Escalate alarm
      {:ok, _escalation} =
        Alarms.escalate_alarm(alarm, %{
          level: 2,
          reason: "No response in 15 minutes"
        })

      assert_broadcast "alarm:escalated", %{
        alarm_id: alarm_id,
        escalation: esc
      }

      assert alarm_id == alarm.id
      assert esc.level == 2
      assert esc.reason == "No response in 15 minutes"
    end
  end

  describe "alarm queries" do
    setup %{socket: socket, user: user} do
      {:ok, _, socket} = subscribe_and_join(socket, AlarmChannel, "alarm:#{user.tenant_id}")

      # Create some test alarms
      {:ok, alarm1} = create_test_alarm(user.tenant_id, severity: "low")
      {:ok, alarm2} = create_test_alarm(user.tenant_id, severity: "high")
      {:ok, alarm3} = create_test_alarm(user.tenant_id, severity: "critical")

      {:ok, socket: socket, alarms: [alarm1, alarm2, alarm3]}
    end

    test "handles get_active_alarms request", %{socket: socket} do
      ref = push(socket, "get_active_alarms", %{})

      assert_reply ref, :ok, %{alarms: alarms}
      assert length(alarms) >= 3
      assert Enum.all?(alarms, &(&1.status == "active"))
    end

    test "handles get_alarm_stats request", %{socket: socket} do
      ref = push(socket, "get_alarm_stats", %{})

      assert_reply ref, :ok, %{stats: stats}
      assert stats.total >= 3
      assert Map.has_key?(stats, :by_severity)
      assert Map.has_key?(stats, :by_status)
    end

    test "filters alarms by severity", %{socket: socket} do
      ref = push(socket, "get_active_alarms", %{severity: "critical"})

      assert_reply ref, :ok, %{alarms: alarms}
      assert Enum.all?(alarms, &(&1.severity == "critical"))
    end
  end

  describe "alarm actions" do
    setup %{socket: socket, user: user} do
      {:ok, _, socket} = subscribe_and_join(socket, AlarmChannel, "alarm:#{user.tenant_id}")
      {:ok, alarm} = create_test_alarm(user.tenant_id)

      {:ok, socket: socket, alarm: alarm}
    end

    test "acknowledges alarm via channel", %{socket: socket, alarm: alarm} do
      ref =
        push(socket, "acknowledge_alarm", %{
          alarm_id: alarm.id,
          notes: "Looking into it"
        })

      assert_reply ref, :ok, %{acknowledgment: ack}
      assert ack.alarm_id == alarm.id
      assert ack.notes == "Looking into it"

      # Should also broadcast
      assert_broadcast "alarm:acknowledged", _
    end

    test "resolves alarm via channel", %{socket: socket, alarm: alarm} do
      ref =
        push(socket, "resolve_alarm", %{
          alarm_id: alarm.id,
          resolution: "Fixed",
          root_cause: "Misconfiguration"
        })

      assert_reply ref, :ok, %{alarm: resolved_alarm}
      assert resolved_alarm.status == "resolved"

      # Should also broadcast
      assert_broadcast "alarm:resolved", _
    end

    test "escalates alarm via channel", %{socket: socket, alarm: alarm} do
      ref =
        push(socket, "escalate_alarm", %{
          alarm_id: alarm.id,
          level: 2,
          reason: "Urgent attention needed"
        })

      assert_reply ref, :ok, %{escalation: esc}
      assert esc.level == 2

      # Should also broadcast
      assert_broadcast "alarm:escalated", _
    end

    test "handles invalid alarm actions", %{socket: socket} do
      ref =
        push(socket, "acknowledge_alarm", %{
          # Non-existent alarm
          alarm_id: Ecto.UUID.generate(),
          notes: "Test"
        })

      assert_reply ref, :error, %{message: message}
      assert message =~ "not found"
    end
  end

  describe "presence and typing indicators" do
    setup %{socket: socket, user: user} do
      {:ok, _, socket} = subscribe_and_join(socket, AlarmChannel, "alarm:#{user.tenant_id}")
      {:ok, alarm} = create_test_alarm(user.tenant_id)
      {:ok, socket: socket, user: user, alarm: alarm}
    end

    test "tracks presence in alarm channel", %{socket: _socket, user: user} do
      # Check presence
      presence = IndrajaalWeb.Presence.list("alarm:#{user.tenant_id}")
      assert Map.has_key?(presence, user.id)
    end

    test "broadcasts typing indicators", %{socket: socket, alarm: alarm} do
      # Send typing indicator
      push(socket, "typing", %{alarm_id: alarm.id})

      assert_broadcast "user:typing", %{user_id: user_id, alarm_id: alarm_id}
      assert user_id == socket.assigns.user_id
      assert alarm_id == alarm.id
    end
  end

  describe "error handling" do
    setup %{socket: socket, user: user} do
      {:ok, _, socket} = subscribe_and_join(socket, AlarmChannel, "alarm:#{user.tenant_id}")
      {:ok, socket: socket}
    end

    test "handles malformed messages gracefully", %{socket: socket} do
      # Missing alarm_id
      ref = push(socket, "acknowledge_alarm", %{})

      assert_reply ref, :error, %{message: message}
      assert message =~ "alarm_id is required"
    end

    test "handles authorization errors", %{socket: socket} do
      # Create alarm in different tenant
      {:ok, other_tenant} = create_test_tenant("Other")
      {:ok, other_alarm} = create_test_alarm(other_tenant.id)

      ref =
        push(socket, "acknowledge_alarm", %{
          alarm_id: other_alarm.id,
          notes: "Should fail"
        })

      assert_reply ref, :error, %{message: "unauthorized"}
    end
  end

  # Helper functions

  defp create_test_user(attrs \\ []) do
    default_attrs = %{
      email: "user#{System.unique_integer()}@example.com",
      password: "Test123!@#",
      first_name: "Test",
      last_name: "User",
      role: Keyword.get(attrs, :role, "operator")
    }

    Indrajaal.Accounts.create_user(Map.merge(default_attrs, Map.new(attrs)))
  end

  defp create_test_tenant(name) do
    Indrajaal.Tenants.create_tenant(%{
      name: name,
      code: String.downcase(String.replace(name, " ", "_"))
    })
  end

  defp create_test_alarm(tenant_id, attrs \\ []) do
    default_attrs = %{
      name: "Test Alarm #{System.unique_integer()}",
      severity: Keyword.get(attrs, :severity, "medium"),
      source: "test_device",
      status: "active",
      tenant_id: tenant_id
    }

    Indrajaal.Alarms.create_alarm(Map.merge(default_attrs, Map.new(attrs)))
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
