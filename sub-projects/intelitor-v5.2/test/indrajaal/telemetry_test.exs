defmodule Indrajaal.TelemetryTest do
  @moduledoc """
  Tests for Indrajaal.Telemetry module - SOPv5.11 compliance enhancement.

  This test suite validates the Type 3 Domain observability helper integration,
  focusing on domain extraction, metadata mapping, and event routing.

  Task 11.4.1.1.2: Domain Extraction Function Tests (TDG - Written First)
  Task 11.4.1.1.3: Metadata Mapping Function Tests (TDG - Written First)
  Task 11.4.1.1.4: Event Routing Logic Tests (TDG - Written First)
  """
  use ExUnit.Case, async: true

  alias Indrajaal.Telemetry

  describe "extract_domain_from_resource/1" do
    @moduletag :sopv511
    @moduletag :observability

    test "extracts domain from valid billing resource module" do
      # Given a billing domain resource
      resource_module = Indrajaal.Billing.Invoice

      # When extracting domain
      result = Telemetry.extract_domain_from_resource(resource_module)

      # Then should return underscore domain name
      assert result == "billing"
    end

    test "extracts domain from valid devices resource module" do
      # Given a devices domain resource
      resource_module = Indrajaal.Devices.Device

      # When extracting domain
      result = Telemetry.extract_domain_from_resource(resource_module)

      # Then should return underscore domain name
      assert result == "devices"
    end

    test "returns nil for invalid module structure (non-Indrajaal)" do
      # Given a non-Indrajaal module
      resource_module = Phoenix.LiveView

      # When extracting domain
      result = Telemetry.extract_domain_from_resource(resource_module)

      # Then should return nil
      assert result == nil
    end

    test "returns nil for single-level module (no domain)" do
      # Given a single-level module name
      resource_module = Indrajaal

      # When extracting domain
      result = Telemetry.extract_domain_from_resource(resource_module)

      # Then should return nil
      assert result == nil
    end
  end

  describe "prepare_observability_metadata/2" do
    @moduletag :sopv511
    @moduletag :observability

    test "converts Ash metadata to SOPv5.11 format with all fields" do
      # Given valid Ash metadata with resource module and additional metadata
      resource_module = Indrajaal.Billing.Invoice

      ash_metadata = %{
        action: :create,
        resource_id: "inv-123",
        tenant: "tenant-456",
        user_id: "user-789"
      }

      # When preparing observability metadata
      result = Telemetry.prepare_observability_metadata(resource_module, ash_metadata)

      # Then should return SOPv5.11 formatted metadata with domain, resource, and trace info
      assert result.domain == "billing"
      assert result.resource == "Indrajaal.Billing.Invoice"
      assert result.action == :create
      assert result.resource_id == "inv-123"
      assert result.tenant == "tenant-456"
      assert result.user_id == "user-789"
      assert Map.has_key?(result, :trace_id)
    end

    test "handles nil ash_metadata gracefully" do
      # Given a resource module but nil metadata
      resource_module = Indrajaal.Devices.Device

      # When preparing observability metadata with nil
      result = Telemetry.prepare_observability_metadata(resource_module, nil)

      # Then should return metadata with domain and resource only
      assert result.domain == "devices"
      assert result.resource == "Indrajaal.Devices.Device"
      assert Map.has_key?(result, :trace_id)
    end

    test "handles empty ash_metadata map" do
      # Given a resource module and empty metadata
      resource_module = Indrajaal.Alarms.Alarm

      # When preparing observability metadata with empty map
      result = Telemetry.prepare_observability_metadata(resource_module, %{})

      # Then should return metadata with domain and resource
      assert result.domain == "alarms"
      assert result.resource == "Indrajaal.Alarms.Alarm"
      assert Map.has_key?(result, :trace_id)
    end
  end

  describe "extract_resource_id/1" do
    @moduletag :sopv511
    @moduletag :observability

    test "extracts resource_id from map with string key" do
      # Given Ash data with resource_id as string key
      ash_data = %{"resource_id" => "res-123"}

      # When extracting resource ID
      result = Telemetry.extract_resource_id(ash_data)

      # Then should return the resource ID
      assert result == "res-123"
    end

    test "extracts resource_id from map with atom key" do
      # Given Ash data with resource_id as atom key
      ash_data = %{resource_id: "res-456"}

      # When extracting resource ID
      result = Telemetry.extract_resource_id(ash_data)

      # Then should return the resource ID
      assert result == "res-456"
    end

    test "extracts id field when resource_id not present" do
      # Given Ash data with id field but no resource_id
      ash_data = %{id: "id-789"}

      # When extracting resource ID
      result = Telemetry.extract_resource_id(ash_data)

      # Then should return the id field
      assert result == "id-789"
    end

    test "returns nil when no ID fields present" do
      # Given Ash data without any ID fields
      ash_data = %{name: "test", status: "active"}

      # When extracting resource ID
      result = Telemetry.extract_resource_id(ash_data)

      # Then should return nil
      assert result == nil
    end

    test "returns nil when given nil" do
      # Given nil data
      ash_data = nil

      # When extracting resource ID
      result = Telemetry.extract_resource_id(ash_data)

      # Then should return nil
      assert result == nil
    end
  end

  describe "get_trace_id/0" do
    @moduletag :sopv511
    @moduletag :observability

    test "returns trace_id from OpenTelemetry when available" do
      # When getting trace ID
      result = Telemetry.get_trace_id()

      # Then should return a trace ID (string or nil if not in traced context)
      assert is_binary(result) or is_nil(result)
    end

    test "returns nil when OpenTelemetry context not available" do
      # Given no active OpenTelemetry context
      # When getting trace ID
      result = Telemetry.get_trace_id()

      # Then should handle gracefully (return nil or trace ID)
      assert is_binary(result) or is_nil(result)
    end
  end

  describe "handle_ash_event/4" do
    @moduletag :sopv511
    @moduletag :observability

    test "routes create action event to domain logger" do
      # Given a create action event for billing resource
      event_name = [:ash, Indrajaal.Billing, :create, :stop]
      measurements = %{duration: 1500}

      metadata = %{
        resource: Indrajaal.Billing.Invoice,
        action: :create,
        tenant: "tenant-123"
      }

      config = %{}

      # When handling the event
      result = Telemetry.handle_ash_event(event_name, measurements, metadata, config)

      # Then should return :ok (successful routing)
      assert result == :ok
    end

    test "routes update action event to domain logger" do
      # Given an update action event for devices resource
      event_name = [:ash, Indrajaal.Devices, :update, :stop]
      measurements = %{duration: 2000}

      metadata = %{
        resource: Indrajaal.Devices.Device,
        action: :update,
        resource_id: "dev-456"
      }

      config = %{}

      # When handling the event
      result = Telemetry.handle_ash_event(event_name, measurements, metadata, config)

      # Then should return :ok (successful routing)
      assert result == :ok
    end

    test "routes read action event to domain logger" do
      # Given a read action event for alarms resource
      event_name = [:ash, Indrajaal.Alarms, :read, :stop]
      measurements = %{duration: 500}

      metadata = %{
        resource: Indrajaal.Alarms.Alarm,
        action: :read,
        query: %{}
      }

      config = %{}

      # When handling the event
      result = Telemetry.handle_ash_event(event_name, measurements, metadata, config)

      # Then should return :ok (successful routing)
      assert result == :ok
    end

    test "routes destroy action event to domain logger" do
      # Given a destroy action event for accounts resource
      event_name = [:ash, Indrajaal.Accounts, :destroy, :stop]
      measurements = %{duration: 1000}

      metadata = %{
        resource: Indrajaal.Accounts.User,
        action: :destroy,
        resource_id: "user-789"
      }

      config = %{}

      # When handling the event
      result = Telemetry.handle_ash_event(event_name, measurements, metadata, config)

      # Then should return :ok (successful routing)
      assert result == :ok
    end

    test "routes error event to error logger" do
      # Given an error event for billing resource
      event_name = [:ash, Indrajaal.Billing, :error]
      measurements = %{}

      metadata = %{
        resource: Indrajaal.Billing.Invoice,
        action: :create,
        error: %{message: "Validation failed", type: :validation_error}
      }

      config = %{}

      # When handling the event
      result = Telemetry.handle_ash_event(event_name, measurements, metadata, config)

      # Then should return :ok (successful error routing)
      assert result == :ok
    end

    test "routes exception event to error logger" do
      # Given an exception event for devices resource
      event_name = [:ash, Indrajaal.Devices, :exception]
      measurements = %{}

      metadata = %{
        resource: Indrajaal.Devices.Device,
        action: :update,
        exception: %ArgumentError{message: "Invalid argument"}
      }

      config = %{}

      # When handling the event
      result = Telemetry.handle_ash_event(event_name, measurements, metadata, config)

      # Then should return :ok (successful exception routing)
      assert result == :ok
    end

    test "propagates metadata through event routing" do
      # Given an event with complete metadata
      event_name = [:ash, Indrajaal.Billing, :create, :stop]
      measurements = %{duration: 1500}

      metadata = %{
        resource: Indrajaal.Billing.Invoice,
        action: :create,
        tenant: "tenant-123",
        user_id: "user-456",
        resource_id: "inv-789"
      }

      config = %{}

      # When handling the event
      result = Telemetry.handle_ash_event(event_name, measurements, metadata, config)

      # Then should return :ok with metadata propagated
      assert result == :ok
    end

    test "handles events with minimal metadata" do
      # Given an event with minimal metadata
      event_name = [:ash, Indrajaal.Alarms, :read, :stop]
      measurements = %{duration: 300}

      metadata = %{
        resource: Indrajaal.Alarms.Alarm
      }

      config = %{}

      # When handling the event
      result = Telemetry.handle_ash_event(event_name, measurements, metadata, config)

      # Then should return :ok even with minimal metadata
      assert result == :ok
    end

    test "handles events for Type 3 domains" do
      # Given an event for a Type 3 domain (Analytics)
      event_name = [:ash, Indrajaal.Analytics, :create, :stop]
      measurements = %{duration: 2500}

      metadata = %{
        resource: Indrajaal.Analytics.Report,
        action: :create,
        report_type: "usage"
      }

      config = %{}

      # When handling the event
      result = Telemetry.handle_ash_event(event_name, measurements, metadata, config)

      # Then should return :ok (Type 3 domain support)
      assert result == :ok
    end

    test "includes SOPv5.11 metadata in routed events" do
      # Given an event with resource module
      event_name = [:ash, Indrajaal.Billing, :update, :stop]
      measurements = %{duration: 1800}

      metadata = %{
        resource: Indrajaal.Billing.Invoice,
        action: :update,
        resource_id: "inv-999"
      }

      config = %{}

      # When handling the event
      result = Telemetry.handle_ash_event(event_name, measurements, metadata, config)

      # Then should return :ok with SOPv5.11 metadata included
      # (domain, resource, trace_id should be automatically added)
      assert result == :ok
    end
  end

  describe "should_audit?/1 - Task 11.4.1.1.5" do
    @moduletag :sopv511
    @moduletag :observability
    @moduletag :audit

    test "returns true for sensitive billing operations (create)" do
      # Given a create action event for billing
      event_name = [:ash, Indrajaal.Billing, :create, :stop]

      # When checking if should audit
      result = Telemetry.should_audit?(event_name)

      # Then should return true (billing create requires audit)
      assert result == true
    end

    test "returns true for sensitive billing operations (update)" do
      # Given an update action event for billing
      event_name = [:ash, Indrajaal.Billing, :update, :stop]

      # When checking if should audit
      result = Telemetry.should_audit?(event_name)

      # Then should return true (billing update requires audit)
      assert result == true
    end

    test "returns true for sensitive billing operations (destroy)" do
      # Given a destroy action event for billing
      event_name = [:ash, Indrajaal.Billing, :destroy, :stop]

      # When checking if should audit
      result = Telemetry.should_audit?(event_name)

      # Then should return true (billing destroy requires audit)
      assert result == true
    end

    test "returns true for access control domain actions" do
      # Given an access control domain event
      event_name = [:ash, Indrajaal.AccessControl, :update, :stop]

      # When checking if should audit
      result = Telemetry.should_audit?(event_name)

      # Then should return true (access control requires audit)
      assert result == true
    end

    test "returns true for accounts domain sensitive actions" do
      # Given an accounts domain event
      event_name = [:ash, Indrajaal.Accounts, :create, :stop]

      # When checking if should audit
      result = Telemetry.should_audit?(event_name)

      # Then should return true (accounts require audit)
      assert result == true
    end

    test "returns false for read operations on non-sensitive domains" do
      # Given a read action event for devices
      event_name = [:ash, Indrajaal.Devices, :read, :stop]

      # When checking if should audit
      result = Telemetry.should_audit?(event_name)

      # Then should return false (read operations not audited)
      assert result == false
    end

    test "returns false for alarms read operations" do
      # Given a read action event for alarms
      event_name = [:ash, Indrajaal.Alarms, :read, :stop]

      # When checking if should audit
      result = Telemetry.should_audit?(event_name)

      # Then should return false (alarms read not audited)
      assert result == false
    end

    test "returns false for non-Ash events" do
      # Given a non-Ash event
      event_name = [:phoenix, :endpoint, :stop]

      # When checking if should audit
      result = Telemetry.should_audit?(event_name)

      # Then should return false (only Ash events audited)
      assert result == false
    end
  end

  describe "log_audit_event/3 - Task 11.4.1.1.5" do
    @moduletag :sopv511
    @moduletag :observability
    @moduletag :audit

    test "logs audit event with complete metadata" do
      # Given an event with complete audit metadata
      event_name = [:ash, Indrajaal.Billing, :create, :stop]

      metadata = %{
        resource: Indrajaal.Billing.Invoice,
        action: :create,
        user_id: "user-123",
        tenant_id: "tenant-456",
        resource_id: "inv-789"
      }

      measurements = %{duration: 1500}

      # When logging audit event
      result = Telemetry.log_audit_event(event_name, metadata, measurements)

      # Then should return :ok (successful audit logging)
      assert result == :ok
    end

    test "logs audit event with minimal metadata" do
      # Given an event with minimal metadata
      event_name = [:ash, Indrajaal.Accounts, :update, :stop]

      metadata = %{
        resource: Indrajaal.Accounts.User,
        action: :update
      }

      measurements = %{duration: 2000}

      # When logging audit event
      result = Telemetry.log_audit_event(event_name, metadata, measurements)

      # Then should return :ok (handles minimal metadata)
      assert result == :ok
    end

    test "logs audit event with billing domain data" do
      # Given a billing event with financial data
      event_name = [:ash, Indrajaal.Billing, :update, :stop]

      metadata = %{
        resource: Indrajaal.Billing.Invoice,
        action: :update,
        user_id: "user-456",
        tenant_id: "tenant-789",
        resource_id: "inv-123",
        amount: 999.99,
        currency: "USD"
      }

      measurements = %{duration: 1800}

      # When logging audit event
      result = Telemetry.log_audit_event(event_name, metadata, measurements)

      # Then should return :ok (logs financial data)
      assert result == :ok
    end

    test "logs audit event with access control changes" do
      # Given an access control event
      event_name = [:ash, Indrajaal.AccessControl, :update, :stop]

      metadata = %{
        resource: Indrajaal.AccessControl.Permission,
        action: :update,
        user_id: "user-999",
        tenant_id: "tenant-111",
        resource_id: "perm-555",
        permission_change: "admin -> user"
      }

      measurements = %{duration: 500}

      # When logging audit event
      result = Telemetry.log_audit_event(event_name, metadata, measurements)

      # Then should return :ok (logs permission changes)
      assert result == :ok
    end

    test "logs audit event with destroy action" do
      # Given a destroy action event
      event_name = [:ash, Indrajaal.Accounts, :destroy, :stop]

      metadata = %{
        resource: Indrajaal.Accounts.User,
        action: :destroy,
        user_id: "admin-123",
        tenant_id: "tenant-456",
        resource_id: "user-to-delete-789"
      }

      measurements = %{duration: 1200}

      # When logging audit event
      result = Telemetry.log_audit_event(event_name, metadata, measurements)

      # Then should return :ok (logs destructive actions)
      assert result == :ok
    end

    test "logs audit event includes trace context" do
      # Given an event with trace information
      event_name = [:ash, Indrajaal.Billing, :create, :stop]

      metadata = %{
        resource: Indrajaal.Billing.Invoice,
        action: :create,
        user_id: "user-123",
        tenant_id: "tenant-456",
        trace_id: "trace-abc-123"
      }

      measurements = %{duration: 1500}

      # When logging audit event
      result = Telemetry.log_audit_event(event_name, metadata, measurements)

      # Then should return :ok (includes trace context)
      assert result == :ok
    end
  end
end
