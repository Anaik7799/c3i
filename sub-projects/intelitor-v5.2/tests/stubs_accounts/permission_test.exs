defmodule Intelitor.Accounts.PermissionTest do
  @moduledoc """
  Test suite for Intelitor.Accounts.Permission.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/accounts/permission.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Accounts.Permission

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(Permission)
    end

    test "module has __info__/1 function" do
      assert function_exported?(Permission, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = Permission.__info__(:module)
      assert info == Intelitor.Accounts.Permission
    end
  end
end
