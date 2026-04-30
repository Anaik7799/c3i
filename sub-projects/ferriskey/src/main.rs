//! FerrisKey-C3I Bridge: Webhook receiver → Zenoh publisher
//!
//! Receives FerrisKey IAM webhook events and publishes them to the Zenoh mesh
//! under `indrajaal/auth/**` topics with dark cockpit filtering (SC-HMI-010).
//!
//! STAMP: SC-IAM-005, SC-IAM-006, SC-AUTH-005

mod oidc_client;
mod token_cache;
mod webhook_zenoh;

use axum::{Router, routing::post};
use std::sync::Arc;
use tracing::{info, warn};
use webhook_zenoh::WebhookState;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::fmt::init();

    // Connect to Zenoh mesh
    let zenoh_config = zenoh::Config::default();
    let zenoh_session = match zenoh::open(zenoh_config).await {
        Ok(session) => {
            info!("Zenoh session opened for auth event bridge");
            Some(Arc::new(session))
        }
        Err(e) => {
            warn!("Zenoh unavailable, running in degraded mode: {e}");
            None
        }
    };

    let state = Arc::new(WebhookState::new(zenoh_session));

    let app = Router::new()
        .route("/webhook", post(webhook_zenoh::handle_webhook))
        .route("/health", axum::routing::get(health))
        .with_state(state);

    let bind_addr = std::env::var("BRIDGE_BIND_ADDR").unwrap_or_else(|_| "0.0.0.0:9090".into());
    let listener = tokio::net::TcpListener::bind(&bind_addr).await?;
    info!("FerrisKey-C3I bridge listening on {bind_addr}");

    axum::serve(listener, app).await?;
    Ok(())
}

async fn health() -> &'static str {
    r#"{"status":"ok","service":"ferriskey-c3i-bridge"}"#
}
