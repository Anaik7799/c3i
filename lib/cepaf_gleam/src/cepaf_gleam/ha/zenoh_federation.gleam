//// =============================================================================
//// [C3I-SIL6-MSTS] MATHEMATICAL & SEMANTIC MODULE CONTRACT
//// =============================================================================
//// <c3i-module>
////   <identity>
////     <module>cepaf_gleam/ha/zenoh_federation</module>
////     <fsharp-lineage>None — novel multi-region federation layer (F26)</fsharp-lineage>
////   </identity>
////   <fractal-topology>
////     <layer>L7_FEDERATION</layer>
////     <mesh-domain>
////       Multi-region Zenoh mesh federation for the SIL-6 Biomorphic system.
////       Defines region topology, health tracking, mode determination, quorum
////       evaluation, and Zenoh topic namespace generation for cross-region
////       communication.  Pure types and functions — no I/O, no side-effects.
////     </mesh-domain>
////   </fractal-topology>
////   <compliance>
////     <criticality>HIGH</criticality>
////     <stamp-controls>
////       SC-FED-001, SC-FED-006, SC-HA-001, SC-SIL4-011,
////       SC-ZENOH-001, SC-ZMOF-001, SC-MUDA-001, SC-FUNC-001
////     </stamp-controls>
////   </compliance>
////   <transformations>
////     <morphism type="injective">
////       Rust ha_election.rs Primary/Backup/Standby states ↪ Gleam FederationMode ADT.
////       HA election maps to multi-region quorum; region set extends node set.
////     </morphism>
////     <morphism type="surjective" loss="network-topology">
////       Zenoh router endpoint reachability ↠ Bool healthy flag.
////       Mitigation: Latency and consistency fields carry additional signal beyond
////       the binary reachable flag.
////     </morphism>
////   </transformations>
//// </c3i-module>
//// =============================================================================
////
//// ZENOH MULTI-REGION FEDERATION — F26
//// विश्वव्यापी — World-pervading (Sanskrit)
////
//// Default 3-region topology (GDPR-aware):
////   europe-north1   Stockholm  — primary,  GDPR-compliant EU data residence
////   us-east1        Virginia   — backup,   AWS us-east-1 redundancy
////   asia-southeast1 Singapore  — expansion, APAC coverage
////
//// Quorum rule  : majority of regions must be healthy  (floor(N/2) + 1)
//// Mode ladder  : FullFederation → PartialFederation → IslandMode → Recovering
//// Zenoh topics : indrajaal/{region}/health/**
////                indrajaal/{region}/guard/**
////                indrajaal/{region}/ooda/**
////
//// STAMP: SC-FED-001, SC-FED-006, SC-HA-001, SC-SIL4-011, SC-ZENOH-001,
////        SC-ZMOF-001, SC-MUDA-001, SC-FUNC-001

import gleam/int
import gleam/list
import gleam/string

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/// A single region in the multi-region federation mesh.
pub type Region {
  Region(
    /// Canonical region ID matching GCP/AWS/Azure region codes.
    /// e.g. "europe-north1", "us-east1", "asia-southeast1"
    id: String,
    /// Human-readable location, e.g. "Stockholm", "Virginia"
    name: String,
    /// Zenoh TCP endpoint for this region's router.
    /// e.g. "tcp/zenoh-eu.example.com:7447"
    zenoh_endpoint: String,
    /// Whether the region is currently passing health checks.
    healthy: Bool,
    /// Number of Zenoh nodes in this region's mesh.
    node_count: Int,
    /// ZID or hostname of the current leader node in this region.
    leader_node: String,
    /// Unix epoch milliseconds of the last received heartbeat.
    last_heartbeat: Int,
  )
}

/// Aggregate federation state — the full multi-region picture.
pub type FederationState {
  FederationState(
    /// All registered regions, including unhealthy ones.
    regions: List(Region),
    /// ID of the region this node is running in.
    local_region: String,
    /// Sum of node_count across all regions.
    total_nodes: Int,
    /// Number of regions that are currently healthy.
    healthy_regions: Int,
    /// Current operating mode of the federation.
    federation_mode: FederationMode,
    /// Name of the consensus protocol in use, e.g. "raft", "2oo3-quorum".
    consensus_protocol: String,
  )
}

/// Operating mode of the federation — degrades gracefully on partition.
pub type FederationMode {
  /// All regions connected, full cross-region replication active.
  FullFederation
  /// Some regions unreachable; local quorum still met, degraded globally.
  PartialFederation
  /// No connectivity to other regions; local-only operation.
  IslandMode
  /// Re-establishing connections after a partition has healed.
  Recovering
}

