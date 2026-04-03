/// CEPAF STAMP Constraint Validator Module
/// SC-CEP-001: Artifact locality validation
/// SC-CNT-009: NixOS container enforcement
/// SC-CNT-010: Localhost registry validation
/// SC-CNT-012: Rootless Podman verification
/// SC-CEP-004: 30-second boot threshold
///
/// WHAT: Validates STAMP safety constraints for container orchestration
/// WHY: Ensures compliance with safety-critical system requirements
/// CONSTRAINTS: All violations halt execution per SC-EMR-057
module Cepaf.Modules.ConstraintValidator

open System
open Cepaf

// ============================================================================
// TYPES
// ============================================================================

/// Severity levels for constraint violations (SC-EMR-057 compliance)
type Severity =
    | Critical   // Immediate halt required (<1s per AOR-SAF-001)
    | High       // Must fix before deploy
    | Medium     // Should fix soon
    | Low        // Advisory only

/// STAMP Constraint Violation record
type ConstraintViolation = {
    ConstraintId: string           // e.g., "SC-CNT-009"
    Message: string
    Severity: Severity
    Timestamp: DateTime
    Context: Map<string, string>
}

/// Container specification for validation
type ContainerSpec = {
    Name: string
    Image: string
    DependsOn: string list
    IsRootless: bool
    Ports: (int * int) list        // (host, container) port pairs
    VolumeMounts: string list
    Environment: Map<string, string>
}

/// Runtime specification
type RuntimeSpec = {
    Name: string
    IsRootless: bool
    Socket: string option
    Version: string option
}

/// Validation result with multiple violations
type ValidationResult =
    | Valid
    | Invalid of ConstraintViolation list

// ============================================================================
// CONSTRAINT VALIDATORS - CONTAINER (SC-CNT)
// ============================================================================

/// SC-CNT-009: Validate NixOS container image
/// All containers MUST use NixOS-based images
let validateNixOS (container: ContainerSpec) : Result<ContainerSpec, ConstraintViolation> =
    match container.Image with
    | null | "" ->
        Error {
            ConstraintId = "SC-CNT-009"
            Message = "Container image cannot be null or empty"
            Severity = Critical
            Timestamp = DateTime.UtcNow
            Context = Map.ofList [
                ("container", container.Name |> Option.ofObj |> Option.defaultValue "unknown")
            ]
        }
    | image ->
        let imageLower = image.ToLowerInvariant()
        if imageLower.Contains("nixos") || imageLower.StartsWith("localhost/indrajaal-") then
            Ok container
        else
            Error {
                ConstraintId = "SC-CNT-009"
                Message = sprintf "Container must use NixOS image. Found: %s" image
                Severity = Critical
                Timestamp = DateTime.UtcNow
                Context = Map.ofList [
                    ("container", container.Name |> Option.ofObj |> Option.defaultValue "unknown")
                    ("image", image)
                    ("expected", "NixOS-based image (localhost/indrajaal-*)")
                ]
            }

/// SC-CNT-010: Validate localhost registry
/// All images MUST come from localhost/ registry
let validateLocalRegistry (image: string) : Result<string, ConstraintViolation> =
    match image with
    | null | "" ->
        Error {
            ConstraintId = "SC-CNT-010"
            Message = "Image cannot be null or empty"
            Severity = Critical
            Timestamp = DateTime.UtcNow
            Context = Map.empty
        }
    | img when img.StartsWith("localhost/") ->
        Ok img
    | img ->
        Error {
            ConstraintId = "SC-CNT-010"
            Message = sprintf "Image must use localhost registry. Found: %s" img
            Severity = Critical
            Timestamp = DateTime.UtcNow
            Context = Map.ofList [
                ("image", img)
                ("expected", "localhost/*")
                ("actual_registry",
                    if img.Contains("/") then img.Split('/').[0] else "docker.io (implicit)")
            ]
        }

/// SC-CNT-012: Validate rootless execution
/// Podman MUST run in rootless mode
let validateRootless (runtime: RuntimeSpec) : Result<RuntimeSpec, ConstraintViolation> =
    if runtime.IsRootless then
        Ok runtime
    else
        Error {
            ConstraintId = "SC-CNT-012"
            Message = "Podman must run in rootless mode for security compliance"
            Severity = Critical
            Timestamp = DateTime.UtcNow
            Context = Map.ofList [
                ("runtime", runtime.Name)
                ("is_rootless", string runtime.IsRootless)
                ("socket", runtime.Socket |> Option.defaultValue "unknown")
            ]
        }

