# FMEA Top-20 Failure Modes with Mitigations

> Version: 21.3.1-SIL6 | Date: 2026-03-28 | STAMP: SC-FMEA-001, SC-FMEA-004

## Overview

Failure Mode and Effects Analysis (FMEA) for the Indrajaal SIL-6 mesh. RPN is computed
as Severity x Occurrence x Detection (S x O x D), each rated 1-10. Any RPN >= 200
requires immediate action (SC-FMEA-004). Current status: 0 items at RPN >= 200
after full reconciliation.

## Top-20 Failure Modes

| # | Failure Mode | Component | S | O | D | RPN | Mitigation |
|---|-------------|-----------|---|---|---|-----|-----------|
| 1 | Zenoh router crash | zenoh-router | 9 | 3 | 3 | 81 | depends_on + auto-restart, health check every 10s |
| 2 | NIF load failure | Elixir app | 9 | 2 | 4 | 72 | SKIP_ZENOH_NIF=0 enforced, startup gate (SC-ZENOH-008) |
| 3 | Database corruption | indrajaal-db-prod | 9 | 1 | 8 | 72 | WAL mode mandatory, daily backup, ACID (SC-XHOLON-031) |
| 4 | Split brain partition | Cluster mesh | 9 | 2 | 4 | 72 | Apoptosis protocol (SC-SIL4-015), quorum enforcement |
| 5 | Host _build conflict | App container | 8 | 3 | 3 | 72 | Axiom 0.1 enforcement, volume mount validation |
| 6 | OOM on app container | indrajaal-ex-app-1 | 7 | 3 | 3 | 63 | Memory limits in compose, BEAM memory governor |
| 7 | Network partition | Podman network | 7 | 2 | 4 | 56 | Reconnect with backoff (AOR-ZENOH-006), gossip protocol |
| 8 | OTEL collector overload | indrajaal-obs-prod | 6 | 3 | 3 | 54 | Circuit breaker (SC-CIRCUIT-001), drop at queue > 100 |
| 9 | Migration failure | Ecto migrations | 8 | 2 | 3 | 48 | Rollback path, pre-migration snapshot (SC-SIL4-027) |
| 10 | Guardian timeout | Guardian process | 9 | 1 | 5 | 45 | Fail-closed (SC-SIL4-004), DMS backup |
| 11 | Ed25519 key compromise | KMS | 9 | 1 | 5 | 45 | Key rotation, HSM integration planned |
| 12 | Immutable register tamper | Audit trail | 9 | 1 | 5 | 45 | Hash chain verification (SC-SIL4-029), append-only |
| 13 | Topic mismatch | Zenoh pub/sub | 5 | 3 | 3 | 45 | Topic validation at boot, key expression registry |
| 14 | CPU governor failure | Agent operations | 6 | 3 | 2 | 36 | Triple-redundant (Shell + Elixir + F#), PID controller |
| 15 | DuckDB analytics stall | Analytics queries | 5 | 3 | 2 | 30 | Query timeout < 10ms (SC-XHOLON-021), connection pool |
| 16 | Phoenix PubSub flood | LiveView updates | 5 | 3 | 2 | 30 | Rate limiting, circuit breaker per topic |
| 17 | F# MCP tool timeout | Sentinel MCP | 6 | 2 | 2 | 24 | 5s timeout, fallback to simulated mode |
| 18 | Gossip cookie mismatch | Cluster join | 7 | 1 | 3 | 21 | SC-SIL4-014, cookie validation at startup |
| 19 | Stale Digital Twin | State sync | 4 | 3 | 2 | 24 | 30s sync interval (SC-FUNC-008), drift detection |
| 20 | Volume shadow config | Container mount | 8 | 1 | 3 | 24 | Axiom 0.2, pre-seed validation |

## RPN Distribution

```
RPN Range    Count    Action Required
---------    -----    ---------------
200+         0        IMMEDIATE (none currently)
100-199      0        High priority remediation
50-99        8        Monitor and mitigate
25-49        7        Standard monitoring
1-24         5        Accept risk
```

## Severity Scale

| Rating | Meaning | Example |
|--------|---------|---------|
| 10 | Catastrophic | Data loss, safety function bypass |
| 9 | Critical | Safety function impaired |
| 8 | Major | Core service failure |
| 7 | Significant | Subsystem degradation |
| 6 | Moderate | Performance degradation |
| 5 | Minor | Feature degradation |
| 4 | Low | Cosmetic/log issue |
| 3 | Very low | Minor inconvenience |
| 2 | Negligible | Edge case only |
| 1 | None | No user impact |

## Occurrence Scale

| Rating | Meaning | Frequency |
|--------|---------|-----------|
| 10 | Certain | Multiple times per day |
| 7 | Frequent | Weekly |
| 5 | Occasional | Monthly |
| 3 | Rare | Quarterly |
| 1 | Improbable | Never observed |

## Detection Scale

| Rating | Meaning | Method |
|--------|---------|--------|
| 10 | Undetectable | No monitoring |
| 7 | Low | Manual inspection only |
| 5 | Moderate | Periodic automated check |
| 3 | High | Real-time monitoring |
| 1 | Certain | Built-in self-test |

## Related Documents

- CLAUDE.md (SC-FMEA-001 to SC-FMEA-008)
- docs/safety/CROSS_HOLON_DATABASE_STAMP_FMEA_V2.md
- docs/architecture/PRAJNA_FMEA_SIL3_ROBUSTNESS.md
- .claude/rules/constraint-sync-mandatory.md (FMEA section)
