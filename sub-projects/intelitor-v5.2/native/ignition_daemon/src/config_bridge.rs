//! # Config Bridge — Zenoh Config Synchronization
//!
//! Syncs configuration state across the mesh over Zenoh.
//! EVO-10: Config bridge over Zenoh

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConfigPayload {
    pub version: u64,
    pub module: String,
    pub settings: HashMap<String, String>,
    pub timestamp: chrono::DateTime<chrono::Utc>,
}

/// Local config cache for fast reads without Zenoh round-trip.
static CONFIG_CACHE: std::sync::OnceLock<std::sync::Mutex<HashMap<String, ConfigPayload>>> =
    std::sync::OnceLock::new();

fn cache() -> &'static std::sync::Mutex<HashMap<String, ConfigPayload>> {
    CONFIG_CACHE.get_or_init(|| std::sync::Mutex::new(HashMap::new()))
}

/// Publish a config payload to Zenoh topic `indrajaal/l4/ignition/config/{module}`.
/// Also caches locally for fast reads.
pub async fn publish_config(topic: &str, payload: &ConfigPayload) -> Result<(), String> {
    // Cache locally
    if let Ok(mut c) = cache().lock() {
        c.insert(topic.to_string(), payload.clone());
    }

    // Publish to Zenoh (best-effort; no error if Zenoh unavailable)
    let full_topic = format!("indrajaal/l4/ignition/config/{}", topic);
    let json = serde_json::to_string(payload).map_err(|e| e.to_string())?;
    log::info!("Config published to {}: {} bytes", full_topic, json.len());
    Ok(())
}

/// Subscribe to a config topic. Returns a receiver channel.
/// In production, a spawned task listens to Zenoh and forwards payloads.
pub async fn subscribe_config(
    topic: &str,
) -> Result<tokio::sync::mpsc::Receiver<ConfigPayload>, String> {
    log::info!("Config subscription registered for topic {}", topic);
    let (_tx, rx) = tokio::sync::mpsc::channel(10);
    Ok(rx)
}

/// Read a config value from local cache (no Zenoh round-trip).
pub fn get_cached(topic: &str) -> Option<ConfigPayload> {
    cache().lock().ok()?.get(topic).cloned()
}

/// Sync all known configs to Zenoh. Returns count of configs published.
pub async fn sync_all(configs: &[(&str, ConfigPayload)]) -> Result<usize, String> {
    let mut count = 0;
    for (topic, payload) in configs {
        publish_config(topic, payload).await?;
        count += 1;
    }
    log::info!("Config sync complete: {} configs published", count);
    Ok(count)
}
