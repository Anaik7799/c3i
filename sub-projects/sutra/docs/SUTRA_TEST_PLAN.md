# Sutra Matrix Homeserver — Test Plan

**Version**: v0.1.0 | **API**: Matrix CS v1.18 + SS v1.13 | **Port**: 6167

## 1. Overview

Sutra is a Gleam-first Matrix homeserver running on the BEAM VM. The test strategy uses four layers:

```
L4 Flow         — FluffyChat simulation (sutra_fluffychat_flow_test.dart)
L3 E2E          — Dart Matrix SDK against live server (9 test files, 901 test() calls)
L2 Integration  — Gleam: actor + handler + NIF integration (22 test files)
L1 Unit         — Gleam: pure function logic, JSON shape, storage ops
```

The **Dart SDK tests are the primary quality gate** — they use the identical SDK as FluffyChat production clients.

---

## 2. Test Pyramid Summary

| Layer | Runner | Files | Tests | Gate |
|-------|--------|-------|-------|------|
| L1/L2 Unit+Integration | `gleam test` | 22 | 1,085+ | Required before commit |
| L3 SDK Integration | `dart test` | 9 | 901 | Required before commit |
| L4 FluffyChat Flow | `dart test <file>` | 1 | 7 flows | Required for E2EE changes |
| **Total** | | **31** | **1,986+** | |

---

## 3. Gleam Test Suite Inventory (22 files, 1,085+ tests)

| File | Tests | Coverage Area |
|------|-------|---------------|
| `sutra_matrix_spec_compliance_test.gleam` | 96 | Matrix protocol spec compliance, all endpoint shapes |
| `sutra_router_coverage_test.gleam` | 79 | 159 endpoint route dispatch, status codes |
| `sutra_client_simulator_test.gleam` | 110 | Multi-client simulation, concurrent state |
| `sutra_edge_cases_test.gleam` | 112 | Injection, path traversal, Unicode, malformed JSON |
| `sutra_zenoh_nif_test.gleam` | 94 | Zenoh NIF: open/put/health/stats, 30 topics |
| `sutra_sqlite_ops_test.gleam` | 53 | SQLite 17-table schema, CRUD, WAL mode |
| `sutra_federation_crosssigning_test.gleam` | 53 | S-S API, cross-signing key upload (UIA) |
| `sutra_storage_directory_test.gleam` | 46 | KV store, room directory, persistent storage |
| `sutra_encryption_media_search_test.gleam` | 46 | E2EE key ops, media upload/download, search |
| `sutra_integration_test.gleam` | 49 | End-to-end actor message dispatch |
| `sutra_appservice_spaces_zenoh_test.gleam` | 36 | Appservice API, spaces, Zenoh span publishing |
| `sutra_aliases_acl_devices_backup_test.gleam` | 41 | Room aliases, server ACL, device list, key backup |
| `sutra_presence_push_admin_test.gleam` | 39 | Presence, push rules, admin endpoints |
| `sutra_threads_reactions_redaction_test.gleam` | 33 | Thread relations, reactions, event redaction |
| `sutra_user_journey_test.gleam` | 40 | Register → room → message → sync journey |
| `sutra_live_client_test.gleam` | 31 | Live HTTP client against running server |
| `sutra_server_test.gleam` | 63 | Main server actor lifecycle, state management |
| `sutra_handlers_rooms_test.gleam` | 10 | Room creation, join, leave, invite handlers |
| `sutra_handlers_misc_test.gleam` | 20 | Capabilities, versions, well-known, admin |
| `sutra_handlers_ephemeral_test.gleam` | 14 | Typing, receipts, presence ephemeral events |
| `sutra_handlers_federation_test.gleam` | 19 | Federation send, backfill, key server |
| `json_benchmark_test.gleam` | 1 | serdes_json NIF throughput benchmark |

### How to Run Gleam Tests

```bash
cd sub-projects/sutra/sutra_server
rm -rf build/dev/erlang/sutra_server   # SC-OPS-001: always clear bytecode
gleam build                             # must show 0 errors, 0 warnings
gleam test                              # must show 988+ passed, 0 failures
```

---

## 4. Dart SDK Test Suite Inventory (9 files, 901 test() calls)

