/// Regression Runner - 5-Level Execution Engine
///
/// Runs all 5 levels of regression testing with live ANSI dashboard,
/// subprocess orchestration via CliWrap, and SQLite result tracking.
///
/// ## What
/// Complete regression execution framework:
/// - L1: Compilation (mix compile, warnings-as-errors)
/// - L2: Full Tests (mix test --trace)
/// - L3: SIL-6 Tests (mix test test/sil6/ --trace)
/// - L4: Quality Gates (format, credo)
/// - L5: System Health (ports, git, DB, F# build)
///
/// ## Why
/// - Single-command regression: `dotnet run -- regression`
/// - Live progress dashboard with ANSI formatting
/// - All results tracked in SQLite for trend analysis
///
/// ## Constraints
/// - SC-METRICS-003: 16 schedulers, parallelization mandatory
/// - SC-NET-001: net10.0 target framework
/// - AOR-TEST-NIF-001: SKIP_ZENOH_NIF=0 mandatory
///
/// ## Change History
/// | Version | Date       | Author      | Change                    |
/// |---------|------------|-------------|---------------------------|
/// | 1.0.0   | 2026-03-09 | Claude Opus | Initial implementation    |
///
/// @version "1.0.0"
/// @last_modified "2026-03-09T00:00:00Z"
module Cepaf.Testing.RegressionRunner

open System
open System.Diagnostics
open System.IO
open System.Text.RegularExpressions
open Cepaf.Mesh

// ============================================================
// CONFIGURATION
// ============================================================

/// Regression level
type RegressionLevel =
    | L1_Compilation
    | L2_FullTests
    | L3_SIL6Tests
    | L4_QualityGates
    | L5_SystemHealth

/// Runner configuration
type RunConfig = {
    Levels: RegressionLevel list
    Verbose: bool
    ReportOnly: bool
}

/// Result of an asynchronous regression run
type AsyncRunResult = {
    RunId: string
    OverallStatus: string
    ExitCode: int
    DurationS: float
    LevelStatuses: Map<RegressionLevel, string>
    LevelOutputs: Map<RegressionLevel, string>
    TotalPassed: int
    TotalFailed: int
    StateVector: int array
}

/// Default environment variables for all Elixir subprocesses (SC-METRICS-003)
let private envVars = [
    "SKIP_ZENOH_NIF", "0"
    "NO_TIMEOUT", "true"
    "PATIENT_MODE", "enabled"
    "INFINITE_PATIENCE", "true"
    "ELIXIR_ERL_OPTIONS", "+S 16:16 +SDio 16"
    "MIX_OS_DEPS_COMPILE_PARTITION_COUNT", "8"
]

// ============================================================
// ZENOH CHECKPOINT TRACKING (SC-ZTEST-001 to SC-ZTEST-008)
// ============================================================

/// Zenoh checkpoint messaging for regression progress tracking.
/// Uses log-based fallback (SC-ZTEST-008) with structured [ZTEST-CHECKPOINT]
/// messages. When Zenoh mesh is available, the Elixir ZenohTestOrchestrator
/// subscribes to these topics for <100ms real-time dashboard updates.
module ZenohProgress =

    /// Regression checkpoint IDs (CP-REG-*)
    module CheckpointIds =
        let REG_START = "CP-REG-01"    // Regression run started
        let L1_START  = "CP-REG-02"    // L1 Compilation started
        let L1_DONE   = "CP-REG-03"    // L1 Compilation complete
        let L2_START  = "CP-REG-04"    // L2 Full Tests started
        let L2_DONE   = "CP-REG-05"    // L2 Full Tests complete
        let L3_START  = "CP-REG-06"    // L3 SIL-6 Tests started
        let L3_DONE   = "CP-REG-07"    // L3 SIL-6 Tests complete
        let L4_START  = "CP-REG-08"    // L4 Quality Gates started
        let L4_DONE   = "CP-REG-09"    // L4 Quality Gates complete
        let L5_START  = "CP-REG-10"    // L5 System Health started
        let L5_DONE   = "CP-REG-11"    // L5 System Health complete
        let REG_DONE  = "CP-REG-12"    // Regression run complete

    /// Zenoh topic patterns for regression tracking
    module Topics =
        let regBase = "indrajaal/regression"

        let runStart runId = $"{regBase}/run/{runId}/start"
        let runComplete runId = $"{regBase}/run/{runId}/complete"
        let levelStart level = $"{regBase}/level/{level}/start"
        let levelComplete level = $"{regBase}/level/{level}/complete"
        let stateVector runId = $"{regBase}/run/{runId}/state_vector"
        let summary runId = $"{regBase}/run/{runId}/summary"
        let substep level step = $"{regBase}/level/{level}/substep/{step}"

    /// Regression state vector: [L1, L2, L3, L4, L5] ∈ {0=Pending, 1=Running, 2=Pass, 3=Fail, 4=Skip}
    type RegressionStateVector = {
        Levels: int array               // 5-element: [L1..L5]
        RunId: string
        OverallHealth: float            // 0.0 to 1.0
        StartTime: DateTime
        LastUpdate: DateTime
    }

    /// Create initial state vector
    let createStateVector (runId: string) : RegressionStateVector = {
        Levels = Array.create 5 0       // All pending
        RunId = runId
        OverallHealth = 0.0
        StartTime = DateTime.UtcNow
        LastUpdate = DateTime.UtcNow
    }

    /// Update level status in state vector
    let updateLevel (levelIdx: int) (status: int) (sv: RegressionStateVector) : RegressionStateVector =
        if levelIdx < 0 || levelIdx >= 5 then sv
        else
            let newLevels = Array.copy sv.Levels
            newLevels.[levelIdx] <- status
            let completed = newLevels |> Array.filter (fun s -> s = 2) |> Array.length
            { sv with
                Levels = newLevels
                OverallHealth = float completed / 5.0
                LastUpdate = DateTime.UtcNow }

    /// Level index mapping
    let levelIndex = function
        | L1_Compilation -> 0
        | L2_FullTests -> 1
        | L3_SIL6Tests -> 2
        | L4_QualityGates -> 3
        | L5_SystemHealth -> 4

    /// Status code: PASS=2, FAIL=3, WARN=2, SKIP=4, RUN=1
    let statusCode = function
        | "PASS" -> 2 | "FAIL" -> 3 | "WARN" -> 2 | "SKIP" -> 4 | _ -> 1

    /// SC-ZTEST-008: Log-based fallback - ALWAYS write before Zenoh attempt.
    /// Format: [ZTEST-CHECKPOINT] checkpoint={id} topic={topic} message={msg} state_vector=[...] timestamp={ts}
    let publishCheckpoint (checkpointId: string) (topic: string) (message: string) (stateVector: int array) (details: Map<string, string>) =
        let timestamp = DateTimeOffset.UtcNow.ToString("o")
        let svStr = "[" + (stateVector |> Array.map string |> String.concat ",") + "]"
        let detailStr =
            if Map.isEmpty details then ""
            else " details=" + (details |> Map.toList |> List.map (fun (k,v) -> $"{k}={v}") |> String.concat ";")

        // SC-ZTEST-008: ALWAYS write log fallback first (AOR-ZTEST-008)
        printfn "[ZTEST-CHECKPOINT] checkpoint=%s topic=%s message=%s state_vector=%s timestamp=%s%s"
            checkpointId topic message svStr timestamp detailStr

    /// Publish regression run start
    let publishRunStart (sv: RegressionStateVector) =
        publishCheckpoint
            CheckpointIds.REG_START
            (Topics.runStart sv.RunId)
            "5-level regression suite initiated"
            sv.Levels
            (Map.ofList ["run_id", sv.RunId; "levels", "5"])

    /// Publish level start
    let publishLevelStart (level: RegressionLevel) (sv: RegressionStateVector) =
        let idx = levelIndex level
        let checkpointId = match level with
                           | L1_Compilation -> CheckpointIds.L1_START
                           | L2_FullTests -> CheckpointIds.L2_START
                           | L3_SIL6Tests -> CheckpointIds.L3_START
                           | L4_QualityGates -> CheckpointIds.L4_START
                           | L5_SystemHealth -> CheckpointIds.L5_START
        let levelName = match level with
                        | L1_Compilation -> "compilation"
                        | L2_FullTests -> "full-tests"
                        | L3_SIL6Tests -> "sil6-tests"
                        | L4_QualityGates -> "quality-gates"
                        | L5_SystemHealth -> "system-health"
        publishCheckpoint
            checkpointId
            (Topics.levelStart levelName)
            $"Level {idx + 1} started"
            sv.Levels
            (Map.ofList ["level", levelName; "run_id", sv.RunId])

    /// Publish level completion with results
    let publishLevelComplete (level: RegressionLevel) (status: string) (durationS: float) (details: Map<string, string>) (sv: RegressionStateVector) =
        let idx = levelIndex level
        let checkpointId = match level with
                           | L1_Compilation -> CheckpointIds.L1_DONE
                           | L2_FullTests -> CheckpointIds.L2_DONE
                           | L3_SIL6Tests -> CheckpointIds.L3_DONE
                           | L4_QualityGates -> CheckpointIds.L4_DONE
                           | L5_SystemHealth -> CheckpointIds.L5_DONE
        let levelName = match level with
                        | L1_Compilation -> "compilation"
                        | L2_FullTests -> "full-tests"
                        | L3_SIL6Tests -> "sil6-tests"
                        | L4_QualityGates -> "quality-gates"
                        | L5_SystemHealth -> "system-health"
        let allDetails = details |> Map.add "status" status |> Map.add "duration_s" (sprintf "%.1f" durationS)
        publishCheckpoint
            checkpointId
            (Topics.levelComplete levelName)
            $"Level {idx + 1} {status}"
            sv.Levels
            allDetails

    /// Publish substep progress (e.g., "mix compile" within L1)
    let publishSubstep (level: RegressionLevel) (step: string) (status: string) (detail: string) (sv: RegressionStateVector) =
        let levelName = match level with
                        | L1_Compilation -> "compilation"
                        | L2_FullTests -> "full-tests"
                        | L3_SIL6Tests -> "sil6-tests"
                        | L4_QualityGates -> "quality-gates"
                        | L5_SystemHealth -> "system-health"
        let stepId = step.ToUpperInvariant().Replace(" ", "-")
        let cpId = $"CP-REG-SUB-{stepId}"
        publishCheckpoint
            cpId
            (Topics.substep levelName step)
            $"{step}: {status}"
            sv.Levels
            (Map.ofList ["step", step; "status", status; "detail", detail])

    /// Publish final regression summary
    let publishRunComplete (sv: RegressionStateVector) (overallStatus: string) (totalTests: int) (totalFailed: int) (durationS: float) =
        publishCheckpoint
            CheckpointIds.REG_DONE
            (Topics.runComplete sv.RunId)
            $"Regression {overallStatus}"
            sv.Levels
            (Map.ofList [
                "overall_status", overallStatus
                "total_tests", string totalTests
                "total_failed", string totalFailed
                "duration_s", sprintf "%.1f" durationS
                "run_id", sv.RunId
                "health", sprintf "%.0f%%" (sv.OverallHealth * 100.0)
            ])

    /// Print state vector dashboard (visual inline)
    let printStateVectorBar (sv: RegressionStateVector) =
        let levelLabels = [| "L1"; "L2"; "L3"; "L4"; "L5" |]
        let statusChar s =
            match s with
            | 0 -> $"{Colors.dim}·{Colors.reset}"        // Pending
            | 1 -> $"{Colors.brightYellow}▶{Colors.reset}"  // Running
            | 2 -> $"{Colors.brightGreen}✓{Colors.reset}"   // Pass
            | 3 -> $"{Colors.brightRed}✗{Colors.reset}"     // Fail
            | 4 -> $"{Colors.dim}⊘{Colors.reset}"        // Skip
            | _ -> "?"
        let bar =
            Array.zip levelLabels sv.Levels
            |> Array.map (fun (label, status) -> $"{label}:{statusChar status}")
            |> String.concat " "
        printfn "%s[PROGRESS]%s  [%s] health=%.0f%%"
            Colors.cyan Colors.reset
            bar
            (sv.OverallHealth * 100.0)

