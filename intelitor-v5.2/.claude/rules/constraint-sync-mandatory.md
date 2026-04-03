# Constraint Synchronization Mandate (SC-SYNC-DOC)

## SUPREME MANDATE

**CLAUDE.md MUST be the authoritative superset of ALL constraints and rules in the codebase.**

Every SC-* constraint and AOR-* rule that exists in code MUST have a corresponding entry in CLAUDE.md (or a referenced `.claude/rules/*.md` file). CLAUDE.md is the **superset** — it may contain constraints not yet implemented in code, but code MUST NEVER contain undocumented constraints.

---

## 1.0 STAMP Constraints (SC-SYNC-DOC)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-SYNC-DOC-001 | CLAUDE.md SC-* set MUST be superset of code SC-* set | CRITICAL |
| SC-SYNC-DOC-002 | CLAUDE.md AOR-* set MUST be superset of code AOR-* set | CRITICAL |
| SC-SYNC-DOC-003 | Sync check MUST run on every Claude session start | CRITICAL |
| SC-SYNC-DOC-004 | Gap metrics MUST be published to session context | HIGH |
| SC-SYNC-DOC-005 | Weekly sync reconciliation MANDATORY (7-day gate) | HIGH |
| SC-SYNC-DOC-006 | .claude/rules/ MUST be audited for staleness daily | MEDIUM |
| SC-SYNC-DOC-007 | .claude/agents/ inventory MUST match agent definitions | MEDIUM |
| SC-SYNC-DOC-008 | .claude/commands/ inventory MUST match skill definitions | MEDIUM |
| SC-SYNC-DOC-009 | New code SC-*/AOR-* MUST be added to CLAUDE.md before commit | CRITICAL |
| SC-SYNC-DOC-010 | Sync gap ratio MUST trend toward 1.0 (parity) | HIGH |

---

## 2.0 AOR Rules (AOR-SYNC-DOC)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-SYNC-DOC-001 | On EVERY session start, run constraint census and publish gap metrics | SessionStart hook |
| AOR-SYNC-DOC-002 | When introducing NEW SC-* in code, ADD to CLAUDE.md in same commit | Pre-commit check |
| AOR-SYNC-DOC-003 | When introducing NEW AOR-* in code, ADD to CLAUDE.md in same commit | Pre-commit check |
| AOR-SYNC-DOC-004 | Daily: audit .claude/rules/*.md for stale/outdated content | Manual or automated |
| AOR-SYNC-DOC-005 | Daily: verify .claude/agents/*.md match subagent_type definitions | Manual or automated |
| AOR-SYNC-DOC-006 | Daily: verify .claude/commands/*.md match skill definitions | Manual or automated |
| AOR-SYNC-DOC-007 | Gap report format: `SC: {code_count}/{doc_count} ({gap_pct}%)` | Standardized |
| AOR-SYNC-DOC-008 | If gap ratio > 5:1, flag as P1 blocker for next sprint | Escalation |
| AOR-SYNC-DOC-009 | Reconciliation MUST NOT delete constraints from CLAUDE.md | Append-only docs |
| AOR-SYNC-DOC-010 | Reconciliation MUST add undocumented code constraints to CLAUDE.md | Additive sync |

---

## 3.0 Sync Direction (Critical)

```
AUTHORITATIVE DIRECTION:

  CLAUDE.md + .claude/rules/    ──── SUPERSET (authoritative)
        │                               │
        │  ⊇ (superset of)              │  Contains ALL constraints
        │                               │  including not-yet-implemented
        ▼                               │
  Code (SC-*/AOR-*)             ──── SUBSET (implementation)
                                        │
                                        │  Every code constraint MUST
                                        │  appear in docs
                                        │
                                        ▼
  Gap = Code \ Docs             ──── VIOLATION (must be zero)
