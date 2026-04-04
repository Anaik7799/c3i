# Constraint Synchronization (SC-SYNC-DOC)

**CLAUDE.md MUST be the authoritative superset of ALL constraints in code.** Code MUST NEVER contain undocumented constraints. NEVER remove constraints from docs because code doesn't reference them.

## Key Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-SYNC-DOC-001 | CLAUDE.md SC-* set MUST be superset of code SC-* set | CRITICAL |
| SC-SYNC-DOC-002 | CLAUDE.md AOR-* set MUST be superset of code AOR-* set | CRITICAL |
| SC-SYNC-DOC-009 | New code SC-*/AOR-* MUST be added to CLAUDE.md before commit | CRITICAL |
| SC-SYNC-DOC-011 | Claude MUST use F# constraint sync engine for all sync ops | CRITICAL |
| SC-SYNC-DOC-012 | Claude SHALL NOT use ad-hoc rg commands for constraint census | HIGH |

## F# Sync Engine (AUTHORITATIVE)

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

## FMEA
RPN = Severity x Occurrence x Detection. Severity: P0=9, P1=7, P2=5, P3=3. RPN >= 200 requires immediate action.

## Baseline (2026-03-22, PARITY ACHIEVED)
SC: 2,257 in code / 2,297 in docs (1.0:1) | AOR: 480 in code / 663 in docs (0.7:1) | Health: HEALTHY | Coverage: 100% | Doc Debt: 0

## Reconciliation Protocol
P0 (CRITICAL): SC-SIL*, SC-IMMUNE*, SC-CONST*, SC-PRIME* | P1 (HIGH): SC-HOLON*, SC-REG*, SC-ZENOH*, SC-SYNC* | P2: Domain logic | P3: Style/linter
