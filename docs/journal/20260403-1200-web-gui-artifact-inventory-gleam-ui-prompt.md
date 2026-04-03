# Journal: Web GUI Artifact Inventory & Gleam UI Development Prompt

**Date**: 2026-04-03 12:00 CEST
**Author**: Claude Opus 4.6
**Type**: Audit / Documentation / Prompt Engineering

---

## 1. Scope & Trigger

**Trigger**: User requested a comprehensive inventory of ALL Web GUI related artifacts across
the c3i and intelitor-v5.2 codebases — rules, skills, agents, CLAUDE.md, GEMINI.md, AGENTS.md
sections — covering design, coding, implementation, testing, verification, and coverage guidelines.
The goal was to collate them and produce a reusable prompt for Gleam-based Web UI development
and testing in the c3isystem.

**Scope**:
- Full audit of `.claude/rules/*.md` (41 files in c3i, 42 files in intelitor-v5.2)
- Full audit of `.claude/agents/*.md` (27 agent definitions)
- STAMP constraint family census for UI-relevant families
- Gleam source code inventory (`lib/cepaf_gleam/`, `lib/indrajaal_gleam_web/`)
- Design documents (`docs/PLANNING_WEBUI_DESIGN.md`)
- Creation of consolidated rule file and development prompt

---

## 2. Pre-State Assessment

Before this audit:
- Web GUI knowledge was scattered across 10+ rule files, 3 agent definitions, 200+ STAMP constraints, and 67+ Gleam source files
- No single consolidated reference existed for Gleam-based Web UI development
- The relationship between Elixir/Phoenix LiveView artifacts (Wallaby, HMI, coverage) and the new Gleam/Lustre codebase was not formally documented
- intelitor-v5.2's location (inside c3i, not separate) was not explicitly documented

---

## 3. Execution Detail

### 3.1 Discovery Phase

Searched both codebases in parallel using Glob, Grep, and Read tools:

**c3i `.claude/rules/` — 41 rule files scanned, 10 found UI-relevant:**

