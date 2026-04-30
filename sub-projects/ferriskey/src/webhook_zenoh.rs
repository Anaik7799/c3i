//! FerrisKey Webhook → Zenoh Bridge
//!
//! Receives webhook payloads from FerrisKey IAM, classifies events,
//! applies dark cockpit filtering (SC-HMI-010), and publishes to Zenoh.
//!
//! STAMP: SC-IAM-005, SC-IAM-006, SC-HMI-010

use axum::{Json, extract::State, http::StatusCode};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tracing::{debug, info, warn};

/// Shared state for the webhook handler.
pub struct WebhookState {
    zenoh: Option<Arc<zenoh::Session>>,
}

impl WebhookState {
    pub fn new(zenoh: Option<Arc<zenoh::Session>>) -> Self {
        Self { zenoh }
    }
}

/// FerrisKey webhook payload (matches FerrisKey's webhook format).
#[derive(Debug, Deserialize)]
pub struct WebhookPayload {
    pub event_type: String,
    pub realm_id: Option<String>,
    pub user_id: Option<String>,
    pub client_id: Option<String>,
    pub ip_address: Option<String>,
    pub details: Option<serde_json::Value>,
    pub timestamp: Option<String>,
}

/// Zenoh auth event published to the mesh.
#[derive(Debug, Serialize)]
struct AuthEvent {
    event_type: String,
    realm_id: String,
    user_id: String,
    client_id: String,
    ip_address: String,
    timestamp: String,
    severity: String,
    details: serde_json::Value,
}

/// Dark cockpit classification: should this event be published?
#[derive(Debug, PartialEq)]
enum CockpitAction {
    /// Publish to Zenoh (anomalous or security-relevant)
    Publish,
    /// Suppress (nominal operation, dark cockpit)
    Suppress,
}

/// Classify event for dark cockpit filtering (SC-HMI-010).
///
/// Nominal events (login success, token issued for service accounts) are
/// suppressed. Anomalous events (failures, role changes, admin actions) are
/// always published.
fn classify_event(event_type: &str) -> CockpitAction {
    match event_type {
        // Always publish (anomalous or security-relevant)
        "login_failure" | "LOGIN_ERROR" => CockpitAction::Publish,
        "logout" | "LOGOUT" => CockpitAction::Publish,
        "token_revoked" | "REVOKE_TOKEN" => CockpitAction::Publish,
        "role_assigned" | "role_unassigned" => CockpitAction::Publish,
        "mfa_failure" | "MFA_ERROR" => CockpitAction::Publish,
        "mfa_enrolled" | "MFA_REGISTER" => CockpitAction::Publish,
        "admin_action" | "ADMIN_EVENT" => CockpitAction::Publish,
        "user_created" | "user_deleted" => CockpitAction::Publish,
        "client_created" | "client_deleted" => CockpitAction::Publish,
        "credential_created" | "credential_deleted" => CockpitAction::Publish,
        "federation_linked" | "IDENTITY_PROVIDER_LINK" => CockpitAction::Publish,

        // Suppress (nominal — dark cockpit)
        "login_success" | "LOGIN" => CockpitAction::Suppress,
        "token_issued" | "CODE_TO_TOKEN" => CockpitAction::Suppress,
        "token_refreshed" | "REFRESH_TOKEN" => CockpitAction::Suppress,

        // Unknown events: publish (fail-safe, SC-AUTH-005)
        _ => CockpitAction::Publish,
    }
}

/// Map event type to Zenoh topic suffix.
fn event_to_topic(event_type: &str) -> &str {
    match event_type {
        "login_failure" | "LOGIN_ERROR" | "login_success" | "LOGIN" => "login",
        "logout" | "LOGOUT" => "logout",
        "token_revoked" | "REVOKE_TOKEN" => "token/revoked",
        "token_issued" | "CODE_TO_TOKEN" => "token/issued",
        "role_assigned" | "role_unassigned" => "role/changed",
        "mfa_failure" | "MFA_ERROR" => "mfa/failed",
        "mfa_enrolled" | "MFA_REGISTER" => "mfa/enrolled",
        "admin_action" | "ADMIN_EVENT" => "admin/action",
        "user_created" | "user_deleted" => "user/lifecycle",
        "client_created" | "client_deleted" => "client/lifecycle",
        "federation_linked" | "IDENTITY_PROVIDER_LINK" => "federation/linked",
        _ => "unknown",
    }
}