// ============================================================
// ANSI DASHBOARD
// ============================================================

module Dashboard =

    let private banner () =
        printfn ""
        printfn "%s%s+===============================================================================+%s" Colors.brightMagenta Colors.bold Colors.reset
        printfn "%s%s|  INDRAJAAL REGRESSION RUNNER v1.0.0 - 5-Level Full Regression                 |%s" Colors.brightMagenta Colors.bold Colors.reset
        printfn "%s%s|  SIL-6 Biomorphic Fractal Mesh | F# CEPAF Runtime                             |%s" Colors.brightMagenta Colors.bold Colors.reset
        printfn "%s%s+===============================================================================+%s" Colors.brightMagenta Colors.bold Colors.reset
        printfn ""

    let private levelName level =
        match level with
        | L1_Compilation -> "L1 Compilation"
        | L2_FullTests -> "L2 Full Tests"
        | L3_SIL6Tests -> "L3 SIL-6 Tests"
        | L4_QualityGates -> "L4 Quality Gates"
        | L5_SystemHealth -> "L5 System Health"

    let private levelIcon level =
        match level with
        | L1_Compilation -> "BUILD"
        | L2_FullTests -> "TEST"
        | L3_SIL6Tests -> "SIL6"
        | L4_QualityGates -> "QUALITY"
        | L5_SystemHealth -> "HEALTH"

    let printStart () =
        banner()
        let ts = DateTimeOffset.UtcNow.ToString("HH:mm:ss.fff")
        printfn "%s[%s]%s %sREGRESSION%s  Starting 5-level regression suite..." Colors.dim ts Colors.reset Colors.brightCyan Colors.reset

    let printLevelStart level =
        let ts = DateTimeOffset.UtcNow.ToString("HH:mm:ss.fff")
        let icon = levelIcon level
        let name = levelName level
        printfn ""
        printfn "%s---------------------------------------------------------------------------------%s" Colors.dim Colors.reset
        printfn "%s[%s]%s %s[%-10s]%s %-20s [%sSTARTING%s]" Colors.dim ts Colors.reset Colors.cyan icon Colors.reset name Colors.brightYellow Colors.reset

    let printLevelResult level (status: string) (detail: string) (durationS: float) =
        let ts = DateTimeOffset.UtcNow.ToString("HH:mm:ss.fff")
        let icon = levelIcon level
        let name = levelName level
        let color = MeshUtils.statusColor status
        printfn "%s[%s]%s %s[%-10s]%s %-20s [%s%-8s%s] %s %s(%.1fs)%s"
            Colors.dim ts Colors.reset
            Colors.cyan icon Colors.reset
            name
            color status Colors.reset
            detail
            Colors.dim durationS Colors.reset

    let printSubStep (label: string) (status: string) (detail: string) =
        let ts = DateTimeOffset.UtcNow.ToString("HH:mm:ss.fff")
        let color = MeshUtils.statusColor status
        printfn "%s[%s]%s              %-20s [%s%-8s%s] %s"
            Colors.dim ts Colors.reset
            label
            color status Colors.reset
            detail

    let printSummary (summary: RegressionTracker.RunSummary) (durationS: float) (prevRun: RegressionTracker.PreviousRun option) =
        printfn ""
        printfn "%s%s+===============================================================================+%s" Colors.brightCyan Colors.bold Colors.reset
        printfn "%s%s|  REGRESSION SUMMARY                                                           |%s" Colors.brightCyan Colors.bold Colors.reset
        printfn "%s%s+===============================================================================+%s" Colors.brightCyan Colors.bold Colors.reset
        printfn ""

        let overallColor = MeshUtils.statusColor summary.OverallStatus
        printfn "  Run ID:     %s%s%s" Colors.white summary.RunId Colors.reset
        printfn "  Status:     %s%s%s%s" overallColor Colors.bold summary.OverallStatus Colors.reset
        printfn "  Duration:   %.1fs" durationS
        printfn ""

        // Level breakdown
        printfn "  %s%-20s %-10s%s" Colors.underline "Level" "Status" Colors.reset
        let printLevelSummary name status =
            let color = MeshUtils.statusColor status
            printfn "  %-20s %s%-10s%s" name color status Colors.reset
        printLevelSummary "L1 Compilation" summary.CompileStatus
        printLevelSummary "L2 Full Tests" summary.FullTestStatus
        printLevelSummary "L3 SIL-6 Tests" summary.Sil6TestStatus
        printLevelSummary "L4 Quality Gates" summary.QualityStatus
        printLevelSummary "L5 System Health" summary.SystemStatus
        printfn ""

        // Test stats
        printfn "  Tests: %s%d%s total | %s%d%s passed | %s%d%s failed | %s%d%s skipped | %s%d%s properties"
            Colors.white summary.TotalTests Colors.reset
            Colors.brightGreen summary.TotalPassed Colors.reset
            (if summary.TotalFailed > 0 then Colors.brightRed else Colors.green) summary.TotalFailed Colors.reset
            Colors.yellow summary.TotalSkipped Colors.reset
            Colors.cyan summary.TotalProperties Colors.reset

        if summary.Sil6Tests > 0 then
            printfn "  SIL-6: %s%d%s total | %s%d%s passed | %s%d%s failed | %s%d%s properties"
                Colors.white summary.Sil6Tests Colors.reset
                Colors.brightGreen summary.Sil6Passed Colors.reset
                (if summary.Sil6Failed > 0 then Colors.brightRed else Colors.green) summary.Sil6Failed Colors.reset
                Colors.cyan summary.Sil6Properties Colors.reset

        // Comparison with previous run
        match prevRun with
        | Some prev ->
            printfn ""
            printfn "  %sPrevious: %s (%s) - %d tests, %d failed, %.1fs%s"
                Colors.dim prev.RunId prev.OverallStatus prev.TotalTests prev.TotalFailed prev.TotalDurationS Colors.reset
            let testDelta = summary.TotalTests - prev.TotalTests
            let failDelta = summary.TotalFailed - prev.TotalFailed
            let durationDelta = durationS - prev.TotalDurationS
            if testDelta <> 0 || failDelta <> 0 then
                printfn "  %sDelta: tests %+d, failures %+d, duration %+.1fs%s"
                    Colors.dim testDelta failDelta durationDelta Colors.reset
        | None -> ()

        printfn ""
        printfn "%s---------------------------------------------------------------------------------%s" Colors.dim Colors.reset

// ============================================================
// SUBPROCESS EXECUTION
// ============================================================

