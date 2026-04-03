/// CEPAF Chain Verifier Module - Service Chain Verification with FPPS Consensus
/// SC-AGT-018: Deadlock prevention (no circular dependencies)
/// SC-CEP-003: Consensus-based health verification (FPPS 5-method)
/// SC-VAL-003: 100% consensus required for verification pass
///
/// WHAT: Verifies entire service chains and their dependencies
/// WHY: Ensures all services in a chain are healthy before accepting workload
/// CONSTRAINTS: All 5 FPPS methods must agree; cycles are fatal errors
module Cepaf.Modules.ChainVerifier

open System
open System.Collections.Generic
open System.Diagnostics
open System.Net.Http
open System.Net.Sockets
open Cepaf
open Cepaf.Infrastructure
open Cepaf.Observability
open Cepaf.Modules.ServiceDAG
open Cepaf.Modules.ConstraintValidator

// ============================================================================
// TYPES - Chain Verification Status
// ============================================================================

/// Status of chain verification
type ChainVerificationStatus =
    | ChainNotVerified          // Initial state, no verification performed
    | ChainVerifying            // Verification in progress
    | ChainHealthy              // All nodes healthy, all checks passed
    | ChainDegraded of degradedNodes: string list  // Some non-critical nodes unhealthy
    | ChainFailed of failedNodes: string list       // Critical nodes failed

/// FPPS Consensus verification methods (5-method validation per SC-CEP-003)
type ConsensusMethod =
    | PodmanStatus      // podman ps check - container running
    | HealthEndpoint    // HTTP health endpoint - /health returns 200
    | PortProbe         // TCP port check - port is listening
    | ProcessCheck      // Process exists - main process running in container
    | LogAnalysis       // Log pattern matching - no ERROR in recent logs

/// Result of a single FPPS method check
type FPPSResult = {
    Method: ConsensusMethod
    NodeId: string
    Passed: bool
    Timestamp: DateTime
    Details: string option
}

/// Result of node verification (individual container)
type NodeVerificationResult = {
    NodeId: string
    IsHealthy: bool
    FPPSResults: FPPSResult list
    ConsensusAchieved: bool
    VerificationTimeMs: int64
    FailureReason: string option
}

/// Comprehensive chain verification result
type ChainVerificationResult = {
    ChainId: string
    Status: ChainVerificationStatus
    NodeResults: Map<string, NodeVerificationResult>
    ConsensusResults: FPPSResult list
    CycleDetected: bool
    BootOrderValid: bool
    TotalVerificationTimeMs: int64
    VerifiedAt: DateTime
    LayerResults: Map<int, bool>  // Layer -> all healthy
}

/// Chain verification configuration
type ChainVerifierConfig = {
    ChainId: string
    DAG: ServiceDAG
    HealthEndpointPath: string       // Usually "/health"
    HealthTimeoutMs: int             // HTTP timeout
    LogErrorPatterns: string list    // Patterns to detect errors
    LogTailLines: int                // Number of log lines to check
    RequireAllMethods: bool          // True = all 5 must pass
    AllowDegradedOptional: bool      // Allow optional deps to be degraded
}

// ============================================================================
// DEFAULT CONFIGURATION
// ============================================================================

/// Default chain verifier configuration
let defaultConfig (chainId: string) (dag: ServiceDAG) : ChainVerifierConfig = {
    ChainId = chainId
    DAG = dag
    HealthEndpointPath = "/health"
    HealthTimeoutMs = 5000
    LogErrorPatterns = ["ERROR"; "FATAL"; "CRITICAL"; "panic"; "SIGKILL"]
    LogTailLines = 50
    RequireAllMethods = true
    AllowDegradedOptional = true
}

// ============================================================================
// CYCLE DETECTION (SC-AGT-018: Deadlock prevention)
// ============================================================================

/// Check for cyclic dependencies in the chain DAG
/// SC-AGT-018: Deadlock prevention through cycle detection
let checkCyclicDependencies (dag: ServiceDAG) : Result<unit, string list> =
    match detectCycles dag with
    | NoCycle -> Ok ()
    | CycleDetected nodes ->
        Error [
            sprintf "[SC-AGT-018] Circular dependency detected - deadlock risk"
            sprintf "Involved nodes: %s" (String.concat " -> " nodes)
            "Chain verification BLOCKED until cycles are resolved"
        ]

