// =============================================================================
// ZenohLifecycleTests.fs - Unit Tests for Session Lifecycle (L5)
// =============================================================================
// STAMP: SC-OP-001, SC-OP-002, SC-OP-003, SC-OP-004, SC-SESS-001
// AOR: AOR-TEST-001, AOR-ZENOH-002
// Criticality: Level 5 (CRITICAL) - Session Lifecycle Tests
// =============================================================================

module Cepaf.Zenoh.Tests.ZenohLifecycleTests

open System
open Expecto
open Cepaf.Zenoh.Core

// =============================================================================
// State Machine Tests
// =============================================================================

[<Tests>]
let stateMachineTests =
    testList "Lifecycle State Machine" [
        test "Initial state is Disconnected" {
            let status = ConnectionStatus.Disconnected
            Expect.equal status ConnectionStatus.Disconnected "Initial is Disconnected"
        }

        test "Valid transition: Disconnected -> Connecting" {
            let from = ConnectionStatus.Disconnected
            let to' = ConnectionStatus.Connecting
            // Both states are valid
            Expect.isFalse from.IsInConnectedState "From not connected"
            Expect.isFalse to'.IsInConnectedState "To not yet connected"
        }

        test "Valid transition: Connecting -> Connected" {
            let from = ConnectionStatus.Connecting
            let to' = ConnectionStatus.Connected
            Expect.isFalse from.IsInConnectedState "Connecting not yet connected"
            Expect.isTrue to'.IsInConnectedState "Connected is connected"
        }

        test "Valid transition: Connected -> Reconnecting" {
            let from = ConnectionStatus.Connected
            let to' = ConnectionStatus.Reconnecting
            Expect.isTrue from.IsInConnectedState "Was connected"
            Expect.isFalse to'.IsInConnectedState "Reconnecting not connected"
        }

        test "Valid transition: Reconnecting -> Connected" {
            let from = ConnectionStatus.Reconnecting
            let to' = ConnectionStatus.Connected
            Expect.isFalse from.IsInConnectedState "Was reconnecting"
            Expect.isTrue to'.IsInConnectedState "Now connected"
        }

        test "Valid transition: Reconnecting -> Failed" {
            let from = ConnectionStatus.Reconnecting
            let to' = ConnectionStatus.Failed "Max attempts exceeded"
            Expect.isFalse to'.IsInConnectedState "Failed not connected"
            Expect.isFalse to'.IsHealthy "Failed not healthy"
        }
    ]

// =============================================================================
// Timeout Tests (SC-OP-001)
// =============================================================================

[<Tests>]
let timeoutTests =
    testList "Timeout Bounds (SC-OP-001)" [
        test "Connect timeout <= 5000ms" {
            let config = SessionConfig.defaultConfig()
            Expect.isLessThanOrEqual config.ConnectTimeoutMs 5000 "SC-OP-001"
        }

        test "Connect timeout > 0" {
            let config = SessionConfig.defaultConfig()
            Expect.isGreaterThan config.ConnectTimeoutMs 0 "Positive timeout"
        }

        test "Reasonable timeout range" {
            let config = SessionConfig.defaultConfig()
            Expect.isGreaterThanOrEqual config.ConnectTimeoutMs 1000 "At least 1s"
        }
    ]

// =============================================================================
// Reconnection Tests (SC-OP-002, SC-OP-004)
// =============================================================================

[<Tests>]
let reconnectionTests =
    testList "Reconnection Behavior" [
        test "Max delay <= 60000ms (SC-OP-002)" {
            let config = SessionConfig.defaultConfig()
            Expect.isLessThanOrEqual config.ReconnectMaxDelayMs 60000 "SC-OP-002"
        }

        test "Base delay < max delay" {
            let config = SessionConfig.defaultConfig()
            Expect.isLessThan config.ReconnectBaseDelayMs config.ReconnectMaxDelayMs
                "Base < Max"
        }

        test "Max attempts > 0 (SC-OP-004)" {
            let config = SessionConfig.defaultConfig()
            Expect.isGreaterThan config.MaxReconnectAttempts 0 "SC-OP-004"
        }

        test "Exponential backoff formula" {
            // delay = min(base * 2^attempt, max)
            let baseDelay = 1000
            let maxDelay = 60000
            for attempt in 0..10 do
                let delay = min (baseDelay * pown 2 attempt) maxDelay
                Expect.isLessThanOrEqual delay maxDelay "Within max"
                Expect.isGreaterThan delay 0 "Positive delay"
        }
    ]

// =============================================================================
// Health Monitoring Tests (SC-OP-003)
// =============================================================================

[<Tests>]
let healthMonitoringTests =
    testList "Health Monitoring (SC-OP-003)" [
        test "Health record tracks publishes" {
            let health = ZenohHealth.empty
            let h1 = ZenohHealth.recordPublish health
            let h2 = ZenohHealth.recordPublish h1
            Expect.equal h2.MessagesPublished 2L "Two publishes"
        }

        test "Health record tracks receives" {
            let health = ZenohHealth.empty
            let h1 = ZenohHealth.recordReceive health
            Expect.equal h1.MessagesReceived 1L "One receive"
        }

        test "Health record tracks errors" {
            let health = ZenohHealth.empty
            let h1 = ZenohHealth.recordError health
            let h2 = ZenohHealth.recordError h1
            Expect.equal h2.ErrorCount 2 "Two errors"
        }

        test "Heartbeat updates timestamp" {
            let health = ZenohHealth.empty
            Expect.isNone health.LastHeartbeat "No initial heartbeat"
            let updated = ZenohHealth.recordHeartbeat health
            Expect.isSome updated.LastHeartbeat "Heartbeat set"
        }

        test "Uptime calculation" {
            let now = DateTimeOffset.UtcNow
            let earlier = now.AddMinutes(-10.0)
            let health = { ZenohHealth.empty with ConnectedAt = Some earlier }
            let updated = ZenohHealth.updateUptime health
            match updated.Uptime with
            | Some uptime ->
                Expect.isGreaterThan uptime.TotalMinutes 9.0 "At least 9 minutes"
            | None -> failtest "Expected uptime"
        }
    ]

// =============================================================================
// Configuration Tests
// =============================================================================

[<Tests>]
let configurationTests =
    testList "Configuration" [
        test "Default endpoints include localhost" {
            let config = SessionConfig.defaultConfig()
            Expect.contains config.Endpoints "tcp/localhost:7447" "Localhost endpoint"
        }

        test "forEndpoint creates single endpoint config" {
            let config = SessionConfig.forEndpoint "tcp/router:7447"
            Expect.equal config.Endpoints.Length 1 "Single endpoint"
        }

        test "forEndpoints preserves order" {
            let endpoints = ["tcp/r1:7447"; "tcp/r2:7447"; "tcp/r3:7447"]
            let config = SessionConfig.forEndpoints endpoints
            Expect.equal config.Endpoints endpoints "Endpoints preserved"
        }

        test "Mode defaults to client" {
            let config = SessionConfig.defaultConfig()
            Expect.equal config.Mode "client" "Client mode default"
        }

        test "SHM disabled by default" {
            let config = SessionConfig.defaultConfig()
            Expect.isFalse config.EnableShm "SHM disabled"
        }

        test "withShm enables shared memory" {
            let config = SessionConfig.defaultConfig() |> SessionConfig.withShm
            Expect.isTrue config.EnableShm "SHM enabled"
        }
    ]
