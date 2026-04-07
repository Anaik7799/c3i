# C3I Gleam-First System — UI Development & Testing Master Prompt

**Status**: AUTHORITATIVE / SIL-6 / GOLD-STANDARD
**Version**: 22.3.0-GLM
**Scope**: All future UI development, refactoring, and testing by AI Agents across the C3I Biomorphic Mesh.
**Date**: 2026-04-07

---

## 1. System Identity & Architecture

You are operating within the **C3I SIL-6 Biomorphic Mesh**, a high-assurance distributed control system running on the BEAM VM. The UI architecture is exclusively the **Gleam Penta-Stack**.

*   **Primary Language**: Gleam (type-safe, BEAM VM, hot reload)
*   **Primary Rule (SC-GLM-UI-001)**: The Web UI uses **Gleam Lustre 5.6+ MVU** for Server-Side Rendering (SSR). Minimal inline JS for progressive enhancement (auto-fetch, SSE, keyboard nav, column sort, row filter) — base SSR works without JS.
*   **Triple-Interface Mandate (SC-GLM-UI-001)**: Every UI capability must simultaneously exist as:
    1.  A server-rendered Gleam Lustre Web UI (`ui/lustre/*.gleam`) — port 4100
    2.  A strongly-typed Gleam Wisp REST API (`ui/wisp/*.gleam`) — port 4100
    3.  A Gleam ANSI Terminal UI (`ui/tui/*.gleam`) — CLI
    4.  *(Legacy)* Phoenix LiveView — port 4000
    5.  *(Fallback)* F# Prajna CLI — safety kernel
*   **Single Source of Truth**: All primary domain types (`Page`, `HealthStatus`, `Action`, `OtelSpan`, `FractalLayer`) must be imported exclusively from `ui/domain.gleam`. No per-interface type duplication (SC-GLM-UI-009).

---

## 2. The 31 TABs — Page Registry

Every page maps to a `Page` variant in `ui/domain.gleam`, a Lustre page, a Wisp API handler, and a TUI view. ComponentDemo page shows all 233 A2UI components.

| # | Page | Path | Fractal Layer | Lustre | Wisp | TUI | Key Components |
|:-:|------|------|:-------------:|:------:|:----:|:---:|----------------|
| 1 | Dashboard | `/dashboard` | L5 Cognitive | `app.gleam` | `health_api.gleam` | `health_view.gleam` | Health status, telemetry feed, dark cockpit |
| 2 | Planning | `/planning` | L3 Transaction | `planning.gleam`, `planning_view.gleam`, `planning_dashboard.gleam` | `planning_api.gleam`, `planning_routes.gleam` | `planning_view.gleam`, `planning_dashboard_view.gleam` | Task lifecycle, SQLite-backed planning, Gantt |
| 3 | Immune | `/immune` | L0 Constitutional | `immune.gleam` | `immune_api.gleam` | `immune_view.gleam` | Guardian approval, emergency stop, Psi invariants |
| 4 | Knowledge (Smriti) | `/knowledge` | L5 Cognitive | `knowledge.gleam`, `smriti.gleam` | `knowledge_api.gleam` | `knowledge_view.gleam`, `smriti_view.gleam` | Knowledge graph, RAG, semantic memory |
| 5 | Zenoh Mesh | `/zenoh` | L6 Ecosystem | `zenoh_mesh.gleam` | `zenoh_api.gleam` | `zenoh_view.gleam` | Topic tree, quorum (2oo3), message inspection |
| 6 | Cockpit | `/cockpit` | L5 Cognitive | `cockpit_view.gleam` | `cockpit_api.gleam` | `cockpit_view.gleam` | Prajna cockpit, operator controls |
| 7 | Verification | `/verification` | L0 Constitutional | `verification.gleam` | `verification_api.gleam` | `verification_view.gleam` | SIL-6 gates, PROMETHEUS DAG, constraint audit |
| 8 | Substrate | `/substrate` | L3 Transaction | `substrate.gleam` | `substrate_api.gleam` | `substrate_view.gleam` | Container state, build oracle, deployment |
| 9 | Metabolic | `/metabolic` | L1 Atomic Debug | `metabolic.gleam` | `metabolic_api.gleam` | `metabolic_view.gleam` | CPU ticks, sensor data, resource utilization |
| 10 | Podman | `/podman` | L4 System | `podman.gleam` | `podman_api.gleam` | `podman_view.gleam` | Container lifecycle, health probes, stats |
| 11 | MCP Server | `/mcp` | L6 Ecosystem | `mcp.gleam` | `mcp_api.gleam` | `mcp_view.gleam` | Model context protocol, tool registry |
| 12 | KMS Catalog | `/kms` | L0 Constitutional | `kms.gleam` | `kms_api.gleam` | `kms_view.gleam` | A2UI component catalog, security validation |
| 13 | Telemetry | `/telemetry` | L1 Atomic Debug | `telemetry.gleam` | `telemetry_api.gleam` | `telemetry_view.gleam` | OTel spans, sparklines, time-series |
| 14 | Federation (L7) | `/federation` | L7 Federation | `federation.gleam` | `federation_api.gleam` | `federation_view.gleam` | Peer discovery, version vectors, attestation |
| 15 | Health Grid | `/health-grid` | L4 System | `health_grid.gleam` | `health_api.gleam` | `health_view.gleam` | Device status grid, online/offline/maintenance |

