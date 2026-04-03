#!/usr/bin/env -S dotnet fsi
// mesh-quick-snapshot.fsx - Minimal SIL-6 State Snapshot for Quick Recovery
// Version: 2.0.0
// STAMP: SC-BACKUP-001, SC-EMR-057, SC-SIL6-001
// Compliance: IEC 61508 SIL-6 (Fast Recovery Mode)
// Purpose: Capture P0-critical artifacts only for rapid disaster recovery
//
// Design Philosophy:
//   - Capture ONLY what's needed to restart the mesh
//   - Complete in < 30 seconds (SC-EMR-057 compliance)
//   - Small archive size for fast transfer
//   - Complementary to full mesh-state-capture.fsx
//
// Captured Artifacts (P0 Only):
//   - Core compose file (podman-compose-prod-standalone.yml)
//   - Orchestration scripts (sa-*.fsx)
//   - KMS databases (SQLite)
//   - Governance script
//
// 5-Order Effects:
//   1st → Critical files copied to staging
//   2nd → Checksums generated (integrity)
//   3rd → Compressed archive created
//   4th → Fast recovery enabled
//   5th → Minimal downtime achievable

// Load shared mesh utilities (SC-METRICS-003 compliance)
#load "MeshCommon.fsx"
open MeshCommon

open System
open System.IO
open System.Diagnostics
open System.Text
open System.Security.Cryptography

// =============================================================================
// Configuration
// =============================================================================

// Use shared projectRoot from MeshCommon (auto-detected or fallback)

// P0 Critical artifacts ONLY - minimal set for restart
let p0Artifacts = [
    // Compose file (REQUIRED for sa-up)
    ("lib/cepaf/artifacts/podman-compose-prod-standalone.yml", "compose/")

    // Core orchestration scripts
    ("sa-up.fsx", "scripts/")
    ("sa-down.fsx", "scripts/")
    ("sa-mesh.fsx", "scripts/")
    ("sa-health.fsx", "scripts/")
    ("sa-test.fsx", "scripts/")

    // Governance (required for cockpit)
    ("lib/cepaf/scripts/Governance.fsx", "scripts/cepaf/")

    // KMS state databases
    ("data/kms/core.db", "kms/")
    ("data/kms/holons.db", "kms/")
    ("data/kms/todos.db", "kms/")
]

// SC-METRICS-003: Mandatory parallelization environment
let mandatoryEnvVars = [
    ("ELIXIR_ERL_OPTIONS", "+S 16:16 +SDio 16")
    ("NO_TIMEOUT", "true")
    ("PATIENT_MODE", "enabled")
]

// =============================================================================
// Types
// =============================================================================

type CaptureResult =
    | Captured of path: string * size: int64 * checksum: string
    | Skipped of path: string * reason: string
    | Failed of path: string * error: string

type SnapshotReport =
    { Timestamp: DateTime
      ArchivePath: string
      ArchiveSize: int64
      ArchiveChecksum: string
      FilesCaptured: int
      FilesSkipped: int
      Duration: TimeSpan }

// =============================================================================
// Logging
// =============================================================================

type LogLevel = Info | Success | Warning | Phase | Metric

let log level msg =
    let prefix = match level with
                 | Info -> "    → "
                 | Success -> "    ✓ "
                 | Warning -> "    ⚠ "
                 | Phase -> ">>> "
                 | Metric -> "    📊 "
    printfn "%s%s" prefix msg

let printHeader title =
    printfn ""
    printfn "================================================================================"
    printfn "   %s" title
    printfn "================================================================================"

// =============================================================================
// Utility Functions
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
    if bytes >= 1048576L then sprintf "%.2f MB" (float bytes / 1048576.0)
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

// =============================================================================
// Capture Functions
// =============================================================================

let captureFile (sourceRoot: string) (snapDir: string) (sourcePath: string) (targetSubdir: string) : CaptureResult =
    let fullSourcePath = Path.Combine(sourceRoot, sourcePath)
    let fileName = Path.GetFileName(sourcePath)
    let targetDir = Path.Combine(snapDir, targetSubdir)
    let targetPath = Path.Combine(targetDir, fileName)

    if File.Exists(fullSourcePath) then
        try
            ensureDirectory targetDir
            File.Copy(fullSourcePath, targetPath, true)
            let size = getFileSize targetPath
            let checksum = computeSHA256 targetPath
            Captured(fileName, size, checksum)
        with
        | ex -> Failed(fileName, ex.Message) // Use Failed for actual errors
    else
        Skipped(fileName, "Not found") // Use Skipped for missing files (optional artifacts)

// =============================================================================
// Main Snapshot Workflow
// =============================================================================

