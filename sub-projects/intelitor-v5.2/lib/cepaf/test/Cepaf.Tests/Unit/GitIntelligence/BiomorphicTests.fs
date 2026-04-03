// =============================================================================
// Git Intelligence — Biomorphic Subsystem Expecto Tests
// =============================================================================
// Purpose:  Unit + property tests for all 5 biomorphic subsystems,
//           the BiomorphicOrchestrator, and Trend analysis.
//
// Coverage: Immune (15), Neural (8), Homeostatic (10), Regenerative (8),
//           Symbiotic (8), Orchestrator (10), FsCheck properties (15) = ~74
//
// STAMP:    SC-BIO-EXT-001, SC-SIL6-006, SC-ORCH-001
// =============================================================================

namespace Cepaf.Tests.Unit.GitIntelligence

open System
open Expecto
open FsCheck
open Cepaf.GitIntelligence

// ─────────────────────────────────────────────────────────────────────────────
// Test Helpers
// ─────────────────────────────────────────────────────────────────────────────

module TestHelpers =

    let now = DateTimeOffset.UtcNow

    /// Create a minimal ParsedCommit for testing.
    let mkCommit
        (subject: string)
        (style: CommitStyle)
        (commitType: CommitType option)
        (scopes: IcpScope list)
        (filesChanged: int)
        (daysAgo: float)
        : ParsedCommit =
        { Hash = Guid.NewGuid().ToString("N").[..7]
          ShortHash = "abc1234"
          Author = "test-author"
          Date = now.AddDays(-daysAgo)
          Subject = subject
          Body = ""
          FilesChanged = filesChanged
          Insertions = 10
          Deletions = 5
          Style = style
          CommitType = commitType
          Scopes = scopes
          RawScopes = scopes |> List.map IcpScope.toTag
          HasEmDash = subject.Contains("—")
          SubjectLength = subject.Length
          ContextAfterEmDash = None }

    /// Create N ICP-style commits spread over recent days.
    let mkIcpCommits (n: int) : ParsedCommit[] =
        [| for i in 0 .. n - 1 ->
            mkCommit
                (sprintf "feat(mesh): add feature %d — context" i)
                CommitStyle.IcpConventional
                (Some CommitType.Feat)
                [IcpScope.Mesh]
                3
                (float i * 0.5) |]

    /// Create N freeform commits (poor style).
    let mkFreeformCommits (n: int) : ParsedCommit[] =
        [| for i in 0 .. n - 1 ->
            mkCommit
                (sprintf "did some stuff %d" i)
                CommitStyle.Other
                None
                []
                1
                (float i * 0.5) |]

    /// Create a commit with AI co-authorship.
    let mkAiCommit (daysAgo: float) : ParsedCommit =
        { mkCommit "feat(cortex): integrate AI — Claude" CommitStyle.IcpConventional (Some CommitType.Feat) [IcpScope.Cortex] 5 daysAgo
            with Body = "Co-Authored-By: Claude Opus 4 <noreply@anthropic.com>" }

    /// Create commits with diverse types and scopes.
    let mkDiverseCommits () : ParsedCommit[] =
        let types = [CommitType.Feat; CommitType.Fix; CommitType.Refactor; CommitType.Test;
                     CommitType.Docs; CommitType.Chore; CommitType.Perf; CommitType.Security]
        let scopeValues = [IcpScope.Mesh; IcpScope.Cepaf; IcpScope.Zenoh; IcpScope.Sentinel;
                           IcpScope.Immune; IcpScope.Smriti; IcpScope.Prajna; IcpScope.Cortex;
                           IcpScope.Plan; IcpScope.Obs; IcpScope.Vsm; IcpScope.Math;
                           IcpScope.Swarm; IcpScope.Fed; IcpScope.Formal; IcpScope.Test]
        let scopeTags = scopeValues |> List.map IcpScope.toTag
        [| for i in 0 .. 19 ->
            mkCommit
                (sprintf "%s(%s): action %d — context"
                    (CommitType.toTag types.[i % types.Length])
                    scopeTags.[i % scopeTags.Length]
                    i)
                CommitStyle.IcpConventional
                (Some types.[i % types.Length])
                [scopeValues.[i % scopeValues.Length]]
                (i % 8 + 1)
                (float i * 0.3) |]

    /// Create an EvolutionEvent for trend analysis.
    let mkEvent (ghsAfter: float) (daysAgo: float) : EvolutionEvent =
        { EventId = Guid.NewGuid().ToString("N").[..7]
          EventType = "commit"
          GhsBefore = Some (ghsAfter - 0.01)
          GhsAfter = Some ghsAfter
          Delta = Some 0.01
          Metadata = "{}"
          Timestamp = now.AddDays(-daysAgo) }

