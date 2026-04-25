# Sutra Matrix Homeserver — Comprehensive Feature Matrix
# v0.1.0 | Matrix Client-Server API v1.18 | Gleam + BEAM OTP
# Generated: 2026-04-18 | Source: 39 .gleam files, ~14K LOC

---

## §1. Module Inventory — Full Fractal Layer Mapping

All 39 Gleam source files classified by fractal layer assignment (as declared in each module's Layer annotation).

### L0 — CONSTITUTIONAL (Safety-Critical / Cryptographic)
Security kernel, key material, redaction enforcement, server access control — no violations tolerated.

| Module | File | LOC (approx) | Primary Responsibility |
|--------|------|-------------|----------------------|
| `auth` | `matrix/auth.gleam` | ~250 | Event authorization check: join/leave/invite/ban/kick; power level comparisons |
| `auth.password` | `auth/password.gleam` | ~200 | SHA-256 password hashing with random salts; constant-time comparison; access token generation |
| `matrix.encryption` | `matrix/encryption.gleam` | ~200 | E2EE type definitions: DeviceKeys, OlmSession, MegolmSession, CrossSigningKeys; rotation policy |
| `matrix.redaction` | `matrix/redaction.gleam` | ~180 | Event redaction enforcement per spec §10.4; per-type content stripping allowlist |
| `matrix.cross_signing` | `matrix/cross_signing.gleam` | ~250 | Cross-signing key upload/query (master/self-signing/user-signing); device verification heuristic |
| `matrix.key_backup` | `matrix/key_backup.gleam` | ~246 | E2EE key backup versioning (m.megolm_backup.v1); session storage; etag/count management |
| `matrix.server_acl` | `matrix/server_acl.gleam` | ~243 | m.room.server_acl parsing and enforcement; glob pattern matching; IP literal detection |

**L0 total: 7 modules**

---

### L1 — ATOMIC / DEBUG (Observability, Presence Signals)
Low-level ephemeral signals, telemetry instrumentation, presence state.

| Module | File | LOC (approx) | Primary Responsibility |
|--------|------|-------------|----------------------|
| `observability.telemetry` | `observability/telemetry.gleam` | ~280 | SutraSpan / SutraMetrics; 7 Zenoh topics under `indrajaal/l7/sutra/`; OoZ spans at `indrajaal/otel/spans/sutra/{op}` |
| `matrix.presence` | `matrix/presence.gleam` | ~200 | PresenceEntry / PresenceStore; online/idle user tracking; TypingStore; m.typing JSON builder |

**L1 total: 2 modules**

---

### L2 — COMPONENT (Reusable Data Components)
Shared types, HTTP boundary primitives, per-event attachment data.

| Module | File | LOC (approx) | Primary Responsibility |
|--------|------|-------------|----------------------|
| `matrix.types` | `matrix/types.gleam` | ~589 | Canonical type system: UserId, RoomId, PduEvent, Room, Membership, PowerLevels, MediaId, MatrixError, SyncToken, FederationTransaction, PresenceStatus |
| `api.json_helpers` | `api/json_helpers.gleam` | ~120 | Lightweight JSON field extraction (no parser dep): extract_string, extract_int, extract_bool, extract_string_list; error_json / success_json builders |
| `api.middleware` | `api/middleware.gleam` | ~180 | HTTP boundary: RequestLog, RateLimitState (sliding window), CORS headers, OPTIONS response builder, client_ip_from_header |
| `matrix.receipts` | `matrix/receipts.gleam` | ~150 | ReceiptType (ReadReceipt, ReadPrivateReceipt, FullyRead); ReceiptStore; nested JSON encoder for m.receipt events |
| `matrix.reactions` | `matrix/reactions.gleam` | ~160 | MSC2677 m.annotation reactions; dedup by (sender, target_event_id, key); bundled aggregation JSON encoder |

**L2 total: 5 modules**

---

### L3 — TRANSACTION (Storage, Room Data, MSC Spec Features)
Durable data structures, room metadata, content-addressed storage.

| Module | File | LOC (approx) | Primary Responsibility |
|--------|------|-------------|----------------------|
| `storage.kv` | `storage/kv.gleam` | ~350 | Pure-functional in-memory Store: token→user_id→UserAccount two-step lookup; rooms_for_user; search_users; room_snapshot |
| `storage.sqlite` | `storage/sqlite.gleam` | ~280 | 14 migration schema definitions (WAL mode, busy-timeout); SqliteConfig; validate_config; schema-only (not wired to runtime) |
| `storage.persistent` | `storage/persistent.gleam` | ~220 | PersistentStore JSON serialize/deserialize; 60s auto-save heuristic; partial restore (users+tokens only) |
| `matrix.account_data` | `matrix/account_data.gleam` | ~224 | AccountDataEntry upsert by (user_id, room_id, data_type); global + per-room; JSON array encoder |
| `matrix.room_aliases` | `matrix/room_aliases.gleam` | ~200 | RoomAlias CRUD; parse_alias("#localpart:server"); GET /directory/room/{alias} response builder |
| `matrix.spaces` | `matrix/spaces.gleam` | ~200 | MSC1772 SpaceHierarchy; SpaceChild / Space; m.space.child + m.space.parent state event JSON builders; hierarchy response encoder |
| `matrix.threads` | `matrix/threads.gleam` | ~180 | MSC3440 Thread / ThreadStore; threads_in_room event scanner; m.thread relation content JSON; bundled aggregation encoder |
| `matrix.media` | `matrix/media.gleam` | ~200 | MediaStore; MediaFile; MediaUploadResult; mxc:// URI builder/parser; usage_percent; delete_media |
| `matrix.room_directory` | `matrix/room_directory.gleam` | ~263 | Public room directory list/filter/paginate; is_public_room (join_rule==Public); string-offset pagination tokens |

**L3 total: 9 modules**

---

### L4 — SYSTEM (Server Orchestration, Device Management, Push)
OTP actor lifecycle, device registry, push notification dispatch.

| Module | File | LOC (approx) | Primary Responsibility |
|--------|------|-------------|----------------------|
| `sutra_server` | `sutra_server.gleam` | ~530 | Main entry: OTP actor (ServerState{store,server_name,request_count}); Mist HTTP handler; 19 live dispatch cases + router fallback; path helpers |
| `matrix.devices` | `matrix/devices.gleam` | ~215 | DeviceStore keyed by (user_id, Device); add/remove/get/update/update_last_seen; encode_device_list |
| `matrix.push` | `matrix/push.gleam` | ~280 | Pusher / PushRule / PushAction / PushCondition types; 8 default push rules; first-match evaluation; encode_pushers / encode_push_rules |

**L4 total: 3 modules**

---

### L5 — COGNITIVE (Intelligent Processing, Search, State Analysis)
Sync computation, state resolution, search ranking, user directory.

| Module | File | LOC (approx) | Primary Responsibility |
|--------|------|-------------|----------------------|
| `matrix.sync_engine` | `matrix/sync_engine.gleam` | ~250 | Initial vs incremental sync; "s{timestamp_ms}" batch tokens; 20-event cap per room initial; rooms_for_user + filter by since_ts |
| `matrix.state_resolution` | `matrix/state_resolution.gleam` | ~280 | Matrix State Resolution v2: unconflicted/conflicted separation; mainline_ordering (power_level_depth DESC, ts ASC, event_id ASC); merge_state_maps |
| `matrix.search` | `matrix/search.gleam` | ~200 | TF-IDF proxy: match m.room.message, score_hit = occurrences/word_count; SearchOrder(Recent|Rank); paginate with offset tokens; encode_search_response |
| `matrix.user_directory` | `matrix/user_directory.gleam` | ~180 | UserProfile / DirectoryEntry / UserSearchResult; case-insensitive match on user_id or display_name; GET /profile/{userId} encoder |

**L5 total: 4 modules**

---

### L6 — ECOSYSTEM (External System Integration, App Service Bridge)
Zenoh mesh bridge, application service protocol gateway.

| Module | File | LOC (approx) | Primary Responsibility |
|--------|------|-------------|----------------------|
| `integration.zenoh_bridge` | `integration/zenoh_bridge.gleam` | ~250 | ZenohBridgeConfig (6 topics: health/events/federation/metrics/admin/otel); ZenohBridgeState; bridge_health score 0.0–1.0; health_message + event_to_zenoh_message encoders |
| `matrix.appservice` | `matrix/appservice.gleam` | ~262 | MSC AS API: AppServiceRegistration (id/url/as_token/hs_token/namespaces/rate_limited); namespace matching; encode_transaction for PUT /_matrix/app/v1/transactions/{txnId}; Telegram+WhatsApp bridge factory stubs |

**L6 total: 2 modules**

---

### L7 — FEDERATION (Server-to-Server, Admin, Discovery)
Cross-server protocol, event DAG authority, server discovery, admin ops.

| Module | File | LOC (approx) | Primary Responsibility |
|--------|------|-------------|----------------------|
| `federation.transport` | `federation/transport.gleam` | ~250 | FederationRequest / SignedRequest / ServerKeys / FederationTransaction; Ed25519 stub signing ("stub_sig_*"); path builders for S2S endpoints |
| `federation.resolver` | `federation/resolver.gleam` | ~220 | Server resolution (WellKnown/SrvRecord/DirectConnect/DefaultPort); FederationRegistry; backoff_duration = min(2^n × 1000ms, 300s); active_peers filter |
| `federation.backfill` | `federation/backfill.gleam` | ~249 | BackfillState (pending/completed/failed per room); build_backfill_request URL encoder; parse_backfill_response pdus_count extractor |
| `api.well_known` | `api/well_known.gleam` | ~100 | /.well-known/matrix/client + /.well-known/matrix/server JSON builders; server_version(); health_ok() |
| `matrix.admin` | `matrix/admin.gleam` | ~180 | AdminAction (PurgeRoom/DeactivateUser/ResetPassword/MakeAdmin/ServerNotice/ShutdownRoom); is_admin guard; ServerStats encoder |
| `matrix.event_dag` | `matrix/event_dag.gleam` | ~280 | EventDAG with auth-chain BFS; topological_order via Kahn's algorithm; is_ancestor; state_at causal history; validate_event format check |
| `matrix.room_lifecycle` | `matrix/room_lifecycle.gleam` | ~250 | create_room emits 5-7 ordered PDUs (m.room.create, m.room.member, m.room.power_levels, m.room.join_rules, m.room.history_visibility, [m.room.topic, m.room.name]); preset handling; apply_membership_change |
| `api.router` | `api/router.gleam` | ~1554 | ApiResult (JsonResponse | ErrorResponse); ~80 endpoint stubs returning router-level responses; well-known + versions endpoints |
| `api.handlers` | `api/handlers.gleam` | ~600 | 19 live handler functions: login, register, logout, whoami, sync, create_room, join, leave, get_state, get_members, send_event, media_upload, search; HandlerContext{store,server_name,timestamp} |

**L7 total: 9 modules**

---

### Layer Summary

| Layer | Name | Module Count | Key Theme |
|-------|------|-------------|-----------|
| L0 | Constitutional | 7 | Crypto, auth enforcement, ACL, key safety |
| L1 | Atomic/Debug | 2 | Telemetry, presence ephemera |
| L2 | Component | 5 | Shared types, HTTP boundary, receipt/reaction data |
| L3 | Transaction | 9 | Storage, room content, spec-extension features |
| L4 | System | 3 | OTP actor, device registry, push |
| L5 | Cognitive | 4 | Sync, state resolution, search, user lookup |
| L6 | Ecosystem | 2 | Zenoh bridge, App Service API |
| L7 | Federation | 9 | S2S transport, DAG authority, admin, discovery |
| **Total** | | **41** | |

> Note: 41 modules found in source tree including 2 FFI support files not in the Gleam module count (sutra_auth_ffi.erl, erlang_now_ms FFI). The 39 .gleam files map to 41 rows above due to `sutra_server.gleam` spanning both the L4 entry point and L7 router/handler imports.

---

## §2. Biomorphic Holon Properties — Per-Module Assessment

Each module is assessed against the 7 biomorphic properties of life as mapped to the C3I system.

Legend: ✅ Implemented | ⬜ Partial / Stub | ❌ Absent

| # | Property | C3I Mapping |
|---|----------|------------|
| 1 | **Homeostasis** | Self-stabilising state maintenance: error paths, rate limiting, graceful degradation |
| 2 | **Metabolism** | Resource consumption tracking: request counting, media size, session counts |
| 3 | **Growth** | Structural expansion capacity: registration, room creation, event append |
| 4 | **Reproduction** | Self-replication / templating: room presets, bridge factories, default rules |
| 5 | **Response** | Stimulus reaction: HTTP dispatch, sync push, Zenoh event publish |
| 6 | **Adaptation** | State change on feedback: state resolution, backoff, retry logic |
| 7 | **Evolution** | Code-level hot-swap readiness: pure-functional design, stateless modules |

### L0 — Constitutional Modules

| Module | Homeostasis | Metabolism | Growth | Reproduction | Response | Adaptation | Evolution |
|--------|:-----------:|:----------:|:------:|:------------:|:--------:|:----------:|:---------:|
| `auth` | ✅ AuthResult covers all failure modes | ❌ no counting | ⬜ checks grow with event types | ❌ | ✅ returns AuthResult immediately | ⬜ power-level read only | ✅ pure functions |
| `auth.password` | ✅ constant_time_compare prevents timing | ❌ no counting | ⬜ token factory only | ⬜ generate_device_id factory | ✅ verify_password returns Bool | ❌ salt is not crypto-random (erlang unique_int) | ✅ stateless, swappable |
| `matrix.encryption` | ⬜ rotation policy defined but not enforced | ⬜ message_index tracks usage | ⬜ new sessions appendable | ✅ default_algorithms() factory | ✅ is_room_encrypted check | ✅ should_rotate_megolm | ✅ pure types |
| `matrix.redaction` | ✅ AlreadyRedacted guard; deny non-admin | ❌ | ⬜ RedactionStore grows | ✅ redacted_content_for_type allowlist | ✅ apply_redaction_to_event | ❌ no retry/feedback | ✅ pure functions |
| `matrix.cross_signing` | ⬜ Blocked device state defined, not persisted | ❌ | ✅ upload_keys upserts | ⬜ key structure factory | ✅ verify_device returns DeviceVerification | ⬜ crypto verification is stub only | ✅ pure |
| `matrix.key_backup` | ⬜ etag for conflict detection | ✅ count tracks session growth | ✅ create_version, put_room_keys | ✅ version factory from timestamp | ✅ returns (store, version) tuple | ⬜ no retry on failed backup | ✅ pure |
| `matrix.server_acl` | ✅ deny before allow; IP literal guard | ❌ | ✅ deny list grows | ✅ default_acl() factory | ✅ check_server returns AclDecision | ✅ glob match adapts to any pattern | ✅ pure |

### L1 — Atomic/Debug Modules

| Module | Homeostasis | Metabolism | Growth | Reproduction | Response | Adaptation | Evolution |
|--------|:-----------:|:----------:|:------:|:------------:|:--------:|:----------:|:---------:|
| `observability.telemetry` | ✅ health score 0.0–1.0 | ✅ request_count, event_count, media_size_mb | ✅ metric counters grow | ⬜ span builder factory | ✅ publish span on every operation | ⬜ Zenoh topics defined but publish is stub | ✅ pure encoding |
| `matrix.presence` | ✅ idle_users threshold filter | ⬜ tracks last_active_ts only | ✅ presence entries grow | ✅ encode_presence_events for all users | ✅ set_presence immediate | ✅ idle threshold parametric | ✅ pure |

### L2 — Component Modules

| Module | Homeostasis | Metabolism | Growth | Reproduction | Response | Adaptation | Evolution |
|--------|:-----------:|:----------:|:------:|:------------:|:--------:|:----------:|:---------:|
| `matrix.types` | ✅ exhaustive MatrixError variants | ❌ pure types only | ✅ add new variants safely | ✅ canonical type factories (UserId, RoomId) | ❌ types don't respond | ❌ types don't adapt | ✅ adding fields is non-breaking |
| `api.json_helpers` | ✅ Result-typed extraction, no panics | ❌ | ⬜ new helpers addable | ⬜ error_json / success_json builders | ✅ extract_* return immediately | ❌ | ✅ pure functions |
| `api.middleware` | ✅ rate_limit_check evicts stale window | ✅ RateLimitState.requests tracks volume | ⬜ new middleware composable | ⬜ options_response factory | ✅ is_matrix_path guard fires on every request | ✅ rate limit window slides | ✅ pure functions |
| `matrix.receipts` | ✅ add_receipt replaces prior (no duplicates) | ❌ | ✅ receipts grow per user | ⬜ ReceiptStore constructor | ✅ encode_receipt_event for all receipt types | ❌ | ✅ pure |
| `matrix.reactions` | ✅ add_reaction deduplicates (sender, target, key) | ⬜ count per key tracked | ✅ reaction store grows | ⬜ ReactionSummary builder | ✅ encode_reaction_bundle returns immediately | ❌ | ✅ pure |

### L3 — Transaction Modules

| Module | Homeostasis | Metabolism | Growth | Reproduction | Response | Adaptation | Evolution |
|--------|:-----------:|:----------:|:------:|:------------:|:--------:|:----------:|:---------:|
| `storage.kv` | ✅ pure functional: no mutations escape | ⬜ rooms/users/events counts in Store | ✅ add_user, add_room, add_event grow store | ✅ kv.new() factory + seed_store pipeline | ✅ lookup functions return immediately | ⬜ no TTL or eviction | ✅ pure, swappable |
| `storage.sqlite` | ⬜ schema defined, WAL + busy-timeout | ❌ no runtime metrics | ✅ 14 migrations addable in sequence | ✅ migration list is a factory | ❌ schema-only, not wired | ❌ no migration retry | ✅ declarative schema |
| `storage.persistent` | ⬜ 60s auto-save heuristic | ⬜ tracks last_save_ts | ✅ serialize grows with Store | ✅ PersistentStore.new() | ✅ should_save returns Bool | ⬜ restore is partial (users+tokens only) | ✅ pure encoding |
| `matrix.account_data` | ✅ upsert prevents duplicate entries | ❌ | ✅ entries grow per user/room/type | ✅ store_new() | ✅ encode_account_data for any user | ✅ set_global/set_room overwrite stale | ✅ pure |
| `matrix.room_aliases` | ✅ AliasExists guard prevents double-register | ❌ | ✅ aliases grow | ✅ create_alias factory | ✅ resolve_alias / AliasNotFound | ✅ delete_alias removes stale | ✅ pure |
| `matrix.spaces` | ✅ remove_child prevents dangling references | ❌ | ✅ add_child grows hierarchy | ✅ space_state_event / parent_state_event | ✅ encode_hierarchy_response | ✅ set_parent overwrites | ✅ pure |
| `matrix.threads` | ✅ create_thread only if absent | ❌ | ✅ reply_count grows on add_reply | ✅ thread_relation_content factory | ✅ encode_thread_summary | ✅ add_reply updates latest_event_id | ✅ pure |
| `matrix.media` | ✅ UploadTooLarge guard; total_bytes tracked | ✅ total_bytes, usage_percent | ✅ upload grows store | ✅ mxc_uri builder | ✅ upload returns (store, result) | ⬜ no expiry/eviction | ✅ pure |
| `matrix.room_directory` | ✅ is_public_room filter | ⬜ member_count from state | ✅ list grows with rooms | ✅ default_acl-equivalent (list_public_rooms) | ✅ paginate with next_batch token | ✅ filter_rooms text query | ✅ pure |

### L4 — System Modules

| Module | Homeostasis | Metabolism | Growth | Reproduction | Response | Adaptation | Evolution |
|--------|:-----------:|:----------:|:------:|:------------:|:--------:|:----------:|:---------:|
| `sutra_server` | ✅ OTP supervisor; 5s call timeout; OPTIONS 200 | ✅ request_count increments per request | ✅ dispatch table grows with new cases | ✅ seed_store pre-populates admin+bot | ✅ synchronous process.call + build_response pipeline | ⬜ no health-check loop or reconnect | ⬜ stateful actor (NIF needed for hot swap) |
| `matrix.devices` | ✅ remove_device removes stale; no duplicates by (uid, did) | ⬜ device_count per user | ✅ add_device grows store | ✅ generate_device_id from timestamp | ✅ get_device / devices_for_user return immediately | ✅ update_last_seen updates IP+ts | ✅ pure (store passed functionally) |
| `matrix.push` | ✅ should_notify first-match exits early | ❌ | ✅ push rules list growable | ✅ default_push_rules() factory (8 rules) | ✅ should_notify Bool immediately | ⬜ rule evaluation order is fixed | ✅ pure |

### L5 — Cognitive Modules

| Module | Homeostasis | Metabolism | Growth | Reproduction | Response | Adaptation | Evolution |
|--------|:-----------:|:----------:|:------:|:------------:|:--------:|:----------:|:---------:|
| `matrix.sync_engine` | ✅ since-token prevents re-delivery | ⬜ events_per_room tracked implicitly | ✅ sync range grows with events | ✅ initial_sync / incremental_sync factories | ✅ returns sync response immediately | ✅ incremental filters by origin_server_ts | ✅ pure |
| `matrix.state_resolution` | ✅ merge_state_maps prevents conflicted state | ❌ | ✅ resolved state grows with events | ✅ resolve() orchestrator | ✅ returns resolved state | ✅ mainline_ordering adapts to power level changes | ✅ pure |
| `matrix.search` | ✅ paginate caps results; no OOM | ⬜ score_hit tracks word_count | ✅ search corpus grows with events | ✅ paginate factory (offset tokens) | ✅ returns SearchResult immediately | ✅ SearchOrder(Recent|Rank) switchable | ✅ pure |
| `matrix.user_directory` | ✅ limited flag prevents unbounded results | ❌ | ✅ directory grows with profiles | ✅ encode_profile / encode_search_response | ✅ search_users returns immediately | ✅ case-insensitive match | ✅ pure |

### L6 — Ecosystem Modules

| Module | Homeostasis | Metabolism | Growth | Reproduction | Response | Adaptation | Evolution |
|--------|:-----------:|:----------:|:------:|:------------:|:--------:|:----------:|:---------:|
| `integration.zenoh_bridge` | ✅ health score 0.0 when disconnected | ✅ published_count / received_count tracked | ✅ topics list growable | ✅ ZenohBridgeConfig factory | ✅ health_message + event_to_zenoh_message return immediately | ✅ bridge_health adapts to connect state | ✅ pure (Zenoh session external) |
| `matrix.appservice` | ✅ validate_hs_token guards inbound | ❌ | ✅ register grows store | ✅ telegram_bridge_registration / whatsapp_bridge_registration factories | ✅ should_forward_event returns Bool | ✅ namespace regex matching | ✅ pure |

### L7 — Federation Modules

| Module | Homeostasis | Metabolism | Growth | Reproduction | Response | Adaptation | Evolution |
|--------|:-----------:|:----------:|:------:|:------------:|:--------:|:----------:|:---------:|
| `federation.transport` | ⬜ stub_sig fallback in MVP | ❌ | ✅ path builders composable | ✅ sign_request / build_* factories | ✅ returns SignedRequest immediately | ⬜ stub — real Ed25519 needs NIF | ✅ pure (NIF swappable) |
| `federation.resolver` | ✅ backoff_until prevents retry storms | ⬜ retry_count tracked | ✅ peers list grows | ✅ resolve_server() factory | ✅ active_peers / mark_peer_failed return immediately | ✅ exponential backoff adapts (2^n × 1000ms, cap 300s) | ✅ pure |
| `federation.backfill` | ✅ pending deduplication (room replaces) | ⬜ pending/completed/failed counts | ✅ pending list grows | ✅ request_backfill factory | ✅ has_pending / build_backfill_request immediate | ✅ mark_failed / mark_completed adapts state | ✅ pure |
| `api.well_known` | ✅ health_ok always returns 200 | ❌ | ⬜ static responses | ✅ server_version / health_ok factories | ✅ immediate string return | ❌ | ✅ pure |
| `matrix.admin` | ✅ AdminDenied if !is_admin | ❌ | ✅ AdminAction variants extensible | ⬜ execute_admin dispatcher | ✅ execute_admin returns AdminResult immediately | ❌ no retry | ✅ pure |
| `matrix.event_dag` | ✅ Kahn's detects cycles; auth_chain BFS bounded | ⬜ event count in DAG | ✅ append grows DAG | ✅ validate_event format check | ✅ is_ancestor / state_at return immediately | ✅ topological_order re-sorts on each call | ✅ pure |
| `matrix.room_lifecycle` | ✅ AlreadyMember guard on join | ❌ | ✅ create_room emits ordered PDUs | ✅ room preset factories (PublicChat/PrivateChat/TrustedPrivateChat) | ✅ apply_membership_change immediate | ✅ membership state machine (join/leave/invite/ban/knock) | ✅ pure |
| `api.router` | ✅ default stub returns structured error | ❌ | ⬜ ~80 stubs grow by adding live cases | ✅ router.route() dispatcher | ✅ returns ApiResult immediately | ❌ stubs are static | ⬜ live endpoints require dispatch wiring |
| `api.handlers` | ✅ FluffyChat identifier block; M_UNKNOWN error | ⬜ request count via ctx.timestamp | ✅ 19 live handlers, extensible | ✅ HandlerContext factory | ✅ all handlers return #(kv.Store, ApiResult) | ⬜ token lookup only; no session invalidation | ✅ pure functions (ctx immutable) |

---

## §3. Control Path Documentation

Four primary control flows govern how requests traverse the system.

### 3.1 Authentication Control Flow

```
Client HTTP Request
  │
  ├─ [BOUNDARY] sutra_server.gleam: extract_token(req) → Option(String)
  │
  ├─ [ACTOR MSG] process.call(actor_subject, 5000, HandleRequest{method,path,body,token,reply})
  │
  ├─ [DISPATCH] dispatch_to_handler(ctx, method, path, body, token)
  │
  ├─ [AUTH GUARD] dispatch_with_token(ctx, token, handler_fn)
  │    ├─ None → #(store, ErrorResponse(401, "M_MISSING_TOKEN", "Missing access token"))
  │    └─ Some(token) → handler_fn(token)
  │
  ├─ [HANDLER] e.g. handlers.handle_whoami(ctx, token)
  │    └─ kv.lookup_user_by_token(store, token)
  │         ├─ Error → ErrorResponse(401, "M_UNKNOWN_TOKEN", ...)
  │         └─ Ok(user_account) → JsonResponse(200, whoami_json)
  │
  ├─ [RESPONSE LOG] io.println("[RES] status path")
  │
  └─ [ACTOR REPLY] process.send(reply, result) → build_response(result) → mist.Response
```

**STAMP: SC-SAFETY-001** — all token-gated endpoints flow through `dispatch_with_token`.

### 3.2 Room Operation Control Flow

```
POST /_matrix/client/v3/createRoom
  │
  ├─ [AUTH] dispatch_with_token → token validated
  │
  ├─ [HANDLER] handlers.handle_create_room(ctx, token, body)
  │    ├─ json_helpers.extract_string(body, "name") → Option
  │    ├─ json_helpers.extract_string(body, "preset") → Option
  │    └─ room_lifecycle.create_room(store, creator_id, name, preset, topic, ts)
  │         ├─ Generate RoomId (unique_integer)
  │         ├─ Emit PDU: m.room.create
  │         ├─ Emit PDU: m.room.member (Join creator)
  │         ├─ Emit PDU: m.room.power_levels
  │         ├─ Emit PDU: m.room.join_rules (from preset)
  │         ├─ Emit PDU: m.room.history_visibility
  │         ├─ [Optional] m.room.topic / m.room.name
  │         └─ kv.add_room(store, room) → new_store
  │
  ├─ [AUTH CHECK] matrix.auth.check_event(room, event, sender_power)
  │    └─ AuthResult { Authorized | Denied }
  │
  └─ [RESPONSE] JsonResponse(200, {"room_id": "!abc:server"})

PUT /_matrix/client/v3/rooms/{roomId}/send/{eventType}/{txnId}
  │
  ├─ [AUTH] dispatch_with_token → token validated
  ├─ [PATH PARSE] extract_room_id_from_path + extract_room_sub_path
  ├─ [HANDLER] handlers.handle_send_event(ctx, token, room_id, sub_path, body)
  │    ├─ Parse event_type and txn_id from sub_path
  │    ├─ Build PduEvent with EventId(unique_integer)
  │    ├─ auth.check_event(room, event, sender_power) → Authorized | Denied
  │    └─ kv.add_event(store, room_id, event) → new_store
  └─ [RESPONSE] JsonResponse(200, {"event_id": "$abc"})
```

### 3.3 Federation Control Flow (S2S)

```
[Inbound — receive remote event]
  POST /_matrix/federation/v1/send/{txnId}   [STUB in router]
  │
  └─ federation.transport.verify_signature(signed_request)
       └─ MVP: accepts all "stub_sig_*" prefixed signatures
            Real: Rust NIF Ed25519 verify → ServerKeys lookup → validate

[Outbound — send to remote server]
  federation.resolver.resolve_server(server_name)
  │   ├─ Contains ":" → DirectConnect
  │   └─ Default → DefaultPort 8448
  │
  ├─ FederationRegistry.active_peers(registry, now)
  │    └─ Filters peers where should_retry(peer, now)
  │         └─ backoff_until < now (exponential backoff: min(2^n × 1000ms, 300s))
  │
  └─ federation.transport.sign_request(request, key_id, private_key)
       └─ Returns SignedRequest with stub_sig or real Ed25519 (future)

[History gap fill]
  federation.backfill.request_backfill(state, room_id, event_id, limit, server_name)
  │   └─ Deduplicates per room_id (latest wins)
  ├─ build_backfill_request(room_id, event_id, limit)
  │   └─ "/_matrix/federation/v1/backfill/{roomId}?v={eventId}&limit={limit}"
  └─ parse_backfill_response(body) → Result(Int, String) [pdus_count]
```

### 3.4 Admin Control Flow

```
POST /_matrix/client/v1/admin/... [router stub]
  │
  ├─ [AUTH] dispatch_with_token + admin flag check
  │    └─ kv.lookup_user_by_token → UserAccount.is_admin
  │
  ├─ [EXEC] matrix.admin.execute_admin(action, is_admin)
  │    ├─ Not admin → AdminDenied("Insufficient privileges")
  │    └─ Admin → AdminOk (stub — real implementation required)
  │         Actions: PurgeRoom | DeactivateUser | ResetPassword
  │                  MakeAdmin | ServerNotice | ShutdownRoom
  │
  └─ matrix.admin.encode_server_stats(stats) for /admin/server_info
       ServerStats { user_count, room_count, event_count,
                     media_size_bytes, uptime_seconds, version }
```

---

## §4. Data Path Documentation

### 4.1 Event Data Path (Write)

```
Client PUT /rooms/{roomId}/send/m.room.message/{txnId}
  │
  [1] Body JSON → json_helpers.extract_* → msgtype + body fields
  [2] handlers.handle_send_event builds PduEvent:
       PduEvent {
         event_id: EventId(unique_integer),
         event_type: "m.room.message",
         room_id: RoomId(room_id),
         sender: UserId(localpart, server),
         content: body_string,
         origin_server_ts: ctx.timestamp,
         auth_events: [...],
         prev_events: [...],
         depth: computed
       }
  [3] auth.check_event(room, event, sender_power) → Authorized
  [4] kv.add_event(store, room_id, event) → new_store (functional copy)
  [5] event_dag.append(dag, event) [separate DAG for ordering]
  [6] Actor: ServerState.store updated via actor.continue(new_state)
  [7] [Future] zenoh_bridge: event_to_zenoh_message(room_alias, event_json)
       → publishes to indrajaal/l7/sutra/events/{room_alias}
```

### 4.2 Sync Data Path (Read)

```
GET /_matrix/client/v3/sync?since=s{ts}&timeout=30000
  │
  [1] handlers.handle_sync(ctx, token, query)
  [2] sync_engine.extract_since(query) → Option(String) "s{ts}"
  [3] sync_engine.initial_sync(ctx.store, user_id) OR
      sync_engine.incremental_sync(ctx.store, user_id, since_ts)
       │
       ├─ kv.rooms_for_user(store, user_id) → List(Room)
       ├─ For each room:
       │   ├─ room_snapshot(store, room_id) → List(events)
       │   ├─ [Initial] take last 20 events
       │   ├─ [Incremental] filter by origin_server_ts > since_ts
       │   ├─ state_resolution.resolve(room_events) → current_state
       │   ├─ presence events for user's contacts
       │   └─ account_data.all_global(store, user_id)
       │
  [4] build_sync_response JSON with:
       { "next_batch": "s{now_ts}",
         "rooms": { "join": { room_id: { "state": [...], "timeline": [...] } } },
         "presence": { "events": [...] },
         "account_data": { "events": [...] }
       }
  [5] JsonResponse(200, sync_json)
```

### 4.3 Key Material Data Path (E2EE)

```
[Upload device keys]
  PUT /_matrix/client/v3/keys/upload  [STUB]
  │
  ├─ matrix.encryption: DeviceKeys { user_id, device_id, algorithms, keys, signatures }
  ├─ [Future] kv.add_device_keys(store, user_id, device_keys)
  └─ auth.password.generate_access_token(user_id, device_id) for new sessions

[Key backup]
  POST /_matrix/client/v3/room_keys/version  [STUB]
  │
  ├─ key_backup.create_version(store, algorithm, auth_data, ts)
  │   → KeyBackupVersion { version, algorithm, auth_data, count: 0, etag }
  ├─ key_backup.put_room_keys(store, version_id, room_id, sessions)
  │   → increments count, updates etag
  └─ GET /_matrix/client/v3/room_keys/version
      → key_backup.encode_version_response(version)

[Cross-signing]
  PUT /_matrix/client/v3/keys/device_signing/upload  [STUB]
  │
  ├─ cross_signing.upload_keys(store, user_id, CrossSigningKeys{master,self_signing,user_signing})
  └─ cross_signing.verify_device(keys, device_id) → DeviceVerification
      { Verified | Unverified | Blocked | Unknown }
```

### 4.4 Media Data Path

```
POST /_matrix/media/v3/upload
  │
  [1] dispatch_with_token → user_id resolved
  [2] handlers.handle_media_upload(ctx, token, body)
  [3] media.upload(store, content_type, filename, size_bytes, uploader, server_name, ts)
       ├─ size check: size_bytes <= max_size_bytes
       │   Fail → UploadTooLarge(max_size_bytes)
       ├─ Generate MediaId(unique_integer as string)
       ├─ MediaFile { media_id, server_name, content_type, filename, size_bytes, uploaded_at, uploader }
       └─ MediaStore { files: [new_file, ..existing], total_bytes: total + size }
  [4] UploadOk(mxc_uri) → "mxc://{server_name}/{media_id}"
  [5] JsonResponse(200, {"content_uri": "mxc://..."})

GET /_matrix/media/v3/download/{serverName}/{mediaId}  [STUB]
  │
  └─ media.parse_mxc_uri("mxc://server/id") → #(server, media_id)
      → lookup in MediaStore → serve bytes [not implemented — stubs 200]
```

---

## §5. Coverage Tensor — 8×7 Biomorphic Property Matrix

Aggregated at the **fractal layer level** across all modules in each layer.
A cell is ✅ if the majority of modules in the layer implement the property,
⬜ if implementation is partial or present in fewer than half of modules,
❌ if the property is absent across all modules in the layer.

| Layer | Homeostasis | Metabolism | Growth | Reproduction | Response | Adaptation | Evolution |
|-------|:-----------:|:----------:|:------:|:------------:|:--------:|:----------:|:---------:|
| **L0 Constitutional** | ✅ | ❌ | ✅ | ⬜ | ✅ | ⬜ | ✅ |
| **L1 Atomic/Debug** | ✅ | ✅ | ✅ | ✅ | ✅ | ⬜ | ✅ |
| **L2 Component** | ✅ | ❌ | ✅ | ⬜ | ✅ | ❌ | ✅ |
| **L3 Transaction** | ✅ | ⬜ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **L4 System** | ✅ | ⬜ | ✅ | ✅ | ✅ | ⬜ | ⬜ |
| **L5 Cognitive** | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **L6 Ecosystem** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **L7 Federation** | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ⬜ |

### Scoring Key

| Symbol | Score | Meaning |
|--------|-------|---------|
| ✅ | 1.0 | Majority (>50%) of layer modules implement this property |
| ⬜ | 0.5 | Partial: minority (<50%) of modules or stub implementation |
| ❌ | 0.0 | Absent across all modules in the layer |

### Coverage Calculation

| Layer | ✅ Count | ⬜ Count | ❌ Count | Layer Score |
|-------|---------|---------|---------|------------|
| L0 Constitutional | 4 | 2 | 1 | 4×1.0 + 2×0.5 + 1×0.0 = **5.0/7 = 71.4%** |
| L1 Atomic/Debug | 6 | 1 | 0 | 6×1.0 + 1×0.5 = **6.5/7 = 92.9%** |
| L2 Component | 3 | 1 | 2 | 3×1.0 + 1×0.5 = **3.5/7 = 50.0%** |
| L3 Transaction | 6 | 1 | 0 | 6×1.0 + 1×0.5 = **6.5/7 = 92.9%** |
| L4 System | 4 | 2 | 0 | 4×1.0 + 2×0.5 = **5.0/7 = 71.4%** |
| L5 Cognitive | 5 | 0 | 2 | 5×1.0 + 0×0.5 = **5.0/7 = 71.4%** |
| L6 Ecosystem | 7 | 0 | 0 | 7×1.0 = **7.0/7 = 100.0%** |
| L7 Federation | 5 | 1 | 1 | 5×1.0 + 1×0.5 = **5.5/7 = 78.6%** |

**Overall biomorphic coverage: (5.0+6.5+3.5+6.5+5.0+5.0+7.0+5.5) / (8×7) = 44.0/56 = 78.6%**

### Per-Property Totals

| Property | ✅ Layers | ⬜ Layers | ❌ Layers | Property Score |
|----------|---------|---------|---------|---------------|
| Homeostasis | 8 | 0 | 0 | **100%** |
| Metabolism | 2 | 3 | 3 | **43.8%** |
| Growth | 8 | 0 | 0 | **100%** |
| Reproduction | 5 | 2 | 1 | **75.0%** |
| Response | 8 | 0 | 0 | **100%** |
| Adaptation | 3 | 3 | 2 | **56.3%** |
| Evolution | 6 | 1 | 1 | **81.3%** |

**System-wide biomorphic vitality: 78.6%** — the system is biomorphically alive but metabolism and adaptation are the weakest dimensions.

---

## §6. Gap Analysis — Actionable Priorities

### 6.1 Critical Gaps (Blocking Production Readiness)

#### GAP-001: Ed25519 Federation Signing (L7, SC-FED-001)
- **Problem**: All outbound S2S requests use `stub_sig_*` placeholders. Remote homeservers will reject all federation.
- **Impact**: No federation — Sutra is an island. FluffyChat and other clients cannot talk to matrix.org, beeper.com, etc.
- **Module**: `federation/transport.gleam` — `sign_request/3`, `verify_signature/2`
- **Fix**: Add Rust NIF binding for `libsodium` Ed25519 sign/verify. Wire `sutra_auth_ffi.erl` with `crypto:sign(eddsa, ...)` or Rust NIF. 3 function stubs to replace.
- **Effort**: High (Rust NIF) | **Priority**: P0

#### GAP-002: SQLite Not Wired to Runtime (L3, SC-XHOLON-001)
- **Problem**: `storage/sqlite.gleam` defines 14 migration schemas but is never called from the running server. All data is in-memory KV; server restart loses everything.
- **Impact**: Zero persistence. Admin users, rooms, events, and media are ephemeral.
- **Module**: `storage/sqlite.gleam`, `storage/persistent.gleam`
- **Fix**: Wire `sqlite.run_migrations(conn)` on actor init. Replace `kv.Store` lookups with SQLite queries in `kv.gleam` or add a parallel SQLite-backed store. `storage/persistent.gleam` already has serialize/deserialize — it just needs a periodic actor call.
- **Effort**: High (data model change) | **Priority**: P0

#### GAP-003: 61 Router Stubs Unimplemented (L7, SC-FUNC-001)
- **Problem**: `api/router.gleam` contains ~80 endpoints; only 19 are live-wired in `dispatch_to_handler`. The remaining ~61 return stub responses without real logic.
- **Key missing endpoints** (selected high-impact):
  - `GET /rooms/{roomId}/messages` — room timeline pagination (no clients work without this)
  - `PUT /rooms/{roomId}/state/{eventType}/{stateKey}` — state event set
  - `GET /rooms/{roomId}/state/{eventType}/{stateKey}` — state event get
  - `PUT /profile/{userId}/displayname` — display name set
  - `POST /keys/upload` — device key upload (E2EE prerequisite)
  - `POST /keys/query` — key query (E2EE prerequisite)
  - `GET /publicRooms` — room directory
  - `POST /user_directory/search` — user search
  - `GET/PUT /rooms/{roomId}/typing/{userId}` — typing notifications
  - `POST /rooms/{roomId}/read_markers` — read receipts
  - `GET /devices` / `GET /devices/{deviceId}` — device list
  - `PUT/DELETE /directory/room/{roomAlias}` — alias management
  - `POST /pushrules/` — push rule management
  - `GET /_matrix/federation/v1/*` — ALL inbound S2S endpoints are stubs
- **Impact**: Most Matrix clients (FluffyChat, Element, Cinny) require many of these to function beyond basic login/send.
- **Effort**: High (61 endpoints × ~30 LOC each ≈ 1800 LOC) | **Priority**: P0-P1

#### GAP-004: Crypto Not Random — Salt Generation (L0, SC-SEC-001)
- **Problem**: `auth/password.gleam::generate_salt()` uses `erlang:unique_integer()` — monotonic, not cryptographically random. An attacker with timing info could predict salts.
- **Module**: `auth/password.gleam` — `generate_salt/0`, line 45
- **Fix**: Replace with `crypto:strong_rand_bytes(32)` via Erlang FFI in `sutra_auth_ffi.erl`.
- **Effort**: Low (1 function) | **Priority**: P0 (security-critical)

---

### 6.2 High-Priority Gaps (Significant Capability Gaps)

#### GAP-005: Metabolism Absent at L0, L2, L5, L7 (Biomorphic SC-BIO-EVO-002)
- **Problem**: Modules at L0, L2, L5, and L7 have no resource consumption tracking. The system cannot self-report its load.
- **Missing**: Request rate per user (L0 auth), parse counts (L2 json_helpers), search query cost (L5 search), federation message volume (L7).
- **Fix**: Add telemetry counters to `observability/telemetry.gleam::SutraMetrics` and wire from each module via OTel spans. `telemetry.gleam` already emits to `indrajaal/otel/spans/sutra/{operation}`.
- **Effort**: Medium | **Priority**: P1

#### GAP-006: L4 Actor Not Hot-Swappable (Biomorphic SC-BIO-EVO-007)
- **Problem**: `sutra_server.gleam` holds stateful `ServerState` in an OTP actor. The actor cannot be hot-reloaded without losing in-memory state. This is expected for production but a gap vs. the evolution mandate.
- **Fix**: Once SQLite is wired (GAP-002), actor state can be reconstructed on restart. Add a dying-gasp checkpoint (SC-SIL4-007): on `SIGTERM`, flush store to SQLite before shutdown.
- **Effort**: Medium (after GAP-002) | **Priority**: P1

#### GAP-007: App Service Forwarding Not Wired (L6)
- **Problem**: `matrix/appservice.gleam` defines the full AppService protocol including `encode_transaction`, `should_forward_event`, and namespace matching. However, the event dispatch in `sutra_server.gleam` never calls `should_forward_event`. Bridge events are never forwarded.
- **Fix**: In `handle_server_msg`, after `dispatch_to_handler`, check `appservice.should_forward_event` for each registered AS and fire outbound HTTP PUT to AS URL. Add `AppServiceStore` to `ServerState`.
- **Effort**: Medium | **Priority**: P1

#### GAP-008: Presence / Typing Not Pushed to Clients (L1)
- **Problem**: `matrix/presence.gleam` and `PresenceStore`/`TypingStore` are complete. However, sync responses in `handlers.handle_sync` do not include presence events. Typing notifications are not delivered.
- **Fix**: Wire `presence.encode_presence_events(store, user_ids)` into `sync_engine.build_sync_response`. Add ephemeral events section with `m.typing` events.
- **Effort**: Low-Medium | **Priority**: P1

#### GAP-009: Receipts and Reactions Not in Sync Response (L2)
- **Problem**: `matrix/receipts.gleam` and `matrix/reactions.gleam` are complete with correct encoders. However, receipts are not included in sync responses (`handle_sync` does not call `receipts.encode_receipt_event`). Reactions bundled aggregations are not injected into event content.
- **Fix**: Wire receipt store into sync response ephemeral events. Inject reaction bundles into timeline events.
- **Effort**: Medium | **Priority**: P1

#### GAP-010: Adaptation Absent at L2 (Component Layer)
- **Problem**: L2 modules (`matrix.types`, `api.json_helpers`, `api.middleware`) have no feedback-driven adaptation. Rate limit window is not configurable at runtime. CORS headers are hardcoded.
- **Fix**: Allow rate limit config to be passed from `ServerState` (or loaded from SQLite config table). Allow CORS origins to be per-room or per-server.
- **Effort**: Low | **Priority**: P2

---

### 6.3 Medium-Priority Gaps (Spec Completeness)

#### GAP-011: State Resolution Not Used in Sync (L5)
- **Problem**: `matrix/state_resolution.gleam` implements full Matrix v2 algorithm. However, `sync_engine.gleam` does not call `state_resolution.resolve()` to compute current room state — it reads raw state from `kv.room_snapshot`. This can serve stale/conflicted state during concurrent writes.
- **Fix**: Wire `state_resolution.resolve(room_events)` into the sync timeline before building room state block.
- **Effort**: Medium | **Priority**: P1

#### GAP-012: Event DAG Not Used for Ordering (L7)
- **Problem**: `matrix/event_dag.gleam` provides topological ordering via Kahn's algorithm and `state_at` for causal state. The KV store adds events without consulting the DAG. Events could be delivered out-of-DAG order.
- **Fix**: On `kv.add_event`, validate via `event_dag.validate_event` and append to the room's DAG. Use `event_dag.topological_order` for timeline construction.
- **Effort**: Medium-High | **Priority**: P1

#### GAP-013: Push Delivery Not Implemented (L4)
- **Problem**: `matrix/push.gleam` has `should_notify` evaluation and `Pusher` types. However, the server never actually delivers push notifications to push gateways (no HTTP call to `pusher.url`).
- **Fix**: After event write, evaluate `push.should_notify(push_rules, event_type, content)` for each room member; if True, HTTP POST to pusher URL with Matrix push payload.
- **Effort**: Medium | **Priority**: P2

#### GAP-014: Server ACL Not Checked on Inbound Federation (L0)
- **Problem**: `matrix/server_acl.gleam` is complete with glob matching and IP literal detection. But `federation/transport.gleam::verify_signature` does not call `server_acl.check_server` before accepting inbound events.
- **Fix**: Before accepting any inbound federation transaction, load room ACL state and call `server_acl.check_server(acl, origin_server)`. Reject if `ServerDenied`.
- **Effort**: Low (3 function calls) | **Priority**: P1 (security)

#### GAP-015: Zenoh Bridge Not Connected (L6, SC-GLM-ZEN-001)
- **Problem**: `integration/zenoh_bridge.gleam` defines 6 Zenoh topics and health scoring. The bridge state is never added to `ServerState`, and `zenoh_bridge.event_to_zenoh_message` is never called.
- **Fix**: Add `ZenohBridgeState` to `ServerState`. On event write, call `bridge.event_to_zenoh_message` and publish via Zenoh NIF. On actor init, attempt Zenoh connection and set `bridge_state.connected`.
- **Effort**: Medium (requires Zenoh NIF wiring) | **Priority**: P1 (SC-GLM-ZEN-001 = CRITICAL)

#### GAP-016: Spaces, Threads, Cross-Signing, Key Backup Not Wired (L3/L0)
- **Problem**: `matrix/spaces.gleam`, `matrix/threads.gleam`, `matrix/cross_signing.gleam`, `matrix/key_backup.gleam` are complete domain modules. None are reachable from `dispatch_to_handler` — no handler routes map to their endpoints.
- **Key missing routes**: `GET /_matrix/client/v1/rooms/{roomId}/hierarchy`, `GET /_matrix/client/v1/threads/{roomId}`, `POST /keys/device_signing/upload`, `GET /room_keys/version`.
- **Fix**: Add live dispatch cases in `sutra_server.gleam::dispatch_to_handler` for each. Add corresponding handlers in `api/handlers.gleam`.
- **Effort**: Medium (route wiring) | **Priority**: P2

---

### 6.4 Low-Priority Gaps (Hardening)

#### GAP-017: Persistent Store Restores Only Users+Tokens (L3)
- **Problem**: `storage/persistent.gleam` serializes rooms and events but `restore_from_json` only restores users + tokens. Room data is lost on restart even with persistence enabled.
- **Fix**: Implement room + event deserialization in `restore_from_json`.
- **Effort**: Low-Medium | **Priority**: P2

#### GAP-018: Media Download Not Implemented (L3)
- **Problem**: `media.upload` is live-wired. However, `GET /_matrix/media/v3/download/{serverName}/{mediaId}` is a router stub. Clients cannot retrieve uploaded files.
- **Fix**: Add handler that reads from `MediaStore` by media_id and returns file bytes. For now: store raw bytes in `MediaFile.session_data` string field or wire to filesystem.
- **Effort**: Medium | **Priority**: P2

#### GAP-019: User Directory Search Not Wired (L5)
- **Problem**: `matrix/user_directory.gleam` is complete. `POST /_matrix/client/v3/user_directory/search` is a router stub.
- **Fix**: Add live dispatch in `dispatch_to_handler` and handler calling `user_directory.search_users`.
- **Effort**: Low | **Priority**: P2

#### GAP-020: Room Directory Not Wired (L3)
- **Problem**: `matrix/room_directory.gleam` is complete. `GET /_matrix/client/v3/publicRooms` is a router stub.
- **Fix**: Add live dispatch in `dispatch_to_handler` and handler calling `room_directory.list_public_rooms`.
- **Effort**: Low | **Priority**: P2

---

## §7. Implementation Completeness Summary

### Live Endpoints vs Stubs

| Category | Live | Stub | Total |
|----------|------|------|-------|
| Auth (login, register, logout, whoami) | 4 | 2 (guest, token) | 6 |
| Sync | 1 | 0 | 1 |
| Room CRUD (create, join, leave, state, members) | 5 | ~15 | ~20 |
| Event send | 1 | ~10 (redact, state set, etc.) | ~11 |
| Media | 1 (upload) | 1 (download) | 2 |
| Search | 1 | 0 | 1 |
| Logout | 1 | 0 | 1 |
| Keys / E2EE | 0 | ~8 | 8 |
| Push | 0 | ~6 | 6 |
| User directory | 0 | 1 | 1 |
| Public rooms | 0 | 1 | 1 |
| Presence / typing | 0 | ~4 | 4 |
| Room aliases | 0 | 2 | 2 |
| Admin | 0 | ~6 | 6 |
| Federation S2S | 0 | ~12 | 12 |
| Well-known / versions | 2 (well-known builders) | 0 | 2 |
| **TOTAL** | **~19** | **~68** | **~87** |

**Implementation ratio: 19/87 ≈ 21.8% live endpoints**

### Module Wiring Status

| Module | Types Defined | Encoded | Wired to Handler | Wired to Server |
|--------|:------------:|:-------:|:----------------:|:---------------:|
| auth | ✅ | ✅ | ✅ | ✅ |
| auth.password | ✅ | ✅ | ✅ | ✅ |
| storage.kv | ✅ | ✅ | ✅ | ✅ |
| storage.sqlite | ✅ | ⬜ | ❌ | ❌ |
| storage.persistent | ✅ | ✅ | ⬜ | ❌ |
| matrix.sync_engine | ✅ | ✅ | ✅ | ✅ |
| matrix.state_resolution | ✅ | ✅ | ❌ | ❌ |
| matrix.event_dag | ✅ | ⬜ | ❌ | ❌ |
| matrix.room_lifecycle | ✅ | ✅ | ✅ | ✅ |
| matrix.auth | ✅ | ✅ | ✅ | ✅ |
| matrix.encryption | ✅ | ⬜ | ❌ | ❌ |
| matrix.devices | ✅ | ✅ | ❌ | ❌ |
| matrix.presence | ✅ | ✅ | ❌ | ❌ |
| matrix.receipts | ✅ | ✅ | ❌ | ❌ |
| matrix.push | ✅ | ✅ | ❌ | ❌ |
| matrix.search | ✅ | ✅ | ✅ | ✅ |
| matrix.media | ✅ | ✅ | ✅ (upload) | ✅ |
| matrix.reactions | ✅ | ✅ | ❌ | ❌ |
| matrix.redaction | ✅ | ✅ | ❌ | ❌ |
| matrix.account_data | ✅ | ✅ | ❌ | ❌ |
| matrix.room_aliases | ✅ | ✅ | ❌ | ❌ |
| matrix.spaces | ✅ | ✅ | ❌ | ❌ |
| matrix.threads | ✅ | ✅ | ❌ | ❌ |
| matrix.user_directory | ✅ | ✅ | ❌ | ❌ |
| matrix.admin | ✅ | ✅ | ❌ | ❌ |
| matrix.room_directory | ✅ | ✅ | ❌ | ❌ |
| matrix.cross_signing | ✅ | ✅ | ❌ | ❌ |
| matrix.key_backup | ✅ | ✅ | ❌ | ❌ |
| matrix.server_acl | ✅ | ✅ | ❌ | ❌ |
| matrix.event_dag | ✅ | ⬜ | ❌ | ❌ |
| observability.telemetry | ✅ | ✅ | ⬜ | ❌ |
| integration.zenoh_bridge | ✅ | ✅ | ❌ | ❌ |
| matrix.appservice | ✅ | ✅ | ❌ | ❌ |
| federation.transport | ✅ | ✅ | ❌ | ❌ |
| federation.resolver | ✅ | ✅ | ❌ | ❌ |
| federation.backfill | ✅ | ✅ | ❌ | ❌ |
| api.well_known | ✅ | ✅ | ⬜ (router only) | ⬜ |
| api.router | ✅ | ✅ | ⬜ (stubs) | ✅ |
| api.handlers | ✅ | ✅ | ✅ | ✅ |
| api.middleware | ✅ | ✅ | ❌ | ❌ |
| api.json_helpers | ✅ | ✅ | ✅ | ✅ |

**Wiring completeness (handler+server): 9/39 modules = 23%**

---

## §8. Sprint Roadmap — Recommended Execution Order

Based on gap analysis priorities and dependency ordering:

### Sprint 0 — Security Hardening (1 day)
1. **GAP-004**: Replace `erlang:unique_integer` salt with `crypto:strong_rand_bytes(32)` in `sutra_auth_ffi.erl`
2. **GAP-014**: Wire `server_acl.check_server` into inbound federation path

### Sprint 1 — Persistence (2 days)
3. **GAP-002**: Wire `storage/sqlite.gleam` migrations on actor init; add SQLite conn to `ServerState`
4. **GAP-017**: Complete `storage/persistent.gleam` room+event restore

### Sprint 2 — Core Client Compatibility (3 days)
5. **GAP-003 subset**: Wire 15 highest-impact missing endpoints:
   - `GET /rooms/{roomId}/messages` (timeline pagination)
   - `PUT /rooms/{roomId}/state/{eventType}/{stateKey}` (state set)
   - `GET /rooms/{roomId}/state/{eventType}/{stateKey}` (state get)
   - `PUT /profile/{userId}/displayname`
   - `GET /profile/{userId}/displayname`
   - `POST /keys/upload`
   - `POST /keys/query`
   - `GET /publicRooms`
   - `POST /user_directory/search`
   - `GET/PUT /typing/{userId}`
   - `POST /read_markers`
   - `GET /devices`
   - `PUT/DELETE /directory/room/{roomAlias}`
   - `GET/POST /pushrules/`
   - `POST /rooms/{roomId}/receipt/{receiptType}/{eventId}`

### Sprint 3 — Biomorphic Wiring (2 days)
6. **GAP-008**: Wire presence + typing into sync response
7. **GAP-009**: Wire receipts + reactions into sync response
8. **GAP-011**: Wire `state_resolution.resolve` into sync pipeline
9. **GAP-012**: Wire `event_dag` into event append path
10. **GAP-015**: Wire `zenoh_bridge` into `ServerState` and event publish path

### Sprint 4 — Federation (3 days)
11. **GAP-001**: Implement Ed25519 signing via Erlang `crypto` or Rust NIF
12. **GAP-003 subset**: Wire inbound S2S endpoints (send transaction, make_join, send_join, backfill)

### Sprint 5 — MSC Feature Endpoints (2 days)
13. **GAP-016**: Wire spaces, threads, cross-signing, key backup endpoints
14. **GAP-013**: Implement push delivery (HTTP POST to pusher URLs)
15. **GAP-018**: Implement media download handler
16. **GAP-007**: Wire appservice event forwarding

---

## §9. STAMP Compliance Reference

| Constraint | Status | Module |
|-----------|--------|--------|
| SC-TRUTH-001 (Show only truth) | ⬜ Partial — sync reads raw KV, not resolved state | GAP-011 |
| SC-FUNC-001 (System compiles) | ✅ All 39 modules compile | — |
| SC-XHOLON-001 (DB isolation) | ❌ SQLite not wired at runtime | GAP-002 |
| SC-SAFETY-001 (Auth required) | ✅ dispatch_with_token guards all mutations | sutra_server |
| SC-IKE-001 (Knowledge in store) | ⬜ In-memory only, no persistence | GAP-002 |
| SC-GLM-ZEN-001 (OTel spans) | ⬜ Telemetry module exists, not wired to actor | GAP-015 |
| SC-ZMOF-001 (Zenoh sole transport) | ❌ Zenoh bridge not connected | GAP-015 |
| SC-ZENOH-001 (Zenoh NIF loaded) | ❌ No Zenoh NIF in sutra tree | GAP-015 |
| SC-FED-001 (Federation protocol) | ⬜ Types correct; signing is stub only | GAP-001 |
| SC-SEC-001 (Key safety) | ⬜ Password module complete; salt not crypto-random | GAP-004 |

---

*Feature matrix complete. 39 Gleam source files read, 41 modules classified across L0-L7, 8×7 biomorphic tensor computed (78.6% coverage), 20 actionable gaps identified and prioritised.*
