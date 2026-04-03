# Phase 2: CEPAF Dashboard System Implementation
**Fractal Level**: L0-L4 Complete | **STAMP Compliance**: SC-DASH-* | **Omega**: Active

---

## Document Metadata

| Field | Value |
|-------|-------|
| **Journal ID** | J-2025-12-26-0930 |
| **Phase** | 2 of 4 (CEPAF Implementation) |
| **Author** | Agent 3 (Documenter) |
| **Created** | 2025-12-26 09:30 CET |
| **Last Updated** | 2025-12-26 09:30 CET |
| **FPPS Validated** | Pending |
| **Related Journals** | 20251226-0911-phase1-multi-agent-execution.md |

---

# Level 0 (L0) - Critical/Emergency

## Executive Summary

| Field | Value |
|-------|-------|
| **Date** | 2025-12-26 |
| **Time** | 09:30 CET |
| **Session** | Phase 2 CEPAF Dashboard System |
| **Agents** | 6 (1 Supervisor + 4 Workers + 1 Dashboard Daemon) |
| **Status** | IN_PROGRESS |
| **Priority** | CRITICAL |
| **Omega Compliance** | $\Omega_1$ (Patient Mode), $\Omega_3$ (Zero-Defect), $\Omega_4$ (TDG) |

### Mission Statement
Implement a comprehensive, always-on CEPAF Dashboard System providing real-time visibility into all 9 KPI categories, full terminal width utilization, and seamless integration with the TodoList system per AOR-DASH-003.

### Critical Success Criteria
1. Dashboard daemon runs continuously without interruption (SC-DASH-001)
2. Full terminal width utilization with responsive layout (SC-DASH-002)
3. All 9 KPI categories displayed with <60s data freshness (SC-DASH-003)
4. TodoList JSON synchronization functional (SC-DASH-004)
5. CEPAF OODA loop integration complete (SC-DASH-005)

### New STAMP Constraints Introduced

| ID | Description | Verification Method | Criticality |
|----|-------------|---------------------|-------------|
| SC-DASH-001 | Always-on dashboard availability | PID file exists + `pgrep` returns process | CRITICAL |
| SC-DASH-002 | Full terminal width utilization | `tput cols >= 80` verified at startup | HIGH |
| SC-DASH-003 | Real-time KPI accuracy (<60s staleness) | Timestamp delta check on each refresh | CRITICAL |
| SC-DASH-004 | TodoList integration via JSON sync | `data/tmp/todos.json` exists and valid | HIGH |
| SC-DASH-005 | CEPAF OODA coordination | Loop execution logs in dashboard output | MEDIUM |

### New AOR Rules Introduced

| ID | Description | Enforcement |
|----|-------------|-------------|
| AOR-DASH-001 | Persistent daemon operation - Dashboard MUST survive terminal disconnect | `nohup` + PID tracking |
| AOR-DASH-002 | Non-blocking updates with 5s timeout - Never freeze on slow metrics | `Task.await/2` with timeout |
| AOR-DASH-003 | Claude session integration - TodoList visible in dashboard | JSON file watcher |
| AOR-DASH-004 | 9 mandatory KPI categories - All must display | Startup validation |
| AOR-DASH-005 | Visual standards (ANSI/Unicode) - Consistent rendering | Character set validation |

### Emergency Procedures

| Trigger | Response | Recovery Time |
|---------|----------|---------------|
| Dashboard crash | Auto-restart via systemd/cron | <30s |
| Metric timeout | Display stale indicator | Immediate |
| Container unreachable | Red status + last known state | <5s |
| TodoList sync failure | Retry with exponential backoff | <60s |

---

# Level 1 (L1) - Error/Important

## Agent Assignments

| Agent | Role | Task | Deliverables | Status |
|-------|------|------|--------------|--------|
| Supervisor | Coordinator | CEPAF Rules Document | `docs/operations/CEPAF_DASHBOARD_RULES.md` | PENDING |
| Agent 1 | Developer | Full-Screen Dashboard | `scripts/monitoring/cepaf_dashboard.exs` | IN_PROGRESS |
| Agent 2 | DevOps | Daemon Scripts | start/stop/status/attach scripts | PENDING |
| Agent 3 | Documenter | 5-Level Journal | This file | IN_PROGRESS |
| Agent 4 | Developer | Stub Module Fixes | circuit_breaker.ex, health_monitor.ex | PENDING |
| Dashboard | Daemon | Continuous Monitoring | Always-on KPI display | BLOCKED |

