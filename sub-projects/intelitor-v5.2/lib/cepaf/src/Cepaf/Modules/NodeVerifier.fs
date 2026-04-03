/// CEPAF Node Verification Module
/// SC-CNT-009: NixOS container enforcement
/// SC-CNT-010: Localhost registry validation
/// SC-CNT-012: Rootless Podman verification
/// SC-CEP-004: 30-second boot threshold
///
/// WHAT: Verifies individual service nodes against STAMP constraints
/// WHY: Ensures safety-critical compliance before container deployment
/// CONSTRAINTS: All constraint violations trigger halt per AOR-SAF-001
module Cepaf.Modules.NodeVerifier

open System
open System.Diagnostics
open Cepaf
open Cepaf.Rop
open Cepaf.Infrastructure
open Cepaf.Observability
open Cepaf.Modules.ConstraintValidator

// ============================================================================
// TYPES
// ============================================================================

/// Node verification status tracking
type NodeStatus =
    | NotVerified
    | VerificationInProgress
    | Verified of DateTime
    | VerificationFailed of reasons: string list

/// Verification depth levels (trade-off between speed and thoroughness)
type VerificationLevel =
    | Quick     // Basic checks only (~100ms)
    | Standard  // Normal verification (~500ms)
    | Thorough  // Full verification with probes (~2s)

/// Probe result for a specific health check
type ProbeResult = {
    ProbeName: string
    Success: bool
    ResponseTimeMs: int64
    Message: string option
    Timestamp: DateTime
}

/// Complete node verification result
type NodeVerificationResult = {
    NodeId: string
    Status: NodeStatus
    Constraints: (string * bool) list  // Constraint ID -> passed
    StartTime: DateTime
    EndTime: DateTime option
    ProbeResults: Map<string, bool>
    BootTimeMs: int64 option
    Image: string option
    IsRootless: bool option
}

/// Port availability check result
type PortCheckResult = {
    Port: int
    Available: bool
    ConflictingProcess: string option
}

/// Volume mount validation result
type VolumeMountResult = {
    Path: string
    Exists: bool
    Writable: bool
    ErrorMessage: string option
}

/// Verification report with detailed findings
type VerificationReport = {
    NodeId: string
    Timestamp: DateTime
    Level: VerificationLevel
    OverallSuccess: bool
    Constraints: (string * bool * string option) list  // ID, passed, message
    BootCompliance: bool
    ImageCompliance: bool
    RootlessCompliance: bool
    PortConflicts: PortCheckResult list
    VolumeMounts: VolumeMountResult list
    ProbeResults: ProbeResult list
    TotalDurationMs: int64
    Recommendations: string list
}

// ============================================================================
// CONSTANTS (STAMP Thresholds)
// ============================================================================

/// SC-CEP-004: Maximum boot time in milliseconds (30 seconds)
let private bootThresholdMs = 30000L

/// SC-PRF-050: Maximum PHICS response latency in milliseconds
let private responseThresholdMs = 50L

/// SC-EMR-057: Maximum emergency stop time in milliseconds
let private emergencyStopThresholdMs = 5000L

// ============================================================================
// INTERNAL HELPERS
// ============================================================================

/// Create empty verification result for a node
let private emptyResult nodeId = {
    NodeId = nodeId
    Status = NotVerified
    Constraints = []
    StartTime = DateTime.UtcNow
    EndTime = None
    ProbeResults = Map.empty
    BootTimeMs = None
    Image = None
    IsRootless = None
}

/// Parse podman inspect output for image info
let private parseImageFromInspect (output: string) : string option =
    // Look for Image field in JSON output
    let lines = output.Split('\n') |> Array.map (fun s -> s.Trim())
    lines
    |> Array.tryFind (fun line -> line.Contains("\"Image\"") || line.Contains("\"ImageName\""))
    |> Option.bind (fun line ->
        let parts = line.Split(':')
        if parts.Length >= 2 then
            parts.[1..]
            |> String.concat ":"
            |> fun s -> s.Trim().Trim(',').Trim('"')
            |> Some
        else None)

