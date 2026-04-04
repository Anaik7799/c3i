# Git Conventions & Workflow

## 1. Commit Format — ICP v2.0

```
type(scope): action — context [ref]
```
Max 80 chars. Em-dash separates WHAT from WHY/HOW MUCH.

### 9 Types
feat | fix | refactor | perf | test | docs | chore | security | evolve

### 23 Scopes
L0: guardian | L1-L2: app, db, kms | L3-L4: mesh, cepaf, zenoh, sentinel, immune, smriti, prajna, cortex, plan, obs | L5-L6: vsm, math, swarm | L7: fed, formal | Cross: test, ci, sync, core

Multi-scope max 2: `fix(zenoh,cepaf): ...`

### Body (required for L2+ changes)
```
WHY: Causal trigger
WHAT: Technical approach

Layer: L1-CODE(N), L3-SYSTEM(N)
STAMP: SC-XXX-NNN
Task: SNN-TNNN

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

**Forbidden**: EVOLUTION RUN N, emoji prefixes, free-text scopes, past tense.

## 2. Concurrent Bug Fix Protocol

### Phase 0: Bootstrap
```bash
Read AGENT_BOOTSTRAP.md && sa-plan list pending
```
**NEVER** read/write PROJECT_TODOLIST.md directly. **ALWAYS** use sa-plan CLI.

### Phase 1: Discover
`sa-plan list pending` -> `sa-plan list in_progress` (avoid claimed tasks) -> Work P0 first.

### Phase 2: Claim
`sa-plan update <task-id> in_progress`

### Phase 3: Fix
```bash
git checkout -b multiverse/<agent-id>-<scope> main
# Read code -> Write fix -> Verify:
governed_compile   # 0 errors, 0 warnings
mix format --check-formatted
governed_test      # 0 failures
# Commit with ICP v2.0 format
```

### Phase 4: Complete
`sa-plan update <task-id> completed` -- Only when: compiles clean, tests pass, formatted, committed on multiverse/ branch.

### Phase 5: Merge (requires Guardian approval per SC-GIT-006)
`git checkout main && git merge multiverse/<branch> --ff-only` -- If fails: rebase, re-verify, retry.

**Valid statuses**: pending | in_progress | completed | blocked
**Priority**: P0 (critical/safety) > P1 (core) > P2 (routine) > P3 (nice-to-have)

## 3. Change Management (SC-CHG-000)

**All changes: documented, traceable, reversible.** Derives from Psi-2, Psi-3, SC-REG-001, SC-FUNC-003.

### 4-Layer Impact Analysis (before any change)
| Layer | Aspects |
|-------|---------|
| L1-CODE | Files, functions, types, dependencies, breaking changes |
| L2-DOMAIN | Resources, business rules, data model, workflows |
| L3-SYSTEM | Containers, networks, config, secrets, monitoring |
| L4-ECOSYSTEM | CI/CD, docs, tests, federation, compliance |

**Impact score** = sum of layer scores (0-4 per layer, weighted by layer). 0-10: standard review. 11-20: senior review. 21-30: architecture review. 31+: Guardian approval.

### 4-Layer Reversal
L1: `git revert [sha]` | L2: + `mix compile --force` | L3: + `mix ecto.rollback` + `sa-down/up` | L4: `sa-checkpoint-restore --phase full`

### Version Updates
Update on release: mix.exs, CLAUDE.md, CHANGELOG.md, lib/indrajaal/version.ex. Use Keep a Changelog format.
