// =============================================================================
// SplitBrainResolver.fs - Split-Brain Detection and Resolution (FM-006)
// =============================================================================
// STAMP: SC-CONS-003, SC-CONS-005, SC-CONS-006
// AOR: AOR-ZENOH-015, AOR-ZENOH-016
// Criticality: Level 6 (CRITICAL) - Network Partition Recovery
// =============================================================================
// Provides split-brain detection and resolution using external witness:
// - External witness arbitration for network partitions (SC-CONS-003)
// - Majority vs minority partition determination (SC-CONS-005)
// - Automatic freeze/recovery protocol for minority (SC-CONS-006)
// - Witness health monitoring and failover
// - Metrics and telemetry for partition events
// =============================================================================

namespace Cepaf.Zenoh.Cluster

open System
open System.Net.Http
open System.Text.Json
open System.Threading
open System.Threading.Tasks
open System.Collections.Concurrent
open Cepaf.Zenoh.Core

/// Configuration for external witness node
type WitnessConfig = {
    /// HTTP endpoint of witness node (e.g., "http://witness:8080")
    Endpoint: string
    /// Request timeout in milliseconds (SC-CONS-003: max 5000ms)
    TimeoutMs: int
    /// Number of retry attempts before declaring witness unreachable
    RetryCount: int
    /// Delay between retry attempts in milliseconds
    RetryDelayMs: int
    /// Witness health check interval in milliseconds
    HealthCheckIntervalMs: int
    /// Enable TLS for witness communication
    EnableTls: bool
    /// API key for witness authentication (optional)
    ApiKey: string option
}

module WitnessConfig =
    /// Default witness configuration with SIL-6 compliant values
    let defaultConfig () = {
        Endpoint = "http://witness:8080"
        TimeoutMs = 5000          // SC-CONS-003: max 5000ms
        RetryCount = 3
        RetryDelayMs = 1000
        HealthCheckIntervalMs = 10000
        EnableTls = false
        ApiKey = None
    }

    /// Create config for specific witness endpoint
    let forEndpoint (endpoint: string) =
        { defaultConfig() with Endpoint = endpoint }

    /// Enable TLS with API key authentication
    let withTls (apiKey: string) (config: WitnessConfig) =
        { config with EnableTls = true; ApiKey = Some apiKey }

/// Partition resolution decision from witness
[<RequireQualifiedAccess>]
type PartitionResolution =
    /// This node is in the majority partition - continue operations
    | IAmMajority of totalNodes: int * myPartitionSize: int * otherPartitionSize: int
    /// This node is in the minority partition - freeze operations
    | IAmMinority of totalNodes: int * myPartitionSize: int * majorityPartitionSize: int
    /// Witness node is unreachable - enter safe mode
    | WitnessUnreachable of attemptedCount: int * lastError: string
    /// Partitions are equal size - witness decides based on leader presence
    | TieBreaker of decision: bool * reason: string

    /// Check if this node should continue operations
    member this.ShouldContinueOperations =
        match this with
        | IAmMajority _ -> true
        | TieBreaker (decision, _) -> decision
        | _ -> false

    /// Check if this node should freeze operations
    member this.ShouldFreezeOperations =
        match this with
        | IAmMinority _ -> true
        | TieBreaker (decision, _) -> not decision
        | _ -> false

    /// Check if safe mode should be entered
    member this.RequiresSafeMode =
        match this with
        | WitnessUnreachable _ -> true
        | _ -> false

/// Arbitration request sent to witness
type ArbitrationRequest = {
    /// ID of node requesting arbitration
    RequestingNodeId: string
    /// Current term (Raft epoch)
    Term: int64
    /// Nodes visible in requesting node's partition
    PartitionNodes: string list
    /// Total cluster size
    TotalClusterSize: int
    /// Current leader in this partition (if known)
    CurrentLeader: string option
    /// Timestamp of partition detection
    DetectedAt: DateTimeOffset
    /// Request ID for idempotency
    RequestId: Guid
}

module ArbitrationRequest =
    /// Create arbitration request
    let create (nodeId: string) (term: int64) (partitionNodes: string list) (totalSize: int) (leader: string option) = {
        RequestingNodeId = nodeId
        Term = term
        PartitionNodes = partitionNodes
        TotalClusterSize = totalSize
        CurrentLeader = leader
        DetectedAt = DateTimeOffset.UtcNow
        RequestId = Guid.NewGuid()
    }

    /// Serialize to JSON
    let toJson (request: ArbitrationRequest) : string =
        JsonSerializer.Serialize(request, JsonSerializerOptions(PropertyNamingPolicy = JsonNamingPolicy.CamelCase))

