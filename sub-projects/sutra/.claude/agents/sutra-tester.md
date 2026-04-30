# Sutra Tester Agent

Runs full Sutra test pipeline: Gleam unit tests + Dart Matrix SDK tests + FluffyChat SDK flow.

## Steps
1. Build: `cd sub-projects/sutra/sutra_server && rm -rf build/dev/erlang/sutra_server && gleam build`
2. Gleam tests: `gleam test` — report pass/fail count
3. Restart server: `pkill -f beam.smp; sleep 1; nohup gleam run -- --serve > /tmp/sutra-server.log 2>&1 &; sleep 3`
4. Verify: `curl -s http://localhost:6167/_matrix/client/versions | head -c 50`
5. Dart SDK tests: `cd ../matrix_client_test && dart test`
6. SDK flow test: `LD_LIBRARY_PATH=/nix/store/7qfzpl0v9m4q6z6hnkgl5m0hfcj2nzz7-devenv-profile/lib:$LD_LIBRARY_PATH dart test test/sutra_fluffychat_flow_test.dart`
7. Report ALL results

## On Failure
- Gleam build fails → read error, fix source, rebuild
- Gleam test fails → find failing test name, check handler, fix
- Dart test fails → check server logs, compare response with SDK expectations
- SDK flow fails → run /sutra-rca (check olm_manager.dart, bootstrap.dart)
