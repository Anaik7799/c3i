# Agentic UI Complete Wave Specification (Wave 1 → Wave 6)

**Timestamp**: 20260403-0430 CEST  
**Program**: Sprint 52+ Agentic Dashboard Evolution  
**Scope**: Phoenix LiveView + Prajna cockpit + Rust ignition TUI + CEPAF bridge  
**Inputs**:
- `docs/plans/20260403-0330-agentic-ui-200-ideas.md`
- `docs/plans/20260403-0300-golden-triangle-100-ideas-elixir-dashboard.md`
- AG-UI protocol (`docs.ag-ui.com/introduction`)
- Google Generative UI paper/research
- Golden Triangle (DevUI + AG-UI + OTel)

---

## 1) Objective

Deliver a **6-wave implementation roadmap** for all 200 Agentic UI ideas, prioritized by:

1. **Criticality** (SIL-6 safety + operational risk)
2. **Usability** (operator efficiency)
3. **Information Utility** (actionable signal quality)
4. **UX/CX** (clarity, confidence, trust)

Primary execution policy: **criticality-first with FMEA gating**.

---

## 2) Ranking Model (Execution Order Driver)

From the 200-ideas plan:

`Score = Criticality×3 + Usability×2 + InformationUtility×2 + UX/CX×1` (max 40)

### Priority Bands

| Band | Score | Execution Priority | Intent |
|---|---:|---|---|
| P0 | 36–40 | Wave 1 | Safety-critical + core operator control |
| P1 | 32–35 | Wave 2–3 | High-value control-plane observability + AG-UI interaction |
| P2 | 28–31 | Wave 4 | Strong operational leverage |
| P3 | 24–27 | Wave 5 | UX/CX + workflow acceleration |
| P4 | 15–23 | Wave 6 | Polish, delight, non-critical expansion |

---

## 2.1) Fractal Coverage Mandate (8 Elements × 8 Layers)

This plan is now explicitly constrained to cover **all fractal elements** and **all fractal layers**.

### Canonical Fractal Elements (E1–E8)
1. **Alarms**
2. **Guardian**
3. **Sentinel**
4. **Devices**
5. **Compliance**
6. **Analytics**
7. **KMS**
8. **Config**

### Canonical Fractal Layers (L0–L7)
- **L0** Runtime / Constitutional
- **L1** Atomic / Debug
- **L2** Component
- **L3** Transaction
- **L4** System
- **L5** Cognitive
- **L6** Ecosystem
- **L7** Federation

### Coverage Invariant

For every cell in the 8x8 matrix, execution must produce:
1) a design artifact,
2) an implementation artifact, and
3) a verification artifact.

`CoverageComplete ⇔ ∀e∈E, ∀l∈L: Design(e,l) ∧ Implemented(e,l) ∧ Verified(e,l)`

### 8x8 Matrix — First Implementation Wave per Cell

| Element \ Layer | L0 | L1 | L2 | L3 | L4 | L5 | L6 | L7 |
|---|---|---|---|---|---|---|---|---|
| **Alarms** | W1 | W1 | W2 | W2 | W3 | W4 | W5 | W6 |
| **Guardian** | W1 | W1 | W1 | W2 | W2 | W3 | W4 | W5 |
| **Sentinel** | W1 | W1 | W2 | W2 | W3 | W3 | W4 | W5 |
| **Devices** | W1 | W1 | W2 | W2 | W3 | W4 | W5 | W6 |
| **Compliance** | W1 | W1 | W2 | W2 | W3 | W4 | W5 | W6 |
| **Analytics** | W1 | W2 | W2 | W3 | W3 | W4 | W5 | W6 |
| **KMS** | W1 | W1 | W2 | W3 | W3 | W4 | W5 | W6 |
| **Config** | W1 | W1 | W1 | W2 | W2 | W3 | W4 | W5 |

Legend: `Wn` = first wave where that element×layer cell is implemented and verified.

### Layer Completion Gates by Wave

| Wave | Mandatory Fractal Completion Gate |
|---|---|
| **Wave 1** | All elements covered at **L0-L1**; Guardian/Sentinel/Config baseline established |
| **Wave 2** | All elements covered at **L2-L3** |
| **Wave 3** | All elements covered at **L4**; high-risk GenUI cells validated |
| **Wave 4** | All elements covered at **L5**; predictive controls bounded |
| **Wave 5** | All elements covered at **L6** |
| **Wave 6** | All elements covered at **L7**; **64/64 matrix closure** |

