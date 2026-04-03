defmodule Indrajaal.Changes.TraceOperation do
  @moduledoc """
  Change module for tracing Ash resource operations.
  """

  use Ash.Resource.Change
  require Logger

  alias Indrajaal.Shared.TracingUtilities

  @spec init(any()) :: any()
  def init(opts) do
    case opts do
      [operation_type: operation_type, operation_name: operation_name, importance: importance] ->
        {:ok,
         %{operation_type: operation_type, operation_name: operation_name, importance: importance}}

      [operation_type: operation_type, operation_name: operation_name] ->
        {:ok,
         %{operation_type: operation_type, operation_name: operation_name, importance: :medium}}

      [operation_name: operation_name, importance: importance] ->
        {:ok,
         %{operation_type: :business, operation_name: operation_name, importance: importance}}

      [operation_name: operation_name] ->
        {:ok, %{operation_type: :business, operation_name: operation_name, importance: :medium}}

      operation_name when is_binary(operation_name) ->
        {:ok, %{operation_type: :business, operation_name: operation_name, importance: :medium}}

      _ ->
        {:error, "Must provide operation_name and optionally operation_type and importance"}
    end
  end

  @spec change(term(), term(), term()) :: term()
  def change(changeset, _opts, config) do
    operation_type = Map.get(config, :operation_type, :business)
    operation_name = Map.get(config, :operation_name)
    importance = Map.get(config, :importance, :medium)

    case operation_type do
      :alarm ->
        trace_alarm_operation(changeset, operation_name)

      :device ->
        trace_device_operation(changeset, operation_name)

      :video ->
        trace_video_operation(changeset, operation_name)

      :business ->
        trace_business_operation(changeset, operation_name)

      :business_critical ->
        trace_business_critical_operation(changeset, operation_name, importance)

      :security_critical ->
        trace_security_critical_operation(changeset, operation_name, importance)

      :auth_event ->
        trace_auth_event_operation(changeset, operation_name, importance)

      :audit ->
        trace_audit_operation(changeset, operation_name)

      _ ->
        changeset
    end
  end

  @spec trace_alarm_operation(term(), term()) :: term()
  defp trace_alarm_operation(changeset, operation_name) do
    TracingUtilities.trace_alarm_operation_with_telemetry(
      changeset,
      operation_name,
      &Indrajaal.Tracing.trace_alarm_operation/4
    )
  end

  @spec trace_device_operation(term(), term()) :: term()
  defp trace_device_operation(changeset, operation_name) do
    TracingUtilities.trace_device_operation_with_telemetry(
      changeset,
      operation_name,
      &Indrajaal.Tracing.trace_device_operation/4
    )
  end

  @spec trace_video_operation(term(), term()) :: term()
  defp trace_video_operation(changeset, operation_name) do
    TracingUtilities.trace_video_operation_with_telemetry(
      changeset,
      operation_name,
      &Indrajaal.Tracing.trace_video_operation/4
    )
  end

  @spec trace_business_operation(term(), term()) :: term()
  defp trace_business_operation(changeset, operation_name) do
    context = TracingUtilities.build_business_context(changeset, operation_name)

    Indrajaal.Tracing.trace_business_operation(operation_name, context, fn ->
      changeset
    end)
  end

  defp trace_business_critical_operation(changeset, operation_name, importance) do
    TracingUtilities.trace_business_critical_with_telemetry(
      changeset,
      operation_name,
      importance,
      &Indrajaal.Tracing.trace_business_operation/3
    )
  end

  defp trace_security_critical_operation(changeset, operation_name, importance) do
    security_context =
      TracingUtilities.build_business_context(changeset, operation_name, importance)

    Indrajaal.Tracing.trace_security_operation(
      "critical.#{operation_name}",
      security_context,
      fn ->
        # Emit security - critical telemetry
        TracingUtilities.emit_operation_telemetry(
          :security,
          :critical,
          %{count: 1, importance_level: TracingUtilities.importance_to_number(importance)},
          security_context
        )

        changeset
      end
    )
  end

  defp trace_auth_event_operation(changeset, operation_name, importance) do
    auth_context = TracingUtilities.build_business_context(changeset, operation_name, importance)

    Indrajaal.Tracing.trace_security_operation("auth.#{operation_name}", auth_context, fn ->
      # Emit auth telemetry
      TracingUtilities.emit_operation_telemetry(
        :auth,
        operation_name,
        %{count: 1, importance_level: TracingUtilities.importance_to_number(importance)},
        auth_context
      )

      changeset
    end)
  end

  @spec trace_audit_operation(term(), term()) :: term()
  defp trace_audit_operation(changeset, operation_name) do
    audit_context =
      TracingUtilities.build_business_context(
        changeset,
        operation_name
      )

    Indrajaal.Tracing.trace_business_operation("audit.#{operation_name}", audit_context, fn ->
      # Emit audit telemetry
      TracingUtilities.emit_operation_telemetry(
        :audit,
        operation_name,
        %{count: 1},
        audit_context
      )

      changeset
    end)
  end

  # Note: Helper functions moved to TracingUtilities shared module
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
