# Zettelkasten Operational Use Cases — Complete Taxonomy

**Version:** 1.0.0
**Date:** 2026-04-11
**Status:** COMPREHENSIVE ANALYSIS
**Evidence:** 2,710 tasks, 85 intents, 293 cached queries, 2,060 holons, 288 Gleam modules, 120 Rust modules
**STAMP:** SC-IKE-001, SC-SMRITI-131, SC-COG-001

---

## 1. SDLC Use Cases (Software Development Lifecycle)

The Zettelkasten participates in every SDLC phase — not as a tool used by developers, but as a **cognitive participant** that remembers, advises, and validates.

### 1.1 PLANNING PHASE

| UC-ID | Use Case | Process | Zettelkasten Role |
|-------|----------|---------|-------------------|
| SDLC-P01 | **Requirement Traceability** | New feature proposed → check if Allium spec exists | Search holons for matching entity/rule/contract. If none: "No spec exists for this — create Allium spec first" (SC-ALLIUM-001) |
| SDLC-P02 | **Impact Analysis** | Before changing a module → what depends on it? | Traverse code edges: "This module has 5 inbound edges from 3 test files and 2 production modules. Changing it affects these." |
| SDLC-P03 | **Effort Estimation** | How long will this take? | Search past journal entries for similar tasks: "Last time we implemented a Lustre page, it took 2 hours (journal 20260410). But this one touches L0 Constitutional, which historically takes 3x longer." |
| SDLC-P04 | **Priority Scoring** | Which task to work on next? | Knowledge-aware RETE-UL: combine task priority (P0-P3) with knowledge freshness (are the relevant docs up to date?) and dependency depth (how many other tasks block on this?) |
| SDLC-P05 | **Duplicate Detection** | Is this task already done? | FTS5 search against 2,710 tasks + 2,060 holons: "A similar feature was completed on 2026-04-10 (task ULTRA-F4). Are you sure this isn't a duplicate?" |
| SDLC-P06 | **Specification Completeness** | Does the plan cover all constraints? | Cross-reference plan zettel against constraint zettels: "Your plan mentions SC-ZENOH-001 but not SC-ZENOH-002 through SC-ZENOH-008. Missing 7 constraints." |

### 1.2 DESIGN PHASE

| UC-ID | Use Case | Process | Zettelkasten Role |
|-------|----------|---------|-------------------|
| SDLC-D01 | **Architecture Decision Records** | Record why a design choice was made | Ecosystem-level zettel with Axiom rhetorical function: "We chose SSR over client-side JS because SC-GLM-UI-002 mandates server-side rendering." Permanent. Slow decay. |
| SDLC-D02 | **Pattern Reuse** | Has this pattern been implemented before? | Search journal zettels for "Patterns & Anti-Patterns" sections: "The builder pattern (search.query().with_level().with_limit()) was used successfully in zettelkasten/search.gleam." |
| SDLC-D03 | **Allium Spec Authoring** | Write behavioral spec before code | Surface related Allium zettels: "43 existing Allium specs. The planning domain has entities: PlanningModel, PlanningDashboardModel, TaskCard. Reuse these types." |
| SDLC-D04 | **Constraint-Aware Design** | Ensure design complies before coding | Query constraint zettels by domain: "For Zenoh features, these 8 SC-ZENOH constraints apply: [list]. For L0 Constitutional, these 22 SC-SAFETY constraints apply: [list]." |
| SDLC-D05 | **Technology Radar** | What technologies are we using and why? | Aggregate code zettels by technology tag: "Gleam: 288 modules. Rust: 120 modules. Dependencies: Lustre 5.6, Wisp 2.2.2, Mist, Zenoh 1.0-rc5. Each with rationale from architecture zettels." |

### 1.3 IMPLEMENTATION PHASE

