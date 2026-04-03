/// CEPAF Signal Arrows Module
/// Arrow-based signal processing for safety-critical telemetry pipelines.
///
/// WHAT: Composable signal processing using Arrow abstractions
/// WHY: Type-safe, testable telemetry transformations with guaranteed properties
/// CONSTRAINTS:
///   - SC-ARROW-001: All signal transformations must be pure and composable
///   - SC-ARROW-002: Anomaly detection must be configurable with thresholds
///   - SC-ARROW-003: Smoothing windows must preserve signal characteristics
///   - SC-ARROW-004: Trend detection must use validated statistical methods
///
/// STAMP Compliance: SC-ARROW-001 to SC-ARROW-012
/// Version: 1.0.0
namespace Cepaf.Cockpit

open System
open Cepaf.Cockpit.Domain

// ============================================================================
// SUPPORTING TYPES (MUST BE DEFINED FIRST)
// ============================================================================

/// Smoothing algorithm selection
type SmoothingType =
    | SmaSmooth        // Simple Moving Average
    | EmaSmooth        // Exponential Moving Average
    | WmaSmooth        // Weighted Moving Average
    | MedianSmooth     // Median Filter

/// Anomaly detection algorithm selection
type AnomalyType =
    | ZScoreAnomaly
    | IqrAnomaly

/// Configuration for telemetry pipeline
type TelemetryConfig = {
    WindowSize: int
    Alpha: float  // For EMA
    SmoothingType: SmoothingType
    AnomalyType: AnomalyType
    AnomalyThreshold: float
    FastTrendThreshold: float
}

/// Result of telemetry processing
type TelemetryProcessingResult = {
    ProcessedValue: float
    DetectedTrend: Trend
    IsAnomalous: bool
    PredictedValue: float
    SampleCount: int
}

/// Health assessment result
type HealthAssessment = {
    AssessedNodeId: NodeId
    ComputedHealthScore: float
    CpuTrendResult: Trend
    MemoryTrendResult: Trend
    LatencyTrendResult: Trend
    AnomaliesDetected: bool
    ComputedAlarmLevel: AlarmLevel
    AssessmentTimestamp: DateTime
}

// ============================================================================
// SIGNAL ARROW - Type-Safe Signal Processing
// ============================================================================

/// Signal Arrow - A composable signal transformation
type SignalArrow<'A, 'B> = SigArr of ('A -> 'B)

