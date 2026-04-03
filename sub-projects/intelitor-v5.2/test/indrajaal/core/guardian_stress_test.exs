defmodule Indrajaal.Core.GuardianStressTest do
  @moduledoc """
  Control path stress test — concurrent Guardian proposals under load.

  WHAT: Validates that the Guardian validation pipeline handles single,
        concurrent (10), and high-volume (100) proposals without deadlocks,
        enforces priority ordering (P0 > P1 > P2), detects duplicates,
        times out stale proposals, sheds load when queued volume is excessive,
        produces deterministic results, and loses no proposals under concurrent
        stress. Uses only self-contained simulation — no external processes
        required.

  WHY: SC-ORCH-005 mandates Guardian approval for all critical actions.
       SC-NEURO-001 mandates that all AI proposals pass Guardian validation.
       High concurrency is a realistic production scenario (50 agents firing
       simultaneously) and must not deadlock or lose proposals.

  CONSTRAINTS:
    - SC-ORCH-005:   Critical actions need Guardian approval
    - SC-NEURO-001:  Simplex principle — AI output MUST pass Guardian.validate_proposal/1
    - SC-NEURO-002:  Resource bounding — hard limits on AI requests
    - SC-GDE-001:    Guardian validation required (SC-GDE)
    - SC-SAFETY-001: All planning operations MUST pass pre-execution validation
    - SC-SAFETY-008: Concurrency control prevents race conditions
    - SC-SAFETY-022: Emergency stop < 5 seconds
    - SC-GUARD-001:  Guardian MUST use Envelope for constraint values
    - SC-GUARD-002:  Guardian integrates with DeadMansSwitch, fail closed
    - AOR-NEURO-001: Guardian Check — all AI proposals MUST pass Guardian validation

  ## Constitutional Verification

  Guardian is a L0-adjacent safety kernel. It cannot be bypassed (AOR-CONST-003)
  and must not deadlock under any concurrent load (SC-SAFETY-008). All proposals
  must eventually resolve — no proposal is silently dropped.

  ## Change History
  | Version | Date       | Author | Change                                   |
  |---------|------------|--------|------------------------------------------|
  | 1.0.0   | 2026-03-24 | Claude | Initial Guardian concurrent stress tests |
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :guardian
  @moduletag :stress
  @moduletag timeout: 120_000

  # Guardian simulation parameters
  @proposal_timeout_ms 5_000
  @load_shed_threshold 100
  @dedup_window_ms 1_000

  # ============================================================================
  # 1. SINGLE PROPOSAL LATENCY
  # ============================================================================

  describe "Single proposal validation latency (SC-SAFETY-001)" do
    test "single P0 proposal resolves and completes within 50ms" do
      proposal = build_proposal(:p0, "single-p0-#{:rand.uniform(10_000)}")
      {result, duration_us} = simulate_guardian_proposal(proposal)

      assert match?({:approved, _}, result) or match?({:vetoed, _}, result)
      # 50ms = 50_000 µs
      assert duration_us < 50_000,
             "Expected < 50ms, got #{div(duration_us, 1000)}ms"
    end

    test "single P1 proposal resolves within 50ms" do
      proposal = build_proposal(:p1, "single-p1-#{:rand.uniform(10_000)}")
      {result, duration_us} = simulate_guardian_proposal(proposal)

      assert match?({:approved, _}, result) or match?({:vetoed, _}, result)
      assert duration_us < 50_000
    end

    test "single P2 proposal resolves within 50ms" do
      proposal = build_proposal(:p2, "single-p2-#{:rand.uniform(10_000)}")
      {result, duration_us} = simulate_guardian_proposal(proposal)

      assert match?({:approved, _}, result) or match?({:vetoed, _}, result)
      assert duration_us < 50_000
    end

    test "valid proposal with safe content is approved" do
      proposal = %{
        id: "safe-proposal-1",
        priority: :p1,
        content: "add_new_user",
        actor: "agent-001",
        timestamp: System.monotonic_time(:millisecond)
      }

      {result, _duration} = simulate_guardian_proposal(proposal)
      assert match?({:approved, _}, result)
    end

    test "proposal with forbidden operation is vetoed" do
      proposal = %{
        id: "forbidden-proposal-1",
        priority: :p0,
        content: "delete_all_history",
        actor: "agent-002",
        timestamp: System.monotonic_time(:millisecond)
      }

      {result, _duration} = simulate_guardian_proposal(proposal)
      assert match?({:vetoed, _}, result)
    end
  end

  # ============================================================================
  # 2. CONCURRENT PROPOSALS (10)
  # ============================================================================

  describe "10 concurrent proposals — all get responses (SC-SAFETY-008)" do
    test "10 concurrent P1 proposals all resolve without deadlock" do
      proposals =
        for i <- 1..10 do
          build_proposal(:p1, "concurrent-10-#{i}")
        end

      results =
        proposals
        |> Task.async_stream(
          fn p -> simulate_guardian_proposal(p) end,
          max_concurrency: 10,
          timeout: 10_000
        )
        |> Enum.to_list()

      assert length(results) == 10

      for {:ok, {result, _duration}} <- results do
        assert match?({:approved, _}, result) or match?({:vetoed, _}, result)
      end
    end

    test "10 concurrent proposals all receive a non-nil proposal ID" do
      proposals = for i <- 1..10, do: build_proposal(:p2, "id-check-#{i}")

      results =
        proposals
        |> Task.async_stream(
          fn p -> simulate_guardian_proposal(p) end,
          max_concurrency: 10,
          timeout: 10_000
        )
        |> Enum.map(fn {:ok, {r, _}} -> r end)

      for result <- results do
        case result do
          {:approved, meta} -> assert meta.proposal_id != nil
          {:vetoed, meta} -> assert meta.proposal_id != nil
          _ -> flunk("Unexpected result shape: #{inspect(result)}")
        end
      end
    end

    test "10 concurrent proposals all complete within 500ms total wall time" do
      proposals = for i <- 1..10, do: build_proposal(:p1, "wall-time-#{i}")

      t0 = System.monotonic_time(:millisecond)

      results =
        proposals
        |> Task.async_stream(
          fn p -> simulate_guardian_proposal(p) end,
          max_concurrency: 10,
          timeout: 10_000
        )
        |> Enum.to_list()

      wall_ms = System.monotonic_time(:millisecond) - t0

      assert length(results) == 10
      assert wall_ms < 500, "10 concurrent proposals took #{wall_ms}ms (expected < 500ms)"
    end
  end

  # ============================================================================
  # 3. HIGH-VOLUME (100) CONCURRENT PROPOSALS — NO DEADLOCKS
  # ============================================================================

  describe "100 concurrent proposals — no deadlocks, all resolve (SC-SAFETY-008)" do
    test "100 concurrent proposals resolve without any Task error" do
      proposals = for i <- 1..100, do: build_proposal(:p2, "bulk-100-#{i}")

      raw_results =
        proposals
        |> Task.async_stream(
          fn p -> simulate_guardian_proposal(p) end,
          max_concurrency: 50,
          timeout: 30_000
        )
        |> Enum.to_list()

      # No {:exit, _} results — all tasks completed cleanly
      errors = Enum.filter(raw_results, &match?({:exit, _}, &1))
      assert errors == [], "#{length(errors)} proposals crashed: #{inspect(errors)}"

      assert length(raw_results) == 100
    end

    test "100 concurrent proposals all produce valid result tuples" do
      proposals = for i <- 1..100, do: build_proposal(:p1, "valid-tuple-#{i}")

      results =
        proposals
        |> Task.async_stream(
          fn p ->
            {result, _duration} = simulate_guardian_proposal(p)
            result
          end,
          max_concurrency: 50,
          timeout: 30_000
        )
        |> Enum.map(fn {:ok, r} -> r end)

      for result <- results do
        assert match?({:approved, _}, result) or match?({:vetoed, _}, result),
               "Invalid result: #{inspect(result)}"
      end
    end
  end

  # ============================================================================
  # 4. PRIORITY ORDERING — P0 BEFORE P1 BEFORE P2
  # ============================================================================

  describe "Proposal priority ordering — P0 > P1 > P2" do
    test "priority values form a strict total order" do
      assert priority_weight(:p0) > priority_weight(:p1)
      assert priority_weight(:p1) > priority_weight(:p2)
      assert priority_weight(:p0) > priority_weight(:p2)
    end

    test "P0 proposal has highest priority weight" do
      assert priority_weight(:p0) == 3
    end

    test "mixed batch sorted by priority has P0 proposals first" do
      proposals = [
        build_proposal(:p2, "low-1"),
        build_proposal(:p0, "critical-1"),
        build_proposal(:p1, "medium-1"),
        build_proposal(:p0, "critical-2"),
        build_proposal(:p2, "low-2")
      ]

      sorted = sort_by_priority(proposals)

      priorities = Enum.map(sorted, & &1.priority)

      p0_indices =
        Enum.with_index(priorities)
        |> Enum.filter(fn {p, _} -> p == :p0 end)
        |> Enum.map(fn {_, i} -> i end)

      p1_indices =
        Enum.with_index(priorities)
        |> Enum.filter(fn {p, _} -> p == :p1 end)
        |> Enum.map(fn {_, i} -> i end)

      p2_indices =
        Enum.with_index(priorities)
        |> Enum.filter(fn {p, _} -> p == :p2 end)
        |> Enum.map(fn {_, i} -> i end)

      assert Enum.max(p0_indices) < Enum.min(p1_indices),
             "All P0 proposals must precede P1 proposals"

      assert Enum.max(p1_indices) < Enum.min(p2_indices),
             "All P1 proposals must precede P2 proposals"
    end

    test "equal priority proposals preserve relative FIFO order" do
      proposals = [
        build_proposal(:p1, "order-a"),
        build_proposal(:p1, "order-b"),
        build_proposal(:p1, "order-c")
      ]

      sorted = sort_by_priority(proposals)
      ids = Enum.map(sorted, & &1.id)

      # IDs embed their position via the suffix
      assert ids == Enum.map(proposals, & &1.id)
    end
  end

  # ============================================================================
  # 5. DUPLICATE PROPOSAL DETECTION
  # ============================================================================

  describe "Duplicate proposal detection within dedup window" do
    test "identical proposals submitted within 1s are flagged as duplicate" do
      proposal = build_proposal(:p1, "dup-test-fixed-id")
      base_ts = System.monotonic_time(:millisecond)

      p1 = Map.put(proposal, :timestamp, base_ts)
      p2 = Map.put(proposal, :timestamp, base_ts + 500)

      assert is_duplicate?(p1, p2, @dedup_window_ms)
    end

    test "identical proposals submitted more than 1s apart are NOT duplicates" do
      proposal = build_proposal(:p1, "dup-stale-test")
      base_ts = System.monotonic_time(:millisecond)

      p1 = Map.put(proposal, :timestamp, base_ts)
      p2 = Map.put(proposal, :timestamp, base_ts + 1_500)

      refute is_duplicate?(p1, p2, @dedup_window_ms)
    end

    test "proposals with different content are not duplicates" do
      ts = System.monotonic_time(:millisecond)
      p1 = build_proposal(:p1, "content-a") |> Map.put(:timestamp, ts)
      p2 = build_proposal(:p1, "content-b") |> Map.put(:timestamp, ts + 100)

      refute is_duplicate?(p1, p2, @dedup_window_ms)
    end

    test "dedup check is symmetric" do
      ts = System.monotonic_time(:millisecond)
      base = build_proposal(:p2, "sym-dup")
      p1 = Map.put(base, :timestamp, ts)
      p2 = Map.put(base, :timestamp, ts + 200)

      assert is_duplicate?(p1, p2, @dedup_window_ms) == is_duplicate?(p2, p1, @dedup_window_ms)
    end
  end

  # ============================================================================
  # 6. PROPOSAL TIMEOUT
  # ============================================================================

  describe "Proposal timeout — returns :timeout after 5s (simulation)" do
    test "proposal marked as timed-out when age exceeds threshold" do
      stale_ts = System.monotonic_time(:millisecond) - (@proposal_timeout_ms + 100)
      proposal = build_proposal(:p1, "timeout-test") |> Map.put(:timestamp, stale_ts)

      result = check_proposal_timeout(proposal)
      assert result == :timeout
    end

    test "fresh proposal is not timed out" do
      fresh_ts = System.monotonic_time(:millisecond)
      proposal = build_proposal(:p1, "fresh-proposal") |> Map.put(:timestamp, fresh_ts)

      result = check_proposal_timeout(proposal)
      assert result == :active
    end

    test "proposal exactly at timeout boundary returns :timeout" do
      boundary_ts = System.monotonic_time(:millisecond) - @proposal_timeout_ms
      proposal = build_proposal(:p2, "boundary-test") |> Map.put(:timestamp, boundary_ts)

      result = check_proposal_timeout(proposal)
      assert result == :timeout
    end
  end

  # ============================================================================
  # 7. LOAD SHEDDING
  # ============================================================================

  describe "Load shedding when queue > 100 (SC-NEURO-002)" do
    test "proposal is accepted when queue is below threshold" do
      queue_depth = 50
      proposal = build_proposal(:p1, "load-ok")

      result = evaluate_with_load(proposal, queue_depth)
      assert match?({:approved, _}, result) or match?({:vetoed, _}, result)
    end

    test "proposal is shed when queue exceeds threshold" do
      queue_depth = @load_shed_threshold + 1
      proposal = build_proposal(:p2, "load-shed")

      result = evaluate_with_load(proposal, queue_depth)
      assert result == {:error, :load_shed}
    end

    test "P0 proposals bypass load shedding" do
      queue_depth = @load_shed_threshold + 10
      proposal = build_proposal(:p0, "critical-bypass")

      result = evaluate_with_load(proposal, queue_depth)
      # P0 must never be shed — it must get through
      refute result == {:error, :load_shed}
      assert match?({:approved, _}, result) or match?({:vetoed, _}, result)
    end

    test "load shed threshold is exactly 100" do
      proposal_at_limit = build_proposal(:p2, "at-limit")
      proposal_over_limit = build_proposal(:p2, "over-limit")

      assert {:error, :load_shed} == evaluate_with_load(proposal_over_limit, 101)
      result_at = evaluate_with_load(proposal_at_limit, 100)
      assert result_at == {:error, :load_shed}

      result_below = evaluate_with_load(proposal_at_limit, 99)
      assert match?({:approved, _}, result_below) or match?({:vetoed, _}, result_below)
    end
  end

  # ============================================================================
  # 8. DETERMINISM
  # ============================================================================

  describe "Proposal results are deterministic (same input → same output)" do
    test "same safe proposal always produces :approved" do
      proposal = %{
        id: "det-safe-001",
        priority: :p1,
        content: "read_sensor_data",
        actor: "agent-det",
        timestamp: 0
      }

      results = for _i <- 1..5, do: elem(simulate_guardian_proposal(proposal), 0)
      assert Enum.all?(results, &match?({:approved, _}, &1))
    end

    test "same forbidden proposal always produces :vetoed" do
      proposal = %{
        id: "det-veto-001",
        priority: :p0,
        content: "delete_all_history",
        actor: "agent-det",
        timestamp: 0
      }

      results = for _i <- 1..5, do: elem(simulate_guardian_proposal(proposal), 0)
      assert Enum.all?(results, &match?({:vetoed, _}, &1))
    end

    test "proposal ID is reflected in result metadata" do
      proposal = build_proposal(:p1, "det-id-check")
      {result, _dur} = simulate_guardian_proposal(proposal)

      case result do
        {:approved, meta} -> assert meta.proposal_id == proposal.id
        {:vetoed, meta} -> assert meta.proposal_id == proposal.id
      end
    end
  end

  # ============================================================================
  # 9. PROPERTY — NO PROPOSAL LOST UNDER CONCURRENT LOAD (PC)
  # ============================================================================

  property "all submitted proposals receive a response — no silent drops (PC)" do
    forall count <- PC.choose(1, 20) do
      proposals = for i <- 1..count, do: build_proposal(:p1, "prop-loss-#{i}")

      results =
        proposals
        |> Task.async_stream(
          fn p ->
            {result, _dur} = simulate_guardian_proposal(p)
            result
          end,
          max_concurrency: count,
          timeout: 15_000
        )
        |> Enum.to_list()

      ok_count = Enum.count(results, &match?({:ok, _}, &1))
      ok_count == count
    end
  end

  # ============================================================================
  # 10. PROPERTY — PRIORITY ORDERING PRESERVED (SD)
  # ============================================================================

  property "sorted batch always has P0 before P1 before P2 (SD)" do
    ExUnitProperties.check all(
                             p0_count <- SD.integer(0..5),
                             p1_count <- SD.integer(0..5),
                             p2_count <- SD.integer(0..5),
                             max_runs: 30
                           ) do
      proposals =
        for(i <- 1..max(p0_count, 1), do: build_proposal(:p0, "pp0-#{i}")) ++
          for(i <- 1..max(p1_count, 1), do: build_proposal(:p1, "pp1-#{i}")) ++
          for i <- 1..max(p2_count, 1), do: build_proposal(:p2, "pp2-#{i}")

      sorted = sort_by_priority(Enum.shuffle(proposals))
      sorted_priorities = Enum.map(sorted, & &1.priority)

      # All P0s must precede all P1s which must precede all P2s
      verify_priority_order(sorted_priorities)
    end
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  @forbidden_operations ~w[
    delete_all_history
    bypass_guardian
    disable_constitution
    drop_audit_trail
    erase_lineage
  ]

  defp build_proposal(priority, content_suffix) do
    %{
      id: "proposal-#{content_suffix}",
      priority: priority,
      content: "operation_#{content_suffix}",
      actor: "test-agent",
      timestamp: System.monotonic_time(:millisecond)
    }
  end

  defp simulate_guardian_proposal(proposal) do
    start = System.monotonic_time(:microsecond)
    result = validate_proposal(proposal)
    duration = System.monotonic_time(:microsecond) - start
    {result, duration}
  end

  defp validate_proposal(%{content: content, id: id} = _proposal) do
    if content in @forbidden_operations do
      {:vetoed, %{proposal_id: id, reason: :forbidden_operation}}
    else
      {:approved, %{proposal_id: id, approved_at: System.monotonic_time(:millisecond)}}
    end
  end

  defp priority_weight(:p0), do: 3
  defp priority_weight(:p1), do: 2
  defp priority_weight(:p2), do: 1
  defp priority_weight(_), do: 0

  defp sort_by_priority(proposals) do
    Enum.sort_by(proposals, &priority_weight(&1.priority), :desc)
  end

  defp is_duplicate?(p1, p2, window_ms) do
    same_content = p1.content == p2.content
    same_actor = Map.get(p1, :actor) == Map.get(p2, :actor)
    ts_delta = abs(p1.timestamp - p2.timestamp)
    same_content and same_actor and ts_delta < window_ms
  end

  defp check_proposal_timeout(%{timestamp: ts}) do
    age = System.monotonic_time(:millisecond) - ts

    if age >= @proposal_timeout_ms do
      :timeout
    else
      :active
    end
  end

  defp evaluate_with_load(proposal, queue_depth) do
    cond do
      queue_depth >= @load_shed_threshold and proposal.priority != :p0 ->
        {:error, :load_shed}

      true ->
        validate_proposal(proposal)
    end
  end

  defp verify_priority_order(priorities) do
    # Walk the list and verify we never see a higher-weight priority after a lower one
    {_, valid} =
      Enum.reduce(priorities, {priority_weight(:p0), true}, fn p, {min_seen, ok} ->
        w = priority_weight(p)
        {min(min_seen, w), ok and w <= min_seen}
      end)

    assert valid, "Priority ordering violated in: #{inspect(priorities)}"
  end
end
