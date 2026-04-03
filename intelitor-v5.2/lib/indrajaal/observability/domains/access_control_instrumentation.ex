defmodule Indrajaal.Observability.Domains.AccessControlInstrumentation do
  @moduledoc """
  require Logger
  Domain-specific instrumentation for the Access Control domain.

  Provides comprehensive telemetry and tracing for access control operations,
  security events, credential validation, and STAMP safety monitoring.
  """

  use Indrajaal.Observability.InstrumentationBase,
    domain: :access_control

  # EP-012: Tracing alias removed (unused)

  alias Indrajaal.Observability.Domains.InstrumentationHelpers

  @access_control_resources [
    Indrajaal.AccessControl.AccessCredential,
    Indrajaal.AccessControl.AccessGrant,
    Indrajaal.AccessControl.AccessLevel,
    Indrajaal.AccessControl.AccessRequest,
    Indrajaal.AccessControl.AccessRevocation,
    Indrajaal.AccessControl.AccessRule,
    Indrajaal.AccessControl.AccessSchedule,
    Indrajaal.AccessControl.AccessException,
    Indrajaal.AccessControl.AccessLog,
    Indrajaal.AccessControl.VisitorPass,
    Indrajaal.AccessControl.AntiPassback
  ]

  # EP-013: Security critical operations and high security access levels (unused but kept for future security validation)
  # @security_critical_operations [:grant_access, :revoke_access, :create_credential, :modify_access_level]
  # @high_security_access_levels ["executive", "security", "admin", "maximum_security"]
  @safety_critical_access_levels ["Maximum Security"]

  @doc """
  Sets up telemetry handlers for the Access Control domain.
  """
  def setup do
    # Attach handlers for Ash lifecycle events
    attach_lifecycle_handlers()

    # Attach handlers for security-specific events
    attach_security_handlers()

    :ok
  end

  def handle_event(event, measurements, metadata) do
    :telemetry.execute(
      [:indrajaal, :observability, :access_control, :event],
      measurements,
      Map.merge(metadata, %{original_event: event})
    )

    :ok
  end

  def get_metrics do
    {:ok, %{status: :active, domain: :access_control}}
  end

  def record_metric(name, value) do
    :telemetry.execute(
      [:indrajaal, :observability, :access_control, :metric],
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
       domain: :access_control,
       access_control_resources: @access_control_resources,
       safety_critical_access_levels: @safety_critical_access_levels
     ]}
  end

  def shutdown do
    :ok
  end

  defp attach_lifecycle_handlers do
    # Create operation handlers
    :telemetry.attach_many(
      "access-control-instrumentation-create",
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
      "access-control-instrumentation-update",
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
      "access-control-instrumentation-read",
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
      "access-control-instrumentation-destroy",
      [
        [:ash, :changeset, :destroy, :start],
        [:ash, :changeset, :destroy, :stop],
        [:ash, :changeset, :destroy, :exception]
      ],
      &handle_changeset_event/4,
      %{operation: :destroy}
    )
  end

  defp attach_security_handlers do
    # These would be attached to custom security events in the access control system
    handlers = [
      {"access-control-security-grant", [:indrajaal, :access_control, :security, :access_granted],
       &handle_security_event/4},
      {"access-control-security-deny", [:indrajaal, :access_control, :security, :access_denied],
       &handle_security_event/4},
      {"access-control-security-validate",
       [:indrajaal, :access_control, :security, :credential_validation],
       &handle_security_event/4},
      {"access-control-security-rules",
       [:indrajaal, :access_control, :security, :rule_evaluation], &handle_security_event/4}
    ]

    Enum.each(handlers, fn {id, event, handler} ->
      :telemetry.attach(id, event, handler, nil)
    end)
  end

  # Handler for changeset events (create, update, destroy)
  defp handle_changeset_event(event, measurements, metadata, config) do
    operation = config.operation
    phase = List.last(event)

    if access_control_resource?(metadata.resource) do
      handle_operation_phase(operation, phase, measurements, metadata)
    end
  end

  # Handler for query events (read)
  defp handle_query_event(event, measurements, metadata, config) do
    operation = config.operation
    phase = List.last(event)

    if access_control_resource?(metadata.resource || metadata.query.resource) do
      handle_operation_phase(operation, phase, measurements, metadata)
    end
  end

  # Security event handlers
  defp handle_security_event(event, measurements, metadata, _config) do
    # Security events already have the full event name
    action = List.last(event)

    enriched =
      metadata
      |> Map.put(:security_event, true)
      |> add_security_event_attributes(action, metadata)

    # Security events don't follow start/stop pattern, they're single events
    :telemetry.execute(event, measurements, enriched)

    # Record business metrics for security events
    record_security_metrics(action, enriched)
  end

  defp add_security_event_attributes(metadata, :access_denied, _original) do
    metadata
    |> Map.put(:security_alert_generated, true)
  end

  defp add_security_event_attributes(metadata, :credential_validation, original) do
    if original[:validation_result] == "success" && original[:anti_passback_check] == "passed" do
      Map.put(metadata, :security_checks_passed, true)
    else
      metadata
    end
  end

  defp add_security_event_attributes(metadata, :rule_evaluation, original) do
    if original[:override_applied] do
      Map.put(metadata, :security_audit_required, true)
    else
      metadata
    end
  end

  defp add_security_event_attributes(metadata, _, _), do: metadata

  defp record_security_metrics(:access_granted, enriched) do
    Indrajaal.Observability.Metrics.increment(
      "intelitor.access_control.access_granted_total",
      1,
      enriched
    )
  end

  defp record_security_metrics(:access_denied, enriched) do
    Indrajaal.Observability.Metrics.increment(
      "intelitor.access_control.access_denied_total",
      1,
      enriched
    )
  end

  defp record_security_metrics(:credential_validation, enriched) do
    Indrajaal.Observability.Metrics.increment(
      "intelitor.access_control.credentials_validated_total",
      1,
      enriched
    )
  end

  defp record_security_metrics(_, _), do: :ok

  defp record_creation_metrics(%{resource_type: :access_grant} = metadata) do
    Indrajaal.Observability.Metrics.increment(
      "intelitor.access_control.access_grants_created_total",
      1,
      metadata
    )
  end

  defp record_creation_metrics(%{resource_type: :access_credential} = metadata) do
    Indrajaal.Observability.Metrics.increment(
      "intelitor.access_control.credentials_created_total",
      1,
      metadata
    )
  end

  defp record_creation_metrics(_), do: :ok

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
    emit_domain_event(operation, :start, measurements, enriched)
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

  # Helper to check if resource is access control-related
  defp access_control_resource?(resource) do
    resource in @access_control_resources
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
    |> add_access_control_attributes(metadata)
    |> add_security_attributes(metadata)
    |> add_safety_attributes(metadata)
  end

  defp resource_type(resource) do
    resource
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> String.to_atom()
  end

  defp add_access_control_attributes(enriched, %{changeset: changeset}) do
    resource_type = enriched[:resource_type]

    case resource_type do
      :access_credential ->
        enriched
        |> add_if_present(changeset, :credential_type)
        |> add_if_present(changeset, :credential_number)
        |> add_if_present(changeset, :status)
        |> Map.put(:security_sensitive, true)

      :access_rule ->
        enriched
        |> add_if_present(changeset, :rule_type)
        |> Map.put(:security_impact, :high)

      :access_grant ->
        grant_duration = calculate_grant_duration(changeset)

        enriched
        |> Map.put(:resource_type, :access_grant)
        |> Map.put(:grant_duration_days, grant_duration)
        |> Map.put(:grant_type, if(grant_duration < 90, do: "temporary", else: "permanent"))
        |> Map.put(:security_audit_required, true)

      :access_request ->
        enriched
        |> add_if_present(changeset, :access_type)
        |> add_request_duration(changeset)
        |> add_areas_count(changeset)

      :access_level ->
        enriched
        |> add_if_present(changeset, :security_clearance_required)

      :access_revocation ->
        enriched
        |> add_if_present(changeset, :immediate)
        |> Map.put(:immediate_revocation, changeset.data.immediate || false)
        |> Map.put(:safety_actions_triggered, [
          "notify_security",
          "update_access_points",
          "audit_log"
        ])

      _ ->
        enriched
    end
  end

  defp add_access_control_attributes(enriched, _), do: enriched

  defp add_if_present(enriched, changeset, field) do
    case Ash.Changeset.get_attribute(changeset, field) ||
           Ash.Changeset.fetch_change(changeset, field) do
      nil -> enriched
      value -> Map.put(enriched, field, value)
    end
  end

  defp calculate_grant_duration(changeset) do
    valid_from =
      Ash.Changeset.get_attribute(changeset, :valid_from) ||
        Ash.Changeset.fetch_change(changeset, :valid_from) ||
        DateTime.utc_now()

    valid_until =
      Ash.Changeset.get_attribute(changeset, :valid_until) ||
        Ash.Changeset.fetch_change(changeset, :valid_until)

    if valid_from && valid_until do
      DateTime.diff(valid_until, valid_from, :day)
    else
      0
    end
  end

  defp add_request_duration(enriched, changeset) do
    requested_from =
      Ash.Changeset.get_attribute(changeset, :_requested_from) ||
        Ash.Changeset.fetch_change(changeset, :_requested_from)

    requested_until =
      Ash.Changeset.get_attribute(changeset, :_requested_until) ||
        Ash.Changeset.fetch_change(changeset, :_requested_until)

    if requested_from && requested_until do
      Map.put(enriched, :duration_hours, DateTime.diff(requested_until, requested_from, :hour))
    else
      enriched
    end
  end

  defp add_areas_count(enriched, changeset) do
    areas =
      Ash.Changeset.get_attribute(changeset, :_requested_areas) ||
        Ash.Changeset.fetch_change(changeset, :_requested_areas) ||
        []

    Map.put(enriched, :areas_count, length(areas))
  end

  defp add_security_attributes(enriched, _metadata) do
    enriched
    |> Map.put(:security_event, true)
  end

  defp add_safety_attributes(enriched, metadata) do
    resource_type = enriched[:resource_type]

    cond do
      safety_critical_resource?(resource_type, enriched) ->
        enriched
        |> Map.put(:safety_critical, true)
        |> Map.put(:safety_constraints, get_safety_constraints(resource_type, enriched))

      unsafe_control_action?(resource_type, enriched, metadata) ->
        enriched
        |> Map.put(:unsafe_control_action, true)
        |> add_safety_violation_details(resource_type, metadata)

      true ->
        enriched
    end
  end

  defp safety_critical_resource?(:access_level, enriched) do
    enriched[:name] in @safety_critical_access_levels ||
      enriched[:security_clearance_required] == true
  end

  defp safety_critical_resource?(_, _), do: false

  defp get_safety_constraints(:access_level, _enriched) do
    ["dual_authorization_required", "audit_trail_mandatory", "periodic_review_required"]
  end

  defp get_safety_constraints(_, _), do: []

  defp unsafe_control_action?(:access_grant, enriched, %{changeset: changeset}) do
    # Check if granting access to suspended credential
    credential_id =
      Ash.Changeset.get_attribute(changeset, :access_credential_id) ||
        Ash.Changeset.fetch_change(changeset, :access_credential_id)

    if credential_id do
      # In a real implementation, we'd look up the credential
      # For now, check if the metadata indicates suspended status
      enriched[:credential_status] == "suspended"
    else
      false
    end
  end

  defp unsafe_control_action?(_, _, _), do: false

  defp add_safety_violation_details(enriched, :accessgrant, _metadata) do
    enriched
    |> Map.put(:safety_violation, "grant_to_suspended_credential")
    |> Map.put(:_required_credential_status, ["active", "pending_activation"])
  end

  defp add_safety_violation_details(enriched, _resource_type, _metadata), do: enriched

  defp add_exception_metadata(enriched, %{kind: kind, reason: reason} = metadata) do
    error_fields = extract_error_fields(reason)

    enriched
    |> Map.put(:error_kind, kind)
    |> Map.put(:error_reason, inspect(reason))
    |> Map.put(:error_fields, error_fields)
    |> add_unsafe_control_action_exception(metadata)
  end

  defp add_exception_metadata(enriched, metadata) do
    error_fields = extract_error_fields(metadata[:error] || metadata[:reason])
    Map.put(enriched, :error_fields, error_fields)
  end

  defp add_unsafe_control_action_exception(enriched, %{changeset: _changeset} = metadata) do
    # Check for credential status violations
    if enriched[:resource_type] == :access_grant &&
         metadata[:reason] &&
         String.contains?(inspect(metadata[:reason]), "suspended") do
      enriched
      |> Map.put(:unsafe_control_action, true)
      |> Map.put(:safety_violation, "grant_to_suspended_credential")
      |> Map.put(:_required_credential_status, ["active", "pending_activation"])
    else
      enriched
    end
  end

  defp add_unsafe_control_action_exception(enriched, _), do: enriched

  defp add_result_specific_metadata(enriched, :read, results) when is_list(results) do
    Map.put(enriched, :result_count, length(results))
  end

  defp add_result_specific_metadata(enriched, :read, _result) do
    Map.put(enriched, :result_count, 1)
  end

  defp add_result_specific_metadata(enriched, _, _), do: enriched

  defp extract_error_fields(%{errors: errors}) when is_list(errors) do
    errors
    |> Enum.map(fn
      %{field: field} -> field
      _ -> :unknown
    end)
    |> Enum.uniq()
  end

  defp extract_error_fields(_), do: []

  defp get_tenant_id(%{tenant: %{id: id}}), do: id
  defp get_tenant_id(%{__context: %{tenant: %{id: id}}}), do: id
  defp get_tenant_id(_), do: nil

  defp get_actor_id(%{actor: %{id: id}}), do: id
  defp get_actor_id(%{__context: %{actor: %{id: id}}}), do: id
  defp get_actor_id(_), do: nil

  # Emit domain-specific telemetry events
  defp emit_domain_event(category, phase, measurements, metadata) do
    event = [:indrajaal, :access_control, category, phase]

    enriched_measurements =
      measurements
      |> Map.put(:timestamp, System.monotonic_time())
      |> Map.put(:monotonic_time, measurements[:monotonic_time] || System.monotonic_time())

    # Ensure we have duration for stop events
    enriched_measurements =
      if phase == :stop && measurements[:duration] do
        Map.put(enriched_measurements, :duration, measurements[:duration])
      else
        enriched_measurements
      end

    :telemetry.execute(event, enriched_measurements, metadata)

    # Record business metrics for successful creation
    if category == :create && phase == :stop do
      record_creation_metrics(metadata)
    end

    # Log for observability
    if phase == :exception do
      Logger.error("Access Control domain error", metadata: metadata)
    end
  end
end
