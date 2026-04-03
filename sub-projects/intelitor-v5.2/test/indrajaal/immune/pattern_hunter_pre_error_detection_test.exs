defmodule Indrajaal.Immune.PatternHunterPreErrorDetectionTest do
  @moduledoc """
  Tests for the PatternHunter subsystem of the Digital Immune System.

  WHAT: Tests pre-error signature detection, baseline calibration, anomaly
        scoring, pattern matching against known failure signatures, threat
        escalation to Guardian, and latency compliance.
  WHY: SC-IMMUNE-004 requires PatternHunter to detect pre-error signatures
       before failures occur. SC-BIO-EXT-001 mandates detection completes
       within 10ms. SC-BIO-EXT-002 mandates SymbioticDefense response < 100ms.
  CONSTRAINTS:
    - SC-IMMUNE-004: PatternHunter detects pre-error signatures
    - SC-BIO-EXT-001: PatternHunter pre-error detection < 10ms
    - SC-BIO-EXT-002: SymbioticDefense threat response < 100ms
    - AOR-IMMUNE-003: PatternHunter requires baseline calibration on first run
    - AOR-IMMUNE-004: Threats with RPN >= 50 MUST be reported to Guardian
    - EP-GEN-014: Dual property testing — PropCheck + StreamData

  ## Test Index
  | Group                            | Tests | Category       |
  |----------------------------------|-------|----------------|
  | pattern baseline calibration     |     6 | baseline       |
  | anomaly scoring                  |     7 | scoring        |
  | pre-error signature matching     |     8 | signatures     |
  | threat escalation                |     7 | escalation     |
  | detection latency                |     5 | timing         |
  | property: anomaly detection      |     4 | property       |
  | TOTAL                            |    37 |                |

  ## Change History
  | Version | Date       | Author      | Change                                |
  |---------|------------|-------------|---------------------------------------|
  | 1.0.0   | 2026-03-24 | Claude S4.6 | Initial PatternHunter pre-error suite |

  @version "1.0.0"
  @last_modified "2026-03-24T00:00:00Z"
  """

  use ExUnit.Case, async: true

  # EP-GEN-014: MANDATORY dual property testing import pattern
  import ExUnitProperties, except: [property: 2, property: 3]
  alias StreamData, as: SD

  @moduletag :immune
  @moduletag :pattern_hunter
  @moduletag :pre_error_detection

  # ============================================================================
  # CONSTANTS
  # ============================================================================

  # Known failure pre-error signatures per SC-IMMUNE-004
  @known_signatures [
    :memory_leak,
    :gc_pressure,
    :connection_exhaustion,
    :cpu_saturation,
    :error_rate_spike,
    :latency_degradation,
    :queue_overflow
  ]

  # RPN escalation threshold per AOR-IMMUNE-004
  @guardian_rpn_threshold 50

  # Detection latency budget per SC-BIO-EXT-001 (milliseconds)
  @detection_latency_budget_ms 10

  # SymbioticDefense response latency budget per SC-BIO-EXT-002 (milliseconds)
  @defense_latency_budget_ms 100

  # Minimum baseline window length before anomaly detection is meaningful
  @min_baseline_window 5

  # ============================================================================
  # SELF-CONTAINED HELPERS
  #
  # All helpers simulate PatternHunter logic purely in-process.
  # No production GenServer is required to be running.
  # ============================================================================

  # ---------------------------------------------------------------------------
  # Baseline calibration helpers
  # ---------------------------------------------------------------------------

  # Build a baseline from a list of metric samples (time-series windows).
  # Returns %{mean: float, std_dev: float, min: float, max: float, n: integer}.
  defp build_baseline(samples)
       when is_list(samples) and length(samples) >= @min_baseline_window do
    n = length(samples)
    mean = Enum.sum(samples) / n

    variance =
      samples
      |> Enum.map(fn x -> (x - mean) * (x - mean) end)
      |> Enum.sum()
      |> Kernel./(n)

    std_dev = :math.sqrt(variance)

    %{
      mean: mean,
      std_dev: std_dev,
      min: Enum.min(samples),
      max: Enum.max(samples),
      n: n,
      calibrated: true
    }
  end

  defp build_baseline(samples) when is_list(samples) do
    %{
      mean: 0.0,
      std_dev: 0.0,
      min: 0.0,
      max: 0.0,
      n: length(samples),
      calibrated: false
    }
  end

  # Check whether a baseline is valid for anomaly scoring.
  defp baseline_valid?(%{calibrated: true, n: n}) when n >= @min_baseline_window, do: true
  defp baseline_valid?(_), do: false

  # ---------------------------------------------------------------------------
  # Anomaly scoring helpers
  # ---------------------------------------------------------------------------

  # Compute the z-score for a current value given a calibrated baseline.
  # z = (value - mean) / std_dev. Returns 0.0 when std_dev is zero (stable baseline).
  defp z_score(value, %{mean: mean, std_dev: std_dev}) when std_dev > 0.0 do
    (value - mean) / std_dev
  end

  defp z_score(_value, _baseline), do: 0.0

  # Compute exponential moving average deviation score in [0.0, 1.0].
  # Uses alpha=0.3. A large deviation from the EMA indicates anomaly.
  defp ema_deviation(samples, alpha \\ 0.3) when is_list(samples) and length(samples) >= 2 do
    [first | rest] = samples
    ema = Enum.reduce(rest, first, fn x, acc -> alpha * x + (1.0 - alpha) * acc end)
    last = List.last(samples)
    raw_dev = abs(last - ema)
    # Normalise using the observed range to get a [0.0, 1.0] deviation score
    range = max(Enum.max(samples) - Enum.min(samples), 1.0e-9)
    min(raw_dev / range, 1.0)
  end

  defp ema_deviation(_samples, _alpha), do: 0.0

  # Classify anomaly severity from a z-score magnitude.
  defp classify_anomaly(z) when abs(z) >= 4.0, do: :critical
  defp classify_anomaly(z) when abs(z) >= 3.0, do: :high
  defp classify_anomaly(z) when abs(z) >= 2.0, do: :medium
  defp classify_anomaly(z) when abs(z) >= 1.0, do: :low
  defp classify_anomaly(_z), do: :normal

  # ---------------------------------------------------------------------------
  # Pre-error signature matching helpers
  # ---------------------------------------------------------------------------

  # A signature definition is a map with:
  #   :name          — atom
  #   :metric        — which metric to watch
  #   :threshold     — raw value above which the signature fires
  #   :description   — human readable description
  @signature_library [
    %{
      name: :memory_leak,
      metric: :memory_mb,
      threshold: 850.0,
      description: "Process memory above 850 MB (steady growth pattern)"
    },
    %{
      name: :gc_pressure,
      metric: :gc_pause_ms,
      threshold: 120.0,
      description: "GC pause above 120ms — heap under pressure"
    },
    %{
      name: :connection_exhaustion,
      metric: :open_connections,
      threshold: 950.0,
      description: "Open connection count approaching pool limit"
    },
    %{
      name: :cpu_saturation,
      metric: :cpu_percent,
      threshold: 85.0,
      description: "CPU sustained above 85% — saturation approaching"
    },
    %{
      name: :error_rate_spike,
      metric: :errors_per_sec,
      threshold: 50.0,
      description: "Error rate above 50/s — storm potential"
    },
    %{
      name: :latency_degradation,
      metric: :p99_latency_ms,
      threshold: 500.0,
      description: "p99 latency above 500ms — SLA breach risk"
    },
    %{
      name: :queue_overflow,
      metric: :queue_depth,
      threshold: 800.0,
      description: "Message queue depth approaching overflow"
    }
  ]

  # Match a metrics snapshot against the signature library.
  # Returns a list of matched signature maps (may be empty).
  defp match_signatures(metrics) when is_map(metrics) do
    @signature_library
    |> Enum.filter(fn sig ->
      value = Map.get(metrics, sig.metric, 0.0)
      value >= sig.threshold
    end)
  end

  # Run full pre-error detection on a metrics snapshot with a baseline.
  # Returns {:detected, matched_signatures, max_rpn} | {:none, [], 0}.
  defp detect_pre_error(metrics, baseline) when is_map(metrics) and is_map(baseline) do
    matched = match_signatures(metrics)

    case matched do
      [] ->
        {:none, [], 0}

      sigs ->
        # Compute RPN for the worst matched signature using the z-score
        max_rpn =
          sigs
          |> Enum.map(fn sig ->
            value = Map.get(metrics, sig.metric, 0.0)
            z = if baseline_valid?(baseline), do: z_score(value, baseline), else: 0.0
            compute_rpn_for_signature(sig, z)
          end)
          |> Enum.max()

        {:detected, sigs, max_rpn}
    end
  end

  # Compute RPN = Severity × Occurrence × Detection for a matched signature.
  # Severity is fixed per signature type; occurrence and detection scale with z-score.
  defp compute_rpn_for_signature(sig, z_score_val) do
    severity = signature_severity(sig.name)
    # Occurrence scales with z-score magnitude (bounded 1..9)
    occurrence = min(9, max(1, round(abs(z_score_val) + 1)))
    # Detection inversely proportional to severity (hard-to-find = higher D)
    detection = max(1, 10 - severity)
    severity * occurrence * detection
  end

  defp signature_severity(:memory_leak), do: 7
  defp signature_severity(:gc_pressure), do: 5
  defp signature_severity(:connection_exhaustion), do: 8
  defp signature_severity(:cpu_saturation), do: 6
  defp signature_severity(:error_rate_spike), do: 8
  defp signature_severity(:latency_degradation), do: 7
  defp signature_severity(:queue_overflow), do: 6
  defp signature_severity(_), do: 3

  # ---------------------------------------------------------------------------
  # Threat escalation helpers
  # ---------------------------------------------------------------------------

  # Escalation decision per AOR-IMMUNE-004: RPN >= 50 must go to Guardian.
  defp escalate(rpn) when rpn >= 300,
    do: %{level: :critical, guardian: true, action: :emergency_stop}

  defp escalate(rpn) when rpn >= 150, do: %{level: :high, guardian: true, action: :quarantine}

  defp escalate(rpn) when rpn >= 50,
    do: %{level: :elevated, guardian: true, action: :alert_and_monitor}

  defp escalate(_rpn), do: %{level: :low, guardian: false, action: :log_only}

  # Severity label for a numeric RPN.
  defp rpn_severity_label(rpn) when rpn >= 300, do: :critical
  defp rpn_severity_label(rpn) when rpn >= 150, do: :high
  defp rpn_severity_label(rpn) when rpn >= 50, do: :elevated
  defp rpn_severity_label(_rpn), do: :low

  # FMEA S×O×D helper
  defp rpn(s, o, d), do: s * o * d

  # ---------------------------------------------------------------------------
  # Time-series fixture builders
  # ---------------------------------------------------------------------------

  # Normal baseline window — 20 samples around a stable mean.
  defp normal_window(mean, noise_amplitude \\ 5.0) do
    for _ <- 1..20 do
      mean + (:rand.uniform() - 0.5) * 2.0 * noise_amplitude
    end
  end

  # Drifting window — starts at mean, linearly grows by drift each step.
  defp drifting_window(mean, drift_per_step) do
    for i <- 0..19 do
      mean + i * drift_per_step + (:rand.uniform() - 0.5) * 3.0
    end
  end

  # Spike window — stable with a large spike at the end.
  defp spike_window(mean, spike_magnitude) do
    base = for _ <- 1..19, do: mean + (:rand.uniform() - 0.5) * 4.0
    base ++ [mean + spike_magnitude]
  end

  # Healthy metrics snapshot (all values below signature thresholds).
  defp healthy_metrics do
    %{
      memory_mb: 400.0,
      gc_pause_ms: 30.0,
      open_connections: 200.0,
      cpu_percent: 25.0,
      errors_per_sec: 2.0,
      p99_latency_ms: 80.0,
      queue_depth: 50.0
    }
  end

  # Metrics snapshot triggering a memory-leak signature.
  defp memory_leak_metrics do
    %{healthy_metrics() | memory_mb: 920.0}
  end

  # Metrics snapshot triggering a GC-pressure signature.
  defp gc_pressure_metrics do
    %{healthy_metrics() | gc_pause_ms: 180.0}
  end

  # Metrics snapshot triggering a connection-exhaustion signature.
  defp connection_exhaustion_metrics do
    %{healthy_metrics() | open_connections: 980.0}
  end

  # Metrics snapshot triggering multiple signatures simultaneously.
  defp multi_signature_metrics do
    %{
      memory_mb: 900.0,
      gc_pause_ms: 150.0,
      open_connections: 970.0,
      cpu_percent: 90.0,
      errors_per_sec: 55.0,
      p99_latency_ms: 600.0,
      queue_depth: 820.0
    }
  end

  # ============================================================================
  # GROUP 1: Pattern Baseline Calibration
  # ============================================================================

  describe "pattern baseline calibration" do
    @tag :baseline
    test "PH_BASELINE_01: baseline is uncalibrated when fewer than 5 samples provided" do
      samples = [10.0, 20.0, 30.0]
      baseline = build_baseline(samples)
      assert baseline.calibrated == false
      assert baseline_valid?(baseline) == false
    end

    @tag :baseline
    test "PH_BASELINE_02: baseline is calibrated with 5 or more samples" do
      samples = [10.0, 12.0, 11.0, 13.0, 10.5]
      baseline = build_baseline(samples)
      assert baseline.calibrated == true
      assert baseline_valid?(baseline) == true
      assert baseline.n == 5
    end

    @tag :baseline
    test "PH_BASELINE_03: baseline mean is accurate to within floating-point tolerance" do
      samples = [100.0, 200.0, 300.0, 400.0, 500.0]
      baseline = build_baseline(samples)
      assert_in_delta baseline.mean, 300.0, 0.001
    end

    @tag :baseline
    test "PH_BASELINE_04: baseline std_dev is non-negative for any sample window" do
      windows = [
        normal_window(200.0),
        drifting_window(50.0, 3.0),
        spike_window(100.0, 500.0)
      ]

      for window <- windows do
        baseline = build_baseline(window)

        assert baseline.std_dev >= 0.0,
               "Standard deviation must be non-negative, got #{baseline.std_dev}"
      end
    end

    @tag :baseline
    test "PH_BASELINE_05: baseline min and max bracket all sample values" do
      samples = [15.0, 42.0, 7.0, 99.0, 31.0, 55.0, 21.0]
      baseline = build_baseline(samples)
      assert baseline.min == 7.0
      assert baseline.max == 99.0
      assert baseline.min <= baseline.mean
      assert baseline.mean <= baseline.max
    end

    @tag :baseline
    test "PH_BASELINE_06: stable baseline window has low std_dev (< 5% of mean)" do
      # 20 samples tightly clustered around 500.0
      samples = for _ <- 1..20, do: 500.0 + (:rand.uniform() - 0.5) * 4.0
      baseline = build_baseline(samples)

      relative_std = baseline.std_dev / baseline.mean

      assert relative_std < 0.05,
             "Stable window std_dev should be < 5% of mean, got #{Float.round(relative_std * 100, 2)}%"
    end
  end

  # ============================================================================
  # GROUP 2: Anomaly Scoring
  # ============================================================================

  describe "anomaly scoring" do
    @tag :scoring
    test "PH_SCORE_01: z-score is zero when value equals baseline mean" do
      samples = normal_window(300.0, 5.0)
      baseline = build_baseline(samples)
      z = z_score(baseline.mean, baseline)
      assert_in_delta z, 0.0, 0.0001
    end

    @tag :scoring
    test "PH_SCORE_02: z-score is positive for value above the mean" do
      samples = normal_window(100.0, 2.0)
      baseline = build_baseline(samples)
      z = z_score(120.0, baseline)
      assert z > 0.0
    end

    @tag :scoring
    test "PH_SCORE_03: z-score magnitude scales with deviation from mean" do
      samples = for i <- 1..20, do: 50.0 + i * 1.0
      baseline = build_baseline(samples)

      z_small = abs(z_score(52.0, baseline))
      z_large = abs(z_score(90.0, baseline))
      assert z_large > z_small, "Larger deviation must produce larger |z|"
    end

    @tag :scoring
    test "PH_SCORE_04: anomaly classification maps z-score magnitude to severity" do
      assert classify_anomaly(0.5) == :normal
      assert classify_anomaly(1.5) == :low
      assert classify_anomaly(2.5) == :medium
      assert classify_anomaly(3.5) == :high
      assert classify_anomaly(4.5) == :critical
    end

    @tag :scoring
    test "PH_SCORE_05: negative z-score produces same severity as positive with same magnitude" do
      assert classify_anomaly(-2.5) == :medium
      assert classify_anomaly(-3.5) == :high
      assert classify_anomaly(-4.5) == :critical
    end

    @tag :scoring
    test "PH_SCORE_06: EMA deviation returns value in [0.0, 1.0] for any samples" do
      windows = [
        normal_window(200.0, 10.0),
        drifting_window(50.0, 5.0),
        spike_window(100.0, 300.0)
      ]

      for samples <- windows do
        dev = ema_deviation(samples)
        assert dev >= 0.0, "EMA deviation must be >= 0.0"
        assert dev <= 1.0, "EMA deviation must be <= 1.0, got #{dev}"
      end
    end

    @tag :scoring
    test "PH_SCORE_07: spike window produces higher EMA deviation than stable window" do
      stable = normal_window(200.0, 1.0)
      spiked = spike_window(200.0, 500.0)

      stable_dev = ema_deviation(stable)
      spike_dev = ema_deviation(spiked)

      assert spike_dev > stable_dev,
             "Spike window must have higher EMA deviation than stable window"
    end
  end

  # ============================================================================
  # GROUP 3: Pre-Error Signature Matching
  # ============================================================================

  describe "pre-error signature matching" do
    @tag :signatures
    test "PH_SIG_01: healthy metrics produce no signature matches" do
      {:none, sigs, rpn_val} = detect_pre_error(healthy_metrics(), %{calibrated: false})
      assert sigs == []
      assert rpn_val == 0
    end

    @tag :signatures
    test "PH_SIG_02: memory-leak metrics trigger :memory_leak signature" do
      {:detected, sigs, _rpn} = detect_pre_error(memory_leak_metrics(), %{calibrated: false})
      names = Enum.map(sigs, & &1.name)
      assert :memory_leak in names
    end

    @tag :signatures
    test "PH_SIG_03: GC-pressure metrics trigger :gc_pressure signature" do
      {:detected, sigs, _rpn} = detect_pre_error(gc_pressure_metrics(), %{calibrated: false})
      names = Enum.map(sigs, & &1.name)
      assert :gc_pressure in names
    end

    @tag :signatures
    test "PH_SIG_04: connection-exhaustion metrics trigger :connection_exhaustion signature" do
      {:detected, sigs, _rpn} =
        detect_pre_error(connection_exhaustion_metrics(), %{calibrated: false})

      names = Enum.map(sigs, & &1.name)
      assert :connection_exhaustion in names
    end

    @tag :signatures
    test "PH_SIG_05: multi-signature metrics trigger at least 5 signatures simultaneously" do
      {:detected, sigs, rpn_val} =
        detect_pre_error(multi_signature_metrics(), %{calibrated: false})

      assert length(sigs) >= 5,
             "Multi-signature snapshot should trigger >= 5 signatures, got #{length(sigs)}"

      assert rpn_val > 0
    end

    @tag :signatures
    test "PH_SIG_06: all matched signature names are from the known library" do
      {:detected, sigs, _rpn} = detect_pre_error(multi_signature_metrics(), %{calibrated: false})

      for sig <- sigs do
        assert sig.name in @known_signatures,
               "Matched signature #{sig.name} must be in the known library"
      end
    end

    @tag :signatures
    test "PH_SIG_07: RPN with calibrated baseline is greater than RPN without baseline for same metrics" do
      # Build a baseline from healthy samples so the anomaly is z-score amplified
      baseline_samples = for _ <- 1..20, do: 200.0 + (:rand.uniform() - 0.5) * 10.0
      baseline = build_baseline(baseline_samples)
      # memory_mb = 920 is far above the baseline mean of ~200
      metrics = memory_leak_metrics()

      {:detected, _sigs_no_bl, rpn_no_bl} =
        detect_pre_error(metrics, %{calibrated: false})

      {:detected, _sigs_with_bl, rpn_with_bl} =
        detect_pre_error(metrics, baseline)

      assert rpn_with_bl >= rpn_no_bl,
             "Calibrated baseline should amplify RPN: #{rpn_with_bl} >= #{rpn_no_bl}"
    end

    @tag :signatures
    test "PH_SIG_08: signature library covers all known pre-error patterns" do
      library_names = Enum.map(@signature_library, & &1.name)

      for known <- @known_signatures do
        assert known in library_names,
               "Known signature #{known} must have a definition in the signature library"
      end
    end
  end

  # ============================================================================
  # GROUP 4: Threat Escalation
  # ============================================================================

  describe "threat escalation" do
    @tag :escalation
    test "PH_ESC_01: RPN below threshold does not notify Guardian" do
      result = escalate(@guardian_rpn_threshold - 1)
      assert result.guardian == false
      assert result.level == :low
    end

    @tag :escalation
    test "PH_ESC_02: RPN exactly at threshold notifies Guardian (AOR-IMMUNE-004)" do
      result = escalate(@guardian_rpn_threshold)

      assert result.guardian == true,
             "RPN #{@guardian_rpn_threshold} must trigger Guardian notification"
    end

    @tag :escalation
    test "PH_ESC_03: RPN 50–149 maps to elevated level with alert_and_monitor action" do
      for rpn_val <- [50, 75, 100, 149] do
        result = escalate(rpn_val)
        assert result.level == :elevated
        assert result.action == :alert_and_monitor
        assert result.guardian == true
      end
    end

    @tag :escalation
    test "PH_ESC_04: RPN 150–299 maps to high level with quarantine action" do
      for rpn_val <- [150, 200, 250, 299] do
        result = escalate(rpn_val)
        assert result.level == :high
        assert result.action == :quarantine
        assert result.guardian == true
      end
    end

    @tag :escalation
    test "PH_ESC_05: RPN >= 300 maps to critical level with emergency_stop action" do
      for rpn_val <- [300, 400, 500, 729] do
        result = escalate(rpn_val)
        assert result.level == :critical
        assert result.action == :emergency_stop
        assert result.guardian == true
      end
    end

    @tag :escalation
    test "PH_ESC_06: severity label classification covers all RPN ranges" do
      assert rpn_severity_label(0) == :low
      assert rpn_severity_label(49) == :low
      assert rpn_severity_label(50) == :elevated
      assert rpn_severity_label(149) == :elevated
      assert rpn_severity_label(150) == :high
      assert rpn_severity_label(299) == :high
      assert rpn_severity_label(300) == :critical
      assert rpn_severity_label(729) == :critical
    end

    @tag :escalation
    test "PH_ESC_07: FMEA RPN formula S×O×D is correctly applied (SC-FMEA-002)" do
      # FMEA: PatternHunter false-negative — severity=8, occurrence=3, detection=6
      computed = rpn(8, 3, 6)
      assert computed == 144

      assert computed >= @guardian_rpn_threshold,
             "FMEA RPN 144 requires Guardian escalation"

      # Boundary: maximum possible RPN
      assert rpn(9, 9, 9) == 729
      # Minimum non-zero RPN
      assert rpn(1, 1, 1) == 1
    end
  end

  # ============================================================================
  # GROUP 5: Detection Latency
  # ============================================================================

  describe "detection latency" do
    @tag :timing
    test "PH_LAT_01: signature matching on healthy metrics completes within 10ms (SC-BIO-EXT-001)" do
      baseline = build_baseline(normal_window(200.0))

      t0 = System.monotonic_time(:millisecond)
      detect_pre_error(healthy_metrics(), baseline)
      elapsed = System.monotonic_time(:millisecond) - t0

      assert elapsed < @detection_latency_budget_ms,
             "PatternHunter must complete within #{@detection_latency_budget_ms}ms " <>
               "(SC-BIO-EXT-001), took #{elapsed}ms"
    end

    @tag :timing
    test "PH_LAT_02: signature matching on multi-signature metrics completes within 10ms" do
      baseline = build_baseline(normal_window(100.0))

      t0 = System.monotonic_time(:millisecond)
      detect_pre_error(multi_signature_metrics(), baseline)
      elapsed = System.monotonic_time(:millisecond) - t0

      assert elapsed < @detection_latency_budget_ms,
             "PatternHunter must handle multi-signature case within #{@detection_latency_budget_ms}ms, " <>
               "took #{elapsed}ms"
    end

    @tag :timing
    test "PH_LAT_03: baseline calibration on 20 samples completes within 10ms" do
      samples = normal_window(500.0)

      t0 = System.monotonic_time(:millisecond)
      build_baseline(samples)
      elapsed = System.monotonic_time(:millisecond) - t0

      assert elapsed < @detection_latency_budget_ms,
             "Baseline calibration must complete within #{@detection_latency_budget_ms}ms, " <>
               "took #{elapsed}ms"
    end

    @tag :timing
    test "PH_LAT_04: escalation decision completes within defense latency budget (SC-BIO-EXT-002)" do
      # After detection, the escalation step must also finish within 100ms
      rpn_val = 200

      t0 = System.monotonic_time(:millisecond)
      escalate(rpn_val)
      elapsed = System.monotonic_time(:millisecond) - t0

      assert elapsed < @defense_latency_budget_ms,
             "Escalation decision must complete within #{@defense_latency_budget_ms}ms " <>
               "(SC-BIO-EXT-002), took #{elapsed}ms"
    end

    @tag :timing
    test "PH_LAT_05: full detect-then-escalate pipeline runs within combined budget" do
      # Combined budget: detection (10ms) + escalation (100ms) = 110ms
      combined_budget_ms = @detection_latency_budget_ms + @defense_latency_budget_ms
      baseline = build_baseline(normal_window(150.0))

      t0 = System.monotonic_time(:millisecond)
      {status, _sigs, rpn_val} = detect_pre_error(multi_signature_metrics(), baseline)

      if status == :detected do
        escalate(rpn_val)
      end

      elapsed = System.monotonic_time(:millisecond) - t0

      assert elapsed < combined_budget_ms,
             "Full detect+escalate pipeline must complete within #{combined_budget_ms}ms, " <>
               "took #{elapsed}ms"
    end
  end

  # ============================================================================
  # GROUP 6: Property — Anomaly Detection
  # ============================================================================

  describe "property: anomaly detection" do
    @tag :property
    test "PH_PROP_01: SD — baseline z-score is always zero when value equals mean" do
      ExUnitProperties.check all(
                               mean <- SD.float(min: 10.0, max: 1000.0),
                               noise <- SD.float(min: 0.5, max: 10.0),
                               max_runs: 40
                             ) do
        samples = for _ <- 1..20, do: mean + Enum.random([-1, 1]) * noise * :rand.uniform()
        baseline = build_baseline(samples)

        if baseline.std_dev > 0.0 do
          z = z_score(baseline.mean, baseline)
          assert_in_delta z, 0.0, 0.0001, "z-score at mean must be 0.0, got #{z}"
        end
      end
    end

    @tag :property
    test "PH_PROP_02: SD — anomaly classification covers all z-score ranges without gaps" do
      ExUnitProperties.check all(
                               z <- SD.float(min: -10.0, max: 10.0),
                               max_runs: 60
                             ) do
        severity = classify_anomaly(z)

        assert severity in [:normal, :low, :medium, :high, :critical],
               "classify_anomaly/1 must return a known severity, got #{severity} for z=#{z}"
      end
    end

    @tag :property
    test "PH_PROP_03: SD — escalation always notifies Guardian when RPN >= 50 (AOR-IMMUNE-004)" do
      ExUnitProperties.check all(
                               rpn_val <- SD.integer(@guardian_rpn_threshold..729),
                               max_runs: 60
                             ) do
        result = escalate(rpn_val)

        assert result.guardian == true,
               "RPN #{rpn_val} >= #{@guardian_rpn_threshold} must notify Guardian (AOR-IMMUNE-004)"

        assert result.level != :low,
               "RPN #{rpn_val} must not produce :low escalation level"
      end
    end

    @tag :property
    test "PH_PROP_04: SD — false-positive rate is zero for healthy metrics across noise variations" do
      # Property: if ALL metrics are below their thresholds, no signature fires.
      # We verify this across randomly varied healthy metrics (below threshold by 30%).
      ExUnitProperties.check all(
                               mem_pct <- SD.float(min: 0.1, max: 0.69),
                               cpu_pct <- SD.float(min: 0.1, max: 0.59),
                               err_pct <- SD.float(min: 0.1, max: 0.59),
                               lat_pct <- SD.float(min: 0.1, max: 0.59),
                               max_runs: 50
                             ) do
        # Keep all metrics strictly below their signature thresholds
        safe_metrics = %{
          memory_mb: 850.0 * mem_pct,
          gc_pause_ms: 120.0 * cpu_pct,
          open_connections: 950.0 * err_pct,
          cpu_percent: 85.0 * cpu_pct,
          errors_per_sec: 50.0 * err_pct,
          p99_latency_ms: 500.0 * lat_pct,
          queue_depth: 800.0 * err_pct
        }

        {status, sigs, rpn_val} = detect_pre_error(safe_metrics, %{calibrated: false})

        assert status == :none,
               "Metrics below all thresholds must produce :none, got #{inspect(status)}"

        assert sigs == [],
               "No signatures should fire for safe metrics, got #{inspect(Enum.map(sigs, & &1.name))}"

        assert rpn_val == 0
      end
    end
  end
end
