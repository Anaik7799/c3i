# Sentinel MCP Server — Usage Guide

**Version**: 1.0.0 | **Date**: 2026-03-20 | **Status**: VERIFIED
**STAMP**: SC-ZEN-001, SC-PRAJNA-004, SC-ZENOH-FFI-001

---

## 1. What Is It

The Sentinel MCP Server (`sentinel-zenoh`) gives Claude Code direct access to:

- **Zenoh pub/sub** — publish messages, subscribe to topics, poll for data
- **Sentinel health monitoring** — system health score, active threats, bridge status
- **Zenoh FFI diagnostics** — 27 atomic counters, 12 formal invariants, latency histograms

It runs as a stdio JSON-RPC 2.0 process that Claude Code launches automatically.

### 1.1 The 5 Tools

| Tool | Actions | What It Does |
|------|---------|--------------|
| `zenoh_session` | `open`, `close`, `stats` | Connect/disconnect to Zenoh router, view session stats |
| `zenoh_pub` | *(direct)* | Publish a UTF-8 message to a Zenoh key expression |
| `zenoh_sub` | `subscribe`, `poll`, `unsubscribe` | Subscribe to topics, retrieve messages, clean up |
| `zenoh_query` | `get`, `metrics`, `verify` | Query Zenoh keys, view FFI metrics, verify invariants |
| `sentinel` | `health`, `threats`, `status` | System health score, threat list, bridge status |

---

## 2. Quick Start (5 Minutes)

### Step 1: Run the Setup Tool

```bash
# From project root
dotnet run --project scripts/setup/SentinelMcpSetup/
```