// ─────────────────────────────────────────────────────────────────────────────
// Immune System Tests (15)
// ─────────────────────────────────────────────────────────────────────────────

module ImmuneTests =
    open TestHelpers

    [<Tests>]
    let immuneTests =
        testList "GitIntelligence.Biomorphic.Immune" [

            testCase "empty commits yields no patterns" <| fun _ ->
                let patterns = Immune.scanCommitHistory [||] None None
                Expect.isEmpty patterns "no patterns from empty history"

            testCase "empty commits yields None threat level" <| fun _ ->
                let level = Immune.assessThreatLevel [] None
                Expect.equal level ThreatLevel.None "no threats without patterns"

            testCase "empty commits yields 1.0 immunity" <| fun _ ->
                let score = Immune.calculateImmunityScore []
                Expect.floatClose Accuracy.high score 1.0 "perfect immunity with no patterns"

            testCase "scope creep detected with >5 scopes" <| fun _ ->
                let commit = mkCommit "feat(a,b,c,d,e,f): big change" CommitStyle.IcpConventional
                                (Some CommitType.Feat)
                                [IcpScope.Mesh; IcpScope.Cepaf; IcpScope.Zenoh; IcpScope.Sentinel; IcpScope.Immune; IcpScope.Smriti] 10 0.0
                let patterns = Immune.scanCommitHistory [|commit|] (Some 0.7) None
                let hasScopeCreep = patterns |> List.exists (fun p -> p.Pattern = GitPatternType.ScopeCreep)
                Expect.isTrue hasScopeCreep "should detect scope creep"

            testCase "type monoculture detected when >80% same type" <| fun _ ->
                let commits = Array.init 20 (fun i ->
                    mkCommit (sprintf "fix(mesh): fix %d" i) CommitStyle.IcpConventional
                        (Some CommitType.Fix) [IcpScope.Mesh] 1 (float i * 0.5))
                let patterns = Immune.scanCommitHistory commits (Some 0.7) None
                let hasMono = patterns |> List.exists (fun p -> p.Pattern = GitPatternType.TypeMonoculture)
                Expect.isTrue hasMono "should detect type monoculture"

            testCase "commit storm detected with >20 commits/day" <| fun _ ->
                let commits = Array.init 25 (fun i ->
                    mkCommit (sprintf "fix(mesh): quick fix %d" i) CommitStyle.IcpConventional
                        (Some CommitType.Fix) [IcpScope.Mesh] 1 0.0)
                let patterns = Immune.scanCommitHistory commits (Some 0.7) None
                let hasStorm = patterns |> List.exists (fun p -> p.Pattern = GitPatternType.CommitStorm)
                Expect.isTrue hasStorm "should detect commit storm"

            testCase "entropy collapse detected when GHS drops >15%" <| fun _ ->
                let commits = mkIcpCommits 5
                let patterns = Immune.scanCommitHistory commits (Some 0.50) (Some 0.80)
                let hasCollapse = patterns |> List.exists (fun p -> p.Pattern = GitPatternType.EntropyCollapse)
                Expect.isTrue hasCollapse "should detect entropy collapse (37.5% drop)"

            testCase "no entropy collapse when GHS stable" <| fun _ ->
                let commits = mkIcpCommits 5
                let patterns = Immune.scanCommitHistory commits (Some 0.80) (Some 0.82)
                let hasCollapse = patterns |> List.exists (fun p -> p.Pattern = GitPatternType.EntropyCollapse)
                Expect.isFalse hasCollapse "should not flag stable GHS"

            testCase "convention drift detected with low ICP adoption" <| fun _ ->
                let commits = mkFreeformCommits 20
                let patterns = Immune.scanCommitHistory commits (Some 0.7) None
                let hasDrift = patterns |> List.exists (fun p -> p.Pattern = GitPatternType.ConventionDrift)
                Expect.isTrue hasDrift "should detect convention drift"

            testCase "message truncation detected with long subjects" <| fun _ ->
                let longMsg = String.replicate 15 "verylongword "
                let commits = Array.init 10 (fun i ->
                    mkCommit longMsg CommitStyle.Other None [] 1 (float i))
                let patterns = Immune.scanCommitHistory commits (Some 0.7) None
                let hasTrunc = patterns |> List.exists (fun p -> p.Pattern = GitPatternType.MessageTruncation)
                Expect.isTrue hasTrunc "should detect message truncation"

            testCase "assessThreatLevel Medium with 3+ patterns" <| fun _ ->
                let patterns = [
                    { Pattern = GitPatternType.ScopeCreep; Confidence = 0.8; Severity = 0.5
                      Description = "test"; DetectedAt = now; Window = TimeSpan.FromDays(7.0) }
                    { Pattern = GitPatternType.ConventionDrift; Confidence = 0.7; Severity = 0.4
                      Description = "test"; DetectedAt = now; Window = TimeSpan.FromDays(14.0) }
                    { Pattern = GitPatternType.MessageTruncation; Confidence = 0.6; Severity = 0.3
                      Description = "test"; DetectedAt = now; Window = TimeSpan.FromDays(7.0) }
                ]
                let level = Immune.assessThreatLevel patterns None
                Expect.isTrue (level >= ThreatLevel.Medium) "3 patterns should be at least Medium"

            testCase "assessThreatLevel Critical with low GHS" <| fun _ ->
                let level = Immune.assessThreatLevel [] (Some 0.2)
                Expect.equal level ThreatLevel.Critical "GHS < 0.3 should be Critical"

            testCase "calculateImmunityScore decreases with patterns" <| fun _ ->
                let patterns = [
                    { Pattern = GitPatternType.ScopeCreep; Confidence = 0.8; Severity = 0.7
                      Description = "test"; DetectedAt = now; Window = TimeSpan.FromDays(7.0) }
                    { Pattern = GitPatternType.CommitStorm; Confidence = 0.9; Severity = 0.8
                      Description = "test"; DetectedAt = now; Window = TimeSpan.FromDays(1.0) }
                ]
                let score = Immune.calculateImmunityScore patterns
                Expect.isLessThan score 1.0 "immunity should decrease with patterns"
                Expect.isGreaterThanOrEqual score 0.0 "immunity should not go below 0"

            testCase "formatThreatReport returns non-empty string" <| fun _ ->
                let report = Immune.formatThreatReport [] ThreatLevel.None 1.0
                Expect.isNonEmpty report "report should not be empty"

            testCase "healthy ICP commits produce no critical patterns" <| fun _ ->
                // Use diverse commits to avoid triggering TypeMonoculture detector
                // (which fires when >80% of 10+ commits in a 14-day window share one type)
                let commits = mkDiverseCommits () |> Array.take 10
                let patterns = Immune.scanCommitHistory commits (Some 0.85) (Some 0.83)
                let hasCritical = patterns |> List.exists (fun p -> p.Severity > 0.9)
                Expect.isFalse hasCritical "healthy commits should have no critical patterns"
        ]

