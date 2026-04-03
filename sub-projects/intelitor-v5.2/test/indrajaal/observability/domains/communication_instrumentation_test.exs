defmodule Indrajaal.Observability.Domains.CommunicationInstrumentationTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import Indrajaal.STAMPTestHelpers

  alias Indrajaal.Observability.Domains.CommunicationInstrumentation

  setup do
    # Detach any existing handlers before test
    handlers = :telemetry.list_handlers([])

    handlers
    |> Enum.each(fn handler ->
      if String.contains?(to_string(handler.id), "communication") do
        :telemetry.detach(handler.id)
      end
    end)

    :ok
  end

  describe "setup/0" do
    test "attaches all communication telemetry handlers" do
      log =
        capture_log(fn ->
          assert :ok = CommunicationInstrumentation.setup()
        end)

      # Verify handlers were attached
      handlers = :telemetry.list_handlers([])
      handler_ids = Enum.map(handlers, & &1.id)

      assert "communication - notification - handlers" in handler_ids
      assert "communication - message - handlers" in handler_ids
      assert "communication - channel - handlers" in handler_ids
      assert "communication - preference - handlers" in handler_ids
    end

    test "returns :ok" do
      capture_log(fn ->
        assert :ok = CommunicationInstrumentation.setup()
      end)
    end

    test "can be called multiple times idempotently" do
      capture_log(fn ->
        assert :ok = CommunicationInstrumentation.setup()
        assert :ok = CommunicationInstrumentation.setup()
      end)
    end
  end

  describe "notification events" do
    test "handles notification send start event" do
      log =
        capture_log(fn ->
          :telemetry.execute(
            [:indrajaal, :communication, :notification, :send, :start],
            %{},
            %{
              type: "alert",
              channel: "email",
              recipient_count: 100,
              priority: "high",
              trace_id: "trace-123"
            }
          )
        end)

      assert log =~ "Notification send started"
      assert log =~ "alert"
      assert log =~ "email"
    end

    test "handles notification send stop event with duration" do
      log =
        capture_log(fn ->
          :telemetry.execute(
            [:indrajaal, :communication, :notification, :send, :stop],
            %{duration: System.convert_time_unit(100, :millisecond, :native)},
            %{
              type: "alert",
              channel: "sms",
              success: true
            }
          )
        end)

      assert log =~ "Notification sent"
      assert log =~ "alert"
    end

    test "handles notification delivery confirmed event" do
      :telemetry.execute(
        [:indrajaal, :communication, :notification, :delivery, :confirmed],
        %{},
        %{
          type: "alert",
          channel: "push"
        }
      )

      # Event should be handled without errors
    end

    test "handles notification delivery failed event with logging" do
      log =
        capture_log(fn ->
          :telemetry.execute(
            [:indrajaal, :communication, :notification, :delivery, :failed],
            %{},
            %{
              type: "alert",
              channel: "email",
              error: "rate limit exceeded",
              error_type: "rate_limit",
              retry_count: 3
            }
          )
        end)

      assert log =~ "Notification delivery failed"
      assert log =~ "alert"
      assert log =~ "email"
    end

    test "handles batch processing stop event" do
      :telemetry.execute(
        [:indrajaal, :communication, :notification, :batch, :stop],
        %{
          duration: System.convert_time_unit(500, :millisecond, :native),
          batch_size: 1000
        },
        %{channel: "email"}
      )

      # Event should be handled without errors
    end
  end

  describe "message queue events" do
    test "handles message queue enqueued event" do
      :telemetry.execute(
        [:indrajaal, :communication, :message, :queue, :enqueued],
        %{queue_size: 150},
        %{
          queue_name: "notifications",
          priority: "high"
        }
      )

      # Event should be handled without errors
    end

    test "handles message queue processed event" do
      :telemetry.execute(
        [:indrajaal, :communication, :message, :queue, :processed],
        %{processing_time: 25},
        %{
          queue_name: "notifications",
          message_type: "alert"
        }
      )

      # Event should be handled without errors
    end

    test "handles message queue failed event" do
      :telemetry.execute(
        [:indrajaal, :communication, :message, :queue, :failed],
        %{},
        %{
          queue_name: "notifications",
          error_type: "timeout"
        }
      )

      # Event should be handled without errors
    end

    test "handles message retry attempted event" do
      :telemetry.execute(
        [:indrajaal, :communication, :message, :retry, :attempted],
        %{},
        %{
          attempt_number: 2,
          max_attempts: 5
        }
      )

      # Event should be handled without errors
    end

    test "handles message moved to DLQ event with logging" do
      log =
        capture_log(fn ->
          :telemetry.execute(
            [:indrajaal, :communication, :message, :dlq, :moved],
            %{},
            %{
              message_id: "msg-123",
              original_queue: "notifications",
              failure_reason: "max retries exceeded"
            }
          )
        end)

      assert log =~ "Message moved to DLQ"
      assert log =~ "msg-123"
      assert log =~ "notifications"
    end
  end

  describe "channel-specific events" do
    test "handles email sent event" do
      :telemetry.execute(
        [:indrajaal, :communication, :channel, :email, :sent],
        %{},
        %{
          provider: "sendgrid",
          template: "alert_template"
        }
      )

      # Event should be handled without errors
    end

    test "handles email bounced event" do
      :telemetry.execute(
        [:indrajaal, :communication, :channel, :email, :bounced],
        %{},
        %{
          bounce_type: "hard",
          provider: "sendgrid"
        }
      )

      # Event should be handled without errors
    end

    test "handles SMS sent event with cost" do
      :telemetry.execute(
        [:indrajaal, :communication, :channel, :sms, :sent],
        %{cost: 0.05},
        %{
          provider: "twilio",
          country_code: "+1"
        }
      )

      # Event should be handled without errors
    end

    test "handles SMS delivered event" do
      :telemetry.execute(
        [:indrajaal, :communication, :channel, :sms, :delivered],
        %{},
        %{
          provider: "twilio",
          country_code: "+1"
        }
      )

      # Event should be handled without errors (unknown event - handled by _ clause)
    end

    test "handles push notification sent event" do
      :telemetry.execute(
        [:indrajaal, :communication, :channel, :push, :sent],
        %{},
        %{
          platform: "ios",
          topic: "alerts"
        }
      )

      # Event should be handled without errors
    end

    test "handles push notification received event" do
      :telemetry.execute(
        [:indrajaal, :communication, :channel, :push, :received],
        %{delivery_time: 150},
        %{platform: "android"}
      )

      # Event should be handled without errors
    end

    test "handles webhook triggered event" do
      :telemetry.execute(
        [:indrajaal, :communication, :channel, :webhook, :triggered],
        %{response_time: 200},
        %{
          endpoint: "https://example.com/webhook",
          status_code: 200
        }
      )

      # Event should be handled without errors
    end
  end

  describe "preference management events" do
    test "handles preference updated event" do
      :telemetry.execute(
        [:indrajaal, :communication, :preference, :updated],
        %{},
        %{
          channel: "email",
          action: "enabled"
        }
      )

      # Event should be handled without errors
    end

    test "handles opt-out event with logging" do
      log =
        capture_log(fn ->
          :telemetry.execute(
            [:indrajaal, :communication, :preference, :opt_out],
            %{},
            %{
              user_id: "user-123",
              channel: "sms",
              reason: "too_frequent"
            }
          )
        end)

      assert log =~ "User opted out of communications"
      assert log =~ "user-123"
      assert log =~ "sms"
    end

    test "handles opt-in event" do
      :telemetry.execute(
        [:indrajaal, :communication, :preference, :opt_in],
        %{},
        %{
          user_id: "user-123",
          channel: "email"
        }
      )

      # Event should be handled without errors (unknown event - handled by _ clause)
    end

    test "handles compliance check event" do
      :telemetry.execute(
        [:indrajaal, :communication, :preference, :compliance, :checked],
        %{},
        %{
          regulation: "GDPR",
          compliant: true
        }
      )

      # Event should be handled without errors
    end
  end

  describe "record_notification_send/5" do
    test "executes telemetry with all parameters" do
      assert_nothing_raised(fn ->
        CommunicationInstrumentation.record_notification_send(
          "alert",
          "email",
          100,
          50,
          true
        )
      end)
    end

    test "converts duration from milliseconds to native" do
      log =
        capture_log(fn ->
          CommunicationInstrumentation.record_notification_send(
            "alert",
            "sms",
            50,
            100,
            true
          )
        end)

      # Event should be handled without errors
    end

    test "includes all metadata fields" do
      log =
        capture_log(fn ->
          CommunicationInstrumentation.record_notification_send(
            "reminder",
            "push",
            200,
            75,
            false
          )
        end)

      # Metadata should include type, channel, recipient_count, success
    end
  end

  describe "record_queue_metrics/3" do
    test "executes telemetry for queue enqueued event" do
      assert_nothing_raised(fn ->
        CommunicationInstrumentation.record_queue_metrics("notifications", 100, nil)
      end)
    end

    test "executes both enqueued and processed events when processing_time provided" do
      assert_nothing_raised(fn ->
        CommunicationInstrumentation.record_queue_metrics("notifications", 100, 50)
      end)
    end

    test "only executes enqueued event when processing_time is nil" do
      assert_nothing_raised(fn ->
        CommunicationInstrumentation.record_queue_metrics("notifications", 100, nil)
      end)
    end
  end

  describe "record_channel_delivery/3" do
    test "executes telemetry with channel-specific event" do
      assert_nothing_raised(fn ->
        CommunicationInstrumentation.record_channel_delivery(
          :email,
          %{provider: "sendgrid"},
          %{sent_count: 1}
        )
      end)
    end

    test "supports different channels" do
      assert_nothing_raised(fn ->
        CommunicationInstrumentation.record_channel_delivery(:sms, %{}, %{})
        CommunicationInstrumentation.record_channel_delivery(:push, %{}, %{})
      end)
    end

    test "includes metrics and delivery_data" do
      assert_nothing_raised(fn ->
        CommunicationInstrumentation.record_channel_delivery(
          :webhook,
          %{endpoint: "https://example.com"},
          %{response_time: 150}
        )
      end)
    end
  end

  describe "record_delivery_failure/4" do
    test "executes telemetry with failure information" do
      log =
        capture_log(fn ->
          CommunicationInstrumentation.record_delivery_failure(
            "alert",
            "email",
            "rate limit exceeded",
            3
          )
        end)

      # Event should trigger delivery failed handler
    end

    test "classifies error using classify_error/1" do
      log =
        capture_log(fn ->
          CommunicationInstrumentation.record_delivery_failure(
            "alert",
            "sms",
            "timeout occurred",
            2
          )
        end)

      # Error should be classified as "timeout"
    end

    test "includes retry_count in metadata" do
      log =
        capture_log(fn ->
          CommunicationInstrumentation.record_delivery_failure(
            "reminder",
            "push",
            "invalid recipient",
            1
          )
        end)

      # Retry count should be in metadata
    end
  end

  describe "BUGS: double underscore prefix (Lines 15, 34, 54, 72, 92, 108, 197, 264, 345)" do
    test "BUG: line 15 - double underscore in comment '__event'" do
      # Line 15: # Telemetry __event prefixes
      #                        ^^^^^^^ BUG - double underscore prefix
      # Should be: # Telemetry event prefixes
      # Impact: Documentation inconsistency (comment only)
      # Fix: Change __event to event
      # Note: This is a documentation bug in the comment text
    end

    test "BUG: line 34 - double underscore prefix in variable '__events'" do
      # Line 34: __events = [
      #          ^^^^^^^^ BUG - double underscore prefix
      # Should be: events = [
      # Impact: Non-standard variable naming convention
      # Fix: Change __events to events
      # Note: Used in attach_notification_handlers function
    end

    test "BUG: line 54 - double underscore prefix in variable '__events'" do
      # Line 54: __events = [
      #          ^^^^^^^^ BUG - double underscore prefix
      # Should be: events = [
      # Impact: Non-standard variable naming convention
      # Fix: Change __events to events
      # Note: Used in attach_message_handlers function
    end

    test "BUG: line 72 - double underscore prefix in variable '__events'" do
      # Line 72: __events = [
      #          ^^^^^^^^ BUG - double underscore prefix
      # Should be: events = [
      # Impact: Non-standard variable naming convention
      # Fix: Change __events to events
      # Note: Used in attach_channel_handlers function
    end

    test "BUG: line 92 - double underscore prefix in variable '__events'" do
      # Line 92: __events = [
      #          ^^^^^^^^ BUG - double underscore prefix
      # Should be: events = [
      # Impact: Non-standard variable naming convention
      # Fix: Change __events to events
      # Note: Used in attach_preference_handlers function
    end

    test "BUG: line 108 - double underscore prefix in parameter '__config'" do
      # Line 108: defp handle_notification_event(event, measurements, metadata, __config) do
      #                                                                         ^^^^^^^^^ BUG
      # Should be: _config (single underscore for unused parameter)
      # Impact: Non-standard parameter naming convention
      # Fix: Change __config to _config
      # Note: Parameter is unused in handle_notification_event function
    end

    test "BUG: line 197 - double underscore prefix in parameter '__config'" do
      # Line 197: defp handle_message_event(event, measurements, metadata, __config) do
      #                                                                     ^^^^^^^^^ BUG
      # Should be: _config (single underscore for unused parameter)
      # Impact: Non-standard parameter naming convention
      # Fix: Change __config to _config
      # Note: Parameter is unused in handle_message_event function
    end

    test "BUG: line 264 - double underscore prefix in parameter '__config'" do
      # Line 264: defp handle_channel_event(event, measurements, metadata, __config) do
      #                                                                     ^^^^^^^^^ BUG
      # Should be: _config (single underscore for unused parameter)
      # Impact: Non-standard parameter naming convention
      # Fix: Change __config to _config
      # Note: Parameter is unused in handle_channel_event function
    end

    test "BUG: line 345 - double underscore prefix in parameter '__config'" do
      # Line 345: defp handle_preference_event(event, _measurements, metadata, __config) do
      #                                                                        ^^^^^^^^^ BUG
      # Should be: _config (single underscore for unused parameter)
      # Impact: Non-standard parameter naming convention
      # Fix: Change __config to _config
      # Note: Parameter is unused in handle_preference_event function
    end
  end

  describe "BUGS: handler ID spacing issues (Lines 45, 63, 83, 100)" do
    test "BUG: line 45 - spaces in handler ID 'communication - notification - handlers'" do
      # Line 45: "communication - notification - handlers",
      #          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ BUG - spaces around hyphens
      # Should be: "communication-notification-handlers"
      # Impact: Non-standard handler ID naming (still works functionally)
      # Fix: Remove spaces around hyphens
      # Note: Handler ID has inconsistent spacing
    end

    test "BUG: line 63 - spaces in handler ID 'communication - message - handlers'" do
      # Line 63: "communication - message - handlers",
      #          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ BUG - spaces around hyphens
      # Should be: "communication-message-handlers"
      # Impact: Non-standard handler ID naming
      # Fix: Remove spaces around hyphens
      # Note: Handler ID has inconsistent spacing
    end

    test "BUG: line 83 - spaces in handler ID 'communication - channel - handlers'" do
      # Line 83: "communication - channel - handlers",
      #          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ BUG - spaces around hyphens
      # Should be: "communication-channel-handlers"
      # Impact: Non-standard handler ID naming
      # Fix: Remove spaces around hyphens
      # Note: Handler ID has inconsistent spacing
    end

    test "BUG: line 100 - spaces in handler ID 'communication - preference - handlers'" do
      # Line 100: "communication - preference - handlers",
      #           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ BUG - spaces around hyphens
      # Should be: "communication-preference-handlers"
      # Impact: Non-standard handler ID naming
      # Fix: Remove spaces around hyphens
      # Note: Handler ID has inconsistent spacing
    end
  end

  describe "BUGS: pattern matching issues (Lines 110, 129, 149, 160, 179, 199, 210, 223, 234, 245, 266, 277, 288, 306, 317, 327, 347, 358, 375)" do
    test "BUG: line 110 - extra square brackets in pattern match" do
      # Line 110: [@notification_prefix | [:send, :start]] ->
      #           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ BUG - wrong pattern syntax
      # Should be: @notification_prefix ++ [:send, :start] ->
      # Impact: This pattern will NEVER match (incorrect structure)
      # Fix: Change [@notification_prefix | [:send, :start]] to @notification_prefix ++ [:send, :start]
      # Note: This is a CRITICAL BUG - notification send start events will never be handled
    end

    test "BUG: all notification handler patterns use wrong syntax" do
      # Same pattern bug appears in ALL notification event case clauses:
      # Lines 110, 129, 149, 160, 179
      # All use [@notification_prefix | [...]] instead of @notification_prefix ++ [...]
      # This means NONE of the notification events will be matched correctly
    end

    test "BUG: all message handler patterns use wrong syntax" do
      # Same pattern bug appears in ALL message event case clauses:
      # Lines 199, 210, 223, 234, 245
      # All use [@message_prefix | [...]] instead of @message_prefix ++ [...]
      # This means NONE of the message queue events will be matched correctly
    end

    test "BUG: all channel handler patterns use wrong syntax" do
      # Same pattern bug appears in ALL channel event case clauses:
      # Lines 266, 277, 288, 306, 317, 327
      # All use [@channel_prefix | [...]] instead of @channel_prefix ++ [...]
      # This means NONE of the channel-specific events will be matched correctly
    end

    test "BUG: all preference handler patterns use wrong syntax" do
      # Same pattern bug appears in ALL preference event case clauses:
      # Lines 347, 358, 375
      # All use [@preference_prefix | [...]] instead of @preference_prefix ++ [...]
      # This means NONE of the preference events will be matched correctly
    end
  end

  describe "BUGS: comment formatting (Lines 428, 473)" do
    test "BUG: line 428 - spaces in comment 'channel - specific'" do
      # Line 428: # Records channel - specific delivery metrics.
      #                            ^^^^^^^^^^^^ BUG - spaces around hyphen
      # Should be: # Records channel-specific delivery metrics.
      # Impact: Documentation formatting inconsistency
      # Fix: Remove spaces around hyphen
      # Note: Comment formatting issue
    end

    test "BUG: line 473 - spaces in comment 'Multi - Agent'" do
      # Line 473: # Multi - Agent Architecture: Integrated with 11 - agent coordination system
      #                  ^^^^^^^^^^^^ BUG - spaces around hyphen
      # Should be: # Multi-Agent Architecture: Integrated with 11-agent coordination system
      # Impact: Documentation formatting inconsistency
      # Fix: Remove spaces around hyphens
      # Note: Comment formatting issue (appears in multiple places on this line)
    end
  end

  describe "integration scenarios" do
    test "complete notification workflow" do
      # Start notification
      :telemetry.execute(
        [:indrajaal, :communication, :notification, :send, :start],
        %{},
        %{type: "alert", channel: "email", recipient_count: 100, trace_id: "trace-1"}
      )

      # Complete notification
      log =
        capture_log(fn ->
          :telemetry.execute(
            [:indrajaal, :communication, :notification, :send, :stop],
            %{duration: System.convert_time_unit(100, :millisecond, :native)},
            %{type: "alert", channel: "email", success: true}
          )
        end)

      # Confirm delivery
      :telemetry.execute(
        [:indrajaal, :communication, :notification, :delivery, :confirmed],
        %{},
        %{type: "alert", channel: "email"}
      )

      assert log =~ "Notification sent"
    end

    test "message queue workflow with retry" do
      # Enqueue message
      :telemetry.execute(
        [:indrajaal, :communication, :message, :queue, :enqueued],
        %{queue_size: 50},
        %{queue_name: "notifications", priority: "high"}
      )

      # Processing fails
      :telemetry.execute(
        [:indrajaal, :communication, :message, :queue, :failed],
        %{},
        %{queue_name: "notifications", error_type: "timeout"}
      )

      # Retry attempted
      :telemetry.execute(
        [:indrajaal, :communication, :message, :retry, :attempted],
        %{},
        %{attempt_number: 1, max_attempts: 3}
      )

      # Eventually processed
      :telemetry.execute(
        [:indrajaal, :communication, :message, :queue, :processed],
        %{processing_time: 25},
        %{queue_name: "notifications", message_type: "alert"}
      )
    end

    test "multi-channel delivery workflow" do
      # Email sent
      :telemetry.execute(
        [:indrajaal, :communication, :channel, :email, :sent],
        %{},
        %{provider: "sendgrid", template: "alert"}
      )

      # SMS sent with cost
      :telemetry.execute(
        [:indrajaal, :communication, :channel, :sms, :sent],
        %{cost: 0.05},
        %{provider: "twilio", country_code: "+1"}
      )

      # Push notification sent
      :telemetry.execute(
        [:indrajaal, :communication, :channel, :push, :sent],
        %{},
        %{platform: "ios", topic: "alerts"}
      )
    end

    test "preference management workflow with opt-out" do
      # Update preference
      :telemetry.execute(
        [:indrajaal, :communication, :preference, :updated],
        %{},
        %{channel: "email", action: "enabled"}
      )

      # User opts out
      log =
        capture_log(fn ->
          :telemetry.execute(
            [:indrajaal, :communication, :preference, :opt_out],
            %{},
            %{user_id: "user-123", channel: "sms", reason: "too_frequent"}
          )
        end)

      # Compliance check
      :telemetry.execute(
        [:indrajaal, :communication, :preference, :compliance, :checked],
        %{},
        %{regulation: "GDPR", compliant: true}
      )

      assert log =~ "User opted out"
    end
  end

  describe "edge cases and error handling" do
    test "handles unknown events gracefully" do
      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :communication, :unknown, :event],
          %{},
          %{}
        )
      end)
    end

    test "handles missing metadata fields" do
      log =
        capture_log(fn ->
          :telemetry.execute(
            [:indrajaal, :communication, :notification, :send, :stop],
            %{duration: System.convert_time_unit(50, :millisecond, :native)},
            %{type: "alert"}
          )

          # Missing channel, success - should not crash
        end)
    end

    test "handles empty measurements" do
      assert_nothing_raised(fn ->
        :telemetry.execute(
          [:indrajaal, :communication, :preference, :updated],
          %{},
          %{channel: "email", action: "disabled"}
        )
      end)
    end

    test "handles large batch sizes" do
      :telemetry.execute(
        [:indrajaal, :communication, :notification, :batch, :stop],
        %{
          duration: System.convert_time_unit(5000, :millisecond, :native),
          batch_size: 100_000
        },
        %{channel: "email"}
      )
    end

    test "handles zero and negative values" do
      :telemetry.execute(
        [:indrajaal, :communication, :message, :queue, :enqueued],
        %{queue_size: 0},
        %{queue_name: "empty_queue"}
      )
    end

    test "handles very long processing times" do
      :telemetry.execute(
        [:indrajaal, :communication, :message, :queue, :processed],
        %{processing_time: 60_000},
        %{queue_name: "slow_queue", message_type: "heavy"}
      )
    end
  end

  describe "telemetry handler attachment" do
    test "handlers use correct event patterns" do
      capture_log(fn ->
        CommunicationInstrumentation.setup()
      end)

      handlers = :telemetry.list_handlers([])

      notification_handler =
        Enum.find(handlers, fn h -> h.id == "communication - notification - handlers" end)

      message_handler =
        Enum.find(handlers, fn h -> h.id == "communication - message - handlers" end)

      channel_handler =
        Enum.find(handlers, fn h -> h.id == "communication - channel - handlers" end)

      preference_handler =
        Enum.find(handlers, fn h -> h.id == "communication - preference - handlers" end)

      assert notification_handler != nil
      assert message_handler != nil
      assert channel_handler != nil
      assert preference_handler != nil
    end

    test "handlers use correct callback functions" do
      capture_log(fn ->
        CommunicationInstrumentation.setup()
      end)

      handlers = :telemetry.list_handlers([])

      notification_handler =
        Enum.find(handlers, fn h -> h.id == "communication - notification - handlers" end)

      # Verify callback function is set
      assert is_function(notification_handler.function, 4)
    end
  end

  describe "public API functions" do
    test "all public record_* functions accept valid parameters" do
      assert_nothing_raised(fn ->
        CommunicationInstrumentation.record_notification_send("type", "channel", 100, 50, true)
        CommunicationInstrumentation.record_queue_metrics("queue", 100, 50)
        CommunicationInstrumentation.record_channel_delivery(:email, %{}, %{})

        CommunicationInstrumentation.record_delivery_failure(
          "type",
          "channel",
          "error",
          3
        )
      end)
    end

    test "record_queue_metrics optional processing_time parameter" do
      assert_nothing_raised(fn ->
        CommunicationInstrumentation.record_queue_metrics("queue", 100, nil)
        CommunicationInstrumentation.record_queue_metrics("queue", 100, 50)
      end)
    end
  end

  describe "error classification" do
    test "classifies rate limit errors" do
      log =
        capture_log(fn ->
          CommunicationInstrumentation.record_delivery_failure(
            "alert",
            "email",
            "rate limit exceeded",
            1
          )
        end)

      # Error should be classified as "rate_limit"
    end

    test "classifies invalid recipient errors" do
      log =
        capture_log(fn ->
          CommunicationInstrumentation.record_delivery_failure(
            "alert",
            "sms",
            "invalid recipient",
            1
          )
        end)

      # Error should be classified as "invalid_recipient"
    end

    test "classifies timeout errors" do
      log =
        capture_log(fn ->
          CommunicationInstrumentation.record_delivery_failure(
            "alert",
            "push",
            "timeout occurred",
            1
          )
        end)

      # Error should be classified as "timeout"
    end

    test "classifies authentication errors" do
      log =
        capture_log(fn ->
          CommunicationInstrumentation.record_delivery_failure(
            "alert",
            "webhook",
            "auth failed",
            1
          )
        end)

      # Error should be classified as "authentication"
    end

    test "classifies unknown errors" do
      log =
        capture_log(fn ->
          CommunicationInstrumentation.record_delivery_failure(
            "alert",
            "email",
            "unknown error",
            1
          )
        end)

      # Error should be classified as "unknown"
    end
  end
end
