# /sutra-server — Manage Sutra server

Operations:
- **start**: `pkill -f beam.smp; sleep 1; cd sub-projects/sutra/sutra_server && rm -rf build/dev/erlang/sutra_server && gleam build && nohup gleam run -- --serve > /tmp/sutra-server.log 2>&1 &`
- **stop**: `pkill -f beam.smp`
- **restart**: stop + start
- **status**: `curl -s http://localhost:6167/_matrix/client/versions | head -c 50`
- **logs**: `cat /tmp/sutra-server.log | grep "REQ\|RES\|ERR" | tail -20`

CRITICAL: Always rm -rf build/dev/erlang/sutra_server before gleam build. Stale BEAM cache causes old code to run.
