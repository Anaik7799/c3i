defmodule Indrajaal.Authentication.SessionTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Authentication.Session

  test "module exists" do
    assert Code.ensure_loaded?(Session)
  end

  test "create/2 is exported" do
    assert function_exported?(Session, :create, 2)
  end

  test "get_info/1 is exported" do
    assert function_exported?(Session, :get_info, 1)
  end

  test "revoke/1 is exported" do
    assert function_exported?(Session, :revoke, 1)
  end
end
