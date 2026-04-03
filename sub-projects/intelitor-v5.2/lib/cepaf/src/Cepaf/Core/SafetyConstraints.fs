namespace Cepaf.Core

open System
open System.Diagnostics
open Cepaf.Core.DomainUnits
open Cepaf.Core.DomainPatterns
open Cepaf.Core.Pipelines

/// Safety Constraints Module for FEMA Compliance and Emergency Handling
/// Implements STAMP safety constraints with type-safe operations.
///
/// WHAT: Centralized safety constraint verification and emergency response
/// WHY: Ensures SC-EMR-*, SC-PRF-*, SC-SEC-* compliance across CEPAF
/// CONSTRAINTS:
///   - FEMA-FSH-001: Pattern match failures prevented via exhaustive patterns
///   - FEMA-FSH-002: Unhandled exceptions captured via Result type
///   - FEMA-FSH-005: Emergency stop <5s (SC-EMR-057)
///   - SC-PRF-050: Response latency <50ms
///   - SC-PRF-055: No blocking operations >50ms
///
/// TDG Compliance:
///   - TDG-FSH-050: All safety operations use async pipelines
///   - TDG-FSH-054: Timeout behavior tested
///
/// AOR Compliance:
///   - AOR-FSH-042: All safety thresholds use type-safe units
module SafetyConstraints =

    // =========================================================================
    // SAFETY THRESHOLD CONSTANTS (Type-Safe Units)
    // =========================================================================

    /// SC-EMR-057: Emergency stop must complete within 5 seconds
    let emergencyStopThreshold = SafetyThresholds.emergencyStopMax

    /// SC-PRF-050: Response latency must be under 50ms
    let responseLatencyThreshold = SafetyThresholds.responseLatencyMax

    /// SC-PRF-055: No blocking operations over 50ms
    let blockingThreshold = SafetyThresholds.blockingMax

    /// SC-AGT-017: Agent efficiency must be above 90%
    let efficiencyThreshold = Efficiency.threshold

    // =========================================================================
    // SAFETY CHECK RESULTS
    // =========================================================================

    /// Result of a safety constraint check
    type SafetyCheckResult = {
        ConstraintId: string
        Description: string
        Passed: bool
        Value: string
        Threshold: string
        Severity: string
        Timestamp: DateTimeOffset
    }

    /// Aggregate safety report
    type SafetyReport = {
        TotalChecks: int
        PassedChecks: int
        FailedChecks: int
        CriticalFailures: int
        Results: SafetyCheckResult list
        OverallCompliant: bool
        GeneratedAt: DateTimeOffset
    }

    // =========================================================================
    // EMERGENCY STOP INFRASTRUCTURE (FEMA-FSH-005, SC-EMR-057)
    // =========================================================================

    /// Emergency stop state
    type EmergencyState =
        | Normal
        | EmergencyActive of reason: string * activatedAt: DateTimeOffset
        | RecoveryMode of reason: string * recoveryStarted: DateTimeOffset

    /// Emergency stop handler result
    type EmergencyStopResult = {
        Succeeded: bool
        ElapsedMs: int64
        WithinThreshold: bool  // <5s per SC-EMR-057
        Message: string
        AffectedSystems: string list
    }

    /// Mutable emergency state (thread-safe via lock)
    let mutable private currentEmergencyState = Normal
    let private emergencyLock = obj()

    /// Execute emergency stop with timing validation (SC-EMR-057)
    let executeEmergencyStop (reason: string) (stopAction: unit -> Async<Result<string list, string>>) : Async<EmergencyStopResult> =
        async {
            let stopwatch = Stopwatch.StartNew()

            lock emergencyLock (fun () ->
                currentEmergencyState <- EmergencyActive (reason, DateTimeOffset.UtcNow)
            )

            let! result = stopAction ()
            stopwatch.Stop()

            let elapsedMs = stopwatch.ElapsedMilliseconds
            let withinThreshold = elapsedMs < int64 (int emergencyStopThreshold * 1000)

            match result with
            | Ok affectedSystems ->
                return {
                    Succeeded = true
                    ElapsedMs = elapsedMs
                    WithinThreshold = withinThreshold
                    Message = if withinThreshold
                              then sprintf "Emergency stop completed in %dms (within SC-EMR-057 threshold)" elapsedMs
                              else sprintf "WARNING: Emergency stop took %dms (exceeds SC-EMR-057 threshold of %ds)" elapsedMs (int emergencyStopThreshold)
                    AffectedSystems = affectedSystems
                }
            | Error err ->
                return {
                    Succeeded = false
                    ElapsedMs = elapsedMs
                    WithinThreshold = withinThreshold
                    Message = sprintf "Emergency stop failed: %s" err
                    AffectedSystems = []
                }
        }

    /// Get current emergency state
    let getEmergencyState () = currentEmergencyState

    /// Begin recovery from emergency
    let beginRecovery (reason: string) =
        lock emergencyLock (fun () ->
            currentEmergencyState <- RecoveryMode (reason, DateTimeOffset.UtcNow)
        )

    /// Clear emergency state (return to normal)
    let clearEmergency () =
        lock emergencyLock (fun () ->
            currentEmergencyState <- Normal
        )

    // =========================================================================
    // LATENCY MONITORING (SC-PRF-050, SC-PRF-055)
    // =========================================================================

    /// Measure operation latency and check against threshold
    let measureLatency (thresholdMs: int<response_ms>) (operation: unit -> Async<'T>) : Async<Result<'T * int64, string>> =
        async {
            let stopwatch = Stopwatch.StartNew()
            try
                let! result = operation ()
                stopwatch.Stop()
                let elapsedMs = stopwatch.ElapsedMilliseconds

                if elapsedMs <= int64 (int thresholdMs) then
                    return Ok (result, elapsedMs)
                else
                    return Error (sprintf "SC-PRF-050 VIOLATION: Operation took %dms, exceeds %dms threshold" elapsedMs (int thresholdMs))
            with ex ->
                stopwatch.Stop()
                return Error (sprintf "Operation failed after %dms: %s" stopwatch.ElapsedMilliseconds ex.Message)
        }

    /// Measure operation and return with timing metadata
    let measureWithTiming (operation: unit -> Async<'T>) : Async<{| Result: 'T; ElapsedMs: int64; MeetsResponseThreshold: bool; MeetsBlockingThreshold: bool |}> =
        async {
            let stopwatch = Stopwatch.StartNew()
            let! result = operation ()
            stopwatch.Stop()
            let elapsedMs = stopwatch.ElapsedMilliseconds

            return {|
                Result = result
                ElapsedMs = elapsedMs
                MeetsResponseThreshold = elapsedMs <= int64 (int responseLatencyThreshold)
                MeetsBlockingThreshold = elapsedMs <= int64 (int blockingThreshold)
            |}
        }

    // =========================================================================
    // CONSTRAINT VERIFICATION PIPELINES
    // =========================================================================

    /// Create a safety check result
    let private createCheckResult constraintId description passed value threshold severity =
        {
            ConstraintId = constraintId
            Description = description
            Passed = passed
            Value = value
            Threshold = threshold
            Severity = severity
            Timestamp = DateTimeOffset.UtcNow
        }

    /// Check emergency stop compliance (SC-EMR-057)
    let checkEmergencyStopCompliance (elapsedMs: int64) : SafetyCheckResult =
        let thresholdMs = int emergencyStopThreshold * 1000
        let passed = elapsedMs < int64 thresholdMs
        createCheckResult
            "SC-EMR-057"
            "Emergency stop must complete within 5 seconds"
            passed
            (sprintf "%dms" elapsedMs)
            (sprintf "%dms" thresholdMs)
            (if passed then "OK" else "CRITICAL")

    /// Check response latency compliance (SC-PRF-050)
    let checkResponseLatencyCompliance (elapsedMs: int64) : SafetyCheckResult =
        let thresholdMs = int responseLatencyThreshold
        let passed = elapsedMs <= int64 thresholdMs
        createCheckResult
            "SC-PRF-050"
            "Response latency must be under 50ms"
            passed
            (sprintf "%dms" elapsedMs)
            (sprintf "%dms" thresholdMs)
            (if passed then "OK" else "HIGH")

    /// Check blocking operation compliance (SC-PRF-055)
    let checkBlockingCompliance (elapsedMs: int64) : SafetyCheckResult =
        let thresholdMs = int blockingThreshold
        let passed = elapsedMs <= int64 thresholdMs
        createCheckResult
            "SC-PRF-055"
            "No blocking operations over 50ms"
            passed
            (sprintf "%dms" elapsedMs)
            (sprintf "%dms" thresholdMs)
            (if passed then "OK" else "HIGH")

    /// Check efficiency compliance (SC-AGT-017)
    let checkEfficiencyCompliance (efficiency: float<efficiency>) : SafetyCheckResult =
        let passed = Efficiency.isCompliant efficiency
        let classification =
            match Efficiency.toFloat efficiency with
            | EfficiencyCompliant -> "COMPLIANT"
            | EfficiencyWarning -> "WARNING"
            | EfficiencyViolation -> "VIOLATION"
        createCheckResult
            "SC-AGT-017"
            "Agent efficiency must be above 90%"
            passed
            (sprintf "%.1f%%" (Efficiency.toFloat efficiency))
            (sprintf "%.0f%%" (Efficiency.toFloat efficiencyThreshold))
            classification

    /// Generate comprehensive safety report
    let generateSafetyReport (checks: SafetyCheckResult list) : SafetyReport =
        let passed = checks |> List.filter (fun c -> c.Passed) |> List.length
        let failed = checks |> List.filter (fun c -> not c.Passed) |> List.length
        let critical = checks |> List.filter (fun c -> c.Severity = "CRITICAL" && not c.Passed) |> List.length

        {
            TotalChecks = List.length checks
            PassedChecks = passed
            FailedChecks = failed
            CriticalFailures = critical
            Results = checks
            OverallCompliant = failed = 0
            GeneratedAt = DateTimeOffset.UtcNow
        }

    // =========================================================================
    // RECOVERY PROCEDURES (FEMA Section 5.5)
    // =========================================================================

    /// Recovery action based on error classification
    type RecoveryAction =
        | Retry of maxAttempts: int * baseDelayMs: int
        | GracefulDegradation of fallbackAction: string
        | EmergencyStop of reason: string
        | HumanIntervention of instructions: string

    /// Determine recovery action based on error classification
    let determineRecoveryAction (error: obj) (failureCount: int) : RecoveryAction =
        match error with
        | Transient when failureCount < 3 ->
            Retry (3, 100)
        | Transient ->
            GracefulDegradation "Switch to backup system"
        | Recoverable when failureCount < 5 ->
            Retry (2, 500)
        | Recoverable ->
            HumanIntervention "Manual review required - persistent recoverable error"
        | NonRecoverable ->
            EmergencyStop "Non-recoverable error detected"

    /// Execute recovery with error classification
    let executeRecoveryAsync (error: obj) (failureCount: int) (retryOperation: unit -> Async<Result<'T, string>>) : Async<Result<'T, string>> =
        let action = determineRecoveryAction error failureCount
        match action with
        | Retry (maxAttempts, baseDelayMs) ->
            let config = {
                Retry.defaultConfig with
                    MaxAttempts = maxAttempts
                    BaseDelayMs = baseDelayMs
            }
            Retry.retryAsyncResult config retryOperation
        | GracefulDegradation msg ->
            async { return Error (sprintf "Degraded mode: %s" msg) }
        | EmergencyStop reason ->
            async {
                let! _ = executeEmergencyStop reason (fun () -> async { return Ok [] })
                return Error (sprintf "Emergency stop executed: %s" reason)
            }
        | HumanIntervention instructions ->
            async { return Error (sprintf "Human intervention required: %s" instructions) }

    // =========================================================================
    // SAFETY ASSERTION HELPERS
    // =========================================================================

    /// Assert response time is within threshold (SC-PRF-050)
    let assertResponseTime (operationName: string) (elapsedMs: int64) : Result<unit, string> =
        if elapsedMs <= int64 (int responseLatencyThreshold) then
            Ok ()
        else
            Error (sprintf "SC-PRF-050 VIOLATION: %s took %dms (threshold: %dms)" operationName elapsedMs (int responseLatencyThreshold))

    /// Assert efficiency is compliant (SC-AGT-017)
    let assertEfficiency (agentId: string) (efficiency: float<efficiency>) : Result<unit, string> =
        if Efficiency.isCompliant efficiency then
            Ok ()
        else
            Error (sprintf "SC-AGT-017 VIOLATION: Agent %s efficiency %.1f%% below %.0f%% threshold"
                          agentId (Efficiency.toFloat efficiency) (Efficiency.toFloat efficiencyThreshold))

    /// Assert emergency stop time is within threshold (SC-EMR-057)
    let assertEmergencyStopTime (elapsedMs: int64) : Result<unit, string> =
        let thresholdMs = int emergencyStopThreshold * 1000
        if elapsedMs < int64 thresholdMs then
            Ok ()
        else
            Error (sprintf "SC-EMR-057 VIOLATION: Emergency stop took %dms (threshold: %dms)" elapsedMs thresholdMs)
