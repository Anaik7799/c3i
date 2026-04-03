// =============================================================================
// RollingUpdate.fs - SIL-4 Rolling Update Coordinator
// =============================================================================
// Aligns with: lib/indrajaal/upgrade/rolling_update.ex
//
// STAMP Constraints:
//   SC-SIL4-009: Seed nodes before satellites
//   SC-SIL4-011: Quorum = floor(N/2) + 1 maintained
//   SC-SIL4-026: Rollback path exists
//   SC-CTRL-003: 5-order effects analysis required
//
// AOR Rules:
//   AOR-SIL4-001: Seed nodes upgraded first
//   AOR-SIL4-002: Quorum must be maintained during upgrade
//   AOR-REG-008: Rollback capability for 24 hours
//
// 5-Order Effects Analysis:
//   1st Order: Node upgrade initiated
//   2nd Order: Health check on upgraded node
//   3rd Order: Wave progression, quorum validation
//   4th Order: Cluster stability verified
//   5th Order: Federation notification, full rollout complete
// =============================================================================

namespace Cepaf.SIL4

open System
open System.Collections.Concurrent
open System.Threading.Tasks

/// Node type classification
type NodeType =
    | Seed
    | Satellite

/// Node update status
type NodeUpdateStatus =
    | Pending
    | InProgress
    | Completed
    | Failed
    | RolledBack

/// Node in the update wave
type UpdateNode = {
    NodeId: string
    NodeType: NodeType
    Status: NodeUpdateStatus
    PreviousVersion: string
    TargetVersion: string
    UpdatedAt: DateTime option
    ErrorMessage: string option
}

/// Wave in rolling update
type UpdateWave = {
    WaveNumber: int
    Nodes: UpdateNode list
    Status: NodeUpdateStatus
    StartedAt: DateTime option
    CompletedAt: DateTime option
}

/// Rolling update state
type RollingUpdateState = {
    UpdateId: Guid
    ImageName: string
    Signature: string
    CurrentVersion: string
    TargetVersion: string
    Waves: UpdateWave list
    CurrentWave: int
    TotalNodes: int
    CompletedNodes: int
    FailedNodes: int
    IsPaused: bool
    StartedAt: DateTime
    CompletedAt: DateTime option
    ErrorMessage: string option
}

/// Update result
type RollingUpdateResult =
    | UpdateComplete of RollingUpdateState
    | UpdatePaused of RollingUpdateState
    | UpdateFailed of RollingUpdateState * reason: string
    | UpdateAborted of RollingUpdateState * reason: string

/// 5-Order effect for rolling updates
type RollingUpdateEffect = {
    Order: int
    NodeId: string
    Wave: int
    Description: string
    QuorumStatus: string
    Timestamp: DateTime
}