/// Result of a cross-region health probe for a single region.
pub type RegionHealth {
  RegionHealth(
    /// The region being probed.
    region_id: String,
    /// Round-trip latency in milliseconds for the last probe.
    latency_ms: Int,
    /// Whether the region's Zenoh router is reachable.
    reachable: Bool,
    /// Whether the region's state is consistent with the local view.
    data_consistent: Bool,
    /// Whether the region is running the same software version.
    version_match: Bool,
  )
}

// ---------------------------------------------------------------------------
// Construction
// ---------------------------------------------------------------------------

/// Build the default 3-region federation state for a given local region.
///
/// [C3I-SIL6] ATOMIC CONTRACT
/// <c3i-atomic>
///   <morphism type="injective">F26 bootstrap ↪ pure FederationState value</morphism>
///   <formal-proof>
///     <P> local_region is a non-empty String </P>
///     <C> init(local_region) </C>
///     <Q> Returns FederationState with 3 canonical regions; healthy=False until
///         probed; total_nodes is the sum of initial node_count values. </Q>
///   </formal-proof>
/// </c3i-atomic>
pub fn init(local_region: String) -> FederationState {
  let eu =
    Region(
      id: "europe-north1",
      name: "Stockholm",
      zenoh_endpoint: "tcp/zenoh-eu.example.com:7447",
      healthy: False,
      node_count: 3,
      leader_node: "eu-node-1",
      last_heartbeat: 0,
    )
  let us =
    Region(
      id: "us-east1",
      name: "Virginia",
      zenoh_endpoint: "tcp/zenoh-us.example.com:7447",
      healthy: False,
      node_count: 3,
      leader_node: "us-node-1",
      last_heartbeat: 0,
    )
  let apac =
    Region(
      id: "asia-southeast1",
      name: "Singapore",
      zenoh_endpoint: "tcp/zenoh-ap.example.com:7447",
      healthy: False,
      node_count: 2,
      leader_node: "ap-node-1",
      last_heartbeat: 0,
    )
  let regions = [eu, us, apac]
  let total = list.fold(regions, 0, fn(acc, r) { acc + r.node_count })
  FederationState(
    regions: regions,
    local_region: local_region,
    total_nodes: total,
    healthy_regions: 0,
    federation_mode: IslandMode,
    consensus_protocol: "2oo3-quorum",
  )
}

// ---------------------------------------------------------------------------
// Region management
// ---------------------------------------------------------------------------

/// Add a new region to the federation, recomputing totals.
pub fn add_region(
  state: FederationState,
  region: Region,
) -> FederationState {
  let regions = list.append(state.regions, [region])
  let total = list.fold(regions, 0, fn(acc, r) { acc + r.node_count })
  let healthy =
    list.filter(regions, fn(r) { r.healthy }) |> list.length()
  let mode = determine_mode_for(regions, healthy)
  FederationState(
    ..state,
    regions: regions,
    total_nodes: total,
    healthy_regions: healthy,
    federation_mode: mode,
  )
}

/// Remove a region by ID, recomputing totals.
pub fn remove_region(
  state: FederationState,
  region_id: String,
) -> FederationState {
  let regions = list.filter(state.regions, fn(r) { r.id != region_id })
  let total = list.fold(regions, 0, fn(acc, r) { acc + r.node_count })
  let healthy =
    list.filter(regions, fn(r) { r.healthy }) |> list.length()
  let mode = determine_mode_for(regions, healthy)
  FederationState(
    ..state,
    regions: regions,
    total_nodes: total,
    healthy_regions: healthy,
    federation_mode: mode,
  )
}

/// Update health status for a specific region, recomputing mode.
pub fn update_health(
  state: FederationState,
  region_id: String,
  healthy: Bool,
) -> FederationState {
  let regions =
    list.map(state.regions, fn(r) {
      case r.id == region_id {
        True -> Region(..r, healthy: healthy)
        False -> r
      }
    })
  let healthy_count =
    list.filter(regions, fn(r) { r.healthy }) |> list.length()
  let mode = determine_mode_for(regions, healthy_count)
  FederationState(
    ..state,
    regions: regions,
    healthy_regions: healthy_count,
    federation_mode: mode,
  )
}

// ---------------------------------------------------------------------------
// Mode determination
// ---------------------------------------------------------------------------

/// Compute the FederationMode from the current state.
/// Delegates to the internal helper which accepts raw region list + count.
pub fn determine_mode(state: FederationState) -> FederationMode {
  determine_mode_for(state.regions, state.healthy_regions)
}

