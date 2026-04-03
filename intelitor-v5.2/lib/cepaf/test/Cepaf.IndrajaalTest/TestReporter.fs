/// Cepaf.IndrajaalTest.TestReporter
/// Test reporting and result aggregation
///
/// STAMP Constraints:
/// - SC-REPORT-001: All test results must be persisted
/// - SC-REPORT-002: Reports must include timing information
module Cepaf.IndrajaalTest.TestReporter

open System
open System.IO
open System.Text
open System.Text.Json
open Cepaf.IndrajaalTest.Types
open Serilog

// =============================================================================
// Logger Configuration
// =============================================================================

/// Configure Serilog logger
let configureLogger (outputPath: string option) =
    let config =
        LoggerConfiguration()
            .MinimumLevel.Debug()
            .WriteTo.Console(
                outputTemplate = "[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}")

    let config =
        match outputPath with
        | Some path ->
            config.WriteTo.File(
                path,
                outputTemplate = "[{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} {Level:u3}] {Message:lj}{NewLine}{Exception}",
                rollingInterval = RollingInterval.Day)
        | None -> config

    Log.Logger <- config.CreateLogger()

// =============================================================================
// Console Output Helpers
// =============================================================================

/// ANSI color codes
module Colors =
    let reset = "\x1b[0m"
    let red = "\x1b[31m"
    let green = "\x1b[32m"
    let yellow = "\x1b[33m"
    let blue = "\x1b[34m"
    let magenta = "\x1b[35m"
    let cyan = "\x1b[36m"
    let white = "\x1b[37m"
    let bold = "\x1b[1m"

/// Print with color
let printColored (color: string) (text: string) =
    printf "%s%s%s" color text Colors.reset

/// Print line with color
let printColoredLine (color: string) (text: string) =
    printfn "%s%s%s" color text Colors.reset

// =============================================================================
// Test Result Reporting
// =============================================================================

/// Print test result
let printTestResult (result: TestResult) =
    let statusIcon = if result.Passed then "PASS" else "FAIL"
    let statusColor = if result.Passed then Colors.green else Colors.red

    printf "  ["
    printColored statusColor statusIcon
    printfn "] %s (%.2fms)" result.Name result.Duration.TotalMilliseconds

    match result.Error with
    | Some err ->
        printColoredLine Colors.red (sprintf "       Error: %s" err)
    | None -> ()

/// Print suite result
let printSuiteResult (suite: TestSuiteResult) =
    printfn ""
    printColoredLine Colors.bold (sprintf "Suite: %s" suite.SuiteName)
    printfn "  Duration: %.2fs" suite.Duration.TotalSeconds
    printfn "  Tests: %d total, %d passed, %d failed, %d skipped"
        suite.TotalTests suite.Passed suite.Failed suite.Skipped

    let passRate = float suite.Passed / float suite.TotalTests * 100.0
    let rateColor = if passRate >= 80.0 then Colors.green elif passRate >= 50.0 then Colors.yellow else Colors.red
    printf "  Pass Rate: "
    printColoredLine rateColor (sprintf "%.1f%%" passRate)

    printfn ""
    suite.Tests |> List.iter printTestResult

/// Print run summary
let printRunSummary (summary: TestRunSummary) =
    printfn ""
    printColoredLine Colors.bold "=============================================="
    printColoredLine Colors.bold "            TEST RUN SUMMARY"
    printColoredLine Colors.bold "=============================================="
    printfn ""
    printfn "  Environment: %A" summary.Environment
    printfn "  Server URL:  %s" summary.ServerUrl
    printfn "  Duration:    %.2fs" summary.TotalDuration.TotalSeconds
    printfn ""
    printfn "  Suites:  %d" summary.TotalSuites
    printfn "  Tests:   %d" summary.TotalTests
    printf "  Passed:  "
    printColoredLine Colors.green (string summary.TotalPassed)
    printf "  Failed:  "
    printColoredLine (if summary.TotalFailed > 0 then Colors.red else Colors.green) (string summary.TotalFailed)
    printf "  Skipped: "
    printColoredLine Colors.yellow (string summary.TotalSkipped)
    printfn ""

    let passRate = float summary.TotalPassed / float summary.TotalTests * 100.0
    let rateColor = if passRate >= 80.0 then Colors.green elif passRate >= 50.0 then Colors.yellow else Colors.red
    printf "  Overall Pass Rate: "
    printColoredLine rateColor (sprintf "%.1f%%" passRate)

    printfn ""
    if summary.TotalFailed = 0 then
        printColoredLine Colors.green "  ALL TESTS PASSED!"
    else
        printColoredLine Colors.red (sprintf "  %d TEST(S) FAILED!" summary.TotalFailed)
    printfn ""

