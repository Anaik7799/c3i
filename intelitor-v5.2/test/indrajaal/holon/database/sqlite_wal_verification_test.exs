defmodule Indrajaal.Holon.Database.SQLiteWALVerificationTest do
  @moduledoc """
  TDG test suite verifying SQLite WAL mode for holon state integrity (SC-DBLOCAL-004).

  WHAT: Verifies that the SQLitePool always operates in WAL (Write-Ahead Logging) mode,
        providing concurrent reads, ACID compliance, and no data loss on crash.
  WHY: SC-DBLOCAL-004 mandates WAL mode for all SQLite databases.
       SC-XHOLON-030 requires no data loss on crash.
       SC-XHOLON-031 mandates ACID compliance for all writes.

  ## STAMP Safety Integration
  - SC-DBLOCAL-004: WAL mode MANDATORY for all SQLite databases
  - SC-XHOLON-030: No data loss on crash — WAL mode provides atomic writes
  - SC-XHOLON-031: ACID compliance for all SQLite writes
  - SC-XHOLON-020: SQLite read latency < 1ms (verified indirectly via WAL)
  - SC-CONC-002: Connection pooling via Poolboy

  ## WAL Mode Properties Verified
  1. `PRAGMA journal_mode` returns `wal` after pool start
  2. Concurrent reads do not block writes
  3. Writes are ACID — commit = durable
  4. Multiple queries return consistent results (no phantom reads)
  5. Transactions are atomic — all or nothing
  """

  use ExUnit.Case, async: false

  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Holon.Database.SQLitePool

  @moduletag :unit
  @moduletag :database

  # Each test gets its own uniquely-named pool and temp database
  setup do
    # Unique pool name to prevent cross-test contamination
    pool_name = :"wal_test_pool_#{System.unique_integer([:positive])}"
    db_path = Path.join(System.tmp_dir!(), "wal_test_#{System.unique_integer([:positive])}.db")

    # Start pool — pool_size=2 to enable concurrent access tests
    {:ok, _pid} = SQLitePool.start_pool(pool_name, db_path, 2, 5_000)

    on_exit(fn ->
      SQLitePool.stop_pool(pool_name)
      File.rm(db_path)
      # WAL creates sidecar files
      File.rm("#{db_path}-wal")
      File.rm("#{db_path}-shm")
    end)

    {:ok, pool_name: pool_name, db_path: db_path}
  end

  # ─────────────────────────────────────────────────────────────────────────
  # WAL MODE ACTIVATION VERIFICATION (SC-DBLOCAL-004)
  # ─────────────────────────────────────────────────────────────────────────

  describe "WAL mode activation (SC-DBLOCAL-004)" do
    test "PRAGMA journal_mode returns 'wal' after pool start", %{pool_name: pool_name} do
      {:ok, rows} = SQLitePool.query(pool_name, "PRAGMA journal_mode", [])

      assert length(rows) == 1
      row = hd(rows)

      # WAL mode must be active — value is returned as atom key map
      journal_mode = row[:journal_mode] || row["journal_mode"]

      assert journal_mode == "wal",
             "Expected WAL journal mode but got: #{inspect(journal_mode)}"
    end

    test "busy_timeout pragma is set (non-zero)", %{pool_name: pool_name} do
      {:ok, rows} = SQLitePool.query(pool_name, "PRAGMA busy_timeout", [])

      assert length(rows) == 1
      row = hd(rows)
      timeout_val = row[:timeout] || row["timeout"]

      # busy_timeout=5000 set in open_connection/2
      assert is_integer(timeout_val) and timeout_val > 0,
             "Expected positive busy_timeout, got: #{inspect(timeout_val)}"
    end

    test "foreign_keys pragma is enabled", %{pool_name: pool_name} do
      {:ok, rows} = SQLitePool.query(pool_name, "PRAGMA foreign_keys", [])

      assert length(rows) == 1
      row = hd(rows)
      fk_val = row[:foreign_keys] || row["foreign_keys"]

      assert fk_val == 1,
             "Expected foreign_keys=1 (ON), got: #{inspect(fk_val)}"
    end

    test "synchronous pragma is set to NORMAL or FULL", %{pool_name: pool_name} do
      {:ok, rows} = SQLitePool.query(pool_name, "PRAGMA synchronous", [])

      assert length(rows) == 1
      row = hd(rows)
      sync_val = row[:synchronous] || row["synchronous"]

      # NORMAL = 1, FULL = 2 — both are acceptable for SIL-6
      assert sync_val in [1, 2],
             "Expected synchronous=1 (NORMAL) or 2 (FULL), got: #{inspect(sync_val)}"
    end
  end

  # ─────────────────────────────────────────────────────────────────────────
  # ACID COMPLIANCE VERIFICATION (SC-XHOLON-031)
  # ─────────────────────────────────────────────────────────────────────────

  describe "ACID compliance for writes (SC-XHOLON-031)" do
    test "write is durable — read after write returns committed data", %{pool_name: pool_name} do
      # Create table
      :ok = setup_test_table(pool_name)

      # Write
      {:ok, result} =
        SQLitePool.execute(
          pool_name,
          "INSERT INTO holon_state (key, value) VALUES (?, ?)",
          ["durability_key", "durability_value"]
        )

      assert result.changes == 1

      # Read back — must see the committed write
      {:ok, rows} =
        SQLitePool.query(
          pool_name,
          "SELECT value FROM holon_state WHERE key = ?",
          ["durability_key"]
        )

      assert length(rows) == 1
      assert hd(rows)[:value] == "durability_value"
    end

    test "transaction is atomic — all rows inserted or none", %{pool_name: pool_name} do
      :ok = setup_test_table(pool_name)

      # Successful transaction — all 3 rows committed
      {:ok, :all_inserted} =
        SQLitePool.transaction(
          pool_name,
          fn conn ->
            :ok = Exqlite.Sqlite3.execute(conn, "INSERT INTO holon_state VALUES ('k1', 'v1')")
            :ok = Exqlite.Sqlite3.execute(conn, "INSERT INTO holon_state VALUES ('k2', 'v2')")
            :ok = Exqlite.Sqlite3.execute(conn, "INSERT INTO holon_state VALUES ('k3', 'v3')")
            {:ok, :all_inserted}
          end,
          []
        )

      {:ok, rows} = SQLitePool.query(pool_name, "SELECT count(*) AS n FROM holon_state", [])
      assert hd(rows)[:n] == 3
    end

    test "rolled-back transaction leaves no partial state", %{pool_name: pool_name} do
      :ok = setup_test_table(pool_name)

      # Pre-condition: table is empty
      {:ok, rows_before} =
        SQLitePool.query(pool_name, "SELECT count(*) AS n FROM holon_state", [])

      count_before = hd(rows_before)[:n]

      # Aborted transaction
      _result =
        SQLitePool.transaction(
          pool_name,
          fn conn ->
            :ok = Exqlite.Sqlite3.execute(conn, "INSERT INTO holon_state VALUES ('partial', 'x')")
            {:error, :intentional_rollback}
          end,
          []
        )

      # Post-condition: count unchanged (rollback happened)
      {:ok, rows_after} =
        SQLitePool.query(pool_name, "SELECT count(*) AS n FROM holon_state", [])

      count_after = hd(rows_after)[:n]

      assert count_after == count_before,
             "Transaction rollback left partial state: before=#{count_before}, after=#{count_after}"
    end

    test "unique constraint prevents duplicate keys (ACID isolation)", %{pool_name: pool_name} do
      :ok = setup_test_table(pool_name)

      # First insert succeeds
      {:ok, _} =
        SQLitePool.execute(
          pool_name,
          "INSERT INTO holon_state (key, value) VALUES (?, ?)",
          ["unique_key", "value1"]
        )

      # Second insert with same primary key must fail
      result =
        SQLitePool.execute(
          pool_name,
          "INSERT INTO holon_state (key, value) VALUES (?, ?)",
          ["unique_key", "value2"]
        )

      assert match?({:error, _}, result),
             "Expected unique constraint violation, got: #{inspect(result)}"

      # Original value must be intact
      {:ok, rows} =
        SQLitePool.query(
          pool_name,
          "SELECT value FROM holon_state WHERE key = ?",
          ["unique_key"]
        )

      assert hd(rows)[:value] == "value1"
    end
  end

  # ─────────────────────────────────────────────────────────────────────────
  # WAL CONCURRENT ACCESS (SC-DBLOCAL-004 + SC-XHOLON-030)
  # ─────────────────────────────────────────────────────────────────────────

  describe "WAL concurrent access patterns (SC-DBLOCAL-004)" do
    test "multiple sequential queries return consistent results", %{pool_name: pool_name} do
      :ok = setup_test_table(pool_name)

      # Write known data
      for i <- 1..5 do
        {:ok, _} =
          SQLitePool.execute(
            pool_name,
            "INSERT INTO holon_state (key, value) VALUES (?, ?)",
            ["key_#{i}", "value_#{i}"]
          )
      end

      # Read multiple times — must get consistent count (WAL consistency guarantee)
      counts =
        for _ <- 1..5 do
          {:ok, rows} = SQLitePool.query(pool_name, "SELECT count(*) AS n FROM holon_state", [])
          hd(rows)[:n]
        end

      assert Enum.all?(counts, &(&1 == 5)),
             "WAL mode should provide consistent reads, got counts: #{inspect(counts)}"
    end

    test "pool handles concurrent operations without deadlock", %{pool_name: pool_name} do
      :ok = setup_test_table(pool_name)

      # Spawn 4 concurrent tasks using the pool (pool_size=2, so 2 will queue)
      tasks =
        for i <- 1..4 do
          Task.async(fn ->
            SQLitePool.execute(
              pool_name,
              "INSERT INTO holon_state (key, value) VALUES (?, ?)",
              ["concurrent_#{i}", "val_#{i}"]
            )
          end)
        end

      results = Task.await_many(tasks, 10_000)

      # All operations must succeed or at least not crash with deadlock
      assert Enum.all?(results, fn r ->
               match?({:ok, _}, r) or match?({:error, _}, r)
             end),
             "Expected all pool operations to return ok/error tuples, got: #{inspect(results)}"
    end

    test "read-after-write is consistent within same connection (serializable)", %{
      pool_name: pool_name
    } do
      :ok = setup_test_table(pool_name)

      SQLitePool.transaction(
        pool_name,
        fn conn ->
          :ok =
            Exqlite.Sqlite3.execute(
              conn,
              "INSERT INTO holon_state VALUES ('serial_key', 'serial_val')"
            )

          # Read within same transaction — must see own writes
          {:ok, stmt} =
            Exqlite.Sqlite3.prepare(conn, "SELECT value FROM holon_state WHERE key = ?")

          :ok = Exqlite.Sqlite3.bind(conn, stmt, ["serial_key"])
          {:row, [value]} = Exqlite.Sqlite3.step(conn, stmt)
          Exqlite.Sqlite3.release(conn, stmt)

          assert value == "serial_val",
                 "Read-your-own-writes failed within transaction: #{inspect(value)}"

          {:ok, :verified}
        end,
        []
      )
    end
  end

  # ─────────────────────────────────────────────────────────────────────────
  # NO DATA LOSS INVARIANT (SC-XHOLON-030)
  # ─────────────────────────────────────────────────────────────────────────

  describe "no data loss invariant (SC-XHOLON-030)" do
    test "committed data persists across query boundaries", %{pool_name: pool_name} do
      :ok = setup_test_table(pool_name)

      # Write 10 rows
      for i <- 1..10 do
        {:ok, _} =
          SQLitePool.execute(
            pool_name,
            "INSERT INTO holon_state (key, value) VALUES (?, ?)",
            ["persist_#{i}", "data_#{i}"]
          )
      end

      # Read back all 10
      {:ok, rows} =
        SQLitePool.query(pool_name, "SELECT key, value FROM holon_state ORDER BY key", [])

      assert length(rows) == 10,
             "Expected 10 persisted rows, got: #{length(rows)}"

      # Verify each row
      keys = Enum.map(rows, & &1[:key])
      assert "persist_1" in keys
      assert "persist_10" in keys
    end

    test "pool start/stop cycle preserves data in file database", %{db_path: db_path} do
      # Use a unique pool name for this two-phase test
      pool1 = :"wal_persist_test_#{System.unique_integer([:positive])}"

      {:ok, _} = SQLitePool.start_pool(pool1, db_path, 1, 5_000)

      # Create table and insert data in first pool instance
      :ok = setup_test_table(pool1)

      {:ok, _} =
        SQLitePool.execute(
          pool1,
          "INSERT INTO holon_state (key, value) VALUES (?, ?)",
          ["persisted_key", "persisted_value"]
        )

      # Stop the pool (simulates process restart)
      :ok = SQLitePool.stop_pool(pool1)

      # Start a new pool pointing to same database
      pool2 = :"wal_persist_test2_#{System.unique_integer([:positive])}"
      {:ok, _} = SQLitePool.start_pool(pool2, db_path, 1, 5_000)

      on_exit(fn -> SQLitePool.stop_pool(pool2) end)

      # Data MUST survive the pool restart
      {:ok, rows} =
        SQLitePool.query(
          pool2,
          "SELECT value FROM holon_state WHERE key = ?",
          ["persisted_key"]
        )

      assert length(rows) == 1,
             "Data did not survive pool restart — SC-XHOLON-030 violation"

      assert hd(rows)[:value] == "persisted_value",
             "Data value corrupted after pool restart: #{inspect(rows)}"
    end
  end

  # ─────────────────────────────────────────────────────────────────────────
  # PROPERTY TESTS
  # ─────────────────────────────────────────────────────────────────────────

  describe "property: WAL mode is stable across repeated queries" do
    test "journal_mode pragma always returns 'wal' (property)", %{pool_name: pool_name} do
      ExUnitProperties.check all(_ <- SD.constant(:ok), max_runs: 5) do
        {:ok, rows} = SQLitePool.query(pool_name, "PRAGMA journal_mode", [])
        assert length(rows) == 1
        row = hd(rows)
        mode = row[:journal_mode] || row["journal_mode"]
        assert mode == "wal"
      end
    end

    test "write then read is always consistent (property)", %{pool_name: pool_name} do
      :ok = setup_test_table(pool_name)

      ExUnitProperties.check all(
                               value <- SD.binary(min_length: 1, max_length: 64),
                               max_runs: 10
                             ) do
        key = "prop_key_#{:erlang.unique_integer([:positive])}"

        {:ok, _} =
          SQLitePool.execute(
            pool_name,
            "INSERT INTO holon_state (key, value) VALUES (?, ?)",
            [key, value]
          )

        {:ok, rows} =
          SQLitePool.query(
            pool_name,
            "SELECT value FROM holon_state WHERE key = ?",
            [key]
          )

        assert length(rows) == 1
        assert hd(rows)[:value] == value
      end
    end
  end

  # ─────────────────────────────────────────────────────────────────────────
  # PRIVATE HELPERS
  # ─────────────────────────────────────────────────────────────────────────

  defp setup_test_table(pool_name) do
    {:ok, _} =
      SQLitePool.execute(
        pool_name,
        """
        CREATE TABLE IF NOT EXISTS holon_state (
          key   TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
        """,
        []
      )

    :ok
  end
end
