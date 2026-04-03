// =============================================================================
// ZenohFederationTests.fs - Unit Tests for Federation Protocol (L7)
// =============================================================================
// STAMP: SC-FED-001 to SC-FED-010, SC-REG-010, SC-REG-012
// AOR: AOR-TEST-001, AOR-MESH-006
// Criticality: Level 7 (CRITICAL) - Federation Protocol Tests
// =============================================================================

module Cepaf.Zenoh.Tests.ZenohFederationTests

open System
open Expecto
open Cepaf.Zenoh.Federation

// =============================================================================
// Protocol Version Tests (SC-FED-001)
// =============================================================================

[<Tests>]
let protocolVersionTests =
    testList "Protocol Version" [
        test "Version comparison: equal" {
            let v1 = { Major = 1; Minor = 2; Patch = 3 }
            let v2 = { Major = 1; Minor = 2; Patch = 3 }
            Expect.equal v1 v2 "Equal versions"
        }

        test "Version comparison: major difference" {
            let v1 = { Major = 1; Minor = 0; Patch = 0 }
            let v2 = { Major = 2; Minor = 0; Patch = 0 }
            Expect.isLessThan v1 v2 "v1 < v2"
        }

        test "Version comparison: minor difference" {
            let v1 = { Major = 1; Minor = 1; Patch = 0 }
            let v2 = { Major = 1; Minor = 2; Patch = 0 }
            Expect.isLessThan v1 v2 "v1 < v2"
        }

        test "Version comparison: patch difference" {
            let v1 = { Major = 1; Minor = 0; Patch = 1 }
            let v2 = { Major = 1; Minor = 0; Patch = 2 }
            Expect.isLessThan v1 v2 "v1 < v2"
        }

        test "isCompatible: same major version" {
            let v1 = { Major = 1; Minor = 0; Patch = 0 }
            let v2 = { Major = 1; Minor = 5; Patch = 10 }
            Expect.isTrue (ProtocolVersion.isCompatible v1 v2) "Same major compatible"
        }

        test "isCompatible: different major version" {
            let v1 = { Major = 1; Minor = 0; Patch = 0 }
            let v2 = { Major = 2; Minor = 0; Patch = 0 }
            Expect.isFalse (ProtocolVersion.isCompatible v1 v2) "Different major incompatible"
        }

        test "format produces correct string" {
            let v = { Major = 1; Minor = 2; Patch = 3 }
            Expect.equal (ProtocolVersion.format v) "1.2.3" "Version string"
        }

        test "current version is valid" {
            let current = ProtocolVersion.current
            Expect.isGreaterThan current.Major 0 "Major > 0"
        }

        test "parse valid version string" {
            match ProtocolVersion.parse "1.2.3" with
            | Some v ->
                Expect.equal v.Major 1 "Major"
                Expect.equal v.Minor 2 "Minor"
                Expect.equal v.Patch 3 "Patch"
            | None -> failtest "Should parse valid version"
        }

        test "parse invalid version returns None" {
            Expect.isNone (ProtocolVersion.parse "invalid") "Invalid returns None"
            Expect.isNone (ProtocolVersion.parse "1.2") "Incomplete returns None"
        }

        test "max returns higher version" {
            let v1 = { Major = 1; Minor = 2; Patch = 3 }
            let v2 = { Major = 1; Minor = 3; Patch = 0 }
            let result = ProtocolVersion.max v1 v2
            Expect.equal result v2 "v2 is higher"
        }
    ]

// =============================================================================
// Holon Identity Tests (SC-FED-003)
// =============================================================================

