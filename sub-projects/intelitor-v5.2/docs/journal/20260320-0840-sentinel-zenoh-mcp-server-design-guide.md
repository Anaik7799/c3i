# Cepaf.Sentinel.MCP — Design, Implementation & Test Guide

**Version**: 2.0.0 | **Date**: 2026-03-20 08:40 CET | **Author**: Claude Opus 4.6
**Module**: `lib/cepaf/src/Cepaf.Sentinel.MCP/`
**STAMP**: SC-ZEN-001, SC-PRAJNA-004, SC-ZENOH-FFI-001..050, SC-ZTEST-003/004/016
**AOR**: AOR-FFI-001, AOR-SYNC-007, AOR-ZTEST-004

---

## 1. Problem Statement

Claude Code (and any MCP-compliant host) needs to:
1. **Publish and subscribe** to Zenoh real-time messages for system coordination
2. **Monitor Sentinel health** (CPU, memory, error rates, active threats)
3. Do both via a **standardized protocol** without custom glue scripts

The existing infrastructure provides:
- A Rust `cdylib` (`native/zenoh_ffi/`) exposing 13 C ABI functions for Zenoh 1.7
- An F# P/Invoke bridge (`ZenohFfiBridge.fs`) wrapping those 13 functions safely
- A Sentinel health system publishing to Zenoh topics `indrajaal/sentinel/**` and `prajna/alerts/**`

What was missing: a protocol-compliant server that exposes these as callable tools.

---

## 2. Design Decisions & Tradeoffs

### 2.1 Protocol Choice: MCP over stdio (JSON-RPC 2.0)

**Decision**: Implement an MCP server using stdio transport.

**Alternatives considered**:

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **MCP stdio** | Zero-latency local IPC; Claude Code native support; standardized discovery; no port conflicts | Process-per-session; first-call JIT latency | **CHOSEN** |
| gRPC server | Efficient binary protocol; streaming; schema-first | Not MCP-native; requires client wrapper; port management | Rejected |
| HTTP REST API | Simple; universally consumable | Polling-based; no native MCP integration; token-heavy | Rejected |
| Zenoh topic bridge | Zero additional process; direct mesh access | No standard tool discovery; Claude Code can't natively subscribe to Zenoh | Rejected |
| Elixir Port protocol | Existing Elixir↔F# pattern in codebase | Custom protocol; deprecated by SC-ZEN-002 | Rejected (SC-ZEN-002 forbids) |

**Key factors**:
- **SC-ZEN-001** mandates Zenoh as the unified IPC backplane
- **SC-ZEN-002** deprecates JSON-RPC and custom Elixir Port protocols
- MCP stdio is the native integration path for Claude Code (documented at `https://modelcontextprotocol.io/docs/concepts/transports`)
- Zero network configuration: the host launches the process, wires stdin/stdout

**Tradeoff**: First invocation has ~6s JIT latency (dotnet run compiles on first call). Subsequent calls are instant. Could be mitigated with AOT compilation (`dotnet publish -c Release`) but adds build complexity.

**Reference**: MCP specification 2025-06-18, stdio transport section — "Client launches server as subprocess. Server reads JSON-RPC from stdin, writes to stdout. Messages delimited by newlines."

### 2.2 Tool Consolidation: 14 → 5 Tools

**Decision**: Consolidate 14 granular tools into 5 using action-enum patterns.

**Before** (14 tools):
```
zenoh_publish, zenoh_subscribe, zenoh_poll, zenoh_unsubscribe,
zenoh_get, zenoh_metrics, zenoh_verify, zenoh_session_open,
zenoh_session_close, zenoh_session_stats,
sentinel_health, sentinel_threats, sentinel_sync, sentinel_status
```

**After** (5 tools):
```
zenoh_session  (action: open|close|stats)
zenoh_pub      (single-purpose, no enum)
zenoh_sub      (action: subscribe|poll|unsubscribe)
zenoh_query    (action: get|metrics|verify)
sentinel       (action: health|threats|status)
```

**Why**:
- Each tool definition is sent in the `tools/list` response and **consumed by the LLM context window**. 14 tools × ~200 tokens/tool = ~2,800 tokens of schema. 5 tools = ~1,000 tokens. That's **1,800 tokens saved per session**.
- Enum constraints (`"enum": ["open","close","stats"]`) guide the LLM to valid values without free-text guessing.
- The MCP spec supports pagination for `tools/list` but the real cost is LLM context, not transport.

**Why not consolidate further** (e.g., single `zenoh` tool with action=publish|subscribe|...)?
- `zenoh_pub` has fundamentally different required params (`key` + `payload`) vs `zenoh_sub` (`action` + optional `key`/`id`/`limit`). A single tool would have confusing "sometimes required" params.
- The LLM performs better when each tool has a clear contract: "this tool publishes", "this tool manages subscriptions".

**Tradeoff**: `zenoh_sub` with action=poll requires the LLM to remember the subscription ID from a prior call. This is a stateful interaction pattern. Alternative would be auto-subscribing inline (subscribe+poll+unsubscribe in one call), but that prevents long-lived subscriptions which are the whole point of pub/sub.

**Reference**: User's MCP best practices guidance — "A few well-designed tools outperform dozens of granular ones. Each tool schema consumes context. Constrain with enums."

### 2.3 Token Economy: Minimal Response JSON

**Decision**: Use abbreviated JSON keys in responses (`k` for key_expr, `v` for value, `n` for count).

**Before**:
```json
{"subscription_id":"sub_1","message_count":3,"messages":[{"key_expr":"indrajaal/test","payload":"hello","timestamp":"","encoding":""}]}
```
(~130 chars per message)

**After**:
```json
{"id":"sub_1","n":3,"msgs":[{"k":"indrajaal/test","v":"hello"}]}
```
(~60 chars per message)

**Why**: Every byte of tool output is consumed by the LLM context window. For a poll returning 50 messages, the savings compound: ~3,500 chars saved. This matters at 80% context utilization (SC-BIO-004).

**What we strip**: Timestamps (usually empty from poll), encoding (always UTF-8 in our system), duplicate wrapper objects.

**Tradeoff**: Abbreviated keys are less self-documenting. But the tool description already explains the response format, and the LLM sees the schema. Clarity in the schema, brevity in the data.

**Reference**: User's MCP best practices — "Strip non-essential data. Think of responses as context-window fuel — every token counts."

### 2.4 Self-Contained Sentinel (No Cepaf.Cockpit Dependency)

**Decision**: SentinelTools reads health data directly from Zenoh topics instead of embedding the full SentinelBridge agent.