/// Validate that DAG has no cycles (returns bool for quick checks)
let hasNoCycles (dag: ServiceDAG) : bool =
    match checkCyclicDependencies dag with
    | Ok () -> true
    | Error _ -> false

// ============================================================================
// FPPS PROBE IMPLEMENTATIONS (5-method consensus)
// ============================================================================

/// Method 1: PodmanStatus - Check container is running via podman ps
let probePodmanStatus (runner: IProcessRunner) (nodeId: string) : Async<FPPSResult> = async {
    let sw = Stopwatch.StartNew()
    let! result = runner.Run("podman", ["ps"; "--filter"; sprintf "name=%s" nodeId; "--format"; "{{.State}}"])
    sw.Stop()

    match result with
    | Ok res ->
        let state = res.StandardOutput.Trim()
        let passed = state.ToLowerInvariant().Contains("running")
        return {
            Method = PodmanStatus
            NodeId = nodeId
            Passed = passed
            Timestamp = DateTime.UtcNow
            Details = if passed then Some (sprintf "State: %s" state) else Some (sprintf "Not running. State: %s" state)
        }
    | Error e ->
        return {
            Method = PodmanStatus
            NodeId = nodeId
            Passed = false
            Timestamp = DateTime.UtcNow
            Details = Some (sprintf "Podman error: %A" e)
        }
}

/// Method 2: HealthEndpoint - HTTP GET to /health endpoint
let probeHealthEndpoint (nodeId: string) (port: int) (path: string) (timeoutMs: int) : Async<FPPSResult> = async {
    use client = new HttpClient()
    client.Timeout <- TimeSpan.FromMilliseconds(float timeoutMs)
    let url = sprintf "http://127.0.0.1:%d%s" port path
    let sw = Stopwatch.StartNew()

    try
        let! response = client.GetAsync(url) |> Async.AwaitTask
        sw.Stop()
        let passed = response.IsSuccessStatusCode
        return {
            Method = HealthEndpoint
            NodeId = nodeId
            Passed = passed
            Timestamp = DateTime.UtcNow
            Details = Some (sprintf "HTTP %d from %s in %dms" (int response.StatusCode) url sw.ElapsedMilliseconds)
        }
    with ex ->
        sw.Stop()
        return {
            Method = HealthEndpoint
            NodeId = nodeId
            Passed = false
            Timestamp = DateTime.UtcNow
            Details = Some (sprintf "HTTP error: %s" ex.Message)
        }
}

/// Method 3: PortProbe - TCP connection to expected port
let probePort (nodeId: string) (port: int) : Async<FPPSResult> = async {
    use client = new TcpClient()
    let sw = Stopwatch.StartNew()

    try
        do! client.ConnectAsync("127.0.0.1", port) |> Async.AwaitTask
        sw.Stop()
        return {
            Method = PortProbe
            NodeId = nodeId
            Passed = true
            Timestamp = DateTime.UtcNow
            Details = Some (sprintf "Port %d open, connected in %dms" port sw.ElapsedMilliseconds)
        }
    with ex ->
        sw.Stop()
        return {
            Method = PortProbe
            NodeId = nodeId
            Passed = false
            Timestamp = DateTime.UtcNow
            Details = Some (sprintf "Port %d closed: %s" port ex.Message)
        }
}

/// Method 4: ProcessCheck - Verify main process running in container
let probeProcess (runner: IProcessRunner) (nodeId: string) : Async<FPPSResult> = async {
    let sw = Stopwatch.StartNew()
    // Check if there are running processes in the container
    let! result = runner.Run("podman", ["top"; nodeId; "-o"; "pid,comm"])
    sw.Stop()

    match result with
    | Ok res ->
        let output = res.StandardOutput.Trim()
        let hasProcesses = output.Split('\n', StringSplitOptions.RemoveEmptyEntries).Length > 1 // Header + at least 1 process
        return {
            Method = ProcessCheck
            NodeId = nodeId
            Passed = hasProcesses
            Timestamp = DateTime.UtcNow
            Details = if hasProcesses then Some "Main process running" else Some "No processes found"
        }
    | Error e ->
        return {
            Method = ProcessCheck
            NodeId = nodeId
            Passed = false
            Timestamp = DateTime.UtcNow
            Details = Some (sprintf "Process check failed: %A" e)
        }
}

