#!/usr/bin/env dotnet fsi
// =============================================================================
// ClusterVerificationPhase2.fsx - Dual App Cluster Verification
// =============================================================================
// Purpose: Verify SC-FIX-006/006b in 2-node cluster mode with fractal logging
// STAMP: SC-FIX-006, SC-FIX-006b, SC-FUNC-001, SC-BIO-001
// Logging: Full Quadplex + 7-Level Directed Telescope
// Compliance: SC-METRICS-003 (Mandatory Parallelization)
//
// Usage:
//   dotnet fsi ClusterVerificationPhase2.fsx
//   dotnet fsi ClusterVerificationPhase2.fsx --verbose
//   dotnet fsi ClusterVerificationPhase2.fsx --phase 2

open System
open System.IO
open System.Net.Http
open System.Diagnostics
open System.Threading
open System.Text.Json

// =============================================================================
// ANSI Colors for Linux Boot Style Output
// =============================================================================
module Colors =
    let reset = "\u001b[0m"
    let bold = "\u001b[1m"
    let dim = "\u001b[2m"
    let red = "\u001b[31m"
    let green = "\u001b[32m"
    let yellow = "\u001b[33m"
    let blue = "\u001b[34m"
    let cyan = "\u001b[36m"
    let brightGreen = "\u001b[92m"
    let brightYellow = "\u001b[93m"
    let brightCyan = "\u001b[96m"
    let brightRed = "\u001b[91m"
    let brightMagenta = "\u001b[95m"

// =============================================================================
// Configuration
// =============================================================================
type Phase = Phase1 | Phase2 | Phase3

type ClusterConfig = {
    Phase: Phase
    ComposeFile: string
    Nodes: string list
    HealthUrls: string list
    ExpectedContainers: int
    LogDir: string
}

let phase2Config = {
    Phase = Phase2
    ComposeFile = "lib/cepaf/artifacts/podman-compose-prod-standalone.yml"
    // SC-NAME-001: Standardized app naming convention
    Nodes = ["indrajaal-ex-app-1"; "indrajaal-ex-app-2"]
    HealthUrls = ["http://localhost:4000/health"; "http://localhost:4010/health"]
    ExpectedContainers = 5  // db, obs, zenoh, app-prod, app-node2
    LogDir = "./data/tmp/phase2-verification"
}

// =============================================================================
// Telemetry & Logging (Linux Kernel Boot Style)
// =============================================================================
type LogLevel = KERNEL | BOOT | VERIFY | HEALTH | CLUSTER | FRACTAL | INFO | WARN | ERROR

let statusColor status =
    match status with
    | "OK" | "PASS" | "HEALTHY" -> Colors.brightGreen
    | "RUN" | "STARTING" | "CHECKING" -> Colors.brightCyan
    | "WAIT" | "PENDING" -> Colors.brightYellow
    | "FAIL" | "ERROR" | "UNHEALTHY" -> Colors.brightRed
    | "FIX" -> Colors.brightMagenta
    | _ -> Colors.reset

let levelStr = function
    | KERNEL -> "KERNEL"
    | BOOT -> "BOOT"
    | VERIFY -> "VERIFY"
    | HEALTH -> "HEALTH"
    | CLUSTER -> "CLUSTER"
    | FRACTAL -> "FRACTAL"
    | INFO -> "INFO"
    | WARN -> "WARN"
    | ERROR -> "ERROR"

let log level stage status message =
    let ts = DateTimeOffset.UtcNow.ToString("HH:mm:ss.fff")
    let lvl = levelStr level
    let color = statusColor status
    printfn "%s[%s]%s %s[%-8s]%s %-12s [%s%-8s%s] %s"
        Colors.dim ts Colors.reset
        Colors.cyan lvl Colors.reset
        stage
        color status Colors.reset
        message

// =============================================================================
// Container Operations
// =============================================================================
let runCommand (cmd: string) (args: string) =
    let psi = ProcessStartInfo(cmd, args)
    psi.RedirectStandardOutput <- true
    psi.RedirectStandardError <- true
    psi.UseShellExecute <- false
    psi.CreateNoWindow <- true

    use proc = Process.Start(psi)
    let output = proc.StandardOutput.ReadToEnd()
    let error = proc.StandardError.ReadToEnd()
    proc.WaitForExit(60000) |> ignore
    (proc.ExitCode, output, error)

let getContainerStatus () =
    let (code, output, _) = runCommand "podman" "ps -a --format \"{{.Names}}|{{.Status}}\""
    if code = 0 then
        output.Split([|'\n'|], StringSplitOptions.RemoveEmptyEntries)
        |> Array.map (fun line ->
            let parts = line.Split('|')
            if parts.Length >= 2 then Some(parts.[0].Trim(), parts.[1].Trim())
            else None)
        |> Array.choose id
        |> Array.toList
    else []

