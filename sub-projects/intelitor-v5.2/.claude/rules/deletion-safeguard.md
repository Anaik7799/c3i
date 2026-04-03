---
paths: "**/*"
---

# Deletion Safeguard Protocol (SC-DELETE)

## SUPREME MANDATE

**ALL untracked files with code content MUST be backed up and manually approved before deletion.**

This rule applies even when agents operate in bypass permissions mode.

## STAMP Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-DELETE-001 | Untracked code files MUST be backed up before deletion | CRITICAL |
| SC-DELETE-002 | File deletion MUST require explicit manual approval | CRITICAL |
| SC-DELETE-003 | Backup MUST be timestamped under data/tmp/backup/ | HIGH |
| SC-DELETE-004 | Build artifacts (.dot, .beam, .o) exempt from backup | MEDIUM |
| SC-DELETE-005 | git checkout -- on modified files MUST be preceded by git stash | HIGH |
| SC-DELETE-006 | git clean operations MUST use --dry-run first and show results | CRITICAL |
| SC-DELETE-007 | Bulk deletion (>3 files) REQUIRES itemized approval | CRITICAL |

## AOR Rules

| ID | Rule |
|----|------|
| AOR-DELETE-001 | ALWAYS run `git stash --include-untracked` before discarding untracked work |
| AOR-DELETE-002 | ALWAYS present deletion list to user before executing |
| AOR-DELETE-003 | NEVER use `rm -rf` on directories containing .ex, .fs, .rs, .md files without backup |
| AOR-DELETE-004 | ALWAYS create backup: `cp -r <file> data/tmp/backup/<timestamp>-<filename>` |
| AOR-DELETE-005 | Build artifacts (.dot, .dot.bak, _build/, deps/) are exempt |
| AOR-DELETE-006 | NEVER delete files during autonomous/bypass mode without backup |
| AOR-DELETE-007 | Log all deletions to session audit trail |

## Backup Protocol

Before deleting ANY untracked file with code content:

```bash
# Step 1: Create backup directory
mkdir -p data/tmp/backup/$(date +%Y%m%d-%H%M%S)

# Step 2: Copy files to backup
cp -r <files-to-delete> data/tmp/backup/$(date +%Y%m%d-%H%M%S)/

# Step 3: Present list to user
echo "Files to be deleted (backed up to data/tmp/backup/...):"
echo "<list>"

# Step 4: Wait for explicit approval
# BLOCK until user confirms

# Step 5: Execute deletion only after approval
```

## Exempt File Types (No backup needed)

- `*.dot`, `*.dot.bak` (graph artifacts)
- `*.beam` (compiled BEAM files)
- `*.o`, `*.so` (compiled objects — BUT libzenoh_ffi.so needs backup)
- `_build/`, `deps/`, `node_modules/` directories
- `.elixir_ls/`, `.lexical/` IDE cache

## Non-Exempt (ALWAYS backup)

- `*.ex`, `*.exs` (Elixir source/test)
- `*.fs`, `*.fsx`, `*.fsproj` (F# source/project)
- `*.rs`, `*.toml` (Rust source/config)
- `*.md` (documentation with substantive content)
- `*.yml`, `*.yaml` (infrastructure config)
- `*.json` (configuration files)

## Incident Reference

On 2026-03-24, Phase 1 of a recovery plan deleted ~30 untracked files using `git checkout --` and manual `rm`. These files contained:
- 4 Elixir modules (DriftMonitor, SemanticRouter, ConsensusAggregator, ConsensusIntegrity)
- 2 F# projects (Cepaf.Evolution.Monitor, Cepaf.Metabolic)
- 12+ architecture/safety documentation files
- Mojo compute and Ollama integration stubs

None were recoverable because they had never been committed to git. This rule prevents recurrence.

## Constitutional Alignment

- **Psi-2 (Evolutionary Continuity)**: Work product represents evolution that must be preserved
- **SC-REG-001**: State mutations (including deletions) require audit trail
- **Omega-0**: Resource loss is antithetical to the Founder's Directive
