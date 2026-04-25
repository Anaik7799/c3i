//// Sutra Matrix Server — Sync Engine
//// Implements the Matrix /sync endpoint logic (CS API v1.18).
//// Supports both initial sync (no `since`) and incremental sync (`since=sN`).
////
//// Token format: "s{unix_timestamp_ms}" — e.g. "s1700000000000"

import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import sutra_server/matrix/types.{type PduEvent, type Room}
import sutra_server/serdes_json
import sutra_server/storage/kv

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

pub type SyncState {
  SyncState(
    user_id: String,
    since: Option(String),
    rooms_subscribed: List(String),
    last_sync_ts: Int,
  )
}

pub type SyncResult {
  SyncResult(
    next_batch: String,
    joined_rooms: List(JoinedRoomSync),
    invited_rooms: List(InvitedRoomSync),
    left_rooms: List(LeftRoomSync),
    /// Count of one-time keys held by the server per algorithm.
    /// Reported via `device_one_time_keys_count` in the sync response
    /// so clients know whether to upload more (Matrix CS API v1.18).
    device_one_time_keys_count: List(#(String, Int)),
    /// User IDs whose device keys changed — reported in `device_lists.changed`.
    device_lists_changed: List(String),
    /// Top-level account_data events for the syncing user.
    account_data_events: List(#(String, String)),
    /// Pending to-device events for the syncing user: (event_type, content_json).
    to_device_events: List(#(String, String)),
    /// Presence events: (user_id, status, last_active_ts).
    presence_events: List(#(String, String, Int)),
  )
}

pub type JoinedRoomSync {
  JoinedRoomSync(
    room_id: String,
    timeline_events: List(PduEvent),
    state_events: List(PduEvent),
    ephemeral_events: List(PduEvent),
    unread_count: Int,
    prev_batch: Option(String),
    limited: Bool,
    /// Read receipts for this room: (event_id, user_id, receipt_type, ts)
    receipts: List(#(String, String, String, Int)),
    /// Users currently typing: list of user_ids
    typing_users: List(String),
  )
}

pub type InvitedRoomSync {
  InvitedRoomSync(room_id: String, invite_state: List(PduEvent))
}

pub type LeftRoomSync {
  LeftRoomSync(room_id: String, timeline_events: List(PduEvent))
}

// ---------------------------------------------------------------------------
// Constructor
// ---------------------------------------------------------------------------

pub fn new_sync_state(user_id: String) -> SyncState {
  SyncState(
    user_id: user_id,
    since: None,
    rooms_subscribed: [],
    last_sync_ts: 0,
  )
}

/// Create a sync state with a real timestamp (for accurate batch tokens).
pub fn new_sync_state_with_ts(user_id: String, timestamp: Int) -> SyncState {
  SyncState(
    user_id: user_id,
    since: None,
    rooms_subscribed: [],
    last_sync_ts: timestamp,
  )
}

// ---------------------------------------------------------------------------
// Batch token helpers
// ---------------------------------------------------------------------------

/// Generate a sync batch token from a timestamp: "s{timestamp}".
pub fn generate_batch_token(timestamp: Int) -> String {
  "s" <> int.to_string(timestamp)
}

/// Parse "s{timestamp}" → Ok(timestamp) or Error("invalid token: ...").
pub fn parse_batch_token(token: String) -> Result(Int, String) {
  case string.starts_with(token, "s") {
    False -> Error("invalid token: must start with 's': " <> token)
    True -> {
      let digits = string.drop_start(token, 1)
      case int.parse(digits) {
        Ok(ts) -> Ok(ts)
        Error(_) ->
          Error("invalid token: non-numeric timestamp in '" <> token <> "'")
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Room queries
// ---------------------------------------------------------------------------

/// Return all rooms where the user has MJoin membership.
pub fn rooms_for_user(store: kv.Store, user_id: String) -> List(Room) {
  kv.rooms_for_user(store, user_id)
}

/// Return up to `limit` events in a room whose origin_server_ts > since_ts.
/// Events are returned in insertion order (oldest first).
pub fn events_since_token(
  store: kv.Store,
  room_id: String,
  since_ts: Int,
  limit: Int,
) -> List(PduEvent) {
  store.events
  |> list.filter(fn(e) {
    types.room_id_to_string(e.room_id) == room_id
    && e.origin_server_ts > since_ts
  })
  |> list.reverse
  |> list.take(limit)
  |> list.reverse
}

// ---------------------------------------------------------------------------
// Sync — initial (no since token)
// ---------------------------------------------------------------------------

/// Full initial sync: return all state + up to 20 timeline events per room.
/// `device_id` is the device making the request — used for accurate OTK counts.
pub fn initial_sync(
  state: SyncState,
  store: kv.Store,
  device_id: String,
) -> #(SyncState, SyncResult) {
  // Use real timestamp for batch token so incremental sync can filter correctly
  let now_ts = case state.last_sync_ts > 1000 {
    True -> state.last_sync_ts
    False -> 1
  }
  let next_batch = generate_batch_token(now_ts)

  let user_rooms = rooms_for_user(store, state.user_id)

  let joined =
    list.map(user_rooms, fn(room) {
      build_joined_room_initial(room, store, 20)
    })

  // Collect all user IDs that have stored device keys — report them as changed
  // so the client knows to query for keys (Matrix CS API v1.18 §11.12).
  let changed_users =
    store.device_keys
    |> list.map(fn(dk) { dk.user_id })
    |> list.unique

  // Report actual stored OTK count for the syncing device.
  // Report ACTUAL stored OTK count — NEVER fake 50 (SC-SATYA-001, SC-TRUTH-001)
  // Prior bug: reported 50 when 0 → FluffyChat skipped OTK upload → E2EE broke
  let otk_count = kv.count_otks(store, state.user_id, device_id)
  let otk_report = [#("curve25519", otk_count), #("signed_curve25519", otk_count)]

  let acct_data = kv.all_account_data(store, state.user_id)

  // Drain pending to-device events for this user.
  let #(to_dev_events, _store2) = kv.drain_to_device(store, state.user_id)

  let presence_evts = kv.all_presence(store)

  let result =
    SyncResult(
      next_batch: next_batch,
      joined_rooms: joined,
      invited_rooms: build_invited_rooms(store, state.user_id),
      left_rooms: [],
      device_one_time_keys_count: otk_report,
      device_lists_changed: changed_users,
      account_data_events: acct_data,
      to_device_events: to_dev_events,
      presence_events: presence_evts,
    )

  let new_state =
    SyncState(
      ..state,
      since: Some(next_batch),
      last_sync_ts: now_ts,
      rooms_subscribed: list.map(user_rooms, fn(r) {
        types.room_id_to_string(r.room_id)
      }),
    )

  #(new_state, result)
}

fn build_joined_room_initial(
  room: Room,
  store: kv.Store,
  limit: Int,
) -> JoinedRoomSync {
  let rid = types.room_id_to_string(room.room_id)
  let state_evts = kv.state_events_in_room(store, rid)
  let timeline_evts = kv.events_in_room(store, rid, limit)
  let limited = list.length(timeline_evts) >= limit
  // Collect receipts for this room: drop room_id field → (event_id, user_id, receipt_type, ts)
  let room_receipts =
    kv.receipts_for_room(store, rid)
    |> list.map(fn(r) {
      let #(_room_id, event_id, user_id, receipt_type, ts) = r
      #(event_id, user_id, receipt_type, ts)
    })
  let typing_users = kv.typing_in_room(store, rid)

  JoinedRoomSync(
    room_id: rid,
    timeline_events: timeline_evts,
    state_events: state_evts,
    ephemeral_events: [],
    unread_count: 0,
    prev_batch: None,
    limited: limited,
    receipts: room_receipts,
    typing_users: typing_users,
  )
}

fn build_invited_rooms(
  store: kv.Store,
  user_id: String,
) -> List(InvitedRoomSync) {
  list.filter_map(store.rooms, fn(room) {
    case
      list.find(room.state.members, fn(pair) {
        types.user_id_to_string(pair.0) == user_id
        && pair.1 == types.MInvite
      })
    {
      Error(_) -> Error(Nil)
      Ok(_) -> {
        let rid = types.room_id_to_string(room.room_id)
        let invite_state = kv.state_events_in_room(store, rid)
        Ok(InvitedRoomSync(room_id: rid, invite_state: invite_state))
      }
    }
  })
}

// ---------------------------------------------------------------------------
// Sync — incremental (since token provided)
// ---------------------------------------------------------------------------

/// Incremental sync: return only events newer than `since` token.
/// `device_id` is the device making the request — used for accurate OTK counts.
pub fn incremental_sync(
  state: SyncState,
  store: kv.Store,
  since: String,
  device_id: String,
) -> #(SyncState, SyncResult) {
  let since_ts_result = parse_batch_token(since)
  let since_ts = case since_ts_result {
    Ok(ts) -> ts
    Error(_) -> 0
  }

  // Use real timestamp for next batch token
  let now_ts = case state.last_sync_ts > 1000 {
    True -> state.last_sync_ts
    False -> since_ts + 1
  }
  let next_batch = generate_batch_token(now_ts)

  let user_rooms = rooms_for_user(store, state.user_id)

  let joined =
    list.filter_map(user_rooms, fn(room) {
      let rid = types.room_id_to_string(room.room_id)
      let new_events = events_since_token(store, rid, since_ts, 100)
      let room_receipts =
        kv.receipts_for_room(store, rid)
        |> list.map(fn(r) {
          let #(_room_id, event_id, user_id, receipt_type, ts) = r
          #(event_id, user_id, receipt_type, ts)
        })
      let typing_users = kv.typing_in_room(store, rid)
      // Always include rooms with ephemeral data, even with no new timeline events
      let has_ephemeral = room_receipts != [] || typing_users != []
      case new_events, has_ephemeral {
        [], False -> Error(Nil)
        _, _ -> {
          let timeline_evts =
            list.filter(new_events, fn(e) { e.state_key == None })
          let state_evts =
            list.filter(new_events, fn(e) { e.state_key != None })
          Ok(
            JoinedRoomSync(
              room_id: rid,
              timeline_events: timeline_evts,
              state_events: state_evts,
              ephemeral_events: [],
              unread_count: 0,
              prev_batch: Some(since),
              limited: False,
              receipts: room_receipts,
              typing_users: typing_users,
            ),
          )
        }
      }
    })

  // Report device key changes for incremental sync too
  let changed_users =
    store.device_keys
    |> list.map(fn(dk) { dk.user_id })
    |> list.unique

  // Report ACTUAL stored OTK count — NEVER fake 50 (SC-SATYA-001, SC-TRUTH-001)
  // Prior bug: reported 50 when 0 → FluffyChat skipped OTK upload → E2EE broke
  let otk_count = kv.count_otks(store, state.user_id, device_id)
  let otk_report = [#("curve25519", otk_count), #("signed_curve25519", otk_count)]

  let acct_data = kv.all_account_data(store, state.user_id)

  // Drain pending to-device events for this user.
  let #(to_dev_events, _store2) = kv.drain_to_device(store, state.user_id)

  let presence_evts = kv.all_presence(store)

  let result =
    SyncResult(
      next_batch: next_batch,
      joined_rooms: joined,
      invited_rooms: build_invited_rooms(store, state.user_id),
      left_rooms: [],
      device_one_time_keys_count: otk_report,
      device_lists_changed: changed_users,
      account_data_events: acct_data,
      to_device_events: to_dev_events,
      presence_events: presence_evts,
    )

  let new_state =
    SyncState(
      ..state,
      since: Some(next_batch),
      last_sync_ts: now_ts,
      rooms_subscribed: list.map(user_rooms, fn(r) {
        types.room_id_to_string(r.room_id)
      }),
    )

  #(new_state, result)
}

// ---------------------------------------------------------------------------
// JSON encoding
// ---------------------------------------------------------------------------

/// Encode a SyncResult to a JSON string matching the Matrix spec shape.
/// Includes `device_one_time_keys_count` as required by CS API v1.18 §11.5.
/// Includes top-level `account_data` as required by CS API v1.18 §14.1.
pub fn encode_sync_result(result: SyncResult) -> String {
  let rooms_json =
    serdes_json.object_raw([
      #("join", "{" <> encode_joined_rooms(result.joined_rooms) <> "}"),
      #("invite", "{" <> encode_invited_rooms(result.invited_rooms) <> "}"),
      #("leave", "{" <> encode_left_rooms(result.left_rooms) <> "}"),
    ])
  let acct_data_json =
    serdes_json.object_raw([
      #(
        "events",
        "[" <> encode_account_data_events(result.account_data_events) <> "]",
      ),
    ])
  let to_device_json =
    serdes_json.object_raw([
      #(
        "events",
        "[" <> encode_to_device_events(result.to_device_events) <> "]",
      ),
    ])
  let device_lists_json =
    serdes_json.object_raw([
      #(
        "changed",
        json.to_string(json.array(
          result.device_lists_changed,
          of: json.string,
        )),
      ),
      #("left", "[]"),
    ])
  let presence_json =
    serdes_json.object_raw([
      #("events", "[" <> encode_presence_events(result.presence_events) <> "]"),
    ])
  let otk_json =
    json.to_string(json.object(
      list.map(result.device_one_time_keys_count, fn(pair) {
        #(pair.0, json.int(pair.1))
      }),
    ))

  serdes_json.object_raw([
    #("next_batch", json.to_string(json.string(result.next_batch))),
    #("rooms", rooms_json),
    #("account_data", acct_data_json),
    #("to_device", to_device_json),
    #("device_one_time_keys_count", otk_json),
    #("device_unused_fallback_key_types", json.to_string(json.preprocessed_array([json.string("signed_curve25519")]))),
    #("device_lists", device_lists_json),
    #("presence", presence_json),
  ])
}

fn encode_account_data_events(events: List(#(String, String))) -> String {
  events
  |> list.map(fn(pair) {
    let #(data_type, content) = pair
    serdes_json.object_raw([
      #("type", json.to_string(json.string(data_type))),
      #("content", content),
    ])
  })
  |> string.join(",")
}

fn encode_to_device_events(events: List(#(String, String))) -> String {
  events
  |> list.map(fn(pair) {
    let #(event_type, content) = pair
    serdes_json.object_raw([
      #("type", json.to_string(json.string(event_type))),
      #("content", content),
    ])
  })
  |> string.join(",")
}


fn encode_joined_rooms(rooms: List(JoinedRoomSync)) -> String {
  rooms
  |> list.map(encode_one_joined)
  |> string.join(",")
}

fn encode_one_joined(room: JoinedRoomSync) -> String {
  let timeline_evts = encode_event_list(room.timeline_events)
  let state_evts = encode_event_list(room.state_events)
  let ephemeral_json = encode_ephemeral(room.receipts, room.typing_users)
  let timeline_obj =
    serdes_json.object_raw([
      #("events", "[" <> timeline_evts <> "]"),
      #("limited", json.to_string(json.bool(room.limited))),
      #(
        "prev_batch",
        json.to_string(json.nullable(room.prev_batch, of: json.string)),
      ),
    ])
  let state_obj =
    serdes_json.object_raw([#("events", "[" <> state_evts <> "]")])
  let ephemeral_obj =
    serdes_json.object_raw([#("events", "[" <> ephemeral_json <> "]")])
  let unread_obj =
    json.to_string(
      json.object([#("notification_count", json.int(room.unread_count))]),
    )
  let room_obj =
    serdes_json.object_raw([
      #("timeline", timeline_obj),
      #("state", state_obj),
      #("ephemeral", ephemeral_obj),
      #("unread_notifications", unread_obj),
    ])
  json.to_string(json.string(room.room_id)) <> ":" <> room_obj
}

fn encode_ephemeral(
  receipts: List(#(String, String, String, Int)),
  typing_users: List(String),
) -> String {
  let receipt_event = case receipts {
    [] -> []
    _ -> {
      // Build m.receipt event: {"type":"m.receipt","content":{eventId:{"m.read":{userId:{"ts":N}}}}}
      // Receipt content has dynamic event_id keys — use serdes_json.object_raw.
      let content =
        receipts
        |> list.map(fn(r) {
          let #(event_id, user_id, receipt_type, ts) = r
          let user_ts =
            json.to_string(json.object([#("ts", json.int(ts))]))
          let user_map = serdes_json.object_raw([#(user_id, user_ts)])
          let receipt_map = serdes_json.object_raw([#(receipt_type, user_map)])
          #(event_id, receipt_map)
        })
      let content_json = serdes_json.object_raw(content)
      [
        serdes_json.object_raw([
          #("type", json.to_string(json.string("m.receipt"))),
          #("content", content_json),
        ]),
      ]
    }
  }
  let typing_event = case typing_users {
    [] -> []
    uids -> {
      let uids_json = json.to_string(json.array(uids, of: json.string))
      let content =
        serdes_json.object_raw([#("user_ids", uids_json)])
      [
        serdes_json.object_raw([
          #("type", json.to_string(json.string("m.typing"))),
          #("content", content),
        ]),
      ]
    }
  }
  list.append(receipt_event, typing_event)
  |> string.join(",")
}

fn encode_presence_events(events: List(#(String, String, Int))) -> String {
  events
  |> list.map(fn(e) {
    let #(user_id, status, last_active_ts) = e
    json.to_string(
      json.object([
        #("type", json.string("m.presence")),
        #("sender", json.string(user_id)),
        #(
          "content",
          json.object([
            #("presence", json.string(status)),
            #("last_active_ago", json.int(last_active_ts)),
          ]),
        ),
      ]),
    )
  })
  |> string.join(",")
}

fn encode_invited_rooms(rooms: List(InvitedRoomSync)) -> String {
  rooms
  |> list.map(fn(r) {
    let evts = encode_event_list(r.invite_state)
    let invite_state_obj =
      serdes_json.object_raw([#("events", "[" <> evts <> "]")])
    let room_obj =
      serdes_json.object_raw([#("invite_state", invite_state_obj)])
    json.to_string(json.string(r.room_id)) <> ":" <> room_obj
  })
  |> string.join(",")
}

fn encode_left_rooms(rooms: List(LeftRoomSync)) -> String {
  rooms
  |> list.map(fn(r) {
    let evts = encode_event_list(r.timeline_events)
    let timeline_obj =
      serdes_json.object_raw([#("events", "[" <> evts <> "]")])
    let room_obj = serdes_json.object_raw([#("timeline", timeline_obj)])
    json.to_string(json.string(r.room_id)) <> ":" <> room_obj
  })
  |> string.join(",")
}

fn encode_event_list(events: List(PduEvent)) -> String {
  events
  |> list.map(encode_pdu_event)
  |> string.join(",")
}

fn encode_pdu_event(e: PduEvent) -> String {
  // Use encode_event NIF for the base (embeds content raw, no escaping).
  // Then merge room_id back in — the NIF omits it but Matrix clients need it.
  let base =
    serdes_json.encode_event(
      types.event_id_to_string(e.event_id),
      e.event_type,
      types.user_id_to_string(e.sender),
      e.origin_server_ts,
      e.content,
      case e.state_key {
        None -> "__NONE__"
        Some(sk) -> sk
      },
    )
  let room_id_patch =
    serdes_json.object_raw([
      #(
        "room_id",
        json.to_string(json.string(types.room_id_to_string(e.room_id))),
      ),
    ])
  serdes_json.merge(base, room_id_patch)
}

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------

pub fn summary(result: SyncResult) -> String {
  "SyncResult("
  <> "next_batch="
  <> result.next_batch
  <> " joined="
  <> int.to_string(list.length(result.joined_rooms))
  <> " invited="
  <> int.to_string(list.length(result.invited_rooms))
  <> " left="
  <> int.to_string(list.length(result.left_rooms))
  <> ")"
}
