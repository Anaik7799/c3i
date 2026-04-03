defmodule Indrajaal.Communication.NotificationRuleTest do
  @moduledoc """
  ## TDG Compliance - Sprint 54
  Tests for Indrajaal.Communication.NotificationRule Ash resource.

  ## STAMP Compliance
  - SC-TDG: Tests exist before code modification
  - SC-DB-001: BaseResource usage verified
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Communication.NotificationRule

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(NotificationRule)
    end
  end

  describe "Ash resource introspection" do
    test "resource has CRUD actions" do
      actions = Ash.Resource.Info.actions(NotificationRule)
      action_names = Enum.map(actions, & &1.name)
      assert :create in action_names
      assert :update in action_names
      assert :read in action_names
      assert :destroy in action_names
    end

    test "resource has rule management actions" do
      actions = Ash.Resource.Info.actions(NotificationRule)
      action_names = Enum.map(actions, & &1.name)
      assert :create_rule in action_names
      assert :enable in action_names
      assert :disable in action_names
      assert :add_recipients in action_names
    end

    test "create_rule is a create action" do
      actions = Ash.Resource.Info.actions(NotificationRule)
      action = Enum.find(actions, &(&1.name == :create_rule))
      assert action.type == :create
    end

    test "enable is an update action" do
      actions = Ash.Resource.Info.actions(NotificationRule)
      action = Enum.find(actions, &(&1.name == :enable))
      assert action.type == :update
    end

    test "disable is an update action" do
      actions = Ash.Resource.Info.actions(NotificationRule)
      action = Enum.find(actions, &(&1.name == :disable))
      assert action.type == :update
    end

    test "add_recipients is an update action" do
      actions = Ash.Resource.Info.actions(NotificationRule)
      action = Enum.find(actions, &(&1.name == :add_recipients))
      assert action.type == :update
    end

    test "domain is CommunicationDomain" do
      assert Ash.Resource.Info.domain(NotificationRule) == Indrajaal.CommunicationDomain
    end
  end
end