| UC-ID | Use Case | Process | Zettelkasten Role |
|-------|----------|---------|-------------------|
| SDLC-I01 | **Code Context** | Understand a module before modifying it | Surface the module's zettel: doc comments, STAMP refs, dependency graph, last modification date, who changed it, what tests cover it. |
| SDLC-I02 | **API Discovery** | Find the right function to call | FTS5 search across code zettels: "Functions accepting PlanningModel: planning.update(), planning.filtered_tasks(), planning.task_count_by_status(), mini_app.planning_view()." |
| SDLC-I03 | **Wiring Guard Compliance** | Adding a Model field → what else to update | Constraint zettel SC-WIRE-002: "Adding a field to ANY Model type MUST update wiring_guard.gleam in the SAME commit." Auto-surface when code zettel for a Model type changes. |
| SDLC-I04 | **Commit Message Generation** | Draft ICP v2.0 commit message | From code changes: "You modified 3 files in zettelkasten/. The git convention (zettel: git-commit-convention.md) says: `feat(cepaf): action — context`. Suggested: `feat(cepaf): add operations module — 25 use cases, 420 LOC`" |
| SDLC-I05 | **Auto-Zettel on Commit** | Every git commit becomes knowledge | Post-commit hook creates atomic zettel: sha, message, files changed, STAMP refs in the diff. Future: "What changed on April 10?" → reconstruct from commit zettels. |

### 1.4 TESTING PHASE

| UC-ID | Use Case | Process | Zettelkasten Role |
|-------|----------|---------|-------------------|
| SDLC-T01 | **Test Gap Analysis** | Which module has no tests? | Cross-reference code zettels against test zettels: "288 source modules, 81 test files. Module coverage: 99.7%. The only uncovered module is cepaf_gleam.gleam (main entry point)." |
| SDLC-T02 | **Test Priority by Risk** | Which tests matter most? | Combine FMEA RPN scores from rules zettels with code complexity: "Module cortex.gleam has RPN=252 (Critical) and 11 Msg variants. It should have 15-20 tests. Currently has 8. Gap: 7-12 tests." |
| SDLC-T03 | **Regression Context** | Test fails — what changed recently? | Search commit zettels + journal zettels: "This test started failing after commit a499ecd4 which modified cortex.rs gateway calls. The journal entry says: '56 broadcast_message signature fixes.'" |
| SDLC-T04 | **Coverage Math Validation** | Shannon entropy, CCM, ITQS gates | Coverage math zettels: "Current H=2.67 bits (target ≥2.5). CCM=0.770 (target ≥0.90). ITQS=0.736 (target ≥0.85). CCM and ITQS are below threshold — need more C3 Data Grid and C8 Action Button coverage." |
| SDLC-T05 | **Test Knowledge Capture** | Test results become knowledge | Auto-zettel from test runs: "3,786 passed, 0 failures. New: +30 zettelkasten use case tests. This is the 5th consecutive green run." Trends visible over time. |

### 1.5 DEPLOYMENT PHASE

| UC-ID | Use Case | Process | Zettelkasten Role |
|-------|----------|---------|-------------------|
| SDLC-X01 | **Pre-Deploy Checklist** | Verify all gates before deploying | Aggregate constraint zettels: "SC-FUNC-001 (compile): PASS. SC-FUNC-006 (quality gates): PASS. SC-SIL4-010 (DAG validation): PASS. SC-ZENOH-001 (Zenoh NIF): PASS. All 18 preflight checks: PASS." |
| SDLC-X02 | **Rollback Knowledge** | How to undo this deployment | Surface rollback zettels from change-management.md: "4-layer reversal: L1=git revert, L2=mix compile --force, L3=ecto rollback, L4=sa-checkpoint-restore." |
| SDLC-X03 | **Changelog Generation** | What's new in this release | Aggregate commit zettels since last tag: "v22.5.0-CORTEX → v22.6.0-BRAIN: 493 files, +61,318 lines. Features: Zettelkasten (9 modules), Telegram Mini App (6 modules), Indra's Net vision." |
| SDLC-X04 | **Version Alignment** | Are all artifacts at the same version? | Cross-reference version zettels: "mix.exs: 22.6.0. CLAUDE.md: 22.5.0-CORTEX (STALE). Cargo.toml: 22.5.0. GEMINI.md: 22.5.0 (STALE). 2 artifacts need version bump." |

### 1.6 FEEDBACK PHASE

