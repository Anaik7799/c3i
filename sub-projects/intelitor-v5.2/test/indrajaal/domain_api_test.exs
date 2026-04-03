defmodule Indrajaal.DomainApiTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.DomainApi

  test "module exists" do
    assert Code.ensure_loaded?(DomainApi)
  end

  test "create_tenant/2 is exported" do
    assert function_exported?(DomainApi, :create_tenant, 2)
  end

  test "create_user/2 is exported" do
    assert function_exported?(DomainApi, :create_user, 2)
  end

  test "create_site/2 is exported" do
    assert function_exported?(DomainApi, :create_site, 2)
  end
end
