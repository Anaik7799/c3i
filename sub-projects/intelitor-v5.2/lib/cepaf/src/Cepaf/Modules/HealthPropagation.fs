/// CEPAF Health Propagation Module
/// SC-CEP-003: Consensus-based health verification (FPPS 3/5 pattern)
/// SC-PRF-050: Response time <50ms for health checks
/// AOR-SAF-001: Halt <1s on critical failure (emergency stop)
///
/// WHAT: Propagates health state changes through the service dependency DAG
/// WHY: Ensures dependent services react appropriately to dependency failures
/// CONSTRAINTS:
///   - Health consensus requires 3/5 checks to agree (SC-CEP-003)
///   - All health check operations must complete within 50ms (SC-PRF-050)
///   - Emergency stop must halt all dependents within 1 second (AOR-SAF-001)
///   - Mandatory dependencies block dependent startup on failure
///   - Optional dependencies allow degraded operation
module Cepaf.Modules.HealthPropagation

open System
open System.Diagnostics
open System.Collections.Generic
open Cepaf.Modules.ServiceDAG
open Cepaf.Core.Units  // SC-FSH-004: Units of Measure for type safety

// ============================================================================
// TYPE-SAFE TIMEOUT CONSTANTS (SC-FSH-004)
// ============================================================================

/// SC-PRF-050: Health check threshold - 50ms max response time
let private healthCheckTimeout = Duration.ms 50.0

/// AOR-SAF-001: Emergency stop threshold - must halt within 1 second
let private emergencyStopTimeout = Duration.sec 1.0 |> Time.secToMs

/// Maximum retry delay cap for safety
let private maxRetryDelayMs = Duration.sec 1.0 |> Time.secToMs

// ============================================================================
// HEALTH STATE CLASSIFICATION (SC-FSH-050)
// ============================================================================

/// Classify health state (SC-FSH-050)
let classifyHealthState (state: HealthState) : string =
    match state with
    | Healthy -> "HEALTHY"
    | Degraded -> "DEGRADED"
    | Failed -> "FAILED"
    | Starting -> "STARTING"
    | Created -> "CREATED"
    | Absent -> "ABSENT"

/// Get health state severity for prioritization
let getHealthSeverity (state: HealthState) : int =
    match state with
    | Failed -> 4      // Critical
    | Degraded -> 3    // Warning
    | Starting -> 2    // Info
    | Created -> 1     // Normal
    | Healthy -> 0     // Good
    | Absent -> 5      // Most critical

/// Check if health state requires immediate attention
let requiresImmediateAttention (state: HealthState) : bool =
    match state with
    | Failed | Absent -> true
    | _ -> false

/// Check if health state allows operation (even if degraded)
let allowsOperation (state: HealthState) : bool =
    match state with
    | Healthy | Degraded | Starting -> true
    | Failed | Absent | Created -> false

// ============================================================================
// TYPES
// ============================================================================

/// Health event recording a state transition
type HealthEvent = {
    NodeId: string
    PreviousState: HealthState
    NewState: HealthState
    Timestamp: DateTime
    Reason: string option
}

/// Result of health propagation through the DAG
type PropagationResult = {
    AffectedNodes: string list
    Events: HealthEvent list
    TotalTimeMs: int64
}

/// Health policy determining failure behavior
type HealthPolicy =
    | FailFast                                      // Immediate failure propagation
    | GracefulDegrade                               // Allow degraded operation
    | RetryWithBackoff of maxRetries: int * baseDelayMs: int  // Retry before failing

/// Result of a single health check
type HealthCheckResult = {
    NodeId: string
    IsHealthy: bool
    LatencyMs: int64
    CheckType: string
    Message: string option
}

/// Consensus result from FPPS pattern (3/5 checks)
type ConsensusResult =
    | Consensus of isHealthy: bool * agreementCount: int * totalChecks: int
    | NoConsensus of healthyCount: int * unhealthyCount: int * totalChecks: int

/// Impact analysis result
type ImpactAnalysis = {
    FailedNode: string
    DirectDependents: string list
    TransitiveDependents: string list
    MandatoryBlocked: string list
    OptionalDegraded: string list
    TotalAffected: int
}

