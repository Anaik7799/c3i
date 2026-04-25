# Matrix Standard Compliance Checklist — Sutra v22.10.0

**Spec Version**: Matrix Client-Server API v1.13 / Server-Server API v1.13
**Router**: `sutra_server/src/sutra_server/api/router.gleam`
**Live Handlers**: `sutra_server/src/sutra_server/api/handlers.gleam` + `handlers_e2ee.gleam` + `handlers_ephemeral.gleam` + `handlers_rooms.gleam` + `handlers_federation.gleam` + `handlers_misc.gleam`
**Updated**: 2026-04-18

Legend: [x] = Implemented, [-] = Stubbed (returns valid shape, no real logic), [ ] = Missing

---

## 1. API Standards (§2.1 — All Endpoints)

- [x] All successful responses use `application/json` Content-Type
- [x] Error responses include `errcode` field (e.g. `M_NOT_FOUND`)
- [x] Error responses include `error` field (human-readable string)
- [-] Transaction IDs for PUT events are accepted but NOT checked for idempotency — duplicate sends create duplicate events
- [ ] Rate limiting: no `429 M_LIMIT_EXCEEDED` with `retry_after_ms` is implemented
- [x] `/_matrix/client/versions` advertises v1.1 through v1.18
- [x] `unstable_features` object present in versions response
- [x] Unknown endpoints return `404 M_NOT_FOUND`
- [ ] HTTP OPTIONS not handled (CORS preflight)
- [ ] `X-Matrix` auth header for federation not validated

---

## 2. Discovery (§2.2)

- [x] `GET /.well-known/matrix/client` — returns `m.homeserver.base_url`
- [x] `GET /.well-known/matrix/server` — returns `m.server`
- [x] `GET /_matrix/client/versions` — stable version list
- [x] `GET /_matrix/key/v2/server` — returns `server_name`, `verify_keys`, `valid_until_ts`
- [ ] `GET /_matrix/key/v2/server/{keyId}` — per-key fetch not separated (falls through to same handler)
- [-] `verify_keys` in server key response is an empty object — no real Ed25519 key advertised
- [-] `signatures` in server key response is empty — server does not sign its own key document

---

## 3. Registration (§5.5 UIA)

- [x] `GET /_matrix/client/v3/register` — returns flows list
- [x] `POST /_matrix/client/v3/register` with `username` + `password` — returns 200 with credentials
- [x] `POST /_matrix/client/v3/register` with no `username` — returns 401 UIA challenge with `session` + `flows`
- [x] Duplicate username registration returns `400 M_USER_IN_USE`
- [x] Registration response contains `access_token`, `device_id`, `user_id`, `home_server`
- [-] `device_id` in request body is ignored — always returns `"SUTRA_DEVICE"`
- [ ] Guest registration (`is_guest` flag) not supported
- [ ] `inhibit_login` flag not supported — login credentials always returned
- [ ] Registration token (MSC3231) not implemented
- [ ] `GET /_matrix/client/v3/register/available` always returns `true` (does not actually check DB)
- [ ] Email / phone 3PID verification in registration flow not functional (returns stub `sid`)

---

## 4. Login (§5.4)

- [x] `GET /_matrix/client/v3/login` — returns `m.login.password` flow
- [x] `POST /_matrix/client/v3/login` with valid credentials — returns `access_token`, `device_id`, `user_id`, `well_known`
- [x] Login with missing username returns `400 M_MISSING_PARAM`
- [x] Login with unknown username returns `403 M_FORBIDDEN`
- [x] Login with wrong password returns `403 M_FORBIDDEN`
- [x] `identifier.user` format parsed (FluffyChat style)
- [-] `device_id` from login request body is ignored — always issues `"SUTRA_DEVICE"`
- [-] Access token is `syt_<username>_<timestamp>` — not a cryptographically random token
- [ ] `m.login.token` flow not supported
- [ ] SSO login returns `404 M_UNRECOGNIZED` (intentional for now)
- [ ] OIDC (`/_matrix/client/v1/auth_metadata`) returns `404` (intentional)
- [ ] Soft logout (`soft_logout: true`) flag not implemented
- [ ] `POST /_matrix/client/v3/logout/all` is a stub returning `{}`

---

## 5. Account Management (§5.7)