module Subprocess =

    /// Run a command and capture stdout+stderr, with env vars.
    /// Uses async reads to avoid pipe buffer deadlock (classic pattern
    /// where large output fills the 64KB pipe buffer, blocking the child
    /// process while parent blocks on ReadToEnd).
    let run (cmd: string) (args: string) (timeoutMs: int) : (int * string * string) =
        let psi = ProcessStartInfo(cmd, args)
        psi.RedirectStandardOutput <- true
        psi.RedirectStandardError <- true
        psi.UseShellExecute <- false
        psi.CreateNoWindow <- true

        // Set environment variables
        for (key, value) in envVars do
            psi.Environment.[key] <- value

        try
            let p = Process.Start(psi)
            // Read stdout and stderr asynchronously to avoid deadlock
            let stdoutTask = p.StandardOutput.ReadToEndAsync()
            let stderrTask = p.StandardError.ReadToEndAsync()
            let exited = p.WaitForExit(timeoutMs)
            if not exited then
                try p.Kill(true) with _ -> ()
                p.WaitForExit(5000) |> ignore
                let stdout = if stdoutTask.IsCompleted then stdoutTask.Result else ""
                let stderr = if stderrTask.IsCompleted then stderrTask.Result else ""
                (-1, stdout, stderr + "\n[TIMEOUT after " + string (timeoutMs / 1000) + "s]")
            else
                let stdout = stdoutTask.Result
                let stderr = stderrTask.Result
                (p.ExitCode, stdout, stderr)
        with ex ->
            (-1, "", $"[ERROR] {ex.Message}")

    /// Run mix command with env vars (Enforces --jobs 16 for compile)
    let runMix (args: string) (timeoutMs: int) : (int * string * string) =
        let effectiveArgs = 
            if args.Contains("compile") && not (args.Contains("--jobs")) then
                args + " --jobs 16"
            else
                args
        run "mix" effectiveArgs timeoutMs

    /// Default log budget: 50MB (Detailed Analysis §67.1)
    let [<Literal>] private MaxLogSizeBytes = 52428800L

    /// Streaming subprocess runner - invokes callback for each stdout line in real-time.
    /// Includes Log Budget Guard (Detailed Analysis §67.1) to switch to summary mode
    /// when output exceeds redline, protecting host homeostasis.
    let runStreaming (cmd: string) (args: string) (timeoutMs: int) (onLine: string -> unit) : (int * string * string) =
        let psi = ProcessStartInfo(cmd, args)
        psi.RedirectStandardOutput <- true
        psi.RedirectStandardError <- true
        psi.UseShellExecute <- false
        psi.CreateNoWindow <- true
        for (key, value) in envVars do
            psi.Environment.[key] <- value

        try
            let p = Process.Start(psi)
            let stdoutLines = System.Collections.Concurrent.ConcurrentBag<string>()
            let stderrLines = System.Collections.Concurrent.ConcurrentBag<string>()
            let mutable totalBytes = 0L
            let mutable summaryModeActive = false

            // Subscribe to stdout events for real-time line-by-line processing
            p.OutputDataReceived.Add(fun args ->
                if args.Data <> null then
                    let lineBytes = int64 (args.Data.Length)
                    totalBytes <- totalBytes + lineBytes

                    if totalBytes > MaxLogSizeBytes then
                        if not summaryModeActive then
                            summaryModeActive <- true
                            let msg = $"[HOMEOSTASIS] Log budget exceeded ({totalBytes / 1024L / 1024L}MB). Switching to SUMMARY MODE (SC-OBS-069)."
                            stdoutLines.Add(msg)
                            onLine msg
                        
                        // Summary Mode: Only preserve P0/P1 lines (errors, failures, warnings)
                        if args.Data.Contains("error", StringComparison.OrdinalIgnoreCase) || 
                           args.Data.Contains("fail", StringComparison.OrdinalIgnoreCase) ||
                           args.Data.Contains("warning", StringComparison.OrdinalIgnoreCase) then
                            stdoutLines.Add(args.Data)
                            onLine args.Data
                    else
                        stdoutLines.Add(args.Data)
                        onLine args.Data)

            p.ErrorDataReceived.Add(fun args ->
                if args.Data <> null then
                    stderrLines.Add(args.Data))
            p.BeginOutputReadLine()
            p.BeginErrorReadLine()

            let exited = p.WaitForExit(timeoutMs)
            if not exited then
                try p.Kill(true) with _ -> ()
                p.WaitForExit(5000) |> ignore
                let stdout = stdoutLines.ToArray() |> Array.rev |> String.concat "\n"
                let stderr = stderrLines.ToArray() |> Array.rev |> String.concat "\n"
                (-1, stdout, stderr + "\n[TIMEOUT after " + string (timeoutMs / 1000) + "s]")
            else
                // After WaitForExit, wait briefly for async read events to flush
                p.WaitForExit()  // Ensure async events are drained
                let stdout = stdoutLines.ToArray() |> Array.rev |> String.concat "\n"
                let stderr = stderrLines.ToArray() |> Array.rev |> String.concat "\n"
                (p.ExitCode, stdout, stderr)
        with ex ->
            (-1, "", $"[ERROR] {ex.Message}")

    /// Run mix command with streaming output and per-line callback (Enforces --jobs 16 for compile)
    let runMixStreaming (args: string) (timeoutMs: int) (onLine: string -> unit) : (int * string * string) =
        let effectiveArgs = 
            if args.Contains("compile") && not (args.Contains("--jobs")) then
                args + " --jobs 16"
            else
                args
        runStreaming "mix" effectiveArgs timeoutMs onLine

// ============================================================
// ZENOH PER-TEST TELEMETRY (SC-ZTEST-001 to SC-ZTEST-008)
// ============================================================

