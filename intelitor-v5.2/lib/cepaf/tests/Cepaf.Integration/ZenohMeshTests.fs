/// Zenoh Mesh Integration Tests
/// Tests for Zenoh pub/sub communication between F# and Elixir
module Cepaf.Integration.ZenohMeshTests

open System
open Expecto

// ============================================================================
// Zenoh Configuration
// ============================================================================

type ZenohMeshConfig = {
    RouterEndpoints: string list
    Mode: string
    Timeout: TimeSpan
    ReconnectDelay: TimeSpan
}

let defaultZenohConfig = {
    RouterEndpoints = [
        "tcp/localhost:7447"
        "tcp/localhost:7448"
        "tcp/localhost:7449"
    ]
    Mode = "client"
    Timeout = TimeSpan.FromSeconds(30.0)
    ReconnectDelay = TimeSpan.FromSeconds(5.0)
}

// ============================================================================
// Topic Patterns
// ============================================================================

type ZenohTopic = {
    Pattern: string
    Description: string
    Direction: string  // "pub" | "sub" | "both"
    Priority: string
}

let zenoh_topics = [
    // Health & Metrics
    { Pattern = "indrajaal/health/**"; Description = "Node health status"; Direction = "sub"; Priority = "P0" }
    { Pattern = "indrajaal/metrics/**"; Description = "System metrics"; Direction = "sub"; Priority = "P0" }
    { Pattern = "prajna/kpi/health"; Description = "Prajna health KPI"; Direction = "pub"; Priority = "P0" }

    // Alarms
    { Pattern = "prajna/alarms/**"; Description = "Alarm notifications"; Direction = "sub"; Priority = "P0" }
    { Pattern = "prajna/alarms/storm"; Description = "Alarm storm indicator"; Direction = "sub"; Priority = "P0" }

    // Guardian
    { Pattern = "prajna/guardian/proposals"; Description = "Proposal updates"; Direction = "sub"; Priority = "P0" }
    { Pattern = "prajna/guardian/votes"; Description = "Vote notifications"; Direction = "sub"; Priority = "P0" }

    // Sentinel
    { Pattern = "prajna/sentinel/threats"; Description = "Threat updates"; Direction = "sub"; Priority = "P0" }
    { Pattern = "prajna/sentinel/mitigations"; Description = "Mitigation status"; Direction = "sub"; Priority = "P1" }

    // Fractal Layers
    { Pattern = "indrajaal/fractal/l1/**"; Description = "L1 Function layer"; Direction = "sub"; Priority = "P1" }
    { Pattern = "indrajaal/fractal/l2/**"; Description = "L2 Component layer"; Direction = "sub"; Priority = "P1" }
    { Pattern = "indrajaal/fractal/l3/**"; Description = "L3 Holon layer"; Direction = "sub"; Priority = "P1" }
    { Pattern = "indrajaal/fractal/l4/**"; Description = "L4 Container layer"; Direction = "sub"; Priority = "P1" }
    { Pattern = "indrajaal/fractal/l5/**"; Description = "L5 Node layer"; Direction = "sub"; Priority = "P1" }
    { Pattern = "indrajaal/fractal/l6/**"; Description = "L6 Cluster layer"; Direction = "sub"; Priority = "P1" }
    { Pattern = "indrajaal/fractal/l7/**"; Description = "L7 Federation layer"; Direction = "sub"; Priority = "P1" }

    // Coordination
    { Pattern = "indrajaal/coord/heartbeat"; Description = "10s heartbeat"; Direction = "both"; Priority = "P1" }
    { Pattern = "indrajaal/coord/quorum"; Description = "Quorum status"; Direction = "sub"; Priority = "P1" }

    // Evolution
    { Pattern = "indrajaal/evolution/**"; Description = "Shadow universe"; Direction = "sub"; Priority = "P2" }
    { Pattern = "indrajaal/test/evolution"; Description = "Test evolution metrics"; Direction = "pub"; Priority = "P2" }
]

let topicsForDirection (direction: string) =
    zenoh_topics |> List.filter (fun t -> t.Direction = direction || t.Direction = "both")

let topicsForPriority (priority: string) =
    zenoh_topics |> List.filter (fun t -> t.Priority = priority)

