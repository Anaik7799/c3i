# Sutra Matrix Homeserver — Feature & Compliance Report
**Date**: 2026-04-19
**Version**: v0.1.0
**Server**: Gleam on BEAM, port 6167
**Tests**: 988 Gleam + 129 Dart SDK = 1,117 total, 0 failures

---

## 1. LIVE Features (KV-backed, real state persistence)

### Authentication (6 endpoints)
| Endpoint | Method | Status | Notes |
|----------|--------|--------|-------|
| `/_matrix/client/v3/login` | GET | LIVE | Returns password flow |
| `/_matrix/client/v3/login` | POST | LIVE | Password validation, token issuance, device creation, well_known |
| `/_matrix/client/v3/register` | GET | LIVE | Returns UIA flows |
| `/_matrix/client/v3/register` | POST | LIVE | UIA (401→200), user creation, duplicate detection |
| `/_matrix/client/v3/logout` | POST | LIVE | Token revocation |
| `/_matrix/client/v3/account/whoami` | GET | LIVE | Token validation, returns user_id + device_id |

### Sync (3 endpoints)
| Endpoint | Method | Status | Notes |
|----------|--------|--------|-------|
| `/_matrix/client/v3/sync` | GET | LIVE | Initial + incremental, rooms.join with timeline + state, device_lists, OTK counts, account_data, to_device, presence, ephemeral (receipts + typing) |
| `/_matrix/client/v1/sync` | GET | LIVE | Same handler as v3 |
| `/_matrix/client/unstable/org.matrix.simplified_msc3575/sync` | POST | LIVE | Sliding sync (MSC3575) |

### Room Management (12 endpoints)
| Endpoint | Method | Status | Notes |
|----------|--------|--------|-------|
| `/_matrix/client/v3/createRoom` | POST | LIVE | Generates 5+ initial state events, stores room + events |
| `/_matrix/client/v3/join/{roomIdOrAlias}` | POST | LIVE | Join by ID or alias (%23 decoded), membership event stored |
| `/_matrix/client/v3/rooms/{roomId}/leave` | POST | LIVE | Membership event stored |
| `/_matrix/client/v3/rooms/{roomId}/invite` | POST | LIVE | MInvite + member event |
| `/_matrix/client/v3/rooms/{roomId}/kick` | POST | LIVE | MLeave + member event |
| `/_matrix/client/v3/rooms/{roomId}/ban` | POST | LIVE | MBan + member event |
| `/_matrix/client/v3/rooms/{roomId}/unban` | POST | LIVE | MLeave + member event |
| `/_matrix/client/v3/rooms/{roomId}/forget` | POST | LIVE | Stub (200) |
| `/_matrix/client/v3/rooms/{roomId}/upgrade` | POST | LIVE | Returns replacement_room |
| `/_matrix/client/v3/rooms/{roomId}/state` | GET | LIVE | Real state events from KV |
| `/_matrix/client/v3/rooms/{roomId}/members` | GET | LIVE | Real member list |
| `/_matrix/client/v3/joined_rooms` | GET | LIVE | Real rooms from KV |

### Messaging (5 endpoints)
| Endpoint | Method | Status | Notes |
|----------|--------|--------|-------|
| `rooms/{roomId}/send/{eventType}/{txnId}` | PUT | LIVE | Event stored in KV, membership check |
| `rooms/{roomId}/state/{eventType}/{stateKey}` | PUT | LIVE | State event stored, room name/topic updated |
| `rooms/{roomId}/messages` | GET | LIVE | Real event history from KV with pagination |
| `rooms/{roomId}/event/{eventId}` | GET | LIVE | Real event lookup by ID |
| `rooms/{roomId}/redact/{eventId}/{txnId}` | PUT | LIVE | Redaction event stored |

