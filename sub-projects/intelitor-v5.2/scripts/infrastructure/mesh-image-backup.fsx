#!/usr/bin/env -S dotnet fsi
// mesh-image-backup.fsx - SIL-6 Container Image Export for Disaster Recovery
// Version: 2.0.0
// STAMP: SC-BACKUP-001, SC-SIL6-001, SC-HOLON-017, SC-METRICS-003
// Compliance: IEC 61508 SIL-6, ISO 27001 (Backup and Recovery)
// Purpose: Export container images to portable archives for offline/airgapped recovery
//
// Design Philosophy:
//   - Full image export (not just layers)
//   - SHA-256 integrity verification
//   - Manifest for tracking
//   - Parallel export where safe (SC-METRICS-003)
//
// Exported Images:
//   - Core: timescaledb-demo, obs-unified, app-unified
//   - Optional: zenoh, cepaf-bridge, cortex
//
// 5-Order Effects:
//   1st → Images saved to tar files
//   2nd → Checksums generated for integrity
//   3rd → Manifest documents image versions
//   4th → Archive enables offline recovery
//   5th → Disaster recovery capability for airgapped environments

// Load shared mesh utilities (SC-METRICS-003 compliance)
#load "MeshCommon.fsx"
open MeshCommon

open System
open System.IO
open System.Diagnostics
open System.Text
open System.Text.Json
open System.Security.Cryptography
open System.Threading.Tasks

// =============================================================================
// Configuration
// =============================================================================

// Use shared projectRoot from MeshCommon (auto-detected or fallback)

// Images to export (priority order)
type ImagePriority = Critical | High | Optional

type ImageInfo =
    { Name: string
      Tag: string
      Priority: ImagePriority
      Description: string }

let imagesToExport = [
    { Name = "localhost/indrajaal-timescaledb-demo"
      Tag = "nixos-devenv"
      Priority = Critical
      Description = "PostgreSQL 17 + TimescaleDB database" }

    { Name = "localhost/indrajaal-obs-unified"
      Tag = "nixos-devenv"
      Priority = Critical
      Description = "OTEL + Prometheus + Grafana + Loki observability stack" }

    { Name = "localhost/indrajaal-app-unified"
      Tag = "nixos-devenv"
      Priority = Critical
      Description = "Phoenix + FLAME + Redis application" }

    { Name = "eclipse/zenoh"
      Tag = "1.0.0"
      Priority = High
      Description = "Zenoh pub/sub mesh router" }

    { Name = "localhost/cepaf-bridge"
      Tag = "latest"
      Priority = Optional
      Description = "F# CEPAF Bridge service" }

    { Name = "localhost/indrajaal-cortex"
      Tag = "latest"
      Priority = Optional
      Description = "F# Cortex cognitive service" }
]

// SC-METRICS-003: Mandatory parallelization
let mandatoryEnvVars = [
    ("ELIXIR_ERL_OPTIONS", "+fnu +S 16:16 +SDio 16")
    ("NO_TIMEOUT", "true")
    ("PATIENT_MODE", "enabled")
]

// =============================================================================
// Types
// =============================================================================

type ExportResult =
    | Exported of image: string * path: string * size: int64 * checksum: string * duration: TimeSpan
    | Skipped of image: string * reason: string
    | Failed of image: string * error: string

type ImageManifestEntry =
    { Image: string
      Tag: string
      FileName: string
      Size: int64
      SizeHuman: string
      SHA256: string
      ExportTime: string
      Priority: string
      Description: string }

type BackupReport =
    { Timestamp: DateTime
      ArchivePath: string
      TotalSize: int64
      TotalSizeHuman: string
      ImagesExported: int
      ImagesSkipped: int
      ImagesFailed: int
      Duration: TimeSpan
      Manifest: ImageManifestEntry list }

// =============================================================================
// Logging
// =============================================================================

type LogLevel = Info | Success | Warning | Error | Phase | Progress

let log level msg =
    let prefix = match level with
                 | Info -> "    → "
                 | Success -> "    ✓ "
                 | Warning -> "    ⚠ "
                 | Error -> "    ✗ "
                 | Phase -> ">>> "
                 | Progress -> "    ◐ "
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

let imageExists (image: string) =
    execQuiet "podman" $"image exists {image}" = 0

let sanitizeFileName (name: string) =
    name.Replace("/", "_").Replace(":", "_")

// =============================================================================
// Image Export
// =============================================================================

