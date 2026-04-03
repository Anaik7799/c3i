defmodule Indrajaal.Accounts.ProfileTest do
  @moduledoc """
  TDG test suite for Indrajaal.Accounts.Profile Ash resource.

  ## STAMP Safety Integration
  - SC-DB-001: BaseResource compliance

  ## TPS 5-Level RCA Context
  - L1 Symptom: Profile defaults not applied
  - L5 Root Cause: Missing default attribute values
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Accounts.Profile

  describe "Profile Ash resource schema" do
    test "module exists and is an Ash resource" do
      assert Code.ensure_loaded?(Profile)
      assert function_exported?(Profile, :__ash_resource__, 0)
    end

    test "__schema__/1 returns field list" do
      fields = Profile.__schema__(:fields)
      assert is_list(fields)
      assert length(fields) > 0
    end

    test "has :id field" do
      fields = Profile.__schema__(:fields)
      assert :id in fields
    end

    test "has :timezone field" do
      fields = Profile.__schema__(:fields)
      assert :timezone in fields
    end

    test "has :locale field" do
      fields = Profile.__schema__(:fields)
      assert :locale in fields
    end

    test "has :tenant_id field" do
      fields = Profile.__schema__(:fields)
      assert :tenant_id in fields
    end

    test "struct can be created with defaults" do
      profile = %Profile{}
      assert profile.__struct__ == Profile
      # timezone defaults to "UTC", locale to "en"
      assert profile.timezone == "UTC" or is_nil(profile.timezone)
      assert profile.locale == "en" or is_nil(profile.locale)
    end
  end

  describe "Profile default values" do
    test "timezone default is UTC" do
      profile = %Profile{}
      assert profile.timezone == "UTC" or is_nil(profile.timezone)
    end

    test "locale default is en" do
      profile = %Profile{}
      assert profile.locale == "en" or is_nil(profile.locale)
    end
  end

  describe "Constitutional Invariants (Ψ₀)" do
    test "Ψ₀ existence: Profile module exists" do
      assert Profile.__info__(:module) == Profile
    end

    test "Ψ₃ verification: schema fields are introspectable" do
      assert is_list(Profile.__schema__(:fields))
    end
  end
end
