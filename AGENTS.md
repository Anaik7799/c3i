# C3I Agent System — UI Development & Testing Agents (v21.6.0-GLM)

## Overview

C3I operates a 25-agent biomorphic swarm organized in 2 supervision layers. This document
covers agents relevant to Gleam UI development, testing, and coverage. For the full agent
inventory see `.claude/agents/`.

---

## Agent Architecture

```
Layer 1 — Executive (1 agent, Opus model)
  master-supervisor — supreme orchestrator, Guardian integration, Constitutional compliance

Layer 2 — Domain Supervisors (4 agents, Sonnet model)
  design-supervisor    — architecture planning, spawns fractal-architect
  build-supervisor     — code generation and testing, spawns code-evolution + test-generator
  deploy-supervisor    — SIL-6 compliance, verification
  operate-supervisor   — monitoring, Zenoh mesh, OODA telemetry

Layer 3 — Workers (20 agents, Haiku model)
  See sections below for UI-specialist and UI-supporting workers.
```

Agent counts: 1 executive + 4 supervisors + 20 workers = 25 total (SC-BIO-001).

---

## Planning & Orchestration (L3-L4)

### Autoritative Tools
The following root-level tools are the primary interfaces for system management:

| Tool | Purpose | Primary Agent |
|:---|:---|:---|
| `./sa-up` | Unified Mesh Bootstrap (Gleam Auth) | `deploy-supervisor` |
| `./sa-gleam` | High-Performance Gleam Planning & Mesh CLI | `code-evolution` |
| `./sa-plan` | Authoritative F# Planning & Chaya CLI | `master-supervisor` |

**Rule**: Use `./sa-gleam status` for high-speed task inspection and `./sa-plan sync` for Git persistence.

---

## UI-Specialist Agents (Primary)

### fractal-architect

| Field | Value |
|-------|-------|
| File | `.claude/agents/fractal-architect.md` |
| Model | opus |
| Tools | Read, Grep, Glob, Bash |

**Purpose.** Designs and validates the 7-layer fractal widget architecture (L0-L7) as defined
in `CLAUDE.md §7.0`. Verifies self-similarity across layers, constitutional invariant propagation
(Psi-0 through Psi-5), and health propagation (failures up, recovery down).

**Scope.**
- All fractal widget modules: `lib/cepaf_gleam/src/cepaf_gleam/fractal/l{0-7}_*.gleam`
- Layer-consistency checks: Jaccard self-similarity J(Li, Lj) >= 0.7
- Holon properties per layer: state, health monitoring, recovery, boundary, parent/child comms
- Constitutional coverage matrix (Psi-0..5 x L0..L7)

**Layer reference.**

| Layer | Module | Lines | HITL |
|-------|--------|-------|------|
| L0 | `l0_constitutional.gleam` | 176 | Mandatory |
| L1 | `l1_atomic_debug.gleam` | 118 | Optional |
| L2 | `l2_component.gleam` | 112 | No |
| L3 | `l3_transaction.gleam` | 144 | Optional |
| L4 | `l4_system.gleam` | 202 | Optional |
| L5 | `l5_cognitive.gleam` | 149 | Optional |
| L6 | `l6_ecosystem.gleam` | 105 | Optional |
| L7 | `l7_federation.gleam` | 101 | Optional |

**When to use.** New fractal layer features, cross-layer architectural decisions, constitutional
propagation audits, Jaccard consistency failures.

---

### gleam-coverage-engineer

| Field | Value |
|-------|-------|
| File | `.claude/agents/gleam-coverage-engineer.md` |
| Model | sonnet |
| Tools | Read, Write, Edit, Grep, Glob, Bash(gleam:*), Bash(git:*) |

**Purpose.** Writes and fixes Gleam gleeunit test files in `lib/cepaf_gleam/test/` to achieve
the 10-category gold standard (C1-C8 + AG-UI + A2UI) with mandatory math gate passage.

**Math gates (all must pass).**

| Metric | Formula | Threshold |
|--------|---------|-----------|
| H | -Sum(n_i/N * log2(n_i/N)) | >= 2.5 bits |
| CCM | Sum(w_i * cov_i) / Sum(w_i) | >= 0.90 |
| D_EA | |expected \ tested| / |expected| | <= 0.10 |
| ITQS | 0.25*H_norm + 0.35*CCM + 0.25*(1-D_EA) + 0.15*FSI | >= 0.85 |

**Test categories (Gleam).**

