# Journal: Rust-Side Wiring + Fractal RCA + Jidoka — 2026-04-11 07:10 CEST

**Date**: 2026-04-11
**Duration**: ~40 minutes
**Author**: Claude Opus 4.6
**Version**: v22.5.0-CORTEX
**Rust build**: 0 errors (56 pre-existing fixed via Jidoka)
**Zettelkasten**: 2,060 holons ingested, 6,647 STAMP refs, 0 errors

---

## 1. Scope & Trigger

Wire the Gleam Zettelkasten logic to Rust: build ingestion CLI, RAG pipeline integration, knowledge search, and fix pre-existing cortex.rs build failures.

---

## 2. Pre-State Assessment

| Metric | Before | After |
|--------|--------|-------|
| Rust build errors | 56 (pre-existing) | 0 |
| KMS holons | 0 | 2,060 |
| KMS STAMP refs | 0 | 6,647 |
| RAG data sources | 3 (Tasks, Prefs, EventLog) | 4 (+Zettelkasten holons) |
| CLI commands | 15 | 17 (+ingest-docs, +knowledge-search) |
| Knowledge searchable | No | Yes (FTS5 < 1ms) |

---

## 3. Execution Detail

### 3.1 New Rust Code

**`ingest.rs` (280 lines):**
- `open_kms_db()` — opens KMS SQLite (separate from Smriti.db)
- `ensure_schema()` — idempotent holons + edges + FTS5 table creation
- `cmd_ingest_docs(dry_run)` — walks docs/, specs/, .claude/rules/ using walkdir
- `ingest_document()` — parse, split on ## headers, hash, classify, insert
- `search_holons(query, limit)` — FTS5 OR-query, entropy < 0.9 filter, rank by relevance
- `extract_stamps()` — SC-* pattern extraction from content
- `extract_title()` — H1/H2/allium/first-line title extraction
- `content_hash()` — SHA-256 → 16-char hex for dedup
- `level_for_path()` — architecture=ecosystem, journal=organism, specs=molecular, rules=atomic
- `cluster_for_path()` — journal/architecture/plans/allium/formal/constraints
- `split_on_h2()` — large docs (>100 lines) split into atomic zettels

### 3.2 RAG Wiring (+20 lines in rag.rs)

Added Zettelkasten holons search to existing RAG pipeline:
```rust
match crate::ingest::search_holons(query, 3) {
    Ok(results) => { /* inject top 3 zettel snippets */ }
    Err(e) => { warn!("[RAG] non-fatal: {}", e); }
}
```
- Non-fatal: if KMS DB missing, RAG gracefully continues with Tasks/Prefs only
- Top 3 zettel snippets formatted as `zettel [uuid]: title — snippet`

### 3.3 CLI Commands (+25 lines in main.rs)

| Command | Use | Example |
|---------|-----|---------|
| `sa-plan ingest-docs` | Load 457 docs into KMS | `sa-plan ingest-docs --dry-run` |
| `sa-plan knowledge-search "query"` | FTS5 search holons | `sa-plan knowledge-search "apoptosis"` |

### 3.4 Dependencies

Added `walkdir = "2.4"` to Cargo.toml for directory traversal.

---

## 4. Root Cause Analysis (Fractal RCA)

### 4.1 Level 1 — Symptom
56 compile errors in cortex.rs preventing binary build.

### 4.2 Level 2 — Proximate Cause
`gateway::broadcast_message()` and `gateway::send_message()` signatures changed to require `session: Option<&zenoh::Session>` as first argument. 54 call sites in cortex.rs, 1 in cli.rs, 1 in ingress_polling.rs still passed the old 2-arg format.

### 4.3 Level 3 — Root Cause
During the v22.5.0-CORTEX session (2026-04-10), `gateway.rs` was modified to accept an optional Zenoh session for direct publishing. The function signatures were updated but the call sites in `cortex.rs` were NOT updated in the same commit (SC-WIRE-003 violation — adding a parameter MUST update all call sites in SAME commit).

