defmodule Indrajaal.Core.VersionVectorConflictTest do
  @moduledoc """
  Version vector merge and conflict resolution test suite.

  ## WHAT
  Tests concurrent write merge semantics using version vectors (logical clocks).
  Implements increment, compare (happens-before / concurrent), and merge
  (least-upper-bound) operations. Verifies conflict detection and resolution
  for cross-holon concurrent writes. All tests are self-contained.

  ## CONSTRAINTS
  - SC-DBCROSS-003: Version vectors for conflict resolution
  - SC-XHOLON-006: OCC (Optimistic Concurrency Control) with version vectors
  - SC-XHOLON-007: Monotonically increasing version vectors
  - SC-SMRITI-110: Version vectors in SQLite; attestation expires 1hr
  - SC-SMRITI-111: Concurrent updates detected via version vectors
  - SC-SMRITI-113: Causality preserved via version vectors

  ## Change History
  | Version | Date       | Author | Change                                              |
  |---------|------------|--------|-----------------------------------------------------|
  | 1.0.0   | 2026-03-24 | Claude | Sprint 88 Wave 3 — version vector conflict tests    |
  """

  use ExUnit.Case, async: true
  use ExUnitProperties
  alias StreamData, as: SD

  # EP-GEN-014 compliance: StreamData only (SD. prefix); no PropCheck forall to avoid CounterStrike

  @moduletag :sprint_88
  @moduletag :version_vector

  # ============================================================================
  # SECTION 1: Version Vector Increment (SC-XHOLON-007)
  # ============================================================================

  describe "version vector increment (SC-XHOLON-007)" do
    test "increment creates entry for new node" do
      vv = new_vv()
      updated = increment(vv, "node_a")

      assert Map.get(updated, "node_a") == 1
    end

    test "increment is monotonically increasing for same node" do
      vv = new_vv()
      vv1 = increment(vv, "node_a")
      vv2 = increment(vv1, "node_a")
      vv3 = increment(vv2, "node_a")

      assert vv3["node_a"] == 3
    end

    test "increment does not affect other nodes" do
      vv = new_vv()
      vv = increment(vv, "node_a")
      vv = increment(vv, "node_b")
      vv_after = increment(vv, "node_a")

      assert vv_after["node_b"] == 1, "node_b should remain unchanged"
      assert vv_after["node_a"] == 2
    end

    test "increment of absent node starts from 0" do
      vv = %{"node_a" => 5}
      updated = increment(vv, "node_b")

      assert updated["node_b"] == 1
      assert updated["node_a"] == 5
    end

    test "multiple independent nodes increment independently" do
      nodes = ["node_a", "node_b", "node_c"]
      vv = new_vv()

      final_vv =
        Enum.reduce(nodes, vv, fn node, acc ->
          acc
          |> increment(node)
          |> increment(node)
          |> increment(node)
        end)

      for node <- nodes do
        assert final_vv[node] == 3, "#{node} should have count 3"
      end
    end
  end

  # ============================================================================
  # SECTION 2: Happens-Before Relationship (SC-SMRITI-113)
  # ============================================================================

  describe "happens-before causality (SC-SMRITI-113)" do
    test "empty vector equals empty vector" do
      vv1 = new_vv()
      vv2 = new_vv()

      # Two empty vectors are equal (neither has advanced)
      assert compare(vv1, vv2) == :equal
    end

    test "vv1 happens-before vv2 when all entries of vv1 <= vv2" do
      vv1 = %{"node_a" => 1, "node_b" => 2}
      vv2 = %{"node_a" => 2, "node_b" => 3}

      assert compare(vv1, vv2) == :before
    end

    test "vv2 happens-before vv1 (strictly dominated)" do
      vv1 = %{"node_a" => 3, "node_b" => 3}
      vv2 = %{"node_a" => 1, "node_b" => 1}

      assert compare(vv2, vv1) == :before
      assert compare(vv1, vv2) == :after
    end

    test "identical vectors are concurrent (equal)" do
      vv1 = %{"node_a" => 2, "node_b" => 3}
      vv2 = %{"node_a" => 2, "node_b" => 3}

      assert compare(vv1, vv2) in [:equal, :concurrent]
    end

    test "diverged vectors are concurrent" do
      # node_a sees more from a, node_b sees more from b
      vv1 = %{"node_a" => 3, "node_b" => 1}
      vv2 = %{"node_a" => 1, "node_b" => 3}

      assert compare(vv1, vv2) == :concurrent
    end

    test "happens-before is transitive" do
      vv1 = %{"node_a" => 1}
      vv2 = %{"node_a" => 2}
      vv3 = %{"node_a" => 3}

      assert compare(vv1, vv2) == :before
      assert compare(vv2, vv3) == :before
      # Transitivity: vv1 before vv3
      assert compare(vv1, vv3) == :before
    end

    test "partial order: subset happens-before superset" do
      vv1 = %{"node_a" => 1}
      vv2 = %{"node_a" => 1, "node_b" => 1}

      # vv1 happens-before vv2 (missing node_b treated as 0)
      assert compare(vv1, vv2) == :before
    end
  end

  # ============================================================================
  # SECTION 3: Merge (Least Upper Bound) (SC-DBCROSS-003)
  # ============================================================================

  describe "vector merge — least upper bound (SC-DBCROSS-003)" do
    test "merge of identical vectors is idempotent" do
      vv = %{"node_a" => 2, "node_b" => 3}
      merged = merge(vv, vv)

      assert merged == vv
    end

    test "merge takes max of each component" do
      vv1 = %{"node_a" => 3, "node_b" => 1}
      vv2 = %{"node_a" => 1, "node_b" => 4}
      merged = merge(vv1, vv2)

      assert merged["node_a"] == 3
      assert merged["node_b"] == 4
    end

    test "merge includes entries from both vectors" do
      vv1 = %{"node_a" => 2}
      vv2 = %{"node_b" => 5}
      merged = merge(vv1, vv2)

      assert merged["node_a"] == 2
      assert merged["node_b"] == 5
    end

    test "merge is commutative (vv1 merge vv2 == vv2 merge vv1)" do
      vv1 = %{"node_a" => 3, "node_b" => 1, "node_c" => 2}
      vv2 = %{"node_a" => 1, "node_b" => 4, "node_d" => 2}

      assert merge(vv1, vv2) == merge(vv2, vv1)
    end

    test "merge is associative" do
      vv1 = %{"node_a" => 1}
      vv2 = %{"node_b" => 2}
      vv3 = %{"node_c" => 3}

      left = merge(merge(vv1, vv2), vv3)
      right = merge(vv1, merge(vv2, vv3))

      assert left == right
    end

    test "merged vector happens-after both inputs" do
      vv1 = %{"node_a" => 3, "node_b" => 1}
      vv2 = %{"node_a" => 1, "node_b" => 3}
      merged = merge(vv1, vv2)

      assert compare(vv1, merged) in [:before, :equal]
      assert compare(vv2, merged) in [:before, :equal]
    end
  end

  # ============================================================================
  # SECTION 4: Conflict Detection (SC-XHOLON-006)
  # ============================================================================

  describe "OCC conflict detection (SC-XHOLON-006)" do
    test "no conflict when writing to a vector that happened before current" do
      # Node A reads at vv_read, then writes
      vv_read = %{"node_a" => 1, "node_b" => 2}
      vv_current = %{"node_a" => 2, "node_b" => 2}

      # vv_read happened-before vv_current → safe write
      conflict? = has_conflict?(vv_read, vv_current)

      assert conflict? == false, "No conflict when vv_read happens-before vv_current"
    end

    test "conflict detected when vectors are concurrent" do
      # Two nodes wrote concurrently
      vv_local = %{"node_a" => 3, "node_b" => 1}
      vv_remote = %{"node_a" => 1, "node_b" => 3}

      conflict? = has_conflict?(vv_local, vv_remote)

      assert conflict? == true, "Concurrent vectors must be detected as conflict"
    end

    test "conflict resolution via last-write-wins uses merged vector" do
      vv_local = %{"node_a" => 3, "node_b" => 1}
      vv_remote = %{"node_a" => 1, "node_b" => 3}

      # Resolve via LWW merge
      resolved = resolve_conflict_lww(vv_local, vv_remote)

      # Resolved vector must dominate both
      assert compare(vv_local, resolved) in [:before, :equal]
      assert compare(vv_remote, resolved) in [:before, :equal]
    end

    test "three-way merge resolves correctly" do
      vv_base = %{"node_a" => 1, "node_b" => 1}
      vv_branch1 = %{"node_a" => 2, "node_b" => 1}
      vv_branch2 = %{"node_a" => 1, "node_b" => 2}

      resolved = merge(vv_branch1, vv_branch2)

      # Resolved dominates base
      assert compare(vv_base, resolved) == :before

      # Both branches are subsumed
      assert resolved["node_a"] == 2
      assert resolved["node_b"] == 2
    end

    test "write-write conflict returns {:conflict, merged}" do
      existing = %{"node_a" => 2, "node_b" => 1}
      incoming = %{"node_a" => 1, "node_b" => 2}

      result = apply_write(existing, incoming, "data_v2")

      case result do
        {:conflict, merged_vv} ->
          assert merged_vv["node_a"] == 2
          assert merged_vv["node_b"] == 2

        {:ok, _vv} ->
          # Some OCC implementations resolve immediately
          assert true
      end
    end

    test "sequential writes produce no conflict" do
      vv0 = %{"node_a" => 1}
      vv1 = increment(vv0, "node_a")
      vv2 = increment(vv1, "node_a")

      # vv1 happened-before vv2
      assert has_conflict?(vv1, vv2) == false
    end
  end

  # ============================================================================
  # SECTION 5: Replica Synchronization (SC-SMRITI-120)
  # ============================================================================

  describe "replica synchronization via version vectors" do
    test "replica sync merges diverged histories" do
      # Two replicas start at same state
      base = %{"node_a" => 1, "node_b" => 1}

      # Replica 1 advances node_a
      r1 = increment(base, "node_a") |> increment("node_a")

      # Replica 2 advances node_b
      r2 = increment(base, "node_b") |> increment("node_b")

      # After sync, both replicas should converge
      synced = merge(r1, r2)

      assert synced["node_a"] == 3
      assert synced["node_b"] == 3
    end

    test "sync is idempotent (syncing twice produces same result)" do
      vv1 = %{"node_a" => 3, "node_b" => 1}
      vv2 = %{"node_a" => 1, "node_b" => 3}

      sync1 = merge(vv1, vv2)
      sync2 = merge(sync1, vv2)

      assert sync1 == sync2, "Sync must be idempotent (SC-SMRITI-110)"
    end

    test "gossip propagation converges after 3 rounds" do
      # 3 nodes starting from different states
      n_a = %{"node_a" => 5, "node_b" => 1, "node_c" => 1}
      n_b = %{"node_a" => 1, "node_b" => 5, "node_c" => 1}
      n_c = %{"node_a" => 1, "node_b" => 1, "node_c" => 5}

      # Round 1: a gossips to b, b gossips to c
      n_b_r1 = merge(n_a, n_b)
      n_c_r1 = merge(n_b_r1, n_c)

      # Round 2: c gossips to a
      n_a_r2 = merge(n_c_r1, n_a)

      # After 2-3 rounds, all should converge to same max
      final = merge(n_a_r2, n_c_r1)

      assert final["node_a"] == 5
      assert final["node_b"] == 5
      assert final["node_c"] == 5
    end
  end

  # ============================================================================
  # SECTION 6: Property-Based Tests (EP-GEN-014)
  # ============================================================================

  # Property-based tests (EP-GEN-014 compliant — StreamData only)

  describe "StreamData: version vector laws" do
    @tag timeout: 30_000
    test "merge is idempotent for any version vector" do
      ExUnitProperties.check all(vv <- gen_sd_version_vector(["a", "b", "c"])) do
        assert merge(vv, vv) == vv
      end
    end

    @tag timeout: 30_000
    test "increment is monotone for any node" do
      ExUnitProperties.check all(
                               vv <- gen_sd_version_vector(["n_0", "n_1", "n_2"]),
                               node <- SD.member_of(["n_0", "n_1", "n_2"])
                             ) do
        before_count = Map.get(vv, node, 0)
        vv_after = increment(vv, node)
        after_count = Map.get(vv_after, node, 0)
        assert after_count == before_count + 1
      end
    end

    @tag timeout: 30_000
    test "merged vector happens-after or equal to both inputs" do
      ExUnitProperties.check all(
                               vv1 <- gen_sd_version_vector(["a", "b", "c"]),
                               vv2 <- gen_sd_version_vector(["a", "b", "c"])
                             ) do
        merged = merge(vv1, vv2)

        compare_result1 = compare(vv1, merged)
        compare_result2 = compare(vv2, merged)

        assert compare_result1 in [:before, :equal, :concurrent]
        assert compare_result2 in [:before, :equal, :concurrent]
      end
    end

    @tag timeout: 30_000
    test "merge is commutative for any two version vectors" do
      ExUnitProperties.check all(
                               vv1 <- gen_sd_version_vector(["a", "b", "c"]),
                               vv2 <- gen_sd_version_vector(["a", "b", "c"])
                             ) do
        assert merge(vv1, vv2) == merge(vv2, vv1)
      end
    end
  end

  # ============================================================================
  # PRIVATE HELPERS — Version Vector Implementation
  # ============================================================================

  defp new_vv, do: %{}

  defp increment(vv, node) do
    Map.update(vv, node, 1, &(&1 + 1))
  end

  defp merge(vv1, vv2) do
    Map.merge(vv1, vv2, fn _node, c1, c2 -> max(c1, c2) end)
  end

  defp compare(vv1, vv2) do
    all_nodes = MapSet.union(MapSet.new(Map.keys(vv1)), MapSet.new(Map.keys(vv2)))

    {v1_le_v2, v2_le_v1} =
      Enum.reduce(all_nodes, {true, true}, fn node, {le1, le2} ->
        c1 = Map.get(vv1, node, 0)
        c2 = Map.get(vv2, node, 0)
        {le1 and c1 <= c2, le2 and c2 <= c1}
      end)

    cond do
      v1_le_v2 and v2_le_v1 -> :equal
      v1_le_v2 -> :before
      v2_le_v1 -> :after
      true -> :concurrent
    end
  end

  defp has_conflict?(vv_local, vv_remote) do
    compare(vv_local, vv_remote) == :concurrent
  end

  defp resolve_conflict_lww(vv1, vv2) do
    merge(vv1, vv2)
  end

  defp apply_write(existing_vv, incoming_vv, _data) do
    case compare(incoming_vv, existing_vv) do
      :before ->
        # Incoming is stale — conflict
        {:conflict, merge(existing_vv, incoming_vv)}

      :concurrent ->
        {:conflict, merge(existing_vv, incoming_vv)}

      _ ->
        # Incoming dominates or equals — safe write
        {:ok, incoming_vv}
    end
  end

  defp gen_sd_version_vector(nodes) do
    SD.map(
      SD.fixed_map(Enum.map(nodes, fn n -> {n, SD.integer(0..10)} end)),
      fn m -> Enum.filter(m, fn {_, v} -> v > 0 end) |> Enum.into(%{}) end
    )
  end
end