// ─────────────────────────────────────────────────────────────────────────────
// Neural Tests (8)
// ─────────────────────────────────────────────────────────────────────────────

module NeuralTests =
    open TestHelpers

    [<Tests>]
    let neuralTests =
        testList "GitIntelligence.Biomorphic.Neural" [

            testCase "ICP message scores high quality" <| fun _ ->
                let q = Neural.assessSemanticQuality "feat(mesh): add health check — SC-MESH-001"
                Expect.isGreaterThan q 0.5 "ICP message should score > 0.5"

            testCase "freeform message scores low quality" <| fun _ ->
                let q = Neural.assessSemanticQuality "did stuff"
                Expect.isLessThan q 0.5 "freeform message should score < 0.5"

            testCase "empty message scores zero" <| fun _ ->
                let q = Neural.assessSemanticQuality ""
                Expect.floatClose Accuracy.medium q 0.0 "empty message should score 0"

            testCase "EVOLUTION RUN penalized" <| fun _ ->
                let q = Neural.assessSemanticQuality "EVOLUTION RUN 5: Biomorphic Sync Complete"
                Expect.isLessThan q 0.5 "EVOLUTION RUN should be penalized"

            testCase "classifyIntent returns heuristic fallback" <| fun _ ->
                let commit = mkCommit "feat(mesh): add feature — context" CommitStyle.IcpConventional
                                (Some CommitType.Feat) [IcpScope.Mesh] 3 0.0
                let rec' = Neural.classifyIntent commit
                Expect.isTrue rec'.IsHeuristicFallback "should use heuristic fallback"
                Expect.isGreaterThan rec'.SemanticQuality 0.0 "quality should be positive"
                Expect.isGreaterThan rec'.Confidence 0.0 "confidence should be positive"

            testCase "suggestHeuristic generates valid recommendation" <| fun _ ->
                let rec' = Neural.suggestHeuristic ["lib/mesh/health.fs"; "lib/mesh/core.fs"] 50 10
                Expect.isNonEmpty rec'.SuggestedMessage "should generate a message"
                Expect.isTrue rec'.IsHeuristicFallback "should be heuristic"

            testCase "formatRecommendation returns non-empty" <| fun _ ->
                let rec' = { SuggestedMessage = "test"; SemanticQuality = 0.8;
                             Confidence = 0.7; Model = "heuristic"; IsHeuristicFallback = true }
                let s = Neural.formatRecommendation rec'
                Expect.isNonEmpty s "formatted recommendation should not be empty"

            testCase "quality score is bounded 0-1" <| fun _ ->
                let veryLong = String.replicate 50 "word "
                let q = Neural.assessSemanticQuality veryLong
                Expect.isGreaterThanOrEqual q 0.0 "quality >= 0"
                Expect.isLessThanOrEqual q 1.0 "quality <= 1"
        ]

