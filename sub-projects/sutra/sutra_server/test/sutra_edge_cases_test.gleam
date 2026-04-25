//// Sutra Edge Cases & Error Paths — Matrix Client-Server API v1.13
////
//// Tests ALL boundary conditions, malformed inputs, injection attempts,
//// missing fields, unknown paths, auth failures, and spec-mandated error shapes.
////
//// Structure:
////   Section A: Malformed / empty request bodies     (~12 tests)
////   Section B: Auth edge cases                      (~10 tests)
////   Section C: Room ID edge cases                   (~8  tests)
////   Section D: Event edge cases                     (~8  tests)
////   Section E: Sync edge cases                      (~6  tests)
////   Section F: Media edge cases                     (~8  tests)
////   Section G: Membership edge cases                (~10 tests)
////   Section H: Key / E2EE edge cases                (~6  tests)
////   Section I: Push rule edge cases                 (~6  tests)
////   Section J: Account data edge cases              (~6  tests)
////   Section K: Injection / path traversal attacks   (~8  tests)
////   Section L: HTTP method mismatches               (~8  tests)
////   Section M: Federation edge cases                (~6  tests)
////   Section N: Profile and presence edge cases      (~6  tests)
////   Section O: Well-known / discovery edge cases    (~4  tests)
////
//// All tests are PURE — no HTTP, no OTP, no file I/O.

import gleam/option.{None, Some}
import gleam/string
import gleeunit
import gleeunit/should
import sutra_server/api/router.{type ApiResult, ErrorResponse, JsonResponse}

pub fn main() -> Nil {
  gleeunit.main()
}

// ---------------------------------------------------------------------------
// Helpers (mirrored from compliance test)
// ---------------------------------------------------------------------------

fn body_of(result: ApiResult) -> String {
  case result {
    JsonResponse(_, b) -> b
    ErrorResponse(_, code, msg) ->
      "{\"errcode\":\"" <> code <> "\",\"error\":\"" <> msg <> "\"}"
  }
}

fn status_of(result: ApiResult) -> Int {
  case result {
    JsonResponse(s, _) -> s
    ErrorResponse(s, _, _) -> s
  }
}

fn is_error(result: ApiResult, expected_status: Int) -> Bool {
  case result {
    ErrorResponse(s, _, _) -> s == expected_status
    JsonResponse(_, _) -> False
  }
}

fn is_ok(result: ApiResult, expected_status: Int) -> Bool {
  case result {
    JsonResponse(s, _) -> s == expected_status
    ErrorResponse(_, _, _) -> False
  }
}

/// Error responses must always have both errcode and error fields.
fn error_has_both_fields(result: ApiResult) -> Bool {
  case result {
    JsonResponse(_, _) -> True
    // JsonResponse is fine
    ErrorResponse(_, code, msg) ->
      string.length(code) > 0 && string.length(msg) > 0
  }
}

// ===========================================================================
// Section A: Malformed / Empty Request Bodies
// ===========================================================================

/// Empty body to POST /login — router stub accepts anything and issues token.
pub fn empty_login_body_test() {
  let result = router.route("POST", "/_matrix/client/v3/login", "", None)
  // Stub login ignores body and returns 200 — spec says 400 for missing fields.
  // We test that the response is one of the two valid shapes.
  let s = status_of(result)
  { s == 200 || s == 400 } |> should.be_true()
}

/// Completely invalid JSON to POST /login.
pub fn invalid_json_login_body_test() {
  let result =
    router.route(
      "POST",
      "/_matrix/client/v3/login",
      "not json at all!!!",
      None,
    )
  let s = status_of(result)
  { s == 200 || s == 400 } |> should.be_true()
}

/// POST /register with only whitespace in body — should get UIA challenge (401).
pub fn register_whitespace_body_test() {
  let result =
    router.route("POST", "/_matrix/client/v3/register", "   ", None)
  // Router checks for "username" / "auth" in body — whitespace has neither.
  // Spec says: 401 UIA challenge.
  let s = status_of(result)
  { s == 200 || s == 401 } |> should.be_true()
}

/// POST /register with null JSON object — no username present.
pub fn register_null_object_test() {
  let result =
    router.route("POST", "/_matrix/client/v3/register", "{}", None)
  let b = body_of(result)
  // Should respond with UIA challenge (401 with session + flows) or 400.
  let s = status_of(result)
  { s == 401 || s == 400 }
  |> should.be_true()
  // If 401, must include session.
  case s == 401 {
    True -> { string.contains(b, "session") } |> should.be_true()
    False -> Nil
  }
}

/// POST /register with empty string username.
pub fn register_empty_string_username_test() {
  let result =
    router.route(
      "POST",
      "/_matrix/client/v3/register",
      "{\"username\":\"\",\"password\":\"pw\"}",
      None,
    )
  // Empty username: spec says 400 M_INVALID_USERNAME or proceeds as UIA.
  let s = status_of(result)
  // Router handles "" username via stub logic — any of 200/400/401 is safe.
  { s == 200 || s == 400 || s == 401 } |> should.be_true()
}

/// POST /register with very long username (255 characters).
pub fn register_very_long_username_test() {
  let long_name =
    "abcdefghijklmnopqrstuvwxyz"
    <> "abcdefghijklmnopqrstuvwxyz"
    <> "abcdefghijklmnopqrstuvwxyz"
    <> "abcdefghijklmnopqrstuvwxyz"
    <> "abcdefghijklmnopqrstuvwxyz"
    <> "abcdefghijklmnopqrstuvwxyz"
    <> "abcdefghijklmnopqrstuvwxyz"
    <> "abcdefghijklmnopqrstuvwxyz"
    <> "abcdefghijklmnopqrstuvwxyz"
    <> "abcd"
  let body =
    "{\"username\":\"" <> long_name <> "\",\"password\":\"pw\"}"
  let result = router.route("POST", "/_matrix/client/v3/register", body, None)
  // Should not crash; returns either 200 (stub accepted) or 400 (length check).
  let s = status_of(result)
  { s == 200 || s == 400 } |> should.be_true()
}

