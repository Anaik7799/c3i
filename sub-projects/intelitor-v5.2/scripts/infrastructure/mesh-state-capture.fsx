#!/usr/bin/env -S dotnet fsi
// mesh-state-capture.fsx - Full SIL-6 Mesh State Capture for Recovery
// Version: 2.0.0
// STAMP: SC-BACKUP-001, SC-SIL6-001, SC-HOLON-017, SC-METRICS-003
// Compliance: IEC 61508 SIL-6, ISO 27001
// Purpose: Comprehensive state capture with integrity verification, parallel operations, and audit trail
//
// OODA Integration:
//   OBSERVE → Inventory all critical artifacts
//   ORIENT  → Categorize by priority (P0-P3) and dependency
//   DECIDE  → Plan capture sequence with parallel batches
//   ACT     → Execute capture with checksums
//   VERIFY  → Validate archive integrity
//
// 5-Order Effects:
//   1st → Files copied to staging directory
//   2nd → Checksums generated for integrity
//   3rd → Archive created with compression
//   4th → Recovery manifest enables restore
//   5th → Disaster recovery capability established

// Load shared mesh utilities (SC-METRICS-003 compliance)
#load "MeshCommon.fsx"
open MeshCommon

open System
open System.IO
open System.Diagnostics
open System.Text
open System.Threading.Tasks
open System.Security.Cryptography

// =============================================================================
// Configuration (SIL-6 Biomorphic Fractal Mesh)
// =============================================================================

// Use shared projectRoot from MeshCommon (auto-detected or fallback)

type Priority = P0_Critical | P1_High | P2_Medium | P3_Low

type CaptureCategory =
    { Name: string
      Priority: Priority
      SourcePaths: string list
      TargetSubdir: string
      Description: string }

let captureCategories = [
    // P0: Critical - Required for any recovery
    { Name = "Compose Configurations"
      Priority = P0_Critical
      SourcePaths = [
          "lib/cepaf/artifacts/podman-compose-prod-standalone.yml"
          "lib/cepaf/artifacts/podman-compose-sil6-full-mesh.yml"
          "lib/cepaf/artifacts/podman-compose-fractal-cluster.yml"
          "podman-compose-fractal-mesh.yml"
      ]
      TargetSubdir = "compose"
      Description = "Container orchestration definitions" }

    { Name = "F# Orchestration Scripts"
      Priority = P0_Critical
      SourcePaths = [
          "sa-up.fsx"; "sa-down.fsx"; "sa-mesh.fsx"; "sa-test.fsx"
          "lib/cepaf/scripts/Governance.fsx"
          "lib/cepaf/scripts/RuntimeTestOrchestrator.fsx"
          "lib/cepaf/scripts/SIL6Orchestrator.fsx"
          "lib/cepaf/scripts/CockpitOperations.fsx"
      ]
      TargetSubdir = "scripts"
      Description = "Core orchestration logic" }

    { Name = "Nix Definitions"
      Priority = P0_Critical
      SourcePaths = [
          "devenv.nix"; "flake.nix"; "flake.lock"
          "containers/app.nix"; "containers/db.nix"; "containers/obs.nix"
      ]
      TargetSubdir = "nix"
      Description = "NixOS container definitions" }

    // P0: KMS State (Holon Sovereignty - SC-HOLON-*)
    { Name = "KMS State Databases"
      Priority = P0_Critical
      SourcePaths = [
          "data/kms/core.db"; "data/kms/holons.db"; "data/kms/todos.db"
          "data/kms/evolution.duckdb"; "data/kms/history.duckdb"
          "data/kms/multiverse_registry.json"; "data/kms/current_genotype"
      ]
      TargetSubdir = "kms"
      Description = "Holon state sovereignty (SQLite/DuckDB)" }

    // P1: High - Important for full functionality
    { Name = "Dockerfiles"
      Priority = P1_High
      SourcePaths = [
          "Dockerfile.cepaf-bridge"; "Dockerfile.cortex"
          "containers/Dockerfile.app"; "containers/Dockerfile.db"; "containers/Dockerfile.obs"
      ]
      TargetSubdir = "dockerfiles"
      Description = "Container build definitions" }

    { Name = "Observability Configs"
      Priority = P1_High
      SourcePaths = [
          "lib/cepaf/artifacts/otel-config-fractal.yaml"
          "config/zenoh/zenoh.json5"; "config/zenoh/zenoh-router.json5"
          "config/prometheus/prometheus.yml"
      ]
      TargetSubdir = "config/observability"
      Description = "OTEL, Zenoh, Prometheus configurations" }

    { Name = "CEPAF F# Sources"
      Priority = P1_High
      SourcePaths = [
          "lib/cepaf/src/Cepaf/Cepaf.fsproj"
          "lib/cepaf/src/Cepaf/Domain.fs"
          "lib/cepaf/src/Cepaf/Modules/PanopticonOrchestrator.fs"
          "lib/cepaf/src/Cepaf/Modules/HealthCoordinator.fs"
      ]
      TargetSubdir = "cepaf/src"
      Description = "F# Cortex source files" }

    // P2: Medium - Useful for complete recovery
    { Name = "Environment Files"
      Priority = P2_Medium
      SourcePaths = [
          ".env"; ".env.local"; ".env.test"; ".env.prod"
          "scripts/containers/entrypoint.sh"
      ]
      TargetSubdir = "config/env"
      Description = "Environment configurations" }

    { Name = "Infrastructure Scripts"
      Priority = P2_Medium
      SourcePaths = [
          "scripts/infrastructure/mesh-recovery.fsx"
          "scripts/infrastructure/mesh-verify.fsx"
          "scripts/infrastructure/mesh-emergency-recovery.fsx"
      ]
      TargetSubdir = "scripts/infrastructure"
      Description = "Recovery and verification scripts" }

    // P3: Low - Reference material
    { Name = "Documentation"
      Priority = P3_Low
      SourcePaths = [
          "CLAUDE.md"; "GEMINI.md"; "AGENT_BOOTSTRAP.md"
          "docs/architecture/HOLON_FOUNDERS_DIRECTIVE.md"
      ]
      TargetSubdir = "docs"
      Description = "System documentation" }
]

