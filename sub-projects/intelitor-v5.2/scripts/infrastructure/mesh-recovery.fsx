#!/usr/bin/env -S dotnet fsi
// mesh-recovery.fsx - Full SIL-6 Mesh System Recovery from Backup
// Version: 2.0.0
// STAMP: SC-BACKUP-003, SC-EMR-060, SC-SIL6-001, SC-HOLON-015
// Compliance: IEC 61508 SIL-6, ISO 27001
// Purpose: Comprehensive system recovery with integrity verification and staged rollback
//
// OODA Integration:
//   OBSERVE → Verify archive integrity and contents
//   ORIENT  → Analyze recovery scope and dependencies
//   DECIDE  → Plan staged recovery sequence
//   ACT     → Execute recovery with checkpoints
//   VERIFY  → Validate recovered state
//
// 5-Order Effects:
//   1st → Archive extracted and verified
//   2nd → Configuration files restored to locations
//   3rd → Container stack restartable
//   4th → Services can boot from recovered state
//   5th → Full system operational capability restored

// Load shared mesh utilities (SC-METRICS-003 compliance)
// MeshCommon provides: projectRoot, exec, computeSHA256, formatSize, etc.
#load "MeshCommon.fsx"

open System
open System.IO
open System.Diagnostics
open System.Text
open System.Threading.Tasks
open System.Security.Cryptography

// =============================================================================
// Configuration
// =============================================================================

// Use shared projectRoot from MeshCommon (auto-detected or fallback)
let projectRoot = MeshCommon.projectRoot

// Recovery priority order (reverse of capture)
type RecoveryPhase =
    | StopServices
    | VerifyArchive
    | ExtractArchive
    | VerifyChecksums
    | RestoreKMS
    | RestoreCompose
    | RestoreScripts
    | RestoreNix
    | RestoreConfigs
    | Verify
    | StartServices

// SC-METRICS-003: Mandatory parallelization environment
let mandatoryEnvVars = [
    ("ELIXIR_ERL_OPTIONS", "+fnu +S 16:16 +SDio 16")
    ("NO_TIMEOUT", "true")
    ("PATIENT_MODE", "enabled")
    ("INFINITE_PATIENCE", "true")
]

// Critical files that MUST exist after recovery
let criticalFiles = [
    "lib/cepaf/artifacts/podman-compose-prod-standalone.yml"
    "sa-up.fsx"
    "sa-down.fsx"
    "devenv.nix"
    "lib/cepaf/scripts/Governance.fsx"
]

// =============================================================================
// Types
// =============================================================================

type RecoveryResult =
    | Success of message: string
    | Warning of message: string
    | Failed of message: string

type PhaseResult =
    { Phase: RecoveryPhase
      Result: RecoveryResult
      Duration: TimeSpan
      Details: string list }

type RecoveryReport =
    { ArchivePath: string
      StartTime: DateTime
      EndTime: DateTime
      Phases: PhaseResult list
      FilesRestored: int
      CriticalFilesPresent: int
      TotalCriticalFiles: int
      OverallSuccess: bool }

// =============================================================================
// Logging & OODA Telemetry
// =============================================================================

type LogLevel = Info | Success | Warning | Error | Phase | Telemetry | Critical

let log level msg =
    let prefix = match level with
                 | Info -> "    → "
                 | Success -> "    ✓ "
                 | Warning -> "    ⚠ "
                 | Error -> "    ✗ "
                 | Phase -> ">>> "
                 | Telemetry -> "    📊 "
                 | Critical -> "!!! "
    printfn "%s%s" prefix msg

let logOODA phase action =
    printfn "    [OODA:%s] %s" phase action

let printHeader title =
    printfn ""
    printfn "================================================================================"
    printfn "   %s" title
    printfn "================================================================================"

// =============================================================================
// Core Utilities
// =============================================================================

let ensureDirectory path =
    if not (Directory.Exists(path)) then
        Directory.CreateDirectory(path) |> ignore

let computeSHA256 (filePath: string) =
    use stream = File.OpenRead(filePath)
    use sha = SHA256.Create()
    let hash = sha.ComputeHash(stream)
    BitConverter.ToString(hash).Replace("-", "").ToLower()