/// SC-CNT-013: Validate image pull policy (implicit localhost = never pull)
let validateImagePullPolicy (image: string) : Result<string, ConstraintViolation> =
    match image with
    | null | "" ->
        Error {
            ConstraintId = "SC-CNT-013"
            Message = "Image cannot be null or empty"
            Severity = High
            Timestamp = DateTime.UtcNow
            Context = Map.empty
        }
    | img when img.StartsWith("localhost/") ->
        Ok img  // Local images don't need pull
    | img ->
        Error {
            ConstraintId = "SC-CNT-013"
            Message = sprintf "External images not allowed. Must use local builds: %s" img
            Severity = High
            Timestamp = DateTime.UtcNow
            Context = Map.ofList [("image", img)]
        }

/// SC-CNT-014: Validate volume mounts (no host system paths)
let validateVolumeMounts (container: ContainerSpec) : Result<ContainerSpec, ConstraintViolation> =
    let dangerousPaths = ["/etc"; "/var"; "/usr"; "/bin"; "/sbin"; "/root"; "/home"]

    // Extract the source path from a mount (format: source:destination[:options])
    let getSourcePath (mount: string) =
        match mount with
        | null | "" -> ""
        | m -> m.Split(':').[0]

    // Check if a source path starts with any dangerous path
    let isDangerous (sourcePath: string) =
        dangerousPaths |> List.exists (fun danger ->
            sourcePath.StartsWith(danger + "/") || sourcePath = danger)

    let violations =
        container.VolumeMounts
        |> List.filter (fun mount ->
            let source = getSourcePath mount
            isDangerous source)

    if List.isEmpty violations then
        Ok container
    else
        Error {
            ConstraintId = "SC-CNT-014"
            Message = sprintf "Dangerous host paths mounted: %s" (String.concat ", " violations)
            Severity = Critical
            Timestamp = DateTime.UtcNow
            Context = Map.ofList [
                ("container", container.Name |> Option.ofObj |> Option.defaultValue "unknown")
                ("violations", String.concat ";" violations)
            ]
        }

// ============================================================================
// CONSTRAINT VALIDATORS - CEPAF (SC-CEP)
// ============================================================================

/// SC-CEP-004: Validate 30-second boot threshold
/// Full stack boot MUST complete within 30 seconds
let validateBootThreshold (duration: TimeSpan) : Result<TimeSpan, ConstraintViolation> =
    let thresholdSeconds = 30.0
    if duration.TotalSeconds <= thresholdSeconds then
        Ok duration
    else
        Error {
            ConstraintId = "SC-CEP-004"
            Message = sprintf "Boot time %.2fs exceeds 30s threshold" duration.TotalSeconds
            Severity = High
            Timestamp = DateTime.UtcNow
            Context = Map.ofList [
                ("duration_seconds", sprintf "%.2f" duration.TotalSeconds)
                ("threshold_seconds", string thresholdSeconds)
                ("exceeded_by", sprintf "%.2f" (duration.TotalSeconds - thresholdSeconds))
            ]
        }

/// SC-CEP-001: Validate artifact locality (PathResolver scope)
/// All paths MUST be within the CEPAF directory scope
let validateArtifactLocality (basePath: string) (targetPath: string) : Result<string, ConstraintViolation> =
    let normalizedBase = IO.Path.GetFullPath(basePath).TrimEnd([|'/'; '\\'|])
    let normalizedTarget = IO.Path.GetFullPath(targetPath).TrimEnd([|'/'; '\\'|])

    if normalizedTarget.StartsWith(normalizedBase) then
        Ok targetPath
    else
        Error {
            ConstraintId = "SC-CEP-001"
            Message = sprintf "Path outside CEPAF scope: %s" targetPath
            Severity = Critical
            Timestamp = DateTime.UtcNow
            Context = Map.ofList [
                ("target_path", targetPath)
                ("base_path", basePath)
                ("scope_violation", "true")
            ]
        }

/// SC-CEP-006: Validate VTO phase sequence
/// VTO phases MUST execute in order: VERIFY -> TEARDOWN -> ORCHESTRATE
let validateVtoPhaseSequence (previousPhase: string option) (currentPhase: string) : Result<string, ConstraintViolation> =
    let validTransitions = Map.ofList [
        (None, "VERIFY")
        (Some "VERIFY", "TEARDOWN")
        (Some "TEARDOWN", "ORCHESTRATE")
        (Some "ORCHESTRATE", "COMPLETE")
    ]

    match Map.tryFind previousPhase validTransitions with
    | Some expected when expected = currentPhase -> Ok currentPhase
    | Some expected ->
        Error {
            ConstraintId = "SC-CEP-006"
            Message = sprintf "Invalid VTO phase transition. Expected %s, got %s" expected currentPhase
            Severity = High
            Timestamp = DateTime.UtcNow
            Context = Map.ofList [
                ("previous_phase", previousPhase |> Option.defaultValue "START")
                ("current_phase", currentPhase)
                ("expected_phase", expected)
            ]
        }
    | None ->
        Error {
            ConstraintId = "SC-CEP-006"
            Message = sprintf "Unknown VTO phase state: previous=%s, current=%s"
                (previousPhase |> Option.defaultValue "START") currentPhase
            Severity = High
            Timestamp = DateTime.UtcNow
            Context = Map.ofList [
                ("previous_phase", previousPhase |> Option.defaultValue "START")
                ("current_phase", currentPhase)
            ]
        }

