// =============================================================================
// Git Intelligence — Expecto Tests
// =============================================================================
// Purpose:  Unit + property tests for Parser, Analysis, Validation, Generation.
//
// STAMP:    SC-CHG-001 (structured change notes), SC-SYNC-DOC-009
// AOR:      AOR-CHG-001 to AOR-CHG-010
// =============================================================================

namespace Cepaf.Tests.Unit.GitIntelligence

open System
open Expecto
open FsCheck
open Cepaf.GitIntelligence

// ─────────────────────────────────────────────────────────────────────────────
// Types Tests
// ─────────────────────────────────────────────────────────────────────────────

module TypesTests =

    [<Tests>]
    let commitTypeTests =
        testList "GitIntelligence.Types.CommitType" [
            testCase "all contains exactly 9 types" <| fun _ ->
                Expect.equal CommitType.all.Length 9 "ICP v2.0 defines exactly 9 commit types"

            testCase "toTag roundtrips through fromTag" <| fun _ ->
                for ct in CommitType.all do
                    let tag = CommitType.toTag ct
                    let parsed = CommitType.fromTag tag
                    Expect.equal parsed (Some ct) (sprintf "roundtrip failed for %A" ct)

            testCase "fromTag rejects unknown types" <| fun _ ->
                Expect.isNone (CommitType.fromTag "feature") "should reject 'feature'"
                Expect.isNone (CommitType.fromTag "bugfix") "should reject 'bugfix'"
                Expect.isNone (CommitType.fromTag "update") "should reject 'update'"
                Expect.isNone (CommitType.fromTag "") "should reject empty string"

            testCase "fromTag is case-insensitive" <| fun _ ->
                Expect.equal (CommitType.fromTag "Feat") (Some CommitType.Feat) "mixed case"
                Expect.equal (CommitType.fromTag "FIX") (Some CommitType.Fix) "upper case"
                Expect.equal (CommitType.fromTag "  docs  ") (Some CommitType.Docs) "whitespace trimmed"

            testCase "versionBump returns correct bumps" <| fun _ ->
                Expect.equal (CommitType.versionBump CommitType.Feat) (Some "MINOR") "feat is MINOR"
                Expect.equal (CommitType.versionBump CommitType.Fix) (Some "PATCH") "fix is PATCH"
                Expect.equal (CommitType.versionBump CommitType.Security) (Some "PATCH+") "security is PATCH+"
                Expect.isNone (CommitType.versionBump CommitType.Docs) "docs has no bump"
                Expect.isNone (CommitType.versionBump CommitType.Chore) "chore has no bump"
                Expect.isNone (CommitType.versionBump CommitType.Refactor) "refactor has no bump"
        ]

    [<Tests>]
    let icpScopeTests =
        testList "GitIntelligence.Types.IcpScope" [
            testCase "all contains exactly 23 scopes" <| fun _ ->
                Expect.equal IcpScope.all.Length 23 "ICP v2.0 defines exactly 23 scopes"

            testCase "toTag roundtrips through fromTag" <| fun _ ->
                for scope in IcpScope.all do
                    let tag = IcpScope.toTag scope
                    let parsed = IcpScope.fromTag tag
                    Expect.equal parsed (Some scope) (sprintf "roundtrip failed for %A" scope)

            testCase "fromTag rejects unknown scopes" <| fun _ ->
                Expect.isNone (IcpScope.fromTag "sprint-54") "historical sprint scope rejected"
                Expect.isNone (IcpScope.fromTag "unknown") "unknown scope rejected"
                Expect.isNone (IcpScope.fromTag "") "empty string rejected"

            testCase "fractalLayer maps to correct layers" <| fun _ ->
                Expect.equal (IcpScope.fractalLayer IcpScope.Guardian) "L0" "guardian is L0"
                Expect.equal (IcpScope.fractalLayer IcpScope.App) "L1-L2" "app is L1-L2"
                Expect.equal (IcpScope.fractalLayer IcpScope.Mesh) "L3-L4" "mesh is L3-L4"
                Expect.equal (IcpScope.fractalLayer IcpScope.Vsm) "L5-L6" "vsm is L5-L6"
                Expect.equal (IcpScope.fractalLayer IcpScope.Fed) "L7" "fed is L7"
                Expect.equal (IcpScope.fractalLayer IcpScope.Test) "Cross" "test is cross-cutting"
        ]

    [<Tests>]
    let commitStyleTests =
        testList "GitIntelligence.Types.CommitStyle" [
            testCase "semanticDensity is ordered correctly" <| fun _ ->
                // ICP should have highest density
                let icpDensity = CommitStyle.semanticDensity CommitStyle.IcpConventional
                let evoDensity = CommitStyle.semanticDensity CommitStyle.EvolutionRun
                Expect.isGreaterThan icpDensity evoDensity
                    "ICP density (0.568) should exceed EVOLUTION RUN density (0.064)"

            testCase "all densities are positive" <| fun _ ->
                let styles = [
                    CommitStyle.IcpConventional; CommitStyle.ConventionalNoEmDash
                    CommitStyle.Emoji; CommitStyle.EvolutionRun; CommitStyle.Hyperbolic
                    CommitStyle.PhaseSop; CommitStyle.Other
                ]
                for s in styles do
                    let d = CommitStyle.semanticDensity s
                    Expect.isGreaterThan d 0.0 (sprintf "%A should have positive density" s)
        ]

