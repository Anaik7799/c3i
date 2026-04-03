defmodule Indrajaal.AuthorizationTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Authorization

  test "module exists" do
    assert Code.ensure_loaded?(Authorization)
  end

  test "can?/3 is exported" do
    assert function_exported?(Authorization, :can?, 3)
  end

  test "filter_by_access/2 is exported" do
    assert function_exported?(Authorization, :filter_by_access, 2)
  end
end