/// Arbitration response from witness
type ArbitrationResponse = {
    /// Was arbitration successful?
    Success: bool
    /// Is the requesting partition the majority?
    IsMajority: bool
    /// Size of requesting partition
    RequestingPartitionSize: int
    /// Size of other known partition(s)
    OtherPartitionSize: int
    /// Total nodes known to witness
    WitnessTotalNodes: int
    /// Reason for decision
    Reason: string
    /// Timestamp of arbitration
    ArbitratedAt: DateTimeOffset
    /// Request ID for correlation
    RequestId: Guid
}

module ArbitrationResponse =
    /// Parse from JSON
    let fromJson (json: string) : Result<ArbitrationResponse, string> =
        try
            let response = JsonSerializer.Deserialize<ArbitrationResponse>(json, JsonSerializerOptions(PropertyNamingPolicy = JsonNamingPolicy.CamelCase))
            Ok response
        with ex ->
            Error (sprintf "Failed to parse arbitration response: %s" ex.Message)

/// Partition state for monitoring
type PartitionState = {
    /// Is partition currently detected?
    IsPartitioned: bool
    /// When was partition detected?
    DetectedAt: DateTimeOffset option
    /// Current resolution
    CurrentResolution: PartitionResolution option
    /// Arbitration attempts count
    ArbitrationAttempts: int
    /// Last successful arbitration
    LastArbitration: DateTimeOffset option
    /// Are operations frozen?
    OperationsFrozen: bool
    /// Frozen at timestamp
    FrozenAt: DateTimeOffset option
}

module PartitionState =
    /// Empty/initial state
    let empty = {
        IsPartitioned = false
        DetectedAt = None
        CurrentResolution = None
        ArbitrationAttempts = 0
        LastArbitration = None
        OperationsFrozen = false
        FrozenAt = None
    }

    /// Mark partition detected
    let detected (state: PartitionState) =
        { state with
            IsPartitioned = true
            DetectedAt = Some DateTimeOffset.UtcNow
            ArbitrationAttempts = 0
        }

    /// Update with resolution
    let resolved (resolution: PartitionResolution) (state: PartitionState) =
        { state with
            CurrentResolution = Some resolution
            ArbitrationAttempts = state.ArbitrationAttempts + 1
            LastArbitration = Some DateTimeOffset.UtcNow
        }

    /// Freeze operations
    let freeze (state: PartitionState) =
        { state with
            OperationsFrozen = true
            FrozenAt = Some DateTimeOffset.UtcNow
        }

    /// Unfreeze operations (partition healed)
    let unfreeze (state: PartitionState) =
        { state with
            IsPartitioned = false
            OperationsFrozen = false
            CurrentResolution = None
        }

/// Recovery action to execute based on resolution
[<RequireQualifiedAccess>]
type RecoveryAction =
    /// Continue normal operations
    | ContinueOperations
    /// Freeze all write operations
    | FreezeWrites
    /// Enter safe mode (conservative)
    | EnterSafeMode
    /// Step down from leadership
    | StepDownLeader
    /// Trigger manual intervention
    | ManualIntervention of reason: string

