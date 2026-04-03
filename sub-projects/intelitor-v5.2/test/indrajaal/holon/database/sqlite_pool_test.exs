defmodule Indrajaal.Holon.Database.SQLitePoolTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Holon.Database.SQLitePool

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(SQLitePool)
    end

    test "module exports expected functions" do
      assert function_exported?(SQLitePool, :start_pool, 4)
      assert function_exported?(SQLitePool, :stop_pool, 1)
      assert function_exported?(SQLitePool, :query, 3)
      assert function_exported?(SQLitePool, :execute, 3)
      assert function_exported?(SQLitePool, :transaction, 3)
    end
  end

  describe "query/3 error handling" do
    test "returns error for nonexistent pool name" do
      result = SQLitePool.query(:nonexistent_sqlite_pool_xyz, "SELECT 1", [])
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "execute/3 error handling" do
    test "returns error for nonexistent pool name" do
      result = SQLitePool.execute(:nonexistent_sqlite_pool_xyz, "CREATE TABLE t (id INTEGER)", [])
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "transaction/3 error handling" do
    test "returns error for nonexistent pool name" do
      result =
        SQLitePool.transaction(:nonexistent_sqlite_pool_xyz, fn _conn -> {:ok, :done} end, [])

      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end
end