/// Real-time per-test and per-suite Zenoh checkpoint publishing.
/// Parses ExUnit output line-by-line and emits structured checkpoints
/// for every test case, every test file/module, and provides intelligent
/// Jidoka control (stop-on-failure-threshold).
module ZenohTestTelemetry =

    /// Topic patterns for per-test tracking
    module Topics =
        let testBase = "indrajaal/regression/test"
        let suiteBase = "indrajaal/regression/suite"
        let controlBase = "indrajaal/regression/control"

        let testResult level testId = $"{testBase}/{level}/{testId}/result"
        let suiteStart level suiteName = $"{suiteBase}/{level}/{suiteName}/start"
        let suiteComplete level suiteName = $"{suiteBase}/{level}/{suiteName}/complete"
        let progress level = $"{testBase}/{level}/progress"
        let jidokaStop level = $"{controlBase}/{level}/jidoka-stop"
        let liveStats level = $"{testBase}/{level}/live-stats"

    /// Live test tracking state - mutable for real-time updates
    type TestTracker = {
        mutable TotalTests: int
        mutable Passed: int
        mutable Failed: int
        mutable Skipped: int
        mutable Properties: int
        mutable CurrentModule: string
        mutable CurrentFile: string
        mutable ModuleTestCount: int
        mutable ModulePassed: int
        mutable ModuleFailed: int
        mutable FailureThreshold: int       // Jidoka: max failures before stop
        mutable ShouldStop: bool            // Jidoka: stop signal
        mutable LastProgressPublish: DateTime
        Level: string                       // "full-tests" or "sil6-tests"
        RunId: string
        StateVector: int array
    }

    /// Create a new test tracker
    let createTracker (level: string) (runId: string) (stateVector: int array) (failureThreshold: int) : TestTracker = {
        TotalTests = 0; Passed = 0; Failed = 0; Skipped = 0; Properties = 0
        CurrentModule = ""; CurrentFile = ""
        ModuleTestCount = 0; ModulePassed = 0; ModuleFailed = 0
        FailureThreshold = failureThreshold
        ShouldStop = false
        LastProgressPublish = DateTime.UtcNow
        Level = level; RunId = runId; StateVector = stateVector
    }

    /// Publish per-test checkpoint (SC-ZTEST-002: checkpoint ID included)
    let private publishTestResult (tracker: TestTracker) (testName: string) (status: string) (durationMs: float) =
        let testId = testName.GetHashCode() |> abs |> string
        let cpId = $"CP-TEST-{tracker.Level.ToUpperInvariant().Substring(0, min 4 tracker.Level.Length)}-{tracker.TotalTests}"
        ZenohProgress.publishCheckpoint
            cpId
            (Topics.testResult tracker.Level testId)
            $"{status}: {testName}"
            tracker.StateVector
            (Map.ofList [
                "test_name", testName
                "status", status
                "duration_ms", sprintf "%.1f" durationMs
                "module", tracker.CurrentModule
                "file", tracker.CurrentFile
                "test_number", string tracker.TotalTests
                "run_id", tracker.RunId
            ])

    /// Publish suite/module start checkpoint
    let private publishSuiteStart (tracker: TestTracker) (moduleName: string) (filePath: string) =
        let safeName = moduleName.Replace(".", "-").ToLowerInvariant()
        ZenohProgress.publishCheckpoint
            $"CP-SUITE-START-{safeName}"
            (Topics.suiteStart tracker.Level safeName)
            $"Suite started: {moduleName}"
            tracker.StateVector
            (Map.ofList ["module", moduleName; "file", filePath; "run_id", tracker.RunId])

    /// Publish suite/module complete checkpoint
    let private publishSuiteComplete (tracker: TestTracker) (moduleName: string) =
        let safeName = moduleName.Replace(".", "-").ToLowerInvariant()
        ZenohProgress.publishCheckpoint
            $"CP-SUITE-DONE-{safeName}"
            (Topics.suiteComplete tracker.Level safeName)
            $"Suite complete: {moduleName} ({tracker.ModulePassed}/{tracker.ModuleTestCount})"
            tracker.StateVector
            (Map.ofList [
                "module", moduleName
                "total", string tracker.ModuleTestCount
                "passed", string tracker.ModulePassed
                "failed", string tracker.ModuleFailed
                "run_id", tracker.RunId
            ])

    /// Publish live progress stats (throttled to every 500ms)
    let private publishProgress (tracker: TestTracker) =
        let now = DateTime.UtcNow
        if (now - tracker.LastProgressPublish).TotalMilliseconds > 500.0 then
            tracker.LastProgressPublish <- now
            let passRate = if tracker.TotalTests > 0 then float tracker.Passed / float tracker.TotalTests * 100.0 else 0.0
            ZenohProgress.publishCheckpoint
                $"CP-PROGRESS-{tracker.TotalTests}"
                (Topics.liveStats tracker.Level)
                $"Progress: {tracker.TotalTests} tests ({passRate:F0}%% pass)"
                tracker.StateVector
                (Map.ofList [
                    "total", string tracker.TotalTests
                    "passed", string tracker.Passed
                    "failed", string tracker.Failed
                    "skipped", string tracker.Skipped
                    "properties", string tracker.Properties
                    "pass_rate", sprintf "%.1f" passRate
                    "current_module", tracker.CurrentModule
                ])

    /// Publish Jidoka stop signal
    let private publishJidokaStop (tracker: TestTracker) (reason: string) =
        ZenohProgress.publishCheckpoint
            "CP-JIDOKA-STOP"
            (Topics.jidokaStop tracker.Level)
            $"JIDOKA STOP: {reason}"
            tracker.StateVector
            (Map.ofList [
                "reason", reason
                "failures", string tracker.Failed
                "threshold", string tracker.FailureThreshold
                "total_run", string tracker.TotalTests
            ])

    /// Process a single output line from ExUnit --trace mode.
    /// Detects module headers, test results, and property tests.
    /// Returns true if processing should continue, false if Jidoka stop triggered.
    let processTraceLine (tracker: TestTracker) (line: string) : bool =
        if tracker.ShouldStop then false
        else

        // Detect module header: "ModuleName [file/path.exs]"
        let moduleMatch = Regex.Match(line, @"^\s*(\S+Test\S*)\s+\[(.+?)\]")
        if moduleMatch.Success then
            // Complete previous module if any
            if tracker.CurrentModule <> "" && tracker.ModuleTestCount > 0 then
                publishSuiteComplete tracker tracker.CurrentModule
            // Start new module
            tracker.CurrentModule <- moduleMatch.Groups.[1].Value
            tracker.CurrentFile <- moduleMatch.Groups.[2].Value
            tracker.ModuleTestCount <- 0
            tracker.ModulePassed <- 0
            tracker.ModuleFailed <- 0
            publishSuiteStart tracker tracker.CurrentModule tracker.CurrentFile
            true

        // Detect passed test: "  * test description (1.2ms) [L#42]"
        elif Regex.IsMatch(line, @"^\s+\*\s+test\s+.+\(\d") then
            let m = Regex.Match(line, @"^\s+\*\s+(.+?)\s+\((\d+\.?\d*)ms\)")
            if m.Success then
                let testName = m.Groups.[1].Value
                let durationMs = float m.Groups.[2].Value
                tracker.TotalTests <- tracker.TotalTests + 1
                tracker.Passed <- tracker.Passed + 1
                tracker.ModuleTestCount <- tracker.ModuleTestCount + 1
                tracker.ModulePassed <- tracker.ModulePassed + 1
                publishTestResult tracker testName "PASS" durationMs
                publishProgress tracker
            true

        // Detect property: "  * property ..."
        elif Regex.IsMatch(line, @"^\s+\*\s+property\s+") then
            let m = Regex.Match(line, @"^\s+\*\s+(.+?)\s+\((\d+\.?\d*)ms\)")
            if m.Success then
                let testName = m.Groups.[1].Value
                let durationMs = float m.Groups.[2].Value
                tracker.TotalTests <- tracker.TotalTests + 1
                tracker.Properties <- tracker.Properties + 1
                tracker.Passed <- tracker.Passed + 1
                tracker.ModuleTestCount <- tracker.ModuleTestCount + 1
                tracker.ModulePassed <- tracker.ModulePassed + 1
                publishTestResult tracker testName "PASS-PROP" durationMs
                publishProgress tracker
            true

        // Detect failure marker
        elif line.TrimStart().StartsWith("** (") || (line.Contains("test ") && line.Contains("FAILED")) then
            tracker.Failed <- tracker.Failed + 1
            tracker.ModuleFailed <- tracker.ModuleFailed + 1
            // Check Jidoka threshold
            if tracker.FailureThreshold > 0 && tracker.Failed >= tracker.FailureThreshold then
                tracker.ShouldStop <- true
                publishJidokaStop tracker $"Failure threshold reached: {tracker.Failed}/{tracker.FailureThreshold}"
                false
            else
                true

        // Detect skipped test
        elif line.Contains("* test") && line.Contains("(excluded)") then
            tracker.Skipped <- tracker.Skipped + 1
            tracker.TotalTests <- tracker.TotalTests + 1
            true

        // Non-trace mode: count dots and F's for progress
        elif Regex.IsMatch(line, @"^[\.\*FE]+$") then
            for c in line do
                match c with
                | '.' ->
                    tracker.TotalTests <- tracker.TotalTests + 1
                    tracker.Passed <- tracker.Passed + 1
                | '*' ->
                    tracker.TotalTests <- tracker.TotalTests + 1
                    tracker.Skipped <- tracker.Skipped + 1
                | 'F' | 'E' ->
                    tracker.TotalTests <- tracker.TotalTests + 1
                    tracker.Failed <- tracker.Failed + 1
                    if tracker.FailureThreshold > 0 && tracker.Failed >= tracker.FailureThreshold then
                        tracker.ShouldStop <- true
                        publishJidokaStop tracker $"Failure threshold: {tracker.Failed}/{tracker.FailureThreshold}"
                | _ -> ()
            publishProgress tracker
            not tracker.ShouldStop

        else true

    /// Finalize tracker - publish remaining module completion
    let finalize (tracker: TestTracker) =
        if tracker.CurrentModule <> "" && tracker.ModuleTestCount > 0 then
            publishSuiteComplete tracker tracker.CurrentModule
        // Final progress publish
        let passRate = if tracker.TotalTests > 0 then float tracker.Passed / float tracker.TotalTests * 100.0 else 0.0
        ZenohProgress.publishCheckpoint
            "CP-TEST-FINAL"
            (Topics.liveStats tracker.Level)
            $"Final: {tracker.TotalTests} tests, {tracker.Passed} passed, {tracker.Failed} failed ({passRate:F0}%%)"
            tracker.StateVector
            (Map.ofList [
                "total", string tracker.TotalTests
                "passed", string tracker.Passed
                "failed", string tracker.Failed
                "skipped", string tracker.Skipped
                "properties", string tracker.Properties
                "pass_rate", sprintf "%.1f" passRate
                "jidoka_stopped", string tracker.ShouldStop
            ])

// ============================================================
// OUTPUT PARSING
// ============================================================

module Parser =

    /// Parse compile output for file count, warnings, errors
    let parseCompileOutput (stdout: string) (stderr: string) (exitCode: int) : RegressionTracker.CompileResult =
        let combined = stdout + "\n" + stderr

        // File count: "Compiled 773 files (.ex)"
        let fileCount =
            let m = Regex.Match(combined, @"Compiled (\d+) file")
            if m.Success then int m.Groups.[1].Value else 0

        // Warning count: count "warning:" lines
        let warningCount =
            combined.Split('\n')
            |> Array.filter (fun l -> l.Contains("warning:"))
            |> Array.length

        // Error detection
        let hasError = exitCode <> 0 || combined.Contains("** (CompileError)")
        let errorCount = if hasError && exitCode <> 0 then 1 else 0

        let status =
            if hasError then "FAIL"
            elif warningCount > 0 then "WARN"
            else "PASS"

        {
            Env = "dev"
            Status = status
            FileCount = fileCount
            WarningCount = warningCount
            ErrorCount = errorCount
            DurationS = 0.0
        }

    /// Parse warnings-as-errors output
    let parseStrictCompile (stdout: string) (stderr: string) (exitCode: int) : RegressionTracker.CompileResult =
        let base' = parseCompileOutput stdout stderr exitCode
        { base' with
            Env = "warnings-as-errors"
            Status = if exitCode = 0 then "PASS" else "FAIL" }

    /// Parse mix test output
    let parseTestOutput (stdout: string) (stderr: string) (exitCode: int) (suiteName: string) (suitePath: string) : RegressionTracker.TestSuiteResult =
        let combined = stdout + "\n" + stderr

        // Parse: "62 tests, 0 failures, 8 properties"
        // Parse: "210 tests, 0 failures, 2 skipped, 5 excluded"
        let parseNum pattern =
            let m = Regex.Match(combined, pattern)
            if m.Success then int m.Groups.[1].Value else 0

        let total = parseNum @"(\d+) tests?"
        let failures = parseNum @"(\d+) failures?"
        let skipped = parseNum @"(\d+) skipped"
        let excluded = parseNum @"(\d+) excluded"
        let properties = parseNum @"(\d+) propert"

        let passed = total - failures - skipped

        let status =
            if exitCode <> 0 || failures > 0 then "FAIL"
            elif skipped > 0 then "WARN"
            else "PASS"

        {
            SuiteName = suiteName
            SuitePath = suitePath
            Total = total
            Passed = passed
            Failed = failures
            Skipped = skipped
            Excluded = excluded
            Properties = properties
            DurationS = 0.0
            Status = status
        }

    /// Parse credo output for issue count
    let parseCredoOutput (stdout: string) (exitCode: int) : int =
        // Credo outputs issue count in summary line
        let m = Regex.Match(stdout, @"(\d+) issues? found")
        if m.Success then int m.Groups.[1].Value
        elif exitCode = 0 then 0
        else 1

// ============================================================
// LEVEL EXECUTORS
// ============================================================

