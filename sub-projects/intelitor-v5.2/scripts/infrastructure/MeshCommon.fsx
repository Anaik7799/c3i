#!/usr/bin/env -S dotnet fsi
// MeshCommon.fsx - Shared SIL-6 Mesh Infrastructure Utilities
// Version: 2.0.0
// STAMP: SC-METRICS-003, SC-HOLON-017, SC-BACKUP-001, SC-SIL6-001
// Compliance: IEC 61508 SIL-6 (Biomorphic Extended)
// Purpose: Common utilities for mesh infrastructure scripts to reduce duplication
//
// Usage:
//   #load "MeshCommon.fsx"
//   open MeshCommon
//
// 5-Order Effects:
//   1st -> Utilities loaded into script
//   2nd -> Consistent behavior across all mesh scripts
//   3rd -> Reduced code duplication (~200 lines)
//   4th -> Easier maintenance and bug fixes
//   5th -> Improved reliability and testability

open System
open System.IO
open System.Diagnostics
open System.Text
open System.Security.Cryptography
open System.Threading

// =============================================================================
// Project Root Detection
// =============================================================================

/// Detect project root by searching for mix.exs (Elixir project marker)
let detectProjectRoot () =
    let rec findRoot dir =
        if String.IsNullOrEmpty(dir) then None
        elif File.Exists(Path.Combine(dir, "mix.exs")) then Some dir
        else
            let parent = Directory.GetParent(dir)
            if parent = null then None
            else findRoot parent.FullName

    let startDir = Environment.CurrentDirectory
    match findRoot startDir with
    | Some root -> root
    | None ->
        // Fallback to hardcoded path if detection fails
        "/home/an/dev/ver/intelitor-v5.2"

/// The detected project root (evaluated once)
let projectRoot = detectProjectRoot ()

// =============================================================================
// SC-METRICS-003: Mandatory Parallelization Environment
// =============================================================================

/// Environment variables for parallel compilation (SC-METRICS-003)
let mandatoryEnvVars = [
    ("ELIXIR_ERL_OPTIONS", "+fnu +S 16:16 +SDio 16")
    ("NO_TIMEOUT", "true")
    ("PATIENT_MODE", "enabled")
    ("MIX_OS_DEPS_COMPILE_PARTITION_COUNT", "8")
]

// =============================================================================
// Logging Infrastructure
// =============================================================================

/// Log levels for consistent output
type LogLevel =
    | Info
    | Success
    | Warning
    | Error
    | Phase
    | Progress
    | Critical
    | OODA

/// Log a message with the given level
let log level msg =
    let prefix = match level with
                 | Info -> "    -> "
                 | Success -> "    [OK] "
                 | Warning -> "    [!] "
                 | Error -> "    [X] "
                 | Phase -> ">>> "
                 | Progress -> "    [.] "
                 | Critical -> "    [!!] "
                 | OODA -> "    [OODA] "
    printfn "%s%s" prefix msg

/// Print a section header
let printHeader title =
    printfn ""
    printfn "================================================================================"
    printfn "   %s" title
    printfn "================================================================================"

/// Print a warning block
let printWarning msg =
    printfn ""
    printfn "   /!\\ WARNING /!\\"
    printfn "   %s" msg
    printfn ""

/// Log an OODA phase
let logOODA phase msg =
    printfn "    [OODA %s] %s" phase msg

// =============================================================================
// Process Execution
// =============================================================================

/// Execute a command with environment variables and timeout
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

/// Execute a command quietly and return only exit code
let execQuiet command args =
    let (code, _, _) = exec command args
    code

/// Execute a command with a timeout (in seconds)
let execWithTimeout command args timeoutSeconds =
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
    if proc.WaitForExit(timeoutSeconds * 1000) then
        let stdout = proc.StandardOutput.ReadToEnd()
        let stderr = proc.StandardError.ReadToEnd()
        (proc.ExitCode, stdout, stderr)
    else
        try proc.Kill() with _ -> ()
        (-1, "", "Timeout")

// =============================================================================
// File System Utilities
// =============================================================================

/// Ensure a directory exists
let ensureDirectory path =
    if not (Directory.Exists(path)) then
        Directory.CreateDirectory(path) |> ignore

/// Get file size safely
let getFileSize (filePath: string) =
    if File.Exists(filePath) then FileInfo(filePath).Length else 0L

/// Format file size in human-readable format
let formatSize (bytes: int64) =
    if bytes >= 1073741824L then sprintf "%.2f GB" (float bytes / 1073741824.0)
    elif bytes >= 1048576L then sprintf "%.2f MB" (float bytes / 1048576.0)
    elif bytes >= 1024L then sprintf "%.2f KB" (float bytes / 1024.0)
    else sprintf "%d B" bytes

/// Sanitize a filename (replace unsafe characters)
let sanitizeFileName (name: string) =
    name.Replace("/", "_").Replace(":", "_").Replace(" ", "_")

// =============================================================================
// SC-HOLON-017: Integrity Verification
// =============================================================================