| # | Rule File | UI Relevance |
|---|-----------|-------------|
| 1 | `ui-graph-testing.md` | Mathematical graph-theory testing for 30 Prajna LiveView pages. Models navigation as directed graph G_nav = (V, E), page state as Labeled Transition Systems (LTS), PubSub channels as bipartite hypergraph. Prime path coverage >= 0.95. 15 STAMP constraints (SC-UIGT-001 to SC-UIGT-015), 10 AOR rules (AOR-UIGT-001 to AOR-UIGT-010). Defines 3 page complexity tiers, Chinese Postman lower bound (~458 test cases), PageRank-weighted test priority for 5 highest-priority pages. |
| 2 | `fractal-coverage-gold-standard.md` | Defines the 8 mandatory Wallaby E2E test categories (C1-C8): C1 Page Structure (w=1.0), C2 Status/Badge (w=1.5), C3 Data Grid (w=1.0), C4 Timeline (w=1.2), C5 Interactive (w=2.0), C6 Media/Rich (w=1.0), C7 AI/Advisory (w=1.5), C8 Action Buttons (w=3.0). Gold standard template with @moduledoc 9-section spec. Shannon entropy H >= 2.5 bits. C8 dual verification (status change + flash) mandatory. Two-step commit (arm/confirm/cancel). Quality gates per priority: P0>=30 features, P1>=20, P2>=15, P3>=10. FMEA Findings Registry with 7 known bugs. 5-wave execution plan. 14 STAMP constraints (SC-COV-009 to SC-COV-022), 10 AOR rules (AOR-COV-008 to AOR-COV-017). |
| 3 | `fractal-coverage-mathematical-framework.md` | Formal mathematical foundations: (1) Fractal Coverage Tensor C[layer][depth][element] mapping 7 tensor layers to 8 gold-standard categories with 4 depth indices (state/structure/actions/timeline). (2) Shannon Coverage Entropy H = -Sum(n_i/N * log2(n_i/N)), H_norm >= 0.83. (3) CCM weighted completeness with category weights, acceptance gates CCM >= 0.95 for P0, >= 0.90 for P1. (4) FMEA RPN_coverage >= 0.95 for safety pages. (5) Fractal Self-Similarity Index FSI = 1 - (sigma_H / mu_H) >= 0.85. (6) EXPECTED vs AS-IS Divergence D_EA <= 0.10 with 5-step source-derivation protocol. (7) ITQS = 0.25*H_norm + 0.35*CCM + 0.25*(1-D_EA) + 0.15*FSI >= 0.85 system-wide, >= 0.75 per file. 8 STAMP constraints (SC-MATH-COV-001 to SC-MATH-COV-008), 8 AOR rules. |
| 4 | `prajna-biomorphic.md` | Prajna cockpit integration rules. Paths trigger on `lib/indrajaal/cockpit/**/*.ex` and `lib/indrajaal_web/live/prajna/**/*.ex` and `lib/cepaf/src/Cepaf/Cockpit/**/*.fs`. References SC-PRAJNA-001 to SC-PRAJNA-007, AOR-PRAJNA-001 to AOR-PRAJNA-005. Critical modules: GuardianIntegration, AiCopilotFounder (Three Supreme Goals), SentinelBridge (30s sync), ImmutableState (Ed25519 + SHA3-256 + DuckDB). Color Rich & Interface Profiles (SC-HMI-010): Shift from Dark Cockpit to Color Rich Mechanism. 4 selectable profiles: Dark Cockpit, Color Rich, Google Compliant, Functionally Clean. 8x8 Fractal Matrix (8 Elements x 8 Layers) for all UI verification. 100% path coverage mandate. |
| 5 | `five-level-testing.md` | Defines 6 test levels. Level 6 (E2E): Wallaby + Chrome via NixOS devenv. `IndrajaalWeb.FeatureCase` template with Ecto Sandbox metadata passthrough. `WALLABY_ENABLED=true mix test --only wallaby` or `test-e2e` devenv command. 23+ page object modules in `test/support/wallaby_page_objects.ex`. `@moduletag :wallaby` and `async: false`. Screenshots on failure in `test/wallaby/screenshots/`. Config: `config/wallaby.exs`. 8-category gold standard (C1-C8) per SC-COV-009 to SC-COV-016. C8 dual verification. Two-step commit (SC-COV-019). Coverage entropy H >= 2.5 bits (AOR-COV-012). 8 STAMP constraints (SC-COV-001 to SC-COV-008), 7+ AOR rules. |
| 6 | `human-intent-protection.md` | Every page spec MUST contain `## Human-Specified Intent` section with `<!-- HUMAN-ONLY: DO NOT AUTO-MODIFY -->` sentinel. Agents ABSOLUTELY FORBIDDEN from creating/editing/deleting content inside this section. Alignment Score = |EXPECTED intersection AS-IS| / |EXPECTED union AS-IS|. Thresholds: >= 0.9 ALIGNED, 0.7-0.9 DRIFT, < 0.7 MISALIGNED (P1 alert, block agent modifications). 5-step computation: parse EXPECTED from intent, parse AS-IS from LiveView .ex, compute intersection, report per-statement breakdown. Misalignment response: BLOCK + P1 ALERT + LOG to Immutable Register + PUBLISH to Zenoh. 8 STAMP constraints (SC-HINT-001 to SC-HINT-008), 5 AOR rules (AOR-HINT-001 to AOR-HINT-005). Constitutional alignment: Psi-2, Psi-3, Omega-4, SC-COV-021, SC-HMI-010. |
| 7 | `cpu-governor.md` | CPU governance for UI testing. `governed_wallaby` function includes ALL required env vars: WALLABY_ENABLED=true, SKIP_ZENOH_NIF=0, NO_TIMEOUT=true, PATIENT_MODE=enabled, HEALTH_PORT=4051, DATABASE_URL. Port assignments: 4000-4010 reserved for 16-container mesh, 4050 for Phoenix Wallaby test endpoint, 4051 for FoundationSupervisor health plug (test), 5433 PostgreSQL, 7447 Zenoh. Wallaby config: base_url localhost:4050, server true, HTTP port 4050, Oban plugins/queues disabled. Adaptive parallelism table based on CPU%. 10 STAMP constraints (SC-CPU-GOV-001 to SC-CPU-GOV-010), 10 AOR rules. |
| 8 | `mandatory-compile-env.md` | WALLABY_ENABLED=true mandatory for ALL compile/test invocations. Canonical Wallaby E2E command: `WALLABY_ENABLED=true SKIP_ZENOH_NIF=0 NO_TIMEOUT=true PATIENT_MODE=enabled ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" POSTGRES_USER=postgres POSTGRES_PASSWORD=postgres DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_test" MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 MIX_ENV=test mix test --only wallaby`. 8 STAMP constraints (SC-ENV-COMPILE-001 to SC-ENV-COMPILE-008), 5 AOR rules. |
| 9 | `biomorphic-mode.md` | Quality gates before marking any task complete: (1) `mix compile --jobs 16` 0 errors 0 warnings, (2) `mix format --check-formatted`, (3) `mix credo --strict` 0 issues, (4) `mix test` 0 failures, (5) All STAMP constraints verified. Telemetry dashboard 30s refresh. |
| 10 | `reconciled-p2-domain-critical.md` | SC-HMI-001 to SC-HMI-080 (80 constraints) — Human-Machine Interface for Prajna cockpit UI compliance, accessibility, dark cockpit. Also SC-MCP-001..082, SC-SEM-001..072, SC-ACE-001..039, SC-KMS-001..023. |

