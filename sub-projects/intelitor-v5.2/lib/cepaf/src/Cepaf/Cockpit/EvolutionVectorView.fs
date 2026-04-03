// =============================================================================
// EvolutionVectorView.fs - Evolution Vector Visualization (V1-V4)
// =============================================================================
// STAMP: SC-EVO-001 (Shannon entropy gate), SC-HMI-010 (Color Rich),
//        SC-MATH-001 (Discipline health monitored)
// AOR: AOR-BIO-004 (biomorphic dashboard), AOR-EVO-006 (evolution tracking)
//
// Renders the four evolution vectors (V1-V4) as ANSI-coloured gauges
// for the Prajna Cockpit TUI.
//
//   V1 — Substrate Saturation:  module count / target across L0-L7
//   V2 — Constraint Coverage:   documented / total SC-* constraints
//   V3 — Test Entropy:          Shannon entropy of test distribution
//   V4 — Morphogenic Velocity:  commits per day in evolution window
//
// All functions are PURE — no I/O, no side effects.
// Version: 21.3.2 | 2026-03-30
// =============================================================================

namespace Cepaf.Cockpit

open System

// ---------------------------------------------------------------------------
// Domain types
// ---------------------------------------------------------------------------

/// A single evolution vector measurement.
type EvolutionVector = {
    /// Vector identifier (V1, V2, V3, V4)
    Id          : string
    /// Human-readable label
    Label       : string
    /// Current value (0.0 – 1.0 normalised)
    Value       : float
    /// Target value (0.0 – 1.0)
    Target      : float
    /// Raw numerator (e.g. 780 modules)
    RawCount    : int
    /// Raw denominator (e.g. 1000 target modules)
    RawTotal    : int
    /// Unit label for the raw values
    Unit        : string
}

/// Snapshot of all four evolution vectors.
type EvolutionState = {
    Vectors     : EvolutionVector list
    /// Overall evolution health (geometric mean of V1-V4)
    OverallScore : float
    /// Sprint identifier
    SprintId    : string
    Timestamp   : DateTimeOffset
}

// ---------------------------------------------------------------------------
// ANSI colour helpers (inline — avoids cross-project dependency)
// ---------------------------------------------------------------------------

module private EvAnsi =
    let reset   = "\u001b[0m"
    let bold    = "\u001b[1m"
    let dim     = "\u001b[2m"
    let green   = "\u001b[92m"
    let yellow  = "\u001b[93m"
    let red     = "\u001b[91m"
    let cyan    = "\u001b[96m"
    let white   = "\u001b[97m"
    let magenta = "\u001b[95m"

// ---------------------------------------------------------------------------
// EvolutionVectorView — pure rendering functions
// ---------------------------------------------------------------------------

