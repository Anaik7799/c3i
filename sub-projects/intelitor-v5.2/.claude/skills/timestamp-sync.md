---
name: timestamp-sync
description: Synchronize system, agent, and model timestamps to prevent drift. Runs at session start and every 30 minutes. Full TUI, Zenoh, MCP, OTEL, Fractal logging support.
---

# Timestamp Sync Skill

## Purpose

Ensure all timestamps (system, OpenCode agent, model) are synchronized to prevent drift that could affect audit trails, forensic analysis, and distributed system coordination.

## Architecture

```
Shell Script ──┐
                │
Rust Daemon ──┼──► State File ──► Zenoh Telemetry
                │         │
                │         ├──► logs/fractal.log (L0-L7)
                │         └──► logs/otel_traces.jsonl
                │
Elixir Gen ───┘
```

## Features

### TUI (Terminal User Interface)
- ANSI color-coded drift levels
- Real-time status display
- Fractal layer indicator
- Integration status (Zenoh, MCP, OTEL)

### Fractal Logging (L0-L7)
- L0: Constitutional - Core invariants
- L1: Atomic - Individual operations
- L2: Component - Component events
- L3: Transaction - Boundaries
- L4: System - System-wide
- L5: Cognitive - Agent decisions
- L6: Ecosystem - Cross-system
- L7: Federation - External

### Zenoh Telemetry
Topics:
- `indrajaal/telemetry/timestamp-sync/status`
- `indrajaal/telemetry/timestamp-sync/alerts`

### MCP Tools
- `mcp_get_drift_status()`
- `mcp_force_sync()`
- `mcp_get_telemetry()`

### OpenTelemetry
Logs to: `logs/otel_traces.jsonl`

## Usage

### Start Daemon
```bash
./target/release/timestamp_daemon
```

### One-Shot Sync
```bash
./scripts/timestamp/indrajaal-timestamp-sync.sh
```

## Thresholds

| Drift | Level | Color | Action |
|-------|-------|-------|--------|
| 0-2s | NOMINAL | Green | Log info |
| 2-5s | MINOR | Yellow | Log warning |
| 5-10s | WARNING | Magenta | Alert + log |
| >10s | CRITICAL | Red | Halt + NTP sync |

## TUI Display

```
┌─ Timestamp Status ────────────────────────────────────────────┐
│ System:  2026-04-02 13:32:49 UTC                              │
│ Model:   2026-04-02 12:30:06 UTC                              │
│ Drift:   +3763s (CRITICAL)                                     │
│ NTP:     ✓ Synced                                              │
└─────────────────────────────────────────────────────────────────┘

┌─ Drift Level ─────────────────────────────────────────────────┐
│ Drift: 3763s [▓▓▓▓▓▓▓▓▓▓] CRITICAL                          │
└────────────────────────────────────────────────────────────────┘

┌─ Integration Status ──────────────────────────────────────────┐
│ Zenoh:   ○ Disabled    │ MCP:      Available                   │
│ OTEL:    ✓ Active      │ Fractal:  L7_FEDERATION              │
└────────────────────────────────────────────────────────────────┘
```

## Files

| File | Purpose |
|------|---------|
| `native/timestamp_daemon/` | Rust daemon source |
| `target/release/timestamp_daemon` | Compiled binary |
| `scripts/timestamp/indrajaal-timestamp-sync.sh` | Shell sync |
| `lib/indrajaal/core/timestamp_daemon.ex` | Elixir wrapper |
| `lib/indrajaal/core/timestamp_sync.ex` | Elixir coordination |
| `.claude/rules/timestamp-sync.md` | Full protocol |
| `data/state/timestamp-state.json` | State file |
| `logs/fractal.log` | Fractal logs |
| `logs/otel_traces.jsonl` | OTEL traces |

## Compliance

| Constraint | Description |
|------------|-------------|
| SC-TIME-001 | Startup sync enforced |
| SC-TIME-002 | 30-min interval enforced |
| SC-TIME-003 | Max drift 5s enforced |
| SC-TIME-004 | NTP auto-correction enforced |
| SC-TIME-005 | Zenoh telemetry enforced |
| Fractal Logging | ✅ L0-L7 |
| TUI | ✅ ANSI colors |
| MCP Tools | ✅ Available |
| OTEL Tracing | ✅ JSONL format |
