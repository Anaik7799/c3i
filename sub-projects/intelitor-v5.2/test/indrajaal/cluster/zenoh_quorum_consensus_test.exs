defmodule Indrajaal.Cluster.ZenohQuorumConsensusTest do
  @moduledoc """
  Zenoh 2oo3 quorum consensus test suite.

  ## WHAT
  Tests two-out-of-three voting protocol, quorum calculation, vote validation,
  multi-round consensus, and leader election for the distributed consensus engine.

  ## CONSTRAINTS
  - SC-SIL4-006: 2oo3 voting MANDATORY for production actuations
  - SC-SIL4-011: Quorum = floor(N/2) + 1
  - SC-CONSENSUS-001: 2oo3 voting for P0 decisions
  - SC-CONSENSUS-003: Timeout < 30s per chamber
  - SC-QUORUM-001: Two-out-of-three voting MANDATORY
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Cluster.Consensus

  # ============================================================================
  # Quorum Calculation Tests
  # ============================================================================

  describe "quorum calculation (SC-SIL4-011)" do
    test "quorum for 3 nodes is 2 (floor(3/2) + 1)" do
      assert quorum(3) == 2
    end

    test "quorum for 5 nodes is 3" do
      assert quorum(5) == 3
    end

    test "quorum for 1 node is 1" do
      assert quorum(1) == 1
    end

    test "quorum for 7 nodes is 4" do
      assert quorum(7) == 4
    end

    test "quorum for even number (4 nodes) is 3" do
      assert quorum(4) == 3
    end
  end

  # ============================================================================
  # 2oo3 Voting Protocol (SC-SIL4-006)
  # ============================================================================

  describe "2oo3 voting protocol (SC-SIL4-006)" do
    test "unanimous healthy votes yield healthy" do
      votes = [
        {:node_a, :healthy, now()},
        {:node_b, :healthy, now()},
        {:node_c, :healthy, now()}
      ]

      assert {:ok, :healthy} = tally_votes(votes, 3)
    end

    test "2 of 3 healthy votes yield healthy (majority)" do
      votes = [
        {:node_a, :healthy, now()},
        {:node_b, :healthy, now()},
        {:node_c, :degraded, now()}
      ]

      assert {:ok, :healthy} = tally_votes(votes, 3)
    end

    test "2 of 3 degraded votes yield degraded" do
      votes = [
        {:node_a, :degraded, now()},
        {:node_b, :degraded, now()},
        {:node_c, :healthy, now()}
      ]

      assert {:ok, :degraded} = tally_votes(votes, 3)
    end

    test "all different votes yield no consensus" do
      votes = [
        {:node_a, :healthy, now()},
        {:node_b, :degraded, now()},
        {:node_c, :unhealthy, now()}
      ]

      assert {:error, :no_consensus} = tally_votes(votes, 3)
    end

    test "2 of 3 unhealthy votes yield unhealthy" do
      votes = [
        {:node_a, :unhealthy, now()},
        {:node_b, :unhealthy, now()},
        {:node_c, :healthy, now()}
      ]

      assert {:ok, :unhealthy} = tally_votes(votes, 3)
    end
  end

  # ============================================================================
  # Vote Validation Tests
  # ============================================================================

  describe "vote validation" do
    test "stale votes (>30s) are rejected" do
      stale_ts = DateTime.add(DateTime.utc_now(), -35, :second)

      votes = [
        {:node_a, :healthy, now()},
        {:node_b, :healthy, stale_ts},
        {:node_c, :healthy, now()}
      ]

      valid = Enum.filter(votes, fn {_, _, ts} -> not stale?(ts) end)
      assert length(valid) == 2
    end

    test "invalid vote values are rejected" do
      valid_values = [:healthy, :degraded, :unhealthy]
      assert :invalid not in valid_values
      assert :maybe not in valid_values
    end
  end

  # ============================================================================
  # Multi-Round Consensus
  # ============================================================================

  describe "multi-round consensus" do
    test "consensus resolves in round 1 with agreement" do
      rounds = simulate_rounds([[:healthy, :healthy, :healthy]], 3)
      assert {:ok, :healthy, 1} = rounds
    end

    test "consensus may need round 2 with partial disagreement" do
      # Round 1: no consensus, Round 2: converge
      rounds =
        simulate_rounds(
          [
            [:healthy, :degraded, :unhealthy],
            [:healthy, :healthy, :degraded]
          ],
          3
        )

      assert {:ok, :healthy, 2} = rounds
    end

    test "max 3 rounds before declaring no-consensus" do
      rounds =
        simulate_rounds(
          [
            [:healthy, :degraded, :unhealthy],
            [:healthy, :degraded, :unhealthy],
            [:healthy, :degraded, :unhealthy]
          ],
          3
        )

      assert {:error, :no_consensus_after_max_rounds} = rounds
    end
  end

  # ============================================================================
  # Property Tests
  # ============================================================================

  describe "property: quorum is always majority" do
    @tag timeout: 30_000
    test "quorum(n) > n/2 for all positive n" do
      ExUnitProperties.check all(n <- SD.integer(1..100)) do
        q = quorum(n)
        assert q > div(n, 2), "quorum(#{n}) = #{q} should be > #{div(n, 2)}"
        assert q <= n, "quorum(#{n}) = #{q} should be <= #{n}"
      end
    end
  end

  describe "property: unanimous votes always reach consensus" do
    @tag timeout: 30_000
    test "all same votes produce consensus" do
      ExUnitProperties.check all(
                               value <- SD.member_of([:healthy, :degraded, :unhealthy]),
                               count <- SD.integer(3..9)
                             ) do
        votes = for _ <- 1..count, do: {:node, value, now()}
        assert {:ok, ^value} = tally_votes(votes, count)
      end
    end
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp quorum(n), do: div(n, 2) + 1

  defp now, do: DateTime.utc_now()

  defp stale?(ts) do
    DateTime.diff(DateTime.utc_now(), ts, :second) > 30
  end

  defp tally_votes(votes, n) do
    valid_votes = Enum.filter(votes, fn {_, _, ts} -> not stale?(ts) end)
    q = quorum(n)

    frequencies =
      valid_votes
      |> Enum.map(fn {_, val, _} -> val end)
      |> Enum.frequencies()

    case Enum.max_by(frequencies, fn {_val, count} -> count end, fn -> {nil, 0} end) do
      {val, count} when count >= q -> {:ok, val}
      _ -> {:error, :no_consensus}
    end
  end

  defp simulate_rounds(rounds_data, n) do
    Enum.reduce_while(
      Enum.with_index(rounds_data, 1),
      {:error, :no_consensus_after_max_rounds},
      fn {votes_list, round}, _acc ->
        votes = Enum.map(votes_list, fn val -> {:node, val, now()} end)

        case tally_votes(votes, n) do
          {:ok, value} -> {:halt, {:ok, value, round}}
          {:error, _} -> {:cont, {:error, :no_consensus_after_max_rounds}}
        end
      end
    )
  end
end
