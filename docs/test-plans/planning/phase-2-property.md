# Phase 2 — Property tests (L1, L2, L3)

**Goal:** prove behavioural invariants across randomised inputs (qcheck / rapidcheck-style).

## Properties

1. **Idempotency of `setView`**:
   `∀ k ∈ {grid,kanban,timeline,analytics}: setView(k); setView(k) ≡ setView(k)`
2. **Mutual exclusion of view sections** (closes ZK[zk-741220214a931009]):
   After any sequence of `setView(...)` calls, exactly one of `*-section` has `display:block`.
3. **Fractal classifier total**:
   `∀ task t: classifyFractalLayer(t) ∈ {L0..L7}` (no `undefined`).
4. **Status counts non-negative monotone**:
   `∀ delta_t ≥ 0: plan_status_after.total ≥ 0 ∧ plan_status_before.total + delta ≈ plan_status_after.total`
5. **Search injectivity**:
   `∀ q,r ∈ Query: q == r ⟹ plan_search(q) == plan_search(r)`
6. **DAG-Q parity**:
   `∀ snapshot: WS.total ≈ HTTP.total ≈ SSE.total (within 1)`
7. **Freshness escalation monotonic**:
   `fresh ≤ stale ≤ degraded ≤ dead` (state machine never skips levels backwards).
8. **Tabulator filter idempotent**:
   `filter(filter(rows, p), p) ≡ filter(rows, p)`.
9. **Value-guard total**:
   `∀ Tasks row r: r.Status ∈ {pending,in_progress,blocked,completed} ∧ r.Priority ∈ {P0,P1,P2,P3}` (SC-VALUE-GUARD).
10. **Kanban column cap**:
    `∀ col: visible(col).count ≤ 20 ∧ "+N more" emitted iff col.tasks.count > 20`.

## Tooling

- Gleam: `qcheck` (1k iterations per property by default).
- JS-side: shimmed via `gleeunit_test "JS property…"` calling into a Node.js side-runner.

## Exit criteria

- 0 counter-examples in 10 000 iterations per property.
- ITQS ≥ 0.85.