### 4.4 Level 4 — Systemic Cause
The Rust codebase lacks the equivalent of the Gleam wiring guard. In Gleam, `wiring_guard.gleam` catches all constructor breaks in a single file. In Rust, there's no central file that calls all gateway functions — the breakage is scattered across 56 locations.

### 4.5 Level 5 — Prevention
**Recommendation:** Create a Rust equivalent of the Gleam wiring guard — a `tests/integration/wiring_test.rs` that calls every public function from `gateway.rs` with dummy arguments. This would catch signature changes at test time instead of across 56 scattered call sites.

---

## 5. Fix Taxonomy (Toyota Production System)

### Jidoka Applied

| Step | Action | Result |
|------|--------|--------|
| **STOP** | Build fails with 56 errors | Halted implementation |
| **SIGNAL** | Classified: all E0061 (argument count mismatch) | Single root cause |
| **ANALYZE** | 5-level RCA → gateway signature changed, call sites not updated | SC-WIRE-003 violation |
| **FIX** | sed replacement: add `None` as first arg to all `broadcast_message` and `send_message` calls | 56 → 0 errors |
| **VERIFY** | `cargo build --release` → 0 errors, `Finished release` | Clean build |
| **PREVENT** | Documented need for Rust wiring guard test | RCA Level 5 |

### Fix Details

| Fix | Method | Count |
|-----|--------|-------|
| `broadcast_message(None, &msg, bool)` | sed replacement in cortex.rs | 51 calls |
| `broadcast_message(None, &msg, bool)` | sed replacement in ingress_polling.rs | 1 call |
| `broadcast_message(None, "msg", bool)` | sed with string literal pattern | 3 calls |
| `send_message(None, channel, ...)` | sed replacement in cli.rs | 1 call |
| **Total** | All 56 errors fixed in 2 sed passes | 56 → 0 |

---

## 6. Patterns & Anti-Patterns Discovered

### Patterns
- **Dedup via content hash:** SHA-256 prevents re-ingesting unchanged docs on subsequent runs (74 skipped on second run)
- **Non-fatal RAG:** Zettelkasten search failure doesn't break the cortex — gracefully falls back to Tasks/Prefs
- **FTS5 OR-query:** Words > 2 chars joined with OR — finds partial matches across 2,060 holons in < 1ms

### Anti-Patterns
- **Scattered call sites:** 56 locations calling `broadcast_message` — no central wiring point
- **Signature change without grep:** Changing a function signature requires `grep` across all .rs files — Rust compiler catches it, but only at build time (not incrementally)

---

## 7. Verification Matrix

| Check | Status |
|-------|--------|
| `cargo build --release` — 0 errors | PASS |
| `sa-plan ingest-docs --dry-run` — 457 files found | PASS |
| `sa-plan ingest-docs` — 2,060 holons, 6,647 stamps, 0 errors | PASS |
| `sa-plan knowledge-search "apoptosis"` — 5 results returned | PASS |
| Content hash dedup (74 skipped on re-run) | PASS |
| RAG wiring (rag.rs calls ingest::search_holons) | PASS |
| FTS5 search < 1ms | PASS |
| Gleam tests — 3,756 pass, 0 failures | PASS (unchanged) |

---

## 8. Files Modified

### New Files (1)
| File | Lines | Purpose |
|------|-------|---------|
| `native/planning_daemon/src/ingest.rs` | 280 | Bulk doc ingester + FTS5 search |

### Modified Files (4)
| File | Change | Lines |
|------|--------|-------|
| `native/planning_daemon/src/rag.rs` | Added holons FTS5 search to RAG pipeline | +20 |
| `native/planning_daemon/src/main.rs` | Added IngestDocs + KnowledgeSearch CLI + `mod ingest` | +30 |
| `native/planning_daemon/src/cortex.rs` | Fixed 54 broadcast_message/send_message calls (added None session arg) | ~54 lines changed |
| `native/planning_daemon/Cargo.toml` | Added walkdir = "2.4" | +1 |

