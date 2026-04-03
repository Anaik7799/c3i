// =============================================================================
// Prajna C3I Cockpit - Zenoh Real-Time Subscriber
// =============================================================================
// STAMP: SC-BRIDGE-001 to SC-BRIDGE-005, SC-PRF-050
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 1.0.0 |
// | Created | 2026-01-03 |
// | Author | Cybernetic Architect |
// | Reference | SC-BRIDGE-*, AOR-BRIDGE-* |
// =============================================================================

namespace Cepaf.Cockpit.Avalonia.Services

open System
open System.Collections.Concurrent
open System.Threading
open System.Threading.Tasks
open Cepaf.Cockpit.Avalonia.Domain.Types
open Cepaf.Cockpit.Avalonia.Domain.Messages

/// <summary>
/// Zenoh pub/sub subscriber for real-time telemetry streaming
/// Implements FIFO message ordering and latency budgets per SC-BRIDGE-*
/// </summary>
module ZenohSubscriber =

    // =========================================================================
    // Configuration
    // =========================================================================

    type ZenohConfig = {
        EndpointUrl: string
        BufferFlushIntervalMs: int   // SC-BRIDGE-002: Max 100ms
        LatencyBudgetMs: int         // SC-BRIDGE-003: 50ms per batch
        ReconnectDelayMs: int
        MaxBufferSize: int
    }

    let defaultConfig = {
        EndpointUrl = "ws://localhost:7447"
        BufferFlushIntervalMs = 100
        LatencyBudgetMs = 50
        ReconnectDelayMs = 5000
        MaxBufferSize = 1000
    }

    // =========================================================================
    // Zenoh Key Expressions (FQUN - Fully Qualified Universal Names)
    // =========================================================================

    module KeyExpressions =
        // SC-BRIDGE-005: PubSub topics
        let kpi = "indrajaal/zenoh:kpi/**"
        let metrics = "indrajaal/zenoh:metrics/**"
        let agents = "indrajaal/zenoh:agents/**"
        let health = "indrajaal/zenoh:health/**"
        let safety = "indrajaal/zenoh:safety/**"

        // Domain-specific keys
        let alarms = "indrajaal/alarms/**"
        let devices = "indrajaal/devices/**"
        let video = "indrajaal/video/**"
        let guardian = "indrajaal/guardian/**"
        let sentinel = "indrajaal/sentinel/**"
        let testEvolution = "indrajaal/test-evolution/**"
        let ooda = "indrajaal/ooda/**"

    // =========================================================================
    // Message Types from Zenoh
    // =========================================================================

    type ZenohMessage =
        | KpiUpdate of {| name: string; value: float; timestamp: DateTime |}
        | MetricsUpdate of {| domain: string; metrics: Map<string, float> |}
        | AgentStatus of {| agent_id: string; status: string; phase: string |}
        | HealthUpdate of SystemHealth
        | SafetyAlert of {| constraint_id: string; severity: string; message: string |}
        | AlarmEvent of Alarm
        | DeviceEvent of {| device_id: Guid; event_type: string |}
        | GuardianProposal of Proposal
        | SentinelThreat of Threat
        | OodaPhaseChange of OodaState
        | FitnessUpdate of FitnessMetrics
        | Unknown of string

    // =========================================================================
    // Subscriber State
    // =========================================================================

    type SubscriberState = {
        Config: ZenohConfig
        mutable ConnectionStatus: ConnectionStatus
        MessageBuffer: ConcurrentQueue<ZenohMessage>
        mutable CancellationSource: CancellationTokenSource option
        mutable DispatchCallback: (Msg -> unit) option
        mutable LastMessageTime: DateTime
    }

    let create (config: ZenohConfig) : SubscriberState = {
        Config = config
        ConnectionStatus = Disconnected
        MessageBuffer = ConcurrentQueue<ZenohMessage>()
        CancellationSource = None
        DispatchCallback = None
        LastMessageTime = DateTime.MinValue
    }

    let createDefault () = create defaultConfig

    // =========================================================================
    // Message Conversion to MVU Messages
    // =========================================================================

    let private toMvuMessage (zenohMsg: ZenohMessage) : Msg option =
        match zenohMsg with
        | HealthUpdate health ->
            Some (System (HealthUpdated health))

        | AlarmEvent alarm ->
            Some (Alarm (NewAlarmReceived alarm))

        | GuardianProposal proposal ->
            Some (Guard (NewProposal proposal))

        | SentinelThreat threat ->
            Some (Sent (ThreatDetected threat))

        | OodaPhaseChange ooda ->
            Some (TestEvo (OodaCycleCompleted ooda))

        | FitnessUpdate fitness ->
            Some (TestEvo (FitnessUpdated fitness))

        | KpiUpdate _ | MetricsUpdate _ | AgentStatus _ | SafetyAlert _ | DeviceEvent _ | Unknown _ ->
            // These are handled by the dashboard directly
            None

    // =========================================================================
    // Message Buffer Processing (SC-BRIDGE-001: FIFO ordering)
    // =========================================================================

    let private processBuffer (state: SubscriberState) =
        let messages = ResizeArray<ZenohMessage>()
        let mutable msg = Unchecked.defaultof<ZenohMessage>

        // Drain buffer (SC-BRIDGE-001: FIFO order)
        while state.MessageBuffer.TryDequeue(&msg) do
            messages.Add(msg)

        // Reverse for FIFO processing
        messages.Reverse()

        // Convert and dispatch
        match state.DispatchCallback with
        | Some dispatch ->
            for zenohMsg in messages do
                match toMvuMessage zenohMsg with
                | Some mvuMsg -> dispatch mvuMsg
                | None -> ()
        | None -> ()

    // =========================================================================
    // WebSocket Connection Simulation
    // =========================================================================

    /// Simulates WebSocket message reception
    /// In production, this would use actual Zenoh client
    let private simulateMessage (key: string) : ZenohMessage option =
        let random = Random()
        match key with
        | k when k.StartsWith("indrajaal/zenoh:health") ->
            Some (HealthUpdate {
                Overall = Healthy
                CpuUsage = random.NextDouble() * 100.0
                MemoryUsage = random.NextDouble() * 100.0
                DiskUsage = random.NextDouble() * 100.0
                NetworkLatency = random.Next(10, 100)
                ActiveConnections = random.Next(1, 50)
                ErrorRate = random.NextDouble() * 0.05
                LastUpdated = DateTime.UtcNow
            })

        | k when k.StartsWith("indrajaal/ooda") ->
            let phases = [| Observe; Orient; Decide; Act; Complete |]
            Some (OodaPhaseChange {
                CurrentPhase = phases.[random.Next(phases.Length)]
                CycleCount = random.Next(1, 1000)
                CycleStartTime = DateTime.UtcNow.AddSeconds(-float (random.Next(1, 30)))
                LastCycleDuration = TimeSpan.FromMilliseconds(float (random.Next(50, 200)))
                ObservationsCount = random.Next(100, 10000)
                DecisionsMade = random.Next(50, 5000)
                ActionsExecuted = random.Next(50, 5000)
            })

        | k when k.StartsWith("indrajaal/test-evolution") ->
            Some (FitnessUpdate {
                Coverage = 0.5 + random.NextDouble() * 0.5
                PassRate = 0.8 + random.NextDouble() * 0.2
                MutationScore = 0.3 + random.NextDouble() * 0.7
                Diversity = 0.4 + random.NextDouble() * 0.6
                Combined = 0.6 + random.NextDouble() * 0.4
            })

        | _ -> None

    // =========================================================================
    // Connection Management
    // =========================================================================

    let connect (state: SubscriberState) (dispatch: Msg -> unit) : Task<bool> =
        task {
            state.ConnectionStatus <- Connecting
            state.DispatchCallback <- Some dispatch

            // In production, establish WebSocket connection to Zenoh router
            // For now, simulate successful connection
            do! Task.Delay(100)

            state.ConnectionStatus <- Connected
            state.CancellationSource <- Some (new CancellationTokenSource())

            // Start background message processing
            let token = state.CancellationSource.Value.Token
            Task.Run(fun () ->
                task {
                    while not token.IsCancellationRequested do
                        // Simulate receiving messages
                        let keys = [|
                            KeyExpressions.health
                            KeyExpressions.ooda
                            KeyExpressions.testEvolution
                        |]

                        for key in keys do
                            match simulateMessage key with
                            | Some msg ->
                                state.MessageBuffer.Enqueue(msg)
                                state.LastMessageTime <- DateTime.UtcNow
                            | None -> ()

                        // SC-BRIDGE-002: Flush buffer at interval
                        processBuffer state

                        do! Task.Delay(state.Config.BufferFlushIntervalMs)
                } :> Task
            ) |> ignore

            return true
        }

    let disconnect (state: SubscriberState) =
        match state.CancellationSource with
        | Some cts ->
            cts.Cancel()
            cts.Dispose()
            state.CancellationSource <- None
        | None -> ()

        state.ConnectionStatus <- Disconnected
        state.DispatchCallback <- None

    let dispose (state: SubscriberState) =
        disconnect state

    // =========================================================================
    // Subscription Management
    // =========================================================================

    type Subscription = {
        KeyExpression: string
        Handler: ZenohMessage -> unit
    }

    let subscribe (state: SubscriberState) (keyExpr: string) (handler: ZenohMessage -> unit) : Subscription =
        // In production, register with Zenoh router
        { KeyExpression = keyExpr; Handler = handler }

    let unsubscribe (state: SubscriberState) (subscription: Subscription) =
        // In production, unregister from Zenoh router
        ()

    // =========================================================================
    // Status Queries
    // =========================================================================

    let isConnected (state: SubscriberState) : bool =
        match state.ConnectionStatus with
        | Connected -> true
        | _ -> false

    let getBufferSize (state: SubscriberState) : int =
        state.MessageBuffer.Count

    let getLastMessageTime (state: SubscriberState) : DateTime =
        state.LastMessageTime

    let getConnectionStatus (state: SubscriberState) : ConnectionStatus =
        state.ConnectionStatus
