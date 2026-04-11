# Journal: Microservice Decomposition Analysis — 2026-04-11 05:30 CEST

**Date**: 2026-04-11
**Duration**: ~30 minutes
**Author**: Claude Opus 4.6
**Version**: v22.5.0-CORTEX
**STAMP**: SC-ARCH-SPLIT-001, SC-ZENOH-001, SC-XHOLON-001

---

## 1. Scope & Trigger

Operator asked: "this is currently monolithic, can it be split into functionally independent services" — referring to the Rust sa-plan-daemon (31 modules, 9,104 LOC, single binary) that currently handles ALL planning system features.

---

## 2. Pre-State Assessment

| Metric | Value |
|--------|-------|
| Binary | 1 monolith (`sa-plan-daemon`) |
| Modules | 31 Rust files |
| Total LOC | 9,104 |
| Database | 1 file (`Smriti.db`) with 6 tables |
| Feature domains | 13 |
| MCP tools | 47 |
| RETE-UL rules | 52 |
| Zenoh topics | ~20 distinct key expressions |
| God module | `cortex.rs` (1,580 lines, imports 6 crate modules) |
| God DB module | `db.rs` (1,007 lines, 21 writes, 56 reads, ALL 6 tables) |

---

## 3. Execution Detail

### 3.1 Dependency Analysis Method

Three-dimensional coupling analysis performed:

1. **Module imports** — `use crate::` statements traced for every .rs file
2. **Shared state** — table access patterns (which module reads/writes which table)
3. **Zenoh topics** — topic namespaces per module (communication boundaries)

### 3.2 Key Findings

**Coupling hotspots identified:**

| Module | Why it's a problem |
|--------|-------------------|
| `cortex.rs` (1,580 L) | God module — imports 6 crate modules, handles ALL dispatch |
| `db.rs` (1,007 L) | God DB — owns ALL 6 tables, 21 write sites, 56 read sites |

**Clean boundaries identified:**

| Boundary | Evidence |
|----------|---------|
| Gateway is pure I/O | `gateway.rs` + `ingress_polling.rs` only publish/subscribe Zenoh, no business logic |
| Trace is read-only analysis | `trace.rs` + `fmea.rs` only write to their own tables, never read Tasks |
| Inference is self-contained | `mcp_inference.rs` + `SemanticCache` have no dependency on Tasks or Trace |
| Task CRUD is isolated | `cli.rs` + `markdown.rs` + `tui.rs` only touch Tasks table |
| Ruliology is pure computation | `ruliology.rs` (929 L) has zero DB dependency |

**Table independence confirmed:**

| Table | Written by | Read by |
|-------|-----------|---------|
| Tasks | db.rs (via CLI) | cortex, markdown, tui, backup, rag |
| TransactionTrace | trace.rs | fmea.rs |
| TransactionSummary | trace.rs | cortex, fmea |
| ConversationHistory | db.rs (via cortex) | cortex |
| SemanticCache | db.rs (via cortex) | cortex, rag |
| UserPreferences | db.rs (via CLI) | cortex, mcp_gworkspace, rag, main |

Tables are logically independent — no foreign keys between them, no cross-table joins.

### 3.3 Proposed 6-Service Architecture

| Service | Owns | Database | LOC (est.) | Zenoh Namespace |
|---------|------|----------|-----------|----------------|
| **sa-plan** | Task CRUD, CLI, TUI, markdown sync | `planning.db` (Tasks) | 783 | `indrajaal/l5/cog/mcp/req/plan/**` |
| **sa-cortex** | Intent classification, OODA dispatch, MCP routing, PII | Stateless | 1,313 | `indrajaal/l5/cog/intent/**` |
| **sa-infer** | 6-tier cascade, cache, RAG, voice, circuit breakers | `inference.db` (SemanticCache) | 1,114 | `indrajaal/l5/cog/inference/**` |
| **sa-gateway** | Telegram/GChat/Email ingress+egress, conversation history | `gateway.db` (ConversationHistory) | 1,029 | `indrajaal/l4/system/gateway/**` |
| **sa-observe** | Pipeline tracing, FMEA, audit, telemetry, smoke test | `observe.db` (TransactionTrace, TransactionSummary) | 682 | `indrajaal/l5/cog/trace/**` |
| **sa-infra** | Backup/restore, HA election, ruliology, simulator, system tools | `infra.db` (UserPreferences) | 2,348 | `indrajaal/l4/system/**` |

**Total: 7,269 LOC across 6 services** (vs 9,104 in monolith — delta is shared types extracted to crate)