### 3.2 Agent Inventory

**27 agent definitions scanned in `.claude/agents/`, 3 found UI-relevant:**

| # | Agent File | Description | Tools | Model |
|---|-----------|-------------|-------|-------|
| 1 | `wallaby-coverage-engineer.md` | Writes and fixes Wallaby E2E browser tests to achieve 8-category gold standard coverage. Shannon entropy >= 2.5 bits, CCM >= 90%, ITQS >= 0.85 per file. Source-first: reads LiveView .ex BEFORE writing selectors (AOR-COV-008). Human-Specified Intent sections never modified (SC-HINT-002). 8-category taxonomy with section markers. Entropy optimization strategies for heavy C3 bias and missing C4-C8. C8 dual verification pattern. Two-step commit pattern. FMEA table template. Execution workflow: read source -> read test -> count features -> compute entropy -> add to weakest categories -> verify. Mathematical quality gates table. References gold standard test file, FeatureCase, ITQS audit mix task. | Read, Write, Edit, Grep, Glob, Bash(mix:*), Bash(git:*) | sonnet |
| 2 | `coverage-audit-agent.md` | Automatically audits ALL Wallaby test files against the gold standard using mathematical and information theory criteria. 5-phase audit: (1) Census — glob all wallaby files, extract feature counts per C1-C8 from markers. (2) Mathematical Metrics — Shannon entropy, CCM, feature density, balance ratio, FSI, mean H, files below threshold. (3) Source Correlation — read .ex source, extract handle_event/mount/PubSub/timers, compute D_EA divergence, check Human-Specified Intent alignment. (4) FMEA Coverage — extract FMEA table, verify tests for RPN >= 100 modes, compute RPN_coverage. (5) Recommendations — per-file report with corrections prioritized by RPN. Triggers: after Wallaby file modification, LiveView source modification, on demand, weekly. | All tools | sonnet |
| 3 | `prajna-operator.md` | Operates and analyzes the Prajna C3I Command Cockpit. 33 modules across Core Command Layer (guardian_integration, sentinel_bridge, immutable_state, prometheus_verifier, ai_copilot, ai_copilot_founder, orchestrator, config, supervisor), Bio Layer (membrane, vital_signs), Neuro Layer (spine, reflex), Immune Layer (mara, antibody), SIL-6 Safety Components (DualChannel, Watchdog, Diagnostics). | Read, Grep, Glob, Bash | sonnet |

### 3.3 STAMP Constraint Census (UI-Relevant)

