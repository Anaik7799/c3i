defmodule Indrajaal.Logging do
  @moduledoc """
  Comprehensive structured logging for the Indrajaal Security Monitoring System.

  Provides domain - specific logging functions following the CLAUDE - ASH - LOGGING - TRACING
    rules
  with proper OpenTelemetry integration and business context.
  """

  require Logger
  require OpenTelemetry.Tracer

  @doc """
  Log security - related __events with enhanced __context and severity classification.
  """
  @spec log_security_event(term(), term(), term()) :: term()
  def log_security_event(event_type, severity, context \\ %{}) do
    Logger.log(
      security_level_to_log_level(severity),
      "Security __event occurred",
      event_type: event_type,
      severity: severity,
      actor_id: context[:actor_id],
      tenant_id: context[:tenant_id],
      resource: context[:resource],
      action: context[:action],
      ip_address: context[:ip_address],
      __user_agent: context[:__user_agent],
      session_id: context[:session_id],
      trace_id: get_trace_id(),
      timestamp: DateTime.utc_now()
    )

    # Emit security telemetry
    :telemetry.execute(
      [:indrajaal, :security, :event],
      %{count: 1, severity_level: severity_to_number(severity)},
      Map.merge(context, %{event_type: event_type, severity: severity})
    )
  end

  @doc """
  Log authentication __events with detailed context.
  """
  @spec log_auth_event(term(), term(), term()) :: term()
  def log_auth_event(event_type, result, context \\ %{}) do
    log_level =
      case result do
        :success -> :info
        :failure -> :warn
        :error -> :error
      end

    Logger.log(
      log_level,
      "Authentication __event",
      event_type: event_type,
      result: result,
      user_id: context[:user_id],
      email: context[:email],
      ip_address: context[:ip_address],
      __user_agent: context[:__user_agent],
      mfa_method: context[:mfa_method],
      failure_reason: context[:failure_reason],
      session_id: context[:session_id],
      tenant_id: context[:tenant_id],
      trace_id: get_trace_id(),
      timestamp: DateTime.utc_now()
    )

    # Emit auth telemetry
    :telemetry.execute(
      [:indrajaal, :auth, event_type],
      %{count: 1, success: result == :success},
      context
    )
  end

  @doc """
  Log device operations with device - specific context.
  """
  @spec log_device_event(term(), term(), term()) :: term()
  def log_device_event(event_type, _severity, context \\ %{}) do
    Logger.info("Device __event",
      device_id: context[:device_id],
      event_type: event_type,
      device_type: context[:device_type],
      device_name: context[:device_name],
      location: context[:location],
      status: context[:status],
      firmware_version: context[:firmware_version],
      last_heartbeat: context[:last_heartbeat],
      tenant_id: context[:tenant_id],
      trace_id: get_trace_id(),
      timestamp: DateTime.utc_now()
    )

    # Emit device telemetry
    :telemetry.execute(
      [:indrajaal, :device, event_type],
      %{count: 1},
      Map.merge(context, %{device_id: context[:device_id], event_type: event_type})
    )
  end

  @doc """
  Log alarm __events with priority and severity tracking.
  """
  def log_alarm_event(event_type, _severity, context \\ %{}) do
    severity = context[:severity] || :medium

    Logger.log(
      alarm_severity_to_log_level(severity),
      "Alarm __event",
      alarm_id: context[:alarm_id],
      event_type: event_type,
      severity: severity,
      priority: context[:priority],
      incident_type: context[:incident_type],
      device_id: context[:device_id],
      site_id: context[:site_id],
      zone_id: context[:zone_id],
      state: context[:state],
      response_time: context[:response_time],
      actor_id: context[:actor_id],
      tenant_id: context[:tenant_id],
      trace_id: get_trace_id(),
      timestamp: DateTime.utc_now()
    )

    # Emit alarm telemetry
    :telemetry.execute(
      [:indrajaal, :alarm, event_type],
      %{
        count: 1,
        severity_level: severity_to_number(severity),
        priority: context[:priority] || 5
      },
      Map.merge(context, %{alarm_id: context[:alarm_id], event_type: event_type})
    )
  end

  @doc """
  Log video system __events with video - specific metadata.
  """
  @spec log_video_event(term(), term(), term()) :: term()
  def log_video_event(event_type, _severity, context \\ %{}) do
    Logger.info("Video __event",
      camera_id: context[:camera_id],
      event_type: event_type,
      stream_type: context[:stream_type],
      resolution: context[:resolution],
      codec: context[:codec],
      recording_id: context[:recording_id],
      duration: context[:duration],
      file_size: context[:file_size],
      analytics_result: context[:analytics_result],
      tenant_id: context[:tenant_id],
      trace_id: get_trace_id(),
      timestamp: DateTime.utc_now()
    )

    # Emit video telemetry
    :telemetry.execute(
      [:indrajaal, :video, event_type],
      %{count: 1, duration: context[:duration] || 0},
      Map.merge(context, %{camera_id: context[:camera_id], event_type: event_type})
    )
  end

  @doc """
  Log access control __events with detailed access context.
  """
  @spec log_access_event(term(), term(), term(), map()) :: term()
  def log_access_event(event_type, _severity, result, context \\ %{}) do
    log_level =
      case result do
        :granted -> :info
        :denied -> :warn
        :violation -> :error
      end

    Logger.log(
      log_level,
      "Access control __event",
      user_id: context[:user_id],
      event_type: event_type,
      result: result,
      location_id: context[:location_id],
      reader_id: context[:reader_id],
      access_level: context[:access_level],
      credential_type: context[:credential_type],
      denial_reason: context[:denial_reason],
      time_schedule: context[:time_schedule],
      anti_passback: context[:anti_passback],
      tenant_id: context[:tenant_id],
      trace_id: get_trace_id(),
      timestamp: DateTime.utc_now()
    )

    # Emit access control telemetry
    :telemetry.execute(
      [:indrajaal, :access, event_type],
      %{count: 1, success: result == :granted},
      Map.merge(context, %{user_id: context[:user_id], event_type: event_type, result: result})
    )
  end

  @doc """
  Log business operations with business impact classification.
  """
  def log_business_event(_event_type, _severity, context \\ %{}) do
    importance = context[:importance] || :medium

    log_level =
      case importance do
        :critical -> :warn
        :high -> :info
        :medium -> :info
        :low -> :debug
      end

    Logger.log(
      log_level,
      "Business operation",
      operation: context[:operation],
      importance: context[:importance],
      resource: context[:resource],
      resource_id: context[:resource_id],
      actor_id: context[:actor_id],
      tenant_id: context[:tenant_id],
      duration_ms: context[:duration_ms],
      impact: context[:impact],
      trace_id: get_trace_id(),
      timestamp: DateTime.utc_now()
    )

    # Emit business telemetry
    :telemetry.execute(
      [:indrajaal, :business, :operation],
      %{
        count: 1,
        importance_level: importance_to_number(importance),
        duration: context[:duration_ms] || 0
      },
      Map.merge(context, %{operation: context[:operation], importance: context[:importance]})
    )
  end

  @doc """
  Log compliance __events with regulatory framework context.
  """
  def log_compliance_event(event_type, _severity, context \\ %{}) do
    severity = context[:severity] || :medium

    Logger.log(
      compliance_severity_to_log_level(severity),
      "Compliance __event",
      event_type: event_type,
      framework: context[:framework],
      severity: severity,
      _requirement_id: context[:_requirement_id],
      assessment_id: context[:assessment_id],
      violation_type: context[:violation_type],
      remediation_required: context[:remediation_required],
      auditor_id: context[:auditor_id],
      tenant_id: context[:tenant_id],
      trace_id: get_trace_id(),
      timestamp: DateTime.utc_now()
    )

    # Emit compliance telemetry
    :telemetry.execute(
      [:indrajaal, :compliance, event_type],
      %{count: 1, severity_level: severity_to_number(severity)},
      Map.merge(context, %{event_type: event_type, framework: context[:framework]})
    )
  end

  @doc """
  Log system performance and health __events.
  """
  def log_system_event(event_type, _severity, context \\ %{}) do
    severity = context[:severity] || :info

    Logger.log(
      system_severity_to_log_level(severity),
      "System __event",
      component: context[:component],
      event_type: event_type,
      severity: severity,
      metric_value: context[:metric_value],
      threshold: context[:threshold],
      node: context[:node] || Node.self(),
      memory_usage: context[:memory_usage],
      cpu_usage: context[:cpu_usage],
      disk_usage: context[:disk_usage],
      trace_id: get_trace_id(),
      timestamp: DateTime.utc_now()
    )

    # Emit system telemetry
    :telemetry.execute(
      [:indrajaal, :system, event_type],
      %{
        count: 1,
        severity_level: severity_to_number(severity),
        metric_value: context[:metric_value] || 0
      },
      Map.merge(context, %{component: context[:component], event_type: event_type})
    )
  end

  @doc """
  Log audit trail __events for compliance and security.
  """
  def log_audit_event(_event_type, _severity, context \\ %{}) do
    Logger.info("Audit __event",
      action: context[:action],
      resource: context[:resource],
      resource_id: context[:resource_id],
      actor_id: context[:actor_id],
      actor_type: context[:actor_type],
      tenant_id: context[:tenant_id],
      changes: context[:changes],
      old_values: context[:old_values],
      new_values: context[:new_values],
      ip_address: context[:ip_address],
      user_agent: context[:user_agent],
      session_id: context[:session_id],
      correlation_id: context[:correlation_id],
      trace_id: get_trace_id(),
      timestamp: DateTime.utc_now()
    )

    # Store in audit log table if configured
    if context[:persist_audit] do
      store_audit_record(context[:action], context[:resource], context)
    end

    # Emit audit telemetry
    :telemetry.execute(
      [:indrajaal, :audit, :logged],
      %{count: 1},
      Map.merge(context, %{action: context[:action], resource: context[:resource]})
    )
  end

  # Private helper functions

  @spec get_trace_id() :: any()
  def get_trace_id() do
    case :otel_tracer.current_span_ctx() do
      :undefined ->
        nil

      span_ctx ->
        trace_result =
          if Code.ensure_loaded?(OpenTelemetry) do
            OpenTelemetry.Span.trace_id(span_ctx)
          else
            :ok
          end

        to_string(trace_result)
    end
  rescue
    _ -> nil
  end

  @spec security_level_to_log_level(term()) :: term()
  defp security_level_to_log_level(:critical), do: :error
  defp security_level_to_log_level(:high), do: :warn
  defp security_level_to_log_level(:medium), do: :info
  @spec security_level_to_log_level(term()) :: term()
  defp security_level_to_log_level(:low), do: :debug

  defp alarm_severity_to_log_level(:critical), do: :error
  @spec alarm_severity_to_log_level(term()) :: term()
  defp alarm_severity_to_log_level(:high), do: :warn
  defp alarm_severity_to_log_level(:medium), do: :info
  defp alarm_severity_to_log_level(:low), do: :debug

  @spec compliance_severity_to_log_level(term()) :: term()
  defp compliance_severity_to_log_level(:critical), do: :error
  # SC-SIL6-001: Use :warning (OTP 28 compatible) instead of deprecated :warn
  defp compliance_severity_to_log_level(:high), do: :warning
  defp compliance_severity_to_log_level(:medium), do: :info
  @spec compliance_severity_to_log_level(term()) :: term()
  defp compliance_severity_to_log_level(:low), do: :debug

  defp system_severity_to_log_level(:error), do: :error
  @spec system_severity_to_log_level(term()) :: term()
  # SC-SIL6-001: Map both :warn and :warning to :warning for OTP 28 compatibility
  defp system_severity_to_log_level(:warn), do: :warning
  defp system_severity_to_log_level(:warning), do: :warning
  defp system_severity_to_log_level(:info), do: :info
  defp system_severity_to_log_level(:debug), do: :debug

  @spec severity_to_number(term()) :: term()
  defp severity_to_number(:critical), do: 4
  defp severity_to_number(:high), do: 3
  defp severity_to_number(:medium), do: 2
  @spec severity_to_number(term()) :: term()
  defp severity_to_number(:low), do: 1

  defp importance_to_number(:critical), do: 4
  @spec importance_to_number(term()) :: term()
  defp importance_to_number(:high), do: 3
  defp importance_to_number(:medium), do: 2
  defp importance_to_number(:low), do: 1

  defp store_audit_record(action, resource, context) do
    # This would integrate with the existing AuditLog resource
    # For now, we'll just log that we would store it
    Logger.debug("Audit record would be stored",
      action: action,
      resource: resource,
      context: context
    )
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