**Additional Lustre pages** (not in Page enum, supporting modules): `agents.gleam`, `bridge.gleam`, `config.gleam`, `database.gleam`, `effects.gleam`, `holon.gleam`, `git.gleam`, `prajna.gleam`.

---

## 3. AG-UI Protocol (32 Events)

Agents communicate via the 32-event AG-UI protocol (`agui/events.gleam` + 4 supporting modules, 1,224 lines total):

| Category | Count | Events |
|----------|-------|--------|
| Lifecycle | 5 | RunStarted, RunFinished, RunError, StepStarted, StepFinished |
| Text | 4 | TextMessageStart, TextMessageContent, TextMessageEnd, TextMessageChunk |
| Tool | 5 | ToolCallStart, ToolCallArgs, ToolCallEnd, ToolCallResult, ToolCallChunk |
| State | 3 | StateSnapshot, StateDelta (RFC 6902), MessagesSnapshot |
| Activity | 2 | ActivitySnapshot, ActivityDelta |
| Reasoning | 7 | ReasoningStart, ReasoningMessageStart/Content/End/Chunk, ReasoningEnd, ReasoningEncryptedValue |
| Special | 4 | Raw, Custom, MetaEvent, Heartbeat |
| **TOTAL** | **32** | — |

**Modules**: `events.gleam` (582), `state.gleam` (268), `tools.gleam` (231), `sse.gleam` (84), `zenoh_bus.gleam` (59)
**Transport**: WebSocket (Lustre) + JSON (Wisp) + Zenoh PubSub + OTel spans (zenoh_otel)

---

## 4. A2UI Declarative Catalog (16 Components)

Agents propose UI mutations via a strict 16-component JSON catalog (`a2ui/*.gleam`, 655 lines):

**Components**: badge, button, data_table, progress, sparkline, alert, modal, ooda_ring, reasoning, topology, form_input, select, textarea, checkbox, radio, slider

**Modules**: `schema.gleam` (118), `catalog.gleam` (230), `renderer.gleam` (100), `bindings.gleam` (88), `validator.gleam` (119)

**Pattern**: Agent → A2UI JSON spec → Validator (allowlist) → Renderer → Lustre HTML
**Security**: Agents prohibited from sending executable DOM components (SC-SAFETY-001)

---

## 5. Zenoh OTel Integration (SC-GLM-ZEN)

All 15 UI pages MUST publish OpenTelemetry spans for every state change:

| Constraint | Requirement |
|------------|-------------|
| SC-GLM-ZEN-001 | All UI state changes MUST publish OTel spans via `zenoh_otel` |
| SC-GLM-ZEN-002 | Test runner MUST observe Zenoh messages for verification |
| SC-GLM-ZEN-003 | Split-screen TUI MUST display dashboard + test results simultaneously |

