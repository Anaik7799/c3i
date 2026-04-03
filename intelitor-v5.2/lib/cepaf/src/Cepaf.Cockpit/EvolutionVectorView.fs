// =============================================================================
// EvolutionVectorView.fs - Evolution Vector Visualization (V1-V4)
// =============================================================================
// STAMP: SC-EVO-001 (Evolution — Shannon entropy gate),
//        SC-HMI-010 (Color Rich — vibrant chromatic feedback),
//        SC-VDP-001 (Visual Data Plane — cluster visualization),
//        SC-HMI-011 (8x8 Matrix — 100% path coverage)
// AOR: AOR-EVO-006, AOR-SING-001, AOR-MATH-007
//
// Renders the four Indrajaal evolution vectors (V1-V4) as ANSI-coloured
// radar/bar charts, tabular progress views, and compact summaries for the
// Prajna TUI cockpit and Zenoh telemetry bus.
//
// Four evolution vectors:
//   V1 Structural  — code modules, coverage        (target 1.0)
//   V2 Functional  — test pass rate, zero defects  (target 1.0)
//   V3 Safety      — STAMP compliance, SIL level   (target 1.0)
//   V4 Intelligence — AI integration, autonomy     (target 1.0)
//
// All render functions return plain strings (no I/O, no mutable state).
// Version: 21.3.2 | 2026-03-30
// =============================================================================

namespace Cepaf.Cockpit

open System

// ---------------------------------------------------------------------------
// ANSI palette (SC-CONSOL-003, SC-HMI-010)
// ---------------------------------------------------------------------------

module private EvoAnsi =
    let reset    = "\x1b[0m"
    let bold     = "\x1b[1m"
    let dim      = "\x1b[2m"
    let red      = "\x1b[31m"
    let green    = "\x1b[32m"
    let yellow   = "\x1b[33m"
    let blue     = "\x1b[34m"
    let magenta  = "\x1b[35m"
    let cyan     = "\x1b[36m"
    let white    = "\x1b[97m"
    let grey     = "\x1b[90m"
    let brightGreen   = "\x1b[92m"
    let brightYellow  = "\x1b[93m"
    let brightBlue    = "\x1b[94m"
    let brightMagenta = "\x1b[95m"
    let brightCyan    = "\x1b[96m"

    let paint (colour: string) (text: string) : string =
        sprintf "%s%s%s" colour text reset

    let boldPaint (colour: string) (text: string) : string =
        sprintf "%s%s%s%s" bold colour text reset

    /// Pick colour based on progress ratio (0.0–1.0).
    let progressColour (ratio: float) : string =
        if   ratio >= 0.90 then brightGreen
        elif ratio >= 0.75 then green
        elif ratio >= 0.50 then brightYellow
        elif ratio >= 0.25 then yellow
        else red

    /// Colour for a specific vector index (V1-V4).
    let vectorColour (idx: int) : string =
        match idx with
        | 0 -> brightCyan      // V1 Structural
        | 1 -> brightGreen     // V2 Functional
        | 2 -> brightYellow    // V3 Safety
        | 3 -> brightMagenta   // V4 Intelligence
        | _ -> white

// ---------------------------------------------------------------------------
// Domain types (public)
// ---------------------------------------------------------------------------

/// A single evolution vector measurement.
type EvolutionVector = {
    /// Short identifier, e.g. "V1".
    Id         : string
    /// Human-readable name, e.g. "Structural".
    Name       : string
    /// Measurement dimension, e.g. "code_modules|coverage".
    Dimension  : string
    /// Current progress value in [0.0, 1.0].
    Current    : float
    /// Target value (typically 1.0).
    Target     : float
    /// Rate of change per OODA cycle (signed).
    Velocity   : float
    /// ISO-8601 timestamp of last measurement.
    Timestamp  : string
}