| Family | ID Range | Count | Severity | Description |
|--------|----------|-------|----------|-------------|
| SC-HMI | 001-080 | 80 | HIGH | Human-Machine Interface — Prajna cockpit UI compliance, accessibility, dark cockpit |
| SC-COV | 001-022 | 22 | HIGH-CRITICAL | Coverage — Wallaby E2E, 8-category gold standard, entropy gates |
| SC-MATH-COV | 001-008 | 8 | HIGH-CRITICAL | Mathematical coverage framework — tensor, Shannon entropy, CCM, FMEA RPN, FSI, D_EA, ITQS |
| SC-UIGT | 001-015 | 15 | HIGH-CRITICAL | UI Graph Testing — navigation digraph, LTS, prime paths, PageRank |
| SC-HINT | 001-008 | 8 | CRITICAL-HIGH | Human Intent Protection — inviolable spec sections, alignment scoring |
| SC-GLM-UI | 001-010+ | 10+ | HIGH-CRITICAL | Gleam UI — triple-interface mandate, typed JSON, dark cockpit, SSE, port 4100 |
| SC-VDP | 001-017 | 17 | HIGH | Visual Data Plane — cluster visualization, data presentation |
| SC-GRID | 001-025 | 25 | MEDIUM | Grid Layout — capability grid, data grid, responsive layout |
| SC-ARROW | 001-012 | 12 | MEDIUM | Signal Arrows — cockpit signal flow visualization |
| SC-THEME | 001-006 | 6 | MEDIUM | Theme System — cockpit theme management, dark mode |
| SC-COMONAD | 001-008 | 8 | MEDIUM | UI Comonads — functional UI composition |
| SC-EFFECT | 001-010 | 10 | MEDIUM | Cockpit Effects — side effect management |
| SC-STM | 001-008 | 8 | HIGH | State Machine — concurrent cockpit state |
| SC-COCKPIT | 001-004 | 4 | MEDIUM | Cockpit UI component constraints |
| SC-DRK | 001-004 | 4 | MEDIUM | DRK (Dark) UI component |
| SC-LED | 001-004 | 4 | MEDIUM | LED UI component |
| SC-FBK | 001-004 | 4 | MEDIUM | Feedback UI component |
| SC-HMP | 001-004 | 4 | MEDIUM | Heatmap UI component |
| SC-INT | 001-004 | 4 | MEDIUM | Interaction UI component |
| SC-ENT | 001-004 | 4 | MEDIUM | Entity UI component |
| SC-PRT | 001-004 | 4 | MEDIUM | Print UI component |
| SC-CONFIG | 001-006 | 6 | MEDIUM | Configuration — Prajna settings |
| SC-C3I | 001-005 | 5 | HIGH | C3I Console — command and control |
| SC-DASH | 001-005 | 5 | MEDIUM | Dashboard — distributed dashboard |
| SC-JRN | 001-005 | 5 | LOW | Journal — theme simulator journaling |
| SC-STREAM | 001-010 | 10 | MEDIUM | Telemetry Streams — cockpit data streaming |
| **TOTAL** | | **~230+** | | |

### 3.4 Gleam Codebase Inventory

**Two Gleam projects discovered inside c3i:**

#### `lib/cepaf_gleam/` — Core Gleam Library (gleam.toml)
- **Name**: `cepaf_gleam` v1.0.0
- **Dependencies**: `gleam_stdlib >= 0.44.0`, `gleam_http >= 4.3.0`, `gleam_json >= 3.1.0`, `gleam_erlang >= 1.3.0`, `gleam_otp >= 1.2.0`, `hackney >= 3.2.1`, `esqlite >= 0.9.0`, `gleam_crypto >= 1.0.0`, `lustre >= 5.2.0` (SC-GLM-UI-001), `wisp >= 1.0.0`, `gleam_regexp >= 1.1.1`
- **Dev deps**: `gleeunit >= 1.0.0`

**67+ UI source files across 3 interface layers:**

##### Lustre (Web SSR) — `ui/lustre/*.gleam` (18+ modules)
| Module | Purpose | STAMP |
|--------|---------|-------|
| `app.gleam` | Main MVU application — Model(context, dark_cockpit, selected_page), Msg(NavigateTo, TelemetryReceived, HealthUpdated, ZenohConnectionChanged, ToggleDarkCockpit, Tick) | SC-GLM-UI-001, SC-GLM-UI-002, SC-GLM-UI-005, SC-GLM-UI-008 |
| `cockpit_view.gleam` | Cockpit overview dashboard | SC-GLM-UI-001 |
| `planning.gleam` | Planning board | SC-GLM-UI-001 |
| `planning_dashboard.gleam` | Planning dashboard with charts | SC-GLM-UI-001 |
| `immune.gleam` | Immune system view | SC-GLM-UI-001 |
| `knowledge.gleam` | Knowledge/Smriti view | SC-GLM-UI-001 |
| `zenoh_mesh.gleam` | Zenoh mesh topology | SC-GLM-UI-001 |
| `verification.gleam` | Verification status | SC-GLM-UI-001 |
| `substrate.gleam` | Substrate infrastructure view | SC-GLM-UI-001 |
| `metabolic.gleam` | Metabolic subsystem view | SC-GLM-UI-001 |
| `podman.gleam` | Podman container view | SC-GLM-UI-001 |
| `mcp.gleam` | MCP server view | SC-GLM-UI-001 |
| `kms.gleam` | KMS catalog view | SC-GLM-UI-001 |
| `telemetry.gleam` | Telemetry dashboard | SC-GLM-UI-001 |
| `bridge.gleam` | CEPAF bridge view | SC-GLM-UI-001 |
| `config.gleam` | Configuration view | SC-GLM-UI-001 |
| `smriti.gleam` | Smriti knowledge view | SC-GLM-UI-001 |
| `database.gleam` | Database view | SC-GLM-UI-001 |
| `git.gleam` | Git intelligence view | SC-GLM-UI-001 |
| `holon.gleam` | Holon view | SC-GLM-UI-001 |
| `agents.gleam` | Agents view | SC-GLM-UI-001 |
| `prajna.gleam` | Prajna cockpit view | SC-GLM-UI-001 |

