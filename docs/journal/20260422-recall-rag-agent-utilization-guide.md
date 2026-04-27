https://vm-1.tail55d152.ts.net:8443/task-id/116442770287604446/20260422-recall-rag-agent-utilization-guide.md

# Agent Utilization Guide: Recall/RAG/Context Memory System
## Complete Instructions for Full System Utilization

**Date**: 2026-04-22
**Task ID**: 116442770287604446
**Version**: v22.10.1-PI-SYMBIOSIS
**ZK Recall**: [zk-c50fc32bd0bf7510] SC-RECALL-RAG rule, [zk-a76df6bf24462fbc] feature evolution journal

---

## 1. Scope & Trigger

**Scope**: Comprehensive analysis and operational guide for how AI agents (Claude, Gemini, Pi, OpenCode) should fully utilize the 7-layer Recall/RAG/Context Memory system.

**Trigger**: User requested detailed journal documenting what instructions to provide agents for full utilization of the RAG and lookup system.

**Problem Statement**: The system has 6,139 lines of recall/RAG code across 10 Gleam modules and 31 Rust modules, but agents underutilize it. On 2026-04-17, Claude ignored ZK recall results for an entire session despite hooks firing on every prompt (RPN=729, highest-risk cognitive failure). This guide prevents recurrence by providing explicit, actionable agent instructions.

---

## 2. Pre-State Assessment

### Current System Inventory
| Component | Location | LOC | Status |
|-----------|----------|-----|--------|
| Gleam ZK types | `zettelkasten/types.gleam` | 233 | Operational — 9 KnowledgeSource variants, 4 HolonLevel, 4 RhetoricalFunction |
| Gleam ZK search | `zettelkasten/search.gleam` | 241 | Operational — FTS5 query builder, SearchQuery/SearchResult/RagContext types |
| Gleam ZK operations | `zettelkasten/operations.gleam` | 435 | Operational — 25 use cases (UC01-UC25) |
| Gleam ZK ingestion | `zettelkasten/ingestion.gleam` | 265 | Operational — markdown parser, SHA-256, split on ## headers |
| Gleam ZK entropy | `zettelkasten/entropy.gleam` | 128 | Operational — decay rates Fast/Medium/Slow |
| Gleam ZK trust | `zettelkasten/trust.gleam` | 121 | Operational — Axiom=1.0, Evidence=0.9, Hypothesis=0.5, Anecdote=0.3 |
| Gleam ZK linker | `zettelkasten/linker.gleam` | 168 | Operational — STAMP ref extraction |
| Gleam ZK metrics | `zettelkasten/metrics.gleam` | 191 | Operational — orphan detection, health stats |
| Gleam ZK rules | `zettelkasten/rules.gleam` | 184 | Operational — stale architecture, orphan surge detection |
| Gleam ZK export | `zettelkasten/export.gleam` | 168 | Operational — MD/JSON/SQLite export |
| Rust RAG pipeline | `planning_daemon/src/rag.rs` | 104 | Operational — LIKE + FTS5 + holon search + PII scrub |
| Rust cortex | `planning_daemon/src/cortex.rs` | 1,980 | Operational — intent classification, 6-tier cascade |
| Rust PipelineTracer | `planning_daemon/src/trace.rs` | 241 | Operational — zero-write hot path, batch finish |
| Rust semantic cache | `planning_daemon/src/mcp_inference.rs` | 663 | Operational — 24h TTL, SQLite-backed |
| Rust DB backend | `planning_daemon/src/db.rs` | 1,017 | Operational — task CRUD, trace schema |

### Dual Zettelkasten State
| ZK | Holons | Database | Binary |
|----|--------|----------|--------|
| C3I-ZK | 31,775 | `data/kms/smriti.db` | `sa-plan-daemon knowledge-search` |
| FY27-ZK | 475+ | `sub-projects/work/gdrive/1-Work/FY27-Plan/zettelkasten/fy27-plan.db` | `fy27-zettelkasten search` |

### Known Utilization Gap
- **P(ZK_cited per response)**: ~0.05 (target: 0.90)
- **Holon IDs cited per session**: ~0 (target: 5+)
- **Anti-patterns caught by recall**: 0% (target: 100%)
- **Root cause**: Advisory-only hooks, no enforcement mechanism

