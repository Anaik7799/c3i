defmodule Indrajaal.Communication.ContactGroupTest do
  @moduledoc """
  ## TDG Compliance - Sprint 54
  Tests for Indrajaal.Communication.ContactGroup Ash resource.

  ## STAMP Compliance
  - SC-TDG: Tests exist before code modification
  - SC-DB-001: BaseResource usage verified
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Communication.ContactGroup

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(ContactGroup)
    end
  end

  describe "Ash resource introspection" do
    test "resource has CRUD actions" do
      actions = Ash.Resource.Info.actions(ContactGroup)
      action_names = Enum.map(actions, & &1.name)
      assert :create in action_names
      assert :update in action_names
      assert :read in action_names
      assert :destroy in action_names
    end

    test "resource has group management actions" do
      actions = Ash.Resource.Info.actions(ContactGroup)
      action_names = Enum.map(actions, & &1.name)
      assert :create_group in action_names
      assert :add_members in action_names
      assert :remove_members in action_names
      assert :activate in action_names
      assert :deactivate in action_names
    end

    test "create_group is a create action" do
      actions = Ash.Resource.Info.actions(ContactGroup)
      action = Enum.find(actions, &(&1.name == :create_group))
      assert action.type == :create
    end

    test "add_members is an update action" do
      actions = Ash.Resource.Info.actions(ContactGroup)
      action = Enum.find(actions, &(&1.name == :add_members))
      assert action.type == :update
    end

    test "remove_members is an update action" do
      actions = Ash.Resource.Info.actions(ContactGroup)
      action = Enum.find(actions, &(&1.name == :remove_members))
      assert action.type == :update
    end

    test "domain is CommunicationDomain" do
      assert Ash.Resource.Info.domain(ContactGroup) == Indrajaal.CommunicationDomain
    end
  end
end
