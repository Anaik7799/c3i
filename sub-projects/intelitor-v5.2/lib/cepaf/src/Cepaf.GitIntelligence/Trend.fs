// =============================================================================
// Git Intelligence — L5 Time-Series Trend Analysis
// =============================================================================
// Purpose:  Compute GHS trends using Exponential Moving Average (EMA),
//           detect regressions, compute velocity metrics, and project
//           when GHS target will be reached via linear regression.
//
// Data:     Uses EvolutionEvent records from History.fs (DuckDB).
//
// STAMP:    SC-TREND-001 to SC-TREND-005
// =============================================================================

module Cepaf.GitIntelligence.Trend

open System

// ─────────────────────────────────────────────────────────────────────────────
// Exponential Moving Average (EMA)
// ─────────────────────────────────────────────────────────────────────────────

/// Compute EMA of a value series with given smoothing factor (alpha).
/// Alpha = 2 / (N + 1) where N = window size.
let computeEma (values: float[]) (alpha: float) : float[] =
    if values.Length = 0 then [||]
    else
        let ema = Array.zeroCreate values.Length
        ema.[0] <- values.[0]
        for i in 1 .. values.Length - 1 do
            ema.[i] <- alpha * values.[i] + (1.0 - alpha) * ema.[i - 1]
        ema

/// Compute GHS trend: EMA of GHS values from evolution events.
/// Returns (timestamps, ema_values) aligned arrays.
let computeGhsTrend (events: EvolutionEvent[]) (windowSize: int) : (DateTimeOffset * float)[] =
    let ghsEvents =
        events
        |> Array.filter (fun e -> e.GhsAfter.IsSome)
        |> Array.sortBy (fun e -> e.Timestamp)
    if ghsEvents.Length = 0 then [||]
    else
        let values = ghsEvents |> Array.map (fun e -> e.GhsAfter.Value)
        let alpha = 2.0 / (float windowSize + 1.0)
        let ema = computeEma values alpha
        Array.zip (ghsEvents |> Array.map (fun e -> e.Timestamp)) ema

// ─────────────────────────────────────────────────────────────────────────────
// Regression Detection
// ─────────────────────────────────────────────────────────────────────────────

/// Detect GHS regression: alert when current GHS drops >10% from EMA baseline.
/// Returns (isRegression, dropPercentage, emaBaseline).
let detectRegression (currentGhs: float) (emaBaseline: float) : bool * float * float =
    if emaBaseline <= 0.0 then (false, 0.0, emaBaseline)
    else
        let drop = (emaBaseline - currentGhs) / emaBaseline
        (drop > 0.10, drop * 100.0, emaBaseline)

/// Detect regression from event history.
let detectRegressionFromEvents (events: EvolutionEvent[]) (currentGhs: float) (windowSize: int) : bool * float * float =
    let trend = computeGhsTrend events windowSize
    if trend.Length = 0 then (false, 0.0, 0.0)
    else
        let (_, latestEma) = trend.[trend.Length - 1]
        detectRegression currentGhs latestEma

// ─────────────────────────────────────────────────────────────────────────────
// Velocity Metrics
// ─────────────────────────────────────────────────────────────────────────────

/// Compute commit velocity: commits per day over given period.
let computeVelocity (commits: ParsedCommit[]) (periodDays: float) : float =
    if periodDays <= 0.0 then 0.0
    else
        let now = DateTimeOffset.UtcNow
        let recentCount =
            commits |> Array.filter (fun c -> (now - c.Date).TotalDays <= periodDays) |> Array.length
        float recentCount / periodDays

/// Compute ICP adoption rate change per week.
/// Returns (currentRate, previousRate, delta) where delta is rate change.
let computeAdoptionTrend (commits: ParsedCommit[]) : float * float * float =
    let now = DateTimeOffset.UtcNow
    let thisWeek = commits |> Array.filter (fun c -> (now - c.Date).TotalDays <= 7.0)
    let lastWeek = commits |> Array.filter (fun c ->
        let age = (now - c.Date).TotalDays
        age > 7.0 && age <= 14.0)

    let icpRate (cs: ParsedCommit[]) =
        if cs.Length = 0 then 0.0
        else
            let count = cs |> Array.filter (fun c ->
                c.Style = CommitStyle.IcpConventional || c.Style = CommitStyle.ConventionalNoEmDash) |> Array.length
            float count / float cs.Length * 100.0

    let current = icpRate thisWeek
    let previous = icpRate lastWeek
    (current, previous, current - previous)

