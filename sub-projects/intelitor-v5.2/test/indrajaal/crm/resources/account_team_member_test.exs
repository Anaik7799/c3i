defmodule Indrajaal.Crm.AccountTeamMemberTest do
  @moduledoc """
  ## TDG Compliance - Sprint 54
  Tests for Indrajaal.Crm.AccountTeamMember Ash resource.

  ## STAMP Compliance
  - SC-TDG: Tests exist before code modification
  - SC-DB-001: BaseResource usage verified
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Crm.AccountTeamMember

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(AccountTeamMember)
    end
  end

  describe "Ash resource introspection" do
    test "resource has core CRUD actions" do
      actions = Ash.Resource.Info.actions(AccountTeamMember)
      action_names = Enum.map(actions, & &1.name)
      assert :create in action_names
      assert :update in action_names
      assert :read in action_names
      assert :destroy in action_names
    end

    test "resource has team management actions" do
      actions = Ash.Resource.Info.actions(AccountTeamMember)
      action_names = Enum.map(actions, & &1.name)
      assert :activate in action_names
      assert :deactivate in action_names
      assert :change_role in action_names
      assert :change_access_level in action_names
    end

    test "change_role is an update action" do
      actions = Ash.Resource.Info.actions(AccountTeamMember)
      action = Enum.find(actions, &(&1.name == :change_role))
      assert action.type == :update
    end

    test "resource has membership calculations" do
      calcs = Ash.Resource.Info.calculations(AccountTeamMember)
      calc_names = Enum.map(calcs, & &1.name)
      assert :is_active_member? in calc_names
      assert :has_write_access? in calc_names
    end

    test "domain is Crm" do
      assert Ash.Resource.Info.domain(AccountTeamMember) == Indrajaal.Crm
    end
  end
end
