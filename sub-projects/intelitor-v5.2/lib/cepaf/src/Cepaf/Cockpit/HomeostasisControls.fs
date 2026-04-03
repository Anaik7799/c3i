// =============================================================================
// HomeostasisControls.fs - CEPAF Cockpit TUI Homeostasis Set-Point Controls
// =============================================================================
// STAMP: SC-HOM-001 (homeostatic controller), SC-HMI-010 (Color Rich),
//        SC-MATH-003 (Ziegler-Nichols PID)
// AOR:   AOR-MATH-007 (Validate PID parameters)
//
// Pure rendering module — returns ANSI-coloured strings for individual
// homeostasis set-point gauges and the full bordered dashboard pane.
// No I/O, no side effects.  All state passed in via HomeostasisState record.
//
// ## Constitutional Alignment
// - Ψ₀ (Existence): Homeostatic set points directly guard system survival
// - Ψ₁ (Regeneration): Authoritative state stored in SQLite/DuckDB; pane
//   reflects the live snapshot forwarded from the Elixir CpuGovernor
// - Ψ₃ (Verification): All values numeric, deviation formula auditable
//
// ## STAMP Compliance
// - SC-HOM-001: Homeostatic controller — green/yellow/red encodes SIL-6 bands
// - SC-HMI-010: Vibrant chromatic feedback linked to Zenoh metabolic telemetry
// - SC-MATH-003: Ziegler-Nichols PID gains Kp/Ki/Kd rendered alongside gauges
//
// ## Colour Coding
//   Within tolerance (|Δ| ≤ tol)       → green
//   Near boundary (tol < |Δ| ≤ 2×tol)  → yellow
//   Out of band   (|Δ| > 2×tol)        → red
//
// Version: 21.3.2 | 2026-03-30
// =============================================================================

namespace Cepaf.Cockpit

open System
open System.Collections.Generic

// ---------------------------------------------------------------------------
// Domain types
// ---------------------------------------------------------------------------

/// A single homeostatic control set point with its current and target values.
type SetPoint = {
    /// Human-readable name, e.g. "CPU Temperature"
    Name         : string
    /// Measured value at the time of the snapshot
    CurrentValue : float
    /// Desired target value (the homeostatic equilibrium)
    TargetValue  : float
    /// Absolute minimum of the valid operating range
    MinValue     : float
    /// Absolute maximum of the valid operating range
    MaxValue     : float
    /// Display unit suffix, e.g. "°C", "%", "ms"
    Unit         : string
    /// Acceptable absolute deviation from TargetValue (one-sided).
    /// Values within this band are "within tolerance" (green).
    Tolerance    : float
}

/// Full snapshot of the homeostasis subsystem for one dashboard refresh cycle.
type HomeostasisState = {
    /// All monitored set points (rendered in list order)
    SetPoints    : SetPoint list
    /// Aggregate health score 0.0–1.0 (fraction of set points in green band)
    OverallHealth : float
    /// Proportional gain (Ziegler-Nichols Kp) — SC-MATH-003
    PidKp        : float
    /// Integral gain (Ziegler-Nichols Ki)
    PidKi        : float
    /// Derivative gain (Ziegler-Nichols Kd)
    PidKd        : float
    /// Snapshot wall-clock time
    LastUpdate   : DateTimeOffset
}

// ---------------------------------------------------------------------------
// Private ANSI colour helpers — inline, zero cross-project dependencies
// ---------------------------------------------------------------------------

[<RequireQualifiedAccess>]
module private HcAnsi =
    // CSI escape prefix
    let reset    = "\u001b[0m"
    let bold     = "\u001b[1m"
    let dim      = "\u001b[2m"
    // Standard colours
    let green    = "\u001b[32m"
    let yellow   = "\u001b[33m"
    let red      = "\u001b[31m"
    let cyan     = "\u001b[36m"
    let white    = "\u001b[37m"
    let magenta  = "\u001b[35m"
    // Bright variants
    let bGreen   = "\u001b[92m"
    let bYellow  = "\u001b[93m"
    let bRed     = "\u001b[91m"
    let bCyan    = "\u001b[96m"
    let bWhite   = "\u001b[97m"
    let bMagenta = "\u001b[95m"

// ---------------------------------------------------------------------------
// HomeostasisControls — pure rendering functions
// ---------------------------------------------------------------------------

