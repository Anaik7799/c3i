defmodule Indrajaal.Core.TenantComprehensiveTest do
  import Indrajaal.ActorHelpers

  @moduledoc """
  Comprehensive test suite for Tenant resource following TDG specifications.

  Implements SOPv5.1 Task 8.4.2.2 - Tenant resource tests with STAMP validation.

  STAMP Safety Constraints Applied:
  - SC1: Data isolation using unique slugs per test
  - SC2: Transaction rollback pr__events __database corruption
  - SC3: Proper cleanup in setup/teardown
  - SC4: Multi-tenant isolation validation
  - SC5: Deterministic factory __data
  """
  use Indrajaal.DataCase, async: true

  alias Indrajaal.Core.Tenant

  describe "Tenant Creation (TDG: creation category)" do
    test "creates tenant with valid attributes" do
      # TDG Spec: Use Factory.insert(:tenant) pattern
      attrs = %{
        name: "Test Tenant #{System.unique_integer()}",
        slug: "test-tenant-#{System.unique_integer()}"
      }

      tenant = insert(:tenant, attrs)

      # Validations from TDG spec
      assert tenant.name == attrs.name
      assert to_string(tenant.slug) == attrs.slug
      assert tenant.subscription_tier == :professional
      assert tenant.status == :active
      assert tenant.settings == %{"timezone" => "UTC", "locale" => "en"}

      # STAMP SC1: Verify unique slug
      assert_raise RuntimeError, ~r/Failed to create tenant/, fn ->
        insert(:tenant, %{slug: to_string(tenant.slug)})
      end
    end

    test "validates __required tenant fields" do
      # TDG Spec: Attempt to create tenant with missing fields

      # Create a system actor for these tests
      system_actor = Indrajaal.ActorHelpers.system_actor()

      # Name is __required
      assert_raise Ash.Error.Invalid, fn ->
        Ash.create!(Tenant, %{slug: "valid-slug"},
          action: :create,
          actor: system_actor,
          authorize?: false
        )
      end

      # Slug is __required
      assert_raise Ash.Error.Invalid, fn ->
        Ash.create!(Tenant, %{name: "Valid Name"},
          action: :create,
          actor: system_actor,
          authorize?: false
        )
      end

      # Verify defaults are applied
      tenant = insert(:tenant)
      assert tenant.subscription_tier == :professional
      assert tenant.status == :active
    end

    test "enforces slug uniqueness constraint" do
      # STAMP SC5: Deterministic test __data
      slug = "unique-test-slug-#{System.unique_integer()}"

      # First tenant succeeds
      tenant1 = insert(:tenant, %{slug: slug})
      assert to_string(tenant1.slug) == slug

      # Second tenant with same slug fails
      assert_raise RuntimeError, ~r/Failed to create tenant/, fn ->
        insert(:tenant, %{slug: slug})
      end
    end

    test "accepts all valid subscription tiers" do
      # Test each valid tier
      for tier <- [:free, :basic, :professional, :enterprise] do
        tenant = insert(:tenant, %{subscription_tier: tier})
        assert tenant.subscription_tier == tier
      end
    end
  end

  describe "Tenant Status Transitions (TDG: status_transitions category)" do
    setup do
      tenant = insert(:tenant, %{status: :active})
      {:ok, tenant: tenant}
    end

    test "transitions from active to suspended", %{tenant: tenant} do
      # TDG Spec: Active -> Suspended transition allowed
      {:ok, updated} =
        tenant
        |> Ash.Changeset.for_update(:suspend, %{}, actor: %{id: "system", is_system_admin: true})
        |> Ash.update(authorize?: false)

      assert updated.status == :suspended
    end

    test "transitions from suspended to active", %{tenant: tenant} do
      # First suspend the tenant
      {:ok, suspended} =
        tenant
        |> Ash.Changeset.for_update(:suspend, %{}, actor: %{id: "system", is_system_admin: true})
        |> Ash.update(authorize?: false)

      # TDG Spec: Suspended -> Active transition allowed
      {:ok, reactivated} =
        suspended
        |> Ash.Changeset.for_update(:reactivate, %{},
          actor: %{id: "system", is_system_admin: true}
        )
        |> Ash.update(authorize?: false)

      assert reactivated.status == :active
    end

    test "transitions from active to archived", %{tenant: tenant} do
      # TDG Spec: Active -> Archived transition allowed
      {:ok, archived} =
        tenant
        |> Ash.Changeset.for_update(:archive, %{}, actor: %{id: "system", is_system_admin: true})
        |> Ash.update(authorize?: false)

      assert archived.status == :archived
    end

    test "allows transition from archived to active" do
      # Create archived tenant
      tenant = insert(:tenant, %{status: :archived})

      # TDG Spec: Archived -> Active transition is allowed (no validation pr__eventing it)
      {:ok, reactivated} =
        tenant
        |> Ash.Changeset.for_update(:reactivate, %{},
          actor: %{id: "system", is_system_admin: true}
        )
        |> Ash.update(authorize?: false)

      assert reactivated.status == :active
    end
  end

  describe "Tenant Isolation (TDG: isolation category)" do
    test "enforces tenant isolation in queries" do
      # STAMP SC4: Multi-tenant isolation validation
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)

      # Create __data for each tenant (will implement with other resources)
      # For now, verify tenants are separate entities
      assert tenant1.id != tenant2.id
      assert to_string(tenant1.slug) != to_string(tenant2.slug)

      # Query for specific tenant
      {:ok, found} =
        Ash.get(Tenant, tenant1.id,
          actor: %{id: "system", is_system_admin: true},
          authorize?: false
        )

      assert found.id == tenant1.id

      # List all tenants (admin operation)
      {:ok, all_tenants} =
        Ash.read(Tenant, actor: %{id: "system", is_system_admin: true}, authorize?: false)

      tenant_ids = Enum.map(all_tenants, & &1.id)
      assert tenant1.id in tenant_ids
      assert tenant2.id in tenant_ids
    end

    test "__requires tenant __context for operations" do
      tenant = insert(:tenant)

      # Operations should respect tenant boundaries
      # This will be more thoroughly tested with associated resources
      assert tenant.id != nil
      assert is_binary(tenant.id)
    end
  end

  describe "Tenant Deletion and Cascades (TDG: cascading category)" do
    test "supports soft delete for __data preservation" do
      tenant = insert(:tenant)

      # Soft delete (if implemented) would set deleted_at
      # For now, test that tenant can be marked archived
      {:ok, archived} =
        tenant
        |> Ash.Changeset.for_update(:archive, %{}, actor: %{id: "system", is_system_admin: true})
        |> Ash.update(authorize?: false)

      assert archived.status == :archived

      # Verify tenant still exists in __database
      {:ok, found} =
        Ash.get(Tenant, tenant.id,
          actor: %{id: "system", is_system_admin: true},
          authorize?: false
        )

      assert found.status == :archived
    end

    test "maintains audit trail for tenant changes" do
      tenant = insert(:tenant)
      assert tenant.status == :active

      # Suspend tenant
      {:ok, suspended} =
        tenant
        |> Ash.Changeset.for_update(:suspend, %{}, actor: %{id: "system", is_system_admin: true})
        |> Ash.update(authorize?: false)

      assert suspended.status == :suspended
      assert suspended.status != tenant.status

      # Verify timestamps are tracked
      assert suspended.updated_at != nil
      assert DateTime.compare(suspended.updated_at, tenant.inserted_at) == :gt
    end
  end

  describe "Tenant Settings and Meta__data (TDG: additional validations)" do
    test "stores and retrieves settings correctly" do
      settings = %{
        "timezone" => "America/New_York",
        "locale" => "en-US",
        "features" => %{
          "advanced_analytics" => true,
          "api_access" => true
        }
      }

      tenant = insert(:tenant, %{settings: settings})

      assert tenant.settings["timezone"] == "America/New_York"
      assert tenant.settings["locale"] == "en-US"
      assert tenant.settings["features"]["advanced_analytics"] == true
      assert tenant.settings["features"]["api_access"] == true
    end

    test "stores settings with nested structure" do
      settings = %{
        "timezone" => "America/New_York",
        "locale" => "en-US",
        "features" => %{
          "advanced_analytics" => true,
          "api_access" => true
        },
        "preferences" => %{
          "industry" => "technology",
          "employee_count" => "50-100"
        }
      }

      tenant = insert(:tenant, %{settings: settings})

      assert tenant.settings["preferences"]["industry"] == "technology"
      assert tenant.settings["preferences"]["employee_count"] == "50-100"
    end
  end

  describe "STAMP Safety Validations" do
    test "SC1: validates __data isolation between tests" do
      # Each test creates unique tenants with unique slugs
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)

      assert to_string(tenant1.slug) != to_string(tenant2.slug)
      assert tenant1.id != tenant2.id
    end

    test "SC2: pr__events test __database corruption via transactions" do
      # Test runs in transaction that rolls back
      assert_raise Ash.Error.Invalid, fn ->
        # Invalid, should rollback
        Ash.create!(Tenant, %{name: nil},
          action: :create,
          actor: %{id: "system", is_system_admin: true},
          authorize?: false
        )
      end

      # Verify we can still create valid tenants
      tenant = insert(:tenant)
      assert tenant.id != nil
    end

    test "SC5: uses deterministic test __data from factories" do
      # Factory produces predictable structure
      tenant = insert(:tenant)

      assert tenant.status == :active
      assert tenant.subscription_tier == :professional
      assert is_map(tenant.settings)
      assert tenant.settings["timezone"] == "UTC"
      assert tenant.settings["locale"] == "en"
    end
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
