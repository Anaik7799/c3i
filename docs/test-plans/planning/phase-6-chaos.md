# Phase 6 — Chaos / fault injection (L0, L1, L4, L6)

## Scenarios

| # | Fault | Injection | Expected outcome | Authority |
|---|---|---|---|---|
| 1 | NIF panic on `plan_status` | `cargo build` with intentional `unwrap` panic; restart BEAM | NIF crash isolated; BEAM stays up; `staleness="dead"` after 300 s; emergency cockpit | SC-NIF-001..006 |
| 2 | WebSocket connection drop mid-flight | `iptables -A OUTPUT -p tcp --dport 4100 -j DROP` for 15 s | Client exponential backoff (1→2→4→8 s); polling fallback at 5 s; resync on reconnect | SC-AGUI-UI-006, SC-DRIFT-007 |
| 3 | Smriti.db write lock contention | Parallel `sa-plan add` ×16 | At-most-one write succeeds; others retry; integrity preserved (WAL) | SC-XHOLON-002 |
| 4 | Hot-reload mid-flight (router updated mid-WS) | `gleam build` while `ping` in flight | `code:soft_purge` waits for `ping` to drain; subsequent ping uses new code | SC-HA-RELOAD-002..008 |
| 5 | Zenoh router partition (split-brain) | Disconnect zenoh-router-1 | 2oo3 quorum holds; OTel spans buffered; reconnect drains queue (Rule 184 backpressure) | SC-FED-006, SC-CPIG-FED-007 |
| 6 | Stale data injection (clock skew) | Set NIF clock back 600 s | `freshness_monitor` escalates to dead; UI banner red; manual recovery required | SC-TRUTH-001..010 |
| 7 | Mara chaos agent activates random tab kills | Kill ex-app-1 mid-run | OODA decides Restart; rules engine fires `RecoveryNif` playbook | SC-IMMUNE-001..010 |
| 8 | Page-spec drift (someone removed `task-detail-panel`) | Delete element in DOM | page-spec checker P1 task within 5 min cadence | SC-PAGE-SPEC-003 |
| 9 | Value-guard violation (insert priority='SUPREME') | `INSERT … Priority='SUPREME'` | SQL CHECK constraint fails; data_quality_scan opens P0 task | SC-VALUE-GUARD-007 |
| 10 | Pi runtime circuit-breaker storm | 3 sequential Gemma timeouts | breaker opens 60 s; fallback to NIF search; static ack on prolonged failure | SC-PI-RUNTIME-002 |

## Exit criteria

- All 10 scenarios self-recover within their respective SLA windows.
- ΣRPN reduction ≥ 50 %.
- Lyapunov λ ≥ 0 over 3-pass window after chaos.
- No data corruption (Smriti.db PRAGMA `integrity_check;` returns `ok`).
