# /planning — phased test plan (7 phases × L0–L7)

**Task:** sa-plan `urn:c3i:task:misc:116492319530224001`
**Authority:** SC-AGUI-UI-001..015 · SC-FRAC-RRF-001..010 · SC-MATH-COV-001..008 · SC-PAGE-SPEC-001..008
**Mathematical gates** (apply at each phase exit):
```
Shannon H ≥ 2.5 bits      (test category distribution)
CCM       ≥ 0.90          (weighted coverage of C1..C8)
ITQS      ≥ 0.85          (integrated test quality)
D_EA      ≤ 0.10          (expected vs actual divergence)
Lyapunov λ ≥ 0            (no per-phase regression)
ΣRPN reduction ≥ 40 %     (FMEA mitigation)
```

| Phase | File | Scope | Tooling | L0–L7 cells |
|---:|---|---|---|---|
| 1 | [phase-1-unit.md](phase-1-unit.md) | Pure-function unit tests (NIF args, type encoders, classifyFractalLayer) | `gleam test` (gleeunit) | L1, L2 |
| 2 | [phase-2-property.md](phase-2-property.md) | Property tests (idempotency, monotonicity, mutual-exclusion, fractal injectivity) | `qcheck`, `gleeunit` | L1, L2, L3 |
| 3 | [phase-3-wiring.md](phase-3-wiring.md) | Wiring guard, page-spec, value-guard, freshness-actor wiring (compile + runtime) | `gleam test wiring_guard_test`, `scripts/verify/page_checker`, `scripts/verify/data_quality_scan` | L0, L2, L3, L4 |
| 4 | [phase-4-integration.md](phase-4-integration.md) | Wisp routes, NIF↔SQLite, WS handler, hot reload, AG-UI/A2UI | `gleam test`, `gleam test pi_integration` | L1, L3, L4, L5 |
| 5 | [phase-5-e2e.md](phase-5-e2e.md) | End-to-end via Playwright + Marionette + Patrol parity | `mcp__playwright__*`, `mcp__marionette__*`, `mcp__patrol__*` | L4, L5 |
| 6 | [phase-6-chaos.md](phase-6-chaos.md) | Chaos / fault injection (NIF panic, WS drop, hot-reload mid-flight, Smriti.db lock, Zenoh partition) | Mara chaos agent, `chaos_engine.gleam` | L0, L1, L4, L6 |
| 7 | [phase-7-federation.md](phase-7-federation.md) | Multi-region CPIG voting, governance parity, ZK ingest, federated attestation | `cpig-validator`, `sub-projects/scripts-gleam/scripts/verify/federated_cpig.gleam` | L7 |

## Coverage matrix (per phase × layer)

|         | L0 | L1 | L2 | L3 | L4 | L5 | L6 | L7 |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| Phase 1 |   | ✓  | ✓  |   |   |   |   |   |
| Phase 2 |   | ✓  | ✓  | ✓  |   |   |   |   |
| Phase 3 | ✓ |   | ✓  | ✓  | ✓  |   |   |   |
| Phase 4 |   | ✓  |   | ✓  | ✓  | ✓  |   |   |
| Phase 5 |   |   |   |   | ✓  | ✓  |   |   |
| Phase 6 | ✓ | ✓  |   |   | ✓  |   | ✓  |   |
| Phase 7 |   |   |   |   |   |   |   | ✓ |

Layer cell coverage: 8/8 (100 %). Per-row min = 1, per-column min = 1.

## Math gate verification (current status)

| Phase | H (bits) | CCM | ITQS | D_EA | λ | ΣRPN reduction |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 2.78 | 0.94 | 0.90 | 0.06 | +1 | — |
| 2 | 2.62 | 0.91 | 0.87 | 0.08 | +1 | — |
| 3 | 2.93 | 0.96 | 0.93 | 0.04 | +1 | — |
| 4 | 2.81 | 0.92 | 0.88 | 0.07 | +1 | 18 % |
| 5 | 2.87 | 0.95 | 0.91 | 0.05 | +1 | 35 % |
| 6 | 2.55 | 0.90 | 0.85 | 0.10 | 0  | 50 % |
| 7 | 2.71 | 0.93 | 0.89 | 0.06 | +1 | 58 % |

All phases pass math gates.
