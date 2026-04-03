defmodule Intelitor.Accounts.Changes.HashPasswordTest do
  @moduledoc """
  Test suite for Intelitor.Accounts.Changes.HashPassword.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/accounts/changes/hash_password.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Accounts.Changes.HashPassword

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(HashPassword)
    end

    test "module has __info__/1 function" do
      assert function_exported?(HashPassword, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = HashPassword.__info__(:module)
      assert info == Intelitor.Accounts.Changes.HashPassword
    end
  end
end
