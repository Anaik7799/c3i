// =============================================================================
// ZenohCheckpoints.fs - Zenoh Checkpoint Messaging for Boot Sequence
// =============================================================================
// STAMP: SC-ZTEST-001 to SC-ZTEST-008 (Zenoh test messaging constraints)
// AOR: AOR-ZENOH-007 (Publish node health every 10s), AOR-ZENOH-008
//
// ## Purpose
// Implements Zenoh checkpoint messaging for real-time boot progress tracking.
// Replaces log-based verification with <100ms pub/sub feedback.
//
// ## Key Benefits
// - Real-time feedback: <100ms latency vs 5-30s log parsing
// - Structured messages: JSON payloads with checkpoint IDs
// - State vectors: Track boot progress across all phases
// - Dashboard integration: Direct feed to LiveView
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 1.0.0 |
// | Created | 2026-01-18 |
// | Author | Claude Opus 4.5 |
// | Reference | 20260118-1615-sil6-biomorphic-startup-master-specification.md |
// =============================================================================

namespace Cepaf.Mesh

open System
open System.Text.Json
open System.Text.Json.Serialization

/// Type of checkpoint event
type CheckpointType =
    | BootPhaseStart
    | BootPhaseComplete
    | ContainerStarted
    | ContainerHealthy
    | ContainerFailed
    | QuorumAchieved
    | QuorumLost
    | StateVectorUpdate
    | BootComplete
    | BootFailed
    | HealthCheck
    | MetricsUpdate

/// Phase state for state vector
type PhaseStatus =
    | Pending = 0
    | Running = 1
    | Complete = 2
    | Failed = 3
    | Skipped = 4

/// Checkpoint message payload
type CheckpointMessage = {
    [<JsonPropertyName("type")>]
    Type: string

    [<JsonPropertyName("checkpoint_id")>]
    CheckpointId: string

    [<JsonPropertyName("phase")>]
    Phase: int

    [<JsonPropertyName("timestamp")>]
    Timestamp: string

    [<JsonPropertyName("container")>]
    Container: string option

    [<JsonPropertyName("state_vector")>]
    StateVector: int array

    [<JsonPropertyName("duration_ms")>]
    DurationMs: int option

    [<JsonPropertyName("details")>]
    Details: Map<string, string>

    [<JsonPropertyName("metrics")>]
    Metrics: Map<string, float> option
}

/// Boot state vector tracking
type BootStateVector = {
    Phases: PhaseStatus array       // 7 phases: P0-P6
    Containers: Map<string, PhaseStatus>
    QuorumStatus: int * int         // (healthy, total)
    OverallHealth: float            // 0.0 to 1.0
    BootStartTime: DateTime
    LastUpdateTime: DateTime
    CriticalPathProgress: float     // 0.0 to 1.0
}