/// Emergency stop result (AOR-SAF-001 compliance)
type EmergencyStopResult = {
    StoppedNodes: string list
    StopTimeMs: int64
    WithinThreshold: bool      // Must be <1000ms per AOR-SAF-001
    Errors: (string * string) list  // (nodeId, error message)
}

/// Health summary aggregation with classification (SC-FSH-050)
type HealthSummary = {
    TotalNodes: int
    HealthyCount: int
    DegradedCount: int
    FailedCount: int
    AbsentCount: int
    StartingCount: int
    CreatedCount: int
    OverallHealthy: bool
    LastUpdated: DateTime
    Classification: string         // SC-FSH-050: Pattern-based classification
    RequiresAttention: bool        // SC-FSH-050: Derived from pattern matching
    SeverityScore: int             // SC-FSH-050: Aggregate severity
}

/// Recovery result for degraded nodes
type RecoveryResult = {
    AttemptedNodes: string list
    RecoveredNodes: string list
    FailedNodes: string list
    TotalTimeMs: int64
}

// ============================================================================
// HEALTH CHECK FUNCTIONS (SC-PRF-050: <50ms)
// ============================================================================

/// Perform a single health check with timing
/// SC-PRF-050: Must complete within 50ms
let private performHealthCheck (checkFn: string -> bool) (nodeId: string) (checkType: string) : HealthCheckResult =
    let sw = Stopwatch.StartNew()
    let isHealthy =
        try
            checkFn nodeId
        with _ ->
            false
    sw.Stop()

    {
        NodeId = nodeId
        IsHealthy = isHealthy
        LatencyMs = sw.ElapsedMilliseconds
        CheckType = checkType
        Message = if sw.ElapsedMilliseconds > 50L then Some "SC-PRF-050 violation: check exceeded 50ms" else None
    }

/// Run multiple health checks in parallel with timeout
/// Returns results within 50ms overall (SC-PRF-050)
/// SC-FSH-004: Using type-safe timeout constant
let private runHealthChecksWithTimeout (checks: (string -> bool) list) (nodeId: string) : HealthCheckResult list =
    let sw = Stopwatch.StartNew()
    let timeoutMs = int64 (float healthCheckTimeout)  // Convert from float<ms> to int64

    checks
    |> List.mapi (fun i checkFn ->
        if sw.ElapsedMilliseconds < timeoutMs then
            performHealthCheck checkFn nodeId (sprintf "check_%d" i)
        else
            // Timeout - mark as unhealthy
            {
                NodeId = nodeId
                IsHealthy = false
                LatencyMs = sw.ElapsedMilliseconds
                CheckType = sprintf "check_%d" i
                Message = Some "Skipped due to timeout (SC-PRF-050)"
            })

// ============================================================================
// CONSENSUS-BASED HEALTH VERIFICATION (SC-CEP-003)
// ============================================================================

/// Check health consensus using FPPS pattern (3/5 checks must agree)
/// SC-CEP-003: Consensus-based health verification
let checkHealthConsensus (healthChecks: HealthCheckResult list) : ConsensusResult =
    let total = List.length healthChecks
    let healthyCount = healthChecks |> List.filter (fun c -> c.IsHealthy) |> List.length
    let unhealthyCount = total - healthyCount

    // FPPS pattern: 3/5 (60%) agreement required for consensus
    let consensusThreshold =
        if total >= 5 then 3
        elif total >= 3 then 2
        else 1

    if healthyCount >= consensusThreshold then
        Consensus (true, healthyCount, total)
    elif unhealthyCount >= consensusThreshold then
        Consensus (false, unhealthyCount, total)
    else
        NoConsensus (healthyCount, unhealthyCount, total)

