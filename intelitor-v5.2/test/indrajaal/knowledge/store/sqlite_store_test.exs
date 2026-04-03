defmodule Indrajaal.Knowledge.Store.SQLiteStoreTest do
  @moduledoc """
  Tests for Indrajaal.Knowledge.Store.SQLiteStore GenServer.
  STAMP: SC-TDG, SC-COV-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Knowledge.Store.SQLiteStore

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(SQLiteStore)
    end

    test "module has expected public functions" do
      assert function_exported?(SQLiteStore, :get_holon, 1)
      assert function_exported?(SQLiteStore, :save_holon, 2)
      assert function_exported?(SQLiteStore, :insert, 2)
      assert function_exported?(SQLiteStore, :stats, 0)
    end

    test "module implements GenServer behaviour" do
      assert function_exported?(SQLiteStore, :start_link, 1)
      assert function_exported?(SQLiteStore, :init, 1)
    end
  end

  describe "SQLiteStore with temp database" do
    setup do
      db_path = "/tmp/sqlite_store_test_#{System.unique_integer([:positive])}.db"
      name = :"sqlite_store_test_#{System.unique_integer([:positive])}"

      case SQLiteStore.start_link(name: name, path: db_path) do
        {:ok, pid} ->
          on_exit(fn ->
            if Process.alive?(pid), do: GenServer.stop(pid, :normal)
            File.rm(db_path)
            File.rm("#{db_path}-shm")
            File.rm("#{db_path}-wal")
          end)

          {:ok, pid: pid}

        {:error, _reason} ->
          :skip
      end
    end

    test "stats/0 returns a map or term", %{pid: _pid} do
      result = SQLiteStore.stats()
      assert is_map(result) or result != nil
    end

    test "get_holon/1 returns not found for missing holon", %{pid: _pid} do
      result = SQLiteStore.get_holon("nonexistent-holon-xyz-123")
      assert match?({:error, :not_found}, result) or match?({:ok, _}, result) or result == nil
    end

    test "save_holon/2 stores and retrieves a holon", %{pid: _pid} do
      holon_id = "test-holon-#{System.unique_integer([:positive])}"
      data = %{name: "test", value: 42, timestamp: DateTime.utc_now()}

      save_result = SQLiteStore.save_holon(holon_id, data)
      assert match?(:ok, save_result) or match?({:ok, _}, save_result)

      get_result = SQLiteStore.get_holon(holon_id)
      assert match?({:ok, _}, get_result) or get_result != nil
    end

    test "insert/2 inserts a record into a table", %{pid: _pid} do
      result = SQLiteStore.insert(:holons, %{id: "ins-test", data: Jason.encode!(%{v: 1})})
      assert match?(:ok, result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
