//! Token cache for OAuth2 client credentials flow.
//!
//! Provides thread-safe cached token management with automatic refresh
//! when tokens approach expiration (30s buffer).
//!
//! STAMP: SC-AUTH-008

use std::sync::RwLock;
use std::time::{Duration, Instant};

/// Cached OAuth2 access token with expiration tracking.
#[derive(Debug, Clone)]
pub struct CachedToken {
    pub access_token: String,
    pub expires_at: Instant,
}

impl CachedToken {
    /// Check if the token is still valid (with 30s safety buffer).
    pub fn is_valid(&self) -> bool {
        Instant::now() + Duration::from_secs(30) < self.expires_at
    }
}

/// Thread-safe token cache for service account credentials.
pub struct TokenCache {
    cached: RwLock<Option<CachedToken>>,
}

impl TokenCache {
    pub fn new() -> Self {
        Self {
            cached: RwLock::new(None),
        }
    }

    /// Get the cached token if still valid.
    pub fn get(&self) -> Option<CachedToken> {
        let guard = self.cached.read().ok()?;
        guard.as_ref().filter(|t| t.is_valid()).cloned()
    }

    /// Store a new token with the given TTL in seconds.
    pub fn set(&self, access_token: String, expires_in_secs: u64) {
        if let Ok(mut guard) = self.cached.write() {
            *guard = Some(CachedToken {
                access_token,
                expires_at: Instant::now() + Duration::from_secs(expires_in_secs),
            });
        }
    }

    /// Invalidate the cached token.
    pub fn invalidate(&self) {
        if let Ok(mut guard) = self.cached.write() {
            *guard = None;
        }
    }
}

impl Default for TokenCache {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn new_cache_is_empty() {
        let cache = TokenCache::new();
        assert!(cache.get().is_none());
    }

    #[test]
    fn set_and_get_token() {
        let cache = TokenCache::new();
        cache.set("test-token".into(), 3600);
        let token = cache.get().expect("token should be cached");
        assert_eq!(token.access_token, "test-token");
        assert!(token.is_valid());
    }

    #[test]
    fn expired_token_returns_none() {
        let cache = TokenCache::new();
        // Set token that expires in 1 second (within 30s buffer, so already "expired")
        cache.set("expired-token".into(), 1);
        assert!(cache.get().is_none());
    }

    #[test]
    fn invalidate_clears_cache() {
        let cache = TokenCache::new();
        cache.set("token".into(), 3600);
        assert!(cache.get().is_some());
        cache.invalidate();
        assert!(cache.get().is_none());
    }
}
