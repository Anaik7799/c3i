// =============================================================================
// HealthDashboard.fs - CEPAF Cockpit TUI Health Dashboard
// =============================================================================
// STAMP: SC-HMI-010 (Color Rich), SC-CPU-GOV-001, SC-VER-031
// AOR: AOR-MON-004 (30s refresh), AOR-BIO-004
//
// Pure rendering module — returns ANSI-colored dashboard string.
// No side effects. All state passed in via HealthState record.
//
// ## Constitutional Alignment
// - Ψ₀ (Existence): Reports system survival indicators
// - Ψ₃ (Verification): Health scores are numeric, auditable
// =============================================================================

namespace Cepaf.Cockpit

open System

// ---------------------------------------------------------------------------
// Domain types
// ---------------------------------------------------------------------------

/// Threat level enumeration for the Guardian/Sentinel subsystem.
[<RequireQualifiedAccess>]
type ThreatLevel =
    | None
    | Low
    | Medium
    | High
    | Critical

/// Snapshot of all observable health signals for the cockpit dashboard.
type HealthState = {
    /// CPU utilisation percentage (0–100)
    CpuPercent      : float
    /// Memory utilisation percentage (0–100)
    MemoryPercent   : float
    /// Round-trip Zenoh publish latency in microseconds
    ZenohLatencyUs  : int64
    /// Number of healthy containers currently running
    ContainerCount  : int
    /// Maximum container count expected (used to compute % up)
    MaxContainers   : int
    /// Current threat assessment from Sentinel
    ThreatLevel     : ThreatLevel
    /// Overall mesh health score 0.0–1.0 (composite)
    MeshHealthScore : float
    /// Timestamp of this snapshot
    Timestamp       : DateTimeOffset
}

// ---------------------------------------------------------------------------
// ANSI colour helpers (inline — avoids Cepaf.Observability dependency)
// ---------------------------------------------------------------------------

module private Ansi =
    let reset   = "\u001b[0m"
    let bold    = "\u001b[1m"
    let dim     = "\u001b[2m"
    let green   = "\u001b[32m"
    let yellow  = "\u001b[33m"
    let red     = "\u001b[31m"
    let cyan    = "\u001b[36m"
    let white   = "\u001b[37m"
    let bgBlack = "\u001b[40m"
    let bGreen  = "\u001b[92m"
    let bYellow = "\u001b[93m"
    let bRed    = "\u001b[91m"
    let bCyan   = "\u001b[96m"
    let bWhite  = "\u001b[97m"

// ---------------------------------------------------------------------------
// HealthDashboard — pure rendering functions
// ---------------------------------------------------------------------------

