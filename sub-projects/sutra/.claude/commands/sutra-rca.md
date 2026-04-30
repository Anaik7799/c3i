# /sutra-rca — Fractal RCA for FluffyChat/Matrix SDK issues

Steps:
1. Check server logs: `cat /tmp/sutra-server.log | grep "REQ\|RES\|ERR" | tail -30`
2. Identify the failing request sequence (look for retry loops or missing calls)
3. Trace the code path: router.gleam → dispatch_to_handler → handler
4. Check the Matrix SDK source at `~/.pub-cache/hosted/pub.dev/matrix-6.2.0/lib/`
5. Key SDK files:
   - `encryption/olm_manager.dart` — uploadKeys(), init(), "Upload key failed"
   - `encryption/utils/bootstrap.dart` — BootstrapState machine
   - `matrix_api_lite/generated/api.dart:2587` — response parsing
   - `matrix_api_lite/model/matrix_keys.dart:131` — MatrixDeviceKeys.fromJson
6. Compare server response format with SDK expectations
7. Fix server code
8. Clean build + restart: `rm -rf build/dev/erlang/sutra_server && gleam build`
9. Run SDK flow test to verify
10. Document in `docs/fluffychat-rca.md`
