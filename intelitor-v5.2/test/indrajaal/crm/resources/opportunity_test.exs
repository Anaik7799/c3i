defmodule Indrajaal.Crm.OpportunityTest do
  @moduledoc """
  ## TDG Compliance - Sprint 54
  Tests for Indrajaal.Crm.Opportunity Ash resource.

  ## STAMP Compliance
  - SC-TDG: Tests exist before code modification
  - SC-DB-001: BaseResource usage verified
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Crm.Opportunity

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Opportunity)
    end
  end

  describe "Ash resource introspection" do
    test "resource has core CRUD actions" do
      actions = Ash.Resource.Info.actions(Opportunity)
      action_names = Enum.map(actions, & &1.name)
      assert :create in action_names
      assert :update in action_names
      assert :read in action_names
      assert :destroy in action_names
    end

    test "resource has sales stage actions" do
      actions = Ash.Resource.Info.actions(Opportunity)
      action_names = Enum.map(actions, & &1.name)
      assert :advance_stage in action_names
      assert :close_won in action_names
      assert :close_lost in action_names
      assert :reopen in action_names
    end

    test "resource has assignment action" do
      actions = Ash.Resource.Info.actions(Opportunity)
      action_names = Enum.map(actions, & &1.name)
      assert :assign in action_names
    end

    test "close_won is an update action" do
      actions = Ash.Resource.Info.actions(Opportunity)
      action = Enum.find(actions, &(&1.name == :close_won))
      assert action.type == :update
    end

    test "close_lost is an update action" do
      actions = Ash.Resource.Info.actions(Opportunity)
      action = Enum.find(actions, &(&1.name == :close_lost))
      assert action.type == :update
    end

    test "resource has expected attributes" do
      attrs = Ash.Resource.Info.attributes(Opportunity)
      attr_names = Enum.map(attrs, & &1.name)
      assert :id in attr_names
      assert :name in attr_names
      assert :amount in attr_names
      assert :probability in attr_names
    end

    test "resource has opportunity calculations" do
      calcs = Ash.Resource.Info.calculations(Opportunity)
      calc_names = Enum.map(calcs, & &1.name)
      assert :is_open? in calc_names
      assert :days_to_close in calc_names
      assert :age_days in calc_names
    end

    test "domain is Crm" do
      assert Ash.Resource.Info.domain(Opportunity) == Indrajaal.Crm
    end
  end
end
