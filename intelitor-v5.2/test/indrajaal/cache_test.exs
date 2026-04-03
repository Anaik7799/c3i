defmodule Indrajaal.CacheTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cache

  test "module exists" do
    assert Code.ensure_loaded?(Cache)
  end

  test "start_link/1 is exported" do
    assert function_exported?(Cache, :start_link, 1)
  end

  test "get/3 is exported" do
    assert function_exported?(Cache, :get, 3)
  end

  test "put/4 is exported" do
    assert function_exported?(Cache, :put, 4)
  end

  test "delete/2 is exported" do
    assert function_exported?(Cache, :delete, 2)
  end

  test "stats/1 is exported" do
    assert function_exported?(Cache, :stats, 1)
  end
end