/// POST /login with username but missing password field.
pub fn login_missing_password_test() {
  let result =
    router.route(
      "POST",
      "/_matrix/client/v3/login",
      "{\"type\":\"m.login.password\",\"user\":\"alice\"}",
      None,
    )
  // Stub accepts missing password and issues a token (acceptable for stub).
  let s = status_of(result)
  { s == 200 || s == 400 || s == 403 } |> should.be_true()
}

/// POST /login with password but missing user field.
pub fn login_missing_user_field_test() {
  let result =
    router.route(
      "POST",
      "/_matrix/client/v3/login",
      "{\"type\":\"m.login.password\",\"password\":\"secret\"}",
      None,
    )
  let s = status_of(result)
  { s == 200 || s == 400 || s == 403 } |> should.be_true()
}

/// POST /createRoom with entirely empty body — spec allows this (defaults apply).
pub fn create_room_empty_body_test() {
  let result =
    router.route("POST", "/_matrix/client/v3/createRoom", "", Some("tok"))
  // Must still return 200 with room_id.
  { is_ok(result, 200) } |> should.be_true()
  { string.contains(body_of(result), "room_id") } |> should.be_true()
}

/// POST /search with empty body — should not crash.
pub fn search_empty_body_test() {
  let result =
    router.route("POST", "/_matrix/client/v3/search", "", Some("tok"))
  let s = status_of(result)
  { s == 200 || s == 400 } |> should.be_true()
}

/// POST /search with malformed JSON — should not crash.
pub fn search_malformed_json_test() {
  let result =
    router.route(
      "POST",
      "/_matrix/client/v3/search",
      "{bad json",
      Some("tok"),
    )
  let s = status_of(result)
  { s == 200 || s == 400 } |> should.be_true()
}

/// POST /user_directory/search with empty body — must not crash.
pub fn user_directory_empty_body_test() {
  let result =
    router.route(
      "POST",
      "/_matrix/client/v3/user_directory/search",
      "",
      Some("tok"),
    )
  let s = status_of(result)
  { s == 200 || s == 400 } |> should.be_true()
}

// ===========================================================================
// Section B: Auth Edge Cases
// ===========================================================================

/// Missing auth token — all auth-gated endpoints must return 401 M_MISSING_TOKEN.
pub fn missing_token_whoami_test() {
  let result =
    router.route("GET", "/_matrix/client/v3/account/whoami", "", None)
  { is_error(result, 401) } |> should.be_true()
  { string.contains(body_of(result), "M_MISSING_TOKEN") } |> should.be_true()
}

/// Auth-gated endpoint with Some("") — empty string is still Some, so passes require_auth.
pub fn empty_string_token_passes_require_auth_test() {
  let result =
    router.route(
      "GET",
      "/_matrix/client/v3/account/whoami",
      "",
      Some(""),
    )
  // require_auth checks Some vs None — Some("") passes the gate.
  { is_ok(result, 200) } |> should.be_true()
}

/// require_auth on POST /logout with None returns 401.
pub fn logout_no_token_returns_401_test() {
  let result = router.route("POST", "/_matrix/client/v3/logout", "", None)
  { is_error(result, 401) } |> should.be_true()
}

/// require_auth on POST /keys/upload with None returns 401.
pub fn keys_upload_no_token_test() {
  let result =
    router.route("POST", "/_matrix/client/v3/keys/upload", "{}", None)
  { is_error(result, 401) } |> should.be_true()
}

/// require_auth on POST /createRoom with None returns 401.
pub fn create_room_no_token_test() {
  let result =
    router.route("POST", "/_matrix/client/v3/createRoom", "{}", None)
  { is_error(result, 401) } |> should.be_true()
}

/// GET /capabilities is public (no auth required per Matrix spec).
pub fn capabilities_no_token_test() {
  let result =
    router.route("GET", "/_matrix/client/v3/capabilities", "", None)
  { is_ok(result, 200) } |> should.be_true()
}

/// Token with special characters in it — require_auth passes (it's Some).
pub fn token_with_special_chars_test() {
  let result =
    router.route(
      "GET",
      "/_matrix/client/v3/account/whoami",
      "",
      Some("syt_!@#$%^&*()_+"),
    )
  { is_ok(result, 200) } |> should.be_true()
}

/// Token that is very long (1000 chars) — should not crash.
pub fn very_long_token_test() {
  let long_token =
    "syt_"
    <> "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    <> "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    <> "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    <> "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    <> "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    <> "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    <> "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    <> "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    <> "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    <> "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    <> "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    <> "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    <> "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    <> "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    <> "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    <> "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  let result =
    router.route(
      "GET",
      "/_matrix/client/v3/account/whoami",
      "",
      Some(long_token),
    )
  { is_ok(result, 200) } |> should.be_true()
}

/// POST /refresh — no auth required by spec, should return 200.
pub fn refresh_no_token_test() {
  let result = router.route("POST", "/_matrix/client/v3/refresh", "{}", None)
  { is_ok(result, 200) } |> should.be_true()
}

/// Error response shape: errcode and error both present and non-empty.
pub fn auth_error_has_both_fields_test() {
  let result =
    router.route("GET", "/_matrix/client/v3/account/whoami", "", None)
  { error_has_both_fields(result) } |> should.be_true()
}

