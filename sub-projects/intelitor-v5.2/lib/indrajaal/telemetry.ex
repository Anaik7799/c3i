defmodule Indrajaal.Telemetry do
  @moduledoc """
  Comprehensive telemetry __event handlers for the Indrajaal Security Monitoring
    System.

  This module provides centralized telemetry instrumentation following
    the CLAUDE - ASH - LOGGING - TRACING rules
  for all domains with proper OpenTelemetry integration and business metrics
    collection.
  """

  require Logger
  require OpenTelemetry.Tracer

  # SOPv5.11 Observability Helpers
  alias Indrajaal.Observability.AuditLogger

  # OpenTelemetry Integration
  require OpentelemetryProcessPropagator

  @doc """
  Attach all telemetry handlers during application startup.
  """
  @spec attach_handlers() :: any()
  def attach_handlers do
    attach_ash_handlers()
    attach_phoenix_handlers()
    attach_ecto_handlers()
    attach_oban_handlers()
    attach_business_handlers()
    attach_security_handlers()
    attach_device_handlers()
    attach_video_handlers()
    attach_alarm_handlers()
  end

  # Ash Framework Handlers
  @spec attach_ash_handlers() :: any()
  defp attach_ash_handlers do
    :telemetry.attach_many(
      "intelitor - ash - handlers",
      [
        [:ash, :domain, :create, :start],
        [:ash, :domain, :create, :stop],
        [:ash, :domain, :create, :exception],
        [:ash, :domain, :read, :start],
        [:ash, :domain, :read, :stop],
        [:ash, :domain, :read, :exception],
        [:ash, :domain, :update, :start],
        [:ash, :domain, :update, :stop],
        [:ash, :domain, :update, :exception],
        [:ash, :domain, :destroy, :start],
        [:ash, :domain, :destroy, :stop],
        [:ash, :domain, :destroy, :exception]
      ],
      &handle_ash_event/4,
      nil
    )
  end

  # Phoenix Framework Handlers
  @spec attach_phoenix_handlers() :: any()
  defp attach_phoenix_handlers do
    :telemetry.attach_many(
      "intelitor - phoenix - handlers",
      [
        [:phoenix, :endpoint, :start],
        [:phoenix, :endpoint, :stop],
        [:phoenix, :router_dispatch, :start],
        [:phoenix, :router_dispatch, :stop],
        [:phoenix, :router_dispatch, :exception]
      ],
      &handle_phoenix_event/4,
      nil
    )
  end

  # Ecto Database Handlers
  @spec attach_ecto_handlers() :: any()
  defp attach_ecto_handlers do
    :telemetry.attach_many(
      "intelitor - ecto - handlers",
      [
        [:indrajaal, :repo, :query],
        [:indrajaal, :repo, :query, :exception]
      ],
      &handle_ecto_event/4,
      nil
    )
  end

  # Oban Job Handlers
  @spec attach_oban_handlers() :: any()
  defp attach_oban_handlers do
    :telemetry.attach_many(
      "intelitor - oban - handlers",
      [
        [:oban, :job, :start],
        [:oban, :job, :stop],
        [:oban, :job, :exception]
      ],
      &handle_oban_event/4,
      nil
    )
  end

  # Business Logic Handlers
  @spec attach_business_handlers() :: any()
  defp attach_business_handlers do
    business_events = [
      # User management __events
      [:indrajaal, :user, :registered],
      [:indrajaal, :user, :authenticated],
      [:indrajaal, :user, :mfa_enabled],
      [:indrajaal, :user, :locked],

      # Organization __events
      [:indrajaal, :organization, :created],
      [:indrajaal, :organization, :updated],

      # Billing __events
      [:indrajaal, :subscription, :created],
      [:indrajaal, :subscription, :upgraded],
      [:indrajaal, :subscription, :cancelled],
      [:indrajaal, :invoice, :generated],
      [:indrajaal, :payment, :processed],
      [:indrajaal, :payment, :failed],

      # Compliance __events
      [:indrajaal, :assessment, :completed],
      [:indrajaal, :compliance, :violation],
      [:indrajaal, :audit, :report_generated]
    ]

    :telemetry.attach_many(
      "intelitor - business - handlers",
      business_events,
      &handle_business_event/4,
      nil
    )
  end

  # Security Events Handlers
  @spec attach_security_handlers() :: any()
  defp attach_security_handlers do
    security_events = [
      # Authentication __events
      [:indrajaal, :auth, :login_success],
      [:indrajaal, :auth, :login_failure],
      [:indrajaal, :auth, :logout],
      [:indrajaal, :auth, :session_expired],
      [:indrajaal, :auth, :mfa_challenge],
      [:indrajaal, :auth, :mfa_success],
      [:indrajaal, :auth, :mfa_failure],

      # Access control __events
      [:indrajaal, :access, :granted],
      [:indrajaal, :access, :denied],
      [:indrajaal, :access, :revoked],
      [:indrajaal, :access, :schedule_violation],
      [:indrajaal, :access, :anti_passback_violation],

      # Policy __events
      [:indrajaal, :policy, :violation],
      [:indrajaal, :policy, :evaluation],

      # Security incidents
      [:indrajaal, :security, :incident_detected],
      [:indrajaal, :security, :threat_analyzed]
    ]

    :telemetry.attach_many(
      "intelitor - security - handlers",
      security_events,
      &handle_security_event/4,
      nil
    )
  end

  # Device Management Handlers
  @spec attach_device_handlers() :: any()
  defp attach_device_handlers do
    device_events = [
      [:indrajaal, :device, :connected],
      [:indrajaal, :device, :disconnected],
      [:indrajaal, :device, :heartbeat_missed],
      [:indrajaal, :device, :status_changed],
      [:indrajaal, :device, :maintenance_required],
      [:indrajaal, :device, :configuration_updated],
      [:indrajaal, :device, :telemetry_received]
    ]

    :telemetry.attach_many(
      "intelitor - device - handlers",
      device_events,
      &handle_device_event/4,
      nil
    )
  end

  # Video System Handlers
  @spec attach_video_handlers() :: any()
  defp attach_video_handlers do
    video_events = [
      [:indrajaal, :video, :recording_started],
      [:indrajaal, :video, :recording_stopped],
      [:indrajaal, :video, :stream_connected],
      [:indrajaal, :video, :stream_disconnected],
      [:indrajaal, :video, :analytics_processed],
      [:indrajaal, :video, :motion_detected],
      [:indrajaal, :video, :face_detected],
      [:indrajaal, :video, :export_completed]
    ]

    :telemetry.attach_many(
      "intelitor - video - handlers",
      video_events,
      &handle_video_event/4,
      nil
    )
  end

  # Alarm System Handlers
  @spec attach_alarm_handlers() :: any()
  defp attach_alarm_handlers do
    alarm_events = [
      [:indrajaal, :alarm, :triggered],
      [:indrajaal, :alarm, :acknowledged],
      [:indrajaal, :alarm, :investigated],
      [:indrajaal, :alarm, :verified],
      [:indrajaal, :alarm, :resolved],
      [:indrajaal, :alarm, :false_alarm],
      [:indrajaal, :alarm, :escalated],
      [:indrajaal, :alarm, :response_dispatched],
      [:indrajaal, :alarm, :sla_violated]
    ]

    :telemetry.attach_many(
      "intelitor - alarm - handlers",
      alarm_events,
      &handle_alarm_event/4,
      nil
    )
  end

  # Event Handler Implementations

  @doc """
  Handles Ash resource events and routes them to appropriate loggers.

  Routes events to DomainLogger for successful operations (create, read, update, destroy)
  and to ErrorLogger for errors and exceptions. Automatically enriches metadata with
  SOPv5.11 observability information (domain, resource, trace_id).

  ## Examples

      iex> handle_ash_event(
      ...>   [:ash, Indrajaal.Billing, :create, :stop],
      ...>   %{duration: 1500},
      ...>   %{resource: Indrajaal.Billing.Invoice, action: :create},
      ...>   %{}
      ...> )
      :ok

      iex> handle_ash_event(
      ...>   [:ash, Indrajaal.Devices, :error],
      ...>   %{},
      ...>   %{resource: Indrajaal.Devices.Device, error: %{message: "Failed"}},
      ...>   %{}
      ...> )
      :ok
  """
  @spec handle_ash_event(list(), map(), map(), map()) :: :ok
  def handle_ash_event(event_name, measurements, metadata, _config) do
    # Extract domain and resource from metadata
    resource_module = Map.get(metadata, :resource)

    if resource_module do
      # Prepare SOPv5.11 observability metadata
      enriched_metadata = prepare_observability_metadata(resource_module, metadata)

      # Extract domain for logging
      domain = enriched_metadata.domain

      # Calculate duration if present
      duration_ms =
        if Map.has_key?(measurements, :duration) do
          System.convert_time_unit(measurements.duration, :native, :millisecond)
        else
          0
        end

      # Route based on event type
      case event_name do
        # Error events - route to ErrorLogger
        [_ash, _domain_module, :error] ->
          error = Map.get(metadata, :error, %{message: "Unknown error"})
          action = Map.get(metadata, :action, :unknown)

          Indrajaal.Observability.ErrorLogger.log_error(
            domain,
            action,
            error,
            convert_to_keyword_list(enriched_metadata)
          )

        # Exception events - route to ErrorLogger
        [_ash, _domain_module, :exception] ->
          exception = Map.get(metadata, :exception, %RuntimeError{message: "Unknown exception"})
          action = Map.get(metadata, :action, :unknown)

          Indrajaal.Observability.ErrorLogger.log_error(
            domain,
            action,
            exception,
            convert_to_keyword_list(enriched_metadata)
          )

        # Successful action events - route to DomainLogger
        [_ash, _domain_module, action, :stop] when action in [:create, :read, :update, :destroy] ->
          metadata_with_duration = Map.put(enriched_metadata, :duration_ms, duration_ms)

          Indrajaal.Observability.DomainLogger.log_success(
            domain,
            action,
            convert_to_keyword_list(metadata_with_duration)
          )

          # Emit metrics for monitoring (preserve existing functionality)
          emit_ash_metrics(event_name, measurements, metadata, duration_ms)

        # Other events - log with basic success handler
        _ ->
          action = extract_action_from_event(event_name)

          Indrajaal.Observability.DomainLogger.log_success(
            domain,
            action,
            convert_to_keyword_list(enriched_metadata)
          )

          # Emit metrics for monitoring (preserve existing functionality)
          if Map.has_key?(measurements, :duration) do
            emit_ash_metrics(event_name, measurements, metadata, duration_ms)
          end
      end
    end

    :ok
  end

  defp handle_phoenix_event(event_name, measurements, metadata, _config) do
    case event_name do
      [:phoenix, :router_dispatch, :stop] ->
        duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

        Logger.info("HTTP __request completed",
          method: metadata.method,
          path_info: metadata.path_info,
          status: metadata.status,
          duration_ms: duration_ms,
          remote_ip: format_ip(metadata.remote_ip)
        )

      [:phoenix, :router_dispatch, :exception] ->
        Logger.error("HTTP __request failed",
          method: metadata.method,
          path_info: metadata.path_info,
          kind: metadata.kind,
          reason: metadata.reason,
          remote_ip: format_ip(metadata.remote_ip)
        )

      _ ->
        :ok
    end
  end

  defp handle_ecto_event(event_name, measurements, metadata, _config) do
    case event_name do
      [:indrajaal, :repo, :query] ->
        duration_ms = System.convert_time_unit(measurements.total_time, :native, :millisecond)

        # Log slow queries
        if duration_ms > 1000 do
          Logger.warning("Slow database query detected",
            duration_ms: duration_ms,
            source: metadata.source,
            query: metadata.query
          )
        end

      [:indrajaal, :repo, :query, :exception] ->
        Logger.error("Database query failed",
          source: metadata.source,
          query: metadata.query,
          kind: metadata.kind,
          reason: metadata.reason
        )

      _ ->
        :ok
    end
  end

  defp handle_oban_event(event_name, measurements, metadata, _config) do
    case event_name do
      [:oban, :job, :stop] ->
        duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

        Logger.info("Background job completed",
          job_id: metadata.job.id,
          worker: metadata.job.worker,
          queue: metadata.job.queue,
          duration_ms: duration_ms,
          attempt: metadata.job.attempt
        )

      [:oban, :job, :exception] ->
        Logger.error("Background job failed",
          job_id: metadata.job.id,
          worker: metadata.job.worker,
          queue: metadata.job.queue,
          attempt: metadata.job.attempt,
          kind: metadata.kind,
          reason: metadata.reason
        )

      _ ->
        :ok
    end
  end

  defp handle_business_event(event_name, measurements, metadata, _config) do
    Logger.info("Business __event occurred",
      __event: event_name,
      measurements: measurements,
      metadata: sanitize_metadata(metadata)
    )

    # Emit business metrics
    emit_business_metrics(event_name, measurements, metadata)
  end

  defp handle_security_event(event_name, measurements, metadata, _config) do
    Logger.info("Security __event occurred",
      __event: event_name,
      severity: determine_security_severity(event_name),
      measurements: measurements,
      metadata: sanitize_security_metadata(metadata)
    )

    # Emit security alerts if necessary
    handle_security_alerts(event_name, metadata)
  end

  defp handle_device_event(event_name, measurements, metadata, _config) do
    Logger.info("Device __event occurred",
      __event: event_name,
      device_id: metadata[:device_id],
      device_type: metadata[:device_type],
      measurements: measurements,
      metadata: sanitize_metadata(metadata)
    )
  end

  defp handle_video_event(event_name, measurements, metadata, _config) do
    Logger.info("Video __event occurred",
      __event: event_name,
      camera_id: metadata[:camera_id],
      measurements: measurements,
      metadata: sanitize_metadata(metadata)
    )
  end

  defp handle_alarm_event(event_name, measurements, metadata, _config) do
    severity = determine_alarm_severity(event_name, metadata)

    Logger.info("Alarm __event occurred",
      __event: event_name,
      alarm_id: metadata[:alarm_id],
      incident_type: metadata[:incident_type],
      severity: severity,
      measurements: measurements,
      metadata: sanitize_metadata(metadata)
    )

    # Handle alarm escalation
    handle_alarm_escalation(event_name, metadata, severity)
  end

  # Helper Functions

  defp emit_ash_metrics(event_name, _measurements, metadata, duration_ms) do
    # Extract action from metadata or event name as fallback
    action = Map.get(metadata, :action) || extract_action_from_event(event_name)

    :telemetry.execute(
      [:indrajaal, :metrics, :ash_operation],
      %{duration: duration_ms, count: 1},
      %{
        resource: metadata.resource,
        action: action,
        success: metadata[:success?] || true,
        __event: event_name
      }
    )
  end

  defp emit_business_metrics(event_name, measurements, metadata) do
    :telemetry.execute(
      [:indrajaal, :metrics, :business_event],
      Map.merge(%{count: 1}, measurements),
      Map.merge(%{__event: event_name}, metadata)
    )
  end

  @spec extract_actor_id(term()) :: term()
  # Enhanced to extract user_id from various metadata patterns for SOPv5.11 compliance
  defp extract_actor_id(metadata) do
    cond do
      # Direct user_id field
      Map.has_key?(metadata, :user_id) ->
        metadata.user_id

      # Actor with id field
      Map.has_key?(metadata, :actor) && is_map(metadata.actor) &&
          Map.has_key?(metadata.actor, :id) ->
        metadata.actor.id

      # Direct actor_id field
      Map.has_key?(metadata, :actor_id) ->
        metadata.actor_id

      # Default to system for required field
      true ->
        "system"
    end
  end

  # Enhanced to extract tenant_id from various metadata patterns for SOPv5.11 compliance
  @spec extract_tenant_id(term()) :: term()
  defp extract_tenant_id(metadata) do
    cond do
      # Direct tenant_id field
      Map.has_key?(metadata, :tenant_id) ->
        metadata.tenant_id

      # Actor with tenant_id field
      Map.has_key?(metadata, :actor) && is_map(metadata.actor) &&
          Map.has_key?(metadata.actor, :tenant_id) ->
        metadata.actor.tenant_id

      # Direct tenant field
      Map.has_key?(metadata, :tenant) ->
        metadata.tenant

      # Default to system for required field
      true ->
        "system"
    end
  end

  @spec format_ip(term()) :: term()
  defp format_ip(ip) when is_tuple(ip) do
    ip |> :inet.ntoa() |> to_string()
  end

  @spec format_ip(term()) :: term()
  defp format_ip(ip), do: ip

  defp sanitize_metadata(metadata) do
    metadata
    |> Map.drop([:password, :token, :api_key, :secret])
    |> Map.new()
  end

  @spec sanitize_security_metadata(term()) :: term()
  defp sanitize_security_metadata(metadata) do
    metadata
    |> Map.drop([:password, :token, :api_key, :secret, :credentials])
    |> Map.new()
  end

  @spec determine_security_severity(term()) :: term()
  defp determine_security_severity(event_name) do
    case event_name do
      [:indrajaal, :auth, :login_failure] -> :medium
      [:indrajaal, :access, :denied] -> :medium
      [:indrajaal, :policy, :violation] -> :high
      [:indrajaal, :security, :incident_detected] -> :critical
      _ -> :low
    end
  end

  @spec determine_alarm_severity(term(), term()) :: term()
  defp determine_alarm_severity(event_name, metadata) do
    case {event_name, metadata[:incident_type]} do
      {[:indrajaal, :alarm, :triggered], "fire"} -> :critical
      {[:indrajaal, :alarm, :triggered], "intrusion"} -> :high
      {[:indrajaal, :alarm, :triggered], "medical"} -> :critical
      {[:indrajaal, :alarm, :sla_violated], _} -> :high
      _ -> :medium
    end
  end

  @spec handle_security_alerts(term(), term()) :: term()
  defp handle_security_alerts(event_name, metadata) do
    case determine_security_severity(event_name) do
      severity when severity in [:high, :critical] ->
        :telemetry.execute(
          [:indrajaal, :alert, :security],
          %{count: 1, severity_level: severity_to_number(severity)},
          %{__event: event_name, metadata: metadata}
        )

      _ ->
        :ok
    end
  end

  defp handle_alarm_escalation(event_name, metadata, severity) do
    case {event_name, severity} do
      {[:indrajaal, :alarm, :sla_violated], _} ->
        :telemetry.execute(
          [:indrajaal, :escalation, :sla_violation],
          %{count: 1},
          metadata
        )

      {_, :critical} ->
        :telemetry.execute(
          [:indrajaal, :escalation, :critical_alarm],
          %{count: 1},
          metadata
        )

      _ ->
        :ok
    end
  end

  @spec severity_to_number(term()) :: term()
  defp severity_to_number(:low), do: 1
  defp severity_to_number(:medium), do: 2
  defp severity_to_number(:high), do: 3
  @spec severity_to_number(term()) :: term()
  defp severity_to_number(:critical), do: 4

  @doc """
  Extracts the domain name from a resource module path.

  This function takes a module name (like Indrajaal.Billing.Invoice) and
  extracts the domain name ("billing") from it.

  ## Examples

      iex> extract_domain_from_resource(Indrajaal.Billing.Invoice)
      "billing"

      iex> extract_domain_from_resource(Indrajaal.Devices.Device)
      "devices"

      iex> extract_domain_from_resource(Phoenix.LiveView)
      nil

      iex> extract_domain_from_resource(Indrajaal)
      nil
  """
  @spec extract_domain_from_resource(module()) :: String.t() | nil
  def extract_domain_from_resource(resource_module) do
    case Module.split(resource_module) do
      ["Indrajaal", domain | _rest] when is_binary(domain) ->
        Macro.underscore(domain)

      _ ->
        nil
    end
  end

  @doc """
  Prepares observability metadata in SOPv5.11 format.

  Converts Ash resource metadata to standardized observability format with
  domain, resource, trace_id, user_id, tenant_id, and any additional metadata fields.

  Extracts user_id from common patterns: actor.id, actor_id, user_id
  Extracts tenant_id from common patterns: tenant, tenant_id

  ## Examples

      iex> prepare_observability_metadata(Indrajaal.Billing.Invoice, %{action: :create, resource_id: "inv-123", user_id: "user-1", tenant_id: "tenant-1"})
      %{domain: "billing", resource: "Indrajaal.Billing.Invoice", action: :create, resource_id: "inv-123", trace_id: ..., user_id: "user-1", tenant_id: "tenant-1"}

      iex> prepare_observability_metadata(Indrajaal.Devices.Device, nil)
      %{domain: "devices", resource: "Indrajaal.Devices.Device", trace_id: ..., user_id: "system", tenant_id: "system"}
  """
  @spec prepare_observability_metadata(module(), map() | nil) :: map()
  def prepare_observability_metadata(resource_module, ash_metadata) do
    base_metadata = %{
      domain: extract_domain_from_resource(resource_module),
      resource: inspect(resource_module),
      trace_id: get_trace_id()
    }

    case ash_metadata do
      nil ->
        # Provide system defaults for required fields when no metadata
        Map.merge(base_metadata, %{
          user_id: "system",
          tenant_id: "system"
        })

      metadata when is_map(metadata) ->
        # Extract user_id and tenant_id using existing helper functions
        user_id = extract_actor_id(metadata)
        tenant_id = extract_tenant_id(metadata)

        # Merge all metadata with extracted fields
        metadata
        |> Map.merge(base_metadata)
        |> Map.put(:user_id, user_id)
        |> Map.put(:tenant_id, tenant_id)
    end
  end

  @doc """
  Extracts resource ID from Ash data.

  Attempts to extract the resource identifier from Ash resource data,
  checking both atom and string keys for resource_id and id fields.

  ## Examples

      iex> extract_resource_id(%{resource_id: "res-123"})
      "res-123"

      iex> extract_resource_id(%{"resource_id" => "res-456"})
      "res-456"

      iex> extract_resource_id(%{id: "id-789"})
      "id-789"

      iex> extract_resource_id(%{name: "test"})
      nil

      iex> extract_resource_id(nil)
      nil
  """
  @spec extract_resource_id(map() | nil) :: String.t() | nil
  def extract_resource_id(nil), do: nil

  def extract_resource_id(ash_data) when is_map(ash_data) do
    ash_data[:resource_id] ||
      ash_data["resource_id"] ||
      ash_data[:id] ||
      ash_data["id"]
  end

  @doc """
  Determines if an Ash event should be audited based on domain sensitivity.

  Returns true for sensitive domains (Billing, AccessControl, Accounts) and
  false for read operations or non-sensitive domains.

  ## Task 11.4.1.1.5 - Audit Integration Helpers

  ## Examples

      iex> should_audit?([:ash, Indrajaal.Billing, :create, :stop])
      true

      iex> should_audit?([:ash, Indrajaal.Devices, :read, :stop])
      false
  """
  @spec should_audit?(list()) :: boolean()
  def should_audit?(event_name) when is_list(event_name) do
    case event_name do
      # Read operations - no audit needed (even for sensitive domains)
      [:ash, _domain, :read, :stop] ->
        false

      # Sensitive domains - all non-read actions require audit
      [:ash, domain, _action, :stop]
      when domain in [
             Indrajaal.Billing,
             Indrajaal.AccessControl,
             Indrajaal.Accounts
           ] ->
        true

      # Non-Ash events - no audit
      _ ->
        false
    end
  end

  @doc """
  Logs an audit event with structured metadata for compliance tracking.

  Accepts event name, metadata map, and measurements map. Logs the event
  with user_id, tenant_id, resource_id, and domain-specific data.

  ## Task 11.4.1.1.5 - Audit Integration Helpers

  ## Examples

      iex> log_audit_event(
      ...>   [:ash, Indrajaal.Billing, :create, :stop],
      ...>   %{user_id: "user-123", tenant_id: "tenant-456"},
      ...>   %{duration: 1500}
      ...> )
      :ok
  """
  @spec log_audit_event(list(), map(), map()) :: :ok
  def log_audit_event(event_name, metadata, measurements) when is_list(event_name) do
    # Extract domain and action from event name
    domain = extract_domain_from_event(event_name)
    action = extract_action_from_event_name(event_name)

    # Build operation subtype from domain and action
    operation_subtype = "#{domain}_#{action}"

    # Build details map with resource and domain-specific data
    details = %{
      domain: domain,
      resource: Map.get(metadata, :resource),
      resource_id: Map.get(metadata, :resource_id),
      action: action,
      duration_ms: Map.get(measurements, :duration, 0)
    }

    # Add any additional domain-specific metadata to details
    additional_metadata =
      Map.drop(metadata, [:user_id, :tenant_id, :resource_id, :resource, :trace_id, :action])

    full_details = Map.merge(details, additional_metadata)

    # Build metadata keyword list for AuditLogger (required fields)
    # Use defaults for required fields if not provided
    audit_metadata = [
      user_id: Map.get(metadata, :user_id) || "system",
      tenant_id: Map.get(metadata, :tenant_id) || "system",
      trace_id: Map.get(metadata, :trace_id) || "no-trace",
      severity: "info"
    ]

    # Log to audit system using "user_action" operation type
    AuditLogger.log_audit_event("user_action", operation_subtype, full_details, audit_metadata)

    :ok
  end

  # Private helper to extract domain from event name
  defp extract_domain_from_event(event_name) when is_list(event_name) do
    case event_name do
      [:ash, domain, _action, :stop] when is_atom(domain) ->
        domain
        |> to_string()
        |> String.split(".")
        |> List.last()
        |> String.downcase()

      _ ->
        "unknown"
    end
  end

  # Private helper to extract action from event name
  defp extract_action_from_event_name(event_name) when is_list(event_name) do
    case event_name do
      [:ash, _domain, action, :stop] when is_atom(action) ->
        action

      _ ->
        :unknown
    end
  end

  @doc """
  Gets the current OpenTelemetry trace ID.

  Returns the trace ID from the current OpenTelemetry context if available,
  or nil if not in a traced context.

  ## Examples

      iex> get_trace_id()
      "abc123def456..."  # or nil
  """
  @spec get_trace_id() :: String.t() | nil
  def get_trace_id do
    # Try to get trace ID from OpenTelemetry context
    # Returns nil if OpenTelemetry is not available or no active trace
    try do
      case :otel_tracer.current_span_ctx() do
        :undefined ->
          nil

        span_ctx ->
          trace_id = :otel_span.trace_id(span_ctx)
          if trace_id != 0, do: Integer.to_string(trace_id, 16), else: nil
      end
    rescue
      _ -> nil
    end
  end

  # Private helper to convert map to keyword list
  defp convert_to_keyword_list(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} -> {k, v} end)
    |> Enum.into([])
  end

  # Private helper to extract action from event name
  defp extract_action_from_event(event_name) when is_list(event_name) do
    event_name
    |> Enum.reverse()
    |> Enum.find(&is_atom(&1))
    |> case do
      :stop -> :unknown
      action when is_atom(action) -> action
      _ -> :unknown
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
