defmodule Indrajaal.Observability.Logging do
  @moduledoc """
  Enhanced logging module with complete SigNoz integration and dual - backend optimization.

  This module provides comprehensive structured logging for the Indrajaal Security
  Monitoring System with:
  - Trace correlation for distributed tracing
  - Structured metadata for all 19 domains
  - Dual - backend optimization (console + JSON)
  - STAMP safety constraints tracking
  - TDG methodology compliance logging
  - GDE goal tracking with measurements
  - Tenant isolation and security __context
  - Performance metrics in log entries

  ## Usage

      # Log domain event with trace correlation
      Indrajaal.Observability.Logging.log_domain_event(
        :alarms,
        :alarm_triggered,
        %{alarm_id: "ALM - 123", severity: :critical},
        :error"

      # Log with performance metrics
      Indrajaal.Observability.Logging.log_with_metrics(
        :info,
        "Operation completed",
        %{duration_ms: 125, operation: "data_processing"}
  """

  require Logger
  require OpenTelemetry.Tracer
  # Note: DualLogging alias removed as it was unused

  # Domain modules for enhanced __context
  @domain_modules %{
    access_control: Indrajaal.AccessControl,
    accounts: Indrajaal.Accounts,
    alarms: Indrajaal.Alarms,
    analytics: Indrajaal.Analytics,
    asset_management: Indrajaal.AssetManagement,
    billing: Indrajaal.Billing,
    communication: Indrajaal.Communication,
    compliance: Indrajaal.Compliance,
    core: Indrajaal.Core,
    devices: Indrajaal.Devices,
    dispatch: Indrajaal.Dispatch,
    guard_tour: Indrajaal.GuardTour,
    integrations: Indrajaal.Integrations,
    maintenance: Indrajaal.Maintenance,
    policy: Indrajaal.Policy,
    risk_management: Indrajaal.RiskManagement,
    sites: Indrajaal.Sites,
    video: Indrajaal.Video,
    visitor_management: Indrajaal.VisitorManagement
  }

  @doc """
  Logs a domain - specific event with full trace correlation and dual - backend support.
  """
  @spec log_domain_event(term(), term(), map(), term()) :: term()
  def log_domain_event(domain, event, metadata \\ %{}, level \\ :info) do
    unless Map.has_key?(@domain_modules, domain) do
      raise ArgumentError,
            "Unknown domain: #{domain}. Valid domains: #{Map.keys(@domain_modules)}"
    end

    # Get current trace __context
    trace_context = get_trace_context()

    # Enhance metadata with trace and domain __context
    enhanced_metadata =
      metadata
      |> Map.merge(trace_context)
      |> Map.merge(%{
        domain: domain,
        event: event,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        correlation_id: metadata[:correlation_id] || generate_correlation_id(domain, event)
      })
      |> ensure_tenant_isolation()

    # Format message for readability
    message = format_domain_message(domain, event, metadata)

    # Log to both backends via dual logging
    Logger.log(level, message, enhanced_metadata)

    # Add trace event for SigNoz
    add_trace_event(domain, event, enhanced_metadata)

    # Emit telemetry for metrics
    emit_log_telemetry(domain, event, level, enhanced_metadata)
  end

  @doc """
  Logs a message with performance metrics embedded.
  """
  @spec log_with_metrics(term(), term(), term()) :: term()
  def log_with_metrics(message, metadata \\ %{}, level \\ :info) do
    metrics = extract_metrics(metadata)
    trace_context = get_trace_context()

    enhanced_metadata =
      metadata
      |> Map.merge(trace_context)
      |> Map.merge(%{
        metrics: metrics,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      })

    # Log with metrics
    Logger.log(level, "#{message} | Metrics: #{format_metrics(metrics)}", enhanced_metadata)

    # Record metrics to OpenTelemetry
    record_metrics_to_otel(metrics, metadata)
  end

  @doc """
  Logs a STAMP safety constraint event with proper severity.
  """
  @spec log_stamp_event(term(), term(), map(), term()) :: term()
  def log_stamp_event(constraint, status, context \\ %{}, level \\ nil) do
    level = level || stamp_status_to_level(status)

    metadata =
      %{
        stamp_constraint: constraint,
        stamp_status: status,
        control_structure: context[:control_structure],
        unsafe_control_action: context[:unsafe_control_action],
        safety_requirements: context[:safety_requirements],
        mitigation: context[:mitigation]
      }
      |> Map.merge(get_trace_context())
      |> ensure_tenant_isolation()

    message = "STAMP Safety Constraint #{constraint}: #{status}"

    # Add visual indicators for critical statuses
    formatted_message =
      case status do
        :violated -> "🚨 ALERT: #{message} 🚨"
        :at_risk -> "⚠️ WARNING: #{message}"
        _ -> "✅ OK: #{message}"
      end

    Logger.log(level, formatted_message, metadata)

    # Track safety metrics
    track_safety_metrics(constraint, status, context)
  end

  @doc """
  Logs a TDG methodology compliance event.
  """
  @spec log_tdg_event(term(), term(), term(), map()) :: term()
  def log_tdg_event(phase, component, compliance_status, details \\ %{}) do
    level = tdg_compliance_to_level(compliance_status)

    metadata =
      %{
        tdg_phase: phase,
        tdg_component: component,
        tdg_compliance: compliance_status,
        test_coverage: details[:test_coverage],
        tests_written_first: details[:tests_written_first] || false,
        ai_agent: details[:ai_agent],
        validation_result: details[:validation_result]
      }
      |> Map.merge(get_trace_context())

    message = "TDG #{phase} - #{component}: #{compliance_status}"

    Logger.log(level, message, metadata)

    # Track TDG compliance metrics
    track_tdg_metrics(phase, component, compliance_status, details)
  end

  @doc """
  Logs a GDE goal tracking event with achievement metrics.
  """
  @spec log_gde_event(term(), term(), term(), map()) :: term()
  def log_gde_event(domain, goal_id, status, metrics \\ %{}) do
    level = gde_status_to_level(status)

    metadata =
      %{
        gde_domain: domain,
        gde_goal_id: goal_id,
        gde_status: status,
        completion_percentage: metrics[:completion_percentage],
        target_value: metrics[:target_value],
        actual_value: metrics[:actual_value],
        time_to_achievement: metrics[:time_to_achievement]
      }
      |> Map.merge(get_trace_context())
      |> ensure_tenant_isolation()

    message =
      "GDE Goal #{domain}:#{goal_id} - #{status} (#{metrics[:completion_percentage] || 0}%)"

    Logger.log(level, message, metadata)

    # Track goal metrics
    track_gde_metrics(domain, goal_id, status, metrics)
  end

  @doc """
  Logs a security event with enhanced context and automatic alerting.
  """
  @spec log_security_event(term(), term(), term()) :: term()
  def log_security_event(event_type, severity, context \\ %{}) do
    level = security_severity_to_level(severity)

    metadata =
      %{
        security_event: event_type,
        security_severity: severity,
        actor_id: context[:actor_id],
        resource: context[:resource],
        action: context[:action],
        ip_address: context[:ip_address],
        user_agent: context[:user_agent],
        session_id: context[:session_id],
        threat_indicators: context[:threat_indicators]
      }
      |> Map.merge(get_trace_context())
      |> ensure_tenant_isolation()

    message = "Security Event [#{severity}]: #{event_type}"

    # Add visual severity indicators
    formatted_message =
      case severity do
        :critical -> "🚨 CRITICAL: #{message} 🚨"
        :high -> "⚠️ HIGH: #{message}"
        :medium -> "⚠️ WARNING: #{message}"
        _ -> message
      end

    Logger.log(level, formatted_message, metadata)

    # Trigger security alerts for high severity
    if severity in [:critical, :high] do
      trigger_security_alert(event_type, severity, context)
    end
  end

  @doc """
  Logs an error with full stack trace and recovery suggestions.
  """
  @spec log_error(term(), term(), term()) :: term()
  def log_error(error, stacktrace, context \\ %{}) do
    metadata =
      %{
        error_type: error.__struct__,
        error_message: Exception.message(error),
        error_context: context,
        stacktrace: format_stacktrace(stacktrace),
        recovery_suggestions: get_recovery_suggestions(error)
      }
      |> Map.merge(get_trace_context())
      |> ensure_tenant_isolation()

    message = "Error occurred: #{Exception.message(error)}"

    Logger.error(message, metadata)

    # Record error in OpenTelemetry
    record_error_to_otel(error, stacktrace, context)
  end

  @doc """
  Creates a logging context that will be applied to all logs within the function.
  """
  @spec with_context(any(), any()) :: any()
  def with_context(additional_metadata, fun) do
    current_metadata = Logger.metadata()

    try do
      # Add context to logger metadata
      Logger.metadata(Keyword.merge(current_metadata, Keyword.new(additional_metadata)))

      # Add context to OpenTelemetry span
      add_span_attributes(additional_metadata)

      fun.()
    after
      # Restore original metadata
      Logger.metadata(current_metadata)
    end
  end

  @doc """
  Logs a batch of related events efficiently.
  """
  @spec log_batch(any(), any()) :: any()
  def log_batch(events, base_metadata \\ %{}) do
    batch_id = generate_batch_id()
    trace_context = get_trace_context()

    Enum.each(events, fn {level, message, event_metadata} ->
      metadata =
        base_metadata
        |> Map.merge(event_metadata)
        |> Map.merge(trace_context)
        |> Map.put(:batch_id, batch_id)

      Logger.log(level, message, metadata)
    end)

    # Log batch summary
    Logger.info("Batch logged: #{length(events)} events",
      batch_id: batch_id,
      event_count: length(events)
    )
  end

  # Private functions

  defp get_trace_context do
    []
    |> Indrajaal.Observability.LoggerTraceContext.enrich_metadata()
    |> Map.new()
  end

  # Note: format_trace_id, format_span_id, and format_trace_flags functions
  # migrated to and accessed via get_trace_context()

  @spec ensure_tenant_isolation(term()) :: term()
  defp ensure_tenant_isolation(metadata) do
    # SC2: Ensure tenant isolation
    tenant_id = Process.get(:tenant_id, "default")
    Map.put(metadata, :tenant_id, tenant_id)
  end

  @spec generate_correlation_id(term(), term()) :: term()
  defp generate_correlation_id(domain, event) do
    "#{domain}_#{event}_#{System.unique_integer([:positive])}"
  end

  defp generate_batch_id do
    "batch-#{DateTime.utc_now() |> DateTime.to_unix(:microsecond)}-#{:rand.uniform(999_999)}"
  end

  defp format_domain_message(domain, event, metadata) do
    base = "[#{String.upcase(to_string(domain))}] #{event}"

    # Add key context if available
    context_parts =
      []
      |> maybe_add_context(metadata[:user_id], "user")
      |> maybe_add_context(metadata[:resource_id], "resource")
      |> maybe_add_context(metadata[:alarm_id], "alarm")
      |> maybe_add_context(metadata[:device_id], "device")

    if length(context_parts) > 0 do
      "#{base} (#{Enum.join(context_parts, ", ")})"
    else
      base
    end
  end

  defp maybe_add_context(acc, nil, _prefix), do: acc
  defp maybe_add_context(acc, value, prefix), do: ["#{prefix}:#{value}" | acc]

  @spec extract_metrics(term()) :: term()
  defp extract_metrics(metadata) do
    metadata
    |> Enum.filter(fn {k, _v} ->
      String.ends_with?(to_string(k), "ms") or
        String.ends_with?(to_string(k), "count") or
        String.ends_with?(to_string(k), "bytes") or
        String.ends_with?(to_string(k), "percentage") or
        k in [:duration, :latency, :throughput, :error_rate]
    end)
    |> Map.new()
  end

  @spec format_metrics(term()) :: term()
  defp format_metrics(metrics) when metrics == %{}, do: "none"

  defp format_metrics(metrics) do
    metrics
    |> Enum.map_join(", ", fn {k, v} -> "#{k}=#{v}" end)
  end

  defp add_trace_event(domain, event, metadata) do
    case :otel_tracer.current_span_ctx() do
      :undefined ->
        :ok

      _ ->
        if Code.ensure_loaded?(OpenTelemetry) do
          OpenTelemetry.Tracer.add_event("log_event", %{
            "log.domain" => domain,
            "log.event" => event,
            "log.severity" => metadata[:level] || "info"
          })
        else
          :ok
        end
    end
  end

  defp emit_log_telemetry(domain, event, level, metadata) do
    :telemetry.execute(
      [:indrajaal, :logging, :event],
      %{count: 1},
      Map.merge(metadata, %{
        domain: domain,
        event: event,
        level: level
      })
    )
  end

  @spec add_span_attributes(term()) :: term()
  defp add_span_attributes(metadata) do
    # Add metadata as span attributes to OpenTelemetry
    if Code.ensure_loaded?(OpenTelemetry) do
      OpenTelemetry.Tracer.set_attributes(Map.to_list(metadata))
    else
      :ok
    end
  end

  @spec record_metrics_to_otel(term(), term()) :: term()
  defp record_metrics_to_otel(metrics, context) do
    alias Indrajaal.Observability.MetricsWrapper

    Enum.each(metrics, fn {metric_name, value} ->
      if is_number(value) do
        MetricsWrapper.record(
          :"intelitor.logged_metric.#{metric_name}",
          value,
          %{
            source: "logging",
            tenant_id: context[:tenant_id] || "default"
          }
        )
      end
    end)
  end

  defp record_error_to_otel(error, stacktrace, context) do
    case :otel_tracer.current_span_ctx() do
      :undefined ->
        :ok

      _ ->
        if Code.ensure_loaded?(OpenTelemetry) do
          OpenTelemetry.Tracer.record_exception(error, stacktrace)
          OpenTelemetry.Tracer.set_status(:error, Exception.message(error))

          OpenTelemetry.Tracer.set_attributes(
            format_otel_attributes(%{
              "error.context" => inspect(context)
            })
          )
        end
    end
  end

  defp format_otel_attributes(attrs) do
    Enum.map(attrs, fn {k, v} -> {String.to_atom(k), v} end)
  end

  @spec stamp_status_to_level(term()) :: term()
  defp stamp_status_to_level(:violated), do: :error
  defp stamp_status_to_level(:at_risk), do: :warning
  defp stamp_status_to_level(:satisfied), do: :info
  defp stamp_status_to_level(_), do: :info

  @spec tdg_compliance_to_level(term()) :: term()
  defp tdg_compliance_to_level(:non_compliant), do: :error
  defp tdg_compliance_to_level(:partial), do: :warning
  defp tdg_compliance_to_level(:compliant), do: :info
  defp tdg_compliance_to_level(_), do: :info

  @spec gde_status_to_level(term()) :: term()
  defp gde_status_to_level(:failed), do: :error
  defp gde_status_to_level(:at_risk), do: :warning
  defp gde_status_to_level(:in_progress), do: :info
  defp gde_status_to_level(:achieved), do: :info
  defp gde_status_to_level(_), do: :info

  @spec security_severity_to_level(term()) :: term()
  defp security_severity_to_level(:critical), do: :error
  defp security_severity_to_level(:high), do: :error
  defp security_severity_to_level(:medium), do: :warning
  defp security_severity_to_level(:low), do: :info
  defp security_severity_to_level(_), do: :info

  @spec format_stacktrace(term()) :: term()
  defp format_stacktrace(stacktrace) do
    stacktrace
    |> Exception.format_stacktrace()
    |> String.split("\\n")
    |> Enum.take(10)
    |> Enum.join("\\n")
  end

  @spec get_recovery_suggestions(term()) :: term()
  defp get_recovery_suggestions(error) do
    case error.__struct__ do
      Indrajaal.Errors.Unauthorized -> "Check authentication and permissions"
      Indrajaal.Errors.NotFound -> "Verify resource exists and ID is correct"
      Indrajaal.Errors.Conflict -> "Resource may have been modified, retry with latest version"
      Indrajaal.Errors.Timeout -> "Operation timed out, consider retry with backoff"
      Indrajaal.Errors.ServiceUnavailable -> "Service temporarily unavailable, retry later"
      _ -> "Check error details and system logs"
    end
  end

  defp track_safety_metrics(constraint, status, context) do
    :telemetry.execute(
      [:indrajaal, :stamp, :constraint],
      %{count: 1, severity: constraint_severity(status)},
      Map.merge(context, %{constraint: constraint, status: status})
    )
  end

  defp track_tdg_metrics(phase, component, compliance_status, details) do
    :telemetry.execute(
      [:indrajaal, :tdg, :compliance],
      %{
        count: 1,
        coverage: details[:test_coverage] || 0,
        compliance_score: compliance_score(compliance_status)
      },
      Map.merge(details, %{phase: phase, component: component, status: compliance_status})
    )
  end

  defp track_gde_metrics(domain, goal_id, status, metrics) do
    :telemetry.execute(
      [:indrajaal, :gde, :goal_tracking],
      %{
        count: 1,
        completion: metrics[:completion_percentage] || 0,
        achievement_score: achievement_score(status)
      },
      Map.merge(metrics, %{domain: domain, goal_id: goal_id, status: status})
    )
  end

  @spec constraint_severity(term()) :: term()
  defp constraint_severity(status) do
    case status do
      :violated -> :error
      :at_risk -> :warn
      :monitored -> :info
      _ -> :debug
    end
  end

  @spec compliance_score(term()) :: term()
  defp compliance_score(status) do
    case status do
      :compliant -> 100
      :partial -> 75
      :non_compliant -> 0
      _ -> 50
    end
  end

  @spec achievement_score(term()) :: term()
  defp achievement_score(status) do
    case status do
      :completed -> 100
      :in_progress -> 50
      :blocked -> 25
      :pending -> 0
      _ -> 0
    end
  end

  defp trigger_security_alert(event_type, severity, context) do
    :telemetry.execute(
      [:indrajaal, :security, :alert],
      %{severity: severity_to_number(severity)},
      Map.merge(context, %{event_type: event_type, severity: severity})
    )
  end

  @spec severity_to_number(term()) :: term()
  defp severity_to_number(:critical), do: 4
  defp severity_to_number(:high), do: 3
  defp severity_to_number(:medium), do: 2
  defp severity_to_number(:low), do: 1
  defp severity_to_number(_), do: 1

  # CLAUDE_AGENT_CONTEXT: Missing Logger wrapper functions added
  # Date: 2025-09-03
  # Issue: Undefined function warnings for Indrajaal.Observability.Logging.info/2 and .error/2
  # Pattern: EP045_UNDEFINED_FUNCTION
  # Fix: Added wrapper functions that delegate to Elixir's Logger module
  #
  # These functions provide a consistent interface for logging throughout the application.
  # They wrap the standard Logger functions to allow for future enhancements like:
  # - Additional metadata injection
  # - Log filtering or transformation
  # - Multi-backend routing
  #
  # Usage:
  #   Indrajaal.Observability.Logging.info("User logged in", user_id: 123)
  #   Indrajaal.Observability.Logging.error("Failed to process", error: reason)

  def warning(message, metadata \\ %{}) do
    Logger.warning(message, metadata)
  end

  def log(level, message, metadata \\ %{}) do
    Logger.log(level, message, metadata)
  end

  def info(message, metadata \\ %{}) do
    Logger.info(message, metadata)
  end

  def error(message, metadata \\ %{}) do
    Logger.error(message, metadata)
  end
end
