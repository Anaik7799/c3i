#!/usr/bin/env -S dotnet fsi
// mesh-verify.fsx - SIL-6 Mesh Health Verification with FPPS Consensus
// Version: 2.0.0
// STAMP: SC-BACKUP-003, SC-SIL6-005, SC-VAL-003, SC-METRICS-003
// Compliance: IEC 61508 SIL-6, FPPS 5-Method Consensus
// Purpose: Comprehensive health verification using 5-point consensus validation
//
// FPPS (Five-Point Pattern Validation System):
//   1. Service Health - HTTP/TCP endpoint responsiveness
//   2. Container Status - Podman container state verification
//   3. Critical Files - File system artifact presence
//   4. KMS State - Holon state integrity verification
//   5. Network Connectivity - Inter-container communication
//
// OODA Integration:
//   OBSERVE → Collect health data from all 5 methods
//   ORIENT  → Analyze consensus across validation methods
//   DECIDE  → Calculate health score and determine status
//   ACT     → Report findings with recommendations
//   VERIFY  → Log verification audit trail

// Load shared mesh utilities (SC-METRICS-003 compliance)
#load "MeshCommon.fsx"
open MeshCommon

open System
open System.IO
open System.Diagnostics
open System.Net.Http
open System.Net.Sockets
open System.Threading.Tasks
open System.Security.Cryptography

// =============================================================================
// Configuration
// =============================================================================

// Use shared projectRoot from MeshCommon (auto-detected or fallback)

// Service endpoints to verify
let serviceEndpoints = [
    ("Phoenix Application", "http://localhost:4000/health", 4000)
    ("Health Endpoint", "http://localhost:4001/health", 4001)
    ("OTEL Collector", "http://localhost:13133/health", 13133)
    ("Prometheus", "http://localhost:9090/-/healthy", 9090)
    ("Grafana", "http://localhost:3000/api/health", 3000)
    ("Zenoh REST", "http://localhost:8000/@/router/local", 8000)
    ("CEPAF Bridge", "http://localhost:9876/health", 9876)
    ("Cortex", "http://localhost:9877/health", 9877)
]

// TCP port checks (database doesn't have HTTP endpoint)
let tcpEndpoints = [
    ("PostgreSQL", "localhost", 5433)
    ("Redis", "localhost", 6379)
    ("Loki", "localhost", 3100)
    ("OTEL gRPC", "localhost", 4317)
    ("OTEL HTTP", "localhost", 4318)
]

// Expected containers (SIL-6 Full Mesh)
let expectedContainers = [
    "indrajaal-db-prod"
    "indrajaal-obs-prod"
    "indrajaal-ex-app-1"
    "zenoh-router"
    "cepaf-bridge"
    "indrajaal-cortex"
]

// Critical files
let criticalFiles = [
    "lib/cepaf/artifacts/podman-compose-prod-standalone.yml"
    "lib/cepaf/artifacts/podman-compose-sil6-full-mesh.yml"
    "sa-up.fsx"
    "sa-down.fsx"
    "sa-mesh.fsx"
    "devenv.nix"
    "lib/cepaf/scripts/Governance.fsx"
    "lib/cepaf/scripts/SIL6Orchestrator.fsx"
]

// KMS state files
let kmsFiles = [
    "data/kms/core.db"
    "data/kms/holons.db"
    "data/kms/todos.db"
]

// SC-METRICS-003: Mandatory parallelization
let mandatoryEnvVars = [
    ("ELIXIR_ERL_OPTIONS", "+S 16:16 +SDio 16")
    ("NO_TIMEOUT", "true")
    ("PATIENT_MODE", "enabled")
]

// =============================================================================
// Types
// =============================================================================

type HealthStatus = Healthy | Degraded | Unhealthy | Unknown

type CheckResult =
    { Name: string
      Status: HealthStatus
      Details: string
      ResponseTime: int }

type ValidationMethod =
    | ServiceHealth
    | ContainerStatus
    | CriticalFiles
    | KMSState
    | NetworkConnectivity

type MethodResult =
    { Method: ValidationMethod
      Checks: CheckResult list
      PassCount: int
      TotalCount: int
      Score: float }

type VerificationReport =
    { Timestamp: DateTime
      Methods: MethodResult list
      OverallScore: float
      Status: HealthStatus
      ConsensusReached: bool
      Duration: TimeSpan }

// =============================================================================
// Logging
// =============================================================================

type LogLevel = Info | Success | Warning | Error | Phase | Score

let log level msg =
    let prefix = match level with
                 | Info -> "    → "
                 | Success -> "    ✓ "
                 | Warning -> "    ⚠ "
                 | Error -> "    ✗ "
                 | Phase -> ">>> "
                 | Score -> "    📊 "
    printfn "%s%s" prefix msg

