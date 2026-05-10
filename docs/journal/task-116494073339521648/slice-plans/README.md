# Vault Slice Plans — index

Detailed continuation plans for each remaining slice of the secrets vault evolution.

**Parent task**: `urn:c3i:task:misc:116494073339521648`
**Tailscale**: https://vm-1.tail55d152.ts.net:8443/task-id/116494073339521648/slice-plans/

| Slice | Plan | sa-plan | Effort | RPN | Depends on | Unblocks |
|---|---|---|---|---:|---|---|
| **B continuation** | [slice-b-continuation.md](slice-b-continuation.md) | 116494382047537935 | 2-3 sessions | 180 | A ✅ | C, E |
| **C continuation** | [slice-c-continuation.md](slice-c-continuation.md) | 116494259021299827 | 1-2 sessions | 160 | B | unattended boot |
| **D continuation** | [slice-d-continuation.md](slice-d-continuation.md) | 116494259024062400 | 1 session | 175 | B | sync convergence |
| **E continuation** | [slice-e-continuation.md](slice-e-continuation.md) | 116494259026350434 | 1-2 sessions | 288 | B | full caller flip + .pi/ migration |
| **F closure** | [slice-f.md](slice-f.md) | 116494259028115525 | 1-2 sessions | 168 | A-E | END STATE |

**Total remaining effort**: 6-10 sessions across 5 slices.
**Total LOC remaining**: ~5,094 (1,175 B + 946 C + 668 D + 755 E + 1,550 F).

## Critical-path DAG

```
A (vendored) ✅
  └─→ B continuation (NIF body) ──┬─→ C continuation (KEK chain)
                                  │
                                  ├─→ D continuation (GCP sync)
                                  │
                                  ├─→ E continuation (caller flip + .pi/)
                                  │
                                  └─→ F closure (test execution + dashboard + audit reconcile)
```

B is the bottleneck — once stub bodies are real, C/D/E can ship in parallel. F depends on all.

## What's been shipped already (across passes 1-4)

- **Pass 1** (Slice A + governance): vendored RustyVault, scrubbed Tongsuo patch, 12 diagrams, journal, RCA, TPS, fractal matrix, 7-phase test plan, 25 SC-VAULT + 1 SC-VAULT-CRYPTO + 15 AOR-VAULT, .gemini parity, ZK ingest
- **Pass 2** (Slice B partial): NIF skeleton with 10 functions + Erlang shim + Gleam typed wrapper + cargo audit gate + pre-commit hook script
- **Pass 3** (governance + Slice C skeleton): 12 RETE-UL rules in 2 domains, TLA+ + Apalache.cfg + Agda + Allium specs, vault_supervisor.gleam, pre-commit hook ARMED in `.git/hooks/pre-commit`, 4 Oban schedules registered
- **Pass 4** (Slice D + E skeletons): vault_sync_actor.gleam (circuit breaker + conflict resolution), secret_api.gleam Wisp REST (3 endpoints, OIDC-gated), 4 cron-referenced gleam scripts (no more silent cron failures)
- **Pass 5** (this): 5 detailed slice continuation plans (this directory)

Cumulative tests: **9370 passing** (+23 from baseline 9347).

## Reading order

For a fresh implementer picking up this task:

1. Start with the [parent journal](../journal.md) for context (13-section)
2. Read the [5-level fractal RCA](../5-level-fractal-rca.md) to understand WHY
3. Read [TPS countermeasures](../tps-countermeasures.md) to understand defense-in-depth design
4. Read [fractal-criticality-matrix.md](../fractal-criticality-matrix.md) to understand impact scoring
5. Read this index, then the 5 slice plans in critical-path order: **B → C → D → E → F**
6. Cross-reference [test-plan/README.md](../test-plan/README.md) for the 7 testing phases that close the loop
7. Use the 12 PNG diagrams (`../diagrams/png/01..12.png`) as visual aids

## Status snapshot for operator dashboard (refreshed Pass-10)

| Metric | Value |
|---|---:|
| Plan completeness | ✅ 5/5 slice plans written |
| Skeleton completeness | ✅ 4/5 slices (A done; B/C/D/E skeleton + MoZ dispatcher; F is closure) |
| Body completeness | ⏳ 0/4 (B/C/D/E continuations need RustyVault::core wiring + GCP HTTP) |
| Test phases | ✅ 7 phase docs written; 0/7 phases executed |
| Formal specs | ✅ TLA+/Agda/Allium written; 0/3 model-checked |
| Documentation | ✅ doc pack 100% complete (14 PNG diagrams, journal, RCA, TPS, matrix, test plan, slice plans, analysis HTML, slide deck) |
| Governance | ✅ 25 STAMP + 12 RETE-UL + 15 AOR + 4 Oban schedules + pre-commit ARMED + CLAUDE.md registered + vault-validator agent + /vault-evolve skill |
| Discoverability | ✅ 5 MCP tools + 11 Zenoh topic prefixes + 5 glob patterns + MoZ dispatcher (Pass-10) |
| Triple-interface | ✅ Lustre + Wisp + TUI all shipped (Pass-6) |
| Cumulative LOC shipped | ~3,000 (Pass-1: 0+vendor; Pass-2: 756; Pass-3: 800; Pass-4: 470; Pass-6: 420; Pass-8: 270; Pass-10: 200; passes 5/7/9: docs only) |
| Cumulative LOC pending (per plans) | ~5,094 (5 slice continuations) |
| Tests passing | 9386 (+39 from baseline 9347) |
| sa-plan tasks | 50 created across 10 passes; 30+ closed (60%); 20 tracked |
| Total task closure | **~50%** (governance/specs/skeleton/MoZ surface/discoverability/agent/skill complete; bodies pending) |

## Pass-by-pass progress

| Pass | Headline | Source LOC | Tests | Closure focus |
|---:|---|---:|---:|---|
| 1 | Slice A vendor + scrub + 12 diagrams + governance | 0 / 67 MB | 9347 baseline | Plan/governance |
| 2 | Slice B partial — NIF skeleton + cargo audit gate | 756 | 9358 (+11) | Skeleton |
| 3 | 12 RETE-UL rules + TLA+/Agda/Allium specs + pre-commit ARMED + 4 Oban | 800 | 9363 (+5) | Specs/rules |
| 4 | Slice D + E skeletons — sync_actor + secret_api + 4 cron scripts | 470 | 9370 (+7) | Skeleton |
| 5 | 5 detailed slice continuation plans | 0 / 1,488 plan | 9370 | Plan |
| 6 | secret_policy schema + Lustre tile + TUI view + Wisp routing | 420 | 9376 (+6) | Schema/UI |
| 7 | CLAUDE.md SC-VAULT registered + 8-layer defense table | 100 docs | 9376 | Governance |
| 8 | 5 MCP tools + 11 Zenoh topic prefixes + 5 glob patterns | 270 | 9381 (+5) | Discoverability |
| 9 | vault-validator agent + /vault-evolve skill + 2 sequence diagrams | 210 + DOT/PNG | 9381 | Skills/agents |
| 10 | MoZ vault dispatcher (5-tool surface) + slice plans index refresh | 200 | 9386 (+5) | Federation surface |

## Defense-in-depth ledger now 10 layers (full table in `journal.md` §16)

L0 build / L1 pre-commit / L2 schema / L3 wiring guard / L4 RETE-UL / L5 cron / L6 formal / L7 triple-iface / L8 discoverable / L9 validator agent
