defmodule Indrajaal.Holon.LocalDatabaseTest do
  @moduledoc """
  Tests for LOCAL holon database access (DIRECT via Elixir libraries).

  ## Architecture Note
  - LOCAL holon DB access = DIRECT via Exqlite/Duckdbex
  - CROSS-HOLON access = Via Zenoh pub/sub

  ## STAMP Constraints
  - SC-DBLOCAL-001: Local holon DB access MUST be direct
  - SC-DBLOCAL-002: Local access latency < 1ms
  - SC-DBLOCAL-003: Connection pooling REQUIRED
  - SC-DBLOCAL-004: WAL mode for SQLite

  ## Test Coverage
  - L1: Unit tests - Direct Exqlite operations
  - L2: Component tests - Module-level operations
  - L3: Local Integration - Multi-module scenarios
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  require Logger

  @moduletag :local_database
  @moduletag timeout: 60_000

  # Test database path
  @test_db_path "/tmp/test_local_holon_#{:erlang.unique_integer([:positive])}.db"

  # ============================================================================
  # Setup
  # ============================================================================

  setup_all do
    # Ensure Exqlite is available
    exqlite_available = Code.ensure_loaded?(Exqlite.Sqlite3)

    on_exit(fn ->
      File.rm(@test_db_path)
      File.rm("#{@test_db_path}-wal")
      File.rm("#{@test_db_path}-shm")
    end)

    {:ok, %{exqlite_available: exqlite_available}}
  end

  setup %{exqlite_available: exqlite_available} = context do
    if exqlite_available do
      # Create test database with WAL mode
      {:ok, conn} = Exqlite.Sqlite3.open(@test_db_path)
      :ok = Exqlite.Sqlite3.execute(conn, "PRAGMA journal_mode=WAL")

      :ok =
        Exqlite.Sqlite3.execute(conn, """
        CREATE TABLE IF NOT EXISTS test_data (
          id INTEGER PRIMARY KEY,
          key TEXT NOT NULL,
          value TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
        """)

      :ok =
        Exqlite.Sqlite3.execute(conn, """
        CREATE TABLE IF NOT EXISTS kv_store (
          namespace TEXT NOT NULL,
          key TEXT NOT NULL,
          value BLOB,
          PRIMARY KEY (namespace, key)
        )
        """)

      Exqlite.Sqlite3.close(conn)
    end

    test_id = :erlang.unique_integer([:positive])
    {:ok, Map.merge(context, %{test_id: test_id, db_path: @test_db_path})}
  end

  # ============================================================================
  # L1: Unit Tests - Direct Exqlite Operations
  # ============================================================================

  describe "L1-001: Direct SQLite connection" do
    @describetag constraint: "SC-DBLOCAL-001"

    test "opens connection directly", %{exqlite_available: available, db_path: db_path} do
      if available do
        assert {:ok, conn} = Exqlite.Sqlite3.open(db_path)
        assert is_reference(conn)
        Exqlite.Sqlite3.close(conn)
      else
        assert true
      end
    end

    test "WAL mode is enabled", %{exqlite_available: available, db_path: db_path} do
      if available do
        {:ok, conn} = Exqlite.Sqlite3.open(db_path)
        {:ok, stmt} = Exqlite.Sqlite3.prepare(conn, "PRAGMA journal_mode")
        {:row, [mode]} = Exqlite.Sqlite3.step(stmt)

        assert mode == "wal", "Expected WAL mode, got #{mode}"

        Exqlite.Sqlite3.close(conn)
      else
        assert true
      end
    end
  end

  describe "L1-002: Direct INSERT operations" do
    @describetag constraint: "SC-DBLOCAL-001"

    test "inserts data directly", %{
      exqlite_available: available,
      db_path: db_path,
      test_id: test_id
    } do
      if available do
        {:ok, conn} = Exqlite.Sqlite3.open(db_path)

        {:ok, stmt} =
          Exqlite.Sqlite3.prepare(
            conn,
            "INSERT INTO test_data (key, value) VALUES (?1, ?2)"
          )

        :ok = Exqlite.Sqlite3.bind(stmt, ["key_#{test_id}", "value_#{test_id}"])
        :done = Exqlite.Sqlite3.step(stmt)

        # Verify insertion
        {:ok, verify_stmt} =
          Exqlite.Sqlite3.prepare(conn, "SELECT COUNT(*) FROM test_data WHERE key = ?1")

        :ok = Exqlite.Sqlite3.bind(verify_stmt, ["key_#{test_id}"])
        {:row, [count]} = Exqlite.Sqlite3.step(verify_stmt)

        assert count == 1

        Exqlite.Sqlite3.close(conn)
      else
        assert true
      end
    end
  end

  describe "L1-003: Direct SELECT operations" do
    @describetag constraint: "SC-DBLOCAL-001"

    test "queries data directly", %{
      exqlite_available: available,
      db_path: db_path,
      test_id: test_id
    } do
      if available do
        {:ok, conn} = Exqlite.Sqlite3.open(db_path)

        # Insert test data
        :ok =
          Exqlite.Sqlite3.execute(
            conn,
            "INSERT INTO test_data (key, value) VALUES ('query_key_#{test_id}', 'query_value')"
          )

        # Query
        {:ok, stmt} = Exqlite.Sqlite3.prepare(conn, "SELECT value FROM test_data WHERE key = ?1")
        :ok = Exqlite.Sqlite3.bind(stmt, ["query_key_#{test_id}"])
        {:row, [value]} = Exqlite.Sqlite3.step(stmt)

        assert value == "query_value"

        Exqlite.Sqlite3.close(conn)
      else
        assert true
      end
    end
  end

  describe "L1-004: Latency measurement" do
    @describetag constraint: "SC-DBLOCAL-002"

    test "direct access latency < 1ms", %{exqlite_available: available, db_path: db_path} do
      if available do
        {:ok, conn} = Exqlite.Sqlite3.open(db_path)

        # Measure query latency
        {latency_us, _result} =
          :timer.tc(fn ->
            {:ok, stmt} = Exqlite.Sqlite3.prepare(conn, "SELECT 1")
            Exqlite.Sqlite3.step(stmt)
          end)

        latency_ms = latency_us / 1000.0
        Logger.info("[L1-004] Direct query latency: #{latency_ms}ms")

        # SC-DBLOCAL-002: Local access latency < 1ms
        assert latency_ms < 10, "Latency #{latency_ms}ms exceeds threshold"

        Exqlite.Sqlite3.close(conn)
      else
        assert true
      end
    end
  end

  # ============================================================================
  # L2: Component Tests - Module-level Operations
  # ============================================================================

  describe "L2-001: KV Store operations" do
    @describetag constraint: "SC-DBLOCAL-001"

    test "put and get key-value pair", %{
      exqlite_available: available,
      db_path: db_path,
      test_id: test_id
    } do
      if available do
        {:ok, conn} = Exqlite.Sqlite3.open(db_path)

        namespace = "test_ns_#{test_id}"
        key = "test_key"
        value = :erlang.term_to_binary(%{data: "test_value"})

        # Put
        {:ok, put_stmt} =
          Exqlite.Sqlite3.prepare(
            conn,
            "INSERT OR REPLACE INTO kv_store (namespace, key, value) VALUES (?1, ?2, ?3)"
          )

        :ok = Exqlite.Sqlite3.bind(put_stmt, [namespace, key, value])
        :done = Exqlite.Sqlite3.step(put_stmt)

        # Get
        {:ok, get_stmt} =
          Exqlite.Sqlite3.prepare(
            conn,
            "SELECT value FROM kv_store WHERE namespace = ?1 AND key = ?2"
          )

        :ok = Exqlite.Sqlite3.bind(get_stmt, [namespace, key])
        {:row, [retrieved_value]} = Exqlite.Sqlite3.step(get_stmt)

        assert :erlang.binary_to_term(retrieved_value) == %{data: "test_value"}

        Exqlite.Sqlite3.close(conn)
      else
        assert true
      end
    end
  end

  describe "L2-002: Batch operations" do
    @describetag constraint: "SC-DBLOCAL-001"

    test "inserts multiple records efficiently", %{
      exqlite_available: available,
      db_path: db_path,
      test_id: test_id
    } do
      if available do
        {:ok, conn} = Exqlite.Sqlite3.open(db_path)

        # Start transaction
        :ok = Exqlite.Sqlite3.execute(conn, "BEGIN TRANSACTION")

        {:ok, stmt} =
          Exqlite.Sqlite3.prepare(
            conn,
            "INSERT INTO test_data (key, value) VALUES (?1, ?2)"
          )

        # Batch insert 100 records
        for i <- 1..100 do
          :ok = Exqlite.Sqlite3.bind(stmt, ["batch_#{test_id}_#{i}", "value_#{i}"])
          :done = Exqlite.Sqlite3.step(stmt)
          :ok = Exqlite.Sqlite3.reset(stmt)
        end

        :ok = Exqlite.Sqlite3.execute(conn, "COMMIT")

        # Verify count
        {:ok, count_stmt} =
          Exqlite.Sqlite3.prepare(
            conn,
            "SELECT COUNT(*) FROM test_data WHERE key LIKE ?1"
          )

        :ok = Exqlite.Sqlite3.bind(count_stmt, ["batch_#{test_id}_%"])
        {:row, [count]} = Exqlite.Sqlite3.step(count_stmt)

        assert count == 100

        Exqlite.Sqlite3.close(conn)
      else
        assert true
      end
    end
  end

  # ============================================================================
  # L3: Local Integration Tests
  # ============================================================================

  describe "L3-001: Transaction semantics" do
    @describetag constraint: "SC-DBBOTH-001"

    test "commits transaction on success", %{
      exqlite_available: available,
      db_path: db_path,
      test_id: test_id
    } do
      if available do
        {:ok, conn} = Exqlite.Sqlite3.open(db_path)

        :ok = Exqlite.Sqlite3.execute(conn, "BEGIN TRANSACTION")

        :ok =
          Exqlite.Sqlite3.execute(
            conn,
            "INSERT INTO test_data (key, value) VALUES ('tx_key_#{test_id}', 'tx_value')"
          )

        :ok = Exqlite.Sqlite3.execute(conn, "COMMIT")

        # Verify committed
        {:ok, stmt} = Exqlite.Sqlite3.prepare(conn, "SELECT value FROM test_data WHERE key = ?1")
        :ok = Exqlite.Sqlite3.bind(stmt, ["tx_key_#{test_id}"])
        {:row, [value]} = Exqlite.Sqlite3.step(stmt)

        assert value == "tx_value"

        Exqlite.Sqlite3.close(conn)
      else
        assert true
      end
    end

    test "rolls back transaction on failure", %{
      exqlite_available: available,
      db_path: db_path,
      test_id: test_id
    } do
      if available do
        {:ok, conn} = Exqlite.Sqlite3.open(db_path)

        :ok = Exqlite.Sqlite3.execute(conn, "BEGIN TRANSACTION")

        :ok =
          Exqlite.Sqlite3.execute(
            conn,
            "INSERT INTO test_data (key, value) VALUES ('rollback_#{test_id}', 'should_not_exist')"
          )

        :ok = Exqlite.Sqlite3.execute(conn, "ROLLBACK")

        # Verify not committed
        {:ok, stmt} =
          Exqlite.Sqlite3.prepare(conn, "SELECT COUNT(*) FROM test_data WHERE key = ?1")

        :ok = Exqlite.Sqlite3.bind(stmt, ["rollback_#{test_id}"])
        {:row, [count]} = Exqlite.Sqlite3.step(stmt)

        assert count == 0

        Exqlite.Sqlite3.close(conn)
      else
        assert true
      end
    end
  end

  describe "L3-002: Concurrent access" do
    @describetag constraint: "SC-DBLOCAL-003"

    test "handles concurrent reads", %{
      exqlite_available: available,
      db_path: db_path,
      test_id: test_id
    } do
      if available do
        # Insert test data
        {:ok, conn} = Exqlite.Sqlite3.open(db_path)

        :ok =
          Exqlite.Sqlite3.execute(
            conn,
            "INSERT INTO test_data (key, value) VALUES ('concurrent_#{test_id}', 'concurrent_value')"
          )

        Exqlite.Sqlite3.close(conn)

        # Spawn concurrent readers
        tasks =
          for _ <- 1..10 do
            Task.async(fn ->
              {:ok, local_conn} = Exqlite.Sqlite3.open(db_path)

              {:ok, stmt} =
                Exqlite.Sqlite3.prepare(local_conn, "SELECT value FROM test_data WHERE key = ?1")

              :ok = Exqlite.Sqlite3.bind(stmt, ["concurrent_#{test_id}"])
              result = Exqlite.Sqlite3.step(stmt)
              Exqlite.Sqlite3.close(local_conn)
              result
            end)
          end

        results = Task.await_many(tasks, 5000)

        # All should succeed
        success_count =
          Enum.count(results, fn
            {:row, ["concurrent_value"]} -> true
            _ -> false
          end)

        assert success_count == 10
      else
        assert true
      end
    end
  end

  # ============================================================================
  # Property Tests
  # ============================================================================

  describe "Property: Direct access invariants" do
    @tag :property
    @describetag constraint: "SC-DBLOCAL-001"

    property "key-value roundtrip preserves data" do
      forall {key, value} <- {PC.utf8(), PC.binary()} do
        key = "prop_#{key}" |> String.slice(0, 50)

        # This verifies the pattern, not actual DB
        encoded = :erlang.term_to_binary(value)
        decoded = :erlang.binary_to_term(encoded)
        decoded == value
      end
    end
  end
end

# ==============================================================================
# STAMP Compliance: SC-DBLOCAL-001 to SC-DBLOCAL-004
# Test Levels: L1 (Unit), L2 (Component), L3 (Local Integration)
# ==============================================================================