##### Wisp (REST API) — `ui/wisp/*.gleam` (14+ modules)
| Module | Purpose | STAMP |
|--------|---------|-------|
| `router.gleam` | HTTP router (port 4100), health endpoint | SC-GLM-UI-001, SC-GLM-UI-003, SC-GLM-UI-006, SC-GLM-UI-007 |
| `cockpit_api.gleam` | Cockpit API | SC-GLM-UI-001, SC-GLM-UI-003, SC-GLM-UI-007 |
| `planning_api.gleam` | Planning API | SC-GLM-UI-001, SC-GLM-UI-003, SC-GLM-UI-007 |
| `planning_routes.gleam` | Planning routes | SC-GLM-UI-001 |
| `immune_api.gleam` | Immune API | SC-GLM-UI-001, SC-GLM-UI-003, SC-GLM-UI-007 |
| `knowledge_api.gleam` | Knowledge/Smriti API | SC-GLM-UI-001, SC-GLM-UI-003, SC-GLM-UI-007 |
| `zenoh_api.gleam` | Zenoh API | SC-GLM-UI-001, SC-GLM-UI-003, SC-GLM-UI-007 |
| `verification_api.gleam` | Verification API | SC-GLM-UI-001, SC-GLM-UI-003, SC-GLM-UI-007 |
| `substrate_api.gleam` | Substrate API | SC-GLM-UI-001, SC-GLM-UI-003, SC-GLM-UI-007 |
| `metabolic_api.gleam` | Metabolic API | SC-GLM-UI-001, SC-GLM-UI-003, SC-GLM-UI-007 |
| `podman_api.gleam` | Podman API | SC-GLM-UI-001, SC-GLM-UI-003, SC-GLM-UI-007 |
| `mcp_api.gleam` | MCP API | SC-GLM-UI-001, SC-GLM-UI-003, SC-GLM-UI-007 |
| `kms_api.gleam` | KMS API | SC-GLM-UI-001, SC-GLM-UI-003, SC-GLM-UI-007 |
| `telemetry_api.gleam` | Telemetry API | SC-GLM-UI-001, SC-GLM-UI-003, SC-GLM-UI-007 |

##### TUI (Terminal) — `ui/tui/*.gleam` (14+ modules)
| Module | Purpose |
|--------|---------|
| `renderer.gleam` | ANSI rendering engine |
| `cockpit_view.gleam` | Cockpit TUI view |
| `planning_view.gleam` | Planning TUI view |
| `planning_dashboard_view.gleam` | Planning dashboard TUI |
| `immune_view.gleam` | Immune TUI view |
| `knowledge_view.gleam` | Knowledge TUI view |
| `zenoh_view.gleam` | Zenoh TUI view |
| `verification_view.gleam` | Verification TUI view |
| `substrate_view.gleam` | Substrate TUI view |
| `metabolic_view.gleam` | Metabolic TUI view |
| `podman_view.gleam` | Podman TUI view |
| `mcp_view.gleam` | MCP TUI view |
| `kms_view.gleam` | KMS TUI view |
| `telemetry_view.gleam` | Telemetry TUI view |
| `smriti_view.gleam` | Smriti TUI view |
| `bridge_view.gleam` | Bridge TUI view |
| `database_view.gleam` | Database TUI view |
| `git_view.gleam` | Git TUI view |
| `config_view.gleam` | Config TUI view |
| `holon_view.gleam` | Holon TUI view |
| `agents_view.gleam` | Agents TUI view |
| `prajna_view.gleam` | Prajna TUI view |