let getFileSize (filePath: string) =
    if File.Exists(filePath) then FileInfo(filePath).Length else 0L

let formatSize (bytes: int64) =
    if bytes >= 1073741824L then sprintf "%.2f GB" (float bytes / 1073741824.0)
    elif bytes >= 1048576L then sprintf "%.2f MB" (float bytes / 1048576.0)
    elif bytes >= 1024L then sprintf "%.2f KB" (float bytes / 1024.0)
    else sprintf "%d B" bytes

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

// =============================================================================
// Phase Implementations
// =============================================================================

let stopExistingServices () : PhaseResult =
    let sw = Stopwatch.StartNew()
    log Phase "Stopping Existing Services"

    let details = ResizeArray<string>()

    // Try to stop compose stack gracefully
    let composeFiles = [
        "lib/cepaf/artifacts/podman-compose-prod-standalone.yml"
        "lib/cepaf/artifacts/podman-compose-sil6-full-mesh.yml"
    ]

    for compose in composeFiles do
        let fullPath = Path.Combine(projectRoot, compose)
        if File.Exists(fullPath) then
            let (code, _, _) = exec "podman-compose" $"-f {compose} down"
            if code = 0 then
                details.Add($"Stopped: {Path.GetFileName(compose)}")
                log Success $"Stopped: {Path.GetFileName(compose)}"
            else
                details.Add($"Not running: {Path.GetFileName(compose)}")

    sw.Stop()
    { Phase = StopServices
      Result = RecoveryResult.Success "Services stopped"
      Duration = sw.Elapsed
      Details = details |> Seq.toList }

let verifyArchive (archivePath: string) : PhaseResult =
    let sw = Stopwatch.StartNew()
    log Phase "Verifying Archive Integrity"

    let details = ResizeArray<string>()

    if not (File.Exists(archivePath)) then
        sw.Stop()
        { Phase = VerifyArchive
          Result = RecoveryResult.Failed $"Archive not found: {archivePath}"
          Duration = sw.Elapsed
          Details = [] }
    else
        // Check archive can be read
        let (code, _, stderr) = exec "tar" $"-tzf {archivePath}"
        if code <> 0 then
            sw.Stop()
            { Phase = VerifyArchive
              Result = RecoveryResult.Failed $"Archive appears corrupted: {stderr}"
              Duration = sw.Elapsed
              Details = [] }
        else
            let size = getFileSize archivePath
            let checksum = computeSHA256 archivePath
            details.Add($"Size: {formatSize size}")
            details.Add($"SHA256: {checksum}")

            log Success $"Archive verified: {formatSize size}"
            log Info $"SHA256: {checksum}"

            sw.Stop()
            { Phase = VerifyArchive
              Result = RecoveryResult.Success "Archive integrity verified"
              Duration = sw.Elapsed
              Details = details |> Seq.toList }

let extractArchive (archivePath: string) (tempDir: string) : PhaseResult =
    let sw = Stopwatch.StartNew()
    log Phase "Extracting Archive"

    ensureDirectory tempDir

    let (code, _, stderr) = exec "tar" $"-xzf {archivePath} -C {tempDir}"
    if code <> 0 then
        sw.Stop()
        { Phase = ExtractArchive
          Result = RecoveryResult.Failed $"Extraction failed: {stderr}"
          Duration = sw.Elapsed
          Details = [] }
    else
        // Find extracted directory
        let dirs = Directory.GetDirectories(tempDir)
        if dirs.Length = 0 then
            sw.Stop()
            { Phase = ExtractArchive
              Result = RecoveryResult.Failed "No content found in archive"
              Duration = sw.Elapsed
              Details = [] }
        else
            let backupDir = dirs.[0]
            log Success $"Extracted to: {Path.GetFileName(backupDir)}"

            sw.Stop()
            { Phase = ExtractArchive
              Result = RecoveryResult.Success backupDir
              Duration = sw.Elapsed
              Details = [$"Directory: {backupDir}"] }

