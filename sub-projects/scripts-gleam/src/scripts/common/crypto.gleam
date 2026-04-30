//// scripts/common/crypto — Gleam wrapper over scripts_crypto_ffi (Erlang crypto).
//// Authority: SC-CPIG-FED-002 (Ed25519), SC-SCRIPT-GLEAM-001 (no shell, gleam-only).
////
//// Used by `scripts/verify/cpig_attest` and `scripts/verify/cpig_federation`
//// to sign + verify peer attestations of the C3I CPIG matrix score.

@external(erlang, "scripts_crypto_ffi", "ed25519_keypair")
fn ffi_keypair() -> #(Atom, String, String)

@external(erlang, "scripts_crypto_ffi", "ed25519_keypair_from_seed")
fn ffi_keypair_from_seed(seed_hex: String) -> #(Atom, String, String)

@external(erlang, "scripts_crypto_ffi", "ed25519_sign")
fn ffi_sign(message: String, priv_hex: String) -> #(Atom, String)

@external(erlang, "scripts_crypto_ffi", "ed25519_verify")
fn ffi_verify(message: String, sig_hex: String, pub_hex: String) -> #(Atom, Bool)

@external(erlang, "scripts_crypto_ffi", "sha256_hex")
fn ffi_sha256(message: String) -> #(Atom, String)

@external(erlang, "scripts_crypto_ffi", "canonical_attestation")
fn ffi_canonical(mesh_id: String, score: Int, ts: Int) -> #(Atom, String)

@external(erlang, "scripts_crypto_ffi", "now_seconds")
fn ffi_now() -> #(Atom, Int)

pub type Atom

pub type Keypair {
  Keypair(public_hex: String, private_hex: String)
}

pub fn keypair() -> Keypair {
  let #(_ok, pubh, priv) = ffi_keypair()
  Keypair(public_hex: pubh, private_hex: priv)
}

pub fn keypair_from_seed(seed_hex: String) -> Keypair {
  let #(_ok, pubh, priv) = ffi_keypair_from_seed(seed_hex)
  Keypair(public_hex: pubh, private_hex: priv)
}

pub fn sign(message: String, kp: Keypair) -> String {
  let #(_ok, sig) = ffi_sign(message, kp.private_hex)
  sig
}

pub fn verify(message: String, sig_hex: String, pub_hex: String) -> Bool {
  let #(_ok, ok) = ffi_verify(message, sig_hex, pub_hex)
  ok
}

pub fn sha256_hex(message: String) -> String {
  let #(_ok, h) = ffi_sha256(message)
  h
}

/// `<mesh>|<score>|<timestamp>` — canonical attestation pre-image.
pub fn canonical(mesh_id: String, score: Int, ts: Int) -> String {
  let #(_ok, s) = ffi_canonical(mesh_id, score, ts)
  s
}

pub fn now_seconds() -> Int {
  let #(_ok, t) = ffi_now()
  t
}