##### Supporting Modules
| Module | Purpose |
|--------|---------|
| `ui/domain.gleam` | Shared types: Page (12 variants), HealthStatus, TelemetryPoint, Action, RenderContext. CANONICAL source — no type duplication (SC-GLM-UI-009). |
| `prajna/dark_cockpit.gleam` | Dark Cockpit state machine: CockpitMode (Dark/Dim/NormalMode/Bright/EmergencyMode), AlertSeverity, Alert, CockpitState. `determine_mode()` auto-derives mode from unacknowledged alert severity counts. |
| `cockpit/visuals.gleam` | ANSI color rendering (`with_color`), progress bars (`render_progress_bar` with color thresholds), sparklines (`render_sparkline` with Unicode block characters). |
| `cockpit/domain.gleam` | Cockpit domain types |
| `agui/sse.gleam` | Server-Sent Events for AG-UI streaming (SC-GLM-CORE-001, SC-GLM-CORE-002, SC-GLM-UI-001) |
| `agui/events.gleam` | AG-UI event types (STATE_DELTA, TOOL_CALL, STEP_STARTED/FINISHED) |
| `agui/zenoh_bus.gleam` | Zenoh PubSub to SSE bridge |

#### `lib/indrajaal_gleam_web/` — Web Frontend (gleam.toml)
- **Name**: `indrajaal_gleam_web` v1.0.0
- **Dependencies**: `gleam_stdlib >= 0.44.0`, `mist >= 6.0.0`, `lustre >= 5.6.0`, `gleam_http >= 4.3.0`, `gleam_erlang >= 1.3.0`, `gleam_otp >= 1.2.0`, `gleam_json >= 3.1.0`, `cepaf_gleam = { path = "../cepaf_gleam" }`
- **Source files**: `src/indrajaal_gleam_web.gleam` (entry point), `src/indrajaal_gleam_web/types.gleam` (web-specific types)

### 3.5 Design Documents

| Document | Path | Summary |
|----------|------|---------|
| **PLANNING_WEBUI_DESIGN.md** | `docs/PLANNING_WEBUI_DESIGN.md` | C3I Planning WebUI — SIL-6 Aligned Design. 8-Panel Dashboard: (1) Task Board (Kanban, drag-drop, AG-UI STATE_DELTA), (2) OODA Cycle Monitor (4-phase ring, <100ms target, sparkline), (3) Safety Kernel (10 constitutional check indicators, threat gauge), (4) Enforcer Shield (5-layer defense rings, violation feed), (5) Graph Verify (interactive SVG, 4-check verification), (6) Orchestration Mesh (7-service mesh, container DFA 14 states), (7) Chaya Twin (5-phase sync, bidirectional status), (8) Startup Optimizer (Gantt chart, CPM metrics, DFA state machine). Fractal Layer Coverage Matrix (L0-L7). FMEA Risk Analysis per panel (RPN 108-210). Design principles: SIL-6 Dark Cockpit + AG-UI Event Streaming + Generative UI (Google A2UI). |

### 3.6 intelitor-v5.2 Assessment

**Location**: `/home/an/dev/ver/c3i/intelitor-v5.2/` (subdirectory INSIDE c3i, not separate repo)

- Has its own `.claude/rules/` directory with 42 rule files — mirrors of c3i rules (identical content: ui-graph-testing.md, fractal-coverage-gold-standard.md, fractal-coverage-mathematical-framework.md, prajna-biomorphic.md, five-level-testing.md, human-intent-protection.md, etc.)
- Has `CLAUDE.md` at root
- Uses the original Elixir/Phoenix LiveView stack (not Gleam)
- No Gleam-specific UI artifacts — relies on the shared c3i Gleam codebase
- Has a Gleam project at `scripts/monitoring/container_monitor/` (monitoring utility, not UI)

---

## 4. Root Cause Analysis

**Why was this inventory needed?**
- Knowledge fragmentation: Web UI guidelines were distributed across 10 rule files, 3 agents, 200+ STAMP constraints with no unified reference
- Technology transition: Moving from Elixir/Phoenix LiveView to Gleam/Lustre requires mapping existing coverage standards to the new stack
- Triple-interface complexity: 67+ source files across 3 rendering interfaces (Lustre/Wisp/TUI) need consistent development guidance
- Testing gap: The mathematical coverage framework (Shannon entropy, CCM, ITQS) was defined for Wallaby/Elixir but needed adaptation for Gleam

---

## 5. Fix Taxonomy

| # | Type | Artifact | Description |
|---|------|----------|-------------|
| 1 | **NEW RULE** | `.claude/rules/gleam-web-ui-development.md` | Consolidated Gleam Web UI development protocol — 16 sections covering triple-interface mandate, STAMP constraints, Dark Cockpit, 8-panel dashboard, Lustre/Wisp/TUI patterns, testing protocol with 8-category coverage, source-first mandate, Human Intent protection, AG-UI SSE, graph-theory testing, file structure, compile commands |
| 2 | **NEW MEMORY** | `memory/gleam-web-ui-inventory.md` | Persistent memory recording the audit results for future sessions |
| 3 | **DOCUMENTATION** | This journal entry | Complete 13-section journal with zero information loss |

