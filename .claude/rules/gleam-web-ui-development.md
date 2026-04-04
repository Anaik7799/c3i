---
paths: lib/cepaf_gleam/src/cepaf_gleam/ui/**/*.gleam, lib/cepaf_gleam/src/cepaf_gleam/agui/**/*.gleam, lib/cepaf_gleam/src/cepaf_gleam/a2ui/**/*.gleam, lib/cepaf_gleam/src/cepaf_gleam/testing/**/*.gleam, lib/cepaf_gleam/src/cepaf_gleam/fractal/**/*.gleam, lib/indrajaal_gleam_web/src/**/*.gleam, lib/cepaf_gleam/test/**/*.gleam
---

# Gleam Fractal Agentic UI Development & Testing Protocol (v21.4.0-GLM)

**ALL C3I Web UI: Penta-Stack, AG-UI 32-event, A2UI catalog, Lustre SSR (no JS), Triple-Interface mandate, Dark Cockpit 5-mode, 8-category coverage gold standard.**

## 1.0 Penta-Stack Architecture (SC-GLM-UI-001)

| Layer | Tech | Port | Path | Purpose |
|-------|------|------|------|---------|
| Lustre Web SSR | Lustre 5.6+ MVU | 4100 | `ui/lustre/*.gleam` | Server-rendered HTML, no client JS |
| Wisp REST API | Wisp 1.0.0 HTTP | 4100 | `ui/wisp/*.gleam` | Typed JSON endpoints |
| TUI Terminal | ANSI + Renderer | CLI | `ui/tui/*.gleam` | Dashboard with sparklines |
| Phoenix LiveView | Elixir Phoenix | 4000 | `lib/indrajaal_web/live/` | Legacy backward compat |
| F# CLI Fallback | F# Console | CLI | `lib/cepaf/` | Safety kernel fallback |

**Triple-Interface**: Every feature = 1 Lustre page + 1 Wisp endpoint + 1 TUI view. All share types from `ui/domain.gleam` ONLY. A feature on 1 interface is 67% incomplete.

**Shared types**: `cepaf_gleam/ui/domain.gleam` — Page, HealthStatus, TelemetryPoint, Action, RenderContext. See source file for definitions.

## 2.0 STAMP Constraints (SC-GLM-UI)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-GLM-UI-001 | Triple-Interface: Lustre SSR + Wisp JSON + TUI ANSI for every capability | CRITICAL |
| SC-GLM-UI-002 | Lustre MVU: Model/Msg/init/update/view — server-side on BEAM | HIGH |
| SC-GLM-UI-003 | Typed JSON via `gleam/json` — NO raw string concatenation | HIGH |
| SC-GLM-UI-004 | All UI modules MUST have C3I-SIL6-MSTS module contract header | MEDIUM |
| SC-GLM-UI-005 | Real-time telemetry via Zenoh PubSub subscription | HIGH |
| SC-GLM-UI-006 | Wisp HTTP binds to port 4100 — outside mesh range 4000-4010 | CRITICAL |
| SC-GLM-UI-007 | Every Wisp endpoint MUST have corresponding Lustre + TUI view | HIGH |
| SC-GLM-UI-008 | Dark Cockpit: panels auto-hide when healthy (SC-HMI-010) | HIGH |
| SC-GLM-UI-009 | Shared types from `ui/domain.gleam` ONLY — no duplication | HIGH |
| SC-GLM-UI-010 | AG-UI SSE/WebSocket streaming for real-time dashboard updates | HIGH |

## 3.0 Lustre MVU Pattern

**Canonical structure**: `init(ctx: RenderContext) -> Model`, `update(model, msg) -> Model` (pure), `view(model) -> Element(Msg)`. Server-side only, no client JS emitted. See any `ui/lustre/*.gleam` file for the pattern.

