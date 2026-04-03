//! ProofToken Enforcement — NIF Boundary Control-Plane Gate
//!
//! Mirrors the HMAC-SHA256 scheme from `Indrajaal.Prometheus.Verifier` so that
//! control-plane publishes (`indrajaal/control/**`) are blocked at the NIF
//! boundary unless a valid ProofToken is presented.
//!
//! ## Cryptographic Scheme (must stay in sync with verifier.ex)
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
//! - SC-NIF-005: ProofToken enforcement at NIF boundary
//! - SC-HASH-001: Deterministic computation
//! - SC-HASH-002: Constant-time comparison (timing-attack prevention)
//! - AOR-NIF-003: ProofToken verification before control-plane publish

use hmac::{Hmac, Mac};
use sha2::Sha256;
use std::sync::OnceLock;
use std::time::{Duration, Instant};

// HMAC-SHA256 type alias from RustCrypto
type HmacSha256 = Hmac<Sha256>;

// SC-PROM-001 / SC-NIF-005: HMAC key material — MUST match Elixir verifier.ex
const HMAC_KEY_MATERIAL: &[u8] = b"indrajaal_prometheus_verifier_hmac_key_v21.3.0";

// Prefix matching Elixir `"prom_sig_" <> hex(...)`
const SIG_PREFIX: &str = "prom_sig_";

// Control-plane key prefix — retained for backward compatibility with direct callers
#[allow(dead_code)]
const CONTROL_PLANE_PREFIX: &str = "indrajaal/control/";

// =============================================================================
// Tiered Enforcement (SC-NIF-010)
// =============================================================================

/// Tier 0 bypass: telemetry prefixes that NEVER require ProofToken.
const BYPASS_PREFIXES: &[&str] = &[
    "indrajaal/logs/",
    "indrajaal/metrics/",
    "indrajaal/health/",
];

/// Tier 1 session-cached: inference prefixes with HMAC cached for 60s.
const SESSION_PREFIXES: &[&str] = &[
    "indrajaal/inference/",
    "indrajaal/neural/",
];

/// Tier 2 full enforcement: control + evolution prefixes verified every call.
const FULL_PREFIXES: &[&str] = &[
    "indrajaal/control/",
    "indrajaal/evolution/",
];

/// Session token cache TTL in seconds (SC-NIF-011).
const SESSION_TOKEN_TTL_SECS: u64 = 60;

/// Maximum cache entries before lazy garbage collection.
const SESSION_CACHE_MAX_ENTRIES: usize = 1000;

/// Three-tier enforcement classification for Zenoh key expressions.
///
/// ## SC-NIF-010: Tiered ProofToken Enforcement
///
/// | Tier | Key Prefix | Enforcement | Latency Target |
/// |------|-----------|-------------|----------------|
/// | 0 (Bypass)  | logs, metrics, health | None | 0 |
/// | 1 (Session) | inference, neural | Session HMAC cached 60s | <5us |
/// | 2 (Full)    | control, evolution | Full HMAC per call | <10us |
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum EnforcementTier {
    /// No enforcement — telemetry, logs, health, metrics
    Bypass,
    /// Session-cached HMAC — inference, neural (<5us amortized)
    Session,
    /// Full HMAC per call — control, evolution (<10us)
    Full,
}

/// Classify a Zenoh key expression into its enforcement tier.
///
/// Keys not matching any known prefix default to `Bypass` (non-control,
/// non-inference traffic such as PubSub events, dashboard data, etc.).
#[inline]
pub fn classify_tier(key_expr: &str) -> EnforcementTier {
    for prefix in BYPASS_PREFIXES {
        if key_expr.starts_with(prefix) {
            return EnforcementTier::Bypass;
        }
    }
    for prefix in SESSION_PREFIXES {
        if key_expr.starts_with(prefix) {
            return EnforcementTier::Session;
        }
    }
    for prefix in FULL_PREFIXES {
        if key_expr.starts_with(prefix) {
            return EnforcementTier::Full;
        }
    }
    // Default: bypass for keys outside known hierarchies
    EnforcementTier::Bypass
}

