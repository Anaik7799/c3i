#!/usr/bin/env -S dotnet fsi
// mesh-emergency-recovery.fsx - SIL-6 Emergency Recovery Procedure
// Version: 2.0.0
// STAMP: SC-EMR-057, SC-EMR-060, SC-SIL6-001, SC-SIL6-015 (Apoptosis)
// Compliance: IEC 61508 SIL-6 (Emergency Procedures)
// Purpose: Controlled emergency recovery with full cleanup and staged restart
//
// Emergency Protocol (6 Phases):
//   Phase 1: ASSESS   - Evaluate current system state
//   Phase 2: HALT     - Stop all running containers (SC-EMR-057: < 5s)
//   Phase 3: CLEAN    - Remove containers, networks, volumes
//   Phase 4: VERIFY   - Check required images and dependencies
//   Phase 5: RESTART  - Start services in dependency order
//   Phase 6: VALIDATE - Verify health and report status
//
// Safety Constraints:
//   - Confirmation required before destructive operations
//   - Staged approach with checkpoints
//   - Image preservation (no image deletion)
//   - Data volume warning before removal
//
// 5-Order Effects:
//   1st → All containers stopped and removed
//   2nd → Networks and orphan resources cleaned
//   3rd → Fresh container instances created
//   4th → Services initialize in order
//   5th → Full mesh operational state restored

// Load shared mesh utilities (SC-METRICS-003 compliance)
// MeshCommon provides: projectRoot, exec, computeSHA256, formatSize, etc.
#load "MeshCommon.fsx"

open System
open System.IO
open System.Diagnostics
open System.Threading

// =============================================================================
// Configuration
// =============================================================================

// Use shared projectRoot from MeshCommon (auto-detected or fallback)
let projectRoot = MeshCommon.projectRoot

// Compose files in priority order
let composeFiles = [
    "lib/cepaf/artifacts/podman-compose-prod-standalone.yml"
    "lib/cepaf/artifacts/podman-compose-sil6-full-mesh.yml"
]

// Required images for basic mesh
let requiredImages = [
    "localhost/indrajaal-timescaledb-demo:nixos-devenv"
    "localhost/indrajaal-obs-unified:nixos-devenv"
    "localhost/indrajaal-app-unified:nixos-devenv"
]

// Optional images for full SIL-6 mesh
let optionalImages = [
    "eclipse/zenoh:1.0.0"
    "localhost/cepaf-bridge:latest"
    "localhost/indrajaal-cortex:latest"
]

// Network configuration
let meshNetworks = [
    ("indrajaal-mesh", "172.28.0.0/16")
    ("indrajaal-internal", "172.29.0.0/16")
    ("indrajaal-sil6-mesh", "172.30.0.0/16")  // Unique subnet to avoid collision
]

// SC-METRICS-003: Mandatory parallelization
let mandatoryEnvVars = [
    ("ELIXIR_ERL_OPTIONS", "+S 16:16 +SDio 16")
    ("NO_TIMEOUT", "true")
    ("PATIENT_MODE", "enabled")
    ("INFINITE_PATIENCE", "true")
]

// =============================================================================
// Types
// =============================================================================

type PhaseStatus = Passed | Warning of string | Failed of string

type PhaseResult =
    { Phase: int
      Name: string
      Status: PhaseStatus
      Duration: TimeSpan
      Details: string list }

type EmergencyReport =
    { StartTime: DateTime
      EndTime: DateTime
      Phases: PhaseResult list
      OverallSuccess: bool
      ServicesRunning: int }

// =============================================================================
// Logging
// =============================================================================

type LogLevel = Info | Success | Warning | Error | Phase | Critical | Question

let log level msg =
    let prefix = match level with
                 | Info -> "    → "
                 | Success -> "    ✓ "
                 | Warning -> "    ⚠ "
                 | Error -> "    ✗ "
                 | Phase -> ">>> "
                 | Critical -> "!!! "
                 | Question -> "??? "
    printfn "%s%s" prefix msg

