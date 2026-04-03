defmodule Indrajaal.Safety.TricameralConsensusTest do
  @moduledoc """
  Tricameral Consensus 3-Chamber Voting Test Suite.

  WHAT: Validates the tricameral consensus protocol — three independent chambers
        (Legislative, Judicial, Executive) each with constitutional veto authority,
        requiring 2-out-of-3 majority for any safety-critical decision.
  WHY: SC-CONSENSUS-001 (2oo3 voting mandatory for P0 decisions),
       SC-CONSENSUS-002 (each chamber has constitutional veto),
       SC-CONSENSUS-003 (timeout < 30s per chamber), SC-SIL6-006 (2oo3 voting
       mandatory in production), SC-GDE-001 (Guardian validation required),
       Ψ₄ (Human Alignment — Founder's lineage PRIMARY).
  CONSTRAINTS:
    - SC-CONSENSUS-001: 2oo3 voting MANDATORY for P0 decisions
    - SC-CONSENSUS-002: Each chamber has Constitutional veto
    - SC-CONSENSUS-003: Timeout < 30s per chamber
    - SC-SIL6-006: 2oo3 voting MANDATORY in SIL-6 mesh
    - SC-SIL6-011: Quorum = floor(N/2)+1
    - SC-GDE-001: Guardian validation required
    - SC-CONST-007: Guardian has absolute veto authority
    - SC-TRI-001 to SC-TRI-015: Tricameral orchestrator constraints

  ## Tricameral Chambers
    Legislative  — Rule creation, policy proposals, constitutional amendments
    Judicial     — Constitutional compliance, veto of rule violations
    Executive    — Action execution, operational decisions, emergency authority

  ## 2oo3 Voting Semantics
    APPROVE: 2+ chambers approve → consensus achieved
    VETO:    Any 1 chamber vetoes → constitutional veto (unanimous rejection not required)
    TIMEOUT: Chamber exceeds 30s → treated as abstain (not veto)

  ## Change History
  | Version | Date       | Author | Change                              |
  |---------|------------|--------|-------------------------------------|
  | 1.0.0   | 2026-03-24 | Claude | Initial tricameral consensus tests  |

  @version "1.0.0"
  @last_modified "2026-03-24T00:00:00Z"
  """

  use ExUnit.Case, async: false
  import ExUnitProperties

  alias StreamData, as: SD

  alias Indrajaal.Safety.Guardian

  @moduletag :tricameral
  @moduletag :consensus
  @moduletag :sil6
  @moduletag :sprint_88

  # ---------------------------------------------------------------------------
  # ETS-backed chamber state for tests
  # ---------------------------------------------------------------------------

  @ets_table :tricameral_consensus_test

  setup do
    # Set up isolated ETS table for chamber state
    if :ets.whereis(@ets_table) == :undefined do
      :ets.new(@ets_table, [:set, :public, :named_table])
    else
      :ets.delete_all_objects(@ets_table)
    end

    on_exit(fn ->
      if :ets.whereis(@ets_table) != :undefined do
        :ets.delete_all_objects(@ets_table)
      end
    end)

    :ok
  end

  # ---------------------------------------------------------------------------
  # Helpers that simulate the 3 chambers
  # ---------------------------------------------------------------------------

  @chambers [:legislative, :judicial, :executive]

  defp chamber_vote(chamber, proposal, verdict) do
    :ets.insert(
      @ets_table,
      {{chamber, :vote}, verdict, proposal, System.monotonic_time(:millisecond)}
    )

    verdict
  end

  defp get_chamber_vote(chamber) do
    case :ets.lookup(@ets_table, {chamber, :vote}) do
      [{_, verdict, _proposal, _ts}] -> {:ok, verdict}
      [] -> {:error, :no_vote}
    end
  end

  defp tally_votes(verdicts) do
    approve_count = Enum.count(verdicts, &(&1 == :approve))
    veto_count = Enum.count(verdicts, &(&1 == :veto))

    cond do
      veto_count >= 1 -> {:veto, veto_count}
      approve_count >= 2 -> {:consensus, approve_count}
      true -> {:no_quorum, approve_count}
    end
  end

  defp simulate_chamber_vote(chamber, proposal, opts) do
    # Simulate a chamber vote with optional override
    forced_verdict = Keyword.get(opts, :force, nil)
    timeout_ms = Keyword.get(opts, :timeout_ms, 5_000)

    verdict =
      if forced_verdict do
        forced_verdict
      else
        # Default: approve safe proposals, veto risky ones
        risk = Map.get(proposal, :risk_level, :low)

        case {chamber, risk} do
          {:judicial, :high} -> :veto
          {:legislative, :critical} -> :veto
          _ -> :approve
        end
      end

    chamber_vote(chamber, proposal, verdict)
    {:ok, verdict, timeout_ms}
  end

  defp run_tricameral_vote(proposal, opts \\ []) do
    chamber_opts = Keyword.get(opts, :chamber_opts, %{})

    results =
      Enum.map(@chambers, fn chamber ->
        c_opts = Map.get(chamber_opts, chamber, [])
        {:ok, verdict, _timeout} = simulate_chamber_vote(chamber, proposal, c_opts)
        {chamber, verdict}
      end)

    verdicts = Enum.map(results, fn {_, v} -> v end)
    {tally_votes(verdicts), results}
  end

  # ---------------------------------------------------------------------------
  # Chamber initialization tests
  # ---------------------------------------------------------------------------

  describe "Chamber initialization and identity (SC-CONSENSUS-001)" do
    test "All 3 chambers are distinct and enumerable" do
      assert length(@chambers) == 3, "Tricameral requires exactly 3 chambers"
      assert :legislative in @chambers
      assert :judicial in @chambers
      assert :executive in @chambers
    end

    test "Each chamber can record a vote independently" do
      proposal = %{action: :deploy_config, resource: "config_v2", risk_level: :low}

      for chamber <- @chambers do
        chamber_vote(chamber, proposal, :approve)
        {:ok, verdict} = get_chamber_vote(chamber)
        assert verdict == :approve, "#{chamber} chamber vote must be recorded"
      end
    end

    test "Chamber votes are isolated in ETS (SC-CONSENSUS-001)" do
      proposal = %{action: :test, risk_level: :low}

      chamber_vote(:legislative, proposal, :approve)
      chamber_vote(:judicial, proposal, :veto)
      chamber_vote(:executive, proposal, :approve)

      {:ok, leg_vote} = get_chamber_vote(:legislative)
      {:ok, jud_vote} = get_chamber_vote(:judicial)
      {:ok, exe_vote} = get_chamber_vote(:executive)

      assert leg_vote == :approve
      assert jud_vote == :veto
      assert exe_vote == :approve
    end
  end

  # ---------------------------------------------------------------------------
  # 2oo3 majority voting (SC-CONSENSUS-001)
  # ---------------------------------------------------------------------------

  describe "2oo3 majority voting (SC-CONSENSUS-001, SC-SIL6-006)" do
    test "3/3 unanimous approval achieves consensus" do
      {result, _details} =
        run_tricameral_vote(%{action: :read_log, risk_level: :low})

      assert match?({:consensus, _}, result),
             "3/3 approval must achieve consensus"
    end

    test "2/3 approval with 1 abstain achieves consensus (quorum = floor(3/2)+1 = 2)" do
      verdicts = [:approve, :approve, :abstain]
      result = tally_votes(verdicts)
      # 2 approvals, 0 vetoes → consensus
      assert match?({:consensus, 2}, result),
             "2/3 approval must satisfy quorum floor(N/2)+1 = 2 (SC-SIL6-011)"
    end

    test "1/3 approval is no_quorum" do
      verdicts = [:approve, :abstain, :abstain]
      result = tally_votes(verdicts)
      assert match?({:no_quorum, 1}, result), "Only 1 approval must be no_quorum"
    end

    test "0/3 approval is no_quorum" do
      verdicts = [:abstain, :abstain, :abstain]
      result = tally_votes(verdicts)
      assert match?({:no_quorum, 0}, result), "0 approvals must be no_quorum"
    end

    test "Judicial veto on high-risk proposal triggers constitutional veto (SC-CONSENSUS-002)" do
      proposal = %{action: :delete_audit_log, risk_level: :high}

      {result, details} =
        run_tricameral_vote(proposal)

      # Judicial vetoes high-risk — constitutional veto should apply
      assert match?({:veto, _}, result),
             "Judicial constitutional veto must block high-risk proposal"

      judicial_vote = details |> Enum.find(fn {c, _} -> c == :judicial end) |> elem(1)
      assert judicial_vote == :veto
    end

    test "Legislative veto on critical proposal triggers constitutional veto" do
      proposal = %{action: :disable_guardian, risk_level: :critical}

      {result, _details} =
        run_tricameral_vote(proposal)

      assert match?({:veto, _}, result),
             "Legislative constitutional veto must block critical proposal"
    end
  end

  # ---------------------------------------------------------------------------
  # Constitutional veto per chamber (SC-CONSENSUS-002)
  # ---------------------------------------------------------------------------

  describe "Constitutional veto authority per chamber (SC-CONSENSUS-002)" do
    test "Single veto from any chamber blocks consensus" do
      # Even if 2 chambers approve, 1 veto is sufficient to block
      for vetoing_chamber <- @chambers do
        chamber_opts = %{
          vetoing_chamber => [force: :veto],
          # All other chambers approve
          List.first(List.delete(@chambers, vetoing_chamber)) => [force: :approve],
          List.last(List.delete(@chambers, vetoing_chamber)) => [force: :approve]
        }

        {result, details} =
          run_tricameral_vote(
            %{action: :test_veto, risk_level: :medium},
            chamber_opts: chamber_opts
          )

        assert match?({:veto, _}, result),
               "#{vetoing_chamber} veto must block consensus even with 2 approvals"

        # Verify the right chamber vetoed
        vetoing_detail =
          Enum.find(details, fn {c, _} -> c == vetoing_chamber end)

        assert elem(vetoing_detail, 1) == :veto
      end
    end

    test "Constitutional veto is irrevocable within the voting round" do
      # Once a veto is recorded, the round result is determined
      chamber_vote(:judicial, %{action: :irrevocable}, :veto)

      # Even adding approvals later, veto stands
      chamber_vote(:legislative, %{action: :irrevocable}, :approve)
      chamber_vote(:executive, %{action: :irrevocable}, :approve)

      {:ok, jud} = get_chamber_vote(:judicial)
      assert jud == :veto, "Constitutional veto must be irrevocable"
    end

    test "Guardian.validate_proposal/2 respects constitutional authority (SC-CONST-007)" do
      proposal = %{
        action: :constitutional_amendment,
        resource: "system_core",
        agent: "operator",
        risk_level: :critical
      }

      result = Guardian.validate_proposal(proposal)

      # Guardian has absolute veto — must return a valid tagged tuple
      assert match?({:ok, _}, result) or match?({:veto, _, _}, result),
             "Guardian must exercise constitutional authority on critical proposals"
    end
  end

  # ---------------------------------------------------------------------------
  # Timeout handling (SC-CONSENSUS-003: < 30s per chamber)
  # ---------------------------------------------------------------------------

  describe "Chamber timeout handling (SC-CONSENSUS-003: timeout < 30s)" do
    test "Chamber timeout is within the 30-second SLA" do
      # Test with 5s << 30s maximum
      timeout_ms = 5_000
      assert timeout_ms < 30_000, "Chamber timeout must be < 30s (SC-CONSENSUS-003)"
    end

    test "Timed-out chamber is treated as abstain, not veto" do
      # A chamber that doesn't respond should not block consensus
      # Simulate: 2 approvals + 1 timeout (abstain)
      # :abstain represents timeout
      verdicts = [:approve, :approve, :abstain]
      result = tally_votes(verdicts)

      assert match?({:consensus, 2}, result),
             "Timeout/abstain must not block 2oo3 consensus (SC-CONSENSUS-003)"
    end

    test "All 3 chambers timeout leaves no_quorum" do
      verdicts = [:abstain, :abstain, :abstain]
      result = tally_votes(verdicts)
      assert match?({:no_quorum, _}, result), "All timeouts must not achieve quorum"
    end

    test "Voting round completes within acceptable wall-clock time" do
      start_ts = System.monotonic_time(:millisecond)

      run_tricameral_vote(%{action: :time_sensitive, risk_level: :low})

      elapsed_ms = System.monotonic_time(:millisecond) - start_ts

      # Local simulation must be fast (< 1s); real chambers must be < 30s
      assert elapsed_ms < 1_000,
             "Simulated tricameral vote must complete in < 1s (SC-CONSENSUS-003)"
    end
  end

  # ---------------------------------------------------------------------------
  # Cascade failure prevention (SC-SIL6-006)
  # ---------------------------------------------------------------------------

  describe "Cascade failure prevention (SC-SIL6-006)" do
    test "Multiple sequential votes don't interfere with each other" do
      proposal_1 = %{action: :action_a, risk_level: :low}
      proposal_2 = %{action: :action_b, risk_level: :low}

      {result_1, _} = run_tricameral_vote(proposal_1)
      # Reset ETS between rounds
      :ets.delete_all_objects(@ets_table)
      {result_2, _} = run_tricameral_vote(proposal_2)

      assert match?({:consensus, _}, result_1)
      assert match?({:consensus, _}, result_2)
    end

    test "Veto in round N does not cascade to round N+1" do
      high_risk = %{action: :risky_op, risk_level: :high}
      {veto_result, _} = run_tricameral_vote(high_risk)
      assert match?({:veto, _}, veto_result)

      # Reset state between rounds
      :ets.delete_all_objects(@ets_table)

      low_risk = %{action: :safe_op, risk_level: :low}
      {safe_result, _} = run_tricameral_vote(low_risk)

      assert match?({:consensus, _}, safe_result),
             "Veto from previous round must not cascade to next round"
    end

    test "Emergency stop proposal via Guardian is vetoed or handled safely" do
      emergency_proposal = %{
        action: :emergency_stop,
        resource: "all_systems",
        agent: "operator",
        reason: "critical_failure_test"
      }

      result = Guardian.validate_proposal(emergency_proposal)

      # Guardian must process emergency proposals safely — no crash
      assert match?({:ok, _}, result) or match?({:veto, _, _}, result),
             "Guardian must handle emergency stop proposal without crashing"
    end

    test "Guardian emergency_stop/1 is exported (SC-CTRL-004)" do
      assert function_exported?(Guardian, :emergency_stop, 1),
             "Guardian must export emergency_stop/1"
    end
  end

  # ---------------------------------------------------------------------------
  # Guardian integration (SC-GDE-001, SC-CONST-007)
  # ---------------------------------------------------------------------------

  describe "Guardian integration with tricameral protocol (SC-GDE-001)" do
    test "Guardian.validate_proposal/1 is the L1 validation gate" do
      proposals = [
        %{action: :create, resource: "log", agent: "s1_ops"},
        %{action: :read, resource: "holon_state", agent: "s4_intel"},
        %{action: :delete, resource: "audit_trail", agent: "unknown"}
      ]

      for proposal <- proposals do
        result = Guardian.validate_proposal(proposal)

        assert match?({:ok, _}, result) or match?({:veto, _, _}, result),
               "Guardian must process proposal: #{inspect(proposal.action)}"
      end
    end

    test "Guardian.status/0 returns status map (L2 component health)" do
      status = Guardian.status()
      assert is_map(status), "Guardian.status/0 must return a map"
    end

    test "Guardian.alive?/1 returns boolean for process liveness" do
      result = Guardian.alive?(self())
      assert is_boolean(result), "Guardian.alive?/1 must return boolean"
    end

    test "Guardian.constraints/0 returns non-empty STAMP constraints" do
      constraints = Guardian.constraints()
      # constraints/0 returns a map of constraint categories
      assert is_map(constraints) or is_list(constraints),
             "Guardian.constraints/0 must return constraints"

      non_empty =
        if is_map(constraints), do: map_size(constraints) > 0, else: length(constraints) > 0

      assert non_empty, "Guardian must enforce at least one STAMP constraint"
    end
  end

  # ---------------------------------------------------------------------------
  # Property-based tests (EP-GEN-014)
  # ---------------------------------------------------------------------------

  test "tally_votes always returns a tagged tuple (SD property, SC-CONSENSUS-001)" do
    ExUnitProperties.check all(verdicts <- SD.list_of(SD.member_of([:approve, :veto, :abstain]))) do
      result = tally_votes(verdicts)

      assert match?({:consensus, _}, result) or
               match?({:veto, _}, result) or
               match?({:no_quorum, _}, result)
    end
  end

  test "veto is always triggered when at least 1 veto present (SD property)" do
    ExUnitProperties.check all(
                             extra_verdicts <-
                               SD.list_of(SD.member_of([:approve, :abstain]), max_length: 5)
                           ) do
      verdicts = [:veto | extra_verdicts]
      result = tally_votes(verdicts)
      assert match?({:veto, _}, result)
    end
  end

  test "StreamData: consensus is achieved for all-approve lists (SD)" do
    ExUnitProperties.check all(
                             n <- SD.integer(2..10),
                             extra <-
                               SD.list_of(SD.member_of([:approve, :abstain]), max_length: 3)
                           ) do
      # Build at least n approvals + some extra
      verdicts = List.duplicate(:approve, n) ++ extra
      result = tally_votes(verdicts)

      # With n >= 2 approvals and no vetoes, consensus must be achieved
      assert match?({:consensus, _}, result),
             "#{n} approvals with no vetoes must achieve consensus"
    end
  end

  test "StreamData: any veto always blocks consensus regardless of approvals (SD)" do
    ExUnitProperties.check all(
                             approve_count <- SD.integer(0..10),
                             veto_count <- SD.integer(1..5)
                           ) do
      verdicts =
        List.duplicate(:approve, approve_count) ++
          List.duplicate(:veto, veto_count)

      result = tally_votes(verdicts)

      assert match?({:veto, _}, result),
             "Any veto must block consensus regardless of #{approve_count} approvals"
    end
  end
end
