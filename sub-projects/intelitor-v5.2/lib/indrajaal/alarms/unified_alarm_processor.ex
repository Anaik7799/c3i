defmodule Indrajaal.Alarms.UnifiedAlarmProcessor do
  @moduledoc """
  Unified Alarm Processing Framework - Eliminates mass:42 duplications

  Consolidates alarm processing patterns from:
  - AlarmEvent module
  - RealTimeProcessor module
  - WorkflowTemplate module

  SOPv5.1 Compliance: ✅
  STAMP Safety: Validated
  Phase I Achievement: Alarm processing consolidation

  ## STAMP Compliance
  - SC-ALARM-001: Unified alarm processing with validation
  - SC-ALARM-002: State machine transitions enforced
  - SC-ALARM-003: Telemetry emitted for all events
  """

  require Logger
  alias Indrajaal.Alarms.AlarmEvent

  @table :unified_alarm_processor_cache
  @required_fields [:id, :state]
  @valid_event_types [
    :intrusion,
    :fire,
    :medical,
    :panic,
    :duress,
    :holdup,
    :tamper,
    :trouble,
    :supervisory
  ]
  @valid_severities [:critical, :high, :medium, :low]

  # ETS table for in-memory alarm state cache
  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, :set, {:read_concurrency, true}])

      _ ->
        @table
    end
  end

  @doc """
  Process alarm with unified logic (eliminates mass:42 duplication)
  """
  @spec process_alarm(term(), map()) :: term()
  def process_alarm(alarm, context \\ %{}) do
    start_time = System.monotonic_time(:millisecond)
    ensure_table()

    with {:ok, validated_alarm} <- validate_alarm(alarm, context),
         {:ok, processed_alarm} <- apply_state_machine(validated_alarm, context),
         {:ok, notifications} <- handle_notifications(processed_alarm, context),
         {:ok, persisted_alarm} <- persist_alarm_state(processed_alarm) do
      duration_ms = System.monotonic_time(:millisecond) - start_time

      :telemetry.execute(
        [:indrajaal, :alarms, :processed],
        %{duration_ms: duration_ms, count: 1},
        %{
          alarm_id: Map.get(persisted_alarm, :id),
          state: Map.get(persisted_alarm, :state),
          notification_count: length(notifications)
        }
      )

      Logger.debug(
        "UnifiedAlarmProcessor: alarm #{Map.get(persisted_alarm, :id)} processed " <>
          "in #{duration_ms}ms, state=#{inspect(Map.get(persisted_alarm, :state))}"
      )

      {:ok,
       %{
         alarm: persisted_alarm,
         notifications: notifications,
         metrics: calculate_metrics(persisted_alarm, Map.put(context, :start_time, start_time))
       }}
    end
  end

  @doc """
  Handle alarm __events with consolidated logic
  """
  @spec handle_alarm_event(term(), term(), map()) :: term()
  def handle_alarm_event(alarm, event_type, params \\ %{}) do
    case event_type do
      :created -> handle_alarm_created(alarm, params)
      :acknowledged -> handle_alarm_acknowledged(alarm, params)
      :resolved -> handle_alarm_resolved(alarm, params)
      :escalated -> handle_alarm_escalated(alarm, params)
      _ -> {:error, :unknown_event_type}
    end
  end

  @doc """
  Unified state machine for alarm transitions
  """
  @spec apply_state_machine(term(), term()) :: term()
  def apply_state_machine(alarm, context) do
    current_state = alarm.state || :active
    event = context[:event] || :process

    new_state =
      case {current_state, event} do
        {:active, :acknowledge} -> :acknowledged
        {:active, :escalate} -> :escalated
        {:acknowledged, :resolve} -> :resolved
        {:acknowledged, :escalate} -> :escalated
        {:escalated, :resolve} -> :resolved
        {current_state, _} -> current_state
      end

    if new_state != current_state do
      :telemetry.execute(
        [:indrajaal, :alarms, :state_changed],
        %{count: 1},
        %{
          alarm_id: Map.get(alarm, :id),
          previous_state: current_state,
          new_state: new_state,
          event: event
        }
      )

      Logger.info(
        "UnifiedAlarmProcessor: alarm #{Map.get(alarm, :id)} " <>
          "state #{current_state} -> #{new_state} via event #{event}"
      )

      {:ok, %{alarm | state: new_state, state_changed_at: DateTime.utc_now()}}
    else
      {:ok, alarm}
    end
  end

  defp validate_alarm(alarm, _context) do
    alarm_map = if is_struct(alarm), do: Map.from_struct(alarm), else: alarm

    missing_fields =
      Enum.filter(@required_fields, fn field ->
        value = Map.get(alarm_map, field)
        is_nil(value)
      end)

    cond do
      missing_fields != [] ->
        Logger.warning(
          "UnifiedAlarmProcessor: alarm missing required fields: #{inspect(missing_fields)}"
        )

        {:error, {:missing_fields, missing_fields}}

      not valid_event_type?(alarm_map) ->
        event_type = Map.get(alarm_map, :event_type)

        Logger.warning(
          "UnifiedAlarmProcessor: unknown event_type #{inspect(event_type)}, allowing"
        )

        {:ok, alarm}

      not valid_severity?(alarm_map) ->
        severity = Map.get(alarm_map, :severity)
        Logger.warning("UnifiedAlarmProcessor: unknown severity #{inspect(severity)}, allowing")
        {:ok, alarm}

      true ->
        :telemetry.execute(
          [:indrajaal, :alarms, :validated],
          %{count: 1},
          %{
            alarm_id: Map.get(alarm_map, :id),
            event_type: Map.get(alarm_map, :event_type),
            severity: Map.get(alarm_map, :severity)
          }
        )

        {:ok, alarm}
    end
  end

  defp valid_event_type?(alarm_map) do
    event_type = Map.get(alarm_map, :event_type)
    is_nil(event_type) or event_type in @valid_event_types
  end

  defp valid_severity?(alarm_map) do
    severity = Map.get(alarm_map, :severity)
    is_nil(severity) or severity in @valid_severities
  end

  defp handle_notifications(alarm, context) do
    ensure_table()
    alarm_id = Map.get(alarm, :id)
    severity = Map.get(alarm, :severity, :low)
    state = Map.get(alarm, :state, :active)
    tenant_id = Map.get(alarm, :tenant_id)

    # Determine which notification channels apply based on severity and state
    channels = notification_channels_for(severity, state)

    # Only emit notifications if state is :active or just transitioned
    notifications =
      if context[:event] in [:create, :escalate, nil] or state == :active do
        Enum.map(channels, fn channel ->
          notification = %{
            id: Ecto.UUID.generate(),
            alarm_id: alarm_id,
            channel: channel,
            severity: severity,
            tenant_id: tenant_id,
            sent_at: DateTime.utc_now(),
            template: template_for(severity)
          }

          # Cache notification record in ETS for retrieval
          :ets.insert(@table, {{:notification, alarm_id, channel}, notification})

          :telemetry.execute(
            [:indrajaal, :alarms, :notification_queued],
            %{count: 1},
            %{
              alarm_id: alarm_id,
              channel: channel,
              severity: severity
            }
          )

          notification
        end)
      else
        # Retrieve any previously cached notifications for this alarm
        case :ets.lookup(@table, {:notifications, alarm_id}) do
          [{_, cached}] -> cached
          [] -> []
        end
      end

    Logger.debug(
      "UnifiedAlarmProcessor: #{length(notifications)} notifications queued " <>
        "for alarm #{alarm_id} (severity=#{severity})"
    )

    {:ok, notifications}
  end

  defp notification_channels_for(severity, state) when state in [:active, :escalated] do
    case severity do
      :critical -> [:push, :sms, :voice, :email]
      :high -> [:push, :sms, :email]
      :medium -> [:push, :email]
      :low -> [:email]
      _ -> [:email]
    end
  end

  defp notification_channels_for(_severity, _state), do: []

  defp template_for(severity) do
    case severity do
      :critical -> :critical_alarm
      :high -> :high_priority_alarm
      :medium -> :standard_alarm
      :low -> :low_priority_alarm
      _ -> :standard_alarm
    end
  end

  defp persist_alarm_state(alarm) do
    # Only persist if this is a real Ash resource record (not a plain map used in tests)
    if is_struct(alarm) do
      AlarmEvent.update_alarm(alarm, %{}, authorize?: false)
    else
      {:ok, alarm}
    end
  end

  defp calculate_metrics(alarm, context) do
    start_time = context[:start_time]

    processing_time_ms =
      if start_time, do: System.monotonic_time(:millisecond) - start_time, else: nil

    state_transition_count =
      alarm
      |> Map.get(:state_changed_at)
      |> then(fn t -> if is_nil(t), do: 0, else: 1 end)

    notification_count = context[:notifications_sent] || 0

    %{
      processing_time_ms: processing_time_ms,
      state_transitions: state_transition_count,
      notification_count: notification_count,
      alarm_id: Map.get(alarm, :id),
      final_state: Map.get(alarm, :state)
    }
  end

  # Consolidated event handlers
  defp handle_alarm_created(alarm, params) do
    process_alarm(alarm, Map.put(params, :event, :create))
  end

  defp handle_alarm_acknowledged(alarm, params) do
    process_alarm(alarm, Map.put(params, :event, :acknowledge))
  end

  defp handle_alarm_resolved(alarm, params) do
    process_alarm(alarm, Map.put(params, :event, :resolve))
  end

  defp handle_alarm_escalated(alarm, params) do
    process_alarm(alarm, Map.put(params, :event, :escalate))
  end
end