---

## 3) Six-Wave Plan Summary

| Wave | Priority | Focus | Ideas (Primary IDs) | Target Duration | Exit Gate |
|---|---|---|---|---|---|
| **Wave 1** | P0 | AG-UI safety foundation + shared state | 1,2,3,4,5,10,14,20,27,41,54,61 | 2 weeks | Safety gate + HITL verified |
| **Wave 2** | P1 | DevUI X-ray + OTel core | 21,22,23,24,25,26,44,45,46,50,56,68 | 2 weeks | Observability gate + zero blind spots |
| **Wave 3** | P1 | Generative operations & runbooks | 62,63,66,69,70,73,76,78,80,98 | 3 weeks | Human-reviewable GenUI + bounded scope |
| **Wave 4** | P2 | Intelligent orchestration & predictive panels | 42,43,47,52,57,84,99,100,108,109,141,144 | 2 weeks | Predictive quality + low false-positive |
| **Wave 5** | P3 | UX/CX acceleration + collaboration | 81,82,83,86,88,89,90,91,92,93,94,95 | 2 weeks | Operator productivity uplift |
| **Wave 6** | P4 | Full catalog completion + GA hardening | Remaining 101–200 not implemented in Waves 1–5 | 2 weeks | GA gate (compile/test/format/credo/sobelow) |

---

## 3.1) 200-Idea Coverage Contract (Complete)

This plan explicitly covers **all 200 ideas** from `20260403-0330-agentic-ui-200-ideas.md`.

### Canonical Set

- `Ideas = {1..200}`
- Every idea must map to exactly one wave (`W1..W6`) and at least one fractal cell (`Element, Layer`).

### Baseline Wave Allocation (All 200)

| Wave | Idea ID Span | Count | Priority Bias |
|---|---|---:|---|
| **W1** | 1–34 | 34 | P0-heavy |
| **W2** | 35–68 | 34 | P1-heavy |
| **W3** | 69–100 | 32 | P1/P2 bridge |
| **W4** | 101–134 | 34 | P2-heavy |
| **W5** | 135–168 | 34 | P3-heavy |
| **W6** | 169–200 | 32 | P4 + completion |
|  | **Total** | **200** |  |

### FMEA Override Rule (Criticality-first)

If any idea in a later wave has elevated risk (`RPN >= 150`), it is pulled forward to the earliest feasible wave with safety capacity.  
Reallocation must preserve:

1. No idea dropped from `{1..200}`
2. No duplicate wave assignment
3. Fractal 8x8 closure target unchanged (64/64)

### Coverage Validation Checks

- **Cardinality check**: `|AssignedIdeas| = 200`
- **Uniqueness check**: each idea appears in exactly one wave
- **Fractal check**: each idea linked to `Element × Layer` matrix cell(s)
- **Completion check**: Wave 6 cannot close with unassigned ideas

---

## 4) Detailed Wave Specifications

## Wave 1 — P0 Safety + AG-UI Core

### Goals
- Remove black-box operation for critical actions.
- Enforce human-in-the-loop on destructive flows.
- Establish shared state/event backbone for all dashboards.

### Deliverables
- Streaming ignition progress (Idea 1)
- Human-in-loop restart approvals (Idea 2)
- Two-key emergency action (Ideas 3 + 54)
- Shared mesh health/state vector (Ideas 4 + 14)
- Thinking steps for preflight/guardian flow (Idea 5)
- STAMP violation custom events (Idea 10)
- Boot checkpoint timeline streaming (Idea 20)
- NL query entrypoint (Idea 41, minimal read-only)
- Generative incident report MVP (Idea 61, gated)

### FMEA (Wave 1)
| Failure Mode | S | O | D | RPN | Mitigation |
|---|---:|---:|---:|---:|---|
| HITL bypass on destructive action | 10 | 3 | 3 | 90 | Mandatory arm→confirm gate; audit log |
| Shared state desync across sessions | 8 | 4 | 4 | 128 | PubSub consensus + replay on reconnect |
| Alert flood from custom events | 7 | 5 | 4 | 140 | Backpressure + aggregation + dedupe |

### Exit Criteria
- SC-SAFETY-001 two-step commit validated in UI tests.
- Critical actions blocked without operator confirmation.
- Shared state consistency verified across multiple sessions.

