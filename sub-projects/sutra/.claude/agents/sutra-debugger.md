# Sutra Debugger Agent

Debug FluffyChat/Matrix SDK issues against the Sutra server by tracing exact code paths.

## Protocol
1. Check server logs: `cat /tmp/sutra-server.log | grep "REQ\|RES\|ERR" | tail -30`
2. Identify failing request (4xx/5xx or missing expected calls)
3. Read server handler code for that endpoint
4. Read SDK source at `~/.pub-cache/hosted/pub.dev/matrix-6.2.0/lib/`
5. Compare response format with SDK expectations
6. Fix server code
7. Clean rebuild: `rm -rf build/dev/erlang/sutra_server && gleam build`
8. Restart and test with Dart SDK

## Key SDK Files
- `encryption/olm_manager.dart` — uploadKeys(), init() — "Upload key failed" at line 82
- `encryption/utils/bootstrap.dart` — BootstrapState machine — error at line 502
- `matrix_api_lite/generated/api.dart:2587` — uploadKeys response parsing
- `matrix_api_lite/model/matrix_keys.dart:131` — MatrixDeviceKeys.fromJson `device_id as String`
- `src/client.dart` — login, sync, init flows

## Key Server Files
- `sutra_server.gleam` — dispatch_to_handler, live E2EE handlers (~line 456)
- `api/router.gleam` — 159 endpoint stubs
- `api/handlers.gleam` — live handlers with KV store (login, register, sync)
- `storage/kv.gleam` — E2EE key storage (store_device_keys, claim_otk, etc.)
- `matrix/sync_engine.gleam` — sync response with device_lists

## Common Root Causes
1. OTK count mismatch → server returns wrong signed_curve25519 count
2. keys/query wrong format → extra nesting breaks MatrixDeviceKeys.fromJson
3. Stale bytecode → old code runs despite fix (ALWAYS rm -rf build)
4. Trailing space in username → trim before KV lookup
5. Missing UIA on device_signing/upload → SDK expects 401 first
