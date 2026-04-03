module Cepaf.Tests.Unit.Cockpit.EvolutionVectorViewTests

open System
open Expecto
open Cepaf.Cockpit

// Module alias for the public API under test
module EV = Cepaf.Cockpit.EvolutionVectorView

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Minimal valid EvolutionVector for unit tests.
let private mkVector id label value target rawCount rawTotal unit_ : EvolutionVector = {
    Id       = id
    Label    = label
    Value    = value
    Target   = target
    RawCount = rawCount
    RawTotal = rawTotal
    Unit     = unit_
}

/// Minimal valid EvolutionState for unit tests.
let private mkState vectors overallScore sprintId : EvolutionState = {
    Vectors      = vectors
    OverallScore = overallScore
    SprintId     = sprintId
    Timestamp    = DateTimeOffset.UtcNow
}

// ---------------------------------------------------------------------------
// defaultState
// ---------------------------------------------------------------------------

[<Tests>]
let defaultStateTests =
    testList "EV-DEFAULT: defaultState" [

        test "EV-DEFAULT-001: defaultState returns exactly 4 vectors (V1-V4)" {
            let state = EV.defaultState ()
            Expect.equal state.Vectors.Length 4
                "defaultState must return exactly 4 evolution vectors"
        }

        test "EV-DEFAULT-002: all default vectors have targets of 1.0" {
            let state = EV.defaultState ()
            let allTargetOne = state.Vectors |> List.forall (fun v -> v.Target = 1.0)
            Expect.isTrue allTargetOne
                "All default evolution vectors must target 1.0"
        }

        test "EV-DEFAULT-003: default OverallScore is within [0.0, 1.0]" {
            let state = EV.defaultState ()
            Expect.isTrue (state.OverallScore >= 0.0 && state.OverallScore <= 1.0)
                "OverallScore must be in [0.0, 1.0]"
        }

        test "EV-DEFAULT-004: default vectors carry IDs V1 through V4" {
            let state = EV.defaultState ()
            let ids = state.Vectors |> List.map (fun v -> v.Id) |> Set.ofList
            Expect.equal ids (Set.ofList ["V1"; "V2"; "V3"; "V4"])
                "defaultState must carry vector IDs V1, V2, V3, V4"
        }

        test "EV-DEFAULT-005: default SprintId is non-empty" {
            let state = EV.defaultState ()
            Expect.isTrue (state.SprintId.Length > 0)
                "SprintId must be a non-empty string"
        }

        test "EV-DEFAULT-006: default Timestamp is a recent DateTimeOffset" {
            let before = DateTimeOffset.UtcNow.AddSeconds(-5.0)
            let state  = EV.defaultState ()
            let after  = DateTimeOffset.UtcNow.AddSeconds(5.0)
            Expect.isTrue (state.Timestamp >= before && state.Timestamp <= after)
                "defaultState Timestamp must be close to the current time"
        }

    ]

// ---------------------------------------------------------------------------
// renderVector
// ---------------------------------------------------------------------------

[<Tests>]
let renderVectorTests =
    testList "EV-VECTOR: renderVector" [

        test "EV-VECTOR-001: renderVector returns non-empty string" {
            let v      = mkVector "V1" "Substrate Sat." 0.80 1.0 800 1000 "modules"
            let result = EV.renderVector v
            Expect.isTrue (result.Length > 0)
                "renderVector must return content"
        }

        test "EV-VECTOR-002: renderVector output contains the vector ID" {
            let v      = mkVector "V2" "Constraint Cov." 1.0 1.0 2297 2257 "SC-*"
            let result = EV.renderVector v
            Expect.stringContains result "V2"
                "renderVector output must contain the vector ID"
        }

        test "EV-VECTOR-003: renderVector output contains the vector label" {
            let v      = mkVector "V3" "Test Entropy" 0.85 1.0 85 100 "% balanced"
            let result = EV.renderVector v
            Expect.stringContains result "Test Entropy"
                "renderVector output must contain the vector label"
        }

        test "EV-VECTOR-004: renderVector output contains ANSI escape codes (SC-HMI-010)" {
            let v      = mkVector "V1" "Substrate Sat." 0.78 1.0 780 1000 "modules"
            let result = EV.renderVector v
            Expect.stringContains result "\u001b["
                "renderVector must contain ANSI colour codes (SC-HMI-010)"
        }

        test "EV-VECTOR-005: renderVector uses green for value at or above 95% of target" {
            // Value 0.98, Target 1.0 → ratio 0.98 ≥ 0.95 → bright green \u001b[92m
            let v      = mkVector "V2" "Constraint Cov." 0.98 1.0 980 1000 "units"
            let result = EV.renderVector v
            Expect.stringContains result "\u001b[92m"
                "renderVector must use bright green for ratio >= 0.95"
        }

        test "EV-VECTOR-006: renderVector uses red for value below 70% of target" {
            // Value 0.50, Target 1.0 → ratio 0.50 < 0.70 → red \u001b[91m
            let v      = mkVector "V4" "Morph Velocity" 0.50 1.0 5 10 "commits/day"
            let result = EV.renderVector v
            Expect.stringContains result "\u001b[91m"
                "renderVector must use red for ratio < 0.70"
        }

        test "EV-VECTOR-007: renderVector uses yellow for value between 70% and 95% of target" {
            // Value 0.80, Target 1.0 → ratio 0.80 in [0.70, 0.95) → yellow \u001b[93m
            let v      = mkVector "V1" "Substrate Sat." 0.80 1.0 800 1000 "modules"
            let result = EV.renderVector v
            Expect.stringContains result "\u001b[93m"
                "renderVector must use yellow for ratio in [0.70, 0.95)"
        }

        test "EV-VECTOR-008: renderVector contains raw count and total" {
            let v      = mkVector "V1" "Substrate Sat." 0.80 1.0 800 1000 "modules"
            let result = EV.renderVector v
            Expect.stringContains result "800"
                "renderVector must contain raw count"
            Expect.stringContains result "1000"
                "renderVector must contain raw total"
        }

    ]

