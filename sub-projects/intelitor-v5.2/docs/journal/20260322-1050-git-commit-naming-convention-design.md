# 2026-03-22 10:50 — Git Commit Naming Convention Design

## Context
- Branch: main
- Recent commits:
  - 0bdd03f50 chore: remove archived plan files and deprecated sil4-validator
  - bb0082476 docs: journals, analysis reports, verification scripts
  - 1358a39a5 fix(formal-specs): Quint + Agda syntax corrections and CI scripts
  - fbde9936d refactor(core): supervisor granularity restructuring + Sentinel MCP enhancements
  - abfcfdcf0 feat(constraint-sync): full reconciliation + compiled binary (5-35x speedup)
  - 98d6a7a32 refactor(.claude): config overhaul — agents, commands, rules, plans archive
- Task: Design a unified git commit naming convention for the Indrajaal project
- Trigger: User directive after organizing 228 files into 6 logical commits, exposing the inconsistency of the existing commit history

## Summary

Designed a comprehensive git commit naming convention based on the **Conventional Commits** specification, customized with Indrajaal-specific scopes mapped to the project's fractal architecture. The convention replaces three incompatible historical styles with a single, machine-parseable, human-readable format.

### Problem Statement

Analysis of 1,364 commits in the repository revealed three incompatible commit message styles:

| Style | Count | % | Semantic Value | Example |
|-------|-------|---|----------------|---------|
| Conventional | 547 | 40.1% | HIGH | `feat(sprint-54): mathematical morphogenesis` |
| Automated (EVOLUTION RUN) | 75 | 5.5% | ZERO | `EVOLUTION RUN 2: Biomorphic Synchronization Complete` |
| Hyperbolic (SINGULARITY/GA) | 7 | 0.5% | LOW | `TOTAL BIOMORPHIC SINGULARITY: ...` |
| Other mixed | 735 | 53.9% | VARIABLE | `PRAJNA-UNIFIED-20260116-0553: ...` |

**Key finding**: The automated `EVOLUTION RUN` messages and hyperbolic `SINGULARITY` messages carry **zero differential information** — they don't describe what changed, why, or what subsystem was affected. The 6 commits just created (using Conventional Commits) demonstrated the improvement: each commit is self-describing, filterable by type and scope, and maps to specific subsystems.

### Solution: Indrajaal Commit Convention v1.0

#### Format

```
<type>(<scope>): <subject>

[body]

[footer]
```

#### 8 Commit Types

| Type | Semantics | Version Bump | Frequency |
|------|-----------|-------------|-----------|
| `feat` | New capability or behavior | MINOR | ~30% |
| `fix` | Bug fix (behavior correction) | PATCH | ~20% |
| `refactor` | Code restructure, no behavior change | — | ~15% |
| `test` | Test additions/changes only | — | ~10% |
| `docs` | Documentation, journals, specs | — | ~10% |
| `chore` | Build, CI, config, tooling | — | ~10% |
| `perf` | Performance optimization | PATCH | ~3% |
| `security` | Security fix or hardening | PATCH+ | ~2% |

Breaking changes use `!` suffix: `feat(ash)!: rename BaseResource`

#### 22 Project-Specific Scopes

Mapped to Indrajaal's fractal subsystem architecture:

| Scope | Subsystem | Layer |
|-------|-----------|-------|
| `app` | Phoenix/Ash application | L0-L2 |
| `ash` | Ash framework resources | L0-L1 |
| `mesh` | SIL-6 mesh orchestration | L3-L5 |
| `cepaf` | F# CEPAF layer | L3-L4 |
| `zenoh` | Zenoh IPC/FFI | L3-L6 |
| `sentinel` | MCP server, health monitoring | L3-L4 |
| `smriti` | Knowledge management | L3-L4 |
| `prajna` | C3I cockpit UI | L2-L3 |
| `guardian` | Safety kernel | L0 (Constitutional) |
| `immune` | Digital immune system | L3-L4 |
| `db` | Database layer (PG/SQLite/DuckDB) | L1-L2 |
| `obs` | Observability (OTEL/Grafana) | L3-L4 |
| `kms` | Key management | L2-L3 |
| `test` | Test infrastructure (TDG/FPPS) | Cross-cutting |
| `ci` | CI/CD pipeline | L4-L5 |
| `sync` | Constraint sync engine | Cross-cutting |
| `plan` | Planning system (sa-plan/Chaya) | L3-L4 |
| `formal` | Formal verification (Quint/Agda) | L7 |
| `math` | Mathematical disciplines | L3-L4 |
| `vsm` | VSM cybernetic layers (S1-S5) | L3-L5 |
| `fed` | Federation/cluster (L6-L7) | L6-L7 |
| `sprint-N` | Sprint-scoped work | Cross-cutting |