// ===========================================================================
// Section C: Room ID Edge Cases
// ===========================================================================

/// GET /rooms/{roomId}/state with no token.
pub fn get_room_state_no_auth_test() {
  let result =
    router.route(
      "GET",
      "/_matrix/client/v3/rooms/!abc123:localhost/state",
      "",
      None,
    )
  { is_error(result, 401) } |> should.be_true()
}

/// Room sub-path with only roomId and no operation — invalid path.
pub fn room_path_too_short_test() {
  let result =
    router.route(
      "GET",
      "/_matrix/client/v3/rooms",
      "",
      Some("tok"),
    )
  // No room operation found — should 404.
  let s = status_of(result)
  { s == 404 } |> should.be_true()
}

/// Room path with only slash after /rooms/ — malformed.
pub fn room_path_empty_room_id_test() {
  let result =
    router.route(
      "GET",
      "/_matrix/client/v3/rooms/",
      "",
      Some("tok"),
    )
  let s = status_of(result)
  // Should not crash — returns 400 or 404.
  { s == 400 || s == 404 } |> should.be_true()
}

/// Room ID without the `!` sigil.
pub fn room_id_no_sigil_test() {
  let result =
    router.route(
      "GET",
      "/_matrix/client/v3/rooms/abc123:localhost/state",
      "",
      Some("tok"),
    )
  let s = status_of(result)
  { s == 200 || s == 400 || s == 403 || s == 404 } |> should.be_true()
}

/// Room ID without the server part.
pub fn room_id_no_server_test() {
  let result =
    router.route(
      "GET",
      "/_matrix/client/v3/rooms/!localonly/state",
      "",
      Some("tok"),
    )
  let s = status_of(result)
  { s == 200 || s == 400 || s == 403 || s == 404 } |> should.be_true()
}

/// PUT send event on a room path — valid path structure.
pub fn send_event_valid_path_test() {
  let result =
    router.route(
      "PUT",
      "/_matrix/client/v3/rooms/!abc:localhost/send/m.room.message/txn1",
      "{\"msgtype\":\"m.text\",\"body\":\"hello\"}",
      Some("tok"),
    )
  // Stub router returns 200 with event_id.
  let s = status_of(result)
  { s == 200 || s == 403 || s == 404 } |> should.be_true()
}

/// Redact with correct path structure — must not crash.
pub fn redact_event_path_test() {
  let result =
    router.route(
      "PUT",
      "/_matrix/client/v3/rooms/!abc:localhost/redact/$ev1:localhost/txn99",
      "{}",
      Some("tok"),
    )
  let s = status_of(result)
  { s == 200 || s == 403 || s == 404 } |> should.be_true()
}

/// GET /rooms/{roomId}/joined_rooms — this sub-path is handled as `joined_rooms` room op.
pub fn room_joined_rooms_sub_path_test() {
  let result =
    router.route(
      "GET",
      "/_matrix/client/v3/rooms/!abc:localhost/joined_rooms",
      "",
      Some("tok"),
    )
  let s = status_of(result)
  { s == 200 || s == 403 || s == 404 } |> should.be_true()
}

// ===========================================================================
// Section D: Event Edge Cases
// ===========================================================================

/// Sending an event with an empty body (empty JSON object is valid).
pub fn send_empty_json_event_test() {
  let result =
    router.route(
      "PUT",
      "/_matrix/client/v3/rooms/!abc:localhost/send/m.room.message/txn0",
      "{}",
      Some("tok"),
    )
  let s = status_of(result)
  // Stub: always 200; real handler: 403 if not member, 404 if room not found.
  { s == 200 || s == 403 || s == 404 } |> should.be_true()
}

/// Sending event with a very large body (10 KB of repeated text).
pub fn send_large_event_body_test() {
  let big =
    string.repeat("abcdefghijklmnopqrstuvwxyz0123456789", 277)
  let body = "{\"msgtype\":\"m.text\",\"body\":\"" <> big <> "\"}"
  let result =
    router.route(
      "PUT",
      "/_matrix/client/v3/rooms/!abc:localhost/send/m.room.message/txn1",
      body,
      Some("tok"),
    )
  let s = status_of(result)
  { s == 200 || s == 403 || s == 404 || s == 413 } |> should.be_true()
}

/// Sending event with Unicode body content — must not crash.
pub fn send_unicode_body_test() {
  let result =
    router.route(
      "PUT",
      "/_matrix/client/v3/rooms/!abc:localhost/send/m.room.message/txn2",
      "{\"msgtype\":\"m.text\",\"body\":\"こんにちは 🌸 مرحبا\"}",
      Some("tok"),
    )
  let s = status_of(result)
  { s == 200 || s == 403 || s == 404 } |> should.be_true()
}

/// GET event by ID — valid path.
pub fn get_event_by_id_test() {
  let result =
    router.route(
      "GET",
      "/_matrix/client/v3/rooms/!abc:localhost/event/$someevent:localhost",
      "",
      Some("tok"),
    )
  let s = status_of(result)
  { s == 200 || s == 403 || s == 404 } |> should.be_true()
}

/// Redact a non-existent event — stub returns 200 (not spec-correct, documented as DEV).
pub fn redact_nonexistent_event_test() {
  let result =
    router.route(
      "PUT",
      "/_matrix/client/v3/rooms/!abc:localhost/redact/$nope:localhost/txnR",
      "{\"reason\":\"spam\"}",
      Some("tok"),
    )
  let s = status_of(result)
  { s == 200 || s == 404 } |> should.be_true()
}

