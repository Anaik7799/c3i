defmodule Indrajaal.Accounts.PermissionTest do
  @moduledoc """
  TDG test suite for Indrajaal.Accounts.Permission Ash resource.

  ## STAMP Safety Integration
  - SC-DB-001: BaseResource compliance
  - SC-DB-005: uuid_primary_key

  ## TPS 5-Level RCA Context
  - L1 Symptom: Permission schema errors
  - L5 Root Cause: Missing required fields
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Accounts.Permission

  describe "Permission Ash resource schema" do
    test "module exists and is an Ash resource" do
      assert Code.ensure_loaded?(Permission)
      assert function_exported?(Permission, :__ash_resource__, 0)
    end

    test "__schema__/1 returns field list" do
      fields = Permission.__schema__(:fields)
      assert is_list(fields)
      assert length(fields) > 0
    end

    test "has :id field (uuid_primary_key)" do
      fields = Permission.__schema__(:fields)
      assert :id in fields
    end

    test "has :name field (required)" do
      fields = Permission.__schema__(:fields)
      assert :name in fields
    end

    test "has :resource field (required)" do
      fields = Permission.__schema__(:fields)
      assert :resource in fields
    end

    test "has :action field (required)" do
      fields = Permission.__schema__(:fields)
      assert :action in fields
    end

    test "has :tenant_id field" do
      fields = Permission.__schema__(:fields)
      assert :tenant_id in fields
    end

    test "struct can be created" do
      perm = %Permission{}
      assert perm.__struct__ == Permission
    end
  end

  describe "Constitutional Invariants (Ψ₀)" do
    test "Ψ₀ existence: Permission module exists" do
      assert Permission.__info__(:module) == Permission
    end

    test "Ψ₃ verification: schema fields are introspectable" do
      assert is_list(Permission.__schema__(:fields))
    end
  end
end