- [x] `GET /_matrix/client/v3/account/whoami` — returns `user_id`, `device_id`, `is_guest`
- [-] `POST /_matrix/client/v3/account/password` — stub, always returns `{}`
- [-] `POST /_matrix/client/v3/account/deactivate` — stub, returns `id_server_unbind_result: "success"`
- [-] `GET /_matrix/client/v3/account/3pid` — returns empty threepids array
- [-] `POST /_matrix/client/v3/account/3pid/add` — stub
- [-] `POST /_matrix/client/v3/account/3pid/bind` — stub
- [-] `POST /_matrix/client/v3/account/3pid/delete` — stub success
- [-] `POST /_matrix/client/v3/account/3pid/unbind` — stub success
- [-] `POST /_matrix/client/v3/account/password/email/requestToken` — stub `sid`
- [-] `POST /_matrix/client/v3/account/password/msisdn/requestToken` — stub `sid`
- [ ] `GET /_matrix/client/v3/account/whoami` missing `device_id` per spec when no device provided

---

## 6. Capabilities (§5.8)

- [x] `GET /_matrix/client/v3/capabilities` — requires auth
- [x] `m.change_password.enabled` present
- [x] `m.room_versions.default` = `"11"` and `available` map includes v1–v11
- [-] `m.set_displayname` / `m.set_avatar_url` present but display name + avatar not fully stored
- [ ] `m.3pid_changes` capability absent

---

## 7. Sync (§6.2)

- [x] `GET /_matrix/client/v3/sync` — requires auth, returns shape-valid response
- [x] Initial sync (no `since`) returns `next_batch`, `rooms.join/invite/leave/knock`, `presence`, `account_data`, `to_device`, `device_lists`, `device_one_time_keys_count`
- [x] Incremental sync with `since` token accepted
- [-] `next_batch` token is static `"s0_0_0_0_0_0_0_0_0"` — not a real pagination cursor
- [ ] `timeout` query parameter (long-polling) not implemented — returns immediately
- [ ] Sliding sync (`/_matrix/client/v1/sync` MSC3575) routes to same handler as v3/sync
- [ ] Filter ID from `POST /user/{userId}/filter` not applied to sync results
- [ ] `full_state` parameter not implemented
- [ ] `set_presence` parameter not implemented

---

## 8. Room Creation (§9.1)

- [x] `POST /_matrix/client/v3/createRoom` — requires auth, returns `room_id`
- [x] `name`, `topic`, `preset`, `room_version`, `invite` fields parsed
- [x] Room version defaults to `"11"`
- [x] `private_chat` preset is default
- [-] `initial_state` array accepted but not applied to room state
- [-] `is_direct` flag accepted but not stored
- [ ] `power_level_content_override` not handled
- [ ] `creation_content` not merged into `m.room.create` event
- [ ] Invited users don't receive invite events in their sync

---

## 9. Room Membership (§9.4–9.7)

- [x] `POST /_matrix/client/v3/join/{roomIdOrAlias}` — resolves alias, applies MJoin
- [x] `POST /_matrix/client/v3/rooms/{roomId}/join` — direct room join
- [x] `POST /_matrix/client/v3/rooms/{roomId}/leave` — applies MLeave
- [x] `POST /_matrix/client/v3/rooms/{roomId}/invite` — requires auth (handler stub via router)
- [x] `POST /_matrix/client/v3/rooms/{roomId}/kick` — requires auth
- [x] `POST /_matrix/client/v3/rooms/{roomId}/ban` — requires auth
- [x] `POST /_matrix/client/v3/rooms/{roomId}/unban` — requires auth
- [x] `POST /_matrix/client/v3/rooms/{roomId}/forget` — requires auth
- [x] `POST /_matrix/client/v3/knock/{roomIdOrAlias}` — returns room_id
- [x] `POST /_matrix/client/v3/rooms/{roomId}/upgrade` — returns `replacement_room`
- [ ] Joining non-existent room returns `404` via handlers.gleam but router.gleam stub returns `200`
- [ ] Power level checks on kick/ban not enforced
- [ ] Invite sends the invited user a sync event in their next poll
- [ ] `knock` join rule not validated against room state

---

## 10. Sending Events (§11.1)

- [x] `PUT /_matrix/client/v3/rooms/{roomId}/send/{eventType}/{txnId}` — returns `event_id`
- [x] Non-member send returns `403 M_FORBIDDEN`
- [x] Missing room returns `404 M_NOT_FOUND`
- [x] Invalid room_id format returns `400 M_BAD_REQUEST`
- [-] Transaction ID (`txnId`) stored in path but NOT checked — duplicate PUT creates duplicate event
- [-] `event_id` format is `$<timestamp><servername>` — not an RFC 6901 hash-based ID
- [ ] `age_ts` / `unsigned.age` not set on sent events
- [ ] `prev_events` is always empty — no real DAG linkage from send handler