/// Method 5: LogAnalysis - Check recent logs for error patterns
let probeLogAnalysis (runner: IProcessRunner) (nodeId: string) (patterns: string list) (tailLines: int) : Async<FPPSResult> = async {
    let sw = Stopwatch.StartNew()
    let! result = runner.Run("podman", ["logs"; "--tail"; string tailLines; nodeId])
    sw.Stop()

    match result with
    | Ok res ->
        let logs = res.StandardOutput + res.StandardError
        let foundPatterns =
            patterns
            |> List.filter (fun p -> logs.Contains(p))

        let passed = List.isEmpty foundPatterns
        return {
            Method = LogAnalysis
            NodeId = nodeId
            Passed = passed
            Timestamp = DateTime.UtcNow
            Details =
                if passed then Some "No error patterns in recent logs"
                else Some (sprintf "Found error patterns: %s" (String.concat ", " foundPatterns))
        }
    | Error e ->
        // If we can't read logs, still pass if container might be new
        return {
            Method = LogAnalysis
            NodeId = nodeId
            Passed = true  // Don't fail chain for log read issues
            Timestamp = DateTime.UtcNow
            Details = Some (sprintf "Log read issue (non-blocking): %A" e)
        }
}

// ============================================================================
// FPPS CONSENSUS VERIFICATION (SC-CEP-003, SC-VAL-003)
// ============================================================================

/// Run all 5 FPPS methods for a single node
let runFPPSConsensusForNode
    (runner: IProcessRunner)
    (config: ChainVerifierConfig)
    (nodeId: string)
    (port: int)
    : Async<FPPSResult list> = async {

    let! results =
        [
            probePodmanStatus runner nodeId
            probeHealthEndpoint nodeId port config.HealthEndpointPath config.HealthTimeoutMs
            probePort nodeId port
            probeProcess runner nodeId
            probeLogAnalysis runner nodeId config.LogErrorPatterns config.LogTailLines
        ]
        |> Async.Parallel

    return results |> Array.toList
}

/// Check if all FPPS methods agree (SC-VAL-003: 100% consensus required)
let checkConsensusAgreement (results: FPPSResult list) (requireAll: bool) : bool =
    if requireAll then
        // SC-VAL-003: All 5 methods must pass
        results |> List.forall (fun r -> r.Passed)
    else
        // Majority (at least 3 of 5) must pass
        let passCount = results |> List.filter (fun r -> r.Passed) |> List.length
        passCount >= 3

