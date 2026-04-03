module Cepaf.Tests.Unit.Cockpit.BicameralDashboardTests

open System
open Expecto
open Cepaf.Cockpit

module BD = Cepaf.Cockpit.BicameralDashboard

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

let freshRelease () =
    BD.createRelease "v21.3.0" "main" "abc123def456"

// ---------------------------------------------------------------------------
// createRelease
// ---------------------------------------------------------------------------

[<Tests>]
let createReleaseTests =
    testList "BIC-CREATE: createRelease" [

        test "BIC-CREATE-001: createRelease returns Draft state" {
            let release = freshRelease ()
            match release.State with
            | ReleaseState.Draft -> ()
            | other -> failtest (sprintf "Expected Draft but got: %A" other)
        }

        test "BIC-CREATE-002: createRelease stores version in candidate" {
            let release = freshRelease ()
            Expect.equal release.Candidate.Version "v21.3.0"
                "Candidate version must match argument"
        }

        test "BIC-CREATE-003: createRelease stores branch in candidate" {
            let release = freshRelease ()
            Expect.equal release.Candidate.Branch "main"
                "Candidate branch must match argument"
        }

        test "BIC-CREATE-004: createRelease stores commitSha in candidate" {
            let release = freshRelease ()
            Expect.equal release.Candidate.CommitSha "abc123def456"
                "Candidate commitSha must match argument"
        }

        test "BIC-CREATE-005: createRelease creates exactly 7 quality gates" {
            let release = freshRelease ()
            Expect.equal release.Candidate.QualityGates.Length 7
                "Must have exactly 7 default quality gates"
        }

        test "BIC-CREATE-006: all initial quality gates have status pending" {
            let release = freshRelease ()
            Expect.isTrue (release.Candidate.QualityGates |> List.forall (fun g -> g.Status = "pending"))
                "All gates must start with status 'pending'"
        }

        test "BIC-CREATE-007: quality gates include Compile gate" {
            let release = freshRelease ()
            Expect.isTrue (release.Candidate.QualityGates |> List.exists (fun g -> g.Name.Contains("Compile")))
                "Must include Compile gate"
        }

        test "BIC-CREATE-008: quality gates include STAMP gate" {
            let release = freshRelease ()
            Expect.isTrue (release.Candidate.QualityGates |> List.exists (fun g -> g.Name.Contains("STAMP")))
                "Must include STAMP gate"
        }

        test "BIC-CREATE-009: CreatedAt is non-empty" {
            let release = freshRelease ()
            Expect.isTrue (release.CreatedAt.Length > 0) "CreatedAt must be non-empty"
        }

        test "BIC-CREATE-010: History has exactly one entry on creation" {
            let release = freshRelease ()
            Expect.equal release.History.Length 1
                "History must have exactly one creation entry on creation"
        }
    ]

// ---------------------------------------------------------------------------
// approveKey1
// ---------------------------------------------------------------------------

[<Tests>]
let approveKey1Tests =
    testList "BIC-K1: approveKey1" [

        test "BIC-K1-001: approveKey1 from Draft returns Ok" {
            let release = freshRelease ()
            let result = BD.approveKey1 release "Alice"
            Expect.isOk result "approveKey1 from Draft must return Ok"
        }

        test "BIC-K1-002: approveKey1 transitions state to Key1Approved" {
            let release = freshRelease ()
            match BD.approveKey1 release "Alice" with
            | Ok approved ->
                match approved.State with
                | ReleaseState.Key1Approved _ -> ()
                | other -> failtest (sprintf "Expected Key1Approved but got: %A" other)
            | Error e -> failtest (sprintf "Expected Ok but got Error: %s" e)
        }

        test "BIC-K1-003: approveKey1 stores approver name" {
            let release = freshRelease ()
            match BD.approveKey1 release "Alice" with
            | Ok approved ->
                match approved.State with
                | ReleaseState.Key1Approved key ->
                    Expect.equal key.Approver "Alice" "Key1 approver must be Alice"
                | other -> failtest (sprintf "Expected Key1Approved but got: %A" other)
            | Error e -> failtest (sprintf "Expected Ok but got Error: %s" e)
        }

        test "BIC-K1-004: approveKey1 on Key1Approved returns Error" {
            let release = freshRelease ()
            let approved =
                match BD.approveKey1 release "Alice" with
                | Ok r -> r
                | Error e -> failtest (sprintf "Setup failed: %s" e)
            let result = BD.approveKey1 approved "Bob"
            Expect.isError result "approveKey1 on already-approved release must return Error"
        }

        test "BIC-K1-005: approveKey1 double-approval error mentions Chamber 1" {
            let release = freshRelease ()
            let approved =
                match BD.approveKey1 release "Alice" with
                | Ok r -> r
                | Error e -> failtest (sprintf "Setup failed: %s" e)
            match BD.approveKey1 approved "Bob" with
            | Error msg ->
                Expect.isTrue (msg.Contains("Chamber 1") || msg.Contains("already approved"))
                    "Error must mention Chamber 1 or already approved"
            | Ok _ -> failtest "Expected Error but got Ok"
        }

        test "BIC-K1-006: ApprovalKey has non-empty Token" {
            let release = freshRelease ()
            match BD.approveKey1 release "Alice" with
            | Ok approved ->
                match approved.State with
                | ReleaseState.Key1Approved key ->
                    Expect.isTrue (key.Token.Length > 0) "Token must be non-empty"
                | _ -> failtest "Expected Key1Approved state"
            | Error e -> failtest (sprintf "Expected Ok but got Error: %s" e)
        }
    ]

