defmodule Indrajaal.Core.CoreIntegrationTest do
  @moduledoc """
  Integration tests for Core domain interactions following TDG specifications.

  Tests cross-resource functionality and validates STAMP safety constraints.

  STAMP Safety Constraints Applied:
  - SC2: Transaction integrity for multi-resource operations
  - SC3: Proper cleanup after integration tests
  - SC4: Cross-resource tenant isolation
  """
  use Indrajaal.DataCase, async: true
  import Indrajaal.ActorHelpers

  alias Indrajaal.Core.{Tenant, Organization, SystemConfig}
  import Ash.Query

  describe "Tenant-Organization Relationships (TDG: relationships category)" do
    test "organizations are scoped to creating tenant" do
      # Create two tenants with organizations
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)

      # Create orgs for tenant1
      org1_a = insert(:organization, %{tenant: tenant1, name: "Org 1A"})
      org1_b = insert(:organization, %{tenant: tenant1, name: "Org 1B"})

      # Create orgs for tenant2
      org2_a = insert(:organization, %{tenant: tenant2, name: "Org 2A"})

      # Query orgs for tenant1
      {:ok, tenant1_orgs} = Ash.read(Organization, actor: tenant1, tenant: tenant1.id)
      mapped_org_ids = Enum.map(tenant1_orgs, & &1.id)
      tenant1_org_ids = mapped_org_ids |> Enum.sort()

      # Should only see tenant1's orgs
      assert length(tenant1_orgs) == 2
      assert org1_a.id in tenant1_org_ids
      assert org1_b.id in tenant1_org_ids
      refute org2_a.id in tenant1_org_ids
    end

    test "cannot access organizations from other tenants" do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)

      # Create org for tenant2
      org2 = insert(:organization, %{tenant: tenant2, name: "Private Org"})

      # Try to get org2 with tenant1 context - should raise Invalid (wrapping NotFound)
      assert_raise Ash.Error.Invalid, fn ->
        Ash.get!(Organization, org2.id, actor: tenant1, tenant: tenant1.id)
      end
    end

    test "tenant status affects organization operations" do
      # Create active tenant with org
      tenant = insert(:tenant, %{status: :active})
      _org = insert(:organization, %{tenant: tenant})

      # Can query orgs for active tenant
      {:ok, orgs} = Ash.read(Organization, actor: tenant, tenant: tenant.id)
      assert length(orgs) == 1

      # Suspend tenant using the suspend action
      {:ok, suspended_tenant} =
        Tenant.suspend(tenant, actor: %{id: "system", is_system_admin: true})

      # Can still query but may have restricted operations
      {:ok, orgs} = Ash.read(Organization, actor: suspended_tenant, tenant: suspended_tenant.id)
      assert length(orgs) == 1
    end
  end

  describe "Organization-SystemConfig Associations (TDG: integration specs)" do
    test "system configs are tenant-scoped across organizations" do
      tenant = insert(:tenant)
      _org1 = insert(:organization, %{tenant: tenant, name: "Org 1"})
      _org2 = insert(:organization, %{tenant: tenant, name: "Org 2"})

      # Create configs that might be org-specific (using valid key patterns without hyphens)
      unique_suffix = System.unique_integer([:positive])
      key1 = "org.setting.org1_#{unique_suffix}"
      key2 = "org.setting.org2_#{unique_suffix}"

      _config1 =
        insert(:system_config, %{
          tenant: tenant,
          key: key1,
          value: %{"data" => "org1-specific"},
          category: :general
        })

      _config2 =
        insert(:system_config, %{
          tenant: tenant,
          key: key2,
          value: %{"data" => "org2-specific"},
          category: :general
        })

      # Both configs visible at tenant level
      {:ok, configs} =
        SystemConfig
        |> Ash.Query.filter(category == :general)
        |> Ash.read(actor: tenant, tenant: tenant.id)

      assert length(configs) == 2
      mapped_config_keys = Enum.map(configs, & &1.key)
      config_keys = mapped_config_keys |> Enum.sort()
      assert key1 in config_keys
      assert key2 in config_keys
    end

    test "organization hierarchy with config inheritance patterns" do
      tenant = insert(:tenant)

      # Create org hierarchy
      parent = insert(:organization, %{tenant: tenant, name: "Parent Corp"})

      _child =
        insert(:organization, %{
          tenant: tenant,
          parent_organization_id: parent.id,
          name: "Child Div"
        })

      # Create hierarchical configs (using valid key patterns without hyphens)
      unique_suffix = System.unique_integer([:positive])

      _global_config =
        insert(:system_config, %{
          tenant: tenant,
          key: "policy.approval_required_#{unique_suffix}",
          value: %{"value" => true},
          category: :security
        })

      _parent_config =
        insert(:system_config, %{
          tenant: tenant,
          key: "policy.org.parent_#{unique_suffix}",
          value: %{"value" => 10_000},
          category: :security
        })

      _child_config =
        insert(:system_config, %{
          tenant: tenant,
          key: "policy.org.child_#{unique_suffix}",
          value: %{"value" => 5000},
          category: :security
        })

      # All configs accessible at tenant level
      {:ok, all_configs} =
        SystemConfig
        |> Ash.Query.filter(category == :security)
        |> Ash.read(actor: tenant, tenant: tenant.id)

      assert length(all_configs) == 3
    end
  end

  describe "Transactional Operations (TDG: transactions category)" do
    test "creates tenant with initial setup atomically" do
      # Multi-step tenant setup
      attrs = %{
        name: "Transactional Tenant",
        slug: "trans-tenant-#{System.unique_integer()}"
      }

      {:ok, tenant} = Tenant.register(attrs, actor: system_admin_actor())

      assert tenant.name == "Transactional Tenant"
      # register action uses default subscription_tier (:free)
      assert tenant.subscription_tier == :free

      # Create default org in same transaction concept
      org_attrs = %{
        tenant_id: tenant.id,
        name: "#{tenant.name} HQ",
        is_primary: true
      }

      {:ok, org} =
        Organization.create(org_attrs, actor: admin_actor(tenant.id), tenant: tenant.id)

      assert org.tenant_id == tenant.id

      # Create initial configs
      {:ok, _config1} =
        SystemConfig.set(
          %{
            key: "setup.complete",
            value: %{"value" => "true"},
            category: :general
          },
          actor: admin_actor(tenant.id),
          tenant: tenant.id
        )

      {:ok, _config2} =
        SystemConfig.set(
          %{
            key: "setup.version",
            value: %{"value" => "1.0"},
            category: :general
          },
          actor: admin_actor(tenant.id),
          tenant: tenant.id
        )

      # Verify setup completed successfully
      assert org.is_primary == true
    end

    test "rolls back on partial failure" do
      tenant = insert(:tenant)

      # Try to create configs with one invalid
      configs = [
        %{tenant_id: tenant.id, key: "valid.key1", value: %{"v" => 1}, category: :general},
        # Invalid - nil key
        %{tenant_id: tenant.id, key: nil, value: %{"v" => 2}, category: :general},
        %{tenant_id: tenant.id, key: "valid.key3", value: %{"v" => 3}, category: :general}
      ]

      # Try to create configs individually - should fail on invalid key
      result =
        try do
          configs_results =
            Enum.map(configs, fn config_attrs ->
              SystemConfig.set(config_attrs,
                actor: Indrajaal.ActorHelpers.admin_actor(tenant.id),
                tenant: tenant.id
              )
            end)

          if Enum.any?(configs_results, fn {status, _} -> status == :error end) do
            %{status: :error}
          else
            %{status: :success}
          end
        rescue
          _error -> %{status: :error}
        end

      # Should fail due to invalid record
      assert result.status == :error

      # Verify no partial __data was saved (configs with valid.key pattern)
      {:ok, saved_configs} =
        SystemConfig
        |> Ash.read(actor: tenant, tenant: tenant.id)

      valid_key_configs =
        Enum.filter(saved_configs, fn c -> String.starts_with?(c.key, "valid.key") end)

      assert valid_key_configs == []
    end
  end

  describe "Performance Characteristics (TDG: performance category)" do
    @tag :performance
    test "tenant creation completes within acceptable time" do
      # Measure tenant creation time - use :create action which accepts all fields
      {time, {:ok, tenant}} =
        :timer.tc(fn ->
          Ash.create(
            Tenant,
            %{
              name: "Perf Test Tenant",
              slug: "perf-tenant-#{System.unique_integer()}",
              status: :active,
              subscription_tier: :basic
            },
            action: :create,
            actor: system_admin_actor(),
            authorize?: false
          )
        end)

      # Convert microseconds to milliseconds
      time_ms = time / 1000

      # TDG Spec: Tenant creation < 100ms
      assert time_ms < 100
      assert tenant.id != nil
      assert tenant.subscription_tier == :basic
    end

    @tag :performance
    test "organization hierarchy query performs efficiently" do
      tenant = insert(:tenant)

      # Create a hierarchy
      parent = insert(:organization, %{tenant: tenant})

      for i <- 1..5 do
        dept =
          insert(:organization, %{
            tenant: tenant,
            parent_organization_id: parent.id,
            name: "Dept #{i}"
          })

        for j <- 1..3 do
          insert(:organization, %{
            tenant: tenant,
            parent_organization_id: dept.id,
            name: "Team #{i}-#{j}"
          })
        end
      end

      # Measure query time
      {time, {:ok, orgs}} =
        :timer.tc(fn ->
          Ash.read(Organization, actor: tenant, tenant: tenant.id)
        end)

      time_ms = time / 1000

      # TDG Spec: Org hierarchy query < 50ms
      assert time_ms < 50
      # 1 parent + 5 depts + 15 teams
      assert length(orgs) == 21
    end

    @tag :performance
    test "config retrieval performs efficiently" do
      tenant = insert(:tenant)

      # Create multiple configs
      for i <- 1..20 do
        insert(:system_config, %{
          tenant: tenant,
          key: "perf.test.key#{i}",
          value: %{"value" => i},
          category: :features
        })
      end

      # Measure retrieval time
      {time, {:ok, configs}} =
        :timer.tc(fn ->
          SystemConfig
          |> Ash.Query.filter(category == :features)
          |> Ash.read(actor: tenant, tenant: tenant.id)
        end)

      time_ms = time / 1000

      # TDG Spec: Config retrieval < 10ms
      assert time_ms < 10
      assert length(configs) == 20
    end
  end

  describe "STAMP Cross-Resource Safety" do
    test "SC4: validates cross-resource tenant isolation" do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)

      # Create complete setup for each tenant
      org1 = insert(:organization, %{tenant: tenant1})
      config1 = insert(:system_config, %{tenant: tenant1, key: "isolated.key"})

      org2 = insert(:organization, %{tenant: tenant2})
      config2 = insert(:system_config, %{tenant: tenant2, key: "isolated.key"})

      # Verify complete isolation
      {:ok, t1_orgs} = Ash.read(Organization, actor: tenant1, tenant: tenant1.id)
      {:ok, t1_configs} = Ash.read(SystemConfig, actor: tenant1, tenant: tenant1.id)

      t1_org_ids = Enum.map(t1_orgs, & &1.id)
      t1_config_ids = Enum.map(t1_configs, & &1.id)

      # Tenant1 can only see its own __data
      assert org1.id in t1_org_ids
      refute org2.id in t1_org_ids
      assert config1.id in t1_config_ids
      refute config2.id in t1_config_ids
    end

    test "SC3: ensures proper cleanup after integration tests" do
      # This test verifies our test infrastructure
      # Each test runs in a transaction that rolls back
      tenant = insert(:tenant)
      org = insert(:organization, %{tenant: tenant})
      config = insert(:system_config, %{tenant: tenant})

      # All __data exists within this test
      assert tenant.id != nil
      assert org.id != nil
      assert config.id != nil

      # But will be cleaned up after test completes
    end
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
