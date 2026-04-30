# /sutra-evolve — Add a new Matrix endpoint or feature

Steps:
1. Add route in `router.gleam` (literal match or prefix match)
2. Add live handler in `dispatch_to_handler` (`sutra_server.gleam`) if it needs KV store access
3. Add Gleam unit test in `test/`
4. Add Dart SDK test in `matrix_client_test/test/`
5. Run `/sutra-test` to verify all green
6. Update `docs/matrix-compliance-map.md`
7. Ingest to ZK
