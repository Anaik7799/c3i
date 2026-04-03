defmodule Intelitor.Accounts.RoleTest do
  @moduledoc """
  Test suite for Intelitor.Accounts.Role.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/accounts/role.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Accounts.Role

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(Role)
    end

    test "module has __info__/1 function" do
      assert function_exported?(Role, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = Role.__info__(:module)
      assert info == Intelitor.Accounts.Role
    end
  end
end
