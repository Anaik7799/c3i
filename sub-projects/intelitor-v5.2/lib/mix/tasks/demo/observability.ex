defmodule Mix.Tasks.Demo.Observability do
  @moduledoc """
  Demonstrates the comprehensive observability features implemented in Indrajaal.

  This task showcases OpenTelemetry tracing, structured logging, error handling,
  and telemetry __events across all domains.

  Usage: mix demo.observability
  """

  use Mix.Task
  require Logger

  @shortdoc "Demonstrates observability features"

  @spec run(any()) :: any()
  def run(_args) do
    Mix.Task.run("app.start")

    Logger.info("[LAUNCH] Starting Indrajaal Observability Demonstration")

    # Demo 1: OpenTelemetry Tracing
    demonstrate_opentelemetry_tracing()

    # Demo 2: Structured Logging
    demonstrate_structured_logging()

    # Demo 3: Error Handling with Splode
    demonstrate_error_handling()

    # Demo 4: Telemetry Events
    demonstrate_telemetry_events()

    # Demo 5: Security Event Logging
    demonstrate_security_logging()

    # Demo 6: Business Operation Tracing
    demonstrate_business_operations()

    # Demo 7: Device Operations
    demonstrate_device_operations()

    # Demo 8: Alarm System Monitoring
    demonstrate_alarm_monitoring()

    Logger.info("[SUCCESS] Observability demonstration completed!")
  end

  @spec demonstrate_opentelemetry_tracing() :: any()
  defp demonstrate_opentelemetry_tracing do
    Logger.info("[STATS] Demo 1: OpenTelemetry Tracing")

    # Manual span creation with rich attributes
    Indrajaal.Tracing.with_span(
      "demo.tenant_operations",
      %{
        "demo.type" => "observability_showcase",
        "demo.user" => "demo_user",
        "demo.tenant" => "demo_tenant"
      },
      fn ->
        # Nested business operation span
        Indrajaal.Tracing.trace_business_operation(
          "tenant.lifecycle_demo",
          %{
            operation_type: "demonstration",
            business_impact: :high
          },
          fn ->
            Logger.info("Creating demo tenant with full tracing",
              trace_id: get_current_trace_id(),
              operation: "tenant.create",
              business_context: "observability_demo"
            )

            # Simulate tenant creation delay
            Process.sleep(100)

            # Nested security operation
            Indrajaal.Tracing.trace_security_operation(
              "tenant.security_check",
              %{
                actor_id: "demo_user",
                security_level: "admin",
                ip_address: "192.168.1.100"
              },
              fn ->
                Logger.info("Security validation completed for demo tenant")
                Process.sleep(50)
              end
            )

            Logger.info("Demo tenant creation completed with full trace __context")
          end
        )
      end
    )

    Logger.info("[SUCCESS] OpenTelemetry tracing demonstration completed")
  end

  @spec demonstrate_structured_logging() :: any()
  defp demonstrate_structured_logging do
    Logger.info("Demo 2 - Structured Logging")

    # Security __event logging
    Indrajaal.Logging.log_security_event("demo_access_attempt", :high, %{
      actor_id: "demo_user_123",
      tenant_id: "demo_tenant_456",
      resource: "sensitive_configuration",
      action: "read",
      ip_address: "192.168.1.100",
      __user_agent: "Mozilla / 5.0 (Demo Browser)",
      session_id: "session_abc123"
    })

    # Authentication __event logging
    Indrajaal.Logging.log_auth_event("login_attempt", :success, %{
      user_id: "demo_user_123",
      email: "demo@example.com",
      ip_address: "192.168.1.100",
      __user_agent: "Demo Client",
      mfa_method: "totp",
      session_id: "session_abc123",
      tenant_id: "demo_tenant_456"
    })

    # Business __event logging
    Indrajaal.Logging.log_business_event("subscription_upgrade", :high, %{
      resource: "subscription",
      resource_id: "sub_demo_789",
      actor_id: "demo_user_123",
      tenant_id: "demo_tenant_456",
      duration_ms: 250,
      impact: "revenue_increase"
    })

    # System __event logging
    Indrajaal.Logging.log_system_event("database", "performance_alert", %{
      severity: :warn,
      metric_value: 850.5,
      threshold: 500.0,
      memory_usage: 75.2,
      cpu_usage: 45.8
    })

    Logger.info("[SUCCESS] Structured logging demonstration completed")
  end

  @spec demonstrate_error_handling() :: any()
  defp demonstrate_error_handling do
    Logger.info("Demo 3: Error Handling with Splode")

    # Demonstrate different error types
    errors_to_demo = [
      # Security errors
      {Indrajaal.Errors.Forbidden.AccessDenied,
       %{
         resource: "alarm_configuration",
         action: "update",
         actor_id: "demo_user",
         tenant_id: "demo_tenant",
         reason: "insufficient_permissions"
       }},

      # Business errors
      {Indrajaal.Errors.Business.AlarmStateTransitionInvalid,
       %{
         alarm_id: "alarm_demo_123",
         current_state: "triggered",
         __requested_state: "resolved",
         valid_transitions: ["acknowledged", "investigating"]
       }},

      # System errors
      {Indrajaal.Errors.System.DatabaseConnectionError,
       %{
         repo: "Indrajaal.Repo",
         operation: "alarm_query",
         error_details: "connection_timeout",
         retry_count: 3
       }},

      # External service errors
      {Indrajaal.Errors.External.EmailDeliveryFailed,
       %{
         recipient: "admin@demo.com",
         subject: "Critical Alarm Notification",
         provider: "SendGrid",
         error_code: "RATE_LIMIT_EXCEEDED",
         bounce_reason: "quota_exceeded"
       }}
    ]

    Enum.each(errors_to_demo, fn {error_module, fields} ->
      try do
        error = struct(error_module, fields)

        # Emit error telemetry (this is what would happen in real error scenarios
        Indrajaal.Errors.emit_error_telemetry(error, %{
          demo_context: "observability_showcase",
          error_demonstration: true
        })

        Logger.info("Demonstrated error type: #{error_module}",
          error_message: Exception.message(error),
          error_fields: Map.from_struct(error)
        )
      rescue
        e ->
          Logger.warning("Could not demonstrate error #{error_module}: #{Exception.message(e)}")
      end
    end)

    Logger.info("[SUCCESS] Error handling demonstration completed")
  end

  @spec demonstrate_telemetry_events() :: any()
  defp demonstrate_telemetry_events do
    Logger.info("Demo 4: Telemetry Events")

    # Business telemetry __events
    telemetry_demos = [
      # Tenant operations
      {[:indrajaal, :tenant, :registered], %{count: 1},
       %{
         tenant_id: "demo_tenant_123",
         organization_id: "demo_org_456",
         subscription_tier: :enterprise
       }},

      # Security __events
      {[:indrajaal, :security, :event], %{count: 1, severity_level: 3},
       %{
         __event_type: "unauthorized_access_attempt",
         actor_id: "demo_user_789",
         resource: "admin_panel"
       }},

      # Device operations
      {[:indrajaal, :device, :heartbeat], %{count: 1, uptime_minutes: 1440},
       %{
         device_id: "camera_demo_001",
         device_type: "security_camera",
         status: "active"
       }},

      # Alarm __events
      {[:indrajaal, :alarm, :triggered], %{count: 1, severity_level: 4, priority: 1},
       %{
         alarm_id: "alarm_demo_critical",
         __event_type: "intrusion",
         site_id: "site_demo_hq"
       }},

      # Business metrics
      {[:indrajaal, :business, :operation], %{count: 1, importance_level: 4, duration: 150},
       %{
         operation: "compliance_assessment",
         framework: "ISO_27001"
       }}
    ]

    Enum.each(telemetry_demos, fn {event_name, measurements, metadata} ->
      :telemetry.execute(event_name, measurements, metadata)

      Logger.info("Emitted telemetry event: #{inspect(event_name)}",
        measurements: measurements,
        metadata: Map.take(metadata, [:event_type, :operation, :device_id, :alarm_id])
      )
    end)

    Logger.info("[SUCCESS] Telemetry events demonstration completed")
  end

  @spec demonstrate_security_logging() :: any()
  defp demonstrate_security_logging do
    Logger.info("Demo 5: Security Event Logging")

    # Access control __events
    Indrajaal.Logging.log_access_event("demo_user_456", "door_access", :granted, %{
      location_id: "entrance_lobby",
      reader_id: "reader_001",
      access_level: "employee",
      credential_type: "rfid_badge",
      time_schedule: "business_hours",
      tenant_id: "demo_tenant_789"
    })

    Indrajaal.Logging.log_access_event("demo_user_999", "door_access", :denied, %{
      location_id: "server_room",
      reader_id: "reader_secure_001",
      access_level: "admin_required",
      credential_type: "rfid_badge",
      denial_reason: "insufficient_clearance",
      tenant_id: "demo_tenant_789"
    })

    # Compliance __events
    Indrajaal.Logging.log_compliance_event("policy_violation", "GDPR", %{
      severity: :high,
      __requirement_id: "article_32",
      violation_type: "data_access_without_authorization",
      remediation_required: true,
      auditor_id: "compliance_officer_001",
      tenant_id: "demo_tenant_789"
    })

    Logger.info("[SUCCESS] Security logging demonstration completed")
  end

  @spec demonstrate_business_operations() :: any()
  defp demonstrate_business_operations do
    Logger.info("Demo 6: Business Operation Tracing")

    # Simulate complex business operation with nested tracing
    Indrajaal.Tracing.trace_business_operation(
      "subscription_lifecycle",
      %{
        tenant_id: "demo_tenant_enterprise",
        operation_type: "upgrade",
        business_impact: :critical
      },
      fn ->
        Logger.info("Starting subscription upgrade process")

        # Step 1: Validate current subscription
        Indrajaal.Tracing.with_span(
          "subscription.validate",
          %{
            "subscription.current_tier" => "professional",
            "subscription.target_tier" => "enterprise"
          },
          fn ->
            Process.sleep(50)
            Logger.info("Subscription validation completed")
          end
        )

        # Step 2: Process payment
        Indrajaal.Tracing.with_span(
          "payment.process",
          %{
            "payment.amount" => "999.00",
            "payment.currency" => "USD",
            "payment.method" => "credit_card"
          },
          fn ->
            Process.sleep(100)
            Logger.info("Payment processing completed")
          end
        )

        # Step 3: Update entitlements
        Indrajaal.Tracing.with_span(
          "entitlements.update",
          %{
            "entitlements.feature_count" => "15",
            "entitlements.__user_limit" => "unlimited"
          },
          fn ->
            Process.sleep(75)
            Logger.info("Entitlements updated successfully")
          end
        )

        # Emit business telemetry
        :telemetry.execute(
          [:indrajaal, :subscription, :upgraded],
          %{count: 1, revenue_impact: 999.00},
          %{
            tenant_id: "demo_tenant_enterprise",
            from_tier: "professional",
            to_tier: "enterprise"
          }
        )

        Logger.info("Subscription upgrade completed successfully")
      end
    )

    Logger.info("[SUCCESS] Business operations demonstration completed")
  end

  @spec demonstrate_device_operations() :: any()
  defp demonstrate_device_operations do
    Logger.info("Demo 7: Device Operations")

    # Device heartbeat with tracing
    Indrajaal.Tracing.trace_device_operation(
      "camera_demo_hq_001",
      "heartbeat",
      %{
        device_type: "security_camera",
        location: "main_entrance",
        status: "active",
        firmware_version: "v2.1.4"
      },
      fn ->
        Indrajaal.Logging.log_device_event("camera_demo_hq_001", "heartbeat_received", %{
          device_type: "security_camera",
          device_name: "Main Entrance Camera",
          location: "building_a_entrance",
          status: "active",
          firmware_version: "v2.1.4",
          last_heartbeat: DateTime.utc_now(),
          tenant_id: "demo_tenant_789"
        })

        Process.sleep(25)
      end
    )

    # Device configuration change
    Indrajaal.Tracing.trace_device_operation(
      "sensor_demo_002",
      "configuration_update",
      %{
        device_type: "motion_sensor",
        location: "corridor_b",
        status: "active"
      },
      fn ->
        Indrajaal.Logging.log_device_event("sensor_demo_002", "configuration_changed", %{
          device_type: "motion_sensor",
          device_name: "Corridor B Motion Sensor",
          location: "building_a_corridor_b",
          status: "active",
          tenant_id: "demo_tenant_789"
        })

        Process.sleep(30)
      end
    )

    Logger.info("[SUCCESS] Device operations demonstration completed")
  end

  @spec demonstrate_alarm_monitoring() :: any()
  defp demonstrate_alarm_monitoring do
    Logger.info("Demo 8: Alarm System Monitoring")

    # Critical alarm with full tracing
    Indrajaal.Tracing.trace_alarm_operation(
      "alarm_demo_critical_001",
      "triggered",
      %{
        incident_type: "intrusion",
        priority: 1,
        source: "motion_sensor_lobby"
      },
      fn ->
        Indrajaal.Logging.log_alarm_event("alarm_demo_critical_001", "triggered", %{
          severity: :critical,
          priority: 1,
          incident_type: "intrusion",
          device_id: "motion_sensor_lobby_001",
          site_id: "site_demo_headquarters",
          zone_id: "zone_lobby_secure",
          state: "triggered",
          tenant_id: "demo_tenant_789"
        })

        Process.sleep(50)

        # Alarm acknowledgment
        Indrajaal.Tracing.trace_alarm_operation(
          "alarm_demo_critical_001",
          "acknowledged",
          %{
            incident_type: "intrusion",
            priority: 1,
            response_time: 45
          },
          fn ->
            Indrajaal.Logging.log_alarm_event("alarm_demo_critical_001", "acknowledged", %{
              severity: :critical,
              priority: 1,
              incident_type: "intrusion",
              state: "acknowledged",
              response_time: 45,
              actor_id: "security_officer_001",
              tenant_id: "demo_tenant_789"
            })

            Process.sleep(25)
          end
        )

        # Video verification
        Indrajaal.Logging.log_video_event("camera_lobby_main", "verification_requested", %{
          stream_type: "live",
          resolution: "1080p",
          codec: "h264",
          analytics_result: "motion_detected",
          tenant_id: "demo_tenant_789"
        })
      end
    )

    Logger.info("[SUCCESS] Alarm monitoring demonstration completed")
  end

  @spec get_current_trace_id() :: any()
  def get_current_trace_id() do
    case :otel_tracer.current_span_ctx() do
      :undefined ->
        "no_trace"

      span_ctx ->
        trace_result =
          if Code.ensure_loaded?(OpenTelemetry) do
            OpenTelemetry.Span.trace_id(span_ctx)
          else
            :ok
          end

        trace_result |> to_string()
    end
  rescue
    _ -> "trace_unavailable"
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
