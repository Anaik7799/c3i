# C3I Gleam-First System — Claude Guidance (v21.6.0-GLM)

## §1.0 System Identity & Mandate

**C3I is a Gleam-first cybernetic command-and-control cockpit for distributed mesh orchestration.**

- **Primary Language**: Gleam (type-safe, BEAM VM, hot reload)
- **UI Framework**: Lustre 5.6+ MVU (server-side rendered, no JavaScript)
- **API Framework**: Wisp 2.2.2 (HTTP/JSON)
- **Terminal UI**: ANSI renderer + Split-Screen TUI
- **Telemetry Bus**: Zenoh pub/sub mesh with OTel span publishing
- **Backend Integration**: Elixir/Phoenix (legacy, maintained for backwards compatibility)
- **Compute Bridge**: F# CEPAF (biomorphic synthesis, FMEA generation, formal verification)

The system uses a **Penta-Stack** architecture:
1. Gleam Lustre WebUI (port 4100)
2. Gleam Wisp REST API (port 4100)
3. Gleam TUI (ANSI terminal + Split-Screen dashboard)
4. Elixir Phoenix LiveView (port 4000, legacy)
5. F# Prajna CLI (fallback)

---

## §2.0 Penta-Stack Architecture

Every UI capability MUST be simultaneously available across all 3 Gleam interfaces. Types are shared from `ui/domain.gleam`; no per-interface duplication.

| Layer | Tech | Port | Purpose | Path |
|-------|------|------|---------|------|
| **Web UI** | Lustre 5.6+ MVU | 4100 | Server-rendered HTML, no client JS | `ui/lustre/*.gleam` |
| **REST API** | Wisp 2.2.2 HTTP | 4100 | Typed JSON endpoints | `ui/wisp/*.gleam` |
| **Terminal UI** | ANSI + Split-Screen | CLI | Dashboard with sparklines + test results | `ui/tui/*.gleam` |
| **Legacy Web** | Phoenix LiveView | 4000 | Backward compatibility | `lib/indrajaal_web/live/` |
| **CLI Fallback** | F# Console | CLI | Safety kernel, dark cockpit | `lib/cepaf/` |

---

## §2.5 Zenoh OTel Integration (NEW)

All 15 UI pages publish OpenTelemetry spans via `ui/zenoh_otel.gleam` for every state change.
OTel spans are transported over Zenoh topics `indrajaal/otel/spans/**` for distributed tracing.

**Module**: `ui/zenoh_otel.gleam` — OTel span context propagation, span builder, Zenoh publisher
**Test Observer**: `testing/zenoh_test_observer.gleam` — Zenoh message verification during tests
**Topics**: `indrajaal/otel/spans/{page}/{operation}`, `indrajaal/test/zenoh/observe/**`

---

## §3.0 Triple-Interface Mandate (SC-GLM-UI-001)

Every new page, dashboard, or interactive component MUST be implemented THREE times:

**Requirement**: A single feature = 1 Lustre page + 1 Wisp endpoint + 1 TUI view.

**Canonical Rule**: Before marking a feature "done," verify:
```
✓ Lustre page renders without client JS
✓ Wisp endpoint returns typed JSON (no string concat)
✓ TUI view displays terminal output (ANSI codes OK)
✓ All three share types from ui/domain.gleam
✓ OTel spans published via zenoh_otel (SC-GLM-ZEN-001)
```

**Consequences of omission**: Feature is 67% incomplete (only 1/3 interface).

---

## §4.0 Build & Test Commands

### Canonical Compile (SC-ENV-COMPILE)
```bash
NO_TIMEOUT=true \
PATIENT_MODE=enabled \
SKIP_ZENOH_NIF=0 \
WALLABY_ENABLED=true \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 \
mix compile --jobs 16
```

### Gleam Build
```bash
cd lib/cepaf_gleam
gleam build
```

### Gleam Test
```bash
cd lib/cepaf_gleam
gleam test
```

### Split-Screen Test Cycle (NEW)
```bash
./scripts/run-split-screen-tests.sh
```
Runs 10-minute test cycle with split-screen TUI: dashboard + test results simultaneously.
15 tabs × 8 fractal layers × 381 comprehensive regression tests.