let runQuickSnapshot () =
    let sw = Stopwatch.StartNew()
    let timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss")
    let snapDir = Path.Combine(projectRoot, "backups", $"quick-{timestamp}")

    printHeader "QUICK SNAPSHOT (P0 Critical Only)"
    printfn "   Timestamp: %s" timestamp
    printfn "   STAMP: SC-BACKUP-001, SC-EMR-057"
    printfn "   Target: < 30 seconds"
    printfn ""

    // Phase 1: Create staging directory
    log Phase "Capturing P0 Critical Artifacts"
    ensureDirectory snapDir

    // Phase 2: Capture files (sequential for speed - small set)
    let results =
        p0Artifacts
        |> List.map (fun (sourcePath, targetSubdir) ->
            let result = captureFile projectRoot snapDir sourcePath targetSubdir
            match result with
            | Captured(name, size, _) ->
                log Success $"{name} ({formatSize size})"
            | Skipped(name, reason) ->
                log Warning $"{name} - {reason}"
            | Failed(name, error) ->
                log Warning $"{name} - FAILED: {error}"
            result
        )

    let captured = results |> List.choose (function Captured(p, s, c) -> Some(p, s, c) | _ -> None)
    let skipped = results |> List.choose (function Skipped(p, r) -> Some(p, r) | _ -> None)
    let failed = results |> List.choose (function Failed(p, e) -> Some(p, e) | _ -> None)

    // Phase 3: Generate checksums
    log Phase "Generating Checksums"
    let checksumPath = Path.Combine(snapDir, "checksums.sha256")
    let checksumContent =
        captured
        |> List.map (fun (name, _, checksum) -> $"{checksum}  {name}")
        |> String.concat "\n"
    File.WriteAllText(checksumPath, checksumContent)
    log Success $"{captured.Length} checksums generated"

    // Phase 4: Create recovery note
    let recoveryNote = $"""# Quick Snapshot Recovery Note
# Created: {timestamp}
# Files: {captured.Length}
#
# To restore:
#   1. Extract: tar -xzf quick-{timestamp}.tar.gz
#   2. Copy compose: cp compose/*.yml lib/cepaf/artifacts/
#   3. Copy scripts: cp scripts/*.fsx ./
#   4. Copy KMS: cp kms/*.db data/kms/
#   5. Start: sa-up
#
# For full recovery, use mesh-recovery.fsx with a full state capture.
"""
    File.WriteAllText(Path.Combine(snapDir, "RECOVERY.txt"), recoveryNote)

    // Phase 5: Create archive
    log Phase "Creating Archive"
    let archiveName = $"quick-{timestamp}.tar.gz"
    let archivePath = Path.Combine(projectRoot, "backups", archiveName)

    ensureDirectory (Path.Combine(projectRoot, "backups"))

    let snapDirName = Path.GetFileName(snapDir)
    let (code, _, stderr) = exec "tar" $"-czvf {archivePath} -C {Path.GetDirectoryName(snapDir)} {snapDirName}"

    if code <> 0 then
        log Warning $"Archive creation issue: {stderr}"

    // Cleanup staging
    try Directory.Delete(snapDir, true) with _ -> ()

    sw.Stop()

    // Calculate final metrics
    let archiveSize = getFileSize archivePath
    let archiveChecksum = if File.Exists(archivePath) then computeSHA256 archivePath else "N/A"

    // Print summary
    printHeader "QUICK SNAPSHOT COMPLETE"
    printfn ""
    printfn "   Archive: %s" archivePath
    printfn "   Size: %s" (formatSize archiveSize)
    printfn "   SHA256: %s" archiveChecksum
    printfn ""
    printfn "   Files Captured: %d" captured.Length
    printfn "   Files Skipped: %d" skipped.Length
    printfn "   Files Failed: %d" failed.Length
    printfn "   Duration: %.2fs" sw.Elapsed.TotalSeconds
    printfn ""

    // Check SC-EMR-057 compliance (< 30 seconds)
    if sw.Elapsed.TotalSeconds < 30.0 then
        log Success $"SC-EMR-057 Compliant (< 30s)"
    else
        log Warning $"SC-EMR-057 Exceeded (> 30s)"

    // Report any failures
    if failed.Length > 0 then
        printfn ""
        printfn "   FAILURES:"
        for (name, error) in failed do
            printfn "     ✗ %s: %s" name error

    printfn ""
    printfn "   Note: This is a minimal P0 snapshot."
    printfn "   For complete recovery, use: dotnet fsi scripts/infrastructure/mesh-state-capture.fsx"
    printfn ""

    // Exit with error if any failures occurred (0 failures required for success)
    if captured.Length > 0 && failed.Length = 0 then 0 else 1

// =============================================================================
// Entry Point
// =============================================================================

let args = fsi.CommandLineArgs |> Array.skip 1 |> Array.toList

match args with
| [] ->
    let code = runQuickSnapshot ()
    Environment.Exit(code)
| ["--help"] | ["-h"] ->
    printfn "Usage: dotnet fsi mesh-quick-snapshot.fsx"
    printfn ""
    printfn "Minimal P0-critical snapshot for fast disaster recovery."
    printfn ""
    printfn "Captured Artifacts:"
    for (path, _) in p0Artifacts do
        printfn "  - %s" path
    printfn ""
    printfn "Performance Target: < 30 seconds (SC-EMR-057)"
    printfn ""
    printfn "Output: backups/quick-<timestamp>.tar.gz"
    printfn ""
    printfn "For full state capture, use: mesh-state-capture.fsx"
    printfn ""
    printfn "STAMP: SC-BACKUP-001, SC-EMR-057, SC-SIL6-001"
| _ ->
    printfn "Unknown arguments. Use --help for usage."
    Environment.Exit(1)