// ─────────────────────────────────────────────────────────────────────────────
// Parser Tests
// ─────────────────────────────────────────────────────────────────────────────

module ParserTests =

    [<Tests>]
    let classifyStyleTests =
        testList "GitIntelligence.Parser.classifyStyle" [
            // ICP v2.0 with em-dash
            testCase "classifies ICP v2.0 with em-dash" <| fun _ ->
                let style = Parser.classifyStyle "fix(sentinel): correct JsonDocument parsing \u2014 .NET 10 broke private records"
                Expect.equal style CommitStyle.IcpConventional "full ICP with em-dash"

            testCase "classifies ICP v2.0 scopeless with em-dash" <| fun _ ->
                let style = Parser.classifyStyle "chore: update devenv.nix \u2014 add git-intelligence alias"
                Expect.equal style CommitStyle.IcpConventional "scopeless ICP with em-dash"

            // Conventional without em-dash
            testCase "classifies conventional without em-dash" <| fun _ ->
                let style = Parser.classifyStyle "feat(app): add user authentication"
                Expect.equal style CommitStyle.ConventionalNoEmDash "conventional without em-dash"

            testCase "classifies scopeless conventional" <| fun _ ->
                let style = Parser.classifyStyle "docs: update README"
                Expect.equal style CommitStyle.ConventionalNoEmDash "scopeless conventional"

            // EVOLUTION RUN
            testCase "classifies EVOLUTION RUN" <| fun _ ->
                let style = Parser.classifyStyle "EVOLUTION RUN 2: Biomorphic Synchronization Complete"
                Expect.equal style CommitStyle.EvolutionRun "EVOLUTION RUN pattern"

            testCase "classifies EVOLUTION RUN case-insensitive" <| fun _ ->
                let style = Parser.classifyStyle "evolution run 1: something"
                Expect.equal style CommitStyle.EvolutionRun "lowercase evolution run"

            // Hyperbolic
            testCase "classifies SINGULARITY" <| fun _ ->
                let style = Parser.classifyStyle "SINGULARITY: Total System Convergence"
                Expect.equal style CommitStyle.Hyperbolic "SINGULARITY prefix"

            testCase "classifies TOTAL BIOMORPHIC" <| fun _ ->
                let style = Parser.classifyStyle "TOTAL BIOMORPHIC Deployment Phase Complete"
                Expect.equal style CommitStyle.Hyperbolic "TOTAL BIOMORPHIC prefix"

            // Emoji
            testCase "classifies emoji prefix" <| fun _ ->
                let style = Parser.classifyStyle "\u2705 All tests passing"
                Expect.equal style CommitStyle.Emoji "checkmark emoji"

            testCase "classifies star emoji" <| fun _ ->
                let style = Parser.classifyStyle "\u2B50 Major feature release"
                Expect.equal style CommitStyle.Emoji "star emoji"

            // Phase/SOP
            testCase "classifies PHASE prefix" <| fun _ ->
                let style = Parser.classifyStyle "PHASE 3: Agent Architecture Deployment"
                Expect.equal style CommitStyle.PhaseSop "PHASE prefix"

            testCase "classifies SPRINT prefix" <| fun _ ->
                let style = Parser.classifyStyle "SPRINT 47: Multi-Layer Sprint Complete"
                Expect.equal style CommitStyle.PhaseSop "SPRINT prefix"

            // Other
            testCase "classifies unrecognized as Other" <| fun _ ->
                let style = Parser.classifyStyle "random commit message that doesn't match anything"
                Expect.equal style CommitStyle.Other "unrecognized format"

            testCase "classifies empty string as Other" <| fun _ ->
                let style = Parser.classifyStyle ""
                Expect.equal style CommitStyle.Other "empty string"
        ]

    [<Tests>]
    let parseIcpSubjectTests =
        testList "GitIntelligence.Parser.parseIcpSubject" [
            testCase "parses full ICP with em-dash" <| fun _ ->
                let result = Parser.parseIcpSubject "feat(mesh): add boot orchestrator \u2014 5-stage pipeline"
                Expect.isSome result "should parse"
                let (ct, scopes, rawScopes, action, context, hasEmDash) = result.Value
                Expect.equal ct (Some CommitType.Feat) "type is feat"
                Expect.equal scopes [IcpScope.Mesh] "scope is mesh"
                Expect.equal rawScopes ["mesh"] "raw scope"
                Expect.equal action "add boot orchestrator" "action extracted"
                Expect.equal context (Some "5-stage pipeline") "context after em-dash"
                Expect.isTrue hasEmDash "has em-dash"

            testCase "parses multi-scope" <| fun _ ->
                let result = Parser.parseIcpSubject "fix(zenoh,cepaf): correct FFI bridge \u2014 null handle safety"
                Expect.isSome result "should parse"
                let (_, scopes, rawScopes, _, _, _) = result.Value
                Expect.equal scopes [IcpScope.Zenoh; IcpScope.Cepaf] "two scopes parsed"
                Expect.equal rawScopes ["zenoh"; "cepaf"] "two raw scopes"

            testCase "parses conventional without em-dash" <| fun _ ->
                let result = Parser.parseIcpSubject "refactor(app): simplify auth pipeline"
                Expect.isSome result "should parse"
                let (ct, scopes, _, _, context, hasEmDash) = result.Value
                Expect.equal ct (Some CommitType.Refactor) "type is refactor"
                Expect.equal scopes [IcpScope.App] "scope is app"
                Expect.isNone context "no context"
                Expect.isFalse hasEmDash "no em-dash"

            testCase "parses scopeless format" <| fun _ ->
                let result = Parser.parseIcpSubject "chore: update dependencies"
                Expect.isSome result "should parse"
                let (ct, scopes, rawScopes, _, _, _) = result.Value
                Expect.equal ct (Some CommitType.Chore) "type is chore"
                Expect.isEmpty scopes "no scopes"
                Expect.isEmpty rawScopes "no raw scopes"

            testCase "returns None for non-ICP format" <| fun _ ->
                Expect.isNone (Parser.parseIcpSubject "EVOLUTION RUN 1: stuff") "EVOLUTION RUN"
                Expect.isNone (Parser.parseIcpSubject "random message") "random"
                Expect.isNone (Parser.parseIcpSubject "") "empty"
        ]

    [<Tests>]
    let validateTests =
        testList "GitIntelligence.Parser.validate" [
            testCase "valid ICP message passes" <| fun _ ->
                let result = Parser.validate "feat(mesh): add boot orchestrator \u2014 5-stage pipeline"
                Expect.isTrue result.IsValid "should be valid"
                Expect.isEmpty result.Issues "no issues"
                Expect.equal result.ParsedType (Some CommitType.Feat) "type parsed"
                Expect.isTrue result.HasEmDash "has em-dash"

            testCase "valid scopeless ICP passes" <| fun _ ->
                let result = Parser.validate "docs: update architecture docs"
                Expect.isTrue result.IsValid "should be valid"

            testCase "EVOLUTION RUN fails validation" <| fun _ ->
                let result = Parser.validate "EVOLUTION RUN 2: Biomorphic Sync Complete"
                Expect.isFalse result.IsValid "should fail"
                Expect.contains result.Issues ValidationIssue.EvolutionRunFormat "evolution run issue"

            testCase "hyperbolic fails validation" <| fun _ ->
                let result = Parser.validate "SINGULARITY: Total Convergence"
                Expect.isFalse result.IsValid "should fail"
                Expect.contains result.Issues ValidationIssue.HyperbolicFormat "hyperbolic issue"

            testCase "emoji prefix fails validation" <| fun _ ->
                let result = Parser.validate "\u2705 All tests passing"
                Expect.isFalse result.IsValid "should fail"
                Expect.contains result.Issues ValidationIssue.EmojiPrefix "emoji issue"

            testCase "subject too long fails" <| fun _ ->
                let longSubject = "feat(mesh): " + String.replicate 80 "x"
                let result = Parser.validate longSubject
                Expect.isFalse result.IsValid "should fail for long subject"
                let hasLongIssue =
                    result.Issues |> List.exists (fun i ->
                        match i with
                        | ValidationIssue.SubjectTooLong _ -> true
                        | _ -> false)
                Expect.isTrue hasLongIssue "should have SubjectTooLong issue"

            testCase "past tense detected" <| fun _ ->
                let result = Parser.validate "feat(app): added user login"
                let hasPastTense =
                    result.Issues |> List.exists (fun i ->
                        match i with
                        | ValidationIssue.PastTense "added" -> true
                        | _ -> false)
                Expect.isTrue hasPastTense "should detect past tense 'added'"

            testCase "invalid scope detected" <| fun _ ->
                let result = Parser.validate "feat(sprint-54): do something"
                let hasInvalidScope =
                    result.Issues |> List.exists (fun i ->
                        match i with
                        | ValidationIssue.InvalidScope "sprint-54" -> true
                        | _ -> false)
                Expect.isTrue hasInvalidScope "should detect invalid scope 'sprint-54'"
        ]

    [<Tests>]
    let generateMessageTests =
        testList "GitIntelligence.Parser.generateMessage" [
            testCase "generates basic ICP message" <| fun _ ->
                let input = {
                    Type = CommitType.Feat
                    Scopes = [IcpScope.Mesh]
                    Action = "add boot orchestrator"
                    Context = Some "5-stage pipeline"
                    Why = None
                    What = None
                    FilesCreated = 0
                    FilesModified = 0
                    Layers = []
                    StampRefs = []
                    TaskRef = None
                }
                let msg = Parser.generateMessage input
                let lines = msg.Split('\n')
                Expect.stringContains lines.[0] "feat(mesh):" "subject starts with type(scope):"
                Expect.stringContains lines.[0] "\u2014" "subject contains em-dash"
                Expect.stringContains msg "Co-Authored-By:" "has co-author trailer"

            testCase "generates message with structured body" <| fun _ ->
                let input = {
                    Type = CommitType.Fix
                    Scopes = [IcpScope.Sentinel; IcpScope.Cepaf]
                    Action = "correct FFI bridge"
                    Context = Some "null handle safety"
                    Why = Some "production crash on null FFI handle"
                    What = Some "added null check before dereference"
                    FilesCreated = 1
                    FilesModified = 3
                    Layers = [("L1-CODE", 2); ("L3-SYSTEM", 1)]
                    StampRefs = ["SC-FFI-001"; "SC-ZENOH-002"]
                    TaskRef = Some "S60-T001"
                }
                let msg = Parser.generateMessage input
                Expect.stringContains msg "fix(sentinel,cepaf):" "multi-scope"
                Expect.stringContains msg "WHY:" "has WHY section"
                Expect.stringContains msg "WHAT:" "has WHAT section"
                Expect.stringContains msg "Files: 1 created, 3 modified" "file stats"
                Expect.stringContains msg "Layer: L1-CODE(2), L3-SYSTEM(1)" "layer info"
                Expect.stringContains msg "STAMP: SC-FFI-001, SC-ZENOH-002" "stamp refs"
                Expect.stringContains msg "Task: S60-T001" "task ref"

            testCase "truncates long subjects to 80 chars" <| fun _ ->
                let input = {
                    Type = CommitType.Feat
                    Scopes = [IcpScope.Mesh]
                    Action = "implement a very long action description that would exceed the eighty character limit for commit subjects"
                    Context = None
                    Why = None; What = None
                    FilesCreated = 0; FilesModified = 0
                    Layers = []; StampRefs = []; TaskRef = None
                }
                let msg = Parser.generateMessage input
                let subject = msg.Split('\n').[0]
                Expect.isLessThanOrEqual subject.Length 80 "subject should be <= 80 chars"
                Expect.stringContains subject "..." "truncated subjects end with ..."

            testCase "generates scopeless message" <| fun _ ->
                let input = {
                    Type = CommitType.Chore
                    Scopes = []
                    Action = "update devenv.nix"
                    Context = None
                    Why = None; What = None
                    FilesCreated = 0; FilesModified = 1
                    Layers = []; StampRefs = []; TaskRef = None
                }
                let msg = Parser.generateMessage input
                let subject = msg.Split('\n').[0]
                Expect.stringStarts subject "chore: " "scopeless format"
                Expect.isFalse (subject.Contains("()")) "no empty parens"
        ]

    [<Tests>]
    let mapHistoricalScopeTests =
        testList "GitIntelligence.Parser.mapHistoricalScope" [
            testCase "maps direct ICP scopes" <| fun _ ->
                Expect.equal (Parser.mapHistoricalScope "mesh") (Some IcpScope.Mesh) "mesh"
                Expect.equal (Parser.mapHistoricalScope "app") (Some IcpScope.App) "app"
                Expect.equal (Parser.mapHistoricalScope "zenoh") (Some IcpScope.Zenoh) "zenoh"

            testCase "maps historical drift scopes" <| fun _ ->
                Expect.equal (Parser.mapHistoricalScope "sprint-54") (Some IcpScope.Core) "sprint -> core"
                Expect.equal (Parser.mapHistoricalScope "ash") (Some IcpScope.App) "ash -> app"
                Expect.equal (Parser.mapHistoricalScope "constraint-sync") (Some IcpScope.Sync) "constraint-sync -> sync"
                Expect.equal (Parser.mapHistoricalScope "quint") (Some IcpScope.Formal) "quint -> formal"
                Expect.equal (Parser.mapHistoricalScope "sil6") (Some IcpScope.Mesh) "sil6 -> mesh"
                Expect.equal (Parser.mapHistoricalScope "otel") (Some IcpScope.Obs) "otel -> obs"
                Expect.equal (Parser.mapHistoricalScope "cockpit") (Some IcpScope.Prajna) "cockpit -> prajna"

            testCase "returns None for unmapped scopes" <| fun _ ->
                Expect.isNone (Parser.mapHistoricalScope "xyzzy") "unknown"
                Expect.isNone (Parser.mapHistoricalScope "foobar") "unknown"
        ]

