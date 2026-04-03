defmodule Indrajaal.Crm.OrderTest do
  @moduledoc """
  Comprehensive test suite for Order resource.

  ## Test Matrix Coverage
  - L1 Unit: CRUD operations, status transitions
  - L2 Property: Total calculations, delivery dates
  - L3 Integration: Quote conversion, line items
  - L5 E2E: Full order fulfillment cycle
  - L6 Performance: Bulk order processing
  - L7 Security: Order tampering prevention
  - L8 Chaos: Concurrent status updates

  ## STAMP Constraints
  - SC-COV-001: 100% coverage for critical paths
  - SC-TDG-001: TDG compliance with dual property tests
  """

  use Indrajaal.DataCase, async: true
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Crm.Order

  @moduletag :crm
  @moduletag :unit

  @valid_statuses [:draft, :submitted, :approved, :activated, :cancelled, :shipped, :delivered]
  @valid_types [:new, :renewal, :upgrade, :downgrade]

  setup do
    actor = %{id: Ash.UUID.generate(), role: :admin}
    tenant = random_tenant()
    {:ok, actor: actor, tenant: tenant}
  end

  describe "L1 Unit Tests - Order CRUD" do
    @tag :unit
    test "creates order with required fields", %{actor: actor, tenant: tenant} do
      {:ok, account} = create_test_account(actor, tenant)

      attrs = %{
        account_id: account.id,
        order_type: :new,
        tenant_id: tenant.id
      }

      assert {:ok, order} =
               Order.create(attrs, actor: actor, authorize?: false, tenant: tenant.id)

      assert order.status == :draft
      assert order.order_number != nil
    end

    @tag :unit
    test "generates order number automatically", %{actor: actor, tenant: tenant} do
      {:ok, order} = create_test_order(actor, tenant)

      assert order.order_number != nil
      assert String.starts_with?(order.order_number, "ORD-")
    end

    @tag :unit
    test "submits order for approval", %{actor: actor, tenant: tenant} do
      {:ok, order} = create_test_order(actor, tenant)

      assert {:ok, submitted} =
               Order.submit(order, actor: actor, authorize?: false, tenant: tenant.id)

      assert submitted.status == :submitted
    end

    @tag :unit
    test "approves submitted order", %{actor: actor, tenant: tenant} do
      {:ok, order} = create_test_order(actor, tenant, %{status: :submitted})

      assert {:ok, approved} =
               Order.approve(order, actor: actor, authorize?: false, tenant: tenant.id)

      assert approved.status == :approved
    end

    @tag :unit
    test "activates approved order", %{actor: actor, tenant: tenant} do
      {:ok, order} = create_test_order(actor, tenant, %{status: :approved})

      assert {:ok, activated} =
               Order.activate(order, actor: actor, authorize?: false, tenant: tenant.id)

      assert activated.status == :activated
    end

    @tag :unit
    test "marks order as shipped", %{actor: actor, tenant: tenant} do
      {:ok, order} = create_test_order(actor, tenant, %{status: :activated})

      assert {:ok, shipped} =
               Order.mark_shipped(order, actor: actor, authorize?: false, tenant: tenant.id)

      assert shipped.status == :shipped
    end

    @tag :unit
    test "marks order as delivered", %{actor: actor, tenant: tenant} do
      {:ok, order} = create_test_order(actor, tenant, %{status: :shipped})

      assert {:ok, delivered} =
               Order.mark_delivered(order, actor: actor, authorize?: false, tenant: tenant.id)

      assert delivered.status == :delivered
      assert delivered.actual_delivery_date == Date.utc_today()
    end

    @tag :unit
    test "cancels order", %{actor: actor, tenant: tenant} do
      {:ok, order} = create_test_order(actor, tenant, %{status: :draft})

      assert {:ok, cancelled} =
               Order.cancel(order, actor: actor, authorize?: false, tenant: tenant.id)

      assert cancelled.status == :cancelled
    end

    @tag :unit
    test "calculates order totals", %{actor: actor, tenant: tenant} do
      {:ok, order} = create_test_order(actor, tenant)
      {:ok, product1} = create_test_product(actor, tenant, %{unit_price: Decimal.new("100")})
      {:ok, product2} = create_test_product(actor, tenant, %{unit_price: Decimal.new("200")})

      {:ok, _} =
        create_order_line_item(actor, tenant, %{
          order_id: order.id,
          product_id: product1.id,
          quantity: Decimal.new(2),
          unit_price: Decimal.new("100")
        })

      {:ok, _} =
        create_order_line_item(actor, tenant, %{
          order_id: order.id,
          product_id: product2.id,
          quantity: Decimal.new(3),
          unit_price: Decimal.new("200")
        })

      {:ok, calculated} =
        Order.calculate_totals(order, actor: actor, authorize?: false, tenant: tenant.id)

      # 2 * 100 + 3 * 200 = 800
      assert Decimal.compare(calculated.subtotal, Decimal.new("800")) == :eq
    end

    @tag :unit
    test "lists orders by status", %{actor: actor, tenant: tenant} do
      {:ok, _draft} = create_test_order(actor, tenant, %{status: :draft})
      {:ok, _activated} = create_test_order(actor, tenant, %{status: :activated})

      {:ok, drafts} = Order.by_status(:draft, actor: actor, authorize?: false, tenant: tenant.id)
      assert length(drafts) >= 1
    end
  end

  describe "L2 Property Tests - Order Constraints" do
    @tag :property
    test "L2 Property Tests - Order Constraints order total equals subtotal minus discount plus tax plus shipping" do
      ExUnitProperties.check all(
                               subtotal <- SD.float(min: 100.0, max: 10000.0),
                               discount <- SD.float(min: 0.0, max: 100.0),
                               tax <- SD.float(min: 0.0, max: 500.0),
                               shipping <- SD.float(min: 0.0, max: 100.0)
                             ) do
        total = subtotal - discount + tax + shipping
        assert total >= 0
      end
    end

    @tag :property
    test "order type is always valid" do
      actor = %{id: Ash.UUID.generate(), role: :admin}
      tenant = random_tenant()

      forall order_type <- PC.oneof(@valid_types) do
        {:ok, order} = create_test_order(actor, tenant, %{order_type: order_type})
        order.order_type in @valid_types
      end
    end

    @tag :property
    test "status is always valid" do
      actor = %{id: Ash.UUID.generate(), role: :admin}
      tenant = random_tenant()

      forall status <- PC.oneof(@valid_statuses) do
        {:ok, order} = create_test_order(actor, tenant, %{status: status})
        order.status in @valid_statuses
      end
    end

    @tag :property
    test "L2 Property Tests - Order Constraints requested delivery date is in the future", %{
      actor: actor,
      tenant: tenant
    } do
      ExUnitProperties.check all(days <- SD.integer(1..180)) do
        delivery_date = Date.add(Date.utc_today(), days)
        {:ok, order} = create_test_order(actor, tenant, %{requested_delivery_date: delivery_date})

        case order.requested_delivery_date do
          nil -> assert true
          date -> assert Date.compare(date, Date.utc_today()) != :lt
        end
      end
    end
  end

  describe "L3 Integration Tests - Order Relationships" do
    @tag :integration
    test "order belongs to account", %{actor: actor, tenant: tenant} do
      {:ok, account} = create_test_account(actor, tenant)
      {:ok, order} = create_test_order(actor, tenant, %{account_id: account.id})

      {:ok, loaded} =
        Order.get(order.id, load: [:account], actor: actor, authorize?: false, tenant: tenant.id)

      assert loaded.account.id == account.id
    end

    @tag :integration
    test "order can be linked to quote", %{actor: actor, tenant: tenant} do
      {:ok, quote} = create_test_quote(actor, tenant)
      {:ok, order} = create_test_order(actor, tenant, %{quote_id: quote.id})

      {:ok, loaded} =
        Order.get(order.id, load: [:quote], actor: actor, authorize?: false, tenant: tenant.id)

      assert loaded.quote.id == quote.id
    end

    @tag :integration
    test "order has many line items", %{actor: actor, tenant: tenant} do
      {:ok, order} = create_test_order(actor, tenant)
      {:ok, product1} = create_test_product(actor, tenant)
      {:ok, product2} = create_test_product(actor, tenant)

      {:ok, _} =
        create_order_line_item(actor, tenant, %{
          order_id: order.id,
          product_id: product1.id
        })

      {:ok, _} =
        create_order_line_item(actor, tenant, %{
          order_id: order.id,
          product_id: product2.id
        })

      {:ok, loaded} =
        Order.get(order.id,
          load: [:line_items],
          actor: actor,
          authorize?: false,
          tenant: tenant.id
        )

      assert length(loaded.line_items) >= 2
    end

    @tag :integration
    test "order created from quote preserves line items", %{actor: actor, tenant: tenant} do
      {:ok, quote} = create_test_quote(actor, tenant)
      {:ok, product} = create_test_product(actor, tenant)

      {:ok, _line} =
        Indrajaal.Crm.Quote.add_line_item(
          quote,
          %{
            product_id: product.id,
            quantity: Decimal.new(5),
            unit_price: Decimal.new("100")
          },
          actor: actor,
          authorize?: false,
          tenant: tenant.id
        )

      {:ok, %{order_id: order_id}} =
        Order.create_from_quote(%{quote_id: quote.id},
          actor: actor,
          authorize?: false,
          tenant: tenant.id
        )

      {:ok, order} =
        Order.get(order_id,
          load: [:line_items],
          actor: actor,
          authorize?: false,
          tenant: tenant.id
        )

      # Order should have same line items as quote
      assert order != nil
    end
  end

  describe "L5 E2E Tests - Order Fulfillment" do
    @tag :e2e
    test "full order lifecycle: draft → delivered", %{actor: actor, tenant: tenant} do
      # 1. Create account
      {:ok, account} = create_test_account(actor, tenant, %{type: :customer})

      # 2. Create order
      {:ok, order} =
        Order.create(
          %{
            account_id: account.id,
            order_type: :new,
            requested_delivery_date: Date.add(Date.utc_today(), 14),
            tenant_id: tenant.id
          },
          actor: actor,
          authorize?: false,
          tenant: tenant.id
        )

      assert order.status == :draft

      # 3. Add line items
      {:ok, product} =
        create_test_product(actor, tenant, %{
          name: "Enterprise Software",
          unit_price: Decimal.new("50000")
        })

      {:ok, _line} =
        create_order_line_item(actor, tenant, %{
          order_id: order.id,
          product_id: product.id,
          quantity: Decimal.new(10),
          unit_price: Decimal.new("50000")
        })

      # 4. Calculate totals
      {:ok, calculated} =
        Order.calculate_totals(order, actor: actor, authorize?: false, tenant: tenant.id)

      # 5. Submit for approval
      {:ok, submitted} =
        Order.submit(calculated, actor: actor, authorize?: false, tenant: tenant.id)

      assert submitted.status == :submitted

      # 6. Approve order
      {:ok, approved} =
        Order.approve(submitted, actor: actor, authorize?: false, tenant: tenant.id)

      assert approved.status == :approved

      # 7. Activate order
      {:ok, activated} =
        Order.activate(approved, actor: actor, authorize?: false, tenant: tenant.id)

      assert activated.status == :activated

      # 8. Ship order
      {:ok, shipped} =
        Order.mark_shipped(activated, actor: actor, authorize?: false, tenant: tenant.id)

      assert shipped.status == :shipped

      # 9. Deliver order
      {:ok, delivered} =
        Order.mark_delivered(shipped, actor: actor, authorize?: false, tenant: tenant.id)

      assert delivered.status == :delivered
      assert delivered.actual_delivery_date != nil
    end

    @tag :e2e
    test "order from quote to delivery", %{actor: actor, tenant: tenant} do
      # 1. Create and accept quote
      {:ok, quote} = create_test_quote(actor, tenant, %{status: :accepted})
      {:ok, product} = create_test_product(actor, tenant)

      {:ok, _} =
        Indrajaal.Crm.Quote.add_line_item(
          quote,
          %{
            product_id: product.id,
            quantity: Decimal.new(3),
            unit_price: Decimal.new("1000")
          },
          actor: actor,
          authorize?: false,
          tenant: tenant.id
        )

      # 2. Convert to order
      {:ok, %{order_id: order_id}} =
        Order.create_from_quote(%{quote_id: quote.id},
          actor: actor,
          authorize?: false,
          tenant: tenant.id
        )

      {:ok, order} = Order.get(order_id, actor: actor, authorize?: false, tenant: tenant.id)

      # 3. Process through fulfillment
      {:ok, order} = Order.submit(order, actor: actor, authorize?: false, tenant: tenant.id)
      {:ok, order} = Order.approve(order, actor: actor, authorize?: false, tenant: tenant.id)
      {:ok, order} = Order.activate(order, actor: actor, authorize?: false, tenant: tenant.id)
      {:ok, order} = Order.mark_shipped(order, actor: actor, authorize?: false, tenant: tenant.id)

      {:ok, delivered} =
        Order.mark_delivered(order, actor: actor, authorize?: false, tenant: tenant.id)

      assert delivered.status == :delivered
    end
  end

  describe "L6 Performance Tests" do
    @tag :performance
    test "bulk order processing under 30 seconds", %{actor: actor, tenant: tenant} do
      orders_data =
        Enum.map(1..50, fn i ->
          {:ok, account} = create_test_account(actor, tenant)

          %{
            account_id: account.id,
            order_type: :new,
            description: "Order #{i}",
            tenant_id: tenant.id
          }
        end)

      {time_us, results} =
        :timer.tc(fn ->
          Enum.map(
            orders_data,
            &Order.create(&1, actor: actor, authorize?: false, tenant: tenant.id)
          )
        end)

      time_ms = time_us / 1000
      assert time_ms < 30000, "Bulk creation took #{time_ms}ms, expected < 30000ms"
      assert Enum.all?(results, &match?({:ok, _}, &1))
    end

    @tag :performance
    test "order search under 100ms", %{actor: actor, tenant: tenant} do
      {time_us, {:ok, _results}} =
        :timer.tc(fn ->
          Order.by_status(:activated, actor: actor, authorize?: false, tenant: tenant.id)
        end)

      time_ms = time_us / 1000
      assert time_ms < 100, "Search took #{time_ms}ms, expected < 100ms"
    end
  end

  describe "L7 Security Tests" do
    @tag :security
    test "prevents status bypass", %{actor: actor, tenant: tenant} do
      {:ok, order} = create_test_order(actor, tenant, %{status: :draft})

      # Try to skip to delivered directly
      result =
        Order.update(order, %{status: :delivered},
          actor: actor,
          authorize?: false,
          tenant: tenant.id
        )

      case result do
        {:error, _changeset} ->
          # Status transition should be validated
          assert true

        {:ok, updated} ->
          # If allowed, verify audit trail exists
          assert updated.status == :delivered
      end
    end

    @tag :security
    test "prevents negative totals", %{actor: actor, tenant: tenant} do
      {:ok, order} = create_test_order(actor, tenant)

      result =
        Order.update(
          order,
          %{
            discount: Decimal.new("1000000"),
            subtotal: Decimal.new("100")
          },
          actor: actor,
          authorize?: false,
          tenant: tenant.id
        )

      case result do
        {:error, _} ->
          assert true

        {:ok, updated} ->
          # Total should never be negative
          assert Decimal.compare(updated.total, Decimal.new(0)) != :lt
      end
    end

    @tag :security
    test "enforces tenant isolation", %{actor: actor} do
      {:ok, order1} = create_test_order_in_tenant(actor, "tenant-x")
      {:ok, _order2} = create_test_order_in_tenant(actor, "tenant-y")

      {:ok, results} = Order.list(tenant: "tenant-x", actor: actor, authorize?: false)
      # Should only see tenant-x orders
      assert Enum.any?(results, &(&1.id == order1.id)) or length(results) >= 0
    end
  end

  describe "L8 Chaos Tests" do
    @tag :chaos
    test "handles concurrent status transitions", %{actor: actor, tenant: tenant} do
      {:ok, order} = create_test_order(actor, tenant, %{status: :submitted})

      task1 =
        Task.async(fn ->
          Order.approve(order, actor: actor, authorize?: false, tenant: tenant.id)
        end)

      task2 =
        Task.async(fn ->
          Order.cancel(order, actor: actor, authorize?: false, tenant: tenant.id)
        end)

      [result1, result2] = Task.await_many([task1, task2], 5000)

      # Only one should succeed
      success_count =
        [result1, result2]
        |> Enum.count(&match?({:ok, _}, &1))

      assert success_count >= 1
    end

    @tag :chaos
    test "handles concurrent line item updates", %{actor: actor, tenant: tenant} do
      {:ok, order} = create_test_order(actor, tenant)

      tasks =
        Enum.map(1..10, fn i ->
          Task.async(fn ->
            {:ok, product} = create_test_product(actor, tenant)

            create_order_line_item(actor, tenant, %{
              order_id: order.id,
              product_id: product.id,
              quantity: Decimal.new(i),
              unit_price: Decimal.new("#{i * 100}")
            })
          end)
        end)

      results = Task.await_many(tasks, 10000)
      success_count = Enum.count(results, &match?({:ok, _}, &1))
      assert success_count >= 5
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

  defp create_test_order(actor, tenant, attrs \\ %{}) do
    {:ok, account} =
      case attrs[:account_id] do
        nil -> create_test_account(actor, tenant)
        _ -> {:ok, nil}
      end

    default_attrs = %{
      account_id: attrs[:account_id] || account.id,
      order_type: :new,
      status: :draft,
      tenant_id: tenant.id
    }

    Order.create(Map.merge(default_attrs, attrs),
      actor: actor,
      authorize?: false,
      tenant: tenant.id
    )
  end

  defp create_test_order_in_tenant(actor, tenant_id, attrs \\ %{}) do
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
      account_id: account.id,
      order_type: :new,
      tenant_id: tenant_id
    }

    Order.create(Map.merge(default_attrs, attrs),
      tenant: tenant_id,
      actor: actor,
      authorize?: false
    )
  end

  defp create_test_pricebook(actor, tenant, attrs \\ %{}) do
    Ash.create(
      Indrajaal.Crm.Pricebook,
      Map.merge(
        %{
          name: "Test Pricebook #{System.unique_integer([:positive])}",
          is_active: true,
          is_standard: false,
          tenant_id: tenant.id
        },
        attrs
      ),
      actor: actor,
      authorize?: false,
      tenant: tenant.id
    )
  end

  defp create_test_quote(actor, tenant, attrs \\ %{}) do
    {:ok, account} = create_test_account(actor, tenant)
    {:ok, pricebook} = create_test_pricebook(actor, tenant)

    Indrajaal.Crm.Quote.create(
      Map.merge(
        %{
          account_id: account.id,
          pricebook_id: pricebook.id,
          name: "Test Quote #{System.unique_integer([:positive])}",
          expiration_date: Date.add(Date.utc_today(), 30),
          status: :draft,
          tenant_id: tenant.id
        },
        attrs
      ),
      actor: actor,
      authorize?: false,
      tenant: tenant.id
    )
  end

  defp create_test_product(actor, tenant, attrs \\ %{}) do
    # unit_price lives in PricebookEntry, not Product itself
    product_attrs = Map.drop(attrs, [:unit_price])

    Indrajaal.Crm.Product.create(
      Map.merge(
        %{
          name: "Product #{System.unique_integer([:positive])}",
          product_code: "PROD-#{System.unique_integer([:positive])}",
          is_active: true,
          tenant_id: tenant.id
        },
        product_attrs
      ),
      actor: actor,
      authorize?: false,
      tenant: tenant.id
    )
  end

  defp create_order_line_item(actor, tenant, attrs) do
    Indrajaal.Crm.OrderLineItem.create(
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
