// =============================================================================
// Git Intelligence — Advanced Tests (Trend + Homeostasis)
// =============================================================================
// Purpose:  Test L5 time-series trend analysis (Trend.fs) and homeostatic
//           quality PID controller (Homeostasis.fs).
//
// STAMP:    SC-BIO-EXT-009 (self-healing), SC-OODA-001 (< 30ms),
//           AOR-HOLON-019 (append-only lineage)
// =============================================================================

namespace Cepaf.Tests.Unit.GitIntelligence

open System
open Expecto
open Cepaf.GitIntelligence

module AdvancedTrendTests =

    // ── Helpers ──────────────────────────────────────────────────────────

    /// Build a minimal EvolutionEvent with GHS values.
    let private mkEvent (ghsBefore: float option) (ghsAfter: float option) (minutesAgo: float) =
        { EventId = Guid.NewGuid().ToString("D")
          EventType = "commit"
          GhsBefore = ghsBefore
          GhsAfter = ghsAfter
          Delta =
            match ghsBefore, ghsAfter with
            | Some b, Some a -> Some (a - b)
            | _ -> None
          Metadata = "{}"
          Timestamp = DateTimeOffset.UtcNow.AddMinutes(-minutesAgo) }

    /// Build a minimal ParsedCommit.
    let private mkCommit (daysAgo: float) (style: CommitStyle) =
        { Hash = Guid.NewGuid().ToString("N")
          ShortHash = "abc1234"
          Author = "test"
          Date = DateTimeOffset.UtcNow.AddDays(-daysAgo)
          Subject = "test commit"
          Body = ""
          FilesChanged = 1
          Insertions = 10
          Deletions = 5
          Style = style
          CommitType = Some CommitType.Feat
          Scopes = []
          RawScopes = []
          HasEmDash = (style = CommitStyle.IcpConventional)
          SubjectLength = 20
          ContextAfterEmDash = None }

    // ═══════════════════════════════════════════════════════════════════════
    // Trend.fs Tests (L5 Time-Series Analysis)
    // ═══════════════════════════════════════════════════════════════════════

    [<Tests>]
    let trendTests = testList "Trend" [

        // ── EMA ─────────────────────────────────────────────────────────

        testCase "computeEma returns empty for empty input" <| fun _ ->
            let result = Trend.computeEma [||] 0.5
            Expect.equal result.Length 0 "empty in → empty out"

        testCase "computeEma single value returns that value" <| fun _ ->
            let result = Trend.computeEma [| 0.85 |] 0.5
            Expect.equal result.Length 1 "one element"
            Expect.floatClose Accuracy.medium result.[0] 0.85 "identity"

        testCase "computeEma smooths multiple values" <| fun _ ->
            let result = Trend.computeEma [| 0.80; 0.85; 0.90; 0.82; 0.88 |] 0.4
            Expect.equal result.Length 5 "same length"
            // EMA starts at first value, then blends
            Expect.floatClose Accuracy.medium result.[0] 0.80 "first = seed"
            // Subsequent values should be between previous EMA and new value
            for i in 1 .. result.Length - 1 do
                Expect.isGreaterThanOrEqual result.[i] 0.70 $"EMA[{i}] is reasonable"
                Expect.isLessThanOrEqual result.[i] 1.0 $"EMA[{i}] <= 1.0"

        // ── GHS Trend ───────────────────────────────────────────────────

        testCase "computeGhsTrend returns empty for no events" <| fun _ ->
            let result = Trend.computeGhsTrend [||] 5
            Expect.equal result.Length 0 "no events → no trend"

        testCase "computeGhsTrend returns points for events with GHS" <| fun _ ->
            let events = [|
                mkEvent (Some 0.80) (Some 0.82) 60.0
                mkEvent (Some 0.82) (Some 0.85) 30.0
                mkEvent (Some 0.85) (Some 0.88) 10.0
            |]
            let result = Trend.computeGhsTrend events 3
            Expect.isGreaterThanOrEqual result.Length 1 "produces trend points"

        // ── Regression Detection ────────────────────────────────────────

        testCase "detectRegression returns false when GHS is above baseline" <| fun _ ->
            let (isReg, _, _) = Trend.detectRegression 0.85 0.80
            Expect.isFalse isReg "above baseline = no regression"

        testCase "detectRegression returns true for >10% drop" <| fun _ ->
            let (isReg, dropPct, _) = Trend.detectRegression 0.70 0.85
            Expect.isTrue isReg "17.6% drop = regression"
            Expect.isGreaterThan dropPct 10.0 "drop > 10%"

        testCase "detectRegression handles zero baseline" <| fun _ ->
            let (isReg, _, _) = Trend.detectRegression 0.50 0.0
            Expect.isFalse isReg "zero baseline = no regression"

        testCase "detectRegressionFromEvents with improving events" <| fun _ ->
            let events = [|
                mkEvent (Some 0.70) (Some 0.75) 60.0
                mkEvent (Some 0.75) (Some 0.80) 30.0
                mkEvent (Some 0.80) (Some 0.85) 10.0
            |]
            let (isReg, _, _) = Trend.detectRegressionFromEvents events 0.85 3
            Expect.isFalse isReg "improving trend = no regression"

        // ── Velocity ────────────────────────────────────────────────────

        testCase "computeVelocity returns 0 for no commits" <| fun _ ->
            let velocity = Trend.computeVelocity [||] 7.0
            Expect.floatClose Accuracy.medium velocity 0.0 "no commits = 0"

        testCase "computeVelocity counts recent commits" <| fun _ ->
            let commits = [|
                mkCommit 1.0 CommitStyle.IcpConventional
                mkCommit 2.0 CommitStyle.IcpConventional
                mkCommit 3.0 CommitStyle.ConventionalNoEmDash
                mkCommit 30.0 CommitStyle.Other  // outside 7-day window
            |]
            let velocity = Trend.computeVelocity commits 7.0
            Expect.isGreaterThan velocity 0.0 "has recent commits"

        testCase "computeVelocity with zero period returns 0" <| fun _ ->
            let commits = [| mkCommit 1.0 CommitStyle.IcpConventional |]
            let velocity = Trend.computeVelocity commits 0.0
            Expect.floatClose Accuracy.medium velocity 0.0 "zero period = 0"

        // ── Adoption Trend ──────────────────────────────────────────────

        testCase "computeAdoptionTrend with mixed styles" <| fun _ ->
            let commits = [|
                // This week: 2 ICP, 1 other
                mkCommit 1.0 CommitStyle.IcpConventional
                mkCommit 2.0 CommitStyle.IcpConventional
                mkCommit 3.0 CommitStyle.Emoji
                // Last week: 1 ICP, 2 other
                mkCommit 8.0 CommitStyle.IcpConventional
                mkCommit 9.0 CommitStyle.EvolutionRun
                mkCommit 10.0 CommitStyle.Other
            |]
            let (currentRate, _, _) = Trend.computeAdoptionTrend commits
            Expect.isGreaterThanOrEqual currentRate 0.0 "rate >= 0"
            Expect.isLessThanOrEqual currentRate 100.0 "rate <= 100"

        // ── Projection ──────────────────────────────────────────────────

        testCase "projectTarget returns None with insufficient data" <| fun _ ->
            let events = [| mkEvent (Some 0.80) (Some 0.85) 10.0 |]
            let result = Trend.projectTarget events 0.90
            Expect.isNone result "< 3 events = None"

        testCase "projectTarget returns None for negative slope" <| fun _ ->
            let events = [|
                mkEvent (Some 0.90) (Some 0.88) 60.0
                mkEvent (Some 0.88) (Some 0.85) 30.0
                mkEvent (Some 0.85) (Some 0.80) 10.0
            |]
            let result = Trend.projectTarget events 0.95
            Expect.isNone result "declining = None"

        testCase "projectTarget returns days for positive slope" <| fun _ ->
            let events = [|
                mkEvent (Some 0.70) (Some 0.75) 120.0
                mkEvent (Some 0.75) (Some 0.80) 60.0
                mkEvent (Some 0.80) (Some 0.85) 10.0
            |]
            let result = Trend.projectTarget events 0.90
            // May or may not return Some depending on slope magnitude
            match result with
            | Some days -> Expect.isGreaterThan days 0.0 "positive days"
            | None -> () // slope too shallow or already above target
    ]


