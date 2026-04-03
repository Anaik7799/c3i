/// WebUI Service Tests
/// Tests for backend integration, HTTP clients, and Zenoh bridge
module Cepaf.Cockpit.Web.Tests.ServiceTests

open System
open System.Net.Http
open Expecto

// ============================================================================
// HTTP Client Service Tests
// ============================================================================

type HttpResponse<'T> =
    | Success of 'T
    | HttpError of int * string
    | NetworkError of string
    | Timeout

type ElixirApiConfig = {
    BaseUrl: string
    Timeout: TimeSpan
    RetryCount: int
}

let defaultApiConfig = {
    BaseUrl = "http://localhost:4000"
    Timeout = TimeSpan.FromSeconds(30.0)
    RetryCount = 3
}

let buildUrl (config: ElixirApiConfig) (path: string) =
    sprintf "%s%s" config.BaseUrl path

[<Tests>]
let httpClientTests =
    testList "HttpClient" [
        test "should build correct URL" {
            let url = buildUrl defaultApiConfig "/api/health"
            Expect.equal url "http://localhost:4000/api/health" "Should build URL"
        }

        test "should handle path with leading slash" {
            let url = buildUrl defaultApiConfig "/api/prajna/metrics"
            Expect.equal url "http://localhost:4000/api/prajna/metrics" "Should handle path"
        }
    ]

// ============================================================================
// Health API Tests
// ============================================================================

type SystemHealth = {
    OverallHealth: float
    ConnectedNodes: int
    ActiveAlarms: int
    PendingProposals: int
    ActiveThreats: int
    Timestamp: DateTime
}

let parseHealthResponse (json: string) : Result<SystemHealth, string> =
    // Simplified parsing for tests
    try
        Ok {
            OverallHealth = 95.0
            ConnectedNodes = 3
            ActiveAlarms = 2
            PendingProposals = 1
            ActiveThreats = 0
            Timestamp = DateTime.UtcNow
        }
    with ex ->
        Error ex.Message

let isHealthy (health: SystemHealth) =
    health.OverallHealth >= 70.0

[<Tests>]
let healthApiTests =
    testList "HealthAPI" [
        test "should determine healthy status" {
            let health = {
                OverallHealth = 95.0
                ConnectedNodes = 3
                ActiveAlarms = 0
                PendingProposals = 0
                ActiveThreats = 0
                Timestamp = DateTime.UtcNow
            }
            Expect.isTrue (isHealthy health) "95% is healthy"
        }

        test "should determine unhealthy status" {
            let health = {
                OverallHealth = 50.0
                ConnectedNodes = 1
                ActiveAlarms = 10
                PendingProposals = 5
                ActiveThreats = 3
                Timestamp = DateTime.UtcNow
            }
            Expect.isFalse (isHealthy health) "50% is not healthy"
        }
    ]

// ============================================================================
// Guardian API Tests
// ============================================================================

type GuardianCommand =
    | ApproveProposal of proposalId: string * reason: string
    | VetoProposal of proposalId: string * reason: string
    | SubmitProposal of title: string * description: string * category: string

type GuardianResponse = {
    Success: bool
    ProposalId: string
    Message: string
}

let commandToEndpoint (cmd: GuardianCommand) =
    match cmd with
    | ApproveProposal _ -> "/api/prajna/guardian/approve"
    | VetoProposal _ -> "/api/prajna/guardian/veto"
    | SubmitProposal _ -> "/api/prajna/guardian/submit"

let commandToJson (cmd: GuardianCommand) =
    match cmd with
    | ApproveProposal (id, reason) ->
        sprintf """{"proposalId":"%s","reason":"%s"}""" id reason
    | VetoProposal (id, reason) ->
        sprintf """{"proposalId":"%s","reason":"%s"}""" id reason
    | SubmitProposal (title, desc, cat) ->
        sprintf """{"title":"%s","description":"%s","category":"%s"}""" title desc cat

