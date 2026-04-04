//! ProofToken Verification — Wire-Level Enforcement for Zenoh Router Plugin
//!
//! This module is extracted from `zenoh_nif/src/proof_token.rs` to share the
//! identical HMAC-SHA256 scheme. Both the NIF boundary and the router plugin
//! MUST produce identical verification results for the same payload.
//!
//! ## Cryptographic Scheme (MUST stay in sync with verifier.ex AND zenoh_nif)
//!
//! ```text
//! derived_key   = SHA-256("indrajaal_prometheus_verifier_hmac_key_v21.3.0")
//! canonical     = sort(claims by key) |> join("|") using "k=inspect(v)"
//! message       = "{id}:{canonical}:{iso8601_timestamp}"
//! raw_sig       = HMAC-SHA256(derived_key, message)
//! signature     = "prom_sig_" + lower_hex(raw_sig)
//! ```
//!
//! ## STAMP Constraints
//! - SC-NIF-005: ProofToken enforcement at wire level (router tier)
//! - SC-HASH-001: Deterministic computation
//! - SC-HASH-002: Constant-time comparison (timing-attack prevention)

use hmac::{Hmac, Mac};
use sha2::Sha256;
use std::sync::OnceLock;
use std::time::{Duration, Instant};

type HmacSha256 = Hmac<Sha256>;

// SC-PROM-001 / SC-NIF-005: HMAC key material — MUST match Elixir verifier.ex AND zenoh_nif
const HMAC_KEY_MATERIAL: &[u8] = b"indrajaal_prometheus_verifier_hmac_key_v21.3.0";

const SIG_PREFIX: &str = "prom_sig_";

/// Session token cache TTL in seconds (SC-NIF-011).
const SESSION_TOKEN_TTL_SECS: u64 = 60;

/// Maximum cache entries before lazy garbage collection.
const SESSION_CACHE_MAX_ENTRIES: usize = 1000;

// =============================================================================
// Key Expression Filtering
// =============================================================================

/// Default control-plane key patterns that require ProofToken enforcement.
/// These match the Elixir RouterPlugin's `@default_control_filters`.
pub const DEFAULT_ENFORCEMENT_PATTERNS: &[&str] = &[
    "indrajaal/control/",
    "indrajaal/guardian/",
    "indrajaal/evolution/",
    "indrajaal/immune/",
];

/// Check if a key expression matches any enforcement pattern.
///
/// Uses prefix matching for performance (<10ns per check).
/// The patterns use prefix semantics — `indrajaal/control/` matches
/// `indrajaal/control/guardian/approve`, etc.
#[inline]
pub fn requires_enforcement(key_expr: &str) -> bool {
    DEFAULT_ENFORCEMENT_PATTERNS
        .iter()
        .any(|prefix| key_expr.starts_with(prefix))
}

// =============================================================================
// Session Token Cache (SC-NIF-011)
// =============================================================================

struct SessionCache {
    entries: parking_lot::RwLock<std::collections::HashMap<String, Instant>>,
}

impl SessionCache {
    fn new() -> Self {
        SessionCache {
            entries: parking_lot::RwLock::new(std::collections::HashMap::new()),
        }
    }

    fn is_valid(&self, token_hash: &str) -> bool {
        let entries = self.entries.read();
        if let Some(expires_at) = entries.get(token_hash) {
            Instant::now() < *expires_at
        } else {
            false
        }
    }

    fn insert(&self, token_hash: &str, ttl_secs: u64) {
        let mut entries = self.entries.write();
        entries.insert(
            token_hash.to_string(),
            Instant::now() + Duration::from_secs(ttl_secs),
        );
        if entries.len() > SESSION_CACHE_MAX_ENTRIES {
            let now = Instant::now();
            entries.retain(|_, expires| *expires > now);
        }
    }
}

static SESSION_CACHE: OnceLock<SessionCache> = OnceLock::new();