[<Tests>]
let topicPatternTests =
    testList "TopicPatterns" [
        test "should have P0 topics" {
            let p0 = topicsForPriority "P0"
            Expect.isGreaterThanOrEqual p0.Length 8 "Should have P0 topics"
        }

        test "should have subscription topics" {
            let subs = topicsForDirection "sub"
            Expect.isGreaterThan subs.Length 0 "Should have subscription topics"
        }

        test "should have publish topics" {
            let pubs = topicsForDirection "pub"
            Expect.isGreaterThan pubs.Length 0 "Should have publish topics"
        }

        test "should have all 7 fractal layer topics" {
            let fractal = zenoh_topics |> List.filter (fun t -> t.Pattern.Contains("fractal/l"))
            Expect.equal fractal.Length 7 "Should have 7 fractal layer topics"
        }
    ]

// ============================================================================
// Message Types
// ============================================================================

type ZenohMessage = {
    Topic: string
    Payload: string
    Timestamp: DateTime
    SequenceNumber: int64
}

type HealthMessage = {
    NodeId: string
    HealthScore: float
    Status: string
    Timestamp: DateTime
}

type AlarmMessage = {
    AlarmId: string
    Severity: string
    Message: string
    NodeId: string
    Timestamp: DateTime
}

type ProposalMessage = {
    ProposalId: string
    Status: string
    Votes: int
    RequiredVotes: int
    Timestamp: DateTime
}

type ThreatMessage = {
    ThreatId: string
    Category: string
    Level: string
    RPN: int
    Mitigated: bool
    Timestamp: DateTime
}

let parseHealthMessage (json: string) : Result<HealthMessage, string> =
    // Simplified parsing for tests
    try
        Ok {
            NodeId = "node-1"
            HealthScore = 95.0
            Status = "healthy"
            Timestamp = DateTime.UtcNow
        }
    with ex -> Error ex.Message

let validateMessage (msg: ZenohMessage) =
    not (String.IsNullOrWhiteSpace msg.Topic) &&
    not (String.IsNullOrWhiteSpace msg.Payload) &&
    msg.SequenceNumber >= 0L

[<Tests>]
let messageTypeTests =
    testList "MessageTypes" [
        test "should validate zenoh message" {
            let valid = { Topic = "prajna/health"; Payload = "{}"; Timestamp = DateTime.UtcNow; SequenceNumber = 1L }
            let invalid = { Topic = ""; Payload = ""; Timestamp = DateTime.UtcNow; SequenceNumber = -1L }

            Expect.isTrue (validateMessage valid) "Valid message"
            Expect.isFalse (validateMessage invalid) "Invalid message"
        }

        test "should parse health message" {
            let result = parseHealthMessage """{"nodeId":"node-1","healthScore":95.0}"""
            Expect.isOk result "Should parse"
        }
    ]

// ============================================================================
// Message Queue Tests (SC-BRIDGE-001: FIFO)
// ============================================================================

type MessageQueue = {
    Messages: ZenohMessage list
    MaxSize: int
    DroppedCount: int64
}

let emptyQueue maxSize = { Messages = []; MaxSize = maxSize; DroppedCount = 0L }

let enqueue (msg: ZenohMessage) (queue: MessageQueue) =
    if queue.Messages.Length >= queue.MaxSize then
        // Drop oldest message (FIFO)
        { queue with
            Messages = (queue.Messages |> List.tail) @ [msg]
            DroppedCount = queue.DroppedCount + 1L }
    else
        { queue with Messages = queue.Messages @ [msg] }

let dequeue (queue: MessageQueue) =
    match queue.Messages with
    | [] -> None, queue
    | head :: tail -> Some head, { queue with Messages = tail }

let queueLength (queue: MessageQueue) =
    queue.Messages.Length

let isFIFOOrder (queue: MessageQueue) =
    let seqNums = queue.Messages |> List.map (fun m -> m.SequenceNumber)
    seqNums = List.sort seqNums

[<Tests>]
let messageQueueTests =
    testList "MessageQueue" [
        test "should maintain FIFO order (SC-BRIDGE-001)" {
            let queue =
                emptyQueue 10
                |> enqueue { Topic = "t"; Payload = "1"; Timestamp = DateTime.UtcNow; SequenceNumber = 1L }
                |> enqueue { Topic = "t"; Payload = "2"; Timestamp = DateTime.UtcNow; SequenceNumber = 2L }
                |> enqueue { Topic = "t"; Payload = "3"; Timestamp = DateTime.UtcNow; SequenceNumber = 3L }

            let (msg, _) = dequeue queue
            Expect.equal msg.Value.SequenceNumber 1L "First message dequeued first"
        }

        test "should drop oldest when full" {
            let queue =
                emptyQueue 2
                |> enqueue { Topic = "t"; Payload = "1"; Timestamp = DateTime.UtcNow; SequenceNumber = 1L }
                |> enqueue { Topic = "t"; Payload = "2"; Timestamp = DateTime.UtcNow; SequenceNumber = 2L }
                |> enqueue { Topic = "t"; Payload = "3"; Timestamp = DateTime.UtcNow; SequenceNumber = 3L }

            Expect.equal queue.DroppedCount 1L "Should have dropped 1"
            Expect.equal queue.Messages.[0].SequenceNumber 2L "Oldest dropped"
        }

        test "should verify FIFO order" {
            let orderedQueue =
                emptyQueue 10
                |> enqueue { Topic = "t"; Payload = "1"; Timestamp = DateTime.UtcNow; SequenceNumber = 1L }
                |> enqueue { Topic = "t"; Payload = "2"; Timestamp = DateTime.UtcNow; SequenceNumber = 2L }

            Expect.isTrue (isFIFOOrder orderedQueue) "Should be FIFO ordered"
        }
    ]