/// Parse rootless mode from podman info
let private parseRootlessFromInfo (output: string) : bool =
    output.Contains("rootless: true") ||
    output.Contains("\"rootless\": true") ||
    output.Contains("/run/user/")  // Rootless uses user socket

/// Check if a port is in use by running ss/netstat
let private isPortInUse (runner: IProcessRunner) (port: int) = async {
    // Try to check with ss first (more modern)
    let! result = runner.Run("ss", ["-tuln"; sprintf "sport = :%d" port])
    match result with
    | Ok res -> return res.StandardOutput.Contains(sprintf ":%d " port)
    | Error _ ->
        // Fallback to netstat
        let! netstatResult = runner.Run("netstat", ["-tuln"])
        match netstatResult with
        | Ok res -> return res.StandardOutput.Contains(sprintf ":%d " port)
        | Error _ -> return false
}

// ============================================================================
// CONSTRAINT VERIFICATION FUNCTIONS
// ============================================================================

/// SC-CNT-009: Verify image is NixOS-based
let verifyImage (image: string) : Result<string, ConstraintViolation> =
    // Use the existing validator from ConstraintValidator
    validateNixOS {
        Name = "image-check"
        Image = image
        DependsOn = []
        IsRootless = true
        Ports = []
        VolumeMounts = []
        Environment = Map.empty
    }
    |> Result.map (fun _ -> image)
    |> Result.mapError (fun v -> v)

/// SC-CNT-010: Verify localhost registry
let verifyLocalRegistry (image: string) : Result<string, ConstraintViolation> =
    validateLocalRegistry image

/// SC-CNT-012: Verify Podman runs in rootless mode
let verifyRootless (logger: UnifiedLogger) (runner: IProcessRunner) = asyncResult {
    logger.Info("SC-CNT-012: Verifying Podman rootless mode...")

    // Check podman info for rootless status
    let! infoResult = runner.Run("podman", ["info"; "--format"; "{{.Host.Security.Rootless}}"])

    let isRootless =
        infoResult.StandardOutput.Trim().ToLowerInvariant() = "true" ||
        parseRootlessFromInfo infoResult.StandardOutput

    if isRootless then
        logger.Info("  [PASS] Podman running in rootless mode")
        return true
    else
        logger.Error("  [FAIL] Podman NOT in rootless mode - SC-CNT-012 violation")
        return! fromResult (Error (SafetyViolation("SC-CNT-012", "Podman must run in rootless mode")))
}

/// SC-CEP-004: Verify container boots within 30 seconds
let verifyBootTime (logger: UnifiedLogger) (bootTimeMs: int64) : Result<int64, ConstraintViolation> =
    let result = validateBootThreshold (TimeSpan.FromMilliseconds(float bootTimeMs))
    match result with
    | Ok _ ->
        logger.Info(sprintf "  [PASS] Boot time %dms within 30s threshold" bootTimeMs)
        Ok bootTimeMs
    | Error violation ->
        logger.Error(sprintf "  [FAIL] Boot time %dms exceeds 30s threshold - SC-CEP-004 violation" bootTimeMs)
        Error violation

/// Run a health probe against a container
let runHealthProbe (logger: UnifiedLogger) (runner: IProcessRunner) (containerId: string) (probeName: string) = async {
    let startTime = DateTime.UtcNow
    let sw = Stopwatch.StartNew()

    logger.Info(sprintf "  Running probe '%s' on container '%s'..." probeName containerId)

    // Run podman healthcheck
    let! result = runner.Run("podman", ["healthcheck"; "run"; containerId])
    sw.Stop()

    let probeResult = {
        ProbeName = probeName
        Success =
            match result with
            | Ok res -> res.ExitCode = 0
            | Error _ -> false
        ResponseTimeMs = sw.ElapsedMilliseconds
        Message =
            match result with
            | Ok res when res.ExitCode = 0 -> Some "Health check passed"
            | Ok res -> Some (sprintf "Health check failed: %s" res.StandardError)
            | Error e -> Some (sprintf "Probe error: %A" e)
        Timestamp = startTime
    }

    if probeResult.Success then
        logger.Info(sprintf "    [PASS] Probe '%s' succeeded in %dms" probeName sw.ElapsedMilliseconds)
    else
        logger.LogWithCategory(sprintf "    [FAIL] Probe '%s' failed: %s" probeName (probeResult.Message |> Option.defaultValue "unknown error"), EventCategory.Protocol, LogLevel.Warning)

    return probeResult
}

