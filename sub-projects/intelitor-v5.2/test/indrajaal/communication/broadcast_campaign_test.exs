defmodule Indrajaal.Communication.BroadcastCampaignTest do
  @moduledoc """
  ## TDG Compliance - Sprint 54
  Tests for Indrajaal.Communication.BroadcastCampaign Ash resource.

  ## STAMP Compliance
  - SC-TDG: Tests exist before code modification
  - SC-DB-001: BaseResource usage verified
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Communication.BroadcastCampaign

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(BroadcastCampaign)
    end
  end

  describe "Ash resource introspection" do
    test "resource has CRUD actions" do
      actions = Ash.Resource.Info.actions(BroadcastCampaign)
      action_names = Enum.map(actions, & &1.name)
      assert :create in action_names
      assert :update in action_names
      assert :read in action_names
      assert :destroy in action_names
    end

    test "resource has campaign lifecycle actions" do
      actions = Ash.Resource.Info.actions(BroadcastCampaign)
      action_names = Enum.map(actions, & &1.name)
      assert :create_campaign in action_names
      assert :schedule_campaign in action_names
      assert :start_campaign in action_names
      assert :complete_campaign in action_names
      assert :cancel_campaign in action_names
      assert :update_progress in action_names
    end

    test "create_campaign is a create action" do
      actions = Ash.Resource.Info.actions(BroadcastCampaign)
      action = Enum.find(actions, &(&1.name == :create_campaign))
      assert action.type == :create
    end

    test "schedule_campaign is an update action" do
      actions = Ash.Resource.Info.actions(BroadcastCampaign)
      action = Enum.find(actions, &(&1.name == :schedule_campaign))
      assert action.type == :update
    end

    test "cancel_campaign is an update action" do
      actions = Ash.Resource.Info.actions(BroadcastCampaign)
      action = Enum.find(actions, &(&1.name == :cancel_campaign))
      assert action.type == :update
    end

    test "resource has expected attributes" do
      attrs = Ash.Resource.Info.attributes(BroadcastCampaign)
      attr_names = Enum.map(attrs, & &1.name)
      assert :id in attr_names
      assert :name in attr_names
      assert :campaign_type in attr_names
      assert :status in attr_names
      assert :target_audience in attr_names
      assert :total_recipients in attr_names
      assert :messages_sent in attr_names
    end

    test "resource has is_active and completion_percentage calculations" do
      calcs = Ash.Resource.Info.calculations(BroadcastCampaign)
      calc_names = Enum.map(calcs, & &1.name)
      assert :is_active in calc_names
      assert :completion_percentage in calc_names
    end

    test "domain is CommunicationDomain" do
      assert Ash.Resource.Info.domain(BroadcastCampaign) == Indrajaal.CommunicationDomain
    end
  end
end
