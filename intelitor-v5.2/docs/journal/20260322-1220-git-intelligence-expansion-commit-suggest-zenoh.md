# 20260322-1220 — GitIntelligence Expansion: Commit, Suggest, Zenoh Integration

## Context
- Branch: main
- Parent: 20260322-1330 (GitIntelligence scope alignment complete)
- Task: Expand GitIntelligence from read-only analysis to full git operations layer with Zenoh mesh broadcasting

## Summary

Expanded the F# GitIntelligence project from 6 read-only commands to 8 full operational commands by adding `commit` (autonomous git commit with ICP v2.0 enforcement) and `suggest` (AI-powered commit message generation via OpenRouter). Added `Notify.fs` module for dual-write Zenoh event broadcasting — every git event is published to the mesh so the entire 14-container system has real-time git awareness.

## Technical Details

### New Files
| File | Lines | Purpose |
|------|-------|---------|
| `Notify.fs` | 148 | Zenoh FFI dual-write publisher — 4 event types, standalone DllImport |

### Modified Files
| File | Changes | Purpose |
|------|---------|---------|
| `Program.fs` | +~200 lines | `commit` and `suggest` commands, `runGit` helper, `Notify.closeSession()` on exit |
| `Cepaf.GitIntelligence.fsproj` | +1 line | `Notify.fs` inserted between `Analysis.fs` and `Program.fs` |

### New Commands
| Command | Purpose | Integration |
|---------|---------|-------------|
| `commit` | Autonomous ICP-compliant git commit | validate → git add → git commit → GHS → Zenoh notify |
| `suggest` | AI commit message from staged diff | OpenRouter free model → ICP v2.0 formatted suggestion |

### Zenoh Topics (4 Event Types)
| Topic | Event | Payload |
|-------|-------|---------|
| `indrajaal/git/commit` | Post-commit | sha, message, type, scopes, ghs, filesChanged |
| `indrajaal/git/health` | Health update | ghs, icpAdoption, scopeCompliance, totalCommits |
| `indrajaal/git/validate` | Validation result | message, valid, issues[] |
| `indrajaal/git/suggest` | AI suggestion | diffLines, suggestion, model |

### Key Design Decisions
1. **Dual-write pattern (SC-ZTEST-008)**: Log fallback FIRST (always succeeds via `eprintfn`), then attempt Zenoh FFI publish. Ensures no event is lost even without Zenoh router.
2. **Standalone DllImport**: `Notify.fs` has its own `ZenohFfi` private module with `zenoh_ffi_open/publish/close` — no dependency on `Cepaf.Zenoh.Core`. This keeps GitIntelligence self-contained.
3. **F# interpolated strings**: All JSON payloads use `$"""..."""` syntax instead of `sprintf` with format strings, avoiding the FS0001 `Printf.StringFormat<>` type incompatibility.
4. **OpenRouter free models**: `suggest` uses `meta-llama/llama-3.1-8b-instruct:free` with graceful fallback on network errors (AOR-OPENROUTER-001, AOR-OPENROUTER-005).
5. **MCP via Zenoh**: System-wide git awareness is achieved through Zenoh pub/sub rather than a separate MCP server — every subscriber (Sentinel, Prajna, Digital Twin) receives events in real-time.

### F# sprintf Lesson Learned
F# `sprintf` requires a **compile-time literal** format string (`PrintfFormat<>` type). Storing a format string in a `let` binding degrades it to a runtime `string`, causing FS0001. Solution: use F# 6+ interpolated strings (`$"..."` / `$"""..."""`) which embed expressions directly. In triple-quoted interpolated strings, JSON braces `{` must be doubled to `{{`.

## STAMP Compliance
- SC-ZTEST-008: Dual-write pattern (log fallback first, then Zenoh)
- SC-ZENOH-001: Zenoh FFI DllImport for mesh publishing
- SC-BUS-001: Async messaging only
- SC-OBS-069: Dual log (stderr + Zenoh)
- SC-FSH-017: All errors in Result type (graceful fallback)
- SC-FUNC-001: System compiles at all times — 0 errors, 0 warnings
- AOR-OPENROUTER-001: Free models used exclusively
- AOR-OPENROUTER-005: Offline fallback for AI suggestions
- AOR-FFI-006: Dual-write preserved in Notify.fs

