# Change Management Protocol (SC-CHG-000)

## SUPREME CHANGE MANDATE

**ALL CODE CHANGES MUST BE FULLY DOCUMENTED, TRACEABLE, AND REVERSIBLE.**

This rule enforces:
- **Traceability**: Every change has a clear audit trail
- **Reversibility**: Every change can be undone at 4 layers
- **Impact Analysis**: 4-layer impact assessment before any change
- **Version Control**: Semantic versioning with change log updates

## Constitutional Alignment

This rule derives from and enforces:
- **Ψ₂ (Evolutionary Continuity)**: Complete history preserved
- **Ψ₃ (Verification Capability)**: All changes verifiable
- **SC-REG-001**: All state changes via append-only register
- **SC-FUNC-003**: Rollback path MUST exist for every change

---

## 1.0 Change Note Structure (MANDATORY)

Every change MUST include a structured change note:

```markdown
## CHANGE NOTE: [CHANGE-ID]

### 1. Change Identity
| Field | Value |
|-------|-------|
| Change ID | CHG-YYYYMMDD-HHMMSS-[SHORT_HASH] |
| Author | [Name/Agent ID] |
| Timestamp | YYYY-MM-DD HH:MM:SS CEST |
| Version | From: v[X.Y.Z] → To: v[X.Y.Z+1] |
| Branch | [branch-name] |
| Commit | [full-sha] |

### 2. What Is Being Changed
- **Files Modified**: [list of files with line ranges]
- **Modules Affected**: [list of modules]
- **Features Impacted**: [feature names]
- **APIs Changed**: [endpoint/function signatures]

### 3. Why This Change Is Being Made
- **Motivation**: [problem being solved]
- **Ticket/Issue**: [reference to issue tracker]
- **Business Value**: [benefit to users/system]
- **Technical Debt**: [debt addressed or introduced]

### 4. Git Details
- **Base Commit**: [parent commit sha]
- **Branch**: [feature/fix/refactor branch name]
- **PR/MR**: [link to pull request if applicable]
- **Related Commits**: [list of related commits]

### 5. 4-Layer Impact Analysis
[See Section 2.0]

### 6. Reversibility Plan
[See Section 3.0]

### 7. Version Updates
[See Section 4.0]
```

---

## 2.0 Four-Layer Impact Analysis (SC-CHG-IMPACT)

Every change MUST be analyzed across 4 layers:

### Layer 1: Code Layer (L1-CODE)
| Aspect | Analysis |
|--------|----------|
| **Files Changed** | List all modified files |
| **Functions Added/Removed** | Function signature changes |
| **Types Changed** | Struct/type modifications |
| **Dependencies** | New/removed dependencies |
| **Breaking Changes** | API contract violations |
| **Compile Impact** | Expected compile time change |

### Layer 2: Domain Layer (L2-DOMAIN)
| Aspect | Analysis |
|--------|----------|
| **Ash Resources** | Resource schema changes |
| **Business Rules** | Logic/validation changes |
| **Data Model** | Database schema impact |
| **Workflows** | Process flow changes |
| **Integrations** | External system effects |

### Layer 3: System Layer (L3-SYSTEM)
| Aspect | Analysis |
|--------|----------|
| **Containers** | Container image changes |
| **Ports/Networks** | Network topology changes |
| **Configuration** | Config file updates |
| **Secrets/KMS** | Security impact |
| **Monitoring** | Observability changes |

### Layer 4: Ecosystem Layer (L4-ECOSYSTEM)
| Aspect | Analysis |
|--------|----------|
| **CI/CD Pipeline** | Build process changes |
| **Documentation** | Doc updates required |
| **Tests** | Test suite modifications |
| **Federation** | Cross-holon effects |
| **Compliance** | Regulatory impact |

### Impact Severity Matrix

```
             │ L1-CODE │ L2-DOMAIN │ L3-SYSTEM │ L4-ECOSYSTEM │
─────────────┼─────────┼───────────┼───────────┼──────────────┤
 NONE        │    0    │     0     │     0     │       0      │
 LOW         │    1    │     2     │     3     │       4      │
 MEDIUM      │    2    │     4     │     6     │       8      │
 HIGH        │    3    │     6     │     9     │      12      │
 CRITICAL    │    4    │     8     │    12     │      16      │
─────────────┴─────────┴───────────┴───────────┴──────────────┘
Total Impact Score = Σ(Layer Scores)
  0-10:  LOW RISK     → Standard review
  11-20: MEDIUM RISK  → Senior review required
  21-30: HIGH RISK    → Architecture review
  31+:   CRITICAL     → Guardian approval required
```