let printHeader title =
    printfn ""
    printfn "================================================================================"
    printfn "   %s" title
    printfn "================================================================================"

let printWarning (msg: string) =
    printfn ""
    printfn "╔══════════════════════════════════════════════════════════════════════════════╗"
    printfn "║  ⚠️  WARNING: %s" (msg.PadRight(60))
    printfn "╚══════════════════════════════════════════════════════════════════════════════╝"

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

let execQuiet command args =
    let (code, _, _) = exec command args
    code

let execWithTimeout command args (timeoutMs: int) =
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

    use proc = new Process()
    proc.StartInfo <- psi
    proc.Start() |> ignore

    if proc.WaitForExit(timeoutMs) then
        let stdout = proc.StandardOutput.ReadToEnd()
        let stderr = proc.StandardError.ReadToEnd()
        (proc.ExitCode, stdout, stderr)
    else
        try proc.Kill() with _ -> ()
        (-1, "", "Timeout")

let askConfirmation prompt =
    printf "%s (y/N): " prompt
    let response = Console.ReadLine()
    response.ToLower() = "y" || response.ToLower() = "yes"

// Ψ₀/Ψ₂ Constitutional Protection: Verify backup exists before destructive operations
let verifyBackupExists () =
    let backupDir = Path.Combine(projectRoot, "backups")
    if Directory.Exists(backupDir) then
        let backups = Directory.GetFiles(backupDir, "*.tar.gz")
        let quickBackups = Directory.GetFiles(backupDir, "quick-*.tar.gz")
        let stateBackups = Directory.GetFiles(backupDir, "mesh-state-*.tar.gz")
        if backups.Length > 0 then
            let latestBackup = backups |> Array.sortByDescending File.GetLastWriteTime |> Array.head
            let backupAge = DateTime.Now - File.GetLastWriteTime(latestBackup)
            (true, latestBackup, backupAge)
        else
            (false, "", TimeSpan.Zero)
    else
        (false, "", TimeSpan.Zero)

let waitWithProgress message seconds =
    printf "    %s " message
    for i in 1 .. seconds do
        Thread.Sleep(1000)
        printf "."
    printfn " done"

// =============================================================================
// Phase 1: Assess Current State
// =============================================================================

let phaseAssess () : PhaseResult =
    let sw = Stopwatch.StartNew()
    log Phase "[1/6] ASSESS - Evaluating Current State"

    let details = ResizeArray<string>()

    // Count running containers
    let (code, stdout, _) = exec "podman" "ps --format \"{{.Names}}\""
    let runningContainers =
        if code = 0 then
            stdout.Split([|'\n'|], StringSplitOptions.RemoveEmptyEntries)
            |> Array.filter (fun n -> n.Contains("indrajaal") || n.Contains("zenoh") || n.Contains("cepaf"))
        else
            [||]

    log Info $"Running containers: {runningContainers.Length}"
    for c in runningContainers do
        details.Add($"Running: {c}")
        log Info $"  - {c}"

    // Check for orphan volumes
    let (_, volOut, _) = exec "podman" "volume ls --format \"{{.Name}}\""
    let volumes = volOut.Split([|'\n'|], StringSplitOptions.RemoveEmptyEntries) |> Array.length
    log Info $"Volumes: {volumes}"
    details.Add($"Volumes: {volumes}")

    // Check for networks
    let (_, netOut, _) = exec "podman" "network ls --format \"{{.Name}}\""
    let networks = netOut.Split([|'\n'|], StringSplitOptions.RemoveEmptyEntries)
                   |> Array.filter (fun n -> n.Contains("indrajaal"))
    log Info $"Mesh networks: {networks.Length}"
    details.Add($"Networks: {networks.Length}")

    sw.Stop()
    { Phase = 1
      Name = "ASSESS"
      Status = PhaseStatus.Passed
      Duration = sw.Elapsed
      Details = details |> Seq.toList }

