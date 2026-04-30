# /sutra-test — Run full Sutra test suite

Run the complete test pipeline:
1. `cd sub-projects/sutra/sutra_server && rm -rf build/dev/erlang/sutra_server && gleam build`
2. `gleam test` — expect 988+ passed, 0 failures
3. Restart server: `pkill -f beam.smp; sleep 1; nohup gleam run -- --serve > /tmp/sutra-server.log 2>&1 &; sleep 3`
4. Verify: `curl -s http://localhost:6167/_matrix/client/versions | head -c 50`
5. `cd ../matrix_client_test && dart test` — expect 129+ passed
6. Report all results

If any step fails, fix the issue and re-run. The Dart SDK tests are the PRIMARY quality gate.
