/// ZMOF (Zenoh-MCP-OTel Fractal) publishing layer.
///
/// Provides Zenoh session management with OnceLock caching (SC-MUDA-001),
/// typed JSON publishing, and OoZ span emission.
use chrono::Utc;
use serde::Serialize;
use std::sync::OnceLock;
use zenoh::Session;

use crate::namespace;

static ZENOH_SESSION: OnceLock<Session> = OnceLock::new();

/// Initialize a Zenoh session, or return the cached one.
///
/// The session connects to the default Zenoh router (tcp/localhost:7447).
/// Returns None if connection fails — tools should degrade gracefully.
pub async fn get_or_init_session() -> Option<&'static Session> {
    if let Some(session) = ZENOH_SESSION.get() {
        return Some(session);
    }

    match zenoh::open(zenoh::Config::default()).await {
        Ok(session) => {
            let _ = ZENOH_SESSION.set(session);
            ZENOH_SESSION.get()
        }
        Err(e) => {
            tracing::warn!("Zenoh connection failed (tools will run without ZMOF): {e}");
            None
        }
    }
}

/// Publish a JSON-serializable payload to a Zenoh key expression.
pub async fn publish_json<T: Serialize>(
    session: &Session,
    key_expr: &str,
    payload: &T,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let json = serde_json::to_vec(payload)?;
    session.put(key_expr, json).await?;
    tracing::debug!("Published to {key_expr}");
    Ok(())
}

/// Publish an OoZ (OTel-over-Zenoh) span.
pub async fn publish_ooz_span(
    session: &Session,
    layer: u8,
    entity_id: &str,
    operation: &str,
    duration_ms: u64,
    attributes: &serde_json::Value,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let span = OozSpan {
        trace_id: format!("{:032x}", rand_trace_id()),
        span_id: format!("{:016x}", rand_span_id()),
        operation: operation.to_string(),
        start_time: Utc::now().to_rfc3339(),
        duration_ms,
        layer,
        entity_id: entity_id.to_string(),
        attributes: attributes.clone(),
    };

    let key = namespace::ooz_span_key(layer, entity_id);
    publish_json(session, &key, &span).await
}

#[derive(Serialize)]
struct OozSpan {
    trace_id: String,
    span_id: String,
    operation: String,
    start_time: String,
    duration_ms: u64,
    layer: u8,
    entity_id: String,
    attributes: serde_json::Value,
}

fn rand_trace_id() -> u128 {
    use std::time::{SystemTime, UNIX_EPOCH};
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_nanos();
    nanos ^ (nanos >> 64)
}

fn rand_span_id() -> u64 {
    use std::time::{SystemTime, UNIX_EPOCH};
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_nanos() as u64
}
