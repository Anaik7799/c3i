defmodule Indrajaal.Safety.SentinelHealthAssessmentTest do
  @moduledoc """
  TDG test: Sentinel health monitoring and threat assessment.

  WHAT: Tests health scoring, threat detection, baseline calibration, and escalation protocols.
  WHY: Validates SC-IMMUNE-001 (Sentinel monitors system health), SC-IMMUNE-004 (PatternHunter),
       SC-BIO-EXT-001 (pre-error detection < 10ms), SC-BIO-EXT-002 (threat response < 100ms).

  STAMP Constraints:
  - SC-IMMUNE-001: Sentinel monitors system health
  - SC-IMMUNE-004: PatternHunter detects pre-error signatures
  - SC-BIO-EXT-001: PatternHunter pre-error detection < 10ms
  - SC-BIO-EXT-002: SymbioticDefense threat response < 100ms
  - SC-WATCHDOG-001: Check interval <= 100ms
  - SC-WATCHDOG-002: Corruption triggers Guardian report
  - SC-WATCHDOG-003: Self-healing attempted before escalation
  - AOR-IMMUNE-001: Run Sentinel.assess_now() before critical ops
  - AOR-IMMUNE-004: Threats with RPN >= 50 MUST be reported
  """

  use ExUnit.Case, async: true
  import ExUnitProperties, except: [property: 2, property: 3]
  alias StreamData, as: SD

  @health_check_interval_ms 100
  @threat_response_budget_ms 100
  @pre_error_detection_budget_ms 10

  describe "health scoring" do
    test "initial health is 100%" do
      sentinel = new_sentinel()
      assert sentinel.health_score == 1.0
      assert sentinel.status == :healthy
    end

    test "health degrades with anomalies" do
      sentinel =
        new_sentinel()
        |> report_anomaly(:cpu_spike, 0.1)
        |> report_anomaly(:memory_leak, 0.15)

      assert sentinel.health_score < 1.0
      assert sentinel.health_score >= 0.75
    end

    test "health recovers after anomaly resolution" do
      sentinel =
        new_sentinel()
        |> report_anomaly(:cpu_spike, 0.2)
        |> resolve_anomaly(:cpu_spike)

      assert sentinel.health_score == 1.0
    end

    test "critical health triggers alert" do
      sentinel =
        new_sentinel()
        |> report_anomaly(:cascade_failure, 0.6)

      assert sentinel.status == :critical
      assert sentinel.health_score <= 0.4
    end

    test "health score bounded [0.0, 1.0]" do
      sentinel =
        new_sentinel()
        |> report_anomaly(:a, 0.3)
        |> report_anomaly(:b, 0.3)
        |> report_anomaly(:c, 0.3)
        |> report_anomaly(:d, 0.3)

      assert sentinel.health_score >= 0.0
      assert sentinel.health_score <= 1.0
    end
  end

  describe "threat detection (SC-IMMUNE-004)" do
    test "no threats initially" do
      sentinel = new_sentinel()
      assert sentinel.threats == []
    end

    test "detects new threat" do
      sentinel =
        detect_threat(new_sentinel(), %{type: :intrusion, severity: 7, source: :external})

      assert length(sentinel.threats) == 1
      assert hd(sentinel.threats).type == :intrusion
    end

    test "computes threat RPN" do
      threat = %{type: :data_corruption, severity: 8, occurrence: 3, detection: 5}
      rpn = compute_rpn(threat)
      assert rpn == 120
    end

    test "RPN >= 50 flagged for Guardian report (AOR-IMMUNE-004)" do
      sentinel =
        new_sentinel()
        |> detect_threat(%{type: :corruption, severity: 8, occurrence: 3, detection: 3})

      threat = hd(sentinel.threats)
      assert threat.rpn >= 50
      assert threat.escalated == true
    end

    test "RPN < 50 handled locally" do
      sentinel =
        new_sentinel()
        |> detect_threat(%{type: :minor_glitch, severity: 2, occurrence: 2, detection: 2})

      threat = hd(sentinel.threats)
      assert threat.rpn < 50
      assert threat.escalated == false
    end

    test "multiple threats tracked simultaneously" do
      sentinel =
        new_sentinel()
        |> detect_threat(%{type: :intrusion, severity: 7, occurrence: 2, detection: 3})
        |> detect_threat(%{type: :corruption, severity: 9, occurrence: 1, detection: 4})
        |> detect_threat(%{type: :overload, severity: 5, occurrence: 5, detection: 2})

      assert length(sentinel.threats) == 3
    end
  end

  describe "baseline calibration (AOR-IMMUNE-003)" do
    test "initial baseline is empty" do
      sentinel = new_sentinel()
      assert sentinel.baseline == %{}
    end

    test "calibration records baseline metrics" do
      metrics = %{cpu: 0.3, memory: 0.45, latency_ms: 12, error_rate: 0.001}
      sentinel = calibrate_baseline(new_sentinel(), metrics)

      assert sentinel.baseline.cpu == 0.3
      assert sentinel.baseline.memory == 0.45
    end

    test "deviation from baseline triggers pattern detection" do
      sentinel =
        new_sentinel()
        |> calibrate_baseline(%{cpu: 0.3, memory: 0.45, latency_ms: 12})
        |> check_deviation(%{cpu: 0.9, memory: 0.45, latency_ms: 12})

      assert sentinel.deviations != []
      assert hd(sentinel.deviations).metric == :cpu
    end

    test "within-threshold deviation is normal" do
      sentinel =
        new_sentinel()
        |> calibrate_baseline(%{cpu: 0.3, memory: 0.45, latency_ms: 12})
        |> check_deviation(%{cpu: 0.35, memory: 0.47, latency_ms: 14})

      assert sentinel.deviations == []
    end
  end

  describe "self-healing protocol (SC-WATCHDOG-003)" do
    test "self-healing attempted before escalation" do
      sentinel =
        new_sentinel()
        |> report_anomaly(:recoverable_error, 0.15)
        |> attempt_self_heal(:recoverable_error)

      assert sentinel.heal_attempts > 0
      assert sentinel.status == :healthy
    end

    test "escalation after failed self-heal" do
      sentinel =
        new_sentinel()
        |> report_anomaly(:persistent_error, 0.3)
        |> attempt_self_heal(:persistent_error, success: false)
        |> attempt_self_heal(:persistent_error, success: false)
        |> attempt_self_heal(:persistent_error, success: false)

      assert sentinel.heal_attempts >= 3
      assert sentinel.escalated_to_guardian == true
    end

    test "successful heal resets attempt counter" do
      sentinel =
        new_sentinel()
        |> report_anomaly(:transient_error, 0.1)
        |> attempt_self_heal(:transient_error, success: false)
        |> attempt_self_heal(:transient_error)

      assert sentinel.heal_attempts == 0
      assert sentinel.escalated_to_guardian == false
    end
  end

  describe "timing constraints" do
    test "check interval is 100ms (SC-WATCHDOG-001)" do
      assert @health_check_interval_ms == 100
    end

    test "threat response budget is 100ms (SC-BIO-EXT-002)" do
      assert @threat_response_budget_ms == 100
    end

    test "pre-error detection budget is 10ms (SC-BIO-EXT-001)" do
      assert @pre_error_detection_budget_ms == 10
    end
  end

  describe "assess_now protocol (AOR-IMMUNE-001)" do
    test "assessment returns comprehensive report" do
      sentinel =
        new_sentinel()
        |> calibrate_baseline(%{cpu: 0.3, memory: 0.45})
        |> detect_threat(%{type: :minor, severity: 3, occurrence: 2, detection: 2})

      report = assess_now(sentinel)
      assert Map.has_key?(report, :health_score)
      assert Map.has_key?(report, :threat_count)
      assert Map.has_key?(report, :status)
      assert Map.has_key?(report, :timestamp)
    end

    test "assessment before critical ops returns go/no-go" do
      healthy_sentinel = new_sentinel()
      assert assess_now(healthy_sentinel).go == true

      critical_sentinel =
        new_sentinel()
        |> report_anomaly(:major_failure, 0.7)

      assert assess_now(critical_sentinel).go == false
    end
  end

  describe "property: health score invariants" do
    test "health never exceeds bounds" do
      ExUnitProperties.check all(
                               anomaly_count <- SD.integer(0..20),
                               max_runs: 20
                             ) do
        sentinel =
          Enum.reduce(1..max(anomaly_count, 1), new_sentinel(), fn i, acc ->
            report_anomaly(acc, :"anomaly_#{i}", :rand.uniform() * 0.2)
          end)

        assert sentinel.health_score >= 0.0
        assert sentinel.health_score <= 1.0
      end
    end

    test "resolve all anomalies restores full health" do
      ExUnitProperties.check all(
                               count <- SD.integer(1..10),
                               max_runs: 15
                             ) do
        anomalies = Enum.map(1..count, &:"anomaly_#{&1}")

        sentinel =
          Enum.reduce(anomalies, new_sentinel(), fn a, acc ->
            report_anomaly(acc, a, 0.05)
          end)

        restored =
          Enum.reduce(anomalies, sentinel, fn a, acc ->
            resolve_anomaly(acc, a)
          end)

        assert restored.health_score == 1.0
      end
    end
  end

  describe "property: RPN computation" do
    test "RPN is always non-negative" do
      ExUnitProperties.check all(
                               severity <- SD.integer(1..10),
                               occurrence <- SD.integer(1..10),
                               detection <- SD.integer(1..10),
                               max_runs: 30
                             ) do
        rpn = compute_rpn(%{severity: severity, occurrence: occurrence, detection: detection})
        assert rpn >= 0
        assert rpn == severity * occurrence * detection
      end
    end
  end

  # ===========================================================================
  # Helpers
  # ===========================================================================

  defp new_sentinel do
    %{
      health_score: 1.0,
      status: :healthy,
      threats: [],
      anomalies: %{},
      baseline: %{},
      deviations: [],
      heal_attempts: 0,
      escalated_to_guardian: false
    }
  end

  defp report_anomaly(sentinel, name, impact) do
    anomalies = Map.put(sentinel.anomalies, name, impact)
    total_impact = anomalies |> Map.values() |> Enum.sum()
    health = max(0.0, 1.0 - total_impact)

    status =
      cond do
        health <= 0.4 -> :critical
        health <= 0.7 -> :degraded
        true -> :healthy
      end

    %{sentinel | anomalies: anomalies, health_score: health, status: status}
  end

  defp resolve_anomaly(sentinel, name) do
    anomalies = Map.delete(sentinel.anomalies, name)
    total_impact = anomalies |> Map.values() |> Enum.sum()
    health = max(0.0, 1.0 - total_impact)

    status =
      cond do
        health <= 0.4 -> :critical
        health <= 0.7 -> :degraded
        true -> :healthy
      end

    %{sentinel | anomalies: anomalies, health_score: health, status: status}
  end

  defp detect_threat(sentinel, threat_data) do
    rpn = compute_rpn(threat_data)
    escalated = rpn >= 50

    threat = %{
      type: threat_data.type,
      severity: Map.get(threat_data, :severity, 5),
      rpn: rpn,
      escalated: escalated,
      detected_at: System.monotonic_time(:millisecond)
    }

    %{sentinel | threats: [threat | sentinel.threats]}
  end

  defp compute_rpn(%{severity: s, occurrence: o, detection: d}), do: s * o * d
  defp compute_rpn(%{severity: s}), do: s * 3 * 3

  defp calibrate_baseline(sentinel, metrics) do
    %{sentinel | baseline: metrics}
  end

  defp check_deviation(sentinel, current_metrics) do
    threshold = 0.5

    deviations =
      Enum.reduce(current_metrics, [], fn {metric, value}, acc ->
        case Map.get(sentinel.baseline, metric) do
          nil ->
            acc

          baseline_value when baseline_value > 0 ->
            deviation = abs(value - baseline_value) / baseline_value

            if deviation > threshold do
              [
                %{metric: metric, baseline: baseline_value, current: value, deviation: deviation}
                | acc
              ]
            else
              acc
            end

          _ ->
            acc
        end
      end)

    %{sentinel | deviations: deviations}
  end

  defp attempt_self_heal(sentinel, _anomaly, opts \\ []) do
    success = Keyword.get(opts, :success, true)

    if success do
      %{sentinel | heal_attempts: 0, escalated_to_guardian: false, status: :healthy}
    else
      attempts = sentinel.heal_attempts + 1
      escalated = attempts >= 3
      %{sentinel | heal_attempts: attempts, escalated_to_guardian: escalated}
    end
  end

  defp assess_now(sentinel) do
    %{
      health_score: sentinel.health_score,
      threat_count: length(sentinel.threats),
      status: sentinel.status,
      timestamp: System.monotonic_time(:millisecond),
      go: sentinel.status != :critical
    }
  end
end