/// Renders homeostasis set-point gauges for the Prajna Cockpit TUI.
/// All functions are pure (no I/O). Callers are responsible for printing.
[<RequireQualifiedAccess>]
module HomeostasisControls =

    // -----------------------------------------------------------------------
    // Internal helpers
    // -----------------------------------------------------------------------

    /// Compute absolute percentage deviation of CurrentValue from TargetValue.
    /// Returns 0.0 when TargetValue is 0.0 to avoid division by zero.
    let computeDeviation (sp: SetPoint) : float =
        if sp.TargetValue = 0.0 then
            abs sp.CurrentValue
        else
            abs (sp.CurrentValue - sp.TargetValue) / abs sp.TargetValue * 100.0

    /// Returns true when the current value is within one tolerance band of the target.
    let isWithinTolerance (sp: SetPoint) : bool =
        abs (sp.CurrentValue - sp.TargetValue) <= sp.Tolerance

    /// Select ANSI colour based on the deviation relative to the tolerance band.
    ///   |deviation| ≤ tol        → green
    ///   tol < |deviation| ≤ 2×tol → yellow
    ///   |deviation| > 2×tol      → red
    let private deviationColour (sp: SetPoint) : string =
        let delta = abs (sp.CurrentValue - sp.TargetValue)
        if delta <= sp.Tolerance            then HcAnsi.bGreen
        elif delta <= sp.Tolerance * 2.0   then HcAnsi.bYellow
        else                                    HcAnsi.bRed

    /// Colour for the overall health score: green ≥ 0.9, yellow ≥ 0.7, else red.
    let private healthColour (h: float) : string =
        if h >= 0.9      then HcAnsi.bGreen
        elif h >= 0.7    then HcAnsi.bYellow
        else                  HcAnsi.bRed

    /// Render a filled + empty ASCII progress gauge (16 chars wide by default).
    /// The gauge is anchored at MinValue; CurrentValue and TargetValue are both
    /// shown as absolute positions within [MinValue, MaxValue].
    let private gaugeBar
            (current : float)
            (target  : float)
            (minV    : float)
            (maxV    : float)
            (width   : int)
            (colour  : string) : string =
        let span = maxV - minV
        let safePct v =
            if span <= 0.0 then 0.0
            else (v - minV) / span |> max 0.0 |> min 1.0
        let curFill    = int (safePct current * float width) |> max 0 |> min width
        let tgtPos     = int (safePct target  * float width) |> max 0 |> min (width - 1)
        // Build bar char by char
        let chars = Array.create width '░'
        for i in 0 .. curFill - 1 do
            chars.[i] <- '█'
        // Overlay target marker (◆ when filled, ◇ when empty)
        if tgtPos >= 0 && tgtPos < width then
            chars.[tgtPos] <- if tgtPos < curFill then '◆' else '◇'
        sprintf "%s%s%s" colour (String(chars)) HcAnsi.reset

    /// Format a float value truncated to at most 1 decimal place,
    /// suppressing the trailing zero (e.g. 45.0 → "45", 5.3 → "5.3").
    let private fmtVal (v: float) : string =
        if v = Math.Floor v then sprintf "%.0f" v
        else                     sprintf "%.1f" v

    /// Render the ±deviation indicator with direction glyph.
    let private deviationLabel (sp: SetPoint) : string =
        let delta = sp.CurrentValue - sp.TargetValue
        let sign  = if delta >= 0.0 then "▲+" else "▼"
        sprintf "%s%s%.1f%%" (deviationColour sp) sign (abs (computeDeviation sp))

    // -----------------------------------------------------------------------
    // Public API
    // -----------------------------------------------------------------------

    /// Renders a single set point as an ANSI gauge bar with deviation indicator.
    ///
    /// Format (single line, no trailing newline):
    ///   NAME              [████████◆░░░░░░░] CUR/TGT unit  ▲+2.3%
    ///
    /// Width of name column: 22 chars (padded).
    /// Width of gauge bar: 18 chars.
    let renderSetPoint (sp: SetPoint) : string =
        let col        = deviationColour sp
        let namePadded = sp.Name.PadRight(22)
        let gauge      = gaugeBar sp.CurrentValue sp.TargetValue sp.MinValue sp.MaxValue 18 col
        let curStr     = fmtVal sp.CurrentValue
        let tgtStr     = fmtVal sp.TargetValue
        let devLabel   = deviationLabel sp
        sprintf "  %s%s%s  [%s]  %s%s%s/%s%s  %s%s"
            col namePadded HcAnsi.reset
            gauge
            col curStr HcAnsi.reset
            HcAnsi.dim tgtStr
            devLabel HcAnsi.reset
        + sprintf " %s%s%s" HcAnsi.dim sp.Unit HcAnsi.reset

    /// Renders all set points in a bordered dashboard pane together with
    /// PID parameters and the aggregate health score.
    ///
    /// Returns a multi-line ANSI-coloured string ready for Console.Write.
    let renderPane (state: HomeostasisState) : string =
        let sepColour = HcAnsi.bMagenta
        let sep       = sprintf "%s%s%s" sepColour (String.replicate 72 "─") HcAnsi.reset
        let hdr       = sprintf "%s%s HOMEOSTASIS CONTROLS %s%s"
                            HcAnsi.bold HcAnsi.bCyan HcAnsi.reset HcAnsi.reset

        let ts        = state.LastUpdate.ToString("yyyy-MM-dd HH:mm:ss zzz")

        // Health row
        let hCol      = healthColour state.OverallHealth
        let hPct      = state.OverallHealth * 100.0
        let hRow      = sprintf "  %sOverall Health:%s %s%.0f%%%s"
                            HcAnsi.dim HcAnsi.reset
                            hCol hPct HcAnsi.reset

        // PID row — SC-MATH-003 / AOR-MATH-007
        let pidRow    = sprintf "  %sPID Kp:%s %s%.4f%s  %sKi:%s %s%.4f%s  %sKd:%s %s%.4f%s"
                            HcAnsi.dim HcAnsi.reset HcAnsi.bCyan state.PidKp HcAnsi.reset
                            HcAnsi.dim HcAnsi.reset HcAnsi.bCyan state.PidKi HcAnsi.reset
                            HcAnsi.dim HcAnsi.reset HcAnsi.bCyan state.PidKd HcAnsi.reset

        // Legend row
        let legend    = sprintf "  %s[%s◆%s] target  [%s█%s] current  [%s░%s] range%s"
                            HcAnsi.dim
                            HcAnsi.white HcAnsi.dim
                            HcAnsi.white HcAnsi.dim
                            HcAnsi.white HcAnsi.dim
                            HcAnsi.reset

        // Column header
        let colHdr    = sprintf "  %s%-22s  %-20s  VALUE/TARGET  DEV%s"
                            HcAnsi.dim "SET POINT" "GAUGE" HcAnsi.reset

        // Set point rows
        let spRows    =
            state.SetPoints
            |> List.map renderSetPoint

        // Timestamp
        let timeRow   = sprintf "  %sUpdated:%s %s%s%s"
                            HcAnsi.dim HcAnsi.reset HcAnsi.white ts HcAnsi.reset

        [ ""
          sep
          sprintf "  %s" hdr
          sep
          hRow
          pidRow
          sep
          legend
          colHdr
          sep ]
        @ spRows
        @ [ sep
            timeRow
            sep
            "" ]
        |> String.concat "\n"

    /// Renders a compact one-liner summarising homeostasis state.
    ///
    /// Example:
    ///   HOM health=95%  CPU_temp=45°C(↕0.0%)  Mem_press=62%(↑3.3%)  ZenLat=5ms(↕0.0%)
    ///
    /// Returns a single ANSI-coloured line (no trailing newline).
    let renderCompact (state: HomeostasisState) : string =
        let hCol   = healthColour state.OverallHealth
        let hPart  = sprintf "HOM health=%s%.0f%%%s" hCol (state.OverallHealth * 100.0) HcAnsi.reset

        let spParts =
            state.SetPoints
            |> List.map (fun sp ->
                let col      = deviationColour sp
                let dev      = computeDeviation sp
                let devGlyph = if abs (sp.CurrentValue - sp.TargetValue) <= sp.Tolerance
                               then "↕"
                               elif sp.CurrentValue > sp.TargetValue then "↑"
                               else "↓"
                // Compact key: strip spaces from name to avoid wide output
                let key = sp.Name.Replace(" ", "_")
                sprintf "  %s=%s%s%s%s(%s%s%.1f%%%%%s)"
                    key
                    col (fmtVal sp.CurrentValue) sp.Unit HcAnsi.reset
                    col devGlyph dev HcAnsi.reset)

        hPart + (spParts |> String.concat "")

    /// Returns a default HomeostasisState populated with typical biomorphic
    /// set points:
    ///   1. CPU temperature   — target 45°C  ± 5°C
    ///   2. Memory pressure   — target 60%   ± 8%
    ///   3. Zenoh latency     — target 5 ms  ± 2 ms
    ///   4. Thread pool util  — target 70%   ± 10%
    ///   5. GC pressure       — target 30%   ± 7%
    ///
    /// All CurrentValues are initialised to their TargetValues (ideal steady state).
    let defaultState () : HomeostasisState =
        let sp name cur tgt lo hi unit tol =
            { Name         = name
              CurrentValue = cur
              TargetValue  = tgt
              MinValue     = lo
              MaxValue     = hi
              Unit         = unit
              Tolerance    = tol }

        { SetPoints =
            [ sp "CPU Temperature"      45.0  45.0   0.0  100.0  "°C"  5.0
              sp "Memory Pressure"      60.0  60.0   0.0  100.0  "%"   8.0
              sp "Zenoh Latency"         5.0   5.0   0.0   50.0  "ms"  2.0
              sp "Thread Pool Util"     70.0  70.0   0.0  100.0  "%"  10.0
              sp "GC Pressure"          30.0  30.0   0.0  100.0  "%"   7.0 ]
          OverallHealth = 1.0
          // Ziegler-Nichols PID defaults for biomorphic substrate (SC-MATH-003)
          PidKp        = 0.6000
          PidKi        = 0.1200
          PidKd        = 0.0750
          LastUpdate   = DateTimeOffset.UtcNow }