This will:
1. Build `libzenoh_ffi.so` (Rust FFI library)
2. Build `cepaf-sentinel-mcp` (F# MCP binary)
3. Validate `.mcp.json` has the correct `sentinel-zenoh` entry
4. Start the MCP server and run 14 integration tests
5. Report pass/fail

### Step 2: Restart Claude Code

After all tests pass, **restart Claude Code** in the project directory.
MCP servers connect at session startup — the tools won't appear until restart.

### Step 3: Use the Tools

Ask Claude to use the Sentinel tools. Examples:

> "Open a Zenoh session and check system health"

> "Subscribe to indrajaal/sentinel/** and poll for threat data"

> "Run zenoh_query verify to check FFI invariants"

---

## 3. Setup Tool Options

```bash
# Full build + test (first time)
dotnet run --project scripts/setup/SentinelMcpSetup/

# Test only — skip builds (already built)
dotnet run --project scripts/setup/SentinelMcpSetup/ -- --test-only

# With dedicated Zenoh router container
dotnet run --project scripts/setup/SentinelMcpSetup/ -- --with-zenoh

# Stop the test Zenoh router
dotnet run --project scripts/setup/SentinelMcpSetup/ -- --teardown

# Help
dotnet run --project scripts/setup/SentinelMcpSetup/ -- --help
```

---

## 4. Prerequisites

| Requirement | Check | Purpose |
|-------------|-------|---------|
| .NET 10.0 SDK | `dotnet --version` >= 10.0 | Build and run F# binary |
| Rust toolchain | `cargo --version` | Build libzenoh_ffi.so |
| Podman 5.4+ | `podman --version` | Only for `--with-zenoh` |
| Zenoh router | Running on port 7447 | For live pub/sub (optional for health-only) |

### Do I Need a Zenoh Router?

- **Without router**: `sentinel` tool works (returns zeroed/cached metrics). Zenoh tools return helpful errors.
- **With router**: Full pub/sub, subscriptions, queries, and live health data work.
- **Start one**: Use `sa-up` (starts full mesh) or `--with-zenoh` flag.

---

## 5. Tool Reference

### 5.1 zenoh_session

**Open a session** (must be called before pub/sub/query):
```
Tool: zenoh_session
Arguments: { "action": "open" }
           { "action": "open", "endpoints": "tcp/custom-host:7447", "mode": "peer" }
```
Returns: `{ "status": "connected", "endpoints": [...], "mode": "client" }`

**View session stats**:
```
Tool: zenoh_session
Arguments: { "action": "stats" }
```
Returns: `{ "connected": true, "messages_sent": 47, ... }`

**Close session**:
```
Tool: zenoh_session
Arguments: { "action": "close" }
```

### 5.2 zenoh_pub

**Publish a message**:
```
Tool: zenoh_pub
Arguments: { "key": "indrajaal/test/hello", "payload": "world" }
```
Returns: `{ "ok": true, "key": "indrajaal/test/hello", "len": 5 }`

### 5.3 zenoh_sub

**Subscribe to a topic pattern**:
```
Tool: zenoh_sub
Arguments: { "action": "subscribe", "key": "indrajaal/**" }
```
Returns: `{ "id": "sub_1", "key": "indrajaal/**" }`

**Poll for messages**:
```
Tool: zenoh_sub
Arguments: { "action": "poll", "id": "sub_1" }
           { "action": "poll", "id": "sub_1", "limit": 5 }
```
Returns: `{ "id": "sub_1", "n": 2, "msgs": [{ "k": "key", "v": "value" }, ...] }`

**Unsubscribe**:
```
Tool: zenoh_sub
Arguments: { "action": "unsubscribe", "id": "sub_1" }
```

### 5.4 zenoh_query

**Get value at a key**:
```
Tool: zenoh_query
Arguments: { "action": "get", "key": "indrajaal/health/node-1" }
           { "action": "get", "key": "indrajaal/health/node-1", "timeout_ms": 3000 }
```

**View FFI metrics** (27 atomic counters + latency histogram):
```
Tool: zenoh_query
Arguments: { "action": "metrics" }
```
Returns: `{ "atomic_counters": { "session_open": 2, "publish": 47, ... }, "latency_histogram": [...] }`

**Verify 12 formal invariants**:
```
Tool: zenoh_query
Arguments: { "action": "verify" }
```
Returns: Per-invariant pass/fail with details (INV-1 through INV-12).

### 5.5 sentinel

**System health score**:
```
Tool: sentinel
Arguments: { "action": "health" }
```
Returns: `{ "score": 0.85, "status": "healthy", "cpu": 0.42, "mem": 0.65, "err_rate": 0.001, "threats": 0 }`

**Active threats**:
```
Tool: sentinel
Arguments: { "action": "threats" }
```
Returns: `{ "n": 2, "threats": [{ "id": "T-001", "severity": "high", ... }] }`

**Bridge status**:
```
Tool: sentinel
Arguments: { "action": "status" }
```
Returns: `{ "health_sub": true, "threat_sub": true, "session": true, "polls": 42 }`

---

## 6. Common Workflows

### 6.1 Health Check

```
1. zenoh_session open
2. sentinel health           → score, CPU, memory, error rate
3. sentinel threats          → active threat list
4. zenoh_query verify        → 12 FFI invariants
5. zenoh_session close
```

### 6.2 Real-Time Monitoring

```
1. zenoh_session open
2. zenoh_sub subscribe  key="indrajaal/sentinel/**"
3. (wait for events)
4. zenoh_sub poll  id="sub_1"    → retrieve health updates
5. zenoh_sub poll  id="sub_1"    → poll again for new data
6. zenoh_sub unsubscribe id="sub_1"
7. zenoh_session close
```

### 6.3 Publish System Event

```
1. zenoh_session open
2. zenoh_pub key="indrajaal/test/event" payload='{"type":"test","ts":"2026-03-20T12:00:00Z"}'
3. zenoh_session close
```

### 6.4 Diagnostics & Debugging

```
1. zenoh_query metrics       → 27 FFI counters (works without session)
2. zenoh_query verify        → 12 formal invariants (works without session)
3. sentinel status           → bridge subscription state
```

---

## 7. Troubleshooting

### Tools Not Appearing in Claude Code

**Cause**: MCP server failed to start when the session began.

**Fix**:
```bash
# 1. Verify the setup passes
dotnet run --project scripts/setup/SentinelMcpSetup/ -- --test-only

# 2. Restart Claude Code (MCP servers connect at startup)
```

### "No session" Error on Pub/Sub

**Cause**: `zenoh_session open` was not called first.

**Fix**: Always call `zenoh_session open` before `zenoh_pub`, `zenoh_sub`, or `zenoh_query get`.

### Session Open Timeout

**Cause**: No Zenoh router reachable on port 7447.

**Fix**:
```bash
# Option A: Start the full mesh
sa-up

# Option B: Start a standalone test router
dotnet run --project scripts/setup/SentinelMcpSetup/ -- --with-zenoh
```

### FFI Not Available

**Cause**: `libzenoh_ffi.so` not found in `LD_LIBRARY_PATH`.

**Fix**:
```bash
# Rebuild the Rust library
cargo build --release -p zenoh_ffi

# Verify it exists
ls -la target/release/libzenoh_ffi.so
```

### Server Crashes on Startup

**Cause**: Binary not built or DOTNET_ROOT not set.

**Fix**:
```bash
# Full rebuild
dotnet run --project scripts/setup/SentinelMcpSetup/
```

### .NET 10 stdout/stderr Swap Bug

**Known issue**: `dotnet run` and `dotnet exec` swap stdout/stderr on .NET 10 (NixOS).
The `.mcp.json` entry uses `bash -c exec` with the native binary to work around this.
Never change the `.mcp.json` command to use `dotnet run`.

See: `journal/2026-03/20260320-0840-sentinel-zenoh-mcp-server-design-guide.md` Section 10.

---

## 8. Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│  Claude Code                                                      │
│  ├── Reads .mcp.json on startup                                  │
│  ├── Launches cepaf-sentinel-mcp as subprocess                   │
│  ├── Sends JSON-RPC 2.0 requests on stdin                        │
│  └── Reads JSON-RPC 2.0 responses from stdout                   │
└──────────┬───────────────────────────────────────────────────────┘
           │ stdio (stdin/stdout)
┌──────────▼───────────────────────────────────────────────────────┐
│  cepaf-sentinel-mcp (F# .NET 10.0)                               │
│  ├── McpProtocol.fs  — JSON-RPC dispatch                         │
│  ├── ZenohTools.fs   — 4 tools → ZenohFfiBridge                 │
│  └── SentinelTools.fs — 1 tool → Zenoh health topics             │
└──────────┬───────────────────────────────────────────────────────┘
           │ P/Invoke (DllImport)
┌──────────▼───────────────────────────────────────────────────────┐
│  libzenoh_ffi.so (Rust cdylib)                                    │
│  ├── 13 C ABI functions                                           │
│  ├── Tokio async runtime                                          │
│  ├── 27 atomic counters (SeqCst)                                  │
│  └── 12 formal invariants                                         │
└──────────┬───────────────────────────────────────────────────────┘
           │ TCP
┌──────────▼───────────────────────────────────────────────────────┐
│  Zenoh Router (port 7447)                                         │
│  ├── Real-time pub/sub mesh                                       │
│  └── indrajaal/** topic namespace                                 │
└──────────────────────────────────────────────────────────────────┘
```

---

## 9. File Inventory

| File | Purpose |
|------|---------|
| `.mcp.json` | MCP server registration (sentinel-zenoh entry) |
| `lib/cepaf/src/Cepaf.Sentinel.MCP/Program.fs` | Entry point, stdio JSON-RPC loop |
| `lib/cepaf/src/Cepaf.Sentinel.MCP/Protocol/McpProtocol.fs` | JSON-RPC 2.0 protocol |
| `lib/cepaf/src/Cepaf.Sentinel.MCP/Tools/ZenohTools.fs` | 4 Zenoh tools |
| `lib/cepaf/src/Cepaf.Sentinel.MCP/Tools/SentinelTools.fs` | Sentinel health tool |
| `lib/cepaf/src/Cepaf/Zenoh/Core/ZenohFfiBridge.fs` | F# P/Invoke bridge (13 DllImport) |
| `native/zenoh_ffi/src/lib.rs` | Rust FFI (13 C ABI functions) |
| `target/release/libzenoh_ffi.so` | Compiled Rust library (6.1 MB) |
| `scripts/setup/SentinelMcpSetup/Program.fs` | Setup & test tool |

---

## 10. Graceful Degradation

The server is designed to work at any level of infrastructure availability:

| Infrastructure | sentinel tool | zenoh tools | Notes |
|----------------|--------------|-------------|-------|
| No FFI lib | Zeroed data | "FFI not available" error | Server still starts |
| FFI but no router | Zeroed data | "Open failed" on session open | Metrics/verify still work |
| FFI + router, no session | Zeroed data | "No session" guidance | Call `open` first |
| Full stack | Live health data | Full pub/sub/query | Production mode |

---

## 11. Related Documents

| Document | Location |
|----------|----------|
| Design Guide (945 lines) | `journal/2026-03/20260320-0840-sentinel-zenoh-mcp-server-design-guide.md` |
| FFI Fix Release Note | `docs/releases/RELEASE_NOTE_20260320_SENTINEL_MCP_FIX.md` |
| Zenoh FFI v2 Architecture | `journal/2026-03/20260319-1120-zenoh-ffi-v2-instrumented-correctness.md` |
| Setup Tool Journal | `journal/2026-03/20260320-0924-sentinel-mcp-setup-tool-and-usage-guide.md` |

---

## 12. Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2026-03-20 | Claude Opus 4.6 | Initial usage guide |