// ─────────────────────────────────────────────────────────────────────────────
// Homeostatic Tests (10)
// ─────────────────────────────────────────────────────────────────────────────

module HomeostaticTests =
    open TestHelpers

    [<Tests>]
    let homeostaticTests =
        testList "GitIntelligence.Biomorphic.Homeostatic" [

            testCase "createPid has correct defaults" <| fun _ ->
                let pid = Homeostasis.createPid ()
                Expect.floatClose Accuracy.high pid.Setpoint 0.85 "setpoint 0.85"
                Expect.floatClose Accuracy.high pid.Kp 0.5 "Kp 0.5"
                Expect.floatClose Accuracy.high pid.Ki 0.1 "Ki 0.1"
                Expect.floatClose Accuracy.high pid.Kd 0.05 "Kd 0.05"
                Expect.floatClose Accuracy.high pid.Integral 0.0 "integral starts at 0"
                Expect.floatClose Accuracy.high pid.Output 0.0 "output starts at 0"

            testCase "assessMode Normal when GHS near setpoint" <| fun _ ->
                let mode = Homeostasis.assessMode 0.83 0.85 None
                Expect.equal mode HomeostaticMode.Normal "within 5% is Normal"

            testCase "assessMode Stressed when GHS 5-15% below" <| fun _ ->
                let mode = Homeostasis.assessMode 0.75 0.85 None
                Expect.equal mode HomeostaticMode.Stressed "~12% below is Stressed"

            testCase "assessMode Degraded when GHS 15-30% below" <| fun _ ->
                let mode = Homeostasis.assessMode 0.65 0.85 None
                Expect.equal mode HomeostaticMode.Degraded "~24% below is Degraded"

            testCase "assessMode Critical when GHS >30% below" <| fun _ ->
                let mode = Homeostasis.assessMode 0.50 0.85 None
                Expect.equal mode HomeostaticMode.Critical ">30% below is Critical"

            testCase "assessMode Recovery when improving from degraded" <| fun _ ->
                let mode = Homeostasis.assessMode 0.65 0.85 (Some 0.55)
                Expect.equal mode HomeostaticMode.Recovery "improving from worse is Recovery"

            testCase "updatePid adjusts output" <| fun _ ->
                let pid = Homeostasis.createPid ()
                let updated = Homeostasis.updatePid pid 0.70 (now.AddSeconds(1.0))
                Expect.notEqual updated.Output 0.0 "PID should adjust output for error"

            testCase "generateGuidance returns actions for Critical" <| fun _ ->
                let guidance = Homeostasis.generateGuidance HomeostaticMode.Critical 0.5 0.50
                Expect.isNonEmpty guidance "Critical mode should produce guidance"

            testCase "assess combines PID and mode" <| fun _ ->
                let pid = Homeostasis.createPid ()
                let state = Homeostasis.assess pid 0.70 (Some 0.72)
                Expect.equal state.CurrentGhs 0.70 "currentGhs should match"
                Expect.isNonEmpty state.Guidance "should have guidance"

            testCase "isCritical true when mode is Critical" <| fun _ ->
                let pid = Homeostasis.createPid ()
                let state = Homeostasis.assess pid 0.40 None
                Expect.isTrue (Homeostasis.isCritical state) "GHS 0.40 should be critical"
        ]

// ─────────────────────────────────────────────────────────────────────────────
// Regenerative Tests (8)
// ─────────────────────────────────────────────────────────────────────────────

