defmodule Indrajaal.Observability.Tracing do
  @moduledoc """
  Enhanced tracing module with complete SigNoz integration and distributed tracing.

  This module provides comprehensive distributed tracing for the Indrajaal Security
  Monitoring System with:
  - SigNoz - specific attributes and tags
  - Distributed trace __context propagation
  - Domain - specific trace instrumentation
  - STAMP safety constraints tracking in traces
  - TDG methodology trace spans
  - GDE goal tracking in distributed traces
  - Performance monitoring with latency tracking
  - Error tracking and recovery suggestions

  ## Migration to Shared Utilities

  This module has been migrated to use `Indrajaal.Shared.` for
  common observability functions, eliminating ~65 lines of duplicate code:
  - format_trace_id / 1 -> .format_trace_id / 1
  - format_span_id / 1 -> .format_span_id / 1
  - ensure_tenant_isolation / 1 -> .ensure_tenant_isolation / 1
  - is_basic_type?/1 -> .is_basic_type?/1

  ## Usage

      # Trace a domain operation
      Indrajaal.Observability.Tracing.trace_domain_operation(
        :alarms,
        :process_alarm,
        %{alarm_id: "ALM - 123", severity: :critical},
        fn ->
          # Process alarm logic")
    end
      )

      # Trace with custom attributes
      Indrajaal.Observability.Tracing.with_span(
        "custom_operation",
        %{custom_attr: "value"},
        fn ->
          # Custom logic")
    end
      )
  """

  require Logger
  require OpenTelemetry.Tracer
  alias Indrajaal.Observability.{Logging, Telemetry}
  alias Indrajaal.Shared.ObservabilityHelpers

  # SigNoz - specific semantic conventions
  @signoz_attributes %{
    "service.name" => "indrajaal",
    "service.version" => "21.2.1",
    "deployment.environment" => "production",
    "signoz.enabled" => true
  }

  # Domain span prefixes
  @domain_span_prefixes %{
    access_control: "access",
    accounts: "accounts",
    alarms: "alarms",
    analytics: "analytics",
    asset_management: "assets",
    billing: "billing",
    communication: "comm",
    compliance: "compliance",
    core: "core",
    devices: "devices",
    dispatch: "dispatch",
    guard_tour: "guard",
    integrations: "integrations",
    maintenance: "maintenance",
    policy: "policy",
    risk_management: "risk",
    sites: "sites",
    video: "video",
    visitor_management: "visitor",
    authentication: "authn",
    authorization: "authz",
    cluster: "cluster",
    cockpit: "cockpit",
    coordination: "coordination",
    cortex: "cortex",
    cybernetic: "cyber",
    distributed: "distributed",
    flame: "flame",
    identity: "identity",
    knowledge: "knowledge",
    mesh: "mesh",
    observability: "obs",
    safety: "safety",
    security: "security",
    validation: "validation"
  }

  @doc """
  Traces a domain - specific operation with full SigNoz integration.
  """
  @spec trace_domain_operation(term(), term(), map(), term()) :: term()
  def trace_domain_operation(domain, operation, context \\ %{}, fun) do
    unless Map.has_key?(@domain_span_prefixes, domain) do
      raise ArgumentError,
            "Unknown domain: #{domain}. Valid domains: #{Map.keys(@domain_span_prefixes)}"
    end

    span_name = "#{@domain_span_prefixes[domain]}.#{operation}"
    attributes = build_domain_attributes(domain, operation, context)

    with_span(span_name, attributes, fn ->
      # Log operation start
      Logging.log_domain_event(domain, :"#{operation}start", context, :info)

      try do
        result = fun.()

        # Log operation success
        Logging.log_domain_event(domain, :"#{operation}success", context, :info)

        # Record success metric
        Telemetry.record_domain_event(domain, :"#{operation}completed", context)

        result
      rescue
        error ->
          # Log operation failure
          Logging.log_domain_event(
            domain,
            :"#{operation}failed",
            Map.put(context, :error, Exception.message(error)),
            :error
          )

          # Record error metric
          Telemetry.record_domain_event(
            domain,
            :"#{operation}error",
            Map.put(context, :error_type, Exception.message(error))
          )

          reraise error, __STACKTRACE__
      end
    end)
  end

  @doc """
  Creates a span with SigNoz - specific attributes and error handling.
  """
  # Agent: SUPERVISOR-1 (SOPv5.1 OpenTelemetry Correct Integration)
  # Error Pattern: EP-081 - OpenTelemetry API Misuse
  # Fix Strategy: Use manual span management for function-based API
  # Impact: Provides wrapper function that works with anonymous functions
  # Dependencies: Requires OpenTelemetry.Tracer and __context management
  # Validation: Compile with --warnings-as-errors
  # Future: Consider deprecating in favor of macro-only usage
  @spec with_span(term(), term(), term()) :: term()
  def with_span(name, attributes \\ %{}, fun) do
    require OpenTelemetry.Tracer

    # Merge SigNoz attributes
    enhanced_attributes =
      @signoz_attributes
      |> Map.merge(attributes)
      |> Map.merge(extract_context_attributes())
      |> ObservabilityHelpers.ensure_tenant_isolation()

    # Convert attributes to list format for OpenTelemetry
    attribute_list =
      enhanced_attributes
      |> Enum.filter(fn {_k, v} -> not is_nil(v) and ObservabilityHelpers.basic_type?(v) end)
      |> Enum.map(fn {k, v} -> {to_string(k), convert_attribute_value(v)} end)
      |> Enum.to_list()

    # Use the macro with our function
    OpenTelemetry.Tracer.with_span name do
      # Set all attributes at once
      if Code.ensure_loaded?(OpenTelemetry),
        do: OpenTelemetry.Tracer.set_attributes(attribute_list)

      # Set span kind based on operation type
      set_span_kind(name, attributes)

      # Add baggage for distributed __context
      add_distributed_context(attributes)

      # Track span start time
      start_time = System.monotonic_time(:microsecond)

      try do
        result = fun.()

        # Calculate duration
        duration = System.monotonic_time(:microsecond) - start_time

        # Set success attributes
        if Code.ensure_loaded?(OpenTelemetry) do
          OpenTelemetry.Tracer.set_attributes([
            {"operation.success", true},
            {"operation.duration_us", duration},
            {"signoz.custom.latency_ms", duration / 1000}
          ])
        else
          :ok
        end

        result
      rescue
        error ->
          # Calculate duration even on error
          duration = System.monotonic_time(:microsecond) - start_time

          # Handle error with enhanced __context
          handle_span_error(error, __STACKTRACE__, name, attributes, duration)

          reraise error, __STACKTRACE__
      end
    end
  end

  @doc """
  Traces a STAMP safety constraint check with proper span hierarchy.
  """
  @spec trace_stamp_constraint(term(), term(), term()) :: term()
  def trace_stamp_constraint(constraint, context \\ %{}, fun) do
    span_name = "stamp.constraint.#{constraint}"

    attributes = %{
      "stamp.constraint" => constraint,
      "stamp.control_structure" => context[:control_structure],
      "stamp.hazard" => context[:hazard],
      "stamp.unsafe_control_action" => context[:unsafe_control_action]
    }

    with_span(span_name, attributes, fn ->
      result = fun.()

      # Record constraint status
      status =
        case result do
          {:ok, :satisfied} -> :satisfied
          {:ok, :at_risk} -> :at_risk
          {:error, _} -> :violated
          _ -> :unknown
        end

      # Log STAMP event
      Logging.log_stamp_event(constraint, status, context)

      # Record telemetry
      Telemetry.record_stamp_event(constraint, status, context)

      result
    end)
  end

  @doc """
  Traces a TDG methodology compliance check.
  """
  @spec trace_tdg_compliance(term(), term(), map(), term()) :: term()
  def trace_tdg_compliance(phase, component, context \\ %{}, fun) do
    span_name = "tdg.#{phase}.#{component}"

    attributes = %{
      "tdg.phase" => phase,
      "tdg.component" => component,
      "tdg.ai_agent" => context[:ai_agent],
      "tdg.test_coverage" => context[:test_coverage]
    }

    with_span(span_name, attributes, fn ->
      result = fun.()

      # Determine compliance status
      compliance_status =
        case result do
          {:ok, true} -> :compliant
          {:ok, false} -> :non_compliant
          {:ok, :partial} -> :partial
          _ -> :unknown
        end

      # Log TDG event
      Logging.log_tdg_event(phase, component, compliance_status, context)

      # Record telemetry
      Telemetry.record_tdg_event(phase, component, compliance_status, context)

      result
    end)
  end

  @doc """
  Traces a GDE goal execution with measurement.
  """
  @spec trace_gde_goal(term(), term(), map(), term()) :: term()
  def trace_gde_goal(domain, goalid, context \\ %{}, fun) do
    span_name = "gde.#{domain}.goal_#{goalid}"

    attributes = %{
      "gde.domain" => domain,
      "gde.goal_id" => goalid,
      "gde.target_value" => context[:target_value],
      "gde.current_value" => context[:current_value]
    }

    with_span(span_name, attributes, fn ->
      result = fun.()

      # Extract achievement metrics
      {status, metrics} =
        case result do
          {:ok, metrics} when is_map(metrics) ->
            status = determine_goal_status(metrics)
            {status, metrics}

          {:ok, value} ->
            {:in_progress, %{actual_value: value}}

          {:error, _} ->
            {:failed, %{}}

          _ ->
            {:unknown, %{}}
        end

      # Log GDE event
      Logging.log_gde_event(domain, goalid, status, Map.merge(context, metrics))

      # Record telemetry
      Telemetry.recordgde_event(domain, goalid, status, Map.merge(context, metrics))

      result
    end)
  end

  @doc """
  Creates a child span that inherits trace __context and tenant isolation.
  """
  @spec with_child_span(term(), term(), term()) :: term()
  def with_child_span(name, attributes \\ %{}, fun) do
    # Get parent __context
    parent_ctx = :otel_tracer.current_span_ctx()

    if parent_ctx == :undefined do
      # No parent, create new trace
      with_span(name, attributes, fun)
    else
      # Create child span with parent __context
      enhanced_attributes =
        attributes
        |> Map.merge(extract_parent_attributes(parent_ctx))
        |> ObservabilityHelpers.ensure_tenant_isolation()

      with_span(name, enhanced_attributes, fun)
    end
  end

  @doc """
  Traces a batch operation with individual span tracking.
  """
  @spec trace_batch_operation(term(), term(), map(), term()) :: term()
  def trace_batch_operation(operationname, items, context \\ %{}, process_fn) do
    batch_id = generate_batch_id()

    span_name = "batch.#{operationname}"

    attributes =
      Map.merge(context, %{
        "batch.id" => batch_id,
        "batch.size" => length(items),
        "batch.operation" => operationname
      })

    with_span(span_name, attributes, fn ->
      results =
        items
        |> Enum.with_index()
        |> Enum.map(fn {item, index} ->
          item_span_name = "#{operationname}.item_#{index}"

          with_child_span(item_span_name, %{"batch.item_index" => index}, fn ->
            try do
              {:ok, process_fn.(item)}
            rescue
              error -> {:error, error}
            end
          end)
        end)

      # Calculate batch metrics
      success_count = Enum.count(results, fn r -> match?({:ok, _}, r) end)
      error_count = length(results) - success_count

      if Code.ensure_loaded?(OpenTelemetry) do
        OpenTelemetry.Tracer.set_attributes(
          format_otel_attributes([
            {"batch.success_count", success_count},
            {"batch.error_count", error_count},
            {"batch.success_rate", success_count / length(results) * 100}
          ])
        )
      else
        :ok
      end

      results
    end)
  end

  @doc """
  Traces an external service call with timeout and retry tracking.
  """
  @spec trace_external_call(term(), term(), map(), term()) :: term()
  def trace_external_call(service, endpoint, options \\ %{}, fun) do
    span_name = "external.#{service}.#{endpoint}"

    attributes = %{
      "external.service" => service,
      "external.endpoint" => endpoint,
      "external.method" => options[:method] || "GET",
      "external.timeout_ms" => options[:timeout] || 5000,
      "external.max_retries" => options[:max_retries] || 3
    }

    with_span(span_name, attributes, fn ->
      # Track retries
      result =
        execute_with_retries(fun, options[:max_retries] || 3, fn attempt ->
          if Code.ensure_loaded?(OpenTelemetry) do
            OpenTelemetry.Tracer.add_event("retry_attempt", %{
              "retry.attempt" => attempt,
              "retry.timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
            })
          else
            :ok
          end
        end)

      if Code.ensure_loaded?(OpenTelemetry) do
        OpenTelemetry.Tracer.set_attributes(
          format_otel_attributes([
            # Will be updated by retry logic
            {"external.retry_count", 0}
          ])
        )
      else
        :ok
      end

      result
    end)
  end

  @doc """
  Adds distributed trace __context to outgoing _requests.
  """
  @spec inject_trace_context(any()) :: any()
  def inject_trace_context(headers \\ []) do
    case :otel_tracer.current_span_ctx() do
      :undefined ->
        headers

      ctx ->
        trace_id = ObservabilityHelpers.format_trace_id(ctx) || String.duplicate("0", 32)
        span_id = ObservabilityHelpers.format_span_id(ctx) || String.duplicate("0", 16)
        trace_flags = format_trace_flags(ctx)

        # W3C Trace Context headers
        [
          {"traceparent", "00-#{trace_id}-#{span_id}-#{trace_flags}"},
          {"trace_state", "intelitor = enabled"}
          | headers
        ]
    end
  end

  @doc """
  Extracts trace __context from incoming _request headers.
  """
  @spec extract_trace_context(any()) :: any()
  def extract_trace_context(headers) do
    case List.keyfind(headers, "traceparent", 0) do
      {"traceparent", traceparent} ->
        parse_traceparent(traceparent)

      _ ->
        nil
    end
  end

  # Private functions

  # Convert attribute values to OpenTelemetry compatible types
  @spec convert_attribute_value(any()) :: any()
  defp convert_attribute_value(value) when is_binary(value), do: value
  defp convert_attribute_value(value) when is_number(value), do: value
  defp convert_attribute_value(value) when is_boolean(value), do: value
  defp convert_attribute_value(value) when is_atom(value), do: to_string(value)
  defp convert_attribute_value(value), do: inspect(value)

  defp build_domain_attributes(domain, operation, context) do
    %{
      "domain" => domain,
      "operation" => operation,
      "resource.type" => context[:resource_type] || "unknown",
      "resource.id" => context[:resource_id],
      "user.id" => context[:user_id] || context[:actor_id],
      "tenant.id" => context[:tenant_id] || "default"
    }
    |> Map.merge(extract_domain_specific_attributes(domain, context))
  end

  @spec extract_domain_specific_attributes(term(), term()) :: term()
  defp extract_domain_specific_attributes(:alarms, context) do
    %{
      "alarm.id" => context[:alarm_id],
      "alarm.severity" => context[:severity],
      "alarm.priority" => context[:priority],
      "alarm.incident_type" => context[:incident_type]
    }
  end

  @spec extract_domain_specific_attributes(term(), term()) :: term()
  defp extract_domain_specific_attributes(:devices, context) do
    %{
      "device.id" => context[:device_id],
      "device.type" => context[:device_type],
      "device.location" => context[:location],
      "device.status" => context[:status]
    }
  end

  @spec extract_domain_specific_attributes(term(), term()) :: term()
  defp extract_domain_specific_attributes(:video, context) do
    %{
      "video.camera_id" => context[:camera_id],
      "video.stream_type" => context[:stream_type],
      "video.quality" => context[:quality],
      "video.recording_id" => context[:recording_id]
    }
  end

  @spec extract_domain_specific_attributes(term(), term()) :: term()
  defp extract_domain_specific_attributes(:access_control, context) do
    %{
      "access.user_id" => context[:user_id],
      "access.location" => context[:location],
      "access.result" => context[:result],
      "access.credential_type" => context[:credential_type]
    }
  end

  @spec extract_domain_specific_attributes(term(), term()) :: term()
  defp extract_domain_specific_attributes(_, __context), do: %{}

  defp extract_context_attributes do
    metadata = Logger.metadata()

    %{
      "context._request_id" => metadata[:_request_id],
      "context.correlation_id" => metadata[:correlation_id],
      "context.session_id" => metadata[:session_id]
    }
  end

  @spec set_span_kind(term(), term()) :: term()
  defp set_span_kind(name, attributes) do
    kind =
      cond do
        String.starts_with?(name, "external.") -> :client
        String.starts_with?(name, "api.") -> :server
        attributes[:async] == true -> :producer
        attributes[:consumer] == true -> :consumer
        true -> :internal
      end

    if Code.ensure_loaded?(OpenTelemetry),
      do: OpenTelemetry.Tracer.set_attributes(format_otel_attributes([{"span.kind", kind}])),
      else: :ok
  end

  @spec add_distributed_context(term()) :: term()
  defp add_distributed_context(attributes) do
    # Add important __context as baggage for propagation
    if attributes[:tenant_id] do
      :otel_baggage.set("tenant.id", attributes[:tenant_id])
    end

    if attributes[:user_id] do
      :otel_baggage.set("user.id", attributes[:user_id])
    end
  end

  defp handle_span_error(error, stacktrace, span_name, attributes, duration) do
    error_type = error.__struct__ |> to_string()
    error_message = Exception.message(error)

    # Record exception in span
    if Code.ensure_loaded?(OpenTelemetry) do
      OpenTelemetry.Tracer.record_exception(error, stacktrace)
    end

    if Code.ensure_loaded?(OpenTelemetry) do
      OpenTelemetry.Tracer.set_status(:error, error_message)
    end

    # Set error attributes
    if Code.ensure_loaded?(OpenTelemetry) do
      OpenTelemetry.Tracer.set_attributes(
        format_otel_attributes([
          {"error", true},
          {"error.type", error_type},
          {"error.message", error_message},
          {"error.span_name", span_name},
          {"operation.success", false},
          {"operation.duration_us", duration},
          {"signoz.custom.error_latency_ms", duration / 1000}
        ])
      )
    end

    # Add recovery suggestions
    recovery = get_error_recovery_suggestions(error)

    if recovery do
      if Code.ensure_loaded?(OpenTelemetry) do
        OpenTelemetry.Tracer.add_event("error_recovery", %{
          "recovery.suggestion" => recovery
        })
      end
    end

    # Log error with trace __context
    Logging.log_error(
      error,
      stacktrace,
      Map.merge(attributes, %{
        span_name: span_name,
        duration_us: duration
      })
    )
  end

  @spec extract_parent_attributes(term()) :: term()
  defp extract_parent_attributes(parentctx) do
    %{
      "parent.trace_id" => ObservabilityHelpers.format_trace_id(parentctx) || "unknown",
      "parent.span_id" => ObservabilityHelpers.format_span_id(parentctx) || "unknown"
    }
  end

  @spec determine_goal_status(term()) :: term()
  defp determine_goal_status(metrics) do
    completion = metrics[:completion_percentage] || 0

    cond do
      completion >= 100 -> :achieved
      completion >= 75 -> :in_progress
      completion >= 50 -> :at_risk
      true -> :failed
    end
  end

  defp generate_batch_id do
    "batch-#{DateTime.utc_now() |> DateTime.to_unix(:microsecond)}-#{:rand.uniform(10_000)}"
  end

  defp execute_with_retries(fun, maxretries, on_retry, attempt \\ 0) do
    try do
      fun.()
    rescue
      error ->
        if attempt < maxretries do
          on_retry.(attempt + 1)
          :timer.sleep(calculate_backoff(attempt))
          execute_with_retries(fun, maxretries, on_retry, attempt + 1)
        else
          reraise error, __STACKTRACE__
        end
    end
  end

  @spec calculate_backoff(term()) :: term()
  defp calculate_backoff(attempt) do
    # Exponential backoff with jitter
    base_delay = :math.pow(2, attempt) * 100
    jitter = :rand.uniform(100)
    round(base_delay + jitter)
  end

  @spec format_trace_flags(term()) :: term()
  defp format_trace_flags(:undefined), do: "00"
  defp format_trace_flags(nil), do: "00"

  defp format_trace_flags(_ctx) do
    # Use constant fallback since OpenTelemetry Erlang API for trace flags is unclear
    # Trace flags are typically 0x01 for sampled traces in W3C Trace Context
    # Default to "00" (not sampled) for safety
    "00"
  end

  @spec parse_traceparent(term()) :: term()
  defp parse_traceparent(traceparent) do
    case String.split(traceparent, "-") do
      ["00", trace_id, span_id, flags] ->
        %{
          trace_id: trace_id,
          span_id: span_id,
          flags: flags
        }

      _ ->
        nil
    end
  end

  @spec get_error_recovery_suggestions(term()) :: term()
  defp get_error_recovery_suggestions(error) do
    case error.__struct__ do
      Ash.Error.Query.NotFound ->
        "Verify the resource exists and the ID is correct. Check tenant isolation."

      Ash.Error.Forbidden ->
        "Check user permissions and authentication. Verify actor has required access."

      Ash.Error.Invalid ->
        "Validate input data matches expected schema. Check required fields."

      Ecto.QueryError ->
        "Database query error. Check query syntax and database connection."

      DBConnection.ConnectionError ->
        "Database connection failed. Verify database is running and accessible."

      Jason.DecodeError ->
        "Invalid JSON format. Validate JSON structure and encoding."

      _ ->
        nil
    end
  end

  # Helper function for OpenTelemetry attribute formatting
  defp format_otel_attributes(attributes) when is_list(attributes) do
    attributes
    |> Enum.filter(fn {_k, v} -> v != nil end)
    |> Enum.map(fn {k, v} -> {to_string(k), to_string(v)} end)
  end

  defp format_otel_attributes(attributes) when is_map(attributes) do
    attributes
    |> Map.to_list()
    |> format_otel_attributes()
  end

  defp format_otel_attributes(attributes), do: attributes

  @doc """
  Adds custom attributes to the current span.
  """
  @spec add_span_attributes(any()) :: any()
  def add_span_attributes(attributes) when is_map(attributes) do
    case :otel_tracer.current_span_ctx() do
      :undefined ->
        :ok

      _ ->
        formatted_attrs =
          attributes
          |> Enum.filter(fn {_, v} -> ObservabilityHelpers.basic_type?(v) end)
          |> Enum.map(fn {k, v} -> {to_string(k), to_string(v)} end)

        if Code.ensure_loaded?(OpenTelemetry) do
          OpenTelemetry.Tracer.set_attributes(format_otel_attributes(formatted_attrs))
        else
          :ok
        end
    end
  end

  @doc """
  Adds an __event to the current span.
  """
  @spec add_span_event(any(), any()) :: any()
  def add_span_event(name, attributes \\ %{}) do
    case :otel_tracer.current_span_ctx() do
      :undefined ->
        :ok

      _ ->
        if Code.ensure_loaded?(OpenTelemetry) do
          OpenTelemetry.Tracer.add_event(name, attributes)
        else
          :ok
        end
    end
  end

  @doc """
  Returns the current OpenTelemetry span context, or :undefined if none is active.
  """
  @spec get_current_span() :: term()
  def get_current_span do
    try do
      :otel_tracer.current_span_ctx()
    rescue
      _ -> :undefined
    end
  end

  @doc """
  Starts a new OpenTelemetry span with the given name and attributes.

  Returns a span context map that can be passed to `end_span/1` and `record_error/2`.
  Falls back to a lightweight local span if OTEL is not available.

  ## STAMP: SC-OBS-071 (OTEL modules), SC-PRF-050 (< 50ms)
  """
  @spec start_span(String.t() | atom(), map()) :: map()
  def start_span(name, attributes \\ %{}) do
    span_name = to_string(name)

    try do
      otel_attrs =
        Enum.flat_map(attributes, fn
          {k, v} when is_binary(v) or is_number(v) or is_boolean(v) or is_atom(v) ->
            [{to_string(k), v}]

          _ ->
            []
        end)

      span_ctx =
        OpenTelemetry.Tracer.start_span(span_name, %{attributes: otel_attrs})

      %{
        span_ctx: span_ctx,
        name: span_name,
        start_time: System.monotonic_time(:microsecond),
        otel: true
      }
    rescue
      _ ->
        %{
          span_id: :rand.uniform(1_000_000),
          name: span_name,
          attributes: attributes,
          start_time: System.monotonic_time(:microsecond),
          otel: false
        }
    end
  end

  @doc """
  Ends a span previously started with `start_span/2`.

  Emits a telemetry event with the span duration and sets the OTEL span status to `:ok`.
  """
  @spec end_span(map()) :: :ok
  def end_span(%{otel: true, span_ctx: span_ctx, name: name, start_time: t0}) do
    duration_us = System.monotonic_time(:microsecond) - t0

    try do
      _ = span_ctx
      OpenTelemetry.Tracer.set_status(:ok)
      OpenTelemetry.Tracer.end_span()
    rescue
      _ -> :ok
    end

    :telemetry.execute(
      [:indrajaal, :tracing, :span_end],
      %{duration_us: duration_us},
      %{name: name}
    )

    :ok
  end

  def end_span(%{otel: false, name: name, start_time: t0}) do
    duration_us = System.monotonic_time(:microsecond) - t0

    :telemetry.execute(
      [:indrajaal, :tracing, :span_end],
      %{duration_us: duration_us},
      %{name: name}
    )

    :ok
  end

  def end_span(_span), do: :ok

  @doc """
  Records an error on an active span.

  Sets the span status to `:error` and adds an exception event with the error details.
  """
  @spec record_error(map(), term()) :: :ok
  def record_error(%{otel: true, span_ctx: span_ctx, name: name}, error) do
    error_str = inspect(error)

    try do
      _ = span_ctx
      OpenTelemetry.Tracer.set_status(:error, error_str)

      OpenTelemetry.Tracer.add_event("exception", %{
        "exception.message" => error_str,
        "exception.type" => "runtime"
      })
    rescue
      _ -> :ok
    end

    :telemetry.execute(
      [:indrajaal, :tracing, :span_error],
      %{count: 1},
      %{name: name, error: error_str}
    )

    :ok
  end

  def record_error(%{otel: false, name: name}, error) do
    :telemetry.execute(
      [:indrajaal, :tracing, :span_error],
      %{count: 1},
      %{name: name, error: inspect(error)}
    )

    :ok
  end

  def record_error(_span, _error), do: :ok
end
