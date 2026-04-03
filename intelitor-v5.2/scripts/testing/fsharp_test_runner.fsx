#!/usr/bin/env dotnet fsi
/// F# Test Group Runner — Runs each Expecto test group individually with timeouts.
///
/// Solves the stdout pipe buffer deadlock caused by ZenohPublish triple-write
/// in throughput tests (FFI.Perf writes 2000+ lines per test → 64KB pipe fills → deadlock).
///
/// Strategy: Run each of the 37 test groups as a separate `dotnet exec` process
/// with per-group timeouts. Aggregate results into a dashboard summary.
///
/// STAMP: SC-COV-001 (100% critical paths), SC-ZTEST-008 (log fallback)
/// AOR: AOR-TEST-001 (TDG validation), AOR-BIO-001 (fast OODA)
///
/// Usage:
///   dotnet fsi scripts/testing/fsharp_test_runner.fsx
///   dotnet fsi scripts/testing/fsharp_test_runner.fsx --timeout 30
///   dotnet fsi scripts/testing/fsharp_test_runner.fsx --group ZenohFfiBridge

open System
open System.Diagnostics
open System.IO
open System.Text.RegularExpressions

// ============================================================
// Configuration
// ============================================================

let testDll = "lib/cepaf/test/Cepaf.Tests/bin/Debug/net10.0/Cepaf.Tests.dll"
let defaultTimeoutSec = 45
let projectRoot = Environment.CurrentDirectory

/// All 37 top-level test groups from Program.fs
let allGroups = [|
    "TopologicalSort"
    "ROP"
    "OodaOrient"
    "OodaController"
    "Constraints"
    "PHICS"
    "CyberneticAgents"
    "BuilderPhase"
    "Orchestrator"
    "PRAJNA C3I Cockpit TUI"
    "Formal Verification"
    "ZenohFfiBridge"
    "NativeSession"
    "SafePublisher"
    "SafeSubscriber"
    "SafeSession"
    "SimulatedMessageBus"
    "ZenohKeyExpr"
    "ZenohTypes"
    "ZenohPublish"
    "FFI"
    "ExponentialBackoff"
    "HLC (Hybrid Logical Clock)"
    "DAG Complete Test Suite"
    "FSM Complete Test Suite"
    "CPM Complete Test Suite"
    "Hysteresis Complete Test Suite"
    "MathematicalSystemMonitor"
    "ZenohChannel"
    "Zenoh-Elixir Integration"
    "Zenoh Performance"
    "SC-FSH-003: Active Patterns"
    "SC-FSH-004: Units of Measure"
    "SC-FSH-010/011: Function Composition"
    "F# Capability Integration"
    "Biomorphic Test Evolution"
    "Planning <-> Chaya Sync"
    "7-Level Fractal Verification"
|]

// ============================================================
// Types
// ============================================================

type TestStatus = Pass | Fail | Timeout | Error
type GroupResult = {
    Name: string
    Status: TestStatus
    Passed: int
    Failed: int
    Ignored: int
    Errored: int
    ElapsedMs: int64
    FailureDetails: string list
}

// ============================================================
// Process Runner
// ============================================================

