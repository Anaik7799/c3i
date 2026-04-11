---
paths:
- native/timestamp_daemon/
- scripts/timestamp/*.sh
- lib/indrajaal/core/timestamp_*.ex
---
# Timestamp Synchronization Protocol (SC-TIME)
# Overview
Ensures system, OpenCode agent, and model timestamps do not drift. Critical for audit trails, forensic analysis, and distributed system coordination.
# Architecture
```
┌─────────────────────────────────────────────────────────────────┐
│                    ENHANCED DAEMON ARCHITECTURE                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │                      TUI Layer (ANSI)                         │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │ │
│  │  │ Drift Meter │  │ Status Box  │  │ Integration │         │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘         │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │   Zenoh     │  │    MCP      │  │    OTEL     │              │
│  │  Publisher   │  │   Tools     │  │   Tracing   │              │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘              │
│         │                 │                 │                       │
│  ┌──────┴────────────────┴─────────────────┴──────┐                │
│  │              Fractal Logging (L0-L7)          │                │
│  │  L0 Constitutional | L4 System | L7 Federation │                │
│  └───────────────────────────────────────────────┘                │
│                           │                                       │
│                           ▼                                       │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │                    State File (JSON)                         │ │
│  │              logs/fractal.log | logs/otel_traces.jsonl      │ │
│  └──────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```
# Thresholds
| Level | Drift | Action |
|-------|-------|--------|
| **NOMINAL** | 0-2s | Log only |
| **MINOR** | 2-5s | Log warning |
| **WARNING** | 5-10s | Alert + log |
| **CRITICAL** | >10s | Halt + NTP sync |
# Fractal Layers (L0-L7)
| Layer | Name | Description |
|-------|------|-------------|
| L0 | Constitutional | Core invariant enforcement |
| L1 | Atomic | Individual timestamp operations |
| L2 | Component | Component-level logging |
| L3 | Transaction | Transaction boundaries |
| L4 | System | System-wide events |
| L5 | Cognitive | Agent-level decisions |
| L6 | Ecosystem | Cross-system coordination |
| L7 | Federation | External integrations |
# Implementation Layers
# Rust: `native/timestamp_daemon/`
**Binary**: `target/release/timestamp_daemon`
```bash
# Start daemon
./target/release/timestamp_daemon
# PID file
~/.local/share/indrajaal-timestamp-sync/timestamp-daemon.pid
```
**Features**:
- Long-running background process
- 30-minute sync interval
- TUI with ANSI colors
- Fractal logging (L0-L7)
- Zenoh telemetry publisher
- MCP tools
- OTEL tracing
- NTP sync on critical drift
- PID file management
# Shell: `scripts/timestamp/indrajaal-timestamp-sync.sh`
```bash
# One-shot sync
./scripts/timestamp/indrajaal-timestamp-sync.sh
```
# Elixir: `lib/indrajaal/core/timestamp_*.ex`
- `timestamp_daemon.ex`: Rust daemon wrapper
- `timestamp_sync.ex`: Coordination layer
# TUI Features
```
┌─ Timestamp Status ────────────────────────────────────────────┐
│ System:  2026-04-02 13:32:49 UTC                              │
│ Model:   2026-04-02 12:30:06 UTC                              │
│ Drift:   +3763s (CRITICAL)                                     │
│ NTP:     ✓ Synced                                              │
└─────────────────────────────────────────────────────────────────┘
┌─ Drift Level ─────────────────────────────────────────────────┐
│ Drift: 3763s [▓▓▓▓▓▓▓▓▓▓] CRITICAL                          │
│ Level Thresholds: Nominal<2s | Minor<5s | Warning<10s | >10s  │
└─────────────────────────────────────────────────────────────────┘
┌─ Integration Status ──────────────────────────────────────────┐
│ Zenoh:   ○ Disabled    │ MCP:      Available                   │
│ OTEL:    ✓ Active      │ Fractal:  L7_FEDERATION              │
└─────────────────────────────────────────────────────────────────┘
```
# Zenoh Telemetry Topics
| Topic | Purpose |
|-------|---------|
| `indrajaal/telemetry/timestamp-sync/status` | Current drift status |
| `indrajaal/telemetry/timestamp-sync/alerts` | Warnings/critical alerts |
| `indrajaal/telemetry/timestamp-sync/history` | Drift history |
# MCP Tools
```rust
// Available via MCP protocol
mcp_get_drift_status() -> MCPToolResult
mcp_force_sync() -> MCPToolResult
mcp_get_telemetry() -> ZenohTelemetry
```
# OpenTelemetry
Logs to: `logs/otel_traces.jsonl`
```json
{
"resource": {
"service.name": "timestamp_daemon",
"service.version": "0.1.0",
"deployment.environment": "indrajaal_sil6"
},
"trace": {
"trace_id": "18a28d7c998b8747",
"span_id": "9d01774b",
"name": "perform_sync",
"kind": "INTERNAL",
"status": "ok"
}
}
```
# State File
Path: `data/state/timestamp-state.json`
```json
{
"last_sync": 1709467200,
"last_sync_iso": "2026-04-02T13:20:00Z",
"opencode_session_start": 1709467200,
"model_timestamp": 1709467200,
"system_to_model_drift": 3,
"drift_level": "minor",
"sync_count": 42,
"sync_source": "Indrajaal Timestamp Sync Daemon v0.1.0"
}
```
# Fractal Log Format
Logs to: `logs/fractal.log` (JSON Lines)
```json
{"timestamp":"2026-04-02T13:32:49.486+00:00","layer":"L7_FEDERATION","level":"INFO","message":"Initial sync: drift=3763s","drift":3763,"drift_level":"critical","sync_count":5,"trace_id":"18a28d7c998b8747"}
```
# Compliance
| Constraint | Status |
|------------|--------|
| SC-TIME-001 | ✅ Startup sync enforced |
| SC-TIME-002 | ✅ 30-min interval enforced |
| SC-TIME-003 | ✅ Max drift 5s enforced |
| SC-TIME-004 | ✅ NTP auto-correction enforced |
| SC-TIME-005 | ✅ Zenoh telemetry enforced |
| Fractal Logging | ✅ L0-L7 |
| TUI | ✅ ANSI colors |
| MCP Tools | ✅ Available |
| OTEL Tracing | ✅ JSONL format |
# FMEA
| Failure Mode | RPN | Detection | Mitigation |
|--------------|-----|-----------|------------|
| Skip startup sync | 36 | Missing log entry | Mandatory hook |
| Daemon crashes | 48 | PID file missing | Auto-restart |
| NTP unreachable | 36 | exit code 3 | Manual intervention |
| Drift > 60s | 64 | Critical alert | Halt operations |
| State file corrupted | 24 | JSON parse fail | Recreate empty |