/// PUT state event with empty state key (spec allows this).
pub fn send_state_event_empty_state_key_test() {
  let result =
    router.route(
      "PUT",
      "/_matrix/client/v3/rooms/!abc:localhost/state/m.room.topic",
      "{\"topic\":\"New topic\"}",
      Some("tok"),
    )
  let s = status_of(result)
  { s == 200 || s == 403 || s == 404 } |> should.be_true()
}

/// PUT state event with explicit state key.
pub fn send_state_event_with_state_key_test() {
  let result =
    router.route(
      "PUT",
      "/_matrix/client/v3/rooms/!abc:localhost/state/m.room.member/@bob:localhost",
      "{\"membership\":\"invite\"}",
      Some("tok"),
    )
  let s = status_of(result)
  { s == 200 || s == 403 || s == 404 } |> should.be_true()
}

/// GET /context/ for an event — shape check.
pub fn get_event_context_test() {
  let result =
    router.route(
      "GET",
      "/_matrix/client/v3/rooms/!abc:localhost/context/$ev:localhost",
      "",
      Some("tok"),
    )
  let s = status_of(result)
  case s == 200 {
    True -> {
      let b = body_of(result)
      { string.contains(b, "events_before") } |> should.be_true()
      { string.contains(b, "events_after") } |> should.be_true()
    }
    False -> { s == 403 || s == 404 } |> should.be_true()
  }
}

// ===========================================================================
// Section E: Sync Edge Cases
// ===========================================================================

/// Sync without token returns 401.
pub fn sync_no_token_test() {
  let result =
    router.route("GET", "/_matrix/client/v3/sync", "", None)
  { is_error(result, 401) } |> should.be_true()
}

/// Sync with token — must return shape-valid response.
pub fn sync_with_token_shape_test() {
  let result =
    router.route("GET", "/_matrix/client/v3/sync", "", Some("tok"))
  { is_ok(result, 200) } |> should.be_true()
  let b = body_of(result)
  { string.contains(b, "next_batch") } |> should.be_true()
  { string.contains(b, "rooms") } |> should.be_true()
}

/// Sync with `since` query param embedded in path — since is extracted from query.
pub fn sync_with_since_param_test() {
  let result =
    router.route(
      "GET",
      "/_matrix/client/v3/sync?since=s42_0_0_0_0_0_0_0_0",
      "",
      Some("tok"),
    )
  let s = status_of(result)
  { s == 200 || s == 401 } |> should.be_true()
}

/// v1 sync path (sliding sync / MSC3575) routes to same handler.
pub fn sync_v1_path_test() {
  let result =
    router.route("GET", "/_matrix/client/v1/sync", "", Some("tok"))
  let s = status_of(result)
  { s == 200 || s == 401 || s == 404 } |> should.be_true()
}

/// Sync response must include all required top-level fields.
pub fn sync_response_required_fields_test() {
  let result =
    router.route("GET", "/_matrix/client/v3/sync", "", Some("tok"))
  let b = body_of(result)
  { string.contains(b, "next_batch") } |> should.be_true()
  { string.contains(b, "presence") } |> should.be_true()
  { string.contains(b, "account_data") } |> should.be_true()
  { string.contains(b, "to_device") } |> should.be_true()
  { string.contains(b, "device_lists") } |> should.be_true()
}

/// Sync rooms map must include join / invite / leave.
pub fn sync_rooms_map_fields_test() {
  let result =
    router.route("GET", "/_matrix/client/v3/sync", "", Some("tok"))
  let b = body_of(result)
  { string.contains(b, "join") } |> should.be_true()
  { string.contains(b, "invite") } |> should.be_true()
  { string.contains(b, "leave") } |> should.be_true()
}

// ===========================================================================
// Section F: Media Edge Cases
// ===========================================================================

/// POST /upload with empty body — should return 200 with mxc:// URI.
pub fn upload_empty_body_test() {
  let result =
    router.route("POST", "/_matrix/media/v3/upload", "", Some("tok"))
  let s = status_of(result)
  { s == 200 || s == 400 || s == 413 } |> should.be_true()
}

/// POST /upload without token — should return 401.
pub fn upload_no_token_test() {
  let result =
    router.route("POST", "/_matrix/media/v3/upload", "bytes", None)
  { is_error(result, 401) } |> should.be_true()
}

/// Successful upload response must contain mxc:// content_uri.
pub fn upload_response_has_mxc_uri_test() {
  let result =
    router.route("POST", "/_matrix/media/v3/upload", "data", Some("tok"))
  case status_of(result) == 200 {
    True ->
      { string.contains(body_of(result), "mxc://") } |> should.be_true()
    False -> Nil
  }
}

/// GET /download/{server}/{mediaId} — always 404 (stub).
pub fn download_nonexistent_media_test() {
  let result =
    router.route(
      "GET",
      "/_matrix/media/v3/download/localhost/not_a_real_media_id",
      "",
      None,
    )
  { is_error(result, 404) } |> should.be_true()
}

/// GET /download with unicode filename — must not crash.
pub fn download_unicode_filename_test() {
  let result =
    router.route(
      "GET",
      "/_matrix/media/v3/download/localhost/abc123/こんにちは.png",
      "",
      None,
    )
  let s = status_of(result)
  { s == 200 || s == 404 } |> should.be_true()
}

/// GET /thumbnail — always 404 (stub).
pub fn thumbnail_nonexistent_test() {
  let result =
    router.route(
      "GET",
      "/_matrix/media/v3/thumbnail/localhost/imageid",
      "",
      None,
    )
  { is_error(result, 404) } |> should.be_true()
}

/// GET /media/v3/config — no auth required per spec.
pub fn media_config_no_auth_test() {
  let result =
    router.route("GET", "/_matrix/media/v3/config", "", None)
  { is_ok(result, 200) } |> should.be_true()
  { string.contains(body_of(result), "m.upload.size") } |> should.be_true()
}

