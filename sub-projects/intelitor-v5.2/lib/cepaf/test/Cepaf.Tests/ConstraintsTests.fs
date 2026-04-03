module ConstraintsTests

open System
open Expecto
open FsCheck
open FsCheck.FSharp
open Cepaf

/// TDG: Property-based tests for Safety Constraints (STAMP compliance)
/// Reference: GEMINI.md Section 5.0 - Unified Safety Constraints
module Properties =

    /// All constraint IDs must follow the SC-XXX-NNN pattern
    let constraintIdFormat (constraint': SafetyConstraint) =
        let pattern = System.Text.RegularExpressions.Regex(@"^SC-[A-Z]{2,4}-\d{3}$")
        pattern.IsMatch(constraint'.Id)

    /// Constraint categories must be non-empty
    let constraintCategoryNonEmpty (constraint': SafetyConstraint) =
        not (String.IsNullOrWhiteSpace constraint'.Category)

    /// Compliance status transitions are valid
    let complianceTransitionValid (before: bool option) (after: bool option) =
        match before, after with
        | None, Some _ -> true      // Pending to verified
        | Some true, Some false -> true  // Regression (flagged)
        | Some false, Some true -> true  // Fixed
        | Some x, Some y -> x = y   // No change
        | _, None -> false          // Cannot go back to unknown

/// Unit tests for safety constraint types and validation
[<Tests>]
let constraintTypeTests =
    testList "Safety Constraint Types" [
        testCase "SafetyConstraint can be created with all fields" <| fun _ ->
            let constraint' = {
                Id = "SC-VAL-001"
                Category = "Validation"
                Description = "Patient Mode must be enabled for validation"
                Compliance = Some true
            }
            Expect.equal constraint'.Id "SC-VAL-001" "ID should match"
            Expect.equal constraint'.Category "Validation" "Category should match"
            Expect.isSome constraint'.Compliance "Compliance should be set"

        testCase "SafetyConstraint compliance can be None (pending)" <| fun _ ->
            let constraint' = {
                Id = "SC-CNT-009"
                Category = "Container"
                Description = "NixOS/Podman only"
                Compliance = None
            }
            Expect.isNone constraint'.Compliance "Pending constraint should have None compliance"

        testCase "SafetyConstraint compliance can be false (failed)" <| fun _ ->
            let constraint' = {
                Id = "SC-CMP-025"
                Category = "Compilation"
                Description = "Zero warnings required"
                Compliance = Some false
            }
            Expect.equal constraint'.Compliance (Some false) "Failed constraint should be Some false"
    ]

/// Tests for STAMP constraint categories from GEMINI.md Section 5.0
[<Tests>]
let stampCategoryTests =
    testList "STAMP Constraint Categories" [
        testCase "SC-VAL constraints are for Validation" <| fun _ ->
            let constraints = [
                { Id = "SC-VAL-001"; Category = "Validation"; Description = "Patient Mode only"; Compliance = Some true }
                { Id = "SC-VAL-002"; Category = "Validation"; Description = "Analyze complete logs"; Compliance = Some true }
                { Id = "SC-VAL-003"; Category = "Validation"; Description = "100% consensus"; Compliance = None }
            ]
            Expect.all constraints (fun c -> c.Category = "Validation") "All SC-VAL should be Validation category"

        testCase "SC-CNT constraints are for Container" <| fun _ ->
            let constraints = [
                { Id = "SC-CNT-009"; Category = "Container"; Description = "NixOS/Podman only"; Compliance = Some true }
                { Id = "SC-CNT-010"; Category = "Container"; Description = "Localhost registry"; Compliance = Some true }
                { Id = "SC-CNT-012"; Category = "Container"; Description = "Rootless mode"; Compliance = Some true }
            ]
            Expect.all constraints (fun c -> c.Category = "Container") "All SC-CNT should be Container category"

        testCase "SC-AGT constraints are for Agents" <| fun _ ->
            let constraints = [
                { Id = "SC-AGT-017"; Category = "Agent"; Description = "Efficiency >90%"; Compliance = None }
                { Id = "SC-AGT-018"; Category = "Agent"; Description = "No deadlocks"; Compliance = Some true }
                { Id = "SC-AGT-019"; Category = "Agent"; Description = "Exec Authority"; Compliance = Some true }
            ]
            Expect.all constraints (fun c -> c.Category = "Agent") "All SC-AGT should be Agent category"

        testCase "SC-PRF constraints are for Performance" <| fun _ ->
            let constraint' = { Id = "SC-PRF-055"; Category = "Performance"; Description = "No blocking ops"; Compliance = Some true }
            Expect.equal constraint'.Category "Performance" "SC-PRF should be Performance"
    ]

/// Tests for AppError.SafetyViolation handling
[<Tests>]
let safetyViolationTests =
    testList "SafetyViolation Error Handling" [
        testCase "SafetyViolation captures constraint ID and reason" <| fun _ ->
            let error = SafetyViolation("SC-CMP-025", "Found 3 warnings")
            match error with
            | SafetyViolation (id, reason) ->
                Expect.equal id "SC-CMP-025" "Constraint ID should match"
                Expect.equal reason "Found 3 warnings" "Reason should match"
            | _ -> failtest "Should be SafetyViolation"

        testCase "SafetyViolation for AOR-QUA-001 zero warnings" <| fun _ ->
            let error = SafetyViolation("AOR-QUA-001", "Protocol completed with 5 warnings")
            match error with
            | SafetyViolation (id, _) ->
                Expect.stringStarts id "AOR" "AOR violations use same SafetyViolation type"
            | _ -> failtest "Should be SafetyViolation"

        testCase "Different error types are distinguishable" <| fun _ ->
            let errors = [
                SafetyViolation("SC-VAL-001", "Patient mode disabled")
                ProcessError("mix", 1, "compilation failed")
                BootMandateViolation(45000L, 30000L)
            ]

            let safetyViolations = errors |> List.choose (function
                | SafetyViolation (id, reason) -> Some (id, reason)
                | _ -> None)

            Expect.equal (List.length safetyViolations) 1 "Should have exactly 1 SafetyViolation"
    ]

/// Tests for constraint validation in SystemRegistry
[<Tests>]
let registryConstraintTests =
    testList "SystemRegistry Constraints" [
        testCase "SystemRegistry can hold multiple constraints" <| fun _ ->
            let constraints = [
                { Id = "SC-VAL-001"; Category = "Validation"; Description = "Test 1"; Compliance = Some true }
                { Id = "SC-CNT-009"; Category = "Container"; Description = "Test 2"; Compliance = Some true }
                { Id = "SC-PRF-055"; Category = "Performance"; Description = "Test 3"; Compliance = None }
            ]
            let registry: SystemRegistry = {
                LogPath = "test.log"
                DatabasePath = "test.db"
                TempDir = "tmp"
                ComposeFiles = Map.empty
                ContainerNames = Map.empty
                PortMap = Map.empty
                ReadyPatterns = Map.empty
                Dockerfiles = Map.empty
                Constraints = constraints
                PodmanSocket = None
            }
            Expect.equal (List.length registry.Constraints) 3 "Registry should hold 3 constraints"

        testCase "Empty constraints list is valid for testing" <| fun _ ->
            let registry: SystemRegistry = {
                LogPath = "test.log"
                DatabasePath = "test.db"
                TempDir = "tmp"
                ComposeFiles = Map.empty
                ContainerNames = Map.empty
                PortMap = Map.empty
                ReadyPatterns = Map.empty
                Dockerfiles = Map.empty
                Constraints = []
                PodmanSocket = None
            }
            Expect.isEmpty registry.Constraints "Empty constraints should be valid"

        testCase "Constraints can be filtered by compliance status" <| fun _ ->
            let constraints = [
                { Id = "SC-VAL-001"; Category = "Validation"; Description = "Passed"; Compliance = Some true }
                { Id = "SC-CNT-009"; Category = "Container"; Description = "Failed"; Compliance = Some false }
                { Id = "SC-PRF-055"; Category = "Performance"; Description = "Pending"; Compliance = None }
            ]

            let passed = constraints |> List.filter (fun c -> c.Compliance = Some true)
            let failed = constraints |> List.filter (fun c -> c.Compliance = Some false)
            let pending = constraints |> List.filter (fun c -> c.Compliance.IsNone)

            Expect.equal (List.length passed) 1 "Should have 1 passed constraint"
            Expect.equal (List.length failed) 1 "Should have 1 failed constraint"
            Expect.equal (List.length pending) 1 "Should have 1 pending constraint"
    ]

/// Tests for AOR (Agent Operating Rules) as constraints
[<Tests>]
let aorConstraintTests =
    testList "AOR Constraint Validation" [
        testCase "AOR-QUA-001 zero warnings gate" <| fun _ ->
            let warningCount = 0
            let compliant = warningCount = 0
            Expect.isTrue compliant "Zero warnings should pass AOR-QUA-001"

        testCase "AOR-QUA-001 fails with warnings" <| fun _ ->
            let warningCount = 5
            let compliant = warningCount = 0
            Expect.isFalse compliant "Non-zero warnings should fail AOR-QUA-001"

        testCase "AOR-CNT-001 Podman only" <| fun _ ->
            let containerRuntime = "podman"
            let compliant = containerRuntime = "podman"
            Expect.isTrue compliant "Podman runtime should pass AOR-CNT-001"

        testCase "AOR-CNT-001 fails with Docker" <| fun _ ->
            let containerRuntime = "docker"
            let compliant = containerRuntime = "podman"
            Expect.isFalse compliant "Docker runtime should fail AOR-CNT-001"
    ]

[<Tests>]
let allTests =
    testList "Constraints" [
        constraintTypeTests
        stampCategoryTests
        safetyViolationTests
        registryConstraintTests
        aorConstraintTests
    ]