// ============================================================================
// CONSTRAINT VALIDATORS - PERFORMANCE (SC-PRF)
// ============================================================================

/// SC-PRF-050: Validate response time <50ms (PHICS latency)
let validateResponseTime (responseMs: int64) : Result<int64, ConstraintViolation> =
    let thresholdMs = 50L
    if responseMs <= thresholdMs then
        Ok responseMs
    else
        Error {
            ConstraintId = "SC-PRF-050"
            Message = sprintf "Response time %dms exceeds 50ms threshold" responseMs
            Severity = Medium
            Timestamp = DateTime.UtcNow
            Context = Map.ofList [
                ("response_ms", string responseMs)
                ("threshold_ms", string thresholdMs)
            ]
        }

// ============================================================================
// CONSTRAINT VALIDATORS - EMERGENCY (SC-EMR)
// ============================================================================

/// SC-EMR-057: Validate emergency stop <5s
let validateEmergencyStop (stopDuration: TimeSpan) : Result<TimeSpan, ConstraintViolation> =
    let thresholdSeconds = 5.0
    if stopDuration.TotalSeconds <= thresholdSeconds then
        Ok stopDuration
    else
        Error {
            ConstraintId = "SC-EMR-057"
            Message = sprintf "Emergency stop %.2fs exceeds 5s threshold" stopDuration.TotalSeconds
            Severity = Critical
            Timestamp = DateTime.UtcNow
            Context = Map.ofList [
                ("stop_duration_seconds", sprintf "%.2f" stopDuration.TotalSeconds)
                ("threshold_seconds", string thresholdSeconds)
            ]
        }

// ============================================================================
// CONSTRAINT VALIDATORS - SAFETY (AOR-SAF)
// ============================================================================

/// AOR-SAF-001: Validate safety halt <1s
let validateSafetyHalt (haltDuration: TimeSpan) : Result<TimeSpan, ConstraintViolation> =
    let thresholdSeconds = 1.0
    if haltDuration.TotalSeconds <= thresholdSeconds then
        Ok haltDuration
    else
        Error {
            ConstraintId = "AOR-SAF-001"
            Message = sprintf "Safety halt %.3fs exceeds 1s threshold" haltDuration.TotalSeconds
            Severity = Critical
            Timestamp = DateTime.UtcNow
            Context = Map.ofList [
                ("halt_duration_seconds", sprintf "%.3f" haltDuration.TotalSeconds)
                ("threshold_seconds", string thresholdSeconds)
            ]
        }

// ============================================================================
// CONSTRAINT VALIDATORS - QUALITY (AOR-QUA)
// ============================================================================

/// Compilation result for quality checks
type CompilationResult = {
    Errors: int
    Warnings: int
    Files: int
}

/// AOR-QUA-001: Zero warnings mandatory
let validateZeroWarnings (result: CompilationResult) : Result<CompilationResult, ConstraintViolation> =
    if result.Warnings = 0 && result.Errors = 0 then
        Ok result
    else
        Error {
            ConstraintId = "AOR-QUA-001"
            Message = sprintf "Compilation has %d errors and %d warnings (must be 0)" result.Errors result.Warnings
            Severity = if result.Errors > 0 then Critical else High
            Timestamp = DateTime.UtcNow
            Context = Map.ofList [
                ("errors", string result.Errors)
                ("warnings", string result.Warnings)
                ("files", string result.Files)
            ]
        }

// ============================================================================
// CONSTRAINT VALIDATORS - BATCH (AOR-BATCH)
// ============================================================================

/// AOR-BATCH-001: Max 10 changes per batch
let validateBatchSize<'T> (changes: 'T list) : Result<'T list, ConstraintViolation> =
    let maxSize = 10
    if List.length changes <= maxSize then
        Ok changes
    else
        Error {
            ConstraintId = "AOR-BATCH-001"
            Message = sprintf "Batch size %d exceeds maximum of 10" (List.length changes)
            Severity = High
            Timestamp = DateTime.UtcNow
            Context = Map.ofList [
                ("batch_size", string (List.length changes))
                ("max_size", string maxSize)
            ]
        }

// ============================================================================
// COMPOSITE VALIDATORS
// ============================================================================

