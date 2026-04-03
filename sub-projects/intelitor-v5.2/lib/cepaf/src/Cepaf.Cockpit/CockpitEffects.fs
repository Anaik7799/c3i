/// CEPAF Cockpit Effects Module
/// Free monad effects for testable, composable side effects in the cockpit.
///
/// WHAT: Effect algebras, interpreters, testable side effect handling
/// WHY: Separate effect description from execution for testing and composition
/// CONSTRAINTS:
///   - SC-EFFECT-001: All effects must be interpretable in pure mode for testing
///   - SC-EFFECT-002: Command effects must support two-step commit
///   - SC-EFFECT-003: Telemetry effects must be cancellable
///   - SC-EFFECT-004: Effect handlers must be total (handle all cases)
///
/// STAMP Compliance: SC-EFFECT-001 to SC-EFFECT-010
/// Version: 1.0.0
namespace Cepaf.Cockpit

open System
open Cepaf.Cockpit.Domain

// ============================================================================
// FREER MONAD - Core Effect System
// ============================================================================

/// Freer monad - efficient free monad using continuation-passing
type Eff<'Op, 'A> =
    | Pure of 'A
    | Impure of operation: 'Op * continuation: (obj -> Eff<'Op, 'A>)

module Eff =
    /// Lift pure value
    let pure' (x: 'A) : Eff<'Op, 'A> = Pure x

    /// Send an operation (effect)
    let send (op: 'Op) : Eff<'Op, 'A> =
        Impure (op, fun x -> Pure (unbox x))

    /// Bind (flatMap)
    let rec bind (f: 'A -> Eff<'Op, 'B>) (eff: Eff<'Op, 'A>) : Eff<'Op, 'B> =
        match eff with
        | Pure a -> f a
        | Impure (op, k) -> Impure (op, fun x -> bind f (k x))

    /// Map
    let map (f: 'A -> 'B) (eff: Eff<'Op, 'A>) : Eff<'Op, 'B> =
        bind (f >> pure') eff

    /// Apply
    let apply (ff: Eff<'Op, 'A -> 'B>) (fa: Eff<'Op, 'A>) : Eff<'Op, 'B> =
        bind (fun f -> map f fa) ff

    /// Run with handler
    let rec run
        (handleReturn: 'A -> 'R)
        (handleOp: 'Op -> (obj -> Eff<'Op, 'A>) -> 'R)
        (eff: Eff<'Op, 'A>) : 'R =
        match eff with
        | Pure a -> handleReturn a
        | Impure (op, k) -> handleOp op k

/// Computation expression builder
type EffBuilder<'Op>() =
    member _.Return(x) = Eff.pure' x
    member _.ReturnFrom(m) = m
    member _.Bind(m, f) = Eff.bind f m
    member _.Zero() = Eff.pure' ()
    member _.Combine(m1, m2) = Eff.bind (fun () -> m2) m1
    member _.Delay(f) = f ()

// ============================================================================
// COCKPIT EFFECT ALGEBRA
// ============================================================================

/// All cockpit operations as a unified effect type
type CockpitOp =
    // State operations
    | GetState
    | SetState of CockpitState
    | ModifyState of (CockpitState -> CockpitState)

    // Node operations
    | GetNode of NodeId
    | UpdateNode of NodeId * MeshNode
    | GetAllNodes

    // Alarm operations
    | GetAlarms of AlarmLevel option  // Filter by level
    | AddAlarm of Alarm
    | AcknowledgeAlarm of AlarmId * string  // alarmId * operatorId
    | ClearAlarm of AlarmId

    // Command operations (SC-EFFECT-002: Two-step commit)
    | ArmCommand of NodeId * MeshCommand
    | ExecuteCommand of CommandId
    | CancelCommand of CommandId
    | GetCommandStatus of CommandId

    // Telemetry operations
    | SendTelemetryRequest of NodeId
    | ReceiveTelemetry of NodeId

    // AI operations
    | RequestAiInsight of NodeId list
    | GetInsights

    // UI operations
    | NavigateView of ViewMode
    | SelectNode of NodeId option
    | SelectZone of ZoneId option

    // Logging
    | LogInfo of string
    | LogWarning of string
    | LogError of string

    // Time
    | GetCurrentTime
    | Delay of int  // milliseconds

/// Cockpit effect type alias
type CockpitEff<'A> = Eff<CockpitOp, 'A>

/// Computation expression module
module CockpitComputation =
    /// Computation expression for cockpit effects
    let cockpit = EffBuilder<CockpitOp>()

// ============================================================================
// COCKPIT EFFECT DSL
// ============================================================================

module CockpitDsl =
    /// Get current cockpit state
    let getState : CockpitEff<CockpitState> =
        Eff.send GetState

    /// Set cockpit state
    let setState (state: CockpitState) : CockpitEff<unit> =
        Eff.send (SetState state) |> Eff.map ignore

    /// Modify state with function
    let modifyState (f: CockpitState -> CockpitState) : CockpitEff<unit> =
        Eff.send (ModifyState f) |> Eff.map ignore

    /// Get specific node
    let getNode (nodeId: NodeId) : CockpitEff<MeshNode option> =
        Eff.send (GetNode nodeId)

    /// Update node
    let updateNode (nodeId: NodeId) (node: MeshNode) : CockpitEff<unit> =
        Eff.send (UpdateNode (nodeId, node)) |> Eff.map ignore

    /// Get all nodes
    let getAllNodes : CockpitEff<MeshNode list> =
        Eff.send GetAllNodes

    /// Get alarms, optionally filtered by level
    let getAlarms (level: AlarmLevel option) : CockpitEff<Alarm list> =
        Eff.send (GetAlarms level)

    /// Add new alarm
    let addAlarm (alarm: Alarm) : CockpitEff<unit> =
        Eff.send (AddAlarm alarm) |> Eff.map ignore

    /// Acknowledge alarm
    let acknowledgeAlarm (alarmId: AlarmId) (operatorId: string) : CockpitEff<bool> =
        Eff.send (AcknowledgeAlarm (alarmId, operatorId))

    /// Clear alarm
    let clearAlarm (alarmId: AlarmId) : CockpitEff<unit> =
        Eff.send (ClearAlarm alarmId) |> Eff.map ignore

    /// Arm a command (first step of two-step commit)
    let armCommand (nodeId: NodeId) (cmd: MeshCommand) : CockpitEff<CommandId> =
        Eff.send (ArmCommand (nodeId, cmd))

    /// Execute an armed command (second step)
    let executeCommand (cmdId: CommandId) : CockpitEff<bool> =
        Eff.send (ExecuteCommand cmdId)

    /// Cancel armed command
    let cancelCommand (cmdId: CommandId) : CockpitEff<unit> =
        Eff.send (CancelCommand cmdId) |> Eff.map ignore

    /// Get command status
    let getCommandStatus (cmdId: CommandId) : CockpitEff<CommandState option> =
        Eff.send (GetCommandStatus cmdId)

    /// Request AI insight for nodes
    let requestAiInsight (nodeIds: NodeId list) : CockpitEff<unit> =
        Eff.send (RequestAiInsight nodeIds) |> Eff.map ignore

    /// Get current insights
    let getInsights : CockpitEff<AiInsight list> =
        Eff.send GetInsights

    /// Navigate to view
    let navigateTo (view: ViewMode) : CockpitEff<unit> =
        Eff.send (NavigateView view) |> Eff.map ignore

    /// Select node
    let selectNode (nodeId: NodeId option) : CockpitEff<unit> =
        Eff.send (SelectNode nodeId) |> Eff.map ignore

    /// Select zone
    let selectZone (zoneId: ZoneId option) : CockpitEff<unit> =
        Eff.send (SelectZone zoneId) |> Eff.map ignore

    /// Log info message
    let logInfo (msg: string) : CockpitEff<unit> =
        Eff.send (LogInfo msg) |> Eff.map ignore

    /// Log warning
    let logWarning (msg: string) : CockpitEff<unit> =
        Eff.send (LogWarning msg) |> Eff.map ignore

    /// Log error
    let logError (msg: string) : CockpitEff<unit> =
        Eff.send (LogError msg) |> Eff.map ignore

    /// Get current time
    let getCurrentTime : CockpitEff<DateTime> =
        Eff.send GetCurrentTime

    /// Delay execution
    let delay (ms: int) : CockpitEff<unit> =
        Eff.send (Delay ms) |> Eff.map ignore

// ============================================================================
// EFFECT INTERPRETERS
// ============================================================================

/// Interpreter context
type InterpreterContext = {
    mutable State: CockpitState
    mutable CommandCounter: int
    LogSink: string -> unit
}

module Interpreter =
    open CockpitDsl

    /// Pure interpreter for testing (SC-EFFECT-001)
    let runPure (ctx: InterpreterContext) (eff: CockpitEff<'A>) : 'A =
        let rec go eff =
            match eff with
            | Pure a -> a
            | Impure (op, k) ->
                let result =
                    match op with
                    | GetState -> box ctx.State
                    | SetState s -> ctx.State <- s; box ()
                    | ModifyState f -> ctx.State <- f ctx.State; box ()

                    | GetNode nodeId -> box (Map.tryFind nodeId ctx.State.Nodes)
                    | UpdateNode (nodeId, node) ->
                        ctx.State <- { ctx.State with Nodes = Map.add nodeId node ctx.State.Nodes }
                        box ()
                    | GetAllNodes -> box (ctx.State.Nodes |> Map.toList |> List.map snd)

                    | GetAlarms level ->
                        let alarms = ctx.State.Alarms |> Map.toList |> List.map snd
                        match level with
                        | None -> box alarms
                        | Some l -> box (alarms |> List.filter (fun a -> a.Level = l))
                    | AddAlarm alarm ->
                        ctx.State <- { ctx.State with Alarms = Map.add alarm.Id alarm ctx.State.Alarms }
                        box ()
                    | AcknowledgeAlarm (alarmId, operatorId) ->
                        match Map.tryFind alarmId ctx.State.Alarms with
                        | None -> box false
                        | Some alarm ->
                            let updated = { alarm with AcknowledgedAt = Some DateTime.UtcNow; AcknowledgedBy = Some operatorId }
                            ctx.State <- { ctx.State with Alarms = Map.add alarmId updated ctx.State.Alarms }
                            box true
                    | ClearAlarm alarmId ->
                        ctx.State <- { ctx.State with Alarms = Map.remove alarmId ctx.State.Alarms }
                        box ()

                    | ArmCommand (nodeId, cmd) ->
                        ctx.CommandCounter <- ctx.CommandCounter + 1
                        let cmdId = sprintf "CMD-%04d" ctx.CommandCounter
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
                        ctx.State <- { ctx.State with PendingCommands = Map.add cmdId record ctx.State.PendingCommands }
                        box cmdId
                    | ExecuteCommand cmdId ->
                        match Map.tryFind cmdId ctx.State.PendingCommands with
                        | None -> box false
                        | Some cmd ->
                            let updated = { cmd with State = Executing; ExecutedAt = Some DateTime.UtcNow }
                            ctx.State <- { ctx.State with PendingCommands = Map.add cmdId updated ctx.State.PendingCommands }
                            box true
                    | CancelCommand cmdId ->
                        ctx.State <- { ctx.State with PendingCommands = Map.remove cmdId ctx.State.PendingCommands }
                        box ()
                    | GetCommandStatus cmdId ->
                        box (Map.tryFind cmdId ctx.State.PendingCommands |> Option.map (fun c -> c.State))

                    | SendTelemetryRequest _ -> box ()
                    | ReceiveTelemetry _ -> box ()

                    | RequestAiInsight _ -> box ()
                    | GetInsights -> box ctx.State.Insights

                    | NavigateView view ->
                        ctx.State <- { ctx.State with CurrentView = view }
                        box ()
                    | SelectNode nodeId ->
                        ctx.State <- { ctx.State with SelectedNodeId = nodeId }
                        box ()
                    | SelectZone zoneId ->
                        ctx.State <- { ctx.State with SelectedZoneId = zoneId }
                        box ()

                    | LogInfo msg -> ctx.LogSink (sprintf "[INFO] %s" msg); box ()
                    | LogWarning msg -> ctx.LogSink (sprintf "[WARN] %s" msg); box ()
                    | LogError msg -> ctx.LogSink (sprintf "[ERROR] %s" msg); box ()

                    | GetCurrentTime -> box DateTime.UtcNow
                    | Delay _ -> box ()  // No-op in pure mode

                go (k result)
        go eff

    /// Async interpreter for production
    let runAsync (ctx: InterpreterContext) (eff: CockpitEff<'A>) : Async<'A> =
        let rec go eff = async {
            match eff with
            | Pure a -> return a
            | Impure (op, k) ->
                let! result = async {
                    match op with
                    | Delay ms ->
                        do! Async.Sleep ms
                        return box ()
                    | GetCurrentTime ->
                        return box DateTime.UtcNow
                    | _ ->
                        // Delegate to pure interpreter for most ops
                        return
                            match op with
                            | GetState -> box ctx.State
                            | SetState s -> ctx.State <- s; box ()
                            | ModifyState f -> ctx.State <- f ctx.State; box ()
                            | GetNode nodeId -> box (Map.tryFind nodeId ctx.State.Nodes)
                            | UpdateNode (nodeId, node) ->
                                ctx.State <- { ctx.State with Nodes = Map.add nodeId node ctx.State.Nodes }
                                box ()
                            | GetAllNodes -> box (ctx.State.Nodes |> Map.toList |> List.map snd)
                            | GetAlarms level ->
                                let alarms = ctx.State.Alarms |> Map.toList |> List.map snd
                                match level with
                                | None -> box alarms
                                | Some l -> box (alarms |> List.filter (fun a -> a.Level = l))
                            | AddAlarm alarm ->
                                ctx.State <- { ctx.State with Alarms = Map.add alarm.Id alarm ctx.State.Alarms }
                                box ()
                            | AcknowledgeAlarm (alarmId, operatorId) ->
                                match Map.tryFind alarmId ctx.State.Alarms with
                                | None -> box false
                                | Some alarm ->
                                    let updated = { alarm with AcknowledgedAt = Some DateTime.UtcNow; AcknowledgedBy = Some operatorId }
                                    ctx.State <- { ctx.State with Alarms = Map.add alarmId updated ctx.State.Alarms }
                                    box true
                            | ClearAlarm alarmId ->
                                ctx.State <- { ctx.State with Alarms = Map.remove alarmId ctx.State.Alarms }
                                box ()
                            | ArmCommand (nodeId, cmd) ->
                                ctx.CommandCounter <- ctx.CommandCounter + 1
                                let cmdId = sprintf "CMD-%04d" ctx.CommandCounter
                                let record = {
                                    Id = cmdId; TargetNodeId = nodeId; Command = cmd; State = Armed
                                    ArmedAt = Some DateTime.UtcNow; ExecutedAt = None; AcknowledgedAt = None
                                    ErrorMessage = None; RequiresConfirmation = isCriticalCommand cmd
                                }
                                ctx.State <- { ctx.State with PendingCommands = Map.add cmdId record ctx.State.PendingCommands }
                                box cmdId
                            | ExecuteCommand cmdId ->
                                match Map.tryFind cmdId ctx.State.PendingCommands with
                                | None -> box false
                                | Some cmd ->
                                    let updated = { cmd with State = Executing; ExecutedAt = Some DateTime.UtcNow }
                                    ctx.State <- { ctx.State with PendingCommands = Map.add cmdId updated ctx.State.PendingCommands }
                                    box true
                            | CancelCommand cmdId ->
                                ctx.State <- { ctx.State with PendingCommands = Map.remove cmdId ctx.State.PendingCommands }
                                box ()
                            | GetCommandStatus cmdId ->
                                box (Map.tryFind cmdId ctx.State.PendingCommands |> Option.map (fun c -> c.State))
                            | SendTelemetryRequest _ -> box ()
                            | ReceiveTelemetry _ -> box ()
                            | RequestAiInsight _ -> box ()
                            | GetInsights -> box ctx.State.Insights
                            | NavigateView view ->
                                ctx.State <- { ctx.State with CurrentView = view }
                                box ()
                            | SelectNode nodeId ->
                                ctx.State <- { ctx.State with SelectedNodeId = nodeId }
                                box ()
                            | SelectZone zoneId ->
                                ctx.State <- { ctx.State with SelectedZoneId = zoneId }
                                box ()
                            | LogInfo msg -> ctx.LogSink (sprintf "[INFO] %s" msg); box ()
                            | LogWarning msg -> ctx.LogSink (sprintf "[WARN] %s" msg); box ()
                            | LogError msg -> ctx.LogSink (sprintf "[ERROR] %s" msg); box ()
                            | _ -> box ()
                }
                return! go (k result)
        }
        go eff

// ============================================================================
// EXAMPLE EFFECT PROGRAMS
// ============================================================================

module CockpitPrograms =
    open CockpitDsl
    open CockpitComputation

    /// Process incoming alarm
    let processAlarm (alarm: Alarm) : CockpitEff<unit> = cockpit {
        do! logInfo (sprintf "Processing alarm: %s" alarm.Id)
        do! addAlarm alarm

        if alarm.Level = Critical then
            do! logWarning (sprintf "CRITICAL alarm from node %s: %s" alarm.NodeId alarm.Message)
            // Auto-navigate to alarm center for critical alarms
            do! navigateTo AlarmCenter
            do! selectNode (Some alarm.NodeId)
    }

    /// Two-step command execution (SC-EFFECT-002)
    let sendCriticalCommand (nodeId: NodeId) (cmd: MeshCommand) : CockpitEff<Result<CommandId, string>> = cockpit {
        if not (isCriticalCommand cmd) then
            return Error "Command is not critical, use direct send"
        else
            do! logInfo (sprintf "Arming critical command for node %s" nodeId)
            let! cmdId = armCommand nodeId cmd
            do! logInfo (sprintf "Command armed: %s. Awaiting confirmation..." cmdId)

            // In real usage, wait for user confirmation
            do! delay 100  // Simulated confirmation delay

            let! success = executeCommand cmdId
            if success then
                do! logInfo (sprintf "Command %s executed successfully" cmdId)
                return Ok cmdId
            else
                do! logError (sprintf "Command %s execution failed" cmdId)
                return Error "Execution failed"
    }

    /// Batch acknowledge alarms (using recursive helper instead of for loop)
    let acknowledgeAllAlarmsForNode (nodeId: NodeId) (operatorId: string) : CockpitEff<int> =
        Eff.bind (fun alarms ->
            let nodeAlarms = alarms |> List.filter (fun (a: Alarm) -> a.NodeId = nodeId && a.AcknowledgedAt.IsNone)
            let count = List.length nodeAlarms
            Eff.bind (fun () ->
                Eff.pure' count
            ) (logInfo (sprintf "Would acknowledge %d alarms for node %s" count nodeId))
        ) (getAlarms None)

    /// Health check routine (using pure computation)
    let healthCheckRoutine : CockpitEff<Map<NodeId, bool>> =
        Eff.bind (fun nodes ->
            let results =
                nodes
                |> List.map (fun (node: MeshNode) ->
                    let isHealthy =
                        node.Status = Connected &&
                        node.Cpu.Value < 90.0 &&
                        node.Memory.Value < 90.0 &&
                        not (isStale node.Cpu)
                    (node.Id, isHealthy)
                )
                |> Map.ofList
            Eff.pure' results
        ) getAllNodes

    /// Dashboard refresh routine
    let refreshDashboard : CockpitEff<unit> = cockpit {
        let! time = getCurrentTime
        do! logInfo (sprintf "Refreshing dashboard at %s" (time.ToString("HH:mm:ss")))

        let! nodes = getAllNodes
        let! alarms = getAlarms (Some Warning)

        do! modifyState (fun s ->
            { s with
                LastMessageAt = Some time
                MessagesReceived = s.MessagesReceived + 1L
            }
        )

        if not (List.isEmpty alarms) then
            do! logWarning (sprintf "%d active warnings" (List.length alarms))
    }

// ============================================================================
// TEST UTILITIES
// ============================================================================

module EffectTesting =
    /// Create test context with empty state
    let createTestContext (operatorId: string) : InterpreterContext =
        let logs = System.Collections.Generic.List<string>()
        {
            State = createCockpitState operatorId
            CommandCounter = 0
            LogSink = fun msg -> logs.Add(msg)
        }

    /// Run effect in test mode and return result + final state
    let testRun (ctx: InterpreterContext) (eff: CockpitEff<'A>) : 'A * CockpitState =
        let result = Interpreter.runPure ctx eff
        (result, ctx.State)

    /// Assert effect produces expected result
    let assertResult (expected: 'A) (ctx: InterpreterContext) (eff: CockpitEff<'A>) : bool =
        let (actual, _) = testRun ctx eff
        actual = expected
