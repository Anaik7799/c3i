module Cepaf.Tests.Unit.Cockpit.BiomorphicMatrixTests

// =============================================================================
// BiomorphicMatrixTests.fs — Expecto tests for BiomorphicMatrix rendering module
// =============================================================================
// STAMP: SC-NASA-001, SC-HMI-010, SC-HMI-011
// AOR:   AOR-BIO-004
//
// Coverage categories:
//   C1  defaultState structure       (BM-STATE-*)
//   C2  layerLabel output            (BM-LABEL-*)
//   C3  renderLayer single-row       (BM-RLAYER-*)
//   C4  renderMatrix full pane       (BM-MATRIX-*)
//   C5  renderCompact one-liner      (BM-COMPACT-*)
//   C6  health / ratio colour coding (BM-COLOUR-*)
// =============================================================================

open System
open Expecto
open Cepaf.Cockpit

module BM = Cepaf.Cockpit.BiomorphicMatrix

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Strip all ANSI escape sequences from a string so assertions can target
/// plain text without fighting the escape codes.
let stripAnsi (s: string) : string =
    System.Text.RegularExpressions.Regex.Replace(s, "\u001b\\[[0-9;]*m", "")

/// Build a minimal LayerHealth for a given layer.
let mkLayer layer mods target cov total hs =
    let modR = if target > 0 then float mods / float target else 0.0
    let conR = if total  > 0 then float cov  / float total  else 0.0
    let entropyRatio = hs / 4.0
    let health = ((modR * 0.40) + (conR * 0.40) + (entropyRatio * 0.20)) |> max 0.0 |> min 1.0
    { Layer              = layer
      ModuleCount        = mods
      TargetCount        = target
      ConstraintsCovered = cov
      ConstraintsTotal   = total
      TestEntropy        = hs
      HealthScore        = health }

/// A minimal BiomorphicState with a single layer, useful for targeted tests.
let singleLayerState layer mods target cov total hs =
    let lh = mkLayer layer mods target cov total hs
    { Layers            = [ lh ]
      OverallSaturation = if target > 0 then float mods / float target else 0.0
      Timestamp         = DateTimeOffset.UtcNow }

// ---------------------------------------------------------------------------
// C1: defaultState structure
// ---------------------------------------------------------------------------

[<Tests>]
let defaultStateTests =
    testList "BM-STATE: defaultState structure" [

        test "BM-STATE-001: defaultState returns exactly 8 layers" {
            let state = BM.defaultState ()
            Expect.equal state.Layers.Length 8
                "defaultState must return exactly 8 fractal layers (L0-L7)"
        }

        test "BM-STATE-002: OverallSaturation is in (0.0, 1.0]" {
            let state = BM.defaultState ()
            Expect.isTrue (state.OverallSaturation > 0.0 && state.OverallSaturation <= 1.0)
                "OverallSaturation must be a ratio in (0, 1]"
        }

        test "BM-STATE-003: OverallSaturation equals modules/targets ratio" {
            let state = BM.defaultState ()
            let totalMods   = state.Layers |> List.sumBy (fun l -> l.ModuleCount)
            let totalTarget = state.Layers |> List.sumBy (fun l -> l.TargetCount)
            let expected    = float totalMods / float totalTarget
            Expect.floatClose Accuracy.medium state.OverallSaturation expected
                "OverallSaturation must equal sum(ModuleCount)/sum(TargetCount)"
        }

        test "BM-STATE-004: all layers have HealthScore in [0.0, 1.0]" {
            let state = BM.defaultState ()
            let allValid = state.Layers |> List.forall (fun l -> l.HealthScore >= 0.0 && l.HealthScore <= 1.0)
            Expect.isTrue allValid "Every layer HealthScore must be in [0.0, 1.0]"
        }

        test "BM-STATE-005: all layers have ModuleCount <= TargetCount" {
            let state = BM.defaultState ()
            let allValid = state.Layers |> List.forall (fun l -> l.ModuleCount <= l.TargetCount)
            Expect.isTrue allValid "ModuleCount must not exceed TargetCount for any layer"
        }

        test "BM-STATE-006: L0_Constitution layer is present and has highest module target" {
            let state = BM.defaultState ()
            let l0 = state.Layers |> List.find (fun l -> l.Layer = FractalLayer.L0_Constitution)
            let maxTarget = state.Layers |> List.map (fun l -> l.TargetCount) |> List.max
            Expect.equal l0.TargetCount maxTarget
                "L0_Constitution must have the largest TargetCount (1000)"
        }

        test "BM-STATE-007: Timestamp is close to UtcNow (within 5 seconds)" {
            let before = DateTimeOffset.UtcNow
            let state  = BM.defaultState ()
            let after  = DateTimeOffset.UtcNow
            Expect.isTrue (state.Timestamp >= before && state.Timestamp <= after)
                "Timestamp must be captured at call time"
        }

        test "BM-STATE-008: all eight fractal layers are represented" {
            let state = BM.defaultState ()
            let layers = state.Layers |> List.map (fun l -> l.Layer)
            let expected = [
                FractalLayer.L0_Constitution
                FractalLayer.L1_Physical
                FractalLayer.L2_DataLink
                FractalLayer.L3_Network
                FractalLayer.L4_Transport
                FractalLayer.L5_Session
                FractalLayer.L6_Presentation
                FractalLayer.L7_Application
            ]
            Expect.equal layers expected "Layers must appear in L0-L7 order"
        }
    ]