| Cat | Weight | What to Test |
|-----|--------|-------------|
| C1 | 1.0 | init() returns valid Model, correct Page variant |
| C2 | 1.5 | health_class() mapping, severity indicators |
| C3 | 1.0 | Model data fields populated after events |
| C4 | 1.2 | Tick stability, sequential events accumulate |
| C5 | 2.0 | Msg dispatch changes Model (NavigateTo, drag-drop) |
| C6 | 1.0 | Dark Cockpit CSS classes, mode affects display |
| C7 | 1.5 | Reasoning state, OODA phase tracking |
| C8 | 3.0 | DUAL: Model state change AND Effect emitted |
| AG-UI | 2.0 | RunStarted/Finished/Error, StepStarted, ToolCall, HITL |
| A2UI | 1.5 | Catalog validation, proposal acceptance/rejection |

**Source-first rule (AOR-COV-008).** Always read the `.gleam` source module before writing
tests. Extract Model fields, Msg variants, update() arms, view() structure, and Zenoh topics.

**Test command.**
```bash
cd /home/an/dev/ver/c3i/lib/cepaf_gleam
gleam build && gleam test
```

**Split-screen test cycle.**
```bash
./scripts/run-split-screen-tests.sh
```
10-minute cycle: 381 tests, 15 tabs × 8 fractal layers, 30+ sec monitoring per tab.

**When to use.** Writing new Gleam test files, fixing entropy/CCM gaps, adding AG-UI or A2UI
coverage, triple-interface (Lustre + Wisp + TUI) test coverage, Zenoh OTel span verification.

---

### wallaby-coverage-engineer

| Field | Value |
|-------|-------|
| File | `.claude/agents/wallaby-coverage-engineer.md` |
| Model | sonnet |
| Tools | Read, Write, Edit, Grep, Glob, Bash(mix:*), Bash(git:*) |

**Purpose.** Writes and fixes E2E browser tests (`test/**/*_wallaby_test.exs`) for Elixir
Phoenix LiveView pages and gleeunit tests for the Gleam Lustre MVU. Both use the same
8-category gold standard.

**Scope.** Lustre MVU, AG-UI 32-event protocol, A2UI catalog, fractal layer widgets (L0-L7),
PROMETHEUS verification DAG, Wisp REST endpoints, Zenoh OTel spans.

**C8 dual verification (SC-COV-016).** For every action button in a LiveView or Gleam page,
write two tests: one verifying the Model/state change, one verifying the Effect/flash/side-effect.

**Read source first.** For Wallaby tests: read the LiveView `.ex` source and HEEx template
before writing any selector. For Gleam: read the `.gleam` source before writing any test.

**E2E test command.**
```bash
WALLABY_ENABLED=true SKIP_ZENOH_NIF=0 NO_TIMEOUT=true PATIENT_MODE=enabled \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" HEALTH_PORT=4051 \
MIX_ENV=test mix test --only wallaby
```

**When to use.** Browser E2E tests for LiveView pages, cross-framework coverage (Elixir +
Gleam), FMEA-driven test writing, two-step commit verification (arm/confirm/cancel patterns).

---

### coverage-audit-agent

| Field | Value |
|-------|-------|
| File | `.claude/agents/coverage-audit-agent.md` |
| Model | sonnet |
| Tools | All tools |

**Purpose.** Mathematically audits all Wallaby and gleeunit test files. Computes Shannon
entropy H, CCM, D_EA, FSI, RPN_coverage, and ITQS per file. Generates ranked correction
recommendations.

**Audit phases.**
1. Census: glob all test files, extract feature counts per C1-C8 category marker
2. Math metrics: compute H, CCM, balance ratio, FSI suite-wide
3. Source correlation: read LiveView/Gleam source, compute D_EA (EXPECTED vs AS-IS)
4. FMEA coverage: verify tests exist for all failure modes with RPN >= 100
5. Recommendations: per-file report with ranked corrections

**Trigger conditions.** After any test file or source file modification, on demand via
`/coverage-audit`, and on a weekly schedule (SC-COV-021 compliance).

**Output location.** `docs/analysis/coverage-audit-{date}.md`

**When to use.** Coverage gap identification, entropy audits, alignment score reporting,
pre-sprint coverage gate verification, FMEA RPN-driven test prioritization.

---

## UI-Supporting Agents (Secondary)

### design-supervisor

Orchestrates design-phase agents. For UI work: spawns `fractal-architect` to determine
affected fractal layers (L0-L7) and `impact-analyzer` for risk assessment before any new
page or widget is added. Requires Guardian approval for constitutional changes (L0).

### build-supervisor

Orchestrates build-phase agents. For UI work: spawns `test-generator` first (TDG-compliant
tests before implementation), then `code-evolution` for the triple-interface feature, then
`code-debugger` on errors, then `code-reviewer` for quality review.

### code-evolution

