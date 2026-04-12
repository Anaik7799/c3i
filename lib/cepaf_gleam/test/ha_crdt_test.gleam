/// CRDT Foundation Test Suite — 30+ tests
/// एकत्वं बहुत्वे — Unity in multiplicity (L7_FEDERATION)
///
/// Verifies all four CRDT types and their mathematical properties:
///   - G-Counter:    grow-only counter for distributed metrics
///   - PN-Counter:   up/down counter
///   - LWW-Register: last-writer-wins state register
///   - OR-Set:       observed-remove set for guard verdicts
///
/// Mathematical gate (all 3 laws must pass):
///   Commutativity  merge(a,b) = merge(b,a)
///   Associativity  merge(merge(a,b),c) = merge(a,merge(b,c))
///   Idempotency    merge(a,a) = a
///
/// STAMP: SC-ULTRA-001 (Focus 2), SC-XHOLON-006, SC-HA-001

import cepaf_gleam/ha/crdt
import gleam/list
import gleeunit/should

// =============================================================================
// G-Counter tests
// =============================================================================

pub fn gcounter_new_is_zero_test() {
  crdt.gcounter_new("node-1")
  |> crdt.gcounter_value()
  |> should.equal(0)
}

pub fn gcounter_increment_once_is_one_test() {
  crdt.gcounter_new("node-1")
  |> crdt.gcounter_increment()
  |> crdt.gcounter_value()
  |> should.equal(1)
}

pub fn gcounter_increment_three_times_test() {
  let c =
    crdt.gcounter_new("node-1")
    |> crdt.gcounter_increment()
    |> crdt.gcounter_increment()
    |> crdt.gcounter_increment()
  crdt.gcounter_value(c) |> should.equal(3)
}

pub fn gcounter_two_nodes_sum_test() {
  let a =
    crdt.gcounter_new("node-1")
    |> crdt.gcounter_increment()
    |> crdt.gcounter_increment()
  let b =
    crdt.gcounter_new("node-2")
    |> crdt.gcounter_increment()
    |> crdt.gcounter_increment()
    |> crdt.gcounter_increment()
  let merged = crdt.gcounter_merge(a, b)
  crdt.gcounter_value(merged) |> should.equal(5)
}

pub fn gcounter_merge_takes_max_per_node_test() {
  // Simulate diverged replicas: a has 5 on node-1, b has 3 on node-1
  let a =
    crdt.gcounter_new("node-1")
    |> crdt.gcounter_increment()
    |> crdt.gcounter_increment()
    |> crdt.gcounter_increment()
    |> crdt.gcounter_increment()
    |> crdt.gcounter_increment()
  // b is a stale replica with only 3 increments on the same node
  let b =
    crdt.gcounter_new("node-1")
    |> crdt.gcounter_increment()
    |> crdt.gcounter_increment()
    |> crdt.gcounter_increment()
  let merged = crdt.gcounter_merge(a, b)
  // max(5, 3) = 5 — no regression
  crdt.gcounter_value(merged) |> should.equal(5)
}

// =============================================================================
// G-Counter — Mathematical property tests
// =============================================================================

pub fn gcounter_commutativity_test() {
  let a =
    crdt.gcounter_new("n1")
    |> crdt.gcounter_increment()
    |> crdt.gcounter_increment()
  let b =
    crdt.gcounter_new("n2")
    |> crdt.gcounter_increment()
    |> crdt.gcounter_increment()
    |> crdt.gcounter_increment()
  crdt.verify_commutativity(a, b) |> should.be_true()
}

pub fn gcounter_associativity_test() {
  let a = crdt.gcounter_new("n1") |> crdt.gcounter_increment()
  let b = crdt.gcounter_new("n2") |> crdt.gcounter_increment()
  let c = crdt.gcounter_new("n3") |> crdt.gcounter_increment()
  crdt.verify_associativity(a, b, c) |> should.be_true()
}

pub fn gcounter_idempotency_test() {
  let a =
    crdt.gcounter_new("n1")
    |> crdt.gcounter_increment()
    |> crdt.gcounter_increment()
  crdt.verify_idempotency(a) |> should.be_true()
}

pub fn gcounter_verify_all_properties_test() {
  let a = crdt.gcounter_new("n1") |> crdt.gcounter_increment()
  let b = crdt.gcounter_new("n2") |> crdt.gcounter_increment()
  crdt.verify_all_properties(a, b) |> should.be_true()
}

pub fn gcounter_idempotency_empty_test() {
  let a = crdt.gcounter_new("n1")
  crdt.verify_idempotency(a) |> should.be_true()
}

pub fn gcounter_commutativity_asymmetric_test() {
  // One node has many increments, other has none
  let a =
    crdt.gcounter_new("n1")
    |> crdt.gcounter_increment()
    |> crdt.gcounter_increment()
    |> crdt.gcounter_increment()
  let b = crdt.gcounter_new("n2")
  crdt.verify_commutativity(a, b) |> should.be_true()
}

// =============================================================================
// PN-Counter tests
// =============================================================================

