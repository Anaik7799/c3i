// =============================================================================
// BuildStreamMonitor.fs - Real-Time Build Observability & Streaming Progress
// =============================================================================
// STAMP: SC-IGNITE-004, SC-HMI-010, SC-CTRL-007, SC-ZENOH-001
// AOR: AOR-IGNITE-001, AOR-MON-001
//
// ## Purpose
// Replaces buffered Process.WaitForExit() with streaming output parsing that
// provides real-time progress bars, step tracking, ETA estimation, and Zenoh
// telemetry during long-running container builds (10-15 min app image builds).
//
// ## Document Control
// | Version | 1.0.0 |
// | Created | 2026-03-31 |
// | Author  | Cybernetic Architect |
// =============================================================================

namespace Cepaf.Mesh

open System
open System.Diagnostics
open System.Text.RegularExpressions
open System.Threading
open Cepaf.Zenoh.Messaging

module BuildStreamMonitor =

    // =========================================================================
    // Types
    // =========================================================================

    /// Individual build step parsed from podman/docker output
    type BuildStep = {
        StepNumber: int
        TotalSteps: int
        Instruction: string
        CacheHit: bool
        StartTime: DateTime
        EndTime: DateTime option
        DurationMs: int64
    }

    /// Live build progress state
    type BuildProgress = {
        ContainerName: string
        TotalSteps: int
        CompletedSteps: int
        CurrentStep: string
        CacheHits: int
        CacheMisses: int
        StartTime: DateTime
        EstimatedTotalMs: float
        LastStepDurationMs: float
        Errors: string list
        Warnings: string list
    }

    /// Final build result
    type BuildResult = {
        ContainerName: string
        Success: bool
        ExitCode: int
        TotalSteps: int
        CacheHits: int
        TotalDurationMs: int64
        StepDurations: (int * int64) list
        ImageId: string option
        Errors: string list
    }

    /// Command stream result (for non-build commands like compose up/down)
    type CommandStreamResult = {
        Command: string
        ExitCode: int
        DurationMs: int64
        OutputLines: int
        ErrorLines: int
        LastOutput: string
    }

    // =========================================================================
    // EMA Calculator for dynamic ETA
    // =========================================================================

    /// Exponential Moving Average for step duration prediction
    type EmaCalculator(alpha: float) =
        let mutable value = 0.0
        let mutable initialized = false

        member _.Update(sample: float) =
            if not initialized then
                value <- sample
                initialized <- true
            else
                value <- alpha * sample + (1.0 - alpha) * value

        member _.Value = value
        member _.IsInitialized = initialized

    // =========================================================================
    // ANSI Rendering Helpers
    // =========================================================================

    let private formatDuration (ms: float) =
        let ts = TimeSpan.FromMilliseconds(ms)
        if ts.TotalMinutes >= 1.0 then
            sprintf "%dm %02ds" (int ts.TotalMinutes) ts.Seconds
        else
            sprintf "%.1fs" ts.TotalSeconds

    let private formatEta (ms: float) =
        if ms <= 0.0 then "< 1s"
        else formatDuration ms

    let private progressBar (pct: float) (width: int) =
        let filled = int (pct / 100.0 * float width)
        let empty = max 0 (width - filled)
        let bar = String('█', min width filled)
        let rest = String('░', empty)
        let color =
            if pct >= 100.0 then "\u001b[32m"       // Green
            elif pct >= 60.0 then "\u001b[36m"       // Cyan
            elif pct >= 30.0 then "\u001b[33m"       // Yellow
            else "\u001b[34m"                         // Blue
        sprintf "%s%s\u001b[0m%s" color bar rest

    let private clearLine () =
        printf "\r\u001b[2K"

    // =========================================================================
    // Regex Patterns for podman build output parsing
    // =========================================================================

    let private stepPattern = Regex(@"STEP\s+(\d+)/(\d+)\s*[:\|]\s*(.*)", RegexOptions.IgnoreCase ||| RegexOptions.Compiled)
    let private cachePattern = Regex(@"-->.*(?:Using cache|CACHED)", RegexOptions.IgnoreCase ||| RegexOptions.Compiled)
    let private errorPattern = Regex(@"(?:^error|^ERROR|COPY failed|RUN.*returned non-zero|cannot find)", RegexOptions.IgnoreCase ||| RegexOptions.Compiled)
    let private warnPattern = Regex(@"(?:^WARNING|^warning|deprecated)", RegexOptions.IgnoreCase ||| RegexOptions.Compiled)
    let private imageIdPattern = Regex(@"(?:Successfully built|-->\s*)([0-9a-f]{12,64})", RegexOptions.IgnoreCase ||| RegexOptions.Compiled)
    let private commitPattern = Regex(@"COMMIT\s+(.+)", RegexOptions.IgnoreCase ||| RegexOptions.Compiled)

    // =========================================================================
    // Core: streamBuild — Real-time podman build with full parsing
    // =========================================================================

    /// Stream a podman build command with real-time step parsing, ETA, and Zenoh telemetry.
    /// Replaces buffered exec for container image builds (SC-IGNITE-004).
    let streamBuild (containerName: string) (command: string) (args: string) (timeoutMs: int) : BuildResult =
        let sw = Stopwatch.StartNew()
        let ema = EmaCalculator(0.3)
        let mutable progress = {
            ContainerName = containerName
            TotalSteps = 0
            CompletedSteps = 0
            CurrentStep = "Initializing..."
            CacheHits = 0
            CacheMisses = 0
            StartTime = DateTime.UtcNow
            EstimatedTotalMs = 0.0
            LastStepDurationMs = 0.0
            Errors = []
            Warnings = []
        }
        let mutable lastStepStart = DateTime.UtcNow
        let mutable imageId = None
        let stepDurations = System.Collections.Generic.List<int * int64>()
        let mutable exitCode = -1

        // Zenoh: announce build start
        ZenohPublish.publish
            (sprintf "CP-BUILD-%s-START" containerName)
            (sprintf "indrajaal/mesh/build/%s" containerName)
            (sprintf "BUILD START: %s" containerName)
            (sprintf "{\"event\":\"build_start\",\"container\":\"%s\",\"timestamp\":\"%s\"}" containerName (DateTime.UtcNow.ToString("O")))

        printfn ""
        printfn "  \u001b[35m\u001b[1m╔══════════════════════════════════════════════════════════════╗\u001b[0m"
        printfn "  \u001b[35m\u001b[1m║\u001b[0m  \u001b[36mBUILDING: %-50s\u001b[0m \u001b[35m\u001b[1m║\u001b[0m" containerName
        printfn "  \u001b[35m\u001b[1m╚══════════════════════════════════════════════════════════════╝\u001b[0m"

        let psi = ProcessStartInfo(
            FileName = command,
            Arguments = args,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        )
        use proc = new Process()
        proc.StartInfo <- psi
        proc.EnableRaisingEvents <- true

        // Heartbeat ticker — prints elapsed time every 5s during idle periods
        let mutable lastActivity = DateTime.UtcNow
        let heartbeatCts = new CancellationTokenSource()
        let heartbeatThread = Thread(fun () ->
            try
                while not heartbeatCts.Token.IsCancellationRequested do
                    Thread.Sleep(5000)
                    if not heartbeatCts.Token.IsCancellationRequested then
                        let idleMs = (DateTime.UtcNow - lastActivity).TotalMilliseconds
                        if idleMs > 4500.0 then
                            let elapsed = sw.Elapsed
                            clearLine()
                            printf "  \u001b[90m  ⏱ %s elapsed | Step %d/%d | %s\u001b[0m"
                                (formatDuration elapsed.TotalMilliseconds)
                                progress.CompletedSteps
                                (max 1 progress.TotalSteps)
                                progress.CurrentStep
            with :? ThreadInterruptedException -> ()
        )
        heartbeatThread.IsBackground <- true
        heartbeatThread.Start()

        // Parse output lines (podman sends build progress to both stdout and stderr)
        let parseLine (line: string) (isStderr: bool) =
            if not (String.IsNullOrWhiteSpace line) then
                lastActivity <- DateTime.UtcNow
                let now = DateTime.UtcNow

                // Check for STEP N/M pattern
                let stepMatch = stepPattern.Match(line)
                if stepMatch.Success then
                    let stepNum = Int32.Parse(stepMatch.Groups.[1].Value)
                    let totalSteps = Int32.Parse(stepMatch.Groups.[2].Value)
                    let instruction = stepMatch.Groups.[3].Value.Trim()

                    // Record duration of previous step
                    if progress.CompletedSteps > 0 then
                        let dur = int64 (now - lastStepStart).TotalMilliseconds
                        stepDurations.Add(progress.CompletedSteps, dur)
                        ema.Update(float dur)

                    lastStepStart <- now
                    progress <- { progress with
                                    TotalSteps = totalSteps
                                    CompletedSteps = stepNum - 1
                                    CurrentStep = instruction }

                    // Calculate ETA
                    let remainingSteps = float (totalSteps - stepNum + 1)
                    let estRemaining =
                        if ema.IsInitialized then ema.Value * remainingSteps
                        else 0.0
                    progress <- { progress with EstimatedTotalMs = estRemaining }

                    // Render progress line
                    let pct = float (stepNum - 1) / float totalSteps * 100.0
                    clearLine()
                    let etaStr = if ema.IsInitialized then sprintf " | ETA: %s" (formatEta estRemaining) else ""
                    printf "  %s %3.0f%% | STEP %d/%d: %-35s%s"
                        (progressBar pct 20)
                        pct stepNum totalSteps
                        (if instruction.Length > 35 then instruction.[..34] else instruction)
                        etaStr

                    // Zenoh telemetry per step
                    ZenohPublish.publish
                        (sprintf "CP-BUILD-%s-S%02d" containerName stepNum)
                        (sprintf "indrajaal/mesh/build/%s/step" containerName)
                        (sprintf "STEP %d/%d: %s" stepNum totalSteps instruction)
                        (sprintf "{\"step\":%d,\"total\":%d,\"pct\":%.1f,\"eta_ms\":%.0f,\"cache_hits\":%d,\"instruction\":\"%s\"}"
                            stepNum totalSteps pct estRemaining progress.CacheHits (instruction.Replace("\"", "\\\"").Replace("\n", "")))

                // Check for cache hit
                elif cachePattern.IsMatch(line) then
                    progress <- { progress with CacheHits = progress.CacheHits + 1 }
                    clearLine()
                    printf "  \u001b[32m  ✓ Cache hit (step %d)\u001b[0m" (progress.CompletedSteps + 1)

                // Check for image ID
                elif imageIdPattern.IsMatch(line) then
                    let m = imageIdPattern.Match(line)
                    imageId <- Some(m.Groups.[1].Value)

                // Check for COMMIT (final image tag)
                elif commitPattern.IsMatch(line) then
                    let m = commitPattern.Match(line)
                    clearLine()
                    printfn "  \u001b[32m\u001b[1m  ✓ COMMIT: %s\u001b[0m" (m.Groups.[1].Value)

                // Check for errors
                elif errorPattern.IsMatch(line) then
                    progress <- { progress with Errors = line :: progress.Errors }
                    clearLine()
                    printfn "  \u001b[31m  ✗ ERROR: %s\u001b[0m" line

                // Check for warnings
                elif warnPattern.IsMatch(line) then
                    progress <- { progress with Warnings = line :: progress.Warnings }

                // Regular output — don't spam, only show for stderr (build log)
                elif isStderr && line.Length > 2 then
                    // Show brief build output at low verbosity
                    if line.Contains("RUN") || line.Contains("COPY") || line.Contains("FROM") || line.Contains("-->") then
                        clearLine()
                        let truncated = if line.Length > 72 then line.[..71] + "..." else line
                        printf "  \u001b[90m  │ %s\u001b[0m" truncated

        // Wire up event handlers
        proc.OutputDataReceived.Add(fun e ->
            if not (isNull e.Data) then parseLine e.Data false)
        proc.ErrorDataReceived.Add(fun e ->
            if not (isNull e.Data) then parseLine e.Data true)

        proc.Start() |> ignore
        proc.BeginOutputReadLine()
        proc.BeginErrorReadLine()

        let completed = proc.WaitForExit(timeoutMs)
        heartbeatCts.Cancel()

        if completed then
            exitCode <- proc.ExitCode
        else
            proc.Kill()
            exitCode <- -1

        sw.Stop()

        // Record final step duration
        if progress.CompletedSteps > 0 && progress.TotalSteps > 0 then
            let lastDur = int64 (DateTime.UtcNow - lastStepStart).TotalMilliseconds
            stepDurations.Add(progress.TotalSteps, lastDur)

        // Final progress bar
        clearLine()
        printfn ""
        let success = exitCode = 0
        if success then
            printfn "  %s 100%% | BUILD COMPLETE in %s" (progressBar 100.0 20) (formatDuration (float sw.ElapsedMilliseconds))
        else
            printfn "  \u001b[31m  ✗ BUILD FAILED (exit %d) after %s\u001b[0m" exitCode (formatDuration (float sw.ElapsedMilliseconds))

        // Summary box
        printfn "  \u001b[35m\u001b[1m┌──────────────────────────────────────────────────────────────┐\u001b[0m"
        printfn "  \u001b[35m\u001b[1m│\u001b[0m  Container: %-48s \u001b[35m\u001b[1m│\u001b[0m" containerName
        printfn "  \u001b[35m\u001b[1m│\u001b[0m  Status:    %-48s \u001b[35m\u001b[1m│\u001b[0m" (if success then "\u001b[32mSUCCESS\u001b[0m" else "\u001b[31mFAILED\u001b[0m")
        printfn "  \u001b[35m\u001b[1m│\u001b[0m  Steps:     %d/%d (cache hits: %d)                            \u001b[35m\u001b[1m│\u001b[0m"
            (if success then progress.TotalSteps else progress.CompletedSteps)
            progress.TotalSteps
            progress.CacheHits
        printfn "  \u001b[35m\u001b[1m│\u001b[0m  Duration:  %-48s \u001b[35m\u001b[1m│\u001b[0m" (formatDuration (float sw.ElapsedMilliseconds))
        match imageId with
        | Some id -> printfn "  \u001b[35m\u001b[1m│\u001b[0m  Image ID:  %-48s \u001b[35m\u001b[1m│\u001b[0m" (if id.Length > 48 then id.[..47] else id)
        | None -> ()
        if not (List.isEmpty progress.Errors) then
            printfn "  \u001b[35m\u001b[1m│\u001b[0m  Errors:    \u001b[31m%d\u001b[0m                                               \u001b[35m\u001b[1m│\u001b[0m" (List.length progress.Errors)
        printfn "  \u001b[35m\u001b[1m└──────────────────────────────────────────────────────────────┘\u001b[0m"

        // Zenoh: announce build complete
        ZenohPublish.publish
            (sprintf "CP-BUILD-%s-DONE" containerName)
            (sprintf "indrajaal/mesh/build/%s" containerName)
            (sprintf "BUILD %s: %s in %s" (if success then "OK" else "FAIL") containerName (formatDuration (float sw.ElapsedMilliseconds)))
            (sprintf "{\"event\":\"build_done\",\"container\":\"%s\",\"success\":%b,\"exit_code\":%d,\"duration_ms\":%d,\"steps\":%d,\"cache_hits\":%d}"
                containerName success exitCode sw.ElapsedMilliseconds progress.TotalSteps progress.CacheHits)

        { ContainerName = containerName
          Success = success
          ExitCode = exitCode
          TotalSteps = progress.TotalSteps
          CacheHits = progress.CacheHits
          TotalDurationMs = sw.ElapsedMilliseconds
          StepDurations = stepDurations |> Seq.toList
          ImageId = imageId
          Errors = progress.Errors |> List.rev }

    // =========================================================================
    // Core: streamCommand — Streaming output for non-build commands
    // =========================================================================

    /// Stream a shell command with heartbeat, line counting, and Zenoh telemetry.
    /// Use for podman-compose up/down and similar commands that don't have STEP parsing.
    let streamCommand (label: string) (command: string) (args: string) (timeoutMs: int) : CommandStreamResult =
        let sw = Stopwatch.StartNew()
        let mutable outputLines = 0
        let mutable errorLines = 0
        let mutable lastOutput = ""
        let mutable exitCode = -1

        ZenohPublish.publish
            (sprintf "CP-CMD-%s-START" (label.Replace(" ", "-")))
            "indrajaal/mesh/command"
            (sprintf "CMD START: %s" label)
            (sprintf "{\"event\":\"cmd_start\",\"label\":\"%s\",\"command\":\"%s\"}" label command)

        let psi = ProcessStartInfo(
            FileName = command,
            Arguments = args,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        )
        use proc = new Process()
        proc.StartInfo <- psi
        proc.EnableRaisingEvents <- true

        // Heartbeat ticker
        let mutable lastActivity = DateTime.UtcNow
        let heartbeatCts = new CancellationTokenSource()
        let heartbeatThread = Thread(fun () ->
            try
                while not heartbeatCts.Token.IsCancellationRequested do
                    Thread.Sleep(5000)
                    if not heartbeatCts.Token.IsCancellationRequested then
                        let idleMs = (DateTime.UtcNow - lastActivity).TotalMilliseconds
                        if idleMs > 4500.0 then
                            clearLine()
                            printf "  \u001b[90m  ⏱ %s elapsed | %s | %d lines\u001b[0m"
                                (formatDuration sw.Elapsed.TotalMilliseconds)
                                label
                                outputLines
            with :? ThreadInterruptedException -> ()
        )
        heartbeatThread.IsBackground <- true
        heartbeatThread.Start()

        proc.OutputDataReceived.Add(fun e ->
            if not (isNull e.Data) then
                lastActivity <- DateTime.UtcNow
                outputLines <- outputLines + 1
                lastOutput <- e.Data
                clearLine()
                let truncated = if e.Data.Length > 72 then e.Data.[..71] + "..." else e.Data
                printf "  \u001b[34m  │ %s\u001b[0m" truncated)

        proc.ErrorDataReceived.Add(fun e ->
            if not (isNull e.Data) then
                lastActivity <- DateTime.UtcNow
                errorLines <- errorLines + 1
                clearLine()
                let truncated = if e.Data.Length > 72 then e.Data.[..71] + "..." else e.Data
                printf "  \u001b[33m  │ %s\u001b[0m" truncated)

        proc.Start() |> ignore
        proc.BeginOutputReadLine()
        proc.BeginErrorReadLine()

        let completed = proc.WaitForExit(timeoutMs)
        heartbeatCts.Cancel()

        if completed then exitCode <- proc.ExitCode
        else proc.Kill(); exitCode <- -1

        sw.Stop()
        clearLine()
        printfn ""

        ZenohPublish.publish
            (sprintf "CP-CMD-%s-DONE" (label.Replace(" ", "-")))
            "indrajaal/mesh/command"
            (sprintf "CMD %s: %s in %s" (if exitCode = 0 then "OK" else "FAIL") label (formatDuration (float sw.ElapsedMilliseconds)))
            (sprintf "{\"event\":\"cmd_done\",\"label\":\"%s\",\"exit_code\":%d,\"duration_ms\":%d,\"output_lines\":%d}"
                label exitCode sw.ElapsedMilliseconds outputLines)

        { Command = sprintf "%s %s" command args
          ExitCode = exitCode
          DurationMs = sw.ElapsedMilliseconds
          OutputLines = outputLines
          ErrorLines = errorLines
          LastOutput = lastOutput }