### Module contract header (SC-GLM-UI-004):
```gleam
//// [C3I-SIL6-MSTS] MODULE CONTRACT
//// <c3i-module><identity><module>cepaf_gleam/ui/lustre/{page}</module></identity>
////   <fractal-topology><layer>{LAYER}</layer></fractal-topology>
////   <compliance><stamp-controls>SC-GLM-UI-001, SC-GLM-UI-002</stamp-controls></compliance>
//// </c3i-module>
```

### Lustre View Modules (24 total)
| Module | Page | Layer | Module | Page | Layer |
|--------|------|-------|--------|------|-------|
| app.gleam | Dashboard | L5 | cockpit_view.gleam | Cockpit | L5 |
| planning.gleam | Planning | L3 | verification.gleam | PROMETHEUS | L0 |
| immune.gleam | Immune | L0 | substrate.gleam | File/SQLite | L3 |
| knowledge.gleam | Knowledge | L5 | metabolic.gleam | Metabolic | L1 |
| zenoh_mesh.gleam | Zenoh | L6 | podman.gleam | Containers | L4 |
| mcp.gleam | MCP | L6 | kms.gleam | Keys | L0 |
| telemetry.gleam | OTEL | L1 | + 11 planned | Various | L0-L7 |

### Lustre Effects (SC-AGUI-014)
Use `effect.from(fn(dispatch) { ... })` for Zenoh subscriptions. Batch with `effect.batch([...])`.

## 4.0 Wisp REST API (SC-GLM-UI-003)

Router at `ui/wisp/router.gleam`, port 4100. All endpoints return typed JSON via `gleam/json` — never string concatenation.

**Core routes**: `/api/v1/{dashboard,planning,immune,knowledge,zenoh,verification,substrate,metabolic,podman,mcp,kms,telemetry}`
**AG-UI routes**: `/ag-ui/{run,events,health,hitl/respond,hitl/pending,tools/result,state}`

### Wisp API Modules (14): router, planning_api, planning_routes, immune_api, knowledge_api, zenoh_api, verification_api, cockpit_api, substrate_api, metabolic_api, podman_api, mcp_api, kms_api, telemetry_api

## 5.0 TUI Terminal

ANSI rendering via `cockpit/visuals.gleam`: `with_color`, `render_progress_bar`, `render_sparkline`, `render_table`.

### Dark Cockpit 5-Mode State Machine (`prajna/dark_cockpit.gleam`)
| Mode | Trigger | Display | Color |
|------|---------|---------|-------|
| Dark | No alerts | Minimal gray | Monochrome |
| Dim | Warnings | Subtle yellow | Low-saturation |
| Normal | Errors | Visible orange | Standard |
| Bright | Multiple errors | High-visibility | High-contrast |
| Emergency | Critical | Full illumination + flash | Red dominant |

**4 Color Profiles** (SC-HMI-010): Dark Cockpit (default), Color Rich (metabolic-linked), Google WCAG 2.1 AA, Functionally Clean (monochrome).

### TUI Modules (22): renderer, cockpit_view, planning_view, immune_view, knowledge_view, zenoh_view, verification_view, substrate_view, metabolic_view, podman_view, mcp_view, kms_view, telemetry_view + 9 planned

## 6.0 AG-UI 32-Event Protocol (SC-AGUI)

| Category | # | Events |
|----------|---|--------|
| Lifecycle | 5 | RunStarted, RunFinished, RunError, StepStarted, StepFinished |
| Text | 4 | TextMessageStart/Content/End/Chunk |
| Tool | 5 | ToolCallStart/Args/End/Result/Chunk |
| State | 3 | StateSnapshot, StateDelta (RFC 6902), MessagesSnapshot |
| Activity | 2 | ActivitySnapshot, ActivityDelta |
| Reasoning | 7 | ReasoningStart, MessageStart/Content/End/Chunk, ReasoningEnd, EncryptedValue |
| Special | 4 | Raw, Custom, MetaEvent, Heartbeat |

**Transport**: Lustre WebSocket (DOM patches) | SSE fallback | Wisp REST (JSON) | Zenoh PubSub (A2A)