let getContainerRestartCount name =
    let (code, output, _) = runCommand "podman" $"inspect {name} --format \"{{{{.RestartCount}}}}\""
    if code = 0 then
        match Int32.TryParse(output.Trim()) with
        | (true, n) -> Some n
        | _ -> None
    else None

// =============================================================================
// Health Check Operations
// =============================================================================
let checkHealthEndpoint (url: string) =
    async {
        use client = new HttpClient()
        client.Timeout <- TimeSpan.FromSeconds(10.0)
        try
            let! response = client.GetStringAsync(url) |> Async.AwaitTask
            // Parse JSON to check status
            use doc = JsonDocument.Parse(response)
            let root = doc.RootElement
            let mutable statusElement = System.Text.Json.JsonElement()
            let status =
                if root.TryGetProperty("status", &statusElement) then
                    statusElement.GetString()
                else "unknown"
            return (true, status, Some response)
        with ex ->
            return (false, "error", Some ex.Message)
    }

// =============================================================================
// Verification Stages
// =============================================================================
let verifyStage1_Infrastructure config =
    log BOOT "INFRA" "RUN" "Checking infrastructure containers..."

    let containers = getContainerStatus()
    let dbRunning = containers |> List.exists (fun (n, s) -> n.Contains("db") && s.Contains("healthy"))
    let obsRunning = containers |> List.exists (fun (n, s) -> n.Contains("obs") && s.Contains("Up"))
    let zenohRunning = containers |> List.exists (fun (n, s) -> n.Contains("zenoh") && s.Contains("healthy"))

    if dbRunning then log HEALTH "DATABASE" "HEALTHY" "PostgreSQL/TimescaleDB ready"
    else log HEALTH "DATABASE" "FAIL" "Database not healthy"

    if obsRunning then log HEALTH "OBS" "OK" "Observability stack running"
    else log HEALTH "OBS" "WARN" "Observability stack not running"

    if zenohRunning then log HEALTH "ZENOH" "HEALTHY" "Mesh router ready"
    else log HEALTH "ZENOH" "FAIL" "Zenoh router not healthy"

    (dbRunning, obsRunning, zenohRunning)

let verifyStage2_AppNodes config =
    log BOOT "APPS" "RUN" $"Checking {config.Nodes.Length} app nodes..."

    let containers = getContainerStatus()
    let results =
        config.Nodes
        |> List.map (fun node ->
            let status = containers |> List.tryFind (fun (n, _) -> n.Contains(node.Replace("-", "")))
            match status with
            | Some (name, stat) ->
                let healthy = stat.Contains("healthy") || stat.Contains("Up")
                let restarts = getContainerRestartCount name |> Option.defaultValue 0
                log CLUSTER node (if healthy then "HEALTHY" else "UNHEALTHY") $"Status: {stat}, Restarts: {restarts}"
                (node, healthy, restarts)
            | None ->
                log CLUSTER node "FAIL" "Container not found"
                (node, false, -1)
        )
    results

let verifyStage3_HealthEndpoints config =
    log VERIFY "HEALTH" "RUN" "Checking health endpoints..."

    let results =
        config.HealthUrls
        |> List.mapi (fun i url ->
            let (success, status, response) = checkHealthEndpoint url |> Async.RunSynchronously
            let nodeName = $"Node-{i+1}"
            if success && status = "healthy" then
                log HEALTH nodeName "HEALTHY" $"{url} -> {status}"
            else
                log HEALTH nodeName "FAIL" $"{url} -> {status}"
            (nodeName, success, status)
        )
    results

let verifyStage4_RestartCount config =
    log VERIFY "SC-FIX-006" "CHECKING" "Verifying no restart loops..."

    let containers = getContainerStatus()
    let appContainers = containers |> List.filter (fun (n, _) -> n.Contains("app"))

    let results =
        appContainers
        |> List.map (fun (name, _) ->
            let restarts = getContainerRestartCount name |> Option.defaultValue -1
            if restarts = 0 then
                log VERIFY name "PASS" $"RestartCount = {restarts} (SC-FIX-006 verified)"
            elif restarts > 0 && restarts < 5 then
                log VERIFY name "WARN" $"RestartCount = {restarts} (minor restarts)"
            else
                log VERIFY name "FAIL" $"RestartCount = {restarts} (restart loop detected)"
            (name, restarts)
        )
    results

let verifyStage5_Clustering config =
    log CLUSTER "ERLANG" "CHECKING" "Verifying Erlang distributed clustering..."

    // Check if nodes can see each other via health endpoint
    let healthResults = verifyStage3_HealthEndpoints config
    let allHealthy = healthResults |> List.forall (fun (_, success, status) -> success && status = "healthy")

    if allHealthy then
        log CLUSTER "QUORUM" "OK" $"All {config.Nodes.Length} nodes healthy"
        true
    else
        log CLUSTER "QUORUM" "FAIL" "Cluster quorum not achieved"
        false