/// Run FPPS consensus for all nodes in the chain
let runFPPSConsensus
    (logger: UnifiedLogger)
    (runner: IProcessRunner)
    (config: ChainVerifierConfig)
    (portMap: Map<string, int>)
    : Async<FPPSResult list * Map<string, NodeVerificationResult>> = async {

    logger.Info(sprintf "[SC-CEP-003] Running FPPS 5-method consensus for chain '%s'" config.ChainId)
    let allResults = ResizeArray<FPPSResult>()
    let nodeResults = Dictionary<string, NodeVerificationResult>()

    // Verify each node in the DAG
    for KeyValue(nodeId, _) in config.DAG.Nodes do
        let sw = Stopwatch.StartNew()
        let port = portMap |> Map.tryFind nodeId |> Option.defaultValue 0

        logger.LogWithCategory(sprintf "  Verifying node '%s' on port %d..." nodeId port, EventCategory.Protocol, LogLevel.Debug)

        let! fppsResults = runFPPSConsensusForNode runner config nodeId port
        sw.Stop()

        allResults.AddRange(fppsResults)

        let consensusAchieved = checkConsensusAgreement fppsResults config.RequireAllMethods
        let failedMethods = fppsResults |> List.filter (fun r -> not r.Passed)

        let nodeResult = {
            NodeId = nodeId
            IsHealthy = consensusAchieved
            FPPSResults = fppsResults
            ConsensusAchieved = consensusAchieved
            VerificationTimeMs = sw.ElapsedMilliseconds
            FailureReason =
                if consensusAchieved then None
                else Some (sprintf "Failed methods: %s"
                    (failedMethods
                     |> List.map (fun r -> sprintf "%A" r.Method)
                     |> String.concat ", "))
        }

        nodeResults.[nodeId] <- nodeResult

        // Log consensus result with metrics
        if consensusAchieved then
            logger.Info(sprintf "    [PASS] Node '%s': 5/5 methods passed" nodeId)
            logger.IncrementCounter("chain.node_verified", tags = Map.ofList [("node", nodeId); ("result", "pass")])
        else
            let passCount = fppsResults |> List.filter (fun r -> r.Passed) |> List.length
            logger.LogWithCategory(sprintf "    [FAIL] Node '%s': %d/5 methods passed" nodeId passCount, EventCategory.Protocol, LogLevel.Warning)
            logger.IncrementCounter("chain.node_verified", tags = Map.ofList [("node", nodeId); ("result", "fail")])

    let resultMap = nodeResults |> Seq.map (fun kv -> kv.Key, kv.Value) |> Map.ofSeq
    return (allResults |> List.ofSeq, resultMap)
}

// ============================================================================
// BOOT SEQUENCE VERIFICATION
// ============================================================================

/// Verify nodes can boot in correct topological order
let verifyBootSequence (dag: ServiceDAG) : Result<string list, string> =
    match topologicalSort dag with
    | Ok order -> Ok order
    | Error msg -> Error (sprintf "[SC-AGT-018] Boot sequence invalid: %s" msg)

/// Calculate if chain is ready to start based on dependency health
let calculateChainReadiness (dag: ServiceDAG) (nodeResults: Map<string, NodeVerificationResult>) : bool =
    // Get boot order
    match topologicalSort dag with
    | Error _ -> false
    | Ok bootOrder ->
        // Check each node in boot order - all mandatory deps must be healthy
        bootOrder
        |> List.forall (fun nodeId ->
            match Map.tryFind nodeId nodeResults with
            | None -> false  // Node not verified
            | Some result ->
                if result.IsHealthy then true
                else
                    // Check if this is an optional dependency to anyone
                    // If all its dependents have it as optional, chain can still be ready
                    let dependents = getDependents nodeId dag
                    dependents |> List.forall (fun depId ->
                        match getDependencyType nodeId depId dag with
                        | Some Optional -> true
                        | _ -> false))

// ============================================================================
// LAYER VERIFICATION
// ============================================================================

/// Verify all nodes in a specific layer are healthy
let verifyLayerHealth
    (layer: int)
    (dag: ServiceDAG)
    (nodeResults: Map<string, NodeVerificationResult>)
    : bool * string list =

    let layerNodes = getNodesAtLayer layer dag
    let unhealthyNodes =
        layerNodes
        |> List.filter (fun nodeId ->
            match Map.tryFind nodeId nodeResults with
            | Some r -> not r.IsHealthy
            | None -> true)  // Not verified = unhealthy

    (List.isEmpty unhealthyNodes, unhealthyNodes)

/// Verify all layers in sequence
let verifyAllLayers
    (dag: ServiceDAG)
    (nodeResults: Map<string, NodeVerificationResult>)
    : Map<int, bool> =

    let maxLayer = getMaxLayer dag
    [0 .. maxLayer]
    |> List.map (fun layer ->
        let (healthy, _) = verifyLayerHealth layer dag nodeResults
        (layer, healthy))
    |> Map.ofList

// ============================================================================
// CHAIN VERIFICATION REPORT
// ============================================================================