---

## 3.0 Four-Layer Reversibility Protocol (SC-CHG-REVERSE)

Every change MUST have a documented reversal procedure at each layer:

### Layer 1: Git Reversal (Immediate)
```bash
# Revert single commit
git revert [commit-sha] --no-edit

# Revert range of commits
git revert [older-sha]..[newer-sha] --no-edit

# Hard reset (DESTRUCTIVE - use with caution)
git reset --hard [safe-commit-sha]

# Verify reversal
mix compile --warnings-as-errors
mix test
```

### Layer 2: Code Reversal (Minutes)
```elixir
# Restore from backup
cp _backup/[file].ex.bak lib/[path]/[file].ex

# Regenerate from source
mix compile --force

# Verify functionality
mix test --only [affected_tests]
```

### Layer 3: Database Reversal (Minutes-Hours)
```bash
# Rollback migration
mix ecto.rollback --step 1

# Restore from backup
pg_restore -d indrajaal_dev backup/[timestamp].dump

# Verify data integrity
mix ecto.migrate
mix run scripts/verify_data_integrity.exs
```

### Layer 4: System Reversal (Hours)
```bash
# Container rollback
podman tag localhost/indrajaal-app:v[NEW] localhost/indrajaal-app:failed
podman tag localhost/indrajaal-app:v[OLD] localhost/indrajaal-app:latest
sa-down && sa-up

# Full system restore from checkpoint
sa-checkpoint-restore --phase full --checkpoint [checkpoint-id]

# Verify system health
sa-health
sa-verify
```

### Reversal Decision Tree

```
Change Failed?
    │
    ├─ L1 Only (Code typo, small fix)
    │       └─► git revert [sha]
    │
    ├─ L2 Involved (Domain logic)
    │       └─► git revert + mix compile --force
    │
    ├─ L3 Involved (DB/Config)
    │       └─► git revert + mix ecto.rollback + sa-down/up
    │
    └─ L4 Involved (Full system)
            └─► sa-checkpoint-restore --phase full
```

---

## 4.0 Version Control Protocol (SC-CHG-VERSION)

### Semantic Versioning (SemVer)

```
v[MAJOR].[MINOR].[PATCH]-[PRERELEASE]+[BUILD]

MAJOR: Breaking changes (L4 impact)
MINOR: New features (L2-L3 impact)
PATCH: Bug fixes (L1 impact)
PRERELEASE: alpha, beta, rc.N
BUILD: git sha, timestamp
```

### Version Update Locations

| File | Field | Update Trigger |
|------|-------|----------------|
| `mix.exs` | `version:` | Every release |
| `CLAUDE.md` | Version header | Major/minor releases |
| `GEMINI.md` | Version header | Major/minor releases |
| `CHANGELOG.md` | New section | Every PR merge |
| `lib/indrajaal/version.ex` | `@version` | Every release |
| `package.json` (if exists) | `version` | Every release |

### Version Bump Script

```bash
# Bump version (auto-updates all locations)
elixir scripts/version/bump_version.exs --type [major|minor|patch]
```

---

## 5.0 In-File Change Tracking (SC-CHG-INLINE)

### Module Header Update (MANDATORY)

Every modified module MUST have updated header:

```elixir
defmodule Indrajaal.MyModule do
  @moduledoc """
  Description of module.

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.2.1 | 2026-01-10 | Claude | Added new_function/2 |
  | 21.2.0 | 2026-01-05 | Human | Initial implementation |

  ## Constraints
  - SC-CHG-001: Change tracking required
  - SC-FUNC-001: Must compile without errors
  """

  @version "21.2.1"
  @last_modified "2026-01-10T12:00:00Z"
  @last_author "Claude"
```

### Function-Level Change Tracking

```elixir
@doc """
Performs operation X.

## Change History
- v21.2.1 (2026-01-10): Added timeout parameter
- v21.2.0 (2026-01-05): Initial implementation

## Why Changed
Added timeout to prevent blocking calls per SC-PRF-055.
"""
@spec my_function(arg :: term(), timeout :: pos_integer()) :: {:ok, result} | {:error, reason}
def my_function(arg, timeout \\ 5000) do
  # Implementation
end
```

---

## 6.0 STAMP/AOR Reference
> SC-CHG-001 to SC-CHG-010, AOR-CHG-001 to AOR-CHG-010 — defined in CLAUDE.md §5.0, §9.0
> Key: Document before coding, 4-layer impact analysis, reversal procedure, version updates, Immutable Register logging
> Breaking changes (impact > 20): architecture review required. Impact > 30: Guardian approval.

