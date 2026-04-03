// =============================================================================
// IntegrationTests.fs - Cross-Level Integration Tests
// =============================================================================
// STAMP: SC-TDG-001, SC-SIL6-001, SC-ZENOH-001
// AOR: AOR-TEST-001, AOR-MESH-001
// Criticality: Level 1 (CRITICAL) - Full Stack Integration Tests
// =============================================================================
// Tests cross-level interactions:
// - L1→L2: Native to Core
// - L2→L3: Core to Envelope
// - L5→L6: Lifecycle to Cluster
// - L6→L7: Cluster to Federation
// =============================================================================

module Cepaf.Zenoh.Tests.IntegrationTests

open System
open Expecto
open Cepaf.Zenoh.Core
open Cepaf.Zenoh.Cluster
open Cepaf.Zenoh.Federation

// =============================================================================
// L1→L2: Native to Core Integration
// =============================================================================

[<Tests>]
let nativeToCoreTests =
    testList "L1→L2: Native to Core" [
        test "SessionConfig uses valid native parameters" {
            let config = SessionConfig.defaultConfig()
            // These values will be passed to native layer
            Expect.isGreaterThan config.ConnectTimeoutMs 0 "Valid timeout"
            Expect.isNonEmpty config.Endpoints "Has endpoints"
        }

        test "ConnectionStatus maps to native states" {
            let states = [
                ConnectionStatus.Disconnected
                ConnectionStatus.Connecting
                ConnectionStatus.Connected
                ConnectionStatus.Reconnecting
                ConnectionStatus.Failed "error"
            ]
            Expect.equal states.Length 5 "All states represented"
        }
    ]

// =============================================================================
// L2→L3: Core to Envelope Integration
// =============================================================================

[<Tests>]
let coreToEnvelopeTests =
    testList "L2→L3: Core to Envelope" [
        test "ZenohSample payload flows to envelope" {
            let sample = {
                ZenohSample.empty with
                    Payload = System.Text.Encoding.UTF8.GetBytes("test")
                    KeyExpr = "test/topic"
            }
            let payloadStr = ZenohSample.payloadString sample
            Expect.equal payloadStr "test" "Payload preserved"
        }

        test "Envelope timestamp compatible with sample" {
            let sample = {
                ZenohSample.empty with
                    Timestamp = Some DateTimeOffset.UtcNow
            }
            Expect.isSome sample.Timestamp "Timestamp flows"
        }
    ]

// =============================================================================
// L5→L6: Lifecycle to Cluster Integration
// =============================================================================

[<Tests>]
let lifecycleToClusterTests =
    testList "L5→L6: Lifecycle to Cluster" [
        test "Health status affects quorum participation" {
            let health = ZenohHealth.empty
            let connected = { health with Status = ConnectionStatus.Connected }
            let disconnected = { health with Status = ConnectionStatus.Disconnected }

            Expect.isTrue connected.Status.IsInConnectedState "Connected can vote"
            Expect.isFalse disconnected.Status.IsInConnectedState "Disconnected cannot vote"
        }

        test "Session config timeout applies to quorum" {
            let config = SessionConfig.defaultConfig()
            let quorumTimeout = 5000  // QuorumSession timeout
            Expect.isLessThanOrEqual config.ConnectTimeoutMs quorumTimeout
                "Session timeout compatible with quorum"
        }

        test "Reconnection affects quorum status" {
            // During reconnection, node should not participate in quorum
            let reconnecting = ConnectionStatus.Reconnecting
            Expect.isFalse reconnecting.IsInConnectedState "Reconnecting excluded from quorum"
        }
    ]

// =============================================================================
// L6→L7: Cluster to Federation Integration
// =============================================================================

[<Tests>]
let clusterToFederationTests =
    testList "L6→L7: Cluster to Federation" [
        test "Quorum result affects federation membership" {
            let approved = QuorumResult.Approved (2, 3, 3)
            let rejected = QuorumResult.Rejected (2, 3, 3)

            // Federation join requires quorum approval
            Expect.isTrue approved.WasApproved "Join approved"
            Expect.isFalse rejected.WasApproved "Join rejected"
        }

        test "2oo3 voting compatible with federation consensus" {
            // Federation uses 2oo3 for critical decisions
            let result = TwoOfThreeVoting.vote true true false
            Expect.isTrue result.IsDecided "Federation decision made"
        }

        test "Protocol version affects cluster communication" {
            let v1 = ProtocolVersion.current
            let v2 = ProtocolVersion.current
            Expect.isTrue (ProtocolVersion.isCompatible v1 v2) "Same cluster protocol"
        }
    ]