// ---------------------------------------------------------------------------
// approveKey2
// ---------------------------------------------------------------------------

[<Tests>]
let approveKey2Tests =
    testList "BIC-K2: approveKey2" [

        test "BIC-K2-001: approveKey2 from Key1Approved returns Ok" {
            let release = freshRelease ()
            let k1 =
                match BD.approveKey1 release "Alice" with
                | Ok r -> r
                | Error e -> failtest (sprintf "Setup failed: %s" e)
            let result = BD.approveKey2 k1 "Bob"
            Expect.isOk result "approveKey2 from Key1Approved must return Ok"
        }

        test "BIC-K2-002: approveKey2 transitions state to Key2Approved" {
            let release = freshRelease ()
            let k1 =
                match BD.approveKey1 release "Alice" with
                | Ok r -> r
                | Error e -> failtest (sprintf "Setup failed: %s" e)
            match BD.approveKey2 k1 "Bob" with
            | Ok approved ->
                match approved.State with
                | ReleaseState.Key2Approved _ -> ()
                | other -> failtest (sprintf "Expected Key2Approved but got: %A" other)
            | Error e -> failtest (sprintf "Expected Ok but got Error: %s" e)
        }

        test "BIC-K2-003: approveKey2 from Draft returns Error" {
            let release = freshRelease ()
            let result = BD.approveKey2 release "Bob"
            Expect.isError result "approveKey2 from Draft must return Error — Chamber 1 required first"
        }

        test "BIC-K2-004: approveKey2 from Draft error mentions Chamber 1 required" {
            let release = freshRelease ()
            match BD.approveKey2 release "Bob" with
            | Error msg ->
                Expect.isTrue (msg.Contains("Chamber 1") || msg.Contains("approval required") || msg.Contains("SC-SAFETY-001"))
                    "Error must mention Chamber 1 approval requirement or SC-SAFETY-001"
            | Ok _ -> failtest "Expected Error but got Ok"
        }

        test "BIC-K2-005: approveKey2 stores second approver" {
            let release = freshRelease ()
            let k1 =
                match BD.approveKey1 release "Alice" with
                | Ok r -> r
                | Error e -> failtest (sprintf "Setup failed: %s" e)
            match BD.approveKey2 k1 "Bob" with
            | Ok approved ->
                match approved.State with
                | ReleaseState.Key2Approved (_, key2) ->
                    Expect.equal key2.Approver "Bob" "Key2 approver must be Bob"
                | _ -> failtest "Expected Key2Approved state"
            | Error e -> failtest (sprintf "Expected Ok but got Error: %s" e)
        }

        test "BIC-K2-006: Key2Approved preserves Key1 info" {
            let release = freshRelease ()
            let k1 =
                match BD.approveKey1 release "Alice" with
                | Ok r -> r
                | Error e -> failtest (sprintf "Setup failed: %s" e)
            match BD.approveKey2 k1 "Bob" with
            | Ok approved ->
                match approved.State with
                | ReleaseState.Key2Approved (key1, _) ->
                    Expect.equal key1.Approver "Alice" "Key1 approver must still be Alice"
                | _ -> failtest "Expected Key2Approved state"
            | Error e -> failtest (sprintf "Expected Ok but got Error: %s" e)
        }
    ]