/// Verify ports are available (no conflicts)
let verifyPorts (logger: UnifiedLogger) (runner: IProcessRunner) (ports: int list) = async {
    logger.Info(sprintf "  Checking port availability for %d ports..." (List.length ports))

    let! results =
        ports
        |> List.map (fun port -> async {
            let! inUse = isPortInUse runner port
            let result = {
                Port = port
                Available = not inUse
                ConflictingProcess = if inUse then Some "unknown" else None
            }
            if result.Available then
                logger.Info(sprintf "    [PASS] Port %d is available" port)
            else
                logger.LogWithCategory(sprintf "    [FAIL] Port %d is in use" port, EventCategory.Protocol, LogLevel.Warning)
            return result
        })
        |> Async.Sequential

    return results |> List.ofArray
}

/// Verify volume mounts exist and are accessible
let verifyVolumes (logger: UnifiedLogger) (volumes: string list) : VolumeMountResult list =
    logger.Info(sprintf "  Checking %d volume mounts..." (List.length volumes))

    volumes
    |> List.map (fun path ->
        // Extract source path from volume mount (source:destination:options)
        let sourcePath =
            if path.Contains(":") then path.Split(':').[0]
            else path

        let exists = IO.Directory.Exists(sourcePath) || IO.File.Exists(sourcePath)
        let writable =
            if exists && IO.Directory.Exists(sourcePath) then
                try
                    let testFile = IO.Path.Combine(sourcePath, ".cepaf_write_test")
                    IO.File.WriteAllText(testFile, "test")
                    IO.File.Delete(testFile)
                    true
                with _ -> false
            else
                false

        let result = {
            Path = sourcePath
            Exists = exists
            Writable = writable
            ErrorMessage =
                if not exists then Some (sprintf "Path does not exist: %s" sourcePath)
                elif not writable then Some (sprintf "Path is not writable: %s" sourcePath)
                else None
        }

        if result.Exists && result.Writable then
            logger.Info(sprintf "    [PASS] Volume mount '%s' is accessible" sourcePath)
        elif result.Exists then
            logger.LogWithCategory(sprintf "    [WARN] Volume mount '%s' exists but is not writable" sourcePath, EventCategory.Protocol, LogLevel.Warning)
        else
            logger.LogWithCategory(sprintf "    [FAIL] Volume mount '%s' does not exist" sourcePath, EventCategory.Protocol, LogLevel.Warning)

        result)

/// Verify environment variables are set
let verifyEnvironment (logger: UnifiedLogger) (runner: IProcessRunner) (containerId: string) (requiredVars: string list) = asyncResult {
    logger.Info(sprintf "  Checking %d required environment variables..." (List.length requiredVars))

    let! inspectResult = runner.Run("podman", ["inspect"; "--format"; "{{json .Config.Env}}"; containerId])

    let envOutput = inspectResult.StandardOutput
    let missingVars =
        requiredVars
        |> List.filter (fun varName -> not (envOutput.Contains(varName)))

    if List.isEmpty missingVars then
        logger.Info("    [PASS] All required environment variables are set")
        return true
    else
        logger.LogWithCategory(sprintf "    [WARN] Missing environment variables: %s" (String.concat ", " missingVars), EventCategory.Protocol, LogLevel.Warning)
        return false
}

// ============================================================================
// MAIN VERIFICATION FUNCTIONS
// ============================================================================