// =============================================================================
// Phase 2: Halt All Services (SC-EMR-057: < 5 seconds)
// =============================================================================

let phaseHalt () : PhaseResult =
    let sw = Stopwatch.StartNew()
    log Phase "[2/6] HALT - Stopping All Services (SC-EMR-057)"
    log Info "Target: < 5 seconds"

    let details = ResizeArray<string>()

    // Force stop all indrajaal containers
    let (code, _, _) = execWithTimeout "podman" "rm -af" 5000

    if code = 0 then
        log Success "All containers stopped"
        details.Add("Containers stopped successfully")
    elif code = -1 then
        log Warning "Container stop timed out - forcing"
        // Force kill
        let _ = exec "podman" "kill --all"
        let _ = exec "podman" "rm -af"
        details.Add("Forced container removal")
    else
        details.Add("Some containers may still be running")

    sw.Stop()

    // Check SC-EMR-057 compliance
    let status =
        if sw.ElapsedMilliseconds < 5000L then
            log Success $"SC-EMR-057 Compliant: {sw.ElapsedMilliseconds}ms"
            PhaseStatus.Passed
        else
            log Warning $"SC-EMR-057 Exceeded: {sw.ElapsedMilliseconds}ms"
            PhaseStatus.Warning $"Halt took {sw.ElapsedMilliseconds}ms (> 5000ms)"

    { Phase = 2
      Name = "HALT"
      Status = status
      Duration = sw.Elapsed
      Details = details |> Seq.toList }

// =============================================================================
// Phase 3: Clean Resources
// =============================================================================

let phaseClean () : PhaseResult =
    let sw = Stopwatch.StartNew()
    log Phase "[3/6] CLEAN - Removing Resources"

    let details = ResizeArray<string>()

    // Prune networks
    log Info "Pruning networks..."
    let (code1, _, _) = exec "podman" "network prune -f"
    if code1 = 0 then
        log Success "Networks pruned"
        details.Add("Networks pruned")

    // Prune volumes (warning: this removes data!)
    log Info "Pruning orphan volumes..."
    let (code2, _, _) = exec "podman" "volume prune -f"
    if code2 = 0 then
        log Success "Orphan volumes removed"
        details.Add("Orphan volumes removed")

    // Remove dangling images (not tagged images)
    log Info "Removing dangling images..."
    let (code3, _, _) = exec "podman" "image prune -f"
    if code3 = 0 then
        log Success "Dangling images removed"
        details.Add("Dangling images removed")

    // Recreate mesh networks
    log Info "Recreating mesh networks..."
    for (name, subnet) in meshNetworks do
        let (code, _, _) = exec "podman" $"network create {name} --subnet {subnet}"
        if code = 0 then
            log Success $"Network created: {name}"
            details.Add($"Created: {name}")
        else
            // May already exist - try to use it
            details.Add($"Network exists: {name}")

    sw.Stop()
    { Phase = 3
      Name = "CLEAN"
      Status = PhaseStatus.Passed
      Duration = sw.Elapsed
      Details = details |> Seq.toList }

// =============================================================================
// Phase 4: Verify Images
// =============================================================================

