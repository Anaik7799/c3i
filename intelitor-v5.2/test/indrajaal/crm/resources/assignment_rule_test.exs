defmodule Indrajaal.Crm.AssignmentRuleTest do
  @moduledoc """
  ## TDG Compliance - Sprint 54
  Tests for Indrajaal.Crm.AssignmentRule Ash resource.
  Covers module loading, Ash introspection, and pure `matches?/2` logic.

  ## STAMP Compliance
  - SC-TDG: Tests exist before code modification
  - SC-AUTO-001: Max 100 rules per object type (enforcement in DB constraints)
  - SC-AUTO-003: Fallback owner required
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Crm.AssignmentRule

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(AssignmentRule)
    end

    test "module exports expected functions" do
      fns = AssignmentRule.__info__(:functions)
      assert Keyword.has_key?(fns, :matches?)
      assert Keyword.has_key?(fns, :active_by_object)
    end
  end

  describe "Ash resource introspection" do
    test "resource has CRUD actions" do
      actions = Ash.Resource.Info.actions(AssignmentRule)
      action_names = Enum.map(actions, & &1.name)
      assert :create in action_names
      assert :update in action_names
      assert :read in action_names
      assert :destroy in action_names
    end

    test "resource has lifecycle actions" do
      actions = Ash.Resource.Info.actions(AssignmentRule)
      action_names = Enum.map(actions, & &1.name)
      assert :activate in action_names
      assert :deactivate in action_names
    end

    test "resource has filter actions" do
      actions = Ash.Resource.Info.actions(AssignmentRule)
      action_names = Enum.map(actions, & &1.name)
      assert :by_object_type in action_names
      assert :active in action_names
      assert :active_by_type in action_names
    end

    test "resource has expected attributes" do
      attrs = Ash.Resource.Info.attributes(AssignmentRule)
      attr_names = Enum.map(attrs, & &1.name)
      assert :id in attr_names
      assert :name in attr_names
      assert :object_type in attr_names
      assert :criteria in attr_names
      assert :active in attr_names
    end

    test "domain is Crm" do
      assert Ash.Resource.Info.domain(AssignmentRule) == Indrajaal.Crm
    end
  end

  describe "matches?/2 pure logic" do
    test "matches when all criteria fields match" do
      rule = %{criteria: %{status: :new, source: :web}}
      record = %{status: :new, source: :web, other: "ignored"}
      assert AssignmentRule.matches?(rule, record)
    end

    test "does not match when one field differs" do
      rule = %{criteria: %{status: :new}}
      record = %{status: :qualified}
      refute AssignmentRule.matches?(rule, record)
    end

    test "matches when criteria is empty (catch-all rule)" do
      rule = %{criteria: %{}}
      record = %{status: :new, anything: true}
      assert AssignmentRule.matches?(rule, record)
    end

    test "returns false for non-map rule" do
      refute AssignmentRule.matches?(nil, %{status: :new})
    end

    test "returns false for non-map record" do
      rule = %{criteria: %{status: :new}}
      refute AssignmentRule.matches?(rule, nil)
    end

    test "handles string field keys in criteria" do
      rule = %{criteria: %{"status" => :new}}
      # String.to_existing_atom("status") should work for known atoms
      record = %{status: :new}
      assert AssignmentRule.matches?(rule, record)
    end

    test "returns false for unknown string field keys" do
      rule = %{criteria: %{"nonexistent_field_xyz_abc" => :value}}
      record = %{status: :new}
      refute AssignmentRule.matches?(rule, record)
    end

    test "returns false when criteria is nil" do
      rule = %{criteria: nil}
      record = %{status: :new}
      refute AssignmentRule.matches?(rule, record)
    end
  end
end