| UC-ID | Use Case | Process | Zettelkasten Role |
|-------|----------|---------|-------------------|
| SDLC-F01 | **Post-Mortem Archive** | Incident RCA becomes permanent knowledge | Journal RCA sections → organism zettels with Evidence function. Searchable forever: "What went wrong with file deletion?" → March 24 RCA zettel. |
| SDLC-F02 | **User Feedback Capture** | Operator says "this is confusing" | Interaction zettel with "feedback" tag. Aggregated: "Operators have complained about the planning page 3 times. Common theme: static data, no live updates." |
| SDLC-F03 | **Metric Trending** | Are we getting better or worse? | Time-series from test result zettels + task completion zettels: "Tests: 1,559 → 3,756 (2.4x growth). Task velocity: 38/week → 50/week. Inference cost: $0.108/day → $0.054/day." |

---

## 2. SRE Use Cases (Site Reliability Engineering)

### 2.1 INCIDENT MANAGEMENT

| UC-ID | Use Case | Process | Zettelkasten Role |
|-------|----------|---------|-------------------|
| SRE-I01 | **Incident Pattern Matching** | Alert fires → has this happened before? | Search anomaly signature against incident zettels: "This CPU spike pattern matches the March 28 incident. RCA was: DuckDB C++ compilation during build. Resolution: throttle build parallelism." |
| SRE-I02 | **Runbook Surfacing** | Container down → what's the procedure? | FTS5 search for container name + "recovery": "For zenoh-router: 1) Check port 7447. 2) Verify Zenoh NIF loaded. 3) Restart via sa-up. See operational-architecture.md §2.2 for 7-tier boot." |
| SRE-I03 | **Blast Radius Assessment** | Service failing → what's affected? | Traverse dependency edges from failing holon: "zenoh-router failure affects: 4 quorum routers, 6 OODA-capable containers, all Zenoh telemetry, OTel span transport. Blast radius: 75% of mesh." |
| SRE-I04 | **MTTR Tracking** | How fast are we resolving incidents? | Aggregate incident zettels by resolution time: "Mean MTTR: 6 minutes. P95: 15 minutes. Fastest: 2 minutes (cache-related). Slowest: 45 minutes (network partition)." |
| SRE-I05 | **Incident Debrief** | After resolution → what did we learn? | Auto-create organism zettel from pipeline trace + resolution actions: "Incident tg-poll-49b5: CPU spike at 11:42. Classified as complex_query. Resolved by shifting to Gemini Direct. Learning: OpenRouter latency > 8s triggers cascade delay." |

### 2.2 CAPACITY & PERFORMANCE

| UC-ID | Use Case | Process | Zettelkasten Role |
|-------|----------|---------|-------------------|
| SRE-C01 | **Latency Baseline** | What's normal for this endpoint? | Aggregate trace zettels: "Pipeline P50: 3,582ms. P95: 6,127ms. P99: 8,458ms. Normal range for complex_query: 2,800-7,000ms. Above 7,000ms = anomaly." |
| SRE-C02 | **Cost Tracking** | How much is inference costing? | Aggregate model usage from trace zettels: "Gemini Direct: 11 calls × $0 = $0. OpenRouter: 50 calls × $0.009 = $0.45. Cached: 293 hits × $0 = $0. Total: $0.45/week." |
| SRE-C03 | **Cache Effectiveness** | Is the cache learning? | Track cache zettel growth: "Week 1: 100 entries, 50 hits. Week 4: 293 entries, 336 hits. Hit rate: 3.5x. Avg latency saved: 2,284ms per hit. Cache is learning effectively." |
| SRE-C04 | **Resource Forecast** | Will we hit capacity limits? | Project from trace zettels: "At current growth (12 intents/day), we'll hit 1,000 trace zettels in 83 days. SQLite can handle 100K+ rows. No capacity concern." |

### 2.3 RELIABILITY

