// =============================================================================
// FederationProtocol.fs - SIL-4 Federation Protocol Manager
// =============================================================================
// Aligns with:
//   - lib/indrajaal/federation/upgrade_notifier.ex
//   - lib/indrajaal/federation/version_negotiator.ex
//
// STAMP Constraints:
//   SC-REG-010: Protocol version in every block
//   SC-REG-013: Cross-holon attestation for federation
//   SC-RECONFIG-010: Federation notification required
//   SC-SIL4-011: Quorum = floor(N/2) + 1 maintained
//   SC-CTRL-003: 5-order effects analysis required
//
// AOR Rules:
//   AOR-REG-010: Negotiate protocol version before cross-holon comms
//   AOR-REG-012: Attest peer holon integrity every hour
//   AOR-RECONFIG-004: Notify federation peers of major reconfigs
//   AOR-FOUNDER-010: Eternal commitment (federation-level)
//
// 5-Order Effects Analysis:
//   1st Order: Upgrade announcement broadcast
//   2nd Order: Peer acknowledgments received
//   3rd Order: Version negotiation complete
//   4th Order: Protocol handshake established
//   5th Order: Federation-wide rollout confirmed
// =============================================================================

namespace Cepaf.SIL4

open System
open System.Collections.Concurrent
open System.Security.Cryptography
open System.Text

/// Protocol version
type ProtocolVersion = {
    Major: int
    Minor: int
    Patch: int
}

module ProtocolVersion =
    let create major minor patch = { Major = major; Minor = minor; Patch = patch }
    let toString v = sprintf "%d.%d.%d" v.Major v.Minor v.Patch
    let parse (s: string) =
        match s.Split('.') |> Array.map Int32.TryParse with
        | [| (true, major); (true, minor); (true, patch) |] ->
            Some { Major = major; Minor = minor; Patch = patch }
        | _ -> None

    /// Check if versions are compatible (same major version)
    let isCompatible v1 v2 = v1.Major = v2.Major

    /// Compare versions
    let compare v1 v2 =
        if v1.Major <> v2.Major then v1.Major - v2.Major
        elif v1.Minor <> v2.Minor then v1.Minor - v2.Minor
        else v1.Patch - v2.Patch

/// Federation peer status
type PeerStatus =
    | Online
    | Offline
    | Upgrading
    | Degraded
    | Unknown

/// Federation peer
type FederationPeer = {
    PeerId: string
    HolonId: string
    Endpoint: string
    ProtocolVersion: ProtocolVersion
    Status: PeerStatus
    LastSeen: DateTime
    LastAttested: DateTime option
    AttestationHash: string option
}

/// Upgrade announcement
type UpgradeAnnouncement = {
    AnnouncementId: Guid
    SourceHolonId: string
    FromVersion: ProtocolVersion
    ToVersion: ProtocolVersion
    ImageName: string
    ImageSignature: string
    AnnouncedAt: DateTime
    RolloutStart: DateTime
    RolloutEnd: DateTime option
}

/// Peer acknowledgment
type PeerAcknowledgment = {
    AcknowledgmentId: Guid
    AnnouncementId: Guid
    PeerId: string
    Accepted: bool
    Reason: string option
    ReceivedAt: DateTime
}

/// Negotiation result
type NegotiationResult =
    | Agreed of ProtocolVersion
    | Incompatible of local: ProtocolVersion * remote: ProtocolVersion
    | Timeout of peer: string
    | Failed of reason: string

/// 5-Order effect for federation operations
type FederationEffect = {
    Order: int
    OperationId: Guid
    Operation: string
    PeersAffected: int
    Description: string
    Timestamp: DateTime
}

/// Federation protocol result
type FederationResult<'T> =
    | FederationSuccess of 'T
    | FederationFailed of reason: string
    | FederationPartial of result: 'T * failures: string list

/// Compatibility matrix entry
type CompatibilityEntry = {
    Version: ProtocolVersion
    CompatibleWith: ProtocolVersion list
    DeprecatedAt: DateTime option
    EndOfLife: DateTime option
}

