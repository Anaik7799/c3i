defmodule Indrajaal.Policy.PermissionTest do
  use Indrajaal.DataCase
  import Indrajaal.PolicyComprehensiveFactory
  alias Indrajaal.Policy
  alias Indrajaal.Policy.Permission

  describe "permission creation" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "creates permission with valid attributes", %{tenant: tenant} do
      attrs = %{
        name: "__users.view_all",
        category: "__users",
        description: "View all __users in the system",
        tenant_id: tenant.id
      }

      assert {:ok, permission} = Policy.create_permission(attrs)
      assert permission.name == "__users.view_all"
      assert permission.category == "__users"
      assert permission.description == "View all __users in the system"
      assert permission.tenant_id == tenant.id
      assert permission.active == true
    end

    test "validates required fields", %{tenant: tenant} do
      assert {:error, error} = Policy.create_permission(%{tenant_id: tenant.id})
      error_msg = Exception.message(error)
      assert error_msg =~ "name: is required"
      assert error_msg =~ "category: is required"
    end

    test "validates name format", %{tenant: tenant} do
      # Valid formats
      valid_names = [
        "__users.view",
        "devices.update_all",
        "system.manage_configuration",
        "reports.export.pdf",
        "api.v2.access"
      ]

      for name <- valid_names do
        attrs = %{
          name: name,
          category: name |> String.split(".") |> List.first(),
          tenant_id: tenant.id
        }

        assert {:ok, perm} = Policy.create_permission(attrs)
        assert perm.name == name
      end

      # Invalid formats
      invalid_names = [
        # no category separator
        "invalid",
        # starts with dot
        ".invalid",
        # ends with dot
        "invalid.",
        # uppercase
        "USERS.VIEW",
        # contains space
        "__users view",
        # double dots
        "__users..view"
      ]

      for name <- invalid_names do
        attrs = %{name: name, category: "test", tenant_id: tenant.id}
        assert {:error, _} = Policy.create_permission(attrs)
      end
    end

    test "validates name uniqueness within tenant", %{tenant: tenant} do
      attrs = %{
        name: "__users.manage",
        category: "__users",
        tenant_id: tenant.id
      }

      assert {:ok, _perm1} = Policy.create_permission(attrs)
      assert {:error, error} = Policy.create_permission(attrs)
      assert Exception.message(error) =~ "name: has already been taken"
    end

    test "allows same name across tenants" do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)

      attrs1 = %{
        name: "__users.view",
        category: "__users",
        tenant_id: tenant1.id
      }

      attrs2 = %{
        name: "__users.view",
        category: "__users",
        tenant_id: tenant2.id
      }

      assert {:ok, perm1} = Policy.create_permission(attrs1)
      assert {:ok, perm2} = Policy.create_permission(attrs2)
      assert perm1.name == perm2.name
      assert perm1.tenant_id != perm2.tenant_id
    end

    test "creates permission with risk level", %{tenant: tenant} do
      risk_levels = ["low", "medium", "high", "critical"]

      for risk <- risk_levels do
        attrs = %{
          name: "test.#{risk}_risk",
          category: "test",
          risk_level: risk,
          tenant_id: tenant.id
        }

        assert {:ok, perm} = Policy.create_permission(attrs)
        assert perm.risk_level == risk
      end
    end

    test "creates permission with security __requirements", %{tenant: tenant} do
      attrs = %{
        name: "system.delete_all",
        category: "system",
        risk_level: "critical",
        __requires_mfa: true,
        __requires_approval: true,
        tenant_id: tenant.id
      }

      assert {:ok, perm} = Policy.create_permission(attrs)
      assert perm.__requires_mfa == true
      assert perm.__requires_approval == true
    end

    test "creates permission with conditions", %{tenant: tenant} do
      conditions = %{
        "time_ranges" => ["08:00 - 18:00"],
        "days_of_week" => ["mon", "tue", "wed", "thu", "fri"],
        "ip_whitelist" => ["192.168.1.0 / 24"]
      }

      attrs = %{
        name: "office.access",
        category: "physical",
        conditions: conditions,
        tenant_id: tenant.id
      }

      assert {:ok, perm} = Policy.create_permission(attrs)
      assert perm.conditions["time_ranges"] == ["08:00 - 18:00"]
      assert "mon" in perm.conditions["days_of_week"]
    end

    test "creates permission with metadata", %{tenant: tenant} do
      metadata = %{
        "actions" => ["read", "list"],
        "resource_type" => "__user_profile",
        "audit_level" => "detailed",
        "compliance_tags" => ["GDPR", "HIPAA"]
      }

      attrs = %{
        name: "__users.view_profile",
        category: "__users",
        metadata: metadata,
        tenant_id: tenant.id
      }

      assert {:ok, perm} = Policy.create_permission(attrs)
      assert "read" in perm.metadata["actions"]
      assert "GDPR" in perm.metadata["compliance_tags"]
    end

    test "creates permission with conflicts", %{tenant: tenant} do
      # Create first permission
      {:ok, perm1} =
        Policy.create_permission(%{
          name: "__users.delete",
          category: "__users",
          tenant_id: tenant.id
        })

      # Create conflicting permission
      attrs = %{
        name: "__users.protect",
        category: "__users",
        conflicts_with: ["__users.delete"],
        tenant_id: tenant.id
      }

      assert {:ok, perm2} = Policy.create_permission(attrs)
      assert "__users.delete" in perm2.conflicts_with
    end
  end

  describe "permission updates" do
    setup do
      tenant = insert(:tenant)
      permission = insert(:permission, tenant_id: tenant.id)
      {:ok, tenant: tenant, permission: permission}
    end

    test "updates permission details", %{permission: permission} do
      attrs = %{
        description: "Updated description",
        risk_level: "high",
        __requires_mfa: true
      }

      assert {:ok, updated} = Policy.update_permission(permission, attrs)
      assert updated.description == "Updated description"
      assert updated.risk_level == "high"
      assert updated.__requires_mfa == true
    end

    test "updates permission conditions", %{permission: permission} do
      conditions = %{
        "max_uses_per_day" => 100,
        "__require_reason" => true
      }

      assert {:ok, updated} =
               Policy.update_permission(permission, %{
                 conditions: conditions
               })

      assert updated.conditions["max_uses_per_day"] == 100
      assert updated.conditions["__require_reason"] == true
    end

    test "deactivates permission", %{permission: permission} do
      assert {:ok, updated} =
               Policy.update_permission(permission, %{
                 active: false
               })

      assert updated.active == false
    end

    test "prevents name change", %{permission: permission} do
      assert {:error, error} =
               Policy.update_permission(permission, %{
                 name: "new.name"
               })

      assert Exception.message(error) =~ "cannot change permission name"
    end

    test "validates risk level changes", %{permission: permission} do
      # Can increase risk level
      assert {:ok, updated} =
               Policy.update_permission(permission, %{
                 risk_level: "high"
               })

      assert updated.risk_level == "high"

      # Decreasing risk level __requires audit
      assert {:ok, updated2} =
               Policy.update_permission(updated, %{
                 risk_level: "low",
                 audit_reason: "Risk reassessed after security review"
               })

      assert updated2.risk_level == "low"
    end
  end

  describe "permission queries" do
    setup do
      tenant = insert(:tenant)
      permissions = bulk_create_permissions(tenant, 100)
      {:ok, tenant: tenant, permissions: permissions}
    end

    test "lists all permissions for tenant",
         %{tenant: tenant, permissions: permissions} do
      result = Policy.list_permissions!(tenant_id: tenant.id)
      assert length(result) >= length(permissions)
      assert Enum.all?(result, &(&1.tenant_id == tenant.id))
    end

    test "filters by category", %{tenant: tenant} do
      __user_perms =
        Policy.list_permissions!(
          tenant_id: tenant.id,
          filter: [category: "__users"]
        )

      assert Enum.all?(__user_perms, &(&1.category == "__users"))
      assert length(__user_perms) > 0
    end

    test "filters by risk level", %{tenant: tenant} do
      critical_perms =
        Policy.list_permissions!(
          tenant_id: tenant.id,
          filter: [risk_level: "critical"]
        )

      assert Enum.all?(critical_perms, &(&1.risk_level == "critical"))

      # Get high and critical
      high_risk_perms =
        Policy.list_permissions!(
          tenant_id: tenant.id,
          filter: [risk_level: {:in, ["high", "critical"]}]
        )

      assert Enum.all?(high_risk_perms, &(&1.risk_level in ["high", "critical"]))
    end

    test "filters active permissions", %{tenant: tenant} do
      # Create inactive permission
      insert(:permission, tenant_id: tenant.id, active: false)

      active_perms =
        Policy.list_permissions!(
          tenant_id: tenant.id,
          filter: [active: true]
        )

      assert Enum.all?(active_perms, &(&1.active == true))
    end

    test "filters permissions __requiring MFA", %{tenant: tenant} do
      mfa_perms =
        Policy.list_permissions!(
          tenant_id: tenant.id,
          filter: [__requires_mfa: true]
        )

      assert Enum.all?(mfa_perms, &(&1.__requires_mfa == true))
    end

    test "filters permissions __requiring approval", %{tenant: tenant} do
      approval_perms =
        Policy.list_permissions!(
          tenant_id: tenant.id,
          filter: [__requires_approval: true]
        )

      assert Enum.all?(approval_perms, &(&1.__requires_approval == true))
    end

    test "searches by name pattern", %{tenant: tenant} do
      # Search for view permissions
      view_perms =
        Policy.list_permissions!(
          tenant_id: tenant.id,
          filter: [name: {:ilike, "%.view%"}]
        )

      assert Enum.all?(view_perms, &String.contains?(&1.name, "view"))

      # Search for device permissions
      device_perms =
        Policy.list_permissions!(
          tenant_id: tenant.id,
          filter: [name: {:ilike, "devices.%"}]
        )

      assert Enum.all?(device_perms, &String.starts_with?(&1.name, "devices."))
    end

    test "sorts by category and name", %{tenant: tenant} do
      perms =
        Policy.list_permissions!(
          tenant_id: tenant.id,
          sort: [category: :asc, name: :asc]
        )

      # Verify sorting
      grouped = Enum.group_by(perms, & &1.category)

      for {_category, group} <- grouped do
        names = Enum.map(group, & &1.name)
        assert names == Enum.sort(names)
      end
    end

    test "paginates results", %{tenant: tenant} do
      page1 =
        Policy.list_permissions!(
          tenant_id: tenant.id,
          page: [limit: 30, offset: 0]
        )

      page2 =
        Policy.list_permissions!(
          tenant_id: tenant.id,
          page: [limit: 30, offset: 30]
        )

      assert length(page1) == 30
      assert length(page2) == 30

      # No overlap
      page1_ids = MapSet.new(page1, & &1.id)
      page2_ids = MapSet.new(page2, & &1.id)
      assert MapSet.disjoint?(page1_ids, page2_ids)
    end
  end

  describe "permission relationships" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "finds conflicting permissions", %{tenant: tenant} do
      # Create permissions with conflicts
      {:ok, delete_perm} =
        Policy.create_permission(%{
          name: "data.delete",
          category: "__data",
          tenant_id: tenant.id
        })

      {:ok, protect_perm} =
        Policy.create_permission(%{
          name: "data.protect",
          category: "__data",
          conflicts_with: ["data.delete", "data.purge"],
          tenant_id: tenant.id
        })

      {:ok, archive_perm} =
        Policy.create_permission(%{
          name: "data.archive",
          category: "__data",
          conflicts_with: ["data.delete"],
          tenant_id: tenant.id
        })

      # Check conflicts
      conflicts = Policy.find_permission_conflicts([delete_perm.id, protect_perm.id])
      assert length(conflicts) > 0

      # Archive doesn't conflict with protect
      no_conflicts = Policy.find_permission_conflicts([archive_perm.id, protect_perm.id])
      assert Enum.empty?(no_conflicts)
    end

    test "finds dependent permissions", %{tenant: tenant} do
      # Create permission hierarchy
      {:ok, view_perm} =
        Policy.create_permission(%{
          name: "reports.view",
          category: "reports",
          tenant_id: tenant.id
        })

      {:ok, export_perm} =
        Policy.create_permission(%{
          name: "reports.export",
          category: "reports",
          depends_on: ["reports.view"],
          tenant_id: tenant.id
        })

      {:ok, share_perm} =
        Policy.create_permission(%{
          name: "reports.share",
          category: "reports",
          depends_on: ["reports.view", "reports.export"],
          tenant_id: tenant.id
        })

      # Get dependencies
      deps = Policy.get_permission_dependencies(share_perm.id)
      assert length(deps) == 2
      assert Enum.any?(deps, &(&1.name == "reports.view"))
      assert Enum.any?(deps, &(&1.name == "reports.export"))
    end

    test "validates permission compatibility", %{tenant: tenant} do
      # Create incompatible permissions
      {:ok, read_only} =
        Policy.create_permission(%{
          name: "system.read_only",
          category: "system",
          metadata: %{"mode" => "read_only"},
          tenant_id: tenant.id
        })

      {:ok, write} =
        Policy.create_permission(%{
          name: "system.write",
          category: "system",
          metadata: %{"mode" => "write"},
          incompatible_with: ["system.read_only"],
          tenant_id: tenant.id
        })

      # Check compatibility
      assert Policy.permissions_compatible?([read_only.id]) == true
      assert Policy.permissions_compatible?([write.id]) == true
      assert Policy.permissions_compatible?([read_only.id, write.id]) == false
    end
  end

  describe "permission categories" do
    setup do
      tenant = insert(:tenant)
      permissions = bulk_create_permissions(tenant, 100)
      {:ok, tenant: tenant, permissions: permissions}
    end

    test "gets all categories", %{tenant: tenant} do
      categories = Policy.get_permission_categories(tenant_id: tenant.id)

      expected = [
        "system",
        "__users",
        "devices",
        "alarms",
        "video",
        "access_control",
        "reports",
        "sites"
      ]

      for cat <- expected do
        assert cat in categories
      end
    end

    test "counts permissions by category", %{tenant: tenant} do
      counts = Policy.count_permissions_by_category(tenant_id: tenant.id)

      assert counts["__users"] > 0
      assert counts["devices"] > 0
      assert counts["alarms"] > 0

      total = Enum.sum(Map.values(counts))
      assert total >= 100
    end

    test "gets category risk profile", %{tenant: tenant} do
      risk_profile =
        Policy.get_category_risk_profile(
          tenant_id: tenant.id,
          category: "system"
        )

      assert Map.has_key?(risk_profile, "critical")
      assert Map.has_key?(risk_profile, "high")
      assert Map.has_key?(risk_profile, "medium")
      assert Map.has_key?(risk_profile, "low")

      # System category should have critical permissions
      assert risk_profile["critical"] > 0
    end
  end

  describe "permission usage tracking" do
    setup do
      tenant = insert(:tenant)
      permission = insert(:permission, tenant_id: tenant.id)
      {:ok, tenant: tenant, permission: permission}
    end

    test "tracks permission usage", %{permission: permission} do
      user = insert(:user, tenant_id: permission.tenant_id)

      # Log permission usage
      assert {:ok, log} =
               Policy.log_permission_usage(%{
                 permission_id: permission.id,
                 user_id: user.id,
                 action: "granted",
                 ip_address: "192.168.1.100",
                 __context: %{"resource_id" => Ecto.UUID.generate()}
               })

      assert log.permission_id == permission.id
      assert log.__user_id == user.id
      assert log.action == "granted"
    end

    test "gets permission usage statistics", %{permission: permission} do
      # Create usage logs
      __users =
        Indrajaal.Factory.insert_list(
          3,
          :user,
          tenant_id: permission.tenant_id
        )

      for user <- __users do
        for _ <- 1..5 do
          Policy.log_permission_usage(%{
            permission_id: permission.id,
            user_id: user.id,
            action: Enum.random(["granted", "denied"]),
            ip_address: Faker.Internet.ip_v4_address()
          })
        end
      end

      stats =
        Policy.get_permission_usage_stats(
          permission_id: permission.id,
          period: :day
        )

      assert stats.total_uses >= 15
      assert stats.unique_users == 3
      assert Map.has_key?(stats, :granted_count)
      assert Map.has_key?(stats, :denied_count)
    end

    test "identifies frequently used permissions", %{tenant: tenant} do
      permissions = Indrajaal.Factory.insert_list(5, :permission, tenant_id: tenant.id)
      user = insert(:user, tenant_id: tenant.id)

      # Create varied usage
      for {perm, usage_count} <- Enum.zip(permissions, [50, 30, 20, 10, 5]) do
        for _ <- 1..usage_count do
          Policy.log_permission_usage(%{
            permission_id: perm.id,
            user_id: user.id,
            action: "granted"
          })
        end
      end

      top_perms =
        Policy.get_most_used_permissions(
          tenant_id: tenant.id,
          limit: 3
        )

      assert length(top_perms) == 3
      # First should be most used
      assert List.first(top_perms).usage_count >= 50
    end
  end

  describe "bulk operations" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "bulk creates permissions", %{tenant: tenant} do
      permissions = bulk_create_permissions(tenant, 100)

      assert length(permissions) >= 100
      assert Enum.all?(permissions, &(&1.tenant_id == tenant.id))

      # Verify category distribution
      by_category = Enum.group_by(permissions, & &1.category)
      assert map_size(by_category) >= 7

      # Verify risk distribution
      by_risk = Enum.group_by(permissions, & &1.risk_level)
      assert Map.has_key?(by_risk, "critical")
      assert Map.has_key?(by_risk, "high")
      assert Map.has_key?(by_risk, "medium")
    end

    test "bulk updates permissions", %{tenant: tenant} do
      permissions = bulk_create_permissions(tenant, 20)
      perm_ids = Enum.map(permissions, & &1.id)

      assert {:ok, count} =
               Policy.bulk_update_permissions(
                 filter: [id: {:in, perm_ids}],
                 attributes: %{
                   metadata: %{"bulk_review" => true, "reviewed_at" => Date.utc_today()}
                 }
               )

      assert count == 20

      # Verify update
      updated = Policy.list_permissions!(filter: [id: {:in, perm_ids}])
      assert Enum.all?(updated, &(&1.metadata["bulk_review"] == true))
    end

    test "bulk deactivates permissions", %{tenant: tenant} do
      # Create permissions to deactivate
      category = "deprecated"

      perms =
        for i <- 1..5 do
          {:ok, perm} =
            Policy.create_permission(%{
              name: "#{category}.action_#{i}",
              category: category,
              tenant_id: tenant.id
            })

          perm
        end

      assert {:ok, count} =
               Policy.bulk_update_permissions(
                 filter: [category: category],
                 attributes: %{active: false}
               )

      assert count == 5

      # Verify all inactive
      inactive =
        Policy.list_permissions!(
          tenant_id: tenant.id,
          filter: [category: category]
        )

      assert Enum.all?(inactive, &(&1.active == false))
    end
  end

  describe "permission validation" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "validates permission constraints", %{tenant: tenant} do
      # Can't have both __requires_approval and low risk
      assert {:error, error} =
               Policy.create_permission(%{
                 name: "test.invalid",
                 category: "test",
                 risk_level: "low",
                 __requires_approval: true,
                 tenant_id: tenant.id
               })

      assert Exception.message(error) =~ "low risk permissions cannot __require
        approval"
    end

    test "validates condition format", %{tenant: tenant} do
      # Valid conditions
      valid_conditions = %{
        "time_ranges" => ["09:00 - 17:00", "18:00 - 22:00"],
        "ip_whitelist" => ["192.168.1.0 / 24", "10.0.0.0 / 8"],
        "max_uses" => 100
      }

      assert {:ok, _} =
               Policy.create_permission(%{
                 name: "test.valid_conditions",
                 category: "test",
                 conditions: valid_conditions,
                 tenant_id: tenant.id
               })

      # Invalid time range
      invalid_conditions = %{
        # Invalid hours
        "time_ranges" => ["25:00 - 26:00"]
      }

      assert {:error, _} =
               Policy.create_permission(%{
                 name: "test.invalid_time",
                 category: "test",
                 conditions: invalid_conditions,
                 tenant_id: tenant.id
               })
    end

    test "validates dependency chains", %{tenant: tenant} do
      # Create base permission
      {:ok, base} =
        Policy.create_permission(%{
          name: "base.permission",
          category: "base",
          tenant_id: tenant.id
        })

      # Create dependent
      {:ok, dep1} =
        Policy.create_permission(%{
          name: "dep.level1",
          category: "dep",
          depends_on: ["base.permission"],
          tenant_id: tenant.id
        })

      # Can't create circular dependency
      assert {:error, error} =
               Policy.update_permission(base, %{
                 depends_on: ["dep.level1"]
               })

      assert Exception.message(error) =~ "circular dependency"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