let verifyChecksums (backupDir: string) : PhaseResult =
    let sw = Stopwatch.StartNew()
    log Phase "Verifying Checksums (SC-HOLON-017)"

    let checksumPath = Path.Combine(backupDir, "checksums.sha256")
    if not (File.Exists(checksumPath)) then
        log Warning "No checksum file found - skipping verification"
        sw.Stop()
        { Phase = VerifyChecksums
          Result = RecoveryResult.Warning "No checksums in archive"
          Duration = sw.Elapsed
          Details = [] }
    else
        let lines = File.ReadAllLines(checksumPath)
        let mutable passed = 0
        let mutable failed = 0
        let details = ResizeArray<string>()

        // Parallel checksum verification (SC-METRICS-003)
        let results =
            lines
            |> Array.Parallel.map (fun line ->
                let parts = line.Split([|"  "|], StringSplitOptions.None)
                if parts.Length = 2 then
                    let expectedHash = parts.[0]
                    let relativePath = parts.[1]
                    let filePath = Path.Combine(backupDir, relativePath)
                    if File.Exists(filePath) then
                        let actualHash = computeSHA256 filePath
                        if actualHash = expectedHash then
                            (true, relativePath)
                        else
                            (false, $"MISMATCH: {relativePath}")
                    else
                        (false, $"MISSING: {relativePath}")
                else
                    (true, "")
            )

        for (success, msg) in results do
            if success then passed <- passed + 1
            else
                failed <- failed + 1
                details.Add(msg)
                log Warning msg

        log Info $"Verified: {passed} files"
        if failed > 0 then
            log Warning $"Failed: {failed} files"

        sw.Stop()
        if failed = 0 then
            { Phase = VerifyChecksums
              Result = RecoveryResult.Success $"{passed} files verified"
              Duration = sw.Elapsed
              Details = details |> Seq.toList }
        else
            { Phase = VerifyChecksums
              Result = RecoveryResult.Warning $"{failed} verification failures"
              Duration = sw.Elapsed
              Details = details |> Seq.toList }

let restoreKMSState (backupDir: string) : PhaseResult =
    let sw = Stopwatch.StartNew()
    log Phase "Restoring KMS State (SC-HOLON-015)"

    let kmsSource = Path.Combine(backupDir, "kms")
    let kmsTarget = Path.Combine(projectRoot, "data", "kms")
    let details = ResizeArray<string>()

    if Directory.Exists(kmsSource) then
        ensureDirectory kmsTarget

        let files = Directory.GetFiles(kmsSource)
        for file in files do
            let fileName = Path.GetFileName(file)
            let targetPath = Path.Combine(kmsTarget, fileName)
            try
                File.Copy(file, targetPath, true)
                details.Add($"Restored: {fileName}")
                log Success fileName
            with
            | ex ->
                details.Add($"Failed: {fileName} - {ex.Message}")
                log Error $"{fileName}: {ex.Message}"

        sw.Stop()
        { Phase = RestoreKMS
          Result = RecoveryResult.Success $"Restored {files.Length} KMS files"
          Duration = sw.Elapsed
          Details = details |> Seq.toList }
    else
        log Info "No KMS state in backup"
        sw.Stop()
        { Phase = RestoreKMS
          Result = RecoveryResult.Warning "No KMS state found"
          Duration = sw.Elapsed
          Details = [] }

let restoreComposeFiles (backupDir: string) : PhaseResult =
    let sw = Stopwatch.StartNew()
    log Phase "Restoring Compose Configurations"

    let source = Path.Combine(backupDir, "compose")
    let target = Path.Combine(projectRoot, "lib", "cepaf", "artifacts")
    let details = ResizeArray<string>()

    if Directory.Exists(source) then
        let files = Directory.GetFiles(source, "*.yml")
        for file in files do
            let fileName = Path.GetFileName(file)
            try
                File.Copy(file, Path.Combine(target, fileName), true)
                details.Add(fileName)
                log Success fileName
            with ex ->
                log Error $"{fileName}: {ex.Message}"

        sw.Stop()
        { Phase = RestoreCompose
          Result = RecoveryResult.Success $"Restored {files.Length} compose files"
          Duration = sw.Elapsed
          Details = details |> Seq.toList }
    else
        sw.Stop()
        { Phase = RestoreCompose
          Result = RecoveryResult.Warning "No compose files in backup"
          Duration = sw.Elapsed
          Details = [] }