| UC-ID | Use Case | Process | Zettelkasten Role |
|-------|----------|---------|-------------------|
| SRE-R01 | **Apoptosis Monitoring** | Is the stochastic lifecycle working? | Track death/resurrection zettels: "zenoh-router-2: 5 deaths, 5 resurrections. Mean lifespan: 68h (target: 72h). Recovery time: 5 minutes avg. Anti-fragility score: 0.87." |
| SRE-R02 | **Quorum Health** | Do we have enough healthy routers? | Aggregate container health zettels: "4 Zenoh routers. 3 healthy, 1 in scheduled apoptosis. Quorum: 3/4 = maintained. Next death: zenoh-router-2 in 4 hours." |
| SRE-R03 | **SLO Tracking** | Are we meeting service level objectives? | Compute from trace zettels: "Delivery SLO: 95% under 5 seconds. Actual: 92% (target missed). Root cause: 8% of OpenRouter calls exceed 6s. Action: increase cache TTL." |
| SRE-R04 | **Chaos Test Results** | How did the system respond to chaos? | Archive Mara chaos experiment results as organism zettels: "Mara experiment #7: killed db-prod container. System detected in 10s. Auto-recovery in 45s. No data loss. Grade: PASS." |

---

## 3. DEV Use Cases (Developer Experience)

### 3.1 ONBOARDING

| UC-ID | Use Case | Process | Zettelkasten Role |
|-------|----------|---------|-------------------|
| DEV-O01 | **System Overview** | New developer needs the big picture | Surface 5 ecosystem zettels: architecture overview, Penta-Stack, fractal layers, STAMP constraint families, Indra's Net vision. "Start here." |
| DEV-O02 | **Domain Glossary** | What does "apoptosis" mean in this system? | FTS5 search: "Apoptosis: Continuous Stochastic Apoptosis (chaos/apoptosis.gleam). 72h mean lifespan, log-normal distribution, max_concurrent_deaths=1. Purpose: anti-fragility through controlled container death." |
| DEV-O03 | **Codebase Map** | Where is the code for X? | Structured query: "Planning page → 3 modules: planning.gleam (67L, Model+update), planning_view.gleam (~400L, 8-panel HTML), planning_dashboard.gleam (~350L, DashboardModel). API: /api/v1/planning. TUI: tui/planning_view." |
| DEV-O04 | **Constraint Primer** | What rules must I follow? | Surface top constraint zettels by frequency of violation: "Most violated: SC-WIRE-003 (add param must update all call sites). Most critical: SC-FUNC-001 (must compile). Most referenced: SC-GLM-UI-001 (triple interface)." |
| DEV-O05 | **Historical Context** | Why does this code look like this? | Surface journal zettels for the relevant module: "cortex.gleam was modified on 2026-04-10 to add HITL approval. The journal says: 'HITL check in decide_next_action requires_approval → approval_queue.' See journal-20260410." |

### 3.2 DAILY WORKFLOW

| UC-ID | Use Case | Process | Zettelkasten Role |
|-------|----------|---------|-------------------|
| DEV-W01 | **Morning Briefing** | What happened while I was away? | Aggregate journal + commit + task zettels since last session: "Since your last session: 3 tasks completed, 1 new journal, 2 new Allium specs, 5 tests added. The big change: Zettelkasten brain implemented." |
| DEV-W02 | **Context Recovery** | Resuming work after interruption | Surface session summary zettels: "Your last session: you were implementing the Telegram Mini App. 6 modules created, 40 tests. Unfinished: wiring guard update for telegram modules." |
| DEV-W03 | **Code Review Context** | Reviewing someone else's PR | Surface relevant constraint + architecture zettels for the changed files: "This PR modifies cortex.rs. Relevant constraints: SC-COG-001, SC-ARCH-SPLIT-001. Architecture note: cortex is L5-Cognitive, must not contain L4-System logic." |
| DEV-W04 | **Debug Assistance** | "Why does this fail?" | Search error message against journal RCA sections + incident zettels: "'No gmail_username in Smriti' → This error occurred on 2026-04-10. RCA: UserPreferences table didn't exist in root Smriti.db. Fix: create table + sync credentials from sub-project." |
| DEV-W05 | **Dependency Awareness** | "If I change this, what breaks?" | Traverse edges from target module: "Changing planning.gleam affects: 3 test files, wiring_guard.gleam, module_coverage_test, mini_app.gleam (planning_view), and the Wisp API at /api/v1/planning." |

### 3.3 KNOWLEDGE CREATION