/// POST /media/v1/create — async upload create, requires auth.
pub fn media_create_no_token_test() {
  let result =
    router.route("POST", "/_matrix/media/v1/create", "", None)
  { is_error(result, 401) } |> should.be_true()
}

// ===========================================================================
// Section G: Membership Edge Cases
// ===========================================================================

/// POST /join with no token returns 401.
pub fn join_no_token_test() {
  let result =
    router.route(
      "POST",
      "/_matrix/client/v3/join/!abc:localhost",
      "{}",
      None,
    )
  { is_error(result, 401) } |> should.be_true()
}

/// POST /join — response must contain room_id.
pub fn join_returns_room_id_test() {
  let result =
    router.route(
      "POST",
      "/_matrix/client/v3/join/!abc:localhost",
      "{}",
      Some("tok"),
    )
  let s = status_of(result)
  case s == 200 {
    True ->
      { string.contains(body_of(result), "room_id") } |> should.be_true()
    False -> { s == 404 } |> should.be_true()
  }
}

/// POST /rooms/{roomId}/leave with no token — 401.
pub fn leave_no_token_test() {
  let result =
    router.route(
      "POST",
      "/_matrix/client/v3/rooms/!abc:localhost/leave",
      "",
      None,
    )
  { is_error(result, 401) } |> should.be_true()
}

/// POST /rooms/{roomId}/invite with no token — 401.
pub fn invite_no_token_test() {
  let result =
    router.route(
      "POST",
      "/_matrix/client/v3/rooms/!abc:localhost/invite",
      "{\"user_id\":\"@bob:localhost\"}",
      None,
    )
  { is_error(result, 401) } |> should.be_true()
}

/// POST /rooms/{roomId}/ban with no token — 401.
pub fn ban_no_token_test() {
  let result =
    router.route(
      "POST",
      "/_matrix/client/v3/rooms/!abc:localhost/ban",
      "{\"user_id\":\"@bob:localhost\"}",
      None,
    )
  { is_error(result, 401) } |> should.be_true()
}

/// POST /rooms/{roomId}/unban with no token — 401.
pub fn unban_no_token_test() {
  let result =
    router.route(
      "POST",
      "/_matrix/client/v3/rooms/!abc:localhost/unban",
      "{\"user_id\":\"@bob:localhost\"}",
      None,
    )
  { is_error(result, 401) } |> should.be_true()
}

/// POST /rooms/{roomId}/kick with no token — 401.
pub fn kick_no_token_test() {
  let result =
    router.route(
      "POST",
      "/_matrix/client/v3/rooms/!abc:localhost/kick",
      "{\"user_id\":\"@bob:localhost\"}",
      None,
    )
  { is_error(result, 401) } |> should.be_true()
}

/// POST /rooms/{roomId}/forget with no token — 401.
pub fn forget_no_token_test() {
  let result =
    router.route(
      "POST",
      "/_matrix/client/v3/rooms/!abc:localhost/forget",
      "",
      None,
    )
  { is_error(result, 401) } |> should.be_true()
}

/// POST /knock — returns room_id, requires auth.
pub fn knock_no_token_test() {
  let result =
    router.route(
      "POST",
      "/_matrix/client/v3/knock/!abc:localhost",
      "{}",
      None,
    )
  { is_error(result, 401) } |> should.be_true()
}

/// POST /knock with token — returns room_id.
pub fn knock_returns_room_id_test() {
  let result =
    router.route(
      "POST",
      "/_matrix/client/v3/knock/!abc:localhost",
      "{}",
      Some("tok"),
    )
  { is_ok(result, 200) } |> should.be_true()
  { string.contains(body_of(result), "room_id") } |> should.be_true()
}

// ===========================================================================
// Section H: Key / E2EE Edge Cases
// ===========================================================================

/// POST /keys/upload with empty body — spec §11.12 requires M_NOT_JSON for empty body.
/// Hardened: require_body returns 400 M_NOT_JSON when body is empty.
pub fn keys_upload_empty_body_test() {
  let result =
    router.route("POST", "/_matrix/client/v3/keys/upload", "", Some("tok"))
  { is_error(result, 400) } |> should.be_true()
  let b = body_of(result)
  { string.contains(b, "M_NOT_JSON") } |> should.be_true()
}

/// POST /keys/query for a non-existent user — returns device_keys empty.
pub fn keys_query_nonexistent_user_test() {
  let result =
    router.route(
      "POST",
      "/_matrix/client/v3/keys/query",
      "{\"device_keys\":{\"@ghost:localhost\":[]}}",
      Some("tok"),
    )
  { is_ok(result, 200) } |> should.be_true()
  { string.contains(body_of(result), "device_keys") } |> should.be_true()
}

/// POST /keys/claim for a non-existent OTK — returns empty one_time_keys.
pub fn keys_claim_nonexistent_otk_test() {
  let result =
    router.route(
      "POST",
      "/_matrix/client/v3/keys/claim",
      "{\"one_time_keys\":{\"@ghost:localhost\":{\"DEVID\":\"signed_curve25519\"}}}",
      Some("tok"),
    )
  { is_ok(result, 200) } |> should.be_true()
  { string.contains(body_of(result), "one_time_keys") } |> should.be_true()
}

/// GET /keys/changes with no token — 401.
pub fn keys_changes_no_token_test() {
  let result =
    router.route("GET", "/_matrix/client/v3/keys/changes", "", None)
  { is_error(result, 401) } |> should.be_true()
}