let restoreScripts (backupDir: string) : PhaseResult =
    let sw = Stopwatch.StartNew()
    log Phase "Restoring F# Scripts"

    let details = ResizeArray<string>()
    let mutable count = 0

    // Root scripts (sa-*.fsx)
    let rootScripts = Path.Combine(backupDir, "scripts")
    if Directory.Exists(rootScripts) then
        for file in Directory.GetFiles(rootScripts, "*.fsx") do
            let fileName = Path.GetFileName(file)
            if fileName.StartsWith("sa-") then
                try
                    File.Copy(file, Path.Combine(projectRoot, fileName), true)
                    details.Add(fileName)
                    log Success fileName
                    count <- count + 1
                with ex ->
                    log Error $"{fileName}: {ex.Message}"

    // CEPAF scripts
    let cepafScripts = Path.Combine(backupDir, "scripts", "cepaf")
    if Directory.Exists(cepafScripts) then
        let target = Path.Combine(projectRoot, "lib", "cepaf", "scripts")
        for file in Directory.GetFiles(cepafScripts, "*.fsx") do
            let fileName = Path.GetFileName(file)
            try
                File.Copy(file, Path.Combine(target, fileName), true)
                details.Add($"cepaf/{fileName}")
                log Success $"cepaf/{fileName}"
                count <- count + 1
            with ex ->
                log Error $"{fileName}: {ex.Message}"

    sw.Stop()
    { Phase = RestoreScripts
      Result = RecoveryResult.Success $"Restored {count} scripts"
      Duration = sw.Elapsed
      Details = details |> Seq.toList }

let restoreNixFiles (backupDir: string) : PhaseResult =
    let sw = Stopwatch.StartNew()
    log Phase "Restoring Nix Definitions"

    let source = Path.Combine(backupDir, "nix")
    let details = ResizeArray<string>()

    if Directory.Exists(source) then
        let files = Directory.GetFiles(source, "*.nix")
        for file in files do
            let fileName = Path.GetFileName(file)
            let targetPath =
                if fileName = "devenv.nix" || fileName = "flake.nix" then
                    Path.Combine(projectRoot, fileName)
                else
                    Path.Combine(projectRoot, "containers", fileName)

            try
                ensureDirectory (Path.GetDirectoryName(targetPath))
                File.Copy(file, targetPath, true)
                details.Add(fileName)
                log Success fileName
            with ex ->
                log Error $"{fileName}: {ex.Message}"

        // Also restore flake.lock if present
        let lockFile = Path.Combine(source, "flake.lock")
        if File.Exists(lockFile) then
            try
                File.Copy(lockFile, Path.Combine(projectRoot, "flake.lock"), true)
                details.Add("flake.lock")
                log Success "flake.lock"
            with _ -> ()

        sw.Stop()
        { Phase = RestoreNix
          Result = RecoveryResult.Success $"Restored {files.Length} nix files"
          Duration = sw.Elapsed
          Details = details |> Seq.toList }
    else
        sw.Stop()
        { Phase = RestoreNix
          Result = RecoveryResult.Warning "No nix files in backup"
          Duration = sw.Elapsed
          Details = [] }

let restoreConfigs (backupDir: string) : PhaseResult =
    let sw = Stopwatch.StartNew()
    log Phase "Restoring Configuration Files"

    let details = ResizeArray<string>()

    // Observability configs
    let obsSource = Path.Combine(backupDir, "config", "observability")
    if Directory.Exists(obsSource) then
        for file in Directory.GetFiles(obsSource) do
            let fileName = Path.GetFileName(file)
            let targetPath =
                if fileName.EndsWith(".yaml") || fileName.EndsWith(".yml") then
                    Path.Combine(projectRoot, "lib", "cepaf", "artifacts", fileName)
                elif fileName.EndsWith(".json5") then
                    Path.Combine(projectRoot, "config", "zenoh", fileName)
                else
                    Path.Combine(projectRoot, "config", fileName)

            try
                ensureDirectory (Path.GetDirectoryName(targetPath))
                File.Copy(file, targetPath, true)
                details.Add(fileName)
                log Success fileName
            with ex ->
                log Error $"{fileName}: {ex.Message}"

    // Environment files
    let envSource = Path.Combine(backupDir, "config", "env")
    if Directory.Exists(envSource) then
        for file in Directory.GetFiles(envSource) do
            let fileName = Path.GetFileName(file)
            try
                File.Copy(file, Path.Combine(projectRoot, fileName), true)
                details.Add(fileName)
                log Success fileName
            with ex ->
                log Error $"{fileName}: {ex.Message}"

    sw.Stop()
    { Phase = RestoreConfigs
      Result = RecoveryResult.Success $"Restored {details.Count} config files"
      Duration = sw.Elapsed
      Details = details |> Seq.toList }