[<Tests>]
let guardianApiTests =
    testList "GuardianAPI" [
        test "should map approve to correct endpoint" {
            let cmd = ApproveProposal ("p-1", "Looks good")
            let endpoint = commandToEndpoint cmd
            Expect.equal endpoint "/api/prajna/guardian/approve" "Approve endpoint"
        }

        test "should map veto to correct endpoint" {
            let cmd = VetoProposal ("p-2", "Security concern")
            let endpoint = commandToEndpoint cmd
            Expect.equal endpoint "/api/prajna/guardian/veto" "Veto endpoint"
        }

        test "should serialize approve command" {
            let cmd = ApproveProposal ("p-1", "LGTM")
            let json = commandToJson cmd
            Expect.stringContains json "p-1" "Should contain proposal ID"
            Expect.stringContains json "LGTM" "Should contain reason"
        }
    ]

// ============================================================================
// Sentinel API Tests
// ============================================================================

type SentinelCommand =
    | ReportThreat of category: string * description: string * source: string
    | MitigateThreat of threatId: string
    | GetThreats

let sentinelEndpoint (cmd: SentinelCommand) =
    match cmd with
    | ReportThreat _ -> "/api/prajna/sentinel/report"
    | MitigateThreat _ -> "/api/prajna/sentinel/mitigate"
    | GetThreats -> "/api/prajna/sentinel/threats"

[<Tests>]
let sentinelApiTests =
    testList "SentinelAPI" [
        test "should map commands to endpoints" {
            Expect.equal (sentinelEndpoint (ReportThreat ("", "", ""))) "/api/prajna/sentinel/report" "Report"
            Expect.equal (sentinelEndpoint (MitigateThreat "t-1")) "/api/prajna/sentinel/mitigate" "Mitigate"
            Expect.equal (sentinelEndpoint GetThreats) "/api/prajna/sentinel/threats" "Get threats"
        }
    ]

// ============================================================================
// Zenoh Bridge Service Tests
// ============================================================================

type ZenohConnectionState =
    | Connected
    | Connecting
    | Reconnecting of attempt: int
    | Disconnected
    | Error of string

type ZenohSubscription = {
    Topic: string
    Active: bool
    MessageCount: int64
    LastMessage: DateTime option
}

let isZenohConnected state =
    match state with
    | Connected -> true
    | _ -> false

let subscriptionIsStale (sub: ZenohSubscription) (threshold: TimeSpan) =
    match sub.LastMessage with
    | None -> true
    | Some last -> DateTime.UtcNow - last > threshold

[<Tests>]
let zenohBridgeTests =
    testList "ZenohBridge" [
        test "should detect connected state" {
            Expect.isTrue (isZenohConnected Connected) "Connected is connected"
            Expect.isFalse (isZenohConnected Disconnected) "Disconnected is not connected"
            Expect.isFalse (isZenohConnected (Reconnecting 1)) "Reconnecting is not connected"
        }

        test "should detect stale subscription" {
            let sub = {
                Topic = "test/topic"
                Active = true
                MessageCount = 100L
                LastMessage = Some (DateTime.UtcNow.AddMinutes(-5.0))
            }
            let isStale = subscriptionIsStale sub (TimeSpan.FromMinutes(1.0))
            Expect.isTrue isStale "Should be stale after 1 minute"
        }

        test "should not be stale with recent message" {
            let sub = {
                Topic = "test/topic"
                Active = true
                MessageCount = 100L
                LastMessage = Some DateTime.UtcNow
            }
            let isStale = subscriptionIsStale sub (TimeSpan.FromMinutes(1.0))
            Expect.isFalse isStale "Should not be stale"
        }
    ]

// ============================================================================
// SignalR Hub Tests
// ============================================================================

type HubMessage =
    | HealthUpdate of SystemHealth
    | AlarmUpdate of alarmId: string * level: string * message: string
    | ProposalUpdate of proposalId: string * votes: int
    | ThreatUpdate of threatId: string * mitigated: bool

let hubMessageType (msg: HubMessage) =
    match msg with
    | HealthUpdate _ -> "HealthUpdate"
    | AlarmUpdate _ -> "AlarmUpdate"
    | ProposalUpdate _ -> "ProposalUpdate"
    | ThreatUpdate _ -> "ThreatUpdate"

[<Tests>]
let signalRHubTests =
    testList "SignalRHub" [
        test "should identify message types" {
            let health = HealthUpdate { OverallHealth = 95.0; ConnectedNodes = 3; ActiveAlarms = 0; PendingProposals = 0; ActiveThreats = 0; Timestamp = DateTime.UtcNow }
            let alarm = AlarmUpdate ("a-1", "critical", "CPU high")
            let proposal = ProposalUpdate ("p-1", 2)
            let threat = ThreatUpdate ("t-1", false)

            Expect.equal (hubMessageType health) "HealthUpdate" "Health message"
            Expect.equal (hubMessageType alarm) "AlarmUpdate" "Alarm message"
            Expect.equal (hubMessageType proposal) "ProposalUpdate" "Proposal message"
            Expect.equal (hubMessageType threat) "ThreatUpdate" "Threat message"
        }
    ]

