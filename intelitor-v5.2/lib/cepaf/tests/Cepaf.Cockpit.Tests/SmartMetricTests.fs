/// SmartMetric Unit Tests
/// Tests for metric calculations, trend detection, and staleness
module Cepaf.Cockpit.Tests.SmartMetricTests

open System
open Expecto

// ============================================================================
// Test Types (Local test-only definitions)
// ============================================================================

/// Simple metric value for testing
type TestMetricValue = {
    Value: float
    Timestamp: DateTime
    Source: string
}

// ============================================================================
// Test Data Generators
// ============================================================================

let createMetricValue value timestamp : TestMetricValue =
    { Value = value
      Timestamp = timestamp
      Source = "test" }

let createMetricSeries values =
    values
    |> List.mapi (fun i v ->
        createMetricValue v (DateTime.UtcNow.AddSeconds(float -i)))

// ============================================================================
// Unit Tests: Metric Value Calculations
// ============================================================================

[<Tests>]
let metricValueTests =
    testList "MetricValue" [
        test "should create metric with valid value" {
            let metric = createMetricValue 42.0 DateTime.UtcNow
            Expect.equal metric.Value 42.0 "Value should be 42"
        }

        test "should detect stale metric (>30s)" {
            let metric = createMetricValue 42.0 (DateTime.UtcNow.AddSeconds(-45.0))
            let isStale = (DateTime.UtcNow - metric.Timestamp).TotalSeconds > 30.0
            Expect.isTrue isStale "Metric should be stale after 30s"
        }

        test "should not be stale within 30s" {
            let metric = createMetricValue 42.0 (DateTime.UtcNow.AddSeconds(-15.0))
            let isStale = (DateTime.UtcNow - metric.Timestamp).TotalSeconds > 30.0
            Expect.isFalse isStale "Metric should not be stale within 30s"
        }

        test "should calculate age correctly" {
            let timestamp = DateTime.UtcNow.AddMinutes(-5.0)
            let metric = createMetricValue 42.0 timestamp
            let age = DateTime.UtcNow - metric.Timestamp
            Expect.isGreaterThan age.TotalMinutes 4.9 "Age should be ~5 minutes"
            Expect.isLessThan age.TotalMinutes 5.1 "Age should be ~5 minutes"
        }
    ]

// ============================================================================
// Unit Tests: Trend Detection
// ============================================================================

type Trend = Rising | Falling | Stable | Unknown

let detectTrend (values: float list) =
    match values with
    | [] -> Unknown
    | [_] -> Stable
    | first :: rest ->
        let last = List.last values
        let diff = last - first
        let threshold = 0.05 * Math.Abs(first) // 5% threshold
        if diff > threshold then Rising
        elif diff < -threshold then Falling
        else Stable

[<Tests>]
let trendDetectionTests =
    testList "TrendDetection" [
        test "should detect rising trend" {
            let values = [10.0; 12.0; 15.0; 18.0; 22.0]
            let trend = detectTrend values
            Expect.equal trend Rising "Should detect rising trend"
        }

        test "should detect falling trend" {
            let values = [100.0; 95.0; 88.0; 75.0; 60.0]
            let trend = detectTrend values
            Expect.equal trend Falling "Should detect falling trend"
        }

        test "should detect stable trend" {
            let values = [50.0; 50.1; 49.9; 50.0; 50.2]
            let trend = detectTrend values
            Expect.equal trend Stable "Should detect stable trend"
        }

        test "should handle empty values" {
            let trend = detectTrend []
            Expect.equal trend Unknown "Should return Unknown for empty"
        }

        test "should handle single value" {
            let trend = detectTrend [42.0]
            Expect.equal trend Stable "Should return Stable for single value"
        }
    ]

// ============================================================================
// Unit Tests: Health Score Calculation
// ============================================================================

type HealthScore =
    | Healthy
    | Degraded
    | Critical
    | Unknown

let calculateHealthScore (metrics: Map<string, float>) =
    let requiredMetrics = ["cpu"; "memory"; "latency"; "errors"]
    let hasAllMetrics =
        requiredMetrics
        |> List.forall (fun m -> metrics.ContainsKey m)

    if not hasAllMetrics then Unknown
    else
        let cpu = metrics.["cpu"]
        let memory = metrics.["memory"]
        let latency = metrics.["latency"]
        let errors = metrics.["errors"]

        if errors > 10.0 || cpu > 95.0 || memory > 95.0 || latency > 1000.0 then
            Critical
        elif errors > 5.0 || cpu > 80.0 || memory > 80.0 || latency > 500.0 then
            Degraded
        else
            Healthy