/// SIL-4 Federation Protocol Manager
/// Manages cross-holon communication and upgrade coordination
type FederationProtocolManager(localHolonId: string, localVersion: ProtocolVersion) =

    // Peer tracking
    let peers = ConcurrentDictionary<string, FederationPeer>()
    let announcements = ConcurrentDictionary<Guid, UpgradeAnnouncement>()
    let acknowledgments = ConcurrentDictionary<Guid, PeerAcknowledgment list>()
    let effectsLog = ConcurrentDictionary<Guid, FederationEffect list>()

    // Compatibility matrix (SC-REG-010)
    let compatibilityMatrix =
        [|
            { Version = ProtocolVersion.create 21 1 0
              CompatibleWith = [ProtocolVersion.create 21 0 0; ProtocolVersion.create 21 1 0; ProtocolVersion.create 21 2 0]
              DeprecatedAt = None; EndOfLife = None }
            { Version = ProtocolVersion.create 21 0 0
              CompatibleWith = [ProtocolVersion.create 21 0 0; ProtocolVersion.create 21 1 0]
              DeprecatedAt = Some (DateTime(2026, 6, 1)); EndOfLife = Some (DateTime(2026, 12, 1)) }
            { Version = ProtocolVersion.create 20 0 0
              CompatibleWith = [ProtocolVersion.create 20 0 0]
              DeprecatedAt = Some (DateTime(2025, 1, 1)); EndOfLife = Some (DateTime(2025, 6, 1)) }
        |]

    // Attestation interval (SC-REG-012: every hour)
    let attestationIntervalHours = 1.0

    /// Log 5-order effect
    member private this.LogEffect(opId: Guid, order: int, operation: string, peersAffected: int, desc: string) =
        let effect = {
            Order = order
            OperationId = opId
            Operation = operation
            PeersAffected = peersAffected
            Description = desc
            Timestamp = DateTime.UtcNow
        }
        effectsLog.AddOrUpdate(
            opId,
            [effect],
            fun _ existing -> existing @ [effect]) |> ignore

    /// Get local protocol version
    member this.LocalVersion = localVersion

    /// Get local holon ID
    member this.LocalHolonId = localHolonId

    /// Register a federation peer
    member this.RegisterPeer(peerId: string, holonId: string, endpoint: string, version: ProtocolVersion) =
        let peer = {
            PeerId = peerId
            HolonId = holonId
            Endpoint = endpoint
            ProtocolVersion = version
            Status = Unknown
            LastSeen = DateTime.UtcNow
            LastAttested = None
            AttestationHash = None
        }
        peers.AddOrUpdate(peerId, peer, fun _ _ -> peer) |> ignore
        peer

    /// Update peer status
    member this.UpdatePeerStatus(peerId: string, status: PeerStatus) =
        match peers.TryGetValue(peerId) with
        | true, peer ->
            let updated = { peer with Status = status; LastSeen = DateTime.UtcNow }
            peers.[peerId] <- updated
            Some updated
        | false, _ -> None

    /// Negotiate protocol version with peer (SC-REG-010)
    member this.NegotiateVersion(peerId: string, peerVersion: ProtocolVersion) =
        let opId = Guid.NewGuid()

        // 1st Order: Negotiation initiated
        this.LogEffect(opId, 1, "VERSION_NEGOTIATE", 1,
            sprintf "Negotiating with %s: local=%s, remote=%s"
                peerId (ProtocolVersion.toString localVersion) (ProtocolVersion.toString peerVersion))

        // Check compatibility matrix
        let localEntry = compatibilityMatrix |> Array.tryFind (fun e ->
            e.Version.Major = localVersion.Major && e.Version.Minor = localVersion.Minor)

        match localEntry with
        | Some entry ->
            let compatible =
                entry.CompatibleWith
                |> List.exists (fun v -> v.Major = peerVersion.Major && v.Minor = peerVersion.Minor)

            if compatible then
                // 2nd Order: Compatibility confirmed
                this.LogEffect(opId, 2, "COMPATIBLE", 1, "Versions compatible")

                // Select negotiated version (lower of the two)
                let negotiated =
                    if ProtocolVersion.compare localVersion peerVersion <= 0 then
                        localVersion
                    else
                        peerVersion

                // 3rd Order: Version selected
                this.LogEffect(opId, 3, "VERSION_SELECTED", 1,
                    sprintf "Negotiated version: %s" (ProtocolVersion.toString negotiated))

                Agreed negotiated
            else
                // Incompatible
                this.LogEffect(opId, 2, "INCOMPATIBLE", 1,
                    sprintf "No compatible version found")
                Incompatible(localVersion, peerVersion)

        | None ->
            Failed "Local version not in compatibility matrix"

    /// Broadcast upgrade announcement (SC-RECONFIG-010)
    member this.BroadcastUpgrade(
        fromVersion: ProtocolVersion,
        toVersion: ProtocolVersion,
        imageName: string,
        signature: string,
        ?rolloutDelay: TimeSpan) = async {

        let announcementId = Guid.NewGuid()
        let now = DateTime.UtcNow
        let delay = defaultArg rolloutDelay (TimeSpan.FromMinutes(5.0))

        // 1st Order: Announcement created
        this.LogEffect(announcementId, 1, "ANNOUNCE_UPGRADE", peers.Count,
            sprintf "Upgrade from %s to %s" (ProtocolVersion.toString fromVersion) (ProtocolVersion.toString toVersion))

        let announcement = {
            AnnouncementId = announcementId
            SourceHolonId = localHolonId
            FromVersion = fromVersion
            ToVersion = toVersion
            ImageName = imageName
            ImageSignature = signature
            AnnouncedAt = now
            RolloutStart = now.Add(delay)
            RolloutEnd = None
        }

        announcements.TryAdd(announcementId, announcement) |> ignore
        acknowledgments.TryAdd(announcementId, []) |> ignore

        // 2nd Order: Broadcast to peers
        let peerList = peers.Values |> Seq.filter (fun p -> p.Status = Online) |> Seq.toList
        this.LogEffect(announcementId, 2, "BROADCAST", peerList.Length,
            sprintf "Broadcasting to %d online peers" peerList.Length)

        // Simulate broadcast (would use actual network in production)
        for peer in peerList do
            // In production: send via Zenoh/gRPC
            ()

        return FederationSuccess announcement
    }

    /// Receive upgrade announcement acknowledgment
    member this.ReceiveAcknowledgment(ack: PeerAcknowledgment) =
        let opId = ack.AnnouncementId

        match acknowledgments.TryGetValue(opId) with
        | true, acks ->
            acknowledgments.[opId] <- acks @ [ack]

            let announcement = announcements.[opId]
            let totalPeers = peers.Count
            let receivedCount = acknowledgments.[opId].Length
            let acceptedCount = acknowledgments.[opId] |> List.filter (fun a -> a.Accepted) |> List.length

            // Check quorum (SC-SIL4-011: floor(N/2) + 1)
            let quorum = (totalPeers / 2) + 1
            let quorumReached = acceptedCount >= quorum

            // 3rd Order: Acknowledgments tracked
            this.LogEffect(opId, 3, "ACK_RECEIVED", receivedCount,
                sprintf "Ack from %s: accepted=%b, quorum=%d/%d"
                    ack.PeerId ack.Accepted acceptedCount quorum)

            if quorumReached then
                // 4th Order: Quorum reached
                this.LogEffect(opId, 4, "QUORUM_REACHED", acceptedCount,
                    sprintf "Quorum reached: %d/%d accepted" acceptedCount quorum)

            FederationSuccess ack

        | false, _ ->
            FederationFailed "Announcement not found"

    /// Attest peer holon integrity (SC-REG-013)
    member this.AttestPeer(peerId: string, integrityProof: byte[]) =
        let opId = Guid.NewGuid()

        match peers.TryGetValue(peerId) with
        | true, peer ->
            // Calculate attestation hash
            use sha256 = SHA256.Create()
            let hash = sha256.ComputeHash(integrityProof)
            let hashStr = BitConverter.ToString(hash).Replace("-", "").ToLowerInvariant()

            // 4th Order: Attestation recorded
            this.LogEffect(opId, 4, "PEER_ATTESTED", 1,
                sprintf "Peer %s attested with hash: %s..." peerId (hashStr.Substring(0, 16)))

            let updated = {
                peer with
                    LastAttested = Some DateTime.UtcNow
                    AttestationHash = Some hashStr
                    Status = Online
            }
            peers.[peerId] <- updated

            FederationSuccess updated

        | false, _ ->
            FederationFailed "Peer not found"

    /// Check which peers need re-attestation
    member this.GetPeersNeedingAttestation() =
        let threshold = DateTime.UtcNow.AddHours(-attestationIntervalHours)
        peers.Values
        |> Seq.filter (fun p ->
            match p.LastAttested with
            | Some last -> last < threshold
            | None -> true)
        |> Seq.toList

    /// Get all compatible versions for a given version
    member this.CompatibleVersions(version: ProtocolVersion) =
        compatibilityMatrix
        |> Array.tryFind (fun e -> e.Version = version)
        |> Option.map (fun e -> e.CompatibleWith)
        |> Option.defaultValue []

    /// Get upgrade announcement status
    member this.GetAnnouncementStatus(announcementId: Guid) =
        match announcements.TryGetValue(announcementId), acknowledgments.TryGetValue(announcementId) with
        | (true, ann), (true, acks) ->
            let totalPeers = peers.Count
            let quorum = (totalPeers / 2) + 1
            let accepted = acks |> List.filter (fun a -> a.Accepted) |> List.length
            let rejected = acks |> List.filter (fun a -> not a.Accepted) |> List.length

            Some {|
                Announcement = ann
                Acknowledgments = acks.Length
                Accepted = accepted
                Rejected = rejected
                Quorum = quorum
                QuorumReached = accepted >= quorum
                ReadyToRollout = accepted >= quorum && rejected = 0
            |}
        | _ -> None

    /// Get all peers
    member this.GetPeers() =
        peers.Values |> Seq.toList

    /// Get online peers
    member this.GetOnlinePeers() =
        peers.Values |> Seq.filter (fun p -> p.Status = Online) |> Seq.toList

    /// Get peer count by status
    member this.GetPeerStats() =
        let all = peers.Values |> Seq.toList
        {|
            Total = all.Length
            Online = all |> List.filter (fun p -> p.Status = Online) |> List.length
            Offline = all |> List.filter (fun p -> p.Status = Offline) |> List.length
            Upgrading = all |> List.filter (fun p -> p.Status = Upgrading) |> List.length
            Degraded = all |> List.filter (fun p -> p.Status = Degraded) |> List.length
            Unknown = all |> List.filter (fun p -> p.Status = Unknown) |> List.length
            NeedingAttestation = this.GetPeersNeedingAttestation().Length
        |}

    /// Get 5-order effects for operation
    member this.GetEffects(operationId: Guid) =
        match effectsLog.TryGetValue(operationId) with
        | true, effects -> effects
        | false, _ -> []

    /// Confirm federation-wide rollout (5th Order)
    member this.ConfirmRollout(announcementId: Guid) =
        match this.GetAnnouncementStatus(announcementId) with
        | Some status when status.ReadyToRollout ->
            // 5th Order: Federation-wide confirmation
            this.LogEffect(announcementId, 5, "ROLLOUT_CONFIRMED", status.Accepted,
                sprintf "Federation-wide rollout confirmed: %d/%d peers accepted"
                    status.Accepted status.Quorum)

            let updatedAnn = { status.Announcement with RolloutEnd = Some DateTime.UtcNow }
            announcements.[announcementId] <- updatedAnn

            FederationSuccess updatedAnn

        | Some status ->
            FederationFailed (sprintf "Not ready: accepted=%d, quorum=%d" status.Accepted status.Quorum)

        | None ->
            FederationFailed "Announcement not found"