fn get_session_cache() -> &'static SessionCache {
    SESSION_CACHE.get_or_init(SessionCache::new)
}

// =============================================================================
// Public Verification API
// =============================================================================

/// Result of ProofToken verification at the router level.
#[derive(Debug, PartialEq)]
pub enum VerifyResult {
    /// Message does not target an enforced key — pass through.
    PassThrough,
    /// ProofToken is valid — allow routing.
    Verified,
    /// ProofToken verification failed — drop the message.
    Rejected(RejectReason),
}

/// Reason for rejecting a message at the router level.
#[derive(Debug, PartialEq)]
pub enum RejectReason {
    /// Payload is not valid UTF-8 or JSON.
    InvalidPayload,
    /// JSON object does not contain a `proof_token` field.
    MissingProofToken,
    /// ProofToken is missing required fields (id/timestamp/signature).
    MalformedToken,
    /// HMAC-SHA256 signature does not match.
    InvalidSignature,
    /// HMAC key could not be initialised (should never happen).
    CryptoError,
}

impl std::fmt::Display for RejectReason {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            RejectReason::InvalidPayload => write!(f, "invalid_payload"),
            RejectReason::MissingProofToken => write!(f, "missing_proof_token"),
            RejectReason::MalformedToken => write!(f, "malformed_token"),
            RejectReason::InvalidSignature => write!(f, "invalid_signature"),
            RejectReason::CryptoError => write!(f, "crypto_error"),
        }
    }
}

/// Verify a message at the router wire level.
///
/// This is the primary entry point called from the plugin's message interceptor.
///
/// 1. Check if key_expr matches enforcement patterns → PassThrough if not.
/// 2. Check session cache for recently verified payloads → Verified if cached.
/// 3. Parse JSON payload, extract ProofToken, verify HMAC-SHA256.
/// 4. Cache successful verifications for 60 seconds.
///
/// Returns `VerifyResult` indicating pass-through, verified, or rejected.
pub fn verify_message(key_expr: &str, payload: &[u8]) -> VerifyResult {
    if !requires_enforcement(key_expr) {
        return VerifyResult::PassThrough;
    }

    // Check session cache first (fast path: ~36ns for cache hit)
    let cache_key = {
        let hash = sha2_hash(payload);
        hex_encode(&hash[..8])
    };

    let cache = get_session_cache();
    if cache.is_valid(&cache_key) {
        return VerifyResult::Verified;
    }

    // Cache miss — perform full HMAC verification
    match verify_from_payload(payload) {
        Ok(()) => {
            cache.insert(&cache_key, SESSION_TOKEN_TTL_SECS);
            VerifyResult::Verified
        }
        Err(reason) => VerifyResult::Rejected(reason),
    }
}

// =============================================================================
// Internal Verification (identical to zenoh_nif/src/proof_token.rs)
// =============================================================================

struct ProofToken {
    id: String,
    timestamp: String,
    claims: Vec<(String, String)>,
    signature: String,
}

fn verify_from_payload(payload: &[u8]) -> Result<(), RejectReason> {
    let json: serde_json::Value =
        serde_json::from_slice(payload).map_err(|_| RejectReason::InvalidPayload)?;

    let token_obj = json
        .get("proof_token")
        .ok_or(RejectReason::MissingProofToken)?;

    let token = parse_proof_token(token_obj)?;
    verify(&token)
}

fn verify(token: &ProofToken) -> Result<(), RejectReason> {
    let derived_key = sha2_hash(HMAC_KEY_MATERIAL);
    let canonical_claims = build_canonical_claims(&token.claims);
    let message = format!("{}:{}:{}", token.id, canonical_claims, token.timestamp);

    let expected_hex = hmac_sha256_hex(&derived_key, message.as_bytes())
        .map_err(|_| RejectReason::CryptoError)?;

    let expected_sig = format!("{}{}", SIG_PREFIX, expected_hex);

    constant_time_eq(expected_sig.as_bytes(), token.signature.as_bytes())
        .map_err(|_| RejectReason::InvalidSignature)
}