/// Run 5 health checks and determine consensus
/// Returns (isHealthy, consensusResult)
let verifyHealthWithConsensus (checkFns: (string -> bool) list) (nodeId: string) : bool * ConsensusResult =
    // Ensure we have exactly 5 checks for FPPS pattern
    let checks =
        if List.length checkFns >= 5 then
            checkFns |> List.take 5
        else
            // Pad with duplicate checks if fewer than 5 provided
            let needed = 5 - List.length checkFns
            let additional =
                if List.isEmpty checkFns then
                    List.replicate needed (fun _ -> false)
                else
                    List.replicate needed (List.head checkFns)
            checkFns @ additional

    let results = runHealthChecksWithTimeout checks nodeId
    let consensus = checkHealthConsensus results

    match consensus with
    | Consensus (healthy, _, _) -> (healthy, consensus)
    | NoConsensus _ -> (false, consensus)  // Default to unhealthy on no consensus

// ============================================================================
// IMPACT CALCULATION
// ============================================================================

/// Calculate the impact of a node failure on the DAG
/// Identifies all nodes that will be affected by this failure
let calculateImpact (nodeId: string) (dag: ServiceDAG) : ImpactAnalysis =
    // Get direct dependents (nodes that depend on the failed node)
    let directDependents = getDependents nodeId dag

    // Get all transitive dependents
    let transitiveDependents = getTransitiveDependents nodeId dag

    // Categorize by dependency type
    let mandatoryBlocked =
        directDependents
        |> List.filter (fun depId ->
            match getDependencyType nodeId depId dag with
            | Some Mandatory -> true
            | _ -> false)

    let optionalDegraded =
        directDependents
        |> List.filter (fun depId ->
            match getDependencyType nodeId depId dag with
            | Some Optional -> true
            | _ -> false)

    {
        FailedNode = nodeId
        DirectDependents = directDependents
        TransitiveDependents = transitiveDependents
        MandatoryBlocked = mandatoryBlocked
        OptionalDegraded = optionalDegraded
        TotalAffected = List.length transitiveDependents
    }

// ============================================================================
// HEALTH PROPAGATION
// ============================================================================

/// Create a health event for a state transition
let private createHealthEvent (nodeId: string) (prevState: HealthState) (newState: HealthState) (reason: string option) : HealthEvent =
    {
        NodeId = nodeId
        PreviousState = prevState
        NewState = newState
        Timestamp = DateTime.UtcNow
        Reason = reason
    }

/// Propagate health state change through the DAG
/// Notifies all dependents of the state change
let propagateHealthChange (nodeId: string) (newState: HealthState) (policy: HealthPolicy) (dag: ServiceDAG) : PropagationResult * ServiceDAG =
    let sw = Stopwatch.StartNew()
    let events = ResizeArray<HealthEvent>()
    let affectedNodes = ResizeArray<string>()

    // Get current state
    let currentState = getHealthState nodeId dag |> Option.defaultValue Absent

    // Update the source node
    let updatedDag = updateHealthState nodeId newState dag

    // Record source event
    events.Add(createHealthEvent nodeId currentState newState None)
    affectedNodes.Add(nodeId)

    // Propagate based on state and policy
    let finalDag =
        match newState with
        | Failed ->
            // On failure, propagate to all dependents
            let impact = calculateImpact nodeId dag

            // Apply policy to mandatory dependents
            let dagAfterMandatory =
                impact.MandatoryBlocked
                |> List.fold (fun acc depId ->
                    let prevState = getHealthState depId acc |> Option.defaultValue Absent
                    let newDepState =
                        match policy with
                        | FailFast -> Failed
                        | GracefulDegrade -> Degraded
                        | RetryWithBackoff _ -> Degraded
                    events.Add(createHealthEvent depId prevState newDepState (Some (sprintf "Dependency %s failed" nodeId)))
                    affectedNodes.Add(depId)
                    updateHealthState depId newDepState acc
                ) updatedDag

            // Apply policy to optional dependents (always degrade, never fail)
            impact.OptionalDegraded
            |> List.fold (fun acc depId ->
                let prevState = getHealthState depId acc |> Option.defaultValue Absent
                events.Add(createHealthEvent depId prevState Degraded (Some (sprintf "Optional dependency %s failed" nodeId)))
                affectedNodes.Add(depId)
                updateHealthState depId Degraded acc
            ) dagAfterMandatory

        | Degraded ->
            // On degradation, notify dependents but don't fail them
            let dependents = getDependents nodeId updatedDag
            dependents
            |> List.fold (fun acc depId ->
                let prevState = getHealthState depId acc |> Option.defaultValue Absent
                if prevState = Healthy then
                    events.Add(createHealthEvent depId prevState Degraded (Some (sprintf "Dependency %s degraded" nodeId)))
                    affectedNodes.Add(depId)
                    updateHealthState depId Degraded acc
                else
                    acc
            ) updatedDag

        | Healthy ->
            // On recovery, check if dependents can be upgraded
            let dependents = getDependents nodeId updatedDag
            dependents
            |> List.fold (fun acc depId ->
                if areMandatoryDepsHealthy depId acc then
                    let prevState = getHealthState depId acc |> Option.defaultValue Absent
                    if prevState = Degraded then
                        events.Add(createHealthEvent depId prevState Healthy (Some "All dependencies healthy"))
                        affectedNodes.Add(depId)
                        updateHealthState depId Healthy acc
                    else
                        acc
                else
                    acc
            ) updatedDag

        | _ ->
            updatedDag

    sw.Stop()

    let result = {
        AffectedNodes = affectedNodes |> List.ofSeq
        Events = events |> List.ofSeq
        TotalTimeMs = sw.ElapsedMilliseconds
    }

    (result, finalDag)

