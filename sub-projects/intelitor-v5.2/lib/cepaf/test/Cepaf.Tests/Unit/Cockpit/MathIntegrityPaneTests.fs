module Cepaf.Tests.Unit.Cockpit.MathIntegrityPaneTests

// =============================================================================
// MathIntegrityPaneTests.fs — Unit tests for Cepaf.Cockpit.MathIntegrityPane
// =============================================================================
// STAMP: SC-MATH-001 (Discipline health monitored), SC-HMI-010 (Color Rich)
// AOR:   AOR-MATH-001 (Monitor mathematical discipline health continuously)
//
// Tests cover:
//   - defaultState construction (MI-STATE-*)
//   - renderPane string content (MI-PANE-*)
//   - renderCompact one-liner format (MI-COMPACT-*)
//   - Colour-coding thresholds for entropy, epsilon, coverage, RPN (MI-COLOUR-*)
//   - Top-5 RPN discipline selection and ordering (MI-TOP5-*)
//   - Maturity summary and discipline row formatting (MI-MAT-*)
// =============================================================================

open System
open Expecto
open Cepaf.Cockpit

module MI = Cepaf.Cockpit.MathIntegrityPane

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

/// Minimal discipline — healthy values.
let private d (name: string) (score: float) (maturity: string) (rpn: int) : DisciplineScore =
    { Name = name; Score = score; Maturity = maturity; Rpn = rpn }

/// A realistic healthy state: 17 disciplines, 17 at Production, Hs=2.8, ε=0.0071.
let private healthyState : MathIntegrityState =
    { ShannonEntropy    = 2.800
      EpsilonDivergence = 0.0071
      DisciplineCount   = 17
      ProductionCount   = 17
      Disciplines       =
          [ d "Shannon Entropy"   0.95 "Production"    10
            d "Reed-Solomon"      0.92 "Production"    20
            d "Cryptography"      0.90 "Production"    15
            d "Category Theory"   0.88 "Production"    30
            d "Graph Theory"      0.87 "Production"    25
            d "Petri Nets"        0.85 "Production"    50
            d "Active Inference"  0.84 "Production"    45
            d "Homeostasis"       0.83 "Production"    35
            d "Swarm"             0.82 "Production"    40
            d "VSM S1"            0.80 "Production"    22
            d "VSM S2"            0.79 "Production"    18
            d "VSM S3"            0.78 "Production"    28
            d "VSM S3*"           0.77 "Production"    32
            d "VSM S4"            0.76 "Production"    12
            d "VSM S5"            0.75 "Production"    16
            d "Consensus"         0.74 "Production"    38
            d "Set Theory"        0.73 "Production"    24 ]
      Timestamp         = DateTimeOffset(2026, 3, 28, 12, 0, 0, TimeSpan.Zero) }

/// Degraded state: low Hs, high ε, partial Production coverage.
let private degradedState : MathIntegrityState =
    { ShannonEntropy    = 1.5
      EpsilonDivergence = 0.08
      DisciplineCount   = 10
      ProductionCount   = 6
      Disciplines       =
          [ d "DisciplineA" 0.60 "Production"    120
            d "DisciplineB" 0.55 "Stabilisation" 200
            d "DisciplineC" 0.50 "Prototype"     300
            d "DisciplineD" 0.45 "Isolated"      150
            d "DisciplineE" 0.40 "Production"     80
            d "DisciplineF" 0.35 "Production"     90
            d "DisciplineG" 0.30 "Production"     60
            d "DisciplineH" 0.25 "Production"     55
            d "DisciplineI" 0.20 "Stabilisation" 110
            d "DisciplineJ" 0.15 "Prototype"     170 ]
      Timestamp         = DateTimeOffset(2026, 3, 28, 9, 0, 0, TimeSpan.Zero) }

/// State with exactly 5 disciplines — tests exact boundary of top-5 logic.
let private fiveDiscState : MathIntegrityState =
    { ShannonEntropy    = 2.6
      EpsilonDivergence = 0.005
      DisciplineCount   = 5
      ProductionCount   = 5
      Disciplines       =
          [ d "Alpha" 0.9 "Production" 10
            d "Beta"  0.8 "Production" 50
            d "Gamma" 0.7 "Production" 30
            d "Delta" 0.6 "Production" 70
            d "Eps"   0.5 "Production" 20 ]
      Timestamp         = DateTimeOffset(2026, 3, 28, 8, 0, 0, TimeSpan.Zero) }