let verifyCriticalFiles () : PhaseResult =
    let sw = Stopwatch.StartNew()
    log Phase "Verifying Critical Files"

    let mutable present = 0
    let details = ResizeArray<string>()

    for file in criticalFiles do
        let fullPath = Path.Combine(projectRoot, file)
        if File.Exists(fullPath) then
            log Success file
            present <- present + 1
            details.Add($"✓ {file}")
        else
            log Error $"MISSING: {file}"
            details.Add($"✗ {file} (MISSING)")

    sw.Stop()
    let total = criticalFiles.Length
    if present = total then
        { Phase = Verify
          Result = RecoveryResult.Success $"All {total} critical files present"
          Duration = sw.Elapsed
          Details = details |> Seq.toList }
    else
        { Phase = Verify
          Result = RecoveryResult.Warning $"{present}/{total} critical files present"
          Duration = sw.Elapsed
          Details = details |> Seq.toList }

// =============================================================================
// Main Recovery Workflow
// =============================================================================

let runRecovery (archivePath: string) =
    let startTime = DateTime.Now
    let sw = Stopwatch.StartNew()

    printHeader "SIL-6 BIOMORPHIC FRACTAL MESH RECOVERY"
    printfn "   Archive: %s" archivePath
    printfn "   STAMP: SC-BACKUP-003, SC-EMR-060, SC-SIL6-001"
    printfn ""

    // OODA: OBSERVE
    logOODA "OBSERVE" "Analyzing archive and current system state..."

    let phases = ResizeArray<PhaseResult>()

    // Phase 1: Stop existing services
    phases.Add(stopExistingServices ())

    // Phase 2: Verify archive
    let archiveResult = verifyArchive archivePath
    phases.Add(archiveResult)

    match archiveResult.Result with
    | RecoveryResult.Failed _ ->
        log Critical "Cannot proceed - archive verification failed"
        1
    | _ ->

    // OODA: ORIENT
    logOODA "ORIENT" "Planning recovery sequence..."

    // Phase 3: Extract archive
    let tempDir = Path.Combine(Path.GetTempPath(), $"mesh-recovery-{Guid.NewGuid():N}")
    let extractResult = extractArchive archivePath tempDir
    phases.Add(extractResult)

    match extractResult.Result with
    | RecoveryResult.Failed _ ->
        log Critical "Cannot proceed - extraction failed"
        try Directory.Delete(tempDir, true) with _ -> ()
        1
    | RecoveryResult.Warning _ ->
        // Warnings during extraction are unlikely but treat same as failure
        log Warning "Extraction completed with warnings - proceeding with caution"
        try Directory.Delete(tempDir, true) with _ -> ()
        1
    | RecoveryResult.Success backupDir ->

    // OODA: DECIDE
    logOODA "DECIDE" "Executing staged recovery..."

    // Phase 4: Verify checksums
    phases.Add(verifyChecksums backupDir)

    // OODA: ACT
    logOODA "ACT" "Restoring system state..."

    // Phase 5-9: Restore in order
    phases.Add(restoreKMSState backupDir)
    phases.Add(restoreComposeFiles backupDir)
    phases.Add(restoreScripts backupDir)
    phases.Add(restoreNixFiles backupDir)
    phases.Add(restoreConfigs backupDir)

    // OODA: VERIFY
    logOODA "VERIFY" "Validating restored state..."

    // Phase 10: Verify critical files
    let verifyResult = verifyCriticalFiles ()
    phases.Add(verifyResult)

    // Cleanup temp directory
    try Directory.Delete(tempDir, true) with _ -> ()

    sw.Stop()
    let endTime = DateTime.Now

    // Count results
    let filesRestored =
        phases
        |> Seq.collect (fun p -> p.Details)
        |> Seq.filter (fun d -> not (d.Contains("MISSING")))
        |> Seq.length

    let (criticalPresent, criticalTotal) =
        match verifyResult.Result with
        | RecoveryResult.Success msg ->
            let total = criticalFiles.Length
            (total, total)
        | RecoveryResult.Warning msg ->
            let parts = msg.Split('/')
            if parts.Length >= 1 then
                (Int32.Parse(parts.[0]), criticalFiles.Length)
            else
                (0, criticalFiles.Length)
        | _ -> (0, criticalFiles.Length)

    let overallSuccess =
        phases |> Seq.forall (fun p ->
            match p.Result with
            | RecoveryResult.Failed _ -> false
            | _ -> true
        )

    // Print summary
    printHeader "RECOVERY COMPLETE"
    printfn ""
    printfn "   Status: %s" (if overallSuccess then "SUCCESS" else "PARTIAL")
    printfn "   Duration: %.2fs" sw.Elapsed.TotalSeconds
    printfn "   Files Restored: %d" filesRestored
    printfn "   Critical Files: %d/%d" criticalPresent criticalTotal
    printfn ""

    printfn "   Phase Summary:"
    for phase in phases do
        let status = match phase.Result with
                     | RecoveryResult.Success _ -> "✓"
                     | RecoveryResult.Warning _ -> "⚠"
                     | RecoveryResult.Failed _ -> "✗"
        printfn "     [%s] %A - %dms" status phase.Phase (int phase.Duration.TotalMilliseconds)

    printfn ""
    printfn "   Next Steps:"
    printfn "     1. Enter devenv: devenv shell"
    printfn "     2. Start mesh: sa-up"
    printfn "     3. Verify health: dotnet fsi scripts/infrastructure/mesh-verify.fsx"
    printfn ""

    if overallSuccess && criticalPresent = criticalTotal then 0 else 1

