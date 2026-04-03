defmodule Indrajaal.AccessControl.AccessRuleTest do
  @moduledoc """
  TDG tests for Indrajaal.AccessControl.AccessRule Ecto schema.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.AccessControl.AccessRule

  describe "schema definition" do
    test "module is loadable" do
      assert Code.ensure_loaded?(AccessRule)
    end

    test "has expected schema fields" do
      fields = AccessRule.__schema__(:fields)
      assert :name in fields
      assert :active in fields
      assert :tenant_id in fields
      assert :rule_type in fields
    end

    test "has description field" do
      fields = AccessRule.__schema__(:fields)
      assert :description in fields
    end

    test "has priority field" do
      fields = AccessRule.__schema__(:fields)
      assert :priority in fields
    end

    test "has metadata field" do
      fields = AccessRule.__schema__(:fields)
      assert :metadata in fields
    end
  end

  describe "changeset/2" do
    test "valid params create valid changeset" do
      attrs = %{name: "Allow All", rule_type: "allow"}
      changeset = AccessRule.changeset(%AccessRule{}, attrs)
      assert changeset.valid?
    end

    test "missing name makes changeset invalid" do
      attrs = %{rule_type: "allow"}
      changeset = AccessRule.changeset(%AccessRule{}, attrs)
      refute changeset.valid?
      assert :name in Keyword.keys(changeset.errors)
    end

    test "invalid rule_type makes changeset invalid" do
      attrs = %{name: "Test", rule_type: "invalid_type"}
      changeset = AccessRule.changeset(%AccessRule{}, attrs)
      refute changeset.valid?
    end

    test "allow rule type is valid" do
      attrs = %{name: "Allow Rule", rule_type: "allow"}
      changeset = AccessRule.changeset(%AccessRule{}, attrs)
      assert changeset.valid?
    end

    test "deny rule type is valid" do
      attrs = %{name: "Deny Rule", rule_type: "deny"}
      changeset = AccessRule.changeset(%AccessRule{}, attrs)
      assert changeset.valid?
    end

    test "schedule rule type is valid" do
      attrs = %{name: "Schedule Rule", rule_type: "schedule"}
      changeset = AccessRule.changeset(%AccessRule{}, attrs)
      assert changeset.valid?
    end
  end
end