pub fn pncounter_new_is_zero_test() {
  crdt.pncounter_new("node-1")
  |> crdt.pncounter_value()
  |> should.equal(0)
}

pub fn pncounter_increment_once_test() {
  crdt.pncounter_new("node-1")
  |> crdt.pncounter_increment()
  |> crdt.pncounter_value()
  |> should.equal(1)
}

pub fn pncounter_decrement_once_test() {
  crdt.pncounter_new("node-1")
  |> crdt.pncounter_decrement()
  |> crdt.pncounter_value()
  |> should.equal(-1)
}

pub fn pncounter_inc_dec_net_test() {
  let c =
    crdt.pncounter_new("node-1")
    |> crdt.pncounter_increment()
    |> crdt.pncounter_increment()
    |> crdt.pncounter_increment()
    |> crdt.pncounter_decrement()
  crdt.pncounter_value(c) |> should.equal(2)
}

pub fn pncounter_merge_two_nodes_test() {
  let a =
    crdt.pncounter_new("n1")
    |> crdt.pncounter_increment()
    |> crdt.pncounter_increment()
  let b =
    crdt.pncounter_new("n2")
    |> crdt.pncounter_increment()
    |> crdt.pncounter_decrement()
  let merged = crdt.pncounter_merge(a, b)
  // n1 pos=2 neg=0, n2 pos=1 neg=1 → total = (2+1) - (0+1) = 2
  crdt.pncounter_value(merged) |> should.equal(2)
}

pub fn pncounter_merge_commutativity_test() {
  let a =
    crdt.pncounter_new("n1")
    |> crdt.pncounter_increment()
    |> crdt.pncounter_increment()
  let b =
    crdt.pncounter_new("n2")
    |> crdt.pncounter_increment()
    |> crdt.pncounter_decrement()
  let ab = crdt.pncounter_merge(a, b)
  let ba = crdt.pncounter_merge(b, a)
  crdt.pncounter_value(ab) |> should.equal(crdt.pncounter_value(ba))
}

pub fn pncounter_merge_idempotency_test() {
  let a =
    crdt.pncounter_new("n1")
    |> crdt.pncounter_increment()
    |> crdt.pncounter_decrement()
  let aa = crdt.pncounter_merge(a, a)
  crdt.pncounter_value(aa) |> should.equal(crdt.pncounter_value(a))
}

// =============================================================================
// LWW-Register tests
// =============================================================================

pub fn lww_new_empty_test() {
  let r = crdt.lww_new("node-1")
  crdt.lww_get(r) |> should.equal("")
}

pub fn lww_set_updates_value_test() {
  let r =
    crdt.lww_new("node-1")
    |> crdt.lww_set("active", 1000)
  crdt.lww_get(r) |> should.equal("active")
}

pub fn lww_set_higher_timestamp_wins_test() {
  let r =
    crdt.lww_new("node-1")
    |> crdt.lww_set("old", 1000)
    |> crdt.lww_set("new", 2000)
  crdt.lww_get(r) |> should.equal("new")
}

pub fn lww_set_lower_timestamp_ignored_test() {
  let r =
    crdt.lww_new("node-1")
    |> crdt.lww_set("current", 2000)
    |> crdt.lww_set("stale", 500)
  // stale write with lower timestamp must not overwrite
  crdt.lww_get(r) |> should.equal("current")
}

pub fn lww_merge_higher_timestamp_wins_test() {
  let a = crdt.lww_new("n1") |> crdt.lww_set("v1", 100)
  let b = crdt.lww_new("n2") |> crdt.lww_set("v2", 200)
  let merged = crdt.lww_merge(a, b)
  crdt.lww_get(merged) |> should.equal("v2")
}

pub fn lww_merge_commutativity_test() {
  let a = crdt.lww_new("n1") |> crdt.lww_set("alpha", 100)
  let b = crdt.lww_new("n2") |> crdt.lww_set("beta", 200)
  let ab = crdt.lww_merge(a, b)
  let ba = crdt.lww_merge(b, a)
  crdt.lww_get(ab) |> should.equal(crdt.lww_get(ba))
}

pub fn lww_merge_idempotency_test() {
  let a = crdt.lww_new("n1") |> crdt.lww_set("stable", 1000)
  let aa = crdt.lww_merge(a, a)
  crdt.lww_get(aa) |> should.equal(crdt.lww_get(a))
}

pub fn lww_merge_tie_break_by_node_id_test() {
  // Same timestamp: lexicographically larger node_id wins
  let a = crdt.lww_new("node-a") |> crdt.lww_set("from-a", 1000)
  let b = crdt.lww_new("node-z") |> crdt.lww_set("from-z", 1000)
  let merged = crdt.lww_merge(a, b)
  // "node-z" > "node-a" lexicographically → b wins
  crdt.lww_get(merged) |> should.equal("from-z")
}

// =============================================================================
// OR-Set tests
// =============================================================================

pub fn orset_new_is_empty_test() {
  crdt.orset_new()
  |> crdt.orset_elements()
  |> should.equal([])
}