// =============================================================================
// Private helpers (identical to zenoh_nif/src/proof_token.rs)
// =============================================================================

fn sha2_hash(input: &[u8]) -> Vec<u8> {
    use sha2::Digest;
    let mut hasher = sha2::Sha256::new();
    hasher.update(input);
    hasher.finalize().to_vec()
}

fn hmac_sha256_hex(key: &[u8], message: &[u8]) -> Result<String, ()> {
    let mut mac = HmacSha256::new_from_slice(key).map_err(|_| ())?;
    mac.update(message);
    let result = mac.finalize().into_bytes();
    Ok(hex_encode(&result))
}

fn hex_encode(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{:02x}", b)).collect()
}

fn build_canonical_claims(claims: &[(String, String)]) -> String {
    claims
        .iter()
        .map(|(k, v)| format!("{}={}", k, v))
        .collect::<Vec<_>>()
        .join("|")
}

fn constant_time_eq(a: &[u8], b: &[u8]) -> Result<(), ()> {
    if a.len() != b.len() {
        return Err(());
    }
    let mut diff: u8 = 0;
    for (x, y) in a.iter().zip(b.iter()) {
        diff |= x ^ y;
    }
    if diff == 0 { Ok(()) } else { Err(()) }
}

fn parse_proof_token(obj: &serde_json::Value) -> Result<ProofToken, RejectReason> {
    let id = obj
        .get("id")
        .and_then(|v| v.as_str())
        .ok_or(RejectReason::MalformedToken)?
        .to_string();

    let timestamp = obj
        .get("timestamp")
        .ok_or(RejectReason::MalformedToken)?;

    let timestamp_str = match timestamp {
        serde_json::Value::String(s) => s.clone(),
        other => other.to_string(),
    };

    let signature = obj
        .get("signature")
        .and_then(|v| v.as_str())
        .ok_or(RejectReason::MalformedToken)?
        .to_string();

    let claims_json = match obj.get("claims") {
        Some(serde_json::Value::Object(map)) => map,
        Some(_) => return Err(RejectReason::MalformedToken),
        None => {
            return Ok(ProofToken {
                id,
                timestamp: timestamp_str,
                claims: vec![],
                signature,
            });
        }
    };

    let mut claims: Vec<(String, String)> = claims_json
        .iter()
        .map(|(k, v)| {
            let inspected = elixir_inspect(v);
            (k.clone(), inspected)
        })
        .collect();

    claims.sort_by(|(a, _), (b, _)| a.cmp(b));

    Ok(ProofToken {
        id,
        timestamp: timestamp_str,
        claims,
        signature,
    })
}

fn elixir_inspect(value: &serde_json::Value) -> String {
    match value {
        serde_json::Value::Null => "nil".to_string(),
        serde_json::Value::Bool(b) => b.to_string(),
        serde_json::Value::Number(n) => n.to_string(),
        serde_json::Value::String(s) => format!("\"{}\"", s),
        other => other.to_string(),
    }
}

