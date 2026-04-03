defmodule Indrajaal.Holon.Replication.VersionVectorConflictTest do
  @moduledoc """
  TDG-compliant test suite for version vector conflict resolution.

  WHAT: Tests OCC conflict detection, monotonic increment, causal ordering,
        and merge strategies for holon replication version vectors.
  WHY: SC-XHOLON-006 (OCC with version vectors), SC-XHOLON-007 (monotonic vectors),
       SC-SMRITI-113 (causality preserved) mandate correct vector clock semantics.
  CONSTRAINTS: SC-XHOLON-006, SC-XHOLON-007, SC-SMRITI-113, EP-GEN-014

  ## Coverage Matrix
  | Concern                        | PropCheck | StreamData | Unit |
  |-------------------------------|-----------|------------|------|
  | Vector creation                | 0         | 1          | 2    |
  | Increment monotonicity         | 1         | 1          | 2    |
  | Concurrent write detection     | 1         | 1          | 3    |
  | Causal ordering                | 1         | 1          | 2    |
  | Merge dominance                | 1         | 1          | 3    |
  | Last-writer-wins               | 0         | 0          | 2    |
  | TOTAL                          | 4         | 5          | 14   |

  ## EP-GEN-014 compliance
  - `use PropCheck` + `import ExUnitProperties, except: [property: 2, property: 3, check: 2]`
  - PC. prefix for PropCheck generators (forall blocks)
  - SD. prefix for StreamData generators (check all blocks)
  - All helpers are self-contained in this module (no external production deps)
  """

  use ExUnit.Case, async: true

  # EP-GEN-014: dual property testing import pattern — MANDATORY
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :property
  @moduletag :version_vector
  @moduletag :holon_replication

  setup_all do
    Application.ensure_all_started(:propcheck)
    :ok
  end

  # ==========================================================================
  # Self-contained version vector implementation (test helper)
  # Implements the CRDTs required by SC-XHOLON-006, SC-XHOLON-007, SC-SMRITI-113
  # ==========================================================================

  defmodule VV do
    @moduledoc """
    Self-contained version vector implementation for test validation.
    Represents a vector clock as a map: %{node_id => counter}.
    """

    @spec new() :: map()
    def new(), do: %{}

    @spec new(list(binary())) :: map()
    def new(nodes) when is_list(nodes) do
      Map.new(nodes, fn n -> {n, 0} end)
    end

    @spec increment(map(), binary()) :: map()
    def increment(vv, node_id) do
      Map.update(vv, node_id, 1, &(&1 + 1))
    end

    @spec merge(map(), map()) :: map()
    def merge(vv_a, vv_b) do
      Map.merge(vv_a, vv_b, fn _node, c_a, c_b -> max(c_a, c_b) end)
    end

    @spec dominates?(map(), map()) :: boolean()
    def dominates?(vv_a, vv_b) do
      all_nodes = Map.keys(vv_a) ++ Map.keys(vv_b)

      Enum.all?(all_nodes, fn node ->
        Map.get(vv_a, node, 0) >= Map.get(vv_b, node, 0)
      end) and
        Enum.any?(all_nodes, fn node ->
          Map.get(vv_a, node, 0) > Map.get(vv_b, node, 0)
        end)
    end

    @spec equal?(map(), map()) :: boolean()
    def equal?(vv_a, vv_b) do
      all_nodes = Map.keys(vv_a) ++ Map.keys(vv_b)

      Enum.all?(all_nodes, fn node ->
        Map.get(vv_a, node, 0) == Map.get(vv_b, node, 0)
      end)
    end

    @spec concurrent?(map(), map()) :: boolean()
    def concurrent?(vv_a, vv_b) do
      not dominates?(vv_a, vv_b) and
        not dominates?(vv_b, vv_a) and
        not equal?(vv_a, vv_b)
    end

    @spec causally_before?(map(), map()) :: boolean()
    def causally_before?(vv_a, vv_b), do: dominates?(vv_b, vv_a)

    @spec last_writer_wins(map(), any(), map(), any(), (any() -> integer())) :: any()
    def last_writer_wins(_vv_a, val_a, _vv_b, val_b, timestamp_fn) do
      if timestamp_fn.(val_a) >= timestamp_fn.(val_b), do: val_a, else: val_b
    end
  end

  # ==========================================================================
  # SECTION 1: Vector Creation — SC-XHOLON-007
  # ==========================================================================

  describe "vector creation — SC-XHOLON-007" do
    test "VV_UNIT_01: new/0 returns empty map" do
      assert VV.new() == %{}
    end

    test "VV_UNIT_02: new/1 initializes all nodes at counter zero" do
      nodes = ["node-a", "node-b", "node-c"]
      vv = VV.new(nodes)

      assert map_size(vv) == 3
      assert Enum.all?(nodes, fn n -> Map.get(vv, n) == 0 end)
    end

    test "VV_STREAM_01: new/1 always zeros all given nodes" do
      ExUnitProperties.check all(
                               nodes <-
                                 SD.list_of(SD.string(:alphanumeric, min_length: 1),
                                   min_length: 1,
                                   max_length: 5
                                 )
                             ) do
        vv = VV.new(nodes)
        assert Enum.all?(nodes, fn n -> Map.get(vv, n, :missing) == 0 end)
      end
    end
  end

  # ==========================================================================
  # SECTION 2: Monotonic Increment — SC-XHOLON-007
  # ==========================================================================

  describe "monotonic increment — SC-XHOLON-007" do
    test "VV_UNIT_03: increment increases counter by exactly 1" do
      vv = VV.new()
      vv1 = VV.increment(vv, "node-a")
      vv2 = VV.increment(vv1, "node-a")

      assert Map.get(vv1, "node-a") == 1
      assert Map.get(vv2, "node-a") == 2
    end

    test "VV_UNIT_04: increment of one node does not affect other nodes" do
      vv = VV.new(["node-a", "node-b"])
      vv1 = VV.increment(vv, "node-a")

      assert Map.get(vv1, "node-b") == 0
      assert Map.get(vv1, "node-a") == 1
    end

    property "VV_PROP_01: repeated increments are strictly monotonically increasing" do
      forall {node, n} <- {PC.utf8(), PC.pos_integer()} do
        vv =
          Enum.reduce(1..n, VV.new(), fn _, acc ->
            VV.increment(acc, node)
          end)

        Map.get(vv, node, 0) == n
      end
    end

    test "VV_STREAM_02: every increment strictly exceeds previous counter" do
      ExUnitProperties.check all(
                               node <- SD.string(:alphanumeric, min_length: 1),
                               steps <- SD.integer(1..10)
                             ) do
        {final_vv, prev_counters} =
          Enum.reduce(1..steps, {VV.new(), []}, fn _, {vv, counters} ->
            prev = Map.get(vv, node, 0)
            new_vv = VV.increment(vv, node)
            {new_vv, [prev | counters]}
          end)

        final_count = Map.get(final_vv, node, 0)
        initial = List.last(prev_counters) || 0
        assert final_count > initial
        assert final_count == steps
      end
    end
  end

  # ==========================================================================
  # SECTION 3: Concurrent Write Detection — SC-XHOLON-006
  # ==========================================================================

  describe "concurrent write detection — SC-XHOLON-006" do
    test "VV_UNIT_05: writes from same causal history are not concurrent" do
      base = VV.new(["node-a"])
      vv_a = VV.increment(base, "node-a")
      vv_b = VV.increment(vv_a, "node-a")

      refute VV.concurrent?(vv_a, vv_b)
      assert VV.causally_before?(vv_a, vv_b)
    end

    test "VV_UNIT_06: independent writes from different nodes are concurrent" do
      base = VV.new(["node-a", "node-b"])
      vv_a = VV.increment(base, "node-a")
      vv_b = VV.increment(base, "node-b")

      assert VV.concurrent?(vv_a, vv_b)
    end

    test "VV_UNIT_07: after merge, writes are no longer concurrent with merged state" do
      base = VV.new(["node-a", "node-b"])
      vv_a = VV.increment(base, "node-a")
      vv_b = VV.increment(base, "node-b")
      merged = VV.merge(vv_a, vv_b)

      refute VV.concurrent?(merged, vv_a)
      refute VV.concurrent?(merged, vv_b)
    end

    property "VV_PROP_02: a vector is never concurrent with itself" do
      forall vv <- PC.map(PC.utf8(), PC.non_neg_integer()) do
        not VV.concurrent?(vv, vv)
      end
    end

    test "VV_STREAM_03: partition-then-merge produces exactly one concurrent pair" do
      ExUnitProperties.check all(
                               node_a <- SD.string(:alphanumeric, min_length: 1),
                               node_b <- SD.string(:alphanumeric, min_length: 1),
                               _guard <- SD.filter(SD.constant(:ok), fn _ -> node_a != node_b end)
                             ) do
        base = VV.new([node_a, node_b])
        partition_a = VV.increment(base, node_a)
        partition_b = VV.increment(base, node_b)

        assert VV.concurrent?(partition_a, partition_b)
        refute VV.concurrent?(VV.merge(partition_a, partition_b), partition_a)
      end
    end
  end

  # ==========================================================================
  # SECTION 4: Causal Ordering — SC-SMRITI-113
  # ==========================================================================

  describe "causal ordering — SC-SMRITI-113" do
    test "VV_UNIT_08: causally_before? reflects dominates? inverse" do
      base = VV.new(["node-a"])
      vv_old = VV.increment(base, "node-a")
      vv_new = VV.increment(vv_old, "node-a")

      assert VV.causally_before?(vv_old, vv_new)
      refute VV.causally_before?(vv_new, vv_old)
    end

    test "VV_UNIT_09: equal vectors are neither before nor after each other" do
      vv = VV.new(["node-a"])
      vv_inc = VV.increment(vv, "node-a")

      refute VV.causally_before?(vv_inc, vv_inc)
      refute VV.dominates?(vv_inc, vv_inc)
      assert VV.equal?(vv_inc, vv_inc)
    end

    property "VV_PROP_03: causal chain is transitively ordered" do
      forall {node, steps} <- {PC.utf8(), PC.choose(2, 5)} do
        vectors =
          Enum.scan(1..steps, VV.new(), fn _, acc ->
            VV.increment(acc, node)
          end)

        [first | rest] = vectors
        last = List.last(rest)

        VV.causally_before?(first, last)
      end
    end

    test "VV_STREAM_04: knowledge of merged state is causally after both inputs" do
      ExUnitProperties.check all(
                               nodes <-
                                 SD.list_of(SD.string(:alphanumeric, min_length: 1),
                                   min_length: 2,
                                   max_length: 3
                                 ),
                               node_a <- SD.member_of(nodes),
                               node_b <- SD.member_of(nodes)
                             ) do
        base = VV.new(nodes)
        vv_a = VV.increment(base, node_a)
        vv_b = VV.increment(base, node_b)
        merged = VV.merge(vv_a, vv_b)

        assert VV.dominates?(merged, vv_a) or VV.equal?(merged, vv_a)
        assert VV.dominates?(merged, vv_b) or VV.equal?(merged, vv_b)
      end
    end
  end

  # ==========================================================================
  # SECTION 5: Merge Dominance — SC-XHOLON-006, SC-SMRITI-113
  # ==========================================================================

  describe "merge dominance — SC-XHOLON-006 + SC-SMRITI-113" do
    test "VV_UNIT_10: merge is commutative" do
      base = VV.new(["a", "b"])
      vv_a = VV.increment(base, "a")
      vv_b = VV.increment(base, "b")

      assert VV.merge(vv_a, vv_b) == VV.merge(vv_b, vv_a)
    end

    test "VV_UNIT_11: merge is idempotent" do
      vv = VV.increment(VV.new(["a"]), "a")
      assert VV.merge(vv, vv) == vv
    end

    test "VV_UNIT_12: merge takes max counter per node" do
      vv_a = %{"node-1" => 5, "node-2" => 2}
      vv_b = %{"node-1" => 3, "node-2" => 7}
      merged = VV.merge(vv_a, vv_b)

      assert merged["node-1"] == 5
      assert merged["node-2"] == 7
    end

    property "VV_PROP_04: merged vector dominates both inputs (or equals them)" do
      forall {vv_a, vv_b} <-
               {PC.map(PC.utf8(), PC.non_neg_integer()), PC.map(PC.utf8(), PC.non_neg_integer())} do
        merged = VV.merge(vv_a, vv_b)

        (VV.dominates?(merged, vv_a) or VV.equal?(merged, vv_a)) and
          (VV.dominates?(merged, vv_b) or VV.equal?(merged, vv_b))
      end
    end

    test "VV_STREAM_05: merge is associative over three vectors" do
      ExUnitProperties.check all(
                               nodes <-
                                 SD.list_of(SD.string(:alphanumeric, min_length: 1),
                                   min_length: 1,
                                   max_length: 3
                                 )
                             ) do
        base = VV.new(nodes)

        vv_a = if nodes != [], do: VV.increment(base, hd(nodes)), else: base
        vv_b = if length(nodes) > 1, do: VV.increment(base, Enum.at(nodes, 1)), else: base
        vv_c = if length(nodes) > 2, do: VV.increment(base, Enum.at(nodes, 2)), else: base

        left = VV.merge(VV.merge(vv_a, vv_b), vv_c)
        right = VV.merge(vv_a, VV.merge(vv_b, vv_c))

        assert left == right
      end
    end
  end

  # ==========================================================================
  # SECTION 6: Last-Writer-Wins — SC-XHOLON-006
  # ==========================================================================

  describe "last-writer-wins conflict resolution — SC-XHOLON-006" do
    test "VV_UNIT_13: LWW selects value with higher timestamp" do
      vv_old = %{"node-a" => 1}
      vv_new = %{"node-a" => 2}

      result =
        VV.last_writer_wins(vv_old, {:data, 100}, vv_new, {:data, 200}, fn {:data, ts} -> ts end)

      assert result == {:data, 200}
    end

    test "VV_UNIT_14: LWW is deterministic for equal timestamps" do
      vv = %{"node-a" => 1}
      val_a = {:data, 100}
      val_b = {:data, 100}

      result1 = VV.last_writer_wins(vv, val_a, vv, val_b, fn {:data, ts} -> ts end)
      result2 = VV.last_writer_wins(vv, val_a, vv, val_b, fn {:data, ts} -> ts end)

      assert result1 == result2
    end
  end
end