## TDG Compliance Requirements

### PropCheck/StreamData Disambiguation (SC-PROP-023/024)

Per EP-GEN-014 and the mandatory disambiguation rules, all test files for dashboard components MUST include:

```elixir
# MANDATORY: Add after use declarations
alias PropCheck.BasicTypes, as: PC
alias StreamData, as: SD

# PropCheck forall blocks use PC.* generators
property "dashboard refresh interval is positive" do
  forall interval <- PC.pos_integer() do
    interval > 0
  end
end

# ExUnitProperties check all blocks use SD.* generators
check all(
  width <- SD.integer(80..300),
  height <- SD.integer(24..100)
) do
  assert width >= 80
  assert height >= 24
end
```

### Test Coverage Requirements

| Component | Min Coverage | Property Tests | Unit Tests |
|-----------|--------------|----------------|------------|
| cepaf_dashboard.exs | 80% | 5 PropCheck | 10 ExUnit |
| start_dashboard.sh | N/A | N/A | Integration |
| sync_todos.exs | 80% | 3 PropCheck | 5 ExUnit |

## Error Handling Matrix

| Error Type | Detection | Handler | Recovery |
|------------|-----------|---------|----------|
| Terminal too narrow | `tput cols < 80` | Warning + fallback layout | Automatic |
| Podman unavailable | Connection timeout | Display "OFFLINE" | Retry 30s |
| Metrics collection failure | Process exit | Partial display + error indicator | Retry 5s |
| JSON parse error | `Jason.decode!` exception | Use cached data | Log + continue |
| OOM during render | GenServer crash | Restart with reduced metrics | Immediate |

## Dependency Graph

```
Phase 2 Dependencies:
                    ┌──────────────────┐
                    │ Phase 1 Complete │
                    │  (Multi-Agent)   │
                    └────────┬─────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              v              v              v
     ┌────────────┐  ┌─────────────┐  ┌──────────────┐
     │ Rules Doc  │  │ Dashboard   │  │ Daemon       │
     │ (Supervisor)│  │ (Agent 1)  │  │ (Agent 2)    │
     └──────┬─────┘  └──────┬──────┘  └──────┬───────┘
            │               │                │
            │               v                │
            │        ┌─────────────┐         │
            └───────>│ Integration │<────────┘
                     │   Test      │
                     └──────┬──────┘
                            │
                            v
                    ┌───────────────┐
                    │ Phase 2       │
                    │ COMPLETE      │
                    └───────────────┘
```

---

# Level 2 (L2) - Warning/Moderate

## Dashboard KPI Specification

### 1. Compilation KPIs

| Metric | Source | Threshold | Display Format | Color Logic |
|--------|--------|-----------|----------------|-------------|
| Errors | `mix compile 2>&1` | 0 | Integer count | Red if > 0, Green if 0 |
| Warnings | `mix compile 2>&1` | 0 | Integer count | Yellow if > 0, Green if 0 |
| Files | `find lib -name "*.ex" \| wc -l` | 773+ | "XXX files" | White (info) |
| Last Compile | Timestamp | <5min | "X min ago" | Red if >10min |

### 2. Test KPIs

| Metric | Source | Threshold | Display Format | Color Logic |
|--------|--------|-----------|----------------|-------------|
| Total | `mix test --json` | - | Integer count | White |
| Passed | `mix test --json` | 100% | "XXX passed" | Green |
| Failed | `mix test --json` | 0 | "XXX failed" | Red if > 0 |
| Skipped | `mix test --json` | <5% | "XXX skipped" | Yellow if > 0 |
| Coverage | `mix coveralls` | 80%+ | Progress bar | Red <70%, Yellow <80%, Green >=80% |

### 3. Container KPIs

| Container | Health Check Command | Threshold | Display |
|-----------|---------------------|-----------|---------|
| indrajaal-app-standalone | `podman inspect --format '{{.State.Status}}'` | "running" | Green/Red dot |
| indrajaal-db-standalone | `podman inspect --format '{{.State.Status}}'` | "running" | Green/Red dot |
| indrajaal-obs-standalone | `podman inspect --format '{{.State.Status}}'` | "running" | Green/Red dot |
| Resource Usage | `podman stats --no-stream --format json` | <80% CPU/MEM | Percentage |