**Problem**: The existing `SentinelBridge` lives in `Cepaf.Cockpit` which depends on:
- `Avalonia 11.0.0` (heavy UI framework, ~40MB)
- `ReactiveUI` (reactive patterns)
- `Spectre.Console` (TUI rendering)
- `FSharp.Control.Reactive`

Including these would bloat the MCP server binary by ~40MB and introduce GUI initialization code that's irrelevant to a headless stdio process.

**Alternative approaches**:

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **Direct Zenoh polling** | Zero deps beyond Cepaf; self-contained; ~170 lines | Doesn't get full SentinelBridge agent features (30s auto-sync) | **CHOSEN** |
| Reference Cepaf.Cockpit | Full SentinelBridge agent embedded | +40MB deps; Avalonia init; 66 build errors on first attempt | Rejected |
| Extract SentinelBridge to shared lib | Clean dependency; reusable | Requires refactoring Cepaf.Cockpit; new project; not in scope | Future work |
| HTTP bridge to Elixir | Leverage existing Elixir Sentinel | Extra HTTP hop; network dependency; contradicts SC-ZEN-001 | Rejected |

**How it works**: On first `sentinel` tool call, SentinelTools lazily subscribes to `indrajaal/sentinel/**` and `prajna/alerts/**`. Each subsequent call polls for the latest message and caches the result. This is "pull-on-demand" rather than the SentinelBridge's "push every 30s" pattern.

**Tradeoff**: The MCP Sentinel view is slightly stale (only updates when Claude calls the tool). For a human-interactive AI assistant, this is fine — Claude calls `sentinel` when it needs data, gets the latest. For a dashboard that needs continuous updates, the full SentinelBridge would be better.

**Reference**: SC-PRAJNA-004 (Sentinel integration), AOR-SYNC-007 (health sync). The sync interval is driven by tool calls rather than a timer.

### 2.5 F# Over Other Languages

**Decision**: Implement in F# (net10.0) rather than Elixir, Rust, TypeScript, or Python.

**Why F#**:
1. The Zenoh FFI bridge (`ZenohFfiBridge.fs`) is already F# — zero bridging cost
2. SC-NET-001 mandates net10.0 for all F# projects
3. F#'s discriminated unions and pattern matching are ideal for JSON-RPC dispatch
4. The `Cepaf` project reference provides all Zenoh types without duplication
5. SC-CEP-005 mandates pre-compiled F# (no `.fsx` scripts in production)

**Why not Elixir**: Would require a new Zenoh NIF or Port to bridge to the Rust library. The F# path already exists and is tested (31 FFI tests passing).

**Why not TypeScript/Python**: The MCP ecosystem has official TypeScript and Python SDKs (`@modelcontextprotocol/sdk`, `mcp` package). But these would require either: (a) a separate Zenoh client library, or (b) an HTTP wrapper around the F# FFI. Both add latency and complexity vs. direct P/Invoke.

**Tradeoff**: F# MCP servers don't have an official SDK (unlike TypeScript/Python). We implement the protocol from scratch (~230 lines in McpProtocol.fs). This is more work but gives us complete control and zero external dependencies.

**Reference**: MCP spec server implementation guide at `https://modelcontextprotocol.io/docs/develop/build-server`. The spec is language-agnostic — any language that can read stdin and write stdout works.

### 2.6 Protocol Version: 2025-03-26

**Decision**: Advertise protocol version `2025-03-26` in the initialize response.

**Why not 2025-06-18** (latest): The 2025-06-18 spec adds `structuredContent`, `outputSchema`, `title` field, and `tasks` (experimental). None of these features are required for our tool-only server. Using 2025-03-26 ensures compatibility with older Claude Code versions while keeping the implementation simple.

**Tradeoff**: We don't get structured content validation. But our tools return JSON-as-text in the `content[].text` field, which works universally.

**Future**: Can upgrade to 2025-06-18 to add `outputSchema` for type-safe tool results when the ecosystem matures.

### 2.7 Mutable State (SessionState / SentinelState)

**Decision**: Use mutable record fields for session handles and subscription maps.

```fsharp
type SessionState = {
    mutable SessionHandle: nativeint
    mutable Subscriptions: Map<string, nativeint>
    mutable NextSubId: int
}
```

**Why not immutable state + MailboxProcessor**: The MCP server is single-threaded (stdio read loop). There's no concurrent access. An immutable state pattern would require threading state through every handler function, adding complexity without benefit.

**Tradeoff**: Mutable state is a code smell in functional programming. But in a single-threaded stdio server, it's the pragmatic choice. The state lives for the duration of one Claude Code session and is cleaned up in the `finally` block.

---

## 3. Architecture