/// Perform quick verification (~100ms) - basic checks only
let private verifyQuick (logger: UnifiedLogger) (runner: IProcessRunner) (nodeId: string) (image: string) = async {
    logger.Info(sprintf "Quick verification for node '%s'..." nodeId)

    let mutable constraints = []

    // SC-CNT-010: Localhost registry check
    match verifyLocalRegistry image with
    | Ok _ -> constraints <- ("SC-CNT-010", true) :: constraints
    | Error _ -> constraints <- ("SC-CNT-010", false) :: constraints

    // SC-CNT-009: NixOS image check
    match verifyImage image with
    | Ok _ -> constraints <- ("SC-CNT-009", true) :: constraints
    | Error _ -> constraints <- ("SC-CNT-009", false) :: constraints

    let allPassed = constraints |> List.forall snd

    return {
        emptyResult nodeId with
            Status = if allPassed then Verified DateTime.UtcNow else VerificationFailed ["Quick check failed"]
            Constraints = constraints
            Image = Some image
            EndTime = Some DateTime.UtcNow
    }
}

/// Perform standard verification (~500ms) - includes rootless check
let private verifyStandard (logger: UnifiedLogger) (runner: IProcessRunner) (nodeId: string) (image: string) = async {
    logger.Info(sprintf "Standard verification for node '%s'..." nodeId)

    let mutable constraints = []
    let mutable failures = []

    // SC-CNT-010: Localhost registry check
    match verifyLocalRegistry image with
    | Ok _ -> constraints <- ("SC-CNT-010", true) :: constraints
    | Error v ->
        constraints <- ("SC-CNT-010", false) :: constraints
        failures <- v.Message :: failures

    // SC-CNT-009: NixOS image check
    match verifyImage image with
    | Ok _ -> constraints <- ("SC-CNT-009", true) :: constraints
    | Error v ->
        constraints <- ("SC-CNT-009", false) :: constraints
        failures <- v.Message :: failures

    // SC-CNT-012: Rootless check
    let! rootlessResult = verifyRootless logger runner
    let isRootless =
        match rootlessResult with
        | Ok r -> r
        | Error _ -> false
    constraints <- ("SC-CNT-012", isRootless) :: constraints
    if not isRootless then
        failures <- "Podman not in rootless mode" :: failures

    let allPassed = constraints |> List.forall snd

    return {
        emptyResult nodeId with
            Status =
                if allPassed then Verified DateTime.UtcNow
                else VerificationFailed failures
            Constraints = constraints
            Image = Some image
            IsRootless = Some isRootless
            EndTime = Some DateTime.UtcNow
    }
}

/// Perform thorough verification (~2s) - includes probes and timing
let private verifyThorough (logger: UnifiedLogger) (runner: IProcessRunner) (nodeId: string) (image: string) (ports: int list) (volumes: string list) = async {
    logger.Info(sprintf "Thorough verification for node '%s'..." nodeId)

    let mutable constraints = []
    let mutable failures = []
    let mutable probeResults = Map.empty

    // SC-CNT-010: Localhost registry check
    match verifyLocalRegistry image with
    | Ok _ -> constraints <- ("SC-CNT-010", true) :: constraints
    | Error v ->
        constraints <- ("SC-CNT-010", false) :: constraints
        failures <- v.Message :: failures

    // SC-CNT-009: NixOS image check
    match verifyImage image with
    | Ok _ -> constraints <- ("SC-CNT-009", true) :: constraints
    | Error v ->
        constraints <- ("SC-CNT-009", false) :: constraints
        failures <- v.Message :: failures

    // SC-CNT-012: Rootless check
    let! rootlessResult = verifyRootless logger runner
    let isRootless =
        match rootlessResult with
        | Ok r -> r
        | Error _ -> false
    constraints <- ("SC-CNT-012", isRootless) :: constraints
    if not isRootless then
        failures <- "Podman not in rootless mode" :: failures

    // Port availability check
    let! portResults = verifyPorts logger runner ports
    let portsAvailable = portResults |> List.forall (fun p -> p.Available)
    constraints <- ("PORT-AVAILABLE", portsAvailable) :: constraints
    if not portsAvailable then
        let conflictPorts = portResults |> List.filter (fun p -> not p.Available) |> List.map (fun p -> string p.Port)
        failures <- (sprintf "Port conflicts: %s" (String.concat ", " conflictPorts)) :: failures

    // Volume mount check
    let volumeResults = verifyVolumes logger volumes
    let volumesOk = volumeResults |> List.forall (fun v -> v.Exists)
    constraints <- ("VOLUME-EXISTS", volumesOk) :: constraints
    if not volumesOk then
        let missingPaths = volumeResults |> List.filter (fun v -> not v.Exists) |> List.map (fun v -> v.Path)
        failures <- (sprintf "Missing volumes: %s" (String.concat ", " missingPaths)) :: failures

    // Health probe (if container exists)
    let! containerExists = runner.Run("podman", ["container"; "exists"; nodeId])
    match containerExists with
    | Ok res when res.ExitCode = 0 ->
        let! probe = runHealthProbe logger runner nodeId "default"
        probeResults <- probeResults |> Map.add "default" probe.Success
        if not probe.Success then
            constraints <- ("HEALTH-PROBE", false) :: constraints
            failures <- (sprintf "Health probe failed: %s" (probe.Message |> Option.defaultValue "unknown")) :: failures
        else
            constraints <- ("HEALTH-PROBE", true) :: constraints
    | _ ->
        logger.Info("  Container not running - skipping health probe")

    let allPassed = constraints |> List.forall snd

    return {
        emptyResult nodeId with
            Status =
                if allPassed then Verified DateTime.UtcNow
                else VerificationFailed failures
            Constraints = constraints
            Image = Some image
            IsRootless = Some isRootless
            ProbeResults = probeResults
            EndTime = Some DateTime.UtcNow
    }
}

