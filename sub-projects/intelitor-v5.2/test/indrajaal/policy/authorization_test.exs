defmodule Indrajaal.Policy.AuthorizationTest do
  use Indrajaal.DataCase

  alias Indrajaal.Accounts.User
  alias Indrajaal.Core.Tenant
  alias Indrajaal.Policy.{Role, Permission, RolePermission, UserRole, AccessRule}
  alias Indrajaal.Sites.Site

  describe "Policy and Authorization System" do
    setup do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant: tenant)

      {:ok, tenant: tenant, organization: organization}
    end

    test "creates role with permissions", %{tenant: tenant} do
      # Create role
      {:ok, admin_role} =
        Role.create(%{
          name: "security_admin",
          description: "Security system administrator",
          level: 100,
          tenant_id: tenant.id
        })

      assert admin_role.name == "security_admin"
      assert admin_role.level == 100
      assert admin_role.active? == true

      # Create permissions
      permissions = [
        %{name: "sites.create", description: "Create sites"},
        %{name: "sites.read", description: "Read sites"},
        %{name: "sites.update", description: "Update sites"},
        %{name: "sites.delete", description: "Delete sites"},
        %{name: "devices.manage", description: "Manage devices"},
        %{name: "alarms.respond", description: "Respond to alarms"}
      ]

      created_permissions =
        for perm_attrs <- permissions do
          {:ok, permission} = Permission.create(Map.put(perm_attrs, :tenant_id, tenant.id))
          permission
        end

      # Assign permissions to role
      for permission <- created_permissions do
        {:ok, _role_perm} =
          RolePermission.create(%{
            role_id: admin_role.id,
            permission_id: permission.id,
            tenant_id: tenant.id
          })
      end

      # Verify role has permissions
      role_with_perms = Role.read!(admin_role.id, load: [:permissions])
      assert length(role_with_perms.permissions) == 6

      permission_names = Enum.map(role_with_perms.permissions, & &1.name)
      assert "sites.create" in permission_names
      assert "devices.manage" in permission_names
      assert "alarms.respond" in permission_names
    end

    test "assigns roles to users with hierarchy", %{tenant: tenant} do
      # Create hierarchical roles
      {:ok, admin_role} =
        Role.create(%{
          name: "admin",
          description: "System Administrator",
          level: 100,
          tenant_id: tenant.id
        })

      {:ok, manager_role} =
        Role.create(%{
          name: "manager",
          description: "Site Manager",
          level: 50,
          parent_role_id: admin_role.id,
          tenant_id: tenant.id
        })

      {:ok, operator_role} =
        Role.create(%{
          name: "operator",
          description: "Security Operator",
          level: 10,
          parent_role_id: manager_role.id,
          tenant_id: tenant.id
        })

      # Create users
      admin_user = insert(:user, tenant: tenant)
      manager_user = insert(:user, tenant: tenant)
      operator_user = insert(:user, tenant: tenant)

      # Assign roles
      {:ok, _admin_assignment} =
        UserRole.create(%{
          user_id: admin_user.id,
          role_id: admin_role.id,
          tenant_id: tenant.id
        })

      {:ok, _manager_assignment} =
        UserRole.create(%{
          user_id: manager_user.id,
          role_id: manager_role.id,
          tenant_id: tenant.id
        })

      {:ok, _operator_assignment} =
        UserRole.create(%{
          user_id: operator_user.id,
          role_id: operator_role.id,
          tenant_id: tenant.id
        })

      # Verify role hierarchy
      manager_with_parent = Role.read!(manager_role.id, load: [:parent_role])
      assert manager_with_parent.parent_role.id == admin_role.id

      admin_with_children = Role.read!(admin_role.id, load: [:child_roles])
      assert length(admin_with_children.child_roles) == 1
      assert Enum.any?(admin_with_children.child_roles, &(&1.id == manager_role.id))
    end

    test "creates resource - specific access rules",
         %{tenant: tenant, organization: organization} do
      # Create site for testing
      site = insert(:site, tenant: tenant, organization: organization)

      # Create user and role
      user = insert(:user, tenant: tenant)

      site_manager_role =
        insert(:role,
          name: "site_manager",
          tenant: tenant
        )

      insert(:user_role,
        user: user,
        role: site_manager_role,
        tenant: tenant
      )

      # Create access rule for specific site
      {:ok, access_rule} =
        AccessRule.create(%{
          resource_type: "Site",
          resource_id: site.id,
          permission_type: "full_access",
          access_level: :write,
          conditions: %{
            "site_access" => true,
            "business_hours_only" => false
          },
          tenant_id: tenant.id
        })

      assert access_rule.resource_type == "Site"
      assert access_rule.resource_id == site.id
      assert access_rule.permission_type == "full_access"
      assert access_rule.access_level == :write
      assert access_rule.conditions["site_access"] == true
    end

    test "validates permission inheritance", %{tenant: tenant} do
      # Create parent permission
      {:ok, parent_perm} =
        Permission.create(%{
          name: "sites.manage",
          description: "Full site management",
          tenant_id: tenant.id
        })

      # Create child permissions that inherit from parent
      child_permissions = [
        %{name: "sites.create", parent_permission_id: parent_perm.id},
        %{name: "sites.update", parent_permission_id: parent_perm.id},
        %{name: "sites.delete", parent_permission_id: parent_perm.id}
      ]

      created_children =
        for child_attrs <- child_permissions do
          full_attrs =
            Map.merge(child_attrs, %{
              description: "Child permission",
              tenant_id: tenant.id
            })

          {:ok, child} = Permission.create(full_attrs)
          child
        end

      # Verify inheritance
      parent_with_children = Permission.read!(parent_perm.id, load: [:child_permissions])
      assert length(parent_with_children.child_permissions) == 3

      for child <- created_children do
        child_with_parent = Permission.read!(child.id, load: [:parent_permission])
        assert child_with_parent.parent_permission.id == parent_perm.id
      end
    end

    test "enforces temporal access restrictions", %{tenant: tenant} do
      user = insert(:user, tenant: tenant)
      role = insert(:role, tenant: tenant)

      # Create time - limited role assignment
      start_time = DateTime.utc_now()
      # 1 hour
      end_time = DateTime.utc_now() |> DateTime.add(3600, :second)

      {:ok, user_role} =
        UserRole.create(%{
          user_id: user.id,
          role_id: role.id,
          valid_from: start_time,
          valid_until: end_time,
          tenant_id: tenant.id
        })

      assert user_role.valid_from == start_time
      assert user_role.valid_until == end_time
      assert user_role.active? == true

      # Test expiration calculation
      user_role_with_calc = UserRole.read!(user_role.id, load: [:is_expired?])
      assert user_role_with_calc.is_expired? == false

      # Test with expired assignment
      expired_assignment =
        insert(:user_role,
          user: user,
          role: role,
          # 1 hour ago
          valid_until: DateTime.utc_now() |> DateTime.add(-3600, :second),
          tenant: tenant
        )

      expired_with_calc = UserRole.read!(expired_assignment.id, load: [:is_expired?])
      assert expired_with_calc.is_expired? == true
    end

    test "implements attribute - based access control (ABAC)", %{
      tenant: tenant,
      organization: organization
    } do
      # Create site with specific attributes
      site =
        insert(:site,
          security_level: :high,
          site_type: :office,
          tenant: tenant,
          organization: organization
        )

      # Create user with clearance attributes
      user =
        insert(:user,
          tenant: tenant,
          settings: %{
            "security_clearance" => "high",
            "department" => "security",
            "shift" => "day"
          }
        )

      # Create ABAC access rule
      {:ok, abac_rule} =
        AccessRule.create(%{
          resource_type: "Site",
          resource_id: site.id,
          permission_type: "abac_access",
          access_level: :read,
          conditions: %{
            "__user.security_clearance" => "high",
            "__user.department" => "security",
            "resource.security_level" => "high",
            "time_constraints" => %{
              "business_hours_only" => true
            }
          },
          tenant_id: tenant.id
        })

      # Verify ABAC rule structure
      assert abac_rule.conditions["__user.security_clearance"] == "high"
      assert abac_rule.conditions["resource.security_level"] == "high"

      assert abac_rule.conditions["time_constraints"]["business_hours_only"] ==
               true
    end

    test "manages dynamic role assignments", %{tenant: tenant} do
      user = insert(:user, tenant: tenant)

      emergency_role =
        insert(:role,
          name: "emergency_responder",
          tenant: tenant
        )

      # Assign emergency role temporarily
      {:ok, emergency_assignment} =
        UserRole.assign_temporary(user, %{
          role_id: emergency_role.id,
          duration_minutes: 60,
          reason: "Emergency response activation"
        })

      assert emergency_assignment.temporary? == true
      assert emergency_assignment.valid_until != nil
      assert emergency_assignment.metadata["reason"] == "Emergency response
        activation"

      # Test automatic expiration
      expired_time = DateTime.utc_now() |> DateTime.add(-3600, :second)

      {:ok, expired_assignment} =
        UserRole.update(emergency_assignment, %{
          valid_until: expired_time
        })

      expired_with_calc = UserRole.read!(expired_assignment.id, load: [:is_expired?])
      assert expired_with_calc.is_expired? == true
    end

    test "validates role level restrictions", %{tenant: tenant} do
      # High - level role
      admin_role =
        insert(:role,
          name: "admin",
          level: 100,
          tenant: tenant
        )

      # Lower - level role
      operator_role =
        insert(:role,
          name: "operator",
          level: 10,
          tenant: tenant
        )

      # Admin can create high - level permissions
      {:ok, high_perm} =
        Permission.create(%{
          name: "system.admin",
          description: "System administration",
          __required_level: 90,
          tenant_id: tenant.id
        })

      # Assign high permission to admin role (should succeed)
      {:ok, _admin_role_perm} =
        RolePermission.create(%{
          role_id: admin_role.id,
          permission_id: high_perm.id,
          tenant_id: tenant.id
        })

      # Assign high permission to operator role (should fail validation)
      {:error, changeset} =
        RolePermission.create(%{
          role_id: operator_role.id,
          permission_id: high_perm.id,
          tenant_id: tenant.id
        })

      assert changeset.errors[:role_id] || changeset.errors[:permission_id]
    end

    test "tracks permission usage and auditing", %{tenant: tenant} do
      user = insert(:user, tenant: tenant)

      permission =
        insert(:permission,
          name: "sites.create",
          tenant: tenant
        )

      # Log permission usage
      {:ok, usage_record} =
        Permission.log_usage(permission, %{
          user_id: user.id,
          action: "site_creation",
          resource_id: "site_123",
          result: "success",
          __context: %{
            "ip_address" => "192.168.1.100",
            "__user_agent" => "Mozilla / 5.0...",
            "timestamp" => DateTime.utc_now()
          }
        })

      # Verify usage tracking
      assert usage_record.metadata["usage_log"]
      usage_entry = List.first(usage_record.metadata["usage_log"])
      assert usage_entry["__user_id"] == user.id
      assert usage_entry["action"] == "site_creation"
      assert usage_entry["result"] == "success"
    end

    test "implements geo - fencing access control",
         %{tenant: tenant, organization: organization} do
      # Create site with location
      site =
        insert(:site,
          coordinates: %{"lat" => 37.7749, "lng" => -122.4194},
          tenant: tenant,
          organization: organization
        )

      # Create geo - fenced access rule
      {:ok, geo_rule} =
        AccessRule.create(%{
          resource_type: "Site",
          resource_id: site.id,
          permission_type: "location_based",
          access_level: :read,
          conditions: %{
            "geo_fence" => %{
              "center_lat" => 37.7749,
              "center_lng" => -122.4194,
              "radius_meters" => 100
            },
            "__require_physical_presence" => true
          },
          tenant_id: tenant.id
        })

      assert geo_rule.conditions["geo_fence"]["radius_meters"] == 100
      assert geo_rule.conditions["__require_physical_presence"] == true
    end

    test "enforces tenant isolation in authorization", %{tenant: tenant} do
      tenant2 = insert(:tenant)

      # Create roles in different tenants
      role1 = insert(:role, tenant: tenant)
      role2 = insert(:role, tenant: tenant2)

      permission1 = insert(:permission, tenant: tenant)
      permission2 = insert(:permission, tenant: tenant2)

      # Verify tenant isolation in queries
      tenant1_roles = Role.read!(tenant: tenant)
      tenant2_roles = Role.read!(tenant: tenant2)

      assert length(tenant1_roles) == 1
      assert length(tenant2_roles) == 1
      assert Enum.any?(tenant1_roles, &(&1.id == role1.id))
      assert Enum.any?(tenant2_roles, &(&1.id == role2.id))
      refute Enum.any!(tenant1_roles, &(&1.id == role2.id))
      refute Enum.any!(tenant2_roles, &(&1.id == role1.id))

      # Cross - tenant permission assignment should fail
      {:error, changeset} =
        RolePermission.create(%{
          role_id: role1.id,
          # Different tenant
          permission_id: permission2.id,
          tenant_id: tenant.id
        })

      assert changeset.errors[:permission_id] || changeset.errors[:role_id]
    end

    test "calculates effective permissions for user", %{tenant: tenant} do
      user = insert(:user, tenant: tenant)

      # Create role hierarchy
      admin_role = insert(:role, name: "admin", level: 100, tenant: tenant)

      manager_role =
        insert(:role, name: "manager", level: 50, parent_role_id: admin_role.id, tenant: tenant)

      # Create permissions
      admin_perm = insert(:permission, name: "admin.all", tenant: tenant)
      manager_perm = insert(:permission, name: "sites.manage", tenant: tenant)

      # Assign permissions to roles
      insert(:role_permission, role: admin_role, permission: admin_perm, tenant: tenant)
      insert(:role_permission, role: manager_role, permission: manager_perm, tenant: tenant)

      # Assign user to manager role
      insert(:user_role, user: user, role: manager_role, tenant: tenant)

      # Calculate effective permissions
      user_with_perms = User.read!(user.id, load: [:effective_permissions])
      permission_names = Enum.map(user_with_perms.effective_permissions, & &1.name)

      # Should have manager permissions and inherited admin permissions
      assert "sites.manage" in permission_names
      # Inherited from parent role
      assert "admin.all" in permission_names
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
