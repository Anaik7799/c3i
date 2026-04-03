namespace Cepaf.Zenoh

open System
open System.Text.Json
open Cepaf.Zenoh.ZenohSession

/// Zenoh publisher for boot phase transitions.
///
/// ## STAMP Constraints
/// - SC-ZTEST-009: Publish on every phase transition
/// - SC-ZTEST-010: Include state vector in every message
/// - SC-ZTEST-011: Quorum status within 1s of change
///
/// ## Checkpoints Published
/// - CP-BOOT-01: Preflight start
/// - CP-BOOT-02: Preflight complete
/// - CP-BOOT-03: DB ready
/// - CP-BOOT-04: Observability ready
/// - CP-BOOT-05: Zenoh quorum achieved
/// - CP-BOOT-06: CEPAF bridge connected
/// - CP-BOOT-07: Cortex online
/// - CP-BOOT-08: App seed ready
/// - CP-BOOT-09: Homeostasis verified
/// - CP-BOOT-10: Boot complete
///
/// ## Usage
/// ```fsharp
/// BootPhasePublisher.phaseStarted Preflight 0 [] "[0,0,0,0,0,0]"
/// BootPhasePublisher.containerHealth "indrajaal-db-prod" true 234 "PostgreSQL ready"
/// BootPhasePublisher.quorumAchieved 2 3 routers
/// BootPhasePublisher.phaseFinished Preflight 0 5000 true "[1,0,0,0,0,0]"
/// ```
module BootPhasePublisher =

    // ========================================================================
    // TYPES
    // ========================================================================

    /// Boot phases
    type BootPhase =
        | Preflight
        | Foundation
        | Mesh
        | Cognitive
        | App
        | Homeostasis
        | Swarm

    /// Container status
    type ContainerStatus = {
        Name: string
        Status: string
        Healthy: bool
        Port: int option
        Uptime: string option
    }

    /// Router status for quorum
    type RouterStatus = {
        Name: string
        Healthy: bool
        Port: int
        Endpoint: string option
    }

    /// Quorum status
    type QuorumStatus =
        | Achieved
        | NotAchieved
        | InsufficientNodes

    // ========================================================================
    // CONSTANTS
    // ========================================================================

    let private schemaVersion = "1.0.0"

    let private nodeId () =
        Environment.MachineName

    // ========================================================================
    // PHASE MAPPING
    // ========================================================================

    let private phaseToStartCheckpoint = function
        | Preflight -> "CP-BOOT-01"
        | Foundation -> "CP-BOOT-03"
        | Mesh -> "CP-BOOT-05"
        | Cognitive -> "CP-BOOT-06"
        | App -> "CP-BOOT-08"
        | Homeostasis -> "CP-BOOT-09"
        | Swarm -> "CP-BOOT-10"

    let private phaseToCompleteCheckpoint = function
        | Preflight -> "CP-BOOT-02"
        | Foundation -> "CP-BOOT-04"
        | Mesh -> "CP-BOOT-05"
        | Cognitive -> "CP-BOOT-07"
        | App -> "CP-BOOT-08"
        | Homeostasis -> "CP-BOOT-09"
        | Swarm -> "CP-BOOT-10"

    let private checkpointToTopic (checkpoint: string) (phase: string) (event: string) =
        match checkpoint with
        | "CP-BOOT-01" -> "indrajaal/boot/preflight/start"
        | "CP-BOOT-02" -> "indrajaal/boot/preflight/complete"
        | "CP-BOOT-03" -> "indrajaal/boot/foundation/db_ready"
        | "CP-BOOT-04" -> "indrajaal/boot/foundation/obs_ready"
        | "CP-BOOT-05" -> "indrajaal/boot/mesh/quorum"
        | "CP-BOOT-06" -> "indrajaal/boot/cognitive/bridge"
        | "CP-BOOT-07" -> "indrajaal/boot/cognitive/cortex"
        | "CP-BOOT-08" -> "indrajaal/boot/app/seed_ready"
        | "CP-BOOT-09" -> "indrajaal/boot/homeostasis/verified"
        | "CP-BOOT-10" -> "indrajaal/boot/complete"
        | _ -> sprintf "indrajaal/boot/%s/%s" phase event

    // ========================================================================
    // MESSAGE BUILDERS
    // ========================================================================

    /// Build phase started message
    let private buildPhaseStartedMessage (phase: BootPhase) (wave: int) (containers: string list) (stateVector: string) =
        let checkpoint = phaseToStartCheckpoint phase
        {|
            schema_version = schemaVersion
            message_id = Guid.NewGuid().ToString("N")
            ``type`` = "boot_checkpoint"
            checkpoint = checkpoint
            phase = phase.ToString().ToLowerInvariant()
            wave = wave
            containers = containers
            state_vector = stateVector
            timestamp = DateTimeOffset.UtcNow.ToString("o")
            source = "fsharp"
            node_id = nodeId()
        |}

    /// Build phase finished message
    let private buildPhaseFinishedMessage (phase: BootPhase) (wave: int) (durationMs: int) (success: bool) (stateVector: string) =
        let checkpoint = phaseToCompleteCheckpoint phase
        {|
            schema_version = schemaVersion
            message_id = Guid.NewGuid().ToString("N")
            ``type`` = "boot_checkpoint"
            checkpoint = checkpoint
            phase = phase.ToString().ToLowerInvariant()
            wave = wave
            duration_ms = durationMs
            success = success
            state_vector = stateVector
            timestamp = DateTimeOffset.UtcNow.ToString("o")
            source = "fsharp"
            node_id = nodeId()
        |}

    /// Build container started message (CP-BOOT-TX-01)
    let private buildContainerStartedMessage (containerName: string) (wave: int) (port: int) =
        {|
            schema_version = schemaVersion
            message_id = Guid.NewGuid().ToString("N")
            ``type`` = "container_started"
            checkpoint = "CP-BOOT-TX-01"
            container = containerName
            wave = wave
            port = port
            timestamp = DateTimeOffset.UtcNow.ToString("o")
            source = "fsharp"
            node_id = nodeId()
        |}

    /// Build container health message (CP-BOOT-TX-02)
    let private buildContainerHealthMessage (containerName: string) (healthy: bool) (durationMs: int) (details: string) =
        {|
            schema_version = schemaVersion
            message_id = Guid.NewGuid().ToString("N")
            ``type`` = "container_health"
            checkpoint = "CP-BOOT-TX-02"
            container = containerName
            healthy = healthy
            check_duration_ms = durationMs
            details = details
            timestamp = DateTimeOffset.UtcNow.ToString("o")
            source = "fsharp"
            node_id = nodeId()
        |}

    /// Build quorum status message (CP-BOOT-TX-03)
    let private buildQuorumStatusMessage (status: QuorumStatus) (healthyCount: int) (totalCount: int) (routers: RouterStatus list) =
        {|
            schema_version = schemaVersion
            message_id = Guid.NewGuid().ToString("N")
            ``type`` = "quorum_status"
            checkpoint = "CP-BOOT-TX-03"
            status = status.ToString()
            healthy_count = healthyCount
            total_count = totalCount
            routers = routers |> List.map (fun r ->
                {| name = r.Name; healthy = r.Healthy; port = r.Port |})
            timestamp = DateTimeOffset.UtcNow.ToString("o")
            source = "fsharp"
            node_id = nodeId()
        |}

    /// Build state vector update message (CP-BOOT-TX-04)
    let private buildStateVectorMessage (vector: string) (components: Map<string, string>) =
        {|
            schema_version = schemaVersion
            message_id = Guid.NewGuid().ToString("N")
            ``type`` = "state_vector"
            checkpoint = "CP-BOOT-TX-04"
            vector = vector
            components = components |> Map.toSeq |> Seq.map (fun (k, v) -> k, box v) |> dict
            timestamp = DateTimeOffset.UtcNow.ToString("o")
            source = "fsharp"
            node_id = nodeId()
        |}

    /// Build boot complete message
    let private buildBootCompleteMessage (totalDurationMs: int) (containerCount: int) (stateVector: string) =
        {|
            schema_version = schemaVersion
            message_id = Guid.NewGuid().ToString("N")
            ``type`` = "boot_checkpoint"
            checkpoint = "CP-BOOT-10"
            total_duration_ms = totalDurationMs
            containers = containerCount
            state_vector = stateVector
            status = "operational"
            timestamp = DateTimeOffset.UtcNow.ToString("o")
            source = "fsharp"
            node_id = nodeId()
        |}

    // ========================================================================
    // PUBLISHING API - PHASE EVENTS
    // ========================================================================

    /// Publish phase started event
    let phaseStarted (phase: BootPhase) (wave: int) (containers: string list) (stateVector: string) =
        let message = buildPhaseStartedMessage phase wave containers stateVector
        let json = JsonSerializer.Serialize(message)
        let checkpoint = phaseToStartCheckpoint phase
        let topic = checkpointToTopic checkpoint (phase.ToString().ToLowerInvariant()) "start"
        publishJson topic json

    /// Publish phase finished event
    let phaseFinished (phase: BootPhase) (wave: int) (durationMs: int) (success: bool) (stateVector: string) =
        let message = buildPhaseFinishedMessage phase wave durationMs success stateVector
        let json = JsonSerializer.Serialize(message)
        let checkpoint = phaseToCompleteCheckpoint phase
        let topic = checkpointToTopic checkpoint (phase.ToString().ToLowerInvariant()) "complete"
        publishJson topic json

    // ========================================================================
    // PUBLISHING API - CONTAINER EVENTS
    // ========================================================================

    /// Publish container started event
    let containerStarted (containerName: string) (wave: int) (port: int) =
        let message = buildContainerStartedMessage containerName wave port
        let json = JsonSerializer.Serialize(message)
        let topic = sprintf "indrajaal/boot/container/%s/started" containerName
        publishJson topic json

    /// Publish container health check event
    let containerHealth (containerName: string) (healthy: bool) (durationMs: int) (details: string) =
        let message = buildContainerHealthMessage containerName healthy durationMs details
        let json = JsonSerializer.Serialize(message)
        let topic = sprintf "indrajaal/boot/container/%s/health" containerName
        publishJson topic json

    /// Publish container ready event
    let containerReady (containerName: string) (healthy: bool) =
        let message = {|
            schema_version = schemaVersion
            message_id = Guid.NewGuid().ToString("N")
            ``type`` = "container_ready"
            checkpoint = "CP-BOOT-TX-05"
            container = containerName
            healthy = healthy
            timestamp = DateTimeOffset.UtcNow.ToString("o")
            source = "fsharp"
            node_id = nodeId()
        |}
        let json = JsonSerializer.Serialize(message)
        let topic = sprintf "indrajaal/boot/container/%s/ready" containerName
        publishJson topic json

    // ========================================================================
    // PUBLISHING API - QUORUM EVENTS
    // ========================================================================

    /// Publish quorum status update
    let quorumStatus (status: QuorumStatus) (healthyCount: int) (totalCount: int) (routers: RouterStatus list) =
        let message = buildQuorumStatusMessage status healthyCount totalCount routers
        let json = JsonSerializer.Serialize(message)
        publishJson "indrajaal/boot/mesh/quorum" json

    /// Shorthand for quorum achieved event
    let quorumAchieved (healthyCount: int) (totalCount: int) (routers: RouterStatus list) =
        quorumStatus Achieved healthyCount totalCount routers

    // ========================================================================
    // PUBLISHING API - STATE VECTOR EVENTS
    // ========================================================================

    /// Publish state vector update
    let stateVector (vector: string) (components: Map<string, string>) =
        let message = buildStateVectorMessage vector components
        let json = JsonSerializer.Serialize(message)
        publishJson "indrajaal/boot/state_vector" json

    // ========================================================================
    // PUBLISHING API - SPECIFIC CHECKPOINTS
    // ========================================================================

    /// Publish preflight start (CP-BOOT-01)
    let preflightStart (stateVector: string) =
        phaseStarted Preflight 0 [] stateVector

    /// Publish preflight complete (CP-BOOT-02)
    let preflightComplete (durationMs: int) (stateVector: string) =
        phaseFinished Preflight 0 durationMs true stateVector

    /// Publish database ready (CP-BOOT-03)
    let dbReady (durationMs: int) =
        let message = {|
            schema_version = schemaVersion
            message_id = Guid.NewGuid().ToString("N")
            ``type`` = "boot_checkpoint"
            checkpoint = "CP-BOOT-03"
            port = 5433
            duration_ms = durationMs
            healthy = true
            timestamp = DateTimeOffset.UtcNow.ToString("o")
            source = "fsharp"
            node_id = nodeId()
        |}
        let json = JsonSerializer.Serialize(message)
        publishJson "indrajaal/boot/foundation/db_ready" json

    /// Publish observability ready (CP-BOOT-04)
    let obsReady (durationMs: int) =
        let message = {|
            schema_version = schemaVersion
            message_id = Guid.NewGuid().ToString("N")
            ``type`` = "boot_checkpoint"
            checkpoint = "CP-BOOT-04"
            ports = [| 4317; 4318; 9090; 3000; 3100 |]
            duration_ms = durationMs
            healthy = true
            timestamp = DateTimeOffset.UtcNow.ToString("o")
            source = "fsharp"
            node_id = nodeId()
        |}
        let json = JsonSerializer.Serialize(message)
        publishJson "indrajaal/boot/foundation/obs_ready" json

    /// Publish CEPAF bridge connected (CP-BOOT-06)
    let bridgeConnected (durationMs: int) =
        let message = {|
            schema_version = schemaVersion
            message_id = Guid.NewGuid().ToString("N")
            ``type`` = "boot_checkpoint"
            checkpoint = "CP-BOOT-06"
            port = 9876
            duration_ms = durationMs
            timestamp = DateTimeOffset.UtcNow.ToString("o")
            source = "fsharp"
            node_id = nodeId()
        |}
        let json = JsonSerializer.Serialize(message)
        publishJson "indrajaal/boot/cognitive/bridge" json

    /// Publish Cortex online (CP-BOOT-07)
    let cortexOnline (durationMs: int) =
        let message = {|
            schema_version = schemaVersion
            message_id = Guid.NewGuid().ToString("N")
            ``type`` = "boot_checkpoint"
            checkpoint = "CP-BOOT-07"
            port = 9877
            duration_ms = durationMs
            timestamp = DateTimeOffset.UtcNow.ToString("o")
            source = "fsharp"
            node_id = nodeId()
        |}
        let json = JsonSerializer.Serialize(message)
        publishJson "indrajaal/boot/cognitive/cortex" json

    /// Publish app seed ready (CP-BOOT-08)
    let appReady (containerName: string) (durationMs: int) =
        let message = {|
            schema_version = schemaVersion
            message_id = Guid.NewGuid().ToString("N")
            ``type`` = "boot_checkpoint"
            checkpoint = "CP-BOOT-08"
            container = containerName
            port = 4000
            duration_ms = durationMs
            timestamp = DateTimeOffset.UtcNow.ToString("o")
            source = "fsharp"
            node_id = nodeId()
        |}
        let json = JsonSerializer.Serialize(message)
        publishJson "indrajaal/boot/app/seed_ready" json

    /// Publish homeostasis verified (CP-BOOT-09)
    let homeostasisVerified (healthChecks: Map<string, bool>) =
        let allHealthy = healthChecks |> Map.forall (fun _ v -> v)
        let message = {|
            schema_version = schemaVersion
            message_id = Guid.NewGuid().ToString("N")
            ``type`` = "boot_checkpoint"
            checkpoint = "CP-BOOT-09"
            checks = healthChecks |> Map.toSeq |> Seq.map (fun (k, v) -> k, box v) |> dict
            all_healthy = allHealthy
            timestamp = DateTimeOffset.UtcNow.ToString("o")
            source = "fsharp"
            node_id = nodeId()
        |}
        let json = JsonSerializer.Serialize(message)
        publishJson "indrajaal/boot/homeostasis/verified" json

    /// Publish boot complete (CP-BOOT-10)
    let bootComplete (totalDurationMs: int) (containerCount: int) (stateVector: string) =
        let message = buildBootCompleteMessage totalDurationMs containerCount stateVector
        let json = JsonSerializer.Serialize(message)
        publishJson "indrajaal/boot/complete" json