// =============================================================================
// JSON Report Generation
// =============================================================================

/// JSON serializer options
let jsonOptions =
    let options = JsonSerializerOptions()
    options.WriteIndented <- true
    options.PropertyNamingPolicy <- JsonNamingPolicy.CamelCase
    options

/// Generate JSON report
let generateJsonReport (summary: TestRunSummary) : string =
    let report = {|
        timestamp = DateTime.UtcNow.ToString("o")
        environment = sprintf "%A" summary.Environment
        serverUrl = summary.ServerUrl
        duration = summary.TotalDuration.TotalSeconds
        summary = {|
            totalSuites = summary.TotalSuites
            totalTests = summary.TotalTests
            passed = summary.TotalPassed
            failed = summary.TotalFailed
            skipped = summary.TotalSkipped
            passRate = float summary.TotalPassed / float summary.TotalTests * 100.0
        |}
        suites = summary.Suites |> List.map (fun s -> {|
            name = s.SuiteName
            duration = s.Duration.TotalSeconds
            totalTests = s.TotalTests
            passed = s.Passed
            failed = s.Failed
            skipped = s.Skipped
            tests = s.Tests |> List.map (fun t -> {|
                name = t.Name
                category = t.Category
                passed = t.Passed
                duration = t.Duration.TotalMilliseconds
                error = t.Error
                timestamp = t.Timestamp.ToString("o")
            |})
        |})
    |}

    JsonSerializer.Serialize(report, jsonOptions)

/// Save JSON report to file
let saveJsonReport (path: string) (summary: TestRunSummary) =
    let json = generateJsonReport summary
    File.WriteAllText(path, json)
    Log.Information("JSON report saved to {Path}", path)

// =============================================================================
// Markdown Report Generation
// =============================================================================