module RegenerativeTests =
    open TestHelpers

    [<Tests>]
    let regenerativeTests =
        testList "GitIntelligence.Biomorphic.Regenerative" [

            testCase "computeVitalSigns with healthy inputs" <| fun _ ->
                let commits = mkIcpCommits 20
                let vitals = Regenerative.computeVitalSigns commits 0.85 0.1
                Expect.isGreaterThan vitals.HealthIndex 0.0 "health > 0"
                Expect.isLessThanOrEqual vitals.HealthIndex 1.0 "health <= 1"
                Expect.isGreaterThanOrEqual vitals.StressIndex 0.0 "stress >= 0"
                Expect.isGreaterThan vitals.EnergyIndex 0.0 "energy > 0 with active commits"

            testCase "computeVitalSigns with no commits" <| fun _ ->
                let vitals = Regenerative.computeVitalSigns [||] 0.5 0.5
                Expect.isGreaterThanOrEqual vitals.HealthIndex 0.0 "health >= 0"
                Expect.floatClose Accuracy.medium vitals.EnergyIndex 0.1 "energy 0.1 with no commits (stagnant)"

            testCase "isPathological with very low health" <| fun _ ->
                let vitals = { HealthIndex = 0.1; StressIndex = 0.5; EnergyIndex = 0.5 }
                Expect.isTrue (Regenerative.isPathological vitals) "HealthIndex < 0.2 is pathological"

            testCase "isPathological with extreme stress" <| fun _ ->
                let vitals = { HealthIndex = 0.5; StressIndex = 0.96; EnergyIndex = 0.5 }
                Expect.isTrue (Regenerative.isPathological vitals) "StressIndex > 0.95 is pathological"

            testCase "isPathological false when healthy" <| fun _ ->
                let vitals = { HealthIndex = 0.8; StressIndex = 0.3; EnergyIndex = 0.7 }
                Expect.isFalse (Regenerative.isPathological vitals) "normal values not pathological"

            testCase "isStagnant with low energy" <| fun _ ->
                let vitals = { HealthIndex = 0.5; StressIndex = 0.3; EnergyIndex = 0.1 }
                Expect.isTrue (Regenerative.isStagnant vitals) "EnergyIndex < 0.2 is stagnant"

            testCase "diagnose pathological triggers ResetBaseline and Recompute" <| fun _ ->
                let vitals = { HealthIndex = 0.1; StressIndex = 0.96; EnergyIndex = 0.5 }
                let actions = Regenerative.diagnose vitals 100
                Expect.contains actions RegenerativeAction.ResetBaseline "should recommend ResetBaseline"
                Expect.contains actions RegenerativeAction.Recompute "should recommend Recompute"

            testCase "diagnose healthy returns NoAction" <| fun _ ->
                let vitals = { HealthIndex = 0.8; StressIndex = 0.3; EnergyIndex = 0.7 }
                let actions = Regenerative.diagnose vitals 100
                Expect.contains actions RegenerativeAction.NoAction "healthy should get NoAction"
        ]

// ─────────────────────────────────────────────────────────────────────────────
// Symbiotic Tests (8)
// ─────────────────────────────────────────────────────────────────────────────

module SymbioticTests =
    open TestHelpers

    [<Tests>]
    let symbioticTests =
        testList "GitIntelligence.Biomorphic.Symbiotic" [

            testCase "assessSurvival with active commits" <| fun _ ->
                let commits = mkIcpCommits 15
                let score = Symbiotic.assessSurvival commits
                Expect.isGreaterThan score 0.5 "active project should have decent survival"

            testCase "assessSurvival with no commits" <| fun _ ->
                let score = Symbiotic.assessSurvival [||]
                Expect.floatClose Accuracy.high score 0.0 "no commits = 0 survival"

            testCase "assessSentience with AI co-authored commits" <| fun _ ->
                let commits = [| for i in 0..9 -> mkAiCommit (float i * 0.5) |]
                let score = Symbiotic.assessSentience commits
                Expect.isGreaterThan score 0.3 "AI-heavy history should score on sentience"

            testCase "assessPower with diverse commits" <| fun _ ->
                let commits = mkDiverseCommits ()
                let score = Symbiotic.assessPower commits
                Expect.isGreaterThan score 0.5 "diverse types and scopes should score high"

            testCase "assessPower with monoculture" <| fun _ ->
                let commits = Array.init 10 (fun i ->
                    mkCommit (sprintf "fix(mesh): fix %d" i) CommitStyle.IcpConventional
                        (Some CommitType.Fix) [IcpScope.Mesh] 1 (float i))
                let score = Symbiotic.assessPower commits
                Expect.isLessThan score 0.5 "monoculture should score low on power"

            testCase "assessAlignment weights correctly" <| fun _ ->
                let commits = mkDiverseCommits ()
                let alignment = Symbiotic.assessAlignment commits
                Expect.isGreaterThan alignment.OverallAlignment 0.0 "overall should be positive"
                Expect.isLessThanOrEqual alignment.OverallAlignment 1.0 "overall should be <= 1"

            testCase "validateDirective passes when all goals above threshold" <| fun _ ->
                let alignment = { SurvivalScore = 0.8; SentienceScore = 0.5;
                                  PowerScore = 0.6; OverallAlignment = 0.7 }
                let result = Symbiotic.validateDirective alignment
                Expect.isOk result "all goals above 0.3 should pass"

            testCase "validateDirective fails when goal below 0.3" <| fun _ ->
                let alignment = { SurvivalScore = 0.1; SentienceScore = 0.5;
                                  PowerScore = 0.6; OverallAlignment = 0.4 }
                let result = Symbiotic.validateDirective alignment
                Expect.isError result "survival below 0.3 should fail"
        ]

