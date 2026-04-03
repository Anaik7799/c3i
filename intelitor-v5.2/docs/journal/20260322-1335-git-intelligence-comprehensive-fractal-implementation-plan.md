# 20260322-1335 — GitIntelligence Comprehensive 10×8 Fractal Implementation Plan

## Context
- Branch: main
- Recent commits: 0bdd03f50, bb0082476, 1358a39a5
- Project: `lib/cepaf/src/Cepaf.GitIntelligence/` — standalone F# CLI (zero ProjectReference to Cepaf)
- Current state: 10 source files, 3,279 lines, Phases 1-2 COMPLETE, Phases 3-5 PENDING
- Plan reference: `/home/an/.claude/plans/bright-orbiting-cupcake.md`

## Summary

Comprehensive criticality-based implementation plan mapping ALL 80 fractal cells (10 Layers × 8 Entities) for the GitIntelligence standalone F# project. Expands the existing 5-phase plan from 70/80 (87.5%) to **80/80 (100%)** coverage by identifying and filling the 10 remaining gaps.

---

## 1.0 The 10-Layer × 8-Entity Fractal Matrix

### 1.1 Fractal Entity Definitions

Each fractal level has 8 entities. For GitIntelligence, these map to:

| Entity | Code | Description | GitIntelligence Mapping |
|--------|------|-------------|------------------------|
| E1 | **Domain Model** | Type definitions, algebraic types, data structures | Records, DUs, type modules |
| E2 | **Input Processing** | Parsing, classification, normalization | Commit parsing, git log processing |
| E3 | **Core Logic** | Analysis, computation, scoring algorithms | GHS, entropy, pattern detection |
| E4 | **State Management** | Persistence, retrieval, state transitions | SQLite (WAL), DuckDB (append-only) |
| E5 | **Communication** | Events, notifications, mesh integration | Zenoh dual-write, topic publishing |
| E6 | **Safety & Validation** | Guards, invariant checks, constitutional | Guardian, Constitutional, immune |
| E7 | **Verification** | Tests, property checks, formal proofs | Expecto tests, FsCheck properties |
| E8 | **Interface** | CLI commands, MCP tools, output formatting | Program.fs dispatch, McpTools.fs |

### 1.2 Status Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | DONE — Implemented and build-verified |
| 🔵 | P1-DONE — Completed in Phase 1 (Foundation) |
| 🟣 | P2-DONE — Completed in Phase 2 (Safety) |
| 🟡 | PLANNED — Scheduled in Phases 3-5 |
| 🔴 | GAP — Not in original plan, NEW addition for 100% |
| ⬛ | BASELINE — Existed before expansion |

---

## 2.0 Complete 80-Cell Matrix

### L0: Runtime — "The system compiles and boots without error"

| Cell | Entity | Status | Implementation | STAMP |
|------|--------|--------|---------------|-------|
| L0-E1 | Domain Model | ⬛ | Types.fs (316L) + Bio.fs (219L) compile cleanly | SC-FUNC-001 |
| L0-E2 | Input Processing | ⬛ | Parser.fs (514L) compiles, regex engine loads | SC-FUNC-001 |
| L0-E3 | Core Logic | ⬛ | Analysis.fs (356L) compiles, math functions available | SC-FUNC-001 |
| L0-E4 | State Management | 🔵 | Store.fs (294L) + History.fs (244L) + NuGets resolve (Microsoft.Data.Sqlite 10.0.0, DuckDB.NET.Data 1.3.0) | SC-FUNC-001 |
| L0-E5 | Communication | ⬛ | Notify.fs (254L) compiles, ZenohFfi DllImport resolves at build time | SC-FUNC-001, SC-FFI-001 |
| L0-E6 | Safety | 🟣 | Guardian.fs (158L) + Constitutional.fs (224L) compile | SC-FUNC-001 |
| L0-E7 | Verification | ⬛ | Cepaf.Tests project references and compiles GitIntelligence | SC-FUNC-001 |
| L0-E8 | Interface | ⬛ | Program.fs (700L) compiles as `<OutputType>Exe</OutputType>` | SC-FUNC-001 |

**Score: 8/8 (100%)** — All cells satisfied by successful `dotnet build`

---

### L1: Function — "I/O contracts are valid"

| Cell | Entity | Status | Implementation | STAMP |
|------|--------|--------|---------------|-------|
| L1-E1 | Domain Model | ⬛ | `ParsedCommit`, `ValidationResult`, `CommitType` (9 cases), `IcpScope` (23 cases) — all F# records/DUs with correct field types | SC-FSH-012 |
| L1-E2 | Input Processing | ⬛ | `Parser.parseCommit: string -> ParsedCommit` — pure function, regex-based, returns typed result | SC-FSH-070 |
| L1-E3 | Core Logic | ⬛ | `Analysis.computeGhs: ParsedCommit list -> float` — bounded [0.0, 1.0], weighted composite | SC-FSH-017 |
| L1-E4 | State Management | 🔵 | `Store.recordCommit`, `Store.getLatestHealth`, `History.appendEvent`, `History.queryTrend` — typed SQLite/DuckDB I/O | SC-XHOLON-020 |
| L1-E5 | Communication | 🔵 | 14 `Notify.publish*` functions with typed parameters → JSON payload → dual-write (eprintfn + zenohPublish) | SC-ZTEST-008 |
| L1-E6 | Safety | 🟣 | `Guardian.validateProposal: Proposal -> ApprovalResult`, `Constitutional.verifyAll: ... -> ConstitutionalCheck list` | SC-SAFETY-001 |
| L1-E7 | Verification | ⬛ | 77 Expecto unit tests validating Parser/Analysis I/O contracts | SC-FSH-030 |
| L1-E8 | Interface | 🟡 P3 | **GAP**: Biomorphic CLI commands not yet dispatched. Phase 3 `BiomorphicOrchestrator.fs` provides `runFullAssessment` function. Phase 5 wires 8 new CLI commands. | SC-FSH-017 |

**Score: 7/8 (87.5%)** → **8/8 after Phase 3+5**

---

### L2: Component — "Modules are cohesive"

