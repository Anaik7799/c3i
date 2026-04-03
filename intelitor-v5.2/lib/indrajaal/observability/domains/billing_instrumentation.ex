defmodule Indrajaal.Observability.Domains.BillingInstrumentation do
  @moduledoc """
  Domain-specific instrumentation for the Billing domain.

  Provides comprehensive telemetry and tracing for billing lifecycle events,
  payment processing, and STAMP safety monitoring.
  """

  require Logger
  use Indrajaal.Observability.InstrumentationBase, domain: :billing

  alias Indrajaal.Observability.Domains.InstrumentationHelpers

  @billing_resources [
    Indrajaal.Billing.Payment,
    Indrajaal.Billing.Plan,
    Indrajaal.Billing.UsageRecord,
    Indrajaal.Billing.Subscription,
    Indrajaal.Billing.Invoice
  ]

  @critical_operations [:process_payment, :refund, :cancel_subscription]
  @security_sensitive_fields [:card_number, :cvv, :bank_account]

  @doc """
  Sets up telemetry handlers for the Billing domain.
  """
  def setup do
    attach_lifecycle_handlers()
    :ok
  end

  def handle_event(event, measurements, metadata) do
    :telemetry.execute(
      [:indrajaal, :observability, :billing, :event],
      measurements,
      Map.merge(metadata, %{original_event: event})
    )

    :ok
  end

  def get_metrics do
    {:ok, %{status: :active, domain: :billing}}
  end

  def record_metric(name, value) do
    :telemetry.execute(
      [:indrajaal, :observability, :billing, :metric],
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
       domain: :billing,
       billing_resources: @billing_resources,
       critical_operations: @critical_operations,
       security_sensitive_fields: @security_sensitive_fields
     ]}
  end

  def shutdown do
    :ok
  end

  defp attach_lifecycle_handlers do
    :telemetry.attach_many(
      "billing-instrumentation-create",
      [
        [:ash, :changeset, :create, :start],
        [:ash, :changeset, :create, :stop],
        [:ash, :changeset, :create, :exception]
      ],
      &handle_changeset_event/4,
      %{operation: :create}
    )

    :telemetry.attach_many(
      "billing-instrumentation-update",
      [
        [:ash, :changeset, :update, :start],
        [:ash, :changeset, :update, :stop],
        [:ash, :changeset, :update, :exception]
      ],
      &handle_changeset_event/4,
      %{operation: :update}
    )

    :telemetry.attach_many(
      "billing-instrumentation-read",
      [
        [:ash, :query, :read, :start],
        [:ash, :query, :read, :stop],
        [:ash, :query, :read, :exception]
      ],
      &handle_query_event/4,
      %{operation: :read}
    )

    :telemetry.attach_many(
      "billing-instrumentation-destroy",
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

    if billing_resource?(metadata.resource) do
      handle_operation_phase(operation, phase, measurements, metadata)
    end
  end

  defp handle_query_event(event, measurements, metadata, config) do
    operation = config.operation
    phase = List.last(event)

    if billing_resource?(metadata.resource || metadata.query.resource) do
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
    InstrumentationHelpers.handle_stop_with_measurements(
      metadata,
      measurements,
      operation,
      &add_billing_metrics/3,
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

  defp add_exception_metadata(enriched, %{kind: kind, reason: reason}) do
    enriched
    |> Map.put(:error_kind, kind)
    |> Map.put(:error_reason, inspect(reason))
  end

  defp add_exception_metadata(enriched, _), do: enriched

  defp billing_resource?(resource), do: resource in @billing_resources

  defp enrich_metadata(metadata, operation) do
    resource = metadata.resource || (metadata[:query] && metadata.query.resource) || nil

    %{
      resource: resource,
      resource_type: resource && resource_type(resource),
      tenant_id: get_tenant_id(metadata),
      actor_id: get_actor_id(metadata),
      operation: operation,
      pci_sensitive: pci_sensitive?(operation, metadata),
      critical_operation: operation in @critical_operations,
      security_event: true
    }
    |> Map.merge(metadata)
  end

  defp resource_type(resource) do
    resource |> Module.split() |> List.last() |> Macro.underscore() |> String.to_atom()
  end

  defp add_billing_metrics(enriched, :create, %{amount: amount}) when is_number(amount) do
    Map.put(enriched, :transaction_amount, amount)
  end

  defp add_billing_metrics(enriched, _, _), do: enriched

  defp pci_sensitive?(_operation, %{changeset: changeset}) do
    changed_fields = Map.keys(changeset.changes || %{})
    Enum.any?(@security_sensitive_fields, &(&1 in changed_fields))
  end

  defp pci_sensitive?(_, _), do: false

  defp get_tenant_id(%{tenant: %{id: id}}), do: id
  defp get_tenant_id(%{__context: %{tenant: %{id: id}}}), do: id
  defp get_tenant_id(_), do: nil

  defp get_actor_id(%{actor: %{id: id}}), do: id
  defp get_actor_id(%{__context: %{actor: %{id: id}}}), do: id
  defp get_actor_id(_), do: nil

  defp emit_domain_event(category, phase, measurements, metadata) do
    event = [:indrajaal, :billing, category, phase]

    enriched_measurements =
      measurements
      |> Map.put(:timestamp, System.monotonic_time())

    :telemetry.execute(event, enriched_measurements, metadata)

    if phase == :exception do
      Logger.error("Billing domain error", metadata: metadata)
    end
  end
end
