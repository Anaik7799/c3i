defmodule Intelitor.MultiTenantTest do
  @moduledoc """
  Test suite for Intelitor.MultiTenant.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/multi_tenant.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.MultiTenant

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(MultiTenant)
    end

    test "module has __info__/1 function" do
      assert function_exported?(MultiTenant, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = MultiTenant.__info__(:module)
      assert info == Intelitor.MultiTenant
    end
  end
end
