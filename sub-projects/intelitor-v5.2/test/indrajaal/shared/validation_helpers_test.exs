defmodule Indrajaal.Shared.ValidationHelpersTest do
  @moduledoc """
  TDG-compliant tests for Indrajaal.Shared.ValidationHelpers module.

  Tests comprehensive validation patterns for:
  - Query parameter validation (pagination)
  - User access control (RBAC/ABAC)
  - Item-level tenant access
  - Update safety validation
  - STAMP deletion safety
  - Create attributes validation

  Created: 2025-11-27 12:58:00 CEST
  Phase: 2.2 - C1 Security-Critical Testing (Validation Modules)
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Shared.ValidationHelpers

  # Test structs for validation
  defmodule TestUser do
    @moduledoc false
    defstruct [:id, :tenant_id, :admin, :status, :permissions]
  end

  defmodule TestItem do
    @moduledoc false
    defstruct [
      :id,
      :tenant_id,
      :status,
      :locked_at,
      :deleted_at,
      :child_count,
      :dependencies,
      :referenced_by,
      :system_critical
    ]
  end

  # ============================================================================
  # QUERY PARAMS VALIDATION TESTS
  # ============================================================================

  describe "validate_query_params/2" do
    test "returns :ok for valid page and page_size" do
      assert :ok = ValidationHelpers.validate_query_params(1, 20)
      assert :ok = ValidationHelpers.validate_query_params(1, 1)
      assert :ok = ValidationHelpers.validate_query_params(100, 100)
      assert :ok = ValidationHelpers.validate_query_params(1, 1000)
    end

    test "returns error for page less than 1" do
      assert {:error, :invalid_page} = ValidationHelpers.validate_query_params(0, 20)
      assert {:error, :invalid_page} = ValidationHelpers.validate_query_params(-1, 20)
      assert {:error, :invalid_page} = ValidationHelpers.validate_query_params(-100, 20)
    end

    test "returns error for page_size less than 1" do
      assert {:error, :invalid_page_size} = ValidationHelpers.validate_query_params(1, 0)
      assert {:error, :invalid_page_size} = ValidationHelpers.validate_query_params(1, -1)
      assert {:error, :invalid_page_size} = ValidationHelpers.validate_query_params(1, -100)
    end

    test "returns error for page_size greater than 1000" do
      assert {:error, :page_size_too_large} = ValidationHelpers.validate_query_params(1, 1001)
      assert {:error, :page_size_too_large} = ValidationHelpers.validate_query_params(1, 10_000)
    end

    test "boundary values work correctly" do
      # Minimum valid values
      assert :ok = ValidationHelpers.validate_query_params(1, 1)
      # Maximum page_size
      assert :ok = ValidationHelpers.validate_query_params(1, 1000)
      # Just over maximum
      assert {:error, :page_size_too_large} = ValidationHelpers.validate_query_params(1, 1001)
    end
  end

  # ============================================================================
  # USER ACCESS VALIDATION TESTS
  # ============================================================================

  describe "validate_user_access/3" do
    test "returns error for nil user" do
      assert {:error, :authentication_required} =
               ValidationHelpers.validate_user_access(nil, :read, TestItem)
    end

    test "returns :ok for authenticated user with valid action" do
      user = %TestUser{id: 1, tenant_id: "tenant-1", admin: false, status: :active}

      assert :ok = ValidationHelpers.validate_user_access(user, :read, TestItem)
      assert :ok = ValidationHelpers.validate_user_access(user, :list, TestItem)
      assert :ok = ValidationHelpers.validate_user_access(user, :create, TestItem)
      assert :ok = ValidationHelpers.validate_user_access(user, :update, TestItem)
    end

    test "returns error for non-admin trying admin actions" do
      user = %TestUser{id: 1, tenant_id: "tenant-1", admin: false, status: :active}

      assert {:error, :access_denied} =
               ValidationHelpers.validate_user_access(user, :admin, TestItem)

      assert {:error, :access_denied} =
               ValidationHelpers.validate_user_access(user, :system, TestItem)

      assert {:error, :access_denied} =
               ValidationHelpers.validate_user_access(user, :delete, TestItem)
    end

    test "returns :ok for admin user with admin actions" do
      admin_user = %TestUser{id: 1, tenant_id: "tenant-1", admin: true, status: :active}

      assert :ok = ValidationHelpers.validate_user_access(admin_user, :admin, TestItem)
      assert :ok = ValidationHelpers.validate_user_access(admin_user, :system, TestItem)
      assert :ok = ValidationHelpers.validate_user_access(admin_user, :delete, TestItem)
    end

    test "returns error for suspended user" do
      suspended_user = %TestUser{id: 1, tenant_id: "tenant-1", admin: false, status: :suspended}

      assert {:error, :access_denied} =
               ValidationHelpers.validate_user_access(suspended_user, :read, TestItem)
    end

    test "returns error for inactive user" do
      inactive_user = %TestUser{id: 1, tenant_id: "tenant-1", admin: false, status: :inactive}

      assert {:error, :access_denied} =
               ValidationHelpers.validate_user_access(inactive_user, :read, TestItem)
    end

    test "returns error for tenant mismatch on resource" do
      user = %TestUser{id: 1, tenant_id: "tenant-1", admin: false, status: :active}
      resource = %TestItem{id: 1, tenant_id: "tenant-2", status: :active}

      assert {:error, :access_denied} =
               ValidationHelpers.validate_user_access(user, :read, resource)
    end

    test "returns :ok for matching tenant on resource" do
      user = %TestUser{id: 1, tenant_id: "tenant-1", admin: false, status: :active}
      resource = %TestItem{id: 1, tenant_id: "tenant-1", status: :active}

      assert :ok = ValidationHelpers.validate_user_access(user, :read, resource)
    end

    test "returns error for invalid user type" do
      assert {:error, :invalid_user_type} =
               ValidationHelpers.validate_user_access("not_a_struct", :read, TestItem)

      assert {:error, :invalid_user_type} =
               ValidationHelpers.validate_user_access(%{id: 1}, :read, TestItem)
    end
  end

  # ============================================================================
  # ITEM ACCESS VALIDATION TESTS
  # ============================================================================

  describe "validate_item_access/2" do
    test "returns :ok when tenant IDs match" do
      user = %TestUser{id: 1, tenant_id: "tenant-1"}
      item = %TestItem{id: 1, tenant_id: "tenant-1"}

      assert :ok = ValidationHelpers.validate_item_access(user, item)
    end

    test "returns error when tenant IDs don't match" do
      user = %TestUser{id: 1, tenant_id: "tenant-1"}
      item = %TestItem{id: 1, tenant_id: "tenant-2"}

      assert {:error, :tenant_mismatch} = ValidationHelpers.validate_item_access(user, item)
    end

    test "handles nil tenant_id gracefully" do
      user = %TestUser{id: 1, tenant_id: nil}
      item = %TestItem{id: 1, tenant_id: nil}

      # Both nil should match (nil == nil)
      assert :ok = ValidationHelpers.validate_item_access(user, item)
    end

    test "returns error when user has nil tenant but item has tenant" do
      user = %TestUser{id: 1, tenant_id: nil}
      item = %TestItem{id: 1, tenant_id: "tenant-1"}

      assert {:error, :tenant_mismatch} = ValidationHelpers.validate_item_access(user, item)
    end
  end

  # ============================================================================
  # UPDATE ATTRS VALIDATION TESTS
  # ============================================================================

  describe "validate_update_attrs/2" do
    test "returns :ok for valid update attributes" do
      item = %TestItem{id: 1, status: :pending, locked_at: nil}
      attrs = %{name: "Updated Name"}

      assert :ok = ValidationHelpers.validate_update_attrs(attrs, item)
    end

    test "returns error for empty attributes" do
      item = %TestItem{id: 1, status: :pending, locked_at: nil}
      attrs = %{}

      assert {:error, :no_attributes_to_update} =
               ValidationHelpers.validate_update_attrs(attrs, item)
    end

    test "returns error for archived item" do
      item = %TestItem{id: 1, status: :archived, locked_at: nil}
      attrs = %{name: "Updated Name"}

      assert {:error, :cannot_update_archived} =
               ValidationHelpers.validate_update_attrs(attrs, item)
    end

    test "returns error for locked item" do
      item = %TestItem{id: 1, status: :pending, locked_at: ~U[2025-01-01 00:00:00Z]}
      attrs = %{name: "Updated Name"}

      assert {:error, :item_locked} = ValidationHelpers.validate_update_attrs(attrs, item)
    end

    test "returns error for deleted item (unsafe update)" do
      item = %TestItem{
        id: 1,
        status: :pending,
        locked_at: nil,
        deleted_at: ~U[2025-01-01 00:00:00Z]
      }

      attrs = %{name: "Updated Name"}

      assert {:error, :unsafe_update} = ValidationHelpers.validate_update_attrs(attrs, item)
    end

    test "returns error when trying to set admin flag" do
      item = %TestItem{id: 1, status: :pending, locked_at: nil}
      attrs = %{"admin" => true}

      assert {:error, :unsafe_update} = ValidationHelpers.validate_update_attrs(attrs, item)
    end

    test "returns error when trying to set system_critical flag" do
      item = %TestItem{id: 1, status: :pending, locked_at: nil}
      attrs = %{"system_critical" => true}

      assert {:error, :unsafe_update} = ValidationHelpers.validate_update_attrs(attrs, item)
    end

    test "returns error for too many attributes (bulk update protection)" do
      item = %TestItem{id: 1, status: :pending, locked_at: nil}

      attrs =
        1..11
        |> Enum.map(fn i -> {"field_#{i}", "value_#{i}"} end)
        |> Map.new()

      assert {:error, :unsafe_update} = ValidationHelpers.validate_update_attrs(attrs, item)
    end

    test "returns error for invalid attributes format (non-map)" do
      item = %TestItem{id: 1, status: :pending}

      assert {:error, :invalid_attributes_format} =
               ValidationHelpers.validate_update_attrs("not_a_map", item)
    end

    test "returns error for invalid item format (non-struct)" do
      attrs = %{name: "test"}

      assert {:error, :invalid_item_format} =
               ValidationHelpers.validate_update_attrs(attrs, %{id: 1})
    end

    test "returns error for completely invalid parameters" do
      assert {:error, :invalid_update_parameters} =
               ValidationHelpers.validate_update_attrs("string", "string")
    end
  end

  # ============================================================================
  # DELETION SAFETY VALIDATION TESTS (STAMP)
  # ============================================================================

  describe "validate_deletion_safety/1 (STAMP safety)" do
    # NOTE: Implementation checks in order: dependencies -> status -> system_critical
    # NOTE: Struct fields with nil values still trigger Map.has_key? = true,
    #       so we must initialize list fields with [] to avoid length(nil) errors

    test "returns :ok for safe deletion" do
      # Must initialize list fields with [] to avoid has_dependencies? check issues
      item = %TestItem{
        id: 1,
        status: :inactive,
        system_critical: false,
        child_count: 0,
        dependencies: [],
        referenced_by: []
      }

      assert :ok = ValidationHelpers.validate_deletion_safety(item)
    end

    test "returns error for active item" do
      # Active status check is second, after dependencies check
      item = %TestItem{
        id: 1,
        status: :active,
        system_critical: false,
        child_count: 0,
        dependencies: [],
        referenced_by: []
      }

      assert {:error, :cannot_delete_active_item} =
               ValidationHelpers.validate_deletion_safety(item)
    end

    test "returns error for system critical item" do
      # system_critical check is LAST (after dependencies and status)
      item = %TestItem{
        id: 1,
        status: :inactive,
        system_critical: true,
        child_count: 0,
        dependencies: [],
        referenced_by: []
      }

      assert {:error, :system_critical_resource} =
               ValidationHelpers.validate_deletion_safety(item)
    end

    test "returns error for item with child records" do
      item = %TestItem{
        id: 1,
        status: :inactive,
        system_critical: false,
        child_count: 5,
        dependencies: [],
        referenced_by: []
      }

      assert {:error, :has_dependencies} = ValidationHelpers.validate_deletion_safety(item)
    end

    test "returns error for item with dependencies list" do
      item = %TestItem{
        id: 1,
        status: :inactive,
        system_critical: false,
        child_count: 0,
        dependencies: ["dep1", "dep2"],
        referenced_by: []
      }

      assert {:error, :has_dependencies} = ValidationHelpers.validate_deletion_safety(item)
    end

    test "returns error for item referenced by others" do
      item = %TestItem{
        id: 1,
        status: :inactive,
        system_critical: false,
        child_count: 0,
        dependencies: [],
        referenced_by: ["ref1", "ref2"]
      }

      assert {:error, :has_dependencies} = ValidationHelpers.validate_deletion_safety(item)
    end

    test "returns error for item in use" do
      # :in_use status triggers has_dependencies? -> true
      item = %TestItem{
        id: 1,
        status: :in_use,
        system_critical: false,
        child_count: 0,
        dependencies: [],
        referenced_by: []
      }

      assert {:error, :has_dependencies} = ValidationHelpers.validate_deletion_safety(item)
    end

    test "returns :ok for item with zero child_count" do
      item = %TestItem{
        id: 1,
        status: :inactive,
        system_critical: false,
        child_count: 0,
        dependencies: [],
        referenced_by: []
      }

      assert :ok = ValidationHelpers.validate_deletion_safety(item)
    end

    test "returns :ok for item with empty dependencies" do
      item = %TestItem{
        id: 1,
        status: :inactive,
        system_critical: false,
        child_count: 0,
        dependencies: [],
        referenced_by: []
      }

      assert :ok = ValidationHelpers.validate_deletion_safety(item)
    end

    test "dependencies check takes precedence over system_critical" do
      # Even if system_critical is true, dependencies check happens FIRST
      item = %TestItem{
        id: 1,
        status: :inactive,
        system_critical: true,
        child_count: 5,
        dependencies: [],
        referenced_by: []
      }

      # Returns :has_dependencies, not :system_critical_resource
      assert {:error, :has_dependencies} = ValidationHelpers.validate_deletion_safety(item)
    end

    test "active status check takes precedence over system_critical" do
      # Status check is before system_critical check
      item = %TestItem{
        id: 1,
        status: :active,
        system_critical: true,
        child_count: 0,
        dependencies: [],
        referenced_by: []
      }

      # Returns :cannot_delete_active_item, not :system_critical_resource
      assert {:error, :cannot_delete_active_item} =
               ValidationHelpers.validate_deletion_safety(item)
    end
  end

  # ============================================================================
  # CREATE ATTRS VALIDATION TESTS
  # ============================================================================

  describe "validate_create_attrs/1" do
    test "returns :ok for non-empty attributes" do
      assert :ok = ValidationHelpers.validate_create_attrs(%{name: "Test"})
      assert :ok = ValidationHelpers.validate_create_attrs(%{a: 1, b: 2, c: 3})
    end

    test "returns error for empty attributes" do
      assert {:error, :empty_attributes} = ValidationHelpers.validate_create_attrs(%{})
    end

    test "returns error for non-map input" do
      assert {:error, :invalid_attributes} = ValidationHelpers.validate_create_attrs("string")
      assert {:error, :invalid_attributes} = ValidationHelpers.validate_create_attrs(123)
      assert {:error, :invalid_attributes} = ValidationHelpers.validate_create_attrs(nil)
      assert {:error, :invalid_attributes} = ValidationHelpers.validate_create_attrs([])
    end
  end

  # ============================================================================
  # PROPERTY-BASED TESTS (PropCheck)
  # ============================================================================

  describe "Property Tests (PropCheck)" do
    property "query params validation returns valid structure" do
      forall {page, page_size} <- {PC.integer(), PC.integer()} do
        result = ValidationHelpers.validate_query_params(page, page_size)

        case result do
          :ok -> true
          {:error, reason} when is_atom(reason) -> true
          _ -> false
        end
      end
    end

    property "user access always returns valid result for any action" do
      forall action <- PC.oneof([:read, :list, :create, :update, :delete, :admin, :system]) do
        user = %TestUser{id: 1, tenant_id: "tenant-1", admin: false, status: :active}
        result = ValidationHelpers.validate_user_access(user, action, TestItem)

        case result do
          :ok -> true
          {:error, :access_denied} -> true
          _ -> false
        end
      end
    end

    property "deletion safety returns valid result for any status" do
      forall status <- PC.oneof([:active, :inactive, :pending, :archived, :in_use]) do
        item = %TestItem{id: 1, status: status, system_critical: false}
        result = ValidationHelpers.validate_deletion_safety(item)

        case result do
          :ok -> true
          {:error, reason} when is_atom(reason) -> true
          _ -> false
        end
      end
    end

    property "create attrs validation handles all map sizes" do
      forall attr_count <- PC.non_neg_integer() do
        attrs =
          if attr_count == 0 do
            %{}
          else
            1..min(attr_count, 100)
            |> Enum.map(fn i -> {:"field_#{i}", "value_#{i}"} end)
            |> Map.new()
          end

        result = ValidationHelpers.validate_create_attrs(attrs)

        case result do
          :ok -> attr_count > 0
          {:error, :empty_attributes} -> attr_count == 0
          _ -> false
        end
      end
    end
  end

  # ============================================================================
  # EDGE CASE TESTS
  # ============================================================================

  describe "Edge Cases" do
    test "handles very large page numbers" do
      assert :ok = ValidationHelpers.validate_query_params(999_999_999, 20)
    end

    test "handles unicode in attributes" do
      item = %TestItem{id: 1, status: :pending, locked_at: nil}
      attrs = %{name: "日本語テスト", description: "🎉 emoji test"}

      assert :ok = ValidationHelpers.validate_update_attrs(attrs, item)
    end

    test "handles nested map in create attrs" do
      attrs = %{
        name: "Test",
        metadata: %{nested: %{deep: "value"}}
      }

      assert :ok = ValidationHelpers.validate_create_attrs(attrs)
    end

    test "validate_query_params with integer boundaries" do
      # Test with MAX_INT-like values
      assert :ok = ValidationHelpers.validate_query_params(1, 1000)
      assert {:error, :page_size_too_large} = ValidationHelpers.validate_query_params(1, 1001)
    end
  end

  # ============================================================================
  # SECURITY TESTS
  # ============================================================================

  describe "Security Tests" do
    test "prevents unauthorized admin escalation" do
      user = %TestUser{id: 1, tenant_id: "tenant-1", admin: false, status: :active}

      # Regular user cannot perform admin actions
      assert {:error, :access_denied} =
               ValidationHelpers.validate_user_access(user, :admin, TestItem)
    end

    test "prevents cross-tenant access" do
      user = %TestUser{id: 1, tenant_id: "tenant-1", admin: false, status: :active}
      resource = %TestItem{id: 1, tenant_id: "tenant-2", status: :active}

      assert {:error, :access_denied} =
               ValidationHelpers.validate_user_access(user, :read, resource)
    end

    test "prevents suspended user access" do
      user = %TestUser{id: 1, tenant_id: "tenant-1", admin: true, status: :suspended}

      # Even admin is blocked when suspended
      assert {:error, :access_denied} =
               ValidationHelpers.validate_user_access(user, :read, TestItem)
    end

    test "prevents deletion of system critical resources" do
      # Must initialize list fields to avoid has_dependencies? triggering first
      item = %TestItem{
        id: 1,
        status: :inactive,
        system_critical: true,
        child_count: 0,
        dependencies: [],
        referenced_by: []
      }

      assert {:error, :system_critical_resource} =
               ValidationHelpers.validate_deletion_safety(item)
    end

    test "prevents bulk attribute updates (protection against mass assignment)" do
      item = %TestItem{id: 1, status: :pending, locked_at: nil}

      # Creating attrs with 11+ fields should be blocked
      large_attrs =
        1..15
        |> Enum.map(fn i -> {"field_#{i}", "value"} end)
        |> Map.new()

      assert {:error, :unsafe_update} = ValidationHelpers.validate_update_attrs(large_attrs, item)
    end

    test "does not leak internal details in error messages" do
      # Must initialize list fields - check order: dependencies → status → system_critical
      item = %TestItem{
        id: 1,
        status: :active,
        child_count: 0,
        dependencies: [],
        referenced_by: []
      }

      result = ValidationHelpers.validate_deletion_safety(item)

      {:error, reason} = result

      # Error reason should be an atom, not exposing internal state
      assert is_atom(reason)
      assert reason == :cannot_delete_active_item
    end
  end

  # ============================================================================
  # INTEGRATION-STYLE TESTS
  # ============================================================================

  describe "Validation Flow Integration" do
    test "complete user action validation flow" do
      user = %TestUser{id: 1, tenant_id: "tenant-1", admin: false, status: :active}
      item = %TestItem{id: 1, tenant_id: "tenant-1", status: :pending, locked_at: nil}
      attrs = %{name: "Updated"}

      # Step 1: Validate user access
      assert :ok = ValidationHelpers.validate_user_access(user, :update, item)

      # Step 2: Validate item access
      assert :ok = ValidationHelpers.validate_item_access(user, item)

      # Step 3: Validate update attrs
      assert :ok = ValidationHelpers.validate_update_attrs(attrs, item)
    end

    test "complete deletion validation flow" do
      user = %TestUser{id: 1, tenant_id: "tenant-1", admin: true, status: :active}

      # Must initialize list fields to avoid has_dependencies? check failing
      item = %TestItem{
        id: 1,
        tenant_id: "tenant-1",
        status: :inactive,
        system_critical: false,
        child_count: 0,
        dependencies: [],
        referenced_by: []
      }

      # Step 1: Validate user access for deletion
      assert :ok = ValidationHelpers.validate_user_access(user, :delete, item)

      # Step 2: Validate item access
      assert :ok = ValidationHelpers.validate_item_access(user, item)

      # Step 3: Validate deletion safety
      assert :ok = ValidationHelpers.validate_deletion_safety(item)
    end

    test "validation flow fails at first error" do
      user = %TestUser{id: 1, tenant_id: "tenant-1", admin: false, status: :suspended}
      item = %TestItem{id: 1, tenant_id: "tenant-1", status: :active}

      # Should fail at user access validation due to suspended status
      assert {:error, :access_denied} =
               ValidationHelpers.validate_user_access(user, :read, item)
    end
  end
end
