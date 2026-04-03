defmodule Indrajaal.Tracing.ResourceHelpers do
  require Logger

  @moduledoc """
  Helper macros and functions to add comprehensive tracing to Ash resources.

  Provides easy - to - use macros that can be included in existing resources to add
  OpenTelemetry tracing with minimal code changes following the CLAUDE - ASH - LOGGING - TRACING
    rules.
  """

  alias Indrajaal.Shared.TracingUtilities

  @doc """
  Adds comprehensive tracing to an Ash resource action.

  ## Usage in resource

      use Indrajaal.Tracing.ResourceHelpers

      actions do
        create :register_user do
          change trace_action("user.register", &extract__user_context / 2)
        end
      end
  """
  defmacro __using__(_opts) do
    quote do
      import Indrajaal.Tracing.ResourceHelpers
      require OpenTelemetry.Tracer
      require Logger
    end
  end

  @doc """
  Creates a change that traces the action execution with custom __context
    extraction.
  """
  @spec trace_action(any(), any()) :: any()
  def trace_action(
        _span_name,
        context_extractor \\ &default_context_extractor/2
      ) do
    fn changeset, context ->
      resource = changeset.resource
      action = changeset.action.name
      actor = context[:actor]

      # Extract custom context
      custom_context = context_extractor.(changeset, context)

      Indrajaal.Tracing.trace_ash_operation(
        resource,
        action,
        actor,
        custom_context,
        fn ->
          # Log action start
          Logger.info("Ash action started",
            resource: Indrajaal.Tracing.extract_resource_name(resource),
            action: action,
            actor_id: Indrajaal.Tracing.extract_actor_id(actor),
            tenant_id: Indrajaal.Tracing.extract_tenant_id(actor)
          )

          changeset
        end
      )
    end
  end

  @doc """
  Creates a preparation that traces query execution.
  """
  @spec trace_query(any()) :: any()
  def trace_query(span_name_prefix \\ "query") do
    fn query, context ->
      resource = query.resource
      action = query.action.name
      actor = context[:actor]

      _span_name =
        "#{span_name_prefix}.#{Indrajaal.Tracing.extract_resource_name(resource)}.#{action}"

      filter_count = length(query.filter || [])
      sort_count = length(query.sort || [])

      query_context = %{
        "query.filter_count" => filter_count,
        "query.sort_count" => sort_count,
        "query.limit" => query.limit,
        "query.offset" => query.offset
      }

      Indrajaal.Tracing.trace_ash_operation(
        resource,
        action,
        actor,
        query_context,
        fn ->
          Logger.debug("Ash query prepared",
            resource: Indrajaal.Tracing.extract_resource_name(resource),
            action: action,
            filter_count: filter_count,
            sort_count: sort_count
          )

          query
        end
      )
    end
  end

  @doc """
  Creates an after_action hook that traces the completion and emits telemetry.
  """
  @spec trace_completion(any()) :: any()
  def trace_completion(telemetry_event \\ nil) do
    fn changeset, result, context ->
      resource = changeset.resource
      action = changeset.action.name

      # Emit specific telemetry event if provided
      if telemetry_event do
        emit_domain_telemetry(telemetry_event, result, context)
      end

      # Log successful completion
      Logger.info("Ash action completed",
        resource: Indrajaal.Tracing.extract_resource_name(resource),
        action: action,
        result_id: TracingUtilities.extract_result_id(result),
        success: true
      )

      {:ok, result}
    end
  end

  @doc """
  Creates a change that adds comprehensive audit logging with tracing.
  """
  @spec trace_and_audit(any()) :: any()
  def trace_and_audit(audit_action \\ :create) do
    fn changeset, context ->
      # Create audit context using shared utilities
      audit_context = TracingUtilities.build_audit_context(changeset, context)

      # Use structured logging
      Indrajaal.Logging.log_audit_event(
        changeset.action.name,
        audit_context.resource,
        audit_context
      )

      # Trace the audit logging
      Indrajaal.Tracing.trace_security_operation(
        "audit.#{audit_action}",
        audit_context,
        fn ->
          changeset
        end
      )
    end
  end

  @doc """
  Creates a change that logs security - critical operations.
  """
  @spec trace_security_critical(any(), any()) :: any()
  def trace_security_critical(operation_name, severity \\ :high) do
    fn changeset, context ->
      # Build security context using shared utilities
      security_context =
        TracingUtilities.build_security_context(changeset, context, operation_name, severity)

      # Use structured security logging
      Indrajaal.Logging.log_security_event(operation_name, severity, security_context)

      changeset
    end
  end

  @doc """
  Creates a change that logs authentication events.
  """
  @spec trace_auth_event(any(), any()) :: any()
  def trace_auth_event(event_type, expected_result \\ :success) do
    fn changeset, context ->
      # Build auth context using shared utilities
      auth_context = TracingUtilities.build_auth_context(changeset, context, event_type)

      # Use structured auth logging
      Indrajaal.Logging.log_auth_event(event_type, expected_result, auth_context)

      changeset
    end
  end

  @doc """
  Creates a change for business - critical operations with enhanced telemetry.
  """
  @spec trace_business_critical(any(), any()) :: any()
  def trace_business_critical(operation_name, importance \\ :high) do
    fn changeset, context ->
      business_context =
        TracingUtilities.build_security_context(changeset, context, operation_name, importance)

      Indrajaal.Tracing.trace_business_operation(
        operation_name,
        business_context,
        fn ->
          # Emit business telemetry
          TracingUtilities.emit_operation_telemetry(
            :business,
            :critical_operation,
            %{count: 1, importance_level: TracingUtilities.importance_to_number(importance)},
            business_context
          )

          changeset
        end
      )
    end
  end

  @doc """
  Creates a change that traces device - specific operations.
  """
  @spec trace_device_operation(any()) :: any()
  def trace_device_operation(operation_name) do
    fn changeset, __context ->
      TracingUtilities.trace_device_operation_with_telemetry(
        changeset,
        operation_name,
        &Indrajaal.Tracing.trace_device_operation/4
      )
    end
  end

  @doc """
  Creates a change that traces alarm - specific operations.
  """
  @spec trace_alarm_operation(any()) :: any()
  def trace_alarm_operation(operation_name) do
    fn changeset, __context ->
      TracingUtilities.trace_alarm_operation_with_telemetry(
        changeset,
        operation_name,
        &Indrajaal.Tracing.trace_alarm_operation/4
      )
    end
  end

  @doc """
  Creates a change that traces video - specific operations.
  """
  @spec trace_video_operation(any()) :: any()
  def trace_video_operation(operation_name) do
    fn changeset, __context ->
      TracingUtilities.trace_video_operation_with_telemetry(
        changeset,
        operation_name,
        &Indrajaal.Tracing.trace_video_operation/4
      )
    end
  end

  # Private helper functions

  @spec default_context_extractor(term(), term()) :: term()
  defp default_context_extractor(changeset, _context) do
    %{
      "resource.id" => TracingUtilities.extract_resource_id(changeset),
      "changes.count" => map_size(changeset.changes),
      "validation.errors" => length(changeset.errors)
    }
  end

  defp emit_domain_telemetry(event_name, result, context) do
    :telemetry.execute(
      [:indrajaal, :domain, event_name],
      %{count: 1},
      %{
        result_id: TracingUtilities.extract_result_id(result),
        context: context
      }
    )
  end

  # Note: Helper functions moved to TracingUtilities shared module
  # Use TracingUtilities.extract_resource_id / 1, TracingUtilities.extract_result

  # Note: Helper functions moved to TracingUtilities shared module
  # Use TracingUtilities.extract_device_id / 1, TracingUtilities.extract_alarm_id
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