[<Tests>]
let holonIdentityTests =
    testList "Holon Identity" [
        test "Identity has correct holon ID" {
            let publicKey = Array.zeroCreate<byte> 32
            let identity = HolonIdentity.create "holon-1" "Test Holon" publicKey
            Expect.equal identity.HolonId "holon-1" "Holon ID preserved"
        }

        test "Identity preserves name" {
            let publicKey = Array.zeroCreate<byte> 32
            let identity = HolonIdentity.create "holon-1" "test-holon" publicKey
            Expect.equal identity.Name "test-holon" "Name preserved"
        }

        test "Identity has protocol version" {
            let publicKey = Array.zeroCreate<byte> 32
            let identity = HolonIdentity.create "holon-1" "test" publicKey
            Expect.equal identity.ProtocolVersion ProtocolVersion.current "Has current protocol version"
        }

        test "Identity starts with empty capabilities" {
            let publicKey = Array.zeroCreate<byte> 32
            let identity = HolonIdentity.create "holon-1" "test" publicKey
            Expect.isEmpty identity.Capabilities "Empty capabilities"
        }

        test "withCapabilities adds capabilities" {
            let publicKey = Array.zeroCreate<byte> 32
            let identity =
                HolonIdentity.create "holon-1" "test" publicKey
                |> HolonIdentity.withCapabilities ["storage"; "compute"]
            Expect.equal identity.Capabilities.Length 2 "Has 2 capabilities"
        }

        test "withEndpoints adds endpoints" {
            let publicKey = Array.zeroCreate<byte> 32
            let identity =
                HolonIdentity.create "holon-1" "test" publicKey
                |> HolonIdentity.withEndpoints ["tcp/localhost:7447"; "tcp/localhost:7448"]
            Expect.equal identity.Endpoints.Length 2 "Has 2 endpoints"
        }
    ]

// =============================================================================
// Attestation Tests (SC-FED-004)
// =============================================================================

[<Tests>]
let attestationTests =
    testList "Attestation" [
        test "Attestation links two holons" {
            let stateHash = Array.zeroCreate<byte> 32
            let signature = Array.zeroCreate<byte> 64
            let att = Attestation.create "holon-a" "holon-b" stateHash signature
            Expect.equal att.AttesterId "holon-a" "Attester holon"
            Expect.equal att.AttesteeId "holon-b" "Attestee holon"
        }

        test "Attestation has timestamp" {
            let stateHash = Array.zeroCreate<byte> 32
            let signature = Array.zeroCreate<byte> 64
            let att = Attestation.create "a" "b" stateHash signature
            Expect.isTrue (att.Timestamp <= DateTimeOffset.UtcNow.AddSeconds(1.0))
                "Timestamp current"
        }

        test "Attestation has default validity of 1 hour" {
            let stateHash = Array.zeroCreate<byte> 32
            let signature = Array.zeroCreate<byte> 64
            let att = Attestation.create "a" "b" stateHash signature
            Expect.equal att.ValiditySeconds 3600 "Default 1 hour validity"
        }

        test "Fresh attestation is valid" {
            let stateHash = Array.zeroCreate<byte> 32
            let signature = Array.zeroCreate<byte> 64
            let att = Attestation.create "a" "b" stateHash signature
            Expect.isTrue (Attestation.isValid att) "Fresh is valid"
        }

        test "Expired attestation is invalid" {
            let expired = {
                AttesterId = "a"
                AttesteeId = "b"
                StateHash = Array.zeroCreate<byte> 32
                Timestamp = DateTimeOffset.UtcNow.AddHours(-2.0)
                Signature = Array.zeroCreate<byte> 64
                ValiditySeconds = 3600  // 1 hour - already expired
            }
            Expect.isFalse (Attestation.isValid expired) "Expired is invalid"
        }

        test "isExpired returns true for old attestation" {
            let old = {
                AttesterId = "a"
                AttesteeId = "b"
                StateHash = Array.zeroCreate<byte> 32
                Timestamp = DateTimeOffset.UtcNow.AddHours(-5.0)
                Signature = Array.zeroCreate<byte> 64
                ValiditySeconds = 3600
            }
            Expect.isTrue (Attestation.isExpired old) "Old is expired"
        }
    ]

// =============================================================================
// Federation Member Tests (SC-FED-005)
// =============================================================================