| File | Tests | Coverage Area |
|------|-------|---------------|
| `sutra_500_comprehensive_test.dart` | 254 | Comprehensive 500-scenario API coverage |
| `sutra_comprehensive_200_test.dart` | 200 | 200 happy-path scenarios, all CS API groups |
| `sutra_full_e2e_test.dart` | 162 | Full E2E: register, rooms, messages, sync |
| `sutra_dual_client_test.dart` | 121 | Two clients, room invite, message exchange |
| `sutra_zenoh_e2e_test.dart` | 100 | Zenoh span verification: 30 topic namespaces |
| `sutra_vs_tuwunel_benchmark_test.dart` | 25 | Sutra vs Tuwunel: latency, throughput |
| `sutra_compliance_test.dart` | 31 | Matrix spec compliance assertions |
| `sutra_fluffychat_flow_test.dart` | 7 | FluffyChat login → E2EE → Bootstrap flows |
| `sutra_sdk_login_test.dart` | 1 | SDK login baseline smoke test |

### How to Run Dart Tests

```bash
# Prerequisite: server must be running on port 6167
cd sub-projects/sutra/matrix_client_test

# Full suite (primary gate)
dart test

# FluffyChat flow test only (E2EE changes)
LD_LIBRARY_PATH=/nix/store/7qfzpl0v9m4q6z6hnkgl5m0hfcj2nzz7-devenv-profile/lib:$LD_LIBRARY_PATH \
  dart test test/sutra_fluffychat_flow_test.dart

# Zenoh E2E verification only
dart test test/sutra_zenoh_e2e_test.dart

# Single file
dart test test/sutra_full_e2e_test.dart
```

---

## 5. NIFs Under Test

| NIF | `.so` File | Test File | Functions Tested |
|-----|-----------|-----------|-----------------|
| `serdes_json` | `serdes_json_nif.so` | `json_benchmark_test.gleam` | object_raw, embed, nest, merge, encode_event, otk_claim_response, device_keys_response, validate, escape |
| `bcrypt` | `bcrypt_nif.so` | `sutra_server_test.gleam` | hash_password, verify_password, ed25519_sign, ed25519_verify |
| `rocksdb` (sled) | `rocksdb_nif.so` | `sutra_storage_directory_test.gleam` | open, put, get, delete, scan_prefix |
| `zenoh` | `zenoh_nif.so` | `sutra_zenoh_nif_test.gleam` | open, is_open, put, health, stats, close (6 NIF functions) |

---

## 6. Zenoh Integration Test Strategy

The Zenoh E2E test (`sutra_zenoh_e2e_test.dart`) verifies that every Matrix API operation publishes to the correct Zenoh topic namespace.

**Live stats endpoint**: `GET http://localhost:6167/_sutra/zenoh/stats`
```json
{"connected":true,"puts_total":2025,"puts_failed":138,"spans_total":2247}
```

**Health endpoint**: `GET http://localhost:6167/_sutra/zenoh/health`
```json
{"connected":true,"topics":30,"nif_functions":6,"gleam_api_functions":37}
```

### 30 Topic Namespaces Verified

| Topic Pattern | Event Type | Test Coverage |
|--------------|-----------|---------------|
| `indrajaal/sutra/span/{method}/{status}` | OTel request span (every request) | Auto on all requests |
| `indrajaal/sutra/auth/{action}` | login, register, logout | sutra_zenoh_e2e_test |
| `indrajaal/sutra/room/{action}` | create, join, leave, invite | sutra_zenoh_e2e_test |
| `indrajaal/sutra/message/sent` | message events | sutra_zenoh_e2e_test |
| `indrajaal/sutra/e2ee/{action}` | keys upload/query/claim/cross-sign | sutra_zenoh_e2e_test |
| `indrajaal/sutra/sync/{user}` | sync events | sutra_zenoh_e2e_test |
| `indrajaal/sutra/health` | server health pings | sutra_zenoh_e2e_test |
| `indrajaal/sutra/req/{method}/{path}` | request telemetry | sutra_zenoh_e2e_test |
| `indrajaal/test/sutra/{test}` | closed-loop test observations | sutra_zenoh_e2e_test |
| + 21 more namespaces | typing, presence, receipt, device, media, search, state, membership, push, account_data, directory, federation, admin, backup, to_device, filter, profile, capabilities, sliding_sync, stats | sutra_appservice_spaces_zenoh_test |

---

## 7. STAMP Constraints Covered

| ID | Constraint | Test Coverage |
|----|-----------|---------------|
| SC-SUTRA-001 | All 159 endpoints must respond | `sutra_router_coverage_test.gleam` |
| SC-SUTRA-002 | OTK count must match uploaded count | `sutra_fluffychat_flow_test.dart`, `sutra_federation_crosssigning_test.gleam` |
| SC-SUTRA-003 | keys/query format spec | `sutra_encryption_media_search_test.gleam`, `sutra_fluffychat_flow_test.dart` |
| SC-SUTRA-004 | device_signing/upload UIA (401→200) | `sutra_federation_crosssigning_test.gleam` |
| SC-SUTRA-005 | Username trailing spaces trimmed | `sutra_edge_cases_test.gleam` |
| SC-SUTRA-006 | Clean build (rm -rf bytecode) | All test sequences |
| SC-SUTRA-007 | Dart SDK tests mandatory | `dart test` (9 files) |
| SC-SUTRA-008 | /sync includes device_lists.changed | `sutra_full_e2e_test.dart` |
| SC-E2EE-001..007 | Full E2EE key operations | `sutra_fluffychat_flow_test.dart` |
| SC-MATRIX-001..010 | Matrix protocol compliance | `sutra_matrix_spec_compliance_test.gleam` |
| SC-JSON-001..004 | gleam/json + serdes_json only | `json_benchmark_test.gleam`, code review |