---

## 3. Execution Detail: Agent Instructions for Full RAG Utilization

### 3.1 MANDATORY BOOTSTRAP SEQUENCE (Every Session Start)

Every agent session MUST begin with this exact sequence:

```
PHASE 1: MEMORY (0-2s)
  Read .claude/projects/*/memory/MEMORY.md
  → Provides cross-session context, user preferences, prior session summaries

PHASE 2: RECALL (2-8s)
  sa-plan-daemon knowledge-search "<user's request keywords>"
  → Returns top 5 holons from C3I-ZK (31,775 holons, engineering)
  
  $ZK search "<user's request keywords>"  
  → Returns top 5 holons from FY27-ZK (475 holons, sales/accounts)
  
  CRITICAL: Read the results. Cite at least 1 holon ID in your first response.
  Format: "ZK recall: [zk-XXXX] indicates..."

PHASE 3: ORIENT (8-12s)
  sa-plan-daemon status
  → Shows active/pending/completed task counts
  
  cd lib/cepaf_gleam && gleam build
  → Verifies system compiles (0 errors required)

PHASE 4: ACT
  Begin task execution with ZK-informed approach
```

### 3.2 ON EVERY USER PROMPT (UserPromptSubmit Hook)

The hook automatically fires `knowledge-search` on every prompt. Agents MUST:

1. **READ** the ZK recall results injected as system context
2. **SCAN** for anti-pattern alerts (look for prior failures, RCA findings)
3. **CITE** at least 1 holon ID in the response opening
4. **APPLY** proven patterns instead of reinventing solutions
5. **AVOID** anti-patterns flagged in recall results

**Citation format**:
```
ZK recall: [zk-1234] prior pattern for <topic> — applying proven approach.
ZK recall: [zk-5678] anti-pattern detected — avoiding <bad approach>.
ZK recall: no relevant prior patterns — proceeding from first principles.
```

### 3.3 KNOWLEDGE SEARCH COMMANDS

| Need | Command | Returns |
|------|---------|---------|
| Engineering search | `sa-plan-daemon knowledge-search "query"` | Top 5 holons from Smriti.db |
| Sales/account search | `cd $ZK_DIR && $ZK search "query"` | Top 5 holons from FY27 ZK |
| Contact lookup | `cd $ZK_DIR && $ZK contacts "name or company"` | Contact details |
| System status | `sa-plan-daemon status` | Task counts, system health |
| ZK statistics | `cd $ZK_DIR && $ZK stats` | Holon count, format distribution |

Where:
```bash
ZK=/home/an/dev/ver/c3i/sub-projects/work/fy27-zk-build/release/fy27-zettelkasten
ZK_DIR=/home/an/dev/ver/c3i/sub-projects/work/gdrive/1-Work/FY27-Plan/zettelkasten
```

### 3.4 RAG PIPELINE — HOW IT WORKS (Agent Understanding Required)

When the Rust cortex receives a user intent, the RAG pipeline executes before ANY LLM inference:

```
retrieve_context(query) → 4 parallel searches:
  1. UserPreferences table: LIKE match on key/value (limit 5)
  2. Tasks table: LIKE match on title (limit 5)
  3. EventLog table: LIKE match on Payload, ORDER BY Timestamp DESC (limit 3)
  4. Zettelkasten holons: FTS5 MATCH query (limit 3)
  
→ Results combined into context string
→ PII scrubber removes emails, phones, SSN, IPs, credit cards
→ Each snippet truncated to 200 chars
→ Context injected into LLM system prompt
→ Total RAG latency: ~4ms
```

**Why agents should care**: The RAG context is already injected before agents see the response. But agents operating in Claude Code (not via the chat cortex) must MANUALLY search ZK because they bypass the Rust RAG pipeline. The hooks bridge this gap.

### 3.5 SEMANTIC CACHE — WHAT AGENTS SHOULD KNOW

```
Query hash → SQLite lookup → if hit (< 24h old): skip LLM inference
                            → if miss: run 6-tier cascade, store result

Agent implication:
- Identical questions within 24h get cached answers (faster, cheaper)
- If you need a FRESH answer, rephrase the query slightly
- Cache is per-query-hash, not per-session
```

