// =============================================================================
// CommandVerifierTests.fs - TDG-compliant tests for CommandVerifier
// =============================================================================
// STAMP: SC-TEST-001 (TDG compliance), SC-CLI-001 (CLI commands runtime-verified),
//        AOR-CMD-001 (sa-* verification mandatory at boot)
//
// ## Test Coverage
// - verifyAll: returns CommandVerificationResult with correct aggregate counts
// - verifyAll: total >= 1, available+missing+errors = total
// - verifyAll: commands list is non-empty, all names start with "sa-"
// - verifyAll: known sa-* names appear in the commands list
// - verifyAll: timestamp is a recent UTC timestamp
// - checkCommand: known command name fills Name/Description/Category/CheckedAt
// - checkCommand: returns CommandStatus.Available or CommandStatus.Missing (never throws)
// - checkCommand: unknown name returns CommandStatus.Missing (not in registry)
// - checkCommand: all status variants are pattern-matchable without MatchFailureException
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 2.0.0 |
// | Created | 2026-03-30 |
// | Updated | 2026-03-30 — rewrote to match actual CommandVerifier API |
// | Author | Code Evolution Agent v21.3.0-SIL6 |
// | STAMP | SC-TEST-001, SC-CLI-001, AOR-CMD-001 |
// =============================================================================

module Cepaf.Tests.Unit.Mesh.CommandVerifierTests

open Expecto
open Cepaf.Mesh
open System

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// All unique command names listed in the static registry (de-duplicated).
/// We derive this from verifyAll rather than hard-coding to stay in sync.
let private allCommandNames () =
    let result = CommandVerifier.verifyAll ()
    result.Commands |> List.map (fun c -> c.Name) |> List.distinct

/// True when the CommandStatus is Available.
let private isAvailable (s: CommandStatus) =
    match s with
    | CommandStatus.Available -> true
    | _ -> false

/// True when the CommandStatus is Missing.
let private isMissing (s: CommandStatus) =
    match s with
    | CommandStatus.Missing -> true
    | _ -> false

/// True when the CommandStatus is Error.
let private isError (s: CommandStatus) =
    match s with
    | CommandStatus.Error _ -> true
    | _ -> false