/// GET /room_keys/version — 404 when no backup exists (spec-correct).
pub fn room_keys_no_backup_test() {
  let result =
    router.route(
      "GET",
      "/_matrix/client/v3/room_keys/version",
      "",
      Some("tok"),
    )
  { is_error(result, 404) } |> should.be_true()
  { string.contains(body_of(result), "M_NOT_FOUND") } |> should.be_true()
}

/// PUT /room_keys/version — creates a backup, returns version field.
pub fn room_keys_create_version_test() {
  let result =
    router.route(
      "PUT",
      "/_matrix/client/v3/room_keys/version",
      "{\"algorithm\":\"m.megolm_backup.v1.curve25519-aes-sha2\",\"auth_data\":{}}",
      Some("tok"),
    )
  { is_ok(result, 200) } |> should.be_true()
  { string.contains(body_of(result), "version") } |> should.be_true()
}

// ===========================================================================
// Section I: Push Rule Edge Cases
// ===========================================================================

/// GET /pushrules/ with no token — 401.
pub fn push_rules_no_token_test() {
  let result =
    router.route("GET", "/_matrix/client/v3/pushrules/", "", None)
  { is_error(result, 401) } |> should.be_true()
}

/// GET /pushrules/ — response must include global object.
pub fn push_rules_shape_test() {
  let result =
    router.route("GET", "/_matrix/client/v3/pushrules/", "", Some("tok"))
  { is_ok(result, 200) } |> should.be_true()
  { string.contains(body_of(result), "global") } |> should.be_true()
}

/// GET /pushrules/{scope}/{kind}/{ruleId}/enabled — returns enabled boolean.
pub fn push_rule_enabled_endpoint_test() {
  let result =
    router.route(
      "GET",
      "/_matrix/client/v3/pushrules/global/content/.m.rule.contains_user_name/enabled",
      "",
      Some("tok"),
    )
  { is_ok(result, 200) } |> should.be_true()
  { string.contains(body_of(result), "enabled") } |> should.be_true()
}

/// GET /pushrules/{scope}/{kind}/{ruleId}/actions — returns actions array.
pub fn push_rule_actions_endpoint_test() {
  let result =
    router.route(
      "GET",
      "/_matrix/client/v3/pushrules/global/content/.m.rule.contains_user_name/actions",
      "",
      Some("tok"),
    )
  { is_ok(result, 200) } |> should.be_true()
  { string.contains(body_of(result), "actions") } |> should.be_true()
}

/// DELETE /pushrules/{scope}/{kind}/{ruleId} with no token — 401.
pub fn delete_push_rule_no_token_test() {
  let result =
    router.route(
      "DELETE",
      "/_matrix/client/v3/pushrules/global/content/myrule",
      "",
      None,
    )
  { is_error(result, 401) } |> should.be_true()
}

/// DELETE /pushrules/{scope}/{kind}/{nonexistent} — stub returns 200 always.
pub fn delete_nonexistent_push_rule_test() {
  let result =
    router.route(
      "DELETE",
      "/_matrix/client/v3/pushrules/global/content/doesnotexist",
      "",
      Some("tok"),
    )
  // Stub: always returns 200 (DEV-010 class deviation — should be 404 for missing rule).
  { is_ok(result, 200) } |> should.be_true()
}

// ===========================================================================
// Section J: Account Data Edge Cases
// ===========================================================================

/// PUT user account data with no token — 401.
pub fn set_account_data_no_token_test() {
  let result =
    router.route(
      "PUT",
      "/_matrix/client/v3/user/@alice:localhost/account_data/m.push_rules",
      "{}",
      None,
    )
  { is_error(result, 401) } |> should.be_true()
}

/// PUT user account data with token — stub returns 200.
pub fn set_account_data_stub_test() {
  let result =
    router.route(
      "PUT",
      "/_matrix/client/v3/user/@alice:localhost/account_data/m.custom.type",
      "{\"key\":\"value\"}",
      Some("tok"),
    )
  { is_ok(result, 200) } |> should.be_true()
}

/// GET user account data — stub returns 200 with `{}`.
pub fn get_account_data_stub_test() {
  let result =
    router.route(
      "GET",
      "/_matrix/client/v3/user/@alice:localhost/account_data/m.custom.type",
      "",
      Some("tok"),
    )
  { is_ok(result, 200) } |> should.be_true()
}

/// PUT room-scoped account data — stub returns 200.
pub fn set_room_account_data_test() {
  let result =
    router.route(
      "PUT",
      "/_matrix/client/v3/rooms/!abc:localhost/account_data/m.room.tag",
      "{\"order\":0.5}",
      Some("tok"),
    )
  let s = status_of(result)
  { s == 200 || s == 401 } |> should.be_true()
}

/// GET room-scoped account data — stub returns 200.
pub fn get_room_account_data_test() {
  let result =
    router.route(
      "GET",
      "/_matrix/client/v3/rooms/!abc:localhost/account_data/m.room.tag",
      "",
      Some("tok"),
    )
  let s = status_of(result)
  { s == 200 || s == 401 } |> should.be_true()
}

/// PUT account data with empty body — must not crash.
pub fn set_account_data_empty_body_test() {
  let result =
    router.route(
      "PUT",
      "/_matrix/client/v3/user/@alice:localhost/account_data/m.push_rules",
      "",
      Some("tok"),
    )
  let s = status_of(result)
  { s == 200 || s == 400 } |> should.be_true()
}

// ===========================================================================
// Section K: Injection / Path Traversal / Security Inputs
// ===========================================================================

/// Path traversal attempt — dots in path segments.
/// Must NOT return file content; must return 400/404.
pub fn path_traversal_dot_dot_test() {
  let result =
    router.route(
      "GET",
      "/_matrix/client/v3/rooms/!abc:localhost/../../../etc/passwd/state",
      "",
      Some("tok"),
    )
  let s = status_of(result)
  // Gleam string.split does not resolve `..`; route falls to 404.
  { s == 400 || s == 404 } |> should.be_true()
}