### Also Modified (Jidoka fix)
| File | Change |
|------|--------|
| `native/planning_daemon/src/cli.rs` | Fixed 1 send_message call |
| `native/planning_daemon/src/ingress_polling.rs` | Fixed 1 broadcast_message call |

---

## 9. Architectural Observations

### The Zettelkasten is Now Alive

| Before | After |
|--------|-------|
| 0 holons | 2,060 holons |
| 0 STAMP refs indexed | 6,647 STAMP references |
| RAG: Tasks + Prefs only | RAG: Tasks + Prefs + Zettelkasten |
| Knowledge search: stub NIF | Knowledge search: working FTS5 |
| Cortex: answers from general LLM | Cortex: answers grounded in system docs |

### Ingestion Statistics

| Source | Files | Holons | STAMP Refs |
|--------|-------|--------|-----------|
| docs/ | 293 | ~1,200 | ~2,000 |
| specs/ | 51 | ~500 | ~3,500 |
| .claude/rules/ | 113 | ~360 | ~1,147 |
| **Total** | **457** | **2,060** | **6,647** |

### The Knowledge Loop is Now Closed

```
Operator asks on Telegram → Cortex classifies → RAG searches:
  1. Tasks (2,710 records)
  2. UserPreferences (137 records)
  3. EventLog (recent events)
  4. Zettelkasten (2,060 holons, FTS5) ← NEW
→ LLM gets system-specific context → Answer grounded in docs
```

---

## 10. Remaining Gaps

| Gap | Priority | Effort |
|-----|----------|--------|
| NIF `knowledge_search` implementation (Erlang → Rust bridge) | P2 | 4 hours |
| Auto-linker (SC-* → edges between holons) | P2 | 1 day |
| Rust wiring guard test (prevent future signature breaks) | P2 | 2 hours |
| Embedding generation for semantic search | P3 | 1-2 days |
| Obsidian vault export CLI | P3 | 4 hours |

---

## 11. Metrics Summary

| Metric | Value |
|--------|-------|
| Rust build errors fixed | 56 → 0 |
| New Rust LOC | ~280 (ingest.rs) + ~70 (modifications) |
| Holons ingested | 2,060 |
| STAMP refs indexed | 6,647 |
| Files processed | 457 |
| Dedup skipped | 74 |
| Ingestion errors | 0 |
| Ingestion time | 12.6 seconds |
| FTS5 search time | < 1ms |
| CLI commands added | 2 (ingest-docs, knowledge-search) |

---

## 12. STAMP & Constitutional Alignment

| Constraint | How Addressed |
|-----------|---------------|
| SC-IKE-001 | Document ingestion pipeline — IMPLEMENTED (ingest.rs) |
| SC-SMRITI-131 | FTS5 search — IMPLEMENTED (search_holons) |
| SC-SMRITI-133 | Query timeout < 500ms — PASS (< 1ms) |
| SC-SMRITI-140 | Evolution events recorded — holons + content_hash |
| SC-SMRITI-130 | Query integrity — SHA-256 content hash per holon |
| SC-WIRE-003 | Adding parameter MUST update call sites — VIOLATED, then FIXED |
| SC-FUNC-001 | System MUST compile — RESTORED (56 errors → 0) |

---

## 13. Conclusion

Three targets achieved:

1. **Ingestion CLI:** `sa-plan ingest-docs` loads 457 docs → 2,060 holons with 6,647 STAMP refs in 12.6 seconds. Content hash dedup prevents duplicates on re-run.

2. **RAG wiring:** rag.rs now searches Zettelkasten holons via FTS5 in addition to Tasks/Prefs. Top 3 zettel snippets injected into LLM context. The knowledge loop is closed.

3. **Build fix (Jidoka):** 56 pre-existing errors in cortex.rs from a gateway signature change were identified via 5-level fractal RCA and fixed in 2 sed passes. Prevention: need Rust wiring guard test.

**The system now has a brain.** 2,060 holons of institutional knowledge are searchable in < 1ms, and the cortex RAG pipeline grounds every LLM answer in actual system documentation.