---

## 6. Patterns & Anti-Patterns Discovered

### Patterns (Good)
1. **Triple-Interface Consistency**: Every Gleam UI module follows the SC-GLM-UI-001 mandate — Lustre view + Wisp API + TUI view for each domain
2. **Shared Domain Types**: `ui/domain.gleam` is the single source of truth for Page, HealthStatus, TelemetryPoint, Action, RenderContext (SC-GLM-UI-009)
3. **Mathematical Coverage**: Information-theoretic quality gates (Shannon entropy, ITQS) provide objective, reproducible coverage measurement
4. **Dark Cockpit State Machine**: `prajna/dark_cockpit.gleam` implements proper ADT-based state machine with automatic mode derivation
5. **Module Contract Headers**: Every .gleam file has C3I-SIL6-MSTS XML metadata documenting fractal layer, F# lineage, and STAMP controls

### Anti-Patterns (Risks)
1. **Scattered Guidelines**: Before this audit, a developer would need to read 10+ rule files to understand Web UI requirements
2. **Framework Gap**: Mathematical coverage framework (Shannon entropy, ITQS) was formalized for Wallaby/Elixir but had no explicit Gleam adaptation document
3. **intelitor Mirror**: 42 rule files duplicated between c3i and intelitor-v5.2 creates maintenance burden if they diverge

---

## 7. Verification Matrix

| Check | Status | Evidence |
|-------|--------|----------|
| All 41 c3i rules scanned | PASS | Glob returned 41 files, 10 identified as UI-relevant |
| All 27 agents scanned | PASS | Glob returned 27 files, 3 identified as UI-relevant |
| Gleam source files counted | PASS | 67+ files across ui/lustre, ui/wisp, ui/tui |
| gleam.toml dependencies verified | PASS | Both cepaf_gleam and indrajaal_gleam_web read and documented |
| Dark Cockpit implementation verified | PASS | prajna/dark_cockpit.gleam read — 5 modes, alert-driven |
| Shared types canonical source verified | PASS | ui/domain.gleam has 12 Page variants, all types documented |
| Design document found | PASS | docs/PLANNING_WEBUI_DESIGN.md — 8-panel design |
| intelitor-v5.2 located | PASS | Inside c3i at intelitor-v5.2/, 42 mirrored rules |
| Consolidated rule created | PASS | .claude/rules/gleam-web-ui-development.md written |
| Memory saved | PASS | memory/gleam-web-ui-inventory.md written |
| STAMP constraint census | PASS | 230+ UI-relevant constraints across 25+ families |

---

## 8. Files Modified

| Action | File | Description |
|--------|------|-------------|
| CREATED | `.claude/rules/gleam-web-ui-development.md` | Consolidated Gleam Web UI development and testing protocol (SC-GLM-UI) |
| CREATED | `docs/journal/20260403-1200-web-gui-artifact-inventory-gleam-ui-prompt.md` | This journal entry |
| CREATED | `~/.claude/projects/-home-an-dev-ver-c3i/memory/MEMORY.md` | Memory index |
| CREATED | `~/.claude/projects/-home-an-dev-ver-c3i/memory/gleam-web-ui-inventory.md` | Persistent audit memory |

---

## 9. Architectural Observations

### 9.1 Triple-Interface as Isomorphic Functor
The Gleam triple-interface architecture (Lustre/Wisp/TUI) is structurally isomorphic to the F# triple-interface (Bolero/API/Console). Each UI capability maps through a natural transformation:
```
F: Domain -> Lustre(Html)  (Web rendering)
G: Domain -> Wisp(Json)   (API serialization)
H: Domain -> Tui(Ansi)    (Terminal rendering)
```
The shared `ui/domain.gleam` types ensure `F`, `G`, `H` all operate on the same algebraic data types.

### 9.2 Coverage Framework Portability
The mathematical coverage framework (Shannon entropy, CCM, ITQS) is framework-agnostic. While originally designed for Wallaby/Elixir, the formulas operate on test feature counts per category — applicable to any test framework. For Gleam:
- C1-C8 categories map to Lustre view assertions
- Shannon entropy computed from gleeunit test distribution
- Source-first mandate applies to .gleam files instead of .ex files

