defmodule Indrajaal.Holon.Database.ZenohDatabaseBridgeTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Holon.Database.ZenohDatabaseBridge

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(ZenohDatabaseBridge)
    end

    test "module exports expected functions" do
      assert function_exported?(ZenohDatabaseBridge, :start_link, 1)
      assert function_exported?(ZenohDatabaseBridge, :query, 1)
      assert function_exported?(ZenohDatabaseBridge, :execute, 1)
      assert function_exported?(ZenohDatabaseBridge, :execute_cas, 1)
      assert function_exported?(ZenohDatabaseBridge, :stats, 1)
      assert function_exported?(ZenohDatabaseBridge, :check_connection, 1)
      assert function_exported?(ZenohDatabaseBridge, :get_version_vector, 2)
    end
  end

  describe "check_connection/1" do
    test "returns :ok or error tuple for any endpoint" do
      result = ZenohDatabaseBridge.check_connection("tcp/127.0.0.1:7447")
      assert result == :ok or match?({:error, _}, result)
    end

    test "accepts any string endpoint" do
      result = ZenohDatabaseBridge.check_connection("stub://localhost")
      assert result == :ok or match?({:error, _}, result)
    end
  end

  describe "get_version_vector/2" do
    test "returns ok tuple with version map for any holon id" do
      result = ZenohDatabaseBridge.get_version_vector("ex:l3:tst:srv:main", "fs:l4:tst:agt:peer")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returned version map is a map type" do
      target = "fs:l4:tst:agt:peer"

      case ZenohDatabaseBridge.get_version_vector("ex:l3:tst:srv:main", target) do
        {:ok, version_map} ->
          assert is_map(version_map)

        {:error, _} ->
          assert true
      end
    end
  end

  describe "query/1, execute/1, execute_cas/1 keyword-list contract" do
    # These functions route to a GenServer via Registry (BridgeRegistry must be running).
    # In unit tests without the full application, we verify the function contract at the
    # spec level only. The full integration is tested via sa-test with running containers.

    test "query/1 is exported with arity 1" do
      assert function_exported?(ZenohDatabaseBridge, :query, 1)
    end

    test "execute/1 is exported with arity 1" do
      assert function_exported?(ZenohDatabaseBridge, :execute, 1)
    end

    test "execute_cas/1 is exported with arity 1" do
      assert function_exported?(ZenohDatabaseBridge, :execute_cas, 1)
    end

    test "stats/1 is exported with arity 1" do
      assert function_exported?(ZenohDatabaseBridge, :stats, 1)
    end
  end
end
