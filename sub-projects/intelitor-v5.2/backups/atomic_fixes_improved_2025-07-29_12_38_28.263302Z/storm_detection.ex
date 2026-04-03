defmodule Intelitor.Alarms.StormDetection do
  @moduledoc """
  Detects and manages alarm storms to prevent system overload.
  Implements intelligent grouping and notification consolidation.
  """

  require Logger
  alias Intelitor.Alarms
  # alias Intelitor.Communication

  # alarms per minute
  @storm_threshold 50
  # seconds
  @storm_window 60
  # @recovery_window 900 # 15 minutes

  @doc """
  Check for alarm storm conditions for a tenant.
  """
  def detect_storm(tenant_id) do
    alarm_count = count_recent_alarms(tenant_id, @storm_window)

    if alarm_count > @storm_threshold do
      handle_alarm_storm(tenant_id, alarm_count)
    else
      check_storm_recovery(tenant_id)
    end

    :ok
  end

  @doc """
  Get current storm status for a tenant.
  """
  def get_storm_status(tenant_id) do
    case get_storm_state(tenant_id) do
      nil ->
        %{
          active: false,
          alarm_count: count_recent_alarms(tenant_id, @storm_window),
          threshold: @storm_threshold
        }

      state ->
        %{
          active: true,
          started_at: state.started_at,
          alarm_count: state.alarm_count,
          threshold: @storm_threshold,
          mode: state.mode,
          consolidated_count: state.consolidated_count
        }
    end
  end

  @doc """
  Manually activate storm mode (for testing or emergency).
  """
  def activate_storm_mode(tenant_id, reason \\ "Manual activation") do
    Logger.warning("Manually activating storm mode for tenant #{tenant_id}: #{reason}")

    apply_storm_mode_settings(tenant_id, %{
      mode: :manual,
      reason: reason,
      alarm_count: 0
    })
  end

  @doc """
  Manually deactivate storm mode.
  """
  def deactivate_storm_mode(tenant_id) do
    Logger.info("Deactivating storm mode for tenant #{tenant_id}")

    clear_storm_state(tenant_id)
    restore_normal_operations(tenant_id)

    :ok
  end

  # Storm Handling

  defp handle_alarm_storm(tenant_id, alarm_count) do
    Logger.warning(
      "Alarm storm detected for tenant #{tenant_id}: #{alarm_count} alarms in #{@storm_window}s"
    )

    # Check if already in storm mode
    case get_storm_state(tenant_id) do
      nil ->
        # First detection - activate storm mode
        activate_new_storm(tenant_id, alarm_count)

      existing_state ->
        # Already in storm mode - update severity
        update_storm_severity(tenant_id, existing_state, alarm_count)
    end
  end

  defp activate_new_storm(tenant_id, alarm_count) do
    storm_state = %{
      tenant_id: tenant_id,
      started_at: DateTime.utc_now(),
      alarm_count: alarm_count,
      mode: determine_storm_mode(alarm_count),
      consolidated_count: 0,
      last_update: DateTime.utc_now()
    }

    # Store storm state
    set_storm_state(tenant_id, storm_state)

    # Apply storm mode settings
    apply_storm_mode_settings(tenant_id, storm_state)

    # Create summary alarm
    create_storm_summary_alarm(tenant_id, alarm_count)

    # Notify operations team
    notify_operations_team(tenant_id, storm_state)
  end

  defp apply_storm_mode_settings(tenant_id, storm_state) do
    mode = storm_state.mode

    case mode do
      :light ->
        apply_light_storm_settings(tenant_id)

      :moderate ->
        apply_moderate_storm_settings(tenant_id)

      :severe ->
        apply_severe_storm_settings(tenant_id)

      :critical ->
        apply_critical_storm_settings(tenant_id)
    end

    # Schedule recovery check
    schedule_storm_recovery_check(tenant_id)
  end

  # Storm Mode Settings

  defp apply_light_storm_settings(tenant_id) do
    # Light storm: 50-100 alarms/minute
    %{
      # 15 seconds
      notification_batch_window: 15,
      notification_channels: [:dashboard, :email],
      alarm_grouping: true,
      auto_acknowledge_low: false,
      dispatch_threshold: :high
    }
    |> apply_settings(tenant_id)
  end

  defp apply_moderate_storm_settings(tenant_id) do
    # Moderate storm: 100-200 alarms/minute
    %{
      # 30 seconds
      notification_batch_window: 30,
      notification_channels: [:dashboard, :summary_email],
      alarm_grouping: true,
      auto_acknowledge_low: true,
      dispatch_threshold: :critical
    }
    |> apply_settings(tenant_id)
  end

  defp apply_severe_storm_settings(tenant_id) do
    # Severe storm: 200-500 alarms/minute
    %{
      # 60 seconds
      notification_batch_window: 60,
      notification_channels: [:dashboard],
      alarm_grouping: true,
      auto_acknowledge_low: true,
      auto_acknowledge_medium: true,
      dispatch_threshold: :critical_only
    }
    |> apply_settings(tenant_id)
  end

  defp apply_critical_storm_settings(tenant_id) do
    # Critical storm: 500+ alarms/minute
    %{
      # 2 minutes
      notification_batch_window: 120,
      notification_channels: [:summary_only],
      alarm_grouping: true,
      auto_acknowledge_low: true,
      auto_acknowledge_medium: true,
      dispatch_threshold: :none,
      emergency_mode: true
    }
    |> apply_settings(tenant_id)
  end

  # Alarm Consolidation

  # defp consolidate_pending_notifications(tenant_id) do
  #   # Get pending notifications
  #   pending = get_pending_notifications(tenant_id)
  #
  #   if length(pending) > 10 do
  #     # Group by recipient and priority
  #     grouped = Enum.group_by(pending, fn n ->
  #       {n.recipient_id, n.priority}
  #     end)
  #
  #     # Create consolidated notifications
  #     Enum.each(grouped, fn {{recipient_id, priority}, notifications} ->
  #       create_consolidated_notification(recipient_id, priority, notifications)
  #
  #       # Cancel individual notifications
  #       Enum.each(notifications, &cancel_notification/1)
  #     end)
  #
  #     Logger.info("Consolidated #{length(pending)} notifications into #{map_size(grouped)} summary notifications")
  #   end
  # end

  defp create_storm_summary_alarm(tenant_id, alarm_count) do
    Alarms.AlarmEvent.create(%{
      tenant_id: tenant_id,
      event_code: "STORM",
      event_type: :supervisory,
      severity: :high,
      priority: 8,
      site_id: get_primary_site(tenant_id),
      description: "Alarm storm detected: #{alarm_count} alarms in #{@storm_window} seconds",
      metadata: %{
        storm_detection: true,
        alarm_count: alarm_count,
        consolidation_active: true
      }
    })
  end

  # Intelligent Grouping

  # defp enable_intelligent_grouping(tenant_id) do
  #   # Configure grouping rules
  #   grouping_rules = [
  #     %{
  #       name: :location_grouping,
  #       group_by: [:site_id, :zone_id],
  #       window: 60,
  #       min_count: 3
  #     },
  #     %{
  #       name: :device_grouping,
  #       group_by: [:device_id],
  #       window: 30,
  #       min_count: 5
  #     },
  #     %{
  #       name: :type_grouping,
  #       group_by: [:event_type],
  #       window: 120,
  #       min_count: 10
  #     }
  #   ]
  #
  #   apply_grouping_rules(tenant_id, grouping_rules)
  # end

  # Recovery Management

  defp check_storm_recovery(tenant_id) do
    case get_storm_state(tenant_id) do
      nil ->
        :ok

      state ->
        current_count = count_recent_alarms(tenant_id, @storm_window)

        if current_count < @storm_threshold * 0.5 do
          # Alarm rate has dropped significantly
          initiate_storm_recovery(tenant_id, state)
        else
          # Still elevated but below storm threshold
          update_storm_state(tenant_id, %{state | alarm_count: current_count})
        end
    end
  end

  defp initiate_storm_recovery(tenant_id, storm_state) do
    duration = DateTime.diff(DateTime.utc_now(), storm_state.started_at)

    Logger.info("Initiating storm recovery for tenant #{tenant_id}. Storm duration: #{duration}s")

    # Gradually restore normal operations
    restore_normal_operations(tenant_id)

    # Generate storm report
    generate_storm_report(tenant_id, storm_state)

    # Clear storm state
    clear_storm_state(tenant_id)
  end

  defp restore_normal_operations(tenant_id) do
    %{
      # Immediate
      notification_batch_window: 0,
      notification_channels: :all,
      alarm_grouping: false,
      auto_acknowledge_low: false,
      auto_acknowledge_medium: false,
      dispatch_threshold: :normal
    }
    |> apply_settings(tenant_id)
  end

  # Helper Functions

  defp count_recent_alarms(tenant_id, window_seconds) do
    start_time = DateTime.add(DateTime.utc_now(), -window_seconds, :second)

    # Optimized count query for alarm storm detection
    case Alarms.AlarmEvent.list_alarm_events(%{
           filter: %{
             tenant_id: %{eq: tenant_id},
             triggered_at: %{gt: start_time}
           }
         }) do
      {:ok, alarms} ->
        count = length(alarms)

        Logger.debug(
          "Counted #{count} recent alarms for tenant #{tenant_id} in #{window_seconds}s window"
        )

        count

      {:error, reason} ->
        Logger.error("Failed to count recent alarms for tenant #{tenant_id}: #{inspect(reason)}")
        0
    end
  end

  defp determine_storm_mode(alarm_count) do
    cond do
      alarm_count >= 500 -> :critical
      alarm_count >= 200 -> :severe
      alarm_count >= 100 -> :moderate
      true -> :light
    end
  end

  defp get_storm_state(tenant_id) do
    # This would retrieve from cache/ETS/database
    Process.get({:storm_state, tenant_id})
  end

  defp set_storm_state(tenant_id, state) do
    Process.put({:storm_state, tenant_id}, state)
  end

  defp clear_storm_state(tenant_id) do
    Process.delete({:storm_state, tenant_id})
  end

  defp update_storm_state(tenant_id, state) do
    set_storm_state(tenant_id, %{state | last_update: DateTime.utc_now()})
  end

  defp update_storm_severity(tenant_id, existing_state, new_count) do
    new_mode = determine_storm_mode(new_count)

    if new_mode != existing_state.mode do
      Logger.warning("Storm severity changed from #{existing_state.mode} to #{new_mode}")

      updated_state = %{
        existing_state
        | mode: new_mode,
          alarm_count: new_count,
          last_update: DateTime.utc_now()
      }

      set_storm_state(tenant_id, updated_state)
      apply_storm_mode_settings(tenant_id, updated_state)
    else
      update_storm_state(tenant_id, %{existing_state | alarm_count: new_count})
    end
  end

  defp apply_settings(settings, tenant_id) do
    # This would apply the settings to the notification and dispatch systems
    Logger.debug("Applying storm settings for tenant #{tenant_id}: #{inspect(settings)}")
    :ok
  end

  defp schedule_storm_recovery_check(tenant_id) do
    # Schedule check in 1 minute
    Process.send_after(self(), {:check_storm_recovery, tenant_id}, 60_000)
  end

  defp notify_operations_team(tenant_id, storm_state) do
    # Log critical alarm storm event
    Logger.critical("Alarm storm detected for tenant #{tenant_id}", %{
      tenant_id: tenant_id,
      alarm_count: storm_state.alarm_count,
      storm_mode: storm_state.mode,
      started_at: storm_state.started_at,
      storm_window_seconds: @storm_window
    })

    # Emit telemetry for monitoring systems
    :telemetry.execute(
      [:intelitor, :alarm, :storm_detected],
      %{alarm_count: storm_state.alarm_count, storm_level: storm_mode_to_level(storm_state.mode)},
      %{tenant_id: tenant_id, storm_mode: storm_state.mode}
    )

    # Future: Implement actual notification via Communication domain
    # Communication.send_critical_alert(%{
    #   recipients: get_operations_contacts(),
    #   subject: "Alarm Storm Detected",
    #   message: "ALARM STORM DETECTED for tenant #{tenant_id}: #{storm_state.alarm_count} alarms in #{@storm_window}s. Storm mode: #{storm_state.mode}. Mitigation measures applied.",
    #   priority: :urgent
    # })

    :ok
  end

  defp generate_storm_report(tenant_id, storm_state) do
    duration = DateTime.diff(DateTime.utc_now(), storm_state.started_at)

    report = %{
      tenant_id: tenant_id,
      storm_started: storm_state.started_at,
      storm_ended: DateTime.utc_now(),
      duration_seconds: duration,
      peak_alarm_count: storm_state.alarm_count,
      mode: storm_state.mode,
      consolidated_notifications: storm_state.consolidated_count,
      mitigation_applied: true
    }

    # Store report for analysis
    Logger.info("Storm report: #{inspect(report)}")

    report
  end

  # defp get_pending_notifications(_tenant_id) do
  #   # This would fetch actual pending notifications
  #   []
  # end

  # defp create_consolidated_notification(recipient_id, priority, notifications) do
  #   alarm_count = length(notifications)
  #   alarm_types = notifications
  #                |> Enum.map(& &1.metadata[:event_type])
  #                |> Enum.frequencies()
  #
  #   Communication.send_notification(%{
  #     recipient_id: recipient_id,
  #     channel: :email,
  #     priority: priority,
  #     subject: "Alarm Storm Alert - #{alarm_count} alarms",
  #     content: """
  #     Multiple alarms have been triggered:
  #
  #     Total alarms: #{alarm_count}
  #     Types: #{inspect(alarm_types)}
  #
  #     Please check the security dashboard for details.
  #     Individual notifications have been suppressed during the alarm storm.
  #     """
  #   })
  #   :ok
  # end

  # defp cancel_notification(_notification) do
  #   # This would cancel the notification
  #   :ok
  # end

  defp get_primary_site(_tenant_id) do
    # This would get the primary site for the tenant
    Ecto.UUID.generate()
  end

  # defp get_operations_contacts do
  #   # This would fetch operations team contacts
  #   []
  # end

  # defp apply_grouping_rules(tenant_id, _rules) do
  #   # This would configure the grouping engine
  #   Logger.debug("Applying grouping rules for tenant #{tenant_id}")
  #   :ok
  # end

  defp storm_mode_to_level(mode) do
    case mode do
      :critical -> 4
      :severe -> 3
      :moderate -> 2
      :light -> 1
      :manual -> 0
    end
  end
end
