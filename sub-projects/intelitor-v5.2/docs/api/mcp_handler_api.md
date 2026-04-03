# MCP Handler API Documentation

> Version: 21.3.1-SIL6 | Date: 2026-03-28 | STAMP: SC-MCP-001 to SC-MCP-082

## Overview

The Indrajaal Model Context Protocol (MCP) server exposes 5 domain handlers over
JSON-RPC 2.0 with Server-Sent Events (SSE) transport. Each handler provides typed
tool calls for agent-to-system interaction, enforced by the SIL-6 safety kernel.

## Architecture

```
Agent (Claude/Gemini)
  |  JSON-RPC 2.0 over SSE
  v
Cepaf.Sentinel.MCP Server (F#, .NET 10)
  |
  +-- GuardianHandler      (safety approvals, constitutional checks)
  +-- CortexHandler        (AI inference, guided decoding)
  +-- SmritiHandler        (knowledge queries, ingestion)
  +-- SentinelHandler      (threat assessment, pattern detection)
  +-- CpuGovernorHandler   (CPU metrics, throttle control)
  |
  v
Zenoh IPC Bus --> Elixir Runtime / F# Mesh
```

## Transport: SSE

All MCP communication uses Server-Sent Events for streaming responses.

```bash
# Start the MCP server
dotnet exec lib/cepaf/src/Cepaf.Sentinel.MCP/bin/Release/net10.0/cepaf-sentinel-mcp

# SSE endpoint
GET http://localhost:3001/sse
Accept: text/event-stream

# Tool invocation endpoint
POST http://localhost:3001/message
Content-Type: application/json
```

## JSON-RPC Request Format

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "sentinel",
    "arguments": {
      "action": "assess",
      "target": "indrajaal-ex-app-1"
    }
  }
}
```

## Handler Reference

### 1. Guardian Handler

Controls safety approvals and constitutional verification.

| Tool | Action | Description |
|------|--------|-------------|
| `guardian` | `approve` | Request Guardian approval for a mutation |
| `guardian` | `check` | Verify constitutional constraint holds |
| `guardian` | `veto` | Query veto status for pending operation |

### 2. Cortex Handler

AI inference and guided decoding through OpenRouter.

| Tool | Action | Description |
|------|--------|-------------|
| `cortex` | `infer` | Run inference pipeline via Synapse |
| `cortex` | `decode` | Guided Decoding Engine (GDE) call |
| `cortex` | `graph` | Knowledge Graph query via SMRITI |

### 3. SMRITI Handler

Knowledge management, ingestion, and retrieval.

| Tool | Action | Description |
|------|--------|-------------|
| `smriti` | `query` | Full-text search (FTS5) or semantic search |
| `smriti` | `ingest` | Ingest document into knowledge base |
| `smriti` | `export` | Export knowledge in JSON/Markdown/SQLite |

### 4. Sentinel Handler

Threat detection, pattern hunting, and security assessment.

| Tool | Action | Description |
|------|--------|-------------|
| `sentinel` | `assess` | Run threat assessment on target |
| `sentinel` | `poll` | Poll current threat level |
| `sentinel` | `stats` | Retrieve detection statistics |

### 5. CPU Governor Handler

CPU utilization monitoring and adaptive throttling (SC-CPU-GOV-001).

| Tool | Action | Description |
|------|--------|-------------|
| `cpu_governor` | `check` | Current CPU percentage and mode |
| `cpu_governor` | `publish` | Publish metrics to Zenoh |
| `cpu_governor` | `status` | Scheduler count, jobs, nice level |
| `cpu_governor` | `govern` | Adaptive throttle command |

## SSE Streaming Example

```bash
# Subscribe to SSE stream
curl -N http://localhost:3001/sse

# Response (event stream)
event: endpoint
data: /message?sessionId=abc123

# Send tool call to the session endpoint
curl -X POST "http://localhost:3001/message?sessionId=abc123" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"cpu_governor","arguments":{"action":"check"}}}'

# SSE response
event: message
data: {"jsonrpc":"2.0","id":1,"result":{"content":[{"type":"text","text":"{\"cpu_pct\":42.3,\"mode\":\"normal\",\"schedulers\":16,\"jobs\":16,\"nice\":10}"}]}}
```

## Error Codes

| Code | Meaning |
|------|---------|
| `-32600` | Invalid request (malformed JSON-RPC) |
| `-32601` | Method not found |
| `-32602` | Invalid params (missing required argument) |
| `-32000` | Guardian veto (safety constraint violation) |
| `-32001` | Zenoh unavailable (mesh disconnected) |

## Configuration

Located in `.mcp.json` under the `sentinel-zenoh` entry:

```json
{
  "mcpServers": {
    "sentinel-zenoh": {
      "command": "dotnet",
      "args": ["exec", "lib/cepaf/src/Cepaf.Sentinel.MCP/bin/Release/net10.0/cepaf-sentinel-mcp"],
      "env": {
        "ZENOH_USE_NATIVE": "true",
        "LD_LIBRARY_PATH": "./target/release"
      }
    }
  }
}
```

## Related Constraints

- SC-MCP-001 to SC-MCP-082: Full MCP protocol compliance
- SC-ZENOH-001: Zenoh NIF must be loaded for native transport
- SC-CPU-GOV-001: CPU hard limit 85% enforced via governor handler
- SC-SAFETY-001: Guardian pre-approval for mutations