```

**NEVER** remove a constraint from CLAUDE.md because code doesn't reference it — the code may not have implemented it yet. **ALWAYS** add code constraints to CLAUDE.md if they're missing.

---

## 4.0 Session Start Metric (Mandatory)

On every Claude Code session start, the following metrics MUST be computed and displayed:

```
╔═══════════════════════════════════════════════════════════════╗
║  CONSTRAINT SYNC STATUS (SC-SYNC-DOC)          [YYYY-MM-DD]  ║
╠═══════════════════════════════════════════════════════════════╣
║  SC-* Constraints:                                            ║
║    Code:     {N} unique across {F} families                   ║
║    Docs:     {M} unique across {G} families                   ║
║    Gap:      {N-M} undocumented ({pct}%)                      ║
║    Ratio:    {N/M}:1 (target: 1.0:1)                          ║
║                                                               ║
║  AOR-* Rules:                                                 ║
║    Code:     {N} unique across {F} families                   ║
║    Docs:     {M} unique across {G} families                   ║
║    Gap:      {N-M} undocumented ({pct}%)                      ║
║    Ratio:    {N/M}:1 (target: 1.0:1)                          ║
║                                                               ║
║  .claude/ Inventory:                                          ║
║    Rules:    {R} files                                        ║
║    Agents:   {A} definitions                                  ║
║    Commands: {C} skills                                       ║
║    Hooks:    {H} configured                                   ║
║                                                               ║
║  Last Full Sync: {date}                                       ║
║  Sync Health:    {HEALTHY|DEGRADED|CRITICAL}                  ║
╚═══════════════════════════════════════════════════════════════╝
```

Health thresholds:
- **HEALTHY**: Gap ratio ≤ 1.5:1
- **DEGRADED**: Gap ratio 1.5:1 to 5:1
- **CRITICAL**: Gap ratio > 5:1

---

## 5.0 Sync Checklist

### 5.0.1 Every Session (Automatic)
- [x] Bash hook publishes SC/AOR gap metrics on startup (~1s)
- [ ] Review gap metrics in session context

### 5.0.2 Weekly Reconciliation (7-day gate)
- [ ] Run `--reconcile` to generate reconciliation plan
- [ ] Count SC-* in code vs CLAUDE.md
- [ ] Count AOR-* in code vs CLAUDE.md
- [ ] Identify NEW undocumented families
- [ ] Add top-priority undocumented families to CLAUDE.md
- [ ] Update sync timestamp with `--record`

### 5.0.3 On Demand (Deep Analysis)
- [ ] Run `--analysis` for info theory, FMEA, STAMP, criticality
- [ ] Review RPN ≥ 200 families for immediate action
- [ ] Check P0/P1 coverage percentages

### 5.2 .claude/ Directory Audit
- [ ] Verify all `.claude/rules/*.md` are current (no stale references)
- [ ] Verify all `.claude/agents/*.md` definitions are valid
- [ ] Verify all `.claude/commands/*.md` skills are functional
- [ ] Check `.claude/hooks/` scripts execute without error
- [ ] Verify `.claude/settings.json` is well-formed

### 5.3 Cross-Reference Verification
- [ ] Rules reference valid STAMP IDs
- [ ] Agents reference valid module paths
- [ ] Commands reference valid CLI commands
- [ ] Hooks execute within timeout limits

---

## 6.0 Reconciliation Protocol

When gap is detected (code constraint not in docs):

### Step 1: Classify
```
Priority classification:
  P0 (CRITICAL): Safety constraints (SC-SIL*, SC-IMMUNE*, SC-CONST*, SC-PRIME*)
  P1 (HIGH):     Core system (SC-HOLON*, SC-REG*, SC-ZENOH*, SC-SYNC*)
  P2 (MEDIUM):   Domain logic (SC-KMS*, SC-AI*, SC-MCP*, SC-OBS*)
  P3 (LOW):      F# linter/style (SC-STYLE*, SC-UNUSED*, SC-DEPR*, SC-ENFORCE*)
```

### Step 2: Document
Add missing constraints to the appropriate location:
- **CLAUDE.md §5.0**: For constraints affecting system behavior
- **`.claude/rules/{domain}.md`**: For domain-specific constraints
- **Both**: For constraints referenced in multiple places

### Step 3: Verify
```bash
# Count after reconciliation
rg "SC-[A-Z]+-[0-9]+" lib/ test/ --only-matching | sort -u | wc -l   # Code
rg "SC-[A-Z]+-[0-9]+" CLAUDE.md .claude/rules/ --only-matching | sort -u | wc -l  # Docs
```

### Step 4: Record
Log sync event with timestamp, counts, and delta.

---

## 7.0 Enforcement

### 7.1 Mandatory F# Script (SC-SYNC-DOC-011)

**Claude agents MUST use the F# constraint sync engine for ALL constraint synchronization operations.** The compiled binary is preferred (5-35x faster); the fsx script is the fallback. No other tool, ad-hoc command, or manual approach is permitted.

| ID | Constraint | Severity |
|----|------------|----------|
| SC-SYNC-DOC-011 | Claude MUST use the F# constraint sync engine for all sync ops | CRITICAL |
| SC-SYNC-DOC-012 | Claude SHALL NOT use ad-hoc `rg` commands for constraint census | HIGH |
| SC-SYNC-DOC-013 | The F# script is the SOLE authoritative census engine | CRITICAL |
| SC-SYNC-DOC-014 | Reconciliation MUST only run once per week (7-day gate) | HIGH |
| SC-SYNC-DOC-015 | Analysis results MUST be auto-cached to `.claude/constraint_sync_cache.json` | HIGH |
| SC-SYNC-DOC-016 | `--cached` mode MUST read from cache without re-scanning codebase | HIGH |
| SC-FMEA-001 | FMEA analysis MUST run on every `--analysis` or `--full` invocation | CRITICAL |
| SC-FMEA-002 | RPN MUST use S×O×D formula (Severity × Occurrence × Detection) | CRITICAL |
| SC-FMEA-003 | Severity mapping: P0=9, P1=7, P2=5, P3=3 | HIGH |
| SC-FMEA-004 | RPN ≥ 200 MUST be flagged as critical requiring immediate action | CRITICAL |
| SC-FMEA-005 | FMEA results MUST be cached for fast retrieval via `--cached` | HIGH |
| SC-FMEA-006 | Top 15 FMEA entries MUST be persisted in cache JSON | HIGH |
| SC-FMEA-007 | Mitigation plan MUST be generated for RPN ≥ 100 | HIGH |
| SC-FMEA-008 | FMEA trend MUST be tracked in sync history JSONL | MEDIUM |
| AOR-SYNC-DOC-011 | On session start, bash hook publishes fast metrics (~1s) | SessionStart hook |
| AOR-SYNC-DOC-012 | For gap analysis, use `--gaps` flag ONLY (no manual grep) | Mandatory |
| AOR-SYNC-DOC-013 | For reconciliation planning, use `--reconcile` flag ONLY (weekly gate) | Mandatory |
| AOR-SYNC-DOC-014 | After reconciliation, run `--record` to log sync timestamp | Mandatory |
| AOR-SYNC-DOC-015 | For deep analysis, use `--analysis` flag (auto-caches results) | Mandatory |
| AOR-SYNC-DOC-016 | For fast cached results, use `--cached` flag (reads last run) | Mandatory |
| AOR-FMEA-001 | FMEA analysis MUST accompany every `--analysis` run | Mandatory |
| AOR-FMEA-002 | RPN ≥ 200 families MUST be prioritized for immediate reconciliation | Escalation |
| AOR-FMEA-003 | Severity: P0-SAFETY=9, P1-CORE=7, P2-DOMAIN=5, P3-STYLE=3 | Standard |
| AOR-FMEA-004 | Occurrence: ≥20 IDs=8, ≥10=6, ≥5=4, <5=2 | Standard |
| AOR-FMEA-005 | Detection: matches severity (undocumented = hard to detect) | Standard |
| AOR-FMEA-006 | FMEA results included in cache JSON for Claude fast retrieval | Automatic |
| AOR-FMEA-007 | Top 10 FMEA entries displayed in analysis dashboard | Display |
| AOR-FMEA-008 | Mean RPN increase triggers P1 escalation | Escalation |

**Engine Locations**:
- **Compiled binary (PREFERRED)**: `lib/cepaf/src/Cepaf.ConstraintSync/` → `constraint-sync.dll`
- **Script fallback**: `scripts/verification/constraint_sync.fsx`

**Authorized Commands (Compiled — 5-35x faster)**:
```bash
# Build once (required after code changes to Program.fs)
dotnet build lib/cepaf/src/Cepaf.ConstraintSync/Cepaf.ConstraintSync.fsproj -c Release

# All commands via compiled binary (~500ms census, ~57ms cached):
dotnet exec lib/cepaf/src/Cepaf.ConstraintSync/bin/Release/net10.0/constraint-sync.dll          # Dashboard
dotnet exec lib/cepaf/src/Cepaf.ConstraintSync/bin/Release/net10.0/constraint-sync.dll --json    # JSON
dotnet exec lib/cepaf/src/Cepaf.ConstraintSync/bin/Release/net10.0/constraint-sync.dll --gaps    # Gap analysis
dotnet exec lib/cepaf/src/Cepaf.ConstraintSync/bin/Release/net10.0/constraint-sync.dll --reconcile  # Weekly reconciliation
dotnet exec lib/cepaf/src/Cepaf.ConstraintSync/bin/Release/net10.0/constraint-sync.dll --inventory  # .claude/ inventory
dotnet exec lib/cepaf/src/Cepaf.ConstraintSync/bin/Release/net10.0/constraint-sync.dll --analysis   # Full analysis
dotnet exec lib/cepaf/src/Cepaf.ConstraintSync/bin/Release/net10.0/constraint-sync.dll --cached     # Cached results
dotnet exec lib/cepaf/src/Cepaf.ConstraintSync/bin/Release/net10.0/constraint-sync.dll --full       # Full report
dotnet exec lib/cepaf/src/Cepaf.ConstraintSync/bin/Release/net10.0/constraint-sync.dll --record     # Record sync
```

**Fallback Commands (fsx — ~2.5s, use when binary not built)**:
```bash
dotnet fsi scripts/verification/constraint_sync.fsx             # Dashboard
dotnet fsi scripts/verification/constraint_sync.fsx -- --cached  # Cached results
dotnet fsi scripts/verification/constraint_sync.fsx -- --full    # Full report
```

**Performance Comparison (2026-03-22)**:
| Mode | fsx (JIT) | Compiled | Speedup |
|------|-----------|----------|---------|
| `--cached` | 2.0s | 57ms | 35x |
| `--inventory` | 2.1s | 84ms | 25x |
| Dashboard | 2.5s | 500ms | 5x |
| `--analysis` | 2.7s | 506ms | 5x |
| `--full` | 2.9s | 517ms | 5.6x |

**FORBIDDEN ACTIONS ($\mathbb{F}_{SYNC}$)**:
1. `rg "SC-[A-Z]+-[0-9]+" lib/ test/ | sort -u | wc -l` → **VIOLATION** (use `--json` instead)
2. Manual `grep` for constraint counting → **VIOLATION**
3. Any ad-hoc script for constraint census → **VIOLATION**
4. Direct file reads of sync history → **VIOLATION** (use `--json` for current state)

### 7.2 SessionStart Hook
The bash script `scripts/verification/constraint_sync_check.sh` runs on every session start via `.claude/settings.json` SessionStart hook. It tries the compiled F# binary first (~500ms), falling back to bash `rg`-based counting (~1s) if the binary isn't built.

### 7.3 Pre-Commit (Future)
A pre-commit hook SHOULD verify that any new SC-*/AOR-* introduced in code has a corresponding CLAUDE.md entry.