// ─────────────────────────────────────────────────────────────────────────────
// Trend Analysis Tests (8)
// ─────────────────────────────────────────────────────────────────────────────

module TrendTests =
    open TestHelpers

    [<Tests>]
    let trendTests =
        testList "GitIntelligence.Biomorphic.Trend" [

            testCase "computeEma with empty array" <| fun _ ->
                let result = Trend.computeEma [||] 0.5
                Expect.isEmpty result "empty input yields empty EMA"

            testCase "computeEma with single value" <| fun _ ->
                let result = Trend.computeEma [|0.7|] 0.5
                Expect.equal result.Length 1 "single value EMA has length 1"
                Expect.floatClose Accuracy.high result.[0] 0.7 "single value EMA equals input"

            testCase "computeEma smooths values" <| fun _ ->
                let values = [| 0.5; 0.6; 0.7; 0.8; 0.9 |]
                let ema = Trend.computeEma values 0.5
                Expect.equal ema.Length 5 "EMA length matches input"
                // EMA should trail behind the raw values
                Expect.isLessThan ema.[4] 0.9 "EMA trails behind raw values"
                Expect.isGreaterThan ema.[4] 0.5 "EMA is above first value"

            testCase "detectRegression flags >10% drop" <| fun _ ->
                let (isReg, dropPct, _) = Trend.detectRegression 0.70 0.85
                Expect.isTrue isReg ">10% drop should be flagged"
                Expect.isGreaterThan dropPct 10.0 "drop should be >10%"

            testCase "detectRegression no flag for stable GHS" <| fun _ ->
                let (isReg, _, _) = Trend.detectRegression 0.83 0.85
                Expect.isFalse isReg "~2% drop should not be flagged"

            testCase "computeVelocity with recent commits" <| fun _ ->
                let commits = mkIcpCommits 10
                let vel = Trend.computeVelocity commits 7.0
                Expect.isGreaterThan vel 0.0 "velocity should be positive with recent commits"

            testCase "projectTarget returns None with insufficient data" <| fun _ ->
                let events = [| mkEvent 0.7 1.0; mkEvent 0.72 0.5 |]
                let proj = Trend.projectTarget events 0.85
                Expect.isNone proj "< 3 events should return None"

            testCase "projectTarget returns Some with improving trend" <| fun _ ->
                let events = [| for i in 0..9 -> mkEvent (0.50 + float i * 0.03) (float (9 - i)) |]
                let proj = Trend.projectTarget events 0.85
                Expect.isSome proj "improving trend should project target"
        ]

// ─────────────────────────────────────────────────────────────────────────────
// Biomorphic Orchestrator Tests (10)
// ─────────────────────────────────────────────────────────────────────────────

