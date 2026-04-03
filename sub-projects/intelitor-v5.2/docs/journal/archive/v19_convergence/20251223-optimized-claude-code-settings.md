# Optimized Claude Code Settings for Heavy Development
**Date**: 2025-12-23 | **Version**: 1.2.0 | **Status**: ACTIVE | **Updated**: Added cleanupPeriodDays & fileSuggestion

## Overview
Configuration optimizations for Claude Code when working with large, safety-critical codebases like Indrajaal.

---

## 1. Recommended `.claude/settings.json`

```json
{
  "model": "opus",
  "cleanupPeriodDays": 99999,
  "fileSuggestion": {
    "type": "command",
    "command": "rg --files . --glob '!_build' --glob '!deps' --glob '!.elixir_ls' --glob '!.git' --glob '!node_modules' --glob '!data/tmp' | head -20"
  },
  "permissions": {
    "allow": [
      "*",
      "Bash(mix:*)",
      "Bash(elixir:*)",
      "Bash(podman:*)",
      "Bash(git:*)",
      "Bash(rg:*)",
      "Bash(grep:*)",
      "Bash(MIX_ENV=test mix test:*)",
      "WebFetch(domain:code.claude.com)",
      "WebSearch"
    ],
    "deny": [
      "Read(.git/objects/**)",
      "Read(_build/**)",
      "Read(deps/**)",
      "Read(.elixir_ls/**)",
      "Read(.lexical/**)",
      "Read(data/tmp/**)",
      "Read(node_modules/**)",
      "Edit(mix.lock)"
    ]
  },
  "env": {
    "CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR": "1",
    "USE_BUILTIN_RIPGREP": "0",
    "BASH_MAX_OUTPUT_LENGTH": "100000",
    "BASH_DEFAULT_TIMEOUT_MS": "60000",
    "BASH_MAX_TIMEOUT_MS": "300000",
    "MAX_MCP_OUTPUT_TOKENS": "50000",
    "CLAUDE_CODE_MAX_OUTPUT_TOKENS": "8000",
    "MAX_THINKING_TOKENS": "12000",
    "NO_TIMEOUT": "true",
    "PATIENT_MODE": "enabled",
    "INFINITE_PATIENCE": "true"
  },
  "fileSuggestion": {
    "type": "command",
    "command": "rg --files . --glob '!_build' --glob '!deps' --glob '!.elixir_ls' --glob '!.git' --glob '!node_modules' --glob '!data/tmp' | head -20"
  },
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "elixir scripts/planning/claude_todo_sync.exs --sync --to-claude 2>/dev/null || true",
            "timeout": 30,
            "statusMessage": "Loading project tasks..."
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "elixir scripts/planning/claude_todo_sync.exs --sync --from-claude 2>/dev/null || true",
            "timeout": 30,
            "statusMessage": "Syncing session tasks to project..."
          }
        ]
      }
    ]
  }
}
```

---

## 2. Settings Reference

### 2.1 Model Selection

| Model | Use Case | Context |
|-------|----------|---------|
| `opus` | Complex architecture, formal verification, refactoring | Full reasoning |
| `sonnet` | Daily development, bug fixes, test writing | Fast iteration |
| `opusplan` | **Recommended** - Opus in plan mode, Sonnet in execution | Best balance |
| `sonnet[1m]` | Large codebases requiring 1M token context | Extended context |
| `haiku` | Background/utility tasks, simple queries | Minimal cost |

### 2.2 Environment Variables with Limits

| Variable | Recommended | **MAX VALUE** | Default | Purpose |
|----------|-------------|---------------|---------|---------|
| `BASH_MAX_OUTPUT_LENGTH` | `100000` | **~500,000-1M** | ~30,000 | Max chars before middle-truncation |
| `BASH_DEFAULT_TIMEOUT_MS` | `60000` | **120,000** | 120,000 | Default timeout for bash commands |
| `BASH_MAX_TIMEOUT_MS` | `300000` | **600,000** | 600,000 | Hard max timeout (10 minutes) |
| `MAX_MCP_OUTPUT_TOKENS` | `50000` | **~100,000+** | 25,000 | MCP tool response limit (warning at 10k) |
| `CLAUDE_CODE_MAX_OUTPUT_TOKENS` | `8000` | **~16,000-32,000** | ~8,000 | Model response token limit |
| `MAX_THINKING_TOKENS` | `12000` | **~128,000** | disabled | Extended thinking budget (Opus) |

