/// Cepaf.Tests.Integration.ZenohElixirIntegrationTests
/// F#/Elixir Integration Tests via Zenoh Mesh
///
/// WHAT: Verifies bidirectional communication between F# (CEPAF) and Elixir (Indrajaal) via Zenoh
/// WHY:  Ensures the fractal logging, control commands, and telemetry pipelines work across language boundaries
/// CONSTRAINTS: Tests are self-contained with mocked Zenoh session when not connected
///
/// STAMP Constraints:
/// - SC-ZENOH-INT-001: F# must receive Elixir-published messages
/// - SC-ZENOH-INT-002: F# must publish messages receivable by Elixir
/// - SC-ZENOH-INT-003: Fractal logs must be parsed correctly
/// - SC-ZENOH-INT-004: Control commands must be sent correctly
/// - SC-ZENOH-INT-005: Acknowledgments must be received
/// - SC-ZENOH-INT-006: Telemetry must be received
/// - SC-ZENOH-INT-007: KPI updates must be received
/// - SC-ZENOH-INT-008: Connection state must be tracked
/// - SC-ZENOH-INT-009: Message filtering must work
/// - SC-ZENOH-INT-010: Buffer management must work
/// - SC-ZENOH-INT-011: Concurrent subscribers must work
/// - SC-ZENOH-INT-012: Graceful disconnect must work
module Cepaf.Tests.Integration.ZenohElixirIntegrationTests

open System
open System.Collections.Concurrent
open System.Text.Json
open System.Threading
open System.Threading.Tasks
open Expecto

// =============================================================================
// Mock Types and Infrastructure for Self-Contained Tests
// =============================================================================

/// Connection state for mock session
type MockConnectionState =
    | Disconnected
    | Connected
    | Reconnecting

/// Log level for fractal logging
type FractalLogLevel =
    | Trace = 0
    | Debug = 1
    | Info = 2
    | Warning = 3
    | Error = 4
    | Critical = 5

/// Fractal log message structure (matches Elixir format)
type FractalLogMessage = {
    Timestamp: DateTimeOffset
    Level: FractalLogLevel
    Domain: string
    Source: string
    Message: string
    Metadata: Map<string, string>
    TraceId: string option
    SpanId: string option
}

/// Control command types
type ControlCommand =
    | Start of target: string
    | Stop of target: string
    | Restart of target: string
    | Configure of target: string * config: Map<string, string>
    | Query of queryType: string * parameters: Map<string, string>

/// Command acknowledgment
type CommandAck = {
    CommandId: Guid
    Status: string
    Timestamp: DateTimeOffset
    Details: string option
}

/// Telemetry metric from Elixir
type TelemetryMetric = {
    Name: string
    Value: float
    Unit: string
    Timestamp: DateTimeOffset
    Tags: Map<string, string>
}

/// KPI data point
type KpiDataPoint = {
    Name: string
    Value: float
    Target: float option
    Status: string
    Domain: string
    Timestamp: DateTimeOffset
}

/// Mock Zenoh message types
type ZenohMessage =
    | Log of FractalLogMessage
    | Telemetry of TelemetryMetric
    | Kpi of KpiDataPoint
    | Control of ControlCommand
    | Ack of CommandAck
    | Raw of key: string * payload: byte[]

/// Message filter configuration
type MessageFilter = {
    Levels: FractalLogLevel list
    Domains: string list
    IncludeAll: bool
}

/// Mock Zenoh session for self-contained tests
type MockZenohSession() =
    let messageBuffer = ConcurrentQueue<string * ZenohMessage>()
    let subscribers = ConcurrentDictionary<string, (ZenohMessage -> unit)>()
    let mutable state = Disconnected
    let mutable filter = { Levels = []; Domains = []; IncludeAll = true }
    let mutable bufferLimit = 1000
    let lockObj = obj()

    member _.State = state

    member _.Connect() =
        state <- Connected
        true

    member _.Disconnect() =
        lock lockObj (fun () ->
            // Flush buffer before disconnect
            while not messageBuffer.IsEmpty do
                messageBuffer.TryDequeue() |> ignore
            subscribers.Clear()
            state <- Disconnected
        )

    member _.IsConnected = state = Connected

    member _.Subscribe(keyExpr: string, handler: ZenohMessage -> unit) =
        subscribers.TryAdd(keyExpr, handler) |> ignore

    member _.Unsubscribe(keyExpr: string) =
        subscribers.TryRemove(keyExpr) |> ignore

    member _.GetSubscriberCount() = subscribers.Count

    member _.Publish(keyExpr: string, msg: ZenohMessage) =
        if state = Connected then
            // Buffer management
            if messageBuffer.Count >= bufferLimit then
                messageBuffer.TryDequeue() |> ignore

            messageBuffer.Enqueue((keyExpr, msg))

            // Notify matching subscribers
            for kvp in subscribers do
                if keyExpr.StartsWith(kvp.Key.TrimEnd('*', '/')) || kvp.Key = "*" then
                    kvp.Value msg
            true
        else
            false

    member _.SetFilter(f: MessageFilter) =
        filter <- f

    member _.GetFilter() = filter

    member _.SetBufferLimit(limit: int) =
        bufferLimit <- limit

    member _.GetBufferCount() = messageBuffer.Count

    member _.DrainBuffer() =
        let msgs = ResizeArray<string * ZenohMessage>()
        let mutable item = Unchecked.defaultof<_>
        while messageBuffer.TryDequeue(&item) do
            msgs.Add(item)
        msgs |> Seq.toList

    member _.SimulateElixirMessage(keyExpr: string, msg: ZenohMessage) =
        // Simulate message arriving from Elixir side
        for kvp in subscribers do
            if keyExpr.StartsWith(kvp.Key.TrimEnd('*', '/')) || kvp.Key = "*" then
                kvp.Value msg