| Cell | Entity | Status | Implementation | STAMP |
|------|--------|--------|---------------|-------|
| L2-E1 | Domain Model | ⬛ | Types.fs + Bio.fs form cohesive type layer. Types imported by all downstream modules. | SC-FSH-003 |
| L2-E2 | Input Processing | ⬛ | Parser.fs is self-contained (only depends on Types.fs). Single responsibility: git log → ParsedCommit. | — |
| L2-E3 | Core Logic | ⬛ | Analysis.fs depends on Types.fs only. Single responsibility: ParsedCommit list → GHS metrics. | — |
| L2-E4 | State Management | 🔵 | Store.fs (SQLite) + History.fs (DuckDB) have clear boundary: real-time state vs evolution log. | AOR-HOLON-001 |
| L2-E5 | Communication | 🔵 | Notify.fs is self-contained (own ZenohFfi module, no external deps). 14 topics. | SC-ZENOH-001 |
| L2-E6 | Safety | 🟡 P3 | **PLANNED**: BiomorphicOrchestrator.fs will coordinate 5 subsystems (Immune+Neural+Homeostatic+Regenerative+Symbiotic) into cohesive safety assessment. | SC-ORCH-001 |
| L2-E7 | Verification | 🟡 P3 | **PLANNED**: 4 new test files (StoreTests, SafetyTests, AdvancedTests, BiomorphicTests) create cohesive test modules per subsystem. | SC-COV-001 |
| L2-E8 | Interface | 🟡 P4 | **PLANNED**: McpTools.fs provides cohesive MCP interface (5 tools) parallel to CLI. Component-level integration. | SC-MCP |

**Score: 5/8 (62.5%)** → **8/8 after Phases 3+4**

---

### L3: Holon — "Holon state sovereignty (SQLite + DuckDB)"

| Cell | Entity | Status | Implementation | STAMP |
|------|--------|--------|---------------|-------|
| L3-E1 | Domain Model | 🔵 | `HolonCommitRecord`, `EvolutionEvent`, `ConstitutionalCheck`, `FederationPeer`, `MultiverseUniverse` in Bio.fs | AOR-HOLON-001 |
| L3-E2 | Input Processing | 🔴 NEW | **GAP → NEW**: `Store.normalizeAndIngest` — holon-level commit ingestion pipeline. Normalizes raw git output into `HolonCommitRecord` before SQLite insert. ~30 lines added to Store.fs. | SC-XHOLON-001 |
| L3-E3 | Core Logic | 🔵 | Store.fs CRUD + History.fs append-only logic. `recordCommit`, `recordHealthSnapshot`, `appendEvent`, `queryTrend`, `computeVelocity`. | AOR-HOLON-009 |
| L3-E4 | State Management | 🔵 | `data/holons/git-intel/state.sqlite` (WAL, busy_timeout=5000) + `data/holons/git-intel/history.duckdb` (append-only per SC-SMRITI-142). Manifest: `manifest.json` with UHI `fsharp.l3.git.001`. | SC-DBNAME-001, Ω₇ |
| L3-E5 | Communication | 🔵 | `Notify.publishConstitutionalEvent`, `publishMultiverseEvent`, `publishFederationEvent` — holon lifecycle events on Zenoh. | SC-ZENOH-001 |
| L3-E6 | Safety | 🟣 | `Constitutional.verifyRegeneration(sqliteExists, duckdbExists)` — checks holon DB existence. Score 0.0-1.0. | SC-SAFETY-010 |
| L3-E7 | Verification | 🟡 P3 | **PLANNED**: StoreTests.fs (~30 tests) — SQLite WAL, DuckDB append-only, commit recording, health snapshot, event lineage. | SC-UTLTS-001 |
| L3-E8 | Interface | 🟡 P5 | **PLANNED**: `store-init` CLI command (Phase 5) — creates holon directory + initializes SQLite + DuckDB + manifest. | — |

**Score: 5/8 (62.5%)** → **8/8 after Phases 3+5 + NEW L3-E2**

---

### L4: Container — "Isolation is maintained"

| Cell | Entity | Status | Implementation | STAMP |
|------|--------|--------|---------------|-------|
| L4-E1 | Domain Model | ⬛ | Types are isolated within `Cepaf.GitIntelligence` namespace. No `ProjectReference` to Cepaf — fully standalone container. | SC-CNT-009 |
| L4-E2 | Input Processing | ⬛ | Parser.fs reads from stdin/pipe — container-isolated I/O. `git log --format` subprocess call. | — |
| L4-E3 | Core Logic | ⬛ | Analysis.fs pure functions — no external state dependency. Container-portable. | — |
| L4-E4 | State Management | 🔵 | SQLite/DuckDB files in `data/holons/git-intel/` — container-scoped. Files portable via copy. | AOR-HOLON-003 |
| L4-E5 | Communication | ⬛ | Zenoh connects to `tcp/127.0.0.1:7447` — container-network isolated. Fails gracefully if unreachable. | SC-ZTEST-008 |
| L4-E6 | Safety | ⬛ | Guardian.fs self-contained — no external process dependency. L6 artifact list hardcoded. | SC-PRIME-001 |
| L4-E7 | Verification | 🟡 P3 | **PLANNED**: Immune.fs sliding-window analysis operates within container memory. Homeostasis.fs PID state container-isolated. | SC-BIO-EXT-001 |
| L4-E8 | Interface | 🟡 P3 | **PLANNED**: BiomorphicOrchestrator.fs `formatBiomorphicDashboard` — container-isolated ANSI rendering. | — |

**Score: 6/8 (75%)** → **8/8 after Phase 3**

---

### L5: Node — "Runtime environment is stable"

| Cell | Entity | Status | Implementation | STAMP |
|------|--------|--------|---------------|-------|
| L5-E1 | Domain Model | ⬛ | net10.0 target framework, .NET runtime stable. NuGet packages pinned. | SC-NET-001 |
| L5-E2 | Input Processing | ⬛ | `git log` subprocess — depends on git binary being available on node. | — |
| L5-E3 | Core Logic | ⬛ | Pure F# — no native deps except Zenoh FFI (graceful fallback). | — |
| L5-E4 | State Management | ⬛ | SQLite + DuckDB native libraries via NuGet — node-level deps. WAL mode for concurrent access. | SC-UTLTS-001 |
| L5-E5 | Communication | ⬛ | `libzenoh_ffi.so` node-level dependency. LD_LIBRARY_PATH required. Graceful `DllNotFoundException` fallback. | SC-FFI-001 |
| L5-E6 | Safety | ⬛ | Guardian.fs checks are pure — no node-level safety concerns. | — |
| L5-E7 | Verification | 🟡 P3 | **PLANNED**: Trend.fs `computeGhsTrend` + `detectRegression` — node-level time-series stability monitoring. | — |
| L5-E8 | Interface | 🟡 P3 | **PLANNED**: Homeostasis.fs `generateGuidance` — node-level PID controller recommendations. | SC-BIO-EXT-009 |

