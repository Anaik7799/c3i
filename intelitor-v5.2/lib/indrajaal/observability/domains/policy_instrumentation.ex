defmodule Indrajaal.Observability.Domains.PolicyInstrumentation do
  @moduledoc """
  Domain-specific instrumentation for the Policy domain.

  Provides comprehensive telemetry and tracing for policy lifecycle events,
  role assignments, permission changes, and STAMP safety monitoring.
  """

  require Logger
  use Indrajaal.Observability.InstrumentationBase, domain: :policy

  alias Indrajaal.Observability.Domains.InstrumentationHelpers

  @policy_resources [
    Indrajaal.Policy.Role,
    Indrajaal.Policy.Permission,
    Indrajaal.Policy.UserRole,
    Indrajaal.Policy.RolePermission,
    Indrajaal.Policy.AccessRule
  ]

  @critical_operations [:grant, :revoke, :assign_role, :remove_role]
  @security_sensitive_resources [
    Indrajaal.Policy.Permission,
    Indrajaal.Policy.RolePermission
  ]

  @doc """
  Sets up telemetry handlers for the Policy domain.
  """
  def setup do
    attach_lifecycle_handlers()
    :ok
  end

  def handle_event(event, measurements, metadata) do
    :telemetry.execute(
      [:indrajaal, :observability, :policy, :event],
      measurements,
      Map.merge(metadata, %{original_event: event})
    )

    :ok
  end

  def get_metrics do
    {:ok, %{status: :active, domain: :policy}}
  end

  def record_metric(name, value) do
    :telemetry.execute(
      [:indrajaal, :observability, :policy, :metric],
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
       domain: :policy,
       policy_resources: @policy_resources,
       critical_operations: @critical_operations,
       security_sensitive_resources: @security_sensitive_resources
     ]}
  end

  def shutdown do
    :ok
  end

  defp attach_lifecycle_handlers do
    :telemetry.attach_many(
      "policy-instrumentation-create",
      [
        [:ash, :changeset, :create, :start],
        [:ash, :changeset, :create, :stop],
        [:ash, :changeset, :create, :exception]
      ],
      &handle_changeset_event/4,
      %{operation: :create}
    )

    :telemetry.attach_many(
      "policy-instrumentation-update",
      [
        [:ash, :changeset, :update, :start],
        [:ash, :changeset, :update, :stop],
        [:ash, :changeset, :update, :exception]
      ],
      &handle_changeset_event/4,
      %{operation: :update}
    )

    :telemetry.attach_many(
      "policy-instrumentation-read",
      [
        [:ash, :query, :read, :start],
        [:ash, :query, :read, :stop],
        [:ash, :query, :read, :exception]
      ],
      &handle_query_event/4,
      %{operation: :read}
    )

    :telemetry.attach_many(
      "policy-instrumentation-destroy",
      [
        [:ash, :changeset, :destroy, :start],
        [:ash, :changeset, :destroy, :stop],
        [:ash, :changeset, :destroy, :exception]
      ],
      &handle_changeset_event/4,
      %{operation: :destroy}
    )
  end

  defp handle_changeset_event(event, measurements, metadata, config) do
    operation = config.operation
    phase = List.last(event)

    if policy_resource?(metadata.resource) do
      handle_operation_phase(operation, phase, measurements, metadata)
    end
  end

  defp handle_query_event(event, measurements, metadata, config) do
    operation = config.operation
    phase = List.last(event)

    if policy_resource?(metadata.resource || metadata.query.resource) do
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
    emit_domain_event(operation, :start, measurements, enriched)
  end

  defp handle_operation_stop(operation, measurements, metadata) do
    InstrumentationHelpers.handle_stop_with_post_process(
      metadata,
      measurements,
      operation,
      &add_policy_metrics/3,
      fn -> enrich_metadata(metadata, operation) end,
      &emit_domain_event/4,
      fn _op, meas, enriched, meta ->
        # Always track security-sensitive policy changes
        if security_sensitive?(meta) do
          emit_security_audit_event(operation, meas, enriched)
        end
      end
    )
  end

  defp handle_operation_exception(operation, measurements, metadata) do
    enriched =
      metadata
      |> enrich_metadata(operation)
      |> add_exception_metadata(metadata)

    emit_domain_event(operation, :exception, measurements, enriched)

    # Critical: Policy failures may affect access control
    if critical_policy_operation?(metadata) do
      emit_access_control_alert(operation, measurements, enriched)
    end
  end

  defp add_exception_metadata(enriched, %{kind: kind, reason: reason}) do
    enriched
    |> Map.put(:error_kind, kind)
    |> Map.put(:error_reason, inspect(reason))
    |> Map.put(:security_incident, true)
  end

  defp add_exception_metadata(enriched, _), do: enriched

  defp policy_resource?(resource), do: resource in @policy_resources

  defp enrich_metadata(metadata, operation) do
    resource = metadata.resource || (metadata[:query] && metadata.query.resource) || nil
    record = get_record(metadata)

    %{
      resource: resource,
      resource_type: resource && resource_type(resource),
      tenant_id: get_tenant_id(metadata),
      actor_id: get_actor_id(metadata),
      operation: operation,
      critical_operation: operation in @critical_operations,
      security_sensitive: resource in @security_sensitive_resources,
      role_name: get_role_name(record),
      permission_name: get_permission_name(record),
      security_event: true,
      access_control_event: true
    }
    |> Map.merge(metadata)
  end

  defp resource_type(resource) do
    resource |> Module.split() |> List.last() |> Macro.underscore() |> String.to_atom()
  end

  defp add_policy_metrics(enriched, :create, %{name: name}) when is_binary(name) do
    Map.put(enriched, :created_entity_name, name)
  end

  defp add_policy_metrics(enriched, _, _), do: enriched

  defp get_role_name(%{role_name: name}) when is_binary(name), do: name
  defp get_role_name(%{name: name}) when is_binary(name), do: name
  defp get_role_name(_), do: nil

  defp get_permission_name(%{permission_name: name}) when is_binary(name), do: name
  defp get_permission_name(%{name: name}) when is_binary(name), do: name
  defp get_permission_name(_), do: nil

  defp security_sensitive?(%{resource: resource}) do
    resource in @security_sensitive_resources
  end

  defp security_sensitive?(_), do: false

  defp critical_policy_operation?(%{changeset: %{action_name: action}}) do
    action in @critical_operations
  end

  defp critical_policy_operation?(_), do: false

  defp get_record(%{changeset: %{data: data}}), do: data
  defp get_record(%{record: record}), do: record
  defp get_record(_), do: nil

  defp get_tenant_id(%{tenant: %{id: id}}), do: id
  defp get_tenant_id(%{__context: %{tenant: %{id: id}}}), do: id
  defp get_tenant_id(_), do: nil

  defp get_actor_id(%{actor: %{id: id}}), do: id
  defp get_actor_id(%{__context: %{actor: %{id: id}}}), do: id
  defp get_actor_id(_), do: nil

  defp emit_domain_event(category, phase, measurements, metadata) do
    event = [:indrajaal, :policy, category, phase]

    enriched_measurements =
      measurements
      |> Map.put(:timestamp, System.monotonic_time())

    :telemetry.execute(event, enriched_measurements, metadata)

    if phase == :exception do
      Logger.error("Policy domain error", metadata: metadata)
    end
  end

  defp emit_security_audit_event(operation, measurements, metadata) do
    event = [:indrajaal, :policy, :security_audit, operation]
    :telemetry.execute(event, measurements, metadata)
  end

  defp emit_access_control_alert(operation, measurements, metadata) do
    event = [:indrajaal, :policy, :access_control_alert, operation]
    :telemetry.execute(event, measurements, Map.put(metadata, :access_control_risk, true))
    Logger.warning("Critical policy operation failed", metadata: metadata)
  end
end