/// Empty disciplines list — edge case.
let private emptyDiscState : MathIntegrityState =
    { ShannonEntropy    = 0.0
      EpsilonDivergence = 0.99
      DisciplineCount   = 0
      ProductionCount   = 0
      Disciplines       = []
      Timestamp         = DateTimeOffset(2026, 3, 28, 6, 0, 0, TimeSpan.Zero) }

// Strip ANSI codes so we can assert on plain text content.
let private stripAnsi (s: string) : string =
    System.Text.RegularExpressions.Regex.Replace(s, @"\u001b\[[0-9;]*m", "")

// ---------------------------------------------------------------------------
// MI-STATE: Default / fixture construction
// ---------------------------------------------------------------------------

[<Tests>]
let stateTests =
    testList "MI-STATE: MathIntegrityState construction" [

        test "MI-STATE-001: DisciplineScore fields are accessible" {
            let ds = d "Shannon Entropy" 0.95 "Production" 10
            Expect.equal ds.Name "Shannon Entropy" "Name must round-trip"
            Expect.equal ds.Score 0.95 "Score must round-trip"
            Expect.equal ds.Maturity "Production" "Maturity must round-trip"
            Expect.equal ds.Rpn 10 "Rpn must round-trip"
        }

        test "MI-STATE-002: MathIntegrityState fields are accessible" {
            Expect.equal healthyState.ShannonEntropy 2.800 "ShannonEntropy must round-trip"
            Expect.equal healthyState.EpsilonDivergence 0.0071 "EpsilonDivergence must round-trip"
            Expect.equal healthyState.DisciplineCount 17 "DisciplineCount must round-trip"
            Expect.equal healthyState.ProductionCount 17 "ProductionCount must round-trip"
            Expect.equal (List.length healthyState.Disciplines) 17 "Disciplines list must have 17 items"
        }

        test "MI-STATE-003: Timestamp is preserved" {
            let expected = DateTimeOffset(2026, 3, 28, 12, 0, 0, TimeSpan.Zero)
            Expect.equal healthyState.Timestamp expected "Timestamp must round-trip"
        }
    ]

// ---------------------------------------------------------------------------
// MI-PANE: renderPane — structural checks
// ---------------------------------------------------------------------------

[<Tests>]
let renderPaneStructureTests =
    testList "MI-PANE: renderPane structure" [

        test "MI-PANE-001: renderPane returns non-empty string" {
            let result = MI.renderPane healthyState
            Expect.isTrue (result.Length > 0) "renderPane must return content"
        }

        test "MI-PANE-002: renderPane contains ANSI escape codes (SC-HMI-010)" {
            let result = MI.renderPane healthyState
            Expect.stringContains result "\u001b[" "renderPane must emit ANSI colour codes"
        }

        test "MI-PANE-003: renderPane output is multi-line" {
            let result = MI.renderPane healthyState
            Expect.isTrue (result.Contains("\n")) "renderPane must produce multiple lines"
        }

        test "MI-PANE-004: renderPane contains MATHEMATICAL INTEGRITY header" {
            let plain = stripAnsi (MI.renderPane healthyState)
            Expect.stringContains plain "MATHEMATICAL INTEGRITY"
                "renderPane must show the MATHEMATICAL INTEGRITY header"
        }

        test "MI-PANE-005: renderPane contains separator lines" {
            let plain = stripAnsi (MI.renderPane healthyState)
            Expect.stringContains plain "─" "renderPane must include separator lines"
        }

        test "MI-PANE-006: renderPane contains timestamp string" {
            // Timestamp was set to 2026-03-28 12:00:00
            let plain = stripAnsi (MI.renderPane healthyState)
            Expect.stringContains plain "2026-03-28" "renderPane must show the snapshot date"
        }
    ]

// ---------------------------------------------------------------------------
// MI-PANE: renderPane — Hs / ε / Ds metric rows
// ---------------------------------------------------------------------------