// ─────────────────────────────────────────────────────────────────────────────
// Linear Regression Projection
// ─────────────────────────────────────────────────────────────────────────────

/// Simple linear regression: y = mx + b
/// Returns (slope, intercept, r_squared).
let private linearRegression (xs: float[]) (ys: float[]) : float * float * float =
    let n = float xs.Length
    if n < 2.0 then (0.0, 0.0, 0.0)
    else
        let sumX = Array.sum xs
        let sumY = Array.sum ys
        let sumXY = Array.map2 (*) xs ys |> Array.sum
        let sumX2 = xs |> Array.sumBy (fun x -> x * x)
        let sumY2 = ys |> Array.sumBy (fun y -> y * y)

        let denominator = n * sumX2 - sumX * sumX
        if abs denominator < 1e-10 then (0.0, sumY / n, 0.0)
        else
            let slope = (n * sumXY - sumX * sumY) / denominator
            let intercept = (sumY - slope * sumX) / n

            // R²
            let ssRes = Array.map2 (fun x y -> let pred = slope * x + intercept in (y - pred) ** 2.0) xs ys |> Array.sum
            let meanY = sumY / n
            let ssTot = ys |> Array.sumBy (fun y -> (y - meanY) ** 2.0)
            let r2 = if abs ssTot < 1e-10 then 0.0 else 1.0 - ssRes / ssTot

            (slope, intercept, r2)

/// Project when GHS target (default 0.85) will be reached.
/// Returns estimated days until target, or None if slope is non-positive.
let projectTarget (events: EvolutionEvent[]) (target: float) : float option =
    let ghsEvents =
        events
        |> Array.filter (fun e -> e.GhsAfter.IsSome)
        |> Array.sortBy (fun e -> e.Timestamp)
    if ghsEvents.Length < 3 then None
    else
        let baseTime = ghsEvents.[0].Timestamp
        let xs = ghsEvents |> Array.map (fun e -> (e.Timestamp - baseTime).TotalDays)
        let ys = ghsEvents |> Array.map (fun e -> e.GhsAfter.Value)

        let (slope, intercept, _r2) = linearRegression xs ys

        if slope <= 0.0 then None  // Not improving
        else
            let currentDay = xs.[xs.Length - 1]
            let targetDay = (target - intercept) / slope
            let daysRemaining = targetDay - currentDay
            if daysRemaining > 0.0 && daysRemaining < 365.0 then Some daysRemaining
            else None

// ─────────────────────────────────────────────────────────────────────────────
// Formatting
// ─────────────────────────────────────────────────────────────────────────────

/// Format trend report for display.
let formatTrendReport
    (commits: ParsedCommit[])
    (events: EvolutionEvent[])
    (currentGhs: float)
    (windowSize: int)
    : string =

    let sb = System.Text.StringBuilder()
    sb.AppendLine("GHS Trend Analysis") |> ignore
    sb.AppendLine($"  Current GHS: {currentGhs:F4}") |> ignore

    // EMA trend
    let trend = computeGhsTrend events windowSize
    if trend.Length > 0 then
        let (_, latestEma) = trend.[trend.Length - 1]
        sb.AppendLine($"  EMA({windowSize}): {latestEma:F4}") |> ignore

        let (isRegression, dropPct, baseline) = detectRegression currentGhs latestEma
        if isRegression then
            sb.AppendLine($"  REGRESSION: GHS dropped {dropPct:F1}%% from baseline {baseline:F4}") |> ignore
        else
            sb.AppendLine($"  No regression detected (baseline: {baseline:F4})") |> ignore

    // Velocity
    let velocity7d = computeVelocity commits 7.0
    let velocity30d = computeVelocity commits 30.0
    sb.AppendLine($"  Velocity: {velocity7d:F1}/day (7d), {velocity30d:F1}/day (30d)") |> ignore

    // Adoption trend
    let (currentAdoption, prevAdoption, delta) = computeAdoptionTrend commits
    let arrow = if delta > 0.0 then "↑" elif delta < 0.0 then "↓" else "→"
    let deltaStr = if delta >= 0.0 then $"+{delta:F0}" else $"{delta:F0}"
    sb.AppendLine($"  ICP Adoption: {currentAdoption:F0}%% {arrow} ({deltaStr}%% vs last week)") |> ignore

    // Projection
    match projectTarget events 0.85 with
    | Some days -> sb.AppendLine($"  Projection: GHS 0.85 target in ~{days:F0} days") |> ignore
    | None -> sb.AppendLine("  Projection: GHS target not projectable (slope non-positive or insufficient data)") |> ignore

    sb.ToString()