**Score: 6/8 (75%)** → **8/8 after Phase 3**

---

### L6: Cluster — "Consensus holds"

| Cell | Entity | Status | Implementation | STAMP |
|------|--------|--------|---------------|-------|
| L6-E1 | Domain Model | ⬛ | `FederationPeer` type defines cluster peer identity. | — |
| L6-E2 | Input Processing | ⬛ | Notify.fs Zenoh session management — cluster-level pub/sub. | SC-ZENOH-001 |
| L6-E3 | Core Logic | ⬛ | 14 publish functions broadcast to cluster-wide topics. Any subscriber can consume. | — |
| L6-E4 | State Management | ⬛ | Health snapshots broadcast via `publishHealthEvent` — cluster-observable state. | — |
| L6-E5 | Communication | ⬛ | Full Zenoh dual-write: `eprintfn` (log) + `zenohPublish` (mesh). 14 topics on `indrajaal/git/**`. | SC-ZTEST-008 |
| L6-E6 | Safety | ⬛ | Constitutional check results broadcast via `publishConstitutionalEvent` — cluster-visible safety. | SC-SAFETY-009 |
| L6-E7 | Verification | ⬛ | Threat events broadcast via `publishThreatEvent` — cluster-level immune signaling. | SC-IMMUNE-001 |
| L6-E8 | Interface | 🔵 | Biomorphic assessment broadcast via `publishBiomorphicEvent` — cluster dashboard feed. Phase 1 enrichment. | — |

**Score: 8/8 (100%)** — Fully covered by Phase 1 Notify.fs enrichment

---

### L7: Federation — "Global invariants hold across holons"

| Cell | Entity | Status | Implementation | STAMP |
|------|--------|--------|---------------|-------|
| L7-E1 | Domain Model | 🔵 | `FederationPeer` type in Bio.fs: `PeerId`, `PeerGhs`, `ProtocolVersion`, `Attested`, `LastSeen`. | SC-FED-006 |
| L7-E2 | Input Processing | 🟡 P4 | **PLANNED**: Federation.fs `discoverPeers` — Zenoh queryable at `indrajaal/git/federation/discover`. Ingest peer GHS. | SC-FED-005 |
| L7-E3 | Core Logic | 🟡 P4 | **PLANNED**: Federation.fs `syncHealth` — exchange GHS, compute aggregate. `negotiateProtocol` — version negotiation. | SC-FED-001 |
| L7-E4 | State Management | 🔴 NEW | **GAP → NEW**: Federation peer registry in SQLite. `Store.recordFederationPeer(peerId, ghs, protocolVersion)`. ~40 lines added to Store.fs. Peer TTL expiry. | SC-XHOLON-003 |
| L7-E5 | Communication | 🟡 P4 | **PLANNED**: Federation.fs events on `indrajaal/git/federation/{peer}/health`. `Notify.publishFederationEvent` already exists. | SC-FED-006 |
| L7-E6 | Safety | 🟡 P4 | **PLANNED**: Federation.fs `attestPeer` — Ed25519-based attestation of peer identity. Reject unattested peers. | SC-FED-006 |
| L7-E7 | Verification | 🔴 NEW | **GAP → NEW**: FederationTests.fs (~15 tests) — peer discovery, GHS exchange, protocol negotiation, attestation, TTL expiry. | SC-FSH-030 |
| L7-E8 | Interface | 🟡 P5 | **PLANNED**: `federation` CLI command — `federation list`, `federation sync`, `federation attest`. | — |

**Score: 1/8 (12.5%)** → **8/8 after Phases 4+5 + NEW L7-E4, L7-E7**

---

### L8: Constitutional — "Ψ₀-Ψ₅ invariants verified"

| Cell | Entity | Status | Implementation | STAMP |
|------|--------|--------|---------------|-------|
| L8-E1 | Domain Model | 🔵 | `ConstitutionalCheck` record in Bio.fs: `InvariantId`, `InvariantName`, `Passed`, `Score`, `Details`. | SC-CONST-001 |
| L8-E2 | Input Processing | 🟣 | Constitutional.fs ingests system state metrics (commit age, DB existence, GHS, ICP adoption, semantic density). | SC-SAFETY-009 |
| L8-E3 | Core Logic | 🟣 | 6 invariant verifiers: `verifyExistence`(Ψ₀), `verifyRegeneration`(Ψ₁), `verifyHistory`(Ψ₂), `verifyVerification`(Ψ₃), `verifyAlignment`(Ψ₄), `verifyTruthfulness`(Ψ₅). Weighted composite: 25/20/15/15/15/10%. | SC-SAFETY-009–015 |
| L8-E4 | State Management | 🟣 | Constitutional check results publishable and storable. `verifyNoForbiddenModification` uses Guardian.containsL6Artifacts. | SC-PRIME-001 |
| L8-E5 | Communication | 🔵 | `Notify.publishConstitutionalEvent(invariantId, passed, score, details)` — per-invariant Zenoh broadcast. | SC-ZENOH-001 |
| L8-E6 | Safety | 🟣 | Guardian.fs: `validateCommit` blocks L6 artifacts (SC-PRIME-001), `validateBranchOp` blocks force-push on protected branches, `wrapWithGuardian` higher-order safety wrapper. | SC-SAFETY-001, SC-PRIME-001/002 |
| L8-E7 | Verification | 🟡 P3 | **PLANNED**: SafetyTests.fs (~25 tests) — Guardian veto/approve, Constitutional invariant scoring, L6 protection, branch safety. | SC-FSH-030 |
| L8-E8 | Interface | 🟡 P5 | **PLANNED**: `constitutional` CLI command — runs all 6 invariant checks, displays formatted dashboard. `--guardian` flag on `commit` command. | — |

**Score: 6/8 (75%)** → **8/8 after Phases 3+5**

---

### L9: Multiverse — "Fork/shadow/promote operations"