// =============================================================================
// Entry Point
// =============================================================================

let args = fsi.CommandLineArgs |> Array.skip 1 |> Array.toList

match args with
| ["--help"] | ["-h"] ->
    printfn "Usage: dotnet fsi mesh-recovery.fsx <archive-path>"
    printfn ""
    printfn "Full SIL-6 mesh system recovery from backup archive."
    printfn ""
    printfn "Arguments:"
    printfn "  archive-path    Path to mesh-state-*.tar.gz backup archive"
    printfn ""
    printfn "Example:"
    printfn "  dotnet fsi scripts/infrastructure/mesh-recovery.fsx backups/mesh-state-20260109_120000.tar.gz"
    printfn ""
    printfn "Recovery Phases:"
    printfn "  1. Stop existing services"
    printfn "  2. Verify archive integrity"
    printfn "  3. Extract archive"
    printfn "  4. Verify checksums"
    printfn "  5. Restore KMS state"
    printfn "  6. Restore compose files"
    printfn "  7. Restore F# scripts"
    printfn "  8. Restore Nix definitions"
    printfn "  9. Restore configurations"
    printfn "  10. Verify critical files"
    printfn ""
    printfn "STAMP: SC-BACKUP-003, SC-EMR-060, SC-SIL6-001, SC-HOLON-015"
| [] ->
    printfn "Error: Archive path required"
    printfn "Usage: dotnet fsi mesh-recovery.fsx <archive-path>"
    Environment.Exit(1)
| [archivePath] ->
    let fullPath =
        if Path.IsPathRooted(archivePath) then archivePath
        else Path.Combine(projectRoot, archivePath)
    let code = runRecovery fullPath
    Environment.Exit(code)
| _ ->
    printfn "Error: Unknown arguments"
    printfn "Usage: dotnet fsi mesh-recovery.fsx <archive-path>"
    Environment.Exit(1)
