defmodule Indrajaal.Observability.Domains.AlarmsInstrumentation do
  @moduledoc """
  require Logger
  Domain-specific instrumentation for the Alarms domain.

  Provides comprehensive telemetry and tracing for alarm lifecycle events,
  security-critical operations, and STAMP safety monitoring.
  """

  # @behaviour removed - already set by use statement below via __using__ macro
  use Indrajaal.Observability.InstrumentationBase, domain: :alarms
  # EP-012: Tracing alias removed (unused)

  alias Indrajaal.Observability.Domains.InstrumentationHelpers

  @alarm_resources [
    Indrajaal.Alarms.AlarmEvent,
    Indrajaal.Alarms.Response,
    Indrajaal.Alarms.DispatchLog,
    Indrajaal.Alarms.IncidentType,
    Indrajaal.Alarms.WorkflowTemplate
  ]

  @critical_alarm_types ["fire_detected", "intrusion_detected", "system_failure", "panic_alarm"]
  @safety_critical_priorities ["critical", "emergency"]

  @doc """
  Sets up telemetry handlers for the Alarms domain.
  """
  def setup do
    # Attach handlers for Ash lifecycle events with proper phases
    attach_lifecycle_handlers()

    :ok
  end

  def handle_event(event, measurements, metadata) do
    :telemetry.execute(
      [:indrajaal, :observability, :alarms, :event],
      measurements,
      Map.merge(metadata, %{original_event: event})
    )

    :ok
  end

  def get_metrics do
    {:ok, %{status: :active, domain: :alarms}}
  end

  def record_metric(name, value) do
    :telemetry.execute(
      [:indrajaal, :observability, :alarms, :metric],
      %{value: value},
      %{name: name}
    )

    :ok
  end

  def configure(_opts) do
    :ok
  end

  def get_configuration do
    {:ok,
     [
       domain: :alarms,
       alarm_resources: @alarm_resources,
       critical_alarm_types: @critical_alarm_types,
       safety_critical_priorities: @safety_critical_priorities
     ]}
  end

  def shutdown do
    :ok
  end

  defp attach_lifecycle_handlers do
    # Ash emits multiple events per operation: start, stop, and exception
    # We need to handle each phase appropriately

    # Create operation handlers
    :telemetry.attach_many(
      "alarms-instrumentation-create",
      [
        [:ash, :changeset, :create, :start],
        [:ash, :changeset, :create, :stop],
        [:ash, :changeset, :create, :exception]
      ],
      &handle_changeset_event/4,
      %{operation: :create}
    )

    # Update operation handlers
    :telemetry.attach_many(
      "alarms-instrumentation-update",
      [
        [:ash, :changeset, :update, :start],
        [:ash, :changeset, :update, :stop],
        [:ash, :changeset, :update, :exception]
      ],
      &handle_changeset_event/4,
      %{operation: :update}
    )

    # Read operation handlers
    :telemetry.attach_many(
      "alarms-instrumentation-read",
      [
        [:ash, :query, :read, :start],
        [:ash, :query, :read, :stop],
        [:ash, :query, :read, :exception]
      ],
      &handle_query_event/4,
      %{operation: :read}
    )

    # Destroy operation handlers
    :telemetry.attach_many(
      "alarms-instrumentation-destroy",
      [
        [:ash, :changeset, :destroy, :start],
        [:ash, :changeset, :destroy, :stop],
        [:ash, :changeset, :destroy, :exception]
      ],
      &handle_changeset_event/4,
      %{operation: :destroy}
    )
  end

  # Handler for changeset events (create, update, destroy)
  defp handle_changeset_event(event, measurements, metadata, config) do
    operation = config.operation
    phase = List.last(event)

    if alarm_resource?(metadata.resource) do
      handle_operation_phase(operation, phase, measurements, metadata)
    end
  end

  # Handler for query events (read)
  defp handle_query_event(event, measurements, metadata, config) do
    operation = config.operation
    phase = List.last(event)

    if alarm_resource?(metadata.resource || metadata.query.resource) do
      handle_operation_phase(operation, phase, measurements, metadata)
    end
  end

  defp handle_operation_phase(operation, phase, measurements, metadata) do
    case phase do
      :start ->
        handle_operation_start(operation, measurements, metadata)

      :stop ->
        handle_operation_stop(operation, measurements, metadata)

      :exception ->
        handle_operation_exception(operation, measurements, metadata)
    end
  end

  defp handle_operation_start(operation, measurements, metadata) do
    enriched = enrich_metadata(metadata, operation)

    # Special handling for update operations
    enriched =
      if operation == :update && metadata.resource == Indrajaal.Alarms.AlarmEvent do
        track_state_transition(enriched, metadata)
      else
        enriched
      end

    emit_domain_event(operation, :start, measurements, enriched)

    # Also handle special lifecycle actions
    if operation == :update do
      handle_lifecycle_action(metadata, measurements)
    end
  end

  defp handle_operation_stop(operation, measurements, metadata) do
    InstrumentationHelpers.handle_stop_with_measurements(
      metadata,
      measurements,
      operation,
      &add_result_specific_metadata/3,
      fn -> enrich_metadata(metadata, operation) end,
      &emit_domain_event/4
    )
  end

  defp handle_operation_exception(operation, measurements, metadata) do
    enriched =
      metadata
      |> enrich_metadata(operation)
      |> add_exception_metadata(metadata)

    emit_domain_event(operation, :exception, measurements, enriched)
  end

  defp add_exception_metadata(
         enriched,
         %{kind: kind, reason: reason, stacktrace: _stacktrace} = metadata
       ) do
    error_fields = extract_error_fields(reason)

    enriched
    |> Map.put(:error_kind, kind)
    |> Map.put(:error_reason, inspect(reason))
    |> Map.put(:error_fields, error_fields)
    |> add_unsafe_control_action_metadata(metadata)
  end

  defp add_exception_metadata(enriched, metadata) do
    error_fields = extract_error_fields(metadata[:error] || metadata[:reason])
    Map.put(enriched, :error_fields, error_fields)
  end

  defp add_unsafe_control_action_metadata(enriched, metadata) do
    # Check if this was an unsafe control action
    case metadata do
      %{changeset: %{action: :update}, resource: Indrajaal.Alarms.AlarmEvent} ->
        # Check for state transition violations
        if enriched[:safety_violation] do
          enriched
          |> Map.put(:unsafe_control_action, true)
        else
          enriched
        end

      _ ->
        enriched
    end
  end

  defp add_result_specific_metadata(enriched, :read, results) when is_list(results) do
    Map.put(enriched, :result_count, length(results))
  end

  defp add_result_specific_metadata(enriched, :read, _result) do
    Map.put(enriched, :result_count, 1)
  end

  defp add_result_specific_metadata(enriched, _, _), do: enriched

  defp handle_lifecycle_action(%{changeset: changeset} = metadata, measurements) do
    action_name = changeset.action_name || changeset.action

    case action_name do
      :acknowledge ->
        emit_lifecycle_event(:acknowledged, measurements, metadata)

      :resolve ->
        emit_lifecycle_event(:resolved, measurements, metadata)

      :escalate ->
        emit_lifecycle_event(:escalated, measurements, metadata)

      _ ->
        :ok
    end
  end

  defp handle_lifecycle_action(_, _), do: :ok

  defp emit_lifecycle_event(action, measurements, metadata) do
    alarm = get_record(metadata)

    if alarm do
      enriched = %{
        alarm_id: alarm.id,
        alarm_type: alarm.alarm_type,
        priority: alarm.priority,
        tenant_id: get_tenant_id(metadata)
      }

      # Add timing metrics
      enriched =
        case action do
          :acknowledged ->
            time_to_acknowledge =
              if alarm.created_at do
                DateTime.diff(DateTime.utc_now(), alarm.created_at, :millisecond)
              else
                0
              end

            Map.put(enriched, :time_to_acknowledge, time_to_acknowledge)

          :resolved ->
            time_to_resolution =
              if alarm.created_at do
                DateTime.diff(DateTime.utc_now(), alarm.created_at, :millisecond)
              else
                0
              end

            enriched
            |> Map.put(:time_to_resolution, time_to_resolution)
            |> Map.put(:resolution_type, categorize_resolution(metadata))

          _ ->
            enriched
        end

      :telemetry.execute(
        [:indrajaal, :alarms, :lifecycle, action],
        Map.merge(measurements, %{
          time_to_acknowledge: enriched[:time_to_acknowledge] || 0,
          time_to_resolution: enriched[:time_to_resolution] || 0
        }),
        enriched
      )

      # Record business metrics for lifecycle events
      record_lifecycle_metrics(action, enriched)
    end
  end

  defp record_lifecycle_metrics(:acknowledged, enriched) do
    Indrajaal.Observability.Metrics.record_business_metric(
      :alarm_response_time,
      enriched.time_to_acknowledge / 1000,
      enriched
    )

    Indrajaal.Observability.Metrics.increment("intelitor.alarms.acknowledged_total", 1, enriched)
  end

  defp record_lifecycle_metrics(:resolved, enriched) do
    Indrajaal.Observability.Metrics.record_business_metric(
      :alarm_resolution_time,
      enriched.time_to_resolution / 1000,
      enriched
    )

    Indrajaal.Observability.Metrics.increment("intelitor.alarms.resolved_total", 1, enriched)
  end

  defp record_lifecycle_metrics(:escalated, enriched) do
    Indrajaal.Observability.Metrics.increment("intelitor.alarms.escalated_total", 1, enriched)
  end

  defp record_lifecycle_metrics(_, _), do: :ok

  # Helper to check if resource is alarm-related
  defp alarm_resource?(resource) do
    resource in @alarm_resources
  end

  # Enrich metadata with domain-specific attributes
  defp enrich_metadata(metadata, operation) do
    resource = metadata.resource || (metadata[:query] && metadata.query.resource) || nil

    base_enriched = %{
      resource: resource,
      resource_type: resource && resource_type(resource),
      tenant_id: get_tenant_id(metadata),
      actor_id: get_actor_id(metadata),
      operation: operation
    }

    enriched = Map.merge(metadata, base_enriched)

    enriched
    |> add_alarm_attributes(metadata)
    |> add_security_attributes(metadata)
    |> add_safety_attributes(metadata)
    |> add_query_attributes(metadata, operation)
  end

  defp add_query_attributes(enriched, %{query: query} = _metadata, :read) do
    # Extract query details
    enriched =
      case query.action && query.action.name do
        :list_by_priority ->
          enriched
          |> Map.put(:query_type, :list_by_priority)
          |> add_filter_attributes(query)

        action when is_atom(action) ->
          Map.put(enriched, :query_type, action)

        _ ->
          enriched
      end

    enriched
  end

  defp add_query_attributes(enriched, _, _), do: enriched

  defp add_filter_attributes(enriched, query) do
    # Check for priority filter in query arguments
    case query.arguments[:priority] do
      nil -> enriched
      priority -> Map.put(enriched, :filter_priority, priority)
    end
  end

  defp resource_type(resource) do
    resource
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> String.to_atom()
  end

  defp add_alarm_attributes(enriched, %{resource: Indrajaal.Alarms.AlarmEvent} = metadata) do
    alarm = get_record(metadata)

    if alarm do
      enriched
      |> Map.put(:alarm_type, alarm.alarm_type)
      |> Map.put(:priority, alarm.priority)
      |> Map.put(:state, alarm.state)
      |> Map.put(:source, alarm.source)
      |> Map.put(:alarm_id, alarm.id)
    else
      enriched
    end
  end

  defp add_alarm_attributes(enriched, _metadata), do: enriched

  defp add_security_attributes(enriched, _metadata) do
    alarm_type = Map.get(enriched, :alarm_type)
    priority = Map.get(enriched, :priority)

    enriched
    |> Map.put(:security_sensitive, security_sensitive?(alarm_type, priority))
    |> Map.put(:security_event, true)
  end

  defp add_safety_attributes(enriched, _metadata) do
    alarm_type = Map.get(enriched, :alarm_type)
    priority = Map.get(enriched, :priority)
    operation = Map.get(enriched, :operation)

    if safety_critical?(alarm_type, priority) do
      enriched
      |> Map.put(:safety_critical, true)
      |> Map.put(:safety_constraints, get_safety_constraints(operation, alarm_type, priority))
    else
      enriched
    end
  end

  defp security_sensitive?(alarm_type, priority) do
    alarm_type in @critical_alarm_types or priority in @safety_critical_priorities
  end

  defp safety_critical?(alarm_type, priority) do
    alarm_type in @critical_alarm_types or priority in @safety_critical_priorities
  end

  defp get_safety_constraints(:create, _alarm_type, "critical") do
    ["alarm_must_be_acknowledged", "critical_alarm_escalation_required", "audit_trail_mandatory"]
  end

  defp get_safety_constraints(:update, _alarm_type, "critical") do
    ["state_transition_validation", "authorization_required", "change_tracking"]
  end

  defp get_safety_constraints(_, _, _), do: []

  defp track_state_transition(enriched, metadata) do
    changeset = Map.get(metadata, :changeset)

    if changeset && Ash.Changeset.changing_attribute?(changeset, :state) do
      old_state = Ash.Changeset.get_attribute(changeset, :state)
      new_state = Ash.Changeset.fetch_change(changeset, :state)

      enriched
      |> Map.put(:state_transition, {old_state, new_state})
      |> validate_state_transition(old_state, new_state)
    else
      enriched
    end
  end

  defp validate_state_transition(enriched, old_state, new_state) do
    valid_transitions = %{
      "pending" => ["acknowledged", "resolved"],
      "acknowledged" => ["resolved", "escalated"],
      "escalated" => ["resolved"]
    }

    allowed = Map.get(valid_transitions, old_state, [])

    # Check for special safety violations
    cond do
      # Critical alarms must be acknowledged before resolution
      old_state == "pending" && new_state == "resolved" &&
          enriched[:priority] in @safety_critical_priorities ->
        enriched
        |> Map.put(:unsafe_control_action, true)
        |> Map.put(:safety_violation, "critical_alarm_resolved_without_acknowledgment")
        |> Map.put(:_required_state_path, [:pending, :acknowledged, :resolved])

      # Normal state transition validation
      new_state not in allowed ->
        enriched
        |> Map.put(:unsafe_control_action, true)
        |> Map.put(:safety_violation, "invalid_state_transition")
        |> Map.put(:_required_state_path, get_required_path(old_state))

      true ->
        enriched
    end
  end

  defp get_required_path("pending"), do: [:pending, :acknowledged, :resolved]
  defp get_required_path("acknowledged"), do: [:acknowledged, :resolved]
  defp get_required_path(_), do: []

  # EP-013: Unused lifecycle metrics functions removed for cleaner codebase
  # Lifecycle metrics will be implemented when telemetry integration is complete
  # defp add_lifecycle_metrics(metadata, __context), do: metadata

  defp categorize_resolution(%{changeset: changeset}) do
    case Ash.Changeset.fetch_change(changeset, :resolution) do
      res when is_binary(res) ->
        cond do
          String.contains?(String.downcase(res), "false") -> "false_alarm"
          String.contains?(String.downcase(res), "test") -> "test"
          true -> "resolved"
        end

      _ ->
        "unknown"
    end
  end

  defp categorize_resolution(_), do: "unknown"

  defp get_tenant_id(%{tenant: %{id: id}}), do: id
  defp get_tenant_id(%{context: %{tenant: %{id: id}}}), do: id
  defp get_tenant_id(_), do: nil

  defp get_actor_id(%{actor: %{id: id}}), do: id
  defp get_actor_id(%{context: %{actor: %{id: id}}}), do: id
  defp get_actor_id(_), do: nil

  defp get_record(%{changeset: %{data: data}}), do: data
  defp get_record(%{query: %{results: [result | _]}}), do: result
  defp get_record(%{results: [result | _]}), do: result
  defp get_record(%{record: record}), do: record
  defp get_record(_), do: nil

  # Emit domain-specific telemetry events
  defp emit_domain_event(category, phase, measurements, metadata) do
    event = [:indrajaal, :alarms, category, phase]

    result_measurements = add_result_measurements(phase, metadata)

    enriched_measurements =
      measurements
      |> Map.put(:timestamp, System.monotonic_time())
      |> Map.merge(result_measurements)

    result_metadata = add_result_metadata(phase, metadata)

    enriched_metadata =
      metadata
      |> Map.merge(result_metadata)
      |> ensure_safety_monitoring(category, phase)

    :telemetry.execute(event, enriched_measurements, enriched_metadata)

    # Record business metrics for successful creation
    if category == :create && phase == :stop do
      Indrajaal.Observability.Metrics.increment(
        "intelitor.alarms.created_total",
        1,
        enriched_metadata
      )
    end

    # Log for observability
    if phase == :exception do
      Logger.error("Alarms domain error", metadata: enriched_metadata)
    end
  end

  # Measurements helpers for telemetry events
  defp add_result_measurements(:stop, %{result: {:ok, results}}) when is_list(results) do
    %{result_count: length(results)}
  end

  defp add_result_measurements(:stop, _), do: %{}
  defp add_result_measurements(_, _), do: %{}

  # Result metadata helpers
  defp add_result_metadata(:stop, %{result: {:ok, _}}) do
    %{result: :ok}
  end

  defp add_result_metadata(:stop, %{result: {:error, error}}) do
    %{result: :error, error: inspect(error)}
  end

  defp add_result_metadata(:exception, %{error: error}) do
    error_fields = extract_error_fields(error)
    %{error_fields: error_fields}
  end

  defp add_result_metadata(_, _), do: %{}

  defp extract_error_fields(%{errors: errors}) when is_list(errors) do
    errors
    |> Enum.map(fn
      %{field: field} -> field
      _ -> :unknown
    end)
    |> Enum.uniq()
  end

  defp extract_error_fields(_), do: []

  defp ensure_safety_monitoring(metadata, :create, :exception) do
    if metadata[:safety_critical] do
      metadata
      |> Map.put(:safety_monitoring_alert, true)
      |> Map.put(:safety_action_required, "review_critical_alarm_failure")
    else
      metadata
    end
  end

  defp ensure_safety_monitoring(metadata, _, _), do: metadata
end