Implements new UI features through OODA cycles with Guardian pre-validation and shadow
testing. Enforces triple-interface mandate: every feature = 1 Lustre page + 1 Wisp endpoint
+ 1 TUI view. Records activations to the Immutable Register.

### code-debugger

Performs 5-Why root cause analysis on UI compilation errors, gleeunit test failures, and
Wallaby E2E failures. Isolates the failing assertion, traces to source, generates a targeted
fix, and re-tests.

### code-reviewer

Reviews Gleam UI code against: triple-interface completeness (SC-GLM-UI-001), shared types
from `ui/domain.gleam` (no per-interface duplication), AG-UI 32-event correctness,
A2UI catalog allowlist, zero-warning compilation (SC-CMP-025), and OTel span publication
(SC-GLM-ZEN-001).

### test-generator

Generates TDG-compliant test stubs that fail before implementation. For Gleam: generates
gleeunit tests targeting all applicable C1-C8 + AG-UI + A2UI categories. Follows AOR-COV-008
(source-first) before generating any selector or assertion.

### prajna-operator

Operates the Prajna C3I cockpit. Relevant to UI work for verifying that Lustre pages render
correctly in the live cockpit environment, monitoring AG-UI event flow via Zenoh topics
(`indrajaal/agui/**`), and confirming dark-cockpit HMI compliance (SC-HMI-001).

### deploy-supervisor

Coordinates UI deployment with SIL-6 compliance. Spawns `sil6-validator` to confirm all
fractal layers pass verification gates and `robustness-analyzer` to assess UI resilience
before activation.

### master-supervisor

Supreme orchestrator (Opus model). Coordinates all 4 domain supervisors. For UI work:
manages full SDLC from fractal architecture design through E2E coverage audit. Requires
Guardian approval for L0 constitutional widget changes and production deployments.

---

## Agent Coordination for UI Work

```
User Request
  |
  +-- master-supervisor (Opus)
       |
       +-- design-supervisor (Sonnet)
       |     |
       |     +-- fractal-architect    : layer assignment, self-similarity check
       |     +-- impact-analyzer      : cascade risk for new page
       |
       +-- build-supervisor (Sonnet)
       |     |
       |     +-- test-generator       : failing gleeunit stubs first (TDG)
       |     +-- code-evolution       : triple-interface implementation
       |     +-- gleam-coverage-engineer : C1-C8 + AG-UI + A2UI tests
       |     +-- wallaby-coverage-engineer : E2E browser tests
       |     +-- code-debugger        : on compilation or test failure
       |     +-- code-reviewer        : quality and constraint review
       |
       +-- deploy-supervisor (Sonnet)
       |     +-- sil6-validator       : fractal layer verification gates
       |
       +-- coverage-audit-agent       : math gates (H, CCM, ITQS)
```

---

## UI Testing Workflow (New Page)

Follow these steps in order when adding a new UI page to the Penta-Stack:

**Step 1 — Layer assignment (fractal-architect).**
Determine which fractal layer (L0-L7) the new page belongs to. Verify constitutional
invariants are correctly propagated. Confirm the layer widget module exists.

**Step 2 — Implementation (code-evolution).**
Implement the triple-interface feature:
- `ui/lustre/{page}.gleam` — Lustre MVU page (server-rendered, no client JS)
- `ui/wisp/{page}_handler.gleam` — Wisp REST endpoint (typed JSON, no string concat)
- `ui/tui/{page}_view.gleam` — TUI ANSI renderer

All three share types from `ui/domain.gleam`. Verify with `gleam build` (zero warnings).
Publish OTel spans via `zenoh_otel` for all state changes (SC-GLM-ZEN-001).

**Step 3 — Unit tests (gleam-coverage-engineer).**
Read the `.gleam` source first. Write gleeunit tests covering all applicable categories
(C1-C8 + AG-UI + A2UI) with section markers. Target >= 15 tests for interactive pages.
Verify `gleam test` passes. Include Zenoh message verification via `zenoh_test_observer`.

**Step 4 — E2E tests (wallaby-coverage-engineer).**
For any LiveView integration or browser-level verification, write Wallaby tests with the
8-category structure and C8 dual verification for every action button.

**Step 5 — Regression suite (gleam-coverage-engineer).**
Add tests to `comprehensive_ui_regression_test.gleam` for the new tab. Ensure 100% tab
coverage is maintained. Each tab monitored for 30+ seconds (SC-GLM-TST-002).

**Step 6 — Math gate audit (coverage-audit-agent).**
Verify all gates pass:

| Gate | Threshold | Blocks? |
|------|-----------|---------|
| Shannon entropy H | >= 2.5 bits | Yes |
| CCM | >= 90% | Yes |
| ITQS | >= 0.85 | Yes |
| D_EA | <= 10% | Yes |
| Human Intent alignment | >= 0.70 | Yes (SC-HINT-006) |

