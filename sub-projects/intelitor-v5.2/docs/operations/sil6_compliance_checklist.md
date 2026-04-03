# SIL-6 Compliance Checklist for Operators

> Version: 21.3.1-SIL6 | Date: 2026-03-28 | STAMP: SC-SIL4-001, SC-SIL-001, SC-HA-001

## Overview

This checklist ensures Indrajaal meets SIL-6 Biomorphic Extended compliance requirements
derived from IEC 61508, DO-178C DAL-A, and EN 50131. Operators MUST verify all 20 items
before declaring a deployment production-ready.

## Pre-Deployment Verification (Items 1-8)

| # | Item | Constraint | Verified |
|---|------|-----------|----------|
| 1 | Safety functions fail to safe state | SC-SIL4-001 | [ ] |
| 2 | Type boundary checks are fail-closed | SC-SIL4-002 | [ ] |
| 3 | Container image signatures verified (Ed25519) | SC-SIL4-024 | [ ] |
| 4 | Boot DAG validated (Kahn's algorithm, acyclic) | SC-SIL4-010 | [ ] |
| 5 | 5 startup phases confirmed mandatory | SC-SIL4-012 | [ ] |
| 6 | 6 shutdown phases confirmed mandatory | SC-SIL4-013 | [ ] |
| 7 | Container start order: DB -> OBS -> APP | SC-SIL4-005 | [ ] |
| 8 | Quorum floor(N/2)+1 maintained | SC-SIL4-011 | [ ] |

## Runtime Safety (Items 9-14)

| # | Item | Constraint | Verified |
|---|------|-----------|----------|
| 9 | 2oo3 voting active for production actuations | SC-SIL4-006 | [ ] |
| 10 | Dead Man's Switch heartbeat at 100ms interval | SC-DMS-001 | [ ] |
| 11 | Failsafe triggers within 50ms of timeout | SC-DMS-002 | [ ] |
| 12 | Split-brain detection triggers apoptosis | SC-SIL4-015 | [ ] |
| 13 | Safe failure fraction >= 90% | SC-SIL-002 | [ ] |
| 14 | Diagnostic coverage >= 90% | SC-SIL-003 | [ ] |

## State Integrity (Items 15-17)

| # | Item | Constraint | Verified |
|---|------|-----------|----------|
| 15 | Dying gasp checkpoint before shutdown | SC-SIL4-007 | [ ] |
| 16 | Immutable register integrity verified | SC-SIL4-029 | [ ] |
| 17 | State snapshot taken before any upgrade | SC-SIL4-027 | [ ] |

## Mesh & Federation (Items 18-20)

| # | Item | Constraint | Verified |
|---|------|-----------|----------|
| 18 | Gossip protocol cookie configured | SC-SIL4-014 | [ ] |
| 19 | FPPS 3/5 consensus for health validation | SC-SIL4-023 | [ ] |
| 20 | Rollback path with 24-hour window active | SC-SIL4-026 | [ ] |

## Verification Commands

```bash
# Item 1-3: Safety + image verification
./sa-verify --safety

# Item 4: DAG validation
./sa-verify --dag

# Item 8: Quorum check
./sa-verify --quorum

# Item 9: 2oo3 voting test
./sa-verify --voting

# Item 10-11: DMS health
curl -s http://localhost:4000/health | jq '.dms'

# Item 16: Register integrity
./sa-verify --register

# Item 19: FPPS consensus
./sa-verify --fpps
```

## Compliance Matrix

| Standard | Requirement | Indrajaal Implementation |
|----------|------------|-------------------------|
| IEC 61508 SIL-4 | PFD < 10^-4/hr | 2oo3 voting + DMS |
| IEC 61508 SIL-6 (ext) | Biomorphic resilience | Self-healing mesh + apoptosis |
| DO-178C DAL-A | MC/DC coverage | Formal proofs (Agda) |
| EN 50131 | Intrusion detection | Sentinel + Guardian |
| ISO 27001 | Information security | KMS + Ed25519 signing |

## Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| System Engineer | | | |
| Safety Officer | | | |
| Operations Lead | | | |

## Related Documents

- CLAUDE.md Section 1.0 (Fundamental Axioms)
- docs/safety/IEC_61508_SAFETY_REQUIREMENTS.md
- docs/architecture/SIL6_7LAYER_FRACTAL_ARCHITECTURE.md
- .claude/rules/reconciled-p0-safety.md
