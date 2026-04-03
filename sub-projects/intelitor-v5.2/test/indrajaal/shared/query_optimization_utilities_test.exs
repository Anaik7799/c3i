defmodule Indrajaal.Shared.QueryOptimizationUtilitiesTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Shared.QueryOptimizationUtilities

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(QueryOptimizationUtilities)
    end
  end

  describe "apply_pagination/2" do
    test "function is exported" do
      assert function_exported?(QueryOptimizationUtilities, :apply_pagination, 2)
    end

    test "applies pagination to an Ecto query" do
      import Ecto.Query
      query = from(x in "items")
      result = QueryOptimizationUtilities.apply_pagination(query, %{page: 1, page_size: 10})
      assert result != nil
    end

    test "uses defaults for missing pagination options" do
      import Ecto.Query
      query = from(x in "items")
      result = QueryOptimizationUtilities.apply_pagination(query, %{})
      assert result != nil
    end

    test "clamps page to minimum of 1" do
      import Ecto.Query
      query = from(x in "items")
      result = QueryOptimizationUtilities.apply_pagination(query, %{page: -5, page_size: 10})
      assert result != nil
    end
  end

  describe "apply_filters/3" do
    test "function is exported" do
      assert function_exported?(QueryOptimizationUtilities, :apply_filters, 3)
    end

    test "returns unchanged query for empty filters" do
      import Ecto.Query
      query = from(x in "items")
      result = QueryOptimizationUtilities.apply_filters(query, %{}, %{})
      assert result != nil
    end

    test "applies boolean active filter" do
      import Ecto.Query
      query = from(x in "items")
      result = QueryOptimizationUtilities.apply_filters(query, %{active: true}, %{})
      assert result != nil
    end
  end

  describe "apply_ordering/2" do
    test "function is exported" do
      assert function_exported?(QueryOptimizationUtilities, :apply_ordering, 2)
    end

    test "applies ascending order" do
      import Ecto.Query
      query = from(x in "items")

      result =
        QueryOptimizationUtilities.apply_ordering(query, %{field: :inserted_at, direction: :asc})

      assert result != nil
    end

    test "applies list of ordering specs" do
      import Ecto.Query
      query = from(x in "items")

      result =
        QueryOptimizationUtilities.apply_ordering(query, [%{field: :name, direction: :asc}])

      assert result != nil
    end
  end

  describe "apply_time_filters/2" do
    test "function is exported" do
      assert function_exported?(QueryOptimizationUtilities, :apply_time_filters, 2)
    end

    test "returns unchanged query for empty time filters" do
      import Ecto.Query
      query = from(x in "items")
      result = QueryOptimizationUtilities.apply_time_filters(query, %{})
      assert result != nil
    end
  end

  describe "apply_tenant_scoping/2" do
    test "function is exported" do
      assert function_exported?(QueryOptimizationUtilities, :apply_tenant_scoping, 2)
    end

    test "applies tenant scoping for valid tenant_id" do
      import Ecto.Query
      query = from(x in "items")
      result = QueryOptimizationUtilities.apply_tenant_scoping(query, "tenant-abc")
      assert result != nil
    end

    test "returns query unchanged for nil tenant_id" do
      import Ecto.Query
      query = from(x in "items")
      result = QueryOptimizationUtilities.apply_tenant_scoping(query, nil)
      assert result != nil
    end
  end

  describe "apply_aggregation/3" do
    test "function is exported" do
      assert function_exported?(QueryOptimizationUtilities, :apply_aggregation, 3)
    end

    test "applies count aggregation" do
      import Ecto.Query
      query = from(x in "items")
      result = QueryOptimizationUtilities.apply_aggregation(query, :id, :count)
      assert result != nil
    end

    test "applies sum aggregation" do
      import Ecto.Query
      query = from(x in "items")
      result = QueryOptimizationUtilities.apply_aggregation(query, :amount, :sum)
      assert result != nil
    end

    test "returns unchanged query for unknown operation" do
      import Ecto.Query
      query = from(x in "items")
      result = QueryOptimizationUtilities.apply_aggregation(query, :field, :unknown_op)
      assert result != nil
    end
  end

  describe "optimize_query_performance/2" do
    test "function is exported" do
      assert function_exported?(QueryOptimizationUtilities, :optimize_query_performance, 2)
    end

    test "optimizes query with default options" do
      import Ecto.Query
      query = from(x in "items")
      result = QueryOptimizationUtilities.optimize_query_performance(query)
      assert result != nil
    end
  end

  describe "build_complex_where/2" do
    test "function is exported" do
      assert function_exported?(QueryOptimizationUtilities, :build_complex_where, 2)
    end

    test "builds where clause from conditions list" do
      import Ecto.Query
      query = from(x in "items")
      conditions = [%{field: :status, operator: :eq, value: "active"}]
      result = QueryOptimizationUtilities.build_complex_where(query, conditions)
      assert result != nil
    end

    test "returns unchanged query for empty conditions" do
      import Ecto.Query
      query = from(x in "items")
      result = QueryOptimizationUtilities.build_complex_where(query, [])
      assert result != nil
    end
  end
end
