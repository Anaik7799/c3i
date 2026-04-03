module Cepaf.Tests.Unit.Cockpit.HomeostasisControlsTests

// =============================================================================
// HomeostasisControlsTests.fs
// =============================================================================
// STAMP: SC-HOM-001 (homeostatic controller), SC-HMI-010 (Color Rich),
//        SC-MATH-003 (Ziegler-Nichols PID), SC-TDG-001 (test-driven gen)
//
// Tests are written against the ACTUAL public API of HomeostasisControls.fs:
//   - defaultState()    : HomeostasisState
//   - computeDeviation  : SetPoint -> float
//   - isWithinTolerance : SetPoint -> bool
//   - renderSetPoint    : SetPoint -> string
//   - renderPane        : HomeostasisState -> string
//   - renderCompact     : HomeostasisState -> string
//
// Types verified in source (2026-03-30):
//   SetPoint       : Name, CurrentValue, TargetValue, MinValue, MaxValue, Unit, Tolerance
//   HomeostasisState : SetPoints, OverallHealth, PidKp, PidKi, PidKd, LastUpdate
// =============================================================================

open System
open Expecto

module HC = Cepaf.Cockpit.HomeostasisControls

// ---------------------------------------------------------------------------
// Helpers — build SetPoint values without relying on defaultState internals
// ---------------------------------------------------------------------------

/// Construct a SetPoint with all fields explicit.
let private mkSp name cur tgt lo hi unit tol : Cepaf.Cockpit.SetPoint =
    { Name         = name
      CurrentValue = cur
      TargetValue  = tgt
      MinValue     = lo
      MaxValue     = hi
      Unit         = unit
      Tolerance    = tol }

/// Construct a minimal HomeostasisState for rendering tests.
let private mkState (sps : Cepaf.Cockpit.SetPoint list) health : Cepaf.Cockpit.HomeostasisState =
    { SetPoints    = sps
      OverallHealth = health
      PidKp        = 0.6
      PidKi        = 0.12
      PidKd        = 0.075
      LastUpdate   = DateTimeOffset.UtcNow }

// ---------------------------------------------------------------------------
// 1. defaultState
// ---------------------------------------------------------------------------

[<Tests>]
let defaultStateTests =
    testList "HOM-DEFAULT: defaultState" [

        test "HOM-DEFAULT-001: returns exactly 5 set points" {
            let state = HC.defaultState ()
            Expect.equal state.SetPoints.Length 5
                "defaultState must return exactly 5 homeostatic set points"
        }

        test "HOM-DEFAULT-002: all set point names are non-empty" {
            let state = HC.defaultState ()
            Expect.isTrue
                (state.SetPoints |> List.forall (fun sp -> sp.Name.Length > 0))
                "Every set point name must be non-empty"
        }

        test "HOM-DEFAULT-003: includes CPU Temperature set point" {
            let state = HC.defaultState ()
            Expect.isTrue
                (state.SetPoints |> List.exists (fun sp -> sp.Name.Contains("CPU")))
                "Default state must include a CPU set point"
        }

        test "HOM-DEFAULT-004: includes Memory Pressure set point" {
            let state = HC.defaultState ()
            Expect.isTrue
                (state.SetPoints |> List.exists (fun sp -> sp.Name.Contains("Memory")))
                "Default state must include a Memory set point"
        }

        test "HOM-DEFAULT-005: all set points have MaxValue > MinValue" {
            let state = HC.defaultState ()
            Expect.isTrue
                (state.SetPoints |> List.forall (fun sp -> sp.MaxValue > sp.MinValue))
                "Every set point must have MaxValue strictly greater than MinValue"
        }

        test "HOM-DEFAULT-006: all set points have positive Tolerance" {
            let state = HC.defaultState ()
            Expect.isTrue
                (state.SetPoints |> List.forall (fun sp -> sp.Tolerance > 0.0))
                "Every set point must have a positive Tolerance"
        }

        test "HOM-DEFAULT-007: OverallHealth is 1.0 (ideal steady state)" {
            let state = HC.defaultState ()
            Expect.equal state.OverallHealth 1.0
                "defaultState OverallHealth must be 1.0 (all set points at target)"
        }

        test "HOM-DEFAULT-008: OverallHealth is in [0.0, 1.0]" {
            let state = HC.defaultState ()
            Expect.isTrue
                (state.OverallHealth >= 0.0 && state.OverallHealth <= 1.0)
                "OverallHealth must be a valid fraction in [0.0, 1.0]"
        }

        test "HOM-DEFAULT-009: PID gains are finite positive floats" {
            let state = HC.defaultState ()
            Expect.isTrue (Double.IsFinite(state.PidKp) && state.PidKp > 0.0)
                "PidKp must be a finite positive float"
            Expect.isTrue (Double.IsFinite(state.PidKi) && state.PidKi > 0.0)
                "PidKi must be a finite positive float"
            Expect.isTrue (Double.IsFinite(state.PidKd) && state.PidKd > 0.0)
                "PidKd must be a finite positive float"
        }

        test "HOM-DEFAULT-010: LastUpdate is a recent DateTimeOffset" {
            let before = DateTimeOffset.UtcNow.AddSeconds(-1.0)
            let state  = HC.defaultState ()
            let after  = DateTimeOffset.UtcNow.AddSeconds(1.0)
            Expect.isTrue
                (state.LastUpdate >= before && state.LastUpdate <= after)
                "LastUpdate must be within 1 second of UtcNow"
        }

        test "HOM-DEFAULT-011: default set points have CurrentValue equal to TargetValue" {
            let state = HC.defaultState ()
            Expect.isTrue
                (state.SetPoints |> List.forall (fun sp -> sp.CurrentValue = sp.TargetValue))
                "defaultState initialises all CurrentValues to their TargetValues (ideal state)"
        }
    ]