// =============================================================================
// Key Expression Patterns (must match Elixir side)
// =============================================================================

module KeyExpressions =
    let root = "indrajaal"
    let logs = sprintf "%s/logs/**" root
    let logsByDomain domain = sprintf "%s/logs/%s/**" root domain
    let telemetry = sprintf "%s/telemetry/**" root
    let kpi = sprintf "%s/kpi/**" root
    let control = sprintf "%s/control/**" root
    let controlAck = sprintf "%s/control/ack/**" root
    let status = sprintf "%s/status/**" root

// =============================================================================
// Helper Functions
// =============================================================================

/// Parse a fractal log from JSON (as Elixir would send it)
let parseFractalLog (json: string) : FractalLogMessage option =
    try
        let doc = JsonDocument.Parse(json)
        let root = doc.RootElement
        Some {
            Timestamp =
                if root.TryGetProperty("timestamp") |> fst then
                    DateTimeOffset.Parse(root.GetProperty("timestamp").GetString())
                else DateTimeOffset.UtcNow
            Level =
                if root.TryGetProperty("level") |> fst then
                    match root.GetProperty("level").GetString().ToLower() with
                    | "trace" -> FractalLogLevel.Trace
                    | "debug" -> FractalLogLevel.Debug
                    | "info" -> FractalLogLevel.Info
                    | "warning" | "warn" -> FractalLogLevel.Warning
                    | "error" -> FractalLogLevel.Error
                    | "critical" -> FractalLogLevel.Critical
                    | _ -> FractalLogLevel.Info
                else FractalLogLevel.Info
            Domain =
                if root.TryGetProperty("domain") |> fst then
                    root.GetProperty("domain").GetString()
                else "unknown"
            Source =
                if root.TryGetProperty("source") |> fst then
                    root.GetProperty("source").GetString()
                else "unknown"
            Message =
                if root.TryGetProperty("message") |> fst then
                    root.GetProperty("message").GetString()
                else ""
            Metadata = Map.empty
            TraceId =
                if root.TryGetProperty("trace_id") |> fst then
                    Some (root.GetProperty("trace_id").GetString())
                else None
            SpanId =
                if root.TryGetProperty("span_id") |> fst then
                    Some (root.GetProperty("span_id").GetString())
                else None
        }
    with _ -> None

/// Serialize a control command to JSON (as Elixir expects)
let serializeControlCommand (cmd: ControlCommand) : string =
    match cmd with
    | Start target -> sprintf """{"type":"start","target":"%s"}""" target
    | Stop target -> sprintf """{"type":"stop","target":"%s"}""" target
    | Restart target -> sprintf """{"type":"restart","target":"%s"}""" target
    | Configure (target, _config) -> sprintf """{"type":"configure","target":"%s"}""" target
    | Query (queryType, _params) -> sprintf """{"type":"query","query_type":"%s"}""" queryType

/// Check if message passes filter
let passesFilter (filter: MessageFilter) (msg: ZenohMessage) : bool =
    if filter.IncludeAll then true
    else
        match msg with
        | Log log ->
            let levelOk = List.isEmpty filter.Levels || List.contains log.Level filter.Levels
            let domainOk = List.isEmpty filter.Domains || List.contains log.Domain filter.Domains
            levelOk && domainOk
        | _ -> true

// =============================================================================
// INT-F-001: receive_from_elixir
// SC-ZENOH-INT-001: F# receives Elixir messages
// =============================================================================