let runTestGroup (timeoutSec: int) (groupName: string) : GroupResult =
    let sw = Stopwatch.StartNew()
    let dllPath = Path.Combine(projectRoot, testDll)

    if not (File.Exists dllPath) then
        sw.Stop()
        { Name = groupName; Status = Error; Passed = 0; Failed = 0
          Ignored = 0; Errored = 1; ElapsedMs = sw.ElapsedMilliseconds
          FailureDetails = [$"DLL not found: {dllPath}"] }
    else

    let ldPath =
        let existing = Environment.GetEnvironmentVariable("LD_LIBRARY_PATH") |> Option.ofObj |> Option.defaultValue ""
        let release = Path.Combine(projectRoot, "target/release")
        if existing.Contains(release) then existing
        else $"{release}:{existing}"

    let psi = ProcessStartInfo()
    psi.FileName <- "dotnet"
    psi.Arguments <- $"exec \"{dllPath}\" --filter-test-list \"{groupName}\" --sequenced --summary"
    psi.UseShellExecute <- false
    psi.RedirectStandardOutput <- true
    psi.RedirectStandardError <- true
    psi.CreateNoWindow <- true
    psi.WorkingDirectory <- projectRoot
    psi.Environment["LD_LIBRARY_PATH"] <- ldPath

    let stdout = System.Text.StringBuilder()
    let stderr = System.Text.StringBuilder()

    try
        use proc = new Process()
        proc.StartInfo <- psi

        // Async read to prevent pipe deadlock
        proc.OutputDataReceived.Add(fun e ->
            if not (isNull e.Data) then
                stdout.AppendLine(e.Data) |> ignore)
        proc.ErrorDataReceived.Add(fun e ->
            if not (isNull e.Data) then
                stderr.AppendLine(e.Data) |> ignore)

        proc.Start() |> ignore
        proc.BeginOutputReadLine()
        proc.BeginErrorReadLine()

        let finished = proc.WaitForExit(timeoutSec * 1000)
        sw.Stop()

        if not finished then
            try proc.Kill(true) with _ -> ()
            { Name = groupName; Status = Timeout; Passed = 0; Failed = 0
              Ignored = 0; Errored = 0; ElapsedMs = sw.ElapsedMilliseconds
              FailureDetails = [$"Timeout after {timeoutSec}s"] }
        else

        // Strip ANSI escape codes for clean parsing
        let stripAnsi (s: string) = Regex.Replace(s, @"\x1B\[[0-9;]*[a-zA-Z]|\x1B\[\?[0-9;]*[a-zA-Z]|\x1B\[[0-9]*D", "")
        let output = stdout.ToString() |> stripAnsi
        let exitCode = proc.ExitCode

        // Parse Expecto summary section:
        //   Passed:  N
        //   Ignored: N
        //   Failed:  N
        //   Errored: N
        let parseCount (label: string) =
            let m = Regex.Match(output, label + @":\s*(\d+)")
            if m.Success then int m.Groups.[1].Value else 0

        let passed = parseCount "Passed"
        let ignored = parseCount "Ignored"
        let failed = parseCount "Failed"
        let errored = parseCount "Errored"
        let total = passed + failed + ignored + errored

        // Extract failure details from ERR lines
        let failures =
            Regex.Matches(output, @"ERR\]\s*(.+?)\s+failed in")
            |> Seq.cast<Match>
            |> Seq.map (fun m -> m.Groups.[1].Value.Trim())
            |> Seq.toList

        let status =
            if total = 0 && exitCode = 0 then Pass  // No summary but clean exit
            elif failed + errored > 0 then Fail
            elif exitCode <> 0 then Error
            else Pass
        { Name = groupName; Status = status; Passed = passed; Failed = failed
          Ignored = ignored; Errored = errored; ElapsedMs = sw.ElapsedMilliseconds
          FailureDetails = failures }

    with ex ->
        sw.Stop()
        { Name = groupName; Status = Error; Passed = 0; Failed = 0
          Ignored = 0; Errored = 1; ElapsedMs = sw.ElapsedMilliseconds
          FailureDetails = [ex.Message] }

// ============================================================
// Dashboard Rendering
// ============================================================

let statusIcon = function
    | Pass -> "\u2705"  // green check
    | Fail -> "\u274C"  // red X
    | Timeout -> "\u23F0" // alarm clock
    | Error -> "\u26A0\uFE0F"  // warning

let statusText = function
    | Pass -> "PASS"
    | Fail -> "FAIL"
    | Timeout -> "TIMEOUT"
    | Error -> "ERROR"