## KPIs
- Build: 0 errors, 0 warnings
- Tests: 77/77 pass (0 failures, 0 regressions)
- CLI commands: 8/8 verified (analyze, health, validate, classify, generate, commit, suggest, guardrails)
- GHS: 0.7490 (3-month window, stable)
- Scope compliance: 97.2% (unchanged from prior session)
- Zenoh topics: 4 new event types
- Lines added: ~350 (Notify.fs + Program.fs additions)

## Workflow Impact Analysis — Zenoh, OpenRouter, MCP

The three new capabilities (Zenoh mesh broadcasting, OpenRouter AI suggestions, MCP-via-Zenoh) transform all 6 defined git workflows from silent local operations to mesh-aware system events.

### Workflow Transformations

| Workflow | Before | After |
|----------|--------|-------|
| **Standard Dev** | Manual commit msg, hope for compliance | `suggest` → AI generates ICP msg → `commit` validates+broadcasts |
| **Agentic Evolution** | `EVOLUTION RUN N` free-text | `--json` output for machine parsing → `evolve(scope): action` → Zenoh broadcast |
| **Emergency Fix** | Silent commit, manual triage | `commit` → Sentinel notified instantly via Zenoh → correlates fix with active threats |
| **Sprint Orchestration** | Manual progress tracking | Each `commit --task S60-T001` → SprintOrchestrator receives event → auto-tracks |
| **Health Monitoring** | One-time CLI report | `health --json` → Zenoh `indrajaal/git/health` → Prajna/Grafana/PatternHunter |
| **Pre-Commit Guardrail** | No enforcement | `validate` in git hook → Zenoh `indrajaal/git/validate` → pattern detection |

### Zenoh Subscriber Matrix

| Topic | Sentinel | Prajna | SprintOrch | Digital Twin | SMRITI | Grafana |
|-------|----------|--------|------------|--------------|--------|---------|
| `indrajaal/git/commit` | threat assess | dashboard | task track | state refresh | knowledge | - |
| `indrajaal/git/health` | - | SmartMetrics | - | - | - | gauge |
| `indrajaal/git/validate` | pattern detect | - | - | - | audit | - |
| `indrajaal/git/suggest` | - | - | - | - | diff→msg corpus | - |

### Agentic Development Optimization

The `--json` flag on `suggest`, `validate`, `health`, and `analyze` makes all commands machine-parseable. Exit codes (0/1) give agents clear pass/fail signals. The commit pipeline becomes fully autonomous:

```
Agent OODA loop:
  1. Code change
  2. git add <files>
  3. git-intel suggest --json → parse suggestion
  4. git-intel validate <suggestion> → exit 0?
  5. git-intel commit --type <t> --scope <s> --action <a> --all
     → validates → commits → computes GHS → publishes to Zenoh
     → Sentinel/Prajna/SprintOrchestrator all notified
  6. git-intel health --json → GHS trend for OODA feedback
```

### MCP Integration Architecture

System-wide git awareness is achieved through Zenoh, not a separate MCP server:

```
Claude Code → MCP → sentinel-zenoh → Zenoh subscribe indrajaal/git/**
                                    → receives all git events in real-time
```

The existing `sentinel-zenoh` MCP server subscribes to Zenoh topics. Any MCP client gets git awareness transitively. This avoids a second MCP server binary and leverages the existing mesh infrastructure.

### OpenRouter Integration

| Aspect | Implementation |
|--------|---------------|
| Model | `meta-llama/llama-3.1-8b-instruct:free` (AOR-OPENROUTER-001) |
| Timeout | 15 seconds (graceful) |
| Fallback | Rule-based: `chore(core): update N files` (AOR-OPENROUTER-005) |
| Rate limit | Exponential backoff on 429 (AOR-OPENROUTER-002) |
| Audit | All calls logged to Zenoh via `publishSuggestEvent` (AOR-OPENROUTER-004) |
| Learning | SMRITI subscribes to `indrajaal/git/suggest` → accumulates diff→msg corpus |

### Dual-Write Reliability Guarantee (SC-ZTEST-008)

Every event follows the pattern in `Notify.fs`:
1. `eprintfn "[GIT-EVENT] ..."` — stderr log fallback (ALWAYS succeeds)
2. `zenohPublish topic payload` — Zenoh FFI (may fail gracefully)

This ensures: Loki always captures events, Zenoh subscribers get real-time when available, no event is ever lost.

## Next Steps
- User wants to update existing repository commit history to ICP v2.0 format (rewrite/retag)
- Consider pre-commit hook integration using `git-intel validate`
- Monitor GHS improvement as new ICP-compliant commits accumulate
- SMRITI knowledge agent could train local model from accumulated diff→msg pairs, reducing OpenRouter dependency