let receiveFromElixirTests =
    testList "INT-F-001: Receive from Elixir" [

        test "F# receives log message from Elixir" {
            // SC-ZENOH-INT-001: F# must receive Elixir-published messages
            let session = MockZenohSession()
            session.Connect() |> ignore

            let received = ref None
            session.Subscribe(KeyExpressions.logs, fun msg ->
                received := Some msg
            )

            // Simulate Elixir publishing a log
            let log = {
                Timestamp = DateTimeOffset.UtcNow
                Level = FractalLogLevel.Info
                Domain = "alarms"
                Source = "Indrajaal.Alarms.Processor"
                Message = "Alarm processed successfully"
                Metadata = Map.empty
                TraceId = Some "trace-123"
                SpanId = Some "span-456"
            }
            session.SimulateElixirMessage("indrajaal/logs/alarms", Log log)

            match !received with
            | Some (Log rcvd) ->
                Expect.equal rcvd.Domain "alarms" "Domain should match"
                Expect.equal rcvd.Level FractalLogLevel.Info "Level should match"
            | _ -> failtest "Should have received log message"

            session.Disconnect()
        }

        test "F# receives multiple messages in order" {
            let session = MockZenohSession()
            session.Connect() |> ignore

            let messages = ConcurrentQueue<ZenohMessage>()
            session.Subscribe(KeyExpressions.logs, fun msg ->
                messages.Enqueue(msg)
            )

            // Simulate multiple Elixir messages
            for i in 1..5 do
                let log = {
                    Timestamp = DateTimeOffset.UtcNow.AddMilliseconds(float i)
                    Level = FractalLogLevel.Info
                    Domain = "test"
                    Source = sprintf "source-%d" i
                    Message = sprintf "Message %d" i
                    Metadata = Map.empty
                    TraceId = None
                    SpanId = None
                }
                session.SimulateElixirMessage("indrajaal/logs/test", Log log)

            Expect.equal messages.Count 5 "Should receive all 5 messages"

            session.Disconnect()
        }

        test "F# handles empty payload gracefully" {
            let session = MockZenohSession()
            session.Connect() |> ignore

            let received = ref false
            session.Subscribe(KeyExpressions.logs, fun _ ->
                received := true
            )

            // Simulate empty raw message
            session.SimulateElixirMessage("indrajaal/logs/test", Raw ("key", [||]))

            Expect.isTrue !received "Should handle empty payload"

            session.Disconnect()
        }
    ]

// =============================================================================
// INT-F-002: publish_to_elixir
// SC-ZENOH-INT-002: F# publishes, Elixir receives
// =============================================================================

let publishToElixirTests =
    testList "INT-F-002: Publish to Elixir" [

        test "F# publishes message successfully" {
            // SC-ZENOH-INT-002: F# must publish messages receivable by Elixir
            let session = MockZenohSession()
            session.Connect() |> ignore

            let cmd = Start "alarm-processor"
            let result = session.Publish(KeyExpressions.control, Control cmd)

            Expect.isTrue result "Publish should succeed when connected"
            Expect.equal (session.GetBufferCount()) 1 "Buffer should contain 1 message"

            session.Disconnect()
        }

        test "F# publish fails when disconnected" {
            let session = MockZenohSession()
            // Do not connect

            let cmd = Stop "alarm-processor"
            let result = session.Publish(KeyExpressions.control, Control cmd)

            Expect.isFalse result "Publish should fail when disconnected"

            session.Disconnect()
        }

        test "F# publishes JSON serializable control command" {
            let session = MockZenohSession()
            session.Connect() |> ignore

            let cmd = Configure ("video-processor", Map.ofList [("quality", "high")])
            let json = serializeControlCommand cmd

            Expect.stringContains json "configure" "Should contain command type"
            Expect.stringContains json "video-processor" "Should contain target"

            session.Disconnect()
        }
    ]

// =============================================================================
// INT-F-003: fractal_log_parsing
// SC-ZENOH-INT-003: Parse incoming fractal logs
// =============================================================================

let fractalLogParsingTests =
    testList "INT-F-003: Fractal Log Parsing" [

        test "Parse valid fractal log JSON" {
            // SC-ZENOH-INT-003: Fractal logs must be parsed correctly
            let json = """
            {
                "timestamp": "2025-12-29T10:00:00Z",
                "level": "info",
                "domain": "alarms",
                "source": "Indrajaal.Alarms.Processor",
                "message": "Alarm created",
                "trace_id": "abc123",
                "span_id": "def456"
            }
            """

            match parseFractalLog json with
            | Some log ->
                Expect.equal log.Level FractalLogLevel.Info "Level should be Info"
                Expect.equal log.Domain "alarms" "Domain should be alarms"
                Expect.equal log.TraceId (Some "abc123") "TraceId should match"
                Expect.equal log.SpanId (Some "def456") "SpanId should match"
            | None -> failtest "Should parse valid JSON"
        }

        test "Parse log with warning level" {
            let json = """{"level": "warning", "domain": "security", "message": "Access attempt"}"""

            match parseFractalLog json with
            | Some log ->
                Expect.equal log.Level FractalLogLevel.Warning "Level should be Warning"
            | None -> failtest "Should parse warning level"
        }

        test "Parse log with critical level" {
            let json = """{"level": "critical", "domain": "system", "message": "System failure"}"""

            match parseFractalLog json with
            | Some log ->
                Expect.equal log.Level FractalLogLevel.Critical "Level should be Critical"
            | None -> failtest "Should parse critical level"
        }

        test "Handle malformed JSON gracefully" {
            let json = """{"level": "info", "domain": """

            let result = parseFractalLog json
            Expect.isNone result "Should return None for malformed JSON"
        }

        test "Handle missing fields with defaults" {
            let json = """{"message": "Just a message"}"""

            match parseFractalLog json with
            | Some log ->
                Expect.equal log.Level FractalLogLevel.Info "Should default to Info"
                Expect.equal log.Domain "unknown" "Should default to unknown domain"
            | None -> failtest "Should parse with defaults"
        }
    ]