---

## 11. State Events (§11.2)

- [x] `PUT /_matrix/client/v3/rooms/{roomId}/state/{eventType}` — requires auth
- [x] `PUT /_matrix/client/v3/rooms/{roomId}/state/{eventType}/{stateKey}` — requires auth
- [x] `GET /_matrix/client/v3/rooms/{roomId}/state` — returns state events array (auth-gated, member-only)
- [x] `GET /_matrix/client/v3/rooms/{roomId}/state/{eventType}/{stateKey}` — returns event content
- [ ] Non-member GET state returns `403` from handlers but stub in router returns `{}` for unknown sub-paths
- [ ] Power level enforcement on state events not implemented

---

## 12. Redaction (§11.3)

- [x] `PUT /_matrix/client/v3/rooms/{roomId}/redact/{eventId}/{txnId}` — returns `event_id`
- [-] Redaction creates a new event ID but does not actually strip `content` from the target event
- [ ] Redacting non-existent event should return `404` — currently always returns `200`
- [ ] Power level enforcement on redaction not implemented

---

## 13. Room History (§11.4)

- [x] `GET /_matrix/client/v3/rooms/{roomId}/messages` — returns `start`, `end`, `chunk`, `state`
- [x] `GET /_matrix/client/v3/rooms/{roomId}/event/{eventId}` — returns event object
- [x] `GET /_matrix/client/v3/rooms/{roomId}/context/{eventId}` — returns `event`, `events_before`, `events_after`, `state`
- [-] `messages` response `chunk` is always empty — no real event pagination
- [ ] `dir` (forward/backward), `limit`, `from`, `to` query parameters on `/messages` not parsed
- [ ] `/context/{eventId}` returns empty arrays — not fetching real surrounding events

---

## 14. Receipts and Read Markers (§11.5)

- [x] `POST /_matrix/client/v3/rooms/{roomId}/receipt/{receiptType}/{eventId}` — requires auth
- [x] `POST /_matrix/client/v3/rooms/{roomId}/read_markers` — requires auth
- [-] Both are stubs — receipts not persisted or surfaced in sync

---

## 15. Typing Notifications (§11.6)

- [x] `PUT /_matrix/client/v3/rooms/{roomId}/typing/{userId}` — requires auth
- [-] Typing state not broadcast to other room members in sync

---

## 16. Room Directory and Aliases (§9.8)

- [x] `GET /_matrix/client/v3/directory/room/{roomAlias}` — returns `404 M_NOT_FOUND` (no aliases stored)
- [x] `PUT /_matrix/client/v3/directory/room/{roomAlias}` — requires auth, stub
- [x] `DELETE /_matrix/client/v3/directory/room/{roomAlias}` — requires auth, stub
- [x] `GET /_matrix/client/v3/rooms/{roomId}/aliases` — returns empty aliases array
- [x] `GET /_matrix/client/v3/publicRooms` — returns shape-valid empty list
- [x] `POST /_matrix/client/v3/publicRooms` — requires auth, filtered stub
- [x] `GET /_matrix/client/v3/directory/list/room/{roomId}` — returns `"private"`
- [x] `PUT /_matrix/client/v3/directory/list/room/{roomId}` — requires auth, stub

---

## 17. Profile (§9.3)

- [x] `GET /_matrix/client/v3/profile/{userId}` — returns `displayname`, `avatar_url`
- [x] `PUT /_matrix/client/v3/profile/{userId}/displayname` — requires auth
- [x] `PUT /_matrix/client/v3/profile/{userId}/avatar_url` — requires auth
- [-] Profile changes not persisted — GET always returns user_id as displayname
- [ ] `GET /_matrix/client/v3/profile/{userId}/displayname` — not separately routed (falls to prefix handler)
- [ ] `GET /_matrix/client/v3/profile/{userId}/avatar_url` — not separately routed

---

## 18. Presence (§11.7)

- [x] `GET /_matrix/client/v3/presence/{userId}/status` — returns `presence: "offline"`
- [x] `PUT /_matrix/client/v3/presence/{userId}/status` — requires auth
- [-] Presence state not persisted or surfaced in sync `presence.events`

---

## 19. User Directory (§11.8)

- [x] `POST /_matrix/client/v3/user_directory/search` — requires auth, returns `results`, `limited`
- [-] Search always returns empty results — not querying the user store

