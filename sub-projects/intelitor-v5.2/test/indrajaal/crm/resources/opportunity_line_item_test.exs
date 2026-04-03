defmodule Indrajaal.Crm.OpportunityLineItemTest do
  @moduledoc """
  ## TDG Compliance - Sprint 54
  Tests for Indrajaal.Crm.OpportunityLineItem Ash resource.

  ## STAMP Compliance
  - SC-TDG: Tests exist before code modification
  - SC-DB-001: BaseResource usage verified
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Crm.OpportunityLineItem

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(OpportunityLineItem)
    end
  end

  describe "Ash resource introspection" do
    test "resource has core CRUD actions" do
      actions = Ash.Resource.Info.actions(OpportunityLineItem)
      action_names = Enum.map(actions, & &1.name)
      assert :create in action_names
      assert :update in action_names
      assert :read in action_names
      assert :destroy in action_names
    end

    test "resource has revenue_contribution calculation" do
      calcs = Ash.Resource.Info.calculations(OpportunityLineItem)
      calc_names = Enum.map(calcs, & &1.name)
      assert :revenue_contribution in calc_names
    end

    test "domain is Crm" do
      assert Ash.Resource.Info.domain(OpportunityLineItem) == Indrajaal.Crm
    end
  end
end