let printDashboard (results: GroupResult list) (totalElapsed: int64) =
    let totalPass = results |> List.sumBy (fun r -> r.Passed)
    let totalFail = results |> List.sumBy (fun r -> r.Failed)
    let totalIgnore = results |> List.sumBy (fun r -> r.Ignored)
    let totalError = results |> List.sumBy (fun r -> r.Errored)
    let totalTests = totalPass + totalFail + totalIgnore + totalError
    let groupsPass = results |> List.filter (fun r -> r.Status = Pass) |> List.length
    let groupsFail = results |> List.filter (fun r -> r.Status <> Pass) |> List.length
    let passRate = if totalTests > 0 then float totalPass / float (totalPass + totalFail + totalError) * 100.0 else 0.0

    printfn ""
    printfn "================================================================="
    printfn "  F# EXPECTO TEST SUITE — FULL REGRESSION RESULTS"
    printfn "  Date: %s | Duration: %.1fs" (DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")) (float totalElapsed / 1000.0)
    printfn "================================================================="
    printfn ""
    printfn "  SUMMARY"
    printfn "  -------"
    printfn "  Total Tests:   %d" totalTests
    printfn "  Passed:        %d" totalPass
    printfn "  Failed:        %d" totalFail
    printfn "  Ignored:       %d" totalIgnore
    printfn "  Errored:       %d" totalError
    printfn "  Pass Rate:     %.1f%%" passRate
    printfn "  Groups:        %d/%d passed" groupsPass (groupsPass + groupsFail)
    printfn ""
    printfn "  %-50s  %7s  %7s  %s" "GROUP" "STATUS" "TIME" "TESTS"
    printfn "  %s" (String.replicate 85 "-")

    for r in results do
        let testSummary = sprintf "%dp/%df/%di" r.Passed r.Failed r.Ignored
        printfn "  %-50s  %7s  %5dms  %s"
            (if r.Name.Length > 50 then r.Name.[..49] else r.Name)
            (statusText r.Status)
            r.ElapsedMs
            testSummary

    printfn "  %s" (String.replicate 85 "-")
    printfn "  %-50s  %7s  %5dms  %dp/%df/%di"
        "TOTAL"
        (if totalFail + totalError = 0 then "PASS" else "FAIL")
        totalElapsed
        totalPass totalFail totalIgnore
    printfn ""

    // Print failures detail
    let failedGroups = results |> List.filter (fun r -> r.Status <> Pass)
    if not (List.isEmpty failedGroups) then
        printfn "  FAILURE DETAILS"
        printfn "  ---------------"
        for r in failedGroups do
            printfn "  [%s] %s:" (statusText r.Status) r.Name
            for detail in r.FailureDetails |> List.truncate 3 do
                printfn "    - %s" (if detail.Length > 100 then detail.[..99] + "..." else detail)
        printfn ""

    printfn "================================================================="
    printfn ""

// ============================================================
// CLI Argument Parsing
// ============================================================

let args = fsi.CommandLineArgs |> Array.toList |> List.tail  // skip script name

let rec parseArgs (args: string list) (timeout: int) (filterGroup: string option) =
    match args with
    | "--timeout" :: n :: rest ->
        parseArgs rest (int n) filterGroup
    | "--group" :: g :: rest ->
        parseArgs rest timeout (Some g)
    | _ :: rest ->
        parseArgs rest timeout filterGroup
    | [] -> (timeout, filterGroup)

let (timeoutSec, filterGroup) = parseArgs args defaultTimeoutSec None

// ============================================================
// Main Execution
// ============================================================

let groups =
    match filterGroup with
    | Some g -> allGroups |> Array.filter (fun name -> name.Contains(g, StringComparison.OrdinalIgnoreCase))
    | None -> allGroups

printfn ""
printfn "F# Test Runner — %d groups, %ds timeout per group" groups.Length timeoutSec
printfn "DLL: %s" testDll
printfn ""

let totalSw = Stopwatch.StartNew()
let results =
    groups
    |> Array.mapi (fun i group ->
        printf "  [%2d/%2d] %-50s ... " (i+1) groups.Length group
        Console.Out.Flush()
        let result = runTestGroup timeoutSec group
        printfn "%s  %dms  (%dp/%df)" (statusText result.Status) result.ElapsedMs result.Passed result.Failed
        result)
    |> Array.toList

totalSw.Stop()

printDashboard results totalSw.ElapsedMilliseconds

// Write JSON results for machine consumption
let jsonPath = "/tmp/fsharp_test_results.json"
let json =
    results
    |> List.map (fun r ->
        sprintf """  {"group":"%s","status":"%s","passed":%d,"failed":%d,"ignored":%d,"errored":%d,"elapsed_ms":%d}"""
            (r.Name.Replace("\"", "\\\"")) (statusText r.Status) r.Passed r.Failed r.Ignored r.Errored r.ElapsedMs)
    |> String.concat ",\n"
File.WriteAllText(jsonPath, sprintf "[\n%s\n]" json)
printfn "JSON results written to: %s" jsonPath

// Exit code
let exitCode = if results |> List.forall (fun r -> r.Status = Pass) then 0 else 1
printfn "Exit code: %d" exitCode
