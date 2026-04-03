// =============================================================================
// ZenohTypesTests.fs - Unit Tests for ZenohTypes (L1)
// =============================================================================
// STAMP: SC-NAT-001, SC-NAT-002, SC-TDG-001
// AOR: AOR-TEST-001, AOR-TEST-EVO-001
// Criticality: Level 1 (CRITICAL) - Foundation Type Tests
// =============================================================================

module Cepaf.Zenoh.Tests.ZenohTypesTests

open System
open Expecto
open Cepaf.Zenoh.Core

// =============================================================================
// ConnectionStatus Tests
// =============================================================================

[<Tests>]
let connectionStatusTests =
    testList "ConnectionStatus" [
        test "Disconnected is not healthy" {
            let status = ConnectionStatus.Disconnected
            Expect.isFalse status.IsHealthy "Disconnected should not be healthy"
        }

        test "Connecting is healthy" {
            let status = ConnectionStatus.Connecting
            Expect.isTrue status.IsHealthy "Connecting should be healthy"
        }

        test "Connected is healthy" {
            let status = ConnectionStatus.Connected
            Expect.isTrue status.IsHealthy "Connected should be healthy"
        }

        test "Reconnecting is healthy" {
            let status = ConnectionStatus.Reconnecting
            Expect.isTrue status.IsHealthy "Reconnecting should be healthy"
        }

        test "Failed is not healthy" {
            let status = ConnectionStatus.Failed "error"
            Expect.isFalse status.IsHealthy "Failed should not be healthy"
        }

        test "Connected IsInConnectedState is true" {
            let status = ConnectionStatus.Connected
            Expect.isTrue status.IsInConnectedState "Connected should be in connected state"
        }

        test "Disconnected IsInConnectedState is false" {
            let status = ConnectionStatus.Disconnected
            Expect.isFalse status.IsInConnectedState "Disconnected should not be in connected state"
        }

        test "ToString returns expected values" {
            Expect.equal (ConnectionStatus.Disconnected.ToString()) "disconnected" "Disconnected string"
            Expect.equal (ConnectionStatus.Connecting.ToString()) "connecting" "Connecting string"
            Expect.equal (ConnectionStatus.Connected.ToString()) "connected" "Connected string"
            Expect.equal (ConnectionStatus.Reconnecting.ToString()) "reconnecting" "Reconnecting string"
            Expect.stringContains (ConnectionStatus.Failed("test").ToString()) "failed" "Failed string"
        }
    ]

// =============================================================================
// SessionConfig Tests (SC-OP-001, SC-OP-002, SC-OP-004)
// =============================================================================

[<Tests>]
let sessionConfigTests =
    testList "SessionConfig" [
        test "defaultConfig has valid connect timeout (SC-OP-001)" {
            let config = SessionConfig.defaultConfig()
            Expect.isLessThanOrEqual config.ConnectTimeoutMs 5000 "Connect timeout must be <= 5000ms"
        }

        test "defaultConfig has valid max reconnect delay (SC-OP-002)" {
            let config = SessionConfig.defaultConfig()
            Expect.isLessThanOrEqual config.ReconnectMaxDelayMs 60000 "Max reconnect delay must be <= 60000ms"
        }

        test "defaultConfig has positive max reconnect attempts (SC-OP-004)" {
            let config = SessionConfig.defaultConfig()
            Expect.isGreaterThan config.MaxReconnectAttempts 0 "Max reconnect attempts must be > 0"
        }

        test "defaultConfig has localhost endpoint" {
            let config = SessionConfig.defaultConfig()
            Expect.equal config.Endpoints ["tcp/localhost:7447"] "Default endpoint"
        }

        test "defaultConfig has client mode" {
            let config = SessionConfig.defaultConfig()
            Expect.equal config.Mode "client" "Default mode should be client"
        }

        test "forEndpoint creates config with single endpoint" {
            let config = SessionConfig.forEndpoint "tcp/router:7447"
            Expect.equal config.Endpoints ["tcp/router:7447"] "Single endpoint"
        }

        test "forEndpoints creates config with multiple endpoints" {
            let endpoints = ["tcp/r1:7447"; "tcp/r2:7447"; "tcp/r3:7447"]
            let config = SessionConfig.forEndpoints endpoints
            Expect.equal config.Endpoints endpoints "Multiple endpoints"
        }

        test "withName sets session name" {
            let config = SessionConfig.defaultConfig() |> SessionConfig.withName "test-session"
            Expect.equal config.Name "test-session" "Session name"
        }

        test "withShm enables shared memory" {
            let config = SessionConfig.defaultConfig() |> SessionConfig.withShm
            Expect.isTrue config.EnableShm "SHM should be enabled"
        }
    ]