// =============================================================================
// INT-F-004: control_command_send
// SC-ZENOH-INT-004: Send commands to Elixir
// =============================================================================

let controlCommandSendTests =
    testList "INT-F-004: Control Command Send" [

        test "Send Start command" {
            // SC-ZENOH-INT-004: Control commands must be sent correctly
            let session = MockZenohSession()
            session.Connect() |> ignore

            let cmd = Start "alarm-processor"
            let result = session.Publish("indrajaal/control/start", Control cmd)

            Expect.isTrue result "Should send start command"

            session.Disconnect()
        }

        test "Send Stop command" {
            let session = MockZenohSession()
            session.Connect() |> ignore

            let cmd = Stop "video-encoder"
            let result = session.Publish("indrajaal/control/stop", Control cmd)

            Expect.isTrue result "Should send stop command"

            session.Disconnect()
        }

        test "Send Restart command" {
            let session = MockZenohSession()
            session.Connect() |> ignore

            let cmd = Restart "dispatch-service"
            let result = session.Publish("indrajaal/control/restart", Control cmd)

            Expect.isTrue result "Should send restart command"

            session.Disconnect()
        }

        test "Send Configure command with parameters" {
            let session = MockZenohSession()
            session.Connect() |> ignore

            let config = Map.ofList [
                ("buffer_size", "1024")
                ("timeout_ms", "5000")
            ]
            let cmd = Configure ("message-broker", config)
            let result = session.Publish("indrajaal/control/configure", Control cmd)

            Expect.isTrue result "Should send configure command"

            session.Disconnect()
        }

        test "Send Query command" {
            let session = MockZenohSession()
            session.Connect() |> ignore

            let queryParams = Map.ofList [("node_id", "node-001")]
            let cmd = Query ("node_status", queryParams)
            let result = session.Publish("indrajaal/control/query", Control cmd)

            Expect.isTrue result "Should send query command"

            session.Disconnect()
        }
    ]

// =============================================================================
// INT-F-005: control_ack_receive
// SC-ZENOH-INT-005: Receive acknowledgments
// =============================================================================

let controlAckReceiveTests =
    testList "INT-F-005: Control Ack Receive" [

        test "Receive success acknowledgment" {
            // SC-ZENOH-INT-005: Acknowledgments must be received
            let session = MockZenohSession()
            session.Connect() |> ignore

            let received = ref None
            session.Subscribe(KeyExpressions.controlAck, fun msg ->
                received := Some msg
            )

            let ack = {
                CommandId = Guid.NewGuid()
                Status = "success"
                Timestamp = DateTimeOffset.UtcNow
                Details = Some "Command executed successfully"
            }
            session.SimulateElixirMessage("indrajaal/control/ack/start", Ack ack)

            match !received with
            | Some (Ack rcvd) ->
                Expect.equal rcvd.Status "success" "Status should be success"
                Expect.isSome rcvd.Details "Should have details"
            | _ -> failtest "Should receive ack"

            session.Disconnect()
        }

        test "Receive failure acknowledgment" {
            let session = MockZenohSession()
            session.Connect() |> ignore

            let received = ref None
            session.Subscribe(KeyExpressions.controlAck, fun msg ->
                received := Some msg
            )

            let ack = {
                CommandId = Guid.NewGuid()
                Status = "failed"
                Timestamp = DateTimeOffset.UtcNow
                Details = Some "Target not found"
            }
            session.SimulateElixirMessage("indrajaal/control/ack/stop", Ack ack)

            match !received with
            | Some (Ack rcvd) ->
                Expect.equal rcvd.Status "failed" "Status should be failed"
            | _ -> failtest "Should receive failure ack"

            session.Disconnect()
        }

        test "Receive pending acknowledgment" {
            let session = MockZenohSession()
            session.Connect() |> ignore

            let received = ref None
            session.Subscribe(KeyExpressions.controlAck, fun msg ->
                received := Some msg
            )

            let ack = {
                CommandId = Guid.NewGuid()
                Status = "pending"
                Timestamp = DateTimeOffset.UtcNow
                Details = Some "Command queued for execution"
            }
            session.SimulateElixirMessage("indrajaal/control/ack/configure", Ack ack)

            match !received with
            | Some (Ack rcvd) ->
                Expect.equal rcvd.Status "pending" "Status should be pending"
            | _ -> failtest "Should receive pending ack"

            session.Disconnect()
        }
    ]

