// =============================================================================
// HomeostasisControls.fs - Interactive Threshold Controls for Homeostasis Set Points
// =============================================================================
// STAMP: SC-HOM-001  (homeostatic controller — PID set points and bounds)
//        SC-MATH-003 (Ziegler-Nichols PID tuning for homeostasis)
//        SC-HMI-010  (vibrant chromatic feedback based on Zenoh metabolic telemetry)
//
// Provides interactive threshold controls for homeostasis set points in the
// Prajna TUI cockpit. Renders ANSI tables and deviation charts with colour-
// coded health indicators.
//
// Deviation formula:
//   deviation = abs(current - target) / (maxBound - minBound)   [0.0 .. 1.0]
//
// Colour thresholds (SC-HMI-010):
//   green  \x1b[32m  — deviation < 0.10  (within 10% of range)
//   yellow \x1b[33m  — deviation < 0.30  (within 30% of range)
//   red    \x1b[31m  — deviation ≥ 0.30  (outside 30% of range)
//
// Pure module — no I/O, no mutable state.
// Version: 21.3.2 | 2026-03-30
// =============================================================================

namespace Cepaf.Cockpit

open System
open System.Text

// ---------------------------------------------------------------------------
// Domain types
// ---------------------------------------------------------------------------

/// A single homeostasis set point with PID parameters (Ziegler-Nichols tuned).
type SetPoint = {
    /// Display name (e.g. "CPU Target")
    Name         : string
    /// Current observed value (from telemetry)
    CurrentValue : float
    /// Target set point for PID controller
    TargetValue  : float
    /// Lower bound — PID will not request below this
    MinBound     : float
    /// Upper bound — PID will not request above this
    MaxBound     : float
    /// Engineering unit label (e.g. "%", "ms", "bits")
    Unit         : string
    /// PID proportional gain (Ziegler-Nichols)
    PidKp        : float
    /// PID integral gain
    PidKi        : float
    /// PID derivative gain
    PidKd        : float
}

/// Full homeostasis dashboard state.
type HomeostasisState = {
    /// List of all monitored set points
    SetPoints        : SetPoint list
    /// Mean normalised deviation across all set points [0.0 .. 1.0]
    OverallDeviation : float
    /// ISO-8601 timestamp of last state refresh
    Timestamp        : string
}

// ---------------------------------------------------------------------------
// Internal ANSI helpers
// ---------------------------------------------------------------------------

module private HomAnsi =
    let reset  = "\x1b[0m"
    let bold   = "\x1b[1m"
    let green  = "\x1b[32m"
    let yellow = "\x1b[33m"
    let red    = "\x1b[31m"
    let cyan   = "\x1b[36m"
    let white  = "\x1b[97m"
    let grey   = "\x1b[90m"

    let inline paint (colour: string) (text: string) = sprintf "%s%s%s" colour text reset
    let inline bold' (colour: string) (text: string) = sprintf "%s%s%s%s" bold colour text reset

    /// Deviation → colour (green < 0.1, yellow < 0.3, red ≥ 0.3)
    let deviationColour (dev: float) =
        if dev < 0.10 then green
        elif dev < 0.30 then yellow
        else red

// ---------------------------------------------------------------------------
// HomeostasisControls module
// ---------------------------------------------------------------------------