// =============================================================================
// PublisherConfig Tests
// =============================================================================

[<Tests>]
let publisherConfigTests =
    testList "PublisherConfig" [
        test "create has correct defaults" {
            let config = PublisherConfig.create "test/topic"
            Expect.equal config.KeyExpr "test/topic" "Key expression"
            Expect.equal config.CongestionControl "block" "Congestion control"
            Expect.equal config.Priority 5 "Priority"
            Expect.equal config.Reliability "reliable" "Reliability"
            Expect.isFalse config.Express "Express should be false"
        }

        test "highPriority sets priority to 1" {
            let config = PublisherConfig.highPriority "test/topic"
            Expect.equal config.Priority 1 "High priority should be 1"
        }

        test "express enables express mode" {
            let config = PublisherConfig.express "test/topic"
            Expect.isTrue config.Express "Express should be enabled"
        }

        test "bestEffort sets reliability and congestion" {
            let config = PublisherConfig.bestEffort "test/topic"
            Expect.equal config.Reliability "best_effort" "Reliability"
            Expect.equal config.CongestionControl "drop" "Congestion control"
        }
    ]

// =============================================================================
// SubscriberConfig Tests (SC-MSG-003)
// =============================================================================

[<Tests>]
let subscriberConfigTests =
    testList "SubscriberConfig" [
        test "create has correct defaults" {
            let config = SubscriberConfig.create "test/**"
            Expect.equal config.KeyExpr "test/**" "Key expression"
            Expect.equal config.Reliability "reliable" "Reliability"
            Expect.isFalse config.MissDetection "Miss detection should be false"
        }

        test "callback timeout respects SC-MSG-003" {
            let config = SubscriberConfig.create "test"
            Expect.isLessThanOrEqual config.CallbackTimeoutMs 50 "Callback timeout must be <= 50ms"
        }

        test "withMissDetection enables miss detection" {
            let config = SubscriberConfig.create "test" |> SubscriberConfig.withMissDetection
            Expect.isTrue config.MissDetection "Miss detection should be enabled"
            Expect.equal config.RecoveryMode "heartbeat" "Recovery mode"
        }
    ]

// =============================================================================
// ZenohSample Tests
// =============================================================================

[<Tests>]
let zenohSampleTests =
    testList "ZenohSample" [
        test "empty has correct defaults" {
            let sample = ZenohSample.empty
            Expect.equal sample.KeyExpr "" "Empty key expression"
            Expect.equal sample.Payload [||] "Empty payload"
            Expect.equal sample.Kind "put" "Default kind is put"
            Expect.isNone sample.Timestamp "No timestamp"
        }

        test "payloadString decodes UTF-8" {
            let sample = { ZenohSample.empty with Payload = System.Text.Encoding.UTF8.GetBytes("hello") }
            Expect.equal (ZenohSample.payloadString sample) "hello" "Payload string"
        }

        test "isDelete detects delete kind" {
            let putSample = { ZenohSample.empty with Kind = "put" }
            let deleteSample = { ZenohSample.empty with Kind = "delete" }
            Expect.isFalse (ZenohSample.isDelete putSample) "Put is not delete"
            Expect.isTrue (ZenohSample.isDelete deleteSample) "Delete is delete"
        }
    ]

// =============================================================================
// ZenohError Tests
// =============================================================================