| UC-ID | Use Case | Process | Zettelkasten Role |
|-------|----------|---------|-------------------|
| DEV-K01 | **Decision Documentation** | Record why a choice was made | Create axiom zettel: "We chose FTS5 over embedding search for the initial Zettelkasten because: 1) FTS5 is built into SQLite (no external dependency), 2) < 1ms query time, 3) Embedding generation requires LLM API call." |
| DEV-K02 | **Pattern Discovery** | Notice a recurring pattern in the codebase | Create molecular zettel: "Pattern: All Lustre pages follow init() → update(model, msg) → view(model). The init() function is the canonical constructor. Tests should always use init(), not direct Model() constructors (SC-WIRE-007)." |
| DEV-K03 | **Anti-Pattern Warning** | Document a mistake to prevent recurrence | Create evidence zettel: "Anti-pattern: Calling gateway::broadcast_message without session arg. Occurred 56 times in cortex.rs. Root cause: signature changed but grep wasn't run on all callers. Prevention: Rust wiring guard test." |

---

## 4. System Ops Use Cases (Operations)

### 4.1 MESH ORCHESTRATION

| UC-ID | Use Case | Process | Zettelkasten Role |
|-------|----------|---------|-------------------|
| OPS-M01 | **Boot Sequence Knowledge** | Starting the 17-container mesh | Surface boot zettels: "7-tier boot hierarchy: 1) Zenoh router (7447), 2) DB (5433), 3) Observability (4317), 4) Quorum routers, 5) Cognitive (cortex + bridge), 6) Seed + twin, 7) HA + ML. See panoptic-swarm-ignition.md." |
| OPS-M02 | **Container Health Context** | Container degraded — what's the history? | Aggregate container zettels: "zenoh-router-2: born 68h ago, scheduled death in 4h. 3 previous lives. Mean recovery: 5 minutes. Last incident: none. Health trend: stable." |
| OPS-M03 | **Port Conflict Resolution** | Service won't start — port in use | Surface port assignment zettels: "Port 4100: Wisp HTTP (SC-GLM-UI-006). Port 4050: Wallaby test. Port 4051: Health plug test (HEALTH_PORT). Port 4000-4010: RESERVED for 16-container mesh." |
| OPS-M04 | **Network Topology** | How are containers connected? | Surface mesh zettels: "Network: indrajaal-sil6-mesh. Router: zenoh-router:7447. Clients: all app containers in client mode. Key expressions: indrajaal/health/*, indrajaal/otel/*, indrajaal/l5/cog/*." |
| OPS-M05 | **Upgrade Procedure** | Rolling upgrade across the mesh | Surface HA zettels: "SC-HA-001: SIL-6 availability. Procedure: 1) Drain primary, 2) Upgrade, 3) Verify, 4) Promote. Quorum maintained throughout. See ha/rolling_upgrade.gleam." |

### 4.2 BACKUP & DR

| UC-ID | Use Case | Process | Zettelkasten Role |
|-------|----------|---------|-------------------|
| OPS-B01 | **Backup Verification** | Was the backup successful? | Surface backup zettels: "Last backup: 2026-04-10 14:45. Size: 19.9MB (1,113 files). SHA-256 verified. GCS bucket: europe-north1. 3-tier classification: 78 critical, 234 high, 801 medium." |
| OPS-B02 | **Restore Procedure** | System needs recovery | Surface restore zettels: "sa-plan restore [source]. Options: latest, daily/YYYYMMDD-HHMMSS, weekly/YYYYMMDD-HHMMSS. Procedure: download → decompress → verify SHA-256 → PRAGMA integrity_check → replace." |
| OPS-B03 | **DR Test Results** | Did the last DR test pass? | Surface DR test zettels: "Last DR test: not performed. Recommendation: schedule monthly DR drill. Runbook: backup → destroy → restore → verify 17-container boot → compare state checksums." |

### 4.3 MONITORING & ALERTING

| UC-ID | Use Case | Process | Zettelkasten Role |
|-------|----------|---------|-------------------|
| OPS-A01 | **Alert Enrichment** | Alert fires — add context | When alert arrives, inject knowledge: "ALERT: Zenoh disconnected > 30s. CONTEXT: SC-ZENOH-005 (reconnect with backoff). Last disconnection: never (first occurrence). Runbook: check zenoh-router health, verify port 7447, restart if needed." |
| OPS-A02 | **Alert Fatigue Analysis** | Too many alerts — which matter? | Aggregate alert zettels: "Last 7 days: 0 critical, 2 high (both OpenRouter latency), 15 medium (routine entropy decay). Recommendation: suppress medium entropy alerts (they're working as designed)." |
| OPS-A03 | **Dashboard Context** | What does this metric mean? | When operator hovers over a metric: "CPU Governor: currently at 45% (Full Speed). Thresholds: <60% = full speed, 60-70% = slight reduction, 70-80% = moderate, 80-85% = heavy, >85% = WAIT. Source: SC-CPU-GOV-001." |

