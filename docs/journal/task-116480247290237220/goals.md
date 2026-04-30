# Marionette MCP — Goals & Success Criteria

> Task `116480247290237220` · Pattern follows GDE goals doc [zk-3f996f8bc20835ce] and SDLC/SRE lifecycle [zk-3e3c45be5cbff3ba].

## North-star

**Make AI-driven Flutter UI authoring a first-class, formally-governed, fractally-integrated channel — at parity with Patrol regression but optimised for live exploration.**

## Goals

| ID | Goal | Success criterion | Owner | Status |
|---|---|---|---|---|
| **G1** | **Tool-surface completeness** | All 16 upstream Marionette MCP tools reachable from Claude/Pi/Gemini | code-evolution | ✅ achieved (was 8 → now 16) |
| **G2** | **Anti-pattern mechanical block** | Selector-guess (tap before discovery) impossible without an explicit warning | safety-validator | ✅ flag-file PostToolUse hook |
| **G3** | **Formal spec** | Allium spec covers entities, transitions, contracts, invariants, math, ruliology | constitutional-verifier | ✅ `specs/allium/marionette_mcp.allium` (379 LOC) |
| **G4** | **Fractal L0–L7 integration** | Every layer carries an artefact; vertical traceability from violation to FMEA | fractal-architect | ✅ rule §9 + journal §7 |
| **G5** | **Math-gated quality** | H ≥ 2.5 bits, CCM ≥ 0.90, FMEA top RPN ≤ 200 (post-mitigation) | observability-analyzer | 🟡 H=2.62 ✓, CCM=1.00 ✓, RPN=216 (1 row, mitigated) |
| **G6** | **RETE-UL closed-loop** | 10 GRL rules subscribed to `indrajaal/l5/test/marionette/**`, advisories surface in agent | code-evolution | 🟥 rules documented; Rust dispatcher pending (A7) |
| **G7** | **Multi-platform parity** | Starred tests run on Android + Linux + Chrome | patrol-test-agent | 🟡 catalog tagged; CI runner pending (A4) |
| **G8** | **Evidence sufficiency on failure** | Every failed test carries screenshot + logs + native_tree before disconnect | safety-validator | ✅ Allium invariant + force-capture branch |
| **G9** | **Federation across Flutter sub-projects** | Rule + agent + skill reusable for any Flutter app under `sub-projects/` | hyperscaler-analyzer | ✅ governance generic; needs ≥ 1 second-app proof point |
| **G10** | **Operator UX < 5 min from intent to evidence** | `/marionette-explore <app> <flow>` returns annotated catalog row + run_id under `docs/cache/marionette/` | prajna-operator | 🟡 path defined; first run pending (A1+A6) |
| **G11** | **Zenoh ↔ MoZ parity** | Every tool callable via stdio MCP **and** via `indrajaal/mcp/req/...` | zenoh-mesh-analyzer | ✅ SC-ZMOF-001 inherited |
| **G12** | **CI nightly regression** | Full P9 suite green every night with KPI rollup | build-supervisor | 🟥 pending (A4 + A8) |

Legend: ✅ achieved · 🟡 partially achieved · 🟥 not yet started

## Anti-goals (explicitly out of scope)

- Replacing Patrol — Patrol remains the regression channel; Marionette is exploratory + authoring.
- Auto-merging selector drift fixes — drift is flagged, never auto-applied.
- Marionette in production builds — `kDebugMode` guard is non-negotiable.
- Bypassing UX assertions via `call_custom_extension` — agent rule prohibits.

## Definition of Done (per pass-2 §16 + journal §16)

Marionette MCP integration is *complete* when:
1. All A-gaps closed (A1–A8).
2. P0–P9 of the test plan green for FluffyChat.
3. ≥ 1 second Flutter sub-project adopts the rule unchanged (proves L7).
4. Lustre dashboard tile shows live Marionette telemetry (B1).
5. `MarionetteSelectorDrift` advisory has fired ≥ 1× and the system auto-recovered.
6. KPI graph with 30-day history exists.

Until all 6 hold → mark **operational**, not **complete**.