// ---------------------------------------------------------------------------
// 2. computeDeviation
// ---------------------------------------------------------------------------

[<Tests>]
let computeDeviationTests =
    testList "HOM-DEV: computeDeviation" [

        test "HOM-DEV-001: deviation is 0.0 when CurrentValue equals TargetValue" {
            let sp = mkSp "X" 45.0 45.0 0.0 100.0 "°C" 5.0
            Expect.equal (HC.computeDeviation sp) 0.0
                "Zero deviation when current equals target"
        }

        test "HOM-DEV-002: deviation is 50.0% when current is 150% of target" {
            // current=75, target=50 → |75-50|/50 * 100 = 50.0%
            let sp = mkSp "X" 75.0 50.0 0.0 200.0 "%" 5.0
            Expect.floatClose Accuracy.high (HC.computeDeviation sp) 50.0
                "Deviation of +50% when current is 150% of target"
        }

        test "HOM-DEV-003: deviation is 50.0% when current is below target by half" {
            // current=25, target=50 → |25-50|/50 * 100 = 50.0%
            let sp = mkSp "X" 25.0 50.0 0.0 100.0 "%" 5.0
            Expect.floatClose Accuracy.high (HC.computeDeviation sp) 50.0
                "Deviation is symmetric for equal absolute undershoot"
        }

        test "HOM-DEV-004: deviation is non-negative for any input" {
            let sp = mkSp "X" 10.0 80.0 0.0 100.0 "%" 5.0
            Expect.isTrue (HC.computeDeviation sp >= 0.0)
                "computeDeviation must always be non-negative"
        }

        test "HOM-DEV-005: TargetValue 0.0 returns absolute CurrentValue (no divide-by-zero)" {
            let sp = mkSp "X" 3.5 0.0 0.0 10.0 "ms" 0.5
            // When TargetValue = 0, the formula returns abs(CurrentValue)
            Expect.equal (HC.computeDeviation sp) 3.5
                "When TargetValue is 0.0, deviation equals abs(CurrentValue)"
        }

        test "HOM-DEV-006: deviation is a finite float" {
            let sp = mkSp "X" 62.0 60.0 0.0 100.0 "%" 8.0
            Expect.isTrue (Double.IsFinite(HC.computeDeviation sp))
                "computeDeviation must return a finite float"
        }

        test "HOM-DEV-007: 10% overshoot yields 10% deviation" {
            // current=55, target=50 → |55-50|/50 * 100 = 10.0%
            let sp = mkSp "Temp" 55.0 50.0 0.0 100.0 "°C" 5.0
            Expect.floatClose Accuracy.high (HC.computeDeviation sp) 10.0
                "10-unit overshoot on a 50-unit target = 10% deviation"
        }

        test "HOM-DEV-008: defaultState set points all have 0.0 deviation" {
            let state = HC.defaultState ()
            Expect.isTrue
                (state.SetPoints |> List.forall (fun sp -> HC.computeDeviation sp = 0.0))
                "All defaultState set points must have zero deviation"
        }
    ]

// ---------------------------------------------------------------------------
// 3. isWithinTolerance
// ---------------------------------------------------------------------------

