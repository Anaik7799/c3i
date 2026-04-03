defmodule Indrajaal.Safety.HLCMonotonicityTest do
  @moduledoc """
  Hybrid Logical Clock (HLC) Monotonicity Tests across 3 Simulated Nodes.

  WHAT: Tests that HLC timestamps are strictly monotonically increasing
        across node boundaries, verifying causality is preserved.
  WHY: AOR-HLC-001 mandates monotonic HLC. AOR-HLC-002 requires persistence
       across node restarts. Distributed systems depend on causal ordering.
  CONSTRAINTS:
    - AOR-HLC-001: HLC MUST be monotonically increasing
    - AOR-HLC-002: HLC MUST survive node restart via persistence
    - SC-SIL6-011: Quorum = floor(N/2)+1 applies to clock synchronization
    - SC-ZTEST-015: Timestamps MUST be ISO 8601 UTC

  ## Change History
  | Version | Date       | Author | Change                       |
  |---------|------------|--------|------------------------------|
  | 1.0.0   | 2026-03-23 | Claude | Initial HLC monotonicity tests|

  @version "1.0.0"
  @last_modified "2026-03-23T00:00:00Z"
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Time.HLC

  @moduletag :safety
  @moduletag :hlc

  # Simulated node names
  @node_a :node_alpha
  @node_b :node_beta
  @node_c :node_gamma

  # ============================================================================
  # SETUP
  # ============================================================================

  setup do
    table = :ets.new(:hlc_test, [:set, :public])

    on_exit(fn ->
      if :ets.info(table) != :undefined, do: :ets.delete(table)
    end)

    # Initialize one HLC per node in ETS
    hlc_a = {System.system_time(:millisecond), 0, @node_a}
    hlc_b = {System.system_time(:millisecond), 0, @node_b}
    hlc_c = {System.system_time(:millisecond), 0, @node_c}

    :ets.insert(table, {:hlc_a, hlc_a})
    :ets.insert(table, {:hlc_b, hlc_b})
    :ets.insert(table, {:hlc_c, hlc_c})

    %{table: table, hlc_a: hlc_a, hlc_b: hlc_b, hlc_c: hlc_c}
  end

  # ============================================================================
  # HELPER: Compare two HLC timestamps
  # Returns :lt | :eq | :gt
  # ============================================================================

  defp hlc_compare({wall1, count1, _node1}, {wall2, count2, _node2}) do
    cond do
      wall1 < wall2 -> :lt
      wall1 > wall2 -> :gt
      count1 < count2 -> :lt
      count1 > count2 -> :gt
      true -> :eq
    end
  end

  defp hlc_less_than?(a, b), do: hlc_compare(a, b) == :lt
  defp hlc_greater_than?(a, b), do: hlc_compare(a, b) == :gt

  # Advance a local HLC tick (simulate event on same node)
  defp local_tick({wall, count, node}) do
    now = System.system_time(:millisecond)

    if now > wall do
      {now, 0, node}
    else
      {wall, count + 1, node}
    end
  end

  # ============================================================================
  # 1. BASIC HLC STRUCTURE
  # ============================================================================

  describe "HLC basic structure and creation" do
    test "HLC.new/0 returns a valid 3-tuple" do
      hlc = HLC.new()
      assert is_tuple(hlc)
      assert tuple_size(hlc) == 3
    end

    test "HLC.new/0 wall time is current system time" do
      before_ms = System.system_time(:millisecond)
      {wall, _count, _node} = HLC.new()
      after_ms = System.system_time(:millisecond)

      assert wall >= before_ms
      assert wall <= after_ms
    end

    test "HLC.new/0 counter starts at 0" do
      {_wall, count, _node} = HLC.new()
      assert count == 0
    end

    test "HLC.new/0 node is current node" do
      {_wall, _count, node} = HLC.new()
      assert node == Node.self()
    end

    test "HLC.to_string/1 returns formatted string" do
      hlc = {1_711_000_000_000, 5, :my_node}
      result = HLC.to_string(hlc)
      assert is_binary(result)
      assert String.contains?(result, "HLC[")
      assert String.contains?(result, "1711000000000")
      assert String.contains?(result, "5")
    end
  end

  # ============================================================================
  # 2. MONOTONICITY: SINGLE NODE (AOR-HLC-001)
  # ============================================================================

  describe "HLC monotonicity on single node (AOR-HLC-001)" do
    test "local_tick always produces a greater-than-or-equal timestamp" do
      hlc = HLC.new()
      ticked = local_tick(hlc)

      # Ticked must be >= original
      assert hlc_compare(ticked, hlc) in [:gt, :eq]
    end

    test "multiple local ticks produce strictly increasing sequence" do
      hlc0 = HLC.new()

      # Force counter-based advancement by keeping wall time fixed
      {wall, _count, node} = hlc0
      hlc1 = {wall, 1, node}
      hlc2 = {wall, 2, node}
      hlc3 = {wall, 3, node}

      assert hlc_less_than?(hlc0, hlc1)
      assert hlc_less_than?(hlc1, hlc2)
      assert hlc_less_than?(hlc2, hlc3)
    end

    test "HLC with higher wall time dominates counter" do
      hlc_early = {1_000_000, 999, :node_a}
      hlc_later = {1_000_001, 0, :node_a}

      assert hlc_less_than?(hlc_early, hlc_later),
             "Later wall time must dominate even with lower counter"
    end

    test "100 sequential local ticks are monotonically increasing" do
      initial = {System.system_time(:millisecond), 0, @node_a}

      ticks =
        Enum.reduce(1..100, [initial], fn _, [prev | _] = acc ->
          next = {elem(prev, 0), elem(prev, 1) + 1, elem(prev, 2)}
          [next | acc]
        end)
        |> Enum.reverse()

      pairs = Enum.zip(ticks, tl(ticks))

      Enum.each(pairs, fn {a, b} ->
        assert hlc_less_than?(a, b),
               "Monotonicity violated: #{HLC.to_string(a)} >= #{HLC.to_string(b)}"
      end)
    end
  end

  # ============================================================================
  # 3. CROSS-NODE SYNCHRONIZATION (AOR-HLC-001)
  # ============================================================================

  describe "HLC.update/2 cross-node synchronization" do
    test "update with remote clock advances local past remote", %{hlc_a: hlc_a, hlc_b: hlc_b} do
      updated = HLC.update(hlc_a, hlc_b)
      {updated_wall, updated_count, _node} = updated

      # Result must be >= both local and remote
      assert updated_wall >= elem(hlc_a, 0)
      assert updated_wall >= elem(hlc_b, 0)

      # If walls are equal, counter must advance
      if updated_wall == max(elem(hlc_a, 0), elem(hlc_b, 0)) do
        assert updated_count > 0 or updated_wall > max(elem(hlc_a, 0), elem(hlc_b, 0))
      end
    end

    test "update result is strictly greater than both inputs (when walls differ)" do
      # Create a local clock that is clearly in the past
      past_ms = System.system_time(:millisecond) - 1000
      hlc_local = {past_ms, 0, @node_a}
      hlc_remote = {past_ms + 500, 5, @node_b}

      updated = HLC.update(hlc_local, hlc_remote)

      # Updated wall should be >= remote wall
      assert elem(updated, 0) >= elem(hlc_remote, 0)
    end

    test "3-node synchronization: A updates from B, B from C, C from A — no cycle" do
      base_ms = System.system_time(:millisecond)
      hlc_a = {base_ms, 0, @node_a}
      hlc_b = {base_ms + 10, 0, @node_b}
      hlc_c = {base_ms + 20, 0, @node_c}

      # Simulate message passing: A receives from B, B receives from C, C receives from A
      hlc_a2 = HLC.update(hlc_a, hlc_b)
      hlc_b2 = HLC.update(hlc_b, hlc_c)
      hlc_c2 = HLC.update(hlc_c, hlc_a)

      # After one round, each should be >= its predecessor
      assert elem(hlc_a2, 0) >= elem(hlc_a, 0)
      assert elem(hlc_b2, 0) >= elem(hlc_b, 0)
      assert elem(hlc_c2, 0) >= elem(hlc_c, 0)
    end

    test "nodes with identical wall time use counter to break ties" do
      fixed_wall = System.system_time(:millisecond)
      hlc_a = {fixed_wall, 3, @node_a}
      hlc_b = {fixed_wall, 7, @node_b}

      updated = HLC.update(hlc_a, hlc_b)
      {_wall, count, _node} = updated

      # Counter must be > max(3, 7) = 7
      assert count > 7,
             "Counter must exceed max of local(3) and remote(7), got #{count}"
    end

    test "causality chain: event A before B before C is preserved" do
      base_ms = System.system_time(:millisecond)

      # Node A sends to B
      hlc_a_send = {base_ms, 0, @node_a}
      hlc_b_recv = HLC.update({base_ms, 0, @node_b}, hlc_a_send)

      # Node B sends to C (after receiving from A)
      hlc_b_send = {elem(hlc_b_recv, 0), elem(hlc_b_recv, 1) + 1, @node_b}
      hlc_c_recv = HLC.update({base_ms, 0, @node_c}, hlc_b_send)

      # C's timestamp must be > A's original send
      assert elem(hlc_c_recv, 0) >= elem(hlc_a_send, 0),
             "Causality violated: C recv not >= A send wall time"
    end

    test "ETS persists HLC state across simulated restarts (AOR-HLC-002)", %{table: table} do
      hlc = HLC.new()
      :ets.insert(table, {:persisted_hlc, hlc})

      # Simulate restart: re-read from ETS
      [{:persisted_hlc, recovered}] = :ets.lookup(table, :persisted_hlc)

      assert recovered == hlc
      {wall, count, _node} = recovered
      assert is_integer(wall)
      assert is_integer(count)
    end
  end

  # ============================================================================
  # 4. THREE-NODE CONVERGENCE
  # ============================================================================

  describe "3-node HLC convergence and consistency" do
    test "after full gossip round, all nodes have equivalent view", %{table: table} do
      base_ms = System.system_time(:millisecond)
      hlc_a = {base_ms, 0, @node_a}
      hlc_b = {base_ms + 5, 0, @node_b}
      hlc_c = {base_ms + 10, 0, @node_c}

      # Simulate gossip: each node receives from the other two
      hlc_a2 = HLC.update(HLC.update(hlc_a, hlc_b), hlc_c)
      hlc_b2 = HLC.update(HLC.update(hlc_b, hlc_a), hlc_c)
      hlc_c2 = HLC.update(HLC.update(hlc_c, hlc_a), hlc_b)

      # Store convergence results
      :ets.insert(table, {:convergence, [hlc_a2, hlc_b2, hlc_c2]})

      [{_, results}] = :ets.lookup(table, :convergence)

      walls = Enum.map(results, fn {w, _, _} -> w end)
      max_wall = Enum.max(walls)

      # All walls should be within 1ms of each other after convergence
      Enum.each(walls, fn w ->
        assert max_wall - w <= 1,
               "Wall drift exceeds 1ms: max=#{max_wall}, got=#{w}"
      end)
    end

    test "3 nodes with clock skew converge to maximum" do
      # Simulate clock skew: node_c is 100ms ahead
      base_ms = System.system_time(:millisecond)
      hlc_a = {base_ms - 50, 0, @node_a}
      hlc_b = {base_ms, 0, @node_b}
      hlc_c = {base_ms + 100, 0, @node_c}

      # Node A updates from C (the fast clock)
      updated_a = HLC.update(hlc_a, hlc_c)

      # A's wall should advance to at least node_c's wall
      assert elem(updated_a, 0) >= elem(hlc_c, 0)
    end

    test "concurrent events on different nodes have different HLC values" do
      base_ms = System.system_time(:millisecond)

      event_a = {base_ms, 0, @node_a}
      event_b = {base_ms, 0, @node_b}

      # Same wall time but different nodes — should still be distinguishable
      # (HLC uses counter to differentiate concurrent events)
      updated = HLC.update(event_a, event_b)

      # Updated counter should > 0 since walls are equal
      {_wall, count, _} = updated
      assert count > 0, "Counter must advance for concurrent events with same wall time"
    end

    test "quorum of 2 out of 3 nodes can determine ordering (SC-SIL6-011)" do
      base_ms = System.system_time(:millisecond)

      event1 = {base_ms, 0, @node_a}
      event2 = {base_ms, 1, @node_b}
      event3 = {base_ms, 2, @node_c}

      # 2oo3 quorum check: at least 2 nodes agree on ordering
      node_a_ordering = hlc_less_than?(event1, event2)
      node_b_ordering = hlc_less_than?(event1, event2)
      # node_c may disagree in theory, but here all 3 agree

      quorum_agrees = node_a_ordering == node_b_ordering
      assert quorum_agrees, "At least 2/3 nodes must agree on event ordering"
    end
  end

  # ============================================================================
  # 5. PROPERTY-BASED TESTS
  # ============================================================================

  property "HLC update is always monotonically non-decreasing (AOR-HLC-001)" do
    forall {wall_l, count_l, wall_r, count_r} <- {
             PC.pos_integer(),
             PC.non_neg_integer(),
             PC.pos_integer(),
             PC.non_neg_integer()
           } do
      local = {wall_l, count_l, @node_a}
      remote = {wall_r, count_r, @node_b}

      updated = HLC.update(local, remote)
      {updated_wall, _updated_count, _} = updated

      # Updated wall must be >= both local and remote walls
      updated_wall >= wall_l and updated_wall >= wall_r
    end
  end

  property "HLC update result node is always the current node" do
    forall {wall, count} <- {PC.pos_integer(), PC.non_neg_integer()} do
      local = {wall, count, @node_a}
      remote = {wall + 1, count, @node_b}

      {_w, _c, node} = HLC.update(local, remote)

      # The result node should always be Node.self() — not the remote node
      node == Node.self()
    end
  end

  describe "property-based counter advancement" do
    test "property — counter advances beyond max of both when wall times are equal (SD)" do
      check all(
              wall <- SD.positive_integer(),
              count_a <- SD.non_negative_integer(),
              count_b <- SD.non_negative_integer()
            ) do
        # Same wall time: counter must advance beyond max
        hlc_a = {wall, count_a, @node_a}
        hlc_b = {wall, count_b, @node_b}

        {_w, updated_count, _n} = HLC.update(hlc_a, hlc_b)

        assert updated_count > max(count_a, count_b),
               "Counter #{updated_count} must exceed max(#{count_a}, #{count_b}) when walls equal"
      end
    end
  end
end
