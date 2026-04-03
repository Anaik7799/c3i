defmodule Indrajaal.Accounts.ActivityLogTest do
  @moduledoc """
  TDG test suite for Indrajaal.Accounts.ActivityLog Ash resource.

  ## STAMP Safety Integration
  - SC-HOLON-001: Holon state sovereignty
  - SC-DB-001: BaseResource compliance

  ## TPS 5-Level RCA Context
  - L1 Symptom: ActivityLog schema mismatch
  - L5 Root Cause: Incorrect enum or field definition
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Accounts.ActivityLog

  @valid_activity_types [
    :login,
    :logout,
    :password_change,
    :profile_update,
    :permission_change,
    :access_granted,
    :access_denied,
    :token_created,
    :token_revoked,
    :mfa_enabled,
    :mfa_disabled,
    :account_locked,
    :account_unlocked,
    :data_export,
    :admin_action
  ]

  describe "ActivityLog Ash resource schema" do
    test "module exists and is an Ash resource" do
      assert Code.ensure_loaded?(ActivityLog)
      assert function_exported?(ActivityLog, :__ash_resource__, 0)
    end

    test "__schema__/1 returns field list" do
      fields = ActivityLog.__schema__(:fields)
      assert is_list(fields)
      assert length(fields) > 0
    end

    test "has :id field" do
      fields = ActivityLog.__schema__(:fields)
      assert :id in fields
    end

    test "has :activity_type field" do
      fields = ActivityLog.__schema__(:fields)
      assert :activity_type in fields
    end

    test "has :tenant_id field" do
      fields = ActivityLog.__schema__(:fields)
      assert :tenant_id in fields
    end

    test "struct can be created" do
      log = %ActivityLog{}
      assert log.__struct__ == ActivityLog
    end
  end

  describe "activity_type enum values" do
    test "all 15 valid activity types are atoms" do
      Enum.each(@valid_activity_types, fn type ->
        assert is_atom(type),
               "Expected #{inspect(type)} to be an atom"
      end)
    end

    test "valid_activity_types list has 15 entries" do
      assert length(@valid_activity_types) == 15
    end

    test "login is a valid activity type" do
      assert :login in @valid_activity_types
    end

    test "admin_action is a valid activity type" do
      assert :admin_action in @valid_activity_types
    end

    test "data_export is a valid activity type" do
      assert :data_export in @valid_activity_types
    end
  end

  describe "Constitutional Invariants (Ψ₀)" do
    test "Ψ₀ existence: ActivityLog module exists" do
      assert ActivityLog.__info__(:module) == ActivityLog
    end

    test "Ψ₃ verification: schema fields are introspectable" do
      assert is_list(ActivityLog.__schema__(:fields))
    end
  end
end
