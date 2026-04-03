# Concurrent Bug Fix Protocol — Multi-Agent sa-plan Coordination

## Applicability
This protocol governs ALL agent sessions (Claude, Gemini, or any AI agent) that fix bugs or implement tasks concurrently. Follow this protocol exactly.

---

## Phase 0: Bootstrap (BEFORE any work)

```bash
# 1. Read system awareness document
Read AGENT_BOOTSTRAP.md

# 2. Discover available tasks
sa-plan list pending

# 3. Identify your agent ID (use throughout session)
#    Format: {vendor}-{instance} e.g., claude-1, gemini-2
```

**CRITICAL RULES**:
- NEVER read or write `PROJECT_TODOLIST.md` directly (SC-TODO-001 to SC-TODO-009)
- NEVER use `cat`, `grep`, `sed` on `PROJECT_TODOLIST.md`
- ALWAYS use `sa-plan` CLI for ALL task operations
- NEVER run `chaya-sync` (deprecated path, AOR-SYNC-PLAN-010)

---

## Phase 1: Discovery — Find tasks to work on

```bash
# List all pending tasks
sa-plan list pending

# Check current status summary
sa-plan status

# See what's already in progress (avoid claiming these)
sa-plan list in_progress
```

**Coordination rule**: Before claiming a task, check `sa-plan list in_progress` to see what other agents have already claimed. Pick a task that is `pending`, not one already `in_progress`.

**Priority order**: Work P0 tasks first, then P1, then P2, then P3.

---

## Phase 2: Claim — Reserve your task

```bash
# Claim the task by setting it to in_progress
sa-plan update <task-id> in_progress
```

**Example**:
```bash
sa-plan update 2fd3419d in_progress
```

**What happens behind the scenes**:
1. PlanningEnforcer validates your access (5 layers, <5ms)
2. SQLite atomically updates task status (WAL mode, ACID)
3. Zenoh publishes `task_updated` event (other agents see your claim)
4. Chaya Digital Twin syncs automatically
5. PROJECT_TODOLIST.md regenerated (read-only artifact)

**If another agent already claimed the same task**: Your update still succeeds (last-writer-wins), but you'll be doing duplicate work. Always check `sa-plan list in_progress` first.

---

## Phase 3: Fix — Implement the change

### 3a. Create an isolated branch

```bash
git checkout -b multiverse/<your-agent-id>-<short-scope> main
# Example:
git checkout -b multiverse/claude-1-fix-sentinel-parsing main
```

### 3b. Understand before changing

```bash
# Read the relevant code BEFORE modifying
# Read the module's @moduledoc or XML doc comments
# Read existing tests for the module
# Check STAMP constraints referenced in the code
```

### 3c. Write the fix

Follow these quality rules:
- **Zero warnings**: `mix compile` or `dotnet build` must produce 0 warnings
- **Zero test failures**: All existing tests must still pass
- **TDG**: Write or update tests for your change
- **Format**: Run `mix format` (Elixir) or ensure F# formatting is clean

### 3d. Verify locally

```bash
# Elixir changes:
NO_TIMEOUT=true PATIENT_MODE=enabled SKIP_ZENOH_NIF=0 WALLABY_ENABLED=true \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" mix compile --jobs 16 2>&1 | tail -5
SKIP_ZENOH_NIF=0 WALLABY_ENABLED=true NO_TIMEOUT=true PATIENT_MODE=enabled \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" MIX_ENV=test mix test --only <relevant_test_tag>
mix format --check-formatted

# F# changes:
dotnet build lib/cepaf/src/<Project>/<Project>.fsproj
dotnet run --project lib/cepaf/test/Cepaf.Tests/Cepaf.Tests.fsproj -- \
  --filter-test-list "<RelevantTestGroup>" --summary
```

### 3e. Commit with ICP v2.0 format