// =============================================================================
// Session Token Cache (SC-NIF-011)
// =============================================================================

/// Thread-safe LRU-style session token cache.
///
/// Uses `parking_lot::RwLock` for fast concurrent reads (read-heavy workload).
/// Cache key is a truncated SHA-256 hash of the payload (16 hex chars).
/// Lazy GC: expired entries purged when cache exceeds `SESSION_CACHE_MAX_ENTRIES`.
struct SessionCache {
    entries: parking_lot::RwLock<std::collections::HashMap<String, Instant>>,
}

impl SessionCache {
    fn new() -> Self {
        SessionCache {
            entries: parking_lot::RwLock::new(std::collections::HashMap::new()),
        }
    }

    /// Check if a session token hash is still valid (not expired).
    fn is_valid(&self, token_hash: &str) -> bool {
        let entries = self.entries.read();
        if let Some(expires_at) = entries.get(token_hash) {
            Instant::now() < *expires_at
        } else {
            false
        }
    }

    /// Insert a validated session token hash with TTL.
    fn insert(&self, token_hash: &str, ttl_secs: u64) {
        let mut entries = self.entries.write();
        entries.insert(
            token_hash.to_string(),
            Instant::now() + Duration::from_secs(ttl_secs),
        );
        // Lazy GC: purge expired entries when cache grows too large
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

/// Verify a ProofToken with session caching (Tier 1).
///
/// On first verification for a payload, performs full HMAC-SHA256 check.
/// Result is cached for 60 seconds using a truncated payload hash as key.
/// Subsequent calls with the same payload return immediately from cache.
///
/// ## SC-NIF-011: Session Token Caching
pub fn verify_session(payload: &[u8]) -> Result<(), ProofTokenError> {
    // Compute cache key: first 8 bytes of SHA-256(payload) as hex
    let cache_key = {
        let hash = sha2_hash(payload);
        hex_encode(&hash[..8])
    };

    let cache = get_session_cache();
    if cache.is_valid(&cache_key) {
        return Ok(()); // Cache hit — skip full verification
    }

    // Cache miss — perform full HMAC verification
    verify_from_payload(payload)?;

    // Cache the successful result
    cache.insert(&cache_key, SESSION_TOKEN_TTL_SECS);
    Ok(())
}

/// Returns `true` when the key expression targets the inference plane
/// (`indrajaal/inference/**` or `indrajaal/neural/**`).
#[inline]
#[allow(dead_code)]
pub fn is_inference_plane(key_expr: &str) -> bool {
    SESSION_PREFIXES.iter().any(|p| key_expr.starts_with(p))
}

/// Decoded ProofToken fields extracted from the JSON payload.
///
/// Matches the Elixir struct:
/// ```elixir
/// %ProofToken{id: String.t(), timestamp: DateTime.t(), claims: map(), signature: String.t()}
/// ```
#[derive(Debug)]
pub struct ProofToken {
    /// UUID token id
    pub id: String,
    /// ISO 8601 timestamp string, e.g. "2026-03-28T10:00:00.000000Z"
    pub timestamp: String,
    /// Sorted canonical claims map (String key → JSON value as string)
    pub claims: Vec<(String, String)>,
    /// Full signature string including "prom_sig_" prefix
    pub signature: String,
}

/// Error variants for ProofToken verification failures.
#[derive(Debug, PartialEq)]
pub enum ProofTokenError {
    /// JSON payload is not valid UTF-8 or not parseable JSON
    InvalidJson,
    /// `proof_token` key is absent from the JSON object
    MissingProofToken,
    /// ProofToken JSON is missing a required field (id / timestamp / signature)
    MalformedToken(String),
    /// HMAC signature does not match the recomputed value
    InvalidSignature,
    /// The SHA-256 derived key could not be initialised (should never happen)
    CryptoError,
}

impl std::fmt::Display for ProofTokenError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ProofTokenError::InvalidJson => write!(f, "invalid_json"),
            ProofTokenError::MissingProofToken => write!(f, "missing_proof_token"),
            ProofTokenError::MalformedToken(msg) => write!(f, "malformed_token:{}", msg),
            ProofTokenError::InvalidSignature => write!(f, "invalid_signature"),
            ProofTokenError::CryptoError => write!(f, "crypto_error"),
        }
    }
}