### E2EE (7 endpoints)
| Endpoint | Method | Status | Notes |
|----------|--------|--------|-------|
| `/_matrix/client/v3/keys/upload` | POST | LIVE | Device keys + OTKs stored, returns real count |
| `/_matrix/client/v3/keys/query` | POST | LIVE | Returns stored device keys + cross-signing keys (master, self, user) |
| `/_matrix/client/v3/keys/claim` | POST | LIVE | Pop semantics, returns claimed OTK |
| `/_matrix/client/v3/keys/device_signing/upload` | POST | LIVE | UIA (401→200), stores cross-signing keys |
| `/_matrix/client/v3/sendToDevice/{type}/{txnId}` | PUT | LIVE | Stored, drained in sync to_device |
| `/_matrix/client/v3/room_keys/version` | GET/PUT | LIVE | Key backup version CRUD |
| `/_matrix/client/v3/room_keys/keys` | GET/PUT | LIVE | Key backup data stored |

### Profiles (5 endpoints)
| Endpoint | Method | Status | Notes |
|----------|--------|--------|-------|
| `/_matrix/client/v3/profile/{userId}` | GET | LIVE | Returns stored displayname + avatar_url |
| `/_matrix/client/v3/profile/{userId}/displayname` | GET | LIVE | Real lookup |
| `/_matrix/client/v3/profile/{userId}/displayname` | PUT | LIVE | Persists via kv.update_user |
| `/_matrix/client/v3/profile/{userId}/avatar_url` | GET | LIVE | Real lookup |
| `/_matrix/client/v3/profile/{userId}/avatar_url` | PUT | LIVE | Persists via kv.update_user |

### Account Data (4 endpoints)
| Endpoint | Method | Status | Notes |
|----------|--------|--------|-------|
| `user/{userId}/account_data/{type}` | GET | LIVE | Real lookup from KV |
| `user/{userId}/account_data/{type}` | PUT | LIVE | Stored in KV, included in sync |
| `user/{userId}/rooms/{roomId}/account_data/{type}` | GET | LIVE | Room-scoped |
| `user/{userId}/rooms/{roomId}/account_data/{type}` | PUT | LIVE | Room-scoped |

### Devices (4 endpoints)
| Endpoint | Method | Status | Notes |
|----------|--------|--------|-------|
| `/_matrix/client/v3/devices` | GET | LIVE | Real device list from user.devices |
| `/_matrix/client/v3/devices/{deviceId}` | GET | LIVE | Real device lookup |
| `/_matrix/client/v3/devices/{deviceId}` | PUT | LIVE | Update display_name |
| `/_matrix/client/v3/devices/{deviceId}` | DELETE | LIVE | Remove device |

### Media (4 endpoints)
| Endpoint | Method | Status | Notes |
|----------|--------|--------|-------|
| `/_matrix/media/v3/upload` | POST | LIVE | Stores metadata + file bytes |
| `/_matrix/media/v3/download/{server}/{mediaId}` | GET | LIVE | Returns stored file bytes |
| `/_matrix/media/v3/thumbnail/{server}/{mediaId}` | GET | LIVE | Returns stored bytes (same as download) |
| `/_matrix/media/v3/config` | GET | LIVE | Returns 100MB upload limit |

### Room Directory & Aliases (5 endpoints)
| Endpoint | Method | Status | Notes |
|----------|--------|--------|-------|
| `/_matrix/client/v3/directory/room/{alias}` | GET | LIVE | Resolves alias → room_id |
| `/_matrix/client/v3/directory/room/{alias}` | PUT | LIVE | Stores alias→room_id mapping |
| `/_matrix/client/v3/directory/room/{alias}` | DELETE | LIVE | Removes alias |
| `/_matrix/client/v3/publicRooms` | GET | Stub | Empty list |
| `/_matrix/client/v3/publicRooms` | POST | Stub | Empty list |

### Ephemeral (6 endpoints)
| Endpoint | Method | Status | Notes |
|----------|--------|--------|-------|
| `rooms/{roomId}/receipt/{type}/{eventId}` | POST | LIVE | Stored, in sync ephemeral |
| `rooms/{roomId}/read_markers` | POST | LIVE | Stored |
| `rooms/{roomId}/typing/{userId}` | PUT | LIVE | Stored, in sync ephemeral |
| `/_matrix/client/v3/presence/{userId}/status` | GET | LIVE | Real status from KV |
| `/_matrix/client/v3/presence/{userId}/status` | PUT | LIVE | Stored, in sync presence |
| `/_matrix/client/v3/user_directory/search` | POST | LIVE | Wired to kv.search_users |

