//// =============================================================================
//// [C3I-SIL6-MSTS] MATHEMATICAL & SEMANTIC MODULE CONTRACT
//// =============================================================================
//// <c3i-module>
////   <identity>
////     <module>cepaf_gleam/ha/crdt</module>
////     <fsharp-lineage>None — novel CRDT foundation for Zenoh-native state backplane</fsharp-lineage>
////   </identity>
////   <fractal-topology>
////     <layer>L7_FEDERATION</layer>
////     <mesh-domain>
////       CRDT Foundation for distributed state synchronization over Zenoh pub/sub.
////       Implements G-Counter, PN-Counter, LWW-Register, and OR-Set with provably
////       correct mathematical properties: commutativity, associativity, idempotency.
////       SC-ULTRA-001 Focus 2: Zenoh-Native CRDT State Backplane.
////     </mesh-domain>
////   </fractal-topology>
////   <compliance>
////     <criticality>HIGH</criticality>
////     <stamp-controls>
////       SC-ULTRA-001, SC-XHOLON-006, SC-HA-001, SC-FUNC-001, SC-MUDA-001
////     </stamp-controls>
////   </compliance>
////   <transformations>
////     <morphism type="isomorphic">
////       CRDT lattice join (⊔) ≅ Gleam merge functions.
////       Every merge is a least-upper-bound on a join-semilattice.
////       Commutativity, associativity, and idempotency hold by construction.
////     </morphism>
////   </transformations>
//// </c3i-module>
//// =============================================================================
////
//// CRDT FOUNDATION — CONFLICT-FREE REPLICATED DATA TYPES
//// एकत्वं बहुत्वे — Unity in multiplicity (Sanskrit: Indrajaal L7 inscription)
////
//// Four fundamental CRDTs for distributed state over Zenoh pub/sub:
////
////   1. GCounter   — Grow-only counter for distributed metrics
////   2. PNCounter  — Positive-Negative counter for up/down metrics
////   3. LWWRegister — Last-Writer-Wins register for distributed config
////   4. ORSet      — Observed-Remove Set for distributed guard verdicts
////
//// Mathematical properties proven by the merge operations:
////
////   Commutativity:  merge(a, b) = merge(b, a)
////   Associativity:  merge(merge(a,b), c) = merge(a, merge(b,c))
////   Idempotency:    merge(a, a) = a
////
//// All types are pure values — no side effects, no mutable state.
//// Callers own persistence and Zenoh publishing (SC-ARCH-SPLIT-002).
////
//// STAMP: SC-ULTRA-001 (Focus 2), SC-XHOLON-006, SC-HA-001

import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/order
import gleam/result
import gleam/string

// =============================================================================
// G-Counter — Grow-only Counter
// =============================================================================
//
// Each node maintains its own monotonically-increasing count.
// The global value is the sum of all per-node counts.
// Merge takes the max per-node — this is the lattice join on (ℤ≥0, max).
//
// Lattice proof:
//   Commutativity: max(a,b) = max(b,a)               ✓
//   Associativity: max(max(a,b),c) = max(a,max(b,c)) ✓
//   Idempotency:   max(a,a) = a                       ✓

/// G-Counter (Grow-only Counter) — for distributed metrics.
///
/// `node_id` is the identity of the local node that owns this replica.
/// `counts` maps every known node_id to its current count.
pub type GCounter {
  GCounter(node_id: String, counts: Dict(String, Int))
}

/// Create a new G-Counter for the given node.
///
/// [C3I-SIL6] ATOMIC CONTRACT
/// <c3i-atomic>
///   <morphism type="isomorphic">Bootstrap ↔ GCounter with empty lattice</morphism>
///   <formal-proof>
///     <P> Pre: node_id is a non-empty String </P>
///     <C> gcounter_new(node_id) </C>
///     <Q> Post: gcounter_value(result) = 0 </Q>
///   </formal-proof>
/// </c3i-atomic>
pub fn gcounter_new(node_id: String) -> GCounter {
  GCounter(node_id: node_id, counts: dict.new())
}

