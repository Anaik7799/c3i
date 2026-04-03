defmodule Indrajaal.Observability.Domains.DispatchInstrumentation do
  @moduledoc """
  Domain-specific instrumentation for the Dispatch domain.

  Provides comprehensive telemetry and tracing for dispatch lifecycle events,
  officer assignments, vehicle tracking, and STAMP safety monitoring.
  """

  require Logger
  use Indrajaal.Observability.InstrumentationBase, domain: :dispatch

  alias Indrajaal.Observability.Domains.InstrumentationHelpers

  @dispatch_resources [
    Indrajaal.Dispatch.Vehicle,
    Indrajaal.Dispatch.Route,
    Indrajaal.Dispatch.Assignment,
    Indrajaal.Dispatch.Officer,
    Indrajaal.Dispatch.Team
  ]

  @critical_operations [:emergency_dispatch, :reassign, :cancel_dispatch]
  @time_sensitive_resources [Indrajaal.Dispatch.Assignment]

  @doc """
  Sets up telemetry handlers for the Dispatch domain.
  """
  def setup do
    attach_lifecycle_handlers()
    :ok
  end

  def handle_event(event, measurements, metadata) do
    :telemetry.execute(
      [:indrajaal, :observability, :dispatch, :event],
      measurements,
      Map.merge(metadata, %{original_event: event})
    )

    :ok
  end

  def get_metrics do
    {:ok, %{status: :active, domain: :dispatch}}
  end

  def record_metric(name, value) do
    :telemetry.execute(
      [:indrajaal, :observability, :dispatch, :metric],
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
       domain: :dispatch,
       dispatch_resources: @dispatch_resources,
       critical_operations: @critical_operations,
       time_sensitive_resources: @time_sensitive_resources
     ]}
  end

  def shutdown do
    :ok
  end

  defp attach_lifecycle_handlers do
    :telemetry.attach_many(
      "dispatch-instrumentation-create",
      [
        [:ash, :changeset, :create, :start],
        [:ash, :changeset, :create, :stop],
        [:ash, :changeset, :create, :exception]
      ],
      &handle_changeset_event/4,
      %{operation: :create}
    )

    :telemetry.attach_many(
      "dispatch-instrumentation-update",
      [
        [:ash, :changeset, :update, :start],
        [:ash, :changeset, :update, :stop],
        [:ash, :changeset, :update, :exception]
      ],
      &handle_changeset_event/4,
      %{operation: :update}
    )

    :telemetry.attach_many(
      "dispatch-instrumentation-read",
      [
        [:ash, :query, :read, :start],
        [:ash, :query, :read, :stop],
        [:ash, :query, :read, :exception]
      ],
      &handle_query_event/4,
      %{operation: :read}
    )

    :telemetry.attach_many(
      "dispatch-instrumentation-destroy",
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

    if dispatch_resource?(metadata.resource) do
      handle_operation_phase(operation, phase, measurements, metadata)
    end
  end

  defp handle_query_event(event, measurements, metadata, config) do
    operation = config.operation
    phase = List.last(event)

    if dispatch_resource?(metadata.resource || metadata.query.resource) do
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
      fn enriched, op, result -> add_dispatch_metrics(enriched, op, result, metadata) end,
      fn -> enrich_metadata(metadata, operation) end,
      &emit_domain_event/4,
      fn _op, meas, enriched, meta ->
        # Track response times for time-sensitive operations
        if time_sensitive?(meta) do
          emit_response_time_event(operation, meas, enriched)
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

    # Critical: Dispatch failures may affect safety
    if critical_dispatch?(metadata) do
      emit_safety_alert(operation, measurements, enriched)
    end
  end

  defp add_exception_metadata(enriched, %{kind: kind, reason: reason}) do
    enriched
    |> Map.put(:error_kind, kind)
    |> Map.put(:error_reason, inspect(reason))
  end

  defp add_exception_metadata(enriched, _), do: enriched

  defp dispatch_resource?(resource), do: resource in @dispatch_resources

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
      time_sensitive: resource in @time_sensitive_resources,
      dispatch_status: get_dispatch_status(record),
      security_event: true
    }
    |> Map.merge(metadata)
  end

  defp resource_type(resource) do
    resource |> Module.split() |> List.last() |> Macro.underscore() |> String.to_atom()
  end

  defp add_dispatch_metrics(enriched, :create, result, _metadata) do
    enriched
    |> maybe_add_assignment_metrics(result)
  end

  defp add_dispatch_metrics(enriched, _, _, _), do: enriched

  defp maybe_add_assignment_metrics(enriched, %{priority: priority}) when not is_nil(priority) do
    Map.put(enriched, :assignment_priority, priority)
  end

  defp maybe_add_assignment_metrics(enriched, _), do: enriched

  defp get_dispatch_status(%{status: status}) when is_binary(status), do: status
  defp get_dispatch_status(%{status: status}) when is_atom(status), do: Atom.to_string(status)
  defp get_dispatch_status(_), do: nil

  defp time_sensitive?(%{resource: resource}) do
    resource in @time_sensitive_resources
  end

  defp time_sensitive?(_), do: false

  defp critical_dispatch?(%{changeset: %{action_name: action}}) do
    action in @critical_operations
  end

  defp critical_dispatch?(_), do: false

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
    event = [:indrajaal, :dispatch, category, phase]

    enriched_measurements =
      measurements
      |> Map.put(:timestamp, System.monotonic_time())

    :telemetry.execute(event, enriched_measurements, metadata)

    if phase == :exception do
      Logger.error("Dispatch domain error", metadata: metadata)
    end
  end

  defp emit_response_time_event(operation, measurements, metadata) do
    event = [:indrajaal, :dispatch, :response_time, operation]

    enriched_measurements =
      measurements
      |> Map.put(:response_timestamp, System.monotonic_time())

    :telemetry.execute(event, enriched_measurements, metadata)
  end

  defp emit_safety_alert(operation, measurements, metadata) do
    event = [:indrajaal, :dispatch, :safety_alert, operation]
    :telemetry.execute(event, measurements, Map.put(metadata, :safety_critical, true))
    Logger.warning("Critical dispatch operation failed", metadata: metadata)
  end
end