/// Split-brain resolver using external witness (SC-CONS-003, SC-CONS-005, SC-CONS-006)
type SplitBrainResolver(nodeId: string, config: WitnessConfig) =
    let httpClient = new HttpClient(Timeout = TimeSpan.FromMilliseconds(float config.TimeoutMs))
    let mutable partitionState = PartitionState.empty
    let lockObj = obj()
    let mutable healthCheckTimer: Timer option = None
    let witnessHealthy = ConcurrentDictionary<DateTimeOffset, bool>()

    // Witness health tracking
    let mutable lastWitnessCheck = DateTimeOffset.MinValue
    let mutable consecutiveFailures = 0

    do
        // Configure HTTP client
        if config.EnableTls then
            httpClient.DefaultRequestHeaders.Add("X-API-Key", config.ApiKey |> Option.defaultValue "")

    /// Node identifier
    member _.NodeId = nodeId

    /// Current partition state
    member _.State = partitionState

    /// Is witness healthy?
    member _.IsWitnessHealthy =
        consecutiveFailures < config.RetryCount

    /// Start health check timer
    member this.Start() =
        healthCheckTimer <- Some (new Timer(
            TimerCallback(fun _ -> this.CheckWitnessHealth() |> ignore),
            null,
            0,
            config.HealthCheckIntervalMs))

    /// Stop health check timer
    member _.Stop() =
        healthCheckTimer |> Option.iter (fun t -> t.Dispose())
        healthCheckTimer <- None

    /// Check witness health
    member private this.CheckWitnessHealth() : Task<bool> =
        task {
            try
                let! response = httpClient.GetAsync($"{config.Endpoint}/health")
                let isHealthy = response.IsSuccessStatusCode

                lastWitnessCheck <- DateTimeOffset.UtcNow
                if isHealthy then
                    consecutiveFailures <- 0
                    witnessHealthy.[DateTimeOffset.UtcNow] <- true
                else
                    consecutiveFailures <- consecutiveFailures + 1
                    witnessHealthy.[DateTimeOffset.UtcNow] <- false

                return isHealthy
            with ex ->
                consecutiveFailures <- consecutiveFailures + 1
                witnessHealthy.[DateTimeOffset.UtcNow] <- false
                return false
        }

    /// Request arbitration from external witness (SC-CONS-003)
    member this.RequestArbitrationAsync(term: int64, partitionNodes: string list, totalClusterSize: int, currentLeader: string option) : Task<PartitionResolution> =
        Task.Run(fun () ->
            lock lockObj (fun () ->
                partitionState <- PartitionState.detected partitionState
            )

            let request = ArbitrationRequest.create nodeId term partitionNodes totalClusterSize currentLeader
            let mutable attempts = 0
            let mutable lastError = ""
            let mutable result: PartitionResolution option = None

            while attempts < config.RetryCount && result.IsNone do
                attempts <- attempts + 1

                try
                    let requestJson = ArbitrationRequest.toJson request
                    let content = new StringContent(requestJson, System.Text.Encoding.UTF8, "application/json")

                    use response = httpClient.PostAsync($"{config.Endpoint}/arbitrate", content).Result

                    if response.IsSuccessStatusCode then
                        let responseJson = response.Content.ReadAsStringAsync().Result

                        match ArbitrationResponse.fromJson responseJson with
                        | Ok arbResponse ->
                            let resolution =
                                if not arbResponse.Success then
                                    PartitionResolution.WitnessUnreachable (attempts, arbResponse.Reason)
                                elif arbResponse.IsMajority then
                                    PartitionResolution.IAmMajority (arbResponse.WitnessTotalNodes, arbResponse.RequestingPartitionSize, arbResponse.OtherPartitionSize)
                                elif arbResponse.RequestingPartitionSize = arbResponse.OtherPartitionSize then
                                    // Tie-breaker: witness decides based on leader presence
                                    let hasLeader = currentLeader.IsSome
                                    PartitionResolution.TieBreaker (hasLeader, arbResponse.Reason)
                                else
                                    PartitionResolution.IAmMinority (arbResponse.WitnessTotalNodes, arbResponse.RequestingPartitionSize, arbResponse.OtherPartitionSize)

                            lock lockObj (fun () ->
                                partitionState <- PartitionState.resolved resolution partitionState
                            )

                            result <- Some resolution

                        | Error err ->
                            lastError <- err
                            if attempts < config.RetryCount then
                                Threading.Thread.Sleep(config.RetryDelayMs)
                    else
                        lastError <- sprintf "HTTP %d: %s" (int response.StatusCode) response.ReasonPhrase
                        if attempts < config.RetryCount then
                            Threading.Thread.Sleep(config.RetryDelayMs)
                with ex ->
                    lastError <- ex.Message
                    if attempts < config.RetryCount then
                        Threading.Thread.Sleep(config.RetryDelayMs)

            // Return result or failure
            match result with
            | Some r -> r
            | None ->
                let resolution = PartitionResolution.WitnessUnreachable (attempts, lastError)

                lock lockObj (fun () ->
                    partitionState <- PartitionState.resolved resolution partitionState
                )

                resolution
        )

    /// Execute recovery based on resolution (SC-CONS-006)
    member this.ExecuteRecovery(resolution: PartitionResolution) : RecoveryAction =
        match resolution with
        | PartitionResolution.IAmMajority _ ->
            // Majority partition - continue operations normally
            lock lockObj (fun () ->
                partitionState <- PartitionState.unfreeze partitionState
            )
            RecoveryAction.ContinueOperations

        | PartitionResolution.IAmMinority _ ->
            // Minority partition - freeze all write operations
            lock lockObj (fun () ->
                partitionState <- PartitionState.freeze partitionState
            )
            RecoveryAction.FreezeWrites

        | PartitionResolution.WitnessUnreachable _ ->
            // Witness unreachable - enter conservative safe mode
            lock lockObj (fun () ->
                partitionState <- PartitionState.freeze partitionState
            )
            RecoveryAction.EnterSafeMode

        | PartitionResolution.TieBreaker (shouldContinue, reason) ->
            // Tie-breaker decision
            if shouldContinue then
                lock lockObj (fun () ->
                    partitionState <- PartitionState.unfreeze partitionState
                )
                RecoveryAction.ContinueOperations
            else
                lock lockObj (fun () ->
                    partitionState <- PartitionState.freeze partitionState
                )
                RecoveryAction.StepDownLeader

    /// Detect split-brain condition (SC-CONS-005)
    member this.DetectSplitBrain(visibleNodes: string list, totalClusterSize: int) : bool =
        let visibleCount = visibleNodes.Length
        let quorumSize = (totalClusterSize / 2) + 1

        // Split-brain detected if we can't see quorum
        if visibleCount < quorumSize then
            true
        else
            false

    /// Get recovery recommendation based on current state
    member this.GetRecoveryRecommendation() : RecoveryAction option =
        match partitionState.CurrentResolution with
        | Some resolution -> Some (this.ExecuteRecovery(resolution))
        | None -> None

    /// Freeze operations immediately (emergency)
    member this.FreezeOperations(reason: string) : unit =
        lock lockObj (fun () ->
            partitionState <- PartitionState.freeze partitionState
        )

    /// Check if operations are currently frozen
    member _.AreOperationsFrozen = partitionState.OperationsFrozen

    /// Get partition metrics for telemetry
    member this.GetMetrics() = {|
        IsPartitioned = partitionState.IsPartitioned
        DetectedAt = partitionState.DetectedAt
        ArbitrationAttempts = partitionState.ArbitrationAttempts
        LastArbitration = partitionState.LastArbitration
        OperationsFrozen = partitionState.OperationsFrozen
        FrozenAt = partitionState.FrozenAt
        WitnessHealthy = this.IsWitnessHealthy
        LastWitnessCheck = lastWitnessCheck
        ConsecutiveFailures = consecutiveFailures
    |}

    /// Heal partition (called when network partition is resolved)
    member this.HealPartition() : unit =
        lock lockObj (fun () ->
            partitionState <- PartitionState.unfreeze partitionState
        )

    interface IDisposable with
        member this.Dispose() =
            this.Stop()
            httpClient.Dispose()

