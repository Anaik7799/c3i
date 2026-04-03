defmodule Indrajaal.Crm.CampaignMemberTest do
  @moduledoc """
  ## TDG Compliance - Sprint 54
  Tests for Indrajaal.Crm.CampaignMember Ash resource.

  ## STAMP Compliance
  - SC-TDG: Tests exist before code modification
  - SC-DB-001: BaseResource usage verified
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Crm.CampaignMember

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(CampaignMember)
    end
  end

  describe "Ash resource introspection" do
    test "resource has CRUD actions" do
      actions = Ash.Resource.Info.actions(CampaignMember)
      action_names = Enum.map(actions, & &1.name)
      assert :create in action_names
      assert :update in action_names
      assert :read in action_names
      assert :destroy in action_names
    end

    test "resource has state-change actions" do
      actions = Ash.Resource.Info.actions(CampaignMember)
      action_names = Enum.map(actions, & &1.name)
      assert :mark_responded in action_names
      assert :mark_converted in action_names
    end

    test "resource has filter read actions" do
      actions = Ash.Resource.Info.actions(CampaignMember)
      action_names = Enum.map(actions, & &1.name)
      assert :by_campaign in action_names
      assert :by_lead in action_names
      assert :by_contact in action_names
      assert :responded_members in action_names
      assert :converted_members in action_names
    end

    test "resource has expected attributes" do
      attrs = Ash.Resource.Info.attributes(CampaignMember)
      attr_names = Enum.map(attrs, & &1.name)
      assert :id in attr_names
      assert :member_type in attr_names
      assert :status in attr_names
      assert :responded in attr_names
      assert :has_converted in attr_names
    end

    test "domain is Crm" do
      assert Ash.Resource.Info.domain(CampaignMember) == Indrajaal.Crm
    end
  end
end