If any gate fails, return to step 3 or 4 with the audit report as input.

---

## STAMP Constraints (UI Agent Scope)

| Family | Count | Enforced By |
|--------|-------|-------------|
| SC-GLM-UI | 10 | code-evolution, code-reviewer |
| SC-AGUI | 10 | gleam-coverage-engineer, wallaby-coverage-engineer |
| SC-A2UI | 8 | gleam-coverage-engineer, coverage-audit-agent |
| SC-UIGT | 10 | coverage-audit-agent |
| SC-HINT | 8 | all test engineers (never modify HUMAN-ONLY blocks) |
| SC-MATH-COV | 6 | coverage-audit-agent |
| SC-HMI | 80 | fractal-architect, wallaby-coverage-engineer (C6) |
| SC-VER | 79 | fractal-architect, sil6-validator |
| SC-GLM-ZEN | 3 | code-evolution, gleam-coverage-engineer |
| SC-GLM-TST | 2 | gleam-coverage-engineer, coverage-audit-agent |

---

## Key Source Paths

| Purpose | Path |
|---------|------|
| Shared domain types | `lib/cepaf_gleam/src/cepaf_gleam/ui/domain.gleam` |
| AG-UI 32 event types | `lib/cepaf_gleam/src/cepaf_gleam/agui/events.gleam` |
| Lustre pages (24 files) | `lib/cepaf_gleam/src/cepaf_gleam/ui/lustre/` |
| Wisp handlers (15 files) | `lib/cepaf_gleam/src/cepaf_gleam/ui/wisp/` |
| Enhanced Wisp Zenoh API | `lib/cepaf_gleam/src/cepaf_gleam/ui/wisp/zenoh_api.gleam` |
| TUI renderer (23 files) | `lib/cepaf_gleam/src/cepaf_gleam/ui/tui/` |
| Split-Screen TUI | `lib/cepaf_gleam/src/cepaf_gleam/ui/tui/split_screen.gleam` |
| Zenoh OTel Integration | `lib/cepaf_gleam/src/cepaf_gleam/ui/zenoh_otel.gleam` |
| A2UI catalog | `lib/cepaf_gleam/src/cepaf_gleam/a2ui/catalog.gleam` |
| Fractal widgets L0-L7 | `lib/cepaf_gleam/src/cepaf_gleam/fractal/` |
| Math coverage lib | `lib/cepaf_gleam/src/cepaf_gleam/testing/coverage_math.gleam` |
| Zenoh Test Observer | `lib/cepaf_gleam/src/cepaf_gleam/testing/zenoh_test_observer.gleam` |
| Test Dashboard Model | `lib/cepaf_gleam/src/cepaf_gleam/testing/test_dashboard.gleam` |
| Gleam test suite | `lib/cepaf_gleam/test/` |
| Comprehensive Regression | `lib/cepaf_gleam/test/comprehensive_ui_regression_test.gleam` |
| Test Runner Script | `scripts/run-split-screen-tests.sh` |
| Agent definitions | `.claude/agents/` |

---

## Related Documents

- `CLAUDE.md §3.0` — Triple-interface mandate (SC-GLM-UI-001)
- `CLAUDE.md §5.0` — AG-UI 32-event protocol
- `CLAUDE.md §6.0` — A2UI 16-component catalog
- `CLAUDE.md §7.0` — Fractal widget architecture (L0-L7)
- `CLAUDE.md §8.0` — 8-category gold standard and math gates
- `CLAUDE.md §2.5` — Zenoh OTel Integration
- `.claude/rules/gleam-web-ui-development.md` — Full SC-GLM-UI constraint text
- `.claude/rules/ui-graph-testing.md` — Graph-theory UI testing (22-page digraph, LTS)
- `.claude/rules/zenoh-telemetry-mandatory.md` — Zenoh OTel span publishing
- `.claude/rules/zenoh-test-messaging.md` — Zenoh test observer protocol
- `.claude/rules/biomorphic-mode.md` — 25-agent swarm, context budget, OODA loop
- `.claude/rules/human-intent-protection.md` — SC-HINT-001..008
- `docs/GLEAM_UI_DEVELOPMENT_PROMPT.md` — Definitive session bootstrap prompt

---

**Version**: 21.6.0-GLM
**Last Updated**: 2026-04-04
**Agent count**: 28 definitions in `.claude/agents/` (4 UI-specialist, 9 UI-supporting, 15 other)
**Test metrics**: 1,559 tests passed, 0 failures | H=2.67 bits | CCM=0.770 | ITQS=0.736 | 100% tab coverage