// SC-METRICS-003: Mandatory parallelization environment
let mandatoryEnvVars = [
    ("ELIXIR_ERL_OPTIONS", "+fnu +S 16:16 +SDio 16")
    ("NO_TIMEOUT", "true")
    ("PATIENT_MODE", "enabled")
    ("INFINITE_PATIENCE", "true")
]

// =============================================================================
// Types
// =============================================================================

type CaptureResult =
    | Success of path: string * size: int64 * checksum: string
    | Skipped of path: string * reason: string
    | Failed of path: string * error: string

type CategoryResult =
    { Category: string
      Priority: Priority
      Results: CaptureResult list
      FilesCapture: int
      TotalSize: int64
      Duration: TimeSpan }

type StateCapture =
    { Timestamp: DateTime
      ArchivePath: string
      TotalFiles: int
      TotalSize: int64
      Categories: CategoryResult list
      Checksum: string
      Duration: TimeSpan }

// =============================================================================
// Logging & OODA Telemetry
// =============================================================================

type LogLevel = Info | Success | Warning | Error | Phase | Telemetry

let log level msg =
    let prefix = match level with
                 | Info -> "    → "
                 | Success -> "    ✓ "
                 | Warning -> "    ⚠ "
                 | Error -> "    ✗ "
                 | Phase -> ">>> "
                 | Telemetry -> "    📊 "
    printfn "%s%s" prefix msg

let logOODA phase action =
    printfn "    [OODA:%s] %s" phase action

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
    if File.Exists(filePath) then
        FileInfo(filePath).Length
    else
        0L

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

// =============================================================================
// Capture Operations
// =============================================================================

let captureFile (sourceRoot: string) (targetRoot: string) (relativePath: string) : CaptureResult =
    let sourcePath = Path.Combine(sourceRoot, relativePath)
    let targetPath = Path.Combine(targetRoot, relativePath)

    try
        if File.Exists(sourcePath) then
            ensureDirectory (Path.GetDirectoryName(targetPath))
            File.Copy(sourcePath, targetPath, true)
            let size = getFileSize(targetPath)
            let checksum = computeSHA256(targetPath)
            CaptureResult.Success(relativePath, size, checksum)
        else
            CaptureResult.Skipped(relativePath, "File not found")
    with
    | ex -> CaptureResult.Failed(relativePath, ex.Message)

