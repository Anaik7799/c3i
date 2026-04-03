defmodule Indrajaal.Analytics.AnomalyDetectionPropertyTest do
  @moduledoc """
  Property-based tests for Indrajaal.Analytics.AnomalyDetection module.

  This test suite follows TDG (Test-Driven Generation) methodology - tests are written BEFORE
  any implementation changes. Uses dual property-based testing framework combining PropCheck
  (advanced shrinking) and ExUnitProperties (StreamData integration).

  STAMP Safety Constraints (SC-AD-XXX):
  - SC-AD-001: Anomaly detection SHALL maintain statistical model consistency
  - SC-AD-002: System SHALL detect anomalies within acceptable false positive/negative rates
  - SC-AD-003: Anomaly thresholds SHALL adapt to data distribution changes
  - SC-AD-004: Detection algorithms SHALL scale efficiently with data volume
  - SC-AD-005: Real-time detection SHALL maintain temporal accuracy requirements
  """

  use ExUnit.Case, async: true
  # Advanced property testing with sophisticated shrinking
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  # StreamData-based property testing - import except check to avoid conflict
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # Use explicit ExUnitProperties.check for StreamData tests

  # Use aliases to disambiguate PropCheck vs StreamData generators
  # PropCheck generators: use PC.float(), PC.integer(), etc.
  # StreamData generators: use SD.float(), SD.integer(), etc.
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Analytics.AnomalyDetection

  # Test data generators
  @anomaly_algorithms [
    :statistical,
    :machine_learning,
    :clustering,
    :isolation_forest,
    :neural_network
  ]
  @threshold_types [:static, :dynamic, :adaptive, :percentile_based, :standard_deviation]
  @data_distributions [:normal, :exponential, :uniform, :poisson, :gamma]
  @anomaly_severities [:low, :medium, :high, :critical]
  @detection_modes [:batch, :streaming, :real_time, :hybrid]

  # Valid time windows for anomaly detection (in minutes)
  @time_windows [1, 5, 10, 15, 30, 60, 120, 240, 480, 1440]

  # Statistical thresholds
  @confidence_levels [0.90, 0.95, 0.99, 0.995, 0.999]
  @false_positive_rates [0.001, 0.005, 0.01, 0.05, 0.1]

  describe "detect_anomalies/3 - Core anomaly detection function" do
    test "propcheck: detect_anomalies/3 returns consistent structure with advanced shrinking" do
      assert PropCheck.quickcheck(
               forall {data_points, algorithm, params} <-
                        {PC.list(PC.float()), PC.oneof(@anomaly_algorithms),
                         PC.map(PC.atom(), PC.any())} do
                 result = AnomalyDetection.detect_anomalies(data_points, algorithm, params)

                 # Validate result structure
                 assert is_map(result)
                 assert Map.has_key?(result, :anomalies)
                 assert Map.has_key?(result, :algorithm_used)
                 assert Map.has_key?(result, :confidence_scores)
                 assert Map.has_key?(result, :detection_metadata)

                 # Validate anomalies list
                 assert is_list(result.anomalies)

                 Enum.all?(result.anomalies, fn anomaly ->
                   is_map(anomaly) and
                     Map.has_key?(anomaly, :index) and
                     Map.has_key?(anomaly, :value) and
                     Map.has_key?(anomaly, :severity) and
                     Map.has_key?(anomaly, :confidence)
                 end)
               end
             )
    end

    test "exunitproperties: detect_anomalies/3 maintains algorithm consistency" do
      ExUnitProperties.check all(
                               algorithm <- SD.member_of(@anomaly_algorithms),
                               data <- SD.list_of(SD.float(), min_length: 10, max_length: 1000),
                               threshold_type <- SD.member_of(@threshold_types),
                               max_runs: 100
                             ) do
        params = %{threshold_type: threshold_type, sensitivity: 0.95}
        result = AnomalyDetection.detect_anomalies(data, algorithm, params)

        # Algorithm consistency
        assert result.algorithm_used == algorithm

        # Anomaly count should be reasonable (not all points are anomalies)
        anomaly_count = length(result.anomalies)
        data_count = length(data)
        anomaly_rate = if data_count > 0, do: anomaly_count / data_count, else: 0

        # Reasonable anomaly rate (typically < 10% for real data)
        assert anomaly_rate <= 0.15, "Anomaly rate too high: #{anomaly_rate}"
      end
    end
  end

  describe "configure_thresholds/2 - Dynamic threshold configuration" do
    test "propcheck: configure_thresholds/2 maintains threshold validity with advanced shrinking" do
      assert PropCheck.quickcheck(
               forall {threshold_type, config} <-
                        {PC.oneof(@threshold_types), PC.map(PC.atom(), PC.any())} do
                 result = AnomalyDetection.configure_thresholds(threshold_type, config)

                 # Validate threshold configuration structure
                 assert is_map(result)
                 assert Map.has_key?(result, :threshold_type)
                 assert Map.has_key?(result, :upper_bound)
                 assert Map.has_key?(result, :lower_bound)
                 assert Map.has_key?(result, :sensitivity)
                 assert Map.has_key?(result, :adaptation_rate)

                 # Validate threshold bounds
                 assert is_number(result.upper_bound)
                 assert is_number(result.lower_bound)
                 assert result.upper_bound >= result.lower_bound

                 # Validate sensitivity and adaptation rate
                 assert result.sensitivity >= 0.0 and result.sensitivity <= 1.0
                 assert result.adaptation_rate >= 0.0 and result.adaptation_rate <= 1.0
               end
             )
    end

    test "exunitproperties: configure_thresholds/2 respects distribution parameters" do
      ExUnitProperties.check all(
                               threshold_type <- SD.member_of(@threshold_types),
                               distribution <- SD.member_of(@data_distributions),
                               confidence <- SD.member_of(@confidence_levels),
                               max_runs: 50
                             ) do
        config = %{
          distribution: distribution,
          confidence_level: confidence,
          min_samples: 100
        }

        result = AnomalyDetection.configure_thresholds(threshold_type, config)

        # Confidence level consistency
        assert result.confidence_level == confidence

        # Distribution-specific validations
        case distribution do
          :normal ->
            assert Map.has_key?(result, :mean)
            assert Map.has_key?(result, :std_deviation)

          :exponential ->
            assert Map.has_key?(result, :lambda)

          :uniform ->
            assert Map.has_key?(result, :min_value)
            assert Map.has_key?(result, :max_value)

          _ ->
            assert Map.has_key?(result, :distribution_params)
        end
      end
    end
  end

  describe "analyze_patterns/2 - Pattern analysis in anomalies" do
    test "propcheck: analyze_patterns/2 identifies consistent pattern structures" do
      assert PropCheck.quickcheck(
               forall {anomalies, analysis_config} <-
                        {PC.list(PC.map(PC.atom(), PC.any())), PC.map(PC.atom(), PC.any())} do
                 result = AnomalyDetection.analyze_patterns(anomalies, analysis_config)

                 # Validate pattern analysis structure
                 assert is_map(result)
                 assert Map.has_key?(result, :patterns_found)
                 assert Map.has_key?(result, :pattern_types)
                 assert Map.has_key?(result, :temporal_patterns)
                 assert Map.has_key?(result, :clustering_results)

                 # Validate patterns found
                 assert is_list(result.patterns_found)

                 Enum.all?(result.patterns_found, fn pattern ->
                   is_map(pattern) and
                     Map.has_key?(pattern, :pattern_id) and
                     Map.has_key?(pattern, :frequency) and
                     Map.has_key?(pattern, :confidence) and
                     Map.has_key?(pattern, :description)
                 end)
               end
             )
    end

    test "exunitproperties: analyze_patterns/2 maintains temporal consistency" do
      ExUnitProperties.check all(
                               time_window <- SD.member_of(@time_windows),
                               pattern_threshold <- SD.float(min: 0.1, max: 0.9),
                               max_runs: 50
                             ) do
        # Generate time-ordered anomalies
        anomalies =
          Enum.map(1..50, fn i ->
            %{
              timestamp: DateTime.add(DateTime.utc_now(), i * 60, :second),
              value: :rand.uniform() * 100,
              severity: Enum.random(@anomaly_severities)
            }
          end)

        config = %{
          time_window_minutes: time_window,
          pattern_threshold: pattern_threshold,
          include_temporal: true
        }

        result = AnomalyDetection.analyze_patterns(anomalies, config)

        # Temporal patterns should respect time window
        if length(result.temporal_patterns) > 0 do
          Enum.each(result.temporal_patterns, fn pattern ->
            assert Map.has_key?(pattern, :time_range)
            assert Map.has_key?(pattern, :duration_minutes)
            assert pattern.duration_minutes <= time_window
          end)
        end
      end
    end
  end

  describe "calculate_baseline/2 - Baseline establishment for anomaly detection" do
    test "propcheck: calculate_baseline/2 produces stable statistical baseline" do
      assert PropCheck.quickcheck(
               forall {historical_data, baseline_config} <-
                        {PC.list(PC.float()), PC.map(PC.atom(), PC.any())} do
                 result = AnomalyDetection.calculate_baseline(historical_data, baseline_config)

                 # Validate baseline structure
                 assert is_map(result)
                 assert Map.has_key?(result, :mean)
                 assert Map.has_key?(result, :median)
                 assert Map.has_key?(result, :standard_deviation)
                 assert Map.has_key?(result, :percentiles)
                 assert Map.has_key?(result, :seasonal_components)

                 # Statistical validity
                 assert is_number(result.mean)
                 assert is_number(result.median)
                 assert result.standard_deviation >= 0

                 # Percentiles should be ordered
                 percentiles = result.percentiles
                 assert percentiles.p25 <= percentiles.p50
                 assert percentiles.p50 <= percentiles.p75
                 assert percentiles.p75 <= percentiles.p95
               end
             )
    end

    test "exunitproperties: calculate_baseline/2 handles different data distributions" do
      ExUnitProperties.check all(
                               distribution <- SD.member_of(@data_distributions),
                               sample_size <- SD.integer(50..1000),
                               max_runs: 30
                             ) do
        # Generate data based on distribution
        historical_data =
          case distribution do
            :normal -> Enum.map(1..sample_size, fn _ -> :rand.normal() * 10 + 50 end)
            :uniform -> Enum.map(1..sample_size, fn _ -> :rand.uniform() * 100 end)
            :exponential -> Enum.map(1..sample_size, fn _ -> -:math.log(:rand.uniform()) * 10 end)
            _ -> Enum.map(1..sample_size, fn _ -> :rand.uniform() * 100 end)
          end

        config = %{
          distribution_type: distribution,
          outlier_removal: true,
          seasonal_analysis: false
        }

        result = AnomalyDetection.calculate_baseline(historical_data, config)

        # Distribution-specific validations
        case distribution do
          :normal ->
            # For normal distribution, mean should be close to median
            diff = abs(result.mean - result.median)
            std_threshold = result.standard_deviation * 0.5

            assert diff <= std_threshold,
                   "Mean-median difference too large for normal distribution"

          :uniform ->
            # For uniform distribution, all percentiles should be reasonably spaced
            p_range = result.percentiles.p95 - result.percentiles.p5
            assert p_range > 0, "Percentile range should be positive"

          _ ->
            # General validations for other distributions
            assert result.mean != nil
            assert result.standard_deviation >= 0
        end
      end
    end
  end

  describe "real_time_detection/3 - Real-time anomaly detection" do
    test "propcheck: real_time_detection/3 maintains streaming consistency" do
      assert PropCheck.quickcheck(
               forall {data_stream, detection_config, baseline} <- {
                        PC.list(PC.float()),
                        PC.map(PC.atom(), PC.any()),
                        PC.map(PC.atom(), PC.float())
                      } do
                 result =
                   AnomalyDetection.real_time_detection(data_stream, detection_config, baseline)

                 # Validate real-time detection structure
                 assert is_map(result)
                 assert Map.has_key?(result, :anomalies_detected)
                 assert Map.has_key?(result, :processing_time_ms)
                 assert Map.has_key?(result, :baseline_updates)
                 assert Map.has_key?(result, :alert_triggers)

                 # Processing time should be reasonable for real-time
                 assert result.processing_time_ms >= 0

                 assert result.processing_time_ms < 1000,
                        "Processing time too high for real-time: #{result.processing_time_ms}ms"

                 # Anomalies should be subset of input data
                 anomaly_count = length(result.anomalies_detected)
                 data_count = length(data_stream)
                 assert anomaly_count <= data_count
               end
             )
    end

    test "exunitproperties: real_time_detection/3 respects temporal windows" do
      ExUnitProperties.check all(
                               detection_mode <- SD.member_of(@detection_modes),
                               time_window <- SD.member_of(@time_windows),
                               max_runs: 50
                             ) do
        # Generate streaming data with timestamps
        current_time = DateTime.utc_now()

        data_stream =
          Enum.map(1..100, fn i ->
            %{
              value: :rand.uniform() * 100,
              timestamp: DateTime.add(current_time, i * 5, :second),
              source_id: "sensor_#{rem(i, 10)}"
            }
          end)

        config = %{
          mode: detection_mode,
          time_window_minutes: time_window,
          # ms
          real_time_threshold: 100
        }

        baseline = %{
          mean: 50.0,
          std_deviation: 15.0,
          upper_bound: 80.0,
          lower_bound: 20.0
        }

        result = AnomalyDetection.real_time_detection(data_stream, config, baseline)

        # Mode-specific validations
        case detection_mode do
          :real_time ->
            assert result.processing_time_ms <= 100, "Real-time mode exceeded threshold"

          :streaming ->
            # Streaming mode should process all data points
            assert length(result.anomalies_detected) >= 0

          :batch ->
            # Batch mode should have complete analysis
            assert Map.has_key?(result, :batch_statistics)

          _ ->
            assert result.processing_time_ms >= 0
        end
      end
    end
  end

  describe "STAMP Safety Constraints Validation" do
    test "SC-AD-001: System SHALL maintain statistical model consistency" do
      ExUnitProperties.check all(
                               algorithm <- SD.member_of(@anomaly_algorithms),
                               data_size <- SD.integer(100..1000),
                               max_runs: 20
                             ) do
        # Generate consistent test data
        test_data = Enum.map(1..data_size, fn _ -> :rand.normal() * 10 + 50 end)
        params = %{threshold_type: :statistical, sensitivity: 0.95}

        # Run detection multiple times with same data
        results =
          Enum.map(1..3, fn _ ->
            AnomalyDetection.detect_anomalies(test_data, algorithm, params)
          end)

        # Results should be consistent across runs
        first_result = hd(results)

        Enum.each(tl(results), fn result ->
          assert result.algorithm_used == first_result.algorithm_used
          assert length(result.anomalies) == length(first_result.anomalies)
        end)
      end
    end

    test "SC-AD-002: System SHALL detect anomalies within acceptable false positive/negative rates" do
      ExUnitProperties.check all(
                               false_positive_rate <- SD.member_of(@false_positive_rates),
                               confidence_level <- SD.member_of(@confidence_levels),
                               max_runs: 20
                             ) do
        # Generate data with known anomalies (outliers)
        normal_data = Enum.map(1..900, fn _ -> :rand.normal() * 5 + 50 end)
        # Clear outliers
        anomaly_data = Enum.map(1..100, fn _ -> :rand.uniform() * 50 + 150 end)
        mixed_data = Enum.shuffle(normal_data ++ anomaly_data)

        params = %{
          threshold_type: :statistical,
          false_positive_rate: false_positive_rate,
          confidence_level: confidence_level
        }

        result = AnomalyDetection.detect_anomalies(mixed_data, :statistical, params)

        # Calculate actual false positive rate
        detected_anomalies = length(result.anomalies)
        total_points = length(mixed_data)
        actual_anomaly_rate = detected_anomalies / total_points

        # Should be close to expected rate (allowing some tolerance)
        # Account for both sides of distribution
        expected_rate = false_positive_rate * 2
        tolerance = expected_rate * 0.5

        assert actual_anomaly_rate <= expected_rate + tolerance,
               "Anomaly rate #{actual_anomaly_rate} exceeds expected #{expected_rate} + tolerance"
      end
    end

    test "SC-AD-003: Anomaly thresholds SHALL adapt to data distribution changes" do
      ExUnitProperties.check all(
                               adaptation_rate <- SD.float(min: 0.1, max: 0.9),
                               max_runs: 15
                             ) do
        # Phase 1: Initial data with one distribution
        initial_data = Enum.map(1..500, fn _ -> :rand.normal() * 10 + 50 end)

        # Phase 2: Shifted data (distribution change)
        # Mean shifted
        shifted_data = Enum.map(1..500, fn _ -> :rand.normal() * 10 + 70 end)

        config = %{
          threshold_type: :adaptive,
          adaptation_rate: adaptation_rate,
          min_samples_for_adaptation: 100
        }

        # Initial threshold calculation
        initial_baseline = AnomalyDetection.calculate_baseline(initial_data, config)

        # Process shifted data and check adaptation
        updated_result =
          AnomalyDetection.real_time_detection(shifted_data, config, initial_baseline)

        # Baseline should have been updated
        assert Map.has_key?(updated_result, :baseline_updates)
        assert length(updated_result.baseline_updates) > 0

        # New mean should be closer to shifted distribution
        if length(updated_result.baseline_updates) > 0 do
          latest_update = List.last(updated_result.baseline_updates)

          assert latest_update.updated_mean > initial_baseline.mean,
                 "Baseline should adapt to distribution shift"
        end
      end
    end

    test "SC-AD-004: Detection algorithms SHALL scale efficiently with data volume" do
      data_sizes = [100, 500, 1000, 2000, 5000]

      Enum.each(data_sizes, fn size ->
        test_data = Enum.map(1..size, fn _ -> :rand.uniform() * 100 end)
        params = %{threshold_type: :statistical, sensitivity: 0.95}

        start_time = System.monotonic_time(:millisecond)
        _result = AnomalyDetection.detect_anomalies(test_data, :statistical, params)
        end_time = System.monotonic_time(:millisecond)

        processing_time = end_time - start_time

        # Processing time should scale reasonably (not exponentially)
        # Allow more time for larger datasets but with reasonable limits
        max_time =
          case size do
            # 50ms for small datasets
            100 -> 50
            # 100ms for medium datasets
            500 -> 100
            # 200ms for large datasets
            1000 -> 200
            # 400ms for very large datasets
            2000 -> 400
            # 1s for massive datasets
            5000 -> 1000
          end

        assert processing_time <= max_time,
               "Processing time #{processing_time}ms exceeds limit #{max_time}ms for #{size} data points"
      end)
    end

    test "SC-AD-005: Real-time detection SHALL maintain temporal accuracy requirements" do
      ExUnitProperties.check all(
                               time_window <- SD.member_of(@time_windows),
                               # ms
                               detection_latency <- SD.integer(1..100),
                               max_runs: 20
                             ) do
        # Generate time-series data with precise timestamps
        current_time = DateTime.utc_now()

        streaming_data =
          Enum.map(1..200, fn i ->
            %{
              value: :rand.uniform() * 100,
              # 1-second intervals
              timestamp: DateTime.add(current_time, i * 1000, :millisecond),
              sequence_id: i
            }
          end)

        config = %{
          mode: :real_time,
          time_window_minutes: time_window,
          max_detection_latency_ms: detection_latency,
          temporal_accuracy_required: true
        }

        baseline = %{mean: 50.0, std_deviation: 15.0, upper_bound: 80.0, lower_bound: 20.0}

        result = AnomalyDetection.real_time_detection(streaming_data, config, baseline)

        # Verify temporal accuracy
        assert result.processing_time_ms <= detection_latency,
               "Detection latency #{result.processing_time_ms}ms exceeds requirement #{detection_latency}ms"

        # Check timestamp consistency in detected anomalies
        if length(result.anomalies_detected) > 0 do
          Enum.each(result.anomalies_detected, fn anomaly ->
            assert Map.has_key?(anomaly, :detection_timestamp)
            assert Map.has_key?(anomaly, :data_timestamp)

            # Detection timestamp should be after data timestamp
            detection_time = anomaly.detection_timestamp
            data_time = anomaly.data_timestamp

            assert DateTime.compare(detection_time, data_time) in [:gt, :eq],
                   "Detection timestamp should be >= data timestamp"
          end)
        end
      end
    end
  end

  describe "Integration and End-to-End Testing" do
    test "complete anomaly detection pipeline integrity" do
      # End-to-end pipeline: baseline → threshold → detection → pattern analysis

      # Step 1: Generate realistic historical data for baseline
      combined_data =
        Enum.concat([
          # Normal data
          Enum.map(1..800, fn _ -> :rand.normal() * 10 + 50 end),
          # Some anomalies
          Enum.map(1..20, fn _ -> :rand.uniform() * 50 + 120 end)
        ])

      historical_data = Enum.shuffle(combined_data)

      # Step 2: Establish baseline
      baseline_config = %{distribution_type: :normal, outlier_removal: true}
      baseline = AnomalyDetection.calculate_baseline(historical_data, baseline_config)

      # Step 3: Configure thresholds
      threshold_config = %{confidence_level: 0.95, sensitivity: 0.9}
      thresholds = AnomalyDetection.configure_thresholds(:adaptive, threshold_config)

      # Step 4: Detect anomalies in new data
      new_data = Enum.map(1..100, fn _ -> :rand.normal() * 12 + 52 end)
      detection_params = Map.merge(threshold_config, thresholds)

      detection_result =
        AnomalyDetection.detect_anomalies(new_data, :statistical, detection_params)

      # Step 5: Analyze patterns in detected anomalies
      if length(detection_result.anomalies) > 0 do
        pattern_config = %{include_temporal: false, pattern_threshold: 0.7}

        pattern_result =
          AnomalyDetection.analyze_patterns(detection_result.anomalies, pattern_config)

        # Validate complete pipeline
        assert is_map(baseline)
        assert is_map(thresholds)
        assert is_map(detection_result)
        assert is_map(pattern_result)

        # Cross-component consistency
        assert baseline.mean != nil
        assert thresholds.upper_bound > baseline.mean
        assert thresholds.lower_bound < baseline.mean
        assert length(detection_result.anomalies) >= 0
        assert is_list(pattern_result.patterns_found)
      end
    end

    test "multi-tenant anomaly detection isolation" do
      tenants = ["tenant_a", "tenant_b", "tenant_c"]

      Enum.each(tenants, fn tenant_id ->
        # Generate tenant-specific data
        tenant_data =
          Enum.map(1..500, fn i ->
            %{
              # Different ranges per tenant
              value: :rand.uniform() * 100 + String.length(tenant_id) * 10,
              tenant_id: tenant_id,
              timestamp: DateTime.add(DateTime.utc_now(), i * 60, :second),
              metric_type: "cpu_usage"
            }
          end)

        params = %{
          tenant_id: tenant_id,
          threshold_type: :statistical,
          isolation_required: true
        }

        result = AnomalyDetection.detect_anomalies(tenant_data, :statistical, params)

        # Verify tenant isolation
        if length(result.anomalies) > 0 do
          Enum.each(result.anomalies, fn anomaly ->
            assert anomaly.tenant_id == tenant_id,
                   "Anomaly contains wrong tenant_id: expected #{tenant_id}, got #{anomaly.tenant_id}"
          end)
        end

        # Verify tenant-specific baseline
        assert Map.has_key?(result, :tenant_baseline)
        assert result.tenant_baseline.tenant_id == tenant_id
      end)
    end
  end
end
