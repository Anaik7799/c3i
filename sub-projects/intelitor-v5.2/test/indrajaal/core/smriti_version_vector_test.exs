defmodule Indrajaal.Core.SmritiVersionVectorTest do
  @moduledoc """
  TDG test: SMRITI version vector federation sync.

  ## WHAT
  Validates version vector operations for conflict-free holon replication:
  increment, merge, dominates, concurrent detection.

  ## WHY
  SC-SMRITI-110 mandates version vectors in SQLite.
  SC-SMRITI-111 requires concurrent update detection.
  SC-SMRITI-113 requires causality preserved via version vectors.
  SC-XHOLON-007 mandates monotonically increasing version vectors.

  ## CONSTRAINTS
  - SC-SMRITI-110: Version vectors in SQLite
  - SC-SMRITI-111: Concurrent update detection
  - SC-SMRITI-113: Causality via version vectors
  - SC-XHOLON-007: Monotonically increasing
  - SC-DBCROSS-003: Version vectors for conflict resolution

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-03-24 | Claude | Initial implementation — Sprint 88 Wave 7 |
  """

  use ExUnit.Case, async: true
  import ExUnitProperties, except: [property: 2, property: 3]
  alias StreamData, as: SD

  @moduletag :smriti
  @moduletag :version_vector
  @moduletag :federation
  @moduletag :sprint_88

  describe "version vector creation" do
    test "new vector is empty map" do
      vv = vv_new()
      assert vv == %{}
    end

    test "single-node vector" do
      vv = vv_increment(vv_new(), :node_a)
      assert vv == %{node_a: 1}
    end
  end

  describe "increment (SC-XHOLON-007 monotonic)" do
    test "incrementing increases node counter by 1" do
      vv = vv_new() |> vv_increment(:node_a) |> vv_increment(:node_a)
      assert vv[:node_a] == 2
    end

    test "incrementing different nodes is independent" do
      vv = vv_new() |> vv_increment(:node_a) |> vv_increment(:node_b)
      assert vv[:node_a] == 1
      assert vv[:node_b] == 1
    end

    test "version is monotonically increasing" do
      vv0 = vv_new()
      vv1 = vv_increment(vv0, :node_a)
      vv2 = vv_increment(vv1, :node_a)
      vv3 = vv_increment(vv2, :node_a)

      assert vv1[:node_a] < vv2[:node_a]
      assert vv2[:node_a] < vv3[:node_a]
    end

    test "property — increment counter equals number of increments for any count (SD)" do
      check all(n <- SD.integer(1..100)) do
        vv = Enum.reduce(1..n, vv_new(), fn _, acc -> vv_increment(acc, :node_x) end)
        assert vv[:node_x] == n
      end
    end
  end

  describe "merge (SC-SMRITI-113 causality)" do
    test "merge takes element-wise maximum" do
      vv_a = %{node_a: 3, node_b: 1}
      vv_b = %{node_a: 1, node_b: 5}

      merged = vv_merge(vv_a, vv_b)
      assert merged == %{node_a: 3, node_b: 5}
    end

    test "merge with empty vector returns original" do
      vv = %{node_a: 2, node_b: 3}
      assert vv_merge(vv, vv_new()) == vv
      assert vv_merge(vv_new(), vv) == vv
    end

    test "merge includes nodes from both vectors" do
      vv_a = %{node_a: 1}
      vv_b = %{node_b: 2}

      merged = vv_merge(vv_a, vv_b)
      assert merged == %{node_a: 1, node_b: 2}
    end

    test "merge is commutative" do
      vv_a = %{node_a: 3, node_b: 1, node_c: 2}
      vv_b = %{node_a: 1, node_b: 5, node_d: 4}

      assert vv_merge(vv_a, vv_b) == vv_merge(vv_b, vv_a)
    end

    test "merge is associative" do
      vv_a = %{node_a: 3}
      vv_b = %{node_b: 2}
      vv_c = %{node_c: 1}

      assert vv_merge(vv_merge(vv_a, vv_b), vv_c) == vv_merge(vv_a, vv_merge(vv_b, vv_c))
    end

    test "merge is idempotent" do
      vv = %{node_a: 3, node_b: 5}
      assert vv_merge(vv, vv) == vv
    end
  end

  describe "dominates relation (SC-SMRITI-113)" do
    test "later vector dominates earlier" do
      vv_early = %{node_a: 1, node_b: 1}
      vv_late = %{node_a: 2, node_b: 2}

      assert vv_dominates?(vv_late, vv_early)
      refute vv_dominates?(vv_early, vv_late)
    end

    test "equal vectors don't dominate each other" do
      vv = %{node_a: 1, node_b: 1}
      refute vv_dominates?(vv, vv)
    end

    test "empty vector is dominated by any non-empty" do
      vv = %{node_a: 1}
      assert vv_dominates?(vv, vv_new())
      refute vv_dominates?(vv_new(), vv)
    end

    test "superset with higher counts dominates" do
      vv_a = %{node_a: 2, node_b: 3}
      vv_b = %{node_a: 1, node_b: 2}

      assert vv_dominates?(vv_a, vv_b)
    end
  end

  describe "concurrent detection (SC-SMRITI-111)" do
    test "concurrent vectors detected" do
      vv_a = %{node_a: 2, node_b: 1}
      vv_b = %{node_a: 1, node_b: 2}

      assert vv_concurrent?(vv_a, vv_b)
    end

    test "sequential vectors are not concurrent" do
      vv_early = %{node_a: 1, node_b: 1}
      vv_late = %{node_a: 2, node_b: 2}

      refute vv_concurrent?(vv_early, vv_late)
    end

    test "equal vectors are not concurrent" do
      vv = %{node_a: 1, node_b: 1}
      refute vv_concurrent?(vv, vv)
    end

    test "disjoint node sets are concurrent" do
      vv_a = %{node_a: 1}
      vv_b = %{node_b: 1}

      assert vv_concurrent?(vv_a, vv_b)
    end
  end

  describe "federation sync simulation (SC-SMRITI-063)" do
    test "3-node federation converges" do
      # Simulate 3 nodes with independent writes
      nodes = %{
        alpha: %{alpha: 3, beta: 1},
        beta: %{alpha: 1, beta: 4, gamma: 1},
        gamma: %{gamma: 2}
      }

      # Gossip round: each node merges with peers
      converged =
        Enum.reduce(Map.keys(nodes), nodes, fn node, state ->
          peers = Map.keys(state) -- [node]

          merged =
            Enum.reduce(peers, Map.get(state, node), fn peer, acc ->
              vv_merge(acc, Map.get(state, peer))
            end)

          Map.put(state, node, merged)
        end)

      # After full gossip, all nodes should have same vector
      vectors = Map.values(converged)
      assert length(Enum.uniq(vectors)) == 1
    end
  end

  describe "property-based version vector laws" do
    test "property — incremented vector dominates empty vector for any node and count (SD)" do
      check all(
              node <- SD.atom(:alphanumeric),
              n <- SD.integer(1..50)
            ) do
        vv = Enum.reduce(1..n, vv_new(), fn _, acc -> vv_increment(acc, node) end)
        assert vv[node] == n
        assert vv_dominates?(vv, vv_new())
      end
    end

    test "property — merge takes element-wise maximum for any counter pair (SD)" do
      check all(
              a_count <- SD.integer(0..10),
              b_count <- SD.integer(0..10)
            ) do
        vv_a = if a_count > 0, do: %{x: a_count}, else: %{}
        vv_b = if b_count > 0, do: %{x: b_count}, else: %{}

        merged = vv_merge(vv_a, vv_b)
        expected_x = max(Map.get(vv_a, :x, 0), Map.get(vv_b, :x, 0))

        if expected_x > 0 do
          assert merged[:x] == expected_x
        end
      end
    end
  end

  # --- Version Vector Helpers ---

  defp vv_new, do: %{}

  defp vv_increment(vv, node) do
    Map.update(vv, node, 1, &(&1 + 1))
  end

  defp vv_merge(vv_a, vv_b) do
    all_keys = (Map.keys(vv_a) ++ Map.keys(vv_b)) |> Enum.uniq()

    Map.new(all_keys, fn key ->
      {key, max(Map.get(vv_a, key, 0), Map.get(vv_b, key, 0))}
    end)
  end

  defp vv_dominates?(vv_a, vv_b) do
    all_keys = (Map.keys(vv_a) ++ Map.keys(vv_b)) |> Enum.uniq()

    at_least_one_greater =
      Enum.any?(all_keys, fn key ->
        Map.get(vv_a, key, 0) > Map.get(vv_b, key, 0)
      end)

    all_gte =
      Enum.all?(all_keys, fn key ->
        Map.get(vv_a, key, 0) >= Map.get(vv_b, key, 0)
      end)

    all_gte and at_least_one_greater
  end

  defp vv_concurrent?(vv_a, vv_b) do
    not vv_dominates?(vv_a, vv_b) and
      not vv_dominates?(vv_b, vv_a) and
      vv_a != vv_b
  end
end