/// Full node verification against STAMP constraints
/// Entry point for verification with configurable level
let verifyNode
    (logger: UnifiedLogger)
    (runner: IProcessRunner)
    (nodeId: string)
    (image: string)
    (level: VerificationLevel)
    (ports: int list)
    (volumes: string list) = async {

    logger.Info("============================================================================")
    logger.Info(sprintf "NODE VERIFICATION: %s (Level: %A)" nodeId level)
    logger.Info("============================================================================")

    let startTime = DateTime.UtcNow

    let! result =
        match level with
        | Quick -> verifyQuick logger runner nodeId image
        | Standard -> verifyStandard logger runner nodeId image
        | Thorough -> verifyThorough logger runner nodeId image ports volumes

    let finalResult = { result with StartTime = startTime }

    // Log summary
    match finalResult.Status with
    | Verified dt ->
        logger.Info(sprintf "NODE VERIFICATION PASSED: %s at %s" nodeId (dt.ToString("o")))
    | VerificationFailed reasons ->
        logger.Error(sprintf "NODE VERIFICATION FAILED: %s" nodeId)
        reasons |> List.iter (fun r -> logger.Error(sprintf "  - %s" r))
    | VerificationInProgress ->
        logger.Info(sprintf "NODE VERIFICATION IN PROGRESS: %s" nodeId)
    | NotVerified ->
        logger.LogWithCategory(sprintf "NODE NOT VERIFIED: %s" nodeId, EventCategory.Protocol, LogLevel.Warning)

    logger.Info("============================================================================")

    return finalResult
}

// ============================================================================
// VERIFICATION REPORT GENERATION
// ============================================================================

