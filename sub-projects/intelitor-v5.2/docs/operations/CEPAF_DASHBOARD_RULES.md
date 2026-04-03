# CEPAF Dashboard Operational Rules
**Version**: 1.0.0 | **Status**: ACTIVE | **Compliance**: SOPv5.11

## 1.0 STAMP Safety Constraints for Dashboard

### SC-DASH-001: Always-On Availability
- Dashboard MUST be accessible during ALL Claude development operations
- Refresh interval: 30 seconds (configurable)
- Graceful degradation on data source failure

### SC-DASH-002: Full-Screen Utilization
- Dashboard MUST use terminal width dynamically (tput cols)
- Minimum supported width: 80 columns
- Optimal width: 120+ columns for full KPI display

### SC-DASH-003: Real-Time KPI Accuracy
- All KPIs MUST reflect current system state
- Stale data (>60s) MUST be marked with warning
- Data sources: ETS, files, shell commands

### SC-DASH-004: TodoList Integration
- Dashboard MUST display current session todos
- Status tracking: pending -> in_progress -> completed
- Sync with PROJECT_TODOLIST.md every refresh

### SC-DASH-005: CEPAF Coordination
- Dashboard agent coordinates with CEPAF OODA loop
- Observe: Collect all KPIs
- Orient: Analyze trends and anomalies
- Decide: Flag warnings/blockers
- Act: Update display and log changes

## 2.0 Agent Operating Rules (AOR)

### AOR-DASH-001: Persistent Daemon
- Dashboard daemon runs as background process
- PID file: data/tmp/dashboard.pid
- Log file: data/tmp/dashboard.log
- Restart on crash (supervised)

### AOR-DASH-002: Non-Blocking Updates
- All data collection MUST be async
- Timeout per data source: 5 seconds
- Display "N/A" on timeout, not block

### AOR-DASH-003: Claude Session Integration
- Dashboard starts automatically with Claude sessions
- Accessible via: `elixir scripts/monitoring/cepaf_dashboard.exs`
- Background mode: `./scripts/monitoring/start_dashboard.sh`

### AOR-DASH-004: KPI Categories (Mandatory)
1. **Compilation**: Errors, Warnings, Files
2. **Tests**: Total, Passed, Failed, Coverage
3. **Containers**: Health (app/db/obs)
4. **Performance**: p50/p95/p99 latency
5. **Security**: Sobelow findings, Audit status
6. **Progress**: C1/C2/C3/C4 completion %
7. **STAMP**: Constraints verified count
8. **TodoList**: Session tasks status
9. **Agents**: Active agent count and status

### AOR-DASH-005: Visual Standards
- Use ANSI colors: Green=PASS, Yellow=WARN, Red=FAIL
- Progress bars for percentage metrics
- Unicode box drawing for layout
- Timestamp and refresh countdown visible

## 3.0 TDG (Test-Driven Generation) Rules

### TDG-DASH-001: Dashboard Module Tests
- Unit tests for each KPI collector function
- Property tests for display formatting
- Integration tests for full refresh cycle

### TDG-DASH-002: PropCheck/StreamData Disambiguation
```elixir
alias PropCheck.BasicTypes, as: PC
alias StreamData, as: SD
```

### TDG-DASH-003: Test Coverage
- Minimum 80% coverage for dashboard modules
- All STAMP constraints MUST have corresponding tests

## 4.0 Dashboard Layout Specification

```
+-----------------------------------------------------------------------------+
| CEPAF DASHBOARD | SOPv5.11 | STAMP: 242 | 2025-12-26 09:30:00 | [R] 30s     |
+-----------------+-----------------------+-----------------------------------+
| COMPILATION     | TESTS                 | CONTAINERS                        |
| Errors:    0 [OK]| Total:    500         | App: ========== HEALTHY           |
| Warnings:  0 [OK]| Passed:   498 [OK]    | DB:  ========== HEALTHY           |
| Files:   926    | Failed:     2 [X]     | Obs: ========== HEALTHY           |
|                 | Coverage: 87%         |                                   |
+-----------------+-----------------------+-----------------------------------+
| PERFORMANCE     | SECURITY              | PROGRESS                          |
| p50:    7ms [OK]| Sobelow:  0 [OK]      | C1: ========.. 80% [OK]           |
| p95:   14ms [OK]| Deps:     0 [OK]      | C2: ==........ 20%                |
| p99:   18ms [OK]| OWASP:    PASS        | C3: .......... 0%                 |
| RPS:   243      |                       | C4: .......... 0%                 |
+-----------------+-----------------------+-----------------------------------+
| TODOLIST (Session)                                                          |
| [DONE] Phase 1: Multi-agent execution complete                              |
| [WIP]  Create CEPAF Dashboard Rules (STAMP/AOR/TDG)                         |
| [    ] Create full-screen persistent KPI Dashboard                          |
| [    ] Create Dashboard Daemon Agent                                        |
+-----------------------------------------------------------------------------+
| AGENTS                                                                      |
| Supervisor: ACTIVE | Agent1: RUNNING | Agent2: RUNNING | Agent3: PENDING   |
| Dashboard:  ACTIVE | Agent4: RUNNING | Agent5: IDLE    | Agent6: IDLE      |
+-----------------------------------------------------------------------------+
```

## 5.0 Startup Commands

```bash
# Start dashboard (foreground)
elixir scripts/monitoring/cepaf_dashboard.exs

# Start dashboard (background daemon)
./scripts/monitoring/start_dashboard.sh

# Stop dashboard
./scripts/monitoring/stop_dashboard.sh

# Check dashboard status
./scripts/monitoring/dashboard_status.sh
```