| Variable | Value | Purpose |
|----------|-------|---------|
| `CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR` | `"1"` | Return to project root after each bash command |
| `USE_BUILTIN_RIPGREP` | `"0"` | Use system ripgrep (faster for large repos) |
| `NO_TIMEOUT` | `"true"` | Patient mode - never timeout |
| `PATIENT_MODE` | `"enabled"` | Enable patient compilation mode |
| `INFINITE_PATIENCE` | `"true"` | Never interrupt long operations |

### 2.3 Maximum Values Configuration (Heavy Development)

For maximum performance on large codebases, use these aggressive settings:

```json
{
  "env": {
    "BASH_MAX_OUTPUT_LENGTH": "500000",
    "BASH_DEFAULT_TIMEOUT_MS": "120000",
    "BASH_MAX_TIMEOUT_MS": "600000",
    "MAX_MCP_OUTPUT_TOKENS": "100000",
    "CLAUDE_CODE_MAX_OUTPUT_TOKENS": "16000",
    "MAX_THINKING_TOKENS": "32000"
  }
}
```

**Trade-offs to Consider:**
- Higher `BASH_MAX_OUTPUT_LENGTH` = More context tokens consumed per command
- Higher `MAX_THINKING_TOKENS` = Deeper reasoning but slower responses
- Higher `MAX_MCP_OUTPUT_TOKENS` = More MCP data but faster context exhaustion

**Limit Sources:**
- `BASH_MAX_TIMEOUT_MS`: Tool schema explicitly defines `maximum: 600000` (10 minutes)
- `MAX_MCP_OUTPUT_TOKENS`: Default 25,000, warning threshold at 10,000
- `MAX_THINKING_TOKENS`: Opus 4.5 supports ~128k thinking tokens
- Others: Practical limits based on context window constraints

### 2.4 Session & File Settings with Limits

| Setting | Recommended | **MAX VALUE** | Default | Purpose |
|---------|-------------|---------------|---------|---------|
| `cleanupPeriodDays` | **99999** | **unlimited** | 30 | Days to keep sessions (0 = delete all) |
| `fileSuggestion` output | `head -20` | **15 displayed** | - | Hard limit: only 15 files shown |
| `hooks.timeout` | 30-60 | **no limit** | 60 | Per-hook timeout in seconds |

**cleanupPeriodDays Values:**
- `0` - Delete ALL sessions on startup (dangerous)
- `7` - Keep 1 week of history
- `30` - Default, keep 1 month
- `99999` - **Effectively unlimited** (~274 years)

**fileSuggestion Limitation:**
- Command can output any number of files
- Claude Code hard-codes display limit to **15 files maximum**
- Cannot be changed via settings (internal limit)

**hooks.timeout:**
- Default 60 seconds per hook
- Each hook runs in parallel
- Long timeout only blocks that specific hook

### 2.5 Permission Patterns

**Allow Patterns** (auto-approve these commands):
```
Bash(mix:*)           # All mix commands
Bash(elixir:*)        # All elixir commands
Bash(podman:*)        # Container management
Bash(git:*)           # Version control
Bash(rg:*)            # Ripgrep search
```

**Deny Patterns** (prevent context pollution):
```
Read(_build/**)       # Build artifacts
Read(deps/**)         # Dependencies
Read(.elixir_ls/**)   # Language server cache
Read(data/tmp/**)     # Temporary files
Read(node_modules/**) # NPM packages
```

---

## 3. Session Management Commands

| Command | Purpose |
|---------|---------|
| `/compact` | Reduce context size between major tasks |
| `/cost` | Track token usage for optimization |
| `/memory` | View all loaded memory files |
| `/vim` | Enable vim keybindings |
| `/terminal-setup` | Configure Shift+Enter for multiline input |
| `/help` | Show all available commands |

---

## 4. Memory & Context Management

### 4.1 CLAUDE.md Structure (Optimized)

```markdown
# Project Architecture
[Key system components and layers - keep concise]

# Essential Commands
- Compilation: `NO_TIMEOUT=true PATIENT_MODE=enabled mix compile`
- Testing: `MIX_ENV=test mix test --timeout 7200000`

# Code Patterns & Rules
[Framework-specific patterns - Ash, Phoenix, etc.]

# Directory Safety
[Excluded paths to prevent context pollution]
```

### 4.2 Modular Rules (.claude/rules/)