### 3.6 THE 25 USE CASES — WHAT'S AVAILABLE

Agents can leverage these implemented operations from `zettelkasten/operations.gleam`:

| UC | Function | Agent Use Case |
|----|----------|---------------|
| UC01 | `cortex_rag_context(query, holons)` | Build RAG context before LLM call |
| UC02 | `ooda_find_precedent(facts, holons)` | "Has this decision been made before?" |
| UC04 | `grounded_system_prompt(base, query, holons)` | Inject ZK context into system prompt |
| UC05 | `capture_interaction(chat_id, intent_id, q, a, ts)` | Save Q&A as new holon |
| UC06 | `operator_profile(chat_id, holons)` | Build user interest profile |
| UC07 | `detect_drift(holons, edges)` | Find code↔spec freshness gaps |
| UC08 | `onboarding_sequence(holons)` | Surface knowledge for new operators |
| UC09 | `compliance_gaps(holons, edges)` | Find constraints with no implementing code |
| UC10 | `state_at_time(holons, timestamp)` | Reconstruct system state at any point |
| UC11 | `zettel_from_commit(sha, message, ts)` | Auto-create holon from git commit |
| UC12 | `zettel_from_trace(intent_id, class, model, ms, ts)` | Auto-create from pipeline trace |
| UC13-25 | Various auto-generation | OODA decisions, cache learning, session summaries |

### 3.7 TRUST-BASED RETRIEVAL — HOW TO INTERPRET RESULTS

Not all holons are equal. Agents MUST weight results by trust:

| RhetoricalFunction | Trust | Decay | Example Content |
|--------------------|-------|-------|----------------|
| **Axiom** | 1.0 | Slow | SC-* constraints, architectural decisions, CLAUDE.md rules |
| **Evidence** | 0.9 | Medium | Journal entries, test results, pipeline traces |
| **Hypothesis** | 0.5 | Medium | Plans, predictions, cost estimates |
| **Anecdote** | 0.3 | Fast | Chat conversations, user preferences |

**Agent rule**: Prefer Axiom > Evidence > Hypothesis > Anecdote. If an Axiom holon contradicts an Anecdote holon, the Axiom wins.

### 3.8 ENTROPY-BASED FRESHNESS — HOW TO HANDLE STALE DATA

Each holon has an entropy value [0.0 = fresh, 1.0 = stale]:

```
Decay per day:
  Fast:   0.1  (chat conversations → stale in ~10 days)
  Medium: 0.05 (journal entries → stale in ~20 days)
  Slow:   0.02 (architecture docs → stale in ~50 days)

Agent rule:
  entropy < 0.3: FRESH — use confidently
  entropy 0.3-0.7: AGING — use with verification
  entropy > 0.7: STALE — verify against current code before acting
  entropy > 0.9: NEARLY DEAD — do not use without fresh verification
```

### 3.9 SESSION END PROTOCOL (MANDATORY)

Before ending ANY session, agents MUST:

```bash
# 1. Ingest all new/modified documents to ZK
cd /home/an/dev/ver/c3i && sa-plan-daemon ingest-docs
# → This ensures new knowledge is searchable in future sessions

# 2. Email summary (if significant work done)
sa-plan-daemon send-email \
  --to Abhijit.Naik@bountytek.com \
  --subject "Session: <summary>" \
  --body "<key outcomes>" \
  -a docs/journal/<journal-file>.md

# 3. Update memory with session learnings
# Write to .claude/projects/*/memory/ with session findings
```

---

## 4. Root Cause Analysis: Why Agents Underutilize RAG

### Primary Causes
1. **Attention allocation**: Agents focus ~80% on the user's urgent task, ~5% on ZK context. The ZK results are present but not attended to.
2. **No enforcement**: Hooks inject context but don't BLOCK the agent from ignoring it. The mandate is rule-based, not mechanically enforced.
3. **Context window pressure**: In long sessions, ZK results may be compressed away before the agent processes them.
4. **Mismatched timing**: The hook fires BEFORE the agent sees the prompt, so the ZK results arrive as system context, not as a direct answer to a question.

