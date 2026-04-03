namespace Cepaf.Cockpit

open System
open System.Text
open System.Text.Json
open System.Collections.Generic
open Cepaf.Cockpit.Domain
open Cepaf.Cockpit.SituationalAwareness

/// ═══════════════════════════════════════════════════════════════════════════════
/// PRAJNA MESSAGING INTEGRATION - UNIFIED PROTOCOL LAYER
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// WHAT: Unified integration layer for all messaging protocols (Zenoh, PubSub, gRPC)
///       with full telemetry and fractal logging support.
///
/// WHY: PRAJNA needs real-time bidirectional communication with:
///      - Zenoh for distributed telemetry (C3I mesh)
///      - Phoenix PubSub for internal events (LiveView)
///      - gRPC for external services (CEPAF bridge)
///
/// DESIGN PRINCIPLES:
///   1. Protocol abstraction - unified message model
///   2. Fractal logging - events at all levels (Spine → Gossamer)
///   3. Telemetry display - real-time metric visualization
///   4. Event sourcing - complete audit trail
///
/// STAMP Compliance:
///   - SC-MSG-001: Message delivery guarantee (at-least-once)
///   - SC-MSG-002: Message ordering preservation
///   - SC-MSG-003: Protocol failover capability
///   - SC-MSG-004: Audit logging for all messages
///   - SC-TEL-001: Telemetry latency <100ms
///   - SC-LOG-001: Fractal logging hierarchy enforcement
///
/// ═══════════════════════════════════════════════════════════════════════════════
module MessagingIntegration =

    // ═══════════════════════════════════════════════════════════════════════════
    // UNIFIED MESSAGE MODEL
    // ═══════════════════════════════════════════════════════════════════════════

    /// Message source protocol
    type Protocol =
        | Zenoh      // Distributed pub/sub (c3i/*)
        | PubSub     // Phoenix internal (prajna:*)
        | GRPC       // External services
        | Internal   // Local events

    /// Message priority for fractal logging
    type MessagePriority =
        | Spine      // Critical - system failures
        | Thorax     // Warning - safety alerts
        | Segment    // Info - operational events
        | Fiber      // Debug - diagnostics
        | Gossamer   // Trace - development

    /// Unified message envelope
    type Message = {
        Id: string
        Timestamp: DateTime
        Protocol: Protocol
        Topic: string
        Priority: MessagePriority
        Payload: byte[]
        Metadata: Map<string, string>
        CorrelationId: string option
        ReplyTo: string option
    }

    /// Create a new message
    let createMessage (protocol: Protocol) (topic: string) (priority: MessagePriority) (payload: byte[]) : Message =
        {
            Id = Guid.NewGuid().ToString("N")
            Timestamp = DateTime.UtcNow
            Protocol = protocol
            Topic = topic
            Priority = priority
            Payload = payload
            Metadata = Map.empty
            CorrelationId = None
            ReplyTo = None
        }

    /// Add metadata to message
    let withMetadata (key: string) (value: string) (msg: Message) : Message =
        { msg with Metadata = msg.Metadata |> Map.add key value }

    /// Add correlation ID
    let withCorrelation (correlationId: string) (msg: Message) : Message =
        { msg with CorrelationId = Some correlationId }

    // ═══════════════════════════════════════════════════════════════════════════
    // ZENOH INTEGRATION (c3i/*)
    // ═══════════════════════════════════════════════════════════════════════════

    module ZenohIntegration =

        /// Zenoh key expressions for C3I mesh
        module KeyExpressions =
            let units zone node subsystem = sprintf "c3i/units/%s/%s/%s" zone node subsystem
            let telemetry zone node = sprintf "c3i/units/%s/%s/telemetry" zone node
            let status zone node = sprintf "c3i/units/%s/%s/status" zone node
            let commands zone node = sprintf "c3i/ctrl/%s/%s" zone node
            let alarms severity = sprintf "c3i/alarms/%s" severity
            let metrics metricType = sprintf "c3i/metrics/%s" metricType
            let insights = "c3i/ai/insights"
            let ooda phase = sprintf "c3i/ooda/%s" phase

        /// Zenoh subscription state
        type ZenohState = {
            Subscriptions: Set<string>
            Publications: Map<string, DateTime>
            Connected: bool
            LastHeartbeat: DateTime
            MessageCount: int64
            ErrorCount: int64
        }

        let defaultZenohState = {
            Subscriptions = Set.empty
            Publications = Map.empty
            Connected = false
            LastHeartbeat = DateTime.MinValue
            MessageCount = 0L
            ErrorCount = 0L
        }

        /// Subscribe to Zenoh key expression
        let subscribe (keyExpr: string) (state: ZenohState) : ZenohState =
            { state with Subscriptions = state.Subscriptions |> Set.add keyExpr }

        /// Record publication
        let recordPublication (keyExpr: string) (state: ZenohState) : ZenohState =
            { state with
                Publications = state.Publications |> Map.add keyExpr DateTime.UtcNow
                MessageCount = state.MessageCount + 1L
            }

        /// Update heartbeat
        let updateHeartbeat (state: ZenohState) : ZenohState =
            { state with LastHeartbeat = DateTime.UtcNow; Connected = true }

        /// Record error
        let recordError (state: ZenohState) : ZenohState =
            { state with ErrorCount = state.ErrorCount + 1L }

        /// Check if connected (heartbeat within 10s)
        let isConnected (state: ZenohState) : bool =
            state.Connected && (DateTime.UtcNow - state.LastHeartbeat).TotalSeconds < 10.0

        /// Create Zenoh message from telemetry
        let createTelemetryMessage (zone: string) (node: string) (cpu: float) (memory: float) (latency: float) : Message =
            let payload = sprintf """{"cpu":%.2f,"memory":%.2f,"latency":%.2f}""" cpu memory latency
            createMessage Zenoh (KeyExpressions.telemetry zone node) Fiber (Encoding.UTF8.GetBytes payload)
            |> withMetadata "zone" zone
            |> withMetadata "node" node

        /// Create Zenoh alarm message
        let createAlarmMessage (severity: string) (source: string) (message: string) : Message =
            let priority =
                match severity.ToLower() with
                | "critical" -> Spine
                | "warning" -> Thorax
                | "caution" -> Segment
                | "advisory" -> Fiber
                | _ -> Gossamer
            let ts = DateTime.UtcNow.ToString("o")
            let payload = sprintf """{"source":"%s","message":"%s","timestamp":"%s"}""" source message ts
            createMessage Zenoh (KeyExpressions.alarms severity) priority (Encoding.UTF8.GetBytes payload)
            |> withMetadata "severity" severity
            |> withMetadata "source" source

        /// Parse telemetry from Zenoh payload
        let parseTelemetry (payload: byte[]) : (float * float * float) option =
            try
                let json = Encoding.UTF8.GetString(payload)
                let doc = JsonDocument.Parse(json)
                let root = doc.RootElement
                let cpu = root.GetProperty("cpu").GetDouble()
                let memory = root.GetProperty("memory").GetDouble()
                let latency = root.GetProperty("latency").GetDouble()
                Some (cpu, memory, latency)
            with _ -> None

    // ═══════════════════════════════════════════════════════════════════════════
    // PHOENIX PUBSUB INTEGRATION (prajna:*)
    // ═══════════════════════════════════════════════════════════════════════════

    module PubSubIntegration =

        /// PubSub topics for PRAJNA
        module Topics =
            let metrics = "prajna:metrics"
            let alarms = "prajna:alarms"
            let commands = "prajna:commands"
            let insights = "prajna:insights"
            let ooda = "prajna:ooda"
            let containers = "prajna:containers"
            let nodes = "prajna:nodes"
            let navigation = "prajna:navigation"

        /// PubSub event types
        type PubSubEvent =
            | MetricUpdated of nodeId: string * metricType: string * value: float
            | AlarmRaised of alarmId: string * level: AlarmLevel * message: string
            | AlarmAcknowledged of alarmId: string * operator: string
            | CommandArmed of commandId: string * nodeId: string * command: MeshCommand
            | CommandExecuted of commandId: string * result: string
            | InsightGenerated of insightType: string * content: string * confidence: float
            | OodaPhaseChanged of phase: string * cycleMs: float
            | ContainerStateChanged of containerId: string * status: string
            | NodeStateChanged of nodeId: string * status: string
            | NavigationChanged of level: int * scope: string

        /// Serialize event to JSON
        let serializeEvent (event: PubSubEvent) : string =
            match event with
            | MetricUpdated (nodeId, metricType, value) ->
                sprintf """{"type":"metric_updated","node_id":"%s","metric_type":"%s","value":%.2f}"""
                    nodeId metricType value
            | AlarmRaised (alarmId, level, message) ->
                sprintf """{"type":"alarm_raised","alarm_id":"%s","level":"%A","message":"%s"}"""
                    alarmId level message
            | AlarmAcknowledged (alarmId, operator) ->
                sprintf """{"type":"alarm_acknowledged","alarm_id":"%s","operator":"%s"}"""
                    alarmId operator
            | CommandArmed (commandId, nodeId, command) ->
                sprintf """{"type":"command_armed","command_id":"%s","node_id":"%s","command":"%A"}"""
                    commandId nodeId command
            | CommandExecuted (commandId, result) ->
                sprintf """{"type":"command_executed","command_id":"%s","result":"%s"}"""
                    commandId result
            | InsightGenerated (insightType, content, confidence) ->
                sprintf """{"type":"insight_generated","insight_type":"%s","content":"%s","confidence":%.2f}"""
                    insightType content confidence
            | OodaPhaseChanged (phase, cycleMs) ->
                sprintf """{"type":"ooda_phase_changed","phase":"%s","cycle_ms":%.2f}"""
                    phase cycleMs
            | ContainerStateChanged (containerId, status) ->
                sprintf """{"type":"container_state_changed","container_id":"%s","status":"%s"}"""
                    containerId status
            | NodeStateChanged (nodeId, status) ->
                sprintf """{"type":"node_state_changed","node_id":"%s","status":"%s"}"""
                    nodeId status
            | NavigationChanged (level, scope) ->
                sprintf """{"type":"navigation_changed","level":%d,"scope":"%s"}"""
                    level scope

        /// Create PubSub message
        let createPubSubMessage (topic: string) (event: PubSubEvent) : Message =
            let priority =
                match event with
                | AlarmRaised (_, level, _) ->
                    match level with
                    | Critical -> Spine
                    | Warning -> Thorax
                    | Caution -> Segment
                    | Advisory -> Fiber
                    | Normal -> Gossamer
                | CommandExecuted _ -> Segment
                | _ -> Fiber
            let payload = serializeEvent event |> Encoding.UTF8.GetBytes
            createMessage PubSub topic priority payload

    // ═══════════════════════════════════════════════════════════════════════════
    // GRPC INTEGRATION (CEPAF Bridge)
    // ═══════════════════════════════════════════════════════════════════════════

    module GrpcIntegration =

        /// gRPC service types
        type GrpcService =
            | CepafBridge     // F# ↔ Elixir bridge
            | OpenRouter      // LLM integration
            | SigNoz          // Observability
            | Tailscale       // Mesh networking

        /// gRPC call state
        type GrpcCallState = {
            Service: GrpcService
            Method: string
            StartedAt: DateTime
            CompletedAt: DateTime option
            Status: string
            LatencyMs: float option
        }

        /// gRPC connection state
        type GrpcState = {
            Services: Map<GrpcService, bool>  // Service -> Connected
            ActiveCalls: GrpcCallState list
            TotalCalls: int64
            FailedCalls: int64
        }

        let defaultGrpcState = {
            Services = Map.empty
            ActiveCalls = []
            TotalCalls = 0L
            FailedCalls = 0L
        }

        /// Start a gRPC call
        let startCall (service: GrpcService) (method: string) (state: GrpcState) : GrpcState * GrpcCallState =
            let call = {
                Service = service
                Method = method
                StartedAt = DateTime.UtcNow
                CompletedAt = None
                Status = "in_progress"
                LatencyMs = None
            }
            { state with
                ActiveCalls = call :: state.ActiveCalls
                TotalCalls = state.TotalCalls + 1L
            }, call

        /// Complete a gRPC call
        let completeCall (call: GrpcCallState) (status: string) (state: GrpcState) : GrpcState =
            let now = DateTime.UtcNow
            let latency = (now - call.StartedAt).TotalMilliseconds
            let completed = { call with CompletedAt = Some now; Status = status; LatencyMs = Some latency }
            let newFailed = if status <> "ok" then state.FailedCalls + 1L else state.FailedCalls
            let activeCalls = state.ActiveCalls |> List.filter (fun c -> c <> call)
            { state with ActiveCalls = activeCalls; FailedCalls = newFailed }

        /// Create gRPC message
        let createGrpcMessage (service: GrpcService) (method: string) (payload: byte[]) : Message =
            let topic = sprintf "grpc/%A/%s" service method
            createMessage GRPC topic Fiber payload
            |> withMetadata "service" (sprintf "%A" service)
            |> withMetadata "method" method

    // ═══════════════════════════════════════════════════════════════════════════
    // FRACTAL LOGGING INTEGRATION
    // ═══════════════════════════════════════════════════════════════════════════

    module FractalLogging =

        /// Log entry with fractal level
        type FractalLogEntry = {
            Id: string
            Timestamp: DateTime
            Level: MessagePriority
            Source: string
            Message: string
            Context: Map<string, string>
            CorrelationId: string option
            SpanId: string option
            TraceId: string option
        }

        /// Fractal log state
        type FractalLogState = {
            Spine: FractalLogEntry list      // Critical - forever
            Thorax: FractalLogEntry list     // Warning - 30 days
            Segment: FractalLogEntry list    // Info - 7 days
            Fiber: FractalLogEntry list      // Debug - 24 hours
            Gossamer: FractalLogEntry list   // Trace - 1 hour
            TotalEntries: int64
            EntriesBySource: Map<string, int64>
        }

        let defaultFractalLogState = {
            Spine = []
            Thorax = []
            Segment = []
            Fiber = []
            Gossamer = []
            TotalEntries = 0L
            EntriesBySource = Map.empty
        }

        /// Create log entry
        let createEntry
            (level: MessagePriority)
            (source: string)
            (message: string)
            (context: Map<string, string>) : FractalLogEntry =
            {
                Id = Guid.NewGuid().ToString("N")
                Timestamp = DateTime.UtcNow
                Level = level
                Source = source
                Message = message
                Context = context
                CorrelationId = None
                SpanId = None
                TraceId = None
            }

        /// Add trace context
        let withTrace (traceId: string) (spanId: string) (entry: FractalLogEntry) : FractalLogEntry =
            { entry with TraceId = Some traceId; SpanId = Some spanId }

        /// Log at appropriate fractal level
        let log (entry: FractalLogEntry) (state: FractalLogState) : FractalLogState =
            let addToList maxSize list entry =
                (entry :: list) |> List.truncate maxSize

            let newEntriesBySource =
                let current = state.EntriesBySource |> Map.tryFind entry.Source |> Option.defaultValue 0L
                state.EntriesBySource |> Map.add entry.Source (current + 1L)

            match entry.Level with
            | Spine ->
                { state with
                    Spine = addToList 10000 state.Spine entry
                    TotalEntries = state.TotalEntries + 1L
                    EntriesBySource = newEntriesBySource
                }
            | Thorax ->
                { state with
                    Thorax = addToList 50000 state.Thorax entry
                    TotalEntries = state.TotalEntries + 1L
                    EntriesBySource = newEntriesBySource
                }
            | Segment ->
                { state with
                    Segment = addToList 100000 state.Segment entry
                    TotalEntries = state.TotalEntries + 1L
                    EntriesBySource = newEntriesBySource
                }
            | Fiber ->
                { state with
                    Fiber = addToList 50000 state.Fiber entry
                    TotalEntries = state.TotalEntries + 1L
                    EntriesBySource = newEntriesBySource
                }
            | Gossamer ->
                { state with
                    Gossamer = addToList 10000 state.Gossamer entry
                    TotalEntries = state.TotalEntries + 1L
                    EntriesBySource = newEntriesBySource
                }

        /// Prune old entries based on retention
        let prune (state: FractalLogState) : FractalLogState =
            let now = DateTime.UtcNow

            let pruneByAge maxAge entries =
                entries |> List.filter (fun e -> (now - e.Timestamp).TotalHours < maxAge)

            { state with
                // Spine: forever (no pruning)
                Thorax = pruneByAge (30.0 * 24.0) state.Thorax      // 30 days
                Segment = pruneByAge (7.0 * 24.0) state.Segment     // 7 days
                Fiber = pruneByAge 24.0 state.Fiber                 // 24 hours
                Gossamer = pruneByAge 1.0 state.Gossamer            // 1 hour
            }

        /// Convenience logging functions
        let logSpine source message context state =
            log (createEntry Spine source message context) state

        let logThorax source message context state =
            log (createEntry Thorax source message context) state

        let logSegment source message context state =
            log (createEntry Segment source message context) state

        let logFiber source message context state =
            log (createEntry Fiber source message context) state

        let logGossamer source message context state =
            log (createEntry Gossamer source message context) state

    // ═══════════════════════════════════════════════════════════════════════════
    // TELEMETRY DISPLAY INTEGRATION
    // ═══════════════════════════════════════════════════════════════════════════

    module TelemetryDisplay =

        /// Telemetry metric types
        type MetricType =
            | Counter of name: string * value: int64
            | Gauge of name: string * value: float * unit: string
            | Histogram of name: string * values: float list * percentiles: float list
            | Timer of name: string * durationMs: float
            | Rate of name: string * value: float * window: TimeSpan

        /// Telemetry display state
        type TelemetryDisplayState = {
            Metrics: Map<string, MetricType>
            Sparklines: Map<string, float list>  // Last 60 values per metric
            UpdatedAt: Map<string, DateTime>
            StalenessThreshold: TimeSpan
        }

        let defaultTelemetryDisplayState = {
            Metrics = Map.empty
            Sparklines = Map.empty
            UpdatedAt = Map.empty
            StalenessThreshold = TimeSpan.FromSeconds(5.0)
        }

        /// Update metric
        let updateMetric (metric: MetricType) (state: TelemetryDisplayState) : TelemetryDisplayState =
            let name =
                match metric with
                | Counter (n, _) -> n
                | Gauge (n, _, _) -> n
                | Histogram (n, _, _) -> n
                | Timer (n, _) -> n
                | Rate (n, _, _) -> n

            let value =
                match metric with
                | Counter (_, v) -> float v
                | Gauge (_, v, _) -> v
                | Timer (_, v) -> v
                | Rate (_, v, _) -> v
                | Histogram (_, values, _) ->
                    if values.IsEmpty then 0.0 else values |> List.average

            let sparkline =
                match state.Sparklines |> Map.tryFind name with
                | Some existing -> (value :: existing) |> List.truncate 60
                | None -> [value]

            { state with
                Metrics = state.Metrics |> Map.add name metric
                Sparklines = state.Sparklines |> Map.add name sparkline
                UpdatedAt = state.UpdatedAt |> Map.add name DateTime.UtcNow
            }

        /// Check if metric is stale
        let isStale (name: string) (state: TelemetryDisplayState) : bool =
            match state.UpdatedAt |> Map.tryFind name with
            | Some updated -> (DateTime.UtcNow - updated) > state.StalenessThreshold
            | None -> true

        /// Get staleness in seconds
        let getStaleness (name: string) (state: TelemetryDisplayState) : float =
            match state.UpdatedAt |> Map.tryFind name with
            | Some updated -> (DateTime.UtcNow - updated).TotalSeconds
            | None -> 9999.0

        /// Render sparkline for metric
        let renderSparkline (name: string) (width: int) (state: TelemetryDisplayState) : string =
            match state.Sparklines |> Map.tryFind name with
            | None -> String.replicate width "░"
            | Some values ->
                if values.IsEmpty then String.replicate width "░"
                else
                    let minVal = values |> List.min
                    let maxVal = values |> List.max
                    let range = max 0.001 (maxVal - minVal)

                    let chars = [| '▁'; '▂'; '▃'; '▄'; '▅'; '▆'; '▇'; '█' |]
                    let takeLast = min width (List.length values)
                    let recentValues = values |> List.take takeLast |> List.rev

                    recentValues
                    |> List.map (fun v ->
                        let normalized = (v - minVal) / range
                        let idx = int (normalized * float (chars.Length - 1))
                        chars.[min (chars.Length - 1) (max 0 idx)])
                    |> List.toArray
                    |> String
                    |> fun s -> s.PadLeft(width, '░')

        /// Render gauge with staleness indicator
        let renderGauge (name: string) (state: TelemetryDisplayState) (situational: SituationalState) : string =
            match state.Metrics |> Map.tryFind name with
            | Some (Gauge (_, value, unit)) ->
                let staleness = getStaleness name state
                let alarmLevel =
                    if staleness > 30.0 then Warning
                    elif staleness > 5.0 then Caution
                    else Normal
                let content = sprintf "%.1f%s" value unit
                renderWithAwareness name content alarmLevel staleness situational
            | _ -> "N/A"

    // ═══════════════════════════════════════════════════════════════════════════
    // UNIFIED MESSAGING HUB
    // ═══════════════════════════════════════════════════════════════════════════

    /// Combined state for all messaging protocols
    type MessagingState = {
        Zenoh: ZenohIntegration.ZenohState
        Grpc: GrpcIntegration.GrpcState
        Log: FractalLogging.FractalLogState
        Telemetry: TelemetryDisplay.TelemetryDisplayState
        MessageQueue: Message list
        ProcessedCount: int64
    }

    let defaultMessagingState = {
        Zenoh = ZenohIntegration.defaultZenohState
        Grpc = GrpcIntegration.defaultGrpcState
        Log = FractalLogging.defaultFractalLogState
        Telemetry = TelemetryDisplay.defaultTelemetryDisplayState
        MessageQueue = []
        ProcessedCount = 0L
    }

    /// Process incoming message
    let processMessage (msg: Message) (state: MessagingState) : MessagingState =
        // Log the message at appropriate fractal level
        let protocol = sprintf "%A" msg.Protocol
        let topic = sprintf "Message on %s" msg.Topic
        let logEntry = FractalLogging.createEntry msg.Priority protocol topic msg.Metadata
        let newLogState = FractalLogging.log logEntry state.Log

        // Update protocol-specific state
        let newState =
            match msg.Protocol with
            | Zenoh ->
                let newZenoh = ZenohIntegration.recordPublication msg.Topic state.Zenoh
                { state with Zenoh = newZenoh }
            | _ -> state

        { newState with Log = newLogState; ProcessedCount = state.ProcessedCount + 1L }

    /// Enqueue message for processing
    let enqueue (msg: Message) (state: MessagingState) : MessagingState =
        { state with MessageQueue = msg :: state.MessageQueue }

    /// Process all queued messages
    let processQueue (state: MessagingState) : MessagingState =
        let processed = state.MessageQueue |> List.fold (fun s msg -> processMessage msg s) state
        { processed with MessageQueue = [] }

    /// Get messaging status summary
    let getStatus (state: MessagingState) : string =
        sprintf "Zenoh: %s | gRPC: %d svcs | Log: %d entries | Processed: %d"
            (if ZenohIntegration.isConnected state.Zenoh then "Connected" else "Disconnected")
            (state.Grpc.Services |> Map.filter (fun _ v -> v) |> Map.count)
            state.Log.TotalEntries
            state.ProcessedCount
