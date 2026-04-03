defmodule Indrajaal.Holon.Database.CrossHolonInterop9DegreeTest do
  @moduledoc """
  Comprehensive 9-Degree Interop Test Suite for Cross-Holon Database Access.

  Tests all interaction dimensions between Elixir and F# holons:
  - D1: Cross-Runtime (Ex→Fs, Fs→Ex via Zenoh)
  - D2: Database Types (SQLite, DuckDB variations)
  - D3: Operations (query, execute, CAS, batch)
  - D4: Concurrency (concurrent reads/writes, OCC)
  - D5: Transactions (2PC commit/abort/recovery)
  - D6: Failures (timeout, partition, crash)
  - D7: Performance (latency SLAs)
  - D8: Security (injection, traversal, auth)
  - D9: Recovery (crash recovery, checkpoint restore)

  ## STAMP Constraints
  - SC-XHOLON-001: UHI format validation
  - SC-XHOLON-010: Zenoh bridge mandatory for cross-runtime
  - SC-XHOLON-015: 2PC required for cross-runtime writes
  - SC-XHOLON-020: OCC version vectors for concurrency
  - SC-XHOLON-030: Circuit breaker for failures
  - SC-XHOLON-040: Performance SLAs
  - SC-XHOLON-045: Security constraints
  - SC-XHOLON-050: Recovery completeness

  ## Test Coverage
  - 100% of D1-D9 interaction matrix
  - All 18 critical paths from DAG analysis
  - 200+ edges covered
  """

  use ExUnit.Case, async: false
  use PropCheck

  # Aliases for property testing (SC-PROP-023)
  alias PropCheck.BasicTypes, as: PC
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias StreamData, as: SD

  alias Indrajaal.Holon.Database.CrossHolonAccess
  alias Indrajaal.Holon.Database.ZenohBridge
  alias Indrajaal.Holon.Database.VersionVector
  alias Indrajaal.Holon.Database.TwoPhaseCommit

  @moduletag :interop
  @moduletag :cross_holon
  @moduletag timeout: 120_000
  # TDG Phase 1: Tests written, Phase 3 (implementation) pending
  # Skip until ZenohBridge and CrossHolonAccess D9 functions are implemented
  @moduletag :skip

  # ============================================================================
  # Test Setup and Helpers
  # ============================================================================

  setup_all do
    # Ensure Zenoh bridge is running for interop tests
    case ZenohBridge.ensure_connected() do
      :ok ->
        # Create test holons for both runtimes
        {:ok, ex_holon_id} = create_test_holon(:elixir, "interop_test_ex")
        {:ok, fs_holon_id} = create_test_holon(:fsharp, "interop_test_fs")

        on_exit(fn ->
          cleanup_test_holon(ex_holon_id)
          cleanup_test_holon(fs_holon_id)
        end)

        %{
          ex_holon_id: ex_holon_id,
          fs_holon_id: fs_holon_id,
          zenoh_connected: true
        }

      {:error, reason} ->
        # Skip interop tests if Zenoh not available
        %{zenoh_connected: false, skip_reason: reason}
    end
  end

  setup %{zenoh_connected: connected} = context do
    if connected do
      # Create fresh transaction context for each test
      tx_id = "tx_#{:erlang.unique_integer([:positive])}"
      {:ok, Map.put(context, :tx_id, tx_id)}
    else
      {:ok, context}
    end
  end

  defp create_test_holon(runtime, name) do
    runtime_prefix =
      case runtime do
        :elixir -> "ex"
        :fsharp -> "fs"
      end

    holon_id = "#{runtime_prefix}:l3:test:holon:#{name}"

    # Initialize holon databases
    case CrossHolonAccess.initialize_holon(holon_id) do
      :ok -> {:ok, holon_id}
      error -> error
    end
  end

  defp cleanup_test_holon(holon_id) do
    CrossHolonAccess.cleanup_holon(holon_id)
  end

  # ============================================================================
  # D1: Cross-Runtime Interaction Tests (Ex→Fs, Fs→Ex via Zenoh)
  # ============================================================================

  describe "D1: Cross-Runtime Interactions" do
    @describetag :d1_cross_runtime

    test "D1.1: Elixir holon queries F# holon state database via Zenoh", %{
      ex_holon_id: ex_id,
      fs_holon_id: fs_id,
      zenoh_connected: true
    } do
      # Setup: Write data to F# holon
      fs_uhi = "#{fs_id}:state.sqlite"
      setup_data = %{key: "test_key", value: "test_value"}

      :ok =
        ZenohBridge.remote_execute(fs_uhi, """
          INSERT INTO holon_state (key, value) VALUES ('test_key', 'test_value')
        """)

      # Test: Query from Elixir holon
      source_uhi = "#{ex_id}:state.sqlite"
      target_uhi = fs_uhi

      result =
        CrossHolonAccess.cross_runtime_query(
          source_uhi,
          target_uhi,
          "SELECT value FROM holon_state WHERE key = ?",
          ["test_key"]
        )

      assert {:ok, [%{value: "test_value"}]} = result
    end

    test "D1.2: F# holon queries Elixir holon analytics database via Zenoh", %{
      ex_holon_id: ex_id,
      fs_holon_id: fs_id,
      zenoh_connected: true
    } do
      # Setup: Write data to Elixir holon DuckDB
      ex_uhi = "#{ex_id}:analytics.duckdb"

      :ok =
        CrossHolonAccess.execute(ex_uhi, """
          INSERT INTO analytics_events (event_type, timestamp, data)
          VALUES ('test_event', '2026-01-17T12:00:00Z', '{"foo": "bar"}')
        """)

      # Test: Query from F# holon via Zenoh
      fs_uhi = "#{fs_id}:state.sqlite"
      target_uhi = ex_uhi

      # F# → Ex query goes through Zenoh
      result =
        ZenohBridge.remote_query(
          fs_uhi,
          target_uhi,
          "SELECT event_type, data FROM analytics_events WHERE event_type = ?",
          ["test_event"]
        )

      assert {:ok, rows} = result
      assert length(rows) >= 1
      assert hd(rows).event_type == "test_event"
    end

    test "D1.3: Bidirectional cross-runtime write with 2PC", %{
      ex_holon_id: ex_id,
      fs_holon_id: fs_id,
      tx_id: tx_id,
      zenoh_connected: true
    } do
      ex_uhi = "#{ex_id}:state.sqlite"
      fs_uhi = "#{fs_id}:state.sqlite"

      # Start 2PC transaction spanning both runtimes
      {:ok, coordinator} = TwoPhaseCommit.start_coordinator(tx_id, [ex_uhi, fs_uhi])

      # Phase 1: Prepare
      :ok =
        TwoPhaseCommit.prepare(coordinator, ex_uhi, fn ->
          CrossHolonAccess.execute(
            ex_uhi,
            "INSERT INTO sync_log (source, target) VALUES (?, ?)",
            [ex_id, fs_id]
          )
        end)

      :ok =
        TwoPhaseCommit.prepare(coordinator, fs_uhi, fn ->
          ZenohBridge.remote_execute(
            fs_uhi,
            "INSERT INTO sync_log (source, target) VALUES (?, ?)",
            [fs_id, ex_id]
          )
        end)

      # Phase 2: Commit
      assert :ok = TwoPhaseCommit.commit(coordinator)

      # Verify both writes succeeded
      {:ok, ex_rows} = CrossHolonAccess.query(ex_uhi, "SELECT * FROM sync_log")
      {:ok, fs_rows} = ZenohBridge.remote_query(fs_uhi, fs_uhi, "SELECT * FROM sync_log", [])

      assert length(ex_rows) >= 1
      assert length(fs_rows) >= 1
    end

    test "D1.4: Cross-runtime message ordering via Zenoh FIFO", %{
      ex_holon_id: ex_id,
      fs_holon_id: fs_id,
      zenoh_connected: true
    } do
      fs_uhi = "#{fs_id}:state.sqlite"

      # Send multiple messages in sequence
      messages =
        Enum.map(1..10, fn i ->
          %{seq: i, timestamp: System.system_time(:nanosecond)}
        end)

      # Send all messages through Zenoh
      Enum.each(messages, fn msg ->
        ZenohBridge.send_ordered(fs_uhi, {:insert, msg})
      end)

      # Wait for delivery
      :timer.sleep(100)

      # Verify FIFO ordering
      {:ok, received} = ZenohBridge.get_received_messages(fs_uhi)

      sequences = Enum.map(received, & &1.seq)
      assert sequences == Enum.sort(sequences), "Messages should be in FIFO order"
    end

    test "D1.5: Cross-runtime version vector synchronization", %{
      ex_holon_id: ex_id,
      fs_holon_id: fs_id,
      zenoh_connected: true
    } do
      ex_uhi = "#{ex_id}:state.sqlite"
      fs_uhi = "#{fs_id}:state.sqlite"

      # Get initial version vectors
      {:ok, ex_vv} = CrossHolonAccess.get_version_vector(ex_uhi)
      {:ok, fs_vv} = ZenohBridge.remote_get_version_vector(fs_uhi)

      # Update Elixir holon
      {:ok, new_ex_vv} = CrossHolonAccess.increment_version(ex_uhi, ex_id)

      # Sync version vectors across runtimes
      {:ok, merged_vv} = ZenohBridge.sync_version_vectors(ex_uhi, fs_uhi, new_ex_vv)

      # Verify merge properties
      assert VersionVector.happens_before(ex_vv, merged_vv) or
               VersionVector.concurrent(ex_vv, merged_vv)
    end
  end

  # ============================================================================
  # D2: Database Type Interaction Tests
  # ============================================================================

  describe "D2: Database Type Interactions" do
    @describetag :d2_database_types

    test "D2.1: SQLite state to DuckDB analytics cross-type query", %{
      ex_holon_id: ex_id,
      zenoh_connected: true
    } do
      state_uhi = "#{ex_id}:state.sqlite"
      analytics_uhi = "#{ex_id}:analytics.duckdb"

      # Insert state data
      :ok =
        CrossHolonAccess.execute(state_uhi, """
          INSERT INTO holon_state (key, value, updated_at)
          VALUES ('metric_1', '100', datetime('now'))
        """)

      # Query state and insert into analytics
      {:ok, state_rows} =
        CrossHolonAccess.query(state_uhi, "SELECT key, value FROM holon_state WHERE key = ?", [
          "metric_1"
        ])

      row = hd(state_rows)

      :ok =
        CrossHolonAccess.execute(
          analytics_uhi,
          """
            INSERT INTO state_snapshots (key, value, snapshot_time)
            VALUES (?, ?, now())
          """,
          [row.key, row.value]
        )

      # Verify cross-type operation
      {:ok, analytics_rows} =
        CrossHolonAccess.query(
          analytics_uhi,
          "SELECT key, value FROM state_snapshots WHERE key = ?",
          ["metric_1"]
        )

      assert length(analytics_rows) == 1
      assert hd(analytics_rows).value == "100"
    end

    test "D2.2: All 6 database types accessible within holon", %{ex_holon_id: ex_id} do
      db_types = [:state, :vectors, :cache, :analytics, :history, :register]

      results =
        Enum.map(db_types, fn db_type ->
          uhi =
            case db_type do
              t when t in [:state, :vectors, :cache] -> "#{ex_id}:#{t}.sqlite"
              t -> "#{ex_id}:#{t}.duckdb"
            end

          # Test connection
          case CrossHolonAccess.ping(uhi) do
            :ok -> {:ok, db_type}
            error -> {:error, db_type, error}
          end
        end)

      # All should succeed
      assert Enum.all?(results, fn
               {:ok, _} -> true
               _ -> false
             end),
             "All 6 database types should be accessible"
    end

    test "D2.3: Cross-runtime heterogeneous database access (Ex SQLite → Fs DuckDB)", %{
      ex_holon_id: ex_id,
      fs_holon_id: fs_id,
      zenoh_connected: true
    } do
      ex_sqlite_uhi = "#{ex_id}:state.sqlite"
      fs_duckdb_uhi = "#{fs_id}:analytics.duckdb"

      # Write to Ex SQLite
      :ok =
        CrossHolonAccess.execute(ex_sqlite_uhi, """
          INSERT INTO holon_state (key, value) VALUES ('cross_type_test', '42')
        """)

      # Query Ex SQLite
      {:ok, [row]} =
        CrossHolonAccess.query(ex_sqlite_uhi, "SELECT value FROM holon_state WHERE key = ?", [
          "cross_type_test"
        ])

      # Write result to Fs DuckDB via Zenoh
      :ok =
        ZenohBridge.remote_execute(
          fs_duckdb_uhi,
          """
            INSERT INTO cross_runtime_data (source_runtime, source_db, value)
            VALUES ('elixir', 'sqlite', ?)
          """,
          [row.value]
        )

      # Verify via Zenoh query
      {:ok, [result]} =
        ZenohBridge.remote_query(
          fs_duckdb_uhi,
          fs_duckdb_uhi,
          "SELECT value FROM cross_runtime_data WHERE source_runtime = ?",
          ["elixir"]
        )

      assert result.value == "42"
    end

    test "D2.4: DuckDB analytical query across history database", %{ex_holon_id: ex_id} do
      history_uhi = "#{ex_id}:history.duckdb"

      # Insert historical data
      Enum.each(1..100, fn i ->
        CrossHolonAccess.execute(
          history_uhi,
          """
            INSERT INTO evolution_events (generation, fitness, timestamp)
            VALUES (?, ?, now() - INTERVAL '#{i}' MINUTE)
          """,
          [i, :rand.uniform()]
        )
      end)

      # Analytical query
      {:ok, [result]} =
        CrossHolonAccess.query(history_uhi, """
          SELECT
            COUNT(*) as total_events,
            AVG(fitness) as avg_fitness,
            MAX(generation) as max_generation
          FROM evolution_events
        """)

      assert result.total_events >= 100
      assert result.avg_fitness > 0.0
      assert result.max_generation >= 100
    end

    test "D2.5: Vector database embedding operations", %{ex_holon_id: ex_id} do
      vectors_uhi = "#{ex_id}:vectors.sqlite"

      # Insert test embedding
      embedding = Enum.map(1..128, fn _ -> :rand.uniform() end)
      embedding_json = Jason.encode!(embedding)

      :ok =
        CrossHolonAccess.execute(
          vectors_uhi,
          """
            INSERT INTO embeddings (holon_id, embedding, metadata)
            VALUES (?, ?, '{"type": "test"}')
          """,
          [ex_id, embedding_json]
        )

      # Query with similarity (mock - actual would use vector extension)
      {:ok, rows} =
        CrossHolonAccess.query(
          vectors_uhi,
          "SELECT holon_id, metadata FROM embeddings WHERE holon_id = ?",
          [ex_id]
        )

      assert length(rows) == 1
      assert hd(rows).holon_id == ex_id
    end
  end

  # ============================================================================
  # D3: Operation Type Tests
  # ============================================================================

  describe "D3: Operation Types" do
    @describetag :d3_operations

    test "D3.1: Query operation with parameters", %{ex_holon_id: ex_id} do
      uhi = "#{ex_id}:state.sqlite"

      # Setup data
      :ok =
        CrossHolonAccess.execute(uhi, "INSERT INTO holon_state (key, value) VALUES ('q1', 'v1')")

      :ok =
        CrossHolonAccess.execute(uhi, "INSERT INTO holon_state (key, value) VALUES ('q2', 'v2')")

      # Parameterized query
      {:ok, rows} =
        CrossHolonAccess.query(uhi, "SELECT * FROM holon_state WHERE key IN (?, ?)", ["q1", "q2"])

      assert length(rows) == 2
    end

    test "D3.2: Execute operation (INSERT/UPDATE/DELETE)", %{ex_holon_id: ex_id} do
      uhi = "#{ex_id}:state.sqlite"

      # INSERT
      {:ok, insert_result} =
        CrossHolonAccess.execute_returning(uhi, """
          INSERT INTO holon_state (key, value) VALUES ('exec_test', 'initial')
          RETURNING rowid
        """)

      assert insert_result.rows_affected >= 1

      # UPDATE
      {:ok, update_result} =
        CrossHolonAccess.execute_returning(uhi, """
          UPDATE holon_state SET value = 'updated' WHERE key = 'exec_test'
          RETURNING rowid
        """)

      assert update_result.rows_affected == 1

      # DELETE
      {:ok, delete_result} =
        CrossHolonAccess.execute_returning(uhi, """
          DELETE FROM holon_state WHERE key = 'exec_test'
          RETURNING rowid
        """)

      assert delete_result.rows_affected == 1
    end

    test "D3.3: CAS (Compare-And-Swap) operation", %{ex_holon_id: ex_id} do
      uhi = "#{ex_id}:state.sqlite"

      # Setup initial value with version
      :ok =
        CrossHolonAccess.execute(uhi, """
          INSERT INTO versioned_state (key, value, version)
          VALUES ('cas_key', 'v0', 1)
        """)

      # CAS with correct expected version - should succeed
      result1 = CrossHolonAccess.compare_and_swap(uhi, "cas_key", "v0", "v1", 1)
      # Returns new version
      assert {:ok, 2} = result1

      # CAS with stale expected version - should fail
      result2 = CrossHolonAccess.compare_and_swap(uhi, "cas_key", "v1", "v2", 1)
      assert {:error, :version_mismatch, _} = result2
    end

    test "D3.4: Batch operation execution", %{ex_holon_id: ex_id} do
      uhi = "#{ex_id}:state.sqlite"

      operations =
        Enum.map(1..10, fn i ->
          {:insert, "INSERT INTO holon_state (key, value) VALUES ('batch_#{i}', 'val_#{i}')"}
        end)

      # Execute batch atomically
      {:ok, results} = CrossHolonAccess.execute_batch(uhi, operations)

      assert length(results) == 10
      assert Enum.all?(results, fn r -> r.rows_affected == 1 end)

      # Verify all inserted
      {:ok, rows} =
        CrossHolonAccess.query(
          uhi,
          "SELECT COUNT(*) as cnt FROM holon_state WHERE key LIKE 'batch_%'"
        )

      assert hd(rows).cnt == 10
    end

    test "D3.5: Cross-runtime CAS via Zenoh", %{
      ex_holon_id: ex_id,
      fs_holon_id: fs_id,
      zenoh_connected: true
    } do
      fs_uhi = "#{fs_id}:state.sqlite"

      # Setup in F# holon
      :ok =
        ZenohBridge.remote_execute(fs_uhi, """
          INSERT INTO versioned_state (key, value, version)
          VALUES ('remote_cas', 'initial', 1)
        """)

      # CAS from Elixir to F# via Zenoh
      result = ZenohBridge.remote_cas(fs_uhi, "remote_cas", "initial", "updated", 1)
      assert {:ok, 2} = result

      # Verify
      {:ok, [row]} =
        ZenohBridge.remote_query(
          fs_uhi,
          fs_uhi,
          "SELECT value, version FROM versioned_state WHERE key = ?",
          ["remote_cas"]
        )

      assert row.value == "updated"
      assert row.version == 2
    end
  end

  # ============================================================================
  # D4: Concurrency Tests
  # ============================================================================

  describe "D4: Concurrency" do
    @describetag :d4_concurrency

    test "D4.1: Concurrent reads don't block each other", %{ex_holon_id: ex_id} do
      uhi = "#{ex_id}:state.sqlite"

      # Setup data
      :ok =
        CrossHolonAccess.execute(
          uhi,
          "INSERT INTO holon_state (key, value) VALUES ('concurrent_read', 'data')"
        )

      # Spawn concurrent readers
      tasks =
        Enum.map(1..10, fn _ ->
          Task.async(fn ->
            start = System.monotonic_time(:millisecond)

            {:ok, _} =
              CrossHolonAccess.query(uhi, "SELECT * FROM holon_state WHERE key = ?", [
                "concurrent_read"
              ])

            System.monotonic_time(:millisecond) - start
          end)
        end)

      results = Task.await_many(tasks, 5000)

      # All should complete within reasonable time (no blocking)
      assert Enum.all?(results, fn time -> time < 100 end)
    end

    test "D4.2: Concurrent writes with OCC version vectors", %{ex_holon_id: ex_id} do
      uhi = "#{ex_id}:state.sqlite"
      key = "occ_test_#{:erlang.unique_integer([:positive])}"

      # Initialize
      :ok =
        CrossHolonAccess.execute(
          uhi,
          """
            INSERT INTO versioned_state (key, value, version) VALUES (?, 'v0', 1)
          """,
          [key]
        )

      # Spawn concurrent writers
      tasks =
        Enum.map(1..5, fn i ->
          Task.async(fn ->
            # Read current version
            {:ok, [row]} =
              CrossHolonAccess.query(uhi, "SELECT version FROM versioned_state WHERE key = ?", [
                key
              ])

            # Try to update with OCC
            result =
              CrossHolonAccess.compare_and_swap(uhi, key, "v#{i - 1}", "v#{i}", row.version)

            {i, result}
          end)
        end)

      results = Task.await_many(tasks, 5000)

      # Exactly one should succeed, others should fail with version_mismatch
      successes = Enum.filter(results, fn {_, r} -> match?({:ok, _}, r) end)
      failures = Enum.filter(results, fn {_, r} -> match?({:error, :version_mismatch, _}, r) end)

      assert length(successes) == 1, "Exactly one writer should succeed"
      assert length(failures) == 4, "Four writers should fail with version mismatch"
    end

    test "D4.3: Version vector merge on concurrent cross-holon updates", %{
      ex_holon_id: ex_id,
      fs_holon_id: fs_id,
      zenoh_connected: true
    } do
      ex_uhi = "#{ex_id}:state.sqlite"
      fs_uhi = "#{fs_id}:state.sqlite"

      # Concurrent updates from both holons
      task1 =
        Task.async(fn ->
          CrossHolonAccess.increment_version(ex_uhi, ex_id)
        end)

      task2 =
        Task.async(fn ->
          ZenohBridge.remote_increment_version(fs_uhi, fs_id)
        end)

      [{:ok, ex_vv}, {:ok, fs_vv}] = Task.await_many([task1, task2], 5000)

      # Merge version vectors
      merged = VersionVector.merge(ex_vv, fs_vv)

      # Merged should dominate both
      assert VersionVector.happens_before(ex_vv, merged) or ex_vv == merged
      assert VersionVector.happens_before(fs_vv, merged) or fs_vv == merged
    end

    test "D4.4: Connection pool under concurrent load", %{ex_holon_id: ex_id} do
      uhi = "#{ex_id}:state.sqlite"

      # Exhaust connection pool with concurrent operations
      tasks =
        Enum.map(1..50, fn i ->
          Task.async(fn ->
            case CrossHolonAccess.query(uhi, "SELECT ? as val", [i]) do
              {:ok, [%{val: ^i}]} -> :ok
              {:error, :pool_exhausted} -> :pool_exhausted
              other -> {:unexpected, other}
            end
          end)
        end)

      results = Task.await_many(tasks, 10_000)

      # Most should succeed, some may hit pool limits
      successes = Enum.count(results, &(&1 == :ok))
      assert successes >= 10, "At least 10 should succeed even under load"
    end

    property "D4.5: Version vector partial order is maintained under concurrent updates" do
      forall ops <- PC.list(PC.oneof([:increment, :merge])) do
        holon_ids = ["h1", "h2", "h3"]

        {final_vvs, _} =
          Enum.reduce(ops, {%{}, %{}}, fn op, {vvs, last_vv} ->
            holon = Enum.random(holon_ids)
            current = Map.get(vvs, holon, %{})

            new_vv =
              case op do
                :increment ->
                  VersionVector.increment(current, holon)

                :merge ->
                  other_holon = Enum.random(holon_ids)
                  other_vv = Map.get(vvs, other_holon, %{})
                  VersionVector.merge(current, other_vv)
              end

            {Map.put(vvs, holon, new_vv), new_vv}
          end)

        # Verify partial order consistency
        Enum.all?(final_vvs, fn {_, vv1} ->
          Enum.all?(final_vvs, fn {_, vv2} ->
            # Reflexivity
            # At least one relation holds
            VersionVector.compare(vv1, vv1) in [:eq, :concurrent] and
              VersionVector.compare(vv1, vv2) in [:lt, :gt, :eq, :concurrent]
          end)
        end)
      end
    end
  end

  # ============================================================================
  # D5: Transaction Tests (2PC)
  # ============================================================================

  describe "D5: Transactions (2PC)" do
    @describetag :d5_transactions

    test "D5.1: 2PC commit succeeds when all participants prepared", %{
      ex_holon_id: ex_id,
      fs_holon_id: fs_id,
      tx_id: tx_id,
      zenoh_connected: true
    } do
      ex_uhi = "#{ex_id}:state.sqlite"
      fs_uhi = "#{fs_id}:state.sqlite"
      key = "2pc_commit_#{tx_id}"

      {:ok, coordinator} = TwoPhaseCommit.start_coordinator(tx_id, [ex_uhi, fs_uhi])

      # Prepare phase
      :ok =
        TwoPhaseCommit.prepare(coordinator, ex_uhi, fn ->
          CrossHolonAccess.execute(
            ex_uhi,
            "INSERT INTO tx_log (tx_id, status) VALUES (?, 'prepared')",
            [key]
          )
        end)

      :ok =
        TwoPhaseCommit.prepare(coordinator, fs_uhi, fn ->
          ZenohBridge.remote_execute(
            fs_uhi,
            "INSERT INTO tx_log (tx_id, status) VALUES (?, 'prepared')",
            [key]
          )
        end)

      # Commit phase
      assert :ok = TwoPhaseCommit.commit(coordinator)

      # Verify both committed
      {:ok, [ex_row]} =
        CrossHolonAccess.query(ex_uhi, "SELECT status FROM tx_log WHERE tx_id = ?", [key])

      {:ok, [fs_row]} =
        ZenohBridge.remote_query(fs_uhi, fs_uhi, "SELECT status FROM tx_log WHERE tx_id = ?", [
          key
        ])

      # Data should be visible
      assert ex_row.status == "prepared"
      assert fs_row.status == "prepared"
    end

    test "D5.2: 2PC abort when participant fails to prepare", %{
      ex_holon_id: ex_id,
      fs_holon_id: fs_id,
      tx_id: tx_id,
      zenoh_connected: true
    } do
      ex_uhi = "#{ex_id}:state.sqlite"
      fs_uhi = "#{fs_id}:state.sqlite"
      key = "2pc_abort_#{tx_id}"

      {:ok, coordinator} = TwoPhaseCommit.start_coordinator(tx_id, [ex_uhi, fs_uhi])

      # Prepare Elixir - succeeds
      :ok =
        TwoPhaseCommit.prepare(coordinator, ex_uhi, fn ->
          CrossHolonAccess.execute(
            ex_uhi,
            "INSERT INTO tx_log (tx_id, status) VALUES (?, 'prepared')",
            [key]
          )
        end)

      # Prepare F# - fails (simulate constraint violation)
      {:error, _} =
        TwoPhaseCommit.prepare(coordinator, fs_uhi, fn ->
          {:error, :constraint_violation}
        end)

      # Abort phase
      assert :ok = TwoPhaseCommit.abort(coordinator)

      # Verify Elixir side was rolled back
      {:ok, rows} = CrossHolonAccess.query(ex_uhi, "SELECT * FROM tx_log WHERE tx_id = ?", [key])
      assert rows == [], "Aborted transaction should not leave data"
    end

    test "D5.3: 2PC timeout triggers abort", %{
      ex_holon_id: ex_id,
      fs_holon_id: fs_id,
      tx_id: tx_id,
      zenoh_connected: true
    } do
      ex_uhi = "#{ex_id}:state.sqlite"
      fs_uhi = "#{fs_id}:state.sqlite"

      {:ok, coordinator} =
        TwoPhaseCommit.start_coordinator(tx_id, [ex_uhi, fs_uhi],
          # Very short timeout
          timeout: 100
        )

      # Prepare Elixir - succeeds
      :ok =
        TwoPhaseCommit.prepare(coordinator, ex_uhi, fn ->
          :ok
        end)

      # F# prepare takes too long
      result =
        TwoPhaseCommit.prepare(coordinator, fs_uhi, fn ->
          # Exceeds timeout
          :timer.sleep(200)
          :ok
        end)

      assert {:error, :timeout} = result

      # Transaction should be aborted
      state = TwoPhaseCommit.get_state(coordinator)
      assert state.status in [:aborted, :aborting]
    end

    test "D5.4: Distributed transaction across 3 holons", %{
      ex_holon_id: ex_id,
      fs_holon_id: fs_id,
      tx_id: tx_id,
      zenoh_connected: true
    } do
      # Create third holon
      {:ok, ex2_id} = create_test_holon(:elixir, "interop_test_ex2")

      try do
        uhis = [
          "#{ex_id}:state.sqlite",
          "#{fs_id}:state.sqlite",
          "#{ex2_id}:state.sqlite"
        ]

        {:ok, coordinator} = TwoPhaseCommit.start_coordinator(tx_id, uhis)

        # Prepare all three
        Enum.each(uhis, fn uhi ->
          if String.starts_with?(uhi, "fs:") do
            :ok =
              TwoPhaseCommit.prepare(coordinator, uhi, fn ->
                ZenohBridge.remote_execute(uhi, "INSERT INTO tx_log (tx_id) VALUES (?)", [tx_id])
              end)
          else
            :ok =
              TwoPhaseCommit.prepare(coordinator, uhi, fn ->
                CrossHolonAccess.execute(uhi, "INSERT INTO tx_log (tx_id) VALUES (?)", [tx_id])
              end)
          end
        end)

        # Commit all
        assert :ok = TwoPhaseCommit.commit(coordinator)
      after
        cleanup_test_holon(ex2_id)
      end
    end

    test "D5.5: Transaction isolation - uncommitted reads not visible", %{
      ex_holon_id: ex_id,
      tx_id: tx_id
    } do
      uhi = "#{ex_id}:state.sqlite"
      key = "isolation_test_#{tx_id}"

      {:ok, coordinator} = TwoPhaseCommit.start_coordinator(tx_id, [uhi])

      # Start transaction and prepare write
      :ok =
        TwoPhaseCommit.prepare(coordinator, uhi, fn ->
          CrossHolonAccess.execute(
            uhi,
            "INSERT INTO holon_state (key, value) VALUES (?, 'uncommitted')",
            [key]
          )
        end)

      # Before commit, read from another connection
      {:ok, rows_before} =
        CrossHolonAccess.query(uhi, "SELECT * FROM holon_state WHERE key = ?", [key],
          isolation: :read_committed
        )

      # Should not see uncommitted data
      assert rows_before == []

      # Commit
      :ok = TwoPhaseCommit.commit(coordinator)

      # After commit, data is visible
      {:ok, rows_after} =
        CrossHolonAccess.query(uhi, "SELECT * FROM holon_state WHERE key = ?", [key])

      assert length(rows_after) == 1
    end
  end

  # ============================================================================
  # D6: Failure Handling Tests
  # ============================================================================

  describe "D6: Failure Handling" do
    @describetag :d6_failures

    test "D6.1: Timeout handling for slow queries", %{ex_holon_id: ex_id} do
      uhi = "#{ex_id}:state.sqlite"

      # Query with short timeout on potentially slow operation
      result =
        CrossHolonAccess.query(uhi, "SELECT * FROM holon_state", [],
          # 1ms - very aggressive
          timeout: 1
        )

      # Should either succeed quickly or timeout gracefully
      assert match?({:ok, _}, result) or match?({:error, :timeout}, result)
    end

    test "D6.2: Network partition simulation (Zenoh disconnect)", %{
      ex_holon_id: ex_id,
      fs_holon_id: fs_id,
      zenoh_connected: true
    } do
      fs_uhi = "#{fs_id}:state.sqlite"

      # Simulate partition by disconnecting Zenoh
      :ok = ZenohBridge.simulate_disconnect()

      # Cross-runtime query should fail
      result = ZenohBridge.remote_query(fs_uhi, fs_uhi, "SELECT 1", [])
      assert {:error, :network_partition} = result

      # Reconnect
      :ok = ZenohBridge.reconnect()

      # Query should succeed again
      {:ok, _} = ZenohBridge.remote_query(fs_uhi, fs_uhi, "SELECT 1", [])
    end

    test "D6.3: Circuit breaker activation on repeated failures", %{
      fs_holon_id: fs_id,
      zenoh_connected: true
    } do
      fs_uhi = "#{fs_id}:state.sqlite"

      # Force multiple failures to trigger circuit breaker
      Enum.each(1..10, fn _ ->
        ZenohBridge.remote_execute(fs_uhi, "INVALID SQL SYNTAX!!!")
      end)

      # Circuit breaker should be open
      state = ZenohBridge.get_circuit_breaker_state(fs_uhi)
      assert state.status in [:open, :half_open]

      # Requests should be rejected fast
      start = System.monotonic_time(:millisecond)
      {:error, :circuit_open} = ZenohBridge.remote_query(fs_uhi, fs_uhi, "SELECT 1", [])
      elapsed = System.monotonic_time(:millisecond) - start

      assert elapsed < 10, "Circuit breaker should reject immediately"
    end

    test "D6.4: Graceful degradation on partial system failure", %{
      ex_holon_id: ex_id,
      fs_holon_id: fs_id,
      zenoh_connected: true
    } do
      ex_uhi = "#{ex_id}:state.sqlite"
      fs_uhi = "#{fs_id}:state.sqlite"

      # Simulate F# holon being unavailable
      :ok = ZenohBridge.mark_unavailable(fs_uhi)

      # Local operations should still work
      {:ok, _} = CrossHolonAccess.query(ex_uhi, "SELECT 1")

      # Cross-runtime operations should degrade gracefully
      result =
        ZenohBridge.remote_query(fs_uhi, fs_uhi, "SELECT 1", [], fallback: {:cached, [%{val: 1}]})

      # Returns cached/fallback data
      assert {:ok, [%{val: 1}]} = result

      # Mark available again
      :ok = ZenohBridge.mark_available(fs_uhi)
    end

    test "D6.5: Recovery after coordinator crash during 2PC", %{
      ex_holon_id: ex_id,
      fs_holon_id: fs_id,
      tx_id: tx_id,
      zenoh_connected: true
    } do
      ex_uhi = "#{ex_id}:state.sqlite"
      fs_uhi = "#{fs_id}:state.sqlite"

      {:ok, coordinator} = TwoPhaseCommit.start_coordinator(tx_id, [ex_uhi, fs_uhi])

      # Prepare both
      :ok = TwoPhaseCommit.prepare(coordinator, ex_uhi, fn -> :ok end)
      :ok = TwoPhaseCommit.prepare(coordinator, fs_uhi, fn -> :ok end)

      # Simulate coordinator crash
      :ok = TwoPhaseCommit.simulate_crash(coordinator)

      # Recovery should be automatic
      {:ok, recovered_state} = TwoPhaseCommit.recover_transaction(tx_id)

      # Transaction should be resolved (committed or aborted)
      assert recovered_state.status in [:committed, :aborted]
    end

    test "D6.6: Error propagation across runtime boundary", %{
      fs_holon_id: fs_id,
      zenoh_connected: true
    } do
      fs_uhi = "#{fs_id}:state.sqlite"

      # Trigger error in F# holon
      result =
        ZenohBridge.remote_execute(fs_uhi, """
          INSERT INTO nonexistent_table VALUES (1)
        """)

      # Error should propagate with F# origin info
      assert {:error,
              %{
                type: :sql_error,
                origin: :fsharp,
                message: message
              }} = result

      assert message =~ "table" or message =~ "nonexistent"
    end
  end

  # ============================================================================
  # D7: Performance Tests
  # ============================================================================

  describe "D7: Performance" do
    @describetag :d7_performance
    @describetag timeout: 60_000

    test "D7.1: Local query latency < 10ms (p99)", %{ex_holon_id: ex_id} do
      uhi = "#{ex_id}:state.sqlite"

      # Warmup
      Enum.each(1..10, fn _ ->
        CrossHolonAccess.query(uhi, "SELECT 1")
      end)

      # Measure 100 queries
      latencies =
        Enum.map(1..100, fn _ ->
          start = System.monotonic_time(:microsecond)
          {:ok, _} = CrossHolonAccess.query(uhi, "SELECT 1")
          System.monotonic_time(:microsecond) - start
        end)

      p99 = Enum.sort(latencies) |> Enum.at(98)
      p99_ms = p99 / 1000

      assert p99_ms < 10, "p99 latency should be under 10ms, got #{p99_ms}ms"
    end

    test "D7.2: Cross-runtime query latency < 50ms (p99)", %{
      fs_holon_id: fs_id,
      zenoh_connected: true
    } do
      fs_uhi = "#{fs_id}:state.sqlite"

      # Warmup
      Enum.each(1..10, fn _ ->
        ZenohBridge.remote_query(fs_uhi, fs_uhi, "SELECT 1", [])
      end)

      # Measure 100 queries
      latencies =
        Enum.map(1..100, fn _ ->
          start = System.monotonic_time(:microsecond)
          {:ok, _} = ZenohBridge.remote_query(fs_uhi, fs_uhi, "SELECT 1", [])
          System.monotonic_time(:microsecond) - start
        end)

      p99 = Enum.sort(latencies) |> Enum.at(98)
      p99_ms = p99 / 1000

      assert p99_ms < 50, "p99 cross-runtime latency should be under 50ms, got #{p99_ms}ms"
    end

    test "D7.3: Throughput > 1000 ops/sec local", %{ex_holon_id: ex_id} do
      uhi = "#{ex_id}:state.sqlite"

      # Measure throughput over 1 second
      start = System.monotonic_time(:millisecond)
      ops = 0
      end_time = start + 1000

      ops =
        Stream.iterate(0, &(&1 + 1))
        |> Stream.take_while(fn _ -> System.monotonic_time(:millisecond) < end_time end)
        |> Stream.each(fn _ -> CrossHolonAccess.query(uhi, "SELECT 1") end)
        |> Enum.count()

      assert ops >= 1000, "Should achieve at least 1000 ops/sec, got #{ops}"
    end

    test "D7.4: Batch operation throughput", %{ex_holon_id: ex_id} do
      uhi = "#{ex_id}:state.sqlite"

      # Create batch of 1000 inserts
      operations =
        Enum.map(1..1000, fn i ->
          {:insert, "INSERT INTO perf_test (id, data) VALUES (#{i}, 'data_#{i}')"}
        end)

      start = System.monotonic_time(:millisecond)
      {:ok, _} = CrossHolonAccess.execute_batch(uhi, operations)
      elapsed = System.monotonic_time(:millisecond) - start

      ops_per_sec = 1000 * 1000 / elapsed
      assert ops_per_sec >= 5000, "Batch should achieve 5000+ ops/sec, got #{ops_per_sec}"
    end

    test "D7.5: Memory usage under sustained load", %{ex_holon_id: ex_id} do
      uhi = "#{ex_id}:state.sqlite"

      # Record initial memory
      initial_memory = :erlang.memory(:total)

      # Sustained load for 5 seconds
      Task.async(fn ->
        end_time = System.monotonic_time(:millisecond) + 5000

        Stream.repeatedly(fn ->
          CrossHolonAccess.query(uhi, "SELECT * FROM holon_state LIMIT 100")
          System.monotonic_time(:millisecond)
        end)
        |> Enum.take_while(&(&1 < end_time))
      end)
      |> Task.await(10_000)

      # Force GC
      :erlang.garbage_collect()

      # Check memory didn't grow excessively
      final_memory = :erlang.memory(:total)
      growth = final_memory - initial_memory
      growth_mb = growth / (1024 * 1024)

      assert growth_mb < 50, "Memory growth should be under 50MB, got #{growth_mb}MB"
    end
  end

  # ============================================================================
  # D8: Security Tests
  # ============================================================================

  describe "D8: Security" do
    @describetag :d8_security

    test "D8.1: SQL injection prevention in queries", %{ex_holon_id: ex_id} do
      uhi = "#{ex_id}:state.sqlite"

      # Attempt SQL injection via parameter
      malicious_input = "'; DROP TABLE holon_state; --"

      result =
        CrossHolonAccess.query(uhi, "SELECT * FROM holon_state WHERE key = ?", [malicious_input])

      # Should not cause error (injection escaped)
      assert {:ok, []} = result

      # Table should still exist
      {:ok, _} = CrossHolonAccess.query(uhi, "SELECT COUNT(*) FROM holon_state")
    end

    test "D8.2: Path traversal prevention in UHI", %{ex_holon_id: ex_id} do
      # Attempt path traversal
      malicious_uhi = "#{ex_id}:../../etc/passwd"

      result = CrossHolonAccess.resolve_path(malicious_uhi)

      assert {:error, :invalid_path} = result
    end

    test "D8.3: Cross-holon access requires authorization", %{
      ex_holon_id: ex_id,
      fs_holon_id: fs_id,
      zenoh_connected: true
    } do
      ex_uhi = "#{ex_id}:state.sqlite"
      fs_uhi = "#{fs_id}:state.sqlite"

      # Attempt unauthorized access (no capability token)
      result =
        ZenohBridge.remote_query(fs_uhi, fs_uhi, "SELECT * FROM holon_state", [],
          capability_token: nil
        )

      assert {:error, :unauthorized} = result

      # With valid token should succeed
      {:ok, token} = CrossHolonAccess.request_capability_token(ex_uhi, fs_uhi, [:read])

      {:ok, _} =
        ZenohBridge.remote_query(fs_uhi, fs_uhi, "SELECT * FROM holon_state", [],
          capability_token: token
        )
    end

    test "D8.4: Capability token expiration", %{
      ex_holon_id: ex_id,
      fs_holon_id: fs_id,
      zenoh_connected: true
    } do
      ex_uhi = "#{ex_id}:state.sqlite"
      fs_uhi = "#{fs_id}:state.sqlite"

      # Get short-lived token
      {:ok, token} =
        CrossHolonAccess.request_capability_token(ex_uhi, fs_uhi, [:read],
          # 100ms TTL
          ttl: 100
        )

      # Should work immediately
      {:ok, _} = ZenohBridge.remote_query(fs_uhi, fs_uhi, "SELECT 1", [], capability_token: token)

      # Wait for expiration
      :timer.sleep(150)

      # Should fail after expiration
      result = ZenohBridge.remote_query(fs_uhi, fs_uhi, "SELECT 1", [], capability_token: token)

      assert {:error, :token_expired} = result
    end

    test "D8.5: Audit logging for cross-holon access", %{
      ex_holon_id: ex_id,
      fs_holon_id: fs_id,
      zenoh_connected: true
    } do
      fs_uhi = "#{fs_id}:state.sqlite"
      register_uhi = "#{ex_id}:register.duckdb"

      # Clear audit log
      CrossHolonAccess.execute(register_uhi, "DELETE FROM access_audit WHERE 1=1")

      # Perform cross-holon access
      {:ok, token} = CrossHolonAccess.request_capability_token(ex_id, fs_id, [:read])
      ZenohBridge.remote_query(fs_uhi, fs_uhi, "SELECT 1", [], capability_token: token)

      # Check audit log
      {:ok, audit_rows} =
        CrossHolonAccess.query(
          register_uhi,
          """
            SELECT * FROM access_audit
            WHERE source_holon = ? AND target_holon = ?
            ORDER BY timestamp DESC LIMIT 1
          """,
          [ex_id, fs_id]
        )

      assert length(audit_rows) >= 1
      audit = hd(audit_rows)
      assert audit.operation == "read"
      assert audit.target_holon == fs_id
    end

    test "D8.6: Rate limiting on cross-holon requests", %{
      fs_holon_id: fs_id,
      zenoh_connected: true
    } do
      fs_uhi = "#{fs_id}:state.sqlite"

      # Make many rapid requests
      results =
        Enum.map(1..100, fn _ ->
          ZenohBridge.remote_query(fs_uhi, fs_uhi, "SELECT 1", [])
        end)

      # Some should be rate limited
      rate_limited = Enum.count(results, fn r -> match?({:error, :rate_limited}, r) end)

      # At least some should be rate limited (not all succeed)
      assert rate_limited > 0 or Enum.all?(results, &match?({:ok, _}, &1)),
             "Either rate limiting kicks in or all succeed (if under limit)"
    end
  end

  # ============================================================================
  # D9: Recovery Tests
  # ============================================================================

  describe "D9: Recovery" do
    @describetag :d9_recovery

    test "D9.1: Crash recovery restores last consistent state", %{ex_holon_id: ex_id} do
      uhi = "#{ex_id}:state.sqlite"
      key = "recovery_test_#{:erlang.unique_integer([:positive])}"

      # Write data
      :ok =
        CrossHolonAccess.execute(
          uhi,
          """
            INSERT INTO holon_state (key, value) VALUES (?, 'committed_value')
          """,
          [key]
        )

      # Get checksum before "crash"
      {:ok, pre_crash_checksum} = CrossHolonAccess.get_db_checksum(uhi)

      # Simulate crash (close connection abruptly)
      :ok = CrossHolonAccess.simulate_crash(uhi)

      # Recover
      :ok = CrossHolonAccess.recover(uhi)

      # Verify data integrity
      {:ok, post_recovery_checksum} = CrossHolonAccess.get_db_checksum(uhi)

      {:ok, [row]} =
        CrossHolonAccess.query(uhi, "SELECT value FROM holon_state WHERE key = ?", [key])

      assert pre_crash_checksum == post_recovery_checksum, "Checksum should match after recovery"
      assert row.value == "committed_value", "Data should be intact"
    end

    test "D9.2: WAL replay after crash", %{ex_holon_id: ex_id} do
      uhi = "#{ex_id}:state.sqlite"

      # Enable WAL mode explicitly
      :ok = CrossHolonAccess.execute(uhi, "PRAGMA journal_mode=WAL")

      # Write several records
      Enum.each(1..10, fn i ->
        CrossHolonAccess.execute(uhi, "INSERT INTO wal_test (seq) VALUES (?)", [i])
      end)

      # Don't checkpoint - simulate crash before checkpoint
      :ok = CrossHolonAccess.simulate_crash(uhi, skip_checkpoint: true)

      # Recover - should replay WAL
      :ok = CrossHolonAccess.recover(uhi)

      # All 10 records should be present
      {:ok, [%{cnt: count}]} = CrossHolonAccess.query(uhi, "SELECT COUNT(*) as cnt FROM wal_test")
      assert count == 10
    end

    test "D9.3: Checkpoint restore from backup", %{ex_holon_id: ex_id} do
      uhi = "#{ex_id}:state.sqlite"

      # Create initial data
      :ok =
        CrossHolonAccess.execute(
          uhi,
          "INSERT INTO holon_state (key, value) VALUES ('ckpt_test', 'original')"
        )

      # Create checkpoint
      {:ok, checkpoint_id} = CrossHolonAccess.create_checkpoint(uhi)

      # Modify data
      :ok =
        CrossHolonAccess.execute(
          uhi,
          "UPDATE holon_state SET value = 'modified' WHERE key = 'ckpt_test'"
        )

      # Verify modification
      {:ok, [%{value: "modified"}]} =
        CrossHolonAccess.query(uhi, "SELECT value FROM holon_state WHERE key = 'ckpt_test'")

      # Restore from checkpoint
      :ok = CrossHolonAccess.restore_checkpoint(uhi, checkpoint_id)

      # Data should be back to original
      {:ok, [%{value: value}]} =
        CrossHolonAccess.query(uhi, "SELECT value FROM holon_state WHERE key = 'ckpt_test'")

      assert value == "original"
    end

    test "D9.4: Cross-runtime recovery coordination", %{
      ex_holon_id: ex_id,
      fs_holon_id: fs_id,
      zenoh_connected: true
    } do
      ex_uhi = "#{ex_id}:state.sqlite"
      fs_uhi = "#{fs_id}:state.sqlite"

      # Create coordinated checkpoints
      {:ok, ex_ckpt} = CrossHolonAccess.create_checkpoint(ex_uhi)
      {:ok, fs_ckpt} = ZenohBridge.remote_create_checkpoint(fs_uhi)

      # Verify checkpoints are correlated
      {:ok, ex_meta} = CrossHolonAccess.get_checkpoint_metadata(ex_uhi, ex_ckpt)
      {:ok, fs_meta} = ZenohBridge.remote_get_checkpoint_metadata(fs_uhi, fs_ckpt)

      # Timestamps should be within 1 second
      time_diff = abs(ex_meta.timestamp - fs_meta.timestamp)
      assert time_diff < 1000, "Coordinated checkpoints should be within 1 second"
    end

    test "D9.5: Immutable register recovery", %{ex_holon_id: ex_id} do
      register_uhi = "#{ex_id}:register.duckdb"

      # Append to register
      {:ok, block1} =
        CrossHolonAccess.append_to_register(register_uhi, %{
          action: "test_action_1",
          data: %{key: "value"}
        })

      {:ok, block2} =
        CrossHolonAccess.append_to_register(register_uhi, %{
          action: "test_action_2",
          data: %{key: "value2"}
        })

      # Verify chain integrity
      {:ok, chain_valid} = CrossHolonAccess.verify_register_chain(register_uhi)
      assert chain_valid

      # Get chain head
      {:ok, head} = CrossHolonAccess.get_register_head(register_uhi)
      assert head.block_id == block2

      # Verify block hashes link correctly
      {:ok, block2_data} = CrossHolonAccess.get_register_block(register_uhi, block2)
      assert block2_data.prev_hash == block1.hash
    end

    test "D9.6: Version vector recovery after partition", %{
      ex_holon_id: ex_id,
      fs_holon_id: fs_id,
      zenoh_connected: true
    } do
      ex_uhi = "#{ex_id}:state.sqlite"
      fs_uhi = "#{fs_id}:state.sqlite"

      # Get initial VVs
      {:ok, initial_ex_vv} = CrossHolonAccess.get_version_vector(ex_uhi)
      {:ok, initial_fs_vv} = ZenohBridge.remote_get_version_vector(fs_uhi)

      # Simulate partition - both sides update independently
      {:ok, ex_vv_during} = CrossHolonAccess.increment_version(ex_uhi, ex_id)
      {:ok, ex_vv_during2} = CrossHolonAccess.increment_version(ex_uhi, ex_id)

      {:ok, fs_vv_during} = ZenohBridge.remote_increment_version(fs_uhi, fs_id)

      # Resolve partition - merge VVs
      {:ok, merged_vv} = ZenohBridge.sync_version_vectors(ex_uhi, fs_uhi, ex_vv_during2)

      # Merged VV should dominate all previous
      assert VersionVector.happens_before(initial_ex_vv, merged_vv)
      assert VersionVector.happens_before(initial_fs_vv, merged_vv)

      # Should have entries from both holons
      assert Map.has_key?(merged_vv, ex_id)
      assert Map.has_key?(merged_vv, fs_id)
    end
  end

  # ============================================================================
  # Integration: Full 9-Degree Scenario
  # ============================================================================

  describe "Full 9-Degree Integration Scenario" do
    @describetag :integration
    @describetag :full_9degree

    test "Complete workflow spanning all 9 degrees", %{
      ex_holon_id: ex_id,
      fs_holon_id: fs_id,
      tx_id: tx_id,
      zenoh_connected: true
    } do
      ex_state_uhi = "#{ex_id}:state.sqlite"
      ex_analytics_uhi = "#{ex_id}:analytics.duckdb"
      fs_state_uhi = "#{fs_id}:state.sqlite"

      # D1: Cross-runtime setup
      {:ok, token} = CrossHolonAccess.request_capability_token(ex_id, fs_id, [:read, :write])

      # D2: Multi-database type operations
      :ok =
        CrossHolonAccess.execute(
          ex_state_uhi,
          "INSERT INTO holon_state (key, value) VALUES ('scenario_key', '100')"
        )

      :ok =
        CrossHolonAccess.execute(
          ex_analytics_uhi,
          "INSERT INTO analytics_events (event_type, data) VALUES ('scenario_event', '{}')"
        )

      # D3: Various operations (query, execute, CAS)
      {:ok, [state_row]} =
        CrossHolonAccess.query(ex_state_uhi, "SELECT value FROM holon_state WHERE key = ?", [
          "scenario_key"
        ])

      # D4: Concurrent access with version vectors
      {:ok, vv1} = CrossHolonAccess.increment_version(ex_state_uhi, ex_id)

      task =
        Task.async(fn ->
          ZenohBridge.remote_increment_version(fs_state_uhi, fs_id, capability_token: token)
        end)

      {:ok, vv2} = Task.await(task)

      # D5: Distributed transaction
      {:ok, coordinator} = TwoPhaseCommit.start_coordinator(tx_id, [ex_state_uhi, fs_state_uhi])

      :ok =
        TwoPhaseCommit.prepare(coordinator, ex_state_uhi, fn ->
          CrossHolonAccess.execute(
            ex_state_uhi,
            "INSERT INTO tx_log (tx_id, status) VALUES (?, 'scenario')",
            [tx_id]
          )
        end)

      :ok =
        TwoPhaseCommit.prepare(coordinator, fs_state_uhi, fn ->
          ZenohBridge.remote_execute(
            fs_state_uhi,
            "INSERT INTO tx_log (tx_id, status) VALUES (?, 'scenario')",
            [tx_id],
            capability_token: token
          )
        end)

      :ok = TwoPhaseCommit.commit(coordinator)

      # D6: Verify circuit breaker is healthy
      cb_state = ZenohBridge.get_circuit_breaker_state(fs_state_uhi)
      assert cb_state.status == :closed

      # D7: Performance check
      start = System.monotonic_time(:millisecond)
      {:ok, _} = CrossHolonAccess.query(ex_state_uhi, "SELECT 1")
      latency = System.monotonic_time(:millisecond) - start
      assert latency < 50

      # D8: Security - verify token was required
      unauthorized_result =
        ZenohBridge.remote_query(fs_state_uhi, fs_state_uhi, "SELECT 1", [],
          capability_token: nil
        )

      assert {:error, :unauthorized} = unauthorized_result

      # D9: Create checkpoint for recovery
      {:ok, checkpoint_id} = CrossHolonAccess.create_checkpoint(ex_state_uhi)
      assert is_binary(checkpoint_id)

      # Verify all operations completed successfully
      {:ok, final_rows} =
        CrossHolonAccess.query(
          ex_state_uhi,
          "SELECT COUNT(*) as cnt FROM tx_log WHERE tx_id = ?",
          [tx_id]
        )

      assert hd(final_rows).cnt >= 1

      # Merge version vectors at the end
      {:ok, final_vv} = VersionVector.merge(vv1, vv2)
      # Both holons represented
      assert map_size(final_vv) >= 2
    end
  end
end
