# Secrets Vault — 7-Phase Test Plan

Per **SC-FEAT-EVO-013** (visual verification) + **SC-MATH-COV-001..008** (math gates).

| Phase | Scope | Wall budget | Coverage gate | Files |
|---|---|---|---|---|
| **1. Unit** | NIF + Gleam wrapper + supervisor + sync_actor + rule engine | < 30 s | 200+ tests, H ≥ 2.5 bits, CCM ≥ 0.90 | [phase-1-unit.md](phase-1-unit.md) |
| **2. Integration** | Boot → unseal → put → get → seal round-trip; lease renewal; soft/hard stale boundary; GCP mock pull/push | < 5 min | 50+ tests | [phase-2-integration.md](phase-2-integration.md) |
| **3. Property-based** | Version monotonicity, freshness boundary determinism, wrong-key-never-decrypts | 1000 cases per property | 5 properties × 1000 cases | [phase-3-property.md](phase-3-property.md) |
| **4. Formal** | TLA+ TLC + Apalache + Agda type proofs | weekly cron | 7 invariants + 2 type-level proofs | [phase-4-formal.md](phase-4-formal.md) |
| **5. E2E offline** | iptables drop + clock advance simulation of 1-week network outage | 30 min | hot-path uninterrupted, hard-stale fail-closed correctly | [phase-5-e2e-offline.md](phase-5-e2e-offline.md) |
| **6. Chaos** | Mara process kill, vault.db corruption, audit gap forge, KEK tamper | 1 h per scenario | system survives all 8 scenarios | [phase-6-chaos.md](phase-6-chaos.md) |
| **7. UX (Playwright)** | 4 operator workflows: stale reload, key rotation, outage countdown, TPM PCR mismatch | 10 min | 4 flows, screenshots + video evidence | [phase-7-ux-flows.md](phase-7-ux-flows.md) |

**Total**: ~270+ unit/integration tests + 5 property checks × 1000 cases + 9 formal invariants + 8 chaos scenarios + 4 UX flows.

## Closure gates (all must pass before vault can ship to production)

1. Phase 1: 100% pass + Shannon H ≥ 2.5 + CCM ≥ 0.90 + ITQS ≥ 0.85
2. Phase 2: 0 failures, all transitive paths covered
3. Phase 3: no counter-example found in 1000 generated cases
4. Phase 4: TLC + Apalache green; Agda compiles
5. Phase 5: no fail-open observed; hard-stale precisely at MaxTTL
6. Phase 6: 8/8 scenarios survived (system either degraded gracefully or fail-closed correctly)
7. Phase 7: 4/4 UX flows pass with screenshots + < 30s task completion

## sa-plan tracking

Single closure task: 116494259710729749 (Vault: 7-phase test plan + 200+ initial tests). Sub-tasks created when each phase begins.

## Critical-path ordering

Phases run in dependency order: 1 → 2 → 3, then 4 in parallel with 5/6/7 (formal proofs are independent of runtime tests).

```
Phase 1 ──→ Phase 2 ──→ Phase 3
              ├──→ Phase 5 (offline)
              ├──→ Phase 6 (chaos)
              └──→ Phase 7 (UX)
            Phase 4 (formal) — parallel with 2-7
```

Earliest closure: 1 day with full parallelism after Slices A-E ship.
