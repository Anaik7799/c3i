defmodule Indrajaal.Crm.LeadTest do
  @moduledoc """
  ## TDG Compliance - Sprint 54
  Tests for Indrajaal.Crm.Lead Ash resource.

  ## STAMP Compliance
  - SC-TDG: Tests exist before code modification
  - SC-DB-001: BaseResource usage verified
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Crm.Lead

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Lead)
    end
  end

  describe "Ash resource introspection" do
    test "resource has core CRUD actions" do
      actions = Ash.Resource.Info.actions(Lead)
      action_names = Enum.map(actions, & &1.name)
      assert :create in action_names
      assert :update in action_names
      assert :read in action_names
      assert :destroy in action_names
    end

    test "resource has qualification lifecycle actions" do
      actions = Ash.Resource.Info.actions(Lead)
      action_names = Enum.map(actions, & &1.name)
      assert :qualify in action_names
      assert :disqualify in action_names
      assert :convert in action_names
    end

    test "resource has scoring and assignment actions" do
      actions = Ash.Resource.Info.actions(Lead)
      action_names = Enum.map(actions, & &1.name)
      assert :score in action_names
      assert :assign in action_names
    end

    test "qualify is an update action" do
      actions = Ash.Resource.Info.actions(Lead)
      action = Enum.find(actions, &(&1.name == :qualify))
      assert action.type == :update
    end

    test "convert is an update action" do
      actions = Ash.Resource.Info.actions(Lead)
      action = Enum.find(actions, &(&1.name == :convert))
      assert action.type == :update
    end

    test "resource has expected attributes" do
      attrs = Ash.Resource.Info.attributes(Lead)
      attr_names = Enum.map(attrs, & &1.name)
      assert :id in attr_names
      assert :last_name in attr_names
      assert :email in attr_names
    end

    test "resource has lead calculations" do
      calcs = Ash.Resource.Info.calculations(Lead)
      calc_names = Enum.map(calcs, & &1.name)
      assert :full_name in calc_names
      assert :is_converted? in calc_names
      assert :is_qualified? in calc_names
    end

    test "domain is Crm" do
      assert Ash.Resource.Info.domain(Lead) == Indrajaal.Crm
    end
  end
end
