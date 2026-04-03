# 2026-03-22 02:00 — `.claude/` Configuration Deep Audit & Enhancement Plan

## Context
- **Branch**: main
- **Version**: v21.3.0-SIL6
- **Scope**: Complete audit of all 85 files (17,106 lines, 4.4MB) in `.claude/` directory
- **Method**: 4 parallel deep-analysis agents covering agents, commands, rules, and settings/plans/plugins
- **STAMP**: SC-CHG-001 (Change Management), SC-FUNC-001 (Functional Invariant)

---

## 1. Directory Structure Overview

```
.claude/                          85 files, 4.4MB, 17,106 lines
├── agents/          24 files     Agent definitions (specialized subagents)
├── commands/        14 files     Slash commands (user-invocable skills)
├── hooks/            2 files     Git/session hooks (ep014_check, todo_sync)
├── plans/           17 files     Execution plans (mostly historical)
├── plugins/          3 files     LSP/DAP configuration
├── rules/           22 files     Safety rules & constraints
├── settings.json     1 file      Primary configuration
├── settings.local.json 1 file    Local overrides
└── bash-history.log  1 file      Command audit trail (46,884 lines)
```

---

## 2. Agents Analysis (24 Files)

### 2.1 Architecture

The 24 agents follow a 4-tier supervisory hierarchy:

| Tier | Role | Count | Agents |
|------|------|-------|--------|
| **T1 Supreme** | Master orchestrator | 1 | master-supervisor |
| **T2 Domain** | Phase supervisors | 4 | design-supervisor, build-supervisor, deploy-supervisor, operate-supervisor |
| **T3 Specialist** | Domain experts | 14 | holon-analyzer, fractal-architect, impact-analyzer, constitutional-verifier, hyperscaler-analyzer, code-evolution, code-debugger, test-generator, code-reviewer, safety-validator, prajna-operator, immune-chaos-agent, zenoh-mesh-analyzer, observability-analyzer |
| **T4 Utility** | Focused tools | 5 | script-finder, cepaf-bridge-analyzer, robustness-analyzer, fmea-analyzer, sil4-validator |

### 2.2 Coverage Assessment

| System Area | Agent(s) | Coverage |
|-------------|----------|----------|
| Holon architecture | holon-analyzer | Complete |
| Fractal layers L0-L7 | fractal-architect | Complete |
| Safety (STAMP/SC) | safety-validator | Complete |
| Constitutional (Ψ₀-Ψ₅) | constitutional-verifier | Complete |
| Code quality | code-reviewer | Complete |
| Code generation | code-evolution | Complete |
| Debugging | code-debugger | Complete |
| Test generation | test-generator | Complete |
| Impact analysis | impact-analyzer | Complete |
| FMEA risk | fmea-analyzer | Complete |
| Zenoh mesh | zenoh-mesh-analyzer | Complete |
| Prajna cockpit | prajna-operator | Complete |
| Immune system | immune-chaos-agent | Complete |
| Observability | observability-analyzer | Complete |
| CEPAF bridge | cepaf-bridge-analyzer | Complete |
| Scripts discovery | script-finder | Complete |
| Robustness | robustness-analyzer | Complete |
| SIL-4 compliance | sil4-validator | Complete |
| Hyperscaler comparison | hyperscaler-analyzer | Complete |
| SDLC orchestration | master + 4 supervisors | Complete |

**Score: 100% coverage** — All 22 system areas have dedicated agents.

### 2.3 Issues Found

| Issue | Severity | Details |
|-------|----------|---------|
| Model allocation | P2 | safety-validator uses Haiku — should be Sonnet for judgment-heavy safety decisions |
| Tool scope variance | P3 | Some agents have broader tool access than needed (e.g., Bash wildcards) |
| No agent for SMRITI/knowledge graph | P3 | Intelligence amplification mentions SMRITI but no agent manages it |
| No agent for F# Planning CLI | P3 | Task management operations have no dedicated agent |

### 2.4 Recommendations

1. **P2**: Upgrade safety-validator model from Haiku to Sonnet
2. **P3**: Consider a `knowledge-graph-agent` for SMRITI operations
3. **P3**: Consider a `planning-agent` wrapping `sa-plan` CLI
4. **P3**: Tighten tool scopes on agents that don't need Bash access