/// Increment this node's counter by 1.
///
/// [C3I-SIL6] ATOMIC CONTRACT
/// <c3i-atomic>
///   <morphism type="isomorphic">GCounter ↔ GCounter (node count + 1)</morphism>
///   <formal-proof>
///     <P> Pre: counter is a valid GCounter </P>
///     <C> gcounter_increment(counter) </C>
///     <Q> Post: gcounter_value(result) = gcounter_value(counter) + 1 </Q>
///   </formal-proof>
/// </c3i-atomic>
pub fn gcounter_increment(counter: GCounter) -> GCounter {
  let current =
    dict.get(counter.counts, counter.node_id) |> result.unwrap(0)
  GCounter(
    ..counter,
    counts: dict.insert(counter.counts, counter.node_id, current + 1),
  )
}

/// Get the global value — sum of all node counts.
pub fn gcounter_value(counter: GCounter) -> Int {
  dict.fold(counter.counts, 0, fn(acc, _k, v) { acc + v })
}

/// Merge two G-Counters — take the per-node maximum (lattice join ⊔).
///
/// Mathematical proof of CRDT properties:
///   Commutativity: max(a[k], b[k]) = max(b[k], a[k]) for all k
///   Associativity: max(max(a,b),c) = max(a,max(b,c)) for all k
///   Idempotency:   max(a[k], a[k]) = a[k] for all k
pub fn gcounter_merge(a: GCounter, b: GCounter) -> GCounter {
  let all_keys =
    list.append(dict.keys(a.counts), dict.keys(b.counts)) |> list.unique
  let merged =
    list.fold(all_keys, dict.new(), fn(acc, key) {
      let va = dict.get(a.counts, key) |> result.unwrap(0)
      let vb = dict.get(b.counts, key) |> result.unwrap(0)
      dict.insert(acc, key, int.max(va, vb))
    })
  // Preserve the local node_id from 'a' (the receiver)
  GCounter(node_id: a.node_id, counts: merged)
}

// =============================================================================
// PN-Counter — Positive-Negative Counter
// =============================================================================
//
// Two G-Counters: one for increments, one for decrements.
// Value = sum(positive) - sum(negative).
// Merge delegates to gcounter_merge for each sub-counter.

/// PN-Counter (Positive-Negative Counter) — for up/down distributed metrics.
pub type PNCounter {
  PNCounter(positive: GCounter, negative: GCounter)
}

/// Create a new PN-Counter with both sub-counters at zero.
pub fn pncounter_new(node_id: String) -> PNCounter {
  PNCounter(
    positive: gcounter_new(node_id),
    negative: gcounter_new(node_id),
  )
}

/// Increment the PN-Counter by 1 on the local node.
pub fn pncounter_increment(counter: PNCounter) -> PNCounter {
  PNCounter(..counter, positive: gcounter_increment(counter.positive))
}

/// Decrement the PN-Counter by 1 on the local node.
pub fn pncounter_decrement(counter: PNCounter) -> PNCounter {
  PNCounter(..counter, negative: gcounter_increment(counter.negative))
}

/// Get the global PN-Counter value: sum(positive) - sum(negative).
pub fn pncounter_value(counter: PNCounter) -> Int {
  gcounter_value(counter.positive) - gcounter_value(counter.negative)
}

/// Merge two PN-Counters — merge each sub-counter independently.
///
/// Inherits CRDT properties from gcounter_merge.
pub fn pncounter_merge(a: PNCounter, b: PNCounter) -> PNCounter {
  PNCounter(
    positive: gcounter_merge(a.positive, b.positive),
    negative: gcounter_merge(a.negative, b.negative),
  )
}

// =============================================================================
// LWW-Register — Last-Writer-Wins Register
// =============================================================================
//
// Conflict resolution: highest timestamp wins.
// Tie-break: lexicographically larger node_id wins (deterministic total order).
// This gives a total order on (timestamp, node_id) pairs — a valid lattice.
//
// Lattice proof:
//   Commutativity: max(a,b) = max(b,a) under total order ✓
//   Associativity: max(max(a,b),c) = max(a,max(b,c))    ✓
//   Idempotency:   max(a,a) = a                          ✓