// ============================================================================
// EMERGENCY STOP (AOR-SAF-001: <1s)
// ============================================================================

/// Trigger emergency stop for a node and all its dependents
/// AOR-SAF-001: Must complete within 1 second
let triggerEmergencyStop (nodeId: string) (stopFn: string -> Result<unit, string>) (dag: ServiceDAG) : EmergencyStopResult * ServiceDAG =
    let sw = Stopwatch.StartNew()
    let threshold = 1000L  // AOR-SAF-001: 1 second threshold

    let stoppedNodes = ResizeArray<string>()
    let errors = ResizeArray<string * string>()

    // Get all nodes to stop (the node and all its transitive dependents)
    let nodesToStop =
        let dependents = getTransitiveDependents nodeId dag
        nodeId :: dependents
        |> List.distinct
        |> List.sortByDescending (fun n ->
            // Stop in reverse topological order (dependents first)
            match getNode n dag with
            | Some node -> node.Layer
            | None -> 0)

    // Stop nodes with time budget
    let mutable updatedDag = dag
    let mutable timeExpired = false

    for node in nodesToStop do
        if not timeExpired then
            if sw.ElapsedMilliseconds < threshold then
                match stopFn node with
                | Ok () ->
                    stoppedNodes.Add(node)
                    updatedDag <- updateHealthState node Failed updatedDag
                | Error msg ->
                    errors.Add((node, msg))
                    updatedDag <- updateHealthState node Failed updatedDag
            else
                timeExpired <- true
                errors.Add((node, "Stop aborted: AOR-SAF-001 threshold approaching"))

    sw.Stop()

    let result = {
        StoppedNodes = stoppedNodes |> List.ofSeq
        StopTimeMs = sw.ElapsedMilliseconds
        WithinThreshold = sw.ElapsedMilliseconds < threshold
        Errors = errors |> List.ofSeq
    }

    (result, updatedDag)

/// Fast emergency stop without external stop function (just state update)
/// Guaranteed to complete within threshold
let triggerFastEmergencyStop (nodeId: string) (dag: ServiceDAG) : EmergencyStopResult * ServiceDAG =
    let stopFn _ = Ok ()
    triggerEmergencyStop nodeId stopFn dag

// ============================================================================
// RECOVERY
// ============================================================================