### Contributing Factors
- Agents don't know the ZK exists unless they read the rules
- No visual indicator of ZK recall quality (hit vs miss)
- No penalty for ignoring ZK (only a rule violation, not a functional failure)
- The 200-char truncation makes snippets hard to act on

### 5-Why Analysis
1. WHY did Claude ignore ZK? → ZK results were advisory context, not blocking
2. WHY were they advisory? → No enforcement mechanism existed
3. WHY no enforcement? → The system assumed agents would read system context
4. WHY did they not? → Attention competition with user's urgent request
5. WHY? → Cognitive architectures prioritize explicit requests over ambient context

---

## 5. Fix Taxonomy

| Fix | Type | Status | Impact |
|-----|------|--------|--------|
| SC-ZK-IMP-001..006 mandatory citation rules | Rule | Active | Forces agents to cite holons |
| UserPromptSubmit hook auto-search | Hook | Active | Automatic search on every prompt |
| SessionStart hook stats display | Hook | Active | Shows ZK health on session start |
| Stop hook auto-ingest | Hook | Active | Ensures new knowledge is captured |
| This agent utilization guide | Documentation | NEW | Explicit instructions for agents |
| Recall-RAG automation rule | Rule | NEW | SC-RECALL-RAG-001..008 |
| 74 regression tests | Tests | NEW | Verifies ZK module correctness |

---

## 6. Patterns & Anti-Patterns Discovered

### PATTERNS (Do These)

**P1: Search Before Act**
Always search ZK before starting any task. The 5s search time saves hours of reinventing.
```bash
sa-plan-daemon knowledge-search "<task keywords>"
```

**P2: Cite Early**
Put the ZK citation in your first paragraph. This forces you to read the results.
```
ZK recall: [zk-XXXX] indicates prior pattern for <topic>...
```

**P3: Trust-Weighted Retrieval**
When ZK returns multiple results, prefer Axiom (trust=1.0) over Anecdote (trust=0.3).

**P4: Entropy-Aware Usage**
Check entropy before acting on ZK results. Entropy > 0.7 = verify against current code.

**P5: Ingest on Exit**
Every session MUST run `sa-plan-daemon ingest-docs` before ending. This is the feedback loop that makes the system smarter over time.

**P6: Dual-ZK for Dual Domains**
Engineering questions → C3I-ZK. Sales questions → FY27-ZK. Always search BOTH for ambiguous queries.

**P7: Anti-Pattern Detection**
If ZK recall contains an anti-pattern tag, STOP and read it before proceeding. These are expensive lessons from prior failures.

### ANTI-PATTERNS (Never Do These)

**AP1: Ignoring ZK Recall (RPN=729)**
Root cause of the 2026-04-17 incident. Agent performed deep analysis without citing a single holon despite 2,705 available.

**AP2: First-Principles When Pattern Exists**
If ZK has a proven pattern for your task, USE IT. Don't reinvent. Check before reasoning.

**AP3: Skipping Session End Ingest**
Every session creates knowledge. If you don't ingest, it's lost forever. This is institutional amnesia.

**AP4: Manual Reasoning When NIF Exists**
Don't manually compute PageRank, shortest paths, or graph analysis. Use the 125 Gleam NIF functions.

**AP5: Treating All Holons Equally**
An Axiom holon (SC-* constraint, architecture decision) is NOT the same as an Anecdote holon (chat conversation). Weight by trust score.

---

## 7. Verification Matrix

| Check | Method | Status |
|-------|--------|--------|
| ZK search returns results | `sa-plan-daemon knowledge-search "test"` | PASS (31,775 holons) |
| FY27 ZK accessible | `$ZK search "ARM"` | PASS (475+ holons) |
| Gleam ZK modules compile | `gleam build` | PASS (0.50s) |
| Regression tests pass | `gleam test` | PASS (8,979 passed, 74 new) |
| RAG pipeline functional | rag.rs `retrieve_context()` | PASS |
| Semantic cache works | mcp_inference.rs cache lookup | PASS |
| Hooks configured | .claude/settings.json | PASS (3 hooks) |
| Dashboard accessible | https://vm-1.tail55d152.ts.net:8443/recall-rag | PASS |
| Pi bridge compatible | pi_claude_code.gleam compiles | PASS |
| STAMP constraints documented | SC-RECALL-RAG-001..008 | PASS |