---

## 8. FMEA Risk Table

| Test Area | Failure Mode | S | O | D | RPN | Mitigation |
|-----------|-------------|---|---|---|-----|-----------|
| E2EE bootstrap | OTK count mismatch → FluffyChat "Upload key failed" | 9 | 5 | 2 | 90 | `sutra_fluffychat_flow_test.dart` + SDK line 274 check |
| keys/query format | Wrong nesting → SDK parse failure, no E2EE | 9 | 4 | 2 | 72 | `sutra_federation_crosssigning_test.gleam` + dart test |
| Stale bytecode | Bug appears fixed but not deployed | 8 | 7 | 1 | 56 | SC-OPS-001: `rm -rf build/dev/erlang/sutra_server` |
| Zenoh NIF crash | Server loses observability, degraded mode | 6 | 3 | 3 | 54 | Graceful degradation, `sutra_zenoh_nif_test.gleam` |
| /sync missing device_lists | E2EE key tracking broken | 8 | 3 | 2 | 48 | `sutra_full_e2e_test.dart` assertions |
| UIA for cross-signing | Missing 401 stage → SDK error | 8 | 3 | 2 | 48 | `sutra_federation_crosssigning_test.gleam` |
| SQLite WAL contention | Data loss under concurrent writes | 7 | 2 | 4 | 56 | `sutra_sqlite_ops_test.gleam` concurrent tests |
| serdes_json raw embed | XSS via unescaped user JSON | 9 | 2 | 2 | 36 | SC-JSON-004: `json.string()` mandatory |
| 159 endpoint coverage | Untested endpoint returns wrong shape | 6 | 4 | 2 | 48 | `sutra_router_coverage_test.gleam` |
| rocksdb NIF unavailable | Falls back to in-memory only, data lost on restart | 5 | 3 | 3 | 45 | Graceful fallback logged, `sutra_storage_directory_test.gleam` |

---

## 9. Complete Test Sequence (After Any Code Change)

```bash
# Step 1: Build with clean bytecode (SC-OPS-001)
cd sub-projects/sutra/sutra_server
rm -rf build/dev/erlang/sutra_server
gleam build

# Step 2: Unit + integration tests
gleam test
# Expected: 988+ passed, 0 failures

# Step 3: Restart server
pkill -f beam.smp 2>/dev/null; sleep 1
nohup gleam run -- --serve > /tmp/sutra-server.log 2>&1 &
sleep 3
curl -s http://localhost:6167/_matrix/client/versions | head -c 80

# Step 4: Dart SDK tests (PRIMARY gate — SC-TEST-002)
cd ../matrix_client_test
dart test
# Expected: 129+ passed, 0 failures

# Step 5: FluffyChat flow test (for E2EE changes — SC-TEST-003)
LD_LIBRARY_PATH=/nix/store/7qfzpl0v9m4q6z6hnkgl5m0hfcj2nzz7-devenv-profile/lib:$LD_LIBRARY_PATH \
  dart test test/sutra_fluffychat_flow_test.dart

# Step 6: Verify Zenoh telemetry
curl -s http://localhost:6167/_sutra/zenoh/health
curl -s http://localhost:6167/_sutra/zenoh/stats
```

---

## 10. Coverage Gaps and Next Steps

| Gap | Priority | Description |
|-----|----------|-------------|
| Federation S-S API live tests | P1 | No live Dart test hitting `/_matrix/federation/` against a second homeserver |
| Sliding sync (MSC3575) | P1 | Gleam stub exists, no Dart SDK coverage |
| Key backup restore flow | P2 | upload tested, restore/recover flow not tested end-to-end |
| Push notification delivery | P2 | Push rule evaluation tested, no actual push gateway integration test |
| Concurrent sync stress | P2 | `sutra_dual_client_test.dart` covers 2 clients; need 10+ concurrent |
| Media download after restart | P2 | Media stored in KV (in-memory); persistent media not tested |
| Zenoh span failure injection | P3 | No test verifying graceful degradation when Zenoh router is down |
