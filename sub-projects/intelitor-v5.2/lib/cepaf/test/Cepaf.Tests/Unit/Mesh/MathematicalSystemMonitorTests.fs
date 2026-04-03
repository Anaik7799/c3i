// =============================================================================
// MathematicalSystemMonitorTests.fs - Tests for Mathematical System Monitor
// =============================================================================
// STAMP: SC-TEST-001 (TDG compliance), SC-AI-003 (IA factor), SC-FUNC-001
// AOR: AOR-IMMUNE-001, AOR-REG-002, AOR-HOLON-014
//
// ## Test Coverage
// - MathDisciplineRegistry: 17 disciplines, levels, maturity, RPN, active layers
// - MathInteractionMatrix: 18 interactions, strength, coupling scores
// - MathHealthAssessor: health scoring, discipline/system assessment
// - MathSystemMonitor: integration (publishing, dashboard)
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 1.1.0 |
// | Created | 2026-03-19 |
// | Updated | 2026-03-20 (Sprint 52: update tests to reflect post-fix maturity/gaps) |
// | Author | Claude Opus 4.6 |
// | STAMP | SC-TEST-001, SC-AI-003, SC-FUNC-001 |
// =============================================================================

module Cepaf.Tests.Unit.Mesh.MathematicalSystemMonitorTests

open Expecto
open Cepaf.Mesh

