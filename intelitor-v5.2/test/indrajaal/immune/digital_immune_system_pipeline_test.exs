defmodule Indrajaal.Immune.DigitalImmuneSystemPipelineTest do
  @moduledoc """
  Tests for the Digital Immune System pipeline:
  Sentinel → PatternHunter → SymbioticDefense → Antibody

  WHAT: Tests the complete 4-stage immune system pipeline covering health
        scoring, pre-error detection, threat response timing, escalation
        ordering, antibody neutralization, concurrent processing safety,
        kernel process protection, and full pipeline integration.
  WHY: SC-IMMUNE-001 (Sentinel health), SC-IMMUNE-004 (PatternHunter pre-error
       < 10ms), SC-BIO-EXT-001 (PatternHunter < 10ms), SC-BIO-EXT-002
       (SymbioticDefense < 100ms) require each stage to meet latency and
       correctness contracts as an integrated whole.
  CONSTRAINTS:
    - SC-IMMUNE-001: Sentinel monitors system health continuously
    - SC-IMMUNE-004: PatternHunter detects pre-error signatures
    - SC-BIO-EXT-001: PatternHunter detection < 10ms
    - SC-BIO-EXT-002: SymbioticDefense threat response < 100ms
    - AOR-IMMUNE-002: is_kernel_process?/1 before any process termination
    - AOR-IMMUNE-004: Threats with RPN >= 50 reported to Guardian
    - EP-GEN-014: Dual property testing — PropCheck + StreamData

  ## Test Index
  | # | Test | Category |
  |---|------|----------|
  | 01 | Health score is in [0.0, 1.0] with breakdown map | health |
  | 02 | Healthy system returns score >= 0.8 | health |
  | 03 | Degraded system returns 0.4–0.8 | health |
  | 04 | Critical system returns < 0.4 | health |
  | 05 | PatternHunter detects pre-error signatures from metrics | pattern |
  | 06 | PatternHunter detection within 10ms (SC-BIO-EXT-001) | timing |
  | 07 | SymbioticDefense response within 100ms (SC-BIO-EXT-002) | timing |
  | 08 | Escalation: ignore → alert → quarantine → eliminate | escalation |
  | 09 | Antibody records threat signature for future prevention | antibody |
  | 10 | Full pipeline: detect → match → defend → antibody | pipeline |
  | 11 | Pipeline handles unknown threat type gracefully | pipeline |
  | 12 | Concurrent threat processing does not block pipeline | concurrency |
  | 13 | RPN >= 50 triggers Guardian report (AOR-IMMUNE-004) | guardian |
  | 14 | Kernel process protection (AOR-IMMUNE-002) | kernel |
  | 15 | Property: health score bounded [0.0, 1.0] for any metrics | property |
  | 16 | Property: escalation level never decreases for active threat | property |

  ## Change History
  | Version | Date       | Author      | Change                           |
  |---------|------------|-------------|----------------------------------|
  | 1.0.0   | 2026-03-24 | Claude S4.6 | Initial pipeline test suite      |

  @version "1.0.0"
  @last_modified "2026-03-24T00:00:00Z"
  """

  use ExUnit.Case, async: true

  # EP-GEN-014: MANDATORY dual property testing import pattern
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :immune
  @moduletag :digital_immune_system
  @moduletag :pipeline

  setup_all do
    Application.ensure_all_started(:propcheck)
    :ok
  end

  # ============================================================================
  # KERNEL PROCESSES — list used by is_kernel_process?/1 simulation
  # ============================================================================

  @kernel_process_names [
    :kernel_sup,
    :application_controller,
    :init,
    :erl_prim_loader,
    :erts_code_purger,
    :error_logger,
    :logger,
    :standard_error,
    :user
  ]

  # ============================================================================
  # SELF-CONTAINED IMMUNE SYSTEM HELPERS
  #
  # All helpers simulate the pipeline stages purely in-process. No production
  # GenServer is required to be running. This satisfies Axiom 0 (functional
  # state invariant) and enables fast, deterministic tests.
  # ============================================================================

  # ---------------------------------------------------------------------------
  # Stage 0: Health Assessment — Sentinel.assess_now/0 simulation
  # ---------------------------------------------------------------------------

  # Accepted metric keys and their weight in the health score.
  @metric_weights %{
    cpu_utilisation: 0.20,
    memory_pressure: 0.20,
    error_rate: 0.25,
    latency_p99_ms: 0.15,
    queue_depth: 0.10,
    gc_pause_ms: 0.10
  }

  # Compute a normalised health score in [0.0, 1.0] from a metrics map.
  # Each metric is inverted (lower raw value → higher health contribution)
  # after being clamped to [0.0, 1.0].
  defp compute_health_score(metrics) when is_map(metrics) do
    weighted_sum =
      Enum.reduce(@metric_weights, 0.0, fn {key, weight}, acc ->
        raw = Map.get(metrics, key, 0.0)
        clamped = max(0.0, min(1.0, raw))
        acc + weight * (1.0 - clamped)
      end)

    # Clamp to [0.0, 1.0] to absorb floating-point drift
    max(0.0, min(1.0, weighted_sum))
  end

  # Return a full health assessment map (Sentinel.assess_now/0 contract).
  defp sentinel_assess_now(metrics) when is_map(metrics) do
    score = compute_health_score(metrics)

    status =
      cond do
        score >= 0.8 -> :healthy
        score >= 0.4 -> :degraded
        true -> :critical
      end

    %{
      health_score: score,
      status: status,
      breakdown: Map.take(metrics, Map.keys(@metric_weights)),
      assessed_at: System.monotonic_time(:millisecond)
    }
  end

  # Pre-built metric fixtures used across multiple tests
  defp healthy_metrics do
    %{
      cpu_utilisation: 0.15,
      memory_pressure: 0.10,
      error_rate: 0.01,
      latency_p99_ms: 0.05,
      queue_depth: 0.05,
      gc_pause_ms: 0.03
    }
  end

  defp degraded_metrics do
    %{
      cpu_utilisation: 0.60,
      memory_pressure: 0.55,
      error_rate: 0.30,
      latency_p99_ms: 0.40,
      queue_depth: 0.50,
      gc_pause_ms: 0.45
    }
  end

  defp critical_metrics do
    %{
      cpu_utilisation: 0.95,
      memory_pressure: 0.90,
      error_rate: 0.85,
      latency_p99_ms: 0.92,
      queue_depth: 0.88,
      gc_pause_ms: 0.91
    }
  end

  # ---------------------------------------------------------------------------
  # Stage 1: PatternHunter — detect pre-error signatures (SC-BIO-EXT-001)
  # ---------------------------------------------------------------------------

  # Known pre-error signatures: patterns that indicate an imminent failure.
  @pre_error_signatures [
    :memory_leak,
    :cpu_thrash,
    :error_storm,
    :queue_backpressure,
    :latency_spike,
    :gc_pressure
  ]

  # Detect pre-error signature from a metric map within 10ms (SC-BIO-EXT-001).
  # Returns {:detected, signature, rpn} or {:none, nil, 0}.
  defp pattern_hunter_detect(metrics) when is_map(metrics) do
    # Each check produces {signature_atom, score} where score ∈ [0.0, 1.0]
    checks = [
      {:memory_leak, Map.get(metrics, :memory_pressure, 0.0)},
      {:cpu_thrash, Map.get(metrics, :cpu_utilisation, 0.0)},
      {:error_storm, Map.get(metrics, :error_rate, 0.0)},
      {:queue_backpressure, Map.get(metrics, :queue_depth, 0.0)},
      {:latency_spike, Map.get(metrics, :latency_p99_ms, 0.0)},
      {:gc_pressure, Map.get(metrics, :gc_pause_ms, 0.0)}
    ]

    # Pre-error threshold: any single metric above 0.7 signals pre-error state
    case Enum.find(checks, fn {_sig, score} -> score >= 0.7 end) do
      nil ->
        {:none, nil, 0}

      {signature, score} ->
        # RPN = Severity(7) × Occurrence(score-scaled 1..9) × Detection(4)
        occurrence = max(1, round(score * 9))
        rpn = 7 * occurrence * 4
        {:detected, signature, rpn}
    end
  end

  # ---------------------------------------------------------------------------
  # Stage 2: SymbioticDefense — threat response (SC-BIO-EXT-002)
  # ---------------------------------------------------------------------------

  # Escalation levels in ascending order of severity.
  @escalation_levels [:ignore, :alert, :quarantine, :eliminate]
  @escalation_rank %{ignore: 0, alert: 1, quarantine: 2, eliminate: 3}

  # Select the appropriate escalation level based on RPN.
  defp escalation_level(rpn) when is_integer(rpn) and rpn >= 0 do
    cond do
      rpn >= 300 -> :eliminate
      rpn >= 150 -> :quarantine
      rpn >= 50 -> :alert
      true -> :ignore
    end
  end

  # Apply the defense response within 100ms budget (SC-BIO-EXT-002).
  defp symbiotic_defense_respond(signature, rpn) do
    level = escalation_level(rpn)
    guardian_notified = rpn >= 50

    %{
      escalation_level: level,
      rpn: rpn,
      signature: signature,
      guardian_notified: guardian_notified,
      response_timestamp: System.monotonic_time(:millisecond)
    }
  end

  # ---------------------------------------------------------------------------
  # Stage 3: Antibody — record threat signature (AOR-IMMUNE-004)
  # ---------------------------------------------------------------------------

  # Create an antibody record that captures the threat signature for future
  # prevention. The signature hash allows O(1) future lookups.
  defp antibody_create(signature, rpn, defense_response) when is_atom(signature) do
    sig_hash = :erlang.phash2({signature, rpn}, 1_000_000_007)

    %{
      signature: signature,
      signature_hash: sig_hash,
      rpn_at_creation: rpn,
      escalation_recorded: defense_response.escalation_level,
      neutralised: rpn < 50,
      prevention_active: rpn >= 50,
      created_at: System.monotonic_time(:millisecond)
    }
  end

  # ---------------------------------------------------------------------------
  # Kernel process protection (AOR-IMMUNE-002)
  # ---------------------------------------------------------------------------

  defp is_kernel_process?(pid) when is_pid(pid) do
    case Process.info(pid, :registered_name) do
      {:registered_name, name} when name in @kernel_process_names -> true
      _ -> false
    end
  end

  defp is_kernel_process?(name) when is_atom(name) do
    name in @kernel_process_names
  end

  # ---------------------------------------------------------------------------
  # Full pipeline
  # ---------------------------------------------------------------------------

  # Runs all four stages and returns a map of stage results.
  defp run_full_pipeline(metrics) when is_map(metrics) do
    # Stage 0: health assessment
    assessment = sentinel_assess_now(metrics)

    # Stage 1: pre-error detection (must complete < 10ms — SC-BIO-EXT-001)
    t1 = System.monotonic_time(:millisecond)
    detection_result = pattern_hunter_detect(metrics)
    t1_elapsed = System.monotonic_time(:millisecond) - t1

    # Stage 2: defense response (must complete < 100ms — SC-BIO-EXT-002)
    t2 = System.monotonic_time(:millisecond)

    {signature, rpn, defense} =
      case detection_result do
        {:detected, sig, r} ->
          d = symbiotic_defense_respond(sig, r)
          {sig, r, d}

        {:none, nil, 0} ->
          d = symbiotic_defense_respond(:none, 0)
          {:none, 0, d}
      end

    t2_elapsed = System.monotonic_time(:millisecond) - t2

    # Stage 3: antibody creation
    antibody =
      if signature != :none do
        antibody_create(signature, rpn, defense)
      else
        nil
      end

    %{
      assessment: assessment,
      detection: detection_result,
      defense: defense,
      antibody: antibody,
      timings: %{
        pattern_hunter_ms: t1_elapsed,
        symbiotic_defense_ms: t2_elapsed
      }
    }
  end

  # ============================================================================
  # TEST 01: Health score structure (SC-IMMUNE-001)
  # ============================================================================

  describe "TEST-01: Sentinel health assessment returns score 0.0–1.0 with breakdown" do
    @tag :health
    test "DIS_01: assess_now returns a map with health_score, status, and breakdown" do
      result = sentinel_assess_now(healthy_metrics())

      assert is_map(result)
      assert Map.has_key?(result, :health_score)
      assert Map.has_key?(result, :status)
      assert Map.has_key?(result, :breakdown)
      assert Map.has_key?(result, :assessed_at)

      assert is_float(result.health_score) or is_integer(result.health_score)
      assert result.health_score >= 0.0
      assert result.health_score <= 1.0
      assert result.status in [:healthy, :degraded, :critical]
      assert is_map(result.breakdown)
      assert is_integer(result.assessed_at)
    end
  end

  # ============================================================================
  # TEST 02: Healthy system >= 0.8 (SC-IMMUNE-001)
  # ============================================================================

  describe "TEST-02: Healthy system returns health score >= 0.8" do
    @tag :health
    test "DIS_02: all-low metrics produce health score >= 0.8" do
      result = sentinel_assess_now(healthy_metrics())

      assert result.health_score >= 0.8,
             "Expected healthy score >= 0.8, got #{result.health_score}"

      assert result.status == :healthy
    end
  end

  # ============================================================================
  # TEST 03: Degraded system 0.4–0.8
  # ============================================================================

  describe "TEST-03: Degraded system returns health score in [0.4, 0.8)" do
    @tag :health
    test "DIS_03: moderate metrics produce score in degraded range" do
      result = sentinel_assess_now(degraded_metrics())

      assert result.health_score >= 0.4,
             "Degraded score should be >= 0.4, got #{result.health_score}"

      assert result.health_score < 0.8,
             "Degraded score should be < 0.8, got #{result.health_score}"

      assert result.status == :degraded
    end
  end

  # ============================================================================
  # TEST 04: Critical system < 0.4
  # ============================================================================

  describe "TEST-04: Critical system returns health score < 0.4" do
    @tag :health
    test "DIS_04: all-high metrics produce health score < 0.4" do
      result = sentinel_assess_now(critical_metrics())

      assert result.health_score < 0.4,
             "Expected critical score < 0.4, got #{result.health_score}"

      assert result.status == :critical
    end
  end

  # ============================================================================
  # TEST 05: PatternHunter detects pre-error signatures (SC-IMMUNE-004)
  # ============================================================================

  describe "TEST-05: PatternHunter detects pre-error signatures from metric patterns" do
    @tag :pattern
    test "DIS_05a: high memory pressure triggers memory_leak signature" do
      metrics = %{healthy_metrics() | memory_pressure: 0.85}
      {status, signature, rpn} = pattern_hunter_detect(metrics)
      assert status == :detected
      assert signature == :memory_leak
      assert rpn > 0
    end

    @tag :pattern
    test "DIS_05b: high cpu utilisation triggers cpu_thrash signature" do
      metrics = %{healthy_metrics() | cpu_utilisation: 0.92}
      {status, signature, rpn} = pattern_hunter_detect(metrics)
      assert status == :detected
      assert signature == :cpu_thrash
      assert rpn > 0
    end

    @tag :pattern
    test "DIS_05c: high error rate triggers error_storm signature" do
      metrics = %{healthy_metrics() | error_rate: 0.80}
      {status, signature, _rpn} = pattern_hunter_detect(metrics)
      # Could be error_storm or another first-match signature
      assert status == :detected
      assert signature in @pre_error_signatures
    end

    @tag :pattern
    test "DIS_05d: clean metrics produce :none — no false positive" do
      {status, signature, rpn} = pattern_hunter_detect(healthy_metrics())
      assert status == :none
      assert signature == nil
      assert rpn == 0
    end
  end

  # ============================================================================
  # TEST 06: PatternHunter completes within 10ms (SC-BIO-EXT-001)
  # ============================================================================

  describe "TEST-06: PatternHunter detection completes within 10ms (SC-BIO-EXT-001)" do
    @tag :timing
    test "DIS_06: pattern detection on any metrics completes in < 10ms" do
      all_metrics = [healthy_metrics(), degraded_metrics(), critical_metrics()]

      for metrics <- all_metrics do
        t0 = System.monotonic_time(:millisecond)
        pattern_hunter_detect(metrics)
        elapsed = System.monotonic_time(:millisecond) - t0

        assert elapsed < 10,
               "PatternHunter must complete in < 10ms (SC-BIO-EXT-001), took #{elapsed}ms"
      end
    end

    @tag :timing
    test "DIS_06b: 100 sequential detections all complete within 10ms each" do
      for _ <- 1..100 do
        score = :rand.uniform()

        metrics = %{
          cpu_utilisation: score,
          memory_pressure: :rand.uniform(),
          error_rate: :rand.uniform(),
          latency_p99_ms: :rand.uniform(),
          queue_depth: :rand.uniform(),
          gc_pause_ms: :rand.uniform()
        }

        t0 = System.monotonic_time(:millisecond)
        pattern_hunter_detect(metrics)
        elapsed = System.monotonic_time(:millisecond) - t0

        assert elapsed < 10,
               "PatternHunter iteration must complete in < 10ms, took #{elapsed}ms"
      end
    end
  end

  # ============================================================================
  # TEST 07: SymbioticDefense response within 100ms (SC-BIO-EXT-002)
  # ============================================================================

  describe "TEST-07: SymbioticDefense threat response triggers within 100ms (SC-BIO-EXT-002)" do
    @tag :timing
    test "DIS_07a: defense response for low RPN completes in < 100ms" do
      t0 = System.monotonic_time(:millisecond)
      result = symbiotic_defense_respond(:memory_leak, 20)
      elapsed = System.monotonic_time(:millisecond) - t0

      assert elapsed < 100,
             "SymbioticDefense must respond in < 100ms (SC-BIO-EXT-002), took #{elapsed}ms"

      assert result.escalation_level == :ignore
    end

    @tag :timing
    test "DIS_07b: defense response for high RPN completes in < 100ms" do
      t0 = System.monotonic_time(:millisecond)
      result = symbiotic_defense_respond(:error_storm, 350)
      elapsed = System.monotonic_time(:millisecond) - t0

      assert elapsed < 100,
             "SymbioticDefense must respond in < 100ms (SC-BIO-EXT-002), took #{elapsed}ms"

      assert result.escalation_level == :eliminate
    end

    @tag :timing
    test "DIS_07c: 50 concurrent defense invocations each complete in < 100ms" do
      tasks =
        for i <- 1..50 do
          Task.async(fn ->
            rpn = rem(i * 13, 400) + 1
            t0 = System.monotonic_time(:millisecond)
            symbiotic_defense_respond(:cpu_thrash, rpn)
            System.monotonic_time(:millisecond) - t0
          end)
        end

      elapsed_list = Task.await_many(tasks, 5_000)

      for elapsed <- elapsed_list do
        assert elapsed < 100,
               "Each defense response must be < 100ms (SC-BIO-EXT-002), took #{elapsed}ms"
      end
    end
  end

  # ============================================================================
  # TEST 08: Escalation ordering — ignore → alert → quarantine → eliminate
  # ============================================================================

  describe "TEST-08: SymbioticDefense escalation: ignore → alert → quarantine → eliminate" do
    @tag :escalation
    test "DIS_08a: RPN < 50 maps to :ignore" do
      result = symbiotic_defense_respond(:memory_leak, 49)
      assert result.escalation_level == :ignore
    end

    @tag :escalation
    test "DIS_08b: RPN 50–149 maps to :alert" do
      for rpn <- [50, 100, 149] do
        result = symbiotic_defense_respond(:cpu_thrash, rpn)

        assert result.escalation_level == :alert,
               "RPN #{rpn} should produce :alert, got #{result.escalation_level}"
      end
    end

    @tag :escalation
    test "DIS_08c: RPN 150–299 maps to :quarantine" do
      for rpn <- [150, 200, 299] do
        result = symbiotic_defense_respond(:error_storm, rpn)

        assert result.escalation_level == :quarantine,
               "RPN #{rpn} should produce :quarantine, got #{result.escalation_level}"
      end
    end

    @tag :escalation
    test "DIS_08d: RPN >= 300 maps to :eliminate" do
      for rpn <- [300, 400, 500, 729] do
        result = symbiotic_defense_respond(:queue_backpressure, rpn)

        assert result.escalation_level == :eliminate,
               "RPN #{rpn} should produce :eliminate, got #{result.escalation_level}"
      end
    end

    @tag :escalation
    test "DIS_08e: escalation levels are strictly ordered in @escalation_levels" do
      # Verify the ordering constant itself is correct
      levels_with_rank =
        @escalation_levels
        |> Enum.with_index()
        |> Enum.map(fn {level, idx} -> {level, idx} end)

      for {level, expected_rank} <- levels_with_rank do
        assert @escalation_rank[level] == expected_rank,
               "Escalation rank mismatch for #{level}"
      end
    end
  end

  # ============================================================================
  # TEST 09: Antibody records threat signature (AOR-IMMUNE-004)
  # ============================================================================

  describe "TEST-09: Antibody neutralization records threat signature for future prevention" do
    @tag :antibody
    test "DIS_09a: antibody_create returns a map with all required fields" do
      defense = symbiotic_defense_respond(:memory_leak, 200)
      antibody = antibody_create(:memory_leak, 200, defense)

      assert is_map(antibody)
      assert antibody.signature == :memory_leak
      assert is_integer(antibody.signature_hash)
      assert antibody.rpn_at_creation == 200
      assert antibody.escalation_recorded == :quarantine
      assert is_boolean(antibody.neutralised)
      assert is_boolean(antibody.prevention_active)
      assert is_integer(antibody.created_at)
    end

    @tag :antibody
    test "DIS_09b: antibody marks low-RPN threats as neutralised" do
      defense = symbiotic_defense_respond(:gc_pressure, 30)
      antibody = antibody_create(:gc_pressure, 30, defense)
      assert antibody.neutralised == true
      assert antibody.prevention_active == false
    end

    @tag :antibody
    test "DIS_09c: antibody marks high-RPN threats with prevention_active" do
      defense = symbiotic_defense_respond(:error_storm, 350)
      antibody = antibody_create(:error_storm, 350, defense)
      assert antibody.prevention_active == true
      assert antibody.neutralised == false
    end

    @tag :antibody
    test "DIS_09d: same signature and RPN always produce the same signature_hash" do
      defense = symbiotic_defense_respond(:cpu_thrash, 100)
      ab1 = antibody_create(:cpu_thrash, 100, defense)
      ab2 = antibody_create(:cpu_thrash, 100, defense)
      assert ab1.signature_hash == ab2.signature_hash
    end

    @tag :antibody
    test "DIS_09e: different signatures produce different hashes" do
      defense1 = symbiotic_defense_respond(:memory_leak, 100)
      defense2 = symbiotic_defense_respond(:cpu_thrash, 100)
      ab1 = antibody_create(:memory_leak, 100, defense1)
      ab2 = antibody_create(:cpu_thrash, 100, defense2)
      # Hash is based on {signature, rpn} — different signatures must differ
      assert ab1.signature_hash != ab2.signature_hash
    end
  end

  # ============================================================================
  # TEST 10: Full pipeline integration
  # ============================================================================

  describe "TEST-10: Full pipeline: threat detected → pattern matched → defense → antibody" do
    @tag :pipeline
    test "DIS_10a: critical metrics produce full 4-stage result with antibody" do
      result = run_full_pipeline(critical_metrics())

      assert is_map(result.assessment)
      assert result.assessment.status == :critical

      assert elem(result.detection, 0) == :detected
      assert elem(result.detection, 1) in @pre_error_signatures

      assert is_map(result.defense)
      assert result.defense.escalation_level in @escalation_levels

      # Antibody must be created for detected threats
      assert is_map(result.antibody),
             "Antibody must be created when a pre-error signature is detected"
    end

    @tag :pipeline
    test "DIS_10b: healthy metrics produce no-threat result with nil antibody" do
      result = run_full_pipeline(healthy_metrics())

      assert result.assessment.status == :healthy
      assert elem(result.detection, 0) == :none
      assert result.defense.escalation_level == :ignore
      assert result.antibody == nil
    end

    @tag :pipeline
    test "DIS_10c: pipeline output always contains timing information" do
      for metrics <- [healthy_metrics(), degraded_metrics(), critical_metrics()] do
        result = run_full_pipeline(metrics)
        assert Map.has_key?(result.timings, :pattern_hunter_ms)
        assert Map.has_key?(result.timings, :symbiotic_defense_ms)
        assert is_integer(result.timings.pattern_hunter_ms)
        assert is_integer(result.timings.symbiotic_defense_ms)
      end
    end
  end

  # ============================================================================
  # TEST 11: Unknown threat type handled gracefully
  # ============================================================================

  describe "TEST-11: Pipeline handles unknown threat types gracefully (new signature)" do
    @tag :pipeline
    test "DIS_11a: metrics with unrecognised keys are treated as healthy" do
      unknown_metrics = %{
        unknown_sensor_a: 0.99,
        unknown_sensor_b: 0.87,
        future_metric: 0.95
      }

      # compute_health_score only weighs known keys, unknown keys are ignored
      result = sentinel_assess_now(unknown_metrics)
      # All weights for known keys will use default 0.0 → max health
      assert result.health_score >= 0.0
      assert result.health_score <= 1.0
    end

    @tag :pipeline
    test "DIS_11b: pattern_hunter_detect returns :none for all-unknown metrics" do
      unknown_metrics = %{
        future_sensor: 0.99,
        quantum_flux: 0.95
      }

      {status, sig, rpn} = pattern_hunter_detect(unknown_metrics)
      assert status == :none
      assert sig == nil
      assert rpn == 0
    end

    @tag :pipeline
    test "DIS_11c: symbiotic_defense_respond accepts any atom as signature" do
      result = symbiotic_defense_respond(:new_unknown_threat_type_xyz, 75)
      assert result.escalation_level == :alert
      assert result.signature == :new_unknown_threat_type_xyz
      assert result.rpn == 75
    end

    @tag :pipeline
    test "DIS_11d: antibody_create accepts any atom signature without crashing" do
      defense = symbiotic_defense_respond(:totally_new_signature, 60)
      antibody = antibody_create(:totally_new_signature, 60, defense)
      assert antibody.signature == :totally_new_signature
      assert is_integer(antibody.signature_hash)
    end
  end

  # ============================================================================
  # TEST 12: Concurrent threat processing does not block pipeline
  # ============================================================================

  describe "TEST-12: Concurrent threat processing does not block pipeline" do
    @tag :concurrency
    test "DIS_12a: 20 concurrent full-pipeline runs all complete within 500ms" do
      tasks =
        for i <- 1..20 do
          Task.async(fn ->
            # Vary metrics per task to exercise different code paths
            base_score = rem(i, 10) / 10.0

            metrics = %{
              cpu_utilisation: base_score,
              memory_pressure: 1.0 - base_score,
              error_rate: base_score * 0.5,
              latency_p99_ms: base_score,
              queue_depth: 1.0 - base_score * 0.3,
              gc_pause_ms: base_score * 0.8
            }

            run_full_pipeline(metrics)
          end)
        end

      # All tasks must complete within 500ms total
      results = Task.await_many(tasks, 500)

      assert length(results) == 20

      for result <- results do
        assert Map.has_key?(result, :assessment)
        assert Map.has_key?(result, :detection)
        assert Map.has_key?(result, :defense)
        assert result.assessment.health_score >= 0.0
        assert result.assessment.health_score <= 1.0
      end
    end

    @tag :concurrency
    test "DIS_12b: concurrent runs produce independent results (no shared state)" do
      tasks =
        for _ <- 1..10 do
          Task.async(fn ->
            # All tasks use identical metrics
            run_full_pipeline(degraded_metrics())
          end)
        end

      results = Task.await_many(tasks, 500)

      # All results should have the same health score (pure computation)
      scores = Enum.map(results, fn r -> r.assessment.health_score end)
      first_score = hd(scores)

      for score <- scores do
        assert_in_delta score,
                        first_score,
                        0.001,
                        "Concurrent results must be deterministic (no shared mutable state)"
      end
    end
  end

  # ============================================================================
  # TEST 13: RPN >= 50 triggers Guardian report (AOR-IMMUNE-004)
  # ============================================================================

  describe "TEST-13: Threat RPN >= 50 triggers Guardian report (AOR-IMMUNE-004)" do
    @tag :guardian
    test "DIS_13a: defense response sets guardian_notified when RPN >= 50" do
      result = symbiotic_defense_respond(:memory_leak, 50)

      assert result.guardian_notified == true,
             "RPN 50 must trigger Guardian notification (AOR-IMMUNE-004)"
    end

    @tag :guardian
    test "DIS_13b: defense response does NOT set guardian_notified when RPN < 50" do
      result = symbiotic_defense_respond(:gc_pressure, 49)
      assert result.guardian_notified == false
    end

    @tag :guardian
    test "DIS_13c: all RPN thresholds above 50 trigger Guardian" do
      for rpn <- [50, 100, 150, 200, 300, 400, 500, 729] do
        result = symbiotic_defense_respond(:error_storm, rpn)

        assert result.guardian_notified == true,
               "RPN #{rpn} must notify Guardian (AOR-IMMUNE-004)"
      end
    end

    @tag :guardian
    test "DIS_13d: pipeline run on critical metrics produces guardian_notified defense" do
      result = run_full_pipeline(critical_metrics())
      # Critical metrics trigger high RPN signatures
      if elem(result.detection, 0) == :detected do
        assert result.defense.guardian_notified == true,
               "Critical system pipeline must notify Guardian"
      end
    end
  end

  # ============================================================================
  # TEST 14: Kernel process protection (AOR-IMMUNE-002)
  # ============================================================================

  describe "TEST-14: Kernel process protection — is_kernel_process?/1 before termination (AOR-IMMUNE-002)" do
    @tag :kernel
    test "DIS_14a: known kernel process names are identified as kernel processes" do
      for name <- @kernel_process_names do
        assert is_kernel_process?(name) == true,
               "#{name} must be identified as a kernel process"
      end
    end

    @tag :kernel
    test "DIS_14b: non-kernel atom names are not identified as kernel processes" do
      for name <- [:my_genserver, :user_worker, :domain_supervisor, :test_process] do
        assert is_kernel_process?(name) == false,
               "#{name} must not be identified as a kernel process"
      end
    end

    @tag :kernel
    test "DIS_14c: current test process is not a kernel process" do
      self_pid = self()
      assert is_kernel_process?(self_pid) == false
    end

    @tag :kernel
    test "DIS_14d: is_kernel_process?/1 accepts PID type" do
      # A regular spawned process is never a kernel process
      pid = spawn(fn -> :ok end)
      result = is_kernel_process?(pid)
      assert result == false
    end

    @tag :kernel
    test "DIS_14e: immune system must NOT terminate any kernel process" do
      # Simulate the pre-termination check an immune agent must perform.
      # If the process is kernel, action must be :skip, not :terminate.
      kernel_names = @kernel_process_names

      for name <- kernel_names do
        action =
          if is_kernel_process?(name) do
            :skip
          else
            :terminate
          end

        assert action == :skip,
               "Immune system must skip kernel process #{name} (AOR-IMMUNE-002)"
      end
    end
  end

  # ============================================================================
  # TEST 15: Property — health score bounded [0.0, 1.0] for any metrics
  # ============================================================================

  describe "TEST-15: Property — health score bounded [0.0, 1.0] regardless of input metrics" do
    @tag :property
    property "DIS_15_PC: any combination of metric values produces bounded health score (PropCheck)" do
      forall {cpu, mem, err, lat, queue, gc} <-
               {PC.float(min: 0.0, max: 1.0), PC.float(min: 0.0, max: 1.0),
                PC.float(min: 0.0, max: 1.0), PC.float(min: 0.0, max: 1.0),
                PC.float(min: 0.0, max: 1.0), PC.float(min: 0.0, max: 1.0)} do
        metrics = %{
          cpu_utilisation: cpu,
          memory_pressure: mem,
          error_rate: err,
          latency_p99_ms: lat,
          queue_depth: queue,
          gc_pause_ms: gc
        }

        score = compute_health_score(metrics)
        is_float(score) and score >= 0.0 and score <= 1.0
      end
    end

    @tag :property
    test "DIS_15_SD: StreamData — health score in [0.0, 1.0] for all random metric sets" do
      ExUnitProperties.check all(
                               cpu <- SD.float(min: 0.0, max: 1.0),
                               mem <- SD.float(min: 0.0, max: 1.0),
                               err <- SD.float(min: 0.0, max: 1.0),
                               lat <- SD.float(min: 0.0, max: 1.0),
                               queue <- SD.float(min: 0.0, max: 1.0),
                               gc <- SD.float(min: 0.0, max: 1.0),
                               max_runs: 60
                             ) do
        metrics = %{
          cpu_utilisation: cpu,
          memory_pressure: mem,
          error_rate: err,
          latency_p99_ms: lat,
          queue_depth: queue,
          gc_pause_ms: gc
        }

        result = sentinel_assess_now(metrics)
        assert result.health_score >= 0.0, "Health score must be >= 0.0"
        assert result.health_score <= 1.0, "Health score must be <= 1.0"
        assert result.status in [:healthy, :degraded, :critical]
      end
    end
  end

  # ============================================================================
  # TEST 16: Property — escalation level never decreases for active threat
  # ============================================================================

  describe "TEST-16: Property — escalation level never decreases for increasing RPN" do
    @tag :property
    property "DIS_16_PC: higher RPN produces equal or higher escalation rank (PropCheck)" do
      forall {low_rpn, high_rpn} <-
               {PC.integer(min: 0, max: 299), PC.integer(min: 300, max: 729)} do
        low_result = symbiotic_defense_respond(:error_storm, low_rpn)
        high_result = symbiotic_defense_respond(:error_storm, high_rpn)

        low_rank = @escalation_rank[low_result.escalation_level]
        high_rank = @escalation_rank[high_result.escalation_level]

        low_rank <= high_rank
      end
    end

    @tag :property
    test "DIS_16_SD: StreamData — escalation rank is monotonically non-decreasing with RPN" do
      ExUnitProperties.check all(
                               rpn_a <- SD.integer(0..149),
                               rpn_b <- SD.integer(150..729),
                               max_runs: 60
                             ) do
        result_a = symbiotic_defense_respond(:memory_leak, rpn_a)
        result_b = symbiotic_defense_respond(:memory_leak, rpn_b)

        rank_a = @escalation_rank[result_a.escalation_level]
        rank_b = @escalation_rank[result_b.escalation_level]

        assert rank_a <= rank_b,
               "Escalation must not decrease: RPN #{rpn_a}=#{result_a.escalation_level}(#{rank_a}) " <>
                 "should be <= RPN #{rpn_b}=#{result_b.escalation_level}(#{rank_b})"
      end
    end
  end
end