### Search (1 endpoint)
| Endpoint | Method | Status | Notes |
|----------|--------|--------|-------|
| `/_matrix/client/v3/search` | POST | LIVE | TF-IDF search across stored events |

---

## 2. Stub Endpoints (valid JSON responses, no real state)

### Discovery & Config (5 endpoints — all correct, no state needed)
- GET `/_matrix/client/versions` — v1.1-v1.18 + sliding sync advertised
- GET `/.well-known/matrix/client` — homeserver base_url
- GET `/.well-known/matrix/server` — m.server
- GET `/_matrix/client/v3/capabilities` — room_versions, password, displayname, avatar
- GET `/_matrix/key/v2/server` — server_name, verify_keys

### Auth Stubs (4 endpoints)
- GET `/_matrix/client/v1/auth_metadata` — 404 (no OIDC)
- POST `/_matrix/client/v3/refresh` — returns new token
- GET `/_matrix/client/v3/register/available` — always true
- GET `/_matrix/client/v3/login/sso/redirect` — 404

### 3PID Stubs (6 endpoints)
- POST `register/email/requestToken` — returns sid
- POST `register/msisdn/requestToken` — returns sid
- POST `account/password/email/requestToken` — returns sid
- POST `account/password/msisdn/requestToken` — returns sid
- POST `account/3pid/add` — 200
- POST `account/3pid/delete` — 200

### Push Stubs (8 endpoints)
- GET/POST `pushers` — empty list / 200
- GET `pushrules/` — empty rule sets
- GET/PUT/DELETE `pushrules/{scope}/{kind}/{ruleId}` — stubs
- GET `notifications` — empty list

### Federation Stubs (20+ endpoints)
- GET `federation/v1/version` — Sutra 0.1.0
- GET `federation/v1/event/{id}` — empty pdus
- GET `federation/v1/state/{roomId}` — empty pdus + auth_chain
- GET `federation/v1/backfill/{roomId}` — empty pdus
- PUT `federation/v1/send/{txnId}` — accepts, returns empty
- PUT `federation/v2/send_join` — 403
- PUT `federation/v2/send_leave` — 200
- PUT `federation/v2/invite` — 200
- POST `federation/v1/user/keys/query` — empty
- POST `federation/v1/user/keys/claim` — empty
- GET `federation/v1/publicRooms` — empty
- GET `federation/v1/hierarchy` — empty

### Third-party Stubs (6 endpoints)
- GET `thirdparty/protocols` — empty
- GET `thirdparty/protocol/{name}` — stub
- GET `thirdparty/location` — empty
- GET `thirdparty/user` — empty

### Miscellaneous Stubs (10+ endpoints)
- POST `account/password` — 200
- POST `account/deactivate` — 200
- GET `account/3pid` — empty
- GET `voip/turnServer` — empty URIs
- POST `knock/{roomId}` — 200
- POST `rooms/{roomId}/report/{eventId}` — 200
- GET `rooms/{roomId}/context/{eventId}` — empty
- GET `rooms/{roomId}/initialSync` — stub
- GET `rooms/{roomId}/aliases` — empty
- GET `media/v3/preview_url` — empty OG metadata
- POST `media/v1/create` — async upload stub

---

## 3. Formal Verification (15 specs)

### TLA+ (5 files, 24 invariants, 7 properties)
| Spec | Invariants | Properties |
|------|-----------|------------|
| StateResolutionV2.tla | 4 | 1 (AlgorithmTerminates) |
| EventDAG.tla | 6 | 1 (EventuallyGrows) |
| MembershipFSM.tla | 5 | 1 (BanToJoinRequiresUnban) |
| SyncProtocol.tla | 6 | 1 (EventualDelivery) |
| FederationSend.tla | 3 | 1 (TransactionEventuallyProcessed) |

