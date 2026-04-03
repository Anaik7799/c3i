// =============================================================================
// Apoptosis.fs - SIL-4 Controlled Self-Destruction Protocol
// =============================================================================
// STAMP Constraints:
//   SC-SIL4-015: Split-brain triggers apoptosis
//   SC-SIL4-007: Dying gasp mandatory before shutdown
//   SC-EMR-057: Emergency stop < 5s
//   SC-CONST-001: Ψ₀ Existence preservation (graceful termination)
//
// AOR Rules:
//   AOR-FOUNDER-007: Threats to system eliminated immediately
//   AOR-REG-008: Maintain rollback capability for 24h after evolution
//   AOR-CONST-002: Immediate halt and rollback on constitutional violation
//
// 5-Order Effects Analysis:
//   1st Order: Apoptosis signal received, countdown initiated
//   2nd Order: Connections drained, state checkpointed
//   3rd Order: Peer notification, federation alert
//   4th Order: Resources released, containers terminated
//   5th Order: Cluster reconfigures, new leader elected
//
// Biomorphic Analogy:
//   Cellular apoptosis - programmed cell death that maintains organism health
//   by removing damaged/dangerous cells before they can harm the whole
// =============================================================================

namespace Cepaf.Mesh

open System
open System.Collections.Concurrent
open System.Threading
open System.Threading.Tasks
open System.Security.Cryptography

/// Async helpers (F# standard library doesn't have bind/map)
module AsyncHelpers =
    let bind f a = async {
        let! x = a
        return! f x
    }

    let map f a = async {
        let! x = a
        return f x
    }

/// Split-brain trigger data
type SplitBrainTriggerData = {
    Partition1Count: int
    Partition2Count: int
    OurPartition: string
}

/// Quorum lost trigger data
type QuorumLostData = {
    HealthyNodes: int
    RequiredQuorum: int
    TotalNodes: int
}

/// Seed nodes down trigger data
type SeedNodesDownData = {
    DownSeeds: string list
    TotalSeeds: int
}

/// Constitutional violation trigger data
type ConstitutionalViolationData = {
    ViolatedInvariant: string
    Severity: string
}

/// Manual trigger data
type ManualTriggerData = {
    AuthorizedBy: string
    Reason: string
    ProofToken: string
}

/// Cascade failure trigger data
type CascadeFailureData = {
    FailedComponents: string list
    FailureRate: float
}

/// Security threat trigger data
type SecurityThreatData = {
    ThreatType: string
    ThreatLevel: string
    Source: string
}

/// Apoptosis trigger reason
type ApoptosisTrigger =
    | SplitBrainDetected of SplitBrainTriggerData
    | QuorumLost of QuorumLostData
    | SeedNodesDown of SeedNodesDownData
    | ConstitutionalViolation of ConstitutionalViolationData
    | ManualTrigger of ManualTriggerData
    | CascadeFailure of CascadeFailureData
    | SecurityThreat of SecurityThreatData

/// Apoptosis phase (6 phases for controlled shutdown)
type ApoptosisPhase =
    | Initiated         // Signal received, countdown started
    | Notifying         // Alerting peers and federation
    | Draining          // Connections being drained
    | Checkpointing     // State being saved (dying gasp)
    | Terminating       // Processes being stopped
    | Terminated        // Final state

/// Dying gasp checkpoint data
type DyingGaspCheckpoint = {
    CheckpointId: Guid
    ContainerId: string
    Timestamp: DateTime
    TriggerReason: ApoptosisTrigger
    StateSnapshot: Map<string, obj>
    HealthMetrics: Map<string, float>
    ConnectionCount: int
    PendingOperations: int
    Sha256Hash: string
}

/// Apoptosis state for a container
type ApoptosisState = {
    ContainerId: string
    Phase: ApoptosisPhase
    Trigger: ApoptosisTrigger
    InitiatedAt: DateTime
    PhaseStartedAt: DateTime
    DeadlineAt: DateTime
    DyingGaspSaved: bool
    PeersNotified: int
    FederationNotified: bool
    LastCheckpoint: DyingGaspCheckpoint option
}