[<Tests>]
let federationMemberTests =
    testList "Federation Member" [
        test "New member has Pending status" {
            let publicKey = Array.zeroCreate<byte> 32
            let identity = HolonIdentity.create "holon-1" "test" publicKey
            let member' = FederationMember.create identity
            Expect.equal member'.Status MembershipStatus.Pending "Starts as Pending"
        }

        test "New member has neutral trust score" {
            let publicKey = Array.zeroCreate<byte> 32
            let identity = HolonIdentity.create "holon-1" "test" publicKey
            let member' = FederationMember.create identity
            Expect.equal member'.TrustScore 0.5 "Neutral trust"
        }

        test "activate changes status to Active" {
            let publicKey = Array.zeroCreate<byte> 32
            let identity = HolonIdentity.create "holon-1" "test" publicKey
            let member' =
                FederationMember.create identity
                |> FederationMember.activate
            Expect.equal member'.Status MembershipStatus.Active "Now Active"
        }

        test "adjustTrust increases score" {
            let publicKey = Array.zeroCreate<byte> 32
            let identity = HolonIdentity.create "holon-1" "test" publicKey
            let member' =
                FederationMember.create identity
                |> FederationMember.adjustTrust 0.2
            Expect.equal member'.TrustScore 0.7 "Trust increased"
        }

        test "adjustTrust decreases score" {
            let publicKey = Array.zeroCreate<byte> 32
            let identity = HolonIdentity.create "holon-1" "test" publicKey
            let member' =
                FederationMember.create identity
                |> FederationMember.adjustTrust -0.3
            Expect.equal member'.TrustScore 0.2 "Trust decreased"
        }

        test "Trust score clamped to 0.0-1.0" {
            let publicKey = Array.zeroCreate<byte> 32
            let identity = HolonIdentity.create "holon-1" "test" publicKey
            let maxedOut =
                FederationMember.create identity
                |> FederationMember.adjustTrust 1.0
            let zeroed =
                FederationMember.create identity
                |> FederationMember.adjustTrust -1.0
            Expect.equal maxedOut.TrustScore 1.0 "Max is 1.0"
            Expect.equal zeroed.TrustScore 0.0 "Min is 0.0"
        }
    ]

// =============================================================================
// Routed Message Tests (SC-FED-007)
// =============================================================================

[<Tests>]
let routingTests =
    testList "Message Routing" [
        test "create sets source holon" {
            let msg = RoutedMessage.create "holon-a" "test payload"
            Expect.equal msg.SourceHolon "holon-a" "Source"
        }

        test "create sets empty target (broadcast)" {
            let msg = RoutedMessage.create "holon-a" "test"
            Expect.isNone msg.TargetHolon "Broadcast has no target"
        }

        test "createTargeted sets target" {
            let msg = RoutedMessage.createTargeted "holon-a" "holon-b" "test"
            Expect.equal msg.TargetHolon (Some "holon-b") "Has target"
        }

        test "incrementHop increases hop count" {
            let msg = RoutedMessage.create "a" "payload"
            match RoutedMessage.incrementHop "b" msg with
            | Some hopped ->
                Expect.equal hopped.HopCount 1 "Hop incremented"
                Expect.contains hopped.Route "b" "Route includes hop"
            | None -> failtest "Should succeed"
        }

        test "incrementHop fails when max hops exceeded" {
            let msg = {
                RoutedMessage.create "a" "payload" with
                    HopCount = 10
                    MaxHops = 10
            }
            Expect.isNone (RoutedMessage.incrementHop "b" msg) "Should fail at max"
        }

        test "hasReachedTarget returns true at destination" {
            let msg = RoutedMessage.createTargeted "a" "b" "payload"
            Expect.isTrue (RoutedMessage.hasReachedTarget "b" msg) "At destination"
        }

        test "hasReachedTarget returns false when not at destination" {
            let msg = RoutedMessage.createTargeted "a" "c" "payload"
            Expect.isFalse (RoutedMessage.hasReachedTarget "b" msg) "Not at destination"
        }

        test "isBroadcast returns true for no target" {
            let msg = RoutedMessage.create "a" "payload"
            Expect.isTrue (RoutedMessage.isBroadcast msg) "Is broadcast"
        }

        test "isBroadcast returns false for targeted" {
            let msg = RoutedMessage.createTargeted "a" "b" "payload"
            Expect.isFalse (RoutedMessage.isBroadcast msg) "Not broadcast"
        }
    ]