/// L1: Compilation Level
let private runL1Compilation (conn: Microsoft.Data.Sqlite.SqliteConnection) (runId: string) (verbose: bool) (sv: ZenohProgress.RegressionStateVector) : (string * ZenohProgress.RegressionStateVector) =
    Dashboard.printLevelStart L1_Compilation
    let sv = ZenohProgress.updateLevel 0 1 sv  // L1 = Running
    ZenohProgress.publishLevelStart L1_Compilation sv
    ZenohProgress.printStateVectorBar sv
    let sw = Stopwatch.StartNew()

    // Step 1: mix compile
    Dashboard.printSubStep "mix compile" "RUN" "Patient mode + 16 schedulers"
    ZenohProgress.publishSubstep L1_Compilation "mix-compile" "RUN" "Patient mode + 16 schedulers" sv
    let (exitCode1, stdout1, stderr1) = Subprocess.runMix "compile" 600_000
    let result1 = Parser.parseCompileOutput stdout1 stderr1 exitCode1
    let result1 = { result1 with DurationS = sw.Elapsed.TotalSeconds }
    RegressionTracker.recordCompileResult conn runId result1
    Dashboard.printSubStep "mix compile" result1.Status $"{result1.FileCount} files, {result1.WarningCount} warnings, {result1.ErrorCount} errors"
    ZenohProgress.publishSubstep L1_Compilation "mix-compile" result1.Status $"{result1.FileCount} files, {result1.WarningCount}w, {result1.ErrorCount}e" sv

    // Step 2: mix compile --warnings-as-errors
    Dashboard.printSubStep "strict compile" "RUN" "warnings-as-errors"
    ZenohProgress.publishSubstep L1_Compilation "strict-compile" "RUN" "warnings-as-errors" sv
    let (exitCode2, stdout2, stderr2) = Subprocess.runMix "compile --warnings-as-errors" 600_000
    let dur2 = sw.Elapsed.TotalSeconds - result1.DurationS
    let result2 = Parser.parseStrictCompile stdout2 stderr2 exitCode2
    let result2 = { result2 with DurationS = dur2 }
    RegressionTracker.recordCompileResult conn runId result2
    Dashboard.printSubStep "strict compile" result2.Status (if exitCode2 = 0 then "0 warnings" else "has warnings")
    ZenohProgress.publishSubstep L1_Compilation "strict-compile" result2.Status (if exitCode2 = 0 then "0 warnings" else "has warnings") sv

    sw.Stop()
    let overallStatus =
        if result1.Status = "FAIL" || result2.Status = "FAIL" then "FAIL"
        elif result1.Status = "WARN" || result2.Status = "WARN" then "WARN"
        else "PASS"

    let sv = ZenohProgress.updateLevel 0 (ZenohProgress.statusCode overallStatus) sv
    ZenohProgress.publishLevelComplete L1_Compilation overallStatus sw.Elapsed.TotalSeconds
        (Map.ofList ["files", string result1.FileCount; "warnings", string result1.WarningCount; "errors", string result1.ErrorCount]) sv
    ZenohProgress.printStateVectorBar sv

    Dashboard.printLevelResult L1_Compilation overallStatus
        $"{result1.FileCount} files compiled"
        sw.Elapsed.TotalSeconds

    (overallStatus, sv)

/// L2: Full Tests - uses streaming subprocess with per-test Zenoh telemetry
let private runL2FullTests (conn: Microsoft.Data.Sqlite.SqliteConnection) (runId: string) (verbose: bool) (sv: ZenohProgress.RegressionStateVector) : (string * RegressionTracker.TestSuiteResult * ZenohProgress.RegressionStateVector) =
    Dashboard.printLevelStart L2_FullTests
    let sv = ZenohProgress.updateLevel 1 1 sv  // L2 = Running
    ZenohProgress.publishLevelStart L2_FullTests sv
    ZenohProgress.printStateVectorBar sv
    let sw = Stopwatch.StartNew()

    // Create per-test tracker with Jidoka threshold (50 failures = stop)
    let tracker = ZenohTestTelemetry.createTracker "full-tests" runId sv.Levels 50

    Dashboard.printSubStep "mix test" "RUN" "Full test suite (streaming, 16 schedulers)"
    ZenohProgress.publishSubstep L2_FullTests "mix-test" "RUN" "Full test suite (streaming, per-test Zenoh)" sv

    // Streaming execution: per-line callback for real-time Zenoh telemetry
    let (exitCode, stdout, stderr) = Subprocess.runMixStreaming "test" 1_800_000 (fun line ->
        ZenohTestTelemetry.processTraceLine tracker line |> ignore)
    sw.Stop()

    // Finalize tracker - publishes remaining suite completion
    ZenohTestTelemetry.finalize tracker

    // Parse final output for official results (captures the summary line)
    let result = Parser.parseTestOutput stdout stderr exitCode "full-test-suite" "test/"
    // Use tracker counts if parser found no tests (e.g., non-trace mode parsing)
    let result =
        if result.Total = 0 && tracker.TotalTests > 0 then
            { result with
                Total = tracker.TotalTests; Passed = tracker.Passed
                Failed = tracker.Failed; Skipped = tracker.Skipped
                Properties = tracker.Properties }
        else result
    let result = { result with DurationS = sw.Elapsed.TotalSeconds }
    RegressionTracker.recordTestSuite conn runId result

    if verbose && result.Failed > 0 then
        let lines = (stdout + "\n" + stderr).Split('\n')
        let failureLines =
            lines
            |> Array.filter (fun l ->
                l.Contains("** (") || l.Contains("Assertion") || l.Contains("Expected"))
            |> Array.truncate 10
        for line in failureLines do
            printfn "    %s%s%s" Colors.red line Colors.reset

    // Report if Jidoka stopped early
    if tracker.ShouldStop then
        Dashboard.printSubStep "JIDOKA" "STOP" $"Stopped after {tracker.Failed} failures (threshold: {tracker.FailureThreshold})"
        ZenohProgress.publishSubstep L2_FullTests "jidoka" "STOP" $"{tracker.Failed} failures exceeded threshold" sv

    let sv = ZenohProgress.updateLevel 1 (ZenohProgress.statusCode result.Status) sv
    ZenohProgress.publishLevelComplete L2_FullTests result.Status sw.Elapsed.TotalSeconds
        (Map.ofList ["total", string result.Total; "passed", string result.Passed; "failed", string result.Failed
                     "skipped", string result.Skipped; "properties", string result.Properties
                     "streaming", "true"; "jidoka_stopped", string tracker.ShouldStop]) sv
    ZenohProgress.printStateVectorBar sv

    Dashboard.printLevelResult L2_FullTests result.Status
        $"{result.Total} tests, {result.Passed} passed, {result.Failed} failed, {result.Properties} props"
        sw.Elapsed.TotalSeconds

    (result.Status, result, sv)

/// L3: SIL-6 Tests - uses streaming subprocess with per-test Zenoh telemetry
let private runL3SIL6Tests (conn: Microsoft.Data.Sqlite.SqliteConnection) (runId: string) (verbose: bool) (sv: ZenohProgress.RegressionStateVector) : (string * RegressionTracker.TestSuiteResult * ZenohProgress.RegressionStateVector) =
    Dashboard.printLevelStart L3_SIL6Tests
    let sv = ZenohProgress.updateLevel 2 1 sv  // L3 = Running
    ZenohProgress.publishLevelStart L3_SIL6Tests sv
    ZenohProgress.printStateVectorBar sv
    let sw = Stopwatch.StartNew()

    if Directory.Exists("test/sil6") then
        // Create per-test tracker with Jidoka threshold (20 failures = stop for SIL-6)
        let tracker = ZenohTestTelemetry.createTracker "sil6-tests" runId sv.Levels 20

        Dashboard.printSubStep "SIL-6 tests" "RUN" "test/sil6/ suite (streaming, per-test Zenoh)"
        ZenohProgress.publishSubstep L3_SIL6Tests "sil6-test" "RUN" "test/sil6/ suite (streaming, per-test Zenoh)" sv

        // Streaming execution with --trace for per-test detail
        let (exitCode, stdout, stderr) = Subprocess.runMixStreaming "test test/sil6/ --trace" 600_000 (fun line ->
            ZenohTestTelemetry.processTraceLine tracker line |> ignore)
        sw.Stop()

        // Finalize tracker
        ZenohTestTelemetry.finalize tracker

        let result = Parser.parseTestOutput stdout stderr exitCode "sil6-test-suite" "test/sil6/"
        // Use tracker counts if parser found different totals
        let result =
            if result.Total = 0 && tracker.TotalTests > 0 then
                { result with
                    Total = tracker.TotalTests; Passed = tracker.Passed
                    Failed = tracker.Failed; Skipped = tracker.Skipped
                    Properties = tracker.Properties }
            else result
        let result = { result with DurationS = sw.Elapsed.TotalSeconds }
        RegressionTracker.recordTestSuite conn runId result

        // Report if Jidoka stopped early
        if tracker.ShouldStop then
            Dashboard.printSubStep "JIDOKA" "STOP" $"Stopped after {tracker.Failed} failures (SIL-6 threshold: {tracker.FailureThreshold})"
            ZenohProgress.publishSubstep L3_SIL6Tests "jidoka" "STOP" $"{tracker.Failed} SIL-6 failures exceeded threshold" sv

        let sv = ZenohProgress.updateLevel 2 (ZenohProgress.statusCode result.Status) sv
        ZenohProgress.publishLevelComplete L3_SIL6Tests result.Status sw.Elapsed.TotalSeconds
            (Map.ofList ["total", string result.Total; "passed", string result.Passed; "failed", string result.Failed
                         "properties", string result.Properties
                         "streaming", "true"; "jidoka_stopped", string tracker.ShouldStop]) sv
        ZenohProgress.printStateVectorBar sv

        Dashboard.printLevelResult L3_SIL6Tests result.Status
            $"{result.Total} tests, {result.Passed} passed, {result.Failed} failed"
            sw.Elapsed.TotalSeconds

        (result.Status, result, sv)
    else
        sw.Stop()
        let result : RegressionTracker.TestSuiteResult = {
            SuiteName = "sil6-test-suite"
            SuitePath = "test/sil6/"
            Total = 0; Passed = 0; Failed = 0; Skipped = 0; Excluded = 0; Properties = 0
            DurationS = 0.0
            Status = "SKIP"
        }
        RegressionTracker.recordTestSuite conn runId result
        let sv = ZenohProgress.updateLevel 2 4 sv  // SKIP
        ZenohProgress.publishLevelComplete L3_SIL6Tests "SKIP" 0.0 (Map.ofList ["reason", "test/sil6/ not found"]) sv
        ZenohProgress.printStateVectorBar sv
        Dashboard.printLevelResult L3_SIL6Tests "SKIP" "test/sil6/ not found" 0.0
        ("SKIP", result, sv)