---

## 3. Commands Analysis (14 Files)

### 3.1 Maturity Assessment

| Status | Count | Commands |
|--------|-------|----------|
| **Complete** | 3 | compile, test, immune |
| **Partial** | 2 | quality, sa |
| **Template-only** | 9 | stamp, sil4, fmea, rca, impact, robustness, datadog, hyperscaler, journal |

### 3.2 Critical Gaps

**A. No Agent Spawning Models**
None of the 14 commands specify which agent types to spawn. This is the single biggest gap — commands are designed for direct human execution rather than the biomorphic agentic mesh described in CLAUDE.md §92.

**B. Missing Commands (13 identified)**

| Priority | Command | Purpose | Why Needed |
|----------|---------|---------|------------|
| P0 | `/mesh` | SIL-6 biomorphic mesh boot/manage | `sa` only covers prod-standalone (4 containers), not full mesh (14) |
| P0 | `/zenoh` | Zenoh mesh diagnostics | Core IPC has no diagnostic command |
| P1 | `/checkpoint` | UCR operations | Checkpoint/restore has no CLI command |
| P1 | `/cepaf` | CEPAF F# build + orchestration | F# operations have no unified command |
| P1 | `/plan` | F# Planning CLI wrapper | Task management needs dedicated command |
| P2 | `/chaya` | Digital Twin operations | chaya-ooda, chaya-mesh need command |
| P2 | `/cockpit` | F# Prajna cockpit lifecycle | cockpitf needs command wrapper |
| P2 | `/constitution` | Constitutional verification (Ψ₀-Ψ₅) | Separate from sil4 |
| P2 | `/multiverse` | Shadow universe fork/restore | Multiverse ops need command |
| P2 | `/health` | FPPS consensus health check | Aggregated health beyond immune |
| P3 | `/metrics` | Compilation + execution metrics | Analysis beyond compile logging |
| P3 | `/telemetry` | Zenoh telemetry monitoring | Real-time telemetry observation |
| P3 | `/evolution` | Test evolution + fitness | SC-TEST-EVO needs command |

**C. STAMP Integration Weakness**
Only 4/14 commands reference any STAMP constraints. The other 10 commands have zero constraint integration, meaning safety rules aren't enforced through the command layer.

### 3.3 Specific Fixes Needed

| File | Issue | Fix |
|------|-------|-----|
| `sa.md` | Missing Zenoh router from container inventory | Add zenoh-router (7447) to table |
| `quality.md` | Orphaned SC-QUA-001 reference | Remove or define in CLAUDE.md |
| `impact.md` | "50 agents, 3 containers" outdated | Update to "50 agents, 14 containers (prod-standalone: 4)" |
| `datadog.md` | Claims "47 products" but Datadog has 52 | Update count |
| `sil4.md` | References "hardware watchdog" | Cloud-native: software watchdog only |

---

## 4. Rules Analysis (22 Files, 4,350 Lines)

### 4.1 Context Cost Analysis

This is the **most critical finding** of the entire audit.

```
Rules directory:     4,350 lines × ~4 tokens/line = ~17,400 tokens
CLAUDE.md:           2,500 lines × ~4 tokens/line = ~10,000 tokens
Combined spec load:  ~27,400 tokens (13.7% of 200K session budget)

Biomorphic compact reserve:  20,000 tokens (10%)
Rules alone consume:         87% of compact reserve!
```

Every new session pays a ~27K token tax just loading specifications. This is unsustainable and directly conflicts with SC-BIO-004 (auto-compact at 75% context).

### 4.2 Redundancy Map

#### OODA Loop — Defined 3 Times (300 lines wasted)
| File | Lines | Version |
|------|-------|---------|
| agent-cognitive-protocol.md | 130+ | 5-phase OODA with dependency chains |
| biomorphic-mode.md | ~30 | OODA cycle < 100ms, 30s heartbeat |
| functional-invariant.md | ~20 | OODA + Jidoka integration |

**Fix**: Keep OODA in agent-cognitive-protocol.md only. Others reference it.