---

## Wave 2 — P1 DevUI + OTel Core

### Goals
- Provide agent execution “X-ray” for operators.
- Add latency/cost transparency for mesh decisions.

### Deliverables
- BEAM scheduler heatmap (21)
- Request waterfall (22)
- Container resource gauges (23)
- NIF crash detector panel (24)
- Distributed trace viewer (25)
- Boot Gantt chart + critical path (26 + 68)
- OODA flame graph (44)
- Live supervision tree + state inspector base (45 + 56)
- Guardian approval queue panel (46)
- Watchdog heartbeat matrix (50)

### FMEA (Wave 2)
| Failure Mode | S | O | D | RPN | Mitigation |
|---|---:|---:|---:|---:|---|
| Misleading traces (clock skew, missing spans) | 8 | 4 | 5 | 160 | Trace completeness checks + timestamp sync policy |
| Observability UI overload | 6 | 6 | 4 | 144 | Progressive disclosure + role-based views |
| False NIF crash alarms | 8 | 3 | 5 | 120 | Signature-based classification + cooldown window |

### Exit Criteria
- No “opaque” preflight/verify paths.
- End-to-end trace from Phoenix → bridge/cortex visible.
- OODA + boot timing dashboards stable for 24h.

---

## Wave 3 — P1 Generative Operations

### Goals
- Turn operator intent into guided UI/action components.
- Keep generated UI constrained, auditable, and reversible.

### Deliverables
- Generative runbook execution cards (62)
- Prompt-to-dashboard panel generation (63)
- Generative alert cards (66)
- Generative FMEA assistant (69)
- Generative postmortem/journal assistant (70)
- Compliance report generator (73)
- Error explanation cards (76)
- Data viz from natural language (78)
- Rollback plan generator (80)
- Natural language query (98) v2 with explainable source links

### FMEA (Wave 3)
| Failure Mode | S | O | D | RPN | Mitigation |
|---|---:|---:|---:|---:|---|
| Unsafe/generated UI action proposal | 9 | 4 | 4 | 144 | Strict allow-list component schema + Guardian checks |
| Hallucinated remediation guidance | 8 | 5 | 6 | 240 | Source citation requirement + mandatory human approval |
| Prompt-injected dashboard mutation | 9 | 3 | 4 | 108 | Policy sanitizer + scoped execution tokens |

### Exit Criteria
- All generated action widgets are schema validated.
- No autonomous destructive action from generated output.
- Human approval for all mutating runbooks.

---

## Wave 4 — P2 Intelligent Orchestration

### Goals
- Shift from reactive monitoring to predictive control.
- Introduce recommendation systems with low operational noise.

### Deliverables
- Predictive failure panel (42)
- AI architecture advisor (43)
- Sentinel radar + drift graphs (47 + 52)
- Restart storm/queue anomaly detectors (57)
- Notification center + incident timeline foundations (84, 99)
- Chaos gate + rolling update orchestrator (108, 109)
- Compliance/FMEA live boards (141, 144)
- Predictive failure timeline + confidence (99)
- Architecture advisory go/no-go board (100)

### FMEA (Wave 4)
| Failure Mode | S | O | D | RPN | Mitigation |
|---|---:|---:|---:|---:|---|
| Prediction drift causes bad ops decisions | 8 | 5 | 5 | 200 | Retraining thresholds + confidence floor + override |
| Alert fatigue from low-quality predictions | 7 | 6 | 4 | 168 | Precision targeting + suppression windows |
| Advisor overreach into constitutional scope | 9 | 2 | 5 | 90 | Constitutional guardrails + read-only mode by default |

### Exit Criteria
- Prediction precision/recall meet agreed SRE threshold.
- Advisor outputs always include risk + confidence + alternatives.
- Chaos/rolling update gates require explicit approval.

---

## Wave 5 — P3 UX/CX Acceleration

### Goals
- Improve speed-to-decision for operators.
- Improve discoverability/accessibility without increasing risk.

### Deliverables
- Theme/profile switcher (81)
- Keyboard overlays and quick nav (82)
- Persistent layout memory (83)
- Search-everything command palette (86)
- Split-screen and annotations (88, 89)
- Time-travel dashboard state (90)
- Mobile/tablet responsive cockpit (91)
- Accessibility compliance baseline (92)
- Favorites/pins and status page (93, 94)

