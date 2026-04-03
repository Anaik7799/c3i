defmodule Indrajaal.Policy.RoleTest do
  use Indrajaal.DataCase
  import Indrajaal.PolicyComprehensiveFactory
  import Indrajaal.AccountsComprehensiveFactory
  alias Indrajaal.Policy
  alias Indrajaal.Policy.Role

  describe "role creation" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "creates role with valid attributes", %{tenant: tenant} do
      attrs = %{
        name: "Security Administrator",
        description: "Full access to security settings",
        level: 80,
        tenant_id: tenant.id
      }

      assert {:ok, role} = Policy.create_role(attrs)
      assert role.name == "Security Administrator"
      assert role.description == "Full access to security settings"
      assert role.level == 80
      assert role.tenant_id == tenant.id
      assert role.active == true
    end

    test "validates required fields", %{tenant: tenant} do
      assert {:error, error} = Policy.create_role(%{tenant_id: tenant.id})
      error_msg = Exception.message(error)
      assert error_msg =~ "name: is required"
    end

    test "validates name uniqueness within tenant", %{tenant: tenant} do
      attrs = %{
        name: "Unique Role",
        tenant_id: tenant.id
      }

      assert {:ok, _role1} = Policy.create_role(attrs)
      assert {:error, error} = Policy.create_role(attrs)
      assert Exception.message(error) =~ "name: has already been taken"
    end

    test "allows same name across tenants" do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)

      attrs1 = %{name: "Admin Role", tenant_id: tenant1.id}
      attrs2 = %{name: "Admin Role", tenant_id: tenant2.id}

      assert {:ok, role1} = Policy.create_role(attrs1)
      assert {:ok, role2} = Policy.create_role(attrs2)
      assert role1.name == role2.name
      assert role1.tenant_id != role2.tenant_id
    end

    test "validates role level", %{tenant: tenant} do
      # Valid levels (0 - 100)
      valid_levels = [0, 25, 50, 75, 100]

      for level <- valid_levels do
        attrs = %{
          name: "Role Level #{level}",
          level: level,
          tenant_id: tenant.id
        }

        assert {:ok, role} = Policy.create_role(attrs)
        assert role.level == level
      end

      # Invalid levels
      invalid_levels = [-1, 101, 150]

      for level <- invalid_levels do
        attrs = %{
          name: "Invalid Level",
          level: level,
          tenant_id: tenant.id
        }

        assert {:error, _} = Policy.create_role(attrs)
      end
    end

    test "creates role with type", %{tenant: tenant} do
      types = ["system", "administrative", "operational", "read_only", "limited"]

      for type <- types do
        attrs = %{
          name: "#{String.capitalize(type)} Role",
          type: type,
          tenant_id: tenant.id
        }

        assert {:ok, role} = Policy.create_role(attrs)
        assert role.type == type
      end
    end

    test "creates system role", %{tenant: tenant} do
      attrs = %{
        name: "System Admin",
        system_role: true,
        level: 100,
        tenant_id: tenant.id
      }

      assert {:ok, role} = Policy.create_role(attrs)
      assert role.system_role == true
      assert role.level == 100
    end

    test "creates role with security __requirements", %{tenant: tenant} do
      attrs = %{
        name: "High Security Role",
        __requires_mfa: true,
        ip_restricted: true,
        time_limited: true,
        max_duration_hours: 8,
        tenant_id: tenant.id
      }

      assert {:ok, role} = Policy.create_role(attrs)
      assert role.__requires_mfa == true
      assert role.ip_restricted == true
      assert role.time_limited == true
      assert role.max_duration_hours == 8
    end

    test "creates read - only role", %{tenant: tenant} do
      attrs = %{
        name: "Auditor",
        read_only: true,
        audit_access: true,
        tenant_id: tenant.id
      }

      assert {:ok, role} = Policy.create_role(attrs)
      assert role.read_only == true
      assert role.audit_access == true
    end

    test "creates API - only role", %{tenant: tenant} do
      attrs = %{
        name: "API Service",
        api_only: true,
        level: 50,
        tenant_id: tenant.id
      }

      assert {:ok, role} = Policy.create_role(attrs)
      assert role.api_only == true
    end

    test "creates role with expiration", %{tenant: tenant} do
      expires_at = DateTime.add(DateTime.utc_now(), 30 * 86_400, :second)

      attrs = %{
        name: "Temporary Role",
        type: "temporary",
        expires_at: expires_at,
        tenant_id: tenant.id
      }

      assert {:ok, role} = Policy.create_role(attrs)
      assert role.expires_at != nil
      assert DateTime.compare(role.expires_at, expires_at) == :eq
    end

    test "creates role with metadata", %{tenant: tenant} do
      metadata = %{
        "department" => "Security",
        "cost_center" => "SEC - 001",
        "approval_required" => true
      }

      attrs = %{
        name: "Department Role",
        metadata: metadata,
        tenant_id: tenant.id
      }

      assert {:ok, role} = Policy.create_role(attrs)
      assert role.metadata["department"] == "Security"
      assert role.metadata["approval_required"] == true
    end
  end

  describe "role updates" do
    setup do
      tenant = insert(:tenant)
      role = insert(:role, tenant_id: tenant.id)
      {:ok, tenant: tenant, role: role}
    end

    test "updates role details", %{role: role} do
      attrs = %{
        name: "Updated Role Name",
        description: "Updated description",
        level: 75
      }

      assert {:ok, updated} = Policy.update_role(role, attrs)
      assert updated.name == "Updated Role Name"
      assert updated.description == "Updated description"
      assert updated.level == 75
    end

    test "updates security __requirements", %{role: role} do
      attrs = %{
        __requires_mfa: true,
        ip_restricted: true,
        time_limited: true,
        max_duration_hours: 4
      }

      assert {:ok, updated} = Policy.update_role(role, attrs)
      assert updated.__requires_mfa == true
      assert updated.max_duration_hours == 4
    end

    test "deactivates role", %{role: role} do
      assert {:ok, updated} = Policy.update_role(role, %{active: false})
      assert updated.active == false
    end

    test "prevents system role modification", %{tenant: tenant} do
      system_role =
        insert(:role,
          tenant_id: tenant.id,
          system_role: true,
          name: "System Admin"
        )

      assert {:error, error} =
               Policy.update_role(system_role, %{
                 level: 50
               })

      assert Exception.message(error) =~ "cannot modify system role"
    end

    test "validates level changes", %{role: role} do
      # Valid update
      assert {:ok, updated} = Policy.update_role(role, %{level: 60})
      assert updated.level == 60

      # Invalid level
      assert {:error, _} = Policy.update_role(role, %{level: 150})
    end
  end

  describe "role queries" do
    setup do
      tenant = insert(:tenant)
      roles = bulk_create_roles(tenant, 50)
      {:ok, tenant: tenant, roles: roles}
    end

    test "lists all roles for tenant", %{tenant: tenant, roles: roles} do
      result = Policy.list_roles!(tenant_id: tenant.id)
      assert length(result) >= length(roles)
      assert Enum.all?(result, &(&1.tenant_id == tenant.id))
    end

    test "filters active roles", %{tenant: tenant} do
      # Create inactive role
      insert(:role, tenant_id: tenant.id, active: false)

      active_roles =
        Policy.list_roles!(
          tenant_id: tenant.id,
          filter: [active: true]
        )

      assert Enum.all?(active_roles, &(&1.active == true))
    end

    test "filters by type", %{tenant: tenant} do
      # Create specific type
      admin_role =
        insert(:role,
          tenant_id: tenant.id,
          type: "administrative"
        )

      admin_roles =
        Policy.list_roles!(
          tenant_id: tenant.id,
          filter: [type: "administrative"]
        )

      assert Enum.any?(admin_roles, &(&1.id == admin_role.id))
    end

    test "filters by level range", %{tenant: tenant} do
      # Get high - level roles (70+)
      high_level_roles =
        Policy.list_roles!(
          tenant_id: tenant.id,
          filter: [level: {:>=, 70}]
        )

      assert Enum.all?(high_level_roles, &(&1.level >= 70))

      # Get mid - level roles (40 - 60)
      mid_level_roles =
        Policy.list_roles!(
          tenant_id: tenant.id |> Enum.filter(&(&1.level >= 40 && &1.level <= 60))
        )

      assert length(mid_level_roles) > 0
    end

    test "filters system roles", %{tenant: tenant} do
      # Create system role
      system_role =
        insert(:role,
          tenant_id: tenant.id,
          system_role: true
        )

      system_roles =
        Policy.list_roles!(
          tenant_id: tenant.id,
          filter: [system_role: true]
        )

      assert Enum.any?(system_roles, &(&1.id == system_role.id))
    end

    test "filters roles __requiring MFA", %{tenant: tenant} do
      mfa_roles =
        Policy.list_roles!(
          tenant_id: tenant.id,
          filter: [__requires_mfa: true]
        )

      assert Enum.all?(mfa_roles, &(&1.__requires_mfa == true))
    end

    test "filters expired roles", %{tenant: tenant} do
      # Create expired role
      expired_role =
        insert(:role,
          tenant_id: tenant.id,
          expires_at: DateTime.add(DateTime.utc_now(), -86_400, :second)
        )

      # Get non - expired roles
      now = DateTime.utc_now()

      active_roles =
        Policy.list_roles!(
          tenant_id:
            tenant.id
            |> Enum.filter(fn r ->
              r.expires_at == nil || DateTime.compare(r.expires_at, now) == :gt
            end)
        )

      refute Enum.any?(active_roles, &(&1.id == expired_role.id))
    end

    test "sorts by level descending", %{tenant: tenant} do
      roles =
        Policy.list_roles!(
          tenant_id: tenant.id,
          sort: [level: :desc, name: :asc]
        )

      levels = Enum.map(roles, & &1.level)
      assert levels == Enum.sort(levels, :desc)
    end

    test "sorts by name", %{tenant: tenant} do
      roles =
        Policy.list_roles!(
          tenant_id: tenant.id,
          sort: [name: :asc]
        )

      names = Enum.map(roles, & &1.name)
      assert names == Enum.sort(names)
    end

    test "paginates results", %{tenant: tenant} do
      page1 =
        Policy.list_roles!(
          tenant_id: tenant.id,
          page: [limit: 20, offset: 0]
        )

      page2 =
        Policy.list_roles!(
          tenant_id: tenant.id,
          page: [limit: 20, offset: 20]
        )

      assert length(page1) == 20
      assert length(page2) >= 10

      # No overlap
      page1_ids = MapSet.new(page1, & &1.id)
      page2_ids = MapSet.new(page2, & &1.id)
      assert MapSet.disjoint?(page1_ids, page2_ids)
    end
  end

  describe "role hierarchy" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "compares role levels", %{tenant: tenant} do
      admin = insert(:role, tenant_id: tenant.id, level: 90)
      operator = insert(:role, tenant_id: tenant.id, level: 50)
      viewer = insert(:role, tenant_id: tenant.id, level: 30)

      assert Policy.role_has_higher_level?(admin, operator)
      assert Policy.role_has_higher_level?(operator, viewer)
      refute Policy.role_has_higher_level?(viewer, admin)
    end

    test "checks role subordination", %{tenant: tenant} do
      manager = insert(:role, tenant_id: tenant.id, level: 80, type: "management")
      supervisor = insert(:role, tenant_id: tenant.id, level: 70, type: "supervisory")
      operator = insert(:role, tenant_id: tenant.id, level: 50, type: "operational")

      assert Policy.is_subordinate_role?(operator, supervisor)
      assert Policy.is_subordinate_role?(supervisor, manager)
      assert Policy.is_subordinate_role?(operator, manager)
      refute Policy.is_subordinate_role?(manager, operator)
    end

    test "gets role inheritance chain", %{tenant: tenant} do
      # Create role hierarchy
      roles = [
        insert(:role, tenant_id: tenant.id, name: "CEO", level: 100),
        insert(:role, tenant_id: tenant.id, name: "Director", level: 80),
        insert(:role, tenant_id: tenant.id, name: "Manager", level: 60),
        insert(:role, tenant_id: tenant.id, name: "Supervisor", level: 40),
        insert(:role, tenant_id: tenant.id, name: "Operator", level: 20)
      ]

      operator = List.last(roles)
      chain = Policy.get_role_inheritance_chain(operator.id)

      # Should include all roles with higher levels
      assert length(chain) == 4
      assert Enum.all?(chain, &(&1.level > operator.level))
    end
  end

  describe "role permissions" do
    setup do
      tenant = insert(:tenant)
      role = insert(:role, tenant_id: tenant.id)
      permissions = bulk_create_permissions(tenant, 20)
      {:ok, tenant: tenant, role: role, permissions: permissions}
    end

    test "assigns permissions to role",
         %{role: role, permissions: permissions} do
      selected_perms = Enum.take(permissions, 5)

      assert {:ok, updated_role} =
               Policy.assign_permissions_to_role(
                 role,
                 Enum.map(selected_perms, & &1.id)
               )

      # Verify permissions assigned
      role_perms = Policy.get_role_permissions(role.id)
      assert length(role_perms) == 5
    end

    test "removes permissions from role",
         %{role: role, permissions: permissions} do
      # First assign permissions
      perm_ids = Enum.map(Enum.take(permissions, 5), & &1.id)
      {:ok, _} = Policy.assign_permissions_to_role(role, perm_ids)

      # Remove some permissions
      to_remove = Enum.take(perm_ids, 2)
      assert {:ok, _} = Policy.remove_permissions_from_role(role, to_remove)

      # Verify removed
      remaining = Policy.get_role_permissions(role.id)
      assert length(remaining) == 3
    end

    test "prevents duplicate permission assignment",
         %{role: role, permissions: permissions} do
      perm = List.first(permissions)

      # Assign once
      assert {:ok, _} = Policy.assign_permissions_to_role(role, [perm.id])

      # Try to assign again
      assert {:error, error} = Policy.assign_permissions_to_role(role, [perm.id])
      assert Exception.message(error) =~ "already assigned"
    end

    test "validates permission compatibility", %{tenant: tenant, role: role} do
      # Create conflicting permissions
      {:ok, perm1} =
        Policy.create_permission(%{
          name: "__users.delete",
          category: "__users",
          tenant_id: tenant.id
        })

      {:ok, perm2} =
        Policy.create_permission(%{
          name: "__users.read_only",
          category: "__users",
          conflicts_with: ["__users.delete"],
          tenant_id: tenant.id
        })

      # Assign first permission
      assert {:ok, _} = Policy.assign_permissions_to_role(role, [perm1.id])

      # Try to assign conflicting permission
      assert {:error, error} = Policy.assign_permissions_to_role(role, [perm2.id])
      assert Exception.message(error) =~ "conflicts with existing permissions"
    end
  end

  describe "role statistics" do
    setup do
      tenant = insert(:tenant)
      roles = bulk_create_roles(tenant, 50)
      users = bulk_create_users(tenant, 100)
      permissions = bulk_create_permissions(tenant, 50)
      user_roles = bulk_create_user_roles(users, roles)
      role_permissions = bulk_create_role_permissions(roles, permissions)

      {:ok,
       tenant: tenant,
       roles: roles,
       users: users,
       permissions: permissions,
       user_roles: user_roles,
       role_permissions: role_permissions}
    end

    test "counts __users per role", %{roles: roles} do
      role = List.first(roles)

      __user_count = Policy.count_users_with_role(role.id)
      assert __user_count > 0
    end

    test "gets role distribution", %{tenant: tenant} do
      distribution = Policy.get_role_distribution(tenant_id: tenant.id)

      assert Map.has_key?(distribution, "administrative")
      assert Map.has_key?(distribution, "operational")
      assert Map.has_key?(distribution, "read_only")

      total = Enum.sum(Map.values(distribution))
      assert total > 0
    end

    test "identifies unused roles", %{tenant: tenant, roles: roles} do
      # Create role with no __users
      unused_role = insert(:role, tenant_id: tenant.id, name: "Unused Role")

      unused = Policy.find_unused_roles(tenant_id: tenant.id)
      assert Enum.any?(unused, &(&1.id == unused_role.id))
    end

    test "calculates average permissions per role", %{tenant: tenant} do
      stats = Policy.role_statistics(tenant_id: tenant.id)

      assert stats.total_roles > 0
      assert stats.active_roles > 0
      assert stats.average_permissions_per_role > 0
      assert Map.has_key?(stats, :roles_by_type)
      assert Map.has_key?(stats, :roles_by_level)
    end

    test "finds overlapping roles",
         %{tenant: tenant, permissions: permissions} do
      # Create two roles with similar permissions
      perm_ids = Enum.map(Enum.take(permissions, 10), & &1.id)

      role1 = insert(:role, tenant_id: tenant.id, name: "Role A")
      role2 = insert(:role, tenant_id: tenant.id, name: "Role B")

      # Assign same permissions to both
      {:ok, _} = Policy.assign_permissions_to_role(role1, perm_ids)
      {:ok, _} = Policy.assign_permissions_to_role(role2, Enum.take(perm_ids, 8))

      overlapping = Policy.find_overlapping_roles(tenant_id: tenant.id, threshold: 0.7)

      # Should find these roles as overlapping (80% overlap)
      assert length(overlapping) > 0
    end
  end

  describe "bulk operations" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "bulk creates roles", %{tenant: tenant} do
      roles = bulk_create_roles(tenant, 50)

      assert length(roles) == 50
      assert Enum.all?(roles, &(&1.tenant_id == tenant.id))

      # Verify distribution
      by_type = Enum.group_by(roles, & &1.type)
      assert map_size(by_type) >= 4

      by_level =
        Enum.group_by(roles, fn r ->
          cond do
            r.level >= 80 -> :high
            r.level >= 50 -> :medium
            true -> :low
          end
        end)

      assert Map.has_key?(by_level, :high)
      assert Map.has_key?(by_level, :medium)
      assert Map.has_key?(by_level, :low)
    end

    test "bulk updates roles", %{tenant: tenant} do
      roles = bulk_create_roles(tenant, 10)
      role_ids = Enum.map(roles, & &1.id)

      assert {:ok, count} =
               Policy.bulk_update_roles(
                 filter: [id: {:in, role_ids}],
                 attributes: %{
                   metadata: %{"bulk_updated" => true, "updated_at" => DateTime.utc_now()}
                 }
               )

      assert count == 10

      # Verify update
      updated = Policy.list_roles!(filter: [id: {:in, role_ids}])
      assert Enum.all?(updated, &(&1.metadata["bulk_updated"] == true))
    end

    test "bulk deactivates roles", %{tenant: tenant} do
      roles = bulk_create_roles(tenant, 5)
      role_ids = Enum.map(roles, & &1.id)

      assert {:ok, count} =
               Policy.bulk_update_roles(
                 filter: [id: {:in, role_ids}],
                 attributes: %{active: false}
               )

      assert count == 5

      # Verify all inactive
      updated = Policy.list_roles!(filter: [id: {:in, role_ids}])
      assert Enum.all?(updated, &(&1.active == false))
    end
  end

  describe "role validation" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "validates role name format", %{tenant: tenant} do
      valid_names = [
        "Admin",
        "Security Officer",
        "API_Service",
        "Role-123",
        "24 / 7 Operator"
      ]

      for name <- valid_names do
        attrs = %{name: name, tenant_id: tenant.id}
        assert {:ok, _} = Policy.create_role(attrs)
      end

      invalid_names = [
        # empty
        "",
        # too short
        "a",
        # too long
        String.duplicate("a", 101),
        # invalid character
        "Role@Admin",
        # only spaces
        "   "
      ]

      for name <- invalid_names do
        attrs = %{name: name, tenant_id: tenant.id}
        assert {:error, _} = Policy.create_role(attrs)
      end
    end

    test "validates role constraints", %{tenant: tenant} do
      # Can't have both read_only and high level
      assert {:error, error} =
               Policy.create_role(%{
                 name: "Invalid Role",
                 read_only: true,
                 level: 90,
                 tenant_id: tenant.id
               })

      assert Exception.message(error) =~ "read - only roles cannot have high
        privileges"

      # API - only roles can't require MFA
      assert {:error, error} =
               Policy.create_role(%{
                 name: "Invalid API Role",
                 api_only: true,
                 __requires_mfa: true,
                 tenant_id: tenant.id
               })

      assert Exception.message(error) =~ "API roles cannot require MFA"
    end

    test "validates time - limited roles", %{tenant: tenant} do
      # Time - limited must have max_duration
      assert {:error, error} =
               Policy.create_role(%{
                 name: "Time Limited",
                 time_limited: true,
                 tenant_id: tenant.id
               })

      assert Exception.message(error) =~ "max_duration_hours is __required"

      # Valid time - limited role
      assert {:ok, role} =
               Policy.create_role(%{
                 name: "Time Limited Valid",
                 time_limited: true,
                 max_duration_hours: 8,
                 tenant_id: tenant.id
               })

      assert role.time_limited == true
      assert role.max_duration_hours == 8
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