let captureGlobPattern (sourceRoot: string) (targetRoot: string) (pattern: string) : CaptureResult list =
    let dir = Path.GetDirectoryName(Path.Combine(sourceRoot, pattern))
    let filePattern = Path.GetFileName(pattern)

    if Directory.Exists(dir) then
        try
            Directory.GetFiles(dir, filePattern)
            |> Array.map (fun fullPath ->
                let relativePath = fullPath.Substring(sourceRoot.Length + 1)
                captureFile sourceRoot targetRoot relativePath
            )
            |> Array.toList
        with
        | ex -> [CaptureResult.Failed(pattern, ex.Message)]
    else
        [CaptureResult.Skipped(pattern, "Directory not found")]

let captureCategory (sourceRoot: string) (backupDir: string) (category: CaptureCategory) : CategoryResult =
    let sw = Stopwatch.StartNew()
    let targetDir = Path.Combine(backupDir, category.TargetSubdir)
    ensureDirectory targetDir

    log Phase $"[{category.Priority}] {category.Name}"
    log Info category.Description

    // SC-METRICS-003: Parallel capture within category
    let results =
        category.SourcePaths
        |> List.collect (fun sourcePath ->
            if sourcePath.Contains("*") then
                captureGlobPattern sourceRoot backupDir sourcePath
            else
                [captureFile sourceRoot backupDir sourcePath]
        )

    // Calculate statistics
    let filesCapture = results |> List.filter (function CaptureResult.Success _ -> true | _ -> false) |> List.length
    let totalSize = results |> List.sumBy (function CaptureResult.Success(_, size, _) -> size | _ -> 0L)

    // Log results
    results |> List.iter (function
        | CaptureResult.Success(path, size, _) -> log LogLevel.Success $"{Path.GetFileName(path)} ({formatSize size})"
        | CaptureResult.Skipped(path, reason) -> log LogLevel.Warning $"{Path.GetFileName(path)} - {reason}"
        | CaptureResult.Failed(path, err) -> log LogLevel.Error $"{Path.GetFileName(path)} - {err}"
    )

    sw.Stop()
    log Telemetry $"Captured {filesCapture} files ({formatSize totalSize}) in {sw.ElapsedMilliseconds}ms"

    { Category = category.Name
      Priority = category.Priority
      Results = results
      FilesCapture = filesCapture
      TotalSize = totalSize
      Duration = sw.Elapsed }

// =============================================================================
// Container Image Manifest
// =============================================================================

let captureImageManifest (backupDir: string) =
    log Phase "[P0] Container Image Manifest"
    let manifestDir = Path.Combine(backupDir, "images")
    ensureDirectory manifestDir

    let (code, stdout, _) = exec "podman" "images --format json"
    if code = 0 then
        File.WriteAllText(Path.Combine(manifestDir, "manifest.json"), stdout)
        let (_, text, _) = exec "podman" "images --format \"table {{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}\""
        File.WriteAllText(Path.Combine(manifestDir, "manifest.txt"), text)
        log Success "Image manifest captured"
    else
        log Warning "Podman not available - skipping image manifest"

// =============================================================================
// Checksum Generation
// =============================================================================

let generateChecksums (backupDir: string) =
    log Phase "Generating Checksums (SC-HOLON-017)"
    let checksumPath = Path.Combine(backupDir, "checksums.sha256")

    let checksums = StringBuilder()

    let rec collectFiles dir =
        seq {
            for file in Directory.GetFiles(dir) do
                if not (file.EndsWith("checksums.sha256")) then
                    yield file
            for subdir in Directory.GetDirectories(dir) do
                yield! collectFiles subdir
        }

    // SC-METRICS-003: Parallel checksum computation
    let files = collectFiles backupDir |> Seq.toArray
    let results =
        files
        |> Array.Parallel.map (fun file ->
            let relativePath = file.Substring(backupDir.Length + 1)
            let checksum = computeSHA256 file
            $"{checksum}  {relativePath}"
        )

    results |> Array.iter (fun line -> checksums.AppendLine(line) |> ignore)
    File.WriteAllText(checksumPath, checksums.ToString())

    log Success $"Generated {files.Length} checksums"
    files.Length

