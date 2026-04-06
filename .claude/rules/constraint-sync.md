# Constraint Synchronization (SC-SYNC-DOC)
**CLAUDE.md MUST be the authoritative superset of ALL constraints in code.** Code MUST NEVER contain undocumented constraints. NEVER remove constraints from docs because code doesn't reference them.
# STAMP Constraints
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
| SC-SYNC-DOC-011 | Claude MUST use F# constraint sync engine for all sync ops | CRITICAL |
| SC-SYNC-DOC-012 | Claude SHALL NOT use ad-hoc rg commands for constraint census | HIGH |
| SC-SYNC-DOC-013 | F# script is the SOLE authoritative census engine | CRITICAL |
| SC-SYNC-DOC-014 | Reconciliation MUST only run once per week (7-day gate) | HIGH |
| SC-SYNC-DOC-015 | Analysis results auto-cached to .claude/constraint_sync_cache.json | HIGH |
| SC-SYNC-DOC-016 | --cached mode reads from cache without re-scanning | HIGH |
# Health Thresholds
- **HEALTHY**: Gap ratio <= 1.5:1
- **DEGRADED**: Gap ratio 1.5:1 to 5:1
- **CRITICAL**: Gap ratio > 5:1
# F# Sync Engine (AUTHORITATIVE — no Rust replacement)
The constraint census engine remains F#. Unlike sa-plan (replaced by Rust `sa-plan-daemon`),
`Cepaf.ConstraintSync` has no Rust equivalent. Use dotnet commands below.
**Compiled binary (preferred, 5-35x faster)**:
```bash
dotnet build lib/cepaf/src/Cepaf.ConstraintSync/Cepaf.ConstraintSync.fsproj -c Release
BIN=lib/cepaf/src/Cepaf.ConstraintSync/bin/Release/net10.0/constraint-sync.dll
dotnet exec $BIN              # Dashboard (~500ms)
dotnet exec $BIN --gaps       # Gap analysis
dotnet exec $BIN --reconcile  # Weekly reconciliation (7-day gate)
dotnet exec $BIN --analysis   # Full analysis + FMEA
dotnet exec $BIN --cached     # Cached results (~57ms)
dotnet exec $BIN --inventory  # .claude/ inventory
dotnet exec $BIN --record     # Record sync timestamp
```
**Fallback (fsx, ~2.5s)**: `dotnet fsi scripts/verification/constraint_sync.fsx [-- --flags]`
**Forbidden**: ad-hoc `rg "SC-[A-Z]+-[0-9]+"` for counting, manual grep, any script other than the F# engine.
# FMEA
RPN = Severity x Occurrence x Detection. Severity: P0=9, P1=7, P2=5, P3=3. RPN >= 200 requires immediate action.
# Baseline (2026-03-22, PARITY ACHIEVED)
SC: 2,257 in code / 2,297 in docs (1.0:1) | AOR: 480 in code / 663 in docs (0.7:1) | Health: HEALTHY | Coverage: 100% | Doc Debt: 0
# Reconciliation Protocol
P0 (CRITICAL): SC-SIL*, SC-IMMUNE*, SC-CONST*, SC-PRIME* | P1 (HIGH): SC-HOLON*, SC-REG*, SC-ZENOH*, SC-SYNC* | P2: Domain logic | P3: Style/linter