---

## 8. Files Modified/Created

| File | Action | Lines |
|------|--------|-------|
| `docs/journal/20260422-recall-rag-agent-utilization-guide.md` | NEW | This file |
| `docs/journal/20260421-recall-rag-context-memory-feature-evolution.md` | PRIOR | 410 lines |
| `web_static/recall-rag.html` | PRIOR | 177 lines |
| `web_static/recall-rag-deck.html` | PRIOR | 137 lines |
| `test/recall_rag_regression_test.gleam` | PRIOR | 903 lines |
| `docs/pi-integration/recall-rag-pi-integration-guide.md` | PRIOR | 245 lines |
| `.claude/rules/recall-rag-feature-evolution.md` | PRIOR | 47 lines |
| `docs/journal/task-116442770287604446-links.json` | PRIOR | 54 lines |
| `web/api.rs` | MODIFIED | +12 lines (2 new route handlers) |
| `web/server.rs` | MODIFIED | +4 lines (4 new routes) |

---

## 9. Architectural Observations

### 9.1 The RAG Pipeline is Minimally Elegant
At only 104 lines of Rust, `rag.rs` achieves production-grade retrieval via 4 parallel table searches + ZK holon search + PII scrubbing. The simplicity is a feature — fewer moving parts = fewer failure modes. Agents should not attempt to "improve" this without clear evidence of inadequacy.

### 9.2 The Dual-ZK Architecture is Domain-Aware
C3I-ZK handles engineering knowledge (code patterns, architecture, RCA findings). FY27-ZK handles sales knowledge (accounts, contacts, rate cards). This separation prevents cross-domain pollution. Agents should always search the appropriate ZK for their domain.

### 9.3 The Hook System is the Critical Integration Point
Three hooks (SessionStart, UserPromptSubmit, Stop) form the agent-ZK bridge. Without these hooks, agents have NO automatic access to institutional memory. Any agent platform (Pi, Gemini, OpenCode) MUST implement equivalent hooks to achieve full RAG utilization.

### 9.4 Trust Scoring Creates an Information Hierarchy
The RhetoricalFunction → TrustScore mapping (Axiom=1.0, Evidence=0.9, Hypothesis=0.5, Anecdote=0.3) ensures that architectural decisions outweigh casual observations. This is critical for preventing agents from acting on low-confidence information.

### 9.5 Entropy Decay Prevents Stale Knowledge Poisoning
Without entropy decay, old holons would accumulate forever, eventually drowning relevant results in noise. The decay rates (Fast=0.1/day, Medium=0.05/day, Slow=0.02/day) ensure that conversational knowledge fades faster than architectural knowledge.

### 9.6 The PipelineTracer is a First-Class Observability Pattern
The zero-write hot path (in-memory Vec<TraceStage>, single batch SQLite+Zenoh write on finish) means tracing adds ~0ms latency during processing. This pattern should be replicated in Pi-mono and any other agent platform.

---

## 10. Remaining Gaps

| Gap | Priority | Estimated LOC | Description |
|-----|----------|---------------|-------------|
| Vector embeddings | P1 | 200 Rust | Semantic similarity search (beyond FTS5 keyword matching) |
| Holon link graph | P2 | 150 Rust | Graph-based navigation between related holons |
| Cognitive enforcement hook | P1 | 100 Gleam | Hook that BLOCKS agent response if ZK not cited |
| Session context accumulation | P2 | 100 Gleam | Cross-session context merging |
| Wolfram CA analysis of ZK | P3 | 200 Rust | Rule 110/30/184 on knowledge graph dynamics |
| Visual ZK explorer | P2 | 300 HTML | Interactive graph visualization of holon connections |
| Pi-mono RAG integration | P1 | 630 TypeScript | Full RAG pipeline in Pi (see pi-integration guide) |

---

## 11. Metrics Summary