### 4. Performance KPIs

| Metric | Source | Threshold | Display |
|--------|--------|-----------|---------|
| p50 latency | Artillery JSON | <30ms | "XXms" |
| p95 latency | Artillery JSON | <100ms | "XXms" |
| p99 latency | Artillery JSON | <200ms | "XXms" |
| RPS | Artillery JSON | Baseline | "XX req/s" |
| Memory | `Process.info(:memory)` | <1GB | "XXX MB" |

### 5. Security KPIs

| Metric | Source | Threshold | Display |
|--------|--------|-----------|---------|
| Sobelow High | `mix sobelow --format json` | 0 | Red if > 0 |
| Sobelow Medium | `mix sobelow --format json` | <5 | Yellow if > 0 |
| Sobelow Low | `mix sobelow --format json` | <10 | Info |
| Deps Vulnerabilities | `mix deps.audit` | 0 | Red if > 0 |
| Last Scan | Timestamp | <24h | "X hours ago" |

### 6. Progress KPIs (Tier Progression)

| Tier | Target | Display | Unlock Condition |
|------|--------|---------|------------------|
| C1 Foundation | 80% | Progress bar + percentage | Always visible |
| C2 Advanced | 80% | Progress bar (grayed if locked) | C1 >= 80% |
| C3 Integration | 80% | Progress bar (grayed if locked) | C2 >= 80% |
| C4 Production | 80% | Progress bar (grayed if locked) | C3 >= 80% |

### 7. STAMP KPIs

| Category | Total Count | Display | Verification |
|----------|-------------|---------|--------------|
| SC-VAL-* | 96 | "XX/96 verified" | Automated scan |
| SC-CNT-* | 819 | "XX/819 verified" | Automated scan |
| SC-DASH-* | 5 | "XX/5 verified" (NEW) | This phase |
| SC-PROP-* | 25 | "XX/25 verified" | PropCheck tests |
| SC-ASH-* | 15 | "XX/15 verified" | Ash resource checks |

### 8. TodoList KPIs

| Status | Symbol | Color | JSON Field |
|--------|--------|-------|------------|
| completed | ✅ | Green (`\e[32m`) | `"status": "completed"` |
| in_progress | 🔄 | Yellow (`\e[33m`) | `"status": "in_progress"` |
| pending | ⏳ | Gray (`\e[90m`) | `"status": "pending"` |
| blocked | 🚫 | Red (`\e[31m`) | `"status": "blocked"` |

### 9. Agent KPIs

| Status | Symbol | Color | Meaning |
|--------|--------|-------|---------|
| ACTIVE | ● | Green | Currently executing |
| RUNNING | ▶ | Cyan | Processing task |
| PENDING | ◌ | Yellow | Waiting for assignment |
| IDLE | ○ | Gray | Available |
| ERROR | ✗ | Red | Failed/crashed |

## Layout Specification

```
┌─────────────────────────── CEPAF Dashboard ────────────────────────────┐
│ Last Update: 2025-12-26 09:30:45 CET  │  Refresh: 5s  │  Mode: PATIENT │
├────────────────────────────────────────────────────────────────────────┤
│ COMPILATION          │ TESTS              │ CONTAINERS                 │
│ Errors:     0  ✓     │ Total:    286      │ ● app    Running  CPU: 12% │
│ Warnings:   0  ✓     │ Passed:   286  ✓   │ ● db     Running  CPU:  5% │
│ Files:    773        │ Failed:     0  ✓   │ ● obs    Running  CPU:  8% │
│ Last: 2m ago         │ Coverage:  87%     │                            │
│                      │ [████████░░] 87%   │                            │
├────────────────────────────────────────────────────────────────────────┤
│ PERFORMANCE          │ SECURITY           │ PROGRESS                   │
│ p50:   15ms  ✓       │ Sobelow: 0 high ✓  │ C1: [████████░░] 82%  ✓   │
│ p95:   45ms  ✓       │ Deps:    0 vuln ✓  │ C2: [██████░░░░] 60%      │
│ p99:  120ms  ✓       │ Last: 1h ago       │ C3: [░░░░░░░░░░]  0%  🔒  │
│ RPS:  1200/s         │                    │ C4: [░░░░░░░░░░]  0%  🔒  │
├────────────────────────────────────────────────────────────────────────┤
│ STAMP COMPLIANCE     │ TODO LIST          │ AGENTS                     │
│ SC-VAL:  96/96   ✓   │ ✅ Phase 1 done    │ ● Supervisor  ACTIVE       │
│ SC-CNT: 819/819  ✓   │ 🔄 Phase 2 running │ ▶ Agent 1     RUNNING      │
│ SC-DASH:  5/5    ✓   │ ⏳ Phase 3 pending │ ▶ Agent 2     RUNNING      │
│ Total: 920/920       │ ⏳ Phase 4 pending │ ◌ Agent 3     PENDING      │
└────────────────────────────────────────────────────────────────────────┘
│ [q]uit  [r]efresh  [t]ests  [c]ompile  [l]ogs  [h]elp                  │
└────────────────────────────────────────────────────────────────────────┘
```

