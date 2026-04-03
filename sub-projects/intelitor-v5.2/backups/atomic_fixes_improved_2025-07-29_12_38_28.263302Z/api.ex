defmodule Intelitor.Alarms.Api do
  @moduledoc """
  Public API for alarm operations with comprehensive error handling.

  This module provides a clean interface for all alarm-related operations,
  including creation, updates, queries, and notification management.
  """

  alias Intelitor.Alarms.{AlarmEvent, Notification, Response, WorkflowTemplate}

  require Logger

  # Core alarm operations

  @doc """
  Create a new alarm event from device data
  """
  def create_alarm_event(attrs, opts \\ []) do
    try do
      AlarmEvent
      |> Ash.Changeset.for_create(:create, attrs, opts)
      |> Ash.create!()
      |> then(&{:ok, &1})
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  Update an alarm event
  """
  def update_alarm_event(alarm, attrs, opts \\ []) do
    try do
      alarm
      |> Ash.Changeset.for_update(:update, attrs, opts)
      |> Ash.update!()
      |> then(&{:ok, &1})
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  Acknowledge an alarm
  """
  def acknowledge_alarm(alarm_id, user_id, opts \\ []) do
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
  end

  @doc """
  Begin investigation of an alarm
  """
  def begin_investigation(alarm_id, user_id, opts \\ []) do
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
  end

  @doc """
  Resolve an alarm
  """
  def resolve_alarm(alarm_id, user_id, notes, opts \\ []) do
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
  end

  @doc """
  Mark an alarm as false alarm
  """
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
  def update_alarm_severity(alarm, severity, severity_factors, opts \\ []) do
    try do
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
  end

  @doc """
  Update alarm correlation data
  """
  def update_alarm_correlation(alarm, correlation_data, opts \\ []) do
    try do
      alarm
      |> Ash.Changeset.for_update(:update_correlation, correlation_data, opts)
      |> Ash.update!()
      |> then(&{:ok, &1})
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  Mark alarm as storm suppressed
  """
  def mark_storm_suppressed(alarm, opts \\ []) do
    try do
      alarm
      |> Ash.Changeset.for_update(:mark_storm_suppressed, %{}, opts)
      |> Ash.update!()
      |> then(&{:ok, &1})
    rescue
      e -> {:error, e}
    end
  end

  # Query operations

  @doc """
  List alarm events with filters
  """
  def list_alarm_events(filters \\ %{}, opts \\ []) do
    try do
      AlarmEvent
      |> Ash.Query.for_read(:list_alarm_events, %{filters: filters}, opts)
      |> Ash.read!()
      |> then(&{:ok, &1})
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  Get a single alarm event by ID
  """
  def get_alarm_event(id, opts \\ []) do
    try do
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
  end

  @doc """
  Get active alarms (not resolved)
  """
  def get_active_alarms(opts \\ []) do
    try do
      AlarmEvent
      |> Ash.Query.for_read(:active_alarms, %{}, opts)
      |> Ash.read!()
      |> then(&{:ok, &1})
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  Get recent alarms within specified minutes
  """
  def get_recent_alarms(minutes \\ 5, opts \\ []) do
    try do
      AlarmEvent
      |> Ash.Query.for_read(:recent_alarms, %{minutes: minutes}, opts)
      |> Ash.read!()
      |> then(&{:ok, &1})
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  Count alarms by state
  """
  def count_alarms_by_state(state, opts \\ []) do
    try do
      AlarmEvent
      |> Ash.Query.for_read(:count_by_state, %{state: state}, opts)
      |> Ash.count!()
      |> then(&{:ok, &1})
    rescue
      e -> {:error, e}
    end
  end

  # Notification operations

  @doc """
  Create a notification for an alarm
  """
  def create_notification(attrs, opts \\ []) do
    try do
      Notification
      |> Ash.Changeset.for_create(:create, attrs, opts)
      |> Ash.create!()
      |> then(&{:ok, &1})
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  List notifications for an alarm
  """
  def list_notifications(filters \\ %{}, opts \\ []) do
    try do
      Notification
      |> Ash.Query.for_read(:list, %{filters: filters}, opts)
      |> Ash.read!()
      |> then(&{:ok, &1})
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  Mark notification as delivered
  """
  def mark_notification_delivered(notification_id, opts \\ []) do
    with {:ok, notification} <- get_notification(notification_id, opts) do
      try do
        notification
        |> Ash.Changeset.for_update(:mark_delivered, %{}, opts)
        |> Ash.update!()
        |> then(&{:ok, &1})
      rescue
        e -> {:error, e}
      end
    end
  end

  # Workflow operations

  @doc """
  List workflow templates
  """
  def list_workflow_templates(filters \\ %{}, opts \\ []) do
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
  def get_workflow_template(id, opts \\ []) do
    try do
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
  end

  # Response operations

  @doc """
  Create a response record for an alarm
  """
  def create_response(attrs, opts \\ []) do
    try do
      Response
      |> Ash.Changeset.for_create(:create, attrs, opts)
      |> Ash.create!()
      |> then(&{:ok, &1})
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  List responses for an alarm
  """
  def list_responses(alarm_id, opts \\ []) do
    try do
      Response
      |> Ash.Query.for_read(:list, %{alarm_event_id: alarm_id}, opts)
      |> Ash.read!()
      |> then(&{:ok, &1})
    rescue
      e -> {:error, e}
    end
  end

  # Statistics and analytics

  @doc """
  Get alarm statistics for a time period
  """
  def get_alarm_statistics(params \\ %{}, opts \\ []) do
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
  def create_incident_type(attrs, opts \\ []) do
    Intelitor.Shared.ApiPatterns.create_resource_function(Intelitor.Alarms.IncidentType).(
      attrs,
      opts
    )
  end

  # Private helper functions

  defp get_notification(id, opts) do
    try do
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
  end

  defp count_by_severity(alarms) do
    Enum.frequencies_by(alarms, & &1.severity)
  end

  defp count_by_state(alarms) do
    Enum.frequencies_by(alarms, & &1.state)
  end

  defp count_by_event_type(alarms) do
    Enum.frequencies_by(alarms, & &1.event_type)
  end

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
