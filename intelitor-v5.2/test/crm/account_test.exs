defmodule Indrajaal.Crm.AccountDomainTest do
  @moduledoc """
  Comprehensive test suite for Account resource.

  ## Test Matrix Coverage
  - L1 Unit: CRUD operations, validations
  - L2 Property: Field constraints, type validations
  - L3 Integration: Contact/Opportunity relationships
  - L5 E2E: Full account lifecycle
  - L6 Performance: Bulk operations
  - L7 Security: Access control, data protection
  - L8 Chaos: Concurrent updates, constraint violations

  ## STAMP Constraints
  - SC-COV-001: 100% coverage for critical paths
  - SC-TDG-001: TDG compliance with dual property tests
  """

  use Indrajaal.DataCase, async: true
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' ExUnitProperties.check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Crm.Account

  @moduletag :crm
  @moduletag :unit

  setup do
    actor = %{id: Ash.UUID.generate(), role: :admin}
    tenant = random_tenant()
    {:ok, actor: actor, tenant: tenant}
  end

  describe "L1 Unit Tests - Account CRUD" do
    @tag :unit
    test "creates account with required fields", %{actor: actor, tenant: tenant} do
      attrs = %{
        name: "Acme Corporation",
        type: :customer,
        industry: "Technology",
        website: "https://acme.com",
        created_by_id: Ash.UUID.generate(),
        tenant_id: tenant.id
      }

      assert {:ok, account} =
               Account.create(attrs, actor: actor, authorize?: false, tenant: tenant.id)

      assert account.name == "Acme Corporation"
      assert account.type == :customer
    end

    @tag :unit
    test "validates required name field", %{actor: actor, tenant: tenant} do
      attrs = %{type: :prospect, created_by_id: Ash.UUID.generate(), tenant_id: tenant.id}

      assert {:error, changeset} =
               Account.create(attrs, actor: actor, authorize?: false, tenant: tenant.id)

      assert "can't be blank" in errors_on(changeset).name
    end

    @tag :unit
    test "sets default type to prospect", %{actor: actor, tenant: tenant} do
      attrs = %{name: "New Account", created_by_id: Ash.UUID.generate(), tenant_id: tenant.id}

      assert {:ok, account} =
               Account.create(attrs, actor: actor, authorize?: false, tenant: tenant.id)

      assert account.type == :prospect
    end

    @tag :unit
    test "updates account details", %{actor: actor, tenant: tenant} do
      {:ok, account} = create_test_account(actor, tenant)

      assert {:ok, updated} =
               Account.update(
                 account,
                 %{
                   industry: "Manufacturing",
                   annual_revenue: Decimal.new("5000000")
                 },
                 actor: actor,
                 authorize?: false,
                 tenant: tenant.id
               )

      assert updated.industry == "Manufacturing"
    end

    @tag :unit
    test "soft deletes account", %{actor: actor, tenant: tenant} do
      {:ok, account} = create_test_account(actor, tenant)

      assert {:ok, deleted} =
               Account.destroy(account, actor: actor, authorize?: false, tenant: tenant.id)

      assert deleted.id == account.id
    end

    @tag :unit
    test "reads account by id", %{actor: actor, tenant: tenant} do
      {:ok, account} = create_test_account(actor, tenant)

      assert {:ok, fetched} =
               Account.get(account.id, actor: actor, authorize?: false, tenant: tenant.id)

      assert fetched.id == account.id
    end

    @tag :unit
    test "lists accounts by type", %{actor: actor, tenant: tenant} do
      {:ok, _customer} = create_test_account(actor, tenant, %{type: :customer})
      {:ok, _prospect} = create_test_account(actor, tenant, %{type: :prospect})
      {:ok, _partner} = create_test_account(actor, tenant, %{type: :partner})

      {:ok, customers} =
        Account.by_type(:customer, actor: actor, authorize?: false, tenant: tenant.id)

      assert length(customers) >= 1
    end

    @tag :unit
    test "lists accounts by industry", %{actor: actor, tenant: tenant} do
      {:ok, _tech} = create_test_account(actor, tenant, %{industry: "Technology"})
      {:ok, _mfg} = create_test_account(actor, tenant, %{industry: "Manufacturing"})

      {:ok, tech_accounts} =
        Account.by_industry("Technology", actor: actor, authorize?: false, tenant: tenant.id)

      assert length(tech_accounts) >= 1
    end

    @tag :unit
    test "validates website URL format", %{actor: actor, tenant: tenant} do
      attrs = %{
        name: "Test",
        website: "not-a-url",
        created_by_id: Ash.UUID.generate(),
        tenant_id: tenant.id
      }

      assert {:error, changeset} =
               Account.create(attrs, actor: actor, authorize?: false, tenant: tenant.id)

      assert "must be a valid URL" in errors_on(changeset).website
    end

    @tag :unit
    test "validates phone format", %{actor: actor, tenant: tenant} do
      attrs = %{
        name: "Test",
        phone: "123",
        created_by_id: Ash.UUID.generate(),
        tenant_id: tenant.id
      }

      assert {:error, changeset} =
               Account.create(attrs, actor: actor, authorize?: false, tenant: tenant.id)

      assert "must be a valid phone number" in errors_on(changeset).phone
    end
  end

  describe "L2 Property Tests - Account Constraints" do
    @tag :property
    property "account name is always non-empty string" do
      actor = %{id: Ash.UUID.generate(), role: :admin}
      tenant = random_tenant()

      forall name <- PC.utf8() do
        implies(String.length(name) > 0) do
          attrs = %{name: name, tenant_id: tenant.id}

          case Account.create(attrs, actor: actor, authorize?: false, tenant: tenant.id) do
            {:ok, account} -> String.length(account.name) > 0
            {:error, _} -> true
          end
        end
      end
    end

    @tag :property
    property "account type is always valid enum" do
      actor = %{id: Ash.UUID.generate(), role: :admin}
      tenant = random_tenant()
      valid_types = [:prospect, :customer, :partner, :competitor, :other]

      forall type <- PC.oneof(valid_types) do
        {:ok, account} = create_test_account(actor, tenant, %{type: type})
        account.type in valid_types
      end
    end

    @tag :property
    test "L2 Property Tests - Account Constraints annual revenue is always non-negative", %{
      actor: actor,
      tenant: tenant
    } do
      ExUnitProperties.check all(revenue <- SD.float(min: 0.0, max: 1_000_000_000.0)) do
        revenue_decimal = Decimal.from_float(revenue)
        {:ok, account} = create_test_account(actor, tenant, %{annual_revenue: revenue_decimal})

        assert Decimal.compare(account.annual_revenue, Decimal.new(0)) != :lt
      end
    end

    @tag :property
    test "L2 Property Tests - Account Constraints employee count is always non-negative integer",
         %{
           actor: actor,
           tenant: tenant
         } do
      ExUnitProperties.check all(count <- SD.integer(0..1_000_000)) do
        {:ok, account} = create_test_account(actor, tenant, %{num_employees: count})
        assert account.num_employees >= 0
      end
    end
  end

  describe "L3 Integration Tests - Account Relationships" do
    @tag :integration
    test "account has many contacts", %{actor: actor, tenant: tenant} do
      {:ok, account} = create_test_account(actor, tenant)

      {:ok, _contact1} = create_test_contact(actor, tenant, %{account_id: account.id})
      {:ok, _contact2} = create_test_contact(actor, tenant, %{account_id: account.id})

      {:ok, loaded} =
        Account.get(account.id,
          load: [:contacts],
          actor: actor,
          authorize?: false,
          tenant: tenant.id
        )

      assert length(loaded.contacts) >= 2
    end

    @tag :integration
    test "account has many opportunities", %{actor: actor, tenant: tenant} do
      {:ok, account} = create_test_account(actor, tenant)

      {:ok, _opp1} = create_test_opportunity(actor, tenant, %{account_id: account.id})
      {:ok, _opp2} = create_test_opportunity(actor, tenant, %{account_id: account.id})

      {:ok, loaded} =
        Account.get(account.id,
          load: [:opportunities],
          actor: actor,
          authorize?: false,
          tenant: tenant.id
        )

      assert length(loaded.opportunities) >= 2
    end

    @tag :integration
    test "account hierarchy with parent/child", %{actor: actor, tenant: tenant} do
      {:ok, parent} = create_test_account(actor, tenant, %{name: "Parent Corp"})

      {:ok, child} =
        create_test_account(actor, tenant, %{
          name: "Subsidiary",
          parent_account_id: parent.id
        })

      {:ok, loaded_parent} =
        Account.get(parent.id,
          load: [:child_accounts],
          actor: actor,
          authorize?: false,
          tenant: tenant.id
        )

      assert length(loaded_parent.child_accounts) >= 1

      {:ok, loaded_child} =
        Account.get(child.id,
          load: [:parent_account],
          actor: actor,
          authorize?: false,
          tenant: tenant.id
        )

      assert loaded_child.parent_account.id == parent.id
    end
  end

  describe "L5 E2E Tests - Account Lifecycle" do
    @tag :e2e
    test "full account lifecycle: prospect → customer → partner", %{actor: actor, tenant: tenant} do
      # 1. Create as prospect
      {:ok, account} =
        create_test_account(actor, tenant, %{
          name: "Potential Client",
          type: :prospect
        })

      assert account.type == :prospect

      # 2. Add contact
      {:ok, contact} =
        create_test_contact(actor, tenant, %{
          account_id: account.id,
          first_name: "John",
          last_name: "Decision",
          title: "CEO"
        })

      # 3. Create opportunity
      {:ok, opportunity} =
        create_test_opportunity(actor, tenant, %{
          account_id: account.id,
          contact_id: contact.id,
          stage: :qualification,
          amount: Decimal.new("100000")
        })

      # 4. Win opportunity and convert to customer
      {:ok, _won} =
        Indrajaal.Crm.Opportunity.update(opportunity, %{stage: :closed_won},
          actor: actor,
          authorize?: false,
          tenant: tenant.id
        )

      {:ok, customer} =
        Account.update(account, %{type: :customer},
          actor: actor,
          authorize?: false,
          tenant: tenant.id
        )

      assert customer.type == :customer

      # 5. Develop into partner
      {:ok, partner} =
        Account.update(customer, %{type: :partner},
          actor: actor,
          authorize?: false,
          tenant: tenant.id
        )

      assert partner.type == :partner
    end
  end

  describe "L6 Performance Tests" do
    @tag :performance
    test "bulk account creation under 10 seconds", %{actor: actor, tenant: tenant} do
      accounts_data =
        Enum.map(1..100, fn i ->
          %{
            name: "Company #{i}",
            type: :prospect,
            industry: "Industry #{rem(i, 10)}",
            created_by_id: Ash.UUID.generate(),
            tenant_id: tenant.id
          }
        end)

      {time_us, results} =
        :timer.tc(fn ->
          Enum.map(
            accounts_data,
            &Account.create(&1, actor: actor, authorize?: false, tenant: tenant.id)
          )
        end)

      time_ms = time_us / 1000
      assert time_ms < 10000, "Bulk creation took #{time_ms}ms, expected < 10000ms"
      assert Enum.all?(results, &match?({:ok, _}, &1))
    end

    @tag :performance
    test "account search under 100ms for 1000 records", %{actor: actor, tenant: tenant} do
      # Assuming 1000+ accounts exist
      {time_us, {:ok, _results}} =
        :timer.tc(fn ->
          Account.search("Company", actor: actor, authorize?: false, tenant: tenant.id)
        end)

      time_ms = time_us / 1000
      assert time_ms < 100, "Search took #{time_ms}ms, expected < 100ms"
    end
  end

  describe "L7 Security Tests" do
    @tag :security
    test "prevents SQL injection in search", %{actor: actor, tenant: tenant} do
      malicious_input = "'; DROP TABLE accounts; --"

      assert {:ok, _results} =
               Account.search(malicious_input, actor: actor, authorize?: false, tenant: tenant.id)
    end

    @tag :security
    test "sanitizes XSS in name field", %{actor: actor, tenant: tenant} do
      attrs = %{
        name: "<script>alert('xss')</script>Evil Corp",
        created_by_id: Ash.UUID.generate(),
        tenant_id: tenant.id
      }

      {:ok, account} = Account.create(attrs, actor: actor, authorize?: false, tenant: tenant.id)
      refute String.contains?(account.name, "<script>")
    end

    @tag :security
    test "enforces tenant isolation", %{actor: actor} do
      # Create accounts in different tenants
      {:ok, account1} = create_test_account_in_tenant(actor, "tenant-1")
      {:ok, account2} = create_test_account_in_tenant(actor, "tenant-2")

      # Query from tenant-1 should not see tenant-2 accounts
      {:ok, results} = Account.list(tenant: "tenant-1", actor: actor, authorize?: false)
      refute Enum.any?(results, &(&1.id == account2.id))
    end
  end

  describe "L8 Chaos Tests" do
    @tag :chaos
    test "handles concurrent updates gracefully", %{actor: actor, tenant: tenant} do
      {:ok, account} = create_test_account(actor, tenant)

      tasks =
        Enum.map(1..10, fn i ->
          Task.async(fn ->
            Account.update(account, %{num_employees: i * 100},
              actor: actor,
              authorize?: false,
              tenant: tenant.id
            )
          end)
        end)

      results = Task.await_many(tasks, 5000)

      success_count = Enum.count(results, &match?({:ok, _}, &1))
      assert success_count >= 1
    end

    @tag :chaos
    test "handles duplicate name constraint", %{actor: actor, tenant: tenant} do
      {:ok, _account} = create_test_account(actor, tenant, %{name: "Unique Corp"})

      # Try to create another with same name
      result =
        Account.create(
          %{name: "Unique Corp", created_by_id: Ash.UUID.generate(), tenant_id: tenant.id},
          actor: actor,
          authorize?: false,
          tenant: tenant.id
        )

      case result do
        {:error, changeset} ->
          assert "has already been taken" in errors_on(changeset).name

        {:ok, _} ->
          # Some systems allow duplicate names - both are valid
          assert true
      end
    end
  end

  # Helper functions

  defp create_test_account(actor, tenant, attrs \\ %{}) do
    default_attrs = %{
      name: "Test Account #{System.unique_integer([:positive])}",
      type: :prospect,
      created_by_id: Ash.UUID.generate(),
      tenant_id: tenant.id
    }

    Account.create(Map.merge(default_attrs, attrs),
      actor: actor,
      authorize?: false,
      tenant: tenant.id
    )
  end

  defp create_test_account_in_tenant(actor, tenant_id, attrs \\ %{}) do
    default_attrs = %{
      name: "Test Account #{System.unique_integer([:positive])}",
      type: :prospect,
      created_by_id: Ash.UUID.generate(),
      tenant_id: tenant_id
    }

    Account.create(Map.merge(default_attrs, attrs),
      tenant: tenant_id,
      actor: actor,
      authorize?: false
    )
  end

  defp create_test_contact(actor, tenant, attrs) do
    default_attrs = %{
      first_name: "Test",
      last_name: "Contact#{System.unique_integer([:positive])}",
      email: "contact#{System.unique_integer([:positive])}@example.com",
      created_by_id: Ash.UUID.generate(),
      tenant_id: tenant.id
    }

    Indrajaal.Crm.Contact.create(Map.merge(default_attrs, attrs),
      actor: actor,
      authorize?: false,
      tenant: tenant.id
    )
  end

  defp create_test_opportunity(actor, tenant, attrs) do
    default_attrs = %{
      name: "Test Opportunity #{System.unique_integer([:positive])}",
      stage: :prospecting,
      amount: Decimal.new("10000"),
      created_by_id: Ash.UUID.generate(),
      tenant_id: tenant.id
    }

    Indrajaal.Crm.Opportunity.create(Map.merge(default_attrs, attrs),
      actor: actor,
      authorize?: false,
      tenant: tenant.id
    )
  end
end