### 3.4 Communication Pattern

All inter-service communication via Zenoh pub/sub exclusively. No shared memory, no shared database files, no function calls across service boundaries.

```
Intent Flow:
  External Channel → sa-gateway → Zenoh → sa-cortex → Zenoh → sa-infer
                                                     → Zenoh → sa-plan
                                                     → Zenoh → sa-observe
                                  sa-cortex → Zenoh → sa-gateway → External Channel
```

### 3.5 Migration Strategy

7-phase incremental extraction, each independently deployable:

| Phase | Extract | Days | Risk | Rationale |
|-------|---------|------|------|-----------|
| 1 | Shared `c3i-types` crate | 1 | Low | Foundation — types used by all services |
| 2 | Split `db.rs` into 5 modules | 2 | Low | Tables already independent, no cross-joins |
| 3 | `sa-gateway` (first service) | 2 | Low | Lowest coupling, pure I/O, clean Zenoh boundary |
| 4 | `sa-observe` | 2 | Low | Read-only analysis, zero coupling to other domains |
| 5 | `sa-infer` | 2 | Medium | Self-contained but needs async Zenoh RPC for cache |
| 6 | `sa-plan` | 2 | Low | Pure CRUD, already has CLI interface |
| 7 | `sa-cortex` (slim orchestrator) | 3 | Medium | Becomes stateless Zenoh router |

**Total estimated effort:** ~2 weeks
**Key constraint:** Monolith continues working at every step — services extracted incrementally

---

## 4. Root Cause Analysis

### Why is it monolithic?

**Historical:** The sa-plan-daemon started as a simple CLI task manager (`sa-plan status/add/update`). Features were added incrementally:
- Chat cortex added for Telegram/GChat intent processing
- Inference cascade added for LLM integration
- Pipeline tracing added for observability
- Voice processing added for Gemini Live
- Backup/restore added for DR
- Ruliology added for Wolfram analysis

Each feature was a new .rs file added to the same Cargo binary. The `cortex.rs` module became the central dispatcher because intents need access to tasks, inference, gateway, and tracing simultaneously.

### Why can it be split now?

**Zenoh is the enabler.** All modules already publish/subscribe to distinct Zenoh topic namespaces. The function calls between modules can be replaced with Zenoh pub/sub requests. The system was designed for distributed operation — it just wasn't deployed that way.

---

## 5. Fix Taxonomy

| Category | Count | Description |
|----------|-------|-------------|
| Architectural decomposition | 6 | Extract 6 services from monolith |
| Database separation | 5 | Split Smriti.db into 5 per-service DBs |
| Communication refactor | 1 | Function calls → Zenoh RPC |
| Shared types extraction | 1 | Common types crate |

---

## 6. Patterns & Anti-Patterns Discovered

### Patterns
- **Topic-based boundaries:** Zenoh topic namespaces naturally map to service boundaries (`/plan/**` = task service, `/inference/**` = inference service, `/gateway/**` = gateway service)
- **Table-per-service:** SQLite tables have zero cross-table dependencies — natural database-per-service split
- **Stateless orchestrator:** The cortex reads from all other domains but writes to none — natural candidate for stateless gateway
- **IO boundary:** Gateway modules (`gateway.rs`, `ingress_polling.rs`, `mcp_gworkspace.rs`) are pure external I/O — cleanest extraction target

### Anti-Patterns
- **God module:** `cortex.rs` at 1,580 lines doing classification + dispatch + MCP routing + response formatting
- **God DB:** `db.rs` at 1,007 lines owning all 6 unrelated tables
- **Implicit coupling:** Cortex calls inference functions directly instead of via Zenoh — makes extraction harder
- **Shared preferences:** UserPreferences table used by 4 different modules for different categories — needs category-based sharding

---

## 7. Verification Matrix

| Analysis | Method | Result |
|----------|--------|--------|
| Module dependency graph | `use crate::` grep | 31 modules mapped |
| Table access patterns | Table name grep per module | 6 tables × 31 modules |
| Zenoh topic namespaces | Topic string grep per module | ~20 topics mapped |
| Write vs read coupling | INSERT/UPDATE/SELECT counts | db.rs: 21W/56R, all others: read-mostly |
| Module sizes | `wc -l` per file | Range: 28-1,580 lines |
| Clean boundary identification | Zero cross-domain writes | 5 clean boundaries confirmed |

---

## 8. Files Modified

No files modified — this was a pure analysis session. All output is in this journal entry.

**Files analyzed:** All 31 .rs files in `sub-projects/c3i/native/planning_daemon/src/`

