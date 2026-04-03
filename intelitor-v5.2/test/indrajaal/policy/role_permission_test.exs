defmodule Indrajaal.Policy.RolePermissionTest do
  use Indrajaal.DataCase
  import Indrajaal.PolicyComprehensiveFactory
  alias Indrajaal.Policy
  alias Indrajaal.Policy.RolePermission

  describe "role permission assignment" do
    setup do
      tenant = insert(:tenant)
      role = insert(:role, tenant_id: tenant.id)
      permission = insert(:permission, tenant_id: tenant.id)
      {:ok, tenant: tenant, role: role, permission: permission}
    end

    test "assigns permission to role", %{role: role, permission: permission} do
      attrs = %{
        role_id: role.id,
        permission_id: permission.id
      }

      assert {:ok, role_perm} = Policy.create_role_permission(attrs)
      assert role_perm.role_id == role.id
      assert role_perm.permission_id == permission.id
      assert role_perm.granted_at != nil
    end

    test "validates __required fields" do
      assert {:error, error} = Policy.create_role_permission(%{})
      error_msg = Exception.message(error)
      assert error_msg =~ "role_id: is __required"
      assert error_msg =~ "permission_id: is __required"
    end

    test "pr__events duplicate assignments",
         %{role: role, permission: permission} do
      attrs = %{
        role_id: role.id,
        permission_id: permission.id
      }

      assert {:ok, _} = Policy.create_role_permission(attrs)
      assert {:error, error} = Policy.create_role_permission(attrs)
      assert Exception.message(error) =~ "has already been taken"
    end

    test "validates role and permission belong to same tenant",
         %{tenant: tenant} do
      other_tenant = insert(:tenant)
      role = insert(:role, tenant_id: tenant.id)
      permission = insert(:permission, tenant_id: other_tenant.id)

      assert {:error, error} =
               Policy.create_role_permission(%{
                 role_id: role.id,
                 permission_id: permission.id
               })

      assert Exception.message(error) =~ "must belong to the same tenant"
    end

    test "assigns permission with conditions",
         %{role: role, permission: permission} do
      conditions = %{
        "business_hours_only" => true,
        "__require_approval" => true,
        "max_uses_per_day" => 10
      }

      attrs = %{
        role_id: role.id,
        permission_id: permission.id,
        conditions: conditions
      }

      assert {:ok, role_perm} = Policy.create_role_permission(attrs)
      assert role_perm.conditions["business_hours_only"] == true
      assert role_perm.conditions["max_uses_per_day"] == 10
    end

    test "assigns permission with granted_by",
         %{role: role, permission: permission} do
      admin_user = insert(:user, tenant_id: role.tenant_id)

      attrs = %{
        role_id: role.id,
        permission_id: permission.id,
        granted_by: admin_user.id
      }

      assert {:ok, role_perm} = Policy.create_role_permission(attrs)
      assert role_perm.granted_by == admin_user.id
    end

    test "assigns permission with metadata",
         %{role: role, permission: permission} do
      metadata = %{
        "reason" => "Required for job function",
        "approval_ticket" => "TICK - 1234",
        "review_date" => "2025 - 07 - 31"
      }

      attrs = %{
        role_id: role.id,
        permission_id: permission.id,
        metadata: metadata
      }

      assert {:ok, role_perm} = Policy.create_role_permission(attrs)
      assert role_perm.metadata["reason"] == "Required for job function"
      assert role_perm.metadata["approval_ticket"] == "TICK - 1234"
    end

    test "validates permission compatibility", %{tenant: tenant, role: role} do
      # Create conflicting permissions
      {:ok, perm1} =
        Policy.create_permission(%{
          name: "data.delete",
          category: "__data",
          tenant_id: tenant.id
        })

      {:ok, perm2} =
        Policy.create_permission(%{
          name: "data.protect",
          category: "__data",
          conflicts_with: ["data.delete"],
          tenant_id: tenant.id
        })

      # Assign first permission
      assert {:ok, _} =
               Policy.create_role_permission(%{
                 role_id: role.id,
                 permission_id: perm1.id
               })

      # Try to assign conflicting permission
      assert {:error, error} =
               Policy.create_role_permission(%{
                 role_id: role.id,
                 permission_id: perm2.id
               })

      assert Exception.message(error) =~ "conflicts with existing role
        permissions"
    end

    test "enforces permission dependencies", %{tenant: tenant, role: role} do
      # Create dependent permissions
      {:ok, base_perm} =
        Policy.create_permission(%{
          name: "reports.view",
          category: "reports",
          tenant_id: tenant.id
        })

      {:ok, dependent_perm} =
        Policy.create_permission(%{
          name: "reports.export",
          category: "reports",
          depends_on: ["reports.view"],
          tenant_id: tenant.id
        })

      # Try to assign dependent without base
      assert {:error, error} =
               Policy.create_role_permission(%{
                 role_id: role.id,
                 permission_id: dependent_perm.id
               })

      assert Exception.message(error) =~ "__requires permission: reports.view"

      # Assign base first, then dependent
      assert {:ok, _} =
               Policy.create_role_permission(%{
                 role_id: role.id,
                 permission_id: base_perm.id
               })

      assert {:ok, _} =
               Policy.create_role_permission(%{
                 role_id: role.id,
                 permission_id: dependent_perm.id
               })
    end

    test "respects role type restrictions", %{tenant: tenant} do
      # Create read - only role
      read_only_role =
        insert(:role,
          tenant_id: tenant.id,
          type: "read_only",
          read_only: true
        )

      # Create write permission
      write_perm =
        insert(:permission,
          tenant_id: tenant.id,
          name: "data.write",
          category: "__data"
        )

      # Try to assign write permission to read - only role
      assert {:error, error} =
               Policy.create_role_permission(%{
                 role_id: read_only_role.id,
                 permission_id: write_perm.id
               })

      assert Exception.message(error) =~ "read - only role cannot have write
        permissions"
    end
  end

  describe "role permission removal" do
    setup do
      tenant = insert(:tenant)
      role = insert(:role, tenant_id: tenant.id)
      permissions = bulk_create_permissions(tenant, 10)

      # Assign some permissions
      role_perms =
        Enum.map(Enum.take(permissions, 5), fn perm ->
          {:ok, rp} =
            Policy.create_role_permission(%{
              role_id: role.id,
              permission_id: perm.id
            })

          rp
        end)

      {:ok, tenant: tenant, role: role, permissions: permissions, role_perms: role_perms}
    end

    test "removes permission from role", %{role_perms: role_perms} do
      role_perm = List.first(role_perms)

      assert {:ok, _} = Policy.delete_role_permission(role_perm)

      # Verify deleted
      assert Policy.get_role_permission(role_perm.id) == nil
    end

    test "removes multiple permissions",
         %{role: role, role_perms: role_perms} do
      perm_ids = Enum.map(Enum.take(role_perms, 3), & &1.permission_id)

      assert {:ok, count} = Policy.remove_permissions_from_role(role, perm_ids)
      assert count == 3

      # Verify removed
      remaining = Policy.get_role_permissions(role.id)
      assert length(remaining) == 2
    end

    test "handles cascading removals", %{tenant: tenant, role: role} do
      # Create dependent permissions
      {:ok, base} =
        Policy.create_permission(%{
          name: "admin.access",
          category: "admin",
          tenant_id: tenant.id
        })

      {:ok, dep1} =
        Policy.create_permission(%{
          name: "admin.__users",
          category: "admin",
          depends_on: ["admin.access"],
          tenant_id: tenant.id
        })

      {:ok, dep2} =
        Policy.create_permission(%{
          name: "admin.__users.delete",
          category: "admin",
          depends_on: ["admin.access", "admin.__users"],
          tenant_id: tenant.id
        })

      # Assign all permissions
      for perm <- [base, dep1, dep2] do
        Policy.create_role_permission(%{
          role_id: role.id,
          permission_id: perm.id
        })
      end

      # Remove base permission should cascade
      assert {:ok, removed} = Policy.remove_permission_cascade(role.id, base.id)
      assert removed == 3

      # Verify all removed
      remaining = Policy.get_role_permissions(role.id)
      assert Enum.empty?(remaining)
    end
  end

  describe "role permission queries" do
    setup do
      tenant = insert(:tenant)
      roles = bulk_create_roles(tenant, 20)
      permissions = bulk_create_permissions(tenant, 50)
      role_permissions = bulk_create_role_permissions(roles, permissions)

      {:ok,
       tenant: tenant, roles: roles, permissions: permissions, role_permissions: role_permissions}
    end

    test "lists permissions for role", %{roles: roles} do
      role = List.first(roles)

      perms = Policy.get_role_permissions(role.id)
      assert length(perms) > 0
      assert Enum.all?(perms, &(&1.tenant_id == role.tenant_id))
    end

    test "lists roles with permission", %{permissions: permissions} do
      permission = List.first(permissions)

      roles = Policy.get_roles_with_permission(permission.id)
      assert length(roles) > 0
    end

    test "checks if role has permission",
         %{roles: roles, role_permissions: role_permissions} do
      role_perm = List.first(role_permissions)

      assert Policy.role_has_permission?(
               role_perm.role_id,
               role_perm.permission_id
             )

      # Check non - existent
      refute Policy.role_has_permission?(
               Ecto.UUID.generate(),
               Ecto.UUID.generate()
             )
    end

    test "gets effective permissions for role", %{tenant: tenant} do
      # Create role hierarchy
      parent_role = insert(:role, tenant_id: tenant.id, name: "Parent Role")

      child_role =
        insert(:role,
          tenant_id: tenant.id,
          name: "Child Role",
          parent_role_id: parent_role.id
        )

      # Create permissions
      parent_perms = bulk_create_permissions(tenant, 5)
      child_perms = bulk_create_permissions(tenant, 3)

      # Assign to parent
      for perm <- parent_perms do
        Policy.create_role_permission(%{
          role_id: parent_role.id,
          permission_id: perm.id
        })
      end

      # Assign to child
      for perm <- child_perms do
        Policy.create_role_permission(%{
          role_id: child_role.id,
          permission_id: perm.id
        })
      end

      # Get effective permissions (should include inherited)
      effective = Policy.get_effective_permissions(child_role.id)
      assert length(effective) == 8
    end

    test "filters role permissions by conditions", %{roles: roles} do
      role = List.first(roles)

      # Create permissions with different conditions
      perm1 = insert(:permission, tenant_id: role.tenant_id)
      perm2 = insert(:permission, tenant_id: role.tenant_id)
      perm3 = insert(:permission, tenant_id: role.tenant_id)

      Policy.create_role_permission(%{
        role_id: role.id,
        permission_id: perm1.id,
        conditions: %{"business_hours_only" => true}
      })

      Policy.create_role_permission(%{
        role_id: role.id,
        permission_id: perm2.id,
        conditions: %{"__require_approval" => true}
      })

      Policy.create_role_permission(%{
        role_id: role.id,
        permission_id: perm3.id,
        conditions: %{}
      })

      # Filter by condition
      business_hours =
        Policy.get_role_permissions(
          role.id,
          filter: [conditions: {:has_key, "business_hours_only"}]
        )

      assert length(business_hours) == 1
    end

    test "gets permission grant history",
         %{role_permissions: role_permissions} do
      role_perm = List.first(role_permissions)

      history =
        Policy.get_permission_grant_history(
          role_id: role_perm.role_id,
          permission_id: role_perm.permission_id
        )

      assert length(history) >= 1

      grant = List.first(history)
      assert grant.action == "grant"
      assert grant.role_permission_id == role_perm.id
    end
  end

  describe "role permission statistics" do
    setup do
      tenant = insert(:tenant)
      roles = bulk_create_roles(tenant, 50)
      permissions = bulk_create_permissions(tenant, 100)
      role_permissions = bulk_create_role_permissions(roles, permissions)

      {:ok,
       tenant: tenant, roles: roles, permissions: permissions, role_permissions: role_permissions}
    end

    test "counts permissions per role", %{roles: roles} do
      counts = Policy.count_permissions_per_role(role_ids: Enum.map(roles, & &1.id))

      assert map_size(counts) == length(roles)
      assert Enum.all?(Map.values(counts), &(&1 > 0))
    end

    test "identifies over - privileged roles", %{tenant: tenant} do
      # Roles with too many permissions
      over_privileged =
        Policy.find_over_privileged_roles(
          tenant_id: tenant.id,
          # More than 70 permissions
          threshold: 70
        )

      # High - level roles should have many permissions
      assert length(over_privileged) > 0
      assert Enum.all?(over_privileged, &(&1.permission_count > 70))
    end

    test "identifies under - privileged roles", %{tenant: tenant} do
      # Create role with no permissions
      empty_role = insert(:role, tenant_id: tenant.id, name: "Empty Role")

      under_privileged =
        Policy.find_under_privileged_roles(
          tenant_id: tenant.id,
          # Less than 5 permissions
          threshold: 5
        )

      assert Enum.any?(under_privileged, &(&1.id == empty_role.id))
    end

    test "analyzes permission distribution", %{tenant: tenant} do
      distribution = Policy.analyze_permission_distribution(tenant_id: tenant.id)

      assert Map.has_key?(distribution, :average_permissions_per_role)
      assert Map.has_key?(distribution, :median_permissions_per_role)
      assert Map.has_key?(distribution, :most_granted_permissions)
      assert Map.has_key?(distribution, :least_granted_permissions)
      assert Map.has_key?(distribution, :permission_coverage)
    end

    test "finds unused permissions", %{tenant: tenant} do
      # Create permission not assigned to any role
      unused_perm =
        insert(:permission,
          tenant_id: tenant.id,
          name: "unused.permission"
        )

      unused = Policy.find_unused_permissions(tenant_id: tenant.id)
      assert Enum.any?(unused, &(&1.id == unused_perm.id))
    end

    test "analyzes permission conflicts in roles", %{tenant: tenant} do
      # Create role with conflicting permissions
      role = insert(:role, tenant_id: tenant.id)

      {:ok, delete_perm} =
        Policy.create_permission(%{
          name: "test.delete",
          category: "test",
          tenant_id: tenant.id
        })

      {:ok, readonly_perm} =
        Policy.create_permission(%{
          name: "test.readonly",
          category: "test",
          conflicts_with: ["test.delete"],
          tenant_id: tenant.id
        })

      # Force assign both (bypassing validation for test)
      Policy.create_role_permission(%{
        role_id: role.id,
        permission_id: delete_perm.id
      })

      Policy.create_role_permission(%{
        role_id: role.id,
        permission_id: readonly_perm.id
      })

      conflicts = Policy.analyze_role_permission_conflicts(tenant_id: tenant.id)
      assert length(conflicts) > 0
    end
  end

  describe "bulk role permission operations" do
    setup do
      tenant = insert(:tenant)
      roles = bulk_create_roles(tenant, 10)
      permissions = bulk_create_permissions(tenant, 20)
      {:ok, tenant: tenant, roles: roles, permissions: permissions}
    end

    test "bulk assigns permissions to role",
         %{roles: roles, permissions: permissions} do
      role = List.first(roles)
      perm_ids = Enum.map(Enum.take(permissions, 10), & &1.id)

      assert {:ok, count} =
               Policy.bulk_assign_permissions_to_role(
                 role_id: role.id,
                 permission_ids: perm_ids,
                 granted_by: "bulk_admin"
               )

      assert count == 10

      # Verify assignments
      assigned = Policy.get_role_permissions(role.id)
      assert length(assigned) == 10
    end

    test "bulk assigns permission to multiple roles",
         %{roles: roles, permissions: permissions} do
      permission = List.first(permissions)
      role_ids = Enum.map(Enum.take(roles, 5), & &1.id)

      assert {:ok, count} =
               Policy.bulk_assign_permission_to_roles(
                 permission_id: permission.id,
                 role_ids: role_ids,
                 granted_by: "security_admin"
               )

      assert count == 5

      # Verify assignments
      roles_with_perm = Policy.get_roles_with_permission(permission.id)
      assert length(roles_with_perm) >= 5
    end

    test "bulk updates role permission conditions",
         %{roles: roles, permissions: permissions} do
      role = List.first(roles)

      # First assign permissions
      perm_ids = Enum.map(Enum.take(permissions, 5), & &1.id)

      Policy.bulk_assign_permissions_to_role(
        role_id: role.id,
        permission_ids: perm_ids
      )

      # Update conditions
      new_conditions = %{
        "reviewed" => true,
        "review_date" => Date.utc_today(),
        "next_review" => Date.add(Date.utc_today(), 90)
      }

      assert {:ok, count} =
               Policy.bulk_update_role_permissions(
                 filter: [role_id: role.id],
                 attributes: %{conditions: new_conditions}
               )

      assert count == 5

      # Verify update
      updated = Policy.get_role_permissions(role.id)
      assert Enum.all?(updated, &(&1.conditions["reviewed"] == true))
    end

    test "bulk removes stale permissions", %{tenant: tenant} do
      # Create role with old permissions
      role = insert(:role, tenant_id: tenant.id)

      old_perms =
        for i <- 1..5 do
          perm = insert(:permission, tenant_id: tenant.id)

          {:ok, rp} =
            Policy.create_role_permission(%{
              role_id: role.id,
              permission_id: perm.id,
              granted_at: DateTime.add(DateTime.utc_now(), -365 * 86_400, :second)
            })

          rp
        end

      # Remove permissions older than 180 days
      cutoff = DateTime.add(DateTime.utc_now(), -180 * 86_400, :second)

      assert {:ok, count} =
               Policy.bulk_remove_stale_permissions(
                 tenant_id: tenant.id,
                 granted_before: cutoff
               )

      assert count >= 5
    end
  end

  describe "role permission validation" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "validates role level __requirements", %{tenant: tenant} do
      # Create low - level role
      low_role = insert(:role, tenant_id: tenant.id, level: 30)

      # Create high - level permission
      high_perm =
        insert(:permission,
          tenant_id: tenant.id,
          name: "admin.critical_action",
          risk_level: "critical",
          metadata: %{"min_role_level" => 80}
        )

      # Should fail - role level too low
      assert {:error, error} =
               Policy.create_role_permission(%{
                 role_id: low_role.id,
                 permission_id: high_perm.id
               })

      assert Exception.message(error) =~ "role level too low for permission"
    end

    test "validates time - limited role restrictions", %{tenant: tenant} do
      # Create time - limited role
      temp_role =
        insert(:role,
          tenant_id: tenant.id,
          time_limited: true,
          max_duration_hours: 8
        )

      # Create permanent permission
      perm =
        insert(:permission,
          tenant_id: tenant.id,
          metadata: %{"permanent_only" => true}
        )

      # Should fail - time - limited role can't have permanent permissions
      assert {:error, error} =
               Policy.create_role_permission(%{
                 role_id: temp_role.id,
                 permission_id: perm.id
               })

      assert Exception.message(error) =~ "time - limited role cannot have
        permanent permissions"
    end

    test "validates API - only role restrictions", %{tenant: tenant} do
      # Create API - only role
      api_role =
        insert(:role,
          tenant_id: tenant.id,
          api_only: true
        )

      # Create UI - only permission
      ui_perm =
        insert(:permission,
          tenant_id: tenant.id,
          metadata: %{"ui_only" => true}
        )

      # Should fail
      assert {:error, error} =
               Policy.create_role_permission(%{
                 role_id: api_role.id,
                 permission_id: ui_perm.id
               })

      assert Exception.message(error) =~ "API role cannot have UI permissions"
    end

    test "validates circular dependencies", %{tenant: tenant} do
      # Create permissions with circular dependency
      {:ok, perm_a} =
        Policy.create_permission(%{
          name: "perm.a",
          category: "test",
          tenant_id: tenant.id
        })

      {:ok, perm_b} =
        Policy.create_permission(%{
          name: "perm.b",
          category: "test",
          depends_on: ["perm.a"],
          tenant_id: tenant.id
        })

      # Try to update perm_a to depend on perm_b (circular)
      assert {:error, error} =
               Policy.update_permission(perm_a, %{
                 depends_on: ["perm.b"]
               })

      assert Exception.message(error) =~ "circular dependency detected"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