### Wallaby E2E (Gleam UI coverage)
```bash
WALLABY_ENABLED=true \
SKIP_ZENOH_NIF=0 \
NO_TIMEOUT=true \
PATIENT_MODE=enabled \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
HEALTH_PORT=4051 \
MIX_ENV=test mix test --only wallaby
```

---

## §5.0 AG-UI 32-Event Protocol (SC-AGUI)

**AG-UI** is the event bus connecting agents (Claude, Gemini, external) to the Gleam UI.

All events defined in `agui/events.gleam` (5 modules, 1,224 lines):

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

**Modules**: `events.gleam` (582 lines), `state.gleam` (268), `tools.gleam` (231), `sse.gleam` (84), `zenoh_bus.gleam` (59)

**Transport**: Lustre server components (WebSocket) + Wisp REST (JSON) + Zenoh PubSub (telemetry) + OTel spans (zenoh_otel).

---

## §6.0 A2UI Declarative Catalog (SC-A2UI)

**A2UI** is the component schema system for agents. No executable code, JSON-only.

**16 Component Types** across 5 modules (655 lines):
- `schema.gleam` (118 lines) — ComponentSpec, PropSpec, BindingSpec, FractalLayer types
- `catalog.gleam` (230 lines) — Trusted registry: badge, button, data_table, progress, sparkline, alert, modal, ooda_ring, reasoning, topology, form_input, select, textarea, checkbox, radio, slider
- `renderer.gleam` (100 lines) — A2UI JSON → Lustre Element mapping
- `bindings.gleam` (88 lines) — Data binding (state path → component prop)
- `validator.gleam` (119 lines) — Security validation (allowlist enforcement)

**Pattern**: Agent → (A2UI JSON spec) → Validator → Renderer → Lustre HTML.

---

## §7.0 Fractal Widget Architecture (L0-L7)

Each fractal layer has a dedicated widget module in `fractal/`:

| Layer | Module | Lines | Purpose | HITL |
|-------|--------|-------|---------|------|
| L0 | `l0_constitutional.gleam` | 176 | Guardian approval, emergency stop, Psi invariants (Psi-0..5, Omega-0) | Mandatory |
| L1 | `l1_atomic_debug.gleam` | 118 | Debug trace viewer, event monitor, state inspections | Optional |
| L2 | `l2_component.gleam` | 112 | Reusable forms, data grids, badges, buttons, inputs | No |
| L3 | `l3_transaction.gleam` | 144 | State diff viewer, tool invocation panel, command history | Optional |
| L4 | `l4_system.gleam` | 202 | Agent run monitor, step tracker, execution timeline | Optional |
| L5 | `l5_cognitive.gleam` | 149 | Reasoning display, OODA ring, AI copilot panel | Optional |
| L6 | `l6_ecosystem.gleam` | 105 | Agent mesh topology, A2A messaging, collaboration | Optional |
| L7 | `l7_federation.gleam` | 101 | Gateway, version vectors, federated reconciliation, SIL-6 sync | Optional |

**Total**: 8 modules, 1,107 lines.

---

## §8.0 Testing Gold Standard (C1-C8)

All Gleam UI code MUST achieve **8-category gold standard coverage**:

| Category | Weight | Gate | Check |
|----------|--------|------|-------|
| C1 Page Structure | 1.0 | Renders without error | Lustre element count ≥ 5 |
| C2 Status Badges | 1.5 | All states visible | Healthy/Degraded/Critical all shown |
| C3 Data Grids | 1.0 | Rows render | ≥ 3 rows × ≥ 3 columns |
| C4 Timeline | 0.8 | Events in order | Timestamp validation |
| C5 Interactive | 1.2 | Buttons work | Click → state change |
| C6 Media/Rich | 0.8 | Assets load | SVG/PNG verified |
| C7 AI Advisory | 1.5 | AG-UI events flow | E2E Zenoh publish verified |
| C8 Action Button | 3.0 | Safety gates pass | Guardian approval + 2oo3 consensus |

**Math Gates** (ALL must pass):
- Shannon Entropy H ≥ 2.5 bits
- Cyclomatic Complexity CCM ≥ 90%
- Expected vs Actual Divergence D_EA ≤ 10%
- Integrated Test Quality Score ITQS ≥ 0.85

### §8.1 Comprehensive Regression Suite (NEW)

