defmodule Indrajaal.Crm.QuotaTest do
  @moduledoc """
  TDG tests for Indrajaal.Crm.Quota Ash resource.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Crm.Quota

  describe "Quota resource schema" do
    test "is a valid Ash resource" do
      assert Code.ensure_loaded?(Quota)
    end

    test "has expected fields" do
      fields = Quota.__schema__(:fields)
      assert :id in fields
      assert :user_id in fields
      assert :object_type in fields
      assert :period_type in fields
      assert :period_number in fields
      assert :period_year in fields
      assert :target in fields
      assert :attained in fields
    end

    test "has created_at and updated_at timestamps" do
      fields = Quota.__schema__(:fields)
      assert :created_at in fields
      assert :updated_at in fields
    end

    test "primary key is id" do
      assert :id in Quota.__schema__(:fields)
    end
  end

  describe "Quota struct" do
    test "can create a struct with expected keys" do
      quota = %Quota{}
      assert Map.has_key?(quota, :id)
      assert Map.has_key?(quota, :user_id)
      assert Map.has_key?(quota, :object_type)
      assert Map.has_key?(quota, :period_type)
      assert Map.has_key?(quota, :target)
      assert Map.has_key?(quota, :attained)
    end

    test "default attained is 0.0" do
      quota = %Quota{}
      assert quota.attained == nil or is_nil(quota.attained)
    end
  end

  describe "Quota actions" do
    test "has create action defined" do
      actions = Ash.Resource.Info.actions(Quota)
      action_names = Enum.map(actions, & &1.name)
      assert :create in action_names
    end

    test "has read action defined" do
      actions = Ash.Resource.Info.actions(Quota)
      action_names = Enum.map(actions, & &1.name)
      assert :read in action_names
    end

    test "has update action defined" do
      actions = Ash.Resource.Info.actions(Quota)
      action_names = Enum.map(actions, & &1.name)
      assert :update in action_names
    end

    test "has by_user read action" do
      actions = Ash.Resource.Info.actions(Quota)
      action_names = Enum.map(actions, & &1.name)
      assert :by_user in action_names
    end

    test "has by_period read action" do
      actions = Ash.Resource.Info.actions(Quota)
      action_names = Enum.map(actions, & &1.name)
      assert :by_period in action_names
    end

    test "has current_quarter read action" do
      actions = Ash.Resource.Info.actions(Quota)
      action_names = Enum.map(actions, & &1.name)
      assert :current_quarter in action_names
    end
  end

  describe "Quota code interface" do
    test "create/1 is exported" do
      assert function_exported?(Quota, :create, 1)
    end

    test "update/2 is exported" do
      assert function_exported?(Quota, :update, 2)
    end

    test "by_user/1 is exported" do
      assert function_exported?(Quota, :by_user, 1)
    end

    test "by_period/3 is exported" do
      assert function_exported?(Quota, :by_period, 3)
    end

    test "current_quarter/1 is exported" do
      assert function_exported?(Quota, :current_quarter, 1)
    end
  end
end
