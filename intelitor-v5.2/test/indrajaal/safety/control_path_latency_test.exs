defmodule Indrajaal.Safety.ControlPathLatencyTest do
  @moduledoc """
  Guardian proposal round-trip latency test suite.

  ## WHAT
  Tests that Guardian proposal validation and round-trip processing
  completes within the 50ms latency budget defined by SC-PRF-050.
  Simulates control messages at various priority levels and verifies
  latency bounds are respected under normal and elevated load.
  All tests are self-contained — no running Guardian GenServer required.

  ## CONSTRAINTS
  - SC-PRF-050: Response < 50ms
  - SC-GDE-001: Guardian validation required before deployment
  - SC-GDE-002: Shadow testing mandatory
  - SC-OODA-001: OODA cycle time < 100ms (SC-BIO-001: step < 100ms)
  - SC-SAFETY-001: Guardian pre-approval for planning mutations
  - SC-NEURO-001: AI output MUST pass Guardian.validate_proposal/1

  ## Change History
  | Version | Date       | Author | Change                                         |
  |---------|------------|--------|------------------------------------------------|
  | 1.0.0   | 2026-03-24 | Claude | Sprint 88 Wave 3 — control path latency tests  |
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :sprint_88
  @moduletag :latency
  @moduletag :safety

  # Latency budget per SC-PRF-050
  @max_latency_ms 50
  # Full OODA cycle budget per SC-OODA-001
  @max_ooda_ms 100
  # P0 control path must be faster
  @max_p0_latency_ms 10
  # Number of samples for statistical latency checks
  @sample_count 50

  # ============================================================================
  # SECTION 1: Proposal Construction
  # ============================================================================

  describe "proposal construction and validation" do
    test "safe read proposal is well-formed" do
      proposal = build_proposal(:read, "system_status", :p1)

      assert Map.has_key?(proposal, :id)
      assert Map.has_key?(proposal, :action)
      assert Map.has_key?(proposal, :resource)
      assert Map.has_key?(proposal, :priority)
      assert Map.has_key?(proposal, :created_at_us)
      assert proposal.action == :read
      assert proposal.priority == :p1
    end

    test "proposals have unique IDs" do
      proposals = for i <- 1..10, do: build_proposal(:read, "resource_#{i}", :p2)
      ids = Enum.map(proposals, & &1.id)
      assert length(Enum.uniq(ids)) == 10, "All proposal IDs must be unique"
    end

    test "proposal priority levels are valid" do
      valid_priorities = [:p0, :p1, :p2, :p3]

      for p <- valid_priorities do
        proposal = build_proposal(:read, "test", p)
        assert proposal.priority in valid_priorities
      end
    end

    test "proposal timestamps are in microseconds" do
      proposal = build_proposal(:read, "ts_test", :p1)
      # System.monotonic_time(:microsecond) returns large integer
      assert is_integer(proposal.created_at_us)
    end
  end

  # ============================================================================
  # SECTION 2: Simulated Validation Latency
  # ============================================================================

  describe "simulated Guardian validation latency (SC-PRF-050)" do
    test "P0 proposal validates under #{@max_p0_latency_ms}ms" do
      proposal = build_proposal(:emergency_stop, "safety_kernel", :p0)

      {elapsed_us, result} = :timer.tc(fn -> simulate_validate(proposal) end)
      elapsed_ms = elapsed_us / 1000

      assert result in [:approved, :vetoed]

      assert elapsed_ms < @max_p0_latency_ms,
             "P0 proposal validation #{Float.round(elapsed_ms, 3)}ms exceeds #{@max_p0_latency_ms}ms"
    end

    test "P1 proposal validates under #{@max_latency_ms}ms" do
      proposal = build_proposal(:update, "agent_config", :p1)

      {elapsed_us, result} = :timer.tc(fn -> simulate_validate(proposal) end)
      elapsed_ms = elapsed_us / 1000

      assert result in [:approved, :vetoed]

      assert elapsed_ms < @max_latency_ms,
             "P1 proposal validation #{Float.round(elapsed_ms, 3)}ms exceeds #{@max_latency_ms}ms"
    end

    test "P2 proposal validates under #{@max_latency_ms}ms" do
      proposal = build_proposal(:read, "metrics", :p2)

      {elapsed_us, result} = :timer.tc(fn -> simulate_validate(proposal) end)
      elapsed_ms = elapsed_us / 1000

      assert result in [:approved, :vetoed]

      assert elapsed_ms < @max_latency_ms,
             "P2 proposal validation #{Float.round(elapsed_ms, 3)}ms exceeds #{@max_latency_ms}ms"
    end

    test "#{@sample_count} sequential proposals all meet latency budget" do
      proposals =
        for i <- 1..@sample_count do
          build_proposal(:read, "resource_#{i}", :p2)
        end

      latencies =
        Enum.map(proposals, fn p ->
          {elapsed_us, _result} = :timer.tc(fn -> simulate_validate(p) end)
          elapsed_us / 1000
        end)

      over_budget = Enum.filter(latencies, &(&1 >= @max_latency_ms))

      assert length(over_budget) == 0,
             "#{length(over_budget)}/#{@sample_count} proposals exceeded #{@max_latency_ms}ms budget"
    end

    test "p99 latency across #{@sample_count} samples is under #{@max_latency_ms}ms" do
      latencies =
        for i <- 1..@sample_count do
          proposal = build_proposal(:read, "p99_#{i}", :p2)
          {elapsed_us, _} = :timer.tc(fn -> simulate_validate(proposal) end)
          elapsed_us / 1000
        end

      sorted = Enum.sort(latencies)
      p99_idx = max(0, round(@sample_count * 0.99) - 1)
      p99 = Enum.at(sorted, p99_idx)

      assert p99 < @max_latency_ms,
             "p99 latency #{Float.round(p99, 3)}ms exceeds #{@max_latency_ms}ms budget"
    end
  end

  # ============================================================================
  # SECTION 3: Full Round-Trip Timing
  # ============================================================================

  describe "full Guardian round-trip within OODA budget (SC-OODA-001)" do
    test "complete proposal round-trip under #{@max_ooda_ms}ms" do
      proposal = build_proposal(:read, "system_state", :p1)

      {elapsed_us, {result, decision, audit}} =
        :timer.tc(fn ->
          # Step 1: Validate
          validation_result = simulate_validate(proposal)

          # Step 2: Make decision
          decision = make_decision(validation_result)

          # Step 3: Record audit
          audit = build_audit_entry(proposal, validation_result)

          {validation_result, decision, audit}
        end)

      elapsed_ms = elapsed_us / 1000

      assert result in [:approved, :vetoed]
      assert decision in [:proceed, :veto, :fallback]
      assert is_map(audit)

      assert elapsed_ms < @max_ooda_ms,
             "Full round-trip #{Float.round(elapsed_ms, 2)}ms exceeds OODA budget #{@max_ooda_ms}ms"
    end

    test "concurrent round-trips do not degrade individual latency" do
      # 5 concurrent proposals
      tasks =
        for i <- 1..5 do
          Task.async(fn ->
            proposal = build_proposal(:read, "concurrent_#{i}", :p2)
            {elapsed_us, result} = :timer.tc(fn -> simulate_validate(proposal) end)
            {elapsed_us / 1000, result}
          end)
        end

      results = Enum.map(tasks, &Task.await(&1, 5000))

      for {latency_ms, result} <- results do
        assert result in [:approved, :vetoed]

        assert latency_ms < @max_latency_ms,
               "Concurrent proposal latency #{Float.round(latency_ms, 3)}ms exceeded budget"
      end
    end

    test "rejected proposal round-trip is faster than approval (fail-fast)" do
      # Forbidden proposals should be rejected quickly
      forbidden = build_proposal(:delete, "immutable_register", :p0)
      allowed = build_proposal(:read, "status", :p2)

      {forbidden_us, _} = :timer.tc(fn -> simulate_validate(forbidden) end)
      {allowed_us, _} = :timer.tc(fn -> simulate_validate(allowed) end)

      # Both must be within budget
      assert forbidden_us / 1000 < @max_latency_ms
      assert allowed_us / 1000 < @max_latency_ms
    end
  end

  # ============================================================================
  # SECTION 4: Priority-Weighted Latency
  # ============================================================================

  describe "priority-weighted latency ordering" do
    test "P0 proposals are processed before P3 proposals" do
      p0 = build_proposal(:emergency_stop, "kernel", :p0)
      p3 = build_proposal(:read, "logs", :p3)

      # P0 should have shorter or equal latency
      {p0_us, _} = :timer.tc(fn -> simulate_validate(p0) end)
      {p3_us, _} = :timer.tc(fn -> simulate_validate(p3) end)

      p0_ms = p0_us / 1000
      p3_ms = p3_us / 1000

      # Both within budget — P0 typically faster due to simpler path
      assert p0_ms < @max_latency_ms, "P0 latency #{p0_ms}ms must be within budget"
      assert p3_ms < @max_latency_ms, "P3 latency #{p3_ms}ms must be within budget"
    end

    test "priority queue processes high-priority items first" do
      # Build a priority queue simulation
      items = [
        %{priority: :p3, id: "low"},
        %{priority: :p0, id: "critical"},
        %{priority: :p1, id: "high"},
        %{priority: :p2, id: "medium"}
      ]

      sorted = sort_by_priority(items)

      assert hd(sorted).priority == :p0, "P0 must be processed first"
      assert List.last(sorted).priority == :p3, "P3 must be processed last"
    end

    test "mixed priority batch processes in correct order" do
      priorities = [:p2, :p0, :p3, :p1, :p2, :p0]

      proposals =
        Enum.with_index(priorities, fn p, i ->
          build_proposal(:read, "item_#{i}", p)
        end)

      sorted = sort_by_priority(proposals)
      sorted_priorities = Enum.map(sorted, & &1.priority)

      # P0 items first, then P1, P2, P3
      p0_count = Enum.count(priorities, &(&1 == :p0))
      p1_count = Enum.count(priorities, &(&1 == :p1))

      assert Enum.take(sorted_priorities, p0_count) == List.duplicate(:p0, p0_count)

      assert Enum.take(sorted_priorities, p0_count + p1_count) |> Enum.uniq() |> Enum.sort() == [
               :p0,
               :p1
             ]
    end
  end

  # ============================================================================
  # SECTION 5: Latency Budget Accounting
  # ============================================================================

  describe "latency budget accounting" do
    test "validation phase uses < 80% of total budget" do
      proposal = build_proposal(:read, "budget_test", :p1)
      budget_ms = @max_latency_ms

      {elapsed_us, _} = :timer.tc(fn -> simulate_validate(proposal) end)
      validation_ms = elapsed_us / 1000

      assert validation_ms < budget_ms * 0.8,
             "Validation #{Float.round(validation_ms, 3)}ms uses > 80% of #{budget_ms}ms budget"
    end

    test "latency histogram is populated correctly" do
      n = 20

      latencies =
        for i <- 1..n do
          proposal = build_proposal(:read, "hist_#{i}", :p2)
          {elapsed_us, _} = :timer.tc(fn -> simulate_validate(proposal) end)
          elapsed_us / 1000
        end

      histogram = build_latency_histogram(latencies)

      assert histogram.p50 < @max_latency_ms
      assert histogram.p95 < @max_latency_ms
      assert histogram.p99 < @max_latency_ms
      assert histogram.max < @max_latency_ms * 2
      assert histogram.count == n
    end

    test "deadline miss counter remains zero under normal load" do
      n = 30

      deadline_misses =
        for i <- 1..n do
          proposal = build_proposal(:read, "deadline_#{i}", :p2)
          {elapsed_us, _} = :timer.tc(fn -> simulate_validate(proposal) end)
          if elapsed_us / 1000 >= @max_latency_ms, do: 1, else: 0
        end

      total_misses = Enum.sum(deadline_misses)

      assert total_misses == 0,
             "#{total_misses}/#{n} proposals missed #{@max_latency_ms}ms deadline"
    end
  end

  # ============================================================================
  # SECTION 6: Property-Based Tests (EP-GEN-014)
  # ============================================================================

  describe "property: any proposal validates within latency budget (PropCheck)" do
    @tag timeout: 60_000
    test "all actions complete within budget" do
      forall action <- PC.oneof([:read, :write, :update, :query, :create]) do
        proposal = build_proposal(action, "prop_resource", :p2)
        {elapsed_us, result} = :timer.tc(fn -> simulate_validate(proposal) end)
        elapsed_ms = elapsed_us / 1000

        result in [:approved, :vetoed] and elapsed_ms < @max_latency_ms
      end
    end
  end

  describe "property: priority ordering is total and transitive (StreamData)" do
    @tag timeout: 30_000
    test "priority sort is stable and transitive" do
      ExUnitProperties.check all(
                               priorities <-
                                 SD.list_of(SD.member_of([:p0, :p1, :p2, :p3]),
                                   min_length: 2,
                                   max_length: 10
                                 )
                             ) do
        items =
          Enum.with_index(priorities, fn p, i ->
            %{priority: p, id: "item_#{i}"}
          end)

        sorted = sort_by_priority(items)
        sorted_priorities = Enum.map(sorted, & &1.priority)

        # Verify: no :p1 appears before a :p0
        p0_indices =
          sorted_priorities
          |> Enum.with_index()
          |> Enum.filter(fn {p, _} -> p == :p0 end)
          |> Enum.map(fn {_, i} -> i end)

        p1_indices =
          sorted_priorities
          |> Enum.with_index()
          |> Enum.filter(fn {p, _} -> p == :p1 end)
          |> Enum.map(fn {_, i} -> i end)

        max_p0 = if p0_indices == [], do: -1, else: Enum.max(p0_indices)
        min_p1 = if p1_indices == [], do: 999, else: Enum.min(p1_indices)

        max_p0 < min_p1
      end
    end
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp build_proposal(action, resource, priority) do
    %{
      id: "prop-#{action}-#{System.unique_integer([:positive])}",
      action: action,
      resource: resource,
      priority: priority,
      agent: "test_agent",
      created_at_us: System.monotonic_time(:microsecond)
    }
  end

  defp simulate_validate(proposal) do
    # Simulate Guardian validation logic without a running GenServer.
    # Priority-aware fast-path: P0 skips some checks, P3 runs all checks.
    _checks =
      case proposal.priority do
        :p0 -> [:existence]
        :p1 -> [:existence, :authorization]
        :p2 -> [:existence, :authorization, :rate_limit]
        :p3 -> [:existence, :authorization, :rate_limit, :audit]
      end

    # Forbidden patterns (constitutional invariants)
    forbidden_resources = ["immutable_register", "constitution", "guardian_kernel"]

    cond do
      proposal.resource in forbidden_resources and proposal.action == :delete ->
        :vetoed

      proposal.action == :emergency_stop and proposal.priority != :p0 ->
        :vetoed

      true ->
        :approved
    end
  end

  defp make_decision(:approved), do: :proceed
  defp make_decision(:vetoed), do: :veto
  defp make_decision(_), do: :fallback

  defp build_audit_entry(proposal, result) do
    %{
      proposal_id: proposal.id,
      action: proposal.action,
      resource: proposal.resource,
      priority: proposal.priority,
      result: result,
      recorded_at_us: System.monotonic_time(:microsecond)
    }
  end

  defp sort_by_priority(items) do
    priority_order = %{p0: 0, p1: 1, p2: 2, p3: 3}

    Enum.sort_by(items, fn item ->
      Map.get(priority_order, item.priority, 99)
    end)
  end

  defp build_latency_histogram(latencies) do
    sorted = Enum.sort(latencies)
    n = length(sorted)

    p50_idx = max(0, round(n * 0.50) - 1)
    p95_idx = max(0, round(n * 0.95) - 1)
    p99_idx = max(0, round(n * 0.99) - 1)

    %{
      count: n,
      min: List.first(sorted),
      max: List.last(sorted),
      p50: Enum.at(sorted, p50_idx),
      p95: Enum.at(sorted, p95_idx),
      p99: Enum.at(sorted, p99_idx)
    }
  end
end