// =============================================================================
// Federation Manager Tests (SC-FED-001)
// =============================================================================

[<Tests>]
let federationManagerTests =
    testList "Federation Manager" [
        test "Manager has local identity" {
            use manager = FederationFactory.create "local-holon" "Local"
            Expect.equal manager.LocalIdentity.HolonId "local-holon" "Local identity"
        }

        test "Manager starts with no members" {
            use manager = FederationFactory.create "local" "Local"
            Expect.isEmpty manager.Members "No members initially"
        }

        test "Health returns correct structure" {
            use manager = FederationFactory.create "local" "Local"
            let health = manager.Health
            Expect.containsAll (health |> Map.keys |> Seq.toList)
                ["local_holon"; "total_members"; "active_members"]
                "Has required health keys"
        }
    ]

// =============================================================================
// Version Negotiation Tests (SC-REG-010)
// =============================================================================

[<Tests>]
let versionNegotiationTests =
    testList "Version Negotiation" [
        test "Compatible versions succeed" {
            use manager = FederationFactory.create "local" "Local"
            let negotiation = {
                SourceId = "remote"
                TargetId = "local"
                OfferedVersion = { Major = 1; Minor = 2; Patch = 0 }
                MinVersion = { Major = 1; Minor = 0; Patch = 0 }
                Timestamp = DateTimeOffset.UtcNow
            }
            let result = manager.NegotiateVersion(negotiation)
            Expect.isTrue result.Success "Negotiation succeeds"
            Expect.isSome result.NegotiatedVersion "Has negotiated version"
        }

        test "Incompatible major version fails" {
            use manager = FederationFactory.create "local" "Local"
            let negotiation = {
                SourceId = "remote"
                TargetId = "local"
                OfferedVersion = { Major = 2; Minor = 0; Patch = 0 }  // Different major
                MinVersion = { Major = 2; Minor = 0; Patch = 0 }
                Timestamp = DateTimeOffset.UtcNow
            }
            let result = manager.NegotiateVersion(negotiation)
            Expect.isFalse result.Success "Negotiation fails"
            Expect.isNone result.NegotiatedVersion "No negotiated version"
        }
    ]

// =============================================================================
// Announcement Handling Tests
// =============================================================================

[<Tests>]
let announcementTests =
    testList "Announcement Handling" [
        test "Join announcement adds member" {
            use manager = FederationFactory.create "local" "Local"
            let remotePublicKey = Array.zeroCreate<byte> 32
            let remoteIdentity = HolonIdentity.create "remote" "Remote" remotePublicKey
            let announcement = {
                Identity = remoteIdentity
                Type = AnnouncementType.Join
                Timestamp = DateTimeOffset.UtcNow
                Signature = [||]
            }
            let result = manager.HandleAnnouncement(announcement)
            Expect.isOk result "Join succeeds"
            Expect.equal manager.Members.Length 1 "Has one member"
        }

        test "Heartbeat updates last seen" {
            use manager = FederationFactory.create "local" "Local"
            let remotePublicKey = Array.zeroCreate<byte> 32
            let remoteIdentity = HolonIdentity.create "remote" "Remote" remotePublicKey

            // First join
            let joinAnnouncement = {
                Identity = remoteIdentity
                Type = AnnouncementType.Join
                Timestamp = DateTimeOffset.UtcNow
                Signature = [||]
            }
            manager.HandleAnnouncement(joinAnnouncement) |> ignore

            // Then heartbeat
            let heartbeat = {
                Identity = remoteIdentity
                Type = AnnouncementType.Heartbeat
                Timestamp = DateTimeOffset.UtcNow
                Signature = [||]
            }
            let result = manager.HandleAnnouncement(heartbeat)
            Expect.isOk result "Heartbeat succeeds"
        }
    ]