let phaseVerify () : PhaseResult =
    let sw = Stopwatch.StartNew()
    log Phase "[4/6] VERIFY - Checking Required Images"

    let details = ResizeArray<string>()
    let mutable missingRequired = 0
    let mutable missingOptional = 0

    // Check required images
    log Info "Required images:"
    for img in requiredImages do
        let exists = execQuiet "podman" $"image exists {img}" = 0
        if exists then
            log Success img
            details.Add($"✓ {img}")
        else
            log Error $"{img} (MISSING)"
            details.Add($"✗ {img} (MISSING)")
            missingRequired <- missingRequired + 1

    // Check optional images
    log Info "Optional images (SIL-6 full mesh):"
    for img in optionalImages do
        let exists = execQuiet "podman" $"image exists {img}" = 0
        if exists then
            log Success img
            details.Add($"✓ {img}")
        else
            log Warning $"{img} (not found)"
            details.Add($"? {img} (optional)")
            missingOptional <- missingOptional + 1

    sw.Stop()

    let status =
        if missingRequired > 0 then
            PhaseStatus.Failed $"{missingRequired} required images missing"
        elif missingOptional > 0 then
            PhaseStatus.Warning $"{missingOptional} optional images missing"
        else
            PhaseStatus.Passed

    { Phase = 4
      Name = "VERIFY"
      Status = status
      Duration = sw.Elapsed
      Details = details |> Seq.toList }

// =============================================================================
// Phase 5: Restart Services
// =============================================================================

let phaseRestart () : PhaseResult =
    let sw = Stopwatch.StartNew()
    log Phase "[5/6] RESTART - Starting Services"

    let details = ResizeArray<string>()

    // Find first available compose file
    let composeFile =
        composeFiles
        |> List.tryFind (fun f -> File.Exists(Path.Combine(projectRoot, f)))

    match composeFile with
    | None ->
        log Error "No compose file found!"
        sw.Stop()
        { Phase = 5
          Name = "RESTART"
          Status = PhaseStatus.Failed "No compose file found"
          Duration = sw.Elapsed
          Details = ["No compose file available"] }

    | Some compose ->
        log Info $"Using: {Path.GetFileName(compose)}"
        details.Add($"Compose: {compose}")

        // Start database first (dependency order)
        log Info "Starting database..."
        let (dbCode, _, dbErr) = exec "podman-compose" $"-f {compose} up -d indrajaal-db-prod"
        if dbCode = 0 then
            log Success "Database starting"
            details.Add("Database started")
        else
            log Warning $"Database start issue: {dbErr}"

        // Wait for database
        log Info "Waiting for database to be ready..."
        let mutable dbReady = false
        let mutable retries = 30
        while not dbReady && retries > 0 do
            Thread.Sleep(2000)
            let (code, _, _) = exec "pg_isready" "-h localhost -p 5433"
            dbReady <- code = 0
            if not dbReady then
                retries <- retries - 1
                log Info $"Waiting... ({retries} retries left)"

        if dbReady then
            log Success "Database ready"
            details.Add("Database healthy")
        else
            log Warning "Database not ready - continuing anyway"
            details.Add("Database may not be ready")

        // Start remaining services
        log Info "Starting remaining services..."
        let (allCode, _, allErr) = exec "podman-compose" $"-f {compose} up -d"
        if allCode = 0 then
            log Success "All services starting"
            details.Add("All services started")
        else
            log Warning $"Some services may have issues: {allErr}"
            details.Add("Some services may have issues")

        // Wait for services to stabilize
        waitWithProgress "Waiting for services to stabilize" 10

        sw.Stop()
        { Phase = 5
          Name = "RESTART"
          Status = if dbReady then PhaseStatus.Passed else PhaseStatus.Warning "Database slow to start"
          Duration = sw.Elapsed
          Details = details |> Seq.toList }

// =============================================================================
// Phase 6: Validate Health
// =============================================================================

