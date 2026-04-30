//! OIDC Client for OAuth2 flows (client credentials, token exchange).
//!
//! Used by sa-plan-daemon and other Rust services to authenticate
//! against FerrisKey IAM via standard OAuth2/OIDC protocols.
//!
//! STAMP: SC-AUTH-002, SC-AUTH-008

use crate::token_cache::TokenCache;
use serde::Deserialize;
use tracing::{debug, warn};

/// OIDC client configuration.
#[derive(Debug, Clone)]
pub struct OidcClientConfig {
    pub token_endpoint: String,
    pub client_id: String,
    pub client_secret: String,
    pub scope: Option<String>,
}

impl OidcClientConfig {
    /// Create config from environment variables.
    pub fn from_env() -> Result<Self, String> {
        let issuer = std::env::var("FERRISKEY_ISSUER_URL")
            .unwrap_or_else(|_| "http://localhost:8080/realms/c3i-dev".into());
        Ok(Self {
            token_endpoint: format!("{issuer}/protocol/openid-connect/token"),
            client_id: std::env::var("FERRISKEY_CLIENT_ID")
                .unwrap_or_else(|_| "sa-plan-daemon".into()),
            client_secret: std::env::var("FERRISKEY_CLIENT_SECRET")
                .map_err(|_| "FERRISKEY_CLIENT_SECRET not set".to_string())?,
            scope: std::env::var("FERRISKEY_SCOPE").ok(),
        })
    }
}

/// Token response from the OAuth2 token endpoint.
#[derive(Debug, Deserialize)]
struct TokenResponse {
    access_token: String,
    expires_in: u64,
    #[allow(dead_code)]
    token_type: String,
}

/// OIDC client with token caching.
pub struct OidcClient {
    config: OidcClientConfig,
    http: reqwest::Client,
    cache: TokenCache,
}

impl OidcClient {
    pub fn new(config: OidcClientConfig) -> Self {
        Self {
            config,
            http: reqwest::Client::new(),
            cache: TokenCache::new(),
        }
    }

    /// Get a valid access token, refreshing from FerrisKey if needed.
    ///
    /// Uses OAuth2 client credentials flow (grant_type=client_credentials).
    pub async fn get_token(&self) -> Result<String, String> {
        // Check cache first
        if let Some(cached) = self.cache.get() {
            debug!("Using cached OIDC token");
            return Ok(cached.access_token);
        }

        // Fetch new token via client credentials flow
        debug!("Fetching new OIDC token from {}", self.config.token_endpoint);

        let mut params = vec![
            ("grant_type", "client_credentials"),
            ("client_id", &self.config.client_id),
            ("client_secret", &self.config.client_secret),
        ];

        let scope_str;
        if let Some(scope) = &self.config.scope {
            scope_str = scope.clone();
            params.push(("scope", &scope_str));
        }

        let response = self
            .http
            .post(&self.config.token_endpoint)
            .form(&params)
            .send()
            .await
            .map_err(|e| format!("Token request failed: {e}"))?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            warn!("Token endpoint returned {status}: {body}");
            return Err(format!("Token endpoint returned {status}"));
        }

        let token_resp: TokenResponse = response
            .json()
            .await
            .map_err(|e| format!("Failed to parse token response: {e}"))?;

        // Cache the token
        self.cache
            .set(token_resp.access_token.clone(), token_resp.expires_in);

        debug!("OIDC token cached (expires in {}s)", token_resp.expires_in);
        Ok(token_resp.access_token)
    }

    /// Invalidate the cached token (e.g., on 401 response).
    pub fn invalidate_token(&self) {
        self.cache.invalidate();
    }
}