Multi-scope: `fix(zenoh,cepaf): align FFI signatures`
No scope: `chore: update devenv.nix` (cross-cutting)

#### Subject Line Rules

1. **Imperative mood**: "add feature" not "added feature"
2. **No terminal period**
3. **Max 72 characters** total (type + scope + colon + space + subject)
4. **Lowercase** first word after colon
5. **What, not how**: describe the change's effect, not the implementation mechanism

#### Body Guidelines

- Separated by blank line from subject
- Explains **why** the change was made (the diff shows what)
- Wrap at 80 characters
- Optional for L1-only changes, recommended for L2+

#### Footer (STAMP Integration)

```
STAMP: SC-CHG-001, SC-SYNC-DOC-009
Impact: L1-CODE(2), L2-DOMAIN(0), L3-SYSTEM(1), L4-ECO(0) = 3 (LOW)
```

- **Optional** for L1-only changes (most commits)
- **Recommended** for L2+ changes
- **Required** for L3+ changes (system-level impact)

#### Automated Commit Template

For `sa-mesh.fsx` and other automated scripts, replace:
```
EVOLUTION RUN 2: Biomorphic Synchronization Complete    ← DEPRECATED
```
With:
```
chore(mesh): biomorphic sync run 2 — 14 containers, 3 zenoh routers
```

General template for automated scripts:
```
chore(<scope>): <script-name> — <key metric summary>
```

## Technical Details

### Files Affected

| File | Action | Description |
|------|--------|-------------|
| This journal entry | Created | Convention design document |
| `.claude/rules/` | Future | Rule file for enforcement (pending user approval) |
| `sa-mesh.fsx` | Future | Update EVOLUTION RUN commit messages |
| `sa-multiverse.fsx` | Future | Update automated commit messages |

### Relationship to SC-CHG §9.0

The existing `change-management.md` §9.0 defines a verbose commit format with `Change-Id`, `Impact-Score`, `Layers-Affected`, etc. This convention **simplifies and replaces** that format:

| SC-CHG §9.0 Field | New Convention Equivalent | Status |
|---|---|---|
| `[TYPE]([SCOPE])` | `type(scope)` | Same |
| `Change-Id: CHG-YYYYMMDD-...` | Git SHA (implicit, no manual ID needed) | Simplified |
| `Impact-Score: [0-50]` | Footer `Impact:` line (optional) | Optional |
| `Layers-Affected: L1,L2...` | Footer `Impact:` line (optional) | Merged |
| `STAMP: SC-...` | Footer `STAMP:` line (optional) | Same |
| `Reversal: git revert...` | Omitted (always `git revert <sha>`) | Removed |
| `Co-Authored-By:` | Keep as-is for AI-assisted commits | Same |

### Design Decisions

**Why 8 types, not fewer?**
`perf` and `security` are separated from `fix` because they have different review/audit requirements. A `perf(sync)` commit triggers SC-PRF performance constraint review; a `security(kms)` commit triggers SC-SEC security review. Collapsing into `fix` loses this triage signal.

**Why not enforce footer on every commit?**
The vast majority of commits are L1-CODE changes (a function added, a bug fixed). Requiring STAMP/Impact metadata on every commit creates friction that leads to copy-paste boilerplate. Reserve metadata for commits that actually cross system boundaries.

**Why scopes and not free-text?**
The 22 scopes map 1:1 to Indrajaal's subsystem architecture. This enables:
- `git log --grep="^feat(zenoh)"` — all Zenoh features
- `git log --grep="^fix(mesh)"` — all mesh bug fixes
- Automated changelog generation grouped by subsystem
- Sprint retrospectives filtered by domain

**Why imperative mood?**
Git itself uses imperative ("Merge branch...", "Revert..."). A commit message completes the sentence "If applied, this commit will ___". Imperative mood makes this natural: "add circuit breaker" → "If applied, this commit will add circuit breaker."

## Information Theory Analysis

### Pre-Convention State
The commit history has high entropy — messages follow no predictable pattern, making the history a poor model for understanding system evolution.

$$H_{pre} = -\sum_{i=1}^{4} p_i \log_2 p_i = -(0.40 \log_2 0.40 + 0.055 \log_2 0.055 + 0.005 \log_2 0.005 + 0.54 \log_2 0.54)$$
$$H_{pre} \approx 1.38 \text{ bits}$$

### Post-Convention State (Target)
With all commits following the convention, the type field alone provides ~3 bits of semantic information (8 types), and the scope field adds ~4.5 bits (22 scopes). Total semantic density per commit message rises from near-zero (EVOLUTION RUN) to ~7.5 bits.

$$H_{post,type} = \log_2 8 = 3.0 \text{ bits}$$
$$H_{post,scope} = \log_2 22 \approx 4.46 \text{ bits}$$
$$I_{convention} = H_{post} - H_{pre} \approx 7.46 - 1.38 = 6.08 \text{ bits/commit}$$