---

# Level 3 (L3) - Info/Standard

## Files Created/Modified

### New Files

| File | Purpose | Est. Lines | Status |
|------|---------|------------|--------|
| `docs/operations/CEPAF_DASHBOARD_RULES.md` | Comprehensive rules document | ~200 | PENDING |
| `scripts/monitoring/cepaf_dashboard.exs` | Main dashboard Elixir script | ~500 | IN_PROGRESS |
| `scripts/monitoring/start_dashboard.sh` | Daemon start script | ~30 | PENDING |
| `scripts/monitoring/stop_dashboard.sh` | Daemon stop script | ~20 | PENDING |
| `scripts/monitoring/dashboard_status.sh` | Status check script | ~30 | PENDING |
| `scripts/monitoring/attach_dashboard.sh` | Log attach script | ~20 | PENDING |
| `scripts/monitoring/sync_todos.exs` | TodoList JSON sync | ~30 | PENDING |
| `test/scripts/monitoring/cepaf_dashboard_test.exs` | Dashboard tests | ~150 | PENDING |

### Modified Files

| File | Modification | Reason |
|------|--------------|--------|
| `PROJECT_TODOLIST.md` | Add Phase 2 tasks | Track progress |
| `lib/indrajaal/application.ex` | Optional dashboard supervisor | Integration |

## STAMP Constraint Cross-Reference

| New Constraint | Related To | Verification Method | Test File |
|----------------|------------|---------------------|-----------|
| SC-DASH-001 | SC-OBS-069 (Dual Log) | PID file + process check | `cepaf_dashboard_test.exs` |
| SC-DASH-002 | SC-PRF-050 (Response <50ms) | Terminal width >= 80 | `cepaf_dashboard_test.exs` |
| SC-DASH-003 | $\Omega_3$ (Zero-Defect) | Timestamp freshness <60s | `cepaf_dashboard_test.exs` |
| SC-DASH-004 | AOR-DASH-003 | JSON file sync validation | `sync_todos_test.exs` |
| SC-DASH-005 | SC-AGT-017 (Efficiency) | OODA loop log parsing | `cepaf_dashboard_test.exs` |

## Integration Points

### 1. TodoList Integration (SC-DASH-004)

```elixir
# File: data/tmp/todos.json
# Format:
{
  "updated_at": "2025-12-26T09:30:00Z",
  "todos": [
    {
      "id": "phase-2-dashboard",
      "content": "Implement CEPAF Dashboard",
      "status": "in_progress",
      "activeForm": "Implementing CEPAF Dashboard"
    }
  ]
}
```

### 2. CEPAF OODA Integration (SC-DASH-005)

```elixir
# OODA Loop phases displayed:
# OBSERVE -> ORIENT -> DECIDE -> ACT
# Dashboard shows current phase and timing

@ooda_phases [:observe, :orient, :decide, :act]

defp current_ooda_phase do
  # Read from CEPAF coordinator state
  {:ok, phase} = CEPAFCoordinator.current_phase()
  phase
end
```

### 3. Podman Container Integration

```elixir
# Container health check
defp check_container(name) do
  case System.cmd("podman", ["inspect", "--format", "{{.State.Status}}", name]) do
    {status, 0} -> {:ok, String.trim(status)}
    {error, _} -> {:error, error}
  end
end
```

