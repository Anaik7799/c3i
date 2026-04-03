defmodule Indrajaal.Billing.SubscriptionTest do
  use Indrajaal.DataCase

  alias Indrajaal.Billing.{Subscription, Plan, Invoice, Payment, UsageRecord}
  alias Indrajaal.Core.{Tenant, Organization}

  describe "Subscription resource" do
    setup do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant: tenant)
      plan = insert(:plan, tenant: tenant)

      {:ok, tenant: tenant, organization: organization, plan: plan}
    end

    test "creates a subscription with valid attributes", %{
      tenant: tenant,
      organization: organization,
      plan: plan
    } do
      attrs = %{
        subscription_name: "Enterprise Security Plan",
        status: :active,
        billing_cycle: :monthly,
        start_date: Date.utc_today(),
        end_date: Date.utc_today() |> Date.add(365),
        auto_renew: true,
        pricing_model: :tiered,
        base_amount: Decimal.new("299.99"),
        currency: "USD",
        subscription_details: %{
          "included_sites" => 10,
          "included_devices" => 100,
          "included_storage_gb" => 500,
          "included_users" => 25
        },
        billing_config: %{
          "billing_day" => 1,
          "grace_period_days" => 5,
          "late_fee_percentage" => 2.5,
          "dunning_enabled" => true
        },
        plan_id: plan.id,
        organization_id: organization.id,
        tenant_id: tenant.id
      }

      {:ok, subscription} = Subscription.create(attrs)

      assert subscription.subscription_name == "Enterprise Security Plan"
      assert subscription.status == :active
      assert subscription.billing_cycle == :monthly
      assert subscription.auto_renew == true
      assert subscription.pricing_model == :tiered
      assert Decimal.equal?(subscription.base_amount, Decimal.new("299.99"))
      assert subscription.currency == "USD"
      assert subscription.subscription_details["included_sites"] == 10
      assert subscription.billing_config["billing_day"] == 1
      assert subscription.plan_id == plan.id
      assert subscription.organization_id == organization.id
      assert subscription.tenant_id == tenant.id
    end

    test "validates required fields", %{tenant: tenant} do
      {:error, changeset} = Subscription.create(%{tenant_id: tenant.id})

      assert changeset.errors[:subscription_name]
      assert changeset.errors[:billing_cycle]
      assert changeset.errors[:base_amount]
      assert changeset.errors[:currency]
      assert changeset.errors[:plan_id]
      assert changeset.errors[:organization_id]
    end

    test "manages subscription status transitions", %{
      tenant: tenant,
      organization: organization,
      plan: plan
    } do
      subscription =
        insert(:subscription,
          status: :trial,
          tenant: tenant,
          organization: organization,
          plan: plan
        )

      # Trial -> Active
      {:ok, active_sub} =
        Subscription.activate(subscription, %{
          payment_method_id: "pm_123456",
          activation_notes: "Trial converted to paid subscription"
        })

      assert active_sub.status == :active
      assert active_sub.metadata["activation_record"]

      # Active -> Suspended
      {:ok, suspended_sub} =
        Subscription.suspend(active_sub, %{
          suspension_reason: "Payment failure",
          suspended_by: "billing_system"
        })

      assert suspended_sub.status == :suspended
      assert suspended_sub.metadata["suspension_record"]["reason"] == "Payment
        failure"

      # Suspended -> Active
      {:ok, reactivated_sub} =
        Subscription.reactivate(suspended_sub, %{
          reactivation_notes: "Payment method updated"
        })

      assert reactivated_sub.status == :active
    end

    test "calculates usage - based billing", %{
      tenant: tenant,
      organization: organization,
      plan: plan
    } do
      subscription =
        insert(:subscription,
          pricing_model: :usage_based,
          subscription_details: %{
            "included_sites" => 5,
            "overage_rate_per_site" => 50.00,
            "included_storage_gb" => 100,
            "overage_rate_per_gb" => 0.50
          },
          tenant: tenant,
          organization: organization,
          plan: plan
        )

      # Record usage that exceeds included amounts
      usage_data = %{
        "sites_used" => 8,
        "storage_used_gb" => 150,
        "users_active" => 15,
        "devices_connected" => 85
      }

      {:ok, sub_with_usage} =
        Subscription.record_usage(subscription, %{
          usage_period: Date.utc_today(),
          usage_data: usage_data
        })

      sub_with_calc = Subscription.read!(sub_with_usage.id, load: [:overage_amount])
      # 150 + 25 = 175
      expected_overage = (8 - 5) * 50.00 + (150 - 100) * 0.50
      assert Decimal.equal?(sub_with_calc.overage_amount, Decimal.new("175.00"))
    end

    test "handles subscription renewals", %{
      tenant: tenant,
      organization: organization,
      plan: plan
    } do
      subscription =
        insert(:subscription,
          auto_renew: true,
          # Expires in 30 days
          end_date: Date.utc_today() |> Date.add(30),
          tenant: tenant,
          organization: organization,
          plan: plan
        )

      {:ok, renewed_sub} =
        Subscription.process_renewal(subscription, %{
          renewal_date: Date.utc_today() |> Date.add(30),
          # 1 year + 30 days
          new_end_date: Date.utc_today() |> Date.add(395),
          # Price increase
          price_adjustment: Decimal.new("50.00")
        })

      assert renewed_sub.metadata["renewal_history"]
      renewal = List.first(renewed_sub.metadata["renewal_history"])
      assert renewal["renewal_date"]
      assert Decimal.equal?(renewal["price_adjustment"], Decimal.new("50.00"))
    end

    test "generates invoices for subscription", %{
      tenant: tenant,
      organization: organization,
      plan: plan
    } do
      subscription =
        insert(:subscription,
          base_amount: Decimal.new("299.99"),
          billing_cycle: :monthly,
          tenant: tenant,
          organization: organization,
          plan: plan
        )

      {:ok, invoice} =
        Subscription.generate_invoice(subscription, %{
          invoice_date: Date.utc_today(),
          due_date: Date.utc_today() |> Date.add(30),
          billing_period_start: Date.utc_today() |> Date.add(-30),
          billing_period_end: Date.utc_today()
        })

      assert invoice.subscription_id == subscription.id
      assert Decimal.equal?(invoice.amount, Decimal.new("299.99"))
      assert invoice.status == :pending
    end

    test "applies discounts and promotions", %{
      tenant: tenant,
      organization: organization,
      plan: plan
    } do
      subscription =
        insert(:subscription,
          base_amount: Decimal.new("299.99"),
          tenant: tenant,
          organization: organization,
          plan: plan
        )

      discount_config = %{
        "discount_type" => "percentage",
        # 15% discount
        "discount_value" => 15.0,
        # 6 months
        "discount_duration" => 6,
        "promotion_code" => "SAVE15",
        "applied_by" => "sales_team"
      }

      {:ok, discounted_sub} =
        Subscription.apply_discount(subscription, %{
          discount: discount_config
        })

      sub_with_calc = Subscription.read!(discounted_sub.id, load: [:discounted_amount])
      # 15% off
      expected_discounted = Decimal.mult(Decimal.new("299.99"), Decimal.new("0.85"))
      assert Decimal.equal?(sub_with_calc.discounted_amount, expected_discounted)
    end

    test "tracks subscription metrics",
         %{tenant: tenant, organization: organization, plan: plan} do
      subscription =
        insert(:subscription,
          # 90 days ago
          start_date: Date.utc_today() |> Date.add(-90),
          tenant: tenant,
          organization: organization,
          plan: plan
        )

      # Record payments
      for i <- 1..3 do
        insert(:payment,
          subscription: subscription,
          amount: Decimal.new("299.99"),
          status: :completed,
          payment_date: Date.utc_today() |> Date.add(-30 * i),
          tenant: tenant
        )
      end

      sub_with_calc =
        Subscription.read!(subscription.id,
          load: [
            :total_revenue,
            :days_active,
            :payment_success_rate
          ]
        )

      # 3 * 299.99
      assert Decimal.equal?(sub_with_calc.total_revenue, Decimal.new("899.97"))
      assert sub_with_calc.days_active >= 85
      assert sub_with_calc.payment_success_rate == 100.0
    end

    test "manages subscription add - ons",
         %{tenant: tenant, organization: organization, plan: plan} do
      subscription =
        insert(:subscription,
          tenant: tenant,
          organization: organization,
          plan: plan
        )

      add_ons = [
        %{
          "addon_name" => "Extra Storage",
          "addon_type" => "storage",
          # 500 GB
          "quantity" => 500,
          "unit_price" => 0.10,
          "billing_cycle" => "monthly"
        },
        %{
          "addon_name" => "Premium Support",
          "addon_type" => "support",
          "quantity" => 1,
          "unit_price" => 99.99,
          "billing_cycle" => "monthly"
        }
      ]

      {:ok, sub_with_addons} =
        Subscription.add_addons(subscription, %{
          addons: add_ons
        })

      assert length(sub_with_addons.addons) == 2
      storage_addon = Enum.find(sub_with_addons.addons, &(&1["addon_type"] == "storage"))
      assert storage_addon["quantity"] == 500
    end

    test "handles subscription cancellation", %{
      tenant: tenant,
      organization: organization,
      plan: plan
    } do
      subscription =
        insert(:subscription,
          status: :active,
          tenant: tenant,
          organization: organization,
          plan: plan
        )

      {:ok, cancelled_sub} =
        Subscription.cancel(subscription, %{
          cancellation_reason: "Customer request",
          cancellation_type: "end_of_period",
          cancelled_by: "customer_service",
          refund_requested: false
        })

      assert cancelled_sub.status == :cancelled
      assert cancelled_sub.metadata["cancellation_record"]
      cancellation = cancelled_sub.metadata["cancellation_record"]
      assert cancellation["reason"] == "Customer request"
      assert cancellation["type"] == "end_of_period"
    end

    test "calculates customer lifetime value", %{
      tenant: tenant,
      organization: organization,
      plan: plan
    } do
      subscription =
        insert(:subscription,
          # 1 year ago
          start_date: Date.utc_today() |> Date.add(-365),
          base_amount: Decimal.new("299.99"),
          billing_cycle: :monthly,
          tenant: tenant,
          organization: organization,
          plan: plan
        )

      # Simulate 12 months of payments
      total_paid = Decimal.mult(Decimal.new("299.99"), Decimal.new("12"))

      {:ok, _} =
        Subscription.record_payment_history(subscription, %{
          total_payments: total_paid,
          payment_count: 12,
          average_payment: Decimal.new("299.99")
        })

      sub_with_calc = Subscription.read!(subscription.id, load: [:customer_lifetime_value])
      assert Decimal.gt?(sub_with_calc.customer_lifetime_value, Decimal.new("3000"))
    end

    test "enforces tenant isolation",
         %{organization: organization, plan: plan} do
      tenant1 = organization.tenant
      tenant2 = insert(:tenant)
      organization2 = insert(:organization, tenant: tenant2)
      plan2 = insert(:plan, tenant: tenant2)

      sub1 = insert(:subscription, tenant: tenant1, organization: organization, plan: plan)
      sub2 = insert(:subscription, tenant: tenant2, organization: organization2, plan: plan2)

      tenant1_subs = Subscription.read!(tenant: tenant1)
      tenant2_subs = Subscription.read!(tenant: tenant2)

      assert length(tenant1_subs) == 1
      assert length(tenant2_subs) == 1
      assert Enum.any?(tenant1_subs, &(&1.id == sub1.id))
      assert Enum.any?(tenant2_subs, &(&1.id == sub2.id))
      refute Enum.any?(tenant1_subs, &(&1.id == sub2.id))
      refute Enum.any?(tenant2_subs, &(&1.id == sub1.id))
    end

    test "validates billing compliance",
         %{tenant: tenant, organization: organization, plan: plan} do
      subscription =
        insert(:subscription,
          tenant: tenant,
          organization: organization,
          plan: plan
        )

      compliance_data = %{
        "tax_compliance" => %{
          "tax_rate" => 8.5,
          "tax_jurisdiction" => "CA - US",
          "tax_exempt" => false
        },
        "regulatory_compliance" => %{
          "gdpr_compliant" => true,
          "ccpa_compliant" => true,
          # 7 years
          "data_retention_days" => 2555
        },
        "financial_compliance" => %{
          "revenue_recognition" => "monthly",
          "accounting_method" => "accrual"
        }
      }

      {:ok, compliant_sub} =
        Subscription.update_compliance_settings(subscription, %{
          compliance_settings: compliance_data
        })

      assert compliant_sub.compliance_settings["tax_compliance"]["tax_rate"] ==
               8.5

      assert compliant_sub.compliance_settings["regulatory_compliance"]["gdpr_compliant"] ==
               true
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
