defmodule Indrajaal.Observability.Domains.ComplianceInstrumentation do
  @moduledoc """
  Domain-specific instrumentation for the Compliance domain.

  Provides comprehensive telemetry and tracing for compliance lifecycle events,
  audit trails, and STAMP safety monitoring for regulatory requirements.
  """

  require Logger
  use Indrajaal.Observability.InstrumentationBase, domain: :compliance

  alias Indrajaal.Observability.Domains.InstrumentationHelpers

  @compliance_resources [
    Indrajaal.Compliance.Requirement,
    Indrajaal.Compliance.Framework,
    Indrajaal.Compliance.Policy,
    Indrajaal.Compliance.Assessment,
    Indrajaal.Compliance.ForensicAuditTrail,
    Indrajaal.Compliance.RegulatoryReportingAutomation,
    Indrajaal.Compliance.Report,
    Indrajaal.Compliance.AuditReport,
    Indrajaal.Compliance.Document
  ]

  @critical_frameworks ["ISO_27001", "SOX_404", "GDPR", "PCI_DSS", "HIPAA"]
  @audit_required_operations [:create, :update, :destroy]

  @doc """
  Sets up telemetry handlers for the Compliance domain.
  """
  def setup do
    attach_lifecycle_handlers()
    :ok
  end

  def handle_event(event, measurements, metadata) do
    :telemetry.execute(
      [:indrajaal, :observability, :compliance, :event],
      measurements,
      Map.merge(metadata, %{original_event: event})
    )

    :ok
  end

  def get_metrics do
    {:ok, %{status: :active, domain: :compliance}}
  end

  def record_metric(name, value) do
    :telemetry.execute(
      [:indrajaal, :observability, :compliance, :metric],
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
       domain: :compliance,
       compliance_resources: @compliance_resources,
       critical_frameworks: @critical_frameworks,
       audit_required_operations: @audit_required_operations
     ]}
  end

  def shutdown do
    :ok
  end

  defp attach_lifecycle_handlers do
    :telemetry.attach_many(
      "compliance-instrumentation-create",
      [
        [:ash, :changeset, :create, :start],
        [:ash, :changeset, :create, :stop],
        [:ash, :changeset, :create, :exception]
      ],
      &handle_changeset_event/4,
      %{operation: :create}
    )

    :telemetry.attach_many(
      "compliance-instrumentation-update",
      [
        [:ash, :changeset, :update, :start],
        [:ash, :changeset, :update, :stop],
        [:ash, :changeset, :update, :exception]
      ],
      &handle_changeset_event/4,
      %{operation: :update}
    )

    :telemetry.attach_many(
      "compliance-instrumentation-read",
      [
        [:ash, :query, :read, :start],
        [:ash, :query, :read, :stop],
        [:ash, :query, :read, :exception]
      ],
      &handle_query_event/4,
      %{operation: :read}
    )

    :telemetry.attach_many(
      "compliance-instrumentation-destroy",
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

    if compliance_resource?(metadata.resource) do
      handle_operation_phase(operation, phase, measurements, metadata)
    end
  end

  defp handle_query_event(event, measurements, metadata, config) do
    operation = config.operation
    phase = List.last(event)

    if compliance_resource?(metadata.resource || metadata.query.resource) do
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
      &add_compliance_metrics/3,
      fn -> enrich_metadata(metadata, operation) end,
      &emit_domain_event/4,
      fn op, meas, enriched, _meta ->
        # Always ensure audit trail for compliance operations
        if op in @audit_required_operations do
          emit_audit_event(op, meas, enriched)
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

    # Critical: Log all compliance exceptions for audit
    emit_compliance_violation_event(operation, measurements, enriched)
  end

  defp add_exception_metadata(enriched, %{kind: kind, reason: reason}) do
    enriched
    |> Map.put(:error_kind, kind)
    |> Map.put(:error_reason, inspect(reason))
    |> Map.put(:compliance_violation, true)
  end

  defp add_exception_metadata(enriched, _), do: enriched

  defp compliance_resource?(resource), do: resource in @compliance_resources

  defp enrich_metadata(metadata, operation) do
    resource = metadata.resource || (metadata[:query] && metadata.query.resource) || nil
    record = get_record(metadata)

    %{
      resource: resource,
      resource_type: resource && resource_type(resource),
      tenant_id: get_tenant_id(metadata),
      actor_id: get_actor_id(metadata),
      operation: operation,
      audit_required: operation in @audit_required_operations,
      regulatory_event: true,
      framework: get_framework(record),
      critical_framework: critical_framework?(record)
    }
    |> Map.merge(metadata)
  end

  defp resource_type(resource) do
    resource |> Module.split() |> List.last() |> Macro.underscore() |> String.to_atom()
  end

  defp add_compliance_metrics(enriched, :create, %{framework: framework})
       when is_binary(framework) do
    Map.put(enriched, :compliance_framework, framework)
  end

  defp add_compliance_metrics(enriched, _, _), do: enriched

  defp get_framework(%{framework: framework}) when is_binary(framework), do: framework
  defp get_framework(%{framework_id: id}) when not is_nil(id), do: "framework_#{id}"
  defp get_framework(_), do: nil

  defp critical_framework?(%{framework: framework}) when is_binary(framework) do
    framework in @critical_frameworks
  end

  defp critical_framework?(_), do: false

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
    event = [:indrajaal, :compliance, category, phase]

    enriched_measurements =
      measurements
      |> Map.put(:timestamp, System.monotonic_time())

    :telemetry.execute(event, enriched_measurements, metadata)

    if phase == :exception do
      Logger.error("Compliance domain error", metadata: metadata)
    end
  end

  defp emit_audit_event(operation, measurements, metadata) do
    event = [:indrajaal, :compliance, :audit, operation]
    :telemetry.execute(event, measurements, metadata)
  end

  defp emit_compliance_violation_event(operation, measurements, metadata) do
    event = [:indrajaal, :compliance, :violation, operation]
    :telemetry.execute(event, measurements, Map.put(metadata, :violation_severity, :critical))
    Logger.warning("Compliance violation detected", metadata: metadata)
  end
end