[<Tests>]
let isWithinToleranceTests =
    testList "HOM-TOL: isWithinTolerance" [

        test "HOM-TOL-001: true when CurrentValue equals TargetValue exactly" {
            let sp = mkSp "X" 45.0 45.0 0.0 100.0 "°C" 5.0
            Expect.isTrue (HC.isWithinTolerance sp)
                "Exact target match must be within tolerance"
        }

        test "HOM-TOL-002: true when deviation equals Tolerance exactly (boundary inclusive)" {
            // current = target + tolerance → |delta| = tolerance → within tolerance
            let sp = mkSp "X" 50.0 45.0 0.0 100.0 "°C" 5.0
            Expect.isTrue (HC.isWithinTolerance sp)
                "Deviation exactly equal to Tolerance must be within tolerance (<=)"
        }

        test "HOM-TOL-003: false when deviation exceeds Tolerance by a small epsilon" {
            // current = target + tolerance + epsilon
            let sp = mkSp "X" 50.001 45.0 0.0 100.0 "°C" 5.0
            Expect.isFalse (HC.isWithinTolerance sp)
                "Deviation exceeding Tolerance by epsilon must not be within tolerance"
        }

        test "HOM-TOL-004: true for negative deviation within tolerance" {
            // current = target - tolerance (undershoot, still within)
            let sp = mkSp "X" 40.0 45.0 0.0 100.0 "°C" 5.0
            Expect.isTrue (HC.isWithinTolerance sp)
                "Undershoot equal to Tolerance must still be within tolerance"
        }

        test "HOM-TOL-005: false for large overshoot" {
            let sp = mkSp "X" 90.0 45.0 0.0 100.0 "°C" 5.0
            Expect.isFalse (HC.isWithinTolerance sp)
                "Large overshoot must not be within tolerance"
        }

        test "HOM-TOL-006: false for large undershoot" {
            let sp = mkSp "X" 10.0 60.0 0.0 100.0 "%" 8.0
            Expect.isFalse (HC.isWithinTolerance sp)
                "Large undershoot must not be within tolerance"
        }

        test "HOM-TOL-007: all defaultState set points are within tolerance (ideal state)" {
            let state = HC.defaultState ()
            Expect.isTrue
                (state.SetPoints |> List.forall HC.isWithinTolerance)
                "All defaultState set points must be within tolerance"
        }
    ]

// ---------------------------------------------------------------------------
// 4. renderSetPoint
// ---------------------------------------------------------------------------

[<Tests>]
let renderSetPointTests =
    testList "HOM-RSP: renderSetPoint" [

        test "HOM-RSP-001: returns non-empty string" {
            let sp = mkSp "CPU Temperature" 45.0 45.0 0.0 100.0 "°C" 5.0
            let result = HC.renderSetPoint sp
            Expect.isTrue (result.Length > 0)
                "renderSetPoint must return a non-empty string"
        }

        test "HOM-RSP-002: output contains ANSI escape codes (SC-HMI-010)" {
            let sp = mkSp "CPU Temperature" 45.0 45.0 0.0 100.0 "°C" 5.0
            let result = HC.renderSetPoint sp
            Expect.stringContains result "\u001b["
                "renderSetPoint must contain ANSI escape codes for colour (SC-HMI-010)"
        }

        test "HOM-RSP-003: output contains the set point name" {
            let sp = mkSp "CPU Temperature" 45.0 45.0 0.0 100.0 "°C" 5.0
            let result = HC.renderSetPoint sp
            Expect.stringContains result "CPU Temperature"
                "renderSetPoint must include the set point name"
        }

        test "HOM-RSP-004: output contains the unit string" {
            let sp = mkSp "Zenoh Latency" 5.0 5.0 0.0 50.0 "ms" 2.0
            let result = HC.renderSetPoint sp
            Expect.stringContains result "ms"
                "renderSetPoint must include the unit string"
        }

        test "HOM-RSP-005: at-target set point contains bright green code (deviation within tolerance)" {
            // At target → delta ≤ tolerance → bGreen = ESC[92m
            let sp = mkSp "Memory Pressure" 60.0 60.0 0.0 100.0 "%" 8.0
            let result = HC.renderSetPoint sp
            Expect.stringContains result "\u001b[92m"
                "At-target set point must use bright green (ESC[92m) colour coding"
        }

        test "HOM-RSP-006: yellow band set point contains bright yellow code" {
            // delta = 1.5 × tolerance → falls in yellow band (tol < delta ≤ 2×tol)
            // For tol=5.0: delta must be in (5, 10]. Use delta = 7.5
            let sp = mkSp "CPU Temperature" 52.5 45.0 0.0 100.0 "°C" 5.0
            let result = HC.renderSetPoint sp
            Expect.stringContains result "\u001b[93m"
                "Near-boundary deviation must produce bright yellow (ESC[93m) colour"
        }

        test "HOM-RSP-007: red band set point contains bright red code" {
            // delta > 2 × tolerance → red. For tol=5: current=56 (delta=11 > 10)
            let sp = mkSp "CPU Temperature" 56.0 45.0 0.0 100.0 "°C" 5.0
            let result = HC.renderSetPoint sp
            Expect.stringContains result "\u001b[91m"
                "Out-of-band deviation must produce bright red (ESC[91m) colour"
        }

        test "HOM-RSP-008: output is a single line (no embedded newlines)" {
            let sp = mkSp "Thread Pool Util" 70.0 70.0 0.0 100.0 "%" 10.0
            let result = HC.renderSetPoint sp
            Expect.isFalse (result.Contains('\n'))
                "renderSetPoint must produce a single line without embedded newlines"
        }

        test "HOM-RSP-009: output contains gauge bar characters" {
            let sp = mkSp "GC Pressure" 30.0 30.0 0.0 100.0 "%" 7.0
            let result = HC.renderSetPoint sp
            // Gauge bar uses '█', '░', '◆', or '◇'
            let hasGaugeChar =
                result.Contains('█') || result.Contains('░') ||
                result.Contains('◆') || result.Contains('◇')
            Expect.isTrue hasGaugeChar
                "renderSetPoint output must contain ASCII gauge bar characters"
        }
    ]

