# Sutra Matrix Homeserver — State & Path Analysis
# Layer: L3_TRANSACTION
# Reference: Matrix Client-Server API v1.18
# Generated from source analysis of sutra_server/ (41 modules)

---

## Table of Contents

1. [State Machines](#1-state-machines)
   - FSM-01 User Registration (UIA)
   - FSM-02 Login
   - FSM-03 Room Membership
   - FSM-04 Sync
   - FSM-05 Presence
   - FSM-06 Typing
   - FSM-07 Key Upload (E2EE)
   - FSM-08 Key Backup
   - FSM-09 Room Upgrade
   - FSM-10 Federation Transaction
   - FSM-11 Media Upload
   - FSM-12 Push Rule
2. [Control Paths](#2-control-paths)
3. [Data Paths](#3-data-paths)
4. [Robustness Gap Analysis](#4-robustness-gap-analysis)

---

## 1. State Machines

---

### FSM-01 — User Registration (UIA)

**Module**: `api/router.gleam` → `handle_register/1`
**Spec**: Matrix §5.7.3 User-Interactive Authentication

#### States

| State | Description |
|-------|-------------|
| `S0_IDLE` | No registration in progress |
| `S1_CHALLENGE_ISSUED` | 401 returned with session + flows |
| `S2_AUTH_COMPLETED` | UIA auth stage satisfied |
| `S3_REGISTERED` | User created, access_token issued |
| `S_ERROR` | Terminal failure |

#### Transitions

| From | Event | Guard | To | Response |
|------|-------|-------|----|----------|
| S0 | POST /register (empty body) | `!contains(body, "username") && !contains(body, "auth")` | S1_CHALLENGE_ISSUED | 401 + session + flows |
| S0 | POST /register (has "username") | `contains(body, "username")` | S3_REGISTERED | 200 + access_token |
| S0 | POST /register (has "auth") | `contains(body, "auth")` | S3_REGISTERED | 200 + access_token |
| S1 | POST /register (has "auth") | session token matches | S2_AUTH_COMPLETED | — |
| S2 | POST /register (has "username") | auth_completed | S3_REGISTERED | 200 + access_token |

#### Error Paths

| Condition | Error | Status |
|-----------|-------|--------|
| Username already taken | `M_USER_IN_USE` | 400 |
| Invalid username chars | `M_INVALID_USERNAME` | 400 |
| Guest access disabled | `M_FORBIDDEN` | 403 |
| Rate limit exceeded | `M_LIMIT_EXCEEDED` | 429 |

#### Implementation Gap

The current router.gleam `handle_register` uses `string.contains` on the raw body — it does not parse JSON. Any body containing the string `"username"` (even in a comment field) triggers immediate registration. Session state is not tracked — the `session` field in the 401 response is generated but never verified on follow-up POST.

---

### FSM-02 — Login

**Module**: `api/router.gleam` → `handle_login/1`; `api/handlers.gleam` → `handle_login/2`
**Spec**: Matrix §5.7.2

#### States

| State | Description |
|-------|-------------|
| `S0_IDLE` | Not authenticated |
| `S1_CREDENTIALS_VERIFIED` | Password matched against stored hash |
| `S2_TOKEN_ISSUED` | access_token generated + stored |
| `S_ERROR` | Auth failure |

#### Transitions

| From | Event | Guard | To | Response |
|------|-------|-------|----|----------|
| S0 | GET /login | — | S0 | 200 + flows array |
| S0 | POST /login (valid creds) | `password_verify(stored_hash, provided_password)` | S2_TOKEN_ISSUED | 200 + access_token |
| S0 | POST /login (invalid creds) | hash mismatch | S_ERROR | 403 M_FORBIDDEN |
| S0 | POST /login (unknown user) | user not in store | S_ERROR | 403 M_FORBIDDEN |
| S2 | POST /logout | token in store | S0 | 200 {} |

#### Error Paths

| Condition | Error | Status |
|-----------|-------|--------|
| Wrong password | `M_FORBIDDEN` | 403 |
| Unknown user | `M_FORBIDDEN` | 403 |
| Malformed body | `M_BAD_JSON` | 400 |
| Rate limited | `M_LIMIT_EXCEEDED` | 429 |

#### Implementation Notes

`router.gleam::handle_login` is a stub that issues any token without checking credentials. `handlers.gleam::handle_login` extracts username using string splitting on `"identifier"` / `"user"` keys, then calls the KV store to look up the user and verify the password hash. The live handler (handlers.gleam) is wired to the OTP process but the router contains a fallback stub — both exist simultaneously, with the stub taking precedence in the standalone router path.

---

### FSM-03 — Room Membership

**Module**: `matrix/auth.gleam`, `matrix/room_lifecycle.gleam`
**Spec**: Matrix §9.4

#### States

| State | Description |
|-------|-------------|
| `M_NONE` | User has no relationship with room |
| `M_INVITE` | User has been invited |
| `M_JOIN` | User is a room member |
| `M_LEAVE` | User left or was kicked |
| `M_BAN` | User has been banned |
| `M_KNOCK` | User has knocked (v7+ rooms) |

#### Transitions

| From | Event | Guard | To | Response |
|------|-------|-------|----|----------|
| M_NONE | invite | sender power ≥ invite_level | M_INVITE | 200 {} |
| M_NONE | join (public room) | join_rule=public | M_JOIN | 200 {room_id} |
| M_NONE | join (invite-only) | current_state=M_INVITE | M_JOIN | 200 {room_id} |
| M_NONE | knock (knock room) | join_rule=knock | M_KNOCK | 200 {} |
| M_INVITE | accept (join) | — | M_JOIN | 200 {room_id} |
| M_INVITE | reject (leave) | — | M_NONE | 200 {} |
| M_JOIN | leave | sender == user_id | M_LEAVE | 200 {} |
| M_JOIN | kick | sender power ≥ kick_level AND sender power > target power | M_LEAVE | 200 {} |
| M_JOIN | ban | sender power ≥ ban_level | M_BAN | 200 {} |
| M_LEAVE | join (public) | join_rule=public | M_JOIN | 200 {room_id} |
| M_LEAVE | join (invite-only) | needs new invite | M_JOIN | 200 {room_id} |
| M_BAN | unban | sender power ≥ ban_level | M_LEAVE | 200 {} |
| M_KNOCK | accept (invite sent) | sender power ≥ invite_level | M_INVITE | — |
| M_KNOCK | reject | — | M_LEAVE | — |

#### Guard Details (from auth.gleam)

```
check_join:
  if membership == MBan → Denied("banned")
  case join_rule:
    Public → Authorized
    Invite → if state[m.room.member][sender].membership == MInvite → Authorized
    Knock  → if state[m.room.member][sender].membership == MInvite → Authorized
    Restricted → check allow list (room_id member check)
    _     → Denied("join not allowed")

check_ban:
  if sender_power < ban_level → Denied
  if sender_power <= target_power → Denied
  else → Authorized
```

#### Error Paths

| Condition | Error | Status |
|-----------|-------|--------|
| Not in room for leave | `M_FORBIDDEN` | 403 |
| Already banned | `M_FORBIDDEN` | 403 |
| Insufficient power | `M_FORBIDDEN` | 403 |
| Room not found | `M_NOT_FOUND` | 404 |

---

### FSM-04 — Sync

**Module**: `matrix/sync_engine.gleam`
**Spec**: Matrix §5.3

#### States

| State | Description |
|-------|-------------|
| `S_INITIAL` | No `since` token — first sync |
| `S_INCREMENTAL` | `since` token present — delta sync |
| `S_TIMEOUT` | Long-poll timeout, empty response |
| `S_ERROR` | Sync failure |

#### Transitions

| From | Event | Guard | To | Response |
|------|-------|-------|----|----------|
| S_INITIAL | GET /sync (no since) | token valid | S_INCREMENTAL | 200 + full state + events |
| S_INITIAL | GET /sync (since=null) | same | S_INCREMENTAL | 200 + full state |
| S_INCREMENTAL | GET /sync (since=sN) | token valid, since parseable | S_INCREMENTAL | 200 + delta since sN |
| S_INCREMENTAL | GET /sync (since=sN, no new data) | timeout elapsed | S_TIMEOUT | 200 + next_batch + empty rooms |
| S_INITIAL | GET /sync (bad token) | `token_exists()` = false | S_ERROR | 401 M_UNKNOWN_TOKEN |

#### Token Format

```
next_batch = "s{timestamp}"
parse_batch_token("s1234567890") → Ok(1234567890)
parse_batch_token("invalid") → Error(Nil) → treated as initial sync
```

#### Filter Application

`SyncFilter` type in types.gleam has `limit: Int` (default 20). `initial_sync` returns up to 20 events per room. `incremental_sync` returns events with `origin_server_ts > since_ts`, limited to 100.

#### Implementation Gap

`router.gleam::handle_sync` returns a hardcoded empty sync response. The live `sync_engine.gleam` is not wired to the router — handlers.gleam contains the wired version but it requires the HandlerContext + OTP process. The stub sync ignores since token entirely.

---

### FSM-05 — Presence

**Module**: `matrix/presence.gleam`
**Spec**: Matrix §13.1

#### States

| State | Description |
|-------|-------------|
| `POnline` | User is active |
| `PUnavailable` | User is idle/away |
| `POffline` | User is offline |

#### Transitions

| From | Event | Guard | To |
|------|-------|-------|----|
| POffline | PUT /presence/.../status (online) | content.presence="online" | POnline |
| POnline | PUT /presence/.../status (unavailable) | content.presence="unavailable" | PUnavailable |
| POnline | PUT /presence/.../status (offline) | content.presence="offline" | POffline |
| PUnavailable | PUT /presence/.../status (online) | content.presence="online" | POnline |
| POnline | idle_threshold elapsed | `now - last_active_ts > idle_ms` | PUnavailable |
| PUnavailable | `currently_active` event | user sends request | POnline |

#### Error Paths

| Condition | Error | Status |
|-----------|-------|--------|
| Invalid presence value | `M_BAD_JSON` | 400 |
| User not found | `M_NOT_FOUND` | 404 |
| Setting presence for other user | `M_FORBIDDEN` | 403 |

#### Implementation Notes

`presence.gleam::set_presence` updates the entry in `PresenceStore`. `idle_users(store, now_ts, idle_ms)` finds online users past the idle threshold. The router stub at `handle_set_presence` / `handle_get_presence` returns static values; the store is not updated.

---

### FSM-06 — Typing

**Module**: `matrix/presence.gleam` (TypingStore section)
**Spec**: Matrix §13.2

#### States

| State | Description |
|-------|-------------|
| `T_IDLE` | No user typing in room |
| `T_TYPING` | At least one user typing |

#### Transitions

| From | Event | Guard | To |
|------|-------|-------|----|
| T_IDLE | PUT /typing/{userId} (typing=true) | user in room | T_TYPING |
| T_TYPING | PUT /typing/{userId} (typing=true) | — | T_TYPING (user added to list) |
| T_TYPING | PUT /typing/{userId} (typing=false) | — | T_IDLE or T_TYPING (user removed) |
| T_TYPING | timeout elapsed | `now_ms > start_ts + timeout_ms` | T_IDLE (auto-expire) |

#### Data Structure

```gleam
TypingState(room_id: String, typing_users: List(String), timeout_ms: Int)

set_typing(store, room_id, user_id, typing: True, timeout_ms: 30000)
  → adds user to typing_users list, deduplicates

set_typing(store, room_id, user_id, typing: False, timeout_ms: 0)
  → filters user from typing_users list
```

#### Error Paths

| Condition | Error | Status |
|-----------|-------|--------|
| Not a room member | `M_FORBIDDEN` | 403 |
| Timeout out of range (> 30s) | `M_BAD_JSON` | 400 |

---

### FSM-07 — Key Upload (E2EE)

**Module**: `matrix/encryption.gleam`
**Spec**: Matrix §10.5.4

#### States

| State | Description |
|-------|-------------|
| `E_EMPTY` | No keys uploaded |
| `E_DEVICE_KEYS` | Device identity keys uploaded |
| `E_OTK_LOADED` | One-time keys available |
| `E_CROSS_SIGNED` | Cross-signing keys present |

#### Transitions

| From | Event | Guard | To |
|------|-------|-------|----|
| E_EMPTY | PUT /keys/upload (device_keys) | device_keys present | E_DEVICE_KEYS |
| E_DEVICE_KEYS | PUT /keys/upload (one_time_keys) | OTKs > 0 | E_OTK_LOADED |
| E_OTK_LOADED | PUT /keys/upload (more OTKs) | — | E_OTK_LOADED (count += len) |
| E_DEVICE_KEYS | POST /keys/device_signing/upload | master_key present | E_CROSS_SIGNED |
| E_OTK_LOADED | claim (one key consumed) | OTK count > 0 | E_OTK_LOADED (count -= 1) |
| E_OTK_LOADED | claim (last key consumed) | OTK count = 1 | E_DEVICE_KEYS |

#### State Type

```gleam
EncryptionState(
  device_keys_uploaded: Bool,
  one_time_key_count: Int,
  megolm_sessions: List(MegolmSession),
  cross_signing: Option(CrossSigningKeys),
)
```

#### Response Format

```json
{"one_time_key_counts": {"curve25519": N, "signed_curve25519": N}}
```

The count in the response reflects how many OTKs the server currently holds (not how many were just uploaded). The stub handler returns `50` unconditionally.

#### Megolm Session Sub-FSM

| State | Event | Guard | Next |
|-------|-------|-------|------|
| Active | send_message | `message_index < max_messages` | Active (index++) |
| Active | send_message | `message_index >= max_messages` | Rotated (new session) |
| Active | age_check | `now - created_at > max_age_ms` | Rotated |

#### Error Paths

| Condition | Error | Status |
|-----------|-------|--------|
| Unknown algorithm | `M_UNRECOGNIZED` | 400 |
| Malformed key JSON | `M_BAD_JSON` | 400 |
| Not authenticated | `M_MISSING_TOKEN` | 401 |

---

### FSM-08 — Key Backup

**Module**: `matrix/key_backup.gleam`
**Spec**: Matrix §10.8

#### States

| State | Description |
|-------|-------------|
| `KB_EMPTY` | No backup version exists |
| `KB_VERSION_CREATED` | Backup version active |
| `KB_KEYS_STORED` | Sessions backed up in version |
| `KB_DELETED` | Version deleted |

#### Transitions

| From | Event | Guard | To | Response |
|------|-------|-------|----|----------|
| KB_EMPTY | PUT /room_keys/version | algorithm valid | KB_VERSION_CREATED | 200 {version: "1"} |
| KB_EMPTY | GET /room_keys/version | — | KB_EMPTY | 404 M_NOT_FOUND |
| KB_VERSION_CREATED | PUT /room_keys/keys/{roomId} | version matches | KB_KEYS_STORED | 200 {count, etag} |
| KB_KEYS_STORED | GET /room_keys/keys/{roomId} | version matches | KB_KEYS_STORED | 200 {sessions} |
| KB_KEYS_STORED | DELETE /room_keys/version/{v} | — | KB_DELETED | 200 {} |
| KB_DELETED | PUT /room_keys/version | — | KB_VERSION_CREATED | new version |

#### Etag Semantics

```
etag = "etag_{version_id}_{count}"
Updated on every PUT /room_keys/keys call.
Clients use etag to detect concurrent modification.
```

#### Version Management

```gleam
create_version(store, algorithm, auth_data, timestamp)
  → version_id = int.to_string(timestamp)
  → etag = "etag_" <> version_id

put_room_keys(store, version_id, room_id, sessions)
  → count += len(sessions)
  → etag updated

latest_version(store) → list.first(versions)  // most recent first
```

#### Error Paths

| Condition | Error | Status |
|-----------|-------|--------|
| No backup version | `M_NOT_FOUND` | 404 |
| Version mismatch on PUT | `M_WRONG_ROOM_KEYS_VERSION` | 403 |
| Invalid algorithm | `M_UNRECOGNIZED` | 400 |

---

### FSM-09 — Room Upgrade

**Module**: `api/router.gleam` → `room_op` ("upgrade" branch)
**Spec**: Matrix §9.7

#### States

| State | Description |
|-------|-------------|
| `R_ACTIVE` | Current room version active |
| `R_TOMBSTONED` | Old room has m.room.tombstone |
| `R_UPGRADED` | New room created, old room restricted |

#### Transitions

| From | Event | Guard | To | Response |
|------|-------|-------|----|----------|
| R_ACTIVE | POST /rooms/{id}/upgrade | sender power ≥ 100 | R_TOMBSTONED | create new room |
| R_TOMBSTONED | (new room init) | — | R_UPGRADED | 200 {replacement_room} |
| R_UPGRADED | clients join new room | — | R_UPGRADED | — |

#### Required Sequence (from spec)

1. Create new room with same state (membership, power levels, join rules)
2. Send `m.room.tombstone` in old room pointing to new room
3. Send `m.room.create` with `predecessor.room_id` in new room
4. Migrate aliases from old to new room
5. Power level senders get auto-invited to new room

#### Implementation Status

The router stub generates a new room_id and returns it immediately. Steps 1-5 are not implemented. The new room is not created in the store. No tombstone event is sent.

---

### FSM-10 — Federation Transaction

**Module**: `federation/transport.gleam`
**Spec**: Matrix S2S §6.1

#### States

| State | Description |
|-------|-------------|
| `FT_IDLE` | No active transaction |
| `FT_COLLECTING` | PDUs/EDUs being accumulated |
| `FT_SENDING` | Transaction being transmitted |
| `FT_ACKNOWLEDGED` | Remote accepted PDUs |
| `FT_PARTIAL` | Some PDUs rejected |
| `FT_ERROR` | Transaction failed |

#### Transitions

| From | Event | Guard | To | Response |
|------|-------|-------|----|----------|
| FT_IDLE | new_transaction() | — | FT_COLLECTING | — |
| FT_COLLECTING | add_pdu(pdu) | pdu_count < max | FT_COLLECTING | — |
| FT_COLLECTING | add_edu(edu) | — | FT_COLLECTING | — |
| FT_COLLECTING | send() | signature valid | FT_SENDING | PUT /_matrix/federation/v1/send/{txnId} |
| FT_SENDING | 200 response | — | FT_ACKNOWLEDGED | {pdus: {}} |
| FT_SENDING | partial 200 | some pdus rejected | FT_PARTIAL | {pdus: {event_id: error}} |
| FT_SENDING | 4xx/5xx | — | FT_ERROR | retry with backoff |
| FT_PARTIAL | retry rejected | — | FT_ACKNOWLEDGED or FT_ERROR | — |

#### Signature Verification

```gleam
verify_signature(req: SignedRequest) → Bool
  // Stub: signature.starts_with("stub_sig_") → True
  // Production: Ed25519 verify(server_public_key, canonical_json, signature)
```

#### Transaction ID Semantics

`transaction_id` must be unique per origin server. Receiving server should be idempotent — same txnId from same origin = no-op after first processing.

#### Error Paths

| Condition | Error | Status |
|-----------|-------|--------|
| Invalid signature | `M_UNAUTHORIZED` | 401 |
| PDU auth chain failure | included in response body per PDU | 200 (partial) |
| Unknown destination | `M_NOT_FOUND` | 404 |

---

### FSM-11 — Media Upload

**Module**: `matrix/media.gleam`
**Spec**: Matrix §13.8

#### States

| State | Description |
|-------|-------------|
| `MU_IDLE` | No upload in progress |
| `MU_VALIDATING` | Size/type check |
| `MU_STORED` | File in store, MXC URI assigned |
| `MU_ERROR` | Upload rejected |

#### Transitions

| From | Event | Guard | To | Response |
|------|-------|-------|----|----------|
| MU_IDLE | POST /upload (body) | `size <= max_size_bytes` | MU_STORED | 200 {content_uri} |
| MU_IDLE | POST /upload (body) | `size > max_size_bytes` | MU_ERROR | UploadTooLarge |
| MU_IDLE | POST /media/v1/create | — | MU_STORED (reserved) | 200 {content_uri, unused_expires_at} |
| MU_STORED | PUT /upload/{media_id} | async upload MSC2246 | MU_STORED | 200 {content_uri} |
| MU_STORED | GET /download/{server}/{mediaId} | media exists | MU_STORED | 200 + bytes |
| MU_STORED | GET /thumbnail/{server}/{mediaId} | media exists | MU_STORED | 200 + thumbnail bytes |
| MU_STORED | DELETE (admin) | — | MU_IDLE | 200 {} |

#### MXC URI Format

```
mxc://{server_name}/{media_id}

Examples:
  mxc://localhost/media_1234567890
  mxc://localhost/sutra_1234567890

parse_mxc_uri("mxc://foo.com/bar") → Ok(#("foo.com", "bar"))
parse_mxc_uri("invalid") → Error("MXC URI must start with mxc://: ...")
parse_mxc_uri("mxc:///bar") → Error("MXC URI server_name is empty: ...")
```

#### Error Paths

| Condition | Error | Status |
|-----------|-------|--------|
| File too large | `M_TOO_LARGE` | 413 |
| Unsupported media type | `M_UNKNOWN` | 400 |
| Media not found | `M_NOT_FOUND` | 404 |
| Not authenticated | `M_MISSING_TOKEN` | 401 |

---

### FSM-12 — Push Rule

**Module**: `matrix/push.gleam`
**Spec**: Matrix §11.12

#### States

| State | Description |
|-------|-------------|
| `PR_DEFAULT` | Only 8 default rules active |
| `PR_CUSTOM` | User-defined rules added |
| `PR_MODIFIED` | Default rule toggled or actions changed |

#### Transitions

| From | Event | Guard | To |
|------|-------|-------|----|
| PR_DEFAULT | PUT /pushrules/global/{kind}/{ruleId} | — | PR_CUSTOM |
| PR_DEFAULT | PUT .../enabled | rule_id in defaults | PR_MODIFIED |
| PR_CUSTOM | DELETE /pushrules/global/{kind}/{ruleId} | — | PR_DEFAULT or PR_CUSTOM |
| PR_MODIFIED | PUT .../enabled (true) | — | PR_DEFAULT |

#### Default Rules (order matters — first match wins)

| Priority | Rule ID | Condition | Action |
|----------|---------|-----------|--------|
| 1 | `.m.rule.master` | (disabled) | DontNotify |
| 2 | `.m.rule.suppress_notices` | content.msgtype = m.notice | DontNotify |
| 3 | `.m.rule.invite_for_me` | type=m.room.member, membership=invite | Notify + sound |
| 4 | `.m.rule.member_event` | type=m.room.member | DontNotify |
| 5 | `.m.rule.contains_display_name` | ContainsDisplayName | Notify + highlight |
| 6 | `.m.rule.room_one_to_one` | RoomMemberCount=2 + type=m.room.message | Notify + sound |
| 7 | `.m.rule.message` | type=m.room.message | Notify |
| 8 | `.m.rule.encrypted` | type=m.room.encrypted | Notify |

#### Rule Evaluation

```gleam
should_notify(rules, event_type, content) → Bool
  1. Filter to enabled rules only
  2. For each rule in order:
     if conditions_match(rule.conditions, event_type, content):
       return actions_include_notify(rule.actions)
  3. return False (no matching rule → no notify)
```

#### Condition Matching (simplified)

```
EventMatch("type", pattern) → event_type == pattern OR event_type contains pattern
EventMatch(key, pattern) → content contains pattern (string search, not JSON parse)
ContainsDisplayName → content contains "display_name" (stub — not user-specific)
RoomMemberCount → always True (stub)
SenderNotificationPermission → always True (stub)
```

#### Error Paths

| Condition | Error | Status |
|-----------|-------|--------|
| Invalid rule kind | `M_UNRECOGNIZED` | 400 |
| Rule not found for DELETE | `M_NOT_FOUND` | 404 |
| Invalid actions format | `M_BAD_JSON` | 400 |

---

## 2. Control Paths

### Standard Control Path Template

```
Request → [Middleware: CORS + rate limit] → Router.route() →
  [Auth: require_auth(token)] → [Validation] → [Handler] → ApiResult →
  [Serialize: JSON body or Matrix error] → HTTP Response
```

---

### CP-01 — POST /_matrix/client/v3/login

```
POST /login {user, password, type}
  │
  ├─→ router.route("POST", "/login", body, None)
  │     │
  │     └─→ handle_login(body)
  │           │
  │           ├─→ [Stub path] → always 200 + syt_stub_N token
  │           │
  │           └─→ [Live path via handlers.gleam]
  │                 │
  │                 ├─→ extract username from body (string split)
  │                 ├─→ kv.find_user(store, username)
  │                 │     ├─→ Error(_) → 403 M_FORBIDDEN "User not found"
  │                 │     └─→ Ok(user) →
  │                 │           ├─→ password_verify(user.password_hash, provided)
  │                 │           │     ├─→ False → 403 M_FORBIDDEN "Invalid password"
  │                 │           │     └─→ True →
  │                 │           │           ├─→ token = "syt_" <> username <> "_" <> ts
  │                 │           │           ├─→ kv.add_token(store, token, user_id)
  │                 │           │           └─→ 200 {access_token, device_id, user_id, ...}
  │                 │
  │                 └─→ Failure: 400 M_BAD_JSON if body not parseable
```

**Failure branches**: 400 (malformed body), 403 (bad credentials), 429 (rate limited)

---

### CP-02 — POST /_matrix/client/v3/register

```
POST /register {username, password, auth?}
  │
  ├─→ router.route("POST", "/register", body, None)
  │     │
  │     └─→ handle_register(body)
  │           │
  │           ├─→ string.contains(body, "\"username\"") || string.contains(body, "\"auth\"")
  │           │     │
  │           │     ├─→ True → 200 + syt_reg_N token (no validation)
  │           │     └─→ False → 401 {session, flows:[{stages:["m.login.dummy"]}]}
  │           │
  │           └─→ No duplicate check, no username validation
```

**Failure branches**: None in current stub — always 200 or 401

**Missing**: M_USER_IN_USE (400), M_INVALID_USERNAME (400), M_LIMIT_EXCEEDED (429)

---

### CP-03 — GET /_matrix/client/v3/sync

```
GET /sync?since=sN&timeout=30000&filter=0
  │
  ├─→ require_auth(token) → 401 M_MISSING_TOKEN if no token
  │
  └─→ handle_sync(token, path)
        │
        ├─→ [Stub] → 200 + static empty sync response
        │     next_batch: "s0_0_0_0_0_0_0_0_0"
        │
        └─→ [Live via sync_engine.gleam]
              │
              ├─→ parse_batch_token(since)
              │     ├─→ Ok(ts) → incremental_sync(state, store, since)
              │     │     ├─→ rooms_for_user(store, user_id)
              │     │     ├─→ events_in_room where ts > since_ts, limit 100
              │     │     └─→ 200 {next_batch, joined_rooms, ...}
              │     └─→ Error → initial_sync(state, store)
              │           ├─→ rooms_for_user(store, user_id)
              │           ├─→ state_events_in_room(store, room_id)
              │           ├─→ events_in_room(store, room_id, 20)
              │           └─→ 200 {next_batch, joined_rooms, ...}
```

**Failure branches**: 401 (no/invalid token), 400 (malformed filter)

---

### CP-04 — PUT /_matrix/client/v3/rooms/{roomId}/send/{eventType}/{txnId}

```
PUT /rooms/!abc:localhost/send/m.room.message/txnId_123
  body: {"msgtype":"m.text","body":"hello"}
  │
  ├─→ route_room_operation("PUT", path, body, token)
  │     │
  │     └─→ room_op("PUT", room_id, "send/m.room.message/txnId_123", body, token)
  │           │
  │           └─→ require_auth(token) → 401 if no token
  │                 │
  │                 └─→ handle_send_event(token, room_id, sub_path, body)
  │                       │
  │                       ├─→ [Current stub]: generate new event_id every call (NO idempotency)
  │                       │     event_id = "$" <> erlang_now_ms() <> ":localhost"
  │                       │     → 200 {event_id}
  │                       │
  │                       └─→ [Should be]:
  │                             ├─→ extract txnId from sub_path (last segment)
  │                             ├─→ check idempotency_store[room_id][txnId]
  │                             │     ├─→ Some(existing_event_id) → 200 {event_id: existing}
  │                             │     └─→ None →
  │                             │           ├─→ validate body (not empty, valid JSON)
  │                             │           ├─→ auth.check_event(...)
  │                             │           ├─→ event_dag.append(...)
  │                             │           ├─→ store idempotency_store[room_id][txnId] = event_id
  │                             │           └─→ 200 {event_id}
```

**Failure branches**: 401 (no token), 400 (empty body), 403 (power level), 404 (room not found)

---

### CP-05 — POST /_matrix/client/v3/createRoom

```
POST /createRoom {name?, topic?, preset?, invite?, room_version?}
  │
  ├─→ require_auth(token) → 401
  │
  └─→ handle_create_room(token, body)
        │
        ├─→ [Stub]: generates room_id = "!" <> ts <> ":localhost" → 200
        │
        └─→ [Live via room_lifecycle.gleam]
              │
              ├─→ parse_create_params(body) → CreateRoomParams
              ├─→ generate_room_id(server_name, timestamp)
              ├─→ create_initial_events(params, room_id, creator)
              │     ├─→ m.room.create
              │     ├─→ m.room.member (creator joins)
              │     ├─→ m.room.power_levels
              │     ├─→ m.room.join_rules (from preset)
              │     ├─→ m.room.history_visibility (from preset)
              │     ├─→ m.room.name (if name present)
              │     ├─→ m.room.topic (if topic present)
              │     └─→ m.room.member (invites)
              ├─→ kv.add_room(store, room)
              └─→ 200 {room_id}
```

**Failure branches**: 401 (no token), 400 (invalid room_version), 400 (bad alias), 403 (registration required)

---

### CP-06 — POST /_matrix/client/v3/keys/upload

```
POST /keys/upload {device_keys?, one_time_keys?}
  │
  ├─→ require_auth(token) → 401
  │
  └─→ handle_keys_upload(token, body)
        │
        ├─→ [Stub]: returns {one_time_key_counts: {curve25519: 50, signed_curve25519: 50}}
        │
        └─→ [Should be]:
              ├─→ validate body not empty → 400 M_NOT_JSON
              ├─→ parse device_keys if present
              │     └─→ encryption.upload_device_keys(state, device_keys)
              ├─→ parse one_time_keys if present
              │     └─→ encryption.upload_one_time_keys(state, keys)
              └─→ 200 {one_time_key_counts: actual_counts}
```

**Failure branches**: 401, 400 (malformed), 400 (unknown algorithm)

---

### CP-07 — GET /_matrix/media/v3/download/{serverName}/{mediaId}

```
GET /media/v3/download/localhost/media_1234
  │
  ├─→ [No auth required for public media]
  │
  └─→ handle_media_download(path)
        │
        ├─→ [Stub]: 404 M_NOT_FOUND "Media not found (stub)"
        │
        └─→ [Should be]:
              ├─→ parse_mxc_uri or extract serverName/mediaId from path
              ├─→ if serverName != own_server_name → fetch from remote (federation)
              ├─→ find_media(store, media_id)
              │     ├─→ Error → 404 M_NOT_FOUND
              │     └─→ Ok(file) → 200 + Content-Type + bytes
              └─→ Check content_type, stream body
```

**Failure branches**: 404 (not found), 403 (access denied), 413 (thumbnail too large), 502 (remote fetch failed)

---

### CP-08 — PUT /_matrix/federation/v1/send/{txnId}

```
PUT /_matrix/federation/v1/send/txnId_001
  Authorization: X-Matrix origin=remote.server,...
  body: {pdus:[...], edus:[...]}
  │
  ├─→ route_federation("PUT", path, body)
  │
  └─→ route_federation_prefix("PUT", path)
        │
        ├─→ starts_with("/_matrix/federation/v1/send/")
        │     └─→ [Stub]: 200 {pdus: {}}
        │
        └─→ [Should be]:
              ├─→ verify_signature(request) → 401 M_UNAUTHORIZED if invalid
              ├─→ parse PDUs from body
              ├─→ for each PDU:
              │     ├─→ auth.check_event(pdu, state_at_point)
              │     │     ├─→ Denied(reason) → rejected[event_id] = reason
              │     │     └─→ Authorized → event_dag.append(pdu)
              │     └─→ persist accepted PDUs
              └─→ 200 {pdus: {event_id: error_for_rejected, ...}}
```

**Failure branches**: 401 (bad signature), 400 (malformed), 403 (not in room)

---

## 3. Data Paths

### DP-01 — Event Ingestion Pipeline

```
Client PUT /send/{eventType}/{txnId}
  ↓
[Validation]
  body: String (JSON)
  → check not empty → M_NOT_JSON
  → check valid JSON → M_BAD_JSON
  → check required fields (msgtype for m.room.message) → M_BAD_JSON

[Auth Check]
  auth.check_event(context)
  → get power levels from room state
  → check sender power >= event_power_level(event_type)
  → check membership == MJoin
  → Authorized or Denied(reason)

[DAG Append]
  event_dag.append(dag, pdu)
  → validate_event: not duplicate, prev_events exist
  → update heads: remove prev_events from heads, add new event
  → returns updated DAG

[State Mutation]
  for state events: update room_state map (type+state_key → event)
  for timeline events: append to timeline

[Storage]
  kv.add_event(store, event) → updated Store

[Fanout]
  sync_engine: incremental sync picks up events with ts > client's since_ts
  presence: update last_active_ts for sender
  push: should_notify(rules, event_type, content) → trigger push
  federation: if room has remote members → federation transaction
```

### DP-02 — Federation Data Path

```
Remote Server PUT /send/{txnId}
  ↓
[Signature Verification]
  parse X-Matrix Authorization header
  → origin, key_id, signature
  → verify Ed25519 signature over canonical JSON
  → if invalid → 401

[PDU Processing]
  for each pdu in body.pdus:
    → validate event_id matches hash
    → fetch auth chain if needed (backfill)
    → state_at(dag, prev_events) → room state at point
    → auth.check_event(context_with_historical_state)
    → if Authorized → event_dag.append(dag, pdu)
    → if Denied → add to rejected map

[State Resolution]
  if conflicting states from multiple prev_events:
    state_resolution.resolve(state_sets, auth_chain_fn)
    → separate unconflicted / conflicted
    → resolve_conflict via mainline_ordering

[Response]
  200 {pdus: {rejected_event_id: error_info, ...}}
  (accepted PDUs are NOT listed in response — only rejections)
```

### DP-03 — Key Distribution Path

```
Client A uploads device keys:
  PUT /keys/upload → encryption.upload_device_keys(state, keys)
  → stored in EncryptionState.device_keys_uploaded = True

Client B queries keys:
  POST /keys/query {device_keys: {@user_a: []}}
  → handle_keys_query(token, body)
  → for each user in request:
    → find user's devices from store
    → return DeviceKeys for each device
  → 200 {device_keys: {@user_a: {DEVICE_ID: {...}}}}

Client B claims OTK:
  POST /keys/claim {one_time_keys: {@user_a: {DEVICE_ID: "signed_curve25519"}}}
  → find OTK for user_a/DEVICE_ID of requested algorithm
  → consume (remove) OTK from store (one-time!)
  → 200 {one_time_keys: {@user_a: {DEVICE_ID: {key_id: key_data}}}}
  → if no OTK available → return empty (client falls back to Olm pre-key)
```

### DP-04 — Media Storage Path

```
Client POST /upload (Content-Type: image/jpeg, body: bytes)
  ↓
[Size Check]
  media.upload(store, content_type, filename, size_bytes, uploader, server_name, ts)
  → if size > max_size_bytes → UploadTooLarge → 413

[Storage]
  media_id = "media_" <> ts
  file = MediaFile(media_id, server_name, content_type, filename, size_bytes, ts, uploader)
  store.files = [file, ...store.files]
  store.total_bytes += size_bytes
  → UploadOk(mxc_uri)

[Response]
  200 {"content_uri": "mxc://localhost/media_N"}

[Download]
  GET /download/localhost/media_N
  → find_media(store, "media_N")
  → Error → 404
  → Ok(file) → serve file bytes with file.content_type
```

---

## 4. Robustness Gap Analysis

### GAP-01 — No Body Validation (CRITICAL)

**Affected endpoints**: All POST/PUT handlers
**Impact**: Empty body or non-JSON body reaches handler logic

**Current code**:
```gleam
fn handle_send_event(_token, _room_id, _sub_path, _body) -> ApiResult {
  // _body never checked for emptiness or validity
  let event_id = "$" <> int.to_string(erlang_now_ms()) <> ":localhost"
  JsonResponse(200, ...)
}
```

**Required**:
```gleam
if string.is_empty(string.trim(body)) {
  ErrorResponse(400, "M_NOT_JSON", "Request body is empty")
}
```

**Matrix spec**: §4.2.1 — If the request has no body, or the body is not valid JSON, the server MUST respond with M_NOT_JSON.

---

### GAP-02 — No Idempotency for Event Sending (HIGH)

**Affected endpoint**: PUT /rooms/{roomId}/send/{eventType}/{txnId}
**Impact**: Duplicate events created on network retry

**Current code**:
```gleam
fn handle_send_event(...) -> ApiResult {
  let event_id = "$" <> int.to_string(erlang_now_ms()) <> ":localhost"
  // txnId extracted from sub_path but NEVER USED
  ...
}
```

**Required**: Store `{room_id, txnId} → event_id` in a persistent map. Return cached event_id on replay.

**Matrix spec**: §10.6.1 — The server MUST ensure that the event is not sent to the room more than once for a given transaction ID.

---

### GAP-03 — No Token Validation (CRITICAL)

**Affected**: All authenticated endpoints
**Impact**: Any non-empty string is accepted as a valid token

**Current code**:
```gleam
fn require_auth(token: Option(String), handler) -> ApiResult {
  case token {
    Some(t) -> handler(t)  // t is never verified against store
    None -> ErrorResponse(401, "M_MISSING_TOKEN", ...)
  }
}
```

**Required**: `kv.token_exists(store, t)` check before calling handler. Return `M_UNKNOWN_TOKEN` if not found.

**Matrix spec**: §4.2.2 — If the request's access token does not match any known token, the server MUST respond with M_UNKNOWN_TOKEN.

---

### GAP-04 — Admin Returns 501 with M_UNRECOGNIZED (LOW)

**Current**: `ErrorResponse(501, "M_UNRECOGNIZED", "Admin API not yet implemented")`
**Correct**: Should be 404 M_UNRECOGNIZED for unknown paths, or 501 M_UNRECOGNIZED is acceptable for not-implemented.

Per spec, 501 is valid for "not yet implemented" functionality. M_UNRECOGNIZED is correct here. Low priority.

---

### GAP-05 — Federation Signature Always Accepted (HIGH)

**Module**: `federation/transport.gleam::verify_signature`
```gleam
fn verify_signature(req: SignedRequest) -> Bool {
  string.starts_with(req.signature, "stub_sig_")  // Always True for stubs
}
```

**Required**: Actual Ed25519 verification using server's public key from `/_matrix/key/v2/server/{keyId}`.

---

### GAP-06 — Push Condition Matching Uses String Contains (MEDIUM)

**Module**: `matrix/push.gleam::condition_matches`
```gleam
EventMatch(key: _, pattern: pattern) ->
  string.contains(content, pattern)  // Not JSON field lookup
ContainsDisplayName ->
  string.contains(content, "display_name")  // Not user-specific
```

**Required**: Parse content as JSON, extract the nested field at `key`, compare against pattern with glob matching per Matrix spec §11.12.3.

---

### GAP-07 — No Rate Limiting Wire-Up (MEDIUM)

**Current**: `middleware.gleam` has full rate limiting logic (`rate_limit_check`, `RateLimitState`) but it is not called from the router or HTTP server dispatcher. The middleware functions exist but are dead code.

**Required**: Wire `rate_limit_check` into the request pipeline before routing, returning `ErrorResponse(429, "M_LIMIT_EXCEEDED", ...)` when `is_allowed = False`.

---

### GAP-08 — Sync Returns Hardcoded Empty Response (HIGH)

**Current**: `handle_sync` in router.gleam returns static `"s0_0_0_0_0_0_0_0_0"` with no room data.

**Impact**: FluffyChat shows no messages, no rooms, no history after login.

**Required**: Call `sync_engine.initial_sync` or `sync_engine.incremental_sync` based on `since` parameter. Wire through HandlerContext.

---

### Summary Table

| Gap | Severity | Effort | Impact |
|-----|----------|--------|--------|
| GAP-01 Body validation | CRITICAL | Low | Prevents bad data reaching handlers |
| GAP-02 Idempotency | HIGH | Medium | Prevents duplicate events |
| GAP-03 Token validation | CRITICAL | Low | Prevents unauthorized access |
| GAP-04 Admin errcode | LOW | Trivial | Spec conformance |
| GAP-05 Federation sig | HIGH | High | Real federation security |
| GAP-06 Push conditions | MEDIUM | Medium | Correct notification logic |
| GAP-07 Rate limit wiring | MEDIUM | Low | DDoS protection |
| GAP-08 Sync stub | HIGH | Medium | Core client functionality |