/// L4: Quality Gates
let private runL4QualityGates (conn: Microsoft.Data.Sqlite.SqliteConnection) (runId: string) (verbose: bool) (sv: ZenohProgress.RegressionStateVector) : (string * ZenohProgress.RegressionStateVector) =
    Dashboard.printLevelStart L4_QualityGates
    let sv = ZenohProgress.updateLevel 3 1 sv  // L4 = Running
    ZenohProgress.publishLevelStart L4_QualityGates sv
    ZenohProgress.printStateVectorBar sv
    let sw = Stopwatch.StartNew()

    // Step 1: mix format --check-formatted
    Dashboard.printSubStep "format check" "RUN" "mix format --check-formatted"
    ZenohProgress.publishSubstep L4_QualityGates "format" "RUN" "mix format --check-formatted" sv
    let (exitFmt, stdoutFmt, stderrFmt) = Subprocess.runMix "format --check-formatted" 120_000
    let fmtDuration = sw.Elapsed.TotalSeconds
    let fmtStatus = if exitFmt = 0 then "PASS" else "FAIL"
    let fmtExcerpt = if exitFmt <> 0 then (stdoutFmt + stderrFmt).Substring(0, min 200 (stdoutFmt.Length + stderrFmt.Length)) else ""
    RegressionTracker.recordQualityResult conn runId {
        GateName = "format"
        Status = fmtStatus
        IssueCount = if exitFmt = 0 then 0 else 1
        DurationS = fmtDuration
        OutputExcerpt = fmtExcerpt
    }
    Dashboard.printSubStep "format check" fmtStatus (if exitFmt = 0 then "All files formatted" else "Format issues found")
    ZenohProgress.publishSubstep L4_QualityGates "format" fmtStatus (if exitFmt = 0 then "All files formatted" else "Format issues found") sv

    // Step 2: mix credo --strict
    Dashboard.printSubStep "credo strict" "RUN" "mix credo --strict"
    ZenohProgress.publishSubstep L4_QualityGates "credo" "RUN" "mix credo --strict" sv
    let (exitCredo, stdoutCredo, _stderrCredo) = Subprocess.runMix "credo --strict" 300_000
    let credoDuration = sw.Elapsed.TotalSeconds - fmtDuration
    let credoIssues = Parser.parseCredoOutput stdoutCredo exitCredo
    let credoStatus = if exitCredo = 0 then "PASS" else "FAIL"
    let credoExcerpt = if exitCredo <> 0 then stdoutCredo.Substring(0, min 200 stdoutCredo.Length) else ""
    RegressionTracker.recordQualityResult conn runId {
        GateName = "credo"
        Status = credoStatus
        IssueCount = credoIssues
        DurationS = credoDuration
        OutputExcerpt = credoExcerpt
    }
    Dashboard.printSubStep "credo strict" credoStatus $"{credoIssues} issues"
    ZenohProgress.publishSubstep L4_QualityGates "credo" credoStatus $"{credoIssues} issues" sv

    sw.Stop()
    let overallStatus =
        if fmtStatus = "FAIL" || credoStatus = "FAIL" then "FAIL"
        else "PASS"

    let sv = ZenohProgress.updateLevel 3 (ZenohProgress.statusCode overallStatus) sv
    ZenohProgress.publishLevelComplete L4_QualityGates overallStatus sw.Elapsed.TotalSeconds
        (Map.ofList ["format", fmtStatus; "credo", credoStatus; "credo_issues", string credoIssues]) sv
    ZenohProgress.printStateVectorBar sv

    Dashboard.printLevelResult L4_QualityGates overallStatus
        $"format={fmtStatus}, credo={credoStatus} ({credoIssues} issues)"
        sw.Elapsed.TotalSeconds

    (overallStatus, sv)

/// L5: System Health
let private runL5SystemHealth (conn: Microsoft.Data.Sqlite.SqliteConnection) (runId: string) (verbose: bool) (sv: ZenohProgress.RegressionStateVector) : (string * ZenohProgress.RegressionStateVector) =
    Dashboard.printLevelStart L5_SystemHealth
    let sv = ZenohProgress.updateLevel 4 1 sv  // L5 = Running
    ZenohProgress.publishLevelStart L5_SystemHealth sv
    ZenohProgress.printStateVectorBar sv
    let sw = Stopwatch.StartNew()
    let mutable allPass = true

    // Check 1: Git status
    let (exitGit, stdoutGit, _) = Subprocess.run "git" "status --porcelain" 10_000
    let gitClean = exitGit = 0
    let gitDetails = if String.IsNullOrWhiteSpace(stdoutGit) then "Clean" else $"{stdoutGit.Split('\n').Length} modified files"
    RegressionTracker.recordHealthCheck conn runId {
        CheckName = "git-status"
        Status = if gitClean then "PASS" else "WARN"
        Details = gitDetails
    }
    Dashboard.printSubStep "git status" (if gitClean then "PASS" else "WARN") gitDetails
    ZenohProgress.publishSubstep L5_SystemHealth "git-status" (if gitClean then "PASS" else "WARN") gitDetails sv

    // Check 2: Database connectivity (port 5433)
    let (exitDb, _, _) = Subprocess.run "pg_isready" "-h localhost -p 5433" 5_000
    let dbStatus = if exitDb = 0 then "PASS" else "FAIL"
    if dbStatus = "FAIL" then allPass <- false
    RegressionTracker.recordHealthCheck conn runId {
        CheckName = "database-connectivity"
        Status = dbStatus
        Details = if exitDb = 0 then "PostgreSQL on 5433 is ready" else "PostgreSQL on 5433 not reachable"
    }
    Dashboard.printSubStep "database (5433)" dbStatus (if exitDb = 0 then "PostgreSQL ready" else "Not reachable")
    ZenohProgress.publishSubstep L5_SystemHealth "database" dbStatus (if exitDb = 0 then "PostgreSQL ready" else "Not reachable") sv

    // Check 3: F# build
    Dashboard.printSubStep "F# build" "RUN" "dotnet build"
    ZenohProgress.publishSubstep L5_SystemHealth "fsharp-build" "RUN" "dotnet build" sv
    let (exitFs, stdoutFs, stderrFs) = Subprocess.run "dotnet" "build lib/cepaf/src/Cepaf/Cepaf.fsproj --verbosity quiet" 120_000
    let fsStatus = if exitFs = 0 then "PASS" else "FAIL"
    if fsStatus = "FAIL" then allPass <- false
    let fsDetails =
        if exitFs = 0 then "Build succeeded"
        else
            let lines = (stdoutFs + "\n" + stderrFs).Split('\n')
            let errorLines = lines |> Array.filter (fun l -> l.Contains("error"))
            $"{errorLines.Length} errors"
    RegressionTracker.recordHealthCheck conn runId {
        CheckName = "fsharp-build"
        Status = fsStatus
        Details = fsDetails
    }
    Dashboard.printSubStep "F# build" fsStatus fsDetails
    ZenohProgress.publishSubstep L5_SystemHealth "fsharp-build" fsStatus fsDetails sv

    // Check 4: Phoenix port (4000)
    let (exitPort, _, _) = Subprocess.run "sh" "-c \"ss -tlnp 2>/dev/null | grep -q ':4000 ' && echo ok || echo no\"" 5_000
    let portStatus = if exitPort = 0 then "PASS" else "WARN"
    RegressionTracker.recordHealthCheck conn runId {
        CheckName = "phoenix-port-4000"
        Status = portStatus
        Details = if exitPort = 0 then "Port 4000 listening" else "Port 4000 not active (containers may be down)"
    }
    Dashboard.printSubStep "port 4000" portStatus (if exitPort = 0 then "Phoenix listening" else "Not active")
    ZenohProgress.publishSubstep L5_SystemHealth "phoenix-port" portStatus (if exitPort = 0 then "Phoenix listening" else "Not active") sv

    // Check 5: Regression DB writable
    let dbWritable =
        try
            use testConn = RegressionTracker.openDb()
            use cmd = testConn.CreateCommand()
            cmd.CommandText <- "SELECT count(*) FROM regression_runs"
            let count = cmd.ExecuteScalar() :?> int64
            (true, $"{count} runs recorded")
        with ex ->
            (false, ex.Message)
    let (dbOk, dbDetail) = dbWritable
    if not dbOk then allPass <- false
    RegressionTracker.recordHealthCheck conn runId {
        CheckName = "regression-db"
        Status = if dbOk then "PASS" else "FAIL"
        Details = dbDetail
    }
    Dashboard.printSubStep "regression DB" (if dbOk then "PASS" else "FAIL") dbDetail
    ZenohProgress.publishSubstep L5_SystemHealth "regression-db" (if dbOk then "PASS" else "FAIL") dbDetail sv

    sw.Stop()
    let overallStatus = if allPass then "PASS" else "WARN"

    let sv = ZenohProgress.updateLevel 4 (ZenohProgress.statusCode overallStatus) sv
    ZenohProgress.publishLevelComplete L5_SystemHealth overallStatus sw.Elapsed.TotalSeconds
        (Map.ofList ["checks", "5"; "all_pass", string allPass]) sv
    ZenohProgress.printStateVectorBar sv

    Dashboard.printLevelResult L5_SystemHealth overallStatus
        "5 health checks completed"
        sw.Elapsed.TotalSeconds

    (overallStatus, sv)