| Cell | Entity | Status | Implementation | STAMP |
|------|--------|--------|---------------|-------|
| L9-E1 | Domain Model | 🔵 | `MultiverseUniverse` record in Bio.fs: `UniverseId`, `BranchName`, `ParentSha`, `Created`, `Ghs`, `Status`. | — |
| L9-E2 | Input Processing | 🟡 P5 | **PLANNED**: Multiverse.fs `forkUniverse` — create shadow branch from current HEAD. Ingest shadow branch analysis. | SC-GIT-006 |
| L9-E3 | Core Logic | 🟡 P5 | **PLANNED**: Multiverse.fs `verifyUniverse` — run analysis on shadow branch, compare GHS with main. `promoteUniverse` — merge if GHS improved. `pruneUniverse` — delete expired shadows (24h TTL). | — |
| L9-E4 | State Management | 🔴 NEW | **GAP → NEW**: Multiverse registry in DuckDB. `History.recordMultiverseEvent(action, universeId, branchName, ghs)`. Append-only event log per AOR-HOLON-019. ~30 lines added to History.fs. | AOR-HOLON-019 |
| L9-E5 | Communication | 🔵 | `Notify.publishMultiverseEvent(action, universeId, branchName, ghs)` — already implemented in Phase 1. | SC-ZENOH-001 |
| L9-E6 | Safety | 🟡 P5 | **PLANNED**: Multiverse.fs `promoteUniverse` requires Guardian approval via `Guardian.wrapWithGuardian`. No unattended promotions. | SC-GIT-006 |
| L9-E7 | Verification | 🔴 NEW | **GAP → NEW**: MultiverseTests.fs (~15 tests) — fork creation, GHS comparison, promotion gate, pruning logic, 24h TTL expiry. | SC-FSH-030 |
| L9-E8 | Interface | 🟡 P5 | **PLANNED**: `multiverse` CLI command — `multiverse fork`, `multiverse list`, `multiverse promote`, `multiverse prune`. | — |

**Score: 2/8 (25%)** → **8/8 after Phase 5 + NEW L9-E4, L9-E7**

---

## 3.0 Coverage Summary Matrix

```
         E1     E2     E3     E4     E5     E6     E7     E8     SCORE
L0 Runt  ⬛     ⬛     ⬛     🔵     ⬛     🟣     ⬛     ⬛     8/8 ✓
L1 Func  ⬛     ⬛     ⬛     🔵     🔵     🟣     ⬛     🟡P3   8/8 ✓
L2 Comp  ⬛     ⬛     ⬛     🔵     🔵     🟡P3   🟡P3   🟡P4   8/8 ✓
L3 Holo  🔵     🔴NEW  🔵     🔵     🔵     🟣     🟡P3   🟡P5   8/8 ✓
L4 Cont  ⬛     ⬛     ⬛     🔵     ⬛     ⬛     🟡P3   🟡P3   8/8 ✓
L5 Node  ⬛     ⬛     ⬛     ⬛     ⬛     ⬛     🟡P3   🟡P3   8/8 ✓
L6 Clus  ⬛     ⬛     ⬛     ⬛     ⬛     ⬛     ⬛     🔵     8/8 ✓
L7 Fede  🔵     🟡P4   🟡P4   🔴NEW  🟡P4   🟡P4   🔴NEW  🟡P5   8/8 ✓
L8 Cons  🔵     🟣     🟣     🟣     🔵     🟣     🟡P3   🟡P5   8/8 ✓
L9 Mult  🔵     🟡P5   🟡P5   🔴NEW  🔵     🟡P5   🔴NEW  🟡P5   8/8 ✓
                                                            TOTAL: 80/80
```

### Coverage by Phase

| Phase | Status | Cells Covered | Running Total |
|-------|--------|--------------|---------------|
| Baseline (pre-expansion) | ✅ COMPLETE | 44 cells (⬛) | 44/80 (55.0%) |
| Phase 1: Foundation | ✅ COMPLETE | 14 cells (🔵) | 58/80 (72.5%) |
| Phase 2: Safety | ✅ COMPLETE | 5 cells (🟣) | 63/80 (78.8%) |
| Phase 3: Intelligence | 🟡 PENDING | 9 cells (🟡P3) | 72/80 (90.0%) |
| Phase 4: Integration | 🟡 PENDING | 4 cells (🟡P4) | 76/80 (95.0%) |
| Phase 5: Advanced + NEW gaps | 🟡 PENDING | 4+5=9 cells (🟡P5+🔴) | **80/80 (100%)** |
| **Total** | | **80 cells** | **80/80 (100%)** |

---

## 4.0 Criticality-Based Execution Plan

### 4.1 Execution Order

```
CRITICALITY-BASED EXECUTION PIPELINE

 ┌──────────────────────────────────────────────────────────────────────┐
 │  P0 CRITICAL ─── Phase 1 ✅ + Phase 2 ✅ ── Foundation + Safety     │
 │  ├── Types.fs enrichment (Bio.fs) ─────────── L0/L1/L3 types       │
 │  ├── Store.fs + History.fs ────────────────── L3 holon state        │
 │  ├── Notify.fs enrichment ─────────────────── L6 cluster events     │
 │  ├── Guardian.fs ──────────────────────────── L8 safety gate        │
 │  ├── Constitutional.fs ────────────────────── L8 invariant verify   │
 │  └── manifest.json ────────────────────────── L3 holon identity     │
 │  Status: ✅ ALL COMPLETE (19 cells)                                  │
 ├──────────────────────────────────────────────────────────────────────┤
 │  P1 HIGH ────── Phase 3 ──────────────────── Intelligence           │
 │  ├── Immune.fs (250L) ─────────────────────── L4-E7, L5-E7 pattern │
 │  ├── Neural.fs (200L) ─────────────────────── L1-E8 AI function    │
 │  ├── Homeostasis.fs (230L) ────────────────── L5-E8 PID controller │
 │  ├── Regenerative.fs (180L) ───────────────── L4-E8 vital signs    │
 │  ├── Symbiotic.fs (150L) ──────────────────── L2-E6 alignment      │
 │  ├── Trend.fs (200L) ──────────────────────── L5-E7 regression     │
 │  ├── BiomorphicOrchestrator.fs (280L) ─────── L2-E6 coordination   │
 │  ├── StoreTests.fs (30 tests) ─────────────── L3-E7 holon tests   │
 │  ├── SafetyTests.fs (25 tests) ────────────── L8-E7 safety tests  │
 │  ├── AdvancedTests.fs (25 tests) ──────────── L2-E7 component     │
 │  └── BiomorphicTests.fs (74 tests) ────────── L4-E7 subsystem     │
 │  Cells: 9 (L1-E8, L2-E6, L2-E7, L3-E7, L4-E7, L4-E8, L5-E7,     │
 │          L5-E8, L8-E7)                                              │
 ├──────────────────────────────────────────────────────────────────────┤
 │  P1 HIGH ────── Phase 4 ──────────────────── Integration            │
 │  ├── McpTools.fs (250L) ───────────────────── L2-E8 MCP interface  │
 │  ├── Federation.fs (200L) ─────────────────── L7-E2/E3/E5/E6      │
 │  └── FederationTests.fs (15 tests) ────────── L7-E7 🔴 NEW        │
 │  Cells: 4+1 (L2-E8, L7-E2, L7-E3, L7-E5, L7-E6) + NEW L7-E7     │
 ├──────────────────────────────────────────────────────────────────────┤
 │  P2 MEDIUM ──── Phase 5 ──────────────────── Advanced + Gap Fill   │
 │  ├── Multiverse.fs (200L) ─────────────────── L9-E2/E3/E6         │
 │  ├── Program.fs wiring (+300L) ────────────── L3-E8, L7-E8,       │
 │  │                                             L8-E8, L9-E8        │
 │  ├── Store.fs additions (+40L) ────────────── L7-E4 🔴 NEW        │
 │  ├── Store.fs additions (+30L) ────────────── L3-E2 🔴 NEW        │
 │  ├── History.fs additions (+30L) ──────────── L9-E4 🔴 NEW        │
 │  └── MultiverseTests.fs (15 tests) ────────── L9-E7 🔴 NEW        │
 │  Cells: 4+5 NEW (L3-E2, L3-E8, L7-E4, L7-E8, L8-E8, L9-E2,      │
 │          L9-E3, L9-E4, L9-E6, L9-E7, L9-E8)                       │
 └──────────────────────────────────────────────────────────────────────┘
```