[<Tests>]
let zenohErrorTests =
    testList "ZenohError" [
        test "ConnectionFailed message format" {
            let error = ZenohError.ConnectionFailed "timeout"
            Expect.stringContains error.Message "Connection failed" "Error message"
            Expect.stringContains error.Message "timeout" "Error reason"
        }

        test "SessionClosed message" {
            let error = ZenohError.SessionClosed
            Expect.stringContains error.Message "Session is closed" "Error message"
        }

        test "InvalidKeyExpr includes key and reason" {
            let error = ZenohError.InvalidKeyExpr ("bad/key", "invalid character")
            Expect.stringContains error.Message "bad/key" "Key expression"
            Expect.stringContains error.Message "invalid character" "Reason"
        }

        test "Timeout includes operation and duration" {
            let error = ZenohError.Timeout ("publish", 5000)
            Expect.stringContains error.Message "publish" "Operation"
            Expect.stringContains error.Message "5000" "Duration"
        }

        test "QuorumFailed includes required and received" {
            let error = ZenohError.QuorumFailed (3, 1)
            Expect.stringContains error.Message "3" "Required"
            Expect.stringContains error.Message "1" "Received"
        }

        test "BarrierTimeout includes barrier id and time" {
            let error = ZenohError.BarrierTimeout ("barrier-1", 10000)
            Expect.stringContains error.Message "barrier-1" "Barrier ID"
            Expect.stringContains error.Message "10000" "Wait time"
        }
    ]

// =============================================================================
// ZenohHealth Tests (SC-OP-003)
// =============================================================================

[<Tests>]
let zenohHealthTests =
    testList "ZenohHealth" [
        test "empty has disconnected status" {
            let health = ZenohHealth.empty
            Expect.equal health.Status ConnectionStatus.Disconnected "Initial status"
        }

        test "empty has zero counters" {
            let health = ZenohHealth.empty
            Expect.equal health.MessagesPublished 0L "Messages published"
            Expect.equal health.MessagesReceived 0L "Messages received"
            Expect.equal health.ErrorCount 0 "Error count"
            Expect.equal health.ReconnectCount 0 "Reconnect count"
        }

        test "recordPublish increments counter" {
            let health = ZenohHealth.empty |> ZenohHealth.recordPublish
            Expect.equal health.MessagesPublished 1L "Messages published"
        }

        test "recordReceive increments counter" {
            let health = ZenohHealth.empty |> ZenohHealth.recordReceive
            Expect.equal health.MessagesReceived 1L "Messages received"
        }

        test "recordError increments counter" {
            let health = ZenohHealth.empty |> ZenohHealth.recordError
            Expect.equal health.ErrorCount 1 "Error count"
        }

        test "recordHeartbeat sets timestamp" {
            let health = ZenohHealth.empty |> ZenohHealth.recordHeartbeat
            Expect.isSome health.LastHeartbeat "Last heartbeat should be set"
        }

        test "updateUptime calculates duration" {
            let connectedAt = DateTimeOffset.UtcNow.AddMinutes(-5.0)
            let health = { ZenohHealth.empty with ConnectedAt = Some connectedAt }
            let updated = ZenohHealth.updateUptime health
            Expect.isSome updated.Uptime "Uptime should be set"
            match updated.Uptime with
            | Some uptime -> Expect.isGreaterThan uptime.TotalMinutes 4.0 "Uptime should be > 4 minutes"
            | None -> failtest "Expected uptime"
        }
    ]

// =============================================================================
// LifecycleEvent Tests
// =============================================================================

[<Tests>]
let lifecycleEventTests =
    testList "LifecycleEvent" [
        test "Initializing ToString" {
            let event = LifecycleEvent.Initializing (SessionConfig.defaultConfig())
            Expect.equal (event.ToString()) "Initializing" "Event string"
        }

        test "Connected ToString includes session ID" {
            let event = LifecycleEvent.Connected "session-123"
            Expect.stringContains (event.ToString()) "session-123" "Session ID in string"
        }

        test "Reconnecting ToString includes attempt info" {
            let event = LifecycleEvent.Reconnecting (3, 10)
            Expect.stringContains (event.ToString()) "3" "Attempt number"
            Expect.stringContains (event.ToString()) "10" "Max attempts"
        }

        test "Shutdown ToString indicates graceful" {
            let graceful = LifecycleEvent.Shutdown true
            let ungraceful = LifecycleEvent.Shutdown false
            Expect.stringContains (graceful.ToString()) "true" "Graceful"
            Expect.stringContains (ungraceful.ToString()) "false" "Ungraceful"
        }
    ]