[<Tests>]
let renderPaneMetricTests =
    testList "MI-PANE: renderPane metric rows" [

        test "MI-PANE-007: renderPane shows Hs (entropy) label" {
            let plain = stripAnsi (MI.renderPane healthyState)
            Expect.stringContains plain "Hs" "renderPane must show Hs label"
        }

        test "MI-PANE-008: renderPane shows entropy value 2.800" {
            let plain = stripAnsi (MI.renderPane healthyState)
            Expect.stringContains plain "2.800" "renderPane must show ShannonEntropy value"
        }

        test "MI-PANE-009: renderPane shows epsilon (ε) label" {
            let plain = stripAnsi (MI.renderPane healthyState)
            Expect.isTrue (plain.Contains("ε") || plain.Contains("epsilon") || plain.Contains("divergence"))
                "renderPane must show the epsilon/divergence label"
        }

        test "MI-PANE-010: renderPane shows epsilon value 0.0071" {
            let plain = stripAnsi (MI.renderPane healthyState)
            Expect.stringContains plain "0.0071" "renderPane must show EpsilonDivergence value"
        }

        test "MI-PANE-011: renderPane shows Ds (coverage) label" {
            let plain = stripAnsi (MI.renderPane healthyState)
            Expect.isTrue (plain.Contains("Ds") || plain.Contains("coverage"))
                "renderPane must show the Ds/coverage label"
        }

        test "MI-PANE-012: renderPane shows production/total counts 17/17" {
            let plain = stripAnsi (MI.renderPane healthyState)
            Expect.stringContains plain "17" "renderPane must show discipline counts"
        }

        test "MI-PANE-013: renderPane shows entropy target annotation" {
            let plain = stripAnsi (MI.renderPane healthyState)
            Expect.stringContains plain "target" "renderPane must show target annotation"
        }
    ]

// ---------------------------------------------------------------------------
// MI-TOP5: top-5 RPN disciplines
// ---------------------------------------------------------------------------

[<Tests>]
let renderPaneTop5Tests =
    testList "MI-TOP5: top-5 RPN selection" [

        test "MI-TOP5-001: renderPane shows Top disciplines section header" {
            let plain = stripAnsi (MI.renderPane healthyState)
            Expect.stringContains plain "Top disciplines" "renderPane must label the top disciplines section"
        }

        test "MI-TOP5-002: renderPane shows highest-RPN discipline name from healthy state" {
            // "Petri Nets" has the highest RPN (50) in healthyState
            let plain = stripAnsi (MI.renderPane healthyState)
            Expect.stringContains plain "Petri Nets" "renderPane must list the highest-RPN discipline"
        }

        test "MI-TOP5-003: renderPane shows RPN values" {
            let plain = stripAnsi (MI.renderPane healthyState)
            Expect.stringContains plain "RPN:" "renderPane must show RPN labels in discipline rows"
        }

        test "MI-TOP5-004: top-5 is sorted descending by RPN in degraded state" {
            let plain = stripAnsi (MI.renderPane degradedState)
            // DisciplineC has RPN=300 (highest), DisciplineB has 200 (second)
            let posC = plain.IndexOf("DisciplineC")
            let posB = plain.IndexOf("DisciplineB")
            Expect.isTrue (posC >= 0) "DisciplineC (RPN 300) must appear in top-5"
            Expect.isTrue (posB >= 0) "DisciplineB (RPN 200) must appear in top-5"
            Expect.isTrue (posC < posB) "Higher-RPN discipline must appear before lower-RPN discipline"
        }

        test "MI-TOP5-005: renderPane with exactly 5 disciplines shows all 5 names" {
            let plain = stripAnsi (MI.renderPane fiveDiscState)
            for name in ["Alpha"; "Beta"; "Gamma"; "Delta"; "Eps"] do
                Expect.stringContains plain name (sprintf "renderPane must list discipline %s" name)
        }

        test "MI-TOP5-006: renderPane with empty disciplines list does not crash" {
            let result = MI.renderPane emptyDiscState
            Expect.isTrue (result.Length > 0) "renderPane must not crash on empty disciplines"
        }

        test "MI-TOP5-007: renderPane truncates to at most 5 top disciplines" {
            // degradedState has 10 disciplines; only top 5 by RPN should appear in the top section.
            // The pane also has a section header "Top disciplines by RPN:" — that line contains
            // "by RPN:" but individual discipline rows contain "  RPN:NNN".
            // We count discipline rows by looking for the "  RPN:" pattern (two leading spaces).
            let plain = stripAnsi (MI.renderPane degradedState)
            let rowCount =
                let mutable idx = 0
                let mutable count = 0
                while idx >= 0 do
                    idx <- plain.IndexOf("  RPN:", idx)
                    if idx >= 0 then
                        count <- count + 1
                        idx <- idx + 6
                count
            Expect.isTrue (rowCount <= 5) (sprintf "renderPane must show at most 5 discipline rows, found %d" rowCount)
        }
    ]