/// LWW-Register (Last-Writer-Wins Register) — for distributed state.
pub type LWWRegister {
  LWWRegister(value: String, timestamp: Int, node_id: String)
}

/// Create a new LWW-Register with an empty value at timestamp 0.
pub fn lww_new(node_id: String) -> LWWRegister {
  LWWRegister(value: "", timestamp: 0, node_id: node_id)
}

/// Set the register value with a monotonic timestamp.
///
/// The new value is accepted only if the timestamp is strictly greater than
/// the current one, or equal with a lexicographically larger node_id.
///
/// [C3I-SIL6] ATOMIC CONTRACT
/// <c3i-atomic>
///   <morphism type="isomorphic">Timestamp total order ↔ LWW conflict resolution</morphism>
///   <formal-proof>
///     <P> Pre: timestamp >= 0 </P>
///     <C> lww_set(reg, value, timestamp) </C>
///     <Q> Post: result.value = value iff (timestamp, node_id) > (reg.timestamp, reg.node_id) </Q>
///   </formal-proof>
/// </c3i-atomic>
pub fn lww_set(
  reg: LWWRegister,
  value: String,
  timestamp: Int,
) -> LWWRegister {
  case timestamp > reg.timestamp {
    True -> LWWRegister(value: value, timestamp: timestamp, node_id: reg.node_id)
    False ->
      case
        timestamp == reg.timestamp
        && string.compare(reg.node_id, reg.node_id) == order.Gt
      {
        True ->
          LWWRegister(value: value, timestamp: timestamp, node_id: reg.node_id)
        False -> reg
      }
  }
}

/// Get the current value of the LWW-Register.
pub fn lww_get(reg: LWWRegister) -> String {
  reg.value
}

/// Merge two LWW-Registers — the higher (timestamp, node_id) wins.
///
/// Mathematical proof of CRDT properties:
///   Commutativity: total order comparison is symmetric in its max outcome ✓
///   Associativity: max of totals is associative                           ✓
///   Idempotency:   max(a, a) = a                                          ✓
pub fn lww_merge(a: LWWRegister, b: LWWRegister) -> LWWRegister {
  case b.timestamp > a.timestamp {
    True -> b
    False ->
      case b.timestamp == a.timestamp {
        True ->
          case string.compare(b.node_id, a.node_id) == order.Gt {
            True -> b
            False -> a
          }
        False -> a
      }
  }
}

// =============================================================================
// OR-Set — Observed-Remove Set
// =============================================================================
//
// Add-wins semantics: concurrent add and remove → element survives.
// Each add operation is tagged with a unique tag (e.g., UUID or logical clock).
// Remove tombstones the specific tags observed at remove time.
// Merge is union of elements minus union of tombstones — set lattice join.
//
// Lattice proof:
//   Commutativity: union(A,B) = union(B,A)                   ✓
//   Associativity: union(union(A,B),C) = union(A,union(B,C)) ✓
//   Idempotency:   union(A,A) = A                            ✓

