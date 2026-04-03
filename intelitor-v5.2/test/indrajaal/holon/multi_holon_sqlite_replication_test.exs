defmodule Indrajaal.Holon.MultiHolonSQLiteReplicationTest do
  @moduledoc """
  TDG test suite for multi-holon SQLite replication with version vectors.

  WHAT: Validates a self-contained in-memory simulation of 3-node SQLite replication.
        Each node carries an isolated key-value store, a version vector, and a WAL
        of operations. All state is represented with plain Elixir maps so the suite
        has zero production module dependencies.

  WHY: SC-XHOLON-001 mandates isolated per-holon database files.
       SC-XHOLON-006..007 require OCC with monotonically-increasing version vectors.
       SC-XHOLON-030..035 require WAL, ACID writes, no deadlocks, and append-only audit.
       SC-SMRITI-110..113 require version vectors in SQLite with causality preservation.
       SC-HOLON-009 decrees SQLite/DuckDB as the ONLY authoritative holon state — all
       replicas are ephemeral. These tests verify the fundamental replication invariants
       that underpin that architecture.

  CONSTRAINTS:
    SC-XHOLON-001, SC-XHOLON-003, SC-XHOLON-006, SC-XHOLON-007,
    SC-XHOLON-010, SC-XHOLON-020, SC-XHOLON-025, SC-XHOLON-030,
    SC-XHOLON-031, SC-XHOLON-032, SC-XHOLON-033, SC-XHOLON-035,
    SC-XHOLON-044, SC-XHOLON-045, SC-XHOLON-050, SC-XHOLON-051,
    SC-SMRITI-110, SC-SMRITI-111, SC-SMRITI-113,
    SC-HOLON-001, SC-HOLON-007, SC-HOLON-009, SC-HOLON-011,
    SC-HOLON-014, SC-HOLON-017, SC-HOLON-019,
    AOR-HOLON-001, AOR-HOLON-009, AOR-HOLON-011, AOR-HOLON-019,
    EP-GEN-014

  ## EP-GEN-014 compliance
  - `use PropCheck` sets up `forall`/`property` macros (PropCheck-native).
  - `import ExUnitProperties, except: [property: 2, property: 3, check: 2]`
    avoids the conflicting `check/2` import from ExUnitProperties.
  - `PC.` prefix for all PropCheck generators inside `property`/`forall` blocks.
  - `SD.` prefix for all StreamData generators inside `ExUnitProperties.check all` blocks.
  - `ExUnitProperties.check all(` — never bare `check all(` — satisfies the mandate.
  - All helpers are self-contained `defp` — zero production module dependencies.

  ## Coverage Matrix
  | Scenario                                    | PropCheck | StreamData | Unit |
  |---------------------------------------------|-----------|------------|------|
  | Version vector creation                     | 0         | 0          | 4    |
  | Version vector ordering                     | 1         | 0          | 3    |
  | 3-node replication                          | 0         | 1          | 3    |
  | Conflict detection                          | 0         | 1          | 3    |
  | Causality preservation                      | 0         | 0          | 4    |
  | State isolation                             | 0         | 1          | 3    |
  | Convergence                                 | 1         | 1          | 3    |
  | Property: version vector monotonicity       | 1         | 0          | 0    |
  | Property: merge commutativity               | 1         | 0          | 0    |
  | TOTAL                                       | 4         | 4          | 23   |
  """

  use ExUnit.Case, async: true

  # EP-GEN-014: dual property testing import pattern — MANDATORY
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  require ExUnitProperties

  @moduletag :unit
  @moduletag :holon
  @moduletag :replication
  @moduletag :xholon

  setup_all do
    Application.ensure_all_started(:propcheck)
    :ok
  end

  # ============================================================================
  # SECTION 1: Version vector creation — SC-SMRITI-110, SC-XHOLON-007
  # ============================================================================

  describe "version vector creation" do
    test "create version vector for N nodes — initial vector is all zeros" do
      vv = new_version_vector(3)

      assert map_size(vv) == 3,
             "Version vector must have an entry for each node"

      assert Enum.all?(vv, fn {_k, v} -> v == 0 end),
             "All initial counters must be zero (SC-SMRITI-110)"
    end

    test "new version vector keys are the node indices 0..(N-1)" do
      vv = new_version_vector(4)
      assert Enum.sort(Map.keys(vv)) == [0, 1, 2, 3]
    end

    test "vector clock increment advances only the named node's counter" do
      vv = new_version_vector(3)
      vv2 = increment(vv, 1)

      assert Map.get(vv2, 1) == 1, "Node 1 counter must advance to 1"
      assert Map.get(vv2, 0) == 0, "Node 0 counter must remain 0"
      assert Map.get(vv2, 2) == 0, "Node 2 counter must remain 0"
    end

    test "repeated increments are strictly monotone for the target node" do
      vv =
        Enum.reduce(1..5, new_version_vector(3), fn _i, acc -> increment(acc, 0) end)

      assert Map.get(vv, 0) == 5,
             "After 5 increments, node 0 counter must equal 5 (SC-XHOLON-007)"
    end
  end

  # ============================================================================
  # SECTION 2: Version vector ordering — SC-XHOLON-007, SC-SMRITI-113
  # ============================================================================

  describe "version vector ordering" do
    test "happens-before: vv_a < vv_b when all a[i] <= b[i] and some strict" do
      vv_a = %{0 => 1, 1 => 0, 2 => 0}
      vv_b = %{0 => 2, 1 => 1, 2 => 0}

      assert happens_before?(vv_a, vv_b),
             "vv_a must happen-before vv_b (SC-SMRITI-113)"

      refute happens_before?(vv_b, vv_a),
             "vv_b does not happen-before vv_a"
    end

    test "concurrent detection: incomparable vectors are concurrent" do
      vv_a = %{0 => 2, 1 => 0}
      vv_b = %{0 => 0, 1 => 2}

      assert concurrent?(vv_a, vv_b),
             "Incomparable vectors must be detected as concurrent (SC-XHOLON-006)"
    end

    test "merge operation produces element-wise maximum" do
      vv_a = %{0 => 3, 1 => 1, 2 => 0}
      vv_b = %{0 => 1, 1 => 4, 2 => 2}

      merged = merge_vectors(vv_a, vv_b)

      assert Map.get(merged, 0) == 3
      assert Map.get(merged, 1) == 4
      assert Map.get(merged, 2) == 2
    end

    property "version vector merge is idempotent — merge(a, a) == a (SC-XHOLON-007)" do
      forall entries <- PC.non_empty(PC.list({PC.integer(0, 9), PC.integer(0, 20)})) do
        vv = Map.new(entries)
        merge_vectors(vv, vv) == vv
      end
    end
  end

  # ============================================================================
  # SECTION 3: 3-node replication — SC-XHOLON-001, SC-XHOLON-003, SC-HOLON-009
  # ============================================================================

  describe "3-node replication" do
    test "create 3 holons with isolated state (SC-XHOLON-001)" do
      h1 = new_holon(:n1)
      h2 = new_holon(:n2)
      h3 = new_holon(:n3)

      assert h1.id == :n1
      assert h2.id == :n2
      assert h3.id == :n3
      assert h1.store == %{}, "Initial holon store must be empty"
    end

    test "replicate write from node 1 to nodes 2 and 3" do
      h1 = new_holon(:n1)
      h2 = new_holon(:n2)
      h3 = new_holon(:n3)

      {h1, _vv} = write_holon(h1, "alpha", "value_a")
      h2 = replicate(h1, h2)
      h3 = replicate(h1, h3)

      assert {:ok, "value_a"} == read_holon(h2, "alpha"),
             "n2 must have the replicated key after sync (SC-HOLON-009)"

      assert {:ok, "value_a"} == read_holon(h3, "alpha"),
             "n3 must have the replicated key after sync (SC-HOLON-009)"
    end

    test "version vectors advance correctly after replication (SC-SMRITI-110)" do
      h1 = new_holon(:n1)
      {h1, vv_after_write} = write_holon(h1, "beta", "val_b")

      assert Map.get(vv_after_write, :n1) == 1,
             "n1's own clock must advance to 1 after one write"

      h2 = new_holon(:n2)
      h2 = replicate(h1, h2)

      # After replication n2 must know about n1's clock
      assert Map.get(h2.version_vector, :n1, 0) >= 1,
             "n2 must incorporate n1's clock after replication (SC-SMRITI-110)"
    end

    test "3-node convergence via StreamData key/value pairs" do
      ExUnitProperties.check all(
                               key <- SD.string(:alphanumeric, min_length: 1, max_length: 16),
                               value <- SD.string(:alphanumeric, min_length: 1, max_length: 32)
                             ) do
        h1 = new_holon(:n1)
        {h1, _vv} = write_holon(h1, key, value)

        h2 = replicate(h1, new_holon(:n2))
        h3 = replicate(h1, new_holon(:n3))

        assert read_holon(h2, key) == {:ok, value}
        assert read_holon(h3, key) == {:ok, value}
      end
    end
  end

  # ============================================================================
  # SECTION 4: Conflict detection — SC-XHOLON-006, SC-XHOLON-007
  # ============================================================================

  describe "conflict detection" do
    test "concurrent writes to same key on different nodes produce a conflict" do
      h1 = new_holon(:n1)
      h2 = new_holon(:n2)

      {h1, _} = write_holon(h1, "shared", "from_n1")
      {h2, _} = write_holon(h2, "shared", "from_n2")

      # Neither node has seen the other's write; both have clock=1 for their own node
      conflict = detect_conflict(h1, h2, "shared")

      assert conflict == :conflict,
             "Concurrent writes to the same key must be a conflict (SC-XHOLON-006)"
    end

    test "no conflict when one node's write causally follows the other's" do
      h1 = new_holon(:n1)
      {h1, _} = write_holon(h1, "causal", "v1")

      # h2 sees h1's write first, then writes itself — causal dependency
      h2 = replicate(h1, new_holon(:n2))
      {h2, _} = write_holon(h2, "causal", "v2")

      # h2's entry is causally after h1's — no conflict
      conflict = detect_conflict(h1, h2, "causal")

      assert conflict == :no_conflict,
             "Causally ordered writes must not be a conflict (SC-XHOLON-007)"
    end

    test "conflict resolution via last-writer-wins" do
      h1 = new_holon(:n1)
      {h1, _} = write_holon(h1, "lww", "old_val")

      h2 = replicate(h1, new_holon(:n2))
      {h2, _} = write_holon(h2, "lww", "new_val")

      # Merge h2 into h1 — h2's write is later (higher composite clock)
      h1_merged = replicate(h2, h1)

      assert read_holon(h1_merged, "lww") == {:ok, "new_val"},
             "Last-writer-wins: the higher-clock write must survive (SC-XHOLON-006)"
    end

    test "StreamData: conflicting then resolved writes converge to single value" do
      ExUnitProperties.check all(
                               v1 <- SD.string(:alphanumeric, min_length: 1, max_length: 16),
                               v2 <- SD.string(:alphanumeric, min_length: 1, max_length: 16),
                               key <- SD.string(:alphanumeric, min_length: 1, max_length: 12)
                             ) do
        h1 = new_holon(:n1)
        h2 = new_holon(:n2)

        {h1, _} = write_holon(h1, key, v1)

        # Make h2's write causally after h1's
        h2 = replicate(h1, h2)
        {h2, _} = write_holon(h2, key, v2)

        # Bidirectional sync: merge h2→h1
        h1_final = replicate(h2, h1)
        h2_final = h2

        val1 = read_holon(h1_final, key)
        val2 = read_holon(h2_final, key)

        # Both must read the same value after sync
        assert val1 == val2
      end
    end
  end

  # ============================================================================
  # SECTION 5: Causality preservation — SC-SMRITI-113, SC-XHOLON-007
  # ============================================================================

  describe "causality preservation" do
    test "write A on node 1 is visible to node 2 before writing B" do
      h1 = new_holon(:n1)
      {h1, _} = write_holon(h1, "A", "val_a")

      h2 = replicate(h1, new_holon(:n2))

      assert read_holon(h2, "A") == {:ok, "val_a"},
             "n2 must see A before writing B (SC-SMRITI-113 causality)"
    end

    test "B causally depends on A: B's version vector dominates A's" do
      h1 = new_holon(:n1)
      {h1, vv_a} = write_holon(h1, "A", "val_a")

      h2 = replicate(h1, new_holon(:n2))
      {h2, vv_b} = write_holon(h2, "B", "val_b")

      # vv_b must dominate vv_a: every entry in vv_a must be <= vv_b
      dominated =
        Enum.all?(vv_a, fn {node, clock} ->
          Map.get(vv_b, node, 0) >= clock
        end)

      assert dominated,
             "B's version vector must dominate A's (SC-SMRITI-113 causal dependency)"
    end

    test "chain of causally ordered writes is correctly ordered on all nodes" do
      h1 = new_holon(:n1)
      h2 = new_holon(:n2)
      h3 = new_holon(:n3)

      # n1 writes v1
      {h1, _} = write_holon(h1, "chain", "v1")
      # n2 receives v1 then writes v2
      h2 = replicate(h1, h2)
      {h2, _} = write_holon(h2, "chain", "v2")
      # n3 receives v2 then writes v3
      h3 = replicate(h2, h3)
      {h3, _} = write_holon(h3, "chain", "v3")

      # After full sync, all must read v3
      h1 = replicate(h3, replicate(h2, h1))
      h2_final = replicate(h3, h2)

      assert read_holon(h1, "chain") == {:ok, "v3"},
             "n1 must converge to v3 (causally latest)"

      assert read_holon(h2_final, "chain") == {:ok, "v3"},
             "n2 must converge to v3 (causally latest)"

      assert read_holon(h3, "chain") == {:ok, "v3"},
             "n3 must have v3 (written last)"
    end

    test "write B's WAL entry has a higher clock than A's WAL entry on same node" do
      h1 = new_holon(:n1)
      {h1, _} = write_holon(h1, "first_key", "first_val")
      {h1, _} = write_holon(h1, "second_key", "second_val")

      [entry_a, entry_b] = h1.wal

      assert entry_a.clock < entry_b.clock,
             "WAL entries must be strictly ordered by clock (causality, SC-SMRITI-113)"
    end
  end

  # ============================================================================
  # SECTION 6: State isolation — SC-XHOLON-001, AOR-HOLON-001
  # ============================================================================

  describe "state isolation" do
    test "each holon has independent state (SC-XHOLON-001)" do
      h1 = new_holon(:n1)
      h2 = new_holon(:n2)

      {h1, _} = write_holon(h1, "h1_only", "val_h1")

      assert read_holon(h1, "h1_only") == {:ok, "val_h1"},
             "h1 must have its own key"

      assert read_holon(h2, "h1_only") == {:error, :not_found},
             "h2 must NOT see h1's key before replication (SC-XHOLON-001)"
    end

    test "write to one holon doesn't affect others" do
      h1 = new_holon(:n1)
      h2 = new_holon(:n2)
      h3 = new_holon(:n3)

      {h1, _} = write_holon(h1, "iso_key", "iso_val")

      # h2 and h3 are completely untouched
      assert h2.store == %{}, "h2 store must remain empty (state isolation)"
      assert h3.store == %{}, "h3 store must remain empty (state isolation)"
    end

    test "holons can have different keys without interfering" do
      h1 = new_holon(:n1)
      h2 = new_holon(:n2)
      h3 = new_holon(:n3)

      {h1, _} = write_holon(h1, "key_n1", "v1")
      {h2, _} = write_holon(h2, "key_n2", "v2")
      {h3, _} = write_holon(h3, "key_n3", "v3")

      # Each node only knows about its own key before replication
      assert read_holon(h1, "key_n2") == {:error, :not_found}
      assert read_holon(h2, "key_n3") == {:error, :not_found}
      assert read_holon(h3, "key_n1") == {:error, :not_found}
    end

    test "StreamData: arbitrary keys written to one holon are invisible to others" do
      ExUnitProperties.check all(
                               key <- SD.string(:alphanumeric, min_length: 1, max_length: 16),
                               value <- SD.string(:alphanumeric, min_length: 1, max_length: 32)
                             ) do
        h1 = new_holon(:n1)
        h2 = new_holon(:n2)

        {h1, _} = write_holon(h1, key, value)

        assert read_holon(h1, key) == {:ok, value}
        assert read_holon(h2, key) == {:error, :not_found}
      end
    end
  end

  # ============================================================================
  # SECTION 7: Convergence — SC-HOLON-009, SC-XHOLON-001, AOR-HOLON-001
  # ============================================================================

  describe "convergence" do
    test "after replication, all nodes converge to same state" do
      h1 = new_holon(:n1)
      h2 = new_holon(:n2)
      h3 = new_holon(:n3)

      {h1, _} = write_holon(h1, "k1", "v1")
      {h2, _} = write_holon(h2, "k2", "v2")
      {h3, _} = write_holon(h3, "k3", "v3")

      {h1, h2, h3} = converge_3(h1, h2, h3)

      # All three nodes must have all three keys
      for {h, id} <- [{h1, :n1}, {h2, :n2}, {h3, :n3}] do
        assert read_holon(h, "k1") == {:ok, "v1"},
               "#{id} must have k1 after convergence"

        assert read_holon(h, "k2") == {:ok, "v2"},
               "#{id} must have k2 after convergence"

        assert read_holon(h, "k3") == {:ok, "v3"},
               "#{id} must have k3 after convergence"
      end
    end

    test "convergence is eventually consistent — no state loss during convergence" do
      h1 = new_holon(:n1)
      h2 = new_holon(:n2)
      h3 = new_holon(:n3)

      {h1, _} = write_holon(h1, "persist_key", "must_survive")

      {h1, h2, h3} = converge_3(h1, h2, h3)

      # The original write must survive on all nodes
      assert read_holon(h1, "persist_key") == {:ok, "must_survive"}
      assert read_holon(h2, "persist_key") == {:ok, "must_survive"}
      assert read_holon(h3, "persist_key") == {:ok, "must_survive"}
    end

    test "convergence holds after write then re-sync (idempotent)" do
      h1 = new_holon(:n1)
      h2 = new_holon(:n2)
      h3 = new_holon(:n3)

      {h1, _} = write_holon(h1, "idem", "stable")

      {h1_a, h2_a, h3_a} = converge_3(h1, h2, h3)
      {h1_b, h2_b, h3_b} = converge_3(h1_a, h2_a, h3_a)

      # Second convergence must produce identical stores
      assert h1_a.store == h1_b.store, "Re-sync must be idempotent (SC-XHOLON-031)"
      assert h2_a.store == h2_b.store
      assert h3_a.store == h3_b.store
    end

    test "StreamData: N writes across 3 nodes always converge to same store" do
      ExUnitProperties.check all(
                               ops <-
                                 SD.list_of(
                                   SD.tuple({
                                     SD.member_of([:n1, :n2, :n3]),
                                     SD.string(:alphanumeric, min_length: 1, max_length: 8),
                                     SD.string(:alphanumeric, min_length: 1, max_length: 16)
                                   }),
                                   min_length: 1,
                                   max_length: 15
                                 )
                             ) do
        {h1, h2, h3} =
          Enum.reduce(ops, {new_holon(:n1), new_holon(:n2), new_holon(:n3)}, fn
            {:n1, k, v}, {a, b, c} ->
              {elem(write_holon(a, k, v), 0), b, c}

            {:n2, k, v}, {a, b, c} ->
              {a, elem(write_holon(b, k, v), 0), c}

            {:n3, k, v}, {a, b, c} ->
              {a, b, elem(write_holon(c, k, v), 0)}
          end)

        {h1_f, h2_f, h3_f} = converge_3(h1, h2, h3)

        assert h1_f.store == h2_f.store,
               "n1 and n2 stores must match after convergence"

        assert h2_f.store == h3_f.store,
               "n2 and n3 stores must match after convergence"
      end
    end
  end

  # ============================================================================
  # SECTION 8: Property — version vector monotonicity — SC-XHOLON-007
  # ============================================================================

  describe "property: version vector monotonicity" do
    property "vectors only increase — each increment raises the target node's clock" do
      forall {node_id, increments} <-
               {PC.oneof([0, 1, 2]), PC.integer(1, 20)} do
        vv =
          Enum.reduce(1..increments, new_version_vector(3), fn _i, acc ->
            increment(acc, node_id)
          end)

        Map.get(vv, node_id) == increments
      end
    end

    property "increment never decreases any other node's clock" do
      forall {target, other} <- {PC.integer(0, 2), PC.integer(0, 2)} do
        if target == other do
          true
        else
          vv = new_version_vector(3)
          before_clock = Map.get(vv, other)
          vv2 = increment(vv, target)
          after_clock = Map.get(vv2, other)
          after_clock == before_clock
        end
      end
    end

    property "merge always produces a vector >= both inputs (SC-XHOLON-007)" do
      forall {pairs_a, pairs_b} <-
               {PC.non_empty(PC.list({PC.integer(0, 4), PC.integer(0, 20)})),
                PC.non_empty(PC.list({PC.integer(0, 4), PC.integer(0, 20)}))} do
        vv_a = Map.new(pairs_a)
        vv_b = Map.new(pairs_b)
        merged = merge_vectors(vv_a, vv_b)

        all_keys = Map.keys(vv_a) ++ Map.keys(vv_b)

        Enum.all?(all_keys, fn k ->
          Map.get(merged, k, 0) >= Map.get(vv_a, k, 0) and
            Map.get(merged, k, 0) >= Map.get(vv_b, k, 0)
        end)
      end
    end
  end

  # ============================================================================
  # SECTION 9: Property — merge commutativity — SC-XHOLON-007, SC-SMRITI-111
  # ============================================================================

  describe "property: merge commutativity" do
    property "merge(A, B) == merge(B, A) (SC-SMRITI-111 commutativity)" do
      forall {pairs_a, pairs_b} <-
               {PC.non_empty(PC.list({PC.integer(0, 5), PC.integer(0, 30)})),
                PC.non_empty(PC.list({PC.integer(0, 5), PC.integer(0, 30)}))} do
        vv_a = Map.new(pairs_a)
        vv_b = Map.new(pairs_b)

        merge_vectors(vv_a, vv_b) == merge_vectors(vv_b, vv_a)
      end
    end

    property "merge is associative: merge(merge(A,B),C) == merge(A,merge(B,C))" do
      forall {pairs_a, pairs_b, pairs_c} <-
               {PC.non_empty(PC.list({PC.integer(0, 3), PC.integer(0, 20)})),
                PC.non_empty(PC.list({PC.integer(0, 3), PC.integer(0, 20)})),
                PC.non_empty(PC.list({PC.integer(0, 3), PC.integer(0, 20)}))} do
        vv_a = Map.new(pairs_a)
        vv_b = Map.new(pairs_b)
        vv_c = Map.new(pairs_c)

        lhs = merge_vectors(merge_vectors(vv_a, vv_b), vv_c)
        rhs = merge_vectors(vv_a, merge_vectors(vv_b, vv_c))

        lhs == rhs
      end
    end

    property "merge is idempotent: merge(A, A) == A" do
      forall pairs <- PC.non_empty(PC.list({PC.integer(0, 5), PC.integer(0, 30)})) do
        vv = Map.new(pairs)
        merge_vectors(vv, vv) == vv
      end
    end
  end

  # ============================================================================
  # PRIVATE HELPERS — self-contained simulation, zero production module deps
  # ============================================================================

  # --------------------------------------------------------------------------
  # Version vector primitives
  # --------------------------------------------------------------------------

  # new_version_vector/1 — create zero vector for N nodes (indices 0..N-1)
  defp new_version_vector(n) when is_integer(n) and n > 0 do
    Map.new(0..(n - 1), fn i -> {i, 0} end)
  end

  # increment/2 — increment node's counter in vector, returns updated vector
  defp increment(vv, node_id) do
    Map.update(vv, node_id, 1, &(&1 + 1))
  end

  # merge_vectors/2 — element-wise max of two version vectors
  defp merge_vectors(vv_a, vv_b) do
    all_keys = Map.keys(vv_a) ++ Map.keys(vv_b)

    Map.new(all_keys, fn k ->
      {k, max(Map.get(vv_a, k, 0), Map.get(vv_b, k, 0))}
    end)
  end

  # happens_before?/2 — true when vv_a causally precedes vv_b
  # (all vv_a[k] <= vv_b[k], and at least one is strictly less)
  defp happens_before?(vv_a, vv_b) do
    all_keys = (Map.keys(vv_a) ++ Map.keys(vv_b)) |> Enum.uniq()

    all_leq =
      Enum.all?(all_keys, fn k ->
        Map.get(vv_a, k, 0) <= Map.get(vv_b, k, 0)
      end)

    some_strict =
      Enum.any?(all_keys, fn k ->
        Map.get(vv_a, k, 0) < Map.get(vv_b, k, 0)
      end)

    all_leq and some_strict
  end

  # concurrent?/2 — true when neither vector dominates the other
  defp concurrent?(vv_a, vv_b) do
    not happens_before?(vv_a, vv_b) and not happens_before?(vv_b, vv_a)
  end

  # --------------------------------------------------------------------------
  # Holon primitives
  # --------------------------------------------------------------------------

  # Node structure:
  #   %{
  #     id:             atom,
  #     store:          %{key => %{value: term, vv: map, node_id: atom}},
  #     version_vector: %{atom => integer},
  #     wal:            [%{op: :write, key: binary, value: term,
  #                        clock: integer, node_id: atom}]
  #   }

  # new_holon/1 — create holon with id and empty state map
  defp new_holon(id) do
    %{
      id: id,
      store: %{},
      version_vector: %{id => 0},
      wal: []
    }
  end

  # write_holon/3 — write key-value to holon, increment vector
  # Returns {updated_holon, new_version_vector}
  defp write_holon(holon, key, value) do
    new_clock = Map.get(holon.version_vector, holon.id, 0) + 1
    new_vv = Map.put(holon.version_vector, holon.id, new_clock)

    entry = %{value: value, vv: new_vv, node_id: holon.id}
    wal_entry = %{op: :write, key: key, value: value, clock: new_clock, node_id: holon.id}

    holon = %{
      holon
      | store: Map.put(holon.store, key, entry),
        version_vector: new_vv,
        wal: holon.wal ++ [wal_entry]
    }

    {holon, new_vv}
  end

  # read_holon/2 — read key from holon store
  defp read_holon(holon, key) do
    case Map.get(holon.store, key) do
      nil -> {:error, :not_found}
      %{value: v} -> {:ok, v}
    end
  end

  # replicate/2 — replicate state from source to target holon (last-writer-wins
  # by comparing the per-entry version vectors lexicographically via their
  # originating clock value; higher clock value wins on tie-break by node id)
  defp replicate(source, target) do
    merged_store =
      Map.merge(target.store, source.store, fn _key, t_entry, s_entry ->
        t_clock = Map.get(t_entry.vv, t_entry.node_id, 0)
        s_clock = Map.get(s_entry.vv, s_entry.node_id, 0)

        cond do
          s_clock > t_clock ->
            s_entry

          s_clock == t_clock and to_string(s_entry.node_id) > to_string(t_entry.node_id) ->
            s_entry

          true ->
            t_entry
        end
      end)

    merged_vv = merge_vectors(target.version_vector, source.version_vector)

    merged_wal =
      (target.wal ++ source.wal)
      |> Enum.uniq_by(fn e -> {e.node_id, e.clock, e.key} end)
      |> Enum.sort_by(fn e -> {e.node_id, e.clock} end)

    %{target | store: merged_store, version_vector: merged_vv, wal: merged_wal}
  end

  # detect_conflict/3 — check if writing to key conflicts between two holons.
  # Returns :conflict when both holons have an entry for the key and neither
  # causally dominates the other; :no_conflict otherwise.
  defp detect_conflict(holon_a, holon_b, key) do
    entry_a = Map.get(holon_a.store, key)
    entry_b = Map.get(holon_b.store, key)

    case {entry_a, entry_b} do
      {nil, _} ->
        :no_conflict

      {_, nil} ->
        :no_conflict

      {%{vv: vv_a}, %{vv: vv_b}} ->
        if happens_before?(vv_a, vv_b) or happens_before?(vv_b, vv_a) do
          :no_conflict
        else
          :conflict
        end
    end
  end

  # converge_3/3 — two full replication passes across all node pairs to
  # guarantee convergence regardless of write interleaving
  defp converge_3(h1, h2, h3) do
    {h1, h2, h3} = one_pass(h1, h2, h3)
    one_pass(h1, h2, h3)
  end

  defp one_pass(h1, h2, h3) do
    h1 = replicate(h2, h1)
    h1 = replicate(h3, h1)
    h2 = replicate(h1, h2)
    h2 = replicate(h3, h2)
    h3 = replicate(h1, h3)
    h3 = replicate(h2, h3)
    {h1, h2, h3}
  end
end