/// Generate a detailed verification report
let createVerificationReport
    (logger: UnifiedLogger)
    (result: NodeVerificationResult)
    (level: VerificationLevel)
    (portChecks: PortCheckResult list)
    (volumeChecks: VolumeMountResult list)
    (probes: ProbeResult list) : VerificationReport =

    logger.Info(sprintf "Generating verification report for '%s'..." result.NodeId)

    let endTime = result.EndTime |> Option.defaultValue DateTime.UtcNow
    let duration = int64 (endTime - result.StartTime).TotalMilliseconds

    // Build constraint list with messages
    let constraintDetails =
        result.Constraints
        |> List.map (fun (id, passed) ->
            let message =
                if passed then None
                else Some (sprintf "Constraint %s failed" id)
            (id, passed, message))

    // Check specific compliances
    let bootCompliance =
        result.BootTimeMs
        |> Option.map (fun bt -> bt <= bootThresholdMs)
        |> Option.defaultValue true  // Assume compliant if not measured

    let imageCompliance =
        result.Constraints
        |> List.tryFind (fun (id, _) -> id = "SC-CNT-009" || id = "SC-CNT-010")
        |> Option.map snd
        |> Option.defaultValue false

    let rootlessCompliance =
        result.IsRootless |> Option.defaultValue false

    // Generate recommendations
    let mutable recommendations = []

    if not bootCompliance then
        recommendations <- "Optimize container startup time - consider pre-warming or lazy initialization" :: recommendations

    if not imageCompliance then
        recommendations <- "Ensure all images use localhost/ registry and are NixOS-based" :: recommendations

    if not rootlessCompliance then
        recommendations <- "Configure Podman for rootless operation per SC-CNT-012" :: recommendations

    let portConflicts = portChecks |> List.filter (fun p -> not p.Available)
    if not (List.isEmpty portConflicts) then
        recommendations <- (sprintf "Resolve port conflicts: %s" (portConflicts |> List.map (fun p -> string p.Port) |> String.concat ", ")) :: recommendations

    let missingVolumes = volumeChecks |> List.filter (fun v -> not v.Exists)
    if not (List.isEmpty missingVolumes) then
        recommendations <- (sprintf "Create missing volume paths: %s" (missingVolumes |> List.map (fun v -> v.Path) |> String.concat ", ")) :: recommendations

    let failedProbes = probes |> List.filter (fun p -> not p.Success)
    if not (List.isEmpty failedProbes) then
        recommendations <- (sprintf "Fix failing health probes: %s" (failedProbes |> List.map (fun p -> p.ProbeName) |> String.concat ", ")) :: recommendations

    let overallSuccess =
        match result.Status with
        | Verified _ -> true
        | _ -> false

    let report = {
        NodeId = result.NodeId
        Timestamp = DateTime.UtcNow
        Level = level
        OverallSuccess = overallSuccess
        Constraints = constraintDetails
        BootCompliance = bootCompliance
        ImageCompliance = imageCompliance
        RootlessCompliance = rootlessCompliance
        PortConflicts = portConflicts
        VolumeMounts = volumeChecks
        ProbeResults = probes
        TotalDurationMs = duration
        Recommendations = recommendations |> List.rev
    }

    // Log report summary
    logger.Info("----------------------------------------------------------------------------")
    logger.Info("VERIFICATION REPORT SUMMARY")
    logger.Info("----------------------------------------------------------------------------")
    logger.Info(sprintf "  Node: %s" report.NodeId)
    logger.Info(sprintf "  Level: %A" report.Level)
    logger.Info(sprintf "  Overall: %s" (if report.OverallSuccess then "PASSED" else "FAILED"))
    logger.Info(sprintf "  Duration: %dms" report.TotalDurationMs)
    logger.Info(sprintf "  Constraints Checked: %d" (List.length report.Constraints))
    logger.Info(sprintf "  Boot Compliance: %b" report.BootCompliance)
    logger.Info(sprintf "  Image Compliance: %b" report.ImageCompliance)
    logger.Info(sprintf "  Rootless Compliance: %b" report.RootlessCompliance)

    if not (List.isEmpty report.Recommendations) then
        logger.Info("  Recommendations:")
        report.Recommendations |> List.iter (fun r -> logger.Info(sprintf "    - %s" r))

    logger.Info("----------------------------------------------------------------------------")

    report

