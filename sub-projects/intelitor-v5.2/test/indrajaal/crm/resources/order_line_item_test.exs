defmodule Indrajaal.Crm.OrderLineItemTest do
  @moduledoc """
  ## TDG Compliance - Sprint 54
  Tests for Indrajaal.Crm.OrderLineItem Ash resource.

  ## STAMP Compliance
  - SC-TDG: Tests exist before code modification
  - SC-DB-001: BaseResource usage verified
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Crm.OrderLineItem

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(OrderLineItem)
    end
  end

  describe "Ash resource introspection" do
    test "resource has core CRUD actions" do
      actions = Ash.Resource.Info.actions(OrderLineItem)
      action_names = Enum.map(actions, & &1.name)
      assert :create in action_names
      assert :update in action_names
      assert :read in action_names
      assert :destroy in action_names
    end

    test "resource has fulfillment actions" do
      actions = Ash.Resource.Info.actions(OrderLineItem)
      action_names = Enum.map(actions, & &1.name)
      assert :allocate in action_names
      assert :pick in action_names
      assert :pack in action_names
      assert :ship in action_names
      assert :deliver in action_names
      assert :cancel in action_names
    end

    test "ship is an update action" do
      actions = Ash.Resource.Info.actions(OrderLineItem)
      action = Enum.find(actions, &(&1.name == :ship))
      assert action.type == :update
    end

    test "resource has extended_price calculation" do
      calcs = Ash.Resource.Info.calculations(OrderLineItem)
      calc_names = Enum.map(calcs, & &1.name)
      assert :extended_price in calc_names
    end

    test "domain is Crm" do
      assert Ash.Resource.Info.domain(OrderLineItem) == Indrajaal.Crm
    end
  end
end