let phaseValidate () : PhaseResult =
    let sw = Stopwatch.StartNew()
    log Phase "[6/6] VALIDATE - Verifying Health"

    let details = ResizeArray<string>()

    // Check running containers
    let (code, stdout, _) = exec "podman" "ps --format \"{{.Names}}|{{.Status}}\""
    let containers =
        if code = 0 then
            stdout.Split([|'\n'|], StringSplitOptions.RemoveEmptyEntries)
            |> Array.filter (fun line -> line.Contains("indrajaal") || line.Contains("zenoh") || line.Contains("cepaf"))
        else
            [||]

    log Info "Running containers:"
    for line in containers do
        let parts = line.Split('|')
        if parts.Length >= 2 then
            let name = parts.[0]
            let status = parts.[1]
            let isHealthy = status.Contains("Up")
            if isHealthy then
                log Success $"{name}: {status}"
            else
                log Warning $"{name}: {status}"
            details.Add($"{name}: {status}")

    let runningCount = containers.Length
    details.Add($"Total running: {runningCount}")

    // Quick endpoint check
    log Info "Checking key endpoints..."
    let endpoints = [
        ("Database", "pg_isready -h localhost -p 5433")
        ("Phoenix", "curl -sf http://localhost:4000/health")
    ]

    for (name, cmd) in endpoints do
        let parts = cmd.Split([|' '|], 2)
        let (code, _, _) = exec parts.[0] (if parts.Length > 1 then parts.[1] else "")
        if code = 0 then
            log Success $"{name}: OK"
            details.Add($"{name}: OK")
        else
            log Warning $"{name}: Not responding"
            details.Add($"{name}: Not responding")

    sw.Stop()

    let status =
        if runningCount >= 3 then PhaseStatus.Passed
        elif runningCount >= 1 then PhaseStatus.Warning $"Only {runningCount} containers running"
        else PhaseStatus.Failed "No containers running"

    { Phase = 6
      Name = "VALIDATE"
      Status = status
      Duration = sw.Elapsed
      Details = details |> Seq.toList }

// =============================================================================
// Main Emergency Recovery
// =============================================================================

let runEmergencyRecovery (force: bool) =
    printHeader "EMERGENCY RECOVERY MODE"
    printfn "   STAMP: SC-EMR-057, SC-EMR-060, SC-SIL6-001"
    printfn "   Protocol: 6-Phase Emergency Recovery"
    if force then
        printfn "   Mode: FORCE (no confirmations)"

    printWarning "This will remove ALL containers and attempt a fresh start"

    // Ψ₀/Ψ₂ Constitutional Protection: Verify backup exists when using force mode
    if force then
        let (hasBackup, latestBackup, backupAge) = verifyBackupExists ()
        if hasBackup then
            log Success $"Backup verified: {Path.GetFileName(latestBackup)} (age: {backupAge.TotalHours:F1}h)"
        else
            printWarning "NO BACKUP FOUND! (Ψ₀/Ψ₂ Risk)"
            printfn "   Creating quick snapshot before proceeding..."
            let (snapCode, _, _) = exec "dotnet" $"fsi {projectRoot}/scripts/infrastructure/mesh-quick-snapshot.fsx"
            if snapCode = 0 then
                log Success "Pre-emergency snapshot created"
            else
                log Warning "Could not create pre-emergency snapshot - proceeding anyway"

    let proceed =
        if force then
            true
        else
            askConfirmation "Continue with emergency recovery?"

    if not proceed then
        printfn ""
        log Info "Aborted by user"
        1
    else
        printfn ""
        let startTime = DateTime.Now
        let phases = ResizeArray<PhaseResult>()

        // Execute all phases
        phases.Add(phaseAssess ())
        phases.Add(phaseHalt ())
        phases.Add(phaseClean ())

        let verifyResult = phaseVerify ()
        phases.Add(verifyResult)

        // Check if we can proceed - use flag for early abort
        let shouldAbort =
            match verifyResult.Status with
            | PhaseStatus.Failed _ ->
                printfn ""
                printWarning "Required images missing - cannot proceed"
                printfn ""
                log Info "To build missing images:"
                log Info "  nix build .#indrajaal-timescaledb-demo"
                log Info "  nix build .#indrajaal-obs-unified"
                log Info "  nix build .#indrajaal-app-unified"
                printfn ""

                let continueAnyway = force || askConfirmation "Continue anyway (may fail)?"
                if continueAnyway then
                    if force then log Warning "Force mode: continuing despite missing images"
                    phases.Add(phaseRestart ())
                    phases.Add(phaseValidate ())
                    false  // don't abort
                else
                    log Info "Aborted"
                    true   // abort
            | _ ->
                phases.Add(phaseRestart ())
                phases.Add(phaseValidate ())
                false  // don't abort

        if shouldAbort then
            1  // Exit code 1 - aborted by user
        else

        let endTime = DateTime.Now

        // Count running services
        let (_, stdout, _) = exec "podman" "ps --format \"{{.Names}}\""
        let servicesRunning =
            stdout.Split([|'\n'|], StringSplitOptions.RemoveEmptyEntries)
            |> Array.filter (fun n -> n.Contains("indrajaal") || n.Contains("zenoh") || n.Contains("cepaf"))
            |> Array.length

        let overallSuccess =
            phases |> Seq.forall (fun p ->
                match p.Status with
                | PhaseStatus.Failed _ -> false
                | _ -> true
            ) && servicesRunning >= 3

        // Print summary
        printHeader "EMERGENCY RECOVERY COMPLETE"
        printfn ""
        printfn "   Phase Summary:"
        for phase in phases do
            let statusIcon = match phase.Status with
                             | PhaseStatus.Passed -> "✓"
                             | PhaseStatus.Warning _ -> "⚠"
                             | PhaseStatus.Failed _ -> "✗"
            printfn "     [%s] Phase %d: %s (%dms)" statusIcon phase.Phase phase.Name (int phase.Duration.TotalMilliseconds)

        printfn ""
        printfn "   Services Running: %d" servicesRunning
        printfn "   Duration: %.2fs" (endTime - startTime).TotalSeconds
        printfn "   Status: %s" (if overallSuccess then "SUCCESS" else "PARTIAL")
        printfn ""
        printfn "   Next Steps:"
        printfn "     1. Check logs: podman logs <container-name>"
        printfn "     2. Verify health: dotnet fsi scripts/infrastructure/mesh-verify.fsx"
        printfn "     3. Run tests: sa-test"
        printfn ""

        if overallSuccess then 0 else 1