// ---------------------------------------------------------------------------
// reject
// ---------------------------------------------------------------------------

[<Tests>]
let rejectTests =
    testList "BIC-REJ: reject" [

        test "BIC-REJ-001: reject from Draft sets Rejected state" {
            let release = freshRelease ()
            let rejected = BD.reject release "Test reason"
            match rejected.State with
            | ReleaseState.Rejected _ -> ()
            | other -> failtest (sprintf "Expected Rejected but got: %A" other)
        }

        test "BIC-REJ-002: reject from Key1Approved sets Rejected state" {
            let release = freshRelease ()
            let k1 =
                match BD.approveKey1 release "Alice" with
                | Ok r -> r
                | Error e -> failtest (sprintf "Setup failed: %s" e)
            let rejected = BD.reject k1 "Security concern"
            match rejected.State with
            | ReleaseState.Rejected _ -> ()
            | other -> failtest (sprintf "Expected Rejected but got: %A" other)
        }

        test "BIC-REJ-003: reject stores reason in state" {
            let release = freshRelease ()
            let rejected = BD.reject release "CVE-2026-001 found"
            match rejected.State with
            | ReleaseState.Rejected reason ->
                Expect.stringContains reason "CVE-2026-001" "Rejection reason must be stored"
            | other -> failtest (sprintf "Expected Rejected but got: %A" other)
        }

        test "BIC-REJ-004: reject preserves candidate version" {
            let release = freshRelease ()
            let rejected = BD.reject release "Reason"
            Expect.equal rejected.Candidate.Version "v21.3.0"
                "Rejection must preserve candidate version"
        }
    ]

// ---------------------------------------------------------------------------
// renderGates
// ---------------------------------------------------------------------------

[<Tests>]
let renderGatesTests =
    testList "BIC-GATES: renderGates" [

        test "BIC-GATES-001: renderGates returns non-empty string" {
            let release = freshRelease ()
            let result = BD.renderGates release.Candidate.QualityGates
            Expect.isTrue (result.Length > 0) "renderGates must return content"
        }

        test "BIC-GATES-002: renderGates contains ANSI escape codes (SC-HMI-010)" {
            let release = freshRelease ()
            let result = BD.renderGates release.Candidate.QualityGates
            Expect.stringContains result "\u001b[" "renderGates must contain ANSI codes"
        }

        test "BIC-GATES-003: renderGates contains Compile gate name" {
            let release = freshRelease ()
            let result = BD.renderGates release.Candidate.QualityGates
            Expect.stringContains result "Compile" "renderGates must show Compile gate"
        }

        test "BIC-GATES-004: renderGates contains STAMP gate name" {
            let release = freshRelease ()
            let result = BD.renderGates release.Candidate.QualityGates
            Expect.stringContains result "STAMP" "renderGates must show STAMP gate"
        }

        test "BIC-GATES-005: renderGates on empty list returns empty string" {
            let result = BD.renderGates []
            Expect.equal result "" "renderGates on empty list returns empty string (no gates to render)"
        }

        test "BIC-GATES-006: renderGates contains pending status indicator" {
            let release = freshRelease ()
            let result = BD.renderGates release.Candidate.QualityGates
            // Pending gates typically show a yellow or neutral indicator
            Expect.isTrue (result.Contains("pending") || result.Contains("…") || result.Contains("○") || result.Contains("\u001b[33m"))
                "renderGates must indicate pending gate status"
        }
    ]

// ---------------------------------------------------------------------------
// renderDashboard
// ---------------------------------------------------------------------------