// ---------------------------------------------------------------------------
// MI-MAT: Maturity summary and discipline maturity labels
// ---------------------------------------------------------------------------

[<Tests>]
let maturityTests =
    testList "MI-MAT: Maturity summary" [

        test "MI-MAT-001: renderPane shows Maturity section" {
            let plain = stripAnsi (MI.renderPane healthyState)
            Expect.stringContains plain "Maturity" "renderPane must include Maturity section"
        }

        test "MI-MAT-002: renderPane shows Production label for healthy disciplines" {
            let plain = stripAnsi (MI.renderPane healthyState)
            Expect.stringContains plain "Production" "renderPane must show Production maturity label"
        }

        test "MI-MAT-003: renderPane shows Stabilisation label from degraded state" {
            let plain = stripAnsi (MI.renderPane degradedState)
            Expect.stringContains plain "Stabilisation" "renderPane must show Stabilisation maturity"
        }

        test "MI-MAT-004: renderPane shows Prototype label from degraded state" {
            let plain = stripAnsi (MI.renderPane degradedState)
            Expect.stringContains plain "Prototype" "renderPane must show Prototype maturity"
        }

        test "MI-MAT-005: maturity summary counts match ProductionCount" {
            // The matRow shows "Production: N / Total"
            let plain = stripAnsi (MI.renderPane healthyState)
            // Both the Ds row and matRow should show 17/17
            let firstIdx = plain.IndexOf("17 / 17")
            Expect.isTrue (firstIdx >= 0) "renderPane must show 17/17 in maturity/coverage context"
        }
    ]

// ---------------------------------------------------------------------------
// MI-COLOUR: Colour coding thresholds
// ---------------------------------------------------------------------------

[<Tests>]
let colourThresholdTests =
    testList "MI-COLOUR: Colour coding thresholds" [

        test "MI-COLOUR-001: healthy state (Hs>=2.5) produces bright-green ANSI code" {
            // bGreen = \u001b[92m
            let result = MI.renderPane healthyState
            Expect.stringContains result "\u001b[92m" "Hs >= 2.5 must use bright-green colour"
        }

        test "MI-COLOUR-002: degraded state (Hs=1.5) produces bright-red ANSI code" {
            // bRed = \u001b[91m
            let result = MI.renderPane degradedState
            Expect.stringContains result "\u001b[91m" "Hs < 2.0 must use bright-red colour"
        }

        test "MI-COLOUR-003: healthy epsilon (eps<0.01) produces bright-green ANSI code" {
            let result = MI.renderPane healthyState
            Expect.stringContains result "\u001b[92m" "eps < 0.01 must use bright-green colour"
        }

        test "MI-COLOUR-004: high epsilon (eps=0.08) produces bright-red ANSI code" {
            let result = MI.renderPane degradedState
            Expect.stringContains result "\u001b[91m" "eps >= 0.05 must use bright-red colour"
        }

        test "MI-COLOUR-005: full Production coverage (17/17) produces bright-green" {
            let result = MI.renderPane healthyState
            Expect.stringContains result "\u001b[92m" "100% Production coverage must be bright-green"
        }

        test "MI-COLOUR-006: render output always contains reset escape code" {
            let result = MI.renderPane healthyState
            Expect.stringContains result "\u001b[0m" "renderPane must emit ANSI reset codes"
        }

        test "MI-COLOUR-007: RPN < 50 produces bright-green in healthy state" {
            // All healthy disciplines have RPN < 50; the top-5 rows must include bright-green
            let result = MI.renderPane healthyState
            Expect.stringContains result "\u001b[92m" "RPN < 50 disciplines must use bright-green"
        }

        test "MI-COLOUR-008: degraded state with RPN >= 100 produces bright-red or bright-yellow" {
            // DisciplineC has RPN=300 — should produce bRed
            let result = MI.renderPane degradedState
            Expect.isTrue
                (result.Contains("\u001b[91m") || result.Contains("\u001b[93m"))
                "RPN >= 100 must use bright-red or bright-yellow colour"
        }
    ]

