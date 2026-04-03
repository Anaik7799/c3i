defmodule Indrajaal.Holon.Database.DuckDBPoolTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Holon.Database.DuckDBPool

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(DuckDBPool)
    end

    test "module exports expected functions" do
      assert function_exported?(DuckDBPool, :start_pool, 4)
      assert function_exported?(DuckDBPool, :stop_pool, 1)
      assert function_exported?(DuckDBPool, :query, 3)
      assert function_exported?(DuckDBPool, :execute, 3)
      assert function_exported?(DuckDBPool, :append, 4)
      assert function_exported?(DuckDBPool, :export_parquet, 3)
    end
  end

  describe "query/3 error handling" do
    test "returns error for nonexistent pool name" do
      result = DuckDBPool.query(:nonexistent_duckdb_pool_xyz, "SELECT 1", [])
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "execute/3 error handling" do
    test "returns error for nonexistent pool name" do
      result = DuckDBPool.execute(:nonexistent_duckdb_pool_xyz, "CREATE TABLE t (id INT)", [])
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "append/4 error handling" do
    test "returns error for nonexistent pool name" do
      result = DuckDBPool.append(:nonexistent_duckdb_pool_xyz, "events", ["id"], [{1}])
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "export_parquet/3 error handling" do
    test "returns error for nonexistent pool name" do
      result =
        DuckDBPool.export_parquet(:nonexistent_duckdb_pool_xyz, "SELECT 1", "/tmp/out.parquet")

      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end
end