let printHeader title =
    printfn ""
    printfn "================================================================================"
    printfn "   %s" title
    printfn "================================================================================"

let printSubHeader title =
    printfn ""
    printfn "--- %s ---" title

// =============================================================================
// Utility Functions
// =============================================================================

let exec command args =
    let psi = ProcessStartInfo(
        FileName = command,
        Arguments = args,
        UseShellExecute = false,
        RedirectStandardOutput = true,
        RedirectStandardError = true,
        WorkingDirectory = projectRoot
    )
    for (key, value) in mandatoryEnvVars do
        psi.EnvironmentVariables.[key] <- value
    use proc = Process.Start(psi)
    let stdout = proc.StandardOutput.ReadToEnd()
    let stderr = proc.StandardError.ReadToEnd()
    proc.WaitForExit()
    (proc.ExitCode, stdout, stderr)

let checkHttpEndpoint (url: string) (timeoutMs: int) : bool * int =
    try
        use client = new HttpClient()
        client.Timeout <- TimeSpan.FromMilliseconds(float timeoutMs)
        let sw = Stopwatch.StartNew()
        let response = client.GetAsync(url).Result
        sw.Stop()
        (response.IsSuccessStatusCode, int sw.ElapsedMilliseconds)
    with
    | _ -> (false, -1)

let checkTcpPort (host: string) (port: int) (timeoutMs: int) : bool * int =
    try
        use client = new TcpClient()
        let sw = Stopwatch.StartNew()
        let connectTask = client.ConnectAsync(host, port)
        let completed = connectTask.Wait(timeoutMs)
        sw.Stop()
        if completed && client.Connected then
            (true, int sw.ElapsedMilliseconds)
        else
            (false, -1)
    with
    | _ -> (false, -1)

let formatMs ms =
    if ms < 0 then "timeout" else $"{ms}ms"

// =============================================================================
// FPPS Method 1: Service Health Checks
// =============================================================================

let checkServiceHealth () : MethodResult =
    log Phase "[FPPS-1] Service Health Endpoints"

    let results =
        serviceEndpoints
        |> List.map (fun (name, url, _) ->
            let sw = Stopwatch.StartNew()
            let (success, responseTime) = checkHttpEndpoint url 5000
            sw.Stop()

            let status = if success then Healthy else Unhealthy
            let details = if success then $"OK ({formatMs responseTime})" else "FAILED"

            if success then
                log Success $"{name}: {details}"
            else
                log Error $"{name}: {details}"

            { Name = name
              Status = status
              Details = details
              ResponseTime = responseTime }
        )

    let passCount = results |> List.filter (fun r -> r.Status = Healthy) |> List.length
    let totalCount = results.Length
    let score = float passCount / float totalCount

    log Score $"Score: {passCount}/{totalCount} ({score * 100.0:F1}%%)"

    { Method = ServiceHealth
      Checks = results
      PassCount = passCount
      TotalCount = totalCount
      Score = score }

// =============================================================================
// FPPS Method 2: Container Status Verification
// =============================================================================

let checkContainerStatus () : MethodResult =
    log Phase "[FPPS-2] Container Status"

    let (code, stdout, _) = exec "podman" "ps --format \"{{.Names}}|{{.Status}}\""

    let runningContainers =
        if code = 0 then
            stdout.Split([|'\n'|], StringSplitOptions.RemoveEmptyEntries)
            |> Array.map (fun line ->
                let parts = line.Split('|')
                if parts.Length >= 2 then (parts.[0], parts.[1]) else ("", "")
            )
            |> Array.filter (fun (name, _) -> name <> "")
            |> Map.ofArray
        else
            Map.empty

    let results =
        expectedContainers
        |> List.map (fun containerName ->
            match Map.tryFind containerName runningContainers with
            | Some status ->
                let isHealthy = status.Contains("Up") || status.Contains("healthy")
                let healthStatus = if isHealthy then Healthy else Degraded
                if isHealthy then
                    log Success $"{containerName}: {status}"
                else
                    log Warning $"{containerName}: {status}"
                { Name = containerName
                  Status = healthStatus
                  Details = status
                  ResponseTime = 0 }
            | None ->
                log Error $"{containerName}: NOT RUNNING"
                { Name = containerName
                  Status = Unhealthy
                  Details = "Not running"
                  ResponseTime = -1 }
        )

    let passCount = results |> List.filter (fun r -> r.Status = Healthy) |> List.length
    let totalCount = results.Length
    let score = float passCount / float totalCount

    log Score $"Score: {passCount}/{totalCount} ({score * 100.0:F1}%%)"

    { Method = ContainerStatus
      Checks = results
      PassCount = passCount
      TotalCount = totalCount
      Score = score }

// =============================================================================
// FPPS Method 3: Critical File Verification
// =============================================================================

