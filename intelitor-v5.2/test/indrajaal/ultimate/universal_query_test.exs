defmodule Indrajaal.Ultimate.UniversalQueryTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Ultimate.UniversalQuery

  test "module is loaded" do
    assert Code.ensure_loaded?(UniversalQuery)
  end

  test "build_query/2 is defined" do
    assert function_exported?(UniversalQuery, :build_query, 2)
  end

  test "build_query/2 accepts a base query and empty criteria" do
    # Use a simple Ecto query as base — import Ecto.Query for from/2
    import Ecto.Query
    base = from(u in "users", select: u)
    result = UniversalQuery.build_query(base, [])
    # Should return the query unchanged
    assert result == base
  end

  test "build_query/2 applies limit criterion" do
    import Ecto.Query
    base = from(u in "users", select: u)
    result = UniversalQuery.build_query(base, [{:limit, 10}])
    # Result should be an Ecto query struct
    assert is_struct(result, Ecto.Query)
  end

  test "build_query/2 applies multiple criteria" do
    import Ecto.Query
    base = from(u in "users", select: u)
    criteria = [{:limit, 5}, {:offset, 10}]
    result = UniversalQuery.build_query(base, criteria)
    assert is_struct(result, Ecto.Query)
  end

  test "build_query/2 ignores unknown criteria" do
    import Ecto.Query
    base = from(u in "users", select: u)
    result = UniversalQuery.build_query(base, [{:unknown_criterion, :ignored}])
    assert is_struct(result, Ecto.Query)
  end
end