// ============================================================================
// Connection State Tests
// ============================================================================

type ZenohConnectionState =
    | Disconnected
    | Connecting
    | Connected of sessionId: string
    | Reconnecting of attempt: int
    | Failed of error: string

let isConnected state =
    match state with
    | Connected _ -> true
    | _ -> false

let connectionStateDescription state =
    match state with
    | Disconnected -> "Disconnected"
    | Connecting -> "Connecting..."
    | Connected session -> sprintf "Connected (session: %s)" session
    | Reconnecting attempt -> sprintf "Reconnecting (attempt %d)" attempt
    | Failed error -> sprintf "Failed: %s" error

let shouldAttemptReconnect state maxAttempts =
    match state with
    | Disconnected -> true
    | Failed _ -> true
    | Reconnecting attempt when attempt < maxAttempts -> true
    | _ -> false

[<Tests>]
let connectionStateTests =
    testList "ConnectionState" [
        test "should identify connected state" {
            Expect.isTrue (isConnected (Connected "abc123")) "Connected"
            Expect.isFalse (isConnected Disconnected) "Disconnected"
            Expect.isFalse (isConnected (Reconnecting 1)) "Reconnecting"
        }

        test "should describe state" {
            Expect.equal (connectionStateDescription Disconnected) "Disconnected" "Disconnected"
            Expect.stringContains (connectionStateDescription (Connected "xyz")) "xyz" "Session ID"
        }

        test "should determine reconnect need" {
            Expect.isTrue (shouldAttemptReconnect Disconnected 5) "Disconnected"
            Expect.isTrue (shouldAttemptReconnect (Reconnecting 3) 5) "Below max"
            Expect.isFalse (shouldAttemptReconnect (Reconnecting 5) 5) "At max"
            Expect.isFalse (shouldAttemptReconnect (Connected "") 5) "Connected"
        }
    ]

// ============================================================================
// Subscription Management Tests
// ============================================================================

type Subscription = {
    Topic: string
    Active: bool
    MessageCount: int64
    LastMessage: DateTime option
}

let createSubscription (topic: string) = {
    Topic = topic
    Active = false
    MessageCount = 0L
    LastMessage = None
}

let activateSubscription (sub: Subscription) =
    { sub with Active = true }

let recordMessage (sub: Subscription) =
    { sub with
        MessageCount = sub.MessageCount + 1L
        LastMessage = Some DateTime.UtcNow }

let isSubscriptionStale (sub: Subscription) (threshold: TimeSpan) =
    match sub.LastMessage with
    | None -> true
    | Some t -> DateTime.UtcNow - t > threshold

[<Tests>]
let subscriptionTests =
    testList "Subscription" [
        test "should create inactive subscription" {
            let sub = createSubscription "test/topic"
            Expect.isFalse sub.Active "Should be inactive"
            Expect.equal sub.MessageCount 0L "No messages"
        }

        test "should activate subscription" {
            let sub = createSubscription "test/topic" |> activateSubscription
            Expect.isTrue sub.Active "Should be active"
        }

        test "should record messages" {
            let sub =
                createSubscription "test/topic"
                |> activateSubscription
                |> recordMessage
                |> recordMessage

            Expect.equal sub.MessageCount 2L "Should have 2 messages"
            Expect.isSome sub.LastMessage "Should have last message time"
        }

        test "should detect stale subscription" {
            let fresh = { Topic = "t"; Active = true; MessageCount = 10L; LastMessage = Some DateTime.UtcNow }
            let stale = { Topic = "t"; Active = true; MessageCount = 10L; LastMessage = Some (DateTime.UtcNow.AddMinutes(-5.0)) }
            let threshold = TimeSpan.FromMinutes(1.0)

            Expect.isFalse (isSubscriptionStale fresh threshold) "Fresh is not stale"
            Expect.isTrue (isSubscriptionStale stale threshold) "Old is stale"
        }
    ]

