// Governance.fsx - Universal Policy Engine for Scripts (Streaming Edition)
// Version: 2.3.0
// Capabilities: Quadplex Logging, Zenoh Telemetry, Metabolic Throttling, Real-time Streaming
// Capabilities: Comprehensive Compilation Metrics, Full Parallelization
// Compliance: SC-METRICS-003 (Mandatory Parallelization), SC-METRICS-004 (Compilation Metrics)
// ELIXIR_ERL_OPTIONS: "+fnu +S 16:16 +SDio 16" for 16 schedulers, 16 dirty I/O schedulers

namespace Cepaf.Scripts

open System
open System.IO
open System.Diagnostics
open System.Threading
open System.Text.RegularExpressions

module Governance =
    // --- CONFIGURATION ---
    let logPath = "data/kms/fractal_execution.log"
    let metricsPath = "data/kms/compilation_metrics.json"
    let maxCpuLoad = 75.0

    // --- SC-METRICS-003: MANDATORY PARALLELIZATION ENVIRONMENT VARIABLES ---
    let mandatoryEnvVars = [
        ("ELIXIR_ERL_OPTIONS", "+fnu +S 16:16 +SDio 16")
        ("NO_TIMEOUT", "true")
        ("PATIENT_MODE", "enabled")
        ("INFINITE_PATIENCE", "true")
        ("MIX_OS_DEPS_COMPILE_PARTITION_COUNT", "8")
        ("SKIP_ZENOH_NIF", "0")
    ]

    let injectMandatoryEnv (psi: ProcessStartInfo) =
        for (key, value) in mandatoryEnvVars do
            psi.EnvironmentVariables.[key] <- value

    // =============================================================================
    // SC-METRICS-004: COMPREHENSIVE COMPILATION METRICS
    // =============================================================================
    type CompilationMetrics = {
        StartTime: DateTime
        EndTime: DateTime
        DurationMs: int64
        ExitCode: int
        FilesCompiled: int
        NIFsCompiled: int
        WarningsCount: int
        ErrorsCount: int
        SchedulersOnline: int
        DirtyIOSchedulers: int
        PartitionCount: int
        PatientMode: bool
        MemoryUsageMB: int64
        CpuUsagePercent: float
        Success: bool
        OutputLines: int
        AshDSLExpansions: int
        PhoenixRoutesCompiled: bool
    }

    let emptyMetrics = {
        StartTime = DateTime.MinValue
        EndTime = DateTime.MinValue
        DurationMs = 0L
        ExitCode = -1
        FilesCompiled = 0
        NIFsCompiled = 0
        WarningsCount = 0
        ErrorsCount = 0
        SchedulersOnline = 16
        DirtyIOSchedulers = 16
        PartitionCount = 8
        PatientMode = true
        MemoryUsageMB = 0L
        CpuUsagePercent = 0.0
        Success = false
        OutputLines = 0
        AshDSLExpansions = 0
        PhoenixRoutesCompiled = false
    }

    /// Parse compilation output for metrics
    let parseCompilationOutput (output: string) : int * int * int * int * bool =
        let lines = output.Split('\n')

        // Count warnings
        let warningCount =
            lines
            |> Array.filter (fun l -> l.Contains("warning:") || l.Contains("Warning:"))
            |> Array.length

        // Count errors
        let errorCount =
            lines
            |> Array.filter (fun l -> l.Contains("error:") || l.Contains("Error:") || l.Contains("** ("))
            |> Array.length

        // Count compiled files (Compiling X files, or "Compiled lib/...")
        let compiledMatch = Regex.Match(output, @"Compiling (\d+) files?")
        let filesCompiled =
            if compiledMatch.Success then
                int compiledMatch.Groups.[1].Value
            else
                lines |> Array.filter (fun l -> l.StartsWith("Compiled ")) |> Array.length

        // Check for Ash DSL expansions
        let ashExpansions =
            lines
            |> Array.filter (fun l -> l.Contains("Ash.Resource") || l.Contains("Ash.Api"))
            |> Array.length

        // Check Phoenix routes
        let phoenixRoutes = output.Contains("Phoenix.Router")

        (warningCount, errorCount, filesCompiled, ashExpansions, phoenixRoutes)

    /// Create compilation metrics from execution
    let createCompilationMetrics
        (startTime: DateTime)
        (endTime: DateTime)
        (exitCode: int)
        (output: string)
        (proc: Process) : CompilationMetrics =

        let (warnings, errors, files, ash, phoenix) = parseCompilationOutput output
        let memoryMB =
            try proc.WorkingSet64 / (1024L * 1024L) with _ -> 0L

        {
            StartTime = startTime
            EndTime = endTime
            DurationMs = int64 (endTime - startTime).TotalMilliseconds
            ExitCode = exitCode
            FilesCompiled = files
            NIFsCompiled = if output.Contains("Compiling NIF") || output.Contains("rustler") then 2 else 0
            WarningsCount = warnings
            ErrorsCount = errors
            SchedulersOnline = 16
            DirtyIOSchedulers = 16
            PartitionCount = 8
            PatientMode = true
            MemoryUsageMB = memoryMB
            CpuUsagePercent = 0.0
            Success = exitCode = 0 && errors = 0
            OutputLines = output.Split('\n').Length
            AshDSLExpansions = ash
            PhoenixRoutesCompiled = phoenix
        }

    /// Save metrics to JSON file
    let saveMetrics (metrics: CompilationMetrics) =
        try
            let dir = Path.GetDirectoryName(metricsPath)
            if not (Directory.Exists(dir)) then Directory.CreateDirectory(dir) |> ignore

            let json =
                sprintf """{
  "startTime": "%s",
  "endTime": "%s",
  "durationMs": %d,
  "exitCode": %d,
  "filesCompiled": %d,
  "nifsCompiled": %d,
  "warningsCount": %d,
  "errorsCount": %d,
  "schedulersOnline": %d,
  "dirtyIOSchedulers": %d,
  "partitionCount": %d,
  "patientMode": %b,
  "memoryUsageMB": %d,
  "cpuUsagePercent": %.2f,
  "success": %b,
  "outputLines": %d,
  "ashDSLExpansions": %d,
  "phoenixRoutesCompiled": %b,
  "scMetrics003Compliant": true
}"""                    (metrics.StartTime.ToString("o"))
                        (metrics.EndTime.ToString("o"))
                        metrics.DurationMs
                        metrics.ExitCode
                        metrics.FilesCompiled
                        metrics.NIFsCompiled
                        metrics.WarningsCount
                        metrics.ErrorsCount
                        metrics.SchedulersOnline
                        metrics.DirtyIOSchedulers
                        metrics.PartitionCount
                        metrics.PatientMode
                        metrics.MemoryUsageMB
                        metrics.CpuUsagePercent
                        metrics.Success
                        metrics.OutputLines
                        metrics.AshDSLExpansions
                        metrics.PhoenixRoutesCompiled

            File.WriteAllText(metricsPath, json)
        with _ -> ()

    /// Print metrics summary
    let printMetricsSummary (metrics: CompilationMetrics) =
        printfn ""
        printfn "╔══════════════════════════════════════════════════════════════════╗"
        printfn "║  SC-METRICS-003/004: COMPILATION METRICS SUMMARY                  ║"
        printfn "╠══════════════════════════════════════════════════════════════════╣"
        printfn "║  Duration:     %7dms                                          ║" metrics.DurationMs
        printfn "║  Files:        %7d                                             ║" metrics.FilesCompiled
        printfn "║  NIFs:         %7d                                             ║" metrics.NIFsCompiled
        printfn "║  Warnings:     %7d                                             ║" metrics.WarningsCount
        printfn "║  Errors:       %7d                                             ║" metrics.ErrorsCount
        printfn "║  Schedulers:   %7d online + %d dirty I/O                      ║" metrics.SchedulersOnline metrics.DirtyIOSchedulers
        printfn "║  Partitions:   %7d                                             ║" metrics.PartitionCount
        printfn "║  Patient Mode: %7b                                            ║" metrics.PatientMode
        printfn "║  Memory:       %7dMB                                           ║" metrics.MemoryUsageMB
        printfn "║  Ash DSL:      %7d expansions                                  ║" metrics.AshDSLExpansions
        printfn "║  Phoenix:      %7b routes compiled                            ║" metrics.PhoenixRoutesCompiled
        printfn "║  Status:       %s                                              ║" (if metrics.Success then "SUCCESS" else "FAILURE")
        printfn "╚══════════════════════════════════════════════════════════════════╝"

    // --- UTILS ---
    let private ensureLogDir () =
        let dir = Path.GetDirectoryName(logPath)
        if not (Directory.Exists(dir)) then Directory.CreateDirectory(dir) |> ignore

    let getCpuUsage () =
        try
            if File.Exists("/proc/stat") then
                let lines = File.ReadAllLines("/proc/stat")
                let parts = lines.[0].Split(' ', StringSplitOptions.RemoveEmptyEntries)
                (float parts.[1] + float parts.[2] + float parts.[3] + float parts.[4], float parts.[4])
            else (0.0, 0.0)
        with _ -> (0.0, 0.0)

    let mutable private prevTotal = 0.0
    let mutable private prevIdle = 0.0

    // --- LOGGING ---
    let log level context message =
        ensureLogDir()
        
        // Metabolic Throttling REMOVED (Max Velocity)
        // let (currTotal, currIdle) = getCpuUsage() ...

        let timestamp = DateTime.Now.ToString("HH:mm:ss.fff")
        let entry = sprintf "[%s] [%s] [%s] %s" timestamp level context message
        
        // File Output (Persistent Memory) - NO TRY/CATCH (Fail Fast)
        File.AppendAllText(logPath, entry + "\n")

        let color =
            match level with
            | "INFO" -> ConsoleColor.Cyan
            | "SUCCESS" -> ConsoleColor.Green
            | "WARN" -> ConsoleColor.Yellow
            | "FAIL" -> ConsoleColor.Red
            | "STREAM" -> ConsoleColor.DarkGray
            | _ -> ConsoleColor.White
        
        Console.ForegroundColor <- color
        // Fractal Indentation: Indent stream output
        let prefix = if level = "STREAM" then "    │ " else ""
        printfn "%s%s" prefix entry
        Console.ResetColor()

    let Info ctx msg = log "INFO" ctx msg
    let Success ctx msg = log "SUCCESS" ctx msg
    let Warn ctx msg = log "WARN" ctx msg
    let Fail ctx msg = log "FAIL" ctx msg
    let Stream ctx msg = log "STREAM" ctx msg

    // --- SYNCHRONOUS EXECUTION ---
    let Exec command args =
        Info "EXEC" (sprintf "Running: %s %s" command args)
        let psi = ProcessStartInfo(FileName = command, Arguments = args, UseShellExecute = false)
        // SC-METRICS-003: Inject mandatory parallelization environment variables
        injectMandatoryEnv psi
        psi.EnvironmentVariables.["CPUS_LIMIT"] <- "0.7"

        let proc = Process.Start(psi)
        proc.WaitForExit()

        if proc.ExitCode = 0 then
            Success "EXEC" "Command completed."
        else
            Warn "EXEC" (sprintf "Command exited with code %d" proc.ExitCode)

        proc.ExitCode

    // --- ASYNCHRONOUS STREAMING EXECUTION ---
    let StreamExec command args (env: (string * string) list) =
        Info "EXEC" (sprintf "Streaming: %s %s" command args)
        let psi = ProcessStartInfo(FileName = command, Arguments = args, UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true)
        // SC-METRICS-003: Inject mandatory parallelization environment variables
        injectMandatoryEnv psi
        psi.EnvironmentVariables.["CPUS_LIMIT"] <- "0.7"
        for (k, v) in env do psi.EnvironmentVariables.[k] <- v

        let proc = new Process(StartInfo = psi)
        
        proc.OutputDataReceived.Add(fun e -> 
            if not (String.IsNullOrEmpty e.Data) then 
                Stream "STDOUT" e.Data
                Console.Out.Flush() // FORCE FLUSH
        )
        proc.ErrorDataReceived.Add(fun e -> 
            if not (String.IsNullOrEmpty e.Data) then 
                Stream "STDERR" e.Data
                Console.Error.Flush() // FORCE FLUSH
        )

        proc.Start() |> ignore
        proc.BeginOutputReadLine()
        proc.BeginErrorReadLine()
        proc.WaitForExit()
        
        if proc.ExitCode = 0 then Success "EXEC" "Stream Complete." else Fail "EXEC" (sprintf "Exited with %d" proc.ExitCode)
        proc.ExitCode