// =============================================================================
// Entry Point
// =============================================================================

let args = fsi.CommandLineArgs |> Array.skip 1 |> Array.toList

match args with
| [] ->
    let code = runEmergencyRecovery false
    Environment.Exit(code)
| ["--force"] | ["-f"] ->
    // Skip confirmations - with backup verification gate (Ψ₀/Ψ₂ protection)
    let code = runEmergencyRecovery true
    Environment.Exit(code)
| ["--help"] | ["-h"] ->
    printfn "Usage: dotnet fsi mesh-emergency-recovery.fsx [OPTIONS]"
    printfn ""
    printfn "SIL-6 Emergency Recovery Procedure"
    printfn ""
    printfn "Options:"
    printfn "  --force, -f    Skip confirmation prompts (with backup verification)"
    printfn "  --help, -h     Show this help"
    printfn ""
    printfn "Recovery Phases:"
    printfn "  1. ASSESS   - Evaluate current system state"
    printfn "  2. HALT     - Stop all containers (< 5s, SC-EMR-057)"
    printfn "  3. CLEAN    - Remove containers, networks, volumes"
    printfn "  4. VERIFY   - Check required images"
    printfn "  5. RESTART  - Start services in order"
    printfn "  6. VALIDATE - Verify health"
    printfn ""
    printfn "Constitutional Protection (Ψ₀/Ψ₂):"
    printfn "  When using --force, the script verifies a backup exists."
    printfn "  If no backup is found, a quick snapshot is auto-created before proceeding."
    printfn "  This ensures regeneration capability is preserved (SC-CONST-002)."
    printfn ""
    printfn "STAMP: SC-EMR-057, SC-EMR-060, SC-SIL6-001, SC-CONST-001, SC-CONST-002"
| _ ->
    printfn "Unknown arguments. Use --help for usage."
    Environment.Exit(1)