**Topics**: `indrajaal/otel/spans/{page}/{operation}`, `indrajaal/test/zenoh/observe/**`
**Modules**: `ui/zenoh_otel.gleam` (span builder + publisher), `testing/zenoh_test_observer.gleam` (test verification)

---

## 6. 8-Category Gold Standard Testing (C1-C8)

All Gleam UI code MUST achieve 8-category coverage:

| Category | Weight | Gate | What to Test |
|----------|--------|------|-------------|
| C1 Page Structure | 1.0 | Renders without error | Lustre element count >= 5 |
| C2 Status Badges | 1.5 | All states visible | Healthy/Degraded/Critical all shown |
| C3 Data Grids | 1.0 | Rows render | >= 3 rows x >= 3 columns |
| C4 Timeline | 0.8 | Events in order | Timestamp validation |
| C5 Interactive | 1.2 | Buttons work | Click -> state change |
| C6 Media/Rich | 0.8 | Assets load | SVG/PNG verified |
| C7 AI Advisory | 1.5 | AG-UI events flow | E2E Zenoh publish verified |
| C8 Action Button | 3.0 | Safety gates pass | Guardian approval + 2oo3 consensus |

**Additional categories**: AG-UI (32-event protocol, weight 2.0), A2UI (catalog validation, weight 1.5)

**Source-First Rule (AOR-COV-008)**: Always read the `.gleam` source module before writing tests. Extract Model fields, Msg variants, `update()` arms, `view()` structure, and Zenoh topics.

---

## 7. Mathematical Gates (ALL Must Pass)

| Metric | Formula | Threshold | Status |
|--------|---------|-----------|--------|
| Shannon Entropy H | -Sum(n_i/N * log2(n_i/N)) | >= 2.5 bits | 2.67 PASS |
| Cyclomatic Coverage CCM | Sum(w_i * cov_i) / Sum(w_i) | >= 0.90 | 0.770 IMPROVING |
| Expected vs Actual D_EA | \|expected \ tested\| / \|expected\| | <= 0.10 | — |
| Integrated Test Quality ITQS | 0.25*H_norm + 0.35*CCM + 0.25*(1-D_EA) + 0.15*FSI | >= 0.85 | 0.736 IMPROVING |

**Failure = Jidoka halt**. Do not proceed with feature work until math gates pass.

---

## 8. Fractal Widget Architecture (L0-L7)

| Layer | Module | Lines | Purpose | HITL |
|-------|--------|-------|---------|------|
| L0 | `l0_constitutional.gleam` | 176 | Guardian approval, emergency stop, Psi-0..5 | Mandatory |
| L1 | `l1_atomic_debug.gleam` | 118 | Debug trace viewer, event monitor | Optional |
| L2 | `l2_component.gleam` | 112 | Reusable forms, data grids, badges | No |
| L3 | `l3_transaction.gleam` | 144 | State diff viewer, tool call panel | Optional |
| L4 | `l4_system.gleam` | 202 | Agent run monitor, step tracker | Optional |
| L5 | `l5_cognitive.gleam` | 149 | Reasoning display, OODA ring | Optional |
| L6 | `l6_ecosystem.gleam` | 105 | Agent mesh topology, A2A messaging | Optional |
| L7 | `l7_federation.gleam` | 101 | Gateway, version vectors, SIL-6 sync | Optional |

**Total**: 8 modules, 1,107 lines. Each exports types, initial state functions, state transition functions, serialization, and status helpers.

---

## 9. Split-Screen Testing Workflow

```bash
./scripts/run-split-screen-tests.sh
```

**10-minute cycle**: 15 tabs x 8 fractal layers x 381 comprehensive regression tests.
- Top half: Split-screen TUI dashboard with sparklines and health bars
- Bottom half: Real-time test results with pass/fail indicators
- Each tab monitored for 30+ seconds (SC-GLM-TST-002)
- Zenoh message verification via `zenoh_test_observer`
- OTel span validation via `zenoh_otel`

---

## 10. Build & Test Commands

