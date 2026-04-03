defmodule Indrajaal.Telemetry.Handlers do
  @moduledoc """
  Comprehensive Telemetry Event Handlers

  Handles all system telemetry __events including:
  - HTTP __request / response metrics
  - Database query performance
  - Authentication __events
  - Safety and security __events
  - Business logic metrics
  - System performance metrics
  """

  require Logger

  @telemetry_events [
    # Phoenix endpoint __events
    [:phoenix, :endpoint, :start],
    [:phoenix, :endpoint, :stop],
    [:phoenix, :router_dispatch, :start],
    [:phoenix, :router_dispatch, :stop],

    # Database __events
    [:indrajaal, :repo, :query],
    [:ecto, :repo, :query],

    # Authentication __events
    [:indrajaal, :auth, :login],
    [:indrajaal, :auth, :logout],
    [:indrajaal, :auth, :token_validation, :start],
    [:indrajaal, :auth, :token_validation, :success],
    [:indrajaal, :auth, :token_validation, :failure],
    [:indrajaal, :auth, :token_revoked],
    [:indrajaal, :auth, :refresh_token_generation, :start],
    [:indrajaal, :auth, :refresh_token_generation, :success],
    [:indrajaal, :auth, :refresh_token_use, :success],

    # Session __events
    [:indrajaal, :session, :created],
    [:indrajaal, :session, :validation, :start],
    [:indrajaal, :session, :validation, :success],
    [:indrajaal, :session, :validation, :failure],
    [:indrajaal, :session, :terminated],

    # Security __events
    [:indrajaal, :security, :rate_limit_check, :start],
    [:indrajaal, :security, :rate_limit_check, :allowed],
    [:indrajaal, :security, :rate_limit_check, :exceeded],
    [:indrajaal, :security, :token_family_breach],

    # Safety __events
    [:indrajaal, :safety, :violation],
    [:indrajaal, :safety, :constraint_checked],
    [:indrajaal, :safety, :monitor_alert],
    [:indrajaal, :safety, :intervention_triggered],

    # Business __events
    [:indrajaal, :alarm, :triggered],
    [:indrajaal, :alarm, :acknowledged],
    [:indrajaal, :alarm, :resolved],
    [:indrajaal, :device, :connected],
    [:indrajaal, :device, :disconnected],
    [:indrajaal, :user, :action],

    # System __events
    [:vm, :memory],
    [:vm, :total_run_queue_lengths],
    [:vm, :system_counts]
  ]

  @spec setup() :: any()
  def setup do
    Logger.info("Setting up telemetry __event handlers",
      __events_count: length(@telemetry_events)
    )

    # Attach main __event handler
    :telemetry.attach_many(
      "intelitor - telemetry - handler",
      @telemetry_events,
      &process_request/4,
      %{handler_id: "main"}
    )

    # Attach safety - specific handler for critical __events
    safety_events = [
      [:indrajaal, :safety, :violation],
      [:indrajaal, :safety, :monitor_alert],
      [:indrajaal, :security, :token_family_breach]
    ]

    :telemetry.attach_many(
      "intelitor - safety - handler",
      safety_events,
      &handle_safety_event/4,
      %{handler_id: "safety", priority: :critical}
    )

    # Setup periodic system metrics collection
    :telemetry.attach(
      "vm - metrics",
      [:vm, :memory],
      &handle_vm_metrics/4,
      %{handler_id: "vm"}
    )

    Logger.info("Telemetry handlers attached successfully")
    :ok
  end

  @doc """
  Main __event handler for all telemetry __events
  """
  @spec process_request(term(), term(), term(), term()) :: term()
  def process_request(event_name, measurements, metadata, config) do
    case event_name do
      # HTTP Events
      [:phoenix, :endpoint, :stop] ->
        handle_http_request(measurements, metadata)

      # Database Events
      [:indrajaal, :repo, :query] ->
        handle_database_query(measurements, metadata)

      [:ecto, :repo, :query] ->
        handle_ecto_query(measurements, metadata)

      # Authentication Events
      [:indrajaal, :auth, :login] ->
        handle_auth_login(measurements, metadata)

      [:indrajaal, :auth, :token_validation, :failure] ->
        handle_auth_failure(measurements, metadata)

      # Session Events
      [:indrajaal, :session, :validation, :failure] ->
        handle_session_failure(measurements, metadata)

      # Security Events
      [:indrajaal, :security, :rate_limit_check, :exceeded] ->
        handle_rate_limit_exceeded(measurements, metadata)

      # Business Events
      [:indrajaal, :alarm, :triggered] ->
        handle_alarm_triggered(measurements, metadata)

      # Default handler
      _ ->
        handle_generic_event(event_name, measurements, metadata, config)
    end
  rescue
    error ->
      Logger.error("Error in telemetry handler",
        __event: event_name,
        error: inspect(error),
        measurements: inspect(measurements),
        metadata: inspect(metadata)
      )
  end

  @doc """
  Safety - specific __event handler for critical __events
  """
  @spec handle_safety_event(term(), term(), term(), term()) :: term()
  def handle_safety_event(event_name, measurements, metadata, _config) do
    case event_name do
      [:indrajaal, :safety, :violation] ->
        handle_safety_violation(measurements, metadata)

      [:indrajaal, :safety, :monitor_alert] ->
        handle_safety_alert(measurements, metadata)

      [:indrajaal, :security, :token_family_breach] ->
        handle_security_breach(measurements, metadata)

      _ ->
        Logger.warning("Unhandled safety __event", __event: event_name)
    end

    # Always store critical safety __events
    Indrajaal.Telemetry.Storage.store_critical_event(event_name, measurements, metadata)
  rescue
    error ->
      Logger.error("Critical error in safety __event handler",
        __event: event_name,
        error: inspect(error)
      )

      # Send emergency alert
      Indrajaal.Telemetry.AlertManager.send_emergency_alert(
        "Telemetry safety handler failure",
        %{__event: event_name, error: inspect(error)}
      )
  end

  # Event Handler Implementations

  @spec handle_http_request(term(), term()) :: term()
  defp handle_http_request(measurements, metadata) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
    status = metadata.status
    path = metadata.__request_path || "unknown"
    method = metadata.method || "unknown"

    # Log slow __requests
    if duration_ms > 1000 do
      Logger.warning("Slow HTTP __request",
        duration_ms: duration_ms,
        status: status,
        path: path,
        method: method
      )
    end

    # Store metrics
    Indrajaal.Telemetry.Metrics.record_http_request(
      method,
      path,
      status,
      duration_ms
    )

    # Check for error patterns
    if status >= 500 do
      Indrajaal.Telemetry.AlertManager.handle_http_error(status, path, metadata)
    end
  end

  @spec handle_database_query(term(), term()) :: term()
  defp handle_database_query(measurements, metadata) do
    duration_ms = System.convert_time_unit(measurements.query_time, :native, :millisecond)
    query = metadata.query || "unknown"
    source = metadata.source || "unknown"

    # Log slow queries
    if duration_ms > 100 do
      Logger.warning("Slow database query",
        duration_ms: duration_ms,
        source: source,
        query_preview: String.slice(query, 0, 100)
      )
    end

    # Store metrics
    Indrajaal.Telemetry.Metrics.record_database_query(
      source,
      duration_ms
    )

    # Check for query issues
    if duration_ms > 5000 do
      Indrajaal.Telemetry.AlertManager.handle_slow_query(duration_ms, source, query)
    end
  end

  @spec handle_ecto_query(term(), term()) :: term()
  defp handle_ecto_query(measurements, metadata) do
    total_time = measurements.total_time
    query_time = measurements.query_time || 0
    queue_time = measurements.queue_time || 0
    decode_time = measurements.decode_time || 0

    total_ms = System.convert_time_unit(total_time, :native, :millisecond)

    # Store detailed Ecto metrics
    Indrajaal.Telemetry.Metrics.record_ecto_query(%{
      total_time_ms: total_ms,
      query_time_ms: System.convert_time_unit(query_time, :native, :millisecond),
      queue_time_ms: System.convert_time_unit(queue_time, :native, :millisecond),
      decode_time_ms: System.convert_time_unit(decode_time, :native, :millisecond),
      repo: metadata.repo,
      result: metadata.result
    })
  end

  @spec handle_auth_login(term(), term()) :: term()
  defp handle_auth_login(measurements, metadata) do
    user_id = metadata.user_id
    tenant_id = metadata.tenant_id
    success = metadata.success

    Logger.info("Authentication attempt",
      user_id: user_id,
      tenant_id: tenant_id,
      success: success,
      timestamp: measurements.login_time
    )

    Indrajaal.Telemetry.Metrics.record_auth_event(:login, success, tenant_id)

    if not success do
      Indrajaal.Telemetry.AlertManager.handle_auth_failure(user_id, tenant_id, metadata)
    end
  end

  @spec handle_auth_failure(term(), term()) :: term()
  defp handle_auth_failure(measurements, metadata) do
    reason = metadata.reason

    Logger.warning("Authentication validation failed",
      reason: reason,
      timestamp: measurements.failure_time
    )

    Indrajaal.Telemetry.Metrics.record_auth_failure(reason)

    Indrajaal.Telemetry.AlertManager.handle_auth_validation_failure(
      reason,
      metadata
    )
  end

  @spec handle_session_failure(term(), term()) :: term()
  defp handle_session_failure(measurements, metadata) do
    reason = metadata.reason
    session_id_hash = metadata.session_id_hash

    Logger.warning("Session validation failed",
      reason: reason,
      session_id_hash: session_id_hash,
      timestamp: measurements.failure_time
    )

    Indrajaal.Telemetry.Metrics.record_session_failure(reason)

    # Check for potential attacks
    if reason in [:fingerprint_mismatch, :ip_mismatch, :suspicious_ip_change] do
      Indrajaal.Telemetry.AlertManager.handle_potential_session_hijack(
        session_id_hash,
        metadata
      )
    end
  end

  @spec handle_rate_limit_exceeded(term(), term()) :: term()
  defp handle_rate_limit_exceeded(measurements, metadata) do
    user_id = metadata.user_id
    endpoint = metadata.endpoint
    role = metadata.role

    Logger.warning("Rate limit exceeded",
      user_id: user_id,
      endpoint: endpoint,
      role: role,
      count: measurements.count,
      limit: measurements.limit
    )

    Indrajaal.Telemetry.Metrics.record_rate_limit_violation(
      endpoint,
      role
    )

    Indrajaal.Telemetry.AlertManager.handle_rate_limit_violation(user_id, endpoint, measurements)
  end

  @spec handle_alarm_triggered(term(), term()) :: term()
  defp handle_alarm_triggered(measurements, metadata) do
    alarm_id = metadata.alarm_id
    alarm_type = metadata.alarm_type
    severity = metadata.severity

    Logger.info("Alarm triggered",
      alarm_id: alarm_id,
      alarm_type: alarm_type,
      severity: severity,
      trigger_time: measurements.trigger_time
    )

    Indrajaal.Telemetry.Metrics.record_alarm_event(:triggered, alarm_type, severity)

    if severity in [:critical, :high] do
      Indrajaal.Telemetry.AlertManager.handle_critical_alarm(alarm_id, alarm_type, metadata)
    end
  end

  @spec handle_safety_violation(term(), term()) :: term()
  defp handle_safety_violation(measurements, metadata) do
    violation_type = metadata.violation_type
    severity = metadata.severity

    Logger.error("SAFETY VIOLATION DETECTED",
      violation_type: violation_type,
      severity: severity,
      __context: metadata.context,
      timestamp: measurements.violation_time
    )

    # Immediate safety response
    case severity do
      :critical ->
        Indrajaal.Safety.EmergencyResponse.activate(violation_type, metadata)

        Indrajaal.Telemetry.AlertManager.send_emergency_alert(
          "Critical safety violation",
          metadata
        )

      :high ->
        Indrajaal.Telemetry.AlertManager.send_immediate_alert(
          "High severity safety violation",
          metadata
        )

      _ ->
        Indrajaal.Telemetry.AlertManager.send_standard_alert(
          "Safety violation",
          metadata
        )
    end

    # Record for analysis
    Indrajaal.Telemetry.Metrics.record_safety_violation(
      violation_type,
      severity
    )
  end

  @spec handle_safety_alert(term(), term()) :: term()
  defp handle_safety_alert(_measurements, metadata) do
    alert_type = metadata.alert_type
    constraint = metadata.constraint

    Logger.warning("Safety monitor alert",
      alert_type: alert_type,
      constraint: constraint,
      value: metadata.value,
      threshold: metadata.threshold
    )

    Indrajaal.Telemetry.AlertManager.handle_safety_alert(alert_type, constraint, metadata)
  end

  @spec handle_security_breach(term(), term()) :: term()
  defp handle_security_breach(measurements, metadata) do
    token_family = metadata.token_family
    user_id = metadata.user_id

    Logger.error("SECURITY BREACH: Token family compromise detected",
      token_family: token_family,
      user_id: user_id,
      breach_time: measurements.breach_time
    )

    # Immediate security response
    Indrajaal.Security.IncidentResponse.handle_token_family_breach(
      token_family,
      user_id
    )

    Indrajaal.Telemetry.AlertManager.send_emergency_alert(
      "Token family breach",
      metadata
    )
  end

  defp handle_generic_event(event_name, measurements, metadata, config) do
    # Store all __events for potential analysis
    Indrajaal.Telemetry.Storage.store_event(event_name, measurements, metadata)

    Logger.debug("Telemetry __event processed",
      __event: event_name,
      handler: config.handler_id
    )
  end

  @spec handle_vm_metrics(term(), term(), term(), term()) :: term()
  def handle_vm_metrics([:vm, :memory], measurements, _metadata, _config) do
    Indrajaal.Telemetry.Metrics.record_vm_metrics(measurements)

    # Check for memory issues
    total_memory = measurements.total
    # > 1GB
    if total_memory > 1_000_000_000 do
      Logger.warning("High memory usage", total_memory_bytes: total_memory)
    end
  end

  @doc """
  HTTP event handler for indrajaal HTTP request telemetry events.
  Handles :start, :stop, and :exception phases.
  """
  @spec handle_http_event(term(), term(), term(), term()) :: :ok
  def handle_http_event(event_name, measurements, metadata, _config) do
    case event_name do
      [_, :http, :request, :stop] ->
        duration_ms =
          case measurements do
            %{duration: d} -> System.convert_time_unit(d, :native, :millisecond)
            _ -> 0
          end

        Logger.debug("HTTP request completed",
          method: metadata[:method],
          path: metadata[:path],
          status: metadata[:status],
          duration_ms: duration_ms
        )

      [_, :http, :request, :exception] ->
        Logger.warning("HTTP request exception",
          method: metadata[:method],
          path: metadata[:path],
          exception: inspect(metadata[:exception])
        )

      _ ->
        Logger.debug("HTTP event", event: event_name)
    end

    :ok
  rescue
    _ -> :ok
  end

  @doc """
  Detach all handlers (for testing)
  """
  @spec detach_all() :: any()
  def detach_all do
    :telemetry.detach("intelitor - telemetry - handler")
    :telemetry.detach("intelitor - safety - handler")
    :telemetry.detach("vm - metrics")
    Logger.info("All telemetry handlers detached")
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