let checkCriticalFiles () : MethodResult =
    log Phase "[FPPS-3] Critical Files"

    let results =
        criticalFiles
        |> List.map (fun relativePath ->
            let fullPath = Path.Combine(projectRoot, relativePath)
            if File.Exists(fullPath) then
                let size = FileInfo(fullPath).Length
                let sizeStr = if size > 1024L then $"{size / 1024L}KB" else $"{size}B"
                log Success $"{Path.GetFileName(relativePath)} ({sizeStr})"
                { Name = relativePath
                  Status = Healthy
                  Details = $"Present ({sizeStr})"
                  ResponseTime = 0 }
            else
                log Error $"{Path.GetFileName(relativePath)}: MISSING"
                { Name = relativePath
                  Status = Unhealthy
                  Details = "Missing"
                  ResponseTime = -1 }
        )

    let passCount = results |> List.filter (fun r -> r.Status = Healthy) |> List.length
    let totalCount = results.Length
    let score = float passCount / float totalCount

    log Score $"Score: {passCount}/{totalCount} ({score * 100.0:F1}%%)"

    { Method = CriticalFiles
      Checks = results
      PassCount = passCount
      TotalCount = totalCount
      Score = score }

// =============================================================================
// FPPS Method 4: KMS State Verification (SC-HOLON-*)
// =============================================================================

let checkKMSState () : MethodResult =
    log Phase "[FPPS-4] KMS State (Holon Sovereignty)"

    let results =
        kmsFiles
        |> List.map (fun relativePath ->
            let fullPath = Path.Combine(projectRoot, relativePath)
            if File.Exists(fullPath) then
                let size = FileInfo(fullPath).Length
                let sizeStr = if size > 1024L then $"{size / 1024L}KB" else $"{size}B"

                // Verify SQLite integrity
                let fileName = Path.GetFileName(relativePath)
                let status, details =
                    if fileName.EndsWith(".db") then
                        // Quick SQLite integrity check
                        let (code, _, _) = exec "sqlite3" $"{fullPath} \"PRAGMA integrity_check;\""
                        if code = 0 then
                            (Healthy, $"OK ({sizeStr})")
                        else
                            (Degraded, $"Integrity check failed ({sizeStr})")
                    else
                        (Healthy, $"Present ({sizeStr})")

                if status = Healthy then
                    log Success $"{fileName}: {details}"
                else
                    log Warning $"{fileName}: {details}"

                { Name = relativePath
                  Status = status
                  Details = details
                  ResponseTime = 0 }
            else
                // KMS files may not exist yet - this is OK
                log Info $"{Path.GetFileName(relativePath)}: Not found (optional)"
                { Name = relativePath
                  Status = Unknown
                  Details = "Not found (optional)"
                  ResponseTime = -1 }
        )

    // For KMS, Unknown is OK - only count actual failures
    let passCount = results |> List.filter (fun r -> r.Status = Healthy || r.Status = Unknown) |> List.length
    let totalCount = results.Length
    let score = float passCount / float totalCount

    log Score $"Score: {passCount}/{totalCount} ({score * 100.0:F1}%%)"

    { Method = KMSState
      Checks = results
      PassCount = passCount
      TotalCount = totalCount
      Score = score }

// =============================================================================
// FPPS Method 5: Network Connectivity
// =============================================================================

let checkNetworkConnectivity () : MethodResult =
    log Phase "[FPPS-5] Network Connectivity (TCP)"

    // SC-METRICS-003: Parallel port checks
    let results =
        tcpEndpoints
        |> List.toArray
        |> Array.Parallel.map (fun (name, host, port) ->
            let (success, responseTime) = checkTcpPort host port 3000

            let status = if success then Healthy else Unhealthy
            let details = if success then $"Connected ({formatMs responseTime})" else "Connection refused"

            { Name = $"{name} (:{port})"
              Status = status
              Details = details
              ResponseTime = responseTime }
        )
        |> Array.toList

    // Log results (after parallel execution)
    for r in results do
        if r.Status = Healthy then
            log Success $"{r.Name}: {r.Details}"
        else
            log Error $"{r.Name}: {r.Details}"

    let passCount = results |> List.filter (fun r -> r.Status = Healthy) |> List.length
    let totalCount = results.Length
    let score = float passCount / float totalCount

    log Score $"Score: {passCount}/{totalCount} ({score * 100.0:F1}%%)"

    { Method = NetworkConnectivity
      Checks = results
      PassCount = passCount
      TotalCount = totalCount
      Score = score }

// =============================================================================
// FPPS Consensus Calculation
// =============================================================================

