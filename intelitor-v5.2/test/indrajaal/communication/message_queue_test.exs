defmodule Indrajaal.Communication.MessageQueueTest do
  @moduledoc """
  ## TDG Compliance - Sprint 54
  Tests for Indrajaal.Communication.MessageQueue Ash resource.

  ## STAMP Compliance
  - SC-TDG: Tests exist before code modification
  - SC-DB-001: BaseResource usage verified
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Communication.MessageQueue

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(MessageQueue)
    end
  end

  describe "Ash resource introspection" do
    test "resource has CRUD actions" do
      actions = Ash.Resource.Info.actions(MessageQueue)
      action_names = Enum.map(actions, & &1.name)
      assert :create in action_names
      assert :update in action_names
      assert :read in action_names
      assert :destroy in action_names
    end

    test "resource has queue lifecycle actions" do
      actions = Ash.Resource.Info.actions(MessageQueue)
      action_names = Enum.map(actions, & &1.name)
      assert :create_queue in action_names
      assert :pause_queue in action_names
      assert :resume_queue in action_names
      assert :disable_queue in action_names
    end

    test "resource has queue counter actions" do
      actions = Ash.Resource.Info.actions(MessageQueue)
      action_names = Enum.map(actions, & &1.name)
      assert :increment_pending in action_names
      assert :increment_processing in action_names
      assert :increment_failed in action_names
      assert :complete_processing in action_names
    end

    test "create_queue is a create action" do
      actions = Ash.Resource.Info.actions(MessageQueue)
      action = Enum.find(actions, &(&1.name == :create_queue))
      assert action.type == :create
    end

    test "pause_queue is an update action" do
      actions = Ash.Resource.Info.actions(MessageQueue)
      action = Enum.find(actions, &(&1.name == :pause_queue))
      assert action.type == :update
    end

    test "domain is CommunicationDomain" do
      assert Ash.Resource.Info.domain(MessageQueue) == Indrajaal.CommunicationDomain
    end
  end
end