**Modules** (`agui/`): events.gleam (32 EventType ADT) | state.gleam (RFC 6902 + SharedState) | tools.gleam (tool lifecycle + HITL) | sse.gleam (SSE fallback) | zenoh_bus.gleam (Zenoh pub/sub + A2A)

**HITL**: MANDATORY for L0 Constitutional operations. Flow: agent ToolCallStart -> Lustre A2UI modal -> user POST `/ag-ui/hitl/respond` -> agent ToolCallResult.

## 7.0 A2UI Declarative Component Catalog (SC-A2UI)

Agents propose UI via **declarative JSON only** — NEVER executable code. Application owns trusted catalog.

**Modules** (`a2ui/`): schema.gleam (types) | catalog.gleam (registry + layer access) | renderer.gleam (JSON -> Element/ANSI) | bindings.gleam (state path -> prop) | validator.gleam (allowlist)

| A2UI Type | Layer | Props |
|-----------|-------|-------|
| badge | L2 | label, variant |
| button | L2 | label, action, disabled |
| data_table | L3 | headers, rows, sortable |
| progress | L4 | value, max, label |
| sparkline | L1 | data, width, height |
| alert | L0 | message, severity |
| modal | L0 | title, body, actions |
| ooda_ring | L5 | phase, latency |
| reasoning | L5 | content, encrypted |
| topology | L6 | nodes, edges |
| form_input/select/slider | L2 | type, label, value, options, min, max |

**Layer Access**: L0 agents access all. Non-L0 agents CANNOT propose L0 components. Otherwise same-layer only.

## 8.0 Fractal Widget Architecture (L0-L7)

| Layer | Module | Primary Widgets | HITL |
|-------|--------|----------------|------|
| L0 Constitutional | l0_constitutional.gleam | Guardian approval, emergency stop, Psi invariants | YES |
| L1 Atomic/Debug | l1_atomic_debug.gleam | Debug trace, NIF status, Zenoh session | No |
| L2 Component | l2_component.gleam | Forms, grids, badges, inputs | No |
| L3 Transaction | l3_transaction.gleam | State diff, tool panel, command history | No |
| L4 System | l4_system.gleam | Run monitor, step tracker, container health | No |
| L5 Cognitive | l5_cognitive.gleam | Reasoning, OODA ring, AI copilot | No |
| L6 Ecosystem | l6_ecosystem.gleam | Mesh topology, A2A, quorum routers | No |
| L7 Federation | l7_federation.gleam | Gateway, version vectors, attestation | Yes |

**Key types** in l0_constitutional.gleam: ApprovalRequest, PsiCheck, PsiInvariant (Psi0..5, Omega0), FractalElement (id, layer, element_type, agent_binding, capabilities).

## 9.0 Testing — 8 Categories (C1-C8)

| Cat | Name | Weight | Gate |
|-----|------|--------|------|
| C1 | Page Structure | 1.0 | Element count >= 5 |
| C2 | Status Badges | 1.5 | Healthy/Degraded/Critical visible |
| C3 | Data Grids | 1.0 | >= 3 rows x 3 cols |
| C4 | Timeline | 0.8 | Timestamp ordering |
| C5 | Interactive | 1.2 | Click -> state change |
| C6 | Media/Rich | 0.8 | SVG/sparklines load |
| C7 | AI Advisory | 1.5 | AG-UI events flow |
| C8 | Action Button | 3.0 | Guardian + 2oo3 consensus |

**Source-First** (AOR-COV-008): Read Model -> Msg -> update() -> view() -> Zenoh subscriptions BEFORE writing tests.

## 10.0 Math Gates (SC-MATH-COV)

| Gate | Threshold | Formula |
|------|-----------|---------|
| Shannon Entropy H | >= 2.5 bits | H = -sum(p_i * log2(p_i)) across C1-C8 |
| CCM | >= 90% | CCM = sum(w_i * cov_i) / sum(w_i) |
| ITQS | >= 0.85 | 0.4*H_norm + 0.4*CCM + 0.2*D |
| Human Intent | >= 0.70 | Jaccard: |EXPECTED ∩ AS-IS| / |EXPECTED ∪ AS-IS| |