---

## 20. Account Data (§11.9)

- [x] `GET /_matrix/client/v3/user/{userId}/account_data/{type}` — requires auth
- [x] `PUT /_matrix/client/v3/user/{userId}/account_data/{type}` — requires auth
- [x] `GET /_matrix/client/v3/rooms/{roomId}/account_data/{type}` (room-scoped) — requires auth
- [x] `PUT /_matrix/client/v3/rooms/{roomId}/account_data/{type}` (room-scoped) — requires auth
- [-] Account data not persisted — GET always returns `{}`

---

## 21. Devices (§5.6)

- [x] `GET /_matrix/client/v3/devices` — requires auth, returns empty device list
- [x] `GET /_matrix/client/v3/devices/{deviceId}` — returns stub device info
- [x] `PUT /_matrix/client/v3/devices/{deviceId}` — requires auth
- [x] `DELETE /_matrix/client/v3/devices/{deviceId}` — requires auth
- [x] `POST /_matrix/client/v3/delete_devices` — requires auth
- [-] All device operations are stubs — device list is always empty

---

## 22. End-to-End Encryption — Keys (§10)

- [x] `POST /_matrix/client/v3/keys/upload` — requires auth, returns `one_time_key_counts`
- [x] `POST /_matrix/client/v3/keys/query` — requires auth, returns `device_keys`, `failures`
- [x] `POST /_matrix/client/v3/keys/claim` — requires auth, returns `one_time_keys`, `failures`
- [x] `GET /_matrix/client/v3/keys/changes` — requires auth, returns `changed`, `left`
- [x] `POST /_matrix/client/v3/keys/device_signing/upload` — requires auth
- [x] `POST /_matrix/client/v3/keys/signatures/upload` — requires auth, returns `failures: {}`
- [-] Key counts in `keys/upload` response are hardcoded `50` — not counting real stored keys
- [-] `keys/query` always returns empty `device_keys` — not looking up real device key data
- [ ] Cross-signing verification not implemented

---

## 23. Key Backup (§10.7)

- [x] `GET /_matrix/client/v3/room_keys/version` — returns `404 M_NOT_FOUND` (spec-correct: no backup)
- [x] `PUT /_matrix/client/v3/room_keys/version` — creates backup version, returns `version: "1"`
- [x] `DELETE /_matrix/client/v3/room_keys/version/{version}` — requires auth, stub `{}`
- [x] `GET /_matrix/client/v3/room_keys/keys` — returns `rooms: {}`
- [x] `PUT /_matrix/client/v3/room_keys/keys` — returns `count: 0, etag: "0"`
- [x] `DELETE /_matrix/client/v3/room_keys/keys` — returns `count: 0, etag: "0"`
- [x] `GET /_matrix/client/v3/room_keys/keys/{roomId}` — prefix-matched, returns empty sessions
- [x] `PUT /_matrix/client/v3/room_keys/keys/{roomId}` — prefix-matched, returns count/etag
- [x] `DELETE /_matrix/client/v3/room_keys/keys/{roomId}` — prefix-matched, stub
- [-] Key backup data not persisted

---

## 24. Push Notifications (§14)

- [x] `GET /_matrix/client/v3/pushers` — requires auth, returns empty pushers
- [x] `POST /_matrix/client/v3/pushers/set` — requires auth
- [x] `GET /_matrix/client/v3/notifications` — requires auth, returns `next_token`, `notifications`
- [x] `GET /_matrix/client/v3/pushrules/` — requires auth, returns global rule set
- [x] `GET /_matrix/client/v3/pushrules/{scope}/{kind}/{ruleId}` — prefix-matched
- [x] `PUT /_matrix/client/v3/pushrules/{scope}/{kind}/{ruleId}` — prefix-matched
- [x] `DELETE /_matrix/client/v3/pushrules/{scope}/{kind}/{ruleId}` — prefix-matched
- [x] `GET /_matrix/client/v3/pushrules/{scope}/{kind}/{ruleId}/enabled` — returns `enabled: true`
- [x] `PUT /_matrix/client/v3/pushrules/{scope}/{kind}/{ruleId}/enabled` — stub `{}`
- [x] `GET /_matrix/client/v3/pushrules/{scope}/{kind}/{ruleId}/actions` — returns `actions`
- [x] `PUT /_matrix/client/v3/pushrules/{scope}/{kind}/{ruleId}/actions` — stub `{}`
- [-] Push rules not evaluated against incoming events