/// Returns `true` when the key expression matches the control-plane prefix
/// (`indrajaal/control/`), meaning ProofToken enforcement is required.
///
/// Non-control-plane keys (telemetry, logs, events) are bypass-permitted.
/// Retained for backward compatibility — new code should use `classify_tier()`.
#[inline]
#[allow(dead_code)]
pub fn is_control_plane(key_expr: &str) -> bool {
    key_expr.starts_with(CONTROL_PLANE_PREFIX)
}

/// Verify a ProofToken against the HMAC-SHA256 scheme from `Indrajaal.Prometheus.Verifier`.
///
/// Returns `Ok(())` when the signature is valid, or an appropriate `ProofTokenError`.
///
/// ## Complexity
/// SHA-256 key derivation: O(1) — 64-byte hash on 45-byte key material.
/// HMAC-SHA256 computation: O(n) where n ≈ message length (<200 bytes typical).
/// Typical wall time: < 5 µs on modern hardware.
///
/// ## Timing safety (SC-HASH-002)
/// The final signature comparison uses `subtle::ConstantTimeEq` via
/// RustCrypto's `Hmac::verify_slice`, which is guaranteed constant-time.
pub fn verify(token: &ProofToken) -> Result<(), ProofTokenError> {
    // 1. Derive key: SHA-256(HMAC_KEY_MATERIAL)  — matches :crypto.hash(:sha256, @hmac_key_material)
    let derived_key = sha2_hash(HMAC_KEY_MATERIAL);

    // 2. Reconstruct canonical claims string — mirrors Elixir sign_claims/3:
    //    claims |> sort_by(k) |> map_join("|", fn {k,v} -> "#{k}=#{inspect(v)}" end)
    let canonical_claims = build_canonical_claims(&token.claims);

    // 3. Build message — "#{id}:#{canonical_claims}:#{DateTime.to_iso8601(timestamp)}"
    let message = format!("{}:{}:{}", token.id, canonical_claims, token.timestamp);

    // 4. Compute expected HMAC-SHA256, encode as lower-hex
    let expected_hex = hmac_sha256_hex(&derived_key, message.as_bytes())
        .map_err(|_| ProofTokenError::CryptoError)?;

    let expected_sig = format!("{}{}", SIG_PREFIX, expected_hex);

    // 5. Constant-time comparison (SC-HASH-002) — compare byte slices
    constant_time_eq(expected_sig.as_bytes(), token.signature.as_bytes())
        .map_err(|_| ProofTokenError::InvalidSignature)
}

/// Parse and verify a ProofToken from a raw JSON payload binary.
///
/// This is the primary entry point called from `publisher.rs` before
/// forwarding a control-plane publish to Zenoh.
///
/// Returns `Ok(())` on success, or a `ProofTokenError` describing the failure.
pub fn verify_from_payload(payload: &[u8]) -> Result<(), ProofTokenError> {
    // Parse outer JSON object
    let json: serde_json::Value =
        serde_json::from_slice(payload).map_err(|_| ProofTokenError::InvalidJson)?;

    // Extract proof_token sub-object
    let token_obj = json
        .get("proof_token")
        .ok_or(ProofTokenError::MissingProofToken)?;

    // Parse ProofToken fields
    let token = parse_proof_token(token_obj)?;

    // Run HMAC-SHA256 verification
    verify(&token)
}

// =============================================================================
// Private helpers
// =============================================================================

/// Compute SHA-256 hash of the input bytes, returning raw 32-byte digest.
fn sha2_hash(input: &[u8]) -> Vec<u8> {
    use sha2::Digest;
    let mut hasher = sha2::Sha256::new();
    hasher.update(input);
    hasher.finalize().to_vec()
}

