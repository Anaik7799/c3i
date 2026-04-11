/// CRDT property tests — commutativity, associativity, idempotency
/// SC-ULTRA-001 Focus 2: Zenoh-Native CRDT State Backplane

import cepaf_gleam/crdt/types
import gleeunit/should

// LWW-Register
pub fn lww_new_creates_register_test() {
  let r = types.lww_new("hello", "node-1", 1000)
  r.value |> should.equal("hello")
  r.timestamp |> should.equal(1000)
}

pub fn lww_merge_higher_timestamp_wins_test() {
  let a = types.lww_new("old", "node-1", 1000)
  let b = types.lww_new("new", "node-2", 2000)
  let merged = types.lww_merge(a, b)
  merged.value |> should.equal("new")
}

pub fn lww_merge_commutative_test() {
  let a = types.lww_new("v1", "n1", 100)
  let b = types.lww_new("v2", "n2", 200)
  let ab = types.lww_merge(a, b)
  let ba = types.lww_merge(b, a)
  ab.value |> should.equal(ba.value)
}

pub fn lww_merge_idempotent_test() {
  let a = types.lww_new("v1", "n1", 100)
  let aa = types.lww_merge(a, a)
  aa.value |> should.equal(a.value)
}

// G-Counter
pub fn gcounter_new_is_zero_test() {
  types.gcounter_value(types.gcounter_new()) |> should.equal(0)
}

pub fn gcounter_increment_adds_test() {
  let c = types.gcounter_new() |> types.gcounter_increment("n1", 5)
  types.gcounter_value(c) |> should.equal(5)
}

pub fn gcounter_merge_commutative_test() {
  let a = types.gcounter_new() |> types.gcounter_increment("n1", 3)
  let b = types.gcounter_new() |> types.gcounter_increment("n2", 7)
  let ab = types.gcounter_merge(a, b)
  let ba = types.gcounter_merge(b, a)
  types.gcounter_value(ab) |> should.equal(types.gcounter_value(ba))
  types.gcounter_value(ab) |> should.equal(10)
}

// PN-Counter
pub fn pncounter_inc_dec_test() {
  let c = types.pncounter_new()
    |> types.pncounter_increment("n1", 10)
    |> types.pncounter_decrement("n1", 3)
  types.pncounter_value(c) |> should.equal(7)
}

// OR-Set
pub fn orset_add_remove_test() {
  let s = types.orset_new()
    |> types.orset_add("apple", "t1", 100)
    |> types.orset_add("banana", "t2", 101)
    |> types.orset_remove("apple")
  types.orset_elements(s) |> should.equal(["banana"])
}

pub fn orset_merge_commutative_test() {
  let a = types.orset_new() |> types.orset_add("x", "t1", 100)
  let b = types.orset_new() |> types.orset_add("y", "t2", 200)
  let ab = types.orset_merge(a, b)
  let ba = types.orset_merge(b, a)
  let ab_els = types.orset_elements(ab)
  let ba_els = types.orset_elements(ba)
  { list.contains(ab_els, "x") && list.contains(ab_els, "y") } |> should.be_true()
  { list.contains(ba_els, "x") && list.contains(ba_els, "y") } |> should.be_true()
}

import gleam/list
