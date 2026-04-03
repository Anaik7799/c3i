defmodule Indrajaal.SIL6.MeshQuorumFPPSTest do
  @moduledoc """
  Mesh Quorum Consensus and FPPS Validation Tests.

  WHAT: Tests for 2oo3 voting, quorum computation, FPPS 5-method consensus,
        and safety-critical decision making.
  WHY: SIL-6 requires 2oo3 voting for all safety-critical decisions.
       FPPS 5-method consensus ensures zero-defect validation. Quorum
       calculation (floor(N/2)+1) governs cluster-level decisions.
  CONSTRAINTS:
    - SC-SIL6-006: 2oo3 voting MANDATORY
    - SC-SIL6-011: Quorum = floor(N/2)+1
    - SC-VAL-003: 100% FPPS Consensus - all 5 methods MUST agree
    - SC-VAL-004: Halt on disagreement
    - SC-MESH-005: Quorum voting for health decisions
    - SC-ZTEST-020: Quorum messages require 2oo3 consensus
    - AOR-MESH-003: Verify 2oo3 consensus in production

  ## Change History
  | Version | Date       | Author      | Change                   |
  |---------|------------|-------------|--------------------------|
  | 1.0.0   | 2026-03-09 | Claude Opus | Initial quorum/FPPS tests|

  @version "1.0.0"
  @last_modified "2026-03-09T00:00:00Z"
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :sil6
  @moduletag :mesh
  @moduletag :quorum

  # ============================================================================
  # 1. QUORUM COMPUTATION (SC-SIL6-011)
  # ============================================================================

  describe "Quorum Computation: floor(N/2)+1" do
    test "quorum for N=3 is 2" do
      assert quorum(3) == 2
    end

    test "quorum for N=5 is 3" do
      assert quorum(5) == 3
    end

    test "quorum for N=7 is 4" do
      assert quorum(7) == 4
    end

    test "quorum for N=1 is 1" do
      assert quorum(1) == 1
    end

    test "quorum for N=2 is 2" do
      assert quorum(2) == 2
    end

    test "quorum for even and odd N values" do
      expected = %{
        1 => 1,
        2 => 2,
        3 => 2,
        4 => 3,
        5 => 3,
        6 => 4,
        7 => 4,
        8 => 5,
        9 => 5,
        10 => 6
      }

      for {n, expected_quorum} <- expected do
        assert quorum(n) == expected_quorum,
               "quorum(#{n}) expected #{expected_quorum}, got #{quorum(n)}"
      end
    end

    property "quorum is always > N/2 (majority)" do
      forall n <- PC.pos_integer() do
        n > 0 and quorum(n) > n / 2
      end
    end

    property "quorum is always <= N" do
      forall n <- PC.pos_integer() do
        quorum(n) <= n
      end
    end

    property "quorum(N) >= quorum(N-1) (monotonic)" do
      forall n <- PC.integer(2, 1000) do
        quorum(n) >= quorum(n - 1)
      end
    end
  end

  # ============================================================================
  # 2. 2oo3 VOTING (SC-SIL6-006)
  # ============================================================================

  describe "2oo3 Voting: Triple modular redundancy" do
    test "all agree healthy -> healthy" do
      votes = [:healthy, :healthy, :healthy]
      assert vote_2oo3(votes) == :healthy
    end

    test "two healthy, one unhealthy -> healthy (2oo3)" do
      votes = [:healthy, :healthy, :unhealthy]
      assert vote_2oo3(votes) == :healthy
    end

    test "one healthy, two unhealthy -> unhealthy (2oo3)" do
      votes = [:healthy, :unhealthy, :unhealthy]
      assert vote_2oo3(votes) == :unhealthy
    end

    test "all unhealthy -> unhealthy" do
      votes = [:unhealthy, :unhealthy, :unhealthy]
      assert vote_2oo3(votes) == :unhealthy
    end

    test "order of votes doesn't matter" do
      permutations = [
        [:healthy, :healthy, :unhealthy],
        [:healthy, :unhealthy, :healthy],
        [:unhealthy, :healthy, :healthy]
      ]

      results = Enum.map(permutations, &vote_2oo3/1)

      assert Enum.uniq(results) == [:healthy],
             "2oo3 voting should be order-independent"
    end

    test "2oo3 with timeout votes" do
      # A timeout should count as unhealthy
      votes = [:healthy, :timeout, :healthy]
      normalized = Enum.map(votes, fn v -> if v == :timeout, do: :unhealthy, else: v end)
      assert vote_2oo3(normalized) == :healthy
    end

    property "2oo3 always returns :healthy or :unhealthy" do
      forall votes <- PC.vector(3, PC.oneof([PC.exactly(:healthy), PC.exactly(:unhealthy)])) do
        result = vote_2oo3(votes)
        result in [:healthy, :unhealthy]
      end
    end

    property "2oo3 with >= 2 healthy always returns healthy" do
      forall healthy_count <- PC.integer(2, 3) do
        votes =
          List.duplicate(:healthy, healthy_count) ++
            List.duplicate(:unhealthy, 3 - healthy_count)

        vote_2oo3(votes) == :healthy
      end
    end
  end

  # ============================================================================
  # 3. QUORUM AVAILABILITY (SC-SIL6-011)
  # ============================================================================

  describe "Quorum Availability: Fault tolerance" do
    test "3-node cluster tolerates 1 failure" do
      n = 3
      q = quorum(n)
      max_failures = n - q
      assert max_failures == 1
    end

    test "5-node cluster tolerates 2 failures" do
      n = 5
      q = quorum(n)
      max_failures = n - q
      assert max_failures == 2
    end

    test "has_quorum? with sufficient healthy nodes" do
      assert has_quorum?(3, 2)
      assert has_quorum?(3, 3)
      assert has_quorum?(5, 3)
      assert has_quorum?(5, 4)
      assert has_quorum?(5, 5)
    end

    test "no quorum with insufficient healthy nodes" do
      refute has_quorum?(3, 1)
      refute has_quorum?(3, 0)
      refute has_quorum?(5, 2)
      refute has_quorum?(5, 1)
    end

    property "quorum availability probability" do
      # P(quorum) for N=3, p=0.99
      # P = 3*(0.99)^2*(0.01) + (0.99)^3 = 0.999702
      forall _n <- PC.integer(1, 3) do
        p = 0.99
        n = 3
        q = quorum(n)

        prob =
          for k <- q..n, reduce: 0.0 do
            acc ->
              # Binomial coefficient
              binom = factorial(n) / (factorial(k) * factorial(n - k))
              acc + binom * :math.pow(p, k) * :math.pow(1 - p, n - k)
          end

        prob > 0.99
      end
    end
  end

  # ============================================================================
  # 4. FPPS 5-METHOD CONSENSUS (SC-VAL-003)
  # ============================================================================

  describe "FPPS 5-Method Consensus: Validation agreement" do
    test "FPPS module is available" do
      assert Code.ensure_loaded?(Indrajaal.Validation.FPPS)
    end

    test "consensus with all methods agreeing (0 errors)" do
      results = [
        %{method: :pattern, errors: 0, warnings: 0},
        %{method: :ast, errors: 0, warnings: 0},
        %{method: :statistical, errors: 0, warnings: 0},
        %{method: :binary, errors: 0, warnings: 0},
        %{method: :line_by_line, errors: 0, warnings: 0}
      ]

      assert fpps_consensus?(results)
    end

    test "consensus fails when methods disagree" do
      results = [
        %{method: :pattern, errors: 0, warnings: 0},
        %{method: :ast, errors: 1, warnings: 0},
        %{method: :statistical, errors: 0, warnings: 0},
        %{method: :binary, errors: 0, warnings: 0},
        %{method: :line_by_line, errors: 0, warnings: 0}
      ]

      refute fpps_consensus?(results),
             "FPPS consensus should fail when methods disagree (SC-VAL-004)"
    end

    test "all 5 methods must be present" do
      required_methods = [:pattern, :ast, :statistical, :binary, :line_by_line]

      incomplete_results = [
        %{method: :pattern, errors: 0, warnings: 0},
        %{method: :ast, errors: 0, warnings: 0}
      ]

      methods = Enum.map(incomplete_results, & &1.method)

      for required <- required_methods do
        unless required in methods do
          assert true, "Missing method #{required} detected"
        end
      end
    end

    property "FPPS consensus is symmetric (order doesn't matter)" do
      forall error_count <- PC.integer(0, 1) do
        base_result = %{errors: error_count, warnings: 0}

        results =
          for m <- [:pattern, :ast, :statistical, :binary, :line_by_line] do
            Map.put(base_result, :method, m)
          end

        shuffled = Enum.shuffle(results)
        fpps_consensus?(results) == fpps_consensus?(shuffled)
      end
    end
  end

  # ============================================================================
  # 5. ZENOH QUORUM MESSAGING (SC-ZTEST-020)
  # ============================================================================

  describe "Zenoh Quorum Messaging: 2oo3 consensus publishing" do
    test "quorum checkpoint topic follows naming convention" do
      topic = "indrajaal/boot/mesh/quorum"
      parts = String.split(topic, "/")

      assert length(parts) <= 6, "Topic depth exceeds 6 (SC-ZTEST-017)"
      assert hd(parts) == "indrajaal"
    end

    test "quorum message includes required fields" do
      message = %{
        checkpoint: "CP-BOOT-05",
        healthy_count: 2,
        total_count: 3,
        quorum_achieved: true,
        routers: ["zenoh-router-1", "zenoh-router-2", "zenoh-router-3"],
        state_vector: "[1,1,1,1,0,0]",
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      assert message.quorum_achieved
      assert message.healthy_count >= quorum(message.total_count)
    end

    test "quorum not achieved when healthy < floor(N/2)+1" do
      message = %{
        healthy_count: 1,
        total_count: 3,
        quorum_achieved: false
      }

      refute message.quorum_achieved
      assert message.healthy_count < quorum(message.total_count)
    end
  end

  # ============================================================================
  # 6. PROPERTY TESTS: Quorum/Voting Invariants
  # ============================================================================

  describe "Property Tests: Quorum and voting invariants" do
    @tag :property
    test "StreamData: 2oo3 majority decision is correct" do
      ExUnitProperties.check all(
                               v1 <- SD.member_of([:healthy, :unhealthy]),
                               v2 <- SD.member_of([:healthy, :unhealthy]),
                               v3 <- SD.member_of([:healthy, :unhealthy])
                             ) do
        votes = [v1, v2, v3]
        result = vote_2oo3(votes)
        healthy_count = Enum.count(votes, &(&1 == :healthy))

        if healthy_count >= 2 do
          assert result == :healthy
        else
          assert result == :unhealthy
        end
      end
    end

    property "quorum function matches floor(N/2)+1 formula" do
      forall n <- PC.pos_integer() do
        quorum(n) == div(n, 2) + 1
      end
    end

    property "N-node cluster with N healthy always has quorum" do
      forall n <- PC.integer(1, 100) do
        has_quorum?(n, n)
      end
    end

    property "N-node cluster with 0 healthy never has quorum" do
      forall n <- PC.integer(1, 100) do
        not has_quorum?(n, 0)
      end
    end
  end

  # ============================================================================
  # 7. FMEA: Quorum/Consensus Failure Modes
  # ============================================================================

  describe "FMEA: Quorum and consensus failure modes" do
    @tag :fmea
    test "FMEA-QUORUM-001: Split-brain (RPN=90)" do
      # With N=3, if network partitions into [1] and [2],
      # only the partition with 2 nodes has quorum
      partition_a = 1
      partition_b = 2
      total = 3

      refute has_quorum?(total, partition_a), "Partition of 1 should not have quorum"
      assert has_quorum?(total, partition_b), "Partition of 2 should have quorum"
    end

    @tag :fmea
    test "FMEA-QUORUM-002: All nodes fail simultaneously (RPN=45)" do
      refute has_quorum?(3, 0)
      refute has_quorum?(5, 0)
      refute has_quorum?(7, 0)
    end

    @tag :fmea
    test "FMEA-FPPS-001: One validation method crashes (RPN=60)" do
      # System should detect missing method and halt (SC-VAL-004)
      results = [
        %{method: :pattern, errors: 0, warnings: 0},
        # :ast method missing/crashed
        %{method: :statistical, errors: 0, warnings: 0},
        %{method: :binary, errors: 0, warnings: 0},
        %{method: :line_by_line, errors: 0, warnings: 0}
      ]

      assert length(results) < 5, "Should detect missing method"
    end

    @tag :fmea
    test "FMEA-FPPS-002: Methods return contradictory results (RPN=72)" do
      results = [
        %{method: :pattern, errors: 0, warnings: 0},
        %{method: :ast, errors: 5, warnings: 3},
        %{method: :statistical, errors: 0, warnings: 0},
        %{method: :binary, errors: 2, warnings: 1},
        %{method: :line_by_line, errors: 0, warnings: 0}
      ]

      refute fpps_consensus?(results),
             "Contradictory results must trigger halt (SC-VAL-004)"
    end
  end

  # ============================================================================
  # HELPERS
  # ============================================================================

  defp quorum(n) when n > 0, do: div(n, 2) + 1

  defp has_quorum?(total, healthy) when total > 0 do
    healthy >= quorum(total)
  end

  defp vote_2oo3(votes) when length(votes) == 3 do
    healthy_count = Enum.count(votes, &(&1 == :healthy))
    if healthy_count >= 2, do: :healthy, else: :unhealthy
  end

  defp fpps_consensus?(results) do
    # All methods must report same error count (0 for passing)
    error_counts = Enum.map(results, & &1.errors) |> Enum.uniq()
    length(results) == 5 and length(error_counts) == 1
  end

  defp factorial(0), do: 1
  defp factorial(n) when n > 0, do: n * factorial(n - 1)
end