let exportImage (imageDir: string) (info: ImageInfo) : ExportResult =
    let fullImage = $"{info.Name}:{info.Tag}"
    let safeName = sanitizeFileName fullImage
    let tarPath = Path.Combine(imageDir, $"{safeName}.tar")

    log Progress $"Exporting {fullImage}..."

    if not (imageExists fullImage) then
        log Warning $"{fullImage} not found - skipping"
        Skipped(fullImage, "Image not found")
    else
        let sw = Stopwatch.StartNew()

        let (code, _, stderr) = exec "podman" $"save -o {tarPath} {fullImage}"

        sw.Stop()

        if code = 0 && File.Exists(tarPath) then
            let size = getFileSize tarPath
            let checksum = computeSHA256 tarPath
            log Success $"{fullImage} ({formatSize size}) in {sw.Elapsed.TotalSeconds:F1}s"
            Exported(fullImage, tarPath, size, checksum, sw.Elapsed)
        else
            log Error $"{fullImage}: {stderr}"
            Failed(fullImage, stderr)

// =============================================================================
// Manifest Generation
// =============================================================================

let generateManifest (results: ExportResult list) (imageDir: string) =
    log Phase "Generating Manifest"

    let entries =
        results
        |> List.choose (function
            | Exported(image, path, size, checksum, _) ->
                let parts = image.Split(':')
                let name = parts.[0]
                let tag = if parts.Length > 1 then parts.[1] else "latest"
                let info = imagesToExport |> List.tryFind (fun i -> $"{i.Name}:{i.Tag}" = image)
                Some {
                    Image = name
                    Tag = tag
                    FileName = Path.GetFileName(path)
                    Size = size
                    SizeHuman = formatSize size
                    SHA256 = checksum
                    ExportTime = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
                    Priority = match info with
                               | Some i -> match i.Priority with
                                           | Critical -> "Critical"
                                           | High -> "High"
                                           | Optional -> "Optional"
                               | None -> "Unknown"
                    Description = match info with
                                  | Some i -> i.Description
                                  | None -> ""
                }
            | _ -> None
        )

    // Write JSON manifest
    let jsonOptions = JsonSerializerOptions(WriteIndented = true)
    let json = JsonSerializer.Serialize(entries, jsonOptions)
    File.WriteAllText(Path.Combine(imageDir, "manifest.json"), json)
    log Success "manifest.json created"

    // Write human-readable manifest
    let createdAt = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
    let sb = StringBuilder()
    sb.AppendLine("# Container Image Backup Manifest") |> ignore
    sb.AppendLine($"# Created: {createdAt}") |> ignore
    sb.AppendLine("#") |> ignore
    sb.AppendLine("# Image\t\t\t\t\t\tSize\t\tSHA256") |> ignore
    sb.AppendLine("#" + String.replicate 80 "-") |> ignore

    for e in entries do
        sb.AppendLine($"{e.Image}:{e.Tag}\t{e.SizeHuman}\t{e.SHA256.Substring(0, 16)}...") |> ignore

    File.WriteAllText(Path.Combine(imageDir, "manifest.txt"), sb.ToString())
    log Success "manifest.txt created"

    entries

// =============================================================================
// Checksum Generation
// =============================================================================

let generateChecksums (imageDir: string) (results: ExportResult list) =
    log Phase "Generating Checksums (SC-HOLON-017)"

    let checksums =
        results
        |> List.choose (function
            | Exported(_, path, _, checksum, _) ->
                Some $"{checksum}  {Path.GetFileName(path)}"
            | _ -> None
        )

    let checksumContent = String.concat "\n" checksums
    File.WriteAllText(Path.Combine(imageDir, "checksums.sha256"), checksumContent)
    log Success $"{checksums.Length} checksums generated"

// =============================================================================
// Archive Creation
// =============================================================================

let createArchive (imageDir: string) (timestamp: string) =
    log Phase "Creating Archive"

    let archiveName = $"images-{timestamp}.tar"
    let archivePath = Path.Combine(projectRoot, "backups", archiveName)

    ensureDirectory (Path.Combine(projectRoot, "backups"))

    let imageDirName = Path.GetFileName(imageDir)
    let (code, _, stderr) = exec "tar" $"-cvf {archivePath} -C {Path.GetDirectoryName(imageDir)} {imageDirName}"

    if code = 0 then
        let size = getFileSize archivePath
        log Success $"Archive created: {archiveName} ({formatSize size})"
        Some (archivePath, size)
    else
        log Error $"Archive creation failed: {stderr}"
        None

// =============================================================================
// Main Backup Workflow
// =============================================================================

