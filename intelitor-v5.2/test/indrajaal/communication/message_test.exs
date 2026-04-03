defmodule Indrajaal.Communication.MessageTest do
  @moduledoc """
  Comprehensive test suite for Message resource.
  Tests multi - channel message composition, delivery, and status tracking.
  """

  use Indrajaal.DataCase, async: true

  alias Indrajaal.Communication
  alias Indrajaal.Communication.Message

  describe "Message.compose_message / 1" do
    setup do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant_id: tenant.id)

      channel =
        insert(:notification_channel, %{
          tenant_id: tenant.id,
          name: "Primary Email Channel",
          channel_type: :email
        })

      sender = insert(:user, %{tenant_id: tenant.id})

      %{tenant: tenant, organization: organization, channel: channel, sender: sender}
    end

    test "composes message with required attributes", %{
      tenant: tenant,
      channel: channel,
      sender: sender
    } do
      args = %{
        channel_id: channel.id,
        body: "Critical security alert: Unauthorized access detected in Zone A",
        message_type: :alert,
        sender_id: sender.id,
        recipients: ["security@company.com", "admin@company.com"]
      }

      actor = %{tenant_id: tenant.id, role: "security_officer"}

      assert {:ok, message} = Message.compose_message(args, actor: actor)
      assert message.body == "Critical security alert: Unauthorized access detected in Zone A"
      assert message.message_type == :alert
      assert message.status == :draft
      assert message.priority == :medium
      assert message.tenant_id == tenant.id
      assert message.channel_id == channel.id
      assert message.sender_id == sender.id
      assert message.recipient_list == ["security@company.com", "admin@company.com"]
    end

    test "supports all message types",
         %{tenant: tenant, channel: channel, sender: sender} do
      actor = %{tenant_id: tenant.id, role: "admin"}

      message_types = [:alert, :notification, :report, :reminder, :broadcast]

      Enum.each(message_types, fn message_type ->
        args = %{
          channel_id: channel.id,
          body: "Test message of type #{message_type}",
          message_type: message_type,
          sender_id: sender.id,
          recipients: ["test@example.com"]
        }

        assert {:ok, message} = Message.compose_message(args, actor: actor)
        assert message.message_type == message_type
      end)
    end

    test "validates required arguments",
         %{tenant: tenant, channel: channel, sender: sender} do
      actor = %{tenant_id: tenant.id, role: "admin"}

      # Missing body
      args_no_body = %{
        channel_id: channel.id,
        message_type: :alert,
        sender_id: sender.id,
        recipients: ["test@example.com"]
      }

      assert {:error, changeset} = Message.compose_message(args_no_body, actor: actor)
      assert "is required" in errors_on(changeset).body

      # Empty recipients
      args_no_recipients = %{
        channel_id: channel.id,
        body: "Test message",
        message_type: :alert,
        sender_id: sender.id,
        recipients: []
      }

      assert {:error, changeset} = Message.compose_message(args_no_recipients, actor: actor)
      assert "is required" in errors_on(changeset).recipients
    end

    test "handles multiple recipients and complex formatting", %{
      tenant: tenant,
      channel: channel,
      sender: sender
    } do
      complex_body = """
      SECURITY ALERT: Multiple Failed Login Attempts

      Time: #{DateTime.utc_now() |> DateTime.to_iso8601()}
      Location: {{location}}
      User: {{username}}
      IP Address: {{ip_address}}

      Action Required:
      1. Verify user identity
      2. Check system logs
      3. Consider temporary account lock

      This is an automated security notification.
      """

      recipients = [
        "security-team@company.com",
        "soc@company.com",
        "incident - response@company.com",
        "admin@company.com"
      ]

      args = %{
        channel_id: channel.id,
        body: complex_body,
        message_type: :alert,
        sender_id: sender.id,
        recipients: recipients
      }

      actor = %{tenant_id: tenant.id, role: "security_analyst"}

      assert {:ok, message} = Message.compose_message(args, actor: actor)
      assert String.contains?(message.body, "SECURITY ALERT")
      assert String.contains?(message.body, "{{location}}")
      assert length(message.recipient_list) == 4
      assert "security-team@company.com" in message.recipient_list
    end
  end

  describe "Message status workflow" do
    setup do
      tenant = insert(:tenant)

      message =
        insert(:message, %{
          tenant_id: tenant.id,
          status: :draft
        })

      %{tenant: tenant, message: message}
    end

    test "queues message", %{tenant: tenant, message: message} do
      actor = %{tenant_id: tenant.id, role: "admin"}

      assert {:ok, queued_message} = Message.queue_message(message, actor: actor)
      assert queued_message.status == :queued
    end

    test "sends message", %{tenant: tenant, message: message} do
      actor = %{tenant_id: tenant.id, role: "system"}

      assert {:ok, sending_message} = Message.send_message(message, actor: actor)
      assert sending_message.status == :sending
    end

    test "marks message as sent with timestamp",
         %{tenant: tenant, message: message} do
      actor = %{tenant_id: tenant.id, role: "system"}

      before_time = DateTime.utc_now()
      assert {:ok, sent_message} = Message.mark_sent(message, actor: actor)
      after_time = DateTime.utc_now()

      assert sent_message.status == :sent
      assert sent_message.sent_at != nil
      assert DateTime.compare(sent_message.sent_at, before_time) in [:gt, :eq]
      assert DateTime.compare(sent_message.sent_at, after_time) in [:lt, :eq]
    end

    test "marks message as failed", %{tenant: tenant, message: message} do
      actor = %{tenant_id: tenant.id, role: "system"}

      assert {:ok, failed_message} = Message.mark_failed(message, actor: actor)
      assert failed_message.status == :failed
    end

    test "cancels message", %{tenant: tenant, message: message} do
      actor = %{tenant_id: tenant.id, role: "admin"}

      assert {:ok, cancelled_message} = Message.cancel_message(message, actor: actor)
      assert cancelled_message.status == :cancelled
    end

    test "supports complete workflow progression",
         %{tenant: tenant, message: message} do
      actor = %{tenant_id: tenant.id, role: "system"}

      # Draft → Queued → Sending → Sent
      assert {:ok, queued} = Message.queue_message(message, actor: actor)
      assert queued.status == :queued

      assert {:ok, sending} = Message.send_message(queued, actor: actor)
      assert sending.status == :sending

      assert {:ok, sent} = Message.mark_sent(sending, actor: actor)
      assert sent.status == :sent
      assert sent.sent_at != nil
    end
  end

  describe "Message.create / 1 with advanced attributes" do
    setup do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant_id: tenant.id)

      channel = insert(:notification_channel, %{tenant_id: tenant.id})
      template = insert(:message_template, %{tenant_id: tenant.id})
      sender = insert(:user, %{tenant_id: tenant.id})

      %{
        tenant: tenant,
        organization: organization,
        channel: channel,
        template: template,
        sender: sender
      }
    end

    test "creates message with scheduling and expiration", %{
      tenant: tenant,
      channel: channel,
      sender: sender
    } do
      # 1 hour from now
      scheduled_time = DateTime.add(DateTime.utc_now(), 3600, :second)
      # 24 hours after scheduled
      expiry_time = DateTime.add(scheduled_time, 86_400, :second)

      attrs = %{
        subject: "Scheduled Security Briefing",
        body: "Weekly security briefing scheduled for tomorrow",
        message_type: :reminder,
        priority: :high,
        channel_id: channel.id,
        sender_id: sender.id,
        recipient_list: ["team@company.com"],
        scheduled_at: scheduled_time,
        expires_at: expiry_time,
        variables: %{
          "meeting_time" => "2024 - 01 - 15 10:00 AM",
          "location" => "Conference Room A",
          "duration" => "1 hour"
        },
        metadata: %{
          "category" => "security_briefing",
          "department" => "security",
          "recurring" => "weekly"
        }
      }

      actor = %{tenant_id: tenant.id, role: "admin"}

      assert {:ok, message} = Message.create(attrs, actor: actor)
      assert message.subject == "Scheduled Security Briefing"
      assert message.priority == :high
      assert message.scheduled_at == scheduled_time
      assert message.expires_at == expiry_time
      assert message.variables["meeting_time"] == "2024 - 01 - 15 10:00 AM"
      assert message.metadata["category"] == "security_briefing"
    end

    test "supports all priority levels",
         %{tenant: tenant, channel: channel, sender: sender} do
      actor = %{tenant_id: tenant.id, role: "admin"}

      priorities = [:low, :medium, :high, :critical]

      Enum.each(priorities, fn priority ->
        attrs = %{
          body: "Test message with #{priority} priority",
          message_type: :notification,
          priority: priority,
          channel_id: channel.id,
          sender_id: sender.id,
          recipient_list: ["test@example.com"]
        }

        assert {:ok, message} = Message.create(attrs, actor: actor)
        assert message.priority == priority
      end)
    end

    test "handles template relationships", %{
      tenant: tenant,
      channel: channel,
      template: template,
      sender: sender
    } do
      attrs = %{
        body: "Message body from template",
        message_type: :notification,
        channel_id: channel.id,
        template_id: template.id,
        sender_id: sender.id,
        recipient_list: ["__user@example.com"],
        variables: %{
          "__user_name" => "John Doe",
          "account_status" => "active",
          "login_time" => DateTime.to_iso8601(DateTime.utc_now())
        }
      }

      actor = %{tenant_id: tenant.id, role: "admin"}

      assert {:ok, message} = Message.create(attrs, actor: actor)
      assert message.template_id == template.id
      assert message.variables["__user_name"] == "John Doe"
    end
  end

  describe "Message calculations" do
    setup do
      tenant = insert(:tenant)

      # Message with no expiry
      message_no_expiry =
        insert(:message, %{
          tenant_id: tenant.id,
          expires_at: nil
        })

      # Message with future expiry
      message_future_expiry =
        insert(:message, %{
          tenant_id: tenant.id,
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      # Message that's expired
      message_expired =
        insert(:message, %{
          tenant_id: tenant.id,
          expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
        })

      %{
        tenant: tenant,
        message_no_expiry: message_no_expiry,
        message_future_expiry: message_future_expiry,
        message_expired: message_expired
      }
    end

    test "calculates is_expired correctly", %{
      tenant: tenant,
      message_no_expiry: message_no_expiry,
      message_future_expiry: message_future_expiry,
      message_expired: message_expired
    } do
      actor = %{tenant_id: tenant.id, role: "viewer"}

      assert {:ok, [loaded_no_expiry]} =
               Message.read([message_no_expiry.id], actor: actor, load: [:is_expired])

      assert loaded_no_expiry.is_expired == false

      assert {:ok, [loaded_future]} =
               Message.read([message_future_expiry.id], actor: actor, load: [:is_expired])

      assert loaded_future.is_expired == false

      assert {:ok, [loaded_expired]} =
               Message.read([message_expired.id], actor: actor, load: [:is_expired])

      assert loaded_expired.is_expired == true
    end
  end

  describe "Message authorization and tenant isolation" do
    setup do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)

      message1 = insert(:message, %{tenant_id: tenant1.id})
      message2 = insert(:message, %{tenant_id: tenant2.id})

      %{
        tenant1: tenant1,
        tenant2: tenant2,
        message1: message1,
        message2: message2
      }
    end

    test "users can only access messages in their tenant", %{
      tenant1: tenant1,
      tenant2: tenant2,
      message1: message1,
      message2: message2
    } do
      actor1 = %{tenant_id: tenant1.id, role: "admin"}
      actor2 = %{tenant_id: tenant2.id, role: "admin"}

      # Actor1 can access message1 but not message2
      assert {:ok, [found_message]} = Message.read([message1.id], actor: actor1)
      assert found_message.id == message1.id

      assert {:ok, []} = Message.read([message2.id], actor: actor1)

      # Actor2 can access message2 but not message1
      assert {:ok, [found_message]} = Message.read([message2.id], actor: actor2)
      assert found_message.id == message2.id

      assert {:ok, []} = Message.read([message1.id], actor: actor2)
    end

    test "list queries respect tenant isolation",
         %{tenant1: tenant1, tenant2: tenant2} do
      actor1 = %{tenant_id: tenant1.id, role: "viewer"}
      actor2 = %{tenant_id: tenant2.id, role: "viewer"}

      assert {:ok, messages1} = Message.read(actor: actor1)
      assert {:ok, messages2} = Message.read(actor: actor2)

      assert Enum.all?(messages1, &(&1.tenant_id == tenant1.id))
      assert Enum.all?(messages2, &(&1.tenant_id == tenant2.id))

      # Should not overlap
      message1_ids = messages1 |> Enum.map(& &1.id) |> MapSet.new()
      message2_ids = messages2 |> Enum.map(& &1.id) |> MapSet.new()
      assert MapSet.disjoint?(message1_ids, message2_ids)
    end
  end

  describe "Message bulk operations and enterprise scenarios" do
    setup do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant_id: tenant.id)

      # Create multiple channels
      channels =
        Enum.map([:email, :sms, :push], fn type ->
          insert(:notification_channel, %{
            tenant_id: tenant.id,
            channel_type: type
          })
        end)

      # Create sender users
      senders =
        Enum.map(1..3, fn i ->
          insert(:user, %{
            tenant_id: tenant.id,
            email: "sender#{i}@company.com"
          })
        end)

      %{tenant: tenant, organization: organization, channels: channels, senders: senders}
    end

    test "handles enterprise broadcast messaging", %{
      tenant: tenant,
      channels: channels,
      senders: senders
    } do
      actor = %{tenant_id: tenant.id, role: "admin"}

      email_channel = Enum.find(channels, &(&1.channel_type == :email))
      sender = List.first(senders)

      # Create enterprise - wide security alert
      critical_alert = %{
        subject: "CRITICAL: Security Breach Detected",
        body: """
        IMMEDIATE ACTION REQUIRED

        A critical security breach has been detected in our systems.

        Breach Details:
        - Time: #{DateTime.utc_now() |> DateTime.to_iso8601()}
        - System: Production Database Server
        - Threat Level: CRITICAL
        - Status: ACTIVE

        Immediate Actions:
        1. All users must change passwords immediately
        2. VPN access is temporarily restricted
        3. Report any suspicious activity to security@company.com

        This is not a drill. Please treat this alert with highest priority.

        Security Operations Center
        """,
        message_type: :alert,
        priority: :critical,
        channel_id: email_channel.id,
        sender_id: sender.id,
        recipient_list: [
          "all - staff@company.com",
          "security-team@company.com",
          "management@company.com",
          "it - department@company.com",
          "compliance@company.com"
        ],
        variables: %{
          "breach_id" => "SEC - 2024 - 001",
          "incident_commander" => "Jane Smith, CISO",
          "escalation_level" => "5",
          "response_team" => "Incident Response Team Alpha"
        },
        metadata: %{
          "incident_type" => "__data_breach",
          "severity" => "critical",
          "response_time_sla" => "15_minutes",
          "escalation_required" => true,
          "compliance_notification" => true
        }
      }

      assert {:ok, alert_message} = Message.create(critical_alert, actor: actor)
      assert alert_message.priority == :critical
      assert alert_message.message_type == :alert
      assert length(alert_message.recipient_list) == 5
      assert alert_message.variables["breach_id"] == "SEC - 2024 - 001"
      assert alert_message.metadata["incident_type"] == "__data_breach"

      # Queue and process the alert
      assert {:ok, queued_alert} = Message.queue_message(alert_message, actor: actor)
      assert {:ok, sending_alert} = Message.send_message(queued_alert, actor: actor)
      assert {:ok, sent_alert} = Message.mark_sent(sending_alert, actor: actor)

      assert sent_alert.status == :sent
      assert sent_alert.sent_at != nil
    end

    test "supports multi - channel message distribution", %{
      tenant: tenant,
      channels: channels,
      senders: senders
    } do
      actor = %{tenant_id: tenant.id, role: "security_manager"}

      sender = List.first(senders)

      # Create same message for different channels
      base_content = %{
        body: "Security system maintenance scheduled for tonight 11 PM - 1 AM",
        message_type: :notification,
        priority: :medium,
        sender_id: sender.id,
        variables: %{
          "maintenance_window" => "23:00 - 01:00 UTC",
          "affected_systems" => "Access Control, CCTV, Alarms",
          "contact" => "ops@company.com"
        }
      }

      # Email version (detailed)
      email_channel = Enum.find(channels, &(&1.channel_type == :email))

      email_message =
        Map.merge(base_content, %{
          subject: "Scheduled System Maintenance Tonight",
          body: """
          Dear Team,

          We have scheduled essential security system maintenance for tonight.

          Maintenance Window: 23:00 - 01:00 UTC (3 hours)
          Affected Systems: Access Control, CCTV, Alarms
          Impact: Reduced monitoring capabilities during maintenance

          During this time:
          - Physical security will be enhanced with additional patrols
          - Emergency contact: ops@company.com or +1 - 555 - EMERGENCY

          Thank you for your cooperation.
          IT Operations Team
          """,
          channel_id: email_channel.id,
          recipient_list: ["all - staff@company.com", "security@company.com"]
        })

      # SMS version (concise)
      sms_channel = Enum.find(channels, &(&1.channel_type == :sms))

      sms_message =
        Map.merge(base_content, %{
          body:
            "ALERT: Security system maintenance tonight 11PM - 1AM. Enhanced patrols active. Emergency: +1 - 555 - EMERGENCY",
          channel_id: sms_channel.id,
          # Security team mobile numbers
          recipient_list: ["+1_555_123_001", "+1_555_123_002", "+1_555_123_003"]
        })

      # Push notification version (brief)
      push_channel = Enum.find(channels, &(&1.channel_type == :push))

      push_message =
        Map.merge(base_content, %{
          subject: "System Maintenance Alert",
          body: "Security systems maintenance 11PM - 1AM tonight. Tap for details.",
          channel_id: push_channel.id,
          # Push notification groups
          recipient_list: ["security_team", "operations_team"]
        })

      # Create all messages
      assert {:ok, email_msg} = Message.create(email_message, actor: actor)
      assert {:ok, sms_msg} = Message.create(sms_message, actor: actor)
      assert {:ok, push_msg} = Message.create(push_message, actor: actor)

      # Verify channel - specific attributes
      assert email_msg.channel_id == email_channel.id
      assert String.contains?(email_msg.body, "Dear Team")
      assert email_msg.subject == "Scheduled System Maintenance Tonight"

      assert sms_msg.channel_id == sms_channel.id
      # SMS length limit
      assert String.length(sms_msg.body) < 160
      assert String.contains?(sms_msg.body, "+1 - 555 - EMERGENCY")

      assert push_msg.channel_id == push_channel.id
      assert push_msg.subject == "System Maintenance Alert"
      assert "security_team" in push_msg.recipient_list
    end

    test "handles message scheduling and batch processing", %{
      tenant: tenant,
      channels: channels,
      senders: senders
    } do
      actor = %{tenant_id: tenant.id, role: "admin"}

      email_channel = Enum.find(channels, &(&1.channel_type == :email))
      sender = List.first(senders)

      base_time = DateTime.utc_now()

      # Create scheduled message series
      scheduled_messages =
        Enum.map(1..5, fn i ->
          # Every hour
          scheduled_time = DateTime.add(base_time, i * 3600, :second)

          attrs = %{
            subject: "Security Report ##{i}",
            body: "Automated security report #{i} for zone monitoring",
            message_type: :report,
            priority: :low,
            channel_id: email_channel.id,
            sender_id: sender.id,
            recipient_list: ["security-reports@company.com"],
            scheduled_at: scheduled_time,
            # Expires in 24 hours
            expires_at: DateTime.add(scheduled_time, 86_400, :second),
            variables: %{
              "report_number" => i,
              "zone" => "Zone-#{rem(i, 4) + 1}",
              "period" => "hourly"
            }
          }

          insert(:message, Map.merge(attrs, %{tenant_id: tenant.id}))
        end)

      # Verify scheduling
      assert length(scheduled_messages) == 5
      assert Enum.all?(scheduled_messages, &(&1.status == :draft))
      assert Enum.all?(scheduled_messages, &(!is_nil(&1.scheduled_at)))

      # Simulate batch processing
      now = DateTime.utc_now()

      ready_to_send =
        Enum.filter(scheduled_messages, fn msg ->
          DateTime.compare(msg.scheduled_at, now) in [:lt, :eq]
        end)

      # Process ready messages
      processed_messages =
        Enum.map(ready_to_send, fn msg ->
          {:ok, queued} = Message.queue_message(msg, actor: actor)
          {:ok, sent} = Message.mark_sent(queued, actor: actor)
          sent
        end)

      # Verify processing
      assert Enum.all?(processed_messages, &(&1.status == :sent))
      assert Enum.all?(processed_messages, &(!is_nil(&1.sent_at)))
    end
  end

  describe "Message validation and constraints" do
    test "validates message body length constraints" do
      tenant = insert(:tenant)
      channel = insert(:notification_channel, %{tenant_id: tenant.id})
      sender = insert(:user, %{tenant_id: tenant.id})
      actor = %{tenant_id: tenant.id, role: "admin"}

      # Test maximum body length
      # At limit
      max_body = String.duplicate("A", 10_000)
      # Over limit
      long_body = String.duplicate("B", 10_001)

      # Valid at maximum length
      valid_attrs = %{
        body: max_body,
        message_type: :notification,
        channel_id: channel.id,
        sender_id: sender.id,
        recipient_list: ["test@example.com"]
      }

      assert {:ok, _message} = Message.create(valid_attrs, actor: actor)

      # Invalid over maximum length
      invalid_attrs = %{valid_attrs | body: long_body}
      assert {:error, changeset} = Message.create(invalid_attrs, actor: actor)
      assert "should be at most 10_000 character(s)" in errors_on(changeset).body
    end

    test "validates subject length constraints" do
      tenant = insert(:tenant)
      channel = insert(:notification_channel, %{tenant_id: tenant.id})
      sender = insert(:user, %{tenant_id: tenant.id})
      actor = %{tenant_id: tenant.id, role: "admin"}

      # Test subject length limit
      # Over 200 char limit
      long_subject = String.duplicate("S", 201)

      attrs = %{
        subject: long_subject,
        body: "Valid body",
        message_type: :notification,
        channel_id: channel.id,
        sender_id: sender.id,
        recipient_list: ["test@example.com"]
      }

      assert {:error, changeset} = Message.create(attrs, actor: actor)
      assert "should be at most 200 character(s)" in errors_on(changeset).subject
    end

    test "handles edge cases with dates and scheduling" do
      tenant = insert(:tenant)
      channel = insert(:notification_channel, %{tenant_id: tenant.id})
      sender = insert(:user, %{tenant_id: tenant.id})
      actor = %{tenant_id: tenant.id, role: "admin"}

      # Message scheduled in the past
      past_time = DateTime.add(DateTime.utc_now(), -3600, :second)

      attrs = %{
        body: "Message scheduled in the past",
        message_type: :notification,
        channel_id: channel.id,
        sender_id: sender.id,
        recipient_list: ["test@example.com"],
        scheduled_at: past_time
      }

      # Should still be valid (might be intentional for testing)
      assert {:ok, message} = Message.create(attrs, actor: actor)
      assert message.scheduled_at == past_time

      # Test expiry calculation
      {:ok, [loaded]} = Message.read([message.id], actor: actor, load: [:is_expired])
      # No expiry set, so should not be expired
      assert loaded.is_expired == false
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