// ---------------------------------------------------------------------------
// 5. renderPane
// ---------------------------------------------------------------------------

[<Tests>]
let renderPaneTests =
    testList "HOM-PANE: renderPane" [

        test "HOM-PANE-001: returns non-empty string" {
            let state = HC.defaultState ()
            let result = HC.renderPane state
            Expect.isTrue (result.Length > 0)
                "renderPane must return a non-empty string"
        }

        test "HOM-PANE-002: output contains ANSI escape codes (SC-HMI-010)" {
            let state = HC.defaultState ()
            let result = HC.renderPane state
            Expect.stringContains result "\u001b["
                "renderPane must contain ANSI escape codes (SC-HMI-010)"
        }

        test "HOM-PANE-003: output contains HOMEOSTASIS header keyword" {
            let state = HC.defaultState ()
            let result = HC.renderPane state
            Expect.stringContains result "HOMEOSTASIS"
                "renderPane must include the HOMEOSTASIS header"
        }

        test "HOM-PANE-004: output is multi-line (contains newlines)" {
            let state = HC.defaultState ()
            let result = HC.renderPane state
            Expect.isTrue (result.Contains('\n'))
                "renderPane must produce multi-line output"
        }

        test "HOM-PANE-005: output contains separator line made of '─' characters" {
            let state = HC.defaultState ()
            let result = HC.renderPane state
            Expect.stringContains result "─"
                "renderPane must include a separator line using '─' characters"
        }

        test "HOM-PANE-006: output contains PID keyword (SC-MATH-003)" {
            let state = HC.defaultState ()
            let result = HC.renderPane state
            Expect.stringContains result "PID"
                "renderPane must display PID parameters (SC-MATH-003 / AOR-MATH-007)"
        }

        test "HOM-PANE-007: output contains Overall Health row" {
            let state = HC.defaultState ()
            let result = HC.renderPane state
            Expect.stringContains result "Overall Health"
                "renderPane must include the Overall Health row"
        }

        test "HOM-PANE-008: output contains each set point name" {
            let state = HC.defaultState ()
            let result = HC.renderPane state
            for sp in state.SetPoints do
                Expect.stringContains result sp.Name
                    (sprintf "renderPane must include set point '%s'" sp.Name)
        }

        test "HOM-PANE-009: 100% health renders overall health as 100%" {
            let state = mkState [ mkSp "X" 1.0 1.0 0.0 10.0 "u" 0.5 ] 1.0
            let result = HC.renderPane state
            Expect.stringContains result "100%"
                "renderPane with OverallHealth=1.0 must show 100%"
        }

        test "HOM-PANE-010: low health uses bright red for overall health row" {
            let state = mkState [ mkSp "X" 1.0 1.0 0.0 10.0 "u" 0.5 ] 0.5
            let result = HC.renderPane state
            // healthColour: < 0.7 → bRed = ESC[91m
            Expect.stringContains result "\u001b[91m"
                "Low OverallHealth (< 0.70) must use bright red colour (ESC[91m)"
        }

        test "HOM-PANE-011: high health uses bright green for overall health row" {
            let state = mkState [ mkSp "X" 1.0 1.0 0.0 10.0 "u" 0.5 ] 1.0
            let result = HC.renderPane state
            // healthColour: >= 0.9 → bGreen = ESC[92m
            Expect.stringContains result "\u001b[92m"
                "High OverallHealth (>= 0.90) must use bright green colour (ESC[92m)"
        }

        test "HOM-PANE-012: output contains timestamp keyword 'Updated'" {
            let state = HC.defaultState ()
            let result = HC.renderPane state
            Expect.stringContains result "Updated"
                "renderPane must include a timestamp row labelled 'Updated'"
        }

        test "HOM-PANE-013: Kp value appears in PID row" {
            let state = { HC.defaultState () with PidKp = 1.2345 }
            let result = HC.renderPane state
            Expect.stringContains result "1.2345"
                "renderPane PID row must display the Kp value"
        }
    ]