### 4.2 Phase 3: Intelligence (P1 HIGH) — 7 New Files, 4 Test Files

**Goal**: Add all 5 biomorphic subsystems + trend analysis + tests.

#### 3.1 Immune.fs (~250 lines) — Digital Immune System
- 11 git anti-pattern detectors using sliding window analysis
- `scanCommitHistory: ParsedCommit list -> DetectedPattern list` (< 10ms per SC-BIO-EXT-001)
- `assessThreatLevel: DetectedPattern list -> ThreatLevel`
- `calculateImmunityScore: DetectedPattern list -> float` (0.0-1.0)
- Patterns: ScopeCreep, TypeMonoculture, CommitStorm, EntropyCollapse, ConventionDrift, StyleOscillation, OrphanScope, MessageTruncation, MergeFlood, AuthorSiloing, SemanticDilution
- STAMP: SC-IMMUNE-001, SC-IMMUNE-004, SC-BIO-EXT-001

#### 3.2 Neural.fs (~200 lines) — Cortex/Synapse AI
- Wraps existing OpenRouter HTTP client from Program.fs `cmdSuggest`
- `classifyIntent: ParsedCommit -> NeuralRecommendation`
- `assessSemanticQuality: string -> float` (0.0-1.0)
- In-memory cache, heuristic fallback when API unavailable
- STAMP: SC-NEURO-001, AOR-OPENROUTER-001/005

#### 3.3 Homeostasis.fs (~230 lines) — Quality PID Controller
- PID controller: setpoint GHS 0.85, tuning kp=0.5, ki=0.1, kd=0.05
- `assessMode: float -> HomeostaticMode` (Normal/Stressed/Degraded/Critical/Recovery)
- `generateGuidance: HomeostaticMode -> PidState -> string list`
- Integral windup clamped to [-10, 10]
- STAMP: SC-OODA-001 (< 30ms), SC-BIO-EXT-009

#### 3.4 Regenerative.fs (~180 lines) — Self-Healing
- `computeVitalSigns: ParsedCommit list -> float -> VitalSigns`
- `isPathological: VitalSigns -> bool` (HealthIndex < 0.2 || StressIndex > 0.95)
- `diagnose: VitalSigns -> RegenerativeAction list`
- STAMP: SC-BIO-EXT-009, SC-SAFETY-010

#### 3.5 Symbiotic.fs (~150 lines) — Founder's Directive Alignment
- Maps 3 Supreme Goals to git metrics:
  - Goal 1 (Survival): commit velocity, no stagnation
  - Goal 2 (Sentience): AI-assisted ratio, semantic density trend
  - Goal 3 (Power): scope breadth, type diversity
- `assessAlignment -> SymbioticAlignment` (50% Founder, 30% Sentient, 20% Power)
- `validateDirective: SymbioticAlignment -> Result<unit, string>` (Error if any goal < 0.3)
- STAMP: SC-SAFETY-013, SC-SIL6-006

#### 3.6 Trend.fs (~200 lines) — L5 Time-Series Analysis
- `computeGhsTrend: EvolutionEvent list -> float` (EMA over N commits)
- `detectRegression: float list -> bool` (GHS drops >10% from EMA baseline)
- `computeVelocity: EvolutionEvent list -> float` (commits/day)
- `projectTarget: float list -> float -> DateTimeOffset option` (linear regression to 80% GHS)
- Uses `History.queryTrend` for data source

#### 3.7 BiomorphicOrchestrator.fs (~280 lines) — Unified Coordination
- `runFullAssessment: ParsedCommit list -> float -> BiomorphicState`
- `computeOverallHealth: BiomorphicState -> float` (weighted: Immune 25%, Neural 15%, Homeostatic 25%, Regenerative 20%, Symbiotic 15%)
- `shouldHalt: BiomorphicState -> bool` (2oo3 voting: Immune + Homeostatic + Regenerative)
- `formatBiomorphicDashboard: BiomorphicState -> string` (full ANSI dashboard)
- Publishes to `indrajaal/git/biomorphic` via dual-write
- STAMP: SC-ORCH-001, SC-SIL6-006

#### 3.8 Test Files (4 new, ~154 tests)

| File | Tests | Covers |
|------|-------|--------|
| StoreTests.fs | ~30 | Store.fs (SQLite WAL), History.fs (DuckDB append-only) |
| SafetyTests.fs | ~25 | Guardian.fs, Constitutional.fs |
| AdvancedTests.fs | ~25 | Trend.fs, Homeostasis.fs |
| BiomorphicTests.fs | ~74 | Immune (15), Neural (8), Homeostatic (10), Regenerative (8), Symbiotic (8), Orchestrator (10), FsCheck properties (15) |

### 4.3 Phase 4: Integration (P1 HIGH) — 2 New Files + 1 Test File

#### 4.1 McpTools.fs (~250 lines) — L2 Agentic Interface
- 5 MCP tools: `git_intel_analyze`, `git_intel_validate`, `git_intel_health`, `git_intel_suggest`, `git_intel_history`
- Inline minimal MCP protocol types (~30 lines) — standalone architecture
- Mirror dispatch pattern from `SentinelTools.fs`
- Each tool returns JSON via `toolResult`
- STAMP: SC-MCP

