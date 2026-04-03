/// Avalonia GUI Service Tests
/// Tests for ElixirClient, ZenohSubscriber, and Bridge services
module Cepaf.Cockpit.Avalonia.Tests.ServiceTests

open System
open System.Net.Http
open Expecto

// ============================================================================
// Elixir Client Service Tests
// ============================================================================

type ElixirClientConfig = {
    BaseUrl: string
    Timeout: TimeSpan
    RetryCount: int
    RetryDelay: TimeSpan
}

let defaultElixirConfig = {
    BaseUrl = "http://localhost:4000"
    Timeout = TimeSpan.FromSeconds(30.0)
    RetryCount = 3
    RetryDelay = TimeSpan.FromSeconds(1.0)
}

type ApiResponse<'T> =
    | Success of 'T
    | HttpError of statusCode: int * message: string
    | NetworkError of message: string
    | Timeout

let buildApiUrl (config: ElixirClientConfig) (endpoint: string) =
    let endpoint = if endpoint.StartsWith("/") then endpoint else "/" + endpoint
    sprintf "%s%s" config.BaseUrl endpoint

let shouldRetryStatus (statusCode: int) =
    statusCode = 429 || statusCode >= 500

let calculateRetryDelay (config: ElixirClientConfig) (attempt: int) =
    // Exponential backoff
    let multiplier = Math.Pow(2.0, float attempt)
    TimeSpan.FromMilliseconds(config.RetryDelay.TotalMilliseconds * multiplier)

[<Tests>]
let elixirClientTests =
    testList "ElixirClient" [
        test "should build API URLs correctly" {
            let url = buildApiUrl defaultElixirConfig "/api/health"
            Expect.equal url "http://localhost:4000/api/health" "Health endpoint"
        }

        test "should handle endpoints without leading slash" {
            let url = buildApiUrl defaultElixirConfig "api/prajna/metrics"
            Expect.equal url "http://localhost:4000/api/prajna/metrics" "Without slash"
        }

        test "should identify retryable status codes" {
            Expect.isTrue (shouldRetryStatus 429) "429 is retryable"
            Expect.isTrue (shouldRetryStatus 500) "500 is retryable"
            Expect.isTrue (shouldRetryStatus 502) "502 is retryable"
            Expect.isTrue (shouldRetryStatus 503) "503 is retryable"
            Expect.isFalse (shouldRetryStatus 400) "400 is not retryable"
            Expect.isFalse (shouldRetryStatus 404) "404 is not retryable"
        }

        test "should calculate exponential backoff" {
            let delay0 = calculateRetryDelay defaultElixirConfig 0
            let delay1 = calculateRetryDelay defaultElixirConfig 1
            let delay2 = calculateRetryDelay defaultElixirConfig 2

            Expect.equal delay0.TotalSeconds 1.0 "First delay is 1s"
            Expect.equal delay1.TotalSeconds 2.0 "Second delay is 2s"
            Expect.equal delay2.TotalSeconds 4.0 "Third delay is 4s"
        }
    ]

// ============================================================================
// Zenoh Subscriber Service Tests
// ============================================================================

type ZenohConfig = {
    RouterEndpoint: string
    Mode: string
    Topics: string list
    ReconnectDelay: TimeSpan
}

let defaultZenohConfig = {
    RouterEndpoint = "tcp/localhost:7447"
    Mode = "client"
    Topics = [
        "indrajaal/health/**"
        "indrajaal/metrics/**"
        "prajna/kpi/**"
        "prajna/alarms/**"
    ]
    ReconnectDelay = TimeSpan.FromSeconds(5.0)
}

type ZenohConnectionState =
    | Disconnected
    | Connecting
    | Connected
    | Reconnecting of attempt: int
    | Error of message: string

let isZenohConnected state =
    match state with
    | Connected -> true
    | _ -> false

let zenohStateDescription state =
    match state with
    | Disconnected -> "Disconnected"
    | Connecting -> "Connecting..."
    | Connected -> "Connected"
    | Reconnecting attempt -> sprintf "Reconnecting (attempt %d)" attempt
    | Error msg -> sprintf "Error: %s" msg

let shouldReconnect (state: ZenohConnectionState) (maxAttempts: int) =
    match state with
    | Disconnected -> true
    | Error _ -> true
    | Reconnecting attempt when attempt < maxAttempts -> true
    | _ -> false