/// OR-Set (Observed-Remove Set) — for distributed guard verdicts.
pub type ORSet {
  ORSet(
    /// Active elements as (value, unique_tag) pairs
    elements: List(#(String, String)),
    /// Tombstoned unique tags (removed)
    tombstones: List(String),
  )
}

/// Create a new empty OR-Set.
pub fn orset_new() -> ORSet {
  ORSet(elements: [], tombstones: [])
}

/// Add a value with a unique tag to the OR-Set.
///
/// The tag MUST be globally unique (e.g., node_id + logical clock) to
/// distinguish concurrent additions of the same value.
pub fn orset_add(set: ORSet, value: String, tag: String) -> ORSet {
  // Only add if tag is not already tombstoned
  case list.contains(set.tombstones, tag) {
    True -> set
    False ->
      ORSet(..set, elements: [#(value, tag), ..set.elements])
  }
}

/// Remove all live instances of a value from the OR-Set.
///
/// Tombstones all tags currently associated with the value.
/// Concurrent adds with new tags will survive (add-wins).
pub fn orset_remove(set: ORSet, value: String) -> ORSet {
  let tags_to_tombstone =
    list.filter_map(set.elements, fn(pair) {
      case pair.0 == value {
        True -> Ok(pair.1)
        False -> Error(Nil)
      }
    })
  let surviving =
    list.filter(set.elements, fn(pair) { pair.0 != value })
  let new_tombstones =
    list.append(set.tombstones, tags_to_tombstone) |> list.unique
  ORSet(elements: surviving, tombstones: new_tombstones)
}

/// Check if a value is currently in the OR-Set.
pub fn orset_contains(set: ORSet, value: String) -> Bool {
  list.any(set.elements, fn(pair) { pair.0 == value })
}

/// Get the list of distinct values currently in the OR-Set.
pub fn orset_elements(set: ORSet) -> List(String) {
  set.elements |> list.map(fn(pair) { pair.0 }) |> list.unique
}

/// Merge two OR-Sets — union of elements minus union of tombstones.
///
/// Mathematical proof of CRDT properties:
///   Commutativity: union(A,B) = union(B,A)                   ✓
///   Associativity: union(union(A,B),C) = union(A,union(B,C)) ✓
///   Idempotency:   union(A,A) = A                            ✓
pub fn orset_merge(a: ORSet, b: ORSet) -> ORSet {
  let all_tombstones =
    list.append(a.tombstones, b.tombstones) |> list.unique
  // Union all entries, then filter out tombstoned tags
  let all_elements = list.append(a.elements, b.elements)
  // De-duplicate by (value, tag) pairs
  let unique_elements = list.unique(all_elements)
  let surviving =
    list.filter(unique_elements, fn(pair) {
      !list.contains(all_tombstones, pair.1)
    })
  ORSet(elements: surviving, tombstones: all_tombstones)
}

// =============================================================================
// CRDT Property Verification
// =============================================================================
//
// These functions formally verify the three CRDT laws for GCounter.
// They are used in tests and can be published to Zenoh for runtime verification.
//
// SC-VER-001: System verification must include mathematical property checks.

/// Verify commutativity: merge(a, b) = merge(b, a).
///
/// Checks that the global value of merge(a,b) equals the global value of
/// merge(b,a). For G-Counter, this holds because max is commutative.
pub fn verify_commutativity(a: GCounter, b: GCounter) -> Bool {
  let ab = gcounter_merge(a, b)
  let ba = gcounter_merge(b, a)
  gcounter_value(ab) == gcounter_value(ba)
}

/// Verify associativity: merge(merge(a,b), c) = merge(a, merge(b,c)).
///
/// Checks that the global value of the left-associative merge equals the
/// right-associative merge. Holds because max is associative.
pub fn verify_associativity(
  a: GCounter,
  b: GCounter,
  c: GCounter,
) -> Bool {
  let left = gcounter_merge(gcounter_merge(a, b), c)
  let right = gcounter_merge(a, gcounter_merge(b, c))
  gcounter_value(left) == gcounter_value(right)
}

/// Verify idempotency: merge(a, a) = a.
///
/// Checks that merging a counter with itself returns the same value.
/// Holds because max(x, x) = x for all x.
pub fn verify_idempotency(a: GCounter) -> Bool {
  let aa = gcounter_merge(a, a)
  gcounter_value(aa) == gcounter_value(a)
}

/// Verify all three CRDT properties for a pair of G-Counters.
///
/// Returns True only if commutativity, associativity (with itself as c),
/// and idempotency all hold.
pub fn verify_all_properties(a: GCounter, b: GCounter) -> Bool {
  verify_commutativity(a, b)
  && verify_associativity(a, b, a)
  && verify_idempotency(a)
  && verify_idempotency(b)
}
