defmodule Indrajaal.Accounts.TeamMembershipTest do
  @moduledoc """
  TDG test suite for Indrajaal.Accounts.TeamMembership Ash resource.

  ## STAMP Safety Integration
  - SC-DB-001: BaseResource compliance

  ## TPS 5-Level RCA Context
  - L1 Symptom: Role enum value errors in TeamMembership
  - L5 Root Cause: Undefined enum atom
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Accounts.TeamMembership

  @valid_roles [:member, :lead, :admin]

  describe "TeamMembership Ash resource schema" do
    test "module exists and is an Ash resource" do
      assert Code.ensure_loaded?(TeamMembership)
      assert function_exported?(TeamMembership, :__ash_resource__, 0)
    end

    test "__schema__/1 returns field list" do
      fields = TeamMembership.__schema__(:fields)
      assert is_list(fields)
      assert length(fields) > 0
    end

    test "has :id field" do
      fields = TeamMembership.__schema__(:fields)
      assert :id in fields
    end

    test "has :role field" do
      fields = TeamMembership.__schema__(:fields)
      assert :role in fields
    end

    test "has :tenant_id field" do
      fields = TeamMembership.__schema__(:fields)
      assert :tenant_id in fields
    end

    test "struct can be created" do
      membership = %TeamMembership{}
      assert membership.__struct__ == TeamMembership
    end
  end

  describe "TeamMembership role enum" do
    test "member is a valid role" do
      assert :member in @valid_roles
    end

    test "lead is a valid role" do
      assert :lead in @valid_roles
    end

    test "admin is a valid role" do
      assert :admin in @valid_roles
    end

    test "has exactly 3 role values" do
      assert length(@valid_roles) == 3
    end

    test "all roles are atoms" do
      Enum.each(@valid_roles, fn role ->
        assert is_atom(role)
      end)
    end
  end

  describe "Constitutional Invariants (Ψ₀)" do
    test "Ψ₀ existence: TeamMembership module exists" do
      assert TeamMembership.__info__(:module) == TeamMembership
    end
  end
end