---

## 9. Architectural Observations

### 9.1 The Monolith is Well-Structured

Despite being a single binary, the codebase is already modular:
- Each feature domain is in its own .rs file
- Shared state goes through `db.rs` (not scattered SQL)
- Error types are centralized in `errors.rs`
- Types are centralized in `types.rs`

This means extraction is a **mechanical refactoring**, not a redesign. The boundaries exist — they just need to be enforced with process isolation instead of module boundaries.

### 9.2 Zenoh is the Distributed Bus

The system already communicates internally via Zenoh topics. Converting direct function calls to Zenoh pub/sub is the main work. The topic namespace design (`indrajaal/l{N}/{domain}/{action}`) naturally maps to service ownership.

### 9.3 SQLite-per-Service is Natural

Each service gets its own SQLite file:
- `planning.db` (Tasks) — sa-plan owns
- `inference.db` (SemanticCache) — sa-infer owns
- `gateway.db` (ConversationHistory) — sa-gateway owns
- `observe.db` (TransactionTrace, TransactionSummary) — sa-observe owns
- `infra.db` (UserPreferences) — sa-infra owns

No distributed transactions needed. Each service has full sovereignty over its data (SC-XHOLON-001).

### 9.4 The Cortex Becomes a Router

Post-decomposition, `sa-cortex` is a **stateless Zenoh message router**:
1. Receives intent from `sa-gateway`
2. Classifies it
3. Routes to the right service(s) via Zenoh
4. Collects response(s)
5. Sends back to `sa-gateway` for delivery

No database. No persistent state. Pure cognitive routing. This is the cleanest expression of the biomorphic cortex metaphor — it's literally a nervous system relay.

---

## 10. Remaining Gaps

| Gap | Priority | Effort |
|-----|----------|--------|
| Implement Zenoh RPC pattern (request/response over pub/sub) | P1 | 2 days |
| Extract `c3i-types` shared crate | P1 | 1 day |
| Split db.rs into per-service modules | P1 | 2 days |
| Define service health protocol (each service publishes heartbeat) | P2 | 1 day |
| Service discovery via Zenoh | P2 | 1 day |
| Backup service needs read access to all other DBs | P2 | Design decision |
| UserPreferences sharding by category | P2 | 1 day |
| Integration test framework for 6-service deployment | P3 | 3 days |

---

## 11. Metrics Summary

| Metric | Value |
|--------|-------|
| Modules analyzed | 31 |
| Total LOC analyzed | 9,104 |
| Services proposed | 6 |
| Clean boundaries found | 5 |
| Coupling hotspots | 2 (cortex.rs, db.rs) |
| Estimated migration effort | ~2 weeks |
| Zenoh topics mapped | ~20 |
| Tables confirmed independent | 6/6 (no cross-joins) |

---

## 12. STAMP & Constitutional Alignment

| Constraint | How Addressed |
|-----------|---------------|
| SC-ARCH-SPLIT-001 | Monitoring + ops = Rust only (all 6 services remain Rust) |
| SC-XHOLON-001 | Isolated database files per service (holon sovereignty) |
| SC-ZENOH-001 | All inter-service communication via Zenoh (mandatory mesh) |
| SC-ZMOF-001 | Zenoh is the SOLE transport for inter-service messaging |
| SC-HA-001 | Each service independently restartable, HA election in sa-infra |
| SC-SIL4-007 | Dying gasp per service (not just per monolith) |
| SC-FUNC-003 | Rollback: revert to monolith at any phase (incremental extraction) |
| Psi-0 (Existence) | Each service can restart independently without killing others |
| Omega-0 (Symbiotic) | Services cooperate via Zenoh, not compete for shared state |

---

## 13. Conclusion

The sa-plan-daemon monolith (9,104 LOC, 31 modules) can be cleanly decomposed into 6 independent services communicating exclusively via Zenoh pub/sub, each owning its own SQLite database. The decomposition is enabled by three pre-existing properties:

1. **Modular source** — each feature domain is already in its own .rs file
2. **Independent tables** — no foreign keys or cross-table joins in Smriti.db
3. **Zenoh topic namespaces** — communication boundaries already defined

The migration is incremental (7 phases, ~2 weeks) with the monolith continuing to function at every step. The most impactful single change is extracting `sa-gateway` first — it has the cleanest boundary (pure I/O) and immediately proves the Zenoh RPC pattern works.

Post-decomposition, the cortex becomes what it was always meant to be: a stateless cognitive router. The name was always the blueprint — a nervous system relay, not a database.