[<Tests>]
let tests = testList "CommandVerifier" [

    // =========================================================================
    // verifyAll — aggregate result tests
    // =========================================================================
    testList "verifyAll" [

        test "verifyAll returns without throwing" {
            let result = CommandVerifier.verifyAll ()
            Expect.isTrue (result.Total >= 0) "verifyAll must return a valid result"
        }

        test "verifyAll total equals length of commands list" {
            let result = CommandVerifier.verifyAll ()
            Expect.equal result.Total (result.Commands |> List.length)
                "Total field must equal the number of entries in Commands"
        }

        test "verifyAll total is at least 1" {
            let result = CommandVerifier.verifyAll ()
            Expect.isGreaterThan result.Total 0 "Should have at least one command in registry"
        }

        test "verifyAll available + missing + errors equals total" {
            let result = CommandVerifier.verifyAll ()
            let sum = result.Available + result.Missing + result.Errors
            Expect.equal sum result.Total
                "available + missing + errors must equal total"
        }

        test "verifyAll available count matches commands with Available status" {
            let result = CommandVerifier.verifyAll ()
            let counted =
                result.Commands
                |> List.filter (fun c -> isAvailable c.Status)
                |> List.length
            Expect.equal result.Available counted
                "Available field must match count of Available-status commands"
        }

        test "verifyAll missing count matches commands with Missing status" {
            let result = CommandVerifier.verifyAll ()
            let counted =
                result.Commands
                |> List.filter (fun c -> isMissing c.Status)
                |> List.length
            Expect.equal result.Missing counted
                "Missing field must match count of Missing-status commands"
        }

        test "verifyAll errors count matches commands with Error status" {
            let result = CommandVerifier.verifyAll ()
            let counted =
                result.Commands
                |> List.filter (fun c -> isError c.Status)
                |> List.length
            Expect.equal result.Errors counted
                "Errors field must match count of Error-status commands"
        }

        test "verifyAll timestamp is within last 60 seconds" {
            let before = DateTimeOffset.UtcNow.AddSeconds(-60.0)
            let result = CommandVerifier.verifyAll ()
            Expect.isGreaterThanOrEqual result.Timestamp before
                "Timestamp must be recent (within last 60 seconds)"
        }

        test "verifyAll timestamp is not in the future" {
            let result = CommandVerifier.verifyAll ()
            let after  = DateTimeOffset.UtcNow.AddSeconds(1.0)
            Expect.isLessThan result.Timestamp after
                "Timestamp must not be in the future"
        }

        test "verifyAll commands list is non-empty" {
            let result = CommandVerifier.verifyAll ()
            Expect.isNonEmpty result.Commands "Commands list must not be empty"
        }

        test "every command in verifyAll has a non-empty Name" {
            let result = CommandVerifier.verifyAll ()
            for cmd in result.Commands do
                Expect.isNotEmpty cmd.Name
                    "Every CommandInfo must have a non-empty Name"
        }

        test "every command in verifyAll has a non-empty Description" {
            let result = CommandVerifier.verifyAll ()
            for cmd in result.Commands do
                Expect.isNotEmpty cmd.Description
                    $"Command '{cmd.Name}' must have a non-empty Description"
        }

        test "every command in verifyAll has a non-empty Category" {
            let result = CommandVerifier.verifyAll ()
            for cmd in result.Commands do
                Expect.isNotEmpty cmd.Category
                    $"Command '{cmd.Name}' must have a non-empty Category"
        }

        test "every command name in verifyAll starts with 'sa-'" {
            let result = CommandVerifier.verifyAll ()
            for cmd in result.Commands do
                Expect.isTrue (cmd.Name.StartsWith("sa-"))
                    $"Command '{cmd.Name}' must start with 'sa-'"
        }

        test "verifyAll commands list contains sa-up" {
            let result = CommandVerifier.verifyAll ()
            let found = result.Commands |> List.exists (fun c -> c.Name = "sa-up")
            Expect.isTrue found "Commands list must include sa-up (boot mesh)"
        }

        test "verifyAll commands list contains sa-down" {
            let result = CommandVerifier.verifyAll ()
            let found = result.Commands |> List.exists (fun c -> c.Name = "sa-down")
            Expect.isTrue found "Commands list must include sa-down (graceful shutdown)"
        }

        test "verifyAll commands list contains sa-plan" {
            let result = CommandVerifier.verifyAll ()
            let found = result.Commands |> List.exists (fun c -> c.Name = "sa-plan")
            Expect.isTrue found "Commands list must include sa-plan (SC-PLAN-004)"
        }

        test "verifyAll commands list contains sa-verify" {
            let result = CommandVerifier.verifyAll ()
            let found = result.Commands |> List.exists (fun c -> c.Name = "sa-verify")
            Expect.isTrue found "Commands list must include sa-verify (2oo3 voting)"
        }

        test "verifyAll commands list contains sa-status" {
            let result = CommandVerifier.verifyAll ()
            let found = result.Commands |> List.exists (fun c -> c.Name = "sa-status")
            Expect.isTrue found "Commands list must include sa-status (mesh health)"
        }

        test "verifyAll commands list contains sa-health" {
            let result = CommandVerifier.verifyAll ()
            let found = result.Commands |> List.exists (fun c -> c.Name = "sa-health")
            Expect.isTrue found "Commands list must include sa-health (point-in-time probe)"
        }

        test "verifyAll every CommandInfo status is pattern-matchable without exception" {
            let result = CommandVerifier.verifyAll ()
            for cmd in result.Commands do
                let _ =
                    match cmd.Status with
                    | CommandStatus.Available -> "available"
                    | CommandStatus.Missing   -> "missing"
                    | CommandStatus.Error _   -> "error"
                ()
        }

        test "verifyAll sa-up and sa-down are in the same result set" {
            let result = CommandVerifier.verifyAll ()
            let names  = result.Commands |> List.map (fun c -> c.Name)
            Expect.contains names "sa-up"   "sa-up must be in Commands"
            Expect.contains names "sa-down" "sa-down must be in Commands"
        }
    ]

    // =========================================================================
    // checkCommand — per-command probe tests
    // =========================================================================
    testList "checkCommand" [

        test "checkCommand with known name returns correct Name field" {
            let info = CommandVerifier.checkCommand "sa-up"
            Expect.equal info.Name "sa-up"
                "checkCommand must fill Name field with the requested command name"
        }

        test "checkCommand with known name returns non-empty Description" {
            let info = CommandVerifier.checkCommand "sa-plan"
            Expect.isNotEmpty info.Description
                "checkCommand should fill Description for a known command"
        }

        test "checkCommand with known name returns non-empty Category" {
            let info = CommandVerifier.checkCommand "sa-plan"
            Expect.isNotEmpty info.Category
                "checkCommand should fill Category for a known command"
        }

        test "checkCommand never throws for any known sa-* name" {
            // Contract: always returns CommandInfo — no exception.
            // Status may be Available, Missing, or Error depending on the environment.
            let result = CommandVerifier.verifyAll ()
            let uniqueNames =
                result.Commands |> List.map (fun c -> c.Name) |> List.distinct
            for name in uniqueNames do
                let info = CommandVerifier.checkCommand name
                Expect.equal info.Name name
                    $"checkCommand '{name}' must return CommandInfo with matching Name"
        }

        test "checkCommand result has a recent CheckedAt timestamp" {
            let before = DateTimeOffset.UtcNow.AddSeconds(-60.0)
            let info   = CommandVerifier.checkCommand "sa-up"
            Expect.isGreaterThanOrEqual info.CheckedAt before
                "CheckedAt must be within the last 60 seconds"
        }

        test "checkCommand CheckedAt is not in the future" {
            let info  = CommandVerifier.checkCommand "sa-down"
            let after = DateTimeOffset.UtcNow.AddSeconds(1.0)
            Expect.isLessThan info.CheckedAt after
                "CheckedAt must not be in the future"
        }

        test "checkCommand for truly unknown name returns Missing status" {
            // A name that starts with 'sa-' but is not in the registry.
            // The verifier probes file paths; it will find nothing and return Missing
            // (or Error if a path probe itself fails, but Missing is the common case).
            let info = CommandVerifier.checkCommand "sa-this-command-does-not-exist-at-all"
            let isMissingOrError =
                match info.Status with
                | CommandStatus.Missing -> true
                | CommandStatus.Error _ -> true
                | CommandStatus.Available -> false
            Expect.isTrue isMissingOrError
                "A totally unknown command name should return Missing (or Error, never Available)"
        }

        test "checkCommand for unknown name returns 'uncategorised' category" {
            let info = CommandVerifier.checkCommand "sa-this-command-does-not-exist-at-all"
            Expect.equal info.Category "uncategorised"
                "Unknown commands should fall back to 'uncategorised' category"
        }

        test "checkCommand for unknown name has the requested name in the result" {
            let cmdName = "sa-no-such-command-xyz"
            let info    = CommandVerifier.checkCommand cmdName
            Expect.equal info.Name cmdName
                "checkCommand must always echo back the requested name, even for unknowns"
        }

        test "checkCommand status is pattern-matchable without MatchFailureException" {
            let info = CommandVerifier.checkCommand "sa-verify"
            let _ =
                match info.Status with
                | CommandStatus.Available -> "available"
                | CommandStatus.Missing   -> "missing"
                | CommandStatus.Error _   -> "error"
            ()
        }

        test "checkCommand sa-up Name field equals 'sa-up'" {
            let info = CommandVerifier.checkCommand "sa-up"
            Expect.equal info.Name "sa-up" "Name must match argument"
        }

        test "checkCommand sa-down Name field equals 'sa-down'" {
            let info = CommandVerifier.checkCommand "sa-down"
            Expect.equal info.Name "sa-down" "Name must match argument"
        }

        test "checkCommand sa-plan category is 'planning'" {
            let info = CommandVerifier.checkCommand "sa-plan"
            Expect.equal info.Category "planning"
                "sa-plan must be categorised as 'planning'"
        }

        test "checkCommand sa-up category is 'lifecycle'" {
            let info = CommandVerifier.checkCommand "sa-up"
            Expect.equal info.Category "lifecycle"
                "sa-up must be categorised as 'lifecycle'"
        }

        test "checkCommand sa-verify category is 'verification'" {
            let info = CommandVerifier.checkCommand "sa-verify"
            Expect.equal info.Category "verification"
                "sa-verify must be categorised as 'verification'"
        }
    ]

    // =========================================================================
    // renderReport — smoke tests (format/no-throw; content is ANSI, not checked)
    // =========================================================================
    testList "renderReport" [

        test "renderReport returns a non-empty string" {
            let result = CommandVerifier.verifyAll ()
            let report = CommandVerifier.renderReport result
            Expect.isNotEmpty report "renderReport must return non-empty output"
        }

        test "renderReport does not throw" {
            let result = CommandVerifier.verifyAll ()
            let report = CommandVerifier.renderReport result
            Expect.isTrue (report.Length > 0) "renderReport must produce output without throwing"
        }

        test "renderReport output contains 'COMMAND VERIFIER'" {
            let result = CommandVerifier.verifyAll ()
            let report = CommandVerifier.renderReport result
            Expect.isTrue
                (report.Contains("COMMAND VERIFIER"))
                "renderReport must include the report header"
        }

        test "renderReport output contains 'sa-up'" {
            let result = CommandVerifier.verifyAll ()
            let report = CommandVerifier.renderReport result
            Expect.isTrue
                (report.Contains("sa-up"))
                "renderReport must include 'sa-up' in the output"
        }

        test "renderReport output contains 'sa-plan'" {
            let result = CommandVerifier.verifyAll ()
            let report = CommandVerifier.renderReport result
            Expect.isTrue
                (report.Contains("sa-plan"))
                "renderReport must include 'sa-plan' in the output"
        }

        test "renderReport output contains 'SC-VER-042'" {
            let result = CommandVerifier.verifyAll ()
            let report = CommandVerifier.renderReport result
            Expect.isTrue
                (report.Contains("SC-VER-042"))
                "renderReport footer must reference SC-VER-042 compliance"
        }
    ]
]