---

## 5. Evolutionary System Use Cases

The C3I system is designed to evolve. The Zettelkasten is the evolutionary memory — it tracks what changed, why, and what the system is becoming.

### 5.1 SELF-AWARENESS

| UC-ID | Use Case | Process | Zettelkasten Role |
|-------|----------|---------|-------------------|
| EVO-S01 | **System Autobiography** | Reconstruct the system's history | Temporal query across all holons: "April 1: 1,559 tests, 278 modules. April 10: 3,641 tests, 284 modules (+21 features, +DR backup, +wiring guard). April 11: 3,786 tests, 288 modules (+Zettelkasten brain, +Telegram Mini App)." |
| EVO-S02 | **Capability Inventory** | What can the system do? | Aggregate capability zettels: "13 feature domains, 47 MCP tools, 52 RETE-UL rules, 14 NIF bridges, 17 CLI commands, 14 Telegram Mini App pages, 49 Lustre pages, 23 TUI views, 6 data tables." |
| EVO-S03 | **Identity Verification** | Is the system what it claims to be? | Compare identity zettels (CLAUDE.md) against actual code zettels: "CLAUDE.md says 283+ modules. Actual: 288. CLAUDE.md says 3,354 tests. Actual: 3,786. Documentation is STALE — needs update." |
| EVO-S04 | **Aspiration Tracking** | How close are we to the vision? | Compare aspiration zettels (Ultrathink mandates) against completed task zettels: "10 Ultrathink features: 10/10 completed. Indra's Net vision: 0/7 phases implemented (Gleam logic done, UI not started)." |

### 5.2 KNOWLEDGE EVOLUTION

| UC-ID | Use Case | Process | Zettelkasten Role |
|-------|----------|---------|-------------------|
| EVO-K01 | **Entropy Landscape** | Which knowledge areas are stale? | Cluster entropy analysis: "Architecture cluster: avg entropy 0.15 (FRESH). Journal cluster: avg 0.35 (AGING). Constraints cluster: avg 0.05 (FRESH). Plans cluster: avg 0.60 (ROTTING — many outdated plans)." |
| EVO-K02 | **Knowledge Gap Map** | What don't we know? | Track search misses: "Operators asked about 'webhook' 3 times but no zettel exists. Asked about 'rate limiting' 2 times — zettel exists but is stale (entropy 0.7). Created knowledge gap report." |
| EVO-K03 | **Link Density Evolution** | Is the knowledge graph getting richer? | Monthly density tracking: "Month 1: 2,060 holons, ~5,000 edges, density 0.001. Projecting: Month 6: ~3,200 holons, ~35,000 edges, density 0.003. The graph is getting 3x denser — knowledge is connecting." |
| EVO-K04 | **Trust Calibration** | Are our trust scores accurate? | Compare trust-weighted RAG results against operator satisfaction: "Axiom zettels (trust 1.0) led to 95% satisfactory answers. Anecdote zettels (trust 0.3) led to 60% satisfactory. Trust scores are well-calibrated." |

### 5.3 SYSTEM EVOLUTION

