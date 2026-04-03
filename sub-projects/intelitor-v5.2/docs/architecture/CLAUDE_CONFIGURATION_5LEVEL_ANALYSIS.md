# Claude Code Configuration: 5-Level Analysis & Implementation Guide

**Version**: 21.3.0-FOUNDERS-COVENANT
**Date**: 2026-01-01T10:30:00+01:00
**Author**: Claude Opus 4.5 (Cybernetic Architect)
**Classification**: L4-THORAX (30-day retention)

---

## Executive Summary

This document provides a comprehensive 5-level analysis of the `.claude/` configuration directory, explaining how each component integrates with Claude Code CLI and its impact on the Indrajaal development environment.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         .CLAUDE CONFIGURATION STACK                         │
├─────────────────────────────────────────────────────────────────────────────┤
│  L5-SPINE    │ settings.json (Global Context & Behavior)                   │
│  L4-THORAX   │ agents/*.md (Specialized Sub-Agents)                        │
│  L3-SEGMENT  │ commands/*.md (User-Invokable Skills)                       │
│  L2-FIBER    │ rules/*.md (Path-Triggered Context Injection)              │
│  L1-GOSSAMER │ hooks/*.sh (Event-Driven Automation)                        │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## L5-SPINE: Strategic Configuration (`settings.json`)

### Purpose
The `settings.json` file defines the global operational context for Claude Code sessions in this project.

### Configuration Sections

#### 5.1 Model Selection
```json
{
  "model": "opus"
}
```
**Impact**: Opus 4.5 provides maximum reasoning capability for complex architectural decisions and safety-critical code generation. This aligns with SC-PRIME constraints requiring deep verification.

#### 5.2 Environment Variables
```json
{
  "env": {
    "NO_TIMEOUT": "true",
    "PATIENT_MODE": "enabled",
    "INFINITE_PATIENCE": "true",
    "ELIXIR_ERL_OPTIONS": "+S 16:16 +SDio 16",
    "SKIP_ZENOH_NIF": "0",
    "POSTGRES_USER": "postgres",
    "POSTGRES_PASSWORD": "postgres",
    "DATABASE_URL": "ecto://postgres:postgres@localhost:5433/indrajaal_test"
  }
}
```

| Variable | Purpose | STAMP Constraint |
|----------|---------|------------------|
| `NO_TIMEOUT` | Prevent compilation interruption | SC-VAL-001 |
| `PATIENT_MODE` | Extended operation tolerance | SC-CMP-028 |
| `SKIP_ZENOH_NIF=0` | NIF active for production parity | SC-TEST-NIF-001 |
| `ELIXIR_ERL_OPTIONS` | 16 schedulers for parallel compilation | SC-PRF-050 |
| `DATABASE_URL` | Test database connection | SC-DB-001 |

**Development Impact**: Every Claude session automatically inherits these settings, ensuring consistent behavior across sessions and preventing "works on my machine" issues.

#### 5.3 Permissions
```json
{
  "permissions": {
    "allow": ["*", "Bash(mix:*)", "Bash(git:*)", ...],
    "deny": ["Read(.git/objects/**)", "Read(_build/**)", ...]
  }
}
```

**Security Model**:
- Wide tool access for maximum productivity
- Explicit deny list for binary artifacts and build caches
- Prevents accidental corruption of compiled outputs

#### 5.4 Hooks Configuration
```json
{
  "hooks": {
    "SessionStart": [...],    // Load project tasks
    "SessionEnd": [...],      // Sync tasks back
    "PostToolUse": [...],     // Auto-format Elixir
    "Stop": [...]             // Report compile status
  }
}
```

**Automation Impact**:
1. **SessionStart**: Automatically loads `PROJECT_TODOLIST.md` into Claude context
2. **PostToolUse**: Auto-runs `mix format` on every Elixir file edit
3. **Stop**: Reports compilation errors/warnings at session end

---

## L4-THORAX: Specialized Agents (`agents/*.md`)

### Agent Architecture

```
┌───────────────────────────────────────────────────────────┐
│                    AGENT HIERARCHY                         │
├───────────────────────────────────────────────────────────┤
│  Primary Agent (Opus 4.5)                                 │
│  └── Sub-Agents (Haiku) - Spawned via Task tool           │
│      ├── safety-validator   (STAMP compliance)            │
│      ├── code-reviewer      (Quality & patterns)          │
│      ├── test-generator     (TDG compliance)              │
│      └── script-finder      (Automation discovery)        │
└───────────────────────────────────────────────────────────┘
```

### 4.1 Safety Validator Agent

**File**: `.claude/agents/safety-validator.md`

**Purpose**: Validates code against 460+ STAMP safety constraints including:
- SC-IMMUNE-* (Immune System)
- SC-HOLON-* (Holon State)
- SC-REG-* (Immutable Register)
- SC-FOUNDER-* (Founder's Directive)

**Usage**: Automatically invoked after edits to `lib/indrajaal/safety/**/*.ex`

**Impact**:
- Catches constitutional violations BEFORE commit
- Enforces Guardian veto on unsafe changes
- Documents P0 critical issues from analysis

### 4.2 Code Reviewer Agent

**File**: `.claude/agents/code-reviewer.md`

**Purpose**: Reviews code for quality, patterns, and Indrajaal conventions.

**Checks**:
- Ash 3.x patterns (tenant, actor, pagination)
- Error pattern compliance (EP-*)
- Credo rules (no apply/2, DRY, pipe length)

**Impact**: Consistent code quality across all contributions.

### 4.3 Test Generator Agent

**File**: `.claude/agents/test-generator.md`

**Purpose**: Generates TDG-compliant tests with dual property testing.

**Pattern**:
```elixir
use PropCheck
import ExUnitProperties, except: [property: 2, property: 3]
alias PropCheck.BasicTypes, as: PC
alias StreamData, as: SD
```

**Impact**: Ensures EP-GEN-014 compliance in all new tests.

### 4.4 Script Finder Agent

**File**: `.claude/agents/script-finder.md`

**Purpose**: Discovers and explains scripts from 87+ directories.

**Impact**: Leverages existing automation instead of reinventing.

---

## L3-SEGMENT: User Commands (`commands/*.md`)

### Command Invocation

Commands are invoked via `/command-name [args]` in Claude Code.

```
┌─────────────┬─────────────────────────────────────────────────┐
│ Command     │ Description                                     │
├─────────────┼─────────────────────────────────────────────────┤
│ /compile    │ Patient Mode compilation with logging           │
│ /test       │ Run tests with NIF active (SKIP_ZENOH_NIF=0)   │
│ /quality    │ Format + Credo + Dialyzer + Sobelow            │
│ /sa         │ Standalone environment management               │
│ /stamp      │ Validate STAMP constraints for a file           │
│ /rca        │ 5-Level Root Cause Analysis                     │
│ /journal    │ Create development journal entry                │
│ /immune     │ Validate immune system modules                  │
└─────────────┴─────────────────────────────────────────────────┘
```

### 3.1 Compile Command (`/compile`)

**Tools**: `Bash(mix:*), Bash(NO_TIMEOUT=true:*)`

**Execution**:
```bash
NO_TIMEOUT=true PATIENT_MODE=enabled \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
mix compile 2>&1 | tee -a ./data/tmp/1-compile.log
```

**Impact**:
- Never interrupts long compilations
- Logs all output for post-analysis
- 16 parallel schedulers for speed

### 3.2 Test Command (`/test`)

**Critical Constraint**: `SKIP_ZENOH_NIF=0` MANDATORY

**Execution**:
```bash
SKIP_ZENOH_NIF=0 \
NO_TIMEOUT=true PATIENT_MODE=enabled \
MIX_ENV=test mix test $ARGUMENTS
```

**Impact**:
- Tests use real Zenoh NIF (production parity)
- Full database integration via DATABASE_URL
- Failure analysis with STAMP correlation

### 3.3 Immune Command (`/immune`)

**NEW in v21.1.0**

**Purpose**: Validates Digital Immune System modules:
- Sentinel (T-Cell health scoring)
- PatternHunter (Resource detection)
- SymbioticDefense (Coordinated response)

**Impact**: Ensures P0 critical issues are addressed before deploy.

### 3.4 Journal Command (`/journal`)

**Pattern**: `journal/$(date +%Y-%m)/$(date +%Y%m%d-%H%M)-topic.md`

**Impact**: Creates standardized documentation with:
- Git context (branch, recent commits)
- STAMP compliance section
- KPI tracking

---

## L2-FIBER: Context Rules (`rules/*.md`)

### Rule Activation

Rules are activated when Claude reads/edits files matching their `paths:` pattern.

```yaml
---
paths: lib/indrajaal/safety/**/*.ex, lib/indrajaal/core/**/*.ex
---
```

### 2.1 Safety-Critical Rules

**File**: `.claude/rules/safety-critical.md`

**Trigger Paths**: `lib/indrajaal/safety/**/*.ex, lib/indrajaal/core/**/*.ex`

**Injected Context**:
- Critical safety modules (Guardian, Sentinel, PatternHunter, SymbioticDefense)
- Error handling patterns (`{:ok, result}` / `{:error, reason}`)
- State management (SQLite/DuckDB only, immutable register)
- 5-level fractal logging requirements

**Impact**: When editing safety-critical code, Claude automatically receives:
1. Module-specific constraints
2. Known P0 issues to avoid
3. Required testing patterns

### 2.2 Immune System Rules

**File**: `.claude/rules/immune-system.md`

**Trigger Paths**: `lib/indrajaal/safety/sentinel.ex, pattern_hunter.ex, symbiotic_defense.ex`

**Injected Context**:
- SC-IMMUNE-001 to SC-IMMUNE-010 constraints
- AOR-IMMUNE-001 to AOR-IMMUNE-005 rules
- Known P0 issues (error rate, recovery, detection logic)

**Impact**: Prevents re-introduction of known bugs.

### 2.3 Test Execution Rules

**File**: `.claude/rules/test-execution.md`

**Trigger Paths**: `test/**/*.exs`

**Injected Context**:
- `SKIP_ZENOH_NIF=0` requirement
- Full test command with all env vars
- AOR-TEST-NIF-* rules

**Impact**: Every test file edit includes NIF compliance reminder.

### 2.4 Property Testing Rules

**File**: `.claude/rules/property-testing.md`

**Trigger Paths**: `test/**/*.exs`

**Injected Context**:
- EP-GEN-014 resolution pattern
- Required aliases (PC for PropCheck, SD for StreamData)
- Generator usage examples

**Impact**: Prevents PropCheck/StreamData conflicts.

### 2.5 Factory Rules

**File**: `.claude/rules/factories.md`

**Trigger Paths**: `test/support/factories/**/*.ex`

**Injected Context**:
- Ash.Changeset pattern (NOT ExMachina)
- Parent-child creation order
- Required imports

**Impact**: Consistent factory implementation.

### 2.6 Ash Resource Rules

**File**: `.claude/rules/ash-resources.md`

**Trigger Paths**: `lib/indrajaal/**/*.ex`

**Injected Context**:
- BaseResource usage
- UUID primary keys
- Table naming conventions

**Impact**: Ash 3.x compliance.

---

## L1-GOSSAMER: Automation Hooks (`hooks/*.sh`)

### Hook Lifecycle

```
┌──────────────────────────────────────────────────────────────┐
│                    HOOK EXECUTION FLOW                        │
├──────────────────────────────────────────────────────────────┤
│  SessionStart ─┬─> Load PROJECT_TODOLIST.md                  │
│                └─> Display active tasks                       │
│                                                               │
│  PostToolUse ──┬─> (Edit|Write .ex/.exs) → mix format        │
│                └─> (Bash) → Log to bash-history.log           │
│                                                               │
│  Stop ─────────> Report compile errors/warnings               │
│                                                               │
│  SessionEnd ───> Sync tasks back to PROJECT_TODOLIST.md      │
└──────────────────────────────────────────────────────────────┘
```

### 1.1 Todo Sync Hook

**File**: `.claude/hooks/todo_sync_hook.sh`

**Function**: Synchronizes Claude's TodoWrite tool with `PROJECT_TODOLIST.md`

**Impact**:
- Tasks persist across sessions
- Project-level visibility into Claude's work
- Integration with external task management

### 1.2 EP-014 Check Hook

**File**: `.claude/hooks/ep014_check.sh`

**Function**: Validates PropCheck/StreamData disambiguation

**Impact**: Catches EP-GEN-014 violations before commit.

---

## Impact Analysis

### Development Workflow Impact

| Aspect | Without .claude | With .claude |
|--------|----------------|--------------|
| Compilation | May timeout | Patient Mode always |
| Testing | May use mock NIF | Real NIF (SKIP_ZENOH_NIF=0) |
| Formatting | Manual | Auto on every edit |
| Safety Checks | Ad-hoc | Systematic (460+ constraints) |
| Task Tracking | Lost between sessions | Persistent in PROJECT_TODOLIST |
| Documentation | Inconsistent | Standardized journal format |

### Security Impact

1. **Credential Protection**: DATABASE_URL in env prevents hardcoding in code
2. **Path Denial**: Prevents reading compiled binaries
3. **Audit Trail**: bash-history.log tracks all commands

### Productivity Impact

| Feature | Time Saved | Quality Improvement |
|---------|------------|---------------------|
| Auto-format | 5 sec/file | 100% consistency |
| Task sync | 2 min/session | Cross-session continuity |
| Rule injection | 10 min/task | Fewer constraint violations |
| Agent spawning | 15 min/review | Parallel validation |

---

## Maintenance Guide

### Adding New Rules

1. Create `.claude/rules/new-rule.md` with:
```markdown
---
paths: lib/path/pattern/**/*.ex
---
# Rule content...
```

2. Add to git: `git add .claude/rules/new-rule.md`

### Adding New Commands

1. Create `.claude/commands/new-command.md` with:
```markdown
---
description: Short description
allowed-tools: Bash(tool:*), Read
argument-hint: [args]
---
# Command content...
```

2. Add to git: `git add .claude/commands/new-command.md`

### Adding New Agents

1. Create `.claude/agents/new-agent.md` with:
```markdown
---
name: new-agent
description: Agent purpose
tools: Tool1, Tool2
model: haiku
---
# Agent instructions...
```

2. Add to git: `git add .claude/agents/new-agent.md`

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 21.1.0 | 2026-01-01 | Added SC-IMMUNE-*, immune.md command, 5-level logging |
| 21.0.0 | 2025-12-31 | Founder's Covenant integration, SC-FOUNDER-* |
| 20.0.0 | 2025-12-29 | PROMETHEUS verification layer |

---

## Related Documents

- `CLAUDE.md` - Master specification (3,911 lines)
- `docs/architecture/INDRAJAAL_5LEVEL_SYSTEM_SUMMARY.md` - System overview
- `PROJECT_TODOLIST.md` - Active task tracking

---

**Framework**: SOPv5.11 + STAMP + TDG
**Classification**: L4-THORAX (30-day retention)
