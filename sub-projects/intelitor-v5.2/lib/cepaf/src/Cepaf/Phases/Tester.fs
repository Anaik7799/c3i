/// CEPAF Tester Phase Module
/// Version: 2.0.0
/// SC-METRICS-003: Mandatory 16:16 Parallelization for Elixir test execution
/// SC-METRICS-004: Comprehensive test execution metrics
///
/// WHAT: Executes ExUnit test suite with maximum parallelization
/// WHY: Ensures test execution utilizes all available BEAM schedulers (Ω₁)
/// CONSTRAINTS: Patient Mode enabled, no timeout, full scheduler utilization
namespace Cepaf.Phases

open System
open System.Diagnostics
open System.Text.RegularExpressions
open Cepaf
open Cepaf.Infrastructure
open Cepaf.Rop

module Tester =

    // ==========================================================================
    // SC-METRICS-003: MANDATORY PARALLELIZATION ENVIRONMENT VARIABLES
    // ==========================================================================

    /// Mandatory environment variables for SC-METRICS-003 compliance
    /// Ensures maximum parallelization of Elixir test execution
    let mandatoryTestEnvVars : (string * string) list = [
        ("ELIXIR_ERL_OPTIONS", "+fnu +S 16:16 +SDio 16")  // 16 schedulers + 16 dirty I/O
        ("NO_TIMEOUT", "true")                        // Patient Mode: no timeout
        ("PATIENT_MODE", "enabled")                   // Patient Mode flag
        ("INFINITE_PATIENCE", "true")                 // Never interrupt compilation/tests
        ("MIX_OS_DEPS_COMPILE_PARTITION_COUNT", "8")  // Parallel dependency compilation
        ("SKIP_ZENOH_NIF", "0")                       // Enable Zenoh NIF (SC-TEST-005)
        ("MIX_ENV", "test")                           // Ensure test environment
        ("CPUS_LIMIT", "0.7")                         // CPU throttling for container
    ]

    // ==========================================================================
    // SC-METRICS-004: TEST EXECUTION METRICS
    // ==========================================================================

    /// Comprehensive test execution metrics per SC-METRICS-004
    type TestMetrics = {
        StartTime: DateTime
        EndTime: DateTime
        DurationMs: int64
        ExitCode: int
        TestsTotal: int
        TestsPassed: int
        TestsFailed: int
        TestsSkipped: int
        CoveragePercent: float option
        SchedulersOnline: int
        DirtyIOSchedulers: int
        PatientMode: bool
        MemoryUsageMB: int64
        OutputLines: int
        Success: bool
        PhaseTag: string
    }

    /// Parse test metrics from mix test output
    let parseTestOutput (output: string) : int * int * int * float option =
        // Parse test results: "10 tests, 2 failures, 1 skipped"
        let resultPattern = Regex(@"(\d+)\s+tests?,\s*(\d+)\s+failures?(?:,\s*(\d+)\s+skipped)?")
        let resultMatch = resultPattern.Match(output)
        let (total, failed, skipped) =
            if resultMatch.Success then
                let t = Int32.Parse(resultMatch.Groups.[1].Value)
                let f = Int32.Parse(resultMatch.Groups.[2].Value)
                let s = if resultMatch.Groups.[3].Success then Int32.Parse(resultMatch.Groups.[3].Value) else 0
                (t, f, s)
            else
                (0, 0, 0)

        // Parse coverage percentage
        let coveragePattern = Regex(@"Coverage:\s*([\d.]+)%", RegexOptions.IgnoreCase)
        let coverageMatch = coveragePattern.Match(output)
        let coverage =
            if coverageMatch.Success then
                match Double.TryParse(coverageMatch.Groups.[1].Value) with
                | true, v -> Some v
                | false, _ -> None
            else
                None

        (total, failed, skipped, coverage)

    /// Create test metrics from execution
    let createTestMetrics
        (startTime: DateTime)
        (endTime: DateTime)
        (exitCode: int)
        (output: string)
        : TestMetrics =

        let (total, failed, skipped, coverage) = parseTestOutput output
        let lines = output.Split('\n')

        {
            StartTime = startTime
            EndTime = endTime
            DurationMs = int64 (endTime - startTime).TotalMilliseconds
            ExitCode = exitCode
            TestsTotal = total
            TestsPassed = total - failed - skipped
            TestsFailed = failed
            TestsSkipped = skipped
            CoveragePercent = coverage
            SchedulersOnline = 16
            DirtyIOSchedulers = 16
            PatientMode = true
            MemoryUsageMB = 0L
            OutputLines = lines.Length
            Success = exitCode = 0 && failed = 0
            PhaseTag = "TESTER"
        }

    /// Print test metrics summary to console
    let printMetricsSummary (metrics: TestMetrics) : unit =
        printfn ""
        printfn "╔══════════════════════════════════════════════════════════════════╗"
        printfn "║  SC-METRICS-003/004: TESTER PHASE METRICS SUMMARY                ║"
        printfn "╠══════════════════════════════════════════════════════════════════╣"
        printfn "║  Duration:     %7dms                                          ║" metrics.DurationMs
        printfn "║  Tests Total:  %7d                                             ║" metrics.TestsTotal
        printfn "║  Passed:       %7d                                             ║" metrics.TestsPassed
        printfn "║  Failed:       %7d                                             ║" metrics.TestsFailed
        printfn "║  Skipped:      %7d                                             ║" metrics.TestsSkipped
        printfn "║  Schedulers:   %7d online + %d dirty I/O                      ║" metrics.SchedulersOnline metrics.DirtyIOSchedulers
        printfn "║  Patient Mode: %7b                                            ║" metrics.PatientMode
        match metrics.CoveragePercent with
        | Some cov -> printfn "║  Coverage:     %7.2f%%                                           ║" cov
        | None -> printfn "║  Coverage:     N/A                                                ║"
        printfn "║  Status:       %s                                              ║" (if metrics.Success then "SUCCESS" else "FAILURE")
        printfn "╚══════════════════════════════════════════════════════════════════╝"

    // ==========================================================================
    // PHASE EXECUTION
    // ==========================================================================

    /// Build environment variable arguments for podman exec
    let buildEnvArgs () : string list =
        mandatoryTestEnvVars
        |> List.collect (fun (key, value) -> ["-e"; sprintf "%s=%s" key value])

    /// Execute test phase with SC-METRICS-003 parallelization
    let execute (logger: QuadplexLogger) (runner: IProcessRunner) (config: CepaConfig) = asyncResult {
        logger.Info("Starting Phase: TESTER (ExUnit Suite)")
        logger.Info("SC-METRICS-003: 16:16 schedulers + Patient Mode enabled")
        logger.Emit(PhaseStart "TESTER")

        let startTime = DateTime.UtcNow

        // Section 75.2: Max Parallelism Mode with SC-METRICS-003 compliance
        // Build podman exec command with environment variables
        let envArgs = buildEnvArgs()
        let baseArgs = ["exec"] @ envArgs @ [
            "indrajaal-app"
            "mix"
            "test"
            "--parallel"
            "--trace"
            "--cover"
        ]

        logger.Info(sprintf "  Env: ELIXIR_ERL_OPTIONS=\"+S 16:16 +SDio 16\"")
        logger.Info(sprintf "  Env: PATIENT_MODE=enabled, NO_TIMEOUT=true")
        logger.Info(sprintf "  Env: SKIP_ZENOH_NIF=0 (NIF active)")

        let! result = runner.Run("podman", baseArgs, true)

        let endTime = DateTime.UtcNow

        // Parse output and create metrics
        let output = match result with
                     | r when r.StandardOutput <> null -> r.StandardOutput
                     | _ -> ""

        let exitCode = match result with
                       | r -> r.ExitCode

        let metrics = createTestMetrics startTime endTime exitCode output

        // Print metrics summary
        printMetricsSummary metrics

        // Log results
        if metrics.Success then
            logger.Info(sprintf "TESTER: %d tests passed in %dms" metrics.TestsPassed metrics.DurationMs)
        else
            logger.Error(sprintf "TESTER: %d tests failed out of %d" metrics.TestsFailed metrics.TestsTotal)

        logger.Emit(PhaseComplete("TESTER", metrics.DurationMs, metrics.Success))

        if not metrics.Success then
            return! fromResult (Error (ValidationFailed ("TESTER", sprintf "Test failures: %d" metrics.TestsFailed)))
        else
            return ()
    }

    /// Execute test phase with coverage report generation
    let executeWithCoverage (logger: QuadplexLogger) (runner: IProcessRunner) (config: CepaConfig) = asyncResult {
        logger.Info("Starting Phase: TESTER (ExUnit Suite with Coverage)")
        logger.Info("SC-METRICS-003: 16:16 schedulers + Patient Mode enabled")
        logger.Emit(PhaseStart "TESTER_COVERAGE")

        let startTime = DateTime.UtcNow

        // Build podman exec command with environment variables and coverage
        let envArgs = buildEnvArgs()
        let baseArgs = ["exec"] @ envArgs @ [
            "indrajaal-app"
            "mix"
            "test"
            "--parallel"
            "--trace"
            "--cover"
            "--export-coverage"; "default"
        ]

        let! result = runner.Run("podman", baseArgs, true)

        let endTime = DateTime.UtcNow

        // Parse output and create metrics
        let output = match result with
                     | r when r.StandardOutput <> null -> r.StandardOutput
                     | _ -> ""

        let exitCode = match result with
                       | r -> r.ExitCode

        let metrics = createTestMetrics startTime endTime exitCode output

        // Print metrics summary
        printMetricsSummary metrics

        logger.Emit(PhaseComplete("TESTER_COVERAGE", metrics.DurationMs, metrics.Success))

        if not metrics.Success then
            return! fromResult (Error (ValidationFailed ("TESTER_COVERAGE", sprintf "Test failures: %d" metrics.TestsFailed)))
        else
            return ()
    }