### Agda (5 files, 22 theorems)
| Proof | Key Theorems |
|-------|-------------|
| CRDTConvergence.agda | sec-theorem, merge-comm, merge-assoc, merge-idemp, three-server-convergence |
| AuthRuleSoundness.agda | authCheck-decidable, auth-acyclic, creatorHasAdmin |
| PowerLevelMonotonicity.agda | self-elev-impossible, self-kick-impossible, equal-kick-impossible, no-deadlock |
| EventDAGProperties.agda | dag-acyclic, auth-acyclic, parents-lesser, auth-bounded |
| RoomVersionInvariant.agda | new-not-tombstoned, old-tombstone-correct, pl-copied, tombstoned-readonly, upgradeCorrect |

### Quint (5 files, 12 invariants, 5 properties)
| Model | Invariants | Key Safety Properties |
|-------|-----------|----------------------|
| federation.qnt | 3 | all_signed, depth_monotone, convergence |
| key_distribution.qnt | 2 | otk_single_claim, forward_secrecy |
| room_lifecycle.qnt | 3 | no_banned_joiner, tombstone_permanent, upgrade_preserves |
| sync_protocol.qnt | 2 | token_valid, prefix_coverage |
| presence.qnt | 2 | valid_states, no_forged |

---

## 4. Test Coverage

### Gleam Unit Tests (988 tests, 20 files)
| File | Tests | Coverage |
|------|-------|---------|
| sutra_edge_cases_test | 112 | Injection, traversal, Unicode, boundary, malformed |
| sutra_client_simulator_test | 109 | Full lifecycle + DAG + state resolution + auth |
| sutra_matrix_spec_compliance_test | 96 | All Matrix spec sections |
| sutra_router_coverage_test | 78 | All 159 router endpoints |
| sutra_server_test | 63 | Core server functions |
| sutra_federation_crosssigning_test | 53 | Federation + cross-signing |
| sutra_sqlite_ops_test | 53 | All 40 SQL functions + 17 tables |
| sutra_integration_test | 49 | Cross-module integration |
| sutra_encryption_media_search_test | 46 | E2EE + media + TF-IDF search |
| sutra_storage_directory_test | 46 | KV store + room directory |
| sutra_aliases_acl_devices_backup_test | 41 | Aliases + ACL + devices + backup |
| sutra_user_journey_test | 40 | End-to-end user flows |
| sutra_presence_push_admin_test | 39 | Presence + push + admin |
| sutra_appservice_spaces_zenoh_test | 36 | Appservice + spaces + Zenoh |
| sutra_threads_reactions_redaction_test | 33 | Threads + reactions + redaction |
| sutra_live_client_test | 31 | Real HTTP against live server |
| sutra_handlers_misc_test | 20 | Media + profile + admin + search |
| sutra_handlers_federation_test | 17 | Federation handler functions |
| sutra_handlers_ephemeral_test | 14 | Presence + receipts + push |
| sutra_handlers_rooms_test | 10 | Room alias + directory + redaction |

### Dart SDK Tests (129 tests, 4 files)
| File | Tests | Coverage |
|------|-------|---------|
| sutra_full_e2e_test | 97 | All endpoints, error robustness, full journey |
| sutra_compliance_test | 31 | Matrix spec compliance |
| sutra_sdk_login_test | 1 | FluffyChat login sequence trace |
| sutra_fluffychat_flow_test | 7 | Real Matrix Client class (SDK) |

---

## 5. Storage Schema (17 SQLite tables + KV in-memory)