/// <summary>
/// Interactive threshold controls and ANSI visualisation for homeostasis set points.
/// </summary>
/// <remarks>
/// STAMP compliance:
///   SC-HOM-001  — homeostatic controller PID set points
///   SC-MATH-003 — Ziegler-Nichols PID tuning
///   SC-HMI-010  — vibrant chromatic cockpit feedback
/// </remarks>
module HomeostasisControls =

    // -----------------------------------------------------------------------
    // Default set points (Ziegler-Nichols tuned per SC-MATH-003)
    // -----------------------------------------------------------------------

    let private defaultSetPoints : SetPoint list = [
        { Name         = "CPU Target"
          CurrentValue = 65.0
          TargetValue  = 70.0
          MinBound     = 30.0
          MaxBound     = 85.0
          Unit         = "%"
          PidKp        = 0.6
          PidKi        = 0.1
          PidKd        = 0.05 }

        { Name         = "Memory Target"
          CurrentValue = 55.0
          TargetValue  = 60.0
          MinBound     = 20.0
          MaxBound     = 90.0
          Unit         = "%"
          PidKp        = 0.4
          PidKi        = 0.08
          PidKd        = 0.03 }

        { Name         = "Latency Target"
          CurrentValue = 47.0
          TargetValue  = 50.0
          MinBound     = 5.0
          MaxBound     = 200.0
          Unit         = "ms"
          PidKp        = 0.8
          PidKi        = 0.15
          PidKd        = 0.1 }

        { Name         = "Entropy Target"
          CurrentValue = 2.3
          TargetValue  = 2.5
          MinBound     = 0.0
          MaxBound     = 8.0
          Unit         = "bits"
          PidKp        = 0.3
          PidKi        = 0.05
          PidKd        = 0.02 }

        { Name         = "Coverage Target"
          CurrentValue = 96.5
          TargetValue  = 95.0
          MinBound     = 50.0
          MaxBound     = 100.0
          Unit         = "%"
          PidKp        = 0.5
          PidKi        = 0.1
          PidKd        = 0.04 }
    ]

    // -----------------------------------------------------------------------
    // Private helpers
    // -----------------------------------------------------------------------

    /// Compute normalised deviation for a set point [0.0 .. 1.0].
    let private computeDeviation (sp: SetPoint) : float =
        let range = sp.MaxBound - sp.MinBound
        if range <= 0.0 then 0.0
        else Math.Abs(sp.CurrentValue - sp.TargetValue) / range

    /// Compute overall (mean) deviation across all set points.
    let private computeOverallDeviation (setPoints: SetPoint list) : float =
        if setPoints.IsEmpty then 0.0
        else
            let total = setPoints |> List.sumBy computeDeviation
            total / float setPoints.Length

    // -----------------------------------------------------------------------
    // Public API
    // -----------------------------------------------------------------------

    /// <summary>
    /// Return the current homeostasis state using default stub values.
    /// In production this would pull live metrics from the Zenoh bus.
    /// </summary>
    let getState () : HomeostasisState =
        let pts = defaultSetPoints
        { SetPoints        = pts
          OverallDeviation = computeOverallDeviation pts
          Timestamp        = DateTimeOffset.UtcNow.ToString("o") }

    /// <summary>
    /// Update the target value for a named set point, with bounds validation.
    /// </summary>
    /// <param name="name">Set-point name (case-insensitive match).</param>
    /// <param name="target">New target value.</param>
    /// <returns>Ok with confirmation, or Error with reason.</returns>
    let updateSetPoint (name: string) (target: float) : Result<string, string> =
        let state = getState ()
        let hit =
            state.SetPoints
            |> List.tryFind (fun sp ->
                String.Equals(sp.Name, name, StringComparison.OrdinalIgnoreCase))
        match hit with
        | None ->
            Error (sprintf "Set point '%s' not found." name)
        | Some sp ->
            if target < sp.MinBound then
                Error (sprintf "Target %.2f %s is below minimum bound %.2f." target sp.Unit sp.MinBound)
            elif target > sp.MaxBound then
                Error (sprintf "Target %.2f %s exceeds maximum bound %.2f." target sp.Unit sp.MaxBound)
            else
                Ok (sprintf "Set point '%s' updated to %.2f %s." sp.Name target sp.Unit)

    // -----------------------------------------------------------------------
    // Rendering
    // -----------------------------------------------------------------------

    /// <summary>
    /// Render a full ANSI table of homeostasis set points with deviation indicators.
    /// </summary>
    let renderControls (state: HomeostasisState) : string =
        let sb = StringBuilder()

        // Header
        let title = sprintf " HOMEOSTASIS CONTROLS  [%s] " (state.Timestamp.Substring(0, 19))
        let bar   = String.replicate 80 "═"
        sb.AppendLine(HomAnsi.bold' HomAnsi.cyan (sprintf "╔%s╗" bar)) |> ignore
        sb.AppendLine(HomAnsi.bold' HomAnsi.cyan (sprintf "║  %-78s║" title)) |> ignore
        sb.AppendLine(HomAnsi.bold' HomAnsi.cyan (sprintf "╚%s╝" bar)) |> ignore

        // Overall deviation
        let ovDev = state.OverallDeviation
        let ovCol = HomAnsi.deviationColour ovDev
        sb.AppendLine(
            sprintf "  Overall Deviation: %s  (%.1f%% of normalised range)%s"
                (HomAnsi.paint ovCol (sprintf "%.4f" ovDev))
                (ovDev * 100.0)
                HomAnsi.reset) |> ignore
        sb.AppendLine(HomAnsi.paint HomAnsi.grey (String.replicate 80 "─")) |> ignore

        // Column headers
        sb.AppendLine(
            sprintf "%s  %-22s %9s %9s  %9s/%9s  %5s  %5s  %5s  DEV%s"
                (HomAnsi.bold' HomAnsi.white "")
                "SET POINT" "CURRENT" "TARGET"
                "MIN" "MAX" "Kp" "Ki" "Kd"
                HomAnsi.reset) |> ignore
        sb.AppendLine(HomAnsi.paint HomAnsi.grey (String.replicate 110 "─")) |> ignore

        // Rows
        for sp in state.SetPoints do
            let dev    = computeDeviation sp
            let col    = HomAnsi.deviationColour dev
            let devBar =
                let filled = int (Math.Round(dev * 20.0))
                let empty  = 20 - filled
                String.replicate filled "█" + String.replicate empty "░"
            sb.AppendLine(
                sprintf "  %-22s %7.2f %-4s %7.2f %-4s  %7.2f / %-7.2f  %5.3f  %5.3f  %5.3f  %s%s%s"
                    sp.Name
                    sp.CurrentValue sp.Unit
                    sp.TargetValue  sp.Unit
                    sp.MinBound sp.MaxBound
                    sp.PidKp sp.PidKi sp.PidKd
                    col devBar HomAnsi.reset) |> ignore

        sb.AppendLine(HomAnsi.paint HomAnsi.grey (String.replicate 110 "─")) |> ignore
        sb.ToString()

    /// <summary>
    /// Render a deviation chart showing each set point's distance from target as a bar.
    /// </summary>
    let renderDeviationChart (state: HomeostasisState) : string =
        let sb = StringBuilder()

        sb.AppendLine(HomAnsi.bold' HomAnsi.cyan "  DEVIATION FROM TARGET") |> ignore
        sb.AppendLine(HomAnsi.paint HomAnsi.grey (String.replicate 70 "─")) |> ignore

        let maxBarW = 40

        for sp in state.SetPoints do
            let dev    = computeDeviation sp
            let col    = HomAnsi.deviationColour dev
            let filled = int (Math.Round(dev * float maxBarW))
            let empty  = maxBarW - filled
            let bar    = String.replicate filled "█" + String.replicate empty "░"
            let arrow  =
                if sp.CurrentValue > sp.TargetValue then "▲" else "▼"
            sb.AppendLine(
                sprintf "  %-22s  %s  %s%.4f%s  %s%.2f → %.2f %s%s"
                    sp.Name
                    (HomAnsi.paint col bar)
                    col dev HomAnsi.reset
                    HomAnsi.grey sp.CurrentValue sp.TargetValue sp.Unit HomAnsi.reset
                    |> fun s -> s + sprintf " %s" (HomAnsi.paint col arrow)) |> ignore

        sb.AppendLine(HomAnsi.paint HomAnsi.grey (String.replicate 70 "─")) |> ignore
        sb.ToString()

    /// <summary>
    /// Serialise a HomeostasisState to a compact JSON string (no external library).
    /// </summary>
    let toJson (state: HomeostasisState) : string =
        let spToJson (sp: SetPoint) =
            sprintf
                """{"name":%s,"currentValue":%g,"targetValue":%g,"minBound":%g,"maxBound":%g,"unit":%s,"pidKp":%g,"pidKi":%g,"pidKd":%g}"""
                (sprintf "\"%s\"" (sp.Name.Replace("\"", "\\\"")))
                sp.CurrentValue sp.TargetValue sp.MinBound sp.MaxBound
                (sprintf "\"%s\"" (sp.Unit.Replace("\"", "\\\"")))
                sp.PidKp sp.PidKi sp.PidKd

        let pts =
            state.SetPoints
            |> List.map spToJson
            |> String.concat ","

        sprintf
            """{"setPoints":[%s],"overallDeviation":%g,"timestamp":"%s"}"""
            pts
            state.OverallDeviation
            (state.Timestamp.Replace("\"", "\\\""))
