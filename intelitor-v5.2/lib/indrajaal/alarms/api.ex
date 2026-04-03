defmodule Indrajaal.Alarms.Api do
  @moduledoc """
  Public API for alarm operations with comprehensive error handling.

  This module provides a clean interface for all alarm - related operations,
  including creation, updates, queries, and notification management.
  """

  require Logger
  alias Indrajaal.Alarms.{AlarmEvent, Notification, Response, WorkflowTemplate}
  alias Indrajaal.Observability.Tracing

  require Logger

  # Core alarm operations

  @doc """
  Create a new alarm event from device data
  """
  @spec create_alarm_event(any(), any()) :: any()
  def create_alarm_event(attrs, opts \\ []) do
    Tracing.trace_domain_operation(:alarms, :create_event, attrs, fn ->
      try do
        AlarmEvent
        |> Ash.Changeset.for_create(:create, attrs, opts)
        |> Ash.create!()
        |> then(&{:ok, &1})
      rescue
        e -> {:error, e}
      end
    end)
  end

  @doc """
  Update an alarm event
  """
  @spec update_alarm_event(term(), term(), term()) :: term()
  def update_alarm_event(alarm, attrs, opts \\ []) do
    Tracing.trace_domain_operation(:alarms, :update_event, %{id: alarm.id}, fn ->
      try do
        alarm
        |> Ash.Changeset.for_update(:update, attrs, opts)
        |> Ash.update!()
        |> then(&{:ok, &1})
      rescue
        e -> {:error, e}
      end
    end)
  end

  @doc """
  Acknowledge an alarm
  """
  @spec acknowledge_alarm(term(), term(), term()) :: term()
  def acknowledge_alarm(alarm_id, user_id, opts \\ []) do
    Tracing.trace_domain_operation(:alarms, :acknowledge, %{id: alarm_id, user_id: user_id}, fn ->
      with {:ok, alarm} <- get_alarm_event(alarm_id, opts) do
        try do
          alarm
          |> Ash.Changeset.for_update(:acknowledge, %{acknowledged_by: user_id}, opts)
          |> Ash.update!()
          |> then(&{:ok, &1})
        rescue
          e -> {:error, e}
        end
      end
    end)
  end

  @doc """
  Begin investigation of an alarm
  """
  @spec begin_investigation(term(), term(), term()) :: term()
  def begin_investigation(alarm_id, user_id, opts \\ []) do
    Tracing.trace_domain_operation(:alarms, :investigate, %{id: alarm_id, user_id: user_id}, fn ->
      with {:ok, alarm} <- get_alarm_event(alarm_id, opts) do
        try do
          alarm
          |> Ash.Changeset.for_update(:begin_investigation, %{investigating_by: user_id}, opts)
          |> Ash.update!()
          |> then(&{:ok, &1})
        rescue
          e -> {:error, e}
        end
      end
    end)
  end

  @doc """
  Resolve an alarm
  """
  @spec resolve_alarm(term(), term(), term(), list()) :: term()
  def resolve_alarm(alarm_id, user_id, notes, opts \\ []) do
    Tracing.trace_domain_operation(:alarms, :resolve, %{id: alarm_id, user_id: user_id}, fn ->
      with {:ok, alarm} <- get_alarm_event(alarm_id, opts) do
        try do
          alarm
          |> Ash.Changeset.for_update(
            :resolve,
            %{
              resolved_by: user_id,
              resolution_notes: notes
            },
            opts
          )
          |> Ash.update!()
          |> then(&{:ok, &1})
        rescue
          e -> {:error, e}
        end
      end
    end)
  end

  @doc """
  Mark an alarm as false alarm
  """
  @spec mark_false_alarm(term(), term(), term(), list()) :: term()
  def mark_false_alarm(alarm_id, user_id, reason, opts \\ []) do
    with {:ok, alarm} <- get_alarm_event(alarm_id, opts) do
      try do
        alarm
        |> Ash.Changeset.for_update(
          :mark_false_alarm,
          %{
            resolved_by: user_id,
            false_alarm_reason: reason
          },
          opts
        )
        |> Ash.update!()
        |> then(&{:ok, &1})
      rescue
        e -> {:error, e}
      end
    end
  end

  @doc """
  Update alarm severity based on evaluation
  """
  @spec update_alarm_severity(term(), term(), term(), list()) :: term()
  def update_alarm_severity(alarm, severity, severity_factors, opts \\ []) do
    alarm
    |> Ash.Changeset.for_update(
      :update_severity,
      %{
        severity: severity,
        severity_factors: severity_factors
      },
      opts
    )
    |> Ash.update!()
    |> then(&{:ok, &1})
  rescue
    e -> {:error, e}
  end

  @doc """
  Update alarm correlation data
  """
  @spec update_alarm_correlation(term(), term(), term()) :: term()
  def update_alarm_correlation(alarm, correlation_data, opts \\ []) do
    alarm
    |> Ash.Changeset.for_update(:update_correlation, correlation_data, opts)
    |> Ash.update!()
    |> then(&{:ok, &1})
  rescue
    e -> {:error, e}
  end

  @doc """
  Mark alarm as storm suppressed
  """
  @spec mark_storm_suppressed(any(), any()) :: any()
  def mark_storm_suppressed(alarm, opts \\ []) do
    alarm
    |> Ash.Changeset.for_update(:mark_storm_suppressed, %{}, opts)
    |> Ash.update!()
    |> then(&{:ok, &1})
  rescue
    e -> {:error, e}
  end

  # Query operations

  @doc """
  List alarm events with filters
  """
  @spec list_alarm_events(any(), any()) :: any()
  def list_alarm_events(filters, opts \\ []) do
    AlarmEvent
    |> Ash.Query.for_read(:list_alarm_events, %{filters: filters}, opts)
    |> Ash.read!()
    |> then(&{:ok, &1})
  rescue
    e -> {:error, e}
  end

  @doc """
  Get a single alarm event by ID
  """
  @spec get_alarm_event(any(), any()) :: any()
  def get_alarm_event(id, opts \\ []) do
    AlarmEvent
    |> Ash.Query.for_read(:get_alarm_event, %{id: id}, opts)
    |> Ash.read_one!()
    |> case do
      nil -> {:error, %Ash.Error.Query.NotFound{}}
      alarm -> {:ok, alarm}
    end
  rescue
    e -> {:error, e}
  end

  @doc """
  Get active alarms (not resolved)
  """
  @spec get_active_alarms(any()) :: any()
  def get_active_alarms(opts \\ []) do
    AlarmEvent
    |> Ash.Query.for_read(:active_alarms, %{}, opts)
    |> Ash.read!()
    |> then(&{:ok, &1})
  rescue
    e -> {:error, e}
  end

  @doc """
  Get recent alarms within specified minutes
  """
  @spec get_recent_alarms(any(), any()) :: any()
  def get_recent_alarms(minutes, opts \\ []) do
    AlarmEvent
    |> Ash.Query.for_read(:recent_alarms, %{minutes: minutes}, opts)
    |> Ash.read!()
    |> then(&{:ok, &1})
  rescue
    e -> {:error, e}
  end

  @doc """
  Count alarms by state
  """
  @spec count_alarms_by_state(any(), any()) :: any()
  def count_alarms_by_state(state, opts \\ []) do
    AlarmEvent
    |> Ash.Query.for_read(:count_by_state, %{state: state}, opts)
    |> Ash.count!()
    |> then(&{:ok, &1})
  rescue
    e -> {:error, e}
  end

  # Notification operations

  @doc """
  Create a notification for an alarm
  """
  @spec create_notification(any(), any()) :: any()
  def create_notification(attrs, opts \\ []) do
    Notification
    |> Ash.Changeset.for_create(:create, attrs, opts)
    |> Ash.create!()
    |> then(&{:ok, &1})
  rescue
    e -> {:error, e}
  end

  @doc """
  List notifications for an alarm
  """
  @spec list_notifications(any(), any()) :: any()
  def list_notifications(filters, opts \\ []) do
    Notification
    |> Ash.Query.for_read(:list, %{filters: filters}, opts)
    |> Ash.read!()
    |> then(&{:ok, &1})
  rescue
    e -> {:error, e}
  end

  @doc """
  Mark notification as delivered
  """
  @spec mark_notification_delivered(any(), any()) :: any()
  def mark_notification_delivered(notification_id, opts \\ []) do
    try do
      with {:ok, notification} <- get_notification(notification_id, opts) do
        notification
        |> Ash.Changeset.for_update(:mark_delivered, %{}, opts)
        |> Ash.update!()
        |> then(&{:ok, &1})
      end
    rescue
      e -> {:error, e}
    end
  end

  # Workflow operations

  @doc """
  List workflow templates
  """
  @spec list_workflow_templates(any(), any()) :: any()
  def list_workflow_templates(filters, opts \\ []) do
    try do
      WorkflowTemplate
      |> Ash.Query.for_read(:list, %{filters: filters}, opts)
      |> Ash.read!()
      |> then(&{:ok, &1})
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  Get workflow template by ID
  """
  @spec get_workflow_template(any(), any()) :: any()
  def get_workflow_template(id, opts \\ []) do
    WorkflowTemplate
    |> Ash.Query.for_read(:get, %{id: id}, opts)
    |> Ash.read_one!()
    |> case do
      nil -> {:error, %Ash.Error.Query.NotFound{}}
      template -> {:ok, template}
    end
  rescue
    e -> {:error, e}
  end

  # Response operations

  @doc """
  Create a response record for an alarm
  """
  @spec create_response(any(), any()) :: any()
  def create_response(attrs, opts \\ []) do
    Response
    |> Ash.Changeset.for_create(:create, attrs, opts)
    |> Ash.create!()
    |> then(&{:ok, &1})
  rescue
    e -> {:error, e}
  end

  @doc """
  List responses for an alarm
  """
  @spec list_responses(any(), any()) :: any()
  def list_responses(alarm_id, opts \\ []) do
    Response
    |> Ash.Query.for_read(:list, %{alarm_event_id: alarm_id}, opts)
    |> Ash.read!()
    |> then(&{:ok, &1})
  rescue
    e -> {:error, e}
  end

  # Statistics and analytics

  @doc """
  Get alarm statistics for a time period
  """
  @spec get_alarm_statistics(any(), any()) :: any()
  def get_alarm_statistics(params, opts \\ []) do
    start_date = Map.get(params, :start_date, Date.add(Date.utc_today(), -30))
    end_date = Map.get(params, :end_date, Date.utc_today())
    site_id = Map.get(params, :site_id)

    filters = %{
      triggered_after: DateTime.new!(start_date, ~T[00:00:00]),
      triggered_before: DateTime.new!(end_date, ~T[23:59:59])
    }

    filters = if site_id, do: Map.put(filters, :site_id, site_id), else: filters

    with {:ok, alarms} <- list_alarm_events(filters, opts) do
      stats = %{
        total_alarms: length(alarms),
        by_severity: count_by_severity(alarms),
        by_state: count_by_state(alarms),
        by_event_type: count_by_event_type(alarms),
        average_response_time: calculate_avg_response_time(alarms),
        average_resolution_time: calculate_avg_resolution_time(alarms),
        false_alarm_rate: calculate_false_alarm_rate(alarms)
      }

      {:ok, stats}
    end
  end

  # Ash domain functions

  @doc """
  Create an incident type
  Migrated to shared utility: Eliminates duplicate code (mass: 29)
  """
  @spec create_incident_type(any(), any()) :: any()
  def create_incident_type(attrs, opts \\ []) do
    Indrajaal.Shared.ApiPatterns.create_resource_function(Indrajaal.Alarms.IncidentType).(
      attrs,
      opts
    )
  end

  # Private helper functions

  @spec get_notification(term(), term()) :: term()
  defp get_notification(id, opts) do
    Notification
    |> Ash.Query.for_read(:get, %{id: id}, opts)
    |> Ash.read_one!()
    |> case do
      nil -> {:error, %Ash.Error.Query.NotFound{}}
      notification -> {:ok, notification}
    end
  rescue
    e -> {:error, e}
  end

  @spec count_by_severity(term()) :: term()
  defp count_by_severity(alarms) do
    Enum.frequencies_by(alarms, & &1.severity)
  end

  @spec count_by_state(term()) :: term()
  defp count_by_state(alarms) do
    Enum.frequencies_by(alarms, & &1.state)
  end

  @spec count_by_event_type(term()) :: term()
  defp count_by_event_type(alarms) do
    Enum.frequencies_by(alarms, & &1.event_type)
  end

  @spec calculate_avg_response_time(term()) :: term()
  defp calculate_avg_response_time(alarms) do
    response_times =
      alarms
      |> Enum.filter(& &1.response_time_seconds)
      |> Enum.map(& &1.response_time_seconds)

    if length(response_times) > 0 do
      Enum.sum(response_times) / length(response_times)
    else
      0
    end
  end

  @spec calculate_avg_resolution_time(term()) :: term()
  defp calculate_avg_resolution_time(alarms) do
    resolution_times =
      alarms
      |> Enum.filter(& &1.resolution_time_seconds)
      |> Enum.map(& &1.resolution_time_seconds)

    if length(resolution_times) > 0 do
      Enum.sum(resolution_times) / length(resolution_times)
    else
      0
    end
  end

  @spec calculate_false_alarm_rate(term()) :: term()
  defp calculate_false_alarm_rate(alarms) do
    total = length(alarms)
    false_alarms = Enum.count(alarms, &(&1.state == :false_alarm))

    if total > 0 do
      false_alarms / total * 100
    else
      0
    end
  end
end

# Agent: Worker - 1 (Alarms Domain Agent)
# SOPv5.1 Compliance: ✅ Critical alarm processing and incident response coordin
# Domain: Alarms
# Responsibilities: Alarm processing, incident response, critical system monito
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