## 6.0 Compliance Matrix

| Constraint | Description | Verification |
|------------|-------------|--------------|
| SC-DASH-001 | Always-on | PID file check |
| SC-DASH-002 | Full-screen | Terminal width detection |
| SC-DASH-003 | Real-time | Timestamp < 60s |
| SC-DASH-004 | TodoList | Sync verification |
| SC-DASH-005 | CEPAF OODA | Loop execution log |
| AOR-DASH-001 | Daemon | Process monitoring |
| AOR-DASH-002 | Non-blocking | Timeout tests |
| TDG-DASH-001 | Tests | Coverage report |

## 7.0 Data Collection Specifications

### 7.1 Compilation Data
```elixir
# Source: Compile log analysis
defmodule Dashboard.Collectors.Compilation do
  @compile_log "data/tmp/1-compile.log"

  def collect do
    %{
      errors: count_errors(@compile_log),
      warnings: count_warnings(@compile_log),
      files: count_compiled_files(@compile_log),
      timestamp: DateTime.utc_now()
    }
  end
end
```

### 7.2 Test Data
```elixir
# Source: ExUnit results / coverage report
defmodule Dashboard.Collectors.Tests do
  @coverage_file "cover/excoveralls.json"

  def collect do
    %{
      total: get_test_count(),
      passed: get_passed_count(),
      failed: get_failed_count(),
      coverage: parse_coverage(@coverage_file),
      timestamp: DateTime.utc_now()
    }
  end
end
```

### 7.3 Container Health
```elixir
# Source: Podman health checks
defmodule Dashboard.Collectors.Containers do
  @containers ~w(indrajaal-app indrajaal-db indrajaal-obs)

  def collect do
    @containers
    |> Enum.map(&check_health/1)
    |> Map.new()
    |> Map.put(:timestamp, DateTime.utc_now())
  end

  defp check_health(container) do
    {container, System.cmd("podman", ["healthcheck", "run", container])}
  end
end
```

### 7.4 Performance Metrics
```elixir
# Source: Phoenix telemetry / OTEL
defmodule Dashboard.Collectors.Performance do
  def collect do
    %{
      p50: get_percentile(50),
      p95: get_percentile(95),
      p99: get_percentile(99),
      rps: get_requests_per_second(),
      timestamp: DateTime.utc_now()
    }
  end
end
```

## 8.0 Error Handling

### 8.1 Data Source Failures
```elixir
defmodule Dashboard.ErrorHandler do
  @timeout_ms 5_000

  def safe_collect(collector_fn) do
    task = Task.async(collector_fn)
    case Task.yield(task, @timeout_ms) || Task.shutdown(task) do
      {:ok, result} -> {:ok, result}
      nil -> {:error, :timeout}
    end
  end

  def display_error(:timeout), do: "N/A (timeout)"
  def display_error(:unavailable), do: "N/A"
end
```

### 8.2 Graceful Degradation
- Individual section failures do not crash the dashboard
- Failed sections display "N/A" with error indicator
- Dashboard continues refreshing on partial failures
- Full failure triggers restart via supervisor

## 9.0 OODA Loop Integration

### 9.1 Observe Phase
- Collect all KPIs from data sources
- Parse compilation logs
- Query container health
- Read test results and coverage

### 9.2 Orient Phase
- Compare current values to thresholds
- Detect anomalies and trends
- Calculate delta from previous refresh
- Classify status: OK/WARN/FAIL

### 9.3 Decide Phase
- Determine visual indicators
- Flag items requiring attention
- Prioritize display elements
- Generate alerts if needed

### 9.4 Act Phase
- Render updated dashboard
- Log changes to dashboard.log
- Trigger notifications for critical changes
- Update ETS cache for next cycle

## 10.0 Configuration

### 10.1 Environment Variables
```bash
# Dashboard configuration
DASHBOARD_REFRESH_INTERVAL=30    # seconds
DASHBOARD_TIMEOUT=5000           # ms per collector
DASHBOARD_LOG_LEVEL=info         # debug/info/warn/error
DASHBOARD_COLOR=true             # ANSI color output
DASHBOARD_WIDTH=auto             # auto or fixed number
```

### 10.2 Configuration File
```elixir
# config/dashboard.exs
config :indrajaal, :dashboard,
  refresh_interval: 30_000,
  collector_timeout: 5_000,
  log_file: "data/tmp/dashboard.log",
  pid_file: "data/tmp/dashboard.pid",
  kpi_categories: [
    :compilation,
    :tests,
    :containers,
    :performance,
    :security,
    :progress,
    :stamp,
    :todolist,
    :agents
  ]
```

## 11.0 Audit Trail

### 11.1 Log Format
```
[2025-12-26 09:30:00] [INFO] Dashboard refresh started
[2025-12-26 09:30:01] [INFO] Compilation: 0 errors, 0 warnings
[2025-12-26 09:30:01] [WARN] Tests: 2 failures detected
[2025-12-26 09:30:02] [INFO] Containers: all healthy
[2025-12-26 09:30:02] [INFO] Dashboard refresh completed (2.1s)
```

### 11.2 Retention Policy
- Log rotation: daily
- Retention: 7 days
- Archive: compressed to data/archive/dashboard/

## 12.0 Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2025-12-26 | CEPAF Supervisor | Initial release |

---
**Document End** | **Classification**: Internal | **Review Cycle**: Monthly
