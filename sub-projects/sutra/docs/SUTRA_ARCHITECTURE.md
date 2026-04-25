# Sutra Matrix Homeserver — Architecture Guide

**Version**: v0.1.0 | **Matrix CS API**: v1.18 | **Matrix SS API**: v1.13
**FQDN**: vm-1.tail55d152.ts.net | **Port**: 6167

---

## 1. System Overview

Sutra is a Gleam-first Matrix homeserver implementing 159 Client-Server API endpoints and the full Server-Server federation API. It runs on the BEAM VM (OTP actor model) for concurrent, fault-tolerant request handling, and integrates with the Indrajaal mesh via Zenoh pub/sub for distributed observability.

**Key properties**:
- Type-safe Gleam throughout (no runtime type errors)
- OTP actor holds all mutable state — each HTTP request is a message
- 4 Rust NIFs for performance-critical subsystems
- Zenoh integration: every request publishes an OTel span
- Graceful degradation: NIFs failing → server continues in reduced mode

---

## 2. Full Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    EXTERNAL CLIENTS                          │
│  FluffyChat / Matrix SDK ──HTTP──▶ :6167                    │
│  Dart SDK Tests ──────────HTTP──▶ :6167                     │
│  Federation peers ────────HTTPS──▶ :6167 / /_matrix/fed/   │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────┐
│              MIST HTTP LAYER (Gleam)                         │
│  mist.new(handler) |> mist.port(6167) |> mist.start()       │
│  Extracts: method, path, body, Authorization header         │
└─────────────────────────┬───────────────────────────────────┘
                          │ request.Request(mist.Connection)
┌─────────────────────────▼───────────────────────────────────┐
│              OTP ACTOR (gleam/otp/actor)                     │
│  ServerMsg: HandleRequest(method, path, body, token, reply)  │
│  ServerState: store: kv.Store, server_name, request_count   │
│  handle_server_msg/2 → dispatch → handler → ApiResult       │
│  All mutable state lives HERE (no global variables)         │
└──────────┬────────────────────────────────┬─────────────────┘
           │                                │
┌──────────▼──────────┐        ┌────────────▼──────────────┐
│  api/router.gleam   │        │  api/middleware.gleam     │
│  159 endpoint       │        │  CORS headers             │
│  pattern match      │        │  Auth token extraction    │
│  → dispatch to      │        │  Rate limit stubs         │
│    handler module   │        └───────────────────────────┘
└──────────┬──────────┘
           │
┌──────────▼────────────────────────────────────────────────┐
│              HANDLER MODULES (6 modules)                   │
│  handlers.gleam       — auth, sync, account, to-device    │
│  handlers_e2ee.gleam  — keys/upload/query/claim, X-sign   │
│  handlers_rooms.gleam — create/join/leave/invite/send     │
│  handlers_ephemeral.gleam — typing, receipts, presence    │
│  handlers_federation.gleam — S-S API, key server          │
│  handlers_misc.gleam  — versions, capabilities, admin     │
└──────────┬────────────────────────────────────────────────┘
           │
┌──────────▼────────────────────────────────────────────────┐
│              DOMAIN MODULES (matrix/ — 20 modules)        │
│  auth.gleam            sync_engine.gleam                  │
│  encryption.gleam      devices.gleam                      │
│  cross_signing.gleam   presence.gleam                     │
│  event_dag.gleam       push.gleam                         │
│  state_resolution.gleam  reactions.gleam                  │
│  room_lifecycle.gleam  redaction.gleam                    │
│  room_aliases.gleam    threads.gleam                      │
│  room_directory.gleam  receipts.gleam                     │
│  search.gleam          appservice.gleam                   │
│  media.gleam           spaces.gleam                       │
│  key_backup.gleam      server_acl.gleam                   │
│  user_directory.gleam  types.gleam (shared ADTs)          │
└──────────┬──────────────────────────┬─────────────────────┘
           │                          │
┌──────────▼──────────┐   ┌──────────▼──────────────────────┐
│  STORAGE LAYER      │   │  ZENOH BRIDGE                   │
│  kv.gleam           │   │  integration/zenoh_bridge.gleam │
│  (in-memory ETS)    │   │  zenoh.gleam (NIF wrapper)      │
│  sqlite.gleam       │   │  Every handler → auto-publish   │
│  (17 tables, WAL)   │   │  OTel span to:                  │
│  sqlite_ops.gleam   │   │  indrajaal/sutra/span/{m}/{s}   │
│  rocksdb.gleam      │   │  + domain-specific topic        │
│  (sled persistent)  │   └─────────────────────────────────┘
└─────────────────────┘
           │