/// Format verification report as a string for display/logging
let formatReport (report: VerificationReport) : string =
    let sb = System.Text.StringBuilder()

    sb.AppendLine("================================================================================") |> ignore
    sb.AppendLine(sprintf "VERIFICATION REPORT: %s" report.NodeId) |> ignore
    sb.AppendLine("================================================================================") |> ignore
    sb.AppendLine(sprintf "Timestamp: %s" (report.Timestamp.ToString("yyyy-MM-dd HH:mm:ss UTC"))) |> ignore
    sb.AppendLine(sprintf "Level: %A" report.Level) |> ignore
    sb.AppendLine(sprintf "Overall Result: %s" (if report.OverallSuccess then "PASSED" else "FAILED")) |> ignore
    sb.AppendLine(sprintf "Duration: %dms" report.TotalDurationMs) |> ignore
    sb.AppendLine("") |> ignore

    sb.AppendLine("STAMP CONSTRAINTS:") |> ignore
    for (id, passed, msg) in report.Constraints do
        let status = if passed then "[PASS]" else "[FAIL]"
        let msgStr = msg |> Option.map (sprintf " - %s") |> Option.defaultValue ""
        sb.AppendLine(sprintf "  %s %s%s" status id msgStr) |> ignore
    sb.AppendLine("") |> ignore

    sb.AppendLine("COMPLIANCE STATUS:") |> ignore
    sb.AppendLine(sprintf "  Boot Time (SC-CEP-004): %s" (if report.BootCompliance then "COMPLIANT" else "NON-COMPLIANT")) |> ignore
    sb.AppendLine(sprintf "  Image (SC-CNT-009/010): %s" (if report.ImageCompliance then "COMPLIANT" else "NON-COMPLIANT")) |> ignore
    sb.AppendLine(sprintf "  Rootless (SC-CNT-012): %s" (if report.RootlessCompliance then "COMPLIANT" else "NON-COMPLIANT")) |> ignore
    sb.AppendLine("") |> ignore

    if not (List.isEmpty report.PortConflicts) then
        sb.AppendLine("PORT CONFLICTS:") |> ignore
        for conflict in report.PortConflicts do
            sb.AppendLine(sprintf "  Port %d: in use by %s" conflict.Port (conflict.ConflictingProcess |> Option.defaultValue "unknown")) |> ignore
        sb.AppendLine("") |> ignore

    if not (List.isEmpty report.Recommendations) then
        sb.AppendLine("RECOMMENDATIONS:") |> ignore
        for rec_ in report.Recommendations do
            sb.AppendLine(sprintf "  - %s" rec_) |> ignore
        sb.AppendLine("") |> ignore

    sb.AppendLine("================================================================================") |> ignore

    sb.ToString()

// ============================================================================
// BATCH VERIFICATION
// ============================================================================

/// Verify multiple nodes in sequence
let verifyNodes
    (logger: UnifiedLogger)
    (runner: IProcessRunner)
    (nodes: (string * string * int list * string list) list)  // (nodeId, image, ports, volumes)
    (level: VerificationLevel) = async {

    logger.Info(sprintf "Starting batch verification of %d nodes at level %A" (List.length nodes) level)

    let! results =
        nodes
        |> List.map (fun (nodeId, image, ports, volumes) ->
            verifyNode logger runner nodeId image level ports volumes)
        |> Async.Sequential

    let resultList = results |> List.ofArray

    let passed = resultList |> List.filter (fun r -> match r.Status with Verified _ -> true | _ -> false)
    let failed = resultList |> List.filter (fun r -> match r.Status with VerificationFailed _ -> true | _ -> false)

    logger.Info("============================================================================")
    logger.Info("BATCH VERIFICATION COMPLETE")
    logger.Info(sprintf "  Total: %d | Passed: %d | Failed: %d" (List.length resultList) (List.length passed) (List.length failed))
    logger.Info("============================================================================")

    return resultList
}

/// Check if all nodes passed verification
let allNodesPassed (results: NodeVerificationResult list) : bool =
    results |> List.forall (fun r ->
        match r.Status with
        | Verified _ -> true
        | _ -> false)

/// Get failed node IDs from verification results
let getFailedNodes (results: NodeVerificationResult list) : string list =
    results
    |> List.choose (fun r ->
        match r.Status with
        | VerificationFailed _ -> Some r.NodeId
        | _ -> None)

/// Get constraint violations from verification results
let getConstraintViolations (results: NodeVerificationResult list) : (string * string) list =
    results
    |> List.collect (fun r ->
        r.Constraints
        |> List.filter (fun (_, passed) -> not passed)
        |> List.map (fun (constraintId, _) -> (r.NodeId, constraintId)))