[<Tests>]
let zenohSubscriberTests =
    testList "ZenohSubscriber" [
        test "should detect connected state" {
            Expect.isTrue (isZenohConnected Connected) "Connected is connected"
            Expect.isFalse (isZenohConnected Disconnected) "Disconnected is not connected"
            Expect.isFalse (isZenohConnected Connecting) "Connecting is not connected"
            Expect.isFalse (isZenohConnected (Reconnecting 1)) "Reconnecting is not connected"
        }

        test "should describe state correctly" {
            Expect.equal (zenohStateDescription Connected) "Connected" "Connected"
            Expect.stringContains (zenohStateDescription (Reconnecting 3)) "attempt 3" "Reconnecting"
            Expect.stringContains (zenohStateDescription (Error "timeout")) "timeout" "Error"
        }

        test "should determine reconnection need" {
            Expect.isTrue (shouldReconnect Disconnected 5) "Disconnected should reconnect"
            Expect.isTrue (shouldReconnect (Error "network") 5) "Error should reconnect"
            Expect.isTrue (shouldReconnect (Reconnecting 2) 5) "Below max attempts"
            Expect.isFalse (shouldReconnect (Reconnecting 5) 5) "At max attempts"
            Expect.isFalse (shouldReconnect Connected 5) "Connected shouldn't reconnect"
        }

        test "should have default topics" {
            Expect.isGreaterThan defaultZenohConfig.Topics.Length 0 "Should have topics"
            Expect.contains defaultZenohConfig.Topics "indrajaal/health/**" "Health topic"
        }
    ]

// ============================================================================
// Guardian Bridge Service Tests
// ============================================================================

type GuardianCommand =
    | ApproveProposal of proposalId: string * reason: string
    | VetoProposal of proposalId: string * reason: string
    | GetProposal of proposalId: string
    | ListProposals of status: string option

type GuardianResponse = {
    Success: bool
    ProposalId: string option
    Message: string
    Timestamp: DateTime
}

let guardianEndpoint (cmd: GuardianCommand) =
    match cmd with
    | ApproveProposal _ -> "/api/prajna/guardian/approve"
    | VetoProposal _ -> "/api/prajna/guardian/veto"
    | GetProposal id -> sprintf "/api/prajna/guardian/proposals/%s" id
    | ListProposals _ -> "/api/prajna/guardian/proposals"

let guardianMethod (cmd: GuardianCommand) =
    match cmd with
    | ApproveProposal _ | VetoProposal _ -> "POST"
    | GetProposal _ | ListProposals _ -> "GET"

let guardianRequiresReason (cmd: GuardianCommand) =
    match cmd with
    | ApproveProposal _ | VetoProposal _ -> true
    | _ -> false

[<Tests>]
let guardianBridgeTests =
    testList "GuardianBridge" [
        test "should map commands to endpoints" {
            Expect.equal (guardianEndpoint (ApproveProposal ("p-1", ""))) "/api/prajna/guardian/approve" "Approve"
            Expect.equal (guardianEndpoint (VetoProposal ("p-1", ""))) "/api/prajna/guardian/veto" "Veto"
            Expect.stringContains (guardianEndpoint (GetProposal "p-123")) "p-123" "Get by ID"
        }

        test "should identify HTTP methods" {
            Expect.equal (guardianMethod (ApproveProposal ("", ""))) "POST" "Approve is POST"
            Expect.equal (guardianMethod (VetoProposal ("", ""))) "POST" "Veto is POST"
            Expect.equal (guardianMethod (GetProposal "")) "GET" "Get is GET"
            Expect.equal (guardianMethod (ListProposals None)) "GET" "List is GET"
        }

        test "should identify commands requiring reason" {
            Expect.isTrue (guardianRequiresReason (ApproveProposal ("", ""))) "Approve needs reason"
            Expect.isTrue (guardianRequiresReason (VetoProposal ("", ""))) "Veto needs reason"
            Expect.isFalse (guardianRequiresReason (GetProposal "")) "Get doesn't need reason"
        }
    ]

// ============================================================================
// Sentinel Bridge Service Tests
// ============================================================================

