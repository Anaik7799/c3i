defmodule Indrajaal.Errors.BusinessTest do
  use ExUnit.Case, async: true
  use Indrajaal.Ultimate.TestConsolidation
  alias Indrajaal.Errors.Business

  describe "exception/1" do
    test "creates business error with message" do
      error = Business.exception("Invalid business operation")

      assert %Business{} = error
      assert error.message == "Invalid business operation"
      assert Exception.message(error) == "Invalid business operation"
    end

    test "creates business error with keyword options" do
      error =
        Business.exception(
          message: "Business rule violation",
          code: :validation_failed
        )

      assert %Business{} = error
      assert error.message == "Business rule violation"
      assert error.code == :validation_failed
    end

    test "creates business error with default message" do
      error = Business.exception([])

      assert %Business{} = error
      assert error.message == "A business logic error occurred"
    end
  end

  describe "message/1" do
    test "returns error message" do
      error = %Business{message: "Custom business error"}
      assert Exception.message(error) == "Custom business error"
    end

    test "returns default message when message is nil" do
      error = %Business{message: nil}
      assert Exception.message(error) == "A business logic error occurred"
    end
  end

  describe "struct fields" do
    test "has required fields" do
      error = %Business{}

      assert Map.has_key?(error, :message)
      assert Map.has_key?(error, :code)
      assert Map.has_key?(error, :context)
      assert Map.has_key?(error, :details)
    end

    test "allows setting all fields" do
      error = %Business{
        message: "Test message",
        code: :test_code,
        context: %{resource: "users", operation: "create"},
        details: %{field: "email", reason: "already_exists"}
      }

      assert error.message == "Test message"
      assert error.code == :test_code
      assert error.context == %{resource: "users", operation: "create"}
      assert error.details == %{field: "email", reason: "already_exists"}
    end
  end

  describe "error codes" do
    test "supports validation error codes" do
      errors = [
        Business.exception(code: :validation_failed),
        Business.exception(code: :invalid_input),
        Business.exception(code: :constraint_violation),
        Business.exception(code: :business_rule_violation)
      ]

      codes = Enum.map(errors, & &1.code)
      assert :validation_failed in codes
      assert :invalid_input in codes
      assert :constraint_violation in codes
      assert :business_rule_violation in codes
    end

    test "supports workflow error codes" do
      errors = [
        Business.exception(code: :invalid_state_transition),
        Business.exception(code: :workflow_violation),
        Business.exception(code: :precondition_failed),
        Business.exception(code: :postcondition_failed)
      ]

      codes = Enum.map(errors, & &1.code)
      assert :invalid_state_transition in codes
      assert :workflow_violation in codes
      assert :precondition_failed in codes
      assert :postcondition_failed in codes
    end

    test "supports resource error codes" do
      errors = [
        Business.exception(code: :resource_locked),
        Business.exception(code: :resource_expired),
        Business.exception(code: :resource_limit_exceeded),
        Business.exception(code: :duplicate_resource)
      ]

      codes = Enum.map(errors, & &1.code)
      assert :resource_locked in codes
      assert :resource_expired in codes
      assert :resource_limit_exceeded in codes
      assert :duplicate_resource in codes
    end
  end

  describe "context and details" do
    test "supports rich context information" do
      error =
        Business.exception(
          message: "Tenant resource limit exceeded",
          code: :resource_limit_exceeded,
          context: %{
            tenant_id: "tenant-123",
            resource_type: "devices",
            operation: "create"
          },
          details: %{
            current_count: 100,
            limit: 100,
            requested: 1
          }
        )

      assert error.context.tenant_id == "tenant-123"
      assert error.context.resource_type == "devices"
      assert error.context.operation == "create"
      assert error.details.current_count == 100
      assert error.details.limit == 100
      assert error.details.requested == 1
    end

    test "supports nested context structures" do
      error =
        Business.exception(
          context: %{
            user: %{id: "user-123", role: "operator"},
            resource: %{type: "asset", id: "asset-456"},
            permission: %{action: "delete", scope: "tenant"}
          }
        )

      assert error.context.user.id == "user-123"
      assert error.context.resource.type == "asset"
      assert error.context.permission.action == "delete"
    end
  end

  describe "error formatting" do
    test "formats error for logging" do
      error =
        Business.exception(
          message: "Invalid device configuration",
          code: :validation_failed,
          context: %{device_id: "device-123"},
          details: %{field: "ip_address", value: "invalid"}
        )

      formatted = "#{error}"
      assert formatted =~ "Invalid device configuration"
    end

    test "includes error code in inspection" do
      error =
        Business.exception(
          message: "Test error",
          code: :test_code
        )

      inspected = inspect(error)
      assert inspected =~ "Business"
      assert inspected =~ "test_code"
    end
  end

  describe "error chaining" do
    test "supports error cause tracking" do
      root_error = ArgumentError.exception("Invalid argument")

      business_error =
        Business.exception(
          message: "Business operation failed",
          code: :operation_failed,
          details: %{cause: root_error}
        )

      assert business_error.details.cause == root_error
    end

    test "supports error stack context" do
      error =
        Business.exception(
          message: "Nested operation failed",
          context: %{
            stack: [
              %{operation: "create_user", step: "validate"},
              %{operation: "check_permissions", step: "tenant_check"},
              %{operation: "verify_limits", step: "count_check"}
            ]
          }
        )

      assert length(error.context.stack) == 3
      assert hd(error.context.stack).operation == "create_user"
    end
  end

  describe "integration with Ash framework" do
    test "creates error compatible with Ash.Error" do
      error =
        Business.exception(
          message: "Ash resource validation failed",
          code: :validation_failed,
          context: %{resource: "User", action: "create"}
        )

      # Should be usable in Ash error handling
      assert is_exception(error)
      assert error.__struct__ == Business
    end

    test "supports tenant context for multi-tenant errors" do
      error =
        Business.exception(
          message: "Tenant isolation violation",
          code: :tenant_violation,
          context: %{
            current_tenant: "tenant-a",
            attempted_resource: "resource-from-tenant-b",
            operation: "read"
          }
        )

      assert error.context.current_tenant == "tenant-a"
      assert error.context.attempted_resource == "resource-from-tenant-b"
    end
  end

  describe "error severity levels" do
    test "supports different severity levels" do
      low_severity =
        Business.exception(
          message: "Minor validation warning",
          details: %{severity: :warning}
        )

      high_severity =
        Business.exception(
          message: "Critical business rule violation",
          details: %{severity: :critical}
        )

      assert low_severity.details.severity == :warning
      assert high_severity.details.severity == :critical
    end

    test "supports error categories" do
      categories = [
        :validation,
        :authorization,
        :business_logic,
        :workflow,
        :data_integrity,
        :resource_management
      ]

      for category <- categories do
        error =
          Business.exception(
            message: "Test error for #{category}",
            details: %{category: category}
          )

        assert error.details.category == category
      end
    end
  end

  describe "error recovery information" do
    test "includes recovery suggestions" do
      error =
        Business.exception(
          message: "Device limit exceeded",
          code: :resource_limit_exceeded,
          details: %{
            recovery_actions: [
              "Remove inactive devices",
              "Upgrade tenant plan",
              "Contact support for limit increase"
            ]
          }
        )

      assert length(error.details.recovery_actions) == 3
      assert "Remove inactive devices" in error.details.recovery_actions
    end

    test "includes retry information" do
      error =
        Business.exception(
          message: "Temporary resource lock",
          code: :resource_locked,
          details: %{
            retryable: true,
            retry_after: 30,
            max_retries: 3
          }
        )

      assert error.details.retryable == true
      assert error.details.retry_after == 30
      assert error.details.max_retries == 3
    end
  end

  describe "performance impact" do
    test "error creation is efficient" do
      start_time = System.monotonic_time()

      # Create many errors quickly
      for i <- 1..1000 do
        Business.exception(
          message: "Error #{i}",
          code: :test_error,
          context: %{iteration: i}
        )
      end

      end_time = System.monotonic_time()
      duration = System.convert_time_unit(end_time - start_time, :native, :microsecond)

      # Should be very fast (less than 10ms for 1000 errors)
      assert duration < 10_000
    end

    test "error with large context handles efficiently" do
      large_context = %{
        data: Enum.map(1..100, fn i -> %{id: i, name: "item_#{i}"} end),
        metadata: %{
          timestamp: DateTime.utc_now(),
          version: "1.0.0",
          environment: "test"
        }
      }

      start_time = System.monotonic_time()

      error =
        Business.exception(
          message: "Error with large context",
          context: large_context
        )

      end_time = System.monotonic_time()
      duration = System.convert_time_unit(end_time - start_time, :native, :microsecond)

      assert error.context.data != nil
      assert length(error.context.data) == 100
      # Should still be reasonably fast
      assert duration < 1_000
    end
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: General system coordination and management with cybernetics
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
