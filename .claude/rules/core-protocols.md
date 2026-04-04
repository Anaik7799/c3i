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

### AOR-FUNC Rules
| ID | Rule | Violation Response |
|----|------|-------------------|
| AOR-FUNC-001 | VERIFY compilation before ANY code commit | BLOCK commit |
| AOR-FUNC-002 | CHECKPOINT git state before risky operations | Require --force |
| AOR-FUNC-003 | TEST locally before pushing to remote | BLOCK push |
| AOR-FUNC-004 | MONITOR container health continuously | Alert + auto-restart |
| AOR-FUNC-005 | ROLLBACK immediately on functional degradation | Auto-rollback |
| AOR-FUNC-006 | LOG all state mutations to Immutable Register | Audit trail |
| AOR-FUNC-007 | SYNC Digital Twin within 30s of any change | State verification |
| AOR-FUNC-008 | HALT operations if functional invariant violated | Jidoka principle |

### Jidoka Protocol (on violation)
1. **STOP** — Immediately halt current operation
2. **SIGNAL** — Alert via Zenoh control plane
3. **ANALYZE** — 5-level RCA (5-Why methodology)
4. **FIX** — Root cause resolution with global view
5. **VERIFY** — Confirm functional state restored
6. **PREVENT** — Update constraints to prevent recurrence

### Operational Modes
- **Evolution Mode**: PRE: system functional → OPERATION: code change → POST: MUST remain functional → FAILURE: auto-rollback
- **Deployment Mode**: PRE: stack operational → OPERATION: deploy new version → POST: all containers healthy → FAILURE: rollback to previous image
- **Monitoring Mode**: 10s health checks, >10% degradation triggers alert, 5-level RCA for persistent failures

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

### AOR-DELETE Rules
| ID | Rule |
|----|------|
| AOR-DELETE-001 | ALWAYS run `git stash --include-untracked` before discarding untracked work |
| AOR-DELETE-002 | ALWAYS present deletion list to user before executing |
| AOR-DELETE-003 | NEVER use `rm -rf` on directories containing .ex, .fs, .rs, .md files without backup |
| AOR-DELETE-004 | ALWAYS create backup: `cp -r <file> data/tmp/backup/<timestamp>-<filename>` |
| AOR-DELETE-005 | Build artifacts (.dot, .dot.bak, _build/, deps/) are exempt |
| AOR-DELETE-006 | NEVER delete files during autonomous/bypass mode without backup |
| AOR-DELETE-007 | Log all deletions to session audit trail |

### Backup Protocol (5 steps)
1. Create: `mkdir -p data/tmp/backup/$(date +%Y%m%d-%H%M%S)`
2. Copy: `cp -r <files-to-delete> data/tmp/backup/.../`
3. Present list to user: "Files to be deleted (backed up to ...):"
4. **WAIT for explicit approval** — BLOCK until user confirms
5. Execute deletion ONLY after approval

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