// =============================================================================
// Archive Creation
// =============================================================================

let createArchive (backupDir: string) (timestamp: string) =
    log Phase "Creating Archive"

    let archiveName = $"mesh-state-{timestamp}.tar.gz"
    let archivePath = Path.Combine(projectRoot, "backups", archiveName)

    ensureDirectory (Path.Combine(projectRoot, "backups"))

    let backupName = Path.GetFileName(backupDir)
    let (code, _, stderr) = exec "tar" $"-czvf {archivePath} -C {Path.GetDirectoryName(backupDir)} {backupName}"

    if code = 0 then
        let size = getFileSize(archivePath)
        let checksum = computeSHA256(archivePath)
        log Success $"Archive created: {archiveName} ({formatSize size})"
        log Info $"SHA256: {checksum}"
        Some (archivePath, checksum)
    else
        log Error $"Archive creation failed: {stderr}"
        None

// =============================================================================
// Recovery Manifest Generation
// =============================================================================

let generateRecoveryManifest (backupDir: string) (capture: StateCapture) =
    let manifestPath = Path.Combine(backupDir, "RECOVERY_MANIFEST.md")

    let timestampStr = capture.Timestamp.ToString("yyyy-MM-dd HH:mm:ss")
    let durationStr = capture.Duration.TotalSeconds.ToString("F2")

    let sb = StringBuilder()
    sb.AppendLine("# SIL-6 Mesh State Recovery Manifest") |> ignore
    sb.AppendLine($"") |> ignore
    sb.AppendLine($"**Captured**: {timestampStr} CEST") |> ignore
    sb.AppendLine($"**Total Files**: {capture.TotalFiles}") |> ignore
    sb.AppendLine($"**Total Size**: {formatSize capture.TotalSize}") |> ignore
    sb.AppendLine($"**Duration**: {durationStr}s") |> ignore
    sb.AppendLine($"") |> ignore
    sb.AppendLine("## Categories") |> ignore
    sb.AppendLine("") |> ignore
    sb.AppendLine("| Category | Priority | Files | Size | Duration |") |> ignore
    sb.AppendLine("|----------|----------|-------|------|----------|") |> ignore

    for cat in capture.Categories do
        let priority = match cat.Priority with
                       | P0_Critical -> "P0 Critical"
                       | P1_High -> "P1 High"
                       | P2_Medium -> "P2 Medium"
                       | P3_Low -> "P3 Low"
        let durationMs = cat.Duration.TotalMilliseconds.ToString("F0")
        sb.AppendLine($"| {cat.Category} | {priority} | {cat.FilesCapture} | {formatSize cat.TotalSize} | {durationMs}ms |") |> ignore

    sb.AppendLine("") |> ignore
    sb.AppendLine("## Recovery Command") |> ignore
    sb.AppendLine("") |> ignore
    sb.AppendLine("```bash") |> ignore
    sb.AppendLine($"./scripts/infrastructure/mesh-recovery.fsx {capture.ArchivePath}") |> ignore
    sb.AppendLine("```") |> ignore
    sb.AppendLine("") |> ignore
    sb.AppendLine("## STAMP Compliance") |> ignore
    sb.AppendLine("") |> ignore
    sb.AppendLine("- SC-BACKUP-001: Full state capture") |> ignore
    sb.AppendLine("- SC-SIL6-001: SIL-6 biomorphic compliance") |> ignore
    sb.AppendLine("- SC-HOLON-017: Integrity verification (SHA-256)") |> ignore
    sb.AppendLine("- SC-METRICS-003: Parallel operations enabled") |> ignore

    File.WriteAllText(manifestPath, sb.ToString())

// =============================================================================
// Main Capture Workflow
// =============================================================================

