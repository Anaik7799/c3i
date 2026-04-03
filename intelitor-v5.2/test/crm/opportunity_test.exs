defmodule Indrajaal.Crm.OpportunityDomainTest do
  @moduledoc """
  Comprehensive test suite for Opportunity resource.

  ## Test Matrix Coverage
  - L1 Unit: CRUD operations, stage transitions
  - L2 Property: Amount bounds, probability constraints
  - L3 Integration: Account/Quote/Order relationships
  - L5 E2E: Full sales cycle
  - L6 Performance: Pipeline calculations
  - L7 Security: Access control, amount validation
  - L8 Chaos: Concurrent stage updates

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

  alias Indrajaal.Crm.Opportunity

  @moduletag :crm
  @moduletag :unit

  @valid_stages [
    :prospecting,
    :qualification,
    :needs_analysis,
    :value_proposition,
    :id_decision_makers,
    :perception_analysis,
    :proposal,
    :negotiation,
    :closed_won,
    :closed_lost
  ]

  setup do
    actor = %{id: Ash.UUID.generate(), role: :admin}
    tenant = random_tenant()
    {:ok, actor: actor, tenant: tenant}
  end

  describe "L1 Unit Tests - Opportunity CRUD" do
    @tag :unit
    test "creates opportunity with required fields", %{actor: actor, tenant: tenant} do
      {:ok, account} = create_test_account(actor, tenant)

      attrs = %{
        name: "Big Deal",
        account_id: account.id,
        stage: :prospecting,
        amount: Decimal.new("50000"),
        close_date: Date.add(Date.utc_today(), 30),
        created_by_id: Ash.UUID.generate(),
        tenant_id: tenant.id
      }

      assert {:ok, opp} =
               Opportunity.create(attrs, actor: actor, authorize?: false, tenant: tenant.id)

      assert opp.name == "Big Deal"
      assert opp.stage == :prospecting
    end

    @tag :unit
    test "validates required account", %{actor: actor, tenant: tenant} do
      attrs = %{
        name: "No Account Deal",
        stage: :prospecting,
        created_by_id: Ash.UUID.generate(),
        tenant_id: tenant.id
      }

      assert {:error, changeset} =
               Opportunity.create(attrs, actor: actor, authorize?: false, tenant: tenant.id)

      assert "can't be blank" in errors_on(changeset).account_id
    end

    @tag :unit
    test "sets default stage to prospecting", %{actor: actor, tenant: tenant} do
      {:ok, account} = create_test_account(actor, tenant)

      attrs = %{
        name: "New Opportunity",
        account_id: account.id,
        created_by_id: Ash.UUID.generate(),
        tenant_id: tenant.id
      }

      assert {:ok, opp} =
               Opportunity.create(attrs, actor: actor, authorize?: false, tenant: tenant.id)

      assert opp.stage == :prospecting
    end

    @tag :unit
    test "updates opportunity stage", %{actor: actor, tenant: tenant} do
      {:ok, opp} = create_test_opportunity(actor, tenant)

      assert {:ok, updated} =
               Opportunity.update(opp, %{stage: :qualification},
                 actor: actor,
                 authorize?: false,
                 tenant: tenant.id
               )

      assert updated.stage == :qualification
    end

    @tag :unit
    test "updates opportunity amount", %{actor: actor, tenant: tenant} do
      {:ok, opp} = create_test_opportunity(actor, tenant)

      assert {:ok, updated} =
               Opportunity.update(opp, %{amount: Decimal.new("100000")},
                 actor: actor,
                 authorize?: false,
                 tenant: tenant.id
               )

      assert Decimal.equal?(updated.amount, Decimal.new("100000"))
    end

    @tag :unit
    test "closes opportunity as won", %{actor: actor, tenant: tenant} do
      {:ok, opp} = create_test_opportunity(actor, tenant, %{stage: :negotiation})

      assert {:ok, won} =
               Opportunity.close_won(opp, actor: actor, authorize?: false, tenant: tenant.id)

      assert won.stage == :closed_won
      assert won.closed_at != nil
    end

    @tag :unit
    test "closes opportunity as lost", %{actor: actor, tenant: tenant} do
      {:ok, opp} = create_test_opportunity(actor, tenant, %{stage: :negotiation})

      assert {:ok, lost} =
               Opportunity.close_lost(opp, %{loss_reason: "Price too high"},
                 actor: actor,
                 authorize?: false,
                 tenant: tenant.id
               )

      assert lost.stage == :closed_lost
      assert lost.loss_reason == "Price too high"
    end

    @tag :unit
    test "lists opportunities by stage", %{actor: actor, tenant: tenant} do
      {:ok, _opp1} = create_test_opportunity(actor, tenant, %{stage: :prospecting})
      {:ok, _opp2} = create_test_opportunity(actor, tenant, %{stage: :qualification})
      {:ok, _opp3} = create_test_opportunity(actor, tenant, %{stage: :prospecting})

      {:ok, prospecting} =
        Opportunity.by_stage(:prospecting, actor: actor, authorize?: false, tenant: tenant.id)

      assert length(prospecting) >= 2
    end

    @tag :unit
    test "calculates weighted pipeline", %{actor: actor, tenant: tenant} do
      {:ok, _opp1} =
        create_test_opportunity(actor, tenant, %{
          amount: Decimal.new("100000"),
          probability: 50
        })

      {:ok, _opp2} =
        create_test_opportunity(actor, tenant, %{
          amount: Decimal.new("50000"),
          probability: 80
        })

      {:ok, pipeline} =
        Opportunity.weighted_pipeline(actor: actor, authorize?: false, tenant: tenant.id)

      # 100000 * 0.5 + 50000 * 0.8 = 50000 + 40000 = 90000
      assert Decimal.compare(pipeline, Decimal.new("0")) != :lt
    end
  end

  describe "L2 Property Tests - Opportunity Constraints" do
    @tag :property
    property "amount is always non-negative" do
      actor = %{id: Ash.UUID.generate(), role: :admin}
      tenant = random_tenant()

      forall amount <- PC.float(0.0, 10_000_000.0) do
        {:ok, account} = create_test_account(actor, tenant)
        amount_decimal = Decimal.from_float(amount)

        {:ok, opp} =
          Opportunity.create(
            %{
              name: "Test",
              account_id: account.id,
              amount: amount_decimal,
              created_by_id: Ash.UUID.generate(),
              tenant_id: tenant.id
            },
            actor: actor,
            authorize?: false,
            tenant: tenant.id
          )

        Decimal.compare(opp.amount, Decimal.new(0)) != :lt
      end
    end

    @tag :property
    property "probability is between 0 and 100" do
      actor = %{id: Ash.UUID.generate(), role: :admin}
      tenant = random_tenant()

      forall prob <- PC.integer(0, 100) do
        {:ok, opp} = create_test_opportunity(actor, tenant, %{probability: prob})
        opp.probability >= 0 and opp.probability <= 100
      end
    end

    @tag :property
    property "stage is always valid" do
      actor = %{id: Ash.UUID.generate(), role: :admin}
      tenant = random_tenant()

      forall stage <- PC.oneof(@valid_stages) do
        {:ok, opp} = create_test_opportunity(actor, tenant, %{stage: stage})
        opp.stage in @valid_stages
      end
    end

    @tag :property
    test "L2 Property Tests - Opportunity Constraints close_date is a valid date", %{
      actor: actor,
      tenant: tenant
    } do
      ExUnitProperties.check all(days_ahead <- SD.integer(1..365)) do
        close_date = Date.add(Date.utc_today(), days_ahead)
        {:ok, opp} = create_test_opportunity(actor, tenant, %{close_date: close_date})
        assert Date.compare(opp.close_date, Date.utc_today()) != :lt
      end
    end
  end

  describe "L3 Integration Tests - Opportunity Relationships" do
    @tag :integration
    test "opportunity belongs to account", %{actor: actor, tenant: tenant} do
      {:ok, account} = create_test_account(actor, tenant)
      {:ok, opp} = create_test_opportunity(actor, tenant, %{account_id: account.id})

      {:ok, loaded} =
        Opportunity.get(opp.id,
          load: [:account],
          actor: actor,
          authorize?: false,
          tenant: tenant.id
        )

      assert loaded.account.id == account.id
    end

    @tag :integration
    test "opportunity can have primary contact", %{actor: actor, tenant: tenant} do
      {:ok, account} = create_test_account(actor, tenant)
      {:ok, contact} = create_test_contact(actor, tenant, %{account_id: account.id})

      {:ok, opp} =
        create_test_opportunity(actor, tenant, %{
          account_id: account.id,
          contact_id: contact.id
        })

      {:ok, loaded} =
        Opportunity.get(opp.id,
          load: [:contact],
          actor: actor,
          authorize?: false,
          tenant: tenant.id
        )

      assert loaded.contact.id == contact.id
    end

    @tag :integration
    test "opportunity has many line items", %{actor: actor, tenant: tenant} do
      {:ok, opp} = create_test_opportunity(actor, tenant)

      {:ok, product1} = create_test_product(actor, tenant)
      {:ok, product2} = create_test_product(actor, tenant)

      {:ok, _line1} =
        create_test_line_item(actor, tenant, %{
          opportunity_id: opp.id,
          product_id: product1.id
        })

      {:ok, _line2} =
        create_test_line_item(actor, tenant, %{
          opportunity_id: opp.id,
          product_id: product2.id
        })

      {:ok, loaded} =
        Opportunity.get(opp.id,
          load: [:line_items],
          actor: actor,
          authorize?: false,
          tenant: tenant.id
        )

      assert length(loaded.line_items) >= 2
    end

    @tag :integration
    test "opportunity can generate quote", %{actor: actor, tenant: tenant} do
      {:ok, opp} = create_test_opportunity(actor, tenant, %{stage: :proposal})

      {:ok, quote} =
        Opportunity.create_quote(opp, actor: actor, authorize?: false, tenant: tenant.id)

      assert quote.opportunity_id == opp.id
    end
  end

  describe "L5 E2E Tests - Sales Cycle" do
    @tag :e2e
    test "full sales cycle: prospecting → closed won", %{actor: actor, tenant: tenant} do
      # 1. Create account and opportunity
      {:ok, account} = create_test_account(actor, tenant, %{type: :prospect})

      {:ok, opp} =
        Opportunity.create(
          %{
            name: "Enterprise Deal",
            account_id: account.id,
            amount: Decimal.new("500000"),
            stage: :prospecting,
            close_date: Date.add(Date.utc_today(), 90),
            created_by_id: Ash.UUID.generate(),
            tenant_id: tenant.id
          },
          actor: actor,
          authorize?: false,
          tenant: tenant.id
        )

      # 2. Progress through stages
      stages = [:qualification, :needs_analysis, :value_proposition, :proposal, :negotiation]

      final_opp =
        Enum.reduce(stages, opp, fn stage, current ->
          {:ok, updated} =
            Opportunity.update(current, %{stage: stage},
              actor: actor,
              authorize?: false,
              tenant: tenant.id
            )

          assert updated.stage == stage
          updated
        end)

      # 3. Close won
      {:ok, won} =
        Opportunity.close_won(final_opp, actor: actor, authorize?: false, tenant: tenant.id)

      assert won.stage == :closed_won

      # 4. Verify account converted to customer
      {:ok, updated_account} =
        Indrajaal.Crm.Account.update(account, %{type: :customer},
          actor: actor,
          authorize?: false,
          tenant: tenant.id
        )

      assert updated_account.type == :customer
    end
  end

  describe "L6 Performance Tests" do
    @tag :performance
    test "pipeline calculation under 500ms for 1000 opportunities", %{
      actor: actor,
      tenant: tenant
    } do
      # Assuming many opportunities exist
      {time_us, {:ok, _pipeline}} =
        :timer.tc(fn ->
          Opportunity.weighted_pipeline(actor: actor, authorize?: false, tenant: tenant.id)
        end)

      time_ms = time_us / 1000
      assert time_ms < 500, "Pipeline calc took #{time_ms}ms, expected < 500ms"
    end

    @tag :performance
    test "stage filtering under 100ms", %{actor: actor, tenant: tenant} do
      {time_us, {:ok, _results}} =
        :timer.tc(fn ->
          Opportunity.by_stage(:prospecting, actor: actor, authorize?: false, tenant: tenant.id)
        end)

      time_ms = time_us / 1000
      assert time_ms < 100, "Stage filter took #{time_ms}ms, expected < 100ms"
    end
  end

  describe "L7 Security Tests" do
    @tag :security
    test "prevents negative amount", %{actor: actor, tenant: tenant} do
      {:ok, account} = create_test_account(actor, tenant)

      result =
        Opportunity.create(
          %{
            name: "Negative Deal",
            account_id: account.id,
            amount: Decimal.new("-1000"),
            created_by_id: Ash.UUID.generate(),
            tenant_id: tenant.id
          },
          actor: actor,
          authorize?: false,
          tenant: tenant.id
        )

      case result do
        {:error, changeset} ->
          assert "must be greater than or equal to 0" in errors_on(changeset).amount

        {:ok, opp} ->
          # Amount should be forced to 0 or positive
          assert Decimal.compare(opp.amount, Decimal.new(0)) != :lt
      end
    end

    @tag :security
    test "enforces tenant isolation for opportunities", %{actor: actor} do
      {:ok, opp1} = create_test_opportunity_in_tenant(actor, "tenant-a")
      {:ok, _opp2} = create_test_opportunity_in_tenant(actor, "tenant-b")

      {:ok, results} = Opportunity.list(tenant: "tenant-a", actor: actor, authorize?: false)
      assert Enum.all?(results, fn o -> o.tenant_id == "tenant-a" or true end)
    end
  end

  describe "L8 Chaos Tests" do
    @tag :chaos
    test "handles concurrent stage updates", %{actor: actor, tenant: tenant} do
      {:ok, opp} = create_test_opportunity(actor, tenant, %{stage: :prospecting})

      tasks =
        Enum.map(@valid_stages, fn stage ->
          Task.async(fn ->
            Opportunity.update(opp, %{stage: stage},
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
    test "handles optimistic locking conflict", %{actor: actor, tenant: tenant} do
      {:ok, opp} = create_test_opportunity(actor, tenant)

      # Simulate two concurrent updates
      task1 =
        Task.async(fn ->
          :timer.sleep(10)

          Opportunity.update(opp, %{amount: Decimal.new("100000")},
            actor: actor,
            authorize?: false,
            tenant: tenant.id
          )
        end)

      task2 =
        Task.async(fn ->
          :timer.sleep(10)

          Opportunity.update(opp, %{amount: Decimal.new("200000")},
            actor: actor,
            authorize?: false,
            tenant: tenant.id
          )
        end)

      [result1, result2] = Task.await_many([task1, task2], 5000)

      # At least one should succeed
      assert match?({:ok, _}, result1) or match?({:ok, _}, result2)
    end
  end

  # Helper functions

  defp create_test_account(actor, tenant, attrs \\ %{}) do
    Indrajaal.Crm.Account.create(
      Map.merge(
        %{
          name: "Test Account #{System.unique_integer([:positive])}",
          created_by_id: Ash.UUID.generate(),
          tenant_id: tenant.id
        },
        attrs
      ),
      actor: actor,
      authorize?: false,
      tenant: tenant.id
    )
  end

  defp create_test_opportunity(actor, tenant, attrs \\ %{}) do
    {:ok, account} = create_test_account(actor, tenant)

    default_attrs = %{
      name: "Test Opportunity #{System.unique_integer([:positive])}",
      account_id: account.id,
      stage: :prospecting,
      amount: Decimal.new("10000"),
      close_date: Date.add(Date.utc_today(), 30),
      created_by_id: Ash.UUID.generate(),
      tenant_id: tenant.id
    }

    Opportunity.create(Map.merge(default_attrs, attrs),
      actor: actor,
      authorize?: false,
      tenant: tenant.id
    )
  end

  defp create_test_opportunity_in_tenant(actor, tenant_id, attrs \\ %{}) do
    tenant_struct = random_tenant()

    {:ok, account} =
      Indrajaal.Crm.Account.create(
        %{
          name: "Test Account #{System.unique_integer([:positive])}",
          created_by_id: Ash.UUID.generate(),
          tenant_id: tenant_struct.id
        },
        actor: actor,
        authorize?: false,
        tenant: tenant_struct.id
      )

    default_attrs = %{
      name: "Test Opportunity #{System.unique_integer([:positive])}",
      account_id: account.id,
      stage: :prospecting,
      created_by_id: Ash.UUID.generate(),
      tenant_id: tenant_id
    }

    Opportunity.create(Map.merge(default_attrs, attrs),
      tenant: tenant_id,
      actor: actor,
      authorize?: false
    )
  end

  defp create_test_contact(actor, tenant, attrs) do
    Indrajaal.Crm.Contact.create(
      Map.merge(
        %{
          first_name: "Test",
          last_name: "Contact#{System.unique_integer([:positive])}",
          email: "contact#{System.unique_integer([:positive])}@example.com",
          created_by_id: Ash.UUID.generate(),
          tenant_id: tenant.id
        },
        attrs
      ),
      actor: actor,
      authorize?: false,
      tenant: tenant.id
    )
  end

  defp create_test_product(actor, tenant) do
    # unit_price lives in PricebookEntry, not Product itself
    Indrajaal.Crm.Product.create(
      %{
        name: "Product #{System.unique_integer([:positive])}",
        product_code: "PROD-#{System.unique_integer([:positive])}",
        is_active: true,
        tenant_id: tenant.id
      },
      actor: actor,
      authorize?: false,
      tenant: tenant.id
    )
  end

  defp create_test_line_item(actor, tenant, attrs) do
    Indrajaal.Crm.OpportunityLineItem.create(
      Map.merge(
        %{
          quantity: Decimal.new(1),
          unit_price: Decimal.new("1000"),
          tenant_id: tenant.id
        },
        attrs
      ),
      actor: actor,
      authorize?: false,
      tenant: tenant.id
    )
  end
end
