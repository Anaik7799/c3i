defmodule Indrajaal.Observability.Domains.AssetManagementInstrumentation do
  @moduledoc """
  Domain-specific instrumentation for the Asset Management domain.

  Provides comprehensive telemetry and tracing for asset lifecycle events,
  transfers, maintenance, and STAMP safety monitoring.
  """

  require Logger
  use Indrajaal.Observability.InstrumentationBase, domain: :asset_management

  alias Indrajaal.Observability.Domains.InstrumentationHelpers

  @asset_resources [
    Indrajaal.AssetManagement.Asset,
    Indrajaal.AssetManagement.AssetCategory,
    Indrajaal.AssetManagement.AssetLocation,
    Indrajaal.AssetManagement.AssetTransfer,
    Indrajaal.AssetManagement.AssetMaintenance,
    Indrajaal.AssetManagement.AssetAudit,
    Indrajaal.AssetManagement.AssetAssignment,
    Indrajaal.AssetManagement.AssetWarranty,
    Indrajaal.AssetManagement.AssetDepreciation,
    Indrajaal.AssetManagement.AssetRetirement
  ]

  @critical_operations [:retire, :transfer, :assign]
  @audit_required_resources [Indrajaal.AssetManagement.AssetAudit]

  @doc """
  Sets up telemetry handlers for the Asset Management domain.
  """
  def setup do
    attach_lifecycle_handlers()
    :ok
  end

  def handle_event(event, measurements, metadata) do
    :telemetry.execute(
      [:indrajaal, :observability, :asset_management, :event],
      measurements,
      Map.merge(metadata, %{original_event: event})
    )

    :ok
  end

  def get_metrics do
    {:ok, %{status: :active, domain: :asset_management}}
  end

  def record_metric(name, value) do
    :telemetry.execute(
      [:indrajaal, :observability, :asset_management, :metric],
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
       domain: :asset_management,
       asset_resources: @asset_resources,
       critical_operations: @critical_operations,
       audit_required_resources: @audit_required_resources
     ]}
  end

  def shutdown do
    :ok
  end

  defp attach_lifecycle_handlers do
    :telemetry.attach_many(
      "asset-management-instrumentation-create",
      [
        [:ash, :changeset, :create, :start],
        [:ash, :changeset, :create, :stop],
        [:ash, :changeset, :create, :exception]
      ],
      &handle_changeset_event/4,
      %{operation: :create}
    )

    :telemetry.attach_many(
      "asset-management-instrumentation-update",
      [
        [:ash, :changeset, :update, :start],
        [:ash, :changeset, :update, :stop],
        [:ash, :changeset, :update, :exception]
      ],
      &handle_changeset_event/4,
      %{operation: :update}
    )

    :telemetry.attach_many(
      "asset-management-instrumentation-read",
      [
        [:ash, :query, :read, :start],
        [:ash, :query, :read, :stop],
        [:ash, :query, :read, :exception]
      ],
      &handle_query_event/4,
      %{operation: :read}
    )

    :telemetry.attach_many(
      "asset-management-instrumentation-destroy",
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

    if asset_resource?(metadata.resource) do
      handle_operation_phase(operation, phase, measurements, metadata)
    end
  end

  defp handle_query_event(event, measurements, metadata, config) do
    operation = config.operation
    phase = List.last(event)

    if asset_resource?(metadata.resource || metadata.query.resource) do
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
      &add_asset_metrics/3,
      fn -> enrich_metadata(metadata, operation) end,
      &emit_domain_event/4,
      fn op, meas, enriched, meta ->
        # Track audit events for critical resources
        if audit_required?(meta) do
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

    # Critical: Asset management failures may affect inventory integrity
    if critical_asset_operation?(metadata) do
      emit_integrity_alert(operation, measurements, enriched)
    end
  end

  defp add_exception_metadata(enriched, %{kind: kind, reason: reason}) do
    enriched
    |> Map.put(:error_kind, kind)
    |> Map.put(:error_reason, inspect(reason))
  end

  defp add_exception_metadata(enriched, _), do: enriched

  defp asset_resource?(resource), do: resource in @asset_resources

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
      audit_required: resource in @audit_required_resources,
      asset_status: get_asset_status(record),
      asset_id: get_asset_id(record),
      inventory_event: true
    }
    |> Map.merge(metadata)
  end

  defp resource_type(resource) do
    resource |> Module.split() |> List.last() |> Macro.underscore() |> String.to_atom()
  end

  defp add_asset_metrics(enriched, :create, %{value: value}) when is_number(value) do
    Map.put(enriched, :asset_value, value)
  end

  defp add_asset_metrics(enriched, :update, %{status: status}) when not is_nil(status) do
    Map.put(enriched, :new_status, status)
  end

  defp add_asset_metrics(enriched, _, _), do: enriched

  defp get_asset_status(%{status: status}) when is_binary(status), do: status
  defp get_asset_status(%{status: status}) when is_atom(status), do: Atom.to_string(status)
  defp get_asset_status(_), do: nil

  defp get_asset_id(%{id: id}), do: id
  defp get_asset_id(%{asset_id: id}), do: id
  defp get_asset_id(_), do: nil

  defp audit_required?(%{resource: resource}) do
    resource in @audit_required_resources
  end

  defp audit_required?(_), do: false

  defp critical_asset_operation?(%{changeset: %{action_name: action}}) do
    action in @critical_operations
  end

  defp critical_asset_operation?(_), do: false

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
    event = [:indrajaal, :asset_management, category, phase]

    enriched_measurements =
      measurements
      |> Map.put(:timestamp, System.monotonic_time())

    :telemetry.execute(event, enriched_measurements, metadata)

    if phase == :exception do
      Logger.error("Asset Management domain error", metadata: metadata)
    end
  end

  defp emit_audit_event(operation, measurements, metadata) do
    event = [:indrajaal, :asset_management, :audit, operation]
    :telemetry.execute(event, measurements, metadata)
  end

  defp emit_integrity_alert(operation, measurements, metadata) do
    event = [:indrajaal, :asset_management, :integrity_alert, operation]
    :telemetry.execute(event, measurements, Map.put(metadata, :integrity_risk, true))
    Logger.warning("Critical asset operation failed", metadata: metadata)
  end
end
