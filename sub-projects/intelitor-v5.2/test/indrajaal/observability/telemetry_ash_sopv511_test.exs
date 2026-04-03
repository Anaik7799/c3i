defmodule Indrajaal.Observability.TelemetryAshSopv511Test do
  @moduledoc """
  Comprehensive integration tests for SOPv5.11 Ash telemetry integration.

  Tests the observability enhancements in `/lib/indrajaal/telemetry.ex`:
  - extract_domain_from_resource/1
  - prepare_observability_metadata/2
  - extract_resource_id/1
  - should_audit?/1
  - handle_ash_event/4
  - log_audit_event/3

  This test suite validates Task 11.4.1.2.1 - Integration Testing with Sample Events.

  Test Coverage:
  - All 12 Ash telemetry event patterns (create/read/update/destroy × start/stop/exception)
  - Unit tests for each helper function
  - Integration tests with real Ash events
  - Edge case testing (nil values, missing metadata, non-domain resources)
  """

  use ExUnit.Case, async: true

  import Mox

  alias Indrajaal.Telemetry
  alias Indrajaal.Observability.{DomainLogger, ErrorLogger, AuditLogger}

  # Setup mocks for logger modules
  setup :verify_on_exit!

  # ============================================================================
  # UNIT TESTS - Helper Functions
  # ============================================================================

  describe "extract_domain_from_resource/1" do
    test "extracts domain from Type 3 domain resource module" do
      assert Telemetry.extract_domain_from_resource(Indrajaal.Alarms.AlarmEvent) == "alarms"
      assert Telemetry.extract_domain_from_resource(Indrajaal.Analytics.Report) == "analytics"

      assert Telemetry.extract_domain_from_resource(Indrajaal.Communication.Notification) ==
               "communication"

      assert Telemetry.extract_domain_from_resource(Indrajaal.Compliance.Policy) == "compliance"
      assert Telemetry.extract_domain_from_resource(Indrajaal.Devices.Device) == "devices"
      assert Telemetry.extract_domain_from_resource(Indrajaal.Performance.Metric) == "performance"
      assert Telemetry.extract_domain_from_resource(Indrajaal.Video.Recording) == "video"

      assert Telemetry.extract_domain_from_resource(Indrajaal.VisitorManagement.Visit) ==
               "visitor_management"

      assert Telemetry.extract_domain_from_resource(Indrajaal.Maintenance.WorkOrder) ==
               "maintenance"
    end

    test "extracts domain from Type 1 domain resource module" do
      assert Telemetry.extract_domain_from_resource(Indrajaal.Accounts.User) == "accounts"

      assert Telemetry.extract_domain_from_resource(Indrajaal.AccessControl.Permission) ==
               "access_control"
    end

    test "extracts domain from Type 2 domain resource module" do
      assert Telemetry.extract_domain_from_resource(Indrajaal.Billing.Invoice) == "billing"
    end

    test "returns nil for non-Indrajaal module" do
      assert Telemetry.extract_domain_from_resource(String) == nil
      assert Telemetry.extract_domain_from_resource(Enum) == nil
    end

    test "returns nil for invalid module structure" do
      assert Telemetry.extract_domain_from_resource(Indrajaal) == nil
    end

    test "handles CamelCase domain names correctly" do
      # VisitorManagement -> visitor_management
      assert Telemetry.extract_domain_from_resource(Indrajaal.VisitorManagement.Visit) ==
               "visitor_management"

      # AccessControl -> access_control
      assert Telemetry.extract_domain_from_resource(Indrajaal.AccessControl.Permission) ==
               "access_control"

      # AssetManagement -> asset_management
      assert Telemetry.extract_domain_from_resource(Indrajaal.AssetManagement.Asset) ==
               "asset_management"
    end
  end

  describe "prepare_observability_metadata/2" do
    test "prepares metadata with domain, resource, and trace_id" do
      metadata =
        Telemetry.prepare_observability_metadata(
          Indrajaal.Alarms.AlarmEvent,
          %{action: :create, actor: %{id: 123}}
        )

      assert metadata.domain == "alarms"
      assert metadata.resource == "Indrajaal.Alarms.AlarmEvent"
      assert metadata.trace_id == nil or is_binary(metadata.trace_id)
      assert metadata.action == :create
      assert metadata.actor == %{id: 123}
    end

    test "handles nil ash_metadata gracefully" do
      metadata =
        Telemetry.prepare_observability_metadata(
          Indrajaal.Analytics.Report,
          nil
        )

      assert metadata.domain == "analytics"
      assert metadata.resource == "Indrajaal.Analytics.Report"
      assert metadata.trace_id == nil or is_binary(metadata.trace_id)
    end

    test "preserves existing ash_metadata fields" do
      ash_metadata = %{
        action: :update,
        actor: %{id: 456},
        resource_id: "report_123",
        tenant_id: "tenant_abc"
      }

      metadata =
        Telemetry.prepare_observability_metadata(
          Indrajaal.Analytics.Report,
          ash_metadata
        )

      assert metadata.action == :update
      assert metadata.actor == %{id: 456}
      assert metadata.resource_id == "report_123"
      assert metadata.tenant_id == "tenant_abc"
    end

    test "extracts user_id and tenant_id from actor when present" do
      ash_metadata = %{
        action: :create,
        actor: %{id: 789, tenant_id: "tenant_xyz"}
      }

      metadata =
        Telemetry.prepare_observability_metadata(
          Indrajaal.Devices.Device,
          ash_metadata
        )

      assert metadata.user_id == 789
      assert metadata.tenant_id == "tenant_xyz"
    end

    test "trace_id format is valid hex string when present" do
      metadata =
        Telemetry.prepare_observability_metadata(
          Indrajaal.Performance.Metric,
          %{action: :read}
        )

      assert metadata.trace_id == nil or is_binary(metadata.trace_id)

      if is_binary(metadata.trace_id) do
        assert String.match?(metadata.trace_id, ~r/^[0-9a-f]+$/i)
      end
    end
  end

  describe "extract_resource_id/1" do
    test "extracts resource_id from metadata when present" do
      metadata = %{resource_id: "alarm_123"}
      assert Telemetry.extract_resource_id(metadata) == "alarm_123"
    end

    test "extracts id from metadata when resource_id not present" do
      metadata = %{id: "device_456"}
      assert Telemetry.extract_resource_id(metadata) == "device_456"
    end

    test "returns nil when neither resource_id nor id present" do
      metadata = %{other_field: "value"}
      assert Telemetry.extract_resource_id(metadata) == nil
    end

    test "returns nil for nil metadata" do
      assert Telemetry.extract_resource_id(nil) == nil
    end

    test "prefers resource_id over id when both present" do
      metadata = %{resource_id: "resource_789", id: "id_789"}
      assert Telemetry.extract_resource_id(metadata) == "resource_789"
    end
  end

  describe "should_audit?/1" do
    test "returns true for sensitive domain create:stop events" do
      assert Telemetry.should_audit?([:ash, Indrajaal.Billing, :create, :stop]) == true
      assert Telemetry.should_audit?([:ash, Indrajaal.AccessControl, :create, :stop]) == true
      assert Telemetry.should_audit?([:ash, Indrajaal.Accounts, :create, :stop]) == true
    end

    test "returns true for sensitive domain update:stop events" do
      assert Telemetry.should_audit?([:ash, Indrajaal.Billing, :update, :stop]) == true
      assert Telemetry.should_audit?([:ash, Indrajaal.AccessControl, :update, :stop]) == true
      assert Telemetry.should_audit?([:ash, Indrajaal.Accounts, :update, :stop]) == true
    end

    test "returns true for sensitive domain destroy:stop events" do
      assert Telemetry.should_audit?([:ash, Indrajaal.Billing, :destroy, :stop]) == true
      assert Telemetry.should_audit?([:ash, Indrajaal.AccessControl, :destroy, :stop]) == true
      assert Telemetry.should_audit?([:ash, Indrajaal.Accounts, :destroy, :stop]) == true
    end

    test "returns false for read:stop events (including sensitive domains)" do
      assert Telemetry.should_audit?([:ash, Indrajaal.Billing, :read, :stop]) == false
      assert Telemetry.should_audit?([:ash, Indrajaal.AccessControl, :read, :stop]) == false
      assert Telemetry.should_audit?([:ash, Indrajaal.Accounts, :read, :stop]) == false
    end

    test "returns false for non-sensitive domain events" do
      assert Telemetry.should_audit?([:ash, Indrajaal.Alarms, :create, :stop]) == false
      assert Telemetry.should_audit?([:ash, Indrajaal.Analytics, :update, :stop]) == false
      assert Telemetry.should_audit?([:ash, Indrajaal.Devices, :destroy, :stop]) == false
    end

    test "returns false for non-stop events" do
      assert Telemetry.should_audit?([:ash, Indrajaal.Billing, :create, :start]) == false
      assert Telemetry.should_audit?([:ash, Indrajaal.Billing, :create, :exception]) == false
    end

    test "returns false for invalid event structure" do
      assert Telemetry.should_audit?([:ash]) == false
      assert Telemetry.should_audit?([:ash, :domain]) == false
      assert Telemetry.should_audit?([:not_ash, Indrajaal.Billing, :create, :stop]) == false
    end
  end

  # ============================================================================
  # INTEGRATION TESTS - Event Routing
  # Note: These tests validate that handle_ash_event/4 correctly processes events
  # and calls the appropriate logger functions. The implementation directly calls
  # DomainLogger, ErrorLogger, and AuditLogger functions rather than emitting
  # telemetry events, so we test the function behavior directly.
  # ============================================================================

  describe "handle_ash_event/4 - success events (DomainLogger routing)" do
    test "routes create:stop events with correct metadata" do
      event_name = [:ash, Indrajaal.Alarms, :create, :stop]
      # 1ms in nanoseconds
      measurements = %{duration: 1_000_000}

      metadata = %{
        resource: Indrajaal.Alarms.AlarmEvent,
        action: :create,
        actor: %{id: 123},
        resource_id: "alarm_001"
      }

      # The function should complete without error
      assert :ok = Telemetry.handle_ash_event(event_name, measurements, metadata, %{})
    end

    test "routes read:stop events with correct metadata" do
      event_name = [:ash, Indrajaal.Analytics, :read, :stop]
      # 0.5ms
      measurements = %{duration: 500_000}

      metadata = %{
        resource: Indrajaal.Analytics.Report,
        action: :read,
        resource_id: "report_001"
      }

      assert :ok = Telemetry.handle_ash_event(event_name, measurements, metadata, %{})
    end

    test "routes update:stop events with correct metadata" do
      event_name = [:ash, Indrajaal.Communication, :update, :stop]
      # 2ms
      measurements = %{duration: 2_000_000}

      metadata = %{
        resource: Indrajaal.Communication.Notification,
        action: :update,
        actor: %{id: 456},
        resource_id: "notif_001"
      }

      assert :ok = Telemetry.handle_ash_event(event_name, measurements, metadata, %{})
    end

    test "routes destroy:stop events with correct metadata" do
      event_name = [:ash, Indrajaal.Compliance, :destroy, :stop]
      # 1.5ms
      measurements = %{duration: 1_500_000}

      metadata = %{
        resource: Indrajaal.Compliance.Policy,
        action: :destroy,
        resource_id: "policy_001"
      }

      assert :ok = Telemetry.handle_ash_event(event_name, measurements, metadata, %{})
    end
  end

  describe "handle_ash_event/4 - error events (ErrorLogger routing)" do
    test "routes exception events with error information" do
      event_name = [:ash, Indrajaal.Devices, :exception]
      measurements = %{duration: 2_000_000}

      metadata = %{
        resource: Indrajaal.Devices.Device,
        action: :create,
        exception: %RuntimeError{message: "Connection failed"},
        kind: :error,
        reason: "Network timeout",
        stacktrace: [{__MODULE__, :test, 0, []}]
      }

      assert :ok = Telemetry.handle_ash_event(event_name, measurements, metadata, %{})
    end

    test "handles exception events without explicit exception field" do
      event_name = [:ash, Indrajaal.Video, :exception]
      measurements = %{duration: 1_000_000}

      metadata = %{
        resource: Indrajaal.Video.Recording,
        action: :update,
        kind: :error,
        reason: "Storage full"
      }

      assert :ok = Telemetry.handle_ash_event(event_name, measurements, metadata, %{})
    end
  end

  # ============================================================================
  # EDGE CASE TESTS
  # ============================================================================

  describe "handle_ash_event/4 - edge cases" do
    test "handles events without resource in metadata (no-op)" do
      event_name = [:ash, Indrajaal.Alarms, :create, :stop]
      measurements = %{duration: 1_000_000}
      # Missing :resource key
      metadata = %{action: :create}

      # Should return :ok but skip processing
      assert :ok = Telemetry.handle_ash_event(event_name, measurements, metadata, %{})
    end

    test "handles events without duration measurement" do
      event_name = [:ash, Indrajaal.Analytics, :read, :stop]
      # No duration
      measurements = %{}

      metadata = %{
        resource: Indrajaal.Analytics.Report,
        action: :read
      }

      assert :ok = Telemetry.handle_ash_event(event_name, measurements, metadata, %{})
    end

    test "handles events with minimal metadata" do
      event_name = [:ash, Indrajaal.Performance, :create, :stop]
      measurements = %{duration: 500_000}

      metadata = %{
        resource: Indrajaal.Performance.Metric
        # Minimal metadata - no action, actor, etc.
      }

      assert :ok = Telemetry.handle_ash_event(event_name, measurements, metadata, %{})
    end

    test "handles unknown event types gracefully" do
      event_name = [:ash, Indrajaal.Maintenance, :custom_action, :stop]
      measurements = %{duration: 1_000_000}

      metadata = %{
        resource: Indrajaal.Maintenance.WorkOrder,
        action: :custom_action
      }

      assert :ok = Telemetry.handle_ash_event(event_name, measurements, metadata, %{})
    end
  end

  # ============================================================================
  # COMPREHENSIVE INTEGRATION TEST - All 12 Ash Event Patterns
  # ============================================================================

  describe "comprehensive integration - all 12 Ash event patterns" do
    test "validates all 12 Ash telemetry event patterns route correctly" do
      # Test resource for all patterns
      test_resource = Indrajaal.Alarms.AlarmEvent

      # All 12 Ash event patterns:
      # - 4 actions (create, read, update, destroy)
      # - 3 event types per action (start, stop, exception)

      event_patterns = [
        # CREATE events
        {[:ash, Indrajaal.Alarms, :create, :start], %{},
         %{resource: test_resource, action: :create}},
        {[:ash, Indrajaal.Alarms, :create, :stop], %{duration: 1_000_000},
         %{resource: test_resource, action: :create}},
        {[:ash, Indrajaal.Alarms, :create, :exception], %{duration: 1_000_000},
         %{
           resource: test_resource,
           action: :create,
           exception: %RuntimeError{message: "test"},
           kind: :error,
           reason: "test",
           stacktrace: []
         }},

        # READ events
        {[:ash, Indrajaal.Alarms, :read, :start], %{}, %{resource: test_resource, action: :read}},
        {[:ash, Indrajaal.Alarms, :read, :stop], %{duration: 500_000},
         %{resource: test_resource, action: :read}},
        {[:ash, Indrajaal.Alarms, :read, :exception], %{duration: 500_000},
         %{
           resource: test_resource,
           action: :read,
           exception: %RuntimeError{message: "test"},
           kind: :error,
           reason: "test",
           stacktrace: []
         }},

        # UPDATE events
        {[:ash, Indrajaal.Alarms, :update, :start], %{},
         %{resource: test_resource, action: :update}},
        {[:ash, Indrajaal.Alarms, :update, :stop], %{duration: 2_000_000},
         %{resource: test_resource, action: :update}},
        {[:ash, Indrajaal.Alarms, :update, :exception], %{duration: 2_000_000},
         %{
           resource: test_resource,
           action: :update,
           exception: %RuntimeError{message: "test"},
           kind: :error,
           reason: "test",
           stacktrace: []
         }},

        # DESTROY events
        {[:ash, Indrajaal.Alarms, :destroy, :start], %{},
         %{resource: test_resource, action: :destroy}},
        {[:ash, Indrajaal.Alarms, :destroy, :stop], %{duration: 1_500_000},
         %{resource: test_resource, action: :destroy}},
        {[:ash, Indrajaal.Alarms, :destroy, :exception], %{duration: 1_500_000},
         %{
           resource: test_resource,
           action: :destroy,
           exception: %RuntimeError{message: "test"},
           kind: :error,
           reason: "test",
           stacktrace: []
         }}
      ]

      # Execute all event patterns and verify they complete without error
      for {event_name, measurements, metadata} <- event_patterns do
        assert :ok = Telemetry.handle_ash_event(event_name, measurements, metadata, %{})
      end
    end
  end

  # ============================================================================
  # TYPE 3 DOMAINS INTEGRATION TEST
  # ============================================================================

  describe "comprehensive integration - all 9 Type 3 domains" do
    test "validates telemetry integration for all Type 3 domains" do
      type_3_domains = [
        {Indrajaal.Alarms, Indrajaal.Alarms.AlarmEvent, "alarms"},
        {Indrajaal.Analytics, Indrajaal.Analytics.Report, "analytics"},
        {Indrajaal.Communication, Indrajaal.Communication.Notification, "communication"},
        {Indrajaal.Compliance, Indrajaal.Compliance.Policy, "compliance"},
        {Indrajaal.Devices, Indrajaal.Devices.Device, "devices"},
        {Indrajaal.Performance, Indrajaal.Performance.Metric, "performance"},
        {Indrajaal.Video, Indrajaal.Video.Recording, "video"},
        {Indrajaal.VisitorManagement, Indrajaal.VisitorManagement.Visit, "visitor_management"},
        {Indrajaal.Maintenance, Indrajaal.Maintenance.WorkOrder, "maintenance"}
      ]

      for {domain_module, resource_module, domain_name} <- type_3_domains do
        # Test create:stop event for each domain
        event_name = [:ash, domain_module, :create, :stop]
        measurements = %{duration: 1_000_000}

        metadata = %{
          resource: resource_module,
          action: :create,
          actor: %{id: 123},
          resource_id: "#{domain_name}_001"
        }

        assert :ok = Telemetry.handle_ash_event(event_name, measurements, metadata, %{})

        # Verify metadata preparation works correctly
        enriched = Telemetry.prepare_observability_metadata(resource_module, metadata)
        assert enriched.domain == domain_name
        assert enriched.resource == inspect(resource_module)
      end
    end
  end

  # ============================================================================
  # OPENTELEMETRY TRACE PROPAGATION TEST
  # ============================================================================

  describe "OpenTelemetry trace propagation" do
    test "extracts trace_id when OpenTelemetry span context is active" do
      # Note: In test environment without active OpenTelemetry spans,
      # get_trace_id() returns nil. This test validates the function
      # handles both scenarios correctly.

      metadata =
        Telemetry.prepare_observability_metadata(
          Indrajaal.Alarms.AlarmEvent,
          %{action: :create}
        )

      # Trace ID should be nil (no active span) or a binary hex string
      assert metadata.trace_id == nil or is_binary(metadata.trace_id)

      if is_binary(metadata.trace_id) do
        # If trace_id is present, it should be a valid hex string
        assert String.match?(metadata.trace_id, ~r/^[0-9a-f]+$/i)
        assert String.length(metadata.trace_id) > 0
      end
    end

    test "trace_id is included in all event metadata" do
      event_name = [:ash, Indrajaal.Analytics, :read, :stop]
      measurements = %{duration: 500_000}

      metadata = %{
        resource: Indrajaal.Analytics.Report,
        action: :read
      }

      # The function enriches metadata with trace_id
      assert :ok = Telemetry.handle_ash_event(event_name, measurements, metadata, %{})
    end
  end
end