```bash
git add <specific-files>
git commit -m "$(cat <<'EOF'
fix(scope): description of fix — context

WHY: What caused the bug
WHAT: How the fix works

Layer: L1-CODE(N)
STAMP: SC-RELEVANT-NNN

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

**Commit type reference**: `fix` for bugs, `feat` for features, `refactor` for restructuring, `test` for test-only, `docs` for documentation.

---

## Phase 4: Complete — Mark the task done

```bash
# Mark task as completed
sa-plan update <task-id> completed
```

**Example**:
```bash
sa-plan update 2fd3419d completed
```

**Only mark completed when ALL of these are true**:
- [ ] Code compiles with 0 errors and 0 warnings
- [ ] All tests pass (existing + new)
- [ ] Code is formatted (`mix format` / F# clean)
- [ ] Commit follows ICP v2.0 format
- [ ] Changes are on your `multiverse/` branch (not main)

**If your fix is blocked or incomplete**:
```bash
# Mark as blocked with a reason
sa-plan update <task-id> blocked
```

---

## Phase 5: Merge — Integrate to main (requires approval)

```bash
# Switch to main and merge
git checkout main
git merge multiverse/<your-agent-id>-<short-scope> --ff-only

# If fast-forward fails (another agent merged first):
git checkout multiverse/<your-agent-id>-<short-scope>
git rebase main
# Re-verify: compile + test + format
git checkout main
git merge multiverse/<your-agent-id>-<short-scope> --ff-only

# Clean up branch
git branch -d multiverse/<your-agent-id>-<short-scope>
```

**Guardian Gate (SC-GIT-006)**: Merges to `main` require Guardian approval. If operating autonomously, verify all quality gates pass before merging. If uncertain, leave the branch unmerged and report status.

---

## Quick Reference Card

| Phase | Command | When |
|-------|---------|------|
| **Discover** | `sa-plan list pending` | Start of session |
| **Check conflicts** | `sa-plan list in_progress` | Before claiming |
| **Claim** | `sa-plan update <id> in_progress` | Before starting work |
| **Branch** | `git checkout -b multiverse/<agent>-<scope> main` | After claiming |
| **Verify** | `mix compile && mix test` or `dotnet build && dotnet run tests` | After fix |
| **Commit** | `git commit` (ICP v2.0 format) | After verify passes |
| **Complete** | `sa-plan update <id> completed` | After commit |
| **Merge** | `git merge --ff-only` | After complete |
| **Blocked** | `sa-plan update <id> blocked` | If stuck |
| **Status** | `sa-plan status` | Anytime |

## Valid Status Values

| Status | Meaning | Use when |
|--------|---------|----------|
| `pending` | Not started | Reverting a premature claim |
| `in_progress` | Actively being worked on | Claiming a task |
| `completed` | Done and verified | All quality gates pass |
| `blocked` | Cannot proceed | Dependency or external blocker |

## Priority Levels

| Priority | Meaning | Work order |
|----------|---------|------------|
| P0 | Critical / safety | Work FIRST |
| P1 | High / core functionality | Work second |
| P2 | Medium / routine (default) | Work third |
| P3 | Low / nice-to-have | Work last |

---

## Forbidden Actions

| Action | Violation | Do instead |
|--------|-----------|------------|
| `cat PROJECT_TODOLIST.md` | SC-TODO-003 | `sa-plan list` |
| `Read("PROJECT_TODOLIST.md")` | SC-TODO-001 | `sa-plan list` |
| `Write("PROJECT_TODOLIST.md")` | SC-TODO-002 | `sa-plan update` |
| `grep ... PROJECT_TODOLIST.md` | SC-TODO-003 | `sa-plan list` |
| `chaya-sync` | AOR-SYNC-PLAN-010 | `sa-plan update` (auto-syncs) |
| Committing directly to `main` | SC-GIT-006 | Use `multiverse/` branch |
| Skipping tests before complete | Ω₃ Zero-Defect | Run full verify first |

---

## Failure Recovery

| Problem | Solution |
|---------|----------|
| Another agent claimed my task | Pick a different `pending` task |
| My fix breaks existing tests | Fix the regression before marking complete |
| Merge conflict with main | Rebase your branch, re-verify, retry merge |
| `sa-plan` returns error | Check if database exists: `ls data/smriti/planning.db` |
| Task ID not found | Run `sa-plan list` to find correct IDs |
| Compilation fails after merge | `git revert HEAD` and investigate |

---

## STAMP/AOR Reference
> SC-TODO-001 to SC-TODO-009, SC-SYNC-PLAN-001 to SC-SYNC-PLAN-017, SC-ENFORCE-001 to SC-ENFORCE-025
> SC-GIT-006 (Guardian merge approval), SC-FUNC-001 (always compilable), Ω₃ (Zero-Defect)
> AOR-SYNC-PLAN-009 (use sa-plan update to complete), AOR-SYNC-PLAN-010 (never chaya-sync)