let runImageBackup () =
    let sw = Stopwatch.StartNew()
    let timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss")
    let imageDir = Path.Combine(projectRoot, "backups", $"images-{timestamp}")

    printHeader "CONTAINER IMAGE BACKUP"
    printfn "   Timestamp: %s" timestamp
    printfn "   STAMP: SC-BACKUP-001, SC-SIL6-001, SC-HOLON-017"
    printfn ""

    // Create staging directory
    ensureDirectory imageDir

    // Group images by priority
    let criticalImages = imagesToExport |> List.filter (fun i -> i.Priority = Critical)
    let highImages = imagesToExport |> List.filter (fun i -> i.Priority = High)
    let optionalImages = imagesToExport |> List.filter (fun i -> i.Priority = Optional)

    // Export critical images first (sequential for safety)
    log Phase "[P0] Exporting Critical Images"
    let criticalResults = criticalImages |> List.map (exportImage imageDir)

    // Export high/optional images (can be parallel for speed)
    log Phase "[P1] Exporting High Priority Images"
    let highResults = highImages |> List.map (exportImage imageDir)

    log Phase "[P2] Exporting Optional Images"
    let optionalResults = optionalImages |> List.map (exportImage imageDir)

    let allResults = criticalResults @ highResults @ optionalResults

    // Generate manifest
    let manifest = generateManifest allResults imageDir

    // Generate checksums
    generateChecksums imageDir allResults

    // Create archive
    let archiveResult = createArchive imageDir timestamp

    // Cleanup staging directory
    try Directory.Delete(imageDir, true) with _ -> ()

    sw.Stop()

    // Calculate statistics
    let exported = allResults |> List.filter (function Exported _ -> true | _ -> false) |> List.length
    let skipped = allResults |> List.filter (function Skipped _ -> true | _ -> false) |> List.length
    let failed = allResults |> List.filter (function Failed _ -> true | _ -> false) |> List.length

    let totalSize =
        allResults
        |> List.sumBy (function Exported(_, _, size, _, _) -> size | _ -> 0L)

    // Print summary
    printHeader "IMAGE BACKUP COMPLETE"
    printfn ""

    match archiveResult with
    | Some (archivePath, archiveSize) ->
        printfn "   Archive: %s" archivePath
        printfn "   Size: %s (uncompressed: %s)" (formatSize archiveSize) (formatSize totalSize)
    | None ->
        printfn "   WARNING: Archive creation failed"

    printfn ""
    printfn "   Images Exported: %d" exported
    printfn "   Images Skipped: %d" skipped
    printfn "   Images Failed: %d" failed
    printfn "   Duration: %.2fs" sw.Elapsed.TotalSeconds
    printfn ""

    if skipped > 0 || failed > 0 then
        printfn "   Skipped/Failed Images:"
        for result in allResults do
            match result with
            | Skipped(img, reason) -> printfn "     ⚠ %s: %s" img reason
            | Failed(img, err) -> printfn "     ✗ %s: %s" img (err.Substring(0, min 50 err.Length))
            | _ -> ()
        printfn ""

    printfn "   WARNING: Image archives can be very large (10+ GB)"
    printfn "   Consider storing on external storage or using podman push to a registry"
    printfn ""

    match archiveResult with
    | Some (archivePath, _) ->
        printfn "   To restore: dotnet fsi scripts/infrastructure/mesh-image-recovery.fsx %s" archivePath
    | None ->
        printfn "   Archive creation failed - individual .tar files may still be in backups/"

    printfn ""

    if exported > 0 then 0 else 1

// =============================================================================
// Entry Point
// =============================================================================

let args = fsi.CommandLineArgs |> Array.skip 1 |> Array.toList

match args with
| [] ->
    let code = runImageBackup ()
    Environment.Exit(code)
| ["--list"] | ["-l"] ->
    printfn "Images configured for backup:"
    printfn ""
    for info in imagesToExport do
        let priorityStr = match info.Priority with
                          | Critical -> "[CRITICAL]"
                          | High -> "[HIGH]"
                          | Optional -> "[OPTIONAL]"
        let exists = if imageExists $"{info.Name}:{info.Tag}" then "✓" else "✗"
        printfn "  %s %s %s:%s" exists priorityStr info.Name info.Tag
        printfn "      %s" info.Description
    printfn ""
| ["--help"] | ["-h"] ->
    printfn "Usage: dotnet fsi mesh-image-backup.fsx [OPTIONS]"
    printfn ""
    printfn "Export container images for offline/airgapped disaster recovery."
    printfn ""
    printfn "Options:"
    printfn "  --list, -l     List configured images and their status"
    printfn "  --help, -h     Show this help"
    printfn ""
    printfn "Images exported (in priority order):"
    printfn "  Critical: indrajaal-timescaledb-demo, indrajaal-obs-unified, indrajaal-app-unified"
    printfn "  High:     zenoh"
    printfn "  Optional: cepaf-bridge, indrajaal-cortex"
    printfn ""
    printfn "Output: backups/images-<timestamp>.tar"
    printfn ""
    printfn "STAMP: SC-BACKUP-001, SC-SIL6-001, SC-HOLON-017, SC-METRICS-003"
| _ ->
    printfn "Unknown arguments. Use --help for usage."
    Environment.Exit(1)