// ---------------------------------------------------------------------------
// Quorum & leader
// ---------------------------------------------------------------------------

/// Returns True when a strict majority of regions are healthy.
/// Quorum rule: healthy_regions >= floor(total / 2) + 1.
///
/// Mirrors SC-SIL4-011: quorum floor(N/2)+1 maintained throughout upgrades.
pub fn is_quorum_met(state: FederationState) -> Bool {
  let total = list.length(state.regions)
  case total {
    0 -> False
    _ -> state.healthy_regions >= total / 2 + 1
  }
}

/// Returns True when the local region is the federation leader.
/// Leadership rule: local region is healthy AND is the lexicographically
/// first healthy region (deterministic tie-breaking, no network round-trip).
pub fn local_is_leader(state: FederationState) -> Bool {
  let healthy_ids =
    state.regions
    |> list.filter(fn(r) { r.healthy })
    |> list.map(fn(r) { r.id })
    |> list.sort(string.compare)
  case healthy_ids {
    [first, ..] -> first == state.local_region
    [] -> False
  }
}

// ---------------------------------------------------------------------------
// Zenoh topics
// ---------------------------------------------------------------------------

/// Return the canonical Zenoh key expressions for a region.
/// Pattern: indrajaal/{region_id}/{domain}/**
///
/// Aligned with SC-ZMOF-001 fractal namespace and SC-ZENOH-006.
pub fn zenoh_topics_for_region(region_id: String) -> List(String) {
  [
    "indrajaal/" <> region_id <> "/health/**",
    "indrajaal/" <> region_id <> "/guard/**",
    "indrajaal/" <> region_id <> "/ooda/**",
  ]
}

// ---------------------------------------------------------------------------
// Serialisation
// ---------------------------------------------------------------------------

/// Serialise the full FederationState to a compact JSON string.
pub fn to_json(state: FederationState) -> String {
  let regions_json =
    state.regions
    |> list.map(region_to_json)
    |> string.join(",")
  "{"
  <> "\"local_region\":\""
  <> state.local_region
  <> "\","
  <> "\"total_nodes\":"
  <> int.to_string(state.total_nodes)
  <> ","
  <> "\"healthy_regions\":"
  <> int.to_string(state.healthy_regions)
  <> ","
  <> "\"federation_mode\":\""
  <> mode_to_string(state.federation_mode)
  <> "\","
  <> "\"consensus_protocol\":\""
  <> state.consensus_protocol
  <> "\","
  <> "\"regions\":["
  <> regions_json
  <> "]"
  <> "}"
}

/// Human-readable one-liner summary for logs and TUI display.
pub fn summary(state: FederationState) -> String {
  "Federation["
  <> mode_to_string(state.federation_mode)
  <> "] local="
  <> state.local_region
  <> " healthy="
  <> int.to_string(state.healthy_regions)
  <> "/"
  <> int.to_string(list.length(state.regions))
  <> " nodes="
  <> int.to_string(state.total_nodes)
  <> " quorum="
  <> case is_quorum_met(state) {
    True -> "yes"
    False -> "no"
  }
  <> " leader="
  <> case local_is_leader(state) {
    True -> "yes"
    False -> "no"
  }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

/// Core mode-determination logic, operating on raw region list + healthy count
/// rather than FederationState to avoid circular references in add/remove.
fn determine_mode_for(
  regions: List(Region),
  healthy_count: Int,
) -> FederationMode {
  let total = list.length(regions)
  case total, healthy_count {
    0, _ -> IslandMode
    t, h if h == t -> FullFederation
    _, 0 -> IslandMode
    t, h if h >= t / 2 + 1 -> PartialFederation
    _, _ -> Recovering
  }
}

fn region_to_json(r: Region) -> String {
  "{"
  <> "\"id\":\""
  <> r.id
  <> "\","
  <> "\"name\":\""
  <> r.name
  <> "\","
  <> "\"zenoh_endpoint\":\""
  <> r.zenoh_endpoint
  <> "\","
  <> "\"healthy\":"
  <> case r.healthy {
    True -> "true"
    False -> "false"
  }
  <> ","
  <> "\"node_count\":"
  <> int.to_string(r.node_count)
  <> ","
  <> "\"leader_node\":\""
  <> r.leader_node
  <> "\","
  <> "\"last_heartbeat\":"
  <> int.to_string(r.last_heartbeat)
  <> "}"
}

fn mode_to_string(mode: FederationMode) -> String {
  case mode {
    FullFederation -> "FullFederation"
    PartialFederation -> "PartialFederation"
    IslandMode -> "IslandMode"
    Recovering -> "Recovering"
  }
}
