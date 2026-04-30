# Server Operations (SC-OPS-SUTRA)

## MANDATE
The server must always be in a running, testable state. Stale bytecode is the #1 cause of bugs appearing fixed but not deployed.

| ID | Constraint | Severity |
|----|-----------|----------|
| SC-OPS-001 | Always rm -rf build/dev/erlang/sutra_server before gleam build | CRITICAL |
| SC-OPS-002 | Always pkill -f beam.smp before starting new server | HIGH |
| SC-OPS-003 | Verify server with curl after restart | HIGH |
| SC-OPS-004 | Check /tmp/sutra-server.log for errors after restart | HIGH |
| SC-OPS-005 | Server must respond on port 6167 within 3 seconds of start | HIGH |

## Anti-Patterns
- NEVER assume gleam build picked up changes — always clean first
- NEVER skip the dart test step — it catches format/protocol bugs Gleam tests miss
- NEVER test against a stale server — always restart after code changes