// ─────────────────────────────────────────────────────────────────────────────
// Analysis Tests
// ─────────────────────────────────────────────────────────────────────────────

module AnalysisTests =

    // Helper to create a minimal ParsedCommit for testing
    let mkCommit style commitType scopes rawScopes hasEmDash subjectLen =
        { Hash = "abc123"
          ShortHash = "abc"
          Author = "test"
          Date = DateTimeOffset(2026, 1, 15, 12, 0, 0, TimeSpan.Zero)
          Subject = String.replicate subjectLen "x"
          Body = ""
          FilesChanged = 3
          Insertions = 10
          Deletions = 5
          Style = style
          CommitType = commitType
          Scopes = scopes
          RawScopes = rawScopes
          HasEmDash = hasEmDash
          SubjectLength = subjectLen
          ContextAfterEmDash = None }

    [<Tests>]
    let shannonEntropyTests =
        testList "GitIntelligence.Analysis.shannonEntropy" [
            testCase "entropy of empty counts is 0" <| fun _ ->
                Expect.equal (Analysis.shannonEntropy [||]) 0.0 "empty"
                Expect.equal (Analysis.shannonEntropy [|0; 0; 0|]) 0.0 "all zeros"

            testCase "entropy of single category is 0" <| fun _ ->
                Expect.equal (Analysis.shannonEntropy [|100|]) 0.0 "one category"
                Expect.equal (Analysis.shannonEntropy [|42; 0; 0|]) 0.0 "one non-zero"

            testCase "uniform distribution has maximum entropy" <| fun _ ->
                let counts = [|10; 10; 10; 10|]
                let h = Analysis.shannonEntropy counts
                let maxH = Analysis.maxEntropy 4
                Expect.floatClose Accuracy.high h maxH "uniform = max entropy"

            testCase "entropy of binary 50/50 is 1 bit" <| fun _ ->
                let h = Analysis.shannonEntropy [|50; 50|]
                Expect.floatClose Accuracy.high h 1.0 "binary 50/50 = 1 bit"

            testCase "skewed distribution has lower entropy" <| fun _ ->
                let uniform = Analysis.shannonEntropy [|25; 25; 25; 25|]
                let skewed = Analysis.shannonEntropy [|90; 5; 3; 2|]
                Expect.isLessThan skewed uniform "skewed < uniform"

            testCase "entropy is non-negative" <| fun _ ->
                // Property: entropy should always be >= 0
                let counts = [|1; 2; 3; 100; 0; 0; 50|]
                let h = Analysis.shannonEntropy counts
                Expect.isGreaterThanOrEqual h 0.0 "non-negative"
        ]

    [<Tests>]
    let maxEntropyTests =
        testList "GitIntelligence.Analysis.maxEntropy" [
            testCase "maxEntropy(1) = 0" <| fun _ ->
                Expect.equal (Analysis.maxEntropy 1) 0.0 "single category"

            testCase "maxEntropy(0) = 0" <| fun _ ->
                Expect.equal (Analysis.maxEntropy 0) 0.0 "zero categories"

            testCase "maxEntropy(2) = 1 bit" <| fun _ ->
                Expect.floatClose Accuracy.high (Analysis.maxEntropy 2) 1.0 "binary"

            testCase "maxEntropy(9) = log2(9) for commit types" <| fun _ ->
                let expected = Math.Log(9.0, 2.0)
                Expect.floatClose Accuracy.high (Analysis.maxEntropy 9) expected "9 types"

            testCase "maxEntropy(24) = log2(24) for scopes" <| fun _ ->
                let expected = Math.Log(24.0, 2.0)
                Expect.floatClose Accuracy.high (Analysis.maxEntropy 24) expected "24 scopes"
        ]

    [<Tests>]
    let styleDistributionTests =
        testList "GitIntelligence.Analysis.computeStyleDistribution" [
            testCase "empty commits returns empty distribution" <| fun _ ->
                let dist = Analysis.computeStyleDistribution [||]
                Expect.isEmpty dist "empty"

            testCase "single style returns 100%" <| fun _ ->
                let commits = [|
                    mkCommit CommitStyle.IcpConventional (Some CommitType.Feat) [] [] true 40
                    mkCommit CommitStyle.IcpConventional (Some CommitType.Fix) [] [] true 35
                |]
                let dist = Analysis.computeStyleDistribution commits
                Expect.equal dist.Length 1 "one style"
                Expect.floatClose Accuracy.medium dist.[0].Percentage 100.0 "100%"

            testCase "percentages sum to 100" <| fun _ ->
                let commits = [|
                    mkCommit CommitStyle.IcpConventional (Some CommitType.Feat) [] [] true 40
                    mkCommit CommitStyle.EvolutionRun None [] [] false 50
                    mkCommit CommitStyle.Other None [] [] false 30
                |]
                let dist = Analysis.computeStyleDistribution commits
                let totalPct = dist |> List.sumBy (fun d -> d.Percentage)
                Expect.floatClose Accuracy.medium totalPct 100.0 "sum to 100%"

            testCase "distribution sorted by count descending" <| fun _ ->
                let commits = [|
                    mkCommit CommitStyle.IcpConventional None [] [] true 40
                    mkCommit CommitStyle.Other None [] [] false 30
                    mkCommit CommitStyle.Other None [] [] false 30
                    mkCommit CommitStyle.Other None [] [] false 30
                |]
                let dist = Analysis.computeStyleDistribution commits
                Expect.equal dist.[0].Style CommitStyle.Other "most frequent first"
                Expect.equal dist.[0].Count 3 "count of 3"
        ]

    [<Tests>]
    let scopeComplianceTests =
        testList "GitIntelligence.Analysis.computeScopeCompliance" [
            testCase "all valid scopes gives 100% compliance" <| fun _ ->
                let commits = [|
                    mkCommit CommitStyle.IcpConventional (Some CommitType.Feat)
                        [IcpScope.Mesh] ["mesh"] true 40
                    mkCommit CommitStyle.IcpConventional (Some CommitType.Fix)
                        [IcpScope.App] ["app"] true 35
                |]
                let sc = Analysis.computeScopeCompliance commits
                Expect.floatClose Accuracy.medium sc.ComplianceRate 100.0 "100% compliance"
                Expect.equal sc.InvalidScopes 0 "no invalid scopes"

            testCase "invalid scopes detected" <| fun _ ->
                let commits = [|
                    mkCommit CommitStyle.IcpConventional None
                        [] ["xyzzy-nonsense"] false 40
                    mkCommit CommitStyle.IcpConventional None
                        [IcpScope.Mesh] ["mesh"] true 35
                |]
                let sc = Analysis.computeScopeCompliance commits
                Expect.isLessThan sc.ComplianceRate 100.0 "below 100%"
                Expect.isGreaterThan sc.InvalidScopes 0 "has invalid scopes"
                Expect.contains sc.InvalidScopesList "xyzzy-nonsense" "xyzzy-nonsense in invalid list"

            testCase "scopeless commits excluded from compliance" <| fun _ ->
                let commits = [|
                    mkCommit CommitStyle.ConventionalNoEmDash (Some CommitType.Docs)
                        [] [] false 30  // no scopes at all
                |]
                let sc = Analysis.computeScopeCompliance commits
                Expect.equal sc.TotalScopedCommits 0 "no scoped commits"
        ]

    [<Tests>]
    let healthScoreTests =
        testList "GitIntelligence.Analysis.computeHealthScore" [
            testCase "empty commits gives zero health" <| fun _ ->
                let sc = { TotalScopedCommits = 0; ValidScopes = 0; InvalidScopes = 0
                           ComplianceRate = 0.0; UniqueScopesUsed = []; InvalidScopesList = [] }
                let hs = Analysis.computeHealthScore [||] sc
                Expect.equal hs.Score 0.0 "zero health"

            testCase "perfect ICP gives high health score" <| fun _ ->
                // Create commits with diverse types and valid scopes
                let commits = [|
                    mkCommit CommitStyle.IcpConventional (Some CommitType.Feat) [IcpScope.Mesh] ["mesh"] true 50
                    mkCommit CommitStyle.IcpConventional (Some CommitType.Fix) [IcpScope.App] ["app"] true 40
                    mkCommit CommitStyle.IcpConventional (Some CommitType.Test) [IcpScope.Test] ["test"] true 45
                    mkCommit CommitStyle.IcpConventional (Some CommitType.Docs) [IcpScope.Sync] ["sync"] true 35
                    mkCommit CommitStyle.IcpConventional (Some CommitType.Refactor) [IcpScope.Zenoh] ["zenoh"] true 42
                |]
                let sc = { TotalScopedCommits = 5; ValidScopes = 5; InvalidScopes = 0
                           ComplianceRate = 100.0; UniqueScopesUsed = ["mesh";"app";"test";"sync";"zenoh"]
                           InvalidScopesList = [] }
                let hs = Analysis.computeHealthScore commits sc
                Expect.isGreaterThan hs.Score 0.5 "health > 0.5 for good commits"
                Expect.equal hs.IcpAdoption 1.0 "100% ICP adoption"
                Expect.equal hs.ScopeCompliance 1.0 "100% scope compliance"

            testCase "health score is between 0 and 1" <| fun _ ->
                let commits = [|
                    mkCommit CommitStyle.EvolutionRun None [] [] false 60
                    mkCommit CommitStyle.Other None [] [] false 40
                |]
                let sc = { TotalScopedCommits = 0; ValidScopes = 0; InvalidScopes = 0
                           ComplianceRate = 0.0; UniqueScopesUsed = []; InvalidScopesList = [] }
                let hs = Analysis.computeHealthScore commits sc
                Expect.isGreaterThanOrEqual hs.Score 0.0 "score >= 0"
                Expect.isLessThanOrEqual hs.Score 1.0 "score <= 1"
        ]

    [<Tests>]
    let fullAnalysisTests =
        testList "GitIntelligence.Analysis.analyze" [
            testCase "analyze empty array produces zero analysis" <| fun _ ->
                let a = Analysis.analyze [||]
                Expect.equal a.TotalCommits 0 "zero commits"
                Expect.isEmpty a.StyleDistribution "no style distribution"
                Expect.isEmpty a.MonthlyBreakdown "no monthly data"
                Expect.equal a.HealthScore.Score 0.0 "zero health"

            testCase "analyze single commit produces correct stats" <| fun _ ->
                let commits = [|
                    mkCommit CommitStyle.IcpConventional (Some CommitType.Feat)
                        [IcpScope.Mesh] ["mesh"] true 45
                |]
                let a = Analysis.analyze commits
                Expect.equal a.TotalCommits 1 "one commit"
                Expect.equal a.StyleDistribution.Length 1 "one style"
                Expect.equal a.MonthlyBreakdown.Length 1 "one month"
                Expect.floatClose Accuracy.medium a.MeanSubjectLength 45.0 "mean length"
                Expect.equal a.MedianSubjectLength 45 "median length"
                Expect.equal a.LongSubjects 0 "no long subjects"

            testCase "long subjects counted correctly" <| fun _ ->
                let commits = [|
                    mkCommit CommitStyle.Other None [] [] false 81  // > 80
                    mkCommit CommitStyle.Other None [] [] false 80  // = 80, not >
                    mkCommit CommitStyle.Other None [] [] false 100 // > 80
                |]
                let a = Analysis.analyze commits
                Expect.equal a.LongSubjects 2 "2 subjects > 80 chars"
        ]

    [<Tests>]
    let jsonOutputTests =
        testList "GitIntelligence.Analysis.analysisToJson" [
            testCase "JSON contains required fields" <| fun _ ->
                let commits = [|
                    mkCommit CommitStyle.IcpConventional (Some CommitType.Feat)
                        [IcpScope.Mesh] ["mesh"] true 45
                |]
                let a = Analysis.analyze commits
                let json = Analysis.analysisToJson a
                Expect.stringContains json "\"totalCommits\":" "has totalCommits"
                Expect.stringContains json "\"healthScore\":" "has healthScore"
                Expect.stringContains json "\"ghs\":" "has GHS"
                Expect.stringContains json "\"styleDistribution\":" "has styleDistribution"
                Expect.stringContains json "\"scopeCompliance\":" "has scopeCompliance"
                Expect.stringContains json "\"monthly\":" "has monthly"

            testCase "JSON is parseable (balanced braces)" <| fun _ ->
                let a = Analysis.analyze [||]
                let json = Analysis.analysisToJson a
                let opens = json |> Seq.filter (fun c -> c = '{' || c = '[') |> Seq.length
                let closes = json |> Seq.filter (fun c -> c = '}' || c = ']') |> Seq.length
                Expect.equal opens closes "balanced braces/brackets"
        ]