module SignalArrow =

    // ========================================================================
    // CORE ARROW OPERATIONS
    // ========================================================================

    /// Lift a function into a signal arrow
    let arr (f: 'A -> 'B) : SignalArrow<'A, 'B> = SigArr f

    /// Run a signal arrow
    let run (SigArr f) x = f x

    /// Identity arrow
    let identity<'A> : SignalArrow<'A, 'A> = SigArr id

    /// Compose arrows (left to right)
    let compose (SigArr f: SignalArrow<'A, 'B>) (SigArr g: SignalArrow<'B, 'C>) : SignalArrow<'A, 'C> =
        SigArr (f >> g)

    /// Compose operator (>>>)
    let (>>>) = compose

    /// Reverse compose (<<<)
    let (<<<) g f = compose f g

    /// First - apply arrow to first element of pair
    let first (SigArr f: SignalArrow<'A, 'B>) : SignalArrow<'A * 'C, 'B * 'C> =
        SigArr (fun (a, c) -> (f a, c))

    /// Second - apply arrow to second element of pair
    let second (SigArr f: SignalArrow<'A, 'B>) : SignalArrow<'C * 'A, 'C * 'B> =
        SigArr (fun (c, a) -> (c, f a))

    /// Split - apply two arrows in parallel
    let split (SigArr f: SignalArrow<'A, 'B>) (SigArr g: SignalArrow<'C, 'D>) : SignalArrow<'A * 'C, 'B * 'D> =
        SigArr (fun (a, c) -> (f a, g c))

    /// Split operator (***)
    let ( *** ) = split

    /// Fan-out - apply both arrows to same input
    let fanout (SigArr f: SignalArrow<'A, 'B>) (SigArr g: SignalArrow<'A, 'C>) : SignalArrow<'A, 'B * 'C> =
        SigArr (fun a -> (f a, g a))

    /// Fan-out operator (&&&)
    let ( &&& ) = fanout

    /// Constant arrow
    let constant (b: 'B) : SignalArrow<'A, 'B> = arr (fun _ -> b)

    // ========================================================================
    // SIGNAL SMOOTHING ARROWS (SC-ARROW-003)
    // ========================================================================

    /// Simple Moving Average (SMA) - smooths signal over window
    let sma (windowSize: int) : SignalArrow<float list, float> =
        SigArr (fun samples ->
            if List.isEmpty samples then 0.0
            else
                let window = samples |> List.truncate windowSize
                window |> List.average
        )

    /// Exponential Moving Average (EMA) - weighted toward recent values
    let ema (alpha: float) : SignalArrow<float list, float> =
        SigArr (fun samples ->
            match samples with
            | [] -> 0.0
            | [x] -> x
            | _ ->
                let rec compute acc = function
                    | [] -> acc
                    | x :: xs -> compute (alpha * x + (1.0 - alpha) * acc) xs
                compute (List.last samples) (List.rev samples)
        )

    /// Weighted Moving Average (WMA) - linear weights
    let wma (windowSize: int) : SignalArrow<float list, float> =
        SigArr (fun samples ->
            let window = samples |> List.truncate windowSize
            if List.isEmpty window then 0.0
            else
                let weights = [1 .. List.length window] |> List.map float
                let weightSum = List.sum weights
                let weighted = List.zip window weights |> List.sumBy (fun (v, w) -> v * w)
                weighted / weightSum
        )

    /// Median filter - robust to outliers
    let medianFilter (windowSize: int) : SignalArrow<float list, float> =
        SigArr (fun samples ->
            let window = samples |> List.truncate windowSize |> List.sort
            match List.length window with
            | 0 -> 0.0
            | n when n % 2 = 1 -> window.[n / 2]
            | n -> (window.[n / 2 - 1] + window.[n / 2]) / 2.0
        )

    // ========================================================================
    // TREND DETECTION ARROWS (SC-ARROW-004)
    // ========================================================================

    /// Linear regression slope - determines trend direction
    let linearSlope : SignalArrow<float list, float> =
        SigArr (fun samples ->
            let n = List.length samples |> float
            if n < 2.0 then 0.0
            else
                let xs = [0.0 .. n - 1.0]
                let meanX = (n - 1.0) / 2.0
                let meanY = List.average samples
                let numerator = List.zip xs samples |> List.sumBy (fun (x, y) -> (x - meanX) * (y - meanY))
                let denominator = xs |> List.sumBy (fun x -> (x - meanX) ** 2.0)
                if abs denominator < 1e-10 then 0.0
                else numerator / denominator
        )

    /// Classify trend based on slope magnitude
    let classifyTrend (fastThreshold: float) : SignalArrow<float, Trend> =
        SigArr (fun slope ->
            if slope > fastThreshold then RisingFast
            elif slope > 0.1 then Rising
            elif slope < -fastThreshold then FallingFast
            elif slope < -0.1 then Falling
            else Stable
        )

    /// Complete trend detection pipeline
    let detectTrend (fastThreshold: float) : SignalArrow<float list, Trend> =
        linearSlope >>> classifyTrend fastThreshold

    /// Rate of change arrow
    let rateOfChange : SignalArrow<float list, float> =
        SigArr (fun samples ->
            match samples with
            | [] | [_] -> 0.0
            | x :: y :: _ -> x - y
        )

    /// Acceleration (second derivative)
    let acceleration : SignalArrow<float list, float> =
        SigArr (fun samples ->
            match samples with
            | [] | [_] | [_; _] -> 0.0
            | x :: y :: z :: _ -> (x - 2.0 * y + z)
        )

    // ========================================================================
    // ANOMALY DETECTION ARROWS (SC-ARROW-002)
    // ========================================================================

    /// Z-score based anomaly detection
    let zScoreDetection (threshold: float) : SignalArrow<float list, bool> =
        SigArr (fun samples ->
            match samples with
            | [] | [_] -> false
            | _ ->
                let current = List.head samples
                let mean = List.average samples
                let variance = samples |> List.map (fun x -> (x - mean) ** 2.0) |> List.average
                let stdDev = sqrt variance
                if stdDev < 1e-10 then false
                else abs ((current - mean) / stdDev) > threshold
        )

    /// IQR (Interquartile Range) based anomaly detection
    let iqrDetection (multiplier: float) : SignalArrow<float list, bool> =
        SigArr (fun samples ->
            let sorted = List.sort samples
            let n = List.length sorted
            if n < 4 then false
            else
                let q1 = sorted.[n / 4]
                let q3 = sorted.[3 * n / 4]
                let iqr = q3 - q1
                let lower = q1 - multiplier * iqr
                let upper = q3 + multiplier * iqr
                let current = List.head samples
                current < lower || current > upper
        )

    /// Threshold-based anomaly (absolute bounds)
    let thresholdAnomaly (low: float) (high: float) : SignalArrow<float, bool> =
        SigArr (fun value -> value < low || value > high)

    /// Rate-of-change anomaly (sudden spikes)
    let spikeAnomaly (maxRate: float) : SignalArrow<float list, bool> =
        rateOfChange >>> arr (fun rate -> abs rate > maxRate)

    // ========================================================================
    // ALARM LEVEL CLASSIFICATION (SC-ARROW-005)
    // ========================================================================

    /// Classify value to alarm level based on thresholds
    let classifyAlarmLevel (thresholds: Thresholds<float>) : SignalArrow<float, AlarmLevel> =
        SigArr (fun value ->
            let isOutside low high =
                match (low, high) with
                | (Some l, _) when value < l -> true
                | (_, Some h) when value > h -> true
                | _ -> false

            if isOutside thresholds.WarningLow thresholds.WarningHigh then Warning
            elif isOutside thresholds.CautionLow thresholds.CautionHigh then Caution
            elif isOutside thresholds.AdvisoryLow thresholds.AdvisoryHigh then Advisory
            else Normal
        )

    /// Priority alarm classifier with multiple conditions
    let multiConditionAlarm : SignalArrow<(bool * AlarmLevel) list, AlarmLevel> =
        SigArr (fun conditions ->
            conditions
            |> List.filter fst
            |> List.map snd
            |> List.sortByDescending (function
                | Critical -> 5 | Warning -> 4 | Caution -> 3 | Advisory -> 2 | Normal -> 1)
            |> List.tryHead
            |> Option.defaultValue Normal
        )

    // ========================================================================
    // HEALTH SCORE COMPUTATION (SC-ARROW-006)
    // ========================================================================

    /// Normalize value to 0-100 scale
    let normalize (minVal: float) (maxVal: float) : SignalArrow<float, float> =
        SigArr (fun value ->
            let range = maxVal - minVal
            if range < 1e-10 then 50.0
            else ((value - minVal) / range * 100.0) |> max 0.0 |> min 100.0
        )

    /// Invert health score (high CPU = low health)
    let invertHealth : SignalArrow<float, float> =
        SigArr (fun value -> 100.0 - value)

    /// Weighted health aggregation
    let weightedHealth (weights: float list) : SignalArrow<float list, float> =
        SigArr (fun scores ->
            if List.isEmpty scores then 100.0
            else
                let pairedWeights =
                    if List.length weights >= List.length scores
                    then weights |> List.truncate (List.length scores)
                    else weights @ (List.replicate (List.length scores - List.length weights) 1.0)
                let totalWeight = List.sum pairedWeights
                if totalWeight < 1e-10 then 100.0
                else
                    List.zip scores pairedWeights
                    |> List.sumBy (fun (s, w) -> s * w)
                    |> fun sum -> sum / totalWeight
        )

    /// Compute node health score from metrics
    let computeNodeHealth : SignalArrow<MeshNode, float> =
        SigArr (fun node ->
            let cpuHealth = 100.0 - node.Cpu.Value
            let memHealth = 100.0 - node.Memory.Value
            let latencyHealth =
                if node.NetworkLatency.Value < 10.0 then 100.0
                elif node.NetworkLatency.Value < 50.0 then 80.0
                elif node.NetworkLatency.Value < 100.0 then 60.0
                elif node.NetworkLatency.Value < 500.0 then 40.0
                else 20.0
            let batteryHealth =
                node.Battery
                |> Option.map (fun b -> b.Value)
                |> Option.defaultValue 100.0

            // Weighted average: CPU 30%, Memory 25%, Latency 25%, Battery 20%
            let scores = [cpuHealth; memHealth; latencyHealth; batteryHealth]
            let weights = [0.30; 0.25; 0.25; 0.20]
            List.zip scores weights |> List.sumBy (fun (s, w) -> s * w)
        )

    // ========================================================================
    // SIGNAL FILTERING ARROWS (SC-ARROW-007)
    // ========================================================================

    /// Low-pass filter (removes high frequency noise)
    let lowPass (cutoff: float) : SignalArrow<float list, float list> =
        SigArr (fun samples ->
            let alpha = cutoff / (cutoff + 1.0)
            let rec filter acc prev = function
                | [] -> List.rev acc
                | x :: xs ->
                    let filtered = alpha * x + (1.0 - alpha) * prev
                    filter (filtered :: acc) filtered xs
            match samples with
            | [] -> []
            | x :: xs -> filter [x] x xs
        )

    /// High-pass filter (removes DC offset)
    let highPass (cutoff: float) : SignalArrow<float list, float list> =
        SigArr (fun samples ->
            let alpha = 1.0 / (cutoff + 1.0)
            let rec filter acc prevIn prevOut = function
                | [] -> List.rev acc
                | x :: xs ->
                    let filtered = alpha * (prevOut + x - prevIn)
                    filter (filtered :: acc) x filtered xs
            match samples with
            | [] -> []
            | x :: xs -> filter [0.0] x 0.0 xs
        )

    /// Deadband filter (ignores small changes)
    let deadband (threshold: float) : SignalArrow<float * float, float> =
        SigArr (fun (current, previous) ->
            if abs (current - previous) < threshold then previous
            else current
        )

    // ========================================================================
    // SIGNAL PREDICTION ARROWS (SC-ARROW-008)
    // ========================================================================

    /// Linear extrapolation (predict next value)
    let linearPredict : SignalArrow<float list, float> =
        SigArr (fun samples ->
            match samples with
            | [] -> 0.0
            | [x] -> x
            | x :: y :: _ -> 2.0 * x - y  // Linear extrapolation
        )

    /// Exponential prediction with decay
    let expPredict (decayFactor: float) : SignalArrow<float list, float> =
        SigArr (fun samples ->
            match samples with
            | [] -> 0.0
            | [x] -> x
            | x :: y :: _ ->
                let trend = x - y
                x + trend * decayFactor
        )

    /// Time-to-threshold prediction
    let timeToThreshold (threshold: float) : SignalArrow<float list, float option> =
        SigArr (fun samples ->
            let slope = run linearSlope samples
            if abs slope < 1e-10 then None
            else
                let current = List.tryHead samples |> Option.defaultValue 0.0
                let stepsToThreshold = (threshold - current) / slope
                if stepsToThreshold > 0.0 then Some stepsToThreshold
                else None
        )

    // ========================================================================
    // COMPOSITE SIGNAL PROCESSING PIPELINES
    // ========================================================================

    /// Complete telemetry processing pipeline
    let telemetryPipeline (config: TelemetryConfig) : SignalArrow<float list, TelemetryProcessingResult> =
        let smoothed =
            match config.SmoothingType with
            | SmaSmooth -> sma config.WindowSize
            | EmaSmooth -> ema config.Alpha
            | WmaSmooth -> wma config.WindowSize
            | MedianSmooth -> medianFilter config.WindowSize

        let anomalyDetection =
            match config.AnomalyType with
            | ZScoreAnomaly -> zScoreDetection config.AnomalyThreshold
            | IqrAnomaly -> iqrDetection config.AnomalyThreshold

        SigArr (fun samples ->
            let smoothedValue = run smoothed samples
            let trend = run (detectTrend config.FastTrendThreshold) samples
            let isAnomaly = run anomalyDetection samples
            let prediction = run linearPredict samples

            {
                ProcessedValue = smoothedValue
                DetectedTrend = trend
                IsAnomalous = isAnomaly
                PredictedValue = prediction
                SampleCount = List.length samples
            }
        )

    /// Node health assessment pipeline
    let healthAssessmentPipeline : SignalArrow<MeshNode, HealthAssessment> =
        let healthScore = computeNodeHealth

        SigArr (fun node ->
            let score = run healthScore node
            let cpuTrend = run (detectTrend 5.0) node.Cpu.Sparkline
            let memTrend = run (detectTrend 5.0) node.Memory.Sparkline
            let latencyTrend = run (detectTrend 10.0) node.NetworkLatency.Sparkline

            let cpuAnomaly = run (zScoreDetection 2.0) node.Cpu.Sparkline
            let memAnomaly = run (zScoreDetection 2.0) node.Memory.Sparkline

            let overallAlarm =
                if cpuAnomaly || memAnomaly then Warning
                elif score < 30.0 then Warning
                elif score < 50.0 then Caution
                elif score < 70.0 then Advisory
                else Normal

            {
                AssessedNodeId = node.Id
                ComputedHealthScore = score
                CpuTrendResult = cpuTrend
                MemoryTrendResult = memTrend
                LatencyTrendResult = latencyTrend
                AnomaliesDetected = cpuAnomaly || memAnomaly
                ComputedAlarmLevel = overallAlarm
                AssessmentTimestamp = DateTime.UtcNow
            }
        )

// ============================================================================
// PREBUILT PIPELINE CONFIGURATIONS
// ============================================================================

module TelemetryPipelines =

    /// Default configuration for general telemetry
    let defaultConfig : TelemetryConfig = {
        WindowSize = 10
        Alpha = 0.3
        SmoothingType = EmaSmooth
        AnomalyType = ZScoreAnomaly
        AnomalyThreshold = 2.5
        FastTrendThreshold = 5.0
    }

    /// High-sensitivity configuration for critical metrics
    let criticalConfig : TelemetryConfig = {
        WindowSize = 5
        Alpha = 0.5
        SmoothingType = EmaSmooth
        AnomalyType = ZScoreAnomaly
        AnomalyThreshold = 2.0
        FastTrendThreshold = 3.0
    }

    /// Low-sensitivity for stable metrics
    let stableConfig : TelemetryConfig = {
        WindowSize = 20
        Alpha = 0.1
        SmoothingType = SmaSmooth
        AnomalyType = IqrAnomaly
        AnomalyThreshold = 3.0
        FastTrendThreshold = 10.0
    }

    /// CPU monitoring pipeline
    let cpuPipeline = SignalArrow.telemetryPipeline criticalConfig

    /// Memory monitoring pipeline
    let memoryPipeline = SignalArrow.telemetryPipeline defaultConfig

    /// Network latency pipeline
    let latencyPipeline = SignalArrow.telemetryPipeline stableConfig