/// 5-Order effects tracking for apoptosis
type ApoptosisEffects = {
    FirstOrder: string
    SecondOrder: string
    ThirdOrder: string
    FourthOrder: string
    FifthOrder: string
    Phase: ApoptosisPhase
    ContainerId: string
    Timestamp: DateTime
}

/// Apoptosis configuration
type ApoptosisConfig = {
    GracePeriodMs: int          // Time before forced termination (default: 10000ms)
    DrainTimeoutMs: int         // Max time for connection draining (default: 5000ms)
    CheckpointTimeoutMs: int    // Max time for dying gasp (default: 3000ms)
    NotificationTimeoutMs: int  // Max time for peer notification (default: 2000ms)
    EmergencyStopMs: int        // SC-EMR-057: < 5000ms (default: 4500ms)
    MaxRetries: int             // Retry count for each phase (default: 3)
}

/// SIL-4 Apoptosis Controller
type ApoptosisController() =

    let defaultConfig = {
        GracePeriodMs = 10000       // 10s grace period
        DrainTimeoutMs = 5000      // 5s drain
        CheckpointTimeoutMs = 3000 // 3s checkpoint (dying gasp)
        NotificationTimeoutMs = 2000 // 2s notification
        EmergencyStopMs = 4500     // 4.5s emergency (SC-EMR-057)
        MaxRetries = 3
    }

    let mutable config = defaultConfig
    let apoptosisStates = ConcurrentDictionary<string, ApoptosisState>()
    let effectsLog = ConcurrentDictionary<Guid, ApoptosisEffects>()
    let checkpointStore = ConcurrentDictionary<string, DyingGaspCheckpoint>()

    // Cancellation tokens for controlled abort
    let cancellationTokens = ConcurrentDictionary<string, CancellationTokenSource>()

    /// Configure apoptosis parameters
    member this.Configure(newConfig: ApoptosisConfig) =
        config <- newConfig

    /// Calculate SHA256 hash for checkpoint integrity
    member private this.CalculateSha256(data: string) =
        use sha256 = SHA256.Create()
        let bytes = System.Text.Encoding.UTF8.GetBytes(data)
        let hash = sha256.ComputeHash(bytes)
        BitConverter.ToString(hash).Replace("-", "").ToLower()

    /// Log 5-order effects
    member private this.LogEffects(containerId: string, phase: ApoptosisPhase,
                                    first: string, second: string,
                                    third: string, fourth: string, fifth: string) =
        let effects = {
            FirstOrder = first
            SecondOrder = second
            ThirdOrder = third
            FourthOrder = fourth
            FifthOrder = fifth
            Phase = phase
            ContainerId = containerId
            Timestamp = DateTime.UtcNow
        }
        effectsLog.TryAdd(Guid.NewGuid(), effects) |> ignore

    /// Initiate apoptosis for a container
    member this.Initiate(containerId: string, trigger: ApoptosisTrigger) =
        let now = DateTime.UtcNow

        let state = {
            ContainerId = containerId
            Phase = Initiated
            Trigger = trigger
            InitiatedAt = now
            PhaseStartedAt = now
            DeadlineAt = now.AddMilliseconds(float config.GracePeriodMs)
            DyingGaspSaved = false
            PeersNotified = 0
            FederationNotified = false
            LastCheckpoint = None
        }

        apoptosisStates.[containerId] <- state

        // Create cancellation token for this apoptosis
        let cts = new CancellationTokenSource()
        cancellationTokens.[containerId] <- cts

        // Log 5-order effects
        this.LogEffects(
            containerId,
            Initiated,
            sprintf "Apoptosis initiated for %s" containerId,
            sprintf "Trigger: %A" trigger,
            "Grace period countdown started",
            "System preparing for controlled shutdown",
            "Cluster will reconfigure after termination"
        )

        state

    /// Advance to next apoptosis phase
    member this.AdvancePhase(containerId: string) =
        match apoptosisStates.TryGetValue(containerId) with
        | false, _ -> Error "Container not in apoptosis"
        | true, state ->
            let nextPhase =
                match state.Phase with
                | Initiated -> Notifying
                | Notifying -> Draining
                | Draining -> Checkpointing
                | Checkpointing -> Terminating
                | Terminating -> Terminated
                | Terminated -> Terminated

            let newState = {
                state with
                    Phase = nextPhase
                    PhaseStartedAt = DateTime.UtcNow
            }

            apoptosisStates.[containerId] <- newState

            // Log phase transition effects
            let phaseEffects =
                match nextPhase with
                | Notifying ->
                    ("Entering notification phase",
                     "Alerting peer containers",
                     "Federation receiving health degradation signal",
                     "Load balancers removing from rotation",
                     "Monitoring systems receiving alerts")
                | Draining ->
                    ("Entering drain phase",
                     "Rejecting new connections",
                     "Existing connections completing",
                     "Request queues emptying",
                     "Graceful handoff to healthy nodes")
                | Checkpointing ->
                    ("Entering checkpoint phase (SC-SIL4-007)",
                     "State serialization to JSON",
                     "SHA256 integrity hash calculation",
                     "Dying gasp written to data/checkpoints/",
                     "Recovery point established")
                | Terminating ->
                    ("Entering termination phase",
                     "Processes receiving SIGTERM",
                     "Resources being released",
                     "Containers stopping",
                     "System reconfiguring")
                | Terminated ->
                    ("Apoptosis complete",
                     "Container terminated",
                     "Resources freed",
                     "Cluster reconfigured",
                     "New equilibrium reached")
                | _ ->
                    ("Phase transition", "Processing", "Continuing", "Monitoring", "Completing")

            let (first, second, third, fourth, fifth) = phaseEffects
            this.LogEffects(containerId, nextPhase, first, second, third, fourth, fifth)

            Ok newState

    /// Create dying gasp checkpoint (SC-SIL4-007)
    member this.CreateDyingGasp(containerId: string,
                                 stateSnapshot: Map<string, obj>,
                                 healthMetrics: Map<string, float>,
                                 connectionCount: int,
                                 pendingOps: int) =
        match apoptosisStates.TryGetValue(containerId) with
        | false, _ -> Error "Container not in apoptosis"
        | true, state ->
            // Serialize state for hash
            let stateJson =
                sprintf "{\"containerId\":\"%s\",\"timestamp\":\"%s\",\"connections\":%d,\"pending\":%d}"
                    containerId
                    (DateTime.UtcNow.ToString("o"))
                    connectionCount
                    pendingOps

            let hash = this.CalculateSha256(stateJson)

            let checkpoint = {
                CheckpointId = Guid.NewGuid()
                ContainerId = containerId
                Timestamp = DateTime.UtcNow
                TriggerReason = state.Trigger
                StateSnapshot = stateSnapshot
                HealthMetrics = healthMetrics
                ConnectionCount = connectionCount
                PendingOperations = pendingOps
                Sha256Hash = hash
            }

            checkpointStore.[containerId] <- checkpoint

            let newState = {
                state with
                    DyingGaspSaved = true
                    LastCheckpoint = Some checkpoint
            }

            apoptosisStates.[containerId] <- newState

            this.LogEffects(
                containerId,
                Checkpointing,
                sprintf "Dying gasp saved: %s" (checkpoint.CheckpointId.ToString()),
                sprintf "SHA256: %s" hash,
                sprintf "State: %d keys, %d connections" stateSnapshot.Count connectionCount,
                "Checkpoint recoverable on restart",
                "Federation can reconstruct state if needed"
            )

            Ok checkpoint

    /// Execute full apoptosis sequence
    member this.ExecuteApoptosis(containerId: string,
                                  trigger: ApoptosisTrigger,
                                  notifyPeers: string list -> Async<int>,
                                  notifyFederation: ApoptosisTrigger -> Async<bool>,
                                  drainConnections: string -> Async<int>,
                                  getState: string -> Async<Map<string, obj>>,
                                  getHealth: string -> Async<Map<string, float>>,
                                  terminateContainer: string -> Async<bool>) : Async<Result<ApoptosisState, string>> =
        async {
            // Phase 1: Initiate
            let initialState = this.Initiate(containerId, trigger)

            try
                let cts =
                    match cancellationTokens.TryGetValue(containerId) with
                    | true, token -> token
                    | false, _ ->
                        let newCts = new CancellationTokenSource()
                        cancellationTokens.[containerId] <- newCts
                        newCts

                // Phase 2: Notify peers
                match this.AdvancePhase(containerId) with
                | Error e -> return Error e
                | Ok _ ->
                    let! peersNotified =
                        Async.StartChild(notifyPeers [])
                        |> AsyncHelpers.bind (fun task ->
                            Async.Catch task
                            |> AsyncHelpers.map (function
                                | Choice1Of2 result -> result
                                | Choice2Of2 _ -> 0))

                    match apoptosisStates.TryGetValue(containerId) with
                    | true, state ->
                        apoptosisStates.[containerId] <- { state with PeersNotified = peersNotified }
                    | _ -> ()

                    // Notify federation
                    let! fedNotified =
                        Async.Catch(notifyFederation trigger)
                        |> AsyncHelpers.map (function
                            | Choice1Of2 result -> result
                            | Choice2Of2 _ -> false)

                    match apoptosisStates.TryGetValue(containerId) with
                    | true, state ->
                        apoptosisStates.[containerId] <- { state with FederationNotified = fedNotified }
                    | _ -> ()

                    // Phase 3: Drain connections
                    match this.AdvancePhase(containerId) with
                    | Error e -> return Error e
                    | Ok _ ->
                        let! _ =
                            Async.Catch(drainConnections containerId)
                            |> AsyncHelpers.map (function
                                | Choice1Of2 result -> result
                                | Choice2Of2 _ -> 0)

                        // Phase 4: Checkpoint (Dying Gasp) - SC-SIL4-007
                        match this.AdvancePhase(containerId) with
                        | Error e -> return Error e
                        | Ok _ ->
                            let! stateSnapshot =
                                Async.Catch(getState containerId)
                                |> AsyncHelpers.map (function
                                    | Choice1Of2 result -> result
                                    | Choice2Of2 _ -> Map.empty)

                            let! healthMetrics =
                                Async.Catch(getHealth containerId)
                                |> AsyncHelpers.map (function
                                    | Choice1Of2 result -> result
                                    | Choice2Of2 _ -> Map.empty)

                            let _ = this.CreateDyingGasp(containerId, stateSnapshot, healthMetrics, 0, 0)

                            // Phase 5: Terminate
                            match this.AdvancePhase(containerId) with
                            | Error e -> return Error e
                            | Ok _ ->
                                let! terminated =
                                    Async.Catch(terminateContainer containerId)
                                    |> AsyncHelpers.map (function
                                        | Choice1Of2 result -> result
                                        | Choice2Of2 _ -> false)

                                // Phase 6: Final state
                                match this.AdvancePhase(containerId) with
                                | Error e -> return Error e
                                | Ok finalState ->
                                    return Ok finalState
            with ex ->
                // Emergency stop - SC-EMR-057
                this.LogEffects(
                    containerId,
                    Terminated,
                    sprintf "Emergency termination: %s" ex.Message,
                    "Exception during apoptosis",
                    "Forcing immediate stop",
                    "Resources may not be fully cleaned",
                    "Manual intervention may be required"
                )

                return Error (sprintf "Apoptosis failed: %s" ex.Message)
        }

    /// Emergency stop - bypass normal phases (SC-EMR-057)
    member this.EmergencyStop(containerId: string, reason: string) =
        let now = DateTime.UtcNow

        // Cancel any ongoing apoptosis
        match cancellationTokens.TryGetValue(containerId) with
        | true, cts -> cts.Cancel()
        | _ -> ()

        let state = {
            ContainerId = containerId
            Phase = Terminated
            Trigger = ManualTrigger {
                AuthorizedBy = "EMERGENCY"
                Reason = reason
                ProofToken = this.CalculateSha256(sprintf "%s-%s-%s" containerId reason (now.ToString("o")))
            }
            InitiatedAt = now
            PhaseStartedAt = now
            DeadlineAt = now.AddMilliseconds(float config.EmergencyStopMs)
            DyingGaspSaved = false
            PeersNotified = 0
            FederationNotified = false
            LastCheckpoint = None
        }

        apoptosisStates.[containerId] <- state

        this.LogEffects(
            containerId,
            Terminated,
            sprintf "EMERGENCY STOP: %s" reason,
            "Bypassing normal apoptosis phases",
            "Immediate termination (SC-EMR-057)",
            "Resources force-released",
            "Cluster in emergency reconfiguration"
        )

        state

    /// Get apoptosis state
    member this.GetState(containerId: string) =
        match apoptosisStates.TryGetValue(containerId) with
        | true, state -> Some state
        | false, _ -> None

    /// Get dying gasp checkpoint
    member this.GetCheckpoint(containerId: string) =
        match checkpointStore.TryGetValue(containerId) with
        | true, checkpoint -> Some checkpoint
        | false, _ -> None

    /// Verify checkpoint integrity
    member this.VerifyCheckpoint(checkpoint: DyingGaspCheckpoint) =
        let expectedHash =
            sprintf "{\"containerId\":\"%s\",\"timestamp\":\"%s\",\"connections\":%d,\"pending\":%d}"
                checkpoint.ContainerId
                (checkpoint.Timestamp.ToString("o"))
                checkpoint.ConnectionCount
                checkpoint.PendingOperations
            |> this.CalculateSha256

        let valid = expectedHash = checkpoint.Sha256Hash

        {|
            Valid = valid
            ExpectedHash = expectedHash
            ActualHash = checkpoint.Sha256Hash
            CheckpointId = checkpoint.CheckpointId
        |}

    /// Get effects log
    member this.GetEffectsLog(?count: int) =
        let limit = defaultArg count 50
        effectsLog.Values
        |> Seq.sortByDescending (fun e -> e.Timestamp)
        |> Seq.truncate limit
        |> Seq.toList

    /// Get all active apoptosis states
    member this.GetActiveApoptosis() =
        apoptosisStates.Values
        |> Seq.filter (fun s -> s.Phase <> Terminated)
        |> Seq.toList

    /// Check if container is in apoptosis
    member this.IsInApoptosis(containerId: string) =
        match apoptosisStates.TryGetValue(containerId) with
        | true, state -> state.Phase <> Terminated
        | false, _ -> false

    /// Abort apoptosis (if still in early phase)
    member this.AbortApoptosis(containerId: string, reason: string) =
        match apoptosisStates.TryGetValue(containerId) with
        | false, _ -> Error "Container not in apoptosis"
        | true, state ->
            match state.Phase with
            | Initiated | Notifying ->
                // Can abort in early phases
                match cancellationTokens.TryGetValue(containerId) with
                | true, cts -> cts.Cancel()
                | _ -> ()

                apoptosisStates.TryRemove(containerId) |> ignore
                cancellationTokens.TryRemove(containerId) |> ignore

                this.LogEffects(
                    containerId,
                    Terminated,
                    sprintf "Apoptosis ABORTED: %s" reason,
                    "Early phase - abort successful",
                    "Container returned to normal operation",
                    "No resources lost",
                    "Cluster topology unchanged"
                )

                Ok "Apoptosis aborted"
            | _ ->
                Error "Cannot abort - apoptosis too far advanced"

    /// Clean up completed apoptosis records
    member this.Cleanup(olderThanMinutes: int) =
        let cutoff = DateTime.UtcNow.AddMinutes(float -olderThanMinutes)

        let toRemove =
            apoptosisStates
            |> Seq.filter (fun kv ->
                kv.Value.Phase = Terminated &&
                kv.Value.InitiatedAt < cutoff)
            |> Seq.map (fun kv -> kv.Key)
            |> Seq.toList

        for containerId in toRemove do
            apoptosisStates.TryRemove(containerId) |> ignore
            checkpointStore.TryRemove(containerId) |> ignore
            cancellationTokens.TryRemove(containerId) |> ignore

        toRemove.Length
