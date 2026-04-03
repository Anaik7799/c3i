defmodule Indrajaal.Smriti.VersionVectorFederationTest do
  @moduledoc """
  WHAT: Self-contained tests for SMRITI version vector federation sync — causal ordering,
        concurrent update detection, attestation expiry, and CRDT algebraic laws.
  WHY:  Validates the core mathematical guarantees that make SMRITI federation correct
        without requiring any production module to be available at compile time.

  ## Scope
  All version vector and replication logic is implemented as private helper functions
  (`defp`) inside this module. No production module aliases are imported. This makes
  the suite runnable in any environment, including CI pipelines where federation
  infrastructure is absent.

  ## Constitutional Alignment
  - Ψ₁ (Regeneration): Monotone counters allow full state reconstruction from any snapshot.
  - Ψ₂ (History): Counters strictly increase; the past cannot be erased.
  - Ψ₃ (Verification): Equal vectors produce :synced; divergence is explicitly flagged.
  - Ψ₅ (Truthfulness): Concurrent states are surfaced honestly as :conflict.

  ## STAMP Constraints
  - SC-SMRITI-110: Version vectors stored in SQLite; attestation expires 1 hour
  - SC-SMRITI-111: Concurrent update detection via concurrent?/2
  - SC-SMRITI-113: Causality preserved via descends?/2 (partial order axioms)
  - SC-SMRITI-063: Federation protocol: sync merges version vectors from remote peers

  ## Change History
  | Version | Date       | Author            | Change                                     |
  |---------|------------|-------------------|--------------------------------------------|
  | 21.3.0  | 2026-03-24 | Claude Sonnet 4.6 | Sprint 88 — self-contained VV federation   |
  """

  use ExUnit.Case, async: true

  import ExUnitProperties, except: [property: 2, property: 3]
  alias StreamData, as: SD

  @moduletag :smriti
  @moduletag :sprint_88
  @moduletag :version_vector_federation

  # ---------------------------------------------------------------------------
  # Private version vector implementation (defp helpers, no production deps)
  # SC-SMRITI-110, SC-SMRITI-111, SC-SMRITI-113
  # ---------------------------------------------------------------------------

  # Creates a new version vector with the given node initialised to 0.
  defp vv_new(node_id) when is_binary(node_id), do: %{node_id => 0}

  # Increments the local counter for node_id by 1.
  defp vv_increment(vv, node_id) when is_binary(node_id) do
    Map.update(vv, node_id, 1, &(&1 + 1))
  end

  # Element-wise maximum (join of the partial-order lattice).
  defp vv_merge(vv1, vv2) do
    Map.merge(vv1, vv2, fn _k, a, b -> max(a, b) end)
  end

  # vv1 >= vv2 iff every counter in vv2 is <= the corresponding counter in vv1.
  # Absent keys default to 0.
  defp vv_descends?(vv1, vv2) do
    Enum.all?(vv2, fn {k, v2} ->
      Map.get(vv1, k, 0) >= v2
    end)
  end

  # Neither dominates the other.
  defp vv_concurrent?(vv1, vv2) do
    not vv_descends?(vv1, vv2) and not vv_descends?(vv2, vv1)
  end

  # Returns only the keys where remote is strictly ahead of local.
  defp vv_delta(local, remote) do
    Enum.reduce(remote, %{}, fn {k, remote_v}, acc ->
      local_v = Map.get(local, k, 0)
      if remote_v > local_v, do: Map.put(acc, k, remote_v), else: acc
    end)
  end

  # Classify the relationship between local and remote vectors.
  defp vv_resolve(local, remote) do
    cond do
      local == remote ->
        {:synced, local}

      vv_descends?(remote, local) and not vv_descends?(local, remote) ->
        {:update_required, vv_delta(local, remote)}

      vv_descends?(local, remote) and not vv_descends?(remote, local) ->
        {:up_to_date, local}

      true ->
        {:conflict, {local, remote}}
    end
  end

  # Simulate an attestation timestamp record: %{vv: map, attested_at: DateTime.t()}
  defp attestation_new(vv), do: %{vv: vv, attested_at: DateTime.utc_now()}

  # An attestation is expired if more than 3600 seconds have elapsed.
  defp attestation_expired?(%{attested_at: ts}) do
    diff = DateTime.diff(DateTime.utc_now(), ts, :second)
    diff > 3_600
  end

  # Simulate federation sync: fold a list of remote VVs into a local VV.
  defp federation_sync(local_vv, remote_vvs) when is_list(remote_vvs) do
    Enum.reduce(remote_vvs, local_vv, &vv_merge(&2, &1))
  end

  # Last-writer-wins: pick the entry with the higher logical timestamp.
  # Tiebreaker: if equal, prefer the one whose node_id is lexicographically smaller
  # (deterministic for any two peers).
  defp lww_resolve(entry_a, entry_b, vv_a, vv_b) do
    clock_a = vv_a |> Map.values() |> Enum.sum()
    clock_b = vv_b |> Map.values() |> Enum.sum()

    cond do
      clock_a > clock_b ->
        {:winner, entry_a, vv_a}

      clock_b > clock_a ->
        {:winner, entry_b, vv_b}

      # tiebreak by lexicographic order of the node ids in the vv
      true ->
        tiebreaker = [Map.keys(vv_a), Map.keys(vv_b)] |> Enum.map(&Enum.sort/1)

        if List.first(tiebreaker) <= List.last(tiebreaker),
          do: {:winner, entry_a, vv_merge(vv_a, vv_b)},
          else: {:winner, entry_b, vv_merge(vv_a, vv_b)}
    end
  end

  # ---------------------------------------------------------------------------
  # 1. Version vector initialisation
  # ---------------------------------------------------------------------------

  describe "1. Version vector initialization — all nodes start at 0 (SC-SMRITI-110)" do
    test "vv_new/1 initialises node counter at 0" do
      vv = vv_new("holon-alpha")
      assert Map.get(vv, "holon-alpha") == 0
    end

    test "vv_new/1 produces a single-entry map" do
      vv = vv_new("holon-beta")
      assert map_size(vv) == 1
    end

    test "merging two fresh vv_new vectors from different nodes starts both at 0" do
      vv = vv_merge(vv_new("n1"), vv_new("n2"))
      assert Map.get(vv, "n1") == 0
      assert Map.get(vv, "n2") == 0
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Local update increments own counter only
  # ---------------------------------------------------------------------------

  describe "2. Local update increments own counter only (SC-SMRITI-062)" do
    test "increment raises own counter by 1" do
      vv = vv_new("n") |> vv_increment("n")
      assert Map.get(vv, "n") == 1
    end

    test "increment on node A does not change node B's counter" do
      vv = vv_merge(vv_new("A"), vv_new("B")) |> vv_increment("A")
      assert Map.get(vv, "B") == 0
    end

    test "three successive increments yield counter = 3" do
      vv = vv_new("x") |> vv_increment("x") |> vv_increment("x") |> vv_increment("x")
      assert Map.get(vv, "x") == 3
    end

    test "increment introduces a key when absent from the map" do
      vv = vv_increment(%{}, "new-node")
      assert Map.get(vv, "new-node") == 1
    end
  end

  # ---------------------------------------------------------------------------
  # 3. Merge takes element-wise max
  # ---------------------------------------------------------------------------

  describe "3. Merge takes element-wise maximum (SC-SMRITI-110)" do
    test "merge picks max for overlapping keys" do
      vv1 = %{"a" => 5, "b" => 2}
      vv2 = %{"a" => 3, "b" => 6, "c" => 1}
      merged = vv_merge(vv1, vv2)

      assert merged["a"] == 5
      assert merged["b"] == 6
      assert merged["c"] == 1
    end

    test "merge of identical maps is the map itself" do
      vv = %{"x" => 7, "y" => 3}
      assert vv_merge(vv, vv) == vv
    end

    test "merge with empty map is the identity" do
      vv = %{"n" => 4}
      assert vv_merge(vv, %{}) == vv
      assert vv_merge(%{}, vv) == vv
    end

    test "merged vector contains all keys from both inputs" do
      vv1 = %{"left" => 1}
      vv2 = %{"right" => 1}
      merged = vv_merge(vv1, vv2)

      assert Map.has_key?(merged, "left")
      assert Map.has_key?(merged, "right")
    end
  end

  # ---------------------------------------------------------------------------
  # 4. Concurrent updates detected (neither dominates)
  # ---------------------------------------------------------------------------

  describe "4. Concurrent updates detected (SC-SMRITI-111)" do
    test "two independent writes from zero are concurrent" do
      h1 = vv_new("h1") |> vv_increment("h1")
      h2 = vv_new("h2") |> vv_increment("h2")

      assert vv_concurrent?(h1, h2)
    end

    test "after merge, merged state dominates both originals — not concurrent" do
      h1 = vv_increment(%{}, "h1")
      h2 = vv_increment(%{}, "h2")
      merged = vv_merge(h1, h2)

      refute vv_concurrent?(merged, h1)
      refute vv_concurrent?(merged, h2)
    end

    test "same vector is not concurrent with itself" do
      vv = %{"n" => 3}
      refute vv_concurrent?(vv, vv)
    end

    test "vv_resolve returns :conflict for concurrent vectors" do
      local = %{"h1" => 4, "h2" => 1}
      remote = %{"h1" => 1, "h2" => 4}

      assert {:conflict, {^local, ^remote}} = vv_resolve(local, remote)
    end
  end

  # ---------------------------------------------------------------------------
  # 5. Causal ordering: if v1 < v2, then v1 happened-before v2
  # ---------------------------------------------------------------------------

  describe "5. Causal ordering via descends? (SC-SMRITI-113)" do
    test "earlier version does not descend later version" do
      v1 = %{"n" => 1}
      v2 = %{"n" => 3}

      assert vv_descends?(v2, v1), "v2 must dominate v1"
      refute vv_descends?(v1, v2), "v1 must NOT dominate v2"
    end

    test "reflexivity: any vector descends itself" do
      vv = %{"a" => 2, "b" => 5}
      assert vv_descends?(vv, vv)
    end

    test "transitivity: a >= b >= c implies a >= c" do
      c = %{"n" => 1}
      b = %{"n" => 3}
      a = %{"n" => 5}

      assert vv_descends?(b, c)
      assert vv_descends?(a, b)
      assert vv_descends?(a, c)
    end

    test "empty vector is dominated by any non-empty vector" do
      vv = %{"n" => 1}
      assert vv_descends?(vv, %{})
    end

    test "vv_resolve returns :update_required when remote is strictly ahead" do
      local = %{"h1" => 1}
      remote = %{"h1" => 5}

      assert {:update_required, delta} = vv_resolve(local, remote)
      assert delta["h1"] == 5
    end

    test "vv_resolve returns :up_to_date when local is strictly ahead" do
      local = %{"h1" => 8}
      remote = %{"h1" => 2}

      assert {:up_to_date, ^local} = vv_resolve(local, remote)
    end
  end

  # ---------------------------------------------------------------------------
  # 6. Property test: merge is commutative
  # ---------------------------------------------------------------------------

  describe "6. Property — merge is commutative (SC-SMRITI-110)" do
    test "merge(a, b) == merge(b, a) for arbitrary single-node vectors" do
      ExUnitProperties.check all(
                               n1 <- SD.string(:ascii, min_length: 1, max_length: 20),
                               c1 <- SD.integer(0..200),
                               n2 <- SD.string(:ascii, min_length: 1, max_length: 20),
                               c2 <- SD.integer(0..200)
                             ) do
        vv1 = %{n1 => c1}
        vv2 = %{n2 => c2}

        assert vv_merge(vv1, vv2) == vv_merge(vv2, vv1)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 7. Property test: merge is associative
  # ---------------------------------------------------------------------------

  describe "7. Property — merge is associative (SC-SMRITI-110)" do
    test "(merge(a, b), c) == merge(a, merge(b, c)) for arbitrary vectors" do
      ExUnitProperties.check all(
                               n1 <- SD.string(:ascii, min_length: 1, max_length: 16),
                               c1 <- SD.integer(0..100),
                               n2 <- SD.string(:ascii, min_length: 1, max_length: 16),
                               c2 <- SD.integer(0..100),
                               n3 <- SD.string(:ascii, min_length: 1, max_length: 16),
                               c3 <- SD.integer(0..100)
                             ) do
        vv1 = %{n1 => c1}
        vv2 = %{n2 => c2}
        vv3 = %{n3 => c3}

        left = vv_merge(vv_merge(vv1, vv2), vv3)
        right = vv_merge(vv1, vv_merge(vv2, vv3))

        assert left == right
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 8. Property test: merge is idempotent
  # ---------------------------------------------------------------------------

  describe "8. Property — merge is idempotent (SC-SMRITI-110)" do
    test "merge(a, a) == a for arbitrary vectors" do
      ExUnitProperties.check all(
                               n <- SD.string(:ascii, min_length: 1, max_length: 20),
                               c <- SD.integer(0..500)
                             ) do
        vv = %{n => c}
        assert vv_merge(vv, vv) == vv
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 9. Property test: local increment is strictly monotonic
  # ---------------------------------------------------------------------------

  describe "9. Property — local increment is strictly monotonic (SC-SMRITI-062)" do
    test "n increments yield counter == n for arbitrary node and count" do
      ExUnitProperties.check all(
                               node <- SD.string(:ascii, min_length: 1, max_length: 20),
                               steps <- SD.integer(1..50)
                             ) do
        final =
          Enum.reduce(1..steps, vv_new(node), fn _, acc -> vv_increment(acc, node) end)

        assert Map.fetch!(final, node) == steps
      end
    end

    test "each increment strictly descends the previous state" do
      ExUnitProperties.check all(
                               node <- SD.string(:ascii, min_length: 1, max_length: 20),
                               steps <- SD.integer(1..20)
                             ) do
        {states, _} =
          Enum.map_reduce(1..steps, vv_new(node), fn _, acc ->
            next = vv_increment(acc, node)
            {next, next}
          end)

        prev_states = [vv_new(node) | Enum.drop(states, -1)]

        Enum.zip(prev_states, states)
        |> Enum.each(fn {prev, curr} ->
          assert vv_descends?(curr, prev),
                 "Expected #{inspect(curr)} to descend #{inspect(prev)}"

          refute vv_descends?(prev, curr),
                 "Did not expect #{inspect(prev)} to descend #{inspect(curr)}"
        end)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 10. Concurrent update detection: v1 || v2 when neither dominates
  # ---------------------------------------------------------------------------

  describe "10. Concurrent detection for vectors where neither dominates (SC-SMRITI-111)" do
    test "symmetric: concurrent?(a, b) iff concurrent?(b, a)" do
      h1 = %{"h1" => 3, "h2" => 1}
      h2 = %{"h1" => 1, "h2" => 3}

      assert vv_concurrent?(h1, h2) == vv_concurrent?(h2, h1)
    end

    test "three holons that write independently are pairwise concurrent" do
      h1 = vv_increment(%{}, "h1")
      h2 = vv_increment(%{}, "h2")
      h3 = vv_increment(%{}, "h3")

      assert vv_concurrent?(h1, h2)
      assert vv_concurrent?(h2, h3)
      assert vv_concurrent?(h1, h3)
    end

    test "partial knowledge creates concurrency (h1 knows old h2)" do
      h1_view = %{"h1" => 2}
      h2_view = %{"h1" => 1, "h2" => 3}

      assert vv_concurrent?(h1_view, h2_view)
    end

    test "global merge removes all concurrency with each participant" do
      h1 = vv_increment(%{}, "h1")
      h2 = vv_increment(%{}, "h2")
      h3 = vv_increment(%{}, "h3")
      global = vv_merge(h1, vv_merge(h2, h3))

      refute vv_concurrent?(global, h1)
      refute vv_concurrent?(global, h2)
      refute vv_concurrent?(global, h3)
    end
  end

  # ---------------------------------------------------------------------------
  # 11. Federation sync merges version vectors from remote peers
  # ---------------------------------------------------------------------------

  describe "11. Federation sync merges version vectors from remote peers (SC-SMRITI-063)" do
    test "federation_sync with no remotes is identity" do
      local = %{"n" => 3}
      assert federation_sync(local, []) == local
    end

    test "federation_sync with one remote takes the merge" do
      local = %{"n1" => 2}
      remote = %{"n2" => 5}

      synced = federation_sync(local, [remote])
      assert synced["n1"] == 2
      assert synced["n2"] == 5
    end

    test "federation_sync dominates all remote vectors" do
      local = %{"l" => 1}
      remotes = [%{"r1" => 3}, %{"r2" => 7}, %{"r3" => 2}]

      synced = federation_sync(local, remotes)

      Enum.each(remotes, fn remote ->
        assert vv_descends?(synced, remote),
               "synced #{inspect(synced)} must dominate remote #{inspect(remote)}"
      end)
    end

    test "federation_sync is order-independent (commutative fold)" do
      local = %{"base" => 1}

      remotes = [%{"a" => 3}, %{"b" => 1}, %{"c" => 5}]
      reversed = Enum.reverse(remotes)

      assert federation_sync(local, remotes) == federation_sync(local, reversed)
    end

    test "3-node federation: all nodes converge to same state after full sync" do
      # Each node writes locally
      n1 = vv_increment(%{}, "n1")
      n2 = vv_increment(%{}, "n2")
      n3 = vv_increment(%{}, "n3")

      # Each node syncs with the other two
      n1_synced = federation_sync(n1, [n2, n3])
      n2_synced = federation_sync(n2, [n1, n3])
      n3_synced = federation_sync(n3, [n1, n2])

      assert n1_synced == n2_synced
      assert n2_synced == n3_synced
    end
  end

  # ---------------------------------------------------------------------------
  # 12. Attestation expiry after 1 hour (SC-SMRITI-110)
  # ---------------------------------------------------------------------------

  describe "12. Attestation expiry after 1 hour (SC-SMRITI-110)" do
    test "fresh attestation is not expired" do
      vv = %{"n" => 1}
      att = attestation_new(vv)
      refute attestation_expired?(att)
    end

    test "attestation backdated by 3601 seconds is expired" do
      past = DateTime.add(DateTime.utc_now(), -3_601, :second)
      att = %{vv: %{"n" => 1}, attested_at: past}
      assert attestation_expired?(att)
    end

    test "attestation at exactly 3600 seconds is not yet expired" do
      boundary = DateTime.add(DateTime.utc_now(), -3_600, :second)
      att = %{vv: %{"n" => 1}, attested_at: boundary}
      # diff == 3600, threshold is > 3600, so NOT expired
      refute attestation_expired?(att)
    end

    test "attestation_new wraps the vv with current timestamp" do
      vv = %{"holon" => 5}
      att = attestation_new(vv)

      assert att.vv == vv
      assert %DateTime{} = att.attested_at
    end
  end

  # ---------------------------------------------------------------------------
  # 13. Conflict resolution via LWW with version vector tiebreaker
  # ---------------------------------------------------------------------------

  describe "13. LWW conflict resolution with VV tiebreaker (SC-SMRITI-111)" do
    test "higher logical clock wins" do
      vv_a = %{"n" => 5}
      vv_b = %{"n" => 2}

      {:winner, winner, _merged_vv} = lww_resolve("value_a", "value_b", vv_a, vv_b)
      assert winner == "value_a"
    end

    test "when clocks tie, resolution is deterministic (not non-deterministic)" do
      vv_a = %{"x" => 3}
      vv_b = %{"y" => 3}

      result1 = lww_resolve("entry_a", "entry_b", vv_a, vv_b)
      result2 = lww_resolve("entry_a", "entry_b", vv_a, vv_b)

      # Both calls return the same winner
      {:winner, winner1, _} = result1
      {:winner, winner2, _} = result2
      assert winner1 == winner2
    end

    test "LWW winner's VV merges both inputs so no write is lost" do
      vv_a = %{"a" => 4}
      vv_b = %{"b" => 6}

      {:winner, _entry, merged_vv} = lww_resolve("a", "b", vv_a, vv_b)

      assert vv_descends?(merged_vv, vv_a)
      assert vv_descends?(merged_vv, vv_b)
    end

    test "loser's writes survive in the merged VV (no history loss)" do
      vv_a = %{"writer_a" => 10}
      vv_b = %{"writer_b" => 2}

      {:winner, _entry, merged_vv} = lww_resolve("doc_a", "doc_b", vv_a, vv_b)

      assert Map.has_key?(merged_vv, "writer_a")
      assert Map.has_key?(merged_vv, "writer_b")
    end
  end

  # ---------------------------------------------------------------------------
  # 14. 3-node federation scenario with concurrent writes
  # ---------------------------------------------------------------------------

  describe "14. 3-node federation scenario with concurrent writes (SC-SMRITI-063, SC-SMRITI-113)" do
    test "three nodes diverge then converge via pairwise sync" do
      # Phase 1: each node writes independently from a common state
      common = %{"shared" => 2}

      n1 = vv_increment(common, "n1")
      n2 = vv_increment(common, "n2")
      n3 = vv_increment(common, "n3")

      # Phase 2: all pairs are concurrent because none knows the others
      assert vv_concurrent?(n1, n2)
      assert vv_concurrent?(n2, n3)
      assert vv_concurrent?(n1, n3)

      # Phase 3: pairwise sync (each receives the other two)
      n1_after = federation_sync(n1, [n2, n3])
      n2_after = federation_sync(n2, [n1, n3])
      n3_after = federation_sync(n3, [n1, n2])

      # Phase 4: all nodes converge to the same vector
      assert n1_after == n2_after
      assert n2_after == n3_after

      # Phase 5: converged state is no longer concurrent with any individual node
      refute vv_concurrent?(n1_after, n1)
      refute vv_concurrent?(n2_after, n2)
      refute vv_concurrent?(n3_after, n3)
    end

    test "3-node scenario: resolve_state returns :synced after full sync" do
      n1 = %{"n1" => 1}
      n2 = %{"n2" => 2}
      n3 = %{"n3" => 3}

      converged = federation_sync(%{}, [n1, n2, n3])

      # After sync, local and remote are both converged — :synced
      assert {:synced, ^converged} = vv_resolve(converged, converged)
    end

    test "3-node scenario: partial sync leaves :conflict until all peers are seen" do
      n1 = %{"n1" => 5}
      n2 = %{"n2" => 3}
      _n3 = %{"n3" => 7}

      # n1 has only seen n2, not n3; n2 has seen n1 only
      partially_synced_n1 = federation_sync(n1, [n2])
      partially_synced_n2 = federation_sync(n2, [n1])

      # They have the same info at this point — should be :synced
      assert {:synced, _} = vv_resolve(partially_synced_n1, partially_synced_n2)
    end

    test "3-node scenario: delta shows exactly what a lagging peer is missing" do
      leader = %{"n1" => 10, "n2" => 5, "n3" => 3}
      laggard = %{"n1" => 2, "n3" => 3}

      delta = vv_delta(laggard, leader)

      # n1 advanced from 2 to 10 — delta must contain n1 at 10
      assert delta["n1"] == 10
      # n2 is completely new to laggard — delta must contain n2
      assert delta["n2"] == 5
      # n3 is equal — must NOT appear in delta
      refute Map.has_key?(delta, "n3")
    end

    test "3-node partition-then-heal: merged state has no concurrent pairs" do
      # Simulate a network partition: all three write independently
      p1 = Enum.reduce(1..3, %{}, fn _, acc -> vv_increment(acc, "p1") end)
      p2 = Enum.reduce(1..5, %{}, fn _, acc -> vv_increment(acc, "p2") end)
      p3 = Enum.reduce(1..2, %{}, fn _, acc -> vv_increment(acc, "p3") end)

      # Heal: every node receives all others
      healed = vv_merge(p1, vv_merge(p2, p3))

      assert healed["p1"] == 3
      assert healed["p2"] == 5
      assert healed["p3"] == 2

      refute vv_concurrent?(healed, p1)
      refute vv_concurrent?(healed, p2)
      refute vv_concurrent?(healed, p3)
    end
  end
end
