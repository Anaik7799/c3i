defmodule Indrajaal.Alarms.AlarmTracingTest do
  @moduledoc """
  Comprehensive tracing tests for alarm and alarm event functionality.

  This test suite verifies OpenTelemetry integration, structured logging,
  telemetry events, and observability features for the alarm system.

  Tests cover:
  - Alarm lifecycle tracing (trigger -> acknowledge -> resolve)
  - Telemetry event emission
  - Structured logging validation
  - Error handling and tracing
  - Performance monitoring
  - Business metrics collection
  - Security event logging
  """

  use Indrajaal.DataCase
  use ExUnit.Case, async: false
  use Indrajaal.Ultimate.TestConsolidation
  # import Telemetry.TestHelper - Module not available

  alias Indrajaal.Accounts.User
  alias Indrajaal.Alarms.AlarmEvent
  alias Indrajaal.Core.{Tenant, Organization}
  alias Indrajaal.Devices.{Device, DeviceType}
  alias Indrajaal.Sites.Site

  @moduletag :tracing
  @moduletag :observability

  setup do
    # Setup OpenTelemetry test tracer
    :opentelemetry.set_default_tracer(:test_tracer)

    # Clear any existing telemetry handlers
    :telemetry.list_handlers()[:indrajaal] |> Enum.each(&:telemetry.detach(&1.id))

    # Start collecting telemetry events for testing
    telemetry_pid =
      start_telemetry_collector([
        [:indrajaal, :alarm, :triggered],
        [:indrajaal, :alarm, :acknowledged],
        [:indrajaal, :alarm, :resolved],
        [:indrajaal, :alarm, :escalated],
        [:indrajaal, :business, :operation],
        [:indrajaal, :security, :event],
        [:indrajaal, :error, :occurred],
        [:indrajaal, :metrics, :ash_operation]
      ])

    # Setup test data
    tenant = insert(:tenant, name: "Tracing Test Tenant")
    organization = insert(:organization, tenant: tenant, name: "Test Security Corp")

    site =
      insert(:site,
        tenant: tenant,
        organization: organization,
        name: "Test Facility"
      )

    device_type =
      insert(:device_type,
        tenant: tenant,
        name: "Security Camera",
        category: :camera,
        manufacturer: "TestCorp",
        model: "TC - 2000"
      )

    device =
      insert(:device,
        tenant: tenant,
        site: site,
        device_type: device_type,
        name: "Main Entrance Camera",
        serial_number: "CAM - 001"
      )

    user =
      insert(:user,
        tenant: tenant,
        email: "security.officer@test.com",
        role: "security_officer"
      )

    {:ok,
     tenant: tenant,
     organization: organization,
     site: site,
     device: device,
     device_type: device_type,
     user: user,
     telemetry_pid: telemetry_pid}
  end

  describe "Alarm Lifecycle Tracing" do
    test "traces complete alarm lifecycle with OpenTelemetry", context do
      %{tenant: tenant, device: device, user: user, telemetry_pid: telemetry_pid} = context

      # Test alarm creation with tracing
      {alarm, traces} =
        with_trace_collection(fn ->
          create_test_alarm(tenant, device, %{
            event_type: :intrusion,
            severity: :high,
            description: "Motion detected in restricted area",
            location_details: "Main entrance corridor"
          })
        end)

      # Verify alarm creation span
      creation_span = find_span(traces, "alarm.triggered")
      assert creation_span != nil
      assert span_attribute(creation_span, "alarm.id") == alarm.id
      assert span_attribute(creation_span, "alarm.severity") == "high"
      assert span_attribute(creation_span, "alarm.event_type") == "intrusion"
      assert span_attribute(creation_span, "operation.type") == "alarm"

      # Test alarm acknowledgment with tracing
      {ack_alarm, ack_traces} =
        with_trace_collection(fn ->
          acknowledge_test_alarm(alarm, user, %{
            notes: "Investigating motion detection alert"
          })
        end)

      # Verify acknowledgment span
      ack_span = find_span(ack_traces, "alarm.acknowledged")
      assert ack_span != nil
      assert span_attribute(ack_span, "alarm.id") == alarm.id
      assert span_attribute(ack_span, "acknowledged_by") == user.id
      assert span_attribute(ack_span, "operation.type") == "alarm"

      # Test alarm resolution with tracing
      {resolved_alarm, resolve_traces} =
        with_trace_collection(fn ->
          resolve_test_alarm(ack_alarm, user, %{
            resolution: "False alarm - authorized maintenance staff",
            resolution_category: "false_positive"
          })
        end)

      # Verify resolution span
      resolve_span = find_span(resolve_traces, "alarm.resolved")
      assert resolve_span != nil
      assert span_attribute(resolve_span, "alarm.id") == alarm.id
      assert span_attribute(resolve_span, "resolved_by") == user.id

      assert span_attribute(
               resolve_span,
               "resolution_category"
             ) == "false_positive"

      # Verify telemetry events were emitted
      events = get_telemetry_events(telemetry_pid)

      # Check alarm triggered event
      triggered_event =
        find_telemetry_event(
          events,
          [:indrajaal, :alarm, :triggered]
        )

      assert triggered_event != nil
      assert triggered_event.measurements.count == 1
      # high = 3
      assert triggered_event.measurements.severity_level == 3
      assert triggered_event.metadata.alarm_id == alarm.id
      assert triggered_event.metadata.event_type == :intrusion

      # Check alarm acknowledged event
      ack_event =
        find_telemetry_event(
          events,
          [:indrajaal, :alarm, :acknowledged]
        )

      assert ack_event != nil
      assert ack_event.measurements.count == 1
      assert ack_event.metadata.alarm_id == alarm.id
      assert ack_event.metadata.acknowledged_by == user.id

      # Check alarm resolved event
      resolved_event =
        find_telemetry_event(
          events,
          [:indrajaal, :alarm, :resolved]
        )

      assert resolved_event != nil
      assert resolved_event.measurements.count == 1
      assert resolved_event.metadata.alarm_id == alarm.id
      assert resolved_event.metadata.resolved_by == user.id
    end

    test "traces alarm escalation with business metrics", context do
      %{tenant: tenant, device: device, user: user, telemetry_pid: telemetry_pid} = context

      # Create medium priority alarm
      alarm =
        create_test_alarm(tenant, device, %{
          event_type: :motion,
          severity: :medium,
          description: "Motion detected in office area"
        })

      # Trace escalation process
      {escalated_alarm, traces} =
        with_trace_collection(fn ->
          escalate_test_alarm(alarm, %{
            new_severity: :high,
            escalation_reason: "No response within 30 minutes - SLA violation",
            escalated_by: user.id
          })
        end)

      # Verify escalation span
      escalation_span = find_span(traces, "alarm.escalated")
      assert escalation_span != nil
      assert span_attribute(escalation_span, "alarm.id") == alarm.id
      assert span_attribute(escalation_span, "from_severity") == "medium"
      assert span_attribute(escalation_span, "to_severity") == "high"

      assert span_attribute(escalation_span, "escalation_reason") ==
               "No response within 30 minutes - SLA violation"

      # Verify business operation span
      business_span = find_span(traces, "business.alarm_escalation")
      assert business_span != nil
      assert span_attribute(business_span, "operation.type") == "business"
      assert span_attribute(business_span, "business_impact") == "high"

      # Check telemetry events
      events = get_telemetry_events(telemetry_pid)

      escalation_event =
        find_telemetry_event(
          events,
          [:indrajaal, :alarm, :escalated]
        )

      assert escalation_event != nil
      assert escalation_event.measurements.count == 1
      assert escalation_event.metadata.alarm_id == alarm.id
      assert escalation_event.metadata.escalation_reason =~ "SLA violation"
    end
  end

  describe "Error Handling and Tracing" do
    test "traces alarm state transition errors", context do
      %{tenant: tenant, device: device, telemetry_pid: telemetry_pid} = context

      # Create resolved alarm
      alarm =
        create_test_alarm(tenant, device, %{
          event_type: :test,
          severity: :low,
          description: "Test alarm for error handling"
        })

      resolved_alarm =
        resolve_test_alarm(alarm, insert(:user, tenant: tenant), %{
          resolution: "Test completed"
        })

      # Try to acknowledge already resolved alarm (should fail)
      {result, traces} =
        with_trace_collection(fn ->
          try do
            acknowledge_test_alarm(resolved_alarm, insert(:user, tenant: tenant), %{
              notes: "This should fail"
            })
          rescue
            error -> {:error, error}
          end
        end)

      # Verify error was caught
      assert match?({:error, _}, result)

      # Check error tracing
      error_span = find_span_by_attribute(traces, "error.occurred", true)
      assert error_span != nil
      assert span_attribute(error_span, "operation.success") == false

      # Check error telemetry
      events = get_telemetry_events(telemetry_pid)

      error_event =
        find_telemetry_event(
          events,
          [:indrajaal, :error, :occurred]
        )

      assert error_event != nil
      assert error_event.metadata.error_class =~ "AlarmStateTransitionInvalid"
    end

    test "traces invalid alarm creation with detailed error context", context do
      %{tenant: tenant, telemetry_pid: telemetry_pid} = context

      # Attempt to create alarm with invalid data
      {result, traces} =
        with_trace_collection(fn ->
          try do
            AlarmEvent.create(%{
              # Missing required fields
              tenant_id: tenant.id,
              description: "Invalid alarm test"
              # Missing: event_type, severity, source_type, source_id
            })
          rescue
            error -> {:error, error}
          catch
            :error, reason -> {:error, reason}
          end
        end)

      # Verify creation failed
      assert match?({:error, _}, result)

      # Check validation error tracing
      validation_span =
        find_span_by_attribute(traces, "validation.errors", fn count -> count > 0 end)

      assert validation_span != nil

      # Check error telemetry
      events = get_telemetry_events(telemetry_pid)

      error_event =
        find_telemetry_event(
          events,
          [:indrajaal, :error, :occurred]
        )

      assert error_event != nil
    end
  end

  describe "Performance and Metrics Tracing" do
    test "traces alarm query performance", context do
      %{tenant: tenant, device: device, telemetry_pid: telemetry_pid} = context

      # Create multiple alarms for performance testing
      alarms =
        create_multiple_test_alarms(tenant, device, 10, %{
          severities: [:low, :medium, :high, :critical],
          event_types: [:motion, :door_open, :intrusion, :maintenance]
        })

      # Trace alarm listing with filters
      {results, traces} =
        with_trace_collection(fn ->
          query_alarms_with_filters(tenant, %{
            severity: [:high, :critical],
            status: [:new, :acknowledged],
            limit: 5
          })
        end)

      # Verify query results
      assert length(results) <= 5
      assert Enum.all?(results, &(&1.severity in [:high, :critical]))

      # Check query performance span
      query_span = find_span(traces, "ash_operation.alarm_event.read")
      assert query_span != nil
      assert span_attribute(query_span, "ash.resource") == "alarm_event"
      assert span_attribute(query_span, "ash.action") == "read"
      assert span_attribute(query_span, "query.filter_count") > 0

      # Check performance metrics
      events = get_telemetry_events(telemetry_pid)

      metrics_event =
        find_telemetry_event(
          events,
          [:indrajaal, :metrics, :ash_operation]
        )

      assert metrics_event != nil
      assert metrics_event.measurements.duration > 0
      assert metrics_event.metadata.resource == "alarm_event"
    end

    test "traces bulk alarm processing performance", context do
      %{tenant: tenant, device: device, telemetry_pid: telemetry_pid} = context

      # Trace bulk alarm creation
      {alarms, traces} =
        with_trace_collection(fn ->
          create_bulk_test_alarms(tenant, device, 50)
        end)

      # Verify bulk operation
      assert length(alarms) == 50

      # Check bulk operation span
      bulk_span = find_span(traces, "business.bulk_alarm_processing")
      assert bulk_span != nil
      assert span_attribute(bulk_span, "bulk.operation_count") == 50
      assert span_attribute(bulk_span, "operation.type") == "business"

      # Verify individual alarm creation spans
      creation_spans = filter_spans(traces, "alarm.triggered")
      assert length(creation_spans) == 50

      # Check performance metrics
      events = get_telemetry_events(telemetry_pid)

      business_events =
        filter_telemetry_events(
          events,
          [:indrajaal, :business, :operation]
        )

      assert length(business_events) >= 1

      bulk_event =
        Enum.find(business_events, &(&1.metadata.operation == "bulk_alarm_processing"))

      assert bulk_event != nil
      assert bulk_event.measurements.count == 50
    end
  end

  describe "Security and Audit Tracing" do
    test "traces security related alarm events with audit trail", context do
      %{tenant: tenant, device: device, user: user, telemetry_pid: telemetry_pid} = context

      # Create security critical alarm
      {alarm, traces} =
        with_trace_collection(fn ->
          create_test_alarm(tenant, device, %{
            event_type: :security_breach,
            severity: :critical,
            description: "Unauthorized access attempt detected",
            metadata: %{
              "security_zone" => "high_security",
              "threat_level" => "imminent",
              "requires_immediate_response" => true
            }
          })
        end)

      # Verify security span
      security_span = find_span(traces, "security.critical_alarm")
      assert security_span != nil

      assert span_attribute(
               security_span,
               "security.threat_level"
             ) == "imminent"

      assert span_attribute(security_span, "security.zone") == "high_security"
      assert span_attribute(security_span, "operation.type") == "security"

      # Check security audit span
      audit_span = find_span(traces, "audit.alarm_created")
      assert audit_span != nil
      assert span_attribute(audit_span, "audit.resource") == "alarm_event"
      assert span_attribute(audit_span, "audit.action") == "create"
      assert span_attribute(audit_span, "audit.severity") == "critical"

      # Verify security telemetry
      events = get_telemetry_events(telemetry_pid)

      security_event =
        find_telemetry_event(
          events,
          [:indrajaal, :security, :event]
        )

      assert security_event != nil
      assert security_event.metadata.event_type == "critical_alarm_triggered"
      assert security_event.metadata.threat_level == "imminent"
      # critical = 4
      assert security_event.measurements.severity_level == 4
    end

    test "traces multi tenant alarm access with isolation verification",
         context do
      %{device: device, user: user, telemetry_pid: telemetry_pid} = context

      # Create alarm in tenant 1
      tenant1 = device.tenant

      alarm1 =
        create_test_alarm(tenant1, device, %{
          event_type: :motion,
          severity: :medium,
          description: "Tenant 1 alarm"
        })

      # Create tenant 2 and try to access tenant 1's alarm
      tenant2 = insert(:tenant, name: "Unauthorized Tenant")
      user2 = insert(:user, tenant: tenant2, email: "unauthorized@test.com")

      # Trace unauthorized access attempt
      {result, traces} =
        with_trace_collection(fn ->
          try do
            AlarmEvent.read!(alarm1.id, actor: %{tenant_id: tenant2.id, user_id: user2.id})
          rescue
            error -> {:error, error}
          end
        end)

      # Verify access was denied
      assert match?({:error, _}, result)

      # Check security violation span
      violation_span = find_span(traces, "security.tenant_isolation_violation")
      assert violation_span != nil

      assert span_attribute(violation_span, "security.violation_type") ==
               "unauthorized_cross_tenant_access"

      assert span_attribute(
               violation_span,
               "security.attempted_resource"
             ) == "alarm_event"

      # Check security event telemetry
      events = get_telemetry_events(telemetry_pid)

      security_event =
        find_telemetry_event(
          events,
          [:indrajaal, :security, :event]
        )

      assert security_event != nil
      assert security_event.metadata.event_type == "tenant_isolation_violation"
    end
  end

  describe "Real-time Tracing and Notifications" do
    test "traces real-time alarm notifications with WebSocket events",
         context do
      %{tenant: tenant, device: device, telemetry_pid: telemetry_pid} = context

      # Mock WebSocket connection for testing
      socket_pid = start_mock_websocket()

      # Create critical alarm that should trigger real-time notification
      {alarm, traces} =
        with_trace_collection(fn ->
          create_test_alarm(tenant, device, %{
            event_type: :fire,
            severity: :critical,
            description: "Fire detected in server room",
            requires_immediate_notification: true
          })
        end)

      # Verify real-time notification span
      notification_span = find_span(traces, "notification.real_time")
      assert notification_span != nil
      assert span_attribute(notification_span, "notification.type") == "alarm_triggered"

      assert span_attribute(
               notification_span,
               "notification.channel"
             ) == "websocket"

      assert span_attribute(
               notification_span,
               "notification.priority"
             ) == "critical"

      # Check WebSocket broadcast span
      broadcast_span = find_span(traces, "websocket.broadcast")
      assert broadcast_span != nil
      assert span_attribute(broadcast_span, "websocket.event") == "new_alarm"
      assert span_attribute(broadcast_span, "websocket.recipients_count") > 0

      # Verify notification telemetry
      events = get_telemetry_events(telemetry_pid)

      notification_event =
        find_telemetry_event(
          events,
          [:indrajaal, :notification, :sent]
        )

      assert notification_event != nil
      assert notification_event.metadata.alarm_id == alarm.id
      assert notification_event.metadata.notification_type == "real_time"

      # Cleanup mock WebSocket
      stop_mock_websocket(socket_pid)
    end
  end

  # Helper Functions

  defp create_test_alarm(tenant, device, attrs) do
    default_attrs = %{
      tenant_id: tenant.id,
      site_id: device.site_id,
      device_id: device.id,
      source_type: :device,
      source_id: device.id,
      event_type: :motion,
      severity: :medium,
      description: "Test alarm"
    }

    AlarmEvent.create!(Map.merge(default_attrs, attrs))
  end

  defp acknowledge_test_alarm(alarm, user, attrs \\ %{}) do
    default_attrs = %{
      acknowledged_by: user.id,
      notes: "Alarm acknowledged for testing"
    }

    AlarmEvent.acknowledge!(alarm, Map.merge(default_attrs, attrs))
  end

  defp resolve_test_alarm(alarm, user, attrs \\ %{}) do
    default_attrs = %{
      resolved_by: user.id,
      resolution: "Test alarm resolved",
      resolution_category: "test"
    }

    AlarmEvent.resolve!(alarm, Map.merge(default_attrs, attrs))
  end

  defp escalate_test_alarm(alarm, attrs) do
    AlarmEvent.escalate!(alarm, attrs)
  end

  defp create_multiple_test_alarms(tenant, device, count, options \\ %{}) do
    severities = options[:severities] || [:medium]
    event_types = options[:event_types] || [:motion]

    1..count
    |> Enum.map(fn i ->
      severity = Enum.random(severities)
      event_type = Enum.random(event_types)

      create_test_alarm(tenant, device, %{
        event_type: event_type,
        severity: severity,
        description: "Test alarm #{i}"
      })
    end)
  end

  defp create_bulk_test_alarms(tenant, device, count) do
    Indrajaal.Tracing.trace_business_operation(
      "bulk_alarm_processing",
      %{
        tenant_id: tenant.id,
        operation_count: count
      },
      fn ->
        create_multiple_test_alarms(tenant, device, count)
      end
    )
  end

  defp query_alarms_with_filters(tenant, filters) do
    AlarmEvent.read!(
      actor: %{tenant_id: tenant.id},
      filter: filters
    )
  end

  defp with_trace_collection(fun) do
    # Start collecting spans
    :otel_batch_processor.force_flush()
    spans_before = get_current_spans()

    # Execute function
    result = fun.()

    # Collect new spans
    :otel_batch_processor.force_flush()
    spans_after = get_current_spans()
    new_spans = spans_after -- spans_before

    {result, new_spans}
  end

  defp get_current_spans do
    # This would interface with your OpenTelemetry test setup
    # For testing, you might use a test exporter that collects spans
    []
  end

  defp find_span(spans, span_name) do
    Enum.find(spans, &(&1.name == span_name))
  end

  defp find_span_by_attribute(spans, attr_name, attr_value) when is_function(attr_value) do
    Enum.find(spans, fn span ->
      case span_attribute(span, attr_name) do
        nil -> false
        value -> attr_value.(value)
      end
    end)
  end

  defp find_span_by_attribute(spans, attr_name, attr_value) do
    Enum.find(spans, &(span_attribute(&1, attr_name) == attr_value))
  end

  defp filter_spans(spans, span_name) do
    Enum.filter(spans, &(&1.name == span_name))
  end

  defp span_attribute(span, attr_name) do
    # Extract attribute from span - this would depend on your test setup
    span.attributes[attr_name]
  end

  defp start_telemetry_collector(event_names) do
    {:ok, pid} = Agent.start_link(fn -> [] end)

    :telemetry.attach_many(
      "test-collector",
      event_names,
      fn event_name, measurements, metadata, _config ->
        Agent.update(pid, fn events ->
          [
            %{
              event: event_name,
              measurements: measurements,
              metadata: metadata,
              timestamp: System.monotonic_time()
            }
            | events
          ]
        end)
      end,
      nil
    )

    pid
  end

  defp get_telemetry_events(pid) do
    Agent.get(pid, & &1)
  end

  defp find_telemetry_event(events, event_name) do
    Enum.find(events, &(&1.event == event_name))
  end

  defp filter_telemetry_events(events, event_name) do
    Enum.filter(events, &(&1.event == event_name))
  end

  defp start_mock_websocket do
    {:ok, pid} = Agent.start_link(fn -> %{broadcasts: []} end)
    pid
  end

  defp stop_mock_websocket(pid) do
    Agent.stop(pid)
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
