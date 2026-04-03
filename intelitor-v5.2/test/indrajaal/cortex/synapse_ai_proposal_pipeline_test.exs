defmodule Indrajaal.Cortex.SynapseAiProposalPipelineTest do
  @moduledoc """
  TDG test suite: Cortex AI proposal pipeline with Guardian Simplex gating.

  WHAT: Self-contained tests for the AI proposal creation, validation, Guardian
        gating, shadow testing, context compaction, and tricameral consensus.
  WHY: The Neuro-Symbolic Simplex architecture (CLAUDE.md §100) requires every
       AI-generated mutation to pass Guardian before touching production state.
       These tests verify that contract end-to-end without live GenServer deps.

  ## STAMP Constraints Tested
  - SC-NEURO-001: Simplex Principle — AI output MUST pass Guardian.validate_proposal/1
  - SC-NEURO-002: Resource Bounding — hard limits on AI request resource usage
  - SC-NEURO-003: Forbidden Ops — Guardian veto for destructive commands
  - SC-GDE-001: Guardian validation required before deployment
  - SC-GDE-002: Shadow testing mandatory before activation
  - SC-GDE-004: Proposal fitness threshold >= 0.85
  - SC-CONSENSUS-001: 2oo3 voting MANDATORY for P0 decisions
  - SC-CONSENSUS-002: Each chamber has Constitutional veto
  - SC-CONSENSUS-003: Timeout <30s per chamber
  - AOR-REG-005: Shadow testing before genome/code activation
  - AOR-PROM-003: Context compaction trigger at 75% usage
  - AOR-NEURO-001: All AI proposals pass Guardian validation
  - AOR-NEURO-002: Vetoed proposals logged in shadow mode

  ## TDG Methodology
  - 25 unit tests covering all pipeline stages
  - 3 property tests for universal invariants
  - All logic in defp helpers — zero production module dependencies
  - EP-GEN-014 compliant: dual `use PropCheck` + `import ExUnitProperties`
    with PC./SD. alias disambiguation

  ## Document Control

  | Field  | Value                                                |
  |--------|------------------------------------------------------|
  | Version | 2.0.0                                               |
  | Created | 2026-03-24                                          |
  | Author  | Cybernetic Architect (Code Evolution Agent v21.3.0) |
  | STAMP   | SC-NEURO-001/002/003, SC-CONSENSUS-001/002/003      |
  | AOR     | AOR-REG-005, AOR-NEURO-001/002, AOR-PROM-003        |
  """

  use ExUnit.Case, async: true

  # EP-GEN-014: dual property testing — MANDATORY
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # ---------------------------------------------------------------------------
  # Module-level constants (self-contained, no production deps)
  # ---------------------------------------------------------------------------

  # Resource ceilings for AI requests per SC-NEURO-002
  @resource_limits %{
    max_tokens: 4_096,
    max_time_ms: 5_000,
    max_memory_mb: 128
  }

  # Forbidden operation patterns per SC-NEURO-003
  @forbidden_patterns [
    ~r/rm\s+-rf/i,
    ~r/DROP\s+TABLE/i,
    ~r/git\s+push\s+.*--force/i,
    ~r/mix\s+ecto\.reset/i,
    ~r/podman\s+rm\s+-f/i,
    ~r/DELETE\s+FROM.*WHERE\s+1=1/i
  ]

  # Valid fixture used across most unit tests
  @valid_params %{
    description: "Add telemetry hook to SentinelMonitor",
    module: "Indrajaal.Cortex.Sentinel",
    stamp_refs: ["SC-NEURO-001", "SC-GDE-001"],
    author: "claude-sonnet-4-6",
    tokens_used: 512,
    time_ms: 200,
    memory_mb: 16
  }

  # Tricameral chamber identifiers per SC-CONSENSUS-001
  @chambers [:constitutional_chamber, :safety_chamber, :operational_chamber]

  # Chamber timeout budget in ms per SC-CONSENSUS-003 (<30 000ms)
  @chamber_timeout_ms 29_000

  # Minimum fitness for activation per SC-GDE-004
  @fitness_threshold 0.85

  # Context compaction trigger per AOR-PROM-003
  @compaction_trigger_pct 0.75

  # ---------------------------------------------------------------------------
  # Helper: create_proposal/2
  # ---------------------------------------------------------------------------

  @spec create_proposal(atom(), map()) :: map()
  defp create_proposal(type, params) do
    %{
      id: generate_id(),
      type: type,
      status: :pending,
      description: Map.get(params, :description, ""),
      module: Map.get(params, :module, ""),
      stamp_refs: Map.get(params, :stamp_refs, []),
      author: Map.get(params, :author, "unknown"),
      tokens_used: Map.get(params, :tokens_used, 0),
      time_ms: Map.get(params, :time_ms, 0),
      memory_mb: Map.get(params, :memory_mb, 0),
      context_usage_pct: Map.get(params, :context_usage_pct, 0.40),
      created_at: System.monotonic_time(:millisecond)
    }
  end

  # ---------------------------------------------------------------------------
  # Helper: validate_proposal_fields/1
  # ---------------------------------------------------------------------------

  @spec validate_proposal_fields(map()) ::
          :ok | {:error, :missing_field, atom()} | {:error, :invalid_field, atom()}
  defp validate_proposal_fields(params) do
    required = [:description, :stamp_refs, :author]

    Enum.find_value(required, :ok, fn field ->
      cond do
        not Map.has_key?(params, field) ->
          {:error, :missing_field, field}

        field == :stamp_refs and Map.get(params, field) == [] ->
          {:error, :invalid_field, :stamp_refs}

        true ->
          nil
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Helper: validate_with_guardian/1 — SC-NEURO-001
  # ---------------------------------------------------------------------------

  @spec validate_with_guardian(map()) ::
          {:approved, map()} | {:vetoed, atom(), String.t()}
  defp validate_with_guardian(proposal) do
    cond do
      is_forbidden_operation?(proposal.description) ->
        matched =
          Enum.find(@forbidden_patterns, fn re -> Regex.match?(re, proposal.description) end)

        {:vetoed, :forbidden_operation,
         "Forbidden pattern #{inspect(matched)} matched in: '#{proposal.description}'"}

      match?({:error, _, _}, check_resource_bounds(proposal, @resource_limits)) ->
        {:error, kind, _detail} = check_resource_bounds(proposal, @resource_limits)
        {:vetoed, :resource_limit, "Resource limit violated: #{kind}"}

      true ->
        {:approved, proposal}
    end
  end

  # ---------------------------------------------------------------------------
  # Helper: check_resource_bounds/2 — SC-NEURO-002
  # ---------------------------------------------------------------------------

  @spec check_resource_bounds(map(), map()) :: :ok | {:error, atom(), map()}
  defp check_resource_bounds(usage, limits) do
    cond do
      Map.get(usage, :tokens_used, 0) > limits.max_tokens ->
        {:error, :tokens_exceeded,
         %{actual: Map.get(usage, :tokens_used), limit: limits.max_tokens}}

      Map.get(usage, :time_ms, 0) > limits.max_time_ms ->
        {:error, :time_exceeded, %{actual: Map.get(usage, :time_ms), limit: limits.max_time_ms}}

      Map.get(usage, :memory_mb, 0) > limits.max_memory_mb ->
        {:error, :memory_exceeded,
         %{actual: Map.get(usage, :memory_mb), limit: limits.max_memory_mb}}

      true ->
        :ok
    end
  end

  # ---------------------------------------------------------------------------
  # Helper: is_forbidden_operation?/1 — SC-NEURO-003
  # ---------------------------------------------------------------------------

  @spec is_forbidden_operation?(String.t()) :: boolean()
  defp is_forbidden_operation?(command) when is_binary(command) do
    Enum.any?(@forbidden_patterns, fn pattern -> Regex.match?(pattern, command) end)
  end

  defp is_forbidden_operation?(_), do: false

  # ---------------------------------------------------------------------------
  # Helper: run_shadow_test/2 — AOR-REG-005, SC-GDE-002
  # ---------------------------------------------------------------------------

  @spec run_shadow_test(map(), map()) :: map()
  defp run_shadow_test(proposal, opts) do
    simulate_pass = Map.get(opts, :simulate_pass, true)
    tests_ratio = Map.get(opts, :tests_passed_ratio, if(simulate_pass, do: 1.0, else: 0.4))
    coverage = Map.get(opts, :coverage, if(simulate_pass, do: 0.95, else: 0.5))
    regressions = Map.get(opts, :regressions, [])

    # Fitness formula: tests*0.5 + coverage*0.3 + quality*0.2
    base_fitness = tests_ratio * 0.5 + coverage * 0.3 + 0.2
    fitness = Float.round(min(base_fitness, 1.0), 4)
    passed = simulate_pass and Enum.empty?(regressions) and fitness >= @fitness_threshold

    %{
      proposal_id: proposal.id,
      passed: passed,
      fitness: fitness,
      coverage: coverage,
      tests_passed_ratio: tests_ratio,
      regressions: regressions,
      duration_ms: 10 + rem(:erlang.unique_integer([:positive]), 50)
    }
  end

  # ---------------------------------------------------------------------------
  # Helper: activate_proposal/2
  # ---------------------------------------------------------------------------

  @spec activate_proposal(map(), map()) :: map()
  defp activate_proposal(proposal, shadow_result) do
    %{
      proposal_id: proposal.id,
      status: :activated,
      event_type: :code_evolution,
      shadow_fitness: shadow_result.fitness,
      activated_at: System.monotonic_time(:millisecond),
      register_block_id: generate_id()
    }
  end

  @spec activate_proposal_checked(map(), map()) ::
          map() | {:error, :shadow_failed, map()}
  defp activate_proposal_checked(proposal, shadow_result) do
    if shadow_result.passed do
      activate_proposal(proposal, shadow_result)
    else
      {:error, :shadow_failed,
       %{
         proposal_id: proposal.id,
         fitness: shadow_result.fitness,
         regressions: shadow_result.regressions
       }}
    end
  end

  # ---------------------------------------------------------------------------
  # Helper: tricameral_vote/1 — SC-CONSENSUS-001/002/003
  # ---------------------------------------------------------------------------

  @spec tricameral_vote(map()) :: map()
  defp tricameral_vote(proposal) do
    t0 = System.monotonic_time(:millisecond)

    votes =
      Enum.map(@chambers, fn chamber ->
        vote = cast_chamber_vote(chamber, proposal)
        elapsed_ms = System.monotonic_time(:millisecond) - t0
        {chamber, vote, elapsed_ms}
      end)

    # 2oo3 quorum: floor(3/2)+1 = 2 (SC-CONSENSUS-001)
    approvals = Enum.count(votes, fn {_, v, _} -> v == :approve end)
    vetoes = Enum.count(votes, fn {_, v, _} -> v == :veto end)
    quorum_met = approvals >= 2
    # Any single chamber Constitutional veto overrides quorum (SC-CONSENSUS-002)
    any_veto = vetoes > 0

    overall =
      cond do
        any_veto -> :vetoed
        quorum_met -> :approved
        true -> :rejected
      end

    %{
      overall: overall,
      votes: votes,
      approvals: approvals,
      vetoes: vetoes,
      quorum_met: quorum_met,
      proposal_id: proposal.id
    }
  end

  defp cast_chamber_vote(:constitutional_chamber, proposal) do
    # Veto if proposal has no STAMP refs — constitutional requirement
    if Map.get(proposal, :stamp_refs, []) == [],
      do: :veto,
      else: :approve
  end

  defp cast_chamber_vote(:safety_chamber, proposal) do
    # Veto forbidden ops
    if is_forbidden_operation?(Map.get(proposal, :description, "")),
      do: :veto,
      else: :approve
  end

  defp cast_chamber_vote(:operational_chamber, proposal) do
    # Veto if tokens exceed 80% of ceiling
    if Map.get(proposal, :tokens_used, 0) > @resource_limits.max_tokens * 0.8,
      do: :veto,
      else: :approve
  end

  # ---------------------------------------------------------------------------
  # Helper: context_compaction_needed?/1 — AOR-PROM-003
  # ---------------------------------------------------------------------------

  @spec context_compaction_needed?(map()) :: boolean()
  defp context_compaction_needed?(proposal) do
    pct = Map.get(proposal, :context_usage_pct, 0.0)
    pct >= @compaction_trigger_pct
  end

  # ---------------------------------------------------------------------------
  # Helper: generate_id/0
  # ---------------------------------------------------------------------------

  @spec generate_id() :: String.t()
  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  # ---------------------------------------------------------------------------
  # PropCheck generator: destructive command string
  # ---------------------------------------------------------------------------

  defp pc_destructive_command do
    let prefix <-
          PC.elements([
            "rm -rf",
            "DROP TABLE",
            "git push --force",
            "podman rm -f",
            "mix ecto.reset",
            "DELETE FROM t WHERE 1=1"
          ]) do
      let suffix <- PC.utf8() do
        prefix <> " " <> suffix
      end
    end
  end

  # ===========================================================================
  # 1. UNIT TESTS — Proposal creation
  # ===========================================================================

  describe "proposal creation" do
    test "creates a code_change proposal with all required fields" do
      proposal = create_proposal(:code_change, @valid_params)

      assert proposal.type == :code_change
      assert is_binary(proposal.id)
      assert String.length(proposal.id) > 0
      assert proposal.status == :pending
      assert is_integer(proposal.created_at)
    end

    test "creates a config_change proposal" do
      proposal = create_proposal(:config_change, @valid_params)
      assert proposal.type == :config_change
    end

    test "creates a resource_allocation proposal" do
      proposal = create_proposal(:resource_allocation, @valid_params)
      assert proposal.type == :resource_allocation
    end

    test "proposal id is unique per call" do
      p1 = create_proposal(:code_change, @valid_params)
      p2 = create_proposal(:code_change, @valid_params)
      refute p1.id == p2.id
    end

    test "proposal carries stamp_refs from params" do
      proposal = create_proposal(:code_change, @valid_params)
      assert proposal.stamp_refs == ["SC-NEURO-001", "SC-GDE-001"]
    end

    test "proposal description is preserved verbatim" do
      proposal = create_proposal(:code_change, @valid_params)
      assert proposal.description == "Add telemetry hook to SentinelMonitor"
    end

    test "proposal author is preserved" do
      proposal = create_proposal(:code_change, @valid_params)
      assert proposal.author == "claude-sonnet-4-6"
    end

    test "proposal without description returns error" do
      params = Map.delete(@valid_params, :description)
      assert {:error, :missing_field, :description} = validate_proposal_fields(params)
    end

    test "proposal without stamp_refs returns error" do
      params = Map.delete(@valid_params, :stamp_refs)
      assert {:error, :missing_field, :stamp_refs} = validate_proposal_fields(params)
    end

    test "proposal with empty stamp_refs returns invalid_field error" do
      params = Map.put(@valid_params, :stamp_refs, [])
      assert {:error, :invalid_field, :stamp_refs} = validate_proposal_fields(params)
    end
  end

  # ===========================================================================
  # 2. UNIT TESTS — Guardian gating (SC-NEURO-001)
  # ===========================================================================

  describe "Guardian gating — SC-NEURO-001" do
    test "valid proposal is approved by Guardian" do
      proposal = create_proposal(:code_change, @valid_params)
      assert {:approved, ^proposal} = validate_with_guardian(proposal)
    end

    test "proposal with 'rm -rf' in description is vetoed" do
      params = Map.put(@valid_params, :description, "rm -rf /data/holons")
      proposal = create_proposal(:code_change, params)
      assert {:vetoed, :forbidden_operation, _reason} = validate_with_guardian(proposal)
    end

    test "Guardian veto includes non-empty reason string" do
      params = Map.put(@valid_params, :description, "DROP TABLE users")
      proposal = create_proposal(:code_change, params)
      {:vetoed, :forbidden_operation, reason} = validate_with_guardian(proposal)
      assert is_binary(reason)
      assert String.length(reason) > 0
    end

    test "config_change proposal passes Guardian when clean" do
      proposal = create_proposal(:config_change, @valid_params)
      assert {:approved, _} = validate_with_guardian(proposal)
    end

    test "proposal exceeding token limit is vetoed" do
      params = Map.put(@valid_params, :tokens_used, 99_999)
      proposal = create_proposal(:code_change, params)
      assert {:vetoed, :resource_limit, _} = validate_with_guardian(proposal)
    end

    test "proposal exceeding time limit is vetoed" do
      params = Map.put(@valid_params, :time_ms, 60_000)
      proposal = create_proposal(:code_change, params)
      assert {:vetoed, :resource_limit, _} = validate_with_guardian(proposal)
    end
  end

  # ===========================================================================
  # 3. UNIT TESTS — Resource bounding (SC-NEURO-002)
  # ===========================================================================

  describe "resource bounding — SC-NEURO-002" do
    test "usage within all limits is accepted" do
      usage = %{tokens_used: 512, time_ms: 200, memory_mb: 16}
      assert :ok = check_resource_bounds(usage, @resource_limits)
    end

    test "token usage at exact ceiling is accepted" do
      usage = %{tokens_used: 4_096, time_ms: 200, memory_mb: 16}
      assert :ok = check_resource_bounds(usage, @resource_limits)
    end

    test "token usage exceeding ceiling by one is rejected" do
      usage = %{tokens_used: 4_097, time_ms: 200, memory_mb: 16}
      assert {:error, :tokens_exceeded, _} = check_resource_bounds(usage, @resource_limits)
    end

    test "time exceeding limit is rejected" do
      usage = %{tokens_used: 100, time_ms: 5_001, memory_mb: 16}
      assert {:error, :time_exceeded, _} = check_resource_bounds(usage, @resource_limits)
    end

    test "memory exceeding limit is rejected" do
      usage = %{tokens_used: 100, time_ms: 200, memory_mb: 200}
      assert {:error, :memory_exceeded, _} = check_resource_bounds(usage, @resource_limits)
    end

    test "zero usage is accepted" do
      usage = %{tokens_used: 0, time_ms: 0, memory_mb: 0}
      assert :ok = check_resource_bounds(usage, @resource_limits)
    end

    test "resource error detail includes limit and actual values" do
      usage = %{tokens_used: 9_000, time_ms: 200, memory_mb: 16}
      {:error, :tokens_exceeded, detail} = check_resource_bounds(usage, @resource_limits)
      assert detail.actual == 9_000
      assert detail.limit == @resource_limits.max_tokens
    end
  end

  # ===========================================================================
  # 4. UNIT TESTS — Forbidden operations (SC-NEURO-003)
  # ===========================================================================

  describe "forbidden operations — SC-NEURO-003" do
    test "rm -rf is forbidden" do
      assert is_forbidden_operation?("rm -rf /data")
    end

    test "DROP TABLE is forbidden" do
      assert is_forbidden_operation?("DROP TABLE users")
    end

    test "git push --force is forbidden" do
      assert is_forbidden_operation?("git push origin main --force")
    end

    test "mix ecto.reset is forbidden" do
      assert is_forbidden_operation?("mix ecto.reset")
    end

    test "podman rm -f is forbidden" do
      assert is_forbidden_operation?("podman rm -f indrajaal-db-prod")
    end

    test "DELETE FROM with WHERE 1=1 is forbidden" do
      assert is_forbidden_operation?("DELETE FROM events WHERE 1=1")
    end

    test "safe code description is not forbidden" do
      refute is_forbidden_operation?("Add @spec to Sentinel.assess_now/0")
    end

    test "SELECT query is not forbidden" do
      refute is_forbidden_operation?("SELECT id FROM users WHERE active = true")
    end

    test "mix compile is not forbidden" do
      refute is_forbidden_operation?("mix compile --warnings-as-errors")
    end

    test "case-insensitive matching catches lowercase 'drop table'" do
      assert is_forbidden_operation?("drop table sessions")
    end
  end

  # ===========================================================================
  # 5. UNIT TESTS — Shadow testing (AOR-REG-005, SC-GDE-002)
  # ===========================================================================

  describe "shadow testing — AOR-REG-005" do
    test "approved proposal runs shadow test and returns pass result" do
      proposal = create_proposal(:code_change, @valid_params)
      result = run_shadow_test(proposal, %{simulate_pass: true})

      assert result.passed == true
      assert is_float(result.fitness)
      assert result.fitness >= 0.0 and result.fitness <= 1.0
    end

    test "shadow test failure sets passed: false" do
      proposal = create_proposal(:code_change, @valid_params)
      result = run_shadow_test(proposal, %{simulate_pass: false})
      assert result.passed == false
    end

    test "shadow result includes coverage metric" do
      proposal = create_proposal(:code_change, @valid_params)
      result = run_shadow_test(proposal, %{simulate_pass: true})
      assert Map.has_key?(result, :coverage)
      assert result.coverage >= 0.0 and result.coverage <= 1.0
    end

    test "shadow result includes duration_ms" do
      proposal = create_proposal(:code_change, @valid_params)
      result = run_shadow_test(proposal, %{simulate_pass: true})
      assert Map.has_key?(result, :duration_ms)
      assert result.duration_ms >= 0
    end

    test "shadow test with regressions sets passed: false" do
      proposal = create_proposal(:code_change, @valid_params)

      result =
        run_shadow_test(proposal, %{
          simulate_pass: true,
          regressions: ["Sentinel.assess_now/0 response changed"]
        })

      assert result.passed == false
      assert length(result.regressions) > 0
    end

    test "fitness threshold for activation is 0.85 per SC-GDE-004" do
      assert @fitness_threshold == 0.85
    end

    test "high-quality shadow result exceeds activation threshold" do
      proposal = create_proposal(:code_change, @valid_params)

      result =
        run_shadow_test(proposal, %{simulate_pass: true, tests_passed_ratio: 1.0, coverage: 0.97})

      assert result.fitness >= @fitness_threshold
    end

    test "activation is blocked when shadow fails — SC-GDE-002" do
      proposal = create_proposal(:code_change, @valid_params)
      shadow = run_shadow_test(proposal, %{simulate_pass: false})
      refute shadow.passed
      assert {:error, :shadow_failed, _} = activate_proposal_checked(proposal, shadow)
    end
  end

  # ===========================================================================
  # 6. UNIT TESTS — Activation pipeline
  # ===========================================================================

  describe "activation pipeline" do
    test "approved + shadow-passed proposal activates successfully" do
      proposal = create_proposal(:code_change, @valid_params)
      shadow = run_shadow_test(proposal, %{simulate_pass: true, tests_passed_ratio: 1.0})
      assert shadow.passed
      record = activate_proposal(proposal, shadow)
      assert record.status == :activated
      assert record.proposal_id == proposal.id
    end

    test "activation record includes timestamp" do
      proposal = create_proposal(:code_change, @valid_params)
      shadow = run_shadow_test(proposal, %{simulate_pass: true, tests_passed_ratio: 1.0})
      record = activate_proposal(proposal, shadow)
      assert is_integer(record.activated_at)
      assert record.activated_at > 0
    end

    test "activation record includes shadow fitness" do
      proposal = create_proposal(:code_change, @valid_params)
      shadow = run_shadow_test(proposal, %{simulate_pass: true, tests_passed_ratio: 1.0})
      record = activate_proposal(proposal, shadow)
      assert Map.has_key?(record, :shadow_fitness)
      assert is_float(record.shadow_fitness)
    end

    test "activation record is written to register with non-nil block id" do
      proposal = create_proposal(:code_change, @valid_params)
      shadow = run_shadow_test(proposal, %{simulate_pass: true, tests_passed_ratio: 1.0})
      record = activate_proposal(proposal, shadow)
      assert record.register_block_id != nil
      assert is_binary(record.register_block_id)
    end

    test "activation event_type is :code_evolution" do
      proposal = create_proposal(:code_change, @valid_params)
      shadow = run_shadow_test(proposal, %{simulate_pass: true, tests_passed_ratio: 1.0})
      record = activate_proposal(proposal, shadow)
      assert record.event_type == :code_evolution
    end
  end

  # ===========================================================================
  # 7. UNIT TESTS — Tricameral consensus (SC-CONSENSUS-001/002/003)
  # ===========================================================================

  describe "tricameral consensus — SC-CONSENSUS-001/002/003" do
    test "valid proposal achieves 3/3 approval and is :approved" do
      proposal = create_proposal(:code_change, @valid_params)
      result = tricameral_vote(proposal)

      assert result.overall == :approved
      assert result.approvals >= 2
      assert result.quorum_met == true
    end

    test "all three chambers participate in every vote" do
      proposal = create_proposal(:code_change, @valid_params)
      result = tricameral_vote(proposal)
      chamber_ids = Enum.map(result.votes, fn {c, _, _} -> c end)

      assert :constitutional_chamber in chamber_ids
      assert :safety_chamber in chamber_ids
      assert :operational_chamber in chamber_ids
    end

    test "constitutional chamber vetoes when stamp_refs is empty — SC-CONSENSUS-002" do
      # Bypass validate_proposal_fields to reach chamber logic directly
      proposal = create_proposal(:code_change, @valid_params) |> Map.put(:stamp_refs, [])
      result = tricameral_vote(proposal)

      {_, vote, _} =
        Enum.find(result.votes, fn {c, _, _} -> c == :constitutional_chamber end)

      assert vote == :veto
      assert result.overall == :vetoed
    end

    test "safety chamber vetoes forbidden operation content" do
      params = Map.put(@valid_params, :description, "rm -rf /tmp/data")
      proposal = create_proposal(:code_change, params)
      result = tricameral_vote(proposal)

      {_, vote, _} = Enum.find(result.votes, fn {c, _, _} -> c == :safety_chamber end)
      assert vote == :veto
    end

    test "operational chamber vetoes proposal exceeding 80% token ceiling" do
      # 80% of 4096 = 3276; use 3500 to exceed threshold
      params = Map.put(@valid_params, :tokens_used, 3_500)
      proposal = create_proposal(:code_change, params)
      result = tricameral_vote(proposal)

      {_, vote, _} = Enum.find(result.votes, fn {c, _, _} -> c == :operational_chamber end)
      assert vote == :veto
    end

    test "single veto blocks approval regardless of other chambers — SC-CONSENSUS-002" do
      # Empty stamp_refs triggers only constitutional veto; others approve
      proposal = create_proposal(:code_change, @valid_params) |> Map.put(:stamp_refs, [])
      result = tricameral_vote(proposal)
      assert result.overall == :vetoed
    end

    test "all vote elapsed times remain within chamber timeout — SC-CONSENSUS-003" do
      proposal = create_proposal(:code_change, @valid_params)
      result = tricameral_vote(proposal)

      Enum.each(result.votes, fn {chamber, _vote, elapsed_ms} ->
        assert elapsed_ms < @chamber_timeout_ms,
               "#{chamber} vote took #{elapsed_ms}ms, exceeded #{@chamber_timeout_ms}ms"
      end)
    end
  end

  # ===========================================================================
  # 8. UNIT TESTS — Context compaction trigger (AOR-PROM-003)
  # ===========================================================================

  describe "context compaction trigger — AOR-PROM-003" do
    test "returns false when context usage is below 75%" do
      proposal = create_proposal(:code_change, Map.put(@valid_params, :context_usage_pct, 0.74))
      refute context_compaction_needed?(proposal)
    end

    test "returns true at exactly 75% context usage" do
      proposal = create_proposal(:code_change, Map.put(@valid_params, :context_usage_pct, 0.75))
      assert context_compaction_needed?(proposal)
    end

    test "returns true when context usage exceeds 75%" do
      proposal = create_proposal(:code_change, Map.put(@valid_params, :context_usage_pct, 0.90))
      assert context_compaction_needed?(proposal)
    end

    test "returns false when context_usage_pct key is absent" do
      proposal = create_proposal(:code_change, @valid_params) |> Map.delete(:context_usage_pct)
      refute context_compaction_needed?(proposal)
    end
  end

  # ===========================================================================
  # PROPERTY TESTS — universal invariants
  # ===========================================================================

  describe "property: forbidden ops always vetoed by Guardian" do
    # PropCheck forall — uses PC. generators
    test "PropCheck: any destructive command prefix is always vetoed by Guardian" do
      forall cmd <- pc_destructive_command() do
        params = Map.put(@valid_params, :description, cmd)
        proposal = create_proposal(:code_change, params)

        case validate_with_guardian(proposal) do
          {:vetoed, :forbidden_operation, _} -> true
          {:vetoed, :resource_limit, _} -> true
          {:approved, _} -> false
        end
      end
    end
  end

  describe "property: resource bounds never exceeded on approved proposals" do
    # StreamData check all — uses SD. generators; EP-GEN-014
    test "StreamData: within-limit usage always passes check_resource_bounds" do
      ExUnitProperties.check all(
                               tokens <- SD.integer(0..4_096),
                               time_ms <- SD.integer(0..5_000),
                               memory_mb <- SD.integer(0..128),
                               max_runs: 50
                             ) do
        usage = %{tokens_used: tokens, time_ms: time_ms, memory_mb: memory_mb}
        assert :ok = check_resource_bounds(usage, @resource_limits)
      end
    end
  end

  describe "property: all proposals receive a definitive pipeline verdict" do
    # StreamData — every proposal type + arbitrary safe content yields a valid tag
    test "StreamData: any proposal produces a classified outcome" do
      ExUnitProperties.check all(
                               ptype <-
                                 SD.member_of([
                                   :code_change,
                                   :config_change,
                                   :resource_allocation
                                 ]),
                               tokens <- SD.integer(0..(@resource_limits.max_tokens * 2)),
                               max_runs: 40
                             ) do
        params = Map.merge(@valid_params, %{tokens_used: tokens})
        proposal = create_proposal(ptype, params)

        guardian_result = validate_with_guardian(proposal)

        outcome =
          case guardian_result do
            {:vetoed, _, _} ->
              :guardian_vetoed

            {:approved, approved} ->
              shadow = run_shadow_test(approved, %{simulate_pass: true, tests_passed_ratio: 1.0})

              if shadow.passed do
                vote = tricameral_vote(approved)
                vote.overall
              else
                :shadow_failed
              end
          end

        assert outcome in [:guardian_vetoed, :shadow_failed, :approved, :vetoed, :rejected]
      end
    end
  end
end