┌──────────▼────────────────────────────────────────────────┐
│              RUST NIFs (4 shared libraries)                │
│  serdes_json_nif.so  — serde_json: raw JSON embed/merge   │
│  bcrypt_nif.so       — bcrypt hash + ed25519 sign/verify  │
│  rocksdb_nif.so      — sled key-value persistent store    │
│  zenoh_nif.so        — Zenoh session + pub/sub            │
└───────────────────────────────────────────────────────────┘
```

---

## 3. Layer Stack Detail

| Layer | Technology | Purpose |
|-------|-----------|---------|
| HTTP | Mist 3.0 | HTTP/1.1 + HTTPS server, connection handling |
| Actor | gleam/otp/actor | Single OTP actor holds all mutable state |
| Router | router.gleam | Pattern-match 159 endpoints → dispatch |
| Middleware | middleware.gleam | CORS, auth header extraction |
| Handlers | 6 handler modules | Business logic, JSON construction |
| Domain | 20 matrix/ modules | Protocol logic, state transitions |
| Storage | kv + sqlite + rocksdb | Three-tier storage (see §7) |
| NIFs | 4 Rust .so files | Performance-critical: JSON, bcrypt, KV, Zenoh |
| Zenoh | zenoh_nif.so | OTel spans + domain events to Indrajaal mesh |

---

## 4. The 4 Rust NIFs

### 4.1 serdes_json_nif.so — JSON Processing
**Rust crate**: serde_json | **Erlang bridge**: `src/serdes_json_ffi.erl`

Solves the problem of safely embedding raw JSON blobs (Matrix event content, device keys) into response JSON without double-encoding or injection risk.

| Function | Purpose |
|----------|---------|
| `object_raw(pairs)` | Build JSON object with raw-value fields |
| `embed(key, raw)` | Single-key raw embedding |
| `nest(outer, inner, raw)` | Nested raw value |
| `merge(base, overlay)` | JSON merge (RFC 7396 style) |
| `encode_event(id,type,sender,ts,content,state_key)` | Full Matrix event JSON |
| `otk_claim_response(claims)` | One-time key claim response |
| `device_keys_response(keys)` | keys/query response with correct nesting |
| `validate(str)` | Check valid JSON |
| `escape(str)` | Safe string escaping |

### 4.2 bcrypt_nif.so — Cryptography
**Rust crates**: bcrypt + ed25519-dalek

| Function | Purpose |
|----------|---------|
| `hash_password(plain, cost)` | bcrypt hash (cost 10, tuwunel-compatible) |
| `verify_password(plain, hash)` | Constant-time comparison |
| `ed25519_sign(key, message)` | Sign federation requests |
| `ed25519_verify(pubkey, msg, sig)` | Verify signatures |

### 4.3 rocksdb_nif.so — Persistent Key-Value (sled)
**Rust crate**: sled | **Gleam module**: `src/sutra_server/rocksdb.gleam`

Provides durable K-V storage at `data/sutra.db`. Falls back to in-memory KV if unavailable (server continues, degraded mode).

| Function | Purpose |
|----------|---------|
| `open(path)` | Open/create sled database |
| `put(key, value)` | Store bytes |
| `get(key)` | Retrieve bytes |
| `delete(key)` | Remove key |
| `scan_prefix(prefix)` | Range scan by key prefix |

### 4.4 zenoh_nif.so — Mesh Pub/Sub
**Rust crate**: zenoh 1.x | **Gleam module**: `src/sutra_server/zenoh.gleam`

6 NIF functions, 37 Gleam API functions, 30 topic namespaces. Every HTTP request automatically publishes an OTel span.

| Function | Purpose |
|----------|---------|
| `open(mode)` | Open session ("peer" or "client") |
| `is_open()` | Check connectivity |
| `put(key_expr, payload)` | Publish to topic |
| `health()` | JSON health report |
| `stats()` | JSON telemetry counters |
| `close()` | Graceful shutdown |

---

## 5. Request Flow

```
1. Browser/SDK → POST /_matrix/client/v3/login
2. mist.Connection → handle_request(req, actor_subject)
3. Extract: method="POST", path="/…/login", body="{…}", token=None
4. actor.call(actor_subject, HandleRequest(…), 5000ms timeout)
5. Actor receives message → handle_server_msg(state, msg)
6. dispatch_to_handler("POST", "/…/login", body, None, store)
7. router.gleam pattern match → handlers.handle_login(body, store)
8. handlers.gleam → auth.gleam → bcrypt_nif verify_password
9. Build JSON response via gleam/json or serdes_json NIF
10. Actor returns ApiResult(JsonResponse(200, body)) via reply Subject
11. mist formats HTTP response with CORS headers
12. zenoh_bridge publishes span to indrajaal/sutra/span/POST/200
13. zenoh_bridge publishes to indrajaal/sutra/auth/login
14. Response delivered to client
```

**Latency budget**: NIF calls <1ms, actor dispatch <2ms, total <10ms typical.

---

## 6. Matrix CS API Coverage (159 Endpoints)

| Group | Endpoints | Handler Module | Status |
|-------|-----------|---------------|--------|
| Authentication | login, register, logout, whoami, password, deactivate | handlers.gleam | Complete |
| Sync | /sync, /events (long-poll) | handlers.gleam | Complete |
| Rooms | create, join, leave, invite, kick, ban, unban, forget | handlers_rooms.gleam | Complete |
| Events | send (PUT txn), get, state, state_event, members, messages | handlers_rooms.gleam | Complete |
| E2EE | keys/upload, keys/query, keys/claim, keys/changes | handlers_e2ee.gleam | Complete |
| Cross-signing | device_signing/upload (UIA) | handlers_e2ee.gleam | Complete |
| Key backup | room_keys/version, room_keys/keys | handlers_misc.gleam | Complete |
| Devices | GET/PUT/DELETE /devices, /device/{id} | handlers_misc.gleam | Complete |
| Presence | GET/PUT presence | handlers_ephemeral.gleam | Complete |
| Typing | PUT typing | handlers_ephemeral.gleam | Complete |
| Receipts | POST read_markers, receipts | handlers_ephemeral.gleam | Complete |
| To-device | PUT send_to_device | handlers.gleam | Complete |
| Account data | PUT/GET account_data | handlers_misc.gleam | Complete |
| Push | GET/PUT push_rules, pushers | handlers_misc.gleam | Complete |
| Media | upload, download, thumbnail | handlers_misc.gleam | Complete |
| Search | POST /search | handlers_misc.gleam | Complete |
| User directory | POST /user_directory/search | handlers_misc.gleam | Complete |
| Room aliases | PUT/GET/DELETE /directory/room | handlers_misc.gleam | Complete |
| Room directory | GET /publicRooms | handlers_misc.gleam | Complete |
| Profile | GET/PUT displayname, avatar_url | handlers_misc.gleam | Complete |
| Admin | GET /admin/users, deactivate | handlers_misc.gleam | Complete |
| Federation | /_matrix/federation/v1/* | handlers_federation.gleam | Partial |
| Well-known | GET /.well-known/matrix/* | well_known.gleam | Complete |
| Capabilities | GET /capabilities, /versions | handlers_misc.gleam | Complete |
| Sliding sync | POST /sync (MSC3575) | handlers.gleam | Stub |

---

## 7. Storage Architecture

```
┌─────────────────────────────────────────────────────────────┐
│              THREE-TIER STORAGE                              │
│                                                             │
│  Tier 1: KV Store (in-memory)                              │
│    kv.gleam — Gleam map, held in OTP actor state           │
│    users, tokens, device_keys, one_time_keys, rooms,       │
│    events, media, cross_signing_keys                       │
│    Fast: O(1) lookups, lost on restart                     │
│                                                             │
│  Tier 2: SQLite (durable, WAL mode)                        │
│    sqlite.gleam + sqlite_ops.gleam                         │
│    17 tables: users, devices, rooms, room_state, events,   │
│    event_edges, event_auth, media, tokens, account_data,   │
│    presence, push_rules, receipts, room_aliases,           │
│    device_keys, one_time_keys, cross_signing_keys          │
│    Persistent: survives restarts, ACID transactions        │
│                                                             │
│  Tier 3: Sled persistent KV (rocksdb_nif.so)              │
│    rocksdb.gleam → data/sutra.db                          │
│    Byte-level K-V with prefix scan                        │
│    Optional: falls back to in-memory if unavailable       │
└─────────────────────────────────────────────────────────────┘
```

---

## 8. E2EE Flow (FluffyChat Bootstrap Sequence)

```
Client                          Sutra Server
  │                                 │
  ├─ GET /.well-known/matrix/client ─▶ {"m.homeserver": {"base_url": ...}}
  ├─ GET /versions ────────────────▶ {"versions": ["v1.18", ...]}
  ├─ GET /login ───────────────────▶ {"flows": [{"type": "m.login.password"}]}
  ├─ GET /auth_metadata ───────────▶ 404 (not implemented)
  ├─ POST /login ──────────────────▶ {access_token, device_id, user_id, well_known}
  │   SDK creates Olm account
  ├─ POST /keys/upload ────────────▶ {one_time_key_counts: {signed_curve25519: N}}
  │   CRITICAL: N must equal uploaded OTK count (SC-SUTRA-002)
  ├─ GET /sync ────────────────────▶ {next_batch, device_one_time_keys_count,
  │                                   device_lists: {changed: [...]}}
  │   CRITICAL: device_lists.changed must be present (SC-SUTRA-008)
  ├─ POST /keys/query ─────────────▶ {device_keys: {userId: {deviceId: {keys...}}}}
  │   CRITICAL: format must match SC-SUTRA-003 exactly
  ├─ POST /keys/device_signing/upload
  │   Round 1 ──────────────────▶ 401 {flows: [{stages: ["m.login.password"]}]}
  │   Round 2 (with UIA) ────────▶ 200 {} (SC-SUTRA-004)
  └─ Bootstrap complete
