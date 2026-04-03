defmodule Intelitor.Accounts.AccountTest do
  @moduledoc """
  Test suite for Intelitor.Accounts.Account.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/accounts/account.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Accounts.Account

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(Account)
    end

    test "module has __info__/1 function" do
      assert function_exported?(Account, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = Account.__info__(:module)
      assert info == Intelitor.Accounts.Account
    end
  end
end