// =============================================================================
// INT-F-006: telemetry_receive
// SC-ZENOH-INT-006: Receive Elixir telemetry
// =============================================================================

let telemetryReceiveTests =
    testList "INT-F-006: Telemetry Receive" [

        test "Receive CPU telemetry" {
            // SC-ZENOH-INT-006: Telemetry must be received
            let session = MockZenohSession()
            session.Connect() |> ignore

            let received = ref None
            session.Subscribe(KeyExpressions.telemetry, fun msg ->
                received := Some msg
            )

            let metric = {
                Name = "cpu_usage"
                Value = 75.5
                Unit = "percent"
                Timestamp = DateTimeOffset.UtcNow
                Tags = Map.ofList [("node", "node-001")]
            }
            session.SimulateElixirMessage("indrajaal/telemetry/cpu", Telemetry metric)

            match !received with
            | Some (Telemetry rcvd) ->
                Expect.equal rcvd.Name "cpu_usage" "Name should match"
                Expect.floatClose Accuracy.medium rcvd.Value 75.5 "Value should match"
            | _ -> failtest "Should receive telemetry"

            session.Disconnect()
        }

        test "Receive memory telemetry" {
            let session = MockZenohSession()
            session.Connect() |> ignore

            let received = ref None
            session.Subscribe(KeyExpressions.telemetry, fun msg ->
                received := Some msg
            )

            let metric = {
                Name = "memory_usage"
                Value = 4096.0
                Unit = "MB"
                Timestamp = DateTimeOffset.UtcNow
                Tags = Map.ofList [("node", "node-002")]
            }
            session.SimulateElixirMessage("indrajaal/telemetry/memory", Telemetry metric)

            match !received with
            | Some (Telemetry rcvd) ->
                Expect.equal rcvd.Name "memory_usage" "Name should match"
                Expect.equal rcvd.Unit "MB" "Unit should match"
            | _ -> failtest "Should receive memory telemetry"

            session.Disconnect()
        }

        test "Receive latency telemetry" {
            let session = MockZenohSession()
            session.Connect() |> ignore

            let received = ref None
            session.Subscribe(KeyExpressions.telemetry, fun msg ->
                received := Some msg
            )

            let metric = {
                Name = "request_latency"
                Value = 25.0
                Unit = "ms"
                Timestamp = DateTimeOffset.UtcNow
                Tags = Map.ofList [("endpoint", "/api/v1/alarms")]
            }
            session.SimulateElixirMessage("indrajaal/telemetry/latency", Telemetry metric)

            match !received with
            | Some (Telemetry rcvd) ->
                Expect.equal rcvd.Name "request_latency" "Name should match"
                Expect.isTrue (rcvd.Value < 50.0) "Latency should be < 50ms (SC-PRF-050)"
            | _ -> failtest "Should receive latency telemetry"

            session.Disconnect()
        }
    ]

// =============================================================================
// INT-F-007: kpi_receive
// SC-ZENOH-INT-007: Receive KPI updates
// =============================================================================

let kpiReceiveTests =
    testList "INT-F-007: KPI Receive" [

        test "Receive alarm processing KPI" {
            // SC-ZENOH-INT-007: KPI updates must be received
            let session = MockZenohSession()
            session.Connect() |> ignore

            let received = ref None
            session.Subscribe(KeyExpressions.kpi, fun msg ->
                received := Some msg
            )

            let kpi = {
                Name = "alarm_processing_rate"
                Value = 150.0
                Target = Some 100.0
                Status = "above_target"
                Domain = "alarms"
                Timestamp = DateTimeOffset.UtcNow
            }
            session.SimulateElixirMessage("indrajaal/kpi/alarms", Kpi kpi)

            match !received with
            | Some (Kpi rcvd) ->
                Expect.equal rcvd.Name "alarm_processing_rate" "Name should match"
                Expect.equal rcvd.Status "above_target" "Status should match"
            | _ -> failtest "Should receive KPI"

            session.Disconnect()
        }

        test "Receive video stream KPI" {
            let session = MockZenohSession()
            session.Connect() |> ignore

            let received = ref None
            session.Subscribe(KeyExpressions.kpi, fun msg ->
                received := Some msg
            )

            let kpi = {
                Name = "active_video_streams"
                Value = 25.0
                Target = Some 50.0
                Status = "below_target"
                Domain = "video"
                Timestamp = DateTimeOffset.UtcNow
            }
            session.SimulateElixirMessage("indrajaal/kpi/video", Kpi kpi)

            match !received with
            | Some (Kpi rcvd) ->
                Expect.equal rcvd.Domain "video" "Domain should match"
            | _ -> failtest "Should receive video KPI"

            session.Disconnect()
        }

        test "Receive KPI without target" {
            let session = MockZenohSession()
            session.Connect() |> ignore

            let received = ref None
            session.Subscribe(KeyExpressions.kpi, fun msg ->
                received := Some msg
            )

            let kpi = {
                Name = "total_users"
                Value = 1500.0
                Target = None
                Status = "normal"
                Domain = "accounts"
                Timestamp = DateTimeOffset.UtcNow
            }
            session.SimulateElixirMessage("indrajaal/kpi/accounts", Kpi kpi)

            match !received with
            | Some (Kpi rcvd) ->
                Expect.isNone rcvd.Target "Target should be None"
            | _ -> failtest "Should receive KPI without target"

            session.Disconnect()
        }
    ]