/// Snapshot of all four evolution vectors.
type VectorVisualization = {
    /// Ordered list of evolution vectors (V1–V4).
    Vectors         : EvolutionVector list
    /// Weighted mean of Current/Target across all vectors.
    OverallProgress : float
    /// ISO-8601 timestamp of snapshot.
    Timestamp       : string
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

module private EvoHelpers =

    /// Build an ASCII progress bar of fixed width using █ / ░ characters.
    let progressBar (width: int) (ratio: float) : string =
        let filled = int (Math.Round(float width * (Math.Clamp(ratio, 0.0, 1.0))))
        let empty  = width - filled
        sprintf "%s%s" (String.replicate filled "█") (String.replicate empty "░")

    /// Format a float as a percentage string: "87.3%"
    let pct (v: float) : string = sprintf "%.1f%%" (v * 100.0)

    /// Format velocity with sign: "+0.012" / "-0.003"
    let vel (v: float) : string =
        if v >= 0.0 then sprintf "+%.3f" v else sprintf "%.3f" v

    /// Compute bar chart "row" for a single vector (left-aligned, fixed width).
    let vectorBarRow (idx: int) (vec: EvolutionVector) : string =
        let ratio    = if vec.Target > 0.0 then vec.Current / vec.Target else 0.0
        let colour   = EvoAnsi.vectorColour idx
        let pColour  = EvoAnsi.progressColour ratio
        let idLabel  = EvoAnsi.boldPaint colour (sprintf "%-2s" vec.Id)
        let nameLabel= EvoAnsi.paint colour (sprintf "%-14s" vec.Name)
        let bar      = EvoAnsi.paint pColour (progressBar 24 ratio)
        let pctLabel = EvoAnsi.boldPaint pColour (sprintf "%6s" (pct ratio))
        let velLabel = EvoAnsi.paint EvoAnsi.grey (sprintf "vel:%s" (vel vec.Velocity))
        sprintf " %s %s [%s]%s  %s" idLabel nameLabel bar pctLabel velLabel

    /// Horizontal separator line.
    let separator (ch: string) (width: int) : string =
        EvoAnsi.paint EvoAnsi.grey (String.replicate width ch)

// ---------------------------------------------------------------------------
// EvolutionVectorView — public API
// ---------------------------------------------------------------------------

/// Evolution Vector Visualization (V1–V4) for the Prajna Cockpit TUI.
/// SC-EVO-001, SC-HMI-010.
module EvolutionVectorView =

    // -----------------------------------------------------------------------
    // Stub data  (replace with live Zenoh / DuckDB reads in production)
    // -----------------------------------------------------------------------

    /// Return current vector state as stub data.
    ///
    /// Parameters: none
    ///
    /// Returns: VectorVisualization snapshot with stub values derived from
    ///          recent project KPIs (v21.3.2-SIL6, 2026-03-30).
    let getVectors () : VectorVisualization =
        let ts = "2026-03-30T00:00:00Z"
        let vectors = [
            { Id        = "V1"
              Name      = "Structural"
              Dimension = "code_modules|coverage"
              Current   = 0.86
              Target    = 1.0
              Velocity  = 0.012
              Timestamp = ts }
            { Id        = "V2"
              Name      = "Functional"
              Dimension = "test_pass_rate|zero_defects"
              Current   = 0.97
              Target    = 1.0
              Velocity  = 0.003
              Timestamp = ts }
            { Id        = "V3"
              Name      = "Safety"
              Dimension = "stamp_compliance|sil_level"
              Current   = 0.94
              Target    = 1.0
              Velocity  = 0.008
              Timestamp = ts }
            { Id        = "V4"
              Name      = "Intelligence"
              Dimension = "ai_integration|autonomy"
              Current   = 0.74
              Target    = 1.0
              Velocity  = 0.021
              Timestamp = ts }
        ]
        let overall =
            vectors
            |> List.averageBy (fun v -> if v.Target > 0.0 then v.Current / v.Target else 0.0)
        { Vectors = vectors; OverallProgress = overall; Timestamp = ts }

    // -----------------------------------------------------------------------
    // renderVectorChart — ANSI radar / bar chart
    // -----------------------------------------------------------------------

    /// Render a horizontal bar chart of all evolution vectors.
    ///
    /// Parameters:
    ///   viz — VectorVisualization snapshot
    ///
    /// Returns: multi-line ANSI string suitable for terminal output (80 cols).
    let renderVectorChart (viz: VectorVisualization) : string =
        let header =
            EvoAnsi.boldPaint EvoAnsi.cyan
                "╔══════════════════════════════════════════════════════════╗"
        let title  =
            EvoAnsi.boldPaint EvoAnsi.cyan
                "║        EVOLUTION VECTORS  V1–V4   (SC-EVO-001)          ║"
        let footer =
            EvoAnsi.boldPaint EvoAnsi.cyan
                "╚══════════════════════════════════════════════════════════╝"
        let sep = EvoHelpers.separator "─" 60
        let rows =
            viz.Vectors
            |> List.mapi EvoHelpers.vectorBarRow
        let overallRatio = viz.OverallProgress
        let overallColour = EvoAnsi.progressColour overallRatio
        let overallBar  = EvoAnsi.paint overallColour (EvoHelpers.progressBar 24 overallRatio)
        let overallPct  = EvoAnsi.boldPaint overallColour (sprintf "%6s" (EvoHelpers.pct overallRatio))
        let overallRow  =
            sprintf " %s %s [%s]%s"
                (EvoAnsi.boldPaint EvoAnsi.white "OV")
                (EvoAnsi.paint EvoAnsi.white (sprintf "%-14s" "Overall"))
                overallBar
                overallPct
        let tsRow = EvoAnsi.paint EvoAnsi.grey (sprintf " Snapshot: %s" viz.Timestamp)
        [ header; title; sep ]
        @ rows
        @ [ sep; overallRow; sep; tsRow; footer ]
        |> String.concat "\n"

    // -----------------------------------------------------------------------
    // renderVectorTable — tabular view with progress bars
    // -----------------------------------------------------------------------

    /// Render a tabular view with columns: ID, Name, Current, Target, %, Bar, Velocity.
    ///
    /// Parameters:
    ///   viz — VectorVisualization snapshot
    ///
    /// Returns: multi-line ANSI table string.
    let renderVectorTable (viz: VectorVisualization) : string =
        let colHdr =
            EvoAnsi.paint EvoAnsi.grey
                (sprintf " %-4s %-14s %8s %8s %7s  %-16s  %8s"
                    "ID" "Name" "Current" "Target" "%" "Progress" "Velocity")
        let sep = EvoHelpers.separator "─" 76
        let rows =
            viz.Vectors
            |> List.mapi (fun i vec ->
                let ratio   = if vec.Target > 0.0 then vec.Current / vec.Target else 0.0
                let colour  = EvoAnsi.vectorColour i
                let pColour = EvoAnsi.progressColour ratio
                let bar     = EvoAnsi.paint pColour (EvoHelpers.progressBar 16 ratio)
                sprintf " %s %-14s %8s %8s %s  [%s]  %s"
                    (EvoAnsi.boldPaint colour (sprintf "%-4s" vec.Id))
                    (EvoAnsi.paint colour vec.Name)
                    (EvoAnsi.paint EvoAnsi.white (sprintf "%.4f" vec.Current))
                    (EvoAnsi.paint EvoAnsi.grey  (sprintf "%.4f" vec.Target))
                    (EvoAnsi.boldPaint pColour   (sprintf "%6s" (EvoHelpers.pct ratio)))
                    bar
                    (EvoAnsi.paint EvoAnsi.grey  (EvoHelpers.vel vec.Velocity)))
        let title =
            EvoAnsi.boldPaint EvoAnsi.cyan
                "EVOLUTION VECTOR TABLE  (SC-EVO-001, SC-HMI-010)"
        [ title; sep; colHdr; sep ]
        @ rows
        @ [ sep
            EvoAnsi.paint EvoAnsi.grey
                (sprintf " Overall: %s  |  Snapshot: %s"
                    (EvoHelpers.pct viz.OverallProgress) viz.Timestamp) ]
        |> String.concat "\n"

    // -----------------------------------------------------------------------
    // renderCompact — single-line summary
    // -----------------------------------------------------------------------

    /// Render a single-line summary suitable for a status bar or log line.
    ///
    /// Parameters:
    ///   viz — VectorVisualization snapshot
    ///
    /// Returns: compact ANSI string (fits in ~100 columns).
    let renderCompact (viz: VectorVisualization) : string =
        let vectorTokens =
            viz.Vectors
            |> List.mapi (fun i vec ->
                let ratio  = if vec.Target > 0.0 then vec.Current / vec.Target else 0.0
                let colour = EvoAnsi.vectorColour i
                let pColour= EvoAnsi.progressColour ratio
                sprintf "%s%s"
                    (EvoAnsi.boldPaint colour (sprintf "%s:" vec.Id))
                    (EvoAnsi.paint pColour (EvoHelpers.pct ratio)))
            |> String.concat "  "
        let overallToken =
            EvoAnsi.boldPaint (EvoAnsi.progressColour viz.OverallProgress)
                (sprintf "OV:%s" (EvoHelpers.pct viz.OverallProgress))
        sprintf "[EVO] %s  |  %s" vectorTokens overallToken

    // -----------------------------------------------------------------------
    // toJson — serialization
    // -----------------------------------------------------------------------

    /// Serialize a VectorVisualization to a compact JSON string.
    ///
    /// Parameters:
    ///   viz — VectorVisualization snapshot
    ///
    /// Returns: JSON string (no external dependencies, hand-built).
    let toJson (viz: VectorVisualization) : string =
        let escStr (s: string) = s.Replace("\\", "\\\\").Replace("\"", "\\\"")
        let vectorJson (v: EvolutionVector) =
            sprintf
                "{\"id\":\"%s\",\"name\":\"%s\",\"dimension\":\"%s\",\"current\":%.4f,\"target\":%.4f,\"velocity\":%.4f,\"timestamp\":\"%s\"}"
                (escStr v.Id) (escStr v.Name) (escStr v.Dimension)
                v.Current v.Target v.Velocity (escStr v.Timestamp)
        let arrJson =
            viz.Vectors
            |> List.map vectorJson
            |> String.concat ","
        sprintf
            "{\"vectors\":[%s],\"overall_progress\":%.4f,\"timestamp\":\"%s\"}"
            arrJson viz.OverallProgress (escStr viz.Timestamp)
