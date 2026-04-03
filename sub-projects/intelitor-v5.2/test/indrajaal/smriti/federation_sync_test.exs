defmodule Indrajaal.Smriti.FederationSyncTest do
  @moduledoc """
  WHAT: Tests for SMRITI version vector federation sync — 3-holon concurrent sync,
        conflict detection and resolution, causal ordering guarantees.
  WHY: SC-SMRITI-062 (version vector tracking), SC-SMRITI-063 (federation protocol),
       SC-SMRITI-110 (version vectors in SQLite), SC-SMRITI-111 (concurrent update detection).
  CONSTRAINTS: SC-SMRITI-062, SC-SMRITI-063, SC-SMRITI-110, SC-SMRITI-111, SC-SMRITI-113

  ## Constitutional Alignment
  - Ψ₁ (Regeneration): Version vectors enable state reconstruction from federation peers.
  - Ψ₂ (History): All evolution events must be recorded and causally ordered.
  - Ψ₃ (Verification): Hash chain integrity maintained through version vector merging.
  - Ψ₅ (Truthfulness): Conflict detection surfaces divergent state honestly.

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-03-23 | Claude Sonnet 4.6 | Sprint 88: Task 57d2f4c2 — add federation sync tests |
  """

  use ExUnit.Case, async: true
  use PropCheck

  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Smriti.Federation.VersionVector
  alias Indrajaal.Smriti.Federation.ReplicationEngine

  @moduletag :smriti
  @moduletag :sprint_88
  @moduletag :federation_sync

  # ---------------------------------------------------------------------------
  # Fixtures / helpers
  # ---------------------------------------------------------------------------

  # Create a VersionVector that has been incremented N times for a given node.
  defp vv_at(node_id, n) do
    base = VersionVector.new(node_id)
    Enum.reduce(1..n, base, fn _, acc -> VersionVector.increment(acc, node_id) end)
  end

  # Build a multi-node vector from a keyword list of {node_id, count}.
  defp build_vv(pairs) do
    Enum.reduce(pairs, %{}, fn {node_id, count}, acc ->
      node_vv = vv_at(node_id, count)
      VersionVector.merge(acc, node_vv)
    end)
  end

  # Simulate one holon syncing with a remote and returning its new state.
  defp sync_with(local_vv, remote_vv) do
    case ReplicationEngine.resolve_state(local_vv, remote_vv) do
      {:synced, vv} -> {:ok, :synced, vv}
      {:update_required, _delta} -> {:ok, :updated, VersionVector.merge(local_vv, remote_vv)}
      {:up_to_date, local} -> {:ok, :up_to_date, local}
      {:conflict, {local, remote}} -> {:conflict, {local, remote}}
    end
  end

  # ---------------------------------------------------------------------------
  # 1. VersionVector basics
  # ---------------------------------------------------------------------------

  describe "VersionVector primitives" do
    test "new/1 initializes a vector with the given node at counter 0" do
      vv = VersionVector.new("holon-a")
      assert is_map(vv)
      assert Map.fetch!(vv, "holon-a") == 0
    end

    test "increment/2 increases the counter for the specified node" do
      vv = VersionVector.new("holon-a")
      vv1 = VersionVector.increment(vv, "holon-a")
      assert Map.fetch!(vv1, "holon-a") == 1
    end

    test "increment/2 adds new nodes not yet present" do
      vv = VersionVector.new("holon-a")
      vv1 = VersionVector.increment(vv, "holon-b")
      assert Map.fetch!(vv1, "holon-b") == 1
    end

    test "increment/2 is monotonically increasing per node" do
      vv = VersionVector.new("holon-a")

      final =
        Enum.reduce(1..10, vv, fn _, acc -> VersionVector.increment(acc, "holon-a") end)

      assert Map.fetch!(final, "holon-a") == 10
    end

    test "merge/2 produces the element-wise maximum" do
      vv1 = build_vv([{"a", 3}, {"b", 1}])
      vv2 = build_vv([{"a", 1}, {"b", 5}, {"c", 2}])

      merged = VersionVector.merge(vv1, vv2)
      assert Map.get(merged, "a") >= 3
      assert Map.get(merged, "b") >= 5
      assert Map.get(merged, "c") >= 2
    end

    test "merge/2 is commutative" do
      vv1 = build_vv([{"a", 3}, {"b", 1}])
      vv2 = build_vv([{"a", 1}, {"b", 4}])

      assert VersionVector.merge(vv1, vv2) == VersionVector.merge(vv2, vv1)
    end

    test "merge/2 is idempotent" do
      vv = build_vv([{"a", 2}, {"b", 3}])
      assert VersionVector.merge(vv, vv) == vv
    end

    test "descends?/2 returns true when vv1 has all counters >= vv2" do
      vv1 = build_vv([{"a", 3}, {"b", 2}])
      vv2 = build_vv([{"a", 2}, {"b", 1}])

      assert VersionVector.descends?(vv1, vv2) == true
    end

    test "descends?/2 returns false when vv2 has a counter ahead of vv1" do
      vv1 = build_vv([{"a", 1}])
      vv2 = build_vv([{"a", 2}])

      assert VersionVector.descends?(vv1, vv2) == false
    end

    test "concurrent?/2 is true when neither vector dominates the other" do
      vv1 = build_vv([{"a", 2}, {"b", 1}])
      vv2 = build_vv([{"a", 1}, {"b", 2}])

      assert VersionVector.concurrent?(vv1, vv2) == true
    end

    test "concurrent?/2 is false when one vector dominates" do
      vv1 = build_vv([{"a", 2}, {"b", 2}])
      vv2 = build_vv([{"a", 1}, {"b", 1}])

      assert VersionVector.concurrent?(vv1, vv2) == false
    end

    test "to_string/1 returns a compact printable representation" do
      vv =
        VersionVector.new("holon-alpha")
        |> VersionVector.increment("holon-alpha")

      str = VersionVector.to_string(vv)
      assert is_binary(str)
      assert String.contains?(str, ":")
    end
  end

  # ---------------------------------------------------------------------------
  # 2. ReplicationEngine resolution logic
  # ---------------------------------------------------------------------------

  describe "ReplicationEngine.resolve_state/2" do
    test "returns {:synced, vv} for identical vectors" do
      vv = build_vv([{"a", 2}, {"b", 3}])
      assert {:synced, ^vv} = ReplicationEngine.resolve_state(vv, vv)
    end

    test "returns {:update_required, delta} when remote is ahead" do
      local = build_vv([{"a", 1}])
      remote = build_vv([{"a", 3}])

      assert {:update_required, delta} = ReplicationEngine.resolve_state(local, remote)
      assert Map.fetch!(delta, "a") == 3
    end

    test "returns {:up_to_date, local} when local is ahead" do
      local = build_vv([{"a", 5}])
      remote = build_vv([{"a", 2}])

      assert {:up_to_date, ^local} = ReplicationEngine.resolve_state(local, remote)
    end

    test "returns {:conflict, {local, remote}} for concurrent vectors" do
      local = build_vv([{"a", 3}, {"b", 1}])
      remote = build_vv([{"a", 1}, {"b", 3}])

      assert {:conflict, {^local, ^remote}} = ReplicationEngine.resolve_state(local, remote)
    end

    test "calculate_delta/2 returns only nodes remote is ahead on" do
      local = build_vv([{"a", 2}, {"b", 4}])
      remote = build_vv([{"a", 5}, {"b", 2}, {"c", 1}])

      delta = ReplicationEngine.calculate_delta(local, remote)
      # "a" remote 5 > local 2 → in delta
      assert Map.has_key?(delta, "a")
      assert Map.fetch!(delta, "a") == 5
      # "b" remote 2 <= local 4 → NOT in delta
      refute Map.has_key?(delta, "b")
      # "c" remote 1 > local 0 → in delta
      assert Map.has_key?(delta, "c")
    end

    test "calculate_delta/2 returns empty map when local is up-to-date" do
      vv = build_vv([{"a", 3}, {"b", 5}])
      delta = ReplicationEngine.calculate_delta(vv, vv)
      assert delta == %{}
    end
  end

  # ---------------------------------------------------------------------------
  # 3. Three-holon concurrent sync simulation
  # ---------------------------------------------------------------------------

  describe "3-holon concurrent federation sync" do
    # Topology:
    #   holon-1  <-->  holon-2  <-->  holon-3
    # Each holon makes independent writes, then syncs pairwise.
    # After full sync, all holons should reach the same merged state.

    test "three holons converge after sequential sync" do
      h1 = build_vv([{"holon-1", 3}])
      h2 = build_vv([{"holon-2", 2}])
      h3 = build_vv([{"holon-3", 4}])

      # h1 syncs with h2
      {:ok, _, h1_after_h2} = sync_with(h1, h2)
      # h1 (now merged with h2) syncs with h3
      {:ok, _, h1_final} = sync_with(h1_after_h2, h3)

      # h2 syncs with h1 and h3
      {:ok, _, h2_after_h1} = sync_with(h2, h1)
      {:ok, _, h2_final} = sync_with(h2_after_h1, h3)

      # h3 syncs with h1 final (already merged h1+h2+h3)
      {:ok, _, h3_final} = sync_with(h3, h1_final)

      # All three should now carry at least the max of each node's counter
      expected = VersionVector.merge(h1, VersionVector.merge(h2, h3))

      assert VersionVector.descends?(h1_final, expected)
      assert VersionVector.descends?(h2_final, expected)
      assert VersionVector.descends?(h3_final, expected)
    end

    test "concurrent writes on different nodes are detected as conflict" do
      # Two holons write to their own nodes concurrently (no sync between writes)
      h1 = VersionVector.new("holon-1") |> VersionVector.increment("holon-1")
      h2 = VersionVector.new("holon-2") |> VersionVector.increment("holon-2")

      assert {:conflict, _} = ReplicationEngine.resolve_state(h1, h2)
    end

    test "after conflict detection, merge produces a causal union" do
      h1 = build_vv([{"holon-1", 2}])
      h2 = build_vv([{"holon-2", 3}])

      {:conflict, {local, remote}} = ReplicationEngine.resolve_state(h1, h2)

      # Resolver can merge after conflict detection
      resolved = VersionVector.merge(local, remote)
      assert VersionVector.descends?(resolved, h1)
      assert VersionVector.descends?(resolved, h2)
    end

    test "sync is idempotent — re-syncing with same remote has no effect" do
      local = build_vv([{"holon-1", 3}, {"holon-2", 2}])
      remote = build_vv([{"holon-1", 3}, {"holon-2", 2}])

      assert {:synced, ^local} = ReplicationEngine.resolve_state(local, remote)
    end

    test "three-way pairwise sync reaches global consistency" do
      # Each holon starts with only its own node
      h1_init = VersionVector.new("h1") |> VersionVector.increment("h1")
      h2_init = VersionVector.new("h2") |> VersionVector.increment("h2")
      h3_init = VersionVector.new("h3") |> VersionVector.increment("h3")

      # Round 1: h1 merges h2, h2 merges h1
      h1_r1 = VersionVector.merge(h1_init, h2_init)
      h2_r1 = VersionVector.merge(h2_init, h1_init)

      # Round 2: h3 merges h1_r1 (which already has h1+h2 knowledge)
      h3_r2 = VersionVector.merge(h3_init, h1_r1)

      # Round 3: h1 merges h3_r2, bringing all 3 together
      h1_final = VersionVector.merge(h1_r1, h3_r2)
      h2_final = VersionVector.merge(h2_r1, h3_r2)
      h3_final = h3_r2

      # Global expected is element-wise max of all three
      global = VersionVector.merge(h1_init, VersionVector.merge(h2_init, h3_init))

      assert VersionVector.descends?(h1_final, global)
      assert VersionVector.descends?(h2_final, global)
      assert VersionVector.descends?(h3_final, global)
    end

    test "delta calculation guides partial sync efficiently" do
      # holon-1 knows about h1 and h2, holon-2 only knows h2 and h3
      h1_vv = build_vv([{"h1", 5}, {"h2", 3}])
      h2_vv = build_vv([{"h2", 3}, {"h3", 7}])

      delta = ReplicationEngine.calculate_delta(h1_vv, h2_vv)

      # Only h3 should be in delta (h1 doesn't know about it yet)
      assert Map.has_key?(delta, "h3")
      # h2 is equal, should not be in delta
      refute Map.has_key?(delta, "h2")
    end

    test "concurrent updates from 3 holons all detected" do
      h1 = build_vv([{"h1", 1}])
      h2 = build_vv([{"h2", 1}])
      h3 = build_vv([{"h3", 1}])

      # h1 vs h2 — concurrent
      assert VersionVector.concurrent?(h1, h2)
      # h1 vs h3 — concurrent
      assert VersionVector.concurrent?(h1, h3)
      # h2 vs h3 — concurrent
      assert VersionVector.concurrent?(h2, h3)

      # After global merge, the merged vector descends all
      global = VersionVector.merge(h1, VersionVector.merge(h2, h3))
      assert VersionVector.descends?(global, h1)
      assert VersionVector.descends?(global, h2)
      assert VersionVector.descends?(global, h3)
    end
  end

  # ---------------------------------------------------------------------------
  # 4. Causal ordering guarantees (SC-SMRITI-113)
  # ---------------------------------------------------------------------------

  describe "causal ordering (SC-SMRITI-113)" do
    test "descends? establishes partial order" do
      # If a → b → c, then c descends a
      a = VersionVector.new("n") |> VersionVector.increment("n")
      b = VersionVector.increment(a, "n")
      c = VersionVector.increment(b, "n")

      assert VersionVector.descends?(c, a)
      assert VersionVector.descends?(c, b)
      assert VersionVector.descends?(b, a)
      refute VersionVector.descends?(a, c)
    end

    test "causally preceding events are not concurrent" do
      ancestor = build_vv([{"n", 1}])
      descendant = build_vv([{"n", 3}])

      refute VersionVector.concurrent?(ancestor, descendant)
      refute VersionVector.concurrent?(descendant, ancestor)
    end

    test "merge preserves causal history" do
      # vv1 has seen events on node_a; vv2 has seen those plus more on node_b
      vv1 = build_vv([{"node_a", 3}])
      vv2 = VersionVector.merge(vv1, build_vv([{"node_b", 2}]))

      merged = VersionVector.merge(vv1, vv2)
      # merged descends from both inputs
      assert VersionVector.descends?(merged, vv1)
      assert VersionVector.descends?(merged, vv2)
    end

    test "resolve_state :update_required delta preserves all local progress" do
      local = build_vv([{"local_node", 5}])
      remote = build_vv([{"local_node", 5}, {"remote_node", 3}])

      {:update_required, delta} = ReplicationEngine.resolve_state(local, remote)
      # Delta should only contain remote_node (local already has full knowledge of local_node)
      assert Map.has_key?(delta, "remote_node")
      refute Map.has_key?(delta, "local_node")
    end

    test "full sync after divergence re-establishes causal consistency" do
      # Two holons diverge from a common ancestor
      common = build_vv([{"shared", 3}])
      branch_a = VersionVector.increment(common, "node_a")
      branch_b = VersionVector.increment(common, "node_b")

      # They are concurrent (both descend from common but neither descends the other)
      assert VersionVector.concurrent?(branch_a, branch_b)

      # After merge, the result descends both branches
      reconciled = VersionVector.merge(branch_a, branch_b)
      assert VersionVector.descends?(reconciled, branch_a)
      assert VersionVector.descends?(reconciled, branch_b)
    end
  end

  # ---------------------------------------------------------------------------
  # 5. Property tests (PropCheck)
  # ---------------------------------------------------------------------------

  describe "property tests — PropCheck" do
    property "merge is associative" do
      forall {n1, n2, n3, c1, c2, c3} <-
               {PC.non_empty(PC.utf8()), PC.non_empty(PC.utf8()), PC.non_empty(PC.utf8()),
                PC.pos_integer(), PC.pos_integer(), PC.pos_integer()} do
        vv1 = build_vv([{n1, c1}])
        vv2 = build_vv([{n2, c2}])
        vv3 = build_vv([{n3, c3}])

        left = VersionVector.merge(VersionVector.merge(vv1, vv2), vv3)
        right = VersionVector.merge(vv1, VersionVector.merge(vv2, vv3))
        left == right
      end
    end

    property "descends?(merge(a,b), a) is always true" do
      forall {n1, n2, c1, c2} <-
               {PC.non_empty(PC.utf8()), PC.non_empty(PC.utf8()), PC.pos_integer(),
                PC.pos_integer()} do
        vv_a = build_vv([{n1, c1}])
        vv_b = build_vv([{n2, c2}])
        merged = VersionVector.merge(vv_a, vv_b)

        VersionVector.descends?(merged, vv_a) and VersionVector.descends?(merged, vv_b)
      end
    end

    property "increment always increases counter" do
      forall {node_id, steps} <-
               {PC.non_empty(PC.utf8()), PC.range(1, 20)} do
        vv = VersionVector.new(node_id)

        final =
          Enum.reduce(1..steps, vv, fn _, acc -> VersionVector.increment(acc, node_id) end)

        Map.fetch!(final, node_id) == steps
      end
    end

    property "concurrent?/2 is symmetric" do
      forall {n1, n2, c1, c2} <-
               {PC.non_empty(PC.utf8()), PC.non_empty(PC.utf8()), PC.pos_integer(),
                PC.pos_integer()} do
        vv1 = build_vv([{n1, c1}])
        vv2 = build_vv([{n2, c2}])

        VersionVector.concurrent?(vv1, vv2) == VersionVector.concurrent?(vv2, vv1)
      end
    end

    property "resolved vector always descends both sides after merge" do
      forall {pairs1, pairs2} <-
               {PC.list(PC.tuple({PC.non_empty(PC.utf8()), PC.pos_integer()})),
                PC.list(PC.tuple({PC.non_empty(PC.utf8()), PC.pos_integer()}))} do
        vv1 =
          Enum.reduce(pairs1, %{}, fn {k, v}, acc ->
            build_vv([{k, v}]) |> then(&VersionVector.merge(acc, &1))
          end)

        vv2 =
          Enum.reduce(pairs2, %{}, fn {k, v}, acc ->
            build_vv([{k, v}]) |> then(&VersionVector.merge(acc, &1))
          end)

        if map_size(vv1) == 0 and map_size(vv2) == 0 do
          true
        else
          merged = VersionVector.merge(vv1, vv2)
          VersionVector.descends?(merged, vv1) and VersionVector.descends?(merged, vv2)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 6. Property tests (StreamData)
  # ---------------------------------------------------------------------------

  describe "property tests — StreamData" do
    test "merge idempotency holds for arbitrary vectors" do
      ExUnitProperties.check all(
                               n <- SD.string(:ascii, min_length: 1, max_length: 20),
                               c <- SD.integer(1..50)
                             ) do
        vv = build_vv([{n, c}])
        assert VersionVector.merge(vv, vv) == vv
      end
    end

    test "descends after increment is always true" do
      ExUnitProperties.check all(node <- SD.string(:ascii, min_length: 1, max_length: 20)) do
        vv_before = VersionVector.new(node)
        vv_after = VersionVector.increment(vv_before, node)
        assert VersionVector.descends?(vv_after, vv_before)
        refute VersionVector.descends?(vv_before, vv_after)
      end
    end

    test "resolve_state :synced when vectors are equal" do
      ExUnitProperties.check all(
                               n <- SD.string(:ascii, min_length: 1, max_length: 16),
                               c <- SD.integer(1..100)
                             ) do
        vv = build_vv([{n, c}])
        assert {:synced, ^vv} = ReplicationEngine.resolve_state(vv, vv)
      end
    end

    test "delta contains no entries when local equals remote" do
      ExUnitProperties.check all(
                               n <- SD.string(:ascii, min_length: 1, max_length: 16),
                               c <- SD.integer(1..100)
                             ) do
        vv = build_vv([{n, c}])
        delta = ReplicationEngine.calculate_delta(vv, vv)
        assert delta == %{}
      end
    end

    test "concurrent? is antisymmetric with descends?" do
      ExUnitProperties.check all(
                               n1 <- SD.string(:ascii, min_length: 1, max_length: 16),
                               n2 <- SD.string(:ascii, min_length: 1, max_length: 16),
                               c1 <- SD.integer(1..20),
                               c2 <- SD.integer(1..20)
                             ) do
        vv1 = build_vv([{n1, c1}])
        vv2 = build_vv([{n2, c2}])

        # At most one of these can be true: descends?(vv1,vv2) and concurrent?
        descends_1_2 = VersionVector.descends?(vv1, vv2)
        descends_2_1 = VersionVector.descends?(vv2, vv1)
        concurrent = VersionVector.concurrent?(vv1, vv2)

        # If concurrent, neither can fully descend the other
        if concurrent do
          refute descends_1_2 and descends_2_1
        end

        # If one fully descends the other, they can't be concurrent
        # (unless equal — equal means both descend each other AND concurrent is false)
        if descends_1_2 and descends_2_1 do
          refute concurrent
        end

        true
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 7. FMEA — federation failure modes
  # ---------------------------------------------------------------------------

  describe "FMEA — federation failure modes" do
    # RPN = Severity × Occurrence × Detection

    @tag :fmea
    test "FMEA-FED-001: stale remote vector does not overwrite newer local state (RPN=189)" do
      # Severity=7, Occurrence=3, Detection=9 — could silently rollback data
      stale_remote = build_vv([{"h1", 1}])
      fresh_local = build_vv([{"h1", 5}])

      result = ReplicationEngine.resolve_state(fresh_local, stale_remote)
      # Must NOT return :update_required when local is ahead
      assert {:up_to_date, _} = result
    end

    @tag :fmea
    test "FMEA-FED-002: conflict not silently swallowed (RPN=168)" do
      # Severity=8, Occurrence=3, Detection=7 — silent conflict → data loss
      h1_vv = build_vv([{"h1", 5}, {"h2", 1}])
      h2_vv = build_vv([{"h1", 1}, {"h2", 5}])

      result = ReplicationEngine.resolve_state(h1_vv, h2_vv)
      assert {:conflict, {_, _}} = result
    end

    @tag :fmea
    test "FMEA-FED-003: merge with empty vector is identity (RPN=63)" do
      # Severity=7, Occurrence=3, Detection=3
      vv = build_vv([{"h1", 3}, {"h2", 2}])
      empty = %{}

      merged = VersionVector.merge(vv, empty)
      # Result must still descend from vv (no data lost)
      assert VersionVector.descends?(merged, vv)
    end

    @tag :fmea
    test "FMEA-FED-004: delta with disjoint node sets returns all remote nodes (RPN=105)" do
      # Severity=7, Occurrence=5, Detection=3
      local = build_vv([{"local_only", 5}])
      remote = build_vv([{"remote_only", 3}])

      delta = ReplicationEngine.calculate_delta(local, remote)
      assert Map.has_key?(delta, "remote_only")
      refute Map.has_key?(delta, "local_only")
    end

    @tag :fmea
    test "FMEA-FED-005: resolve_state handles nil-like empty maps gracefully (RPN=84)" do
      # Severity=6, Occurrence=2, Detection=7 — boundary input
      empty1 = %{}
      empty2 = %{}

      result = ReplicationEngine.resolve_state(empty1, empty2)
      assert {:synced, %{}} = result
    end

    @tag :fmea
    test "FMEA-FED-006: merging after conflict does not lose either side's writes (RPN=126)" do
      # Severity=9, Occurrence=2, Detection=7 — data integrity critical
      h1_writes = build_vv([{"h1", 4}])
      h2_writes = build_vv([{"h2", 7}])

      {:conflict, {local, remote}} = ReplicationEngine.resolve_state(h1_writes, h2_writes)
      resolved = VersionVector.merge(local, remote)

      assert VersionVector.descends?(resolved, h1_writes)
      assert VersionVector.descends?(resolved, h2_writes)
    end
  end

  # ---------------------------------------------------------------------------
  # 8. Constitutional invariants (Ψ₀-Ψ₅)
  # ---------------------------------------------------------------------------

  describe "Constitutional Invariants" do
    test "Ψ₁ Regeneration: merged state enables full reconstruction from any peer" do
      # Each peer can regenerate the global state from its merged vector
      h1 = build_vv([{"h1", 3}])
      h2 = build_vv([{"h2", 5}])
      h3 = build_vv([{"h3", 2}])

      global = VersionVector.merge(h1, VersionVector.merge(h2, h3))

      # Any holon that has global can reconstruct total ordering
      assert VersionVector.descends?(global, h1)
      assert VersionVector.descends?(global, h2)
      assert VersionVector.descends?(global, h3)
    end

    test "Ψ₂ History: version counters only increase, never decrease" do
      vv = VersionVector.new("node")

      states =
        Enum.scan(1..10, vv, fn _, acc -> VersionVector.increment(acc, "node") end)

      counters = Enum.map(states, &Map.fetch!(&1, "node"))
      sorted = Enum.sort(counters)

      assert counters == sorted
    end

    test "Ψ₃ Verification: two vectors with same content resolve as :synced" do
      vv_a = build_vv([{"n1", 4}, {"n2", 2}, {"n3", 7}])
      vv_b = build_vv([{"n1", 4}, {"n2", 2}, {"n3", 7}])

      assert {:synced, _} = ReplicationEngine.resolve_state(vv_a, vv_b)
    end

    test "Ψ₅ Truthfulness: conflict resolution surfaces both divergent states accurately" do
      local = build_vv([{"writer_a", 10}, {"shared", 5}])
      remote = build_vv([{"writer_b", 8}, {"shared", 5}])

      {:conflict, {captured_local, captured_remote}} =
        ReplicationEngine.resolve_state(local, remote)

      assert captured_local == local
      assert captured_remote == remote
    end
  end
end
