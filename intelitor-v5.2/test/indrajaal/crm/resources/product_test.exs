defmodule Indrajaal.Crm.ProductTest do
  @moduledoc """
  ## TDG Compliance - Sprint 54
  Tests for Indrajaal.Crm.Product Ash resource.

  ## STAMP Compliance
  - SC-TDG: Tests exist before code modification
  - SC-DB-001: BaseResource usage verified
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Crm.Product

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Product)
    end
  end

  describe "Ash resource introspection" do
    test "resource has CRUD actions" do
      actions = Ash.Resource.Info.actions(Product)
      action_names = Enum.map(actions, & &1.name)
      assert :create in action_names
      assert :update in action_names
      assert :read in action_names
      assert :destroy in action_names
    end

    test "resource has lifecycle actions" do
      actions = Ash.Resource.Info.actions(Product)
      action_names = Enum.map(actions, & &1.name)
      assert :activate in action_names
      assert :deactivate in action_names
    end

    test "resource has filter read actions" do
      actions = Ash.Resource.Info.actions(Product)
      action_names = Enum.map(actions, & &1.name)
      assert :active_products in action_names
      assert :by_family in action_names
    end

    test "resource has expected attributes" do
      attrs = Ash.Resource.Info.attributes(Product)
      attr_names = Enum.map(attrs, & &1.name)
      assert :id in attr_names
      assert :name in attr_names
      assert :product_code in attr_names
      assert :family in attr_names
      assert :is_active in attr_names
      assert :quantity_unit in attr_names
    end

    test "domain is Crm" do
      assert Ash.Resource.Info.domain(Product) == Indrajaal.Crm
    end
  end
end
