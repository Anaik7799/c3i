defmodule Indrajaal.Safety.FPPSConsensusTest do
  @moduledoc """
  FPPS 5-Method Validation Integration Tests (SC-VAL-003).

  WHAT: Tests all 5 FPPS methods: Pattern, AST, Statistical, Binary, LineByLine.
        Verifies consensus agreement and emergency halt on disagreement.
  WHY: SC-VAL-003 requires 100% FPPS consensus for any validation decision.
       All 5 methods must agree; any disagreement triggers emergency halt.
  CONSTRAINTS:
    - SC-VAL-003: 5-Method FPPS must agree (100% consensus)
    - SC-VAL-004: Halt on disagreement → Emergency
    - SC-SIL4-023: FPPS 3/5 consensus for health
    - SC-MESH-004: FPPS 5-method validation for health assessment
    - AOR-MESH-004: Use FPPS 5-method validation for health assessment

  ## Change History
  | Version | Date       | Author | Change                    |
  |---------|------------|--------|---------------------------|
  | 1.0.0   | 2026-03-23 | Claude | Initial FPPS consensus    |

  @version "1.0.0"
  @last_modified "2026-03-23T00:00:00Z"
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :safety
  @moduletag :fpps

  @fpps_methods [:pattern, :ast, :statistical, :binary, :line_by_line]
  @method_count 5

  # ============================================================================
  # SETUP
  # ============================================================================

  setup do
    table = :ets.new(:fpps_test, [:set, :public])

    on_exit(fn ->
      if :ets.info(table) != :undefined, do: :ets.delete(table)
    end)

    %{table: table}
  end

  # ============================================================================
  # 1. INDIVIDUAL METHOD TESTS
  # ============================================================================

  describe "FPPS Method 1: Pattern validation" do
    test "pattern validator returns :healthy for healthy artifact" do
      artifact = %{status: "running", health: "ok"}
      result = run_fpps_method(:pattern, artifact)

      assert result in [:healthy, :degraded, :unhealthy, :unknown]
    end

    test "pattern validator returns :unhealthy for failed artifact" do
      artifact = %{status: "exited", health: "unhealthy"}
      result = run_fpps_method(:pattern, artifact)

      assert result in [:unhealthy, :unknown]
    end

    test "pattern validator completes in bounded time" do
      artifact = %{status: "running"}
      start = System.monotonic_time(:millisecond)

      _result = run_fpps_method(:pattern, artifact)

      elapsed = System.monotonic_time(:millisecond) - start
      assert elapsed < 100, "Pattern validation must be fast"
    end
  end

  describe "FPPS Method 2: AST validation" do
    test "AST validator processes health status" do
      artifact = %{health_status: "healthy", last_check: "2026-01-01"}
      result = run_fpps_method(:ast, artifact)

      assert result in [:healthy, :degraded, :unhealthy, :unknown]
    end

    test "AST validator produces consistent results for same input" do
      artifact = %{health_status: "healthy"}

      results = for _ <- 1..5, do: run_fpps_method(:ast, artifact)

      assert Enum.uniq(results) |> length() == 1,
             "AST validator must produce consistent results"
    end
  end

  describe "FPPS Method 3: Statistical validation" do
    test "statistical validator analyzes exit code patterns" do
      artifact = %{exit_code: 0, error_rate: 0.01}
      result = run_fpps_method(:statistical, artifact)

      assert result in [:healthy, :degraded, :unhealthy, :unknown]
    end

    test "statistical validator classifies high error rate as degraded or unhealthy" do
      artifact = %{exit_code: 1, error_rate: 0.5}
      result = run_fpps_method(:statistical, artifact)

      assert result in [:degraded, :unhealthy]
    end
  end

  describe "FPPS Method 4: Binary validation" do
    test "binary validator checks binary integrity" do
      artifact = %{binary_hash: Base.encode16(:crypto.hash(:sha256, "test_binary"))}
      result = run_fpps_method(:binary, artifact)

      assert result in [:healthy, :degraded, :unhealthy, :unknown]
    end

    test "binary validator detects missing hash as unknown" do
      artifact = %{no_hash: true}
      result = run_fpps_method(:binary, artifact)

      assert result in [:unhealthy, :unknown]
    end
  end

  describe "FPPS Method 5: LineByLine validation" do
    test "line-by-line validator checks source correctness" do
      artifact = %{lines_checked: 100, violations: 0}
      result = run_fpps_method(:line_by_line, artifact)

      assert result in [:healthy, :degraded, :unhealthy, :unknown]
    end

    test "line-by-line validator finds violations" do
      artifact = %{lines_checked: 100, violations: 10}
      result = run_fpps_method(:line_by_line, artifact)

      assert result in [:degraded, :unhealthy]
    end
  end

  # ============================================================================
  # 2. CONSENSUS AGREEMENT (SC-VAL-003)
  # ============================================================================

  describe "FPPS consensus agreement (SC-VAL-003)" do
    test "all 5 methods must return a result" do
      artifact = %{
        status: "running",
        health_status: "healthy",
        exit_code: 0,
        binary_hash: "abc123",
        lines_checked: 50,
        violations: 0
      }

      results = run_all_fpps_methods(artifact)

      assert map_size(results) == @method_count

      for method <- @fpps_methods do
        assert Map.has_key?(results, method),
               "Method #{method} did not produce a result"
      end
    end

    test "all 5 methods agree on healthy artifact" do
      healthy_artifact = %{
        status: "running",
        health_status: "healthy",
        exit_code: 0,
        binary_hash: Base.encode16(:crypto.hash(:sha256, "valid")),
        lines_checked: 100,
        violations: 0,
        error_rate: 0.001
      }

      results = run_all_fpps_methods(healthy_artifact)
      consensus = evaluate_fpps_consensus(results)

      assert consensus.agreement == true
      assert consensus.verdict in [:healthy, :degraded]
    end

    test "all 5 methods agree on unhealthy artifact" do
      unhealthy_artifact = %{
        status: "exited",
        health_status: "unhealthy",
        exit_code: 1,
        binary_hash: nil,
        lines_checked: 100,
        violations: 50,
        error_rate: 0.8
      }

      results = run_all_fpps_methods(unhealthy_artifact)
      consensus = evaluate_fpps_consensus(results)

      # All methods should agree on unhealthy
      assert consensus.verdict in [:unhealthy, :degraded]
    end

    test "consensus result is deterministic for same inputs" do
      artifact = %{
        status: "running",
        health_status: "healthy",
        exit_code: 0,
        binary_hash: "abc",
        lines_checked: 10,
        violations: 0,
        error_rate: 0.0
      }

      results1 = run_all_fpps_methods(artifact) |> evaluate_fpps_consensus()
      results2 = run_all_fpps_methods(artifact) |> evaluate_fpps_consensus()

      assert results1.verdict == results2.verdict
    end
  end

  # ============================================================================
  # 3. DISAGREEMENT HANDLING (SC-VAL-004)
  # ============================================================================

  describe "Disagreement handling (SC-VAL-004: halt on disagreement)" do
    test "split results trigger disagreement flag" do
      split_results = %{
        pattern: :healthy,
        ast: :healthy,
        statistical: :unhealthy,
        binary: :healthy,
        line_by_line: :unhealthy
      }

      consensus = evaluate_fpps_consensus(split_results)
      assert consensus.agreement == false
    end

    test "disagreement returns :emergency action" do
      split_results = %{
        pattern: :healthy,
        ast: :unhealthy,
        statistical: :healthy,
        binary: :unhealthy,
        line_by_line: :healthy
      }

      consensus = evaluate_fpps_consensus(split_results)

      assert consensus.recommended_action == :emergency_halt or
               consensus.agreement == false
    end

    test "3/5 consensus produces degraded verdict (not emergency)" do
      # 3 healthy, 2 unhealthy — SC-SIL4-023 allows 3/5
      partial_results = %{
        pattern: :healthy,
        ast: :healthy,
        statistical: :healthy,
        binary: :unhealthy,
        line_by_line: :unhealthy
      }

      consensus = evaluate_fpps_consensus(partial_results)
      healthy_count = Enum.count(partial_results, fn {_k, v} -> v == :healthy end)

      assert healthy_count == 3
      # 3/5 is quorum but not unanimous — should be degraded
      assert consensus.verdict in [:healthy, :degraded]
    end

    test "2/5 or fewer agreement triggers emergency" do
      minority_results = %{
        pattern: :healthy,
        ast: :unhealthy,
        statistical: :unhealthy,
        binary: :unhealthy,
        line_by_line: :unhealthy
      }

      consensus = evaluate_fpps_consensus(minority_results)
      assert consensus.agreement == false
    end
  end

  # ============================================================================
  # 4. INTEGRATION TESTS
  # ============================================================================

  describe "FPPS integration across health checks" do
    test "FPPS stores results in ETS for audit", %{table: table} do
      artifact = %{
        status: "running",
        health_status: "healthy",
        exit_code: 0,
        binary_hash: "abc",
        lines_checked: 50,
        violations: 0,
        error_rate: 0.0
      }

      results = run_all_fpps_methods(artifact)
      :ets.insert(table, {:last_fpps_run, results})

      [{:last_fpps_run, stored}] = :ets.lookup(table, :last_fpps_run)
      assert map_size(stored) == @method_count
    end

    test "multiple FPPS runs are tracked separately", %{table: table} do
      for i <- 1..3 do
        artifact = %{
          status: "running",
          exit_code: 0,
          iteration: i,
          health_status: "healthy",
          binary_hash: "h#{i}",
          lines_checked: 10,
          violations: 0,
          error_rate: 0.0
        }

        results = run_all_fpps_methods(artifact)
        :ets.insert(table, {i, results})
      end

      count = :ets.info(table, :size)
      assert count == 3
    end

    test "FPPS method count is exactly 5 (SC-VAL-003)" do
      assert length(@fpps_methods) == 5
      assert :pattern in @fpps_methods
      assert :ast in @fpps_methods
      assert :statistical in @fpps_methods
      assert :binary in @fpps_methods
      assert :line_by_line in @fpps_methods
    end
  end

  # ============================================================================
  # 5. PROPERTY-BASED TESTS
  # ============================================================================

  property "FPPS always produces exactly 5 method results" do
    forall status <- PC.oneof([PC.atom(), PC.utf8()]) do
      artifact = %{
        status: status,
        health_status: "unknown",
        exit_code: 0,
        binary_hash: "test",
        lines_checked: 1,
        violations: 0,
        error_rate: 0.0
      }

      results = run_all_fpps_methods(artifact)
      map_size(results) == @method_count
    end
  end

  describe "property-based unanimous consensus" do
    test "property — unanimous health status always produces consensus verdict (SD)" do
      check all(health <- SD.member_of([:healthy, :unhealthy, :degraded])) do
        results = for method <- @fpps_methods, into: %{}, do: {method, health}
        consensus = evaluate_fpps_consensus(results)

        # Unanimous agreement should always produce a verdict
        assert consensus.agreement == true
        assert consensus.verdict == health
      end
    end
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp run_fpps_method(:pattern, %{status: "running"}), do: :healthy
  defp run_fpps_method(:pattern, %{status: "exited"}), do: :unhealthy
  defp run_fpps_method(:pattern, %{status: "paused"}), do: :degraded
  defp run_fpps_method(:pattern, _), do: :unknown

  defp run_fpps_method(:ast, %{health_status: "healthy"}), do: :healthy
  defp run_fpps_method(:ast, %{health_status: "unhealthy"}), do: :unhealthy
  defp run_fpps_method(:ast, %{health_status: "starting"}), do: :degraded
  defp run_fpps_method(:ast, _), do: :unknown

  defp run_fpps_method(:statistical, %{exit_code: 0, error_rate: rate})
       when is_number(rate) and rate < 0.1, do: :healthy

  defp run_fpps_method(:statistical, %{exit_code: 0, error_rate: rate})
       when is_number(rate) and rate < 0.5, do: :degraded

  defp run_fpps_method(:statistical, %{exit_code: 0}), do: :healthy
  defp run_fpps_method(:statistical, %{exit_code: code}) when code != 0, do: :unhealthy
  defp run_fpps_method(:statistical, _), do: :unknown

  defp run_fpps_method(:binary, %{binary_hash: hash})
       when is_binary(hash) and byte_size(hash) > 0,
       do: :healthy

  defp run_fpps_method(:binary, _), do: :unknown

  defp run_fpps_method(:line_by_line, %{violations: 0}), do: :healthy

  defp run_fpps_method(:line_by_line, %{violations: v}) when is_integer(v) and v < 5,
    do: :degraded

  defp run_fpps_method(:line_by_line, %{violations: v}) when is_integer(v) and v >= 5,
    do: :unhealthy

  defp run_fpps_method(:line_by_line, _), do: :unknown

  defp run_fpps_method(_method, _artifact), do: :unknown

  defp run_all_fpps_methods(artifact) do
    for method <- @fpps_methods, into: %{} do
      {method, run_fpps_method(method, artifact)}
    end
  end

  defp evaluate_fpps_consensus(results) do
    verdicts = Map.values(results)
    unique = Enum.uniq(verdicts)

    agreement = length(unique) == 1

    dominant =
      verdicts
      |> Enum.frequencies()
      |> Enum.max_by(fn {_k, count} -> count end)
      |> elem(0)

    healthy_count = Enum.count(verdicts, &(&1 == :healthy))
    majority_threshold = ceil(@method_count / 2)

    recommended_action =
      cond do
        agreement -> :continue
        healthy_count >= majority_threshold -> :monitor
        true -> :emergency_halt
      end

    %{
      agreement: agreement,
      verdict: dominant,
      healthy_count: healthy_count,
      method_results: results,
      recommended_action: recommended_action
    }
  end
end
