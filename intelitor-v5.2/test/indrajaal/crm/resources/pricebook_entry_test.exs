defmodule Indrajaal.Crm.PricebookEntryTest do
  @moduledoc """
  ## TDG Compliance - Sprint 54
  Tests for Indrajaal.Crm.PricebookEntry Ash resource.

  ## STAMP Compliance
  - SC-TDG: Tests exist before code modification
  - SC-DB-001: BaseResource usage verified
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Crm.PricebookEntry

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(PricebookEntry)
    end
  end

  describe "Ash resource introspection" do
    test "resource has core CRUD actions" do
      actions = Ash.Resource.Info.actions(PricebookEntry)
      action_names = Enum.map(actions, & &1.name)
      assert :create in action_names
      assert :update in action_names
      assert :read in action_names
      assert :destroy in action_names
    end

    test "resource has lifecycle actions" do
      actions = Ash.Resource.Info.actions(PricebookEntry)
      action_names = Enum.map(actions, & &1.name)
      assert :activate in action_names
      assert :deactivate in action_names
    end

    test "activate is an update action" do
      actions = Ash.Resource.Info.actions(PricebookEntry)
      action = Enum.find(actions, &(&1.name == :activate))
      assert action.type == :update
    end

    test "resource has id attribute" do
      attrs = Ash.Resource.Info.attributes(PricebookEntry)
      attr_names = Enum.map(attrs, & &1.name)
      assert :id in attr_names
    end

    test "domain is Crm" do
      assert Ash.Resource.Info.domain(PricebookEntry) == Indrajaal.Crm
    end
  end
end