/// Runtime verification for Federation Protocol
module FederationVerification =

    /// Verify protocol version parsing
    let verifyVersionParsing() =
        let testCases = [
            ("21.1.0", Some (ProtocolVersion.create 21 1 0))
            ("20.0.0", Some (ProtocolVersion.create 20 0 0))
            ("invalid", None)
        ]

        let failures =
            testCases
            |> List.filter (fun (input, expected) -> ProtocolVersion.parse input <> expected)

        if failures.IsEmpty then
            FederationSuccess "Version parsing verified"
        else
            FederationFailed (sprintf "Parsing failures: %A" failures)

    /// Verify compatibility matrix
    let verifyCompatibilityMatrix(manager: FederationProtocolManager) =
        let v21_1 = ProtocolVersion.create 21 1 0
        let compatible = manager.CompatibleVersions(v21_1)

        if compatible.Length >= 2 then
            FederationSuccess (sprintf "Compatibility matrix verified: %d compatible versions" compatible.Length)
        else
            FederationFailed "Insufficient compatible versions in matrix"

    /// Verify version negotiation
    let verifyNegotiation(manager: FederationProtocolManager) =
        let peerVersion = ProtocolVersion.create 21 0 0
        match manager.NegotiateVersion("test_peer", peerVersion) with
        | Agreed v ->
            FederationSuccess (sprintf "Negotiation verified: agreed on %s" (ProtocolVersion.toString v))
        | Incompatible (local, remote) ->
            FederationFailed (sprintf "Unexpected incompatibility: %s vs %s"
                (ProtocolVersion.toString local) (ProtocolVersion.toString remote))
        | Timeout peer ->
            FederationFailed (sprintf "Timeout with %s" peer)
        | Failed reason ->
            FederationFailed reason

    /// Run all verifications
    let runAllVerifications() =
        let manager = FederationProtocolManager("test_holon", ProtocolVersion.create 21 1 0)

        let results = [
            ("Version parsing", verifyVersionParsing())
            ("Compatibility matrix", verifyCompatibilityMatrix(manager))
            ("Negotiation", verifyNegotiation(manager))
        ]

        let failures = results |> List.filter (fun (_, r) ->
            match r with
            | FederationFailed _ -> true
            | _ -> false)

        if failures.IsEmpty then
            FederationSuccess (sprintf "All %d Federation verifications passed" results.Length)
        else
            FederationFailed (sprintf "Federation verification failures: %A" (failures |> List.map fst))