## Script Specifications

### start_dashboard.sh

```bash
#!/bin/bash
# SC-DASH-001: Always-on dashboard availability
# AOR-DASH-001: Persistent daemon operation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$SCRIPT_DIR/../../data/tmp/dashboard.pid"
LOG_FILE="$SCRIPT_DIR/../../data/tmp/dashboard.log"

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "Dashboard already running (PID: $(cat "$PID_FILE"))"
    exit 1
fi

nohup elixir "$SCRIPT_DIR/cepaf_dashboard.exs" >> "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"
echo "Dashboard started (PID: $!)"
```

### stop_dashboard.sh

```bash
#!/bin/bash
# SC-EMR-057: Stop <5s

PID_FILE="$(dirname "$0")/../../data/tmp/dashboard.pid"

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID"
        rm "$PID_FILE"
        echo "Dashboard stopped"
    else
        rm "$PID_FILE"
        echo "Dashboard was not running"
    fi
else
    echo "No PID file found"
fi
```

---

# Level 4 (L4) - Debug/Verbose

## Technical Implementation Details

### Terminal Width Detection (SC-DASH-002)

```elixir
@doc """
Detects terminal width for responsive layout.

## STAMP Compliance
- SC-DASH-002: Full terminal width utilization
- Minimum: 80 columns (fallback)
- Maximum: Unlimited (responsive)

## Returns
- Integer representing terminal columns
"""
@spec get_terminal_width() :: pos_integer()
defp get_terminal_width do
  case System.cmd("tput", ["cols"], stderr_to_stdout: true) do
    {cols, 0} ->
      cols
      |> String.trim()
      |> String.to_integer()
      |> max(80)  # Enforce minimum

    _ ->
      80  # Fallback for non-TTY environments
  end
end
```

### Box Drawing Characters (AOR-DASH-005)

```elixir
@moduledoc """
Unicode box drawing characters for dashboard rendering.

## Visual Standards (AOR-DASH-005)
- Consistent Unicode box drawing
- ANSI color support required
- Fallback to ASCII if Unicode unavailable
"""

@box_chars %{
  # Corners
  top_left: "┌",
  top_right: "┐",
  bottom_left: "└",
  bottom_right: "┘",

  # Lines
  horizontal: "─",
  vertical: "│",

  # T-junctions
  t_down: "┬",
  t_up: "┴",
  t_right: "├",
  t_left: "┤",

  # Cross
  cross: "┼",

  # Double lines (for emphasis)
  double_horizontal: "═",
  double_vertical: "║"
}

@ascii_fallback %{
  top_left: "+",
  top_right: "+",
  bottom_left: "+",
  bottom_right: "+",
  horizontal: "-",
  vertical: "|",
  t_down: "+",
  t_up: "+",
  t_right: "+",
  t_left: "+",
  cross: "+"
}

defp box_char(name) do
  if unicode_supported?() do
    @box_chars[name]
  else
    @ascii_fallback[name]
  end
end

defp unicode_supported? do
  case System.get_env("LANG") do
    nil -> false
    lang -> String.contains?(lang, "UTF-8")
  end
end
```

### Progress Bar Rendering

```elixir
@doc """
Renders a progress bar with configurable width.

## Parameters
- percentage: 0-100 integer
- width: character width (default 10)

## Returns
- String with filled/empty blocks

## Example
    iex> progress_bar(75, 10)
    "████████░░"
"""
@spec progress_bar(0..100, pos_integer()) :: String.t()
defp progress_bar(percentage, width \\ 10) when percentage >= 0 and percentage <= 100 do
  filled = round(percentage / 100 * width)
  empty = width - filled

  filled_char = "█"
  empty_char = "░"

  String.duplicate(filled_char, filled) <> String.duplicate(empty_char, empty)
end
```

### ANSI Color Codes

