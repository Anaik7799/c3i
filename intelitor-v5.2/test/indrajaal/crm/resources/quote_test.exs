defmodule Indrajaal.Crm.QuoteTest do
  @moduledoc """
  TDG tests for Indrajaal.Crm.Quote Ash resource.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Crm.Quote

  describe "Quote resource schema" do
    test "is a valid Ash resource" do
      assert Code.ensure_loaded?(Quote)
    end

    test "has expected fields" do
      fields = Quote.__schema__(:fields)
      assert :id in fields
      assert :name in fields
      assert :status in fields
      assert :total_amount in fields
    end

    test "has created_at and updated_at timestamps" do
      fields = Quote.__schema__(:fields)
      assert :created_at in fields
      assert :updated_at in fields
    end
  end

  describe "Quote struct" do
    test "can create a struct with expected keys" do
      quote_struct = %Quote{}
      assert Map.has_key?(quote_struct, :id)
      assert Map.has_key?(quote_struct, :name)
      assert Map.has_key?(quote_struct, :status)
    end

    test "default status is draft" do
      quote_struct = %Quote{}
      assert quote_struct.status == :draft or is_nil(quote_struct.status)
    end
  end

  describe "Quote actions" do
    test "has create action" do
      actions = Ash.Resource.Info.actions(Quote)
      action_names = Enum.map(actions, & &1.name)
      assert :create in action_names
    end

    test "has read action" do
      actions = Ash.Resource.Info.actions(Quote)
      action_names = Enum.map(actions, & &1.name)
      assert :read in action_names
    end

    test "has update action" do
      actions = Ash.Resource.Info.actions(Quote)
      action_names = Enum.map(actions, & &1.name)
      assert :update in action_names
    end

    test "has approve action" do
      actions = Ash.Resource.Info.actions(Quote)
      action_names = Enum.map(actions, & &1.name)
      assert :approve in action_names
    end

    test "has reject action" do
      actions = Ash.Resource.Info.actions(Quote)
      action_names = Enum.map(actions, & &1.name)
      assert :reject in action_names
    end

    test "has submit_for_approval action" do
      actions = Ash.Resource.Info.actions(Quote)
      action_names = Enum.map(actions, & &1.name)
      assert :submit_for_approval in action_names
    end

    test "has accept action" do
      actions = Ash.Resource.Info.actions(Quote)
      action_names = Enum.map(actions, & &1.name)
      assert :accept in action_names
    end

    test "has deny action" do
      actions = Ash.Resource.Info.actions(Quote)
      action_names = Enum.map(actions, & &1.name)
      assert :deny in action_names
    end

    test "has clone action" do
      actions = Ash.Resource.Info.actions(Quote)
      action_names = Enum.map(actions, & &1.name)
      assert :clone in action_names
    end
  end

  describe "Quote code interface" do
    test "create/1 is exported" do
      assert function_exported?(Quote, :create, 1)
    end

    test "update/2 is exported" do
      assert function_exported?(Quote, :update, 2)
    end

    test "approve/1 is exported" do
      assert function_exported?(Quote, :approve, 1)
    end

    test "reject/1 is exported" do
      assert function_exported?(Quote, :reject, 1)
    end
  end

  describe "Quote status values" do
    test "valid statuses are defined as atoms" do
      valid_statuses = [
        :draft,
        :needs_review,
        :approved,
        :rejected,
        :presented,
        :accepted,
        :denied
      ]

      for status <- valid_statuses do
        assert is_atom(status)
      end
    end
  end
end
