defmodule Indrajaal.Policy.UserRoleTest do
  use Indrajaal.DataCase
  import Indrajaal.PolicyComprehensiveFactory
  import Indrajaal.AccountsComprehensiveFactory
  alias Indrajaal.Accounts
  alias Indrajaal.Policy
  alias Indrajaal.Policy.UserRole

  describe "user role assignment" do
    setup do
      tenant = insert(:tenant)
      user = insert(:user, tenant_id: tenant.id)
      role = insert(:role, tenant_id: tenant.id)
      {:ok, tenant: tenant, user: user, role: role}
    end

    test "assigns role to __user", %{tenant: tenant, user: user, role: role} do
      attrs = %{
        user_id: user.id,
        role_id: role.id,
        tenant_id: tenant.id
      }

      assert {:ok, user_role} = Policy.create_user_role(attrs)
      assert user_role.user_id == user.id
      assert user_role.role_id == role.id
      assert user_role.tenant_id == tenant.id
      assert user_role.assigned_at != nil
      assert user_role.active == true
    end

    test "validates __required fields", %{tenant: tenant} do
      assert {:error, error} = Policy.create_user_role(%{tenant_id: tenant.id})
      error_msg = Exception.message(error)
      assert error_msg =~ "user_id: is __required"
      assert error_msg =~ "role_id: is __required"
    end

    test "prevents duplicate assignments",
         %{tenant: tenant, user: user, role: role} do
      attrs = %{
        user_id: user.id,
        role_id: role.id,
        tenant_id: tenant.id
      }

      assert {:ok, _} = Policy.create_user_role(attrs)
      assert {:error, error} = Policy.create_user_role(attrs)
      assert Exception.message(error) =~ "has already been taken"
    end

    test "validates user and role belong to same tenant", %{tenant: tenant} do
      other_tenant = insert(:tenant)
      user = insert(:user, tenant_id: tenant.id)
      role = insert(:role, tenant_id: other_tenant.id)

      assert {:error, error} =
               Policy.create_user_role(%{
                 user_id: user.id,
                 role_id: role.id,
                 tenant_id: tenant.id
               })

      assert Exception.message(error) =~ "must belong to the same tenant"
    end

    test "assigns role with expiration",
         %{tenant: tenant, user: user, role: role} do
      expires_at = DateTime.add(DateTime.utc_now(), 30 * 86_400, :second)

      attrs = %{
        user_id: user.id,
        role_id: role.id,
        tenant_id: tenant.id,
        expires_at: expires_at
      }

      assert {:ok, user_role} = Policy.create_user_role(attrs)
      assert user_role.expires_at != nil
      assert DateTime.compare(user_role.expires_at, expires_at) == :eq
    end

    test "assigns role with assigned_by",
         %{tenant: tenant, user: user, role: role} do
      admin = insert(:user, tenant_id: tenant.id)

      attrs = %{
        user_id: user.id,
        role_id: role.id,
        tenant_id: tenant.id,
        assigned_by: admin.id
      }

      assert {:ok, user_role} = Policy.create_user_role(attrs)
      assert user_role.assigned_by == admin.id
    end

    test "assigns role with metadata",
         %{tenant: tenant, user: user, role: role} do
      metadata = %{
        "assignment_reason" => "Department transfer",
        "approval_ticket" => "HR - 2025 - 001",
        "department" => "Engineering",
        "project" => "Security Enhancement"
      }

      attrs = %{
        user_id: user.id,
        role_id: role.id,
        tenant_id: tenant.id,
        metadata: metadata
      }

      assert {:ok, user_role} = Policy.create_user_role(attrs)
      assert user_role.metadata["assignment_reason"] == "Department transfer"
      assert user_role.metadata["department"] == "Engineering"
    end

    test "validates role hierarchy", %{tenant: tenant, user: user} do
      # Create role that __requires manager approval
      restricted_role =
        insert(:role,
          tenant_id: tenant.id,
          level: 80,
          metadata: %{"__requires_manager_approval" => true}
        )

      # Try to self - assign (should fail)
      assert {:error, error} =
               Policy.create_user_role(%{
                 user_id: user.id,
                 role_id: restricted_role.id,
                 tenant_id: tenant.id,
                 assigned_by: user.id
               })

      assert Exception.message(error) =~ "__requires manager approval"
    end

    test "enforces role level restrictions", %{tenant: tenant} do
      # Create low - level __user
      low_user = insert(:user, tenant_id: tenant.id, role: "viewer")

      # Create high - level role
      admin_role =
        insert(:role,
          tenant_id: tenant.id,
          level: 90,
          type: "administrative"
        )

      # Should validate user eligibility
      assert {:error, error} =
               Policy.create_user_role(%{
                 user_id: low_user.id,
                 role_id: admin_role.id,
                 tenant_id: tenant.id
               })

      assert Exception.message(error) =~ "__user not eligible for administrative
        role"
    end

    test "validates time - limited roles", %{tenant: tenant, user: user} do
      # Create time - limited role
      temp_role =
        insert(:role,
          tenant_id: tenant.id,
          time_limited: true,
          max_duration_hours: 8
        )

      # Must have expiration
      assert {:error, error} =
               Policy.create_user_role(%{
                 user_id: user.id,
                 role_id: temp_role.id,
                 tenant_id: tenant.id
               })

      assert Exception.message(error) =~ "time - limited role __requires expiration"

      # With valid expiration
      expires_at = DateTime.add(DateTime.utc_now(), 4 * 3600, :second)

      assert {:ok, user_role} =
               Policy.create_user_role(%{
                 user_id: user.id,
                 role_id: temp_role.id,
                 tenant_id: tenant.id,
                 expires_at: expires_at
               })

      assert user_role.expires_at != nil
    end
  end

  describe "user role updates" do
    setup do
      tenant = insert(:tenant)
      user = insert(:user, tenant_id: tenant.id)
      role = insert(:role, tenant_id: tenant.id)

      user_role =
        insert(:user_role,
          user_id: user.id,
          role_id: role.id,
          tenant_id: tenant.id
        )

      {:ok, tenant: tenant, user: user, role: role, user_role: user_role}
    end

    test "updates expiration", %{user_role: user_role} do
      new_expires = DateTime.add(DateTime.utc_now(), 60 * 86_400, :second)

      assert {:ok, updated} =
               Policy.update_user_role(user_role, %{
                 expires_at: new_expires
               })

      assert DateTime.compare(updated.expires_at, new_expires) == :eq
    end

    test "deactivates user role", %{user_role: user_role} do
      assert {:ok, updated} =
               Policy.update_user_role(user_role, %{
                 active: false,
                 deactivated_at: DateTime.utc_now(),
                 deactivation_reason: "Role no longer needed"
               })

      assert updated.active == false
      assert updated.deactivated_at != nil
    end

    test "updates metadata", %{user_role: user_role} do
      metadata =
        Map.merge(user_role.metadata || %{}, %{
          "last_review" => Date.utc_today(),
          "next_review" => Date.add(Date.utc_today(), 90),
          "review_notes" => "Approved for continued access"
        })

      assert {:ok, updated} =
               Policy.update_user_role(user_role, %{
                 metadata: metadata
               })

      assert updated.metadata["last_review"] == Date.utc_today()
    end

    test "prevents changing user or role", %{user_role: user_role} do
      other_user = insert(:user, tenant_id: user_role.tenant_id)

      assert {:error, error} =
               Policy.update_user_role(user_role, %{
                 user_id: other_user.id
               })

      assert Exception.message(error) =~ "cannot change user assignment"
    end

    test "validates expiration changes", %{user_role: user_role} do
      # Can't set expiration in the past
      past_date = DateTime.add(DateTime.utc_now(), -86_400, :second)

      assert {:error, error} =
               Policy.update_user_role(user_role, %{
                 expires_at: past_date
               })

      assert Exception.message(error) =~ "expiration must be in the future"
    end
  end

  describe "user role queries" do
    setup do
      tenant = insert(:tenant)
      users = bulk_create_users(tenant, 50)
      roles = bulk_create_roles(20, tenant: tenant)
      user_roles = bulk_create_user_roles(users, roles)

      {:ok, tenant: tenant, users: users, roles: roles, user_roles: user_roles}
    end

    test "lists roles for user", %{users: users} do
      user = List.first(users)

      roles = Policy.get_user_roles(user.id)
      assert length(roles) > 0
      assert Enum.all?(roles, &(&1.user_id == user.id))
    end

    test "lists users with role", %{roles: roles} do
      role = List.first(roles)

      users = Policy.get_users_with_role(role.id)
      assert length(users) > 0
    end

    test "lists active assignments", %{tenant: tenant} do
      # Create expired assignment
      user = insert(:user, tenant_id: tenant.id)
      role = insert(:role, tenant_id: tenant.id)

      insert(:user_role,
        user_id: user.id,
        role_id: role.id,
        tenant_id: tenant.id,
        expires_at: DateTime.add(DateTime.utc_now(), -86_400, :second)
      )

      active =
        Policy.list_user_roles!(
          tenant_id: tenant.id,
          filter: [active: true]
        )

      # Should not include expired
      assert Enum.all?(active, fn ur ->
               ur.active &&
                 (ur.expires_at == nil ||
                    DateTime.compare(ur.expires_at, DateTime.utc_now()) == :gt)
             end)
    end

    test "filters by expiration status", %{tenant: tenant} do
      # Get expiring soon (next 30 days)
      expiring_soon =
        Policy.list_user_roles!(
          tenant_id: tenant.id,
          filter: [
            expires_at: {:<=, DateTime.add(DateTime.utc_now(), 30 * 86_400, :second)},
            expires_at: {:>, DateTime.utc_now()}
          ]
        )

      assert Enum.all?(expiring_soon, &(&1.expires_at != nil))
    end

    test "filters by assignment date", %{tenant: tenant} do
      # Recent assignments (last 7 days)
      recent_date = DateTime.add(DateTime.utc_now(), -7 * 86_400, :second)

      recent =
        Policy.list_user_roles!(
          tenant_id: tenant.id,
          filter: [assigned_at: {:>=, recent_date}]
        )

      assert Enum.all?(recent, fn ur ->
               DateTime.compare(ur.assigned_at, recent_date) in [:gt, :eq]
             end)
    end

    test "searches by metadata", %{user_roles: user_roles} do
      # Update some with department
      ur = List.first(user_roles)

      Policy.update_user_role(ur, %{
        metadata: %{"department" => "Engineering"}
      })

      engineering =
        Policy.list_user_roles!(
          tenant_id: ur.tenant_id,
          filter: [metadata: {:contains, %{"department" => "Engineering"}}]
        )

      assert length(engineering) >= 1
    end

    test "paginates results", %{tenant: tenant} do
      page1 =
        Policy.list_user_roles!(
          tenant_id: tenant.id,
          page: [limit: 20, offset: 0]
        )

      page2 =
        Policy.list_user_roles!(
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

  describe "effective permissions" do
    setup do
      tenant = insert(:tenant)
      user = insert(:user, tenant_id: tenant.id)
      permissions = bulk_create_permissions(tenant, 50)
      {:ok, tenant: tenant, user: user, permissions: permissions}
    end

    test "calculates __user's effective permissions", %{
      tenant: tenant,
      user: user,
      permissions: permissions
    } do
      # Create multiple roles with different permissions
      role1 = insert(:role, tenant_id: tenant.id, name: "Role 1")
      role2 = insert(:role, tenant_id: tenant.id, name: "Role 2")

      # Assign permissions to roles
      perms1 = Enum.take(permissions, 20)
      perms2 = Enum.take(Enum.drop(permissions, 10), 20)

      for perm <- perms1 do
        Policy.create_role_permission(%{
          role_id: role1.id,
          permission_id: perm.id
        })
      end

      for perm <- perms2 do
        Policy.create_role_permission(%{
          role_id: role2.id,
          permission_id: perm.id
        })
      end

      # Assign both roles to __user
      Policy.create_user_role(%{
        user_id: user.id,
        role_id: role1.id,
        tenant_id: tenant.id
      })

      Policy.create_user_role(%{
        user_id: user.id,
        role_id: role2.id,
        tenant_id: tenant.id
      })

      # Get effective permissions (should be union)
      effective = Policy.get_user_effective_permissions(user.id)
      assert length(effective) >= 20
      # Some overlap expected
      assert length(effective) <= 30
    end

    test "excludes permissions from inactive roles", %{
      tenant: tenant,
      user: user,
      permissions: permissions
    } do
      active_role = insert(:role, tenant_id: tenant.id, active: true)
      inactive_role = insert(:role, tenant_id: tenant.id, active: false)

      # Assign same permission to both
      perm = List.first(permissions)

      for role <- [active_role, inactive_role] do
        Policy.create_role_permission(%{
          role_id: role.id,
          permission_id: perm.id
        })

        Policy.create_user_role(%{
          user_id: user.id,
          role_id: role.id,
          tenant_id: tenant.id
        })
      end

      # Should only get permission from active role
      effective = Policy.get_user_effective_permissions(user.id)
      perm_sources = Enum.filter(effective, &(&1.id == perm.id))
      assert length(perm_sources) == 1
    end

    test "respects role expiration",
         %{tenant: tenant, user: user, permissions: permissions} do
      # Create expired and active assignments
      role1 = insert(:role, tenant_id: tenant.id)
      role2 = insert(:role, tenant_id: tenant.id)

      perm = List.first(permissions)

      for role <- [role1, role2] do
        Policy.create_role_permission(%{
          role_id: role.id,
          permission_id: perm.id
        })
      end

      # Expired assignment
      Policy.create_user_role(%{
        user_id: user.id,
        role_id: role1.id,
        tenant_id: tenant.id,
        expires_at: DateTime.add(DateTime.utc_now(), -86_400, :second)
      })

      # Active assignment
      Policy.create_user_role(%{
        user_id: user.id,
        role_id: role2.id,
        tenant_id: tenant.id
      })

      # Should only get permission from active assignment
      effective = Policy.get_user_effective_permissions(user.id)
      assert Enum.any?(effective, &(&1.id == perm.id))
    end

    test "applies permission conditions",
         %{tenant: tenant, user: user, permissions: permissions} do
      role = insert(:role, tenant_id: tenant.id)
      perm = List.first(permissions)

      # Create role permission with conditions
      Policy.create_role_permission(%{
        role_id: role.id,
        permission_id: perm.id,
        conditions: %{
          "business_hours_only" => true,
          "__require_vpn" => true
        }
      })

      Policy.create_user_role(%{
        user_id: user.id,
        role_id: role.id,
        tenant_id: tenant.id
      })

      # Get permissions with conditions
      effective = Policy.get_user_effective_permissions(user.id, include_conditions: true)

      perm_with_conditions = Enum.find(effective, &(&1.id == perm.id))
      assert perm_with_conditions.conditions["business_hours_only"] == true
      assert perm_with_conditions.conditions["__require_vpn"] == true
    end
  end

  describe "user role statistics" do
    setup do
      tenant = insert(:tenant)
      users = bulk_create_users(tenant, 100)
      roles = bulk_create_roles(50, tenant: tenant)
      user_roles = bulk_create_user_roles(users, roles)

      {:ok, tenant: tenant, users: users, roles: roles, user_roles: user_roles}
    end

    test "counts roles per user", %{users: users} do
      counts = Policy.count_roles_per_user(user_ids: Enum.map(users, & &1.id))

      assert map_size(counts) == length(users)
      assert Enum.all?(Map.values(counts), &(&1 > 0))
    end

    test "identifies users with multiple roles", %{tenant: tenant} do
      multi_role_users =
        Policy.find_users_with_multiple_roles(
          tenant_id: tenant.id,
          min_roles: 2
        )

      assert length(multi_role_users) > 0
      assert Enum.all?(multi_role_users, &(&1.role_count >= 2))
    end

    test "finds users without roles", %{tenant: tenant} do
      # Create user with no roles
      no_role_user = insert(:user, tenant_id: tenant.id)

      users_without_roles = Policy.find_users_without_roles(tenant_id: tenant.id)
      assert Enum.any?(users_without_roles, &(&1.id == no_role_user.id))
    end

    test "analyzes role assignment patterns", %{tenant: tenant} do
      analysis = Policy.analyze_role_assignment_patterns(tenant_id: tenant.id)

      assert Map.has_key?(analysis, :average_roles_per_user)
      assert Map.has_key?(analysis, :most_assigned_roles)
      assert Map.has_key?(analysis, :least_assigned_roles)
      assert Map.has_key?(analysis, :role_combination_frequency)
      assert Map.has_key?(analysis, :assignment_trends)
    end

    test "identifies role assignment anomalies",
         %{tenant: tenant, users: users} do
      # Create user with unusual number of roles
      anomaly_user = List.first(users)

      # Assign many roles
      roles = bulk_create_roles(10, tenant: tenant)

      for role <- roles do
        Policy.create_user_role(%{
          user_id: anomaly_user.id,
          role_id: role.id,
          tenant_id: tenant.id
        })
      end

      anomalies =
        Policy.find_role_assignment_anomalies(
          tenant_id: tenant.id,
          # More than 5 roles is anomaly
          threshold: 5
        )

      assert Enum.any?(anomalies, &(&1.user_id == anomaly_user.id))
    end

    test "tracks role assignment history", %{user_roles: user_roles} do
      user_role = List.first(user_roles)

      # Deactivate and reactivate
      Policy.update_user_role(user_role, %{active: false})
      Policy.update_user_role(user_role, %{active: true})

      history =
        Policy.get_user_role_history(
          user_id: user_role.user_id,
          role_id: user_role.role_id
        )

      # Create, deactivate, reactivate
      assert length(history) >= 3
    end
  end

  describe "bulk user role operations" do
    setup do
      tenant = insert(:tenant)
      users = bulk_create_users(tenant, 20)
      roles = bulk_create_roles(10, tenant: tenant)
      {:ok, tenant: tenant, users: users, roles: roles}
    end

    test "bulk assigns role to users", %{users: users, roles: roles} do
      role = List.first(roles)
      user_ids = Enum.map(Enum.take(users, 10), & &1.id)

      assert {:ok, count} =
               Policy.bulk_assign_role_to_users(
                 role_id: role.id,
                 user_ids: user_ids,
                 assigned_by: "hr_system",
                 metadata: %{"bulk_assignment" => true}
               )

      assert count == 10

      # Verify assignments
      users_with_role = Policy.get_users_with_role(role.id)
      assert length(users_with_role) >= 10
    end

    test "bulk assigns roles to user", %{users: users, roles: roles} do
      user = List.first(users)
      role_ids = Enum.map(Enum.take(roles, 5), & &1.id)

      assert {:ok, count} =
               Policy.bulk_assign_roles_to_user(
                 user_id: user.id,
                 role_ids: role_ids,
                 assigned_by: "onboarding_system"
               )

      assert count == 5

      # Verify assignments
      user_roles = Policy.get_user_roles(user.id)
      assert length(user_roles) == 5
    end

    test "bulk expires assignments", %{users: users, roles: roles, tenant: tenant} do
      # Create assignments
      role = List.first(roles)
      selected_users = Enum.take(users, 5)

      user_role_ids =
        for user <- selected_users do
          {:ok, ur} =
            Policy.create_user_role(%{
              user_id: user.id,
              role_id: role.id,
              tenant_id: tenant.id
            })

          ur.id
        end

      # Bulk expire
      assert {:ok, count} =
               Policy.bulk_expire_user_roles(
                 filter: [id: {:in, user_role_ids}],
                 expire_at: DateTime.utc_now()
               )

      assert count == 5

      # Verify expired
      expired = Policy.list_user_roles!(filter: [id: {:in, user_role_ids}])
      assert Enum.all?(expired, &(&1.active == false))
    end

    test "bulk removes roles from department", %{tenant: tenant} do
      # Create users in specific department
      dept_users =
        for _i <- 1..5 do
          insert(:user,
            tenant_id: tenant.id,
            metadata: %{"department" => "Finance"}
          )
        end

      # Assign role
      role = insert(:role, tenant_id: tenant.id)

      for user <- dept_users do
        Policy.create_user_role(%{
          user_id: user.id,
          role_id: role.id,
          tenant_id: tenant.id,
          metadata: %{"department" => "Finance"}
        })
      end

      # Remove role from Finance department
      assert {:ok, count} =
               Policy.bulk_remove_role_by_metadata(
                 tenant_id: tenant.id,
                 role_id: role.id,
                 metadata_filter: %{"department" => "Finance"}
               )

      assert count == 5
    end
  end

  describe "user role validation" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "validates conflicting roles", %{tenant: tenant} do
      user = insert(:user, tenant_id: tenant.id)

      # Create mutually exclusive roles
      role1 =
        insert(:role,
          tenant_id: tenant.id,
          name: "Approver",
          metadata: %{"excludes" => ["Requester"]}
        )

      role2 =
        insert(:role,
          tenant_id: tenant.id,
          name: "Requester",
          metadata: %{"excludes" => ["Approver"]}
        )

      # Assign first role
      assert {:ok, _} =
               Policy.create_user_role(%{
                 user_id: user.id,
                 role_id: role1.id,
                 tenant_id: tenant.id
               })

      # Try to assign conflicting role
      assert {:error, error} =
               Policy.create_user_role(%{
                 user_id: user.id,
                 role_id: role2.id,
                 tenant_id: tenant.id
               })

      assert Exception.message(error) =~ "conflicts with existing role"
    end

    test "validates maximum roles per __user", %{tenant: tenant} do
      user = insert(:user, tenant_id: tenant.id)

      # Create and assign maximum roles
      for i <- 1..5 do
        role = insert(:role, tenant_id: tenant.id, name: "Role #{i}")

        Policy.create_user_role(%{
          user_id: user.id,
          role_id: role.id,
          tenant_id: tenant.id
        })
      end

      # Try to exceed limit
      extra_role = insert(:role, tenant_id: tenant.id)

      assert {:error, error} =
               Policy.create_user_role(%{
                 user_id: user.id,
                 role_id: extra_role.id,
                 tenant_id: tenant.id
               })

      assert Exception.message(error) =~ "maximum number of roles"
    end

    test "validates role eligibility __requirements", %{tenant: tenant} do
      # Create user without __required training
      user =
        insert(:user,
          tenant_id: tenant.id,
          metadata: %{"training_completed" => false}
        )

      # Create role __requiring training
      role =
        insert(:role,
          tenant_id: tenant.id,
          metadata: %{"__requires_training" => true}
        )

      assert {:error, error} =
               Policy.create_user_role(%{
                 user_id: user.id,
                 role_id: role.id,
                 tenant_id: tenant.id
               })

      assert Exception.message(error) =~ "__required training not completed"
    end

    test "validates location - based role restrictions", %{tenant: tenant} do
      # Create user in different location
      user =
        insert(:user,
          tenant_id: tenant.id,
          metadata: %{"location" => "Remote"}
        )

      # Create office - only role
      role =
        insert(:role,
          tenant_id: tenant.id,
          metadata: %{"location_restricted" => true, "allowed_locations" => ["HQ", "Branch"]}
        )

      assert {:error, error} =
               Policy.create_user_role(%{
                 user_id: user.id,
                 role_id: role.id,
                 tenant_id: tenant.id
               })

      assert Exception.message(error) =~ "__user location not allowed for role"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
