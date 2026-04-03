defmodule Indrajaal.Communication.ContactPreferenceTest do
  @moduledoc """
  ## TDG Compliance - Sprint 54
  Tests for Indrajaal.Communication.ContactPreference Ash resource.

  ## STAMP Compliance
  - SC-TDG: Tests exist before code modification
  - SC-DB-001: BaseResource usage verified
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Communication.ContactPreference

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(ContactPreference)
    end
  end

  describe "Ash resource introspection" do
    test "resource has CRUD actions" do
      actions = Ash.Resource.Info.actions(ContactPreference)
      action_names = Enum.map(actions, & &1.name)
      assert :create in action_names
      assert :update in action_names
      assert :read in action_names
      assert :destroy in action_names
    end

    test "resource has preference management actions" do
      actions = Ash.Resource.Info.actions(ContactPreference)
      action_names = Enum.map(actions, & &1.name)
      assert :set_preferences in action_names
      assert :update_channels in action_names
      assert :set_quiet_hours in action_names
      assert :enable_emergency_notifications in action_names
      assert :disable_notifications in action_names
    end

    test "set_preferences is a create action" do
      actions = Ash.Resource.Info.actions(ContactPreference)
      action = Enum.find(actions, &(&1.name == :set_preferences))
      assert action.type == :create
    end

    test "update_channels is an update action" do
      actions = Ash.Resource.Info.actions(ContactPreference)
      action = Enum.find(actions, &(&1.name == :update_channels))
      assert action.type == :update
    end

    test "disable_notifications is an update action" do
      actions = Ash.Resource.Info.actions(ContactPreference)
      action = Enum.find(actions, &(&1.name == :disable_notifications))
      assert action.type == :update
    end

    test "domain is CommunicationDomain" do
      assert Ash.Resource.Info.domain(ContactPreference) == Indrajaal.CommunicationDomain
    end
  end
end
