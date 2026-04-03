defmodule Intelitor.Alarms.NotificationOrchestrator do
  @moduledoc """
  Intelligent notification distribution system with multi-tier escalation,
  channel selection, and delivery tracking.
  """

  require Logger
  # These aliases will be available when implementing actual notification logic
  # alias Intelitor.Alarms
  # alias Intelitor.Accounts
  # alias Intelitor.Communication
  # alias Intelitor.Jobs # Available when Jobs module is implemented

  @escalation_timeouts %{
    # 1 minute
    critical: 60,
    # 3 minutes
    high: 180,
    # 5 minutes
    medium: 300,
    # 10 minutes
    low: 600
  }

  @doc """
  Orchestrate notifications for an alarm event.
  """
  def notify_for_alarm(alarm) do
    with {:ok, notification_plan} <- build_notification_plan(alarm),
         :ok <- validate_notification_plan(notification_plan) do
      # Execute notifications in priority order
      Enum.each(notification_plan.tiers, fn tier ->
        unless previous_tier_acknowledged?(alarm, tier) do
          execute_notification_tier(alarm, tier)

          # Schedule escalation if needed
          if tier.escalation_timeout do
            schedule_escalation(alarm, tier)
          end
        end
      end)

      :ok
    end
  end

  @doc """
  Handle notification acknowledgment.
  """
  def handle_acknowledgment(alarm_id, user_id) do
    # Cancel any pending escalations
    cancel_escalations(alarm_id)

    # Mark notifications as acknowledged
    mark_notifications_acknowledged(alarm_id, user_id)

    :ok
  end

  @doc """
  Get notification status for an alarm.
  """
  def get_notification_status(alarm_id) do
    # Stub implementation until Notifications resource is available
    Logger.debug("Getting notification status for alarm #{alarm_id}")

    # Future implementation:
    # notifications = Alarms.list_notifications(%{
    #   filters: %{alarm_event_id: alarm_id}
    # })

    notifications = []

    %{
      total_sent: length(notifications),
      delivered: Enum.count(notifications, & &1.delivered_at),
      read: Enum.count(notifications, & &1.read_at),
      channels: Enum.map(notifications, & &1.channel) |> Enum.uniq(),
      tiers_notified: Enum.map(notifications, & &1.metadata[:tier_level]) |> Enum.uniq()
    }
  end

  # Notification Planning

  defp build_notification_plan(alarm) do
    plan = %{
      alarm_id: alarm.id,
      alarm_severity: alarm.severity,
      created_at: DateTime.utc_now(),
      tiers: []
    }

    # Build tiers based on severity
    tiers =
      case alarm.severity do
        :critical -> build_critical_tiers(alarm)
        :high -> build_high_tiers(alarm)
        :medium -> build_medium_tiers(alarm)
        :low -> build_low_tiers(alarm)
      end

    {:ok, %{plan | tiers: tiers}}
  end

  defp build_critical_tiers(alarm) do
    [
      %{
        level: 1,
        recipients: get_primary_operators(alarm) ++ get_area_supervisors(alarm),
        channels: [:push, :sms, :voice],
        escalation_timeout: @escalation_timeouts.critical,
        message_template: :critical_alarm,
        require_acknowledgment: true
      },
      %{
        level: 2,
        recipients: get_all_supervisors() ++ get_site_managers(alarm),
        channels: [:sms, :voice, :email],
        escalation_timeout: @escalation_timeouts.critical,
        message_template: :critical_escalation,
        require_acknowledgment: true
      },
      %{
        level: 3,
        recipients: get_executive_contacts() ++ get_emergency_contacts(alarm),
        channels: [:voice, :sms],
        escalation_timeout: nil,
        message_template: :executive_alert,
        require_acknowledgment: true
      }
    ]
  end

  defp build_high_tiers(alarm) do
    [
      %{
        level: 1,
        recipients: get_primary_operators(alarm),
        channels: [:push, :sms],
        escalation_timeout: @escalation_timeouts.high,
        message_template: :high_priority_alarm,
        require_acknowledgment: true
      },
      %{
        level: 2,
        recipients: get_area_supervisors(alarm) ++ get_secondary_operators(alarm),
        channels: [:sms, :email, :push],
        escalation_timeout: @escalation_timeouts.high,
        message_template: :escalated_alarm,
        require_acknowledgment: true
      }
    ]
  end

  defp build_medium_tiers(alarm) do
    [
      %{
        level: 1,
        recipients: get_primary_operators(alarm),
        channels: [:push, :email],
        escalation_timeout: @escalation_timeouts.medium,
        message_template: :standard_alarm,
        require_acknowledgment: false
      },
      %{
        level: 2,
        recipients: get_area_supervisors(alarm),
        channels: [:email, :sms],
        escalation_timeout: nil,
        message_template: :supervisor_notification,
        require_acknowledgment: false
      }
    ]
  end

  defp build_low_tiers(alarm) do
    [
      %{
        level: 1,
        recipients: get_primary_operators(alarm),
        channels: [:push, :email],
        escalation_timeout: nil,
        message_template: :low_priority_alarm,
        require_acknowledgment: false
      }
    ]
  end

  # Notification Execution

  defp execute_notification_tier(alarm, tier) do
    Logger.info("Executing notification tier #{tier.level} for alarm #{alarm.id}")

    Enum.each(tier.recipients, fn recipient ->
      # Get recipient's active channels based on preferences and availability
      active_channels = get_active_channels(recipient, tier.channels)

      Enum.each(active_channels, fn channel ->
        # Use Task for async notification sending
        Task.start(fn ->
          send_notification(%{
            alarm_event_id: alarm.id,
            recipient_id: recipient.id,
            channel: channel,
            priority: alarm_severity_to_priority(alarm.severity),
            content: render_message(tier.message_template, alarm, channel),
            metadata: %{
              tier_level: tier.level,
              requires_acknowledgment: tier.require_acknowledgment,
              template: tier.message_template
            }
          })
        end)
      end)
    end)
  end

  defp send_notification(attrs) do
    Logger.info("Sending notification", %{
      recipient_id: attrs.recipient_id,
      channel: attrs.channel,
      priority: attrs.priority,
      alarm_event_id: attrs.alarm_event_id
    })

    # Stub implementation until Notifications resource is available
    notification = Map.put(attrs, :id, Ecto.UUID.generate())

    with {:ok, notification} <- {:ok, notification},
         {:ok, _} <- deliver_notification(notification) do
      # Update delivery timestamp (stub implementation)
      delivered_notification = Map.put(notification, :delivered_at, DateTime.utc_now())

      Logger.debug("Notification delivered", %{
        notification_id: notification.id,
        channel: notification.channel,
        delivered_at: delivered_notification.delivered_at
      })

      # Future implementation:
      # Alarms.update_notification(notification, %{
      #   delivered_at: DateTime.utc_now()
      # })

      {:ok, delivered_notification}
    else
      error ->
        Logger.error("Failed to send notification: #{inspect(error)}")
        error
    end
  end

  defp deliver_notification(notification) do
    case notification.channel do
      :email ->
        Logger.info("Delivering email notification", %{
          notification_id: notification.id,
          recipient_id: notification.recipient_id
        })

        # Future: Communication.send_email(notification)
        {:ok, :sent}

      :sms ->
        Logger.info("Delivering SMS notification", %{
          notification_id: notification.id,
          recipient_id: notification.recipient_id
        })

        # Future: Communication.send_sms(notification)
        {:ok, :sent}

      :push ->
        Logger.info("Delivering push notification", %{
          notification_id: notification.id,
          recipient_id: notification.recipient_id
        })

        # Future: Communication.send_push_notification(notification)
        {:ok, :sent}

      :voice ->
        Logger.info("Delivering voice notification", %{
          notification_id: notification.id,
          recipient_id: notification.recipient_id
        })

        # Future: Communication.make_voice_call(notification)
        {:ok, :sent}

      channel ->
        Logger.error("Unsupported notification channel: #{channel}")
        {:error, :unsupported_channel}
    end
  end

  # Recipient Selection

  defp get_primary_operators(alarm) do
    Logger.debug("Getting primary operators for site #{alarm.site_id}")

    # Stub implementation until Users/Accounts integration is available
    # Future implementation:
    # Accounts.list_users(%{
    #   filters: %{
    #     roles: ["operator"],
    #     site_id: alarm.site_id,
    #     on_duty: true
    #   }
    # })

    # Return empty list for now - prevents notification errors
    []
  end

  defp get_secondary_operators(alarm) do
    Logger.debug("Getting secondary operators for site #{alarm.site_id}")

    # Stub implementation until Users/Accounts integration is available
    # Future implementation:
    # Accounts.list_users(%{
    #   filters: %{
    #     roles: ["operator"],
    #     site_id: alarm.site_id,
    #     on_call: true
    #   }
    # })

    # Return empty list for now - prevents notification errors
    []
  end

  defp get_area_supervisors(alarm) do
    Logger.debug("Getting area supervisors for site #{alarm.site_id}")

    # Stub implementation until Users/Accounts integration is available
    # Future implementation:
    # Accounts.list_users(%{
    #   filters: %{
    #     roles: ["supervisor"],
    #     site_id: alarm.site_id
    #   }
    # })

    # Return empty list for now - prevents notification errors
    []
  end

  defp get_all_supervisors() do
    Logger.debug("Getting all supervisors")

    # Stub implementation until Users/Accounts integration is available
    # Future implementation:
    # Accounts.list_users(%{
    #   filters: %{roles: ["supervisor"]}
    # })

    # Return empty list for now - prevents notification errors
    []
  end

  defp get_site_managers(_alarm) do
    # This would fetch actual site managers
    []
  end

  defp get_executive_contacts() do
    Logger.debug("Getting executive contacts")

    # Stub implementation until Users/Accounts integration is available
    # Future implementation:
    # Accounts.list_users(%{
    #   filters: %{roles: ["executive"]}
    # })

    # Return empty list for now - prevents notification errors
    []
  end

  defp get_emergency_contacts(_alarm) do
    # This would fetch configured emergency contacts
    []
  end

  # Channel Management

  defp get_active_channels(recipient, requested_channels) do
    user_preferences = get_user_notification_preferences(recipient)
    current_time = DateTime.utc_now()

    # Filter channels based on user preferences and availability
    requested_channels
    |> Enum.filter(fn channel ->
      channel_enabled?(channel, user_preferences) &&
        not in_quiet_hours?(current_time, user_preferences) &&
        channel_available?(channel, recipient)
    end)
    |> prioritize_channels(user_preferences)
  end

  defp channel_enabled?(channel, preferences) do
    Map.get(preferences.enabled_channels || %{}, channel, true)
  end

  defp in_quiet_hours?(datetime, preferences) do
    if preferences[:quiet_hours_enabled] do
      current_time = DateTime.to_time(datetime)
      quiet_start = preferences[:quiet_hours_start] || ~T[22:00:00]
      quiet_end = preferences[:quiet_hours_end] || ~T[07:00:00]

      if Time.compare(quiet_start, quiet_end) == :gt do
        # Quiet hours span midnight
        Time.compare(current_time, quiet_start) != :lt ||
          Time.compare(current_time, quiet_end) != :gt
      else
        Time.compare(current_time, quiet_start) != :lt &&
          Time.compare(current_time, quiet_end) != :gt
      end
    else
      false
    end
  end

  defp channel_available?(channel, recipient) do
    case channel do
      :push -> user_has_active_app_session?(recipient)
      :voice -> user_phone_available?(recipient)
      _ -> true
    end
  end

  defp prioritize_channels(channels, preferences) do
    priority_order = preferences[:channel_priority] || [:push, :sms, :voice, :email]

    Enum.sort_by(channels, fn channel ->
      Enum.find_index(priority_order, &(&1 == channel)) || 999
    end)
  end

  # Message Rendering

  defp render_message(template, alarm, channel) do
    base_content = get_template_content(template, alarm)

    case channel do
      :sms -> truncate_for_sms(base_content)
      :voice -> convert_to_speech_text(base_content)
      :push -> format_for_push(base_content)
      :email -> format_as_html_email(base_content)
      _ -> base_content
    end
  end

  defp get_template_content(template, alarm) do
    case template do
      :critical_alarm ->
        "CRITICAL ALARM: #{alarm.event_type} at #{alarm.location_details}. Immediate response required!"

      :high_priority_alarm ->
        "HIGH PRIORITY: #{alarm.event_type} alarm at #{alarm.location_details}. Please acknowledge."

      :standard_alarm ->
        "Alarm: #{alarm.event_type} detected at #{alarm.location_details}"

      :escalated_alarm ->
        "ESCALATED: Alarm #{alarm.id} requires immediate attention. No response received."

      :executive_alert ->
        "EXECUTIVE ALERT: Critical security incident at #{alarm.site.name}. Multiple escalations failed."

      _ ->
        "Security alarm at #{alarm.location_details}"
    end
  end

  defp truncate_for_sms(content) do
    if String.length(content) > 160 do
      String.slice(content, 0, 157) <> "..."
    else
      content
    end
  end

  defp convert_to_speech_text(content) do
    # Convert to speech-friendly format
    content
    |> String.replace(":", " ")
    |> String.replace("-", " ")
    |> String.downcase()
  end

  defp format_for_push(content) do
    %{
      title: "Security Alert",
      body: content,
      data: %{
        type: "alarm",
        priority: "high"
      }
    }
  end

  defp format_as_html_email(content) do
    """
    <html>
      <body>
        <h2>Security Alarm Notification</h2>
        <p>#{content}</p>
        <p>Please log in to the security system for more details.</p>
      </body>
    </html>
    """
  end

  # Escalation Management

  defp schedule_escalation(alarm, tier) do
    Intelitor.Jobs.AlarmEscalation.new(%{
      alarm_id: alarm.id,
      current_tier: tier.level,
      next_tier: tier.level + 1
    })
    |> Oban.insert(scheduled_at: tier.escalation_timeout)
  end

  defp cancel_escalations(alarm_id) do
    Logger.info("Cancelling escalations for alarm #{alarm_id}")

    # Stub implementation until Oban job management is available
    # Future implementation:
    # Oban.cancel_all_jobs(
    #   Jobs.AlarmEscalation,
    #   %{alarm_id: alarm_id}
    # )

    :ok
  end

  # Helper Functions

  defp validate_notification_plan(plan) do
    cond do
      Enum.empty?(plan.tiers) ->
        {:error, :no_notification_tiers}

      Enum.any?(plan.tiers, fn tier -> Enum.empty?(tier.recipients) end) ->
        {:error, :no_recipients_configured}

      true ->
        :ok
    end
  end

  defp previous_tier_acknowledged?(alarm, tier) do
    tier.level > 1 && alarm.state in [:acknowledged, :investigating, :resolved]
  end

  defp alarm_severity_to_priority(severity) do
    case severity do
      :critical -> :urgent
      :high -> :high
      :medium -> :normal
      :low -> :low
    end
  end

  defp mark_notifications_acknowledged(alarm_id, user_id) do
    Logger.info("Marking notifications acknowledged", %{
      alarm_id: alarm_id,
      user_id: user_id
    })

    # Stub implementation until Notifications resource is available
    # Future implementation:
    # notifications = Alarms.list_notifications(%{
    #   filters: %{
    #     alarm_event_id: alarm_id,
    #     recipient_id: user_id
    #   }
    # })

    notifications = []

    Enum.each(notifications, fn notification ->
      Logger.debug("Marking notification as acknowledged", %{
        notification_id: notification.id,
        read_at: DateTime.utc_now()
      })

      # Stub implementation until Notifications resource is available
      # Future implementation:
      # Alarms.update_notification(notification, %{
      #   read_at: DateTime.utc_now()
      # })

      {:ok, Map.put(notification, :read_at, DateTime.utc_now())}
    end)
  end

  defp get_user_notification_preferences(_user) do
    # This would fetch actual user preferences
    %{
      enabled_channels: %{
        email: true,
        sms: true,
        push: true,
        voice: false
      },
      quiet_hours_enabled: false,
      channel_priority: [:push, :sms, :email, :voice]
    }
  end

  defp user_has_active_app_session?(_user) do
    # This would check for active mobile app session
    true
  end

  defp user_phone_available?(_user) do
    # This would check phone availability
    true
  end
end
