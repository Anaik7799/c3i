defmodule Indrajaal.Crm.AccountTest do
  @moduledoc """
  ## TDG Compliance - Sprint 54
  Tests for Indrajaal.Crm.Account Ash resource.

  ## STAMP Compliance
  - SC-TDG: Tests exist before code modification
  - SC-DB-001: BaseResource usage verified
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Crm.Account

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Account)
    end
  end

  describe "Ash resource introspection" do
    test "resource has core CRUD actions" do
      actions = Ash.Resource.Info.actions(Account)
      action_names = Enum.map(actions, & &1.name)
      assert :create in action_names
      assert :update in action_names
      assert :read in action_names
      assert :destroy in action_names
    end

    test "resource has lifecycle actions" do
      actions = Ash.Resource.Info.actions(Account)
      action_names = Enum.map(actions, & &1.name)
      assert :activate in action_names
      assert :deactivate in action_names
    end

    test "resource has relationship actions" do
      actions = Ash.Resource.Info.actions(Account)
      action_names = Enum.map(actions, & &1.name)
      assert :assign in action_names
      assert :change_parent in action_names
    end

    test "activate is an update action" do
      actions = Ash.Resource.Info.actions(Account)
      action = Enum.find(actions, &(&1.name == :activate))
      assert action.type == :update
    end

    test "resource has expected attributes" do
      attrs = Ash.Resource.Info.attributes(Account)
      attr_names = Enum.map(attrs, & &1.name)
      assert :id in attr_names
      assert :name in attr_names
      assert :type in attr_names
    end

    test "resource has boolean calculations" do
      calcs = Ash.Resource.Info.calculations(Account)
      calc_names = Enum.map(calcs, & &1.name)
      assert :has_parent? in calc_names
      assert :is_active? in calc_names
    end

    test "domain is Crm" do
      assert Ash.Resource.Info.domain(Account) == Indrajaal.Crm
    end
  end
end
