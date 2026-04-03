// =============================================================================
// CliHealthScore.fs - CLI Envelope Real Zenoh Metrics Health Score & Threat Count
// =============================================================================
// STAMP: SC-HEALTH-001, SC-ZENOH-007
// AOR: AOR-MON-001, AOR-MON-003, AOR-MON-004
//
// ## Purpose
// Provides weighted health score computation and threat count rendering
// for the sa-* CLI envelope (L5 layer). Aggregates CPU, memory, disk,
// Zenoh connectivity, and container health into a single 0.0-1.0 score.
//
// ## Health Weights
// | Dimension    | Weight | Rationale                          |
// |--------------|--------|------------------------------------|
// | CPU          | 0.25   | Primary compute resource           |
// | Memory       | 0.20   | Heap pressure affects stability    |
// | Disk         | 0.15   | Storage affects persistence layer  |
// | Zenoh        | 0.25   | Mesh connectivity is SIL-6 critical|
// | Containers   | 0.15   | Service availability               |
//
// ## Grade Scale
// | Grade | Score  | ANSI Color |
// |-------|--------|------------|
// | A     | >= 0.9 | bright green |
// | B     | >= 0.8 | green        |
// | C     | >= 0.7 | yellow       |
// | D     | >= 0.6 | yellow       |
// | F     | < 0.6  | red          |
//
// ## Constraint Compliance
// - SC-HEALTH-001: Health metrics MUST be published at L5 CLI layer
// - SC-ZENOH-007:  Zenoh health MUST be included in /health endpoint data
//
// ## Document Control
// | Field   | Value            |
// |---------|------------------|
// | Version | 1.0.0            |
// | Created | 2026-03-30       |
// | Author  | Code Evolution Agent (W10) |
// =============================================================================

namespace Cepaf.Mesh

open System
open Cepaf.Observability.ConsoleChannel  // SC-CONSOL-003: Centralized ANSI colors

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Computed health score with grade and display color
type HealthScore = {
    /// Weighted score in range [0.0, 1.0]
    Score: float
    /// Letter grade: A, B, C, D, or F
    Grade: string
    /// ANSI escape sequence for terminal coloring
    Color: string
}

/// Breakdown of active Sentinel threats by severity
type ThreatSummary = {
    /// Count of CRITICAL-severity threats
    Critical: int
    /// Count of HIGH-severity threats
    High: int
    /// Count of MEDIUM-severity threats
    Medium: int
    /// Count of LOW-severity threats
    Low: int
    /// Total across all severities
    Total: int
}

// ---------------------------------------------------------------------------
// Module
// ---------------------------------------------------------------------------