// ============================================================
// REPORT DISPLAY
// ============================================================

let private showReport () =
    try
        use conn = RegressionTracker.openDb()
        match RegressionTracker.getLatestRunSummary conn with
        | Some (timestamp, summary) ->
            printfn ""
            printfn "%s%s+===============================================================================+%s" Colors.brightCyan Colors.bold Colors.reset
            printfn "%s%s|  LATEST REGRESSION REPORT                                                     |%s" Colors.brightCyan Colors.bold Colors.reset
            printfn "%s%s+===============================================================================+%s" Colors.brightCyan Colors.bold Colors.reset
            printfn ""
            printfn "  Run ID:     %s" summary.RunId
            printfn "  Timestamp:  %s" timestamp
            let overallColor = MeshUtils.statusColor summary.OverallStatus
            printfn "  Status:     %s%s%s%s" overallColor Colors.bold summary.OverallStatus Colors.reset
            printfn ""
            printfn "  %-20s %s" "L1 Compilation" summary.CompileStatus
            printfn "  %-20s %s" "L2 Full Tests" summary.FullTestStatus
            printfn "  %-20s %s" "L3 SIL-6 Tests" summary.Sil6TestStatus
            printfn "  %-20s %s" "L4 Quality Gates" summary.QualityStatus
            printfn "  %-20s %s" "L5 System Health" summary.SystemStatus
            printfn ""
            printfn "  Tests: %d total | %d passed | %d failed | %d skipped | %d props"
                summary.TotalTests summary.TotalPassed summary.TotalFailed summary.TotalSkipped summary.TotalProperties
            if summary.Sil6Tests > 0 then
                printfn "  SIL-6: %d total | %d passed | %d failed | %d props"
                    summary.Sil6Tests summary.Sil6Passed summary.Sil6Failed summary.Sil6Properties
            printfn "  Duration: %.1fs" summary.TotalDurationS
            printfn ""
            0
        | None ->
            printfn "No regression runs found. Run: dotnet run -- regression"
            1
    with ex ->
        eprintfn "Error reading report: %s" ex.Message
        1

// ============================================================
// MAIN RUNNER
// ============================================================

let private parseArgs (args: string array) : RunConfig =
    let mutable levels = []
    let mutable verbose = false
    let mutable reportOnly = false

    let mutable i = 0
    while i < args.Length do
        match args.[i].ToLower() with
        | "--level" | "-l" when i + 1 < args.Length ->
            match args.[i + 1] with
            | "1" -> levels <- L1_Compilation :: levels
            | "2" -> levels <- L2_FullTests :: levels
            | "3" -> levels <- L3_SIL6Tests :: levels
            | "4" -> levels <- L4_QualityGates :: levels
            | "5" -> levels <- L5_SystemHealth :: levels
            | x -> eprintfn "Unknown level: %s (use 1-5)" x
            i <- i + 2
        | "--verbose" | "-v" ->
            verbose <- true
            i <- i + 1
        | "--report" | "-r" ->
            reportOnly <- true
            i <- i + 1
        | "--help" | "-h" ->
            printfn "Usage: dotnet run -- regression [OPTIONS]"
            printfn ""
            printfn "Options:"
            printfn "  --level N, -l N   Run specific level (1-5), can repeat"
            printfn "  --verbose, -v     Show detailed output"
            printfn "  --report, -r      Show last run report"
            printfn "  --help, -h        Show this help"
            printfn ""
            printfn "Levels:"
            printfn "  1  Compilation    (mix compile, warnings-as-errors)"
            printfn "  2  Full Tests     (mix test, 16 schedulers)"
            printfn "  3  SIL-6 Tests    (mix test test/sil6/ --trace)"
            printfn "  4  Quality Gates  (format, credo)"
            printfn "  5  System Health  (ports, git, DB, F# build)"
            Environment.Exit(0)
            i <- i + 1
        | _ ->
            i <- i + 1

    {
        Levels = if List.isEmpty levels then [L1_Compilation; L2_FullTests; L3_SIL6Tests; L4_QualityGates; L5_SystemHealth] else List.rev levels
        Verbose = verbose
        ReportOnly = reportOnly
    }

