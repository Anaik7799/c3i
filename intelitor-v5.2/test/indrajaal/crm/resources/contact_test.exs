defmodule Indrajaal.Crm.ContactTest do
  @moduledoc """
  ## TDG Compliance - Sprint 54
  Tests for Indrajaal.Crm.Contact Ash resource.

  ## STAMP Compliance
  - SC-TDG: Tests exist before code modification
  - SC-DB-001: BaseResource usage verified
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Crm.Contact

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Contact)
    end

    test "module has code_interface functions" do
      fns = Contact.__info__(:functions)
      assert Keyword.has_key?(fns, :create)
      assert Keyword.has_key?(fns, :update)
      assert Keyword.has_key?(fns, :assign)
      assert Keyword.has_key?(fns, :opt_out_email)
      assert Keyword.has_key?(fns, :opt_in_email)
    end
  end

  describe "Ash resource introspection" do
    test "resource has CRUD actions" do
      actions = Ash.Resource.Info.actions(Contact)
      action_names = Enum.map(actions, & &1.name)
      assert :create in action_names
      assert :update in action_names
      assert :read in action_names
      assert :destroy in action_names
    end

    test "resource has contact-specific actions" do
      actions = Ash.Resource.Info.actions(Contact)
      action_names = Enum.map(actions, & &1.name)
      assert :assign in action_names
      assert :change_account in action_names
      assert :opt_out_email in action_names
      assert :opt_in_email in action_names
      assert :mark_deceased in action_names
    end

    test "resource has personal info attributes" do
      attrs = Ash.Resource.Info.attributes(Contact)
      attr_names = Enum.map(attrs, & &1.name)
      assert :id in attr_names
      assert :first_name in attr_names
      assert :last_name in attr_names
      assert :email in attr_names
      assert :phone in attr_names
    end

    test "resource has contact preference attributes" do
      attrs = Ash.Resource.Info.attributes(Contact)
      attr_names = Enum.map(attrs, & &1.name)
      assert :email_opt_out in attr_names
      assert :do_not_call in attr_names
      assert :status in attr_names
    end

    test "resource has calculations" do
      calcs = Ash.Resource.Info.calculations(Contact)
      calc_names = Enum.map(calcs, & &1.name)
      assert :full_name in calc_names
      assert :is_active? in calc_names
      assert :can_email? in calc_names
      assert :can_call? in calc_names
    end

    test "domain is Crm" do
      assert Ash.Resource.Info.domain(Contact) == Indrajaal.Crm
    end
  end
end