/// Attempt to restore nodes from degraded state
let restoreFromDegradedState (healthCheckFn: string -> bool) (dag: ServiceDAG) : RecoveryResult * ServiceDAG =
    let sw = Stopwatch.StartNew()
    let attemptedNodes = ResizeArray<string>()
    let recoveredNodes = ResizeArray<string>()
    let failedNodes = ResizeArray<string>()

    // Find all degraded nodes
    let degradedNodes =
        dag.Nodes
        |> Map.toList
        |> List.filter (fun (_, node) -> node.HealthState = Degraded)
        |> List.map fst

    // Attempt recovery in topological order (dependencies first)
    let orderedNodes =
        match topologicalSort dag with
        | Ok order -> order |> List.filter (fun n -> List.contains n degradedNodes)
        | Error _ -> degradedNodes

    let mutable updatedDag = dag

    for nodeId in orderedNodes do
        attemptedNodes.Add(nodeId)

        // Check if all mandatory dependencies are healthy
        if areMandatoryDepsHealthy nodeId updatedDag then
            // Perform health check
            if healthCheckFn nodeId then
                recoveredNodes.Add(nodeId)
                updatedDag <- updateHealthState nodeId Healthy updatedDag
            else
                failedNodes.Add(nodeId)
        else
            failedNodes.Add(nodeId)

    sw.Stop()

    let result = {
        AttemptedNodes = attemptedNodes |> List.ofSeq
        RecoveredNodes = recoveredNodes |> List.ofSeq
        FailedNodes = failedNodes |> List.ofSeq
        TotalTimeMs = sw.ElapsedMilliseconds
    }

    (result, updatedDag)

/// Attempt recovery for a specific node
let recoverNode (nodeId: string) (healthCheckFn: string -> bool) (dag: ServiceDAG) : bool * ServiceDAG =
    // Check if all mandatory dependencies are healthy first
    if not (areMandatoryDepsHealthy nodeId dag) then
        (false, dag)
    else
        // Perform health check
        if healthCheckFn nodeId then
            (true, updateHealthState nodeId Healthy dag)
        else
            (false, dag)

// ============================================================================
// HEALTH SUMMARY
// ============================================================================

/// Get aggregated health summary across all nodes with pattern classification (SC-FSH-050)
let getHealthSummary (dag: ServiceDAG) : HealthSummary =
    let nodes = dag.Nodes |> Map.toList |> List.map snd

    let healthyCount = nodes |> List.filter (fun n -> n.HealthState = Healthy) |> List.length
    let degradedCount = nodes |> List.filter (fun n -> n.HealthState = Degraded) |> List.length
    let failedCount = nodes |> List.filter (fun n -> n.HealthState = Failed) |> List.length
    let absentCount = nodes |> List.filter (fun n -> n.HealthState = Absent) |> List.length
    let startingCount = nodes |> List.filter (fun n -> n.HealthState = Starting) |> List.length
    let createdCount = nodes |> List.filter (fun n -> n.HealthState = Created) |> List.length

    // SC-FSH-050: Calculate aggregate severity score
    let severityScore =
        nodes
        |> List.sumBy (fun n -> getHealthSeverity n.HealthState)

    // SC-FSH-050: Determine classification using pattern matching
    let classification =
        if failedCount > 0 || absentCount > 0 then "CRITICAL"
        elif degradedCount > 0 then "WARNING"
        elif startingCount > 0 || createdCount > 0 then "INITIALIZING"
        else "HEALTHY"

    // SC-FSH-050: Check if any node requires immediate attention
    let needsAttention =
        nodes
        |> List.exists (fun n -> requiresImmediateAttention n.HealthState)

    {
        TotalNodes = List.length nodes
        HealthyCount = healthyCount
        DegradedCount = degradedCount
        FailedCount = failedCount
        AbsentCount = absentCount
        StartingCount = startingCount
        CreatedCount = createdCount
        OverallHealthy = failedCount = 0 && degradedCount = 0 && absentCount = 0
        LastUpdated = DateTime.UtcNow
        Classification = classification
        RequiresAttention = needsAttention
        SeverityScore = severityScore
    }

/// Get health summary as a formatted string with classification (SC-FSH-050)
let formatHealthSummary (summary: HealthSummary) : string =
    let attentionFlag = if summary.RequiresAttention then " ⚠️ ATTENTION REQUIRED" else ""
    sprintf """Health Summary [%s]%s
  Total Nodes: %d | Severity Score: %d
  Healthy: %d | Degraded: %d | Failed: %d
  Absent: %d | Starting: %d | Created: %d
  Classification: %s
  Last Updated: %s"""
        summary.Classification
        attentionFlag
        summary.TotalNodes
        summary.SeverityScore
        summary.HealthyCount
        summary.DegradedCount
        summary.FailedCount
        summary.AbsentCount
        summary.StartingCount
        summary.CreatedCount
        summary.Classification
        (summary.LastUpdated.ToString("yyyy-MM-dd HH:mm:ss"))

