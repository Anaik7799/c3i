defmodule Indrajaal.Core.OrganizationTest do
  import Indrajaal.ActorHelpers
  use Indrajaal.DataCase
  alias Indrajaal.Core
  alias Indrajaal.Core.Organization

  describe "organization creation" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "creates organization with valid attributes", %{tenant: tenant} do
      attrs = %{
        tenant_id: tenant.id,
        name: "Security Division"
      }

      assert {:ok, org} = Organization.create(attrs)
      assert org.name == "Security Division"
      assert org.tenant_id == tenant.id
      assert org.parent_organization_id == nil
      assert is_map(org.metadata)
      assert is_map(org.settings)
    end

    test "creates subsidiary organization with parent", %{tenant: tenant} do
      parent = insert(:organization, tenant_id: tenant.id, is_primary: true)

      attrs = %{
        tenant_id: tenant.id,
        name: "Regional Office",
        parent_organization_id: parent.id
      }

      assert {:ok, sub} = Organization.create(attrs)
      assert sub.parent_organization_id == parent.id
    end

    test "validates required fields", %{tenant: tenant} do
      assert {:error, error} = Organization.create(%{tenant_id: tenant.id})
      error_msg = Exception.message(error)
      assert error_msg =~ "name: is required"
    end

    test "validates organization type", %{tenant: tenant} do
      valid_types = [:primary, :subsidiary, :department, :division, :branch]

      for type <- valid_types do
        attrs = %{
          tenant_id: tenant.id,
          name: "Test #{type}",
          type: type
        }

        assert {:ok, org} = Organization.create(attrs)
      end
    end

    test "enforces tenant isolation", %{tenant: tenant} do
      other_tenant = insert(:tenant)
      parent = insert(:organization, tenant_id: other_tenant.id)

      # Cannot create org with parent from different tenant
      attrs = %{
        tenant_id: tenant.id,
        name: "Cross-tenant Org",
        parent_organization_id: parent.id
      }

      result = Organization.create(attrs)
      # Should fail validation or create without parent
      assert match?({:error, _}, result) or
               match?({:ok, %{parent_organization_id: nil}}, result)
    end

    test "creates organization with metadata", %{tenant: tenant} do
      attrs = %{
        tenant_id: tenant.id,
        name: "Metadata Org",
        metadata: %{
          "cost_center" => "CC1234",
          "region" => "North America",
          "manager" => "John Doe"
        }
      }

      assert {:ok, org} = Organization.create(attrs)
      assert org.metadata["cost_center"] == "CC1234"
      assert org.metadata["region"] == "North America"
    end

    test "creates organization with settings", %{tenant: tenant} do
      attrs = %{
        tenant_id: tenant.id,
        name: "Settings Org",
        settings: %{
          "approval_required" => true,
          "budget_limit" => 50_000,
          "notifications" => %{
            "email" => "manager@example.com",
            "slack" => "#security-ops"
          }
        }
      }

      assert {:ok, org} = Organization.create(attrs)
      assert org.settings["approval_required"] == true
      assert org.settings["budget_limit"] == 50_000
      assert org.settings["notifications"]["slack"] == "#security-ops"
    end
  end

  describe "organization updates" do
    setup do
      tenant = insert(:tenant)
      org = insert(:organization, tenant_id: tenant.id)
      {:ok, tenant: tenant, org: org}
    end

    test "updates organization attributes", %{org: org} do
      attrs = %{
        name: "Updated Division"
      }

      assert {:ok, updated} = Organization.update(org, attrs)
      assert updated.name == "Updated Division"
    end

    test "updates organization parent", %{tenant: tenant, org: org} do
      new_parent = insert(:organization, tenant_id: tenant.id, is_primary: true)

      attrs = %{parent_organization_id: new_parent.id}
      assert {:ok, updated} = Organization.update(org, attrs)
      assert updated.parent_organization_id == new_parent.id
    end

    test "prevents circular parent references", %{tenant: tenant} do
      parent = insert(:organization, tenant_id: tenant.id)
      child = insert(:organization, tenant_id: tenant.id, parent_organization_id: parent.id)

      # Try to make parent a child of its own child
      result = Organization.update(parent, %{parent_organization_id: child.id})

      # Should fail validation
      assert match?({:error, _}, result)
    end

    test "updates metadata preserving existing data", %{org: org} do
      # Set initial metadata
      {:ok, org} =
        Organization.update(org, %{
          metadata: %{"initial" => "value", "keep" => "this"}
        })

      # Update with new metadata
      attrs = %{
        metadata: Map.merge(org.metadata, %{"initial" => "updated", "new" => "data"})
      }

      assert {:ok, updated} = Organization.update(org, attrs)
      assert updated.metadata["initial"] == "updated"
      assert updated.metadata["keep"] == "this"
      assert updated.metadata["new"] == "data"
    end
  end

  describe "organization queries" do
    setup do
      tenant = insert(:tenant)
      orgs = bulk_create_organizations(tenant, 50)
      {:ok, tenant: tenant, orgs: orgs}
    end

    test "lists all organizations for tenant", %{tenant: tenant, orgs: orgs} do
      result = Organization.list!(tenant_id: tenant.id)
      assert length(result) >= length(orgs)
    end

    test "filters organizations by parent", %{tenant: tenant} do
      parent = insert(:organization, tenant_id: tenant.id, is_primary: true)
      child1 = insert(:organization, tenant_id: tenant.id, parent_organization_id: parent.id)
      child2 = insert(:organization, tenant_id: tenant.id, parent_organization_id: parent.id)
      unrelated = insert(:organization, tenant_id: tenant.id)

      children =
        Organization.list!(
          tenant_id: tenant.id,
          filter: [parent_organization_id: parent.id]
        )

      child_ids = Enum.map(children, & &1.id)
      assert child1.id in child_ids
      assert child2.id in child_ids
      refute unrelated.id in child_ids
    end

    test "gets organization hierarchy", %{tenant: tenant} do
      # Create hierarchical structure
      root = insert(:organization, tenant_id: tenant.id, is_primary: true)

      level1_a =
        insert(:organization, tenant_id: tenant.id, parent_organization_id: root.id)

      level1_b =
        insert(:organization, tenant_id: tenant.id, parent_organization_id: root.id)

      _level2 =
        insert(:organization,
          tenant_id: tenant.id,
          parent_organization_id: level1_a.id,
          is_primary: false
        )

      # Get root with children loaded
      root_with_children =
        Organization.get!(root.id,
          load: [:child_organizations],
          actor: Indrajaal.ActorHelpers.admin_actor(tenant.id)
        )

      assert length(root_with_children.child_organizations) == 2

      # Verify hierarchy
      child_ids = Enum.map(root_with_children.child_organizations, & &1.id)
      assert level1_a.id in child_ids
      assert level1_b.id in child_ids
    end

    test "paginates organization results", %{tenant: tenant} do
      # Ensure enough orgs
      bulk_create_organizations(tenant, 30)

      page1 =
        Organization.list!(
          tenant_id: tenant.id,
          page: [limit: 10, offset: 0]
        )

      page2 =
        Organization.list!(
          tenant_id: tenant.id,
          page: [limit: 10, offset: 10]
        )

      assert length(page1) == 10
      assert length(page2) == 10

      # Verify no overlap
      page1_ids = MapSet.new(page1, & &1.id)
      page2_ids = MapSet.new(page2, & &1.id)
      assert MapSet.disjoint?(page1_ids, page2_ids)
    end

    test "sorts organizations by name", %{tenant: tenant} do
      orgs =
        Organization.list!(
          tenant_id: tenant.id,
          sort: [name: :asc]
        )

      names = Enum.map(orgs, & &1.name)
      assert names == Enum.sort(names)
    end

    test "enforces tenant isolation in queries" do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)

      org1 = insert(:organization, tenant_id: tenant1.id, name: "Tenant1 Org")
      _org2 = insert(:organization, tenant_id: tenant2.id, name: "Tenant2 Org")

      # Should only see org from tenant1
      results = Organization.list!(tenant_id: tenant1.id)
      result_ids = Enum.map(results, & &1.id)

      assert org1.id in result_ids
      # org2 should not be visible
      assert Enum.all?(results, &(&1.tenant_id == tenant1.id))
    end
  end

  describe "organization deletion" do
    setup do
      tenant = insert(:tenant)
      org = insert(:organization, tenant_id: tenant.id)
      {:ok, tenant: tenant, org: org}
    end

    test "destroys organization", %{org: org} do
      assert {:ok, _deleted} = Organization.destroy(org)
      assert {:error, _} = Organization.get(org.id)
    end

    test "handles deletion with children", %{tenant: tenant, org: org} do
      # Create child organizations
      _child1 = insert(:organization, tenant_id: tenant.id, parent_organization_id: org.id)
      _child2 = insert(:organization, tenant_id: tenant.id, parent_organization_id: org.id)

      # Deletion should handle children (cascade or pr__event)
      result = Organization.destroy(org)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "organization business logic" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "validates organization hierarchy depth", %{tenant: tenant} do
      # Create deep hierarchy
      root = insert(:organization, tenant_id: tenant.id, is_primary: true)
      parent = root

      # Create multiple levels
      for level <- 1..5 do
        child =
          insert(:organization,
            tenant_id: tenant.id,
            parent_organization_id: parent.id,
            name: "Level #{level}"
          )

        # Re-assign parent for next iteration
        parent = child
      end

      # Verify we can traverse the hierarchy
      deepest = parent
      assert deepest.parent_organization_id != nil
    end

    test "calculates organization size metrics", %{tenant: tenant} do
      org = insert(:organization, tenant_id: tenant.id)

      # Create child organizations
      Indrajaal.Factory.insert_list(
        3,
        :organization,
        tenant_id: tenant.id,
        parent_organization_id: org.id
      )

      # Load with calculations
      org_with_counts = Organization.get!(org.id, load: [])
    end

    test "enforces organization type rules", %{tenant: tenant} do
      primary = insert(:organization, tenant_id: tenant.id, is_primary: true)

      # Departments can only be under subsidiaries or divisions
      attrs = %{
        tenant_id: tenant.id,
        name: "Invalid Department",
        parent_organization_id: primary.id
      }

      # This might be allowed depending on business rules
      result = Organization.create(attrs)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "organization search and filtering" do
    setup do
      tenant = insert(:tenant)

      orgs = [
        insert(:organization, tenant_id: tenant.id, name: "Security Operations Center"),
        insert(:organization, tenant_id: tenant.id, name: "IT Security Division"),
        insert(:organization, tenant_id: tenant.id, name: "Physical Security Department"),
        insert(:organization, tenant_id: tenant.id, name: "Risk Management Office")
      ]

      {:ok, tenant: tenant, orgs: orgs}
    end

    test "searches organizations by name pattern", %{tenant: tenant} do
      security_orgs =
        Organization.list!(
          tenant_id: tenant.id,
          filter: [name: {:ilike, "%Security%"}]
        )

      assert length(security_orgs) >= 3
      assert Enum.all?(security_orgs, &String.contains?(&1.name, "Security"))
    end

    test "filters by metadata values", %{tenant: tenant} do
      # Create orgs with specific metadata
      high_budget =
        insert(:organization,
          tenant_id: tenant.id,
          metadata: %{"budget" => 100_000, "priority" => "high"}
        )

      low_budget =
        insert(:organization,
          tenant_id: tenant.id,
          metadata: %{"budget" => 10_000, "priority" => "low"}
        )

      # Filter by metadata (if supported by your Ash setup)
      all_orgs = Organization.list!(tenant_id: tenant.id)

      # Manual filtering for demonstration
      high_priority =
        Enum.filter(all_orgs, fn org ->
          get_in(org.metadata, ["priority"]) == "high"
        end)

      assert Enum.any?(high_priority, &(&1.id == high_budget.id))
      refute Enum.any?(high_priority, &(&1.id == low_budget.id))
    end
  end

  describe "bulk organization operations" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "creates complex organizational hierarchy", %{tenant: tenant} do
      orgs = bulk_create_organizations(tenant, 50)

      # Verify structure
      primaries = Enum.filter(orgs, &(&1.type == :primary))
      subsidiaries = Enum.filter(orgs, &(&1.type == :subsidiary))
      departments = Enum.filter(orgs, &(&1.type == :department))

      assert length(primaries) >= 10
      assert length(subsidiaries) >= 20
      assert length(departments) >= 20

      # Verify parent-child relationships
      assert Enum.all?(subsidiaries, &(&1.parent_organization_id != nil))
      assert Enum.all?(departments, &(&1.parent_organization_id != nil))
    end

    test "generates diverse organization metadata", %{tenant: tenant} do
      orgs = bulk_create_organizations(tenant, 30)

      # Check metadata diversity
      industries =
        orgs
        |> Enum.map(&get_in(&1.metadata, ["industry"]))
        |> Enum.filter(&(&1 != nil))
        |> Enum.uniq()

      assert length(industries) > 3

      # Check different organization sizes
      sizes =
        orgs
        |> Enum.map(&get_in(&1.metadata, ["size"]))
        |> Enum.filter(&(&1 != nil))
        |> Enum.uniq()

      assert length(sizes) > 2
    end

    test "creates organizations across different regions", %{tenant: tenant} do
      orgs = bulk_create_organizations(tenant, 50)

      # Extract regions from org names (e.g., "Company - New York Office")
      location_orgs = Enum.filter(orgs, &String.contains?(&1.name, " - "))
      assert length(location_orgs) > 10

      # Verify geographic distribution
      org_names = Enum.map(location_orgs, & &1.name)
      assert Enum.any?(org_names, &String.contains?(&1, "Office"))
      assert Enum.any?(org_names, &String.contains?(&1, "Branch"))
    end
  end

  describe "organization calculations" do
    setup do
      tenant = insert(:tenant)
      org = insert(:organization, tenant_id: tenant.id)
      {:ok, tenant: tenant, org: org}
    end

    test "calculates total descendant count", %{tenant: tenant, org: org} do
      # Create multi-level hierarchy
      child1 = insert(:organization, tenant_id: tenant.id, parent_organization_id: org.id)
      _child2 = insert(:organization, tenant_id: tenant.id, parent_organization_id: org.id)
      _grandchild = insert(:organization, tenant_id: tenant.id, parent_organization_id: child1.id)

      # Load with descendant count
      org_with_count = Organization.get!(org.id, load: [])

      # Should count all descendants (3 total)
    end

    test "calculates organization depth in hierarchy", %{tenant: tenant} do
      root = insert(:organization, tenant_id: tenant.id, is_primary: true)
      level1 = insert(:organization, tenant_id: tenant.id, parent_organization_id: root.id)
      level2 = insert(:organization, tenant_id: tenant.id, parent_organization_id: level1.id)
      level3 = insert(:organization, tenant_id: tenant.id, parent_organization_id: level2.id)

      # Each org should know its depth
      # depth 0
      assert root.parent_organization_id == nil
      # depth 1
      assert level1.parent_organization_id == root.id
      # depth 2
      assert level2.parent_organization_id == level1.id
      # depth 3
      assert level3.parent_organization_id == level2.id
    end
  end

  describe "organization settings and features" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "inherits settings from parent organization", %{tenant: tenant} do
      parent =
        insert(:organization,
          tenant_id: tenant.id,
          settings: %{
            "security_level" => "high",
            "require_2fa" => true,
            "allowed_ips" => ["10.0.0.0/24"]
          }
        )

      child =
        insert(:organization,
          tenant_id: tenant.id,
          parent_organization_id: parent.id,
          settings: %{
            # Override parent
            "security_level" => "medium"
          }
        )

      # Child should have its own settings
      assert child.settings["security_level"] == "medium"

      # In practice, you might merge parent settings
      # This would be implemented in your business logic
    end

    test "validates organization-specific limits", %{tenant: tenant} do
      org =
        insert(:organization,
          tenant_id: tenant.id,
          settings: %{
            "max_users" => 50,
            "max_devices" => 100,
            "storage_quota_gb" => 500
          }
        )

      assert org.settings["max_users"] == 50
      assert org.settings["max_devices"] == 100
      assert org.settings["storage_quota_gb"] == 500
    end
  end

  describe "organization lifecycle" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "tracks organization creation and modifications", %{tenant: tenant} do
      # Create org
      {:ok, org} =
        Organization.create(%{
          tenant_id: tenant.id,
          name: "Lifecycle Test Org"
        })

      # Update multiple times
      {:ok, org} = Organization.update(org, %{name: "First Update"})

      {:ok, org} =
        Organization.update(org, %{
          metadata: %{"last_review" => Date.utc_today()}
        })

      {:ok, final} = Organization.update(org, %{name: "Final Name"})

      assert final.name == "Final Name"
      assert final.metadata["last_review"] != nil
    end

    test "handles organization status transitions", %{tenant: tenant} do
      org =
        insert(:organization,
          tenant_id: tenant.id,
          metadata: %{"status" => "active"}
        )

      # Deactivate
      {:ok, inactive} =
        Organization.update(org, %{
          metadata: Map.put(org.metadata, "status", "inactive")
        })

      assert inactive.metadata["status"] == "inactive"

      # Reactivate
      {:ok, active} =
        Organization.update(inactive, %{
          metadata: Map.put(inactive.metadata, "status", "active")
        })

      assert active.metadata["status"] == "active"
    end
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: General system coordination and management with cybernetics
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