/// Generate Markdown report
let generateMarkdownReport (summary: TestRunSummary) : string =
    let sb = StringBuilder()

    sb.AppendLine("# Indrajaal External Interface Test Report") |> ignore
    sb.AppendLine() |> ignore
    sb.AppendLine(sprintf "**Date**: %s" (DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss"))) |> ignore
    sb.AppendLine(sprintf "**Environment**: %A" summary.Environment) |> ignore
    sb.AppendLine(sprintf "**Server URL**: %s" summary.ServerUrl) |> ignore
    sb.AppendLine(sprintf "**Duration**: %.2fs" summary.TotalDuration.TotalSeconds) |> ignore
    sb.AppendLine() |> ignore

    // Summary table
    sb.AppendLine("## Summary") |> ignore
    sb.AppendLine() |> ignore
    sb.AppendLine("| Metric | Value |") |> ignore
    sb.AppendLine("|--------|-------|") |> ignore
    sb.AppendLine(sprintf "| Total Suites | %d |" summary.TotalSuites) |> ignore
    sb.AppendLine(sprintf "| Total Tests | %d |" summary.TotalTests) |> ignore
    sb.AppendLine(sprintf "| Passed | %d |" summary.TotalPassed) |> ignore
    sb.AppendLine(sprintf "| Failed | %d |" summary.TotalFailed) |> ignore
    sb.AppendLine(sprintf "| Skipped | %d |" summary.TotalSkipped) |> ignore
    let passRate = float summary.TotalPassed / float summary.TotalTests * 100.0
    sb.AppendLine(sprintf "| Pass Rate | %.1f%% |" passRate) |> ignore
    sb.AppendLine() |> ignore

    // Suite details
    sb.AppendLine("## Test Suites") |> ignore
    sb.AppendLine() |> ignore

    for suite in summary.Suites do
        sb.AppendLine(sprintf "### %s" suite.SuiteName) |> ignore
        sb.AppendLine() |> ignore
        sb.AppendLine(sprintf "- **Duration**: %.2fs" suite.Duration.TotalSeconds) |> ignore
        sb.AppendLine(sprintf "- **Tests**: %d passed, %d failed, %d skipped" suite.Passed suite.Failed suite.Skipped) |> ignore
        sb.AppendLine() |> ignore

        // Test table
        sb.AppendLine("| Test | Status | Duration |") |> ignore
        sb.AppendLine("|------|--------|----------|") |> ignore

        for test in suite.Tests do
            let status = if test.Passed then "PASS" else "FAIL"
            sb.AppendLine(sprintf "| %s | %s | %.2fms |" test.Name status test.Duration.TotalMilliseconds) |> ignore

        // Failed test details
        let failedTests = suite.Tests |> List.filter (fun t -> not t.Passed)
        if not (List.isEmpty failedTests) then
            sb.AppendLine() |> ignore
            sb.AppendLine("#### Failed Tests") |> ignore
            sb.AppendLine() |> ignore

            for test in failedTests do
                sb.AppendLine(sprintf "**%s**" test.Name) |> ignore
                match test.Error with
                | Some err -> sb.AppendLine(sprintf "```\n%s\n```" err) |> ignore
                | None -> ()
                sb.AppendLine() |> ignore

        sb.AppendLine() |> ignore

    sb.ToString()

/// Save Markdown report to file
let saveMarkdownReport (path: string) (summary: TestRunSummary) =
    let markdown = generateMarkdownReport summary
    File.WriteAllText(path, markdown)
    Log.Information("Markdown report saved to {Path}", path)

// =============================================================================
// Test Result Aggregation
// =============================================================================

/// Create test result
let createTestResult (name: string) (category: string) (passed: bool) (duration: TimeSpan) (error: string option) : TestResult = {
    Name = name
    Category = category
    Passed = passed
    Duration = duration
    Error = error
    StackTrace = None
    Timestamp = DateTime.UtcNow
}

/// Create suite result from test results
let createSuiteResult (name: string) (tests: TestResult list) (startTime: DateTime) : TestSuiteResult =
    let endTime = DateTime.UtcNow
    {
        SuiteName = name
        Tests = tests
        TotalTests = tests.Length
        Passed = tests |> List.filter (fun t -> t.Passed) |> List.length
        Failed = tests |> List.filter (fun t -> not t.Passed) |> List.length
        Skipped = 0
        Duration = endTime - startTime
        StartedAt = startTime
        CompletedAt = endTime
    }

/// Create run summary from suite results
let createRunSummary (suites: TestSuiteResult list) (env: TestEnvironment) (serverUrl: string) : TestRunSummary =
    let totalTests = suites |> List.sumBy (fun s -> s.TotalTests)
    let totalPassed = suites |> List.sumBy (fun s -> s.Passed)
    let totalFailed = suites |> List.sumBy (fun s -> s.Failed)
    let totalSkipped = suites |> List.sumBy (fun s -> s.Skipped)
    let totalDuration = suites |> List.sumBy (fun s -> s.Duration.TotalSeconds) |> TimeSpan.FromSeconds

    {
        Suites = suites
        TotalSuites = suites.Length
        TotalTests = totalTests
        TotalPassed = totalPassed
        TotalFailed = totalFailed
        TotalSkipped = totalSkipped
        TotalDuration = totalDuration
        Environment = env
        ServerUrl = serverUrl
    }