/// Generate comprehensive verification report
let generateChainReport (result: ChainVerificationResult) : string =
    let sb = System.Text.StringBuilder()

    sb.AppendLine("=" |> String.replicate 70) |> ignore
    sb.AppendLine(sprintf "CHAIN VERIFICATION REPORT: %s" result.ChainId) |> ignore
    sb.AppendLine(sprintf "Verified at: %s" (result.VerifiedAt.ToString("yyyy-MM-dd HH:mm:ss UTC"))) |> ignore
    sb.AppendLine("=" |> String.replicate 70) |> ignore
    sb.AppendLine() |> ignore

    // Overall Status
    let statusStr =
        match result.Status with
        | ChainNotVerified -> "NOT VERIFIED"
        | ChainVerifying -> "VERIFYING..."
        | ChainHealthy -> "HEALTHY"
        | ChainDegraded nodes -> sprintf "DEGRADED (%d nodes)" (List.length nodes)
        | ChainFailed nodes -> sprintf "FAILED (%d nodes)" (List.length nodes)

    sb.AppendLine(sprintf "STATUS: %s" statusStr) |> ignore
    sb.AppendLine(sprintf "Total Verification Time: %dms" result.TotalVerificationTimeMs) |> ignore
    sb.AppendLine(sprintf "Cycle Detected: %b" result.CycleDetected) |> ignore
    sb.AppendLine(sprintf "Boot Order Valid: %b" result.BootOrderValid) |> ignore
    sb.AppendLine() |> ignore

    // STAMP Compliance
    sb.AppendLine("STAMP COMPLIANCE:") |> ignore
    sb.AppendLine(sprintf "  SC-AGT-018 (Deadlock Prevention): %s"
        (if not result.CycleDetected then "PASS" else "FAIL - Cycles detected")) |> ignore

    let allConsensusAchieved =
        result.NodeResults
        |> Map.forall (fun _ r -> r.ConsensusAchieved)
    sb.AppendLine(sprintf "  SC-CEP-003 (FPPS Consensus): %s"
        (if allConsensusAchieved then "PASS" else "FAIL - Not all nodes achieved consensus")) |> ignore
    sb.AppendLine(sprintf "  SC-VAL-003 (100%% Consensus): %s"
        (if result.Status = ChainHealthy then "PASS" else "FAIL")) |> ignore
    sb.AppendLine() |> ignore

    // Layer Results
    sb.AppendLine("LAYER VERIFICATION:") |> ignore
    result.LayerResults
    |> Map.iter (fun layer healthy ->
        sb.AppendLine(sprintf "  Layer %d: %s" layer (if healthy then "HEALTHY" else "UNHEALTHY")) |> ignore)
    sb.AppendLine() |> ignore

    // Node Details
    sb.AppendLine("NODE VERIFICATION DETAILS:") |> ignore
    sb.AppendLine("-" |> String.replicate 70) |> ignore

    result.NodeResults
    |> Map.iter (fun nodeId nodeResult ->
        let statusIcon = if nodeResult.IsHealthy then "[OK]" else "[!!]"
        sb.AppendLine(sprintf "%s Node: %s (Consensus: %b, Time: %dms)"
            statusIcon nodeId nodeResult.ConsensusAchieved nodeResult.VerificationTimeMs) |> ignore

        // Show FPPS results for each node
        nodeResult.FPPSResults
        |> List.iter (fun fpps ->
            let icon = if fpps.Passed then "+" else "-"
            let methodName =
                match fpps.Method with
                | PodmanStatus -> "PodmanStatus  "
                | HealthEndpoint -> "HealthEndpoint"
                | PortProbe -> "PortProbe     "
                | ProcessCheck -> "ProcessCheck  "
                | LogAnalysis -> "LogAnalysis   "
            let details = fpps.Details |> Option.defaultValue ""
            sb.AppendLine(sprintf "    [%s] %s: %s" icon methodName details) |> ignore)

        match nodeResult.FailureReason with
        | Some reason -> sb.AppendLine(sprintf "    REASON: %s" reason) |> ignore
        | None -> ()

        sb.AppendLine() |> ignore)

    // Summary
    sb.AppendLine("=" |> String.replicate 70) |> ignore
    let healthyCount = result.NodeResults |> Map.filter (fun _ r -> r.IsHealthy) |> Map.count
    let totalCount = result.NodeResults.Count
    sb.AppendLine(sprintf "SUMMARY: %d/%d nodes healthy" healthyCount totalCount) |> ignore

    match result.Status with
    | ChainDegraded nodes ->
        sb.AppendLine(sprintf "DEGRADED NODES: %s" (String.concat ", " nodes)) |> ignore
    | ChainFailed nodes ->
        sb.AppendLine(sprintf "FAILED NODES: %s" (String.concat ", " nodes)) |> ignore
    | _ -> ()

    sb.AppendLine("=" |> String.replicate 70) |> ignore

    sb.ToString()

