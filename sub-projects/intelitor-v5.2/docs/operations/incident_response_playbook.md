# Incident Response Playbook

> Version: 21.3.1-SIL6 | Date: 2026-03-28 | STAMP: SC-SIL4-001, SC-SAFETY-020, SC-VER-045

## Overview

This playbook defines the 5-level escalation framework and recovery procedures for
Indrajaal SIL-6 Biomorphic Fractal Mesh incidents. All operators MUST follow this
sequence when a system anomaly is detected.

## Escalation Levels

| Level | Name | Trigger | Response Time | Authority |
|-------|------|---------|---------------|-----------|
| L1 | Anomaly | Single metric drift > 10% | < 5 min | On-call operator |
| L2 | Degradation | Multiple correlated anomalies | < 2 min | Shift supervisor |
| L3 | Partial Outage | Subsystem failure (1+ containers) | < 60 sec | System engineer |
| L4 | Critical Failure | Safety function impaired | < 30 sec | Guardian (auto) |
| L5 | Emergency Stop | Constitutional violation (Psi-0) | < 5 sec | Jidoka (auto) |

## L1 Anomaly Response

1. Check Prajna cockpit dashboard for metric details
2. Run `sa-status` to get health matrix of all 15 nodes
3. Inspect Zenoh telemetry: `indrajaal/health/{node}`
4. If self-healing resolves within 5 min, log and close
5. If persists, escalate to L2

## L2 Degradation Response

1. Identify root container(s): `sa-status --verbose`
2. Check OTEL traces for cascading failures
3. Verify Zenoh mesh connectivity across all nodes
4. Attempt targeted restart of degraded service
5. If 3+ containers affected, escalate to L3

## L3 Partial Outage Response

1. Activate checkpoint: `sa-verify --snapshot`
2. Identify failure domain (DB / OBS / APP / Zenoh)
3. Execute domain-specific recovery (see below)
4. Verify 2oo3 quorum is maintained
5. If quorum lost, escalate to L4

## L4 Critical Failure Response

1. Guardian auto-triggers fail-safe state (SC-SIL4-001)
2. Dead Man's Switch activates within 50ms (SC-DMS-002)
3. All pending mutations are halted
4. State snapshot saved to Immutable Register
5. If constitutional violation, auto-escalate to L5

## L5 Emergency Stop

1. Jidoka halts all operations < 5 seconds (SC-VER-045)
2. Dying gasp checkpoint written (SC-SIL4-007)
3. All containers enter safe state
4. Manual intervention REQUIRED to restart
5. Post-incident 7-level fractal RCA mandatory

## Top 5 Failure Mode Recovery

### FM-1: Zenoh Router Down (RPN: 81)
```bash
sa-status                           # Confirm router unreachable
podman restart zenoh-router         # Restart router
sa-verify                           # Verify mesh reconnection
```

### FM-2: Database Corruption (RPN: 72)
```bash
sa-down                             # Graceful shutdown
# Restore from last WAL checkpoint
podman exec indrajaal-db-prod pg_restore -d indrajaal backup/latest.dump
sa-up                               # Restart with verification
```

### FM-3: NIF Load Failure (RPN: 72)
```bash
# Verify SKIP_ZENOH_NIF=0 in environment
rm -rf _build deps                  # Clear substrate (Axiom 0.1)
sa-up                               # Rebuild within container
```

### FM-4: Split Brain (RPN: 63)
```bash
sa-status                           # Identify partition
# SC-SIL4-015: Apoptosis triggers automatically
# Minority partition self-terminates
sa-verify                           # Verify quorum restored
```

### FM-5: OOM on App Container (RPN: 56)
```bash
podman stats indrajaal-ex-app-1     # Check memory usage
podman restart indrajaal-ex-app-1   # Restart with limits
sa-verify                           # Verify health
```

## Post-Incident Checklist

- [ ] RCA completed (7-level fractal)
- [ ] Timeline documented with CEST timestamps
- [ ] Immutable Register entries verified
- [ ] STAMP constraint violations identified
- [ ] Corrective actions logged in sa-plan
- [ ] Journal entry created in docs/journal/

## Related Documents

- CLAUDE.md Section 5.0 (STAMP Constraints)
- docs/safety/IEC_61508_SAFETY_REQUIREMENTS.md
- docs/architecture/SAFE_HARBOR_DEPLOYMENT_PROTOCOL.md
- .claude/rules/functional-invariant.md
