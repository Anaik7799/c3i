defmodule Indrajaal.Billing.PlanTest do
  @moduledoc """
  TDG-compliant test suite for Indrajaal.Billing.Plan Ash resource.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written before implementation hardening
  - FPPS Validation: Plan lifecycle verified across 5 status states (draft/active/inactive/deprecated/grandfathered)

  ## STAMP Safety Integration
  - SC-COV-001: Critical billing plan lifecycle coverage
  - SC-COV-006: TDG compliance mandatory
  - SC-DB-001: Uses BaseResource pattern
  - SC-DB-005: uuid_primary_key verified

  ## Constitutional Verification
  - Psi0 Existence: Billing plans persist through all lifecycle states
  - Psi2 Evolutionary Continuity: Plan status transitions are fully auditable

  ## Founder's Directive Alignment
  - Omega0.1: Correct plan management enables revenue streams for Founder's enrichment

  ## TPS 5-Level RCA Context
  - L1 Symptom: Plans not transitioning from draft to active correctly
  - L5 Root Cause: Missing status precondition validation in activate action

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-03-21 | Claude | Initial TDG test generation |
  """

  use Indrajaal.DataCase, async: false

  alias Indrajaal.Billing.Plan

  require Ash.Query

  @moduletag :zenoh_nif

  @valid_attrs %{
    plan_code: "BASIC-001",
    plan_name: "Basic Security Plan",
    plan_type: :basic,
    service_tier: :bronze,
    billing_model: :subscription,
    billing_f_requency: :monthly,
    base_price: Decimal.new("99.00"),
    currency: "USD"
  }

  # ---------------------------------------------------------------------------
  # create action
  # ---------------------------------------------------------------------------

  describe "create/1" do
    test "creates a plan with required attributes" do
      assert {:ok, plan} = Plan.create(@valid_attrs)
      assert plan.id != nil
      assert plan.plan_code == "BASIC-001"
      assert plan.plan_name == "Basic Security Plan"
    end

    test "defaults status to :draft on creation" do
      assert {:ok, plan} = Plan.create(@valid_attrs)
      assert plan.status == :draft
    end

    test "defaults subscriber_count to 0 on creation" do
      assert {:ok, plan} = Plan.create(@valid_attrs)
      assert plan.subscriber_count == 0
    end

    test "uuid primary key is a valid UUID string" do
      assert {:ok, plan} = Plan.create(@valid_attrs)
      assert is_binary(plan.id)
      assert String.length(plan.id) == 36
    end

    test "defaults plan_type to :standard when not provided" do
      attrs = Map.delete(@valid_attrs, :plan_type)
      assert {:ok, plan} = Plan.create(attrs)
      assert plan.plan_type == :standard
    end

    test "defaults service_tier to :silver when not provided" do
      attrs = Map.delete(@valid_attrs, :service_tier)
      assert {:ok, plan} = Plan.create(attrs)
      assert plan.service_tier == :silver
    end

    test "defaults billing_model to :subscription when not provided" do
      attrs = Map.delete(@valid_attrs, :billing_model)
      assert {:ok, plan} = Plan.create(attrs)
      assert plan.billing_model == :subscription
    end

    test "defaults billing_frequency to :monthly when not provided" do
      attrs = Map.delete(@valid_attrs, :billing_f_requency)
      assert {:ok, plan} = Plan.create(attrs)
      assert plan.billing_f_requency == :monthly
    end

    test "creates enterprise plan type" do
      attrs = Map.put(@valid_attrs, :plan_type, :enterprise)
      assert {:ok, plan} = Plan.create(attrs)
      assert plan.plan_type == :enterprise
    end

    test "creates premium plan with platinum tier" do
      attrs = @valid_attrs |> Map.put(:plan_type, :premium) |> Map.put(:service_tier, :platinum)
      assert {:ok, plan} = Plan.create(attrs)
      assert plan.plan_type == :premium
      assert plan.service_tier == :platinum
    end

    test "creates usage_based billing model" do
      attrs = Map.put(@valid_attrs, :billing_model, :usage_based)
      assert {:ok, plan} = Plan.create(attrs)
      assert plan.billing_model == :usage_based
    end

    test "creates annual billing frequency" do
      attrs = Map.put(@valid_attrs, :billing_f_requency, :annual)
      assert {:ok, plan} = Plan.create(attrs)
      assert plan.billing_f_requency == :annual
    end

    test "fails without required plan_code" do
      attrs = Map.delete(@valid_attrs, :plan_code)
      assert {:error, _} = Plan.create(attrs)
    end

    test "fails without required plan_name" do
      attrs = Map.delete(@valid_attrs, :plan_name)
      assert {:error, _} = Plan.create(attrs)
    end

    test "defaults version to 1.0" do
      assert {:ok, plan} = Plan.create(@valid_attrs)
      assert plan.version == "1.0"
    end

    test "two plans get distinct ids" do
      attrs2 = Map.put(@valid_attrs, :plan_code, "BASIC-002")
      assert {:ok, p1} = Plan.create(@valid_attrs)
      assert {:ok, p2} = Plan.create(attrs2)
      refute p1.id == p2.id
    end
  end

  # ---------------------------------------------------------------------------
  # activate action (status must be :draft)
  # ---------------------------------------------------------------------------

  describe "activate/1" do
    test "transitions draft plan to :active" do
      assert {:ok, plan} = Plan.create(@valid_attrs)
      assert {:ok, activated} = Plan.activate(plan.id)
      assert activated.status == :active
    end

    test "sets effective_date on activation" do
      assert {:ok, plan} = Plan.create(@valid_attrs)
      assert {:ok, activated} = Plan.activate(plan.id)
      assert %Date{} = activated.effective_date
    end

    test "returns error for already active plan" do
      assert {:ok, plan} = Plan.create(@valid_attrs)
      assert {:ok, _activated} = Plan.activate(plan.id)
      # Already :active — cannot activate again from :active state (requires :draft)
      assert {:error, _} = Plan.activate(plan.id)
    end
  end

  # ---------------------------------------------------------------------------
  # deactivate action (status must be :active)
  # ---------------------------------------------------------------------------

  describe "deactivate/1" do
    test "transitions active plan to :inactive" do
      assert {:ok, plan} = Plan.create(@valid_attrs)
      assert {:ok, activated} = Plan.activate(plan.id)
      assert {:ok, deactivated} = Plan.deactivate(activated.id)
      assert deactivated.status == :inactive
    end

    test "returns error for draft plan (not :active)" do
      assert {:ok, plan} = Plan.create(@valid_attrs)
      assert {:error, _} = Plan.deactivate(plan.id)
    end
  end

  # ---------------------------------------------------------------------------
  # deprecate action (status must be :active or :inactive)
  # ---------------------------------------------------------------------------

  describe "deprecate/1" do
    test "deprecates an active plan" do
      assert {:ok, plan} = Plan.create(@valid_attrs)
      assert {:ok, activated} = Plan.activate(plan.id)
      assert {:ok, deprecated} = Plan.deprecate(activated.id)
      assert deprecated.status == :deprecated
    end

    test "deprecates an inactive plan" do
      assert {:ok, plan} = Plan.create(@valid_attrs)
      assert {:ok, activated} = Plan.activate(plan.id)
      assert {:ok, deactivated} = Plan.deactivate(activated.id)
      assert {:ok, deprecated} = Plan.deprecate(deactivated.id)
      assert deprecated.status == :deprecated
    end

    test "sets end_date on deprecation" do
      assert {:ok, plan} = Plan.create(@valid_attrs)
      assert {:ok, activated} = Plan.activate(plan.id)
      assert {:ok, deprecated} = Plan.deprecate(activated.id)
      assert %Date{} = deprecated.end_date
    end

    test "returns error for draft plan (not active or inactive)" do
      assert {:ok, plan} = Plan.create(@valid_attrs)
      assert {:error, _} = Plan.deprecate(plan.id)
    end
  end

  # ---------------------------------------------------------------------------
  # grandfather action (status must be :deprecated)
  # ---------------------------------------------------------------------------

  describe "grandfather/1" do
    test "grandfathers a deprecated plan" do
      assert {:ok, plan} = Plan.create(@valid_attrs)
      assert {:ok, activated} = Plan.activate(plan.id)
      assert {:ok, deprecated} = Plan.deprecate(activated.id)
      assert {:ok, grandfathered} = Plan.grandfather(deprecated.id)
      assert grandfathered.status == :grandfathered
    end

    test "sets grandfathered? to true" do
      assert {:ok, plan} = Plan.create(@valid_attrs)
      assert {:ok, activated} = Plan.activate(plan.id)
      assert {:ok, deprecated} = Plan.deprecate(activated.id)
      assert {:ok, grandfathered} = Plan.grandfather(deprecated.id)
      assert grandfathered.grandfathered? == true
    end

    test "returns error for active plan (not :deprecated)" do
      assert {:ok, plan} = Plan.create(@valid_attrs)
      assert {:ok, activated} = Plan.activate(plan.id)
      assert {:error, _} = Plan.grandfather(activated.id)
    end
  end

  # ---------------------------------------------------------------------------
  # update_subscriber_count action
  # ---------------------------------------------------------------------------

  describe "update_subscriber_count/2" do
    test "updates subscriber count to specified value" do
      assert {:ok, plan} = Plan.create(@valid_attrs)

      assert {:ok, updated} =
               Plan.update_subscriber_count(plan.id, %{count: 42})

      assert updated.subscriber_count == 42
    end

    test "can set subscriber_count to zero" do
      assert {:ok, plan} = Plan.create(@valid_attrs)
      assert {:ok, updated} = Plan.update_subscriber_count(plan.id, %{count: 0})
      assert updated.subscriber_count == 0
    end

    test "returns error for negative count" do
      assert {:ok, plan} = Plan.create(@valid_attrs)
      assert {:error, _} = Plan.update_subscriber_count(plan.id, %{count: -1})
    end
  end

  # ---------------------------------------------------------------------------
  # read action
  # ---------------------------------------------------------------------------

  describe "read/1" do
    test "reads back a created plan by id" do
      assert {:ok, plan} = Plan.create(@valid_attrs)

      assert {:ok, [found]} =
               Plan
               |> Ash.Query.filter(id == ^plan.id)
               |> Ash.read(authorize?: false)

      assert found.id == plan.id
      assert found.plan_code == plan.plan_code
    end

    test "returns empty list for nonexistent id" do
      random_id = Ecto.UUID.generate()

      assert {:ok, []} =
               Plan
               |> Ash.Query.filter(id == ^random_id)
               |> Ash.read(authorize?: false)
    end
  end

  # ---------------------------------------------------------------------------
  # Full lifecycle test (Constitutional Psi2)
  # ---------------------------------------------------------------------------

  describe "complete plan lifecycle (Psi2 evolutionary continuity)" do
    test "draft -> active -> deprecated -> grandfathered" do
      assert {:ok, p0} = Plan.create(Map.put(@valid_attrs, :plan_code, "LIFECYCLE-001"))
      assert p0.status == :draft

      assert {:ok, p1} = Plan.activate(p0.id)
      assert p1.status == :active

      assert {:ok, p2} = Plan.deprecate(p1.id)
      assert p2.status == :deprecated

      assert {:ok, p3} = Plan.grandfather(p2.id)
      assert p3.status == :grandfathered
      assert p3.grandfathered? == true
    end

    test "draft -> active -> inactive -> deprecated" do
      assert {:ok, p0} = Plan.create(Map.put(@valid_attrs, :plan_code, "LIFECYCLE-002"))
      assert {:ok, p1} = Plan.activate(p0.id)
      assert {:ok, p2} = Plan.deactivate(p1.id)
      assert {:ok, p3} = Plan.deprecate(p2.id)
      assert p3.status == :deprecated
    end
  end

  # ---------------------------------------------------------------------------
  # Service tier and billing model coverage
  # ---------------------------------------------------------------------------

  describe "service_tier enum coverage" do
    for tier <- [:bronze, :silver, :gold, :platinum, :diamond] do
      @tier tier
      test "creates plan with service_tier #{tier}" do
        attrs =
          @valid_attrs
          |> Map.put(:service_tier, @tier)
          |> Map.put(:plan_code, "TIER-#{:rand.uniform(99999)}")

        assert {:ok, plan} = Plan.create(attrs)
        assert plan.service_tier == @tier
      end
    end
  end
end
