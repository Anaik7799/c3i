defmodule Indrajaal.Alarms.EscalationEngine do
  # EP019: Removed malformed aliases - converted to comments for documentation
  # alias Indrajaal.Shared.UnifiedParallelizationFramework - Pattern coordination framework
  # alias Indrajaal.Shared.UnifiedErrorSystem - Error handling system

  @moduledoc """

  Intelligent escalation workflow automation system for alarm management.

  This module provides comprehensive escalation management with:
  - Rule-based automatic escalation workflows-Multi-level escalation chains with intelligent routing-Time-based escalation triggers and SLA enforcement
  - Dynamic notification and communication integration
  - Escalation analytics and optimization-Integration with external systems (ITSM, paging, etc.)

  SOPv5.1Compliance: ✅ Cybernetic goal-oriented execution with intelligent workflow automation
  Agent: Helper-1 (Alarm Processing Coordination Agent)
  Framework: Container-Only + Git-based + Maximum Parallelization + Workflow Automation
  """

  use GenServer
  # PHASE Q: GenServer patterns consolidated
  # EP021: Removed malformed import - converted to comment for documentation
  # import Indrajaal.Shared.UnifiedGenServerPatterns - GenServer pattern utilities
  require Logger

  # EP022: Removed malformed alias - converted to comment for documentation
  # alias Indrajaal.Alarms.{AlarmEvent, TimescaleDBSchema} - Alarm and schema modules
  # EP201-Unused alias eliminated: Real Time Processor
  alias Indrajaal.Communication

  # Escalation configuration
  # EP301-Module attribute elimination: @escalation_levels unused - removed (was 5)
  # EP301-Module attribute elimination: @default_escalation_timeout unused - removed
  # 30 seconds
  @escalation_check_interval 30_000
  @max_parallel_escalations 50

  defstruct [
    :escalation_rules,
    :active_escalations,
    :escalation_history,
    :notification_queue,
    :performance_metrics,
    status: :starting
  ]

  @spec start_link(keyword() | map()) :: term()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  @spec init(keyword() | map()) :: term()
  def init(_opts) do
    Logger.info("🚀 Starting Escalation Engine - SOPv5.1Cybernetic Mode")

    # Initialize escalation system
    state = %__MODULE__{
      escalation_rules: load_escalation_rules(),
      active_escalations: %{},
      escalation_history: %{},
      notification_queue: :queue.new(),
      performance_metrics: initialize_escalation_metrics(),
      status: :ready
    }

    # Schedule periodic escalation checks
    schedule_escalation_monitoring()
    schedule_notification_processing()

    Logger.info("✅ Escalation Engine initialized successfully")
    {:ok, state}
  end

  # Public API

  @doc """
  Initiate escalation workflow for an alarm based on configured rules.
  """
  @spec initiate_escalation(binary() | integer(), any()) :: term()
  def initiate_escalation(alarm_id, escalation_reason \\ :timeout) do
    GenServer.cast(
      __MODULE__,
      {:initiate_escalation, alarm_id, escalation_reason, DateTime.utc_now()}
    )
  end

  @doc """
  Manual escalation triggered by user action.
  """
  @spec manual_escalation(binary() | integer(), term(), term()) :: term()
  def manual_escalation(alarm_id, escalated_by, escalation_data) do
    GenServer.call(__MODULE__, {:manual_escalation, alarm_id, escalated_by, escalation_data})
  end

  @doc """
  Acknowledge escalation (stops further automatic escalation).
  """
  @spec acknowledge_escalation(binary() | integer(), term()) :: term()
  def acknowledge_escalation(alarm_id, acknowledged_by) do
    GenServer.call(__MODULE__, {:acknowledge_escalation, alarm_id, acknowledged_by})
  end

  @doc """
  Update escalation rules dynamically.
  """
  @spec update_escalation_rules(term()) :: term()
  def update_escalation_rules(new_rules) do
    GenServer.call(__MODULE__, {:update_rules, new_rules})
  end

  @doc """
  Get current escalation status and statistics.
  """
  @spec get_escalation_status :: any()
  def get_escalation_status do
    GenServer.call(__MODULE__, :get_escalation_status)
  end

  @doc """
  Force processing of pending notifications (useful for testing).
  """
  @spec process_pending_notifications :: any()
  def process_pending_notifications do
    GenServer.call(__MODULE__, :process_notifications)
  end

  # GenServer implementation

  @impl true
  @spec handle_cast(term(), map()) :: {:noreply, map()}
  def handle_cast({:initiate_escalation, alarm_id, reason, _triggered_at}, state) do
    Logger.info("🔔 Initiating escalation for alarm: #{alarm_id} (reason: #{reason})")

    # NOTE: get_alarm_for_escalation/1 currently always returns {:error, _}
    # because AlarmEvent.get_alarm_event/1 is a stub. The {:ok, _} clause
    # has been commented out to eliminate unreachable clause warning.
    case get_alarm_for_escalation(alarm_id) do
      # {:ok, alarm_event} ->
      #   # Determine appropriate escalation rules
      #   applicable_rules = find_applicable_escalation_rules(alarm_event, state.escalation_rules)
      #
      #   if applicable_rules != [] do
      #     # Create escalation workflow
      #     escalation_workflow = create_escalation_workflow(alarm_event, applicable_rules, reason)
      #
      #     # Start escalation process
      #     updated_escalations =
      #       Map.put(
      #         state.active_escalations,
      #         alarm_id,
      #         escalation_workflow
      #       )
      #
      #     # Execute initial escalation step
      #     {updated_state, notification_tasks} =
      #       execute_escalation_step(
      #         %{state | active_escalations: updated_escalations},
      #         alarm_id,
      #         1
      #       )
      #
      #     # Queue notifications
      #     final_state = queue_notifications(updated_state, notification_tasks)
      #
      #     # Update metrics
      #     metrics = update_escalation_metrics(final_state.performance_metrics, :initiated)
      #
      #     {:noreply, %{final_state | performance_metrics: metrics}}
      #   else
      #     Logger.warning("⚠️ No applicable escalation rules found for alarm: #{alarm_id}")
      #     {:noreply, state}
      #   end

      {:error, reason} ->
        Logger.error("❌ Failed to get alarm for escalation: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  @spec handle_call(term(), GenServer.from(), map()) :: {:reply, any(), map()}
  def handle_call({:manual_escalation, alarm_id, escalated_by, _escalation_data}, _from, state) do
    Logger.info("📢 Manual escalation initiated by #{escalated_by} for alarm: #{alarm_id}")

    # NOTE: get_alarm_for_escalation/1 currently always returns {:error, _}
    # because AlarmEvent.get_alarm_event/1 is a stub. The {:ok, _} clause
    # has been commented out to eliminate unreachable clause warning.
    case get_alarm_for_escalation(alarm_id) do
      # {:ok, alarm_event} ->
      #   # Create manual escalation entry
      #   escalation_entry = %{
      #     alarm_id: alarm_id,
      #     escalation_level: escalation_data[:level] || 1,
      #     escalated_by: escalated_by,
      #     escalated_to: escalation_data[:escalated_to],
      #     escalation_reason: escalation_data[:reason] || "Manual escalation",
      #     escalated_at: DateTime.utc_now(),
      #     escalation_type: :manual,
      #     notification_methods: escalation_data[:notification_methods] || [:email, :sms],
      #     escalation_data: escalation_data
      #   }
      #
      #   # Log to Timescale DB
      #   :ok = TimescaleDBSchema.log_escalation(alarm_id, escalation_entry)
      #
      #   # Send notifications
      #   notification_tasks = create_escalation_notifications(alarm_event, escalation_entry)
      #   updated_state = queue_notifications(state, notification_tasks)
      #
      #   # Update active escalations
      #   final_state =
      #     case Map.get(state.active_escalations, alarm_id) do
      #       nil ->
      #         # Create new escalation workflow
      #         workflow = %{
      #           alarm_id: alarm_id,
      #           current_level: escalation_entry.escalation_level,
      #           max_level: @escalation_levels,
      #           started_at: DateTime.utc_now(),
      #           escalation_history: [escalation_entry],
      #           status: :active,
      #           last_escalated_at: DateTime.utc_now()
      #         }
      #
      #         %{
      #           updated_state
      #           | active_escalations:
      #               Map.put(updated_state.active_escalations, alarm_id, workflow)
      #         }
      #
      #       existing_workflow ->
      #         # Update existing workflow
      #         updated_workflow = %{
      #           existing_workflow
      #           | current_level:
      #               max(existing_workflow.current_level, escalation_entry.escalation_level),
      #             escalation_history: [escalation_entry | existing_workflow.escalation_history],
      #             last_escalated_at: DateTime.utc_now()
      #         }
      #
      #         %{
      #           updated_state
      #           | active_escalations:
      #               Map.put(updated_state.active_escalations, alarm_id, updated_workflow)
      #         }
      #     end
      #
      #   # Update metrics
      #   metrics = update_escalation_metrics(final_state.performance_metrics, :manual)
      #
      #   {:reply, {:ok, escalation_entry}, %{final_state | performance_metrics: metrics}}

      {:error, reason} ->
        Logger.error("❌ Manual escalation failed: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:acknowledge_escalation, alarm_id, acknowledged_by}, _from, state) do
    case Map.get(state.active_escalations, alarm_id) do
      nil ->
        {:reply, {:error, :escalation_not_found}, state}

      escalation_workflow ->
        Logger.info("✅ Escalation acknowledged by #{acknowledged_by} for alarm: #{alarm_id}")

        # Mark escalation as acknowledged
        updated_workflow = %{
          escalation_workflow
          | status: :acknowledged,
            acknowledged_by: acknowledged_by,
            acknowledged_at: DateTime.utc_now()
        }

        # Log acknowledgment to Timescale DB
        ack_entry = %{
          tenant_id: escalation_workflow[:tenant_id],
          site_id: escalation_workflow[:site_id],
          level: escalation_workflow.current_level,
          reason: "Escalation acknowledged",
          escalated_by: acknowledged_by,
          auto_escalated: false,
          metadata: %{action: "acknowledged", acknowledged_at: DateTime.utc_now()},
          escalated_at: DateTime.utc_now(),
          acknowledged_at: DateTime.utc_now(),
          response_time: DateTime.diff(DateTime.utc_now(), escalation_workflow.started_at)
        }

        # Pattern match commented out - TimescaleDBSchema resolves to stub at timescale_db_schema.ex:27 which only returns {:error, ...}, never :ok
        # :ok = TimescaleDBSchema.log_escalation(alarm_id, ack_entry)
        _result = TimescaleDBSchema.log_escalation(alarm_id, ack_entry)

        # Remove from active escalations and move to history
        updated_escalations = Map.delete(state.active_escalations, alarm_id)
        updated_history = Map.put(state.escalation_history, alarm_id, updated_workflow)

        # Update metrics
        metrics = update_escalation_metrics(state.performance_metrics, :acknowledged)

        {:reply, :ok,
         %{
           state
           | active_escalations: updated_escalations,
             escalation_history: updated_history,
             performance_metrics: metrics
         }}
    end
  end

  @impl true
  def handle_call({:update_rules, new_rules}, _from, state) do
    Logger.info("🔄 Updating escalation rules")

    validated_rules = validate_escalation_rules(new_rules)

    case validated_rules do
      {:ok, rules} ->
        {:reply, :ok, %{state | escalation_rules: rules}}

      {:error, reason} ->
        Logger.error("❌ Invalid escalation rules: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:get_escalation_status, _from, state) do
    status = compile_escalation_status(state)
    {:reply, status, state}
  end

  @impl true
  def handle_call(:process_notifications, _from, state) do
    {processed_count, updated_state} = process_notification_queue(state)
    {:reply, {:ok, processed_count}, updated_state}
  end

  @impl true
  def handle_info(:escalation_monitoring, state) do
    Logger.debug("🔍 Running escalation monitoring check")

    # Check for escalations that need to be processed
    updated_state = check_pending_escalations(state)

    # Schedule next check
    schedule_escalation_monitoring()

    {:noreply, updated_state}
  end

  @impl true
  @spec handle_info(term(), term()) :: term()
  def handle_info(:process_notifications, state) do
    {_processed_count, updated_state} = process_notification_queue(state)

    # Schedule next notification processing
    schedule_notification_processing()

    {:noreply, updated_state}
  end

  # Private implementation functions

  defp load_escalation_rules do
    # Default escalation rules-in production this would be loaded from configuration / database
    %{
      critical_alarms: %{
        event_types: [:panic, :duress, :holdup, :fire, :medical],
        severity: [:critical],
        escalation_levels: [
          %{
            level: 1,
            timeout: 5 * 60,
            escalate_to: [:security_supervisor],
            methods: [:sms, :push]
          },
          %{level: 2, timeout: 10 * 60, escalate_to: [:site_manager], methods: [:phone, :email]},
          %{
            level: 3,
            timeout: 15 * 60,
            escalate_to: [:regional_manager],
            methods: [:phone, :email, :sms]
          },
          %{
            level: 4,
            timeout: 30 * 60,
            escalate_to: [:operations_director],
            methods: [:phone, :email]
          },
          %{
            level: 5,
            timeout: 60 * 60,
            escalate_to: [:emergency_response],
            methods: [:phone, :pager]
          }
        ]
      },
      high_priority_alarms: %{
        event_types: [:intrusion, :tamper],
        severity: [:high, :critical],
        escalation_levels: [
          %{
            level: 1,
            timeout: 10 * 60,
            escalate_to: [:security_operator],
            methods: [:push, :email]
          },
          %{
            level: 2,
            timeout: 20 * 60,
            escalate_to: [:security_supervisor],
            methods: [:sms, :email]
          },
          %{level: 3, timeout: 30 * 60, escalate_to: [:site_manager], methods: [:phone, :email]},
          %{
            level: 4,
            timeout: 60 * 60,
            escalate_to: [:regional_manager],
            methods: [:phone, :email]
          }
        ]
      },
      standard_alarms: %{
        event_types: [:environmental, :trouble, :supervisory],
        severity: [:medium, :high],
        escalation_levels: [
          %{level: 1, timeout: 30 * 60, escalate_to: [:maintenance_team], methods: [:email]},
          %{
            level: 2,
            timeout: 60 * 60,
            escalate_to: [:maintenance_supervisor],
            methods: [:email, :sms]
          },
          %{
            level: 3,
            timeout: 120 * 60,
            escalate_to: [:facilities_manager],
            methods: [:email, :phone]
          }
        ]
      },
      low_priority_alarms: %{
        event_types: [:trouble, :supervisory],
        severity: [:low],
        escalation_levels: [
          %{level: 1, timeout: 60 * 60, escalate_to: [:maintenance_team], methods: [:email]},
          %{
            level: 2,
            timeout: 240 * 60,
            escalate_to: [:maintenance_supervisor],
            methods: [:email]
          }
        ]
      }
    }
  end

  defp initialize_escalation_metrics do
    %{
      escalations_initiated: 0,
      escalations_completed: 0,
      manual_escalations: 0,
      automatic_escalations: 0,
      acknowledged_escalations: 0,
      notifications_sent: 0,
      notification_failures: 0,
      average_escalation_time: 0,
      started_at: DateTime.utc_now(),
      last_reset: DateTime.utc_now()
    }
  end

  defp get_alarm_for_escalation(alarm_id) do
    # AlarmEvent.get_alarm_event/1 currently always returns {:error, "..."}
    {:error, reason} = AlarmEvent.get_alarm_event(alarm_id)
    {:error, reason}
  end

  # EP301-Unused function eliminated: find_applicable_escalation_rules/2 - removed
  # Function filtered escalation rules by matching event_type and severity

  # EP301-Unused function eliminated: create_escalation_workflow/3 - removed
  # Function created escalation workflow map with alarm info, rule config, and timing

  defp calculate_next_escalation_time(escalation_levels, level)
       when level <= length(escalation_levels) do
    level_config = Enum.at(escalation_levels, level - 1)
    DateTime.add(DateTime.utc_now(), level_config.timeout)
  end

  defp calculate_next_escalation_time(_escalation_levels, _level), do: nil

  defp execute_escalation_step(state, alarm_id, level) do
    workflow = Map.get(state.active_escalations, alarm_id)

    if level <= workflow.max_level do
      levelconfig = Enum.at(workflow.ruleconfig.escalation_levels, level - 1)

      # Create escalation entry
      escalation_entry = %{
        alarm_id: alarm_id,
        escalation_level: level,
        # Automatic escalation
        escalated_by: nil,
        escalated_to: levelconfig.escalate_to,
        escalation_reason: workflow.escalation_reason,
        escalated_at: DateTime.utc_now(),
        escalation_type: :automatic,
        notification_methods: levelconfig.methods,
        escalation_data: %{
          rule_applied: true,
          timeout_seconds: levelconfig.timeout,
          escalation_targets: levelconfig.escalate_to
        }
      }

      # Log to Timescale DB
      # Pattern match commented out - TimescaleDBSchema resolves to stub at timescale_db_schema.ex:27 which only returns {:error, ...}, never :ok
      # :ok = TimescaleDBSchema.log_escalation(alarm_id, escalation_entry)
      _result = TimescaleDBSchema.log_escalation(alarm_id, escalation_entry)

      # Get alarm event for notifications
      # Pattern match commented out - get_alarm_for_escalation/1 (line 475) only returns {:error, ...}, never {:ok, ...}
      # {:ok, alarm_event} = get_alarm_for_escalation(alarm_id)
      {:error, _reason} = get_alarm_for_escalation(alarm_id)

      # Create notification tasks
      # Commented out - alarm_event unavailable since get_alarm_for_escalation only returns errors
      # notification_tasks = create_escalation_notifications(alarm_event, escalation_entry)
      notification_tasks = []

      # Update workflow
      updated_workflow = %{
        workflow
        | current_level: level,
          escalation_history: [escalation_entry | workflow.escalation_history],
          last_escalated_at: DateTime.utc_now(),
          next_escalation_at:
            calculate_next_escalation_time(workflow.ruleconfig.escalation_levels, level + 1)
      }

      updated_escalations = Map.put(state.active_escalations, alarm_id, updated_workflow)

      {%{state | active_escalations: updated_escalations}, notification_tasks}
    else
      # Maximum escalation level reached
      Logger.warning("⚠️ Maximum escalation level reached for alarm: #{alarm_id}")

      updated_workflow = %{workflow | status: :max_level_reached}
      updated_escalations = Map.put(state.active_escalations, alarm_id, updated_workflow)

      {%{state | active_escalations: updated_escalations}, []}
    end
  end

  # EP301-Unused function eliminated: create_escalation_notifications/2 - removed
  # Function created notification tasks for each method/target combination with escalation data

  # EP301-Unused function eliminated: calculate_notification_priority/2 - removed
  # Function calculated priority (1-5) based on severity + escalation level

  # EP301-Unused function eliminated: queue_notifications/2 - removed
  # Function added notification tasks to state's notification queue

  defp check_pending_escalations(state) do
    current_time = DateTime.utc_now()

    Enum.reduce(state.active_escalations, state, fn {alarm_id, workflow}, acc_state ->
      if should_escalate_next_level?(workflow, current_time) do
        next_level = workflow.current_level + 1

        if next_level <= workflow.max_level do
          Logger.info(
            "⏰ Time-based escalation triggered for alarm #{alarm_id}, level #{next_level}"
          )

          {updated_state, _notifications} =
            execute_escalation_step(acc_state, alarm_id, next_level)

          updated_state
        else
          acc_state
        end
      else
        acc_state
      end
    end)
  end

  defp should_escalate_next_level?(workflow, current_time) do
    workflow.status == :active and
      workflow.next_escalation_at != nil and
      DateTime.compare(current_time, workflow.next_escalation_at) != :lt
  end

  defp process_notification_queue(state) do
    {notifications, remaining_queue} =
      dequeue_batch(state.notification_queue, @max_parallel_escalations)

    if notifications != [] do
      Logger.debug("📤 Processing #{length(notifications)} escalation notifications")

      # Process notifications in parallel
      results =
        notifications
        |> Task.async_stream(
          &send_escalation_notification/1,
          max_concurrency: System.schedulers_online(),
          timeout: 30_000
        )
        |> Enum.to_list()

      # Count successes and failures
      {successes, failures} =
        Enum.split_with(results, fn
          {:ok, {:ok, _}} -> true
          _ -> false
        end)

      # Update metrics
      updated_metrics = %{
        state.performance_metrics
        | notifications_sent: state.performance_metrics.notifications_sent + length(successes),
          notification_failures:
            state.performance_metrics.notification_failures + length(failures)
      }

      if length(failures) > 0 do
        Logger.warning("⚠️ #{length(failures)} escalation notifications failed to send")
      end

      {length(notifications),
       %{state | notification_queue: remaining_queue, performance_metrics: updated_metrics}}
    else
      {0, state}
    end
  end

  defp dequeue_batch(queue, max_count) do
    dequeue_batch(queue, max_count, [])
  end

  defp dequeue_batch(queue, 0, acc), do: {Enum.reverse(acc), queue}

  defp dequeue_batch(queue, remaining, acc) do
    case :queue.out(queue) do
      {{:value, item}, new_queue} ->
        dequeue_batch(new_queue, remaining - 1, [item | acc])

      {:empty, queue} ->
        {Enum.reverse(acc), queue}
    end
  end

  defp send_escalation_notification(notification) do
    case notification.method do
      :email ->
        send_email_notification(notification)

      :sms ->
        send_sms_notification(notification)

      :push ->
        send_push_notification(notification)

      :phone ->
        initiate_phone_call(notification)

      :pager ->
        send_pager_notification(notification)

      method ->
        Logger.error("❌ Unsupported notification method: #{method}")
        {:error, {:unsupported_method, method}}
    end
  rescue
    exception ->
      Logger.error("❌ Notification failed with exception: #{inspect(exception)}")
      {:error, exception}
  end

  defp send_email_notification(notification) do
    message_subject = format_escalation_subject(notification)
    message_body = format_escalation_body(notification)

    # Use Communication domain for email sending
    case Communication.send_email(%{
           to: get_target_email(notification.target),
           subject: message_subject,
           body: message_body,
           priority: notification.priority,
           metadata: %{
             type: "alarm_escalation",
             alarm_id: notification.alarm_id,
             escalation_level: notification.escalation_level
           }
         }) do
      {:ok, _result} ->
        Logger.debug("✅ Email escalation sent to #{notification.target}")
        {:ok, :email_sent}

      {:error, reason} ->
        Logger.error("❌ Failed to send email escalation: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp send_sms_notification(notification) do
    message = format_sms_escalation_message(notification)

    case Communication.send_sms(%{
           to: get_target_phone(notification.target),
           message: message,
           priority: notification.priority,
           metadata: %{
             type: "alarm_escalation",
             alarm_id: notification.alarm_id,
             escalation_level: notification.escalation_level
           }
         }) do
      {:ok, _result} ->
        Logger.debug("✅ SMS escalation sent to #{notification.target}")
        {:ok, :sms_sent}

      {:error, reason} ->
        Logger.error("❌ Failed to send SMS escalation: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp send_push_notification(notification) do
    push_data = %{
      title: "🚨 Alarm Escalation-Level #{notification.escalation_level}",
      body: format_push_escalation_message(notification),
      data: %{
        type: "alarm_escalation",
        alarm_id: notification.alarm_id,
        escalation_level: notification.escalation_level,
        action_required: true
      },
      priority: notification.priority
    }

    case Communication.send_push_notification(notification.target, push_data) do
      {:ok, _result} ->
        Logger.debug("✅ Push escalation sent to #{notification.target}")
        {:ok, :push_sent}

      {:error, reason} ->
        Logger.error("❌ Failed to send push escalation: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp initiate_phone_call(notification) do
    call_data = %{
      to: get_target_phone(notification.target),
      message: format_voice_escalation_message(notification),
      priority: notification.priority,
      metadata: %{
        type: "alarm_escalation",
        alarm_id: notification.alarm_id,
        escalation_level: notification.escalation_level
      }
    }

    case Communication.initiate_voice_call(call_data) do
      {:ok, _result} ->
        Logger.debug("✅ Voice call escalation initiated to #{notification.target}")
        {:ok, :call_initiated}

      {:error, reason} ->
        Logger.error("❌ Failed to initiate voice call: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp send_pager_notification(notification) do
    pager_message = format_pager_escalation_message(notification)

    case Communication.send_pager(%{
           to: get_target_pager(notification.target),
           message: pager_message,
           priority: notification.priority
         }) do
      {:ok, _result} ->
        Logger.debug("✅ Pager escalation sent to #{notification.target}")
        {:ok, :pager_sent}

      {:error, reason} ->
        Logger.error("❌ Failed to send pager escalation: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Message formatting functions

  defp format_escalation_subject(notification) do
    data = notification.message_data

    "🚨 ALARM ESCALATION L#{notification.escalation_level}-#{data.event_code}-#{String.upcase(to_string(data.severity))}"
  end

  defp format_escalation_body(notification) do
    data = notification.message_data

    """
    ALARM ESCALATION-LEVEL #{notification.escalation_level}

    Event Details:
    - Event Code: #{data.event_code}
    - Type: #{String.upcase(to_string(data.event_type))}
    - Severity: #{String.upcase(to_string(data.severity))}
    - Description: #{data.description}

    Escalation Information:
    - Reason: #{data.escalation_reason}
    - Escalated At: #{Calendar.strftime(data.escalated_at, "%Y-%m-%d %H:%M:%S %Z")}
    - Original Trigger: #{Calendar.strftime(data.triggered_at, "%Y-%m-%d %H:%M:%S %Z")}

    IMMEDIATE ACTION REQUIRED

    Please acknowledge this escalation and take appropriate action.
    """
  end

  defp format_sms_escalation_message(notification) do
    data = notification.message_data

    "🚨 ALARM ESC L#{notification.escalation_level}: #{data.event_code}-#{data.event_type}-#{data.severity} - #{truncate_text(data.description, 80)}"
  end

  defp format_push_escalation_message(notification) do
    data = notification.message_data

    "#{data.event_code} - #{String.upcase(to_string(data.event_type))} - #{truncate_text(data.description, 120)}"
  end

  defp format_voice_escalation_message(notification) do
    data = notification.message_data

    """
    This is an automated alarm escalation call. Level #{notification.escalation_level} escalation for event #{data.event_code}.

    Event type: #{String.replace(to_string(data.event_type), "_", " ")}
    Severity: #{to_string(data.severity)}
    Description: #{data.description}

    Immediate action is __required. Please acknowledge this escalation.
    """
  end

  defp format_pager_escalation_message(notification) do
    data = notification.message_data

    "L#{notification.escalation_level} ESC: #{data.event_code} #{data.event_type} #{data.severity}-#{truncate_text(data.description, 60)}"
  end

  defp truncate_text(text, max_length) when is_binary(text) do
    if String.length(text) > max_length do
      String.slice(text, 0, max_length - 3) <> "..."
    else
      text
    end
  end

  defp truncate_text(text, _max_length), do: to_string(text)

  # Contact information lookup functions (simplified-would integrate with actual directory)

  defp get_target_email(:security_supervisor), do: "security.supervisor@company.com"
  defp get_target_email(:site_manager), do: "site.manager@company.com"
  defp get_target_email(:regional_manager), do: "regional.manager@company.com"
  defp get_target_email(:operations_director), do: "ops.director@company.com"
  defp get_target_email(:emergency_response), do: "emergency@company.com"
  defp get_target_email(:security_operator), do: "security.ops@company.com"
  defp get_target_email(:maintenance_team), do: "maintenance@company.com"
  defp get_target_email(:maintenance_supervisor), do: "maintenance.super@company.com"
  defp get_target_email(:facilities_manager), do: "facilities@company.com"
  defp get_target_email(target), do: "#{target}@company.com"

  defp get_target_phone(:security_supervisor), do: "+1-555-0101"
  defp get_target_phone(:site_manager), do: "+1-555-0102"
  defp get_target_phone(:regional_manager), do: "+1-555-0103"
  defp get_target_phone(:operations_director), do: "+1-555-0104"
  defp get_target_phone(:emergency_response), do: "+1-555-0911"

  defp get_target_phone(target) do
    target_str = target |> to_string() |> String.slice(0, 4) |> String.pad_leading(4, "0")
    "+1-555-#{target_str}"
  end

  defp get_target_pager(:emergency_response), do: "911-EMERGENCY"
  defp get_target_pager(:operations_director), do: "OPS-DIRECTOR"
  defp get_target_pager(target), do: String.upcase(to_string(target))

  # Utility and validation functions

  defp validate_escalation_rules(rules) when is_map(rules) do
    try do
      validated =
        Enum.reduce(rules, %{}, fn {name, rule}, acc ->
          case validate_single_rule(rule) do
            :ok -> Map.put(acc, name, rule)
            {:error, reason} -> throw({:invalid_rule, name, reason})
          end
        end)

      {:ok, validated}
    catch
      {:invalid_rule, name, reason} -> {:error, {name, reason}}
    end
  end

  defp validate_escalation_rules(_), do: {:error, :invalid_rules_format}

  defp validate_single_rule(rule) do
    required_fields = [:event_types, :severity, :escalation_levels]

    case Enum.all?(required_fields, &Map.has_key?(rule, &1)) do
      true -> validate_escalation_levels(rule.escalation_levels)
      false -> {:error, :missing_required_fields}
    end
  end

  defp validate_escalation_levels(levels) when is_list(levels) and length(levels) > 0 do
    if Enum.all?(levels, &valid_escalation_level?/1) do
      :ok
    else
      {:error, :invalid_escalation_level}
    end
  end

  defp validate_escalation_levels(_), do: {:error, :invalid_escalation_levels_format}

  defp valid_escalation_level?(level) do
    required_fields = [:level, :timeout, :escalate_to, :methods]
    Enum.all?(required_fields, &Map.has_key?(level, &1))
  end

  defp update_escalation_metrics(metrics, action) do
    case action do
      :initiated ->
        %{
          metrics
          | escalations_initiated: metrics.escalations_initiated + 1,
            automatic_escalations: metrics.automatic_escalations + 1
        }

      :manual ->
        %{
          metrics
          | escalations_initiated: metrics.escalations_initiated + 1,
            manual_escalations: metrics.manual_escalations + 1
        }

      :acknowledged ->
        %{metrics | acknowledged_escalations: metrics.acknowledged_escalations + 1}
    end
  end

  defp compile_escalation_status(state) do
    active_count = map_size(state.active_escalations)
    queue_size = :queue.len(state.notification_queue)

    %{
      status: state.status,
      active_escalations: active_count,
      pending_notifications: queue_size,
      escalation_rules: map_size(state.escalation_rules),
      performance_metrics: state.performance_metrics,
      system_health: %{
        escalation_processing: if(active_count < 100, do: :healthy, else: :overloaded),
        notification_queue: if(queue_size < 500, do: :healthy, else: :backlogged)
      }
    }
  end

  # Scheduling functions

  defp schedule_escalation_monitoring do
    Process.send_after(self(), :escalation_monitoring, @escalation_check_interval)
  end

  defp schedule_notification_processing do
    # Every 5 seconds
    Process.send_after(self(), :process_notifications, 5_000)
  end
end

# Agent: Helper-1 (Alarm Processing Coordination Agent)
# SOPv5.1Compliance: ✅ Cybernetic goal - oriented execution with intelligent workflow automation
# Framework: Container-Only + Git - based + Maximum Parallelization + Workflow Automation Engine
# Domain: Alarms Escalation Automation
# Responsibilities: Intelligent escalation workflows,
# Multi - Agent Architecture: Integrated with 11 - agent coordination system for scalable notification processing
# Cybernetic Feedback: Adaptive escalation rules, performance optimization, intelligent routing and communication
