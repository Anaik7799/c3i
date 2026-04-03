// =============================================================================
// Git Intelligence — L7 Cross-Holon Federation Sync
// =============================================================================
// Purpose:  Enable cross-holon GHS exchange, peer discovery, protocol
//           negotiation, and Ed25519-based attestation for federated git
//           intelligence. Standalone — no ProjectReference to Cepaf.
//
// STAMP:    SC-FED-001/006 (federation governance), AOR-FED-001 (attestation)
// =============================================================================

module Cepaf.GitIntelligence.Federation

open System
open System.Security.Cryptography
open System.Text

// ─────────────────────────────────────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────────────────────────────────────

/// Protocol version for federation negotiation.
let protocolVersion = "1.0.0"

/// Represents a discovered peer holon.
type FederationPeer =
    { PeerId: string
      Endpoint: string
      ProtocolVersion: string
      LastGhs: float option
      LastSeen: DateTimeOffset
      Attested: bool }

/// Result of a health sync exchange.
type HealthSyncResult =
    { PeerId: string
      PeerGhs: float option
      LocalGhs: float
      AggregateGhs: float
      Timestamp: DateTimeOffset }

/// Result of protocol negotiation.
type NegotiationResult =
    | Compatible of version: string
    | Incompatible of localVersion: string * peerVersion: string * reason: string

/// Attestation result.
type AttestationResult =
    | Verified of peerId: string * timestamp: DateTimeOffset
    | Failed of peerId: string * reason: string

// ─────────────────────────────────────────────────────────────────────────────
// Peer Registry (in-memory for CLI session lifetime)
// ─────────────────────────────────────────────────────────────────────────────

/// In-memory peer registry. Peers discovered during session.
let private peers = System.Collections.Concurrent.ConcurrentDictionary<string, FederationPeer>()

/// Register or update a peer.
let registerPeer (peer: FederationPeer) : unit =
    peers.AddOrUpdate(peer.PeerId, peer, fun _ _ -> peer) |> ignore

/// Get all known peers.
let getPeers () : FederationPeer list =
    peers.Values |> Seq.toList

/// Get a specific peer by ID.
let getPeer (peerId: string) : FederationPeer option =
    match peers.TryGetValue(peerId) with
    | true, peer -> Some peer
    | false, _ -> None

/// Remove stale peers (not seen within TTL).
let pruneStale (ttlMinutes: float) : int =
    let cutoff = DateTimeOffset.UtcNow.AddMinutes(-ttlMinutes)
    let stale =
        peers.Values
        |> Seq.filter (fun p -> p.LastSeen < cutoff)
        |> Seq.map (fun p -> p.PeerId)
        |> Seq.toList
    stale |> List.iter (fun id -> peers.TryRemove(id) |> ignore)
    stale.Length

// ─────────────────────────────────────────────────────────────────────────────
// Peer Discovery (via Zenoh topic)
// ─────────────────────────────────────────────────────────────────────────────

/// Discover peers by publishing a discovery beacon.
/// In standalone mode, this publishes to Zenoh and relies on subscribers
/// to respond. Returns the local peer record for self-registration.
let discoverSelf (localGhs: float option) : FederationPeer =
    let selfId = Environment.MachineName + "-git-intel"
    let self =
        { PeerId = selfId
          Endpoint = "local"
          ProtocolVersion = protocolVersion
          LastGhs = localGhs
          LastSeen = DateTimeOffset.UtcNow
          Attested = true }
    registerPeer self
    // Publish discovery beacon via Notify
    Notify.publishFederationEvent selfId localGhs protocolVersion true |> ignore
    self

/// Simulate receiving a peer discovery response (for testing/offline mode).
let registerRemotePeer (peerId: string) (endpoint: string) (peerGhs: float option) (peerVersion: string) : FederationPeer =
    let peer =
        { PeerId = peerId
          Endpoint = endpoint
          ProtocolVersion = peerVersion
          LastGhs = peerGhs
          LastSeen = DateTimeOffset.UtcNow
          Attested = false }
    registerPeer peer
    peer

// ─────────────────────────────────────────────────────────────────────────────
// Health Sync
// ─────────────────────────────────────────────────────────────────────────────

/// Exchange GHS with a specific peer and compute aggregate health.
let syncHealth (localGhs: float) (peerId: string) : HealthSyncResult option =
    match getPeer peerId with
    | None -> None
    | Some peer ->
        let peerGhs = peer.LastGhs
        // Aggregate: weighted average (local 60%, peer 40%) when peer has GHS
        let aggregate =
            match peerGhs with
            | Some pg -> localGhs * 0.6 + pg * 0.4
            | None -> localGhs
        let result =
            { PeerId = peerId
              PeerGhs = peerGhs
              LocalGhs = localGhs
              AggregateGhs = aggregate
              Timestamp = DateTimeOffset.UtcNow }
        // Publish sync event
        Notify.publishFederationEvent peerId peerGhs protocolVersion peer.Attested |> ignore
        Some result

