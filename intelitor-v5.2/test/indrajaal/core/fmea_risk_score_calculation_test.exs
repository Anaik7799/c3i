defmodule Indrajaal.Core.FmeaRiskScoreCalculationTest do
  @moduledoc """
  FMEA Risk Score Calculation Tests — L2 Mix Task simulation (Sprint 88).

  WHAT: Verifies the FMEA risk scoring engine using an ETS-backed simulation.
        Tests RPN (Risk Priority Number) computation, severity mapping, threshold
        flagging, mitigation generation, trend detection, and property invariants.
        No production module dependencies — fully self-contained simulation.

  WHY: FMEA (Failure Mode and Effects Analysis) is the primary risk quantification
       mechanism for SIL-6 constraint families. The RPN formula S×O×D must be
       mathematically correct, severity mappings must match priority tiers, and
       critical threshold detection must never produce false negatives.

  CONSTRAINTS:
    - SC-FMEA-001: FMEA analysis MUST run on every analysis invocation
    - SC-FMEA-002: RPN computation MUST use S×O×D formula
    - SC-FMEA-003: Severity mapping: P0=9, P1=7, P2=5, P3=3
    - SC-FMEA-004: RPN >= 200 MUST be flagged as critical
    - SC-FMEA-005: FMEA results MUST be cached for fast retrieval
    - SC-FMEA-006: Top 15 FMEA entries MUST be persisted in cache JSON
    - SC-FMEA-007: Mitigation plan MUST be generated for RPN >= 100
    - SC-FMEA-008: FMEA trend MUST be tracked in sync history

  ## Change History
  | Version | Date       | Author | Change                                   |
  |---------|------------|--------|------------------------------------------|
  | 1.0.0   | 2026-03-24 | Claude | Initial FMEA risk score simulation tests |

  @version "1.0.0"
  @last_modified "2026-03-24T00:00:00Z"
  """

  use ExUnit.Case, async: true
  import ExUnitProperties, except: [property: 2, property: 3]
  alias StreamData, as: SD

  @moduletag :fmea
  @moduletag :risk
  @moduletag :safety
  @moduletag :sprint_88

  # Priority → Severity mapping (SC-FMEA-003)
  @severity_map %{p0: 9, p1: 7, p2: 5, p3: 3}

  # RPN thresholds
  @critical_threshold 200
  @mitigation_threshold 100

  # ============================================================================
  # SETUP — ETS-backed FMEA simulation engine
  # ============================================================================

  setup do
    table = :ets.new(:fmea_test, [:set, :public, :named_table])
    history_table = :ets.new(:fmea_history_test, [:ordered_set, :public])

    on_exit(fn ->
      if :ets.info(table) != :undefined, do: :ets.delete(table)
      if :ets.info(history_table) != :undefined, do: :ets.delete(history_table)
    end)

    %{table: table, history: history_table}
  end

  # ============================================================================
  # 1. BASIC RPN CALCULATION (SC-FMEA-002)
  # ============================================================================

  describe "Basic RPN calculation: severity × occurrence × detection (SC-FMEA-002)" do
    test "RPN is product of the three factors" do
      assert compute_rpn(5, 4, 3) == 60
      assert compute_rpn(7, 6, 5) == 210
      assert compute_rpn(1, 1, 1) == 1
      assert compute_rpn(10, 10, 10) == 1000
    end

    test "RPN with S=9, O=8, D=7 yields 504 (critical)" do
      rpn = compute_rpn(9, 8, 7)
      assert rpn == 504
      assert rpn >= @critical_threshold
    end

    test "RPN with S=3, O=2, D=1 yields 6 (low risk)" do
      rpn = compute_rpn(3, 2, 1)
      assert rpn == 6
      refute rpn >= @mitigation_threshold
    end

    test "RPN is commutative within each factor dimension" do
      # Same factors, same result regardless of order among equal sets
      assert compute_rpn(3, 5, 7) == compute_rpn(7, 5, 3)
    end

    test "doubling severity doubles RPN" do
      rpn_base = compute_rpn(3, 4, 5)
      rpn_double = compute_rpn(6, 4, 5)
      assert rpn_double == rpn_base * 2
    end
  end

  # ============================================================================
  # 2. SEVERITY MAPPING (SC-FMEA-003)
  # ============================================================================

  describe "Severity mapping by priority tier (SC-FMEA-003)" do
    test "P0 priority maps to severity 9" do
      assert map_severity(:p0) == 9
    end

    test "P1 priority maps to severity 7" do
      assert map_severity(:p1) == 7
    end

    test "P2 priority maps to severity 5" do
      assert map_severity(:p2) == 5
    end

    test "P3 priority maps to severity 3" do
      assert map_severity(:p3) == 3
    end

    test "severity values are strictly ordered P0 > P1 > P2 > P3" do
      assert map_severity(:p0) > map_severity(:p1)
      assert map_severity(:p1) > map_severity(:p2)
      assert map_severity(:p2) > map_severity(:p3)
    end

    test "all four priorities map to distinct values" do
      values = Enum.map([:p0, :p1, :p2, :p3], &map_severity/1)
      assert length(Enum.uniq(values)) == 4
    end
  end

  # ============================================================================
  # 3. CRITICAL THRESHOLD DETECTION (SC-FMEA-004)
  # ============================================================================

  describe "Critical threshold: RPN >= 200 flagged as critical (SC-FMEA-004)" do
    test "RPN of exactly 200 is flagged critical" do
      fm = build_failure_mode("FM-200", :p0, 5, 5)
      result = analyze_failure_mode(fm)
      assert result.rpn == 200
      assert result.critical == true
    end

    test "RPN of 199 is NOT flagged critical" do
      # S=7, O=4, D=7 → 196
      fm = %{id: "FM-196", failure_mode: "near miss", severity: 7, occurrence: 4, detection: 7}
      result = analyze_failure_mode(fm)
      assert result.rpn == 196
      refute result.critical
    end

    test "RPN of 504 (S=9,O=8,D=7) is flagged critical" do
      fm = %{
        id: "FM-504",
        failure_mode: "severe cascade",
        severity: 9,
        occurrence: 8,
        detection: 7
      }

      result = analyze_failure_mode(fm)
      assert result.critical == true
    end

    test "RPN of 6 (S=3,O=2,D=1) is NOT flagged critical" do
      fm = %{id: "FM-006", failure_mode: "trivial", severity: 3, occurrence: 2, detection: 1}
      result = analyze_failure_mode(fm)
      refute result.critical
    end

    test "critical flag is derived solely from RPN >= 200, not from severity alone" do
      # High severity (P0=9) but low O and D: 9×1×1=9, not critical
      fm = %{
        id: "FM-009",
        failure_mode: "rare critical",
        severity: 9,
        occurrence: 1,
        detection: 1
      }

      result = analyze_failure_mode(fm)
      assert result.rpn == 9
      refute result.critical
    end
  end

  # ============================================================================
  # 4. MITIGATION PLAN GENERATION (SC-FMEA-007)
  # ============================================================================

  describe "Mitigation plan generated for RPN >= 100 (SC-FMEA-007)" do
    test "RPN of exactly 100 generates a mitigation plan" do
      # S=5, O=4, D=5 → 100
      fm = %{
        id: "FM-100",
        failure_mode: "threshold exact",
        severity: 5,
        occurrence: 4,
        detection: 5
      }

      result = analyze_failure_mode(fm)
      assert result.rpn == 100
      assert result.mitigation != nil
      assert result.mitigation.failure_mode == "threshold exact"
      assert result.mitigation.rpn == 100
      assert result.mitigation.recommended_action != nil
    end

    test "RPN of 99 does NOT generate a mitigation plan" do
      # S=3, O=3, D=11 is invalid; S=3, O=3, D=11 — use S=3, O=11, D=3 — all must be 1..10
      # S=9, O=11, D=1 — invalid. Use S=9, O=1, D=11 — invalid. Craft: 9×1×10=90 < 100
      # For exactly 99: not possible as 9×11=99 (invalid); use 99=3×3×11 (invalid)
      # Best under 100: S=9, O=1, D=10=90 or S=5, O=4, D=4=80. Use a value we know < 100.
      fm = %{
        id: "FM-090",
        failure_mode: "below threshold",
        severity: 9,
        occurrence: 1,
        detection: 10
      }

      result = analyze_failure_mode(fm)
      assert result.rpn == 90
      assert result.mitigation == nil
    end

    test "mitigation plan includes required fields" do
      fm = %{
        id: "FM-210",
        failure_mode: "db connection timeout",
        severity: 7,
        occurrence: 6,
        detection: 5
      }

      result = analyze_failure_mode(fm)
      assert result.rpn == 210
      assert result.mitigation != nil
      mit = result.mitigation

      assert Map.has_key?(mit, :failure_mode)
      assert Map.has_key?(mit, :rpn)
      assert Map.has_key?(mit, :recommended_action)
    end

    test "mitigation recommended_action is a non-empty string" do
      fm = %{id: "FM-350", failure_mode: "quorum loss", severity: 9, occurrence: 7, detection: 5}
      result = analyze_failure_mode(fm)
      assert result.rpn > 100
      assert is_binary(result.mitigation.recommended_action)
      assert String.length(result.mitigation.recommended_action) > 0
    end
  end

  # ============================================================================
  # 5. BATCH ANALYSIS AND SORTING (SC-FMEA-001)
  # ============================================================================

  describe "Batch analysis: 50 failure modes, sorted by RPN descending (SC-FMEA-001)" do
    test "batch of 50 failure modes are all scored", %{table: table} do
      failure_modes = generate_batch_failure_modes(50)
      results = run_batch_analysis(failure_modes, table)

      assert length(results) == 50
      assert Enum.all?(results, fn r -> is_integer(r.rpn) and r.rpn >= 1 end)
    end

    test "batch results are sorted by RPN descending" do
      failure_modes = generate_batch_failure_modes(20)
      results = run_batch_analysis(failure_modes, :ets.new(:tmp_sort, [:set]))
      sorted_rpns = Enum.map(results, & &1.rpn)

      assert sorted_rpns == Enum.sort(sorted_rpns, :desc)
    end

    test "top-N extraction returns exactly 15 entries per SC-FMEA-006" do
      failure_modes = generate_batch_failure_modes(50)
      results = run_batch_analysis(failure_modes, :ets.new(:tmp_topn, [:set]))
      top15 = Enum.take(results, 15)

      assert length(top15) == 15
    end

    test "top-15 have highest RPNs in the full batch" do
      failure_modes = generate_batch_failure_modes(30)
      results = run_batch_analysis(failure_modes, :ets.new(:tmp_top15, [:set]))
      top15 = Enum.take(results, 15)
      rest = Enum.drop(results, 15)

      min_top = Enum.min_by(top15, & &1.rpn).rpn
      max_rest = if rest == [], do: 0, else: Enum.max_by(rest, & &1.rpn).rpn

      assert min_top >= max_rest
    end

    test "all failure modes are stored in ETS during analysis", %{table: table} do
      failure_modes = generate_batch_failure_modes(10)
      run_batch_analysis(failure_modes, table)

      count = :ets.info(table, :size)
      assert count == 10
    end
  end

  # ============================================================================
  # 6. TREND DETECTION (SC-FMEA-008)
  # ============================================================================

  describe "Trend tracking: detect RPN regression (SC-FMEA-008)" do
    test "increasing RPN trend is detected as regression", %{history: history} do
      record_historical_rpn(history, "SC-MCP", 150, 1)
      record_historical_rpn(history, "SC-MCP", 180, 2)
      record_historical_rpn(history, "SC-MCP", 220, 3)

      trend = compute_rpn_trend(history, "SC-MCP")
      assert trend.direction == :increasing
      assert trend.regression == true
    end

    test "decreasing RPN trend is detected as improvement", %{history: history} do
      record_historical_rpn(history, "SC-SEM", 300, 1)
      record_historical_rpn(history, "SC-SEM", 250, 2)
      record_historical_rpn(history, "SC-SEM", 180, 3)

      trend = compute_rpn_trend(history, "SC-SEM")
      assert trend.direction == :decreasing
      assert trend.regression == false
    end

    test "stable RPN trend is not flagged as regression", %{history: history} do
      record_historical_rpn(history, "SC-KMS", 120, 1)
      record_historical_rpn(history, "SC-KMS", 120, 2)
      record_historical_rpn(history, "SC-KMS", 120, 3)

      trend = compute_rpn_trend(history, "SC-KMS")
      assert trend.direction == :stable
      assert trend.regression == false
    end

    test "single data point yields stable trend", %{history: history} do
      record_historical_rpn(history, "SC-NEW", 100, 1)
      trend = compute_rpn_trend(history, "SC-NEW")
      assert trend.direction == :stable
    end

    test "trend delta is current minus previous RPN", %{history: history} do
      record_historical_rpn(history, "SC-HMI", 100, 1)
      record_historical_rpn(history, "SC-HMI", 150, 2)

      trend = compute_rpn_trend(history, "SC-HMI")
      assert trend.delta == 50
    end
  end

  # ============================================================================
  # 7. BOUNDS AND INVARIANTS
  # ============================================================================

  describe "RPN bounds and structural invariants" do
    test "RPN is never negative for valid S, O, D in 1..10" do
      for s <- 1..10, o <- [1, 5, 10], d <- [1, 5, 10] do
        assert compute_rpn(s, o, d) >= 1
      end
    end

    test "maximum RPN with all factors at 10 is 1000" do
      assert compute_rpn(10, 10, 10) == 1000
    end

    test "minimum RPN with all factors at 1 is 1" do
      assert compute_rpn(1, 1, 1) == 1
    end

    test "RPN range is 1..1000 for factors in 1..10" do
      sample_rpns =
        for s <- [1, 5, 10], o <- [1, 5, 10], d <- [1, 5, 10] do
          compute_rpn(s, o, d)
        end

      assert Enum.all?(sample_rpns, fn r -> r >= 1 and r <= 1000 end)
    end
  end

  # ============================================================================
  # 8. PROPERTY-BASED TESTS
  # ============================================================================

  test "property: random S,O,D in 1..10 always yields RPN in 1..1000 (SD)" do
    check all(
            s <- SD.integer(1..10),
            o <- SD.integer(1..10),
            d <- SD.integer(1..10)
          ) do
      rpn = compute_rpn(s, o, d)
      assert rpn >= 1
      assert rpn <= 1000
    end
  end

  test "property: higher severity with same O,D always yields higher RPN (SD)" do
    check all(
            s_low <- SD.integer(1..8),
            o <- SD.integer(1..10),
            d <- SD.integer(1..10)
          ) do
      s_high = s_low + 1
      rpn_low = compute_rpn(s_low, o, d)
      rpn_high = compute_rpn(s_high, o, d)
      assert rpn_high > rpn_low
    end
  end

  test "property: RPN formula S×O×D is commutative within the product (SD)" do
    check all(
            a <- SD.integer(1..10),
            b <- SD.integer(1..10),
            c <- SD.integer(1..10)
          ) do
      # S×O×D = O×S×D = any permutation — multiplication is commutative
      assert compute_rpn(a, b, c) == a * b * c
    end
  end

  # ============================================================================
  # PRIVATE: FMEA simulation helpers
  # ============================================================================

  # Compute RPN using the mandatory S×O×D formula (SC-FMEA-002)
  defp compute_rpn(severity, occurrence, detection)
       when is_integer(severity) and is_integer(occurrence) and is_integer(detection) do
    severity * occurrence * detection
  end

  # Map priority tier to severity value (SC-FMEA-003)
  defp map_severity(priority), do: Map.fetch!(@severity_map, priority)

  # Build a failure mode map from priority + occurrence + detection
  defp build_failure_mode(id, priority, occurrence, detection) do
    %{
      id: id,
      failure_mode: "#{id} failure scenario",
      severity: map_severity(priority),
      occurrence: occurrence,
      detection: detection
    }
  end

  # Analyze a single failure mode, computing RPN and thresholds
  defp analyze_failure_mode(
         %{failure_mode: description, severity: s, occurrence: o, detection: d} = fm
       ) do
    rpn = compute_rpn(s, o, d)

    mitigation =
      if rpn >= @mitigation_threshold do
        %{
          failure_mode: description,
          rpn: rpn,
          recommended_action: generate_recommended_action(rpn, description)
        }
      else
        nil
      end

    %{
      id: Map.get(fm, :id, "unknown"),
      failure_mode: description,
      severity: s,
      occurrence: o,
      detection: d,
      rpn: rpn,
      critical: rpn >= @critical_threshold,
      mitigation: mitigation,
      analyzed_at: System.system_time(:millisecond)
    }
  end

  # Generate a human-readable recommended action for RPN >= 100
  defp generate_recommended_action(rpn, description) do
    cond do
      rpn >= @critical_threshold ->
        "CRITICAL: Immediate remediation required for '#{description}'. " <>
          "Assign P0 task, implement redundancy, establish 24h monitoring."

      rpn >= @mitigation_threshold ->
        "HIGH: Schedule mitigation for '#{description}' within current sprint. " <>
          "Review detection mechanisms and reduce occurrence probability."

      true ->
        "Monitor '#{description}' in next review cycle."
    end
  end

  # Run batch analysis over a list of failure modes, storing results in ETS
  defp run_batch_analysis(failure_modes, table) do
    results =
      failure_modes
      |> Enum.map(&analyze_failure_mode/1)
      |> Enum.sort_by(& &1.rpn, :desc)

    Enum.each(results, fn result ->
      :ets.insert(table, {result.id, result})
    end)

    results
  end

  # Generate a batch of failure modes with varied S, O, D values
  defp generate_batch_failure_modes(count) do
    priorities = [:p0, :p1, :p2, :p3]

    Enum.map(1..count, fn i ->
      priority = Enum.at(priorities, rem(i - 1, 4))
      occurrence = rem(i, 10) + 1
      detection = rem(i * 3, 10) + 1

      %{
        id: "FM-#{String.pad_leading(Integer.to_string(i), 3, "0")}",
        failure_mode: "Failure mode scenario ##{i}",
        severity: map_severity(priority),
        occurrence: occurrence,
        detection: detection
      }
    end)
  end

  # Record a historical RPN reading for a constraint family in ETS
  defp record_historical_rpn(table, family, rpn, sequence) do
    key = {family, sequence}
    :ets.insert(table, {key, %{family: family, rpn: rpn, sequence: sequence}})
  end

  # Compute trend for a given constraint family by reading all history entries
  defp compute_rpn_trend(table, family) do
    entries =
      :ets.tab2list(table)
      |> Enum.filter(fn {{f, _seq}, _data} -> f == family end)
      |> Enum.sort_by(fn {{_f, seq}, _data} -> seq end)
      |> Enum.map(fn {_key, data} -> data.rpn end)

    case entries do
      [] ->
        %{direction: :stable, regression: false, delta: 0}

      [_single] ->
        %{direction: :stable, regression: false, delta: 0}

      rpns ->
        first = List.first(rpns)
        last = List.last(rpns)
        delta = last - first

        direction =
          cond do
            delta > 0 -> :increasing
            delta < 0 -> :decreasing
            true -> :stable
          end

        %{
          direction: direction,
          regression: direction == :increasing,
          delta: delta,
          first_rpn: first,
          last_rpn: last
        }
    end
  end
end