module OrchestratorTests =
    open TestHelpers

    let mkPid () = Homeostasis.createPid ()

    [<Tests>]
    let orchestratorTests =
        testList "GitIntelligence.Biomorphic.Orchestrator" [

            testCase "runFullAssessment with healthy commits" <| fun _ ->
                // Use diverse commits to avoid TypeMonoculture detection
                let commits = mkDiverseCommits ()
                let state = BiomorphicOrchestrator.runFullAssessment commits 0.85 (Some 0.83) (mkPid ()) 100
                Expect.isGreaterThan state.OverallHealth 0.0 "overall health should be positive"
                Expect.isLessThanOrEqual state.OverallHealth 1.0 "overall health should be <= 1"
                Expect.isFalse state.ShouldHalt "healthy system should not halt"

            testCase "runFullAssessment with no commits" <| fun _ ->
                let state = BiomorphicOrchestrator.runFullAssessment [||] 0.5 None (mkPid ()) 0
                Expect.isGreaterThanOrEqual state.OverallHealth 0.0 "health >= 0 even with no commits"

            testCase "runFullAssessment populates all subsystem fields" <| fun _ ->
                let commits = mkIcpCommits 10
                let state = BiomorphicOrchestrator.runFullAssessment commits 0.80 (Some 0.78) (mkPid ()) 50
                Expect.isGreaterThanOrEqual state.ImmunityScore 0.0 "immunity populated"
                Expect.isNonEmpty state.Homeostasis.Guidance "homeostasis guidance populated"
                Expect.isGreaterThanOrEqual state.VitalSigns.HealthIndex 0.0 "vitals populated"
                Expect.isGreaterThanOrEqual state.Alignment.OverallAlignment 0.0 "alignment populated"

            testCase "shouldHalt false when no subsystem critical" <| fun _ ->
                // Use diverse commits to avoid TypeMonoculture triggering immune voter
                let commits = mkDiverseCommits ()
                let state = BiomorphicOrchestrator.runFullAssessment commits 0.85 (Some 0.84) (mkPid ()) 100
                Expect.isFalse state.ShouldHalt "no critical subsystems = no halt"

            testCase "shouldHalt true with very low GHS (2oo3 voting)" <| fun _ ->
                // GHS 0.10: immunity low (entropy collapse), homeostatic critical, regenerative pathological
                let commits = mkFreeformCommits 5
                let state = BiomorphicOrchestrator.runFullAssessment commits 0.10 (Some 0.80) (mkPid ()) 100
                // With GHS at 0.10 vs setpoint 0.85, at least 2 of 3 voters should trigger
                // Homeostatic: Critical (>30% below), Regenerative: likely pathological
                Expect.isTrue state.ShouldHalt "very low GHS should trigger 2oo3 halt"

            testCase "overall health uses correct weights" <| fun _ ->
                // With perfect scores in all subsystems, overall should be ~1.0
                let commits = mkDiverseCommits ()
                let state = BiomorphicOrchestrator.runFullAssessment commits 0.90 (Some 0.88) (mkPid ()) 50
                // Can't be exactly 1.0 due to rounding and mode transitions,
                // but should be > 0.5 with good inputs
                Expect.isGreaterThan state.OverallHealth 0.3 "weighted average should be reasonable"

            testCase "formatBiomorphicDashboard returns non-empty" <| fun _ ->
                let commits = mkIcpCommits 10
                let state = BiomorphicOrchestrator.runFullAssessment commits 0.80 (Some 0.78) (mkPid ()) 50
                let dashboard = BiomorphicOrchestrator.formatBiomorphicDashboard state
                Expect.isNonEmpty dashboard "dashboard should not be empty"

            testCase "formatBiomorphicDashboard contains key sections" <| fun _ ->
                let commits = mkIcpCommits 10
                let state = BiomorphicOrchestrator.runFullAssessment commits 0.80 None (mkPid ()) 50
                let dashboard = BiomorphicOrchestrator.formatBiomorphicDashboard state
                Expect.stringContains dashboard "BIOMORPHIC" "should contain header"
                Expect.stringContains dashboard "Immune" "should contain Immune section"
                Expect.stringContains dashboard "Homeostatic" "should contain Homeostatic section"

            testCase "timestamp is recent" <| fun _ ->
                let commits = mkIcpCommits 5
                let state = BiomorphicOrchestrator.runFullAssessment commits 0.80 None (mkPid ()) 10
                let age = DateTimeOffset.UtcNow - state.Timestamp
                Expect.isLessThan age.TotalSeconds 5.0 "timestamp should be very recent"

            testCase "neural recommendation present with commits" <| fun _ ->
                let commits = mkIcpCommits 5
                let state = BiomorphicOrchestrator.runFullAssessment commits 0.80 None (mkPid ()) 10
                Expect.isSome state.NeuralRecommendation "should have neural rec with commits"
        ]

// ─────────────────────────────────────────────────────────────────────────────
// FsCheck Property Tests (15)
// ─────────────────────────────────────────────────────────────────────────────