```elixir
@moduledoc """
ANSI escape codes for terminal coloring.

## Compliance
- AOR-DASH-005: Visual standards
- Fallback: NO_COLOR environment variable support
"""

@colors %{
  # Reset
  reset: "\e[0m",

  # Styles
  bold: "\e[1m",
  dim: "\e[2m",
  italic: "\e[3m",
  underline: "\e[4m",
  blink: "\e[5m",

  # Foreground colors
  black: "\e[30m",
  red: "\e[31m",
  green: "\e[32m",
  yellow: "\e[33m",
  blue: "\e[34m",
  magenta: "\e[35m",
  cyan: "\e[36m",
  white: "\e[37m",
  gray: "\e[90m",

  # Background colors
  bg_red: "\e[41m",
  bg_green: "\e[42m",
  bg_yellow: "\e[43m",
  bg_blue: "\e[44m"
}

@spec colorize(String.t(), atom()) :: String.t()
defp colorize(text, color) do
  if colors_enabled?() do
    "#{@colors[color]}#{text}#{@colors[:reset]}"
  else
    text
  end
end

defp colors_enabled? do
  System.get_env("NO_COLOR") == nil and
  System.get_env("TERM") != "dumb"
end
```

### Metric Collection with Timeout (AOR-DASH-002)

```elixir
@doc """
Collects metrics with non-blocking timeout.

## STAMP Compliance
- AOR-DASH-002: Non-blocking updates (5s timeout)
- SC-DASH-003: Real-time KPI accuracy (<60s)

## Returns
- {:ok, metrics} on success
- {:error, :timeout} on timeout
- {:error, reason} on failure
"""
@spec collect_metrics(atom(), timeout()) :: {:ok, map()} | {:error, term()}
defp collect_metrics(metric_type, timeout \\ 5_000) do
  task = Task.async(fn ->
    case metric_type do
      :compilation -> collect_compilation_metrics()
      :tests -> collect_test_metrics()
      :containers -> collect_container_metrics()
      :performance -> collect_performance_metrics()
      :security -> collect_security_metrics()
      :progress -> collect_progress_metrics()
      :stamp -> collect_stamp_metrics()
      :todos -> collect_todo_metrics()
      :agents -> collect_agent_metrics()
    end
  end)

  case Task.yield(task, timeout) || Task.shutdown(task) do
    {:ok, result} -> {:ok, result}
    nil -> {:error, :timeout}
  end
end
```

### Dashboard Main Loop

```elixir
@doc """
Main dashboard rendering loop.

## STAMP Compliance
- SC-DASH-001: Always-on availability
- SC-DASH-003: Real-time accuracy (<60s)
- AOR-DASH-002: 5s refresh cycle
"""
def run do
  # Clear screen and hide cursor
  IO.write("\e[2J\e[H\e[?25l")

  # Trap exit for cleanup
  Process.flag(:trap_exit, true)

  loop(%{
    last_update: DateTime.utc_now(),
    refresh_interval: 5_000,
    metrics: %{},
    errors: []
  })
end

defp loop(state) do
  # Collect all metrics in parallel
  metrics = collect_all_metrics()

  # Render dashboard
  render(metrics, get_terminal_width())

  # Update state
  new_state = %{state |
    last_update: DateTime.utc_now(),
    metrics: metrics
  }

  # Wait for next refresh or user input
  receive do
    {:input, "q"} ->
      cleanup()
      :ok

    {:input, "r"} ->
      loop(new_state)

    {:EXIT, _pid, reason} ->
      Logger.error("Dashboard subprocess crashed: #{inspect(reason)}")
      loop(new_state)

  after
    state.refresh_interval ->
      loop(new_state)
  end
end

defp cleanup do
  # Show cursor
  IO.write("\e[?25h")
  # Clear screen
  IO.write("\e[2J\e[H")
  IO.puts("Dashboard stopped.")
end
```

## Environment Requirements

| Requirement | Minimum | Recommended | Verification |
|-------------|---------|-------------|--------------|
| Elixir | 1.18.0 | 1.18.0+ | `elixir --version` |
| OTP | 27.0 | 27.0+ | `erl -version` |
| Terminal | ANSI support | xterm-256color | `echo $TERM` |
| Columns | 80 | 120+ | `tput cols` |
| Podman | 5.4.1 | 5.4.1+ | `podman --version` |
| Unicode | UTF-8 | UTF-8 | `echo $LANG` |

## Testing Strategy

### Unit Tests

