#!/usr/bin/env -S dotnet fsi
// mesh-image-recovery.fsx - SIL-6 Container Image Recovery from Backup
// Version: 2.0.0
// STAMP: SC-BACKUP-003, SC-SIL6-001, SC-HOLON-017, SC-METRICS-003
// Compliance: IEC 61508 SIL-6, ISO 27001 (Backup and Recovery)
// Purpose: Restore container images from portable archives for disaster recovery
//
// Recovery Protocol:
//   Phase 1: VERIFY    - Validate archive integrity
//   Phase 2: EXTRACT   - Unpack archive to staging
//   Phase 3: CHECKSUM  - Verify individual image checksums
//   Phase 4: LOAD      - Import images into Podman
//   Phase 5: VALIDATE  - Confirm images are available
//
// 5-Order Effects:
//   1st → Archive extracted to staging directory
//   2nd → Checksums verified against manifest
//   3rd → Images loaded into local Podman registry
//   4th → Container deployments can reference images
//   5th → Full mesh restart capability restored

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

// SC-METRICS-003: Mandatory parallelization
let mandatoryEnvVars = [
    ("ELIXIR_ERL_OPTIONS", "+S 16:16 +SDio 16")
    ("NO_TIMEOUT", "true")
    ("PATIENT_MODE", "enabled")
]

// =============================================================================
// Types
// =============================================================================

type VerifyResult =
    | Verified of checksum: string
    | Mismatch of expected: string * actual: string
    | Missing
    | SkippedVerification

type LoadResult =
    | Loaded of image: string * duration: TimeSpan
    | LoadFailed of image: string * error: string

type RecoveryPhase =
    | VerifyArchive
    | Extract
    | VerifyChecksums
    | LoadImages
    | Validate

type PhaseResult =
    { Phase: RecoveryPhase
      Success: bool
      Message: string
      Duration: TimeSpan
      Details: string list }

type RecoveryReport =
    { ArchivePath: string
      StartTime: DateTime
      EndTime: DateTime
      Phases: PhaseResult list
      ImagesLoaded: int
      ImagesFailed: int
      OverallSuccess: bool }

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

// =============================================================================
// Phase 1: Verify Archive
// =============================================================================

let verifyArchive (archivePath: string) : PhaseResult =
    let sw = Stopwatch.StartNew()
    log Phase "[1/5] Verifying Archive Integrity"

    let details = ResizeArray<string>()

    if not (File.Exists(archivePath)) then
        sw.Stop()
        { Phase = VerifyArchive
          Success = false
          Message = $"Archive not found: {archivePath}"
          Duration = sw.Elapsed
          Details = [] }
    else
        let size = getFileSize archivePath
        let checksum = computeSHA256 archivePath
        details.Add($"Size: {formatSize size}")
        details.Add($"SHA256: {checksum}")

        log Info $"Archive: {Path.GetFileName(archivePath)}"
        log Info $"Size: {formatSize size}"
        log Info $"SHA256: {checksum}"

        // Verify archive can be read
        let (code, _, stderr) = exec "tar" $"-tf {archivePath}"
        if code = 0 then
            log Success "Archive integrity verified"
            sw.Stop()
            { Phase = VerifyArchive
              Success = true
              Message = "Archive integrity verified"
              Duration = sw.Elapsed
              Details = details |> Seq.toList }
        else
            log Error $"Archive appears corrupted: {stderr}"
            sw.Stop()
            { Phase = VerifyArchive
              Success = false
              Message = $"Archive corrupted: {stderr}"
              Duration = sw.Elapsed
              Details = details |> Seq.toList }

// =============================================================================
// Phase 2: Extract Archive
// =============================================================================

let extractArchive (archivePath: string) (tempDir: string) : PhaseResult * string option =
    let sw = Stopwatch.StartNew()
    log Phase "[2/5] Extracting Archive"

    ensureDirectory tempDir

    let (code, _, stderr) = exec "tar" $"-xf {archivePath} -C {tempDir}"

    if code = 0 then
        // Find extracted directory
        let dirs = Directory.GetDirectories(tempDir)
        if dirs.Length > 0 then
            let extractDir = dirs.[0]
            log Success $"Extracted to: {Path.GetFileName(extractDir)}"
            sw.Stop()
            ({ Phase = Extract
               Success = true
               Message = "Archive extracted"
               Duration = sw.Elapsed
               Details = [$"Directory: {extractDir}"] }, Some extractDir)
        else
            log Error "No content found in archive"
            sw.Stop()
            ({ Phase = Extract
               Success = false
               Message = "No content in archive"
               Duration = sw.Elapsed
               Details = [] }, None)
    else
        log Error $"Extraction failed: {stderr}"
        sw.Stop()
        ({ Phase = Extract
           Success = false
           Message = $"Extraction failed: {stderr}"
           Duration = sw.Elapsed
           Details = [] }, None)

// =============================================================================
// Phase 3: Verify Checksums
// =============================================================================

