namespace Cepaf.Cockpit

open System
open System.Text
open Cepaf.Cockpit.Domain

/// ═══════════════════════════════════════════════════════════════════════════════
/// C3I MESH COCKPIT - BRIDGE AGENT (MailboxProcessor)
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// WHAT: The synchronization context bridging async Zenoh data streams to the
///       single-threaded UI. Implements the Actor model for thread-safe state.
///
/// WHY: Isolates multi-threaded Zenoh callbacks from the UI rendering loop.
///      Enables high-frequency telemetry (1000 msg/sec) while UI renders at 10-20 FPS.
///
/// STAMP Compliance:
///   - SC-AGT-020: Actor isolation pattern
///   - SC-PRF-055: No blocking operations in UI thread
///   - SC-OBS-069: Dual logging to terminal and telemetry
///
/// ═══════════════════════════════════════════════════════════════════════════════
module BridgeAgent =

    // ═══════════════════════════════════════════════════════════════════════════
    // MESSAGE TYPES
    // ═══════════════════════════════════════════════════════════════════════════

    /// Messages that the Bridge Agent processes
    type SystemMsg =
        // Inbound from Zenoh
        | TelemetryReceived of key: string * payload: byte[] * timestamp: DateTime
        | AlarmReceived of key: string * payload: byte[]
        | CommandAck of commandId: CommandId * success: bool * message: string option

        // User Actions
        | SelectNode of NodeId option
        | SelectZone of ZoneId option
        | ChangeView of ViewMode
        | ExecuteCommand of CommandRecord
        | ArmCommand of NodeId * MeshCommand
        | ConfirmCommand of CommandId
        | CancelCommand of CommandId
        | AcknowledgeAlarm of AlarmId * operator: string

        // AI Integration
        | AiInsightReceived of AiInsight
        | RequestAiAnalysis of context: string

        // UI Lifecycle
        | Tick  // UI refresh signal (10-20 Hz)
        | Shutdown

        // Query
        | GetState of AsyncReplyChannel<CockpitState>

    // ═══════════════════════════════════════════════════════════════════════════
    // TELEMETRY PARSING
    // ═══════════════════════════════════════════════════════════════════════════

    /// Parse telemetry key: c3i/units/{zone}/{id}/telemetry
    let parseKeyExpression (key: string) : (ZoneId * NodeId) option =
        let parts = key.Split('/')
        if parts.Length >= 4 && parts.[0] = "c3i" && parts.[1] = "units" then
            Some (parts.[2], parts.[3])
        else
            None

    /// Deserialize telemetry payload (simplified - in production use MessagePack)
    let parseTelemetryPayload (payload: byte[]) : Map<string, float> option =
        try
            let json = Encoding.UTF8.GetString(payload)
            // Simple JSON parsing for demo - use proper serializer in production
            let pairs =
                json.Trim('{', '}', ' ')
                |> fun s -> s.Split(',')
                |> Array.choose (fun pair ->
                    let kv = pair.Split(':')
                    if kv.Length = 2 then
                        let k = kv.[0].Trim('"', ' ')
                        match Double.TryParse(kv.[1].Trim()) with
                        | true, v -> Some (k, v)
                        | false, _ -> None
                    else None
                )
                |> Map.ofArray
            Some pairs
        with _ -> None

    // ═══════════════════════════════════════════════════════════════════════════
    // STATE UPDATE LOGIC
    // ═══════════════════════════════════════════════════════════════════════════

    /// Update node with telemetry data
    let updateNodeTelemetry (data: Map<string, float>) (node: MeshNode) : MeshNode =
        let cpu =
            match Map.tryFind "cpu" data with
            | Some v -> updateMetric v node.Cpu
            | None -> node.Cpu

        let memory =
            match Map.tryFind "memory" data with
            | Some v -> updateMetric v node.Memory
            | None -> node.Memory

        let latency =
            match Map.tryFind "latency" data with
            | Some v -> updateMetric v node.NetworkLatency
            | None -> node.NetworkLatency

        let battery =
            match Map.tryFind "battery" data, node.Battery with
            | Some v, Some b -> Some (updateMetric v b)
            | Some v, None -> Some (updateMetric v (createMetric "Battery" "%" 0.0))
            | None, b -> b

        // Calculate health score based on metrics
        let healthValue =
            let cpuPenalty = if cpu.Value > 90.0 then 30 elif cpu.Value > 70.0 then 15 else 0
            let memPenalty = if memory.Value > 90.0 then 30 elif memory.Value > 70.0 then 15 else 0
            let latencyPenalty = if latency.Value > 1000.0 then 20 elif latency.Value > 500.0 then 10 else 0
            max 0 (100 - cpuPenalty - memPenalty - latencyPenalty)

        { node with
            Cpu = cpu
            Memory = memory
            NetworkLatency = latency
            Battery = battery
            Status = Connected
            HealthScore = updateMetric healthValue node.HealthScore
        }

    /// Apply staleness detection to all nodes
    let applyWatchdog (state: CockpitState) : CockpitState =
        let now = DateTime.UtcNow
        let updatedNodes =
            state.Nodes
            |> Map.map (fun _ node ->
                let staleSecs = (now - node.Cpu.LastUpdated).TotalSeconds
                if staleSecs > 30.0 then
                    { node with Status = Disconnected }
                elif staleSecs > 5.0 then
                    { node with Status = Stale }
                else
                    node
            )
        { state with Nodes = updatedNodes }

    /// Compute alarm level for a metric
    let computeAlarmLevel (value: float) (thresholds: Thresholds<float> option) : AlarmLevel =
        match thresholds with
        | None ->
            // Default thresholds for percentage-based metrics
            if value >= 95.0 then Warning
            elif value >= 85.0 then Caution
            elif value >= 75.0 then Advisory
            else Normal
        | Some t ->
            match t.WarningHigh with
            | Some w when value >= w -> Warning
            | _ ->
                match t.CautionHigh with
                | Some c when value >= c -> Caution
                | _ ->
                    match t.AdvisoryHigh with
                    | Some a when value >= a -> Advisory
                    | _ -> Normal

    // ═══════════════════════════════════════════════════════════════════════════
    // THE COCKPIT AGENT (MailboxProcessor)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create the cockpit agent - The Brain of the system
    let createCockpitAgent
        (render: CockpitState -> unit)
        (sendCommand: NodeId -> MeshCommand -> Async<Result<string, string>>)
        (requestAiInsight: string -> Async<AiInsight option>)
        (auditLog: string -> unit) =

        MailboxProcessor.Start(fun inbox ->
            let rec loop (state: CockpitState) = async {
                let! msg = inbox.Receive()

                match msg with
                // ─────────────────────────────────────────────────────────────
                // INBOUND TELEMETRY
                // ─────────────────────────────────────────────────────────────
                | TelemetryReceived (key, payload, timestamp) ->
                    match parseKeyExpression key, parseTelemetryPayload payload with
                    | Some (zone, nodeId), Some data ->
                        let node =
                            match Map.tryFind nodeId state.Nodes with
                            | Some existing -> updateNodeTelemetry data existing
                            | None ->
                                let newNode = createNode nodeId nodeId zone Worker
                                updateNodeTelemetry data newNode

                        let newState = {
                            state with
                                Nodes = Map.add nodeId node state.Nodes
                                MessagesReceived = state.MessagesReceived + 1L
                                LastMessageAt = Some timestamp
                        }
                        return! loop newState

                    | _ ->
                        return! loop { state with MessagesReceived = state.MessagesReceived + 1L }

                // ─────────────────────────────────────────────────────────────
                // ALARMS
                // ─────────────────────────────────────────────────────────────
                | AlarmReceived (key, payload) ->
                    // Parse and add alarm
                    let alarmId = Guid.NewGuid().ToString("N").[..7]
                    let alarm = {
                        Id = alarmId
                        NodeId = "unknown"  // Would parse from key
                        Level = Caution
                        Category = "System"
                        Message = Encoding.UTF8.GetString(payload)
                        Details = None
                        OccurredAt = DateTime.UtcNow
                        AcknowledgedAt = None
                        AcknowledgedBy = None
                        AutoClearable = false
                    }
                    let newState = { state with Alarms = Map.add alarmId alarm state.Alarms }
                    return! loop newState

                // ─────────────────────────────────────────────────────────────
                // COMMANDS (Two-Step Commit)
                // ─────────────────────────────────────────────────────────────
                | ArmCommand (nodeId, cmd) ->
                    if state.MonitorOnly then
                        return! loop state
                    else
                        let cmdId = Guid.NewGuid().ToString("N").[..7]
                        let record = {
                            Id = cmdId
                            TargetNodeId = nodeId
                            Command = cmd
                            State = Armed
                            ArmedAt = Some DateTime.UtcNow
                            ExecutedAt = None
                            AcknowledgedAt = None
                            ErrorMessage = None
                            RequiresConfirmation = isCriticalCommand cmd
                        }
                        auditLog (sprintf "ARMED: %s -> %A on %s" cmdId cmd nodeId)
                        let newState = { state with PendingCommands = Map.add cmdId record state.PendingCommands }
                        return! loop newState

                | ConfirmCommand cmdId ->
                    match Map.tryFind cmdId state.PendingCommands with
                    | Some record when record.State = Armed ->
                        auditLog (sprintf "CONFIRMED: %s executing %A" cmdId record.Command)
                        let updatedRecord = { record with State = Executing; ExecutedAt = Some DateTime.UtcNow }
                        let newState = { state with PendingCommands = Map.add cmdId updatedRecord state.PendingCommands }

                        // Send command asynchronously
                        Async.Start(async {
                            let! result = sendCommand record.TargetNodeId record.Command
                            match result with
                            | Ok _ -> inbox.Post(CommandAck(cmdId, true, None))
                            | Error msg -> inbox.Post(CommandAck(cmdId, false, Some msg))
                        })

                        return! loop newState
                    | _ -> return! loop state

                | CancelCommand cmdId ->
                    auditLog (sprintf "CANCELLED: %s" cmdId)
                    let newState = { state with PendingCommands = Map.remove cmdId state.PendingCommands }
                    return! loop newState

                | CommandAck (cmdId, success, message) ->
                    match Map.tryFind cmdId state.PendingCommands with
                    | Some record ->
                        let final = {
                            record with
                                State = if success then Acknowledged else Failed
                                AcknowledgedAt = Some DateTime.UtcNow
                                ErrorMessage = message
                        }
                        auditLog (sprintf "ACK: %s -> %A" cmdId (if success then "SUCCESS" else "FAILED"))
                        let pending = Map.remove cmdId state.PendingCommands
                        let history = final :: state.CommandHistory |> List.truncate 100
                        return! loop { state with PendingCommands = pending; CommandHistory = history }
                    | None -> return! loop state

                // ─────────────────────────────────────────────────────────────
                // USER ACTIONS
                // ─────────────────────────────────────────────────────────────
                | SelectNode nodeId ->
                    return! loop { state with SelectedNodeId = nodeId }

                | SelectZone zoneId ->
                    return! loop { state with SelectedZoneId = zoneId }

                | ChangeView view ->
                    return! loop { state with CurrentView = view }

                | AcknowledgeAlarm (alarmId, operator) ->
                    match Map.tryFind alarmId state.Alarms with
                    | Some alarm ->
                        let updated = {
                            alarm with
                                AcknowledgedAt = Some DateTime.UtcNow
                                AcknowledgedBy = Some operator
                        }
                        auditLog (sprintf "ALARM ACK: %s by %s" alarmId operator)
                        return! loop { state with Alarms = Map.add alarmId updated state.Alarms }
                    | None -> return! loop state

                // ─────────────────────────────────────────────────────────────
                // AI INTEGRATION
                // ─────────────────────────────────────────────────────────────
                | AiInsightReceived insight ->
                    let insights = insight :: state.Insights |> List.truncate 50
                    return! loop { state with Insights = insights; LastAiUpdate = Some DateTime.UtcNow }

                | RequestAiAnalysis context ->
                    if state.AiEnabled then
                        Async.Start(async {
                            let! maybeInsight = requestAiInsight context
                            match maybeInsight with
                            | Some insight -> inbox.Post(AiInsightReceived insight)
                            | None -> ()
                        })
                    return! loop state

                // ─────────────────────────────────────────────────────────────
                // UI LIFECYCLE
                // ─────────────────────────────────────────────────────────────
                | Tick ->
                    // 1. Apply watchdog (staleness detection)
                    let watchdogState = applyWatchdog state

                    // 2. Render (this happens at UI frequency, not message frequency)
                    render watchdogState

                    return! loop watchdogState

                | Shutdown ->
                    auditLog "COCKPIT SHUTDOWN"
                    return ()

                // ─────────────────────────────────────────────────────────────
                // QUERY
                // ─────────────────────────────────────────────────────────────
                | GetState channel ->
                    channel.Reply state
                    return! loop state

                | ExecuteCommand record ->
                    // Direct execution (for non-critical commands)
                    if record.RequiresConfirmation then
                        inbox.Post(ArmCommand(record.TargetNodeId, record.Command))
                    else
                        auditLog (sprintf "DIRECT: %A on %s" record.Command record.TargetNodeId)
                        Async.Start(async {
                            let! result = sendCommand record.TargetNodeId record.Command
                            match result with
                            | Ok _ -> inbox.Post(CommandAck(record.Id, true, None))
                            | Error msg -> inbox.Post(CommandAck(record.Id, false, Some msg))
                        })
                    return! loop state
            }

            loop (createCockpitState "operator-1")
        )

    // ═══════════════════════════════════════════════════════════════════════════
    // CONVENIENCE FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Start the UI tick loop
    let startTickLoop (agent: MailboxProcessor<SystemMsg>) (hz: int) =
        let interval = 1000 / hz
        async {
            while true do
                agent.Post Tick
                do! Async.Sleep interval
        }
        |> Async.Start

    /// Query current state synchronously
    let getState (agent: MailboxProcessor<SystemMsg>) : CockpitState =
        agent.PostAndReply(fun channel -> GetState channel)

    /// Post telemetry (from Zenoh callback)
    let postTelemetry (agent: MailboxProcessor<SystemMsg>) key payload =
        agent.Post(TelemetryReceived(key, payload, DateTime.UtcNow))