// ---------------------------------------------------------------------------
// renderPane
// ---------------------------------------------------------------------------

[<Tests>]
let renderPaneTests =
    testList "EV-PANE: renderPane" [

        test "EV-PANE-001: renderPane returns non-empty string" {
            let state  = EV.defaultState ()
            let result = EV.renderPane state
            Expect.isTrue (result.Length > 0)
                "renderPane must return content"
        }

        test "EV-PANE-002: renderPane contains ANSI escape codes (SC-HMI-010)" {
            let state  = EV.defaultState ()
            let result = EV.renderPane state
            Expect.stringContains result "\u001b["
                "renderPane must contain ANSI colour codes (SC-HMI-010)"
        }

        test "EV-PANE-003: renderPane contains all four vector IDs" {
            let state  = EV.defaultState ()
            let result = EV.renderPane state
            Expect.stringContains result "V1" "V1 must appear in renderPane output"
            Expect.stringContains result "V2" "V2 must appear in renderPane output"
            Expect.stringContains result "V3" "V3 must appear in renderPane output"
            Expect.stringContains result "V4" "V4 must appear in renderPane output"
        }

        test "EV-PANE-004: renderPane contains the SprintId" {
            let state  = { EV.defaultState () with SprintId = "S99" }
            let result = EV.renderPane state
            Expect.stringContains result "S99"
                "renderPane must include the SprintId"
        }

        test "EV-PANE-005: renderPane contains 'EVOLUTION VECTORS' header text" {
            let state  = EV.defaultState ()
            let result = EV.renderPane state
            Expect.stringContains result "EVOLUTION VECTORS"
                "renderPane must include the EVOLUTION VECTORS header"
        }

        test "EV-PANE-006: renderPane contains overall score percentage" {
            // OverallScore 0.83 → "83.0%"
            let state  = { EV.defaultState () with OverallScore = 0.83 }
            let result = EV.renderPane state
            Expect.stringContains result "83.0%"
                "renderPane must display the overall score as a percentage"
        }

        test "EV-PANE-007: renderPane output is multi-line" {
            let state  = EV.defaultState ()
            let result = EV.renderPane state
            Expect.isTrue (result.Contains("\n"))
                "renderPane output must span multiple lines"
        }

    ]

// ---------------------------------------------------------------------------
// renderCompact
// ---------------------------------------------------------------------------

[<Tests>]
let renderCompactTests =
    testList "EV-COMPACT: renderCompact" [

        test "EV-COMPACT-001: renderCompact returns non-empty string" {
            let state  = EV.defaultState ()
            let result = EV.renderCompact state
            Expect.isTrue (result.Length > 5)
                "renderCompact must return meaningful content"
        }

        test "EV-COMPACT-002: renderCompact does not contain newlines (single line)" {
            let state  = EV.defaultState ()
            let result = EV.renderCompact state
            Expect.isFalse (result.Contains("\n"))
                "renderCompact must be a single line (no newlines)"
        }

        test "EV-COMPACT-003: renderCompact contains all four vector IDs" {
            let state  = EV.defaultState ()
            let result = EV.renderCompact state
            Expect.stringContains result "V1" "V1 must appear in compact output"
            Expect.stringContains result "V2" "V2 must appear in compact output"
            Expect.stringContains result "V3" "V3 must appear in compact output"
            Expect.stringContains result "V4" "V4 must appear in compact output"
        }

        test "EV-COMPACT-004: renderCompact contains 'Evo=' overall score label" {
            let state  = EV.defaultState ()
            let result = EV.renderCompact state
            Expect.stringContains result "Evo="
                "renderCompact must contain Evo= overall score label"
        }

        test "EV-COMPACT-005: renderCompact overall score matches OverallScore field" {
            // OverallScore 1.0 → "Evo=100%"
            let state  = { EV.defaultState () with OverallScore = 1.0 }
            let result = EV.renderCompact state
            Expect.stringContains result "100%"
                "renderCompact must show 100% when OverallScore is 1.0"
        }

    ]

// ---------------------------------------------------------------------------
// Aggregate
// ---------------------------------------------------------------------------

[<Tests>]
let allEvolutionVectorViewTests =
    testList "Evolution Vector View" [
        defaultStateTests
        renderVectorTests
        renderPaneTests
        renderCompactTests
    ]