let verifyChecksums (extractDir: string) : PhaseResult * Map<string, string> =
    let sw = Stopwatch.StartNew()
    log Phase "[3/5] Verifying Checksums (SC-HOLON-017)"

    let checksumFile = Path.Combine(extractDir, "checksums.sha256")
    let details = ResizeArray<string>()
    let verifiedFiles = ResizeArray<string * string>()

    if not (File.Exists(checksumFile)) then
        log Warning "No checksum file found - skipping verification"
        sw.Stop()
        ({ Phase = VerifyChecksums
           Success = true
           Message = "No checksums (skipped)"
           Duration = sw.Elapsed
           Details = ["Checksum file not found"] }, Map.empty)
    else
        let lines = File.ReadAllLines(checksumFile)
        let mutable passed = 0
        let mutable failed = 0

        // Parse checksums and verify (SC-METRICS-003: parallel)
        let results =
            lines
            |> Array.Parallel.map (fun line ->
                let parts = line.Split([|"  "|], StringSplitOptions.None)
                if parts.Length = 2 then
                    let expectedHash = parts.[0]
                    let fileName = parts.[1]
                    let filePath = Path.Combine(extractDir, fileName)

                    if File.Exists(filePath) then
                        let actualHash = computeSHA256 filePath
                        if actualHash = expectedHash then
                            (true, fileName, expectedHash)
                        else
                            (false, $"MISMATCH: {fileName}", "")
                    else
                        (false, $"MISSING: {fileName}", "")
                else
                    (true, "", "")
            )

        for (success, name, hash) in results do
            if success && name <> "" then
                passed <- passed + 1
                verifiedFiles.Add((name, hash))
            elif not success then
                failed <- failed + 1
                details.Add(name)
                log Warning name

        log Info $"Verified: {passed} files"
        if failed > 0 then
            log Warning $"Failed: {failed} files"

        sw.Stop()

        let checksumMap = verifiedFiles |> Seq.map (fun (n, h) -> (n, h)) |> Map.ofSeq

        if failed = 0 then
            ({ Phase = VerifyChecksums
               Success = true
               Message = $"{passed} files verified"
               Duration = sw.Elapsed
               Details = details |> Seq.toList }, checksumMap)
        else
            ({ Phase = VerifyChecksums
               Success = false
               Message = $"{failed} verification failures"
               Duration = sw.Elapsed
               Details = details |> Seq.toList }, checksumMap)

// =============================================================================
// Phase 4: Load Images
// =============================================================================

let loadImages (extractDir: string) : PhaseResult * int * int =
    let sw = Stopwatch.StartNew()
    log Phase "[4/5] Loading Images"

    let details = ResizeArray<string>()
    let mutable loaded = 0
    let mutable failed = 0

    // Find all .tar files in the extracted directory
    let tarFiles = Directory.GetFiles(extractDir, "*.tar")

    if tarFiles.Length = 0 then
        log Warning "No .tar files found in archive"
        sw.Stop()
        ({ Phase = LoadImages
           Success = false
           Message = "No image files found"
           Duration = sw.Elapsed
           Details = [] }, 0, 0)
    else
        for tarFile in tarFiles do
            let fileName = Path.GetFileName(tarFile)
            let fileSize = getFileSize tarFile

            log Progress $"Loading {fileName} ({formatSize fileSize})..."

            let loadSw = Stopwatch.StartNew()
            let (code, stdout, stderr) = exec "podman" $"load -i {tarFile}"
            loadSw.Stop()

            if code = 0 then
                // Parse loaded image name from output
                let loadedImage =
                    stdout.Split([|'\n'|], StringSplitOptions.RemoveEmptyEntries)
                    |> Array.tryFind (fun line -> line.Contains("Loaded image"))
                    |> Option.map (fun line ->
                        let parts = line.Split([|':'|], 2)
                        if parts.Length > 1 then parts.[1].Trim() else fileName
                    )
                    |> Option.defaultValue fileName

                log Success $"{loadedImage} ({loadSw.Elapsed.TotalSeconds:F1}s)"
                details.Add($"✓ {loadedImage}")
                loaded <- loaded + 1
            else
                log Error $"{fileName}: {stderr}"
                details.Add($"✗ {fileName}: {stderr.Substring(0, min 50 stderr.Length)}")
                failed <- failed + 1

        sw.Stop()

        let success = loaded > 0 && failed = 0
        ({ Phase = LoadImages
           Success = success
           Message = $"Loaded {loaded}/{tarFiles.Length} images"
           Duration = sw.Elapsed
           Details = details |> Seq.toList }, loaded, failed)

// =============================================================================
// Phase 5: Validate
// =============================================================================

