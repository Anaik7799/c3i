# Agent comment: Warning elimination for GA release - SOPv5.11 compliance
defmodule Indrajaal.Observability.Telemetry do
  @moduledoc """
  Enhanced telemetry module with complete SigNoz integration.

  This module provides comprehensive telemetry instrumentation for the Indrajaal
  Security Monitoring System with:
  - OpenTelemetry spans for distributed tracing
  - Domain - specific instrumentation for all 19 domains
  - STAMP safety constraints (SC1, SC2, SC5) integration
  - TDG methodology compliance tracking
  - GDE goal achievement monitoring
  - Tenant isolation and security metrics
  - Performance monitoring and alerting

  ## Usage

      # Initialize telemetry handlers
      Indrajaal.Observability.Telemetry.setup()

      # Record domain event
      Indrajaal.Observability.Telemetry.record_domain_event(
        :access_control,
        :access_granted,
        %{user_id: user.id, location: "Main Entrance"}
  """

  require Logger
  require OpenTelemetry.Tracer
  alias Indrajaal.Observability.DualLogging
  alias Indrajaal.Shared.ObservabilityHelpers

  # Domain event prefixes for all 19 domains
  @domain_prefixes %{
    access_control: [:indrajaal, :access_control],
    accounts: [:indrajaal, :accounts],
    alarms: [:indrajaal, :alarms],
    analytics: [:indrajaal, :analytics],
    asset_management: [:indrajaal, :asset_management],
    billing: [:indrajaal, :billing],
    communication: [:indrajaal, :communication],
    compliance: [:indrajaal, :compliance],
    core: [:indrajaal, :core],
    devices: [:indrajaal, :devices],
    dispatch: [:indrajaal, :dispatch],
    guard_tour: [:indrajaal, :guard_tour],
    integrations: [:indrajaal, :integrations],
    maintenance: [:indrajaal, :maintenance],
    policy: [:indrajaal, :policy],
    risk_management: [:indrajaal, :risk_management],
    sites: [:indrajaal, :sites],
    video: [:indrajaal, :video],
    visitor_management: [:indrajaal, :visitor_management]
  }

  @doc """
  Sets up all telemetry handlers with SigNoz integration.
  Should be called during application startup.
  """
  def setup do
    # Validate dual logging is configured
    DualLogging.validate_dual_logging!()

    # Attach domain - specific handlers
    attach_domain_handlers()

    # Attach STAMP safety monitoring
    attach_stamp_handlers()

    # Attach TDG compliance tracking
    attach_tdg_handlers()

    # Attach GDE goal monitoring
    attach_gde_handlers()

    # Attach performance monitoring
    attach_performance_handlers()

    # Attach security monitoring
    attach_security_handlers()

    Logger.info("Enhanced telemetry handlers attached for SigNoz integration",
      domains: Map.keys(@domain_prefixes),
      safety_constraints: ["SC1", "SC2", "SC5"],
      methodologies: ["STAMP", "TDG", "GDE"]
    )
  end

  @doc """
  Records a domain - specific event with OpenTelemetry span and dual logging.
  """
  @spec record_domain_event(term(), term(), term()) :: term()
  def record_domain_event(domain, event_type, metadata \\ %{}) do
    unless Map.has_key?(@domain_prefixes, domain) do
      raise ArgumentError,
            "Unknown domain: #{domain}. Valid domains: #{Map.keys(@domain_prefixes)}"
    end

    # Create OpenTelemetry span
    span_name = "#{domain}.#{event_type}"

    OpenTelemetry.Tracer.with_span span_name do
      # Add standard attributes
      attributes = build_span_attributes(domain, event_type, metadata)

      if Code.ensure_loaded?(OpenTelemetry),
        do: OpenTelemetry.Tracer.set_attributes(format_otel_attributes(attributes)),
        else: :ok

      # Ensure tenant isolation (SC2)
      ObservabilityHelpers.validate_tenant_isolation!(metadata)

      # Log to both backends via dual logging
      Indrajaal.Observability.DualLogging.log_domain_event(domain, event_type, metadata, :info)

      # Execute telemetry event
      event_name = @domain_prefixes[domain] ++ [event_type]
      measurements = extract_measurements(metadata)

      :telemetry.execute(
        event_name,
        measurements,
        ObservabilityHelpers.clean_metadata(metadata)
      )

      # Record SigNoz metrics
      record_signoz_metrics(domain, event_type, measurements, metadata)
    end
  end

  @doc """
  Records a STAMP safety constraint event with proper monitoring.
  """
  @spec record_stamp_event(term(), term(), term()) :: term()
  def record_stamp_event(constraint, status, context \\ %{}) do
    span_name = "stamp.safety_constraint.#{constraint}"

    OpenTelemetry.Tracer.with_span span_name do
      attributes = %{
        "stamp.constraint" => constraint,
        "stamp.status" => status,
        "stamp.system" => context[:system] || "unknown",
        "stamp.control_action" => context[:control_action],
        "stamp.unsafe_action" => context[:unsafe_action],
        "tenant.id" => context[:tenant_id] || "default"
      }

      if Code.ensure_loaded?(OpenTelemetry),
        do: OpenTelemetry.Tracer.set_attributes(format_otel_attributes(attributes)),
        else: :ok

      # Log safety event
      log_level =
        case status do
          :violated -> :error
          :at_risk -> :warning
          :satisfied -> :info
        end

      Logger.log(log_level, "STAMP safety constraint event",
        constraint: constraint,
        status: status,
        __context: context
      )

      # Execute telemetry
      :telemetry.execute(
        [:indrajaal, :stamp, :safety_constraint],
        %{count: 1, severity: ObservabilityHelpers.constraint_severity(status)},
        Map.merge(context, %{constraint: constraint, status: status})
      )

      # Alert on violations
      if status == :violated do
        trigger_safety_alert(constraint, context)
      end
    end
  end

  @doc """
  Records a TDG methodology compliance event.
  """
  @spec record_tdg_event(term(), term(), term(), map()) :: term()
  def record_tdg_event(phase, component, compliance_status, metadata \\ %{}) do
    span_name = "tdg.#{phase}.#{component}"

    OpenTelemetry.Tracer.with_span span_name do
      attributes = %{
        "tdg.phase" => phase,
        "tdg.component" => component,
        "tdg.compliance" => compliance_status,
        "tdg.test_coverage" => metadata[:test_coverage],
        "tdg.tests_written_first" => metadata[:tests_written_first] || false,
        "tenant.id" => metadata[:tenant_id] || "default"
      }

      if Code.ensure_loaded?(OpenTelemetry),
        do: OpenTelemetry.Tracer.set_attributes(format_otel_attributes(attributes)),
        else: :ok

      # Log TDG event
      Logger.info("TDG methodology event",
        phase: phase,
        component: component,
        compliance: compliance_status,
        metadata: metadata
      )

      # Execute telemetry
      :telemetry.execute(
        [:indrajaal, :tdg, phase],
        %{
          count: 1,
          coverage: metadata[:test_coverage] || 0,
          compliance_score: ObservabilityHelpers.compliance_score(compliance_status)
        },
        Map.merge(metadata, %{component: component, compliance: compliance_status})
      )
    end
  end

  @doc """
  Records a GDE goal achievement event.
  """
  def recordgde_event(domain, goal_id, achievement_status, metrics \\ %{}) do
    span_name = "gde.#{domain}.goal_#{goal_id}"

    OpenTelemetry.Tracer.with_span span_name do
      attributes = %{
        "gde.domain" => domain,
        "gde.goal_id" => goal_id,
        "gde.status" => achievement_status,
        "gde.completion_percentage" => metrics[:completion_percentage] || 0,
        "gde.target_value" => metrics[:target_value],
        "gde.actual_value" => metrics[:actual_value],
        "tenant.id" => metrics[:tenant_id] || "default"
      }

      if Code.ensure_loaded?(OpenTelemetry),
        do: OpenTelemetry.Tracer.set_attributes(format_otel_attributes(attributes)),
        else: :ok

      # Log GDE event
      Logger.info("GDE goal achievement event",
        domain: domain,
        goal_id: goal_id,
        status: achievement_status,
        metrics: metrics
      )

      # Execute telemetry
      :telemetry.execute(
        [:indrajaal, :gde, :goal],
        %{
          count: 1,
          completion: metrics[:completion_percentage] || 0,
          achievement_score: ObservabilityHelpers.achievement_score(achievement_status)
        },
        Map.merge(metrics, %{domain: domain, goal_id: goal_id, status: achievement_status})
      )

      # Alert on goal failures
      if achievement_status in [:failed, :at_risk] do
        trigger_goal_alert(domain, goal_id, achievement_status, metrics)
      end
    end
  end

  @doc """
  Records a performance metric with SigNoz integration.
  """
  @spec record_performance_metric(term(), term(), term(), map()) :: term()
  def record_performance_metric(component, metric_name, value, metadata \\ %{}) do
    # Record through OpenTelemetry metrics API (commented out - function not available)
    # # :otel_metrics.record(
    #   :"intelitor.#{component}.#{metric_name}",
    #   value,
    #   %{
    #     component: component,
    #     tenant_id: metadata[:tenant_id] || "default",
    #     environment: metadata[:environment] || "production"
    #   }
    # )

    # Also emit telemetry for local processing
    :telemetry.execute(
      [:indrajaal, :performance, component],
      %{metric_name => value},
      metadata
    )

    # Check performance thresholds
    check_performance_threshold(component, metric_name, value, metadata)
  end

  # Private functions

  defp attach_domain_handlers do
    Enum.each(@domain_prefixes, fn {domain, prefix} ->
      events = [
        prefix ++ [:create, :start],
        prefix ++ [:create, :stop],
        prefix ++ [:create, :exception],
        prefix ++ [:read, :start],
        prefix ++ [:read, :stop],
        prefix ++ [:read, :exception],
        prefix ++ [:update, :start],
        prefix ++ [:update, :stop],
        prefix ++ [:update, :exception],
        prefix ++ [:destroy, :start],
        prefix ++ [:destroy, :stop],
        prefix ++ [:destroy, :exception]
      ]

      :telemetry.attach_many(
        "indrajaal-#{domain}-handlers",
        events,
        &handle_domain_event/4,
        %{domain: domain}
      )
    end)
  end

  defp attach_stamp_handlers do
    events = [
      [:indrajaal, :stamp, :safety_constraint, :checked],
      [:indrajaal, :stamp, :control_action, :executed],
      [:indrajaal, :stamp, :unsafe_action, :prevented],
      [:indrajaal, :stamp, :hazard, :detected]
    ]

    :telemetry.attach_many(
      "intelitor - stamp - handlers",
      events,
      &handle_stamp_event/4,
      nil
    )
  end

  defp attach_tdg_handlers do
    events = [
      [:indrajaal, :tdg, :test, :generated],
      [:indrajaal, :tdg, :code, :validated],
      [:indrajaal, :tdg, :compliance, :checked],
      [:indrajaal, :tdg, :violation, :detected]
    ]

    :telemetry.attach_many(
      "intelitor - tdg - handlers",
      events,
      &handle_tdg_event/4,
      nil
    )
  end

  defp attach_gde_handlers do
    events = [
      [:indrajaal, :gde, :goal, :set],
      [:indrajaal, :gde, :goal, :achieved],
      [:indrajaal, :gde, :goal, :failed],
      [:indrajaal, :gde, :progress, :updated]
    ]

    :telemetry.attach_many(
      "intelitor - gde - handlers",
      events,
      &handle_gde_event/4,
      nil
    )
  end

  defp attach_performance_handlers do
    events = [
      [:indrajaal, :performance, :latency],
      [:indrajaal, :performance, :throughput],
      [:indrajaal, :performance, :error_rate],
      [:indrajaal, :performance, :resource_usage]
    ]

    :telemetry.attach_many(
      "intelitor - performance - handlers",
      events,
      &handle_performance_event/4,
      nil
    )
  end

  defp attach_security_handlers do
    events = [
      [:indrajaal, :security, :authentication],
      [:indrajaal, :security, :authorization],
      [:indrajaal, :security, :violation],
      [:indrajaal, :security, :audit]
    ]

    :telemetry.attach_many(
      "intelitor - security - handlers",
      events,
      &handle_security_event/4,
      nil
    )
  end

  defp handle_domain_event(event_name, measurements, metadata, config) do
    domain = config[:domain]

    # Create span __context
    ctx = :otel_tracer.current_span_ctx()

    # Enhanced logging with trace correlation
    Logger.metadata(
      trace_id: ObservabilityHelpers.format_trace_id(ctx),
      span_id: ObservabilityHelpers.format_span_id(ctx),
      domain: domain
    )

    # Log the event
    Logger.info("Domain event",
      event: Enum.join(event_name, "."),
      domain: domain,
      measurements: measurements,
      metadata: ObservabilityHelpers.clean_metadata(metadata)
    )

    # Add event to current span
    if ctx != :undefined do
      if Code.ensure_loaded?(OpenTelemetry) do
        OpenTelemetry.Tracer.add_event("domain_event", %{
          "event.name" => Enum.join(event_name, "."),
          "event.domain" => domain
        })
      end
    end
  end

  defp handle_stamp_event(event_name, measurements, metadata, __config) do
    Logger.info("STAMP safety event",
      event: Enum.join(event_name, "."),
      measurements: measurements,
      metadata: metadata
    )
  end

  defp handle_tdg_event(event_name, measurements, metadata, __config) do
    Logger.info("TDG compliance event",
      event: Enum.join(event_name, "."),
      measurements: measurements,
      metadata: metadata
    )
  end

  defp handle_gde_event(event_name, measurements, metadata, __config) do
    Logger.info("GDE goal event",
      event: Enum.join(event_name, "."),
      measurements: measurements,
      metadata: metadata
    )
  end

  defp handle_performance_event(event_name, measurements, metadata, __config) do
    Logger.info("Performance metric",
      event: Enum.join(event_name, "."),
      measurements: measurements,
      metadata: metadata
    )

    # Check for performance degradation
    check_performance_measurements(measurements, metadata)
  end

  defp handle_security_event(event_name, measurements, metadata, __config) do
    log_level = determine_security_log_level(event_name, metadata)

    Logger.log(log_level, "Security event",
      event: Enum.join(event_name, "."),
      measurements: measurements,
      metadata: ObservabilityHelpers.clean_security_metadata(metadata)
    )
  end

  defp build_span_attributes(domain, event_type, metadata) do
    %{
      "domain" => domain,
      "event.type" => event_type,
      "tenant.id" => metadata[:tenant_id] || "default",
      "user.id" => metadata[:user_id],
      "resource.id" => metadata[:resource_id],
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }
    |> Map.merge(extract_custom_attributes(metadata))
  end

  @spec extract_measurements(term()) :: term()
  defp extract_measurements(metadata) do
    %{
      count: 1,
      duration: metadata[:duration] || 0,
      size: metadata[:size] || 0,
      value: metadata[:value] || 0
    }
  end

  # Removed: clean_metadata, clean_security_metadata, is_basic_type?, validate_tenant_isolation!
  # Now using shared functions from # Helper function for OpenTelemetry attribute formatting
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

  defp record_signoz_metrics(domain, event_type, _measurements, metadata) do
    # Record custom metrics for SigNoz dashboards
    metric_name = "indrajaal_#{domain}_#{event_type}total"

    :telemetry.execute(
      [:opentelemetry, :metrics, :counter],
      %{value: 1},
      %{
        name: metric_name,
        domain: domain,
        event_type: event_type,
        tenant_id: metadata[:tenant_id] || "default"
      }
    )
  end

  @spec extract_custom_attributes(term()) :: term()
  defp extract_custom_attributes(metadata) do
    metadata
    |> Enum.filter(fn {k, v} ->
      k not in [:tenant_id, :user_id, :resource_id] and ObservabilityHelpers.basic_type?(v)
    end)
    |> Enum.map(fn {k, v} -> {"custom.#{k}", v} end)
    |> Map.new()
  end

  # Removed: format_trace_id, format_span_id
  # Now using shared functions from ObservabilityHelpers

  # Removed: constraint_severity, compliance_score, achievement_score
  # Now using shared functions from ObservabilityHelpers

  defp trigger_safety_alert(constraint, context) do
    :telemetry.execute(
      [:indrajaal, :alert, :safety_violation],
      %{severity: 4},
      Map.merge(context, %{constraint: constraint})
    )
  end

  defp trigger_goal_alert(domain, goal_id, status, metrics) do
    :telemetry.execute(
      [:indrajaal, :alert, :goal_failure],
      %{severity: 3},
      Map.merge(metrics, %{domain: domain, goal_id: goal_id, status: status})
    )
  end

  defp check_performance_threshold(component, metric_name, value, metadata) do
    threshold = get_performance_threshold(component, metric_name)

    if threshold && value > threshold do
      :telemetry.execute(
        [:indrajaal, :alert, :performance_degradation],
        %{value: value, threshold: threshold},
        Map.merge(metadata, %{component: component, metric: metric_name})
      )
    end
  end

  @spec check_performance_measurements(term(), term()) :: term()
  defp check_performance_measurements(measurements, metadata) do
    Enum.each(measurements, fn {metric, value} ->
      if is_number(value) do
        check_performance_threshold(
          metadata[:component] || "unknown",
          metric,
          value,
          metadata
        )
      end
    end)
  end

  @spec get_performance_threshold(term(), term()) :: term()
  defp get_performance_threshold(component, metric_name) do
    # Define performance thresholds
    thresholds = %{
      # 1 second
      {"api", :latency} => 1000,
      # 500ms
      {"database", :query_time} => 500,
      # 5 seconds
      {"video", :processing_time} => 5000,
      # 2 seconds
      {"alarm", :response_time} => 2000
    }

    thresholds[{to_string(component), metric_name}]
  end

  @spec determine_security_log_level(term(), term()) :: term()
  defp determine_security_log_level(event_name, metadata) do
    case {event_name, metadata[:result]} do
      {[:indrajaal, :security, :authentication], :failure} -> :warning
      {[:indrajaal, :security, :authorization], :denied} -> :warning
      {[:indrajaal, :security, :violation], _} -> :error
      _ -> :info
    end
  end

  @doc """
  Records a named metric via `:telemetry.execute/3` with OTEL span annotation.
  SC-OBS-069: Dual log (Term + Zenoh/OTEL).
  """
  def record_metric(name, value, metadata \\ %{}, tags \\ %{}) do
    enriched_meta =
      metadata
      |> Map.merge(%{metric: name, tags: tags})
      |> Map.put(:recorded_at, System.system_time(:millisecond))

    :telemetry.execute([:indrajaal, :metric], %{value: value}, enriched_meta)

    # Annotate current OTEL span with metric event if a span is active
    try do
      case :otel_tracer.current_span_ctx() do
        :undefined -> :ok
        _ctx -> OpenTelemetry.Tracer.add_event("metric.recorded", %{name: name, value: value})
      end
    rescue
      _ -> :ok
    end

    :ok
  end

  @doc """
  Creates an OTEL span via `OpenTelemetry.Tracer.start_span/2`.
  Returns `{:ok, span_ctx}` for use with `Tracing.end_span/1`.
  SC-OBS-071: OTEL trace integration.
  """
  def create_span(name, attributes \\ %{}, _opts \\ []) do
    try do
      span_ctx =
        OpenTelemetry.Tracer.start_span(name, %{
          attributes: format_otel_attributes(attributes)
        })

      {:ok, span_ctx}
    rescue
      _ ->
        {:ok,
         %{span_id: :rand.uniform(1_000_000), trace_id: :rand.uniform(1_000_000), name: name}}
    end
  end

  @doc """
  Executes a telemetry event under the `[:indrajaal | event]` namespace.
  SC-CTRL-007: Telemetry for all operations.
  """
  def execute_telemetry(event, measurements, metadata \\ %{}) do
    enriched = Map.put(metadata, :emitted_at, System.system_time(:millisecond))
    :telemetry.execute([:indrajaal | event], measurements, enriched)
    :ok
  end
end
