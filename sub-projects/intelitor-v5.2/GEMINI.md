# GEMINI.md — Indrajaal c3i Multi-Language System Spec (Root)
**Version**: 21.5.0-GLM | **Status**: ACTIVE | **Primary Language**: Gleam (BEAM) | **Date**: 2026-04-03

## Language Architecture
| Language | Role | Build Command | Constraint |
|:---|:---|:---|:---|
| **Gleam** | Primary c3i language — all new logic | `gleam build` / `gleam test` / `gleam format` | SC-GLM-CMP-001 to SC-GLM-CMP-005 |
| **Rust** | NIF boundary only (Zenoh FFI) | `cargo build --release` / `cargo test` | SC-NIF-001 to SC-NIF-006, SC-GLM-NIF-001 to SC-GLM-NIF-005 |
| **Elixir** | Web portal (Phoenix LiveView, OTP) | `mix compile --jobs 16` / `mix test` | SC-ENV-COMPILE-001 to SC-ENV-COMPILE-008 |
| **F#** | Legacy bridge/cognitive (Phase 6 substrate) | `dotnet build` / `dotnet test` | SC-FSH-003 to SC-FSH-122 |

## Build Order (AOR-BUILD-001)
```
Rust NIFs → Gleam → Elixir → F# (if needed)
```