---

## 25. Filters (§6.1)

- [x] `POST /_matrix/client/v3/user/{userId}/filter` — returns `filter_id: "0"`
- [x] `GET /_matrix/client/v3/user/{userId}/filter/{filterId}` — returns stub filter
- [-] Filter ID is always `"0"` — filters not stored or applied to sync

---

## 26. Tags (§11.10)

- [x] `GET /_matrix/client/v3/user/{userId}/rooms/{roomId}/tags` — returns empty `tags`
- [x] `PUT /_matrix/client/v3/user/{userId}/rooms/{roomId}/tags/{tag}` — stub
- [x] `DELETE /_matrix/client/v3/user/{userId}/rooms/{roomId}/tags/{tag}` — stub

---

## 27. Joined Rooms (§9.2)

- [x] `GET /_matrix/client/v3/joined_rooms` — requires auth, returns empty `joined_rooms`
- [ ] Does not return rooms where the authenticated user's membership is `join`

---

## 28. Media (§13)

- [x] `POST /_matrix/media/v3/upload` — requires auth, returns `content_uri` as `mxc://`
- [x] `PUT /_matrix/media/v3/upload/{serverName}/{mediaId}` — requires auth (async upload)
- [x] `POST /_matrix/media/v1/create` — requires auth, returns `content_uri`, `unused_expires_at`
- [x] `GET /_matrix/media/v3/download/{serverName}/{mediaId}` — returns `404 M_NOT_FOUND` (stub)
- [x] `GET /_matrix/media/v3/download/{serverName}/{mediaId}/{fileName}` — returns `404`
- [x] `GET /_matrix/media/v3/thumbnail/{serverName}/{mediaId}` — returns `404`
- [x] `GET /_matrix/media/v3/config` — returns `m.upload.size: 104857600` (100 MB)
- [x] `GET /_matrix/media/v3/preview_url` — returns stub open graph data
- [ ] Media files not persisted to disk — upload metadata stored but body discarded
- [ ] Download does not serve real file content

---

## 29. Search (§11.11)

- [x] `POST /_matrix/client/v3/search` — requires auth
- [x] Response shape: `search_categories.room_events.{count, results, highlights}`
- [-] Search is a stub — always returns `count: 0, results: []`

---

## 30. Send-to-Device (§12)

- [x] `PUT /_matrix/client/v3/sendToDevice/{eventType}/{txnId}` — requires auth, returns `{}`
- [-] Messages not delivered to target devices in their sync `to_device.events`

---

## 31. Token Refresh (§5.9)

- [x] `POST /_matrix/client/v3/refresh` — returns new `access_token`, `expires_in_ms`
- [-] Old token not invalidated; refresh token not validated

---

## 32. OpenID (§10.10)

- [x] `POST /_matrix/client/v3/user/{userId}/openid/request_token` — returns token stub
- [x] `GET /_matrix/federation/v1/openid/userinfo` — returns `sub`

---

## 33. Admin (Synapse-compatible)

- [x] `GET|POST|PUT /_synapse/admin/**` — requires auth, returns `501 M_UNRECOGNIZED`
- [x] `GET|POST|PUT /_matrix/client/v3/admin/**` — same

---

## 34. Third-Party Protocols (§9.9)

- [x] `GET /_matrix/client/v3/thirdparty/protocols` — returns empty object
- [x] `GET /_matrix/client/v3/thirdparty/protocol/{protocol}` — stub
- [x] `GET /_matrix/client/v3/thirdparty/location` — empty array
- [x] `GET /_matrix/client/v3/thirdparty/location/{protocol}` — empty array
- [x] `GET /_matrix/client/v3/thirdparty/user` — empty array
- [x] `GET /_matrix/client/v3/thirdparty/user/{protocol}` — empty array

---

## 35. 3PID Token Requests

- [x] `POST /_matrix/client/v3/register/email/requestToken` — stub `sid`
- [x] `POST /_matrix/client/v3/register/msisdn/requestToken` — stub `sid`
- [x] `POST /_matrix/client/v3/account/password/email/requestToken` — stub `sid`
- [x] `POST /_matrix/client/v3/account/password/msisdn/requestToken` — stub `sid`

---

## 36. Server-Server (Federation) API (§S2S)