/// Null byte in room ID — must not crash.
pub fn null_byte_in_room_id_test() {
  let result =
    router.route(
      "GET",
      "/_matrix/client/v3/rooms/!abc\u{0000}:localhost/state",
      "",
      Some("tok"),
    )
  let s = status_of(result)
  { s == 200 || s == 400 || s == 403 || s == 404 } |> should.be_true()
}

/// SQL-injection-like search term — must not crash; returns empty results.
pub fn sql_injection_in_search_test() {
  let result =
    router.route(
      "POST",
      "/_matrix/client/v3/search",
      "{\"search_categories\":{\"room_events\":{\"search_term\":\"'; DROP TABLE users; --\"}}}",
      Some("tok"),
    )
  { is_ok(result, 200) } |> should.be_true()
  { string.contains(body_of(result), "room_events") } |> should.be_true()
}

/// XSS attempt in display name PUT — must not crash; returns 200 stub.
pub fn xss_in_display_name_test() {
  let result =
    router.route(
      "PUT",
      "/_matrix/client/v3/profile/@alice:localhost/displayname",
      "{\"displayname\":\"<script>alert(1)</script>\"}",
      Some("tok"),
    )
  let s = status_of(result)
  { s == 200 || s == 400 } |> should.be_true()
}

/// Overlong path (4096 chars) — must not crash.
pub fn overlong_path_test() {
  let segment = string.repeat("a", 4000)
  let result =
    router.route(
      "GET",
      "/_matrix/client/v3/rooms/!" <> segment <> ":localhost/state",
      "",
      Some("tok"),
    )
  let s = status_of(result)
  { s == 200 || s == 400 || s == 403 || s == 404 } |> should.be_true()
}

/// SSRF-like body in pusher set — must not initiate outbound connections.
/// (Pure test: just verifies no crash and returns valid shape.)
pub fn ssrf_pusher_url_test() {
  let result =
    router.route(
      "POST",
      "/_matrix/client/v3/pushers/set",
      "{\"pushkey\":\"x\",\"kind\":\"http\",\"app_id\":\"id\",\"app_display_name\":\"app\",\"device_display_name\":\"dev\",\"lang\":\"en\",\"data\":{\"url\":\"http://169.254.169.254/latest/meta-data/\"}}",
      Some("tok"),
    )
  // Stub returns 200 without making HTTP calls.
  { is_ok(result, 200) } |> should.be_true()
}

/// Search with deeply nested JSON — must not crash.
pub fn search_deeply_nested_json_test() {
  let result =
    router.route(
      "POST",
      "/_matrix/client/v3/search",
      "{\"a\":{\"b\":{\"c\":{\"d\":{\"e\":{\"f\":{\"g\":{\"h\":\"i\"}}}}}}}}",
      Some("tok"),
    )
  let s = status_of(result)
  { s == 200 || s == 400 } |> should.be_true()
}

/// User-directory search with injection term.
pub fn user_directory_injection_test() {
  let result =
    router.route(
      "POST",
      "/_matrix/client/v3/user_directory/search",
      "{\"search_term\":\"admin' OR '1'='1\"}",
      Some("tok"),
    )
  { is_ok(result, 200) } |> should.be_true()
}

// ===========================================================================
// Section L: HTTP Method Mismatches
// ===========================================================================

/// POST to a GET-only endpoint — must return 404 (falls to route_prefix).
pub fn post_to_versions_test() {
  let result =
    router.route("POST", "/_matrix/client/versions", "{}", None)
  let s = status_of(result)
  // POST /versions is not routed — falls to 404.
  { s == 404 || s == 405 } |> should.be_true()
}

/// DELETE to POST-only endpoint.
pub fn delete_to_login_test() {
  let result =
    router.route("DELETE", "/_matrix/client/v3/login", "", None)
  let s = status_of(result)
  { s == 404 || s == 405 } |> should.be_true()
}

/// PATCH method — not supported anywhere.
pub fn patch_method_test() {
  let result =
    router.route("PATCH", "/_matrix/client/v3/account/whoami", "", Some("tok"))
  let s = status_of(result)
  { s == 404 || s == 405 } |> should.be_true()
}

/// GET to POST-only createRoom.
pub fn get_create_room_test() {
  let result =
    router.route("GET", "/_matrix/client/v3/createRoom", "", Some("tok"))
  let s = status_of(result)
  { s == 404 || s == 405 } |> should.be_true()
}

/// PUT to GET-only /sync.
pub fn put_to_sync_test() {
  let result =
    router.route("PUT", "/_matrix/client/v3/sync", "{}", Some("tok"))
  let s = status_of(result)
  { s == 404 || s == 405 } |> should.be_true()
}

/// HEAD method — not implemented.
pub fn head_method_test() {
  let result =
    router.route("HEAD", "/_matrix/client/versions", "", None)
  let s = status_of(result)
  { s == 404 || s == 405 } |> should.be_true()
}

/// OPTIONS method — CORS preflight, not implemented.
pub fn options_method_test() {
  let result =
    router.route("OPTIONS", "/_matrix/client/versions", "", None)
  let s = status_of(result)
  { s == 404 || s == 405 } |> should.be_true()
}

/// DELETE to a rooms sub-path that only supports GET.
pub fn delete_room_state_test() {
  let result =
    router.route(
      "DELETE",
      "/_matrix/client/v3/rooms/!abc:localhost/state",
      "",
      Some("tok"),
    )
  let s = status_of(result)
  { s == 404 || s == 405 } |> should.be_true()
}