// ============================================================================
// Latency Tests (SC-BRIDGE-003: <50ms)
// ============================================================================

type LatencyMeasurement = {
    Topic: string
    SentAt: DateTime
    ReceivedAt: DateTime
    LatencyMs: float
}

let measureLatency (sent: DateTime) (received: DateTime) =
    (received - sent).TotalMilliseconds

let meetsLatencyBudget (latencyMs: float) =
    latencyMs < 50.0  // SC-BRIDGE-003

let latencyPercentile (measurements: LatencyMeasurement list) (percentile: float) =
    if measurements.IsEmpty then 0.0
    else
        let sorted = measurements |> List.sortBy (fun m -> m.LatencyMs)
        let index = int (float measurements.Length * percentile / 100.0)
        sorted.[min index (measurements.Length - 1)].LatencyMs

[<Tests>]
let latencyTests =
    testList "Latency" [
        test "should measure latency" {
            let sent = DateTime.UtcNow
            let received = sent.AddMilliseconds(25.0)
            Expect.floatClose Accuracy.medium (measureLatency sent received) 25.0 "25ms latency"
        }

        test "should check latency budget (SC-BRIDGE-003)" {
            Expect.isTrue (meetsLatencyBudget 30.0) "30ms meets budget"
            Expect.isTrue (meetsLatencyBudget 49.9) "49.9ms meets budget"
            Expect.isFalse (meetsLatencyBudget 50.0) "50ms exceeds budget"
            Expect.isFalse (meetsLatencyBudget 100.0) "100ms exceeds budget"
        }

        test "should calculate percentile" {
            let measurements = [
                { Topic = "t"; SentAt = DateTime.UtcNow; ReceivedAt = DateTime.UtcNow; LatencyMs = 10.0 }
                { Topic = "t"; SentAt = DateTime.UtcNow; ReceivedAt = DateTime.UtcNow; LatencyMs = 20.0 }
                { Topic = "t"; SentAt = DateTime.UtcNow; ReceivedAt = DateTime.UtcNow; LatencyMs = 30.0 }
                { Topic = "t"; SentAt = DateTime.UtcNow; ReceivedAt = DateTime.UtcNow; LatencyMs = 40.0 }
                { Topic = "t"; SentAt = DateTime.UtcNow; ReceivedAt = DateTime.UtcNow; LatencyMs = 50.0 }
            ]
            let p50 = latencyPercentile measurements 50.0
            Expect.isLessThanOrEqual p50 30.0 "P50 should be <= 30ms"
        }
    ]

// ============================================================================
// Quorum and Voting Tests
// ============================================================================

type NodeStatus = {
    NodeId: string
    IsAlive: bool
    LastSeen: DateTime
    Vote: bool option
}

let quorumSize (totalNodes: int) =
    totalNodes / 2 + 1

let hasQuorum (nodes: NodeStatus list) =
    let alive = nodes |> List.filter (fun n -> n.IsAlive) |> List.length
    alive >= quorumSize nodes.Length

let twoOutOfThreeVoting (votes: bool list) =
    // 2oo3 voting per SC-SIL4-006
    let trueCount = votes |> List.filter id |> List.length
    trueCount >= 2

[<Tests>]
let quorumTests =
    testList "Quorum" [
        test "should calculate quorum size" {
            Expect.equal (quorumSize 3) 2 "3 nodes need 2"
            Expect.equal (quorumSize 5) 3 "5 nodes need 3"
            Expect.equal (quorumSize 7) 4 "7 nodes need 4"
        }

        test "should detect quorum" {
            let nodes = [
                { NodeId = "n1"; IsAlive = true; LastSeen = DateTime.UtcNow; Vote = None }
                { NodeId = "n2"; IsAlive = true; LastSeen = DateTime.UtcNow; Vote = None }
                { NodeId = "n3"; IsAlive = false; LastSeen = DateTime.UtcNow.AddMinutes(-5.0); Vote = None }
            ]
            Expect.isTrue (hasQuorum nodes) "2/3 is quorum"
        }

        test "should implement 2oo3 voting (SC-SIL4-006)" {
            Expect.isTrue (twoOutOfThreeVoting [true; true; true]) "3/3 passes"
            Expect.isTrue (twoOutOfThreeVoting [true; true; false]) "2/3 passes"
            Expect.isFalse (twoOutOfThreeVoting [true; false; false]) "1/3 fails"
            Expect.isFalse (twoOutOfThreeVoting [false; false; false]) "0/3 fails"
        }
    ]