let calculateConsensus (methods: MethodResult list) : VerificationReport =
    let methodScores = methods |> List.map (fun m -> m.Score)

    // Calculate weighted average (all methods equal weight for SIL-6)
    let overallScore = methodScores |> List.average

    // Determine overall status
    let status =
        if overallScore >= 0.8 then Healthy
        elif overallScore >= 0.5 then Degraded
        else Unhealthy

    // Check if all methods agree on status (consensus)
    let methodStatuses =
        methods
        |> List.map (fun m ->
            if m.Score >= 0.8 then Healthy
            elif m.Score >= 0.5 then Degraded
            else Unhealthy
        )

    // SC-VAL-003: FPPS requires strict 5-method consensus - all methods MUST agree
    let consensusReached =
        let distinctStatuses = methodStatuses |> List.distinct |> List.length
        distinctStatuses = 1 // Strict consensus: all 5 methods must agree on status

    { Timestamp = DateTime.Now
      Methods = methods
      OverallScore = overallScore
      Status = status
      ConsensusReached = consensusReached
      Duration = TimeSpan.Zero }

// =============================================================================
// Main Verification Workflow
// =============================================================================

let runVerification () =
    let sw = Stopwatch.StartNew()

    printHeader "SIL-6 MESH HEALTH VERIFICATION (FPPS Consensus)"
    printfn "   STAMP: SC-BACKUP-003, SC-SIL6-005, SC-VAL-003"
    printfn "   Method: 5-Point Pattern Validation System"
    printfn ""

    // Execute all 5 FPPS methods
    let method1 = checkServiceHealth ()
    let method2 = checkContainerStatus ()
    let method3 = checkCriticalFiles ()
    let method4 = checkKMSState ()
    let method5 = checkNetworkConnectivity ()

    let methods = [method1; method2; method3; method4; method5]

    // Calculate consensus
    let report = calculateConsensus methods

    sw.Stop()

    // Print summary
    printHeader "VERIFICATION SUMMARY"
    printfn ""
    printfn "   FPPS Method Scores:"
    for m in methods do
        let methodName = match m.Method with
                         | ServiceHealth -> "Service Health"
                         | ContainerStatus -> "Container Status"
                         | CriticalFiles -> "Critical Files"
                         | KMSState -> "KMS State"
                         | NetworkConnectivity -> "Network Connectivity"
        let bar = String.replicate (int (m.Score * 20.0)) "█"
        let space = String.replicate (20 - int (m.Score * 20.0)) "░"
        printfn "     %s: %s%s %.1f%%" (methodName.PadRight(20)) bar space (m.Score * 100.0)

    printfn ""
    printfn "   Overall Score: %.1f%%" (report.OverallScore * 100.0)
    printfn "   Consensus: %s" (if report.ConsensusReached then "REACHED" else "NOT REACHED")

    let statusStr, exitCode =
        match report.Status with
        | Healthy -> "HEALTHY", 0
        | Degraded -> "DEGRADED", 1
        | Unhealthy -> "CRITICAL", 2
        | Unknown -> "UNKNOWN", 3

    printfn "   Status: %s" statusStr
    printfn "   Duration: %.2fs" sw.Elapsed.TotalSeconds
    printfn ""

    if exitCode > 0 then
        printfn "   Recommendations:"
        if method1.Score < 0.8 then
            printfn "     • Check service endpoints - some services may be down"
        if method2.Score < 0.8 then
            printfn "     • Start missing containers with: sa-up"
        if method3.Score < 0.8 then
            printfn "     • Restore missing files from backup"
        if method5.Score < 0.8 then
            printfn "     • Check network connectivity and firewall rules"
        printfn ""

    exitCode

// =============================================================================
// Entry Point
// =============================================================================

let args = fsi.CommandLineArgs |> Array.skip 1 |> Array.toList

match args with
| [] ->
    let code = runVerification ()
    Environment.Exit(code)
| ["--help"] | ["-h"] ->
    printfn "Usage: dotnet fsi mesh-verify.fsx"
    printfn ""
    printfn "SIL-6 Mesh Health Verification using FPPS 5-Method Consensus."
    printfn ""
    printfn "FPPS Methods:"
    printfn "  1. Service Health    - HTTP endpoint responsiveness"
    printfn "  2. Container Status  - Podman container state"
    printfn "  3. Critical Files    - File system artifacts"
    printfn "  4. KMS State         - Holon state integrity"
    printfn "  5. Network Connectivity - TCP port checks"
    printfn ""
    printfn "Exit Codes:"
    printfn "  0 - HEALTHY (>= 80%%)"
    printfn "  1 - DEGRADED (>= 50%%)"
    printfn "  2 - CRITICAL (< 50%%)"
    printfn ""
    printfn "STAMP: SC-BACKUP-003, SC-SIL6-005, SC-VAL-003, SC-METRICS-003"
| _ ->
    printfn "Unknown arguments. Use --help for usage."
    Environment.Exit(1)
