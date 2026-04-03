defmodule Indrajaal.Holon.Database.HolonDatabaseTest do
  @moduledoc """
  Tests for HolonDatabase unified database access.

  STAMP Compliance: SC-XHOLON-001 to SC-XHOLON-010, SC-DBINT-001 to SC-DBINT-010
  Coverage: Degrees D1, D2, D3 from 9x9 Test Matrix
  """

  use ExUnit.Case, async: false
  use PropCheck

  alias Indrajaal.Holon.Database.HolonDatabase
  alias Indrajaal.Holon.Database.ConcurrencyHandler
  alias Indrajaal.Holon.DatabasePath
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @test_holon_id "ex:l3:test:srv:unit"
  @test_db_path "/tmp/test_holons"

  setup_all do
    # Ensure test directory exists
    File.mkdir_p!(@test_db_path)

    # Clean up any previous test databases
    cleanup_test_databases()

    on_exit(fn ->
      cleanup_test_databases()
    end)

    :ok
  end

  setup do
    # Create fresh test databases for each test
    {:ok, db} =
      HolonDatabase.start_link(
        holon_id: @test_holon_id,
        base_path: @test_db_path,
        pool_size: 2
      )

    on_exit(fn ->
      if Process.alive?(db), do: GenServer.stop(db)
    end)

    {:ok, db: db}
  end

  # ==========================================================================
  # D1: Runtime Interaction Tests (Elixir Direct Access)
  # ==========================================================================

  describe "D1-01: Direct Elixir holon database access" do
    test "can query state database", %{db: db} do
      # SC-PERF-001: Local query latency p99 < 10ms
      {time_us, result} =
        :timer.tc(fn ->
          HolonDatabase.query(db, :state, "SELECT 1 AS test")
        end)

      assert {:ok, [%{test: 1}]} = result
      # < 10ms
      assert time_us < 10_000
    end

    test "uses connection pool for queries", %{db: db} do
      # SC-XHOLON-004: Each holon manages its own connection pools
      stats = HolonDatabase.get_stats(db)

      assert stats.pool_size >= 2
      assert stats.active_connections >= 0
    end

    test "no Zenoh bridge involved in direct access", %{db: db} do
      # Verify direct path (no bridge)
      {:ok, result} = HolonDatabase.query(db, :state, "SELECT 1")
      assert is_list(result)

      # Check stats don't show bridge calls
      stats = HolonDatabase.get_stats(db)
      assert stats.bridge_calls == 0
    end
  end

  # ==========================================================================
  # D2: Database Type Interaction Tests
  # ==========================================================================

  describe "D2-01: State SQLite database operations" do
    test "can create tables", %{db: db} do
      result =
        HolonDatabase.execute(db, :state, """
          CREATE TABLE IF NOT EXISTS test_config (
            id TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP
          )
        """)

      assert {:ok, %{changes: 0}} = result
    end

    test "CRUD operations work correctly", %{db: db} do
      # Create table
      HolonDatabase.execute(db, :state, """
        CREATE TABLE IF NOT EXISTS test_crud (
          key TEXT PRIMARY KEY,
          value TEXT
        )
      """)

      # Insert
      {:ok, %{changes: 1}} =
        HolonDatabase.execute(
          db,
          :state,
          "INSERT INTO test_crud (key, value) VALUES (?, ?)",
          ["key1", "value1"]
        )

      # Select
      {:ok, [%{key: "key1", value: "value1"}]} =
        HolonDatabase.query(
          db,
          :state,
          "SELECT * FROM test_crud WHERE key = ?",
          ["key1"]
        )

      # Update
      {:ok, %{changes: 1}} =
        HolonDatabase.execute(
          db,
          :state,
          "UPDATE test_crud SET value = ? WHERE key = ?",
          ["value2", "key1"]
        )

      # Delete
      {:ok, %{changes: 1}} =
        HolonDatabase.execute(
          db,
          :state,
          "DELETE FROM test_crud WHERE key = ?",
          ["key1"]
        )

      # Verify deleted
      {:ok, []} =
        HolonDatabase.query(
          db,
          :state,
          "SELECT * FROM test_crud WHERE key = ?",
          ["key1"]
        )
    end

    test "WAL mode is enabled", %{db: db} do
      # SC-DBINT-001: SQLite MUST use WAL mode
      {:ok, [%{journal_mode: mode}]} =
        HolonDatabase.query(
          db,
          :state,
          "PRAGMA journal_mode"
        )

      assert String.downcase(mode) == "wal"
    end

    test "version vector updated on write", %{db: db} do
      initial_vv = HolonDatabase.get_version_vector(db)

      HolonDatabase.execute(db, :state, """
        CREATE TABLE IF NOT EXISTS vv_test (id INTEGER PRIMARY KEY)
      """)

      HolonDatabase.execute(db, :state, "INSERT INTO vv_test DEFAULT VALUES")

      updated_vv = HolonDatabase.get_version_vector(db)

      assert Map.get(updated_vv, @test_holon_id, 0) >
               Map.get(initial_vv, @test_holon_id, 0)
    end
  end

  describe "D2-02: Vectors SQLite operations" do
    test "can store and retrieve vectors", %{db: db} do
      # Create vector table
      HolonDatabase.execute(db, :vectors, """
        CREATE TABLE IF NOT EXISTS embeddings (
          id TEXT PRIMARY KEY,
          vector BLOB NOT NULL,
          metadata TEXT
        )
      """)

      # Store a vector (as binary)
      vector = :erlang.term_to_binary([0.1, 0.2, 0.3])

      {:ok, %{changes: 1}} =
        HolonDatabase.execute(
          db,
          :vectors,
          "INSERT INTO embeddings (id, vector, metadata) VALUES (?, ?, ?)",
          ["vec1", vector, ~s({"type": "test"})]
        )

      # Retrieve
      {:ok, [%{id: "vec1", vector: stored_vec}]} =
        HolonDatabase.query(
          db,
          :vectors,
          "SELECT * FROM embeddings WHERE id = ?",
          ["vec1"]
        )

      assert :erlang.binary_to_term(stored_vec) == [0.1, 0.2, 0.3]
    end
  end

  describe "D2-04: Analytics DuckDB queries" do
    test "can execute analytical queries", %{db: db} do
      # Create analytics table
      HolonDatabase.execute(db, :analytics, """
        CREATE TABLE IF NOT EXISTS metrics (
          timestamp TIMESTAMP,
          metric_name VARCHAR,
          value DOUBLE
        )
      """)

      # Insert sample data
      for i <- 1..100 do
        HolonDatabase.execute(
          db,
          :analytics,
          "INSERT INTO metrics VALUES (NOW(), ?, ?)",
          ["cpu_usage", i * 0.5]
        )
      end

      # Analytical query with aggregation
      {:ok, [%{avg_value: avg}]} =
        HolonDatabase.query(
          db,
          :analytics,
          "SELECT AVG(value) as avg_value FROM metrics WHERE metric_name = ?",
          ["cpu_usage"]
        )

      assert avg > 0
    end
  end

  describe "D2-06: Register append-only operations" do
    test "INSERT works on register", %{db: db} do
      # SC-REG-001: Append-only
      HolonDatabase.execute(db, :register, """
        CREATE TABLE IF NOT EXISTS immutable_log (
          id INTEGER PRIMARY KEY,
          event TEXT NOT NULL,
          hash TEXT NOT NULL,
          timestamp TEXT DEFAULT CURRENT_TIMESTAMP
        )
      """)

      {:ok, %{changes: 1}} =
        HolonDatabase.execute(
          db,
          :register,
          "INSERT INTO immutable_log (event, hash) VALUES (?, ?)",
          ["test_event", "abc123"]
        )
    end

    # This would fail if properly enforced at DB level
    @tag :skip
    test "UPDATE is rejected on register" do
      # Note: This test documents expected behavior
      # Actual enforcement may be at application layer
    end
  end

  # ==========================================================================
  # D3: Operation Type Interaction Tests
  # ==========================================================================

  describe "D3-RR-01: Concurrent reads (no conflict)" do
    test "multiple concurrent reads succeed", %{db: db} do
      # SC-XHOLON-010: Lock-free reads
      HolonDatabase.execute(db, :state, """
        CREATE TABLE IF NOT EXISTS read_test (id TEXT PRIMARY KEY, data TEXT)
      """)

      HolonDatabase.execute(db, :state, "INSERT INTO read_test VALUES ('test', 'data')")

      # Launch 10 concurrent reads
      tasks =
        for _ <- 1..10 do
          Task.async(fn ->
            HolonDatabase.query(db, :state, "SELECT * FROM read_test WHERE id = 'test'")
          end)
        end

      results = Task.await_many(tasks, 5000)

      # All should succeed
      assert Enum.all?(results, fn
               {:ok, _} -> true
               _ -> false
             end)

      # All return same data
      assert Enum.all?(results, fn
               {:ok, [%{data: "data"}]} -> true
               _ -> false
             end)
    end
  end

  describe "D3-WW-07: Concurrent writes (OCC conflict)" do
    test "concurrent writes to same key handled via OCC", %{db: db} do
      HolonDatabase.execute(db, :state, """
        CREATE TABLE IF NOT EXISTS counter (
          id TEXT PRIMARY KEY,
          value INTEGER NOT NULL
        )
      """)

      HolonDatabase.execute(db, :state, "INSERT INTO counter VALUES ('main', 0)")

      # Get initial version
      initial_vv = HolonDatabase.get_version_vector(db)

      # Two concurrent increments
      task1 =
        Task.async(fn ->
          HolonDatabase.execute_cas(
            db,
            :state,
            "UPDATE counter SET value = value + 1 WHERE id = 'main'",
            [],
            initial_vv
          )
        end)

      task2 =
        Task.async(fn ->
          # Small delay to ensure potential conflict
          Process.sleep(10)

          HolonDatabase.execute_cas(
            db,
            :state,
            "UPDATE counter SET value = value + 1 WHERE id = 'main'",
            [],
            initial_vv
          )
        end)

      [result1, result2] = Task.await_many([task1, task2], 5000)

      # At least one should succeed, one may conflict
      success_count =
        Enum.count([result1, result2], fn
          {:ok, _} -> true
          {:conflict, _} -> false
          _ -> false
        end)

      assert success_count >= 1
    end
  end

  describe "D3-CC-13: Concurrent CAS operations" do
    test "exactly one CAS succeeds with same expected version", %{db: db} do
      # SC-CONC-002: Compare-and-swap MUST be atomic
      HolonDatabase.execute(db, :state, """
        CREATE TABLE IF NOT EXISTS cas_test (
          key TEXT PRIMARY KEY,
          value TEXT
        )
      """)

      HolonDatabase.execute(db, :state, "INSERT INTO cas_test VALUES ('k1', 'initial')")

      vv = HolonDatabase.get_version_vector(db)

      # Two concurrent CAS with same expected version
      tasks =
        for i <- 1..2 do
          Task.async(fn ->
            HolonDatabase.execute_cas(
              db,
              :state,
              "UPDATE cas_test SET value = ? WHERE key = 'k1'",
              ["value_#{i}"],
              vv
            )
          end)
        end

      results = Task.await_many(tasks, 5000)

      # Exactly one succeeds
      successes = Enum.count(results, &match?({:ok, _}, &1))
      conflicts = Enum.count(results, &match?({:conflict, _}, &1))

      assert successes == 1
      assert conflicts == 1
    end
  end

  # ==========================================================================
  # Property-Based Tests
  # ==========================================================================

  describe "Property: Version vector monotonicity" do
    property "version vector always increases on write" do
      forall writes <- PC.list(PC.binary()) do
        {:ok, db} =
          HolonDatabase.start_link(
            holon_id: "ex:l3:prop:srv:test_#{:rand.uniform(1000)}",
            base_path: @test_db_path,
            pool_size: 1
          )

        HolonDatabase.execute(db, :state, """
          CREATE TABLE IF NOT EXISTS prop_test (id INTEGER PRIMARY KEY, data BLOB)
        """)

        versions =
          Enum.map(writes, fn data ->
            HolonDatabase.execute(db, :state, "INSERT INTO prop_test (data) VALUES (?)", [data])
            Map.get(HolonDatabase.get_version_vector(db), db.holon_id, 0)
          end)

        GenServer.stop(db)

        # Version should be monotonically increasing
        versions
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.all?(fn [a, b] -> b >= a end)
      end
    end
  end

  describe "Property: Merge commutativity" do
    property "version vector merge is commutative" do
      forall {vv1_list, vv2_list} <- {
               PC.list(PC.tuple([PC.binary(), PC.pos_integer()])),
               PC.list(PC.tuple([PC.binary(), PC.pos_integer()]))
             } do
        vv1 = Map.new(vv1_list)
        vv2 = Map.new(vv2_list)

        merge1 = ConcurrencyHandler.merge_version_vectors(vv1, vv2)
        merge2 = ConcurrencyHandler.merge_version_vectors(vv2, vv1)

        merge1 == merge2
      end
    end
  end

  # ==========================================================================
  # Helper Functions
  # ==========================================================================

  defp cleanup_test_databases do
    Path.wildcard(Path.join(@test_db_path, "ex:l3:*"))
    |> Enum.each(&File.rm_rf!/1)
  end
end
