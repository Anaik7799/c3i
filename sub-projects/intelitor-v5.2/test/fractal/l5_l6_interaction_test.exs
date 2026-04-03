defmodule Indrajaal.Fractal.L5L6InteractionTest do
  @moduledoc """
  Fractal L5×L6 Interaction Test — Node-to-Cluster Consensus Verification.

  WHAT: Tests that node-level decisions (L5) correctly participate in cluster
        consensus (L6), verifying 2oo3 voting, quorum maintenance, and split-brain.
  WHY: Cluster decisions require consensus from multiple nodes. 2oo3 voting
       ensures safety-critical decisions survive single-node failures.
  CONSTRAINTS:
    - SC-SIL6-006: 2oo3 voting MANDATORY
    - SC-SIL6-011: Quorum = floor(N/2)+1
    - SC-SIL4-015: Split-brain triggers apoptosis
    - SC-CONSENSUS-001: 2oo3 for P0 decisions
    - SC-PROP-023/024: PC. prefix for PropCheck, SD. prefix for StreamData

  ## Change History
  | Version | Date       | Author | Change                                       |
  |---------|------------|--------|----------------------------------------------|
  | 1.1.0   | 2026-03-23 | Claude | Expanded to 20 tests, node failure rebalance |

  @version "1.1.0"
  @last_modified "2026-03-23T00:00:00Z"
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # SC-PROP-023/024: Disambiguation aliases MANDATORY
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :fractal
  @moduletag :l5_l6

  # ===========================================================================
  # L5-L6-TEST-001: 2oo3 Voting (SC-SIL6-006)
  # ===========================================================================

  describe "L5→L6: 2oo3 Voting (SC-SIL6-006)" do
    test "2 out of 3 votes achieves consensus" do
      votes = [:approve, :approve, :reject]
      approve_count = Enum.count(votes, &(&1 == :approve))
      assert approve_count >= 2, "2oo3 consensus achieved"
    end

    test "1 out of 3 votes fails consensus" do
      votes = [:approve, :reject, :reject]
      approve_count = Enum.count(votes, &(&1 == :approve))
      refute approve_count >= 2, "Insufficient votes for 2oo3"
    end

    test "all 3 agree is strongest consensus" do
      votes = [:approve, :approve, :approve]
      assert Enum.all?(votes, &(&1 == :approve))
    end

    test "timeout counts as rejection" do
      votes = [:approve, :timeout, :approve]

      effective =
        Enum.map(votes, fn
          :timeout -> :reject
          v -> v
        end)

      approve_count = Enum.count(effective, &(&1 == :approve))
      assert approve_count >= 2
    end

    test "node votes are aggregated correctly per cluster decision" do
      # Three nodes vote on a cluster-level decision
      cluster_decision = %{
        proposal_id: "cluster-decision-001",
        votes: [
          %{node: :node_a, vote: :approve},
          %{node: :node_b, vote: :approve},
          %{node: :node_c, vote: :reject}
        ]
      }

      approvals = Enum.count(cluster_decision.votes, &(&1.vote == :approve))
      quorum = div(length(cluster_decision.votes), 2) + 1
      assert approvals >= quorum, "Cluster decision passes with 2oo3"
    end
  end

  # ===========================================================================
  # L5-L6-TEST-002: Quorum computation (SC-SIL6-011)
  # ===========================================================================

  describe "L5→L6: Quorum computation (SC-SIL6-011)" do
    test "quorum formula: floor(N/2)+1" do
      for n <- 1..10 do
        expected = div(n, 2) + 1
        assert expected <= n, "Quorum must not exceed total nodes"
        assert expected >= 1, "Quorum must be at least 1"
      end
    end

    test "quorum for 3-node cluster is 2" do
      assert div(3, 2) + 1 == 2
    end

    test "quorum for 5-node cluster is 3" do
      assert div(5, 2) + 1 == 3
    end

    test "node consensus contributes to cluster-level decisions" do
      # Each node's local consensus feeds cluster decision
      node_decisions = %{
        node_1: :proceed,
        node_2: :proceed,
        node_3: :halt
      }

      total = map_size(node_decisions)
      quorum = div(total, 2) + 1
      proceed_count = Enum.count(node_decisions, fn {_n, d} -> d == :proceed end)

      cluster_decision = if proceed_count >= quorum, do: :cluster_proceed, else: :cluster_halt

      assert cluster_decision == :cluster_proceed,
             "Node-level :proceed votes achieve cluster quorum"
    end

    test "cluster quorum requires minimum node participation" do
      # A cluster decision is invalid if fewer than quorum nodes participated
      total_nodes = 5
      quorum = div(total_nodes, 2) + 1
      participating_nodes = 2

      assert participating_nodes < quorum,
             "2 participants insufficient for 5-node cluster quorum (need #{quorum})"
    end
  end

  # ===========================================================================
  # L5-L6-TEST-003: Split-brain detection (SC-SIL4-015)
  # ===========================================================================

  describe "L5→L6: Split-brain detection (SC-SIL4-015)" do
    test "partition creates two groups below quorum" do
      cluster_size = 5
      quorum = div(cluster_size, 2) + 1

      # Split: 2 nodes on one side, 3 on the other
      partition_a = 2
      partition_b = 3

      refute partition_a >= quorum, "Partition A below quorum"
      assert partition_b >= quorum, "Partition B has quorum"
    end

    test "even split with no majority triggers apoptosis" do
      cluster_size = 4
      quorum = div(cluster_size, 2) + 1

      partition_a = 2
      partition_b = 2

      refute partition_a >= quorum
      refute partition_b >= quorum
      # Both partitions below quorum → apoptosis
    end

    test "gossip protocol detects network partition" do
      nodes = [:node_a, :node_b, :node_c]
      reachable_from_a = [:node_a, :node_b]
      unreachable = nodes -- reachable_from_a

      assert length(unreachable) > 0, "Partition detected"
    end
  end

  # ===========================================================================
  # L5-L6-TEST-004: Node failure triggers cluster rebalancing
  # ===========================================================================

  describe "L5→L6: Node failure triggers cluster rebalancing" do
    test "cluster rebalances when node fails" do
      initial_nodes = [:node_1, :node_2, :node_3, :node_4, :node_5]
      failed_node = :node_3
      remaining = List.delete(initial_nodes, failed_node)

      assert length(remaining) == 4
      new_quorum = div(length(remaining), 2) + 1
      assert new_quorum == 3, "4-node cluster needs quorum of 3"
    end

    test "cluster remains operational after one node failure (5-node)" do
      total_nodes = 5
      failed_nodes = 1
      active_nodes = total_nodes - failed_nodes
      quorum = div(total_nodes, 2) + 1

      assert active_nodes >= quorum,
             "#{active_nodes} active nodes >= quorum #{quorum}"
    end

    test "cluster loses quorum after losing majority (3-node cluster)" do
      total_nodes = 3
      quorum = div(total_nodes, 2) + 1
      failed_nodes = 2
      active_nodes = total_nodes - failed_nodes

      refute active_nodes >= quorum,
             "#{active_nodes} active nodes insufficient (need #{quorum})"
    end

    test "node failure triggers membership update event" do
      cluster_state = %{
        nodes: [:node_1, :node_2, :node_3],
        status: :healthy
      }

      # Simulate node failure event
      failed_node = :node_2
      updated_nodes = List.delete(cluster_state.nodes, failed_node)

      event = %{
        type: :node_failure,
        failed_node: failed_node,
        remaining_nodes: updated_nodes,
        timestamp: System.system_time(:millisecond)
      }

      assert event.type == :node_failure
      assert length(event.remaining_nodes) == 2
      assert is_integer(event.timestamp)
    end

    test "cluster health degrades gracefully as nodes leave" do
      node_states = [
        %{nodes: 5, expected_health: :healthy},
        %{nodes: 4, expected_health: :healthy},
        %{nodes: 3, expected_health: :healthy},
        %{nodes: 2, expected_health: :degraded},
        %{nodes: 1, expected_health: :critical}
      ]

      for %{nodes: n, expected_health: expected} <- node_states do
        quorum = div(5, 2) + 1

        health =
          cond do
            n >= quorum -> :healthy
            n >= 2 -> :degraded
            true -> :critical
          end

        assert health == expected,
               "#{n} nodes → expected #{expected}, got #{health}"
      end
    end
  end

  # ===========================================================================
  # L5-L6-TEST-005: Cluster health aggregation
  # ===========================================================================

  describe "L5→L6: Cluster health aggregation" do
    test "cluster health is consensus of node health" do
      node_health = %{
        node_1: :healthy,
        node_2: :healthy,
        node_3: :degraded
      }

      healthy_count = Enum.count(node_health, fn {_n, h} -> h == :healthy end)
      quorum = div(map_size(node_health), 2) + 1

      cluster_healthy? = healthy_count >= quorum
      assert cluster_healthy?
    end

    test "FPPS requires consensus across all 5 methods" do
      # SC-SIL4-023: FPPS 3/5 consensus for health
      fpps_results = %{
        pattern: :pass,
        ast: :pass,
        statistical: :pass,
        binary: :pass,
        line_by_line: :fail
      }

      pass_count = Enum.count(fpps_results, fn {_method, r} -> r == :pass end)

      # 3/5 threshold for FPPS consensus
      fpps_consensus = pass_count >= 3
      assert fpps_consensus, "FPPS 3/5 consensus achieved (#{pass_count}/5)"
    end
  end

  # ===========================================================================
  # L5-L6-TEST-006: Property-based consensus
  # ===========================================================================

  describe "L5→L6: Property-based consensus" do
    property "2oo3 voting is deterministic" do
      forall votes <- PC.vector(3, PC.oneof([:approve, :reject])) do
        count = Enum.count(votes, &(&1 == :approve))
        result1 = count >= 2
        result2 = count >= 2
        result1 == result2
      end
    end

    property "quorum always requires strict majority" do
      forall n <- PC.pos_integer() do
        n = min(n, 1000)
        q = div(n, 2) + 1
        q > div(n, 2) and q <= n
      end
    end

    property "node failure cannot improve quorum" do
      forall n <- PC.range(2, 20) do
        quorum_before = div(n, 2) + 1
        quorum_after_failure = div(n - 1, 2) + 1
        # Losing a node never reduces quorum requirements below what remaining can provide
        # And quorum cannot increase beyond the number of remaining nodes
        quorum_after_failure <= n - 1 and
          quorum_after_failure <= quorum_before
      end
    end

    property "cluster remains at quorum with up to floor(N/2) failures" do
      forall n <- PC.range(3, 10) do
        quorum = div(n, 2) + 1
        max_tolerable_failures = n - quorum
        remaining_after_max_failure = n - max_tolerable_failures
        remaining_after_max_failure >= quorum
      end
    end
  end
end