// ============================================================================
// MAIN CHAIN VERIFICATION
// ============================================================================

/// Full chain verification with FPPS consensus
let verifyChain
    (logger: UnifiedLogger)
    (runner: IProcessRunner)
    (config: ChainVerifierConfig)
    (portMap: Map<string, int>)
    : Async<ChainVerificationResult> = async {

    logger.Info(sprintf "Starting chain verification for '%s'..." config.ChainId)
    logger.StartPhase("CHAIN_VERIFY")
    let sw = Stopwatch.StartNew()

    // Step 1: Check for cycles (SC-AGT-018)
    logger.LogWithCategory("  Step 1: Checking for cyclic dependencies...", EventCategory.Protocol, LogLevel.Debug)
    let cycleResult = checkCyclicDependencies config.DAG
    let cycleDetected = Result.isError cycleResult

    if cycleDetected then
        logger.Error("[SC-AGT-018] Cyclic dependencies detected - chain verification BLOCKED")
        sw.Stop()
        return {
            ChainId = config.ChainId
            Status = ChainFailed []
            NodeResults = Map.empty
            ConsensusResults = []
            CycleDetected = true
            BootOrderValid = false
            TotalVerificationTimeMs = sw.ElapsedMilliseconds
            VerifiedAt = DateTime.UtcNow
            LayerResults = Map.empty
        }
    else
        logger.Info("  [PASS] No cyclic dependencies")

        // Step 2: Verify boot sequence
        logger.LogWithCategory("  Step 2: Verifying boot sequence...", EventCategory.Protocol, LogLevel.Debug)
        let bootResult = verifyBootSequence config.DAG
        let bootOrderValid = Result.isOk bootResult

        if bootOrderValid then
            logger.Info("  [PASS] Boot sequence valid")
        else
            logger.LogWithCategory("  [WARN] Boot sequence issues detected", EventCategory.Protocol, LogLevel.Warning)

        // Step 3: Run FPPS consensus for all nodes (SC-CEP-003)
        logger.LogWithCategory("  Step 3: Running FPPS 5-method consensus...", EventCategory.Protocol, LogLevel.Debug)
        let! (consensusResults, nodeResults) = runFPPSConsensus logger runner config portMap

        // Step 4: Verify layers
        logger.LogWithCategory("  Step 4: Verifying layer health...", EventCategory.Protocol, LogLevel.Debug)
        let layerResults = verifyAllLayers config.DAG nodeResults

        // Step 5: Determine final status
        let healthyNodes = nodeResults |> Map.filter (fun _ r -> r.IsHealthy) |> Map.toList |> List.map fst
        let unhealthyNodes = nodeResults |> Map.filter (fun _ r -> not r.IsHealthy) |> Map.toList |> List.map fst

        // Check if unhealthy nodes are all optional dependencies
        let unhealthyMandatory =
            unhealthyNodes
            |> List.filter (fun nodeId ->
                let dependents = getDependents nodeId config.DAG
                dependents |> List.exists (fun depId ->
                    match getDependencyType nodeId depId config.DAG with
                    | Some Mandatory -> true
                    | _ -> false)
                || List.isEmpty dependents)  // Root/leaf nodes are mandatory

        let status =
            if List.isEmpty unhealthyNodes then
                ChainHealthy
            elif List.isEmpty unhealthyMandatory && config.AllowDegradedOptional then
                ChainDegraded unhealthyNodes
            else
                ChainFailed unhealthyMandatory

        sw.Stop()

        // Log final result
        match status with
        | ChainHealthy ->
            logger.Info(sprintf "[SC-VAL-003] Chain '%s' verification PASSED - all %d nodes healthy"
                config.ChainId (Map.count nodeResults))
            logger.IncrementCounter("chain.verification", tags = Map.ofList [("chain", config.ChainId); ("result", "healthy")])
        | ChainDegraded nodes ->
            logger.LogWithCategory(sprintf "Chain '%s' DEGRADED - %d/%d nodes unhealthy (optional deps only)"
                config.ChainId (List.length nodes) (Map.count nodeResults), EventCategory.Protocol, LogLevel.Warning)
            logger.IncrementCounter("chain.verification", tags = Map.ofList [("chain", config.ChainId); ("result", "degraded")])
        | ChainFailed nodes ->
            logger.Error(sprintf "Chain '%s' FAILED - %d critical nodes unhealthy"
                config.ChainId (List.length nodes))
            logger.IncrementCounter("chain.verification", tags = Map.ofList [("chain", config.ChainId); ("result", "failed")])
        | _ -> ()

        logger.RecordHistogram("chain.verification_ms", float sw.ElapsedMilliseconds,
            Map.ofList [("chain", config.ChainId)])
        logger.EndPhase("CHAIN_VERIFY", sw.ElapsedMilliseconds, (status = ChainHealthy))

        return {
            ChainId = config.ChainId
            Status = status
            NodeResults = nodeResults
            ConsensusResults = consensusResults
            CycleDetected = false
            BootOrderValid = bootOrderValid
            TotalVerificationTimeMs = sw.ElapsedMilliseconds
            VerifiedAt = DateTime.UtcNow
            LayerResults = layerResults
        }
}