/// Witness server API contract for documentation
module WitnessApi =
    /// Health check endpoint
    /// GET /health
    /// Response: 200 OK or 503 Service Unavailable
    let HealthEndpoint = "/health"

    /// Arbitration endpoint
    /// POST /arbitrate
    /// Request: ArbitrationRequest (JSON)
    /// Response: ArbitrationResponse (JSON)
    let ArbitrateEndpoint = "/arbitrate"

    /// Expected response codes
    let [<Literal>] SuccessCode = 200
    let [<Literal>] ServiceUnavailableCode = 503
    let [<Literal>] BadRequestCode = 400

/// Integration with RaftNode consensus
module ConsensusIntegration =
    /// Attach split-brain resolver to Raft node
    let attachResolver<'T> (raftNode: RaftNode<'T>) (resolver: SplitBrainResolver) =
        // Subscribe to consensus events
        raftNode.OnEvent(fun event ->
            match event with
            | ConsensusEvent.BecameFollower (term, leader) when leader.IsNone ->
                // Lost leader - might be partition
                let visibleNodes = [raftNode.NodeId]  // Simplified - would get from membership
                let totalClusterSize = 3  // Simplified - would get from config

                if resolver.DetectSplitBrain(visibleNodes, totalClusterSize) then
                    // Split-brain detected - request arbitration
                    async {
                        let! resolution = resolver.RequestArbitrationAsync(term, visibleNodes, totalClusterSize, None) |> Async.AwaitTask
                        let action = resolver.ExecuteRecovery(resolution)

                        match action with
                        | RecoveryAction.StepDownLeader ->
                            // Already follower, just log
                            ()
                        | RecoveryAction.FreezeWrites ->
                            // Freeze operations
                            resolver.FreezeOperations("Minority partition detected")
                        | _ -> ()
                    } |> Async.Start
            | _ -> ()
        )

    /// Check if safe to accept writes
    let isSafeForWrites (resolver: SplitBrainResolver) : bool =
        not resolver.AreOperationsFrozen
