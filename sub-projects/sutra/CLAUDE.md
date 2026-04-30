# Sutra Matrix Homeserver — Claude Guidance

## Identity
Sutra is a Gleam-first Matrix homeserver implementing the full Matrix Client-Server and Server-Server APIs.
- **Language**: Gleam (type-safe, BEAM VM)
- **API**: Matrix CS API v1.18 + SS API v1.13
- **Port**: 6167 (HTTP), Tailscale HTTPS
- **FQDN**: vm-1.tail55d152.ts.net
- **Test Users**: admin/password, vm-1-bot/!!112233!!

## Architecture
```
sutra_server/src/sutra_server/
  api/           — router.gleam (1860 lines, 159 endpoints) + 6 handler modules
  matrix/        — 20 domain modules (encryption, devices, push, presence, etc.)
  storage/       — kv.gleam (in-memory), sqlite.gleam (17 tables), sqlite_ops.gleam
  federation/    — transport, backfill, resolver
  integration/   — zenoh_bridge
specs/           — 5 TLA+ + 5 Agda + 5 Quint (15 formal specs)
docs/            — compliance map, feature matrix, tuwunel map, RCA, state-path analysis
matrix_client_test/ — Dart Matrix SDK tests (129+ tests, same SDK as FluffyChat)
```

## Build & Test

### Gleam
```bash
cd sub-projects/sutra/sutra_server
rm -rf build/dev/erlang/sutra_server  # CRITICAL: clear cached bytecode
gleam build    # 0 errors, 0 warnings
gleam test     # 988+ passed, 0 failures
```

### Dart Matrix SDK (real client — PRIMARY quality gate)
```bash
cd sub-projects/sutra/matrix_client_test
dart test      # 129+ passed against live server
```

### SDK Flow Test (FluffyChat simulation)
```bash
LD_LIBRARY_PATH=/nix/store/7qfzpl0v9m4q6z6hnkgl5m0hfcj2nzz7-devenv-profile/lib:$LD_LIBRARY_PATH \
  dart test test/sutra_fluffychat_flow_test.dart
```

### Server Start/Restart
```bash
pkill -f beam.smp 2>/dev/null; sleep 1
cd sub-projects/sutra/sutra_server
rm -rf build/dev/erlang/sutra_server && gleam build
nohup gleam run -- --serve > /tmp/sutra-server.log 2>&1 &
```

## Key Constraints

| ID | Constraint | Severity |
|----|-----------|----------|
| SC-SUTRA-001 | All 159 endpoints must respond | CRITICAL |
| SC-SUTRA-002 | OTK count must match uploaded count in keys/upload response | CRITICAL |
| SC-SUTRA-003 | keys/query format: `{userId: {deviceId: {user_id,device_id,algorithms,keys,signatures}}}` | CRITICAL |
| SC-SUTRA-004 | device_signing/upload requires UIA (401 then 200) | CRITICAL |
| SC-SUTRA-005 | Username trailing spaces must be trimmed | HIGH |
| SC-SUTRA-006 | Always rm -rf build/dev/erlang/sutra_server before gleam build | CRITICAL |
| SC-SUTRA-007 | ALL changes tested with Dart SDK against live server | CRITICAL |
| SC-SUTRA-008 | /sync must include device_lists.changed | CRITICAL |

## FluffyChat Login Sequence
```
well-known → versions → login flows → auth_metadata(404) → POST login
→ POST keys/upload → GET sync → POST keys/query
→ POST device_signing/upload (UIA 401→200) → Bootstrap
```

## Storage
- **KV Store** (in-memory): users, rooms, events, tokens, media, device_keys, one_time_keys, cross_signing_keys
- **SQLite** (17 tables): users, devices, rooms, room_state, events, event_edges, event_auth, media, tokens, account_data, presence, push_rules, receipts, room_aliases, device_keys, one_time_keys, cross_signing_keys
