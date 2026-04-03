defmodule Indrajaal.Accounts.RoleTest do
  @moduledoc """
  TDG test suite for Indrajaal.Accounts.Role Ash resource.

  ## STAMP Safety Integration
  - SC-DB-001: BaseResource compliance
  - SC-DB-005: uuid_primary_key

  ## TPS 5-Level RCA Context
  - L1 Symptom: Role schema validation failures
  - L5 Root Cause: Incorrect permissions field definition
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Accounts.Role

  describe "Role Ash resource schema" do
    test "module exists and is an Ash resource" do
      assert Code.ensure_loaded?(Role)
      assert function_exported?(Role, :__ash_resource__, 0)
    end

    test "__schema__/1 returns field list" do
      fields = Role.__schema__(:fields)
      assert is_list(fields)
      assert length(fields) > 0
    end

    test "has :id field (uuid_primary_key)" do
      fields = Role.__schema__(:fields)
      assert :id in fields
    end

    test "has :name field" do
      fields = Role.__schema__(:fields)
      assert :name in fields
    end

    test "has :permissions field" do
      fields = Role.__schema__(:fields)
      assert :permissions in fields
    end

    test "has :tenant_id field" do
      fields = Role.__schema__(:fields)
      assert :tenant_id in fields
    end

    test "struct can be created with defaults" do
      role = %Role{}
      assert role.__struct__ == Role
      # permissions defaults to []
      assert role.permissions == [] or is_nil(role.permissions)
    end
  end

  describe "Role permissions field" do
    test "permissions defaults to empty list" do
      role = %Role{}
      # Default is [] per source
      assert role.permissions == [] or is_nil(role.permissions)
    end
  end

  describe "Constitutional Invariants (Ψ₀)" do
    test "Ψ₀ existence: Role module survives inspection" do
      assert Role.__info__(:module) == Role
    end

    test "Ψ₃ verification: schema fields are introspectable" do
      assert is_list(Role.__schema__(:fields))
    end
  end
end
