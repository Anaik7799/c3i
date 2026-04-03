// =============================================================================
// Git Intelligence — Safety Tests (Guardian + Constitutional)
// =============================================================================
// Purpose:  Test L8 safety gate (Guardian.fs) and constitutional invariant
//           verification (Constitutional.fs).
//
// STAMP:    SC-SAFETY-001 (Guardian pre-approval), SC-PRIME-001/002 (L6 protection),
//           SC-SAFETY-009 to SC-SAFETY-015 (Psi0-Psi5 invariants)
// =============================================================================

namespace Cepaf.Tests.Unit.GitIntelligence

open System
open Expecto
open Cepaf.GitIntelligence

module SafetyTests =

    // ═══════════════════════════════════════════════════════════════════════
    // Guardian.fs Tests
    // ═══════════════════════════════════════════════════════════════════════

    [<Tests>]
    let guardianTests = testList "Guardian" [

        // ── L6 Artifact Protection ───────────────────────────────────────

        testCase "containsL6Artifacts detects CLAUDE.md" <| fun _ ->
            let result = Guardian.containsL6Artifacts ["src/foo.fs"; "CLAUDE.md"]
            Expect.isTrue result "CLAUDE.md is L6 artifact"

        testCase "containsL6Artifacts detects GEMINI.md" <| fun _ ->
            let result = Guardian.containsL6Artifacts ["GEMINI.md"; "src/bar.fs"]
            Expect.isTrue result "GEMINI.md is L6 artifact"

        testCase "containsL6Artifacts detects verifier.ex" <| fun _ ->
            let result = Guardian.containsL6Artifacts ["lib/indrajaal/prometheus/verifier.ex"]
            Expect.isTrue result "verifier.ex is L6 artifact"

        testCase "containsL6Artifacts detects zenoh_nif" <| fun _ ->
            let result = Guardian.containsL6Artifacts ["native/zenoh_nif/src/lib.rs"]
            Expect.isTrue result "zenoh_nif is L6 artifact"

        testCase "containsL6Artifacts returns false for safe files" <| fun _ ->
            let result = Guardian.containsL6Artifacts ["src/Main.fs"; "lib/utils.ex"; "README.md"]
            Expect.isFalse result "no L6 artifacts in safe files"

        testCase "containsL6Artifacts empty list returns false" <| fun _ ->
            let result = Guardian.containsL6Artifacts []
            Expect.isFalse result "empty list has no L6 artifacts"

        // ── Commit Validation ────────────────────────────────────────────

        testCase "validateCommit approves safe commit" <| fun _ ->
            let proposal = Guardian.createCommitProposal ["src/Types.fs"; "src/Parser.fs"] "test-author"
            let result = Guardian.validateCommit proposal
            match result with
            | Guardian.ApprovalResult.Approved _ -> ()
            | other -> failwithf "Expected Approved, got %A" other

        testCase "validateCommit vetoes L6 artifact modification" <| fun _ ->
            let proposal = Guardian.createCommitProposal ["src/Types.fs"; "CLAUDE.md"] "test-author"
            let result = Guardian.validateCommit proposal
            match result with
            | Guardian.ApprovalResult.Vetoed reason ->
                Expect.stringContains reason "L6" "veto mentions L6"
            | other -> failwithf "Expected Vetoed, got %A" other

        // ── Branch Operation Validation ──────────────────────────────────

        testCase "validateBranchOp approves safe branch operation" <| fun _ ->
            let result = Guardian.validateBranchOp "branch-delete" "feature/my-branch"
            match result with
            | Guardian.ApprovalResult.Approved _ -> ()
            | other -> failwithf "Expected Approved, got %A" other

        testCase "validateBranchOp vetoes force-push to main" <| fun _ ->
            let result = Guardian.validateBranchOp "force-push" "main"
            match result with
            | Guardian.ApprovalResult.Vetoed reason ->
                Expect.stringContains reason "main" "veto mentions main"
            | other -> failwithf "Expected Vetoed, got %A" other

        testCase "validateBranchOp vetoes rebase on master" <| fun _ ->
            let result = Guardian.validateBranchOp "rebase" "master"
            match result with
            | Guardian.ApprovalResult.Vetoed _ -> ()
            | other -> failwithf "Expected Vetoed for rebase on master, got %A" other

        testCase "validateBranchOp vetoes reset-hard on production" <| fun _ ->
            let result = Guardian.validateBranchOp "reset-hard" "production"
            match result with
            | Guardian.ApprovalResult.Vetoed _ -> ()
            | other -> failwithf "Expected Vetoed for reset-hard on production, got %A" other

        // ── Proposal Dispatch ────────────────────────────────────────────

        testCase "validateProposal dispatches commit type" <| fun _ ->
            let proposal = Guardian.createCommitProposal ["src/Types.fs"] "author"
            let result = Guardian.validateProposal proposal
            match result with
            | Guardian.ApprovalResult.Approved _ -> ()
            | other -> failwithf "Expected Approved for safe commit proposal, got %A" other

        testCase "validateProposal dispatches force-push type" <| fun _ ->
            let proposal = Guardian.createBranchProposal "force-push" "main" "author"
            let result = Guardian.validateProposal proposal
            match result with
            | Guardian.ApprovalResult.Vetoed _ -> ()
            | other -> failwithf "Expected Vetoed for force-push on main, got %A" other

        testCase "validateProposal approves unknown operation type" <| fun _ ->
            let proposal = Guardian.createBranchProposal "custom-op" "feature" "test"
            let result = Guardian.validateProposal proposal
            match result with
            | Guardian.ApprovalResult.Approved _ -> ()
            | other -> failwithf "Expected Approved for unknown op type, got %A" other

        // ── wrapWithGuardian ─────────────────────────────────────────────

        testCase "wrapWithGuardian executes action on approval" <| fun _ ->
            let mutable executed = false
            let proposal = Guardian.createCommitProposal ["src/safe.fs"] "author"
            let result = Guardian.wrapWithGuardian proposal (fun () -> executed <- true; Ok "done")
            Expect.isTrue executed "action was executed"
            Expect.isOk result "result is Ok"

        testCase "wrapWithGuardian blocks action on veto" <| fun _ ->
            let mutable executed = false
            let proposal = Guardian.createCommitProposal ["CLAUDE.md"] "author"
            let result = Guardian.wrapWithGuardian proposal (fun () -> executed <- true; Ok "done")
            Expect.isFalse executed "action was not executed"
            match result with
            | Error msg -> Expect.stringContains msg "VETO" "error mentions veto"
            | Ok _ -> failwith "Expected Error for vetoed proposal"
    ]

    // ═══════════════════════════════════════════════════════════════════════
    // Constitutional.fs Tests
    // ═══════════════════════════════════════════════════════════════════════

    [<Tests>]
    let constitutionalTests = testList "Constitutional" [

        // ── Psi0 Existence ─────────────────────────────────────────────────

        testCase "verifyExistence passes for recent active repo" <| fun _ ->
            let check = Constitutional.verifyExistence (TimeSpan.FromDays(1.0)) 100
            Expect.isTrue check.Passed "recent repo passes"
            Expect.isGreaterThan check.Score 0.5 "score is high"
            Expect.equal check.InvariantId "Psi0" "invariant ID is Psi0"

        testCase "verifyExistence fails for stagnant repo" <| fun _ ->
            let check = Constitutional.verifyExistence (TimeSpan.FromDays(60.0)) 0
            Expect.isFalse check.Passed "stagnant repo fails"
            Expect.isLessThan check.Score 0.3 "score is low"

        testCase "verifyExistence degrades with age" <| fun _ ->
            let recent = Constitutional.verifyExistence (TimeSpan.FromDays(1.0)) 50
            let older = Constitutional.verifyExistence (TimeSpan.FromDays(20.0)) 50
            Expect.isGreaterThan recent.Score older.Score "recent scores higher"

        // ── Psi1 Regeneration ──────────────────────────────────────────────

        testCase "verifyRegeneration full when both DBs exist" <| fun _ ->
            let check = Constitutional.verifyRegeneration true true
            Expect.isTrue check.Passed "both DBs passes"
            Expect.floatClose Accuracy.medium check.Score 1.0 "perfect score"

        testCase "verifyRegeneration partial with only SQLite" <| fun _ ->
            let check = Constitutional.verifyRegeneration true false
            Expect.isTrue check.Passed "SQLite only passes (0.6 >= 0.5)"
            Expect.floatClose Accuracy.medium check.Score 0.6 "partial score"

        testCase "verifyRegeneration fails with no DBs" <| fun _ ->
            let check = Constitutional.verifyRegeneration false false
            Expect.isFalse check.Passed "no DBs fails"
            Expect.floatClose Accuracy.medium check.Score 0.0 "zero score"

        // ── Psi2 History ───────────────────────────────────────────────────

        testCase "verifyHistory passes with events" <| fun _ ->
            let check = Constitutional.verifyHistory 100 (Some (DateTimeOffset.UtcNow.AddDays(-30.0)))
            Expect.isTrue check.Passed "history with events passes"
            Expect.floatClose Accuracy.medium check.Score 1.0 "perfect score"

        testCase "verifyHistory fails with no events" <| fun _ ->
            let check = Constitutional.verifyHistory 0 None
            Expect.isFalse check.Passed "no events fails"
            Expect.floatClose Accuracy.medium check.Score 0.0 "zero score"

        // ── Psi3 Verification ──────────────────────────────────────────────

        testCase "verifyVerification passes with valid GHS" <| fun _ ->
            let check = Constitutional.verifyVerification true (Some 0.85)
            Expect.isTrue check.Passed "valid GHS passes"
            Expect.floatClose Accuracy.medium check.Score 1.0 "perfect score"

        testCase "verifyVerification partial with out-of-range GHS" <| fun _ ->
            let check = Constitutional.verifyVerification true (Some 1.5)
            Expect.isTrue check.Passed "out-of-range GHS still passes (0.5 >= 0.5)"
            Expect.floatClose Accuracy.medium check.Score 0.5 "partial score"

        testCase "verifyVerification fails when not computable" <| fun _ ->
            let check = Constitutional.verifyVerification false None
            Expect.isFalse check.Passed "non-computable fails"
            Expect.floatClose Accuracy.medium check.Score 0.0 "zero score"

        // ── Psi4 Alignment ─────────────────────────────────────────────────

        testCase "verifyAlignment passes with high ICP adoption" <| fun _ ->
            let check = Constitutional.verifyAlignment 80.0
            Expect.isTrue check.Passed "high adoption passes"
            Expect.isGreaterThan check.Score 0.5 "score above 0.5"

        testCase "verifyAlignment fails with zero adoption" <| fun _ ->
            let check = Constitutional.verifyAlignment 0.0
            Expect.isFalse check.Passed "zero adoption fails"
            Expect.floatClose Accuracy.medium check.Score 0.0 "zero score"

        // ── Psi5 Truthfulness ──────────────────────────────────────────────

        testCase "verifyTruthfulness passes with high density" <| fun _ ->
            let check = Constitutional.verifyTruthfulness 0.4
            Expect.isTrue check.Passed "high density passes"
            Expect.isGreaterThan check.Score 0.5 "score above 0.5"

        testCase "verifyTruthfulness fails with zero density" <| fun _ ->
            let check = Constitutional.verifyTruthfulness 0.0
            Expect.isFalse check.Passed "zero density fails"
            Expect.floatClose Accuracy.medium check.Score 0.0 "zero score"

        // ── Composite Functions ──────────────────────────────────────────

        testCase "verifyAll returns 6 checks" <| fun _ ->
            let checks = Constitutional.verifyAll
                            (TimeSpan.FromDays(1.0)) 100
                            true true
                            50 (Some (DateTimeOffset.UtcNow.AddDays(-10.0)))
                            true (Some 0.85)
                            80.0
                            0.4
            Expect.equal (List.length checks) 6 "returns 6 invariant checks"

        testCase "computeSafetyScore produces valid range" <| fun _ ->
            let checks = Constitutional.verifyAll
                            (TimeSpan.FromDays(1.0)) 100
                            true true
                            50 (Some (DateTimeOffset.UtcNow.AddDays(-10.0)))
                            true (Some 0.85)
                            80.0
                            0.4
            let score = Constitutional.computeSafetyScore checks
            Expect.isGreaterThanOrEqual score 0.0 "score >= 0"
            Expect.isLessThanOrEqual score 1.0 "score <= 1"

        testCase "computeSafetyScore returns 0 for wrong-length list" <| fun _ ->
            let score = Constitutional.computeSafetyScore []
            Expect.floatClose Accuracy.medium score 0.0 "empty list gives 0"

        testCase "hasCriticalViolation detects failed check" <| fun _ ->
            let checks = Constitutional.verifyAll
                            (TimeSpan.FromDays(60.0)) 0  // Psi0 fails
                            false false                   // Psi1 fails
                            0 None                        // Psi2 fails
                            false None                    // Psi3 fails
                            0.0                           // Psi4 fails
                            0.0                           // Psi5 fails
            let hasCritical = Constitutional.hasCriticalViolation checks
            Expect.isTrue hasCritical "all-failing has critical violations"

        testCase "hasCriticalViolation is false when all pass" <| fun _ ->
            let checks = Constitutional.verifyAll
                            (TimeSpan.FromDays(1.0)) 100
                            true true
                            50 (Some (DateTimeOffset.UtcNow.AddDays(-10.0)))
                            true (Some 0.85)
                            80.0
                            0.4
            let hasCritical = Constitutional.hasCriticalViolation checks
            Expect.isFalse hasCritical "all-passing has no critical violations"

        testCase "verifyNoForbiddenModification passes for safe files" <| fun _ ->
            let check = Constitutional.verifyNoForbiddenModification ["src/Main.fs"; "lib/utils.ex"]
            Expect.isTrue check.Passed "safe files pass"
            Expect.floatClose Accuracy.medium check.Score 1.0 "perfect score"

        testCase "verifyNoForbiddenModification fails for L6 artifacts" <| fun _ ->
            let check = Constitutional.verifyNoForbiddenModification ["src/Main.fs"; "CLAUDE.md"]
            Expect.isFalse check.Passed "L6 artifact fails"
            Expect.floatClose Accuracy.medium check.Score 0.0 "zero score"

        testCase "formatDashboard produces non-empty string" <| fun _ ->
            let checks = Constitutional.verifyAll
                            (TimeSpan.FromDays(1.0)) 100
                            true true
                            50 (Some (DateTimeOffset.UtcNow.AddDays(-10.0)))
                            true (Some 0.85)
                            80.0
                            0.4
            let dashboard = Constitutional.formatDashboard checks
            Expect.isNotEmpty dashboard "dashboard is non-empty"
            Expect.stringContains dashboard "CONSTITUTIONAL" "dashboard has header"
    ]

    // ═══════════════════════════════════════════════════════════════════════
    // Combined export
    // ═══════════════════════════════════════════════════════════════════════

    [<Tests>]
    let tests = testList "Safety" [
        guardianTests
        constitutionalTests
    ]