pub fn orset_add_single_element_test() {
  let s = crdt.orset_new() |> crdt.orset_add("guardian-approved", "t1")
  crdt.orset_contains(s, "guardian-approved") |> should.be_true()
}

pub fn orset_add_two_elements_test() {
  let s =
    crdt.orset_new()
    |> crdt.orset_add("approved", "t1")
    |> crdt.orset_add("pending", "t2")
  let elems = crdt.orset_elements(s)
  list.length(elems) |> should.equal(2)
  list.contains(elems, "approved") |> should.be_true()
  list.contains(elems, "pending") |> should.be_true()
}

pub fn orset_remove_element_test() {
  let s =
    crdt.orset_new()
    |> crdt.orset_add("approved", "t1")
    |> crdt.orset_add("pending", "t2")
    |> crdt.orset_remove("approved")
  crdt.orset_contains(s, "approved") |> should.be_false()
  crdt.orset_contains(s, "pending") |> should.be_true()
}

pub fn orset_remove_nonexistent_is_noop_test() {
  let s =
    crdt.orset_new()
    |> crdt.orset_add("alpha", "t1")
    |> crdt.orset_remove("beta")
  crdt.orset_elements(s) |> should.equal(["alpha"])
}

pub fn orset_merge_union_test() {
  let a = crdt.orset_new() |> crdt.orset_add("x", "t1")
  let b = crdt.orset_new() |> crdt.orset_add("y", "t2")
  let merged = crdt.orset_merge(a, b)
  let elems = crdt.orset_elements(merged)
  list.contains(elems, "x") |> should.be_true()
  list.contains(elems, "y") |> should.be_true()
}

pub fn orset_merge_commutativity_test() {
  let a = crdt.orset_new() |> crdt.orset_add("x", "t1")
  let b = crdt.orset_new() |> crdt.orset_add("y", "t2")
  let ab = crdt.orset_merge(a, b)
  let ba = crdt.orset_merge(b, a)
  let ab_elems = crdt.orset_elements(ab)
  let ba_elems = crdt.orset_elements(ba)
  // Both should contain x and y
  { list.contains(ab_elems, "x") && list.contains(ab_elems, "y") }
  |> should.be_true()
  { list.contains(ba_elems, "x") && list.contains(ba_elems, "y") }
  |> should.be_true()
  // Same cardinality
  list.length(ab_elems) |> should.equal(list.length(ba_elems))
}

pub fn orset_merge_idempotency_test() {
  let a =
    crdt.orset_new()
    |> crdt.orset_add("alpha", "t1")
    |> crdt.orset_add("beta", "t2")
  let aa = crdt.orset_merge(a, a)
  list.length(crdt.orset_elements(aa))
  |> should.equal(list.length(crdt.orset_elements(a)))
}

pub fn orset_add_wins_over_concurrent_remove_test() {
  // Node A removes "verdict", Node B concurrently adds "verdict" with a new tag
  let base =
    crdt.orset_new()
    |> crdt.orset_add("verdict", "tag-original")
  let node_a = crdt.orset_remove(base, "verdict")
  let node_b = crdt.orset_add(base, "verdict", "tag-new")
  let merged = crdt.orset_merge(node_a, node_b)
  // "tag-new" was not tombstoned by node_a's remove → add wins
  crdt.orset_contains(merged, "verdict") |> should.be_true()
}

pub fn orset_merge_associativity_test() {
  let a = crdt.orset_new() |> crdt.orset_add("a", "t1")
  let b = crdt.orset_new() |> crdt.orset_add("b", "t2")
  let c = crdt.orset_new() |> crdt.orset_add("c", "t3")
  let left = crdt.orset_merge(crdt.orset_merge(a, b), c)
  let right = crdt.orset_merge(a, crdt.orset_merge(b, c))
  let left_elems = crdt.orset_elements(left)
  let right_elems = crdt.orset_elements(right)
  list.length(left_elems) |> should.equal(list.length(right_elems))
  { list.contains(left_elems, "a") && list.contains(right_elems, "a") }
  |> should.be_true()
  { list.contains(left_elems, "b") && list.contains(right_elems, "b") }
  |> should.be_true()
  { list.contains(left_elems, "c") && list.contains(right_elems, "c") }
  |> should.be_true()
}

// =============================================================================
// Integrated scenario: distributed guard verdict tracking (OR-Set use case)
// =============================================================================

pub fn orset_guard_verdict_scenario_test() {
  // Guardian node approves two tasks
  let guardian =
    crdt.orset_new()
    |> crdt.orset_add("task-001:approved", "g1-t001")
    |> crdt.orset_add("task-002:approved", "g1-t002")
  // Backup node also approved task-001 concurrently (different tag)
  let backup =
    crdt.orset_new()
    |> crdt.orset_add("task-001:approved", "g2-t001")
  // Merge: both nodes sync
  let synced = crdt.orset_merge(guardian, backup)
  // task-001 still present (add-wins semantics across nodes)
  crdt.orset_contains(synced, "task-001:approved") |> should.be_true()
  crdt.orset_contains(synced, "task-002:approved") |> should.be_true()
}
