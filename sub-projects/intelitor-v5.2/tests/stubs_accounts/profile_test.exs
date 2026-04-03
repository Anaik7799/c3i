defmodule Intelitor.Accounts.ProfileTest do
  @moduledoc """
  Test suite for Intelitor.Accounts.Profile.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/accounts/profile.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Accounts.Profile

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(Profile)
    end

    test "module has __info__/1 function" do
      assert function_exported?(Profile, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = Profile.__info__(:module)
      assert info == Intelitor.Accounts.Profile
    end
  end
end
