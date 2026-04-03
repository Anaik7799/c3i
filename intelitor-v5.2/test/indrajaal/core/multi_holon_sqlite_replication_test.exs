defmodule Indrajaal.Core.MultiHolonSqliteReplicationTest do
  @moduledoc """
  TDG test suite for multi-holon SQLite replication using ETS-backed simulation.

  ## WHAT
  Validates a self-contained ETS-backed simulation of 3-node SQLite replication
  at L7 (Federation) fractal layer.  Each simulated node owns an isolated ETS
  table acting as its SQLite store, a monotonically-increasing version vector
  map, and an append-only WAL ETS table.  All state is represented with plain
  Elixir maps and ETS — zero production-module dependencies.

  ## WHY
  SC-XHOLON-001 mandates isolated per-holon database files.
  SC-XHOLON-006 / SC-XHOLON-007 require OCC with monotonically-increasing
  version vectors.  SC-XHOLON-030 mandates WAL so no committed write is ever
  lost across a simulated crash.  SC-DBCROSS-003 and SC-SMRITI-110 require
  version vectors to be the authoritative conflict-resolution mechanism for
  cross-holon replication.

  ## CONSTRAINTS
  - SC-XHOLON-001: Isolated database files per holon
  - SC-XHOLON-006: OCC with version vectors
  - SC-XHOLON-007: Monotonically increasing version vectors
  - SC-XHOLON-030: No data loss on crash (WAL mandatory)
  - SC-XHOLON-031: ACID compliance for SQLite writes
  - SC-XHOLON-032: No deadlocks
  - SC-XHOLON-050: Support 100+ concurrent holons (property test baseline)
  - SC-DBCROSS-003: Version vectors for conflict resolution
  - SC-SMRITI-110: Version vectors in SQLite; attestation expires 1hr
  - SC-SMRITI-111: Concurrent update detection
  - SC-SMRITI-113: Causality preserved via version vectors
  - SC-HOLON-009: SQLite/DuckDB is ONLY authoritative holon state
  - AOR-HOLON-001: ALL holon real-time state stored in SQLite (WAL mode)
  - AOR-HOLON-011: ALL evolution events recorded in DuckDB
  - EP-GEN-014: PropCheck/StreamData disambiguation

  ## EP-GEN-014 Compliance
  - `use PropCheck` registers `forall`/`property` macros (PropCheck-native).
  - `import ExUnitProperties, except: [property: 2, property: 3]` avoids the
    conflicting `check/2` import from ExUnitProperties.
  - `PC.` prefix for all PropCheck generators inside `property`/`forall` blocks.
  - `SD.` prefix for all StreamData generators inside `ExUnitProperties.check all` blocks.
  - `require ExUnitProperties` is present to allow `ExUnitProperties.check all`.
  - All helpers are self-contained `defp` — zero production module dependencies.

  ## Coverage Matrix
  | Scenario                                       | PropCheck | StreamData | Unit |
  |------------------------------------------------|-----------|------------|------|
  | ETS holon isolation                            | 0         | 0          | 3    |
  | Write / read / WAL-append                      | 0         | 0          | 4    |
  | Replication A → B, A → C                      | 0         | 0          | 3    |
  | Concurrent write conflict detection            | 0         | 0          | 3    |
  | Conflict resolution (last-writer-wins)         | 0         | 0          | 2    |
  | Version vector merge                           | 0         | 0          | 3    |
  | Version vector dominance                       | 0         | 0          | 3    |
  | Consistency after full 3-node sync             | 0         | 0          | 2    |
  | Crash simulation + WAL restore                 | 0         | 0          | 2    |
  | Network partition + reconnect                  | 0         | 0          | 2    |
  | Replication latency (100 entries, < 500 ms)    | 0         | 0          | 1    |
  | Property: random writes converge (StreamData)  | 0         | 1          | 0    |
  | Property: version vector monotonicity (PC)     | 1         | 0          | 0    |
  | TOTAL                                          | 1         | 1          | 28   |

  ## Change History
  | Version | Date       | Author | Change                                              |
  |---------|------------|--------|-----------------------------------------------------|
  | 1.0.0   | 2026-03-24 | Claude | Sprint 88 task b57883e5 — multi-holon ETS replication L7 |
  """

  use ExUnit.Case, async: false

  # EP-GEN-014: dual property testing import pattern — MANDATORY
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  require ExUnitProperties

  @moduletag :replication
  @moduletag :sqlite
  @moduletag :holon
  @moduletag :sprint_88

  # ------------------------------------------------------------------
  # Per-test ETS table names are made unique by embedding the test pid
  # so that async: false + ETS name-collision never occurs during a run.
  # ------------------------------------------------------------------

  setup do
    Application.ensure_all_started(:propcheck)

    test_id = System.unique_integer([:positive, :monotonic])

    h_a = new_ets_holon(:node_a, test_id)
    h_b = new_ets_holon(:node_b, test_id)
    h_c = new_ets_holon(:node_c, test_id)

    on_exit(fn ->
      Enum.each([h_a, h_b, h_c], &cleanup_ets_holon/1)
    end)

    %{h_a: h_a, h_b: h_b, h_c: h_c, test_id: test_id}
  end

  # ============================================================================
  # SECTION 1: ETS holon isolation — SC-XHOLON-001
  # ============================================================================

  describe "ETS holon isolation (SC-XHOLON-001)" do
    test "each holon has a distinct ETS table", %{h_a: h_a, h_b: h_b, h_c: h_c} do
      assert h_a.store_table != h_b.store_table,
             "Holon A and B must have separate ETS store tables (SC-XHOLON-001)"

      assert h_b.store_table != h_c.store_table,
             "Holon B and C must have separate ETS store tables (SC-XHOLON-001)"

      assert h_a.wal_table != h_c.wal_table,
             "Holon A and C must have separate WAL tables"
    end

    test "write to A is invisible in B before replication", %{h_a: h_a, h_b: h_b} do
      ets_write(h_a, "exclusive_key", "node_a_value")

      assert ets_read(h_a, "exclusive_key") == {:ok, "node_a_value"},
             "A must see its own write"

      assert ets_read(h_b, "exclusive_key") == {:error, :not_found},
             "B must NOT see A's write before replication (SC-XHOLON-001)"
    end

    test "write to C is invisible in A and B before replication",
         %{h_a: h_a, h_b: h_b, h_c: h_c} do
      ets_write(h_c, "c_private", "c_val")

      assert ets_read(h_a, "c_private") == {:error, :not_found},
             "A must not see C's private key"

      assert ets_read(h_b, "c_private") == {:error, :not_found},
             "B must not see C's private key"
    end
  end

  # ============================================================================
  # SECTION 2: Write / read / WAL-append — SC-XHOLON-030, SC-XHOLON-031
  # ============================================================================

  describe "write, read, and WAL append (SC-XHOLON-030, SC-XHOLON-031)" do
    test "write increments the owning node's version vector", %{h_a: h_a} do
      assert get_node_clock(h_a, :node_a) == 0,
             "Clock must start at 0"

      ets_write(h_a, "k1", "v1")

      assert get_node_clock(h_a, :node_a) == 1,
             "Clock must advance to 1 after one write (SC-XHOLON-007)"
    end

    test "consecutive writes are strictly monotone on same node", %{h_a: h_a} do
      ets_write(h_a, "k1", "v1")
      ets_write(h_a, "k2", "v2")
      ets_write(h_a, "k3", "v3")

      assert get_node_clock(h_a, :node_a) == 3,
             "After 3 writes clock must equal 3 (SC-XHOLON-007 monotone)"
    end

    test "each write appends a WAL entry (SC-XHOLON-030)", %{h_a: h_a} do
      ets_write(h_a, "wal_k1", "wal_v1")
      ets_write(h_a, "wal_k2", "wal_v2")

      wal_entries = wal_all(h_a)

      assert length(wal_entries) == 2,
             "WAL must have 2 entries after 2 writes"
    end

    test "WAL entries are strictly ordered by sequence number", %{h_a: h_a} do
      ets_write(h_a, "seq_k1", "v")
      ets_write(h_a, "seq_k2", "v")
      ets_write(h_a, "seq_k3", "v")

      entries = wal_all(h_a)
      seqs = Enum.map(entries, & &1.seq)

      assert seqs == Enum.sort(seqs),
             "WAL entries must be in ascending sequence order (SC-SMRITI-113)"

      assert Enum.uniq(seqs) == seqs,
             "WAL sequence numbers must be unique"
    end
  end

  # ============================================================================
  # SECTION 3: Replication A → B and A → C — SC-HOLON-009, SC-XHOLON-003
  # ============================================================================

  describe "replication from source to target (SC-HOLON-009)" do
    test "replicate A to B: B sees A's key", %{h_a: h_a, h_b: h_b} do
      ets_write(h_a, "shared", "from_a")
      ets_replicate(h_a, h_b)

      assert ets_read(h_b, "shared") == {:ok, "from_a"},
             "B must see A's key after replication"
    end

    test "replicate A to B and A to C: both see A's key", %{h_a: h_a, h_b: h_b, h_c: h_c} do
      ets_write(h_a, "broadcast_key", "broadcast_val")
      ets_replicate(h_a, h_b)
      ets_replicate(h_a, h_c)

      assert ets_read(h_b, "broadcast_key") == {:ok, "broadcast_val"},
             "B must see A's key"

      assert ets_read(h_c, "broadcast_key") == {:ok, "broadcast_val"},
             "C must see A's key"
    end

    test "after replication, target's version vector dominates source's pre-write vector",
         %{h_a: h_a, h_b: h_b} do
      ets_write(h_a, "vv_check", "value")
      vv_before = get_vv(h_a)
      ets_replicate(h_a, h_b)

      vv_b_after = get_vv(h_b)

      # Every component of vv_before must be <= vv_b_after
      dominated =
        Enum.all?(vv_before, fn {node, clock} ->
          Map.get(vv_b_after, node, 0) >= clock
        end)

      assert dominated,
             "B's VV must dominate A's VV after replication (SC-SMRITI-110)"
    end
  end

  # ============================================================================
  # SECTION 4: Concurrent write conflict detection — SC-XHOLON-006
  # ============================================================================

  describe "concurrent write conflict detection (SC-XHOLON-006)" do
    test "concurrent writes to same key on A and B are detected as conflict",
         %{h_a: h_a, h_b: h_b} do
      # Neither node has seen the other's write
      ets_write(h_a, "concurrent_key", "from_a")
      ets_write(h_b, "concurrent_key", "from_b")

      result = detect_conflict(h_a, h_b, "concurrent_key")

      assert result == :conflict,
             "Independent writes to same key are concurrent → conflict (SC-XHOLON-006)"
    end

    test "no conflict when B's write causally follows A's write",
         %{h_a: h_a, h_b: h_b} do
      ets_write(h_a, "causal_key", "v1")
      # B receives A's write first, establishing causal order
      ets_replicate(h_a, h_b)
      ets_write(h_b, "causal_key", "v2")

      result = detect_conflict(h_a, h_b, "causal_key")

      assert result == :no_conflict,
             "Causally ordered writes must not produce conflict (SC-XHOLON-007)"
    end

    test "no conflict when key exists on only one node", %{h_a: h_a, h_b: h_b} do
      ets_write(h_a, "only_on_a", "val")
      # h_b has never heard of this key

      result = detect_conflict(h_a, h_b, "only_on_a")

      assert result == :no_conflict,
             "Key absent on one node implies no conflict"
    end
  end

  # ============================================================================
  # SECTION 5: Conflict resolution (last-writer-wins) — SC-XHOLON-006
  # ============================================================================

  describe "last-writer-wins conflict resolution (SC-XHOLON-006)" do
    test "LWW: higher-clock write survives after bidirectional sync",
         %{h_a: h_a, h_b: h_b} do
      ets_write(h_a, "lww_key", "old_value")
      # B sees A's write first, then updates
      ets_replicate(h_a, h_b)
      ets_write(h_b, "lww_key", "new_value")

      # Merge B into A — B's write has higher clock
      ets_replicate(h_b, h_a)

      assert ets_read(h_a, "lww_key") == {:ok, "new_value"},
             "Highest-clock write must win (LWW, SC-XHOLON-006)"
    end

    test "after bidirectional sync both nodes hold same LWW value",
         %{h_a: h_a, h_b: h_b} do
      ets_write(h_a, "agree_key", "a_val")
      ets_replicate(h_a, h_b)
      ets_write(h_b, "agree_key", "b_val")

      # Full bidirectional sync
      ets_replicate(h_b, h_a)
      ets_replicate(h_a, h_b)

      val_a = ets_read(h_a, "agree_key")
      val_b = ets_read(h_b, "agree_key")

      assert val_a == val_b,
             "After bidirectional sync, both nodes must hold identical values"
    end
  end

  # ============================================================================
  # SECTION 6: Version vector merge — SC-XHOLON-007, SC-SMRITI-110
  # ============================================================================

  describe "version vector merge (SC-XHOLON-007, SC-SMRITI-110)" do
    test "merge produces element-wise maximum" do
      vv_a = %{node_a: 3, node_b: 1, node_c: 0}
      vv_b = %{node_a: 1, node_b: 4, node_c: 2}
      merged = vv_merge(vv_a, vv_b)

      assert merged[:node_a] == 3
      assert merged[:node_b] == 4
      assert merged[:node_c] == 2
    end

    test "merge includes keys from both vectors" do
      vv_a = %{node_a: 2}
      vv_b = %{node_b: 5}
      merged = vv_merge(vv_a, vv_b)

      assert merged[:node_a] == 2
      assert merged[:node_b] == 5
    end

    test "merge is idempotent: merge(vv, vv) == vv" do
      vv = %{node_a: 3, node_b: 2, node_c: 7}

      assert vv_merge(vv, vv) == vv,
             "Merge must be idempotent (SC-SMRITI-111 duplicate-sync safety)"
    end
  end

  # ============================================================================
  # SECTION 7: Version vector dominance — SC-SMRITI-113
  # ============================================================================

  describe "version vector dominance (SC-SMRITI-113)" do
    test "A dominates B when all A[i] >= B[i] and at least one is strictly greater" do
      vv_a = %{node_a: 3, node_b: 2}
      vv_b = %{node_a: 1, node_b: 1}

      assert vv_dominates?(vv_a, vv_b),
             "vv_a with strictly higher counts must dominate vv_b"

      refute vv_dominates?(vv_b, vv_a),
             "vv_b with lower counts must not dominate vv_a"
    end

    test "B is concurrent with C when neither dominates the other" do
      vv_b = %{node_a: 0, node_b: 3}
      vv_c = %{node_a: 3, node_b: 0}

      refute vv_dominates?(vv_b, vv_c),
             "B must not dominate C in concurrent scenario"

      refute vv_dominates?(vv_c, vv_b),
             "C must not dominate B in concurrent scenario"
    end

    test "equal vectors do not dominate each other" do
      vv = %{node_a: 2, node_b: 2}

      refute vv_dominates?(vv, vv),
             "Equal vectors must not dominate each other (reflexive non-strict)"
    end
  end

  # ============================================================================
  # SECTION 8: Replication consistency — all 3 nodes converge
  # ============================================================================

  describe "3-node convergence (SC-HOLON-009)" do
    test "after full 3-node sync, all nodes hold all keys",
         %{h_a: h_a, h_b: h_b, h_c: h_c} do
      ets_write(h_a, "k_a", "v_a")
      ets_write(h_b, "k_b", "v_b")
      ets_write(h_c, "k_c", "v_c")

      full_3node_sync(h_a, h_b, h_c)

      for {h, id} <- [{h_a, :node_a}, {h_b, :node_b}, {h_c, :node_c}] do
        assert ets_read(h, "k_a") == {:ok, "v_a"},
               "#{id} must hold k_a after convergence"

        assert ets_read(h, "k_b") == {:ok, "v_b"},
               "#{id} must hold k_b after convergence"

        assert ets_read(h, "k_c") == {:ok, "v_c"},
               "#{id} must hold k_c after convergence"
      end
    end

    test "convergence is idempotent: second full sync changes nothing",
         %{h_a: h_a, h_b: h_b, h_c: h_c} do
      ets_write(h_a, "stable_key", "stable_val")
      full_3node_sync(h_a, h_b, h_c)

      # Snapshot store state after first sync
      snap_a = ets_dump_store(h_a)
      snap_b = ets_dump_store(h_b)
      snap_c = ets_dump_store(h_c)

      # Second full sync should produce identical state
      full_3node_sync(h_a, h_b, h_c)

      assert ets_dump_store(h_a) == snap_a,
             "A's store must be idempotent after second sync (SC-XHOLON-031)"

      assert ets_dump_store(h_b) == snap_b
      assert ets_dump_store(h_c) == snap_c
    end
  end

  # ============================================================================
  # SECTION 9: Crash simulation + WAL restore — SC-XHOLON-030
  # ============================================================================

  describe "crash simulation and WAL restore (SC-XHOLON-030)" do
    test "after ETS store crash, WAL log survives and enables state reconstruction",
         %{h_a: h_a} do
      ets_write(h_a, "before_crash", "important_value")
      ets_write(h_a, "also_important", "another_value")

      # Simulate crash: clear the ETS store (WAL survives as separate table)
      :ets.delete_all_objects(h_a.store_table)

      # Verify crash: store is gone
      assert ets_read(h_a, "before_crash") == {:error, :not_found},
             "Store must be empty after simulated crash"

      # Restore from WAL
      restored_holon = restore_from_wal(h_a)

      assert ets_read(restored_holon, "before_crash") == {:ok, "important_value"},
             "Value must be restored from WAL (SC-XHOLON-030)"

      assert ets_read(restored_holon, "also_important") == {:ok, "another_value"},
             "All WAL entries must survive crash and restore"
    end

    test "WAL is append-only: crash does not truncate it", %{h_a: h_a} do
      ets_write(h_a, "pre_crash", "val1")
      wal_count_before = length(wal_all(h_a))

      # Simulate crash and WAL replay
      :ets.delete_all_objects(h_a.store_table)
      _restored = restore_from_wal(h_a)

      wal_count_after = length(wal_all(h_a))

      assert wal_count_after == wal_count_before,
             "WAL must be append-only — no entries lost after crash/restore"
    end
  end

  # ============================================================================
  # SECTION 10: Network partition + reconnect — SC-DBCROSS-003
  # ============================================================================

  describe "network partition and reconnect (SC-DBCROSS-003)" do
    test "A and B diverge independently during partition, then merge after reconnect",
         %{h_a: h_a, h_b: h_b, h_c: h_c} do
      # Baseline: all three nodes are in sync
      ets_write(h_a, "base", "v0")
      full_3node_sync(h_a, h_b, h_c)

      # --- PARTITION: A and B are isolated from C ---
      # A writes independently
      ets_write(h_a, "partition_key", "from_a_during_partition")
      # B writes independently
      ets_write(h_b, "partition_key", "from_b_during_partition")
      # C writes independently (isolated)
      ets_write(h_c, "partition_key", "from_c_during_partition")

      # --- RECONNECT: full 3-node sync ---
      full_3node_sync(h_a, h_b, h_c)

      # After reconnect, all nodes must agree on exactly one value (LWW)
      val_a = ets_read(h_a, "partition_key")
      val_b = ets_read(h_b, "partition_key")
      val_c = ets_read(h_c, "partition_key")

      assert val_a == val_b,
             "A and B must agree after partition heals"

      assert val_b == val_c,
             "B and C must agree after partition heals"

      # Value must be one of the three written values
      assert val_a in [
               {:ok, "from_a_during_partition"},
               {:ok, "from_b_during_partition"},
               {:ok, "from_c_during_partition"}
             ],
             "Resolved value must be one of the three concurrent writes"
    end

    test "keys written only on isolated C are visible to A and B after reconnect",
         %{h_a: h_a, h_b: h_b, h_c: h_c} do
      ets_write(h_c, "c_only_partition", "unique_c_val")

      # Reconnect
      full_3node_sync(h_a, h_b, h_c)

      assert ets_read(h_a, "c_only_partition") == {:ok, "unique_c_val"},
             "A must get C's isolated write after reconnect"

      assert ets_read(h_b, "c_only_partition") == {:ok, "unique_c_val"},
             "B must get C's isolated write after reconnect"
    end
  end

  # ============================================================================
  # SECTION 11: Replication latency — SC-XHOLON-025 (< 500ms for 100 entries)
  # ============================================================================

  describe "replication latency (SC-XHOLON-025)" do
    @tag timeout: 10_000
    test "sync 100 entries across 3 nodes completes in < 500ms",
         %{test_id: test_id} do
      h_src = new_ets_holon(:latency_src, test_id)
      h_dst1 = new_ets_holon(:latency_dst1, test_id)
      h_dst2 = new_ets_holon(:latency_dst2, test_id)

      on_exit(fn ->
        Enum.each([h_src, h_dst1, h_dst2], &cleanup_ets_holon/1)
      end)

      for i <- 1..100 do
        ets_write(h_src, "load_key_#{i}", "load_val_#{i}")
      end

      t0 = System.monotonic_time(:millisecond)
      ets_replicate(h_src, h_dst1)
      ets_replicate(h_src, h_dst2)
      t1 = System.monotonic_time(:millisecond)

      elapsed_ms = t1 - t0

      assert elapsed_ms < 500,
             "Replication of 100 entries must complete in < 500ms (SC-XHOLON-025), took #{elapsed_ms}ms"

      # Sanity: confirm all 100 keys landed
      assert ets_read(h_dst1, "load_key_50") == {:ok, "load_val_50"}
      assert ets_read(h_dst2, "load_key_100") == {:ok, "load_val_100"}
    end
  end

  # ============================================================================
  # SECTION 12: Property — random writes across 3 nodes converge (StreamData)
  # ============================================================================

  describe "property: random writes converge (SC-HOLON-009, SC-XHOLON-007)" do
    @tag timeout: 60_000
    test "random writes to random nodes always converge to the same store" do
      ExUnitProperties.check all(
                               ops <-
                                 SD.list_of(
                                   SD.tuple({
                                     SD.member_of([:n1, :n2, :n3]),
                                     SD.string(:alphanumeric, min_length: 1, max_length: 8),
                                     SD.string(:alphanumeric, min_length: 1, max_length: 16)
                                   }),
                                   min_length: 1,
                                   max_length: 20
                                 )
                             ) do
        prop_test_id = System.unique_integer([:positive, :monotonic])

        h1 = new_ets_holon(:n1, prop_test_id)
        h2 = new_ets_holon(:n2, prop_test_id)
        h3 = new_ets_holon(:n3, prop_test_id)

        try do
          # Apply random operations to the designated node
          Enum.each(ops, fn
            {:n1, k, v} -> ets_write(h1, k, v)
            {:n2, k, v} -> ets_write(h2, k, v)
            {:n3, k, v} -> ets_write(h3, k, v)
          end)

          # Full 3-node convergence
          full_3node_sync(h1, h2, h3)

          # After sync, all stores must be identical
          store_1 = ets_dump_store(h1)
          store_2 = ets_dump_store(h2)
          store_3 = ets_dump_store(h3)

          assert store_1 == store_2,
                 "n1 and n2 must converge to identical stores after full sync"

          assert store_2 == store_3,
                 "n2 and n3 must converge to identical stores after full sync"
        after
          Enum.each([h1, h2, h3], &cleanup_ets_holon/1)
        end
      end
    end
  end

  # ============================================================================
  # SECTION 13: Property — version vector monotonicity (PropCheck)
  # ============================================================================

  describe "property: version vector monotonicity (SC-XHOLON-007)" do
    property "every increment strictly advances the target node's clock" do
      forall {node, n_writes} <- {PC.oneof([:n_a, :n_b, :n_c]), PC.integer(1, 30)} do
        vv = vv_new()

        final_vv =
          Enum.reduce(1..n_writes, vv, fn _, acc ->
            vv_increment(acc, node)
          end)

        Map.get(final_vv, node, 0) == n_writes
      end
    end
  end

  # ============================================================================
  # PRIVATE: ETS holon simulation primitives
  # ============================================================================

  # ---------------------------------------------------------------------------
  # Holon structure (plain Elixir map, zero module deps):
  #   %{
  #     id:             atom,          — unique node identity
  #     store_table:    atom,          — ETS table: key → {key, value, vv, node_id}
  #     wal_table:      atom,          — ETS table: seq → wal_entry
  #     version_vector: %{atom → non_neg_integer},
  #     next_seq:       non_neg_integer  — monotone WAL sequence counter
  #   }
  # ---------------------------------------------------------------------------

  @doc false
  defp new_ets_holon(node_id, test_id) do
    store_name = String.to_atom("ets_store_#{node_id}_#{test_id}")
    wal_name = String.to_atom("ets_wal_#{node_id}_#{test_id}")

    :ets.new(store_name, [:named_table, :public, :set])
    :ets.new(wal_name, [:named_table, :public, :ordered_set])

    %{
      id: node_id,
      store_table: store_name,
      wal_table: wal_name,
      version_vector: %{node_id => 0},
      next_seq: 0
    }
  end

  defp cleanup_ets_holon(%{store_table: st, wal_table: wt}) do
    # Guard against double-deletion (test teardown may race)
    if :ets.whereis(st) != :undefined, do: :ets.delete(st)
    if :ets.whereis(wt) != :undefined, do: :ets.delete(wt)
  end

  # ---------------------------------------------------------------------------
  # Core write: atomically bump VV, write entry to store, append WAL row.
  # Returns the updated holon struct (caller must rebind if needed).
  # Because this is a simulation the holon struct is passed in/out explicitly.
  # The ETS tables are mutated in place; the struct carries mutable metadata.
  # ---------------------------------------------------------------------------

  defp ets_write(holon, key, value) do
    new_clock = Map.get(holon.version_vector, holon.id, 0) + 1
    new_vv = Map.put(holon.version_vector, holon.id, new_clock)
    new_seq = holon.next_seq + 1

    entry = {key, value, new_vv, holon.id}
    wal_entry = %{seq: new_seq, op: :write, key: key, value: value, vv: new_vv, node_id: holon.id}

    :ets.insert(holon.store_table, entry)
    :ets.insert(holon.wal_table, {new_seq, wal_entry})

    # Update the struct with new metadata
    %{holon | version_vector: new_vv, next_seq: new_seq}
  end

  defp ets_read(holon, key) do
    case :ets.lookup(holon.store_table, key) do
      [{^key, value, _vv, _node_id}] -> {:ok, value}
      [] -> {:error, :not_found}
    end
  end

  # ---------------------------------------------------------------------------
  # Replication: copy all entries from source into target using LWW semantics.
  # For each key, the entry with the higher node-local clock wins.
  # The target's version vector is merged (element-wise max) with source's.
  # WAL entries from source are merged into target's WAL (deduped by node+clock).
  # Returns the updated target holon struct.
  # ---------------------------------------------------------------------------

  defp ets_replicate(source, target) do
    source_entries = :ets.tab2list(source.store_table)

    Enum.each(source_entries, fn {key, s_value, s_vv, s_node_id} ->
      case :ets.lookup(target.store_table, key) do
        [] ->
          # Target has no entry for this key — accept source's
          :ets.insert(target.store_table, {key, s_value, s_vv, s_node_id})

        [{^key, _t_value, t_vv, t_node_id}] ->
          # Both have the key — LWW: higher composite clock wins
          t_clock = Map.get(t_vv, t_node_id, 0)
          s_clock = Map.get(s_vv, s_node_id, 0)

          winner =
            cond do
              s_clock > t_clock ->
                {key, s_value, s_vv, s_node_id}

              s_clock == t_clock and to_string(s_node_id) > to_string(t_node_id) ->
                {key, s_value, s_vv, s_node_id}

              true ->
                {key, _t_value, t_vv, t_node_id}
            end

          :ets.insert(target.store_table, winner)
      end
    end)

    # Merge version vectors
    merged_vv = vv_merge(target.version_vector, source.version_vector)

    # Merge WAL (append source WAL entries not already in target's WAL)
    source_wal = :ets.tab2list(source.wal_table)

    # Find next available sequence for target WAL
    next_target_seq =
      case :ets.last(target.wal_table) do
        :"$end_of_table" -> 0
        last_seq -> last_seq
      end

    new_seq_ref = :counters.new(1, [:atomics])
    :counters.put(new_seq_ref, 1, next_target_seq)

    Enum.each(source_wal, fn {_seq, wal_entry} ->
      # Deduplicate by {node_id, original_clock}
      already_exists =
        :ets.foldl(
          fn {_s, e}, acc -> acc or (e.node_id == wal_entry.node_id and e.vv == wal_entry.vv) end,
          false,
          target.wal_table
        )

      unless already_exists do
        new_seq = :counters.get(new_seq_ref, 1) + 1
        :counters.put(new_seq_ref, 1, new_seq)
        :ets.insert(target.wal_table, {new_seq, wal_entry})
      end
    end)

    final_seq = :counters.get(new_seq_ref, 1)

    %{target | version_vector: merged_vv, next_seq: final_seq}
  end

  # ---------------------------------------------------------------------------
  # full_3node_sync: two passes of all-pairs replication to guarantee
  # convergence regardless of write interleaving (mimics gossip protocol).
  # Note: modifies ETS in place; the returned structs carry updated metadata.
  # ---------------------------------------------------------------------------

  defp full_3node_sync(h1, h2, h3) do
    # Pass 1
    h1 = ets_replicate(h2, h1)
    h1 = ets_replicate(h3, h1)
    h2 = ets_replicate(h1, h2)
    h2 = ets_replicate(h3, h2)
    h3 = ets_replicate(h1, h3)
    h3 = ets_replicate(h2, h3)

    # Pass 2
    h1 = ets_replicate(h2, h1)
    h1 = ets_replicate(h3, h1)
    h2 = ets_replicate(h1, h2)
    h2 = ets_replicate(h3, h2)
    h3 = ets_replicate(h1, h3)
    _h3 = ets_replicate(h2, h3)

    {h1, h2}
  end

  # ---------------------------------------------------------------------------
  # Restore holon store from its WAL (crash-recovery simulation).
  # The WAL is the durable record; the ETS store is the volatile cache.
  # ---------------------------------------------------------------------------

  defp restore_from_wal(holon) do
    wal_entries = wal_all(holon)

    # Replay WAL in sequence order — last write per key wins (natural replay order)
    Enum.each(wal_entries, fn %{key: k, value: v, vv: vv, node_id: nid} ->
      :ets.insert(holon.store_table, {k, v, vv, nid})
    end)

    holon
  end

  # ---------------------------------------------------------------------------
  # WAL helpers
  # ---------------------------------------------------------------------------

  defp wal_all(%{wal_table: wt}) do
    :ets.tab2list(wt)
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(&elem(&1, 1))
  end

  # ---------------------------------------------------------------------------
  # Conflict detection: compare per-key VV entries on two holons.
  # Returns :conflict if both have the key and vectors are concurrent,
  # :no_conflict otherwise.
  # ---------------------------------------------------------------------------

  defp detect_conflict(holon_a, holon_b, key) do
    entry_a =
      case :ets.lookup(holon_a.store_table, key) do
        [{^key, _v, vv, _nid}] -> vv
        [] -> nil
      end

    entry_b =
      case :ets.lookup(holon_b.store_table, key) do
        [{^key, _v, vv, _nid}] -> vv
        [] -> nil
      end

    case {entry_a, entry_b} do
      {nil, _} ->
        :no_conflict

      {_, nil} ->
        :no_conflict

      {vv_a, vv_b} ->
        if vv_dominates?(vv_a, vv_b) or vv_dominates?(vv_b, vv_a) do
          :no_conflict
        else
          :conflict
        end
    end
  end

  # ---------------------------------------------------------------------------
  # ETS store dump — returns a plain map of key → value for assertions.
  # ---------------------------------------------------------------------------

  defp ets_dump_store(%{store_table: tbl}) do
    :ets.tab2list(tbl)
    |> Map.new(fn {k, v, _vv, _nid} -> {k, v} end)
  end

  # ---------------------------------------------------------------------------
  # Version vector helpers
  # ---------------------------------------------------------------------------

  defp vv_new, do: %{}

  defp vv_increment(vv, node) do
    Map.update(vv, node, 1, &(&1 + 1))
  end

  defp vv_merge(vv_a, vv_b) do
    all_keys = (Map.keys(vv_a) ++ Map.keys(vv_b)) |> Enum.uniq()
    Map.new(all_keys, fn k -> {k, max(Map.get(vv_a, k, 0), Map.get(vv_b, k, 0))} end)
  end

  defp vv_dominates?(vv_a, vv_b) do
    all_keys = (Map.keys(vv_a) ++ Map.keys(vv_b)) |> Enum.uniq()

    all_gte =
      Enum.all?(all_keys, fn k ->
        Map.get(vv_a, k, 0) >= Map.get(vv_b, k, 0)
      end)

    at_least_one_gt =
      Enum.any?(all_keys, fn k ->
        Map.get(vv_a, k, 0) > Map.get(vv_b, k, 0)
      end)

    all_gte and at_least_one_gt
  end

  # ---------------------------------------------------------------------------
  # VV / clock accessors
  # ---------------------------------------------------------------------------

  defp get_node_clock(%{version_vector: vv}, node) when is_atom(node),
    do: Map.get(vv, node, 0)

  defp get_node_clock(%{version_vector: vv, id: id}, nil),
    do: Map.get(vv, id, 0)

  defp get_node_clock(%{version_vector: vv, id: id}),
    do: Map.get(vv, id, 0)

  defp get_vv(%{version_vector: vv}), do: vv
end