// ---------------------------------------------------------------------------
// MI-COMPACT: renderCompact one-liner
// ---------------------------------------------------------------------------

[<Tests>]
let renderCompactTests =
    testList "MI-COMPACT: renderCompact" [

        test "MI-COMPACT-001: renderCompact returns non-empty string" {
            let result = MI.renderCompact healthyState
            Expect.isTrue (result.Length > 0) "renderCompact must return content"
        }

        test "MI-COMPACT-002: renderCompact contains Hs= prefix" {
            let plain = stripAnsi (MI.renderCompact healthyState)
            Expect.stringContains plain "Hs=" "Compact must include Hs= prefix"
        }

        test "MI-COMPACT-003: renderCompact contains epsilon (ε=) prefix" {
            let plain = stripAnsi (MI.renderCompact healthyState)
            Expect.stringContains plain "ε=" "Compact must include ε= prefix"
        }

        test "MI-COMPACT-004: renderCompact contains Ds= prefix" {
            let plain = stripAnsi (MI.renderCompact healthyState)
            Expect.stringContains plain "Ds=" "Compact must include Ds= prefix"
        }

        test "MI-COMPACT-005: renderCompact contains RPN_max= prefix" {
            let plain = stripAnsi (MI.renderCompact healthyState)
            Expect.stringContains plain "RPN_max=" "Compact must include RPN_max= prefix"
        }

        test "MI-COMPACT-006: renderCompact encodes Hs value 2.800" {
            let plain = stripAnsi (MI.renderCompact healthyState)
            Expect.stringContains plain "2.800" "Compact must show ShannonEntropy as 2.800"
        }

        test "MI-COMPACT-007: renderCompact encodes epsilon value 0.0071" {
            let plain = stripAnsi (MI.renderCompact healthyState)
            Expect.stringContains plain "0.0071" "Compact must show EpsilonDivergence as 0.0071"
        }

        test "MI-COMPACT-008: renderCompact encodes Ds counts 17/17" {
            let plain = stripAnsi (MI.renderCompact healthyState)
            Expect.stringContains plain "17/17" "Compact must show ProductionCount/DisciplineCount"
        }

        test "MI-COMPACT-009: renderCompact shows correct RPN_max for healthy state" {
            // Max RPN in healthyState is 50 (Petri Nets)
            let plain = stripAnsi (MI.renderCompact healthyState)
            Expect.stringContains plain "RPN_max=50" "Compact must show RPN_max=50 for healthy state"
        }

        test "MI-COMPACT-010: renderCompact shows correct RPN_max for degraded state" {
            // Max RPN in degradedState is 300 (DisciplineC)
            let plain = stripAnsi (MI.renderCompact degradedState)
            Expect.stringContains plain "RPN_max=300" "Compact must show RPN_max=300 for degraded state"
        }

        test "MI-COMPACT-011: renderCompact contains ANSI codes (SC-HMI-010)" {
            let result = MI.renderCompact healthyState
            Expect.stringContains result "\u001b[" "Compact must emit ANSI colour codes"
        }

        test "MI-COMPACT-012: renderCompact does not crash on empty disciplines" {
            let result = MI.renderCompact emptyDiscState
            Expect.isTrue (result.Length > 0) "renderCompact must handle empty discipline list"
        }

        test "MI-COMPACT-013: renderCompact shows 0/0 coverage for empty state" {
            let plain = stripAnsi (MI.renderCompact emptyDiscState)
            Expect.stringContains plain "0/0" "Compact must show 0/0 for empty discipline state"
        }

        test "MI-COMPACT-014: renderCompact shows 100% coverage for fully healthy state" {
            let plain = stripAnsi (MI.renderCompact healthyState)
            Expect.stringContains plain "100%" "Compact must show 100% for full Production coverage"
        }
    ]

// ---------------------------------------------------------------------------
// Aggregate
// ---------------------------------------------------------------------------

[<Tests>]
let allMathIntegrityPaneTests =
    testList "Math Integrity Pane" [
        stateTests
        renderPaneStructureTests
        renderPaneMetricTests
        renderPaneTop5Tests
        maturityTests
        colourThresholdTests
        renderCompactTests
    ]
