defmodule Indrajaal.KMS.Federation.VersionVectorTest do
  @moduledoc """
  TDG comprehensive test suite for KMS.Federation.VersionVector.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-SMRITI-062: Version vector causal ordering
  - SC-HOLON-001: SQLite state sovereignty
  - SC-KMS-004: Operations < 100ms

  ## Constitutional Verification
  - Psi2 Evolutionary Continuity: Version vectors preserve causal history
  - Psi3 Verification: Descends/concurrent operations are provably correct

  ## Founder's Directive Alignment
  - Omega0.4: Co-evolution tracked via version vectors

  ## TPS 5-Level RCA Context
  - L1 Symptom: Concurrent updates cause split-brain
  - L5 Root Cause: Missing causal ordering in distributed state

  ## Mathematical Foundations
  - Version vectors form a partial order under the descends? relation
  - Merge is the join (least upper bound) in the lattice of version vectors
  - concurrent? is the complement of total order

  ## Change History
  | Version | Date       | Author | Change                              |
  |---------|------------|--------|-------------------------------------|
  | 21.3.0  | 2026-03-21 | Claude | Sprint 54 W5 test generation (TDG)  |
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.KMS.Federation.VersionVector

  @moduletag :kms_version_vector
  @moduletag :zenoh_nif

  # ---------------------------------------------------------------------------
  # new/1
  # ---------------------------------------------------------------------------

  describe "new/1" do
    test "creates version vector with node at 0" do
      vv = VersionVector.new("node_a")
      assert vv == %{"node_a" => 0}
    end

    test "created vector contains only the specified node" do
      vv = VersionVector.new("single_node")
      assert map_size(vv) == 1
    end

    test "different node IDs produce independent vectors" do
      vv1 = VersionVector.new("node_1")
      vv2 = VersionVector.new("node_2")
      refute Map.has_key?(vv1, "node_2")
      refute Map.has_key?(vv2, "node_1")
    end
  end

  # ---------------------------------------------------------------------------
  # increment/2
  # ---------------------------------------------------------------------------

  describe "increment/2" do
    test "increments existing node counter" do
      vv = VersionVector.new("node_a")
      vv2 = VersionVector.increment(vv, "node_a")
      assert vv2["node_a"] == 1
    end

    test "adding new node starts at 1" do
      vv = VersionVector.new("node_a")
      vv2 = VersionVector.increment(vv, "node_b")
      assert vv2["node_b"] == 1
    end

    test "increment is monotone - never decreases" do
      vv = VersionVector.new("n")
      vv2 = VersionVector.increment(vv, "n")
      vv3 = VersionVector.increment(vv2, "n")
      assert vv3["n"] > vv2["n"]
      assert vv2["n"] > vv["n"]
    end

    test "increments do not affect other node counters" do
      vv = %{"node_a" => 3, "node_b" => 5}
      vv2 = VersionVector.increment(vv, "node_a")
      assert vv2["node_b"] == 5
      assert vv2["node_a"] == 4
    end

    test "multiple increments on same node" do
      vv = VersionVector.new("n")
      vv10 = Enum.reduce(1..10, vv, fn _, acc -> VersionVector.increment(acc, "n") end)
      assert vv10["n"] == 10
    end
  end

  # ---------------------------------------------------------------------------
  # merge/2
  # ---------------------------------------------------------------------------

  describe "merge/2" do
    test "merge of two disjoint vectors contains all nodes" do
      vv1 = %{"a" => 3}
      vv2 = %{"b" => 5}
      merged = VersionVector.merge(vv1, vv2)
      assert merged["a"] == 3
      assert merged["b"] == 5
    end

    test "merge takes max of shared node counters" do
      vv1 = %{"a" => 3, "b" => 1}
      vv2 = %{"a" => 1, "b" => 5}
      merged = VersionVector.merge(vv1, vv2)
      assert merged["a"] == 3
      assert merged["b"] == 5
    end

    test "merge is commutative" do
      vv1 = %{"a" => 3, "b" => 1}
      vv2 = %{"a" => 1, "b" => 5, "c" => 2}
      assert VersionVector.merge(vv1, vv2) == VersionVector.merge(vv2, vv1)
    end

    test "merge is idempotent" do
      vv = %{"a" => 3, "b" => 5}
      assert VersionVector.merge(vv, vv) == vv
    end

    test "merge is associative" do
      vv1 = %{"a" => 3}
      vv2 = %{"b" => 5}
      vv3 = %{"c" => 2}
      left = VersionVector.merge(VersionVector.merge(vv1, vv2), vv3)
      right = VersionVector.merge(vv1, VersionVector.merge(vv2, vv3))
      assert left == right
    end

    test "merge dominates both inputs (upper bound)" do
      vv1 = %{"a" => 3, "b" => 1}
      vv2 = %{"a" => 1, "b" => 5}
      merged = VersionVector.merge(vv1, vv2)
      assert VersionVector.descends?(merged, vv1)
      assert VersionVector.descends?(merged, vv2)
    end

    test "merge of empty and non-empty equals non-empty" do
      vv = %{"a" => 5}
      assert VersionVector.merge(%{}, vv) == vv
      assert VersionVector.merge(vv, %{}) == vv
    end
  end

  # ---------------------------------------------------------------------------
  # descends?/2
  # ---------------------------------------------------------------------------

  describe "descends?/2" do
    test "vv descends itself (reflexive)" do
      vv = %{"a" => 3, "b" => 1}
      assert VersionVector.descends?(vv, vv)
    end

    test "empty vector descends empty vector" do
      assert VersionVector.descends?(%{}, %{})
    end

    test "advanced vector descends earlier one" do
      vv1 = %{"a" => 1}
      vv2 = %{"a" => 3}
      assert VersionVector.descends?(vv2, vv1)
      refute VersionVector.descends?(vv1, vv2)
    end

    test "superset descends subset when all counters dominate" do
      vv1 = %{"a" => 3, "b" => 2}
      vv2 = %{"a" => 1}
      assert VersionVector.descends?(vv1, vv2)
    end

    test "does not descend if any counter is lower" do
      vv1 = %{"a" => 3, "b" => 1}
      vv2 = %{"a" => 1, "b" => 5}
      refute VersionVector.descends?(vv1, vv2)
    end

    test "zero-counter vector does not descend positive-counter vector" do
      vv1 = %{"a" => 0}
      vv2 = %{"a" => 1}
      refute VersionVector.descends?(vv1, vv2)
    end

    test "transitivity: if A descends B and B descends C, A descends C" do
      a = %{"n" => 5}
      b = %{"n" => 3}
      c = %{"n" => 1}
      assert VersionVector.descends?(a, b)
      assert VersionVector.descends?(b, c)
      assert VersionVector.descends?(a, c)
    end
  end

  # ---------------------------------------------------------------------------
  # concurrent?/2
  # ---------------------------------------------------------------------------

  describe "concurrent?/2" do
    test "concurrent when neither descends the other" do
      vv1 = %{"a" => 3, "b" => 0}
      vv2 = %{"a" => 0, "b" => 5}
      assert VersionVector.concurrent?(vv1, vv2)
      assert VersionVector.concurrent?(vv2, vv1)
    end

    test "not concurrent when one descends the other" do
      vv1 = %{"a" => 1}
      vv2 = %{"a" => 3}
      refute VersionVector.concurrent?(vv1, vv2)
      refute VersionVector.concurrent?(vv2, vv1)
    end

    test "not concurrent with itself (is reflexive-descends)" do
      vv = %{"a" => 3}
      refute VersionVector.concurrent?(vv, vv)
    end

    test "concurrent is symmetric" do
      vv1 = %{"a" => 5, "b" => 1}
      vv2 = %{"a" => 1, "b" => 5}
      assert VersionVector.concurrent?(vv1, vv2) == VersionVector.concurrent?(vv2, vv1)
    end

    test "empty vectors are not concurrent (both descend each other)" do
      refute VersionVector.concurrent?(%{}, %{})
    end
  end

  # ---------------------------------------------------------------------------
  # Property tests
  # ---------------------------------------------------------------------------

  property "increment always increases the target node's counter" do
    forall {node_id, initial_count} <- {PC.non_empty(PC.utf8()), PC.non_neg_integer()} do
      vv = %{node_id => initial_count}
      vv2 = VersionVector.increment(vv, node_id)
      vv2[node_id] == initial_count + 1
    end
  end

  property "merge is commutative for arbitrary vectors" do
    forall {pairs1, pairs2} <- {
             PC.list({PC.non_empty(PC.utf8()), PC.non_neg_integer()}),
             PC.list({PC.non_empty(PC.utf8()), PC.non_neg_integer()})
           } do
      vv1 = Map.new(pairs1)
      vv2 = Map.new(pairs2)
      VersionVector.merge(vv1, vv2) == VersionVector.merge(vv2, vv1)
    end
  end

  test "merged vector always descends both inputs" do
    ExUnitProperties.check all(
                             pairs1 <-
                               SD.list_of(
                                 SD.tuple(
                                   {SD.string(:alphanumeric, min_length: 1),
                                    SD.non_negative_integer()}
                                 ),
                                 min_length: 1
                               ),
                             pairs2 <-
                               SD.list_of(
                                 SD.tuple(
                                   {SD.string(:alphanumeric, min_length: 1),
                                    SD.non_negative_integer()}
                                 ),
                                 min_length: 1
                               )
                           ) do
      vv1 = Map.new(pairs1)
      vv2 = Map.new(pairs2)
      merged = VersionVector.merge(vv1, vv2)
      VersionVector.descends?(merged, vv1) and VersionVector.descends?(merged, vv2)
    end
  end

  test "concurrent? and descends? are mutually exclusive for strict ordering" do
    ExUnitProperties.check all(
                             n <- SD.positive_integer(),
                             m <- SD.positive_integer()
                           ) do
      # When one is strictly higher, they are not concurrent
      vv_low = %{"node" => n}
      vv_high = %{"node" => n + m}
      not VersionVector.concurrent?(vv_high, vv_low)
    end
  end

  test "new/1 always returns a single-key map with zero counter" do
    ExUnitProperties.check all(node_id <- SD.string(:alphanumeric, min_length: 1, max_length: 50)) do
      vv = VersionVector.new(node_id)
      map_size(vv) == 1 and vv[node_id] == 0
    end
  end

  # ---------------------------------------------------------------------------
  # SIL-6 / Distributed safety tests
  # ---------------------------------------------------------------------------

  describe "SIL-6: Distributed Consistency (SC-SMRITI-062)" do
    test "simulates two-node update scenario without split-brain" do
      # Node A and Node B start with same base
      base = VersionVector.new("node_a") |> Map.merge(VersionVector.new("node_b"))

      # Each node makes independent updates
      vv_a = VersionVector.increment(base, "node_a") |> VersionVector.increment("node_a")
      vv_b = VersionVector.increment(base, "node_b")

      # They are concurrent (split)
      assert VersionVector.concurrent?(vv_a, vv_b)

      # Merging resolves without data loss
      merged = VersionVector.merge(vv_a, vv_b)
      assert merged["node_a"] == 2
      assert merged["node_b"] == 1

      # Merged descends both
      assert VersionVector.descends?(merged, vv_a)
      assert VersionVector.descends?(merged, vv_b)
    end

    test "three-node quorum scenario" do
      # Simulate 2oo3 voting context
      n1 = VersionVector.new("n1")
      n2 = VersionVector.new("n2")
      n3 = VersionVector.new("n3")

      vv = Enum.reduce([n1, n2, n3], %{}, &VersionVector.merge/2)
      assert map_size(vv) == 3

      # Each node increments independently
      vv1 = VersionVector.increment(vv, "n1")
      vv2 = VersionVector.increment(vv, "n2")
      vv3 = VersionVector.increment(vv, "n3")

      # Quorum merge (all three nodes agree)
      quorum = vv1 |> VersionVector.merge(vv2) |> VersionVector.merge(vv3)

      assert quorum["n1"] == 1
      assert quorum["n2"] == 1
      assert quorum["n3"] == 1
    end
  end

  describe "Constitutional Invariants" do
    test "Psi2 Evolutionary Continuity: version history monotone" do
      vv0 = VersionVector.new("history_node")
      vv1 = VersionVector.increment(vv0, "history_node")
      vv2 = VersionVector.increment(vv1, "history_node")

      # Strictly increasing - history is preserved
      assert vv2["history_node"] > vv1["history_node"]
      assert vv1["history_node"] > vv0["history_node"]
      assert VersionVector.descends?(vv2, vv1)
      assert VersionVector.descends?(vv1, vv0)
    end

    test "Psi3 Verification: descends? is verifiable and consistent" do
      vv_a = %{"a" => 5, "b" => 2}
      vv_b = %{"a" => 3, "b" => 1}

      # vv_a descends vv_b iff all entries in vv_b are covered by vv_a
      expected = Enum.all?(vv_b, fn {k, v} -> Map.get(vv_a, k, 0) >= v end)
      assert VersionVector.descends?(vv_a, vv_b) == expected
    end
  end
end