**Test file**: `test/comprehensive_ui_regression_test.gleam`
- **381 tests** covering all 15 tabs × 8 fractal layers
- **100% tab coverage** — every tab verified
- **Zenoh message verification** via `testing/zenoh_test_observer.gleam`
- **OTel span validation** via `ui/zenoh_otel.gleam`
- **30+ second monitoring** per tab during verification (SC-GLM-TST-002)

### §8.2 Test Metrics (Current)

| Metric | Value | Threshold | Status |
|--------|-------|-----------|--------|
| Total Tests | 1,559 passed, 0 failures | — | PASS |
| Shannon Entropy H | 2.67 bits (weighted mean) | ≥ 2.5 bits | PASS |
| CCM | 0.770 | ≥ 0.90 | IMPROVING |
| ITQS | 0.736 | ≥ 0.85 | IMPROVING |
| D_EA | — | ≤ 10% | — |
| Tab Coverage | 100% (15/15) | 100% | PASS |
| Zenoh Verification | Active | — | PASS |

---

## §9.0 Key File Locations

| Subsystem | Files | Lines | Path |
|-----------|-------|-------|------|
| Domain types | 1 | 166 | `lib/cepaf_gleam/src/cepaf_gleam/ui/domain.gleam` |
| Lustre Web UI | 24 | 3,415 | `lib/cepaf_gleam/src/cepaf_gleam/ui/lustre/*.gleam` |
| Wisp REST API | 15 | 2,278+ | `lib/cepaf_gleam/src/cepaf_gleam/ui/wisp/*.gleam` |
| TUI Terminal | 23 | 1,730+ | `lib/cepaf_gleam/src/cepaf_gleam/ui/tui/*.gleam` |
| Zenoh OTel | 1 | — | `lib/cepaf_gleam/src/cepaf_gleam/ui/zenoh_otel.gleam` |
| AG-UI Events | 5 | 1,224 | `lib/cepaf_gleam/src/cepaf_gleam/agui/*.gleam` |
| A2UI Catalog | 5 | 655 | `lib/cepaf_gleam/src/cepaf_gleam/a2ui/*.gleam` |
| Fractal L0-L7 | 8 | 1,107 | `lib/cepaf_gleam/src/cepaf_gleam/fractal/*.gleam` |
| Testing | 4 | 602+ | `lib/cepaf_gleam/src/cepaf_gleam/testing/*.gleam` |
| Zenoh Test Observer | 1 | — | `lib/cepaf_gleam/src/cepaf_gleam/testing/zenoh_test_observer.gleam` |
| Test Dashboard | 1 | — | `lib/cepaf_gleam/src/cepaf_gleam/testing/test_dashboard.gleam` |
| Verification | 4 | 383 | `lib/cepaf_gleam/src/cepaf_gleam/verification/*.gleam` |
| **Test suite** | **24** | **10,106+** | `lib/cepaf_gleam/test/*_test.gleam` |
| **TOTAL** | **113+** | **~22,000+** | — |

---

## §10.0 Active Constraints Cross-Reference

Full constraint registry (2,257 SC-* / 480 AOR-* at parity): `.claude/rules/constraint-registry.md`

Key Gleam UI families: SC-GLM-UI(10) SC-AGUI(10) SC-A2UI(8) SC-UIGT(10) SC-HINT(8) SC-MATH-COV(6) SC-HMI(80) SC-VER(79) SC-FRACTAL(8) SC-PROM(7) SC-GLM-ZEN(3) SC-GLM-TST(2)

### New STAMP Constraints (v21.6.0-GLM)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-GLM-ZEN-001 | All UI state changes MUST publish OTel spans via zenoh_otel | CRITICAL |
| SC-GLM-ZEN-002 | Test runner MUST observe Zenoh messages for verification | CRITICAL |
| SC-GLM-ZEN-003 | Split-screen TUI MUST display dashboard + test results simultaneously | HIGH |
| SC-GLM-TST-001 | 100+ regression tests required per release | CRITICAL |
| SC-GLM-TST-002 | Each tab monitored for 30+ seconds during verification | HIGH |

**See** `docs/GLEAM_UI_DEVELOPMENT_PROMPT.md` for development session prompt.

---

**Version**: 21.6.0-GLM
**Last Updated**: 2026-04-04
**Status**: Gleam-first platform operational (113+ modules, 22,000+ lines, 1,559 tests, 100% tab coverage)
