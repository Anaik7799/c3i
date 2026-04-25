//// Sutra In-Memory Key-Value Store
//// MVP storage layer — will be replaced by SQLite/RocksDB.
//// Provides typed CRUD operations over pure-functional lists.

import gleam/bool
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import sutra_server/matrix/types

// ---------------------------------------------------------------------------
// Store type
// ---------------------------------------------------------------------------

/// Stored device keys for E2EE.
pub type StoredDeviceKeys {
  StoredDeviceKeys(
    user_id: String,
    device_id: String,
    algorithms: List(String),
    keys_json: String,
    signatures_json: String,
  )
}

/// Stored cross-signing keys.
pub type StoredCrossSigningKeys {
  StoredCrossSigningKeys(
    user_id: String,
    master_key: String,
    self_signing_key: String,
    user_signing_key: String,
  )
}

/// The root in-memory store for all Sutra state.
pub type Store {
  Store(
    users: List(types.UserAccount),
    rooms: List(types.Room),
    events: List(types.PduEvent),
    /// token -> user_id mappings
    tokens: List(#(String, String)),
    media: List(types.MediaMetadata),
    /// E2EE device keys: (user_id, device_id) -> keys
    device_keys: List(StoredDeviceKeys),
    /// E2EE one-time keys: (user_id, device_id, key_id) -> key_json
    one_time_keys: List(#(String, String, String, String)),
    /// Cross-signing keys per user
    cross_signing_keys: List(StoredCrossSigningKeys),
    /// Per-user account data: (user_id, data_type, content_json)
    account_data: List(#(String, String, String)),
    /// Token → device_id mapping so sync can report per-device OTK counts
    token_devices: List(#(String, String)),
    /// Pending to-device events: (target_user_id, event_type, content_json)
    to_device_events: List(#(String, String, String)),
    /// Current key backup version string (empty = none)
    key_backup_version: String,
    /// Key backup auth_data JSON (public key etc.)
    key_backup_auth_data: String,
    /// Key backup algorithm string
    key_backup_algorithm: String,
    /// Key backup data: (version, room_id_session_id, data_json)
    key_backup_data: List(#(String, String, String)),
    /// Read receipts: (room_id, event_id, user_id, receipt_type, ts)
    receipts: List(#(String, String, String, String, Int)),
    /// Typing indicators: (room_id, user_id, timeout_ts)
    typing: List(#(String, String, Int)),
    /// Presence: (user_id, status, last_active_ts)
    presence: List(#(String, String, Int)),
    /// Raw media blobs: (media_id, content)
    media_blobs: List(#(String, String)),
    /// Room aliases: (alias, room_id)
    room_aliases: List(#(String, String)),
    /// Room visibility per room_id: "public" | "private"
    room_visibility: List(#(String, String)),
    /// Event reports: (room_id, event_id, user_id, reason, score)
    reports: List(#(String, String, String, String, Int)),
    /// Forgotten rooms: (user_id, room_id) — rooms the user has forgotten
    forgotten_rooms: List(#(String, String)),
    /// Push notification registrations: (user_id, pusher_json)
    pushers_data: List(#(String, String)),
    /// Push rules: (user_id, scope_kind_ruleid, rule_json)
    /// The key is "{scope}/{kind}/{ruleId}" for easy lookup.
    push_rules_data: List(#(String, String, String)),
    /// 3PID verification sessions: (session_id, medium, address)
    threepid_sessions: List(#(String, String, String)),
    /// Third-party protocol registrations: (protocol_id, config_json)
    thirdparty_protocols: List(#(String, String)),
    /// Reserved media IDs not yet uploaded
    reserved_media: List(String),
    /// URL preview cache: (url, metadata_json)
    url_previews: List(#(String, String)),
  )
}

// ---------------------------------------------------------------------------
// Constructors
// ---------------------------------------------------------------------------

/// Create an empty store.
pub fn new() -> Store {
  Store(
    users: [], rooms: [], events: [], tokens: [], media: [],
    device_keys: [], one_time_keys: [], cross_signing_keys: [],
    account_data: [],
    token_devices: [],
    to_device_events: [],
    key_backup_version: "",
    key_backup_auth_data: "{}",
    key_backup_algorithm: "m.megolm_backup.v1.curve25519-aes-sha2",
    key_backup_data: [],
    receipts: [],
    typing: [],
    presence: [],
    media_blobs: [],
    room_aliases: [],
    room_visibility: [],
    reports: [],
    forgotten_rooms: [],
    pushers_data: [],
    push_rules_data: [],
    threepid_sessions: [],
    thirdparty_protocols: [],
    reserved_media: [],
    url_previews: [],
  )
}

// ---------------------------------------------------------------------------
// User operations
// ---------------------------------------------------------------------------

/// Add a user to the store.
pub fn add_user(store: Store, user: types.UserAccount) -> Store {
  Store(..store, users: [user, ..store.users])
}

/// Find a user by their full user_id string (e.g. "@alice:localhost").
pub fn find_user(
  store: Store,
  user_id: String,
) -> Result(types.UserAccount, Nil) {
  list.find(store.users, fn(u) {
    types.user_id_to_string(u.user_id) == user_id
  })
}

/// Find a user by their access token (searches device tokens).
pub fn find_user_by_token(
  store: Store,
  token: String,
) -> Result(types.UserAccount, Nil) {
  case list.find(store.tokens, fn(pair) { pair.0 == token }) {
    Error(_) -> Error(Nil)
    Ok(#(_, user_id)) -> find_user(store, user_id)
  }
}

/// Find all users whose localpart or display_name contains a search term.
pub fn search_users(
  store: Store,
  term: String,
) -> List(types.UserAccount) {
  let lower_term = string.lowercase(term)
  list.filter(store.users, fn(u) {
    let uid_str = string.lowercase(types.user_id_to_string(u.user_id))
    let display = case u.display_name {
      Some(dn) -> string.lowercase(dn)
      None -> ""
    }
    string.contains(uid_str, lower_term)
    || string.contains(display, lower_term)
  })
}

/// Update an existing user (replaces by user_id match).
pub fn update_user(store: Store, user: types.UserAccount) -> Store {
  let uid = types.user_id_to_string(user.user_id)
  let filtered =
    list.filter(store.users, fn(u) {
      types.user_id_to_string(u.user_id) != uid
    })
  Store(..store, users: [user, ..filtered])
}

// ---------------------------------------------------------------------------
// Room operations
// ---------------------------------------------------------------------------

/// Add a room to the store.
pub fn add_room(store: Store, room: types.Room) -> Store {
  Store(..store, rooms: [room, ..store.rooms])
}

/// Find a room by its full room_id string (e.g. "!abc:localhost").
pub fn find_room(
  store: Store,
  room_id: String,
) -> Result(types.Room, Nil) {
  list.find(store.rooms, fn(r) {
    types.room_id_to_string(r.room_id) == room_id
  })
}

/// Find all rooms that a user is a member of.
pub fn rooms_for_user(
  store: Store,
  user_id: String,
) -> List(types.Room) {
  list.filter(store.rooms, fn(r) {
    list.any(r.state.members, fn(pair) {
      let #(uid, membership) = pair
      types.user_id_to_string(uid) == user_id
      && membership == types.MJoin
    })
  })
}

/// Update an existing room state (replaces by room_id match).
pub fn update_room(store: Store, room: types.Room) -> Store {
  let rid = types.room_id_to_string(room.room_id)
  let filtered =
    list.filter(store.rooms, fn(r) {
      types.room_id_to_string(r.room_id) != rid
    })
  Store(..store, rooms: [room, ..filtered])
}

// ---------------------------------------------------------------------------
// Event operations
// ---------------------------------------------------------------------------

/// Append an event to the store.
pub fn add_event(store: Store, event: types.PduEvent) -> Store {
  Store(..store, events: [event, ..store.events])
}

/// Return the most recent `limit` events in a room, newest first.
pub fn events_in_room(
  store: Store,
  room_id: String,
  limit: Int,
) -> List(types.PduEvent) {
  store.events
  |> list.filter(fn(e) { types.room_id_to_string(e.room_id) == room_id })
  |> list.take(limit)
}

/// Return all state events (events with a state_key) for a room.
pub fn state_events_in_room(
  store: Store,
  room_id: String,
) -> List(types.PduEvent) {
  store.events
  |> list.filter(fn(e) {
    types.room_id_to_string(e.room_id) == room_id
    && types.is_state_event(e)
  })
}

/// Find a single event by its event_id string.
pub fn find_event(
  store: Store,
  event_id: String,
) -> Result(types.PduEvent, Nil) {
  list.find(store.events, fn(e) {
    types.event_id_to_string(e.event_id) == event_id
  })
}

/// Replace an existing event by event_id (upsert — appends if not found).
pub fn update_event(store: Store, event: types.PduEvent) -> Store {
  let eid = types.event_id_to_string(event.event_id)
  let filtered =
    list.filter(store.events, fn(e) {
      types.event_id_to_string(e.event_id) != eid
    })
  Store(..store, events: [event, ..filtered])
}

/// Return all events from a given sender.
pub fn events_by_sender(
  store: Store,
  sender_id: String,
) -> List(types.PduEvent) {
  list.filter(store.events, fn(e) {
    types.user_id_to_string(e.sender) == sender_id
  })
}

// ---------------------------------------------------------------------------
// Token operations
// ---------------------------------------------------------------------------

/// Register an access token for a user.
/// Also persists to sled for cross-restart survival (SC-TRUTH-001).
pub fn add_token(
  store: Store,
  token: String,
  user_id: String,
) -> Store {
  // Persist to sled (fire-and-forget — graceful degradation if sled unavailable)
  let _ = sled_put("tokens", token, user_id)
  Store(..store, tokens: [#(token, user_id), ..store.tokens])
}

/// Revoke an access token (remove from store + sled).
pub fn revoke_token(store: Store, token: String) -> Store {
  let _ = sled_delete("tokens", token)
  Store(
    ..store,
    tokens: list.filter(store.tokens, fn(pair) { pair.0 != token }),
  )
}

/// Revoke all tokens belonging to a user.
pub fn revoke_all_user_tokens(store: Store, user_id: String) -> Store {
  // Delete each token from sled
  list.each(store.tokens, fn(pair) {
    case pair.1 == user_id {
      True -> { let _ = sled_delete("tokens", pair.0) Nil }
      False -> Nil
    }
  })
  Store(
    ..store,
    tokens: list.filter(store.tokens, fn(pair) { pair.1 != user_id }),
  )
}

/// Load persisted tokens from sled into a store.
/// Call this at server startup to restore cross-restart tokens.
pub fn load_tokens_from_sled(store: Store) -> Store {
  case sled_scan("tokens", "", 10_000) {
    Ok(pairs) -> Store(..store, tokens: list.append(pairs, store.tokens))
    Error(_) -> store
  }
}

/// Return True if the token exists in the store.
pub fn token_exists(store: Store, token: String) -> Bool {
  list.any(store.tokens, fn(pair) { pair.0 == token })
}

// ---------------------------------------------------------------------------
// Media operations
// ---------------------------------------------------------------------------

/// Add media metadata to the store.
pub fn add_media(store: Store, meta: types.MediaMetadata) -> Store {
  Store(..store, media: [meta, ..store.media])
}

/// Find media by its mxc:// media_id part.
pub fn find_media(
  store: Store,
  server_name: String,
  media_id: String,
) -> Result(types.MediaMetadata, Nil) {
  list.find(store.media, fn(m) {
    m.media_id.server_name == server_name
    && m.media_id.media_id == media_id
  })
}

/// Return all media uploaded by a given user.
pub fn media_by_user(
  store: Store,
  user_id: String,
) -> List(types.MediaMetadata) {
  list.filter(store.media, fn(m) {
    types.user_id_to_string(m.uploader) == user_id
  })
}

// ---------------------------------------------------------------------------
// Statistics / summary
// ---------------------------------------------------------------------------

/// Total number of registered users.
pub fn user_count(store: Store) -> Int {
  list.length(store.users)
}

/// Total number of rooms.
pub fn room_count(store: Store) -> Int {
  list.length(store.rooms)
}

/// Total number of stored events.
pub fn event_count(store: Store) -> Int {
  list.length(store.events)
}

/// Total number of active tokens.
pub fn token_count(store: Store) -> Int {
  list.length(store.tokens)
}

/// Total number of stored media items.
pub fn media_count(store: Store) -> Int {
  list.length(store.media)
}

/// Human-readable summary string.
pub fn summary(store: Store) -> String {
  "Store("
  <> "users="
  <> int.to_string(user_count(store))
  <> " rooms="
  <> int.to_string(room_count(store))
  <> " events="
  <> int.to_string(event_count(store))
  <> " tokens="
  <> int.to_string(token_count(store))
  <> " media="
  <> int.to_string(media_count(store))
  <> ")"
}

// ---------------------------------------------------------------------------
// Bulk / merge helpers
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// E2EE Device Key operations
// ---------------------------------------------------------------------------

/// Store device keys for a user+device (upsert).
pub fn store_device_keys(store: Store, dk: StoredDeviceKeys) -> Store {
  let filtered = list.filter(store.device_keys, fn(k) {
    case k.user_id == dk.user_id && k.device_id == dk.device_id {
      True -> False
      False -> True
    }
  })
  Store(..store, device_keys: [dk, ..filtered])
}

/// Get all device keys for a user.
pub fn get_device_keys(store: Store, user_id: String) -> List(StoredDeviceKeys) {
  list.filter(store.device_keys, fn(k) { k.user_id == user_id })
}

/// Remove all device keys for a user (called on login to clear stale devices).
pub fn clear_device_keys_for_user(store: Store, user_id: String) -> Store {
  let filtered = list.filter(store.device_keys, fn(k) { k.user_id != user_id })
  Store(..store, device_keys: filtered)
}

/// Merge uploaded signatures into stored device keys.
/// Called by keys/signatures/upload — adds cross-signing signatures
/// to the device key blob so keys/query returns the signed version.
/// The body format is: {"@user:server":{"DEVICEID":{...full key with sigs...}}}
pub fn merge_device_signatures(
  store: Store,
  user_id: String,
  device_id: String,
  signed_blob: String,
) -> Store {
  let updated = list.map(store.device_keys, fn(dk) {
    case dk.user_id == user_id && dk.device_id == device_id {
      True -> StoredDeviceKeys(..dk, keys_json: signed_blob)
      False -> dk
    }
  })
  Store(..store, device_keys: updated)
}

/// Merge cross-signing key signatures. When a user uploads signatures
/// that include a cross-signing key, update the stored cross-signing key blob.
pub fn merge_cross_signing_signatures(
  store: Store,
  user_id: String,
  key_type: String,
  signed_blob: String,
) -> Store {
  let updated = list.map(store.cross_signing_keys, fn(csk) {
    case csk.user_id == user_id {
      True -> case key_type {
        "master_key" -> StoredCrossSigningKeys(..csk, master_key: signed_blob)
        "self_signing_key" -> StoredCrossSigningKeys(..csk, self_signing_key: signed_blob)
        "user_signing_key" -> StoredCrossSigningKeys(..csk, user_signing_key: signed_blob)
        _ -> csk
      }
      False -> csk
    }
  })
  Store(..store, cross_signing_keys: updated)
}

/// Store a one-time key.
pub fn store_otk(store: Store, user_id: String, device_id: String, key_id: String, key_json: String) -> Store {
  Store(..store, one_time_keys: [#(user_id, device_id, key_id, key_json), ..store.one_time_keys])
}

/// Count unclaimed OTKs for a user+device.
pub fn count_otks(store: Store, user_id: String, device_id: String) -> Int {
  list.length(list.filter(store.one_time_keys, fn(k) {
    k.0 == user_id && k.1 == device_id
  }))
}

/// Claim (pop) one OTK for a user+device. Returns #(key_id, key_json, updated_store).
pub fn claim_otk(store: Store, user_id: String, device_id: String) -> Result(#(String, String, Store), Nil) {
  case list.find(store.one_time_keys, fn(k) { k.0 == user_id && k.1 == device_id }) {
    Error(_) -> Error(Nil)
    Ok(found) -> {
      let remaining = list.filter(store.one_time_keys, fn(k) { k != found })
      Ok(#(found.2, found.3, Store(..store, one_time_keys: remaining)))
    }
  }
}

/// Store cross-signing keys for a user.
pub fn store_cross_signing(store: Store, csk: StoredCrossSigningKeys) -> Store {
  let filtered = list.filter(store.cross_signing_keys, fn(k) {
    k.user_id != csk.user_id
  })
  Store(..store, cross_signing_keys: [csk, ..filtered])
}

/// Get cross-signing keys for a user.
pub fn get_cross_signing(store: Store, user_id: String) -> Result(StoredCrossSigningKeys, Nil) {
  list.find(store.cross_signing_keys, fn(k) { k.user_id == user_id })
}

// ---------------------------------------------------------------------------
// Account data operations
// ---------------------------------------------------------------------------

/// Set (upsert) account data for a user+type. Replaces any prior entry.
pub fn set_account_data(
  store: Store,
  user_id: String,
  data_type: String,
  content: String,
) -> Store {
  let filtered =
    list.filter(store.account_data, fn(entry) {
      let #(uid, dtype, _) = entry
      uid != user_id || dtype != data_type
    })
  Store(..store, account_data: [#(user_id, data_type, content), ..filtered])
}

/// Get account data content for a user+type. Returns Error(Nil) when not found.
pub fn get_account_data(
  store: Store,
  user_id: String,
  data_type: String,
) -> Result(String, Nil) {
  case
    list.find(store.account_data, fn(entry) {
      let #(uid, dtype, _) = entry
      uid == user_id && dtype == data_type
    })
  {
    Error(_) -> Error(Nil)
    Ok(#(_, _, content)) -> Ok(content)
  }
}

/// Return all account data entries for a user.
pub fn all_account_data(
  store: Store,
  user_id: String,
) -> List(#(String, String)) {
  store.account_data
  |> list.filter_map(fn(entry) {
    let #(uid, dtype, content) = entry
    case uid == user_id {
      True -> Ok(#(dtype, content))
      False -> Error(Nil)
    }
  })
}

/// Merge two stores — appends all entries from `other` into `base`.
/// Useful for test setup and snapshotting.
pub fn merge(base: Store, other: Store) -> Store {
  Store(
    users: list.append(other.users, base.users),
    rooms: list.append(other.rooms, base.rooms),
    events: list.append(other.events, base.events),
    tokens: list.append(other.tokens, base.tokens),
    media: list.append(other.media, base.media),
    device_keys: list.append(other.device_keys, base.device_keys),
    one_time_keys: list.append(other.one_time_keys, base.one_time_keys),
    cross_signing_keys: list.append(other.cross_signing_keys, base.cross_signing_keys),
    account_data: list.append(other.account_data, base.account_data),
    token_devices: list.append(other.token_devices, base.token_devices),
    to_device_events: list.append(other.to_device_events, base.to_device_events),
    key_backup_version: case other.key_backup_version {
      "" -> base.key_backup_version
      v -> v
    },
    key_backup_auth_data: case other.key_backup_auth_data {
      "{}" -> base.key_backup_auth_data
      v -> v
    },
    key_backup_algorithm: case other.key_backup_algorithm {
      "m.megolm_backup.v1.curve25519-aes-sha2" -> base.key_backup_algorithm
      v -> v
    },
    key_backup_data: list.append(other.key_backup_data, base.key_backup_data),
    receipts: list.append(other.receipts, base.receipts),
    typing: list.append(other.typing, base.typing),
    presence: list.append(other.presence, base.presence),
    media_blobs: list.append(other.media_blobs, base.media_blobs),
    room_aliases: list.append(other.room_aliases, base.room_aliases),
    room_visibility: list.append(other.room_visibility, base.room_visibility),
    reports: list.append(other.reports, base.reports),
    forgotten_rooms: list.append(other.forgotten_rooms, base.forgotten_rooms),
    pushers_data: list.append(other.pushers_data, base.pushers_data),
    push_rules_data: list.append(other.push_rules_data, base.push_rules_data),
    threepid_sessions: list.append(other.threepid_sessions, base.threepid_sessions),
    thirdparty_protocols: list.append(other.thirdparty_protocols, base.thirdparty_protocols),
    reserved_media: list.append(other.reserved_media, base.reserved_media),
    url_previews: list.append(other.url_previews, base.url_previews),
  )
}

/// Return a store snapshot containing only data for a specific room.
pub fn room_snapshot(store: Store, room_id: String) -> Store {
  let room_events = list.filter(store.events, fn(e) {
    types.room_id_to_string(e.room_id) == room_id
  })
  let rooms = case find_room(store, room_id) {
    Ok(r) -> [r]
    Error(_) -> []
  }
  Store(..new(), rooms: rooms, events: room_events)
}

// ---------------------------------------------------------------------------
// Token → device_id operations
// ---------------------------------------------------------------------------

/// Associate an access token with a device_id.
pub fn set_token_device(store: Store, token: String, device_id: String) -> Store {
  let filtered =
    list.filter(store.token_devices, fn(pair) { pair.0 != token })
  Store(..store, token_devices: [#(token, device_id), ..filtered])
}

/// Look up the device_id associated with an access token.
pub fn get_device_for_token(store: Store, token: String) -> Result(String, Nil) {
  case list.find(store.token_devices, fn(pair) { pair.0 == token }) {
    Error(_) -> Error(Nil)
    Ok(#(_, device_id)) -> Ok(device_id)
  }
}

// ---------------------------------------------------------------------------
// To-device event operations
// ---------------------------------------------------------------------------

/// Append a to-device event for a target user.
pub fn add_to_device(
  store: Store,
  target_user: String,
  event_type: String,
  content: String,
) -> Store {
  Store(
    ..store,
    to_device_events: [#(target_user, event_type, content), ..store.to_device_events],
  )
}

/// Drain all pending to-device events for a user.
/// Returns the events and a store with them removed.
pub fn drain_to_device(
  store: Store,
  user_id: String,
) -> #(List(#(String, String)), Store) {
  let mine =
    list.filter(store.to_device_events, fn(ev) { ev.0 == user_id })
  let remaining =
    list.filter(store.to_device_events, fn(ev) { ev.0 != user_id })
  let events =
    list.map(mine, fn(ev) {
      let #(_, event_type, content) = ev
      #(event_type, content)
    })
  #(events, Store(..store, to_device_events: remaining))
}

// ---------------------------------------------------------------------------
// Key backup operations
// ---------------------------------------------------------------------------

/// Get the current key backup version string ("" if none).
pub fn get_key_backup_version(store: Store) -> String {
  store.key_backup_version
}

/// Set the current key backup version with algorithm and auth_data.
pub fn set_key_backup_version(store: Store, version: String) -> Store {
  Store(..store, key_backup_version: version)
}

/// Set key backup version with full metadata (algorithm + auth_data).
pub fn set_key_backup_full(
  store: Store,
  version: String,
  algorithm: String,
  auth_data: String,
) -> Store {
  Store(
    ..store,
    key_backup_version: version,
    key_backup_algorithm: algorithm,
    key_backup_auth_data: auth_data,
  )
}

/// Get key backup auth_data.
pub fn get_key_backup_auth_data(store: Store) -> String {
  store.key_backup_auth_data
}

/// Get key backup algorithm.
pub fn get_key_backup_algorithm(store: Store) -> String {
  store.key_backup_algorithm
}

/// Store key backup data for a specific (version, room+session) key.
pub fn store_key_backup(
  store: Store,
  version: String,
  key: String,
  data_json: String,
) -> Store {
  let filtered =
    list.filter(store.key_backup_data, fn(entry) {
      let #(v, k, _) = entry
      v != version || k != key
    })
  Store(..store, key_backup_data: [#(version, key, data_json), ..filtered])
}

/// Get all key backup entries for a version.
pub fn get_key_backup_data(
  store: Store,
  version: String,
) -> List(#(String, String)) {
  store.key_backup_data
  |> list.filter_map(fn(entry) {
    let #(v, k, data) = entry
    case v == version {
      True -> Ok(#(k, data))
      False -> Error(Nil)
    }
  })
}

// ---------------------------------------------------------------------------
// Receipt operations
// ---------------------------------------------------------------------------

/// Add or update a read receipt.  Upserts on (room_id, user_id, receipt_type).
pub fn add_receipt(
  store: Store,
  room_id: String,
  event_id: String,
  user_id: String,
  receipt_type: String,
  ts: Int,
) -> Store {
  let filtered =
    list.filter(store.receipts, fn(r) {
      let #(rid, _, uid, rt, _) = r
      bool.negate(rid == room_id && uid == user_id && rt == receipt_type)
    })
  Store(
    ..store,
    receipts: [#(room_id, event_id, user_id, receipt_type, ts), ..filtered],
  )
}

/// Return all receipts for a room.
pub fn receipts_for_room(
  store: Store,
  room_id: String,
) -> List(#(String, String, String, String, Int)) {
  list.filter(store.receipts, fn(r) {
    let #(rid, _, _, _, _) = r
    rid == room_id
  })
}

// ---------------------------------------------------------------------------
// Typing operations
// ---------------------------------------------------------------------------

/// Set or refresh a typing entry for a user in a room.
/// timeout_ts is the absolute epoch-ms when typing expires.
pub fn set_typing(
  store: Store,
  room_id: String,
  user_id: String,
  timeout_ts: Int,
) -> Store {
  let filtered =
    list.filter(store.typing, fn(t) {
      let #(rid, uid, _) = t
      bool.negate(rid == room_id && uid == user_id)
    })
  Store(..store, typing: [#(room_id, user_id, timeout_ts), ..filtered])
}

/// Remove a typing entry for a user in a room.
pub fn clear_typing(store: Store, room_id: String, user_id: String) -> Store {
  Store(
    ..store,
    typing: list.filter(store.typing, fn(t) {
      let #(rid, uid, _) = t
      bool.negate(rid == room_id && uid == user_id)
    }),
  )
}

/// Return user_ids currently marked as typing in a room.
/// Entries with timeout_ts == 0 are always included (no expiry check without clock).
pub fn typing_in_room(store: Store, room_id: String) -> List(String) {
  store.typing
  |> list.filter_map(fn(t) {
    let #(rid, uid, _timeout_ts) = t
    case rid == room_id {
      True -> Ok(uid)
      False -> Error(Nil)
    }
  })
}

// ---------------------------------------------------------------------------
// Presence operations
// ---------------------------------------------------------------------------

/// Set or update presence for a user.
pub fn set_presence(
  store: Store,
  user_id: String,
  status: String,
  last_active_ts: Int,
) -> Store {
  let filtered =
    list.filter(store.presence, fn(p) {
      let #(uid, _, _) = p
      uid != user_id
    })
  Store(..store, presence: [#(user_id, status, last_active_ts), ..filtered])
}

/// Get presence for a user.  Returns Error(Nil) when not found.
pub fn get_presence(
  store: Store,
  user_id: String,
) -> Result(#(String, Int), Nil) {
  case list.find(store.presence, fn(p) {
    let #(uid, _, _) = p
    uid == user_id
  }) {
    Error(_) -> Error(Nil)
    Ok(#(_, status, ts)) -> Ok(#(status, ts))
  }
}

/// Return all presence entries.
pub fn all_presence(store: Store) -> List(#(String, String, Int)) {
  store.presence
}

// ---------------------------------------------------------------------------
// Media blob operations
// ---------------------------------------------------------------------------

/// Store the raw bytes of a media upload keyed by media_id.
pub fn store_media_blob(store: Store, media_id: String, content: String) -> Store {
  let filtered =
    list.filter(store.media_blobs, fn(pair) { pair.0 != media_id })
  Store(..store, media_blobs: [#(media_id, content), ..filtered])
}

/// Retrieve raw content for a media_id. Returns Error(Nil) when not found.
pub fn get_media_blob(store: Store, media_id: String) -> Result(String, Nil) {
  case list.find(store.media_blobs, fn(pair) { pair.0 == media_id }) {
    Error(_) -> Error(Nil)
    Ok(#(_, content)) -> Ok(content)
  }
}

// ---------------------------------------------------------------------------
// Room alias operations
// ---------------------------------------------------------------------------

/// Set (upsert) an alias → room_id mapping.
pub fn set_room_alias(store: Store, alias: String, room_id: String) -> Store {
  let filtered =
    list.filter(store.room_aliases, fn(pair) { pair.0 != alias })
  Store(..store, room_aliases: [#(alias, room_id), ..filtered])
}

/// Look up the room_id for an alias. Returns Error(Nil) when not found.
pub fn get_room_alias(store: Store, alias: String) -> Result(String, Nil) {
  case list.find(store.room_aliases, fn(pair) { pair.0 == alias }) {
    Error(_) -> Error(Nil)
    Ok(#(_, room_id)) -> Ok(room_id)
  }
}

/// Remove an alias mapping.
pub fn delete_room_alias(store: Store, alias: String) -> Store {
  Store(
    ..store,
    room_aliases: list.filter(store.room_aliases, fn(pair) { pair.0 != alias }),
  )
}

/// Return all aliases pointing to a given room_id.
pub fn aliases_for_room(store: Store, room_id: String) -> List(String) {
  store.room_aliases
  |> list.filter_map(fn(pair) {
    case pair.1 == room_id {
      True -> Ok(pair.0)
      False -> Error(Nil)
    }
  })
}

/// Alias for aliases_for_room — returns all local aliases for a room.
pub fn get_all_aliases_for_room(store: Store, room_id: String) -> List(String) {
  aliases_for_room(store, room_id)
}

// ---------------------------------------------------------------------------
// Room visibility operations
// ---------------------------------------------------------------------------

/// Set the visibility for a room ("public" or "private").
pub fn set_room_visibility(store: Store, room_id: String, visibility: String) -> Store {
  let filtered =
    list.filter(store.room_visibility, fn(pair) { pair.0 != room_id })
  Store(..store, room_visibility: [#(room_id, visibility), ..filtered])
}

/// Get the visibility for a room. Returns "private" when not set.
pub fn get_room_visibility(store: Store, room_id: String) -> String {
  case list.find(store.room_visibility, fn(pair) { pair.0 == room_id }) {
    Ok(#(_, vis)) -> vis
    Error(_) -> "private"
  }
}

// ---------------------------------------------------------------------------
// Report operations
// ---------------------------------------------------------------------------

/// Store an event report from a user.
pub fn add_report(
  store: Store,
  room_id: String,
  event_id: String,
  user_id: String,
  reason: String,
  score: Int,
) -> Store {
  Store(
    ..store,
    reports: [#(room_id, event_id, user_id, reason, score), ..store.reports],
  )
}

// ---------------------------------------------------------------------------
// Forgotten room operations
// ---------------------------------------------------------------------------

/// Mark a room as forgotten by a user.
pub fn forget_room(store: Store, user_id: String, room_id: String) -> Store {
  let already =
    list.any(store.forgotten_rooms, fn(pair) {
      pair.0 == user_id && pair.1 == room_id
    })
  case already {
    True -> store
    False ->
      Store(
        ..store,
        forgotten_rooms: [#(user_id, room_id), ..store.forgotten_rooms],
      )
  }
}

/// Return True if the user has forgotten the room.
pub fn has_forgotten(store: Store, user_id: String, room_id: String) -> Bool {
  list.any(store.forgotten_rooms, fn(pair) {
    pair.0 == user_id && pair.1 == room_id
  })
}

// ---------------------------------------------------------------------------
// Pusher operations
// ---------------------------------------------------------------------------

/// Store (upsert) a pusher for a user, keyed by user_id.
/// Replaces any prior pusher for the same user_id (simplified: one pusher per user).
pub fn set_pusher(store: Store, user_id: String, pusher_json: String) -> Store {
  let filtered =
    list.filter(store.pushers_data, fn(pair) { pair.0 != user_id })
  Store(..store, pushers_data: [#(user_id, pusher_json), ..filtered])
}

/// Return all pushers for a user.
pub fn get_pushers(store: Store, user_id: String) -> List(String) {
  store.pushers_data
  |> list.filter_map(fn(pair) {
    case pair.0 == user_id {
      True -> Ok(pair.1)
      False -> Error(Nil)
    }
  })
}

/// Delete a pusher for a user (removes all pushers for the user in this simple model).
pub fn delete_pusher(store: Store, user_id: String) -> Store {
  Store(
    ..store,
    pushers_data: list.filter(store.pushers_data, fn(pair) { pair.0 != user_id }),
  )
}

// ---------------------------------------------------------------------------
// Push rule operations
// ---------------------------------------------------------------------------

/// The composite key for a push rule: "{scope}/{kind}/{ruleId}".
fn push_rule_key(scope: String, kind: String, rule_id: String) -> String {
  scope <> "/" <> kind <> "/" <> rule_id
}

/// Store (upsert) a push rule for a user.
pub fn set_push_rule(
  store: Store,
  user_id: String,
  scope: String,
  kind: String,
  rule_id: String,
  rule_json: String,
) -> Store {
  let key = push_rule_key(scope, kind, rule_id)
  let filtered =
    list.filter(store.push_rules_data, fn(entry) {
      let #(uid, k, _) = entry
      uid != user_id || k != key
    })
  Store(..store, push_rules_data: [#(user_id, key, rule_json), ..filtered])
}

/// Get a specific push rule for a user. Returns Error(Nil) when not found.
pub fn get_push_rule(
  store: Store,
  user_id: String,
  scope: String,
  kind: String,
  rule_id: String,
) -> Result(String, Nil) {
  let key = push_rule_key(scope, kind, rule_id)
  case
    list.find(store.push_rules_data, fn(entry) {
      let #(uid, k, _) = entry
      uid == user_id && k == key
    })
  {
    Error(_) -> Error(Nil)
    Ok(#(_, _, rule_json)) -> Ok(rule_json)
  }
}

/// Return all push rules for a user as a list of (key, rule_json) pairs.
pub fn get_all_push_rules(
  store: Store,
  user_id: String,
) -> List(#(String, String)) {
  store.push_rules_data
  |> list.filter_map(fn(entry) {
    let #(uid, key, rule_json) = entry
    case uid == user_id {
      True -> Ok(#(key, rule_json))
      False -> Error(Nil)
    }
  })
}

/// Delete a specific push rule for a user.
pub fn delete_push_rule(
  store: Store,
  user_id: String,
  scope: String,
  kind: String,
  rule_id: String,
) -> Store {
  let key = push_rule_key(scope, kind, rule_id)
  Store(
    ..store,
    push_rules_data: list.filter(store.push_rules_data, fn(entry) {
      let #(uid, k, _) = entry
      uid != user_id || k != key
    }),
  )
}

// ---------------------------------------------------------------------------
// 3PID session operations
// ---------------------------------------------------------------------------

/// Record a pending 3PID verification session.
pub fn add_threepid_session(
  store: Store,
  session_id: String,
  medium: String,
  address: String,
) -> Store {
  Store(
    ..store,
    threepid_sessions: [
      #(session_id, medium, address),
      ..store.threepid_sessions
    ],
  )
}

/// Retrieve all 3PID sessions (session_id, medium, address).
pub fn get_threepid_sessions(store: Store) -> List(#(String, String, String)) {
  store.threepid_sessions
}

// ---------------------------------------------------------------------------
// Third-party protocol operations
// ---------------------------------------------------------------------------

/// Store a third-party protocol entry (upsert by protocol_id).
pub fn set_thirdparty_protocol(
  store: Store,
  protocol_id: String,
  config_json: String,
) -> Store {
  let filtered =
    list.filter(store.thirdparty_protocols, fn(pair) { pair.0 != protocol_id })
  Store(..store, thirdparty_protocols: [#(protocol_id, config_json), ..filtered])
}

/// Return all registered third-party protocols.
pub fn get_thirdparty_protocols(store: Store) -> List(#(String, String)) {
  store.thirdparty_protocols
}

// ---------------------------------------------------------------------------
// Reserved media operations (media/v1/create)
// ---------------------------------------------------------------------------

/// Reserve a media_id for future upload.
pub fn reserve_media(store: Store, media_id: String) -> Store {
  Store(..store, reserved_media: [media_id, ..store.reserved_media])
}

/// Check whether a media_id was reserved via /create.
pub fn is_reserved_media(store: Store, media_id: String) -> Bool {
  list.any(store.reserved_media, fn(id) { id == media_id })
}

/// Remove a reservation once the upload is complete.
pub fn remove_reserved_media(store: Store, media_id: String) -> Store {
  Store(
    ..store,
    reserved_media: list.filter(store.reserved_media, fn(id) { id != media_id }),
  )
}

// ---------------------------------------------------------------------------
// URL preview cache operations
// ---------------------------------------------------------------------------

/// Store a URL preview (upsert by url).
pub fn set_url_preview(store: Store, url: String, metadata_json: String) -> Store {
  let filtered =
    list.filter(store.url_previews, fn(pair) { pair.0 != url })
  Store(..store, url_previews: [#(url, metadata_json), ..filtered])
}

/// Retrieve a URL preview. Returns Error(Nil) when not cached.
pub fn get_url_preview(store: Store, url: String) -> Result(String, Nil) {
  case list.find(store.url_previews, fn(pair) { pair.0 == url }) {
    Error(_) -> Error(Nil)
    Ok(#(_, metadata_json)) -> Ok(metadata_json)
  }
}

// ---------------------------------------------------------------------------
// Sled persistence helpers (graceful degradation — server works without sled)
// ---------------------------------------------------------------------------

import sutra_server/rocksdb

fn sled_put(tree: String, key: String, value: String) -> Result(String, String) {
  rocksdb.put(tree, key, value)
}

fn sled_delete(tree: String, key: String) -> Result(String, String) {
  rocksdb.delete(tree, key)
}

fn sled_scan(tree: String, prefix: String, limit: Int) -> Result(List(#(String, String)), String) {
  rocksdb.scan(tree, prefix, limit)
}
