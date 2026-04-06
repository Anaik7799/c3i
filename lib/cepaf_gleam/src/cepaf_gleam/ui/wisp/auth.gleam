//// =============================================================================
//// [C3I-SIL6-MSTS] MATHEMATICAL & SEMANTIC MODULE CONTRACT
//// =============================================================================
//// <c3i-module>
////   <identity>
////     <module>cepaf_gleam/ui/wisp/auth</module>
////     <fsharp-lineage>Cepaf.Security.Auth.fs (not yet ported)</fsharp-lineage>
////   </identity>
////   <fractal-topology>
////     <layer>L0_CONSTITUTIONAL</layer>
////   </fractal-topology>
////   <compliance>
////     <stamp-controls>SC-SEC-001, SC-GLM-UI-003, SC-GLM-UI-006</stamp-controls>
////   </compliance>
////   <transformations>
////     <morphism type="injective">
////       Static bearer token validation ↪ future JWT/Ed25519 upgrade path.
////       Mitigation: Token read from env var C3I_API_TOKEN at call-site;
////       no global mutable state; Result(T, E) used exclusively.
////     </morphism>
////   </transformations>
//// </c3i-module>
//// =============================================================================
////
//// Bearer-token authentication middleware for the Wisp REST API (port 4100).
////
//// Design (CPS 8.60):
////   - GET endpoints are open — operators can monitor without a token.
////   - POST/PUT/DELETE/PATCH require a valid Bearer token.
////   - Token source: env var C3I_API_TOKEN (default: "c3i-dev-token").
////   - Future upgrade: swap validate_token/1 for JWT/Ed25519 without
////     changing the handle_request call-site.
////
//// STAMP: SC-SEC-001, SC-GLM-UI-003

import envoy
import gleam/http.{Delete, Patch, Post, Put}
import gleam/http/request.{type Request as HttpRequest}
import gleam/json
import gleam/string

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/// Result of inspecting the Authorization header on an incoming request.
pub type AuthResult {
  /// Token was present, well-formed, and matched the configured secret.
  Authenticated(principal: String)
  /// No Authorization header was present.
  Unauthenticated
  /// Header was present but malformed or the token did not match.
  InvalidToken(reason: String)
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Environment variable name for the API bearer token.
const token_env_var = "C3I_API_TOKEN"

/// Fallback token used when the env var is not set (development only).
const default_dev_token = "c3i-dev-token"

/// Principal name assigned to any successfully authenticated caller.
const api_principal = "api-client"

/// Prefix that MUST appear at the start of a valid Authorization header.
const bearer_prefix = "Bearer "

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Inspect the Authorization header of `request` and return an `AuthResult`.
///
/// [C3I-SIL6] ATOMIC CONTRACT
/// <c3i-atomic>
///   <morphism type="injective">Pure function ↪ no side effects beyond env read</morphism>
///   <formal-proof>
///     <P> request is a valid HTTP request value </P>
///     <C> validate_request(request) </C>
///     <Q> Returns Authenticated, Unauthenticated, or InvalidToken. Never panics. </Q>
///   </formal-proof>
/// </c3i-atomic>
pub fn validate_request(request: HttpRequest(String)) -> AuthResult {
  case request.get_header(request, "authorization") {
    Error(Nil) -> Unauthenticated
    Ok(header_value) -> validate_header(header_value)
  }
}

/// Convenience wrapper that returns `Ok(principal)` or `Error(reason)`.
/// Use this at call-sites that want a flat Result rather than the full ADT.
pub fn require_auth(request: HttpRequest(String)) -> Result(String, String) {
  case validate_request(request) {
    Authenticated(principal) -> Ok(principal)
    Unauthenticated -> Error("no_token")
    InvalidToken(reason) -> Error(reason)
  }
}

/// Return `True` when `method` is a mutation verb (POST, PUT, DELETE, PATCH).
/// GET and HEAD pass through without authentication (read-only monitoring).
pub fn is_mutation(method: http.Method) -> Bool {
  case method {
    Post | Put | Delete | Patch -> True
    _ -> False
  }
}

/// Produce a structured 401 JSON error body.
/// All JSON via gleam/json — no raw string concatenation (SC-GLM-UI-003).
pub fn auth_error_json(reason: String) -> String {
  json.object([
    #("error", json.string("unauthorized")),
    #("reason", json.string(reason)),
    #("stamp", json.string("SC-SEC-001")),
  ])
  |> json.to_string()
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

/// Validate a raw Authorization header value against the configured token.
fn validate_header(header_value: String) -> AuthResult {
  case string.starts_with(header_value, bearer_prefix) {
    False -> InvalidToken("authorization header must use Bearer scheme")
    True -> {
      // Drop "Bearer " (7 chars) to obtain the raw token.
      let submitted_token = string.drop_start(header_value, 7)
      let expected_token = configured_token()
      case submitted_token == expected_token {
        True -> Authenticated(api_principal)
        False -> InvalidToken("token_mismatch")
      }
    }
  }
}

/// Read the expected token from the environment, falling back to the dev
/// default when the variable is absent.
fn configured_token() -> String {
  case envoy.get(token_env_var) {
    Ok(token) -> token
    Error(Nil) -> default_dev_token
  }
}
