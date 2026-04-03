// =============================================================================
// SparklineRenderer.fs - CEPAF Cockpit TUI Sparkline Charts
// =============================================================================
// STAMP: SC-HMI-010 (Color Rich), SC-CPU-GOV-001
// AOR: AOR-MON-004 (30s refresh), AOR-BIO-004
//
// Pure rendering module — returns ANSI-coloured sparkline strings for
// time-series metrics (CPU%, memory%) in the TUI cockpit.
// No I/O, no side effects. All state passed in via MetricSample list.
//
// ## Constitutional Alignment
// - Ψ₀ (Existence): Real-time CPU/memory sparklines track system survival
// - Ψ₃ (Verification): Sample values are numeric, auditable, time-stamped
//
// ## STAMP Compliance
// - SC-HMI-010: Vibrant chromatic feedback — green/yellow/red per threshold
// - SC-CPU-GOV-001: CPU must not exceed 85%; red sparkline signals violation
//
// ## Unicode Block Characters
// ▁▂▃▄▅▆▇█  U+2581–U+2588 (8 levels, lowest to highest)
// =============================================================================

namespace Cepaf.Cockpit

open System

// ---------------------------------------------------------------------------
// Domain types
// ---------------------------------------------------------------------------

/// A single time-stamped value in a metric time-series.
type MetricSample = {
    /// Observed metric value (e.g. CPU %, memory %)
    Value     : float
    /// Wall-clock time of the observation
    Timestamp : DateTimeOffset
}

/// Configuration for rendering a single sparkline row.
type SparklineConfig = {
    /// Number of character columns in the sparkline chart
    Width    : int
    /// Value mapped to the lowest block character (▁)
    MinValue : float
    /// Value mapped to the highest block character (█)
    MaxValue : float
    /// Left-hand label text (e.g. "CPU", "MEM")
    Label    : string
    /// Unit suffix appended to the current value (e.g. "%", "MB")
    Unit     : string
}

// ---------------------------------------------------------------------------
// ANSI colour helpers (inline — avoids Cepaf.Observability dependency)
// Mirrors palette used in HealthDashboard.fs and ContainerHealthBars.fs
// ---------------------------------------------------------------------------

[<RequireQualifiedAccess>]
module private SparkAnsi =
    let reset    = "\u001b[0m"
    let bold     = "\u001b[1m"
    let dim      = "\u001b[2m"
    let green    = "\u001b[32m"
    let yellow   = "\u001b[33m"
    let red      = "\u001b[31m"
    let cyan     = "\u001b[36m"
    let white    = "\u001b[37m"
    let bGreen   = "\u001b[92m"
    let bYellow  = "\u001b[93m"
    let bRed     = "\u001b[91m"
    let bCyan    = "\u001b[96m"
    let bWhite   = "\u001b[97m"

// ---------------------------------------------------------------------------
// SparklineRenderer — pure rendering functions
// ---------------------------------------------------------------------------