#### 4.2 Federation.fs (~200 lines) — L7 Cross-Holon Sync
- `discoverPeers: unit -> FederationPeer list` (Zenoh queryable)
- `syncHealth: FederationPeer list -> float` (aggregate health)
- `negotiateProtocol: FederationPeer -> Result<string, string>` (version negotiation)
- `attestPeer: FederationPeer -> bool` (Ed25519 attestation)
- STAMP: SC-FED-001/006, AOR-FED-001

#### 4.3 FederationTests.fs (~15 tests) — 🔴 NEW (Gap Fill for L7-E7)
- Peer discovery mock tests
- GHS exchange protocol tests
- Protocol version negotiation tests
- Attestation verification tests
- TTL expiry tests
- FsCheck: `forall peerId, peerGhs` property tests

### 4.4 Phase 5: Advanced + Gap Fill (P2 MEDIUM) — 1 New File + 1 Test File + Modifications

#### 5.1 Multiverse.fs (~200 lines) — L9 Fork/Shadow Operations
- `forkUniverse: string -> MultiverseUniverse` (create shadow branch)
- `verifyUniverse: MultiverseUniverse -> float` (GHS on shadow branch)
- `promoteUniverse: MultiverseUniverse -> Result<unit, string>` (Guardian-gated merge)
- `pruneUniverse: MultiverseUniverse -> bool` (delete expired shadows)
- Registry at `data/kms/multiverse_registry.json`
- STAMP: SC-GIT-006

#### 5.2 MultiverseTests.fs (~15 tests) — 🔴 NEW (Gap Fill for L9-E7)
- Fork creation and branch naming
- GHS comparison between universes
- Guardian approval gate for promotion
- 24h TTL pruning logic
- FsCheck: `forall universeId, branchName` property tests

#### 5.3 Store.fs Additions (~70 lines total) — 🔴 NEW (Gap Fill for L3-E2, L7-E4)

```fsharp
// L3-E2: Holon-level ingest pipeline (~30 lines)
let normalizeAndIngest (conn: SqliteConnection) (raw: ParsedCommit) : Result<unit, string> =
    // Normalize raw git data → HolonCommitRecord
    // Insert into commits table with conflict detection
    // Return Ok or Error with validation details

// L7-E4: Federation peer registry (~40 lines)
let recordFederationPeer (conn: SqliteConnection) (peer: FederationPeer) : unit =
    // Upsert peer into federation_peers table
    // Track last_seen, protocol_version, attestation_status
    // TTL-based expiry (remove peers not seen in 24h)
```

New SQLite table for federation:
```sql
CREATE TABLE IF NOT EXISTS federation_peers (
    peer_id TEXT PRIMARY KEY,
    peer_ghs REAL,
    protocol_version TEXT NOT NULL,
    attested INTEGER NOT NULL DEFAULT 0,
    last_seen TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
)
```

#### 5.4 History.fs Additions (~30 lines) — 🔴 NEW (Gap Fill for L9-E4)

```fsharp
// L9-E4: Multiverse event log
let recordMultiverseEvent (conn: DuckDBConnection) (action: string) (universeId: string) (branch: string) (ghs: float option) : unit =
    // Append to evolution_events with event_type = 'multiverse'
    // Action: "fork", "verify", "promote", "prune"
    // Append-only per AOR-HOLON-019
```

#### 5.5 Program.fs Wiring (+300 lines) — 8 New CLI Commands

| Command | Layer | Description |
|---------|-------|-------------|
| `store-init` | L3-E8 | Initialize holon directory + databases |
| `trend` | L5-E7 | GHS trend analysis with EMA |
| `homeostasis` | L5-E8 | PID controller state + guidance |
| `constitutional` | L8-E8 | Run all 6 Ψ invariant checks |
| `federation` | L7-E8 | Peer discovery + sync + attest |
| `multiverse` | L9-E8 | Fork/list/promote/prune operations |
| `biomorphic` | L4-E8 | Full 5-subsystem assessment |
| `mcp-list` | L2-E8 | List available MCP tools |

**Flags**: `--bio` on existing commands, `--guardian` on `commit`, `--holon-path` for data directory.

---

## 5.0 Compilation Order (.fsproj)

```xml
<ItemGroup>
  <!-- L0: Domain types (Phase 1) -->
  <Compile Include="Types.fs" />                    <!-- 316L  ⬛ -->
  <Compile Include="Bio.fs" />                      <!-- 219L  🔵 -->
  <!-- L1: Core logic (Baseline) -->
  <Compile Include="Parser.fs" />                   <!-- 514L  ⬛ -->
  <Compile Include="Analysis.fs" />                 <!-- 356L  ⬛ -->
  <!-- L6: Zenoh dual-write (Phase 1) -->
  <Compile Include="Notify.fs" />                   <!-- 254L  🔵 -->
  <!-- L3: Holon state persistence (Phase 1) -->
  <Compile Include="Store.fs" />                    <!-- 294L+ 🔵 -->
  <Compile Include="History.fs" />                  <!-- 244L+ 🔵 -->
  <!-- L8: Safety (Phase 2) -->
  <Compile Include="Guardian.fs" />                 <!-- 158L  🟣 -->
  <Compile Include="Constitutional.fs" />           <!-- 224L  🟣 -->
  <!-- Biomorphic subsystems (Phase 3, L1-L5) -->
  <Compile Include="Immune.fs" />                   <!-- ~250L 🟡 -->
  <Compile Include="Neural.fs" />                   <!-- ~200L 🟡 -->
  <Compile Include="Homeostasis.fs" />              <!-- ~230L 🟡 -->
  <Compile Include="Regenerative.fs" />             <!-- ~180L 🟡 -->
  <Compile Include="Symbiotic.fs" />                <!-- ~150L 🟡 -->
  <Compile Include="Trend.fs" />                    <!-- ~200L 🟡 -->
  <!-- Orchestration (Phase 3, depends on subsystems) -->
  <Compile Include="BiomorphicOrchestrator.fs" />   <!-- ~280L 🟡 -->
  <!-- Integration (Phase 4, depends on Analysis/Store) -->
  <Compile Include="McpTools.fs" />                 <!-- ~250L 🟡 -->
  <Compile Include="Federation.fs" />               <!-- ~200L 🟡 -->
  <!-- Multiverse (Phase 5, depends on Guardian/Store) -->
  <Compile Include="Multiverse.fs" />               <!-- ~200L 🟡 -->
  <!-- CLI entry (depends on everything) -->
  <Compile Include="Program.fs" />                  <!-- 700L+ ⬛ -->
</ItemGroup>

<ItemGroup>
  <PackageReference Include="Microsoft.Data.Sqlite" Version="10.0.0" />
  <PackageReference Include="DuckDB.NET.Data" Version="1.3.0" />
</ItemGroup>
```

