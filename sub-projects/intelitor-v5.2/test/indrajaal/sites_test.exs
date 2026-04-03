defmodule Indrajaal.SitesTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Sites

  test "module exists" do
    assert Code.ensure_loaded?(Sites)
  end

  test "list_sites/1 is exported" do
    assert function_exported?(Sites, :list_sites, 1)
  end

  test "get_site/2 is exported" do
    assert function_exported?(Sites, :get_site, 2)
  end

  test "create_site/2 is exported" do
    assert function_exported?(Sites, :create_site, 2)
  end

  test "update_site/3 is exported" do
    assert function_exported?(Sites, :update_site, 3)
  end
end