### Category G: Architectural Oversight and Assertion (AOR) (NEW)
| ID | Constraint | Verification |
|----|-----------|--------------|
| AOR-ARCH-001 | Gleam is the primary language for all new c3i system logic, ensuring code consistency and maintainability. | Code reviews, static analysis tools |
| AOR-NIF-001 | Rust NIFs must have a clearly defined interface contract with Gleam, minimizing risk of runtime errors and unsafety. | Interface documentation, property testing |
| AOR-POLYGLOT-001 | Language boundaries (Gleam-Rust, Gleam-Elixir, Gleam-F#) must be explicitly documented and tested for interoperability. | Architectural diagrams, integration tests |
| AOR-BUILD-002 | The build order MUST be strictly followed to ensure correct compilation dependencies across all languages. | CI script validation |
| AOR-TOOL-001 | Root-level tools (`sa-up`, `sa-gleam`, `sa-plan`) are the authoritative interfaces for mesh and task management. | Functional verification |
| AOR-TOOL-003 | ALL updates to task status and `PROJECT_TODOLIST.md` MUST be performed via `sa-plan`. Manual edits are FORBIDDEN. | Audit log check |
| AOR-TOOL-002 | `sa-gleam` must maintain a 2-tier fallback (NIF -> CLI) for all critical data operations (SQLite, Podman). | Resilience testing |

## Canonical GEMINI.md Location
Full spec: `dev/ver/c3i/GEMINI.md` (v21.6.0-GLM)

---

### Category N: Zenoh-MCP-OTel Fractal Backplane (ZMOF) (NEW)
**Mandate**: SC-ZMOF-001 — Zenoh is the SOLE transport for internal mesh communication, observability (OTel), and AI tool calls (MCP).

| ID | Constraint | Verification |
|----|-----------|--------------|
| SC-ZMOF-001 | All L0-L7 communication MUST follow the `indrajaal/{layer}/{domain}/...` namespace | Zenoh key audit |
| SC-ZMOF-002 | OTel Spans MUST be published as Zenoh messages to `indrajaal/otel/span/...` | Span audit log |
| SC-ZMOF-003 | MCP Tool Calls MUST ride over Zenoh Pub/Sub (MoZ Protocol) | Tool execution trace |
| SC-ZMOF-004 | Point-to-point HTTP/gRPC for internal control is PROHIBITED | Network traffic audit |
| SC-ZMOF-005 | Every `sa-up` action MUST be exposed as an MCP tool via Zenoh | Agent tool discovery |
| SC-ZMOF-006 | 2oo3 voting (L2) MUST be performed via Zenoh broadcast | Consensus audit |

---

### Category D: Compilation Safety (SC-CMP-025 to SC-CMP-035)
| ID | Constraint | Verification |
|----|-----------|--------------|
| SC-CMP-025 | System SHALL prevent compilation with ANY warnings | --warnings-as-errors for Gleam (primary for c3i) and Elixir, -D warnings for Rust NIFs, /warnaserror for F# |
| SC-CMP-026 | System SHALL ensure complete file compilation for the C3I system (prioritizing Gleam and Rust for NIFs), while supporting Elixir and F# | `gleam build`, `cargo build --release`, `mix compile --jobs 16`, `dotnet build` |
| SC-CMP-027 | System SHALL maintain compilation determinism | Reproducibility check — Gleam BEAM output deterministic |
| SC-CMP-028 | System SHALL prevent compilation interruption | Process monitoring |
| SC-CMP-029 | System SHALL validate syntax correctness | Pre-compilation: `gleam check` (fast type-check gate) |
| SC-CMP-030 | System SHALL ensure dependency resolution | `gleam deps download`, `mix deps.get`, `cargo fetch` |
| SC-CMP-031 | System SHALL prevent compilation environment drift | `devenv.nix` canonical, `gleam.toml` pinned |
| SC-CMP-032 | System SHALL maintain compilation performance baselines | Performance monitoring — Gleam build < 5s target |
| SC-CMP-033 | System SHALL use appropriate parallelization flags | Elixir: `--jobs 16`, `+S 16:16`; Gleam: BEAM-native; Rust: `-j 16` |
| SC-CMP-034 | System SHALL ensure language-specific tooling is available in container | `gleam`, `rustc`, `elixir`, `dotnet` in `devenv.nix` |
| SC-CMP-035 | System SHALL ensure NIFs for Rust are correctly compiled and linked | `priv/native/libzenoh_ffi.so` verified before BEAM boot |

### Category E: Gleam-Specific Safety (SC-GLM-CMP-001 to SC-GLM-CMP-005, NEW)
| ID | Constraint | Verification |
|----|-----------|--------------|
| SC-GLM-CMP-001 | `gleam build` MUST produce zero warnings and zero errors | CI gate + pre-commit |
| SC-GLM-CMP-002 | `gleam format` MUST pass before any Gleam commit | Pre-commit hook |
| SC-GLM-CMP-003 | `gleam check` MUST pass as pre-commit fast gate | Type-check without full build |
| SC-GLM-CMP-004 | Gleam modules MUST compile to BEAM bytecode (not JS) | `target = "erlang"` in `gleam.toml` |
| SC-GLM-CMP-005 | Gleam-Elixir FFI boundary MUST use typed OTP message passing | Code review + property test |

### Category F: Migration Safety (SC-GLM-MIG-001 to SC-GLM-MIG-005, NEW)
| ID | Constraint | Verification |
|----|-----------|--------------|
| SC-GLM-MIG-001 | F# and Gleam enforcers MUST dual-run during Phases 1-2 | Runtime check |
| SC-GLM-MIG-002 | Semantic drift < 5% between F# and Gleam | Property test comparison |
| SC-GLM-MIG-003 | F# modules NOT deleted until Gleam passes all TDG tests | Pre-deletion gate |
| SC-GLM-MIG-004 | Container substrate remains F# until cognitive layers verified | Phase 6 gate |
| SC-GLM-MIG-005 | Migration progress tracked in `docs/plans/` with timestamps | Audit check |

### Category H: State Management and Transition Protocol (STAMP) (NEW)
| ID | Constraint | Verification |
|----|-----------|--------------|
| STAMP-STATE-001 | All system states, especially those involving Gleam and Rust components, MUST be deterministic and auditable. | Runtime verification, state replayability |
| STAMP-CONCUR-001 | Concurrent access to shared state across language boundaries must be managed via thread-safe mechanisms or explicit locking. | Concurrency testing, lock analysis |
| STAMP-PERSIST-001 | Persistent state (e.g., database, file system) MUST be handled with robust transactionality and recovery mechanisms. | Transaction integrity checks, disaster recovery drills |

### Category I: Failure Mode and Error Analysis (FEMA) (NEW)
| ID | Constraint | Verification |
|----|-----------|--------------|
| FEMA-ERROR-001 | Comprehensive error handling and fault tolerance are MANDATORY for all system components, regardless of language. | Code review, fault injection testing |
| FEMA-NIF-001 | Rust NIFs MUST include explicit error propagation and robust safety checks to prevent memory unsafety. | Fuzz testing, static analysis for memory safety |
| FEMA-LOGGING-001 | Detailed logging and diagnostics must be implemented to facilitate rapid analysis of failure modes. | Log analysis tools, automated log validation |

### Category J: Skills and Agent Integration (NEW)
| ID | Constraint | Verification |
|----|-----------|--------------|
| AGENT-SKILL-001 | Gemini CLI will leverage specialized skills for Gleam (`gleam-expert`) and Rust NIF development (`skill-creator` if needed). | Skill activation logs, agent task reports |
| AGENT-PROTO-001 | All agent operations MUST adhere to the Active State Synchronization Protocol (ASSP) and relevant GEMINI/CLAUDE protocols for traceability. | ASSP compliance checks, journal entries |
| AGENT-LANG-001 | Agents managing code development MUST be configured to use Gleam as primary, Rust for NIFs, and support Elixir/F#. | Agent configuration review |

---

### Category K: Gleam UI Architecture — Penta-Stack (NEW)
**Mandate**: SC-GLM-UI-001 (Triple-Interface) — every UI feature MUST exist in Lustre (web) + Wisp (REST) + TUI (terminal) simultaneously.

| Layer | Technology | Port | Purpose | Constraint |
|:---|:---|:---|:---|:---|
| **Web UI** | Gleam Lustre MVU + SSR | 4100 | Primary browser interface, reactive components, server-driven architecture | SC-GLM-UI-001 |
| **REST API** | Gleam Wisp HTTP + JSON | 4100 | Agent API, JSON serialization, routing | SC-GLM-UI-002 |
| **Terminal UI** | Gleam ANSI renderer + Ratatui bridge | CLI | Headless operations, scriptable interface | SC-GLM-UI-003 |
| **Legacy Web** | Elixir Phoenix LiveView | 4000 | Maintained for backward compatibility only | SC-GLM-UI-004 |
| **Fallback CLI** | F# Prajna console | CLI | Failsafe command-and-control interface | SC-GLM-UI-005 |

**Key**: Gleam Lustre IS the transport for AG-UI events; Wisp handles state endpoints; TUI mirrors capabilities via terminal rendering.

---

### Category L: Gleam UI Constraints (SC-GLM-UI-001 to SC-GLM-UI-010)
| ID | Constraint | Verification |
|----|-----------|--------------|
| SC-GLM-UI-001 | Triple-Interface Mandate: every UI feature must exist in Lustre + Wisp + TUI | Code review + capability matrix |
| SC-GLM-UI-002 | Wisp REST endpoints MUST mirror Lustre event handling semantics | Integration test mapping |
| SC-GLM-UI-003 | TUI commands MUST be generated from shared domain types (ui/domain.gleam) | Type system enforcement |
| SC-GLM-UI-004 | AG-UI events (32 types) MUST route through Lustre server components AND Wisp REST endpoints | Event audit log |
| SC-GLM-UI-005 | A2UI components (16 types) MUST be JSON-declarative, renderable in Lustre/TUI/REST | Component validator |
| SC-GLM-UI-006 | Fractal layers L0-L7 MUST have dedicated widget modules (fractal/*.gleam) | File structure audit |
| SC-GLM-UI-007 | All UI state MUST derive from Zenoh PubSub + SQLite holon state | State lineage verification |
| SC-GLM-UI-008 | Lustre subscriptions MUST map 1:1 to Zenoh key expressions | Mapping audit |
| SC-GLM-UI-009 | Testing MUST achieve C1-C8 gold standard (H ≥ 2.5 bits, CCM ≥ 90%, ITQS ≥ 0.85) per file | Coverage math gates |
| SC-GLM-UI-010 | Human Intent alignment (SC-HINT) ≥ 0.70 for every page spec | Alignment score audit |

---

### Category M: Key Gleam UI Source Files
**Critical module files** for Gleam-first UI development:

| File | Lines | Purpose |
|:---|:---|:---|
| `lib/cepaf_gleam/src/cepaf_gleam/ui/domain.gleam` | ~150 | Shared domain types (Page, HealthStatus, Action, RenderContext) — source of truth for Lustre/Wisp/TUI |
| `lib/cepaf_gleam/src/cepaf_gleam/agui/events.gleam` | ~224 | 32-event EventType ADT (Lifecycle 5 + Text 4 + Tool 5 + State 3 + Activity 2 + Reasoning 7 + Special 4 incl. Heartbeat) |
| `lib/cepaf_gleam/src/cepaf_gleam/agui/protocol.gleam` | ~80 | AG-UI transport layer (Lustre WebSocket, Wisp REST, Zenoh PubSub); AG-UI totals: 5 modules, 1,224 lines |
| `lib/cepaf_gleam/src/cepaf_gleam/ui/lustre/app.gleam` | ~200 | Lustre MVU root (Model, Msg, update, view) with server components; Lustre totals: 24 modules, 3,415 lines |
| `lib/cepaf_gleam/src/cepaf_gleam/ui/wisp/router.gleam` | ~180 | Wisp HTTP routing, JSON endpoints mirroring Lustre events (Wisp 2.2.2); Wisp totals: 14 modules, 2,278 lines |
| `lib/cepaf_gleam/src/cepaf_gleam/ui/tui/renderer.gleam` | ~120 | ANSI terminal renderer, Ratatui FFI bridge; TUI totals: 22 modules, 1,730 lines |
| `lib/cepaf_gleam/src/cepaf_gleam/a2ui/catalog.gleam` | ~655 | A2UI component schema (16 component types, JSON-declarative) — 5 modules: schema, catalog, renderer, bindings, validator; A2UI totals: 5 modules, 655 lines |
| `lib/cepaf_gleam/src/cepaf_gleam/fractal/l0_constitutional.gleam` | ~60 | L0 constitutional widgets (guardian gates, founder directives, psi invariants); SC-HINT required |
| `lib/cepaf_gleam/src/cepaf_gleam/fractal/l1_atomic_debug.gleam` | ~121 | L1 atomic/debug operations (health, debug probes, NIF loaded, Zenoh session) |
| `lib/cepaf_gleam/src/cepaf_gleam/fractal/l2_component.gleam` | ~60 | L2 component lifecycle (GenServer, supervisor visualization) |
| `lib/cepaf_gleam/src/cepaf_gleam/fractal/l3_transaction.gleam` | ~70 | L3 transaction UI (DB pool, migration status, Oban queues) |
| `lib/cepaf_gleam/src/cepaf_gleam/fractal/l4_system.gleam` | ~70 | L4 system status (containers, ports, network, volumes) |
| `lib/cepaf_gleam/src/cepaf_gleam/fractal/l5_cognitive.gleam` | ~80 | L5 cognitive interface (cortex, OODA cycle, AI models) |
| `lib/cepaf_gleam/src/cepaf_gleam/fractal/l6_ecosystem.gleam` | ~75 | L6 mesh visualization (Zenoh routers, quorum, 2oo3 voting) |
| `lib/cepaf_gleam/src/cepaf_gleam/fractal/l7_federation.gleam` | ~75 | L7 federation interface (peer discovery, version vectors, attestation); Fractal totals: 8 modules, 1,107 lines |
| `test/cepaf_gleam/ui/ui_test.gleam` | ~200 | Gold-standard UI test suite (C1-C8 categories, graph theory, prime paths) |
| `test/cepaf_gleam/ui/human_intent_test.gleam` | ~150 | Human Intent alignment tests (Jaccard scoring, SC-HINT verification) |

**Codebase totals** (2026-04-03): 109 Gleam modules, ~21,666 lines across all subsystems — Lustre 24/3,415 + Wisp 14/2,278 + TUI 22/1,730 + AG-UI 5/1,224 + A2UI 5/655 + Fractal 8/1,107 + Testing 3/602 + Verification 4/383 + Test suite 23 files/10,106 lines.

**All files use Gleam-first patterns**: type-safe message passing, immutable state, BEAM concurrency, no JavaScript.