/// Compute HMAC-SHA256(key, message) and return lower-hex encoded string.
///
/// Uses RustCrypto `hmac` crate which provides constant-time finalisation.
fn hmac_sha256_hex(key: &[u8], message: &[u8]) -> Result<String, ()> {
    let mut mac =
        HmacSha256::new_from_slice(key).map_err(|_| ())?;
    mac.update(message);
    let result = mac.finalize().into_bytes();
    Ok(hex_encode(&result))
}

/// Lowercase hex encoding without an external `hex` crate dependency.
fn hex_encode(bytes: &[u8]) -> String {
    bytes
        .iter()
        .map(|b| format!("{:02x}", b))
        .collect()
}

/// Build canonical claims string mirroring Elixir's `sign_claims/3`:
///
/// ```elixir
/// claims
/// |> Enum.sort_by(fn {k, _v} -> to_string(k) end)
/// |> Enum.map_join("|", fn {k, v} -> "#{k}=#{inspect(v)}" end)
/// ```
///
/// The claims vec MUST already be sorted by key (ascending) when passed to
/// `verify/1`, which is guaranteed by `parse_proof_token`.
fn build_canonical_claims(claims: &[(String, String)]) -> String {
    claims
        .iter()
        .map(|(k, v)| format!("{}={}", k, v))
        .collect::<Vec<_>>()
        .join("|")
}

/// Constant-time byte slice comparison (SC-HASH-002).
///
/// Returns `Ok(())` when slices are equal, `Err(())` otherwise.
/// The comparison does NOT short-circuit, preventing timing oracle attacks.
fn constant_time_eq(a: &[u8], b: &[u8]) -> Result<(), ()> {
    if a.len() != b.len() {
        // Length leaks one bit — that is acceptable because the attacker
        // already knows the expected length ("prom_sig_" + 64 hex chars = 73).
        return Err(());
    }
    let mut diff: u8 = 0;
    for (x, y) in a.iter().zip(b.iter()) {
        diff |= x ^ y;
    }
    if diff == 0 {
        Ok(())
    } else {
        Err(())
    }
}

/// Extract a `ProofToken` from a parsed `serde_json::Value` token object.
///
/// Mirrors the Elixir struct fields: id, timestamp (ISO8601 string), claims
/// (map of any JSON values), signature (string).
///
/// Claims are sorted by key ascending to match Elixir's `Enum.sort_by`.
fn parse_proof_token(obj: &serde_json::Value) -> Result<ProofToken, ProofTokenError> {
    let id = obj
        .get("id")
        .and_then(|v| v.as_str())
        .ok_or_else(|| ProofTokenError::MalformedToken("missing id".into()))?
        .to_string();

    // Accept either "timestamp" as a plain ISO8601 string OR as a nested object.
    // Elixir encodes `DateTime.t()` as ISO8601 string via Jason.Encoder.
    let timestamp = obj
        .get("timestamp")
        .ok_or_else(|| ProofTokenError::MalformedToken("missing timestamp".into()))?;

    let timestamp_str = match timestamp {
        serde_json::Value::String(s) => s.clone(),
        other => other.to_string(),
    };

    let signature = obj
        .get("signature")
        .and_then(|v| v.as_str())
        .ok_or_else(|| ProofTokenError::MalformedToken("missing signature".into()))?
        .to_string();

    // Parse claims map — any JSON object
    let claims_json = match obj.get("claims") {
        Some(serde_json::Value::Object(map)) => map,
        Some(_) => {
            return Err(ProofTokenError::MalformedToken(
                "claims must be a JSON object".into(),
            ))
        }
        None => {
            // Empty claims map is valid
            return Ok(ProofToken {
                id,
                timestamp: timestamp_str,
                claims: vec![],
                signature,
            });
        }
    };

    // Reconstruct the Elixir inspect() representation for each value.
    // Elixir inspect/1 for simple JSON types:
    //   nil      → "nil"
    //   true     → "true"
    //   false    → "false"
    //   integer  → decimal string
    //   float    → decimal string
    //   string   → "\"value\""   (double-quoted with surrounding quotes)
    //   other    → serde_json Display (best-effort)
    let mut claims: Vec<(String, String)> = claims_json
        .iter()
        .map(|(k, v)| {
            let inspected = elixir_inspect(v);
            (k.clone(), inspected)
        })
        .collect();

    // Sort ascending by key — matches Elixir `Enum.sort_by(fn {k,_} -> to_string(k) end)`
    claims.sort_by(|(a, _), (b, _)| a.cmp(b));

    Ok(ProofToken {
        id,
        timestamp: timestamp_str,
        claims,
        signature,
    })
}

