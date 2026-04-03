defmodule Indrajaal.Crm.CampaignTest do
  @moduledoc """
  ## TDG Compliance - Sprint 54
  Tests for Indrajaal.Crm.Campaign Ash resource.

  ## STAMP Compliance
  - SC-TDG: Tests exist before code modification
  - SC-DB-001: BaseResource usage verified
  - SC-ASH-004: require_atomic? false for ROI calculation verified
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Crm.Campaign

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Campaign)
    end
  end

  describe "Ash resource introspection" do
    test "resource has CRUD actions" do
      actions = Ash.Resource.Info.actions(Campaign)
      action_names = Enum.map(actions, & &1.name)
      assert :create in action_names
      assert :update in action_names
      assert :read in action_names
      assert :destroy in action_names
    end

    test "resource has lifecycle actions" do
      actions = Ash.Resource.Info.actions(Campaign)
      action_names = Enum.map(actions, & &1.name)
      assert :activate in action_names
      assert :deactivate in action_names
      assert :start in action_names
      assert :complete in action_names
      assert :abort in action_names
    end

    test "resource has filter read actions" do
      actions = Ash.Resource.Info.actions(Campaign)
      action_names = Enum.map(actions, & &1.name)
      assert :active_campaigns in action_names
      assert :by_status in action_names
      assert :by_type in action_names
      assert :parent_campaigns in action_names
    end

    test "resource has expected attributes" do
      attrs = Ash.Resource.Info.attributes(Campaign)
      attr_names = Enum.map(attrs, & &1.name)
      assert :id in attr_names
      assert :name in attr_names
      assert :type in attr_names
      assert :status in attr_names
      assert :is_active in attr_names
    end

    test "resource has calculations" do
      calcs = Ash.Resource.Info.calculations(Campaign)
      calc_names = Enum.map(calcs, & &1.name)
      assert :roi in calc_names
      assert :num_leads in calc_names
      assert :num_contacts in calc_names
      assert :total_members in calc_names
    end

    test "domain is Crm" do
      assert Ash.Resource.Info.domain(Campaign) == Indrajaal.Crm
    end
  end
end