/// Renders evolution vector (V1-V4) visualisations as ANSI-coloured strings.
/// All functions are pure — callers handle I/O.
[<RequireQualifiedAccess>]
module EvolutionVectorView =

    // -----------------------------------------------------------------------
    // Internal helpers
    // -----------------------------------------------------------------------

    /// Select colour based on how close value is to target.
    let private colourForRatio (value: float) (target: float) : string =
        let ratio = if target > 0.0 then value / target else 0.0
        if ratio >= 0.95   then EvAnsi.green
        elif ratio >= 0.70 then EvAnsi.yellow
        else                    EvAnsi.red

    /// Render a progress bar of given width filled to pct (0–1).
    let private progressBar (pct: float) (width: int) (colour: string) : string =
        let clamped = pct |> max 0.0 |> min 1.0
        let filled  = int (clamped * float width) |> max 0 |> min width
        let empty   = width - filled
        let bar     = String.replicate filled "█" + String.replicate empty "░"
        sprintf "%s%s%s" colour bar EvAnsi.reset

    /// Render the target marker on the bar (a '│' at the target position).
    let private targetMarker (target: float) (width: int) : string =
        let pos = int (target * float width) |> max 0 |> min (width - 1)
        let before = String.replicate pos " "
        sprintf "%s%s│%s" before EvAnsi.dim EvAnsi.reset

    // -----------------------------------------------------------------------
    // Public API
    // -----------------------------------------------------------------------

    /// Renders a single evolution vector as a labelled gauge line.
    ///
    /// Example output:
    ///   V1 Substrate Sat.  ████████████████░░░░  780/1000 modules  (78.0%)
    let renderVector (v: EvolutionVector) : string =
        let pct    = if v.RawTotal > 0 then float v.RawCount / float v.RawTotal else 0.0
        let colour = colourForRatio v.Value v.Target
        let bar    = progressBar pct 20 colour
        let pctStr = sprintf "%.1f%%" (pct * 100.0)
        sprintf "  %s%s%-2s%s %-18s %s  %s%d/%d%s %-10s %s(%s)%s"
            EvAnsi.bold colour v.Id EvAnsi.reset
            v.Label
            bar
            colour v.RawCount v.RawTotal EvAnsi.reset
            v.Unit
            EvAnsi.dim pctStr EvAnsi.reset

    /// Renders all four evolution vectors as a bordered dashboard pane.
    let renderPane (state: EvolutionState) : string =
        let sep = sprintf "%s%s%s" EvAnsi.cyan (String.replicate 64 "─") EvAnsi.reset
        let hdr = sprintf "%s%s EVOLUTION VECTORS %s — Sprint %s%s"
                      EvAnsi.bold EvAnsi.magenta EvAnsi.reset state.SprintId EvAnsi.reset

        let vectorLines =
            state.Vectors
            |> List.map renderVector

        // Overall score line
        let scoreColour = colourForRatio state.OverallScore 1.0
        let scoreLine =
            sprintf "  %sOverall:%s %s  %s%.1f%%%s"
                EvAnsi.dim EvAnsi.reset
                (progressBar state.OverallScore 20 scoreColour)
                scoreColour (state.OverallScore * 100.0) EvAnsi.reset

        let ts = state.Timestamp.ToString("yyyy-MM-dd HH:mm zzz")
        let timeLine = sprintf "  %sUpdated:%s %s%s%s" EvAnsi.dim EvAnsi.reset EvAnsi.white ts EvAnsi.reset

        [ ""
          sep
          sprintf "  %s" hdr
          sep ]
        @ vectorLines
        @ [ ""
            scoreLine
            sep
            timeLine
            sep
            "" ]
        |> String.concat "\n"

    /// One-line compact summary for embedding in logs or status bars.
    let renderCompact (state: EvolutionState) : string =
        let parts =
            state.Vectors
            |> List.map (fun v ->
                let pct = if v.RawTotal > 0 then float v.RawCount / float v.RawTotal * 100.0 else 0.0
                sprintf "%s:%.0f%%" v.Id pct)
        let overall = sprintf "Evo=%.0f%%" (state.OverallScore * 100.0)
        sprintf "%s%s | %s%s" EvAnsi.dim (parts |> String.concat " ") overall EvAnsi.reset

    /// Creates a default EvolutionState with stub values for testing.
    let defaultState () : EvolutionState =
        { Vectors = [
            { Id = "V1"; Label = "Substrate Sat."; Value = 0.80; Target = 1.0
              RawCount = 800; RawTotal = 1000; Unit = "modules" }
            { Id = "V2"; Label = "Constraint Cov."; Value = 1.0; Target = 1.0
              RawCount = 2297; RawTotal = 2257; Unit = "SC-*" }
            { Id = "V3"; Label = "Test Entropy"; Value = 0.85; Target = 1.0
              RawCount = 85; RawTotal = 100; Unit = "% balanced" }
            { Id = "V4"; Label = "Morph Velocity"; Value = 0.70; Target = 1.0
              RawCount = 14; RawTotal = 20; Unit = "commits/day" }
          ]
          OverallScore = 0.83
          SprintId = "S88"
          Timestamp = DateTimeOffset.UtcNow }