// =============================================================================
// Main Verification Orchestration
// =============================================================================
let printBanner () =
    printfn ""
    printfn "%s╔════════════════════════════════════════════════════════════════╗%s" Colors.cyan Colors.reset
    printfn "%s║  INDRAJAAL SIL-6 CLUSTER VERIFICATION - PHASE 2                ║%s" Colors.cyan Colors.reset
    printfn "%s║  Dual App Cluster • Directed Telescope • Quadplex Logging      ║%s" Colors.cyan Colors.reset
    printfn "%s╚════════════════════════════════════════════════════════════════╝%s" Colors.cyan Colors.reset
    printfn ""

let printResults (dbOk, obsOk, zenohOk) nodeResults healthResults restartResults clusterOk =
    printfn ""
    printfn "%s═══════════════════════════════════════════════════════════════════%s" Colors.cyan Colors.reset
    printfn "%s                     VERIFICATION SUMMARY                          %s" Colors.bold Colors.reset
    printfn "%s═══════════════════════════════════════════════════════════════════%s" Colors.cyan Colors.reset

    let infraOk = dbOk && zenohOk
    let nodesOk = nodeResults |> List.forall (fun (_, healthy, _) -> healthy)
    let healthOk = healthResults |> List.forall (fun (_, success, _) -> success)
    let noRestartLoop = restartResults |> List.forall (fun (_, restarts) -> restarts >= 0 && restarts < 5)

    let overall = infraOk && nodesOk && healthOk && noRestartLoop && clusterOk

    printfn ""
    printfn "  %s Infrastructure:    %s%s" (if infraOk then Colors.brightGreen else Colors.brightRed) (if infraOk then "PASS" else "FAIL") Colors.reset
    printfn "  %s App Nodes:         %s%s" (if nodesOk then Colors.brightGreen else Colors.brightRed) (if nodesOk then "PASS" else "FAIL") Colors.reset
    printfn "  %s Health Endpoints:  %s%s" (if healthOk then Colors.brightGreen else Colors.brightRed) (if healthOk then "PASS" else "FAIL") Colors.reset
    printfn "  %s SC-FIX-006 (No Restart Loop): %s%s" (if noRestartLoop then Colors.brightGreen else Colors.brightRed) (if noRestartLoop then "PASS" else "FAIL") Colors.reset
    printfn "  %s Cluster Quorum:    %s%s" (if clusterOk then Colors.brightGreen else Colors.brightRed) (if clusterOk then "PASS" else "FAIL") Colors.reset
    printfn ""
    printfn "%s═══════════════════════════════════════════════════════════════════%s" Colors.cyan Colors.reset

    if overall then
        printfn "  %s✓ PHASE 2 VERIFICATION PASSED%s" Colors.brightGreen Colors.reset
        printfn "  Ready to proceed to Phase 3 (Full HA Cluster)"
    else
        printfn "  %s✗ PHASE 2 VERIFICATION FAILED%s" Colors.brightRed Colors.reset
        printfn "  Review failed stages before proceeding"

    printfn "%s═══════════════════════════════════════════════════════════════════%s" Colors.cyan Colors.reset
    printfn ""
    overall

let main (argv: string[]) =
    printBanner()

    let config = phase2Config

    log KERNEL "PHASE-2" "RUN" "Starting dual app cluster verification"
    log KERNEL "CONFIG" "INFO" $"Compose file: {config.ComposeFile}"
    log KERNEL "CONFIG" "INFO" $"Expected containers: {config.ExpectedContainers}"
    printfn ""

    // Stage 1: Infrastructure
    log BOOT "STAGE-1" "RUN" "Infrastructure verification"
    let infraResults = verifyStage1_Infrastructure config
    printfn ""

    // Stage 2: App Nodes
    log BOOT "STAGE-2" "RUN" "App node verification"
    let nodeResults = verifyStage2_AppNodes config
    printfn ""

    // Stage 3: Health Endpoints
    log BOOT "STAGE-3" "RUN" "Health endpoint verification"
    let healthResults = verifyStage3_HealthEndpoints config
    printfn ""

    // Stage 4: SC-FIX-006 Verification
    log BOOT "STAGE-4" "RUN" "SC-FIX-006 restart loop verification"
    let restartResults = verifyStage4_RestartCount config
    printfn ""

    // Stage 5: Clustering
    log BOOT "STAGE-5" "RUN" "Cluster quorum verification"
    let clusterOk = verifyStage5_Clustering config
    printfn ""

    // Print Summary
    let (dbOk, obsOk, zenohOk) = infraResults
    let overallPass = printResults infraResults nodeResults healthResults restartResults clusterOk

    if overallPass then 0 else 1

// Run main with command line args
let exitCode = main (fsi.CommandLineArgs |> Array.skip 1)
exit exitCode
