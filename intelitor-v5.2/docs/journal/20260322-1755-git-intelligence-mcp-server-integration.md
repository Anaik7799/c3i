# 20260322-1755 — Git Intelligence MCP Server Integration Complete

## Context
- Branch: main
- Recent commits: 95f7fbea5 EVOLUTION RUN 2: Biomorphic Synchronization Complete
- Phase: Plan Phase 4 (Integration — L2 MCP Tools + L7 Federation)

## Summary
Created and verified the MCP stdio JSON-RPC 2.0 transport for Git Intelligence, enabling agentic tool access to ICP v2.0 commit analysis, GHS health scoring, and evolution history. The server is now registered in `.mcp.json` alongside sentinel-zenoh.

## Technical Details

### New File: `McpServer.fs` (~254 lines)
- **Module**: `Cepaf.GitIntelligence.McpServer`
- **Protocol**: JSON-RPC 2.0 over stdin/stdout (stderr for diagnostics)
- **Transport**: Synchronous readline loop, Utf8JsonWriter for response construction
- **Adapter**: `jsonElementToMap` converts MCP `JsonElement option` to `Map<string, obj>` for `McpTools.dispatch`
- **Methods**: initialize, notifications/initialized, tools/list, tools/call, ping
- **Lifecycle**: `Store.initDb()` + `History.initDb()` on startup, `Notify.closeSession()` on shutdown

### Modified Files
| File | Change |
|------|--------|
| `Cepaf.GitIntelligence.fsproj` | Added `McpServer.fs` between `Multiverse.fs` and `Program.fs` |
| `Program.fs` | Added `mcp-serve` and `mcp-list` to help text and command dispatch |
| `.mcp.json` | Registered `git-intelligence` MCP server with DOTNET_ROOT and LD_LIBRARY_PATH |

### 5 MCP Tools Exposed
| Tool | Description |
|------|-------------|
| `git_intel_analyze` | Commit history analysis: style distribution, scope compliance, GHS, entropy |
| `git_intel_validate` | Validate commit message against ICP v2.0 convention |
| `git_intel_health` | Current Git Health Score and adoption metrics |
| `git_intel_suggest` | Generate ICP-compliant commit message for staged changes |
| `git_intel_history` | Query evolution event history from DuckDB log |

### Verification Results
- **Build**: 0 warnings, 0 errors
- **MCP Protocol**: 5/5 requests pass (initialize, tools/list, tools/call, ping, notification)
- **Unit Tests**: 159/159 GitIntelligence tests pass (Store 14, Safety, Biomorphic, Analysis, Parser)
- **Store Tests**: 14/14 pass (SQLite WAL, DuckDB append-only)

### Root Cause of Initial SIGSEGV (exit 131)
Not a DuckDB crash — the .NET apphost couldn't find the runtime without `DOTNET_ROOT`. The `.mcp.json` entry handles this with inline export. Fixed by ensuring test commands set `DOTNET_ROOT`.

## STAMP Compliance
- SC-MCP (tool dispatch): McpTools.dispatch chain with 5 tools
- SC-FSH-017 (Result type errors): All error paths return JSON-RPC error responses
- SC-ZTEST-008 (dual-write): Notify.fs log fallback + Zenoh publish preserved
- AOR-HOLON-001 (SQLite state): Store.initDb creates WAL-mode SQLite
- AOR-HOLON-002 (DuckDB history): History.initDb creates append-only DuckDB

## Fractal Coverage Impact
| Layer | Before | After | Delta |
|-------|--------|-------|-------|
| L2 Component | 5/8 | 7/8 | +2 (McpTools + McpServer) |
| **Total** | 46/80 (57.5%) | 48/80 (60.0%) | +2 |

## Next Steps
- Create Elixir-side Zenoh subscriber for 14 `indrajaal/git/*` topics
- Wire git intelligence events into Prajna/Sentinel consumption
- End-to-end mesh integration verification
- DuckDB version upgrade (1.2.0 → 1.4.3)

## KPIs
- Files changed: 4 (1 new, 3 modified)
- Lines added/removed: +254/-0 (McpServer.fs), +4/-1 (Program.fs), +2/-0 (.fsproj), +8/-0 (.mcp.json)
- Tests: 159 pass, 0 fail
- Warnings: 0
- MCP protocol compliance: 5/5 methods
