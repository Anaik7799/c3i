# Sentinel MCP Setup Tool & Claude Code Integration Guide

**Date**: 2026-03-20 09:24 CET | **Author**: Claude Opus 4.6
**Sprint**: Post-Sprint-54 | **Type**: Tooling + Documentation
**STAMP**: SC-ZEN-001, SC-ZENOH-FFI-001, SC-PRAJNA-004
**AOR**: AOR-SYNC-007, AOR-FFI-001

---

## 1. Context

The `sentinel-zenoh` MCP server was built in Sprint 53-54 and verified with 15/15 MCP calls and
31/31 F# unit tests (see `RELEASE_NOTE_20260320_SENTINEL_MCP_FIX.md`). However, making it
**reliably available in Claude Code sessions** required a setup and verification tool that:

1. Builds both the Rust FFI library and the F# MCP binary
2. Validates `.mcp.json` configuration
3. Tests the full MCP JSON-RPC handshake and all 5 tools
4. Reports clear pass/fail with actionable fix instructions

An initial bash script (`scripts/setup/setup_sentinel_mcp.sh`) used fragile `grep` patterns
to assert on MCP responses. These broke because MCP wraps tool results in nested JSON:
```json
{"result":{"content":[{"text":"{\"ok\":true,\"key\":\"...\"}","type":"text"}]}}
```
Bash `grep '"ok"'` intermittently failed to match the nested stringified JSON.

## 2. Solution: F# Setup Tool

Rewrote the setup script as a compiled F# program using `System.Text.Json.JsonDocument`
for robust JSON parsing. The F# version properly navigates the nested MCP response structure:

```fsharp
/// Extract tool result text: result.content[0].text
let extractToolText (doc: JsonDocument) : string option =
    doc.RootElement.GetProperty("result").GetProperty("content")
        .EnumerateArray() |> Seq.head
        |> fun el -> el.GetProperty("text").GetString() |> Some

/// Parse inner JSON and extract specific field
let extractToolField (doc: JsonDocument) (field: string) : JsonElement option =
    extractToolText doc
    |> Option.bind (fun text -> JsonDocument.Parse(text).RootElement.TryGetProperty(field))
```

### 2.1 Files Created

| File | Purpose | Lines |
|------|---------|-------|
| `scripts/setup/SentinelMcpSetup/SentinelMcpSetup.fsproj` | Project file (net10.0, standalone) | 10 |
| `scripts/setup/SentinelMcpSetup/Program.fs` | Setup tool — 6 phases, 14 tests | ~470 |

### 2.2 What It Tests (25 assertions)

| Phase | Tests | What |
|-------|-------|------|
| 1. Prerequisites | 4 | dotnet, cargo, podman, jq |
| 2. Build | 2-4 | FFI lib + sentinel binary (or verify exist) |
| 3. .mcp.json | 4 | Entry exists, binary path, ZENOH_USE_NATIVE |
| 4. Zenoh Router | 0-1 | Optional: start container |
| 5. MCP Tests | 14 | Initialize, tools/list, sentinel (3), zenoh (6), error |
| 6. Summary | — | Pass/fail report + next steps |

### 2.3 Test Results

```
Phase 5: MCP Server Tests
  [PASS] server-start: PID 3057039
  [PASS] initialize: protocol=2025-03-26
  [PASS] notification: sent (no response expected)
  [PASS] tools-list: 5 tools [zenoh_session, zenoh_pub, zenoh_sub, zenoh_query, sentinel]
  [PASS] sentinel-health: score=0
  [PASS] sentinel-threats: responded
  [PASS] sentinel-status: responded
  [PASS] zenoh-open: connected to router
  [PASS] zenoh-pub: published 19 bytes
  [PASS] zenoh-sub-subscribe: id=sub_1
  [PASS] zenoh-sub-poll: received 1 messages
  [PASS] zenoh-query-metrics: responded
  [PASS] zenoh-session-stats: responded
  [PASS] zenoh-session-close: session closed
  [PASS] unknown-method: proper JSON-RPC error

Results: 25 passed, 0 failed, 1 skipped
```

## 3. Why F# Over Bash

| Aspect | Bash | F# |
|--------|------|----|
| JSON parsing | `grep '"ok"'` — fragile | `JsonDocument` — type-safe |
| Nested MCP response | Breaks on stringified inner JSON | Properly navigates `content[0].text` → parse inner |
| Process management | Named FIFOs + file descriptors | `Process.Start` with redirected streams |
| Error handling | `set -e` + grep exit codes | Pattern matching on `Option`/`Result` |
| Timeout | `read -t` with bash builtins | `CancellationTokenSource` |
| Maintenance | Fragile string operations | Strongly-typed throughout |

## 4. How to Use

### 4.1 First Time Setup (Full Build + Test)
```bash
dotnet run --project scripts/setup/SentinelMcpSetup/
```
This builds the Rust FFI library, builds the F# MCP binary, validates `.mcp.json`,
starts the MCP server, tests all 5 tools, and reports results.

### 4.2 Quick Verification (Already Built)
```bash
dotnet run --project scripts/setup/SentinelMcpSetup/ -- --test-only
```

### 4.3 Full Live Test (With Zenoh Router)
```bash
dotnet run --project scripts/setup/SentinelMcpSetup/ -- --with-zenoh
```

### 4.4 After Success
Restart Claude Code in the project directory. The 5 Sentinel MCP tools will appear.

## 5. Key Design Decisions

### 5.1 Standalone Project (Not Part of Cepaf)
The setup tool has zero dependency on the Cepaf library. It treats the MCP server as
a black box, testing it purely via JSON-RPC over stdio. This means:
- It can test a freshly built binary without Cepaf changes
- No circular dependency
- Can be built/run independently

### 5.2 Process Communication via Redirected Streams
Rather than named FIFOs (bash approach), the F# tool uses `Process.Start` with
`RedirectStandardInput/Output/Error`. This is the standard .NET pattern and avoids
filesystem-based IPC artifacts.

### 5.3 Async Stderr Capture
Server diagnostic logs are captured via `BeginErrorReadLine()` asynchronously, stored
in a `ref` list, and printed at the end. This ensures stderr doesn't block stdout reads.

## 6. FMEA

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| FFI lib not built | 5 | 3 | 9 | 135 | Phase 2a auto-builds |
| Sentinel binary not built | 5 | 3 | 9 | 135 | Phase 2b auto-builds |
| .mcp.json missing entry | 7 | 2 | 9 | 126 | Phase 3 validates + shows fix |
| MCP server crashes on start | 8 | 2 | 8 | 128 | Stderr captured + displayed |
| Zenoh router not running | 3 | 5 | 8 | 120 | Graceful skip for offline tests |
| Nested JSON parse failure | 6 | 1 | 3 | 18 | JsonDocument (vs bash grep RPN=180) |

## 7. Relation to Existing Documents

| Document | Relation |
|----------|----------|
| `journal/2026-03/20260320-0840-sentinel-zenoh-mcp-server-design-guide.md` | Design/implementation reference (945 lines) |
| `docs/releases/RELEASE_NOTE_20260320_SENTINEL_MCP_FIX.md` | JSON deserialization fix |
| `journal/2026-03/20260319-1120-zenoh-ffi-v2-instrumented-correctness.md` | FFI layer underneath |

## 8. Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2026-03-20 | Claude Opus 4.6 | Initial: setup tool + usage guide |