| UC-ID | Use Case | Process | Zettelkasten Role |
|-------|----------|---------|-------------------|
| EVO-E01 | **Allium Spec Drift** | Has code diverged from behavioral spec? | Compare code zettels against Allium zettels: "planning.gleam has 4 Msg variants. Allium spec says PlanningModel should have filter: FilterState. Code has filter: TaskFilter. Naming drift detected." |
| EVO-E02 | **Constraint Evolution** | Are we adding/removing constraints? | Track constraint zettel count over time: "March 22: 2,257 SC-* constraints. April 11: still 2,257 (no new constraints added in 20 days). The constraint set is stable." |
| EVO-E03 | **Module Growth Rate** | How fast is the codebase growing? | Track code zettel creation: "March: 278 modules. April 10: 284 (+6). April 11: 288 (+4). Growth rate: ~2 modules/day during active sessions." |
| EVO-E04 | **Test Health Trend** | Are tests keeping up with code? | Compare test zettels against code zettels: "Code modules: 288. Test-covered: 287 (99.7%). Test count: 3,786. Tests per module: 13.1 avg. Trend: tests growing faster than code (good)." |
| EVO-E05 | **Formal Verification Coverage** | Are TLA+ specs keeping up? | Track formal spec zettels against feature zettels: "5 TLA+ specs covering: ChatPipeline, HitlApproval, PipelineTrace, InferenceCascade, LeaderElection. 18 Ultrathink features total. Formal coverage: 5/18 = 28%." |

### 5.4 SYMBIOTIC EVOLUTION

| UC-ID | Use Case | Process | Zettelkasten Role |
|-------|----------|---------|-------------------|
| EVO-Y01 | **Operator Learning Curve** | Is the operator getting faster? | Track interaction zettels over time: "Week 1: 5 min/day in app, 3 questions. Week 4: 2 min/day, 1 question. The operator is learning — fewer questions, faster interactions." |
| EVO-Y02 | **System Teaching Effectiveness** | Are onboarding zettels helping? | Track which onboarding zettels operators actually read (click-through from Obsidian): "Architecture overview: 12 views. STAMP primer: 8 views. Zenoh mesh: 3 views. Most effective: architecture overview." |
| EVO-Y03 | **Co-Evolution Score** | Are operator and system evolving together? | Composite metric: "Operator ask diversity: increasing (good — exploring more). System answer quality: improving (fewer hallucinations). Knowledge gap closure: 3 gaps filled this week. Symbiosis score: 87/100." |
| EVO-Y04 | **Feedback-Driven Evolution** | Operator complaints drive system changes | Link feedback zettels to task zettels: "Operator said 'planning page is static' → task created → live NIF data wired → test coverage added → feedback loop closed in 2 days." |

---

## 6. Cross-Cutting Use Cases

These span multiple domains:

| UC-ID | Use Case | Domains | Process |
|-------|----------|---------|---------|
| X01 | **Universal Search** | All | Any question → FTS5 across 2,060 holons → grounded answer in < 1ms |
| X02 | **Knowledge-Aware Chat** | SRE + Dev | Telegram/GChat query → RAG injects relevant zettels → LLM answers from system docs |
| X03 | **Proactive Surfacing** | SRE + Ops | Heartbeat cron checks entropy → surfaces rotting docs before they cause problems |
| X04 | **Cross-Domain Correlation** | All | "Why did latency spike AND a task get blocked at the same time?" → search reveals they share a Zenoh dependency |
| X05 | **Audit Trail** | SDLC + Compliance | Every change, decision, incident, interaction → permanent zettel. Complete audit trail from day 1 |

---

## 7. Summary

| Domain | Use Cases | Key Value |
|--------|-----------|-----------|
| **SDLC** | 22 (Planning 6, Design 5, Implementation 5, Testing 5, Deploy 4, Feedback 3) | Knowledge-driven development — every phase informed by institutional memory |
| **SRE** | 13 (Incident 5, Capacity 4, Reliability 4) | Precedent-based incident response, continuous SLO tracking |
| **DEV** | 13 (Onboarding 5, Workflow 5, Knowledge 3) | Self-teaching codebase, context recovery, decision documentation |
| **OPS** | 11 (Mesh 5, Backup 3, Monitoring 3) | Operational runbooks, boot sequence knowledge, alert enrichment |
| **EVOLUTIONARY** | 13 (Self-Awareness 4, Knowledge 4, System 5, Symbiotic 4) | System autobiography, aspiration tracking, co-evolution scoring |
| **CROSS-CUTTING** | 5 | Universal search, knowledge-aware chat, proactive surfacing |
| **TOTAL** | **77 use cases** | — |

All 77 use cases are enabled by the same infrastructure: 2,060 holons + FTS5 search + trust scoring + entropy decay + RETE-UL rules + RAG pipeline + edge graph.