**Final totals**: 21 source files, ~4,445 lines (current 3,279 + ~1,166 new + ~100 modifications)

---

## 6.0 Zenoh Topics (14 total, all implemented in Phase 1)

| Topic | Event Type | Publisher | Phase |
|-------|-----------|----------|-------|
| `indrajaal/git/commit` | Commit event | Notify.fs | ⬛ |
| `indrajaal/git/health` | GHS score | Notify.fs | ⬛ |
| `indrajaal/git/validate` | Validation result | Notify.fs | ⬛ |
| `indrajaal/git/suggest` | AI suggestion | Notify.fs | ⬛ |
| `indrajaal/git/homeostasis` | PID state | Notify.fs | 🔵 |
| `indrajaal/git/federation` | Peer GHS | Notify.fs | 🔵 |
| `indrajaal/git/constitutional` | Safety check | Notify.fs | 🔵 |
| `indrajaal/git/multiverse` | Fork/promote | Notify.fs | 🔵 |
| `indrajaal/git/biomorphic` | Full assessment | Notify.fs | 🔵 |
| `indrajaal/git/threat` | Detected patterns | Notify.fs | 🔵 |
| `indrajaal/git/homeostatic` | PID + guidance | Notify.fs | 🔵 |
| `indrajaal/git/neural` | AI recommendation | Notify.fs | 🔵 |
| `indrajaal/git/vital` | Vital signs | Notify.fs | 🔵 |
| `indrajaal/git/alignment` | Founder alignment | Notify.fs | 🔵 |

---

## 7.0 Test Strategy (6 test files, ~231 tests)

| File | Tests | Phase | Layers Covered |
|------|-------|-------|----------------|
| GitIntelligenceTests.fs (existing) | 77 | ⬛ | L0-E7, L1-E7 |
| StoreTests.fs | ~30 | P3 | L3-E7 |
| SafetyTests.fs | ~25 | P3 | L8-E7 |
| AdvancedTests.fs | ~25 | P3 | L2-E7, L5-E7 |
| BiomorphicTests.fs | ~74 | P3 | L4-E7 |
| FederationTests.fs | ~15 | P4 🔴NEW | L7-E7 |
| MultiverseTests.fs | ~15 | P5 🔴NEW | L9-E7 |
| **Total** | **~261** | | **E7 at all 10 layers** |

### Test Type Distribution

| Type | Count | Coverage |
|------|-------|----------|
| Unit tests | ~130 | Individual function I/O |
| Property tests (FsCheck) | ~45 | Invariant verification |
| Integration tests | ~50 | Cross-module interactions |
| Dashboard tests | ~15 | Output formatting |
| Safety tests | ~21 | Guardian, Constitutional, L6 |

---

## 8.0 FMEA Risk Analysis

| Failure Mode | S | O | D | RPN | Mitigation | Phase |
|-------------|---|---|---|-----|------------|-------|
| DuckDB.NET.Data not on net10.0 | 8 | 2 | 9 | 144 | Pin version 1.3.0, test first | P1 ✅ |
| Zenoh FFI not loaded | 5 | 4 | 9 | 180 | Graceful fallback (log-only) | ⬛ ✅ |
| Breaking existing 77 tests | 9 | 2 | 9 | 162 | Run tests after each phase | All |
| SQLite WAL lock contention | 7 | 3 | 5 | 105 | busy_timeout=5000, single writer | P1 ✅ |
| Immune scan exceeds 10ms | 7 | 3 | 4 | 84 | Limit history to 1000 commits | P3 |
| PID integral windup | 5 | 4 | 3 | 60 | Clamp integral to [-10, 10] | P3 |
| Federation peer impersonation | 8 | 2 | 5 | 80 | Ed25519 attestation | P4 |
| Multiverse branch conflict | 6 | 3 | 4 | 72 | UUID-based branch naming | P5 |
| MCP tool dispatch mismatch | 5 | 3 | 3 | 45 | Exhaustive match, unit tests | P4 |
| 100% coverage regression | 9 | 1 | 9 | 81 | Fractal matrix CI gate | P5 |

---

## 9.0 Gap Resolution Summary (10 NEW Cells)

| Cell | Gap Description | Resolution | Lines | Phase |
|------|----------------|------------|-------|-------|
| L3-E2 | No holon-level input normalization | `Store.normalizeAndIngest` — raw ParsedCommit → HolonCommitRecord | +30 | P5 |
| L7-E4 | No federation peer persistence | `Store.recordFederationPeer` + `federation_peers` SQLite table | +40 | P5 |
| L7-E7 | No federation tests | FederationTests.fs — 15 tests covering discovery, sync, attest | +120 | P4 |
| L9-E4 | No multiverse event persistence | `History.recordMultiverseEvent` — append to evolution_events | +30 | P5 |
| L9-E7 | No multiverse tests | MultiverseTests.fs — 15 tests covering fork, promote, prune | +120 | P5 |
| **Total** | 5 gaps requiring new code | | **+340 lines** | |

*Note: 5 additional gaps (L3-E8, L7-E8, L8-E8, L9-E8, L1-E8) are resolved by Phase 5 Program.fs wiring, already in original plan.*

---

## 10.0 Patterns to Mirror

| Pattern | Source File | Used In |
|---------|------------|---------|
| SQLite WAL | `lib/cepaf/src/Cepaf/Testing/UTLTSReporter.fs` | Store.fs ✅ |
| Guardian | `lib/cepaf/src/Cepaf/Cockpit/GuardianIntegration.fs` | Guardian.fs ✅ |
| PID Controller | `lib/cepaf/src/Cepaf/Testing/RegressionRunner.fs` | Homeostasis.fs 🟡 |
| MCP Dispatch | `lib/cepaf/src/Cepaf.Sentinel.MCP/Tools/SentinelTools.fs` | McpTools.fs 🟡 |
| Holon Directory | `data/holons/ex/` | manifest.json ✅ |
| Dual-Write | `lib/cepaf/src/Cepaf/Zenoh/Core/ZenohPublish.fs` | Notify.fs ✅ |

---

## 11.0 End-to-End Verification Procedure