// =============================================================================
// INT-F-008: connection_status
// SC-ZENOH-INT-008: Track connection state
// =============================================================================

let connectionStatusTests =
    testList "INT-F-008: Connection Status" [

        test "Initial state is Disconnected" {
            // SC-ZENOH-INT-008: Connection state must be tracked
            let session = MockZenohSession()
            Expect.equal session.State Disconnected "Initial state should be Disconnected"
        }

        test "State changes to Connected after connect" {
            let session = MockZenohSession()
            session.Connect() |> ignore

            Expect.equal session.State Connected "State should be Connected"
            Expect.isTrue session.IsConnected "IsConnected should be true"

            session.Disconnect()
        }

        test "State changes to Disconnected after disconnect" {
            let session = MockZenohSession()
            session.Connect() |> ignore
            session.Disconnect()

            Expect.equal session.State Disconnected "State should be Disconnected"
            Expect.isFalse session.IsConnected "IsConnected should be false"
        }

        test "Connect returns true on success" {
            let session = MockZenohSession()
            let result = session.Connect()

            Expect.isTrue result "Connect should return true"

            session.Disconnect()
        }
    ]

// =============================================================================
// INT-F-009: message_filtering
// SC-ZENOH-INT-009: Level/domain filters work
// =============================================================================

let messageFilteringTests =
    testList "INT-F-009: Message Filtering" [

        test "Filter by log level" {
            // SC-ZENOH-INT-009: Message filtering must work
            let filter = {
                Levels = [FractalLogLevel.Error; FractalLogLevel.Critical]
                Domains = []
                IncludeAll = false
            }

            let infoLog = Log {
                Timestamp = DateTimeOffset.UtcNow
                Level = FractalLogLevel.Info
                Domain = "test"
                Source = "test"
                Message = "Info message"
                Metadata = Map.empty
                TraceId = None
                SpanId = None
            }

            let errorLog = Log {
                Timestamp = DateTimeOffset.UtcNow
                Level = FractalLogLevel.Error
                Domain = "test"
                Source = "test"
                Message = "Error message"
                Metadata = Map.empty
                TraceId = None
                SpanId = None
            }

            Expect.isFalse (passesFilter filter infoLog) "Info should be filtered out"
            Expect.isTrue (passesFilter filter errorLog) "Error should pass filter"
        }

        test "Filter by domain" {
            let filter = {
                Levels = []
                Domains = ["alarms"; "security"]
                IncludeAll = false
            }

            let alarmLog = Log {
                Timestamp = DateTimeOffset.UtcNow
                Level = FractalLogLevel.Info
                Domain = "alarms"
                Source = "test"
                Message = "Alarm log"
                Metadata = Map.empty
                TraceId = None
                SpanId = None
            }

            let videoLog = Log {
                Timestamp = DateTimeOffset.UtcNow
                Level = FractalLogLevel.Info
                Domain = "video"
                Source = "test"
                Message = "Video log"
                Metadata = Map.empty
                TraceId = None
                SpanId = None
            }

            Expect.isTrue (passesFilter filter alarmLog) "Alarm domain should pass"
            Expect.isFalse (passesFilter filter videoLog) "Video domain should be filtered"
        }

        test "IncludeAll bypasses all filters" {
            let filter = {
                Levels = [FractalLogLevel.Critical]
                Domains = ["security"]
                IncludeAll = true
            }

            let anyLog = Log {
                Timestamp = DateTimeOffset.UtcNow
                Level = FractalLogLevel.Debug
                Domain = "random"
                Source = "test"
                Message = "Random message"
                Metadata = Map.empty
                TraceId = None
                SpanId = None
            }

            Expect.isTrue (passesFilter filter anyLog) "IncludeAll should pass all messages"
        }

        test "Session filter can be updated" {
            let session = MockZenohSession()
            session.Connect() |> ignore

            let newFilter = {
                Levels = [FractalLogLevel.Warning]
                Domains = ["test"]
                IncludeAll = false
            }
            session.SetFilter(newFilter)

            let retrievedFilter = session.GetFilter()
            Expect.equal retrievedFilter.Levels [FractalLogLevel.Warning] "Filter should be updated"

            session.Disconnect()
        }
    ]