/// Renders Unicode sparkline charts for time-series metrics in the TUI cockpit.
/// All functions are pure (no I/O). Callers print the returned strings.
[<RequireQualifiedAccess>]
module SparklineRenderer =

    // -----------------------------------------------------------------------
    // Internal constants
    // -----------------------------------------------------------------------

    /// 8-level Unicode block characters ▁▂▃▄▅▆▇█ (U+2581–U+2588).
    let private blocks = [| "▁"; "▂"; "▃"; "▄"; "▅"; "▆"; "▇"; "█" |]

    // -----------------------------------------------------------------------
    // Internal helpers
    // -----------------------------------------------------------------------

    /// Clamps `v` to the interval [lo, hi].
    let private clamp (lo: float) (hi: float) (v: float) : float =
        if v < lo then lo elif v > hi then hi else v

    /// Maps a single sample value to a block character (0–7 levels).
    /// Values at or below `minValue` render as ▁; at or above `maxValue` as █.
    let private sampleToBlock (minVal: float) (maxVal: float) (value: float) : string =
        let range = maxVal - minVal
        if range <= 0.0 then
            blocks.[0]
        else
            let normalised = (clamp minVal maxVal value - minVal) / range
            let idx = int (normalised * 7.0 + 0.5) |> max 0 |> min 7
            blocks.[idx]

    /// Selects ANSI colour for a value given two thresholds.
    ///   value < low  → green
    ///   value < high → yellow
    ///   value >= high → red
    let private colourForValue (value: float) (lowThreshold: float) (highThreshold: float) : string =
        if value < lowThreshold      then SparkAnsi.bGreen
        elif value < highThreshold   then SparkAnsi.bYellow
        else                              SparkAnsi.bRed

    /// Takes the most-recent `width` samples (or fewer if the list is shorter),
    /// pads with ▁ on the left if there are fewer samples than `width`.
    let private selectSamples (width: int) (samples: MetricSample list) : MetricSample list =
        let count = List.length samples
        if count = 0 then []
        elif count >= width then samples |> List.skip (count - width)
        else samples

    /// Renders the sparkline bar as an ANSI string.
    /// Each block character is coloured individually based on its value.
    let private renderBar
            (config      : SparklineConfig)
            (samples     : MetricSample list)
            (lowThresh   : float)
            (highThresh  : float) : string =
        let selected = selectSamples config.Width samples
        let count    = List.length selected

        // Pad left with dim ▁ characters when fewer samples than width
        let padCount = config.Width - count
        let padding  =
            if padCount <= 0 then ""
            else sprintf "%s%s%s" SparkAnsi.dim (String.replicate padCount "▁") SparkAnsi.reset

        let charCols =
            selected
            |> List.map (fun s ->
                let col   = colourForValue s.Value lowThresh highThresh
                let block = sampleToBlock config.MinValue config.MaxValue s.Value
                sprintf "%s%s" col block)
            |> String.concat ""

        sprintf "%s%s%s" padding charCols SparkAnsi.reset

    // -----------------------------------------------------------------------
    // Public API
    // -----------------------------------------------------------------------

    /// Renders a single sparkline row with label, chart, and current value.
    ///
    /// Format:
    ///   LABEL [▁▂▃▄▅▆▇█...] current.value UNIT
    ///
    /// - ANSI colours applied per block: green < lowThreshold, yellow < highThreshold, else red.
    /// - Empty sample list renders as all-dim ▁ padding with "--" current value.
    /// - Values outside [MinValue, MaxValue] are clamped.
    ///
    /// Returns a single ANSI-coloured line (no trailing newline).
    let renderSparkline
            (config        : SparklineConfig)
            (samples       : MetricSample list)
            (lowThreshold  : float)
            (highThreshold : float) : string =
        let labelPadded = config.Label.PadRight(6)

        // Current value: last sample or "--" if empty
        let (currentVal, currentCol) =
            match List.tryLast samples with
            | None   -> ("-- " + config.Unit, SparkAnsi.dim)
            | Some s ->
                let col = colourForValue s.Value lowThreshold highThreshold
                (sprintf "%.1f%s" s.Value config.Unit, col)

        let bar = renderBar config samples lowThreshold highThreshold

        sprintf "  %s%s%s [%s] %s%s%s"
            SparkAnsi.bCyan labelPadded SparkAnsi.reset
            bar
            currentCol currentVal SparkAnsi.reset

    /// Convenience function: renders a CPU sparkline.
    ///   Range: 0–100%, thresholds: green < 60%, yellow < 80%, red ≥ 80%.
    ///   Width: 24 characters.
    let renderCpuSparkline (samples: MetricSample list) : string =
        let config = {
            Width    = 24
            MinValue = 0.0
            MaxValue = 100.0
            Label    = "CPU"
            Unit     = "%"
        }
        renderSparkline config samples 60.0 80.0

    /// Convenience function: renders a memory sparkline.
    ///   Range: 0–100%, thresholds: green < 70%, yellow < 90%, red ≥ 90%.
    ///   Width: 24 characters.
    let renderMemorySparkline (samples: MetricSample list) : string =
        let config = {
            Width    = 24
            MinValue = 0.0
            MaxValue = 100.0
            Label    = "MEM"
            Unit     = "%"
        }
        renderSparkline config samples 70.0 90.0

    /// Renders CPU and memory sparklines on adjacent lines.
    ///
    /// Format:
    ///   CPU    [▁▂▃▄▅▆▇█...] current.value%
    ///   MEM    [▁▂▃▄▅▆▇█...] current.value%
    ///
    /// Returns a two-line ANSI-coloured string (no trailing newline).
    let renderDualSparkline
            (cpuSamples : MetricSample list)
            (memSamples : MetricSample list) : string =
        let cpuLine = renderCpuSparkline cpuSamples
        let memLine = renderMemorySparkline memSamples
        sprintf "%s\n%s" cpuLine memLine