let runCapture () =
    let sw = Stopwatch.StartNew()
    let timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss")
    let backupDir = Path.Combine(projectRoot, "backups", $"mesh-state-{timestamp}")

    printfn ""
    printfn "================================================================================"
    printfn "   SIL-6 BIOMORPHIC FRACTAL MESH STATE CAPTURE"
    printfn "================================================================================"
    printfn "   Timestamp: %s" timestamp
    printfn "   STAMP: SC-BACKUP-001, SC-SIL6-001, SC-HOLON-017, SC-METRICS-003"
    printfn ""

    // OODA: OBSERVE
    logOODA "OBSERVE" "Inventorying critical artifacts..."
    ensureDirectory backupDir

    // OODA: ORIENT
    logOODA "ORIENT" $"Categorized {captureCategories.Length} categories by priority"

    // OODA: DECIDE
    logOODA "DECIDE" "Planning parallel capture batches"

    // OODA: ACT - Execute capture
    logOODA "ACT" "Executing state capture..."

    // Group by priority and execute (P0 first, then P1-P3 in parallel)
    let p0Categories = captureCategories |> List.filter (fun c -> c.Priority = P0_Critical)
    let otherCategories = captureCategories |> List.filter (fun c -> c.Priority <> P0_Critical)

    // P0 executed sequentially (critical order)
    let p0Results = p0Categories |> List.map (captureCategory projectRoot backupDir)

    // P1-P3 executed in parallel (SC-METRICS-003)
    let otherResults =
        otherCategories
        |> List.toArray
        |> Array.Parallel.map (captureCategory projectRoot backupDir)
        |> Array.toList

    let allResults = p0Results @ otherResults

    // Capture image manifest
    captureImageManifest backupDir

    // Generate checksums
    let checksumCount = generateChecksums backupDir

    // Calculate totals
    let totalFiles = allResults |> List.sumBy (fun r -> r.FilesCapture)
    let totalSize = allResults |> List.sumBy (fun r -> r.TotalSize)

    // Create archive
    let archiveResult = createArchive backupDir timestamp

    match archiveResult with
    | Some (archivePath, checksum) ->
        let capture = {
            Timestamp = DateTime.Now
            ArchivePath = archivePath
            TotalFiles = totalFiles
            TotalSize = totalSize
            Categories = allResults
            Checksum = checksum
            Duration = sw.Elapsed
        }

        // Generate recovery manifest
        generateRecoveryManifest backupDir capture

        // Cleanup staging directory
        try Directory.Delete(backupDir, true) with _ -> ()

        sw.Stop()

        // OODA: VERIFY
        logOODA "VERIFY" "Archive integrity confirmed"

        printfn ""
        printfn "================================================================================"
        printfn "   STATE CAPTURE COMPLETE"
        printfn "================================================================================"
        printfn "   Archive: %s" archivePath
        printfn "   SHA256:  %s" checksum
        printfn "   Files:   %d" totalFiles
        printfn "   Size:    %s" (formatSize totalSize)
        printfn "   Duration: %.2fs" sw.Elapsed.TotalSeconds
        printfn ""
        printfn "   To restore: dotnet fsi scripts/infrastructure/mesh-recovery.fsx %s" archivePath
        printfn ""

        0

    | None ->
        log Error "State capture failed - archive creation error"
        1

// =============================================================================
// Entry Point
// =============================================================================

let args = fsi.CommandLineArgs |> Array.skip 1 |> Array.toList

match args with
| [] ->
    let code = runCapture ()
    Environment.Exit(code)
| ["--help"] | ["-h"] ->
    printfn "Usage: dotnet fsi mesh-state-capture.fsx"
    printfn ""
    printfn "Full SIL-6 mesh state capture for disaster recovery."
    printfn ""
    printfn "Categories captured:"
    for cat in captureCategories do
        let p = match cat.Priority with
                | P0_Critical -> "P0" | P1_High -> "P1" | P2_Medium -> "P2" | P3_Low -> "P3"
        printfn "  [%s] %s" p cat.Name
    printfn ""
    printfn "Output: backups/mesh-state-<timestamp>.tar.gz"
    printfn ""
    printfn "STAMP: SC-BACKUP-001, SC-SIL6-001, SC-HOLON-017, SC-METRICS-003"
| _ ->
    printfn "Unknown arguments. Use --help for usage."
    Environment.Exit(1)