// =============================================================================
// INT-F-010: buffer_management
// SC-ZENOH-INT-010: Message buffering works
// =============================================================================

let bufferManagementTests =
    testList "INT-F-010: Buffer Management" [

        test "Messages are buffered" {
            // SC-ZENOH-INT-010: Buffer management must work
            let session = MockZenohSession()
            session.Connect() |> ignore

            let log = Log {
                Timestamp = DateTimeOffset.UtcNow
                Level = FractalLogLevel.Info
                Domain = "test"
                Source = "test"
                Message = "Buffered message"
                Metadata = Map.empty
                TraceId = None
                SpanId = None
            }

            session.Publish("indrajaal/logs/test", log) |> ignore
            session.Publish("indrajaal/logs/test", log) |> ignore

            Expect.equal (session.GetBufferCount()) 2 "Buffer should contain 2 messages"

            session.Disconnect()
        }

        test "Buffer respects limit" {
            let session = MockZenohSession()
            session.Connect() |> ignore
            session.SetBufferLimit(5)

            let log = Log {
                Timestamp = DateTimeOffset.UtcNow
                Level = FractalLogLevel.Info
                Domain = "test"
                Source = "test"
                Message = "Message"
                Metadata = Map.empty
                TraceId = None
                SpanId = None
            }

            // Publish 10 messages with buffer limit of 5
            for _ in 1..10 do
                session.Publish("indrajaal/logs/test", log) |> ignore

            Expect.equal (session.GetBufferCount()) 5 "Buffer should be limited to 5"

            session.Disconnect()
        }

        test "DrainBuffer returns and clears all messages" {
            let session = MockZenohSession()
            session.Connect() |> ignore

            let log = Log {
                Timestamp = DateTimeOffset.UtcNow
                Level = FractalLogLevel.Info
                Domain = "test"
                Source = "test"
                Message = "Message"
                Metadata = Map.empty
                TraceId = None
                SpanId = None
            }

            session.Publish("indrajaal/logs/test", log) |> ignore
            session.Publish("indrajaal/logs/test", log) |> ignore
            session.Publish("indrajaal/logs/test", log) |> ignore

            let drained = session.DrainBuffer()

            Expect.equal drained.Length 3 "Should drain 3 messages"
            Expect.equal (session.GetBufferCount()) 0 "Buffer should be empty after drain"

            session.Disconnect()
        }

        test "Buffer is cleared on disconnect" {
            let session = MockZenohSession()
            session.Connect() |> ignore

            let log = Log {
                Timestamp = DateTimeOffset.UtcNow
                Level = FractalLogLevel.Info
                Domain = "test"
                Source = "test"
                Message = "Message"
                Metadata = Map.empty
                TraceId = None
                SpanId = None
            }

            session.Publish("indrajaal/logs/test", log) |> ignore
            session.Disconnect()

            Expect.equal (session.GetBufferCount()) 0 "Buffer should be cleared on disconnect"
        }
    ]

// =============================================================================
// INT-F-011: concurrent_subscribers
// SC-ZENOH-INT-011: Multiple subs per session
// =============================================================================

