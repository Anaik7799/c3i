defmodule Indrajaal.AggregationQueryBuilderTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.AggregationQueryBuilder

  test "module exists" do
    assert Code.ensure_loaded?(AggregationQueryBuilder)
  end

  test "build_query/2 is exported" do
    assert function_exported?(AggregationQueryBuilder, :build_query, 2)
  end
end