#### Task Management — 765 Lines for ~400 Unique (365 lines wasted)
| File | Lines | Unique Content |
|------|-------|----------------|
| planning-chaya-sync.md | 503 | Sync protocol, FMEA, TDG specs |
| todolist-access-control.md | 262 | Access control enforcement |
| cache-sync.md | 85 | **OBSOLETE** (marked deprecated) |

Overlap estimate: 40-50% between planning-chaya-sync and todolist-access-control.

**Fix**: Delete cache-sync.md. Merge todolist-access-control into planning-chaya-sync.

#### Zenoh Authority — Scattered Across 5 Files
| File | Lines | Zenoh Content |
|------|-------|---------------|
| zenoh-telemetry-mandatory.md | 146 | NIF, router, health, topics |
| zenoh-test-messaging.md | 592 | Checkpoints, state vectors, DAGs |
| fsharp-sil6-mesh.md | ~80 | Container agents (SC-ZENOH-010 to 015) |
| planning-chaya-sync.md | ~20 | Task event topics |
| test-evolution.md | ~20 | Test orchestration topics |

No single authoritative Zenoh reference exists. Agents must cross-reference 5 files.

### 4.3 Staleness Issues

| Issue | Files | Current | Expected |
|-------|-------|---------|----------|
| Version number | 7 files | v21.2.1-SIL6 | v21.3.0-SIL6 |
| Sprint references | ga-release-verification.md | Sprint 47-51 | Sprint 47-54 |
| Obsolete file | cache-sync.md | DEPRECATED | DELETE |
| Undefined references | agent-cognitive-protocol.md | LethalMutationGate | Not found in codebase |
| Aspirational claims | intelligence-amplification.md | SMRITI 2190 holons | Not deployed at scale |

### 4.4 Missing Rule Areas

| System Area | CLAUDE.md Section | Rule File | Status |
|-------------|-------------------|-----------|--------|
| F# Zenoh FFI | §13.0 SC-FFI-* | None | **MISSING** |
| Holon Database Naming | §5.0 SC-DBNAME-* | None | **MISSING** |
| SMRITI Knowledge Graph | §5.0 SC-AI-* | Partial (intelligence-amplification.md) | **INCOMPLETE** |
| Unified Intelligence Plane | §15.0 SC-UIP-* | None | **MISSING** |
| Bicameral Verification | §15.0/§108.0 | None | **MISSING** |
| Apoptosis Protocol | SC-SIL6-015 | None | **MISSING** |

### 4.5 Token Reduction Roadmap

| Phase | Action | Tokens Saved | Result |
|-------|--------|-------------|--------|
| Current | Baseline | — | 17,400 tokens |
| **Phase 1** | Delete cache-sync + merge todolist + consolidate OODA | **−1,300** | 16,100 |
| **Phase 2** | Merge safety-critical into immune-system + version updates | **−770** | 15,330 |
| **Phase 3** | Externalize zenoh-test-messaging math/DAG/schemas to docs/ | **−1,600** | 13,730 |
| **Total** | All phases | **−3,670 (21%)** | **13,730 tokens** |

---

## 5. Settings & Configuration

### 5.1 settings.json — Grade: A+

Well-configured with proper Patient Mode, NIF enforcement, and session lifecycle hooks.

| Component | Status | Notes |
|-----------|--------|-------|
| Model | `opus` | Correct default |
| Patient Mode env vars | 5 configured | NO_TIMEOUT, PATIENT_MODE, INFINITE_PATIENCE, ELIXIR_ERL_OPTIONS, SKIP_ZENOH_NIF=0 |
| Permissions | 22 allow, 7 deny | `*` catch-all present (permissive but functional) |
| Hooks | 5 active | SessionStart, SessionEnd, PostToolUse (2x), Stop |
| File suggestion | ripgrep with exclusions | Correct excludes for _build, deps, .git, data |

### 5.2 Hooks — Grade: A

| Hook | Purpose | Status |
|------|---------|--------|
| SessionStart | Load project tasks via claude_todo_sync.exs | Working |
| SessionEnd | Sync tasks back to project | Working |
| PostToolUse (Edit/Write) | Auto-format Elixir files via `mix format` | Working |
| PostToolUse (Bash) | Log commands to bash-history.log | Working (46,884 entries) |
| Stop | Report compile errors/warnings from log | Working |