### Gleam Build (zero warnings required)
```bash
cd lib/cepaf_gleam
gleam build && gleam format --check
```

### Gleam Test
```bash
cd lib/cepaf_gleam
gleam test
```

### Full Compile (Penta-Stack)
```bash
NO_TIMEOUT=true PATIENT_MODE=enabled SKIP_ZENOH_NIF=0 WALLABY_ENABLED=true \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 \
mix compile --jobs 16
```

### Wallaby E2E
```bash
WALLABY_ENABLED=true SKIP_ZENOH_NIF=0 NO_TIMEOUT=true PATIENT_MODE=enabled \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" HEALTH_PORT=4051 \
MIX_ENV=test mix test --only wallaby
```

### Format Check (pre-commit)
```bash
cd lib/cepaf_gleam && gleam format
```

---

## 11. STAMP Constraints Summary (Gleam UI Scope)

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
| SC-FRACTAL | 8 | fractal-architect |
| SC-PROM | 7 | verification modules |

**Full registry**: `.claude/rules/constraint-registry.md`

---

## 12. Jidoka / Halt Conditions

Immediately halt and perform Fractal RCA if any of the following occur:

1. **`gleam build` produces warnings or errors** (SC-GLM-CMP-001)
2. **`gleam format --check` fails** (SC-GLM-CMP-002)
3. **Any math gate fails**: H < 2.5, CCM < 0.90, ITQS < 0.85, D_EA > 0.10
4. **Test regression**: previously passing test now fails
5. **Constitutional violation**: L0 invariant (Psi-0..5) breached
6. **Triple-interface gap**: feature implemented in < 3 interfaces
7. **Zenoh OTel missing**: state change without span publication (SC-GLM-ZEN-001)
8. **A2UI catalog violation**: unregistered component in render pipeline
9. **Fractal layer breach**: cross-layer data access without proper routing
10. **Source-first violation**: test written without reading source module first (AOR-COV-008)

---

## 13. Execution Mandate for AI Agents

1. **Acknowledge and Contextualize**: State the Fractal Layer (L0-L7) you are modifying.
2. **Read Source First (AOR-COV-008)**: Read the `.gleam` source before writing any test or implementation.
3. **Build and Check**: Run `gleam check` and `gleam format` before proposing changes. Zero warnings required.
4. **Triple-Interface Verification**: Confirm Lustre + Wisp + TUI all exist and share `domain.gleam` types.
5. **Verify via OODA**: After modifying code, confirm Zenoh OTel spans are published.
6. **Math Gate Audit**: Run coverage audit — all four gates must pass.
7. **Halt on Jidoka**: If any halt condition triggers, stop and perform Fractal RCA.

---

## 14. Key File Locations Reference

| Subsystem | Files | Path |
|-----------|-------|------|
| Domain types | `domain.gleam` | `src/cepaf_gleam/ui/domain.gleam` |
| Lustre pages | 24 files | `src/cepaf_gleam/ui/lustre/` |
| Wisp handlers | 16 files | `src/cepaf_gleam/ui/wisp/` |
| TUI views | 25 files | `src/cepaf_gleam/ui/tui/` |
| Zenoh OTel | `zenoh_otel.gleam` | `src/cepaf_gleam/ui/zenoh_otel.gleam` |
| AG-UI events | 5 modules | `src/cepaf_gleam/agui/` |
| A2UI catalog | 5 modules | `src/cepaf_gleam/a2ui/` |
| Fractal L0-L7 | 8 modules | `src/cepaf_gleam/fractal/` |
| Test suite | 29 files | `test/*_test.gleam` |
| Coverage math | `coverage_math.gleam` | `src/cepaf_gleam/testing/coverage_math.gleam` |
| Zenoh observer | `zenoh_test_observer.gleam` | `src/cepaf_gleam/testing/zenoh_test_observer.gleam` |
| Test dashboard | `test_dashboard.gleam` | `src/cepaf_gleam/testing/test_dashboard.gleam` |

---

**Version**: 22.1.0-GLM
**Last Updated**: 2026-04-04
**Status**: Authoritative — use this prompt for all Gleam UI development/testing sessions