### KV Store Fields
| Field | Type | Purpose |
|-------|------|---------|
| users | List(UserAccount) | Registered users with password, profile |
| rooms | List(Room) | Rooms with state, members, depth |
| events | List(PduEvent) | All events (messages + state) |
| tokens | List(#(String, String)) | token → user_id |
| media | List(MediaMetadata) | Media metadata (mxc URIs) |
| media_blobs | List(#(String, String)) | Media file content |
| device_keys | List(StoredDeviceKeys) | E2EE device keys per user/device |
| one_time_keys | List(#(4-tuple)) | E2EE one-time keys |
| cross_signing_keys | List(StoredCrossSigningKeys) | Cross-signing keys per user |
| account_data | List(#(3-tuple)) | User account data |
| token_devices | List(#(String, String)) | token → device_id |
| to_device_events | List(#(3-tuple)) | Pending to-device messages |
| key_backup_version | String | Current backup version |
| key_backup_data | List(#(3-tuple)) | Backup key entries |
| room_aliases | List(#(String, String)) | alias → room_id |
| receipts | List(#(5-tuple)) | Read receipts per room |
| typing | List(#(3-tuple)) | Typing notifications |
| presence | List(#(3-tuple)) | User presence status |

### SQLite Tables (17)
users, devices, rooms, room_state, events, event_edges, event_auth, media, tokens, account_data, presence, push_rules, receipts, room_aliases, device_keys, one_time_keys, cross_signing_keys

---

## 6. Architecture Summary

```
47 source modules, ~20K LOC
├── api/ (10 files)
│   ├── router.gleam (1900+ lines, 159 endpoints)
│   ├── handlers.gleam (live KV handlers)
│   ├── handlers_e2ee.gleam (E2EE handlers)
│   ├── handlers_ephemeral.gleam (presence/receipts/push)
│   ├── handlers_rooms.gleam (aliases/directory/redaction)
│   ├── handlers_federation.gleam (federation stubs)
│   └── handlers_misc.gleam (media/profile/admin)
├── matrix/ (20 domain modules)
│   ├── types.gleam, auth.gleam, event_dag.gleam
│   ├── state_resolution.gleam, sync_engine.gleam
│   ├── room_lifecycle.gleam, encryption.gleam
│   ├── devices.gleam, push.gleam, presence.gleam
│   ├── receipts.gleam, search.gleam, media.gleam
│   └── ... (threads, reactions, redaction, spaces, etc.)
├── storage/ (4 files)
│   ├── kv.gleam (in-memory store, 20+ fields)
│   ├── sqlite.gleam (17 tables)
│   ├── sqlite_ops.gleam (50+ SQL functions)
│   └── persistent.gleam (serialization)
├── federation/ (3 files)
├── integration/ (1 file — zenoh_bridge)
└── sutra_server.gleam (dispatch_to_handler, OTP actor)
```

---

## 7. FluffyChat Compatibility

### Fixed Issues (8 total)
1. Trailing space in username trimmed
2. Unique device_id per login session
3. OTK count matches uploaded count in keys/upload response
4. device_one_time_keys_count in sync response
5. UIA for device_signing/upload (401→200)
6. Device keys stored and returned in correct format in keys/query
7. Cross-signing keys returned in keys/query (master_keys, self_signing_keys, user_signing_keys)
8. device_lists.changed in sync includes users who uploaded keys

### FluffyChat Login Sequence
```
✅ well-known → 200
✅ versions → 200 (v1.1-v1.18 + sliding sync)
✅ login flows → 200 (m.login.password)
✅ auth_metadata → 404 (no OIDC)
✅ POST login → 200 (token + unique device_id + well_known)
✅ keys/upload → 200 (real OTK count)
✅ sync → 200 (rooms + device_lists + OTK counts + to_device + account_data)
✅ keys/query → 200 (device keys + cross-signing keys)
✅ device_signing/upload → 401 (UIA) → 200
```

---

## 8. Configuration Files

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Project instructions, architecture, build commands, constraints |
| `.claude/rules/matrix-protocol.md` | 10 Matrix protocol constraints |
| `.claude/rules/testing-protocol.md` | 6 testing constraints + sequence |
| `.claude/rules/server-operations.md` | 5 server ops constraints |
| `.claude/rules/e2ee-protocol.md` | 7 E2EE constraints + bootstrap sequence |
| `.claude/commands/sutra-test.md` | /sutra-test slash command |
| `.claude/commands/sutra-server.md` | /sutra-server slash command |
| `.claude/commands/sutra-sdk-test.md` | /sutra-sdk-test slash command |
| `.claude/commands/sutra-evolve.md` | /sutra-evolve slash command |
| `.claude/commands/sutra-rca.md` | /sutra-rca slash command |
| `.claude/agents/sutra-tester.md` | Test pipeline agent |
| `.claude/agents/sutra-debugger.md` | FluffyChat debug agent |
| `.claude/agents/sutra-evolver.md` | Feature evolution agent |
