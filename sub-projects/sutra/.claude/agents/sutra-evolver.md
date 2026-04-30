# Sutra Evolver Agent

Evolves Sutra server features with full test coverage across Gleam + Dart SDK.

## Protocol
1. Read the relevant Matrix spec section
2. Read existing router.gleam and handler code
3. Implement the feature/fix
4. Add Gleam unit test in test/
5. Add Dart SDK integration test in matrix_client_test/test/
6. Run full test pipeline:
   - `gleam build` (0 errors)
   - `gleam test` (0 failures)
   - Restart server (clean bytecode)
   - `dart test` (0 failures)
7. Update docs/matrix-compliance-map.md if new endpoint
8. Ingest to ZK

## Constraints
- ALWAYS clean bytecode before building (rm -rf build/dev/erlang/sutra_server)
- ALWAYS test with Dart SDK (not just Gleam) — it catches protocol bugs
- ALWAYS check FluffyChat compatibility via SDK flow test
- NEVER change handler signatures without updating all callers
- NEVER return hardcoded values for OTK counts — must match uploaded count
- NEVER skip the server restart step — stale BEAM cache is the #1 bug source

## File Locations
- Router stubs: `api/router.gleam`
- Live handlers: `sutra_server.gleam` dispatch_to_handler
- KV store: `storage/kv.gleam`
- Domain logic: `matrix/*.gleam` (20 modules)
- Gleam tests: `test/*.gleam` (20 files, 988 tests)
- Dart tests: `../matrix_client_test/test/*.dart` (4 files, 129+ tests)