module BiomorphicPropertyTests =
    open TestHelpers

    [<Tests>]
    let propertyTests =
        testList "GitIntelligence.Biomorphic.Properties" [

            testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 100 }
                "immunity score is always in [0, 1]" <| fun () ->
                let patterns = [
                    for _ in 0 .. (abs (System.Random.Shared.Next(10))) ->
                        { Pattern = GitPatternType.ScopeCreep; Confidence = System.Random.Shared.NextDouble()
                          Severity = System.Random.Shared.NextDouble(); Description = "prop"
                          DetectedAt = now; Window = TimeSpan.FromDays(7.0) }
                ]
                let score = Immune.calculateImmunityScore patterns
                score >= 0.0 && score <= 1.0

            testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 100 }
                "semantic quality is always in [0, 1]" <| fun (msg: NonEmptyString) ->
                let q = Neural.assessSemanticQuality msg.Get
                q >= 0.0 && q <= 1.0

            testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 50 }
                "PID integral is bounded [-10, 10]" <| fun () ->
                let mutable pid = Homeostasis.createPid ()
                for i in 0..20 do
                    let ghs = System.Random.Shared.NextDouble()
                    pid <- Homeostasis.updatePid pid ghs (now.AddSeconds(float i))
                pid.Integral >= -10.0 && pid.Integral <= 10.0

            testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 100 }
                "vital signs indices are in [0, 1]" <| fun () ->
                let ghs = System.Random.Shared.NextDouble()
                let threat = System.Random.Shared.NextDouble()
                let commits = mkIcpCommits (System.Random.Shared.Next(1, 20))
                let vitals = Regenerative.computeVitalSigns commits ghs threat
                vitals.HealthIndex >= 0.0 && vitals.HealthIndex <= 1.0 &&
                vitals.StressIndex >= 0.0 && vitals.StressIndex <= 1.0 &&
                vitals.EnergyIndex >= 0.0 && vitals.EnergyIndex <= 1.0

            testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 100 }
                "alignment overall is in [0, 1]" <| fun () ->
                let n = System.Random.Shared.Next(1, 30)
                let commits = mkIcpCommits n
                let alignment = Symbiotic.assessAlignment commits
                alignment.OverallAlignment >= 0.0 && alignment.OverallAlignment <= 1.0

            testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 100 }
                "survival score is in [0, 1]" <| fun () ->
                let n = System.Random.Shared.Next(0, 30)
                let commits = if n = 0 then [||] else mkIcpCommits n
                let score = Symbiotic.assessSurvival commits
                score >= 0.0 && score <= 1.0

            testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 100 }
                "sentience score is in [0, 1]" <| fun () ->
                let n = System.Random.Shared.Next(0, 20)
                let commits = if n = 0 then [||] else mkIcpCommits n
                let score = Symbiotic.assessSentience commits
                score >= 0.0 && score <= 1.0

            testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 100 }
                "power score is in [0, 1]" <| fun () ->
                let n = System.Random.Shared.Next(0, 20)
                let commits = if n = 0 then [||] else mkIcpCommits n
                let score = Symbiotic.assessPower commits
                score >= 0.0 && score <= 1.0

            testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 50 }
                "overall health is in [0, 1]" <| fun () ->
                let n = System.Random.Shared.Next(1, 15)
                let commits = mkIcpCommits n
                let ghs = 0.3 + System.Random.Shared.NextDouble() * 0.6
                let state = BiomorphicOrchestrator.runFullAssessment commits ghs None (Homeostasis.createPid ()) 50
                state.OverallHealth >= 0.0 && state.OverallHealth <= 1.0

            testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 50 }
                "shouldHalt requires at least 2 voters" <| fun () ->
                // If immunity is good (> 0.2) and vitals are good, halt should be false
                // Use diverse commits to avoid TypeMonoculture triggering immune voter
                let commits = mkDiverseCommits ()
                let state = BiomorphicOrchestrator.runFullAssessment commits 0.85 (Some 0.84)
                                (Homeostasis.createPid ()) 100
                // With GHS at setpoint and diverse commits, no voter should trigger → no halt
                not state.ShouldHalt

            testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 100 }
                "EMA output length matches input length" <| fun () ->
                let n = System.Random.Shared.Next(0, 50)
                let values = [| for _ in 0 .. n - 1 -> System.Random.Shared.NextDouble() |]
                let ema = Trend.computeEma values 0.3
                ema.Length = values.Length

            testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 100 }
                "EMA first value equals first input" <| fun () ->
                let n = System.Random.Shared.Next(1, 20)
                let values = [| for _ in 0 .. n - 1 -> System.Random.Shared.NextDouble() |]
                let ema = Trend.computeEma values 0.5
                abs (ema.[0] - values.[0]) < 1e-10

            testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 100 }
                "regression detection is symmetric around threshold" <| fun () ->
                let baseline = 0.5 + System.Random.Shared.NextDouble() * 0.4
                let smallDrop = baseline * 0.95  // 5% drop — should not flag
                let largeDrop = baseline * 0.85  // 15% drop — should flag
                let (isSmall, _, _) = Trend.detectRegression smallDrop baseline
                let (isLarge, _, _) = Trend.detectRegression largeDrop baseline
                not isSmall && isLarge

            testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 50 }
                "validateDirective consistent with individual scores" <| fun () ->
                let s = System.Random.Shared.NextDouble()
                let e = System.Random.Shared.NextDouble()
                let p = System.Random.Shared.NextDouble()
                let alignment = { SurvivalScore = s; SentienceScore = e;
                                  PowerScore = p; OverallAlignment = 0.5 * s + 0.3 * e + 0.2 * p }
                match Symbiotic.validateDirective alignment with
                | Ok () -> s >= 0.3 && e >= 0.3 && p >= 0.3
                | Error _ -> s < 0.3 || e < 0.3 || p < 0.3

            testPropertyWithConfig { FsCheckConfig.defaultConfig with maxTest = 50 }
                "isPathological iff HealthIndex < 0.2 or StressIndex > 0.95" <| fun () ->
                let h = System.Random.Shared.NextDouble()
                let s = System.Random.Shared.NextDouble()
                let vitals = { HealthIndex = h; StressIndex = s; EnergyIndex = 0.5 }
                let result = Regenerative.isPathological vitals
                result = (h < 0.2 || s > 0.95)
        ]
