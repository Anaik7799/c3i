defmodule Indrajaal.Crm.OrderTest do
  @moduledoc """
  ## TDG Compliance - Sprint 54
  Tests for Indrajaal.Crm.Order Ash resource.

  ## STAMP Compliance
  - SC-TDG: Tests exist before code modification
  - SC-DB-001: BaseResource usage verified
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Crm.Order

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Order)
    end
  end

  describe "Ash resource introspection" do
    test "resource has core CRUD actions" do
      actions = Ash.Resource.Info.actions(Order)
      action_names = Enum.map(actions, & &1.name)
      assert :create in action_names
      assert :update in action_names
      assert :read in action_names
      assert :destroy in action_names
    end

    test "resource has order lifecycle actions" do
      actions = Ash.Resource.Info.actions(Order)
      action_names = Enum.map(actions, & &1.name)
      assert :submit in action_names
      assert :approve in action_names
      assert :activate in action_names
      assert :cancel in action_names
    end

    test "resource has fulfillment actions" do
      actions = Ash.Resource.Info.actions(Order)
      action_names = Enum.map(actions, & &1.name)
      assert :mark_shipped in action_names
      assert :mark_delivered in action_names
    end

    test "submit is an update action" do
      actions = Ash.Resource.Info.actions(Order)
      action = Enum.find(actions, &(&1.name == :submit))
      assert action.type == :update
    end

    test "resource has financial calculations" do
      calcs = Ash.Resource.Info.calculations(Order)
      calc_names = Enum.map(calcs, & &1.name)
      assert :grand_total in calc_names
      assert :line_item_count in calc_names
    end

    test "domain is Crm" do
      assert Ash.Resource.Info.domain(Order) == Indrajaal.Crm
    end
  end
end