let validateImages () : PhaseResult =
    let sw = Stopwatch.StartNew()
    log Phase "[5/5] Validating Loaded Images"

    let details = ResizeArray<string>()

    // Get list of images
    let (code, stdout, _) = exec "podman" "images --format \"table {{.Repository}}:{{.Tag}}\t{{.Size}}\""

    if code = 0 then
        let lines = stdout.Split([|'\n'|], StringSplitOptions.RemoveEmptyEntries)
        log Info $"Total images in registry: {lines.Length - 1}" // -1 for header

        // Show indrajaal images specifically
        let indrajaalImages =
            lines
            |> Array.filter (fun line ->
                line.Contains("indrajaal") || line.Contains("zenoh") || line.Contains("cepaf")
            )

        log Info "Mesh-related images:"
        for img in indrajaalImages do
            log Success img
            details.Add(img)

        sw.Stop()
        { Phase = Validate
          Success = true
          Message = $"{indrajaalImages.Length} mesh images available"
          Duration = sw.Elapsed
          Details = details |> Seq.toList }
    else
        log Warning "Could not list images"
        sw.Stop()
        { Phase = Validate
          Success = false
          Message = "Could not verify images"
          Duration = sw.Elapsed
          Details = [] }

// =============================================================================
// Main Recovery Workflow
// =============================================================================

let runImageRecovery (archivePath: string) =
    let startTime = DateTime.Now
    let sw = Stopwatch.StartNew()

    printHeader "CONTAINER IMAGE RECOVERY"
    printfn "   Archive: %s" archivePath
    printfn "   STAMP: SC-BACKUP-003, SC-SIL6-001, SC-HOLON-017"
    printfn ""

    let phases = ResizeArray<PhaseResult>()

    // Phase 1: Verify archive
    let verifyResult = verifyArchive archivePath
    phases.Add(verifyResult)

    if not verifyResult.Success then
        log Error "Cannot proceed - archive verification failed"
        1
    else

    // Phase 2: Extract
    let tempDir = Path.Combine(Path.GetTempPath(), $"mesh-image-recovery-{Guid.NewGuid():N}")
    let (extractResult, extractDirOpt) = extractArchive archivePath tempDir
    phases.Add(extractResult)

    match extractDirOpt with
    | None ->
        log Error "Cannot proceed - extraction failed"
        try Directory.Delete(tempDir, true) with _ -> ()
        1
    | Some extractDir ->

    // Phase 3: Verify checksums
    let (checksumResult, _) = verifyChecksums extractDir
    phases.Add(checksumResult)

    // Phase 4: Load images
    let (loadResult, loaded, failed) = loadImages extractDir
    phases.Add(loadResult)

    // Phase 5: Validate
    let validateResult = validateImages ()
    phases.Add(validateResult)

    // Cleanup
    try Directory.Delete(tempDir, true) with _ -> ()

    sw.Stop()
    let endTime = DateTime.Now

    // Calculate overall success
    let overallSuccess =
        phases |> Seq.forall (fun p -> p.Success) && loaded > 0

    // Print summary
    printHeader "IMAGE RECOVERY COMPLETE"
    printfn ""
    printfn "   Phase Summary:"
    for phase in phases do
        let statusIcon = if phase.Success then "✓" else "✗"
        printfn "     [%s] %A: %s (%dms)" statusIcon phase.Phase phase.Message (int phase.Duration.TotalMilliseconds)

    printfn ""
    printfn "   Images Loaded: %d" loaded
    printfn "   Images Failed: %d" failed
    printfn "   Duration: %.2fs" sw.Elapsed.TotalSeconds
    printfn "   Status: %s" (if overallSuccess then "SUCCESS" else "PARTIAL")
    printfn ""
    printfn "   Next Steps:"
    printfn "     1. Verify images: podman images"
    printfn "     2. Start mesh: sa-up"
    printfn "     3. Check health: dotnet fsi scripts/infrastructure/mesh-verify.fsx"
    printfn ""

    if overallSuccess then 0 else 1

// =============================================================================
// Entry Point
// =============================================================================

let args = fsi.CommandLineArgs |> Array.skip 1 |> Array.toList

match args with
| ["--help"] | ["-h"] ->
    printfn "Usage: dotnet fsi mesh-image-recovery.fsx <archive-path>"
    printfn ""
    printfn "Restore container images from backup archive."
    printfn ""
    printfn "Arguments:"
    printfn "  archive-path    Path to images-*.tar backup archive"
    printfn ""
    printfn "Example:"
    printfn "  dotnet fsi scripts/infrastructure/mesh-image-recovery.fsx backups/images-20260109_120000.tar"
    printfn ""
    printfn "Recovery Phases:"
    printfn "  1. Verify archive integrity"
    printfn "  2. Extract archive contents"
    printfn "  3. Verify image checksums"
    printfn "  4. Load images into Podman"
    printfn "  5. Validate loaded images"
    printfn ""
    printfn "STAMP: SC-BACKUP-003, SC-SIL6-001, SC-HOLON-017, SC-METRICS-003"
| [] ->
    printfn "Error: Archive path required"
    printfn "Usage: dotnet fsi mesh-image-recovery.fsx <archive-path>"
    Environment.Exit(1)
| [archivePath] ->
    let fullPath =
        if Path.IsPathRooted(archivePath) then archivePath
        else Path.Combine(projectRoot, archivePath)
    let code = runImageRecovery fullPath
    Environment.Exit(code)
| _ ->
    printfn "Error: Unknown arguments"
    printfn "Usage: dotnet fsi mesh-image-recovery.fsx <archive-path>"
    Environment.Exit(1)