Over 1,364 commits, the theoretical information gain is:
$$I_{total} = 6.08 \times 1364 \approx 8,293 \text{ bits}$$

This is the information the repository *should* contain in its commit history but currently doesn't.

## STAMP Compliance

| ID | Status | Notes |
|----|--------|-------|
| SC-CHG-001 | ADDRESSED | Convention IS the structured change note format |
| SC-CHG-002 | ADDRESSED | 4-layer impact analysis in footer (optional for L1, required for L3+) |
| SC-CHG-003 | N/A | Reversal is always `git revert` — no need to document per-commit |
| SC-SYNC-DOC-009 | COMPATIBLE | New SC-*/AOR-* in code → add to CLAUDE.md in same commit (convention doesn't conflict) |
| SC-REG-001 | COMPATIBLE | Append-only register not affected by commit message format |

### 4-Layer Impact Analysis

| Layer | Impact | Score |
|-------|--------|-------|
| L1-CODE | No code changes — convention design only | 0 |
| L2-DOMAIN | No domain logic changes | 0 |
| L3-SYSTEM | Future: automated scripts will change commit messages | 1 |
| L4-ECOSYSTEM | Standardizes all future commits across all contributors | 2 |
| **Total** | | **3 (LOW RISK)** |

## Architecture Decision Records

### ADR-001: Conventional Commits as Base
**Decision**: Use Conventional Commits specification as the foundation.
**Rationale**: Industry standard, machine-parseable, supports automated changelog and semantic versioning. Already used in the 6 most recent commits.
**Trade-off**: Slightly more verbose than free-text, but the structure is the point.

### ADR-002: Fixed Scope Taxonomy
**Decision**: Define 22 fixed scopes mapped to Indrajaal subsystems.
**Rationale**: Free-text scopes (as in vanilla Conventional Commits) lead to inconsistency over time. Fixed scopes enable reliable `git log --grep` filtering and automated grouping.
**Trade-off**: New subsystems require adding a scope to the taxonomy. Acceptable given the project's architecture is relatively stable.

### ADR-003: Optional Footer for L1, Required for L3+
**Decision**: STAMP/Impact footer is optional for L1-only changes, required for L3+ system changes.
**Rationale**: Most commits are small L1 changes. Mandatory metadata creates friction and boilerplate. L3+ changes genuinely need the traceability.
**Trade-off**: Some L1 commits will lack STAMP references. Acceptable because L1 changes are low-risk.

### ADR-004: Replace SC-CHG §9.0 Verbose Format
**Decision**: This convention supersedes the verbose format in `change-management.md` §9.0.
**Rationale**: The §9.0 format includes `Change-Id`, `Impact-Score`, `Layers-Affected`, `Reversal`, etc. — 15+ lines of metadata that no human will consistently fill in. This convention captures the same traceability with 1-3 lines.
**Trade-off**: Less metadata per commit, but more commits will actually comply.

### ADR-005: Automated Script Commit Standardization
**Decision**: Automated scripts (`sa-mesh.fsx`, `sa-multiverse.fsx`) must use `chore(<scope>): <description>` format.
**Rationale**: "EVOLUTION RUN N: Biomorphic Synchronization Complete" provides zero differential information. The new format includes the scope (mesh) and a metric summary.
**Trade-off**: Requires updating F# scripts that generate commit messages.

## Next Steps

1. **Create `.claude/rules/git-commit-convention.md`** — Enforce convention for all agent sessions
2. **Update `sa-mesh.fsx`** — Replace `EVOLUTION RUN` commit messages with `chore(mesh): ...` format
3. **Update `sa-multiverse.fsx`** — Same treatment for multiverse sync commits
4. **Update `change-management.md` §9.0** — Reference this convention as the canonical format
5. **Retroactive cleanup** (optional) — Consider `git rebase -i` on recent EVOLUTION RUN commits to apply convention (low priority, high risk)
6. **Pre-commit hook** (future) — Validate commit message format against convention

## KPIs

- Files changed: 1 (this journal entry)
- Lines added: ~220
- Lines removed: 0
- Tests: N/A (convention design, not code)
- Warnings: 0
- Commit styles analyzed: 4 (conventional, evolution-run, hyperbolic, mixed)
- Total commits analyzed: 1,364
- Scopes defined: 22
- Types defined: 8
- ADRs produced: 5
- Information gain per commit: ~6.08 bits (theoretical)
- Execution time: ~20 minutes (analysis + design)

## Knowledge Density

$$\rho_K = \frac{5 \text{ ADRs} + 3 \text{ constraints} + 11 \text{ KPIs}}{220 \text{ lines}} = 0.086$$