/// Map event type to severity for OTel spans.
fn event_severity(event_type: &str) -> &str {
    match event_type {
        "login_failure" | "LOGIN_ERROR" | "mfa_failure" | "MFA_ERROR" => "warning",
        "admin_action" | "ADMIN_EVENT" | "role_assigned" | "role_unassigned" => "info",
        "user_deleted" | "client_deleted" | "token_revoked" | "REVOKE_TOKEN" => "warning",
        _ => "info",
    }
}

/// Handle incoming webhook from FerrisKey.
pub async fn handle_webhook(
    State(state): State<Arc<WebhookState>>,
    Json(payload): Json<WebhookPayload>,
) -> StatusCode {
    let event_type = &payload.event_type;

    // Dark cockpit filtering (SC-HMI-010)
    match classify_event(event_type) {
        CockpitAction::Suppress => {
            debug!("Dark cockpit: suppressing nominal event '{event_type}'");
            return StatusCode::OK;
        }
        CockpitAction::Publish => {
            info!("Publishing auth event '{event_type}' to Zenoh mesh");
        }
    }

    let auth_event = AuthEvent {
        event_type: event_type.clone(),
        realm_id: payload.realm_id.unwrap_or_default(),
        user_id: payload.user_id.unwrap_or_default(),
        client_id: payload.client_id.unwrap_or_default(),
        ip_address: payload.ip_address.unwrap_or_default(),
        timestamp: payload.timestamp.unwrap_or_default(),
        severity: event_severity(event_type).to_string(),
        details: payload.details.unwrap_or(serde_json::Value::Null),
    };

    // Publish to Zenoh
    if let Some(zenoh) = &state.zenoh {
        let topic = format!("indrajaal/auth/{}", event_to_topic(event_type));
        let otel_topic = format!("indrajaal/otel/spans/auth/{}", event_to_topic(event_type));

        match serde_json::to_string(&auth_event) {
            Ok(json_str) => {
                // Publish auth event
                if let Err(e) = zenoh.put(&topic, json_str.as_bytes()).await {
                    warn!("Failed to publish to {topic}: {e}");
                }
                // Publish OTel span (SC-IAM-006)
                if let Err(e) = zenoh.put(&otel_topic, json_str.as_bytes()).await {
                    warn!("Failed to publish OTel span to {otel_topic}: {e}");
                }
            }
            Err(e) => {
                warn!("Failed to serialize auth event: {e}");
                return StatusCode::INTERNAL_SERVER_ERROR;
            }
        }
    } else {
        warn!("Zenoh not connected, auth event '{event_type}' lost");
    }

    StatusCode::OK
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn login_success_suppressed_by_dark_cockpit() {
        assert_eq!(classify_event("login_success"), CockpitAction::Suppress);
        assert_eq!(classify_event("LOGIN"), CockpitAction::Suppress);
    }

    #[test]
    fn login_failure_published() {
        assert_eq!(classify_event("login_failure"), CockpitAction::Publish);
        assert_eq!(classify_event("LOGIN_ERROR"), CockpitAction::Publish);
    }

    #[test]
    fn token_issued_suppressed() {
        assert_eq!(classify_event("token_issued"), CockpitAction::Suppress);
        assert_eq!(classify_event("CODE_TO_TOKEN"), CockpitAction::Suppress);
    }

    #[test]
    fn security_events_always_published() {
        assert_eq!(classify_event("role_assigned"), CockpitAction::Publish);
        assert_eq!(classify_event("mfa_failure"), CockpitAction::Publish);
        assert_eq!(classify_event("admin_action"), CockpitAction::Publish);
        assert_eq!(classify_event("user_deleted"), CockpitAction::Publish);
        assert_eq!(classify_event("token_revoked"), CockpitAction::Publish);
    }

    #[test]
    fn unknown_events_published_fail_safe() {
        assert_eq!(classify_event("something_unknown"), CockpitAction::Publish);
    }

    #[test]
    fn event_topic_mapping() {
        assert_eq!(event_to_topic("login_failure"), "login");
        assert_eq!(event_to_topic("role_assigned"), "role/changed");
        assert_eq!(event_to_topic("mfa_failure"), "mfa/failed");
        assert_eq!(event_to_topic("admin_action"), "admin/action");
    }
}
