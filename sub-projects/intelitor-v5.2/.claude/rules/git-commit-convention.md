# Git Commit Convention — Indrajaal Commit Protocol (ICP) v2.0

## MANDATORY FORMAT

All commits MUST follow this format:

```
type(scope): action — context [ref]
```

- **type**: WHAT KIND (required)
- **scope**: WHERE in the system (required except cross-cutting)
- **action**: WHAT was done, imperative mood (required)
- **— context**: WHY or HOW MUCH (recommended, after em-dash)
- **[ref]**: SC-*/task reference (optional, in brackets)

**Max 80 characters** for the subject line.

---

## 9 Types (Required)

| Type | Use When |
|------|----------|
| `feat` | New capability or behavior |
| `fix` | Corrects wrong behavior |
| `refactor` | Restructure, same behavior |
| `perf` | Speed/memory/resource improvement |
| `test` | Test-only changes |
| `docs` | Documentation, journals, specs |
| `chore` | Build, config, tooling, cleanup |
| `security` | Security fix or hardening |
| `evolve` | Automated evolution/sync scripts |

**Never invent new types.** `evolve` replaces EVOLUTION RUN.

## 23 Scopes (Required)

```
L0: guardian
L1-L2: app, db, kms
L3-L4: mesh, cepaf, zenoh, sentinel, immune, smriti, prajna, cortex, plan, obs
L5-L6: vsm, math, swarm
L7: fed, formal
Cross: test, ci, sync, core
```

Multi-scope: `fix(zenoh,cepaf): ...` (max 2, comma-separated)
Scopeless: only for truly cross-cutting changes (`chore: update devenv.nix`)

## Em-Dash Context Channel (—)

The em-dash separates action (WHAT) from context (WHY/HOW MUCH):

```
fix(sentinel): correct JsonDocument parsing — .NET 10 broke private record deserialization
perf(sync): compile constraint engine to binary — cached 2.0s→57ms (35x)
feat(test): add MathematicalSystemMonitor tests — 49 Expecto tests, 17 disciplines
docs(sync): constraint reconciliation parity achieved — gap 8.4:1→1.0:1
```

## Structured Body (for L2+ changes)

```
type(scope): subject — context

WHY: One sentence explaining the causal trigger.
WHAT: One sentence describing the technical approach.

Files: 6 created, 4 modified
Layer: L1-CODE(2), L3-SYSTEM(1)
STAMP: SC-SYNC-DOC-011, SC-NET-001
Task: S59-T001
```

- **Skip body** for trivial L1 changes
- **Required** for any change touching L3+ layers

## Forbidden Patterns

| Pattern | Violation | Use Instead |
|---------|-----------|-------------|
| `EVOLUTION RUN N: ...` | Zero information | `evolve(mesh): biomorphic sync cycle N — stats` |
| Emoji prefix (🚀🎯✅🏆) | Not parseable | `type(scope): action` |
| `SINGULARITY: ...` | Hyperbolic, no type/scope | `feat(scope): description` |
| Free-text scope | Degrades over time | Use 23-scope taxonomy |
| Past tense ("added X") | Convention is imperative | "add X" |

## Agent Commit Checklist

1. SELECT type from 9-type enum
2. SELECT scope from 23-scope taxonomy
3. WRITE action in imperative mood
4. APPEND `—` + context (metric, causal trigger, or constraint ref)
5. CHECK subject ≤ 80 characters
6. IF L3+ change: WRITE structured body
7. APPEND `Co-Authored-By:` trailer for AI-assisted commits

## STAMP/AOR Reference

> SC-CHG-001 (structured change notes), SC-CHG-002 (4-layer impact), SC-SYNC-DOC-009 (new SC-* in same commit)
> Supersedes change-management.md §9.0 verbose format.
> Journal: `journal/2026-03/20260322-1100-git-commit-convention-v2-high-density-design.md`