// ---------------------------------------------------------------------------
// C2: layerLabel output
// ---------------------------------------------------------------------------

[<Tests>]
let layerLabelTests =
    testList "BM-LABEL: layerLabel" [

        test "BM-LABEL-001: L0_Constitution label starts with 'L0'" {
            Expect.stringStarts (BM.layerLabel FractalLayer.L0_Constitution) "L0"
                "L0 label must start with 'L0'"
        }

        test "BM-LABEL-002: L7_Application label starts with 'L7'" {
            Expect.stringStarts (BM.layerLabel FractalLayer.L7_Application) "L7"
                "L7 label must start with 'L7'"
        }

        test "BM-LABEL-003: all layer labels are exactly 15 characters" {
            let layers = [
                FractalLayer.L0_Constitution; FractalLayer.L1_Physical
                FractalLayer.L2_DataLink;     FractalLayer.L3_Network
                FractalLayer.L4_Transport;    FractalLayer.L5_Session
                FractalLayer.L6_Presentation; FractalLayer.L7_Application
            ]
            for layer in layers do
                let lbl = BM.layerLabel layer
                Expect.equal lbl.Length 15
                    (sprintf "layerLabel for %A must be 15 chars, got '%s' (%d)" layer lbl lbl.Length)
        }

        test "BM-LABEL-004: L3_Network label contains 'Network'" {
            let lbl = BM.layerLabel FractalLayer.L3_Network
            Expect.stringContains lbl "Network" "L3 label must contain 'Network'"
        }

        test "BM-LABEL-005: L5_Session label contains 'Session'" {
            let lbl = BM.layerLabel FractalLayer.L5_Session
            Expect.stringContains lbl "Session" "L5 label must contain 'Session'"
        }
    ]

// ---------------------------------------------------------------------------
// C3: renderLayer single-row output
// ---------------------------------------------------------------------------

[<Tests>]
let renderLayerTests =
    testList "BM-RLAYER: renderLayer" [

        test "BM-RLAYER-001: renderLayer returns a non-empty string" {
            let lh = mkLayer FractalLayer.L3_Network 280 350 210 245 2.90
            let row = BM.renderLayer lh
            Expect.isTrue (row.Length > 0) "renderLayer must return content"
        }

        test "BM-RLAYER-002: renderLayer output contains ANSI escape codes (SC-HMI-010)" {
            let lh = mkLayer FractalLayer.L1_Physical 320 400 187 210 2.80
            let row = BM.renderLayer lh
            Expect.stringContains row "\u001b[" "renderLayer must emit ANSI colour codes"
        }

        test "BM-RLAYER-003: renderLayer plain text contains layer label" {
            let lh = mkLayer FractalLayer.L2_DataLink 240 300 156 180 2.65
            let plain = stripAnsi (BM.renderLayer lh)
            Expect.stringContains plain "L2 DataLink" "Row must contain the layer label"
        }

        test "BM-RLAYER-004: renderLayer plain text contains 'MOD' column header" {
            let lh = mkLayer FractalLayer.L4_Transport 200 250 148 170 2.55
            let plain = stripAnsi (BM.renderLayer lh)
            Expect.stringContains plain "MOD" "Row must contain 'MOD' column label"
        }

        test "BM-RLAYER-005: renderLayer plain text contains 'CON' column header" {
            let lh = mkLayer FractalLayer.L4_Transport 200 250 148 170 2.55
            let plain = stripAnsi (BM.renderLayer lh)
            Expect.stringContains plain "CON" "Row must contain 'CON' column label"
        }

        test "BM-RLAYER-006: renderLayer plain text contains 'HS' health score column" {
            let lh = mkLayer FractalLayer.L5_Session 160 200 119 140 2.70
            let plain = stripAnsi (BM.renderLayer lh)
            Expect.stringContains plain "HS" "Row must contain 'HS' health score column"
        }

        test "BM-RLAYER-007: renderLayer plain text contains the module count" {
            let lh = mkLayer FractalLayer.L7_Application 400 500 312 370 3.05
            let plain = stripAnsi (BM.renderLayer lh)
            Expect.stringContains plain "400" "Row must contain the module count 400"
        }

        test "BM-RLAYER-008: renderLayer plain text contains entropy glyph for high entropy" {
            // High entropy (>= 2.5) maps to '▓'
            let lh = mkLayer FractalLayer.L0_Constitution 800 1000 292 320 3.10
            let plain = stripAnsi (BM.renderLayer lh)
            Expect.stringContains plain "▓" "High-entropy row must contain '▓' glyph"
        }

        test "BM-RLAYER-009: renderLayer plain text contains '░' glyph for low entropy" {
            // Low entropy (< 2.0) maps to '░'
            let lh = mkLayer FractalLayer.L6_Presentation 120 150 98 115 1.50
            let plain = stripAnsi (BM.renderLayer lh)
            Expect.stringContains plain "░" "Low-entropy row must contain '░' glyph"
        }

        test "BM-RLAYER-010: renderLayer does not contain a newline character" {
            let lh = mkLayer FractalLayer.L3_Network 280 350 210 245 2.90
            let row = BM.renderLayer lh
            Expect.isFalse (row.Contains('\n')) "renderLayer must return a single line (no newline)"
        }
    ]