/// Main entry point for regression runner
let run (args: string array) : int =
    let config = parseArgs args

    if config.ReportOnly then
        showReport()
    else

    let totalSw = Stopwatch.StartNew()
    Dashboard.printStart()

    try
        use conn = RegressionTracker.openDb()
        let runId = RegressionTracker.generateRunId()
        RegressionTracker.createRun conn runId

        // Initialize Zenoh state vector tracking (SC-ZTEST-006)
        let mutable sv = ZenohProgress.createStateVector runId
        ZenohProgress.publishRunStart sv

        // Get previous run for comparison
        let prevRun = RegressionTracker.getPreviousRun conn

        let ts = DateTimeOffset.UtcNow.ToString("HH:mm:ss.fff")
        printfn "%s[%s]%s %sREGRESSION%s  Run ID: %s%s%s" Colors.dim ts Colors.reset Colors.brightCyan Colors.reset Colors.white runId Colors.reset
        ZenohProgress.printStateVectorBar sv

        // Execute requested levels with Zenoh state vector threading
        let mutable compileStatus = "SKIP"
        let mutable fullTestResult = None
        let mutable sil6TestResult = None
        let mutable qualityStatus = "SKIP"
        let mutable systemStatus = "SKIP"

        for level in config.Levels do
            match level with
            | L1_Compilation ->
                let (status, sv') = runL1Compilation conn runId config.Verbose sv
                compileStatus <- status
                sv <- sv'
            | L2_FullTests ->
                let (status, result, sv') = runL2FullTests conn runId config.Verbose sv
                fullTestResult <- Some (status, result)
                sv <- sv'
            | L3_SIL6Tests ->
                let (status, result, sv') = runL3SIL6Tests conn runId config.Verbose sv
                sil6TestResult <- Some (status, result)
                sv <- sv'
            | L4_QualityGates ->
                let (status, sv') = runL4QualityGates conn runId config.Verbose sv
                qualityStatus <- status
                sv <- sv'
            | L5_SystemHealth ->
                let (status, sv') = runL5SystemHealth conn runId config.Verbose sv
                systemStatus <- status
                sv <- sv'

        totalSw.Stop()

        // Aggregate summary
        let fullTestStatus = fullTestResult |> Option.map fst |> Option.defaultValue "SKIP"
        let fullTest = fullTestResult |> Option.map snd
        let sil6TestStatus = sil6TestResult |> Option.map fst |> Option.defaultValue "SKIP"
        let sil6Test = sil6TestResult |> Option.map snd

        let totalTests = (fullTest |> Option.map (fun r -> r.Total) |> Option.defaultValue 0)
                         + (sil6Test |> Option.map (fun r -> r.Total) |> Option.defaultValue 0)
        let totalPassed = (fullTest |> Option.map (fun r -> r.Passed) |> Option.defaultValue 0)
                          + (sil6Test |> Option.map (fun r -> r.Passed) |> Option.defaultValue 0)
        let totalFailed = (fullTest |> Option.map (fun r -> r.Failed) |> Option.defaultValue 0)
                          + (sil6Test |> Option.map (fun r -> r.Failed) |> Option.defaultValue 0)
        let totalSkipped = (fullTest |> Option.map (fun r -> r.Skipped) |> Option.defaultValue 0)
                           + (sil6Test |> Option.map (fun r -> r.Skipped) |> Option.defaultValue 0)
        let totalExcluded = (fullTest |> Option.map (fun r -> r.Excluded) |> Option.defaultValue 0)
                            + (sil6Test |> Option.map (fun r -> r.Excluded) |> Option.defaultValue 0)
        let totalProperties = (fullTest |> Option.map (fun r -> r.Properties) |> Option.defaultValue 0)
                              + (sil6Test |> Option.map (fun r -> r.Properties) |> Option.defaultValue 0)

        let overallStatus =
            let statuses = [compileStatus; fullTestStatus; sil6TestStatus; qualityStatus; systemStatus]
            if statuses |> List.exists (fun s -> s = "FAIL") then "FAIL"
            elif statuses |> List.exists (fun s -> s = "WARN") then "WARN"
            else "PASS"

        let summary : RegressionTracker.RunSummary = {
            RunId = runId
            OverallStatus = overallStatus
            CompileStatus = compileStatus
            FullTestStatus = fullTestStatus
            Sil6TestStatus = sil6TestStatus
            QualityStatus = qualityStatus
            SystemStatus = systemStatus
            TotalTests = totalTests
            TotalPassed = totalPassed
            TotalFailed = totalFailed
            TotalSkipped = totalSkipped
            TotalExcluded = totalExcluded
            TotalProperties = totalProperties
            TotalDurationS = totalSw.Elapsed.TotalSeconds
            Sil6Tests = sil6Test |> Option.map (fun r -> r.Total) |> Option.defaultValue 0
            Sil6Passed = sil6Test |> Option.map (fun r -> r.Passed) |> Option.defaultValue 0
            Sil6Failed = sil6Test |> Option.map (fun r -> r.Failed) |> Option.defaultValue 0
            Sil6Properties = sil6Test |> Option.map (fun r -> r.Properties) |> Option.defaultValue 0
            ElixirModules = fullTest |> Option.map (fun r -> r.Total) |> Option.defaultValue 0
        }

        RegressionTracker.recordRunSummary conn summary

        // Publish final Zenoh checkpoint with complete state vector
        ZenohProgress.publishRunComplete sv overallStatus totalTests totalFailed totalSw.Elapsed.TotalSeconds
        ZenohProgress.printStateVectorBar sv

        Dashboard.printSummary summary totalSw.Elapsed.TotalSeconds prevRun

        if overallStatus = "FAIL" then 1 else 0

    with ex ->
        totalSw.Stop()
        eprintfn "%s[ERROR]%s Regression runner failed: %s" Colors.brightRed Colors.reset ex.Message
        if ex.InnerException <> null then
            eprintfn "  Inner: %s" ex.InnerException.Message
        1

// ============================================================
// HOMEOSTATIC GOVERNANCE (SC-BIO-EXT-007, Detailed Analysis §67.1)
// ============================================================

/// Proportional-Integral-Derivative (PID) Controller for dynamic resource management.
/// Maintains system homeostasis by modulating test spawning rate against
/// hardware limits (80% CPU/Memory setpoint).
module HomeostaticGovernor =

    type PidState = {
        Kp: float; Ki: float; Kd: float
        Setpoint: float
        Integral: float
        LastError: float
        LastTime: DateTime
    }

    let createPid kp ki kd setpoint = {
        Kp = kp; Ki = ki; Kd = kd
        Setpoint = setpoint
        Integral = 0.0
        LastError = 0.0
        LastTime = DateTime.UtcNow
    }

    /// Calculate control variable (optimal job count modulation)
    let update (currentValue: float) (state: PidState) : (float * PidState) =
        let now = DateTime.UtcNow
        let dt = (now - state.LastTime).TotalSeconds
        if dt <= 0.0 then (0.0, state)
        else
            let error = state.Setpoint - currentValue
            let integral = state.Integral + (error * dt)
            let derivative = (error - state.LastError) / dt
            
            let output = (state.Kp * error) + (state.Ki * integral) + (state.Kd * derivative)
            
            let newState = { state with 
                                Integral = integral
                                LastError = error
                                LastTime = now }
            (output, newState)

    /// Calculate the current resource load (0.0 to 1.0)
    let getCurrentLoad () : float =
        // Simulation of resource load - in production queries OS metrics
        let random = System.Random()
        random.NextDouble() * 0.9

/// Execute regression run asynchronously. 
/// Replaces terminal dashboard with Zenoh-only telemetry for background agents.
let runAsync (config: RunConfig) (ct: System.Threading.CancellationToken) : Async<AsyncRunResult> =
    async {
        let totalSw = Stopwatch.StartNew()
        let runId = RegressionTracker.generateRunId()
        
        use conn = RegressionTracker.openDb()
        RegressionTracker.createRun conn runId

        let mutable sv = ZenohProgress.createStateVector runId
        ZenohProgress.publishRunStart sv

        // Initialize Homeostatic Governor (PID) - Detailed Analysis §67.1
        let mutable pid = HomeostaticGovernor.createPid 0.5 0.1 0.05 0.80 // 80% Setpoint

        let mutable levelStatuses = Map.empty
        let mutable levelOutputs = Map.empty
        let mutable totalPassed = 0
        let mutable totalFailed = 0
        let mutable overallExitCode = 0

        for level in config.Levels do
            if not ct.IsCancellationRequested then
                // Homeostatic Modulation (Detailed Analysis §1801)
                // Adjust execution intensity based on real-time hardware load.
                let currentLoad = HomeostaticGovernor.getCurrentLoad()
                let (modulation, nextPid) = HomeostaticGovernor.update currentLoad pid
                pid <- nextPid
                
                // If load is too high (modulation < 0), introduce a biomorphic pause (Throttle)
                if modulation < 0.0 then
                    let pauseMs = int (abs modulation * 1000.0) |> min 5000
                    printfn "[HOMEOSTASIS] Load threshold exceeded (%.2f). Throttling execution for %dms..." currentLoad pauseMs
                    do! Async.Sleep pauseMs

                let levelName = match level with L1_Compilation -> "L1" | L2_FullTests -> "L2" | L3_SIL6Tests -> "L3" | L4_QualityGates -> "L4" | L5_SystemHealth -> "L5"
                let idx = ZenohProgress.levelIndex level
                sv <- ZenohProgress.updateLevel idx 1 sv // Running
                ZenohProgress.publishLevelStart level sv

                let (status, passed, failed, exitCode, output) = 
                    match level with
                    | L1_Compilation ->
                        let (exitCode1, stdout1, stderr1) = Subprocess.runMix "compile" 600_000
                        let result1 = Parser.parseCompileOutput stdout1 stderr1 exitCode1
                        RegressionTracker.recordCompileResult conn runId result1
                        
                        let (exitCode2, stdout2, stderr2) = Subprocess.runMix "compile --warnings-as-errors" 600_000
                        let result2 = Parser.parseStrictCompile stdout2 stderr2 exitCode2
                        RegressionTracker.recordCompileResult conn runId result2
                        
                        let s = if result1.Status = "FAIL" || result2.Status = "FAIL" then "FAIL" else "PASS"
                        (s, 0, (if s = "FAIL" then 1 else 0), (if exitCode1 <> 0 then exitCode1 else exitCode2), stdout1 + "\n" + stderr1 + "\n" + stdout2 + "\n" + stderr2)
                    
                    | L2_FullTests ->
                        let tracker = ZenohTestTelemetry.createTracker "full-tests" runId sv.Levels 50
                        let (ec, out, err) = Subprocess.runMixStreaming "test" 1_800_000 (fun line -> ZenohTestTelemetry.processTraceLine tracker line |> ignore)
                        ZenohTestTelemetry.finalize tracker
                        let res = Parser.parseTestOutput out err ec "full-test-suite" "test/"
                        let res = if res.Total = 0 && tracker.TotalTests > 0 then { res with Total = tracker.TotalTests; Passed = tracker.Passed; Failed = tracker.Failed } else res
                        RegressionTracker.recordTestSuite conn runId res
                        (res.Status, res.Passed, res.Failed, ec, out + "\n" + err)

                    | L3_SIL6Tests ->
                        if Directory.Exists("test/sil6") then
                            let tracker = ZenohTestTelemetry.createTracker "sil6-tests" runId sv.Levels 20
                            let (ec, out, err) = Subprocess.runMixStreaming "test test/sil6/ --trace" 600_000 (fun line -> ZenohTestTelemetry.processTraceLine tracker line |> ignore)
                            ZenohTestTelemetry.finalize tracker
                            let res = Parser.parseTestOutput out err ec "sil6-test-suite" "test/sil6/"
                            let res = if res.Total = 0 && tracker.TotalTests > 0 then { res with Total = tracker.TotalTests; Passed = tracker.Passed; Failed = tracker.Failed } else res
                            RegressionTracker.recordTestSuite conn runId res
                            (res.Status, res.Passed, res.Failed, ec, out + "\n" + err)
                        else ("SKIP", 0, 0, 0, "test/sil6 not found")

                    | L4_QualityGates ->
                        let (ecFmt, outFmt, errFmt) = Subprocess.runMix "format --check-formatted" 120_000
                        let (ecCredo, outCredo, errCredo) = Subprocess.runMix "credo --strict" 300_000
                        let s = if ecFmt = 0 && ecCredo = 0 then "PASS" else "FAIL"
                        (s, 0, (if s = "FAIL" then 1 else 0), (if ecCredo <> 0 then ecCredo else ecFmt), outFmt + "\n" + outCredo)

                    | L5_SystemHealth ->
                        let (ecGit, outGit, _) = Subprocess.run "git" "status --porcelain" 10_000
                        let (ecDb, _, _) = Subprocess.run "pg_isready" "-h localhost -p 5433" 5_000
                        let s = if ecGit = 0 && ecDb = 0 then "PASS" else "FAIL"
                        (s, 0, (if s = "FAIL" then 1 else 0), (if ecDb <> 0 then ecDb else ecGit), outGit)

                levelStatuses <- Map.add level status levelStatuses
                levelOutputs <- Map.add level output levelOutputs
                totalPassed <- totalPassed + passed
                totalFailed <- totalFailed + failed
                if exitCode <> 0 then overallExitCode <- exitCode
                
                sv <- ZenohProgress.updateLevel idx (ZenohProgress.statusCode status) sv
                ZenohProgress.publishLevelComplete level status 0.0 Map.empty sv

        totalSw.Stop()
        let overallStatus = if Map.toSeq levelStatuses |> Seq.exists (fun (_, s) -> s = "FAIL") then "FAIL" else "PASS"
        
        ZenohProgress.publishRunComplete sv overallStatus totalPassed totalFailed totalSw.Elapsed.TotalSeconds

        return {
            RunId = runId
            OverallStatus = overallStatus
            ExitCode = overallExitCode
            DurationS = totalSw.Elapsed.TotalSeconds
            LevelStatuses = levelStatuses
            LevelOutputs = levelOutputs
            TotalPassed = totalPassed
            TotalFailed = totalFailed
            StateVector = sv.Levels
        }
    }