// ---------------------------------------------------------------------------
// 6. renderCompact
// ---------------------------------------------------------------------------

[<Tests>]
let renderCompactTests =
    testList "HOM-COMPACT: renderCompact" [

        test "HOM-COMPACT-001: returns non-empty string" {
            let state = HC.defaultState ()
            let result = HC.renderCompact state
            Expect.isTrue (result.Length > 0)
                "renderCompact must return a non-empty string"
        }

        test "HOM-COMPACT-002: output contains ANSI escape codes (SC-HMI-010)" {
            let state = HC.defaultState ()
            let result = HC.renderCompact state
            Expect.stringContains result "\u001b["
                "renderCompact must contain ANSI escape codes (SC-HMI-010)"
        }

        test "HOM-COMPACT-003: output contains HOM prefix" {
            let state = HC.defaultState ()
            let result = HC.renderCompact state
            Expect.stringContains result "HOM"
                "renderCompact must include the 'HOM' prefix"
        }

        test "HOM-COMPACT-004: output contains health percentage" {
            let state = HC.defaultState ()
            let result = HC.renderCompact state
            Expect.stringContains result "health="
                "renderCompact must contain 'health=' label"
        }

        test "HOM-COMPACT-005: output is a single line (no embedded newlines)" {
            let state = HC.defaultState ()
            let result = HC.renderCompact state
            Expect.isFalse (result.Contains('\n'))
                "renderCompact must produce a single line without newlines"
        }

        test "HOM-COMPACT-006: at-target set points show '↕' glyph (no deviation)" {
            // At exactly target → delta ≤ tolerance → "↕" glyph
            let state = HC.defaultState ()
            let result = HC.renderCompact state
            Expect.stringContains result "↕"
                "renderCompact must show '↕' glyph for set points at target"
        }

        test "HOM-COMPACT-007: overshoot set point shows '↑' glyph" {
            let sp    = mkSp "CPU Temperature" 60.0 45.0 0.0 100.0 "°C" 5.0
            let state = mkState [ sp ] 0.5
            let result = HC.renderCompact state
            Expect.stringContains result "↑"
                "renderCompact must show '↑' glyph when CurrentValue > TargetValue"
        }

        test "HOM-COMPACT-008: undershoot set point shows '↓' glyph" {
            let sp    = mkSp "CPU Temperature" 30.0 45.0 0.0 100.0 "°C" 5.0
            let state = mkState [ sp ] 0.5
            let result = HC.renderCompact state
            Expect.stringContains result "↓"
                "renderCompact must show '↓' glyph when CurrentValue < TargetValue"
        }

        test "HOM-COMPACT-009: set point name appears in compact output (underscored)" {
            let sp    = mkSp "CPU Temperature" 45.0 45.0 0.0 100.0 "°C" 5.0
            let state = mkState [ sp ] 1.0
            let result = HC.renderCompact state
            // Name has spaces replaced with underscores in compact output
            Expect.stringContains result "CPU_Temperature"
                "renderCompact must replace spaces with underscores in set point keys"
        }

        test "HOM-COMPACT-010: 100% health output contains '100%'" {
            let state = mkState [ mkSp "X" 1.0 1.0 0.0 10.0 "u" 0.1 ] 1.0
            let result = HC.renderCompact state
            Expect.stringContains result "100%"
                "renderCompact with OverallHealth=1.0 must display '100%'"
        }
    ]

// ---------------------------------------------------------------------------
// Aggregate test list
// ---------------------------------------------------------------------------

[<Tests>]
let allHomeostasisControlsTests =
    testList "Homeostasis Controls" [
        defaultStateTests
        computeDeviationTests
        isWithinToleranceTests
        renderSetPointTests
        renderPaneTests
        renderCompactTests
    ]
