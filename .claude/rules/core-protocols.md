# Core Safety & Protection Protocols

## 1. Functional Invariant (SC-FUNC-000)

**THE SYSTEM MUST ALWAYS BE IN A FUNCTIONAL STATE.** Derives from Psi-0 (Existence), Omega-0 (Founder's Directive).

| ID | Constraint | Severity |
|----|------------|----------|
| SC-FUNC-001 | System MUST compile at all times | INFINITE |
| SC-FUNC-002 | Core services MUST be operational | CRITICAL |
| SC-FUNC-003 | Rollback path MUST exist for every change | CRITICAL |
| SC-FUNC-004 | State MUST be recoverable from SQLite/DuckDB | CRITICAL |
| SC-FUNC-005 | Container stack MUST auto-heal | HIGH |
| SC-FUNC-006 | Quality gates MUST pass before merge | CRITICAL |
| SC-FUNC-007 | Zenoh mesh MUST maintain connectivity | HIGH |
| SC-FUNC-008 | Digital Twin MUST reflect actual state (30s sync) | HIGH |

**AOR-FUNC**: Verify compilation before commit. Checkpoint git before risky ops. Test locally before push. Monitor container health. Rollback on degradation. Log all mutations. Sync Digital Twin within 30s. HALT on invariant violation (Jidoka).

**OODA**: OBSERVE (functional?) -> ORIENT (delta from last good?) -> DECIDE (can maintain during change?) -> ACT (execute with rollback) -> FEEDBACK (update twin/telemetry)

**Fractal Cluster Default**: System starts/runs/stops ONLY in Fractal Cluster mode (db-prod + obs-prod + ex-app-1 minimum, Zenoh enabled, 10s health checks).

## 2. Deletion Safeguard (SC-DELETE)

**ALL untracked code files MUST be backed up before deletion.** (Incident 2026-03-24: ~30 untracked files lost, never committed.)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-DELETE-001 | Untracked code files MUST be backed up before deletion | CRITICAL |
| SC-DELETE-002 | File deletion MUST require explicit manual approval | CRITICAL |
| SC-DELETE-003 | Backup MUST be timestamped under data/tmp/backup/ | HIGH |
| SC-DELETE-004 | Build artifacts (.dot, .beam, .o) exempt from backup | MEDIUM |
| SC-DELETE-005 | git checkout -- on modified files MUST be preceded by git stash | HIGH |
| SC-DELETE-006 | git clean MUST use --dry-run first | CRITICAL |
| SC-DELETE-007 | Bulk deletion (>3 files) REQUIRES itemized approval | CRITICAL |

**Backup before delete**: `mkdir -p data/tmp/backup/$(date +%Y%m%d-%H%M%S) && cp -r <files> data/tmp/backup/.../`
**Exempt**: .dot .beam .o _build/ deps/ node_modules/ .elixir_ls/ .lexical/
**Never exempt**: .ex .exs .fs .fsx .fsproj .rs .toml .md .yml .yaml .json

## 3. Human Intent Protection (SC-HINT)

**Human-Specified Intent sections in page specs are INVIOLABLE.**

| ID | Constraint | Severity |
|----|------------|----------|
| SC-HINT-001 | Every page spec MUST contain `## Human-Specified Intent` section | CRITICAL |
| SC-HINT-002 | Agent MUST NEVER modify Human-Specified Intent section | CRITICAL |
| SC-HINT-003 | Agent MUST detect misalignment between code and human intent | HIGH |
| SC-HINT-004 | Human intent OVERRIDES all agent-generated sections | CRITICAL |
| SC-HINT-005 | Agent MUST report correlation score between code and intent | HIGH |
| SC-HINT-006 | Misalignment > 30% triggers P1 alert with detailed diff | HIGH |
| SC-HINT-007 | Section MUST have `<!-- HUMAN-ONLY: DO NOT AUTO-MODIFY -->` marker | CRITICAL |
| SC-HINT-008 | Agent MUST preserve human intent across all evolution cycles | CRITICAL |

**AOR-HINT**: Check for section before modifying specs. Verify byte-for-byte unchanged after modifications. Report alignment score in every audit. Flag EXPECTED vs AS-IS divergence. Require git blame for human authorship.

**Alignment Score**: `|EXPECTED intersect AS-IS| / |EXPECTED union AS-IS|` -- >=0.9 ALIGNED, 0.7-0.9 DRIFT, <0.7 MISALIGNED (P1 alert, block agent modifications).

**Forbidden**: Writing/deleting/regenerating/moving/renaming content inside `<!-- HUMAN-ONLY -->` block. Proceeding when section is absent (must create empty template).

**Template** (agent creates empty, human fills):
```markdown
## Human-Specified Intent
<!-- HUMAN-ONLY: DO NOT AUTO-MODIFY -->
### Functional Intent | ### UX Requirements | ### Safety Requirements | ### Override Instructions
<!-- END HUMAN-ONLY -->
```

**Wallaby integration**: Read human intent -> Read LiveView .ex -> Compute alignment -> If <0.7 HALT -> Else generate test. Include `Alignment Score` in @moduledoc.