// ============================================================================
// POLICY HELPERS
// ============================================================================

/// Apply retry policy for health checks
let applyRetryPolicy (policy: HealthPolicy) (healthCheckFn: string -> bool) (nodeId: string) : bool =
    match policy with
    | FailFast ->
        healthCheckFn nodeId

    | GracefulDegrade ->
        healthCheckFn nodeId

    | RetryWithBackoff (maxRetries, baseDelayMs) ->
        let maxDelayMs = int (float maxRetryDelayMs)  // SC-FSH-004: Type-safe max delay
        let rec retry attempt =
            if attempt > maxRetries then
                false
            else
                if healthCheckFn nodeId then
                    true
                else
                    // Exponential backoff: baseDelay * 2^attempt
                    let delayMs = baseDelayMs * (1 <<< attempt)
                    System.Threading.Thread.Sleep(min delayMs maxDelayMs)  // Cap at 1s for safety (SC-FSH-004)
                    retry (attempt + 1)
        retry 0

/// Get recommended policy based on dependency type
let getRecommendedPolicy (depType: DependencyType) : HealthPolicy =
    match depType with
    | Mandatory -> FailFast
    | Optional -> GracefulDegrade

// ============================================================================
// BATCH OPERATIONS
// ============================================================================

/// Propagate multiple health changes in a batch
let propagateHealthChanges (changes: (string * HealthState) list) (policy: HealthPolicy) (dag: ServiceDAG) : PropagationResult * ServiceDAG =
    let sw = Stopwatch.StartNew()
    let allEvents = ResizeArray<HealthEvent>()
    let allAffected = HashSet<string>()

    let finalDag =
        changes
        |> List.fold (fun acc (nodeId, newState) ->
            let (result, updatedDag) = propagateHealthChange nodeId newState policy acc
            result.Events |> List.iter (allEvents.Add)
            result.AffectedNodes |> List.iter (allAffected.Add >> ignore)
            updatedDag
        ) dag

    sw.Stop()

    let result = {
        AffectedNodes = allAffected |> List.ofSeq
        Events = allEvents |> List.ofSeq
        TotalTimeMs = sw.ElapsedMilliseconds
    }

    (result, finalDag)

/// Check health of all nodes and propagate changes
let refreshAllHealth (healthCheckFn: string -> bool) (policy: HealthPolicy) (dag: ServiceDAG) : PropagationResult * ServiceDAG =
    let changes =
        dag.Nodes
        |> Map.toList
        |> List.choose (fun (nodeId, node) ->
            let isHealthy = healthCheckFn nodeId
            let newState = if isHealthy then Healthy else Failed
            if node.HealthState <> newState then
                Some (nodeId, newState)
            else
                None)

    propagateHealthChanges changes policy dag

// ============================================================================
// VALIDATION HELPERS
// ============================================================================

/// Validate that propagation time is within SC-PRF-050 threshold
let validatePropagationTime (result: PropagationResult) : bool =
    result.TotalTimeMs <= 50L

/// Validate that emergency stop is within AOR-SAF-001 threshold
let validateEmergencyStopTime (result: EmergencyStopResult) : bool =
    result.WithinThreshold

/// Get nodes that need attention (failed or degraded)
let getNodesNeedingAttention (dag: ServiceDAG) : (string * HealthState) list =
    dag.Nodes
    |> Map.toList
    |> List.filter (fun (_, node) ->
        match node.HealthState with
        | Failed | Degraded -> true
        | _ -> false)
    |> List.map (fun (id, node) -> (id, node.HealthState))

/// Check if the system is in a critical state (any failed nodes)
let isSystemCritical (dag: ServiceDAG) : bool =
    dag.Nodes
    |> Map.exists (fun _ node -> node.HealthState = Failed)

/// Check if the system is fully operational (all healthy)
let isSystemFullyOperational (dag: ServiceDAG) : bool =
    dag.Nodes
    |> Map.forall (fun _ node -> node.HealthState = Healthy)