### 9.3 AG-UI as Fourth Interface
The `agui/` module (SSE, events, zenoh_bus) effectively constitutes a fourth interface: real-time event streaming. It's not a rendering interface but a data-push channel that feeds all three rendering interfaces.

### 9.4 intelitor-v5.2 Dependency
intelitor-v5.2 lives inside c3i and shares the same Gleam libraries. Its 42 mirrored `.claude/rules/` files suggest it was forked from c3i's rule set. Future rule changes should propagate to both locations or the mirroring should be automated.

---

## 10. Remaining Gaps

| # | Gap | Priority | Mitigation |
|---|-----|----------|------------|
| 1 | No Gleam-specific E2E browser test framework (Wallaby is Elixir-only) | P1 | Use Wallaby via Elixir test harness calling Gleam Wisp endpoints, or adopt Playwright via external process |
| 2 | SC-GLM-UI constraints not yet in CLAUDE.md STAMP section (only in code) | P2 | Add SC-GLM-UI-001..010 to CLAUDE.md per SC-SYNC-DOC-009 |
| 3 | No ITQS audit task for Gleam tests (only `lib/mix/tasks/wallaby_coverage_audit.ex` exists) | P2 | Create `gleam_coverage_audit` task or extend existing |
| 4 | intelitor-v5.2 rule file duplication creates drift risk | P3 | Automate sync or use symlinks |
| 5 | `docs/PLANNING_WEBUI_DESIGN.md` panel specs only cover Planning — other cockpit domains not yet designed | P2 | Extend design doc to cover all 12 Page variants |
| 6 | GEMINI.md and AGENTS.md were not found to have UI-specific sections distinct from CLAUDE.md | P3 | Verify and document if needed |

---

## 11. Metrics Summary

| Metric | Value |
|--------|-------|
| Rule files scanned (c3i) | 41 |
| Rule files scanned (intelitor-v5.2) | 42 |
| UI-relevant rules identified | 10 |
| Agent definitions scanned | 27 |
| UI-relevant agents identified | 3 |
| UI STAMP constraint families | 25+ |
| UI STAMP constraints total | ~230+ |
| Gleam UI source files | 67+ |
| Lustre components | 22 |
| Wisp API modules | 14+ |
| TUI view modules | 22 |
| Supporting modules (domain, dark_cockpit, visuals, agui) | 7 |
| Gleam projects | 2 (cepaf_gleam, indrajaal_gleam_web) |
| Design documents found | 1 (PLANNING_WEBUI_DESIGN.md) |
| Files created | 4 (rule, journal, 2 memory files) |
| Audit duration | ~15 minutes |

---

## 12. STAMP & Constitutional Alignment

| Constraint | Compliance |
|------------|-----------|
| SC-SYNC-DOC-001 | PARTIAL — SC-GLM-UI constraints in code but not yet in CLAUDE.md |
| SC-SYNC-DOC-009 | ADDRESSED — new rule file documents all SC-GLM-UI constraints |
| SC-INST-001 | COMPLIANT — journal follows 13-section template |
| AOR-JOURNAL-001 | COMPLIANT — all sections present |
| SC-FUNC-001 | N/A — no code changes, documentation only |
| SC-HINT-004 | RESPECTED — no Human-Specified Intent sections were modified |
| SC-COV-021 | ENHANCED — consolidated rule provides guidance for Gleam adaptation |
| SC-GLM-UI-001 | DOCUMENTED — triple-interface mandate captured in consolidated rule |

---

## 13. Conclusion

A comprehensive audit of Web GUI artifacts across c3i and intelitor-v5.2 was completed,
identifying 10 relevant rules, 3 agents, 230+ STAMP constraints, and 67+ Gleam source files
implementing a triple-interface architecture (Lustre Web SSR + Wisp JSON API + TUI Terminal).

The consolidated rule `.claude/rules/gleam-web-ui-development.md` provides a single reference
for all Gleam Web UI development, including architecture patterns, STAMP constraints, testing
protocols with mathematical quality gates, and the Dark Cockpit progressive disclosure pattern.

Key deliverables:
1. **Consolidated rule file** — ready for immediate use in c3isystem development
2. **Development prompt** — embedded in the rule file, sections 5-8
3. **Complete inventory** — this journal entry preserves all findings with zero information loss
4. **Remaining gaps identified** — 6 items for future work, prioritized P1-P3