Weights: [1.0, 1.5, 1.0, 0.8, 1.2, 0.8, 1.5, 3.0] for C1-C8. Grades: A>=0.90, B>=0.80, C>=0.70, D<0.70.

## 11.0 Graph-Theory Testing (SC-UIGT)

**Navigation digraph**: |V|=22 pages, |E|≈462 (complete via nav bar), SCC=1, density=1.0. PageRank for test priority (Dashboard > Cockpit > Verification). Chinese Postman bound: CPP ≈ 462 + per-page LTS transitions.

**Per-page LTS**: States from Model fields, labels from Msg variants, transitions from update() branches. Gleam compiler enforces exhaustive pattern matching. Prime path coverage >= 0.95 (Tier 1), >= 0.80 (Tier 2).

**Modules** (`testing/`): nav_graph.gleam (PageRank, SCC, adjacency) | coverage_math.gleam (H, CCM, ITQS, FSI, D_EA) | alignment.gleam (Human Intent Jaccard)

## 12.0 Human Intent Protection

See `core-protocols.md §3` for full SC-HINT specification. Key rule: `## Human-Specified Intent` section with `<!-- HUMAN-ONLY -->` sentinel is INVIOLABLE. Alignment score >= 0.70 required. Agents MUST NEVER modify this section.

## 13.0 File Structure Summary

```
lib/cepaf_gleam/src/cepaf_gleam/
  agui/     (5 modules)  — AG-UI 32-event protocol
  a2ui/     (5 modules)  — A2UI declarative components
  testing/  (3 modules)  — Coverage math, nav graph, alignment
  ui/domain.gleam        — CANONICAL shared types
  ui/lustre/ (24 modules) — Lustre SSR pages
  ui/wisp/  (14 modules)  — REST API endpoints
  ui/tui/   (22 modules)  — Terminal ANSI views
  fractal/  (8 modules)   — L0-L7 widgets
  prajna/   (7 modules)   — Dark cockpit, bio, neuro, immune, circuit breaker
  cockpit/  (2 modules)   — Domain types, visuals
  verification/ (2 modules) — Swarm, probes
lib/cepaf_gleam/test/     — gleeunit tests mirroring src structure
```

## 14.0 Build & Test

See `build-and-test.md` for canonical compile/test/wallaby commands. Gleam-specific:
```bash
cd lib/cepaf_gleam && gleam build    # Build
cd lib/cepaf_gleam && gleam test     # Test
```

## 15.0 STAMP Summary

| Family | Range | # | Domain |
|--------|-------|---|--------|
| SC-GLM-UI | 001-010 | 10 | Triple interface, Lustre, Wisp, TUI, types |
| SC-AGUI | 001-017 | 17 | AG-UI 32-event, transport, HITL |
| SC-A2UI | 001-005 | 5 | A2UI declarative catalog, JSON-only |
| SC-UIGT | 001-015 | 15 | UI graph theory (LTS, prime paths, PageRank) |
| SC-HINT | 001-008 | 8 | Human Intent protection, alignment >= 0.70 |
| SC-MATH-COV | 001-008 | 8 | Shannon H, CCM, ITQS math gates |
| SC-HMI | 001-080 | 80 | HMI cockpit, dark cockpit, accessibility |

## 16.0 Verification Checklist

**Triple-Interface**: Lustre renders w/o JS | Wisp returns typed JSON | TUI renders ANSI | All use domain.gleam types
**AG-UI**: Subscribes to events | HITL for L0 actions | Events emitted | SSE endpoint available
**Coverage**: C1-C8 addressed | H >= 2.5 | CCM >= 0.90 | ITQS >= 0.85 | Intent alignment >= 0.70 | Prime paths >= 0.95 (Tier 1)
**Dark Cockpit**: Healthy=hidden | Degraded=Dim/Normal | Critical=Emergency | Mode via determine_mode()
**Human Intent**: Section present | HUMAN-ONLY sentinel | Not modified by agent
