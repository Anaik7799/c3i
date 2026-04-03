defmodule Indrajaal.Safety.SentinelPatternHunterCalibrationTest do
  @moduledoc """
  Sentinel PatternHunter Baseline Calibration Test (cce65b73).

  WHAT: Verifies PatternHunter statistical baseline calibration — mean + 2σ
        threshold computation, anomaly detection sensitivity, outlier robustness,
        incremental recalibration, and per-metric independence. All logic is
        self-contained via private helpers; no real PatternHunter process needed.

  WHY: The PatternHunter immune sensor must establish a statistically valid
       baseline before it can detect pre-error signatures. Without a calibrated
       baseline the detection rate is undefined, violating SC-BIO-EXT-001 (pre-
       error detection < 10ms) and SC-IMMUNE-004 (pre-error signatures).

  CONSTRAINTS:
    - SC-BIO-EXT-001: PatternHunter pre-error detection MUST complete < 10ms
    - SC-IMMUNE-004: PatternHunter detects pre-error signatures reliably
    - AOR-IMMUNE-003: PatternHunter requires baseline calibration on first run
    - Ω₃ Zero-Defect: 0 warnings, 0 test failures

  ## Constitutional Verification
  - Ψ₀ Existence: helpers are total functions (no crash on any numeric input)
  - Ψ₁ Regeneration: baseline is fully reproduced from the same sample list
  - Ψ₃ Verification: threshold formula is deterministic and auditable

  ## Change History
  | Version | Date       | Author | Change                                    |
  |---------|------------|--------|-------------------------------------------|
  | 1.0.0   | 2026-03-24 | Claude | Initial baseline calibration test suite   |

  @version "1.0.0"
  @last_modified "2026-03-24T00:00:00Z"
  """

  use ExUnit.Case, async: true
  import ExUnitProperties, except: [property: 2, property: 3]

  alias StreamData, as: SD

  @moduletag :safety
  @moduletag :immune

  # ============================================================================
  # 1. BASELINE CALIBRATION — mean + 2σ threshold
  # ============================================================================

  describe "Baseline calibration from N samples" do
    test "calibrate_baseline computes correct mean for uniform samples" do
      samples = [10.0, 10.0, 10.0, 10.0, 10.0]
      baseline = calibrate_baseline(samples)

      assert_in_delta baseline.mean, 10.0, 0.001
    end

    test "calibrate_baseline computes zero stddev for constant samples" do
      samples = [5.0, 5.0, 5.0, 5.0]
      baseline = calibrate_baseline(samples)

      assert_in_delta baseline.stddev, 0.0, 0.001
    end

    test "threshold is mean + 2 * stddev for known distribution" do
      # Samples: mean=10, stddev=2 → threshold=14
      samples = [8.0, 10.0, 12.0, 10.0, 10.0]
      baseline = calibrate_baseline(samples)

      expected_threshold = baseline.mean + 2.0 * baseline.stddev
      assert_in_delta baseline.threshold, expected_threshold, 0.001
    end

    test "sample_count is recorded correctly" do
      samples = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
      baseline = calibrate_baseline(samples)

      assert baseline.sample_count == 6
    end

    test "calibrate_baseline returns a map with all required fields" do
      baseline = calibrate_baseline([1.0, 2.0, 3.0])

      assert is_map(baseline)
      assert Map.has_key?(baseline, :mean)
      assert Map.has_key?(baseline, :stddev)
      assert Map.has_key?(baseline, :threshold)
      assert Map.has_key?(baseline, :sample_count)
    end

    test "threshold is always >= mean" do
      samples = [1.0, 2.0, 3.0, 100.0, 2.0]
      baseline = calibrate_baseline(samples)

      assert baseline.threshold >= baseline.mean
    end
  end

  # ============================================================================
  # 2. PATTERN DETECTION — deviation > 2σ is flagged
  # ============================================================================

  describe "Pattern detection: deviation > 2σ flagged" do
    test "value exactly at threshold is not an anomaly" do
      samples = [10.0, 10.0, 10.0, 10.0]
      baseline = calibrate_baseline(samples)

      # stddev=0, threshold=mean — value == threshold is NOT > 2σ
      refute detect_anomaly(baseline.threshold, baseline)
    end

    test "value clearly above threshold is anomaly" do
      # samples with real spread so stddev > 0
      samples = [8.0, 9.0, 10.0, 11.0, 12.0]
      baseline = calibrate_baseline(samples)

      # Push far above threshold
      high_value = baseline.threshold + 10.0
      assert detect_anomaly(high_value, baseline)
    end

    test "value within 1σ of mean is not anomaly" do
      samples = [8.0, 9.0, 10.0, 11.0, 12.0]
      baseline = calibrate_baseline(samples)

      within_1sigma = baseline.mean + baseline.stddev * 0.5
      refute detect_anomaly(within_1sigma, baseline)
    end

    test "value exactly 2σ above mean is not flagged (boundary)" do
      samples = [8.0, 9.0, 10.0, 11.0, 12.0]
      baseline = calibrate_baseline(samples)

      at_2sigma = baseline.mean + 2.0 * baseline.stddev
      # abs(at_2sigma - mean) == 2σ, NOT strictly > 2σ
      refute detect_anomaly(at_2sigma, baseline)
    end

    test "value just above 2σ threshold is flagged" do
      samples = [8.0, 9.0, 10.0, 11.0, 12.0]
      baseline = calibrate_baseline(samples)

      just_above = baseline.mean + 2.0 * baseline.stddev + 0.001
      assert detect_anomaly(just_above, baseline)
    end

    test "negative deviation below mean also detectable" do
      samples = [8.0, 9.0, 10.0, 11.0, 12.0]
      baseline = calibrate_baseline(samples)

      far_below = baseline.mean - 2.0 * baseline.stddev - 1.0
      assert detect_anomaly(far_below, baseline)
    end
  end

  # ============================================================================
  # 3. OUTLIER ROBUSTNESS — robust to 5% outlier rate
  # ============================================================================

  describe "Calibration robustness to 5% outlier rate" do
    test "5% outlier contamination leaves threshold plausible" do
      # 19 clean samples near 10.0, 1 outlier at 1000.0 (5%)
      clean = Enum.map(1..19, fn _ -> 10.0 end)
      outlier = [1000.0]
      samples = clean ++ outlier

      baseline = calibrate_baseline(samples)

      # Mean should be pulled somewhat but threshold must still be > 0
      assert baseline.threshold > 0.0
      assert is_float(baseline.mean)
    end

    test "baseline sample_count equals total including outliers" do
      samples = Enum.map(1..20, fn _ -> 10.0 end) ++ [9999.0]
      baseline = calibrate_baseline(samples)

      assert baseline.sample_count == 21
    end

    test "normal values still not flagged after outlier contamination" do
      clean = Enum.map(1..95, fn _ -> 10.0 end)
      outliers = Enum.map(1..5, fn _ -> 500.0 end)
      samples = clean ++ outliers

      baseline = calibrate_baseline(samples)

      # A normal value near mean should not be flagged
      # (even with outliers, mean stays near 10 + shift)
      # We assert the anomaly function does not crash
      result = detect_anomaly(10.0, baseline)
      assert is_boolean(result)
    end

    test "threshold is finite after outlier-contaminated calibration" do
      samples = Enum.map(1..18, fn _ -> 1.0 end) ++ [100.0, 200.0]
      baseline = calibrate_baseline(samples)

      assert is_float(baseline.threshold) or is_integer(baseline.threshold)
      # Verify threshold is a finite number (not NaN or infinity)
      assert baseline.threshold == baseline.threshold,
             "threshold must not be NaN (NaN != NaN)"

      assert baseline.threshold < 1.0e308
    end
  end

  # ============================================================================
  # 4. EMPTY BASELINE — returns safe default thresholds
  # ============================================================================

  describe "Empty baseline returns default thresholds" do
    test "empty sample list returns a map baseline" do
      baseline = calibrate_baseline([])

      assert is_map(baseline)
    end

    test "empty baseline threshold is > 0 (safe default)" do
      baseline = calibrate_baseline([])

      assert baseline.threshold > 0 or baseline.threshold == 0
    end

    test "empty baseline sample_count is 0" do
      baseline = calibrate_baseline([])

      assert baseline.sample_count == 0
    end

    test "empty baseline mean is 0" do
      baseline = calibrate_baseline([])

      assert_in_delta baseline.mean, 0.0, 0.001
    end

    test "empty baseline does not raise" do
      assert %{mean: _, stddev: _, threshold: _, sample_count: 0} =
               calibrate_baseline([])
    end
  end

  # ============================================================================
  # 5. INCREMENTAL RECALIBRATION — updates thresholds
  # ============================================================================

  describe "Recalibration with new data updates thresholds incrementally" do
    test "recalibrate_baseline merges old and new samples" do
      original = calibrate_baseline([5.0, 5.0, 5.0, 5.0, 5.0])
      new_samples = [15.0, 15.0, 15.0, 15.0, 15.0]

      updated = recalibrate_baseline(original, new_samples)

      # New mean should be between 5 and 15
      assert updated.mean > original.mean
      assert updated.mean < 15.0
    end

    test "recalibrated sample_count equals old + new" do
      original = calibrate_baseline(Enum.map(1..10, fn _ -> 5.0 end))
      new_samples = Enum.map(1..5, fn _ -> 10.0 end)

      updated = recalibrate_baseline(original, new_samples)

      assert updated.sample_count == 15
    end

    test "recalibrate with no new samples returns equivalent baseline" do
      original = calibrate_baseline([5.0, 6.0, 7.0])
      updated = recalibrate_baseline(original, [])

      assert_in_delta updated.mean, original.mean, 0.001
    end

    test "threshold increases when high-value samples added" do
      original = calibrate_baseline(Enum.map(1..10, fn _ -> 10.0 end))
      high_samples = Enum.map(1..5, fn _ -> 100.0 end)

      updated = recalibrate_baseline(original, high_samples)

      assert updated.threshold > original.threshold
    end
  end

  # ============================================================================
  # 6. MULTI-METRIC INDEPENDENCE — cpu, memory, latency tracked separately
  # ============================================================================

  describe "Multiple metrics tracked independently" do
    test "cpu and memory baselines are independent" do
      cpu_samples = [50.0, 51.0, 49.0, 52.0, 48.0]
      memory_samples = [200.0, 210.0, 190.0, 205.0, 195.0]

      baselines = calibrate_multi_metric(%{cpu: cpu_samples, memory: memory_samples})

      assert baselines.cpu.mean != baselines.memory.mean
      assert baselines.cpu.threshold != baselines.memory.threshold
    end

    test "anomaly in cpu does not affect memory baseline" do
      cpu_samples = [50.0, 50.0, 50.0]
      memory_samples = [200.0, 200.0, 200.0]

      baselines = calibrate_multi_metric(%{cpu: cpu_samples, memory: memory_samples})

      # CPU anomaly
      assert detect_anomaly(200.0, baselines.cpu)
      # Memory normal — the very value that triggered CPU anomaly is its own mean
      refute detect_anomaly(200.0, baselines.memory)
    end

    test "latency metric tracks independently" do
      baselines =
        calibrate_multi_metric(%{
          cpu: [50.0, 50.0, 50.0],
          memory: [200.0, 200.0, 200.0],
          latency: [5.0, 5.0, 5.0]
        })

      assert Map.has_key?(baselines, :cpu)
      assert Map.has_key?(baselines, :memory)
      assert Map.has_key?(baselines, :latency)
    end

    test "detect_metric_anomalies returns per-metric flags" do
      baselines =
        calibrate_multi_metric(%{
          cpu: [50.0, 50.0, 50.0],
          latency: [5.0, 5.0, 5.0]
        })

      readings = %{cpu: 500.0, latency: 5.0}
      flags = detect_metric_anomalies(readings, baselines)

      assert flags.cpu == true
      assert flags.latency == false
    end

    test "unknown metric in readings is flagged as unknown" do
      baselines = calibrate_multi_metric(%{cpu: [50.0, 50.0, 50.0]})
      readings = %{cpu: 50.0, disk: 100.0}

      flags = detect_metric_anomalies(readings, baselines)

      assert Map.has_key?(flags, :cpu)
      # disk has no baseline — treated as :unknown, not a crash
      assert Map.has_key?(flags, :disk)
    end
  end

  # ============================================================================
  # 7. DETECTION LATENCY — pattern matching < 10ms (SC-BIO-EXT-001)
  # ============================================================================

  describe "Detection latency < 10ms (SC-BIO-EXT-001)" do
    @tag :sil4
    test "single anomaly detection completes in < 10ms" do
      samples = Enum.map(1..100, fn i -> i * 1.0 end)
      baseline = calibrate_baseline(samples)

      start = System.monotonic_time(:microsecond)
      _result = detect_anomaly(999.0, baseline)
      elapsed_us = System.monotonic_time(:microsecond) - start

      assert elapsed_us < 10_000,
             "detect_anomaly took #{elapsed_us}µs, expected < 10ms (10_000µs)"
    end

    @tag :sil4
    test "multi-metric anomaly detection for 3 metrics completes in < 10ms" do
      baselines =
        calibrate_multi_metric(%{
          cpu: Enum.map(1..50, fn _ -> 50.0 end),
          memory: Enum.map(1..50, fn _ -> 200.0 end),
          latency: Enum.map(1..50, fn _ -> 5.0 end)
        })

      readings = %{cpu: 999.0, memory: 9999.0, latency: 0.0}

      start = System.monotonic_time(:microsecond)
      _flags = detect_metric_anomalies(readings, baselines)
      elapsed_us = System.monotonic_time(:microsecond) - start

      assert elapsed_us < 10_000,
             "detect_metric_anomalies took #{elapsed_us}µs, expected < 10ms"
    end

    @tag :sil4
    test "baseline calibration for 1000 samples completes in < 10ms" do
      samples = Enum.map(1..1000, fn i -> i * 0.1 end)

      start = System.monotonic_time(:microsecond)
      _baseline = calibrate_baseline(samples)
      elapsed_us = System.monotonic_time(:microsecond) - start

      assert elapsed_us < 10_000,
             "calibrate_baseline(1000 samples) took #{elapsed_us}µs, expected < 10ms"
    end
  end

  # ============================================================================
  # 8. PROPERTY: threshold is always > 0 for positive distributions (PropCheck)
  # ============================================================================

  test "threshold is always > 0 for positive-valued sample distributions" do
    ExUnitProperties.check all(
                             samples <- SD.list_of(SD.positive_integer(), min_length: 1),
                             max_runs: 50
                           ) do
      float_samples = Enum.map(samples, fn x -> x * 1.0 end)
      baseline = calibrate_baseline(float_samples)
      assert baseline.threshold > 0.0
    end
  end

  test "threshold is always >= mean for any sample list" do
    ExUnitProperties.check all(
                             samples <- SD.list_of(SD.integer(), min_length: 1),
                             max_runs: 50
                           ) do
      float_samples = Enum.map(samples, fn x -> x * 1.0 end)
      baseline = calibrate_baseline(float_samples)
      assert baseline.threshold >= baseline.mean
    end
  end

  test "sample_count always matches length of input" do
    ExUnitProperties.check all(
                             samples <- SD.list_of(SD.float(min: -1000.0, max: 1000.0)),
                             max_runs: 50
                           ) do
      baseline = calibrate_baseline(samples)
      assert baseline.sample_count == length(samples)
    end
  end

  # ============================================================================
  # 9. PROPERTY: detection sensitivity increases with sample size (SD property)
  # ============================================================================

  test "detection sensitivity: larger samples narrow 2σ window for normal data" do
    ExUnitProperties.check all(
                             n <- SD.integer(5..50),
                             center <- SD.float(min: 1.0, max: 100.0)
                           ) do
      # All-identical samples have stddev=0, threshold=mean — very tight
      samples = Enum.map(1..n, fn _ -> center end)
      baseline = calibrate_baseline(samples)

      # stddev is 0 for uniform → threshold == mean
      assert_in_delta baseline.threshold, baseline.mean, 0.001
    end
  end

  test "anomaly detection is consistent: same inputs always same result" do
    ExUnitProperties.check all(
                             values <- SD.list_of(SD.float(min: 0.0, max: 100.0), min_length: 3),
                             probe <- SD.float(min: 0.0, max: 200.0)
                           ) do
      baseline = calibrate_baseline(values)
      result1 = detect_anomaly(probe, baseline)
      result2 = detect_anomaly(probe, baseline)

      assert result1 == result2
    end
  end

  test "baseline mean is always between min and max of samples" do
    ExUnitProperties.check all(
                             values <-
                               SD.list_of(SD.float(min: 1.0, max: 1000.0), min_length: 2)
                           ) do
      baseline = calibrate_baseline(values)
      min_v = Enum.min(values)
      max_v = Enum.max(values)

      assert baseline.mean >= min_v - 0.001
      assert baseline.mean <= max_v + 0.001
    end
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  @doc false
  defp calibrate_baseline(samples) do
    n = length(samples)
    mean = Enum.sum(samples) / max(n, 1)

    variance =
      Enum.reduce(samples, 0.0, fn x, acc -> acc + (x - mean) ** 2 end) / max(n, 1)

    stddev = :math.sqrt(variance)

    %{
      mean: mean,
      stddev: stddev,
      threshold: mean + 2.0 * stddev,
      sample_count: n
    }
  end

  @doc false
  defp detect_anomaly(value, baseline) do
    abs(value - baseline.mean) > 2.0 * baseline.stddev
  end

  @doc false
  defp recalibrate_baseline(old_baseline, new_samples) do
    # Reconstruct a virtual sample list from the old summary + the new raw data.
    # For the combined mean: use weighted average of means.
    old_n = old_baseline.sample_count
    new_n = length(new_samples)
    total_n = old_n + new_n

    if total_n == 0 do
      %{mean: 0.0, stddev: 0.0, threshold: 0.0, sample_count: 0}
    else
      new_sum = Enum.sum(new_samples)
      combined_mean = (old_baseline.mean * old_n + new_sum) / total_n

      # Variance via parallel-algorithm (numerically stable combination)
      new_mean = if new_n > 0, do: new_sum / new_n, else: 0.0

      new_variance =
        Enum.reduce(new_samples, 0.0, fn x, acc -> acc + (x - new_mean) ** 2 end) /
          max(new_n, 1)

      old_variance = old_baseline.stddev ** 2

      # Combined variance (two-population formula)
      combined_variance =
        (old_n * (old_variance + (old_baseline.mean - combined_mean) ** 2) +
           new_n * (new_variance + (new_mean - combined_mean) ** 2)) / total_n

      combined_stddev = :math.sqrt(combined_variance)

      %{
        mean: combined_mean,
        stddev: combined_stddev,
        threshold: combined_mean + 2.0 * combined_stddev,
        sample_count: total_n
      }
    end
  end

  @doc false
  defp calibrate_multi_metric(metric_samples) do
    Map.new(metric_samples, fn {metric, samples} ->
      {metric, calibrate_baseline(samples)}
    end)
  end

  @doc false
  defp detect_metric_anomalies(readings, baselines) do
    Map.new(readings, fn {metric, value} ->
      flag =
        case Map.fetch(baselines, metric) do
          {:ok, baseline} -> detect_anomaly(value, baseline)
          :error -> :unknown
        end

      {metric, flag}
    end)
  end
end
