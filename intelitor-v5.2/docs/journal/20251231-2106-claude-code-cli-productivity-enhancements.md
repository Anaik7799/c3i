# Claude Code CLI Productivity Enhancements for Indrajaal

**Date**: 2025-12-31T21:06:00+01:00
**Branch**: `feature/20251231-rapid-execution-biomorphic-actualization`
**Author**: Claude Opus 4.5 + Abhijit Naik
**Version**: v21.1.0-FOUNDERS-COVENANT

---

## Executive Summary

This journal documents the comprehensive Claude Code CLI productivity enhancements implemented for the Indrajaal safety-critical system. The enhancements leverage Claude Code's extensibility features to create a tailored development environment optimized for:

- **1,203 Elixir source files** across 10 domains
- **836 test files** with dual property testing framework
- **1,475 automation scripts** in 87 directories
- **445 STAMP safety constraints** requiring validation
- **Multi-agent coordination** with 50 deployed agents

---

## Table of Contents

1. [.claude Directory Structure](#1-claude-directory-structure)
2. [Custom Slash Commands](#2-custom-slash-commands)
3. [Specialized Subagents](#3-specialized-subagents)
4. [Modular Rules](#4-modular-rules)
5. [LSP Plugin Configuration](#5-lsp-plugin-configuration)
6. [MCP Server Integration](#6-mcp-server-integration)
7. [Hooks & Automation](#7-hooks--automation)
8. [Settings Configuration](#8-settings-configuration)
9. [Shell Integration](#9-shell-integration)
10. [Usage Guide](#10-usage-guide)
11. [Expected Productivity Gains](#11-expected-productivity-gains)

---

## 1. .claude Directory Structure

```
.claude/
├── settings.json              # Main settings with hooks, env, permissions
├── settings.local.json        # Local overrides (gitignored)
├── bash-history.log           # Auto-logged bash commands
│
├── commands/                  # Custom slash commands (7 files)
│   ├── compile.md             # /compile - Patient Mode compilation
│   ├── test.md                # /test - Test execution with analysis
│   ├── quality.md             # /quality - Full quality pipeline
│   ├── sa.md                  # /sa - Standalone environment management
│   ├── stamp.md               # /stamp - STAMP constraint validation
│   ├── rca.md                 # /rca - 5-Level Root Cause Analysis
│   └── journal.md             # /journal - Development journal creation
│
├── agents/                    # Specialized subagents (4 files)
│   ├── safety-validator.md    # STAMP constraint checking (haiku)
│   ├── test-generator.md      # TDG-compliant test generation (sonnet)
│   ├── code-reviewer.md       # Code review with SC-* checks (sonnet)
│   └── script-finder.md       # Navigate 1,475 scripts (haiku)
│
├── rules/                     # Domain-specific context rules (4 files)
│   ├── ash-resources.md       # Ash 3.x patterns (lib/indrajaal/**/*.ex)
│   ├── property-testing.md    # Dual property testing (test/**/*.exs)
│   ├── safety-critical.md     # SIL-2 compliance (lib/indrajaal/safety/**)
│   └── factories.md           # Test factory patterns (test/support/factories/**)
│
└── plugins/                   # LSP and tool plugins
    └── elixir-lsp/            # Multi-language LSP plugin
        ├── .claude-plugin/
        │   └── plugin.json    # Plugin manifest (v3.1.0)
        └── .lsp.json          # LSP server configurations (10 languages)
```

---

## 2. Custom Slash Commands

### Purpose
Slash commands provide quick access to common workflows without typing full commands. They're discoverable via `/help` and auto-complete.

### Commands Detail

#### `/compile` - Patient Mode Compilation
**File**: `.claude/commands/compile.md`
**Allowed Tools**: `Bash(mix:*)`, `Bash(NO_TIMEOUT=true:*)`, `Read`

**Function**:
- Executes compilation with Patient Mode environment variables
- Logs output to `./data/tmp/1-compile.log`
- Reports warnings/errors categorized by type
- Updates journal on significant changes

**Usage**:
```bash
/compile                    # Full compilation
/compile --warnings-as-errors  # Strict mode
```

**Expected Utility**:
- 80% faster than typing full command
- Consistent logging for RCA
- Automatic error categorization

---

#### `/test` - Test Execution with Analysis
**File**: `.claude/commands/test.md`
**Allowed Tools**: `Bash(mix:*)`, `Bash(MIX_ENV=test:*)`, `Read`, `Grep`

**Function**:
- Runs tests with Patient Mode and database configuration
- Analyzes failures and extracts file:line references
- Identifies PropCheck/StreamData conflicts (EP-GEN-014)
- Suggests fixes based on error patterns

**Usage**:
```bash
/test                           # Run all tests
/test test/indrajaal/safety/    # Run specific directory
/test --seed 12345 --trace      # With options
```

**Expected Utility**:
- Automatic failure analysis
- STAMP constraint correlation
- Fix suggestions from EP-* patterns

---

#### `/quality` - Full Quality Pipeline
**File**: `.claude/commands/quality.md`
**Allowed Tools**: `Bash(mix:*)`

**Function**:
- Executes 4-step quality gate:
  1. `mix format --check-formatted`
  2. `mix credo --strict`
  3. `mix dialyzer`
  4. `mix sobelow --exit`
- Reports pass/fail for each gate
- Calculates overall quality score (0-100%)

**Usage**:
```bash
/quality                # Run full pipeline
```

**Expected Utility**:
- Single command for all quality checks
- Gate status tracking
- Actionable fix suggestions

---

#### `/sa` - Standalone Environment
**File**: `.claude/commands/sa.md`
**Allowed Tools**: `Bash(podman-compose:*)`, `Bash(podman:*)`

**Function**:
- Manages 3-container standalone stack:
  - `indrajaal-db-prod` (PostgreSQL 17 + TimescaleDB)
  - `indrajaal-obs-prod` (OTEL + Prometheus + Grafana + Loki)
  - `indrajaal-app-prod` (Phoenix + FLAME + Redis)

**Usage**:
```bash
/sa up          # Start all containers
/sa down        # Stop containers
/sa status      # Show status
/sa logs app    # Stream app logs
/sa clean       # Stop + remove volumes
```

**Expected Utility**:
- Quick environment management
- Consistent container operations
- Documented architecture reference

---

#### `/stamp` - STAMP Constraint Validation
**File**: `.claude/commands/stamp.md`
**Allowed Tools**: `Read`, `Grep`, `Glob`

**Function**:
- Validates code against 445 STAMP safety constraints
- Checks constraint categories:
  - SC-VAL-* (Validation)
  - SC-CNT-* (Container)
  - SC-AGT-* (Agent)
  - SC-SEC-* (Security)
  - SC-HOLON-* (Holon State)
  - SC-REG-* (Immutable Register)
- Reports violations with severity levels

**Usage**:
```bash
/stamp lib/indrajaal/safety/guardian.ex
/stamp Indrajaal.Safety.Guardian
```

**Expected Utility**:
- Proactive constraint checking
- SIL-2 compliance verification
- Remediation suggestions

---

#### `/rca` - 5-Level Root Cause Analysis
**File**: `.claude/commands/rca.md`
**Allowed Tools**: `Read`, `Grep`, `Glob`, `Bash(git:*)`

**Function**:
- Applies TPS Jidoka 5-Why methodology:
  - L1: Symptom (what failed)
  - L2: Immediate Cause (direct code)
  - L3: Contributing Factors (missing guards)
  - L4: Systemic Issues (patterns, constraints)
  - L5: Root Cause (fundamental fix)
- Generates prevention measures

**Usage**:
```bash
/rca "undefined function calculate_coherence_score/2"
/rca lib/indrajaal/kms/technical_leadership.ex:791
```

**Expected Utility**:
- Systematic problem analysis
- Prevention-focused solutions
- Documentation for future reference

---

#### `/journal` - Development Journal Entry
**File**: `.claude/commands/journal.md`
**Allowed Tools**: `Write`, `Bash(date:*)`, `Bash(git:*)`

**Function**:
- Creates timestamped journal entry
- Auto-populates:
  - Current branch
  - Recent commits
  - Template sections (Context, Summary, Technical Details, STAMP Compliance, Next Steps, KPIs)

**Usage**:
```bash
/journal zenoh-nif-fix
/journal claude-code-productivity
```

**Expected Utility**:
- Consistent documentation
- Automatic context capture
- Searchable development history

---

## 3. Specialized Subagents

### Purpose
Subagents are delegated AI instances with specific expertise, tools, and context. They run in parallel for efficiency.

### Agents Detail

#### `safety-validator` - STAMP Constraint Checker
**File**: `.claude/agents/safety-validator.md`
**Model**: `haiku` (fast, cost-effective)
**Tools**: `Read`, `Grep`, `Glob`

**Function**:
- Validates code against 445 STAMP constraints
- Categorizes by severity:
  - **Critical** (Block): SC-VAL-*, SC-CNT-*, SC-SEC-*, SC-HOLON-*, SC-REG-*
  - **High** (Warn): SC-AGT-*, SC-CMP-*, SC-PROP-*
  - **Medium** (Note): SC-ASH-*, SC-DB-*, SC-FAC-*

**When Invoked**:
- Automatically after changes to safety-critical modules
- Manually via "use safety-validator agent"

**Expected Utility**:
- Proactive constraint checking
- Parallel validation during development
- Consistent safety verification

---

#### `test-generator` - TDG Test Creator
**File**: `.claude/agents/test-generator.md`
**Model**: `sonnet` (balanced quality/speed)
**Tools**: `Read`, `Write`, `Grep`, `Glob`

**Function**:
- Generates TDG-compliant tests with:
  - Dual property testing (PropCheck + ExUnitProperties)
  - Proper PC/SD aliases (EP-GEN-014 compliant)
  - STAMP constraint documentation
  - TPS 5-Level RCA context
- Tests designed to FAIL initially (TDG compliance)

**When Invoked**:
- When creating new modules
- When filling coverage gaps
- Via "use test-generator for Module"

**Expected Utility**:
- Consistent test patterns
- Automatic dual property framework
- Coverage gap identification

---

#### `code-reviewer` - Code Quality Reviewer
**File**: `.claude/agents/code-reviewer.md`
**Model**: `sonnet`
**Tools**: `Read`, `Grep`, `Glob`, `Bash(git diff:*)`

**Function**:
- Reviews code against checklists:
  - Ash 3.x Compliance (SC-ASH-*)
  - Variable Naming (SC-VAR-*)
  - Property Testing (SC-PROP-*)
  - Code Quality (SC-CREDO-*)
  - Documentation (SC-DOC-*)
- Outputs prioritized findings (CRITICAL/WARNING/SUGGESTION)

**When Invoked**:
- Proactively after significant code changes
- Before commits/PRs
- Via "have code-reviewer check this"

**Expected Utility**:
- Consistent code review standards
- Pattern enforcement
- Early defect detection

---

#### `script-finder` - Script Navigator
**File**: `.claude/agents/script-finder.md`
**Model**: `haiku` (fast lookups)
**Tools**: `Glob`, `Grep`, `Read`

**Function**:
- Navigates 1,475 scripts across 87 directories
- Searches by:
  - Filename patterns
  - Content/description
  - Category (compilation, testing, quality, etc.)
- Returns path, purpose, usage example

**When Invoked**:
- When looking for automation scripts
- Via "find script for compilation"

**Expected Utility**:
- Rapid script discovery
- Reduced duplication
- Better automation awareness

---

## 4. Modular Rules

### Purpose
Rules provide path-specific context that Claude automatically loads when working on matching files. They enable domain-specific guidance without cluttering the main CLAUDE.md.

### Rules Detail

#### `ash-resources.md` - Ash 3.x Patterns
**File**: `.claude/rules/ash-resources.md`
**Paths**: `lib/indrajaal/**/*.ex`

**Content**:
- Use `Indrajaal.BaseResource` (SC-DB-001)
- Table naming: snake_case, no domain prefix
- `uuid_primary_key :id` (SC-DB-005)
- Tenant access via `query.tenant` (SC-ASH3-001)
- Actor passing in `for_update` (SC-ASH3-004)
- Action patterns with `force_change_attribute`
- Index patterns with `create_if_not_exists`

**Expected Utility**:
- Consistent Ash resource creation
- Automatic pattern enforcement
- Reduced Ash 3.x migration issues

---

#### `property-testing.md` - Dual Property Framework
**File**: `.claude/rules/property-testing.md`
**Paths**: `test/**/*.exs`

**Content**:
- **CRITICAL**: Generator disambiguation (EP-GEN-014)
- Required imports pattern:
  ```elixir
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  ```
- PropCheck: `PC.` prefix for generators
- ExUnitProperties: `SD.` prefix for generators
- Validation: `mix validate.ep014`

**Expected Utility**:
- Zero generator conflicts
- Consistent test patterns
- Compile-time error prevention

---

#### `safety-critical.md` - SIL-2 Compliance
**File**: `.claude/rules/safety-critical.md`
**Paths**: `lib/indrajaal/safety/**/*.ex`, `lib/indrajaal/core/**/*.ex`

**Content**:
- Error handling: `{:ok, result}` or `{:error, reason}`
- State management: SQLite/DuckDB only (SC-HOLON-001)
- Mutations via immutable register (SC-REG-001)
- Structured logging with Telemetry
- Fractal levels: L0-Spine to L4-Gossamer
- Testing: 100% branch coverage, FMEA analysis

**Expected Utility**:
- IEC 61508 SIL-2 compliance
- Consistent safety patterns
- Audit trail requirements

---

#### `factories.md` - Test Factory Patterns
**File**: `.claude/rules/factories.md`
**Paths**: `test/support/factories/**/*.ex`

**Content**:
- Use Ash.Changeset pattern (NOT ExMachina)
- Factory for EVERY resource (SC-FAC-002)
- Create parents BEFORE children (SC-FAC-003)
- Import FactoryUtilities
- Use `Ash.UUID.generate()` for IDs

**Expected Utility**:
- Consistent test data creation
- Proper resource relationships
- Reduced test setup errors

---

## 5. LSP Plugin Configuration

### Purpose
Language Server Protocol integration provides code intelligence (go-to-definition, hover, autocomplete) for all project languages.

### Plugin Structure
```
.claude/plugins/elixir-lsp/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest
└── .lsp.json                 # LSP server configurations
```

### Plugin Manifest (v3.1.0)
**File**: `.claude/plugins/elixir-lsp/.claude-plugin/plugin.json`

```json
{
  "name": "indrajaal-lsp",
  "description": "Multi-language LSP with Elixir framework support",
  "version": "3.1.0",
  "languages": ["elixir", "erlang", "gleam", "fsharp", "csharp",
                "rust", "python", "bash", "zsh", "sql"],
  "elixirFrameworks": ["phoenix", "ecto", "ash", "oban", "liveview", "absinthe"]
}
```

### Supported Languages (10)

| Language | Server | Extensions | Special Features |
|----------|--------|------------|------------------|
| **Elixir** | elixir-ls | `.ex`, `.exs`, `.heex`, `.leex` | Phoenix/Ecto/Ash/Oban support |
| **Erlang** | erlang_ls | `.erl`, `.hrl` | OTP integration |
| **Gleam** | gleam lsp | `.gleam` | Type inference |
| **F#** | fsautocomplete | `.fs`, `.fsi`, `.fsx` | .NET 10 support |
| **C#** | csharp-ls | `.cs`, `.csx` | Lightweight server |
| **Rust** | rust-analyzer | `.rs` | Clippy integration |
| **Python** | pyright | `.py`, `.pyi` | Type checking |
| **Bash/Zsh** | bash-language-server | `.sh`, `.bash`, `.zsh` | Shell scripts |
| **SQL** | sqls | `.sql`, `.pgsql` | PostgreSQL/SQLite/DuckDB |

### Elixir Framework Support

The Elixir LSP is configured with enhanced support for:
- **Phoenix**: HEEx/LEEx templates, LiveView, Controllers
- **Ecto**: Schemas, Migrations, Queries
- **Ash**: Resources, Actions, Policies
- **Oban**: Jobs, Workers, Queues
- **Absinthe**: GraphQL Schemas, Resolvers

**Expected Utility**:
- Go-to-definition across 1,203 files
- Hover documentation for library functions
- DSL macro autocomplete
- Compile-time error detection

---

## 6. MCP Server Integration

### Purpose
Model Context Protocol (MCP) servers extend Claude's capabilities by connecting to external tools, databases, and services. MCP is the "USB-C" of AI integrations - a universal standard for connecting AI assistants to external data sources.

### Configuration File
**File**: `.mcp.json` (project-scoped, shared via git)

### Configured Servers (8) - Complete Reference

---

### 6.1 GitHub MCP Server

**Package**: `@modelcontextprotocol/server-github`
**Type**: Core Development

#### Configuration
```json
{
  "github": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-github"],
    "env": {
      "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
    }
  }
}
```

#### Setup Requirements
```bash
# Create GitHub Personal Access Token at:
# https://github.com/settings/tokens
# Required scopes: repo, read:org, read:user

export GITHUB_TOKEN="ghp_your_token_here"
```

#### Capabilities
| Tool | Description |
|------|-------------|
| `list_repos` | List repositories for authenticated user |
| `get_repo` | Get repository details |
| `list_issues` | List issues with filtering |
| `create_issue` | Create new issue |
| `get_issue` | Get issue details |
| `list_pull_requests` | List PRs with filtering |
| `get_pull_request` | Get PR details with diff |
| `create_pull_request` | Create new PR |
| `list_commits` | List commits on branch |
| `get_file_contents` | Read file from repo |
| `search_code` | Search code across repos |
| `search_issues` | Search issues/PRs |

#### Usage Examples
```bash
# List open PRs
> What pull requests are open on this repository?

# Create issue
> Create an issue titled "Zenoh NIF fails on ARM64" with label "bug"

# Review PR
> Show me the changes in PR #42 and suggest improvements

# Search code
> Find all uses of Guardian module across our repos

# Get file history
> Who contributed to lib/indrajaal/safety/guardian.ex?
```

#### Expected Utility
- **Automated PR Creation**: Create PRs directly from conversation
- **Issue Tracking**: Create/update issues without browser
- **Code Review**: Access diffs and suggest changes inline
- **Cross-Repo Search**: Find patterns across organization
- **Commit History**: Trace changes without git commands

---

### 6.2 PostgreSQL MCP Server

**Package**: `@modelcontextprotocol/server-postgres`
**Type**: Database Access

#### Configuration
```json
{
  "postgres": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-postgres"],
    "env": {
      "POSTGRES_CONNECTION_STRING": "postgresql://postgres:postgres@localhost:5433/indrajaal_dev"
    }
  }
}
```

#### Connection Details
| Parameter | Value |
|-----------|-------|
| Host | `localhost` |
| Port | `5433` |
| Database | `indrajaal_dev` |
| User | `postgres` |
| Password | `postgres` |

#### Capabilities
| Tool | Description |
|------|-------------|
| `query` | Execute read-only SQL queries |
| `list_tables` | List all tables in database |
| `describe_table` | Get table schema, columns, types |
| `list_indexes` | List indexes on table |
| `explain_query` | Get query execution plan |

#### Usage Examples
```bash
# List tables
> What tables exist in the database?

# Describe schema
> Show me the schema for the users table

# Query data
> How many alarms were created in the last 24 hours?

# Analyze performance
> Explain the query plan for selecting active devices

# Check relationships
> What foreign keys reference the tenants table?
```

#### Expected Utility
- **Schema Exploration**: Understand database structure without psql
- **Data Queries**: Quick data lookups during development
- **Performance Analysis**: Query plan inspection
- **Relationship Mapping**: Understand table relationships
- **Migration Planning**: See current state before migrations

#### Security Note
Server is **read-only** by default. No INSERT/UPDATE/DELETE operations allowed.

---

### 6.3 Git MCP Server

**Package**: `@modelcontextprotocol/server-git`
**Type**: Version Control

#### Configuration
```json
{
  "git": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-git", "--repository", "."]
  }
}
```

#### Capabilities
| Tool | Description |
|------|-------------|
| `git_status` | Show working tree status |
| `git_diff` | Show changes between commits |
| `git_log` | Show commit history |
| `git_blame` | Show line-by-line authorship |
| `git_branch` | List/manage branches |
| `git_show` | Show commit details |
| `git_stash` | Manage stashes |
| `search_commits` | Search commit messages |

#### Usage Examples
```bash
# Recent changes
> What files changed in the last 5 commits?

# Blame
> Who last modified line 150 of guardian.ex?

# Branch comparison
> What's different between main and this branch?

# Commit search
> Find commits mentioning "Zenoh"

# Change history
> Show the history of changes to lib/indrajaal/safety/
```

#### Expected Utility
- **Change Tracking**: Understand recent modifications
- **Authorship**: Identify who changed what
- **Branch Management**: Compare branches without switching
- **Commit Archaeology**: Find when changes were introduced
- **Diff Analysis**: Understand scope of changes

---

### 6.4 Filesystem MCP Server

**Package**: `@modelcontextprotocol/server-filesystem`
**Type**: Secure File Access

#### Configuration
```json
{
  "filesystem": {
    "command": "npx",
    "args": [
      "-y",
      "@modelcontextprotocol/server-filesystem",
      "/home/an/dev/ver/intelitor-v5.2/lib",
      "/home/an/dev/ver/intelitor-v5.2/test",
      "/home/an/dev/ver/intelitor-v5.2/config",
      "/home/an/dev/ver/intelitor-v5.2/scripts"
    ]
  }
}
```

#### Allowed Directories
| Path | Contents |
|------|----------|
| `lib/` | 1,203 Elixir source files |
| `test/` | 836 test files |
| `config/` | Configuration files |
| `scripts/` | 1,475 automation scripts |

#### Capabilities
| Tool | Description |
|------|-------------|
| `read_file` | Read file contents |
| `read_multiple_files` | Read multiple files at once |
| `write_file` | Write/create files |
| `list_directory` | List directory contents |
| `create_directory` | Create new directory |
| `move_file` | Move/rename files |
| `search_files` | Search by name pattern |
| `get_file_info` | Get file metadata |

#### Security Model
- **Allowlist-based**: Only configured directories accessible
- **No parent traversal**: Cannot access `../` outside allowed paths
- **Read-heavy**: Optimized for reading, writing requires confirmation

#### Usage Examples
```bash
# Read file
> Show me the contents of lib/indrajaal/safety/guardian.ex

# List directory
> What files are in test/indrajaal/safety/

# Search files
> Find all files named "*_test.exs" in test/

# Batch read
> Read all factory files in test/support/factories/
```

#### Expected Utility
- **Secure Access**: Controlled file operations
- **Bulk Operations**: Read multiple files efficiently
- **Directory Navigation**: Explore project structure
- **Pattern Search**: Find files by name

---

### 6.5 Memory MCP Server

**Package**: `@modelcontextprotocol/server-memory`
**Type**: Cognitive Enhancement

#### Configuration
```json
{
  "memory": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-memory"]
  }
}
```

#### How It Works
The Memory server maintains a **knowledge graph** of entities and relationships that persists across sessions.

#### Capabilities
| Tool | Description |
|------|-------------|
| `create_entities` | Add new entities to memory |
| `create_relations` | Link entities together |
| `add_observations` | Add facts about entities |
| `delete_entities` | Remove entities |
| `delete_observations` | Remove facts |
| `delete_relations` | Remove relationships |
| `read_graph` | Query the knowledge graph |
| `search_nodes` | Search for entities |
| `open_nodes` | Get entity details |

#### Entity Types for Indrajaal
| Entity Type | Examples |
|-------------|----------|
| `Module` | `Indrajaal.Safety.Guardian`, `Indrajaal.KMS.Analytics` |
| `Constraint` | `SC-HOLON-001`, `SC-VAL-001` |
| `Pattern` | `EP-GEN-014`, `EP-VAR-001` |
| `Agent` | `safety-validator`, `test-generator` |
| `Container` | `indrajaal-app-prod`, `indrajaal-db-prod` |

#### Usage Examples
```bash
# Store knowledge
> Remember that Holon state must use SQLite per SC-HOLON-001

# Create relationship
> Guardian module implements SC-SEC-001 through SC-SEC-010

# Recall knowledge
> What do you remember about the Zenoh integration?

# Query relationships
> What modules implement safety constraints?
```

#### Expected Utility
- **Persistent Context**: Knowledge survives session restarts
- **Relationship Tracking**: Understand module dependencies
- **Constraint Mapping**: Remember which code implements which constraints
- **Project Learning**: Build understanding over time

---

### 6.6 Sequential Thinking MCP Server

**Package**: `@modelcontextprotocol/server-sequential-thinking`
**Type**: Cognitive Enhancement

#### Configuration
```json
{
  "sequential-thinking": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
  }
}
```

#### How It Works
Enables **dynamic, reflective problem-solving** through structured thought sequences. Each thought can:
- Build on previous thoughts
- Revise earlier conclusions
- Branch into alternative paths
- Adjust total steps as understanding evolves

#### Capabilities
| Tool | Description |
|------|-------------|
| `create_thinking_session` | Start new problem-solving session |
| `add_thought` | Add next thought in sequence |
| `revise_thought` | Modify previous thought |
| `branch_thought` | Explore alternative path |
| `summarize_session` | Get session summary |
| `get_session` | Retrieve session state |

#### Use Cases for Indrajaal
| Problem Type | How It Helps |
|--------------|--------------|
| **RCA** | Systematic 5-Why analysis |
| **Architecture** | Design decision evaluation |
| **Debugging** | Step-by-step root cause identification |
| **Planning** | Multi-phase implementation planning |
| **Optimization** | Performance analysis and solutions |

#### Usage Examples
```bash
# Root cause analysis
> Use sequential thinking to analyze why Zenoh NIF compilation fails

# Architecture decision
> Think through the trade-offs of using SQLite vs PostgreSQL for holon state

# Debugging complex issue
> Systematically investigate why tests timeout intermittently

# Planning
> Plan the migration from Ash 2.x to Ash 3.x step by step
```

#### Expected Utility
- **Structured Analysis**: Systematic problem decomposition
- **Revision Support**: Can backtrack and revise conclusions
- **Branching**: Explore multiple solution paths
- **Transparency**: See the reasoning chain

---

### 6.7 SQLite MCP Server

**Package**: `@modelcontextprotocol/server-sqlite`
**Type**: Holon State Access

#### Configuration
```json
{
  "sqlite": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-sqlite", "--db-path", "./data/holons"]
  }
}
```

#### Purpose
Provides access to **holon state databases** per SC-HOLON-001:
> "ALL holon core state MUST use SQLite/DuckDB ONLY"

#### Directory Structure
```
data/holons/
├── {holon_id}/
│   ├── state.db          # Real-time state (WAL mode)
│   ├── state.db-wal      # Write-ahead log
│   └── schema.json       # Schema documentation
```

#### Capabilities
| Tool | Description |
|------|-------------|
| `query` | Execute SQL query |
| `list_tables` | List tables in database |
| `describe_table` | Get table schema |
| `read_query` | Read-only query execution |

#### Usage Examples
```bash
# List holon databases
> What holon databases exist in data/holons/?

# Query holon state
> What is the current state of the guardian holon?

# Check evolution history
> Show the last 10 state transitions for holon X

# Verify integrity
> Check the hash chain integrity for the immutable register
```

#### Expected Utility
- **State Inspection**: Debug holon state directly
- **Evolution Tracking**: See state change history
- **Integrity Verification**: Validate hash chains
- **Portable Access**: Query without Elixir runtime

#### STAMP Compliance
- **SC-HOLON-001**: SQLite for holon state ✓
- **SC-HOLON-007**: WAL mode for real-time ✓
- **SC-HOLON-009**: Authoritative source ✓

---

### 6.8 Fetch MCP Server

**Package**: `@modelcontextprotocol/server-fetch`
**Type**: Web Content Access

#### Configuration
```json
{
  "fetch": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-fetch"]
  }
}
```

#### Capabilities
| Tool | Description |
|------|-------------|
| `fetch` | Fetch URL and convert to markdown |

#### Content Processing
- Fetches web pages
- Converts HTML to clean markdown
- Removes scripts, styles, ads
- Preserves structure and links
- Handles redirects

#### Usage Examples
```bash
# Documentation lookup
> Fetch the Ash 3.0 migration guide from hexdocs

# API reference
> Get the Phoenix LiveView documentation for push_event

# Library docs
> Fetch the PropCheck README from GitHub

# Release notes
> Get the Elixir 1.19 release notes
```

#### Expected Utility
- **Documentation Access**: Read docs without leaving Claude
- **API Reference**: Quick lookups during development
- **Release Notes**: Check for breaking changes
- **Tutorial Access**: Follow guides inline

---

### MCP Server Summary

| Server | Category | Primary Use | Model |
|--------|----------|-------------|-------|
| **github** | Development | PR/Issue management | API |
| **postgres** | Database | Schema/data queries | Read-only SQL |
| **git** | Version Control | History/blame/diff | Local repo |
| **filesystem** | File Access | Secure file ops | Allowlist |
| **memory** | Cognitive | Persistent knowledge | Graph DB |
| **sequential-thinking** | Cognitive | Complex problem solving | Chain-of-thought |
| **sqlite** | Holon State | State inspection | Read-only SQL |
| **fetch** | Web | Documentation lookup | HTTP/Markdown |

### Setup Checklist

```bash
# 1. Install Node.js (required for npx)
node --version  # Should be 18+

# 2. Set GitHub token
export GITHUB_TOKEN="ghp_your_token_here"

# 3. Ensure PostgreSQL is running
podman-compose -f lib/cepaf/artifacts/podman-compose-db-standalone.yml up -d

# 4. Verify MCP servers
claude
> /mcp list

# 5. Test each server
> /mcp get github
> /mcp get postgres
```

### Troubleshooting

| Issue | Solution |
|-------|----------|
| `github` auth fails | Check GITHUB_TOKEN is set and valid |
| `postgres` connection refused | Ensure DB container is running on port 5433 |
| `filesystem` access denied | Verify paths in .mcp.json match actual paths |
| `memory` not persisting | Check ~/.mcp/memory/ directory permissions |
| `fetch` timeout | URL may be blocking automated requests |

### Security Considerations

1. **GitHub Token**: Store in environment, not in .mcp.json
2. **PostgreSQL**: Read-only access only
3. **Filesystem**: Allowlist restricts access
4. **SQLite**: Local files only, no network
5. **Fetch**: Some sites may block; use responsibly

---

## 7. Hooks & Automation

### Purpose
Hooks execute shell commands at lifecycle events, enabling deterministic automation without manual intervention.

### Configured Hooks

#### SessionStart Hook
**Trigger**: When Claude session starts or resumes

**Action**:
```bash
echo 'Erlang/OTP 28 [erts-16.2]...'
elixir scripts/planning/claude_todo_sync.exs --sync --to-claude
```

**Purpose**: Load project tasks into Claude's todo list at session start

---

#### SessionEnd Hook
**Trigger**: When Claude session ends

**Action**:
```bash
elixir scripts/planning/claude_todo_sync.exs --sync --from-claude
```

**Purpose**: Sync Claude's todo list back to project task tracker

---

#### PostToolUse: Auto-Format Hook
**Trigger**: After Edit or Write tool completes
**Matcher**: `Edit|Write`

**Action**:
```bash
if [[ "$FILE" == *.ex || "$FILE" == *.exs ]]; then
  mix format "$FILE"
fi
```

**Purpose**: Automatically format Elixir files after editing

---

#### PostToolUse: Bash Logging Hook
**Trigger**: After any Bash tool execution
**Matcher**: `Bash`

**Action**:
```bash
echo "$(date +%Y%m%d-%H%M%S) $CMD" >> .claude/bash-history.log
```

**Purpose**: Log all bash commands for audit trail and RCA

---

#### Stop Hook
**Trigger**: When Claude finishes responding

**Action**:
```bash
if [ -f ./data/tmp/1-compile.log ]; then
  ERRORS=$(grep -c 'error:' ./data/tmp/1-compile.log)
  WARNINGS=$(grep -c 'warning:' ./data/tmp/1-compile.log)
  echo "Compile status: $ERRORS errors, $WARNINGS warnings"
fi
```

**Purpose**: Report compile status at end of each response

---

**Expected Utility**:
- Zero manual formatting
- Complete command audit trail
- Automatic task synchronization
- Compile status awareness

---

## 8. Settings Configuration

### File: `.claude/settings.json`

### Key Settings

#### Model & Cleanup
```json
{
  "model": "opus",
  "cleanupPeriodDays": 99999
}
```

#### Environment Variables
```json
{
  "env": {
    "NO_TIMEOUT": "true",
    "PATIENT_MODE": "enabled",
    "INFINITE_PATIENCE": "true",
    "ELIXIR_ERL_OPTIONS": "+S 16:16 +SDio 16",
    "BASH_DEFAULT_TIMEOUT_MS": "120000",
    "BASH_MAX_TIMEOUT_MS": "600000",
    "POSTGRES_USER": "postgres",
    "POSTGRES_PASSWORD": "postgres",
    "DATABASE_URL": "ecto://postgres:postgres@localhost:5433/indrajaal_test"
  }
}
```

#### Permissions
```json
{
  "permissions": {
    "allow": [
      "*",
      "Bash(mix:*)",
      "Bash(podman:*)",
      "Bash(git:*)",
      "WebSearch"
    ],
    "deny": [
      "Read(.git/objects/**)",
      "Read(_build/**)",
      "Read(deps/**)"
    ]
  }
}
```

#### File Suggestion
```json
{
  "fileSuggestion": {
    "type": "command",
    "command": "rg --files . --glob '!_build' --glob '!deps' | head -20"
  }
}
```

**Expected Utility**:
- Patient Mode always enabled
- Appropriate timeouts for large codebase
- Database credentials pre-configured
- Efficient file suggestions

---

## 9. Shell Integration

### Files Modified

#### `~/.indrajaal_aliases`
Added `claude()` function that:
- Detects if in Indrajaal project (checks for `.claude/plugins/elixir-lsp`)
- Auto-adds `--plugin-dir` argument
- Works from any directory within project

```bash
claude() {
    local plugin_args=""
    if [[ -d ".claude/plugins/elixir-lsp" ]]; then
        plugin_args="--plugin-dir .claude/plugins/elixir-lsp"
    elif [[ -d "$INDRAJAAL_DIR/.claude/plugins/elixir-lsp" && "$PWD" == "$INDRAJAAL_DIR"* ]]; then
        plugin_args="--plugin-dir $INDRAJAAL_DIR/.claude/plugins/elixir-lsp"
    fi
    /home/an/.claude/local/claude $plugin_args "$@"
}
```

#### `devenv.nix`
Added `scripts.claude.exec` for devenv shell:
```nix
scripts.claude.exec = ''
  /home/an/.claude/local/claude --plugin-dir .claude/plugins/elixir-lsp "$@"
'';
```

#### Language Servers in devenv.nix
```nix
packages = with pkgs; [
  # ... existing packages ...
  elixir-ls
  erlang-ls
  gleam
  fsautocomplete
  csharp-ls
  pyright
  nodePackages.bash-language-server
  sqls
];
```

**Expected Utility**:
- LSP auto-enabled in devenv shell
- LSP auto-enabled from any project subdirectory
- Consistent claude command behavior

---

## 10. Usage Guide

### Quick Reference

| Task | Command |
|------|---------|
| Start Claude with LSP | `claude` (anywhere in project) |
| Compile with Patient Mode | `/compile` |
| Run tests | `/test [path]` |
| Quality gate | `/quality` |
| Start containers | `/sa up` |
| Check STAMP constraints | `/stamp file.ex` |
| Root cause analysis | `/rca "error message"` |
| Create journal entry | `/journal topic-slug` |
| List MCP servers | `/mcp list` |
| View commands | `/help` |

### Subagent Invocation

```bash
# Safety validation
> Use the safety-validator agent to check lib/indrajaal/safety/guardian.ex

# Test generation
> Have test-generator create tests for Indrajaal.KMS.Analytics

# Code review
> Ask code-reviewer to review my recent changes

# Script discovery
> Use script-finder to find compilation scripts
```

### MCP Resource Access

```bash
# GitHub
> @github:pr://123          # Reference PR
> @github:issue://456       # Reference issue

# Database
> Query the users table schema

# Git
> Show recent commits to lib/indrajaal/safety/
```

---

## 11. Expected Productivity Gains

### Quantified Benefits

| Enhancement | Time Saved | Frequency | Weekly Impact |
|-------------|------------|-----------|---------------|
| Slash commands | 30s/use | 50/week | 25 min |
| Auto-formatting | 5s/file | 100/week | 8 min |
| Subagent delegation | 5 min/task | 20/week | 100 min |
| LSP navigation | 10s/lookup | 200/week | 33 min |
| MCP database queries | 2 min/query | 30/week | 60 min |
| Bash command logging | N/A | Continuous | RCA enablement |
| Rules auto-loading | 30s/context | 50/week | 25 min |

**Total Estimated Weekly Savings**: ~4 hours

### Qualitative Benefits

1. **Consistency**: All developers use same patterns, commands, constraints
2. **Safety**: STAMP constraints checked proactively
3. **Auditability**: Complete bash command history
4. **Discoverability**: 1,475 scripts searchable via agent
5. **Context Awareness**: Path-specific rules loaded automatically
6. **Memory Persistence**: Project knowledge retained across sessions

---

## STAMP Compliance

This enhancement addresses the following constraints:

- **SC-CLI-001**: Respect CLI rate limits
- **SC-CLI-002**: Max 10 concurrent tool calls
- **SC-CLI-003**: Batch file operations
- **SC-CLI-007**: Prefer Glob/Grep for simple searches
- **SC-CLI-008**: Use agents for multi-step explorations
- **SC-PROP-023**: PropCheck/StreamData disambiguation
- **SC-VAL-001**: Patient Mode only
- **SC-HOLON-001**: SQLite/DuckDB for holon state

---

## Files Created/Modified

### New Files (19)
```
.claude/commands/compile.md
.claude/commands/test.md
.claude/commands/quality.md
.claude/commands/sa.md
.claude/commands/stamp.md
.claude/commands/rca.md
.claude/commands/journal.md
.claude/agents/safety-validator.md
.claude/agents/test-generator.md
.claude/agents/code-reviewer.md
.claude/agents/script-finder.md
.claude/rules/ash-resources.md
.claude/rules/property-testing.md
.claude/rules/safety-critical.md
.claude/rules/factories.md
.claude/plugins/elixir-lsp/.claude-plugin/plugin.json
.claude/plugins/elixir-lsp/.lsp.json
.mcp.json
```

### Modified Files (4)
```
.claude/settings.json
~/.indrajaal_aliases
~/.zshrc
devenv.nix
```

---

## Next Steps

1. **Test all slash commands** in real workflows
2. **Validate MCP servers** with actual queries
3. **Monitor hook performance** for latency issues
4. **Add more domain-specific rules** as patterns emerge
5. **Create additional subagents** for specialized tasks
6. **Document team feedback** for iteration

---

## References

- [Claude Code CLI Documentation](https://docs.anthropic.com/claude-code)
- [MCP Servers Repository](https://github.com/modelcontextprotocol/servers)
- [Awesome MCP Servers](https://github.com/punkpeye/awesome-mcp-servers)
- [CLAUDE.md](../../CLAUDE.md) - Project specification
- [SOPv5.11 Guide](../../docs/guides/sopv511_deployment_guide.md)

---

**Generated**: 2025-12-31T21:06:00+01:00
**Framework**: SOPv5.11 + STAMP + TDG + Claude Code CLI

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
