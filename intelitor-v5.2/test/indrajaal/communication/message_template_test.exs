defmodule Indrajaal.Communication.MessageTemplateTest do
  @moduledoc """
  ## TDG Compliance - Sprint 54
  Tests for Indrajaal.Communication.MessageTemplate Ash resource.

  ## STAMP Compliance
  - SC-TDG: Tests exist before code modification
  - SC-DB-001: BaseResource usage verified
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Communication.MessageTemplate

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(MessageTemplate)
    end
  end

  describe "Ash resource introspection" do
    test "resource has CRUD actions" do
      actions = Ash.Resource.Info.actions(MessageTemplate)
      action_names = Enum.map(actions, & &1.name)
      assert :create in action_names
      assert :update in action_names
      assert :read in action_names
      assert :destroy in action_names
    end

    test "resource has template lifecycle actions" do
      actions = Ash.Resource.Info.actions(MessageTemplate)
      action_names = Enum.map(actions, & &1.name)
      assert :create_template in action_names
      assert :activate in action_names
      assert :deactivate in action_names
    end

    test "create_template is a create action" do
      actions = Ash.Resource.Info.actions(MessageTemplate)
      action = Enum.find(actions, &(&1.name == :create_template))
      assert action.type == :create
    end

    test "activate is an update action" do
      actions = Ash.Resource.Info.actions(MessageTemplate)
      action = Enum.find(actions, &(&1.name == :activate))
      assert action.type == :update
    end

    test "deactivate is an update action" do
      actions = Ash.Resource.Info.actions(MessageTemplate)
      action = Enum.find(actions, &(&1.name == :deactivate))
      assert action.type == :update
    end

    test "domain is CommunicationDomain" do
      assert Ash.Resource.Info.domain(MessageTemplate) == Indrajaal.CommunicationDomain
    end
  end
end