| Metric | Value | Threshold | Status |
|--------|-------|-----------|--------|
| Total recall/RAG LOC | 6,139 | — | Baseline |
| Gleam ZK modules | 10 | — | Complete |
| ZK operations (use cases) | 25 | — | Complete |
| C3I-ZK holons | 31,775 | Growing | HEALTHY |
| FY27-ZK holons | 475+ | Growing | HEALTHY |
| FY27 contacts | 13,437 | — | HEALTHY |
| Auto-recall hooks | 3 | 3 required | PASS |
| FTS5 query P50 | ~4ms | <500ms | PASS |
| Semantic cache TTL | 24h | — | Configured |
| Conversation window | 50 msgs | — | Configured |
| Regression tests | 74 new (8,979 total) | — | PASS |
| Trust score range | [0.3, 1.0] | — | Correct |
| Entropy decay rates | 3 (Fast/Med/Slow) | — | Correct |
| Agent ZK citation rate | ~5% | 90% target | GAP |
| Dashboard uptime | 24/7 via Tailscale | — | LIVE |

---

## 12. STAMP & Constitutional Alignment

### STAMP Constraints Verified
| ID | Constraint | Compliance |
|----|------------|-----------|
| SC-ZK-CLAUDE-001 | Claude MUST search ZK BEFORE starting any task | ENFORCED via hooks |
| SC-ZK-CLAUDE-002 | Claude MUST ingest to ZK AFTER completing work | ENFORCED via Stop hook |
| SC-ZK-IMP-001 | Claude MUST read ZK recall from hook | RULE-BASED (not mechanically enforced) |
| SC-ZK-IMP-002 | Claude MUST cite at least 1 holon per response | RULE-BASED |
| SC-IKE-001 | Document ingestion pipeline | IMPLEMENTED |
| SC-SMRITI-131 | Full-text search uses FTS5 | IMPLEMENTED |
| SC-SMRITI-133 | Query timeout <500ms | VERIFIED (~4ms P50) |
| SC-COG-001 | Cortex processes via 6-tier cascade | IMPLEMENTED |
| SC-SEC-003 | PII masking in RAG | IMPLEMENTED (pii.rs) |
| SC-RECALL-RAG-001 | ZK module changes run regression test | NEW |
| SC-RECALL-RAG-005 | Dashboard updated at /recall-rag | NEW |

### Constitutional Alignment
- **Psi-0 (Existence)**: ZK ensures system knowledge survives session boundaries
- **Psi-1 (Regeneration)**: Holons in SQLite are recoverable from backup
- **Psi-2 (History)**: 31,775 holons = complete institutional history
- **Psi-3 (Verification)**: SHA-256 content hashes verify holon integrity
- **Psi-4 (Alignment)**: Trust scoring preserves human intent (Axiom=1.0)
- **Psi-5 (Truthfulness)**: Entropy decay prevents stale data from deceiving agents
- **Omega-0 (Founder)**: ZK serves the founder by preserving all learnings

---

## 13. Conclusion

The Recall/RAG/Context Memory system is architecturally complete but operationally underutilized. The 7-layer hierarchy (Context Window → Claude Memory → Auto-Recall Hooks → RAG Pipeline → Semantic Cache → Conversation History → Zettelkasten) provides effectively unbounded recall within any context window limit.

**The critical gap is not technical but cognitive**: agents must be explicitly instructed to READ and CITE ZK recall results. This journal provides those instructions. The target is moving P(ZK_cited) from ~5% to 90%+.

**For Pi-mono integration**: See `docs/pi-integration/recall-rag-pi-integration-guide.md` for the complete TypeScript implementation plan (~630 LOC). The key insight is that Pi agents need equivalent hooks (onPromptSubmit, onSessionEnd) to bridge the agent-ZK gap.

**For any new agent platform**: Implement these 3 hooks and the system works automatically:
1. **Session start**: Search both ZKs, display stats
2. **Every prompt**: Search ZK for query context, inject as system context
3. **Session end**: Ingest all new documents to ZK

The ZK is the institutional brain. Agents that ignore it are amnesic. Agents that use it inherit 31,775 holons of accumulated wisdom from every prior session.

> मत्तः स्मृतिर्ज्ञानम् — From Me come memory and knowledge (Gita 15.15)