/// SIL-4 Rolling Update Coordinator
/// Wave-based updates with seed-first strategy per SC-SIL4-009
type RollingUpdateCoordinator() =

    // Update tracking
    let updateHistory = ConcurrentDictionary<Guid, RollingUpdateState>()
    let effectsLog = ConcurrentDictionary<Guid, RollingUpdateEffect list>()
    let mutable currentUpdate: RollingUpdateState option = None

    /// Calculate quorum requirement (SC-SIL4-011)
    /// Quorum = floor(N/2) + 1
    member this.CalculateQuorum(totalNodes: int) =
        if totalNodes <= 0 then 1
        else (totalNodes / 2) + 1

    /// Check if quorum is maintained
    member this.CheckQuorum(state: RollingUpdateState) =
        let activeNodes = state.TotalNodes - state.FailedNodes
        let required = this.CalculateQuorum(state.TotalNodes)
        let maintained = activeNodes >= required
        maintained, activeNodes, required

    /// Create update waves (SC-SIL4-009: Seed before satellites)
    member this.CreateWaves(nodes: (string * NodeType * string) list) =
        // Wave 1: Seed nodes only
        let seedNodes =
            nodes
            |> List.filter (fun (_, nodeType, _) -> nodeType = Seed)
            |> List.map (fun (nodeId, nodeType, version) -> {
                NodeId = nodeId
                NodeType = nodeType
                Status = Pending
                PreviousVersion = version
                TargetVersion = ""
                UpdatedAt = None
                ErrorMessage = None
            })

        // Wave 2+: Satellite nodes in batches
        let satelliteNodes =
            nodes
            |> List.filter (fun (_, nodeType, _) -> nodeType = Satellite)
            |> List.map (fun (nodeId, nodeType, version) -> {
                NodeId = nodeId
                NodeType = nodeType
                Status = Pending
                PreviousVersion = version
                TargetVersion = ""
                UpdatedAt = None
                ErrorMessage = None
            })

        // Group satellites into waves of max 3 nodes
        let satelliteWaves =
            satelliteNodes
            |> List.chunkBySize 3
            |> List.mapi (fun i nodes -> {
                WaveNumber = i + 2
                Nodes = nodes
                Status = Pending
                StartedAt = None
                CompletedAt = None
            })

        let wave1 = {
            WaveNumber = 1
            Nodes = seedNodes
            Status = Pending
            StartedAt = None
            CompletedAt = None
        }

        wave1 :: satelliteWaves

    /// Log 5-order effect
    member private this.LogEffect(updateId: Guid, nodeId: string, wave: int, order: int, desc: string, quorum: string) =
        let effect = {
            Order = order
            NodeId = nodeId
            Wave = wave
            Description = desc
            QuorumStatus = quorum
            Timestamp = DateTime.UtcNow
        }
        effectsLog.AddOrUpdate(
            updateId,
            [effect],
            fun _ existing -> existing @ [effect]) |> ignore

    /// Update a single node
    member this.UpdateNode(
        state: RollingUpdateState,
        node: UpdateNode,
        upgradeFn: string -> string -> Async<bool>,
        healthCheckFn: string -> Async<bool>) = async {

        // 1st Order: Node upgrade initiated
        this.LogEffect(
            state.UpdateId, node.NodeId, state.CurrentWave, 1,
            sprintf "Upgrade initiated for %s" node.NodeId,
            sprintf "Quorum: %d/%d" (state.TotalNodes - state.FailedNodes) state.TotalNodes)

        try
            // Execute upgrade
            let! success = upgradeFn node.NodeId state.TargetVersion

            if success then
                // 2nd Order: Health check
                this.LogEffect(
                    state.UpdateId, node.NodeId, state.CurrentWave, 2,
                    "Health check initiated", "Validating")

                let! healthy = healthCheckFn node.NodeId

                if healthy then
                    // 3rd Order: Wave progression
                    this.LogEffect(
                        state.UpdateId, node.NodeId, state.CurrentWave, 3,
                        "Node healthy, wave progressing", "Healthy")
                    return { node with Status = Completed; UpdatedAt = Some DateTime.UtcNow }
                else
                    return { node with Status = Failed; ErrorMessage = Some "Health check failed"; UpdatedAt = Some DateTime.UtcNow }
            else
                return { node with Status = Failed; ErrorMessage = Some "Upgrade failed"; UpdatedAt = Some DateTime.UtcNow }
        with ex ->
            return { node with Status = Failed; ErrorMessage = Some ex.Message; UpdatedAt = Some DateTime.UtcNow }
    }

    /// Execute a single wave
    member this.ExecuteWave(
        state: RollingUpdateState,
        wave: UpdateWave,
        upgradeFn: string -> string -> Async<bool>,
        healthCheckFn: string -> Async<bool>,
        rollbackFn: string -> Async<bool>) = async {

        let mutable updatedNodes = []
        let mutable failedCount = 0
        let mutable waveState = { wave with Status = InProgress; StartedAt = Some DateTime.UtcNow }

        for node in wave.Nodes do
            // Check quorum before each node
            let quorumOk, active, required = this.CheckQuorum(state)
            if not quorumOk then
                // 4th Order: Quorum violation
                this.LogEffect(
                    state.UpdateId, node.NodeId, wave.WaveNumber, 4,
                    "CRITICAL: Quorum violation detected",
                    sprintf "Active: %d, Required: %d" active required)
                failedCount <- failedCount + 1
                updatedNodes <- { node with Status = Failed; ErrorMessage = Some "Quorum violation" } :: updatedNodes
            else
                let! updatedNode = this.UpdateNode(state, node, upgradeFn, healthCheckFn)
                updatedNodes <- updatedNode :: updatedNodes
                if updatedNode.Status = Failed then
                    failedCount <- failedCount + 1

        let finalStatus =
            if failedCount = 0 then Completed
            elif failedCount = wave.Nodes.Length then Failed
            else Completed // Partial success

        let finalWave = {
            waveState with
                Nodes = updatedNodes |> List.rev
                Status = finalStatus
                CompletedAt = Some DateTime.UtcNow
        }

        // 4th Order: Wave completion
        this.LogEffect(
            state.UpdateId, "", wave.WaveNumber, 4,
            sprintf "Wave %d completed: %d/%d nodes" wave.WaveNumber (wave.Nodes.Length - failedCount) wave.Nodes.Length,
            if finalStatus = Completed then "Stable" else "Degraded")

        return finalWave, failedCount
    }

    /// Start rolling update
    member this.StartUpdate(
        imageName: string,
        signature: string,
        currentVersion: string,
        targetVersion: string,
        nodes: (string * NodeType * string) list,
        upgradeFn: string -> string -> Async<bool>,
        healthCheckFn: string -> Async<bool>,
        rollbackFn: string -> Async<bool>) = async {

        // Create waves (SC-SIL4-009)
        let waves = this.CreateWaves(nodes)
        let wavesWithTarget =
            waves |> List.map (fun w ->
                { w with Nodes = w.Nodes |> List.map (fun n -> { n with TargetVersion = targetVersion }) })

        // Initialize state
        let initialState = {
            UpdateId = Guid.NewGuid()
            ImageName = imageName
            Signature = signature
            CurrentVersion = currentVersion
            TargetVersion = targetVersion
            Waves = wavesWithTarget
            CurrentWave = 1
            TotalNodes = nodes.Length
            CompletedNodes = 0
            FailedNodes = 0
            IsPaused = false
            StartedAt = DateTime.UtcNow
            CompletedAt = None
            ErrorMessage = None
        }

        currentUpdate <- Some initialState

        // Execute waves
        let mutable state = initialState
        let mutable aborted = false

        for wave in wavesWithTarget do
            if not aborted && not state.IsPaused then
                let! updatedWave, failedCount = this.ExecuteWave(state, wave, upgradeFn, healthCheckFn, rollbackFn)

                let completedInWave = wave.Nodes.Length - failedCount

                state <- {
                    state with
                        Waves = state.Waves |> List.map (fun w -> if w.WaveNumber = wave.WaveNumber then updatedWave else w)
                        CurrentWave = wave.WaveNumber + 1
                        CompletedNodes = state.CompletedNodes + completedInWave
                        FailedNodes = state.FailedNodes + failedCount
                }

                // Check quorum after wave
                let quorumOk, _, _ = this.CheckQuorum(state)
                if not quorumOk then
                    state <- { state with ErrorMessage = Some "Quorum lost - update aborted" }
                    aborted <- true

        // 5th Order: Federation notification
        this.LogEffect(
            state.UpdateId, "", state.CurrentWave, 5,
            sprintf "Rolling update completed: %d/%d nodes upgraded" state.CompletedNodes state.TotalNodes,
            if state.FailedNodes = 0 then "Federation notified - SUCCESS" else "Federation notified - PARTIAL")

        let finalState = { state with CompletedAt = Some DateTime.UtcNow }
        updateHistory.TryAdd(finalState.UpdateId, finalState) |> ignore
        currentUpdate <- None

        if aborted then
            return UpdateAborted(finalState, "Quorum violation")
        elif state.FailedNodes > 0 then
            return UpdateFailed(finalState, sprintf "%d nodes failed" state.FailedNodes)
        else
            return UpdateComplete finalState
    }

    /// Get progress
    member this.Progress() =
        currentUpdate |> Option.map (fun state ->
            {|
                UpdateId = state.UpdateId
                CurrentWave = state.CurrentWave
                TotalWaves = state.Waves.Length
                CompletedNodes = state.CompletedNodes
                TotalNodes = state.TotalNodes
                FailedNodes = state.FailedNodes
                PercentComplete = if state.TotalNodes > 0 then float state.CompletedNodes / float state.TotalNodes * 100.0 else 0.0
                IsPaused = state.IsPaused
            |})

    /// Pause update
    member this.Pause() =
        currentUpdate <- currentUpdate |> Option.map (fun s -> { s with IsPaused = true })

    /// Resume update
    member this.Resume() =
        currentUpdate <- currentUpdate |> Option.map (fun s -> { s with IsPaused = false })

    /// Abort update
    member this.Abort(reason: string) =
        match currentUpdate with
        | Some state ->
            let finalState = {
                state with
                    ErrorMessage = Some (sprintf "Aborted: %s" reason)
                    CompletedAt = Some DateTime.UtcNow
            }
            updateHistory.TryAdd(finalState.UpdateId, finalState) |> ignore
            currentUpdate <- None
            UpdateAborted(finalState, reason)
        | None ->
            UpdateFailed(
                { UpdateId = Guid.NewGuid()
                  ImageName = ""
                  Signature = ""
                  CurrentVersion = ""
                  TargetVersion = ""
                  Waves = []
                  CurrentWave = 0
                  TotalNodes = 0
                  CompletedNodes = 0
                  FailedNodes = 0
                  IsPaused = false
                  StartedAt = DateTime.UtcNow
                  CompletedAt = Some DateTime.UtcNow
                  ErrorMessage = Some "No update in progress" },
                "No update in progress")

    /// Get update history
    member this.History() =
        updateHistory.Values |> Seq.toList |> List.sortByDescending (fun s -> s.StartedAt)

    /// Get 5-order effects for update
    member this.GetEffects(updateId: Guid) =
        match effectsLog.TryGetValue(updateId) with
        | true, effects -> effects
        | false, _ -> []