/// Renders a TUI health dashboard as an ANSI-coloured string.
/// All functions are pure (no I/O). Callers print the returned string.
module HealthDashboard =

    // -----------------------------------------------------------------------
    // Internal colour-selection helpers
    // -----------------------------------------------------------------------

    /// Colour for a percentage value: green < low, yellow < high, else red.
    let private colourForPct (value: float) (lowThreshold: float) (highThreshold: float) : string =
        if value < lowThreshold      then Ansi.bGreen
        elif value < highThreshold   then Ansi.bYellow
        else                              Ansi.bRed

    /// Colour for a latency value (µs): green < 1000, yellow < 5000, else red.
    let private colourForLatency (latUs: int64) : string =
        if latUs < 1000L   then Ansi.bGreen
        elif latUs < 5000L then Ansi.bYellow
        else                    Ansi.bRed

    /// Colour and label for the threat level.
    let private threatColourLabel (t: ThreatLevel) : string * string =
        match t with
        | ThreatLevel.None     -> Ansi.bGreen,  "NONE    "
        | ThreatLevel.Low      -> Ansi.bGreen,  "LOW     "
        | ThreatLevel.Medium   -> Ansi.bYellow, "MEDIUM  "
        | ThreatLevel.High     -> Ansi.bRed,    "HIGH    "
        | ThreatLevel.Critical -> Ansi.bRed,    "CRITICAL"

    /// Colour for the overall mesh health score (0–1).
    let private colourForScore (score: float) : string =
        if score >= 0.9 then Ansi.bGreen
        elif score >= 0.7 then Ansi.bYellow
        else Ansi.bRed

    // -----------------------------------------------------------------------
    // Bar chart helper — produces a 20-char ASCII bar
    // -----------------------------------------------------------------------

    /// Renders a simple ASCII bar of width `totalWidth` filled to `pct` (0–100).
    let private bar (pct: float) (totalWidth: int) (colour: string) : string =
        let filled = int (pct / 100.0 * float totalWidth) |> max 0 |> min totalWidth
        let empty  = totalWidth - filled
        let bar    = String.replicate filled "█" + String.replicate empty "░"
        sprintf "%s%s%s" colour bar Ansi.reset

    // -----------------------------------------------------------------------
    // Container status helper
    // -----------------------------------------------------------------------

    let private containerLine (count: int) (max: int) : string =
        let pct = if max > 0 then float count / float max * 100.0 else 0.0
        let col = colourForPct pct 50.0 80.0
        sprintf "%s%d / %d%s  (%.0f%% up)" col count max Ansi.reset pct

    // -----------------------------------------------------------------------
    // Public API
    // -----------------------------------------------------------------------

    /// Renders the complete cockpit health dashboard.
    /// Returns a multi-line ANSI-coloured string suitable for Console.Write.
    let renderDashboard (state: HealthState) : string =
        let sep  = sprintf "%s%s%s" Ansi.cyan (String.replicate 60 "─") Ansi.reset
        let hdr  = sprintf "%s%s INDRAJAAL COCKPIT — HEALTH DASHBOARD %s%s"
                       Ansi.bold Ansi.bCyan Ansi.reset Ansi.reset

        let ts   = state.Timestamp.ToString("yyyy-MM-dd HH:mm:ss zzz")

        // CPU row
        let cpuCol = colourForPct state.CpuPercent 60.0 80.0
        let cpuRow = sprintf "  CPU       %s  %s%.1f%%%s"
                         (bar state.CpuPercent 20 cpuCol) cpuCol state.CpuPercent Ansi.reset

        // Memory row
        let memCol = colourForPct state.MemoryPercent 70.0 90.0
        let memRow = sprintf "  Memory    %s  %s%.1f%%%s"
                         (bar state.MemoryPercent 20 memCol) memCol state.MemoryPercent Ansi.reset

        // Zenoh latency row
        let latUs  = state.ZenohLatencyUs
        let latCol = colourForLatency latUs
        let latLabel =
            if latUs < 1000L then sprintf "%d µs" latUs
            else sprintf "%.2f ms" (float latUs / 1000.0)
        let latRow = sprintf "  Zenoh Lat              %s%s%s" latCol latLabel Ansi.reset

        // Containers row
        let cRow = sprintf "  Containers             %s" (containerLine state.ContainerCount state.MaxContainers)

        // Threat level row
        let (tCol, tLabel) = threatColourLabel state.ThreatLevel
        let tRow = sprintf "  Threat     %s%s%s" tCol tLabel Ansi.reset

        // Mesh health score row
        let scoreCol = colourForScore state.MeshHealthScore
        let scorePct = state.MeshHealthScore * 100.0
        let scoreRow = sprintf "  Mesh Score %s  %s%.1f%%%s"
                           (bar scorePct 20 scoreCol) scoreCol scorePct Ansi.reset

        // Timestamp row
        let timeRow = sprintf "  %sUpdated:%s %s%s%s" Ansi.dim Ansi.reset Ansi.white ts Ansi.reset

        // Assemble
        [ ""
          sep
          sprintf "  %s" hdr
          sep
          cpuRow
          memRow
          latRow
          cRow
          tRow
          scoreRow
          sep
          timeRow
          sep
          "" ]
        |> String.concat "\n"

    /// Convenience: renders a minimal one-liner status for embedding in logs.
    let renderOneLiner (state: HealthState) : string =
        let (tCol, tLabel) = threatColourLabel state.ThreatLevel
        let scoreCol = colourForScore state.MeshHealthScore
        sprintf "%sCPU:%.0f%% Mem:%.0f%% Zenoh:%dµs Containers:%d/%d Threat:%s%s%s Score:%s%.0f%%%s%s"
            Ansi.dim
            state.CpuPercent
            state.MemoryPercent
            state.ZenohLatencyUs
            state.ContainerCount
            state.MaxContainers
            tCol tLabel Ansi.reset
            scoreCol (state.MeshHealthScore * 100.0) Ansi.reset
            Ansi.reset
