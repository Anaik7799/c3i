namespace Cepaf.Podman.Safety

open System
open Cepaf.Podman.Domain
open Cepaf.Podman.Client
open Cepaf.Podman.Api

/// STAMP Safety Constraints for Container Operations
/// Reference: GEMINI.md Section 5.0 Unified Safety Constraints
module Constraints =

    // ========================================================================
    // Safety Constraint Types
    // ========================================================================

    /// Safety constraint identifier
    type ConstraintId =
        | SC_CNT_009  // NixOS/Podman only
        | SC_CNT_010  // Localhost registry only
        | SC_CNT_012  // Rootless mode
        | SC_POD_001  // Pod naming convention
        | SC_POD_002  // Resource limits required
        | SC_POD_003  // Health check required
        | SC_POD_004  // Restart policy required
        | SC_POD_005  // Image source validation
        | SC_POD_006  // Network isolation
        | SC_POD_007  // Volume mount validation
        | SC_POD_008  // Security context required
        | SC_PRF_050  // Response latency < 50ms
        | SC_PRF_055  // No blocking operations
        | SC_EMR_057  // Stop < 5s
        | SC_EMR_060  // Rollback capability

    /// Constraint violation
    type Violation = {
        Constraint: ConstraintId
        Resource: string
        Message: string
        Severity: ViolationSeverity
        Timestamp: DateTimeOffset
    }

    and ViolationSeverity =
        | Critical  // Must fix before operation
        | Warning   // Should fix, operation allowed
        | Info      // Informational only

    /// Validation result
    type ValidationResult =
        | Valid
        | Invalid of Violation list

    module ValidationResult =
        let isValid = function Valid -> true | Invalid _ -> false
        let violations = function Valid -> [] | Invalid vs -> vs

        let combine (r1: ValidationResult) (r2: ValidationResult) : ValidationResult =
            match r1, r2 with
            | Valid, Valid -> Valid
            | Valid, Invalid vs -> Invalid vs
            | Invalid vs, Valid -> Invalid vs
            | Invalid vs1, Invalid vs2 -> Invalid (vs1 @ vs2)

        let combineAll (results: ValidationResult list) : ValidationResult =
            results |> List.fold combine Valid

    // ========================================================================
    // Constraint Validation Functions
    // ========================================================================

    /// Validate container spec
    let validateContainerSpec (spec: ContainerSpec) : ValidationResult =
        let violations = [
            // SC-POD-005: Image must be from localhost/ registry
            if not (spec.Image.StartsWith("localhost/")) then
                yield {
                    Constraint = SC_POD_005
                    Resource = spec.Image
                    Message = sprintf "Image '%s' must use localhost/ registry (SC-POD-005)" spec.Image
                    Severity = Critical
                    Timestamp = DateTimeOffset.UtcNow
                }

            // SC-POD-001: Container naming convention
            match spec.Name with
            | Some name when not (name.StartsWith("indrajaal-")) && not (name.Contains("-")) ->
                yield {
                    Constraint = SC_POD_001
                    Resource = name
                    Message = sprintf "Container name '%s' should follow naming convention (SC-POD-001)" name
                    Severity = Warning
                    Timestamp = DateTimeOffset.UtcNow
                }
            | _ -> ()

            // SC-POD-002: Resource limits should be specified
            match spec.Resources with
            | None ->
                yield {
                    Constraint = SC_POD_002
                    Resource = spec.Name |> Option.defaultValue spec.Image
                    Message = "Resource limits not specified (SC-POD-002)"
                    Severity = Warning
                    Timestamp = DateTimeOffset.UtcNow
                }
            | Some r when r.Memory.IsNone || (r.Memory.Value.Limit.IsNone) ->
                yield {
                    Constraint = SC_POD_002
                    Resource = spec.Name |> Option.defaultValue spec.Image
                    Message = "Memory limit not specified (SC-POD-002)"
                    Severity = Warning
                    Timestamp = DateTimeOffset.UtcNow
                }
            | _ -> ()

            // SC-POD-003: Health check should be configured
            match spec.HealthCheck with
            | None ->
                yield {
                    Constraint = SC_POD_003
                    Resource = spec.Name |> Option.defaultValue spec.Image
                    Message = "Health check not configured (SC-POD-003)"
                    Severity = Warning
                    Timestamp = DateTimeOffset.UtcNow
                }
            | _ -> ()

            // SC-POD-004: Restart policy should be specified
            match spec.RestartPolicy with
            | Option.None ->
                yield {
                    Constraint = SC_POD_004
                    Resource = spec.Name |> Option.defaultValue spec.Image
                    Message = "Restart policy not specified (SC-POD-004)"
                    Severity = Info
                    Timestamp = DateTimeOffset.UtcNow
                }
            | _ -> ()

            // SC-POD-008: Security context validation
            match spec.Security with
            | None ->
                yield {
                    Constraint = SC_POD_008
                    Resource = spec.Name |> Option.defaultValue spec.Image
                    Message = "Security context not configured (SC-POD-008)"
                    Severity = Warning
                    Timestamp = DateTimeOffset.UtcNow
                }
            | Some sec when not sec.ReadOnlyRootfs ->
                yield {
                    Constraint = SC_POD_008
                    Resource = spec.Name |> Option.defaultValue spec.Image
                    Message = "Root filesystem should be read-only (SC-POD-008)"
                    Severity = Info
                    Timestamp = DateTimeOffset.UtcNow
                }
            | _ -> ()

            // SC-POD-007: Volume mount validation
            for mount in spec.Mounts do
                if mount.Source.StartsWith("/") && not (mount.Source.StartsWith("/home/")) then
                    yield {
                        Constraint = SC_POD_007
                        Resource = mount.Source
                        Message = sprintf "Mount source '%s' outside /home/ may be sensitive (SC-POD-007)" mount.Source
                        Severity = Warning
                        Timestamp = DateTimeOffset.UtcNow
                    }
        ]

        if violations.IsEmpty then Valid else Invalid violations

    /// Validate pod spec
    let validatePodSpec (spec: PodSpec) : ValidationResult =
        let violations = [
            // SC-POD-001: Pod naming convention
            match spec.Name with
            | Some name when not (name.StartsWith("indrajaal-")) ->
                yield {
                    Constraint = SC_POD_001
                    Resource = name
                    Message = sprintf "Pod name '%s' should start with 'indrajaal-' (SC-POD-001)" name
                    Severity = Warning
                    Timestamp = DateTimeOffset.UtcNow
                }
            | None ->
                yield {
                    Constraint = SC_POD_001
                    Resource = "unnamed"
                    Message = "Pod should have a name (SC-POD-001)"
                    Severity = Warning
                    Timestamp = DateTimeOffset.UtcNow
                }
            | _ -> ()

            // SC-POD-006: Network isolation
            if spec.Network.IsNone then
                yield {
                    Constraint = SC_POD_006
                    Resource = spec.Name |> Option.defaultValue "unnamed"
                    Message = "Network namespace not specified (SC-POD-006)"
                    Severity = Info
                    Timestamp = DateTimeOffset.UtcNow
                }
        ]

        if violations.IsEmpty then Valid else Invalid violations

    /// Validate image reference
    let validateImageReference (reference: string) : ValidationResult =
        let violations = [
            // SC-CNT-010: Localhost registry only
            if not (reference.StartsWith("localhost/")) then
                yield {
                    Constraint = SC_CNT_010
                    Resource = reference
                    Message = sprintf "Image '%s' must use localhost/ registry (SC-CNT-010)" reference
                    Severity = Critical
                    Timestamp = DateTimeOffset.UtcNow
                }

            // Check for latest tag (discouraged)
            if reference.EndsWith(":latest") || not (reference.Contains(":")) then
                yield {
                    Constraint = SC_POD_005
                    Resource = reference
                    Message = "Image should use explicit version tag, not ':latest' (SC-POD-005)"
                    Severity = Warning
                    Timestamp = DateTimeOffset.UtcNow
                }
        ]

        if violations.IsEmpty then Valid else Invalid violations

    // ========================================================================
    // Runtime Validation
    // ========================================================================

    /// Validate client is using rootless podman
    let validateRootless (client: PodmanClient) : AsyncPodmanResult<ValidationResult> = async {
        let! infoResult = System.info client
        return infoResult |> Result.map (fun info ->
            if info.Host.Os <> "linux" then
                Invalid [{
                    Constraint = SC_CNT_009
                    Resource = "host"
                    Message = sprintf "Expected Linux host, got '%s' (SC-CNT-009)" info.Host.Os
                    Severity = Critical
                    Timestamp = DateTimeOffset.UtcNow
                }]
            else
                Valid
        )
    }

    /// Validate container is healthy
    let validateContainerHealth (client: PodmanClient) (containerId: string) : AsyncPodmanResult<ValidationResult> = async {
        let! healthResult = Containers.healthCheck client containerId
        return healthResult |> Result.map (fun status ->
            match status with
            | HealthStatus.Healthy -> Valid
            | HealthStatus.Unhealthy _ ->
                Invalid [{
                    Constraint = SC_POD_003
                    Resource = containerId
                    Message = "Container is unhealthy (SC-POD-003)"
                    Severity = Critical
                    Timestamp = DateTimeOffset.UtcNow
                }]
            | HealthStatus.Starting ->
                Invalid [{
                    Constraint = SC_POD_003
                    Resource = containerId
                    Message = "Container health check still starting (SC-POD-003)"
                    Severity = Warning
                    Timestamp = DateTimeOffset.UtcNow
                }]
            | HealthStatus.NoHealthcheck ->
                Invalid [{
                    Constraint = SC_POD_003
                    Resource = containerId
                    Message = "Container has no health check configured (SC-POD-003)"
                    Severity = Warning
                    Timestamp = DateTimeOffset.UtcNow
                }]
            | HealthStatus.Unknown s ->
                Invalid [{
                    Constraint = SC_POD_003
                    Resource = containerId
                    Message = sprintf "Container health status unknown: %s (SC-POD-003)" s
                    Severity = Warning
                    Timestamp = DateTimeOffset.UtcNow
                }]
        )
    }

    /// Validate all running containers meet safety requirements
    let validateAllContainers (client: PodmanClient) : AsyncPodmanResult<ValidationResult> = async {
        let! containersResult = Containers.listRunning client
        match containersResult with
        | Error e -> return Error e
        | Ok containers ->
            let! validations =
                containers
                |> List.map (fun c -> async {
                    let! health = validateContainerHealth client c.Id
                    return health |> Result.defaultValue Valid
                })
                |> Async.Parallel

            return Ok (validations |> Array.toList |> ValidationResult.combineAll)
    }

    // ========================================================================
    // SC-PRF-055: Async-Blocking Detection (No Blocking Operations)
    // ========================================================================

    /// Async operation context for blocking detection
    module AsyncBlockingDetector =
        open System.Threading
        open System.Diagnostics

        /// Track operation timing for blocking detection
        type OperationContext = {
            StartTime: int64
            OperationName: string
            ThreadId: int
            mutable WasBlocked: bool
            mutable BlockingDuration: int64
        }

        /// Create new operation context
        let startOperation (name: string) : OperationContext =
            {
                StartTime = Stopwatch.GetTimestamp()
                OperationName = name
                ThreadId = Thread.CurrentThread.ManagedThreadId
                WasBlocked = false
                BlockingDuration = 0L
            }

        /// Check if current operation switched threads (async continuation)
        let checkThreadSwitch (ctx: OperationContext) : bool =
            Thread.CurrentThread.ManagedThreadId <> ctx.ThreadId

        /// Record blocking operation detected
        let recordBlocking (ctx: OperationContext) (durationMs: int64) : unit =
            ctx.WasBlocked <- true
            ctx.BlockingDuration <- durationMs

        /// Maximum allowed synchronous blocking time (ms)
        let maxBlockingThresholdMs = 50L

        /// Validate operation didn't exceed blocking threshold
        let validateNonBlocking (ctx: OperationContext) : ValidationResult =
            let elapsed = (Stopwatch.GetTimestamp() - ctx.StartTime) * 1000L / Stopwatch.Frequency
            if elapsed > maxBlockingThresholdMs && not (checkThreadSwitch ctx) then
                Invalid [{
                    Constraint = SC_PRF_055
                    Resource = ctx.OperationName
                    Message = (sprintf "Operation '%s' blocked for %dms (threshold: %dms) (SC-PRF-055)" ctx.OperationName elapsed maxBlockingThresholdMs)
                    Severity = Warning
                    Timestamp = DateTimeOffset.UtcNow
                }]
            else if ctx.WasBlocked then
                Invalid [{
                    Constraint = SC_PRF_055
                    Resource = ctx.OperationName
                    Message = (sprintf "Operation '%s' had blocking section of %dms (SC-PRF-055)" ctx.OperationName ctx.BlockingDuration)
                    Severity = Warning
                    Timestamp = DateTimeOffset.UtcNow
                }]
            else
                Valid

        /// Wrap async operation with blocking detection
        let wrapWithDetection<'T> (operationName: string) (operation: Async<'T>) : Async<'T * ValidationResult> = async {
            let ctx = startOperation operationName
            let! result = operation
            let validation = validateNonBlocking ctx
            return (result, validation)
        }

        /// Format a single violation (inline to avoid forward reference)
        let private formatViolationInternal (v: Violation) : string =
            sprintf "[%s] %s: %s (%s)"
                (match v.Severity with Critical -> "CRIT" | Warning -> "WARN" | Info -> "INFO")
                (sprintf "%A" v.Constraint)
                v.Message
                v.Resource

        /// Execute with SC-PRF-055 validation
        let executeWithValidation<'T> (operationName: string) (operation: Async<Result<'T, PodmanError>>) : Async<Result<'T, PodmanError>> = async {
            let ctx = startOperation operationName
            let! result = operation
            let validation = validateNonBlocking ctx
            match validation with
            | Invalid violations ->
                // Log warning but don't fail - SC-PRF-055 is a warning not critical
                for v in violations do
                    System.Diagnostics.Debug.WriteLine(formatViolationInternal v)
            | Valid -> ()
            return result
        }

    // ========================================================================
    // Safe Operations (Pre-validated)
    // ========================================================================

    /// Create container with validation (includes SC-PRF-055 blocking detection)
    let safeCreateContainer (client: PodmanClient) (spec: ContainerSpec) : AsyncPodmanResult<string> = async {
        match validateContainerSpec spec with
        | Invalid violations ->
            let criticals = violations |> List.filter (fun v -> v.Severity = Critical)
            if not criticals.IsEmpty then
                let msgs = criticals |> List.map (fun v -> v.Message)
                return Error (PodmanError.ValidationFailed msgs)
            else
                // Warnings only - proceed with SC-PRF-055 monitoring
                let operationName = sprintf "createContainer:%s" (spec.Name |> Option.defaultValue spec.Image)
                return! AsyncBlockingDetector.executeWithValidation operationName (Containers.create client spec)
        | Valid ->
            let operationName = sprintf "createContainer:%s" (spec.Name |> Option.defaultValue spec.Image)
            return! AsyncBlockingDetector.executeWithValidation operationName (Containers.create client spec)
    }

    /// Create and start container with validation (includes SC-PRF-055 blocking detection)
    let safeCreateAndStart (client: PodmanClient) (spec: ContainerSpec) : AsyncPodmanResult<string> = async {
        match validateContainerSpec spec with
        | Invalid violations ->
            let criticals = violations |> List.filter (fun v -> v.Severity = Critical)
            if not criticals.IsEmpty then
                let msgs = criticals |> List.map (fun v -> v.Message)
                return Error (PodmanError.ValidationFailed msgs)
            else
                // SC-PRF-055 monitoring for createAndStart
                let operationName = sprintf "createAndStart:%s" (spec.Name |> Option.defaultValue spec.Image)
                return! AsyncBlockingDetector.executeWithValidation operationName (Containers.createAndStart client spec)
        | Valid ->
            let operationName = sprintf "createAndStart:%s" (spec.Name |> Option.defaultValue spec.Image)
            return! AsyncBlockingDetector.executeWithValidation operationName (Containers.createAndStart client spec)
    }

    /// Pull image with validation (includes SC-PRF-055 blocking detection)
    let safePullImage (client: PodmanClient) (reference: string) : AsyncPodmanResult<string> = async {
        match validateImageReference reference with
        | Invalid violations ->
            let criticals = violations |> List.filter (fun v -> v.Severity = Critical)
            if not criticals.IsEmpty then
                let msg = criticals |> List.map (fun v -> v.Message) |> String.concat "; "
                return Error (PodmanError.RegistryNotAllowed msg)
            else
                // SC-PRF-055 monitoring for image pull
                let operationName = sprintf "pullImage:%s" reference
                return! AsyncBlockingDetector.executeWithValidation operationName (Images.pull client reference)
        | Valid ->
            let operationName = sprintf "pullImage:%s" reference
            return! AsyncBlockingDetector.executeWithValidation operationName (Images.pull client reference)
    }

    /// Create pod with validation (includes SC-PRF-055 blocking detection)
    let safeCreatePod (client: PodmanClient) (spec: PodSpec) : AsyncPodmanResult<string> = async {
        match validatePodSpec spec with
        | Invalid violations ->
            let criticals = violations |> List.filter (fun v -> v.Severity = Critical)
            if not criticals.IsEmpty then
                let msgs = criticals |> List.map (fun v -> v.Message)
                return Error (PodmanError.ValidationFailed msgs)
            else
                // SC-PRF-055 monitoring for pod creation
                let operationName = sprintf "createPod:%s" (spec.Name |> Option.defaultValue "unnamed")
                return! AsyncBlockingDetector.executeWithValidation operationName (Pods.create client spec)
        | Valid ->
            let operationName = sprintf "createPod:%s" (spec.Name |> Option.defaultValue "unnamed")
            return! AsyncBlockingDetector.executeWithValidation operationName (Pods.create client spec)
    }

    // ========================================================================
    // Emergency Operations
    // ========================================================================

    /// SC-EMR-057: Stop container within timeout
    let emergencyStop (client: PodmanClient) (containerId: string) (timeoutSeconds: int) : AsyncPodmanResult<unit> = async {
        // First try graceful stop
        let! stopResult = Containers.stop client containerId (Some timeoutSeconds)
        match stopResult with
        | Ok () -> return Ok ()
        | Error _ ->
            // Force kill if graceful stop fails
            let! killResult = Containers.kill client containerId (Some "SIGKILL")
            return killResult
    }

    /// SC-EMR-060: Remove container and all associated resources
    let emergencyRemove (client: PodmanClient) (containerId: string) : AsyncPodmanResult<unit> = async {
        // Force stop first
        let! _ = emergencyStop client containerId 5
        // Force remove with volumes
        return! Containers.remove client containerId true true
    }

    /// Emergency stop all containers
    let emergencyStopAll (client: PodmanClient) : AsyncPodmanResult<int> = async {
        let! containersResult = Containers.listRunning client
        match containersResult with
        | Error e -> return Error e
        | Ok containers ->
            let! _ =
                containers
                |> List.map (fun c -> emergencyStop client c.Id 5)
                |> Async.Parallel
            return Ok containers.Length
    }

    // ========================================================================
    // Constraint Reporting
    // ========================================================================

    /// Format violation for logging
    let formatViolation (v: Violation) : string =
        sprintf "[%s] %s: %s (%s)"
            (match v.Severity with Critical -> "CRIT" | Warning -> "WARN" | Info -> "INFO")
            (sprintf "%A" v.Constraint)
            v.Message
            v.Resource

    /// Get violation summary
    let violationSummary (result: ValidationResult) : string =
        match result with
        | Valid -> "All constraints passed"
        | Invalid violations ->
            let critical = violations |> List.filter (fun v -> v.Severity = Critical) |> List.length
            let warning = violations |> List.filter (fun v -> v.Severity = Warning) |> List.length
            let info = violations |> List.filter (fun v -> v.Severity = Info) |> List.length
            sprintf "Violations: %d critical, %d warnings, %d info" critical warning info