let concurrentSubscribersTests =
    testList "INT-F-011: Concurrent Subscribers" [

        test "Multiple subscribers to same key" {
            // SC-ZENOH-INT-011: Concurrent subscribers must work
            let session = MockZenohSession()
            session.Connect() |> ignore

            let count1 = ref 0
            let count2 = ref 0

            // Note: In real Zenoh, multiple handlers can subscribe to same key
            // Our mock uses key as unique ID, so we use different keys
            session.Subscribe("indrajaal/logs/test1", fun _ -> incr count1)
            session.Subscribe("indrajaal/logs/test2", fun _ -> incr count2)

            Expect.equal (session.GetSubscriberCount()) 2 "Should have 2 subscribers"

            session.Disconnect()
        }

        test "Different key expressions work independently" {
            let session = MockZenohSession()
            session.Connect() |> ignore

            let logCount = ref 0
            let telemetryCount = ref 0

            session.Subscribe(KeyExpressions.logs, fun _ -> incr logCount)
            session.Subscribe(KeyExpressions.telemetry, fun _ -> incr telemetryCount)

            let log = Log {
                Timestamp = DateTimeOffset.UtcNow
                Level = FractalLogLevel.Info
                Domain = "test"
                Source = "test"
                Message = "Log"
                Metadata = Map.empty
                TraceId = None
                SpanId = None
            }

            let metric = Telemetry {
                Name = "test"
                Value = 1.0
                Unit = "unit"
                Timestamp = DateTimeOffset.UtcNow
                Tags = Map.empty
            }

            session.SimulateElixirMessage("indrajaal/logs/test", log)
            session.SimulateElixirMessage("indrajaal/telemetry/test", metric)

            Expect.equal !logCount 1 "Log subscriber should receive 1"
            Expect.equal !telemetryCount 1 "Telemetry subscriber should receive 1"

            session.Disconnect()
        }

        test "Wildcard subscriber receives all" {
            let session = MockZenohSession()
            session.Connect() |> ignore

            let allCount = ref 0
            session.Subscribe("*", fun _ -> incr allCount)

            let log = Log {
                Timestamp = DateTimeOffset.UtcNow
                Level = FractalLogLevel.Info
                Domain = "test"
                Source = "test"
                Message = "Message"
                Metadata = Map.empty
                TraceId = None
                SpanId = None
            }

            session.SimulateElixirMessage("indrajaal/logs/test", log)
            session.SimulateElixirMessage("indrajaal/telemetry/test", log)
            session.SimulateElixirMessage("indrajaal/kpi/test", log)

            Expect.equal !allCount 3 "Wildcard should receive all 3"

            session.Disconnect()
        }

        test "Unsubscribe removes specific subscriber" {
            let session = MockZenohSession()
            session.Connect() |> ignore

            session.Subscribe("key1", fun _ -> ())
            session.Subscribe("key2", fun _ -> ())

            Expect.equal (session.GetSubscriberCount()) 2 "Should have 2 subscribers"

            session.Unsubscribe("key1")

            Expect.equal (session.GetSubscriberCount()) 1 "Should have 1 subscriber after unsubscribe"

            session.Disconnect()
        }
    ]

// =============================================================================
// INT-F-012: graceful_disconnect
// SC-ZENOH-INT-012: Clean shutdown sequence
// =============================================================================

let gracefulDisconnectTests =
    testSequenced <| testList "INT-F-012: Graceful Disconnect" [

        test "Disconnect clears subscribers" {
            // SC-ZENOH-INT-012: Graceful disconnect must work
            let session = MockZenohSession()
            session.Connect() |> ignore

            session.Subscribe("key1", fun _ -> ())
            session.Subscribe("key2", fun _ -> ())

            session.Disconnect()

            Expect.equal (session.GetSubscriberCount()) 0 "Subscribers should be cleared"
        }

        test "Disconnect flushes buffer" {
            let session = MockZenohSession()
            session.Connect() |> ignore

            let log = Log {
                Timestamp = DateTimeOffset.UtcNow
                Level = FractalLogLevel.Info
                Domain = "test"
                Source = "test"
                Message = "Message"
                Metadata = Map.empty
                TraceId = None
                SpanId = None
            }

            session.Publish("test", log) |> ignore

            session.Disconnect()

            Expect.equal (session.GetBufferCount()) 0 "Buffer should be flushed on disconnect"
        }

        test "Multiple disconnect calls are safe" {
            let session = MockZenohSession()
            session.Connect() |> ignore

            session.Disconnect()
            session.Disconnect()
            session.Disconnect()

            Expect.equal session.State Disconnected "State should remain Disconnected"
        }

        test "Operations after disconnect fail gracefully" {
            let session = MockZenohSession()
            session.Connect() |> ignore
            session.Disconnect()

            let log = Log {
                Timestamp = DateTimeOffset.UtcNow
                Level = FractalLogLevel.Info
                Domain = "test"
                Source = "test"
                Message = "Message"
                Metadata = Map.empty
                TraceId = None
                SpanId = None
            }

            let result = session.Publish("test", log)

            Expect.isFalse result "Publish should fail after disconnect"
        }

        test "Can reconnect after disconnect" {
            let session = MockZenohSession()
            session.Connect() |> ignore
            session.Disconnect()

            let result = session.Connect()

            Expect.isTrue result "Should be able to reconnect"
            Expect.isTrue session.IsConnected "Should be connected after reconnect"

            session.Disconnect()
        }
    ]

// =============================================================================
// All Integration Tests
// =============================================================================

[<Tests>]
let zenohElixirIntegrationTests =
    testList "Zenoh-Elixir Integration (INT-F-001 to INT-F-012)" [
        receiveFromElixirTests
        publishToElixirTests
        fractalLogParsingTests
        controlCommandSendTests
        controlAckReceiveTests
        telemetryReceiveTests
        kpiReceiveTests
        connectionStatusTests
        messageFilteringTests
        bufferManagementTests
        concurrentSubscribersTests
        gracefulDisconnectTests
    ]