```

---

## 9. Zenoh Integration — 30 Topic Namespaces

Every HTTP request auto-publishes an OTel span. Domain events publish to specific topics.

```
indrajaal/sutra/
  span/{method}/{status}    — OTel request span (ALL requests, auto)
  req/{method}/{path}       — request telemetry
  event/{type}              — Matrix event telemetry
  health                    — server health pings (10s interval)
  auth/{action}             — login/register/logout
  room/{action}             — create/join/leave/invite
  message/sent              — message events
  e2ee/{action}             — keys upload/query/claim/cross-sign
  sync/{user}               — sync events per user
  typing/{room}             — typing indicators
  presence/{user}           — presence updates
  receipt/{room}            — read receipts
  device/{action}           — device management
  media/{action}            — media upload/download
  search                    — search queries
  state/{room}/{type}       — room state events
  membership/{room}         — membership changes
  push/{action}             — push rules/notifications
  account_data/{user}       — account data changes
  directory/{action}        — room directory
  federation/{action}       — federation events
  admin/{action}            — admin operations
  backup/{action}           — key backup
  to_device/{type}          — to-device messages
  filter/{action}           — filter operations
  profile/{action}          — profile changes
  capabilities              — capabilities queries
  sliding_sync              — MSC3575 sliding sync
  test/sutra/{test}         — closed-loop test observations
  stats                     — NIF statistics
