defmodule Indrajaal.MultiTenantTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.MultiTenant

  test "module exists" do
    assert Code.ensure_loaded?(MultiTenant)
  end

  test "scope_to_tenant/2 is exported" do
    assert function_exported?(MultiTenant, :scope_to_tenant, 2)
  end

  test "verify_tenant_access/2 is exported" do
    assert function_exported?(MultiTenant, :verify_tenant_access, 2)
  end
end