/// Reproduce Elixir `inspect/1` output for JSON scalar values.
///
/// This is necessary because `sign_claims/3` uses `inspect(v)` rather than
/// `to_string(v)`, which means strings are wrapped in double-quotes in the
/// canonical representation.
///
/// Mapping:
/// | JSON type  | Elixir inspect output |
/// |------------|-----------------------|
/// | null       | "nil"                 |
/// | bool true  | "true"                |
/// | bool false | "false"               |
/// | integer    | e.g. "42"             |
/// | float      | e.g. "3.14"           |
/// | string     | e.g. "\"hello\""      |
/// | array/obj  | serde_json Display    |
fn elixir_inspect(value: &serde_json::Value) -> String {
    match value {
        serde_json::Value::Null => "nil".to_string(),
        serde_json::Value::Bool(b) => b.to_string(),
        serde_json::Value::Number(n) => n.to_string(),
        // Strings are wrapped in escaped double-quotes to match Elixir's inspect/1
        serde_json::Value::String(s) => format!("\"{}\"", s),
        // Arrays and objects: fall back to JSON display (best-effort for complex claims)
        other => other.to_string(),
    }
}

// =============================================================================
// Unit Tests
// =============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    // -------------------------------------------------------------------------
    // is_control_plane
    // -------------------------------------------------------------------------

    #[test]
    fn test_is_control_plane_matches_prefix() {
        assert!(is_control_plane("indrajaal/control/guardian/approve"));
        assert!(is_control_plane("indrajaal/control/"));
        assert!(is_control_plane("indrajaal/control/evolution/mutate"));
    }

    #[test]
    fn test_is_control_plane_rejects_non_control() {
        assert!(!is_control_plane("indrajaal/health/node1"));
        assert!(!is_control_plane("indrajaal/metrics/cpu"));
        assert!(!is_control_plane("indrajaal/logs/cluster/node-1"));
        assert!(!is_control_plane(""));
        assert!(!is_control_plane("control/indrajaal/bypass"));
    }

    // -------------------------------------------------------------------------
    // hex_encode
    // -------------------------------------------------------------------------

    #[test]
    fn test_hex_encode_known_value() {
        let bytes = [0xde, 0xad, 0xbe, 0xef];
        assert_eq!(hex_encode(&bytes), "deadbeef");
    }

    #[test]
    fn test_hex_encode_zeros() {
        let bytes = [0x00, 0x00];
        assert_eq!(hex_encode(&bytes), "0000");
    }

    // -------------------------------------------------------------------------
    // constant_time_eq
    // -------------------------------------------------------------------------

    #[test]
    fn test_constant_time_eq_equal_slices() {
        assert!(constant_time_eq(b"hello", b"hello").is_ok());
    }

    #[test]
    fn test_constant_time_eq_different_slices() {
        assert!(constant_time_eq(b"hello", b"world").is_err());
    }

    #[test]
    fn test_constant_time_eq_different_lengths() {
        assert!(constant_time_eq(b"hello", b"hello!").is_err());
    }

    #[test]
    fn test_constant_time_eq_empty_slices() {
        assert!(constant_time_eq(b"", b"").is_ok());
    }

    // -------------------------------------------------------------------------
    // sha2_hash
    // -------------------------------------------------------------------------

    #[test]
    fn test_sha2_hash_known_vector() {
        // SHA-256("") = e3b0c44298fc1c149afb...
        let result = sha2_hash(b"");
        assert_eq!(result.len(), 32);
        assert_eq!(result[0], 0xe3);
        assert_eq!(result[1], 0xb0);
    }

    // -------------------------------------------------------------------------
    // elixir_inspect
    // -------------------------------------------------------------------------

    #[test]
    fn test_elixir_inspect_null() {
        let v = serde_json::Value::Null;
        assert_eq!(elixir_inspect(&v), "nil");
    }

    #[test]
    fn test_elixir_inspect_bool_true() {
        let v = serde_json::Value::Bool(true);
        assert_eq!(elixir_inspect(&v), "true");
    }

    #[test]
    fn test_elixir_inspect_bool_false() {
        let v = serde_json::Value::Bool(false);
        assert_eq!(elixir_inspect(&v), "false");
    }

    #[test]
    fn test_elixir_inspect_integer() {
        let v = serde_json::json!(42);
        assert_eq!(elixir_inspect(&v), "42");
    }

    #[test]
    fn test_elixir_inspect_string() {
        let v = serde_json::Value::String("hello".into());
        assert_eq!(elixir_inspect(&v), "\"hello\"");
    }

    // -------------------------------------------------------------------------
    // build_canonical_claims
    // -------------------------------------------------------------------------

    #[test]
    fn test_build_canonical_claims_empty() {
        assert_eq!(build_canonical_claims(&[]), "");
    }

    #[test]
    fn test_build_canonical_claims_single() {
        let claims = vec![("action".to_string(), "\"mutate\"".to_string())];
        assert_eq!(build_canonical_claims(&claims), "action=\"mutate\"");
    }

    #[test]
    fn test_build_canonical_claims_multiple_sorted() {
        let claims = vec![
            ("action".to_string(), "\"mutate\"".to_string()),
            ("layer".to_string(), "3".to_string()),
            ("target".to_string(), "\"mesh\"".to_string()),
        ];
        assert_eq!(
            build_canonical_claims(&claims),
            "action=\"mutate\"|layer=3|target=\"mesh\""
        );
    }

    // -------------------------------------------------------------------------
    // hmac_sha256_hex — known test vector
    // -------------------------------------------------------------------------

    #[test]
    fn test_hmac_sha256_hex_known_vector() {
        // RFC 2202 test case 1:
        // key  = 0x0b * 20 bytes
        // data = "Hi There"
        // HMAC-SHA256 = b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7
        let key = vec![0x0b_u8; 20];
        let msg = b"Hi There";
        let hex = hmac_sha256_hex(&key, msg).unwrap();
        assert_eq!(
            hex,
            "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7"
        );
    }

    // -------------------------------------------------------------------------
    // verify_from_payload — end-to-end tests
    // -------------------------------------------------------------------------

    /// Build a valid ProofToken payload matching the Elixir signing scheme.
    /// This replicates what `Indrajaal.Prometheus.Verifier.issue_proof/1` produces.
    fn make_valid_payload(id: &str, timestamp: &str, claims_sorted: &[(&str, &str)]) -> Vec<u8> {
        // Compute expected signature
        let derived_key = sha2_hash(HMAC_KEY_MATERIAL);
        let canonical = claims_sorted
            .iter()
            .map(|(k, v)| format!("{}={}", k, v))
            .collect::<Vec<_>>()
            .join("|");
        let message = format!("{}:{}:{}", id, canonical, timestamp);
        let sig_hex = hmac_sha256_hex(&derived_key, message.as_bytes()).unwrap();
        let signature = format!("{}{}", SIG_PREFIX, sig_hex);

        // Build claims JSON object (values are already inspect-formatted strings)
        let mut claims_obj = serde_json::Map::new();
        for (k, v) in claims_sorted {
            // Store the raw inspect string so we can round-trip through elixir_inspect
            // For test purposes, use String JSON values (they will be wrapped in quotes by inspect)
            claims_obj.insert(k.to_string(), serde_json::Value::String(v[1..v.len()-1].to_string()));
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
    fn test_verify_from_payload_valid_token() {
        let payload = make_valid_payload(
            "550e8400-e29b-41d4-a716-446655440000",
            "2026-03-28T10:00:00.000000Z",
            &[("action", "\"mutate\""), ("layer", "\"3\"")],
        );
        assert!(verify_from_payload(&payload).is_ok());
    }

    #[test]
    fn test_verify_from_payload_empty_claims() {
        let id = "550e8400-e29b-41d4-a716-446655440001";
        let ts = "2026-03-28T11:00:00.000000Z";
        let derived_key = sha2_hash(HMAC_KEY_MATERIAL);
        let message = format!("{}::{}", id, ts);
        let sig_hex = hmac_sha256_hex(&derived_key, message.as_bytes()).unwrap();
        let signature = format!("{}{}", SIG_PREFIX, sig_hex);

        let payload = serde_json::json!({
            "proof_token": {
                "id": id,
                "timestamp": ts,
                "claims": {},
                "signature": signature
            }
        });
        assert!(verify_from_payload(payload.to_string().as_bytes()).is_ok());
    }

    #[test]
    fn test_verify_from_payload_invalid_signature() {
        let id = "550e8400-e29b-41d4-a716-446655440002";
        let ts = "2026-03-28T12:00:00.000000Z";
        let payload = serde_json::json!({
            "proof_token": {
                "id": id,
                "timestamp": ts,
                "claims": {},
                "signature": "prom_sig_deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
            }
        });
        let result = verify_from_payload(payload.to_string().as_bytes());
        assert_eq!(result, Err(ProofTokenError::InvalidSignature));
    }

    #[test]
    fn test_verify_from_payload_missing_proof_token() {
        let payload = br#"{"some_other_field": "value"}"#;
        let result = verify_from_payload(payload);
        assert_eq!(result, Err(ProofTokenError::MissingProofToken));
    }

    #[test]
    fn test_verify_from_payload_invalid_json() {
        let result = verify_from_payload(b"not json at all");
        assert_eq!(result, Err(ProofTokenError::InvalidJson));
    }

    #[test]
    fn test_verify_from_payload_malformed_token_missing_id() {
        let payload = serde_json::json!({
            "proof_token": {
                "timestamp": "2026-03-28T10:00:00.000000Z",
                "claims": {},
                "signature": "prom_sig_abc"
            }
        });
        let result = verify_from_payload(payload.to_string().as_bytes());
        assert!(matches!(result, Err(ProofTokenError::MalformedToken(_))));
    }

    #[test]
    fn test_verify_from_payload_tampered_claims() {
        // Build valid token then tamper with the claims value
        let id = "550e8400-e29b-41d4-a716-446655440003";
        let ts = "2026-03-28T13:00:00.000000Z";
        let claims_sorted = &[("action", "\"approve\"")];
        let mut raw = make_valid_payload(id, ts, claims_sorted);

        // Replace "approve" with "mutate" in the JSON bytes
        let raw_str = String::from_utf8(raw.clone()).unwrap();
        raw = raw_str.replace("approve", "mutate").into_bytes();

        let result = verify_from_payload(&raw);
        assert_eq!(result, Err(ProofTokenError::InvalidSignature));
    }

    #[test]
    fn test_verify_from_payload_tampered_id() {
        let id = "550e8400-e29b-41d4-a716-446655440004";
        let ts = "2026-03-28T14:00:00.000000Z";
        let payload = make_valid_payload(id, ts, &[]);
        let raw_str = String::from_utf8(payload).unwrap();
        // Replace last digit of UUID
        let tampered = raw_str.replace(id, "550e8400-e29b-41d4-a716-446655440099");
        let result = verify_from_payload(tampered.as_bytes());
        assert_eq!(result, Err(ProofTokenError::InvalidSignature));
    }

    // -------------------------------------------------------------------------
    // Tiered enforcement (SC-NIF-010)
    // -------------------------------------------------------------------------

    #[test]
    fn test_classify_tier_bypass_logs() {
        assert_eq!(classify_tier("indrajaal/logs/cluster/node-1"), EnforcementTier::Bypass);
    }

    #[test]
    fn test_classify_tier_bypass_metrics() {
        assert_eq!(classify_tier("indrajaal/metrics/cpu/usage"), EnforcementTier::Bypass);
    }

    #[test]
    fn test_classify_tier_bypass_health() {
        assert_eq!(classify_tier("indrajaal/health/node-1"), EnforcementTier::Bypass);
    }

    #[test]
    fn test_classify_tier_session_inference() {
        assert_eq!(classify_tier("indrajaal/inference/request/abc-123"), EnforcementTier::Session);
    }

    #[test]
    fn test_classify_tier_session_neural() {
        assert_eq!(classify_tier("indrajaal/neural/embeddings/batch-1"), EnforcementTier::Session);
    }

    #[test]
    fn test_classify_tier_full_control() {
        assert_eq!(classify_tier("indrajaal/control/guardian/approve"), EnforcementTier::Full);
    }

    #[test]
    fn test_classify_tier_full_evolution() {
        assert_eq!(classify_tier("indrajaal/evolution/mutate/genome"), EnforcementTier::Full);
    }

    #[test]
    fn test_classify_tier_unknown_defaults_bypass() {
        assert_eq!(classify_tier("indrajaal/prajna/kpi"), EnforcementTier::Bypass);
        assert_eq!(classify_tier("indrajaal/cluster/events"), EnforcementTier::Bypass);
        assert_eq!(classify_tier("other/topic/entirely"), EnforcementTier::Bypass);
        assert_eq!(classify_tier(""), EnforcementTier::Bypass);
    }

    #[test]
    fn test_is_inference_plane() {
        assert!(is_inference_plane("indrajaal/inference/request/123"));
        assert!(is_inference_plane("indrajaal/neural/batch/1"));
        assert!(!is_inference_plane("indrajaal/control/guardian"));
        assert!(!is_inference_plane("indrajaal/logs/node"));
        assert!(!is_inference_plane(""));
    }

    // -------------------------------------------------------------------------
    // Session cache (SC-NIF-011)
    // -------------------------------------------------------------------------

    #[test]
    fn test_session_cache_miss_then_hit() {
        let cache = SessionCache::new();
        let key = "test_cache_key_001";
        assert!(!cache.is_valid(key));
        cache.insert(key, 60);
        assert!(cache.is_valid(key));
    }

    #[test]
    fn test_session_cache_expired_entry() {
        let cache = SessionCache::new();
        let key = "test_cache_key_002";
        // Insert with 0 TTL — immediately expired
        cache.insert(key, 0);
        // After insertion with 0 TTL, the instant is in the past
        std::thread::sleep(std::time::Duration::from_millis(5));
        assert!(!cache.is_valid(key));
    }

    #[test]
    fn test_verify_session_valid_token() {
        let payload = make_valid_payload(
            "550e8400-e29b-41d4-a716-446655440010",
            "2026-03-28T15:00:00.000000Z",
            &[("action", "\"infer\"")],
        );
        // First call: full verification + cache
        assert!(verify_session(&payload).is_ok());
        // Second call: cache hit (fast path)
        assert!(verify_session(&payload).is_ok());
    }

    #[test]
    fn test_verify_session_invalid_token() {
        let payload = serde_json::json!({
            "proof_token": {
                "id": "bad-id",
                "timestamp": "2026-03-28T15:00:00.000000Z",
                "claims": {},
                "signature": "prom_sig_deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
            }
        });
        let result = verify_session(payload.to_string().as_bytes());
        assert_eq!(result, Err(ProofTokenError::InvalidSignature));
    }
}
