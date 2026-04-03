defmodule Indrajaal.Compliance.PolicyTest do
  @moduledoc """
  Tests for Indrajaal.Compliance.Policy Ecto schema module.
  STAMP: SC-GDE-001, SC-DB-001, SC-TDG-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Compliance.Policy

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(Policy)
    end

    test "changeset/2 is exported" do
      assert function_exported?(Policy, :changeset, 2)
    end
  end

  describe "changeset/2" do
    test "returns an Ecto.Changeset" do
      policy = %Policy{}
      result = Policy.changeset(policy, %{})
      assert is_struct(result, Ecto.Changeset)
    end

    test "changeset with valid attrs returns changeset struct" do
      policy = %Policy{}
      attrs = %{name: "Test Policy", description: "A test policy"}
      result = Policy.changeset(policy, attrs)
      assert is_struct(result, Ecto.Changeset)
    end

    test "changeset with empty attrs is still a changeset" do
      policy = %Policy{}
      result = Policy.changeset(policy, %{})
      assert %Ecto.Changeset{} = result
    end
  end

  describe "struct" do
    test "can create a Policy struct" do
      policy = %Policy{}
      assert is_struct(policy, Policy)
    end
  end
end