### FMEA (Wave 5)
| Failure Mode | S | O | D | RPN | Mitigation |
|---|---:|---:|---:|---:|---|
| UX complexity increases operator error | 6 | 5 | 5 | 150 | Role presets + simplified default mode |
| Time-travel misread as live state | 7 | 4 | 4 | 112 | Strong “historical mode” visual framing |
| Accessibility regressions | 5 | 4 | 5 | 100 | Automated a11y checks + manual audits |

### Exit Criteria
- Measurable reduction in mean time-to-insight.
- Accessibility baseline and keyboard parity achieved.
- No increase in operational incident rate due to UI changes.

---

## Wave 6 — P4 Completion + GA Hardening

### Goals
- Close remaining 200-idea backlog items.
- Productionize with safety/quality/compliance gates.

### Deliverables
- Implement remaining ideas from Tier 2/3 backlog (IDs not yet shipped).
- Final harmonization between LiveView, Rust TUI, and CEPAF dashboards.
- Full test expansion: TDG, FMEA, property, BDD, wallaby, perf.
- Operations pack: runbooks, rollback matrix, incident templates.

### FMEA (Wave 6)
| Failure Mode | S | O | D | RPN | Mitigation |
|---|---:|---:|---:|---:|---|
| Regression explosion due to breadth | 8 | 6 | 4 | 192 | Wave freeze policy + strict feature flags |
| Coverage gaps at release | 9 | 3 | 5 | 135 | Mandatory release checklist with stop-the-line |
| Telemetry drift between surfaces | 7 | 4 | 5 | 140 | Unified event schema + contract tests |

### Exit Criteria
- Quality gate pass: compile/test/format/credo/sobelow.
- All release-critical pages have wallaby coverage updates.
- Release readiness review signed-off.

---

## 5) Cross-Wave Workstreams (Always-On)

1. **Safety & Constitutional Compliance**
   - Guardrails for all generated actions
   - Human approval for destructive operations

2. **Telemetry & Event Contracts**
   - AG-UI event schema stability
   - Trace propagation across Elixir/F#/Rust

3. **Testing Discipline (TDG)**
   - Test-first for every new dashboard capability
   - Regression suites for every FMEA high-RPN mode

4. **Documentation & Journaling**
   - Each wave closes with plan update + journal update
   - Institutional pattern extraction after each wave

---

## 6) Wave-Level Task Skeleton (for sa-plan registration)

| Task ID (proposed) | Wave | Description |
|---|---|---|
| W1-T001..W1-T010 | 1 | AG-UI safety foundation + streaming + shared state |
| W2-T001..W2-T010 | 2 | DevUI and OTel visibility core |
| W3-T001..W3-T010 | 3 | Generative operations and runbooks |
| W4-T001..W4-T010 | 4 | Predictive intelligence and orchestration |
| W5-T001..W5-T010 | 5 | UX/CX and productivity features |
| W6-T001..W6-T010 | 6 | Completion, hardening, and release gates |

> Note: register these in Planning CLI (`sa-plan`) when execution starts.

---

## 7) Success Metrics

| Metric | Baseline | Wave-6 Target |
|---|---:|---:|
| Critical actions with HITL | partial | 100% |
| End-to-end trace completeness | low/partial | >95% |
| Fractal matrix cell coverage (8×8) | unknown/partial | **64/64** |
| Elements with full L0–L7 closure | unknown/partial | **8/8** |
| Layers with full E1–E8 closure | unknown/partial | **8/8** |
| Mean time to diagnosis (MTTD) | current | -40% |
| Mean time to recovery (MTTR) | current | -30% |
| False-positive prediction rate | n/a | <10% |
| Operator satisfaction (UX/CX survey) | n/a | +30% |

---

## 8) Go/No-Go Governance

- **Go to next wave only if**:
  1. Wave exit criteria passed
  2. No unresolved P0 safety defects
  3. FMEA high-RPN mitigations implemented
  4. Regression suite green

- **Stop-the-line triggers**:
  - HITL bypass discovered
  - Constitutional invariant violation
  - Unbounded generated-action path
  - Telemetry/tracing contract break on critical flow

---

## 9) Immediate Next Action

Start **Wave 1 backlog decomposition** into implementation units (UI component + event contract + test set), register execution tasks in `sa-plan` with explicit acceptance criteria, and create a **64-cell matrix ledger** to track Design/Implementation/Verification evidence for each element×layer cell.