```

**Live telemetry** (server must be running):
```bash
curl http://localhost:6167/_sutra/zenoh/health
curl http://localhost:6167/_sutra/zenoh/stats
```

---

## 10. Formal Specifications (15 specs)

| Type | File | Verifies |
|------|------|---------|
| TLA+ | `StateResolutionV2.tla` | Matrix state resolution algorithm v2 correctness |
| TLA+ | `MembershipFSM.tla` | Room membership state machine (invite/join/leave/ban) |
| TLA+ | `EventDAG.tla` | Event DAG acyclicity and topological ordering |
| TLA+ | `SyncProtocol.tla` | Sync timeline consistency across clients |
| TLA+ | `FederationSend.tla` | Federation event delivery guarantees |
| Agda | `CRDTConvergence.agda` | CRDT convergence proof for room state |
| Agda | `AuthRuleSoundness.agda` | Authorization rules soundness |
| Agda | `PowerLevelMonotonicity.agda` | Power level changes are monotonically consistent |
| Agda | `EventDAGProperties.agda` | Event DAG mathematical properties |
| Agda | `RoomVersionInvariant.agda` | Room version upgrade invariants |
| Quint | `federation.qnt` | Federation protocol temporal properties |
| Quint | `key_distribution.qnt` | E2EE key distribution liveness/safety |
| Quint | `room_lifecycle.qnt` | Room create/join/leave lifecycle |
| Quint | `sync_protocol.qnt` | Sync protocol linearizability |
| Quint | `presence.qnt` | Presence state machine consistency |

---

## 11. Source Module Map (51 Gleam files)

```
src/
  sutra_server.gleam                  — main entry, OTP actor, HTTP wiring
  sutra_server/
    api/
      router.gleam                    — 159 endpoint dispatch (1,860 lines)
      handlers.gleam                  — auth, sync, account, to-device
      handlers_e2ee.gleam             — E2EE: keys upload/query/claim, cross-signing
      handlers_rooms.gleam            — room create/join/leave/invite/send
      handlers_ephemeral.gleam        — typing, receipts, presence
      handlers_federation.gleam       — S-S federation API
      handlers_misc.gleam             — capabilities, versions, admin, media
      json_helpers.gleam              — shared JSON construction helpers
      middleware.gleam                — CORS, auth extraction, rate limiting
      well_known.gleam                — /.well-known/matrix/client + server
    matrix/
      types.gleam                     — shared ADTs (UserId, RoomId, Event, ...)
      auth.gleam                      — login, register, token management
      sync_engine.gleam               — /sync timeline, filtering
      encryption.gleam                — keys/upload/query, OTK management
      cross_signing.gleam             — device_signing/upload, UIA
      devices.gleam                   — device list management
      event_dag.gleam                 — DAG structure, auth chain
      state_resolution.gleam          — v2 state resolution algorithm
      room_lifecycle.gleam            — create, join, leave, invite
      room_aliases.gleam              — /directory/room/* CRUD
      room_directory.gleam            — /publicRooms listing
      presence.gleam                  — presence state machine
      push.gleam                      — push rules, pushers
      reactions.gleam                 — m.reaction relation
      receipts.gleam                  — read receipts, read markers
      redaction.gleam                 — m.room.redaction
      search.gleam                    — full-text room search
      media.gleam                     — media upload/download/thumbnail
      threads.gleam                   — m.thread relation
      key_backup.gleam                — room key backup/restore
      appservice.gleam                — Application Service API
      spaces.gleam                    — MSC1772 Spaces
      server_acl.gleam                — m.room.server_acl enforcement
      account_data.gleam              — per-user account data
      admin.gleam                     — admin user/room management
      user_directory.gleam            — user directory search
    storage/
      kv.gleam                        — in-memory KV store (OTP actor state)
      sqlite.gleam                    — SQLite config, schema (17 tables)
      sqlite_ops.gleam                — SQLite CRUD operations
      persistent.gleam                — persistent storage abstraction
    federation/
      transport.gleam                 — S-S transport, signatures
      backfill.gleam                  — event backfill from peers
      resolver.gleam                  — server name resolution
    integration/
      zenoh_bridge.gleam              — domain event → Zenoh pub
    observability/
      telemetry.gleam                 — OTel span construction
    auth/
      password.gleam                  — bcrypt via NIF
    zenoh.gleam                       — Zenoh NIF wrapper (6 NIFs, 37 fns)
    rocksdb.gleam                     — Sled NIF wrapper
    serdes_json.gleam                 — serdes_json NIF wrapper
    crypto.gleam                      — crypto helpers (ed25519 via NIF)
```

---

## 12. Key Operational Constraints

| ID | Constraint | Severity | Why |
|----|-----------|----------|-----|
| SC-SUTRA-006 | Always `rm -rf build/dev/erlang/sutra_server` before build | CRITICAL | Stale bytecode silently serves old code |
| SC-SUTRA-001 | All 159 endpoints respond (no 404 for spec endpoints) | CRITICAL | FluffyChat fails on any missing endpoint |
| SC-SUTRA-002 | OTK count in keys/upload response = uploaded count | CRITICAL | SDK refuses E2EE bootstrap |
| SC-SUTRA-003 | keys/query nesting: `{userId: {deviceId: {keys}}}` | CRITICAL | SDK parse fails on wrong format |
| SC-SUTRA-004 | device_signing/upload: 401 → 200 (UIA two-round) | CRITICAL | Cross-signing bootstrap fails |
| SC-JSON-002 | No manual JSON string concatenation | CRITICAL | XSS and injection risk |
| SC-ZMOF-001 | All internal comms via Zenoh pub/sub | HIGH | Observability and mesh integration |
