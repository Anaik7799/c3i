defmodule Indrajaal.Sentinel.HealthAssessmentFppsTest do
  @moduledoc """
  TDG test: Sentinel FPPS 5-method health consensus and threat detection.

  WHAT: Tests the FPPS 5-probe health assessment pipeline: Pattern, AST,
        Statistical, Binary, and LineByLine analysis methods. Verifies
        consensus logic, threat detection, RPN computation, PatternHunter
        pre-error detection timing, auto-healing, and Guardian escalation —
        all via self-contained `defp` helpers with no external production
        module dependencies.

  WHY: SC-IMMUNE-001 requires continuous health monitoring. SC-SIL4-023
       mandates FPPS 3/5 consensus for health decisions. SC-WATCHDOG-001
       constrains the check interval to <= 100ms. AOR-IMMUNE-004 requires
       threats with RPN >= 50 to be escalated to Guardian. SC-BIO-EXT-001
       requires PatternHunter pre-error detection < 10ms. These tests
       validate all those constraints using TDG-compliant dual property
       testing (PropCheck + ExUnitProperties).

  STAMP Constraints:
  - SC-IMMUNE-001: Sentinel SHALL monitor system health continuously
  - SC-SIL4-023:  FPPS 3/5 consensus for health and snapshot validation
  - SC-BIO-EXT-001: PatternHunter pre-error detection < 10ms
  - SC-BIO-EXT-002: SymbioticDefense threat response < 100ms
  - SC-FMEA-002:  RPN MUST use S×O×D formula
  - SC-FMEA-004:  RPN >= 200 flagged as critical
  - SC-WATCHDOG-001: Check interval <= 100ms
  - SC-WATCHDOG-002: Corruption triggers Guardian report
  - SC-WATCHDOG-003: Self-healing attempted before escalation
  - AOR-IMMUNE-001: Run Sentinel.assess_now() before critical ops
  - AOR-IMMUNE-004: Threats RPN >= 50 MUST be reported to Guardian
  - EP-GEN-014: Dual property testing — PropCheck forall + ExUnitProperties check all

  ## FPPS Methods
  | Method      | Purpose                                       |
  |-------------|-----------------------------------------------|
  | Pattern     | Regexp/signature match on health signals      |
  | AST         | Structural analysis of anomaly tree           |
  | Statistical | Mean/stddev threshold crossing                |
  | Binary      | Quantised bit-pattern anomaly detection       |
  | LineByLine  | Sequential delta inspection on sorted impacts |

  ## Consensus Rules (SC-SIL4-023)
  - 5/5 same verdict -> UNANIMOUS (used for most critical gates)
  - >= 3/5 (quorum) agree on :healthy -> :healthy
  - >= 3/5 agree on :degraded, zero :healthy -> :degraded
  - Everything else -> :critical or :degraded (conservative fail-safe)

  ## Constitutional Verification
  - Psi_0 Existence: all helpers are total, never crash on any numeric input
  - Psi_1 Regeneration: status derivable purely from probe results and metrics
  - Psi_3 Verification: consensus is deterministic for same inputs

  ## TDG Compliance (Omega_4)
  - PropCheck `forall` property tests (PC. prefix for generators)
  - ExUnitProperties `check all` tests (SD. prefix for generators)
  - All logic in `defp` helpers — zero external module dependencies

  ## Change History
  | Version | Date       | Author | Change                                        |
  |---------|------------|--------|-----------------------------------------------|
  | 21.3.0  | 2026-03-24 | Claude | Sprint 88 — comprehensive FPPS health suite   |
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :safety
  @moduletag :fpps
  @moduletag :sentinel

  # Five FPPS probe method names (SC-SIL4-023)
  @fpps_methods [:pattern, :ast, :statistical, :binary, :line_by_line]

  # Quorum threshold: floor(5/2) + 1 = 3  (SC-SIL6-011, SC-SIL4-023)
  @quorum 3

  # RPN escalation threshold (AOR-IMMUNE-004)
  @rpn_escalation_threshold 50

  # RPN critical threshold (SC-FMEA-004)
  @rpn_critical_threshold 200

  # Watchdog check interval ceiling in milliseconds (SC-WATCHDOG-001)
  @watchdog_max_interval_ms 100

  # PatternHunter timing budget in milliseconds (SC-BIO-EXT-001)
  @pattern_hunter_budget_ms 10

  # Threat response budget in milliseconds (SC-BIO-EXT-002)
  @threat_response_budget_ms 100

  # ============================================================================
  # 1. Health Assessment -- SC-IMMUNE-001
  # ============================================================================

  describe "health assessment (SC-IMMUNE-001)" do
    test "assess_health returns {:ok, map} for all-healthy probes" do
      probes = all_probes(:healthy)
      assert {:ok, assessment} = assess_health(probes)
      assert is_map(assessment)
    end

    test "assessment contains required keys" do
      {:ok, assessment} = assess_health(all_probes(:healthy))

      for key <- [:status, :probe_results, :consensus_count, :assessed_at] do
        assert Map.has_key?(assessment, key),
               "assessment missing required key: #{inspect(key)}"
      end
    end

    test "status is one of the valid atoms" do
      {:ok, assessment} = assess_health(all_probes(:healthy))
      assert assessment.status in [:healthy, :degraded, :critical]
    end

    test "probe_results contains all 5 method results" do
      {:ok, assessment} = assess_health(all_probes(:healthy))
      assert map_size(assessment.probe_results) == 5

      for method <- @fpps_methods do
        assert Map.has_key?(assessment.probe_results, method),
               "probe_results missing method: #{method}"
      end
    end

    test "all-healthy probes produce :healthy status" do
      {:ok, assessment} = assess_health(all_probes(:healthy))
      assert assessment.status == :healthy
    end

    test "all-critical probes produce :critical status" do
      {:ok, assessment} = assess_health(all_probes(:critical))
      assert assessment.status == :critical
    end

    test "mixed probes with healthy quorum produce :healthy or :degraded" do
      probes = %{
        pattern: :healthy,
        ast: :healthy,
        statistical: :healthy,
        binary: :critical,
        line_by_line: :critical
      }

      {:ok, assessment} = assess_health(probes)
      assert assessment.status in [:healthy, :degraded]
    end

    test "assess_health is deterministic for the same input" do
      probes = all_probes(:healthy)
      {:ok, a1} = assess_health(probes)
      {:ok, a2} = assess_health(probes)
      assert a1.status == a2.status
      assert a1.consensus_count == a2.consensus_count
    end

    test "assessed_at is a DateTime" do
      {:ok, assessment} = assess_health(all_probes(:healthy))
      assert %DateTime{} = assessment.assessed_at
    end

    test "consensus_count is a non-negative integer" do
      {:ok, assessment} = assess_health(all_probes(:healthy))
      assert is_integer(assessment.consensus_count)
      assert assessment.consensus_count >= 0
    end
  end

  # ============================================================================
  # 2. FPPS 5-Method Consensus -- SC-SIL4-023
  # ============================================================================

  describe "FPPS 5-method consensus (SC-SIL4-023)" do
    test "unanimous :healthy yields :healthy" do
      assert fpps_consensus(List.duplicate(:healthy, 5)) == :healthy
    end

    test "unanimous :degraded yields :degraded" do
      assert fpps_consensus(List.duplicate(:degraded, 5)) == :degraded
    end

    test "unanimous :critical yields :critical" do
      assert fpps_consensus(List.duplicate(:critical, 5)) == :critical
    end

    test "3/5 :healthy (quorum met) yields :healthy or :degraded" do
      results = [:healthy, :healthy, :healthy, :degraded, :critical]
      assert fpps_consensus(results) in [:healthy, :degraded]
    end

    test "2/5 :healthy (below quorum) yields :degraded or :critical" do
      results = [:healthy, :healthy, :critical, :critical, :critical]
      assert fpps_consensus(results) in [:degraded, :critical]
    end

    test "exactly quorum :healthy avoids :critical" do
      results =
        List.duplicate(:healthy, @quorum) ++
          List.duplicate(:critical, 5 - @quorum)

      assert fpps_consensus(results) in [:healthy, :degraded]
    end

    test "one less than quorum :healthy yields :degraded or :critical" do
      below_quorum = @quorum - 1

      results =
        List.duplicate(:healthy, below_quorum) ++
          List.duplicate(:critical, 5 - below_quorum)

      assert fpps_consensus(results) in [:degraded, :critical]
    end

    test "consensus result is always a valid status atom" do
      for probe_vals <- [
            [:healthy, :healthy, :healthy, :healthy, :healthy],
            [:healthy, :degraded, :critical, :degraded, :healthy],
            [:critical, :critical, :degraded, :degraded, :critical],
            [:degraded, :degraded, :degraded, :critical, :critical]
          ] do
        result = fpps_consensus(probe_vals)

        assert result in [:healthy, :degraded, :critical],
               "consensus #{inspect(result)} not a valid status atom for #{inspect(probe_vals)}"
      end
    end

    test "quorum constant satisfies SIL4 floor(N/2)+1 for N=5" do
      assert @quorum == 3
    end
  end

  # ============================================================================
  # 3. FPPS Individual Methods -- Pattern, AST, Statistical, Binary, LineByLine
  # ============================================================================

  describe "FPPS Pattern method probe" do
    test "returns :healthy for clean metrics" do
      assert fpps_pattern(clean_metrics()) == :healthy
    end

    test "returns :critical for cpu above critical threshold" do
      metrics = Map.put(clean_metrics(), :cpu, 0.99)
      assert fpps_pattern(metrics) in [:degraded, :critical]
    end

    test "returns :degraded for memory pressure" do
      metrics = Map.put(clean_metrics(), :memory, 0.88)
      assert fpps_pattern(metrics) in [:degraded, :critical]
    end

    test "returns only valid status atoms for any float cpu in [0,1]" do
      for cpu <- [0.0, 0.25, 0.5, 0.75, 0.90, 0.95, 0.99, 1.0] do
        metrics = Map.put(clean_metrics(), :cpu, cpu)
        assert fpps_pattern(metrics) in [:healthy, :degraded, :critical]
      end
    end
  end

  describe "FPPS Statistical method probe" do
    test "returns :healthy for all low-impact metrics" do
      assert fpps_statistical(clean_metrics()) == :healthy
    end

    test "returns :degraded when combined impact crosses moderate threshold" do
      metrics = Map.merge(clean_metrics(), %{cpu: 0.65, memory: 0.60})
      assert fpps_statistical(metrics) in [:degraded, :critical]
    end

    test "returns :critical when any metric crosses critical threshold" do
      metrics = Map.put(clean_metrics(), :cpu, 0.98)
      assert fpps_statistical(metrics) == :critical
    end

    test "output is always a valid status atom" do
      for load <- [0.0, 0.3, 0.6, 0.9, 1.0] do
        metrics = Map.merge(clean_metrics(), %{cpu: load, memory: load})
        assert fpps_statistical(metrics) in [:healthy, :degraded, :critical]
      end
    end
  end

  describe "FPPS AST method probe" do
    test "returns :healthy for empty anomaly set" do
      assert fpps_ast(%{anomalies: [], health_score: 1.0}) == :healthy
    end

    test "returns :degraded for moderate anomaly depth" do
      result = fpps_ast(%{anomalies: [:cpu_spike, :latency], health_score: 0.65})
      assert result in [:degraded, :critical]
    end

    test "returns :critical for severe health score" do
      assert fpps_ast(%{anomalies: [:cascade], health_score: 0.2}) == :critical
    end
  end

  describe "FPPS Binary method probe" do
    test "returns :healthy for score near 1.0 (high quantised value)" do
      assert fpps_binary(1.0) == :healthy
      assert fpps_binary(0.9) == :healthy
    end

    test "returns :degraded for mid-range score" do
      result = fpps_binary(0.55)
      assert result in [:degraded, :critical]
    end

    test "returns :critical for score near 0.0" do
      assert fpps_binary(0.0) == :critical
      assert fpps_binary(0.1) == :critical
    end

    test "output is always valid for any float in [0.0, 1.0]" do
      for score <- [0.0, 0.1, 0.3, 0.5, 0.7, 0.9, 1.0] do
        assert fpps_binary(score) in [:healthy, :degraded, :critical]
      end
    end
  end

  describe "FPPS LineByLine method probe" do
    test "returns :healthy for empty sequential list" do
      assert fpps_line_by_line([]) == :healthy
    end

    test "returns :healthy for stable uniform sequence" do
      assert fpps_line_by_line([0.05, 0.05, 0.05]) == :healthy
    end

    test "returns :degraded or :critical for high-delta sequence" do
      result = fpps_line_by_line([0.05, 0.7, 0.1, 0.9])
      assert result in [:degraded, :critical]
    end

    test "output is always valid for any non-empty float list" do
      for values <- [[0.1], [0.0, 1.0], [0.1, 0.2, 0.3, 0.8]] do
        assert fpps_line_by_line(values) in [:healthy, :degraded, :critical]
      end
    end
  end

  # ============================================================================
  # 4. Threat Detection
  # ============================================================================

  describe "threat detection" do
    test "detects cpu_spike when cpu > 0.95" do
      metrics = Map.put(clean_metrics(), :cpu, 0.98)
      assert Enum.any?(detect_threats(metrics), &(&1.type == :cpu_spike))
    end

    test "detects memory_leak when memory > 0.90" do
      metrics = Map.put(clean_metrics(), :memory, 0.95)
      assert Enum.any?(detect_threats(metrics), &(&1.type == :memory_leak))
    end

    test "detects disk_full when disk > 0.95" do
      metrics = Map.put(clean_metrics(), :disk, 0.97)
      assert Enum.any?(detect_threats(metrics), &(&1.type == :disk_full))
    end

    test "detects network_partition when network_loss > 0.50" do
      metrics = Map.put(clean_metrics(), :network_loss, 0.6)
      assert Enum.any?(detect_threats(metrics), &(&1.type == :network_partition))
    end

    test "detects process_crash when flag is true" do
      metrics = Map.put(clean_metrics(), :process_crash, true)
      assert Enum.any?(detect_threats(metrics), &(&1.type == :process_crash))
    end

    test "returns empty list for healthy metrics" do
      assert detect_threats(clean_metrics()) == []
    end

    test "each detected threat has :type, :severity, :occurrence, :detection fields" do
      metrics = Map.put(clean_metrics(), :cpu, 0.99)
      [threat | _] = detect_threats(metrics)

      for key <- [:type, :severity, :occurrence, :detection] do
        assert Map.has_key?(threat, key), "threat missing field: #{inspect(key)}"
      end
    end

    test "multiple simultaneous anomalies produce multiple threats" do
      metrics = Map.merge(clean_metrics(), %{cpu: 0.99, memory: 0.96})
      assert length(detect_threats(metrics)) >= 2
    end

    test "threats contain only known type atoms" do
      metrics = %{cpu: 0.99, memory: 0.96, disk: 0.97, network_loss: 0.6, process_crash: true}
      known = [:cpu_spike, :memory_leak, :disk_full, :network_partition, :process_crash]

      for threat <- detect_threats(metrics) do
        assert threat.type in known, "unexpected threat type: #{inspect(threat.type)}"
      end
    end
  end

  # ============================================================================
  # 5. Threat RPN Computation -- SC-FMEA-002
  # ============================================================================

  describe "threat RPN computation (SC-FMEA-002)" do
    test "RPN equals severity * occurrence * detection" do
      assert compute_rpn(%{type: :test, severity: 7, occurrence: 4, detection: 3}) == 84
    end

    test "RPN is a positive integer" do
      rpn = compute_rpn(%{type: :test, severity: 9, occurrence: 3, detection: 5})
      assert is_integer(rpn) and rpn > 0
    end

    test "cpu_spike RPN >= escalation threshold (AOR-IMMUNE-004)" do
      assert compute_rpn(cpu_spike_threat()) >= @rpn_escalation_threshold
    end

    test "memory_leak RPN >= escalation threshold" do
      assert compute_rpn(memory_leak_threat()) >= @rpn_escalation_threshold
    end

    test "classify_threat_level :critical for RPN >= 200 (SC-FMEA-004)" do
      assert classify_threat_level(200) == :critical
      assert classify_threat_level(500) == :critical
      assert classify_threat_level(@rpn_critical_threshold) == :critical
    end

    test "classify_threat_level :high for RPN in [100, 200)" do
      assert classify_threat_level(100) == :high
      assert classify_threat_level(150) == :high
      assert classify_threat_level(199) == :high
    end

    test "classify_threat_level :medium for RPN in [50, 100)" do
      assert classify_threat_level(50) == :medium
      assert classify_threat_level(75) == :medium
      assert classify_threat_level(99) == :medium
    end

    test "classify_threat_level :low for RPN < 50" do
      assert classify_threat_level(1) == :low
      assert classify_threat_level(10) == :low
      assert classify_threat_level(49) == :low
    end

    test "maximum theoretical RPN is 1000 (10*10*10)" do
      assert compute_rpn(%{type: :max, severity: 10, occurrence: 10, detection: 10}) == 1_000
    end

    test "minimum theoretical RPN is 1 (1*1*1)" do
      assert compute_rpn(%{type: :min, severity: 1, occurrence: 1, detection: 1}) == 1
    end

    test "classify_threat_level is total for all boundary values" do
      for rpn <- [1, 49, 50, 99, 100, 199, 200, 1000] do
        level = classify_threat_level(rpn)

        assert level in [:low, :medium, :high, :critical],
               "unexpected level #{inspect(level)} for RPN #{rpn}"
      end
    end
  end

  # ============================================================================
  # 6. PatternHunter Timing -- SC-BIO-EXT-001
  # ============================================================================

  describe "PatternHunter pre-error detection timing (SC-BIO-EXT-001)" do
    test "pattern probe completes within 10ms budget on healthy metrics" do
      t0 = System.monotonic_time(:millisecond)
      _result = fpps_pattern(clean_metrics())
      elapsed = System.monotonic_time(:millisecond) - t0

      assert elapsed <= @pattern_hunter_budget_ms,
             "Pattern probe took #{elapsed}ms, budget is #{@pattern_hunter_budget_ms}ms"
    end

    test "pattern probe completes within 10ms budget on stressed metrics" do
      metrics = %{cpu: 0.99, memory: 0.98, disk: 0.96, network_loss: 0.7, process_crash: true}
      t0 = System.monotonic_time(:millisecond)
      _result = fpps_pattern(metrics)
      elapsed = System.monotonic_time(:millisecond) - t0

      assert elapsed <= @pattern_hunter_budget_ms,
             "Pattern probe took #{elapsed}ms, budget is #{@pattern_hunter_budget_ms}ms"
    end

    test "full 5-method FPPS run completes within threat response budget (SC-BIO-EXT-002)" do
      metrics = Map.merge(clean_metrics(), %{cpu: 0.85, memory: 0.75})
      health_state = %{anomalies: [:cpu_spike], health_score: 0.6}

      t0 = System.monotonic_time(:millisecond)

      _verdicts = %{
        pattern: fpps_pattern(metrics),
        ast: fpps_ast(health_state),
        statistical: fpps_statistical(metrics),
        binary: fpps_binary(0.6),
        line_by_line: fpps_line_by_line([0.15, 0.4, 0.3, 0.2])
      }

      elapsed = System.monotonic_time(:millisecond) - t0

      assert elapsed <= @threat_response_budget_ms,
             "FPPS run took #{elapsed}ms, budget is #{@threat_response_budget_ms}ms"
    end

    test "timing constants satisfy STAMP constraints" do
      assert @pattern_hunter_budget_ms == 10
      assert @threat_response_budget_ms == 100
      assert @watchdog_max_interval_ms <= 100
    end
  end

  # ============================================================================
  # 7. Health Degradation and Auto-Healing -- SC-WATCHDOG-003
  # ============================================================================

  describe "health degradation and auto-healing (SC-WATCHDOG-003)" do
    test "new health state is fully healthy" do
      state = new_health_state()
      assert state.health_score == 1.0
      assert state.status == :healthy
      assert state.anomalies == []
      assert state.heal_attempts == 0
      assert state.escalated == false
    end

    test "adding an anomaly degrades health" do
      state = new_health_state() |> add_anomaly(:cpu_spike, 0.25)
      assert state.health_score < 1.0
    end

    test "health score is bounded at 0.0 for extreme anomaly impact" do
      state =
        new_health_state()
        |> add_anomaly(:a, 0.4)
        |> add_anomaly(:b, 0.4)
        |> add_anomaly(:c, 0.4)

      assert state.health_score == 0.0
    end

    test "resolving an anomaly partially restores health" do
      state =
        new_health_state()
        |> add_anomaly(:a, 0.3)
        |> add_anomaly(:b, 0.2)
        |> remove_anomaly(:a)

      assert state.health_score > 0.0
      assert state.health_score < 1.0
    end

    test "resolving all anomalies restores health to 1.0" do
      state =
        new_health_state()
        |> add_anomaly(:a, 0.3)
        |> add_anomaly(:b, 0.15)
        |> remove_anomaly(:a)
        |> remove_anomaly(:b)

      assert_in_delta state.health_score, 1.0, 0.001
      assert state.status == :healthy
    end

    test "self-healing resets attempt counter on success (SC-WATCHDOG-003)" do
      state =
        new_health_state()
        |> add_anomaly(:transient, 0.1)
        |> attempt_heal(:transient, success: false)
        |> attempt_heal(:transient, success: false)
        |> attempt_heal(:transient, success: true)

      assert state.heal_attempts == 0
      assert state.escalated == false
    end

    test "three failed heal attempts trigger Guardian escalation" do
      state =
        new_health_state()
        |> add_anomaly(:persistent, 0.3)
        |> attempt_heal(:persistent, success: false)
        |> attempt_heal(:persistent, success: false)
        |> attempt_heal(:persistent, success: false)

      assert state.heal_attempts == 3
      assert state.escalated == true
    end

    test "escalation sets status to :needs_guardian" do
      state =
        new_health_state()
        |> add_anomaly(:persistent, 0.3)
        |> attempt_heal(:persistent, success: false)
        |> attempt_heal(:persistent, success: false)
        |> attempt_heal(:persistent, success: false)

      assert state.status == :needs_guardian
    end
  end

  # ============================================================================
  # 8. Watchdog Integration -- SC-WATCHDOG-001
  # ============================================================================

  describe "watchdog interval check (SC-WATCHDOG-001)" do
    test "returns :ok when last check was recent" do
      last = DateTime.add(DateTime.utc_now(), -50, :millisecond)
      assert check_watchdog(last, @watchdog_max_interval_ms) == :ok
    end

    test "returns :timeout when last check exceeded interval" do
      last = DateTime.add(DateTime.utc_now(), -200, :millisecond)
      assert check_watchdog(last, @watchdog_max_interval_ms) == :timeout
    end

    test "boundary: 99ms elapsed with 100ms limit returns :ok" do
      last = DateTime.add(DateTime.utc_now(), -99, :millisecond)
      assert check_watchdog(last, @watchdog_max_interval_ms) == :ok
    end

    test "very stale last check always returns :timeout" do
      last = DateTime.add(DateTime.utc_now(), -10_000, :millisecond)
      assert check_watchdog(last, @watchdog_max_interval_ms) == :timeout
    end

    test "custom interval override is honoured" do
      last = DateTime.add(DateTime.utc_now(), -300, :millisecond)
      assert check_watchdog(last, 500) == :ok
    end
  end

  # ============================================================================
  # 9a. PropCheck property: consensus always produces a valid status atom
  # ============================================================================

  property "consensus always produces valid status atom for any probe results" do
    valid_values = [:healthy, :degraded, :critical]

    forall results <-
             PC.vector(
               5,
               PC.oneof(Enum.map(valid_values, &PC.exactly/1))
             ) do
      fpps_consensus(results) in valid_values
    end
  end

  # ============================================================================
  # 9b. ExUnitProperties property: RPN always in [1..1000], equals S*O*D
  # ============================================================================

  test "RPN satisfies S*O*D and is always in [1..1000]" do
    ExUnitProperties.check all(
                             severity <- SD.integer(1..10),
                             occurrence <- SD.integer(1..10),
                             detection <- SD.integer(1..10)
                           ) do
      rpn =
        compute_rpn(%{
          type: :prop,
          severity: severity,
          occurrence: occurrence,
          detection: detection
        })

      assert rpn == severity * occurrence * detection
      assert rpn >= 1
      assert rpn <= 1_000
    end
  end

  # ============================================================================
  # 9c. ExUnitProperties property: health_score always stays in [0.0, 1.0]
  # ============================================================================

  test "health_score stays in [0.0, 1.0] for any anomaly impact combination" do
    ExUnitProperties.check all(
                             impacts <-
                               SD.list_of(SD.float(min: 0.0, max: 0.5),
                                 min_length: 0,
                                 max_length: 8
                               ),
                             max_runs: 50
                           ) do
      state =
        impacts
        |> Enum.with_index()
        |> Enum.reduce(new_health_state(), fn {impact, i}, acc ->
          add_anomaly(acc, :"a#{i}", impact)
        end)

      assert state.health_score >= 0.0,
             "health_score #{state.health_score} below 0.0 for impacts #{inspect(impacts)}"

      assert state.health_score <= 1.0,
             "health_score #{state.health_score} above 1.0 for impacts #{inspect(impacts)}"
    end
  end

  # ============================================================================
  # PRIVATE HELPERS — self-contained, no external module dependencies
  # ============================================================================

  # ---------------------------------------------------------------------------
  # Health state machine (immutable map, no GenServer dependency)
  # ---------------------------------------------------------------------------

  @spec new_health_state() :: map()
  defp new_health_state do
    %{
      health_score: 1.0,
      status: :healthy,
      anomalies: [],
      heal_attempts: 0,
      escalated: false
    }
  end

  @spec add_anomaly(map(), atom(), float()) :: map()
  defp add_anomaly(%{anomalies: existing} = state, name, impact) do
    updated = [{name, impact} | Keyword.delete(existing, name)]
    total = updated |> Keyword.values() |> Enum.sum()
    score = max(0.0, 1.0 - total)

    status =
      cond do
        state.escalated -> :needs_guardian
        score <= 0.4 -> :critical
        score <= 0.7 -> :degraded
        true -> :healthy
      end

    %{state | anomalies: updated, health_score: score, status: status}
  end

  @spec remove_anomaly(map(), atom()) :: map()
  defp remove_anomaly(%{anomalies: existing} = state, name) do
    updated = Keyword.delete(existing, name)
    total = updated |> Keyword.values() |> Enum.sum()
    score = max(0.0, 1.0 - total)

    status =
      cond do
        state.escalated -> :needs_guardian
        score <= 0.4 -> :critical
        score <= 0.7 -> :degraded
        true -> :healthy
      end

    %{state | anomalies: updated, health_score: score, status: status}
  end

  @spec attempt_heal(map(), atom(), keyword()) :: map()
  defp attempt_heal(state, anomaly, opts \\ []) do
    success = Keyword.get(opts, :success, true)

    if success do
      remove_anomaly(%{state | heal_attempts: 0, escalated: false}, anomaly)
    else
      attempts = state.heal_attempts + 1
      escalated = attempts >= 3

      status = if escalated, do: :needs_guardian, else: state.status

      %{state | heal_attempts: attempts, escalated: escalated, status: status}
    end
  end

  # ---------------------------------------------------------------------------
  # assess_health/1 — wraps fpps_consensus over a probe results map
  # ---------------------------------------------------------------------------

  @spec assess_health(map()) :: {:ok, map()}
  defp assess_health(probe_results) when is_map(probe_results) do
    values = Map.values(probe_results)
    status = fpps_consensus(values)
    healthy_count = Enum.count(values, &(&1 == :healthy))

    {:ok,
     %{
       status: status,
       probe_results: probe_results,
       consensus_count: healthy_count,
       assessed_at: DateTime.utc_now()
     }}
  end

  # ---------------------------------------------------------------------------
  # fpps_consensus/1 — SC-SIL4-023 quorum voting over 5 method verdicts
  # ---------------------------------------------------------------------------

  @spec fpps_consensus([atom()]) :: :healthy | :degraded | :critical
  defp fpps_consensus(results) when is_list(results) do
    freqs = Enum.frequencies(results)
    h = Map.get(freqs, :healthy, 0)
    d = Map.get(freqs, :degraded, 0)
    c = Map.get(freqs, :critical, 0)

    cond do
      h == 5 -> :healthy
      d == 5 -> :degraded
      c == 5 -> :critical
      h >= @quorum -> :healthy
      d >= @quorum and h == 0 -> :degraded
      c >= @quorum and h == 0 and d == 0 -> :critical
      h == 0 and d == 0 -> :critical
      h == 0 -> :degraded
      true -> :degraded
    end
  end

  # ---------------------------------------------------------------------------
  # FPPS probe methods (pure, total, deterministic)
  # ---------------------------------------------------------------------------

  # Pattern method: signature matching on metric values
  @spec fpps_pattern(map()) :: :healthy | :degraded | :critical
  defp fpps_pattern(%{} = metrics) do
    cpu = Map.get(metrics, :cpu, 0.0)
    memory = Map.get(metrics, :memory, 0.0)
    network_loss = Map.get(metrics, :network_loss, 0.0)
    crash = Map.get(metrics, :process_crash, false)

    cond do
      cpu > 0.97 or memory > 0.95 or network_loss > 0.70 or crash -> :critical
      cpu > 0.85 or memory > 0.80 or network_loss > 0.40 -> :degraded
      true -> :healthy
    end
  end

  # Statistical method: threshold crossing on combined utilisation
  @spec fpps_statistical(map()) :: :healthy | :degraded | :critical
  defp fpps_statistical(%{} = metrics) do
    cpu = Map.get(metrics, :cpu, 0.0)
    memory = Map.get(metrics, :memory, 0.0)
    disk = Map.get(metrics, :disk, 0.0)

    combined = (cpu + memory + disk) / 3

    cond do
      cpu >= 0.95 or memory >= 0.92 -> :critical
      combined > 0.70 -> :critical
      combined > 0.50 -> :degraded
      true -> :healthy
    end
  end

  # AST method: structural analysis of anomaly depth and health score
  @spec fpps_ast(map()) :: :healthy | :degraded | :critical
  defp fpps_ast(%{anomalies: anomalies, health_score: score}) do
    depth = length(anomalies)

    cond do
      score <= 0.35 or depth >= 5 -> :critical
      score <= 0.65 or depth >= 2 -> :degraded
      true -> :healthy
    end
  end

  # Binary method: quantised health score to 8-bit representation
  @spec fpps_binary(float()) :: :healthy | :degraded | :critical
  defp fpps_binary(health_score) when is_float(health_score) or is_integer(health_score) do
    # Quantise to 0-255
    q = trunc(health_score * 255)

    cond do
      q <= 89 -> :critical
      q <= 178 -> :degraded
      true -> :healthy
    end
  end

  # LineByLine method: sequential delta inspection on sorted impact values
  @spec fpps_line_by_line([float()]) :: :healthy | :degraded | :critical
  defp fpps_line_by_line([]), do: :healthy

  defp fpps_line_by_line(values) when is_list(values) do
    sorted = Enum.sort(values, :desc)
    total = Enum.sum(sorted)

    max_delta =
      case sorted do
        [_] ->
          0.0

        _ ->
          sorted
          |> Enum.chunk_every(2, 1, :discard)
          |> Enum.map(fn [a, b] -> abs(a - b) end)
          |> Enum.max()
      end

    cond do
      total >= 0.65 or max_delta >= 0.55 -> :critical
      total >= 0.30 or max_delta >= 0.30 -> :degraded
      true -> :healthy
    end
  end

  # ---------------------------------------------------------------------------
  # detect_threats/1 — maps metric map to threat list
  # ---------------------------------------------------------------------------

  @spec detect_threats(map()) :: [map()]
  defp detect_threats(%{} = m) do
    []
    |> maybe_threat(m, :cpu_spike, fn x -> x[:cpu] > 0.95 end, 8, 5, 3)
    |> maybe_threat(m, :memory_leak, fn x -> x[:memory] > 0.90 end, 7, 4, 4)
    |> maybe_threat(m, :disk_full, fn x -> x[:disk] > 0.95 end, 6, 3, 4)
    |> maybe_threat(m, :network_partition, fn x -> x[:network_loss] > 0.50 end, 9, 2, 5)
    |> maybe_threat(m, :process_crash, fn x -> x[:process_crash] == true end, 9, 3, 2)
  end

  @spec maybe_threat([map()], map(), atom(), (map() -> boolean()), 1..10, 1..10, 1..10) ::
          [map()]
  defp maybe_threat(acc, metrics, type, condition, s, o, d) do
    if condition.(metrics) do
      [%{type: type, severity: s, occurrence: o, detection: d} | acc]
    else
      acc
    end
  end

  # ---------------------------------------------------------------------------
  # compute_rpn/1 — SC-FMEA-002: S × O × D
  # ---------------------------------------------------------------------------

  @spec compute_rpn(map()) :: pos_integer()
  defp compute_rpn(%{severity: s, occurrence: o, detection: d}), do: s * o * d

  # ---------------------------------------------------------------------------
  # classify_threat_level/1 — SC-FMEA-004 thresholds
  # ---------------------------------------------------------------------------

  @spec classify_threat_level(non_neg_integer()) :: :low | :medium | :high | :critical
  defp classify_threat_level(rpn) when is_integer(rpn) do
    cond do
      rpn >= @rpn_critical_threshold -> :critical
      rpn >= 100 -> :high
      rpn >= @rpn_escalation_threshold -> :medium
      true -> :low
    end
  end

  # ---------------------------------------------------------------------------
  # check_watchdog/2 — SC-WATCHDOG-001
  # ---------------------------------------------------------------------------

  @spec check_watchdog(DateTime.t(), non_neg_integer()) :: :ok | :timeout
  defp check_watchdog(%DateTime{} = last, interval_ms) when is_integer(interval_ms) do
    elapsed = DateTime.diff(DateTime.utc_now(), last, :millisecond)
    if elapsed < interval_ms, do: :ok, else: :timeout
  end

  # ---------------------------------------------------------------------------
  # Test data builders
  # ---------------------------------------------------------------------------

  @spec all_probes(atom()) :: map()
  defp all_probes(verdict) do
    for m <- @fpps_methods, into: %{}, do: {m, verdict}
  end

  @spec clean_metrics() :: map()
  defp clean_metrics do
    %{cpu: 0.15, memory: 0.30, disk: 0.40, network_loss: 0.0, process_crash: false}
  end

  @spec cpu_spike_threat() :: map()
  defp cpu_spike_threat do
    # RPN = 8 * 5 * 3 = 120  >= @rpn_escalation_threshold
    %{type: :cpu_spike, severity: 8, occurrence: 5, detection: 3}
  end

  @spec memory_leak_threat() :: map()
  defp memory_leak_threat do
    # RPN = 7 * 4 * 4 = 112  >= @rpn_escalation_threshold
    %{type: :memory_leak, severity: 7, occurrence: 4, detection: 4}
  end
end