// ---------------------------------------------------------------------------
// C4: renderMatrix full pane
// ---------------------------------------------------------------------------

[<Tests>]
let renderMatrixTests =
    testList "BM-MATRIX: renderMatrix" [

        test "BM-MATRIX-001: renderMatrix returns a non-empty multi-line string" {
            let state = BM.defaultState ()
            let result = BM.renderMatrix state
            Expect.isTrue (result.Contains('\n')) "renderMatrix must be multi-line"
        }

        test "BM-MATRIX-002: renderMatrix contains ANSI escape codes (SC-HMI-010)" {
            let state = BM.defaultState ()
            let result = BM.renderMatrix state
            Expect.stringContains result "\u001b[" "renderMatrix must contain ANSI codes"
        }

        test "BM-MATRIX-003: renderMatrix plain text contains 'BIOMORPHIC MATRIX' header" {
            let state = BM.defaultState ()
            let plain = stripAnsi (BM.renderMatrix state)
            Expect.stringContains plain "BIOMORPHIC MATRIX"
                "renderMatrix must display the BIOMORPHIC MATRIX header"
        }

        test "BM-MATRIX-004: renderMatrix plain text contains 'NASA-STD-3000' reference (SC-NASA-001)" {
            let state = BM.defaultState ()
            let plain = stripAnsi (BM.renderMatrix state)
            Expect.stringContains plain "NASA-STD-3000"
                "renderMatrix must reference NASA-STD-3000 (SC-NASA-001)"
        }

        test "BM-MATRIX-005: renderMatrix plain text contains all eight layer labels" {
            let state = BM.defaultState ()
            let plain = stripAnsi (BM.renderMatrix state)
            let labels = [ "L0"; "L1"; "L2"; "L3"; "L4"; "L5"; "L6"; "L7" ]
            for lbl in labels do
                Expect.stringContains plain lbl
                    (sprintf "renderMatrix must contain layer label '%s'" lbl)
        }

        test "BM-MATRIX-006: renderMatrix plain text contains 'Constitution' (L0 name)" {
            let state = BM.defaultState ()
            let plain = stripAnsi (BM.renderMatrix state)
            Expect.stringContains plain "Constitution"
                "renderMatrix must display the L0_Constitution layer"
        }

        test "BM-MATRIX-007: renderMatrix plain text contains 'OVERALL SATURATION' footer" {
            let state = BM.defaultState ()
            let plain = stripAnsi (BM.renderMatrix state)
            Expect.stringContains plain "OVERALL SATURATION"
                "renderMatrix must display an OVERALL SATURATION footer row"
        }

        test "BM-MATRIX-008: renderMatrix uses box-drawing separator characters (═)" {
            let state = BM.defaultState ()
            let result = BM.renderMatrix state
            Expect.stringContains result "═"
                "renderMatrix must use double-line box-drawing separator (═)"
        }

        test "BM-MATRIX-009: renderMatrix respects custom Timestamp in output" {
            let ts    = DateTimeOffset(2026, 3, 30, 12, 0, 0, TimeSpan.Zero)
            let state = { BM.defaultState () with Timestamp = ts }
            let plain = stripAnsi (BM.renderMatrix state)
            Expect.stringContains plain "2026-03-30"
                "renderMatrix must include the state Timestamp date"
        }

        test "BM-MATRIX-010: renderMatrix line count equals 8 layers + header/footer rows" {
            let state = BM.defaultState ()
            let lines = (BM.renderMatrix state).Split('\n')
            // At minimum: empty, sep, hdr, sep, colhdr, div, 8 layer rows, div, sat, sep, empty
            Expect.isGreaterThan lines.Length 12
                "renderMatrix must produce at least 13 lines"
        }
    ]