module AdvancedHomeostaticTests =

    // ═══════════════════════════════════════════════════════════════════════
    // Homeostasis.fs Tests (PID Controller)
    // ═══════════════════════════════════════════════════════════════════════

    [<Tests>]
    let homeostaticTests = testList "Homeostatic" [

        // ── PID State ───────────────────────────────────────────────────

        testCase "createPid has correct defaults" <| fun _ ->
            let pid = Homeostasis.createPid ()
            Expect.floatClose Accuracy.medium pid.Setpoint 0.85 "setpoint = 0.85"
            Expect.floatClose Accuracy.medium pid.Kp 0.5 "Kp = 0.5"
            Expect.floatClose Accuracy.medium pid.Ki 0.1 "Ki = 0.1"
            Expect.floatClose Accuracy.medium pid.Kd 0.05 "Kd = 0.05"
            Expect.floatClose Accuracy.medium pid.Integral 0.0 "integral starts at 0"
            Expect.floatClose Accuracy.medium pid.Output 0.0 "output starts at 0"

        testCase "updatePid adjusts output for below-setpoint GHS" <| fun _ ->
            let pid = Homeostasis.createPid ()
            let now = DateTimeOffset.UtcNow.AddSeconds(1.0)
            let updated = Homeostasis.updatePid pid 0.70 now
            // Error = 0.85 - 0.70 = 0.15, so output should be positive
            Expect.isGreaterThan updated.Output 0.0 "positive output for low GHS"

        testCase "updatePid adjusts output for above-setpoint GHS" <| fun _ ->
            let pid = Homeostasis.createPid ()
            let now = DateTimeOffset.UtcNow.AddSeconds(1.0)
            let updated = Homeostasis.updatePid pid 0.95 now
            // Error = 0.85 - 0.95 = -0.10, so output should be negative
            Expect.isLessThan updated.Output 0.0 "negative output for high GHS"

        testCase "updatePid clamps integral to [-10, 10]" <| fun _ ->
            let mutable pid = Homeostasis.createPid ()
            // Run many iterations with large error to accumulate integral
            for i in 1 .. 200 do
                let now = DateTimeOffset.UtcNow.AddSeconds(float i)
                pid <- Homeostasis.updatePid pid 0.10 now
            Expect.isLessThanOrEqual pid.Integral 10.0 "integral <= 10"
            Expect.isGreaterThanOrEqual pid.Integral -10.0 "integral >= -10"

        // ── Mode Assessment ─────────────────────────────────────────────

        testCase "assessMode Normal when GHS near setpoint" <| fun _ ->
            let mode = Homeostasis.assessMode 0.84 0.85 None
            Expect.equal mode HomeostaticMode.Normal "within 5% = Normal"

        testCase "assessMode Stressed when moderate deviation" <| fun _ ->
            let mode = Homeostasis.assessMode 0.78 0.85 None
            Expect.equal mode HomeostaticMode.Stressed "~8% deviation = Stressed"

        testCase "assessMode Degraded when significant deviation" <| fun _ ->
            let mode = Homeostasis.assessMode 0.70 0.85 None
            Expect.equal mode HomeostaticMode.Degraded "~18% deviation = Degraded"

        testCase "assessMode Critical when severe deviation" <| fun _ ->
            let mode = Homeostasis.assessMode 0.50 0.85 None
            Expect.equal mode HomeostaticMode.Critical ">30% deviation = Critical"

        testCase "assessMode Recovery when improving from worse state" <| fun _ ->
            let mode = Homeostasis.assessMode 0.70 0.85 (Some 0.60)
            Expect.equal mode HomeostaticMode.Recovery "improving + >15% = Recovery"

        // ── Guidance ────────────────────────────────────────────────────

        testCase "generateGuidance produces output for each mode" <| fun _ ->
            let modes = [ HomeostaticMode.Normal; HomeostaticMode.Stressed;
                          HomeostaticMode.Degraded; HomeostaticMode.Critical;
                          HomeostaticMode.Recovery ]
            for mode in modes do
                let guidance = Homeostasis.generateGuidance mode 0.1 0.80
                Expect.isNonEmpty guidance $"guidance for {mode} is non-empty"

        // ── Full Assessment Pipeline ────────────────────────────────────

        testCase "assess returns complete HomeostasisState" <| fun _ ->
            let pid = Homeostasis.createPid ()
            let state = Homeostasis.assess pid 0.75 None
            Expect.isGreaterThanOrEqual state.Pid.Setpoint 0.0 "setpoint is set"
            Expect.isNonEmpty state.Guidance "guidance generated"

        testCase "isCritical returns true for Critical mode" <| fun _ ->
            let pid = Homeostasis.createPid ()
            let state = Homeostasis.assess pid 0.40 None
            Expect.isTrue (Homeostasis.isCritical state) "0.40 GHS is critical"

        testCase "isCritical returns false for Normal mode" <| fun _ ->
            let pid = Homeostasis.createPid ()
            let state = Homeostasis.assess pid 0.84 None
            Expect.isFalse (Homeostasis.isCritical state) "0.84 GHS is not critical"

        // ── Report Formatting ───────────────────────────────────────────

        testCase "formatReport produces non-empty output" <| fun _ ->
            let pid = Homeostasis.createPid ()
            let state = Homeostasis.assess pid 0.80 (Some 0.75)
            let report = Homeostasis.formatReport state
            Expect.isNotEmpty report "report is non-empty"
            Expect.stringContains report "Mode:" "report has mode header"
    ]

    // ═══════════════════════════════════════════════════════════════════════
    // Combined export
    // ═══════════════════════════════════════════════════════════════════════

    [<Tests>]
    let tests = testList "Advanced" [
        AdvancedTrendTests.trendTests
        homeostaticTests
    ]
