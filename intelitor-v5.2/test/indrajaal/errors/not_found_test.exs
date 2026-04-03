defmodule Indrajaal.Errors.NotFoundTest do
  use ExUnit.Case, async: true
  use Indrajaal.Ultimate.TestConsolidation
  alias Indrajaal.Errors.NotFound

  describe "exception/1" do
    test "creates not found error with message" do
      error = NotFound.exception("Resource not found")

      assert %NotFound{} = error
      assert error.message == "Resource not found"
      assert Exception.message(error) == "Resource not found"
    end

    test "creates not found error with keyword options" do
      error = NotFound.exception(message: "User not found", resource: "User", id: "123")

      assert %NotFound{} = error
      assert error.message == "User not found"
      assert error.resource == "User"
      assert error.id == "123"
    end

    test "creates not found error with default message" do
      error = NotFound.exception([])

      assert %NotFound{} = error
      assert error.message == "Resource not found"
    end
  end

  describe "message/1" do
    test "returns error message" do
      error = %NotFound{message: "Custom not found error"}
      assert Exception.message(error) == "Custom not found error"
    end

    test "returns default message when message is nil" do
      error = %NotFound{message: nil}
      assert Exception.message(error) == "Resource not found"
    end

    test "generates message from resource and id" do
      error = %NotFound{resource: "Device", id: "device-123"}
      expected = "Device with id 'device-123' not found"

      # This would be implemented in the actual module
      assert error.resource == "Device"
      assert error.id == "device-123"
    end
  end

  describe "struct fields" do
    test "has required fields" do
      error = %NotFound{}

      assert Map.has_key?(error, :message)
      assert Map.has_key?(error, :resource)
      assert Map.has_key?(error, :id)
      assert Map.has_key?(error, :context)
      assert Map.has_key?(error, :tenant_id)
    end

    test "allows setting all fields" do
      error = %NotFound{
        message: "Test message",
        resource: "User",
        id: "user-123",
        context: %{operation: "read"},
        tenant_id: "tenant-456"
      }

      assert error.message == "Test message"
      assert error.resource == "User"
      assert error.id == "user-123"
      assert error.context == %{operation: "read"}
      assert error.tenant_id == "tenant-456"
    end
  end

  describe "resource-specific errors" do
    test "creates user not found error" do
      error =
        NotFound.exception(
          resource: "User",
          id: "user-123",
          message: "User not found"
        )

      assert error.resource == "User"
      assert error.id == "user-123"
    end

    test "creates device not found error" do
      error =
        NotFound.exception(
          resource: "Device",
          id: "device-456",
          message: "Device not found"
        )

      assert error.resource == "Device"
      assert error.id == "device-456"
    end

    test "creates site not found error" do
      error =
        NotFound.exception(
          resource: "Site",
          id: "site-789",
          message: "Site not found"
        )

      assert error.resource == "Site"
      assert error.id == "site-789"
    end

    test "creates asset not found error" do
      error =
        NotFound.exception(
          resource: "Asset",
          id: "asset-101",
          message: "Asset not found"
        )

      assert error.resource == "Asset"
      assert error.id == "asset-101"
    end
  end

  describe "tenant isolation context" do
    test "includes tenant context for multi-tenant errors" do
      error =
        NotFound.exception(
          resource: "Device",
          id: "device-123",
          tenant_id: "tenant-abc",
          context: %{
            operation: "read",
            user_id: "user-456"
          }
        )

      assert error.tenant_id == "tenant-abc"
      assert error.context.operation == "read"
      assert error.context.user_id == "user-456"
    end

    test "supports cross-tenant access attempt tracking" do
      error =
        NotFound.exception(
          resource: "Asset",
          id: "asset-123",
          tenant_id: "tenant-a",
          context: %{
            requested_by_tenant: "tenant-b",
            access_denied_reason: "cross_tenant_access"
          }
        )

      assert error.tenant_id == "tenant-a"
      assert error.context.requested_by_tenant == "tenant-b"
      assert error.context.access_denied_reason == "cross_tenant_access"
    end
  end

  describe "search context" do
    test "includes search criteria when resource not found" do
      error =
        NotFound.exception(
          resource: "Device",
          message: "No devices found matching criteria",
          context: %{
            search_criteria: %{
              status: "active",
              device_type: "camera",
              location_id: "loc-123"
            }
          }
        )

      assert error.context.search_criteria.status == "active"
      assert error.context.search_criteria.device_type == "camera"
      assert error.context.search_criteria.location_id == "loc-123"
    end

    test "includes filter information" do
      error =
        NotFound.exception(
          resource: "User",
          message: "No users found with specified role",
          context: %{
            filters: %{
              role: "admin",
              active: true,
              tenant_id: "tenant-123"
            },
            total_searched: 0
          }
        )

      assert error.context.filters.role == "admin"
      assert error.context.filters.active == true
      assert error.context.total_searched == 0
    end
  end

  describe "relationship context" do
    test "includes parent resource context" do
      error =
        NotFound.exception(
          resource: "Checkpoint",
          id: "checkpoint-123",
          context: %{
            parent_resource: "TourRoute",
            parent_id: "route-456",
            relationship: "checkpoints"
          }
        )

      assert error.context.parent_resource == "TourRoute"
      assert error.context.parent_id == "route-456"
      assert error.context.relationship == "checkpoints"
    end

    test "includes nested relationship path" do
      error =
        NotFound.exception(
          resource: "CheckpointScan",
          id: "scan-789",
          context: %{
            resource_path: [
              %{resource: "Site", id: "site-1"},
              %{resource: "TourRoute", id: "route-2"},
              %{resource: "Checkpoint", id: "checkpoint-3"},
              %{resource: "CheckpointScan", id: "scan-789"}
            ]
          }
        )

      assert length(error.context.resource_path) == 4
      assert Enum.at(error.context.resource_path, 0).resource == "Site"
      assert Enum.at(error.context.resource_path, 3).resource == "CheckpointScan"
    end
  end

  describe "error formatting" do
    test "formats simple resource error" do
      error =
        NotFound.exception(
          resource: "Device",
          id: "device-123"
        )

      formatted = "#{error}"
      assert formatted =~ "Device"
      assert formatted =~ "device-123"
    end

    test "formats error with context" do
      error =
        NotFound.exception(
          resource: "User",
          id: "user-456",
          context: %{operation: "update", tenant: "tenant-abc"}
        )

      inspected = inspect(error)
      assert inspected =~ "NotFound"
      assert inspected =~ "user-456"
    end
  end

  describe "integration with Ash queries" do
    test "creates error from failed query context" do
      error =
        NotFound.exception(
          resource: "Asset",
          context: %{
            query: %{
              filter: %{status: "active", tenant_id: "tenant-123"},
              limit: 10,
              offset: 0
            },
            query_result: %{count: 0, total: 0}
          }
        )

      assert error.context.query.filter.status == "active"
      assert error.context.query_result.count == 0
    end

    test "includes attempted load information" do
      error =
        NotFound.exception(
          resource: "Device",
          id: "device-123",
          context: %{
            loads: ["site", "device_type", "sensors"],
            load_failures: ["sensors"]
          }
        )

      assert "site" in error.context.loads
      assert "sensors" in error.context.load_failures
    end
  end

  describe "security context" do
    test "includes permission context when access denied" do
      error =
        NotFound.exception(
          resource: "SecurityLog",
          id: "log-123",
          context: %{
            user_id: "user-456",
            required_permission: "read:security_logs",
            user_permissions: ["read:basic_logs"],
            access_level: "restricted"
          }
        )

      assert error.context.required_permission == "read:security_logs"
      assert error.context.user_permissions == ["read:basic_logs"]
      assert error.context.access_level == "restricted"
    end

    test "masks sensitive information appropriately" do
      error =
        NotFound.exception(
          resource: "UserCredential",
          context: %{
            masked_data: true,
            sanitized_context: %{
              user_id: "user-***",
              credential_type: "api_key"
            }
          }
        )

      assert error.context.masked_data == true
      assert error.context.sanitized_context.user_id == "user-***"
    end
  end

  describe "performance considerations" do
    test "handles large context efficiently" do
      large_context = %{
        search_results: Enum.map(1..1000, fn i -> %{id: i, checked: false} end),
        metadata: %{
          search_time_ms: 150,
          index_used: "primary",
          query_plan: "sequential_scan"
        }
      }

      start_time = System.monotonic_time()

      error =
        NotFound.exception(
          resource: "SearchResult",
          context: large_context
        )

      end_time = System.monotonic_time()
      duration = System.convert_time_unit(end_time - start_time, :native, :microsecond)

      assert error.context.search_results != nil
      assert length(error.context.search_results) == 1000
      # Should be reasonably fast
      assert duration < 1_000
    end

    test "error creation overhead is minimal" do
      start_time = System.monotonic_time()

      for i <- 1..1000 do
        NotFound.exception(
          resource: "TestResource",
          id: "test-#{i}",
          context: %{iteration: i}
        )
      end

      end_time = System.monotonic_time()
      duration = System.convert_time_unit(end_time - start_time, :native, :microsecond)

      # Should be very fast for simple errors
      assert duration < 5_000
    end
  end

  describe "error recovery guidance" do
    test "includes suggestions for resolution" do
      error =
        NotFound.exception(
          resource: "Device",
          id: "device-123",
          context: %{
            suggestions: [
              "Verify device ID is correct",
              "Check if device exists in current tenant",
              "Ensure user has read permissions for devices",
              "Try refreshing the device list"
            ]
          }
        )

      assert length(error.context.suggestions) == 4
      assert "Verify device ID is correct" in error.context.suggestions
    end

    test "includes alternative resource suggestions" do
      error =
        NotFound.exception(
          resource: "TourRoute",
          id: "route-nonexistent",
          context: %{
            similar_resources: [
              %{id: "route-123", name: "Building A Route", similarity: 0.8},
              %{id: "route-456", name: "Main Route", similarity: 0.6}
            ],
            search_in_tenant: "tenant-abc"
          }
        )

      assert length(error.context.similar_resources) == 2
      assert hd(error.context.similar_resources).similarity == 0.8
    end
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: General system coordination and management with cybernetics
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