type SentinelCommand =
    | ReportThreat of category: string * description: string * source: string
    | MitigateThreat of threatId: string
    | GetThreat of threatId: string
    | ListThreats of active: bool
    | GetRPN of threatId: string

type SentinelResponse = {
    Success: bool
    ThreatId: string option
    RPN: int option
    Message: string
}

let sentinelEndpoint (cmd: SentinelCommand) =
    match cmd with
    | ReportThreat _ -> "/api/prajna/sentinel/report"
    | MitigateThreat _ -> "/api/prajna/sentinel/mitigate"
    | GetThreat id -> sprintf "/api/prajna/sentinel/threats/%s" id
    | ListThreats _ -> "/api/prajna/sentinel/threats"
    | GetRPN id -> sprintf "/api/prajna/sentinel/threats/%s/rpn" id

let sentinelMethod (cmd: SentinelCommand) =
    match cmd with
    | ReportThreat _ | MitigateThreat _ -> "POST"
    | GetThreat _ | ListThreats _ | GetRPN _ -> "GET"

let calculateRPN (severity: int) (occurrence: int) (detection: int) =
    // RPN = Severity × Occurrence × Detection
    // Each factor is 1-10
    severity * occurrence * detection

let rpnSeverity (rpn: int) =
    if rpn >= 200 then "Critical"
    elif rpn >= 100 then "High"
    elif rpn >= 50 then "Medium"
    else "Low"

[<Tests>]
let sentinelBridgeTests =
    testList "SentinelBridge" [
        test "should map commands to endpoints" {
            Expect.equal (sentinelEndpoint (ReportThreat ("", "", ""))) "/api/prajna/sentinel/report" "Report"
            Expect.equal (sentinelEndpoint (MitigateThreat "t-1")) "/api/prajna/sentinel/mitigate" "Mitigate"
            Expect.stringContains (sentinelEndpoint (GetThreat "t-123")) "t-123" "Get by ID"
        }

        test "should calculate RPN correctly" {
            Expect.equal (calculateRPN 10 8 5) 400 "High severity RPN"
            Expect.equal (calculateRPN 5 5 5) 125 "Medium RPN"
            Expect.equal (calculateRPN 2 2 2) 8 "Low RPN"
        }

        test "should categorize RPN severity" {
            Expect.equal (rpnSeverity 400) "Critical" ">= 200 is Critical"
            Expect.equal (rpnSeverity 150) "High" ">= 100 is High"
            Expect.equal (rpnSeverity 75) "Medium" ">= 50 is Medium"
            Expect.equal (rpnSeverity 25) "Low" "< 50 is Low"
        }
    ]

// ============================================================================
// Message Serialization Tests
// ============================================================================

type HealthMessage = {
    NodeId: string
    HealthScore: float
    Timestamp: DateTime
}

type AlarmMessage = {
    AlarmId: string
    Severity: string
    Message: string
    NodeId: string
    Timestamp: DateTime
}

let serializeHealth (msg: HealthMessage) =
    sprintf """{"nodeId":"%s","healthScore":%.2f,"timestamp":"%s"}"""
        msg.NodeId msg.HealthScore (msg.Timestamp.ToString("o"))

let serializeAlarm (msg: AlarmMessage) =
    sprintf """{"alarmId":"%s","severity":"%s","message":"%s","nodeId":"%s","timestamp":"%s"}"""
        msg.AlarmId msg.Severity msg.Message msg.NodeId (msg.Timestamp.ToString("o"))

[<Tests>]
let serializationTests =
    testList "Serialization" [
        test "should serialize health message" {
            let msg = { NodeId = "node-1"; HealthScore = 95.5; Timestamp = DateTime(2026, 1, 17, 10, 0, 0, DateTimeKind.Utc) }
            let json = serializeHealth msg
            Expect.stringContains json "node-1" "Contains nodeId"
            Expect.stringContains json "95.50" "Contains healthScore"
        }

        test "should serialize alarm message" {
            let msg = { AlarmId = "a-1"; Severity = "critical"; Message = "CPU high"; NodeId = "n-1"; Timestamp = DateTime.UtcNow }
            let json = serializeAlarm msg
            Expect.stringContains json "a-1" "Contains alarmId"
            Expect.stringContains json "critical" "Contains severity"
            Expect.stringContains json "CPU high" "Contains message"
        }
    ]