### 3.1 Component Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│ Claude Code (MCP Host)                                               │
│                                                                      │
│  ┌─────────────┐    stdio     ┌──────────────────────────────────┐  │
│  │  MCP Client  │◄──────────►│  Cepaf.Sentinel.MCP (F# Process) │  │
│  │  (built-in)  │  JSON-RPC   │                                  │  │
│  └─────────────┘    2.0       │  ┌──────────────────────────┐   │  │
│                               │  │ Program.fs (stdio loop)   │   │  │
│                               │  │                           │   │  │
│                               │  │  ┌────────────────────┐  │   │  │
│                               │  │  │ McpProtocol.fs      │  │   │  │
│                               │  │  │ (parse/serialize)   │  │   │  │
│                               │  │  └────────────────────┘  │   │  │
│                               │  │                           │   │  │
│                               │  │  ┌──────────┬─────────┐  │   │  │
│                               │  │  │ZenohTools│Sentinel │  │   │  │
│                               │  │  │  .fs     │Tools.fs │  │   │  │
│                               │  │  └────┬─────┴────┬────┘  │   │  │
│                               │  └───────┼──────────┼────────┘   │  │
│                               └──────────┼──────────┼────────────┘  │
└──────────────────────────────────────────┼──────────┼───────────────┘
                                           │          │
                              ┌────────────┴──────────┴────────────┐
                              │     ZenohFfiBridge.fs (P/Invoke)   │
                              │     13 DllImport declarations      │
                              └────────────────┬───────────────────┘
                                               │ C ABI
                              ┌────────────────┴───────────────────┐
                              │     libzenoh_ffi.so (Rust cdylib)  │
                              │     zenoh 1.7, tokio, csbindgen    │
                              └────────────────┬───────────────────┘
                                               │ Zenoh wire protocol
                              ┌────────────────┴───────────────────┐
                              │     Zenoh Router (tcp/:7447)       │
                              │                                    │
                              │  Topics:                           │
                              │    indrajaal/sentinel/**           │
                              │    prajna/alerts/**                │
                              │    indrajaal/test/**               │
                              │    indrajaal/mesh/**               │
                              └────────────────────────────────────┘
```

### 3.2 Message Flow

```
Claude Code                    MCP Server                     Zenoh
    │                              │                              │
    │──initialize──────────────────►│                              │
    │◄──capabilities (5 tools)─────│                              │
    │──notifications/initialized──►│                              │
    │                              │                              │
    │──tools/list──────────────────►│                              │
    │◄──[zenoh_session, zenoh_pub,─│                              │
    │    zenoh_sub, zenoh_query,   │                              │
    │    sentinel]                 │                              │
    │                              │                              │
    │──tools/call: zenoh_session───►│                              │
    │  {action:"open"}             │──openSession(config)────────►│
    │                              │◄──handle (nativeint)─────────│
    │◄──{status:"connected"}───────│                              │
    │                              │                              │
    │──tools/call: zenoh_pub───────►│                              │
    │  {key:"x", payload:"y"}      │──publishString(h,k,v)──────►│
    │◄──{ok:true, len:1}──────────│                              │
    │                              │                              │
    │──tools/call: sentinel────────►│                              │
    │  {action:"health"}           │──subscribe("sentinel/**")──►│
    │                              │──poll(subHandle, 50)────────►│
    │                              │◄──[latest health JSON]───────│
    │◄──{score:0.92, cpu:45.2,    │                              │
    │    mem:62.1, ...}            │                              │
    │                              │                              │
    │──[EOF / close stdin]─────────►│                              │
    │                              │──closeSession(handle)───────►│
    │                              │──unsubscribe(subs)──────────►│
    │                              │◄──cleanup complete───────────│
```

### 3.3 Error Handling Strategy

Two distinct error channels per MCP spec:

```
Protocol Errors (JSON-RPC error object):
  -32700  Parse error       → malformed JSON line
  -32601  Method not found  → unknown JSON-RPC method or tool name
  -32602  Invalid params    → missing required argument

Tool Execution Errors (isError: true in result):
  "No session. Call zenoh_session with action=open first."
  "Publish failed: ConnectionFailed(...)"
  "libzenoh_ffi.so not available. Check LD_LIBRARY_PATH."
```

**Design rule**: Protocol errors for protocol violations; tool errors for domain failures. This follows the MCP spec: "Use `isError: true` for business logic errors; let protocol errors bubble up as JSON-RPC errors."

---

## 4. File-by-File Implementation Guide

### 4.1 McpProtocol.fs (230 lines)

**Purpose**: Complete MCP JSON-RPC 2.0 protocol layer — parsing, serialization, helpers.

**Key design choices**:

1. **`JsonElement option` for id**: The JSON-RPC spec allows `id` to be string, number, or null. Using `JsonElement` preserves the original type when echoing back in responses. Using `string` would lose numeric ids.

2. **`Utf8JsonWriter` for responses**: Direct writer instead of serializing anonymous records. This avoids F# anonymous record boxing issues and gives precise control over the JSON output (e.g., writing `null` for missing ids).

3. **CamelCase naming policy**: Matches MCP convention (`protocolVersion`, `serverInfo`, `inputSchema`).

4. **WriteIndented = false**: Responses are single-line (required for stdio transport — "Messages delimited by newlines, MUST NOT contain embedded newlines").

**Functions by category**:

| Category | Function | Line | Purpose |
|----------|----------|------|---------|
| Parsing | `parseRequest` | 56 | JSON-RPC line → McpRequest |
| Response | `successResponse` | 93 | Build {jsonrpc, id, result} |
| Response | `errorResponse` | 117 | Build {jsonrpc, id, error} |
| Response | `methodNotFound` | 139 | -32601 error |
| Response | `invalidParams` | 142 | -32602 error |
| Response | `internalError` | 145 | -32603 error |
| MCP | `initializeResponse` | 153 | Server capabilities |
| MCP | `toolResult` | 171 | {content: [{type:"text", text:...}]} |
| MCP | `toolError` | 178 | Same but isError:true |
| Params | `extractToolCall` | 190 | Get name + arguments from params |
| Params | `getArg` | 204 | Required string param |
| Params | `getArgOpt` | 213 | Optional string param |
| Params | `getArgInt` | 222 | Integer param with default |

### 4.2 ZenohTools.fs (219 lines)

**Purpose**: 4 Zenoh MCP tools with enum-driven dispatch.

**Tool schema design**:

```
zenoh_session:
  action: enum ["open", "close", "stats"]  ← REQUIRED
  endpoints: string                         ← open only
  mode: enum ["client", "peer"]             ← open only

zenoh_pub:
  key: string      ← REQUIRED
  payload: string  ← REQUIRED

zenoh_sub:
  action: enum ["subscribe", "poll", "unsubscribe"]  ← REQUIRED
  key: string                                         ← subscribe only
  id: string                                          ← poll/unsubscribe only
  limit: integer (default: 10)                        ← poll only

zenoh_query:
  action: enum ["get", "metrics", "verify"]  ← REQUIRED
  key: string                                 ← get only
  timeout_ms: integer (default: 5000)         ← get only
```

**`requireSession` guard pattern**: Shared helper that checks `SessionHandle <> nativeint 0` before executing. Returns clear error with remediation guidance ("Call zenoh_session with action=open first"). This prevents cryptic FFI errors from null handle dereference.

**Subscription ID scheme**: Sequential counters (`sub_1`, `sub_2`, ...). Simple, deterministic, human-readable. Not UUID — the LLM needs to reference these in follow-up calls, so brevity matters.

**Poll limit capping**: Uses `McpProtocol.getArgInt "limit" 10 args` — defaults to 10, passed directly to FFI. The FFI bridge internally caps at 100 per `ZenohFfiBridge.poll`.

### 4.3 SentinelTools.fs (145 lines)

**Purpose**: Single `sentinel` tool with lazy Zenoh polling.

**Lazy subscription pattern**:

```fsharp
let private ensureSubscribed (state: SentinelState) (sessionHandle: nativeint) : unit =
    if sessionHandle <> nativeint 0 then
        if state.HealthSubHandle = nativeint 0 then
            match ZenohFfiBridge.subscribe sessionHandle "indrajaal/sentinel/**" with
            | Ok h -> state.HealthSubHandle <- h | Error _ -> ()
```

- Subscribes on first use, not on startup (lazy)
- Silently ignores subscription failures (degrades to "no data" rather than crashing)
- Uses wildcard `**` to capture all Sentinel subtopics

**Health cache update**: Parses JSON payload from the **latest** Zenoh sample (`List.last`). Earlier samples in the same poll batch are discarded — only the most recent health snapshot matters.

**Type annotation requirement**: F# requires explicit `(name: string)` annotation on the inline helper functions `f` and `s` because `JsonElement.TryGetProperty` has 3 overloads (`string`, `ReadOnlySpan<char>`, `ReadOnlySpan<byte>`) and F# can't infer which one without the annotation.

### 4.4 Program.fs (148 lines)

**Purpose**: MCP server entry point — stdio loop, dispatch, cleanup.

**Startup banner** (to stderr only):
```
[sentinel-zenoh-mcp] Starting Indrajaal Sentinel+Zenoh MCP Server v21.3.0
[sentinel-zenoh-mcp] PID: 12345 | FFI available: true
```

**Request routing**:

| Method | Response? | Handler |
|--------|-----------|---------|
| `initialize` | Yes | `McpProtocol.initializeResponse` |
| `notifications/initialized` | No | Log only |
| `tools/list` | Yes | Combine ZenohTools + SentinelTools definitions |
| `tools/call` | Yes | Dispatch to ZenohTools first, then SentinelTools |
| `notifications/*` | No | Log only (fire-and-forget) |
| Unknown (with id) | Yes | `methodNotFound` error |
| Unknown (no id) | No | Silent (notification convention) |

**Tool dispatch order**: ZenohTools checked first (4 tools), then SentinelTools (1 tool). Both return `string option` — `Some` if handled, `None` if not their tool. If neither handles it: `methodNotFound`.

**Cleanup** (`finally` block):
1. Close all Zenoh subscriptions (from ZenohTools state)
2. Close Zenoh session
3. Shutdown Sentinel subscriptions (from SentinelTools state)
4. Log completion

**EOF handling**: `Console.In.ReadLine()` returns `null` when the host closes stdin. This is the normal shutdown signal per MCP stdio transport spec.

### 4.5 Cepaf.Sentinel.MCP.fsproj

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net10.0</TargetFramework>          <!-- SC-NET-001 -->
    <LangVersion>preview</LangVersion>
    <RootNamespace>Cepaf.Sentinel.MCP</RootNamespace>
    <AssemblyName>cepaf-sentinel-mcp</AssemblyName>
    <Version>21.3.0</Version>
  </PropertyGroup>
  <ItemGroup>
    <!-- F# compilation order matters -->
    <Compile Include="Protocol/McpProtocol.fs" />       <!-- Types + helpers first -->
    <Compile Include="Tools/ZenohTools.fs" />            <!-- Depends on McpProtocol -->
    <Compile Include="Tools/SentinelTools.fs" />         <!-- Depends on McpProtocol + ZenohCore -->
    <Compile Include="Program.fs" />                      <!-- Depends on all above -->
  </ItemGroup>
  <ItemGroup>
    <ProjectReference Include="..\Cepaf\Cepaf.fsproj" />  <!-- Gets ZenohFfiBridge transitively -->
  </ItemGroup>
</Project>
```

**Single project reference**: Only `Cepaf.fsproj`. This transitively provides `Cepaf.Zenoh.Core` (ZenohFfiBridge, ZenohTypes) and `Cepaf.Config`. No direct reference to `Cepaf.Cockpit` (avoids Avalonia deps).

### 4.6 .mcp.json Registration

> **WARNING**: Do NOT use `dotnet run` or `dotnet exec` — see Section 10 (.NET 10 Stream Corruption Bug).

```json
"sentinel-zenoh": {
    "command": "bash",
    "args": ["-c", "export DOTNET_ROOT=\"$(dirname \"$(readlink -f \"$(which dotnet)\")\")\" && export LD_LIBRARY_PATH=\"./target/release:${LD_LIBRARY_PATH:-}\" && exec ./lib/cepaf/src/Cepaf.Sentinel.MCP/bin/Release/net10.0/cepaf-sentinel-mcp"],
    "env": {
        "ZENOH_USE_NATIVE": "true"
    },
    "description": "Zenoh pub/sub and Sentinel health monitoring via FFI bridge"
}
```

**Why `bash -c exec` instead of `dotnet run`**: The `dotnet run` and `dotnet exec` commands on .NET 10 (NixOS) swap stdout and stderr file descriptors, corrupting the MCP stdio transport. Running the native binary directly with `exec` avoids this. See Section 10 for full details.

**Environment resolution**:
- `DOTNET_ROOT`: Resolved dynamically from `readlink -f $(which dotnet)` — nix-stable, survives `nix rebuild`
- `LD_LIBRARY_PATH`: Prepends `./target/release` for `libzenoh_ffi.so` P/Invoke discovery
- `ZENOH_USE_NATIVE=true`: Activates real FFI path (vs. simulated mode)

**Pre-requisites**: The binary must be built first:
```bash
dotnet build lib/cepaf/src/Cepaf.Sentinel.MCP/Cepaf.Sentinel.MCP.fsproj -c Release
```

### 4.7 run-mcp.sh Wrapper Script

A convenience wrapper at `lib/cepaf/src/Cepaf.Sentinel.MCP/run-mcp.sh` for manual testing:

```bash
#!/usr/bin/env bash
# Sentinel+Zenoh MCP Server launcher
# Resolves DOTNET_ROOT dynamically from PATH (nix-stable)
# Required because `dotnet run`/`dotnet exec` swap stdout/stderr on .NET 10
#
# Usage: ./run-mcp.sh              (stdio MCP server)
#        ./run-mcp.sh --build      (rebuild then run)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
BIN="$SCRIPT_DIR/bin/Release/net10.0/cepaf-sentinel-mcp"

# Build if binary missing or --build flag
if [ ! -f "$BIN" ] || [ "${1:-}" = "--build" ]; then
    dotnet build "$SCRIPT_DIR/Cepaf.Sentinel.MCP.fsproj" -c Release --verbosity quiet >&2
    [ "${1:-}" = "--build" ] && shift
fi

# Resolve DOTNET_ROOT from `dotnet` on PATH (nix-friendly)
export DOTNET_ROOT="${DOTNET_ROOT:-$(dirname "$(readlink -f "$(which dotnet)")")}"

# Zenoh FFI library
export LD_LIBRARY_PATH="${PROJECT_ROOT}/target/release:${LD_LIBRARY_PATH:-}"
export ZENOH_USE_NATIVE="${ZENOH_USE_NATIVE:-true}"

exec "$BIN" "$@"
```

**Key features**:
- Auto-builds on first run or with `--build` flag
- Build output goes to stderr (`>&2`) so it doesn't corrupt JSON-RPC on stdout
- Dynamic DOTNET_ROOT resolution (survives `nix rebuild`)
- `exec` replaces the shell process — correct PID propagation, clean signal handling

---

## 5. FFI Bridge Reference

### 5.1 Rust → F# Function Map

| Rust C ABI function | F# Bridge function | MCP tool(s) that use it |
|---------------------|-------------------|------------------------|
| `zenoh_ffi_open` | `ZenohFfiBridge.openSession` | `zenoh_session` (open) |
| `zenoh_ffi_close` | `ZenohFfiBridge.closeSession` | `zenoh_session` (close), Program cleanup |
| `zenoh_ffi_is_connected` | `ZenohFfiBridge.isConnected` | `zenoh_session` (open, verify connected) |
| `zenoh_ffi_publish` | `ZenohFfiBridge.publishString` | `zenoh_pub` |
| `zenoh_ffi_subscribe` | `ZenohFfiBridge.subscribe` | `zenoh_sub` (subscribe), `sentinel` (lazy) |
| `zenoh_ffi_poll` | `ZenohFfiBridge.poll` | `zenoh_sub` (poll), `sentinel` (health/threats) |
| `zenoh_ffi_unsubscribe` | `ZenohFfiBridge.unsubscribe` | `zenoh_sub` (unsubscribe), `sentinel` shutdown, Program cleanup |
| `zenoh_ffi_get` | `ZenohFfiBridge.get` | `zenoh_query` (get) |
| `zenoh_ffi_session_stats` | `ZenohFfiBridge.sessionStats` | `zenoh_session` (stats) |
| `zenoh_ffi_metrics` | `ZenohFfiBridge.getMetrics` | `zenoh_query` (metrics) |
| `zenoh_ffi_verify` | `ZenohFfiBridge.verify` | `zenoh_query` (verify, fallback) |
| `zenoh_ffi_verify_detailed` | `ZenohFfiBridge.verifyDetailed` | `zenoh_query` (verify, primary) |
| `zenoh_ffi_last_error` | `ZenohFfiBridge.lastError` | Internal error messages |

### 5.2 Safety Guarantees

| Mechanism | Constraint | Implementation |
|-----------|-----------|----------------|
| Null handle check | AOR-FFI-001 | `if state.SessionHandle = nativeint 0` before every FFI call |
| Buffer bounds | SC-ZTEST-016 | DefaultBufSize = 65536 (64KB) |
| Exception guard | SC-ZENOH-FFI-030 | try/catch around all P/Invoke |
| Timeout guard | SC-ZENOH-FFI-030 | 10s Task.WaitAll in openSession |
| Idempotent cleanup | - | closeSession/unsubscribe safe to call multiple times |
| Panic capture | - | Rust `ffi_guard!` macro catches panics at boundary |
| Lock-free metrics | - | 27 atomic counters (SeqCst) in Rust |
| Tokio isolation | - | Semaphore (capacity=2) prevents FFI thread starvation |

### 5.3 12 Formal Invariants (zenoh_query action=verify)

| ID | Invariant | Checks |
|----|-----------|--------|
| INV-1 | Session handle validity | Non-null after open, null after close |
| INV-2 | Subscription handle validity | Non-null after subscribe, null after unsub |
| INV-3 | Publish counter monotonicity | Counter only increases |
| INV-4 | Error counter monotonicity | Counter only increases |
| INV-5 | Buffer size bounds | All buffers ≤ 64KB |
| INV-6 | Metrics consistency | All counters ≥ 0 |
| INV-7 | Latency non-negative | All latency values ≥ 0 |
| INV-8 | Session singleton | At most 1 active session |
| INV-9 | Subscription refcount | Subscribe increments, unsub decrements |
| INV-10 | Poll returns ≤ max_messages | Never exceeds requested limit |
| INV-11 | UTF-8 payload validity | All returned strings are valid UTF-8 |
| INV-12 | Cleanup completeness | No leaked handles after close |

---

## 6. Test Guide

### 6.1 Manual Protocol Testing

> **IMPORTANT**: Always use the native binary, never `dotnet run`. See Section 10 for why.

**Setup** — build the binary and set env:
```bash
dotnet build lib/cepaf/src/Cepaf.Sentinel.MCP/Cepaf.Sentinel.MCP.fsproj -c Release --verbosity quiet
export BIN=./lib/cepaf/src/Cepaf.Sentinel.MCP/bin/Release/net10.0/cepaf-sentinel-mcp
export DOTNET_ROOT="$(dirname "$(readlink -f "$(which dotnet)")")"
export LD_LIBRARY_PATH="./target/release:${LD_LIBRARY_PATH:-}"
```

**Initialize handshake**:
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | $BIN 2>/dev/null
```
Expected: `{"jsonrpc":"2.0","id":1,"result":{"capabilities":{"tools":{"listChanged":false}},"protocolVersion":"2025-03-26","serverInfo":{"name":"indrajaal-sentinel-zenoh","version":"21.3.0"}}}`

**Tool listing**:
```bash
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}\n{"jsonrpc":"2.0","method":"notifications/initialized"}\n{"jsonrpc":"2.0","id":2,"method":"tools/list"}\n' \
  | timeout 10 $BIN 2>/dev/null
```
Expected: 2 lines of JSON. Second line contains `"tools"` array with 5 entries.

**Sentinel status (no Zenoh session)**:
```bash
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}\n{"jsonrpc":"2.0","method":"notifications/initialized"}\n{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"sentinel","arguments":{"action":"status"}}}\n' \
  | timeout 10 $BIN 2>/dev/null
```
Expected: `{"health_sub":false,"polls":0,"session":false,"threat_sub":false,"updated":"never"}`

**Publish without session (error case)**:
```bash
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}\n{"jsonrpc":"2.0","method":"notifications/initialized"}\n{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"zenoh_pub","arguments":{"key":"test","payload":"hello"}}}\n' \
  | timeout 10 $BIN 2>/dev/null
```
Expected: `"isError":true` with message "No session. Call zenoh_session with action=open first."

**Unknown tool**:
```bash
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}\n{"jsonrpc":"2.0","method":"notifications/initialized"}\n{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"nonexistent","arguments":{}}}\n' \
  | timeout 10 $BIN 2>/dev/null
```
Expected: `"error":{"code":-32601,"message":"Method not found: tool: nonexistent"}`

**Invalid action enum**:
```bash
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}\n{"jsonrpc":"2.0","method":"notifications/initialized"}\n{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"zenoh_session","arguments":{"action":"invalid"}}}\n' \
  | timeout 10 $BIN 2>/dev/null
```
Expected: `"error":{"code":-32602,"message":"Invalid params: Unknown action: invalid (expected open|close|stats)"}`

### 6.2 Live Zenoh Integration Testing

Requires a running Zenoh router:

```bash
# Terminal 1: Start Zenoh router
zenoh-router  # or: podman run --rm -p 7447:7447 eclipse/zenoh:latest

# Terminal 2: Start MCP server interactively (use native binary, NOT dotnet run)
export DOTNET_ROOT="$(dirname "$(readlink -f "$(which dotnet)")")"
export LD_LIBRARY_PATH="./target/release:${LD_LIBRARY_PATH:-}"
export ZENOH_USE_NATIVE=true
./lib/cepaf/src/Cepaf.Sentinel.MCP/bin/Release/net10.0/cepaf-sentinel-mcp

# Then type JSON-RPC lines:
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}
{"jsonrpc":"2.0","method":"notifications/initialized"}
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"zenoh_session","arguments":{"action":"open"}}}
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"zenoh_pub","arguments":{"key":"indrajaal/test/hello","payload":"{\"msg\":\"from MCP\"}"}}}
{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"zenoh_sub","arguments":{"action":"subscribe","key":"indrajaal/test/**"}}}
{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"zenoh_pub","arguments":{"key":"indrajaal/test/world","payload":"second message"}}}
{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"zenoh_sub","arguments":{"action":"poll","id":"sub_1","limit":10}}}
{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"zenoh_sub","arguments":{"action":"unsubscribe","id":"sub_1"}}}
{"jsonrpc":"2.0","id":8,"method":"tools/call","params":{"name":"zenoh_query","arguments":{"action":"metrics"}}}
{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"zenoh_query","arguments":{"action":"verify"}}}
{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"zenoh_session","arguments":{"action":"stats"}}}
{"jsonrpc":"2.0","id":11,"method":"tools/call","params":{"name":"zenoh_session","arguments":{"action":"close"}}}
```

### 6.3 Claude Code Integration Testing

After `.mcp.json` is configured, restart Claude Code and verify:

1. Claude Code should show `sentinel-zenoh` in its MCP server list
2. Ask Claude: "What Zenoh tools are available?" — should describe 5 tools
3. Ask Claude: "Open a Zenoh session" — should call `zenoh_session` with `action=open`
4. Ask Claude: "Publish hello to indrajaal/test" — should call `zenoh_pub`
5. Ask Claude: "Check Sentinel health" — should call `sentinel` with `action=health`
6. Ask Claude: "Run Zenoh invariant checks" — should call `zenoh_query` with `action=verify`

### 6.4 Automated F# Test Plan (Future)

Tests to add in `lib/cepaf/test/Cepaf.Tests/Unit/MCP/`:

| Test | What it validates |
|------|-------------------|
| `McpProtocol_parseRequest_valid` | Parses well-formed JSON-RPC 2.0 |
| `McpProtocol_parseRequest_invalid_version` | Rejects jsonrpc != "2.0" |
| `McpProtocol_parseRequest_missing_method` | Returns error for missing method |
| `McpProtocol_id_preservation` | Numeric id echoed as number, string as string |
| `McpProtocol_initializeResponse` | Contains protocolVersion, capabilities, serverInfo |
| `McpProtocol_toolResult_format` | Contains content array with type=text |
| `McpProtocol_toolError_isError` | Sets isError=true |
| `McpProtocol_extractToolCall` | Extracts name and arguments |
| `McpProtocol_getArg_missing` | Returns Error for missing required arg |
| `McpProtocol_getArgInt_default` | Falls back to default when missing |
| `ZenohTools_dispatch_unknown` | Returns None for unknown tool name |
| `ZenohTools_session_no_ffi` | Returns error when FFI unavailable |
| `ZenohTools_pub_no_session` | Returns isError with guidance message |
| `ZenohTools_sub_invalid_action` | Returns invalidParams for bad action |
| `SentinelTools_dispatch_unknown` | Returns None for unknown tool name |
| `SentinelTools_status_no_session` | Returns all-false status |
| `SentinelTools_invalid_action` | Returns invalidParams for bad action |
| `Program_handleRequest_initialize` | Returns Some with capabilities |
| `Program_handleRequest_notification` | Returns None |
| `Program_handleRequest_unknown_with_id` | Returns Some error |
| `Program_handleRequest_unknown_no_id` | Returns None |

### 6.5 Performance Benchmarks

| Operation | Target | Constraint |
|-----------|--------|------------|
| Initialize handshake | < 1ms | Protocol overhead only |
| tools/list | < 1ms | 5 tools, ~1KB JSON |
| zenoh_pub | < 10ms | SC-ZTEST-003 |
| zenoh_sub (poll) | < 15ms | Non-blocking poll + JSON serialize |
| sentinel (health) | < 50ms | Subscribe + poll + parse + serialize |
| zenoh_query (verify) | < 100ms | 12 invariant checks |
| First invocation (JIT) | < 6s | dotnet run cold start |
| Subsequent invocations | < 100ms | No recompilation |

---

## 7. References

### 7.1 MCP Specification

| Document | URL | Used for |
|----------|-----|----------|
| MCP Introduction | `https://modelcontextprotocol.io/introduction` | Architecture overview |
| MCP Tools Spec | `https://modelcontextprotocol.io/docs/concepts/tools` | Tool schema, content types |
| MCP Architecture | `https://modelcontextprotocol.io/docs/concepts/architecture` | Host/Client/Server model |
| MCP Transports | `https://modelcontextprotocol.io/docs/concepts/transports` | stdio transport rules |
| MCP Lifecycle | `https://modelcontextprotocol.io/specification/2025-06-18/basic/lifecycle` | Initialize handshake |
| MCP Server Tools | `https://modelcontextprotocol.io/specification/2025-06-18/server/tools` | tools/list, tools/call |
| MCP Build Server | `https://modelcontextprotocol.io/docs/develop/build-server` | Implementation patterns |

### 7.2 Codebase References

| File | Lines | Purpose |
|------|-------|---------|
| `lib/cepaf/src/Cepaf/Zenoh/Core/ZenohFfiBridge.fs` | ~480 | FFI bridge (13 DllImport wrappers) |
| `lib/cepaf/src/Cepaf/Zenoh/Core/ZenohTypes.fs` | ~365 | SessionConfig, ZenohSample, ZenohHealth, ZenohError |
| `native/zenoh_ffi/src/lib.rs` | ~1150 | Rust cdylib (13 C ABI functions) |
| `native/zenoh_ffi/generated/ZenohFfi.g.cs` | ~200 | csbindgen output (reference only) |
| `lib/cepaf/src/Cepaf.Cockpit/SentinelBridge.fs` | ~250 | Original Sentinel agent (not used, for reference) |
| `.mcp.json` | 265 | MCP server registry |

### 7.3 STAMP Constraints Applied

| Constraint | Where enforced |
|------------|----------------|
| SC-ZEN-001 (Zenoh unified IPC) | All communication via Zenoh FFI, not HTTP/Port |
| SC-ZEN-002 (JSON-RPC deprecated) | MCP uses JSON-RPC but over stdio, not custom Elixir Port |
| SC-PRAJNA-004 (Sentinel integration) | `sentinel` tool reads from Zenoh health topics |
| SC-ZENOH-FFI-001..050 (FFI safety) | Null checks, buffer bounds, exception guards |
| SC-ZTEST-003 (Publish < 10ms) | Direct FFI path, no serialization overhead |
| SC-ZTEST-004 (Async publishing) | Non-blocking poll model |
| SC-ZTEST-016 (Payload < 64KB) | DefaultBufSize = 65536 |
| SC-NET-001 (net10.0 mandatory) | `<TargetFramework>net10.0</TargetFramework>` |
| SC-CEP-005 (Pre-compiled F#) | Compiled project, not .fsx script |

### 7.4 AOR Rules Applied

| Rule | Where enforced |
|------|----------------|
| AOR-FFI-001 (Validate pointers) | `requireSession` guard, `nativeint 0` checks |
| AOR-SYNC-007 (Sentinel health sync) | Polling on tool call |
| AOR-ZTEST-004 (Async publishing) | Non-blocking ZenohFfiBridge.poll |
| AOR-NET-001 (net10.0 verified) | fsproj TargetFramework |

### 7.5 Journal & Memory References

| Document | Purpose |
|----------|---------|
| `journal/2026-03/20260319-1120-zenoh-ffi-v2-instrumented-correctness.md` | FFI architecture, 12 invariants, 27 counters |
| `memory/MEMORY.md` → Zenoh FFI Architecture | Build commands, LD_LIBRARY_PATH, test patterns |

---

## 8. Tradeoff Summary Matrix

| Decision | Chose | Over | Why | Cost |
|----------|-------|------|-----|------|
| Protocol | MCP stdio | gRPC, REST, Zenoh direct | Native Claude Code integration | First-call JIT ~6s |
| Tools | 5 enum-driven | 14 granular | ~1,800 tokens/session saved | Slightly more complex dispatch |
| Responses | Abbreviated keys | Verbose keys | Token economy | Less self-documenting |
| Sentinel | Self-contained polling | Full SentinelBridge | Avoids +40MB Avalonia deps | Pull-on-demand, not push |
| Language | F# | TypeScript/Python | Direct FFI access, existing bridge | No official MCP SDK |
| Protocol version | 2025-03-26 | 2025-06-18 | Broader compatibility | No outputSchema/structuredContent |
| State | Mutable records | Immutable + MailboxProcessor | Single-threaded, pragmatic | Not idiomatic FP |
| Build | Pre-compiled native binary | dotnet run / AOT publish | Avoids .NET 10 stream corruption bug; instant startup | Requires `dotnet build` before first use |

---

## 9. Future Improvements

1. **AOT compilation**: `dotnet publish -r linux-x64 --self-contained -c Release` to eliminate .NET runtime dependency entirely
2. **outputSchema**: Upgrade to protocol 2025-06-18 and add structured output schemas for type-safe results
3. **Extract SentinelBridge to shared lib**: Factor out from Cepaf.Cockpit into `Cepaf.Sentinel.Core` for reuse
4. **Resources primitive**: Expose Zenoh topic tree as MCP Resources (read-only data sources)
5. **Prompts primitive**: Add pre-built prompts for common operations (e.g., "diagnose mesh health")
6. **Notifications**: Emit `notifications/tools/list_changed` if Zenoh connection state changes available tools
7. **Connection pooling**: Keep Zenoh session warm across Claude Code invocations (requires long-running daemon)
8. **Upstream .NET bug report**: File issue with dotnet/runtime about stdout/stderr stream swapping on .NET 10 (NixOS, see Section 10)

---

## 10. Known Issue: .NET 10 stdout/stderr Stream Corruption

### 10.1 The Bug

**Discovery date**: 2026-03-20
**Severity**: CRITICAL for MCP stdio transport
**Affected**: `dotnet run` and `dotnet exec` on .NET 10.0.101 (NixOS)
**Root cause**: .NET 10 runtime host swaps stdout (fd 1) and stderr (fd 2) when launching child processes

### 10.2 Symptoms

When running the MCP server via `dotnet run`:

```bash
# Redirect stderr to a file, expect only diagnostic messages there
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
  | dotnet run --project lib/cepaf/src/Cepaf.Sentinel.MCP/Cepaf.Sentinel.MCP.fsproj 2>/tmp/stderr.log

# EXPECTED on stdout:  {"jsonrpc":"2.0","id":1,"result":{...}}
# ACTUAL on stdout:    [sentinel-zenoh-mcp] Starting...   (diagnostic messages!)

# EXPECTED in stderr:  [sentinel-zenoh-mcp] Starting...
# ACTUAL in stderr:    {"jsonrpc":"2.0","id":1,"result":{...}}   (JSON-RPC responses!)
```

The F# code is correct — `Console.Out.WriteLine` writes JSON-RPC responses, `Console.Error.WriteLine` writes diagnostics. But `dotnet run` swaps the streams before they reach the host process.

### 10.3 Verification

Confirmed with `dotnet exec` as well:

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
  | dotnet exec ./lib/cepaf/src/Cepaf.Sentinel.MCP/bin/Release/net10.0/cepaf-sentinel-mcp.dll 2>/tmp/stderr.log

# Same result: JSON goes to stderr, diagnostics go to stdout
```

The native binary does NOT exhibit this bug:

```bash
export DOTNET_ROOT="$(dirname "$(readlink -f "$(which dotnet)")")"
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
  | ./lib/cepaf/src/Cepaf.Sentinel.MCP/bin/Release/net10.0/cepaf-sentinel-mcp 2>/tmp/stderr.log

# CORRECT: JSON on stdout, diagnostics in stderr file
```

### 10.4 Impact on MCP

MCP stdio transport requires:
- **stdout**: JSON-RPC 2.0 responses only
- **stderr**: Diagnostic messages (logged by host, never parsed)

With `dotnet run`, the host (Claude Code) receives diagnostic text on stdout where it expects JSON-RPC, causing parse failures. The actual JSON-RPC responses go to stderr where they're logged but never processed as responses.

### 10.5 Workaround

**Always run the native binary directly**, never `dotnet run` or `dotnet exec`:

```bash
# Build once (output goes to bin/Release/net10.0/)
dotnet build lib/cepaf/src/Cepaf.Sentinel.MCP/Cepaf.Sentinel.MCP.fsproj -c Release

# Run the native binary with DOTNET_ROOT set
export DOTNET_ROOT="$(dirname "$(readlink -f "$(which dotnet)")")"
export LD_LIBRARY_PATH="./target/release:${LD_LIBRARY_PATH:-}"
./lib/cepaf/src/Cepaf.Sentinel.MCP/bin/Release/net10.0/cepaf-sentinel-mcp
```

The `.mcp.json` entry uses `bash -c exec` to handle env setup and binary launch in a single command:

```json
"command": "bash",
"args": ["-c", "export DOTNET_ROOT=\"$(dirname \"$(readlink -f \"$(which dotnet)\")\")\" && export LD_LIBRARY_PATH=\"./target/release:${LD_LIBRARY_PATH:-}\" && exec ./lib/cepaf/src/Cepaf.Sentinel.MCP/bin/Release/net10.0/cepaf-sentinel-mcp"]
```

### 10.6 DOTNET_ROOT on NixOS

The native binary requires `DOTNET_ROOT` to locate the .NET runtime. On NixOS, the dotnet SDK is installed to a nix store path that changes on every `nix rebuild`:

```
/nix/store/qjcwx5f3gbm9h3wnlqrqiyr8q8mic2yl-dotnet-sdk-10.0.101/share/dotnet/
```

**Hardcoding this path is fragile** — it breaks on the next rebuild.

**Dynamic resolution** (stable across rebuilds):
```bash
export DOTNET_ROOT="$(dirname "$(readlink -f "$(which dotnet)")")"
```

This resolves `dotnet` through PATH → follows the symlink to the nix store → takes the parent directory. Works because `which dotnet` returns a symlink that `readlink -f` fully resolves.

### 10.7 FMEA Entry

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| dotnet run stream swap | 9 | 10 (always on .NET 10 NixOS) | 4 (not obvious without stderr redirect) | 360 | Use native binary; never dotnet run |
| DOTNET_ROOT not set | 8 | 3 (only outside devenv) | 8 (clear error message) | 192 | Dynamic resolution from PATH |
| Binary not built | 5 | 4 (after clean or first use) | 9 (file not found) | 180 | Auto-build in run-mcp.sh |

---

## 11. Comprehensive MCP Protocol Smoke Test Results

### 11.1 Test Setup

```bash
# Build binary
dotnet build lib/cepaf/src/Cepaf.Sentinel.MCP/Cepaf.Sentinel.MCP.fsproj -c Release --verbosity quiet

# Set environment
export DOTNET_ROOT="$(dirname "$(readlink -f "$(which dotnet)")")"
export LD_LIBRARY_PATH="./target/release:${LD_LIBRARY_PATH:-}"
BIN=./lib/cepaf/src/Cepaf.Sentinel.MCP/bin/Release/net10.0/cepaf-sentinel-mcp
```

### 11.2 10-Request Smoke Test

All 10 requests sent as a single batched input via `printf ... | $BIN 2>/dev/null`:

| # | Method | Tool/Action | Result | Status |
|---|--------|-------------|--------|--------|
| 1 | `initialize` | — | `protocolVersion: "2025-03-26"`, `serverInfo.name: "indrajaal-sentinel-zenoh"`, `serverInfo.version: "21.3.0"` | PASS |
| 2 | `tools/list` | — | 5 tools returned: `zenoh_session`, `zenoh_pub`, `zenoh_sub`, `zenoh_query`, `sentinel` | PASS |
| 3 | `tools/call` | `sentinel` → `status` | `health_sub: false`, `threat_sub: false`, `session: false`, `updated: "never"`, `polls: 0` | PASS |
| 4 | `tools/call` | `sentinel` → `health` | `score: 0.0`, `status: "unknown"`, `cpu: 0.0`, `mem: 0.0`, `threats: 0`, `updated: "never"` | PASS |
| 5 | `tools/call` | `sentinel` → `threats` | `n: 0`, `threats: []` | PASS |
| 6 | `tools/call` | `zenoh_query` → `verify` | **12/12 formal invariants passing** — full JSON with per-invariant pass/fail | PASS |
| 7 | `tools/call` | `zenoh_query` → `metrics` | 27 atomic counters returned (SeqCst): `open_calls: 0`, `close_calls: 0`, `publish_calls: 0`, etc. All zeroed (no session opened). 4 latency histogram buckets. | PASS |
| 8 | `tools/call` | `zenoh_pub` | `isError: true`, message: "No session. Call zenoh_session with action=open first." | PASS (correct error) |
| 9 | `tools/call` | `zenoh_session` → `stats` | `isError: true`, message: "No session. Call zenoh_session with action=open first." | PASS (correct error) |
| 10 | `tools/call` | `bogus_tool` | JSON-RPC error: `code: -32601`, `message: "Method not found: tool: bogus_tool"` | PASS (correct error) |

**Result**: 10/10 passed. All response types exercised: success, tool error (isError), protocol error (-32601).

### 11.3 Key Observations

1. **Zero-session behavior is correct**: Sentinel tools degrade gracefully (return zeroed/empty data) rather than erroring. Zenoh tools return clear guidance messages ("Call zenoh_session with action=open first").

2. **12/12 invariants pass without a session**: The `zenoh_query verify` action validates FFI bridge invariants at the library level, not session level. All 12 pass because the Rust library is loaded and its internal state is consistent.

3. **27 FFI metrics available**: Even without an active Zenoh session, the metrics endpoint returns all 27 atomic counters from the Rust layer. This is useful for debugging FFI initialization.

4. **Error routing is correct**: Protocol errors use JSON-RPC error format (`code`, `message`). Business logic errors use `isError: true` in the tool result content. This matches MCP spec separation.

5. **Response size**: All responses are compact (token economy). The largest single response is the `verify` action (~1.2KB for 12 invariants).

### 11.4 Claude Code Integration Status

The MCP server is registered in `.mcp.json` and confirmed working with Claude Code:
- Claude Code discovers the `sentinel-zenoh` server on session start
- All 5 tools are available in the tool list
- Tool calls are correctly dispatched and responses are properly parsed
- **Requirement**: Claude Code session must be restarted after modifying `.mcp.json`

---

## 12. Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2026-03-20 | Claude Opus 4.6 | Initial design guide — architecture, 5 tools, FFI map, test plan |
| 2.0.0 | 2026-03-20 | Claude Opus 4.6 | Added: .NET 10 stream corruption bug (Section 10), run-mcp.sh wrapper (4.7), 10-request smoke test results (Section 11), updated .mcp.json to bash -c exec pattern (4.6), updated manual test commands to use native binary (6.1, 6.2) |