// ============================================================================
// Retry Policy Tests
// ============================================================================

type RetryPolicy = {
    MaxRetries: int
    InitialDelay: TimeSpan
    MaxDelay: TimeSpan
    ExponentialBase: float
}

let defaultRetryPolicy = {
    MaxRetries = 3
    InitialDelay = TimeSpan.FromSeconds(1.0)
    MaxDelay = TimeSpan.FromSeconds(30.0)
    ExponentialBase = 2.0
}

let calculateDelay (policy: RetryPolicy) (attempt: int) =
    let delay = policy.InitialDelay.TotalMilliseconds * (policy.ExponentialBase ** float attempt)
    let capped = min delay policy.MaxDelay.TotalMilliseconds
    TimeSpan.FromMilliseconds(capped)

let shouldRetry (policy: RetryPolicy) (attempt: int) (statusCode: int) =
    attempt < policy.MaxRetries &&
    (statusCode = 429 || statusCode >= 500)

[<Tests>]
let retryPolicyTests =
    testList "RetryPolicy" [
        test "should calculate exponential delay" {
            let delay0 = calculateDelay defaultRetryPolicy 0
            let delay1 = calculateDelay defaultRetryPolicy 1
            let delay2 = calculateDelay defaultRetryPolicy 2

            Expect.equal delay0.TotalSeconds 1.0 "First delay is 1s"
            Expect.equal delay1.TotalSeconds 2.0 "Second delay is 2s"
            Expect.equal delay2.TotalSeconds 4.0 "Third delay is 4s"
        }

        test "should cap delay at max" {
            let delay10 = calculateDelay defaultRetryPolicy 10
            Expect.isLessThanOrEqual delay10.TotalSeconds 30.0 "Should cap at 30s"
        }

        test "should retry on 429 rate limit" {
            Expect.isTrue (shouldRetry defaultRetryPolicy 0 429) "Should retry 429"
        }

        test "should retry on 500 errors" {
            Expect.isTrue (shouldRetry defaultRetryPolicy 0 500) "Should retry 500"
            Expect.isTrue (shouldRetry defaultRetryPolicy 0 502) "Should retry 502"
            Expect.isTrue (shouldRetry defaultRetryPolicy 0 503) "Should retry 503"
        }

        test "should not retry on 400 errors" {
            Expect.isFalse (shouldRetry defaultRetryPolicy 0 400) "Should not retry 400"
            Expect.isFalse (shouldRetry defaultRetryPolicy 0 401) "Should not retry 401"
            Expect.isFalse (shouldRetry defaultRetryPolicy 0 404) "Should not retry 404"
        }

        test "should stop after max retries" {
            Expect.isFalse (shouldRetry defaultRetryPolicy 3 500) "Should stop after max"
        }
    ]

// ============================================================================
// Cache Service Tests
// ============================================================================

type CacheEntry<'T> = {
    Value: 'T
    CachedAt: DateTime
    ExpiresAt: DateTime
}

let isCacheValid (entry: CacheEntry<'T>) =
    DateTime.UtcNow < entry.ExpiresAt

let createCacheEntry (value: 'T) (ttl: TimeSpan) = {
    Value = value
    CachedAt = DateTime.UtcNow
    ExpiresAt = DateTime.UtcNow + ttl
}

[<Tests>]
let cacheServiceTests =
    testList "CacheService" [
        test "should create valid cache entry" {
            let entry = createCacheEntry "test" (TimeSpan.FromMinutes(5.0))
            Expect.isTrue (isCacheValid entry) "New entry should be valid"
        }

        test "should detect expired entry" {
            let entry = {
                Value = "test"
                CachedAt = DateTime.UtcNow.AddMinutes(-10.0)
                ExpiresAt = DateTime.UtcNow.AddMinutes(-5.0)
            }
            Expect.isFalse (isCacheValid entry) "Expired entry should be invalid"
        }
    ]
