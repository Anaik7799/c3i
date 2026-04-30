//// Tests for scripts/verify/cpig_federation
//// Authority: SC-CPIG-FED-001..010

import gleeunit
import gleeunit/should
import scripts/common/crypto
import scripts/verify/cpig_federation.{
  type Attestation, type FederationDecision, Attestation, InsufficientPeers,
  Quorum, SplitBrain, quorum_2oo3, validate,
}

pub fn main() -> Nil {
  gleeunit.main()
}

const seed_a =
  "1111111111111111111111111111111111111111111111111111111111111111"

const seed_b =
  "2222222222222222222222222222222222222222222222222222222222222222"

const seed_c =
  "3333333333333333333333333333333333333333333333333333333333333333"

fn make(mesh: String, region: String, score: Int, seed: String) -> Attestation {
  let kp = crypto.keypair_from_seed(seed)
  let now = crypto.now_seconds()
  let canon = crypto.canonical(mesh, score, now)
  let sig = crypto.sign(canon, kp)
  Attestation(
    mesh_id: mesh,
    region: region,
    score: score,
    timestamp: now,
    sig_hex: sig,
    public_hex: kp.public_hex,
  )
}

fn make_stale(mesh: String, region: String, score: Int, seed: String) -> Attestation {
  // 2 hours old → past TTL of 1 hour.
  let kp = crypto.keypair_from_seed(seed)
  let now = crypto.now_seconds() - 7201
  let canon = crypto.canonical(mesh, score, now)
  let sig = crypto.sign(canon, kp)
  Attestation(
    mesh_id: mesh,
    region: region,
    score: score,
    timestamp: now,
    sig_hex: sig,
    public_hex: kp.public_hex,
  )
}

pub fn keypair_deterministic_test() {
  let k1 = crypto.keypair_from_seed(seed_a)
  let k2 = crypto.keypair_from_seed(seed_a)
  k1.public_hex |> should.equal(k2.public_hex)
}

pub fn sign_verify_roundtrip_test() {
  let kp = crypto.keypair_from_seed(seed_a)
  let canon = crypto.canonical("mesh-eu-1", 33, 1700000000)
  let sig = crypto.sign(canon, kp)
  crypto.verify(canon, sig, kp.public_hex) |> should.be_true
}

pub fn verify_rejects_tampered_message_test() {
  let kp = crypto.keypair_from_seed(seed_a)
  let canon = crypto.canonical("mesh-eu-1", 33, 1700000000)
  let sig = crypto.sign(canon, kp)
  let tampered = crypto.canonical("mesh-eu-1", 99, 1700000000)
  crypto.verify(tampered, sig, kp.public_hex) |> should.be_false
}

pub fn verify_rejects_wrong_pubkey_test() {
  let kp_a = crypto.keypair_from_seed(seed_a)
  let kp_b = crypto.keypair_from_seed(seed_b)
  let canon = crypto.canonical("mesh-eu-1", 33, 1700000000)
  let sig = crypto.sign(canon, kp_a)
  crypto.verify(canon, sig, kp_b.public_hex) |> should.be_false
}

pub fn validate_attestation_test() {
  let att = make("mesh-eu-1", "eu", 33, seed_a)
  validate(att) |> should.be_true
}

pub fn validate_rejects_stale_attestation_test() {
  let att = make_stale("mesh-eu-1", "eu", 33, seed_a)
  validate(att) |> should.be_false
}

pub fn quorum_insufficient_one_region_test() {
  let atts = [make("mesh-eu-1", "eu", 33, seed_a)]
  case quorum_2oo3(atts) {
    InsufficientPeers(rcv, req) -> {
      rcv |> should.equal(1)
      req |> should.equal(2)
    }
    _ -> should.fail()
  }
}

pub fn quorum_two_of_three_agree_test() {
  let atts = [
    make("mesh-eu-1", "eu", 33, seed_a),
    make("mesh-us-1", "us-west", 33, seed_b),
    make("mesh-asia-1", "asia", 28, seed_c),
  ]
  case quorum_2oo3(atts) {
    Quorum(score, _regions) -> score |> should.equal(33)
    _ -> should.fail()
  }
}

pub fn quorum_unanimous_test() {
  let atts = [
    make("mesh-eu-1", "eu", 33, seed_a),
    make("mesh-us-1", "us-west", 33, seed_b),
    make("mesh-asia-1", "asia", 33, seed_c),
  ]
  case quorum_2oo3(atts) {
    Quorum(score, _) -> score |> should.equal(33)
    _ -> should.fail()
  }
}

pub fn quorum_split_brain_three_way_test() {
  let atts = [
    make("mesh-eu-1", "eu", 33, seed_a),
    make("mesh-us-1", "us-west", 28, seed_b),
    make("mesh-asia-1", "asia", 22, seed_c),
  ]
  case quorum_2oo3(atts) {
    SplitBrain(_) -> True |> should.be_true
    _ -> should.fail()
  }
}

pub fn quorum_filters_stale_attestations_test() {
  let atts = [
    make("mesh-eu-1", "eu", 33, seed_a),
    make_stale("mesh-us-1", "us-west", 33, seed_b),
    make_stale("mesh-asia-1", "asia", 33, seed_c),
  ]
  case quorum_2oo3(atts) {
    InsufficientPeers(_, _) -> True |> should.be_true
    _ -> should.fail()
  }
}