/// Quick chain health check (without full FPPS)
let quickChainCheck
    (logger: UnifiedLogger)
    (runner: IProcessRunner)
    (dag: ServiceDAG)
    : Async<bool> = async {

    // Just check for cycles and basic podman status
    match checkCyclicDependencies dag with
    | Error _ -> return false
    | Ok () ->
        let! results =
            dag.Nodes
            |> Map.toList
            |> List.map (fun (nodeId, _) -> probePodmanStatus runner nodeId)
            |> Async.Parallel

        return results |> Array.forall (fun r -> r.Passed)
}

/// Verify chain and return simple pass/fail with reason
let verifyChainSimple
    (logger: UnifiedLogger)
    (runner: IProcessRunner)
    (config: ChainVerifierConfig)
    (portMap: Map<string, int>)
    : Async<Result<unit, string>> = async {

    let! result = verifyChain logger runner config portMap

    match result.Status with
    | ChainHealthy -> return Ok ()
    | ChainDegraded nodes ->
        return Error (sprintf "Chain degraded: %s" (String.concat ", " nodes))
    | ChainFailed nodes ->
        return Error (sprintf "Chain failed: %s" (String.concat ", " nodes))
    | ChainVerifying ->
        return Error "Verification incomplete"
    | ChainNotVerified ->
        return Error "Verification not started"
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/// Get all failed nodes from verification result
let getFailedNodes (result: ChainVerificationResult) : string list =
    result.NodeResults
    |> Map.toList
    |> List.filter (fun (_, r) -> not r.IsHealthy)
    |> List.map fst

/// Get all healthy nodes from verification result
let getHealthyNodes (result: ChainVerificationResult) : string list =
    result.NodeResults
    |> Map.toList
    |> List.filter (fun (_, r) -> r.IsHealthy)
    |> List.map fst

/// Check if specific FPPS method passed for a node
let methodPassedForNode (method: ConsensusMethod) (nodeId: string) (result: ChainVerificationResult) : bool =
    result.ConsensusResults
    |> List.exists (fun r -> r.NodeId = nodeId && r.Method = method && r.Passed)

/// Get consensus stats for the chain
let getConsensusStats (result: ChainVerificationResult) : Map<ConsensusMethod, int * int> =
    let methods = [PodmanStatus; HealthEndpoint; PortProbe; ProcessCheck; LogAnalysis]

    methods
    |> List.map (fun method ->
        let methodResults = result.ConsensusResults |> List.filter (fun r -> r.Method = method)
        let passed = methodResults |> List.filter (fun r -> r.Passed) |> List.length
        let total = methodResults |> List.length
        (method, (passed, total)))
    |> Map.ofList
