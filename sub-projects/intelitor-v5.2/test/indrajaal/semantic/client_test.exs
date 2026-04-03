defmodule Indrajaal.Semantic.ClientTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Semantic.Client

  test "module exists" do
    assert Code.ensure_loaded?(Client)
  end

  test "add_triple/3 is exported" do
    assert function_exported?(Client, :add_triple, 3)
  end

  test "query_sparql/1 is exported" do
    assert function_exported?(Client, :query_sparql, 1)
  end

  test "find_similar/2 is exported" do
    assert function_exported?(Client, :find_similar, 2)
  end
end