/// <summary>
/// CLI health score and threat summary rendering for the sa-* CLI envelope.
///
/// STAMP Compliance:
///   SC-HEALTH-001 — health metrics available at CLI (L5) layer
///   SC-ZENOH-007  — Zenoh status included in every health line
/// </summary>
module CliHealthScore =

    // -----------------------------------------------------------------------
    // Private constants
    // -----------------------------------------------------------------------

    /// Weight allocated to CPU utilization
    [<Literal>]
    let private WeightCpu = 0.25

    /// Weight allocated to memory utilization
    [<Literal>]
    let private WeightMemory = 0.20

    /// Weight allocated to disk utilization
    [<Literal>]
    let private WeightDisk = 0.15

    /// Weight allocated to Zenoh connectivity (SC-ZENOH-007)
    [<Literal>]
    let private WeightZenoh = 0.25

    /// Weight allocated to container health fraction
    [<Literal>]
    let private WeightContainers = 0.15

    // -----------------------------------------------------------------------
    // Private helpers
    // -----------------------------------------------------------------------

    /// Convert a utilization percentage (0-100) to a contribution score (0-1).
    /// Full score when util <= 50 %; linear decay between 50 % and 100 %.
    let private utilizationScore (pct: float) : float =
        if pct <= 0.0 then 1.0
        elif pct >= 100.0 then 0.0
        elif pct <= 50.0 then 1.0
        else 1.0 - ((pct - 50.0) / 50.0)

    /// Convert a boolean flag (e.g., Zenoh up) to a component score.
    let private boolScore (flag: bool) : float =
        if flag then 1.0 else 0.0

    /// Convert a container healthy fraction to a component score.
    let private containerFractionScore (healthy: int) (total: int) : float =
        if total <= 0 then 1.0  // no containers to worry about
        else float healthy / float total

    /// Classify a 0-1 score into a letter grade.
    let private gradeOf (score: float) : string =
        if score >= 0.9 then "A"
        elif score >= 0.8 then "B"
        elif score >= 0.7 then "C"
        elif score >= 0.6 then "D"
        else "F"

    /// Select the ANSI display color for a grade (SC-CONSOL-003).
    let private colorOf (grade: string) : string =
        match grade with
        | "A" -> AnsiColors.brightGreen
        | "B" -> AnsiColors.green
        | "C" | "D" -> AnsiColors.yellow
        | _ -> AnsiColors.red

    // -----------------------------------------------------------------------
    // Public API
    // -----------------------------------------------------------------------

    /// <summary>
    /// Compute a weighted health score from raw resource metrics.
    /// Returns a <see cref="HealthScore"/> with score in [0.0, 1.0], grade, and ANSI color.
    /// </summary>
    /// <param name="cpuPct">Current CPU utilization 0-100.</param>
    /// <param name="memPct">Current memory utilization 0-100.</param>
    /// <param name="diskPct">Current disk utilization 0-100.</param>
    /// <param name="zenohUp">True when Zenoh router is reachable (SC-ZENOH-007).</param>
    /// <param name="containerHealthy">Count of containers in healthy state.</param>
    /// <param name="containerTotal">Total number of containers in the mesh.</param>
    let computeHealthScore
            (cpuPct: float)
            (memPct: float)
            (diskPct: float)
            (zenohUp: bool)
            (containerHealthy: int)
            (containerTotal: int)
            : HealthScore =
        let cpuComponent       = WeightCpu        * utilizationScore cpuPct
        let memComponent       = WeightMemory     * utilizationScore memPct
        let diskComponent      = WeightDisk       * utilizationScore diskPct
        let zenohComponent     = WeightZenoh      * boolScore zenohUp
        let containerComponent = WeightContainers * containerFractionScore containerHealthy containerTotal

        let raw = cpuComponent + memComponent + diskComponent + zenohComponent + containerComponent
        // Clamp to [0.0, 1.0] for defensive safety
        let score = Math.Max(0.0, Math.Min(1.0, raw))
        let grade = gradeOf score
        let color = colorOf grade
        { Score = score; Grade = grade; Color = color }

    /// <summary>
    /// Return a count of active Sentinel threats as a formatted string.
    ///
    /// Uses a local heuristic based on environment inspection.
    /// Returns Ok "&lt;N&gt; threat(s)" or Error with a diagnostic message.
    /// </summary>
    let getThreatCount () : Result<string, string> =
        // Attempt to read threat count from the Sentinel state file if present.
        // Falls back to zero when the file or environment is unavailable.
        let sentinelStateKey = "SENTINEL_THREAT_COUNT"
        let envValue = Environment.GetEnvironmentVariable(sentinelStateKey)
        match envValue with
        | null | "" ->
            // No Sentinel integration active — report zero threats
            Ok "0 threats (Sentinel offline)"
        | value ->
            match Int32.TryParse(value) with
            | true, n when n >= 0 ->
                let noun = if n = 1 then "threat" else "threats"
                Ok $"{n} active {noun}"
            | _ ->
                Error $"SENTINEL_THREAT_COUNT value '{value}' is not a non-negative integer"

    /// <summary>
    /// Render a single-line health summary with ANSI color suitable for the CLI prompt.
    /// Format: "Health: A [0.93] CPU:42% MEM:31% DISK:12% ZENOH:UP CTR:4/4"
    /// </summary>
    let renderHealthLine
            (cpuPct: float)
            (memPct: float)
            (diskPct: float)
            (zenohUp: bool)
            (containerHealthy: int)
            (containerTotal: int)
            : string =
        let hs = computeHealthScore cpuPct memPct diskPct zenohUp containerHealthy containerTotal
        let zenohStr = if zenohUp then "UP" else "DOWN"
        let reset = AnsiColors.reset
        let bold = AnsiColors.bold
        $"{bold}{hs.Color}Health: {hs.Grade} [{hs.Score:F2}]{reset} \
CPU:{cpuPct:F0}%% MEM:{memPct:F0}%% DISK:{diskPct:F0}%% ZENOH:{zenohStr} CTR:{containerHealthy}/{containerTotal}"

    /// <summary>
    /// Render a threat breakdown by severity.
    /// Returns Ok of a multi-field summary line, or Error if Sentinel is unavailable.
    /// </summary>
    let renderThreatSummary
            (summary: ThreatSummary)
            : Result<string, string> =
        let c = AnsiColors.red
        let y = AnsiColors.yellow
        let b = AnsiColors.brightCyan
        let g = AnsiColors.green
        let r = AnsiColors.reset
        let bold = AnsiColors.bold

        if summary.Total = 0 then
            Ok $"{g}No active threats{r}"
        else
            let critStr = if summary.Critical > 0 then $"{bold}{c}CRIT:{summary.Critical}{r} " else ""
            let highStr = if summary.High     > 0 then $"{c}HIGH:{summary.High}{r} "           else ""
            let medStr  = if summary.Medium   > 0 then $"{y}MED:{summary.Medium}{r} "          else ""
            let lowStr  = if summary.Low      > 0 then $"{b}LOW:{summary.Low}{r} "             else ""
            Ok ($"Threats [{summary.Total}]: {critStr}{highStr}{medStr}{lowStr}".TrimEnd())

    /// <summary>
    /// Render a combined one-line status for inclusion in a CLI prompt or status bar.
    /// Combines health score and threat count into a compact string.
    /// Complies with SC-HEALTH-001 (L5 availability) and SC-ZENOH-007 (Zenoh in status).
    /// </summary>
    let renderCompactStatus
            (cpuPct: float)
            (memPct: float)
            (diskPct: float)
            (zenohUp: bool)
            (containerHealthy: int)
            (containerTotal: int)
            : Result<string, string> =
        let hs = computeHealthScore cpuPct memPct diskPct zenohUp containerHealthy containerTotal
        let threatResult = getThreatCount ()
        match threatResult with
        | Error e ->
            Error $"Threat query failed: {e}"
        | Ok threatStr ->
            let zenohIcon = if zenohUp then $"{AnsiColors.brightGreen}Z{AnsiColors.reset}" else $"{AnsiColors.red}Z{AnsiColors.reset}"
            let status =
                $"{hs.Color}{AnsiColors.bold}{hs.Grade}{AnsiColors.reset} \
{hs.Score:F2} {zenohIcon} CTR:{containerHealthy}/{containerTotal} | {threatStr}"
            Ok status