- [x] `GET /_matrix/federation/v1/version` — returns server name + version
- [x] `PUT /_matrix/federation/v1/send/{txnId}` — accepts PDU batch, returns `pdus: {}`
- [x] `GET /_matrix/federation/v1/event/{eventId}` — returns `pdus: []`
- [x] `GET /_matrix/federation/v1/state/{roomId}` — returns `pdus`, `auth_chain`
- [x] `GET /_matrix/federation/v1/state_ids/{roomId}` — returns `pdu_ids`, `auth_chain_ids`
- [x] `GET /_matrix/federation/v1/backfill/{roomId}` — returns `pdus: []`
- [x] `GET /_matrix/federation/v1/make_join/{roomId}/{userId}` — returns `403 M_FORBIDDEN`
- [x] `GET /_matrix/federation/v1/make_leave/{roomId}/{userId}` — returns `403 M_FORBIDDEN`
- [x] `PUT /_matrix/federation/v2/send_join/{roomId}/{eventId}` — returns `403`
- [x] `PUT /_matrix/federation/v2/send_leave/{roomId}/{eventId}` — returns `{}`
- [x] `PUT /_matrix/federation/v2/invite/{roomId}/{eventId}` — returns `event: {}`
- [x] `GET /_matrix/federation/v1/query/{queryType}` — returns `404`
- [x] `POST /_matrix/federation/v1/user/keys/query` — returns `device_keys: {}`
- [x] `POST /_matrix/federation/v1/user/keys/claim` — returns `one_time_keys: {}`
- [x] `GET /_matrix/federation/v1/hierarchy/{roomId}` — returns `rooms: []`
- [x] `GET /_matrix/federation/v1/publicRooms` — empty room list
- [ ] `X-Matrix` authorization header not validated on incoming federation requests
- [ ] PDU signature verification not performed
- [ ] Event authorization rules not enforced on incoming PDUs

---

## Compliance Summary

| Category | Routed | Functional | Stubbed | Missing |
|----------|--------|------------|---------|---------|
| Discovery | 7 | 5 | 2 | 1 |
| Auth (login/register/logout) | 8 | 6 | 2 | 3 |
| Account management | 10 | 2 | 8 | 1 |
| Capabilities | 1 | 1 | 0 | 1 |
| Sync | 2 | 2 | 0 | 4 |
| Room lifecycle | 12 | 8 | 4 | 2 |
| Events (send/state/redact) | 8 | 5 | 3 | 3 |
| Room history | 3 | 1 | 2 | 2 |
| Profile | 3 | 1 | 2 | 2 |
| Devices | 5 | 0 | 5 | 0 |
| E2EE keys | 6 | 0 | 6 | 1 |
| Key backup | 10 | 0 | 10 | 0 |
| Push notifications | 11 | 0 | 11 | 0 |
| Media | 8 | 2 | 6 | 0 |
| Search | 1 | 0 | 1 | 0 |
| Presence | 2 | 0 | 2 | 0 |
| Tags / Account data | 7 | 0 | 7 | 0 |
| Filters | 2 | 0 | 2 | 0 |
| Federation (S2S) | 16 | 3 | 13 | 3 |
| **Totals** | **122** | **36** | **86** | **23** |

**Routing coverage**: 122/159 = 76.7% (all reachable via `route/4`)
**Functional coverage**: 36/159 = 22.6% (real logic, real data)
**Stub coverage**: 86/159 = 54.1% (shape-correct, no real data)
**Gap (unrouted)**: 23/159 = 14.5%

---

## Known Spec Deviations

| ID | Deviation | Severity | Impact |
|----|-----------|----------|--------|
| DEV-001 | PUT idempotency not enforced — duplicate sends create duplicate events | HIGH | Breaks Matrix event semantics |
| DEV-002 | `device_id` from request always overridden with `"SUTRA_DEVICE"` | MEDIUM | Multi-device clients see collisions |
| DEV-003 | Access tokens are not cryptographically random (`syt_<name>_<ts>`) | HIGH | Predictable token — security gap |
| DEV-004 | No rate limiting on any endpoint | HIGH | Vulnerable to spam and DoS |
| DEV-005 | No `X-Matrix` federation auth validation | HIGH | Open federation relay |
| DEV-006 | `next_batch` sync token is static | HIGH | Incremental sync always returns same state |
| DEV-007 | Push rules never evaluated against events | MEDIUM | No notifications delivered |
| DEV-008 | `joined_rooms` always returns empty list | MEDIUM | Room list never populated |
| DEV-009 | Media bodies discarded on upload | MEDIUM | Download always returns 404 |
| DEV-010 | User directory search always returns empty | LOW | Search non-functional |