```
.claude/rules/
├── testing.md        (paths: test/**/*.exs)
├── elixir-patterns.md (paths: lib/**/*.ex)
├── performance.md    (paths: lib/indrajaal/flame/**/*)
└── security.md       (paths: lib/indrajaal/security/**/*.ex)
```

### 4.3 Personal Preferences

Create `.claude/CLAUDE.local.md` for personal project-specific preferences (auto-gitignored).

---

## 5. Performance Optimization Tips

### 5.1 Extended Thinking
```bash
claude --model opus  # Automatically uses extended thinking with MAX_THINKING_TOKENS
```

### 5.2 Prompt Caching
- Enabled by default
- Disable only if experiencing issues: `DISABLE_PROMPT_CACHING=1`

### 5.3 Search Optimization for Large Codebases
```bash
# Use specific glob patterns:
"Search in lib/indrajaal/compliance/*.ex for validation patterns"

# Instead of:
"Search the codebase for validation patterns"
```

### 5.4 Context Reduction
- Use `/compact` between major tasks
- Exclude build directories from reads
- Keep CLAUDE.md focused and concise

---

## 6. Indrajaal-Specific Integration

### 6.1 Patient Mode Environment (Already Configured)

```bash
NO_TIMEOUT=true
PATIENT_MODE=enabled
INFINITE_PATIENCE=true
ELIXIR_ERL_OPTIONS="+S 10:10"
```

### 6.2 SOPv5.11 Compliance

These settings align with:
- **SC-VAL-001**: Patient Mode only
- **SC-CMP-028**: No compilation interruption
- **$\Omega_1$**: Patient Mode axiom

### 6.3 Recommended Compilation Command

```bash
NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true \
  ELIXIR_ERL_OPTIONS="+S 10:10" \
  mix compile --warnings-as-errors --jobs 10 2>&1 | tee -a ./data/tmp/1-compile.log
```

---

## 7. Document References

| Resource | URL |
|----------|-----|
| Settings | https://code.claude.com/docs/en/settings.md |
| Model Configuration | https://code.claude.com/docs/en/model-config.md |
| Memory Management | https://code.claude.com/docs/en/memory.md |
| Terminal Config | https://code.claude.com/docs/en/terminal-config.md |
| Troubleshooting | https://code.claude.com/docs/en/troubleshooting.md |

---

## 8. Quick Reference Card

```
┌──────────────────────────────────────────────────────────────────────────┐
│ CLAUDE CODE HEAVY DEVELOPMENT QUICK REFERENCE                            │
├──────────────────────────────────────────────────────────────────────────┤
│ Model:     opus (complex) | opusplan (hybrid) | sonnet (fast)            │
├──────────────────────────────────────────────────────────────────────────┤
│ ENVIRONMENT VARIABLES         │ RECOMMENDED │ MAX VALUE   │ DEFAULT      │
│ BASH_MAX_OUTPUT_LENGTH        │ 500,000     │ ~500K-1M    │ ~30,000      │
│ BASH_DEFAULT_TIMEOUT_MS       │ 120,000     │ 120,000     │ 120,000      │
│ BASH_MAX_TIMEOUT_MS           │ 600,000     │ 600,000     │ 600,000      │
│ MAX_MCP_OUTPUT_TOKENS         │ 100,000     │ ~100K+      │ 25,000       │
│ CLAUDE_CODE_MAX_OUTPUT_TOKENS │ 16,000      │ ~16K-32K    │ ~8,000       │
│ MAX_THINKING_TOKENS           │ 32,000      │ ~128,000    │ disabled     │
├──────────────────────────────────────────────────────────────────────────┤
│ SESSION SETTINGS              │ RECOMMENDED │ MAX VALUE   │ DEFAULT      │
│ cleanupPeriodDays             │ 99999       │ unlimited   │ 30           │
│ fileSuggestion (output)       │ head -20    │ 15 shown    │ -            │
│ hooks.timeout                 │ 30-60       │ unlimited   │ 60           │
├──────────────────────────────────────────────────────────────────────────┤
│ Patient:   NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true   │
├──────────────────────────────────────────────────────────────────────────┤
│ Commands:  /compact | /cost | /memory | /vim                             │
├──────────────────────────────────────────────────────────────────────────┤
│ Exclude:   _build/ deps/ .elixir_ls/ data/tmp/ node_modules/ .git/       │
└──────────────────────────────────────────────────────────────────────────┘
```

---

**Generated**: 2025-12-23T19:XX:XX+01:00
**Framework**: SOPv5.11 + STAMP Safety Constraints
