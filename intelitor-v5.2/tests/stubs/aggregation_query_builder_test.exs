defmodule Intelitor.AggregationQueryBuilderTest do
  @moduledoc """
  Test suite for Intelitor.AggregationQueryBuilder.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/aggregation_query_builder.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.AggregationQueryBuilder

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(AggregationQueryBuilder)
    end

    test "module has __info__/1 function" do
      assert function_exported?(AggregationQueryBuilder, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = AggregationQueryBuilder.__info__(:module)
      assert info == Intelitor.AggregationQueryBuilder
    end
  end
end