---

## 8.0 Change Workflow

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CHANGE MANAGEMENT WORKFLOW                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. PLAN                                                             │
│     ├─ Create Change Note (Section 1.0)                             │
│     ├─ Perform 4-Layer Impact Analysis (Section 2.0)                │
│     └─ Document Reversal Procedure (Section 3.0)                    │
│                                                                      │
│  2. IMPLEMENT                                                        │
│     ├─ Create feature branch                                         │
│     ├─ Update version (Section 4.0)                                  │
│     ├─ Add in-file change tracking (Section 5.0)                    │
│     └─ Commit with structured message                                │
│                                                                      │
│  3. VERIFY                                                           │
│     ├─ Run quality gates (compile, test, credo)                     │
│     ├─ Test reversal procedure                                       │
│     └─ Update CHANGELOG.md                                           │
│                                                                      │
│  4. REVIEW                                                           │
│     ├─ Impact score < 20: Standard review                           │
│     ├─ Impact score 20-30: Senior review                            │
│     └─ Impact score > 30: Guardian approval                         │
│                                                                      │
│  5. MERGE                                                            │
│     ├─ Squash or merge (preserve history)                           │
│     ├─ Log to Immutable Register                                     │
│     └─ Tag release if applicable                                     │
│                                                                      │
│  6. MONITOR                                                          │
│     ├─ Watch for regression in next 24h                             │
│     ├─ Rollback if issues detected                                   │
│     └─ Close change ticket                                           │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 9.0 Git Commit Message Format — ICP v2.0

**Canonical specification**: `.claude/rules/git-commit-convention.md`
**Design journal**: `journal/2026-03/20260322-1100-git-commit-convention-v2-high-density-design.md`

```
type(scope): action — context [ref]

WHY: Causal trigger (for L2+ changes)
WHAT: Technical approach (if non-obvious)

Layer: L1-CODE(2), L3-SYSTEM(1)
STAMP: SC-CHG-001
Task: S59-T001

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

### 9 Commit Types
- `feat`: New capability (MINOR bump)
- `fix`: Bug fix (PATCH bump)
- `refactor`: Restructure, same behavior
- `perf`: Performance improvement (PATCH bump)
- `test`: Test-only changes
- `docs`: Documentation, journals, specs
- `chore`: Build, config, tooling, cleanup
- `security`: Security fix or hardening (PATCH+ bump)
- `evolve`: Automated evolution/sync scripts (replaces EVOLUTION RUN)

### Key Innovation: Em-Dash Context Channel
The `—` separates action (WHAT) from context (WHY/HOW MUCH):
```
perf(sync): compile constraint engine to binary — cached 2.0s→57ms (35x)
fix(sentinel): correct JsonDocument parsing — .NET 10 broke private record deserialization
```

### Superseded
This format replaces the previous verbose format (Change-Id, Impact-Score, Layers-Affected, Reversal fields). Git SHA serves as Change-Id; reversal is always `git revert`; impact is in the `Layer:` body field when needed.

---

## 10.0 CHANGELOG.md Format
Use Keep a Changelog format: Added/Changed/Fixed/Deprecated/Removed/Security sections.
Include change detail table: `| Change ID | Author | Impact Score | Layers |`

## 11.0 PR Checklist (Compact)
- [ ] Change note created (§1.0)
- [ ] 4-layer impact analyzed (§2.0): L1-CODE [0-4], L2-DOMAIN [0-8], L3-SYSTEM [0-12], L4-ECOSYSTEM [0-16]
- [ ] Reversal procedure documented (§3.0)
- [ ] Version updated (§4.0)
- [ ] In-file change history updated (§5.0)
- [ ] CHANGELOG.md updated
- [ ] Tests pass, Quality gates pass
- [ ] SC-CHG-001 to SC-CHG-010 verified

---

## 12.0 Enforcement

This rule is:
- **MANDATORY**: All changes must comply
- **AUDITED**: Change records in Immutable Register
- **GATED**: CI/CD enforces compliance
- **REVERSIBLE**: Every change can be undone

---

## Related Documents

- CLAUDE.md §5.0 STAMP Constraints (SC-REG-*)
- CLAUDE.md §9.0 AOR Rules (AOR-REG-*)
- .claude/rules/functional-invariant.md
- docs/architecture/HOLON_IMMUTABLE_REGISTER.md


### Plan & Journal Synchronization (SC-SYNC-DOC)
- **Timestamp**: All plan headers MUST include `YYYYMMDD-HHMM CEST`.
- **Mirroring**: Every plan MUST have a corresponding detailed journal entry.
