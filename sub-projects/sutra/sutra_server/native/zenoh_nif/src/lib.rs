//! Zenoh Pub/Sub NIF for Sutra Matrix Server.
//! Publishes OTel spans and request telemetry to the Indrajaal Zenoh mesh.
//! Enables closed-loop testing: Patrol → FluffyChat → Sutra → Zenoh → Patrol.
//!
//! Functions:
//!   zenoh_open(mode) → ok | error
//!   zenoh_put(key_expr, value) → ok | no_session
//!   zenoh_publish_span(method, path, status, latency_ms) → ok
//!   zenoh_is_open() → bool
//!   zenoh_get_stats() → JSON stats string
//!   zenoh_publish_batch(entries: Vec<(key, value)>) → ok | no_session

use std::sync::OnceLock;
use std::sync::atomic::{AtomicU64, Ordering};

static SESSION: OnceLock<zenoh::Session> = OnceLock::new();

// Counters for observability
static PUTS_TOTAL: AtomicU64 = AtomicU64::new(0);
static PUTS_FAILED: AtomicU64 = AtomicU64::new(0);
static SPANS_TOTAL: AtomicU64 = AtomicU64::new(0);

/// Open a zenoh session. Mode: "peer" (standalone) or "client" (connect to router).
#[rustler::nif(schedule = "DirtyCpu")]
fn zenoh_open(mode: String) -> Result<String, String> {
    if SESSION.get().is_some() { return Ok("already_open".into()); }

    let mut config = zenoh::Config::default();
    if mode != "peer" {
        let _ = config.insert_json5("connect/endpoints", r#"["tcp/127.0.0.1:7447"]"#);
    }

    match zenoh::Wait::wait(zenoh::open(config)) {
        Ok(session) => {
            let _ = SESSION.set(session);
            Ok("ok".into())
        }
        Err(e) => Err(format!("zenoh open: {e}"))
    }
}

/// Publish a value to a zenoh key expression.
#[rustler::nif(schedule = "DirtyCpu")]
fn zenoh_put(key_expr: String, value: String) -> Result<String, String> {
    let session = match SESSION.get() {
        Some(s) => s,
        None => return Ok("no_session".into()),
    };
    match zenoh::Wait::wait(session.put(&key_expr, value.as_bytes().to_vec())) {
        Ok(_) => {
            PUTS_TOTAL.fetch_add(1, Ordering::Relaxed);
            Ok("ok".into())
        }
        Err(e) => {
            PUTS_FAILED.fetch_add(1, Ordering::Relaxed);
            Err(format!("zenoh put: {e}"))
        }
    }
}

/// Check if zenoh session is open.
#[rustler::nif]
fn zenoh_is_open() -> bool {
    SESSION.get().is_some()
}

/// Publish a Matrix request span to zenoh.
#[rustler::nif(schedule = "DirtyCpu")]
fn zenoh_publish_span(method: String, path: String, status: i32, latency_ms: i64) -> Result<String, String> {
    let session = match SESSION.get() {
        Some(s) => s,
        None => return Ok("no_session".into()),
    };
    let ts = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as u64;
    let span = format!(
        r#"{{"method":"{}","path":"{}","status":{},"latency_ms":{},"server":"sutra","ts":{}}}"#,
        method, path, status, latency_ms, ts
    );
    let key = format!("indrajaal/sutra/span/{}/{}", method.to_lowercase(), status);
    match zenoh::Wait::wait(session.put(&key, span.as_bytes().to_vec())) {
        Ok(_) => {
            SPANS_TOTAL.fetch_add(1, Ordering::Relaxed);
            Ok("ok".into())
        }
        Err(e) => Err(format!("{e}"))
    }
}

/// Get zenoh publishing statistics as JSON.
#[rustler::nif]
fn zenoh_get_stats() -> String {
    let connected = SESSION.get().is_some();
    let puts = PUTS_TOTAL.load(Ordering::Relaxed);
    let failed = PUTS_FAILED.load(Ordering::Relaxed);
    let spans = SPANS_TOTAL.load(Ordering::Relaxed);
    format!(
        r#"{{"connected":{},"puts_total":{},"puts_failed":{},"spans_total":{}}}"#,
        connected, puts, failed, spans
    )
}

/// Batch publish multiple key-value pairs to zenoh in one NIF call.
/// Reduces NIF boundary crossings for high-throughput scenarios.
#[rustler::nif(schedule = "DirtyCpu")]
fn zenoh_publish_batch(entries: Vec<(String, String)>) -> Result<String, String> {
    let session = match SESSION.get() {
        Some(s) => s,
        None => return Ok("no_session".into()),
    };
    let mut ok_count = 0u64;
    let mut err_count = 0u64;
    for (key, value) in &entries {
        match zenoh::Wait::wait(session.put(key.as_str(), value.as_bytes().to_vec())) {
            Ok(_) => ok_count += 1,
            Err(_) => err_count += 1,
        }
    }
    PUTS_TOTAL.fetch_add(ok_count, Ordering::Relaxed);
    PUTS_FAILED.fetch_add(err_count, Ordering::Relaxed);
    Ok(format!(r#"{{"ok":{},"errors":{}}}"#, ok_count, err_count))
}

rustler::init!("zenoh_ffi");