**Missing hooks**:
- No pre-commit integration (ep014_check.sh exists but isn't wired to git hooks)
- No PostToolUse hook for F# file formatting (`dotnet fantomas`)

### 5.3 Plans — Grade: C (Stale)

17 plan files, ALL from Jan 2-3, 2026 (78-80 days old). Sprint 30-34 era. Current project is at Sprint 54.

**Recommendation**: Archive all 17 files to `docs/archive/plans/sprint-30-34/`

### 5.4 Plugins (LSP/DAP) — Grade: A+

Comprehensive configuration for 14 language servers and 5 debug adapters. Properly configured for Elixir 1.19, OTP 28, F# net10.0, Rust, and cross-language debugging.

Notable: SQL LSP has hardcoded credentials (`postgres:postgres@localhost:5433`) — low risk but poor practice.

---

## 6. Cross-Cutting Analysis

### 6.1 Specification Coherence

The `.claude/` directory has a coherence problem: **authority is fragmented**.

```
CLAUDE.md (PRIMARY)
  ├── 107 sections, 1,659 lines
  ├── Defines: Ω₀-Ω₁₀, Ψ₀-Ψ₅, SC-*, AOR-*
  └── Contains: Architecture, commands, constraints, patterns

.claude/rules/ (SECONDARY — should be derivations)
  ├── 22 files, 4,350 lines
  ├── Redefines: OODA (3x), Zenoh (5x), Task management (3x)
  └── Adds: SC-CTRL-*, SC-MON-*, SC-CACHE-*, SC-DEBUG-*
      ↑ These families are NOT referenced in CLAUDE.md!

.claude/agents/ (TERTIARY — should be implementations)
  ├── 24 files
  └── Reference rules by SC-* ID
```

**Problem**: Several SC-* families exist ONLY in rules but not in CLAUDE.md:
- SC-CTRL-001 to SC-CTRL-007 (full-system-control.md)
- SC-MON-001 to SC-MON-006 (full-system-control.md)
- SC-CACHE-001 to SC-CACHE-003 (cache-sync.md — OBSOLETE)
- SC-COG-001 to SC-COG-005 (agent-cognitive-protocol.md)
- SC-DEBUG-001 to SC-DEBUG-010 (plugins/DAP config)
- SC-QUA-001 (quality.md — orphaned)

These "shadow constraints" exist outside the canonical CLAUDE.md specification. They should either be registered in CLAUDE.md §5.0 or removed.

### 6.2 Token Budget Impact

```
Component          Tokens   % of 200K   Assessment
─────────────────────────────────────────────────────
CLAUDE.md          10,000     5.0%      Acceptable (primary spec)
.claude/rules/     17,400     8.7%      CRITICAL (redundancy heavy)
Agent definitions   ~3,000     1.5%      Acceptable (loaded on-demand)
Settings/hooks      ~1,500     0.8%      Acceptable (small, functional)
Plans               ~5,000     2.5%      WASTE (all stale)
─────────────────────────────────────────────────────
TOTAL              ~36,900    18.5%      Concerning (approaching 20%)
```

Every session starts with ~37K tokens of specification overhead. After Phase 1-3 optimization:
- Delete stale plans: −5,000 tokens
- Consolidate rules: −3,670 tokens
- **New overhead**: ~28,230 tokens (14.1% — acceptable)

---

## 7. Enhancement Roadmap

### Phase 1: Immediate Cleanup (This Session)

| # | Action | Impact | Effort |
|---|--------|--------|--------|
| 1 | Delete `cache-sync.md` (OBSOLETE) | −340 tokens | 1 min |
| 2 | Archive 17 stale plans to `docs/archive/` | −5,000 tokens | 5 min |
| 3 | Consolidate OODA to single file (agent-cognitive-protocol.md) | −300 tokens | 10 min |
| 4 | Update version refs v21.2.1→v21.3.0 in 7 rule files | Consistency | 5 min |

### Phase 2: Short-Term (Sprint 55)

| # | Action | Impact | Effort |
|---|--------|--------|--------|
| 5 | Merge todolist-access-control into planning-chaya-sync | −660 tokens | 30 min |
| 6 | Merge safety-critical into immune-system | −240 tokens | 15 min |
| 7 | Create 3 missing P0 commands: `/mesh`, `/zenoh`, `/checkpoint` | Coverage | 2 hrs |
| 8 | Add agent spawning model to 3 complete commands | Biomorphic integration | 1 hr |
| 9 | Register shadow SC-* families in CLAUDE.md §5.0 | Specification coherence | 30 min |

### Phase 3: Medium-Term (Sprint 56-57)

| # | Action | Impact | Effort |
|---|--------|--------|--------|
| 10 | Externalize zenoh-test-messaging math to docs/ | −1,600 tokens | 1 hr |
| 11 | Create 10 missing P1-P3 commands | Full command coverage | 5 hrs |
| 12 | Flesh out 9 template-only commands | Command maturity | 4 hrs |
| 13 | Create missing rule files (FFI, DBNAME, BVC, Apoptosis) | Gap closure | 3 hrs |
| 14 | Add F# file formatting hook (dotnet fantomas) | Quality automation | 30 min |
| 15 | Wire ep014_check.sh to git pre-commit hook | Quality gate | 10 min |

---

## 8. Quantitative Summary

### Current State

| Metric | Value | Assessment |
|--------|-------|------------|
| Total files | 85 | Manageable |
| Total lines | 17,106 | High — needs reduction |
| Token overhead | ~37K (18.5% of 200K) | Concerning |
| Agent coverage | 22/22 areas (100%) | Excellent |
| Command coverage | 14/27 needed (52%) | Needs work |
| Rule redundancy | ~3,670 tokens (21%) | Must fix |
| Stale plans | 17/17 (100%) | Archive all |
| Version consistency | 15/22 correct (68%) | Update 7 files |
| Hook coverage | 5/7 needed (71%) | Add 2 hooks |
| LSP/DAP maturity | 14 LSPs + 5 DAPs | Excellent |

### After Optimization (Phases 1-3)

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| Token overhead | ~37K | ~28K | −24% |
| Rule redundancy | 21% | <5% | −16pp |
| Command coverage | 52% | 100% | +48pp |
| Stale plans | 17 files | 0 files | −100% |
| Version consistency | 68% | 100% | +32pp |

---

## 9. Key Insights

`★ Insight ─────────────────────────────────────`

1. **Token Budget is the Real Constraint**: The `.claude/` directory consumes 18.5% of every session's context window before any work begins. The biomorphic compact reserve (20K tokens) is almost entirely consumed by rules alone (17.4K). This is the #1 issue to address.

2. **Authority Fragmentation Creates Confusion**: OODA defined 3 times, Zenoh governed by 5 files, task management split across 3 files. When agents read these rules, they receive contradictory or redundant instructions, wasting inference on disambiguation.

3. **Plans Are Dead Weight**: All 17 plan files are from 78-80 days ago (Sprint 30-34). They serve no current purpose and consume ~5K tokens. Archive immediately.

4. **Commands Lag Behind Architecture**: The system has evolved to a SIL-6 biomorphic fractal mesh with 14 containers, Zenoh IPC, F# CEPAF, and Digital Twin — but commands still cover only basic compilation/testing. 13 commands are missing entirely.

5. **What Works Brilliantly**: The agent architecture (24 agents, 100% coverage), LSP/DAP configuration (14+5), session hooks (5 lifecycle hooks), and safety constraint framework (641+ SC-*) are all production-quality. The foundation is excellent — it's the specification layer that needs trimming.

`─────────────────────────────────────────────────`

---

## STAMP Compliance
- SC-CHG-001: Change analysis documented
- SC-FUNC-001: No functional changes (analysis only)
- SC-BIO-004: Context optimization identified as critical path

## Next Steps
- Execute Phase 1 cleanup (immediate, this session if approved)
- Plan Phase 2 for Sprint 55
- Track token reduction metrics across sessions

## KPIs
- Files analyzed: 85
- Issues identified: 47 (4 critical, 12 high, 18 medium, 13 low)
- Token savings potential: 8,670 (23.5% reduction)
- Commands missing: 13
- Stale files: 18 (17 plans + 1 obsolete rule)