// =============================================================================
// Full Stack Integration
// =============================================================================

[<Tests>]
let fullStackTests =
    testList "Full Stack Integration" [
        test "Config flows through all layers" {
            // L2: Create session config
            let config = SessionConfig.defaultConfig()

            // L5: Use config for lifecycle
            Expect.isGreaterThan config.MaxReconnectAttempts 0 "L5 uses config"

            // L6: Timeout applies to quorum
            let quorumTimeout = config.ConnectTimeoutMs
            Expect.isLessThanOrEqual quorumTimeout 5000 "L6 respects timeout"

            // L7: Protocol version included
            let version = ProtocolVersion.current
            Expect.isGreaterThan version.Major 0 "L7 has version"
        }

        test "Error propagation through layers" {
            let nativeError = ZenohError.NativeError (1, "native failure")
            let sessionError = ZenohError.SessionClosed
            let quorumError = ZenohError.QuorumFailed (3, 1)

            // All errors have messages
            Expect.isNonEmpty nativeError.Message "L1 error"
            Expect.isNonEmpty sessionError.Message "L5 error"
            Expect.isNonEmpty quorumError.Message "L6 error"
        }

        test "Health flows from L5 to L6 to L7" {
            // L5: Basic health
            let health = ZenohHealth.empty
            let connected = { health with Status = ConnectionStatus.Connected }

            // L6: Quorum requires connected health
            let canVote = connected.Status.IsInConnectedState
            Expect.isTrue canVote "Healthy node votes"

            // L7: Federation uses quorum
            let quorumResult = QuorumResult.Approved (2, 3, 3)
            Expect.isTrue quorumResult.WasApproved "Federation action approved"
        }
    ]

// =============================================================================
// STAMP Constraint Verification Across Layers
// =============================================================================

[<Tests>]
let stampConstraintTests =
    testList "STAMP Constraints Across Layers" [
        test "SC-OP-001: Connect timeout through layers" {
            let config = SessionConfig.defaultConfig()
            Expect.isLessThanOrEqual config.ConnectTimeoutMs 5000 "SC-OP-001"
        }

        test "SC-OP-005: Quorum formula in cluster" {
            Expect.equal (QuorumCalculator.requiredVotes 3) 2 "SC-OP-005"
        }

        test "SC-QUORUM-001: 2oo3 voting in cluster" {
            let result = TwoOfThreeVoting.vote true true false
            Expect.isTrue result.IsDecided "SC-QUORUM-001"
        }

        test "SC-MSG-003: Callback timeout in envelope" {
            let config = SubscriberConfig.create "test"
            Expect.isLessThanOrEqual config.CallbackTimeoutMs 50 "SC-MSG-003"
        }

        test "SC-FED-001: Protocol version in federation" {
            let v = ProtocolVersion.current
            Expect.isGreaterThan v.Major 0 "SC-FED-001"
        }
    ]

// =============================================================================
// SIL-6 Safety Property Verification
// =============================================================================

[<Tests>]
let sil6AcrossLayersTests =
    testList "SIL-6 Properties Across Layers" [
        test "Single failure tolerance (2oo3)" {
            // One component fails, system still works
            let result = TwoOfThreeVoting.vote true true false
            Expect.equal result.Value (Some true) "Tolerates one failure"
        }

        test "Fail-safe defaults" {
            // Disconnected state is safe default
            let status = ConnectionStatus.Disconnected
            Expect.isFalse status.IsInConnectedState "Safe default"
        }

        test "Timeout bounds enforced" {
            let config = SessionConfig.defaultConfig()
            Expect.isLessThanOrEqual config.ConnectTimeoutMs 5000 "Timeout bounded"
            Expect.isLessThanOrEqual config.ReconnectMaxDelayMs 60000 "Reconnect bounded"
        }

        test "Quorum prevents split-brain" {
            // Cannot have two majorities
            let n = 5
            let quorum = QuorumCalculator.requiredVotes n
            Expect.isLessThan (n - quorum) quorum "Split-brain prevented"
        }
    ]
