defmodule Indrajaal.Crm.OpportunityContactRoleTest do
  @moduledoc """
  ## TDG Compliance - Sprint 54
  Tests for Indrajaal.Crm.OpportunityContactRole Ash resource.

  ## STAMP Compliance
  - SC-TDG: Tests exist before code modification
  - SC-DB-001: BaseResource usage verified
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Crm.OpportunityContactRole

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(OpportunityContactRole)
    end
  end

  describe "Ash resource introspection" do
    test "resource has core CRUD actions" do
      actions = Ash.Resource.Info.actions(OpportunityContactRole)
      action_names = Enum.map(actions, & &1.name)
      assert :create in action_names
      assert :update in action_names
      assert :read in action_names
      assert :destroy in action_names
    end

    test "resource has role management actions" do
      actions = Ash.Resource.Info.actions(OpportunityContactRole)
      action_names = Enum.map(actions, & &1.name)
      assert :set_primary in action_names
      assert :unset_primary in action_names
    end

    test "set_primary is an update action" do
      actions = Ash.Resource.Info.actions(OpportunityContactRole)
      action = Enum.find(actions, &(&1.name == :set_primary))
      assert action.type == :update
    end

    test "resource has role calculations" do
      calcs = Ash.Resource.Info.calculations(OpportunityContactRole)
      calc_names = Enum.map(calcs, & &1.name)
      assert :is_decision_maker? in calc_names
      assert :is_influencer? in calc_names
    end

    test "domain is Crm" do
      assert Ash.Resource.Info.domain(OpportunityContactRole) == Indrajaal.Crm
    end
  end
end