/// Zenoh checkpoint operations
module ZenohCheckpoints =

    /// Checkpoint IDs for boot sequence
    module CheckpointIds =
        let BOOT_01 = "CP-BOOT-01"  // Preflight start
        let BOOT_02 = "CP-BOOT-02"  // DAG validated
        let BOOT_03 = "CP-BOOT-03"  // DB healthy
        let BOOT_04 = "CP-BOOT-04"  // OBS healthy
        let BOOT_05 = "CP-BOOT-05"  // Zenoh 2oo3 quorum
        let BOOT_06 = "CP-BOOT-06"  // Bridge healthy
        let BOOT_07 = "CP-BOOT-07"  // Cortex healthy
        let BOOT_08 = "CP-BOOT-08"  // App-1 healthy
        let BOOT_09 = "CP-BOOT-09"  // Homeostasis verified
        let BOOT_10 = "CP-BOOT-10"  // Boot complete

    /// Topic patterns for Zenoh pub/sub
    module Topics =
        let bootBase = "indrajaal/boot"

        let phaseStart phase = $"{bootBase}/phase/{phase}/start"
        let phaseComplete phase = $"{bootBase}/phase/{phase}/complete"
        let phaseFailed phase = $"{bootBase}/phase/{phase}/failed"

        let containerStarted name = $"{bootBase}/container/{name}/started"
        let containerHealthy name = $"{bootBase}/container/{name}/healthy"
        let containerFailed name = $"{bootBase}/container/{name}/failed"

        let quorumStatus = $"{bootBase}/zenoh/quorum"
        let stateVector = $"{bootBase}/state_vector"
        let dagValidated = $"{bootBase}/dag/validated"
        let bootComplete = $"{bootBase}/complete"
        let bootFailed = $"{bootBase}/failed"
        let metrics = $"{bootBase}/metrics"

    /// Create initial boot state vector
    let createStateVector () : BootStateVector = {
        Phases = Array.create 7 PhaseStatus.Pending
        Containers = Map.empty
        QuorumStatus = (0, 3)
        OverallHealth = 0.0
        BootStartTime = DateTime.UtcNow
        LastUpdateTime = DateTime.UtcNow
        CriticalPathProgress = 0.0
    }

    /// Update phase status in state vector
    let updatePhase (phase: int) (status: PhaseStatus) (vector: BootStateVector) : BootStateVector =
        if phase < 0 || phase >= 7 then vector
        else
            let newPhases = Array.copy vector.Phases
            newPhases.[phase] <- status

            let completedCount =
                newPhases
                |> Array.filter (fun s -> s = PhaseStatus.Complete)
                |> Array.length

            let health = float completedCount / 7.0

            { vector with
                Phases = newPhases
                OverallHealth = health
                LastUpdateTime = DateTime.UtcNow }

    /// Update container status
    let updateContainer (container: string) (status: PhaseStatus) (vector: BootStateVector) : BootStateVector =
        { vector with
            Containers = vector.Containers |> Map.add container status
            LastUpdateTime = DateTime.UtcNow }

    /// Update quorum status
    let updateQuorum (healthy: int) (total: int) (vector: BootStateVector) : BootStateVector =
        { vector with
            QuorumStatus = (healthy, total)
            LastUpdateTime = DateTime.UtcNow }

    /// Convert state vector to int array for JSON
    let stateVectorToArray (vector: BootStateVector) : int array =
        vector.Phases |> Array.map int

    /// Create a checkpoint message
    let createMessage
        (checkpointType: CheckpointType)
        (checkpointId: string)
        (phase: int)
        (container: string option)
        (stateVector: BootStateVector)
        (durationMs: int option)
        (details: Map<string, string>) : CheckpointMessage =

        let typeString =
            match checkpointType with
            | BootPhaseStart -> "boot_phase_start"
            | BootPhaseComplete -> "boot_phase_complete"
            | ContainerStarted -> "container_started"
            | ContainerHealthy -> "container_healthy"
            | ContainerFailed -> "container_failed"
            | QuorumAchieved -> "quorum_achieved"
            | QuorumLost -> "quorum_lost"
            | StateVectorUpdate -> "state_vector_update"
            | BootComplete -> "boot_complete"
            | BootFailed -> "boot_failed"
            | HealthCheck -> "health_check"
            | MetricsUpdate -> "metrics_update"

        {
            Type = typeString
            CheckpointId = checkpointId
            Phase = phase
            Timestamp = DateTime.UtcNow.ToString("o")
            Container = container
            StateVector = stateVectorToArray stateVector
            DurationMs = durationMs
            Details = details
            Metrics = None
        }

    /// Serialize message to JSON
    let toJson (msg: CheckpointMessage) : string =
        let options = JsonSerializerOptions(WriteIndented = false)
        options.DefaultIgnoreCondition <- JsonIgnoreCondition.WhenWritingNull
        JsonSerializer.Serialize(msg, options)

    /// Get topic for checkpoint type
    let getTopic (checkpointType: CheckpointType) (phase: int) (container: string option) : string =
        match checkpointType with
        | BootPhaseStart -> Topics.phaseStart phase
        | BootPhaseComplete -> Topics.phaseComplete phase
        | ContainerStarted -> container |> Option.map Topics.containerStarted |> Option.defaultValue Topics.bootBase
        | ContainerHealthy -> container |> Option.map Topics.containerHealthy |> Option.defaultValue Topics.bootBase
        | ContainerFailed -> container |> Option.map Topics.containerFailed |> Option.defaultValue Topics.bootBase
        | QuorumAchieved -> Topics.quorumStatus
        | QuorumLost -> Topics.quorumStatus
        | StateVectorUpdate -> Topics.stateVector
        | BootComplete -> Topics.bootComplete
        | BootFailed -> Topics.bootFailed
        | HealthCheck -> Topics.stateVector
        | MetricsUpdate -> Topics.metrics

    /// Create boot phase start message
    let phaseStartMessage (phase: int) (phaseName: string) (vector: BootStateVector) : string * CheckpointMessage =
        let checkpointId = $"CP-BOOT-{phase + 1:D2}"
        let details = Map.ofList [("phase_name", phaseName)]
        let msg = createMessage BootPhaseStart checkpointId phase None vector None details
        (Topics.phaseStart phase, msg)

    /// Create boot phase complete message
    let phaseCompleteMessage (phase: int) (durationMs: int) (vector: BootStateVector) : string * CheckpointMessage =
        let checkpointId = $"CP-BOOT-{phase + 1:D2}"
        let msg = createMessage BootPhaseComplete checkpointId phase None vector (Some durationMs) Map.empty
        (Topics.phaseComplete phase, msg)

    /// Create container healthy message
    let containerHealthyMessage (container: string) (phase: int) (durationMs: int) (vector: BootStateVector) : string * CheckpointMessage =
        let checkpointId = $"CP-BOOT-CONTAINER-{container.ToUpperInvariant()}"
        let msg = createMessage ContainerHealthy checkpointId phase (Some container) vector (Some durationMs) Map.empty
        (Topics.containerHealthy container, msg)

    /// Create quorum achieved message
    let quorumAchievedMessage (healthy: int) (total: int) (vector: BootStateVector) : string * CheckpointMessage =
        let details = Map.ofList [("healthy", string healthy); ("total", string total)]
        let msg = createMessage QuorumAchieved CheckpointIds.BOOT_05 2 None vector None details
        (Topics.quorumStatus, msg)

    /// Create boot complete message
    let bootCompleteMessage (totalDurationMs: int) (vector: BootStateVector) : string * CheckpointMessage =
        let details = Map.ofList [("status", "success")]
        let msg = createMessage BootComplete CheckpointIds.BOOT_10 6 None vector (Some totalDurationMs) details
        (Topics.bootComplete, msg)

    /// Create boot failed message
    let bootFailedMessage (reason: string) (failedPhase: int) (vector: BootStateVector) : string * CheckpointMessage =
        let checkpointId = $"CP-BOOT-FAIL-{failedPhase}"
        let details = Map.ofList [("reason", reason); ("failed_phase", string failedPhase)]
        let msg = createMessage BootFailed checkpointId failedPhase None vector None details
        (Topics.bootFailed, msg)

    /// Publish checkpoint message via SC-ZTEST-008 dual-write pattern.
    /// Writes log fallback first, then structured JSON for CEPAF bridge.
    let publishCheckpoint (topic: string) (msg: CheckpointMessage) : unit =
        let stateVectorStr = sprintf "[%s]" (msg.StateVector |> Array.map string |> String.concat ",")
        let message = msg.Type
        let payload = sprintf """{"type":"%s","checkpoint":"%s","state_vector":%s,"phase":%d}"""
                        msg.Type msg.CheckpointId stateVectorStr msg.Phase
        ZenohPublish.publishWithStateVector msg.CheckpointId topic message stateVectorStr payload

        // Also print colored console output for operator visibility
        let color =
            match msg.Type with
            | "boot_complete" -> "\u001b[32m"
            | "boot_failed" | "container_failed" -> "\u001b[31m"
            | "quorum_achieved" | "container_healthy" -> "\u001b[32m"
            | _ -> "\u001b[36m"
        printfn "%s[ZENOH]%s %s → %s [%s] (checkpoint: %s)"
            color "\u001b[0m"
            msg.Type topic (msg.StateVector |> Array.map string |> String.concat ",") msg.CheckpointId

    /// Backwards-compatible alias for printCheckpoint
    let printCheckpoint (topic: string) (msg: CheckpointMessage) : unit =
        publishCheckpoint topic msg

    /// Print state vector visualization
    let printStateVector (vector: BootStateVector) : unit =
        let phaseNames = [| "P0:Preflight"; "P1:Foundation"; "P2:Control"; "P3:Cognitive"; "P4:App"; "P5:Homeostasis"; "P6:Swarm" |]

        printfn ""
        printfn "╔═══════════════════════════════════════════════════════════════════╗"
        printfn "║                    BOOT STATE VECTOR                               ║"
        printfn "╠═══════════════════════════════════════════════════════════════════╣"

        for i in 0..6 do
            let status = vector.Phases.[i]
            let (color, icon) =
                match status with
                | PhaseStatus.Pending -> ("\u001b[90m", "○")
                | PhaseStatus.Running -> ("\u001b[33m", "◐")
                | PhaseStatus.Complete -> ("\u001b[32m", "●")
                | PhaseStatus.Failed -> ("\u001b[31m", "✗")
                | PhaseStatus.Skipped -> ("\u001b[90m", "⊘")
                | _ -> ("\u001b[90m", "?")

            printfn "║  %s%s %s%-12s\u001b[0m                                              ║"
                color icon color phaseNames.[i]

        printfn "╠═══════════════════════════════════════════════════════════════════╣"
        let (healthy, total) = vector.QuorumStatus
        printfn "║  Quorum: %d/%d    Health: %.0f%%    Progress: %.0f%%                   ║"
            healthy total (vector.OverallHealth * 100.0) (vector.CriticalPathProgress * 100.0)
        printfn "╚═══════════════════════════════════════════════════════════════════╝"
        printfn ""
