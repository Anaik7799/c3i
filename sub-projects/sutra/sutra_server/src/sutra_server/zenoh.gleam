//// zenoh — Full Zenoh pub/sub mesh integration for Sutra Matrix server.
//// Publishes ALL Matrix events, OTel spans, and telemetry to Indrajaal mesh.
//// Enables closed-loop testing: Patrol → FluffyChat → Sutra → Zenoh → Patrol.
////
//// 30 Zenoh Topic Namespaces:
////   indrajaal/sutra/span/{method}/{status}     — OTel request spans (auto)
////   indrajaal/sutra/req/{method}/{path}        — request telemetry
////   indrajaal/sutra/event/{type}               — Matrix event telemetry
////   indrajaal/sutra/health                     — server health pings
////   indrajaal/sutra/auth/{action}              — login/register/logout
////   indrajaal/sutra/room/{action}              — create/join/leave/invite
////   indrajaal/sutra/message/sent               — messages
////   indrajaal/sutra/e2ee/{action}              — keys upload/query/claim/cross-sign
////   indrajaal/sutra/sync/{user}                — sync events
////   indrajaal/sutra/typing/{room}              — typing indicators
////   indrajaal/sutra/presence/{user}            — presence updates
////   indrajaal/sutra/receipt/{room}             — read receipts
////   indrajaal/sutra/device/{action}            — device management
////   indrajaal/sutra/media/{action}             — media upload/download
////   indrajaal/sutra/search                     — search queries
////   indrajaal/sutra/state/{room}/{type}        — room state events
////   indrajaal/sutra/membership/{room}          — membership changes
////   indrajaal/sutra/push/{action}              — push rules/notifications
////   indrajaal/sutra/account_data/{user}        — account data changes
////   indrajaal/sutra/directory/{action}         — room directory
////   indrajaal/sutra/federation/{action}        — federation events
////   indrajaal/sutra/admin/{action}             — admin operations
////   indrajaal/sutra/backup/{action}            — key backup
////   indrajaal/sutra/to_device/{type}           — to-device messages
////   indrajaal/sutra/filter/{action}            — filter operations
////   indrajaal/sutra/profile/{action}           — profile changes
////   indrajaal/sutra/capabilities               — capabilities queries
////   indrajaal/sutra/sliding_sync               — MSC3575 sliding sync
////   indrajaal/test/sutra/{test}                — closed-loop test observations
////   indrajaal/sutra/stats                      — NIF statistics
////
//// STAMP: SC-ZMOF-001, SC-GLM-ZEN-001, SC-ZMOF-COMMS-001

import gleam/json
import gleam/list
import gleam/string

// ═══════════════════════════════════════════════════════════════════════
// NIF BINDINGS — Session Management
// ═══════════════════════════════════════════════════════════════════════

/// Open a zenoh session. Mode: "peer" (standalone) or "client" (router).
@external(erlang, "zenoh_ffi", "zenoh_open")
pub fn open(mode: String) -> Result(String, String)

/// Check if zenoh session is currently open.
@external(erlang, "zenoh_ffi", "zenoh_is_open")
pub fn is_open() -> Bool

// ═══════════════════════════════════════════════════════════════════════
// NIF BINDINGS — Publish
// ═══════════════════════════════════════════════════════════════════════

/// Publish a value to a zenoh key expression.
@external(erlang, "zenoh_ffi", "zenoh_put")
pub fn put(key_expr: String, value: String) -> Result(String, String)

/// Publish a Matrix request span (OTel format).
@external(erlang, "zenoh_ffi", "zenoh_publish_span")
pub fn publish_span(
  method: String,
  path: String,
  status: Int,
  latency_ms: Int,
) -> Result(String, String)

/// Get zenoh NIF statistics (connected, puts, spans counts).
@external(erlang, "zenoh_ffi", "zenoh_get_stats")
pub fn get_stats() -> String

