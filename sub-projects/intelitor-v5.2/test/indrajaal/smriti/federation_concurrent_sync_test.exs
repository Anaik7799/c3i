defmodule Indrajaal.Smriti.FederationConcurrentSyncTest do
  @moduledoc """
  WHAT: ETS-simulated multi-holon concurrent federation sync — eventual consistency,
        conflict resolution, network partition + reconciliation scenarios.
  WHY:  SC-SMRITI-063 (federation protocol / gossip sync), SC-XHOLON-003 (cross-holon
        access via Zenoh only), SC-SMRITI-111 (concurrent update detection),
        SC-SMRITI-110 (version vectors in SQLite per holon).

  ## Design
  Each "holon" is represented by an ETS table keyed by `{holon_id, entry_key}`,
  storing `{value, version_vector}` pairs.  Sync operations are pure functions over
  ETS state — no GenServer, no Zenoh, no external I/O required.
  This isolates the *protocol* from the transport, matching the design of
  `ReplicationEngine` and `VersionVector`.

  ## Topology
  Three holons H1, H2, H3 represent distinct SQLite databases on different nodes.
  Network partitions are simulated by selectively preventing sync between holon pairs.

  ## Eventual Consistency Guarantee
  After any finite sequence of pairwise syncs that forms a connected spanning
  subgraph, all holons converge to the same state (element-wise maximum VV, union
  of all entries).

  ## Constitutional Alignment
  - Ψ₁ (Regeneration): After partition heals, every holon can reconstruct global state.
  - Ψ₂ (History): Write monotonicity — counters never go backward during sync.
  - Ψ₃ (Verification): VV equality after sync guarantees identical content.
  - Ψ₅ (Truthfulness): Conflicts are surfaced, not silently discarded.

  ## STAMP Constraints
  - SC-SMRITI-063: Gossip-based federation protocol simulated with pairwise sync
  - SC-SMRITI-110: Per-holon version vectors (ETS ↔ SQLite semantics)
  - SC-SMRITI-111: Concurrent updates detected before merge
  - SC-XHOLON-003: Cross-holon access is via an explicit sync function (not direct state)
  - SC-XHOLON-006: Optimistic concurrency control via version vectors
  - SC-XHOLON-007: Monotonically increasing version vectors enforced in assertions

  ## Change History
  | Version | Date       | Author            | Change                                  |
  |---------|------------|-------------------|-----------------------------------------|
  | 21.3.0  | 2026-03-24 | Claude Sonnet 4.6 | Sprint 88 — ETS multi-holon sync tests |
  """

  use ExUnit.Case, async: false
  use PropCheck

  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Smriti.Federation.VersionVector
  alias Indrajaal.Smriti.Federation.ReplicationEngine

  @moduletag :smriti
  @moduletag :sprint_88
  @moduletag :federation_concurrent

  # ---------------------------------------------------------------------------
  # ETS Holon Simulation
  # ---------------------------------------------------------------------------
  #
  # A "holon" has:
  #   - An ETS table (named by holon_id atom) of {entry_key, value, vv} triples
  #   - A "node vector" — the holon's own version vector (its causal clock)
  #
  # We store the node vector as a special entry under the key :__node_vv__.

  defp create_holon(holon_id) do
    table = :ets.new(holon_id, [:set, :public, :named_table])
    # Initialize node vector with this holon at 0
    :ets.insert(table, {:__node_vv__, VersionVector.new(Atom.to_string(holon_id))})
    table
  end

  defp destroy_holon(holon_id) do
    :ets.delete(holon_id)
  rescue
    _ -> :ok
  end

  defp get_node_vv(holon_id) do
    case :ets.lookup(holon_id, :__node_vv__) do
      [{:__node_vv__, vv}] -> vv
      [] -> %{}
    end
  end

  defp put_entry(holon_id, key, value) do
    node_str = Atom.to_string(holon_id)
    current_vv = get_node_vv(holon_id)
    new_vv = VersionVector.increment(current_vv, node_str)

    :ets.insert(holon_id, {:__node_vv__, new_vv})
    :ets.insert(holon_id, {key, value, new_vv})
    new_vv
  end

  defp get_entry(holon_id, key) do
    case :ets.lookup(holon_id, key) do
      [{^key, value, vv}] -> {:ok, value, vv}
      [] -> :not_found
    end
  end

  defp all_entries(holon_id) do
    :ets.tab2list(holon_id)
    # Use elem/2 to handle mixed-arity rows: entry rows are {key, value, vv} 3-tuples,
    # but the node-vector row is {__node_vv__, vv} a 2-tuple — pattern matching on
    # {k, _, _} would crash on the 2-tuple.
    |> Enum.reject(fn row -> elem(row, 0) == :__node_vv__ end)
    |> Enum.map(fn {key, value, vv} -> {key, value, vv} end)
  rescue
    _ -> []
  end

  # Sync FROM source INTO target.
  # For each entry in source:
  #   - If the entry does not exist in target, insert it.
  #   - If the entry exists and source VV descends target VV, update target.
  #   - If concurrent, mark as conflict (last-writer-wins by default in this simulation).
  # Returns {:ok, conflicts} where conflicts is a list of conflicting keys.
  defp sync_into(source_id, target_id) do
    source_entries = all_entries(source_id)
    source_node_vv = get_node_vv(source_id)

    conflicts =
      Enum.reduce(source_entries, [], fn {key, src_value, src_vv}, acc ->
        case get_entry(target_id, key) do
          :not_found ->
            # Target doesn't have this entry — insert it
            :ets.insert(target_id, {key, src_value, src_vv})
            acc

          {:ok, _tgt_value, tgt_vv} ->
            case ReplicationEngine.resolve_state(tgt_vv, src_vv) do
              {:synced, _} ->
                acc

              {:update_required, _delta} ->
                # Source is ahead — update target
                :ets.insert(target_id, {key, src_value, src_vv})
                acc

              {:up_to_date, _} ->
                # Target already has newer state — no action
                acc

              {:conflict, {_local, _remote}} ->
                # Last-writer-wins: source's write wins (deterministic resolution)
                :ets.insert(target_id, {key, src_value, src_vv})
                [key | acc]
            end
        end
      end)

    # Merge the node vectors so target knows about source's causal history
    target_node_vv = get_node_vv(target_id)
    merged_vv = VersionVector.merge(target_node_vv, source_node_vv)
    :ets.insert(target_id, {:__node_vv__, merged_vv})

    {:ok, conflicts}
  end

  # Check if two holons have converged (same entries, same values).
  defp converged?(h1, h2) do
    entries1 = all_entries(h1) |> Map.new(fn {k, v, _vv} -> {k, v} end)
    entries2 = all_entries(h2) |> Map.new(fn {k, v, _vv} -> {k, v} end)
    entries1 == entries2
  end

  # Check that h1's node vector descends h2's node vector
  defp vv_descends?(h1, h2) do
    vv1 = get_node_vv(h1)
    vv2 = get_node_vv(h2)
    VersionVector.descends?(vv1, vv2)
  end

  # ---------------------------------------------------------------------------
  # Setup / Teardown
  # ---------------------------------------------------------------------------

  setup do
    # Use unique test-run IDs to avoid ETS table name collisions in async runs.
    # (This module is async: false so ETS :named_table is safe.)
    test_id = :erlang.unique_integer([:positive, :monotonic])
    h1 = :"h1_#{test_id}"
    h2 = :"h2_#{test_id}"
    h3 = :"h3_#{test_id}"

    create_holon(h1)
    create_holon(h2)
    create_holon(h3)

    on_exit(fn ->
      destroy_holon(h1)
      destroy_holon(h2)
      destroy_holon(h3)
    end)

    %{h1: h1, h2: h2, h3: h3}
  end

  # ---------------------------------------------------------------------------
  # 1. Basic single-holon write semantics
  # ---------------------------------------------------------------------------

  describe "single-holon write semantics" do
    test "put_entry increments the holon's node vector", %{h1: h1} do
      vv_before = get_node_vv(h1)
      put_entry(h1, :key1, "value1")
      vv_after = get_node_vv(h1)

      assert VersionVector.descends?(vv_after, vv_before)
      refute VersionVector.descends?(vv_before, vv_after)
    end

    test "get_entry retrieves the written value with its causal vector", %{h1: h1} do
      put_entry(h1, :sensor_reading, 42)
      assert {:ok, 42, _vv} = get_entry(h1, :sensor_reading)
    end

    test "each sequential write advances the node vector strictly", %{h1: h1} do
      Enum.each(1..5, fn i -> put_entry(h1, :"key_#{i}", i) end)
      vv = get_node_vv(h1)
      node_str = Atom.to_string(h1)

      assert Map.get(vv, node_str) == 5
    end

    test "overwriting a key advances the node vector for conflict detection", %{h1: h1} do
      put_entry(h1, :shared_key, "first")
      vv1 = get_node_vv(h1)

      put_entry(h1, :shared_key, "second")
      vv2 = get_node_vv(h1)

      assert VersionVector.descends?(vv2, vv1)
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Pairwise sync — two holons
  # ---------------------------------------------------------------------------

  describe "pairwise sync — two holons" do
    test "syncing from source to target propagates new entries", %{h1: h1, h2: h2} do
      put_entry(h1, :doc_a, "content_a")

      {:ok, _conflicts} = sync_into(h1, h2)

      assert {:ok, "content_a", _vv} = get_entry(h2, :doc_a)
    end

    test "bidirectional sync achieves convergence", %{h1: h1, h2: h2} do
      put_entry(h1, :key_x, "from_h1")
      put_entry(h2, :key_y, "from_h2")

      # h1 syncs h2, then h2 syncs h1
      sync_into(h1, h2)
      sync_into(h2, h1)

      assert converged?(h1, h2)
    end

    test "sync is idempotent — repeating sync has no effect", %{h1: h1, h2: h2} do
      put_entry(h1, :key1, "v1")
      sync_into(h1, h2)

      entries_before = all_entries(h2)
      sync_into(h1, h2)
      entries_after = all_entries(h2)

      assert length(entries_before) == length(entries_after)
    end

    test "target keeps newer write when local is ahead", %{h1: h1, h2: h2} do
      # Simulate: h2 already has a newer write for the same key
      put_entry(h1, :key1, "old_value")
      # Sync first so h2 knows about key1
      sync_into(h1, h2)
      # Now h2 writes a newer value
      put_entry(h2, :key1, "new_value")
      # h1 tries to push old state back
      sync_into(h1, h2)

      # h2 must keep its own newer value (h2 vv is ahead for h2's node)
      assert {:ok, "new_value", _} = get_entry(h2, :key1)
    end

    test "node vectors merge correctly after bidirectional sync", %{h1: h1, h2: h2} do
      put_entry(h1, :k, "v")
      put_entry(h2, :m, "n")

      sync_into(h1, h2)
      sync_into(h2, h1)

      # After full sync, h1's VV must descend h2's VV and vice versa
      assert vv_descends?(h1, h2)
      assert vv_descends?(h2, h1)
    end
  end

  # ---------------------------------------------------------------------------
  # 3. Three-holon concurrent sync
  # ---------------------------------------------------------------------------

  describe "three-holon concurrent sync" do
    test "all three holons converge after full pairwise sync round", %{h1: h1, h2: h2, h3: h3} do
      put_entry(h1, :doc_1, "from_h1")
      put_entry(h2, :doc_2, "from_h2")
      put_entry(h3, :doc_3, "from_h3")

      # Round-robin sync: each holon syncs from every other
      sync_into(h1, h2)
      sync_into(h2, h1)
      sync_into(h1, h3)
      sync_into(h3, h1)
      sync_into(h2, h3)
      sync_into(h3, h2)

      assert converged?(h1, h2), "h1 and h2 should converge"
      assert converged?(h2, h3), "h2 and h3 should converge"
      assert converged?(h1, h3), "h1 and h3 should converge"
    end

    test "concurrent writes on different keys do NOT conflict", %{h1: h1, h2: h2, h3: h3} do
      # Each holon writes to a distinct key (no key overlap → no conflict possible)
      put_entry(h1, :unique_h1, "val1")
      put_entry(h2, :unique_h2, "val2")
      put_entry(h3, :unique_h3, "val3")

      sync_into(h1, h2)
      {:ok, conflicts_h2} = sync_into(h2, h1)
      {:ok, conflicts_h3} = sync_into(h1, h3)

      assert conflicts_h2 == [], "distinct keys must not conflict"
      assert conflicts_h3 == [], "distinct keys must not conflict"
    end

    test "concurrent writes to the same key are detected", %{h1: h1, h2: h2} do
      # Both holons write to the same key without prior sync
      put_entry(h1, :contested_key, "h1_value")
      put_entry(h2, :contested_key, "h2_value")

      # Verify the underlying VVs are concurrent
      {:ok, _h1_val, h1_vv} = get_entry(h1, :contested_key)
      {:ok, _h2_val, h2_vv} = get_entry(h2, :contested_key)

      assert VersionVector.concurrent?(h1_vv, h2_vv),
             "Same-key writes without sync must be concurrent"
    end

    test "after conflict and LWW resolution, merged state is self-consistent", %{h1: h1, h2: h2} do
      put_entry(h1, :ck, "v1")
      put_entry(h2, :ck, "v2")

      {:ok, conflicts} = sync_into(h1, h2)
      assert :ck in conflicts, "contested key must appear in conflicts list"

      # After LWW sync, h2 must have exactly one value for :ck (not both, not empty)
      assert {:ok, _, _} = get_entry(h2, :ck)
    end

    test "merging h1+h2 knowledge into h3 gives h3 awareness of all writes", %{
      h1: h1,
      h2: h2,
      h3: h3
    } do
      put_entry(h1, :a, 1)
      put_entry(h2, :b, 2)

      # h1 picks up h2's knowledge
      sync_into(h2, h1)
      # h3 syncs from h1 (which already knows about h2)
      sync_into(h1, h3)

      assert {:ok, 1, _} = get_entry(h3, :a)
      assert {:ok, 2, _} = get_entry(h3, :b)
    end
  end

  # ---------------------------------------------------------------------------
  # 4. Network partition and reconciliation
  # ---------------------------------------------------------------------------

  describe "network partition and reconciliation" do
    test "holons remain independently writable during partition", %{h1: h1, h2: h2} do
      # Initial sync to establish shared state
      put_entry(h1, :shared, "initial")
      sync_into(h1, h2)

      # --- PARTITION: h1 and h2 cannot sync ---
      put_entry(h1, :partition_h1, "only_h1_knows")
      put_entry(h2, :partition_h2, "only_h2_knows")

      # Each holon has its own state during partition
      assert {:ok, "only_h1_knows", _} = get_entry(h1, :partition_h1)
      assert :not_found = get_entry(h1, :partition_h2)
      assert :not_found = get_entry(h2, :partition_h1)
      assert {:ok, "only_h2_knows", _} = get_entry(h2, :partition_h2)
    end

    test "partition heals: full sync after disconnect achieves convergence", %{h1: h1, h2: h2} do
      put_entry(h1, :shared, "initial")
      sync_into(h1, h2)

      # Diverge during partition
      put_entry(h1, :only_h1, "h1_partition_write")
      put_entry(h2, :only_h2, "h2_partition_write")

      # --- HEAL PARTITION ---
      sync_into(h1, h2)
      sync_into(h2, h1)

      assert converged?(h1, h2), "holons must converge after partition heals"
    end

    test "writes during partition preserve causal monotonicity", %{h1: h1, h2: h2} do
      put_entry(h1, :base, "v0")
      sync_into(h1, h2)

      vv_h2_at_sync = get_node_vv(h2)

      # Both sides write during partition
      put_entry(h1, :x, "x1")
      put_entry(h2, :y, "y1")

      vv_h2_after_write = get_node_vv(h2)
      # h2's vector must have advanced during partition (monotone)
      assert VersionVector.descends?(vv_h2_after_write, vv_h2_at_sync)
    end

    test "three-way partition: h1‖h2, h2‖h3, then full sync converges all three", %{
      h1: h1,
      h2: h2,
      h3: h3
    } do
      # All three start disjoint (partition from the beginning)
      put_entry(h1, :from1, "data_1")
      put_entry(h2, :from2, "data_2")
      put_entry(h3, :from3, "data_3")

      # Heal: first h1 and h2 reconnect
      sync_into(h1, h2)
      sync_into(h2, h1)

      # Then h3 reconnects to h2 (which already has h1+h2)
      sync_into(h2, h3)
      sync_into(h3, h2)

      # h1 catches up from h3 (h3 now has everything)
      sync_into(h3, h1)

      assert converged?(h1, h3), "h1 must converge with h3 after full heal"
      assert converged?(h2, h3), "h2 must converge with h3 after full heal"
    end

    test "re-connecting a stale holon does not roll back a leader's newer state", %{
      h1: h1,
      h2: h2
    } do
      # h1 acts as leader; h2 fell behind (stale)
      put_entry(h1, :critical, "v1")
      sync_into(h1, h2)

      # h1 writes more; h2 is still offline
      put_entry(h1, :critical, "v2")
      put_entry(h1, :critical, "v3")

      # h2 reconnects and pushes its stale state to h1
      sync_into(h2, h1)

      # h1 must NOT regress to h2's older value
      {:ok, h1_val, _} = get_entry(h1, :critical)
      assert h1_val == "v3", "leader's latest write must not be overwritten by stale peer"
    end
  end

  # ---------------------------------------------------------------------------
  # 5. Eventual consistency
  # ---------------------------------------------------------------------------

  describe "eventual consistency" do
    test "any order of full sync rounds achieves convergence (3 holons)", %{
      h1: h1,
      h2: h2,
      h3: h3
    } do
      # Different sync order than the pairwise test above
      put_entry(h1, :ev1, "a")
      put_entry(h2, :ev2, "b")
      put_entry(h3, :ev3, "c")

      # Reversed order
      sync_into(h3, h2)
      sync_into(h2, h3)
      sync_into(h3, h1)
      sync_into(h1, h3)
      sync_into(h2, h1)
      sync_into(h1, h2)

      assert converged?(h1, h2)
      assert converged?(h2, h3)
    end

    test "idempotent sync: repeating all pairwise syncs does not change state", %{
      h1: h1,
      h2: h2,
      h3: h3
    } do
      put_entry(h1, :k1, "v1")
      put_entry(h2, :k2, "v2")
      put_entry(h3, :k3, "v3")

      # First full sync round
      sync_into(h1, h2)
      sync_into(h2, h1)
      sync_into(h1, h3)
      sync_into(h3, h1)
      sync_into(h2, h3)
      sync_into(h3, h2)

      snapshot_h1 = all_entries(h1) |> Enum.sort()
      snapshot_h2 = all_entries(h2) |> Enum.sort()

      # Second full sync round (idempotent)
      sync_into(h1, h2)
      sync_into(h2, h1)
      sync_into(h1, h3)
      sync_into(h3, h1)
      sync_into(h2, h3)
      sync_into(h3, h2)

      assert all_entries(h1) |> Enum.sort() == snapshot_h1
      assert all_entries(h2) |> Enum.sort() == snapshot_h2
    end

    test "writes after convergence propagate correctly in next sync", %{h1: h1, h2: h2} do
      # Establish baseline convergence
      put_entry(h1, :base, "v0")
      sync_into(h1, h2)
      sync_into(h2, h1)

      # New write after convergence
      put_entry(h1, :post_conv, "new_data")
      sync_into(h1, h2)

      assert {:ok, "new_data", _} = get_entry(h2, :post_conv)
    end
  end

  # ---------------------------------------------------------------------------
  # 6. Conflict resolution strategy
  # ---------------------------------------------------------------------------

  describe "conflict resolution (last-writer-wins)" do
    test "LWW preserves exactly one value per key after conflict", %{h1: h1, h2: h2} do
      put_entry(h1, :lww_key, "h1_wins")
      put_entry(h2, :lww_key, "h2_wins")

      # h1's write is pushed to h2 — LWW picks h1's value
      {:ok, conflicts} = sync_into(h1, h2)
      assert :lww_key in conflicts

      # Exactly one value must exist for the key
      assert {:ok, _, _} = get_entry(h2, :lww_key)
    end

    test "conflict detection does not corrupt unrelated entries", %{h1: h1, h2: h2} do
      put_entry(h1, :contested, "c1")
      put_entry(h1, :clean_h1, "safe_value")
      put_entry(h2, :contested, "c2")

      sync_into(h1, h2)

      # The clean entry from h1 must arrive intact
      assert {:ok, "safe_value", _} = get_entry(h2, :clean_h1)
    end

    test "self-sync produces no conflicts (idempotent)", %{h1: h1} do
      put_entry(h1, :k, "v")
      {:ok, conflicts} = sync_into(h1, h1)
      assert conflicts == []
    end
  end

  # ---------------------------------------------------------------------------
  # 7. Version vector monotonicity across sync
  # ---------------------------------------------------------------------------

  describe "version vector monotonicity across sync (SC-XHOLON-007)" do
    test "target's node vector never decreases after any sync", %{h1: h1, h2: h2} do
      put_entry(h2, :baseline, "v0")
      vv_before = get_node_vv(h2)

      put_entry(h1, :new_entry, "v1")
      sync_into(h1, h2)

      vv_after = get_node_vv(h2)

      # vv_after must dominate vv_before (no regression)
      assert VersionVector.descends?(vv_after, vv_before)
    end

    test "three sync rounds produce monotonically growing VVs at each holon", %{
      h1: h1,
      h2: h2,
      h3: h3
    } do
      vv_snapshots_h1 = []

      put_entry(h1, :r1, "v")
      vv_snapshots_h1 = [get_node_vv(h1) | vv_snapshots_h1]

      sync_into(h1, h2)
      sync_into(h2, h1)
      vv_snapshots_h1 = [get_node_vv(h1) | vv_snapshots_h1]

      put_entry(h3, :r2, "w")
      sync_into(h3, h1)
      vv_snapshots_h1 = [get_node_vv(h1) | vv_snapshots_h1]

      # Reversed (latest first) — check each consecutive pair
      vv_snapshots_h1
      |> Enum.reverse()
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [earlier, later] ->
        assert VersionVector.descends?(later, earlier),
               "VV must be monotone: #{inspect(later)} should descend #{inspect(earlier)}"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # 8. Property tests — PropCheck
  # ---------------------------------------------------------------------------

  describe "property tests — PropCheck" do
    property "sync_into is idempotent: repeating source→target yields same target state" do
      forall n_entries <- PC.range(0, 8) do
        tid = :"prop_idem_#{System.unique_integer([:positive])}"
        create_holon(tid)

        Enum.each(1..max(n_entries, 1), fn i -> put_entry(tid, :"k#{i}", "v#{i}") end)

        snap_before = all_entries(tid) |> Enum.sort()
        # Sync with itself is idempotent
        sync_into(tid, tid)
        snap_after = all_entries(tid) |> Enum.sort()

        destroy_holon(tid)
        snap_before == snap_after
      end
    end

    property "node vector descends its previous state after any writes" do
      forall n_writes <- PC.range(1, 15) do
        tid = :"prop_mono_#{System.unique_integer([:positive])}"
        create_holon(tid)

        vv_before = get_node_vv(tid)

        Enum.each(1..n_writes, fn i -> put_entry(tid, :"k#{i}", "v#{i}") end)
        vv_after = get_node_vv(tid)

        destroy_holon(tid)
        VersionVector.descends?(vv_after, vv_before)
      end
    end

    property "bidirectional sync between two holons achieves entry convergence" do
      forall {n_a, n_b} <- {PC.range(1, 6), PC.range(1, 6)} do
        ta = :"prop_conv_a_#{System.unique_integer([:positive])}"
        tb = :"prop_conv_b_#{System.unique_integer([:positive])}"

        create_holon(ta)
        create_holon(tb)

        Enum.each(1..n_a, fn i -> put_entry(ta, :"ta_#{i}", "a#{i}") end)
        Enum.each(1..n_b, fn i -> put_entry(tb, :"tb_#{i}", "b#{i}") end)

        sync_into(ta, tb)
        sync_into(tb, ta)

        result = converged?(ta, tb)

        destroy_holon(ta)
        destroy_holon(tb)

        result
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 9. Property tests — StreamData (EP-GEN-014 compliant)
  # ---------------------------------------------------------------------------

  describe "property tests — StreamData (EP-GEN-014)" do
    test "writes during partition maintain monotone VVs on both sides" do
      ExUnitProperties.check all(n_writes <- SD.integer(1..10)) do
        ta = :"sd_part_a_#{System.unique_integer([:positive])}"
        tb = :"sd_part_b_#{System.unique_integer([:positive])}"
        create_holon(ta)
        create_holon(tb)

        # Establish baseline
        put_entry(ta, :base, "shared")
        sync_into(ta, tb)

        vv_ta_before = get_node_vv(ta)
        vv_tb_before = get_node_vv(tb)

        # Both sides write independently (partition)
        Enum.each(1..n_writes, fn i ->
          put_entry(ta, :"ta_#{i}", "a#{i}")
          put_entry(tb, :"tb_#{i}", "b#{i}")
        end)

        assert VersionVector.descends?(get_node_vv(ta), vv_ta_before)
        assert VersionVector.descends?(get_node_vv(tb), vv_tb_before)

        destroy_holon(ta)
        destroy_holon(tb)
      end
    end

    test "after healing a partition, VV monotonicity is preserved" do
      ExUnitProperties.check all(n_writes <- SD.integer(1..8)) do
        ta = :"sd_heal_a_#{System.unique_integer([:positive])}"
        tb = :"sd_heal_b_#{System.unique_integer([:positive])}"
        create_holon(ta)
        create_holon(tb)

        Enum.each(1..n_writes, fn i -> put_entry(ta, :"k#{i}", "v#{i}") end)

        vv_tb_before_sync = get_node_vv(tb)
        sync_into(ta, tb)
        vv_tb_after_sync = get_node_vv(tb)

        assert VersionVector.descends?(vv_tb_after_sync, vv_tb_before_sync)

        destroy_holon(ta)
        destroy_holon(tb)
      end
    end

    test "three-holon full sync always achieves convergence" do
      ExUnitProperties.check all(
                               n1 <- SD.integer(1..5),
                               n2 <- SD.integer(1..5),
                               n3 <- SD.integer(1..5)
                             ) do
        t1 = :"sd_tri_1_#{System.unique_integer([:positive])}"
        t2 = :"sd_tri_2_#{System.unique_integer([:positive])}"
        t3 = :"sd_tri_3_#{System.unique_integer([:positive])}"

        create_holon(t1)
        create_holon(t2)
        create_holon(t3)

        Enum.each(1..n1, fn i -> put_entry(t1, :"t1_#{i}", "v") end)
        Enum.each(1..n2, fn i -> put_entry(t2, :"t2_#{i}", "w") end)
        Enum.each(1..n3, fn i -> put_entry(t3, :"t3_#{i}", "x") end)

        # Full pairwise sync
        sync_into(t1, t2)
        sync_into(t2, t1)
        sync_into(t1, t3)
        sync_into(t3, t1)
        sync_into(t2, t3)
        sync_into(t3, t2)

        result = converged?(t1, t2) and converged?(t2, t3)

        destroy_holon(t1)
        destroy_holon(t2)
        destroy_holon(t3)

        result
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 10. FMEA — concurrent sync failure modes
  # ---------------------------------------------------------------------------

  describe "FMEA — concurrent sync failure modes" do
    @tag :fmea
    test "FMEA-CS-001: stale sync must not roll back a leader's newer writes (RPN=224, S=8,O=7,D=4)",
         %{h1: h1, h2: h2} do
      # Severity=8: data loss, Occurrence=7: common in leader-follower setups
      put_entry(h1, :critical, "v1")
      sync_into(h1, h2)
      put_entry(h1, :critical, "v2")
      put_entry(h1, :critical, "v3")

      # Stale follower pushes old state
      sync_into(h2, h1)

      {:ok, val, _} = get_entry(h1, :critical)
      assert val == "v3", "leader value must not regress"
    end

    @tag :fmea
    test "FMEA-CS-002: concurrent write must not silently vanish (RPN=168, S=8,O=3,D=7)",
         %{h1: h1, h2: h2} do
      put_entry(h1, :contested, "left")
      put_entry(h2, :contested, "right")

      {:ok, conflicts} = sync_into(h1, h2)

      # The conflict must be detected (not silently discarded)
      assert :contested in conflicts
      # After LWW, the key must still exist (not deleted)
      assert {:ok, _, _} = get_entry(h2, :contested)
    end

    @tag :fmea
    test "FMEA-CS-003: empty source does not corrupt target (RPN=63, S=3,O=7,D=3)",
         %{h1: h1, h2: h2} do
      put_entry(h2, :important, "keep_me")
      vv_before = get_node_vv(h2)

      # h1 is empty; syncing it into h2 must not remove h2's data
      sync_into(h1, h2)

      assert {:ok, "keep_me", _} = get_entry(h2, :important)
      # h2's VV must not have decreased
      assert VersionVector.descends?(get_node_vv(h2), vv_before)
    end

    @tag :fmea
    test "FMEA-CS-004: partition healing must not lose writes from either side (RPN=189, S=9,O=3,D=7)",
         %{h1: h1, h2: h2} do
      put_entry(h1, :a, "from_h1")
      put_entry(h2, :b, "from_h2")

      # Heal partition
      sync_into(h1, h2)
      sync_into(h2, h1)

      # Both sides must have both entries
      assert {:ok, "from_h1", _} = get_entry(h1, :a)
      assert {:ok, "from_h2", _} = get_entry(h1, :b)
      assert {:ok, "from_h1", _} = get_entry(h2, :a)
      assert {:ok, "from_h2", _} = get_entry(h2, :b)
    end

    @tag :fmea
    test "FMEA-CS-005: node vector never wraps or goes negative after many syncs (RPN=126, S=9,O=2,D=7)",
         %{h1: h1, h2: h2} do
      Enum.each(1..50, fn i ->
        put_entry(h1, :"k#{i}", "v")
        sync_into(h1, h2)
      end)

      vv = get_node_vv(h2)

      Enum.each(vv, fn {_node, count} ->
        assert count >= 0, "VV counter must be non-negative"
      end)
    end
  end
end
