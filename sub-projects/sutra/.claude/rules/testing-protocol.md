# Testing Protocol (SC-TEST-SUTRA)

## MANDATE
ALL server changes MUST be tested with BOTH Gleam unit tests AND Dart Matrix SDK tests against the live server. The Dart SDK tests are the PRIMARY quality gate — they use the same SDK as FluffyChat.

| ID | Constraint | Severity |
|----|-----------|----------|
| SC-TEST-001 | gleam test must pass with 0 failures before any commit | CRITICAL |
| SC-TEST-002 | dart test must pass against live server before any commit | CRITICAL |
| SC-TEST-003 | SDK flow test (sutra_fluffychat_flow_test.dart) must pass | HIGH |
| SC-TEST-004 | Server must be restarted with clean bytecode after code changes | CRITICAL |
| SC-TEST-005 | New endpoints must have both Gleam unit test AND Dart SDK test | HIGH |
| SC-TEST-006 | Edge case tests (injection, traversal, Unicode) must pass | MEDIUM |

## Test Sequence After Any Change
```bash
# 1. Build
cd sub-projects/sutra/sutra_server
rm -rf build/dev/erlang/sutra_server && gleam build

# 2. Gleam tests
gleam test

# 3. Restart server
pkill -f beam.smp; sleep 1
nohup gleam run -- --serve > /tmp/sutra-server.log 2>&1 &
sleep 3

# 4. Dart SDK tests (PRIMARY gate)
cd ../matrix_client_test
dart test

# 5. SDK flow test (FluffyChat simulation)
LD_LIBRARY_PATH=/nix/store/7qfzpl0v9m4q6z6hnkgl5m0hfcj2nzz7-devenv-profile/lib:$LD_LIBRARY_PATH \
  dart test test/sutra_fluffychat_flow_test.dart
```
