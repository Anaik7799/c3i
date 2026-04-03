defmodule Indrajaal.Observability.Domains.ShiftsInstrumentation do
  @moduledoc """
  Domain-specific instrumentation for the Shifts domain.

  Provides comprehensive telemetry and tracing for shift management events,
  workforce scheduling operations, and STAMP safety monitoring.

  ## Telemetry Events Handled
  * `[:indrajaal, :shifts, :create, :start | :stop | :exception]`
  * `[:indrajaal, :shifts, :update, :start | :stop | :exception]`
  * `[:indrajaal, :shifts, :read, :start | :stop | :exception]`
  * `[:indrajaal, :shifts, :delete, :start | :stop | :exception]`

  ## Metrics Emitted
  * `[:indrajaal, :shifts, :operation, :duration]` - Operation timing
  * `[:indrajaal, :shifts, :operation, :count]` - Operation count

  ## STAMP Compliance
  * **SC-OBS-065**: Observability for all domain operations
  * **SC-OBS-066**: Audit trail for shift management changes
  """

  use Indrajaal.Observability.InstrumentationBase, domain: :shifts

  @shift_resources [
    Indrajaal.Shifts.Shift
  ]

  @safety_critical_operations [:create, :update, :delete]

  @doc """
  Sets up telemetry handlers for the Shifts domain.
  """
  def setup do
    attach_lifecycle_handlers()
    :ok
  end

  def handle_event(event, measurements, metadata) do
    :telemetry.execute(
      [:indrajaal, :observability, :shifts, :event],
      measurements,
      Map.merge(metadata, %{original_event: event})
    )

    :ok
  end

  def get_metrics do
    {:ok, %{status: :active, domain: :shifts}}
  end

  def record_metric(name, value) do
    :telemetry.execute(
      [:indrajaal, :observability, :shifts, :metric],
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
       domain: :shifts,
       shift_resources: @shift_resources,
       safety_critical_operations: @safety_critical_operations
     ]}
  end

  def shutdown do
    :ok
  end

  defp attach_lifecycle_handlers do
    # Create operation handlers
    :telemetry.attach_many(
      "shifts-instrumentation-create",
      [
        [:indrajaal, :shifts, :create, :start],
        [:indrajaal, :shifts, :create, :stop],
        [:indrajaal, :shifts, :create, :exception]
      ],
      &handle_operation_event/4,
      %{operation: :create}
    )

    # Update operation handlers
    :telemetry.attach_many(
      "shifts-instrumentation-update",
      [
        [:indrajaal, :shifts, :update, :start],
        [:indrajaal, :shifts, :update, :stop],
        [:indrajaal, :shifts, :update, :exception]
      ],
      &handle_operation_event/4,
      %{operation: :update}
    )

    # Read operation handlers
    :telemetry.attach_many(
      "shifts-instrumentation-read",
      [
        [:indrajaal, :shifts, :read, :start],
        [:indrajaal, :shifts, :read, :stop],
        [:indrajaal, :shifts, :read, :exception]
      ],
      &handle_operation_event/4,
      %{operation: :read}
    )

    # Delete operation handlers
    :telemetry.attach_many(
      "shifts-instrumentation-delete",
      [
        [:indrajaal, :shifts, :delete, :start],
        [:indrajaal, :shifts, :delete, :stop],
        [:indrajaal, :shifts, :delete, :exception]
      ],
      &handle_operation_event/4,
      %{operation: :delete}
    )
  end

  # Handle operation start events
  def handle_operation_event(
        [:indrajaal, :shifts, operation, :start],
        measurements,
        metadata,
        _config
      ) do
    Logger.debug("Shifts #{operation} started",
      operation: operation,
      domain: :shifts,
      system_time: measurements[:system_time],
      metadata: sanitize_metadata(metadata)
    )

    # Emit telemetry for operation start
    :telemetry.execute(
      [:indrajaal, :shifts, :operation, :count],
      %{count: 1},
      %{operation: operation, phase: :start}
    )
  end

  # Handle operation stop events (successful completion)
  def handle_operation_event(
        [:indrajaal, :shifts, operation, :stop],
        measurements,
        metadata,
        _config
      ) do
    duration_ms = Map.get(measurements, :duration, 0) / 1_000_000

    Logger.info("Shifts #{operation} completed",
      operation: operation,
      domain: :shifts,
      duration_ms: duration_ms,
      success: true,
      metadata: sanitize_metadata(metadata)
    )

    # Emit duration metric
    :telemetry.execute(
      [:indrajaal, :shifts, :operation, :duration],
      %{value: duration_ms},
      %{operation: operation, success: true}
    )

    # Safety-critical operation audit
    if operation in @safety_critical_operations do
      log_safety_critical_operation(operation, metadata, :success)
    end
  end

  # Handle operation exception events
  def handle_operation_event(
        [:indrajaal, :shifts, operation, :exception],
        measurements,
        metadata,
        _config
      ) do
    duration_ms = Map.get(measurements, :duration, 0) / 1_000_000
    error = Map.get(metadata, :error, :unknown)

    Logger.error("Shifts #{operation} failed",
      operation: operation,
      domain: :shifts,
      duration_ms: duration_ms,
      error: inspect(error),
      metadata: sanitize_metadata(metadata)
    )

    # Emit failure metric
    :telemetry.execute(
      [:indrajaal, :shifts, :operation, :duration],
      %{value: duration_ms},
      %{operation: operation, success: false, error: error_type(error)}
    )

    # Safety-critical operation failure audit
    if operation in @safety_critical_operations do
      log_safety_critical_operation(operation, metadata, :failure)
    end
  end

  # Fallback for any unmatched events
  def handle_operation_event(event, _measurements, _metadata, _config) do
    Logger.debug("Unhandled shifts telemetry event: #{inspect(event)}")
  end

  # Sanitize metadata to prevent sensitive data leakage
  defp sanitize_metadata(metadata) do
    metadata
    |> Map.drop([:password, :secret, :token, :api_key])
    |> Map.take([:id, :tenant_id, :name, :status, :type])
  end

  # Extract error type for metrics
  defp error_type(%{__struct__: struct}), do: struct |> Module.split() |> List.last()
  defp error_type(error) when is_atom(error), do: error
  defp error_type(_), do: :unknown

  # Log safety-critical operations for STAMP compliance
  defp log_safety_critical_operation(operation, metadata, result) do
    Logger.info("STAMP Audit: Shifts safety-critical operation",
      stamp_category: "SC-OBS-066",
      operation: operation,
      result: result,
      tenant_id: Map.get(metadata, :tenant_id),
      shift_id: Map.get(metadata, :id),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    )
  end

  @doc """
  Returns the list of resources instrumented by this module.
  """
  def instrumented_resources, do: @shift_resources
end