```bash
# Phase 3 verification
dotnet build lib/cepaf/src/Cepaf.GitIntelligence/Cepaf.GitIntelligence.fsproj
dotnet run --project lib/cepaf/test/Cepaf.Tests/Cepaf.Tests.fsproj -- \
  --filter-test-list "GitIntelligence" --summary
# Expected: 231+ tests, 0 failures

# Phase 4 verification
dotnet run --project lib/cepaf/src/Cepaf.GitIntelligence/Cepaf.GitIntelligence.fsproj -- mcp-list
# Expected: 5 MCP tools listed

# Phase 5 verification
dotnet run --project lib/cepaf/src/Cepaf.GitIntelligence/Cepaf.GitIntelligence.fsproj -- biomorphic
dotnet run --project lib/cepaf/src/Cepaf.GitIntelligence/Cepaf.GitIntelligence.fsproj -- trend --since 6m
dotnet run --project lib/cepaf/src/Cepaf.GitIntelligence/Cepaf.GitIntelligence.fsproj -- multiverse list
dotnet run --project lib/cepaf/src/Cepaf.GitIntelligence/Cepaf.GitIntelligence.fsproj -- federation list
dotnet run --project lib/cepaf/src/Cepaf.GitIntelligence/Cepaf.GitIntelligence.fsproj -- constitutional

# Holon state verification
sqlite3 data/holons/git-intel/state.sqlite "SELECT COUNT(*) FROM commits;"
sqlite3 data/holons/git-intel/state.sqlite "SELECT COUNT(*) FROM federation_peers;"

# 100% fractal coverage gate
dotnet run --project lib/cepaf/test/Cepaf.Tests/Cepaf.Tests.fsproj -- \
  --filter-test-list "GitIntelligence" --summary
# Expected: 261+ tests, 0 failures, ALL 10 layers verified
```

---

## 12.0 Fractal Coverage Evolution

```
BEFORE EXPANSION (Baseline):
L0 ████████ 8/8     L5 ██████░░ 6/8
L1 ███████░ 7/8     L6 ███████░ 7/8
L2 █████░░░ 5/8     L7 ░░░░░░░░ 0/8
L3 ░░░░░░░░ 0/8     L8 █████░░░ 5/8
L4 ██████░░ 6/8     L9 ░░░░░░░░ 0/8
Total: 44/80 (55.0%)

AFTER PHASE 1+2 (Current):
L0 ████████ 8/8     L5 ██████░░ 6/8
L1 ███████░ 7/8     L6 ████████ 8/8  ← +1
L2 █████░░░ 5/8     L7 █░░░░░░░ 1/8  ← +1
L3 ██████░░ 6/8  ← +6  L8 ████████ 8/8  ← +3
L4 ██████░░ 6/8     L9 ██░░░░░░ 2/8  ← +2
Total: 63/80 (78.8%)

AFTER ALL PHASES (Target):
L0 ████████ 8/8     L5 ████████ 8/8
L1 ████████ 8/8     L6 ████████ 8/8
L2 ████████ 8/8     L7 ████████ 8/8
L3 ████████ 8/8     L8 ████████ 8/8
L4 ████████ 8/8     L9 ████████ 8/8
Total: 80/80 (100.0%) ← COMPLETE FRACTAL COVERAGE
```

---

## 13.0 Summary Table

| Phase | Priority | New Files | New Lines | Mod Lines | New Tests | New Cells | Gap Cells |
|-------|----------|-----------|-----------|-----------|-----------|-----------|-----------|
| 1 Foundation | P0 ✅ | 4 | ~730 | ~300 | 0 | 14 (🔵) | 0 |
| 2 Safety | P0 ✅ | 2 | ~380 | ~0 | 0 | 5 (🟣) | 0 |
| 3 Intelligence | P1 🟡 | 11 | ~1,490 | ~0 | ~154 | 9 | 0 |
| 4 Integration | P1 🟡 | 3 | ~450+120 | ~0 | ~15 | 4 | 1 (L7-E7) |
| 5 Advanced | P2 🟡 | 2 | ~200+120 | ~400 | ~15 | 4 | 4 (L3-E2, L7-E4, L9-E4, L9-E7) |
| **Total** | | **22 files** | **~3,490** | **~700** | **~184** | **36** | **5** |

**Grand Total**: 21 source files + 6 test files + 1 manifest = 28 files
**Lines**: Current 3,279 + ~4,190 additions/modifications = ~7,469 total
**Tests**: Current 77 + ~184 new = **~261 tests**
**Coverage**: 44/80 → **80/80 (100%)**

---

## STAMP Compliance
- SC-FUNC-001 (compile at all times): Build verified after each phase
- SC-SAFETY-001 (Guardian pre-approval): Guardian.fs gates all mutations
- SC-SAFETY-009–015 (Ψ₀-Ψ₅): Constitutional.fs verifies all 6 invariants
- SC-PRIME-001/002 (L6 protection): Guardian blocks L6 artifact modification
- SC-ZTEST-008 (dual-write): Notify.fs log-first, then Zenoh
- SC-XHOLON-001 (holon isolation): Standalone databases in `data/holons/git-intel/`
- SC-FSH-030 (property tests): FsCheck properties in all test files
- SC-SIL6-006 (2oo3 voting): BiomorphicOrchestrator uses 2oo3 for shouldHalt
- SC-FED-006 (Ed25519 attestation): Federation.fs attestPeer
- SC-SMRITI-142 (append-only): History.fs DuckDB never deletes/updates
- SC-DBNAME-001 (UHI naming): `fsharp.l3.git.001` in manifest.json

## Next Steps
1. **Immediate**: Begin Phase 3 — Immune.fs (highest impact: fills L4-E7, L5-E7)
2. **Then**: Neural.fs, Homeostasis.fs, Regenerative.fs, Symbiotic.fs, Trend.fs
3. **Then**: BiomorphicOrchestrator.fs (depends on all 5 subsystems)
4. **Then**: All 4 test files (StoreTests, SafetyTests, AdvancedTests, BiomorphicTests)
5. **Phase 4**: McpTools.fs, Federation.fs, FederationTests.fs
6. **Phase 5**: Multiverse.fs, MultiverseTests.fs, Store/History additions, Program.fs wiring
7. **Final**: Run full verification procedure (§11.0)

## KPIs
- Files changed: 0 (plan document only)
- Lines added: ~0 (journal entry)
- Fractal coverage: 63/80 current → 80/80 planned (100%)
- Phases complete: 2/5
- Tests: 77 current → 261 planned
- Source files: 10 current → 21 planned
