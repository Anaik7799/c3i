defmodule Indrajaal.Crm.QuoteLineItemTest do
  @moduledoc """
  TDG tests for Indrajaal.Crm.QuoteLineItem Ash resource.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Crm.QuoteLineItem

  describe "QuoteLineItem resource schema" do
    test "is a valid Ash resource" do
      assert Code.ensure_loaded?(QuoteLineItem)
    end

    test "has expected fields" do
      fields = QuoteLineItem.__schema__(:fields)
      assert :id in fields
      assert :quantity in fields
      assert :unit_price in fields
      assert :discount in fields
    end

    test "has created_at and updated_at timestamps" do
      fields = QuoteLineItem.__schema__(:fields)
      assert :created_at in fields
      assert :updated_at in fields
    end
  end

  describe "QuoteLineItem struct" do
    test "can create a struct with expected keys" do
      item = %QuoteLineItem{}
      assert Map.has_key?(item, :id)
      assert Map.has_key?(item, :quantity)
      assert Map.has_key?(item, :unit_price)
      assert Map.has_key?(item, :discount)
    end
  end

  describe "QuoteLineItem actions" do
    test "has create action" do
      actions = Ash.Resource.Info.actions(QuoteLineItem)
      action_names = Enum.map(actions, & &1.name)
      assert :create in action_names
    end

    test "has read action" do
      actions = Ash.Resource.Info.actions(QuoteLineItem)
      action_names = Enum.map(actions, & &1.name)
      assert :read in action_names
    end

    test "has update action" do
      actions = Ash.Resource.Info.actions(QuoteLineItem)
      action_names = Enum.map(actions, & &1.name)
      assert :update in action_names
    end

    test "has by_quote read action" do
      actions = Ash.Resource.Info.actions(QuoteLineItem)
      action_names = Enum.map(actions, & &1.name)
      assert :by_quote in action_names
    end
  end

  describe "QuoteLineItem code interface" do
    test "create/1 is exported" do
      assert function_exported?(QuoteLineItem, :create, 1)
    end

    test "update/2 is exported" do
      assert function_exported?(QuoteLineItem, :update, 2)
    end

    test "by_quote/1 is exported" do
      assert function_exported?(QuoteLineItem, :by_quote, 1)
    end
  end

  describe "QuoteLineItem calculations" do
    test "has total_price calculation defined" do
      calcs = Ash.Resource.Info.calculations(QuoteLineItem)
      calc_names = Enum.map(calcs, & &1.name)
      assert :total_price in calc_names
    end
  end
end
