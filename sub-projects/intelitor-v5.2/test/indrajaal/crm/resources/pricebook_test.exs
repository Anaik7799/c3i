defmodule Indrajaal.Crm.PricebookTest do
  @moduledoc """
  ## TDG Compliance - Sprint 54
  Tests for Indrajaal.Crm.Pricebook Ash resource.

  ## STAMP Compliance
  - SC-TDG: Tests exist before code modification
  - SC-DB-001: BaseResource usage verified
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Crm.Pricebook

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Pricebook)
    end
  end

  describe "Ash resource introspection" do
    test "resource has core CRUD actions" do
      actions = Ash.Resource.Info.actions(Pricebook)
      action_names = Enum.map(actions, & &1.name)
      assert :create in action_names
      assert :update in action_names
      assert :read in action_names
      assert :destroy in action_names
    end

    test "resource has lifecycle actions" do
      actions = Ash.Resource.Info.actions(Pricebook)
      action_names = Enum.map(actions, & &1.name)
      assert :activate in action_names
      assert :deactivate in action_names
    end

    test "activate is an update action" do
      actions = Ash.Resource.Info.actions(Pricebook)
      action = Enum.find(actions, &(&1.name == :activate))
      assert action.type == :update
    end

    test "deactivate is an update action" do
      actions = Ash.Resource.Info.actions(Pricebook)
      action = Enum.find(actions, &(&1.name == :deactivate))
      assert action.type == :update
    end

    test "resource has expected attributes" do
      attrs = Ash.Resource.Info.attributes(Pricebook)
      attr_names = Enum.map(attrs, & &1.name)
      assert :id in attr_names
      assert :name in attr_names
      assert :is_active in attr_names
    end

    test "domain is Crm" do
      assert Ash.Resource.Info.domain(Pricebook) == Indrajaal.Crm
    end
  end
end