/// Compute SHA-256 checksum of a file
let computeSHA256 (filePath: string) =
    use stream = File.OpenRead(filePath)
    use sha = SHA256.Create()
    let hash = sha.ComputeHash(stream)
    BitConverter.ToString(hash).Replace("-", "").ToLower()

/// Verify file integrity against expected checksum
let verifyChecksum filePath expectedChecksum =
    let actual = computeSHA256 filePath
    actual = expectedChecksum

// =============================================================================
// Container Utilities
// =============================================================================

/// Check if a podman image exists
let imageExists (image: string) =
    execQuiet "podman" $"image exists {image}" = 0

/// Check if a container is running
let containerRunning (name: string) =
    let (code, stdout, _) = exec "podman" $"ps --filter name={name} --format \"{{{{.Names}}}}\""
    code = 0 && stdout.Contains(name)

/// Get container status
let getContainerStatus (name: string) =
    let (code, stdout, _) = exec "podman" $"ps -a --filter name={name} --format \"{{{{.Status}}}}\""
    if code = 0 && not (String.IsNullOrWhiteSpace(stdout)) then
        stdout.Trim()
    else
        "not found"

/// Stop a container with timeout
let stopContainer name timeoutSeconds =
    let (code, _, stderr) = execWithTimeout "podman" $"stop {name}" timeoutSeconds
    code = 0

// =============================================================================
// Progress Utilities
// =============================================================================

/// Display a progress indicator while waiting
let waitWithProgress message seconds =
    printf "    %s " message
    for _ in 1 .. seconds do
        Thread.Sleep(1000)
        printf "."
    printfn " done"

/// Ask for user confirmation
let askConfirmation prompt =
    printf "%s (y/N): " prompt
    let response = Console.ReadLine()
    response.ToLower() = "y" || response.ToLower() = "yes"

// =============================================================================
// Timestamp Utilities
// =============================================================================

/// Generate a timestamp string for filenames
let generateTimestamp () =
    DateTime.Now.ToString("yyyyMMdd_HHmmss")

/// Parse a timestamp from a filename
let parseTimestamp (timestamp: string) =
    try
        Some (DateTime.ParseExact(timestamp, "yyyyMMdd_HHmmss", null))
    with
    | _ -> None

// =============================================================================
// Result Types
// =============================================================================

/// Standard result type for operations
type OperationResult =
    | Success of message: string
    | Warning of message: string
    | Failed of message: string

/// Check result for boolean success
let isSuccess = function
    | Success _ -> true
    | _ -> false

/// Check result for failure
let isFailed = function
    | Failed _ -> true
    | _ -> false

// =============================================================================
// Port Utilities
// =============================================================================

/// Check if a port is listening
let portListening port =
    let (code, stdout, _) = exec "ss" $"-tlnp sport = :{port}"
    code = 0 && stdout.Contains($":{port}")

/// Wait for a port to become available
let waitForPort port timeoutSeconds =
    let mutable elapsed = 0
    let mutable available = false
    while not available && elapsed < timeoutSeconds do
        available <- portListening port
        if not available then
            Thread.Sleep(1000)
            elapsed <- elapsed + 1
    available

// =============================================================================
// Backup Verification (Constitutional Protection)
// =============================================================================

/// Verify backup exists (Psi_0/Psi_2 protection)
let verifyBackupExists () =
    let backupDir = Path.Combine(projectRoot, "backups")
    if Directory.Exists(backupDir) then
        let backups = Directory.GetFiles(backupDir, "*.tar.gz")
        if backups.Length > 0 then
            let latestBackup = backups |> Array.sortByDescending File.GetLastWriteTime |> Array.head
            let backupAge = DateTime.Now - File.GetLastWriteTime(latestBackup)
            (true, latestBackup, backupAge)
        else
            (false, "", TimeSpan.Zero)
    else
        (false, "", TimeSpan.Zero)

// =============================================================================
// STAMP Constraint Logging
// =============================================================================

/// Log a STAMP constraint check
let logSTAMP constraint_id status details =
    let statusIcon = if status then "[OK]" else "[X]"
    printfn "    %s %s: %s" statusIcon constraint_id details

/// Verify and log a STAMP constraint
let verifySTAMP constraint_id predicate description =
    let result = predicate ()
    logSTAMP constraint_id result description
    result

// =============================================================================
// 5-Order Effects Logging
// =============================================================================

/// Log 5-order effects
let log5OrderEffects effects =
    printfn ""
    printfn "   5-Order Effects:"
    let orders = ["1st"; "2nd"; "3rd"; "4th"; "5th"]
    List.zip orders effects
    |> List.iter (fun (order, effect) ->
        printfn "     %s -> %s" order effect
    )

// =============================================================================
// Module Initialization
// =============================================================================

/// Display module info (for debugging)
let showModuleInfo () =
    printfn "MeshCommon.fsx loaded"
    printfn "  Project Root: %s" projectRoot
    printfn "  Parallelization: 16 schedulers (SC-METRICS-003)"