/// Batch publish multiple entries in one NIF call.
@external(erlang, "zenoh_ffi", "zenoh_publish_batch")
pub fn publish_batch(
  entries: List(#(String, String)),
) -> Result(String, String)

// ═══════════════════════════════════════════════════════════════════════
// SESSION HELPERS
// ═══════════════════════════════════════════════════════════════════════

/// Initialize zenoh — try peer mode first (no router needed).
pub fn init() -> Result(String, String) {
  case open("peer") {
    Ok(msg) -> Ok(msg)
    Error(_) -> open("client")
  }
}

// ═══════════════════════════════════════════════════════════════════════
// AUTH EVENTS — login, register, logout
// ═══════════════════════════════════════════════════════════════════════

/// Publish user login event.
pub fn publish_login(user_id: String, device_id: String) -> Result(String, String) {
  put(
    "indrajaal/sutra/auth/login",
    json_obj([
      #("user_id", user_id),
      #("device_id", device_id),
      #("action", "login"),
    ]),
  )
}

/// Publish user registration event.
pub fn publish_register(user_id: String, device_id: String) -> Result(String, String) {
  put(
    "indrajaal/sutra/auth/register",
    json_obj([
      #("user_id", user_id),
      #("device_id", device_id),
      #("action", "register"),
    ]),
  )
}

/// Publish user logout event.
pub fn publish_logout(user_id: String) -> Result(String, String) {
  put(
    "indrajaal/sutra/auth/logout",
    json_obj([#("user_id", user_id), #("action", "logout")]),
  )
}

// ═══════════════════════════════════════════════════════════════════════
// ROOM EVENTS — create, join, leave, invite
// ═══════════════════════════════════════════════════════════════════════

/// Publish room creation event.
pub fn publish_room_created(room_id: String, creator: String) -> Result(String, String) {
  put(
    "indrajaal/sutra/room/created",
    json_obj([
      #("room_id", room_id),
      #("creator", creator),
      #("action", "created"),
    ]),
  )
}

/// Publish room join event.
pub fn publish_room_join(room_id: String, user_id: String) -> Result(String, String) {
  put(
    "indrajaal/sutra/room/join",
    json_obj([
      #("room_id", room_id),
      #("user_id", user_id),
      #("action", "join"),
    ]),
  )
}

/// Publish room leave event.
pub fn publish_room_leave(room_id: String, user_id: String) -> Result(String, String) {
  put(
    "indrajaal/sutra/room/leave",
    json_obj([
      #("room_id", room_id),
      #("user_id", user_id),
      #("action", "leave"),
    ]),
  )
}

/// Publish room invite event.
pub fn publish_room_invite(
  room_id: String,
  inviter: String,
  invitee: String,
) -> Result(String, String) {
  put(
    "indrajaal/sutra/room/invite",
    json_obj([
      #("room_id", room_id),
      #("inviter", inviter),
      #("invitee", invitee),
      #("action", "invite"),
    ]),
  )
}

// ═══════════════════════════════════════════════════════════════════════
// MESSAGE EVENTS
// ═══════════════════════════════════════════════════════════════════════

/// Publish message sent event.
pub fn publish_message_sent(
  room_id: String,
  sender: String,
  event_id: String,
  msg_type: String,
) -> Result(String, String) {
  put(
    "indrajaal/sutra/message/sent",
    json_obj([
      #("room_id", room_id),
      #("sender", sender),
      #("event_id", event_id),
      #("msg_type", msg_type),
      #("action", "sent"),
    ]),
  )
}

// ═══════════════════════════════════════════════════════════════════════
// E2EE EVENTS — keys upload/query/claim/cross-sign
// ═══════════════════════════════════════════════════════════════════════

/// Publish E2EE key upload event.
pub fn publish_keys_uploaded(
  user_id: String,
  device_id: String,
  otk_count: Int,
) -> Result(String, String) {
  put(
    "indrajaal/sutra/e2ee/keys_uploaded",
    json.object([
      #("user_id", json.string(user_id)),
      #("device_id", json.string(device_id)),
      #("otk_count", json.int(otk_count)),
      #("action", json.string("keys_uploaded")),
    ])
      |> json.to_string,
  )
}

/// Publish keys query event.
pub fn publish_keys_query(user_id: String) -> Result(String, String) {
  put(
    "indrajaal/sutra/e2ee/keys_query",
    json_obj([#("user_id", user_id), #("action", "keys_query")]),
  )
}

/// Publish keys claim event.
pub fn publish_keys_claim(user_id: String) -> Result(String, String) {
  put(
    "indrajaal/sutra/e2ee/keys_claim",
    json_obj([#("user_id", user_id), #("action", "keys_claim")]),
  )
}

/// Publish cross-signing key upload event.
pub fn publish_cross_signing(user_id: String) -> Result(String, String) {
  put(
    "indrajaal/sutra/e2ee/cross_signing",
    json_obj([#("user_id", user_id), #("action", "cross_signing_upload")]),
  )
}

/// Publish key backup event.
pub fn publish_key_backup(user_id: String, action: String) -> Result(String, String) {
  put(
    "indrajaal/sutra/backup/" <> action,
    json_obj([#("user_id", user_id), #("action", action)]),
  )
}

// ═══════════════════════════════════════════════════════════════════════
// SYNC EVENTS
// ═══════════════════════════════════════════════════════════════════════

/// Publish sync event.
pub fn publish_sync(
  user_id: String,
  rooms_joined: Int,
  rooms_invited: Int,
) -> Result(String, String) {
  let localpart = case user_id {
    "" -> "unknown"
    _ -> case string.split(user_id, ":") {
      [part, ..] -> {
        let lp = string.drop_start(part, 1)
        case lp { "" -> "unknown" _ -> safe_key(lp) }
      }
      _ -> "unknown"
    }
  }
  put(
    "indrajaal/sutra/sync/" <> localpart,
    json.object([
      #("user_id", json.string(user_id)),
      #("rooms_joined", json.int(rooms_joined)),
      #("rooms_invited", json.int(rooms_invited)),
      #("action", json.string("sync")),
    ])
      |> json.to_string,
  )
}

/// Publish sliding sync event (MSC3575).
pub fn publish_sliding_sync(user_id: String) -> Result(String, String) {
  put(
    "indrajaal/sutra/sliding_sync",
    json_obj([#("user_id", user_id), #("action", "sliding_sync")]),
  )
}

// ═══════════════════════════════════════════════════════════════════════
// EPHEMERAL EVENTS — typing, presence, receipts
// ═══════════════════════════════════════════════════════════════════════

/// Publish typing indicator event.
pub fn publish_typing(room_id: String, user_id: String, is_typing: String) -> Result(String, String) {
  put(
    "indrajaal/sutra/typing/" <> safe_key(room_id),
    json_obj([
      #("room_id", room_id),
      #("user_id", user_id),
      #("typing", is_typing),
    ]),
  )
}

/// Publish presence update event.
pub fn publish_presence(user_id: String, status: String) -> Result(String, String) {
  let localpart = case string.split(user_id, ":") {
    [part, ..] -> safe_key(string.drop_start(part, 1))
    _ -> "unknown"
  }
  put(
    "indrajaal/sutra/presence/" <> localpart,
    json_obj([
      #("user_id", user_id),
      #("presence", status),
      #("action", "presence_update"),
    ]),
  )
}

/// Publish read receipt event.
pub fn publish_receipt(room_id: String, user_id: String, event_id: String) -> Result(String, String) {
  put(
    "indrajaal/sutra/receipt/" <> safe_key(room_id),
    json_obj([
      #("room_id", room_id),
      #("user_id", user_id),
      #("event_id", event_id),
      #("action", "receipt"),
    ]),
  )
}

// ═══════════════════════════════════════════════════════════════════════
// DEVICE MANAGEMENT
// ═══════════════════════════════════════════════════════════════════════

/// Publish device list query.
pub fn publish_device_list(user_id: String) -> Result(String, String) {
  put(
    "indrajaal/sutra/device/list",
    json_obj([#("user_id", user_id), #("action", "device_list")]),
  )
}

/// Publish device deletion.
pub fn publish_device_delete(user_id: String, device_id: String) -> Result(String, String) {
  put(
    "indrajaal/sutra/device/delete",
    json_obj([
      #("user_id", user_id),
      #("device_id", device_id),
      #("action", "device_delete"),
    ]),
  )
}

/// Publish to-device message.
pub fn publish_to_device(sender: String, msg_type: String) -> Result(String, String) {
  put(
    "indrajaal/sutra/to_device/" <> safe_key(msg_type),
    json_obj([
      #("sender", sender),
      #("type", msg_type),
      #("action", "to_device"),
    ]),
  )
}

// ═══════════════════════════════════════════════════════════════════════
// MEDIA EVENTS
// ═══════════════════════════════════════════════════════════════════════

/// Publish media upload event.
pub fn publish_media_upload(user_id: String, media_id: String) -> Result(String, String) {
  put(
    "indrajaal/sutra/media/upload",
    json_obj([
      #("user_id", user_id),
      #("media_id", media_id),
      #("action", "upload"),
    ]),
  )
}

/// Publish media download event.
pub fn publish_media_download(media_id: String) -> Result(String, String) {
  put(
    "indrajaal/sutra/media/download",
    json_obj([#("media_id", media_id), #("action", "download")]),
  )
}

// ═══════════════════════════════════════════════════════════════════════
// SEARCH, PROFILE, STATE, DIRECTORY, FEDERATION, ADMIN
// ═══════════════════════════════════════════════════════════════════════

/// Publish search query event.
pub fn publish_search(user_id: String) -> Result(String, String) {
  put(
    "indrajaal/sutra/search",
    json_obj([#("user_id", user_id), #("action", "search")]),
  )
}

/// Publish profile update event.
pub fn publish_profile_update(user_id: String, field: String) -> Result(String, String) {
  put(
    "indrajaal/sutra/profile/update",
    json_obj([
      #("user_id", user_id),
      #("field", field),
      #("action", "profile_update"),
    ]),
  )
}

/// Publish room state event.
pub fn publish_state_event(room_id: String, event_type: String) -> Result(String, String) {
  put(
    "indrajaal/sutra/state/" <> safe_key(room_id) <> "/" <> safe_key(event_type),
    json_obj([
      #("room_id", room_id),
      #("type", event_type),
      #("action", "state_change"),
    ]),
  )
}

/// Publish room directory event.
pub fn publish_directory(action: String, alias: String) -> Result(String, String) {
  put(
    "indrajaal/sutra/directory/" <> action,
    json_obj([#("alias", alias), #("action", action)]),
  )
}

/// Publish federation event.
pub fn publish_federation(action: String, origin: String) -> Result(String, String) {
  put(
    "indrajaal/sutra/federation/" <> action,
    json_obj([#("origin", origin), #("action", action)]),
  )
}

/// Publish push rules change.
pub fn publish_push_rules(user_id: String, action: String) -> Result(String, String) {
  put(
    "indrajaal/sutra/push/" <> action,
    json_obj([#("user_id", user_id), #("action", action)]),
  )
}

/// Publish account data change.
pub fn publish_account_data(user_id: String, data_type: String) -> Result(String, String) {
  let localpart = case string.split(user_id, ":") {
    [part, ..] -> safe_key(string.drop_start(part, 1))
    _ -> "unknown"
  }
  put(
    "indrajaal/sutra/account_data/" <> localpart,
    json_obj([
      #("user_id", user_id),
      #("type", data_type),
      #("action", "account_data"),
    ]),
  )
}

/// Publish filter creation event.
pub fn publish_filter(user_id: String) -> Result(String, String) {
  put(
    "indrajaal/sutra/filter/create",
    json_obj([#("user_id", user_id), #("action", "filter_create")]),
  )
}

/// Publish capabilities query.
pub fn publish_capabilities() -> Result(String, String) {
  put(
    "indrajaal/sutra/capabilities",
    json_obj([#("action", "capabilities_query")]),
  )
}

// ═══════════════════════════════════════════════════════════════════════
// GENERIC EVENTS
// ═══════════════════════════════════════════════════════════════════════

/// Publish a Matrix event to the Zenoh mesh.
pub fn publish_event(
  event_type: String,
  room_id: String,
  sender: String,
  event_id: String,
) -> Result(String, String) {
  put(
    "indrajaal/sutra/event/" <> safe_key(event_type),
    json_obj([
      #("type", event_type),
      #("room_id", room_id),
      #("sender", sender),
      #("event_id", event_id),
    ]),
  )
}

/// Publish server health to Zenoh mesh.
pub fn publish_health(
  request_count: Int,
  user_count: Int,
  room_count: Int,
) -> Result(String, String) {
  put(
    "indrajaal/sutra/health",
    json.object([
      #("server", json.string("sutra")),
      #("status", json.string("healthy")),
      #("requests", json.int(request_count)),
      #("users", json.int(user_count)),
      #("rooms", json.int(room_count)),
    ])
      |> json.to_string,
  )
}

/// Publish request telemetry.
pub fn publish_request(
  method: String,
  path: String,
  status: Int,
  body_size: Int,
) -> Result(String, String) {
  let path_key = case string.split(path, "/") {
    [_, _, _, _, seg, ..] -> safe_key(seg)
    _ -> "unknown"
  }
  put(
    "indrajaal/sutra/req/" <> string.lowercase(method) <> "/" <> path_key,
    json.object([
      #("method", json.string(method)),
      #("path", json.string(path)),
      #("status", json.int(status)),
      #("body_size", json.int(body_size)),
    ])
      |> json.to_string,
  )
}

/// Publish a test observation event for closed-loop Patrol testing.
pub fn publish_test_observation(
  test_name: String,
  result: String,
  details: String,
) -> Result(String, String) {
  put(
    "indrajaal/test/sutra/" <> test_name,
    json_obj([
      #("test", test_name),
      #("result", result),
      #("details", details),
    ]),
  )
}

// ═══════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════

/// Build a simple JSON object from string key-value pairs.
fn json_obj(pairs: List(#(String, String))) -> String {
  json.object(list.map(pairs, fn(p) { #(p.0, json.string(p.1)) }))
  |> json.to_string
}

/// Sanitize a key for use in zenoh key expressions (replace . and ! and : and #).
fn safe_key(s: String) -> String {
  s
  |> string.replace(".", "_")
  |> string.replace("!", "_")
  |> string.replace(":", "_")
  |> string.replace("#", "_")
  |> string.replace(" ", "_")
}