[<Tests>]
let tests = testList "MathematicalSystemMonitor" [

    // =========================================================================
    // MathDisciplineRegistry Tests
    // =========================================================================
    testList "MathDisciplineRegistry" [

        test "allDisciplines contains exactly 17 entries" {
            Expect.equal
                (List.length MathDisciplineRegistry.allDisciplines)
                17
                "Should have exactly 17 mathematical disciplines"
        }

        test "allDisciplines contains no duplicates" {
            let distinct =
                MathDisciplineRegistry.allDisciplines
                |> List.distinct
            Expect.equal
                (List.length distinct)
                (List.length MathDisciplineRegistry.allDisciplines)
                "All disciplines should be unique"
        }

        test "levelOf returns a valid level for every discipline" {
            for d in MathDisciplineRegistry.allDisciplines do
                let level = MathDisciplineRegistry.levelOf d
                let validLevels = [
                    MathLevel.L1_Concrete
                    MathLevel.L2_Algorithmic
                    MathLevel.L3_Systems
                    MathLevel.L4_Formal
                    MathLevel.L5_Meta
                ]
                Expect.isTrue
                    (List.contains level validLevels)
                    (sprintf "Discipline %A should have a valid level, got %A" d level)
        }

        test "currentMaturity returns a valid maturity for every discipline" {
            for d in MathDisciplineRegistry.allDisciplines do
                let maturity = MathDisciplineRegistry.currentMaturity d
                let validMaturities = [
                    MathMaturity.Production
                    MathMaturity.Partial
                    MathMaturity.Isolated
                    MathMaturity.Stub
                    MathMaturity.NotApplicable
                ]
                Expect.isTrue
                    (List.contains maturity validMaturities)
                    (sprintf "Discipline %A should have a valid maturity, got %A" d maturity)
        }

        test "baselineRPN returns value for every discipline without throwing" {
            for d in MathDisciplineRegistry.allDisciplines do
                let rpn = MathDisciplineRegistry.baselineRPN d
                Expect.isGreaterThanOrEqual rpn 0
                    (sprintf "Discipline %A should have non-negative RPN" d)
        }

        test "RPN values are within valid FMEA range 0-1000" {
            for d in MathDisciplineRegistry.allDisciplines do
                let rpn = MathDisciplineRegistry.baselineRPN d
                Expect.isTrue
                    (rpn >= 0 && rpn <= 1000)
                    (sprintf "Discipline %A RPN=%d should be in [0, 1000]" d rpn)
        }

        test "activeLayers returns non-empty list for all disciplines" {
            for d in MathDisciplineRegistry.allDisciplines do
                let layers = MathDisciplineRegistry.activeLayers d
                Expect.isNonEmpty layers
                    (sprintf "Discipline %A should have at least one active layer" d)
        }

        test "elixirModulePath returns non-empty string for every discipline" {
            for d in MathDisciplineRegistry.allDisciplines do
                let path = MathDisciplineRegistry.elixirModulePath d
                Expect.isNotEmpty path
                    (sprintf "Discipline %A should have a non-empty Elixir module path" d)
                Expect.isTrue
                    (path.EndsWith(".ex"))
                    (sprintf "Discipline %A path should end with .ex, got %s" d path)
        }

        test "L1_Concrete has exactly 3 disciplines" {
            let l1 =
                MathDisciplineRegistry.allDisciplines
                |> List.filter (fun d -> MathDisciplineRegistry.levelOf d = MathLevel.L1_Concrete)
            Expect.equal (List.length l1) 3 "L1_Concrete should have 3 disciplines"
        }

        test "L2_Algorithmic has exactly 4 disciplines" {
            let l2 =
                MathDisciplineRegistry.allDisciplines
                |> List.filter (fun d -> MathDisciplineRegistry.levelOf d = MathLevel.L2_Algorithmic)
            Expect.equal (List.length l2) 4 "L2_Algorithmic should have 4 disciplines"
        }

        test "L3_Systems has exactly 6 disciplines" {
            let l3 =
                MathDisciplineRegistry.allDisciplines
                |> List.filter (fun d -> MathDisciplineRegistry.levelOf d = MathLevel.L3_Systems)
            Expect.equal (List.length l3) 6 "L3_Systems should have 6 disciplines"
        }

        test "FPPSValidation has highest RPN of 40 (post-Sprint-54)" {
            // Sprint 54 morphogenesis reduced all RPNs. FPPSValidation is now the highest at 40.
            let rpn = MathDisciplineRegistry.baselineRPN MathDiscipline.FPPSValidation
            Expect.equal rpn 40 "FPPSValidation should have highest RPN of 40"
        }

        test "AES256GCM has lowest RPN of 12" {
            let rpn = MathDisciplineRegistry.baselineRPN MathDiscipline.AES256GCM
            Expect.equal rpn 12 "AES256GCM should have lowest RPN of 12"
        }

        test "knownGaps for ReedSolomon are P3 residuals (Sprint 52 fixed P0/P1)" {
            // Sprint 52 resolved the Forney multi-error and erasure decoding P0/P1 gaps.
            // Remaining gaps are P3 (integration tests, benchmarks).
            let gaps = MathDisciplineRegistry.knownGaps MathDiscipline.ReedSolomon
            Expect.isNonEmpty gaps "ReedSolomon should still have residual P3 gaps"
            let hasP0 = gaps |> List.exists (fun g -> g.StartsWith("P0:"))
            Expect.isFalse hasP0 "ReedSolomon should have no remaining P0 gaps after Sprint 52"
            let hasP3 = gaps |> List.exists (fun g -> g.StartsWith("P3:"))
            Expect.isTrue hasP3 "ReedSolomon should have P3 residual gaps"
        }

        test "knownGaps for CryptoPrimitives is empty (Production)" {
            let gaps = MathDisciplineRegistry.knownGaps MathDiscipline.CryptoPrimitives
            Expect.isEmpty gaps "Production CryptoPrimitives should have no known gaps"
        }

        test "CryptoPrimitives maturity is Production" {
            let maturity = MathDisciplineRegistry.currentMaturity MathDiscipline.CryptoPrimitives
            Expect.equal maturity MathMaturity.Production
                "CryptoPrimitives should be Production maturity"
        }

        test "Homeostasis maturity is Production after Sprint 52" {
            // Sprint 52 implemented a full GenServer PID controller (515 lines),
            // replacing the previous 34-line stub.
            let maturity = MathDisciplineRegistry.currentMaturity MathDiscipline.Homeostasis
            Expect.equal maturity MathMaturity.Production
                "Homeostasis should be Production maturity after Sprint 52 PID implementation"
        }
    ]

    // =========================================================================
    // MathInteractionMatrix Tests
    // =========================================================================
    testList "MathInteractionMatrix" [

        test "interactions has at least 15 entries" {
            Expect.isGreaterThanOrEqual
                (List.length MathInteractionMatrix.interactions)
                15
                "Should have at least 15 discipline interactions"
        }

        test "interactions has exactly 18 entries" {
            Expect.equal
                (List.length MathInteractionMatrix.interactions)
                18
                "Should have exactly 18 discipline interactions"
        }

        test "all interactions have strength between 0.0 and 1.0" {
            for i in MathInteractionMatrix.interactions do
                Expect.isTrue
                    (i.Strength >= 0.0 && i.Strength <= 1.0)
                    (sprintf "Interaction %A -> %A strength %.2f should be in [0.0, 1.0]"
                        i.From i.To i.Strength)
        }

        test "all interactions have non-empty InteractionType" {
            for i in MathInteractionMatrix.interactions do
                Expect.isNotEmpty i.InteractionType
                    (sprintf "Interaction %A -> %A should have non-empty type" i.From i.To)
        }

        test "interactionsFor CryptoPrimitives returns non-empty (high coupling)" {
            let related = MathInteractionMatrix.interactionsFor MathDiscipline.CryptoPrimitives
            Expect.isNonEmpty related
                "CryptoPrimitives should have interactions (it is highly coupled)"
        }

        test "interactionsFor CryptoPrimitives has at least 3 interactions" {
            let related = MathInteractionMatrix.interactionsFor MathDiscipline.CryptoPrimitives
            Expect.isGreaterThanOrEqual
                (List.length related) 3
                "CryptoPrimitives should have >= 3 interactions"
        }

        test "couplingScore returns value between 0.0 and 1.0" {
            for d in MathDisciplineRegistry.allDisciplines do
                let score = MathInteractionMatrix.couplingScore d
                Expect.isTrue
                    (score >= 0.0 && score <= 1.0)
                    (sprintf "Coupling score for %A should be in [0.0, 1.0], got %.3f" d score)
        }

        test "couplingScore for CryptoPrimitives is high (>= 0.5)" {
            let score = MathInteractionMatrix.couplingScore MathDiscipline.CryptoPrimitives
            Expect.isGreaterThanOrEqual score 0.5
                "CryptoPrimitives should have high coupling score"
        }

        test "all interaction From disciplines are valid" {
            let allDisciplines = Set.ofList MathDisciplineRegistry.allDisciplines
            for i in MathInteractionMatrix.interactions do
                Expect.isTrue
                    (Set.contains i.From allDisciplines)
                    (sprintf "From discipline %A should be in allDisciplines" i.From)
        }

        test "all interaction To disciplines are valid" {
            let allDisciplines = Set.ofList MathDisciplineRegistry.allDisciplines
            for i in MathInteractionMatrix.interactions do
                Expect.isTrue
                    (Set.contains i.To allDisciplines)
                    (sprintf "To discipline %A should be in allDisciplines" i.To)
        }

        test "no self-interactions in matrix" {
            for i in MathInteractionMatrix.interactions do
                Expect.notEqual i.From i.To
                    (sprintf "Interaction should not be self-referencing: %A" i.From)
        }
    ]

    // =========================================================================
    // MathHealthAssessor Tests
    // =========================================================================
    testList "MathHealthAssessor" [

        test "assessDiscipline returns valid health record" {
            let health = MathHealthAssessor.assessDiscipline MathDiscipline.CryptoPrimitives
            Expect.equal health.Discipline MathDiscipline.CryptoPrimitives
                "Discipline should match input"
            Expect.equal health.Level MathLevel.L1_Concrete
                "Level should be L1_Concrete"
            Expect.isTrue
                (health.HealthScore >= 0.0 && health.HealthScore <= 1.0)
                "Health score should be in [0.0, 1.0]"
        }

        test "Production maturity gives health score >= 0.7" {
            // CryptoPrimitives is Production with low RPN (16) and no gaps
            let health = MathHealthAssessor.assessDiscipline MathDiscipline.CryptoPrimitives
            Expect.isGreaterThanOrEqual health.HealthScore 0.7
                "Production maturity with low RPN should give score >= 0.7"
        }

        test "Production maturity with no gaps gives score >= 0.8" {
            // AES256GCM: Production, RPN=12, no gaps
            let health = MathHealthAssessor.assessDiscipline MathDiscipline.AES256GCM
            Expect.isGreaterThanOrEqual health.HealthScore 0.8
                "Production maturity with no gaps and low RPN should give score >= 0.8"
        }

        test "All disciplines at Production have health score >= 0.7 (post-Sprint-54)" {
            // Sprint 54 morphogenesis promoted ALL 17 disciplines to Production maturity.
            // With Production base (0.90) and RPNs in range [12..40], all should score >= 0.7.
            for d in MathDisciplineRegistry.allDisciplines do
                let health = MathHealthAssessor.assessDiscipline d
                Expect.isGreaterThanOrEqual health.HealthScore 0.7
                    (sprintf "Production discipline %A should have health >= 0.7, got %.3f" d health.HealthScore)
        }

        test "Higher RPN gives lower health score than lower RPN (penalty works)" {
            // FPPSValidation (RPN=40) should have lower health than AES256GCM (RPN=12)
            // Both are Production maturity, so the RPN penalty is the differentiator.
            let highRpn = MathHealthAssessor.assessDiscipline MathDiscipline.FPPSValidation
            let lowRpn = MathHealthAssessor.assessDiscipline MathDiscipline.AES256GCM
            Expect.isLessThan highRpn.HealthScore lowRpn.HealthScore
                (sprintf "FPPSValidation (RPN=40, score=%.3f) should score lower than AES256GCM (RPN=12, score=%.3f)"
                    highRpn.HealthScore lowRpn.HealthScore)
        }

        test "assessDiscipline populates RPN from registry" {
            let health = MathHealthAssessor.assessDiscipline MathDiscipline.PetriNets
            Expect.equal health.RPN 18 "RPN should match registry baseline (18 post-Sprint-54)"
        }

        test "assessDiscipline populates gaps from registry" {
            let health = MathHealthAssessor.assessDiscipline MathDiscipline.ReedSolomon
            Expect.isNonEmpty health.Gaps "ReedSolomon should have gaps populated"
        }

        test "assessDiscipline populates active layers from registry" {
            let health = MathHealthAssessor.assessDiscipline MathDiscipline.ConstitutionalInvariants
            Expect.isNonEmpty health.ActiveLayers
                "ConstitutionalInvariants should have active layers"
            Expect.isTrue
                (health.ActiveLayers |> List.contains FractalLayer.L0_Runtime)
                "ConstitutionalInvariants should be active at L0_Runtime"
        }

        test "assessSystem returns 17 discipline assessments" {
            let system = MathHealthAssessor.assessSystem ()
            Expect.equal
                (List.length system.Disciplines) 17
                "System assessment should contain 17 disciplines"
        }

        test "assessSystem overall score is between 0.0 and 1.0" {
            let system = MathHealthAssessor.assessSystem ()
            Expect.isTrue
                (system.OverallScore >= 0.0 && system.OverallScore <= 1.0)
                (sprintf "Overall score should be in [0.0, 1.0], got %.3f" system.OverallScore)
        }

        test "assessSystem MaturityDistribution has at least 1 category (all Production post-Sprint-54)" {
            let system = MathHealthAssessor.assessSystem ()
            Expect.isGreaterThanOrEqual
                (Map.count system.MaturityDistribution) 1
                "Maturity distribution should have at least 1 category"
        }

        test "assessSystem MaturityDistribution sums to 17" {
            let system = MathHealthAssessor.assessSystem ()
            let total = system.MaturityDistribution |> Map.toList |> List.sumBy snd
            Expect.equal total 17
                "Maturity distribution should sum to 17 disciplines"
        }

        test "assessSystem CriticalDisciplines is empty post-Sprint-54 (all RPNs < 100)" {
            // Sprint 54 morphogenesis reduced ALL RPNs to range [12..40].
            // CriticalDisciplines = disciplines with RPN > 100, so now empty.
            let system = MathHealthAssessor.assessSystem ()
            Expect.isEmpty system.CriticalDisciplines
                "CriticalDisciplines should be empty — all RPNs are now < 100 after Sprint 54"
        }

        test "assessSystem no discipline has RPN > 100 post-Sprint-54" {
            let system = MathHealthAssessor.assessSystem ()
            for d in system.Disciplines do
                Expect.isLessThanOrEqual d.RPN 100
                    (sprintf "Discipline %A has RPN %d which should be <= 100 post-Sprint-54" d.Discipline d.RPN)
        }

        test "assessSystem AES256GCM has lowest RPN of 12" {
            let system = MathHealthAssessor.assessSystem ()
            let aes = system.Disciplines |> List.find (fun d -> d.Discipline = MathDiscipline.AES256GCM)
            Expect.equal aes.RPN 12 "AES256GCM should have RPN 12"
        }

        test "assessSystem Interactions is populated" {
            let system = MathHealthAssessor.assessSystem ()
            Expect.isNonEmpty system.Interactions
                "System assessment should include interactions"
            Expect.equal
                (List.length system.Interactions)
                (List.length MathInteractionMatrix.interactions)
                "Interactions should match matrix"
        }

        test "assessSystem CriticalRiskTotal sums RPNs above 50" {
            let system = MathHealthAssessor.assessSystem ()
            let expectedRisk =
                MathDisciplineRegistry.allDisciplines
                |> List.map MathDisciplineRegistry.baselineRPN
                |> List.filter (fun rpn -> rpn > 50)
                |> List.sum
            Expect.equal system.CriticalRiskTotal expectedRisk
                "CriticalRiskTotal should equal sum of RPNs > 50"
        }

        test "assessSystem has a recent timestamp" {
            let system = MathHealthAssessor.assessSystem ()
            let age = System.DateTimeOffset.UtcNow - system.Timestamp
            Expect.isTrue
                (age.TotalSeconds < 10.0)
                "System assessment timestamp should be recent (< 10 seconds)"
        }

        test "assessSystem FormalProofCoverage is between 0.0 and 100.0" {
            let system = MathHealthAssessor.assessSystem ()
            Expect.isTrue
                (system.FormalProofCoverage >= 0.0 && system.FormalProofCoverage <= 100.0)
                (sprintf "FormalProofCoverage should be in [0.0, 100.0], got %.1f"
                    system.FormalProofCoverage)
        }
    ]

    // =========================================================================
    // MathSystemMonitor Integration Tests
    // =========================================================================
    testList "MathSystemMonitor" [

        test "interactionMatrix returns the full matrix" {
            let matrix = MathSystemMonitor.interactionMatrix ()
            Expect.equal
                (List.length matrix)
                (List.length MathInteractionMatrix.interactions)
                "interactionMatrix should return all interactions"
        }

        test "disciplineHealth returns valid record for any discipline" {
            let health = MathSystemMonitor.disciplineHealth MathDiscipline.OODA
            Expect.equal health.Discipline MathDiscipline.OODA
                "disciplineHealth should return correct discipline"
            Expect.equal health.Maturity MathMaturity.Production
                "OODA should have Production maturity"
        }
    ]
]