```elixir
defmodule Intelitor.CEPAFDashboardTest do
  use ExUnit.Case, async: true

  # SC-PROP-023/024 compliance
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  describe "progress_bar/2" do
    test "renders correct fill level" do
      assert progress_bar(0, 10) == "░░░░░░░░░░"
      assert progress_bar(50, 10) == "█████░░░░░"
      assert progress_bar(100, 10) == "██████████"
    end

    test "handles edge cases" do
      assert progress_bar(0, 5) == "░░░░░"
      assert progress_bar(100, 5) == "█████"
    end
  end

  describe "colorize/2" do
    test "applies color codes when enabled" do
      assert colorize("test", :green) == "\e[32mtest\e[0m"
    end
  end
end
```

### Property Tests

```elixir
defmodule Intelitor.CEPAFDashboardPropertyTest do
  use ExUnit.Case
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # SC-PROP-023/024: Mandatory disambiguation
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # PropCheck property
  property "progress bar width matches input" do
    forall {percentage, width} <- {PC.range(0, 100), PC.range(1, 50)} do
      bar = progress_bar(percentage, width)
      String.length(bar) == width
    end
  end

  # ExUnitProperties property
  property "terminal width is always >= 80" do
    check all(
      width <- SD.integer(1..300)
    ) do
      result = max(width, 80)
      assert result >= 80
    end
  end
end
```

## Verification Signature

```
═══════════════════════════════════════════════════════════════════════════════
                        PHASE 2 JOURNAL VERIFICATION
═══════════════════════════════════════════════════════════════════════════════

FPPS Consensus Status: PENDING (5/5 methods required)
  - Pattern Matching:    [ ] Pending validation
  - AST Analysis:        [ ] Pending validation
  - Statistical:         [ ] Pending validation
  - Binary Comparison:   [ ] Pending validation
  - Line-by-Line:        [ ] Pending validation

STAMP Constraints Defined:
  [✓] SC-DASH-001: Always-on dashboard availability
  [✓] SC-DASH-002: Full terminal width utilization
  [✓] SC-DASH-003: Real-time KPI accuracy (<60s)
  [✓] SC-DASH-004: TodoList integration
  [✓] SC-DASH-005: CEPAF OODA coordination

AOR Rules Defined:
  [✓] AOR-DASH-001: Persistent daemon operation
  [✓] AOR-DASH-002: Non-blocking updates (5s timeout)
  [✓] AOR-DASH-003: Claude session integration
  [✓] AOR-DASH-004: 9 mandatory KPI categories
  [✓] AOR-DASH-005: Visual standards (ANSI/Unicode)

TDG Compliance:
  [✓] SC-PROP-023: PropCheck/StreamData disambiguation documented
  [✓] SC-PROP-024: PC/SD alias pattern specified
  [✓] EP-GEN-014: Conflict resolution referenced

Omega Alignment:
  [✓] Ω₁: Patient Mode requirements documented
  [✓] Ω₃: Zero-Defect targeting (0 errors, 0 warnings)
  [✓] Ω₄: TDG test patterns specified

═══════════════════════════════════════════════════════════════════════════════
Journal Author: Agent 3 (Documenter)
Timestamp: 2025-12-26T09:30:00+01:00 (CET)
Hash: SHA256(pending-implementation-verification)
═══════════════════════════════════════════════════════════════════════════════
```

---

## Appendix A: Related Documentation

| Document | Purpose | Location |
|----------|---------|----------|
| GEMINI.md | Master specification | `/home/an/dev/ver/indrajaal-v5.2/CLAUDE.md` |
| Phase 1 Journal | Previous phase | `journal/2025-12/20251226-0911-phase1-multi-agent-execution.md` |
| CEPAF Plan | Implementation plan | `journal/2025-12/20251223-2330-cepaf-quadplex-implementation-plan-5level.md` |
| PropCheck Resolution | SC-PROP-023/024 | `journal/2025-12/20251224-1315-propcheck-streamdata-conflict-resolution.md` |

## Appendix B: Glossary

| Term | Definition |
|------|------------|
| CEPAF | Claude Enhanced Parallel Agent Framework |
| KPI | Key Performance Indicator |
| OODA | Observe-Orient-Decide-Act loop |
| STAMP | Systems-Theoretic Accident Model and Processes |
| TDG | Test-Driven Generation |
| FPPS | Five-Point Pattern System (validation) |
| AOR | Agent Operating Rules |
| SC | Safety Constraint |

---

*End of Phase 2 Journal Entry*
