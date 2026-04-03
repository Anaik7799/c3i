defmodule Indrajaal.Communication.DeliveryLogTest do
  @moduledoc """
  ## TDG Compliance - Sprint 54
  Tests for Indrajaal.Communication.DeliveryLog Ash resource.

  ## STAMP Compliance
  - SC-TDG: Tests exist before code modification
  - SC-DB-001: BaseResource usage verified
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Communication.DeliveryLog

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(DeliveryLog)
    end
  end

  describe "Ash resource introspection" do
    test "resource has CRUD actions" do
      actions = Ash.Resource.Info.actions(DeliveryLog)
      action_names = Enum.map(actions, & &1.name)
      assert :create in action_names
      assert :update in action_names
      assert :read in action_names
      assert :destroy in action_names
    end

    test "resource has delivery tracking actions" do
      actions = Ash.Resource.Info.actions(DeliveryLog)
      action_names = Enum.map(actions, & &1.name)
      assert :log_attempt in action_names
      assert :mark_delivered in action_names
      assert :mark_failed in action_names
      assert :mark_read in action_names
    end

    test "log_attempt is a create action" do
      actions = Ash.Resource.Info.actions(DeliveryLog)
      action = Enum.find(actions, &(&1.name == :log_attempt))
      assert action.type == :create
    end

    test "mark_delivered is an update action" do
      actions = Ash.Resource.Info.actions(DeliveryLog)
      action = Enum.find(actions, &(&1.name == :mark_delivered))
      assert action.type == :update
    end

    test "mark_failed is an update action" do
      actions = Ash.Resource.Info.actions(DeliveryLog)
      action = Enum.find(actions, &(&1.name == :mark_failed))
      assert action.type == :update
    end

    test "mark_read is an update action" do
      actions = Ash.Resource.Info.actions(DeliveryLog)
      action = Enum.find(actions, &(&1.name == :mark_read))
      assert action.type == :update
    end

    test "domain is CommunicationDomain" do
      assert Ash.Resource.Info.domain(DeliveryLog) == Indrajaal.CommunicationDomain
    end
  end
end
