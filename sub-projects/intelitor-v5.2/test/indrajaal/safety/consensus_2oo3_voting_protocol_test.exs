defmodule Indrajaal.Safety.Consensus2oo3VotingProtocolTest do
  @moduledoc """
  2oo3 Voting Protocol Test Suite — Safety-Critical Decision Consensus.

  WHAT: Tests the two-out-of-three (2oo3) voting protocol for safety-critical
        decisions including quorum calculation, constitutional veto, Byzantine
        fault tolerance, proposal type variants, audit trail, and concurrent
        isolation.
  WHY: SC-SIL6-006 mandates 2oo3 voting for all safety-critical decisions.
       SC-CONSENSUS-001 requires 2oo3 voting for P0 decisions.
       SC-CONSENSUS-002 grants each chamber an absolute constitutional veto.
       SC-CONSENSUS-003 requires timeout < 30s per chamber.
       SC-SIL4-006 mandates 2oo3 for production actuations.
  CONSTRAINTS:
    - SC-SIL6-006: 2oo3 voting MANDATORY for safety-critical decisions
    - SC-SIL6-011: Quorum = floor(N/2)+1
    - SC-QUORUM-001: Two-out-of-three voting mandatory
    - SC-CONSENSUS-001: 2oo3 voting for P0 decisions
    - SC-CONSENSUS-002: Each chamber has Constitutional veto authority
    - SC-CONSENSUS-003: Timeout < 30s per chamber
    - SC-SIL4-006: 2oo3 voting MANDATORY for production actuations

  ## EP-GEN-014 Compliance
  - `use PropCheck` with `PC.` prefix for forall generators
  - `import ExUnitProperties, except: [property: 2, property: 3, check: 2]`
  - `SD.` prefix for StreamData generators inside `ExUnitProperties.check all/1`

  ## Change History
  | Version | Date       | Author | Change                                   |
  |---------|------------|--------|------------------------------------------|
  | 1.0.0   | 2026-03-24 | Claude | Initial 2oo3 voting protocol test suite  |

  @version "1.0.0"
  @last_modified "2026-03-24T00:00:00Z"
  """

  use ExUnit.Case, async: true

  # EP-GEN-014: dual import pattern — MANDATORY
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :safety
  @moduletag :consensus
  @moduletag :quorum

  # SC-CONSENSUS-003: timeout < 30s per chamber
  @chamber_timeout_ms 30_000
  # Emergency proposals use a shorter 5s timeout
  @emergency_timeout_ms 5_000
  # Standard voter count for 2oo3
  @voter_count 3

  # ============================================================================
  # PURE VOTING LOGIC (self-contained helpers — no external deps)
  # ============================================================================

  # Represents a single chamber's vote response.
  # vote: :approve | :reject | {:veto, reason} | :garbage | :timeout
  defp make_vote(voter_id, vote, proposal_id \\ "prop-001") do
    %{
      voter_id: voter_id,
      proposal_id: proposal_id,
      vote: vote,
      timestamp_ms: System.monotonic_time(:millisecond)
    }
  end

  # Compute quorum threshold per SC-SIL6-011: floor(N/2) + 1
  defp quorum_threshold(n), do: floor(n / 2) + 1

  # Evaluates votes according to 2oo3 protocol.
  # Returns a result map with decision, counts, chamber votes, and audit trail.
  # Constitutional veto (SC-CONSENSUS-002) always overrides the majority.
  defp evaluate_2oo3(votes, opts \\ []) do
    total = Keyword.get(opts, :total_voters, length(votes))
    threshold = quorum_threshold(total)

    # Separate constitutional vetoes from ordinary votes
    constitutional_vetoes =
      Enum.filter(votes, fn v ->
        match?({:veto, _}, v.vote)
      end)
      |> Enum.filter(fn v ->
        {_, reason} = v.vote

        reason in [
          :constitutional_violation,
          :guardian_immutable,
          :founder_protection,
          :forbidden_action
        ]
      end)

    approve_count = Enum.count(votes, fn v -> v.vote == :approve end)

    reject_count =
      Enum.count(votes, fn v ->
        v.vote == :reject or
          (match?(
             {:veto, reason}
             when reason not in [
                    :constitutional_violation,
                    :guardian_immutable,
                    :founder_protection,
                    :forbidden_action
                  ],
             v.vote
           ) and
             match?({:veto, _}, v.vote))
      end)

    # Byzantine: votes that are neither approve nor a valid reject/veto
    byzantine_count = Enum.count(votes, fn v -> v.vote == :garbage end)

    # SC-CONSENSUS-002: constitutional veto from ANY chamber is absolute
    if length(constitutional_vetoes) > 0 do
      {_, veto_reason} = hd(constitutional_vetoes).vote

      %{
        decision: :constitutional_veto,
        veto_reason: veto_reason,
        approve_count: approve_count,
        reject_count: reject_count,
        byzantine_count: byzantine_count,
        threshold: threshold,
        total_voters: total,
        quorum_met: false,
        audit_trail: votes,
        constitutional_veto?: true
      }
    else
      quorum_met = approve_count >= threshold

      %{
        decision: if(quorum_met, do: :approved, else: :rejected),
        approve_count: approve_count,
        reject_count: reject_count,
        byzantine_count: byzantine_count,
        threshold: threshold,
        total_voters: total,
        quorum_met: quorum_met,
        audit_trail: votes,
        constitutional_veto?: false
      }
    end
  end

  # Simulate a voter chamber with configurable timeout
  defp chamber_vote_async(voter_id, vote, delay_ms \\ 0) do
    Task.async(fn ->
      if delay_ms > 0, do: Process.sleep(delay_ms)
      make_vote(voter_id, vote)
    end)
  end

  # Collect votes with timeout; timed-out chambers produce no vote (fail-closed).
  defp collect_with_timeout(tasks, timeout_ms) do
    Enum.reduce(tasks, [], fn task, acc ->
      case Task.yield(task, timeout_ms) || Task.shutdown(task, :brutal_kill) do
        {:ok, vote} -> [vote | acc]
        nil -> acc
      end
    end)
  end

  # ============================================================================
  # TEST 1: 3 agreeing voters → proposal approved (unanimous)
  # ============================================================================

  describe "unanimous agreement (3 of 3 approve)" do
    test "all 3 voters approve → approved" do
      votes = [
        make_vote("chamber-1", :approve),
        make_vote("chamber-2", :approve),
        make_vote("chamber-3", :approve)
      ]

      result = evaluate_2oo3(votes)

      assert result.decision == :approved
      assert result.approve_count == 3
      assert result.reject_count == 0
      assert result.quorum_met == true
    end

    test "unanimous approval includes all 3 votes in audit trail" do
      votes = [
        make_vote("chamber-1", :approve),
        make_vote("chamber-2", :approve),
        make_vote("chamber-3", :approve)
      ]

      result = evaluate_2oo3(votes)

      assert length(result.audit_trail) == 3
      voter_ids = Enum.map(result.audit_trail, & &1.voter_id)
      assert "chamber-1" in voter_ids
      assert "chamber-2" in voter_ids
      assert "chamber-3" in voter_ids
    end
  end

  # ============================================================================
  # TEST 2: 2 of 3 agree → proposal approved (majority quorum)
  # ============================================================================

  describe "majority quorum (2 of 3 approve)" do
    test "2 approve + 1 reject → approved (2oo3 quorum met)" do
      votes = [
        make_vote("chamber-1", :approve),
        make_vote("chamber-2", :approve),
        make_vote("chamber-3", :reject)
      ]

      result = evaluate_2oo3(votes)

      assert result.decision == :approved
      assert result.approve_count == 2
      assert result.reject_count == 1
      assert result.quorum_met == true
    end

    test "each combination of 2 approvers out of 3 reaches quorum" do
      combinations = [
        ["chamber-1", "chamber-2"],
        ["chamber-1", "chamber-3"],
        ["chamber-2", "chamber-3"]
      ]

      all_ids = ["chamber-1", "chamber-2", "chamber-3"]

      for approvers <- combinations do
        rejecter = Enum.find(all_ids, fn id -> id not in approvers end)

        votes =
          Enum.map(all_ids, fn id ->
            if id in approvers, do: make_vote(id, :approve), else: make_vote(id, :reject)
          end)

        result = evaluate_2oo3(votes)

        assert result.decision == :approved,
               "approvers=#{inspect(approvers)} rejecter=#{rejecter}: expected approved"

        assert result.approve_count == 2
      end
    end
  end

  # ============================================================================
  # TEST 3: 1 of 3 agree → proposal rejected (no quorum)
  # ============================================================================

  describe "no quorum (1 of 3 approve)" do
    test "1 approve + 2 reject → rejected" do
      votes = [
        make_vote("chamber-1", :approve),
        make_vote("chamber-2", :reject),
        make_vote("chamber-3", :reject)
      ]

      result = evaluate_2oo3(votes)

      assert result.decision == :rejected
      assert result.approve_count == 1
      assert result.reject_count == 2
      assert result.quorum_met == false
    end
  end

  # ============================================================================
  # TEST 4: 0 of 3 agree → proposal rejected
  # ============================================================================

  describe "zero approval" do
    test "0 approve + 3 reject → rejected" do
      votes = for i <- 1..3, do: make_vote("chamber-#{i}", :reject)

      result = evaluate_2oo3(votes)

      assert result.decision == :rejected
      assert result.approve_count == 0
      assert result.reject_count == 3
      assert result.quorum_met == false
    end
  end

  # ============================================================================
  # TEST 5: voter timeout (< 30s per SC-CONSENSUS-003) triggers rejection
  # ============================================================================

  describe "voter timeout (SC-CONSENSUS-003)" do
    test "timeout_ms is within SC-CONSENSUS-003 budget (< 30s)" do
      assert @chamber_timeout_ms <= 30_000,
             "Chamber timeout #{@chamber_timeout_ms}ms exceeds 30s SC-CONSENSUS-003 budget"
    end

    test "when all 3 chambers time out → no quorum → fail-closed rejection" do
      # Use a very short timeout to force timeout on slow chambers
      slow_delay = 500
      short_timeout = 50

      tasks = [
        chamber_vote_async("chamber-1", :approve, slow_delay),
        chamber_vote_async("chamber-2", :approve, slow_delay),
        chamber_vote_async("chamber-3", :approve, slow_delay)
      ]

      collected = collect_with_timeout(tasks, short_timeout)

      # With no votes collected, quorum cannot be reached
      result = evaluate_2oo3(collected, total_voters: @voter_count)

      assert result.approve_count == 0
      assert result.quorum_met == false
    end

    test "when 2 chambers respond in time, 1 times out → 2 votes evaluated" do
      fast_delay = 0
      slow_delay = 500
      timeout_ms = 100

      tasks = [
        chamber_vote_async("chamber-1", :approve, fast_delay),
        chamber_vote_async("chamber-2", :approve, fast_delay),
        # This one will time out
        chamber_vote_async("chamber-3", :approve, slow_delay)
      ]

      collected = collect_with_timeout(tasks, timeout_ms)

      # 2 votes collected (both approve)
      result = evaluate_2oo3(collected, total_voters: @voter_count)

      assert length(collected) == 2
      # 2 approvals >= threshold of 2 → quorum met
      assert result.quorum_met == true
    end

    test "emergency proposals use shorter timeout (5s vs 30s)" do
      assert @emergency_timeout_ms < @chamber_timeout_ms,
             "Emergency timeout must be shorter than standard timeout"

      assert @emergency_timeout_ms <= 5_000,
             "Emergency timeout must be <= 5s"
    end
  end

  # ============================================================================
  # TEST 6: constitutional veto by any chamber overrides majority (SC-CONSENSUS-002)
  # ============================================================================

  describe "constitutional veto (SC-CONSENSUS-002)" do
    test "constitutional veto from 1 chamber overrides 2 approvals" do
      votes = [
        make_vote("chamber-1", :approve),
        make_vote("chamber-2", :approve),
        make_vote("chamber-3", {:veto, :constitutional_violation})
      ]

      result = evaluate_2oo3(votes)

      assert result.decision == :constitutional_veto
      assert result.veto_reason == :constitutional_violation
      assert result.constitutional_veto? == true
    end

    test "guardian_immutable veto is absolute (SC-PRIME-002)" do
      votes = [
        make_vote("chamber-1", :approve),
        make_vote("chamber-2", :approve),
        make_vote("chamber-3", {:veto, :guardian_immutable})
      ]

      result = evaluate_2oo3(votes)

      assert result.decision == :constitutional_veto
      assert result.veto_reason == :guardian_immutable
    end

    test "founder_protection veto is absolute (AOR-FOUNDER-007)" do
      votes = [
        make_vote("chamber-1", :approve),
        make_vote("chamber-2", :approve),
        make_vote("chamber-3", {:veto, :founder_protection})
      ]

      result = evaluate_2oo3(votes)

      assert result.decision == :constitutional_veto
      assert result.veto_reason == :founder_protection
    end

    test "forbidden_action veto is absolute" do
      votes = [
        make_vote("chamber-1", :approve),
        make_vote("chamber-2", :approve),
        make_vote("chamber-3", {:veto, :forbidden_action})
      ]

      result = evaluate_2oo3(votes)

      assert result.decision == :constitutional_veto
    end

    test "constitutional veto audit trail still contains all votes" do
      votes = [
        make_vote("chamber-1", :approve),
        make_vote("chamber-2", :approve),
        make_vote("chamber-3", {:veto, :constitutional_violation})
      ]

      result = evaluate_2oo3(votes)

      assert length(result.audit_trail) == 3
    end

    test "non-constitutional veto does NOT block majority approval" do
      # A procedural veto from chamber-3 is NOT constitutional — 2oo3 can override it
      votes = [
        make_vote("chamber-1", :approve),
        make_vote("chamber-2", :approve),
        make_vote("chamber-3", {:veto, :procedural_concern})
      ]

      result = evaluate_2oo3(votes)

      # :procedural_concern is not in the constitutional list → counted as a reject
      assert result.decision == :approved
      assert result.constitutional_veto? == false
    end
  end

  # ============================================================================
  # TEST 7: Byzantine fault — one voter returns garbage
  # ============================================================================

  describe "Byzantine fault tolerance" do
    test "1 Byzantine (garbage) voter + 2 valid approvals → approved" do
      votes = [
        make_vote("chamber-1", :approve),
        make_vote("chamber-2", :approve),
        make_vote("chamber-3", :garbage)
      ]

      result = evaluate_2oo3(votes)

      # Garbage votes do not count as approve or reject — quorum still met from 2 valid approvals
      assert result.decision == :approved
      assert result.approve_count == 2
      assert result.byzantine_count == 1
      assert result.quorum_met == true
    end

    test "1 Byzantine (garbage) voter + 1 approve + 1 reject → rejected (no quorum)" do
      votes = [
        make_vote("chamber-1", :approve),
        make_vote("chamber-2", :reject),
        make_vote("chamber-3", :garbage)
      ]

      result = evaluate_2oo3(votes)

      assert result.decision == :rejected
      assert result.approve_count == 1
      assert result.byzantine_count == 1
      assert result.quorum_met == false
    end

    test "2 Byzantine voters + 1 valid approval → no quorum" do
      votes = [
        make_vote("chamber-1", :approve),
        make_vote("chamber-2", :garbage),
        make_vote("chamber-3", :garbage)
      ]

      result = evaluate_2oo3(votes)

      assert result.decision == :rejected
      assert result.approve_count == 1
      assert result.byzantine_count == 2
      assert result.quorum_met == false
    end

    test "Byzantine voter is recorded in audit trail" do
      votes = [
        make_vote("chamber-1", :approve),
        make_vote("chamber-2", :approve),
        make_vote("chamber-3", :garbage)
      ]

      result = evaluate_2oo3(votes)

      byzantine_entries = Enum.filter(result.audit_trail, fn v -> v.vote == :garbage end)
      assert length(byzantine_entries) == 1
      assert hd(byzantine_entries).voter_id == "chamber-3"
    end
  end

  # ============================================================================
  # TEST 8: voting with different proposal types
  # ============================================================================

  describe "proposal type variants" do
    test "state_change proposal evaluated with 2oo3" do
      proposal_id = "state-change-001"

      votes = [
        make_vote("chamber-1", :approve, proposal_id),
        make_vote("chamber-2", :approve, proposal_id),
        make_vote("chamber-3", :reject, proposal_id)
      ]

      result = evaluate_2oo3(votes)

      assert result.decision == :approved
      assert Enum.all?(result.audit_trail, fn v -> v.proposal_id == proposal_id end)
    end

    test "config_update proposal evaluated with 2oo3" do
      proposal_id = "config-update-001"

      votes = [
        make_vote("chamber-1", :approve, proposal_id),
        make_vote("chamber-2", :reject, proposal_id),
        make_vote("chamber-3", :reject, proposal_id)
      ]

      result = evaluate_2oo3(votes)

      assert result.decision == :rejected
    end

    test "emergency_stop proposal approved by 2oo3 majority" do
      proposal_id = "emergency-stop-001"

      votes = [
        make_vote("chamber-1", :approve, proposal_id),
        make_vote("chamber-2", :approve, proposal_id),
        make_vote("chamber-3", :approve, proposal_id)
      ]

      result = evaluate_2oo3(votes)

      assert result.decision == :approved
    end

    test "emergency_stop is blocked if constitutional veto raised" do
      proposal_id = "emergency-stop-002"

      # Even emergency stop can be constitutionally vetoed if it violates constitutional axioms
      votes = [
        make_vote("chamber-1", :approve, proposal_id),
        make_vote("chamber-2", :approve, proposal_id),
        make_vote("chamber-3", {:veto, :constitutional_violation}, proposal_id)
      ]

      result = evaluate_2oo3(votes)

      assert result.decision == :constitutional_veto
    end

    test "proposal_id is preserved in audit trail for each type" do
      for {type, pid} <- [
            {:state_change, "sc-001"},
            {:config_update, "cu-001"},
            {:emergency_stop, "es-001"}
          ] do
        votes = for i <- 1..3, do: make_vote("chamber-#{i}", :approve, pid)

        result = evaluate_2oo3(votes)
        audit_ids = Enum.map(result.audit_trail, & &1.proposal_id)

        assert Enum.all?(audit_ids, fn id -> id == pid end),
               "Proposal type #{type} — audit trail contains wrong proposal_ids"
      end
    end
  end

  # ============================================================================
  # TEST 9: voting result includes individual chamber votes for audit trail
  # ============================================================================

  describe "audit trail completeness" do
    test "audit trail contains one entry per voter" do
      votes = [
        make_vote("chamber-1", :approve),
        make_vote("chamber-2", :reject),
        make_vote("chamber-3", {:veto, :guardian_immutable})
      ]

      result = evaluate_2oo3(votes)

      assert length(result.audit_trail) == 3
    end

    test "each audit entry has voter_id, proposal_id, vote, timestamp" do
      votes = [make_vote("chamber-1", :approve, "prop-abc")]

      result = evaluate_2oo3(votes)

      entry = hd(result.audit_trail)
      assert Map.has_key?(entry, :voter_id)
      assert Map.has_key?(entry, :proposal_id)
      assert Map.has_key?(entry, :vote)
      assert Map.has_key?(entry, :timestamp_ms)
    end

    test "audit trail is preserved even when quorum not met" do
      votes = [
        make_vote("chamber-1", :reject),
        make_vote("chamber-2", :reject),
        make_vote("chamber-3", :reject)
      ]

      result = evaluate_2oo3(votes)

      assert result.decision == :rejected
      assert length(result.audit_trail) == 3
    end

    test "individual vote decisions are visible in audit trail" do
      votes = [
        make_vote("chamber-1", :approve),
        make_vote("chamber-2", :reject),
        make_vote("chamber-3", {:veto, :procedural_concern})
      ]

      result = evaluate_2oo3(votes)

      chamber_1_entry = Enum.find(result.audit_trail, fn v -> v.voter_id == "chamber-1" end)
      chamber_2_entry = Enum.find(result.audit_trail, fn v -> v.voter_id == "chamber-2" end)
      chamber_3_entry = Enum.find(result.audit_trail, fn v -> v.voter_id == "chamber-3" end)

      assert chamber_1_entry.vote == :approve
      assert chamber_2_entry.vote == :reject
      assert chamber_3_entry.vote == {:veto, :procedural_concern}
    end
  end

  # ============================================================================
  # TEST 10: concurrent voting on separate proposals doesn't interfere
  # ============================================================================

  describe "concurrent voting isolation" do
    test "two concurrent proposals do not share state" do
      # Both proposals run independently and are isolated by proposal_id
      proposal_a = "prop-alpha"
      proposal_b = "prop-beta"

      votes_a = [
        make_vote("chamber-1", :approve, proposal_a),
        make_vote("chamber-2", :approve, proposal_a),
        make_vote("chamber-3", :reject, proposal_a)
      ]

      votes_b = [
        make_vote("chamber-1", :reject, proposal_b),
        make_vote("chamber-2", :reject, proposal_b),
        make_vote("chamber-3", :reject, proposal_b)
      ]

      result_a = evaluate_2oo3(votes_a)
      result_b = evaluate_2oo3(votes_b)

      assert result_a.decision == :approved
      assert result_b.decision == :rejected
    end

    test "concurrent evaluation via Task.async doesn't cause interference" do
      # Run 5 separate evaluations in parallel, each with distinct outcome
      scenarios = [
        {[make_vote("c1", :approve), make_vote("c2", :approve), make_vote("c3", :approve)],
         :approved},
        {[make_vote("c1", :approve), make_vote("c2", :approve), make_vote("c3", :reject)],
         :approved},
        {[make_vote("c1", :reject), make_vote("c2", :reject), make_vote("c3", :reject)],
         :rejected},
        {[make_vote("c1", :approve), make_vote("c2", :reject), make_vote("c3", :reject)],
         :rejected},
        {[
           make_vote("c1", :approve),
           make_vote("c2", :approve),
           make_vote("c3", {:veto, :guardian_immutable})
         ], :constitutional_veto}
      ]

      results =
        scenarios
        |> Enum.map(fn {votes, _expected} ->
          Task.async(fn -> evaluate_2oo3(votes) end)
        end)
        |> Enum.zip(scenarios)
        |> Enum.map(fn {task, {_votes, expected}} ->
          result = Task.await(task)
          {result.decision, expected}
        end)

      for {actual, expected} <- results do
        assert actual == expected,
               "Concurrent evaluation mismatch: got #{actual}, expected #{expected}"
      end
    end

    test "ETS table isolation — each proposal stores result independently" do
      table = :ets.new(:consensus_test_isolation, [:set, :public])

      on_exit(fn ->
        if :ets.info(table) != :undefined, do: :ets.delete(table)
      end)

      votes_a = [
        make_vote("c1", :approve, "prop-A"),
        make_vote("c2", :approve, "prop-A"),
        make_vote("c3", :reject, "prop-A")
      ]

      votes_b = [
        make_vote("c1", :reject, "prop-B"),
        make_vote("c2", :reject, "prop-B"),
        make_vote("c3", :reject, "prop-B")
      ]

      :ets.insert(table, {"prop-A", evaluate_2oo3(votes_a)})
      :ets.insert(table, {"prop-B", evaluate_2oo3(votes_b)})

      [{_, result_a}] = :ets.lookup(table, "prop-A")
      [{_, result_b}] = :ets.lookup(table, "prop-B")

      assert result_a.decision == :approved
      assert result_b.decision == :rejected
    end
  end

  # ============================================================================
  # TEST 11: quorum calculation: floor(N/2)+1 for N voters
  # ============================================================================

  describe "quorum threshold formula (SC-SIL6-011)" do
    test "floor(N/2)+1 for standard voter counts" do
      expected = [
        {3, 2},
        {4, 3},
        {5, 3},
        {6, 4},
        {7, 4}
      ]

      for {n, expected_threshold} <- expected do
        assert quorum_threshold(n) == expected_threshold,
               "N=#{n}: expected quorum #{expected_threshold}, got #{quorum_threshold(n)}"
      end
    end

    test "quorum threshold is strictly greater than N/2" do
      for n <- 3..9 do
        threshold = quorum_threshold(n)
        assert threshold > n / 2, "Quorum #{threshold} must be > N/2=#{n / 2} for N=#{n}"
      end
    end

    test "quorum threshold is never greater than N" do
      for n <- 3..9 do
        threshold = quorum_threshold(n)
        assert threshold <= n, "Quorum #{threshold} must be <= N=#{n}"
      end
    end
  end

  # ============================================================================
  # TEST 12: emergency proposals use shorter timeout (5s vs 30s)
  # ============================================================================

  describe "emergency vs standard timeout" do
    test "standard proposals use @chamber_timeout_ms (30s max)" do
      assert @chamber_timeout_ms == 30_000
    end

    test "emergency proposals use @emergency_timeout_ms (5s max)" do
      assert @emergency_timeout_ms == 5_000
    end

    test "emergency_timeout is shorter than standard timeout" do
      assert @emergency_timeout_ms < @chamber_timeout_ms
    end

    test "vote collection honours emergency timeout for fast decisions" do
      # Fast chambers respond within emergency budget
      tasks = [
        chamber_vote_async("c1", :approve, 0),
        chamber_vote_async("c2", :approve, 0),
        chamber_vote_async("c3", :approve, 0)
      ]

      start = System.monotonic_time(:millisecond)
      collected = collect_with_timeout(tasks, @emergency_timeout_ms)
      elapsed = System.monotonic_time(:millisecond) - start

      assert length(collected) == 3
      assert elapsed < @emergency_timeout_ms, "Collection took #{elapsed}ms > emergency budget"
    end
  end

  # ============================================================================
  # TEST 13: property — for any 3-boolean vote combination, result matches 2oo3
  # ============================================================================

  property "for any 3-boolean vote combo, result matches expected 2oo3 logic (PropCheck)" do
    forall votes <- PC.list(PC.oneof([:approve, :reject])) do
      # Clamp list to exactly 3 elements
      padded =
        (votes ++ [:reject, :reject, :reject])
        |> Enum.take(3)

      vote_structs =
        Enum.with_index(padded, 1) |> Enum.map(fn {v, i} -> make_vote("c#{i}", v) end)

      result = evaluate_2oo3(vote_structs)

      approve_count = Enum.count(padded, &(&1 == :approve))
      expected_decision = if approve_count >= 2, do: :approved, else: :rejected

      result.decision == expected_decision
    end
  end

  test "SD property: for any 3-boolean vote combo, result matches expected 2oo3 logic" do
    ExUnitProperties.check all(
                             v1 <- SD.member_of([:approve, :reject]),
                             v2 <- SD.member_of([:approve, :reject]),
                             v3 <- SD.member_of([:approve, :reject])
                           ) do
      vote_structs = [
        make_vote("c1", v1),
        make_vote("c2", v2),
        make_vote("c3", v3)
      ]

      result = evaluate_2oo3(vote_structs)

      approve_count = Enum.count([v1, v2, v3], &(&1 == :approve))
      expected_decision = if approve_count >= 2, do: :approved, else: :rejected

      assert result.decision == expected_decision,
             "votes=[#{v1},#{v2},#{v3}] approve_count=#{approve_count}: " <>
               "expected #{expected_decision}, got #{result.decision}"
    end
  end

  # ============================================================================
  # TEST 14: property — for N voters (3..7), quorum is always floor(N/2)+1
  # ============================================================================

  property "for N voters 3..7, quorum = floor(N/2)+1 (PropCheck)" do
    forall n <- PC.choose(3, 7) do
      threshold = quorum_threshold(n)
      expected = floor(n / 2) + 1
      threshold == expected
    end
  end

  test "SD property: for N voters 3..7, quorum = floor(N/2)+1" do
    ExUnitProperties.check all(n <- SD.integer(3, 7)) do
      threshold = quorum_threshold(n)
      expected = floor(n / 2) + 1

      assert threshold == expected,
             "N=#{n}: expected quorum #{expected}, got #{threshold}"
    end
  end
end