// ============================================================================
// Connection Health Tests
// ============================================================================

type ConnectionHealth = {
    ElixirConnected: bool
    ZenohConnected: bool
    LastHealthCheck: DateTime option
    LatencyMs: int option
}

let overallConnectionStatus (health: ConnectionHealth) =
    if health.ElixirConnected && health.ZenohConnected then "Healthy"
    elif health.ElixirConnected || health.ZenohConnected then "Degraded"
    else "Disconnected"

let isConnectionStale (health: ConnectionHealth) (threshold: TimeSpan) =
    match health.LastHealthCheck with
    | None -> true
    | Some t -> DateTime.UtcNow - t > threshold

let latencyStatus (latencyMs: int option) =
    match latencyMs with
    | None -> "Unknown"
    | Some ms when ms < 50 -> "Excellent"
    | Some ms when ms < 100 -> "Good"
    | Some ms when ms < 200 -> "Fair"
    | Some _ -> "Poor"

[<Tests>]
let connectionHealthTests =
    testList "ConnectionHealth" [
        test "should report overall status" {
            let healthy = { ElixirConnected = true; ZenohConnected = true; LastHealthCheck = Some DateTime.UtcNow; LatencyMs = Some 50 }
            let degraded = { healthy with ZenohConnected = false }
            let disconnected = { healthy with ElixirConnected = false; ZenohConnected = false }

            Expect.equal (overallConnectionStatus healthy) "Healthy" "Both connected"
            Expect.equal (overallConnectionStatus degraded) "Degraded" "One connected"
            Expect.equal (overallConnectionStatus disconnected) "Disconnected" "None connected"
        }

        test "should detect stale connection" {
            let fresh = { ElixirConnected = true; ZenohConnected = true; LastHealthCheck = Some DateTime.UtcNow; LatencyMs = Some 50 }
            let stale = { fresh with LastHealthCheck = Some (DateTime.UtcNow.AddMinutes(-5.0)) }
            let threshold = TimeSpan.FromMinutes(1.0)

            Expect.isFalse (isConnectionStale fresh threshold) "Fresh is not stale"
            Expect.isTrue (isConnectionStale stale threshold) "Old is stale"
        }

        test "should categorize latency" {
            Expect.equal (latencyStatus (Some 30)) "Excellent" "< 50ms"
            Expect.equal (latencyStatus (Some 75)) "Good" "< 100ms"
            Expect.equal (latencyStatus (Some 150)) "Fair" "< 200ms"
            Expect.equal (latencyStatus (Some 300)) "Poor" ">= 200ms"
            Expect.equal (latencyStatus None) "Unknown" "No data"
        }
    ]

// ============================================================================
// Cache Service Tests
// ============================================================================

type CacheEntry<'T> = {
    Value: 'T
    CachedAt: DateTime
    ExpiresAt: DateTime
    HitCount: int
}

let isCacheValid (entry: CacheEntry<'T>) =
    DateTime.UtcNow < entry.ExpiresAt

let createCacheEntry (value: 'T) (ttl: TimeSpan) = {
    Value = value
    CachedAt = DateTime.UtcNow
    ExpiresAt = DateTime.UtcNow + ttl
    HitCount = 0
}

let recordCacheHit (entry: CacheEntry<'T>) =
    { entry with HitCount = entry.HitCount + 1 }

[<Tests>]
let cacheServiceTests =
    testList "CacheService" [
        test "should create valid cache entry" {
            let entry = createCacheEntry "test" (TimeSpan.FromMinutes(5.0))
            Expect.isTrue (isCacheValid entry) "New entry should be valid"
            Expect.equal entry.HitCount 0 "New entry has 0 hits"
        }

        test "should detect expired entry" {
            let entry = {
                Value = "test"
                CachedAt = DateTime.UtcNow.AddMinutes(-10.0)
                ExpiresAt = DateTime.UtcNow.AddMinutes(-5.0)
                HitCount = 5
            }
            Expect.isFalse (isCacheValid entry) "Expired entry should be invalid"
        }

        test "should increment hit count" {
            let entry = createCacheEntry "test" (TimeSpan.FromMinutes(5.0))
            let hit1 = recordCacheHit entry
            let hit2 = recordCacheHit hit1
            Expect.equal hit2.HitCount 2 "Should have 2 hits"
        }
    ]