/// Validate all container constraints
let validateContainer (container: ContainerSpec) : ValidationResult =
    let violations = ResizeArray<ConstraintViolation>()

    // SC-CNT-009: NixOS image
    match validateNixOS container with
    | Error v -> violations.Add(v)
    | Ok _ -> ()

    // SC-CNT-010: Localhost registry
    match validateLocalRegistry container.Image with
    | Error v -> violations.Add(v)
    | Ok _ -> ()

    // SC-CNT-014: Volume mounts
    match validateVolumeMounts container with
    | Error v -> violations.Add(v)
    | Ok _ -> ()

    if violations.Count > 0 then
        Invalid (violations |> List.ofSeq)
    else
        Valid

/// Validate all container constraints and return detailed result
let validateContainerWithDetails (container: ContainerSpec) : ContainerSpec * ValidationResult =
    (container, validateContainer container)

/// Validate multiple containers
let validateContainers (containers: ContainerSpec list) : (ContainerSpec * ValidationResult) list =
    containers |> List.map validateContainerWithDetails

/// Check if any validation has critical violations
let hasCriticalViolations (result: ValidationResult) : bool =
    match result with
    | Valid -> false
    | Invalid violations ->
        violations |> List.exists (fun v -> v.Severity = Critical)

/// Get all violations from a validation result
let getViolations (result: ValidationResult) : ConstraintViolation list =
    match result with
    | Valid -> []
    | Invalid violations -> violations

/// Combine multiple validation results
let combineResults (results: ValidationResult list) : ValidationResult =
    let allViolations =
        results
        |> List.collect getViolations

    if List.isEmpty allViolations then
        Valid
    else
        Invalid allViolations

/// Format a constraint violation for display
let formatViolation (v: ConstraintViolation) : string =
    let severityStr =
        match v.Severity with
        | Critical -> "CRITICAL"
        | High -> "HIGH"
        | Medium -> "MEDIUM"
        | Low -> "LOW"

    sprintf "[%s] %s: %s" severityStr v.ConstraintId v.Message

/// Format all violations for display
let formatViolations (result: ValidationResult) : string list =
    result |> getViolations |> List.map formatViolation

// ============================================================================
// VALIDATION PREDICATES (for quick checks)
// ============================================================================

/// Quick check: is this a valid NixOS image?
let isNixOSImage (image: string) : bool =
    match image with
    | null | "" -> false
    | img ->
        let lower = img.ToLowerInvariant()
        lower.Contains("nixos") || lower.StartsWith("localhost/indrajaal-")

/// Quick check: is this a localhost image?
let isLocalhostImage (image: string) : bool =
    match image with
    | null | "" -> false
    | img -> img.StartsWith("localhost/")

/// Quick check: is boot time within threshold?
let isBootWithinThreshold (durationSeconds: float) : bool =
    durationSeconds <= 30.0

/// Quick check: is response time acceptable?
let isResponseTimeAcceptable (responseMs: int64) : bool =
    responseMs <= 50L

// ============================================================================
// HELPER FUNCTIONS FOR CLASSIFICATION (SC-FSH-070)
// ============================================================================

/// Classify severity to string (SC-FSH-050)
let classifySeverity (violation: ConstraintViolation) : string =
    match violation.Severity with
    | Critical -> "CRITICAL"
    | High -> "HIGH"
    | Medium -> "MEDIUM"
    | Low -> "LOW"

/// Get violations sorted by severity using type-safe comparison
let getViolationsBySeverity (result: ValidationResult) : ConstraintViolation list =
    result
    |> getViolations
    |> List.sortBy (fun v ->
        match v.Severity with
        | Critical -> 0
        | High -> 1
        | Medium -> 2
        | Low -> 3)

/// Check if system is in compliant state (SC-FSH-050)
let isSystemCompliant (results: ValidationResult list) : bool =
    results
    |> List.forall (fun r ->
        match r with
        | Valid -> true
        | Invalid violations ->
            not (violations |> List.exists (fun v -> v.Severity = Critical || v.Severity = High)))

/// Get compliance summary with classification (SC-FSH-050)
let getComplianceSummary (results: ValidationResult list) =
    let allViolations = results |> List.collect getViolations
    let criticalCount = allViolations |> List.filter (fun v -> v.Severity = Critical) |> List.length
    let highCount = allViolations |> List.filter (fun v -> v.Severity = High) |> List.length
    let mediumCount = allViolations |> List.filter (fun v -> v.Severity = Medium) |> List.length
    let lowCount = allViolations |> List.filter (fun v -> v.Severity = Low) |> List.length

    let classification =
        if criticalCount > 0 then "CRITICAL"
        elif highCount > 0 then "NON_COMPLIANT"
        elif mediumCount > 0 then "WARNING"
        else "COMPLIANT"

    {|
        TotalViolations = List.length allViolations
        CriticalCount = criticalCount
        HighCount = highCount
        MediumCount = mediumCount
        LowCount = lowCount
        Classification = classification
        IsCompliant = criticalCount = 0 && highCount = 0
        RequiresAttention = criticalCount > 0 || highCount > 0 || mediumCount > 0
    |}