### 7.4 Sprint Gate
Constraint sync gap ratio is a quality gate for sprint completion:
- Sprint CANNOT close if gap ratio increases
- Sprint SHOULD reduce gap by at least 10% if ratio > 2:1

---

## 8.0 Current Baseline (2026-03-22, Post-Full Reconciliation — PARITY ACHIEVED)

| Metric | Session Start | Post-P0/P1 | Post-Full | Target |
|--------|--------------|------------|-----------|--------|
| SC-* in code | 2,257 | 2,257 | 2,257 | — |
| SC-* in docs | 269 | 560 | **2,297** | ≥2,257 ✅ |
| SC-* gap ratio | 8.4:1 | 4.0:1 | **1.0:1** | ≤1.5:1 ✅ |
| SC-* families in code | 393 | 393 | 393 | — |
| SC-* families in docs | 62 | 97 | **395** | ≥393 ✅ |
| AOR-* in code | 480 | 480 | 480 | — |
| AOR-* in docs | 284 | 385 | **663** | ≥480 ✅ |
| AOR-* gap ratio | 1.7:1 | 1.2:1 | **0.7:1** | ≤1.5:1 ✅ |
| .claude/rules/ | 22 files | 24 files | **30 files** | Audit daily |
| .claude/agents/ | 24 defs | 24 defs | 24 defs | Audit daily |
| .claude/commands/ | 34 skills | 34 skills | 34 skills | Audit daily |
| .claude/hooks/ | 2 scripts | 2 scripts | 2 scripts | Audit daily |
| Health status | CRITICAL | DEGRADED | **HEALTHY** | HEALTHY ✅ |
| Coverage | 33.2% | ~60% | **100.0%** | 100% ✅ |
| Doc Debt | 5,373 | ~3,000 | **0** | 0 ✅ |
| KL Divergence | ~18 bits | ~8 bits | **0.009 bits** | →0 ✅ |
| FMEA RPN ≥ 200 | 5 | 5 | **0** | 0 ✅ |

**Full reconciliation delta (2026-03-22)**: +2,028 SC-* IDs documented, +379 AOR-* rules documented, +333 SC families, +86 AOR families. Health: CRITICAL → **HEALTHY**. All priorities (P0-P3) at 100% coverage. PARITY ACHIEVED.

---

## 9.0 Related Documents

- CLAUDE.md §5.0 — STAMP Constraints
- CLAUDE.md §9.0 — AOR Rules
- S59-T001 — STAMP Documentation Sync task
- `scripts/verification/constraint_sync.fsx` — F# census engine (AUTHORITATIVE)
- `scripts/verification/constraint_sync_check.sh` — Bash SessionStart hook (fast fallback)
- docs/journal/20260322-1400-genserver-supervisor-granularity-restructuring.md — Latest architectural journal
