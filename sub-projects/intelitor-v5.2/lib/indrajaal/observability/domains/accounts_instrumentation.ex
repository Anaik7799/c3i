defmodule Indrajaal.Observability.Domains.AccountsInstrumentation do
  @moduledoc """
  require Logger
  Domain-specific instrumentation for the Accounts domain.

  Provides comprehensive telemetry and tracing for user management,
  authentication events, security operations, and STAMP safety monitoring.
  """

  use Indrajaal.Observability.InstrumentationBase,
    domain: :accounts

  # EP-012: Tracing alias removed (unused)

  alias Indrajaal.Observability.Domains.InstrumentationHelpers

  @accounts_resources [
    Indrajaal.Accounts.User,
    Indrajaal.Accounts.Account,
    Indrajaal.Accounts.Team,
    Indrajaal.Accounts.TeamMembership,
    Indrajaal.Accounts.Session,
    Indrajaal.Accounts.Token,
    Indrajaal.Accounts.Profile,
    Indrajaal.Accounts.ActivityLog,
    Indrajaal.Accounts.Authentication,
    Indrajaal.Accounts.SessionSecurity
  ]

  @privileged_roles ["admin", "security", "super_admin"]
  # EP-013: Security critical operations module attribute (unused but kept for future reference)

  @doc """
  Sets up telemetry handlers for the Accounts domain.
  """
  def setup do
    # Attach handlers for Ash lifecycle events
    attach_lifecycle_handlers()

    # Attach handlers for authentication events
    attach_authentication_handlers()

    # Attach handlers for security events
    attach_security_handlers()

    :ok
  end

  def handle_event(event, measurements, metadata) do
    :telemetry.execute(
      [:indrajaal, :observability, :accounts, :event],
      measurements,
      Map.merge(metadata, %{original_event: event})
    )

    :ok
  end

  def get_metrics do
    {:ok, %{status: :active, domain: :accounts}}
  end

  def record_metric(name, value) do
    :telemetry.execute(
      [:indrajaal, :observability, :accounts, :metric],
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
       domain: :accounts,
       accounts_resources: @accounts_resources,
       privileged_roles: @privileged_roles
     ]}
  end

  def shutdown do
    :ok
  end

  defp attach_lifecycle_handlers do
    # Create operation handlers
    :telemetry.attach_many(
      "accounts-instrumentation-create",
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
      "accounts-instrumentation-update",
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
      "accounts-instrumentation-read",
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
      "accounts-instrumentation-destroy",
      [
        [:ash, :changeset, :destroy, :start],
        [:ash, :changeset, :destroy, :stop],
        [:ash, :changeset, :destroy, :exception]
      ],
      &handle_changeset_event/4,
      %{operation: :destroy}
    )
  end

  defp attach_authentication_handlers do
    auth_events = [
      [:indrajaal, :accounts, :authentication, :login_attempt],
      [:indrajaal, :accounts, :authentication, :login_success],
      [:indrajaal, :accounts, :authentication, :login_failure],
      [:indrajaal, :accounts, :authentication, :logout],
      [:indrajaal, :accounts, :authentication, :token_refresh],
      [:indrajaal, :accounts, :authentication, :session_expired]
    ]

    Enum.each(auth_events, fn event ->
      handler_id = "accounts-auth-" <> Enum.join(Enum.take(event, -2), "-")
      :telemetry.attach(handler_id, event, &handle_auth_event/4, nil)
    end)
  end

  defp attach_security_handlers do
    security_events = [
      [:indrajaal, :accounts, :security, :password_change],
      [:indrajaal, :accounts, :security, :mfa_enabled],
      [:indrajaal, :accounts, :security, :suspicious_activity]
    ]

    Enum.each(security_events, fn event ->
      handler_id = "accounts-security-" <> Enum.join(Enum.take(event, -2), "-")
      :telemetry.attach(handler_id, event, &handle_security_event/4, nil)
    end)
  end

  # Handler for changeset events (create, update, destroy)
  defp handle_changeset_event(event, measurements, metadata, _config) do
    operation = :changeset
    phase = List.last(event)

    if accounts_resource?(metadata.resource) do
      handle_operation_phase(operation, phase, measurements, metadata)
    end
  end

  # Handler for query events (read)
  defp handle_query_event(event, measurements, metadata, _config) do
    operation = :query
    phase = List.last(event)

    if accounts_resource?(metadata.resource || metadata.query.resource) do
      handle_operation_phase(operation, phase, measurements, metadata)
    end
  end

  # Handler for authentication events
  defp handle_auth_event(event, measurements, metadata, _config) do
    # Auth events are already domain-specific, just enhance metadata
    action = List.last(event)

    enriched =
      metadata
      |> Map.put(:security_event, true)
      |> Map.put(:security_audit, true)
      |> add_auth_specific_attributes(action, metadata)

    # Auth events don't need transformation, they're already in the right format
    :telemetry.execute(event, measurements, enriched)
  end

  defp add_auth_specific_attributes(metadata, :loginfailure, original) do
    consecutive_failures = original[:consecutive_failures] || 1

    metadata
    |> Map.put(:security_alert, consecutive_failures >= 3)
    |> Map.put(:rate_limit_check, true)
  end

  defp add_auth_specific_attributes(metadata, :login_success, _original) do
    Map.put(metadata, :security_audit, true)
  end

  defp add_auth_specific_attributes(metadata, :logout, original) do
    if original[:session_duration_ms] do
      Map.put(metadata, :session_duration_minutes, div(original[:session_duration_ms], 60_000))
    else
      metadata
    end
  end

  defp add_auth_specific_attributes(metadata, :token_refresh, _original) do
    Map.put(metadata, :token_rotation_successful, true)
  end

  defp add_auth_specific_attributes(metadata, _, _), do: metadata

  # Handler for security events
  defp handle_security_event(event, measurements, metadata, _config) do
    action = List.last(event)

    enriched =
      metadata
      |> Map.put(:security_audit_required, true)
      |> add_security_specific_attributes(action, metadata)

    # Security events are already in the right format
    :telemetry.execute(event, measurements, enriched)
  end

  defp add_security_specific_attributes(metadata, :password_change, _original) do
    metadata
    |> Map.put(:notification_sent, true)
  end

  defp add_security_specific_attributes(metadata, :mfa_enabled, _original) do
    Map.put(metadata, :security_posture_improved, true)
  end

  defp add_security_specific_attributes(metadata, :suspicious_activity, original) do
    metadata
    |> Map.put(:security_alert_raised, true)
    |> Map.put(:automatic_response, original[:action_taken])
  end

  defp add_security_specific_attributes(metadata, _, _), do: metadata

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

  # Helper to check if resource is accounts-related
  defp accounts_resource?(resource) do
    resource in @accounts_resources
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
    |> add_accounts_attributes(metadata)
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

  defp add_accounts_attributes(enriched, %{changeset: changeset}) do
    resource_type = enriched[:resource_type]

    case resource_type do
      :user ->
        enriched
        |> add_if_present(changeset, :email)
        |> add_if_present(changeset, :role)
        |> add_if_present(changeset, :__username)
        |> add_email_domain(changeset)
        |> add_profile_completeness(changeset)
        |> Map.put(:security_event, true)

      :team ->
        permissions =
          Ash.Changeset.get_attribute(changeset, :permissions) ||
            Ash.Changeset.fetch_change(changeset, :permissions) ||
            []

        enriched
        |> add_if_present(changeset, :name)
        |> Map.put(:permissions_count, length(permissions))
        |> Map.put(:security_impact, :high)

      :team_membership ->
        enriched
        |> add_if_present(changeset, :role)
        |> add_if_present(changeset, :team_id)
        |> Map.put(:member_role, changeset.data[:role] || get_change(changeset, :role))

      :session ->
        enriched
        |> add_if_present(changeset, :ip_address)
        |> add_session_duration(changeset)
        |> Map.put(:security_tracking, true)

      _ ->
        enriched
    end
  end

  defp add_accounts_attributes(enriched, _), do: enriched

  defp add_email_domain(enriched, changeset) do
    case Ash.Changeset.get_attribute(changeset, :email) ||
           Ash.Changeset.fetch_change(changeset, :email) do
      nil ->
        enriched

      email ->
        email_parts = String.split(email, "@")
        Map.put(enriched, :email_domain, email_parts |> List.last())
    end
  end

  defp add_profile_completeness(enriched, changeset) do
    fields = [:first_name, :last_name, :phone, :avatar_url, :timezone]

    filled_count =
      fields
      |> Enum.count(fn field ->
        Ash.Changeset.get_attribute(changeset, field) != nil ||
          Ash.Changeset.fetch_change(changeset, field) != nil
      end)

    Map.put(enriched, :profile_completeness, filled_count / length(fields) * 100)
  end

  defp add_session_duration(enriched, changeset) do
    case Ash.Changeset.get_attribute(changeset, :expires_at) ||
           Ash.Changeset.fetch_change(changeset, :expires_at) do
      nil ->
        enriched

      expires_at ->
        duration_minutes = DateTime.diff(expires_at, DateTime.utc_now(), :minute)
        Map.put(enriched, :session_duration_minutes, duration_minutes)
    end
  end

  defp add_if_present(enriched, changeset, field) do
    case Ash.Changeset.get_attribute(changeset, field) ||
           Ash.Changeset.fetch_change(changeset, field) do
      nil -> enriched
      value -> Map.put(enriched, field, value)
    end
  end

  defp get_change(changeset, field) do
    Ash.Changeset.fetch_change(changeset, field)
  end

  defp add_security_attributes(enriched, metadata) do
    if enriched[:operation] == :update do
      # Track which fields were updated
      updated_fields =
        case metadata[:changeset] do
          %{changes: changes} when is_map(changes) ->
            Map.keys(changes)

          _ ->
            []
        end

      Map.put(enriched, :updated_fields, updated_fields)
    else
      enriched
    end
  end

  defp add_safety_attributes(enriched, metadata) do
    resource_type = enriched[:resource_type]
    role = enriched[:role]

    cond do
      safety_critical_operation?(resource_type, role, metadata) ->
        enriched
        |> Map.put(:safety_critical, true)
        |> Map.put(:safety_constraints, get_safety_constraints(resource_type, role))

      unsafe_control_action?(resource_type, enriched, metadata) ->
        enriched
        |> Map.put(:unsafe_control_action, true)
        |> add_safety_violation_details(resource_type, metadata)

      true ->
        enriched
    end
  end

  defp safety_critical_operation?(:user, role, _metadata) do
    role in @privileged_roles
  end

  defp safety_critical_operation?(_, _, _), do: false

  defp get_safety_constraints(:user, role) when role in @privileged_roles do
    ["mfa_mandatory", "audit_all_actions", "privileged_access_monitoring"]
  end

  defp get_safety_constraints(_, _), do: []

  defp unsafe_control_action?(:user, _enriched, %{changeset: changeset} = metadata) do
    # Check for unauthorized privilege escalation
    _current_role = changeset.data[:role]
    new_role = Ash.Changeset.fetch_change(changeset, :role)
    actor_role = get_actor_role(metadata)

    # Privilege escalation attempt
    new_role && new_role in @privileged_roles && actor_role != "admin"
  end

  defp unsafe_control_action?(_, _, _), do: false

  defp add_safety_violation_details(enriched, _, _), do: enriched

  defp get_actor_role(%{actor: %{role: role}}), do: role
  defp get_actor_role(%{__context: %{actor: %{role: role}}}), do: role
  defp get_actor_role(_), do: nil

  defp add_exception_metadata(enriched, %{kind: kind, reason: reason} = metadata) do
    error_fields = extract_error_fields(reason)

    enriched
    |> Map.put(:error_kind, kind)
    |> Map.put(:error_reason, inspect(reason))
    |> Map.put(:error_fields, error_fields)
    |> check_exception_safety_violations(metadata)
  end

  defp add_exception_metadata(enriched, metadata) do
    error_fields = extract_error_fields(metadata[:error] || metadata[:reason])
    Map.put(enriched, :error_fields, error_fields)
  end

  defp check_exception_safety_violations(enriched, %{changeset: changeset} = metadata) do
    # Check if this was an unauthorized privilege escalation attempt
    if enriched[:resource_type] == :user &&
         Ash.Changeset.changing_attribute?(changeset, :role) do
      add_safety_violation_details(enriched, :user, metadata)
    else
      enriched
    end
  end

  defp check_exception_safety_violations(enriched, _), do: enriched

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

  # Check for unsafe authentication patterns (for security monitoring)
  defp detect_unsafe_auth_pattern(metadata, :loginfailure) do
    consecutive_failures = metadata[:consecutive_failures] || 0

    if consecutive_failures >= 5 do
      metadata
      |> Map.put(:unsafe_pattern_detected, true)
      |> Map.put(:pattern_type, "brute_force_attempt")
      |> Map.put(:recommended_action, "temporary_lockout")
    else
      metadata
    end
  end

  defp detect_unsafe_auth_pattern(metadata, _), do: metadata

  defp get_tenant_id(%{tenant: %{id: id}}), do: id
  defp get_tenant_id(%{__context: %{tenant: %{id: id}}}), do: id
  defp get_tenant_id(%{tenant_id: id}) when not is_nil(id), do: id
  defp get_tenant_id(_), do: nil

  defp get_actor_id(%{actor: %{id: id}}), do: id
  defp get_actor_id(%{__context: %{actor: %{id: id}}}), do: id
  defp get_actor_id(%{user_id: id}) when not is_nil(id), do: id
  defp get_actor_id(_), do: nil

  # Emit domain-specific telemetry events
  defp emit_domain_event(category, phase, measurements, metadata) do
    event = [:indrajaal, :accounts, category, phase]

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

    # Apply pattern detection for security monitoring
    enriched_metadata =
      if metadata[:operation] == :authentication do
        detect_unsafe_auth_pattern(metadata, phase)
      else
        metadata
      end

    :telemetry.execute(event, enriched_measurements, enriched_metadata)

    # Log for observability
    if phase == :exception do
      Logger.error("Accounts domain error", metadata: enriched_metadata)
    end
  end
end