[<Tests>]
let renderDashboardTests =
    testList "BIC-DASH: renderDashboard" [

        test "BIC-DASH-001: renderDashboard returns non-empty string" {
            let release = freshRelease ()
            let result = BD.renderDashboard release
            Expect.isTrue (result.Length > 0) "renderDashboard must return content"
        }

        test "BIC-DASH-002: renderDashboard contains ANSI escape codes (SC-HMI-010)" {
            let release = freshRelease ()
            let result = BD.renderDashboard release
            Expect.stringContains result "\u001b[" "renderDashboard must contain ANSI codes"
        }

        test "BIC-DASH-003: renderDashboard contains BICAMERAL RELEASE header" {
            let release = freshRelease ()
            let result = BD.renderDashboard release
            Expect.isTrue (result.Contains("BICAMERAL") || result.Contains("RELEASE DASHBOARD"))
                "renderDashboard must contain BICAMERAL RELEASE header"
        }

        test "BIC-DASH-004: renderDashboard contains SC-SAFETY-001 STAMP reference" {
            let release = freshRelease ()
            let result = BD.renderDashboard release
            Expect.stringContains result "SC-SAFETY-001"
                "renderDashboard must reference SC-SAFETY-001"
        }

        test "BIC-DASH-005: renderDashboard contains box-drawing characters" {
            let release = freshRelease ()
            let result = BD.renderDashboard release
            Expect.isTrue (result.Contains("┌") || result.Contains("║") || result.Contains("└"))
                "renderDashboard must use box-drawing characters"
        }

        test "BIC-DASH-006: renderDashboard shows version number" {
            let release = freshRelease ()
            let result = BD.renderDashboard release
            Expect.stringContains result "v21.3.0"
                "renderDashboard must show candidate version"
        }

        test "BIC-DASH-007: renderDashboard shows branch name" {
            let release = freshRelease ()
            let result = BD.renderDashboard release
            Expect.stringContains result "main"
                "renderDashboard must show branch name"
        }

        test "BIC-DASH-008: renderDashboard for Key1Approved shows Chamber 1 approval" {
            let release = freshRelease ()
            let k1 =
                match BD.approveKey1 release "Alice" with
                | Ok r -> r
                | Error e -> failtest (sprintf "Setup failed: %s" e)
            let result = BD.renderDashboard k1
            Expect.isTrue (result.Contains("Alice") || result.Contains("Chamber 1") || result.Contains("Key1") || result.Contains("approved"))
                "Dashboard for Key1Approved must indicate Chamber 1 approval"
        }

        test "BIC-DASH-009: renderDashboard for Rejected shows rejection info" {
            let release = freshRelease ()
            let rejected = BD.reject release "Critical bug found"
            let result = BD.renderDashboard rejected
            Expect.isTrue (result.Contains("Reject") || result.Contains("reject") || result.Contains("REJECT") || result.Contains("Critical bug"))
                "Dashboard for Rejected must show rejection info"
        }
    ]

// ---------------------------------------------------------------------------
// toJson
// ---------------------------------------------------------------------------

[<Tests>]
let toJsonTests =
    testList "BIC-JSON: toJson" [

        test "BIC-JSON-001: toJson returns valid JSON object" {
            let release = freshRelease ()
            let result = BD.toJson release
            Expect.isTrue (result.TrimStart().StartsWith("{"))
                "toJson must return a JSON object"
        }

        test "BIC-JSON-002: toJson contains version key" {
            let release = freshRelease ()
            let result = BD.toJson release
            Expect.isTrue (result.Contains("version") || result.Contains("Version"))
                "JSON must contain version key"
        }

        test "BIC-JSON-003: toJson contains state key" {
            let release = freshRelease ()
            let result = BD.toJson release
            Expect.isTrue (result.Contains("state") || result.Contains("State"))
                "JSON must contain state key"
        }

        test "BIC-JSON-004: toJson contains qualityGates key" {
            let release = freshRelease ()
            let result = BD.toJson release
            Expect.isTrue (result.Contains("qualityGates") || result.Contains("QualityGates") || result.Contains("gates"))
                "JSON must contain quality gates"
        }

        test "BIC-JSON-005: toJson contains Draft state for fresh release" {
            let release = freshRelease ()
            let result = BD.toJson release
            Expect.isTrue (result.Contains("Draft") || result.Contains("draft"))
                "JSON must contain Draft state for fresh release"
        }
    ]

// ---------------------------------------------------------------------------
// Aggregate
// ---------------------------------------------------------------------------

[<Tests>]
let allBicameralDashboardTests =
    testList "Bicameral Dashboard" [
        createReleaseTests
        approveKey1Tests
        approveKey2Tests
        rejectTests
        renderGatesTests
        renderDashboardTests
        toJsonTests
    ]