// ─────────────────────────────────────────────────────────────────────────────
// Property Tests (FsCheck)
// ─────────────────────────────────────────────────────────────────────────────

module PropertyTests =

    [<Tests>]
    let entropyPropertyTests =
        testList "GitIntelligence.Properties.Entropy" [
            testProperty "entropy is always non-negative" <| fun (counts: int list) ->
                let positiveCounts = counts |> List.map abs |> List.toArray
                Analysis.shannonEntropy positiveCounts >= 0.0

            testProperty "entropy never exceeds log2(N)" <| fun (counts: int list) ->
                let positiveCounts = counts |> List.filter (fun c -> c > 0) |> List.map abs |> List.toArray
                if positiveCounts.Length = 0 then true
                else
                    let h = Analysis.shannonEntropy positiveCounts
                    let maxH = Analysis.maxEntropy positiveCounts.Length
                    h <= maxH + 0.0001  // floating point tolerance

            testProperty "maxEntropy is monotonically increasing" <| fun (n: PositiveInt) ->
                let n = n.Get % 1000  // keep reasonable
                if n >= 2 then
                    Analysis.maxEntropy n <= Analysis.maxEntropy (n + 1)
                else true
        ]

    [<Tests>]
    let typeRoundtripPropertyTests =
        testList "GitIntelligence.Properties.TypeRoundtrip" [
            testProperty "CommitType toTag/fromTag roundtrip is identity" <| fun () ->
                CommitType.all |> Array.forall (fun ct ->
                    CommitType.fromTag (CommitType.toTag ct) = Some ct)

            testProperty "IcpScope toTag/fromTag roundtrip is identity" <| fun () ->
                IcpScope.all |> Array.forall (fun s ->
                    IcpScope.fromTag (IcpScope.toTag s) = Some s)
        ]

    [<Tests>]
    let validationPropertyTests =
        testList "GitIntelligence.Properties.Validation" [
            testProperty "generated messages always pass validation" <| fun () ->
                // Any message we generate should be valid
                let input = {
                    Type = CommitType.Feat
                    Scopes = [IcpScope.Mesh]
                    Action = "add feature"
                    Context = Some "test context"
                    Why = None; What = None
                    FilesCreated = 0; FilesModified = 1
                    Layers = []; StampRefs = []; TaskRef = None
                }
                let msg = Parser.generateMessage input
                let result = Parser.validate msg
                result.IsValid
        ]