// =============================================================================
// Unit Tests
// =============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_requires_enforcement_control() {
        assert!(requires_enforcement("indrajaal/control/guardian/approve"));
        assert!(requires_enforcement("indrajaal/guardian/veto"));
        assert!(requires_enforcement("indrajaal/evolution/mutate"));
        assert!(requires_enforcement("indrajaal/immune/alert"));
    }

    #[test]
    fn test_requires_enforcement_bypass() {
        assert!(!requires_enforcement("indrajaal/logs/node-1"));
        assert!(!requires_enforcement("indrajaal/metrics/cpu"));
        assert!(!requires_enforcement("indrajaal/health/status"));
        assert!(!requires_enforcement("indrajaal/inference/request"));
        assert!(!requires_enforcement("other/topic"));
        assert!(!requires_enforcement(""));
    }

    fn make_valid_payload(id: &str, timestamp: &str, claims_sorted: &[(&str, &str)]) -> Vec<u8> {
        let derived_key = sha2_hash(HMAC_KEY_MATERIAL);
        let canonical = claims_sorted
            .iter()
            .map(|(k, v)| format!("{}={}", k, v))
            .collect::<Vec<_>>()
            .join("|");
        let message = format!("{}:{}:{}", id, canonical, timestamp);
        let sig_hex = hmac_sha256_hex(&derived_key, message.as_bytes()).unwrap();
        let signature = format!("{}{}", SIG_PREFIX, sig_hex);

        let mut claims_obj = serde_json::Map::new();
        for (k, v) in claims_sorted {
            claims_obj.insert(
                k.to_string(),
                serde_json::Value::String(v[1..v.len() - 1].to_string()),
            );
        }

        let payload = serde_json::json!({
            "proof_token": {
                "id": id,
                "timestamp": timestamp,
                "claims": claims_obj,
                "signature": signature
            }
        });
        payload.to_string().into_bytes()
    }

    #[test]
    fn test_verify_message_pass_through() {
        let result = verify_message("indrajaal/logs/test", b"any payload");
        assert_eq!(result, VerifyResult::PassThrough);
    }

    #[test]
    fn test_verify_message_valid_control_plane() {
        let payload = make_valid_payload(
            "550e8400-e29b-41d4-a716-446655440000",
            "2026-03-28T10:00:00.000000Z",
            &[("action", "\"mutate\""), ("layer", "\"3\"")],
        );
        let result = verify_message("indrajaal/control/test", &payload);
        assert_eq!(result, VerifyResult::Verified);
    }

    #[test]
    fn test_verify_message_invalid_signature() {
        let payload = serde_json::json!({
            "proof_token": {
                "id": "test-id",
                "timestamp": "2026-03-28T10:00:00.000000Z",
                "claims": {},
                "signature": "prom_sig_deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
            }
        });
        let result = verify_message("indrajaal/control/test", payload.to_string().as_bytes());
        assert_eq!(result, VerifyResult::Rejected(RejectReason::InvalidSignature));
    }

    #[test]
    fn test_verify_message_missing_proof_token() {
        let payload = serde_json::json!({"data": "no proof token here"});
        let result = verify_message("indrajaal/guardian/test", payload.to_string().as_bytes());
        assert_eq!(result, VerifyResult::Rejected(RejectReason::MissingProofToken));
    }

    #[test]
    fn test_verify_message_invalid_json() {
        let result = verify_message("indrajaal/evolution/test", b"not json");
        assert_eq!(result, VerifyResult::Rejected(RejectReason::InvalidPayload));
    }

    #[test]
    fn test_verify_message_cache_hit() {
        let payload = make_valid_payload(
            "cache-test-id-001",
            "2026-04-04T10:00:00.000000Z",
            &[("action", "\"cache_test\"")],
        );
        // First call: full verification + cache insert
        let result1 = verify_message("indrajaal/control/cache", &payload);
        assert_eq!(result1, VerifyResult::Verified);
        // Second call: should hit session cache
        let result2 = verify_message("indrajaal/control/cache", &payload);
        assert_eq!(result2, VerifyResult::Verified);
    }

    #[test]
    fn test_constant_time_eq_works() {
        assert!(constant_time_eq(b"hello", b"hello").is_ok());
        assert!(constant_time_eq(b"hello", b"world").is_err());
        assert!(constant_time_eq(b"a", b"ab").is_err());
    }

    #[test]
    fn test_hmac_known_vector() {
        let key = vec![0x0b_u8; 20];
        let msg = b"Hi There";
        let hex = hmac_sha256_hex(&key, msg).unwrap();
        assert_eq!(
            hex,
            "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7"
        );
    }
}