[<Tests>]
let healthScoreTests =
    testList "HealthScore" [
        test "should return Healthy for good metrics" {
            let metrics = Map.ofList [
                "cpu", 45.0
                "memory", 60.0
                "latency", 50.0
                "errors", 0.0
            ]
            let score = calculateHealthScore metrics
            Expect.equal score Healthy "Should be Healthy"
        }

        test "should return Degraded for warning metrics" {
            let metrics = Map.ofList [
                "cpu", 85.0
                "memory", 70.0
                "latency", 100.0
                "errors", 2.0
            ]
            let score = calculateHealthScore metrics
            Expect.equal score Degraded "Should be Degraded"
        }

        test "should return Critical for error metrics" {
            let metrics = Map.ofList [
                "cpu", 98.0
                "memory", 70.0
                "latency", 100.0
                "errors", 2.0
            ]
            let score = calculateHealthScore metrics
            Expect.equal score Critical "Should be Critical for high CPU"
        }

        test "should return Critical for high errors" {
            let metrics = Map.ofList [
                "cpu", 50.0
                "memory", 50.0
                "latency", 100.0
                "errors", 15.0
            ]
            let score = calculateHealthScore metrics
            Expect.equal score Critical "Should be Critical for high errors"
        }

        test "should return Unknown for missing metrics" {
            let metrics = Map.ofList [
                "cpu", 50.0
                "memory", 50.0
            ]
            let score = calculateHealthScore metrics
            Expect.equal score Unknown "Should be Unknown for missing metrics"
        }
    ]

// ============================================================================
// Unit Tests: Sparkline Generation
// ============================================================================

let sparklineChars = [| '▁'; '▂'; '▃'; '▄'; '▅'; '▆'; '▇'; '█' |]

let generateSparkline (values: float list) (width: int) =
    if List.isEmpty values then
        String.replicate width " "
    else
        let min = List.min values
        let max = List.max values
        let range = max - min

        let normalize v =
            if range = 0.0 then 0.5
            else (v - min) / range

        // Sample or pad to width
        let sampled =
            if values.Length >= width then
                let step = float values.Length / float width
                [0..width-1]
                |> List.map (fun i -> values.[int (float i * step)])
            else
                values @ List.replicate (width - values.Length) (List.last values)

        sampled
        |> List.map (fun v ->
            let idx = int (normalize v * 7.0) |> Operators.max 0 |> Operators.min 7
            sparklineChars.[idx])
        |> Array.ofList
        |> String

[<Tests>]
let sparklineTests =
    testList "Sparkline" [
        test "should generate sparkline for ascending values" {
            let values = [1.0; 2.0; 3.0; 4.0; 5.0; 6.0; 7.0; 8.0]
            let sparkline = generateSparkline values 8
            Expect.equal sparkline.Length 8 "Should have correct width"
            Expect.equal sparkline "▁▂▃▄▅▆▇█" "Should show ascending bars"
        }

        test "should generate sparkline for descending values" {
            let values = [8.0; 7.0; 6.0; 5.0; 4.0; 3.0; 2.0; 1.0]
            let sparkline = generateSparkline values 8
            Expect.equal sparkline "█▇▆▅▄▃▂▁" "Should show descending bars"
        }

        test "should handle constant values" {
            let values = [5.0; 5.0; 5.0; 5.0]
            let sparkline = generateSparkline values 4
            // All values same, should show middle height
            Expect.equal sparkline.Length 4 "Should have correct width"
        }

        test "should handle empty values" {
            let sparkline = generateSparkline [] 8
            Expect.equal sparkline "        " "Should be spaces for empty"
        }

        test "should sample longer series to width" {
            let values = List.init 100 (fun i -> float i)
            let sparkline = generateSparkline values 10
            Expect.equal sparkline.Length 10 "Should sample to width"
        }
    ]

// ============================================================================
// Unit Tests: Moving Average
// ============================================================================

let movingAverage (window: int) (values: float list) =
    if List.isEmpty values then []
    elif values.Length < window then [List.average values]
    else
        values
        |> List.windowed window
        |> List.map List.average

[<Tests>]
let movingAverageTests =
    testList "MovingAverage" [
        test "should calculate 3-point moving average" {
            let values = [1.0; 2.0; 3.0; 4.0; 5.0]
            let ma = movingAverage 3 values
            Expect.equal ma [2.0; 3.0; 4.0] "Should calculate correct averages"
        }

        test "should handle window larger than values" {
            let values = [1.0; 2.0]
            let ma = movingAverage 5 values
            Expect.equal ma [1.5] "Should return single average"
        }

        test "should handle empty values" {
            let ma = movingAverage 3 []
            Expect.isEmpty ma "Should return empty for empty input"
        }

        test "should handle single value" {
            let ma = movingAverage 3 [42.0]
            Expect.equal ma [42.0] "Should return single value"
        }
    ]

// ============================================================================
// Test Placeholder Types (to be replaced with actual imports)
// ============================================================================

type MetricValue = {
    Value: float
    Timestamp: DateTime
    Source: string
}