// ---------------------------------------------------------------------------
// C5: renderCompact one-liner
// ---------------------------------------------------------------------------

[<Tests>]
let renderCompactTests =
    testList "BM-COMPACT: renderCompact" [

        test "BM-COMPACT-001: renderCompact returns a non-empty string" {
            let state = BM.defaultState ()
            let result = BM.renderCompact state
            Expect.isTrue (result.Length > 0) "renderCompact must return content"
        }

        test "BM-COMPACT-002: renderCompact plain text contains 'BIOMORPHIC' label" {
            let state = BM.defaultState ()
            let plain = stripAnsi (BM.renderCompact state)
            Expect.stringContains plain "BIOMORPHIC"
                "renderCompact must contain the 'BIOMORPHIC' label"
        }

        test "BM-COMPACT-003: renderCompact contains ANSI escape codes (SC-HMI-010)" {
            let state = BM.defaultState ()
            let result = BM.renderCompact state
            Expect.stringContains result "\u001b[" "renderCompact must emit ANSI colour codes"
        }

        test "BM-COMPACT-004: renderCompact plain text contains a saturation percentage" {
            let state = BM.defaultState ()
            let plain = stripAnsi (BM.renderCompact state)
            // OverallSaturation ~ 0.8 → "80.0%"
            Expect.stringContains plain "%" "renderCompact must show a saturation percentage"
        }

        test "BM-COMPACT-005: renderCompact plain text contains 'layers:' marker" {
            let state = BM.defaultState ()
            let plain = stripAnsi (BM.renderCompact state)
            Expect.stringContains plain "layers:" "renderCompact must contain the 'layers:' marker"
        }
    ]

// ---------------------------------------------------------------------------
// C6: health / ratio colour coding
// ---------------------------------------------------------------------------

[<Tests>]
let colourCodingTests =
    testList "BM-COLOUR: health colour coding" [

        test "BM-COLOUR-001: fully-saturated layer row contains bright-green ANSI code" {
            // 100 % saturation → bGreen (92m)
            let lh = mkLayer FractalLayer.L3_Network 350 350 245 245 3.50
            let row = BM.renderLayer lh
            Expect.stringContains row "\u001b[92m"
                "100% saturation must use bright-green (\u001b[92m)"
        }

        test "BM-COLOUR-002: critically-low saturation row contains bright-red ANSI code" {
            // 10 % saturation → bRed (91m)
            let lh = mkLayer FractalLayer.L6_Presentation 15 150 10 115 0.50
            let row = BM.renderLayer lh
            Expect.stringContains row "\u001b[91m"
                "Low saturation must use bright-red (\u001b[91m)"
        }

        test "BM-COLOUR-003: medium saturation (80%) row contains bright-yellow ANSI code" {
            // 80 % saturation → bYellow (93m) for the bar
            let lh = mkLayer FractalLayer.L4_Transport 200 250 148 170 2.55
            let row = BM.renderLayer lh
            Expect.stringContains row "\u001b[93m"
                "80% saturation must use bright-yellow (\u001b[93m)"
        }

        test "BM-COLOUR-004: L0_Constitution row uses bright-magenta label colour" {
            let lh = mkLayer FractalLayer.L0_Constitution 800 1000 292 320 3.10
            let row = BM.renderLayer lh
            // labelColour for L0_Constitution = BmAnsi.bMagenta = "\u001b[95m"
            Expect.stringContains row "\u001b[95m"
                "L0_Constitution label must use bright-magenta (\u001b[95m)"
        }

        test "BM-COLOUR-005: renderCompact uses bright-green for high overall saturation" {
            // Build a state with 95% overall saturation
            let layers =
                [ FractalLayer.L0_Constitution; FractalLayer.L1_Physical
                  FractalLayer.L2_DataLink;     FractalLayer.L3_Network
                  FractalLayer.L4_Transport;    FractalLayer.L5_Session
                  FractalLayer.L6_Presentation; FractalLayer.L7_Application ]
                |> List.map (fun l -> mkLayer l 95 100 90 100 3.0)
            let state = { Layers = layers; OverallSaturation = 0.95; Timestamp = DateTimeOffset.UtcNow }
            let result = BM.renderCompact state
            Expect.stringContains result "\u001b[92m"
                "95% overall saturation must use bright-green in compact output"
        }
    ]

// ---------------------------------------------------------------------------
// Aggregate
// ---------------------------------------------------------------------------

[<Tests>]
let allBiomorphicMatrixTests =
    testList "Biomorphic Matrix" [
        defaultStateTests
        layerLabelTests
        renderLayerTests
        renderMatrixTests
        renderCompactTests
        colourCodingTests
    ]