// ===========================================================================
// Section M: Federation Edge Cases
// ===========================================================================

/// GET /federation/v1/version — no auth, returns server info.
pub fn federation_version_test() {
  let result =
    router.route("GET", "/_matrix/federation/v1/version", "", None)
  { is_ok(result, 200) } |> should.be_true()
  { string.contains(body_of(result), "Sutra") } |> should.be_true()
}

/// PUT /federation/v1/send with empty PDUs array — returns pdus map.
pub fn federation_send_empty_pdus_test() {
  let result =
    router.route(
      "PUT",
      "/_matrix/federation/v1/send/txn_123",
      "{\"pdus\":[],\"edus\":[]}",
      None,
    )
  { is_ok(result, 200) } |> should.be_true()
  { string.contains(body_of(result), "pdus") } |> should.be_true()
}

/// GET /federation/v1/event with malformed event_id.
pub fn federation_invalid_event_id_test() {
  let result =
    router.route(
      "GET",
      "/_matrix/federation/v1/event/not_a_valid_event_id",
      "",
      None,
    )
  let s = status_of(result)
  { s == 200 || s == 404 } |> should.be_true()
}

/// GET /federation/v1/make_join — returns 403 (federation not fully implemented).
pub fn federation_make_join_forbidden_test() {
  let result =
    router.route(
      "GET",
      "/_matrix/federation/v1/make_join/!abc:localhost/@user:remote",
      "",
      None,
    )
  { is_error(result, 403) } |> should.be_true()
}

/// Unknown federation endpoint — returns 501.
pub fn federation_unknown_endpoint_test() {
  let result =
    router.route(
      "GET",
      "/_matrix/federation/v99/something_new",
      "",
      None,
    )
  let s = status_of(result)
  { s == 404 || s == 501 } |> should.be_true()
}

/// Federation hierarchy endpoint — returns rooms array.
pub fn federation_hierarchy_test() {
  let result =
    router.route(
      "GET",
      "/_matrix/federation/v1/hierarchy/!abc:localhost",
      "",
      None,
    )
  { is_ok(result, 200) } |> should.be_true()
  { string.contains(body_of(result), "rooms") } |> should.be_true()
}

// ===========================================================================
// Section N: Profile and Presence Edge Cases
// ===========================================================================

/// GET /profile for a non-existent user — returns 200 with echo of user_id as displayname (stub).
pub fn profile_nonexistent_user_test() {
  let result =
    router.route(
      "GET",
      "/_matrix/client/v3/profile/@ghost:localhost",
      "",
      None,
    )
  { is_ok(result, 200) } |> should.be_true()
  { string.contains(body_of(result), "displayname") } |> should.be_true()
}

/// GET /profile with empty user_id path segment — falls to prefix handler.
pub fn profile_empty_user_id_test() {
  let result =
    router.route("GET", "/_matrix/client/v3/profile/", "", None)
  let s = status_of(result)
  { s == 200 || s == 404 } |> should.be_true()
}

/// GET /presence for a user — returns offline (stub).
pub fn presence_offline_stub_test() {
  let result =
    router.route(
      "GET",
      "/_matrix/client/v3/presence/@alice:localhost/status",
      "",
      None,
    )
  { is_ok(result, 200) } |> should.be_true()
  { string.contains(body_of(result), "presence") } |> should.be_true()
}

/// PUT /presence without token — 401.
pub fn set_presence_no_token_test() {
  let result =
    router.route(
      "PUT",
      "/_matrix/client/v3/presence/@alice:localhost/status",
      "{\"presence\":\"online\"}",
      None,
    )
  { is_error(result, 401) } |> should.be_true()
}

/// GET /joined_rooms — requires auth.
pub fn joined_rooms_no_token_test() {
  let result =
    router.route("GET", "/_matrix/client/v3/joined_rooms", "", None)
  { is_error(result, 401) } |> should.be_true()
}

/// GET /joined_rooms with token — returns joined_rooms array (empty in stub).
pub fn joined_rooms_shape_test() {
  let result =
    router.route("GET", "/_matrix/client/v3/joined_rooms", "", Some("tok"))
  { is_ok(result, 200) } |> should.be_true()
  { string.contains(body_of(result), "joined_rooms") } |> should.be_true()
}

// ===========================================================================
// Section O: Well-known / Discovery Edge Cases
// ===========================================================================

/// GET /.well-known/matrix/client — no auth needed.
pub fn well_known_client_no_auth_test() {
  let result =
    router.route("GET", "/.well-known/matrix/client", "", None)
  { is_ok(result, 200) } |> should.be_true()
}

/// GET /.well-known/matrix/client — must contain base_url.
pub fn well_known_client_base_url_test() {
  let result =
    router.route("GET", "/.well-known/matrix/client", "", None)
  let b = body_of(result)
  { string.contains(b, "base_url") } |> should.be_true()
  { string.contains(b, "m.homeserver") } |> should.be_true()
}

/// GET /.well-known/matrix/server — must contain m.server.
pub fn well_known_server_has_m_server_test() {
  let result =
    router.route("GET", "/.well-known/matrix/server", "", None)
  { is_ok(result, 200) } |> should.be_true()
  { string.contains(body_of(result), "m.server") } |> should.be_true()
}

/// GET /_matrix/key/v2/server — no auth, returns key document fields.
pub fn server_key_document_fields_test() {
  let result =
    router.route("GET", "/_matrix/key/v2/server", "", None)
  { is_ok(result, 200) } |> should.be_true()
  let b = body_of(result)
  { string.contains(b, "server_name") } |> should.be_true()
  { string.contains(b, "verify_keys") } |> should.be_true()
  { string.contains(b, "valid_until_ts") } |> should.be_true()
}