/// Compute aggregate health across all attested peers.
let computeFederatedHealth (localGhs: float) : float =
    let attestedPeers =
        getPeers ()
        |> List.filter (fun p -> p.Attested && p.LastGhs.IsSome)
    if attestedPeers.IsEmpty then
        localGhs
    else
        let peerGhsSum =
            attestedPeers
            |> List.sumBy (fun p -> p.LastGhs.Value)
        let totalWeight = 1.0 + float attestedPeers.Length
        (localGhs + peerGhsSum) / totalWeight

// ─────────────────────────────────────────────────────────────────────────────
// Protocol Negotiation (SC-FED-001)
// ─────────────────────────────────────────────────────────────────────────────

/// Parse a semver string into (major, minor, patch).
let private parseSemver (version: string) : (int * int * int) option =
    let parts = version.Split('.')
    if parts.Length >= 3 then
        match Int32.TryParse parts.[0], Int32.TryParse parts.[1], Int32.TryParse parts.[2] with
        | (true, major), (true, minor), (true, patch) -> Some (major, minor, patch)
        | _ -> None
    else
        None

/// Negotiate protocol version with a peer.
/// Compatible if major versions match (semver compatibility).
let negotiateProtocol (peerVersion: string) : NegotiationResult =
    match parseSemver protocolVersion, parseSemver peerVersion with
    | Some (localMajor, _, _), Some (peerMajor, _, _) ->
        if localMajor = peerMajor then
            // Use the lower version for compatibility
            let negotiated = if peerVersion < protocolVersion then peerVersion else protocolVersion
            Compatible negotiated
        else
            Incompatible (protocolVersion, peerVersion, "Major version mismatch")
    | None, _ ->
        Incompatible (protocolVersion, peerVersion, "Cannot parse local version")
    | _, None ->
        Incompatible (protocolVersion, peerVersion, "Cannot parse peer version")

// ─────────────────────────────────────────────────────────────────────────────
// Attestation (SC-FED-006, AOR-FED-001)
// ─────────────────────────────────────────────────────────────────────────────

/// Compute HMAC-SHA256 of a peer's identity payload.
/// In a full implementation this would use Ed25519 signatures;
/// standalone mode uses HMAC-SHA256 with a shared secret.
let private computeHmac (secret: byte[]) (payload: string) : byte[] =
    use hmac = new HMACSHA256(secret)
    hmac.ComputeHash(Encoding.UTF8.GetBytes(payload))

/// Attest a peer by verifying its identity payload against an expected MAC.
let attestPeer (peerId: string) (payload: string) (expectedMac: byte[]) (sharedSecret: byte[]) : AttestationResult =
    let computed = computeHmac sharedSecret payload
    // Constant-time comparison per SC-HASH-002
    let mutable equal = computed.Length = expectedMac.Length
    if equal then
        for i in 0 .. computed.Length - 1 do
            if computed.[i] <> expectedMac.[i] then
                equal <- false
    if equal then
        // Update peer as attested
        match getPeer peerId with
        | Some peer ->
            registerPeer { peer with Attested = true; LastSeen = DateTimeOffset.UtcNow }
        | None -> ()
        Verified (peerId, DateTimeOffset.UtcNow)
    else
        Failed (peerId, "MAC verification failed")

/// Generate a MAC for self-attestation.
let generateSelfMac (peerId: string) (sharedSecret: byte[]) : byte[] =
    let payload = $"{peerId}:{protocolVersion}:{DateTimeOffset.UtcNow:O}"
    computeHmac sharedSecret payload

// ─────────────────────────────────────────────────────────────────────────────
// Reporting
// ─────────────────────────────────────────────────────────────────────────────

/// Format a federation status report.
let formatReport () : string =
    let sb = System.Text.StringBuilder()
    sb.AppendLine("Federation Status") |> ignore
    sb.AppendLine($"  Protocol: v{protocolVersion}") |> ignore
    let allPeers = getPeers ()
    sb.AppendLine($"  Peers: {allPeers.Length}") |> ignore
    let attested = allPeers |> List.filter (fun p -> p.Attested) |> List.length
    sb.AppendLine($"  Attested: {attested}/{allPeers.Length}") |> ignore
    for peer in allPeers do
        let ghsStr = match peer.LastGhs with Some g -> $"{g:F4}" | None -> "N/A"
        let attestStr = if peer.Attested then "YES" else "NO"
        sb.AppendLine($"  [{peer.PeerId}] GHS={ghsStr} Attested={attestStr} v{peer.ProtocolVersion}") |> ignore
    sb.ToString()

/// Output federation status as JSON.
let toJson () : string =
    let allPeers = getPeers ()
    let peersJson =
        allPeers
        |> List.map (fun p ->
            let ghsStr = match p.LastGhs with Some g -> $"{g:F4}" | None -> "null"
            $"""{{ "peerId": "{p.PeerId}", "endpoint": "{p.Endpoint}", "ghs": {ghsStr}, "attested": {(if p.Attested then "true" else "false")}, "protocol": "{p.ProtocolVersion}", "lastSeen": "{p.LastSeen:O}" }}""")
        |> String.concat ", "
    $"""{{ "protocol": "{protocolVersion}", "peerCount": {allPeers.Length}, "peers": [{peersJson}] }}"""

/// Clear all peers (for testing).
let clearPeers () : unit =
    peers.Clear()
